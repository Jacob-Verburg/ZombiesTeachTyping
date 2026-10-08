
## Deferred from: code review of story-1-1 (2026-10-02)

- `test_debug_disabled_in_release` does not verify that nothing printed; only the `is_level_enabled` seam is tested.
- ~~`Log.verbose_typing` is declared but not consumed; wire it up when per-keystroke logging arrives (Epic 2).~~ Done in 2.1: `TypingInput` logs each emitted character at DEBUG while it is on.
- `directory_rules={"res://addons": 0}` not persisted in `project.godot`; relies on the Godot 4.7 default.
- `Log.debug` evaluates its `msg` argument even when DEBUG is disabled; keep calls out of hot paths.
- GUT plugin is enabled in `project.godot`; confirm the web export (Story 1.2) excludes `addons/gut`.

## Deferred from: dev of story-1-2 (2026-10-02)

- Web letterbox bars render **black**, not night `#2B1D3F` (DESIGN.md marks night bars as `[ASSUMPTION]`). Not required by Story 1.2 AC 5. Natural home: Story 5.0 (loading page / boot splash styling); options are the HTML page background in `html/head_include` plus the engine's black-bar color.
- Firefox checks for Story 1.2 AC 4/5 (load times, 1366×768 screenshot) were skipped because Firefox isn't installed. Stories 1.5 (key capture and quick-find) and 1.7 (reload and tab-close persistence, NFR4) require Firefox: install it before those stories, and re-run the 1.2 Firefox checks then. **5.3 (2026-10-06):** Firefox rows Skipped by Smuck ("Skip Firefox"); still open.

## Deferred from: dev of story-1-3 (2026-10-02)

- Godot imports files inside `build/` (e.g. `build/web/index.icon.png.import` exists since the 1.2 export). Harmless: `build/` is gitignored and export-excluded. Add an empty `build/.gdignore` (recreated after each clean) or export outside the project if it ever slows imports.
- ~~Font is Press Start 2P (wide, arcade look) because Pixelify Sans failed the O/0 check. If Story 1.9 or 5.0 wants a rounder face, any replacement must pass `test_ui_theme.gd` and have a native size that divides 16/24/32/64.~~ Settled at the Story 1.9 art gate (2026-10-03): Smuck approved keeping Press Start 2P.

## Deferred from: code review of 1-3-screen-router-and-title-screen (2026-10-02)

- Router sets `get_tree().paused = false` unconditionally after every transition, which clobbers any pause owned elsewhere (e.g. Story 1.5's tab-blur pause) and pauses other autoloads (AudioManager) for 0.3 s per transition. Revisit when a second pause owner appears: save/restore prior state or centralise pause ownership.
- `Router.go()` during a transition is dropped with only a `Log.debug`. A screen that redirects from its own `_ready()` (e.g. Welcome Gift → Closet when already claimed) loses the redirect silently. Options: queue the last request, return a bool, or defer the redirect with `call_deferred` after `screen_changed`. (4.5: not affected. The gift never redirects from `_ready()`; the decision is made on the report card at leave time, and an already-claimed gift still shows its card.)
- On web, Godot dispatches buffered input from its main loop, not inside the browser's event handler. Story 1.4 must verify that `AudioManager.unlock()` called from `_unhandled_input` actually satisfies the browser gesture rule (Safari especially), or rely on the engine's own AudioContext resume.
- Placeholder button wiring (targets, payloads, Esc on Crypt Closet) and the title's once-only latch / unlock-before-go order are untested; needs a Router test double or injectable router reference. Done in 4.4: the real Closet has `navigate` / `is_transitioning` seams, and `test_crypt_closet.gd` covers Esc and the Menu button (once each, the `_leaving` guard, Esc = No while the prompt is open).

## Deferred from: dev of story-1-4 (2026-10-03)

- ~~**Web: the first UI click is silent (accepted by Smuck, AC 3 partially met on web).** Chrome: the menu loop starts on the first gesture, but `sfx_ui_click` played from that same gesture is never heard. Console shows two "AudioContext was not allowed to start" warnings right after `[INFO][audio] unlocked`. Cause: Godot dispatches input from its main loop, outside the browser's event handler, so `play()` calls made in `unlock()`'s frame hit a still-suspended context; Godot's own resume lands a moment later. The loop survives the gap, the 40 ms click doesn't. Desktop is fine. Options when revisited: (a) AudioManager holds SFX requested in the unlock frame and plays them one frame later (no JS); (b) `WebPlatform` adds a capture-phase `pointerdown`/`keydown` listener that resumes the AudioContext inside the real gesture (Story 1.5 territory; Godot's context is internal). Natural homes: 1.5 (WebPlatform) or 5.1 (real audio + mix). Safari/Edge/Firefox not checked.~~ Done in 5.1 (option a): AudioManager holds SFX asked for in the unlock frame and plays them once on the next frame. Web check: the held click starts on the first frame after the press (~115 ms after the menu loop starts); audibility is Mix Checklist M11.
- ~~Godot imports images under `_bmad-output/` on every `--import`. Add an empty `_bmad-output/.gdignore`.~~ Done in Story 1.5.
- ~~AudioManager's round-robin steal path isn't exercised by GUT: `AudioStreamPlayer.playing` stays `false` under the headless Dummy driver, so the first pool player is always "free". Covered by code review and the desktop listen only; a `_is_busy()` seam would make it testable if 2.5's throttle needs it.~~ Done in 5.1: `_is_busy()` seam; `test_busy_pool_steals_round_robin` and the voice-steal test are deterministic.

## Deferred from: code review of story-1-4 (2026-10-03)

- ~~`test_play_music_same_id_does_not_restart` is vacuous under the headless Dummy driver (`playing` is false, position 0 both ways). Needs a seam (e.g. `_is_busy()`/`_is_music_playing()`) to be meaningful; same seam would cover the SFX steal path.~~ Done in 5.1: `_is_busy()` + `_play_player()` seams make it count restarts.
- `test_title_requests_menu_music_on_ready` mutates and asserts on the live AudioManager autoload (`stop_music()`, `_pending_music`); breaks if any earlier test unlocks it.
- `stop_music()` while locked clears the pending track, so music stopped before the first gesture never starts later. No caller yet; revisit when screens manage their own music.

## Deferred from: code review of story-1-5 (2026-10-03)

- ~~`AudioManager.play_music()` while locked lets an unknown id overwrite a valid pending id (warning + silence at unlock); unlocked, an unknown id keeps the old loop but `_current_music` doesn't record the request. Validate with `_get_playable_cue()` before setting pending when screens start managing music.~~ Done in 5.1: `play_music()` validates with `_get_playable_cue()` first, locked or not.
- ~~Desktop `WebPlatform.offer_download()` ignores `bytes` and only opens `user://`. Story 1.8 must write the save to `user://<file_name>` (check the FileAccess error) before opening the folder, or the desktop export silently loses data.~~ Done in Story 1.8: `SaveService.offer_export()` writes the file first (errors logged).
- ~~The temporary Keyboard Test button on the main menu ships in release builds (desktop Download opens Explorer, Fullscreen flips the window). Gate on `OS.is_debug_build()` or remove the screen in 1.8/5.0.~~ Done in 4.2: the button left the menu; the keyboard test is reached from the F3 debug overlay's jump row (debug builds only). The screen itself still exists until 5.0.
- `test_unlock_is_idempotent` (passes with or without the guard) and the `is_fullscreen` test (expected value computed with the same expression) can't fail. Needs the same playing/mode seam as the 1.4 deferrals.
- ~~One tab switch fires both `focus_lost` and `visibility_hidden`. Story 2.7's auto-pause must be idempotent (or listen to one signal).~~ Done in Story 2.7: both signals call one handler that pauses only `RUNNING` / `COUNTDOWN`, so a second signal while paused changes nothing.
- Story 1.5 browser evidence not recorded: Firefox per-key table (quick-find on `'` and `/`, Tab focus, Backspace), Esc-in-fullscreen in Chrome/Edge/Firefox (incl. whether the first Esc reaches the game; UX open question 4), and `is_storage_persistent()` in normal and private windows. The JS key listener ships enabled as a hedge. Reason: Firefox not installed; verify alongside Story 1.7, which needs Firefox anyway. **Story 1.7 (2026-10-03):** Esc-in-fullscreen (Chrome, Edge) and `is_storage_persistent()` in normal/private windows checked by Smuck and reported fine. Still open: the Firefox per-key table and Firefox Esc-in-fullscreen (Firefox still not installed). **5.3 (2026-10-06):** Firefox rows Skipped by Smuck ("Skip Firefox"); still open.

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
- Web: two tabs share one IndexedDB (last writer wins), `run_history` is unbounded, and storage-unavailable (private window, quota) is only logged. Cover in Story 1.7 browser evidence and Epic 5. **Story 1.7:** two-tab and private-window checks done by Smuck, reported fine (no surprises). ~~`run_history` bounds~~ (done: `GameConstants.RUN_HISTORY_CAP`, `PlayerData.record_run` keeps the newest; struck in 5.3) and quota handling still open for Epic 5.

## Deferred from: dev of story-1-7 (2026-10-03)

- **AC 2's second browser was Edge, not Firefox** (Smuck's call; Firefox still not installed). Edge runs on Chromium like Chrome, so Firefox's IndexedDB/MEMFS persistence (NFR4) is still unmeasured. Re-run the 10-reload / 10-tab-close check in Firefox when it is installed, together with the 1.2 and 1.5 Firefox checks. **5.3 (2026-10-06):** Edge re-run on the Pages v0.9.0 build after a real run + purchase: 20/20 rounds no loss ("all 20 rounds good"). Firefox Skipped by Smuck; still open.
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
- ~~Release gating was checked in the built-in browser pane (Chromium) with a local `--export-release` build: F3 shows nothing and Ctrl+Shift+E logs `download offered`. The CI-deployed Pages build was not checked.~~ Done in 5.3: the CI-deployed Pages v0.9.0 build loads title → menu with no console errors and F3 shows nothing (pane, 2026-10-06). Ctrl+Shift+E wasn't re-tried on Pages.
- The overlay's numbers in a hidden/background browser tab or the hidden built-in pane read ~2 FPS (requestAnimationFrame throttling); only a visible tab gives real numbers.
- Firefox binds Ctrl+Shift+E to its Network tool; the chord is unverified there (Firefox still not installed). If playtests use Firefox, pick another chord or add a fallback. **5.3 (2026-10-06):** Firefox rows Skipped by Smuck ("Skip Firefox"); still open.
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
- ~~`PlayerData.reset_all()` does not re-apply settings (e.g. audio mute) to other systems; revisit when a settings UI exists.~~ Done in 4.2: AudioManager re-applies music_on/sound_on on `profile_replaced`.
- Router tests each add an overlay instance, and `test_debug_build_adds_one_hidden_overlay` assumes a debug runner.
- "Worst 10 s" is pinned by one huge frame after a hidden tab is restored; ~~F-keys may conflict with typing screens in Story 2.1.~~ Resolved in 2.1: `TypingInput` ignores F1–F35, and the overlay reads them first in `_input`.
- F8 reset on a read-only (newer-schema) save clears `_read_only`; the next write copies the newer-build `save.json` to `save.bak`, and a second reset overwrites that only copy. Kept as specified (spec 2.3), dev-only trigger. Revisit if profile/save migration across builds becomes a real playtest scenario.

## Deferred from: dev of story-1-9 (2026-10-03)

- Art gate approved by Smuck (palette, Press Start 2P, zombie idle/walk, villager wave, style sheet). The 8–12 fps rule stands, including 8 fps for 2-frame idles; no slower-idle exception.
- On `night` and `chalkboard` backgrounds the ink outline (#1E1428) is barely distinct from the backdrop; characters read by their fills. Accepted at the gate. Revisit in Story 3.6 / 8.6 (night levels) if characters get lost against dark scenery.
- ~~Brute size class: 48×48 is recorded in the style sheet, but "Horde Rush copies = player sprite scaled" gives uneven pixels at 1.5×. Story 6.3 decides between redrawn 48×48 brutes and an integer scale.~~ Decided in 6.3: per-class `sprite_scale` in `horde_rush.tres` (small 1.0, medium 1.25, brute 1.5 of the 32 px sprite); integer 2× is ruled out (64 px is taller than a 44 px lane); redrawn 48 px brutes are not needed yet since no brute spawns before Epic 7 (band 3–5). The 1.25 medium was checked at 3× (`screenshots/6-3/size-classes-3x.png`): slightly uneven pixels, reads clearly as bigger, kept. Story 6.6 owns the final art and hat fit on scaled classes.
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

- ~~`TypingSession` does not declare `target_completed` on purpose; Epic 6 adds it together with `WordSource`.~~ Done in 6.2: `target_completed(target)` fires on a word's (or paragraph's) last letter, between `char_accepted` and `target_changed`; `RunFrame` connects it to `LevelBase.on_target_completed`.
- ~~`TypingSession`'s `config` argument is stored but unused until Story 6.2 (implied spaces in word mode arrive with `WordSource`; Story 2.3 added `StatsCalculator`'s `completed_words` but nothing counts words yet).~~ Done in 6.2: `config.target_mode` picks letter / word / paragraph judging; WORD mode counts implied spaces, passed to live HUD WPM, the overlay and `RunResult.completed_words`.
- ~~RNG sharing for Story 2.4/3.1: the level and `LetterBagSource` would share the run's RNG, and the source deals lazily, so a level drawing from the same RNG makes the letter sequence depend on call timing (breaks seed replay, 2.10). Give the source its own RNG seeded from the run RNG (`child.seed = rng.randi()`) at creation, or have the level draw only through the source.~~ Done in Story 2.4: `LevelBase` documents the child-RNG rule and the test level follows it (`test_source_has_its_own_rng`).
- Contract guards (`LetterBagSource` null rng / pool < 2 / duplicates, `TypingSession` null source) are covered by code review only; calling them in a GUT test would trip the debug `assert`.

