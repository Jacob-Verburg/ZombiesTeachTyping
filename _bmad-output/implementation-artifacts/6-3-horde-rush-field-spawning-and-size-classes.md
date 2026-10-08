---
baseline_commit: 2de292cde4847ef3cf7109ac63a133071e13a5c2
---

# Story 6.3: Horde Rush Field, Spawning and Size Classes

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want every word I finish to send a copy of my zombie marching toward the house,
so that fast typing builds a bigger horde.

## Acceptance Criteria

1. **Level exists, still hidden (FR53, FR59, FR26).** Given `horde_rush` extending `LevelBase` (`scenes/levels/horde_rush/horde_rush_level.tscn` + `scripts/levels/horde_rush/horde_rush_level.gd`), registered in `level_registry.tres` with its scene and `available = false` (the main menu still shows "Coming soon" and cannot start it), and `data/levels/horde_rush.tres` (a `HordeRushConfig`), when it is started from the debug overlay's jump row with `{"level_id": &"horde_rush"}`, then a 5:00 run (`duration_s = 300`) starts in word mode on a 5-lane field, with zombies entering at the left and the house on the right edge.
2. **Words (FR59, FR54).** The run's words come from `words.json` through `WordSource` with the fixed 3–5 band from `horde_rush.tres` (no band literal in a script). Space stays ignored and case is folded (FR3, FR4). The HUD's word display, hands and start prompt ("Type the word to start!") are the shared ones from Story 6.2, unchanged.
3. **Spawn on completion (FR54, FR43).** Given a completed word, when `on_target_completed(word)` runs, then in the same call a new marcher is added to the logical field and a copy of the player zombie (`player_zombie.tscn`, so its `HatSlot` shows the equipped hat) is placed at the left edge of a random lane chosen with the level's lane RNG (a child of the run RNG), and it marches toward the house.
4. **Size classes from config (FR55).** Given the word length, when the copy spawns, then its size class, crossing time, hits to stop and arrival brains come from `horde_rush.tres`: ≤3 small (8 s, 1, 1), 4–5 medium (10 s, 2, 2), ≥6 big brute (13 s, 3, 3). The copy is drawn at its class's `sprite_scale`, so the hat follows through anchors plus scale.
5. **Logic leads, visuals chase.** Each zombie's logical progress (seconds marched ÷ crossing time, 0..1) lives in a pure `HordeField` model, advanced from the level's `_process(delta)`; the sprite's x is derived from that progress every frame and is never read back for gameplay. A marcher arrives when its progress reaches 1 (exactly at its crossing time); in this story an arrival just removes the marcher and frees its sprite (brains, shuffle-in and "Brainsss" are Story 6.5).
6. **Pause and end freeze the march.** While the tree is paused (PAUSED, COUNTDOWN) nothing marches; after `on_run_ending()` the march stops where it is and no further arrivals happen. `get_brains_earned()` is 0 in this story; `completion_bonus` stays 0 (6.5 sets +25).
7. **Seed replay.** The same seed gives the same words and the same lanes in the same order.
8. **Tests.** GUT covers: `HordeRushConfig` (shipped numbers, `size_class_for` boundaries, `validate`), `HordeField` (class by length, progress, arrival timing, independence, lane choice deterministic and in range, all lanes used), the level (spawn in the key's call, view scale and lane, march moves the sprite from logic, arrival frees, end freezes, seed replay), the registry/menu changes, the new jump button, and one `RunFrame` integration case. Full suite green.

## Tasks / Subtasks

- [x] **Task 1: Config resources** (AC: 1, 2, 4)
  - [x] 1.1 `scripts/resources/horde_size_class.gd`: `class_name HordeSizeClass extends Resource`, `##` docs. `@export var id: StringName` (`&"small"`, `&"medium"`, `&"brute"`), `@export var max_word_length: int = 0` (inclusive upper bound; `0` = no upper bound, for the last class), `@export var crossing_time_s: float = 0.0`, `@export var hits_to_stop: int = 0` (read by 6.4), `@export var arrival_brains: int = 0` (read by 6.5), `@export var sprite_scale: float = 1.0`. Neutral defaults; real values only in the `.tres`.
  - [x] 1.2 `scripts/resources/horde_rush_config.gd`: `class_name HordeRushConfig extends LevelConfig` (mirror `ZombieRunConfig`). `@export var lane_count: int = 0`, `@export var size_classes: Array[HordeSizeClass] = []` (ordered shortest band first). `func size_class_for(word_length: int) -> HordeSizeClass`: the first class with `max_word_length == 0 or word_length <= max_word_length`; null only when the list is empty. `func validate() -> String` ("" = ok, else the first problem): `lane_count >= 1`; at least one class; every class non-null with `crossing_time_s > 0` and finite, `hits_to_stop >= 1`, `arrival_brains >= 0`, `sprite_scale > 0`; `max_word_length` strictly ascending, only the last one is 0 and the last one must be 0 (review 2a: every word length has a class); size-class ids unique; `crossing_time_s >= MIN_CROSSING_TIME_S` (0.01); `word_list != null`; `1 <= word_min_length <= word_max_length`; `target_mode == WORD`; `duration_s > 0`.
  - [x] 1.3 `data/levels/horde_rush.tres` (script_class `HordeRushConfig`, three `HordeSizeClass` sub-resources): `duration_s = 300.0`, `case_sensitive = false`, `space_is_input = false`, `target_mode = 1` (WORD), `completion_bonus = 0` (Story 6.5 sets 25), `music_id = &""` (march music is 6.6; empty keeps the menu loop), `word_list` = ext_resource `res://data/content/words.json` (type `JSON`, exactly as `test_word_level.tres`), `word_min_length = 3`, `word_max_length = 5`, `lane_count = 5`, classes: small (max 3, 8.0 s, 1 hit, 1 brain, scale 1.0), medium (max 5, 10.0 s, 2, 2, scale 1.25), brute (max 0, 13.0 s, 3, 3, scale 1.5). See "Size-class scale decision" below.
- [x] **Task 2: Pure march model** (AC: 3, 4, 5, 7)
  - [x] 2.1 `scripts/levels/horde_rush/horde_marcher.gd`: `class_name HordeMarcher extends RefCounted` — one zombie's logical state: `id: int` (unique per run, spawn order from 0), `word: String`, `lane: int` (0 = top), `size_class: HordeSizeClass`, `elapsed_s: float` (seconds marched), `hits_left: int` (= `size_class.hits_to_stop` at spawn; 6.4 decrements), `func progress() -> float` (`clampf(elapsed_s / size_class.crossing_time_s, 0, 1)`), `func has_arrived() -> bool`. No nodes. Doc: 6.4 adds the stopped state, 6.5 reads `size_class.arrival_brains`.
  - [x] 2.2 `scripts/levels/horde_rush/horde_field.gd`: `class_name HordeField extends RefCounted`. `_init(config: HordeRushConfig, lane_rng: RandomNumberGenerator)`. `spawn(word: String) -> HordeMarcher`: class from `config.size_class_for(word.length())`, lane `lane_rng.randi_range(0, config.lane_count - 1)` (exactly one draw per spawn, nothing else uses this RNG), appends to the marching list and returns it. `advance(delta: float) -> Array[HordeMarcher]`: ignores `delta <= 0` or non-finite; adds `delta` to every marcher's `elapsed_s`; every marcher with `elapsed_s >= crossing_time_s - ARRIVE_EPSILON_S` (a small const, e.g. `1e-4`, so 60 Hz float sums arrive on the frame they should) is removed and returned, in spawn order. Getters: `get_marching() -> Array[HordeMarcher]` (a copy, spawn order), `get_spawned_count()`, `get_arrived_count()`.
  - [x] 2.3 Keep both pure: no nodes, no autoloads except `Log`, no global `randi()/randf()`. This is the model 6.4 (defender) and 6.7 (headless 10/30 WPM simulation) build on, so no rendering or pixel values in it — only seconds and progress.
- [x] **Task 3: The level** (AC: 1, 3, 4, 5, 6, 7)
  - [x] 3.1 `scripts/levels/horde_rush/horde_rush_level.gd` (`extends LevelBase`, no `class_name` needed; the class doc explains field, RNG order, march, what 6.4/6.5/6.6 add). `_ready()`: cast `config as HordeRushConfig`; null → `assert` + `Log.error` like Zombie Run. Draw the placeholder field (Task 3.5).
  - [x] 3.2 `create_target_source(rng)`: `validate()` failing → `Log.error` + return null (RunFrame fails safely to the menu, NFR16). Then **words first, lanes second**: `word_rng.seed = rng.randi()`, `lane_rng.seed = rng.randi()`. Pool via `WordSource.pool_from_json(config.word_list, config.word_min_length, config.word_max_length)`; fewer than 2 words → `Log.error` + null (never reach the `LetterBagSource` assert). Return `WordSource.new(word_rng, pool)`; build `_field = HordeField.new(cfg, lane_rng)`. Keep the run `rng` unused for now (reserved; document it, like Zombie Run's Brainsss roll).
  - [x] 3.3 `on_target_completed(target)`: logic first — `var m := _field.spawn(target)` — then the view: `PLAYER_ZOMBIE_SCENE.instantiate() as PlayerZombie`, set `position = Vector2(SPAWN_X, lane_feet_y(m.lane))` and `scale = Vector2.ONE * m.size_class.sprite_scale` **before** `add_child` to `%Zombies`, then `play_walk()`; store in `_views: Dictionary[int, PlayerZombie]` by `m.id`. No `await`, no tween. `on_char_accepted` / `on_char_rejected` need no override.
  - [x] 3.4 `_process(delta)`: if `_field == null or _frozen`: return. `for m in _field.advance(delta): _on_marcher_arrived(m)` (frees the view, erases it from `_views`; doc: "Story 6.5 replaces this with shuffle-in, Brainsss and brains"). Then for each marching `m`: `view.position.x = march_x(m.progress())` and `view.play_walk()`. `march_x(p) = lerpf(SPAWN_X, ARRIVE_X, p)`. Never read `view.position` back for logic. Do not change `process_mode` (it must inherit so the tree pause freezes the march).
  - [x] 3.5 Layout consts in the level script (UX layout values, not GDD tuning, taken from `mockups/key-run-hud.html` frame B): `FIELD_TOP_Y = 36.0`, `LANE_HEIGHT_PX = 44.0` (5 × 44 = 220, so the field fills y 36–256 above the 104 px HUD band), `LANE_FEET_INSET_PX` (feet sit a few px above each lane's bottom edge, e.g. 6 → feet y 74, 118, 162, 206, 250), `SPAWN_X = 16.0` (the small copy is fully on screen in the frame it spawns, so the kid sees it next frame, NFR2), `HOUSE_FRONT_X = 548.0`, `ARRIVE_X` (feet x where a copy touches the house front, about `HOUSE_FRONT_X - 16`). `lane_feet_y(lane) = FIELD_TOP_Y + LANE_HEIGHT_PX * (lane + 1) - LANE_FEET_INSET_PX`. `lane_count` comes from config; assert `lane_count * LANE_HEIGHT_PX` fits (log + still run if not).
  - [x] 3.6 `on_run_ending(_reason) -> float`: set `_frozen = true`, every view `play_idle()`; return `0.0` (the outro is 6.5). `get_brains_earned() -> int`: `0` (6.5). Getters for tests/debug: `get_field() -> HordeField`, `get_view(id: int) -> PlayerZombie` (null when gone), `get_view_count() -> int`, `is_frozen() -> bool`.
  - [x] 3.7 `scenes/levels/horde_rush/horde_rush_level.tscn`: root `HordeRushLevel` (Node2D, the script, `config` = `horde_rush.tres`), `Field` (Node2D, unique) with the placeholder backdrop, `Zombies` (Node2D, unique, `y_sort_enabled = true` so lower lanes draw in front; copies' origin is at the feet). Placeholder look, palette colours only (6.6 replaces it with real Farmhouse art): sky `ColorRect` y 0–36 `#7EC8E3`, 5 lane `ColorRect`s alternating `#4E9A34` / `#2E6B26` (mock frame B), and a plain house block at x 548–640 (`#8A5228` with an ink `#1E1428` edge, door `#5A3218`) — no new textures. Nothing at the top-right 40 × 40 (the HUD pause button sits there; the house roof may be under it as in the mock).
- [x] **Task 4: Registry, menu safety, debug jump** (AC: 1)
  - [x] 4.1 `data/levels/level_registry.tres`: add an ext_resource for `horde_rush_level.tscn` (bump `load_steps`), set `scene` on `Resource_horde_rush`; keep `available = false`, `debug_only = false`, its card picture and the entry order.
  - [x] 4.2 Main menu: no code change. `main_menu.gd:120` only downgrades `available` entries without a scene; `level_card.gd:63` shows Coming soon for `available = false`. Verify with the existing `test_main_menu.gd` / `test_level_card.gd` (Horde Rush card still Coming soon, Enter/click does nothing).
  - [x] 4.3 Debug overlay jump row (`scenes/debug/debug_overlay.tscn`, `scripts/debug/debug_overlay.gd`): add `JumpHordeRushButton` ("Horde Rush", font 8, `focus_mode = 0`, unique name) wired like the others with `_jump.bind(Router.Screen.RUN, {"level_id": &"horde_rush"})`, and add it to the `_refresh_jumps()` loop (`debug_overlay.gd:290`). The row was already 404 of 412 px in 6.2 (`screenshots/6-2/debug-overlay-jump-row.png`): put the level buttons and the screen buttons on two rows (e.g. a second `HBoxContainer` `JumpRow2` under `JumpRow`) rather than shrinking text below 8 px. Update the class doc line 18. Screenshot it.
- [x] **Task 5: Tests** (AC: 1–8)
  - [x] 5.1 `tests/unit/test_horde_rush_config.gd` (new): the shipped `.tres` loads as `HordeRushConfig`, `validate() == ""`, `duration_s == 300`, `lane_count == 5`, WORD mode, `space_is_input == false`, `case_sensitive == false`, band 3–5, `completion_bonus == 0`; `size_class_for` for lengths 1, 2, 3 → small (8 s, 1, 1); 4, 5 → medium (10 s, 2, 2); 6, 7, 12 → brute (13 s, 3, 3); `validate()` catches each bad case (no classes, zero crossing, 0 hits, non-ascending max, a 0 max that is not last, lane_count 0, LETTER mode, null word list, min > max) on in-test configs (`HordeRushConfig.new()`; never edit the shipped resource in a test — `duplicate(true)` it first if you start from it).
  - [x] 5.2 `tests/unit/test_horde_field.gd` (new; config built in-test with round numbers): spawn picks the class by `word.length()` and sets `hits_left`; ids 0, 1, 2…; a small marcher is not arrived at 7.9 s and is arrived at 8.0 s (also when fed as 480 × `1.0 / 60.0`); two marchers spawned at different times arrive independently and in spawn order; `advance` returns each arrival once and removes it; `advance(0)`, negative and `INF`/`NAN` deltas change nothing; `get_marching()` is a copy; lanes are always in `0..lane_count-1`, every lane is used over 500 spawns, and the same lane seed gives the same lane sequence (different seeds differ); the field never touches the global RNG (seed the global RNG, spawn, compare as `test_zombie_run_groups.gd::test_independent_of_the_global_rng` does).
  - [x] 5.3 `tests/unit/test_horde_rush_level.gd` (new; instance the real scene, call `create_target_source` with a seeded RNG, add to the tree like `test_zombie_run_level.gd::_make`): the source is a `WordSource` whose words are all 3–5 letters; `on_target_completed("cat")` adds exactly one view in the same call, at `x == SPAWN_X`, `y == lane_feet_y(lane)` with the lane the field reports, `scale == Vector2.ONE * 1.0`; a 4- or 5-letter word gives scale 1.25, a 6-letter word 1.5 (the level accepts any length; the source just never deals one yet); the copy has a `HatSlot` (`%HatSlot` exists under its Body); after simulated `_process` steps the view's x equals `march_x(progress)` of its marcher; at the crossing time the view is freed (`is_instance_valid` false after a frame / `get_view_count() == 0`) and `get_field().get_arrived_count() == 1`; after `on_run_ending` further `_process` calls change neither progress nor views and it returns 0.0; `get_brains_earned() == 0`; same run seed → same words and same lanes, and the lanes come from the second child RNG (expected lanes reproduced in the test from `rng.randi()` order: words seed first, lanes seed second); an invalid config (e.g. band 9–9) returns null without asserting.
  - [x] 5.4 `tests/unit/test_level_registry.gd` (fix the assertions this story knowingly changes, around lines 112–125): Horde Rush now has a scene whose root is a `LevelBase` and `registry.get_scene(&"horde_rush")` is non-null, still `available == false`, not debug_only, same picture and name; Pitchfork Panic keeps "no scene yet"; menu ids unchanged. Don't weaken anything else.
  - [x] 5.5 `tests/unit/test_debug_overlay.gd`: add `%JumpHordeRushButton` to `_jump_buttons`, its text to the texts list and `[Router.Screen.RUN, {"level_id": &"horde_rush"}]` to the expected jumps (keep the existing order, insert where the button sits).
  - [x] 5.6 `tests/integration/test_run_frame.gd` (extend; copy the existing helpers, recorder seams and temp `PlayerData` — never the real save): start `{"level_id": &"horde_rush", "seed": 7}`; typing every letter of the current word (from `get_session().get_current_target()`) → before `handle_key` returns for the last letter, the level's field has 1 marcher and the level has 1 view; Space is not judged; `get_duration() == 300.0`; `debug_end_run()` → the level is frozen and `RunResult.brains == 0`, `bonus_brains == 0`.
  - [x] 5.7 Check `test_main_menu.gd` and `test_level_card.gd` still pass untouched (Horde Rush Coming soon). If any test elsewhere asserts the Horde Rush entry has no scene, fix it the same way as 5.4.
- [x] **Task 6: Verification and wrap-up** (AC: 1, 4, 8)
  - [x] 6.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` (registers the new `class_name`s), then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Re-count the baseline before you start (last recorded: 1395 after 6.2, plus its review patches) and record before/after. Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 6.2 Visual check (real window via Godot MCP `run_project` or a scratch capture script modelled on `tools/capture_screens.gd`, temp save dir): jump to Horde Rush from F3, type several words, screenshot copies of mixed sizes marching in different lanes with the equipped hat on (equip one via F5 brains + the Closet, or a temp save). Save as `_bmad-output/implementation-artifacts/screenshots/6-3/horde-rush-field.png`, plus a 3× crop of a small and a medium copy side by side (`size-classes-3x.png`) to judge the 1.25 scale, and the debug overlay jump rows (`debug-overlay-jump-rows.png`).
  - [x] 6.3 `deferred-work.md`: strike through the 1.9 note "Brute size class … Story 6.3 decides …" with "Decided in 6.3: …" (the decision below), and the same sentence in `docs/art-style-sheet.md` §6 (line ~195) gets the decision in one line. Add new items only if found.
  - [x] 6.4 Commit the generated `.uid` files for the new scripts. No tag push (Horde Rush publishes after 6.8).

### Review Findings

- [x] [Review][Patch] (decided 1a: offset spawn/arrive x by half-width x scale) Scaled copies ignore `sprite_scale` at spawn and arrival — `SPAWN_X = 16` / `ARRIVE_X = 532` are fixed feet-centre pixels, so a medium copy clips ~4 px off the left edge (brute ~8 px) and on arrival reaches x=552/556, past the house wall at 548 (AC "touches the house front"). Options: (a) offset spawn/arrive x by half-width x scale, (b) accept for small, fix when the brute lands in Epic 7, (c) tune the two constants for medium. [horde_rush_level.gd:SPAWN_X, ARRIVE_X] (blind+edge+auditor)
- [x] [Review][Patch] (decided 2a: keep strict rule, amend spec Task 1.2 text) `validate()` is stricter than spec Task 1.2 — also rejects a config whose last size class has a non-zero `max_word_length` (documented as deliberate; guarantees `size_class_for()` is never null). Kept; Task 1.2 text amended. [horde_rush_config.gd] (auditor+blind)
- [x] [Review][Patch] `create_target_source` called twice on one level instance leaves stale state — `_views` and `%Zombies` children kept, `_frozen` not reset, new id 0 overwrites old `_views[0]`. Free/clear views and reset `_frozen` on re-create [horde_rush_level.gd:89-90]
- [x] [Review][Patch] Unguarded `PLAYER_ZOMBIE_SCENE.instantiate() as PlayerZombie` — a null cast crashes on `view.position` after the marcher is already spawned; instantiate/check before `_field.spawn()` or log and bail [horde_rush_level.gd:101-104]
- [x] [Review][Patch] Validation and guard gaps — `validate()` should require unique size-class ids and a `crossing_time_s` above a sane minimum (1e-4 s currently arrives instantly), and `HordeField.spawn` should guard `lane_count < 1`; the lane-fit overflow (7+ lanes, 6 already fails) should fail `validate()`/`_ready` rather than only log [horde_rush_config.gd:33,42; horde_field.gd:35; horde_rush_level.gd:57]
- [x] [Review][Patch] `has_arrived()` is true up to `ARRIVE_EPSILON_S` early while `progress()` is still < 1.0; make `progress()` return 1.0 once arrived, and move `ARRIVE_EPSILON_S` off `HordeField` so `HordeMarcher` does not depend on its owner [horde_marcher.gd, horde_field.gd]
- [x] [Review][Patch] Test gaps and fragility — no test for pause/countdown freezing the march (AC6) or for `on_target_completed` after `on_run_ending`; `test_validate_catches_each_bad_case` should assert the expected message per case; `seed()`-based tests should restore global RNG state; `_jump_buttons` line in test_debug_overlay.gd exceeds 120 chars [tests/unit/test_horde_rush_config.gd, test_horde_rush_level.gd, test_debug_overlay.gd]
- [x] [Review][Defer] Huge frame delta arrives every copy in one `advance` — deferred, matters when 6.5 turns arrivals into brains (cap/substep delta there) [horde_rush_level.gd:142, horde_field.gd:44-57]
- [x] [Review][Defer] Debug jump into `horde_rush` writes a real `run_history` entry that 6.8 backfill would count — deferred, already acknowledged in Dev Notes [debug_overlay.gd:81]
- [x] [Review][Defer] Backdrop hard-codes five lane `ColorRect`s while `lane_count` comes from config — deferred, shipped config is 5 [horde_rush_level.tscn]

## Dev Notes

### What this story is (and isn't)

- It is: the Horde Rush level shell (scene, `HordeRushConfig` + `horde_rush.tres`, registry scene, debug jump), the pure march model (`HordeField`/`HordeMarcher`), spawning a hatted copy per completed word in a seeded random lane, size classes from config with per-class sprite scale, the march driven by logical progress, a placeholder field, tests.
- It isn't: the defender, projectiles, hits, flashing, melting (6.4); arrival brains, shuffle-in, "Brainsss", `brains_earned_changed`, +25 bonus, outro (6.5); Farmhouse/Farmer art, march music, sounds, hat fit-check on scaled classes (6.6); tuning and the 30-zombie stress check / pooling (6.7); `available = true`, unlocks (6.7/6.8); tier bands (Epic 7). No save schema change, no new audio, no new textures.

### Design decisions already made (follow them)

- **Pure model + thin view.** The architecture's "logic leads, visuals chase" says gameplay reads logical values, never sprite positions (Horde Rush arrivals are named explicitly). Putting marchers in a RefCounted `HordeField` keeps the march headless-testable and is exactly what 6.4 ("headless simulation … deterministic") and 6.7 ("headless simulation that feeds words at 10 and 30 WPM") need. Precedent: `ZombieRunGroups` is a pure RefCounted in `scripts/levels/zombie_run/` with its own unit test.
- **Progress in seconds, not pixels.** All copies start at `SPAWN_X` and arrive at `ARRIVE_X`, so `elapsed_s / crossing_time_s` is the whole state; pixels are derived. The march is continuous (no key moves a marcher), so the view sets `position.x` from progress each frame — no tween needed. Store `elapsed_s` (not a progress float) so arrival is exactly "crossing time marched".
- **Spawn in the key's call stack.** `on_target_completed` runs synchronously inside `judge()` after `char_accepted` (6.2 order: `char_accepted` → `target_completed` → `target_changed`). Spawn the marcher and its sprite there; never `await` or defer.
- **RNG order.** `LevelBase` rule: the source gets its own child RNG. Words first (so a seed keeps its words, as in the test word level), lanes second (a dedicated child, one `randi_range` per spawn), the run RNG itself unused for now. Same pattern as Zombie Run (letters first, layout second, run RNG for the voice roll). If 6.4/6.5 need randomness they take a third child or the run RNG, and the lanes don't shift.
- **Copies are `player_zombie.tscn` instances.** Its `HatSlot` follows `PlayerData` by itself (`follow_equipped = true`), so the copies wear the equipped hat with no level code (FR43) and the level never touches `PlayerData` (boundary rule). Scaling the copy's root node scales Body and the hat together, which is the architecture's "same anchors serve Horde Rush size classes through the zombie's scale" (D6). Don't create a new character scene for copies in this story.
- **Arrival = free in 6.3.** Without it copies would pile up at the house. 6.5 replaces `_on_marcher_arrived` with the shuffle-in, Brainsss and brains; keep it one small method so that swap is local.
- **Hidden from kids, reachable for dev.** `LevelRegistry.get_scene()` ignores `available`, so RunFrame can start `horde_rush` from the debug jump while the menu keeps showing "Coming soon" (`level_card.gd:63`). That's the epic's intent ("the menu still shows Coming soon").
- **Size-class scale decision** (resolves the Story 1.9 defer, "redrawn 48×48 brutes or an integer scale"): scale per class lives in `horde_rush.tres` — small 1.0 (the approved 32 px sprite, crisp), medium 1.25 (40 px), brute 1.5 (48 px, the style sheet's brute size). Integer scale is ruled out: 2× is 64 px, taller than a 44 px lane. Redrawn 48 px brute sheets are not needed yet: before Epic 7 the band is 3–5, so **no brute ever spawns in Epic 6**. Fractional nearest scaling gives slightly uneven pixels; the style sheet already accepts uneven pixels at fractional window scales. If the 3× crop in Task 6.2 shows the 1.25 medium looks lumpy, set medium to 1.0 in the `.tres` (size then reads by speed only) and note it — it's a data change. 6.6 owns the final art and hat fit on scaled classes.
- **Brains and bonus stay 0.** RunFrame commits `get_brains_earned()` and `completion_bonus` on a timer end; leaving both 0 means a debug run of the unfinished level can't hand Smuck's save free brains. A finished debug run is still recorded in `run_history` with `level_id = horde_rush` (RunFrame does that for any level) — harmless now; note that 6.8's backfill would count it as a Horde Rush timer run (it only unlocks Pitchfork Panic, which stays Coming soon).

### Existing code to read first (current state → what changes → what must be preserved)

- **`scripts/run/level_base.gd`** (read only): the contract and call order; `on_target_completed` is called right after `on_char_accepted` on a word's last letter, with the source already advanced.
- **`scripts/levels/test_level/test_level.gd`** (read only): the word-mode `create_target_source` pattern (child RNG, `pool_from_json`, `< 2` words → null). Copy that pattern; don't import the test level (levels never import other levels).
- **`scripts/levels/zombie_run/zombie_run_level.gd`** (read only): config cast + validate pattern, `preload` scene consts, `setup` before `add_child`, seams, `on_run_ending` freeze, getters for tests, the long class doc style. Horde Rush needs no `play_sfx`/`request_voice` seams yet (no sounds until 6.5/6.6); don't add unused seams.
- **`scripts/resources/zombie_run_config.gd`** (read only): the `extends LevelConfig` + `validate()` shape to mirror.
- **`scripts/characters/player_zombie.gd`** + **`scenes/characters/player_zombie.tscn`** (read only): origin at the feet centre, Body at (-16, -31), `play_walk()` / `play_idle()` are cheap to call every frame, `SIZE_PX = 32`. The sprite faces right (Zombie Run walks right) — copies walk right too, no flip.
- **`scripts/cosmetics/hat_slot.gd`** (read only): follows `PlayerData` itself and disconnects in `_exit_tree`; freeing a copy is safe.
- **`scripts/run/run_frame.gd`** (no change): `_start_level` (registry lookup, null source → menu), `on_run_ending` on entering ENDING, `_record_result` reads brains and bonus. The tree pause (PAUSED/COUNTDOWN) freezes the level's `_process`.
- **`data/levels/level_registry.tres`**, **`scripts/debug/debug_overlay.gd`** (lines 18, 77–80, 288–291) + **`scenes/debug/debug_overlay.tscn`** (JumpRow at line ~63) (UPDATE).
- **`scripts/typing/word_source.gd`** (read only): `WordSource.new(rng, pool)`, `pool_from_json(json, min, max)`.

### Architecture and rules to follow

- Godot **4.7.2** (standard), Compatibility renderer, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed vars, typed arrays (`Array[HordeMarcher]`, `Array[HordeSizeClass]`), typed dictionaries (`Dictionary[int, PlayerZombie]`), typed loop vars, typed returns. Tabs. Short `##` docs that say why.
- New level checklist (architecture Consistency Rules): extends `LevelBase`, lives in `scenes/levels/horde_rush/` + `scripts/levels/horde_rush/`, registered in `level_registry.tres`. Mirrored paths: `scenes/levels/horde_rush/horde_rush_level.tscn` ↔ `scripts/levels/horde_rush/horde_rush_level.gd`.
- Boundaries: levels depend only on `LevelBase`, their own scenes, their `LevelConfig`, `AudioManager`, `HatSlot`/`PetSlot` (via the character scene). Never read input, touch the clock or write `PlayerData`. `scripts/resources/` holds definitions, `data/` holds instances; a `.tres` only references classes from `scripts/resources/`.
- No GDD number as a literal in a script: 5 lanes, 300 s, crossing times, hits, brains, the 3–5 band all live in `horde_rush.tres`. Pixel layout (lane height, spawn/arrive x) is UX layout and may be script consts (as Zombie Run's `GROUND_Y`).
- Randomness: injected RNGs only; `grep` for global `randi(`/`randf(` in `scripts/levels` must stay clean.
- Entities: `preload` the scene as a const, set it up before `add_child`, free when done. No pooling (6.7 adds it only if the stress check fails).
- Logging: `Log.error/warn/debug(&"level", …)`; nothing logged per frame in `_process`.

### UX contract

- Mock: `ux-designs/.../mockups/key-run-hud.html` frame B (Flow 1 step 9): playfield 640 × 256, sky band at the top, 5 alternating green lanes of 44 px from y 36, the house filling the right edge from x ~540–548, pause button top-right, the shared 104 px HUD band below with the word sign. The mock's missing brain counter is known drift (DESIGN.md:326; D15 puts it in every level) — the shared HUD already shows it.
- EXPERIENCE.md Flow 1 step 9: "a copy of his zombie, *wearing his pumpkin hat*, shuffles off down a lane toward a farmhouse while the next word is already waiting."
- The HUD's start prompt strip (y 228–252) and Caps Lock hint (y 196–224) overlap lanes 4–5. The prompt only shows before the first key (no copies yet) and the hint is transient — accepted; don't move the HUD.
- Palette only (32 colours, `docs/art-style-sheet.md`); the placeholder field must not introduce new colours. Tone: no guns, nothing scary (NFR10) — nothing in this story shows the defender.

### Testing notes

- Run `--import` after adding the new `class_name` scripts, before GUT.
- Freeing: a `queue_free`d view is still valid until the end of the frame; in tests either `await wait_frames(1)`/`wait_process_frames` or assert via `get_view_count()` / `get_view(id) == null` (the dictionary entry is erased in the same call).
- Driving `_process` in unit tests: call `level._process(delta)` directly with fixed deltas (as the Zombie Run tests do), so arrival timing is exact and independent of the test runner's frame rate.
- Never assign to the shipped `horde_rush.tres` in a test (resources are cached and shared across tests): `duplicate(true)` it or build a `HordeRushConfig.new()`.
- Integration tests: copy `tests/integration/test_run_frame.gd` helpers (`_make`, `_start`, `_send`, recorder seams, temp `PlayerData`). `LetterBagSource`/`TypingSession` debug asserts must never be triggered from tests.

### Previous story intelligence (6.2)

- `WordSource extends LetterBagSource` (bag = every word once before a repeat, no immediate repeat across bags); `pool_from_json` logs and filters bad entries, never asserts. 191 words in the 3–5 band.
- `TypingSession` emits `target_completed(word)` only in word/paragraph mode, after `char_accepted`, and counts an implied space per word (WORD mode) — WPM already includes them in the HUD, overlay and `RunResult.completed_words`. Nothing to do here for WPM.
- The HUD is refreshed from `_on_session_char_accepted`; word display (green typed letters, 2 px underline, hands on the cursor letter) is done and must not change.
- `UNDERLINE_GAP` was accepted at 0 in review. The words.json web-export load check is still open from 6.1/6.2 (only "if you run a web export").
- Debug jump row: 4 buttons used 404 of 412 px — a 5th needs a second row (Task 4.3).
- Lessons kept: edit story-file sections line-anchored; LF endings for new text files; record any Smuck decision verbatim with a date; debug-only labels are not kid-facing copy (don't add "Horde Rush" jump text to `APPROVED_COPY` — "Horde Rush" is already approved as the level name).

### Git intelligence

- One commit per story on `main`, then "Story 6.3: code review patches applied, done" after review. Use `Story 6.3: horde rush field, spawning and size classes`.
- Expected changes: `scripts/resources/horde_size_class.gd`, `scripts/resources/horde_rush_config.gd`, `scripts/levels/horde_rush/horde_marcher.gd`, `horde_field.gd`, `horde_rush_level.gd` (+ `.uid`s), `scenes/levels/horde_rush/horde_rush_level.tscn`, `data/levels/horde_rush.tres`, `data/levels/level_registry.tres`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`, tests (`test_horde_rush_config.gd`, `test_horde_field.gd`, `test_horde_rush_level.gd` new + `test_level_registry.gd`, `test_debug_overlay.gd`, `test_run_frame.gd`), `deferred-work.md`, `docs/art-style-sheet.md` (one line), screenshots, this file, `sprint-status.yaml`. Nothing in `scripts/autoloads/`, `scripts/typing/`, `scripts/run/`, `project.godot`, `export_presets.cfg`, `.github/`, `assets/`.

### Project Structure Notes

- All new files follow the architecture tree: `scenes/levels/horde_rush/` and `scripts/levels/horde_rush/` ("# Epic 6" placeholders), config classes in `scripts/resources/`, the instance in `data/levels/horde_rush.tres` (level configs use the level id).
- `HordeField`/`HordeMarcher` sit with the level (not in `scripts/typing/`) because they are Horde Rush rules, not typing rules; they still get unit tests like `ZombieRunGroups`.
- `HordeSizeClass` is its own Resource file so the `.tres` can hold typed sub-resources (`Array[HordeSizeClass]`).

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md` (Typing Pipeline & Level Contract, Logic Leads Visuals Chase, Entity Patterns, Configuration, Architectural Boundaries, Consistency Rules), the GDD (*Level 2: Horde Rush*, size-class table, art reuse) and the UX spines (mock frame B, Flow 1 step 9).
- Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, Godot MCP available (`run_project`, `get_debug_output`) for the visual check.

### Latest tech information

- No new libraries or engine features. Godot 4.7.2 notes that matter here: `Node2D.y_sort_enabled` sorts children by their `position.y` (copies' origin is at the feet, so lower lanes draw in front); typed sub-resource arrays in a `.tres` use `Array[ExtResource("…")]([SubResource("…"), …])` exactly as `level_registry.tres` does; `RandomNumberGenerator.randi_range(from, to)` is inclusive at both ends.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.3: Horde Rush Field, Spawning and Size Classes] (ACs); Epic 6 header; Stories 6.4–6.8 (consumers of the field and config)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR3, FR4, FR26, FR43, FR53, FR54, FR55, FR59; NFR1, NFR2, NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Level 2: Horde Rush (~308–326), Art Reuse (~371), brutes 48×48 (~368)
- [Source: _bmad-output/game-architecture.md] Typing Pipeline & Level Contract, Cosmetics (D6, scale), Logic Leads Visuals Chase, Entity Patterns, Configuration, Directory Structure, Consistency Rules
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/mockups/key-run-hud.html] frame B; [EXPERIENCE.md] Flow 1 step 9 (~251); [DESIGN.md] mock drift note (~326)
- [Source: docs/art-style-sheet.md] §3 Sprites (sizes), Scaling (~149), §6 Reuse rules (~195)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] Story 1.9 brute size-class note (~106), ambience note (~359)
- [Source: _bmad-output/implementation-artifacts/6-2-word-target-mode.md] completion order, WordSource, jump row width
- [Source: scripts/run/level_base.gd], [scripts/levels/test_level/test_level.gd], [scripts/levels/zombie_run/zombie_run_level.gd], [scripts/resources/zombie_run_config.gd], [scripts/characters/player_zombie.gd], [scripts/cosmetics/hat_slot.gd], [scripts/resources/level_registry.gd], [scripts/screens/main_menu.gd:120], [scripts/ui/level_card.gd:63], [scripts/debug/debug_overlay.gd:18,77-80,288-291], [tests/unit/test_level_registry.gd:112-125], [tests/unit/test_debug_overlay.gd:507-535]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline before the story: 1395 tests / 1395 passing (81 scripts after: 78 before). After: 1432 / 1432 passing (+37). No `Parse Error|Compile Error|Failed to load script` in the log. The 4 "Villager state can only move forward" SCRIPT ERROR lines are in the baseline log too (an existing test provokes them on purpose).
- `grep` for global `randi(`/`randf(` in `scripts/levels`: only doc comments in `zombie_run_level.gd`; nothing in `horde_rush/`.
- Visual check: a scratch capture script (deleted after use) ran the real RunFrame on `horde_rush` seed 7 in a real window, with the live `SaveService` pointed at a temp dir (pumpkin hat bought and equipped there); the real `user://save.json` hash was identical before and after.

### Completion Notes List

- **Config:** `HordeSizeClass` (Resource) + `HordeRushConfig extends LevelConfig` with `size_class_for()` and `validate()`. `validate()` also requires the **last** class to be unbounded (`max_word_length == 0`), so `size_class_for()` is null only when the list is empty, as the task specifies. `horde_rush.tres` ships 300 s, WORD, band 3–5, 5 lanes, small/medium/brute = (≤3, 8 s, 1, 1, ×1.0) / (≤5, 10 s, 2, 2, ×1.25) / (rest, 13 s, 3, 3, ×1.5), `completion_bonus = 0`, `music_id = &""`.
- **Model:** `HordeMarcher` (RefCounted: id, word, lane, size_class, elapsed_s, hits_left, `progress()`, `has_arrived()`) and `HordeField` (RefCounted: `spawn`, `advance`, getters; `ARRIVE_EPSILON_S = 1e-4`, so 480 × 1/60 arrives on frame 480). One `randi_range` per spawn on the injected lane RNG. `spawn()` returns null and logs if a config somehow has no class for a length (defensive; validate() prevents it).
- **Level:** `horde_rush_level.gd` validates the config, seeds words first and lanes second from the run RNG (run RNG otherwise unused and reserved), spawns the marcher and then a `player_zombie.tscn` copy (position + scale set before `add_child` to `%Zombies`) inside `on_target_completed`, and derives each sprite's x from `progress()` in `_process`. Arrival frees the sprite in `_on_marcher_arrived` (one method for 6.5 to replace). `on_run_ending` freezes the march, returns 0.0; `get_brains_earned()` = 0. Layout consts: lanes from y 36, 44 px, feet inset 6 (feet y 74…250), SPAWN_X 16, HOUSE_FRONT_X 548, ARRIVE_X 532; a too-many-lanes config logs an error and still runs.
- **Scene:** placeholder field in palette colours only (sky #7EC8E3, lanes #4E9A34/#2E6B26, house #8A5228 with an ink edge and a #5A3218 door at the bottom), `%Zombies` y-sorted.
- **Registry/menu:** `horde_rush` now has its scene, still `available = false` (menu shows Coming soon; `test_main_menu.gd` / `test_level_card.gd` pass untouched).
- **Debug overlay:** "Horde Rush" jump button on `%JumpRow` (level jumps); "Welcome gift" / "Keyboard test" moved to a new `%JumpRow2`, all still 8 px. Class doc updated.
- **Size-class scale decision:** kept medium at 1.25 after the 3× crop (`size-classes-3x.png`): slightly uneven pixels, clearly reads as bigger. Recorded in `deferred-work.md` (struck through the 1.9 note) and in one line of `docs/art-style-sheet.md` §6.
- **Tests:** new `test_horde_rush_config.gd` (7), `test_horde_field.gd` (12), `test_horde_rush_level.gd` (15); `test_level_registry.gd` (Horde Rush has a LevelBase scene, still Coming soon; Pitchfork Panic still no scene); `test_debug_overlay.gd` (new button, texts, jumps, two-row layout test); `test_run_frame.gd` (+2 Horde Rush integration cases: spawn in the last key's call, Space ignored, 300 s, end freezes, brains and bonus 0).
- Run note: a finished debug run of Horde Rush is still recorded in `run_history` with `level_id = horde_rush` (RunFrame does that for every level); harmless now, as the story notes.

### File List

- `scripts/resources/horde_size_class.gd` (new) + `.uid`
- `scripts/resources/horde_rush_config.gd` (new) + `.uid`
- `scripts/levels/horde_rush/horde_marcher.gd` (new) + `.uid`
- `scripts/levels/horde_rush/horde_field.gd` (new) + `.uid`
- `scripts/levels/horde_rush/horde_rush_level.gd` (new) + `.uid`
- `scenes/levels/horde_rush/horde_rush_level.tscn` (new)
- `data/levels/horde_rush.tres` (new)
- `data/levels/level_registry.tres` (modified)
- `scripts/debug/debug_overlay.gd` (modified)
- `scenes/debug/debug_overlay.tscn` (modified)
- `tests/unit/test_horde_rush_config.gd` (new) + `.uid`
- `tests/unit/test_horde_field.gd` (new) + `.uid`
- `tests/unit/test_horde_rush_level.gd` (new) + `.uid`
- `tests/unit/test_level_registry.gd` (modified)
- `tests/unit/test_debug_overlay.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/screenshots/6-3/horde-rush-field.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/6-3/size-classes-3x.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/6-3/debug-overlay-jump-rows.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `docs/art-style-sheet.md` (modified)
- `_bmad-output/implementation-artifacts/6-3-horde-rush-field-spawning-and-size-classes.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- 2026-10-07: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-07: Implemented (review). Horde Rush level shell, HordeRushConfig + size classes, pure HordeField march model, a hatted copy per completed word in a seeded lane, registry scene (still Coming soon), debug jump on a second row, size-class scale decision recorded; 1395 → 1432 tests, all passing.
- 2026-10-07: Code review patches applied (scale-aware spawn/arrive x, level re-entry reset, null-view guard, validation gaps, progress/arrival agreement, test gaps); 1432 → 1439 tests passing. Done.
