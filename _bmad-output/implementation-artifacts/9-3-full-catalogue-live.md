---
baseline_commit: 74aeef4ac2d543631350fcfc8b06c3721031cae3
---

# Story 9.3: Full Catalogue Live

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want every Closet slot to be something I can buy,
so that there are no more "Coming soon" signs.

## Acceptance Criteria

1. **All 18 live (FR75).** The 16 Epic 9 `data/cosmetics/*.tres` files (8 hats from 9.1, 8 pets from 9.2) get `is_available = true`. **That one line per file is the only data change**: ids, display names, slots, rows, prices, icons, overlays and `pet_frames` stay byte-for-byte as they are. `hat_pumpkin.tres`, `pet_cute_ghost.tres` and `catalogue.tres` are untouched.
2. **No "Coming soon" in the shipped Closet.** With the shipped catalogue the Crypt Closet shows **no `LOCKED` tile** on a fresh save, with 100 brains, or with 9999 brains: every tile is `CANT_AFFORD`, `BUY`, `WEAR` or `WEARING`, shows its icon (`%Art` visible, `%Question` hidden), and the info sign shows the item's name, never "Coming soon". Prices stay by row (100 / 200 / 300) and the full set still costs 3600.
3. **Every item buys and wears with the existing flow.** For each of the 18 items (data-driven over the shipped catalogue, not a hand list): Buy → the prompt reads `Buy the <display_name> for <price> brains?` → Yes → owned, brains go down by exactly the price, the jingle plays → Wear → `WEARING`, `PlayerData.get_equipped(slot)` returns it, the other slot is unchanged → Wearing (click) takes it off. Focusing each item previews it in the mirror (hats on `%PreviewZombie`'s `HatSlot`, pets in `%PreviewPet`, `is_showing()` true) with **zero warnings**. No change to `CryptCloset`, `ClosetItemTile`, `ConfirmPrompt` or `PlayerData` is needed for this; if one turns out to be, stop and say why before changing it.
4. **The tutorial still targets the Pumpkin hat.** The guided first purchase (FR45) after the Welcome Gift still points at the first `BUY` tile in grid order, which is the Pumpkin hat (hat index 0, row 1) for any wallet ≥ 100. The integration flow `tests/integration/test_first_purchase_flow.gd` passes unchanged.
5. **Existing saves are untouched (Epic 9 AC 2).** A save from before this story (schema 3, or a v1/v2 save that migrates) that owns the Pumpkin hat and the Cute ghost, wears both and holds a brain balance loads with the new catalogue with **the same owned list (same order), the same equipped hat and pet, and the same brain balance**; opening the Crypt Closet changes none of them and writes nothing. No schema bump: `GameConstants.CURRENT_SCHEMA` stays 3 and `SaveSchema` is unchanged (owned and equipped are id strings; the catalogue is not in the save). Tested with a committed fixture.
6. **The Locked state still works for future items.** `LOCKED` / "Coming soon" stays in `ClosetItemTile` and `PlayerData` (FR40: an `is_available = false` item can't be bought, worn, equipped or previewed). The tests that exercised it through shipped unavailable items now use a per-item copy of the shipped catalogue with a chosen item set unavailable, so that coverage is kept, not deleted.
7. **Plain words for the new names (NFR9).** The 16 new display names go into `tests/unit/test_plain_words.gd` `APPROVED_COPY` (live catalogue names) and the confirm-question pattern accepts a hyphenated name ("Buy the Wolf-dog for 300 brains?"). `test_plain_words.gd` and `test_readability.gd` (which now iterate all 18 live items) pass. EXPERIENCE.md Voice and Tone and the Closet flow text stop saying the other 16 tiles are "Coming soon".
8. **In-game check (gate).** Smuck approves screenshots of the real shipped Closet (temp save): fresh save (all Need N more), 300 brains (rows 1–3 Buy / Need N more mix), and one with a new hat and a new pet worn (preview + main menu). The verbatim answer and date go in `### Review Findings

- [x] [Review][Patch] Hat-fit test swaps `_player.catalogue` and never restores it; hat_witch stays bought/worn into the second half [tests/unit/test_hat_fit_check.gd:~305-327]
- [x] [Review][Patch] Hat-fit test spacing: three blank lines before it, one after (gdlint wants two) [tests/unit/test_hat_fit_check.gd:~305-327]
- [x] [Review][Patch] Pet-only tutorial test never asserts `_tutorial_target` is `pet_cute_ghost`, so it can pass for the wrong reason [tests/unit/test_crypt_closet.gd:~1078]
- [x] [Review][Patch] `test_shipped_closet_has_no_locked_tile` only asserts `!= LOCKED`; AC2 wants one of CANT_AFFORD/BUY/WEAR/WEARING [tests/unit/test_crypt_closet.gd:~409]
- [x] [Review][Patch] Locked-tile tests index `_hats()[1]` and assume it is hat_witch; look the tile up by id [tests/unit/test_crypt_closet.gd:~494-510]
- [x] [Review][Defer] Fixture pins `schema_version` 3, so a later schema bump silently tests migration [tests/fixtures/saves/save_v3_mvp_owned.json] — deferred, pre-existing
- [x] [Review][Defer] Tests hard-code prices (340, 3600, 18, 200 brains) and grid layout (3 columns) [tests/unit/test_crypt_closet.gd, test_player_data.gd] — deferred, pre-existing
- [x] [Review][Defer] Confirm-prompt regex accepts any lowercase-word name; APPROVED_COPY is the only per-name gate [tests/unit/test_plain_words.gd:~53] — deferred, pre-existing
- [x] [Review][Defer] Five-state capture now shows three Can't-afford and three Locked tiles, not one each [tools/capture_screens_runner.gd:~270] — deferred, pre-existing

## Closet Approval`.
9. **No regressions.** Every PNG, every `SpriteAnchors` file, every scene and every runtime script are unchanged: the only non-test code that may change is the doc comment in `scripts/debug/hat_fit_check.gd` and `tools/capture_screens_runner.gd`. Full GUT suite green (baseline **2049** after 9.2; recount at the start), 0 `Parse Error|Compile Error|Failed to load script`.

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 9)
  - [x] 1.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count (2049 expected; the recount is authoritative), the `SCRIPT ERROR` and `WARNING` line counts (9.2 ended at 3 and 160), and grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 1.2 Record the sha256 of the real `user://save.json` (`%APPDATA%/Godot/app_userdata/<project>/save.json`); it must be the same at the end.

- [x] **Task 2: Fix the tests that rely on shipped unavailable items, before flipping anything** (AC: 6) — write the replacement tests first, run them green against today's data, then flip in Task 3 so each red test is one you expected.
  - [x] 2.1 Add a helper (in `test_crypt_closet.gd`, mirroring `_two_hat_catalogue`) `_catalogue_with_unavailable(ids: Array[StringName]) -> Catalogue`: a per-item `duplicate()` of `SHIPPED` (never `duplicate(true)`: it shares external resources and the copy must not touch shipped items) with `is_available = false` on `ids`, `true` on the rest.
  - [x] 2.2 `test_crypt_closet.gd`, rewrite against that helper (or against the shipped data where the test is about live items):
    - `test_fresh_save_shows_cant_afford_and_locked` → split: `test_fresh_save_shows_every_tile_cant_afford` (shipped: all 18 `CANT_AFFORD`, info "Pumpkin hat" / "Need 100 more") and keep a Locked variant on the helper copy (e.g. `hat_witch` + `pet_spider` unavailable → those two `LOCKED`, the rest `CANT_AFFORD`).
    - `test_with_100_brains_both_mvp_items_are_buy` → `test_with_100_brains_every_row_1_item_is_buy` (the 6 row-1 items `BUY`, rows 2–3 `CANT_AFFORD` "Need 100 more" / "Need 200 more").
    - `test_locked_tile_info_is_a_mystery`, `test_locked_and_cant_afford_only_wiggle`: use the helper copy (`_make(copy, true)`); `_hats()[1]` is only locked there.
    - `test_focusing_a_locked_tile_shows_the_equipped_items_quietly`: today it loops over shipped `LOCKED` tiles, which becomes **zero** tiles (a vacuous pass). Use the helper copy with several items unavailable and assert the loop visited them (`checked > 0`).
    - `test_focusing_an_unavailable_pet_with_art_never_previews_it`: keep the guard on the helper copy with the 8 Epic 9 pets unavailable (`checked == 8` stays meaningful).
    - `test_a_pet_only_affordable_catalogue_points_at_the_pet`: today it prices only the pumpkin at 200; with the witch hat and bunny ears live at 100 the arrow would go to the witch hat. Price **every hat** above the wallet in the copy (or make them unavailable) so the pet is still the only affordable item.
    - `test_wearing_a_second_hat_flips_the_first_back_to_wear` / `_two_hat_catalogue`: may now use the shipped witch hat (real art). Optional; if kept, update the helper's doc ("with the Witch hat made available" is no longer the reason).
  - [x] 2.3 `test_closet_item_tile.gd`: `test_a_shipped_unavailable_hat_with_an_icon_stays_hidden` / `..._pet_...` assert the shipped Epic 9 items are unavailable. Replace with: (a) every shipped Epic 9 item now renders its non-locked state with `%Art` visible showing its own icon and `%Question` hidden; (b) the "locked hides the icon" guarantee, kept on a duplicated item with `is_available = false` (one hat, one pet, both with real icons).
  - [x] 2.4 `test_catalogue.gd`: `test_shipped_only_mvp_items_are_available` → `test_shipped_full_catalogue_is_available` (all 18 ids, in grid order, `is_available` true). Keep `test_shipped_mvp_items_have_art` (it already checks every hat and pet has its art); rename it only if you like (`test_shipped_items_have_art`). Add `test_every_available_item_has_its_art`: for every available item, a 32×32 `icon`, and an `overlay` (hat) or `pet_frames` with `idle` (pet) — the guard that a future item can't go live without art.
  - [x] 2.5 `test_player_data.gd`: tests that use the shipped catalogue and assume `hat_witch` is unavailable (`test_loaded_string_ids_are_owned_and_equipped` only asserts it is not owned — fine) — grep `_shipped\|SHIPPED\|CATALOGUE` and check each. The shop tests use a code-built catalogue (`_make_shop`, `_item(..., available)`) and are unaffected.
  - [x] 2.6 Grep the whole `tests/` tree for other shipped-availability assumptions: `is_available`, `LOCKED`, `"Coming soon"`, `hat_witch`, `pet_black_cat`, `before Story 9.3`, `Epic 9`. Known: `test_plain_words.gd` (Task 4), `test_readability.gd` (iterates live items: just gets bigger), `test_hat_fit_check.gd` (E on a new item: see Task 5), `test_grayscale_states.gd` / `test_hat_slot.gd` / `test_pet_slot.gd` (code-built items: unaffected).

- [x] **Task 3: Switch the catalogue on** (AC: 1, 2)
  - [x] 3.1 In each of `hat_witch`, `hat_bunny_ears`, `hat_santa`, `hat_leprechaun`, `hat_heart_headband`, `hat_top_hat`, `hat_pirate`, `hat_crown`, `pet_black_cat`, `pet_spider`, `pet_orange_cat`, `pet_bat`, `pet_crow`, `pet_wolf_dog`, `pet_eyeball`, `pet_brain_buddy` `.tres`: `is_available = false` → `is_available = true`. Edit the text, never re-save through `ResourceSaver` (it rewrites ids and `load_steps`). LF endings. `git diff --stat` must show exactly 16 files, 1 line each.
  - [x] 3.2 `--import`, full suite. Only the tests you expected in Task 2 should have needed changes; anything else red is a real finding (read it, don't just update the assertion).

- [x] **Task 4: Plain words and the UX copy** (AC: 7)
  - [x] 4.1 `tests/unit/test_plain_words.gd`: add the 16 names to `APPROVED_COPY` under "Live catalogue items": Witch hat, Bunny ears, Santa hat, Leprechaun hat, Heart headband, Top hat, Pirate hat, Golden crown, Black cat, Spider, Orange cat, Bat, Crow, Wolf-dog, Floating eyeball, Brain buddy. Update the confirm pattern so a name may contain a hyphenated word: e.g. `"^Buy the [A-Z][a-z]+(-[a-z]+)?( [a-z]+(-[a-z]+)?)* for \\d+ brains\\?$"`. Keep it tight (no digits, no apostrophes, no caps after the first letter). Update the header doc's "Live catalogue items" line.
  - [x] 4.2 Note the shipped names differ from the GDD/epics price table ("Valentine heart headband" → **Heart headband**, "New Year's top hat" → **Top hat**): the short names have shipped since Story 4.1 (they fit the tile info sign and avoid the apostrophe). Keep the shipped names; the data is the source of truth. Mention it in Completion Notes.
  - [x] 4.3 Check the RANKS / SLANG / TECHNICAL / all-caps rules pass for the new names (none should trip: "Golden crown" and "Brain buddy" contain no slang; `brains{2,}` needs a double s).
  - [x] 4.4 `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md`: Flow 2 step 2 ("the other 16 tiles are '?' silhouettes marked 'Coming soon'") → say that was the MVP and post-Epic 9 all 18 tiles show their item and price; Closet tiles copy row: "Coming soon" stays (the state still exists for future items) — add "(no shipped item after Story 9.3)". Small, factual edits only; no other UX changes.

- [x] **Task 5: Debug tools that assumed locked items** (AC: 9)
  - [x] 5.1 `scripts/debug/hat_fit_check.gd` header doc: the "E only wears available items… the Epic 9 hats and pets before Story 9.3" note is now stale. Rewrite: E buys and wears any item; an `is_available = false` item (none ship today) warns "could not buy". Check `test_hat_fit_check.gd::test_e_wears_for_real_and_none_unequips` and any test that expected a "could not buy" warning on a shipped item; such a test now needs a copied catalogue with that item unavailable.
  - [x] 5.2 `tools/capture_screens_runner.gd::_five_state_catalogue` (around l.265): it borrows the pumpkin's art for the witch hat, bunny ears and heart headband and relies on "the rest" being Locked. Make it use the items' **own** art (now shipped) and set a named few items `is_available = false` in the copy so the Closet capture still shows all five states (Wearing, Wear, Buy, Can't afford, Locked). Update its doc. Don't regenerate the committed `capture_screens` outputs unless the tool's own tests require it.
  - [x] 5.3 `scripts/debug/ui_art_review.gd` only draws the `ui_locked.png` sprite; nothing to change (confirm).

- [x] **Task 6: New tests for the live flow** (AC: 2, 3, 4)
  - [x] 6.1 `test_crypt_closet.gd::test_shipped_closet_has_no_locked_tile`: shipped catalogue at 0, 100 and 9999 brains → no tile `LOCKED`, every `%Art` visible with `texture == item.icon`, every `%Question` hidden; focusing every tile gives info line 0 == display name (never "Coming soon").
  - [x] 6.2 `test_every_shipped_item_buys_and_wears`: 3600 brains (the full set); for each of the 18 tiles in order: activate (BUY) → prompt text `Buy the %s for %d brains?` → Yes → owned, brains − price, `sfx_purchase` recorded → activate (WEAR) → `WEARING`, `get_equipped(slot_key)` == id → activate (WEARING) → unequipped. End: 18 owned, brains 0. `assert_push_warning_count(0)` and no `push_error`.
  - [x] 6.3 `test_focusing_every_shipped_item_previews_it` (the 9.2 review deferral): for each tile, focus → hats: `%PreviewZombie`'s `HatSlot.get_item_id() == id`; pets: `%PreviewPet.get_item_id() == id` and `is_showing()`; the other slot keeps the equipped item. Zero warnings.
  - [x] 6.4 Tutorial: `test_tutorial_targets_the_pumpkin_hat_with_the_full_catalogue` at 100 and at 300 brains (arrow on hat index 0, `HAT_BUY_ARROW`). The existing `test_tutorial_guides_buy_yes_wear_on_the_pumpkin_hat` should already cover 100; add the 300 case.
  - [x] 6.5 `tests/integration/test_first_purchase_flow.gd`: run unchanged. If it asserted any other tile `LOCKED`, fix that assertion only.

- [x] **Task 7: Save compatibility** (AC: 5)
  - [x] 7.1 New fixture `tests/fixtures/saves/save_v3_mvp_owned.json`: schema 3, `owned_items: ["hat_pumpkin", "pet_cute_ghost"]`, `equipped: {"hat": "hat_pumpkin", "pet": "pet_cute_ghost"}`, `brains: 340`, flags `welcome_bonus_claimed`/`tutorial_seen`/`placement_done` true, a tier, a couple of run_history records (copy shapes from `save_v1_full.json` after migration; keep it valid for `SaveSchema.prepare`). LF, tab-indented, keys sorted like `save_v3_fresh.json`.
  - [x] 7.2 `test_player_data.gd` (pattern: `_put_fixture` + `_make()` with the **shipped** catalogue): `test_an_mvp_save_loads_unchanged_with_the_full_catalogue` — owned list == `[&"hat_pumpkin", &"pet_cute_ghost"]` in order, equipped hat/pet unchanged, brains 340; buying a new 200 item works and leaves the old two owned and worn. Also run the same assertions on `save_v1_full.json` (the migrating path; it owns the same two).
  - [x] 7.3 `test_crypt_closet.gd` (or an integration test): load that fixture into a temp `SaveService`, open the Closet, leave with Esc → owned, equipped and brains unchanged and **no save request** from the Closet itself (`CountingSave.requests` unchanged across open + leave).
  - [x] 7.4 Assert in a test that `GameConstants.CURRENT_SCHEMA == 3` is unchanged only if one doesn't already exist (`test_save_schema.gd` likely has it; don't duplicate).

- [x] **Task 8: Gate: the live Closet** (AC: 8)
  - [x] 8.1 Scratch capture script (pattern: `tools/capture_screens.gd` and the 9.2 gate-2 launcher, which loads the runner Node at runtime because `-s` scripts compile before autoloads exist). Temp-dir `SaveService` + `PlayerData` with the **shipped** catalogue (no injection needed any more). Real window, not `--headless`. Record `user://save.json` sha256 before/after.
  - [x] 8.2 Shots into `_bmad-output/implementation-artifacts/screenshots/9-3/`: `closet-fresh.png` (0 brains: 18 tiles, Need N more), `closet-300.png` (300 brains: rows 1–3 Buy, focus on a row-3 pet so the preview shows it), `closet-wearing.png` (Witch hat and Wolf-dog owned and worn: Wearing tags, preview), `main-menu-wearing.png` (same save), and one grayscale copy of `closet-300.png` (`tools/capture_screens.gd -- --convert <png>`).
  - [x] 8.3 Show Smuck. Ask: does the full Closet read clearly (no tile looks locked, prices and states legible), and is anything off? Record the verbatim answer with the date in `## Closet Approval`.

- [x] **Task 9: Verification and wrap-up** (AC: 9)
  - [x] 9.1 `--import`, full suite; before/after counts; grep for `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` and `WARNING` counts vs the baseline (report any change honestly).
  - [x] 9.2 `git diff --stat -- scripts scenes data/anchors data/levels assets project.godot` shows only `scripts/debug/hat_fit_check.gd` (doc). `data/cosmetics/` shows exactly the 16 one-line flips.
  - [x] 9.3 Mutation pass (project habit): set one Epic 9 item back to `is_available = false`; give one item a null `icon`; drop `-dog` support from the plain-words pattern; make the save fixture own a third id (`hat_witch`) and check the loads-unchanged test notices; price a hat in a duplicated catalogue so the tutorial would target the witch hat; remove the `checked > 0` guard and confirm the vacuous-loop test is caught. Each should fail a test; report honestly any that survive and close the gap.
  - [x] 9.4 `deferred-work.md`: add "Deferred from: dev of story-9.3". Resolve (mark resolved, with a one-liner) the 9.1/9.2 entries this story closes: "stay `is_available = false` … Story 9.3 switches the full catalogue on" (both), "Closet/focus tests only exercise unavailable pets" (closed by 6.3). The `HatSlot.show_item` / `PetSlot.show_item` don't check `is_available` note: decide (recommended: leave it — every caller already filters through `PlayerData.get_equipped` or the Closet's `focused.is_available`, and no shipped item is unavailable now) and record the decision.
  - [x] 9.5 Update this file's Dev Agent Record and File List; `sprint-status.yaml` 9-3 → `review`.

## Dev Notes

### What this story is (and isn't)

- **Is:** 16 one-line data flips, the tests that assumed those items were locked rewritten (keeping the Locked coverage on copies), new data-driven tests that every shipped item can be bought, worn and previewed, a save-compatibility fixture and test, the plain-words list, two stale debug-tool notes, a small UX doc correction and one screenshot gate.
- **Isn't:** new art, new items, price changes, a save-schema change, any change to `PlayerData`, `SaveService`, `SaveSchema`, `CryptCloset`, `ClosetItemTile`, `ConfirmPrompt`, `HatSlot`, `PetSlot`, `ProfessorZombie`, the HUD, the menu, the report card or any level. Juice for the Closet (counter tick-down), item reactions, more pet animations, and Epic 10/11 work.
- This should be a small diff. If you find yourself editing a runtime script, something is wrong: stop and explain.

### What already works (do not rebuild it)

- **Availability is one bool, read in exactly five places** (all already correct for live items):
  - `PlayerData.buy_item` (`scripts/autoloads/player_data.gd:~229`) → `UNAVAILABLE` when false; the catalogue's own record decides.
  - `PlayerData.equip` (~272) rejects an unavailable item; `get_equipped` (~308) hides one.
  - `ClosetItemTile.state_for` / `show_state` (`scripts/ui/closet_item_tile.gd:~67, 117`): `LOCKED` wins over everything; `setup` warns once for an available item with no icon (every shipped item has one, tested in `test_catalogue.gd`).
  - `CryptCloset._show_preview` (`scripts/screens/crypt_closet.gd:~262`) previews the focused item only if available.
- **Art and data are already wired and approved**: 9.1 (hats: overlay, centred icon, `SpriteAnchors` fit on every pose, Professor and Horde Rush size classes) and 9.2 (pets: `pet_frames`, centred icon, fits every slot). Both stories' Gate 2 already approved the in-game look with injected "available" catalogues, so this story's gate is about the Closet as a whole, not each item again.
- **The catalogue** (`data/cosmetics/catalogue.tres`) already lists all 18 in grid order; `Catalogue.validate()` passes; full set = 3600.
- **Tutorial target** = `_first_tile_in(BUY)` over hats then pets (`crypt_closet.gd::_start_tutorial`), so the Pumpkin hat (hat index 0) stays the target for any wallet ≥ 100. Nothing to change, only tests to add.
- **Save**: `owned_items` (Array of id Strings) and `equipped` ({"hat", "pet"} → id String) store ids only; the catalogue is code-side. `get_owned_items` dedupes and skips junk; `get_equipped` returns "" for an id not owned. No migration needed.

### Existing code: current state, what changes, what must be preserved

- `data/cosmetics/hat_{witch,bunny_ears,santa,leprechaun,heart_headband,top_hat,pirate,crown}.tres` (UPDATE, 1 line each; `is_available` is line 18 today).
- `data/cosmetics/pet_{black_cat,spider,orange_cat,bat,crow,wolf_dog,eyeball,brain_buddy}.tres` (UPDATE, 1 line each; line 54).
- `tests/unit/test_catalogue.gd`, `test_crypt_closet.gd`, `test_closet_item_tile.gd`, `test_plain_words.gd`, `test_player_data.gd`, possibly `test_hat_fit_check.gd` (UPDATE).
- `tests/fixtures/saves/save_v3_mvp_owned.json` (NEW).
- `scripts/debug/hat_fit_check.gd` (UPDATE, doc only), `tools/capture_screens_runner.gd` (UPDATE, `_five_state_catalogue`).
- `EXPERIENCE.md` (UPDATE, two factual lines), `deferred-work.md`, `sprint-status.yaml`.
- **Must not change:** `scripts/autoloads/*`, `scripts/core/*`, `scripts/ui/*`, `scripts/screens/*`, `scripts/cosmetics/*`, `scripts/characters/*`, `scripts/levels/*`, `scripts/resources/*`, every scene, every PNG, `data/anchors/*`, `data/levels/*`, `data/cosmetics/catalogue.tres`, `hat_pumpkin.tres`, `pet_cute_ghost.tres`, `project.godot`, the save schema.

### Known test fallout (so you are not surprised)

| Test | Why it breaks | Fix |
|---|---|---|
| `test_catalogue.gd::test_shipped_only_mvp_items_are_available` | expects only 2 available | all 18 (Task 2.4) |
| `test_closet_item_tile.gd::test_a_shipped_unavailable_{hat,pet}_with_an_icon_stays_hidden` | asserts `is_available` false | live-art check + locked check on a copy (2.3) |
| `test_crypt_closet.gd::test_fresh_save_shows_cant_afford_and_locked` | 16 tiles no longer LOCKED | split (2.2) |
| `test_crypt_closet.gd::test_with_100_brains_both_mvp_items_are_buy` | still passes, but the name lies | widen to all 6 row-1 items |
| `test_crypt_closet.gd::test_locked_tile_info_is_a_mystery`, `test_locked_and_cant_afford_only_wiggle` | `_hats()[1]` is the live witch hat | helper copy |
| `test_crypt_closet.gd::test_focusing_a_locked_tile_shows_the_equipped_items_quietly` | **silently passes with 0 iterations** | helper copy + `checked > 0` |
| `test_crypt_closet.gd::test_focusing_an_unavailable_pet_with_art_never_previews_it` | `checked == 8` → 0 | helper copy |
| `test_crypt_closet.gd::test_a_pet_only_affordable_catalogue_points_at_the_pet` | witch hat / bunny ears at 100 become the target | price all hats out |
| `test_plain_words.gd` | 16 new live names not approved; "Wolf-dog" fails the confirm regex | Task 4.1 |
| `test_readability.gd::test_confirm_prompt_fits_every_live_question` | now asks 18 questions — should pass (`test_the_question_fits_for_every_shipped_item` already checks all 18 names) | none expected |

### Testing notes

- Commands as in Task 1. Run `--import` before tests.
- Never write the developer's real save: temp-dir `SaveService` + `PlayerData` (patterns: `test_crypt_closet.gd::_make_player_data`, `test_player_data.gd::_put_fixture`). `test_hud.gd` / `test_report_card.gd` use the live `PlayerData` autoload (deferred-work 4.3): once the new items are live, a new hat or pet equipped in the dev machine's real save **will now actually show** in those tests. They use 32×32 frame-rect layout checks that hold for every shipped item (9.1/9.2), but if one flakes, check the real save first.
- Per-item `duplicate()` for catalogue copies; never mutate `SHIPPED` items in a test (they are preloaded, shared across the whole run, and a flipped flag leaks into later tests).
- Sort `String`s, never `StringName`s (they compare by interned pointer; 9.1 hit this).
- GUT 9.7.1: `assert()` shows as `SCRIPT ERROR` in headless runs; use `assert_push_warning_count` / `assert_push_error` as the existing Closet tests do.
- GUT silently skips a script that fails to parse; always grep the log (8.6 shipped a skipped test file).

### Previous story intelligence

- **9.2 (pets):** final count 2049; all pet data wired, `is_available = false` kept and guarded by `test_shipped_only_mvp_items_are_available` (the guard you are now replacing on purpose). Review deferred to this story: "add an available-pet preview test (`PetSlot.is_showing()` per new pet)" → Task 6.3. Gate captures injected a per-item catalogue copy with the pets available; that injection is no longer needed. The real `user://save.json` hash was identical before and after.
- **9.1 (hats):** same pattern; review deferred "`HatSlot.show_item` does not check `is_available` … revisit in 9.3" → Task 9.4 decision. `_two_hat_catalogue` in `test_crypt_closet.gd` exists only because the witch hat was unavailable.
- **4.4 / 4.5 (Closet, tutorial):** the five tile states, Locked wins, the tutorial picks the first Buy tile hats-then-pets and ends on the first equip. 4.4's AC "16 slots show a locked '?' labeled 'Coming soon'" (FR42) was the MVP rule; FR75 supersedes it.
- **5.2 (plain words):** new live copy must be added to `APPROVED_COPY` on purpose ("A newly live item is added here on purpose"). This story is exactly that case.
- **Traps:** keep files LF (`.gitattributes eol=lf`; working copies may be CRLF via `core.autocrlf`, so normalise before scripted matching). `untyped_declaration = Error` applies to tools and tests (type every `for` variable). The flaky `test_audio_manager` pool test: rerun once before investigating. Untracked `screenshots/8-7/*.jpg.import` were committed in 74aeef4; check `git status` is clean before starting.

### Git intelligence

- Recent: `74aeef4 Add Godot import files for Story 8.7 screenshots`, `f8944cd Story 9.2: eight new pets, code review patches applied, done`, `9d498a4 Story 9.1: eight new hats…`. One commit per story, with code, data, tests, screenshots, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape here: 16 `.tres` one-liners, ~5 test files, 1 fixture, 2 debug/tool files, 1 UX doc, `screenshots/9-3/`. Suggested message: `Story 9.3: full catalogue live`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries or APIs. Godot 4.7.2 standard, Compatibility renderer, GDScript only, statically typed.
- `Resource.duplicate()` (shallow) copies the item's exported properties, sharing the textures/`SpriteFrames` by reference, which is what the copies want (real art, own `is_available`). `duplicate(true)` in 4.x does not deep-copy external resources anyway, and is unnecessary here.
- A `.tres` edited as text is re-read on `--import`/load; no uid changes are involved in flipping a bool.

### Project Structure Notes

- All paths follow the architecture (`data/cosmetics/<id>.tres`, fixtures under `tests/fixtures/saves/`, debug code only under `scripts/debug/`, tools under `tools/`). No variance.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Static data comes through `@export` Resources in `data/`; availability is data, never a code switch.
  - Saves store item ids; ids are permanent once shipped (never rename an id to "fix" a name).
  - Typed GDScript, tabs, short `##` docs that say why, LF endings; `%UniqueName` node refs.
  - Debug code only in `scenes/debug/` / `scripts/debug/` (Boundary 7).
  - FR38: brains are spent only on cosmetics and never gate learning content.
  - NFR9 plain words, NFR10 kid-safe, NFR11 no timers outside runs, NFR16 a missing cosmetic never stops anything.
  - Visible changes wait for Smuck's approval, recorded verbatim with the date.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 9: Full Crypt Closet, Story 9.3: Full Catalogue Live]; FR39, FR40, FR42 (MVP rule, superseded), FR45, FR51, FR75; NFR9, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Crypt Closet price table (~l.280–284)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] Voice and Tone (l.51–67), Flow 2 (l.259), component table (tutorial-arrow l.96), Closet states (l.137–140)
- [Source: _bmad-output/implementation-artifacts/9-1-eight-new-hats.md], [9-2-eight-new-pets.md] (data, gates, deferrals), [4-4-crypt-closet.md], [4-5-welcome-gift-and-guided-first-purchase.md], [5-2-readability-color-and-plain-words-check.md]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 9.1 and 9.2 sections (l.~786–811)
- [Source: scripts/autoloads/player_data.gd buy_item/equip/get_equipped], [scripts/ui/closet_item_tile.gd state_for/show_state/setup], [scripts/screens/crypt_closet.gd _show_preview/_start_tutorial/_first_tile_in], [scripts/resources/catalogue.gd], [scripts/resources/cosmetic_item.gd], [scripts/core/save_schema.gd], [scripts/debug/hat_fit_check.gd header/_wear], [tools/capture_screens_runner.gd _five_state_catalogue]
- [Source: tests/unit/test_catalogue.gd, test_crypt_closet.gd, test_closet_item_tile.gd, test_plain_words.gd (APPROVED_COPY, APPROVED_PATTERNS), test_readability.gd, test_player_data.gd (_put_fixture, FULL_PATH), tests/integration/test_first_purchase_flow.gd, tests/fixtures/saves/]

## Closet Approval

<!-- Task 8: Smuck's answer verbatim with the date. -->

**Gate (the live Closet, 2026-10-14):** shown `screenshots/9-3/closet-fresh.png`, `closet-300.png` (+ `closet-300-gray.png`),
`closet-wearing.png` and `main-menu-wearing.png` (the real shipped catalogue, temp-dir save). Asked whether the full Closet
reads clearly (no tile looks locked, prices and states legible) and whether anything is off. Smuck:

> Approved, the closet reads clearly, nothing looks locked

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): 2049 tests, 2049 passing; 3 `SCRIPT ERROR`, 160 `WARNING` lines; 0 `Parse Error|Compile Error|Failed to load script`. Real `save.json` sha256 `2859cbaa61d4fc9a...`.
- Task 2 against the unflipped data: exactly 5 reds, all "is live" assertions (`test_shipped_full_catalogue_is_available`, `test_every_shipped_epic_9_item_shows_its_own_icon`, `test_fresh_save_shows_every_tile_cant_afford`, `test_with_100_brains_every_row_1_item_is_buy`, `test_e_wears_a_new_hat_and_warns_on_an_unavailable_one`); every Locked-on-a-copy test already green.
- Task 3 after the flip: only `test_plain_words.gd::test_every_string_is_approved_copy` red (the 16 names), fixed in Task 4. `test_readability.gd` passed unchanged with 18 live items.
- Final (Task 9.1): 2058 tests, 2058 passing (+9); 0 parse/compile errors; `SCRIPT ERROR` 3 (unchanged); `WARNING` 161 (+1: the deliberate, asserted `fit check: could not buy hat_crown` in the new fit-check test). Real `save.json` sha256 unchanged.
- Mutation pass (Task 9.3), each caught: Crow back to `is_available = false` (8 tests); Santa hat with no icon (8 tests, incl. `test_every_available_item_has_its_art`); `-dog` dropped from the confirm pattern (`test_every_string_is_approved_copy`, `test_the_rules_bite`); fixture owns `hat_witch` too (both old-save tests); pet-only tutorial copy pricing only the pumpkin (`test_a_pet_only_affordable_catalogue_points_at_the_pet`); Locked-loop copy with nothing locked (`test_focusing_a_locked_tile_shows_the_equipped_items_quietly`, the `checked` guard). None survived.
- Mutation-run incident: one batch restored files with `git checkout`, which reverted `test_crypt_closet.gd` to HEAD and could not restore the untracked fixture. Both were rebuilt from the post-mutation copies with the mutation undone and checked; the final suite run is on the restored files.