## Deferred from: code review of 2-2-judgment-session-and-letter-bag (2026-10-04)

- `TypingSession.judge()` returns `WRONG` when the source is exhausted/empty, so callers cannot tell "no target" from a typo, and a correct key on the last target emits `target_changed("")` with no end signal. Harmless with the infinite `LetterBagSource`; address with `WordSource`/`ParagraphSource` (Epic 6/8), e.g. a `NO_TARGET` verdict or a `source_exhausted` signal. Still open after 6.2: `WordSource` is an infinite bag too, so `ParagraphSource` (8.2) is the first finite source.
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

- ~~Completion bonus is `0` in `RunFrame._send_result()` until Story 3.5 adds it to `LevelConfig`.~~ Done in 3.5: `RunFrame` reads `LevelConfig.completion_bonus` at start and passes it as `RunResult.bonus_brains` on every recorded run.
- ~~`LevelBase.brains_earned_changed` is not connected until the HUD brain counter (Story 2.5); the result reads `get_brains_earned()` at run end.~~ Done in Story 2.5: `RunFrame` connects it to `Hud.set_brains`.
- `RunFrame.LETTER_POOL_ALL` (`"all"`) is a placeholder for `letter_pool_or_tier` until Epic 7.
- The test level (`scenes/levels/test_level/`) and its `debug_only` registry entry ship in release builds but are unreachable there (the menu button is debug-only). Exclude them from release exports with the Keyboard Test and art review screens if export size matters.
- ~~Main menu "Play" sends `&"zombie_run"`, which is not registered until Story 3.1: `RunFrame` logs `[ERROR][run]` and returns to the menu (NFR16 path, on purpose).~~ Done in 3.1: `zombie_run` is registered and the button reads "Zombie Run".
- ~~The main menu's `_is_debug_build()` seam is a placeholder-menu exception to Boundary 7 (`OS.is_debug_build()` outside `scripts/debug/`). Story 4.2 decides where a debug entry to the test level lives.~~ Done in 4.2: the seam is gone; the test level is a jump button in the F3 debug overlay.
- Web key capture: in the browser pane, Space, Tab and Backspace had their default blocked during the run and capture was off again on the report card. The pane sends `'` and `/` with an empty `key`, so the capture listener for those two is not proven by this check; Smuck should press them on a real keyboard (Chrome/Edge) during a test-level run.
- Desktop (non-web) manual run of the test level was not done by the agent; the web debug build covered the same flow.
- `LevelBase.create_target_source()` base contract guard and the `null` target-source fallback in `RunFrame` are covered by code review only (calling the base would trip the debug `assert`).
- `RunFrame._set_state()` logs each transition at DEBUG; the ENDING/DONE transitions happen inside `_process` (one line each per run, debug builds only).

