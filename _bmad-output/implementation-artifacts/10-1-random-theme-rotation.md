---
baseline_commit: 8b1fe1b
---

# Story 10.1: Random Theme Rotation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want each level to look a bit different each time I play,
so that it stays fresh even after many runs.

## Acceptance Criteria

1. **Themes live in the level registry (FR76).** A new typed Resource `LevelTheme` (`scripts/resources/level_theme.gd`) holds one look: `id: StringName`, `backdrop: PackedScene`, `defender: PackedScene` (Horde Rush only; null elsewhere) and `music_id: StringName` (empty = the level config's `music_id`). It has **no gameplay field** (no timing, speed, count, brains or word setting). `LevelEntry` gets `@export var themes: Array[LevelTheme] = []`. The shipped registry gives each real level exactly **one** theme, the look it has today:
   - Zombie Run → `sunny_village_green` (the Sunny Village Green backdrop)
   - Horde Rush → `farmhouse` (field + farmhouse backdrop, defender = `farmer.tscn`)
   - Pitchfork Panic → `moonlit_village` (the Moonlit Village backdrop with its moon)
   The three debug test levels keep `themes = []`.
2. **One theme per run, never the previous one (FR76).** When `RunFrame` starts a level with themes, it picks one with a new pure `ThemePicker`: 1 theme → that theme (no random draw); 2+ themes → uniform among the themes whose id is not the level's saved last theme (if the saved id is empty or not in the list, uniform among all). The picked theme is applied **before** the level enters the tree, its id is saved as that level's last theme, and `RunFrame.get_theme_id()` returns it. A level with no themes plays exactly as today (no apply, nothing saved).
3. **The last theme per level is saved through a schema migration with a fixture test.** Schema **v4**: every profile gets `last_themes: {level_id: theme_id}` (Strings). `SaveSchema.migrate_3_to_4` adds `{}` (keeps an existing Dictionary, replaces a non-Dictionary, skips junk profiles with a warning, like `migrate_2_to_3`), `GameConstants.CURRENT_SCHEMA = 4`, `profile_defaults()` has `"last_themes": {}`. New fixture `tests/fixtures/saves/save_v4_fresh.json` equals `SaveSchema.defaults()`; the v1, v2 and v3 fixtures stay byte-identical as migration inputs. `PlayerData.get_last_theme(level_id) -> StringName` and `set_last_theme(level_id, theme_id)` are the only read/write (an unchanged value writes nothing; a change requests one save).
4. **Rules never change with the theme (FR76).** Only art and music may differ. Proved by tests: (a) `LevelTheme`'s script property list holds only `id`, `backdrop`, `defender`, `music_id`; (b) with a code-built registry whose level has two themes, the same seed gives the **same target sequence and the same `LevelConfig`** whichever theme is picked; (c) the theme draw never touches the run RNG (a seeded run deals the same targets as before this story; existing seed-pinned tests pass unchanged).
5. **A level with one theme works without error, so themes can be added one at a time.** With the shipped registry, each of the three real levels starts through `RunFrame` with its single theme, zero errors and zero warnings, and looks exactly as before (same backdrop textures, sky colour, moon, field, farmhouse, farmer, positions, draw order). A theme with a null backdrop (or null defender for Horde Rush) logs one warning and the level keeps its built-in look (NFR16).
6. **Validation.** `LevelRegistry.validate()` also reports: a null theme, an empty theme id, a duplicate theme id within one entry, a theme with no backdrop. A test asserts the shipped registry validates and every non-debug entry has at least one theme.
7. **Debug and replay.** The F3 overlay's run section shows the theme id (debug build only; never shown to the kid). A RUN payload may carry `"theme": StringName` to force a theme (tests and future gate captures); an id not in the list logs a warning and falls back to the normal pick. The theme is chosen from the run seed through its own RNG, so a pinned seed (F2) replays the same theme too when the saved last theme is the same.
8. **No regressions.** Full GUT suite green; the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except for deliberate, asserted ones. The real `user://save.json` is untouched by the test run (sha256 identical before and after).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 8)
  - [x] 1.1 `git status` clean. `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count (9.3 ended at 2058; the recount is authoritative), the `SCRIPT ERROR` (3) and `WARNING` (161) line counts, and grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 1.2 Record the sha256 of the real `user://save.json` (`%APPDATA%/Godot/app_userdata/<project>/save.json`).

