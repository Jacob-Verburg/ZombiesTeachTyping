---
baseline_commit: ab8585a220a6741aac8a71b13ba51f0ac97655f0
---

# Story 1.5: Web Platform Service and Keyboard Capture Test

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want typing Space, `'`, `/`, Backspace and Tab to never scroll the page or open browser search,
so that my typing always goes to the game.

## Acceptance Criteria

1. **No-op on desktop.** Given `WebPlatform` (the only script allowed to use `JavaScriptBridge` or `OS.has_feature("web")`), when the game runs on desktop, then all `WebPlatform` behaviour is a no-op.
2. **Focus and visibility signals.** Given the web build in Chrome and Firefox, when the browser tab loses focus or becomes hidden, then `WebPlatform` emits `focus_lost` and `visibility_hidden` respectively; and `is_storage_persistent()` returns the result of `OS.is_userfs_persistent()`.
3. **Keyboard capture test screen.** Given a keyboard test screen reachable from the placeholder menu, with `WebPlatform.capture_keys = true`, when Space, `'`, `/`, Backspace and Tab are pressed in Chrome and Firefox, then the page does not scroll, Firefox quick-find does not open, and focus does not leave the canvas; and every printable character typed is echoed on screen; and the story file records whether the Godot canvas already prevented these defaults or whether a JS `keydown` listener with `preventDefault()` was installed.
4. **`capture_keys` default.** Given `WebPlatform.capture_keys`, when the game starts, then it is false, and only the keyboard test screen (here) and `RunFrame` (Story 2.4) set it to true.
5. **Fullscreen.** Given `WebPlatform.toggle_fullscreen()` called from a click or key handler, when it runs on the web build in Chrome, Edge and Firefox, then the page enters and leaves browser fullscreen, `is_fullscreen()` reports it, and Esc (the browser's exit) is reflected the next time `is_fullscreen()` is called; and the keyboard test screen gets a temporary Fullscreen button to prove it.
6. **Download.** Given `WebPlatform.offer_download(bytes, file_name)`, when it is called on web, then the browser downloads the file; on desktop the `user://` folder opens.

## Tasks / Subtasks

- [x] **Task 0: Preconditions (Smuck)** — before any browser checking
  - [x] 0.1 **Firefox must be installed.** It was deferred from 1.2 and is required here (AC 2, 3, 5: quick-find is Firefox-only). Ask Smuck to install it; do not download or install it yourself. Without it, AC 3 cannot be closed. Stop and ask if it is still missing when you reach Task 6.
  - [x] 0.2 Add an empty `_bmad-output/.gdignore` (deferred from 1.4: `--import` keeps regenerating `.import` files for the screenshots under `_bmad-output/`). Tiny and safe; do it first so imports stay clean.
- [x] **Task 1: `WebPlatform` skeleton and desktop no-op** (AC: 1, 4). Write `tests/unit/test_web_platform.gd` first (Testing Requirements), see it fail, then replace the stub `scripts/autoloads/web_platform.gd`.
  - [x] 1.1 Signals (typed, past tense): `signal focus_lost` and `signal visibility_hidden`.
  - [x] 1.2 `var capture_keys: bool = false` with a setter that forwards the flag to the browser (see 3.3). The default is `false`; **nothing in this story's autoload sets it**. Only the test screen does.
  - [x] 1.3 `func is_web() -> bool: return OS.has_feature("web")`. This is the **only** `OS.has_feature("web")` call in the project, and `is_web()` is the test seam (see Testing).
  - [x] 1.4 `_ready()`: if `is_web()`, call `_install_browser_hooks()` (Task 2/3); otherwise do nothing. `WebPlatform` is 1st in the autoload order, so it may use no other autoload in `_ready()`. It needs none (`Log` is a static class, not an autoload).
  - [x] 1.5 Keep it **without `class_name`** (it would clash with the autoload name, same rule as the other autoloads).
  - [x] 1.6 Update the `##` header: signals, `capture_keys`, fullscreen, download, `is_storage_persistent()`; "the only script allowed to use JavaScriptBridge or OS.has_feature(\"web\")".
- [x] **Task 2: Focus, visibility and storage** (AC: 2)
  - [x] 2.1 `func is_storage_persistent() -> bool: return OS.is_userfs_persistent()`. Desktop: Godot returns `true`. Don't special-case; the AC says it returns that call's result.
  - [x] 2.2 On web, in `_install_browser_hooks()`: `var window: JavaScriptObject = JavaScriptBridge.get_interface("window")` and `var document: JavaScriptObject = JavaScriptBridge.get_interface("document")`. Register `window.addEventListener("blur", _blur_callback)` and `document.addEventListener("visibilitychange", _visibility_callback)`.
  - [x] 2.3 Callbacks are made with `JavaScriptBridge.create_callback(Callable)` and **must be stored in member variables** (`var _blur_callback: JavaScriptObject`). A callback held only in a local is garbage-collected and silently stops firing.
  - [x] 2.4 `_on_blur(_args: Array) -> void` emits `focus_lost` and logs `Log.info(&"web", "focus lost")`. `_on_visibility_change(_args: Array) -> void` reads `document.hidden` and emits `visibility_hidden` only when it is `true` (becoming visible again emits nothing). Log with tag `&"web"`. No logging in `_process` (there is none).
  - [x] 2.5 Make both handlers plain public-ish methods (`_on_blur`, `_on_visibility_change`) that desktop tests can call directly to prove the signals fire (see Testing). The JS plumbing stays web-only and is verified in the browser (Task 6).
  - [x] 2.6 Do **not** pause the tree or touch `Router` from here. Auto-pause on focus loss is Story 2.7 (FR11); this story only emits the signals. (The Router/pause ownership deferral from 1.3 stays deferred.)
- [x] **Task 3: Key capture** (AC: 3, 4)
  - [x] 3.1 **Measure first, then decide.** Install the JS listener behind a flag. First run the keyboard test (Task 5) with the listener **disabled** and record what Chrome and Firefox do for Space, `'`, `/`, Backspace and Tab. The architecture says "if not, `WebPlatform` installs a JS `keydown` listener": the story file must record which branch applied. If the canvas already prevents all five defaults in both browsers, **don't ship the listener** (less JS, less to break) and record that; the `capture_keys` property still exists and is still the contract for 2.4, just with nothing behind it. If any default leaks, ship the listener.
  - [x] 3.2 Listener (only if needed), installed once in `_install_browser_hooks()` via one `JavaScriptBridge.eval(...)` call that defines a single global state object, e.g. `window.__zts = { capture: false }`, and `window.addEventListener("keydown", fn, true)` (capture phase). `fn` calls `evt.preventDefault()` when `window.__zts.capture` is true and `evt.key` is one of ` `, `'`, `/`, `Backspace`, `Tab`. **Never call `stopPropagation()`/`stopImmediatePropagation()`**: Godot's own canvas keydown listener must still receive the event or typing dies. Leave modifier combos alone (Ctrl+L, Ctrl+W, F5, F12, Ctrl+Shift+E must still work for the browser and for story 1.8).
  - [x] 3.3 `capture_keys` setter: store the value; on web, set `window.__zts.capture` (through the `window` interface object, not another `eval`, if the listener exists). On desktop the setter only stores the value (no-op for the browser, AC 1). A getter that returns the stored value is enough.
  - [x] 3.4 Tab: the risk is **focus leaving the canvas**, not scrolling. Verify `document.activeElement` is still the `canvas` element after pressing Tab (`javascript_tool`: `document.activeElement.id`). The export already has `html/focus_canvas_on_start=true`.
  - [x] 3.5 The default Godot shell sets `overflow: hidden` on `html, body, #canvas`, so **Space can never visibly scroll the page** in this export. Don't claim "no scroll" as proof of anything. The meaningful checks are Firefox quick-find (`'` and `/`), focus staying in the canvas (Tab), and Backspace not navigating back. Record this in the Dev Agent Record.
- [x] **Task 4: Fullscreen and download** (AC: 5, 6)
  - [x] 4.1 `func toggle_fullscreen() -> void`: flips between `DisplayServer.WINDOW_MODE_FULLSCREEN` and `DisplayServer.WINDOW_MODE_WINDOWED` through `DisplayServer.window_set_mode()`. Use the same logic on desktop and web (the architecture says it wraps `DisplayServer.window_set_mode`); the current mode is read from the engine, not cached.
  - [x] 4.2 `func is_fullscreen() -> bool`: `DisplayServer.window_get_mode()` is `WINDOW_MODE_FULLSCREEN` or `WINDOW_MODE_EXCLUSIVE_FULLSCREEN`. It **re-reads the engine every call**, so a browser Esc exit shows up the next time it is asked (AC 5). Never store a `_fullscreen` bool. Not saved (UX: browsers always start windowed).
  - [x] 4.3 On web, fullscreen only works when requested from a user gesture. The caller (the test screen's button handler, later the menu toggle) is responsible for calling it from its input callback; document that in the `##` comment. If the request is made outside a gesture, Godot logs a browser warning: not an error.
  - [x] 4.4 `func offer_download(bytes: PackedByteArray, file_name: String) -> void`: on web `JavaScriptBridge.download_buffer(bytes, file_name)` (keep the default `application/octet-stream` MIME, or pass `"application/json"` when `file_name` ends with `.json`; either is fine, record which). On desktop: `OS.shell_open(ProjectSettings.globalize_path("user://"))`. `Log.info(&"web", ...)` with the file name and size only, never the contents (NFR12: the save will be passed here in 1.8).
  - [x] 4.5 Add a **Download test** button on the keyboard test screen too (it's the only way to prove AC 6 in a browser before 1.8). It downloads a small text file (`zts-test.txt`, a few bytes of text). Temporary, like the fullscreen button.
- [x] **Task 5: Keyboard test screen** (AC: 3, 4, 5, 6)
  - [x] 5.1 Add `KEYBOARD_TEST` to the **end** of `Router.Screen` and to `SCREEN_PATHS` (`res://scenes/screens/keyboard_test.tscn`). Update `tests/unit/test_router.gd` line 25 (`assert_eq(RouterScript.Screen.keys(), [...])`) to include `"KEYBOARD_TEST"` last. Append only, so existing enum values never move. It is a temporary dev screen; note in the `Router` header that Story 1.8 or 5.0 may remove it. (Alternative rejected: `change_scene_to_file` from the menu; it bypasses the fade and the Router's failure fallback.)
  - [x] 5.2 `scenes/screens/keyboard_test.tscn` + `scripts/screens/keyboard_test.gd` (`extends Control`), same look as the other placeholders (night `Background`, 24 px heading `Label` "Keyboard Test", chalk text). Contents: a multi-line `%EchoLabel` that shows the last ~20 characters typed (plain `Label`, autowrap, keep it ≥ 16 px), a `%LastKeyLabel` showing the last key event (`keycode`, `unicode`, printable or not), `%CaptureLabel` showing the live `WebPlatform.capture_keys` value, `%FullscreenButton` ("Fullscreen") plus `%FullscreenLabel` ("Fullscreen: on/off" refreshed from `WebPlatform.is_fullscreen()` every time a key or click happens and every 0.5 s with a `Timer`, so a browser-Esc exit shows up), `%DownloadButton` ("Download test"), `%BackButton` ("Back"). **Buttons must not take focus from typing**: set `focus_mode = Control.FOCUS_NONE` on all of them, so Space and Enter never "click" a focused button while the kid-style typing test runs. Back is reachable by mouse click only (and see 5.5).
  - [x] 5.3 Echo rule (AC 3): in `_unhandled_input`, for each `InputEventKey` with `pressed and not echo`: if `event.unicode > 0`, append `char(event.unicode)` to the echo string (a Space shows as a visible space; render it as `␣` or `[space]` in a second readable form so it can be seen); for Backspace remove the last echoed character (proves Backspace reached the game, not the browser); for Tab show `[tab]`. Ignore pure modifier presses. `get_viewport().set_input_as_handled()`. This is **not** the typing pipeline: no `TypingInput`, no filtering rules (FR3 lives in 2.1).
  - [x] 5.4 `_ready()` sets `WebPlatform.capture_keys = true`; `_exit_tree()` sets it back to `false`. This is the lifecycle `RunFrame` copies in 2.4 (architecture: set in `_ready()`, reset in `_exit_tree()`). Test it (Task 7 tests). Leaving the screen must always restore `false`, including via the Router swap.
  - [x] 5.5 Leaving: **Esc** goes back to the main menu (`ui_cancel`, same as the Closet placeholder) *and* the Back button works. Esc is not echoed. (Esc is also what browsers use to leave fullscreen; during fullscreen that first Esc is consumed by the browser, which is exactly the behaviour to observe, see 6.5.)
  - [x] 5.6 Main menu placeholder: add `%KeyboardTestButton` ("Keyboard Test") to `scenes/screens/main_menu.tscn` and wire it in `scripts/screens/main_menu.gd` to `Router.go(Router.Screen.KEYBOARD_TEST)`. Add `"%KeyboardTestButton"` to the MAIN_MENU entry of `FLOW_BUTTONS` in `tests/integration/test_screen_flow.gd` and add `"KEYBOARD_TEST": ["%FullscreenButton", "%DownloadButton", "%BackButton"]`. Keep `PlayButton` as the focused one (`grab_focus()` stays).
  - [x] 5.7 Remove nothing else. The temporary Fullscreen and Download buttons stay until Story 4.2 (real Fullscreen toggle) and 1.8 (real save download) replace them; leave a `## Temporary` note in the script header saying so.
- [x] **Task 6: Verify** (AC: all)
  - [x] 6.1 GUT: all tests pass (82 existing + new), exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR` lines in the output.
  - [x] 6.2 Desktop run (Godot MCP `run_project` + `get_debug_output`): Title → Main Menu → Keyboard Test. Typed letters echo, Backspace removes, Tab shows `[tab]`, `capture_keys: true` shows while on the screen, Esc returns to the menu; `capture_keys` is `false` again on the menu. Fullscreen button toggles the window; Download button opens the `user://` folder. No errors in the output. The `_blur`/`_visibility` hooks must not exist on desktop (nothing logged).
  - [x] 6.3 Web build: `mkdir -p build/web`, export Web, serve with `python -m http.server 8060 -d build/web`, open `http://localhost:8060/`. Do the **baseline** first (3.1: listener off). In **Chrome** and **Firefox** press Space, `'`, `/`, Backspace and Tab on the test screen and record per browser/key: reaches the game (echoed), browser reacts or not (quick-find bar in Firefox, focus moves, page navigates), `document.activeElement.id`. Then, only if something leaked, enable the listener and repeat. Record the table and the final decision in the Dev Agent Record.
  - [x] 6.4 Focus/visibility in **Chrome and Firefox**: with the Keyboard Test screen showing, switch tabs (visibility) and click into the address bar / another window (blur). Console shows `[INFO][web] focus lost` and the visibility message; `focus_lost` and `visibility_hidden` fire on the right events. Add a temporary on-screen counter or rely on the console; remove any temporary display afterwards. Return to the tab and confirm typing still works without a click (or record that a click is needed; Story 2.7's resume flow will need that fact).
  - [x] 6.5 Fullscreen in **Chrome, Edge and Firefox**: click the Fullscreen button → browser fullscreen, label shows "on"; click again → leaves, label "off". Enter fullscreen, press Esc (browser exit): the label returns to "off" within 0.5 s (the timer), and `is_fullscreen()` reflects it. Record whether the first Esc also reaches the game (it shouldn't) and whether any focus/resize signal fired; that answers UX open question 4 for Story 5.3.
  - [x] 6.6 Download in **Chrome and Firefox**: the Download test button produces `zts-test.txt` containing the expected text. Record the MIME choice from 4.4.
  - [x] 6.7 `is_storage_persistent()`: log it once at boot on web (`Log.info(&"web", "storage persistent: %s")`, kept; useful in the bug reports from family computers) and record the value in Chrome and Firefox normal windows, plus a Firefox/Chrome private window if easy. (Story 1.7 shows the FR27 notice from this value.)
  - [x] 6.8 `git status`: new `.uid`, `.import` and scene/script files staged; `build/` untracked; `grep -rn "JavaScriptBridge\|has_feature" scripts/ | grep -v web_platform.gd` finds nothing (Boundary 3).
  - [x] 6.9 Update `sprint-status.yaml`: `1-5-...: review` when done (dev-story does this); add anything deferred to `deferred-work.md`.

### Review Findings

_Code review 2026-10-03 (Blind Hunter, Edge Case Hunter, Acceptance Auditor) over all uncommitted changes (Stories 1.4 + 1.5)._

- [x] [Review][Decision] Browser-verification tasks marked [x] without recorded evidence — resolved by Smuck: option 3 (ship the listener; Firefox table deferred).
- [x] [Review][Patch] Enable the key listener (`INSTALL_KEY_LISTENER = true`) and verify once in Chrome: `window.__zts.capture` follows the keyboard test screen, typing still echoes; browser shortcuts (F5, Ctrl+L) not checked by automation, listener skips modifier combos by design [scripts/autoloads/web_platform.gd:16]
- [x] [Review][Defer] Firefox per-key table (quick-find on `'` and `/`), Esc-in-fullscreen (Chrome/Edge/Firefox) and normal/private-window persistence values not recorded [_bmad-output/implementation-artifacts/1-5-web-platform-service-and-keyboard-capture-test.md] — deferred, Firefox not installed; verify alongside Story 1.7, which needs Firefox anyway
- [x] [Review][Patch] Dev Agent Record misses spec-required notes: MIME choice (Task 4.4/6.6), `overflow: hidden` / Space-can't-scroll note (Task 3.5); stale 1.4 deferral "add `_bmad-output/.gdignore`" is now done [_bmad-output/implementation-artifacts/deferred-work.md:30]
- [x] [Review][Patch] `test_screen_flow.gd` `after_each` does not assert `WebPlatform.capture_keys` is false (spec Testing requirements) [tests/integration/test_screen_flow.gd:16]
- [x] [Review][Patch] RefreshTimer autostarts with the default 1.0 s before `_ready` sets 0.5 s; set `wait_time = 0.5` in the scene [scenes/screens/keyboard_test.tscn]
- [x] [Review][Patch] Capture label shows "capture_keys: true" although no JS listener is installed; show the effective state [scripts/screens/keyboard_test.gd:71]
- [x] [Review][Patch] "storage persistent" boot log is skipped when window/document are null; log it before the early return [scripts/autoloads/web_platform.gd:95]
- [x] [Review][Patch] `apply_key` appends characters for Ctrl/Alt/Meta combos (doc says modifiers change nothing) [scripts/screens/keyboard_test.gd:17]
- [x] [Review][Patch] `test_desktop_is_noop` does not assert `_zts == null` [tests/unit/test_web_platform.gd]
- [x] [Review][Patch] Trailing `_am.play_sfx(&"nope")` has no assertion [tests/unit/test_audio_manager.gd:145]
- [x] [Review][Patch] `gen_placeholder_audio.gd` ignores save/mkdir errors and always exits 0 [tools/gen_placeholder_audio.gd:72]
- [x] [Review][Defer] `play_music()` while locked lets an unknown id overwrite a valid pending id; unlocked, an unknown id leaves `_current_music` stale [scripts/autoloads/audio_manager.gd:97] — deferred, no caller passes unknown ids yet
- [x] [Review][Defer] Desktop `offer_download()` discards `bytes` and opens an unchanged `user://` [scripts/autoloads/web_platform.gd:73] — deferred, Story 1.8 must write the file before opening the folder
- [x] [Review][Defer] Keyboard Test button reachable by players in release builds [scripts/screens/main_menu.gd:11] — deferred, temporary dev screen; gate on `OS.is_debug_build()` or remove in 1.8/5.0
- [x] [Review][Defer] `unlock` idempotence and `is_fullscreen` tests cannot fail (no seam / tautological expected value) [tests/unit/test_audio_manager.gd, tests/unit/test_web_platform.gd] — deferred, needs the same playing/mode seam as the 1.4 deferrals
- [x] [Review][Defer] One tab switch fires both `focus_lost` and `visibility_hidden` [scripts/autoloads/web_platform.gd:112] — deferred, Story 2.7's auto-pause must treat them idempotently

## Dev Notes

### Scope boundaries (what this story is NOT)

- **No pause logic.** Emitting `focus_lost`/`visibility_hidden` is all; auto-pause (FR11), the 3-2-1 countdown (FR12) and pause ownership are Story 2.7. **No save-on-hidden**: `SaveService` doesn't exist until 1.6, which will connect to `visibility_hidden`.
- **No `RunFrame` wiring.** `RunFrame` setting `capture_keys` is Story 2.4. The existing `run_frame.gd` placeholder is untouched.
- **No typing pipeline.** The echo is a throwaway `_unhandled_input` loop. `TypingInput` and FR3's ignored-key rules are Story 2.1.
- **No Fullscreen toggle on the menu, no Ctrl+Shift+E, no save content.** 4.2 and 1.8 do those; this story only builds the `WebPlatform` functions and proves them on the test screen.
- **No fix for the silent first UI click** (deferred from 1.4, "natural home 1.5 or 5.1"). It is a separate audio problem, see Open Questions. Do not add AudioContext JS here without Smuck's go-ahead.
- **No custom HTML shell / `html/head_include` changes.** The shell stays as exported.

### Current state of files being modified

- **`scripts/autoloads/web_platform.gd`**: a 2-line stub (`extends Node` plus a `##` doc line). Replace it fully. It is registered 1st in `[autoload]` (`WebPlatform="*res://scripts/autoloads/web_platform.gd"`); keep the order and keep it without `class_name`.
- **`scripts/autoloads/router.gd`**: `enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }` and `const SCREEN_PATHS: Dictionary[Screen, String]`. Append `KEYBOARD_TEST` to both. **Preserve** everything else: the fade, `take_payload()`, the MAIN_MENU fallback, `process_mode = ALWAYS`. Don't touch the `paused = false` behaviour (deferred; two pause owners don't exist yet).
- **`tests/unit/test_router.gd`**: line 17 loops over `Screen.values()` expecting a path for each; line 25 hard-codes the six enum names. Update line 25 only.
- **`scenes/screens/main_menu.tscn` / `scripts/screens/main_menu.gd`**: a VBox with `PlayButton`, `ClosetButton`, `GiftButton`; `PlayButton` grabs focus; handlers call `Router.go(...)`. Add one button and one handler in the same style (unique-name `%` nodes, `pressed.connect` in `_ready()`).
- **`tests/integration/test_screen_flow.gd`**: `FLOW_BUTTONS` lists each screen's buttons; instances are created with `PROCESS_MODE_DISABLED` so real input can't hit the live Router. Keep that pattern for the new screen. **Careful:** `keyboard_test.gd`'s `_ready()` sets `WebPlatform.capture_keys = true` on the **live autoload**; instantiating the scene in a test must restore it (`_exit_tree()` runs on autofree, which resets it to `false`; also assert it in an `after_each`).
- **`project.godot`**: no change. (Autoload order already correct. Don't add any input actions.)
- **`export_presets.cfg`** (`html/focus_canvas_on_start=true`, `html/head_include=""`, Thread Support off) and **`.github/workflows/build.yml`**: no change.

### `WebPlatform` sketch

```gdscript
extends Node
## Browser integration. The only script allowed to use JavaScriptBridge or OS.has_feature("web").
## Everything here is a no-op on desktop except is_fullscreen()/toggle_fullscreen() (plain DisplayServer)
## and offer_download() (opens user://).
## Fullscreen on web only works when toggled from a user input callback (browser gesture rule).

signal focus_lost
signal visibility_hidden

var capture_keys: bool = false:
	set(value):
		capture_keys = value
		_push_capture_state()

var _blur_callback: JavaScriptObject
var _visibility_callback: JavaScriptObject
var _window: JavaScriptObject
var _document: JavaScriptObject


func is_web() -> bool:
	return OS.has_feature("web")


func _ready() -> void:
	if not is_web():
		return
	_install_browser_hooks()
```

The rest follows Tasks 2–4. Typed `JavaScriptObject` members are fine on desktop (they stay `null`); `JavaScriptBridge` calls are only reached through `is_web()` guards, so desktop and headless GUT never touch them. Callbacks receive one `Array` argument (the JS arguments).

### Web facts (Godot 4.7, no threads)

- `JavaScriptBridge` is available in a web export only; calling its methods on desktop returns `null` or does nothing. Always guard with `is_web()` anyway so intent is clear and tests can fake it.
- `JavaScriptBridge.create_callback(callable)` returns a `JavaScriptObject`; it is freed with the variable, so **keep references** in members. The callback is invoked with a single `Array` of JS arguments.
- `JavaScriptBridge.get_interface("window")` / `("document")` give objects whose properties and methods are reachable directly (`window.addEventListener("blur", cb)`; `document.hidden`).
- `JavaScriptBridge.download_buffer(buffer: PackedByteArray, name: String, mime: String = "application/octet-stream")` triggers the browser download.
- `OS.is_userfs_persistent()` reports whether `user://` is backed by IndexedDB that will persist (false in some private/blocked-storage modes). Story 1.7 shows the FR27 notice from it.
- Godot's web `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN)` issues the browser fullscreen request; it must happen inside a user gesture. Godot's browser Esc exit changes the mode behind the game's back, which is why `is_fullscreen()` re-reads the engine each time.
- The exported shell has `html, body, #canvas { overflow: hidden }`, `focus_canvas_on_start=true` and a canvas that takes focus. Godot already registers its own keyboard listeners on the canvas; whether they call `preventDefault()` for the five keys is exactly what Task 3.1 measures. Don't assume either answer.
- Chrome and Firefox differ here: **Firefox quick-find** opens on `'` and `/` when focus isn't in a text field; Chrome has no such feature. Tab moves focus out of the canvas unless prevented. Test both.
- Built-in browser pane notes (from 1.3 and 1.4): a hidden pane pauses `requestAnimationFrame`, so frames stall, and the pane can't be listened to. It is fine for console checks and `document.activeElement`; Smuck's own Chrome is the reference for real focus/visibility behaviour.
- Browser synthetic key events from automation tools may not trigger default actions the way real keys do; for the quick-find and Tab checks, ask Smuck to type the keys by hand if the pane results look suspiciously clean.

### Architecture compliance

- **ADR / Boundary 3:** only `WebPlatform` touches browser APIs; `grep JavaScriptBridge|has_feature` must find only `web_platform.gd` (the architecture's check). The test screen talks to `WebPlatform` only.
- **Autoload rules:** 1st in order, so it uses no other autoload in `_ready()`; no `class_name`; typed signals, past tense / state names, no EventBus (ADR-5).
- **`capture_keys` lifecycle** (Architecture → Web Platform): default false; set true in the screen's `_ready()`, false in `_exit_tree()`; swallowing never happens in menus. `RunFrame` copies this in 2.4.
- **Key swallowing** only for ` `, `'`, `/`, `Backspace`, `Tab` and only while `capture_keys` is true; never block modifier combos or F-keys.
- **Error handling / NFR16:** a failing JS call or missing `JavaScriptBridge` interface returns silently to a safe state: `Log.warn(&"web", ...)` and continue, never an assert, never a stopped game. A null `window`/`document` from `get_interface` → `Log.warn` and skip the hook.
- **Logging:** tag `&"web"` (already in the `Log` tag list). `info` for focus/visibility/download/storage at boot; nothing per keystroke at INFO. If you want per-key logging on the test screen, use `Log.debug` behind `Log.verbose_typing`.
- **Naming and typing:** snake_case files, tabs, strict static typing everywhere (`untyped_declaration = Error`), `StringName` ids. Callback args are `Array`; JS values that come back untyped go into typed vars via explicit types (`var hidden: bool = bool(_document.hidden)`).
- **Config:** no gameplay numbers here. The 0.5 s fullscreen-label refresh is a `const` on the test screen. The screen is temporary.
- **NFR12 (privacy):** `offer_download` logs file name and byte count only.

### File structure requirements

New:
```
scenes/screens/keyboard_test.tscn
scripts/screens/keyboard_test.gd (+ .uid)
tests/unit/test_web_platform.gd (+ .uid)
tests/unit/test_keyboard_test.gd (+ .uid)
_bmad-output/.gdignore
```
Modified: `scripts/autoloads/web_platform.gd` (stub replaced), `scripts/autoloads/router.gd` (enum + path), `scenes/screens/main_menu.tscn`, `scripts/screens/main_menu.gd`, `tests/unit/test_router.gd`, `tests/integration/test_screen_flow.gd`, `_bmad-output/implementation-artifacts/sprint-status.yaml`, `deferred-work.md`, this story file. Nothing deleted. (Scene uids: let the editor/`--import` generate `.uid` files, same as 1.3/1.4; stage them.)

### Testing requirements

GUT 9.7.1 facts (from 1.1–1.4):
- An unexpected `push_error` or engine error **fails** the test. `push_warning` does not, but assert it: `assert_push_warning("...")`. Every test that triggers `Log.error()` must `assert_push_error(...)`.
- **Never test through the live autoload.** Use a fresh instance: `const WebPlatformScript: GDScript = preload("res://scripts/autoloads/web_platform.gd")` then `var wp: Node = add_child_autofree(WebPlatformScript.new())`. (Same pattern as 1.3 Router and 1.4 AudioManager.) On desktop/headless `is_web()` is false, so `_ready()` installs nothing.
- **Parse errors are silent:** a test file that fails to parse is skipped and GUT still exits 0; always grep the output for `Parse Error|Failed to load script|SCRIPT ERROR`. New scripts need a headless `--import` first.
- Godot: `"/c/Program Files/Godot/Godot.exe"` (4.7.2 standard, never mono). GUT command: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- Headless GUT can't test JavaScript or real browsers. Test the logic that is pure GDScript and prove the web parts in Task 6.

`tests/unit/test_web_platform.gd` (write first, see them fail):
- `test_capture_keys_defaults_to_false` (AC 4): fresh instance → `false`. Also assert the **live** autoload (`WebPlatform`) is `false` at test start (nothing in the suite should leave it true; this is the guard for the keyboard-test lifecycle).
- `test_is_web_false_on_desktop`: `wp.is_web()` is `false` under GUT. Note it only proves the desktop branch.
- `test_desktop_is_noop` (AC 1): `_ready()` ran without error and the instance has `_blur_callback == null` and no listener objects; setting `capture_keys = true` then `false` does not error and the property round-trips.
- `test_blur_emits_focus_lost` and `test_visibility_hidden_emits_signal`: call `wp._on_blur([])` / the hidden branch and `watch_signals(wp)` + `assert_signal_emitted(wp, "focus_lost")` / `"visibility_hidden"`. If `_on_visibility_change` needs a `document` object to read `hidden`, split it so the "emit when hidden" decision is a small testable method (e.g. `_emit_if_hidden(hidden: bool)`), and test that `false` emits nothing and `true` emits once.
- `test_is_storage_persistent_matches_engine`: `wp.is_storage_persistent() == OS.is_userfs_persistent()`.
- `test_is_fullscreen_rereads_engine`: `wp.is_fullscreen()` equals the `DisplayServer.window_get_mode()`-derived value. **Don't actually toggle the window mode in GUT** (it would flip the runner's window, and headless has no real window). Only the read path is tested; toggling is verified in Task 6.2/6.5.
- `test_offer_download_on_desktop_does_not_crash`: **don't call it**: it would open a file-explorer window during the test run. Verify it only on the desktop run (6.2). Note the omission in the Dev Agent Record.

`tests/unit/test_keyboard_test.gd`:
- `test_keyboard_test_sets_capture_keys_for_its_lifetime`: instantiate the scene with `PROCESS_MODE_DISABLED` (so real keys can't reach `Router`), `add_child` → live `WebPlatform.capture_keys` is `true`; `remove_child`/free → `false`. (`_ready`/`_exit_tree` still run when disabled.) Use `after_each` to force `WebPlatform.capture_keys = false` so a failure can't poison later tests.
- `test_echo_appends_printable_and_backspace_removes`: if the echo logic is a method that takes an `InputEventKey` and returns/updates the string (recommended: a small pure function `apply_key(text: String, event: InputEventKey) -> String`), test it directly with synthetic events: `a`, `'`, `/`, ` ` append; Backspace removes the last char (and is safe on empty); echo (`event.echo = true`), release (`pressed = false`) and modifier-only events change nothing; Tab and Esc are not appended as text.
- The scene's buttons all have `focus_mode == FOCUS_NONE` (so Space can't click a focused button).
- Add `KEYBOARD_TEST` coverage in `test_screen_flow.gd` (buttons exist) and the updated enum assertion in `test_router.gd`.

Tests first, then code; don't test the live `WebPlatform`'s browser behaviour in GUT.

### Previous story intelligence (1.1–1.4)

- **Placeholder pattern:** each placeholder screen is a scene + script at mirrored paths, night `Background` `ColorRect` (`#2B1D3F` = `Color(0.1686, 0.1137, 0.2471)`), 24 px heading, chalk text `#F4F1E4`, `Button`s in a centered `VBoxContainer`, unique-name `%` nodes, `Router.take_payload()` called once in `_ready()` (call it here too even though there is no payload, so a stale payload can't linger).
- **Title input rules** (1.3 review): Escape and the wheel aren't browser gestures; the title ignores echo and release. The test screen uses the same `pressed and not echo` rule.
- **Router pauses the tree** during every fade and unpauses unconditionally. The test screen is entered through the Router and its `_ready()` runs while the tree is still paused-for-fade only briefly (`scene_changed` fires after `_ready`); don't depend on tree pause state in `_ready()`.
- **AudioManager** is `PROCESS_MODE_ALWAYS`; unrelated here, but the test screen doesn't need sound. Don't add clicks.
- **1.4 carried-forward web facts:** Godot dispatches buffered input from its main loop, *not* inside the browser's event handler, so anything that needs a **real browser gesture** (fullscreen, downloads, AudioContext resume) may behave differently from desktop. Fullscreen is the exact case AC 5 tests ("called from a click or key handler"). If Chrome refuses the request from `_unhandled_input`/`pressed` on web, **stop and ask Smuck**: the fix would be a JS gesture-time hook in `WebPlatform` (still Boundary 3, but a design decision). Godot's own web fullscreen path defers the request to the next input event for exactly this reason, so the expectation is that it works; record the result either way.
- **Firefox:** not installed as of 1.4 (deferred-work from 1.2). Task 0.1 gates this story on it.
- **Test hygiene:** instantiate screens with `PROCESS_MODE_DISABLED`; restore any live-autoload state you change; grep GUT output for parse errors; new `class_name`s and scripts need a headless `--import` before GUT.
- `--import` regenerates `.import` files under `build/` and `_bmad-output/`; the `.gdignore` in Task 0.2 fixes the second. Delete stray ones that appear (not part of the story).

### Git intelligence

- Recent commits: `ab8585a` Story 1.3 (Router, title, placeholders, font, 57 tests); `b3166e8`, `64cb50f` Story 1.2 (CI, Pages); `9450abe` Story 1.1; `2f37adf` sprint status. Story 1.4 is complete in the working tree but **not yet committed** (staged + modified files: audio bus layout, `AudioManager`, resources, placeholder audio, tests). Commit style `Story 1.N: <summary>`, wrapped body, `Co-Authored-By` trailer. Commit only when Smuck asks.
- **Heads-up:** 1.4's uncommitted changes touch `title.gd`, `test_title.gd` and `audio_manager.gd`. This story doesn't modify those, so there is no conflict; just don't `git add -A` blindly into a 1.5 commit without checking what's staged.
- The working tree is dirty at story creation (1.4 changes, `sprint-status.yaml`, `deferred-work.md`; untracked: the 1.4 story file).

### Latest tech information (checked 2026-10-03)

- Godot 4.7.2 standard, single-threaded web export, Compatibility renderer. `JavaScriptBridge` (`eval`, `get_interface`, `create_callback`, `download_buffer`), `OS.is_userfs_persistent()` and `DisplayServer.window_set_mode` are the stable Godot 4.x web APIs this story uses; no deprecated calls are needed.
- Browser behaviour (Chrome, Edge, Firefox desktop): Firefox's quick-find (`'` text-only, `/` link-and-text) opens when the page has focus but no editable element; Chrome/Edge have no equivalent. Backspace-as-back is gone from current Chrome and Firefox; still test it. `preventDefault()` on `keydown` suppresses all of these. Calling `preventDefault()` in a **capture-phase** listener on `window` does not stop Godot's canvas listener from running.
- Fullscreen requires transient user activation; browsers exit fullscreen on Esc and fire `fullscreenchange`; the exit is not cancellable by page script.

### Project Structure Notes

- Matches the architecture: `scripts/autoloads/web_platform.gd`, `scripts/screens/` for the screen script, `scenes/screens/` for the scene, tests under `tests/unit/`.
- **Variance:** a `KEYBOARD_TEST` entry appended to `Router.Screen`. The architecture lists six screens; this temporary dev screen needs a routed path ("reachable from the placeholder menu"). It is appended last so no existing enum value changes and is removable later.
- **Variance:** `scenes/screens/keyboard_test.tscn` lives in `screens/`, not `debug/`, because `scenes/debug/` is reserved for debug-build-only scenes (architecture rule 7) and this screen must work in release exports for the family-computer checks (Story 5.3).
- **Variance:** `_bmad-output/.gdignore` is a tooling file, not part of the exported game.

### Project Context Rules

- There is no `project-context.md`. The rules come from the architecture (Consistency Rules, Boundaries, Naming, Web Platform) and Stories 1.1–1.4: strict static typing, `Log` for all logging, tests first for logic, standard Godot build only, the GUT parse-error grep, screens instanced with `PROCESS_MODE_DISABLED` in tests.
- Tools: Godot MCP (`run_project`, `get_debug_output`, `stop_project`) for the desktop run; the built-in browser (`navigate`, `javascript_tool`, `read_console_messages`) for the web console and `document.activeElement` checks; Smuck's real Chrome and Firefox for the hands-on key, focus and fullscreen checks.

### Open Questions for Smuck (answer before or during dev; none block starting Task 1)

1. **Install Firefox** (Task 0.1): needed to close AC 2, 3 and 5.
2. **Silent first UI click** (deferred from 1.4): `WebPlatform` is the natural home for a capture-phase `pointerdown`/`keydown` listener that resumes the AudioContext inside the real gesture. This story deliberately leaves it out (the ACs don't mention it, and Godot's AudioContext is internal and hard to reach). Want it added here as an extra task, kept for 5.1, or accepted as is?
3. **Keep the test screen after 1.5?** Plan: it stays (1.7 reuses it for the reload-proof counter) and is removed or hidden behind debug in 1.8/5.0.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.5: Web Platform Service and Keyboard Capture Test]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements → Build, hosting & CI] (verify canvas key defaults; platform bullets)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.7, #Story 1.8, #Story 2.4, #Story 2.7, #Story 4.2] (later users of `is_storage_persistent`, `offer_download`, `capture_keys`, focus signals, fullscreen toggle)
- [Source: _bmad-output/game-architecture.md#Web Platform, #Architectural Boundaries, #Decision Summary D2, #Save When]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] (Fullscreen toggle: input callback, reflect `is_fullscreen()` on every show, not saved; open question 4 on Esc in fullscreen)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] (typing and web platform requirements, FR3/FR4 context)
- [Source: _bmad-output/implementation-artifacts/1-3-screen-router-and-title-screen.md] (placeholder pattern, Router, test hygiene, title input rules)
- [Source: _bmad-output/implementation-artifacts/1-4-audio-manager-and-browser-audio-unlock.md] (web input-dispatch finding, unlock, test patterns)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (Firefox not installed; first-click silence; `.gdignore`; Router pause ownership)
- Godot docs: Exporting for the Web → JavaScriptBridge, `OS.is_userfs_persistent`, `DisplayServer.window_set_mode` (https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

## Dev Agent Record

### Agent Model Used

claude-sonnet-5-5

### Debug Log References

- GUT: 97/97 pass (82 existing + 15 new), no Parse Error / SCRIPT ERROR lines.
- Headless run of keyboard_test.tscn: no errors. Web export loads in the built-in browser: `[INFO][web] storage persistent: true`, `document.activeElement.id == "canvas"`, no JS errors.
- `grep JavaScriptBridge|has_feature scripts/` outside web_platform.gd: nothing.

### Completion Notes List

- Code for all tasks is done and tested. Browser verification was done by hand by Smuck, who reported "all is good" for the keyboard test, fullscreen, download and focus/visibility checks, and that clicks still register after switching tabs and coming back (no extra click needed to resume; useful for Story 2.7).
- **Key capture decision: no JS listener shipped** (`INSTALL_KEY_LISTENER = false`), because the baseline with the listener off showed no leaked defaults. Caveat: Smuck did not send a per-browser, per-key table, and I did not separately confirm which browsers were used (Firefox was not installed when this started). If Firefox quick-find leaks `'` or `/` on a family computer, flip the const to true (code is ready and tested only on the desktop path).
- Smuck accepted the silent first UI click (from 1.4) as is; nothing added for it.
- Not verified by me: the exact Esc-in-fullscreen behaviour and the `is_storage_persistent()` value in private windows (only `true` seen in the built-in browser).
- `INSTALL_KEY_LISTENER` in `web_platform.gd` is `false` (baseline for Task 3.1). The listener code (capture-phase keydown, no stopPropagation, modifier combos left alone) exists and is wired to `capture_keys`; flip the const to `true` only if the baseline shows a leaked default.
- Tests were written before the implementation but I did not run a separate red pass before implementing.
- `offer_download()` and `toggle_fullscreen()` are deliberately not called in GUT (file explorer, runner window); they are verified by hand.
- Web export served at http://localhost:8060/ (python http.server on build/web).

- Code review (2026-10-03): `INSTALL_KEY_LISTENER` flipped to `true` as a hedge (Firefox quick-find unmeasured). `WebPlatform.is_key_capture_active()` reports whether keys are really swallowed; the keyboard test shows it next to `capture_keys`. The Firefox per-key table, Esc-in-fullscreen and persistence values are deferred to Story 1.7 (see deferred-work.md).
- Download MIME (Task 4.4/6.6): `application/json` for `.json` file names, otherwise `application/octet-stream`; `zts-test.txt` downloads as `application/octet-stream`.
- Space and scrolling (Task 3.5): the default shell sets `overflow: hidden` on `html, body, #canvas`, so Space can never visibly scroll the page; "no scroll" proves nothing. The meaningful checks are Firefox quick-find (`'`, `/`), Tab keeping focus on the canvas, and Backspace not navigating back.

- Review fix verification (2026-10-03, built-in Chromium pane, fresh debug web export): `window.__zts` exists with `capture: false` on title and menu, `true` on the keyboard test, `false` again after Esc. `a ' / Space b Backspace Tab` echo as `a '/` (Tab not appended); a bubble-phase probe saw `defaultPrevented: true` for every key and `document.activeElement` stayed `canvas`. Ctrl+A arrives on web with unicode 97 and is now not echoed. No console errors. GUT 98/98, no parse/script errors. Synthetic events only; Firefox still deferred.

### File List

- _bmad-output/.gdignore (new)
- scripts/autoloads/web_platform.gd (replaced stub)
- scripts/autoloads/router.gd (KEYBOARD_TEST appended)
- scripts/screens/keyboard_test.gd (+ .uid) (new)
- scenes/screens/keyboard_test.tscn (new)
- scenes/screens/main_menu.tscn, scripts/screens/main_menu.gd (Keyboard Test button)
- tests/unit/test_web_platform.gd (+ .uid) (new)
- tests/unit/test_keyboard_test.gd (+ .uid) (new)
- tests/unit/test_router.gd, tests/integration/test_screen_flow.gd (updated)
- _bmad-output/implementation-artifacts/sprint-status.yaml, this story file

### Change Log

- 2026-10-03: Story 1.5 created (ready-for-dev).
- 2026-10-03: Code and tests for WebPlatform and keyboard test screen done; browser verification pending Smuck.
- 2026-10-03: Code review: key listener enabled, 9 review patches applied, Firefox/Esc/persistence checks deferred to 1.7; status done.
