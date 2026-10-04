
## Deferred from: code review of story-1-1 (2026-10-02)

- `test_debug_disabled_in_release` does not verify that nothing printed; only the `is_level_enabled` seam is tested.
- ~~`Log.verbose_typing` is declared but not consumed; wire it up when per-keystroke logging arrives (Epic 2).~~ Done in 2.1: `TypingInput` logs each emitted character at DEBUG while it is on.
- `directory_rules={"res://addons": 0}` not persisted in `project.godot`; relies on the Godot 4.7 default.
- `Log.debug` evaluates its `msg` argument even when DEBUG is disabled; keep calls out of hot paths.
- GUT plugin is enabled in `project.godot`; confirm the web export (Story 1.2) excludes `addons/gut`.

## Deferred from: dev of story-1-2 (2026-10-02)

- Web letterbox bars render **black**, not night `#2B1D3F` (DESIGN.md marks night bars as `[ASSUMPTION]`). Not required by Story 1.2 AC 5. Natural home: Story 5.0 (loading page / boot splash styling); options are the HTML page background in `html/head_include` plus the engine's black-bar color.
- Firefox checks for Story 1.2 AC 4/5 (load times, 1366×768 screenshot) were skipped because Firefox isn't installed. Stories 1.5 (key capture and quick-find) and 1.7 (reload and tab-close persistence, NFR4) require Firefox: install it before those stories, and re-run the 1.2 Firefox checks then.

## Deferred from: dev of story-1-3 (2026-10-02)

- Godot imports files inside `build/` (e.g. `build/web/index.icon.png.import` exists since the 1.2 export). Harmless: `build/` is gitignored and export-excluded. Add an empty `build/.gdignore` (recreated after each clean) or export outside the project if it ever slows imports.
- ~~Font is Press Start 2P (wide, arcade look) because Pixelify Sans failed the O/0 check. If Story 1.9 or 5.0 wants a rounder face, any replacement must pass `test_ui_theme.gd` and have a native size that divides 16/24/32/64.~~ Settled at the Story 1.9 art gate (2026-10-03): Smuck approved keeping Press Start 2P.

## Deferred from: code review of 1-3-screen-router-and-title-screen (2026-10-02)

