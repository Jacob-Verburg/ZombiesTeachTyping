---
baseline_commit: 1970468e1627a46afb44e10b929461ded5cb4443
---

# Story 2.5: Shared HUD with Wrong-Key Feedback

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want to see my target, timer and stats in the same place in every level, and a clear little wobble when I miss,
so that I always know what to type and how I'm doing.

## Acceptance Criteria

1. **Layout sketch gate.** Given the HUD band in `UX/DESIGN.md` (Layout & Spacing, HUD components) and the Run HUD mock (letter and word modes), when the HUD is built, then it matches them, including the brain counter in every mode (D15); and a layout sketch covering **letter, word and 2-line paragraph** modes, with the final pixel widths, is approved by Smuck and recorded in this story's Dev Agent Record **before** the HUD layout is built (DESIGN.md: "the approved Story 2.5 layout sketch fixes" the band widths). Deviations forced by the font (see Dev Notes "The font problem") are listed in the sketch and approved with it.
2. **Band contents.** Given the HUD inside `RunFrame` at 640×360, then the bottom 104 px band holds, left to right: a pet slot (empty cushion for now), the target area with an empty 48 px zombie-hands area below it, a stats column with Timer, Keys, WPM and Errors rows (labels as approved in the sketch), and the brain counter beside it, which starts at 0 and updates in the same call as `LevelBase.brains_earned_changed`; a pause button sits in the playfield's top-right (FR14, D15).
3. **Readability.** The target character is at least 32 px tall and every HUD text is at least 16 px (NFR7), at whole multiples of the font's 8 px grid; every visible HUD string's characters exist in the project font (no missing-glyph boxes).
4. **Target area by mode.** The target area's size comes from `LevelConfig.target_mode`: one 32 px line for `LETTER` and `WORD`, two 24 px lines for `PARAGRAPH`, with the hands area below in every mode and the band height unchanged, so Epic 8 needs no HUD rework. This story renders letter targets; word progress colouring (Story 6.2) and paragraph text (Story 8.2) only fill the area sized here.
5. **Waiting prompt.** Given the run is in `WAITING_FIRST_KEY`, then the HUD shows the first target and the label "Type the letter to start!" ("word" / "text" by target mode), the timer shows the full run length and WPM shows the placeholder dash; the label hides on the first correct key (FR6).
6. **Live stats.** Given a running run, then Timer shows the time left (counting down to `0:00`), the live WPM stays hidden for the first 5 s of run time and then updates once per second of run time (FR8), and Keys and Errors update in the same call as each judgment (before `TypingInput.handle_key()` returns).
7. **Wrong key.** Given a wrong printable key, when it is judged, then only the target glyph shakes horizontally for 0.2 s (±2 px), nothing changes colour, and `AudioManager` plays the wrong-key tick, at most once per 150 ms, throttled **inside** `AudioManager` (FR2); `tests/unit/test_audio_manager.gd` covers the 150 ms throttle with a fake clock.
8. **Caps Lock hint.** Given `TypingInput.caps_lock_suspected`, then the HUD shows "Caps Lock is on" in plain words, and hides it on `caps_lock_cleared` (FR5). It never blocks typing.
9. **Pause button and focus.** The pause button and every other HUD control are `FOCUS_NONE`, so Space and Enter can never press them (2.1 deferral). The button emits a `pause_pressed` signal; pausing itself is Story 2.7.
10. **Tests.** Given new `tests/unit/test_hud.gd` and `tests/unit/test_brain_counter.gd`, additions to `test_audio_manager.gd`, `test_audio_library.gd` and `tests/integration/test_run_frame.gd`, when GUT runs, then the layout, prompt per mode, live-WPM rule, same-call counter updates, shake, Caps Lock hint, brain counter, throttle and focus rules are covered and pass, and the full suite has no regressions (confirm the starting count in the first run; 350 at the end of 2.4 dev plus any 2.4 review additions).

## Tasks / Subtasks