- [x] **Task 2: Save schema v4** (AC: 3) — do this first; it is pure and fully testable.
  - [x] 2.1 `scripts/core/save_schema.gd`: add `"last_themes": {}` to `profile_defaults()`; add `migrate_3_to_4` (copy the shape of `migrate_2_to_3`, warnings `"migrate_3_to_4: profiles is not a dictionary, skipping"` / `"migrate_3_to_4: profiles/%s is not a dictionary, skipping"`); register it in `migration_steps()` at index 2; extend the class doc with a `## v4 (Story 10.1) ...` line.
  - [x] 2.2 `scripts/core/game_constants.gd`: `CURRENT_SCHEMA = 4`. `tests/unit/test_smoke.gd:12`: expect 4 with the message `"Story 10.1: schema v4 (last_themes)"`.
  - [x] 2.3 New `tests/fixtures/saves/save_v4_fresh.json`: generate it from `JSON.stringify(SaveSchema.defaults(), "\t")` (keys sorted the way the v3 one is; LF, no trailing newline difference — compare with how `save_v3_fresh.json` ends). Keep `save_v3_fresh.json` unchanged.
  - [x] 2.4 `tests/unit/test_save_schema.gd`: `FRESH_PATH` → v4; add `V3_FRESH_PATH`; rename `test_defaults_match_v3_fixture` → `..._v4_...`; `test_prepare_round_trips_full_fixture` expects `last_themes: {}` among the additions; `test_prepare_v1_reaches_v3` → reaches v4; new `test_migration_steps_register_3_to_4` (index 2), `test_migrate_3_to_4_adds_last_themes` (v3 fresh fixture → prepare == defaults), `test_migrate_3_to_4_keeps_existing_dict`, `test_migrate_3_to_4_replaces_a_non_dict`, `test_migrate_3_to_4_survives_junk` (with `assert_push_warning`).
  - [x] 2.5 `tests/unit/test_save_service.gd:9-10`: `FRESH_PATH` → `save_v4_fresh.json` and its comment ("v4 since Story 10.1").
  - [x] 2.6 `scripts/autoloads/player_data.gd`: `get_last_theme(level_id: StringName) -> StringName` (a missing key, a non-Dictionary `last_themes` or a non-String value reads as `&""`) and `set_last_theme(level_id: StringName, theme_id: StringName) -> void` (ignores an empty level id; unchanged value → no write, no save; otherwise stores Strings and `save_service.request_save()`). No new signal (nothing listens). Add a `## Last themes (Story 10.1, FR76): ...` paragraph to the class doc. `reset_all` needs nothing (defaults).
  - [x] 2.7 `tests/unit/test_player_data.gd`: get/set round trip, unchanged value requests no save, junk reads as `&""`, survives a reload through a temp `SaveService` (use the existing temp-dir helpers; never the real save). `save_v3_mvp_owned.json` now migrates (deferred 9.3 note): its tests must still pass; if one asserts `schema_version == 3` after load, update it to `CURRENT_SCHEMA`.

- [x] **Task 3: `LevelTheme`, `LevelEntry.themes`, validation, `ThemePicker`** (AC: 1, 2, 4, 6)
  - [x] 3.1 New `scripts/resources/level_theme.gd`: `class_name LevelTheme extends Resource`, the four `@export`s with `##` docs. Doc says: a theme is art and music only; rules live in the `LevelConfig` and never vary per theme (FR76).
  - [x] 3.2 `scripts/resources/level_entry.gd`: `@export var themes: Array[LevelTheme] = []` + doc ("empty = the level scene's built-in look, nothing saved; Story 10.2-10.4 append themes here") and a `get_theme(id: StringName) -> LevelTheme` helper (null when unknown/empty).
  - [x] 3.3 `scripts/resources/level_registry.gd` `validate()`: before the unlock checks, for every entry: null theme → `"%s has a null theme"`, empty id → `"%s has a theme with no id"`, duplicate id → `"%s has two themes called %s"`, null backdrop → `"%s theme %s has no backdrop"`. Keep returning the first problem.
  - [x] 3.4 New `scripts/run/theme_picker.gd`: `class_name ThemePicker` (RefCounted, static funcs only, pure: no nodes, no autoloads). `static func pick(themes: Array[LevelTheme], last_id: StringName, rng: RandomNumberGenerator) -> LevelTheme`: skips null entries; none → null; one → it, **no draw**; more → candidates = ids != last_id (all if that leaves none, which can only happen with duplicate ids); `candidates[rng.randi_range(0, candidates.size() - 1)]`. `static func theme_rng(run_seed: int) -> RandomNumberGenerator`: a new RNG with `seed = hash("theme:%d" % run_seed)` (deterministic, never drawn from the run RNG; see Dev Notes "RNG").
  - [x] 3.5 Tests: new `tests/unit/test_theme_picker.gd` (empty → null; single → it and the rng state unchanged; 2 themes with last = A → always B over 100 draws; 3 themes with last = B → only A/C, both appear over 200 draws; unknown/empty last → all three appear; nulls skipped; same seed → same pick; `theme_rng` same seed → same sequence, different seeds differ). New `tests/unit/test_level_theme.gd` (property list of the script: only the 4 exports, AC 4a — filter `get_script().get_script_property_list()` to `PROPERTY_USAGE_SCRIPT_VARIABLE`). `tests/unit/test_level_registry.gd`: the four new validate cases; `test_shipped_registry_themes` (every non-debug entry ≥ 1 theme; ids per AC 1; Horde Rush's defender set, the others' null; every `music_id` empty; debug entries none; `validate() == ""`).

- [x] **Task 4: Extract today's looks into theme scenes** (AC: 1, 5) — pure refactor; no pixel moves.
  - [x] 4.1 New `scenes/levels/zombie_run/themes/sunny_village_green.tscn`: root `Backdrop` (Node2D, script `sunny_village_backdrop.gd`) with `Sky`, `Clouds/A,B`, `Far/A,B`, `Near/A,B`, `Ground/A,B` **copied verbatim** from `zombie_run_level.tscn` (same textures by uid, offsets, colour, positions). Replace the inline `Backdrop` in `zombie_run_level.tscn` with an instance of it: `[node name="Backdrop" parent="." instance=ExtResource(...)]` + `unique_name_in_owner = true`, same index (first child).
  - [x] 4.2 New `scenes/levels/pitchfork_panic/themes/moonlit_village.tscn`: the same for `pitchfork_panic_level.tscn`'s `Backdrop` (including `Moon`). The `EscapeBush`, `DustCloud`, `DizzyStars`, `EndLabel`, `FadeLayer` stay in the level (Story 10.4 decides per-theme dive props).
  - [x] 4.3 New `scenes/levels/horde_rush/themes/farmhouse.tscn`: root `Field` (Node2D) with `FieldArt` and `Farmhouse` (position 548, 0) copied verbatim. Replace the inline `Field` in `horde_rush_level.tscn` with an instance (`unique_name_in_owner = true`, first child). The `Defender` (farmer.tscn instance under `%Zombies`) stays as is in the scene.
  - [x] 4.4 Remove the now-unused `ext_resource` lines from the three level scenes and fix `load_steps`. Let Godot write uids on `--import`; commit any new `.uid`/`.tscn` uid lines it adds.
  - [x] 4.5 Run the suite. `test_zombie_run_level.gd`, `test_sunny_village_backdrop.gd`, `test_horde_rush_level.gd` (incl. `%Field/FieldArt`, `%Field/Farmhouse`, `%Defender`), `test_pitchfork_panic_level.gd`, `test_art_backdrop.gd` must pass **unchanged**. If one fails, the extraction is wrong, not the test.