## Deferred from: code review of story-2-4-run-frame-level-contract-and-test-level (2026-10-04)

- A level that emits `end_requested` from `on_run_started`/`on_char_accepted` still receives `on_char_accepted` after `on_run_ending` (the session keeps judging that key), so a late brain can be counted in `get_brains_earned()`. No current level does this; revisit with Zombie Run (3.1). 3.1: Zombie Run never emits `end_requested` (the timer is RunFrame's), so this stays open for Epic 8 (Pitchfork Panic caught/escaped).
- `RunFrame._fail_to_menu`'s Router-transitioning branch and the null-`TargetSource` failure path have no automated test (tests inject `navigate`; the base `create_target_source` asserts in debug). Covered by the manual web run; add when a Router test seam exists.

## Deferred from: dev of story-2-5 (2026-10-04)

- ~~HUD chrome is placeholder (flat palette `StyleBoxFlat`s, 1 px ink borders, zero corner radius, ColorRect brain icon, two-bar pause icon) until Story 5.0's 9-slice art.~~ Done in 5.0: HUD band, target sign, stats chalkboard, cushion, Caps Lock sign, pause button and brain pill are 9-slice / sprite art.
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

- ~~The zombie hands are placeholder code-drawn rects (`zombie_hands.gd` `_draw()`, about 58 px wide per hand) until Story 5.0 (2 hand sprites + 10 glow states). Keep the getters (`get_lit_fingers`, `is_lit`, `get_outline_width`, `get_finger_fill`, `has_bump`) as the contract. Smuck approved the placeholder look on 2026-10-04.~~ Done in 5.0: two hand sprites and ten 2-frame glow sheets; every getter kept.
- ~~Word and paragraph modes must pass the cursor character to the hands, not the whole target: `ZombieHands.show_char()` lights the first character of what it is given (Stories 6.2 / 8.2).~~ Done in 6.2: `Hud.show_target(target, typed)` passes `target.substr(typed, 1)`, for every mode.
- Unmapped keys: `` ` ~ [ ] { } \ | `` (outside the GDD table). Add them to `tools/gen_finger_map.gd` if Epic 8 paragraphs ever use them; until then they log `[WARN][hands]` and light nothing.
- Non-US keyboard layouts still show US QWERTY fingers (GDD A1, accepted).
- Architecture data flow says `ZombieHands` listens to `TypingSession.target_changed`; it is the HUD that forwards the target instead (`Hud.show_target`, also used by `setup`), same timing, no sibling wiring.

## Deferred from: code review of story-2-6-green-zombie-hands-finger-guide (2026-10-04)

- An unmapped first character (newline, tab, curly quotes, accents, `` ` ~ [ ] { } \ | ``) lights no finger and `FingerMap.fingers_for` logs a warning on every `target_changed`. The Epic 6/8 text sources decide whether such characters occur; dedupe the warning or extend the map then.
- ~~`ZombieHands` pulses from its own `_process`; if Story 2.7 pauses through `RunFrame` state instead of the tree, the pulse keeps animating. Stop it with the pause.~~ Done in Story 2.7: the pause goes through the tree; the hands inherit and freeze.

## Deferred from: dev of story-2-7 (2026-10-04)

- ~~Pause panel and countdown are placeholder chrome (flat stone `StyleBoxFlat`, default theme buttons, a 2 px ink shadow label behind the candy-yellow numbers); the toggles show their state in words ("Music: on/off") instead of DESIGN.md's icon + red slash. Stories 4.2 / 5.0.~~ Done in 5.0: stone panel, Sign, PixelButtons and Music / Sound MenuToggles (icon + slash); the countdown keeps the font route (1 px outline verified palette-only).
- ~~Restoring the saved Music / Sound settings on launch is Story 4.2's AC. Until then a muted setting is saved and shown on the pause panel, but the buses start unmuted after a reload.~~ Done in 4.2: AudioManager applies the saved settings in `_ready()` and follows `settings_changed`.
- Windows-fallback auto-pause (desktop window focus) stays deferred (G5); only the web `focus_lost` / `visibility_hidden` signals pause.
- Esc in browser fullscreen leaves fullscreen first (browser rule); whether it also pauses is Story 5.3's check. **5.3 (2026-10-06):** not tested (M5/M6 marked pass by Smuck without a run); still open.
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

- ~~Hand-off to Story 3.1: register `zombie_run` in `data/levels/level_registry.tres` with `display_name = "Zombie Run"` (the report card heading). Without it the card falls back to `"zombie_run".capitalize()`, which happens to read the same.~~ Done in 3.1.
- ~~Final chalkboard, chalk tray, "New best!" stamp (hand-lettered, pre-rotated -8°), pixel buttons, key-hint keycaps, smiling moon and night-classroom backdrop art: Story 5.0. Today they are square `StyleBoxFlat` / `ColorRect` placeholders in palette colours.~~ Done in 5.0: chalkboard 9-slice, tray sprite, skewed stamp sprite, PixelButtons, Keycap boxes, moon and bat sprites; the wall / window / floor ColorRects stay (approved 2.9 composition).
- ~~Chalk-scratch per revealed row, the chime, the stamp thump and menu music on the report card: Story 5.1 (no `AudioCue`s exist for them yet).~~ Done in 5.1 except the stamp thump (not in FR50): post-MVP / Smuck's call.
- ~~The worn hat and pet in Professor Zombie's `%HatSlot` / `%PetSlot`, `SpriteAnchors` for the professor, and lifting the mortarboard by the hat's height: Story 4.3.~~ Done in 4.3: the professor's slots are a `HatSlot` (on `professor_anchors.tres`) and a `PetSlot` on the floor to his right, and `_stack_mortarboard` lifts the mortarboard by the hat's rise (11 px for the pumpkin).
- ~~First completed run goes through the Welcome Gift: Story 4.5 hooks into `report_card.gd` `_leave()`, the card's only navigation.~~ Done in 4.5: `_leave()` sends a card with a `RunResult` to `WELCOME_GIFT` while `welcome_bonus_claimed` is false.
- Long level names vs the stamp: at 24 px the heading has 245 px before the stamp (10 glyphs); "Pitchfork Panic" (15 glyphs = 360 px) would run under it. Epic 8 (or the 5.0 stamp art) resolves it; `test_stamp_clear_of_heading_and_rows` checks only "Test level" today.
- Professor Zombie is 32×32 at 1× (one sprite scale rule), so he is much smaller than in the mock. An exception to the rule or a 48×48 professor sprite is Smuck's call.
- ~~`test_level` has no completion bonus, so the "+N bonus" line is only seen in tests until Story 3.5.~~ Done in 3.5: a completed Zombie Run shows "+10 bonus" (seen in the web build).
- ~~The pixel-button focus look is two parts: the scene's `focus` box draws only the 2 px candy-yellow ring (outside the ink outline), and `report_card.gd` swaps the `normal`/`hover` box to the pumpkin-light fill on focus. A shared pixel-button widget/theme type (Stories 4.2 / 5.0) should absorb this. Partly done in 4.2: the `PixelButton` theme variation + `scripts/ui/pixel_button.gd` absorb it for new buttons; migrating the report card and pause panel is still Story 5.0.~~ Done in 5.0: the report card and pause panel buttons are PixelButtons; `report_card.gd` lost its own swap.

## Deferred from: code review of 2-9-chalkboard-report-card (2026-10-04)

- Soft-lock if navigation does nothing: `report_card.gd` `_leave()` sets `_leaving` before calling `navigate`; if the Router ignores or fails the call the card ignores all input. Router falls back to the menu, so only a missing menu scene triggers it. Reason: Router-level failure, very unlikely.
- No hover cue on the unfocused button (hover stylebox equals normal). Reason: placeholder chrome until Story 5.0.
- Brittle tests in `test_report_card.gd`: hard-coded `checked == 19` label count; guard boundary tests rely on 0.99 + 0.01 summing to exactly 1.0. Reason: low value.

## Deferred from: dev of story-2-10 (2026-10-04)

