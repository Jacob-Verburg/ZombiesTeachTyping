---
baseline_commit: 8fcc2c30ecb842ae68c7b1dab581607ad05e205e
---

# Story 8.3: Chase Movement, Mob and Camera

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want every letter I type to move my zombie one step away from the mob,
so that typing faster really feels like escaping.

## Acceptance Criteria

1. **`pitchfork_panic` is a level, still "Coming soon" (FR74).** `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn` (root script `PitchforkPanicLevel extends LevelBase`) and `data/levels/pitchfork_panic.tres` (a `PitchforkPanicConfig`, which is a `LevelConfig`) exist. The registry entry `pitchfork_panic` gets its `scene` but keeps `available = false`, so the menu card still shows Coming soon. Starting it with `{"level_id": &"pitchfork_panic"}` (a new debug jump button, AC 9) starts a chase run.
2. **Config (FR70, FR71, NFR16).** `PitchforkPanicConfig` (`scripts/resources/pitchfork_panic_config.gd`) holds every chase number, with neutral defaults and a `validate() -> String` (empty = OK) like `HordeRushConfig`. `pitchfork_panic.tres` ships: `duration_s = 300.0`, `case_sensitive = true`, `space_is_input = true`, `target_mode = 2` (PARAGRAPH), `completion_bonus = 0` (8.5 sets the bonuses), `music_id = &""` (8.6), `paragraphs` = `paragraphs.json`, `tier_word_pools` = `word_pools.json`, and:
   - `start_gap_steps = 15.0`, `mob_start_wpm_eq = 4.0`, `mob_accel_wpm_eq = 1.0`, `mob_accel_every_s = 10.0` (GDD, FR70);
   - `step_px = 16.0`, `zombie_screen_x_frac = 0.6`, `mob_visible_gap_steps = 20.0` (FR71);
   - `step_time_s = 0.1` (look value: how long the sprite takes to walk one step).

   The constant `STEPS_PER_WPM_EQ_MIN = 5.0` (1 WPM-eq = 5 steps/min, GDD) lives in `ChaseModel`, not in the config. A broken config makes `create_target_source` return `null`, so RunFrame fails safely to the menu.
3. **One correct character = one step, in the same frame (FR70).** `on_char_accepted` raises the zombie's **logical** position (an int, `ChaseModel.zombie_steps`) by 1 before any visual. Every accepted key counts, including capitals, punctuation, digits and the passage-join Space. Wrong keys move nothing. The sprite chases through a short walk tween (`step_time_s`) and never gates input (ADR-1, "logic leads, visuals chase").
4. **Mob model (FR70).** `ChaseModel` (pure, `scripts/levels/pitchfork_panic/chase_model.gd`, `RefCounted`, no nodes and no RNG) gives:
   - `gap()` = `zombie_steps − mob_steps`, starting at `start_gap_steps` (15 steps);
   - `mob_wpm_eq(t)` = `mob_start_wpm_eq + mob_accel_wpm_eq × (t / mob_accel_every_s)`, i.e. 4 WPM-eq at run time 0 and **+1 WPM-eq every 10 s, continuously** (see Dev Notes);
   - the mob advances `mob_wpm_eq × STEPS_PER_WPM_EQ_MIN / 60` steps per second, integrated exactly over each `advance(dt)`;
   - `caught()` is true when `gap() <= 0`.
   
   Gap and mob use logical positions only, never sprite positions. The model advances **only** between `on_run_started()` and `on_run_ending()`, and only through `_process` (so the tree pause of PAUSED and COUNTDOWN freezes it). Time before the first key never counts.
5. **Closed-form checks (FR70).** With zombie speed fixed at `WPM × 5 / 60` steps/s and the shipped numbers, `ChaseModel` is caught at about **70.8 s at 5 WPM** and **144.8 s (2.4 min) at 10 WPM**, and is **not** caught by 300 s at **19 WPM** (about 311 s needed to be caught, so it escapes). Unit tests pin these with a tolerance of ±3 s. (The full typing sim with the real source is Story 8.7.)
6. **Camera (FR71).** The camera keeps the zombie sprite at `zombie_screen_x_frac` (60%) of the 640 px width, i.e. x = 384, every frame, with no Camera2D (same technique as Zombie Run: the level scrolls `%World`, because the HUD, pause panel and countdown share the canvas layer). `_set_zombie_x()` moves the zombie and the world in one call, and the backdrop scrolls from the same call. With `step_px = 16`, the mob is on screen for every `gap < mob_visible_gap_steps` (20): its screen x is `384 − gap × 16` ≥ 64. A test proves the mob view's screen rect lies fully inside 0–640 for gaps from 1 to 19.9 and is outside it for a gap of 30.
7. **The mob's distance is always readable (FR71).** While the mob is off screen (`gap ≥ mob_visible_gap_steps`), a `%MobGlow` strip on the left screen edge shows it is coming (a warm torch-orange gradient, alpha rising as the gap falls from 32 to 20 steps). The glow is hidden whenever the mob itself is visible. Look values only, final art in 8.6.
8. **Text and data flow (FR67–FR69, FR68).** The level deals paragraphs exactly as the Test text level does (AC 8 of Story 8.2): `ParagraphSource.for_level(child, config, tier, tier_config, used_passages)`, `_pool_label` from the source, nothing from the passage drawn in the playfield, `used_passages_changed` emitted in `on_run_started()` and on every `on_target_completed`. A level still never reads `PlayerData`. `LevelConfig.case_sensitive = true` and `space_is_input = true` give exact matching, so no new typing code is needed.
9. **Playable now (debug).** The F3 overlay gets a "Pitchfork" jump button (`JumpPitchforkButton`, mouse-only, `focus_mode = 0`) wired with `{"level_id": &"pitchfork_panic"}` and added to `_refresh_jumps`. Put it on `%JumpRow2` if `%JumpRow` no longer fits (check with a screenshot).
10. **Interim ending so runs always finish.** Until Story 8.5 builds the real endings, when `caught()` becomes true the level emits `end_requested(GameConstants.END_REASON_CAUGHT)` once and `on_run_ending` returns `0.0` (no outro). A run that reaches `duration_s` (300 s) still ends through RunFrame's timer, as a stand-in for "escaped" until 8.5. Neither ending is final art or final bonus, and Story 8.5 must replace both.
11. **No brains yet.** `get_brains_earned()` is 0 and no pickup exists (Story 8.4). The HUD brain counter stays at 0.
12. **Hidden tier (FR60).** Nothing this story adds (labels, logs, strings) names a tier number, average or WPM-eq to the kid. The run record's pool label is `"tier_n"` / `"all"`, as in 8.2.
13. **Nothing else regresses.** Zombie Run, Horde Rush, the Test text level, the menu (Pitchfork Panic still reads Coming soon), the save and every existing test keep working, with only the expectations named in the tasks changed. The full GUT suite is green with no parse errors.

