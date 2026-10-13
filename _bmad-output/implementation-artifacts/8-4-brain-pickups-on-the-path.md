---
baseline_commit: 0b4c9e9b4c0fa52ff7ddc15f69806b100c2864c3
---

# Story 8.4: Brain Pickups on the Path

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want to scoop up brains along the path as I type,
so that typing more earns more.

## Acceptance Criteria

1. **Placement by distance (FR72).** Pickups sit on the path at logical step positions. The first is `randi_range(pickup_min_steps, pickup_max_steps)` steps after the start (step 0); each next one is `randi_range(min, max)` steps after the previous one (inclusive, uniform). The shipped config has `pickup_min_steps = 10`, `pickup_max_steps = 30`, `brains_per_pickup = 5`. The draws come from the pickups' **own child RNG**, seeded from the run RNG, exactly one draw per pickup placed. Positions never depend on time, frame rate or the sprite.
2. **Collected by typing forward (FR72, FR14).** When a correct key raises `ChaseModel.zombie_steps` to (or past) a pickup's step, that pickup is collected **in the key's own call**, before any visual: the run's brain total grows by `brains_per_pickup`, `brains_earned_changed(total)` is emitted (RunFrame already forwards it to `%Hud.set_brains`, so the HUD counter updates in the same frame), and the pickup sound plays through the `play_sfx` seam. `get_brains_earned()` returns the total. Wrong keys, keys before `on_run_started`, and keys after `on_run_ending` collect nothing.
3. **Pickup sound.** A new cue `sfx_brain_pickup` in `data/audio/audio_library.tres`. Until Story 8.6 delivers its own file, its stream is the existing `sfx_brain_bonk.wav` (already credited, so `CREDITS.md` does not change). The level plays it with `play_sfx.call(&"sfx_brain_pickup")` once per collected pickup, in the logic path, never from a tween.
4. **Visible on the path.** Each placed pickup is a node in the world (`%Pickups` under `%World`, drawn behind the zombie and the mob) at `world x = step × step_px`, sitting on `GROUND_Y`, using the existing cartoon brain art (`assets/sprites/props/brain_pop.png`, NFR10). Pickups are placed far enough ahead that each one exists before it scrolls in from the right edge (the lookahead covers the screen ahead of the zombie plus a margin). On collection the node shows the existing `BrainPop` rise (`scenes/levels/zombie_run/brain_pop.tscn`) and frees itself. No new art files.
5. **Seed replay stays exact.** The paragraph child RNG is still the run RNG's **first** draw (so the same seed deals the same text as in 8.3); the pickup child RNG is the **second**. After `create_target_source` the run RNG is never drawn again. Same seed → same pickup positions; the chase model still draws nothing.
6. **Economy sanity (NFR15, checked fully in 8.7).** Over a long seeded sequence the mean gap is 20 steps (±0.5) and the pay is ≈ 0.25 brains per correct character (±5%), matching the GDD's "≈0.25 brains per character, like brain blocks".
7. **Results keep the brains.** The run's `RunResult.brains` is the level's pickup total, for a caught run and for a timer-ended run (the interim 8.3 endings). Quit to Menu keeps them too (RunFrame already adds `get_brains_earned()` on quit). No bonus changes here (8.5 owns +10/+25; `completion_bonus` stays 0).
8. **Hidden tier and plain words (FR60).** Nothing added names a tier, WPM or WPM-eq. No new kid-facing text (the HUD brain counter is the only feedback).
9. **Nothing else regresses.** Zombie Run, Horde Rush, the Test text level and the menu (Pitchfork Panic still "Coming soon", `available = false`) behave as before. The 8.3 tests that pinned "no brains" are updated to the new behaviour, nothing else. Full GUT suite green, no parse errors.

## Tasks / Subtasks