- Browser F-keys: in the in-app browser pane (embedded Chromium, no address bar) F2/F6/F7 reached the game and did nothing else. Real Chrome and Edge (F6 = focus address bar, F7 = caret-browsing prompt) are still unchecked; if either steals a key during a run, add it to `WebPlatform.CAPTURED_KEYS` (+ `test_web_platform.gd`). Keep the bindings as they are. **5.3:** release build: n/a (no F-key bindings in release); the debug-build question stays open.
- The open overlay (bottom ≈ 192 px on the run screen) covers the right part of `test_level`'s big letter at the top of the playfield. The HUD target box stays clear. Moving the overlay or shrinking the run section is only worth it if real levels (Epic 3) put content top-left.
- ~~`level_base.gd` raises two `UNUSED_SIGNAL` warnings (`end_requested`, `brains_earned_changed`: declared in the base, emitted only by subclasses) in desktop debug runs. They were already there at baseline whenever a run loaded; the overlay's `run_frame.gd` preload now loads the script at startup, so they print at launch instead. Fix: `@warning_ignore("unused_signal")` on both declarations.~~ Done in 3.1.
- Desktop debug key checks (F2/F6/F7 in the desktop window) weren't driven by hand: the Godot MCP can't send keys. Same code as the web debug build, which was checked end to end.

## Deferred from: dev of story-3-1 (2026-10-04)

- The open debug overlay (bottom ≈ game y 154 on the run screen) covers the active target's arrow and the top edge of its tag in Zombie Run (the letter stays readable; the HUD letter is never covered). Debug-only and toggled with F3, so not fixed. Move the overlay or trim its run section if it gets in the way of playtest debugging.
- `ZOMBIE_SCREEN_X = 224` leaves ~224 px behind the zombie for the conga line; Story 3.4 may retune it (the camera, freeing and on-screen tests read the constant). *3.4:* kept at 224: 12 × 16 px followers end at screen x 32 (tail sprite from 24) and the badge's left edge sits at 24, pinned by `test_full_line_fits_behind_the_zombie`.
- ~~Placeholder visuals: code-built target boxes / parchment tags / arrow and flat sky, grass and path rects. Real brain block, villager, backdrop and parallax art = Story 3.6. No ground tick marks were added (optional in the story); resolved targets already show the scroll.~~ Done in 3.6: the Sunny Village Green parallax backdrop, brain block, villager poof and arrow sprites (the generic `zombie_run_target.tscn` box stays the test fixture). The path tiles and grass now show the scroll, so no tick marks.
- Caps Lock hint not seen in the web check: Shift+letter presses from the browser pane don't produce it (it needs real Caps Lock). By layout every playfield item sits above the ground line y 192 and the hint starts at y 196.
- `ZombieRunTarget` resolved look duplicates the box StyleBox on resolve (one small allocation per key, outside `_process`). 3.2 / 3.3 replace the box with sprites.

## Deferred from: code review of story-3-1 (2026-10-04)

- Release builds strip the queue/session desync `assert` in `ZombieRunLevel.on_char_accepted`; add a `Log.error` (and optionally resync). Only reachable via another bug.
- ~~`ZombieRunLevel.on_run_ending` returns 0.0 without stopping movement or setting an `_ended` flag, so a key accepted in the ending frame still spawns and scoots. Revisit with the Story 3.5 outro.~~ Done in 3.5: `on_run_ending` sets `_dancing`, kills the scoot, stops the amble and returns `dance_time_s`; `RunFrame` turns input off before calling it, so no key reaches the level after it.
- `ZombieRunTarget.HALF_WIDTH` is a hand-kept copy of the tag width in the .tscn, and `resolve()` crashes if called before `add_child`. Unreachable today; revisit when 3.2/3.3 replace the box. *State after 3.2:* the brain block keeps the 24 px tag as its widest part (block 16 px, pop 10 px; `test_brain_block.gd` checks both against `HALF_WIDTH`). It is still a hand copy, so 3.3's villager must stay within it or update it. *State after 3.3:* the 24 px width rule still holds: villager sprite about 16 px opaque, poof at most 24 px, party-hat zombie 16 px; `test_villager.gd` and `test_poof.gd` check the tag and the poof against `HALF_WIDTH`.
- `_resolved` is uncapped if `_process` stops running; normal play holds about 6.
- ~~No direct test of the main menu button routing to `zombie_run` (AC2); Story 4.2 replaces the menu.~~ Done in 4.2: `test_main_menu.gd` checks the card's RUN payload and `test_screen_flow.gd::test_menu_card_routes_to_a_zombie_run` starts the level from it.
- ~~Optional ground tick marks (Task 4.11) not added; scroll cue comes from the targets only. Story 3.6 art.~~ Done in 3.6: the ground strip (path + grass tiles) scrolls exactly with the world.

## Deferred from: dev of story-3-2 (2026-10-05)

- ~~Placeholder brain block, bonk, brain pop and hop arc (code-drawn, palette only) until the Story 3.6 art. The hop/scoot timing feel (the zombie bonks while scooting under the block, 16 px arc over 0.35 s) is untuned; 3.6 adds the 3 hop frames and the "don't clobber hop" animation guard.~~ Done in 3.6: brain block idle/bonk, brain pop and hop (3f) sheets, and `PlayerZombie._play()` no longer clobbers a running hop, hug or dance. The hop/scoot timing stays untuned (unchanged).
- ~~No bonk or brain-collect SFX yet (GDD audio list "bonk"): Story 5.1, unless 3.7 takes it.~~ Done in 5.1: `sfx_brain_bonk` per brain block.
- The HUD counter just changes number; the "tick up with a small pop" (EXPERIENCE Game Feel) is 5.0/5.1, per the `BrainCounter` header.
- ~~`vo_brainsss_01.wav` is a generated placeholder (CC0) until the real voice lines in Story 5.1. In the web manual check the Brainsss line could not be confirmed by ear from the browser pane; the roll and spacing are covered by tests only.~~ Done in 5.1: two final generated takes (`vo_brainsss_01/02`, CC0), picked at random.
- ~~The hop was not visible in the browser-pane screenshots (0.35 s, 16 px, and the pause panel covers the zombie). It is verified by the unit tests (arc, cut, restart, one tween); worth a look by eye in the 3.6 art pass.~~ Done in 3.6: the hop frames (crouch, arms-up peak, land) showed mid-hop in the 1x web screenshots (`screenshots/3-6/`).

## Deferred from: code review of story-3-2 (2026-10-05)

- The run RNG has exactly one consumer (the Brainsss roll in `ZombieRunLevel.on_char_accepted`). Any later story that draws from `_rng` shifts every later roll and breaks seed replay; give new consumers their own child RNG. Revisit in 3.3. *3.3:* villagers draw nothing; still one consumer, now pinned by `test_run_rng_has_one_consumer`.
- `test_brainsss_rate_and_determinism` uses a loose 60..140 band over 2000 keys, so a chance off by about 30% still passes. Determinism is covered by a separate check; tighten if the chance gets tuned.

## Deferred from: dev of story-3-3 (2026-10-05)

- ~~The hug is a placeholder 3 px lean of `Body` on x and the poof is a code-drawn 4-frame cloud (`poof.gd`), until Story 3.6's hug (3f) and poof (4f) frames.~~ Done in 3.6: hug (3f) and poof (4f) sheets play; the 3 px lean stays as motion.
- ~~The party-hat zombie is an idle-only prototype (`party_zombie_idle.png`, 2f at 8 fps); Story 3.6 adds the walk (4f).~~ Done in 3.6: `party_zombie_walk.png` (4f at 10 fps).
- ~~No hug-poof SFX (GDD audio list "hug-poof"): Story 5.1, unless 3.7 takes it.~~ Done in 5.1: `sfx_hug_poof` as the poof starts.
- Conga hand-off for 3.4: `Villager.poofed(party_zombie)` is the seam that adds a zombie to the line, but 3.4 must count conga members logically at resolve time (a villager resolved = +1), not on `poofed`. At high speed a villager can scroll off and be freed before its poof ends (0.4 s hug + 0.33 s poof vs. about 1 s to scroll off at 5 keys/s), so `poofed` may never fire for it. *3.4:* counted at resolve; villagers aren't freed before their hand-off.
- `Villager._set_state()` asserts on a backward move. The assert logs a `SCRIPT ERROR` in the test output (3 lines from `test_villager.gd`, consumed with `assert_engine_error`), so the suite's error count is no longer 0 by design.

## Deferred from: code review of story-3.3 (2026-10-05)