## Tasks / Subtasks

- [x] **Task 1: `PitchforkPanicConfig` and `pitchfork_panic.tres`** (AC: 2)
  - [x] 1.1 Create `scripts/resources/pitchfork_panic_config.gd`: `class_name PitchforkPanicConfig extends LevelConfig`, `@export` fields for the AC 2 numbers with `##` docs (cite FR70/FR71) and neutral defaults (0 / 0.0). `validate() -> String`: `duration_s > 0`, `target_mode == PARAGRAPH`, `case_sensitive` and `space_is_input` true, `paragraphs != null`, `start_gap_steps > 0`, `mob_start_wpm_eq >= 0` and `mob_accel_wpm_eq >= 0` and not both 0, `mob_accel_every_s > 0`, `step_px > 0`, `0 < zombie_screen_x_frac < 1`, `mob_visible_gap_steps > 0`, `step_time_s >= 0`; every number must be finite. Mirror `HordeRushConfig.validate` for style.
  - [x] 1.2 Create `data/levels/pitchfork_panic.tres` with the shipped values from AC 2. Copy the header style of `horde_rush.tres` (ext_resources for the script, `paragraphs.json`, `word_pools.json`).
  - [x] 1.3 `tests/unit/test_pitchfork_panic_config.gd`: the shipped `.tres` validates and holds the AC 2 numbers; each bad number is rejected with its message (zero gap, `NAN`, `mob_accel_every_s = 0`, frac 1.0, wrong target mode, missing paragraphs).
- [x] **Task 2: `ChaseModel`, the pure chase logic** (AC: 3, 4, 5)
  - [x] 2.1 Create `scripts/levels/pitchfork_panic/chase_model.gd`: `class_name ChaseModel extends RefCounted`, `const STEPS_PER_WPM_EQ_MIN: float = 5.0`. `_init(config: PitchforkPanicConfig)`; a null or invalid config leaves a model that never moves and is never caught (the level refuses to start then, this is only a safety net).
  - [x] 2.2 State: `zombie_steps: int`, `mob_steps: float` (start `−start_gap_steps`, zombie 0), `elapsed_s: float`. API: `step() -> void` (zombie +1), `advance(dt: float) -> void`, `gap() -> float`, `mob_wpm_eq(t: float) -> float`, `caught() -> bool`.
  - [x] 2.3 `advance(dt)` ignores `dt <= 0` and non-finite values. It integrates the speed over `[elapsed, elapsed + dt]` **exactly**: with `s(t) = (start + accel × t / every) × 5 / 60`, the distance is `(start × 5/60) × dt + (accel × 5/60 / every) × ((t1² − t0²) / 2)`. Do not use `dt × speed(now)`, because that makes the result depend on frame rate. Stepping in many small `dt` values or one big one must agree to within 1e-6 steps.
  - [x] 2.4 `tests/unit/test_chase_model.gd`:
    - start values: gap 15, mob at −15, elapsed 0, not caught;
    - `step()` raises the gap by exactly 1;
    - `mob_wpm_eq` is 4 at 0 s, 5 at 10 s, 9 at 50 s (written-out oracles);
    - integration is frame-rate independent (1 × 10 s equals 600 × 1/60 s equals 3 × 3.333 s, ±1e-6);
    - hand-computed oracle: after 10 s with no typing the mob has moved `4×5/60×10 + (1×5/60/10)×50 = 3.3333 + 0.41667 = 3.75` steps (so gap 11.25);
    - bad `dt` (0, negative, `NAN`, `INF`) changes nothing;
    - **closed-form checks of AC 5**: drive the model with a zombie that steps at a fixed rate (5, 10 and 19 WPM → `WPM × 5 / 60` steps/s, using 1/60 s ticks and stepping when the accumulator reaches 1), find the time `caught()` first becomes true, and assert ≈ 70.8 ±3 s, ≈ 144.8 ±3 s, and not caught by 300 s at 19 WPM; also at 20 and 30 WPM;
    - a null config and an invalid config never move and are never caught.