- [x] **Task 1: Layout sketch and approval gate (AC: 1, 3, 4) — HUMAN GATE**
  - [x] 1.1 Write the sketch to `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/hud-band-2-5.md`: three ASCII frames (letter, word, paragraph) at 640×360 like the one in DESIGN.md "Layout & Spacing", plus a table of every element's rect (x, y, w, h) and font size. Start from the recommended layout in Dev Notes ("Recommended sketch"); it already fits Press Start 2P's 16 px advance.
  - [x] 1.2 List each deviation from DESIGN.md / FR14 in the sketch: stats label "Keys" instead of "Keys Typed"; stats column 176 px instead of 136 px; start prompt and Caps Lock hint above the band (in the playfield's bottom strip) instead of inside the target area; paragraph mode fits 12 characters per line at 24 px (Epic 8 note); WPM placeholder is `-` (hyphen) unless the font has `–`.
  - [x] 1.3 **Stop and ask Smuck to approve** (or change) the sketch, then record the answer verbatim with the date in Debug Log References ("Sketch approved by Smuck, 2026-10-xx: …"). Do not build Task 4's layout before this. If Smuck changes widths or labels, follow the approved sketch over this story's numbers.

- [x] **Task 2: Fixed rule constants (AC: 6, 7)**
  - [x] 2.1 In `scripts/core/game_constants.gd` add, with one `##` comment each: `LIVE_WPM_DELAY_S: float = 5.0` (FR8: live WPM hidden for the first 5 s of run time), `LIVE_WPM_INTERVAL_S: float = 1.0` (FR8: 1 Hz), `WRONG_KEY_SHAKE_S: float = 0.2` (FR2). These are fixed GDD rules (like `MIN_WPM_SECONDS`), not balance values.
  - [x] 2.2 The ±2 px shake amplitude is a UX `[ASSUMPTION]`, owned by the HUD: `const SHAKE_PX: float = 2.0` in `hud.gd` with a comment citing EXPERIENCE.md Game Feel. The 150 ms tick throttle is per-sound data (Task 3).

- [x] **Task 3: Wrong-key tick and the throttle in `AudioManager` (AC: 7)**
  - [x] 3.1 `scripts/resources/audio_cue.gd`: add `@export_range(0.0, 10.0, 0.01) var min_interval_s: float = 0.0` (`##`: the minimum gap between two plays of this cue; 0 = no throttle. AudioManager enforces it, so callers never throttle).
  - [x] 3.2 `scripts/autoloads/audio_manager.gd`: `## Test seam` `var now_msec: Callable = Time.get_ticks_msec` and `var _last_played_msec: Dictionary[StringName, int] = {}`. In `_try_play_sfx`, after the unlock check and the cue lookup: if `cue.min_interval_s > 0` and the id was played less than `min_interval_s` ago (`now - last < roundi(cue.min_interval_s * 1000.0)`), return `null` without playing; otherwise play and store `now`. A dropped call (locked, unknown id, throttled) never updates the timestamp. Update the header comment ("Later: throttling (2.5 wrong-key …)") to say the per-cue throttle now exists.
  - [x] 3.3 Placeholder sound: extend `tools/gen_placeholder_audio.gd` with `res://assets/audio/sfx/sfx_wrong_key.wav`: a soft, short, low "bonk" (for example 70 ms, about 220 Hz sine or triangle, fast decay, peak ≈ 0.35, so it is quieter than the click: "quiet bonk tick"). Run the tool headless, then `--import`. Commit the `.wav` and `.wav.import`. Add the row to `assets/audio/CREDITS.md` (generated, CC0, placeholder until Story 5.1).
  - [x] 3.4 `data/audio/audio_library.tres`: add the cue `sfx_wrong_key` (stream above, `volume_db` around -6, `min_interval_s = 0.15`). The 150 ms lives here, not in a script (FR2).
  - [x] 3.5 `tests/unit/test_audio_manager.gd` (fresh instance, as the file already does): give the code-built library a throttled cue (`min_interval_s = 0.15`) and set `now_msec` to a lambda returning a test-controlled value. Cases: plays at t=0; `_try_play_sfx` returns `null` at t=100 and t=149; plays at t=150; plays again at t=300 (the gap counts from the last **played** time, not the last request); a throttled id doesn't block another id; an unthrottled cue plays every call; a call before `unlock()` doesn't stamp (after unlock the first call plays). Use `_try_play_sfx` (returns the player or null) as the observable, as existing tests do.
  - [x] 3.6 `tests/unit/test_audio_library.gd`: the shipped library has `sfx_wrong_key` with a stream and `min_interval_s == 0.15`; keep the existing checks.

- [x] **Task 4: Brain counter widget (AC: 2)**
  - [x] 4.1 `scenes/ui/brain_counter.tscn` + `scripts/ui/brain_counter.gd` (architecture names this widget; Story 4.2/4.4 reuse it on the menu and Closet): a wood-dark pill (placeholder `Panel` with a `StyleBoxFlat`, **no corner radius**, 1 px ink border; final 9-slice art is Story 5.0), a placeholder brain icon (16×16 `ColorRect` in `art-brain-pink` `#F29AB8` with a 1 px `art-brain-shade` inner block, or a tiny code-drawn rect; no new PNG required) and a `%CountLabel` (16 px, chalk `#F4F1E4`). `func set_count(n: int) -> void` (negative → logs `Log.error(&"ui", ...)`, shows 0). `mouse_filter = IGNORE`, `focus_mode = NONE` on every node.
  - [x] 4.2 No `PlayerData` connection inside the widget: the owner feeds it (HUD: the level's run total; menu: `PlayerData` in 4.2). The count-up tick and pop (EXPERIENCE.md Game Feel) are Story 5.0/5.1 polish; just set the number.
  - [x] 4.3 `tests/unit/test_brain_counter.gd`: starts at "0"; `set_count(12)` shows "12"; font size ≥ 16; nothing focusable or mouse-blocking.

- [x] **Task 5: `Hud` scene and script (AC: 1–9)**
  - [x] 5.1 `scenes/run/hud.tscn` + `scripts/run/hud.gd` (architecture paths). Root `Hud` (`Control`, full rect, `mouse_filter = IGNORE`). Children, positioned by the **approved sketch**: `%Band` (the 104 px band at y = 256: wood-dark fill, 1 px ink top edge; placeholder `Panel`/`ColorRect`), `%PetSlot` (empty parchment cushion placeholder), `%TargetArea` (contains `%TargetSign` parchment panel and `%TargetLabel`), `%HandsArea` (empty 48 px `Control` placeholder for Story 2.6), `%Stats` (chalkboard `#24402F` panel with four rows: `%TimerValue`, `%KeysValue`, `%WpmValue`, `%ErrorsValue` and their label nodes; labels chalk-dim `#A8C4A6`, values chalk `#F4F1E4`, values right-aligned), `%BrainCounter` (instance of Task 4), `%StartPrompt` (label, chalk on night/ink backing), `%CapsHint` (candy-yellow `#FFD23F` sign, ink text "Caps Lock is on"), `%PauseButton` (24 px, "II" or two bars, top-right with 16 px margins). Every node `focus_mode = NONE`; every node `mouse_filter = IGNORE` except `%PauseButton`.
  - [x] 5.2 Placeholder look only: palette colours (DESIGN.md Colors) via `StyleBoxFlat` with border and **zero** corner radius, or `ColorRect`s. No gradients, no shadows beyond an optional hard 2 px ink offset, no new art files (Story 5.0 replaces the chrome). Use the theme font (`data/ui_theme.tres`, Press Start 2P) at 16 / 24 / 32 px via `theme_override_font_sizes`.
  - [x] 5.3 Public API (all `##`-documented; the HUD never reads input, never touches `TypingSession`, autoloads or the clock; `RunFrame` calls down):
    - `func setup(config: LevelConfig, first_target: String) -> void`: sizes the target area for `config.target_mode` (Task 5.4), sets the prompt text by mode, stores `config.duration_s`, shows `first_target`, Timer = full duration, WPM = placeholder, Keys 0, Errors 0, brains 0, prompt visible, Caps hint hidden.
    - `func show_target(target: String) -> void` (from `TypingSession.target_changed`).
    - `func set_counts(keys: int, errors: int) -> void`.
    - `func set_brains(total: int) -> void` (from `LevelBase.brains_earned_changed`).
    - `func hide_start_prompt() -> void` (on `run_started`).
    - `func update_clock(elapsed: float, keys: int) -> void`: called every frame by `RunFrame._process`; updates Timer and the live WPM (Task 5.5).
    - `func shake_target() -> void` (Task 5.6).
    - `func set_caps_hint(visible: bool) -> void`.
    - `signal pause_pressed` (emitted by `%PauseButton.pressed`; `RunFrame` leaves it unconnected until 2.7, or connects a handler that only logs at DEBUG).
  - [x] 5.4 Target modes: `const PROMPTS: Dictionary[LevelConfig.TargetMode, String] = {LETTER: "Type the letter to start!", WORD: "Type the word to start!", PARAGRAPH: "Type the text to start!"}` (copy from EXPERIENCE.md Voice and Tone). `LETTER`/`WORD`: `%TargetLabel` one line, font size 32, sign height 40 (32 + 2×4 pad). `PARAGRAPH`: two lines, font size 24, line height 24 (no extra line spacing: set `theme_override_constants/line_spacing` so two lines take exactly 48 px), sign height 48 + pads within the band budget (4 + 48 + 48 + 4 = 104). Expose `get_target_line_count() -> int` for the test. Paragraph text content is Story 8.2.
  - [x] 5.5 Clock and live WPM, as a small deterministic rule:
    - Timer: `remaining = maxf(0.0, duration - elapsed)`; show `StatsCalculator.format_time(ceilf(remaining))`, so it reads `2:00` while waiting and through the first second of the run, `1:59` once a full second has passed, `0:01` during the last second, and `0:00` only at the end (a countdown never shows `0:00` while time is left). If `duration <= 0` (a level with no timer) show `format_time(elapsed)` counting up. Rebuild the string only when the shown whole second changes.
    - WPM: while `elapsed < GameConstants.LIVE_WPM_DELAY_S` show the placeholder. From then on, recompute only when `floorf(elapsed / LIVE_WPM_INTERVAL_S)` has changed since the last shown value (so at 5.0, 6.0, 7.0 … seconds of **run** time; paused time never counts because `elapsed` comes from `RunClock`), using `StatsCalculator.wpm(keys, elapsed)`. Between updates the number stays put even as keys rise.
    - No logging in this path; no allocations when nothing changed.
  - [x] 5.6 Shake (FR2, EXPERIENCE.md): only `%TargetLabel` moves; sign, colours, hands and playfield stay still. Implement in `_process(delta)` with a remaining-time counter (deterministic for tests, no `Tween`, no `await`): `shake_target()` sets `_shake_left = WRONG_KEY_SHAKE_S` (a new wrong key restarts it); each frame the label's x offset follows a fixed pattern of `±SHAKE_PX` steps (e.g. +2, -2, +2, -2 in four equal slices of 0.2 s), and when `_shake_left <= 0` the offset returns to exactly 0. `show_target()` during a shake keeps shaking the new glyph (no reset needed) but must never leave a non-zero offset after the time ends. Expose `get_target_offset_x() -> float` for tests. No colour change, no text, no screen shake.
  - [x] 5.7 Placeholder dash: use `-` unless `ThemeDB`/the theme font reports `has_char(0x2013)`; a test checks every shown HUD string against the font (Task 7.1).
  - [x] 5.8 House rules: static typing everywhere, `##` docs on every public member, `_on_<node>_<signal>` handler names, no `await`, no `get_node("/root/...")`, no autoload use in `hud.gd`.

- [x] **Task 6: Wire the HUD into `RunFrame` (AC: 2, 5–9)**
  - [x] 6.1 `scenes/run/run_frame.tscn`: instance `hud.tscn` as `%Hud` **after** `%LevelHost` (drawn on top), before `%TypingInput`. Keep the night background.
  - [x] 6.2 `scripts/run/run_frame.gd` `_start_level`, after the session exists: `%Hud.setup(config, _session.get_current_target())`; connect `_session.target_changed` → `%Hud.show_target`; `_session.char_accepted` → `_on_session_char_accepted` (calls `%Hud.set_counts(...)`), `_session.char_rejected` → `_on_session_char_rejected` (calls `%Hud.set_counts(...)`, `%Hud.shake_target()`, `AudioManager.play_sfx(&"sfx_wrong_key")`); `_level.brains_earned_changed` → `%Hud.set_brains`; `%TypingInput.caps_lock_suspected` / `caps_lock_cleared` → `%Hud.set_caps_hint(true/false)` (small handlers). All plain `connect` (no `CONNECT_DEFERRED`), all synchronous. Keep the existing level connections as they are (the level's `char_accepted` connection was made first, so the level reacts before the HUD; both in the same call).
  - [x] 6.3 `_on_session_run_started`: after `_set_state(RUNNING)` and `_level.on_run_started()`, call `%Hud.hide_start_prompt()`.
  - [x] 6.4 `_process`: after `_clock.advance(delta)`, call `%Hud.update_clock(_clock.get_elapsed(), _session.get_keys_typed())` when a session exists (any state, so the final values stay on screen during the outro). The level-end logic stays as it is.
  - [x] 6.5 Failed load: the HUD stays blank/hidden (`%Hud.visible = false` in `_fail_to_menu`); the player never sees technical text (NFR9).
  - [x] 6.6 `%Hud.pause_pressed`: leave unconnected (Story 2.7 connects it). Keep the `RunFrame` header comment up to date ("The HUD (2.5) …" → done; hands 2.6, pause 2.7 …).
  - [x] 6.7 Brain counter shows the **level's** run total only (architecture "Brains during a run": never `PlayerData.brains_changed`).

- [x] **Task 7: Tests (AC: 10)**
  - [x] 7.1 `tests/unit/test_hud.gd`: instance `hud.tscn` with `process_mode = PROCESS_MODE_DISABLED` (`_process` driven by hand), `add_child_autofree`. Use test `LevelConfig`s built in code (duration 120, each `TargetMode`). Cases:
    - layout: `%Band` rect is y 256, height 104, width 640; left-to-right order `PetSlot.x < TargetArea.x < Stats.x < BrainCounter.x`; every rect matches the approved sketch's table (one assert per element, using `get_global_rect()` or position/size); `%PauseButton` inside the playfield top-right with 16 px margins and 24 px size;
    - readability: `%TargetLabel` font size 32 in letter/word mode and 24 in paragraph mode; every `Label` in the HUD has a font size ≥ 16 and a multiple of 8;
    - glyphs: for each visible HUD string (labels, prompts for all 3 modes, "Caps Lock is on", the WPM placeholder, digits, `:`) every character passes `font.has_char(...)` for the theme font;
    - prompt per mode ("letter" / "word" / "text"); visible after `setup`, hidden after `hide_start_prompt()`;
    - target area: 1 line in LETTER and WORD, 2 lines in PARAGRAPH (`get_target_line_count()`); band height unchanged (104) in all three;
    - waiting: after `setup`, Timer `2:00`, WPM placeholder, Keys `0`, Errors `0`, brains `0`;
    - timer (duration 120): `update_clock(0.0, 0)` → `2:00`; `update_clock(0.3, 0)` → `2:00` (ceil of 119.7); `update_clock(1.0, 0)` → `1:59`; `update_clock(119.5, 0)` → `0:01`; `update_clock(120.0, 0)` → `0:00`; `update_clock(130.0, 0)` → `0:00`; a config with duration 0 counts up (`update_clock(65.0, 0)` → `1:05`);
    - live WPM: `update_clock(4.99, 10)` → placeholder; `update_clock(5.0, 10)` → `24` (10 keys in 5 s); `update_clock(5.5, 30)` → still `24`; `update_clock(6.0, 30)` → `60`; `update_clock(6.9, 99)` → still `60`;
    - counts: `set_counts(42, 3)` shows `42` and `3`; `set_brains(12)` shows `12`;
    - shake: after `shake_target()`, `_process(0.05)` → offset ≠ 0 and |offset| ≤ 2; `_process(0.2)` total → offset exactly 0; a second `shake_target()` mid-shake restarts the 0.2 s; colours (`modulate`, font colour) unchanged during the shake; `%TargetSign` position unchanged;
    - Caps Lock hint: hidden after setup; `set_caps_hint(true)` visible with text "Caps Lock is on"; `false` hides;
    - focus and mouse: every `Control` in the HUD has `focus_mode == FOCUS_NONE`; all but `%PauseButton` have `mouse_filter == MOUSE_FILTER_IGNORE`; pressing `%PauseButton` (`emit_signal("pressed")`) emits `pause_pressed` once.
  - [x] 7.2 `tests/integration/test_run_frame.gd` additions (reuse its helpers and the `navigate` recorder; instances stay `PROCESS_MODE_DISABLED`):
    - the HUD exists and shows the session's first target and the "letter" prompt while waiting;
    - right after a wrong key's `handle_key` returns: HUD Errors shows `1` and the target offset is shaking (after one `_process(0.05)`); after the first correct key: prompt hidden, HUD Keys `1`, HUD target equals `get_session().get_current_target()`;
    - 4th correct key → HUD brain counter `1` in the same call;
    - `_process` drives the timer and live WPM (`_process(5.0)` after the first key → WPM shown);
    - three capital letters (synthetic Shift events, as `test_typing_input.gd` builds them) → Caps hint visible; a lowercase letter → hidden;
    - failed load → HUD hidden.
  - [x] 7.3 Mutation checks (one change at a time, restore and diff-verify, record in the Debug Log): (a) connect `char_rejected` → HUD with `CONNECT_DEFERRED` → the same-call Errors test fails; (b) update live WPM every call instead of at 1 Hz → the `5.5 → 24` case fails; (c) show WPM before 5 s → the `4.99` case fails; (d) remove the timestamp check in `AudioManager` → the throttle test fails; (e) stamp the time on throttled calls too → the `t=300` case fails; (f) leave the offset at the last pattern value when the shake ends → the "exactly 0" case fails; (g) set `%PauseButton.focus_mode = FOCUS_ALL` → the focus test fails.

- [x] **Task 8: Run and verify (AC: 10)**
  - [x] 8.1 Red first: write `test_hud.gd`, `test_brain_counter.gd` and the new cases before the code; record the parse errors / failures. GUT exits 0 on a parse failure, so judge by the pass count.
  - [x] 8.2 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: all pass, no `Parse Error`, `Failed to load script`, `SCRIPT ERROR`, GUT warnings. Commit generated `.uid`/`.import` files.
  - [x] 8.3 Boundary greps: no `await` in `hud.gd`, `brain_counter.gd`, `run_frame.gd`; no autoload names (`Router`, `PlayerData`, `AudioManager`, `SaveService`, `WebPlatform`) in `hud.gd` or `brain_counter.gd`; no `CONNECT_DEFERRED`/`call_deferred` in `scripts/run/`; no `corner_radius` in the new `.tscn` files.
  - [x] 8.4 Visual check against the mock and the approved sketch: export a web debug build (`.claude/launch.json` entry `web-debug` from 2.4: `--export-debug "Web" build/web/index.html`, served on :8060), open it in the built-in browser pane, start the test level, and take screenshots of (a) waiting, (b) running after 5 s, (c) a wrong key mid-shake if the timing allows, (d) the Caps Lock hint (type 3 capitals). Compare with `mockups/key-run-hud.html` frames A and C and the sketch; note differences that are only placeholder chrome (Story 5.0). Attach/describe in the Debug Log and show Smuck.
  - [x] 8.5 Listen check (Smuck, desktop or browser): the wrong-key tick is quiet, short and at most ~6–7 per second when mashing a wrong key; correct keys make no tick.
  - [x] 8.6 `deferred-work.md`: add "Deferred from: dev of story-2-5" with at least: placeholder HUD chrome until Story 5.0; brain counter tick-up/pop polish (5.0/5.1); word-mode colouring/underline (6.2) and paragraph rendering (8.2) use the sized area; paragraph width (about 12 characters per 24 px line with Press Start 2P) for Epic 8; any sketch deviation Smuck approved. Strike through the 2.1 `FOCUS_NONE` note and the 2.4 `brains_earned_changed` note as resolved.

### Review Findings

- [x] [Review][Patch] Caps Lock hint stays on screen through the outro: `TypingInput.active = false` in `ENDING` stops `caps_lock_cleared` from ever firing, and `_set_state(ENDING)` never clears the hint. Call `%Hud.set_caps_hint(false)` on `ENDING` and add a run-frame test [scripts/run/run_frame.gd:185-189]
- [x] [Review][Defer] `%TargetLabel` has no `autowrap_mode`, so paragraph text stays on one line and overflows the 2-line sign (the layout only sizes the area) — deferred, paragraph rendering is Story 8.2 [scripts/run/hud.gd:78, scenes/run/hud.tscn] — deferred, pre-existing
- [x] [Review][Defer] Word sign width is unclamped: a word over ~9 letters at 32 px overflows the 312 px target area (spec only requires the longest MVP/Epic 6 word, 8 letters, to fit) — deferred to Story 6.x [scripts/run/hud.gd `_layout_target`] — deferred, pre-existing
- [x] [Review][Defer] The wrong-key shake runs from the HUD's own `_process`, so it keeps animating if Story 2.7 pauses through RunFrame state instead of the tree — deferred to Story 2.7 [scripts/run/hud.gd:901-912] — deferred, pre-existing

Dismissed as noise (19): duplicate signal connects on restart (`_start_level` runs once per RunFrame), HUD never re-shown after a failed load (the frame is freed), HUD timer/WPM refreshing during ENDING (clock is paused; value is stable), wrong-key tick silent before audio unlock (FR47, intended), no rect asserts for `%TargetLabel`/brain-counter children, `%TargetLabel` nested under `%TargetSign` (still inside `%TargetArea`), tautological or weak test details (pressed-signal emit, 104 px band asserts, exact-float Rect2 compares, magic caps threshold, default-clock test, private `_process` call), duplicated layout constants, `PROMPTS.get` fallback, leftover `line_spacing` override, throttle stamp order, `.wav` uid, CapsHint/StartPrompt overlapping playfield strip (per approved sketch), band drawn over level content (by design).

## Dev Notes

### What this story is (and isn't)

- It adds the **shared HUD band** every level uses (GDD Pillar 4, M2b; UX D15) plus the wrong-key feedback (shake + throttled tick). `RunFrame` (2.4) already owns the session, clock and level; this story adds a view (`Hud`) that `RunFrame` drives by calling down, and one per-cue throttle in `AudioManager`.
- **New files:** `scenes/run/hud.tscn`, `scripts/run/hud.gd`, `scenes/ui/brain_counter.tscn`, `scripts/ui/brain_counter.gd`, `assets/audio/sfx/sfx_wrong_key.wav` (+ `.import`), the sketch file, `tests/unit/test_hud.gd`, `tests/unit/test_brain_counter.gd`.
- **Updated files:** `scripts/run/run_frame.gd`, `scenes/run/run_frame.tscn`, `scripts/autoloads/audio_manager.gd`, `scripts/resources/audio_cue.gd`, `data/audio/audio_library.tres`, `tools/gen_placeholder_audio.gd`, `assets/audio/CREDITS.md`, `scripts/core/game_constants.gd`, `tests/unit/test_audio_manager.gd`, `tests/unit/test_audio_library.gd`, `tests/integration/test_run_frame.gd`, `deferred-work.md`.
- **Don't build:** zombie hands and the finger map (2.6; leave the empty 48 px area); pause panel, Esc, focus-loss pause, countdown (2.7; the button only emits); pet display (4.3; empty cushion); final art, 9-slice textures, the brain-counter pop (5.0); word progress colouring and paragraph text (6.2/8.2); any `PlayerData` use in the run.

### The font problem (read before sketching)

Press Start 2P is **monospaced with an advance equal to the font size**: at 16 px every character, spaces included, is 16 px wide; at 32 px, 32 px. DESIGN.md's starting widths were drawn without a chosen font (D11) and are marked `[ASSUMPTION]` "until the Story 2.5 sketch":

| Element | DESIGN.md start | What the font needs |
|---|---|---|
| Stats row "Keys Typed 142" | 136 px column | 14 chars × 16 = **224 px**, doesn't fit |
| Stats row "Timer 1:23" | 136 px | 10 × 16 = 160 px |
| Stats row "Errors 999" | 136 px | 10 × 16 = 160 px |
| "Type the letter to start!" | inside the target area | 25 × 16 = **400 px**, wider than any target area |
| "Caps Lock is on" | above the target sign | 15 × 16 = 240 px + sign padding |
| Paragraph line at 24 px | target area width | ≈ 12–13 chars per line |

So the sketch has to choose. This is why AC 1 makes the sketch a gate: these choices change FR14's labels and DESIGN.md's widths, and only Smuck can approve that.

### Recommended sketch (start here; Smuck decides)

```
┌──────────────────────────────────────────────────────────────── 640 ─┐
│                                                               [II]   │ pause 24×24 at (600,16)
│                       playfield (level)                              │
│        ┌ Caps Lock is on ┐   (candy-yellow sign, only when on)       │ hint  y≈208
│     Type the letter to start!   (chalk on an ink strip)              │ prompt y≈232, 400 px, centred on target area
├──────────────────────────────────────────────────────────────────────┤ y=256
│ pet  │           ┌──────┐            │ Timer  1:23 │ (brain) 12 │    │
│ 64px │           │  f   │ sign 40×40 │ Keys     42 │   88 px    │    │ band 104
│      │       (L) hands 48 px (R)     │ WPM      11 │            │    │
│      │      target area 312 px       │ Errors    3 │            │    │
│      │                               │   176 px    │            │    │
└──────────────────────────────────────────────────────────────────────┘ y=360
```

- x ranges: pet 0–64, target area 64–376 (312), stats 376–552 (176), brain counter 552–640 (88).
- Stats: 4 rows, 16 px font, 20 px row pitch (80 px + 2×4 pad + border fits 96 px of band interior); labels "Timer", "Keys", "WPM", "Errors"; values right-aligned to a 4-character slot ("1:23", "9999"). `Errors` + space + 4 digits = 11 chars = 176 px exactly; give the panel 4 px inner pad by letting the label/value slots overlap the space, or widen to 184 and take 8 px from the target area. Pick one and record it.
- Brain counter: 16 px icon + 4 px gap + 3 digits (48 px) + 2×8 px pad = 84 → 88 px. A run never earns 1000 brains (Zombie Run ≈ 35, Pitchfork Panic ≈ 40–160).
- Target area 312 px: letter/word sign centred, 4 px from the band top; hands area 48 px at the band bottom (y 308–356 with 4 px pad). Longest MVP/Epic 6 word (8 letters × 32 = 256 px + pad) fits. Paragraph: 2 × 24 px lines in 304 px usable = **12 characters per line**. Flag it for Epic 8 (options there: accept, use a smaller paragraph font only if one exists at 8 px multiples ≥ 24, or widen the target area by shrinking the stats); not solved here.
- Prompt and Caps hint live **above** the band, centred on the target area's centre x (220), in the playfield's bottom strip, because neither fits inside the target area. DESIGN.md already says the prompt "sits above the sign" and the hint "hung just above the target sign"; this only moves them out of the band.
- Label change: "Keys Typed" → "Keys" on the HUD (the report card keeps "Keys Typed", where there is room). Plain words, still readable by a 6-year-old.

### Behaviour rules, with sources

| Rule | Source | Where |
|---|---|---|
| Prompt "Type the letter/word/text to start!" while waiting; hides on the first correct key | FR6, EXPERIENCE.md Voice and Tone | `Hud.setup`, `hide_start_prompt` |
| Timer counts **down** from the full length; shows full length while waiting | EXPERIENCE.md stats-column, Run states | `update_clock` (`ceilf(remaining)`) |
| Live WPM hidden for the first 5 s of run time, then 1 Hz | FR8 | `update_clock` with `LIVE_WPM_*` |
| Keys and Errors update the same frame as each judgment | EXPERIENCE.md stats-column | `RunFrame` handlers, synchronous |
| Wrong key: glyph shakes 0.2 s, ±2 px, quiet bonk ≤ 1 per 150 ms; nothing else moves; no colour change | FR2, EXPERIENCE.md Game Feel, DESIGN.md target display, mock frame C | `Hud.shake_target`, `AudioManager` throttle |
| Errors before the first key count (and shake + tick) | 2.2 judgment rules | unchanged |
| Caps Lock hint on suspected, off on cleared; never blocks | FR5, EXPERIENCE.md caps-lock-hint | `Hud.set_caps_hint` |
| Brain counter in every level, run total from the level, never `PlayerData` | D15, architecture "Brains during a run" | `RunFrame` → `Hud.set_brains` |
| HUD never hides or fades during play; same band in every level | EXPERIENCE.md HUD & Diegetic UI | no per-level branches |
| Mouse only for the pause button; Space/Enter never press anything | EXPERIENCE.md Input, 2.1 deferral | `FOCUS_NONE` everywhere |
| No information by sound alone (the bonk always has the shake) | EXPERIENCE.md Accessibility | both in the reject handler |
| No red, no "Wrong!", no screen shake | EXPERIENCE.md Voice/Tone and Game Feel, DESIGN.md Don'ts | review |

### Existing code: current state, what changes, what must be preserved

- **`scripts/run/run_frame.gd`** (2.4, committed in `1970468`): `_start_level` builds level → RNG → source → `TypingSession` → `configure` → connects `char_typed`, `run_started`, level `char_accepted`/`char_rejected`, `end_requested`. `_process` advances the clock every frame and handles timer end and the outro. `navigate` seam; `_navigate_when_idle` for the Router's transition; `_fail_to_menu` frees the level. **Add** the HUD calls listed in Task 6 only. **Preserve** state machine, clamp, single result, getters, validation of `end_requested` reasons, `capture_keys` pairing, and every `test_run_frame.gd` test.
- **`scenes/run/run_frame.tscn`**: `RunFrame` (Control, full rect) → `Background` (ColorRect night, mouse ignore) → `%LevelHost` (Node2D) → `%TypingInput`. **Add** `%Hud` between `%LevelHost` and `%TypingInput`.
- **`scripts/autoloads/audio_manager.gd`** (1.4): `_try_play_sfx(id)` returns the player or `null`; drops before `unlock()`; `_get_playable_cue` warns on unknown ids; pool of 8 + round-robin steal; `PROCESS_MODE_ALWAYS`. **Add** the per-cue throttle only. **Preserve** everything else and every `test_audio_manager.gd` test (they build cues in code with `min_interval_s` defaulting to 0, so they stay unthrottled). Known gap (deferred 1.4): the steal path isn't exercised headless; the throttle doesn't need it.
- **`scripts/resources/audio_cue.gd`**: `id`, `stream`, `volume_db`. **Add** `min_interval_s` (default 0 keeps the existing `.tres` valid).
- **`data/audio/audio_library.tres`**: cues `sfx_ui_click`, `mus_menu` as sub-resources. **Add** `sfx_wrong_key`.
- **`tools/gen_placeholder_audio.gd`**: dev tool (`extends SceneTree`) that writes the click and the menu loop; `_save()` writes 16-bit mono WAV at 22050 Hz. **Add** one generator function and path; keep the non-zero exit on failure.
- **`scripts/levels/test_level/test_level.gd`**: shows its own `%LetterLabel` and `%StatusLabel` ("Brains: N", "Time!") in the playfield. Leave it; the HUD now shows the official target and counter. Make sure the level's labels sit in the 256 px playfield (they are centred above the band).
- **`scripts/core/game_constants.gd`**: has `END_REASON_*` and `MIN_WPM_SECONDS`. **Add** the three constants of Task 2.
- **`scripts/typing/stats_calculator.gd`** (2.3): `wpm(keys, seconds, completed_words=0)` floors, returns 0 below `MIN_WPM_SECONDS`; `format_time(seconds)` floors to `m:ss`. Reuse; don't duplicate formulas in the HUD.
- **`scripts/typing/typing_input.gd`**: emits `caps_lock_suspected` / `caps_lock_cleared`; `active` gate. Not modified.
- **`data/ui_theme.tres`**: `default_font = press_start_2p.ttf`, `default_font_size = 16`; set as the project theme. HUD labels inherit it.

### Signal and call order inside one key (after this story)

```
correct key:  TypingInput.char_typed → RunFrame → session.judge
              → run_started (first key) → RunFrame: RUNNING, level.on_run_started, Hud.hide_start_prompt
              → char_accepted → level.on_char_accepted → RunFrame._on_session_char_accepted → Hud.set_counts
              → target_changed → Hud.show_target
              (level may emit brains_earned_changed inside on_char_accepted → Hud.set_brains)
wrong key:    → char_rejected → level.on_char_rejected → RunFrame._on_session_char_rejected
              → Hud.set_counts, Hud.shake_target, AudioManager.play_sfx(&"sfx_wrong_key")
every frame:  RunFrame._process → clock.advance → Hud.update_clock(elapsed, keys) → (timer end / outro)
```

All synchronous; `handle_key()` returns after everything above has run (except the per-frame line).

### Testing approach

- Disabled instances (`PROCESS_MODE_DISABLED`) and hand-driven `_process(delta)`, as in `test_run_frame.gd`; no `await`, no real frames needed. The shake is computed in `_process` precisely so it can be tested this way.
- Never assert on the live `AudioManager` autoload (`test_audio_manager.gd` header rule); throttle tests use a fresh instance with the `now_msec` seam. In run-frame tests the live `AudioManager` is usually still locked, so `play_sfx` is a silent no-op; don't assert on it there.
- Font checks: get the theme font with `ThemeDB.get_project_theme().default_font` or `load("res://data/ui_theme.tres").default_font`, then `font.has_char(code)`.
- Rect checks after `add_child`: anchors/offsets are applied immediately for a `Control` in the tree; use `get_rect()` relative to the HUD root (a full-rect 640×360 control in the test viewport). If GUT's viewport isn't 640×360, give the instance an explicit `size = Vector2(640, 360)` and compare positions relative to it.
- Every test must be able to fail (Task 7.3). Contract errors (`set_count(-1)`) log `Log.error`; assert with `assert_push_error("[ERROR][ui]")`.

### Coding conventions (architecture)

- Static typing everywhere (`untyped_declaration = Error`); typed `Dictionary[...]` for the prompt table and the throttle map.
- "Call down, signal up": `RunFrame` calls `Hud` methods; `Hud` only emits `pause_pressed`. The HUD takes nothing from autoloads.
- Logging: tag `&"ui"` for widget contract issues, `&"audio"` stays in `AudioManager`. Nothing logged per key or per frame.
- `.tscn`: `unique_name_in_owner = true` for every `%Node` referenced; write by hand or with the Godot MCP scene tools, then `--import`.
- Colours: use the DESIGN.md hex values (`ink #1E1428`, `night #2B1D3F`, `wood-dark #5A3218`, `wood #8A5228`, `parchment #F6E7C1`, `chalkboard #24402F`, `chalk #F4F1E4`, `chalk-dim #A8C4A6`, `candy-yellow #FFD23F`, `art-brain-pink #F29AB8`, `art-brain-shade #C9607F`). No colour outside the palette.

### Project Structure Notes

- Matches the architecture tree: `scenes/run/hud.tscn`, `scripts/run/hud.gd`, `scenes/ui/brain_counter.tscn`, `scripts/ui/brain_counter.gd` (first files in `scripts/ui/` and `scenes/ui/`).
- The sketch goes next to the UX spines (`ux-designs/.../sketches/`), where Story 5.0 will look for the "approved layout sketches from Stories 2.5 … and 4.4".
- Variance: HUD labels and widths differ from DESIGN.md's `[ASSUMPTION]` starting values because of the chosen font; recorded in the sketch and `deferred-work.md` (DESIGN.md itself is a planning artifact; don't edit it in this story, but list the sketch as the override).

### Previous story intelligence (2.4, 2.3, 2.2, 2.1)

- **2.4:** `RunFrame` tests use a `navigate` recorder and disabled instances; `_process` is driven by hand; `%TypingInput.handle_key(event)` drives input. The GUT trap: a preload constant whose name starts with `Test` is treated as an inner test class (rename it, e.g. `LevelScript`). The web debug build + built-in browser pane worked for manual checks (`.claude/launch.json` `web-debug`; the pane's `type` action sends no keydown events, use `key` presses).
- **2.3:** `StatsCalculator` formulas floor; live WPM must reuse them.
- **2.2:** emit order `run_started → char_accepted → target_changed`.
- **2.1:** run-screen controls must be `FOCUS_NONE`; Caps Lock streak counts Shift-held capitals too (by decision).
- Review habits: red run first, one-change mutation checks, `##` docs everywhere, exact assertions, contract `assert`s never called in tests.

### Git intelligence

- One commit per story: `Story 2.5: shared hud with wrong-key feedback` if Smuck asks. 2.3 and 2.4 are committed (`1b36f6a`, `1970468`); the tree was clean when this story was written.
- No new dependencies: built-in Godot APIs and GUT only.

### Latest tech notes (Godot 4.7.2)

- `Font.has_char(char: int) -> bool` checks glyph coverage.
- `Label` line height comes from the font plus `theme_override_constants/line_spacing`; for exact 24 px lines with a 24 px Press Start 2P, check `get_line_height()` in a test rather than assuming.
- `Control.focus_mode = FOCUS_NONE` keeps a `Button` clickable by mouse but out of keyboard focus; Space/Enter only press a focused button.
- `Time.get_ticks_msec()` is monotonic and keeps counting while the tree is paused (fine for the audio throttle, which is not run time).
- `AudioStreamWAV.save_to_wav(path)` writes the placeholder (already used by the tool).

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md` (Typing Pipeline & Level Contract, "Brains during a run", Communication Patterns, Audio, Consistency Rules, Architectural Boundaries) and the UX spines `UX/DESIGN.md` and `UX/EXPERIENCE.md` (spines > mocks > sketches). Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; Godot MCP server and the built-in browser pane for the visual check.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.5: Shared HUD with Wrong-Key Feedback] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR2, FR5, FR6, FR8, FR14; NFR7, NFR8, NFR9.
- [Source: UX/DESIGN.md (ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md)#Colors, #Typography, #Layout & Spacing, #Components → HUD; front-matter tokens `spacing.hud-*`, `components.hud-band`, `stats-column`, `brain-counter`, `caps-lock-hint`, `pause-button`] — look and starting widths.
- [Source: UX/EXPERIENCE.md#Voice and Tone, #Component behaviour (stats-column, caps-lock-hint, brain-counter, hud-band), #Run states, #HUD & Diegetic UI, #Game Feel & Juice, #Accessibility] — behaviour.
- [Source: UX/mockups/key-run-hud.html] — frames A (letter, running) and C (wrong-key shake).
- [Source: docs/art-style-sheet.md#4. Font] — Press Start 2P, 8 px grid, sizes 16/24/32.
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract, #Communication Patterns, #Project Structure, #Configuration] — call-down rule, brains during a run, file locations, where numbers live.
- [Source: _bmad-output/implementation-artifacts/2-4-run-frame-level-contract-and-test-level.md] — RunFrame API, test helpers, browser-pane workflow.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — 2.1 FOCUS_NONE, 2.4 `brains_earned_changed`, 1.4 audio steal-path note.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **Sketch approved by Smuck, 2026-10-04: "Approve as drawn"** (`_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/hud-band-2-5.md`, status line updated). Final widths: pet 0-64, target area 64-376 (312 px), stats 376-552 (176 px; labels at x 380 w 96, values at x 480 w 64, rows y 270/290/310/330), brain counter (556, 264, 80, 28). Approved deviations: label "Keys", stats 176 px, prompt and Caps hint above the band, 12 chars per paragraph line, WPM placeholder en dash, 3-digit brain counter.
- Font facts measured in Godot before sketching: Press Start 2P advance = font size at 16/24/32 px (spaces included), line height = font size, and the font has U+2013, so the placeholder is `–` (5.7).
- Built differently from the sketch table in one place: the pause button is two 4x12 ink bars, not the text "II" (16 px "II" is 32 px wide and does not fit 24 px). Rect, margins and behaviour are as approved.
- Baseline: 352 tests (350 at 2.4 dev + 2 from the 2.4 review). Red run (8.1): 366 tests, 352 passing, 14 failing (6 new throttle tests: `Invalid assignment of property 'now_msec'`; 1 library test; 7 new run-frame HUD tests: `%Hud` null). Parse errors for the not-yet-existing files: `Preload file "res://scenes/run/hud.tscn" does not exist`, `"res://scripts/run/hud.gd"`, `"res://scenes/ui/brain_counter.tscn"`, `Could not find type "BrainCounter"`. Green: 36 scripts, 401 tests, 401 passing on the first run; no `Parse Error`, `Failed to load script`, `SCRIPT ERROR` or GUT warning.
- `test_paragraph_lines_are_24_px`: with `line_spacing` overridden to 0, `Label.get_line_height()` is exactly 24 at font size 24.
- Placeholder sound: `tools/gen_placeholder_audio.gd` now also writes `sfx_wrong_key.wav` (70 ms, 220 Hz triangle, 3 ms attack, fast decay, peak 0.35; 1543 samples). The re-run rewrote the click and the menu loop byte-identically (no git change).
- Mutation checks (7.3), one change at a time, run by a script that restores and compares each file byte for byte:
  - (a) `CONNECT_DEFERRED` on `char_rejected` -> HUD handler: `test_wrong_key_updates_hud_in_the_same_call` fails.
  - (b) live WPM rebuilt every call: `test_live_wpm_rule` fails (at 5.5 s with 30 keys it shows 65 instead of holding 24).
  - (c) WPM shown before 5 s: `test_live_wpm_rule`, `test_process_drives_timer_and_live_wpm`, `test_waiting_values`, `test_setup_resets_a_previous_run` fail.
  - (d) no timestamp check in `AudioManager`: `test_throttle_drops_plays_inside_the_interval`, `test_dropped_calls_do_not_restart_the_gap` fail.
  - (e) dropped calls stamp the time too: the same two tests fail. Note: the story expected the `t=300` case to catch it; the `t=150` assertion fails first, because stamping the dropped calls at 100 and 149 pushes the next allowed play past 150.
  - (f) offset left at the last pattern value when the shake ends: `test_shake_moves_only_the_glyph_and_returns_to_zero`, `test_second_wrong_key_restarts_the_shake`, `test_new_target_during_shake_ends_at_zero` fail.
  - (g) `%PauseButton.focus_mode = FOCUS_ALL`: `test_focus_and_mouse_rules` fails.
- Boundary greps (8.3): no `await` in `hud.gd`, `brain_counter.gd`, `run_frame.gd`; no autoload names in `hud.gd` / `brain_counter.gd` (a brain-counter doc comment naming PlayerData was reworded); no `CONNECT_DEFERRED` / `call_deferred` in `scripts/run/`; no `corner_radius` in `hud.tscn`, `brain_counter.tscn`, `run_frame.tscn`.
- 8.4 visual check, web debug export in the built-in browser pane (`web-debug` on :8060):
  - (a) waiting: target sign with the letter centred in the target area, "Type the letter to start!" on an ink strip above the band, Timer 2:00, Keys 0, WPM `–`, Errors 0, brain counter 0, empty pet cushion, pause button top-right. Matches the sketch and mock frame A's arrangement; the look is placeholder chrome (flat fills, no 9-slice, no hands, no pet), as expected before Story 5.0.
  - wrong key while waiting: Errors 1, prompt stays, target unchanged. The 0.2 s shake ended before a screenshot could land (covered by tests).
  - (b) running: prompt gone; after 5 s of run time WPM appeared (7), the timer counted down (1:58, 1:55, 1:52); the 4th correct key showed 1 on the HUD brain counter (and the test level's own "Brains: 1").
  - (d) Caps Lock: the pane's `shift+q` sends `key: "q"` (lowercase, shiftKey true), so it cannot produce Shift capitals; bare `Q`, `W`, `Z` arrive as capitals without Shift (like Caps Lock on) and showed "Caps Lock is on" (candy-yellow, ink text, above the band); a lowercase `p` then hid it and counted as Keys 5.
  - The test level's `%StatusLabel` touches the hint by 4 px (debug level only; in `deferred-work.md`).
- 8.5 listen check: **Smuck, 2026-10-04: "Sounds right"** (quiet, short, capped when mashing, no tick on correct keys), on the same web debug build.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- Layout sketch written, approved by Smuck as drawn, recorded in the sketch file and above.
- `GameConstants`: `LIVE_WPM_DELAY_S` (5.0), `LIVE_WPM_INTERVAL_S` (1.0), `WRONG_KEY_SHAKE_S` (0.2). `SHAKE_PX` (2.0) lives in `hud.gd`.
- `AudioCue.min_interval_s` plus a per-cue throttle in `AudioManager._try_play_sfx` (`now_msec` test seam, `_last_played_msec`; only actual plays stamp). New cue `sfx_wrong_key` (-6 dB, 0.15 s) with a generated CC0 placeholder bonk and its credit line.
- `BrainCounter` widget (`class_name BrainCounter`, `scenes/ui/brain_counter.tscn`): wood-dark pill, placeholder pink icon, 16 px count; `set_count()` logs and shows 0 for negatives; nothing focusable or mouse-blocking.
- `Hud` (`scenes/run/hud.tscn`, `scripts/run/hud.gd`): band, pet cushion, target sign sized by mode (letter/word one 32 px line, the sign grows with the word; paragraph two 24 px lines), hands area, stats column, brain counter, start prompt per mode, Caps Lock hint, pause button (`pause_pressed`). Countdown timer with `ceilf` (counts up without a duration), live WPM hidden for 5 s then 1 Hz, shake as a deterministic four-slice pattern in `_process`, strings rebuilt only on change. All controls `FOCUS_NONE`; all but the pause button ignore the mouse.
- `RunFrame` drives the HUD: `setup` after the session exists; `target_changed` -> `show_target`; `char_accepted` / `char_rejected` -> counts (rejects also shake and play `sfx_wrong_key`); `brains_earned_changed` -> `set_brains`; Caps Lock signals -> hint; prompt hidden on the first key; `update_clock` every frame; HUD hidden after a failed load. All plain synchronous connections, made after the level's. `pause_pressed` stays unconnected (2.7).
- Tests: new `test_hud.gd` (29), `test_brain_counter.gd` (6); `test_audio_manager.gd` +6, `test_audio_library.gd` +1, `test_run_frame.gd` +7. Suite 352 -> 401.
- `deferred-work.md`: new "dev of story-2-5" section; the 2.1 `FOCUS_NONE` note and the 2.4 `brains_earned_changed` note struck through as resolved.

### File List

- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/hud-band-2-5.md` (new, approved sketch)
- `scripts/core/game_constants.gd` (modified: three FR constants)
- `scripts/resources/audio_cue.gd` (modified: `min_interval_s`)
- `scripts/autoloads/audio_manager.gd` (modified: per-cue throttle, `now_msec` seam)
- `data/audio/audio_library.tres` (modified: `sfx_wrong_key` cue)
- `tools/gen_placeholder_audio.gd` (modified: wrong-key bonk)
- `assets/audio/sfx/sfx_wrong_key.wav` (new) + `.wav.import`
- `assets/audio/CREDITS.md` (modified)
- `scripts/ui/brain_counter.gd` (new) + `.uid`
- `scenes/ui/brain_counter.tscn` (new)
- `scripts/run/hud.gd` (new) + `.uid`
- `scenes/run/hud.tscn` (new)
- `scripts/run/run_frame.gd` (modified: HUD wiring)
- `scenes/run/run_frame.tscn` (modified: `%Hud` instance)
- `tests/unit/test_hud.gd` (new) + `.uid`
- `tests/unit/test_brain_counter.gd` (new) + `.uid`
- `tests/unit/test_audio_manager.gd` (modified)
- `tests/unit/test_audio_library.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-5-shared-hud-with-wrong-key-feedback.md` (this story)

## Change Log

- 2026-10-04: Story 2.5 implemented: approved HUD layout sketch, shared HUD band and brain counter widget, RunFrame wiring, per-cue audio throttle and the wrong-key tick, three FR constants; 49 new tests (suite 352 -> 401), mutation-checked; visual check in the browser pane; listen check approved by Smuck. Status -> review.