### Completion Notes List

- **Data (AC 1):** 16 `.tres` files, `is_available = false` -> `true`, text edit only (LF); `git diff --numstat` 16 files +16 -16. `hat_pumpkin`, `pet_cute_ghost`, `catalogue.tres` untouched.
- **Locked coverage kept (AC 6):** `_catalogue_with_unavailable(ids)` (per-item shallow `duplicate()`, never touches `SHIPPED`) and `_make_with()` in `test_crypt_closet.gd`; the Locked, mystery-info, wiggle, quiet-focus (now asserts `checked == locked.size()`) and unavailable-pet-preview tests use it. `test_closet_item_tile.gd` keeps "locked hides a real icon" on duplicated Witch hat / Black cat. `_two_hat_catalogue` removed: the second-hat test uses the shipped Witch hat with its own art.
- **New tests (AC 2-4):** `test_shipped_closet_has_no_locked_tile` (0 / 100 / 9999), `test_with_100_brains_every_row_1_item_is_buy`, `test_every_shipped_item_buys_and_wears` (all 18, 3600 brains -> 0, prompt text, jingle, wear, other slot unchanged, take off, 0 warnings/errors), `test_focusing_every_shipped_item_previews_it` (9.2 review deferral), `test_tutorial_targets_the_pumpkin_hat_with_the_full_catalogue` (100 and 300), `test_every_shipped_epic_9_item_shows_its_own_icon`, `test_shipped_full_catalogue_is_available`, `test_every_available_item_has_its_art`. `test_first_purchase_flow.gd` passes unchanged.
- **Saves (AC 5):** new fixture `save_v3_mvp_owned.json` (schema 3, owns and wears the MVP pair, 340 brains, tier 1, two runs, a Horde Rush unlock). `test_an_mvp_save_loads_unchanged_with_the_full_catalogue` runs on it and on `save_v1_full.json` (migrating path); `test_an_mvp_save_opens_and_leaves_the_full_closet_unchanged` checks no save request and the file byte-identical after open + Esc. `CURRENT_SCHEMA == 3` is already pinned in `test_smoke.gd` (not duplicated). No `SaveSchema` change.
- **Plain words (AC 7):** the 16 names in `APPROVED_COPY`; confirm pattern `^Buy the [A-Z][a-z]+(-[a-z]+)?( [a-z]+(-[a-z]+)?)* for \\d+ brains\\?$`, with new `test_the_rules_bite` cases proving it accepts "Wolf-dog" / "Floating eyeball" and rejects apostrophes, digits, a capital after the hyphen, and double / leading / trailing hyphens. The shipped names differ from the GDD/epics table ("Valentine heart headband" -> **Heart headband**, "New Year's top hat" -> **Top hat**); kept as shipped since 4.1 (fit the info sign, no apostrophe). EXPERIENCE.md: two factual lines (Flow 2 step 2, Closet tiles copy row).
- **Tools (AC 9):** `hat_fit_check.gd` header doc only, backed by the new `test_e_wears_a_new_hat_and_warns_on_an_unavailable_one`. `capture_screens_runner.gd::_five_state_catalogue` now uses each item's own art and makes the row-3 hats unavailable; verified at runtime in the gate script (all five states on the Hats grid, own art, shipped items untouched). Committed `screenshots/5-2` outputs not regenerated (noted in deferred-work). `ui_art_review.gd` only draws `ui_locked.png`: no change.
- **Gate (AC 8):** approved by Smuck 2026-10-14 (verbatim in `## Closet Approval`). Captures by a scratch launcher + runner outside the repo, temp-dir save, shipped catalogue with no injection.
- **Deferred work (9.4):** 9.1/9.2 "stay unavailable" entries and the available-pet preview gap marked resolved; `HatSlot`/`PetSlot.show_item` not checking `is_available`: decided to leave (callers filter; nothing ships unavailable). New "Deferred from: dev of story-9.3" section.