- [x] **Task 3: `PitchforkPanicLevel` and its scene** (AC: 1, 3, 6, 7, 8, 10, 11)
  - [x] 3.1 Create `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` (`extends LevelBase`, with a class doc in the style of `zombie_run_level.gd` and `horde_rush_level.gd`). It reads its config through `config as PitchforkPanicConfig` (a null cast or a failed `validate()` logs one `Log.error(&"level", ...)` and makes `create_target_source` return `null`).
  - [x] 3.2 `create_target_source(rng)`: `child.seed = rng.randi()`, then `ParagraphSource.for_level(child, config, tier, tier_config, used_passages)` and set `_pool_label` exactly as `test_level.gd`'s paragraph branch does (read it first). Build the `ChaseModel` here. The run RNG is otherwise unused (no brains, no rolls), so a seed replays the same text.
  - [x] 3.3 `on_run_started()`: `_running = true`, emit `used_passages_changed(_paragraphs.get_used_ids())` (closes the 8.2 defer "quit before the first key re-deals the same passage": the first passage is saved at the same moment as in the Test text level), and start the zombie's walk state as `idle`.
  - [x] 3.4 `on_char_accepted(_expected, _index)`: `_model.step()` first (logic leads), then `_set_goal(zombie_steps × step_px)` (visuals chase). `on_target_completed(_target)` only re-emits `used_passages_changed`.
  - [x] 3.5 `_process(delta)`: do nothing unless `_running`. Cap a frame at `MAX_FRAME_S = 0.5` (a longer hitch is dropped, never a burst) and split it into equal steps of at most `MAX_STEP_S = 1/30`, as `HordeRushLevel` does; call `_model.advance(step)` per step, update the views once, and when `caught()` first turns true set `_running = false` and emit `end_requested(GameConstants.END_REASON_CAUGHT)` exactly once. Leave `process_mode` at its default so the tree pause freezes the level (never set `PROCESS_MODE_ALWAYS`).
  - [x] 3.6 `on_run_ending(_reason)`: `_running = false`, kill the walk tween where it is (the camera stays put), play the zombie idle, return `0.0`. `get_brains_earned()` returns 0.
  - [x] 3.7 Camera and views, as in Zombie Run:
    - the scene has `%Backdrop`, `%World` (holding `%Zombie`, an instance of `player_zombie.tscn`, and `%Mob`) and `%MobGlow`;
    - constants (placeholders where noted): `GROUND_Y = 192.0` (feet line, same as Zombie Run so the HUD band stays clear), `MOB_HALF_WIDTH_PX = 16.0` (the placeholder mob is one villager-size figure);
    - `_set_zombie_x(x)` moves `%Zombie.position.x = x`, sets `%World.position.x = zombie_screen_x − x` where `zombie_screen_x = config.zombie_screen_x_frac × 640`, and calls the backdrop's `scroll_to(x − zombie_screen_x)`, all in one call. The walk tween (a node-bound tween retargeted from the sprite's current x on every key) goes through it, and nothing else ever tweens the position;
    - `%Mob.position.x = mob_steps × step_px` (world coordinates, so it scrolls with `%World` and its screen x is `zombie_screen_x + (mob_steps × step_px − zombie_x)`). The zombie starts at world x 0 and the mob at −240;
    - walk animation: `play_walk()` while the sprite is behind its goal, `play_idle()` when it arrives, set from the tween, not polled each frame;
    - `%MobGlow`: a `ColorRect` (or gradient `TextureRect`) 48 px wide on the left edge above the HUD band (y 0–256), `mouse_filter = 2`, hidden when the mob's screen rect is on screen; otherwise alpha = `clampf((32 − gap) / 12, 0, 1) × 0.6` (values are look values, tune from the screenshot). It is read from the **logical** gap.
  - [x] 3.8 Placeholder art, replaced in 8.6: reuse `SunnyVillageBackdrop` and its layers for `%Backdrop` (same scene tree as `zombie_run_level.tscn`; copy that node block, do not edit the Zombie Run scene), and draw the mob as one placeholder figure from an existing villager frame (`assets/sprites/characters/villager/villager_wave.png`) tinted dark, with a small orange torch rectangle. Do not create new art files (8.6 owns the Moonlit Village, mob sprites and the music). Say so in the class doc.
  - [x] 3.9 `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn` with `config = pitchfork_panic.tres`, using unique names for the nodes above, `.uid` files committed.
  - [x] 3.10 `tests/unit/test_pitchfork_panic_level.gd` (use the instancing and `add_child_autofree` patterns from `test_horde_rush_level.gd` and `test_zombie_run_level.gd`, inject a seeded RNG like they do):
    - `create_target_source` gives a `ParagraphSource`; a broken config (`validate()` fails, or no paragraphs) gives `null` with an error and does not assert;
    - one correct key = `zombie_steps + 1` **before** `_process` runs (same call), capitals/punctuation/the join Space step too, and `on_char_rejected` does not;
    - `_process` before `on_run_started` never moves the mob; after it, the mob advances; after `on_run_ending` it is frozen;
    - the camera: after any number of keys and frames, `%Zombie` global x is exactly 384 (`zombie_screen_x_frac × 640`), including at the first frame and mid-tween, and the backdrop's ground offset equals `fposmod(roundf(x − 384), 640)`;
    - the mob's screen rect is inside 0–640 for gaps 1 to 19.9 and outside for a gap of 30; `%MobGlow` is hidden while the mob is on screen and visible with rising alpha when it is not;
    - caught: when the model is advanced to `gap <= 0`, `end_requested(&"caught")` fires exactly once (use `watch_signals`, then a second `_process` does not re-emit);
    - `used_passages_changed` fires in `on_run_started` and on each `on_target_completed`, and the emitted list contains the current passage id;
    - a large hitch (`_process(10.0)`) advances the mob by at most `MAX_FRAME_S` worth of time;
    - `process_mode` is `PROCESS_MODE_INHERIT`;
    - `get_brains_earned()` is 0 and `brains_earned_changed` is never emitted.
