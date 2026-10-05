---
baseline_commit: c76ac33d72e812a1d9144b28111d1dab0717284b
---

# Story 4.1: Cosmetic Catalogue and Brain Wallet Rules

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want my brains to be spent correctly when I buy something and never lost otherwise,
so that I can trust the shop.

## Acceptance Criteria

1. **Resources (architecture Static Game Data).** Three typed Resource classes exist in `scripts/resources/`. `CosmeticItem` has id, slot, price, row, is_available, icon, overlay texture and pet `SpriteFrames`, plus `display_name` (see Dev Notes). `Catalogue` holds the item list with lookups. `EconomyConfig` holds the welcome bonus. Each class has a `class_name` and `##` docs, and its defaults are neutral (real values live only in `.tres` files).
2. **Shipped catalogue (FR39, FR42).** `data/cosmetics/catalogue.tres` lists all 18 GDD items. There are 9 hats and 9 pets, each slot in 3×3 grid order (row 1, then row 2, then row 3, 3 per row), with row prices 100 / 200 / 300. Only `hat_pumpkin` and `pet_cute_ghost` have `is_available = true`. `Catalogue.validate()` returns `""` for the shipped file.
3. **Economy config.** `data/economy.tres` (an `EconomyConfig`) holds `welcome_bonus = 100`. No script holds 100 as a welcome-bonus or price literal.
4. **Buying (FR38, FR41).** `PlayerData.buy_item(item: CosmeticItem) -> PurchaseResult` returns `PurchaseResult.OK` and deducts the price when the item is in the catalogue, available, not owned and affordable. Otherwise it returns `UNAVAILABLE`, `ALREADY_OWNED` or `NOT_ENOUGH_BRAINS` and changes nothing: no signal, no save request. A successful buy appends the id to `owned_items`, emits `brains_changed(total, -price)` and `inventory_changed(item_id)`, and makes exactly **one** `request_save()` call.
5. **Brains never go negative (FR38).** Exact-change buys leave 0. No sequence of `buy_item` / `add_brains` calls ever leaves `brains < 0`.
6. **Flags (sprint change E4-1).** `PlayerData.set_flag(name: StringName, value: bool)` on a known flag (`welcome_bonus_claimed`, `tutorial_seen`, `placement_done`) that changes the value stores it, emits `flags_changed(name, value)` and requests a save. `get_flag(name) -> bool` reads it. An unknown flag name logs `Log.error()` and changes nothing (`get_flag` returns `false`). The tests cover both cases.
7. **Equip / unequip (FR43).** `PlayerData.equip(item_id: StringName) -> bool` equips only owned catalogue items, into that item's slot, replacing whatever was there. There is at most one hat and one pet. `unequip(slot: StringName)` empties a slot. Either slot can be empty. Every real change emits `equipment_changed(slot, item_id)` (`&""` for an emptied slot) and requests a save. Rejected calls change nothing. `get_equipped(slot) -> StringName` and `owns(item_id) -> bool` read the state.
8. **Tests.** `tests/unit/test_player_data.gd` covers every purchase result, the single save request, the equip/unequip rules, the flag rules and the "brains never go negative" rule. A new `tests/unit/test_catalogue.gd` covers `Catalogue` lookups, `validate()` and the shipped `catalogue.tres` / `economy.tres` contents. All existing tests pass unchanged, and the full suite passes.

## Tasks / Subtasks

- [x] **Task 1: `EconomyConfig` (AC: 1, 3)**
  - [x] 1.1 `scripts/resources/economy_config.gd`: `class_name EconomyConfig extends Resource`, `## Brains rules that are not per-level...` header. `@export var welcome_bonus: int = 0` (neutral default, `##`-documented as "FR44: 100", used by Story 4.5).
  - [x] 1.2 `data/economy.tres` with `welcome_bonus = 100`. Copy the existing `.tres` header style (`[gd_resource type="Resource" script_class="EconomyConfig" load_steps=2 format=3]`, see `data/levels/zombie_run.tres`).