- [x] **Task 1: Config numbers** (AC: 1, 6)
  - [x] 1.1 `scripts/resources/pitchfork_panic_config.gd`: add `@export var pickup_min_steps: int = 0`, `pickup_max_steps: int = 0`, `brains_per_pickup: int = 0` with `##` docs citing FR72 (neutral defaults like the rest). Extend `validate()`, after the existing checks: `pickup_min_steps >= 1` ("pickup_min_steps must be at least 1"), `pickup_max_steps >= pickup_min_steps` ("pickup_max_steps must not be below pickup_min_steps"), `brains_per_pickup >= 1` ("brains_per_pickup must be at least 1"). Update the class doc (Story 8.4 numbers).
  - [x] 1.2 `data/levels/pitchfork_panic.tres`: add `pickup_min_steps = 10`, `pickup_max_steps = 30`, `brains_per_pickup = 5`.
  - [x] 1.3 `tests/unit/test_pitchfork_panic_config.gd`: the shipped-values test asserts the three new numbers; the bad-numbers table gets `pickup_min_steps = 0`, `pickup_max_steps` below min (e.g. min 10, max 9), `brains_per_pickup = 0`, each rejected with its own message.
- [x] **Task 2: `PickupTrail`, the pure placement logic** (AC: 1, 2, 5, 6)
  - [x] 2.1 Create `scripts/levels/pitchfork_panic/pickup_trail.gd`: `class_name PickupTrail extends RefCounted` (no nodes, no clock, like `ChaseModel`). `_init(rng: RandomNumberGenerator, min_steps: int, max_steps: int)`. A null RNG or bad numbers (min < 1, max < min) gives a trail that places nothing (safety net; the level refuses an invalid config before this).
  - [x] 2.2 API (keep it this small):
    - `fill_to(step: int) -> Array[int]`: places pickups while the last placed position is `< step` (the first one counted from 0), one `rng.randi_range(min, max)` per pickup, and returns the **newly placed** positions in order;
    - `collect(zombie_steps: int) -> int`: removes every not-yet-collected pickup with position `<= zombie_steps` from the front of the queue and returns how many (loop, though with `min >= 1` and one step per key it is 0 or 1);
    - `upcoming() -> Array[int]`: a copy of the placed, uncollected positions (for the level and tests).
  - [x] 2.3 `tests/unit/test_pickup_trail.gd`:
    - seeded oracle written out by hand: with an RNG seeded `S`, the trail's positions equal a running sum of `randi_range(10, 30)` drawn from a **separate** RNG seeded `S` (independent oracle, not the trail against itself);
    - every gap in `[10, 30]` over 10,000 pickups, all 21 values appear, mean 20 ±0.5;
    - `collect`: nothing at step 9 when the first is at ≥ 10; exactly one when the zombie reaches the position; nothing twice; `collect` with a jump past two pickups returns 2;
    - `fill_to` is idempotent (calling it again with the same or a lower step places nothing new) and draws exactly one RNG value per pickup (compare the RNG `state` with an oracle RNG that drew N times);
    - same seed → same positions; null RNG / min 0 / max < min → `fill_to` returns `[]`, `collect` returns 0;
    - economy: walk 10,000 steps with `fill_to(step + 20)` then `collect(step)` each step; collected × 5 / 10,000 is 0.25 ±5%.
- [x] **Task 3: The pickup node** (AC: 4)
  - [x] 3.1 `scripts/levels/pitchfork_panic/brain_pickup.gd` (`class_name BrainPickup extends Node2D`, class doc) and `scenes/levels/pitchfork_panic/brain_pickup.tscn`: an `AnimatedSprite2D` (`%Sprite`) using the two 16×16 frames of `assets/sprites/props/brain_pop.png` (copy the `SpriteFrames` block from `brain_pop.tscn`, autoplay), origin = bottom centre on the ground line, lifted a few px (`LIFT_PX`, look value) so it reads as sitting on the path, not in it. A missing sprite logs one `Log.warn(&"level", ...)` and never stops the run (NFR16, as `BrainBlock` does).
  - [x] 3.2 `collect() -> void`: instances `BrainPop` (`preload("res://scenes/levels/zombie_run/brain_pop.tscn")`) at its own position under its parent (so the pop keeps rising after the pickup is freed), then `queue_free()`. Calling it twice is harmless. No sound here (the level plays it in the logic path).
  - [x] 3.3 Add a short test (in `test_pitchfork_panic_level.gd` or its own `test_brain_pickup.gd`): `collect()` leaves one `BrainPop` in the parent and the pickup is queued for deletion.