- [x] **Task 4: Registry, overlay and wiring** (AC: 1, 9, 13)
  - [x] 4.1 `data/levels/level_registry.tres`: add the ext_resource for the new scene and set `scene` on the `Resource_pitchfork_panic` entry (`available` stays `false`, `unlocked_by = &"horde_rush"` stays). Update `load_steps`.
  - [x] 4.2 `tests/unit/test_level_registry.gd` (lines ~140–142 assert Pitchfork Panic has no scene): change to "has its level scene (reachable from the debug jump; the card stays Coming soon until 8.7)", assert the root is a `LevelBase` like Horde Rush's check, and assert `available` is still false.
  - [x] 4.3 `scripts/debug/debug_overlay.gd` and `scenes/debug/debug_overlay.tscn`: add `JumpPitchforkButton` ("Pitchfork", `focus_mode = 0`), connect it as `_jump.bind(Router.Screen.RUN, {"level_id": &"pitchfork_panic"})`, add it to `_refresh_jumps`' list, and extend the class doc. Update `test_debug_overlay.gd` (a jump test like the Test text one). The button label is debug copy; check `test_plain_words.gd` still passes (debug-only buttons are skipped by how it scans).
  - [x] 4.4 `tests/integration/test_run_frame.gd` (use the injection pattern: temp-save `PlayerData`, recorder seams): start `pitchfork_panic` with a seed, type the first passage's characters through `%TypingInput`, and check: steps equal the typed count, the target is the paragraph (HUD line texts come from the source), the first passage id is saved to the injected `player_data` on the first key, a capital typed as lowercase is wrong and does not step, and a run caught by a model advanced past the gap ends with `END_REASON_CAUGHT` recorded in the result and no unlock for any level. Also: the HUD brain counter stays 0.
  - [x] 4.5 Check that the main menu card for `pitchfork_panic` is still Coming soon with the scene set (`test_main_menu.gd`, `test_level_unlocks.gd`, `test_level_card.gd` should pass unchanged; the menu shows Coming soon from `available`, not from a missing scene). Do not change them unless a test really depends on the scene being null, and then say so in the Completion Notes.
- [x] **Task 5: Visual check and wrap-up** (AC: 6, 7, 13)
  - [x] 5.1 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command. The baseline is **1890 passing / 99 scripts** (Story 8.2 final); re-run it first. Grep the log for `Parse Error|Compile Error|Failed to load script`. Record the new totals.
  - [x] 5.2 Visual check as in 8.2 Task 7.2 (a real window, a throwaway capture script under `tools/_scratch_8_3/` that is deleted afterwards, or the Godot MCP `run_project`). Run `pitchfork_panic` with a fixed seed and a tier 3 temp save (never the real save), and capture: (a) the start, zombie at x 384 and the mob at gap 15 (screen x 144); (b) after ~20 keys with the mob closing in; (c) the mob at the left edge (gap just under 20, then exactly at 20 with `%MobGlow`); (d) the gap at 3 steps. Confirm the zombie's feet stay on the same y and its x stays 384 in every frame. Save under `_bmad-output/implementation-artifacts/screenshots/8-3/chase-*.png`. The art is placeholder, so show Smuck the screenshots in chat only for the **layout and readability** of the gap (mob distance, camera, glow); record their verdict verbatim in Completion Notes. Real visuals are 8.6's gate.
  - [x] 5.3 Commit the new `.uid` files (the config, model, level, scene and their tests). List every new file in the File List.
  - [x] 5.4 `deferred-work.md`: mark the 8.2 defer "Quitting a paragraph level before the first correct key re-deals the same first passage" as handled for this level in 8.3 (the same emit point), and add a "Deferred from: dev of story 8-3" section with the *Known limitations* below that you confirm.
  - [x] 5.5 Mark sprint-status `8-3-chase-movement-mob-and-camera: review` (dev-story does this).

### Review Findings