- [x] **Task 5: Levels apply a theme** (AC: 2, 5)
  - [x] 5.1 `scripts/run/level_base.gd`: add `func apply_theme(theme: LevelTheme) -> void` — called by RunFrame **before** `add_child` (document the new first step in the "Call order" block). Base behaviour: null theme → no-op; stores `theme_id` (a new `var theme_id: StringName = &""`, read by tests); swaps the node named by `_backdrop_slot()` (virtual, default `&"Backdrop"`) for `theme.backdrop.instantiate()` through a shared `_swap_slot(slot: StringName, scene: PackedScene) -> void` helper. The helper: finds the child by unique name (`get_node_or_null("%" + slot)`); missing slot or null scene → one `Log.warn(&"level", ...)` and keep the built-in look; **if the existing node's `scene_file_path == scene.resource_path`, do nothing** (the single shipped theme is a no-op, so nothing is rebuilt); otherwise instantiate, set `name = slot`, add it to the old node's parent, `move_child` to the old index, copy `position`, set `owner = self` and `unique_name_in_owner = true`, then `remove_child` + `free()` the old one.
  - [x] 5.2 `horde_rush_level.gd`: override `_backdrop_slot()` → `&"Field"`; override `apply_theme` to call `super(theme)` then `_swap_slot(&"Defender", theme.defender)` when the theme is non-null (the slot lives under `%Zombies`; the helper keeps it there so it still y-sorts). `_defender_view`/`_farmer` are `@onready`, so they pick up the swapped node because the swap happens before `_ready`. Do not touch the tomato SFX constants or `DEFENDER_X` (Story 10.3).
  - [x] 5.3 Zombie Run and Pitchfork Panic need no override (`%Backdrop` is their slot; their `@onready _backdrop: SunnyVillageBackdrop` picks up the instanced theme). Do **not** rename `SunnyVillageBackdrop` in this story (see Dev Notes).
  - [x] 5.4 Tests (in the existing level test files, or a new `tests/unit/test_level_themes.gd`): for each real level, `apply_theme(<its shipped theme>)` before `add_child` → zero warnings, same `%Backdrop`/`%Field` node (no swap: assert `get_instance_id()` from a pre-apply lookup), `theme_id` set. With a **test fixture theme** (new `tests/fixtures/levels/test_backdrop.tscn`: a `Node2D` named `Backdrop` with the `SunnyVillageBackdrop` script and four empty-texture layers is enough, or reuse `sunny_village_green.tscn` under a different `LevelTheme` id with a duplicated PackedScene path — pick whichever proves a real swap): the node is replaced, keeps its index and unique name, the level's `_backdrop` scrolls the new node (`scroll_to` moves its ground layer), the old node is freed. Horde Rush with a fixture defender scene (a plain `Node2D`) → `get_defender_view()` is the new node under `%Zombies`, the level runs (logic still paces; `_farmer` null is already handled). Null backdrop theme → one asserted warning, built-in look kept.

- [x] **Task 6: RunFrame picks, applies, saves and plays the theme** (AC: 2, 4, 5, 7)
  - [x] 6.1 `scripts/run/run_frame.gd` `_start_level`: after `get_scene` succeeds, look up `var entry: LevelEntry = level_registry.get_entry(_level_id)`; **move `_seed_rng(_requested_seed(payload))` up to here** (before `instantiate`; it draws nothing, so target replay is unchanged). After the `config == null` check and **before** `%LevelHost.add_child(level)`: `var theme: LevelTheme = _pick_theme(entry, payload)`; `level.apply_theme(theme)`. After the start succeeds (next to `last_seed = _seed`): if `theme != null`, `player_data.set_last_theme(_level_id, theme.id)`. Music: `var music: StringName = theme.music_id if theme != null and theme.music_id != &"" else config.music_id` replaces `config.music_id` in the `play_music` call.
  - [x] 6.2 `_pick_theme(entry, payload) -> LevelTheme`: forced `payload["theme"]` (String or StringName) found by `entry.get_theme()` → it; a forced id not found → `Log.warn(&"run", "unknown theme %s for %s, picking one" % [...])` then normal pick; normal pick = `ThemePicker.pick(entry.themes, player_data.get_last_theme(_level_id), ThemePicker.theme_rng(_seed))`. Store `_theme_id` and add `func get_theme_id() -> StringName`. Log the theme in the existing `"started level=%s seed=%d..."` info line (theme ids are not secret, unlike the tier).
  - [x] 6.3 Update the RunFrame class doc with a `## Themes (Story 10.1, FR76): ...` paragraph (pick before add_child, own RNG from the seed, saved at start so a quit run also counts as "previous", music override).
  - [x] 6.4 `tests/integration/test_run_frame.gd`: with a code-built registry (follow the existing `LevelRegistry.new()` / `LevelEntry.new()` cases at ~l.303) whose `test_level` entry has two fixture themes A and B: last = A → B picked and saved; a third run → A; payload `"theme": &"B"` forces B even with last = B; unknown forced id → asserted warning + a valid pick; same seed and same last → same theme; **AC 4b**: seed 42 with theme A forced and with theme B forced → identical `_targets()` sequence and the same `get_level().get_level_config()`; a theme `music_id` override reaches the `play_music` recorder, an empty one falls back to the config's; the shipped `test_level` entry (no themes) → `get_theme_id() == &""`, `get_last_theme` stays `&""`. All on an injected temp `PlayerData` (the file already does this; never the autoload).
  - [x] 6.5 Shipped levels through RunFrame (AC 5): start `zombie_run`, `horde_rush`, `pitchfork_panic` with the shipped registry and a temp PlayerData → `get_theme_id()` is the AC 1 id, zero warnings/errors, `get_last_theme` saved. Reuse whatever existing test already starts these levels through a frame (check `test_horde_rush_tier.gd`, `test_zombie_run_tier.gd`, `test_placement.gd`), or add three small cases.