- [x] **Task 4: The level** (AC: 1, 2, 4, 5, 7, 8)
  - [x] 4.1 `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`: add `Pickups` (`Node2D`, unique name) under `World`, **before** `Mob` and `Zombie` in the tree so pickups draw behind them. Keep the header `load_steps` correct.
  - [x] 4.2 `pitchfork_panic_level.gd`:
    - add the `play_sfx: Callable` test seam exactly like `ZombieRunLevel`/`HordeRushLevel` (`_ready()` points it at `AudioManager.play_sfx` unless a test set it before `add_child`), and `const SFX_PICKUP: StringName = &"sfx_brain_pickup"`;
    - `create_target_source(rng)`: keep `child.seed = rng.randi()` **first** (paragraph, unchanged), then a second child `pickup_rng.seed = rng.randi()`, build `_trail = PickupTrail.new(pickup_rng, _cfg.pickup_min_steps, _cfg.pickup_max_steps)`, reset `_brains = 0`, free any old pickup nodes, and place the first nodes with `_fill_pickups()`. Do not keep the run RNG;
    - `_fill_pickups()`: `for step: int in _trail.fill_to(_model.zombie_steps + _pickup_lookahead_steps())` → instance `BrainPickup`, `position = Vector2(step × step_px, GROUND_Y)`, add to `%Pickups`, remember it by step (e.g. `Dictionary[int, BrainPickup]` or an ordered array). `_pickup_lookahead_steps()` = `ceili((SCREEN_W − get_zombie_screen_x()) / step_px) + PICKUP_LOOKAHEAD_MARGIN_STEPS` (margin 2, a layout constant documented "not a GDD number"; 18 steps with the shipped config);
    - `on_char_accepted`: after the existing `_running` guard and `_model.step()`, call `_collect_pickups()` (logic: `n = _trail.collect(_model.zombie_steps)`; if `n > 0`: `_brains += n × brains_per_pickup`, `brains_earned_changed.emit(_brains)`, `play_sfx` once per pickup, then `collect()` on each matching node); **then** the visuals (`_walk_to`, `_fill_pickups()`, `_update_views()`). All synchronous, no `await` (NFR2);
    - `get_brains_earned()` returns `_brains`; add `get_pickup_trail() -> PickupTrail` (null before `create_target_source` succeeds, for tests and the 8.7 sim), like `get_model()`;
    - `on_run_ending` changes nothing about pickups (remaining nodes stay where they are, nothing more is collected because `_running` is false);
    - update the class doc: drop "No brains yet (Story 8.4)", describe pickups, the second child RNG and the sound seam.
  - [x] 4.3 `tests/unit/test_pitchfork_panic_level.gd`: set the `play_sfx` recorder in `_make` before `add_child_autofree` (like `test_zombie_run_level.gd` lines ~33–44). Replace the "brains stay zero" checks (lines ~55, ~131–137) with:
    - brains are 0 and nothing emitted before the first pickup; typing up to `upcoming()[0]` emits `brains_earned_changed(5)` exactly on that key (not one key earlier), in the key's own call (before any `_process`), and plays exactly one `sfx_brain_pickup`;
    - typing through several pickups: total = 5 × collected, one emit and one sound per pickup, emits carry the running total;
    - wrong keys, keys before `on_run_started` and keys after `on_run_ending` collect nothing and emit nothing;
    - run RNG: after `create_target_source` with seed 42 its `state` equals an oracle RNG seeded 42 that drew `randi()` twice, and it is unchanged after 200 keys (no other consumer; mirror `test_run_rng_has_one_consumer`);
    - seed replay: the first passage for seed 42 is the same as before this story (build the oracle `ParagraphSource` with a child seeded from the oracle's first `randi()`), and two levels with seed 42 have the same `upcoming()`;
    - nodes: every placed position has a `BrainPickup` in `%Pickups` at `x = step × 16`, `y = GROUND_Y`; after any number of keys the furthest node is at least `ceil(256/16)` steps ahead of the logical zombie (so it exists before it scrolls in); a collected node is queued for deletion and a `BrainPop` appears;
    - `%Pickups` is before `%Mob` and `%Zombie` in `World`'s children.
- [x] **Task 5: Audio cue** (AC: 3)
  - [x] 5.1 `data/audio/audio_library.tres`: add a sub-resource `Resource_pickup` (`id = &"sfx_brain_pickup"`, `stream = ExtResource("13_bonk")`, `volume_db = -6.0`, no throttle) and append it to `cues`. No new ext_resource, no new audio file.
  - [x] 5.2 `tests/unit/test_audio_library.gd`: add `&"sfx_brain_pickup"` to `SFX_IDS` (the "nothing else" count must still match). The WAV-spec and credits tests pass unchanged because the stream is the already-checked bonk file. Add one line to the test or a comment saying the stream is a placeholder until 8.6.
- [x] **Task 6: Integration through RunFrame** (AC: 2, 7, 9)
  - [x] 6.1 `tests/integration/test_run_frame.gd`, `test_pitchfork_types_the_paragraph_one_step_per_key`: the last line asserts the HUD brain counter is `"0"` after 25 keys ("no brains in this story"); with pickups at 10–30 steps that may no longer hold. Change it to: read `level.get_pickup_trail().upcoming()[0]` (at most 30) before typing, type exactly that many characters of `passage` (passages are 150+ characters, so no join Space is needed; assert `first_pickup < passage.length()` first), and assert the HUD counter reads `"0"` one key before and `"5"` on that key.
  - [x] 6.2 New: a caught run after collecting one pickup records `RunResult.brains == 5` and `bonus_brains == 0`; the injected `player_data` wallet grew by 5.
  - [x] 6.3 Check that nothing else in the file assumes Pitchfork pays 0.
- [x] **Task 7: Visual check and wrap-up** (AC: 4, 9)
  - [x] 7.1 Run the import, then the full GUT suite. Baseline **1926 passing / 102 scripts** (Story 8.3 final); re-run it first. Grep the log for `Parse Error|Compile Error|Failed to load script`. Record the new totals.
  - [x] 7.2 Visual check as in 8.3 Task 5.2 (a throwaway scene under `tools/_scratch_8_4/`, deleted afterwards, or the Godot MCP `run_project`; a `-s` SceneTree script cannot see the autoloads). Tier 3 temp save (never the real save), fixed seed. Capture: (a) the start with the first pickup visible or entering from the right; (b) the frame a pickup is collected (pop rising, HUD counter 5); (c) two pickups on screen if the seed gives a short gap. Confirm pickups sit on the ground line, behind the zombie, readable against the placeholder backdrop, and don't overlap the HUD band. Save to `_bmad-output/implementation-artifacts/screenshots/8-4/`. Show Smuck in chat for layout/readability only (art is placeholder until 8.6); record the verdict verbatim in Completion Notes.
  - [x] 7.3 Commit the new `.uid` files (`pickup_trail.gd`, `brain_pickup.gd`, the new tests). List every new file in the File List.
  - [x] 7.4 `deferred-work.md`: add "Deferred from: dev of story 8-4" with the *Known limitations* you confirm.
  - [x] 7.5 Mark sprint-status `8-4-brain-pickups-on-the-path: review` (dev-story does this).

## Dev Notes

### What this story is (and isn't)

- **It is:** distance-based brain pickups for Pitchfork Panic: the config numbers, a pure `PickupTrail`, a `BrainPickup` node using existing brain art, the level awarding brains and playing a sound in the key's call, and a placeholder `sfx_brain_pickup` cue.
- **It isn't:** the caught/escaped endings or bonuses (8.5), Moonlit Village art, mob sprites, chase music or the **final** pickup sound file (8.6), economy tuning or making the card selectable (8.7). Keep `available = false` and `completion_bonus = 0`.
- **No change** to `LevelBase`, `RunFrame`, the HUD, `TypingSession`, `ParagraphSource`, `ChaseModel`, `AudioManager`, the save schema or `PlayerData`. RunFrame already connects `brains_earned_changed` to `%Hud.set_brains` (`run_frame.gd:274`), reads `get_brains_earned()` for the result (`:449`) and on quit (`:423`).

### The numbers (don't re-derive)

- Mean gap with `randi_range(10, 30)` is 20 steps, so 5 brains / 20 steps = **0.25 brains per correct character** (GDD economy table: "like brain blocks").
- GDD check at 10 WPM: a caught run lasts ≈ 144.8 s at 0.833 steps/s ≈ 120 steps ≈ 6 pickups = 30 brains; with 8.5's +10 that is ≈ 40 (GDD ≈ 40). At 20 WPM an escape is 300 s × 1.667 ≈ 500 steps ≈ 25 pickups = 125, + 10 + 25 = 160 (GDD ≈ 160). These are for context only; 8.7 runs the parity sim.
- Screen: the zombie is at screen x 384, so 256 px = 16 steps are visible ahead. Lookahead 16 + 2 = 18 steps means a pickup node always exists before it enters the screen. If 8.7 changes `step_px` or the camera fraction the formula follows.
- `randi_range(from, to)` in Godot 4 is **inclusive** on both ends.

### Collection, timing and "logic leads"

- Collection is a logical event on the key: `_model.step()` → `_trail.collect(zombie_steps)` → brains + signal + sound → then visuals. The sprite lags the logical step by up to a step or more at fast typing (8.3 deferred note: 16·(0.1 − d)/d px), so the brain pops when the sprite is just short of it. That is the accepted "logic leads, visuals chase" trade, same as the Zombie Run bonk. Do not delay the award until the sprite arrives.
- The award happens only in `on_char_accepted`, never in `_process`: the mob moving cannot collect anything, and pause freezes nothing because nothing is time-based.
- `_running` already guards `on_char_accepted` (the key the session judges after `on_run_ending` in the same frame). Keep the collection after that guard.

### RNG (seed replay is a tested contract)

- LevelBase rule: the source owns a child RNG seeded from the run RNG; a level may draw more child seeds. Order is the contract: **1st `randi()` → paragraph child (unchanged from 8.3), 2nd → pickup child.** Adding the second draw after the first keeps every existing seed's text identical.
- Deferred note (story 3.x, `deferred-work.md` ~line 287): any new consumer of a run RNG shifts later draws; that is why the pickups get their own child and the run RNG is not kept.
- No global `randi()`/`randf()`/`shuffle()` anywhere.

### Existing code to read first

| File | Current state | This story |
|---|---|---|
| `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` | Chase level from 8.3; `get_brains_earned()` returns 0; `_running` guard in `on_char_accepted`; `process_priority = -1` | Add trail, nodes, brains, sound seam; keep everything else |
| `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn` | `Backdrop`, `World/{Mob, Zombie}`, `MobGlow` | Add `World/Pickups` first in `World` |
| `scripts/levels/pitchfork_panic/chase_model.gd` | Pure model, `zombie_steps` | **No change**; read `zombie_steps` |
| `scripts/resources/pitchfork_panic_config.gd`, `data/levels/pitchfork_panic.tres` | Chase numbers + `validate()` | Add 3 pickup numbers |
| `scripts/levels/zombie_run/zombie_run_level.gd` | `play_sfx`/`request_voice` seams set in `_ready` unless pre-set; brains + `brains_earned_changed` in the key's call; child RNGs | Copy the seam and award pattern |
| `scripts/levels/zombie_run/brain_block.gd`, `brain_pop.gd` + scenes | Brain art, self-freeing pop | Reuse `brain_pop.tscn` and the `brain_pop.png` frames; don't edit them |
| `data/audio/audio_library.tres`, `tests/unit/test_audio_library.gd`, `tests/unit/test_audio_credits.gd` | 20 cues; `SFX_IDS` list with a "nothing else" count; credits per file | Add 1 cue reusing the bonk stream; add the id to `SFX_IDS` |
| `tests/unit/test_pitchfork_panic_level.gd`, `tests/integration/test_run_frame.gd` (~1960–2030) | Assert brains 0 / counter "0" | Update to pickups |

### What must keep working (regression guard)

- `test_zombie_run_level.gd`, `test_horde_rush_level.gd`, `test_test_level.gd`, `test_run_frame.gd`, `test_main_menu.gd`, `test_level_card.gd`, `test_level_unlocks.gd`, `test_audio_*.gd`, `test_chase_model.gd`, `test_pitchfork_panic_config.gd`.
- The 8.3 behaviours: one step per key in the same call, camera at x 384, mob glow, catch emitted once, catch-before-timer priority, used passages at the first key and each completion.
- Unlocks: a caught Pitchfork run still unlocks nothing.

### Known limitations (note in deferred-work; don't fix here)

- `sfx_brain_pickup` reuses the bonk WAV; 8.6 adds the real file, points the cue at it and credits it.
- No "Brainsss" voice line on pickup (Zombie Run rolls 20%, Horde Rush asks every arrival). Not in the ACs; adding a roll would need another child RNG. A playtest call for 8.7.
- The brain pops a little before the lagging sprite reaches it when typing fast (logic leads).
- Pickups left on the path when the run ends stay where they are; 8.5's ending visuals decide whether to hide them.

### Architecture and rules

- **ADR-1 pipeline:** a level never reads input, the clock or `PlayerData` and never calls the Router; it emits `brains_earned_changed`. Logic leads, visuals chase.
- **Same-frame rule (NFR2):** the award, the signal and the sound happen in the key's call; no `await`, deferred call or timer.
- **GDScript:** static typing everywhere (`untyped_declaration = Error`, typed loop variables, typed arrays/dictionaries), tabs, `##` docs on classes and public functions, `snake_case` files, `PascalCase` classes, `UPPER_SNAKE` constants, StringName log tags. Content/config errors never `assert` (NFR16).
- **Placement:** pure logic and level scripts in `scripts/levels/pitchfork_panic/`, scenes in `scenes/levels/pitchfork_panic/`, tests in `tests/unit/`, data in `data/`.
- **Never mutate shared resources:** read the config `.tres`, never write it; tests `duplicate(true)` before tweaking (the existing `_make(seed, tweak)` helper does).

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. One script: `-gdir=res://tests/unit -gselect=<name>`.
- GUT skips a script that fails to parse and still exits 0: grep for `Parse Error|Compile Error|Failed to load script`.
- Independent oracles: a separately seeded RNG for positions, written-out values (5 brains, x = step × 16), never the trail against itself. Assert data is non-empty before looping.
- Signals: `watch_signals(_level)`, `assert_signal_emit_count`, `get_signal_parameters(_level, "brains_earned_changed", i)`.
- Freed nodes: after `collect()`, `is_queued_for_deletion()`; for the pop, check the parent's children.
- Tests never write the real save (inject `PlayerData` on a temp `SaveService`, as `test_run_frame.gd` does).

### Previous story intelligence (8.3)

- The level and model shapes, the `_make(seed, tweak)` test helper, `_type(count)` and `_set_gap` are in `test_pitchfork_panic_level.gd`; reuse them.
- Review lessons from 8.3: use `assert_almost_eq` for floats mid-tween; keep scene header `load_steps` and ext_resource `uid`s right (resave in the editor or fix by hand); null-guard getters that read `_cfg`; a test must actually exercise what its name says (8.3's pause test had to really pause the tree).
- `-s` SceneTree capture scripts cannot see autoloads; use a throwaway scene for screenshots and delete it.
- Baseline after 8.3 review: **1926 passing / 102 scripts**.

### Git intelligence

- One commit per story ("Story 8.N: …, code review patches applied, done"); new scripts and tests commit with their `.uid` files.
- Recent commits: 8.1 content, 8.2 paragraph display and save v2, 8.3 the chase level. This story only touches the Pitchfork Panic folder, its config, the audio library and the named tests.

### Project Structure Notes

- New: `scripts/levels/pitchfork_panic/pickup_trail.gd`, `scripts/levels/pitchfork_panic/brain_pickup.gd`, `scenes/levels/pitchfork_panic/brain_pickup.tscn`, `tests/unit/test_pickup_trail.gd` (+ `test_brain_pickup.gd` if separate), their `.uid` files, `screenshots/8-4/`.
- Modified: `pitchfork_panic_config.gd`, `pitchfork_panic.tres`, `pitchfork_panic_level.gd`, `pitchfork_panic_level.tscn`, `audio_library.tres`, `test_pitchfork_panic_config.gd`, `test_pitchfork_panic_level.gd`, `test_audio_library.gd`, `test_run_frame.gd`, `deferred-work.md`, `sprint-status.yaml`.
- Untouched: `level_base.gd`, `run_frame.gd`, `hud.gd`, `chase_model.gd`, `audio_manager.gd`, `CREDITS.md`, `assets/`, Zombie Run and Horde Rush files, save schema.

### Project Context Rules

- No `project-context.md` exists. Rules come from `_bmad-output/game-architecture.md` and `epics.md` *Additional Requirements*: Godot 4.7.2, GDScript only, GUT 9.7.1; typed Resources and data under `res://data/`; `Log` with tags; audio only through `AudioManager`; exports exclude `tests/*` and `tools/*`.
- MCP: the `godot` server (`run_project`, `get_debug_output`) is available for the visual check; the headless CLI is the test path.

### Latest tech information

No new libraries. Godot 4.7.2 / GUT 9.7.1. APIs: `RandomNumberGenerator.randi_range` (inclusive), `.state`, `.seed`; `Node2D`, `AnimatedSprite2D`, `SpriteFrames`, `PackedScene.instantiate`, `queue_free`, `is_queued_for_deletion`; GUT `watch_signals`, `assert_signal_emit_count`, `get_signal_parameters`. No web research needed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.4: Brain Pickups on the Path], Epic 8 intro, FR14, FR72, NFR15
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Level 3: Pitchfork Panic ("Brain pickups"), Economy table, SFX set ("pickup")
- [Source: _bmad-output/game-architecture.md] ADR-1 level contract, "Logic Leads, Visuals Chase", `scripts/levels/pitchfork_panic/`
- [Source: _bmad-output/implementation-artifacts/8-3-chase-movement-mob-and-camera.md] Dev Notes, Review Findings, Completion Notes
- [Source: scripts/levels/zombie_run/zombie_run_level.gd] `play_sfx` seam, brains + signal in the key's call, child RNGs
- [Source: scripts/run/run_frame.gd:274, :423, :449] brain counter wiring, quit, result
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] ~287 (run RNG consumers), 669–690 (8.3 notes)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline before changes: 1926 passing / 102 scripts (matches Story 8.3 final).
- First level-test run: 1 failure. The "several pickups" test read `upcoming()[2]`, but only the 18-step lookahead is placed up front (one or two pickups). The test now types key by key until the third pickup is collected (bounded at 90 keys inside the first passage).
- Mutation check: with `_collect_pickups()` disabled, 4 level tests fail (first pickup, several pickups, RNG test's "collected pickups" guard, collected node). Code restored.
- Visual check: the first capture showed the `BrainPop` hidden behind the zombie (pickups draw behind it and the pop was added beside them). Fixed at Smuck's call (see Completion Notes).

### Completion Notes List

- Config: `pickup_min_steps`, `pickup_max_steps`, `brains_per_pickup` (neutral 0 defaults, FR72 docs) with three `validate()` checks; shipped 10 / 30 / 5.
- `PickupTrail` (pure `RefCounted`): `fill_to(step)` places pickups while the last position is below `step`, one inclusive `randi_range(min, max)` each; `collect(zombie_steps)` pops every reached pickup from the front; `upcoming()` returns a copy. Null RNG or bad numbers place nothing.
- `BrainPickup` node + scene: the two `brain_pop.png` frames (copied `SpriteFrames`), bottom centre `LIFT_PX = 2` above the ground line, `Log.warn` on missing frames. `collect(pop_parent = null)` instances `BrainPop` at the same screen spot under `pop_parent` (default: its own parent) and frees itself; a second call does nothing.
- Level: `play_sfx` seam (set in `_ready` unless pre-set), `SFX_PICKUP`, `PICKUP_LOOKAHEAD_MARGIN_STEPS = 2` (18 steps ahead with the shipped config). `create_target_source` keeps the paragraph child as the run RNG's first draw and seeds the pickup child from the second; the run RNG is not kept. `on_char_accepted`: guard → `_model.step()` → `_collect_pickups()` (brains, `brains_earned_changed`, one `play_sfx` per pickup, then node pops) → walk → `_fill_pickups()` → views. No `await`. `get_brains_earned()` returns the total; `get_pickup_trail()` added. `%Pickups` sits first under `%World`.
- Audio: `sfx_brain_pickup` cue on the existing bonk stream (`13_bonk`, -6 dB, no throttle); `CREDITS.md` unchanged.
- RunFrame integration: the 8.3 "no brains" check now asserts the HUD counter "0" one key before the first pickup and "5" on it; new caught-run and timer-run tests record `RunResult.brains == 5`, `bonus_brains == 0`, and the caught one checks the wallet grew by 5. Nothing else assumed Pitchfork pays 0.
- Economy (AC 6): over 10,000 pickups every gap 10–30 appears, mean 20 ±0.5; walking 10,000 steps pays 0.25 brains/char within 5%.
- Visual check (real window, throwaway scene under `tools/_scratch_8_4/` on the real `RunFrame`, tier 3 temp save under `user://scratch_8_4_saves`, never the real save; deleted afterwards). Seed 42: first pickup at step 29, captured entering from the right at 14 keys, collected at key 29 with the HUD at 5. Seed 58: pickups at 13 and 23, both on screen. Pickups sit on the ground line behind the zombie and clear of the HUD band.
- Smuck's layout verdict, round 1: "Pop in front of zombie". The pop is now added to `%World` (after `%Zombie`) so it rises in front while pickups stay behind; this departs from Task 3.2's "under its parent", which the zombie hid. Tests cover both (node test with another `pop_parent`, level test checks the pop's index is after the zombie). Round 2 (after the change): "Approved". Note: the round-2 screenshot failed to send before Smuck answered and was sent right after; the verdict was given on the description.
- Task 7.3: every new `.uid` file exists and is in the File List; nothing is committed yet. They go in the story's single commit after code review ("Story 8.4: …, done"), as with earlier stories.
- Final suite: **1954 passing / 104 scripts**, no parse/compile/load errors (+28 tests, +2 scripts).

### File List

New:
- `scripts/levels/pitchfork_panic/pickup_trail.gd` (+ `.uid`)
- `scripts/levels/pitchfork_panic/brain_pickup.gd` (+ `.uid`)
- `scenes/levels/pitchfork_panic/brain_pickup.tscn`
- `tests/unit/test_pickup_trail.gd` (+ `.uid`)
- `tests/unit/test_brain_pickup.gd` (+ `.uid`)
- `_bmad-output/implementation-artifacts/screenshots/8-4/` (pickup-a-start, pickup-a-entering, pickup-b-collected, pickup-b-zoom, pickup-c-seed58-start, pickup-c-seed58-two-on-screen, pickup-c-zoom)

Modified:
- `scripts/resources/pitchfork_panic_config.gd`
- `data/levels/pitchfork_panic.tres`
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd`
- `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`
- `data/audio/audio_library.tres`
- `tests/unit/test_pitchfork_panic_config.gd`
- `tests/unit/test_pitchfork_panic_level.gd`
- `tests/unit/test_audio_library.gd`
- `tests/integration/test_run_frame.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/8-4-brain-pickups-on-the-path.md`

Created and deleted (throwaway): `tools/_scratch_8_4/capture.gd`, `tools/_scratch_8_4/capture.tscn`

## Change Log

- 2026-10-13: Story 8.4 implemented. Distance-based brain pickups for Pitchfork Panic (config, `PickupTrail`, `BrainPickup`, level award + sound in the key's call, placeholder `sfx_brain_pickup` cue). Pop draws in front of the zombie at Smuck's visual gate. Tests 1954 passing / 104 scripts. Status → review.

### Review Findings

- [x] [Review][Patch] Unbounded pickup lookahead with a tiny `step_px` — resolved as: add a lower bound on `step_px` in `PitchforkPanicConfig.validate()` (at least 1.0, which caps the lookahead at about 258 steps) plus a config test. [pitchfork_panic_config.gd:55]
- [x] [Review][Patch] Old pickup nodes and pops linger on a re-create — `_clear_pickup_nodes()` only `queue_free()`s, so the nodes stay in `%Pickups` until end of frame, and any mid-rise `BrainPop` in `%World` is never cleared. Remove the children immediately and free any pops. [pitchfork_panic_level.gd:~276]
- [x] [Review][Patch] `test_several_pickups_emit_the_running_total_once_each` depends on the dealt passage being longer than 90 steps — it fails if the pool ever deals a shorter passage for seed 42. Guard on the passage length or pick a seed and passage explicitly. [tests/unit/test_pitchfork_panic_level.gd:~312]
- [x] [Review][Patch] `test_pitchfork_timer_run_keeps_the_pickup_brains` only asserts `end_reason != CAUGHT` — assert the reason is the timer end. [tests/integration/test_run_frame.gd]
- [x] [Review][Patch] `test_the_furthest_pickup_is_always_past_the_right_edge` hardcodes 256 and 16 and does not check the 2-step margin (the level places 18 steps ahead, the test checks 16). Read the constants and assert the real lookahead. [tests/unit/test_pitchfork_panic_level.gd]
- [x] [Review][Defer] Lookahead margin (2 steps) is not tied to the sprite's walk lag — at a high typing speed the sprite can trail the logical step by more than the margin, so a node could appear inside the view. Needs a visual check with 8.5/8.6. [pitchfork_panic_level.gd:PICKUP_LOOKAHEAD_MARGIN_STEPS] — deferred, design trade-off already accepted at the visual gate
