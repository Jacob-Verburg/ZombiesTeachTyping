---
baseline_commit: 3798a0c6c79ba734d028e6847ed7c55257b7cd52
---

# Story 1.8: Debug Overlay and Save Export

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer,
I want a debug-only overlay with frame timing, save status and a few cheats, plus a save export that also works in release,
so that I can check performance, test saves quickly and pull playtest run history, without shipping cheats.

## Acceptance Criteria

1. **Overlay (debug build).** Given a debug build, when F3 is pressed, then `scenes/debug/debug_overlay.tscn` toggles on top of every screen, showing FPS, frame time, the worst frame in the last 10 s, the last save write time and whether storage is persistent.
2. **Cheats while open.** Given the overlay is open, when F5 is pressed, then 100 brains are added through `PlayerData.add_brains()`; F8 asks for confirmation and then resets the save to defaults; F9 exports the save (AC 3's export). With the overlay closed, F5/F8/F9 do nothing.
3. **Save export (any build).** Given any build (debug or release) on the main menu (placeholder for now), when Ctrl+Shift+E is pressed, then `SaveService.export_json()` is passed to `WebPlatform.offer_download()` as `zts-save-YYYYMMDD.json`, and nothing on screen changes (no visible UI for kids).
4. **Release gating.** Given a release export, when it runs, then the overlay scene is never instanced and F3/F5/F8/F9 do nothing (gated by `OS.is_debug_build()`), while Ctrl+Shift+E still works.
5. **Tests.** The pure and seam-able parts (frame tracker, export file name, reset, reset confirmation, cheat gating, release gating) are covered by GUT tests that pass.

AC 1–4 are the epic's, verbatim in intent. AC 5 is added: the epic has no test AC for this story, but the architecture requires tests first for logic.

## Tasks / Subtasks

- [x] **Task 1: Tests first** (AC: 1, 2, 3, 4, 5). Write the tests listed in Dev Notes → Testing requirements, run GUT, watch them fail.
- [x] **Task 2: `SaveService` additions** (AC: 2, 3). In `scripts/autoloads/save_service.gd`:
  - [x] 2.1 `static func export_file_name(unix_time: float = -1.0) -> String` returning `zts-save-YYYYMMDD.json` from the **local** date (`Time.get_date_dict_from_unix_time(unix_time + Time.get_time_zone_from_system()["bias"] * 60)`, or `Time.get_datetime_dict_from_system()` when `unix_time < 0`; pick one approach and test it with a fixed time). Zero-pad month and day (`"%04d%02d%02d"`). Pure; no `const` file-name literal elsewhere.
  - [x] 2.2 `func offer_export() -> void`: the one place that delivers the save. It builds `export_json().to_utf8_buffer()` and `export_file_name()`. **Desktop (`not WebPlatform.is_web()`):** first write the text to `save_dir.path_join(file_name)` with the existing `_write_text()` (log `Log.error(&"save", ...)` and still continue to `offer_download` if it fails), because `WebPlatform.offer_download()` on desktop only opens the `user://` folder and ignores the bytes (1.5 and 1.6 deferrals). Then call `WebPlatform.offer_download(bytes, file_name)` on both platforms. This keeps "only `SaveService` touches files" true: `WebPlatform` stays file-free. Never log the contents (NFR12).
  - [x] 2.3 `func reset_to_defaults() -> void`: replaces `_data` with `SaveSchema.defaults()` (after `SaveSchema.prepare`, not needed for fresh defaults), clears `_read_only` (a deliberate reset must be writable), then `request_save()`. It must **not** clear `_main_valid`, so the next write copies the old `save.json` to `save.bak` (a mis-pressed F8 is recoverable by hand). Log `Log.info(&"save", "reset to defaults")`. PlayerData only calls this (same rule as `get_data()`).
  - [x] 2.4 Update the `##` header: mention `offer_export()` and `reset_to_defaults()`; "PlayerData only" applies to `reset_to_defaults()`, while `offer_export()` and `export_file_name()` are callable by the main menu and the debug overlay.
- [x] **Task 3: `PlayerData.reset_all()` and `profile_replaced`** (AC: 2). In `scripts/autoloads/player_data.gd`:
  - [x] 3.1 `signal profile_replaced` (past tense, no params). It is the "profile replaced" notification deferred from the 1.7 review: anything bound to a profile value re-reads on it.
  - [x] 3.2 `func reset_all() -> void`: `save_service.reset_to_defaults()`, then `profile_replaced.emit()`. Do not emit `brains_changed`/`settings_changed` (they are deltas; listeners that care connect `profile_replaced`). Update the header (reset is the one mutation that replaces the whole profile; Epic 11's profile switch will emit the same signal).
  - [x] 3.3 `scripts/screens/keyboard_test.gd`: connect `PlayerData.profile_replaced` to `_on_player_data_profile_replaced`, which re-reads `PlayerData.get_brains()` into `%BrainsLabel` (use the existing `_show_brains()`); disconnect in `_exit_tree()` with an `is_connected` guard, as it already does for `brains_changed`. This keeps the temporary counter honest after F8.
- [x] **Task 4: Frame tracker (pure)** (AC: 1). `scripts/debug/frame_tracker.gd`, `class_name FrameTracker extends RefCounted`:
  - [x] 4.1 `const WINDOW_SEC: float = 10.0` (the "worst frame in the last 10 s"). `func record(now_sec: float, frame_ms: float) -> void` appends to a ring of `(now_sec, frame_ms)` and drops entries older than `now_sec - WINDOW_SEC`. `func worst_ms() -> float` (0.0 when empty). `func last_ms() -> float`. `func clear() -> void`.
  - [x] 4.2 Takes time as a parameter (no `Time` calls) so tests are deterministic. Pure: no nodes, no autoloads (Boundary 1 spirit; it lives in `scripts/debug/` per Boundary 7).
- [x] **Task 5: Debug overlay scene and script** (AC: 1, 2, 4). `scenes/debug/debug_overlay.tscn` (root `CanvasLayer`) + `scripts/debug/debug_overlay.gd`. Remove the `.gitkeep` files in `scenes/debug/` and `scripts/debug/` once real files exist.
  - [x] 5.1 Scene: `CanvasLayer` (`layer = 110`, above Router's fade layer 100) → `Panel` (`%Panel`, top-left, `mouse_filter = 2`, dark translucent `StyleBoxFlat`) → `VBoxContainer` with `%StatsLabel` (FPS, frame time, worst), `%SaveLabel` (save status), `%HelpLabel` (`"F5 +100 brains   F8 reset   F9 export"`), `%ConfirmLabel` (hidden unless confirming). Every control `mouse_filter = 2` (it must never block clicks). `Label` font size 8 (Press Start 2P's native 8 px; the 640×360 canvas has no room for 16 px text here). The overlay starts **hidden** (`visible = false` on the CanvasLayer, which hides its children) and `process_mode = PROCESS_MODE_ALWAYS` so F3 and the numbers still work when the tree is paused (run pause, Router fade).
  - [x] 5.2 Input: handle keys in `_input(event)` (not `_unhandled_input`): the keyboard test screen swallows every key in `_unhandled_input`, so the overlay would never see F3 there. Act only on `InputEventKey` with `pressed and not echo`, no modifiers. F3 → toggle; call `get_viewport().set_input_as_handled()` for the keys the overlay uses (F3 always; F5/F8/F9 only while open) so a screen never also reacts to them. Use physical keys `KEY_F3/F5/F8/F9` on `event.keycode` (function keys have no layout issue). Do not add InputMap actions.
  - [x] 5.3 Stats: `_process(delta)` runs **only while open** (`set_process(visible)` in the toggle; closed = zero cost). Each frame: `_tracker.record(Time.get_ticks_msec() / 1000.0, delta * 1000.0)`. Refresh the labels at a fixed rate with a `Timer` child (0.25 s; no per-frame string formatting): `"FPS %d   Frame %.1f ms"`, `"Worst 10 s: %.1f ms"`. `Engine.get_frames_per_second()` for FPS. Clear the tracker when the overlay opens so old numbers don't appear. Never log in `_process` (architecture hot-path rule).
  - [x] 5.4 Save status: `"Last save: never"` when `SaveService.last_write_ticks_msec < 0`, else `"Last save: %.1f s ago"`; and `"Storage: persistent"` / `"Storage: NOT persistent"` from `WebPlatform.is_storage_persistent()`. The format helper is a `static func format_save_age(last_write_ticks_msec: int, now_msec: int) -> String` (pure, tested). Same labels as the Keyboard Test screen's "Last save", same read-only access.
  - [x] 5.5 Cheats, only while open:
    - **F5:** `PlayerData.add_brains(CHEAT_BRAINS)` with `const CHEAT_BRAINS: int = 100` (dev cheat, not a balance number).
    - **F9:** `SaveService.offer_export()` (the same path as Ctrl+Shift+E).
    - **F8:** two-step confirm. First press → `_confirming = true`, show `%ConfirmLabel` `"Reset the save? F8 again = yes, any other key = no"`, start a 5 s `Timer` (`CONFIRM_SEC`) that cancels. Second F8 within the window → `PlayerData.reset_all()`, hide the confirm. **Any other key** (including F3 closing the overlay), the timeout, or closing the overlay cancels. A pure-ish seam: `func _handle_key(keycode: Key) -> bool` returns whether the key was consumed, and the confirm state is readable through `is_confirming()`; `_input` is a thin wrapper that builds nothing but calls it. This is what the tests drive (no synthetic `InputEvent` plumbing).
  - [x] 5.6 No F6/F7 and no run-state, target, WPM or seed sections: those arrive with Stories 2.4/2.10 (the epic's Story 2.10 extends this overlay). Structure the script so adding a section is one more label plus one more `_refresh_*`; do not stub the later sections now.
  - [x] 5.7 `##` header: debug-only, instanced by Router only when `OS.is_debug_build()` (Boundary 7), keys, confirm rule, why `_input`.
- [x] **Task 6: Instance the overlay in debug builds only** (AC: 4). In `scripts/autoloads/router.gd` `_ready()`, after the fade layer:
  - [x] 6.1 `if _is_debug_build(): _add_debug_overlay()` where `func _is_debug_build() -> bool: return OS.is_debug_build()` is the test seam (the only `OS.is_debug_build()` call in this story; `Log.debug_enabled` is a different seam and not used for gating).
  - [x] 6.2 `_add_debug_overlay()` loads `DEBUG_OVERLAY_PATH = "res://scenes/debug/debug_overlay.tscn"` with `ResourceLoader.load()` (a path, **not** `preload`, the same reasoning as `SCREEN_PATHS`: a missing file must log, not break the parse). On failure `Log.error(&"router", ...)` and carry on. Add the instance as a child of the Router with `name = "DebugOverlay"`. Router is the last autoload and is `PROCESS_MODE_ALWAYS`; the overlay is a CanvasLayer so it follows no scene changes (it persists across `change_scene_to_packed`).
  - [x] 6.3 Why Router and not a new autoload: the autoload list and order are asserted by `test_project_settings.gd` and the architecture fixes it at five; a sixth would change both. Say so in the Router header and in Completion Notes. Router stays navigation-only otherwise (a 3-line debug hook, no logic).
  - [x] 6.4 Update the Router `##` header (mentions the debug overlay hook; Boundary 7).
- [x] **Task 7: Ctrl+Shift+E on the main menu** (AC: 3). In `scripts/screens/main_menu.gd`:
  - [x] 7.1 Add `_unhandled_input(event)`: if `InputEventKey`, `pressed`, `not echo`, `keycode == KEY_E`, `ctrl_pressed and shift_pressed`, and **not** alt/meta: `get_viewport().set_input_as_handled()` and `SaveService.offer_export()`. No sound, no label, no focus change, no fade (AC: nothing on screen changes). Extract the match into `static func is_export_chord(event: InputEventKey) -> bool` (pure; tested).
  - [x] 7.2 This runs in **release too**: no `OS.is_debug_build()` check anywhere on this path.
  - [x] 7.3 Keep everything else in the menu: payload label, 4 buttons, storage notice, `PlayButton.grab_focus()`. Update the header.
- [x] **Task 8: Verify** (AC: all)
  - [x] 8.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then GUT: all tests pass (154 at HEAD + new), exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.
  - [x] 8.2 Boundary greps: `grep -rn "FileAccess\|DirAccess" scripts/` → only `save_service.gd`; `grep -rn "get_active_profile\|get_data()\|reset_to_defaults" scripts/` → callers only in `player_data.gd`; `grep -rn "request_save" scripts/` → only `player_data.gd` and `save_service.gd`; `grep -rn "is_debug_build" scripts/` → `log.gd` (existing) and `router.gd` (new) only; `grep -rn "debug_overlay\|scripts/debug" scripts/ scenes/` → only the Router's path constant and the debug folders themselves.
  - [x] 8.3 Desktop run (Godot MCP `run_project` + `get_debug_output`, window driven as in 1.7's 5.3): F3 opens/closes on Title, Menu and Keyboard Test (including during the fade); numbers update; F5 ×2 → Keyboard Test counter +200; F8 once → confirm text shown, any other key cancels (counter unchanged), F8 F8 → counter 0 and `save.bak` holds the previous brains, `[INFO][save] reset to defaults`; F9 → desktop writes `user://zts-save-YYYYMMDD.json` (check it exists and parses to the current save) and opens the folder; Ctrl+Shift+E on the Main Menu does the same with the overlay closed; F5/F8/F9 do nothing with the overlay closed. Screenshot the overlay on the Keyboard Test screen to check it fits 640×360 and doesn't overlap the box (move it to the corner that is free if it does). Note: this resets and edits Smuck's real desktop save (brains 4 from 1.7); tell Smuck before F8 and restore from `save.bak` or leave defaults, don't hide it.
  - [x] 8.4 Web debug build (`mkdir -p build/web`, export **Web** with `--export-debug`, serve with `python -m http.server 8060 -d build/web`): in Smuck's Chrome and Edge, F3 shows the overlay with `Storage: persistent`; F5 adds 100 and survives a reload; F8-F8 resets and survives a reload; **F9 and Ctrl+Shift+E each download `zts-save-YYYYMMDD.json`** (open it: valid JSON, `schema_version`, `profiles.p1.brains`). Check that the browser does not steal Ctrl+Shift+E (Chrome and Edge dev tools do not use it, but record it; Firefox's Network tool does and Firefox is still not installed: open item, don't fix here). Check that the keyboard test screen's key capture still works with the overlay present.
  - [x] 8.5 Web **release** build (`--export-release`, as CI does): F3/F5/F8/F9 do nothing (no overlay node: `get_tree().root` has no `DebugOverlay`, checkable through the browser console only indirectly, so just confirm F3 does nothing), Ctrl+Shift+E downloads the file on the main menu. If a release export is awkward locally, the CI-deployed Pages build is an acceptable place to check after the push; record which was used.
  - [x] 8.6 Update `sprint-status.yaml` (`review` when done) and `deferred-work.md` (strike the 1.5/1.6 `offer_download` desktop deferrals and the 1.7 "profile replaced" deferral; add anything new).

### Review Findings

- [x] [Review][Defer] F8 reset on a read-only (newer-schema) save clears `_read_only`, and a second reset overwrites the only `save.bak` copy of the newer-build save [scripts/autoloads/save_service.gd:184-189] — deferred, kept as specified (spec 2.3); dev-only trigger
- [x] [Review][Patch] `offer_export()` still calls `offer_download` after a failed desktop write, so it opens a folder with no export [scripts/autoloads/save_service.gd:160-170]
- [x] [Review][Patch] A pure modifier key press (Shift/Ctrl/Alt alone) cancels a pending F8 confirm; ignore bare modifier keycodes [scripts/debug/debug_overlay.gd:_input]
- [x] [Review][Patch] `_process` records the time-scaled `delta`, not real frame time, so frame ms is wrong when `Engine.time_scale != 1`; derive it from `Time.get_ticks_usec` [scripts/debug/debug_overlay.gd:_process]
- [x] [Review][Defer] No tests drive `_input` / `_unhandled_input` (modifier cancel, echo, Ctrl+Shift+E to `offer_export`), only `_handle_key` and the static predicate [tests/unit/test_debug_overlay.gd, tests/unit/test_main_menu.gd] — deferred, covered by manual checks in 8.3/8.4
- [x] [Review][Defer] Export file name is date-only, so same-day exports overwrite each other, and exports accumulate in `user://` [scripts/autoloads/save_service.gd:export_file_name] — deferred, dev/playtest convenience
- [x] [Review][Defer] `export_file_name` uses the current timezone bias, not the bias at that date (DST edge); the test mirrors the formula [scripts/autoloads/save_service.gd:151-159] — deferred, low impact
- [x] [Review][Defer] Desktop `offer_download` always opens `user://`, not `save_dir` [scripts/autoloads/web_platform.gd:78-81] — deferred, only differs in tests
- [x] [Review][Defer] Web `download_buffer` has no failure feedback (blocked download) [scripts/autoloads/web_platform.gd:84] — deferred
- [x] [Review][Defer] `OS.is_debug_build()` is true for a debug web export, which would ship F5/F8 cheats to players [scripts/autoloads/router.gd] — deferred, check export presets before playtests
- [x] [Review][Defer] Ctrl+Shift+E uses `keycode` (layout-dependent), only fires on the main menu, and may be captured by the browser (Firefox Network tool) [scripts/screens/main_menu.gd:262-267] — deferred, already noted in dev notes
- [x] [Review][Defer] `reset_to_defaults()` defers its write with `request_save()`, so a tab close in the same frame could lose it, and a failed write gives no UI feedback [scripts/autoloads/save_service.gd:184-189] — deferred
- [x] [Review][Defer] `reset_all()` does not re-apply settings (e.g. audio mute) to other systems [scripts/autoloads/player_data.gd:62-66] — deferred, no settings UI yet
- [x] [Review][Defer] Each Router instance in tests adds its own overlay, and the debug-build test assumes a debug runner [tests/unit/test_router.gd:390-411] — deferred, test brittleness
- [x] [Review][Defer] "Worst 10 s" is pinned by one huge frame after a hidden tab is restored; F-keys may conflict with Story 2.1's typing screens [scripts/debug/frame_tracker.gd, debug_overlay.gd] — deferred

## Dev Notes

### Scope boundaries (what this story is NOT)

- **Only F3, F5, F8, F9 and Ctrl+Shift+E.** No F6 (end run), no F7 (verbose typing), no run state / clock / target / WPM / seed sections, no `debug_seed`: the architecture lists them but they depend on code that doesn't exist yet (Epic 2, Story 2.10 extends this overlay). The epic's ACs for 1.8 name exactly the five keys above.
- **No save import.** "Save export" only. (The 1.6 deferral about stripping a UTF-8 BOM "in Story 1.8's import" doesn't apply: nothing imports; leave that deferral open.)
- **No visible UI for kids.** The only on-screen additions are debug-only. Ctrl+Shift+E has no feedback of any kind.
- **No real main menu** (Story 4.2 rebuilds it and must keep the chord and the storage notice). Don't restyle the placeholder menu.
- **Don't remove or gate the temporary Keyboard Test screen/button** (deferred from 1.5; Epic 5.3 may still use it on family computers). Mention in Completion Notes that it still ships in release.
- **Don't touch** `project.godot`, `export_presets.cfg`, CI, `AudioManager`, `GameConstants`, `SaveSchema` (the defaults are used as they are).

### Current state of files being modified

- **`scripts/autoloads/save_service.gd`** (1.6, read in full while creating this story): loads in `_ready()`; `_data`, `_dirty`, `_flush_scheduled`, `_main_valid`, `_read_only` private; `save_dir` is the test seam; `request_save()` coalesces; `save_now()` writes tmp → copies good `save.json` to `save.bak` → renames; `export_json()` already exists and returns exactly what `save_now()` writes (`JSON.stringify(_data, "\t")`); `_write_text(path, text)` helper (returns `Error`). `get_data()`/`get_active_profile()` are "PlayerData only". **Preserve:** every existing behaviour and its tests (`test_save_service.gd`); the new methods are additive.
- **`scripts/autoloads/player_data.gd`** (1.7, done): `brains_changed`, `settings_changed`, `save_service` seam typed as the preloaded script, `_profile()` re-reads `get_active_profile()` every call (so a reset is picked up with no change to the getters; a 1.7 test already proves this). **Preserve** all of it; add `profile_replaced` and `reset_all()` only.
- **`scripts/autoloads/web_platform.gd`**: `offer_download(bytes, file_name)` logs `download offered: <name> (<n> bytes)`; on web calls `JavaScriptBridge.download_buffer(bytes, file_name, mime)` with `application/json` for `.json`; on desktop **ignores `bytes`** and calls `OS.shell_open(globalize_path("user://"))`. `is_web()` is the test seam. **No change in this story** (the desktop gap is closed by `SaveService.offer_export()` writing the file first).
- **`scripts/autoloads/router.gd`**: `_ready()` builds the `FadeLayer` (layer 100). `PROCESS_MODE_ALWAYS` already. **Preserve** `go()`, the fade, payloads, fallbacks (`test_router.gd`). Add only the debug hook (Task 6).
- **`scripts/screens/main_menu.gd` / `scenes/screens/main_menu.tscn`** (1.3, 1.5, 1.7): `_ready()` takes the payload, connects four buttons, sets the notice, `PlayButton.grab_focus()`. It has **no** `_unhandled_input` today. `tests/unit/test_main_menu.gd` (disabled instance, `process_mode = DISABLED`) and `tests/integration/test_screen_flow.gd` must keep passing.
- **`scripts/screens/keyboard_test.gd`**: `_unhandled_input` swallows **every** key (hence the overlay uses `_input`). `_show_brains()` already exists from 1.7. Add the `profile_replaced` connection only.
- **`scenes/debug/.gitkeep`, `scripts/debug/.gitkeep`**: empty placeholders from 1.1; delete them when the real files land.
- **`tests/unit/test_project_settings.gd`**: asserts the five autoloads and their order. Must still pass (no sixth autoload).
- **Export presets**: `export_filter="all_resources"`, so `scenes/debug/` and `scripts/debug/` **are** in release exports; they are simply never instanced there. That satisfies AC 4 ("the overlay scene is never instanced"); don't add excludes (a debug web export for local testing needs them, and `test_export_presets.gd` only requires a minimum list).

### Design decisions already made (don't reopen)

1. **Overlay host = Router** (Task 6.3). No sixth autoload.
2. **Delivery helper in `SaveService`** (`offer_export()`), so both call sites (F9, Ctrl+Shift+E) are one line and the desktop file write stays inside the only file-touching script.
3. **Reset = `PlayerData.reset_all()`** (the overlay never touches `SaveService.reset_to_defaults()` directly: Boundary 4 and "PlayerData only"). It emits `profile_replaced`.
4. **Reset keeps the backup chain:** the next write copies the old `save.json` to `save.bak`. That is why `_main_valid` is left alone.
5. **Two-step confirm on F8** (second F8 within 5 s), not a modal dialog: no focus handling, no mouse needed, no new theme work, and a kid can't reach it (debug build only).
6. **File name uses the local date** (`zts-save-YYYYMMDD.json`), because Smuck reads it as "the day I played".
7. **`_input`, not `_unhandled_input`**, for the overlay, so F3 works on the Keyboard Test screen and during pauses (`PROCESS_MODE_ALWAYS`).

### Architecture compliance

- **Debug Tools** (architecture → Debug Tools): overlay scene `scenes/debug/debug_overlay.tscn`, CanvasLayer on top; cheat keys only while open; `F9` = same as the release-safe export; activation F3; "everything except the save export is gated by `OS.is_debug_build()`, the overlay scene is instanced only in debug builds". **Boundary 7:** debug code lives only in `scenes/debug/` and `scripts/debug/` and is instanced only when `OS.is_debug_build()`. (The `SaveService`/`PlayerData`/main-menu additions are release-safe features, not debug code, and live where they belong; the overlay script and `FrameTracker` live in `scripts/debug/`.)
- **Boundary 3:** only `SaveService` touches files (desktop export write goes through it); only `WebPlatform` touches browser APIs (the download). **Boundary 4:** the overlay's F5 and F8 go through `PlayerData` methods; the menu and overlay navigate nowhere. **Boundary 1:** `FrameTracker` is pure.
- **Event naming:** `profile_replaced` (past tense). Handlers `_on_player_data_profile_replaced`. Listeners connect in `_ready()` with Callables and disconnect in `_exit_tree()`.
- **Hot path:** nothing logged per frame; the overlay's `_process` is off while closed and does no string work per frame.
- **Static typing everywhere** (`untyped_declaration = Error`); IDs as `StringName`; no balance numbers (`CHEAT_BRAINS`, `WINDOW_SEC`, `CONFIRM_SEC` are named dev constants).
- **Logging:** tags `&"save"` (reset, export write failure), `&"web"` (already logged by `offer_download`), `&"router"` (overlay load failure). Never log save contents (NFR12). One `Log.info` per reset and per export offer, no more.
- **Error handling:** a failed overlay load or desktop export write is logged and ignored; nothing shown to the player.
- **Kid-facing:** nothing. All overlay text is English dev text and never ships in release.

### File structure requirements

New:
```
scenes/debug/debug_overlay.tscn
scripts/debug/debug_overlay.gd (+ .uid)
scripts/debug/frame_tracker.gd (+ .uid)
tests/unit/test_frame_tracker.gd (+ .uid)
tests/unit/test_debug_overlay.gd (+ .uid)
```
Modified: `scripts/autoloads/save_service.gd`, `scripts/autoloads/player_data.gd`, `scripts/autoloads/router.gd`, `scripts/screens/main_menu.gd`, `scripts/screens/keyboard_test.gd`, `tests/unit/test_save_service.gd`, `tests/unit/test_player_data.gd`, `tests/unit/test_router.gd`, `tests/unit/test_main_menu.gd`, `tests/unit/test_keyboard_test.gd`, `sprint-status.yaml`, `deferred-work.md`, this story file. Deleted: the two `.gitkeep` files in `scenes/debug/` and `scripts/debug/`. New `.uid` files are created by `--import`; commit them.

### Testing requirements

GUT 9.7.1 facts (carried from 1.1–1.7):
- An unexpected `push_error` **fails** the test; assert expected ones with `assert_push_error("…")` (and `assert_push_warning`).
- **Never test through the live autoloads that write.** A mutation through live `PlayerData`/`SaveService` changes and writes Smuck's real save at the end of the frame. Use fresh instances with `save_dir = "user://test_<name>/"` set before `add_child_autofree` (copy `_make()`/`_clear()` from `test_player_data.gd` / `test_save_service.gd`). The overlay must be testable with injected `PlayerData`/`SaveService` instances: give `debug_overlay.gd` two seam vars, `player_data: Node = null` and `save_service: Node = null`, defaulting in `_ready()` to the live autoloads (type them as the preloaded scripts like 1.7 does if that parses), and tests assign fresh instances **before** `add_child_autofree`.
- Desktop `OS.is_debug_build()` is `true` under GUT, so release gating is tested through the Router's `_is_debug_build()` seam, not by the real flag.
- Use `wait_process_frames`, never `wait_frames`. Run `--import` after adding test files, then grep the GUT output for `Parse Error|Failed to load script|SCRIPT ERROR`.
- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.

`tests/unit/test_frame_tracker.gd`:
- records and reports the last and the worst; empty → `worst_ms() == 0.0`.
- entries older than `WINDOW_SEC` drop out: record 50 ms at t=0, 10 ms at t=5, then at t=10.5 record 8 ms → worst is 10 ms (the 50 ms is gone).
- `clear()` empties it.

`tests/unit/test_save_service.gd` (add):
- `test_export_file_name_format`: a fixed unix time gives `zts-save-YYYYMMDD.json` with zero-padded month/day (assert against a time whose local date you compute the same way; avoid a midnight-adjacent value so time zones can't flip it: use mid-day UTC, e.g. 2026-03-05 12:00 UTC, and assert the name matches the regex `^zts-save-\d{8}\.json$` and that the digits equal the `Time` dict values).
- `test_reset_to_defaults_replaces_data_and_saves`: load `save_v1_full.json` (brains 340), `reset_to_defaults()` → `get_active_profile()["brains"] == 0`, `await wait_process_frames(2)` → one write; `save.json` parses to defaults; **`save.bak` holds brains 340** (the backup chain survives the reset).
- `test_reset_clears_read_only`: a save with a newer `schema_version` is read-only; after `reset_to_defaults()` and a frame, `save.json` is written (not `ERR_LOCKED`) with `schema_version == GameConstants.CURRENT_SCHEMA`.
- `test_offer_export_writes_file_on_desktop`: with `save_dir = TEST_DIR`, `offer_export()` creates `TEST_DIR/zts-save-*.json` whose text equals `export_json()`. **This calls the live `WebPlatform.offer_download()`, which on desktop calls `OS.shell_open()` and would open a Windows Explorer window during the test run.** Don't call it through the live autoload: add a seam to `SaveService` (`var offer_download: Callable = Callable()` defaulting to `WebPlatform.offer_download` in `_ready()`, or a small `_deliver(bytes, name)` method the test overrides by subclassing/replacing the Callable) and assert it was called once with the right bytes and name. Prefer the Callable seam; record the choice in the Dev Agent Record.
- `test_offer_export_never_changes_the_save`: `export_json()` text before and after is identical and no `save.json` write happens (no `save_written`).

`tests/unit/test_player_data.gd` (add):
- `test_reset_all_returns_to_defaults_and_emits`: after `add_brains(5)` and `set_setting(&"music_on", false)`, `reset_all()` → `get_brains() == 0`, `get_setting(&"music_on") == true`, `profile_replaced` emitted once, one write after a frame.
- `test_reset_all_emits_no_delta_signals`: `brains_changed`/`settings_changed` emit count 0 for the reset itself.

`tests/unit/test_debug_overlay.gd` (fresh `SaveService` + `PlayerData` injected, overlay instantiated from the scene and added with `add_child_autofree`; drive `_handle_key()` directly):
- starts hidden; F3 toggles visible/hidden; `set_process` follows visibility.
- F5 with the overlay **closed** does nothing (brains stay 0); open → F5 adds `CHEAT_BRAINS` (100) twice → 200, `brains_changed` emitted with `[200, 100]`.
- F8 flow: open, F5 (brains 100), F8 → `is_confirming()` true, brains still 100; another key (e.g. `KEY_A`) → not confirming, brains 100; F8, F8 → brains 0, not confirming; F8 then F3 (close) → not confirming; F8 then wait past `CONFIRM_SEC` (set the constant's timer to a tiny wait via a `confirm_sec` var seam or call the timeout handler directly) → not confirming.
- F9 closed → no export; open → export called once (inject the seam from `SaveService.offer_export` or assert via the `SaveService` Callable seam).
- the overlay's labels never take focus / block mouse: every Control in the scene has `mouse_filter == MOUSE_FILTER_IGNORE`.
- `format_save_age(-1, 5000) == "Last save: never"`; `format_save_age(1000, 3300) == "Last save: 2.3 s ago"`.

`tests/unit/test_router.gd` (add): `_is_debug_build()` overridden to `false` (use a subclass of the router script or a bool seam var `debug_override`; choose the simplest that doesn't touch the live Router) → after `_ready()` there is **no** `DebugOverlay` child; with `true` → exactly one `DebugOverlay` child (a `CanvasLayer`), and its `visible` is `false`. Use a **fresh** Router instance (`RouterScript.new()` + `add_child_autofree`), never the live autoload; mirror how `test_router.gd` already builds one.

`tests/unit/test_main_menu.gd` (add): `MainMenuScript.is_export_chord()` true for Ctrl+Shift+E (pressed, not echo), false for plain E, Ctrl+E, Shift+E, Ctrl+Shift+Alt+E, Ctrl+Shift+R, a release event and an echo. The `_unhandled_input` → `SaveService.offer_export()` hop is covered by the desktop and web checks (Task 8.3/8.4): don't call the live `offer_export()` from a test (it would open Explorer and write a file in the real `user://`).

`tests/unit/test_keyboard_test.gd` (add): calling `_on_player_data_profile_replaced()` refreshes the brains label from `PlayerData.get_brains()` (read-only on the live autoload); the screen disconnects from `profile_replaced` when freed (use `add_child_autofree`, per the 1.7 review patch).

### Previous story intelligence (1.1–1.7)

- **1.7 left this story three hand-offs:** `PlayerData._profile()` re-reads on every call (so reset needs no getter changes); the "no profile replaced signal" review deferral (done here as `profile_replaced`); and the Keyboard Test counter goes stale after F8 (Task 3.3).
- **1.5/1.6 deferrals this story closes:** desktop `offer_download()` ignoring bytes (route the write through `SaveService`, Task 2.2) and Download-name/`export_json()` wiring.
- **1.5:** Godot web dispatches input from its main loop, not inside the browser event, so a download started from a key press may behave differently from one started from a click. The Keyboard Test Download **button** was tested in the browser; a key-triggered download (Ctrl+Shift+E, F9) has not. Task 8.4 measures it. If Chrome/Edge block or prompt for the second and later downloads ("this site is trying to download multiple files"), record it; it's expected browser behaviour, not a bug.
- **1.5:** `WebPlatform.capture_keys` (the JS `preventDefault` hook) is only on for Keyboard Test (and later the run). It never touches modifier combos, so Ctrl+Shift+E is unaffected by it; whether the browser itself reserves the chord is what Task 8.4 checks.
- **1.3:** Router fade layer is 100 and the Router pauses the tree during transitions: the overlay is `PROCESS_MODE_ALWAYS` at layer 110 so it stays visible and live in both.
- **Test patterns:** fresh instances with seams set before `add_child_autofree`, the live autoload only read; private handlers called directly; `assert_push_error` for every expected `Log.error`; GUT parse-error grep.
- **Desktop close/driving:** the window is driven with a scratch PowerShell helper (SetCursorPos/mouse_event, CopyFromScreen screenshots, `Process.CloseMainWindow()` for a real close); `stop_project` kills the process. Don't re-invent: see the 1.6 and 1.7 Debug Log References.
- **Desktop user data:** `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/` holds Smuck's real save (brains 4 from 1.7). The F8 check will reset it; warn first.

### Git intelligence

- Recent commits: `3798a0c` Story 1.7 (PlayerData, counter, notice; 154 tests), `87913aa` 1.6 (SaveSchema, SaveService), `803a575` 1.5 (WebPlatform, keyboard test), `580aba1` 1.4 (AudioManager), `ab8585a` 1.3 (Router, screens). Tree clean at story creation.
- Commit style: `Story 1.N: <summary>` with a short body and the `Co-Authored-By` trailer. Commit only when Smuck asks.

### Latest tech information (checked 2026-10-03)

- Godot 4.7.2-stable, single-threaded web export, GL Compatibility. `JavaScriptBridge.download_buffer(buffer, name, mime)` is the web download call already used by `WebPlatform` (no new JS). `CanvasLayer.visible` hides all children (Godot 4); `Engine.get_frames_per_second()` is the FPS source; `OS.is_debug_build()` is `true` in editor runs and debug exports, `false` in release exports (CI deploys `--export-release`).
- Browser shortcuts: Ctrl+Shift+E is Firefox's Network tool; Chrome and Edge don't bind it as far as known. Unverified until Task 8.4 (Firefox not installed).
- No new libraries. GUT 9.7.1 APIs used: `watch_signals`, `assert_signal_emit_count`, `assert_signal_emitted_with_parameters`, `assert_push_error`, `wait_process_frames`, `add_child_autofree`.

### Project Structure Notes

- Matches the architecture tree: `scenes/debug/debug_overlay.tscn`, `scripts/debug/debug_overlay.gd`. **Variances (small, additive):** `scripts/debug/frame_tracker.gd` (extracted so the 10-second window is unit-testable); the overlay is instanced by the Router (no sixth autoload); `SaveService.offer_export()`, `export_file_name()`, `reset_to_defaults()` and `PlayerData.reset_all()` / `profile_replaced` are new API the architecture implied but didn't name.
- `tests/unit/test_debug_overlay.gd` and `test_frame_tracker.gd` follow the "every logic script has a unit test" rule.

### Project Context Rules

- There is no `project-context.md`. Rules come from the architecture (State Management, Event System, Data Persistence, Error Handling, Debug Tools, Boundaries 1/3/4/7, Consistency Rules, Naming) and Stories 1.1–1.7: strict static typing, `Log` for all logging, tests first for logic, fresh instances instead of live autoloads in tests, the GUT parse-error grep, standard Godot build only.
- Tools: Godot MCP (`run_project`, `get_debug_output`, `stop_project`) for the desktop run; Godot binary at `/c/Program Files/Godot/Godot.exe` for `--import`, export and GUT; Smuck's Chrome and Edge for the download checks.

### Open Questions for Smuck (none block Tasks 1–7)

1. **Firefox's Ctrl+Shift+E** opens its Network tool. If it can't be intercepted, the playtest export needs another chord or a fallback. Only matters if Firefox is used for playtests; Chrome/Edge are measured in Task 8.4.
2. **F8 will reset your real desktop save** during the Task 8.3 check (it currently has brains 4). OK to reset and leave it at defaults?
3. **Keyboard Test button still ships in release** (1.5 deferral). Gate it in this story, leave it for Epic 5.3 (family-computer checks), or remove it? Default: leave it.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.8: Debug Overlay and Save Export]
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.10] (later extension of the overlay), [#Story 5.4] and [#Story 5.5] (save export during playtest)
- [Source: _bmad-output/game-architecture.md#Debug Tools, #Data Persistence (Save export, Write strategy, Coalescing), #Architectural Boundaries, #Event System, #Error Handling]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] ("Hidden parent/dev input: Ctrl+Shift+E on the main menu downloads `save.json`; invisible to kids, no UI")
- [Source: _bmad-output/implementation-artifacts/1-7-player-data-service-and-reload-proof-counter.md] (PlayerData, test seams, review deferrals)
- [Source: _bmad-output/implementation-artifacts/1-6-versioned-save-file.md] (SaveService API, `export_json`, desktop close/drive method)
- [Source: _bmad-output/implementation-artifacts/1-5-web-platform-service-and-keyboard-capture-test.md] (`offer_download`, web export/serve workflow)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (1.5, 1.6, 1.7 items closed or kept here)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Red: GUT with the new tests and no implementation → `Preload file ... debug_overlay.tscn does not exist` parse errors plus 4 failing tests in the scripts that loaded.
- Green: GUT 190/190 (154 at HEAD + 36 new), exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`. One fix on the way: a `\d` regex literal lost its escape in a shell heredoc; now a raw string `r"..."`.
- 8.2 boundary greps clean: `FileAccess`/`DirAccess` only in `save_service.gd`; `get_active_profile`/`reset_to_defaults` called only from `player_data.gd`; `request_save` only in `player_data.gd`/`save_service.gd`; `OS.is_debug_build()` only in `log.gd` and `router.gd` (other hits are comments); debug paths referenced only by the Router's constant.
- 8.3 desktop (Godot MCP run, window driven by a scratch PowerShell helper: SetForegroundWindow + keybd_event keys, SetCursorPos/mouse_event clicks, CopyFromScreen screenshots). Smuck's real save (brains 4) was copied to the scratchpad first and restored afterwards (save.json + save.bak; exports deleted). Results: F3 opens on Title (title did not advance: key consumed), stays up through Title → Menu and Menu → Keyboard Test swaps; F3 closed, then F5/F8/F9 → nothing (no export file); Ctrl+Shift+E on the menu → `zts-save-20261003.json` byte-identical to `save.json`, screen unchanged; Keyboard Test: F5 ×2 → counter 4 → 204, "Last key: none" (the screen never saw F3/F5); F8 → red confirm line; A → cancelled (A echoed on the screen); F8 F8 → counter 0 live (profile_replaced), `save.bak` brains 204, `[INFO][save] reset to defaults`; F9 → export identical to the new `save.json`; Esc then F3 50 ms later (mid-fade, tree paused) → overlay closed. Log: no errors.
- Overlay placement: top-left covers the left half of the Keyboard Test heading; no corner is free there (buttons span the full width at the bottom), so it stays top-left (debug-only, mouse ignored). Recorded in deferred-work.
- 8.4 web debug export (`build/web`, served on :8060): built-in pane smoke (overlay, `Storage: persistent`, F5 writes). Smuck checked Chrome and Edge: F3/F5 + reload, F8 F8 + reload, F9 and Ctrl+Shift+E downloads (valid JSON), key capture with the overlay present — reported "all good".
- 8.5 web release: local `--export-release` (`build/web-release`, :8061) in the built-in pane: F3 shows nothing; Ctrl+Shift+E on the menu → `[INFO][web] download offered: zts-save-20261003.json (443 bytes)`; Smuck confirmed the release download in Chrome. CI Pages build not used.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `SaveService`: `export_file_name()` (static, local date via the system time-zone bias when a unix time is given, `Time.get_datetime_dict_from_system()` otherwise), `offer_export()` (desktop writes `save_dir/<name>` first, logs and continues on failure; then delivers), `reset_to_defaults()` (defaults, clears `_read_only`, keeps `_main_valid` so the old save becomes `save.bak`). Download seam: **Callable** `offer_download`, defaulting to `WebPlatform.offer_download` in `_ready()` (tests set a recorder, so no Explorer window opens during GUT).
- `PlayerData.profile_replaced` + `reset_all()` (no delta signals). Keyboard Test re-reads its counter on `profile_replaced` and disconnects in `_exit_tree()`.
- `FrameTracker` (pure, `scripts/debug/`): parallel `PackedFloat64Array`s with a start index, compacted once the expired half is reached; `size()` added for the window test.
- Debug overlay: `CanvasLayer` layer 110, hidden, `PROCESS_MODE_ALWAYS`; `PanelContainer` (named `Panel`, sizes to its labels; the story said Panel) → VBox → Stats/Save/Help/Confirm labels at 8 px, every Control `mouse_filter = IGNORE`. `_input` → `_handle_key(keycode) -> bool`; modifier combos only cancel a pending confirm. `_process` and the 0.25 s refresh timer run only while open; no per-frame strings or logs. F8 confirm via a one-shot 5 s `%ConfirmTimer`.
- Router hosts the overlay (no sixth autoload: the autoload list/order is asserted by `test_project_settings.gd` and fixed at five by the architecture). `_is_debug_build()` seam + `_debug_overlay_path` var (lets a test prove a missing overlay logs and carries on). Tests use an inner `ReleaseRouter` subclass for the release case.
- Main menu: `is_export_chord()` (Ctrl+Shift+E, pressed, not echo, no Alt/Meta) and `_unhandled_input` → `SaveService.offer_export()`; no debug check on that path (release-safe), no visible feedback.
- The Keyboard Test screen and its menu button still ship in release (unchanged, per scope).

### File List

New:
- scenes/debug/debug_overlay.tscn
- scripts/debug/debug_overlay.gd (+ .uid)
- scripts/debug/frame_tracker.gd (+ .uid)
- tests/unit/test_debug_overlay.gd (+ .uid)
- tests/unit/test_frame_tracker.gd (+ .uid)

Modified:
- scripts/autoloads/save_service.gd
- scripts/autoloads/player_data.gd
- scripts/autoloads/router.gd
- scripts/screens/main_menu.gd
- scripts/screens/keyboard_test.gd
- tests/unit/test_save_service.gd
- tests/unit/test_player_data.gd
- tests/unit/test_router.gd
- tests/unit/test_main_menu.gd
- tests/unit/test_keyboard_test.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/1-8-debug-overlay-and-save-export.md

Deleted:
- scenes/debug/.gitkeep
- scripts/debug/.gitkeep

### Change Log

- 2026-10-03: Story 1.8 created (ready-for-dev).
- 2026-10-03: Implemented debug overlay (F3/F5/F8/F9), FrameTracker, SaveService export/reset, PlayerData.reset_all + profile_replaced, Router debug hook, main-menu Ctrl+Shift+E; 36 new tests (190 total); desktop, web debug and web release checks done. Status → review.
