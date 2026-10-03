---
baseline_commit: 87913aaf2191d793778aef6fdfb2a853750a8dc9
---

# Story 1.7: Player Data Service and Reload-Proof Counter

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want what I earn to still be there after I reload or close the tab,
so that I trust the game with my progress.

## Acceptance Criteria

1. **PlayerData mutations.** Given `PlayerData` (the single in-memory source of truth for the active profile), when its mutation methods run (for now `add_brains()` and `set_setting()`), then each emits a typed change signal (`brains_changed(total, delta)`, `settings_changed`) and calls `SaveService.request_save()`; and no other script writes save fields directly.
2. **Reload-proof counter (NFR4).** Given a test counter on the keyboard test screen backed by `PlayerData.add_brains(1)`, when the counter is clicked and the page is reloaded 10 times and the tab is closed and reopened 10 times in Chrome and Edge (amended in code review 2026-10-03: Edge replaced Firefox at Smuck's call; Firefox tracked in deferred-work.md), then the counter value is never lost (NFR4, first measurement recorded in the story file); and the story file records whether `rename` was reliable on the web file system, switching to direct write plus backup if it was not.
3. **Storage notice (FR27).** Given `WebPlatform.is_storage_persistent()` returns false, when the placeholder main menu is shown, then it shows the plain-words notice "Progress may not be saved in this browser mode".
4. **Tests.** Given `PlayerData`, when the GUT tests run, then `add_brains`, `set_setting` and their signals are covered and pass.

## Tasks / Subtasks

- [x] **Task 0: Firefox gate** (AC: 2). Firefox is **still not installed** (checked 2026-10-03: not in `Program Files`, `Program Files (x86)` or `%LOCALAPPDATA%`). AC 2 requires Chrome **and** Firefox. Ask Smuck to install it before Task 5; **do not download or install it yourself**. Tasks 1–4 don't need it, so start them right away. If it's still missing at Task 5, stop and ask.
- [x] **Task 1: `PlayerData` tests first** (AC: 1, 4). Write `tests/unit/test_player_data.gd` (Dev Notes → Testing requirements), run GUT, see it fail against the stub.
- [x] **Task 2: `PlayerData`** (AC: 1). Replace the stub `scripts/autoloads/player_data.gd`.
  - [x] 2.1 Stays an autoload **without `class_name`**, 3rd in the order (already registered; don't touch `project.godot`). In `_ready()` it may use only `WebPlatform` and `SaveService` (earlier autoloads). It must **not** call `AudioManager` or `Router` (later in the order).
  - [x] 2.2 Test seam: `var save_service: SaveServiceScript = null` where `const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")` (type the var as `Node` if the preloaded-script type gives a parse problem). In `_ready()`: `if save_service == null: save_service = SaveService`. Tests assign a fresh `SaveService` instance pointed at a temp folder **before** `add_child`, so no test ever mutates or writes the real save.
  - [x] 2.3 Signals (typed, past tense, declared here because PlayerData owns the state):
    - `signal brains_changed(total: int, delta: int)`
    - `signal settings_changed(key: StringName, value: bool)`
  - [x] 2.4 Profile access: a private `func _profile() -> Dictionary` that returns `save_service.get_active_profile()` **on every call**. Don't cache the dictionary in a member: Story 1.8's F8 reset (and Epic 11's profile switch) will replace `SaveService`'s data, and a cached reference would silently go stale.
  - [x] 2.5 `func get_brains() -> int` → `int(_profile()["brains"])`.
  - [x] 2.6 `func add_brains(amount: int) -> void`:
    - `amount < 0` → contract violation: `Log.error(&"economy", "add_brains: negative amount %d" % amount)` and return without changing anything. **No `assert()`**: it would fire inside GUT (debug) and break the test that proves the rejection; `Log.error` + early return is the release-safe behaviour the architecture requires anyway. (Spending is `buy_item()` in Story 4.1, which owns the "brains never go negative" rule.)
    - `amount == 0` → silent no-op (no signal, no save). A quit run with 0 brains (Story 2.7) must not log anything.
    - Otherwise `profile["brains"] = get_brains() + amount`, emit `brains_changed(new_total, amount)`, then `save_service.request_save()`.
  - [x] 2.7 `func get_setting(key: StringName) -> bool` and `func set_setting(key: StringName, value: bool) -> void`:
    - Valid keys are the ones in `SaveSchema.profile_defaults()["settings"]` (`music_on`, `sound_on`). Don't hard-code a second list; read the defaults' keys. Look up with `String(key)` (the save's keys are `String`s; `Dictionary.get(&"x")` works on String keys in 4.7.2 but writing with a `StringName` key would create a second, different key: **always write with `String(key)`**).
    - Unknown key → contract violation: `Log.error(&"save", "unknown setting %s" % key)` (no `assert`, same reason as 2.6), return (`get_setting` returns `false`).
    - Value equal to the current value → no-op (no signal, no save).
    - Otherwise write it, emit `settings_changed(key, value)`, `save_service.request_save()`.
    - PlayerData does **not** mute any bus. Applying `music_on`/`sound_on` to `AudioManager` (and restoring it on launch) is Story 4.2's wiring; AudioManager is after PlayerData in the autoload order, so PlayerData can't drive it in `_ready()` anyway.
  - [x] 2.8 `##` header: "single in-memory source of truth for the active profile; the only code that writes save fields; every mutation emits a typed signal and requests a save; getters read through `SaveService.get_active_profile()` every call; `save_service` is a test seam". List the later methods by story so agents know where they go: `buy_item`/`equip`/`unequip`/`set_flag`/`get_flag` (4.1), `record_run` (2.8), `mark_unlock_seen`/`mark_level_chosen`/`get_unlock_state` (6.8). Don't stub them now.
  - [x] 2.9 No `_process`, no logging per call except errors (a brain is added many times per run later; `Log.debug` at most).
- [x] **Task 3: Counter on the keyboard test screen** (AC: 2).
  - [x] 3.1 In `scenes/screens/keyboard_test.tscn`, add (inside `Box`, above `FullscreenButton`) a `%BrainsLabel` (Label, same chalk color as its siblings, text `"Brains: ?"`) and a `%BrainButton` (Button, `focus_mode = 0` like the other buttons so Space/Enter typed on this screen can never press it, text `"+1 brain"`). Optional but recommended for Task 5: a `%SaveStatusLabel` showing `"Last save: never"` / `"Last save: 2.3 s ago"` from `SaveService.last_write_ticks_msec` (read-only; refreshed by the existing 0.5 s `RefreshTimer`). The `Box` is 400 px tall in a 360 px viewport already; if the new rows overflow, shrink the `separation` to 4 or drop the `VisibleLabel` font size rather than growing the box off-screen. Check it visually (Task 4.3).
  - [x] 3.2 In `scripts/screens/keyboard_test.gd`: `_ready()` connects `PlayerData.brains_changed` to `_on_player_data_brains_changed` and `%BrainButton.pressed` to `_on_brain_button_pressed`, and sets the label from `PlayerData.get_brains()`. `_exit_tree()` disconnects the autoload signal (guard with `is_connected`), next to the existing `capture_keys = false`.
  - [x] 3.3 `_on_brain_button_pressed()` → `PlayerData.add_brains(1)`. Nothing else: the label updates only through the signal (proves the signal path, same as the real HUD counter later).
  - [x] 3.4 Update the script's `##` header: the counter is temporary (Story 1.7, NFR4 measurement) and goes with the screen.
- [x] **Task 4: Storage notice on the placeholder main menu** (AC: 3).
  - [x] 4.1 In `scenes/screens/main_menu.tscn` add a `%StorageNotice` `PanelContainer` anchored to the **bottom-right corner** (DESIGN.md: "a small parchment note … pinned to a menu corner"), `visible = false`, `mouse_filter = 2` (ignore; non-interactive, never blocks), with a `StyleBoxFlat` background parchment `#F6E7C1` and a 1 px ink `#1E1428` border, and a child `Label` (`%StorageNoticeLabel`) in ink `#1E1428`, font size 16 (`typography.label`), text exactly `Progress may not be saved in this browser mode`, autowrap on, max width ~260 px so it stays a small note. No red, no warning icon (DESIGN.md: "informational, not alarming"). The thumbtack is Story 5.0 art; skip it.
  - [x] 4.2 In `scripts/screens/main_menu.gd`: `const STORAGE_NOTICE_TEXT: String = "Progress may not be saved in this browser mode"`; set the label from it in `_ready()` (single source for the test). Add `func _show_storage_notice(persistent: bool) -> void: %StorageNotice.visible = not persistent` and call it from `_ready()` with `WebPlatform.is_storage_persistent()`. The parameter is the test seam (desktop always returns `true`, so the `false` branch is tested by calling it directly).
  - [x] 4.3 Keep everything already in the menu (payload label, 4 buttons, `PlayButton.grab_focus()`). The notice must not take focus or steal clicks from the buttons.
- [x] **Task 5: Verify** (AC: all)
  - [x] 5.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then GUT: all tests pass (136 at HEAD + new), exit 0, and **no** `Parse Error` / `Failed to load script` / `SCRIPT ERROR` lines in the output.
  - [x] 5.2 Boundary grep (AC 1, "no other script writes save fields"): `grep -rn "get_active_profile\|get_data()" scripts/` finds callers only in `player_data.gd` (and the definitions in `save_service.gd`); `grep -rn "FileAccess\|DirAccess" scripts/` still finds only `save_service.gd`; `grep -rn "request_save" scripts/` finds only `player_data.gd` and `save_service.gd`.
  - [x] 5.3 Desktop run (Godot MCP `run_project` + `get_debug_output`): Title → Menu (no notice on desktop) → Keyboard Test → click "+1 brain" 3 times → label shows the right total; the log shows one `[INFO][save] written` per click (one write per frame, coalesced). Close the window with a real close (see 1.6 debug log: `Process.CloseMainWindow()`, not `stop_project`), run again → the counter shows the same total. Take a screenshot of the keyboard test screen to check the new rows fit inside 640×360.
  - [x] 5.4 Web build: `mkdir -p build/web`, export the **Web** preset (debug export is fine for the console messages), serve with `python -m http.server 8060 -d build/web`, open `http://localhost:8060/`. Use **Smuck's real Chrome and Firefox** for the reload and tab-close runs (the built-in browser pane can't close and reopen its own tab realistically and pauses `requestAnimationFrame` when hidden). The built-in pane is fine for a first smoke and for reading the console.
  - [x] 5.5 **NFR4 measurement (AC 2)**, per browser (Chrome, Firefox), in a **normal** window, recorded as a table in the Dev Agent Record (browser, run #, value before, action, value after, any `[WARN]`/`[ERROR]` in the console):
    - **10 reloads:** on the Keyboard Test screen, click "+1 brain" (vary 1–3 clicks), wait ~1 s, press F5, walk Title → Menu → Keyboard Test, read the counter. Then do **at least 3 "fast" reloads** where F5 is pressed immediately (< 0.3 s) after the click.
    - **10 tab closes:** click "+1 brain", close the tab (Ctrl+W), reopen the URL in a new tab, read the counter. Include **at least 3 "mid-menu" closes** (NFR4's wording: click on the test screen, Esc back to the **main menu**, then close) and **at least 3 fast closes** right after a click.
    - Pass = the value after equals the value before in every row. A fast row that loses the last click is a **finding**, not something to hide: record it and go to 5.7.
  - [x] 5.6 **`rename` reliability (AC 2):** during 5.5, watch the console for `[WARN][save] rename failed`. Also open DevTools → Application (Chrome) / Storage (Firefox) → IndexedDB → `/userfs` and record which files exist (`save.json`, `save.bak`, and **no** lingering `save.tmp`). Record the verdict: "rename reliable on Chrome/Firefox web FS: yes/no". If **no**, change `SaveService.save_now()` to direct write plus backup (write `save.json` directly after copying the good one to `save.bak`, no tmp) as the architecture allows, add/adjust the GUT tests, and record it. If yes, change nothing.
  - [x] 5.7 **If 5.5 loses data:** don't improvise JS. Record exactly which case lost it (fast reload, fast close, mid-menu close) and stop and ask Smuck; the fix lives in `WebPlatform` (Boundary 3) and is a design decision (see Dev Notes → "Web persistence facts" for the candidate fixes).
  - [x] 5.8 **FR27 notice in the browser (AC 3, best effort):** record `is_storage_persistent()` (the boot log `[INFO][web] storage persistent: …`) in Chrome and Firefox **normal and private** windows, and whether the notice showed. Private windows may well report `true` (both browsers now give private windows an in-memory IndexedDB), in which case the notice won't show there; that's fine: the false branch is proven by the unit test. Note whether progress survives closing a private window (it shouldn't; that's expected and explains why the notice exists).
  - [x] 5.9 **Deferred Firefox checks from Story 1.5** (deferred-work.md says "verify alongside Story 1.7"): while Firefox is open, on the Keyboard Test screen record per key (Space, `'`, `/`, Backspace, Tab): echoed or not, quick-find opens or not, focus stays on the canvas. And Esc-in-fullscreen in Chrome and Firefox (Fullscreen button → Esc → label returns to "off"; does the first Esc also reach the game?). Record in the Dev Agent Record and strike the matching lines in `deferred-work.md`. These are not 1.7 ACs; if anything fails, record it and defer, don't fix here.
  - [x] 5.10 Two tabs (observation only, from the 1.6 review deferral): open the game in two tabs, add brains in tab A, reload tab B, note what B shows; add in B, reload A. Record "last writer wins" or otherwise. No fix in this story.
  - [x] 5.11 Update `sprint-status.yaml` (`review` when done) and `deferred-work.md` (anything deferred; strike the 1.6 items this story measured: visibility_hidden IDB sync, rename reliability, two tabs).

## Dev Notes

### Scope boundaries (what this story is NOT)

- **Only `add_brains`, `set_setting` (+ `get_brains`, `get_setting`) and two signals.** No `buy_item`, `equip`, `set_flag`, `record_run`, no `equipment_changed` signal: those come with the stories that use them (4.1, 2.8). Don't stub them.
- **No audio wiring of settings.** `set_setting` saves and signals; muting buses from it (and restoring on launch) is Story 4.2 (menu toggles) and 2.7 (pause panel).
- **No HUD brain counter, no real main menu.** The counter is a temporary dev widget on the keyboard test screen; the notice is on the placeholder menu. Story 4.2 rebuilds the menu (and must keep the notice).
- **No debug overlay, F5 cheat, F8 reset or save export** (Story 1.8). But design `PlayerData` so a reset works later: that's why `_profile()` re-reads `SaveService` every call (Task 2.4).
- **No `SaveService` changes** unless Task 5.6 proves `rename` unreliable on web (then: direct write plus backup) or Smuck approves a fix from Task 5.7.

### Current state of files being modified

- **`scripts/autoloads/player_data.gd`**: a 2-line stub (`extends Node` + `## Profile state … Stub until Story 1.7.`). Replace it. Registered 3rd: `PlayerData="*res://scripts/autoloads/player_data.gd"`. `tests/unit/test_project_settings.gd` asserts the order and that it's an enabled singleton; must still pass.
- **`scripts/autoloads/save_service.gd`** (Story 1.6, done; **read, don't modify**): loads in `_ready()` (so by the time `PlayerData._ready()` runs, `get_active_profile()` is valid). Public API PlayerData uses: `get_active_profile() -> Dictionary` (live reference: `_data["profiles"][_data["active_profile"]]`), `request_save()` (dirty flag + one `call_deferred` write at the end of the frame), `last_write_ticks_msec` (for the optional save-status label). Also: `save_now()` writes synchronously on `WebPlatform.visibility_hidden` and `NOTIFICATION_WM_CLOSE_REQUEST`, but **only when dirty**; a save with a newer `schema_version` is read-only (`save_now()` returns `ERR_LOCKED` with a warning; PlayerData still mutates memory; that's fine). `save_dir` is its test seam. Numbers in the loaded data are already `int` (`SaveSchema.normalize_numbers`), and missing fields are already filled, so `_profile()["brains"]` and `["settings"]["music_on"]` always exist with the right types.
- **`scripts/core/save_schema.gd`**: `profile_defaults()` returns a fresh dict each call; `["settings"]` has `music_on: true`, `sound_on: true`. Use it as the list of valid setting keys. No change.
- **`scripts/screens/keyboard_test.gd` / `.tscn`** (Story 1.5): echo screen with `capture_keys` on, Fullscreen/Download/Back buttons (all `focus_mode = 0`), a 0.5 s `RefreshTimer` → `_refresh_status()`, `_unhandled_input` swallows every key (Esc → main menu). `Box` is a VBox at offsets ±320 × ±200 (taller than the 360 px viewport already). **Preserve**: `capture_keys` set in `_ready()`/reset in `_exit_tree()`, `apply_key()` (static, tested), the echo labels, Esc/Back. `tests/unit/test_keyboard_test.gd` must keep passing (it instantiates the scene; it must not click the new brain button, which would hit the live PlayerData).
- **`scripts/screens/main_menu.gd` / `.tscn`** (Story 1.3 + 1.5): `_ready()` takes the payload into `%PayloadLabel`, connects Play/Closet/Gift/KeyboardTest, `PlayButton.grab_focus()`. `tests/integration/test_screen_flow.gd` instantiates every screen and checks the placeholder buttons exist; must keep passing.
- **`scripts/autoloads/web_platform.gd`**: `is_storage_persistent()` returns `OS.is_userfs_persistent()` (desktop: `true`); logs `[INFO][web] storage persistent: …` once at web boot. No change.
- **Not touched:** `project.godot`, `router.gd`, `audio_manager.gd`, `game_constants.gd`, `export_presets.cfg`, CI.

### PlayerData shape (target)

```gdscript
extends Node
## (header per Task 2.8)

signal brains_changed(total: int, delta: int)
signal settings_changed(key: StringName, value: bool)

const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")

## Test seam: tests assign a fresh SaveService (save_dir in a temp folder) before add_child.
var save_service: Node = null


func _ready() -> void:
	if save_service == null:
		save_service = SaveService


func get_brains() -> int:
	return int(_profile()["brains"])


func add_brains(amount: int) -> void:
	if amount < 0:
		Log.error(&"economy", "add_brains: negative amount %d" % amount)
		return
	if amount == 0:
		return
	var total: int = get_brains() + amount
	_profile()["brains"] = total
	brains_changed.emit(total, amount)
	save_service.request_save()


func _profile() -> Dictionary:
	return save_service.get_active_profile()
```

Calling `save_service.get_active_profile()` / `request_save()` through a `Node`-typed var is a dynamic call; that's fine under `untyped_declaration = Error` (the rule is about declarations), but if `unsafe_method_access` warnings show up, type the var as the preloaded script instead. Contract violations use `Log.error` + early return only, no `assert()` (asserts fire in GUT's debug run and would break the rejection tests); say so in the header.

### Web persistence facts (read before Task 5)

- **How Godot 4.7 web persists `user://`** (godot `platform/web/os_web.cpp`, checked 2026-10-03): `user://` lives in an in-memory FS mounted on IndexedDB. Closing a file under `/userfs` sets `idb_needs_sync = true`; the actual IndexedDB sync (`godot_js_os_fs_sync`) only starts in `main_loop_iterate()`, i.e. on the **next engine frame**, and is asynchronous. There is **no sync on `beforeunload`/`pagehide`**.
- Consequences to expect (hypotheses for Task 5.5 to confirm or refute, not facts):
  - Normal click → wait → reload/close: the write happens at the end of the click frame, the sync starts the frame after, and IndexedDB finishes in milliseconds. Should never lose data.
  - **Fast** reload/close right after a click: the write + sync start within ~2 frames (~33 ms); a human F5 is slower than that, so probably fine, but this is the case to watch.
  - Tab close of a **dirty** save: `visibility_hidden` → `SaveService.save_now()` writes to memory, but the browser stops `requestAnimationFrame` in a hidden tab, so the engine may never run the next frame that starts the sync. Because the click-frame write already synced, there's normally nothing dirty at that point, so this is rarely hit. Deferral from 1.6: "a write made inside the `visibility_hidden` handler may not reach IndexedDB" is exactly this.
- **Candidate fixes if data is lost (Task 5.7, ask Smuck first):** (a) in `WebPlatform`, after a hide-time write, force the sync from JS (needs a reachable handle to Godot's FS sync; the engine's FS object isn't a stable public global, so this needs investigation); (b) mirror the save JSON into `localStorage` from `WebPlatform` on every write and prefer the newer copy on load (synchronous, survives tab close; changes the "only SaveService touches files" story slightly, since WebPlatform would own a browser storage API); (c) accept the edge case if only sub-second fast-closes lose a brain. Record which one Smuck picks.
- `OS.is_userfs_persistent()` is true when the IndexedDB mount succeeded. Current Chrome and Firefox private windows have (in-memory) IndexedDB, so they may report `true` and still lose everything when the private window closes; FR27's notice covers only the cases where IDB is unavailable.
- `rename` on the in-memory FS is a plain MEMFS rename, so it's expected to work; Task 5.6 records it.
- Built-in browser pane: a hidden pane pauses `requestAnimationFrame` (1.3/1.4 notes). That's the same mechanism as a hidden tab, so the pane is useless for measuring NFR4. Use Smuck's Chrome/Firefox.

### Architecture compliance

- **State Management:** `PlayerData` is the single in-memory source of truth; all mutations go through its methods; each emits a typed change signal and requests a save. **No other code writes save fields directly** (AC 1; Task 5.2 grep).
- **Boundary 3:** only `SaveService` touches files; PlayerData never uses `FileAccess`/`DirAccess` and never calls `save_now()` (only `request_save()`).
- **Boundary 4:** screens change state only through `PlayerData` methods (the keyboard test button calls `PlayerData.add_brains(1)`; the menu only reads `WebPlatform`).
- **Autoload rules:** 3rd in order; in `_ready()` uses only `SaveService`/`WebPlatform`; no `class_name`. Listeners connect to `PlayerData` signals in `_ready()` with Callables and disconnect in `_exit_tree()`.
- **Event naming:** past tense, typed params (`brains_changed(total: int, delta: int)` exactly as the architecture's example; `settings_changed(key: StringName, value: bool)`). Handlers named `_on_player_data_brains_changed`, `_on_brain_button_pressed`.
- **IDs:** `StringName` in code (`&"music_on"`), plain `String` keys in the save.
- **Error handling:** contract violations (negative amount, unknown setting) → `Log.error` + early return, never a crash; nothing shown to the player. **Player-visible errors: only the FR27 notice**.
- **Logging tags:** `&"economy"` for brains, `&"save"` for settings. No logs per successful mutation above `debug`; never log save contents (NFR12).
- **Static typing everywhere** (`untyped_declaration = Error`); no literal gameplay numbers (the `1` in `add_brains(1)` is the test counter's step, not a balance number).
- **Kid-facing text:** the notice copy is fixed by EXPERIENCE.md ("Progress may not be saved in this browser mode"); don't reword it.

### File structure requirements

New:
```
tests/unit/test_player_data.gd (+ .uid)
```
Modified: `scripts/autoloads/player_data.gd` (stub replaced), `scripts/screens/keyboard_test.gd`, `scenes/screens/keyboard_test.tscn`, `scripts/screens/main_menu.gd`, `scenes/screens/main_menu.tscn`, possibly `tests/unit/test_keyboard_test.gd` and `tests/integration/test_screen_flow.gd` (new assertions), `sprint-status.yaml`, `deferred-work.md`, this story file. `save_service.gd` only if Task 5.6/5.7 requires it.

### Testing requirements

GUT 9.7.1 facts (1.1–1.6):
- An unexpected `push_error` **fails** the test: every test that triggers `Log.error()` must `assert_push_error("…")`. Assert expected warnings with `assert_push_warning`.
- **Never test through the live autoloads.** The live `PlayerData` is wired to the live `SaveService`, whose `save_dir` is the real `user://`. A mutation through it would change, and at the end of the frame **write**, Smuck's real save. Use fresh instances:
  ```gdscript
  const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
  const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
  const TEST_DIR: String = "user://test_player_data/"

  func _make() -> PlayerDataScript:
      var save: SaveServiceScript = SaveServiceScript.new()
      save.save_dir = TEST_DIR
      add_child_autofree(save)
      var sut: PlayerDataScript = PlayerDataScript.new()
      sut.save_service = save
      add_child_autofree(sut)
      return sut
  ```
  Clear `TEST_DIR` in `before_each`/`after_each` (copy `_clear()` from `test_save_service.gd`). Keep the `SaveService` reference (`_save`) for assertions.
- Count signals with `watch_signals(sut)` + `assert_signal_emit_count` / `assert_signal_emitted_with_parameters(sut, "brains_changed", [5, 5])`. Count writes with `watch_signals(_save)` + `assert_signal_emit_count(_save, "save_written", 1)` after `await wait_process_frames(2)`.
- Use `wait_process_frames`, not the deprecated `wait_frames`.
- Grep the GUT output for `Parse Error|Failed to load script|SCRIPT ERROR` (a test file that fails to parse is silently skipped). Run `--import` after adding the new test file.
- Godot: `"/c/Program Files/Godot/Godot.exe"`. GUT: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.

`tests/unit/test_player_data.gd`:
- `test_get_brains_reads_loaded_save`: put `save_v1_full.json` (brains 340) into `TEST_DIR` as `save.json` before `_make()` → `get_brains() == 340`; settings read `music_on == false`, `sound_on == true`.
- `test_fresh_save_defaults`: empty folder → `get_brains() == 0`, both settings `true`.
- `test_add_brains_updates_total_and_emits` (AC 1, 4): `add_brains(5)` then `add_brains(3)` → `get_brains() == 8`; `brains_changed` emitted twice, last with `[8, 3]`; `_save.get_active_profile()["brains"] == 8` (it really is the save's dictionary, no copy).
- `test_add_brains_requests_one_coalesced_save` (AC 1): `add_brains(1)` ×3 in one frame → after `wait_process_frames(2)`, `save_written` count 1, and `save.json` in `TEST_DIR` parses to `brains == 3`.
- `test_add_brains_zero_is_a_noop`: no signal, no save after waiting, no error.
- `test_add_brains_negative_is_rejected`: `add_brains(-5)` → total unchanged, no signal, `assert_push_error("negative")`.
- `test_set_setting_changes_value_emits_and_saves` (AC 1, 4): `set_setting(&"music_on", false)` → `get_setting(&"music_on") == false`, `settings_changed` emitted with `[&"music_on", false]`, one write; the written file has `"music_on": false`.
- `test_set_setting_writes_string_key`: after `set_setting(&"sound_on", false)`, `_save.get_active_profile()["settings"].keys()` contains `"sound_on"` exactly once and every key is a `String` (`typeof == TYPE_STRING`). Guards against the StringName-key trap.
- `test_set_setting_same_value_is_a_noop`: setting `music_on` to `true` on a fresh save → no signal, no write.
- `test_set_setting_unknown_key_is_rejected`: `set_setting(&"volume", true)` → nothing added to `settings`, no signal, `assert_push_error("unknown setting")`; `get_setting(&"volume")` → `false` with an error too.
- `test_profile_is_read_live`: replace the save's data the way a 1.8 reset would (e.g. `_save.get_active_profile()["brains"] = 77` directly, or swap `_save._data` for `SaveSchema.defaults()`) → `get_brains()` follows without re-creating PlayerData.
- `test_uses_live_save_service_by_default`: a fresh `PlayerDataScript.new()` without the seam, after `add_child_autofree`, has `save_service == SaveService` (the live autoload). Don't call any mutator on it.

Other test touches:
- `test_keyboard_test.gd`: add `test_brain_counter_shows_player_data_total` (label text contains `str(PlayerData.get_brains())` after `_ready()`; **read-only** on the live autoload) and `test_brain_button_does_not_take_focus` (`focus_mode == FOCUS_NONE`; extend the existing button-focus test if it loops over buttons). Optionally prove the signal path without touching the live wallet: emit `PlayerData.brains_changed.emit(123, 1)` is **not** OK (other listeners may react); instead call the screen's handler `_on_player_data_brains_changed(123, 1)` directly and check the label. Also check the screen disconnects from `PlayerData.brains_changed` after it's freed. While in this file, swap the deprecated `wait_frames` for `wait_process_frames` (1.6 deferral).
- `test_screen_flow.gd` (or a new `tests/unit/test_main_menu.gd`): the notice is hidden on desktop after `_ready()` (persistent is `true` there); `_show_storage_notice(false)` makes it visible and its label text equals `"Progress may not be saved in this browser mode"`; `_show_storage_notice(true)` hides it; the notice's `mouse_filter` is `MOUSE_FILTER_IGNORE` and the Play button still has focus.

### Previous story intelligence (1.1–1.6)

- **1.6 built exactly the hand-off this story uses:** `get_data()`/`get_active_profile()` (live dicts, "PlayerData only"), `request_save()` coalescing, `last_write_ticks_msec`, `save_written`. Its review guarded hide/close writes with `if _dirty`, so after a coalesced click-frame write there is normally nothing left to write on hide. 136 GUT tests pass at HEAD.
- 1.6 Open question 1 was decided "no write on first boot": `save.json` first appears on the first `request_save()` (now: the first "+1 brain" click) or on close/hide. Don't add a boot write.
- **Test pattern for autoloads** (1.3–1.6): fresh instance from the preloaded script, seams set before `add_child_autofree`, private handlers called directly; the live autoload is only read. Here that means a fresh `SaveService` **and** a fresh `PlayerData`.
- JSON numbers come back as floats; `SaveSchema.prepare` already normalizes them to `int`, so `int(...)` in `get_brains()` is belt-and-braces, not a fix for a known problem.
- `String` vs `StringName` keys: reading a String-keyed dict with `&"x"` works (verified 4.7.2, 1.6 notes); writing with a StringName creates a separate key in a typed context. Always write `String(key)`.
- 1.5: one tab switch fires both `focus_lost` and `visibility_hidden`; `SaveService` listens only to `visibility_hidden`. Godot dispatches web input from its main loop, not inside the browser event, which doesn't matter for saving (no gesture rule) but explains why rAF stalls matter.
- 1.5 web workflow: `mkdir -p build/web`, export Web, `python -m http.server 8060 -d build/web`, `http://localhost:8060/`. Built-in pane good for console + `javascript_tool`; Smuck's real browsers for hands-on checks.
- Desktop close in 1.6: `stop_project` kills the process (no `WM_CLOSE_REQUEST`); a real close used `Process.CloseMainWindow()` (PowerShell).
- Desktop user data: `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/` holds a defaults `save.json`/`save.bak` from 1.6's check; the 5.3 desktop run will change the brains there. Mention it to Smuck; don't delete without asking.

### Git intelligence

- Recent commits: `87913aa` Story 1.6 (SaveSchema, SaveService, fixtures, 33+5 tests), `803a575` 1.5 (WebPlatform, keyboard test), `580aba1` 1.4 (AudioManager), `ab8585a` 1.3 (Router, screens), `b3166e8` 1.2 (CI/Pages). Tree clean at story creation.
- Commit style: `Story 1.N: <summary>` with a short body and the `Co-Authored-By` trailer. Commit only when Smuck asks.

### Latest tech information (checked 2026-10-03)

- Godot 4.7.2-stable, single-threaded web export. `user://` on web = MEMFS + IndexedDB sync started from the engine main loop after a file under `/userfs` is closed; no unload-time sync (godot master `platform/web/os_web.cpp`). `OS.is_userfs_persistent()` reflects whether that IndexedDB mount is usable.
- Chrome and Firefox throttle or stop `requestAnimationFrame` in hidden tabs; Godot's web main loop runs on rAF, so engine frames stop while the tab is hidden.
- No new libraries. GUT 9.7.1 APIs used: `watch_signals`, `assert_signal_emit_count`, `assert_signal_emitted_with_parameters`, `assert_push_error`, `wait_process_frames`.

### Project Structure Notes

- Matches the architecture: `scripts/autoloads/player_data.gd` ("Profile state, wallet, cosmetics, history; single source of truth; emits change signals"), test in `tests/unit/test_player_data.gd` (consistency rule: `player_data.gd` must have a unit test).
- **Variance (small, additive):** `PlayerData.save_service` test seam; `settings_changed` carries `(key, value)` (the epic names the signal without parameters; the architecture requires typed params). The counter lives on the temporary keyboard test screen (as the AC says), not on a HUD.
- The storage notice on the placeholder menu is a plain `PanelContainer`; Story 4.2 must carry it into the real menu (add a note to 4.2 only if you touch planning docs; otherwise mention it in Completion Notes).

### Project Context Rules

- There is no `project-context.md`. Rules come from the architecture (State Management, Event System, Data Persistence, Error Handling, Boundaries, Consistency Rules, Naming) and Stories 1.1–1.6: strict static typing, `Log` for all logging, tests first for logic, fresh instances instead of live autoloads in tests, the GUT parse-error grep, standard Godot build only.
- Tools: Godot MCP (`run_project`, `get_debug_output`, `stop_project`) for the desktop run; Godot binary at `/c/Program Files/Godot/Godot.exe` for `--import`, export and GUT; built-in browser for the web smoke/console; Smuck's Chrome and Firefox for NFR4.

### Open Questions for Smuck (none block Tasks 1–4)

1. **Install Firefox** (Task 0). Needed for AC 2 and for the deferred 1.5 Firefox checks.
2. **Who runs the 40 browser rounds?** 10 reloads + 10 closes × 2 browsers is hands-on work in your real browsers. Plan: the dev agent sets up the build and the table, you click and read the counter (or allow the agent to drive Chrome through the Chrome extension, if connected). Say which you prefer.
3. **If a fast close loses the last brain** (Dev Notes → Web persistence facts): fix now (localStorage mirror or JS-forced sync in `WebPlatform`) or accept and defer to Epic 5? Only relevant if Task 5.5 finds it.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.7: Player Data Service and Reload-Proof Counter]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory] (FR27, FR51, FR52, NFR4, NFR12, NFR16; Additional Requirements → Data, Testing, Core architecture)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.8, #Story 2.7, #Story 2.8, #Story 4.1, #Story 4.2] (later users of `add_brains`, `set_setting`, signals, the notice)
- [Source: _bmad-output/game-architecture.md#State Management, #Data Persistence, #Event System, #Error Handling, #Architectural Boundaries, #Data Patterns, #Consistency Rules, #Naming Conventions]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] (storage-notice component: parchment `#F6E7C1`, ink `#1E1428`, label 16 px, corner note, not alarming)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] (notice copy; shown only when not persistent; non-interactive; "Save write fails → silent")
- [Source: _bmad-output/implementation-artifacts/1-6-versioned-save-file.md] (SaveService API, test patterns, desktop close method)
- [Source: _bmad-output/implementation-artifacts/1-5-web-platform-service-and-keyboard-capture-test.md] (web export/serve workflow, keyboard test screen, deferred Firefox checks)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (1.5/1.6 items that land here)
- [Source: https://github.com/godotengine/godot/blob/master/platform/web/os_web.cpp] (IndexedDB sync timing)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Red: `test_player_data.gd` against the stub → SCRIPT ERRORs (no `save_service` property). `test_main_menu.gd` → parse error (no `STORAGE_NOTICE_TEXT`); keyboard test brain tests failed ("Brains: ?").
- Green: GUT 154/154 passing (136 at HEAD + 12 PlayerData + 3 keyboard test + 3 main menu), exit 0, no `Parse Error`/`Failed to load script`/`SCRIPT ERROR`, 0 deprecated (the `wait_frames` call is gone).
- `var save_service: SaveServiceScript` (typed with the preloaded script) parses fine; no `Node` fallback needed.
- 5.2 boundary grep: `get_active_profile`/`get_data()` called only in `player_data.gd` (definitions in `save_service.gd`); `FileAccess`/`DirAccess` only in `save_service.gd`; `request_save` only in `player_data.gd` and `save_service.gd`.
- 5.3 desktop run (window driven by a scratch PowerShell helper: SetCursorPos/mouse_event clicks, CopyFromScreen screenshots, `CloseMainWindow()` for the real close): Title → Menu (no notice, Play focused) → Keyboard Test (`Brains: 0`, `Last save: never`) → 3 clicks → `Brains: 3`, log shows 3 × `[INFO][save] written (443 bytes)`, `Last save: 1.3 s ago`. Rows fit in 640×360 (separation 8 → 4), also with the echo and a wrapped last-key line. A 4th click and an `a` key press reached the window from outside the script after the screenshot (Smuck using the window); disk then held `brains: 4`. Real close → relaunch → Keyboard Test shows `Brains: 4`. Desktop save in `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/` now has brains 4 (left in place).
- 5.4 web smoke (built-in pane, debug export): boot logs `[INFO][web] storage persistent: true`, `[INFO][save] no valid save, starting fresh`; routing to the Keyboard Test works. The pane was hidden, so frames stalled mid-fade (as predicted in Dev Notes); unusable for NFR4.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Task 0: Firefox still not installed (checked 2026-10-03). **Smuck decided to use Edge in place of Firefox** as AC 2's second browser. Recorded as a variance in deferred-work.md: Edge is Chromium, so Firefox persistence is still unmeasured.
- `PlayerData` (AC 1): `add_brains`/`get_brains`, `set_setting`/`get_setting`, typed `brains_changed(total, delta)` and `settings_changed(key, value)`. Each real change emits its signal and calls `request_save()`; 0 or same-value calls are no-ops; a negative amount or unknown key → `Log.error` + early return, no assert. Setting keys come from `SaveSchema.profile_defaults()["settings"]` and are always written as `String`. `_profile()` re-reads `SaveService.get_active_profile()` every call (test proves it follows a replaced `_data`). `save_service` is the test seam, typed as the preloaded script.
- Keyboard Test counter (AC 2): `%BrainsLabel`, `%SaveStatusLabel`, `%BrainButton` (focus none). The label updates only through `PlayerData.brains_changed`; disconnected in `_exit_tree()`.
- Main menu storage notice (AC 3): `%StorageNotice` bottom-right parchment note (`#F6E7C1`, 1 px ink border, 16 px ink label, ~260 px wide), hidden unless `WebPlatform.is_storage_persistent()` is false, mouse ignore, no focus. Play keeps focus.
- Tests (AC 4): 12 in `test_player_data.gd`, 3 in `test_main_menu.gd`, 3 new in `test_keyboard_test.gd` (plus `%BrainButton` added to the focus loop and `wait_frames` → `wait_process_frames`), `%BrainButton` added to `test_screen_flow.gd`. 154/154 pass.
- **NFR4 measurement (AC 2), first measurement, 2026-10-03:** Smuck ran it by hand in Chrome and Edge, normal windows, on the debug web build at `http://localhost:8060/`. Checklist per browser: 10 reloads (7 normal, 3 fast < 0.3 s after a click) and 10 tab closes (4 normal, 3 mid-menu via Esc to the main menu, 3 fast). Reported result: **all rounds pass, the counter was never lost, no console warnings or errors.** Smuck reported an overall pass, not per-round counter values, so there's no per-row table (noted in deferred-work.md).
  | Browser | Reloads (normal / fast) | Tab closes (normal / mid-menu / fast) | Lost |
  |---|---|---|---|
  | Chrome | 7 / 3 pass | 4 / 3 / 3 pass | 0 |
  | Edge | 7 / 3 pass | 4 / 3 / 3 pass | 0 |
- **`rename` reliable on Chrome/Edge web FS: yes.** No `rename failed`, IndexedDB `/userfs` check reported fine. `SaveService` unchanged. 5.7 was not triggered (no data lost), so there was no WebPlatform fix to decide on.
- 5.8 FR27: normal and private (Incognito/InPrivate) windows checked, reported fine. The false branch of the notice is proven by `test_main_menu.gd`.
- 5.9: Esc-in-fullscreen in Chrome and Edge reported fine. The Firefox per-key table is still deferred (no Firefox).
- 5.10: two-tab check done, reported with no surprises (last writer wins is the expected model). No fix.
- Story 4.2 must keep the storage notice in the real menu (noted in deferred-work.md; planning docs not touched).

### File List

- scripts/autoloads/player_data.gd (stub replaced)
- scripts/screens/keyboard_test.gd
- scenes/screens/keyboard_test.tscn
- scripts/screens/main_menu.gd
- scenes/screens/main_menu.tscn
- tests/unit/test_player_data.gd (new) + .uid
- tests/unit/test_main_menu.gd (new) + .uid
- tests/unit/test_keyboard_test.gd
- tests/integration/test_screen_flow.gd
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/1-7-player-data-service-and-reload-proof-counter.md

### Change Log

- 2026-10-03: Story 1.7 created (ready-for-dev).
- 2026-10-03: Implemented PlayerData (brains, settings, signals, coalesced saves), the Keyboard Test brain counter and the FR27 storage notice; 18 new GUT tests (154 total). NFR4 measured in Chrome + Edge (Edge replaced Firefox at Smuck's request): no data lost, rename reliable. Status → review.

### Review Findings

- [x] [Review][Decision] (resolved: option 1, AC 2 amended to Chrome + Edge, Firefox stays in deferred-work.md) AC 2 met only partially: Edge replaced Firefox, and the evidence is thin — AC 2 and Task 0/5.5/5.6/5.8/5.9 say Chrome **and** Firefox, with a per-row NFR4 table, the `/userfs` file list, per-browser `storage persistent:` and notice results, and a Firefox key table. The record holds only aggregate "pass" results for Chrome and Edge (3 fast reload/close rows have no counter values). Options: (a) amend AC 2 to "Chrome + Edge" and accept the variance (Firefox already tracked in deferred-work.md); (b) keep the story `in-progress` until Firefox is installed and the table is recorded.
- [x] [Review][Decision] (resolved: option 3, accepted as-is for the dev-only counter) `add_brains` keeps counting on a read-only (newer-schema) save — `SaveService` returns `ERR_LOCKED` and never writes, but `PlayerData.add_brains` still updates memory and emits `brains_changed`, so the counter climbs and reverts on reload. This can fake a "lost on reload" result. Options: reject mutations while read-only (log + no signal), keep counting but show a "not saving" indicator, or accept as-is for the dev-only counter. [scripts/autoloads/player_data.gd:147]
- [x] [Review][Patch] `test_disconnects_from_player_data_when_freed` leaks the node if an assert fails mid-test — use `add_child_autofree`, or free in a guarded path. [tests/unit/test_keyboard_test.gd:344]
- [x] [Review][Defer] No overflow guard on `add_brains` (int64 wraps with a huge amount) [scripts/autoloads/player_data.gd:147] — deferred, theoretical; no caller passes such values
- [x] [Review][Defer] No "profile replaced" notification, so UI goes stale after Story 1.8's F8 reset [scripts/autoloads/player_data.gd] — deferred, belongs to Story 1.8 / Epic 11