- [x] [Review][Decision] Smuck's layout verdict is not recorded — Task 5.2 is ticked, but the Completion Notes say "pending". The screenshots in `screenshots/8-3/` need a verdict (approve / changes wanted), recorded verbatim. This is the story's visual gate. **Resolved:** Smuck: "approved" (recorded in Completion Notes).
- [x] [Review][Decision] A catch on the timer's last frame is recorded as `timer` — RunFrame (the parent) processes first and calls `_end_run(TIMER)`, so `on_run_ending` sets `_running = false` before the level's `_process` can see the catch. A run where the mob reaches the zombie in the 300 s frame is recorded as `timer`, which also triggers unlocks. Fix it now (it needs a RunFrame/level ordering change, and RunFrame is out of scope), or defer to 8.5, which rewrites both endings. **Resolved: patched.** The level sets `process_priority = PROCESS_PRIORITY` (-1) in `_ready`, so it processes before RunFrame (default 0) and a catch in the timer's frame ends the run as `caught`. RunFrame untouched. New integration test `test_pitchfork_catch_in_the_timers_last_frame_ends_as_caught`.
- [x] [Review][Patch] `get_zombie_screen_x()` dereferences `_cfg` without a null guard (`_ready` returns early on a missing config) [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:159]
- [x] [Review][Patch] Camera test compares float positions mid-tween with exact `assert_eq` — use `assert_almost_eq` [tests/unit/test_pitchfork_panic_level.gd:144]
- [x] [Review][Patch] `test_the_level_pauses_with_the_tree` only checks `process_mode` and never pauses a tree — assert that the level cannot process while the tree is paused [tests/unit/test_pitchfork_panic_level.gd:237]
- [x] [Review][Patch] Registry test dropped its `get_scene(&"pitchfork_panic")` check with no positive replacement — assert it returns the scene while `available = false` [tests/unit/test_level_registry.gd:140]
- [x] [Review][Patch] Integration test checks `get_used_passages()` only after 25 keys, not right after the first key (Task 4.4) [tests/integration/test_run_frame.gd]
- [x] [Review][Patch] `per_step_s` in `advance()` holds steps per second per WPM-eq, not seconds per step — rename it [scripts/levels/pitchfork_panic/chase_model.gd:47]
- [x] [Review][Patch] The deferred-work note says the sprite lag is at most one step (16 px), but restarting a 0.1 s tween from an unfinished x gives a steady lag of 16·(1−r)/r px, where r = key interval / 0.1 s (64 px at 50 keys/s). Correct the note [_bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Patch] Story record: the night-background outline-contrast limitation (Dev Notes → 8.6) is missing from the 8-3 deferred-work section (the "35 new tests" claim was checked against GUT and is correct) [_bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Patch] Scene header `load_steps=14`, but the scene has 12 resources (9 ext + 3 sub), and the script/config/zombie/villager ext_resources have no `uid` — resave in the editor or fix the header [scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn:1]
- [x] [Review][Defer] Mob is hidden at gaps 20–24 while it would still be on screen (it pops out at x 64 instead of walking off), as AC 6/7 specify [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:197] — deferred, spec-intended; revisit with 8.6 art
- [x] [Review][Defer] Mob sprite overlaps the zombie for gaps under 2 steps before the catch fires at gap 0 [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:195] — deferred, placeholder catch visuals (8.5/8.6)
- [x] [Review][Defer] `validate()` checks fields only one at a time: `mob_visible_gap_steps × step_px` beyond the left edge hides both mob and glow; `mob_visible_gap_steps ≥ GLOW_START_GAP_STEPS` makes the glow permanently transparent [scripts/resources/pitchfork_panic_config.gd] — deferred, shipped values safe; 8.7 tuning
- [x] [Review][Defer] `MAX_FRAME_S` clamp makes the mob's `elapsed_s` drift behind the run clock under sustained <2 FPS (the mob stays slower than tuned) [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:140] — deferred, spec-mandated hitch policy
- [x] [Review][Defer] `LevelRegistry.get_scene()` ignores `available`, so a Coming soon level with a scene can run from any payload; only the menu card guards it [scripts/resources/level_registry.gd:24] — deferred, pre-existing registry design
- [x] [Review][Defer] `ChaseModel` computes `_valid` once in `_init` but reads the config live in `advance()`; mutating the shared resource afterwards (e.g. `mob_accel_every_s = 0`) yields NaN and no catch [scripts/levels/pitchfork_panic/chase_model.gd:29] — deferred, hardening only

## Dev Notes

### What this story is (and isn't)

- **It is:**
  - the chase's logic as a pure model (`ChaseModel`) with tests against the GDD's numbers;
  - the level shell that runs it (`PitchforkPanicLevel`): logical steps, the mob's time-driven advance, the zombie sprite, the camera and the mob's visibility rules;
  - paragraphs flowing through the existing `ParagraphSource` and HUD from Story 8.2;
  - a debug jump to play it, and a registry scene so the jump can find it.
- **It isn't** pickups or brains (8.4), the caught and escaped endings, dust cloud, "Got you!", the dive, the +10/+25 bonuses (8.5), the Moonlit Village art, the mob sprites, chase music or the dust/pickup sounds (8.6), or tuning and making the card selectable (8.7: `available = true`). Keep `available = false`.
- **`TypingSession`, `TypingInput`, the HUD, `ParagraphSource` and `ParagraphLayout` need no change.** The level only reads `on_char_accepted`, `on_target_completed` and `on_run_started`. RunFrame already handles paragraph targets, the used-id round trip and `end_requested(&"caught")` (it accepts `caught` and `escaped`; `test_run_frame.gd` shows how to drive it).

### Step units, the mob and the numbers (don't re-derive)

- A **step** is one correct key. One step is `step_px = 16` px, half the 32 px zombie sprite. 15 steps = 240 px; 20 steps = 320 px.
- Screen layout at 640×360: the zombie sits at x 384 (60%). The mob's sprite is at `384 − gap × 16`. At gap 15 that is x 144. At gap 20 it is x 64, still fully on screen for a 32 px sprite (left edge at 48). At gap 24 it is at x 0 (half out). So `mob_visible_gap_steps = 20` is the largest gap the GDD allows ("visible whenever the gap is under 20 steps") and the layout meets it with room to spare. If you change `step_px`, redo this check: the mob's centre must be at least `MOB_HALF_WIDTH_PX` from the left edge at gap 19.9.
- **WPM-eq:** the GDD says 1 WPM-eq = 5 steps/min, so 4 WPM-eq = 20 steps/min = 0.333 steps/s, and the mob speeds up by 1 WPM-eq every 10 s. Implement it as **continuous** acceleration (+0.1 WPM-eq per second), not a jump every 10 s. Reason: it matches the GDD's resulting run lengths. Worked out with zombie speed `v` steps/s: the gap closes when `0.3333 t + 0.004167 t² = 15 + v t`.
  - 5 WPM (`v = 0.4167`): t ≈ 70.8 s (GDD ≈ 70 s) ✓
  - 10 WPM (`v = 0.8333`): t ≈ 144.8 s = 2.4 min (GDD ≈ 2.4 min) ✓
  - 19 WPM (`v = 1.5833`): t ≈ 311 s, past the 300 s cap, so it escapes (GDD ≈ 19+ WPM usually escapes) ✓
  
  A stepped version (jump at each 10 s mark) would give the same lengths within a few seconds, but the continuous one is smoother on screen and has a closed form, which the unit tests rely on.