- `hug_time_s` is validated only as > 0 (no upper bound, INF accepted); a very small value gives no visible lean.
- `Villager.configure()` is optional; an unconfigured villager has `_hug_time_s` 0.0 and poofs on the next frame.
- The hidden `PartyZombie` in every villager autoplays idle and logs a warning per villager if its frames are missing.
- `PlayerZombie` caches Body rest x/y once in `_ready`; stale if anything later repositions Body.
- `test_zombie_run_level.gd` tests hard-code layout-dependent counts (10 brains after 40 keys, 9 villagers in 12 keys) and call private `_process`.

## Deferred from: dev of story-3-4 (2026-10-05)

- ~~Conga followers use the party zombie's idle frames plus a code bob (2 px, 2 Hz, index-phased) until Story 3.6's walk (4f).~~ Done in 3.6: followers play walk while moving and idle once settled; the code bob stays as the conga wave.
- No join SFX when a party zombie joins the line: Story 5.1. 5.1: not in FR50, left open: post-MVP / Smuck's call.
- A join beyond the 12 cap only ticks the "×N" badge (no extra walk-in); a small pop on the badge is a 5.0 polish candidate.
- Extreme speed: a newcomer joins where its villager poofed, which can be well behind the tail (or at the left edge when the villager was kept off screen by the freeing guard), and walks in from there; the badge rides the last drawn follower, so it can lag the tail briefly. Normal speeds (the 2:00 web run, ~1 key/s average with 10-key bursts) kept the line and the badge on screen.
- The chase clamp (`minf(new_x, maxf(x, leader_x - SPACING_PX))`) is redundant with the lerp (weight is in [0, 1) and every slot is behind `leader_x - SPACING_PX`), so removing it alone fails no test; kept as a cheap guard.
- Perf (NFR1 first check): worst frame 22.7 ms over a full 2:00 web debug Zombie Run (seed 3282930552, 116 keys, conga total 87, badge showing) in the Claude desktop browser pane (Chromium 152) on the dev machine (RTX 3070, 16 threads). The target-laptop check is Story 5.3. **5.3 (2026-10-06):** no 2018-era laptop available ("Dev PC is closest"). Release build on the dev PC: pane worst 18.4 ms; Edge on the Pages build worst 17.0 ms, 0 frames > 33 ms, 60.05 FPS, conga over 100 (at DPR 2 emulation). Weak hardware still unmeasured (see "dev of story 5-3").

## Deferred from: code review of story-3-4-conga-line (2026-10-05)

- Newcomer follower pops up to 2 px on its first `step()` (join places y=0, the bob then sets y up to -2).
- A villager poofing ahead of the zombie makes its follower walk back through the zombie; followers are ordered by join order, so they can cross mid-walk.
- `CongaLine.join()` before `configure()` (max_drawn 0) shows a badge with no followers; `ZombieRunConfig.validate` has no upper bound on `conga_max_drawn` versus the screen room.
- Badge is placed right after `reset_size()` in the same frame and may use a stale size for one frame (unconfirmed).
- Test brittleness: `OS.delay_msec(5)` in test_debug_overlay and the hardcoded `brains_earned == 10` for seed 42 in the run-frame integration test.
- Perf check for NFR1 used the first run's seed, not an F2-pinned one (disclosed in the story).

## Deferred from: dev of story-3-5 (2026-10-05)

- ~~The end dance is a code placeholder (bounce 4 px at 2 beats/s + a `flip_h` per beat) until Story 3.6's `dance` 4f; `PlayerZombie.dance()` plays a `dance` animation as soon as the SpriteFrames has one. Party zombies have no dance frames in the GDD list, so the conga line keeps the code dance (3.6 decides).~~ Done in 3.6: `zombie_dance.png` (4f at 8 fps = one 2 Hz bounce); with the frames the `flip_h` beat goes. Party zombies: no dance sheet (decided), idle plus the code bounce and flip.
- No dance music or SFX: Story 5.1. 5.1: not in FR49/FR50 (the Zombie Run loop plays on through the dance), left open: post-MVP / Smuck's call.
- ~~The active target's arrow and the HUD letter stay visible during the dance; decide in 5.0 if it looks odd.~~ Decided in 5.0: leave (no change in an art story); revisit only if the 5.4 playtest shows confusion.
- The completion bonus applies to every recorded end reason (`timer`, F6, `caught`, `escaped`). Epic 8 must split Pitchfork Panic's bonuses (GDD: caught +10, escaped +25).
- The Router fade freezes the last moment of the dance (the tree is paused during the fade).
- Web manual check: once the browser pane was hidden, `requestAnimationFrame` stopped (0 calls in 2.5 s) and the run only advanced on screenshots, so a third F6 run sat in ENDING. Environment only: the same flow reached the report card after the dance while the pane was visible, and `test_zombie_run_keys_and_timer_end` pins the 1.9 s / 2.1 s timing.

## Deferred from: code review of story-3-5-run-end-dance-and-brains-award (2026-10-05)

- Dance constants (`DANCE_HOP_PX`, `DANCE_BEAT_HZ`) are duplicated in `player_zombie.gd` and `conga_line.gd`; the zombie and the line are meant to beat in step, so share one source.
- `dance_time_s` is not tied to `hug_time_s`: with an odd config a late villager could poof after the report card opens (shipped 2.0 s vs 0.4 s is fine).
- AC7 "end to end" report-card check is manual screenshots plus `test_mock_example_values`; no Zombie Run payload test.

## Deferred from: dev of story-3-6 (2026-10-05)

- Party-zombie dance sheet: decided **no** (not in the GDD sprite list). Dancing followers keep idle plus the code bounce and flip.
- No groans or SFX for the new animations: ~~Story 3.7 (groans)~~ Done in 3.7: ambience groans every 3-8 s while RUNNING. SFX for the new animations stay 5.1 (audio pass). 5.1: bonk and hug-poof done; other animation SFX are not in FR50: post-MVP.
- ~~Hat anchors on the new frames (the crown moves on some frames: hop crouch 2 px down, hop land, hug release and dance frame 4 1 px down, hug squeeze 1 px right): Story 4.3 sets per-frame anchors. `%HatSlot` still sits at the idle crown.~~ Done in 4.3: `data/anchors/zombie_anchors.tres` has a head point per frame (measured by `tools/gen_sprite_anchors.gd`, re-measured by `test_sprite_anchors.gd`), and `HatSlot` follows every frame and animation change.
- ~~HUD, pause panel, report card and menu art stay placeholder: Story 5.0.~~ Done in 5.0.
- Readability changes made during the 1x check (not in the story text): the far hills are `chalk-dim` with a `zombie-green` crest instead of solid `zombie-green` (the zombie's and party zombies' skin sat on their own colour), and the pumpkin moved to a short post in front of the fence at x 120 (on a full fence post it sat behind the zombie's head at run start and read as a pumpkin hat, which clashes with the 4.3 hats).
- The distant houses and windmill (`stone-light` on `chalk-dim`) are low contrast; accepted as far-layer decoration.
- The seam test is a heuristic (x 0 vs x 639 opacity per row); the art puts features across the seam on purpose (a cloud, the seam tree, the fence rails, the bunting). The 2:00 scroll check by eye is the real proof.

## Deferred from: code review of story-3-6-sunny-village-green-and-zombie-run-art (2026-10-05)

- Re-hug, re-hop and `_end_hop` restart the animation from frame 0 while the lean tween resumes mid-arc (`player_zombie.gd`); cosmetic.
- No hysteresis on the conga follower walk/idle threshold (`WALK_SPEED_MIN_PX_S` 4 px/s); possible flicker at easing transitions.
- Backdrop ground `roundf(camera_x)` vs the renderer snap at exact .5 values is unverified; `snap_2d_transforms_to_pixel` is on, no tie test.
- Art-review pages use the static `ANIMATIONS` list even if a sheet fails to load; debug tool only.

## Deferred from: dev of story-3-7 (2026-10-05)

- ~~Real groan recordings and the mix (groans sit at -8 dB under the Brainsss line at -6 dB for now): Story 5.1. The 4 `sfx_groan_0N.wav` files are generated placeholders.~~ Done in 5.1: four final generated formant groans (Gate A chose generated over recordings), mixed at -9 dB; final values from the Mix Checklist.
- A groan already playing is not cut when the run pauses or ends (by design: it is under 1 s, and a cut would sound like a glitch). `stop_ambience()` only stops new groans.
- Ambience runs in every level that uses `RunFrame` (Horde Rush and Pitchfork Panic get groans for free). If a level should have none, add a `LevelConfig` flag that `RunFrame` checks before `set_ambience.call(true)`.
- The 2 s mute is one-directional, as FR48 asks: a groan is skipped within 2 s after a voice line, but a voice line right after a groan still plays.
- `_last_groan_id` survives `stop_ambience()`, so the first groan after a resume never repeats the last one before the pause. Intended; noted because a reseeded `ambience_rng` alone does not reproduce the same picks.
- Web check (6.2) was partial: the Browser pane was hidden, so `requestAnimationFrame` was throttled and the countdown stalled at 3. Title, menu, Zombie Run start, the first key and pause logged no errors or warnings. The by-ear check is Smuck's.

## Deferred from: code review of story-3-7-zombie-groans-and-voice-spacing (2026-10-05)

- No test of the live pause/countdown flow with the real `AudioManager`; only recorder-seam tests cover groans stopping on pause.
- `test_default_ambience_seam_drives_the_audio_manager` leaks the frame if an assert fails before `free()`; use `autofree`.

## Deferred from: dev of story 4-2-main-menu (2026-10-05)

- `test_audio_manager.gd::test_sfx_pool_exhaustion_never_steals_the_voice_player` failed once in a full-suite run (calls 4 and 5) and passed in 6 of 6 isolated runs and the next 2 full runs. Under the headless Dummy driver `playing` flips on the mixing thread, so the 8-byte test streams end between `play()` and the `voice.playing` check and a free player gets reused legitimately. This is the same root cause as the 2.5 note above. The test needs the `_is_busy()` seam to be deterministic.
- ~~`MenuToggle`'s icon button is not in `toggle_mode` (the story said `toggle_mode = true` + `set_pressed_no_signal`): a toggled-on Button draws its `pressed` box the whole time, which hides the focused fill. The toggle keeps its own state. Story 5.0's toggle art can revisit it.~~ Done in 5.0: kept the decision; the icon art (2 frames) shows the state.
- The menu's toggle columns moved to x 240 / 352 / 464 (the story's table had 280 / 368 / 464): with 8 px gaps "Music" and "Sound" read as one word. 32 px gaps now.

