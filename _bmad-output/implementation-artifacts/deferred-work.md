
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
- One tab switch fires both `focus_lost` and `visibility_hidden`. Story 2.7's auto-pause must be idempotent (or listen to one signal).
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
- Story 2.4: the `RunFrame` run is the first end-to-end keyboard check of `TypingInput` (no scene or caller exists until then). Run-screen buttons must be `FOCUS_NONE` so Space/Enter can't press them.

## Deferred from: code review of story-2-1-typing-input-filtering (2026-10-03)

- `TypingInput` keeps the Caps Lock streak and `_caps_suspected` across focus loss or pause; only `configure()` resets them. Handle in Story 2.4/2.7.
- `TypingInput._unhandled_input` marks printable keys handled whenever the node is in the tree, and an unconfigured node behaves as lowercase. Add an enabled / active-run gate in Story 2.4.
- Web Caps Lock state is not read directly (no `getModifierState`); the hint relies on the capital streak only. Revisit in web QA.
- Caps Lock hint counts Shift-held capitals (e.g. "NASA") as evidence of Caps Lock, as AC 6 specifies. Kept by decision; revisit after playtests (option: count only capitals typed without Shift).