- The mob's time is **run time**, not wall time: it starts at the first correct key (`on_run_started`) and freezes at the end. The zombie's step is instant, so the first key already raises the gap to 16.
- **Pause:** RunFrame pauses the tree (`pause_tree` seam) for PAUSED and COUNTDOWN. A level's `_process` stops with it, so the mob freezes for free. Do not set `process_mode = ALWAYS` on anything that moves the mob, and do not read `Time` or `RunClock` in the level (LevelBase rule). A hitch cap (0.5 s) drops time instead of paying a burst, as in Horde Rush: the mob can fall slightly behind real time after a long stall, which only helps the kid.
- **Catch check:** do it in `_process`, after `advance`. The zombie stepping can never catch the mob, so `on_char_accepted` does not need the check. Emit `end_requested` once. RunFrame honours it only while RUNNING and then calls `on_run_ending(&"caught")`. The first emit could race a key in the same frame (the session keeps judging that key after `on_run_ending`, an old deferred note), so a late step after catch must not crash or move the mob view. Guard `on_char_accepted` with `if not _running: return` after updating nothing, or at least make the post-end path harmless and test it.

### Existing code to read first

| File | Current state | This story |
|---|---|---|
| `scripts/levels/zombie_run/zombie_run_level.gd` (+ `.tscn`) | Camera without Camera2D: `_set_zombie_x` moves the zombie, `%World` and the backdrop in one call; node-bound scoot tween; zombie walk/idle | **Copy the pattern, don't edit.** Constants `GROUND_Y` and the HUD-band clearance come from here |
| `scripts/levels/zombie_run/sunny_village_backdrop.gd` | Four parallax layers, `scroll_to(camera_x)`, no process, wraps at 640 px | Reuse as the placeholder backdrop |
| `scripts/levels/horde_rush/horde_rush_level.gd` | Logic first then visuals; `_process` with `MAX_FRAME_S`/`MAX_STEP_S`; frozen on `on_run_ending`; pure field/defender classes with tests | Same shape for the chase loop and the pure `ChaseModel` |
| `scripts/levels/test_level/test_level.gd` | The paragraph branch: `ParagraphSource.for_level`, `_pool_label`, `used_passages_changed` at `on_run_started` and each completion | Copy the paragraph branch's behaviour |
| `scripts/run/level_base.gd` | `set_tier`, `set_used_passages`, `_pool_label`, contract rules, `end_requested` | **No change** |
| `scripts/run/run_frame.gd` | `_start_level` order; `end_requested` accepts timer/caught/escaped; `_next_target` for paragraph HUD | **No change** |
| `scripts/resources/horde_rush_config.gd`, `data/levels/horde_rush.tres` | A typed `LevelConfig` subclass with `validate()` and a `.tres` | Model the new config on them |
| `scripts/characters/player_zombie.gd`, `scenes/characters/player_zombie.tscn` | `play_walk()`, `play_idle()`, hat slot follows `PlayerData` by itself | Instance `%Zombie`; the level never touches `PlayerData` |
| `data/levels/level_registry.tres`, `scripts/resources/level_entry.gd`, `tests/unit/test_level_registry.gd` | Pitchfork entry has no scene, `available = false`; a test asserts the scene is null | Add the scene, flip that test |
| `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn` | Jump buttons on `%JumpRow`/`%JumpRow2`; `_refresh_jumps` list | Add "Pitchfork" |
| `scripts/screens/main_menu.gd` | A card is Coming soon from `entry.available`; it only logs a broken *available* entry without a scene | Unchanged; verify Coming soon still shows |

### What must keep working (regression guard)

- Zombie Run, Horde Rush and the Test text level behave exactly as before. Run `test_zombie_run_level.gd`, `test_horde_rush_level.gd`, `test_test_level.gd` and `test_run_frame.gd`.
- The menu: Pitchfork Panic stays "Coming soon" with the scene set. `test_main_menu.gd`, `test_level_card.gd` and `test_level_unlocks.gd` must pass.
- Unlocks: a caught or quit chase run opens nothing and the unlock rules (6.8, a finished run of the previous level opens the next) are untouched.
- Save: no new field and no schema change in this story. `used_passages` flows exactly as in 8.2.

### Known limitations (note in deferred-work; don't fix here)

- **Completion bonus:** `completion_bonus = 0` here. RunFrame still adds one bonus for every recorded end reason (an older deferred note, line ~329), and 8.5 must split it into +10 for any finished run and +25 more for Escaped!. Until then, a chase run earns nothing extra.
- **The 300 s ending is the timer's:** RunFrame ends a run at `duration_s` with reason `timer`, not `escaped`. 8.5 owns turning it into the Escaped! ending (set `duration_s` to 0 and let the level emit `escaped` at 300 s, or end it before the timer). A debug run that reaches 300 s therefore records `timer`.
- **Mob off screen above 24 steps:** past 20 steps the mob is out of view and only `%MobGlow` hints at it. Whether a fast typist needs a better cue (an arrow, a distance number) is a tuning/playtest call for 8.7.
- **Placeholder art:** the backdrop is Sunny Village Green and the mob is a dark villager frame. Real Moonlit Village and mob art, the dust cloud and music are 8.6. The night-background outline contrast note (deferred-work, line ~105) belongs to that story.
- **Caps Lock hint, AltGr and dead keys** (8.2 notes): still open for the Pitchfork playtest (8.7).

### Architecture and rules

