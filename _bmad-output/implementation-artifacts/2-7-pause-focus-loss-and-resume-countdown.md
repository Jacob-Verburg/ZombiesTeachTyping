---
baseline_commit: cc90031b49a5c3a169a4bc46b5b47eb3d76f4370
---

# Story 2.7: Pause, Focus Loss and Resume Countdown

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the game to freeze when I press Esc or switch tabs, and count me back in,
so that I never lose time when something interrupts me.

## Acceptance Criteria

1. **Pause.** Given a run in `RUNNING` (or `WAITING_FIRST_KEY`), when Esc (pressed, not echo) or the HUD pause button (`Hud.pause_pressed`) is used, then the state becomes `PAUSED`, the clock stops, the tree is paused, and the pause panel shows a "Paused" title, **Resume** (keyboard focus), **Quit to Menu**, and **Music** and **Sound** toggles (FR10, GDD M3). Esc and the button do nothing in `ENDING`, `DONE` or after Quit.
2. **Toggles.** The Music and Sound toggles work like the menu ones will: each mutes/unmutes the matching bus (`AudioManager.set_music_muted` / `set_sfx_muted`) **and** saves through `PlayerData.set_setting(&"music_on" / &"sound_on", on)`; each time the panel opens it shows the saved settings (FR46).
3. **Focus loss.** Given a run in `RUNNING` or `COUNTDOWN`, when `WebPlatform.focus_lost` fires (or `visibility_hidden`; one tab switch fires both), then the run goes to `PAUSED`; a countdown in progress is cancelled; a second signal while already paused changes nothing (FR11, FR12; 1.5 deferral).
4. **Resume countdown.** Given the pause panel, when Resume is chosen (button, Enter on it, or Esc on the panel), then the panel closes and a 3-2-1 countdown shows at 0.5 s per number while the tree **stays paused** and typing is rejected; when it ends, the run returns to the state it was paused from, and the tree is unpaused **only then** (FR12; architecture State Management).
5. **Quit.** Given the pause panel, when Quit to Menu is chosen, then the brains the level earned so far are committed through `PlayerData.add_brains(level.get_brains_earned())` (which requests a save; FR52), no completion bonus is given, no `RunResult` is built or recorded, and the run navigates to `MAIN_MENU` exactly once (FR13). The Router unpauses the tree after its swap.
6. **Waiting stays waiting.** Given the run is waiting for its first key, when it is paused and resumed, then it is back in `WAITING_FIRST_KEY` with the clock at 0 and the start prompt still shown, and only the first correct key starts the clock (FR6).
7. **Frozen world.** While `PAUSED` or `COUNTDOWN`, the clock, the level, the HUD (shake) and the hands (pulse) do not advance and receive no input, because they pause with the tree; only the pause panel and the countdown run (`PROCESS_MODE_WHEN_PAUSED`). `capture_keys` stays true for the whole run, pause included (2.5/2.6 deferrals).
8. **Clean resume.** After the countdown no pause-panel button keeps keyboard focus (so Space/Enter typed in the run can never press one), and the Caps Lock hint and streak are reset (2.1 deferral).
9. **Tests.** New `tests/unit/test_pause_panel.gd` and `tests/unit/test_countdown.gd`, additions to `tests/integration/test_run_frame.gd` and `tests/unit/test_typing_input.gd`, cover every rule above and pass, and the full suite has no regressions (confirm the starting count in the first run; 436 at the end of 2.6 dev plus the 2.6 review additions).

## Tasks / Subtasks

- [x] **Task 1: Constants (AC: 4)**
  - [x] 1.1 `scripts/core/game_constants.gd`: `COUNTDOWN_FROM: int = 3` and `COUNTDOWN_STEP_S: float = 0.5`, each with a `##` comment citing FR12 / GDD M3. Fixed GDD rules, like `WRONG_KEY_SHAKE_S`.

- [x] **Task 2: `Countdown` (AC: 4, 7)**
  - [x] 2.1 `scenes/run/countdown.tscn` + `scripts/run/countdown.gd` (architecture paths; no `class_name`, like `hud.gd`). Root `Countdown` (`Control`, full rect 640×360, `process_mode = PROCESS_MODE_WHEN_PAUSED`, `visible = false`, `mouse_filter = IGNORE`, `focus_mode = NONE`). Child `%NumberLabel`: 64 px Press Start 2P, candy-yellow `#FFD23F`, 1 px ink `#1E1428` outline (`theme_override_constants/outline_size = 2` gives about 1 px at this font; check visually, or draw a 2 px ink shadow label behind it as DESIGN.md asks "1 px ink outline plus a 2 px ink shadow"), centred on the **playfield** (x 320, y 128: the band below stays visible).
  - [x] 2.2 API, `##`-documented: `signal finished`; `func start(from: int, step_s: float) -> void` (visible, shows `str(from)`); `func cancel() -> void` (hidden, no signal); `func is_running() -> bool`; `func get_shown_number() -> int` (0 when hidden; test seam).
  - [x] 2.3 Driven by `_process(delta)` with a remaining-time counter (no `Tween`, no `SceneTreeTimer`, no `await`): show `from` for `step_s`, then `from - 1`, … `1`, then hide and emit `finished` **once**. Float sums: compare against a small epsilon like `hud.gd`'s `_SHAKE_DONE_S`. A large delta (a hitch) may skip numbers but still finishes exactly once.
  - [x] 2.4 The numbers come from the caller (`GameConstants`), not literals in `countdown.gd`.

