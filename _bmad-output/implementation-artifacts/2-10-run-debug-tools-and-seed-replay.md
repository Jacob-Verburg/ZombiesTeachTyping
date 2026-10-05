---
baseline_commit: 295a7ea88ac1b46917a348fe6f82577b22b05f34
---

# Story 2.10: Run Debug Tools and Seed Replay

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer,
I want the debug overlay to show what the run is doing and to replay a run with a fixed seed,
so that I can reproduce and diagnose typing bugs quickly.

## Acceptance Criteria

1. **Run section.** Given a debug build during a run, when the overlay (F3) is open, then it also shows the level id and run state, the clock (elapsed / duration), the current target and the next 3, keys / errors / live WPM, and the run seed (marked when it came from the replay seed). The section is hidden when no run is on screen. Values refresh with the overlay's existing 0.25 s timer, never per frame.
2. **F6 ends the run.** Given the overlay is open, when F6 is pressed while the run is `RUNNING`, then the run ends exactly as if the clock ran out (`END_REASON_TIMER`: `ENDING` → outro → recorded → report card). In any other state (waiting for the first key, paused, countdown, ending, done, no run) F6 changes nothing.
3. **F7 typing log.** Given the overlay is open, when F7 is pressed, then `Log.verbose_typing` toggles and, while it is on, every judgment logs one `Log.debug(&"typing", ...)` line (accepted: expected and index; rejected: expected and typed). The overlay shows whether the typing log is on.
4. **Seed replay.** Given a replay seed pinned in the overlay (F2 pins the last run's seed; F2 again clears it, `-1` = off), when the next run starts with a payload that has no `seed`, then `RunFrame` uses the pinned seed as the payload seed, and the same inputs produce the same target sequence. A payload that carries its own `seed` wins. The overlay shows the pinned seed (or "off") and the last run's seed on every screen.
5. **Release.** Given a release export, when it runs, then none of these fields or keys exist: the overlay is never instanced (Story 1.8, unchanged), `RunFrame` ignores the replay seed and refuses the debug end-run (both gated by `OS.is_debug_build()` through a test seam), and per-judgment logs never print (`Log.debug` is off).
6. **Overlay still fits and never blocks.** With every section shown, the overlay panel stays inside the playfield above the HUD band (bottom ≤ 256 px at 640×360), every control keeps `mouse_filter = IGNORE` and `focus_mode = NONE`, and the closed overlay does no per-frame work.
7. **Tests.** `tests/unit/test_debug_overlay.gd`, `tests/integration/test_run_frame.gd` and `tests/unit/test_typing_session.gd` cover every rule above; the full GUT suite passes.

## Tasks / Subtasks

- [x] **Task 1: `RunFrame` debug hooks (AC: 2, 4, 5)** — `scripts/run/run_frame.gd`
  - [x] 1.1 Statics (no `class_name` exists; the overlay reaches them through `preload("res://scripts/run/run_frame.gd")`):
    - `static var debug_seed: int = -1` — `##` "Debug builds only (Story 2.10): the replay seed the debug overlay pins; -1 = off. Used when the RUN payload has no seed. Release never reads it."
    - `static var last_seed: int = -1` — `##` "Seed of the most recent run that started (the overlay's F2 pins it). Set in `_seed_rng`."
  - [x] 1.2 Test seam `var is_debug_build: Callable`, defaulted in `_ready()` like `navigate` / `pause_tree`: `func() -> bool: return OS.is_debug_build()`. Tests assign `func() -> bool: return false` before `add_child` for the release case. (A Callable, not a `_is_debug_build()` method override like `main_menu.gd`: RunFrame is instanced from a scene, so a subclass would mean `set_script` on the instance.)
  - [x] 1.3 Seed resolution in `_start_level`: replace `_seed_rng(payload.get("seed", -1))` with `_seed_rng(_requested_seed(payload))`:
    - payload has `"seed"` → that value (unchanged behaviour, including `-1` / wrong type = random — existing tests `test_no_seed_is_random_but_known`, `test_wrong_seed_type_is_random` must keep passing);
    - else `is_debug_build.call()` and `debug_seed >= 0` → `debug_seed`, and remember `_replayed = true`;
    - else `-1`.
    `_seed_rng` sets `last_seed = _seed` after choosing it. Extend the existing start log: `Log.info(&"run", "started level=%s seed=%d%s" % [..., " (replay)" if _replayed else ""])`.
  - [x] 1.4 Getters for the overlay (keep them plain, no debug gate): `get_level_id() -> StringName`, `get_duration() -> float` (the config's `duration_s`; `<= 0` = no timer), `is_replay() -> bool`. Existing: `get_state()`, `get_elapsed()`, `get_seed()`, `get_session()` (`get_current_target()`, `get_upcoming(n)`, `get_keys_typed()`, `get_errors()`).
  - [x] 1.5 `func debug_end_run() -> bool`: returns `false` (and `Log.debug(&"run", ...)`) unless `is_debug_build.call()` and `_state == RunState.RUNNING` and not `_quitting`; otherwise `_end_run(GameConstants.END_REASON_TIMER)` and `true`. Do **not** allow it from `PAUSED` / `COUNTDOWN`: the tree is paused there, `_process` would never count the outro down, and the pause panel stays open (soft-lock). Not from `WAITING_FIRST_KEY` either (the clock never ran, so "as if the clock ran out" has no meaning; it would record a 0-key run).
  - [x] 1.6 Update the header comment: replace "The overlay's run fields (2.10) attach here later." with one line on the debug hooks (statics, getters, `debug_end_run`, `is_debug_build` seam).

- [x] **Task 2: Per-judgment verbose log (AC: 3, 5)** — `scripts/typing/typing_session.gd`
  - [x] 2.1 In `judge()`, after the correct path's emits: `if Log.verbose_typing: Log.debug(&"typing", "accepted expected='%s' index=%d" % [expected, index])`; after the wrong path's emit: `if Log.verbose_typing: Log.debug(&"typing", "rejected expected='%s' typed='%s'" % [expected, c])`. The `if` guard comes **first** so no string is formatted when the log is off (deferred-work 1.1: `Log.debug` evaluates its argument). Synchronous, no `await`, no change to signals, counts or return values.
  - [x] 2.2 `Log` is a static class in `scripts/core/` and `TypingSession` already calls `Log.error`, so Boundary 1 (pure typing code: no autoloads, no nodes) still holds. Leave `TypingInput`'s existing `typed 'x'` verbose line as it is (input stage vs judgment stage).

- [x] **Task 3: Overlay run section, keys and seed pin (AC: 1–4, 6)** — `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`
  - [x] 3.1 Scene: add two `Label`s to `Panel/Box` (same settings as the others: `unique_name_in_owner`, `mouse_filter = 2`, font size 8), in this order: `StatsLabel`, **`RunLabel`** (new), `SaveLabel`, **`ToolsLabel`** (new), `HelpLabel`, `ConfirmLabel`. `RunLabel` starts hidden. Do not add buttons or anything focusable.
  - [x] 3.2 Script: `const RunFrameScript: GDScript = preload("res://scripts/run/run_frame.gd")` (debug → run is the allowed direction; nothing in `scripts/run/` may reference `scripts/debug/`). `const UPCOMING_SHOWN: int = 3` (architecture "current target and the next 3"; debug display, not a balance number).
  - [x] 3.3 Test seam `var find_run_frame: Callable` defaulted in `_ready()` to the current scene cast: `func() -> Node: return get_tree().current_scene` and then cast with `as RunFrameScript` in one helper `_run_frame() -> RunFrameScript` that also checks `is_instance_valid` and `not is_queued_for_deletion()`. Tests inject `func() -> Node: return frame`. (`current_scene` is the RunFrame during a run because the Router uses `change_scene_to_packed`; GUT's current scene is its runner, hence the seam.)
  - [x] 3.4 `_handle_key` additions (all only while open; closed → `return false`, like F5/F8/F9):
    - **F6** → `frame.debug_end_run()` if a run frame exists; always `return true` while open (it is the overlay's key), then `_refresh()`.
    - **F7** → `Log.verbose_typing = not Log.verbose_typing`, `Log.info(&"debug", "verbose typing %s" % ("on" if ... else "off"))`, `_refresh()`, `return true`.
    - **F2** → if `RunFrameScript.debug_seed >= 0`: set it to `-1` (clear); elif `RunFrameScript.last_seed >= 0`: pin it; else nothing (log at debug). `Log.info(&"debug", ...)` the new value. `_refresh()`, `return true`.
    - Keep the F8 confirm rule: any key other than F8 cancels a pending confirm (F2/F6/F7 included), as `_handle_key` already does at the top.
  - [x] 3.5 `_refresh()` gains `_refresh_run()` and `_refresh_tools()` (header comment of 1.8 asked for exactly this shape). Formats (tests check substrings; keep each line ≤ 40 glyphs = 320 px at 8 px):
    - `RunLabel` (hidden when there is no run frame or its session is null):
      ```
      Run test_level RUNNING
      Clock 12.3 / 120 s        ("Clock 12.3 s" when duration <= 0)
      Target a > b c d
      Keys 12  Errors 1  WPM 14
      Seed 1234567890 (replay)  ("(replay)" only when is_replay())
      ```
      State name via `RunFrameScript.RunState.keys()[frame.get_state()]`. WPM is the exact live value `StatsCalculator.wpm(keys, elapsed)` (not the HUD's 5 s-hidden rule). Target text: current, then `get_upcoming(UPCOMING_SHOWN)` joined by spaces; an empty target shows `-`.
    - `ToolsLabel` (always):
      ```
      Replay seed: off            | Replay seed: 1234567890
      Last run seed: none         | Last run seed: 1234567890
      Typing log: off             | Typing log: on
      ```
    - `HELP_TEXT` becomes two lines: `"F5 +100 brains  F6 end run  F7 typing log\nF8 reset  F9 export  F2 pin seed"` (each ≤ 41 glyphs). Update the header comment (keys list, sections).
  - [x] 3.6 Nothing new runs while closed: `_refresh_*` are only called from `_refresh()` (timer, open, key handlers). No per-frame lookups, no logging in `_process`.

- [x] **Task 4: Tests (AC: 7)**
  - [x] 4.1 `tests/unit/test_debug_overlay.gd` (read it first; keep its fresh SaveService/PlayerData pattern). Add `after_each` resets: `Log.verbose_typing = false`, `RunFrameScript.debug_seed = -1`, `RunFrameScript.last_seed = -1`. Build run frames the same way `test_run_frame.gd` does (scene instance, `process_mode = DISABLED`, recorder `navigate`, recorder `pause_tree`, a fake `player_data` on a temp SaveService dir, `Router._store_payload({...})` before `add_child`, `Router.take_payload()` in `after_each`). Cases:
    - closed: F2 / F6 / F7 return `false` and change nothing (verbose flag, `debug_seed`, frame state).
    - F7 toggles `Log.verbose_typing` both ways; `ToolsLabel` shows on/off.
    - F2: with `last_seed = -1` nothing is pinned; after a frame started with seed 42 (`last_seed == 42`), F2 pins 42, F2 again clears to -1; labels follow.
    - run section: hidden with `find_run_frame` returning null; shown with a frame (seed 42): contains `test_level`, `WAITING_FIRST_KEY`, the session's current target and its next 3, `Keys 0`, `Seed 42`; after typing correct keys and `_process(delta)` on the frame the keys/state/clock text change; `(replay)` appears only for a replayed frame.
    - F6: frame `RUNNING` → `ENDING` and the recorded result's `end_reason == &"timer"`; frame `WAITING_FIRST_KEY` → unchanged; returns `true` while open either way.
    - an F8 confirm is cancelled by F2/F6/F7.
    - update `test_unused_keys_are_not_consumed` (F6 is now used: use `KEY_F4` and `KEY_F10` instead) and `test_labels_fill_in_when_opened` (new `HELP_TEXT`).
    - fit: with the run section shown, `%Panel.get_combined_minimum_size()` + its offset gives a bottom ≤ 256 and a right edge ≤ 640.
    - `test_never_blocks_the_mouse` keeps passing with the new labels (no change needed if 3.1 is followed).
  - [x] 4.2 `tests/integration/test_run_frame.gd` (add the same static resets to `after_each`):
    - `last_seed` equals the started frame's seed.
    - pinned `debug_seed = 777`, payload without `seed` → `get_seed() == 777`, `is_replay()`, and the first N targets equal those of a frame started with payload seed 777 (reuse `_targets`).
    - payload `seed` wins over a pinned `debug_seed`.
    - release seam (`is_debug_build = func() -> bool: return false`): pinned `debug_seed` ignored (random seed, not a replay); `debug_end_run()` returns `false` while `RUNNING`.
    - `debug_end_run()` while `RUNNING` → `true`, state `ENDING`, result recorded with `END_REASON_TIMER` and duration = elapsed so far; a second call → `false`.
    - `debug_end_run()` → `false` and state unchanged in `WAITING_FIRST_KEY`, `PAUSED` and `COUNTDOWN`.
    - `get_level_id()` / `get_duration()` (`test_level`: 120 s).
  - [x] 4.3 `tests/unit/test_typing_session.gd`: with `Log.verbose_typing = true`, judging correct and wrong keys returns the same verdicts, counts and signals as with it off (reset to `false` in `after_each`). The log text itself is checked by the manual run (GUT does not capture `print`).
  - [x] 4.4 Full suite headless (baseline after Story 2.9 + review: **539** passing; confirm the number before starting). No `Parse Error`, `SCRIPT ERROR` or new warnings.

- [x] **Task 5: Manual checks (AC: 1–6)**
  - [x] 5.1 *(Partial: key checks ran in the web debug build only; the overlay covers part of the test level's top letter. See deferred-work.md, dev of story-2-10.)* Desktop debug run (Godot MCP `run_project` + `get_debug_output`): Test level → F3 → run section visible and updating; type a few keys; F7 → `[DEBUG][typing] accepted ...` / `rejected ...` lines appear, F7 again → they stop; F2 → "Replay seed: N"; F6 → report card (recorded run); Play Again → same first letters as the pinned run (`[INFO][run] started ... (replay)`); F2 → off; Play Again → different letters. Screenshot the open overlay during a run (fits above the HUD band, doesn't cover the target area).
  - [x] 5.2 *(Partial: in-app browser pane only; real Chrome/Edge still unchecked. See deferred-work.md, dev of story-2-10.)* Web debug export in the browser pane (as in 2.4/2.8): F2, F6 and F7 during a run do what they do on desktop and the browser does nothing else (Chrome/Edge: F6 = focus address bar, F7 = caret-browsing prompt, unless the page swallows them). Ask Smuck to repeat it in real Chrome and Edge. **If the browser steals a key**, add it to `WebPlatform.CAPTURED_KEYS` (applies only while `capture_keys` is on, i.e. during runs; update `test_web_platform.gd`) and record it; don't change the key bindings.
  - [x] 5.3 Release check: no change to release gating code, so the 1.8 release check stands; note it in the record (the new `RunFrame` paths are covered by the release-seam tests).
  - [x] 5.4 F6 writes a real run record into Smuck's dev save (as F5/F8 do). Tell Smuck; don't hide it.

- [x] **Task 6: Wrap-up**
  - [x] 6.1 `deferred-work.md`: add a "Deferred from: dev of story-2-10" section for anything left open (e.g. browser F-key results).
  - [x] 6.2 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`.

### Review Findings

- [x] [Review][Patch] F6 on a no-timer level records duration 0 — decided: keep F6 allowed, clamp the timer-end duration only when `_duration > 0` [scripts/run/run_frame.gd:354]
- [x] [Review][Patch] The pinned replay seed is not tied to a level — decided: remember the pinned level id at F2 and apply the seed only when that level starts (other levels get a fresh seed, no "(replay)"); show the level in ToolsLabel [scripts/run/run_frame.gd:229-233, scripts/debug/debug_overlay.gd]
- [x] [Review][Patch] `last_seed` is set even when the run fails to start — `_seed_rng` assigns it before `create_target_source` can fail, so F2 can pin the seed of a run that never existed. Set it only after `_start_level` succeeds [scripts/run/run_frame.gd:193-196, :248]
- [x] [Review][Patch] The fit test assigns `debug_seed = 1234567890` twice; the second line does nothing [tests/unit/test_debug_overlay.gd:407]
- [x] [Review][Patch] `test_f6_without_a_run_is_harmless` only checks the return value — also assert no navigation and that RunLabel stays hidden [tests/unit/test_debug_overlay.gd:387]
- [x] [Review][Patch] Tasks 5.1 and 5.2 are marked [x], but parts are still open: the desktop key checks were not done (only the web build was tested), the overlay covers part of the playfield letter, and real Chrome/Edge are unchecked. Annotate both tasks as partial and point to deferred-work [2-10 story:98-99]

## Dev Notes

### What this story is (and isn't)

- Extends the Story 1.8 overlay with the run fields, F6 / F7 and a replay seed, and gives `RunFrame` the matching debug hooks. The last Epic 2 story; nothing depends on it.
- **Updated files:** `scripts/run/run_frame.gd`, `scripts/typing/typing_session.gd`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`, `tests/unit/test_debug_overlay.gd`, `tests/integration/test_run_frame.gd`, `tests/unit/test_typing_session.gd`, `deferred-work.md`, `sprint-status.yaml`. Maybe `scripts/autoloads/web_platform.gd` + `tests/unit/test_web_platform.gd` (only if Task 5.2 finds a browser stealing a key).
- **No new files** are needed.
- **Don't build:** typing an arbitrary seed into the overlay (it is mouse- and focus-free by design; pin-the-last-seed covers replay), a command-line seed argument, a seed field on `RunResult` or in the save, changes to the Router, the main menu or the report card payloads, F-key InputMap actions, or any change to release gating.

### Key design decisions (follow these)

- **Where the replay seed lives.** Architecture: "a `debug_seed` set in the overlay (`-1` means random) is passed as the run payload's `seed`". The RUN payload is built by the main menu and the report card's Play Again (`{"level_id": ...}`, no seed), and `RunFrame._ready()` reads it inside `Router.go()`, so the overlay cannot rewrite it in between. Therefore `RunFrame` substitutes the pinned seed when the payload has none: `static var debug_seed` on `run_frame.gd`, set by the overlay. That keeps the dependency one-way (debug → run; Boundary 7: `scripts/run/` never references `scripts/debug/`). The pin is **sticky** until F2 clears it, so Play Again keeps replaying the same bag while debugging.
- **Why "pin the last run's seed".** The overlay has no focusable controls (`test_never_blocks_the_mouse`), and digits typed during a run belong to `TypingInput`. Pinning `last_seed` covers the real workflow: spot a bug → F3 → F2 → finish or quit → Play Again replays it. `last_seed` survives leaving the run, so F2 also works on the report card or menu.
- **Why F2 for the pin.** F6/F7 are fixed by the architecture. F2 is unbound in Chrome, Edge and Firefox (F1 = help, F10 = browser menu, F11 = fullscreen, F12 = dev tools) and sits next to F3.
- **Why F6 only in `RUNNING`.** "As if the clock ran out" = `_end_run(END_REASON_TIMER)`, the same call `_process` makes at the duration. In `PAUSED`/`COUNTDOWN` the tree is paused (only the overlay runs: `PROCESS_MODE_ALWAYS`), so `ENDING`'s outro never counts down and the pause panel stays up. `_record_result` already clamps a timer end with `minf(elapsed, duration)`, so an early F6 records the elapsed time.
- **Payload seed wins.** Every existing `test_run_frame.gd` test passes an explicit seed; a leftover static `debug_seed` must never change them. Reset both statics in every `after_each` that touches them anyway.

### Existing code: current state, what changes, what must be preserved

- **`scripts/debug/debug_overlay.gd`** (Story 1.8): `CanvasLayer`, layer 110, `PROCESS_MODE_ALWAYS`, hidden at start, keys in `_input` (not `_unhandled_input`; the Keyboard Test screen swallows keys there), ignores echo and any modifier (a modifier cancels a pending F8 confirm), `_handle_key(keycode) -> bool` is the test entry point, cheats only while open, `_refresh()` on open + every 0.25 s via `%RefreshTimer`, `_process` only records frame times. Seams `player_data` / `save_service`. **Changes:** two labels, three keys, two refresh helpers, a `find_run_frame` seam, help text. **Preserve:** everything else, including F8's two-step confirm and "closed = no per-frame work".
- **Overlay hosting** (`scripts/autoloads/router.gd`): the Router adds the overlay as its child in `_ready()` only when `_is_debug_build()`; it survives scene swaps. **No change.**
- **`scripts/run/run_frame.gd`**: `_seed_rng(requested)` already accepts an int ≥ 0 or randomises to a known `_seed`; `get_seed()` exists "for the overlay (Story 2.10)". `_end_run(reason)` → `_set_state(ENDING)` → `_record_result()` → `player_data.record_run` → outro → `DONE` → report card. State changes only through `_set_state` (architecture rule). Seams: `navigate`, `pause_tree`, `player_data`. **Changes:** Task 1 only. **Preserve:** no `await` in the typing path, `capture_keys` on/off pairing, the existing seed semantics for explicit payload seeds.
- **`scripts/typing/typing_session.gd`**: pure judgment; Task 2 adds two guarded log lines and nothing else.
- **`scripts/core/log.gd`**: `static var verbose_typing := false`; `debug()` prints only when `debug_enabled` (= `OS.is_debug_build()`). **No change.**
- **`TypingInput`** ignores F1–F35 (Story 2.1), so F2/F6/F7 never reach judgment even if the overlay did not mark them handled.

### Testing notes

- GUT 9.7.1, headless: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (same command as earlier stories).
- Statics persist across tests in one GUT run: reset `Log.verbose_typing`, `RunFrameScript.debug_seed`, `RunFrameScript.last_seed` in `after_each` of every file that sets them.
- Tests that call `_unhandled_input()` by hand need the no-op `push_input` reset (deferred-work 2.7). Prefer calling `_handle_key()` / `debug_end_run()` directly.
- `test_run_frame.gd` frames are `PROCESS_MODE_DISABLED`; drive time with `frame._process(delta)` and keys with `%TypingInput.handle_key(event)` (helpers `_send`, `_type_correct`, `_targets` exist).
- Mutation habit from 2.4–2.9: check that the new tests fail when the guard is removed (e.g. F6 allowed in `PAUSED`, payload seed losing to `debug_seed`, release seam ignored), and report honestly.

### Previous story intelligence (2.9 and earlier)

- One exit per screen, state that outlives its trigger gets an explicit test, correct test counts in the record, honest mutation reporting (2.9 review findings).
- 1.8 deferred: the overlay at top-left may cover screen content; Task 4.1's fit test plus the 5.1 screenshot settle it for the run screen.
- 2.4 deferred: a level that emits `end_requested` mid-judgment still gets `on_char_accepted`; F6 comes from `_input`, outside `judge()`, so it doesn't hit that path.
- 2.7: Esc during the countdown is ignored; focus loss pauses only `RUNNING` / `COUNTDOWN`. F6 must not open a new path out of `PAUSED`.

### Git intelligence

- One commit per story (`295a7ea Story 2.9: chalkboard report card`, `986b9d3 Story 2.8…`). Working tree clean at story creation. Suggested message if asked: `Story 2.10: run debug tools and seed replay`.

### Latest tech notes (Godot 4.7.2)

- `static var` on a script without `class_name` is reachable through its preloaded `GDScript` (`RunFrameScript.debug_seed = 5`); statics live for the whole process (not reset between scenes or tests).
- `Callable` default in `_ready()` (`if not is_debug_build.is_valid(): is_debug_build = func() -> bool: return OS.is_debug_build()`) matches the existing `navigate` / `pause_tree` seams.
- `SceneTree.current_scene` is the root of the scene set by `change_scene_to_packed` (after the deferred swap).
- `Control.get_combined_minimum_size()` gives the container's size without waiting for a frame.

### Project Structure Notes

- All overlay code stays in `scenes/debug/` + `scripts/debug/` (Boundary 7). `RunFrame` gets plain getters, two statics and one gated method; it never imports debug code.
- No new autoloads (the list is fixed at five, `test_project_settings.gd`), no InputMap actions, no new `data/` resources (debug values are not GDD numbers).

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md`: Debug Tools (overlay contents, F5–F9, `debug_seed`), Architectural Boundaries 1 and 7, Logging ("never log inside `_process`; per-keystroke logs DEBUG only, only while `Log.verbose_typing`"), Randomness (one RNG per run, seed injected), State Management (`_set_state` only), static typing everywhere (`untyped_declaration = Error`).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.10: Run Debug Tools and Seed Replay]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements (Core architecture: RNG + debug_seed; Cross-cutting: Debug tools)]
- [Source: _bmad-output/game-architecture.md#Debug Tools]
- [Source: _bmad-output/game-architecture.md#Architectural Boundaries]
- [Source: _bmad-output/implementation-artifacts/1-8-debug-overlay-and-save-export.md]
- [Source: _bmad-output/implementation-artifacts/2-4-run-frame-level-contract-and-test-level.md]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md (1.1, 1.8, 2.4, 2.7 sections)]
- [Source: scripts/debug/debug_overlay.gd, scripts/run/run_frame.gd, scripts/typing/typing_session.gd, scripts/core/log.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline before the story: **538** passing (the story said 539; 538 is what the suite reported at `295a7ea`).
- Red phase: the new `test_run_frame.gd` and `test_debug_overlay.gd` cases failed to parse before the code existed (`Cannot find member "debug_seed"` / `"UPCOMING_SHOWN"`). The `test_typing_session.gd` case only checks that nothing changes, so it passes either way (as the story expected; the log text was checked by hand).
- `const RunFrameScript: GDScript = preload(...)` in the overlay gave `Parse Error: Cannot assign a new value to a constant` on `RunFrameScript.debug_seed = ...`. With `const RunFrameScript := preload(...)` (inferred, still statically typed, as the tests do it) the assignment parses.
- Python on Windows wrote CRLF; all touched files were converted back to LF.
- Final suite: **560 / 560** passing (538 + 8 run frame + 13 overlay + 1 typing session), 3,686 asserts. No `Parse Error` / `SCRIPT ERROR`. The 50 "non-equal opposite anchors" warnings are the same count as at baseline.
- Mutation checks (each run against the full suite, then reverted; diff stat confirmed clean):
  - F6 allowed outside RUNNING → 2 failures.
  - release seam ignored in `debug_end_run` → 1 failure.
  - pinned `debug_seed` beats the payload seed → 1 failure.
  - release seam ignored for the seed → 1 failure.
  - `last_seed` never set → 3 failures.
  - F2/F6/F7 work while the overlay is closed → 3 failures.
  - `is_queued_for_deletion()` check removed from `_run_frame()` → 1 failure.
- Manual check, web debug export (`--export-debug "Web"`, served by the `web-debug` launch config, in the in-app browser pane): Test level → F3: run section shows `Run test_level WAITING_FIRST_KEY`, `Clock 0.0 / 120 s`, `Target b > k v l`, `Seed 3950031661`; it fits above the HUD band (panel bottom ≈ 192 of 360 px). Keys b k → RUNNING, keys/clock update. F7 on → `[DEBUG][typing] accepted expected='v' index=2` and `rejected expected='l' typed='q'`; F7 off → no more judgment lines. F2 → `Replay seed: 3950031661`. F6 → `ended level=test_level reason=timer`, recorded, report card with Lesson Time 0:11 (elapsed, not 2:00); run section hidden there, tools section shown. Play Again → `started ... seed=3950031661 (replay)`, same `b > k v l`. F6 before the first key and while paused → `debug end run refused in WAITING_FIRST_KEY` / `PAUSED`, nothing changed. F2 → off; Quit to Menu → Test level → new seed 2199887157, different letters.
- Desktop debug run (Godot MCP `run_project`): starts clean. It now prints two pre-existing `UNUSED_SIGNAL` warnings from `level_base.gd` at launch. At baseline the same two print when a run loads (checked by running `run_frame.tscn` at `295a7ea`). The overlay's preload just loads the script earlier. Logged in deferred-work.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- **RunFrame** (`scripts/run/run_frame.gd`): statics `debug_seed` / `last_seed`; `is_debug_build` Callable seam (defaults in `_ready`); `_requested_seed(payload)`: the payload `seed` wins (including -1 / wrong type = random), then a pinned `debug_seed` in a debug build (`_replayed = true`), else random. `_seed_rng` sets `last_seed`. The start log ends in `(replay)` for replays. Plain getters `get_level_id()`, `get_duration()`, `is_replay()`. `debug_end_run()` → `_end_run(END_REASON_TIMER)` only when debug, `RUNNING` and not quitting; anything else logs at debug and returns false. Header comment updated.
- **TypingSession**: two `if Log.verbose_typing:` guarded `Log.debug(&"typing", ...)` lines (accepted: expected + index; rejected: expected + typed). The guard comes first, so nothing is formatted when the log is off. No change to signals, counts or verdicts.
- **Overlay**: `RunLabel` (hidden at start) and `ToolsLabel` in the scene order StatsLabel, RunLabel, SaveLabel, ToolsLabel, HelpLabel, ConfirmLabel; same label settings, nothing focusable. Script: `RunFrameScript` preload (debug → run only), `UPCOMING_SHOWN = 3`, `find_run_frame` seam (default `get_tree().current_scene`), `_run_frame()` helper (null / invalid / queued for deletion → null). F6 / F7 / F2 only while open, each always returns true and refreshes. Any of them cancels a pending F8 confirm (existing top-of-`_handle_key` rule). `_refresh_run()` / `_refresh_tools()` are called only from `_refresh()` (timer, open, keys), so nothing new runs per frame or while closed. Live WPM = `StatsCalculator.wpm(keys, elapsed)`. Two-line `HELP_TEXT`. Header comment lists the sections and keys.
- **Tests**: 8 new RunFrame cases (last_seed, replay = same targets as payload seed 777, payload wins incl. explicit -1, release seam for seed and end-run, debug_end_run ends like the timer with elapsed duration + second call refused + refused after DONE, refused in WAITING / PAUSED / COUNTDOWN, getters). 13 new overlay cases (closed keys inert, F7 toggle, F2 pin/clear/none, tools without a run, run section hidden/shown/content/updates/replay mark/frame freed, F6 RUNNING → ENDING + recorded `timer`, F6 refused before first key, F6 without a run, confirm cancelled by F2/F6/F7, fit ≤ 256 px / ≤ 640 px with every section incl. the confirm line). Two existing overlay tests updated as the story said (`KEY_F4`/`KEY_F10`, new help text). 1 typing-session case (verbose on = same verdicts, counts, per-key record and signal order). Static resets in every `after_each` that touches them.
- **Release (5.3)**: no change to release gating. The overlay is still only instanced by the Router when `OS.is_debug_build()` (Story 1.8 check stands). The new RunFrame paths are gated by `is_debug_build` and covered by the release-seam tests. `Log.debug` stays off in release.
- **Browser keys (5.2)**: in the in-app browser pane F2/F6/F7 reached the game and the browser did nothing else. Real Chrome and Edge still need checking by Smuck (F6 address bar, F7 caret browsing). `CAPTURED_KEYS` unchanged for now.
- **Dev save (5.4)**: the manual run used the web build, so the recorded F6 run went into the browser's IndexedDB save on localhost:8060, **not** the desktop dev save. An F6 in a desktop debug run *will* write a real run record into the dev save, the same way F5/F8 change it.
- **5.1**: the key-driven checks ran in the web debug build. The Godot MCP can't send keys to the desktop window, so the desktop run only confirmed a clean launch. Smuck can repeat F2/F6/F7 on desktop if wanted (same code).

### File List

- `scripts/run/run_frame.gd` (modified)
- `scripts/typing/typing_session.gd` (modified)
- `scripts/debug/debug_overlay.gd` (modified)
- `scenes/debug/debug_overlay.tscn` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `tests/unit/test_debug_overlay.gd` (modified)
- `tests/unit/test_typing_session.gd` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-10-run-debug-tools-and-seed-replay.md` (this story file)

## Change Log

- 2026-10-04: Story 2.10 implemented. RunFrame debug hooks (replay seed statics, getters, gated `debug_end_run`, `is_debug_build` seam). Per-judgment verbose typing log. Overlay run + tools sections, F2 seed pin, F6 end run, F7 typing log. 22 new tests (560 passing). Status → review.
- 2026-10-04: Code review (gds-code-review): 6 patches applied. The pinned seed is tied to its level (`debug_seed_level` / `last_seed_level`; ToolsLabel shows `N (level)`). `last_seed` is set only after `_start_level` succeeds. A timer end clamps only when `_duration > 0`, so F6 on a no-timer level keeps the elapsed time. Test cleanups, and tasks 5.1/5.2 annotated as partial. 2 new tests (562 passing); removing either decided guard fails a test. The failed-load `last_seed` move has no dedicated test (it needs a level whose target source is null after seeding). Status → done.