- **Pipeline (ADR-1):** TypingInput → TypingSession → RunFrame → level. A level never reads input, the clock or `PlayerData`, and never calls the Router. Logic leads, visuals chase: anything read for gameplay (the gap, the catch) uses logical values, never sprite positions (architecture: "the Pitchfork Panic gap").
- **One RNG per run, a child RNG per source** (`child.seed = rng.randi()` in the level). No global `randi()`/`randf()`/`shuffle()`. The chase draws nothing from any RNG, so the seed fixes only the text.
- **GDScript:** static typing everywhere (`untyped_declaration = Error`, typed loop variables), tabs, `##` docs on classes and public functions, `snake_case` files, `PascalCase` classes, `UPPER_SNAKE` constants, StringName log tags (`&"level"`, `&"run"`). Content and config errors never `assert` (NFR16): log once and fall back.
- **Placement:** pure logic in `scripts/levels/pitchfork_panic/` (like `horde_rush/`), each with a `tests/unit/test_*.gd`. Data in `data/levels/`. The scene in `scenes/levels/pitchfork_panic/`. The config resource in `scripts/resources/`.
- **Same-frame rule (NFR2):** `on_char_accepted` must update the logical step and kick off the tween in the key's own call. No `await`, no deferred call and no timer in that path.
- **Never mutate shared resources:** read `config` (a `.tres` shared with the registry) but never write to it, and keep model state in `ChaseModel`.

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- To run one script: `-gdir=res://tests/unit -gselect=<name>`. `-gtest=` runs everything because `.gutconfig.json` sets `dirs`.
- GUT skips a script that fails to parse and still exits 0, so grep for `Parse Error|Compile Error|Failed to load script`.
- Assert loaded data is non-empty before looping (6.1). Use independent oracles: the hand-computed 3.75 steps in 10 s, the three closed-form catch times, and written-out screen x values (144, 64, 384). Never test the model against itself.
- Log errors: `assert_push_error_count(n)`.
- Tests never write the real save: inject a `PlayerData` on a temp `SaveService` (`test_run_frame.gd`, `test_player_data.gd` show how).
- Level tests should not rely on real time: call `_process(delta)` directly with fixed deltas, as the Horde Rush tests do.

### Previous story intelligence

- **8.2:**
  - `ParagraphSource.for_level(child, config, tier, tier_config, used)` is the factory for both the Test text level and this one; it returns `null` when even the fallback text is missing (RunFrame then fails safely).
  - The used list is saved at the first key (`on_run_started`) and at each completion; a quit before the first key saves nothing (8.2 review defer, closed here by using the same emit point).
  - The HUD's paragraph window is driven by RunFrame (`_next_target`); a level draws nothing from the passage (`%LetterLabel` is empty in the Test text level; Pitchfork has no such label at all).
  - Review lessons: stale state when a mode changes, vacuous tests over empty data, peeks that mutate (not relevant here). Baseline: 1890 passing / 99 scripts.
  - The visual gate for HUD changes was Smuck looking at screenshots; this story's gate is the same, for layout only.
- **7.5:** a level reads the tier only through `set_tier`; `_pool_label` is fixed when the source is built and the tier is never shown or logged (FR60).
- **6.4–6.7 (Horde Rush):** logic leads, visuals chase; `MAX_FRAME_S`/`MAX_STEP_S`; pure classes with their own tests; a headless sim for tuning (8.7 will want the same, so keep `ChaseModel` free of nodes).
- **Zombie Run (3.x):** the camera without Camera2D, the scoot tween, the one-call `_set_zombie_x`, and the parallax backdrop are all proven; reuse them rather than inventing a new camera.

### Git intelligence

- One commit per story ("Story 8.N: …, code review patches applied, done"). New scripts and tests commit with their `.uid` files.
- Recent history is Epic 7 (tiers) and 8.1/8.2 (paragraph content and display): mostly new pure classes in `scripts/typing/` plus integration through `run_frame.gd`, `hud.gd` and the test levels. This is the first story of Epic 8 that adds a real level, so mirror the structure of `scripts/levels/horde_rush/`.

### Project Structure Notes

- New:
  - `scripts/resources/pitchfork_panic_config.gd`;
  - `scripts/levels/pitchfork_panic/chase_model.gd`, `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd`;
  - `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`;
  - `data/levels/pitchfork_panic.tres`;
  - `tests/unit/test_pitchfork_panic_config.gd`, `tests/unit/test_chase_model.gd`, `tests/unit/test_pitchfork_panic_level.gd`;
  - screenshots under `screenshots/8-3/`;
  - `.uid` files.
- Modified:
  - `data/levels/level_registry.tres`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`;
  - tests: `test_level_registry.gd`, `test_debug_overlay.gd`, `test_run_frame.gd`;
  - `deferred-work.md`, `sprint-status.yaml`.
- Untouched: `level_base.gd`, `run_frame.gd`, `hud.gd`/`hud.tscn`, `typing_session.gd`, `typing_input.gd`, `paragraph_*.gd`, `save_schema.gd` (no new save field), `game_constants.gd` (the `caught`/`escaped` reasons already exist), `player_data.gd`, the Zombie Run and Horde Rush files, `export_presets.cfg`, `.github/`, `assets/` (no new art in this story).
- The chase numbers live in the config, not in constants, so 8.7 tunes them in `pitchfork_panic.tres` without touching code. The only code constants are layout and robustness values (`GROUND_Y`, `MAX_FRAME_S`, `MAX_STEP_S`, `MOB_HALF_WIDTH_PX`), each documented as "not a GDD number".

### Project Context Rules

- No `project-context.md` exists. The rules come from `_bmad-output/game-architecture.md` and `epics.md` *Additional Requirements*:
  - Godot 4.7.2, GDScript only, GUT 9.7.1;
  - typed Resources and data under `res://data/`;
  - `Log` with tags;
  - exports exclude `tests/*` and `tools/*` and include `data/content/*.json`.