## Deferred from: code review of 4-2-main-menu (2026-10-05)

- A fourth non-debug level overflows the menu's `Cards` row (608 px exactly full, no wrap or scroll).
- A long single word in a level name overflows the level card sign (WORD autowrap never breaks inside a word).
- Up from the bottom row does nothing when no level card is Available (coming-soon cards are focusable but not wired as a cross target).
- ~~`PixelButton` keeps the focused `normal` stylebox override if disabled or hidden while focused; revisit in Story 5.0.~~ Done in 5.0: the override is dropped on disable (redraw hook) and on hide; tested.
- Debug overlay jump buttons have no re-entry guard, and stay disabled when `main_menu.tscn` is run directly (F6) because `Router.current_screen` is still TITLE.
- Test hardening: `test_the_slash_carries_the_off_state` asserts constants only, the Esc test does not assert the event was handled, and the wiggle tests use real-time `wait_seconds`.

## Deferred from: dev of story 4-3 (2026-10-05)

- `HatSlot` logs every anchor move with `Log.debug(&"cosmetics", ...)` (the architecture's "DEBUG for anchor positions"). In a debug build that is one console line per animation frame (about 10 a second while walking). Release builds print nothing. If it drowns other debug output, gate it behind a verbose flag like `Log.verbose_typing`.
- The slots listen to PlayerData once, from `_ready()`, and disconnect in `_exit_tree()`. A slot removed and re-added to the tree (a reparent) would not reconnect. Nothing reparents a slot today. The Crypt Closet preview (4.4) uses `follow_equipped = false`, so it is not affected.
- The screens' `player_data` test seams (main menu, report card) don't reach their slots: a slot defaults to the live `PlayerData`. `test_main_menu.gd` sets the slots' own seams. Other screen tests assert slot type and position only, as the story asked.
- Godot quirk handled in `HatSlot._follow()`: `AnimatedSprite2D` emits `animation_changed` before it resets the frame, so the old frame index is read against the new animation for a moment. An index past the new animation's end is skipped quietly, and the reset's `frame_changed` lands the hat. A same-length switch briefly reads the new animation at the old index, then corrects within the same call.
- The fit check's `E` key writes the real save (it gives each item's price in brains, then buys and equips it, so the wallet nets zero). It is debug-only and works as specified. Story 4.5's welcome gift and the Closet (4.4) make it unnecessary. 4.4 note: the Closet now buys and wears for real; the debug key stays for art checks.

## Deferred from: dev of story 4-4 (2026-10-06)

- Final Closet art: tile frames and tags, the confirm prompt's wood panel and parchment sign, the mirror, the hand-lettered "Crypt Closet" sign (all placeholder `StyleBoxFlat`s in palette colours today), plus the brain counter tick-down and the button squish after a purchase: Story 5.0 / 5.1. Art part done in 5.0 (tile / tag 9-slices, WoodPanel, Sign, Mirror, the lettered sign; the squish is in the button art); the tick-down stays for 5.1.
- ~~The tutorial arrow and the `tutorial_seen` flag: Story 4.5. Its positions are in `sketches/crypt-closet-4-4.md` frame D; the hooks are `get_tile(id)` and `get_confirm_prompt()`, and the Closet already consumes the payload.~~ Done in 4.5: `TutorialArrow` widget; the Closet guides Buy, Yes, Wear from the `{"tutorial": true}` payload and sets `tutorial_seen` on equip or leave.
- ~~Closet music (the Closet starts no music of its own): Story 5.1.~~ Done in 5.1: the Closet, the Welcome Gift and the report card ask for `mus_menu`.
- Approved sketch deviations (Smuck, 2026-10-06, "Approve as drawn"): the long words ("Coming soon", "Need N more", "Wearing") live on the info sign for the focused tile, Buy tiles show the price on the pumpkin tag, Wearing is a drawn check mark (Press Start 2P has no U+2713), tiles are 68 px instead of DESIGN.md's 48 px, locked items show no name, and the focus ring sits on the tile's own edge (superseded in Story 5.2 Gate B: the ring now sits 2 px outside the ink edge, same ring art). DESIGN.md was not edited; the sketch is the override.
- ~~Story 5.2's grayscale review should look at the five tile states side by side: Locked (stone, "?"), Can't afford (disabled fill, no tag box), Buy (pumpkin tag), Wear (green tag, word), Wearing (bright tag, check). Buy vs Wear vs Wearing differ by tag content as well as colour, but the tag fills are close in grey.~~ Done in 5.2: all five side by side in `screenshots/5-2/18-closet-five-states-focus-buy-gray.png` (pass, Gate B); pinned by `test_grayscale_states.gd::test_the_five_tile_states_differ_by_shape_or_content`. The review also moved tile focus outside the ink edge (it vanished in grey).
- ~~The MVP tile icons are the hat's 32x32 overlay and the ghost's first idle frame, so the pumpkin sits low and small in its art box (the overlay is drawn for the head, brim on row 30). Proper tile icons belong with the Epic 9 / 5.0 art.~~ Done in 5.0 (pumpkin): the icon is an AtlasTexture cropped to the opaque pixels with a centring margin, still 32 × 32.
- Observed in the browser pane (web debug build): the first one or two mouse moves after a screen change don't move focus on hover; later moves do. The main menu (4.2) does the same, so it predates the Closet. With a real mouse the cursor sends many moves and it is barely noticeable. Worth a look in 5.0 (the Router fade or Godot's first motion after a scene swap).
- The confirm prompt closes before it emits `answered` (the story text said emit then close), so a handler always sees `is_open() == false` and can reopen it safely.

## Deferred from: code review of story-4-3-hat-and-pet-display-everywhere (2026-10-05)

- `HatSlot`/`PetSlot` connect to PlayerData only in `_ready` (reparent leaves them stale). Move to `_enter_tree` if anything starts reparenting.
- Test robustness: `test_hud.gd` and `test_report_card.gd` use the live `PlayerData` autoload (a saved hat/pet on the dev machine can change results); art-number magic constants in report card/main menu tests; fit-check key bindings and warning counts are untested.

## Deferred from: code review of story-4-4-crypt-closet (2026-10-06)