- Router sets `get_tree().paused = false` unconditionally after every transition, which clobbers any pause owned elsewhere (e.g. Story 1.5's tab-blur pause) and pauses other autoloads (AudioManager) for 0.3 s per transition. Revisit when a second pause owner appears: save/restore prior state or centralise pause ownership.
- `Router.go()` during a transition is dropped with only a `Log.debug`. A screen that redirects from its own `_ready()` (e.g. Welcome Gift → Closet when already claimed) loses the redirect silently. Options: queue the last request, return a bool, or defer the redirect with `call_deferred` after `screen_changed`.
- On web, Godot dispatches buffered input from its main loop, not inside the browser's event handler. Story 1.4 must verify that `AudioManager.unlock()` called from `_unhandled_input` actually satisfies the browser gesture rule (Safari especially), or rely on the engine's own AudioContext resume.
- Placeholder button wiring (targets, payloads, Esc on Crypt Closet) and the title's once-only latch / unlock-before-go order are untested; needs a Router test double or injectable router reference.

## Deferred from: dev of story-1-4 (2026-10-03)

- **Web: the first UI click is silent (accepted by Smuck, AC 3 partially met on web).** Chrome: the menu loop starts on the first gesture, but `sfx_ui_click` played from that same gesture is never heard. Console shows two "AudioContext was not allowed to start" warnings right after `[INFO][audio] unlocked`. Cause: Godot dispatches input from its main loop, outside the browser's event handler, so `play()` calls made in `unlock()`'s frame hit a still-suspended context; Godot's own resume lands a moment later. The loop survives the gap, the 40 ms click doesn't. Desktop is fine. Options when revisited: (a) AudioManager holds SFX requested in the unlock frame and plays them one frame later (no JS); (b) `WebPlatform` adds a capture-phase `pointerdown`/`keydown` listener that resumes the AudioContext inside the real gesture (Story 1.5 territory; Godot's context is internal). Natural homes: 1.5 (WebPlatform) or 5.1 (real audio + mix). Safari/Edge/Firefox not checked.
- ~~Godot imports images under `_bmad-output/` on every `--import`. Add an empty `_bmad-output/.gdignore`.~~ Done in Story 1.5.
- AudioManager's round-robin steal path isn't exercised by GUT: `AudioStreamPlayer.playing` stays `false` under the headless Dummy driver, so the first pool player is always "free". Covered by code review and the desktop listen only; a `_is_busy()` seam would make it testable if 2.5's throttle needs it.

## Deferred from: code review of story-1-4 (2026-10-03)

- `test_play_music_same_id_does_not_restart` is vacuous under the headless Dummy driver (`playing` is false, position 0 both ways). Needs a seam (e.g. `_is_busy()`/`_is_music_playing()`) to be meaningful; same seam would cover the SFX steal path.
- `test_title_requests_menu_music_on_ready` mutates and asserts on the live AudioManager autoload (`stop_music()`, `_pending_music`); breaks if any earlier test unlocks it.
- `stop_music()` while locked clears the pending track, so music stopped before the first gesture never starts later. No caller yet; revisit when screens manage their own music.

## Deferred from: code review of story-1-5 (2026-10-03)

- `AudioManager.play_music()` while locked lets an unknown id overwrite a valid pending id (warning + silence at unlock); unlocked, an unknown id keeps the old loop but `_current_music` doesn't record the request. Validate with `_get_playable_cue()` before setting pending when screens start managing music.
- ~~Desktop `WebPlatform.offer_download()` ignores `bytes` and only opens `user://`. Story 1.8 must write the save to `user://<file_name>` (check the FileAccess error) before opening the folder, or the desktop export silently loses data.~~ Done in Story 1.8: `SaveService.offer_export()` writes the file first (errors logged).
- The temporary Keyboard Test button on the main menu ships in release builds (desktop Download opens Explorer, Fullscreen flips the window). Gate on `OS.is_debug_build()` or remove the screen in 1.8/5.0.
- `test_unlock_is_idempotent` (passes with or without the guard) and the `is_fullscreen` test (expected value computed with the same expression) can't fail. Needs the same playing/mode seam as the 1.4 deferrals.
- ~~One tab switch fires both `focus_lost` and `visibility_hidden`. Story 2.7's auto-pause must be idempotent (or listen to one signal).~~ Done in Story 2.7: both signals call one handler that pauses only `RUNNING` / `COUNTDOWN`, so a second signal while paused changes nothing.
- Story 1.5 browser evidence not recorded: Firefox per-key table (quick-find on `'` and `/`, Tab focus, Backspace), Esc-in-fullscreen in Chrome/Edge/Firefox (incl. whether the first Esc reaches the game; UX open question 4), and `is_storage_persistent()` in normal and private windows. The JS key listener ships enabled as a hedge. Reason: Firefox not installed; verify alongside Story 1.7, which needs Firefox anyway. **Story 1.7 (2026-10-03):** Esc-in-fullscreen (Chrome, Edge) and `is_storage_persistent()` in normal/private windows checked by Smuck and reported fine. Still open: the Firefox per-key table and Firefox Esc-in-fullscreen (Firefox still not installed).

## Deferred from: dev of story-1-6 (2026-10-03)

- ~~**Web: a write made inside the `visibility_hidden` handler may not reach IndexedDB.** Godot syncs `user://` to IndexedDB asynchronously from its main loop, and a hidden tab stops `requestAnimationFrame`. `SaveService` writes synchronously on `visibility_hidden`, but nothing proves the sync completes before a tab close. Story 1.7's 10-reload / 10-tab-close test (NFR4) must measure it, along with whether `DirAccess.rename_absolute` is reliable on the web file system (the direct-write fallback logs `rename failed` if not). If data is lost, the fix belongs in `WebPlatform` (Boundary 3).~~ Measured in Story 1.7 (Chrome + Edge, 10 reloads + 10 tab closes each, including fast and mid-menu closes): no data lost, no `rename failed`; rename is reliable, SaveService unchanged.
- The `save_now()` failure paths (tmp write failure, rename failure → direct write, backup copy failure) are covered by code review only; GUT can't easily make `FileAccess`/`DirAccess` fail on desktop. A small IO seam would make them testable if a real failure ever shows up.
- ~~Desktop `WebPlatform.offer_download()` (see 1.5 deferral): when 1.8 writes the export to `user://`, route the file write through `SaveService` so the "only `SaveService` touches files" rule holds.~~ Done in Story 1.8 (`SaveService.offer_export()`).
- ~~Pre-existing: `tests/unit/test_keyboard_test.gd` uses the deprecated GUT `wait_frames` (the suite's single "Deprecated" line). Swap for `wait_process_frames` or `wait_physics_frames` when that file is next touched.~~ Done in Story 1.7.

## Deferred from: code review of story-1-6-versioned-save-file (2026-10-03)

- Array element types are not validated (`owned_items` strings, `run_history` dictionaries); only hand-edited saves can produce bad elements. Add when PlayerData/Shop consume them.
- A fractional float in an int-default field (`best_wpm`, `brains`) resets the field to 0 in `SaveSchema._merge`. Decide when `best_wpm` semantics are defined.
- A complete `save.tmp` left by a crash between write and rename is ignored on load, so one extra generation of progress is lost. Prefer it over `save.bak` if this ever matters.
- A UTF-8 BOM in a hand-edited or imported save fails to parse. Strip it in Story 1.8's import.
- `SaveService.load_save()` is public and does not assign `_data`. Make it private once nothing else calls it.
- The close-request hook misses `get_tree().quit()`, mobile pause and focus-out. Revisit with a Quit button or a mobile target.
- Web: two tabs share one IndexedDB (last writer wins), `run_history` is unbounded, and storage-unavailable (private window, quota) is only logged. Cover in Story 1.7 browser evidence and Epic 5. **Story 1.7:** two-tab and private-window checks done by Smuck, reported fine (no surprises). `run_history` bounds and quota handling still open for Epic 5.

## Deferred from: dev of story-1-7 (2026-10-03)

- **AC 2's second browser was Edge, not Firefox** (Smuck's call; Firefox still not installed). Edge runs on Chromium like Chrome, so Firefox's IndexedDB/MEMFS persistence (NFR4) is still unmeasured. Re-run the 10-reload / 10-tab-close check in Firefox when it is installed, together with the 1.2 and 1.5 Firefox checks.
- NFR4 browser results were reported as an overall pass ("all good"), with no per-round counter values. If a later regression needs a baseline, re-run with a per-round table.
- The storage notice lives on the placeholder main menu. Story 4.2's real menu must keep `%StorageNotice` (bottom-right parchment note, `mouse_filter` ignore, hidden when `WebPlatform.is_storage_persistent()`).
- The temporary brain counter and "Last save" label on the Keyboard Test screen write to the real save (a dev wallet). Remove them with the screen (see the 1.5 deferral about gating it out of release builds).

## Deferred from: code review of 1-7-player-data-service-and-reload-proof-counter (2026-10-03)

- `add_brains` has no int64 overflow guard (`get_brains() + amount` can wrap with a huge amount). Theoretical: no caller passes such values. Clamp if Epic 2/4 ever adds bulk rewards.
- ~~`PlayerData` emits no "profile replaced" signal, so UI bound to `brains_changed` goes stale when Story 1.8's F8 reset (or Epic 11's profile switch) swaps `SaveService` data. Add one when 1.8 lands.~~ Done in Story 1.8: `PlayerData.profile_replaced`, emitted by `reset_all()`; the Keyboard Test counter re-reads on it.
- `add_brains` keeps counting and emitting `brains_changed` on a read-only (newer-schema) save, so nothing persists. Accepted for the dev-only counter in Story 1.7; revisit when real brain rewards ship (Epic 2/4).

## Deferred from: dev of story-1-8 (2026-10-03)

- The debug overlay (top-left, 8 px text) covers the left half of the Keyboard Test heading at 640×360. No corner is free on that screen (the buttons span the full width at the bottom); the overlay is debug-only and ignores the mouse. Revisit if Story 2.10's extra sections make it taller than the run HUD's free corner.
- F3 during a Router fade was checked once on desktop (Esc then F3 50 ms later, overlay closed correctly). Not measured on web.
- Release gating was checked in the built-in browser pane (Chromium) with a local `--export-release` build: F3 shows nothing and Ctrl+Shift+E logs `download offered`. The CI-deployed Pages build was not checked.
- The overlay's numbers in a hidden/background browser tab or the hidden built-in pane read ~2 FPS (requestAnimationFrame throttling); only a visible tab gives real numbers.
- Firefox binds Ctrl+Shift+E to its Network tool; the chord is unverified there (Firefox still not installed). If playtests use Firefox, pick another chord or add a fallback.
- The Keyboard Test screen and button still ship in release (unchanged; see the 1.5 deferral).

## Deferred from: code review of story-1-8-debug-overlay-and-save-export (2026-10-03)

- No tests drive `_input` / `_unhandled_input` (modifier cancel, echo filtering, Ctrl+Shift+E to `offer_export`); only `_handle_key` and the static predicate are tested. Covered by the manual checks in Task 8.3/8.4.
- Export file name is date-only (`zts-save-YYYYMMDD.json`): same-day exports overwrite each other, and files accumulate in `user://` with no cleanup.
- `export_file_name` uses the current timezone bias, not the bias at that date, so it can be an hour off across a DST edge; its test mirrors the formula.
- Desktop `WebPlatform.offer_download` always opens `user://`, not `SaveService.save_dir`; only differs in tests.
- Web `JavaScriptBridge.download_buffer` has no failure feedback if the browser blocks the download.
- `OS.is_debug_build()` is true for a debug web export, which would ship F5/F8 cheats; check the export presets before any playtest build.
- Ctrl+Shift+E uses `keycode` (layout-dependent) and only fires on the main menu; Firefox captures it (see the earlier deferral).
- `reset_to_defaults()` writes via the deferred `request_save()`: a tab close in the same frame could lose it, and a failed write has no UI feedback.
- `PlayerData.reset_all()` does not re-apply settings (e.g. audio mute) to other systems; revisit when a settings UI exists.
- Router tests each add an overlay instance, and `test_debug_build_adds_one_hidden_overlay` assumes a debug runner.
- "Worst 10 s" is pinned by one huge frame after a hidden tab is restored; ~~F-keys may conflict with typing screens in Story 2.1.~~ Resolved in 2.1: `TypingInput` ignores F1–F35, and the overlay reads them first in `_input`.
- F8 reset on a read-only (newer-schema) save clears `_read_only`; the next write copies the newer-build `save.json` to `save.bak`, and a second reset overwrites that only copy. Kept as specified (spec 2.3), dev-only trigger. Revisit if profile/save migration across builds becomes a real playtest scenario.

## Deferred from: dev of story-1-9 (2026-10-03)

- Art gate approved by Smuck (palette, Press Start 2P, zombie idle/walk, villager wave, style sheet). The 8–12 fps rule stands, including 8 fps for 2-frame idles; no slower-idle exception.
- On `night` and `chalkboard` backgrounds the ink outline (#1E1428) is barely distinct from the backdrop; characters read by their fills. Accepted at the gate. Revisit in Story 3.6 / 8.6 (night levels) if characters get lost against dark scenery.
- Brute size class: 48×48 is recorded in the style sheet, but "Horde Rush copies = player sprite scaled" gives uneven pixels at 1.5×. Story 6.3 decides between redrawn 48×48 brutes and an integer scale.
- `process/fix_alpha_border=true` (Godot default) is on in the sprite `.import` files. It only changes the RGB of fully transparent pixels and is harmless with hard alpha and Nearest; untested.
- The art review scene (`scenes/debug/art_review.tscn`) ships in release exports (all resources) but nothing routes to it. Remove or exclude it with the Keyboard Test screen before the MVP link if export size matters.

## Deferred from: code review of 1-9-art-style-sheet-and-prototype-sprites-review-gate (2026-10-03)

- Esc in `scripts/debug/art_review.gd` calls `get_tree().quit()`, which does nothing in a web build. Scene is unrouted and dev-only.
- `tests/unit/test_art_style_sheet.gd` checks palette hexes by substring only, so a wrong name or index in a table row passes. `palette_32.png` is the master data.
- The 32 palette hexes are duplicated in `tools/gen_art_prototypes.gd` and two tests, and no test reads `DESIGN.md`. Intentional independent oracle; revisit if the palette changes.
- `fix_alpha_border` and Nearest filtering are not asserted in the sprite `.import` tests (see the dev note above).

## Deferred from: dev of story-2-1 (2026-10-03)

- AltGr limitation: on Windows AltGr arrives as Ctrl+Alt, so AltGr characters (e.g. `@` on German layouts) are ignored by `TypingInput`'s modifier rule. Fine for the lowercase-letter MVP; revisit for Epic 8 (Pitchfork Panic punctuation). Not checked in a real browser yet.
- `TypingInput.configure(null)`'s assert + `Log.error` guard is covered by code review only; calling it in a GUT test would trip the debug `assert`.
- ~~Story 2.4: the `RunFrame` run is the first end-to-end keyboard check of `TypingInput` (no scene or caller exists until then). Run-screen buttons must be `FOCUS_NONE` so Space/Enter can't press them. (2.4: the end-to-end check ran in a web debug build in the browser pane; the run screen still has no buttons, so `FOCUS_NONE` carries over to 2.5/2.7.)~~ Done in Story 2.5: the HUD's pause button and every other HUD control are `FOCUS_NONE` (`test_hud.gd`).

## Deferred from: code review of story-2-1-typing-input-filtering (2026-10-03)

- ~~`TypingInput` keeps the Caps Lock streak and `_caps_suspected` across focus loss or pause; only `configure()` resets them. Handle in Story 2.4/2.7.~~ Done in Story 2.7: `TypingInput.reset_caps_hint()`, called with the HUD hint reset when a countdown ends.
- ~~`TypingInput._unhandled_input` marks printable keys handled whenever the node is in the tree, and an unconfigured node behaves as lowercase. Add an enabled / active-run gate in Story 2.4.~~ Done in Story 2.4: `TypingInput.active` (default true); `RunFrame` turns it off in `ENDING` and after a failed load.
- Web Caps Lock state is not read directly (no `getModifierState`); the hint relies on the capital streak only. Revisit in web QA.
- Caps Lock hint counts Shift-held capitals (e.g. "NASA") as evidence of Caps Lock, as AC 6 specifies. Kept by decision; revisit after playtests (option: count only capitals typed without Shift).

## Deferred from: dev of story-2-2 (2026-10-04)

- `TypingSession` does not declare `target_completed` on purpose; Epic 6 adds it together with `WordSource`.
- `TypingSession`'s `config` argument is stored but unused until Story 6.2 (implied spaces in word mode arrive with `WordSource`; Story 2.3 added `StatsCalculator`'s `completed_words` but nothing counts words yet).
- ~~RNG sharing for Story 2.4/3.1: the level and `LetterBagSource` would share the run's RNG, and the source deals lazily, so a level drawing from the same RNG makes the letter sequence depend on call timing (breaks seed replay, 2.10). Give the source its own RNG seeded from the run RNG (`child.seed = rng.randi()`) at creation, or have the level draw only through the source.~~ Done in Story 2.4: `LevelBase` documents the child-RNG rule and the test level follows it (`test_source_has_its_own_rng`).
- Contract guards (`LetterBagSource` null rng / pool < 2 / duplicates, `TypingSession` null source) are covered by code review only; calling them in a GUT test would trip the debug `assert`.

## Deferred from: code review of 2-2-judgment-session-and-letter-bag (2026-10-04)

- `TypingSession.judge()` returns `WRONG` when the source is exhausted/empty, so callers cannot tell "no target" from a typo, and a correct key on the last target emits `target_changed("")` with no end signal. Harmless with the infinite `LetterBagSource`; address with `WordSource`/`ParagraphSource` (Epic 6/8), e.g. a `NO_TARGET` verdict or a `source_exhausted` signal.
- ~~`TypingSession.judge()` has no re-entrancy guard: a `run_started` handler that calls `judge()` would advance the source twice for one key. Check when `RunFrame` (2.4) connects handlers; add a `_judging` guard if any handler can feed input back.~~ Checked in Story 2.4: no `RunFrame` or level handler calls `judge()`; no guard added.

## Deferred from: dev of story-2-3 (2026-10-04)

- Accuracy and WPM round **down** (decision taken in 2.3: 100 % only with zero errors; WPM never overstates, so "New best!" needs a real improvement). The GDD only says "whole number". Smuck may overrule after playtest: one line each in `StatsCalculator.accuracy_percent` / `wpm` plus the edge tests.
- ~~`RunClock` overshoot: accumulated deltas can push the last frame past the level duration (e.g. 120.016 s). Story 2.4's `RunFrame` should pass `minf(elapsed, config.duration_s)` for `&"timer"` ends; `RunResult` doesn't know the level duration.~~ Done in Story 2.4: `RunFrame` clamps timer ends with `minf(elapsed, duration)`.
- `letter_pool_or_tier` is `"all"` for the MVP. Epic 7 decides the tier string format (e.g. `"tier_3"`).
- `RunResult.completed_words` and `bonus_brains` are not written to the run record (architecture key set). Adding them to the save is a schema decision for Epic 6/10 if trends need them.
- Contract guards (`StatsCalculator` negative counts, `RunResult.create` empty level id / unknown end reason) are covered by code review only; calling them in a GUT test would trip the debug `assert`.

## Deferred from: code review of story-2-3-stats-calculator-and-run-result (2026-10-04)

- Run record `duration_s` is floored to whole seconds while `wpm` is computed from the unrounded duration, so recomputing WPM from a saved record (Epic 7 tier rolling average) can differ by 1 from the stored value. Use the stored `wpm`, or store a finer duration, when Epic 7 lands.

## Deferred from: dev of story-2-4 (2026-10-04)

- Completion bonus is `0` in `RunFrame._send_result()` until Story 3.5 adds it to `LevelConfig`.
- ~~`LevelBase.brains_earned_changed` is not connected until the HUD brain counter (Story 2.5); the result reads `get_brains_earned()` at run end.~~ Done in Story 2.5: `RunFrame` connects it to `Hud.set_brains`.
- `RunFrame.LETTER_POOL_ALL` (`"all"`) is a placeholder for `letter_pool_or_tier` until Epic 7.
- The test level (`scenes/levels/test_level/`) and its `debug_only` registry entry ship in release builds but are unreachable there (the menu button is debug-only). Exclude them from release exports with the Keyboard Test and art review screens if export size matters.
- Main menu "Play" sends `&"zombie_run"`, which is not registered until Story 3.1: `RunFrame` logs `[ERROR][run]` and returns to the menu (NFR16 path, on purpose).
- The main menu's `_is_debug_build()` seam is a placeholder-menu exception to Boundary 7 (`OS.is_debug_build()` outside `scripts/debug/`). Story 4.2 decides where a debug entry to the test level lives.
- Web key capture: in the browser pane, Space, Tab and Backspace had their default blocked during the run and capture was off again on the report card. The pane sends `'` and `/` with an empty `key`, so the capture listener for those two is not proven by this check; Smuck should press them on a real keyboard (Chrome/Edge) during a test-level run.
- Desktop (non-web) manual run of the test level was not done by the agent; the web debug build covered the same flow.
- `LevelBase.create_target_source()` base contract guard and the `null` target-source fallback in `RunFrame` are covered by code review only (calling the base would trip the debug `assert`).
- `RunFrame._set_state()` logs each transition at DEBUG; the ENDING/DONE transitions happen inside `_process` (one line each per run, debug builds only).

## Deferred from: code review of story-2-4-run-frame-level-contract-and-test-level (2026-10-04)

- A level that emits `end_requested` from `on_run_started`/`on_char_accepted` still receives `on_char_accepted` after `on_run_ending` (the session keeps judging that key), so a late brain can be counted in `get_brains_earned()`. No current level does this; revisit with Zombie Run (3.1).
- `RunFrame._fail_to_menu`'s Router-transitioning branch and the null-`TargetSource` failure path have no automated test (tests inject `navigate`; the base `create_target_source` asserts in debug). Covered by the manual web run; add when a Router test seam exists.

## Deferred from: dev of story-2-5 (2026-10-04)

- HUD chrome is placeholder (flat palette `StyleBoxFlat`s, 1 px ink borders, zero corner radius, ColorRect brain icon, two-bar pause icon) until Story 5.0's 9-slice art.
- Brain counter count-up tick and pop (EXPERIENCE.md Game Feel) are Story 5.0 / 5.1 polish; `BrainCounter.set_count()` just sets the number.
- Word-mode progress colouring / underline (Story 6.2) and paragraph text rendering (Story 8.2) use the target area sized here (word sign grows with the word up to 9 letters; paragraph sign 304 x 48, 2 lines of 24 px).
- Paragraph mode fits **12 characters per 24 px line** with Press Start 2P. Epic 8 must accept it, use another 8 px-grid size, or widen the target area.
- Approved sketch deviations from DESIGN.md / FR14 (Smuck, 2026-10-04, `sketches/hud-band-2-5.md`): HUD label "Keys" (report card keeps "Keys Typed"); stats column 176 px and target area 312 px; start prompt and Caps Lock hint above the band; WPM placeholder en dash; brain counter 80 px (3 digits). DESIGN.md itself is not edited; the sketch is the override.
- The pause button is drawn as two ink bars, not the text "II": "II" at 16 px is 32 px wide and does not fit the 24 px button (the sketch table said "II", font 16).
- The test level's own `%StatusLabel` ("Brains: N", y 176-200) touches the Caps Lock hint (y 196-224) by 4 px. Debug level only; Zombie Run (3.1) draws its own playfield.
- The wrong-key shake (0.2 s) was not caught on a browser-pane screenshot (too short); covered by `test_hud.gd` and `test_run_frame.gd`. The pane's `shift+<letter>` sends a lowercase `key`, so Shift capitals cannot be tested there; bare capitals (Caps Lock style) can.
- ~~`%Hud.pause_pressed` is not connected until Story 2.7.~~ Done in Story 2.7.

## Deferred from: code review of story-2-5-shared-hud-with-wrong-key-feedback (2026-10-04)

- `Hud`'s `%TargetLabel` has no `autowrap_mode`: paragraph text stays on one line and overflows the two-line sign. The layout only sizes the area; set `autowrap_mode` with paragraph rendering in Story 8.2.
- Word sign width in `Hud._layout_target` is unclamped: a word over about 9 letters at 32 px overflows the 312 px target area. The MVP / Epic 6 words (max 8 letters) fit; check when Story 6.x adds longer words.
- ~~The wrong-key shake runs from the HUD's own `_process`. If Story 2.7 pauses through `RunFrame` state rather than the tree, the shake keeps animating; stop it with the pause.~~ Done in Story 2.7: the pause goes through the tree; the HUD inherits and freezes.

## Deferred from: dev of story-2-6 (2026-10-04)

- The zombie hands are placeholder code-drawn rects (`zombie_hands.gd` `_draw()`, about 58 px wide per hand) until Story 5.0 (2 hand sprites + 10 glow states). Keep the getters (`get_lit_fingers`, `is_lit`, `get_outline_width`, `get_finger_fill`, `has_bump`) as the contract. Smuck approved the placeholder look on 2026-10-04.
- Word and paragraph modes must pass the cursor character to the hands, not the whole target: `ZombieHands.show_char()` lights the first character of what it is given (Stories 6.2 / 8.2).
- Unmapped keys: `` ` ~ [ ] { } \ | `` (outside the GDD table). Add them to `tools/gen_finger_map.gd` if Epic 8 paragraphs ever use them; until then they log `[WARN][hands]` and light nothing.
- Non-US keyboard layouts still show US QWERTY fingers (GDD A1, accepted).
- Architecture data flow says `ZombieHands` listens to `TypingSession.target_changed`; it is the HUD that forwards the target instead (`Hud.show_target`, also used by `setup`), same timing, no sibling wiring.

## Deferred from: code review of story-2-6-green-zombie-hands-finger-guide (2026-10-04)

- An unmapped first character (newline, tab, curly quotes, accents, `` ` ~ [ ] { } \ | ``) lights no finger and `FingerMap.fingers_for` logs a warning on every `target_changed`. The Epic 6/8 text sources decide whether such characters occur; dedupe the warning or extend the map then.
- ~~`ZombieHands` pulses from its own `_process`; if Story 2.7 pauses through `RunFrame` state instead of the tree, the pulse keeps animating. Stop it with the pause.~~ Done in Story 2.7: the pause goes through the tree; the hands inherit and freeze.

