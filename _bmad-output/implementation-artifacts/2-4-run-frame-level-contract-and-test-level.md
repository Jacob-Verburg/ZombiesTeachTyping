---
baseline_commit: beb485e90d77a67b05ce3efe26db9edac23143af
---

# Story 2.4: Run Frame, Level Contract and Test Level

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want a run that waits for my first letter, then times me and ends cleanly,
so that I never lose time before I'm ready.

## Acceptance Criteria

1. **Level contract.** Given `LevelBase` (`scripts/run/level_base.gd`, `class_name LevelBase extends Node2D`) with the architecture's contract: `signal end_requested(reason: StringName)`, `signal brains_earned_changed(total: int)`, `get_level_config() -> LevelConfig`, `create_target_source(rng: RandomNumberGenerator) -> TargetSource`, `on_run_started()`, `on_char_accepted(expected: String, index: int)`, `on_char_rejected(expected: String, typed: String)`, `on_target_completed(target: String)`, `on_run_ending(reason: StringName) -> float`, `get_brains_earned() -> int`, when it is inspected, then every method exists with those exact signatures and a safe default (no-op / `0` / `0.0`), `get_level_config()` returns an `@export var config: LevelConfig`, and the base `create_target_source` is a contract violation (`assert` + `Log.error`, returns `null`).
2. **Level registry.** Given `LevelRegistry` (`scripts/resources/level_registry.gd`) and `data/levels/level_registry.tres`, when a `level_id` is looked up, then the registered `PackedScene` is returned, and an unknown id returns `null` (no crash). The registry holds `&"test_level"` marked debug-only (not for the real menu).
3. **Run start.** Given `RunFrame` starts with a `RUN` payload `{ "level_id": ... }` (optional `"seed": int`), when it enters the tree, then it instances the level from the registry under `%LevelHost`, creates **one** `RandomNumberGenerator` for the run (seeded from the payload's `seed` when present and `>= 0`, otherwise from a fresh random seed that is stored so the run can be replayed), builds `TypingSession.new(level.create_target_source(rng), level.get_level_config())`, calls `%TypingInput.configure(config)`, and connects every signal in code.
4. **Failed level load.** Given a payload with a missing or unknown `level_id`, a scene that is not a `LevelBase`, a level with no `LevelConfig`, or a `null` target source, when `RunFrame` starts, then it logs `Log.error(&"run", ...)`, builds no session, and returns to the main menu (NFR16), waiting for the Router's current transition to finish so the request is not dropped.
5. **Key capture.** Given `RunFrame` enters the tree, then `WebPlatform.capture_keys` is `true`, and `_exit_tree()` sets it back to `false` (report card, quit to menu, failed load) (architecture `capture_keys` lifecycle).
6. **Waiting for the first key.** Given the run is in `WAITING_FIRST_KEY` when the scene loads, then the first target is shown by the level and the clock stays at `0.0` however much time passes; a wrong key counts as an error and does **not** start the run; the first correct key moves the state to `RUNNING` and starts `RunClock`, which accumulates `delta` only while running (FR6).
7. **Same-frame reaction.** Given a `RUNNING` run, when a correct key arrives, then the level's `on_char_accepted` has already run when `TypingInput.handle_key()` returns, with no `await` and no deferred call anywhere in the typing path (FR1, NFR2); a wrong key reaches `on_char_rejected` the same way.
8. **Run end.** Given the clock reaches the level's `duration_s` or the level emits `end_requested(reason)` while `RUNNING`, when the run ends, then the state becomes `ENDING`, typing is rejected (no judgment, no counter change), the frame waits the outro seconds returned by `on_run_ending(reason)`, then enters `DONE`, builds exactly one `RunResult` (timer ends use `duration_s` clamped to the level duration) and calls `Router.go(REPORT_CARD, { "result": result })` once.
9. **Test level.** Given `test_level` (`scenes/levels/test_level/test_level.tscn` + `scripts/levels/test_level/test_level.gd`, a `LevelBase` with `data/levels/test_level.tres`: 120 s, lowercase, Space ignored, letter mode) that shows the current letter from a `LetterBagSource` over all 26 lowercase letters, when "Test level" is chosen on the placeholder main menu (a button that exists only in debug builds), then a full 2:00 run can be typed from start to end and lands on the placeholder report card, which shows the result's stats; and the test level emits `brains_earned_changed` with its new total (+1) on every 4th correct key.
10. **Integration tests.** Given `tests/integration/test_run_frame.gd`, when GUT runs with a fixed seed and synthetic `InputEventKey`s, then state transitions, the clock starting on the first correct key (not on load, not on a wrong key), timer end, `end_requested` end, input rejection while ending, one `RunResult` handed to the Router, seed replay, the failed-load fallback, and `capture_keys` true during the run and false after it are covered and pass; unit tests cover `RunClock`, `LevelBase` defaults, `LevelRegistry` and the test level; the full suite has no regressions (297 tests at the 2.3 finish; confirm the count in the first run).

## Tasks / Subtasks

- [x] **Task 1: `RunClock` (AC: 6, 8)**
  - [x] 1.1 Create `scripts/run/run_clock.gd`: `class_name RunClock extends RefCounted`, `##` doc: the run's stopwatch; accumulates only the deltas it is given while running, never reads wall time, so pause is exact (architecture State Management). Pure: no nodes, no autoloads.
  - [x] 1.2 API: `func start() -> void` (running from 0; used on the first correct key), `func pause() -> void`, `func resume() -> void`, `func advance(delta: float) -> void` (adds `delta` only while running; ignores negative or non-finite `delta`), `func get_elapsed() -> float`, `func is_running() -> bool`. `start()` on an already-started clock does nothing (no reset mid-run). A `RefCounted`, not a `Node`: `RunFrame._process` feeds it, which keeps tests deterministic (call `advance` / `_process` with a chosen delta).
  - [x] 1.3 `tests/unit/test_run_clock.gd`: stopped clock ignores `advance`; `start` then `advance(0.5)` twice → `1.0`; `pause` freezes; `resume` continues; second `start()` keeps the time; negative/`INF`/`NAN` delta ignored; exact sums with chosen deltas (`assert_almost_eq` for sums of 1/60).

- [x] **Task 2: `LevelBase` and `LevelRegistry` (AC: 1, 2)**
  - [x] 2.1 Create `scripts/run/level_base.gd`: `class_name LevelBase extends Node2D`, with the exact contract from AC 1, each member `##`-documented with **who calls it and when** (see Dev Notes "Call order"). Defaults: callbacks `pass`; `on_run_ending` returns `0.0`; `get_brains_earned` returns `0`; `get_level_config` returns `config`. Base `create_target_source`: `assert(false, ...)` + `Log.error(&"level", "... does not override create_target_source")` + `return null` (never called in tests; covered by review).
  - [x] 2.2 Contract rules in the class doc: levels never read input, never touch the clock, never write `PlayerData`, never call `Router` (ADR-1, architecture "Rules"); `create_target_source` must give the source **its own** `RandomNumberGenerator` seeded from the run RNG (`child.seed = rng.randi()`), and the level may keep the run `rng` for its own draws (fixes the 2.2 RNG-sharing deferral: the lazily-dealing bag then never interleaves with level draws, so seed replay holds). `on_target_completed` is never called until Epic 6 adds `TypingSession.target_completed` (2.2 deferral).
  - [x] 2.3 Create `scripts/resources/level_entry.gd`: `class_name LevelEntry extends Resource` with `@export var id: StringName`, `@export var scene: PackedScene`, `@export var debug_only: bool = false` (`##` docs: debug-only levels never appear on the real menu; card art, `available` and `unlocked_by` arrive with Story 4.2 / 6.8, do not add them now).
  - [x] 2.4 Create `scripts/resources/level_registry.gd`: `class_name LevelRegistry extends Resource`, `@export var entries: Array[LevelEntry] = []`, `func get_entry(id: StringName) -> LevelEntry` (null if unknown or the entry's id is empty), `func get_scene(id: StringName) -> PackedScene` (null if unknown or `scene` is null). Duplicate ids: first wins, `Log.warn(&"level", ...)` once per lookup is unnecessary noise; instead a unit test asserts the shipped `.tres` has unique ids.
  - [x] 2.5 Create `data/levels/level_registry.tres` with one `LevelEntry` (sub-resource) `id = &"test_level"`, `scene = test_level.tscn`, `debug_only = true`. Zombie Run is **not** registered (Story 3.1 adds it with its scene).
  - [x] 2.6 `tests/unit/test_level_base.gd`: a bare `LevelBase.new()` (freed with `autofree`) returns `config` from `get_level_config()`, `0.0` from `on_run_ending(&"timer")`, `0` from `get_brains_earned()`; the callbacks run without error; both signals exist (`has_signal`). Do not call the base `create_target_source` (debug `assert`).
  - [x] 2.7 `tests/unit/test_level_registry.gd`: in-memory registry built in the test (two entries) → `get_scene` returns the right scene, unknown id → `null`, entry with null scene → `null`; the shipped `data/levels/level_registry.tres` loads as a `LevelRegistry`, has unique ids, contains `&"test_level"` with `debug_only == true`, and its scene instantiates to a `LevelBase`.

- [x] **Task 3: `TypingInput` active gate (AC: 8; 2.1 deferral)**
  - [x] 3.1 In `scripts/typing/typing_input.gd` add `var active: bool = true` (`##`: when false, `handle_key` emits nothing and returns false, so `_unhandled_input` no longer marks keys handled; `RunFrame` turns it off when the run ends). Check it first in `handle_key`. Default `true` keeps every 2.1 test and behaviour unchanged.
  - [x] 3.2 Add one test to `tests/unit/test_typing_input.gd`: `active = false` → `a` emits nothing and returns false; back to `true` → emits `"a"`. Do not change any existing test.
  - [x] 3.3 Do **not** touch the Caps Lock reset on focus loss / pause (2.7 deferral) or anything else in this file.

- [x] **Task 4: `RunFrame` (AC: 3–8)**
  - [x] 4.1 Replace the placeholder `scripts/run/run_frame.gd` and `scenes/run/run_frame.tscn` (Story 1.3; the header says "Story 2.4 replaces it"). New scene: root `RunFrame` (`Control`, full rect, keep the night `Background` ColorRect with `mouse_filter = IGNORE`), children `%LevelHost` (`Node2D`) and `%TypingInput` (`Node` with `typing_input.gd`). **No buttons** in this story (the pause button arrives in 2.5/2.7 and must be `FOCUS_NONE`, 2.1 deferral). Remove `%PayloadLabel`, `%FinishButton`, `%QuitButton`.
  - [x] 4.2 Script header: `extends Control` (no `class_name` needed; keep it like the other screens), `##` doc: owns the run lifecycle (state machine), `RunClock`, `TypingSession` and the level instance; HUD (2.5), hands (2.6), pause/countdown (2.7), `PlayerData.record_run` (2.8) and debug overlay fields (2.10) attach here later.
  - [x] 4.3 `enum RunState { WAITING_FIRST_KEY, RUNNING, PAUSED, COUNTDOWN, ENDING, DONE }` (full architecture enum now; `PAUSED`/`COUNTDOWN` are unused until 2.7). `var _state: RunState = RunState.WAITING_FIRST_KEY`. **Every** transition goes through `_set_state(new_state)`: returns if unchanged, `Log.debug(&"run", "state %s -> %s" % [...])`, then enter logic in a `match` (`RUNNING`: `_clock.start()` the first time / `resume()` later; `ENDING`: `_clock.pause()`, `%TypingInput.active = false`, ask the level for its outro; `DONE`: build and send the result). Never assign `_state` anywhere else.
  - [x] 4.4 Exports and seams: `@export var level_registry: LevelRegistry` (set to `data/levels/level_registry.tres` in `run_frame.tscn`; no hard-coded data path in the script, architecture Data Patterns). `## Test seam` `var navigate: Callable` (called as `navigate.call(screen, payload)`); in `_ready`, if it is not valid, use `Router.go`. Tests and `test_screen_flow.gd` assign a recorder **before** `add_child`, so no test ever swaps GUT's scene.
  - [x] 4.5 `_ready()` order: `WebPlatform.capture_keys = true` (first, so even a failed load resets it in `_exit_tree`) → `var payload := Router.take_payload()` → resolve `level_id` (must be a `StringName` or `String`; convert to `StringName`) → `level_registry.get_scene(id)` → instantiate, cast `as LevelBase` (if null: free the instance, fail) → check `get_level_config()` non-null → `%LevelHost.add_child(level)` → create RNG and seed (Task 4.6) → `source := level.create_target_source(_rng)` (null → fail) → `_session = TypingSession.new(source, config)` → `%TypingInput.configure(config)` → connect signals (Task 4.7) → `Log.info(&"run", "started level=%s seed=%d" % [id, _seed])`. Any failure → `_fail_to_menu(reason)` (Task 4.10) and return.
  - [x] 4.6 RNG: `_rng = RandomNumberGenerator.new()`. `var requested: int = int(payload.get("seed", -1))` (accept `int` only; anything else → `-1`). If `requested >= 0`, `_seed = requested`; else make a seed with a throwaway `RandomNumberGenerator` (`randomize()` then `randi()`), so the seed is always a known number. `_rng.seed = _seed`. Expose `get_seed() -> int` (2.10 overlay shows it; `-1` meaning "random" is the payload convention, architecture Debug Tools). One RNG per run; never call global `randi()`/`randf()`.
  - [x] 4.7 Signal wiring, all in code, all synchronous (architecture Communication example): `%TypingInput.char_typed` → `_on_typing_input_char_typed(c)`; `_session.run_started` → `_on_session_run_started` (sets `RUNNING`, then calls `_level.on_run_started()`); `_session.char_accepted` → `_level.on_char_accepted`; `_session.char_rejected` → `_level.on_char_rejected`; `_level.end_requested` → `_on_level_end_requested(reason)`. Do **not** connect `brains_earned_changed` yet (the HUD counter is 2.5; the result reads `get_brains_earned()` at the end). Do **not** connect `target_changed` (HUD/hands, 2.5/2.6). No `CONNECT_DEFERRED` anywhere.
  - [x] 4.8 `_on_typing_input_char_typed(c)`: only in `WAITING_FIRST_KEY` or `RUNNING` → `_session.judge(c)`; otherwise ignore. Order inside one key: `judge` emits `run_started` (→ `RUNNING`, clock starts at 0) before `char_accepted` (→ level), so the level sees a running run. No handler calls `judge` again (re-entrancy deferral from 2.2 stays safe; note it in the Debug Log).
  - [x] 4.9 `_process(delta)`: `RUNNING` → `_clock.advance(delta)`; if `_duration > 0.0` and `_clock.get_elapsed() >= _duration` → `_end_run(GameConstants.END_REASON_TIMER)`. `ENDING` → `_outro_left -= delta`; when `<= 0.0` → `_set_state(DONE)`. No logging in `_process`. A `duration_s <= 0` config means "no timer" (the level must end itself with `end_requested`); document it. `_on_level_end_requested(reason)`: only while `RUNNING` (log at DEBUG and ignore otherwise) → `_end_run(reason)`.
  - [x] 4.10 `_end_run(reason)`: store `_end_reason`, `_set_state(ENDING)`; the enter logic calls `_outro_left = maxf(0.0, _level.on_run_ending(reason))` (a non-finite value → `0.0`). An outro of `0.0` still goes through `ENDING` and reaches `DONE` on the next `_process`. `DONE` enter: `_send_result()` exactly once (guard with the state machine; never a second `navigate`).
  - [x] 4.11 `_send_result()`: `duration := _clock.get_elapsed()`; for `END_REASON_TIMER` clamp with `minf(duration, _duration)` (2.3 deferral: last-frame overshoot). `RunResult.create(_level_id, int(Time.get_unix_time_from_system()), duration, _session.get_keys_typed(), _session.get_errors(), _session.get_per_key(), _level.get_brains_earned(), 0, LETTER_POOL_ALL, _end_reason)`. Bonus is `0` here: the completion bonus and its `LevelConfig` field arrive in Story 3.5. `const LETTER_POOL_ALL: String = "all"` (MVP value; Epic 7 replaces it with the tier). Then `Log.info(&"run", "ended level=%s reason=%s wpm=%d" % [result.level_id, result.end_reason, result.wpm])` and `navigate.call(Router.Screen.REPORT_CARD, {"result": result})`. **No** `PlayerData` call (brains are committed by `record_run` in 2.8).
  - [x] 4.12 `_fail_to_menu(reason: String)`: `Log.error(&"run", "cannot start run: %s" % reason)`; free any half-built level; then go to `MAIN_MENU`. `RunFrame._ready()` runs **inside** `Router.go()` (the Router is still `_transitioning` and ignores a new `go()`), so: if `navigate` is the real `Router.go` and `Router.is_transitioning()`, connect `Router.screen_changed` with `CONNECT_ONE_SHOT` to a small handler that calls `navigate.call(Router.Screen.MAIN_MENU, {})`; otherwise call it immediately (tests). Keep the state `WAITING_FIRST_KEY` with `%TypingInput.active = false` so nothing is judged.
  - [x] 4.13 `_exit_tree()`: `WebPlatform.capture_keys = false`. Nothing else.
  - [x] 4.14 Read-only getters for tests and the 2.10 overlay, `##`-documented: `get_state() -> RunState`, `get_elapsed() -> float`, `get_seed() -> int`, `get_session() -> TypingSession` (null after a failed load), `get_level() -> LevelBase`.
  - [x] 4.15 House rules in this file: no `await` anywhere in `run_frame.gd` (the fallback uses a one-shot connection, not `await`); no global RNG; no `get_node("/root/...")`; autoload use limited to `Router`, `WebPlatform`, `Log`; no per-key logging.

- [x] **Task 5: Test level (AC: 9)**
  - [x] 5.1 `data/levels/test_level.tres`: `LevelConfig` with `duration_s = 120.0`, `case_sensitive = false`, `space_is_input = false`, `target_mode = LETTER` (same values as `tests/fixtures/levels/level_config_lowercase.tres`, but a separate game-data file).
  - [x] 5.2 `scripts/levels/test_level/test_level.gd`: `extends LevelBase` (no `class_name`; it is a dev level), `##` doc: debug-only level that proves the run frame and level contract; shows the current letter; Zombie Run (3.1) is the real level. Constants: `const BRAIN_EVERY: int = 4` (`##` test-level demo rule, not a GDD number) and `const OUTRO_S: float = 0.5` (a short visible pause before the report card; also exercises the outro wait). `static func alphabet() -> Array[String]` builds `a`..`z` (typed array, appended in a loop).
  - [x] 5.3 `create_target_source(rng)`: `var child := RandomNumberGenerator.new()`, `child.seed = rng.randi()`, `_source = LetterBagSource.new(child, alphabet())`, show `_source.current()`, return `_source`. Keep the reference so the level can read the next letter: in `on_char_accepted`, the source has already advanced (2.2 emit order), so `_source.current()` is the new target.
  - [x] 5.4 `on_char_accepted(_expected, index)`: update the letter label to `_source.current()`; if `(index + 1) % BRAIN_EVERY == 0` → `_brains += 1`, `brains_earned_changed.emit(_brains)`. `get_brains_earned()` returns `_brains`. `on_run_ending` returns `OUTRO_S` and shows a short "Time!" text. No input reading, no clock, no `PlayerData`, no `Router`.
  - [x] 5.5 `scenes/levels/test_level/test_level.tscn`: root `TestLevel` (`Node2D`, script above, `config` = `test_level.tres`), a `%LetterLabel` (`Label`, centred in the 640×360 playfield above the future 104 px HUD band, font size ≥ 32 px, palette colour `#F4F1E4`-ish chalk as used by the placeholders) and a `%StatusLabel` (16 px, shows `"Brains: N"` and `"Time!"`). Use the shared theme font if the other scenes do; no new art.
  - [x] 5.6 `tests/unit/test_test_level.gd`: instance the scene (autofree), seed an RNG, call `create_target_source`, assert the label shows `source.current()`; simulate `on_char_accepted` for indexes 0..7 (advancing the source each time, as the session would) and assert `brains_earned_changed` fires exactly at indexes 3 and 7 with totals 1 and 2 (`watch_signals`, `assert_signal_emit_count`, `get_signal_parameters`); `get_brains_earned() == 2`; `on_run_ending` returns `OUTRO_S`; two levels given RNGs with the same seed show the same first 10 letters.

- [x] **Task 6: Placeholder screens (AC: 9)**
  - [x] 6.1 `scripts/screens/main_menu.gd` + `scenes/screens/main_menu.tscn`: add `%TestLevelButton` ("Test level") after `%PlayButton`, `visible` only when `_is_debug_build()` returns true (a one-line seam returning `OS.is_debug_build()`, same pattern as `Router._is_debug_build()`); pressing it calls `Router.go(Router.Screen.RUN, {"level_id": &"test_level"})`. Keep everything else (storage notice, export chord, focus on Play). `%PlayButton` keeps sending `&"zombie_run"`: until Story 3.1 registers it, RunFrame logs the error and comes back to the menu (that is the NFR16 path, working on purpose; say so in the header comment).
  - [x] 6.2 `scripts/screens/report_card.gd` (placeholder, Story 2.9 builds the real one): if the payload's `"result"` is a `RunResult`, `%PayloadLabel` shows plain lines `Keys Typed`, `Errors`, `WPM`, `Accuracy` (`%d%%`), `Lesson Time` (`lesson_time()`), `Brains` (`total_brains()`) instead of `str(payload)`; `%PlayAgainButton` replays `result.level_id` (fallback `&"zombie_run"` when there is no result). No other change; no `PlayerData` call.
  - [x] 6.3 Update `tests/integration/test_screen_flow.gd` (regression trap): `RUN` no longer has buttons, so drop its `FLOW_BUTTONS` entry and add `"%TestLevelButton"` to `MAIN_MENU`; in `_instance()`, when the screen is `RUN`, assign a recorder to `navigate` **before** `add_child` (an empty payload makes RunFrame fall back to the menu, and the real `Router.go` would swap GUT's scene); replace `test_run_shows_level_id_payload_and_consumes_it` with a test that stores `{"level_id": &"test_level", "seed": 1}`, instances RUN, and asserts the payload was consumed and a session exists; add a test that an empty RUN payload records one `MAIN_MENU` navigation and logs the error (`assert_push_error("[ERROR][run]")`).
  - [x] 6.4 `tests/unit/test_main_menu.gd`: `%TestLevelButton` exists, its text is "Test level", and it is visible in the (debug) test run; add a release-build case by overriding the `_is_debug_build()` seam before `add_child` (e.g. a tiny inner subclass of the menu script, or a script-level flag) and asserting the button is hidden. Placeholder report card: a small test (new `tests/unit/test_report_card_placeholder.gd` or a section in `test_screen_flow.gd`) that a stored `{"result": RunResult.create(...)}` payload shows `WPM` and the lesson time in `%PayloadLabel`. Instances stay `PROCESS_MODE_DISABLED` and buttons are never pressed (they would call the live Router).

- [x] **Task 7: Integration test `tests/integration/test_run_frame.gd` (AC: 3–8, 10)**
  - [x] 7.1 Helper `_start(payload: Dictionary) -> Control`: `Router._store_payload(payload)`, instantiate `run_frame.tscn`, set `process_mode = PROCESS_MODE_DISABLED` (no engine `_process`, no real keyboard input; tests drive `_process(delta)` and `%TypingInput.handle_key(event)` by hand), assign `navigate` to a lambda appending `[screen, payload]` to `_nav: Array`, `add_child_autofree`. `after_each`: `Router.take_payload()`. `before_each`/`after_all`: `assert_false(WebPlatform.capture_keys)` (same guard as `test_screen_flow.gd`).
  - [x] 7.2 Helper `_key(c: String) -> InputEventKey` (`pressed = true`, `unicode = c.unicode_at(0)`, `keycode` from `OS.find_keycode_from_string(c.to_upper())` or left `KEY_NONE`; check `TypingInput.handle_key` accepts it, as `test_typing_input.gd` builds them) and `_type_correct(frame)` which reads `frame.get_session().get_current_target()` and sends it; `_type_wrong(frame)` sends a letter that differs from the current target.
  - [x] 7.3 Cases (exact assertions):
    - start: state `WAITING_FIRST_KEY`, a level instance under `%LevelHost`, session non-null, `capture_keys == true`, `get_seed() == 42` for payload seed 42;
    - waiting: `_process(5.0)` → elapsed `0.0`; a wrong key → `errors == 1`, still `WAITING_FIRST_KEY`, elapsed still `0.0`;
    - first correct key → `RUNNING`, elapsed `0.0` right after; `_process(0.5)` → `0.5`;
    - same frame: right after `handle_key` returns, the test level's `%LetterLabel` already shows the new `get_current_target()` (proves `on_char_accepted` ran synchronously);
    - 4th correct key → `get_level().get_brains_earned() == 1`;
    - timer end: `_process(200.0)` → `ENDING`; keys typed now change nothing (`keys_typed`/`errors` unchanged, `handle_key` returns false because the gate is off); `_process(0.4)` → still `ENDING` (outro 0.5 s); `_process(0.2)` → `DONE`; `_nav.size() == 1`, `_nav[0][0] == Router.Screen.REPORT_CARD`, `_nav[0][1]["result"]` is a `RunResult` with `level_id == &"test_level"`, `end_reason == &"timer"`, `duration_s == 120.0` (clamped, not 200.5), `keys_typed`/`errors` matching what was typed, `brains` matching the level; more `_process` calls never navigate again;
    - `end_requested`: emit `get_level().end_requested.emit(&"caught")` while `RUNNING` → `ENDING` → `DONE` with `end_reason == &"caught"` and `duration_s` equal to the unclamped elapsed; the same emit while `WAITING_FIRST_KEY` is ignored;
    - seed replay: two frames with seed 7 show the same first 20 targets (type correct keys and record `get_current_target()`); seed 8 differs;
    - no seed: `get_seed() >= 0`; seed `"abc"` (wrong type) is treated as random, no crash;
    - failed load: payload `{"level_id": &"nope"}` and `{}` → `_nav == [[MAIN_MENU, {}]]`, `get_session() == null`, `assert_push_error("[ERROR][run]")`, typing does nothing;
    - capture keys: after `remove_child(frame)` + `frame.free()`, `WebPlatform.capture_keys == false`.
  - [x] 7.4 Mutation checks (one at a time, restore and diff-verify, record in the Debug Log): (a) start the clock in `_ready` instead of on `run_started` → the waiting-clock test fails; (b) `CONNECT_DEFERRED` on `char_accepted` → the same-frame test fails; (c) drop the `minf` clamp → the 120.0 test fails; (d) skip the `DONE` guard so `_send_result` can run twice → the single-navigation test fails; (e) don't turn the `TypingInput` gate off in `ENDING` → the input-rejection test fails (or show why the state check alone still holds and the gate test is in `test_typing_input.gd`; be honest in the log).

- [x] **Task 8: Run and verify (AC: 10)**
  - [x] 8.1 Red first: write `test_run_clock.gd`, `test_level_base.gd`, `test_level_registry.gd`, `test_test_level.gd` and `test_run_frame.gd` before the scripts exist; record the parse errors. GUT exits 0 when a script fails to parse, so judge by the pass count.
  - [x] 8.2 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: all pass (297 + new), no `Parse Error`, `Failed to load script`, `SCRIPT ERROR`. Commit the `.uid` files.
  - [x] 8.3 Boundary greps: no `await` in `run_frame.gd`, `level_base.gd`, `test_level.gd`, `run_clock.gd`; no `randi(`/`randf(` global calls (method calls on an RNG instance are fine: grep for `[^.]randi(`); `PlayerData` not referenced in `scripts/run/` or `scripts/levels/`; `Router` not referenced in `scripts/levels/`; `Input.` / `_input` / `_unhandled_input` absent from `scripts/levels/` (levels never read input); `FileAccess` still only in `save_service.gd`.
  - [x] 8.4 Desktop manual run (debug): launch the project (Godot MCP `run_project` or the editor), title → main menu → "Test level". Smuck types the run: no timer before the first correct key; wrong keys don't start it; letters change instantly; after 2:00 "Time!" shows briefly and the placeholder report card lists Keys Typed, Errors, WPM, Accuracy, `2:00` and Brains; Play Again starts a fresh test level. Main menu "Play" (Zombie Run, not built yet) returns to the menu with an `[ERROR][run]` line in the output. Record the results in the Debug Log (the agent cannot type into the game window; ask Smuck, or use the built-in browser pane on a local web debug build as in 1.8: `--export-debug "Web" build/web/index.html`, `python -m http.server 8060 -d build/web`).
  - [x] 8.5 Web key capture: in the web debug build, during the test level, Space, `'`, `/`, Backspace and Tab do not scroll or navigate the page, and after the report card they behave normally again (menus). This is the first real check of the 2.1 pipeline in a browser (2.1 deferral).
  - [x] 8.6 `deferred-work.md`: add "Deferred from: dev of story-2-4" with at least: completion bonus is `0` until Story 3.5 adds it to `LevelConfig`; `brains_earned_changed` not connected until the HUD (2.5); `LETTER_POOL_ALL` placeholder until Epic 7; the test level and registry entry ship in release builds but are unreachable there; Play → Zombie Run bounces to the menu until 3.1; the main menu's `_is_debug_build()` seam is a placeholder-menu exception to Boundary 7 (Story 4.2 decides where a debug entry to the test level lives). Mark the resolved older items as resolved where you touched them (2.1 "enabled / active-run gate", 2.2 "RNG sharing", 2.3 "RunClock overshoot"), using the strike-through style already used in that file.

### Review Findings

- [x] [Review][Patch] `debug_only` levels are not enforced at run start. Decision (Smuck): `LevelRegistry.get_scene` returns `null` for `debug_only` entries when `not OS.is_debug_build()`, so a release build takes the existing failure path to the menu; add a test via an `_is_debug_build()`-style seam [scripts/resources/level_registry.gd, scripts/run/run_frame.gd:95-97]
- [x] [Review][Patch] `end_requested` reason is not validated — a level emitting `&"quit"`, `&""` or a typo reaches `RunResult.create` (assert in debug) and saves a bad `end_reason`; reject non-`GameConstants.END_REASON_*` reasons with `Log.error` in `_on_level_end_requested` [scripts/run/run_frame.gd:204-208]
- [x] [Review][Patch] Scene whose `instantiate()` returns null crashes the failure path (`instance.free()` on null) instead of falling back to the menu — null-check before `free()` [scripts/run/run_frame.gd:98-102]
- [x] [Review][Patch] `DONE` can be reached without the result being delivered: `Router.go` drops the call while `_transitioning`; reuse the one-shot `screen_changed` wait the failure path uses [scripts/run/run_frame.gd:179-188]
- [x] [Review][Patch] Weak assertion `assert_eq(result.per_key.size() > 0, true)` — use `assert_gt` [tests/integration/test_run_frame.gd:173]
- [x] [Review][Defer] A level that emits `end_requested` from `on_run_started`/`on_char_accepted` still receives `on_char_accepted` after `on_run_ending`, so a late brain can be counted — deferred, no current level does this; revisit with Zombie Run (3.1) [scripts/run/run_frame.gd:199-201] — deferred, pre-existing
- [x] [Review][Defer] Router-transitioning branch of `_fail_to_menu` and the null-`TargetSource` path have no automated test (every test injects `navigate`; the base `create_target_source` asserts in debug) — deferred, covered by the manual web run; add when a Router test seam exists [scripts/run/run_frame.gd:252-261] — deferred, pre-existing

Dismissed as noise (14): no quit/pause/Esc in a run (scheduled for 2.7 by the spec), Play button pointing at unregistered `zombie_run` (documented placeholder until 3.1), `start()`+`resume()` double call (spec allows it), unused PAUSED/COUNTDOWN states (spec: 2.7), clock advanced in every state (RunClock ignores it when paused), `_`-prefixed contract parameter names, "Time!" for every end reason, pre-start wrong keys counted in accuracy but not time (intended), `capture_keys` flag overlap (Router frees the old screen first; unverified), registry-test null-entry hazard, release-build precondition in the menu test, navigate-recorder guard, `.tres` uid churn, float seed fallback.

## Dev Notes

### What this story is (and isn't)

- It turns the 1.3 placeholder run screen into the real **run frame**: the third stage of the typing pipeline (ADR-1). `TypingInput` (2.1) → `TypingSession` (2.2) → **`RunFrame`** → level (`LevelBase`). It owns the state machine, the clock, the RNG and the result (`RunResult`, 2.3).
- It adds a **dev-only test level** so the whole loop can be typed today; Zombie Run (3.1) is the first real level and plugs into the same contract.
- **New files:** `scripts/run/run_clock.gd`, `scripts/run/level_base.gd`, `scripts/resources/level_entry.gd`, `scripts/resources/level_registry.gd`, `data/levels/level_registry.tres`, `data/levels/test_level.tres`, `scenes/levels/test_level/test_level.tscn`, `scripts/levels/test_level/test_level.gd`, tests `tests/unit/test_run_clock.gd`, `test_level_base.gd`, `test_level_registry.gd`, `test_test_level.gd`, `tests/integration/test_run_frame.gd` (+ an optional report-card placeholder test).
- **Updated files:** `scripts/run/run_frame.gd` + `scenes/run/run_frame.tscn` (rewritten), `scripts/typing/typing_input.gd` (one `active` flag), `scripts/screens/main_menu.gd` + `.tscn` (debug button), `scripts/screens/report_card.gd` (placeholder shows the result), `tests/integration/test_screen_flow.gd`, `tests/unit/test_main_menu.gd`, `tests/unit/test_typing_input.gd` (one added test), `deferred-work.md`.
- **Don't build:** HUD, timer display, "Type the letter to start!" prompt, live WPM, brain counter, wrong-key shake/tick, Caps Lock hint display (all 2.5); zombie hands (2.6); pause, Esc, focus-loss pause, countdown, quit to menu (2.7); `PlayerData.record_run`, brains commit, history, best WPM (2.8); real report card (2.9); F6 end-run, verbose-log toggle, overlay run fields, `debug_seed` UI (2.10; this story only accepts the payload `seed` and exposes getters); Zombie Run and its registry entry (3.1); completion bonus (3.5).

### Existing code: current state, what changes, what must be preserved

- **`scripts/run/run_frame.gd` / `run_frame.tscn`** (1.3 placeholder): reads the payload into `%PayloadLabel`, Finish → `REPORT_CARD {"result": null}`, Quit → `MAIN_MENU`. **Replaced entirely.** Preserve: the scene path `res://scenes/run/run_frame.tscn` (Router `SCREEN_PATHS`), the root being a full-rect `Control`, payload read once with `Router.take_payload()`.
- **`scripts/autoloads/router.gd`**: `go(screen, payload)` pauses the tree, fades out, `change_scene_to_packed`, **awaits `scene_changed`**, fades in, unpauses, then emits `screen_changed`. A `go()` call while `_transitioning` is **ignored** (logged at DEBUG). Consequences for this story: (1) `RunFrame._ready()` runs during the transition, with the tree paused, so no key can be judged and no clock time passes during the fade-in, which is what we want; (2) a fallback `go(MAIN_MENU)` from `_ready()` would be silently dropped, hence the one-shot `screen_changed` in Task 4.12; (3) the payload dictionary is shallow-copied, so a `RunResult` reference passes through intact. **Do not modify the Router.**
- **`scripts/typing/typing_input.gd`** (2.1): `configure(config)`, `handle_key(event) -> bool`, `_unhandled_input` calls `handle_key` and marks the event handled when it emitted. Adds only `active`. Preserve every filter rule and the Caps Lock streak behaviour and all `test_typing_input.gd` tests.
- **`scripts/typing/typing_session.gd`** (2.2): `TypingSession.new(source, config)`; `judge(c) -> Verdict`; signals emitted synchronously in the order `run_started` → `char_accepted(expected, index)` → `target_changed(next)`; `char_rejected(expected, typed)`; getters `get_keys_typed()`, `get_errors()`, `get_per_key()` (deep copy), `get_current_target()`, `get_upcoming(n)`, `has_started()`. **Not modified.** `target_completed` is deliberately absent until Epic 6.
- **`scripts/typing/letter_bag_source.gd`** (2.2): `LetterBagSource.new(rng, pool: Array[String])`, pool ≥ 2 unique letters, deals lazily from its injected RNG. **Not modified.**
- **`scripts/typing/run_result.gd` / `stats_calculator.gd`** (2.3): `RunResult.create(level_id: StringName, timestamp: int, duration_s: float, keys_typed: int, errors: int, per_key: Dictionary, brains: int, bonus_brains: int, letter_pool_or_tier: String, end_reason: StringName, completed_words: int = 0)`; fields `wpm`, `accuracy`, `lesson_time()`, `total_brains()`. `StatsCalculator.wpm` returns 0 under `GameConstants.MIN_WPM_SECONDS` (1.0 s). **Not modified.**
- **`scripts/core/game_constants.gd`**: `END_REASON_TIMER/CAUGHT/ESCAPED` already exist (2.3). Use them; add nothing.
- **`scripts/resources/level_config.gd`** (2.1): `duration_s`, `case_sensitive`, `space_is_input`, `target_mode`. **Not modified** (3.1 adds spacing/speed fields, 3.5 the bonus).
- **`scripts/autoloads/web_platform.gd`**: `capture_keys` setter pushes the state to the JS listener on web, plain bool on desktop. Only the Keyboard Test screen used it so far.
- **`scripts/screens/main_menu.gd` / `report_card.gd`** (1.3 placeholders): kept as placeholders; only the debug button and the result text are added. Story 4.2 and 2.9 replace them.
- **`tests/integration/test_screen_flow.gd`**: instances every screen **disabled** and checks placeholder buttons; its `test_every_screen_instantiates` instantiates `RUN` with no payload. With the new `RunFrame` that would fail to the menu through the **real Router** and swap GUT's scene. Task 6.3 is mandatory, not cleanup.

### Call order inside one run (document it in `level_base.gd`)

```
_ready:   level instanced → add_child(level) (level _ready) → create_target_source(rng) → TypingSession → configure input
first correct key:   judge → run_started → RunFrame: _set_state(RUNNING) (clock.start) → level.on_run_started()
                     → char_accepted → level.on_char_accepted(expected, 0) → target_changed (unconnected for now)
each correct key:    level.on_char_accepted(expected, index)        (same call stack as the key event)
each wrong key:      level.on_char_rejected(expected, typed)        (also before the first correct key)
end:   clock ≥ duration (RunFrame) or level.end_requested(reason) → ENDING → level.on_run_ending(reason) → wait outro → DONE → RunResult → Router
```

- A wrong key before the run starts still counts as an error (2.2 rule) and reaches `on_char_rejected` (the level may wobble its target); it never starts the clock.
- `on_run_started` comes **before** the first `on_char_accepted`, in the same key event.

### State machine (this story's slice)

| From | Event | To | Enter actions |
|---|---|---|---|
| `WAITING_FIRST_KEY` | first correct key (`run_started`) | `RUNNING` | `clock.start()`, `level.on_run_started()` |
| `RUNNING` | `elapsed >= duration` (`duration > 0`) | `ENDING` | `clock.pause()`, input gate off, `outro = level.on_run_ending(&"timer")` |
| `RUNNING` | `level.end_requested(reason)` | `ENDING` | same, with `reason` |
| `ENDING` | outro time used up | `DONE` | build `RunResult`, `navigate(REPORT_CARD, {result})` once |
| any other | key / `end_requested` | (no change) | ignored |

`PAUSED`/`COUNTDOWN` exist in the enum but nothing enters them until 2.7. In 2.7, `RUNNING` re-entry uses `clock.resume()`; keep `start()` for the very first entry only (Task 4.3), e.g. `if _clock.is_running() == false and not _clock_started: start() else: resume()`, or simply make `RunClock.start()` a no-op once started and call `start()` then `resume()`.

### RNG and seed replay

- One `RandomNumberGenerator` per run (architecture Randomness). The seed is always a concrete non-negative number, from the payload or freshly generated, so 2.10 can show it and replay it.
- **2.2 deferral resolved here:** the level gives the bag its own child RNG seeded from the run RNG. The child is seeded at `create_target_source` time, before any level draw, so the letter sequence depends only on the seed, whatever the level does with the run RNG later (3.2's brain-block shuffle draws from the run RNG).
- `int(payload.get("seed", -1))` on a non-number throws or returns 0 depending on type; check `typeof(...) == TYPE_INT` first and treat anything else as "random".

### Failed loads (NFR16)

- The player never sees technical text (NFR9): no error label; just return to the menu. The log carries the reason.
- Order matters: `capture_keys = true` first, so the `_exit_tree` reset always pairs with it.
- In tests `navigate` is a recorder, so the fallback is immediate and `Router.screen_changed` is never involved.

### Key capture

- Architecture: "`RunFrame` sets it true in `_ready()` and false in `_exit_tree()`, so keys are swallowed for the whole run (including pause and countdown) and never in menus." Covers the report card swap, quit to menu (2.7) and a failed load.
- `test_screen_flow.gd` asserts `capture_keys` is false before each test and after all; every `RunFrame` instance in tests must be freed (autofree) to reset it.

### Testing approach

- **Deterministic driving:** instances are `PROCESS_MODE_DISABLED`, so the engine never calls `_process` or delivers real keys; `_ready` and signals still work. Tests call `frame._process(delta)` and `frame.get_node("%TypingInput").handle_key(event)` directly. This is the same "disabled instance" rule the screen tests use.
- `RunFrame` has no `class_name`; tests type it as `Control` and call its methods (`frame.get_state()`), or `preload` the script for the enum (`const RunFrameScript := preload("res://scripts/run/run_frame.gd")`, `RunFrameScript.RunState.RUNNING`), like `test_main_menu.gd` does with `MainMenuScript`.
- Error-path tests: `Log.error` uses `push_error`; assert with `assert_push_error("[ERROR][run]")` as `test_router.gd` does.
- Every test must be able to fail (mutation checks, Task 7.4). Contract asserts (base `create_target_source`, `TypingInput.configure(null)`) are never called in tests.
- The suite prints expected `ERROR`/`WARN` lines from error-path tests; judge by pass count, exit code, and no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.

### Coding conventions (architecture: Naming, Consistency, Communication)

- Static typing everywhere (`untyped_declaration = Error`), including lambda parameters in tests (`func(screen: int, payload: Dictionary) -> void:`).
- "Call down, signal up": `RunFrame` calls level methods; the level only emits `end_requested` / `brains_earned_changed`. Dependencies are injected (`@export level_registry`, the run RNG through `create_target_source`).
- Signal handlers named `_on_<source>_<signal>` (e.g. `_on_typing_input_char_typed`, `_on_session_run_started`, `_on_level_end_requested`).
- Logging tags: `&"run"` for the frame, `&"level"` for level/registry contract issues. No logging in `_process` or per key (verbose typing logs are 2.10).
- `.tscn` files: `unique_name_in_owner = true` for `%LevelHost`, `%TypingInput`, `%LetterLabel`, `%StatusLabel`, `%TestLevelButton`. Write resources by hand (as earlier stories did) or with the Godot MCP `create_scene`/`add_node`/`save_scene` tools, then run `--import` and commit the generated `.uid` files.
- Godot 4.7: typed `Array[LevelEntry]` exports work in `.tres` (`entries = Array[ExtResource("...")]([SubResource("...")])`); check the saved file loads by running the registry test, not by eye.

### Project Structure Notes

- Matches the architecture tree: `scripts/run/run_frame.gd`, `run_clock.gd`, `level_base.gd`; `scripts/resources/level_registry.gd`; `data/levels/level_registry.tres`; levels in `scenes/levels/<id>/` + `scripts/levels/<id>/` ("New level" rule). `LevelEntry` is a new small Resource beside `level_registry.gd` (the architecture names only the registry; the entry type is how a typed `.tres` holds "level_id → scene + flags").
- `tests/integration/test_run_frame.gd` is named in the architecture.
- Variance: the main menu's debug-only button uses `OS.is_debug_build()` outside `scripts/debug/` (Boundary 7). It is a placeholder-menu exception the epic asks for ("the button exists only in debug builds"), isolated in one seam method, and recorded for Story 4.2.

### Previous story intelligence (2.3, 2.2, 2.1)

- **2.3:** `RunResult.create` positional order (above); records keep `duration_s` floored; `MIN_WPM_SECONDS` makes a sub-second run show 0 WPM; the timer clamp is explicitly handed to this story.
- **2.2:** emit order `run_started → char_accepted → target_changed`; `index` is 0-based; RNG-sharing and re-entrancy notes (both handled here: child RNG; no handler calls `judge`).
- **2.1:** `TypingInput` needs an active gate and run-screen buttons must be `FOCUS_NONE` (no buttons yet); this run is the first end-to-end keyboard check of the filter.
- Habits that reviews enforced: red run recorded first; one-change-at-a-time mutation checks; `##` docs on every public member; exact assertions; never call contract `assert`s in tests; disabled scene instances so real input can't reach the live Router.
- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` after adding `class_name` scripts or resources, then the GUT command.

### Git intelligence

- One commit per story, `Story 2.N: <lower-case title>`, with scripts + `.uid`s, scenes, data, tests, the story file, `sprint-status.yaml` and `deferred-work.md`. Note: Story 2.3's work is still **uncommitted** in the working tree (status `done` in sprint-status). If Smuck asks for commits, commit 2.3 first (`Story 2.3: stats calculator and run result`), then this story (`Story 2.4: run frame, level contract and test level`).
- No new dependencies: built-in Godot APIs and GUT only.

### Latest tech notes (Godot 4.7.2)

- `Node.process_mode = PROCESS_MODE_DISABLED` stops `_process` and input callbacks but not `_ready` or signals.
- `SceneTree.change_scene_to_packed` swaps at the end of the frame; `scene_changed` fires after the new scene's `_ready` (the Router relies on it).
- `Signal.connect(callable, CONNECT_ONE_SHOT)` disconnects after the first emission.
- `RandomNumberGenerator.seed` setter resets the state; `randomize()` picks a time-based seed; `randi()` returns a 32-bit unsigned value as `int` (non-negative), so `child.seed = rng.randi()` and a generated run seed are always `>= 0`.
- `Time.get_unix_time_from_system()` returns UTC seconds as `float`.
- No web research needed beyond these stable 4.x APIs.

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md` (State Management, Screen Flow, Typing Pipeline & Level Contract, Communication / Entity / State Patterns, Randomness, Web Platform `capture_keys` lifecycle, Architectural Boundaries, Consistency Rules) and are summarised above. Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; the Godot MCP server (`run_project`, `get_debug_output`, scene tools) is available and useful for the manual run in Task 8.4.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.4: Run Frame, Level Contract and Test Level] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR1, FR6, FR13 (quit, 2.7), FR24; NFR2, NFR16.
- [Source: _bmad-output/game-architecture.md#State Management] — `RunState` machine, `RunClock` accumulates delta only while running, tree paused through COUNTDOWN.
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract] — `LevelBase` signatures, rules, brains during a run, feedback latency, randomness.
- [Source: _bmad-output/game-architecture.md#Screen Flow] — `RUN` and `REPORT_CARD` payloads.
- [Source: _bmad-output/game-architecture.md#Web Platform] — `capture_keys` lifecycle.
- [Source: _bmad-output/game-architecture.md#Communication Patterns, State Patterns] — `_start_level` and `_set_state` examples.
- [Source: _bmad-output/game-architecture.md#Debug Tools] — `debug_seed` → payload `seed`, `-1` = random.
- [Source: _bmad-output/game-architecture.md#Project Structure, Architectural Boundaries] — file locations, Boundary 7 (debug code), levels never read input.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — 2.1 active gate / FOCUS_NONE / first end-to-end check; 2.2 RNG sharing and re-entrancy; 2.3 RunClock overshoot.
- [Source: _bmad-output/implementation-artifacts/2-3-stats-calculator-and-run-result.md] — `RunResult` API and the 2.4 hand-off notes.
- [Source: _bmad-output/implementation-artifacts/2-2-judgment-session-and-letter-bag.md] — session API and emit order.
- [Source: scripts/autoloads/router.gd] — transition behaviour that shapes the failed-load fallback.
- [Source: tests/integration/test_screen_flow.gd] — the test that must be updated.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline: 299 tests at the start (the story's 297 predates the 2.3 code review, which added 2 tests to `test_stats_calculator.gd` / `test_run_result.gd`). Final: 34 scripts, 350 tests, 350 passing (+51); no `Parse Error`, `Failed to load script`, `SCRIPT ERROR` or GUT warning.
- Red run (8.1): all new and updated tests written first. Parse errors: `Could not find type "LevelBase" / "LevelRegistry" / "LevelEntry" / "RunClock"`, `Cannot find member "RunState" in base "res://scripts/run/run_frame.gd"`, `Preload file "res://scenes/levels/test_level/test_level.tscn" does not exist`. Result: 29 scripts loaded, 297 passing, 8 failing (the updated screen-flow, main-menu, typing-input and report-card tests); the five new script files did not load.
- First green run: 350/350, with one `[GUT WARNING] Ignoring Inner Class TestLevelScript`: GUT treats a constant whose name starts with `Test` as an inner test class. Renamed the preload constant to `LevelScript`; warning gone.
- `RunFrame._process` calls `_clock.advance(delta)` every frame and lets the clock decide (it only accumulates while running). This makes mutation (a) observable and keeps the clock the single authority.
- Re-entrancy (2.2 deferral): no `RunFrame` or level handler calls `judge()`; the session's synchronous emit order (`run_started` -> `char_accepted`) is relied on, not re-entered.
- Mutation checks (7.4), one change at a time, restored and diff-verified:
  - (a) `_clock.start()` in `_ready` -> `test_waiting_clock_stays_at_zero`, `test_first_correct_key_starts_the_clock` fail.
  - (b) `CONNECT_DEFERRED` on `char_accepted` -> `test_level_reacts_in_the_same_call`, `test_fourth_correct_key_earns_a_brain`, `test_timer_end` fail.
  - (c) no `minf` clamp -> `test_timer_end` fails (200.5 s instead of 120.0).
  - (d) removing only the `_set_state` same-state guard: **no test fails**, because nothing re-enters `DONE` (the send happens only on the ENDING -> DONE transition). Paired check: making `_process` keep calling `_set_state(DONE)` while in DONE passes with the guard on (no second send) and fails `test_timer_end` (two navigations) once the guard is also removed. The single send is guaranteed by the transition structure, with the guard as a second line.
  - (e) leaving the `TypingInput` gate on in ENDING -> `test_timer_end` fails (`handle_key` returns true). (g) dropping the state check in `_on_typing_input_char_typed` alone: no test fails, because the gate already stops the key; with both removed `test_timer_end` fails on the counters. The gate and the state check back each other up.
  - (f) the test level passing the run RNG straight to `LetterBagSource` -> `test_source_has_its_own_rng` fails.
- Contract guards not called in tests: base `LevelBase.create_target_source` (assert) and therefore the `null` target-source fallback in `RunFrame`. Covered by review.
- Boundary greps (8.3): no `await` in `run_frame.gd`, `level_base.gd`, `run_clock.gd`, `test_level.gd` (a doc comment containing the word was reworded); no global `randi(`/`randf(`; no `PlayerData` code in `scripts/run/` or `scripts/levels/`; no `Router`, `Input.`, `_input`, `_unhandled_input` in `scripts/levels/`; no `CONNECT_DEFERRED`/`call_deferred` in `scripts/run/`, `scripts/levels/`, `scripts/typing/`; `FileAccess` only in `save_service.gd`.
- 8.4 / 8.5 manual run, done by the agent in the built-in browser pane on a web debug export (`build/web`, served on :8060 through a new `.claude/launch.json` entry `web-debug`):
  - Main menu shows "Test level" (debug build). "Play" logged `[ERROR][run] cannot start run: unknown level_id zombie_run`, then `-> RUN`, `-> MAIN_MENU`: the one-shot `screen_changed` fallback works with the live Router.
  - Test level showed `u`; Space, Tab, Backspace and a wrong `a` left it on `u`; `u` advanced to `f`, then `v`, `y`, `k` (the letter changed on every correct key); "Brains: 1" appeared on the 4th correct key.
  - The run ended by itself about 120 s after the first correct key (the time before that keypress did not count); the report card showed Keys Typed 5, Errors 1, WPM 0 (5 keys in 2 min floors to 0), Accuracy 83%, Lesson Time 2:00, Brains 1. Log: `started level=test_level seed=288107163`, `ended level=test_level reason=timer wpm=0`. Play Again started a fresh test level.
  - Key capture: `window.__zts.capture` was true during the run and false on the report card. Space, Tab and Backspace keydowns were `defaultPrevented`, the canvas kept focus and the URL did not change. The pane's synthetic `'` and `/` arrive with an empty `key`, so those two were blocked by Godot, not proven against the capture listener (open item for Smuck on a real keyboard; in `deferred-work.md`).
  - Not done: a desktop (non-web) run, and a human typing a full-speed run. Noted in `deferred-work.md`.
  - The pane's `type` action inserts text without keydown events (Godot never sees it); only `key` presses reach the game.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `RunClock` (RefCounted): `start` (once), `pause`, `resume`, `advance` (ignores negative/non-finite deltas), `get_elapsed`, `is_running`.
- `LevelBase` (Node2D): the full contract with `##` docs on who calls what and when, the call-order diagram and the child-RNG rule; safe defaults; the base `create_target_source` asserts + logs + returns null.
- `LevelEntry` / `LevelRegistry` resources and `data/levels/level_registry.tres` (one debug-only `test_level` entry; Zombie Run is not registered).
- `TypingInput.active` gate (default true; no existing test changed).
- `RunFrame` rewritten: full `RunState` enum, every transition through `_set_state`, one seeded run RNG (payload `seed` int >= 0, else a generated known seed), `TypingSession` + input wiring in code (no deferred connections), timer end with the overshoot clamp, `end_requested` end (RUNNING only), outro wait, exactly one `RunResult` -> `navigate(REPORT_CARD, {result})`, failed-load fallback to the menu (one-shot `Router.screen_changed` while the Router is transitioning), `capture_keys` true in `_ready` / false in `_exit_tree`, read-only getters. `navigate` seam for tests.
- Test level: `LetterBagSource` over a..z with its own child RNG, letter label, a brain every 4th correct key (`brains_earned_changed`), 0.5 s "Time!" outro; `data/levels/test_level.tres` (120 s, lowercase, Space ignored, letter mode).
- Placeholders: main menu debug-only "Test level" button behind an `_is_debug_build()` seam; report card lists the RunResult's stats and Play Again replays its level.
- Tests: new `test_run_clock.gd` (7), `test_level_base.gd` (5), `test_level_registry.gd` (6), `test_test_level.gd` (8), `test_report_card_placeholder.gd` (2), `tests/integration/test_run_frame.gd` (19); updated `test_screen_flow.gd` (RUN recorder, +1 net), `test_main_menu.gd` (+2, release case through an inner `ReleaseMenu` subclass), `test_typing_input.gd` (+1).
- Beyond the listed cases, `test_run_frame.gd` also covers a `String` level id, a wrong-typed level id, a scene that is not a `LevelBase`, a level without a `LevelConfig`, a second `end_requested` while ending (ignored), the timer ending at exactly the duration, and `capture_keys` reset after a failed load.
- `deferred-work.md`: new "dev of story-2-4" section; 2.1 gate, 2.2 RNG sharing, 2.2 re-entrancy and 2.3 RunClock overshoot struck through as resolved; the 2.1 end-to-end note updated (FOCUS_NONE carries to 2.5/2.7).

### File List

- `scripts/run/run_clock.gd` (new) + `.uid`
- `scripts/run/level_base.gd` (new) + `.uid`
- `scripts/run/run_frame.gd` (rewritten)
- `scenes/run/run_frame.tscn` (rewritten)
- `scripts/resources/level_entry.gd` (new) + `.uid`
- `scripts/resources/level_registry.gd` (new) + `.uid`
- `data/levels/level_registry.tres` (new)
- `data/levels/test_level.tres` (new)
- `scripts/levels/test_level/test_level.gd` (new) + `.uid`
- `scenes/levels/test_level/test_level.tscn` (new)
- `scripts/typing/typing_input.gd` (modified: `active` gate)
- `scripts/screens/main_menu.gd`, `scenes/screens/main_menu.tscn` (modified: debug "Test level" button)
- `scripts/screens/report_card.gd` (modified: shows the RunResult)
- `tests/unit/test_run_clock.gd` (new) + `.uid`
- `tests/unit/test_level_base.gd` (new) + `.uid`
- `tests/unit/test_level_registry.gd` (new) + `.uid`
- `tests/unit/test_test_level.gd` (new) + `.uid`
- `tests/unit/test_report_card_placeholder.gd` (new) + `.uid`
- `tests/integration/test_run_frame.gd` (new) + `.uid`
- `tests/integration/test_screen_flow.gd` (modified)
- `tests/unit/test_main_menu.gd` (modified)
- `tests/unit/test_typing_input.gd` (modified: one added test)
- `.claude/launch.json` (new: `web-debug` static server for the browser-pane check)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-4-run-frame-level-contract-and-test-level.md` (this story)

## Change Log

- 2026-10-04: Story 2.4 implemented: RunClock, LevelBase contract, LevelEntry/LevelRegistry, TypingInput active gate, RunFrame state machine, debug test level, placeholder menu/report-card updates; 51 new tests (suite 299 -> 350), mutation-checked; web debug run in the browser pane. Status -> review.