- [x] **Task 7: Debug overlay** (AC: 7)
  - [x] 7.1 `scripts/debug/debug_overlay.gd`: add `theme <id>` (or `theme -` when empty) to the run section line that already shows the seed (~l.300-310). Update its test in `tests/unit/test_debug_overlay.gd` if it asserts the exact text.

- [x] **Task 8: Verification and wrap-up** (AC: 8)
  - [x] 8.1 Full suite as in Task 1; record count, `SCRIPT ERROR` / `WARNING` deltas (explain each), zero parse/compile errors. Real save sha256 unchanged.
  - [x] 8.2 Mutation pass (each must turn a test red): `ThemePicker.pick` ignores `last_id`; single theme draws from the rng; `migrate_3_to_4` not registered; RunFrame picks the theme from `_rng` instead of `theme_rng`; `set_last_theme` never called; `_swap_slot` always swaps (the shipped-theme no-op test catches it); validate drops the duplicate-id check.
  - [x] 8.3 Manual smoke in the editor or web build (no gate, nothing looks different): play each level once from the menu; F3 shows the theme id; quit and replay; `save.json` (export with F9) has `last_themes` for each level played. Record in Debug Log References.
  - [x] 8.4 `deferred-work.md`: new "Deferred from: dev of story 10-1" section (at least: `SunnyVillageBackdrop` name still generic-in-use; per-theme escape prop and Horde Rush projectile/SFX left to 10.3/10.4; anything else found). Update this story file's Dev Agent Record, File List, Change Log; `sprint-status.yaml` → `review`.

## Dev Notes

### What this story is (and isn't)

- **Is:** the theme *plumbing*: a `LevelTheme` resource, a registry list, a pure picker, a per-level "last theme" in the save (schema v4), the level-side swap, RunFrame wiring, debug display — plus extracting today's three looks into their own scenes so each is "theme #1" of its level.
- **Isn't:** any new art, new backdrops, new defenders, projectiles or sounds (10.2 Zombie Run themes, 10.3 Horde Rush pairs, 10.4 Pitchfork settings), the trends screen (10.5), renaming `SunnyVillageBackdrop`, per-theme villager recolours or escape props. After this story **nothing looks or sounds different** to the kid: every level has one theme, which is its current look. No screenshot gate.
- If you find yourself changing a level's gameplay code, a `LevelConfig` `.tres`, `TypingSession`, a `TargetSource`, the HUD, the menu or the report card, stop: a theme must never touch rules (FR76).

### Architecture compliance

- Static data = typed `@export` Resources in `data/` (`LevelTheme` sub-resources live inside `data/levels/level_registry.tres`, like `LevelEntry`). No GDD number as a literal in a script (themes carry none).
- **Levels never read PlayerData** (LevelBase contract): RunFrame reads `get_last_theme`, picks, calls `level.apply_theme(theme)` down, and writes `set_last_theme`. Only `PlayerData` mutates the profile; only `SaveService` touches files.
- **One RNG per run, no global `randi()`** — see RNG below.
- Save migrations: ordered `migrate_N_to_N1`, run before `fill_defaults`, must not assume field types, never read the registry. Fixtures per migration.
- New level-side API follows the existing contract style: a call-down method with a no-op default on `LevelBase`, overridden only where needed.
- Typed GDScript everywhere (`untyped_declaration = Error`, also in tests: type every `for` variable), tabs, `##` docs that say why, LF endings, `%UniqueName` refs, `Log.warn/error(&"tag", ...)`, no logging in `_process`.

### RNG (the one subtle part)

- `LevelBase` doc: a seed must always replay the same targets. The source's child RNG is seeded with `rng.randi()` **inside** `create_target_source`, and Zombie Run keeps the run RNG for Brainsss rolls; Pitchfork Panic draws exactly two `randi()`s. Any extra draw from `_rng` before or after `create_target_source` would shift those and break seed-pinned tests (`test_run_frame.gd` uses seeds 1/3/42 and compares target lists; the tier and sim tests pin seeds too).
- So the theme uses **its own RNG**, `ThemePicker.theme_rng(_seed)`, seeded from a hash of the run seed. It is deterministic (F2 replays the theme too, if the saved last theme is the same) and never touches `_rng`. Moving `_seed_rng()` earlier in `_start_level` is safe: it only creates and seeds the RNG; nothing draws from it until `create_target_source`.
- The `"theme:%d"` hash keeps the theme draw from correlating with the run RNG's first `randi()` (seeding a second RNG with the same seed would make the theme choice mirror the first target draw).