- [x] **Task 3: `PausePanel` (AC: 1, 2, 4, 5, 8)**
  - [x] 3.1 `scenes/run/pause_panel.tscn` + `scripts/run/pause_panel.gd` (no `class_name`). Root `PausePanel` (`Control`, full rect, `PROCESS_MODE_WHEN_PAUSED`, `visible = false`). Children:
    - `%Scrim`: `ColorRect` full rect, night `#2B1D3F` at 60 % alpha (`Color(0.169, 0.114, 0.247, 0.6)`), `mouse_filter = STOP` (clicks never reach the HUD's pause button underneath). The scrim is the one sanctioned alpha blend (DESIGN.md Elevation & Depth).
    - `%Panel`: stone placeholder (`Panel` with `StyleBoxFlat` `#6F6A80`, 1 px ink border, **zero** corner radius; art is Story 5.0), centred on the canvas. Suggested rect (184, 64, 272, 232); keep everything ≥ 16 px from the canvas edge.
    - `%Title`: "Paused" (EXPERIENCE.md Voice and Tone `[ASSUMPTION]` title), 24 px, ink on a parchment `#F6E7C1` sign.
    - Four buttons in a vertical list, each 240×32, 8 px apart, 16 px labels: `%ResumeButton` "Resume", `%QuitButton` "Quit to Menu", `%MusicToggle`, `%SoundToggle`. Plain words (NFR9); "Quit to Menu" is 12 chars = 192 px at 16 px, fits.
  - [x] 3.2 Toggles: `Button` with `toggle_mode = true`. Placeholder text shows the state in words, "Music: on" / "Music: off" and "Sound: on" / "Sound: off" (10 chars max = 160 px). DESIGN.md's icon + red slash toggle is Story 4.2 / 5.0 art; note it in `deferred-work.md`. Set the pressed state with `set_pressed_no_signal` in `open()` so opening never emits a toggle.
  - [x] 3.3 Keyboard: buttons are focusable (`FOCUS_ALL`): this is a menu, and the run's typing is frozen. Up/Down move focus (default `ui_up`/`ui_down`; set `focus_neighbor_top/bottom` to wrap first ↔ last); Enter/Space press the focused button (default `ui_accept`); mouse clicks work. **Esc on the panel = Resume** (EXPERIENCE.md pause-panel `[ASSUMPTION]`): in `_unhandled_input`, `event.is_action_pressed("ui_cancel")` (as `crypt_closet.gd` does; echo-free) → `resume_chosen`, mark handled.
  - [x] 3.4 API, `##`-documented. Signals: `resume_chosen`, `quit_chosen`, `music_toggled(on: bool)`, `sound_toggled(on: bool)`. Methods: `func open(music_on: bool, sound_on: bool) -> void` (show, set toggle states and texts, `%ResumeButton.grab_focus()`); `func close() -> void` (hide **and** `get_viewport().gui_release_focus()` if focus is inside the panel, AC 8); `func is_open() -> bool`. The panel touches **no autoload**: `RunFrame` applies toggles and quits (call down, signal up).
  - [x] 3.5 A button press emits its signal only while the panel is open (guard against a stale press during close).

- [x] **Task 4: `TypingInput.reset_caps_hint()` (AC: 8)**
  - [x] 4.1 `scripts/typing/typing_input.gd`: extract the two lines `configure()` uses (`_capital_streak = 0`, `_caps_suspected = false`) into `func reset_caps_hint() -> void` (`##`: silently forgets the Caps Lock streak and hint, no signal; RunFrame calls it when a run resumes, because Caps Lock may have changed while paused). `configure()` calls it. No other change.
  - [x] 4.2 `tests/unit/test_typing_input.gd`: after 3 capitals (`caps_lock_suspected` emitted), `reset_caps_hint()` emits nothing; the next lowercase letter emits **no** `caps_lock_cleared`; 3 more capitals emit `caps_lock_suspected` again. Every existing test unchanged.

- [x] **Task 5: RunFrame pause flow (AC: 1–8)**
  - [x] 5.1 `scenes/run/run_frame.tscn`: instance `pause_panel.tscn` as `%PausePanel` and `countdown.tscn` as `%Countdown` **after** `%Hud` (drawn above it), before `%TypingInput`. Keep their explicit `PROCESS_MODE_WHEN_PAUSED` (an instance must not reset it to inherit).
  - [x] 5.2 Test seams (same style as `navigate`, assigned before `add_child`, `##`-documented):
    - `var pause_tree: Callable`: called as `pause_tree.call(paused: bool)`; default in `_ready` sets `get_tree().paused`. **Every** pause/unpause goes through it, so tests never pause GUT's tree.
    - `var player_data: Node`: default `PlayerData`; tests inject a fresh `PlayerData` wired to a temp `SaveService` (pattern in `test_player_data.gd` `_make()`), so a test never writes the real save.
  - [x] 5.3 New state: `var _resume_to: RunState`, `var _quitting: bool = false`.
  - [x] 5.4 `_request_pause()`: ignored if `_quitting`; from `RUNNING` or `WAITING_FIRST_KEY` → store `_resume_to = _state`, `_set_state(PAUSED)`; from `COUNTDOWN` → `%Countdown.cancel()`, `_set_state(PAUSED)` (keep `_resume_to`); anything else → ignore. Sources:
    - Esc: `_unhandled_input(event)`: an `InputEventKey` with `keycode == KEY_ESCAPE`, pressed, not echo → `_request_pause()` and mark handled. (`TypingInput` ignores Esc, so it reaches here; `RunFrame` freezes with the tree, so Esc while paused goes to the panel.)
    - `%Hud.pause_pressed` → `_request_pause()`.
    - `WebPlatform.focus_lost` and `WebPlatform.visibility_hidden` → `_on_web_platform_focus_lost()`: pauses only `RUNNING` and `COUNTDOWN` (AC 3), else nothing. Both signals call the same handler, so a tab switch pauses once.
  - [x] 5.5 `_set_state` enter logic (extend the existing `match`; never assign `_state` elsewhere):
    - `PAUSED`: `_clock.pause()`, `pause_tree.call(true)`, `%PausePanel.open(player_data.get_setting(&"music_on"), player_data.get_setting(&"sound_on"))`.
    - `COUNTDOWN`: `%PausePanel.close()`, `%Countdown.start(GameConstants.COUNTDOWN_FROM, GameConstants.COUNTDOWN_STEP_S)`. The tree stays paused.
    - `RUNNING`: keep `_clock.start()` + `_clock.resume()`; add `pause_tree.call(false)` (harmless on the first-key path where the tree isn't paused; the only real unpause after a countdown).
    - `WAITING_FIRST_KEY` (only reachable from `COUNTDOWN`): `pause_tree.call(false)`; the clock is **not** started.
    - On both returns from `COUNTDOWN` also call `%TypingInput.reset_caps_hint()` and `%Hud.set_caps_hint(false)` (AC 8). Do this in a small `_after_resume()` called from the countdown handler, not in the generic `RUNNING` branch (the first key also enters `RUNNING` and must not reset anything).
  - [x] 5.6 Wiring in `_start_level` (after the HUD wiring; plain `connect`, no `CONNECT_DEFERRED`): `%Hud.pause_pressed`, `%PausePanel.resume_chosen` → `_set_state(COUNTDOWN)` (only from `PAUSED`), `%PausePanel.quit_chosen` → `_quit_to_menu()`, `%PausePanel.music_toggled` / `sound_toggled` → handlers, `%Countdown.finished` → `_on_countdown_finished()` (`_set_state(_resume_to)` then `_after_resume()`), `WebPlatform.focus_lost` / `visibility_hidden` → `_on_web_platform_focus_lost`. Disconnect the two `WebPlatform` connections in `_exit_tree()` (the autoload outlives the run; Godot drops connections to a freed object, but be explicit, as `SaveService` does).
  - [x] 5.7 Toggles: `_on_pause_panel_music_toggled(on)`: `AudioManager.set_music_muted(not on)` and `player_data.set_setting(&"music_on", on)`; same for sound with `set_sfx_muted` / `&"sound_on"`. No other logic (Story 4.2 adds the same on the menu plus restore-on-launch).
  - [x] 5.8 `_quit_to_menu()`: if `_quitting` return; `_quitting = true`; `%TypingInput.active = false`; `player_data.add_brains(_level.get_brains_earned())` (`add_brains(0)` is a silent no-op; FR52 "quitting a run (brains only)"); `Log.info(&"run", "quit level=%s brains=%d" % [...])`; `_navigate_when_idle(Router.Screen.MAIN_MENU, {})`. No `RunResult`, no bonus, no `record_run` (2.8 must not record quits either). Leave the tree paused: `Router.go()` pauses for its fade and always unpauses after the swap (its comment names "Pause -> Quit to Menu"). The pause panel stays visible during the fade-out.
  - [x] 5.9 Update the `run_frame.gd` header comment (pause/countdown done; `pause_pressed` connected).
  - [x] 5.10 House rules: no `await` anywhere in `run_frame.gd`, `pause_panel.gd`, `countdown.gd`; no autoloads in `pause_panel.gd` / `countdown.gd` except `Log`; no logging per frame.

- [x] **Task 6: Tests (AC: 9)**
  - [x] 6.1 `tests/unit/test_countdown.gd` (instance disabled, `_process` by hand): hidden at start; `start(3, 0.5)` → visible, shows 3; `_process(0.5)` → 2; `_process(0.5)` → 1; `_process(0.5)` → hidden and `finished` emitted exactly once (`watch_signals`, `assert_signal_emit_count`); extra `_process` emits nothing more; `cancel()` mid-way hides and never emits; `start` again after cancel restarts at 3; one big `_process(5.0)` finishes once; `process_mode == PROCESS_MODE_WHEN_PAUSED`; label font size 64; focus/mouse ignored.
  - [x] 6.2 `tests/unit/test_pause_panel.gd` (instance disabled): hidden and `WHEN_PAUSED` by default; `open(true, false)` → visible, `%ResumeButton.has_focus()`, toggle texts "Music: on" / "Sound: off" and pressed states match, and **no** toggle signal emitted by `open`; pressing Resume / Quit (`%ResumeButton.pressed.emit()`) emits `resume_chosen` / `quit_chosen` once; a press while closed emits nothing; toggling Music emits `music_toggled(false)` and updates the text; Esc (`ui_cancel` key event fed to `_unhandled_input`) → `resume_chosen`, echo ignored; `close()` hides and no panel control keeps focus; focus neighbours wrap; every label ≥ 16 px (title 24) and every visible string's glyphs exist in the theme font (copy `test_hud.gd`'s glyph helper); `%Scrim` stops the mouse and covers 640×360.
  - [x] 6.3 `tests/integration/test_run_frame.gd` (existing `_make`/`_start` helpers plus recorders: `pause_tree` → `_paused: Array[bool]`; `player_data` → a fresh PlayerData on a temp SaveService, cleaned in `after_each`; restore `AudioManager.set_music_muted(false)` / `set_sfx_muted(false)` in `after_each`). Cases:
    - Esc while `RUNNING` → `PAUSED`, `_paused == [true]`, panel open; `_process(5.0)` leaves `get_elapsed()` unchanged; typed keys change no counts;
    - Esc echo and Esc in `ENDING` → no pause;
    - pause button (`%Hud.pause_pressed.emit()`) → `PAUSED`;
    - Resume → `COUNTDOWN`, panel closed, countdown shows 3, `_paused` still `[true]` (no unpause yet), typing still rejected; drive `%Countdown._process(0.5)` three times → `RUNNING`, `_paused == [true, false]`, clock advances again on `_process(1.0)`;
    - focus loss: call `_on_web_platform_focus_lost()` in `RUNNING` → `PAUSED`; again → still one `true` recorded and still `PAUSED`; in `COUNTDOWN` → `PAUSED`, countdown hidden, panel open; in `WAITING_FIRST_KEY` → nothing; one test emits `WebPlatform.focus_lost` itself to prove the connection (**never** emit `visibility_hidden` in tests: the live `SaveService` writes the real save on it; call the handler instead);
    - waiting: pause in `WAITING_FIRST_KEY` (Esc) → resume through the countdown → `WAITING_FIRST_KEY`, elapsed 0, start prompt visible, `_paused` ends with `false`; the next correct key → `RUNNING` and the clock starts;
    - Quit: with 4 correct keys first (test level: 1 brain), Quit → `_nav == [[MAIN_MENU, {}]]`, fake PlayerData brains +1, no `REPORT_CARD`, `get_state()` not `DONE`; a second Quit does nothing; Esc / focus loss after Quit do nothing;
    - toggles: `music_toggled(false)` → `AudioManager.is_music_muted()` true and fake `get_setting(&"music_on")` false; same for sound; reopening the panel shows the saved values;
    - clean resume: after the countdown, no pause-panel control has focus (`get_viewport().gui_get_focus_owner()` not inside `%PausePanel`); a Caps hint shown before the pause is hidden after resume;
    - structure: `%PausePanel` and `%Countdown` are `PROCESS_MODE_WHEN_PAUSED`; `%Hud`, `%LevelHost`, `%TypingInput` inherit (so they freeze with the tree).
  - [x] 6.4 Mutation checks (one change at a time, byte-for-byte restore, log each): (a) unpause on entering `COUNTDOWN` → the "still paused during countdown" test fails; (b) always resume into `RUNNING` → the waiting test fails; (c) remove the `COUNTDOWN` → `PAUSED` branch of focus loss → the countdown focus-loss test fails; (d) drop the `_quitting` guard → the double-Quit test fails; (e) skip `gui_release_focus()` in `close()` → the clean-resume focus test fails (or record honestly if hiding already releases focus, and keep the call as a second line); (f) build/send a `RunResult` on Quit → the quit test fails; (g) no `reset_caps_hint()` on resume → the Caps test fails.

- [x] **Task 7: Run and verify (AC: 9)**
  - [x] 7.1 Red first: write the new tests before the code; record parse errors and failures (GUT exits 0 on parse failures; judge by the pass count).
  - [x] 7.2 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: all pass; no `Parse Error`, `Failed to load script`, `SCRIPT ERROR`, GUT warnings. Commit `.uid` files.
  - [x] 7.3 Boundary greps: no `await` in the three scripts; no autoload names except `Log` in `pause_panel.gd` / `countdown.gd`; no `CONNECT_DEFERRED` / `call_deferred` in `scripts/run/`; `get_tree().paused` assigned only inside the `pause_tree` default; no `corner_radius` in the new scenes.
  - [x] 7.4 Web check in the built-in browser pane (web debug export, `web-debug` on :8060): start the test level, type a few letters; **Esc** → panel over the frozen run (timer stops); Resume → 3-2-1 → typing works and the timer continues from where it stopped; **pause button** click → same; switch to another pane tab and back (or blur the page) → paused on return; toggles mute/unmute (and survive a reload: check `F3` overlay or the exported save's `settings`); Quit → main menu, brains in the save went up by the run's brains (debug overlay shows brains). Esc before the first key → pause → resume → still "Type the letter to start!". Record results (and anything the pane cannot do) in the Debug Log; ask Smuck for anything only a person can check.
  - [x] 7.5 `deferred-work.md`: add "Deferred from: dev of story-2-7" (placeholder panel/countdown chrome and text toggles until 4.2/5.0; restore Music/Sound on launch is Story 4.2's AC; Windows-fallback auto-pause stays deferred, G5; Esc in browser fullscreen leaves fullscreen first, Story 5.3; Esc during the countdown is ignored by decision). Strike through as resolved: the 1.5 "focus_lost + visibility_hidden double fire" note, the 2.1 Caps streak note, the 2.4 "%Hud.pause_pressed not connected" note, the 2.5 shake and 2.6 pulse notes.

## Dev Notes

### What this story is (and isn't)

- It fills in the two run states that have existed (unused) since 2.4, `PAUSED` and `COUNTDOWN`, and adds the two overlays that run while the tree is paused: the pause panel and the 3-2-1 countdown. Pause/resume/quit are wired into `RunFrame`'s existing state machine.
- **New files:** `scenes/run/pause_panel.tscn`, `scripts/run/pause_panel.gd`, `scenes/run/countdown.tscn`, `scripts/run/countdown.gd`, `tests/unit/test_pause_panel.gd`, `tests/unit/test_countdown.gd`.
- **Updated files:** `scripts/run/run_frame.gd`, `scenes/run/run_frame.tscn`, `scripts/typing/typing_input.gd` (one extracted method), `scripts/core/game_constants.gd`, `tests/integration/test_run_frame.gd`, `tests/unit/test_typing_input.gd`, `deferred-work.md`.
- **Don't build:** run recording (2.8; Quit must stay unrecorded), the real report card (2.9), main-menu toggles and restore-on-launch (4.2), final panel/toggle art (5.0), Windows-fallback auto-pause (G5), any change to the Router, `PlayerData`, `AudioManager` or `WebPlatform`.

### State machine after this story

| From | Event | To | Enter actions |
|---|---|---|---|
| `WAITING_FIRST_KEY` | first correct key | `RUNNING` | (2.4) clock start, level, prompt hide |
| `WAITING_FIRST_KEY` / `RUNNING` | Esc, pause button | `PAUSED` | `_resume_to = from`; clock pause; tree paused; panel open |
| `RUNNING` | focus lost / tab hidden | `PAUSED` | same |
| `PAUSED` | Resume (button, Enter, Esc on panel) | `COUNTDOWN` | panel close (focus released); countdown 3-2-1; tree **still paused** |
| `COUNTDOWN` | countdown finished | `_resume_to` | tree unpaused; Caps hint reset; `RUNNING` resumes the clock, `WAITING_FIRST_KEY` leaves it at 0 |
| `COUNTDOWN` | focus lost / tab hidden | `PAUSED` | countdown cancelled; panel open |
| `PAUSED` | Quit to Menu | (stays `PAUSED`, `_quitting`) | commit brains; navigate to menu once |
| `RUNNING` | timer / `end_requested` | `ENDING` → `DONE` | (2.4) unchanged |
| any other | Esc / button / focus loss | — | ignored |

The architecture says "the tree is unpaused only on entering `RUNNING`"; returning to `WAITING_FIRST_KEY` after a pause-before-start is the one addition, and it is equally gated behind the countdown.

### Decisions in this story (flag to Smuck in the completion summary)

1. **Esc during the countdown is ignored** (neither EXPERIENCE.md nor the GDD says; the countdown is only 1.5 s, and focus loss already returns it to the panel).
2. **Focus loss while waiting for the first key does not pause** (AC: "a running run or a countdown"; nothing is ticking, and the kid comes back to the same "Type the letter to start!").
3. **Esc and the pause button do pause while waiting** (the epic's last AC needs "paused and resumed" in that state).
4. **The Caps Lock hint resets on resume** (Caps Lock may have been switched while away; 3 more capitals bring it back).
5. **Toggles show their state in words** ("Music: on/off") until the icon art.

### Why the pause runs through `get_tree().paused`

- `RunFrame`, the level, the HUD (shake), `ZombieHands` (pulse) and `TypingInput` all inherit their process mode, so pausing the tree freezes animation, the clock feed and input in one move. The 2.5 and 2.6 reviews deferred exactly this ("if 2.7 pauses through RunFrame state instead of the tree, the shake/pulse keeps animating").
- The panel and the countdown are `PROCESS_MODE_WHEN_PAUSED`, so they get `_process` and input only while the tree is paused (architecture State Management).
- The `AudioManager` is `PROCESS_MODE_ALWAYS`: music keeps playing while paused (and the Router fade). That is fine; the toggles control it.
- The debug overlay is `PROCESS_MODE_ALWAYS` and reads F-keys in `_input`; unaffected.
- In tests, everything is driven by hand and `pause_tree` is a recorder, so GUT's own tree is never paused.

### Existing code: current state, what changes, what must be preserved

- **`scripts/run/run_frame.gd`** (2.4–2.6, at `cc90031`): `RunState` already lists `PAUSED`/`COUNTDOWN`; `_set_state` handles `RUNNING` (`start()` + `resume()`), `ENDING` (clock pause, input gate off, Caps hint off, `clear_hands()`, outro), `DONE` (`_send_result`). `_process` advances the clock **every frame** and lets `RunClock` ignore it while paused, feeds `%Hud.update_clock`, ends on the timer, runs the outro. Seams `navigate`, `_navigate_when_idle` (waits for the Router's transition). `_on_typing_input_char_typed` judges only in `WAITING_FIRST_KEY`/`RUNNING`. **Add** the pause flow only. **Preserve** everything else and all 51 + review tests in `test_run_frame.gd`.
- **`scripts/run/hud.gd`**: `signal pause_pressed` (emitted by `%PauseButton`, `FOCUS_NONE`, the only mouse-stopping HUD control); `set_caps_hint(bool)`; `_process` drives the shake. Not modified.
- **`scripts/run/zombie_hands.gd`**: `_process` drives the pulse. Not modified.
- **`scripts/typing/typing_input.gd`**: `configure()` resets the Caps streak silently; ignores Esc (`IGNORED_KEYCODES`); `active` gate. Add `reset_caps_hint()` only.
- **`scripts/autoloads/router.gd`**: `go()` sets `get_tree().paused = true` for the fade, swaps, then sets it false ("A new screen never starts paused, even when go() came from a paused run (Pause -> Quit to Menu)"). Not modified.
- **`scripts/autoloads/player_data.gd`**: `add_brains(amount)` (0 → no-op, negative → logged error), `get_setting` / `set_setting` for `&"music_on"` / `&"sound_on"` (unknown key → logged error), `settings_changed`, coalesced `request_save()`. Test seam `save_service`. Not modified.
- **`scripts/autoloads/audio_manager.gd`**: `set_music_muted`, `set_sfx_muted`, `is_music_muted`, `is_sfx_muted` (global `AudioServer` bus state: tests must restore it). Not modified. Nothing applies the saved settings at launch yet (Story 4.2 AC: "the setting is restored on the next launch").
- **`scripts/autoloads/web_platform.gd`**: `focus_lost` (window blur) and `visibility_hidden` (document hidden), web only. A tab switch fires both. `SaveService` listens to `visibility_hidden` and writes immediately. Not modified.
- **`scripts/screens/crypt_closet.gd`**: uses `event.is_action_pressed("ui_cancel")` in `_unhandled_input` for Esc; follow it in the panel.

### UX spec (no mock exists for pause or countdown; the spines rule)

- EXPERIENCE.md: pause-panel "Pre-focus **Resume**. Arrows/Enter/click. Esc on the panel = Resume `[ASSUMPTION]`. Quit to Menu keeps brains, awards no bonus, records no run"; countdown "3-2-1 at 0.5 s each; world stays frozen; all typing rejected; focus loss returns to Paused"; pause-button "Click only (mouse); same as Esc. Not keyboard-focusable"; Run states "Paused (Esc / button / tab blur): world and clock frozen; pause-panel over scrim; keys still swallowed"; Voice and Tone "Resume · Quit to Menu · Music · Sound; panel title "Paused" `[ASSUMPTION]`"; Accessibility "Interruptions are free: auto-pause on tab/window blur; 3-2-1 countdown before input resumes"; Windows-fallback auto-pause deferred (G5).
- DESIGN.md: pause panel = **stone** panel over a **night scrim at 60 %** (the only alpha in the UI), title sign, Resume, Quit to Menu, Music and Sound toggles; countdown = **64 px candy-yellow numerals with a 1 px ink outline (plus a 2 px ink shadow), centred on the playfield**; toggles: icon + slash later; 16 px text floor; stepped corners from 9-slice art later (no `StyleBoxFlat` radius now).
- Story 5.0 lists "the pause panel" among the final-art items; the placeholder only has to be clean and readable.

### Testing approach

- Same pattern as 2.4–2.6: disabled instances, `_process(delta)` and signal emits driven by hand, state read through getters.
- Never touch real global state in tests: `pause_tree` recorder (GUT's tree), `player_data` seam (the real save), restore bus mutes in `after_each`, never emit `WebPlatform.visibility_hidden`.
- The `navigate` recorder already keeps the Router out; Quit asserts on `_nav`.
- `Log.info` on Quit prints; no assertion needed. `PlayerData` errors (unknown setting) would `push_error`; there should be none.
- Every test must be able to fail (Task 6.4); record each mutation result honestly, including ones that don't fail and why.

### Coding conventions

- Static typing everywhere (`untyped_declaration = Error`), including lambda parameters (`func(paused: bool) -> void:`).
- `##` docs on every public member and seam; `_on_<node>_<signal>` handler names (`_on_pause_panel_resume_chosen`, `_on_countdown_finished`, `_on_web_platform_focus_lost`); all state changes through `_set_state`.
- Logging: `&"run"` for pause/resume/quit at INFO or DEBUG (state changes already log at DEBUG in `_set_state`); nothing per frame.
- Colours from DESIGN.md: ink `#1E1428`, night `#2B1D3F`, stone `#6F6A80`, stone-light `#BDB6C4`, parchment `#F6E7C1`, wood `#8A5228`, pumpkin-light `#FFA94A` (focused button fill), candy-yellow `#FFD23F`, chalk `#F4F1E4`. A focused panel button should look focused (pumpkin-light fill or a 2 px candy-yellow ring); default `Button` theme focus is acceptable as a placeholder if it is visible.

### Project Structure Notes

- Matches the architecture tree: `scenes/run/pause_panel.tscn`, `scenes/run/countdown.tscn`, `scripts/run/pause_panel.gd`, `scripts/run/countdown.gd`.
- No conflicts. The `player_data` and `pause_tree` seams follow the existing `navigate` / `save_service` / `now_msec` seam pattern.

### Previous story intelligence (2.6, 2.5, 2.4)

- **2.6 review:** a cue that should stop at run end must be cleared explicitly (`clear_hands()` on `ENDING`); same thinking here: the panel must release focus and the Caps hint must reset on resume.
- **2.5 review:** state that outlives its trigger (Caps hint through the outro) needs an explicit reset and a test.
- **2.4:** `navigate` recorder, `_navigate_when_idle` for the Router's transition (Quit uses it), disabled instances, browser-pane web check (`web-debug`); the pane's `type` action sends no keydown events, use `key` presses; the pane can switch tabs to trigger blur.
- GUT trap: a preload constant named `Test…` is treated as an inner test class.
- Habits: red run first; one-change mutation checks with byte-for-byte restore; `##` docs; exact assertions.

### Git intelligence

- One commit per story; latest `cc90031 Story 2.6: green zombie hands finger guide`. Use `Story 2.7: pause, focus loss and resume countdown` if Smuck asks. The working tree holds only this story file and the sprint-status change when this story was written.
- No new dependencies.

### Latest tech notes (Godot 4.7.2)

- `Node.process_mode`: `PROCESS_MODE_WHEN_PAUSED` processes (and receives input) only while `SceneTree.paused` is true; an explicit mode on a child overrides the parent's.
- `SceneTree.paused = true` stops `_process`, `_physics_process` and input for pausable nodes; signals and direct calls still work (the countdown's `finished` reaches `RunFrame` while it is paused).
- `Viewport.gui_release_focus()` drops keyboard focus; `Viewport.gui_get_focus_owner()` returns the focused control (test helper).
- `BaseButton.set_pressed_no_signal(bool)` sets a toggle without emitting `toggled`.
- `InputEvent.is_action_pressed("ui_cancel")` is false for echo events unless `allow_echo` is passed.
- `Label` outline: `theme_override_constants/outline_size` and `theme_override_colors/font_outline_color`.

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md` (State Management, Screen Flow, Communication Patterns, State Patterns, Web Platform `capture_keys` lifecycle, Project Structure) and the UX spines `UX/DESIGN.md` / `UX/EXPERIENCE.md`. Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; the built-in browser pane for the web check.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.7: Pause, Focus Loss and Resume Countdown] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR6, FR10, FR11, FR12, FR13, FR46, FR52; NFR9.
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#M3. Pause] — Esc/button, auto-pause, 3-2-1 at 0.5 s; quitting rules.
- [Source: _bmad-output/game-architecture.md#State Management, #State Patterns] — `RunState`, `_set_state` example (`PAUSED` → tree paused, `COUNTDOWN` → `%Countdown.start(3, 0.5)`), `PROCESS_MODE_WHEN_PAUSED`.
- [Source: UX/EXPERIENCE.md#Component behaviour (pause-button, pause-panel, countdown), #Run states, #Voice and Tone, #Accessibility] — behaviour and copy.
- [Source: UX/DESIGN.md#Elevation & Depth, #Components (Pause panel, Countdown, Toggle)] — look.
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — 1.5 double fire, 2.1 Caps streak, 2.4 `pause_pressed`, 2.5 shake, 2.6 pulse.
- [Source: _bmad-output/implementation-artifacts/2-6-green-zombie-hands-finger-guide.md] — latest review lessons.
- [Source: scripts/autoloads/router.gd] — pause/unpause around `go()`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline: 439 tests (436 at 2.6 dev + 3 from the 2.6 review).
- Red run (7.1): new tests and additions written first. Parse errors: `Preload file "res://scenes/run/countdown.tscn" / "pause_panel.tscn" / "countdown.gd" / "pause_panel.gd" does not exist`, `Cannot find member "COUNTDOWN_FROM" / "COUNTDOWN_STEP_S" in base "GameConstants"` (so `test_run_frame.gd` did not load either); `test_reset_caps_hint_forgets_the_streak_silently` failed at runtime. 37 scripts, 409 tests, 408 passing, 1 failing.
- First green run: 484 tests, 478 passing, 6 failing, for two reasons:
  1. The `pause_tree` recorder caught an extra `false` on the first correct key: the story's 5.5 put `pause_tree.call(false)` in every `RUNNING` entry ("harmless"). Changed `_set_state` to unpause only on the way out of `COUNTDOWN` (into `RUNNING` or `WAITING_FIRST_KEY`), so the first key never touches the tree's pause state; the tests keep the stricter expectation.
  2. `test_typing_input.gd::test_unhandled_input_forwards_key_events` (an untouched 2.1 test) failed at `assert_false(get_viewport().is_input_handled())`: my new tests call `_unhandled_input()` by hand, which marks GUT's shared viewport input as handled, and headless no real event ever clears the flag. Fixed in the new tests (not the old one): `test_run_frame.gd` and `test_pause_panel.gd` push a no-op `InputEventAction` through the viewport in `after_each`, which resets the flag.
  Then: 40 scripts, 484 tests, 484 passing; no `Parse Error`, `Failed to load script`, `SCRIPT ERROR` or GUT warning.
- Strengthened the clean-resume Caps test before the mutation checks: without the streak reset, Caps Lock stays "suspected" after resume, so the test now also asserts that 3 new capitals bring the hint back (one capital alone could not tell the difference).
- Mutation checks (6.4), one change at a time, by a script that restores each file byte for byte (baseline run first: 484/0):
  - (a) unpause on entering `COUNTDOWN`: `test_resume_counts_down_with_the_tree_still_paused`, `test_pause_while_waiting_resumes_to_waiting` fail.
  - (b) always resume into `RUNNING`: `test_pause_while_waiting_resumes_to_waiting` fails.
  - (c) no `COUNTDOWN -> PAUSED` branch on focus loss: `test_focus_loss_during_countdown_returns_to_the_panel` fails.
  - (d) no `_quitting` guard in `_quit_to_menu`: `test_quit_commits_brains_and_goes_to_the_menu_once` fails.
  - (e) `close()` without `gui_release_focus()`: **no test fails.** Godot already drops a control's keyboard focus when it is hidden, so the explicit call is a second line of defence; kept, recorded in `deferred-work.md`.
  - (f) Quit sends a `RunResult` (`_send_result()` instead of the menu navigation): `test_quit_commits_brains_and_goes_to_the_menu_once`, `test_quit_with_no_brains_is_fine` fail.
  - (g) no `reset_caps_hint()` on resume: `test_clean_resume_focus_and_caps_hint` fails.
- Boundary greps (7.3): no `await` in `run_frame.gd`, `pause_panel.gd`, `countdown.gd`; no autoload names in `pause_panel.gd` / `countdown.gd`; no `CONNECT_DEFERRED` / `call_deferred` in `scripts/run/`; `get_tree().paused` assigned only in the `pause_tree` default; no `corner_radius` in the new scenes.
- 7.4 web check (web debug export, browser pane, `web-debug` on :8060):
  - Esc before the first key: pause panel over the scrim ("Paused", Resume focused, Quit to Menu, Music: on, Sound: on); Esc on the panel resumed into a candy-yellow 3-2-1, then back to "Type the letter to start!" with Timer 2:00.
  - Esc while running: Timer 1:53 stayed at 1:53 through 4 s on the panel; clicking Music -> "Music: off" and the overlay showed "Last save: 0.5 s ago"; Resume -> countdown -> timer continued (1:51).
  - HUD pause button click: paused, the panel reopened showing the saved "Music: off"; Enter on Resume resumed.
  - Focus loss: switching pane tabs sent the page **no** blur / visibility event (no `[web] focus lost` log, no pause), so the pane cannot test a real tab switch. A `window.dispatchEvent(new Event('blur'))` went through the real JS callback: `[INFO][web] focus lost`, `RUNNING -> PAUSED`. **Smuck checked a real tab switch in Chrome/Edge on 2026-10-04: "Works"** (paused on return, timer frozen, 3-2-1 and continue).
  - Quit with 1 brain earned: log `quit level=test_level brains=1`, `[save] written (444 bytes)`, `-> MAIN_MENU`; no report card.
  - Reload: "Music: off" was still shown on the pause panel (saved setting); switched back on to leave the browser save as it was.
  - The countdown numbers draw over the test level's own big letter (debug level only).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `GameConstants.COUNTDOWN_FROM` (3) and `COUNTDOWN_STEP_S` (0.5).
- `Countdown` (`scenes/run/countdown.tscn`, `PROCESS_MODE_WHEN_PAUSED`): `start(from, step_s)`, `cancel()`, `is_running()`, `get_shown_number()`, `finished` exactly once; 64 px candy-yellow numbers with an ink outline and a 2 px ink shadow label, centred on the playfield.
- `PausePanel` (`scenes/run/pause_panel.tscn`, `PROCESS_MODE_WHEN_PAUSED`): night scrim at 60 % (stops the mouse), stone panel, "Paused" sign, Resume / Quit to Menu / Music / Sound (240 x 32, focusable, wrapping focus neighbours), Esc = Resume, toggles set without signals on `open()`, signals only while open, `close()` releases focus. No autoloads.
- `TypingInput.reset_caps_hint()` (extracted from `configure()`).
- `RunFrame`: `pause_tree` and `player_data` seams; Esc (`_unhandled_input`), the HUD pause button and `WebPlatform.focus_lost` / `visibility_hidden` (one handler, `RUNNING` / `COUNTDOWN` only) -> `PAUSED` (clock paused, tree paused, panel opened with saved settings); Resume -> `COUNTDOWN` (tree still paused) -> back to `_resume_to`, tree unpaused only when leaving the countdown, then Caps streak + hint reset; focus loss during the countdown cancels it; Quit commits `add_brains(level.get_brains_earned())`, logs, navigates once, no `RunResult`; toggles mute the bus and save the setting; `WebPlatform` connections dropped in `_exit_tree()`.
- Decisions to flag (all in `deferred-work.md`): Esc during the countdown is ignored; focus loss while waiting for the first key does not pause (Esc and the button do); the Caps hint resets on resume; toggles show their state in words.
- Tests: new `test_countdown.gd` (12), `test_pause_panel.gd` (17); `test_run_frame.gd` +15 (Esc, echo, ending, button, countdown with the tree still paused, focus loss once / during countdown / while waiting, the signal connection, pause while waiting, Quit with and without brains, toggles, clean resume, process modes); `test_typing_input.gd` +1. Suite 439 -> 484.
- `deferred-work.md`: new "dev of story-2-7" section; struck through as resolved the 1.5 double-fire note, the 2.1 Caps streak note, the 2.5 `pause_pressed` note, and the 2.5 shake and 2.6 pulse notes.

### File List

- `scripts/core/game_constants.gd` (modified: countdown constants)
- `scripts/typing/typing_input.gd` (modified: `reset_caps_hint()`)
- `scripts/run/countdown.gd` (new) + `.uid`
- `scenes/run/countdown.tscn` (new)
- `scripts/run/pause_panel.gd` (new) + `.uid`
- `scenes/run/pause_panel.tscn` (new)
- `scripts/run/run_frame.gd` (modified: pause flow, seams)
- `scenes/run/run_frame.tscn` (modified: `%PausePanel`, `%Countdown`)
- `tests/unit/test_countdown.gd` (new) + `.uid`
- `tests/unit/test_pause_panel.gd` (new) + `.uid`
- `tests/integration/test_run_frame.gd` (modified)
- `tests/unit/test_typing_input.gd` (modified: one added test)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-7-pause-focus-loss-and-resume-countdown.md` (this story)

## Change Log

- 2026-10-04: Story 2.7 implemented: pause panel, resume countdown, Esc / button / focus-loss pause through the tree, Quit to Menu committing brains, Music / Sound toggles, Caps reset on resume; 45 new tests (suite 439 -> 484), mutation-checked (one honest survivor recorded); web check in the browser pane; real tab switch checked by Smuck. Status -> review.

### Review Findings

Code review 2026-10-04 (Blind Hunter, Edge Case Hunter, Acceptance Auditor). No acceptance-criteria violations. 0 decision_needed, 3 patch, 4 defer, 23 dismissed.

- [x] [Review][Patch] `_quit_to_menu` has no state guard: only `_quitting`, so a stray `quit_chosen` outside PAUSED would commit brains. Guard with `_state == RunState.PAUSED` [scripts/run/run_frame.gd:269]
- [x] [Review][Patch] Music/Sound toggles still apply and save after Quit (no `_quitting` check) [scripts/run/run_frame.gd:_on_pause_panel_music_toggled/_on_pause_panel_sound_toggled]
- [x] [Review][Patch] Tests: Esc/focus loss "after Quit" is only tested while state is still PAUSED (ignored anyway), so the `_quitting` guard in `_request_pause` is untested. Also no test for Esc during COUNTDOWN (spec Decision 1: ignored) [tests/integration/test_run_frame.gd]
- [x] [Review][Defer] Quit soft-locks if the Router swap fails (`_quitting` stays true, tree unpaused, panel frozen) [scripts/run/run_frame.gd:269] — deferred, needs a Router failure contract (Router-wide concern)
- [x] [Review][Defer] `_exit_tree` does not unpause the tree if RunFrame is freed while PAUSED/COUNTDOWN by something other than `Router.go` [scripts/run/run_frame.gd:65] — deferred, Router.go unpauses on every swap today
- [x] [Review][Defer] Integration test `test_clean_resume_focus_and_caps_hint` passes trivially headless (nothing holds focus); mutation (e) has no failing test [tests/integration/test_run_frame.gd] — deferred, already recorded in the dev notes
- [x] [Review][Defer] New unit tests do not disable the instance / drive `_process` by hand as Tasks 6.1/6.2 say (harmless, `_process` returns early) [tests/unit/test_countdown.gd, tests/unit/test_pause_panel.gd] — deferred, cosmetic
