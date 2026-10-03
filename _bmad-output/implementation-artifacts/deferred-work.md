
## Deferred from: code review of story-1-1 (2026-10-02)

- `test_debug_disabled_in_release` does not verify that nothing printed; only the `is_level_enabled` seam is tested.
- `Log.verbose_typing` is declared but not consumed; wire it up when per-keystroke logging arrives (Epic 2).
- `directory_rules={"res://addons": 0}` not persisted in `project.godot`; relies on the Godot 4.7 default.
- `Log.debug` evaluates its `msg` argument even when DEBUG is disabled; keep calls out of hot paths.
- GUT plugin is enabled in `project.godot`; confirm the web export (Story 1.2) excludes `addons/gut`.

## Deferred from: dev of story-1-2 (2026-10-02)

- Web letterbox bars render **black**, not night `#2B1D3F` (DESIGN.md marks night bars as `[ASSUMPTION]`). Not required by Story 1.2 AC 5. Natural home: Story 5.0 (loading page / boot splash styling); options are the HTML page background in `html/head_include` plus the engine's black-bar color.
- Firefox checks for Story 1.2 AC 4/5 (load times, 1366×768 screenshot) were skipped because Firefox isn't installed. Stories 1.5 (key capture and quick-find) and 1.7 (reload and tab-close persistence, NFR4) require Firefox: install it before those stories, and re-run the 1.2 Firefox checks then.

## Deferred from: dev of story-1-3 (2026-10-02)

- Godot imports files inside `build/` (e.g. `build/web/index.icon.png.import` exists since the 1.2 export). Harmless: `build/` is gitignored and export-excluded. Add an empty `build/.gdignore` (recreated after each clean) or export outside the project if it ever slows imports.
- Font is Press Start 2P (wide, arcade look) because Pixelify Sans failed the O/0 check. If Story 1.9 or 5.0 wants a rounder face, any replacement must pass `test_ui_theme.gd` and have a native size that divides 16/24/32/64.

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
- Desktop `WebPlatform.offer_download()` ignores `bytes` and only opens `user://`. Story 1.8 must write the save to `user://<file_name>` (check the FileAccess error) before opening the folder, or the desktop export silently loses data.
- The temporary Keyboard Test button on the main menu ships in release builds (desktop Download opens Explorer, Fullscreen flips the window). Gate on `OS.is_debug_build()` or remove the screen in 1.8/5.0.
- `test_unlock_is_idempotent` (passes with or without the guard) and the `is_fullscreen` test (expected value computed with the same expression) can't fail. Needs the same playing/mode seam as the 1.4 deferrals.
- One tab switch fires both `focus_lost` and `visibility_hidden`. Story 2.7's auto-pause must be idempotent (or listen to one signal).
- Story 1.5 browser evidence not recorded: Firefox per-key table (quick-find on `'` and `/`, Tab focus, Backspace), Esc-in-fullscreen in Chrome/Edge/Firefox (incl. whether the first Esc reaches the game; UX open question 4), and `is_storage_persistent()` in normal and private windows. The JS key listener ships enabled as a hedge. Reason: Firefox not installed; verify alongside Story 1.7, which needs Firefox anyway.

## Deferred from: dev of story-1-6 (2026-10-03)

- **Web: a write made inside the `visibility_hidden` handler may not reach IndexedDB.** Godot syncs `user://` to IndexedDB asynchronously from its main loop, and a hidden tab stops `requestAnimationFrame`. `SaveService` writes synchronously on `visibility_hidden`, but nothing proves the sync completes before a tab close. Story 1.7's 10-reload / 10-tab-close test (NFR4) must measure it, along with whether `DirAccess.rename_absolute` is reliable on the web file system (the direct-write fallback logs `rename failed` if not). If data is lost, the fix belongs in `WebPlatform` (Boundary 3).
- The `save_now()` failure paths (tmp write failure, rename failure → direct write, backup copy failure) are covered by code review only; GUT can't easily make `FileAccess`/`DirAccess` fail on desktop. A small IO seam would make them testable if a real failure ever shows up.
- Desktop `WebPlatform.offer_download()` (see 1.5 deferral): when 1.8 writes the export to `user://`, route the file write through `SaveService` so the "only `SaveService` touches files" rule holds.
- Pre-existing: `tests/unit/test_keyboard_test.gd` uses the deprecated GUT `wait_frames` (the suite's single "Deprecated" line). Swap for `wait_process_frames` or `wait_physics_frames` when that file is next touched.

## Deferred from: code review of story-1-6-versioned-save-file (2026-10-03)

- Array element types are not validated (`owned_items` strings, `run_history` dictionaries); only hand-edited saves can produce bad elements. Add when PlayerData/Shop consume them.
- A fractional float in an int-default field (`best_wpm`, `brains`) resets the field to 0 in `SaveSchema._merge`. Decide when `best_wpm` semantics are defined.
- A complete `save.tmp` left by a crash between write and rename is ignored on load, so one extra generation of progress is lost. Prefer it over `save.bak` if this ever matters.
- A UTF-8 BOM in a hand-edited or imported save fails to parse. Strip it in Story 1.8's import.
- `SaveService.load_save()` is public and does not assign `_data`. Make it private once nothing else calls it.
- The close-request hook misses `get_tree().quit()`, mobile pause and focus-out. Revisit with a Quit button or a mobile target.
- Web: two tabs share one IndexedDB (last writer wins), `run_history` is unbounded, and storage-unavailable (private window, quota) is only logged. Cover in Story 1.7 browser evidence and Epic 5.