## Deferred from: dev of story-2-7 (2026-10-04)

- Pause panel and countdown are placeholder chrome (flat stone `StyleBoxFlat`, default theme buttons, a 2 px ink shadow label behind the candy-yellow numbers); the toggles show their state in words ("Music: on/off") instead of DESIGN.md's icon + red slash. Stories 4.2 / 5.0.
- Restoring the saved Music / Sound settings on launch is Story 4.2's AC. Until then a muted setting is saved and shown on the pause panel, but the buses start unmuted after a reload.
- Windows-fallback auto-pause (desktop window focus) stays deferred (G5); only the web `focus_lost` / `visibility_hidden` signals pause.
- Esc in browser fullscreen leaves fullscreen first (browser rule); whether it also pauses is Story 5.3's check.
- Decisions in 2.7 (Smuck can overrule): Esc during the countdown is ignored; focus loss while waiting for the first key does not pause (Esc and the pause button do); the Caps Lock hint and streak reset on resume.
- `RunFrame` unpauses the tree only when leaving `COUNTDOWN` (into `RUNNING` or `WAITING_FIRST_KEY`), not on every entry into `RUNNING`, so the first correct key never touches the tree's pause state.
- `PausePanel.close()` calls `gui_release_focus()` explicitly; Godot already drops a control's focus when it is hidden, so that call is a second line of defence no test can tell apart (mutation (e) survived).
- The countdown numbers draw over the test level's own big letter in the playfield centre (debug level only).
- In the browser pane a hidden tab gets no blur / visibility event, so a long pane tab switch can deliver one large frame delta to the run clock. Real browsers fire blur first (Smuck checked a tab switch in a real browser: paused, timer frozen). If a platform ever skips both events, a max-delta clamp in `RunFrame._process` would be the fix.
- Tests that call `_unhandled_input()` by hand mark GUT's shared viewport input as handled, and headless nothing clears it; `test_run_frame.gd` and `test_pause_panel.gd` reset it in `after_each` with a no-op `push_input`. Any future test calling `_unhandled_input()` directly needs the same.