### File List

- `data/cosmetics/hat_witch.tres`, `hat_bunny_ears.tres`, `hat_santa.tres`, `hat_leprechaun.tres`, `hat_heart_headband.tres`, `hat_top_hat.tres`, `hat_pirate.tres`, `hat_crown.tres` (modified, 1 line each)
- `data/cosmetics/pet_black_cat.tres`, `pet_spider.tres`, `pet_orange_cat.tres`, `pet_bat.tres`, `pet_crow.tres`, `pet_wolf_dog.tres`, `pet_eyeball.tres`, `pet_brain_buddy.tres` (modified, 1 line each)
- `tests/unit/test_catalogue.gd` (modified)
- `tests/unit/test_closet_item_tile.gd` (modified)
- `tests/unit/test_crypt_closet.gd` (modified)
- `tests/unit/test_hat_fit_check.gd` (modified)
- `tests/unit/test_plain_words.gd` (modified)
- `tests/unit/test_player_data.gd` (modified)
- `tests/fixtures/saves/save_v3_mvp_owned.json` (new)
- `scripts/debug/hat_fit_check.gd` (modified, doc only)
- `tools/capture_screens_runner.gd` (modified, `_five_state_catalogue`)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/9-3/closet-fresh.png`, `closet-300.png`, `closet-300-gray.png`, `closet-wearing.png`, `main-menu-wearing.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/9-3-full-catalogue-live.md` (this file)

### Change Log

- 2026-10-14: Story 9.3 implemented: full catalogue live (16 data flips), Locked coverage moved to catalogue copies, data-driven buy/wear/preview/tutorial/old-save tests, plain-words list and pattern, two stale tool notes, UX doc correction; gate approved; mutation pass clean. Status -> review.