- MCP: the `godot` server (`run_project`, `get_debug_output`) is available for the Task 5.2 visual check. Headless CLI is the test path.

### Latest tech information

No new libraries. The project is pinned to Godot 4.7.2 and GUT 9.7.1. APIs used: `Node2D`, `Tween` (node-bound via `create_tween`), `Sprite2D`/`AnimatedSprite2D` through `player_zombie.tscn`, `ColorRect`, `Resource` with `@export`, `clampf`, `fposmod`, `roundf`, and GUT's `watch_signals` / `assert_signal_emit_count`. No web research was needed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.3: Chase Movement, Mob and Camera], Epic 8 intro
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Level 3: Pitchfork Panic (movement model, start gap, WPM-eq, screen/camera), Adaptive Difficulty ("what never scales"), Economy table
- [Source: _bmad-output/game-architecture.md] ADR-1 level contract, "Logic Leads, Visuals Chase" (the gap uses logical values), end reasons, `scripts/levels/pitchfork_panic/` (Epic 8)
- [Source: _bmad-output/implementation-artifacts/8-2-paragraph-target-mode.md] Dev Notes, Review Findings (defers closed here), Completion Notes
- [Source: scripts/levels/zombie_run/zombie_run_level.gd] camera without Camera2D, scoot tween
- [Source: scripts/levels/horde_rush/horde_rush_level.gd] frame cap, pure logic classes, frozen end
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] lines ~105 (night outlines), ~170 (late `on_char_accepted` after `on_run_ending`), ~329 (completion bonus split), ~655–666 (8.2 notes)

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5.5 (claude-sonnet-5-5)

### Debug Log References

- Level test failure on first run: the mob's screen x read 160 instead of 144 right after a key, because the camera follows the sprite (mid-tween) while the mob follows the logical gap. Expected by design (logic leads, visuals chase); the test now finishes the walk tween first. Noted in deferred-work.
- A `-s` SceneTree capture script cannot see the autoloads; the visual check ran as a throwaway scene instead (deleted afterwards).

### Completion Notes List

- `PitchforkPanicConfig` + `pitchfork_panic.tres` (300 s, paragraph mode, GDD chase numbers), validated like `HordeRushConfig`.
- `ChaseModel` (pure): logical `zombie_steps`, exact closed-form integration of the continuous WPM-eq ramp (frame-rate independent to 1e-6), `caught()` at gap <= 0. Tests pin the 3.75-step oracle and the catch times: 5 WPM about 70.8 s, 10 WPM about 144.8 s, no catch by 300 s at 19, 20 and 30 WPM.
- `PitchforkPanicLevel`: one step per correct key in the key's own call, walk tween chases, camera without Camera2D (zombie at x 384 every frame, mid-tween included), mob in world coordinates, `%MobGlow` gradient strip when the mob is off screen (gap >= 20), frame cap 0.5 s split into steps of at most 1/30 s, interim `caught` end emitted once, no outro, brains 0, `used_passages_changed` at start and each completion.
- Registry now holds the scene (card still `available = false`, Coming soon). Debug overlay has a "Pitchfork" jump on `%JumpRow` (checked by screenshot: the row still fits, 440 of 448 px).
- Tests: 35 new (1925 passing / 102 scripts, baseline 1890 / 99). Changed expectations: the registry test (Pitchfork now has a scene), and the overlay tests (extra button). No menu/unlock test needed changing.
- Visual check (real window, tier 3 temp save, seed 42): zombie x = 384.0 in every capture, feet y unchanged; mob at screen x 128-160 at gap 15, fully on screen at gap 19.5, glow visible at gap 22 and 26, mob 3 steps behind. Screenshots in `_bmad-output/implementation-artifacts/screenshots/8-3/`. Smuck's layout verdict (code review, 2026-10-13): "approved".
- Deferred items recorded in `deferred-work.md` (8.2 first-passage defer handled here).

### File List

New:
- `scripts/resources/pitchfork_panic_config.gd` (+ `.uid`)
- `data/levels/pitchfork_panic.tres`
- `scripts/levels/pitchfork_panic/chase_model.gd` (+ `.uid`)
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` (+ `.uid`)
- `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`
- `tests/unit/test_pitchfork_panic_config.gd`, `tests/unit/test_chase_model.gd`, `tests/unit/test_pitchfork_panic_level.gd` (+ `.uid` files)
- `_bmad-output/implementation-artifacts/screenshots/8-3/` (chase-a-start, chase-b-20keys, chase-c-edge-19, chase-c-edge-20-glow, chase-c-glow-26, chase-d-gap3, overlay)

Modified:
- `data/levels/level_registry.tres`
- `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`
- `tests/unit/test_level_registry.gd`, `tests/unit/test_debug_overlay.gd`, `tests/integration/test_run_frame.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Change Log

- 2026-10-13: Story 8.3 implemented: chase model, config, level, camera, mob glow, debug jump, tests.

- 2026-10-13: Code review (Blind Hunter, Edge Case Hunter, Acceptance Auditor). Layout verdict recorded ("approved"). Timer/catch tie fixed (level `process_priority = -1`). 9 patches applied (null guard, float asserts, real pause test, registry `get_scene` check, first-key save check, rename, scene header UIDs, deferred-work corrections). 6 items deferred. Tests 1926 passing / 102 scripts. Status → done.