## Deferred from: code review of story-2-7 (2026-10-04)

- Quit to Menu soft-locks if `Router._swap_to(MAIN_MENU)` fails: `_quitting` stays true, `Router.go` unpauses the tree, the panel is visible but frozen. Needs a Router failure contract (recover or retry) [run_frame.gd `_quit_to_menu`, router.gd `go`].
- `RunFrame._exit_tree` does not unpause the tree if the frame is freed while PAUSED/COUNTDOWN by anything other than `Router.go` (debug jump, `change_scene`). Fine today because the Router unpauses on every swap.
- `test_clean_resume_focus_and_caps_hint` cannot fail headless (no focus owner exists); the unit test on `PausePanel.close()` is the real check. Mutation (e) still survives.
- `test_countdown.gd` / `test_pause_panel.gd` instances are not process-disabled (spec 6.1/6.2 said so); harmless.

## Deferred from: dev of story-2-8 (2026-10-04)

- A level's first run with 0 WPM leaves the best at 0, so the next run with WPM > 0 is again treated as a "first run" (sets the best, no "New best" flag). Acceptable for a 6-year-old's first run.
- `record_run` validates only `null`; unlock rule (FR79) and `level_unlocked` join it in Story 6.8.
- ~~A non-int value inside a hand-edited `best_wpm` is read through `int(...)`.~~ Resolved in code review: non-numbers and negatives count as no best.
- Games that end through a path other than `RunFrame._send_result` (none today) would not be recorded.