- Task 7.1 live walk was in a web export and never reached the report card; the hat on the report card is covered only by 4.3's check.
- Closet item tile wiggle tween is node-bound, so a tree pause can leave `Frame.position.x` off rest until the next wiggle.
- ~~`uid://51tlvsl155x7` in `audio_library.tres` was hand-written; if `sfx_purchase.wav.import` is regenerated with another UID Godot warns and falls back to the path.~~ Done in 5.1: the `.import` was regenerated by Godot (`uid://83x7bo15sy2k`) and the library uses it.
- ~~Placeholder jingle waveform in `tools/gen_placeholder_audio.gd` starts at -1 (masked by the 4 ms attack).~~ Done in 5.1: the tool is retired; `tools/gen_audio.gd` edge-fades every file and pins both ends to zero.

## Deferred from: dev of story-4-5 (2026-10-06)

- ~~Final Welcome Gift art (wood panel, pumpkin ribbon and bow, the brain icon) and the hand-drawn tutorial arrow: Story 5.0. Today they are palette `StyleBoxFlat`s / `ColorRect`s and a drawn triangle.~~ Done in 5.0: WoodPanel, Ribbon 9-slice, bow and 32 px brain sprites, arrow sprites.
- A gift sound, an arrow sound and the brain counter tick-up on the gift: Story 5.1. 5.1: not in FR50, left open: post-MVP / Smuck's call (the gift's button clicks).
- A tab closed mid-tutorial leaves `tutorial_seen` false. Harmless: the tutorial only starts from the gift's payload, and the gift never comes back on that save.
- The debug overlay's "Welcome gift" jump now grants +100 on a save whose `welcome_bonus_claimed` is false (that is how a dev tests the gift). On a claimed save it shows the card and grants nothing. `test_debug_overlay.gd` only records the jump through its seam; it never instances the real gift.
- The "Play with it!" button after Wear (epics design note): post-MVP.
- The browser pane throttles the web build to about 1 fps while the pane is hidden, so a live walk there stalls (it did again in 4.5, in the run's end dance). A live walk needs the pane on screen, or a desktop run with a backed-up save.

## Deferred from: code review of story-4-5 (2026-10-06)

- Integration test `test_first_purchase_flow.gd` checks only PlayerZombie HatSlot/PetSlot wiring, not a real run or report card (matches Task 5.6 wording; AC 8 prose is broader).
- Tests hard-code the 100 welcome bonus and arrow pixel coordinates (Vector2(176, 222), (38, 52)); they break on economy or layout changes.

## Deferred from: dev of story 5-0 (2026-10-06)

- Brain counter count-up tick and pop, the conga "×N" badge pop, and the Closet tick-down: Story 5.1 (juice with sound). 5.1: not in FR50, left open: post-MVP / Smuck's call.
- Web and desktop letterbox bars are still **black**: the engine draws them itself, so `default_clear_color` (now night) and the head include's night `body` don't reach them. The 1.2 item stays open; a fix needs `RenderingServer` black-bar images (out of an art story's scope).
- The first-mouse-move focus quirk after a screen change (4.4 note) was not looked at.
- The Coming soon card `Tint` is a stone `ColorRect` at 85 % alpha over the picture (the approved 4.2 look), so it blends off-palette pixels; a pre-greyed picture per level would keep it palette-only (5.2 readability pass can decide). Accepted for MVP at the 5.0 review; 5.2 grayscale: pass (plank + darker picture read clearly, G8), so it stays.
- Professor Zombie's scale is unchanged (Smuck's call).
- Level names on the cards stay font text on the parchment sign (Decision 2; Smuck did not ask for lettered names at Gate 1).
- The pause and toggle icons don't follow the pressed plank's 2 px squish (they are child sprites); the label of a PixelButton does.
- `scenes/debug/ui_art_review.tscn` ships in exports like `art_review.tscn` (dev only, never routed to).

## Deferred from: code review of 5-0-mvp-ui-art-pass (2026-10-06)

- Pause/toggle icons don't follow the pressed plank's 2 px squish (already noted under 5.0).
- Letterbox bars stay black on web/desktop; only the clear colour and `body` were changed.
- `ZombieHands._load` builds 12 texture paths at runtime: a Web export resource filter would drop them, and only the first missing file is warned.
- `scripts/debug/ui_art_review.gd` has no null guards for missing sheets and ships in exports.
- Brittle tests: exact pixel counts, hardcoded colours, label counts (`checked == 18`, `> 8`), editor-only `Image.load_from_file`.
- ~~HUD grayscale legibility (AC 5) is covered by a screenshot only, not a test.~~ Done in 5.2: the finger luma test is `test_art_ui.gd::test_lit_finger_is_brighter_in_grayscale`, the wrong-key no-colour rule is `test_grayscale_states.gd`, and the HUD shots are now made by `tools/capture_screens.gd` (repeatable).
- ~~In-run Zombie Run scenes (`zombie_run_target`, `brain_block`, `villager`, `conga_line`) still use StyleBoxFlat; deferred to 5.2 by Smuck. The 5.0 'no placeholder look' claim covers menus, screens and HUD only.~~ Done in 5.2: tags and the base box are `Sign` (resolved box `SignGrey`), the badge `BadgePumpkin`; `test_no_placeholder_chrome.gd` walks `scenes/levels/zombie_run/`.
- Coming-soon card `Tint` stays an 85 % alpha overlay; accepted for MVP by Smuck. 5.2 grayscale: pass (G8).

## Deferred from: dev of story 5-1 (2026-10-06)

- Not in FR50, so not added in 5.1 (post-MVP or Smuck's call): stamp thump, brain counter tick / ×N pop, conga join, gift and tutorial-arrow sounds, dance music, the Closet tick-down.
- Web: the first play of each 96 s music loop costs one long main-thread task (Godot decodes the whole OGG into a Web Audio sample): ~110–145 ms at the title unlock, ~165 ms entering the first run; later plays are free. Shorter loops or `PLAYBACK_TYPE_STREAM` on the music players would avoid it (stream playback risks crackle on the single-threaded web build). Part of 5.3 (technical metrics) if it shows on family computers. **5.3 (2026-10-06):** not captured on a family computer (the load-window probe step wasn't run); still open, and only the dev PC was available.
- In the browser pane the 0.5 s crossfade stretched to ~1.6 s at the run start (the pane ran ~15 fps with smoothed delta right after the level load); judged by ear in real Chrome in the Mix Checklist (M7).

## Deferred from: code review of story-5-1-mvp-audio-pass-and-mix (2026-10-06)

- Voice lines and music started in the unlock frame aren't held like SFX; title doesn't request voice at unlock today.
- Debug end / F6 while PAUSED leaves music ducked until the scene swap (debug-only).
- `sfx_wrong_key` (-14 dB) equals `mus_menu` level; tick can be masked in menus. Gate B approved the mix.
- OGG loop seam (encoder padding) untested; `tools/encode_ogg.py` has no per-file error handling.
- Default-seam tests mutate the live `AudioManager` autoload (possible state leak between tests).
- Failed `buy_item` path in the Closet plays no sound.
- `_is_busy`/`_play_player` test seams: the real `playing` guard is untested against real playback (Dummy driver limitation).

## Deferred from: dev of story 5-2 (2026-10-06)

- NFR7 "32 px" is read as the font size (Gate A); the ink of a lowercase letter is ~20 px. If playtests (5.4) show kids squinting, the next clean size is 40 or 48 px with a new HUD sketch (sign rects in `test_hud.gd`, the 104 px band budget).
- FR27's wording in `epics.md` / `game-architecture.md` still quotes the old storage notice; EXPERIENCE.md (the copy contract) has the Gate A words "This browser might forget your brains".
- The web failure notice is checked on a scratch copy of the 4.7.2 shell with the missing-features path forced; a real failed download (network) shows the same `#status-notice`, so the same CSS applies, but it was not forced in a real exported build. A Godot template upgrade must re-check that the shell still fills `#status-notice` with text nodes (the CSS hides them with `font-size: 0`).
- Report card labels and a few buttons are title case ("Keys Typed", "Play Again", "Quit to Menu") against DESIGN's sentence-case rule; kept as spec verbatim (Gate A). The copy test bans all-caps words only.
- Post-MVP copy (Locked / New! cards, the word and text prompts, Pitchfork Panic endings) must be added to `test_plain_words.gd` `APPROVED_COPY` and EXPERIENCE.md when it ships.
- Windows: an OS-level driver dialog (no OpenGL 3.3) from Godot itself is technical text we can't change.

## Deferred from: code review of story-5-2 (2026-10-06)

- Brittle counts in tests: `test_no_placeholder_chrome` `> 22` scenes, `test_plain_words` `> 80` strings and literal "Need 40 more" / "+10 bonus"; assert specific scenes and derive values from constants.
- `tools/capture_screens_runner.gd`: no null-image guard under `--headless`, no frame timeout (`frame_post_draw` never fires if minimised), no cleanup on the size-mismatch early exit. Dev-only, export-excluded.
- Plain-words test does not cover `level_card.gd`'s `String(id).capitalize()` fallback or `tooltip_text`; add when such copy ships.

## Deferred from: dev of story 5-3 (2026-10-06)

- **NFR1/NFR2 on weak hardware is unmeasured.** No 2018-era integrated-graphics laptop was available; the dev PC (Ryzen 7 5700G, RTX 3070) stood in. Re-run the probe (`tools/perf/frame_probe.js`) on the weakest family computer when one is at hand, e.g. during the 5.4 playtest.
- **Declared, not measured** (Smuck's calls, recorded as such in 5.3): M3 load times at 25 Mbit/s (wire size measured: ≈ 12.55 MB), M5 browser keys in a real run (`'` and `/` on a real keyboard still never proven), M6 1366×768 / fullscreen readability, M8 reach on another family computer. Chrome was skipped for every session ("lets skip chrome and continue").
- M7 Windows exe: the quit run's brains were written to the save (59 → 68), but the exe wasn't relaunched afterwards to show it reloads them. Smuck recorded it as passing.
- `epics.md` Story 5.3 AC 7 says "(NFR8 fallback smoke check)"; the Windows fallback is NFR5 (NFR8 is colour accessibility). For the PM; not edited.
- CI: GitHub warns `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19; check the Godot install step still works after that date.

## Deferred from: code review of story-5-3 (2026-10-06)

- NFR1/NFR2 on weak (2018-era) hardware, Chrome and Firefox remain unmeasured (pending measurement).
- M4 is aggregate only (not per round) and not run for Chrome.
- M7: exe not relaunched after the brains write; windowed 1280x720 start, no console window, F3 no overlay and ~~fullscreen toggle~~ sub-checks not recorded. ~~Fullscreen toggle (F1)~~ Done in 5.5: icon follows the real mode (`main_menu.gd` per-frame re-read; `test_main_menu_fullscreen.gd`; exe and web re-checked by Smuck, 2026-10-07).
- 5.1 OGG-decode load hitch (runbook step 3) not captured and not labelled Skipped.
- `tools/perf/frame_probe.js` key watcher matches `evt.key`, so Dead `'` (US-International) and Shift+`/` are not logged; same limit in `scripts/autoloads/web_platform.gd` `CAPTURED_KEYS`.
- Probe selftest covers only the pure maths; add `buildRun`/state-machine cases. README should note Firefox `resistFingerprinting` rounds timestamps.

## Deferred from: dev of story 5-4 (2026-10-07)

- **No kid playtest before publishing (5.4 P1, Smuck: no action).** Smuck demoed the MVP to coworkers instead ("lets mark all as good, no action, while not a kid I gave demo to coworkers"). Every kid check in `5-4-first-kid-playtest.md` is Skipped. The watch-list items still wait for kid evidence: dance-time arrow (5.0), 32 px letter size (5.2), Caps Lock hint, accuracy/WPM rounding down, Story 4.5's "Play with it!" button, the 6-year-old full keyboard note.
- **Core hypothesis: 0 of 0 kids so far (needs 2 of the first 3); all 3 come after the link is shared.** (Superseded by the 5.5 tally line below.) Ask families for the Ctrl+Shift+E export (main menu) and run `python tools/playtest/summarize_save.py <file>`.
- NFR1/NFR2 on weak hardware (5.3) is still unmeasured: no family computer was used in 5.4.
- The Ctrl+Shift+E export was verified on the Pages build in a Chromium pane (2026-10-07); Firefox is still unverified.

## Deferred from: code review of story-5-4-first-kid-playtest (2026-10-07)

- `tools/playtest/summarize_save.py` does not warn when `schema_version` is missing or newer than the script knows (the game goes read-only above `CURRENT_SCHEMA`); renamed fields would silently show "—".
- `summarize_save.py` `merge_per_key` accepts negative counts, `errors > attempts` and non-numeric `typed` values without a warning; the game never writes these.

## Deferred from: dev of story 5-5 (2026-10-07)

- **Core hypothesis: 0 of 0 kids so far (needs 2 of the first 3); all 3 come after the link is shared.** Live link (v1.0.0): https://jacob-verburg.github.io/ZombiesTeachTyping/ . Ask families for the Ctrl+Shift+E export (main menu) and run `python tools/playtest/summarize_save.py <file>`.
- The v1.0.0 live-link loop was walked only in the built-in Chromium pane (agent, cleared site data); real Chrome, Edge and Firefox on the live link were not walked. The F1 web accept path + Esc exit were checked by Smuck on the local export of the same commit (`3fbb91f`), not on Pages.
- Fullscreen press "click once" has no test seam (the live `AudioManager`); covered by code only. Toggle-once is tested.
- A `root.size_changed` during the 60-frame settle window after a Fullscreen press re-reads the mode at once and could show the old state for a frame until the window switches; not seen in any re-check.
- Still open from 5.x (not promoted at Gate A): NFR1/NFR2 on weak hardware, the first-music OGG-decode hitch, Firefox Ctrl+Shift+E, the `ubuntu-latest` → Ubuntu 26 switch on 2026-10-19.

## Deferred from: code review of story-6.1 (2026-10-07)

- Banned-word test is exact-match only (`hit` caught, `hits` not); a documented backstop, not a filter.
- `tools/tag_words.gd` does not validate `--in`/`--out` (empty `--out=`, relative paths).
- The starter-band check (>=150 words of length 3-5) runs on any `--in` list; Story 7.4's master list may need it relaxed or parameterised.
- When the runtime loader for `words.json` lands, verify in a real web export that it loads (`include_filter="data/content/*.json"`, `load()` vs `FileAccess`).

## Deferred from: code review of story-6.3 (2026-10-07)

- A huge frame `delta` (background tab, window drag) arrives every in-flight copy in one `HordeField.advance`; harmless in 6.3 but in 6.5 it would pay a burst of brains. Cap or substep the delta in 6.5.
  - Resolved in 6.5: `HordeRushLevel.MAX_FRAME_S` (0.5 s) caps each frame before substepping, so no brain burst.
- A debug jump into `horde_rush` that ends writes a real `run_history` entry with `level_id = horde_rush`; the 6.8 backfill would count it as a timer run. Already acknowledged in the 6.3 Dev Notes.
- `horde_rush_level.tscn` hard-codes five lane `ColorRect`s while `lane_count` is config-driven; revisit if the lane count ever changes.

## Deferred from: dev of story-6.4 (2026-10-07)

- Feel input for 6.7 (not tuned here): a headless minute on the shipped GDD starting numbers (0.6 / 0.8 / 1.0, no overkill avoidance, 10 seeds, the rest of the copies allowed to finish) lets through about 1% of copies at 10 WPM, 6% at 20, 11% at 25-30 and 20% at 40 WPM, far below the 40%/70% targets. The defender as specified is strong; 6.7 owns the numbers (or a weaker-defender config flag).
- Cross-ref the 6.3 huge-delta item above: 6.4's `_process` now splits a long frame into equal steps of at most 1/30 s, so a hitch no longer skips throws or contacts, but the total is still uncapped (a 10 s hitch = 300 logic steps in one frame and still marches copies home). The 6.5 cap fixes both the brain burst and the step count.
  - Resolved in 6.5: `_process` caps a frame at `MAX_FRAME_S` (0.5 s, at most 15 steps); the rest of a hitch is dropped.

## Deferred from: code review of story-6.4 (2026-10-07)

- Projectile views and tomatoes freeze mid-air after `on_run_ending` (`_frozen` stops `_process`) and stay on screen until `_reset`; the 6.5 outro must clear them.
  - Resolved in 6.5: `on_run_ending` frees every projectile view and clears `_projectile_views` (the outro).