### Existing code: current state, what changes, what must be preserved

- `scripts/run/run_frame.gd` (UPDATE). `_start_level` (~l.231-293) today: id → `get_scene` → instantiate → config → `add_child` → `set_tier` → `set_used_passages` → `_seed_rng` → `create_target_source` → session/HUD/wiring → `play_music(config.music_id)` → `last_seed`. Changes: entry lookup, `_seed_rng` moved up, theme pick + `apply_theme` before `add_child`, `set_last_theme` on success, music override, `get_theme_id()`. Preserve: every failure path (`_fail_to_menu`, NFR16), the `last_seed` set-only-on-success rule, all test seams (`navigate`, `pause_tree`, `player_data`, `is_debug_build`, `set_ambience`, `play_music`, `duck_music`, `play_sfx`), signal wiring order (level before HUD).
- `scripts/run/level_base.gd` (UPDATE): add `apply_theme`, `theme_id`, `_backdrop_slot`, `_swap_slot`; extend the "Call order" doc with `apply_theme(theme)` as the first step (before `_ready`). Preserve every existing no-op default.
- `scripts/levels/horde_rush/horde_rush_level.gd` (UPDATE, small): the `_backdrop_slot` / `apply_theme` overrides and a doc line. `%Field` is only referenced by tests (the script uses `%Zombies`, `%Projectiles`, `%Defender`, `%Effects`). `_defender_view` is `@onready %Defender`; the swap happens pre-`_ready`, so no change to that line. Preserve: layout constants, defender logic, tomato SFX/consts (10.3 owns those).
- `scripts/levels/zombie_run/zombie_run_level.gd`, `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd`: **no code change expected** (doc line optional). Their `@onready var _backdrop: SunnyVillageBackdrop = %Backdrop` works because the instanced theme root carries that script.
- `scripts/levels/zombie_run/sunny_village_backdrop.gd`: no change. Its `_ready` warning uses `owner.name`; inside an instanced sub-scene `owner` of the backdrop root is the level (set by the level scene / by `_swap_slot`), so the message still names the level.
- Scenes `zombie_run_level.tscn`, `horde_rush_level.tscn`, `pitchfork_panic_level.tscn` (UPDATE): inline backdrop → instanced theme scene, same name, index, unique name. Tests reach `%Backdrop`, `Backdrop`, `%Field`, `%Field/FieldArt`, `%Field/Farmhouse`, `%Defender` — all still resolve (a sub-scene's children are reachable by path from the level).
- `scripts/resources/level_entry.gd`, `level_registry.gd`, `data/levels/level_registry.tres` (UPDATE). In the `.tres`, add the three `LevelTheme` sub-resources + ext_resources for the theme scenes and `farmer.tscn` + the `level_theme.gd` script, set `themes = Array[ExtResource("<theme script id>")]([SubResource(...)])` on the three real entries, bump `load_steps`. Keep `PlayerData`'s lazy registry load (never preload the registry: it references every level scene).
- `scripts/core/save_schema.gd`, `game_constants.gd`, `scripts/autoloads/player_data.gd` (UPDATE) — Task 2.
- `scripts/debug/debug_overlay.gd` (UPDATE) — one line.
- **Must not change:** `data/levels/*.tres` configs, `scripts/typing/*`, `scripts/resources/*_config.gd`, HUD, menu, report card, closet, `AudioManager`, `Router`, `SaveService`, any PNG, `tools/gen_*_art.gd` (they write textures, not scenes).

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_smoke.gd:12` | pins `CURRENT_SCHEMA == 3` | 4 (Task 2.2) |
| `test_save_schema.gd::test_defaults_match_v3_fixture`, `test_prepare_round_trips_full_fixture`, `test_prepare_v1_reaches_v3`, `migration_steps().size()` check | new field + step | Task 2.4 |
| `test_save_service.gd` export-equals-fresh test (~l.245) | exports v4 now | `FRESH_PATH` → v4 |
| `test_level_unlocks.gd:242` | uses `CURRENT_SCHEMA` | none expected |
| `test_player_data.gd` / `test_crypt_closet.gd` on `save_v3_mvp_owned.json` | the fixture now migrates (9.3 deferral foresaw this) | none expected; fix only a literal `3` |
| `test_debug_overlay.gd` | if it asserts the exact run line | add the theme text |
| Level/backdrop tests | scene extraction | must pass **unchanged** (Task 4.5) |

### Testing notes

- Commands in Task 1. Run `--import` after adding scenes/scripts (new `class_name`s need the global class cache) and before tests.
- Never write the real save: temp-dir `SaveService` + injected `PlayerData` (patterns: `test_player_data.gd::_put_fixture`, `test_run_frame.gd::_make`). The F9 export in the manual smoke is the only real-save touch, and that is a manual check outside the suite.
- GUT 9.7.1: use `assert_push_warning` / `assert_push_warning_count` / `assert_push_error` for deliberate `Log.warn`/`Log.error`; `assert()` shows as `SCRIPT ERROR` headless — don't add asserts for theme problems (they are data problems → warn + fallback, NFR16).
- GUT silently skips a script that fails to parse and still exits 0: always grep the log for `Parse Error|Compile Error|Failed to load script` (8.6 shipped a skipped file).
- Sort `String`s, never `StringName`s (they compare by interned pointer; 9.1 hit this).
- When comparing "same node, no swap", capture `get_instance_id()` before `apply_theme`.
- Node lookups before `add_child`: `get_node_or_null("%Backdrop")` on an instantiated-but-not-in-tree scene root resolves through the owner's unique-name map; write the first test for exactly this so a surprise shows up early. If it does not resolve in 4.7.2, fall back to `find_child(slot, true, true)` restricted to nodes owned by `self`, and note it.
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence

- **9.3 (full catalogue live):** final 2058 tests; 3 `SCRIPT ERROR`, 161 `WARNING`. Deferred: "Fixture `save_v3_mvp_owned.json` pins `schema_version` 3; a later schema bump would make it exercise migration instead of the current-schema path" — this story is that bump; leave the fixture as a v3 migration input (it is still useful), and if you want current-schema coverage, add nothing new unless a test needs it.
- **8.2 (schema v3):** the template for this migration: `migrate_2_to_3`, the v3 fresh fixture, the export-equals-fixture test, `test_v2_chain_matches_registry`. Mirror its naming and test set.
- **8.6 / 3.6 / 6.6 (the three looks):** `SunnyVillageBackdrop` is reused for the Moonlit Village "until Epic 10 generalises it". Generalising (rename to e.g. `ParallaxBackdrop`) is optional cleanup for 10.2 when a third parallax look arrives; doing it here touches ~6 test files for no kid-visible gain. Note it in deferred work.
- **6.6 (Horde Rush):** "The tomato ones belong to the Farmhouse pair (Epic 10 adds its own per pair)" — 10.3 will extend `LevelTheme` (projectile scene, throw/hit SFX). Keep `LevelTheme` easy to extend; do not pre-build those fields.
- **8.7 deferred:** `mob_hint.png` unused since 8.7 — "delete ... if no setting needs it by Epic 10". Not this story; leave it for 10.4.
- **Traps:** keep files LF (`.gitattributes eol=lf`; working copies may be CRLF via `core.autocrlf`, normalise before scripted matching). Hand-edited `.tscn`/`.tres`: keep `format=3`, correct `load_steps`, unique sub-resource ids; Godot rewrites uids on import — commit what it writes. The browser pane's `shift+a` sends lowercase (8.7 note) if you do a web smoke.

### Git intelligence

- Recent: `8b1fe1b Story 9.3: full catalogue live, code review patches applied, done`, `74aeef4 Add Godot import files for Story 8.7 screenshots`, `f8944cd Story 9.2 ...`, `9d498a4 Story 9.1 ...`, `9f382be Story 8.7 ...`. One commit per story with code, data, tests, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape here: 3 new theme scenes, 3 level scenes slimmed, 2 new scripts (`level_theme.gd`, `theme_picker.gd`) + their `.uid`s, ~6 updated scripts, the registry `.tres`, 1 new fixture, ~8 test files. Suggested message: `Story 10.1: random theme rotation`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries or APIs; nothing to research. Godot 4.7.2 standard, Compatibility renderer, GDScript only, static typing.
- `RandomNumberGenerator.randi_range(from, to)` is inclusive on both ends. `hash()` on a String is stable across runs and platforms within one Godot version — good enough for a debug replay.
- `Array[LevelTheme]` exports serialise in `.tres` as `Array[ExtResource("<script id>")]([SubResource(...)])`, the same form `entries` uses for `LevelEntry` today.
- An instanced sub-scene node in a `.tscn` can carry `unique_name_in_owner = true` on the instance line; its own children stay owned by the sub-scene root, so `%Name` lookups from the level only see the root (which is all the levels use).
- `Node.scene_file_path` on an instanced root is the `.tscn` path; `PackedScene.resource_path` matches it for a scene loaded from disk — the no-op check in `_swap_slot` relies on this.

### Project Structure Notes

- New files follow the architecture: `scripts/resources/level_theme.gd` (Resource classes), `scripts/run/theme_picker.gd` (run-pipeline helper beside `run_clock.gd`), theme scenes under `scenes/levels/<id>/themes/<theme_id>.tscn` (mirrored feature folders; snake_case; theme ids match file names). Test fixture scenes under `tests/fixtures/levels/`. No variance.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Autoload order `WebPlatform → SaveService → PlayerData → AudioManager → Router`; no EventBus; typed past-tense signals connected in code.
  - Levels never read input, the clock or PlayerData, and never call the Router; RunFrame calls down, levels signal up.
  - One RNG per run, injected; no global `randi()`/`randf()` in gameplay.
  - Static data via `@export` Resources; ids are permanent once shipped and saved (`sunny_village_green`, `farmhouse`, `moonlit_village` will be in players' saves — never rename them).
  - NFR16: a missing sprite/scene never stops a run (warn + fall back). NFR9/NFR10: nothing kid-facing here; theme ids are debug-only text.
  - Debug code only in `scenes/debug/` / `scripts/debug/`.
  - Visible changes wait for Smuck's approval; this story should have none (if anything looks different, that is a bug).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 10: Art Variety & Trends, Story 10.1: Random Theme Rotation]; FR76, FR58, FR74, FR51; NFR13, NFR16; Additional Requirements "Core architecture" (one RNG per run), "Data" (save migrations, typed Resources)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] l.347-348 (art rotation, Zombie Run themes); decision-log.md l.16 (theme list per level)
- [Source: _bmad-output/game-architecture.md] l.70 (theme rotation risk row, Epics 10-11)
- [Source: scripts/run/run_frame.gd _start_level/_seed_rng/_requested_seed], [scripts/run/level_base.gd class doc + call order], [scripts/core/save_schema.gd], [scripts/autoloads/player_data.gd used_passages API (template for last_themes)], [scripts/resources/level_registry.gd validate], [scripts/resources/level_entry.gd], [data/levels/level_registry.tres]
- [Source: scenes/levels/zombie_run/zombie_run_level.tscn, scenes/levels/horde_rush/horde_rush_level.tscn, scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn], [scripts/levels/zombie_run/sunny_village_backdrop.gd]
- [Source: tests/integration/test_run_frame.gd (~l.303 code-built registry, _targets)], [tests/unit/test_save_schema.gd], [tests/unit/test_save_service.gd], [tests/unit/test_smoke.gd], [tests/unit/test_level_registry.gd], [tests/fixtures/saves/]
- [Source: _bmad-output/implementation-artifacts/9-3-full-catalogue-live.md], [8-2-paragraph-target-mode.md], [deferred-work.md] (9.3 fixture note, 8.7 mob_hint note, 6.6 per-pair SFX note in horde_rush_level.gd)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1.1): 2058 tests, all passing; `SCRIPT ERROR` 3, `WARNING` 161, zero `Parse Error|Compile Error|Failed to load script`. Real save sha256 `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.
- Final (Task 8.1): 2106 tests, all passing (+48); `SCRIPT ERROR` 3 (unchanged); `WARNING` 167 (+6, all deliberate and asserted: `ZombieRunLevel: theme broken has no Backdrop` and `HordeRushLevel: theme half has no Defender` in `test_level_themes.gd`; `unknown theme nope for test_level` in `test_run_frame.gd`; `migrate_3_to_4: profiles is not a dictionary` twice (the new junk test, and an existing junk-save prepare that now runs one more step) and `migrate_3_to_4: profiles/bad is not a dictionary` once); zero parse/compile/load errors. Real save sha256 identical to the baseline before and after the final run.
- **Real-save incident (fixed):** the first full run changed the real `save.json`. Cause: `test_screen_flow.gd` instanced the RUN screen on the live `PlayerData` autoload, and RunFrame now saves the last theme at run start (before this story a run only wrote at its end). Fix: that test injects a temp-dir PlayerData into RUN, like MAIN_MENU and WELCOME_GIFT. Found by running the RunFrame-building test scripts one at a time against the save hash (only `test_screen_flow` wrote; a plain boot does not migrate-and-write). Restored: the original was rebuilt from the touched file (schema_version 3, `last_themes` removed, re-serialised the way SaveService writes) and matched the baseline sha256 byte for byte; `save.json` and `save.bak` were both restored to it. Side effect: the earlier contents of `save.bak` (an older backup from before this story) were rotated away and are not recoverable.
- Task 4.4: the extraction was scripted (verbatim copy of the subtree, parents re-rooted, unused ext_resources dropped, `load_steps` recounted). `--import` added no uid lines to the new scenes; references are by path, like the existing ones.
- Task 5 note: `get_node_or_null("%Backdrop")` resolves on an instantiated scene root before it enters the tree in 4.7.2 (pinned by `test_unique_slots_resolve_before_the_level_is_in_the_tree`); no `find_child` fallback needed.
- Mutation pass (Task 8.2), every one killed: `pick` ignores `last_id` (6 failing), a single theme draws from the rng (2), `migrate_3_to_4` not registered (6), RunFrame draws the theme from `_rng` (1, `test_theme_draw_never_touches_the_run_rng`), `set_last_theme` never called (2), `_swap_slot` always swaps (1, the shipped-theme no-op test), validate drops the duplicate-id check (1).
- Manual smoke (Task 8.3): a web debug export served by the `web-debug` launch config in the browser pane, whose `user://` is browser storage, so the real save was not involved. Zombie Run from the menu card, then Horde Rush and Pitchfork Panic through the overlay jumps, each quit from the pause menu. F3 showed `theme sunny_village_green`, `theme farmhouse` and `theme moonlit_village`. Each level looked as before (Sunny Village Green, the field, farmhouse and farmer, the Moonlit Village with its moon). The console logged `started level=... theme=...` with no errors or warnings. The save in browser storage was read directly (instead of downloading an F9 export) and held `schema_version` 4 and `last_themes` for all three levels; all three were quit runs.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- Save schema v4: `migrate_3_to_4` adds `last_themes: {}` per profile (keeps a Dictionary, replaces anything else, skips junk with warnings); `CURRENT_SCHEMA = 4`; `save_v4_fresh.json` equals `SaveSchema.defaults()` (v1-v3 fixtures untouched). `PlayerData.get_last_theme` / `set_last_theme` (Strings in the save, no write for an unchanged value or an empty level id, no signal).
- `LevelTheme` (id, backdrop, defender, music_id; nothing else, pinned by a property-list test), `LevelEntry.themes` + `get_theme()`, `LevelRegistry.validate()` theme checks (null, no id, duplicate id, no backdrop). `ThemePicker.pick` (single theme = no draw; else uniform among ids != last) and `theme_rng(seed)` (`hash("theme:%d")`, never the run RNG).
- The three looks moved verbatim into `scenes/levels/<id>/themes/` and are instanced back into the level scenes under the same name, index and unique name; the shipped registry gives each real level that one theme. All existing level/backdrop tests passed unchanged.
- `LevelBase.apply_theme` (before `add_child`) + `_backdrop_slot` + `_swap_slot` (no-op when the slot already is that scene, warn-and-keep on a missing slot/scene, else replace keeping parent, index, position, owner and unique name). Horde Rush swaps `%Field` and `%Defender` (stays under `%Zombies`).
- RunFrame: entry lookup and seeding moved before instantiation (seeding draws nothing); `_pick_theme` (payload `"theme"` forces, unknown id warns and falls back), `apply_theme` before `add_child`, `set_last_theme` only once the start succeeds, theme music overrides the config's, `get_theme_id()`, theme in the start log line. Debug overlay run line shows `theme <id>` / `theme -`.
- AC 4 proofs: property-list test (a); same seed with theme A or B forced gives the same 20 targets and the same LevelConfig (b); a themed run deals exactly what the unthemed level deals for seeds 1/7/42, and every pre-existing seed-pinned test passes unchanged (c).
- Two test files outside the story's fallout table needed updates: `test_no_placeholder_chrome.gd` read Pitchfork Panic's `Sky` from the level scene text (it now reads the level plus its theme scene, and walks the `themes/` folders), and `test_screen_flow.gd` (temp PlayerData for RUN, see Debug Log).

### File List

New:
- `scripts/resources/level_theme.gd` (+ `.uid`)
- `scripts/run/theme_picker.gd` (+ `.uid`)
- `scenes/levels/zombie_run/themes/sunny_village_green.tscn`
- `scenes/levels/horde_rush/themes/farmhouse.tscn`
- `scenes/levels/pitchfork_panic/themes/moonlit_village.tscn`
- `tests/fixtures/saves/save_v4_fresh.json`
- `tests/fixtures/levels/test_backdrop.tscn`
- `tests/fixtures/levels/test_defender.tscn`
- `tests/fixtures/levels/test_themed_level.tscn`
- `tests/unit/test_theme_picker.gd` (+ `.uid`)
- `tests/unit/test_level_theme.gd` (+ `.uid`)
- `tests/unit/test_level_themes.gd` (+ `.uid`)

Modified:
- `scripts/core/save_schema.gd`
- `scripts/core/game_constants.gd`
- `scripts/autoloads/player_data.gd`
- `scripts/resources/level_entry.gd`
- `scripts/resources/level_registry.gd`
- `scripts/run/level_base.gd`
- `scripts/run/run_frame.gd`
- `scripts/levels/horde_rush/horde_rush_level.gd`
- `scripts/debug/debug_overlay.gd`
- `data/levels/level_registry.tres`
- `scenes/levels/zombie_run/zombie_run_level.tscn`
- `scenes/levels/horde_rush/horde_rush_level.tscn`
- `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`
- `tests/unit/test_smoke.gd`
- `tests/unit/test_save_schema.gd`
- `tests/unit/test_save_service.gd`
- `tests/unit/test_player_data.gd`
- `tests/unit/test_level_registry.gd`
- `tests/unit/test_debug_overlay.gd`
- `tests/unit/test_no_placeholder_chrome.gd`
- `tests/integration/test_run_frame.gd`
- `tests/integration/test_screen_flow.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/10-1-random-theme-rotation.md`

### Change Log

- 2026-10-14: Story 10.1 implemented: theme plumbing (`LevelTheme`, `LevelEntry.themes`, registry validation, `ThemePicker` with its own seed-derived RNG), save schema v4 (`last_themes`, `migrate_3_to_4`, v4 fixture), the three current looks extracted into theme scenes and registered as each level's single theme, `LevelBase.apply_theme` / `_swap_slot` (Horde Rush: field + defender), RunFrame pick/apply/save/music override and payload `"theme"` forcing, theme id on the F3 run line. Nothing looks or sounds different to the kid. 48 new GUT tests (2058 → 2106), all 7 mutations killed. Status set to review.

### Review Findings

- [x] [Review][Patch] Forced payload `"theme"` must not be saved as the level's last theme (decision 1.1) [scripts/run/run_frame.gd:313]
- [x] [Review][Dismissed] F2 replay rarely reproduces the theme — accepted limit per AC7 wording (decision 2.2)
- [x] [Review][Patch] Theme backdrop root type is not checked — Zombie Run / Pitchfork Panic declare `_backdrop: SunnyVillageBackdrop = %Backdrop`; a theme with another root breaks the typed @onready instead of falling back (NFR16). Check the instance in `_swap_slot` / `apply_theme`, warn, keep the built-in look. [scripts/run/level_base.gd:_swap_slot]
- [x] [Review][Patch] `level.apply_theme(theme)` is called with null for levels without themes; AC2 says no apply. Guard with `if theme != null`. [scripts/run/run_frame.gd:272]
- [x] [Review][Patch] `_theme_id` is set before the start can fail, so `get_theme_id()` reports a theme after a failed start although nothing is saved. Set it at the end with `set_last_theme`. [scripts/run/run_frame.gd:271]
- [x] [Review][Patch] Horde Rush theme with both backdrop and defender null logs two warnings; AC5 says one. [scripts/levels/horde_rush/horde_rush_level.gd:apply_theme]
- [x] [Review][Defer] `_swap_slot` copies only position (not z_index, scale, modulate, visible, groups) — deferred, no shipped theme needs it
- [x] [Review][Defer] Horde Rush theme with null defender warns every run (backdrop-only themes in 10.2–10.4) — deferred, AC5 mandates the warning; revisit when a defender-less theme is added
- [x] [Review][Defer] `LevelRegistry.validate()` does not check `music_id` exists, defender presence per level, or backdrop root type — deferred, beyond AC6
- [x] [Review][Defer] Junk entries inside an existing `last_themes` dictionary persist in the save; `set_last_theme` does not repair/guard an empty profile — deferred, getter tolerates it
- [x] [Review][Defer] Registry eagerly loads every theme backdrop for every level — deferred, revisit as themes grow (10.2–10.4)