## Deferred from: code review of 2-8-run-recording-and-personal-bests (2026-10-04)

- `record_run` returns `new_best = true` and emits `run_recorded` even when the save is read-only (newer `schema_version`) or the write fails, so the report card can celebrate a best that is gone after reload. Pre-existing SaveService behavior; no retry on a failed write until the next `request_save` or tab hide.

## Deferred from: dev of story-2-9 (2026-10-04)

- Hand-off to Story 3.1: register `zombie_run` in `data/levels/level_registry.tres` with `display_name = "Zombie Run"` (the report card heading). Without it the card falls back to `"zombie_run".capitalize()`, which happens to read the same.
- Final chalkboard, chalk tray, "New best!" stamp (hand-lettered, pre-rotated -8°), pixel buttons, key-hint keycaps, smiling moon and night-classroom backdrop art: Story 5.0. Today they are square `StyleBoxFlat` / `ColorRect` placeholders in palette colours.
- Chalk-scratch per revealed row, the chime, the stamp thump and menu music on the report card: Story 5.1 (no `AudioCue`s exist for them yet).
- The worn hat and pet in Professor Zombie's `%HatSlot` / `%PetSlot`, `SpriteAnchors` for the professor, and lifting the mortarboard by the hat's height: Story 4.3.
- First completed run goes through the Welcome Gift: Story 4.5 hooks into `report_card.gd` `_leave()`, the card's only navigation.
- Long level names vs the stamp: at 24 px the heading has 245 px before the stamp (10 glyphs); "Pitchfork Panic" (15 glyphs = 360 px) would run under it. Epic 8 (or the 5.0 stamp art) resolves it; `test_stamp_clear_of_heading_and_rows` checks only "Test level" today.
- Professor Zombie is 32×32 at 1× (one sprite scale rule), so he is much smaller than in the mock. An exception to the rule or a 48×48 professor sprite is Smuck's call.
- `test_level` has no completion bonus, so the "+N bonus" line is only seen in tests until Story 3.5.
- The pixel-button focus look is two parts: the scene's `focus` box draws only the 2 px candy-yellow ring (outside the ink outline), and `report_card.gd` swaps the `normal`/`hover` box to the pumpkin-light fill on focus. A shared pixel-button widget/theme type (Stories 4.2 / 5.0) should absorb this.

## Deferred from: code review of 2-9-chalkboard-report-card (2026-10-04)

- Soft-lock if navigation does nothing: `report_card.gd` `_leave()` sets `_leaving` before calling `navigate`; if the Router ignores or fails the call the card ignores all input. Router falls back to the menu, so only a missing menu scene triggers it. Reason: Router-level failure, very unlikely.
- No hover cue on the unfocused button (hover stylebox equals normal). Reason: placeholder chrome until Story 5.0.
- Brittle tests in `test_report_card.gd`: hard-coded `checked == 19` label count; guard boundary tests rely on 0.99 + 0.01 summing to exactly 1.0. Reason: low value.