- [x] **Task 2: `CosmeticItem` (AC: 1)**
  - [x] 2.1 `scripts/resources/cosmetic_item.gd`: `class_name CosmeticItem extends Resource`. `enum Slot { HAT, PET }`. Exports: `id: StringName`, `display_name: String` (kid-facing, e.g. "Pumpkin hat"), `slot: Slot`, `price: int = 0`, `row: int = 0` (1..3), `is_available: bool = false`, `icon: Texture2D`, `overlay: Texture2D` (hats), `pet_frames: SpriteFrames` (pets).
  - [x] 2.2 `const SLOT_HAT: StringName = &"hat"`, `const SLOT_PET: StringName = &"pet"`, and `func slot_key() -> StringName`, which maps `Slot` to the save's `equipped` key. Add `static func is_slot_key(key: StringName) -> bool`. These strings are the **only** place the slot names live. They must match `SaveSchema.profile_defaults()["equipped"]` keys, and a test checks that.
- [x] **Task 3: `Catalogue` (AC: 1, 2)**
  - [x] 3.1 `scripts/resources/catalogue.gd`: `class_name Catalogue extends Resource`. `@export var items: Array[CosmeticItem] = []`, in grid order per slot (row-major).
  - [x] 3.2 `get_item(id: StringName) -> CosmeticItem`: a linear scan, same as `AudioLibrary.get_cue` / `LevelRegistry.get_entry` (a cache would go stale in the inspector). `&""` or an unknown id returns `null`. **Don't** `assert` and **don't** log here. Callers decide; `PlayerData` logs.
  - [x] 3.3 `items_for_slot(slot: CosmeticItem.Slot) -> Array[CosmeticItem]`: that slot's items in grid order (index 0..8 = row 1 col 1 … row 3 col 3). Story 4.4 builds its grids from this.
  - [x] 3.4 `validate() -> String`, following the pattern in `ZombieRunConfig.validate()`. It returns `""` when sound, otherwise the first problem: a null item, an empty or duplicate id, an id whose prefix doesn't match its slot (`hat_` / `pet_`), `row` outside 1..3, `price <= 0`, a slot that doesn't hold exactly `GRID_SIZE` (9) items, or rows out of grid order within a slot. `GRID_SIZE`/`GRID_COLUMNS` are layout constants (FR39's 3×3), not balance numbers, so they live as `const` in `catalogue.gd`.
- [x] **Task 4: Shipped data (AC: 2)**
  - [x] 4.1 One `.tres` per item under `data/cosmetics/`, named `<id>.tres` (architecture tree + naming: `hat_pumpkin.tres`). All 18 items, with ids, names and rows from the table in Dev Notes. Only `hat_pumpkin` and `pet_cute_ghost` get `is_available = true`. Texture/frames fields stay **empty** (the art is Story 4.3, and Epic 9 for the rest).
  - [x] 4.2 `data/cosmetics/catalogue.tres` references the 18 items through `ext_resource`, in this order: 9 hats in grid order, then 9 pets in grid order. Use the `Array[ExtResource("…")]([...])` form from `level_registry.tres`.
  - [x] 4.3 You may hand-write the 19 files or generate them with a throwaway headless script in the scratchpad (`ResourceSaver.save`). If you generate them, don't commit the script, and check the output is LF and has no absolute paths.
- [x] **Task 5: `PlayerData` wallet, inventory, equipment, flags (AC: 4–7)** in `scripts/autoloads/player_data.gd`
  - [x] 5.1 `enum PurchaseResult { OK, NOT_ENOUGH_BRAINS, ALREADY_OWNED, UNAVAILABLE }`, as named in the architecture's Data Patterns example (`PlayerData.PurchaseResult.OK`).
  - [x] 5.2 New typed signals: `inventory_changed(item_id: StringName)`, `equipment_changed(slot: StringName, item_id: StringName)`, `flags_changed(name: StringName, value: bool)`.
  - [x] 5.3 Catalogue test seam, mirroring `save_service`: `const CATALOGUE: Catalogue = preload("res://data/cosmetics/catalogue.tres")`, `var catalogue: Catalogue = null`, and in `_ready()`: `if catalogue == null: catalogue = CATALOGUE`. (The Data Patterns rule allows `preload` constants in autoloads.)
  - [x] 5.4 `buy_item(item: CosmeticItem) -> PurchaseResult`. Checks run in this order:
    1. `item == null`, or `catalogue.get_item(item.id) == null` → `Log.error(&"economy", ...)`, return `UNAVAILABLE`. This is a contract violation: the Closet only passes catalogue items.
    2. `not item.is_available` → `UNAVAILABLE`, no error log (a "Coming soon" tile is a normal state). `Log.debug` is fine.
    3. `owns(item.id)` → `ALREADY_OWNED`.
    4. `get_brains() < item.price` → `NOT_ENOUGH_BRAINS`.
    5. Otherwise deduct, append `String(item.id)` to `owned_items`, emit `brains_changed(total, -item.price)` then `inventory_changed(item.id)`, make one `save_service.request_save()` call, and `Log.info(&"economy", "bought %s for %d, brains=%d" ...)`. Write the brains **inline** (as `record_run` does). Don't route it through `add_brains`: that rejects negatives and would add a second save request.
    - Steps 2–5 read the **catalogue's record** (`var record: CosmeticItem = catalogue.get_item(item.id)`), not the passed object. A stray or duplicated `CosmeticItem` then can't buy at a wrong price or skip `is_available`. Add a test where the passed item has the right id but a different price and availability, and show the catalogue's values win. A price ≤ 0 is impossible after `validate()`, but guard anyway: `record.price <= 0` counts as case 1 (error, `UNAVAILABLE`). Brains can then never rise through a purchase, and nothing can be had for free.
  - [x] 5.5 `owns(item_id: StringName) -> bool` and `get_owned_items() -> Array[StringName]`. These read `owned_items`, skipping non-String junk from hand-edited saves (compare with `String(item_id)`, see "String vs StringName" below).
  - [x] 5.6 `equip(item_id: StringName) -> bool`:
    - Unknown id (not in the catalogue) → `Log.error(&"economy", ...)`, return `false`.
    - Not owned → `Log.error(&"economy", ...)`, return `false`. The Closet only offers Wear on owned items.
    - Already equipped in its slot → return `true`, no signal and no save (no-op).
    - Otherwise write `String(item_id)` to `equipped[item.slot_key()]`, emit `equipment_changed(slot_key, item_id)`, request a save and return `true`.
  - [x] 5.7 `unequip(slot: StringName) -> void`. An unknown slot (`not CosmeticItem.is_slot_key(slot)`) → `Log.error`, no change. A slot that is already empty is a no-op. Otherwise set it to `""`, emit `equipment_changed(slot, &"")` and request a save.
  - [x] 5.8 `get_equipped(slot: StringName) -> StringName`. An unknown slot → `Log.error`, return `&""`. Return `&""` too when the stored value isn't a non-empty String or isn't owned (a hand-edited save can't make 4.3 draw an item the kid never bought). Getters never write.
  - [x] 5.9 `set_flag(name: StringName, value: bool)` / `get_flag(name: StringName) -> bool`. Copy the `set_setting` / `get_setting` / `_is_setting` shape exactly: `_is_flag()` checks `SaveSchema.profile_defaults()["flags"]`, an unknown name → `Log.error(&"save", "unknown flag %s" % name)`, and setting the **same value** is a no-op with no signal and no save (consistent with `set_setting`; see Key design decisions). Store under a `String` key.
  - [x] 5.10 Update the file header comment. Replace the "Later methods, by story: buy_item/equip/unequip/set_flag/get_flag (4.1)" line with a description of the new API, and keep the 6.8 line. Add one sentence: "Listeners also re-read on `profile_replaced` (a reset changes owned/equipped/flags with no delta signals)."
- [x] **Task 6: Tests (AC: 8)**
  - [x] 6.1 `tests/unit/test_catalogue.gd` (new): `get_item` (known, unknown, `&""`, null entries skipped), `items_for_slot` order, one `validate()` case per problem listed in 3.4 (code-built catalogues), and the shipped file. For the shipped file, assert that `load("res://data/cosmetics/catalogue.tres") is Catalogue`, that `validate() == ""`, and that hats and pets each give the exact expected id order. Check row and price per index against the GDD table written **literally in the test**: the test is the guard on the data. Check that exactly `[&"hat_pumpkin", &"pet_cute_ghost"]` are available, and that `CosmeticItem.SLOT_HAT/SLOT_PET` equal the keys of `SaveSchema.profile_defaults()["equipped"]`. Also check that `load("res://data/economy.tres") is EconomyConfig` with `welcome_bonus == 100`.
  - [x] 6.2 `tests/unit/test_player_data.gd`: add a `# --- wallet, inventory, equipment, flags (Story 4.1) ---` section. `_make()` should also assign a **code-built** test catalogue (`sut.catalogue = ...` before `add_child`) with an available hat, an available pet, a second available hat, and an unavailable hat, at known prices. The tests then don't depend on shipped prices. Add one test that a default `PlayerData` uses the shipped `catalogue.tres`, mirroring `test_uses_live_save_service_by_default`. Required cases:
    - buy OK: price deducted, id in `owned_items` (as `String`), `brains_changed` with `[total, -price]`, `inventory_changed` with `[id]`, signal order brains then inventory, **one** `request_save` (reuse `CountingSave`), and the written file shows both changes after `await wait_process_frames(2)`.
    - exact change → brains 0.
    - `NOT_ENOUGH_BRAINS` at price − 1, `ALREADY_OWNED` on a second buy, `UNAVAILABLE` for an unavailable item, null item and non-catalogue item (the last two with `assert_push_error`). Each one leaves brains/owned unchanged, emits no signal and writes no save.
    - Never negative: a scripted sequence of buys and failed buys, asserting `get_brains() >= 0` after each one.
    - equip: an owned item → slot set, signal `[&"hat", id]`, save. Equip a second owned hat → replaces the first, and the pet slot is untouched. Hat and pet are equipped at once. Re-equipping the same item is a no-op. A not-owned or unknown id → `false`, `assert_push_error`, no change.
    - unequip: empties the slot, emits `[slot, &""]`, saves. An already empty slot is a no-op. An unknown slot → error.
    - `get_equipped` hides a stored id that isn't owned (put junk in `_save.get_active_profile()["equipped"]`).
    - Flags: set → stored, `flags_changed` `[&"tutorial_seen", true]`, one save. Same value is a no-op. Unknown name → `assert_push_error("unknown flag")`, no key added, `get_flag` returns false and logs. The fixture save (`save_v1_full.json`) reads `true` for all three.
    - Loaded save: `owns(&"hat_pumpkin")` and `get_equipped(&"hat") == &"hat_pumpkin"` with `FULL_PATH`. Note that the fixture ids must exist in whichever catalogue the test uses, so either use the shipped catalogue for this test or include those ids in the test catalogue.
    - `reset_all()` empties owned/equipped/flags, and emits only `profile_replaced` (no `equipment_changed`, `inventory_changed` or `flags_changed`).
  - [x] 6.3 Run `--import` first (there are new `class_name`s), then the full suite. Every test passes, the count is up only by the new tests, and there are no new `SCRIPT ERROR` or parse errors.
- [x] **Task 7: Wrap-up**
  - [x] 7.1 Every touched text file is LF (`.gitattributes` `eol=lf`).
  - [x] 7.2 Record the baseline and final test counts in the Debug Log, and fill in the File List.

### Review Findings

- [x] [Review][Patch] `equip()` must reject an owned item that is `is_available = false`, and `get_equipped` must hide one (decision resolved: option a) [scripts/autoloads/player_data.gd:165]
- [x] [Review][Patch] `name` parameter shadows `Node.name` in `get_flag`, `set_flag`, `_is_flag` and the `flags_changed` signal; rename to `flag` [scripts/autoloads/player_data.gd:206,213]
- [x] [Review][Patch] The shipped catalogue is never validated at runtime; call `catalogue.validate()` in `_ready` and `Log.error` on a non-empty result [scripts/autoloads/player_data.gd:_ready]
- [x] [Review][Patch] `unequip` leaves a junk or unowned stored id in the slot and emits a spurious `equipment_changed`; compare against `get_equipped` and clear the raw value (spec 5.7) [scripts/autoloads/player_data.gd:183]
- [x] [Review][Patch] `_owned()` returns duplicate ids from a hand-edited save, so a Closet could draw doubled tiles; dedupe [scripts/autoloads/player_data.gd:258]
- [x] [Review][Patch] Integer division without `@warning_ignore("integer_division")` in the tests (`i / 3`) [tests/unit/test_catalogue.gd]
- [x] [Review][Patch] `test_buy_signals_fire_after_the_write` is misnamed: it checks in-memory state at emit time, not a save write [tests/unit/test_player_data.gd:307]


### What this story is (and isn't)

- **Is:** pure data + rules: three Resource classes, 20 `.tres` files (18 items, the catalogue, economy), and the `PlayerData` API that Stories 4.2–4.5 call. No scenes, no UI, no art, no audio.
- **Isn't:** the Closet screen and the confirm prompt (4.4), the purchase jingle (4.4/5.1), `HatSlot`/`PetSlot`/`SpriteAnchors` and the Pumpkin hat / Cute ghost art (4.3), the welcome gift **granting** 100 brains (4.5 reads `EconomyConfig.welcome_bonus` and calls `add_brains` + `set_flag`). Don't touch `crypt_closet.gd` / `welcome_gift.gd` placeholders.

### Catalogue table (GDD "Crypt Closet catalogue"; MVP items in bold)

| Row / price | Hats (col 1, 2, 3) | Pets (col 1, 2, 3) |
|---|---|---|
| 1 / 100 | **`hat_pumpkin` "Pumpkin hat"**, `hat_witch` "Witch hat", `hat_bunny_ears` "Bunny ears" | **`pet_cute_ghost` "Cute ghost"**, `pet_black_cat` "Black cat", `pet_spider` "Spider" |
| 2 / 200 | `hat_santa` "Santa hat", `hat_leprechaun` "Leprechaun hat", `hat_heart_headband` "Heart headband" | `pet_orange_cat` "Orange cat", `pet_bat` "Bat", `pet_crow` "Crow" |
| 3 / 300 | `hat_top_hat` "Top hat", `hat_pirate` "Pirate hat", `hat_crown` "Golden crown" | `pet_wolf_dog` "Wolf-dog", `pet_eyeball` "Floating eyeball", `pet_brain_buddy` "Brain buddy" |

- The GDD names are "Valentine heart headband" and "New Year's top hat". The shorter kid-facing names above follow NFR9 (plain words). The ids are permanent once saved, because saves store ids (Data Patterns: "IDs, not references"), so **don't rename them later**. The display names can change freely.
- Full set = 3 × (100+200+300) × 2 = 3,600 (GDD), a handy sanity assert in the shipped-catalogue test.
- `display_name` isn't in the epic's field list, but 4.4's confirm prompt and preview need a kid-readable name, and adding it now saves a later data migration of 18 files. It is the only extra field. Don't add `column`: the grid position is the item's index within `items_for_slot()`.

### Key design decisions (follow these)

- **Check order in `buy_item`:** contract violation → unavailable → owned → afford. Unavailable comes before owned, so a "Coming soon" item can never report as owned. Owned comes before afford, so a kid with 0 brains who owns the hat gets `ALREADY_OWNED`, which is the more truthful answer for 4.4's tile state.
- **One save per buy.** Inline the wallet write. The architecture's "buy then equip in the same frame = one write" relies on `request_save()` coalescing, which already works (`SaveService` uses `call_deferred`). Don't call `save_now()`.
- **`brains_changed` delta is negative on a purchase.** This is the first negative delta ever emitted. Current listeners: `BrainCounter.set_count(total)` uses the total only. `keyboard_test.gd` shows the total. The HUD feeds run totals, not the wallet. Nothing breaks, but say so in the signal's `##` doc: "delta < 0 only for a purchase".
- **Flags: same value = no-op** (no signal, no save). The epic AC says "is set → emits", which this story reads as "is changed": that matches `set_setting` and avoids a pointless save. The tests make the no-op explicit. If review disagrees, it's a one-line change.
- **`equip` returns `bool`, `unequip` returns `void`.** The architecture doesn't specify either. 4.4 needs to know if Wear worked, and unequip on a known slot can't meaningfully fail.
- **Error vs. quiet:** a caller bug (null item, id not in the catalogue, equip not-owned, unknown slot or flag) → `Log.error`, safe return. A normal game state (unavailable, owned, can't afford, same value) → no error. No `assert()` anywhere: headless GUT logs it as `SCRIPT ERROR`, and it vanishes in release (header rule in `player_data.gd`).
- **Getters read live, nothing cached** (existing header rule). Every new getter goes through `_profile()`, so `reset_all()` and Epic 11's profile switch just work.

### Existing code: current state, what changes, what must be preserved

- `scripts/autoloads/player_data.gd` (UPDATE). Today: `get_brains`, `add_brains` (rejects negative, 0 is a no-op), `record_run` (inline brains + one save), `get_setting`/`set_setting` via `_is_setting` against `SaveSchema` defaults, `reset_all` → `profile_replaced`, and the `save_service` seam set in `_ready()`. **Preserve** every existing signature, signal and test. `debug_overlay.gd` F5 (`add_brains(CHEAT_BRAINS)`), `run_frame.gd` (`record_run`) and `keyboard_test.gd` depend on them. Add the new members below `set_setting` and above `reset_all`, with private helpers at the bottom.
- `scripts/core/save_schema.gd` (**no change**). It already defines `owned_items: []`, `equipped: {hat:"", pet:""}` and the three flags. `fill_defaults` repairs wrong types (e.g. `owned_items` that isn't an Array → `[]`), but it does **not** check array element types or equipped values, so `PlayerData` getters must tolerate junk. `CURRENT_SCHEMA` stays 1. There is no migration.
- `tests/fixtures/saves/save_v1_full.json` (no change). It already owns and equips `hat_pumpkin` / `pet_cute_ghost`, with all flags true. Use it.
- `scripts/resources/` today holds `audio_cue`, `audio_library`, `finger_map`, `level_config`, `level_entry`, `level_registry` and `zombie_run_config`. Match their style: `class_name` first, then `extends Resource`, a `##` header, `##` on every export, neutral defaults, and a linear-scan lookup returning null.

### String vs StringName (trap)

- The save is JSON: ids and keys **must** be stored as `String` (`String(item_id)`), as `set_setting` does (see `test_set_setting_writes_string_key`). Loaded saves give `String`. API parameters and signals use `StringName` (architecture naming: `&"hat_pumpkin"`).
- When comparing, convert explicitly: `owned.has(String(item_id))`, `String(equipped[key]) == String(item_id)`. Don't rely on `Array.has()` matching a `StringName` against a `String` element. Add a test that a `buy_item` result appears in `owned_items` as `TYPE_STRING` and that a loaded `String` id is found by `owns(&"...")`.
- Return `StringName(value)` from `get_equipped` / `get_owned_items`.

### Testing notes

- Suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. **Run `--import` first** (`"/c/Program Files/Godot/Godot.exe" --headless --path . --import`): three new `class_name`s and 20 new `.tres` files must be in the global class cache, or parse errors cascade.
- Baseline at `c76ac33` should be 846 tests, all passing, with 3 expected `SCRIPT ERROR` lines (`villager.gd:68`) and 50 anchor warnings. Confirm it yourself, since the count is often a few off.
- Follow the existing `test_player_data.gd` pattern: a fresh `SaveService` with `save_dir = TEST_DIR`, a fresh `PlayerData` wired via seams **before** `add_child_autofree`, and the live autoloads read only (the one default-seam test). `CountingSave` already exists for "exactly one request".
- `assert_push_error("text")` matches the `Log.error` text, so keep the error strings stable and distinctive (`"unknown flag"`, `"not owned"`, `"not in catalogue"`, `"unknown slot"`).
- Save-written assertions need `await wait_process_frames(2)` (deferred write). "No save" assertions also wait 2 frames, then `assert_signal_not_emitted(_save, "save_written")`.
- Mutation pass (the habit from earlier stories): flip the check order, drop the `request_save`, emit before writing, use `<=` for afford, allow equip of not-owned, and drop the same-value no-op. Each mutation should be caught by at least one test. Report honestly if one isn't.

### Previous story intelligence (3.7 and earlier)

- 1.7 built `PlayerData`'s live-read and seam design, and 1.8 added `reset_all`/`profile_replaced`. 2.8 set the "inline the brains write to keep one save request" pattern (`record_run`) and `CountingSave`. Reuse all of these, don't reinvent them.
- From 3.7 and earlier: keep text files LF (Windows CRLF trap, 2.10/3.7). A Python edit once wrote cp1252 and mangled `×`, so edit as UTF-8 or use the Edit tool. Heredocs with apostrophes were mis-parsed in 3.6; prefer scratchpad scripts for generated files.
- The `assert` rule from 3.x: headless GUT turns `assert` into a `SCRIPT ERROR` log line, not an abort. Use `Log` + safe returns.
- `deferred-work.md` holds nothing that blocks this story. Its Router/closet notes (lines ~23–25) belong to 4.4/4.5.

### Git intelligence

- One commit per story, and the working tree was clean at `c76ac33 Story 3.7: zombie groans and voice spacing` when this story was created. Suggested message: `Story 4.1: cosmetic catalogue and brain wallet rules`.
- Recent stories modified tests alongside their code and recorded baseline/final counts plus a mutation pass in the Dev Agent Record. Keep doing that.

### Latest tech notes

- Godot 4.7.2 (pinned in CI), GDScript only. Nothing new is needed: typed `Array[CosmeticItem]` exports, `Texture2D`/`SpriteFrames` exports and named enums are all core Godot 4 features already used in this codebase (`FingerMap.Hand`, `LevelConfig.TargetMode`). No web research changed anything here.
- Named-enum members (`PurchaseResult.OK`) are scoped to the enum in Godot 4 and don't shadow `@GlobalScope.OK`. Still, confirm that `--import` / the test run shows no `SHADOWED_GLOBAL_IDENTIFIER` warning for `player_data.gd`. If one appears, keep the architecture's names and silence it with `@warning_ignore` on the enum line, with a comment.
- Typed array literals in `.tres` use `Array[ExtResource("id")]([ExtResource("a"), ...])` (see `level_registry.tres`). Enum exports serialize as ints (`slot = 1` for PET). `StringName` values serialize as `&"hat_pumpkin"`.

### Project Structure Notes

- New: `scripts/resources/cosmetic_item.gd`, `catalogue.gd`, `economy_config.gd`; `data/cosmetics/catalogue.tres` + 18 `data/cosmetics/<id>.tres`; `data/economy.tres`; `tests/unit/test_catalogue.gd`. Updated: `scripts/autoloads/player_data.gd`, `tests/unit/test_player_data.gd`. This matches the architecture tree and System Location Mapping ("Catalogue & prices: `data/cosmetics/`, `scripts/resources/cosmetic_item.gd`").
- Boundary 5: `data/` holds instances and `scripts/resources/` holds definitions. A `.tres` only references classes from `scripts/resources/`.
- Autoload order `WebPlatform → SaveService → PlayerData → …`: preloading a `.tres` in `player_data.gd` is fine, because it uses no autoload.
- No variance from the architecture except the extra `display_name` field (justified above).

### Project Context Rules

- There is no `project-context.md` in this repo. Rules carried from the architecture and earlier stories: typed GDScript everywhere (`untyped_declaration = Error`). No GDD number as a literal in a script: prices live in the item `.tres` files and the welcome bonus in `economy.tres` (tests may hold literals as guards). Use `Log` with the tags `&"economy"` (wallet/purchase) and `&"save"` (flags, matching settings), and never log personal data. Only `PlayerData` mutates profile state, and only `SaveService` touches files. Signals are typed, past tense and local, with no event bus (ADR-5). Use `Error`/null returns, no `assert` on reachable paths. NFR16: bad data never crashes. Paths in Git Bash on Windows are `/c/...`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.1: Cosmetic Catalogue and Brain Wallet Rules]
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR38, FR39, FR41, FR42, FR43, FR44, FR51, FR52; NFR9, NFR12, NFR16
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27.md] E4-1 (flag API AC)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] M4, M5, Economy (prices, welcome bonus, "no refunds"), Crypt Closet catalogue table
- [Source: _bmad-output/game-architecture.md#State Management] PlayerData method list
- [Source: _bmad-output/game-architecture.md#Static Game Data], #Configuration (EconomyConfig, CosmeticItem), #Data Patterns (`PurchaseResult`, catalogue injection, ids not references), #Event System (`equipment_changed` signature), #Directory Structure, #Error Handling
- [Source: scripts/autoloads/player_data.gd], [Source: scripts/core/save_schema.gd], [Source: tests/unit/test_player_data.gd], [Source: tests/fixtures/saves/save_v1_full.json], [Source: data/levels/level_registry.tres]
- [Source: _bmad-output/implementation-artifacts/3-7-zombie-groans-and-voice-spacing.md] test command, baseline, LF/encoding traps

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline at `c76ac33`: **848** tests, all passing, 3 expected `SCRIPT ERROR` lines (`villager.gd` "Villager state can only move forward"). The story estimated 846; actual is 848.
- Red phase: after adding the tests, `test_player_data.gd` failed to parse (`PurchaseResult` not found), as expected.
- First green run: 902/903. One failure was a wrong expected value in my own `test_brains_never_go_negative` (the sequence buys the witch hat and then the ghost pet with exact change, not the pumpkin hat). I fixed the test; the code was correct.
- Final: **904** tests, all passing (+56: 25 in `test_catalogue.gd`, 31 in `test_player_data.gd`). Still only the same 3 expected `SCRIPT ERROR` lines, no parse errors, and no `SHADOWED_GLOBAL_IDENTIFIER` warning for `PurchaseResult.OK`.
- Mutation pass (each one applied alone, full suite run): owned-before-unavailable, afford-before-owned, drop the buy `request_save`, emit before writing, `<=` for afford, equip not-owned allowed, drop the flag same-value no-op, charge the passed item's price, drop the equip no-op, and `get_equipped` without the owned check. All 10 are caught. "Emit before writing" was **not** caught at first, so I added `test_buy_signals_fire_after_the_write` (listeners read the new brains/owned state), which catches it.

### Completion Notes List

- Added `EconomyConfig`, `CosmeticItem` (`Slot` enum, `SLOT_HAT`/`SLOT_PET`, `slot_key()`, `is_slot_key()`) and `Catalogue` (`get_item`, `items_for_slot`, `validate`, with `GRID_SIZE`/`GRID_COLUMNS` layout consts). All defaults are neutral.
- Shipped data: 18 item `.tres` files, `catalogue.tres` (9 hats then 9 pets, in grid order) and `economy.tres` (`welcome_bonus = 100`). Only `hat_pumpkin` and `pet_cute_ghost` are available, and the art fields are empty (Story 4.3 / Epic 9). I generated them with a throwaway Python script in the temp folder (not committed). The output is LF, with no absolute paths and no uids.
- `PlayerData`: `PurchaseResult`, `inventory_changed`/`equipment_changed`/`flags_changed`, the `catalogue` seam, `buy_item` (catalogue record wins; check order is contract → price ≤ 0 → unavailable → owned → afford; inline wallet write; one save), `owns`/`get_owned_items` (skip junk), `equip`/`unequip`/`get_equipped` (hides a stored id that isn't owned; getters never write), and `set_flag`/`get_flag` (same shape as settings, same value is a no-op). Every existing signature is unchanged. The header comment is updated.
- The design decisions follow Dev Notes exactly: same-value flag no-op, `equip` → bool / `unequip` → void, `Log.error` only for caller bugs, no `assert`.

### File List

- `scripts/resources/economy_config.gd` (new), `scripts/resources/economy_config.gd.uid` (new)
- `scripts/resources/cosmetic_item.gd` (new), `scripts/resources/cosmetic_item.gd.uid` (new)
- `scripts/resources/catalogue.gd` (new), `scripts/resources/catalogue.gd.uid` (new)
- `data/economy.tres` (new)
- `data/cosmetics/catalogue.tres` (new)
- `data/cosmetics/hat_pumpkin.tres`, `hat_witch.tres`, `hat_bunny_ears.tres`, `hat_santa.tres`, `hat_leprechaun.tres`, `hat_heart_headband.tres`, `hat_top_hat.tres`, `hat_pirate.tres`, `hat_crown.tres` (new)
- `data/cosmetics/pet_cute_ghost.tres`, `pet_black_cat.tres`, `pet_spider.tres`, `pet_orange_cat.tres`, `pet_bat.tres`, `pet_crow.tres`, `pet_wolf_dog.tres`, `pet_eyeball.tres`, `pet_brain_buddy.tres` (new)
- `scripts/autoloads/player_data.gd` (modified)
- `tests/unit/test_catalogue.gd` (new), `tests/unit/test_catalogue.gd.uid` (new)
- `tests/unit/test_player_data.gd` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/4-1-cosmetic-catalogue-and-brain-wallet-rules.md` (this story)

### Change Log

- 2026-10-05: Implemented Story 4.1. Added the cosmetic catalogue and economy Resources with their shipped data, and the PlayerData wallet, inventory, equipment and flags API. Tests: 848 → 904, all passing. Status → review.
