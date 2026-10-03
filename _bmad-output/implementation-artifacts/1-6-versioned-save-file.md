---
baseline_commit: 803a5754f2be4f78d2a308ce6375e82e4d9d18f7
---

# Story 1.6: Versioned Save File

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want my progress saved safely,
so that I never lose my brains or hats.

## Acceptance Criteria

1. **Defaults.** Given `SaveSchema.defaults()`, when a fresh save is created, then it matches the architecture's v1 JSON: `schema_version: 1`, `active_profile: "p1"`, and a `p1` profile with name, brains, owned_items, equipped hat/pet, flags (welcome_bonus_claimed, tutorial_seen, placement_done), tier, settings (music_on, sound_on), best_wpm and an empty run_history (FR51).
2. **Atomic write and backup.** Given `SaveService` (the only script that touches files), when a save is written, then it writes `save.tmp`, renames it over `save.json` and keeps the previous file as `save.bak`; and if `save.json` fails to parse on load, `save.bak` is used; if both fail, defaults are used and no error is shown to the player.
3. **Missing and unknown fields.** Given a loaded save that is missing fields or has unknown fields, when it is loaded, then missing fields are filled from defaults and unknown fields are kept.
4. **Migrations.** Given the ordered migration framework (`migrate_N_to_N1`), when a save with `schema_version` below `CURRENT_SCHEMA` is loaded, then migrations run in order up to the current version.
5. **Coalescing and immediate writes.** Given several `SaveService.request_save()` calls in the same frame, when the frame ends, then exactly one write happens; and on `WebPlatform.visibility_hidden` or `NOTIFICATION_WM_CLOSE_REQUEST` the save is written immediately (FR52).
6. **Export.** Given `SaveService.export_json()`, when it is called, then it returns the current save as the same pretty-printed JSON that is written to `save.json`, without touching the file system.
7. **Tests.** Given fixtures `save_v1_fresh.json`, `save_v1_full.json` and `save_corrupt.json`, when the GUT tests run, then defaults, round-trip, missing-field fill, unknown-field keep, backup fallback and write coalescing are all covered and pass.

## Tasks / Subtasks

- [x] **Task 1: Fixtures** (AC: 1, 3, 7). Create them first; the tests in Tasks 2–3 read them.
  - [x] 1.1 `tests/fixtures/saves/save_v1_fresh.json`: exactly the architecture's v1 JSON (see Dev Notes → "v1 shape"), tab-indented, keys sorted (the same text `JSON.stringify(SaveSchema.defaults(), "\t")` produces; generate it once from the code if easier, then check it by eye against the architecture block). Delete the `.gitkeep` in that folder once real files exist.
  - [x] 1.2 `save_v1_full.json`: a realistic, filled-in v1 save. `brains: 340`, `owned_items: ["hat_pumpkin", "pet_cute_ghost"]`, `equipped: {"hat": "hat_pumpkin", "pet": "pet_cute_ghost"}`, all three flags `true`, `tier: 0`, `settings: {"music_on": false, "sound_on": true}`, `best_wpm: {"zombie_run": 14}`, and **2 run records** in the architecture's run-record shape (Dev Notes → "Run record"), one with a `per_key` entry like `"f": [14, 3, {"g": 2, "d": 1}]`. Add **one unknown field at the root** (`"x_future_root": "keep me"`) and **one inside the profile** (`"x_future_profile": {"kept": true}`), so the same fixture proves AC 3's "unknown fields are kept".
  - [x] 1.3 `save_corrupt.json`: truncated JSON text (e.g. the first ~40 characters of the fresh file, cut mid-object). It must fail `JSON.parse`.
  - [x] 1.4 Fixtures live under `res://tests/` (export-excluded). Tests read them with `FileAccess.get_file_as_string()`; that is fine, the "only `SaveService` touches files" rule applies to game code in `scripts/`, not to tests.
- [x] **Task 2: `SaveSchema` (pure)** (AC: 1, 3, 4). Write `tests/unit/test_save_schema.gd` first (Testing Requirements), see it fail, then create `scripts/core/save_schema.gd`.
  - [x] 2.1 `class_name SaveSchema` with only `static` functions; no `extends Node`, no autoloads, no file access, no scene tree (Boundary 1: `scripts/core/` is pure). `Log` is allowed (static class).
  - [x] 2.2 `const DEFAULT_PROFILE_ID: String = "p1"`. `static func profile_defaults() -> Dictionary` returns a **new** dictionary every call (never a shared `const` dictionary: callers mutate it). `static func defaults() -> Dictionary` returns `{ "schema_version": GameConstants.CURRENT_SCHEMA, "active_profile": DEFAULT_PROFILE_ID, "profiles": { DEFAULT_PROFILE_ID: profile_defaults() } }`. Keys are `String`s (JSON keys always are); values are `int`, `bool`, `String`, `Array`, `Dictionary` only.
  - [x] 2.3 `static func normalize_numbers(value: Variant) -> Variant`: recursively converts every `float` with an integral value to `int` (in dictionaries and arrays). Needed because Godot's JSON parser returns **every number as `float`** and `JSON.stringify` then writes `120.0` (verified on 4.7.2, see Dev Notes → "Engine facts"). Every number in the save is a whole number by design (FR7: whole %, whole WPM).
  - [x] 2.4 `static func fill_defaults(data: Dictionary) -> Dictionary` (mutates and returns `data`):
    - Deep-merge against `defaults()` for the root keys (`schema_version`, `active_profile`, `profiles`).
    - Fill **every** profile in `profiles` from `profile_defaults()`, not just `p1` (Epic 11 adds more profiles; ADR-2).
    - Merge rule per key: missing → deep copy of the default; both dictionaries → recurse; type differs from the default → replace with the default and `Log.warn(&"save", "bad type at <path>, using default")`; otherwise keep. **Keys not in the defaults are kept untouched** (AC 3). Arrays (`owned_items`, `run_history`) are kept as-is if they are arrays; their items are not checked. Dictionaries with free-form keys (`best_wpm`) keep all their keys; only the default keys are filled.
    - Repair: if `profiles` is empty, add `p1` defaults. If `active_profile` is not a key of `profiles`, `Log.warn` and set it to `"p1"` if present, else the first key in sorted order.
  - [x] 2.5 Migrations (AC 4): `static func migration_steps() -> Array[Callable]` returns `[]` today (index 0 will be `migrate_1_to_2` in Story 6.8, index 1 `migrate_2_to_3`, …). `static func migrate(data: Dictionary, steps: Array[Callable] = migration_steps(), target: int = GameConstants.CURRENT_SCHEMA) -> Dictionary`: read `schema_version` (missing, non-numeric or < 1 → `Log.warn` and treat as 1); while `version < target`: call `steps[version - 1]` with the data, take its return value, set `schema_version = version + 1`, continue. A missing step → `Log.error(&"save", ...)` and stop (return what you have; never crash). `version > target` (a save from a newer build) → `Log.warn` and return the data unchanged, keeping its higher `schema_version`. The `steps`/`target` parameters are the test seam; the game always uses the defaults. Each step is a `static func migrate_N_to_N1(data: Dictionary) -> Dictionary` on `SaveSchema`; document that naming in the header for 6.8.
  - [x] 2.6 `static func prepare(data: Dictionary) -> Dictionary`: the one pipeline `SaveService` calls after a successful parse: `normalize_numbers` → `migrate` → `fill_defaults`. Fill runs **after** migration, so it always fills against the current shape.
- [x] **Task 3: `SaveService`** (AC: 2, 5, 6). Write `tests/unit/test_save_service.gd` first, see it fail, then replace the stub `scripts/autoloads/save_service.gd`.
  - [x] 3.1 Keep it an autoload **without `class_name`**, 2nd in the order (already registered; don't touch `project.godot`). In `_ready()` it may use only `WebPlatform` (earlier autoload). `Log` and `SaveSchema` are static classes, always fine.
  - [x] 3.2 Members: `const SAVE_FILE: String = "save.json"`, `TMP_FILE = "save.tmp"`, `BACKUP_FILE = "save.bak"`; `var save_dir: String = "user://"` (**test seam**: tests set it to a temp folder **before** `add_child`, so a test can never overwrite the real save); `signal save_written`; `var last_write_ticks_msec: int = -1` (for the 1.8 debug overlay's "last save write time"); private `_data: Dictionary`, `_dirty: bool`, `_flush_scheduled: bool`, `_main_valid: bool`.
  - [x] 3.3 `_ready()`: `_data = load_save()`; `WebPlatform.visibility_hidden.connect(_on_web_platform_visibility_hidden)`. `_exit_tree()`: disconnect it (architecture: connections to autoload signals are disconnected in `_exit_tree()`; guard with `is_connected`).
  - [x] 3.4 `load_save() -> Dictionary` (AC 2): `_read_json(main)`; if empty, `_read_json(backup)` and `Log.warn(&"save", "save.json unreadable, using save.bak")`; if still empty, `SaveSchema.defaults()` with `Log.info(&"save", "no valid save, starting fresh")` (or `warn` if a file existed but was corrupt). Then `SaveSchema.prepare(data)`. Set `_main_valid = true` only when `save.json` itself parsed. Log once which source was used. **Nothing is shown to the player** (NFR9/NFR16); no `assert`, no `push_error` for a corrupt file (a parse failure is "Recoverable" → `warn`).
  - [x] 3.5 `_read_json(path) -> Dictionary`: follow the architecture's example (Dev Notes → "Architecture's `_read_json`"): missing file → `{}`; open failure → `Log.error` + `{}`; parse failure **or** a non-Dictionary **or** an empty dictionary → `Log.warn` + `{}`.
  - [x] 3.6 `get_data() -> Dictionary` and `get_active_profile() -> Dictionary`: return the **live** dictionaries (by reference) for `PlayerData` (Story 1.7) to read and mutate. Header comment: "PlayerData only. Nobody else edits save fields." No other caller in this story.
  - [x] 3.7 `request_save() -> void` (AC 5): `_dirty = true`; if not `_flush_scheduled`: `_flush_scheduled = true` and `_flush.call_deferred()`. `_flush()`: `_flush_scheduled = false`; if `_dirty`: `save_now()`. Several requests in one frame → one write at the end of the frame.
  - [x] 3.8 `save_now() -> Error` (AC 2, 5): the write algorithm in Dev Notes → "Write algorithm": `save.tmp` → copy the current valid `save.json` to `save.bak` → rename `save.tmp` over `save.json` → on rename failure, fall back to a direct write of `save.json` with `Log.warn` (the architecture's "direct write plus backup" fallback). Clears `_dirty` on success, keeps it `true` on failure (so the next request retries). On success: `_main_valid = true`, `last_write_ticks_msec = Time.get_ticks_msec()`, `Log.info(&"save", "written (%d bytes)")`, emit `save_written`. Never log the save contents (NFR12).
  - [x] 3.9 Never rotate a corrupt `save.json` into `save.bak`: copy to backup only when `_main_valid` is true. (Case: `save.json` corrupt, loaded from `.bak`; the first write must not overwrite the only good copy with garbage.)
  - [x] 3.10 Immediate writes (AC 5): `_notification(what)`: `NOTIFICATION_WM_CLOSE_REQUEST` → `save_now()`. `_on_web_platform_visibility_hidden()` → `save_now()`. Both write even when nothing is dirty (FR52 says "written"; the file is small).
  - [x] 3.11 `export_json() -> String` (AC 6): returns `_serialize()`; no `FileAccess`, no `DirAccess`. `_serialize()` is `JSON.stringify(_data, "\t")` (sort_keys stays at its default `true`) and is the **same function** `save_now()` writes, so the export and the file are byte-identical by construction.
  - [x] 3.12 Ensure `save_dir` exists before writing (`DirAccess.make_dir_recursive_absolute(save_dir)` when `DirAccess.dir_exists_absolute` is false). `user://` always exists; this is for the test folder.
  - [x] 3.13 Update the `##` header: what it does, "the only script that touches files", the write order, when writes happen, `get_data()` is for `PlayerData` only, `save_dir` is a test seam.
- [x] **Task 4: Verify** (AC: all)
  - [x] 4.1 Headless import first (new `class_name SaveSchema` and new scripts need `.uid` files): `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`.
  - [x] 4.2 GUT: all tests pass (98 existing + new), exit 0, and **no** `Parse Error` / `Failed to load script` / `SCRIPT ERROR` lines in the output (a test file that fails to parse is silently skipped).
  - [x] 4.3 Desktop run (Godot MCP `run_project` + `get_debug_output`): boot logs one `[INFO][save]` line saying a fresh save was started (or which file was loaded); no errors. Close the game window: `save.json` now exists in `OS.get_user_data_dir()` (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/`) with the v1 defaults. Run and close again: `save.bak` now exists too. Delete those test files afterwards only if Smuck agrees (they're his real save location; they're defaults, so harmless either way).
  - [x] 4.4 Hand-corrupt check (desktop, optional but quick): put garbage in `save.json`, keep a good `save.bak`, run: boot uses the backup (log line says so) and the game runs normally.
  - [x] 4.5 Boundary check: `grep -rn "FileAccess\|DirAccess" scripts/` finds only `scripts/autoloads/save_service.gd` (architecture consistency rule "Save writes"). The existing `web_platform.gd` uses `ProjectSettings.globalize_path("user://")` and `OS.shell_open`, not `FileAccess`; that's fine.
  - [x] 4.6 `git status`: new scripts, `.uid` files, fixtures and tests staged; `build/` untracked; nothing under `user://` in the repo.
  - [x] 4.7 Update `sprint-status.yaml` (`review` when done; dev-story does this) and add anything deferred to `deferred-work.md`.

### Review Findings

- [x] [Review][Patch] Tab hide / window close write even when `_dirty` is false and rotate `save.bak` — guard both with `if _dirty` (Smuck decided 2026-10-03) [scripts/autoloads/save_service.gd:40-42,173-174]
- [x] [Review][Patch] Save from a newer build (`schema_version` > current) is rewritten by an older build — skip `fill_defaults` and refuse to write while the version is newer than current (Smuck decided 2026-10-03) [scripts/core/save_schema.gd, scripts/autoloads/save_service.gd]
- [x] [Review][Patch] "written (N bytes)" logs characters, not bytes — use `text.to_utf8_buffer().size()` [scripts/autoloads/save_service.gd:116]
- [x] [Review][Patch] Failed tmp write leaves a partial `save.tmp` behind — remove it on the error path [scripts/autoloads/save_service.gd:95-99]
- [x] [Review][Patch] Direct-write fallback deletes `save.tmp` before knowing the direct write succeeded — remove tmp only after success [scripts/autoloads/save_service.gd:107-108]
- [x] [Review][Patch] `migrate()` does not check that a migration step returned a Dictionary — a null return crashes the boot-time load path; log an error and keep the data [scripts/core/save_schema.gd:migrate]
- [x] [Review][Patch] `normalize_numbers()` casts any integral float to int, including values beyond int64 (1e30) — only convert when `absf(number) < 9.0e15` [scripts/core/save_schema.gd:43]
- [x] [Review][Patch] `assert_false(text.contains(".0"))` is a false-positive trap (any "1.0.1" string or 1.05 value trips it) — assert on the specific whole-number fields instead [tests/unit/test_save_schema.gd:202]
- [x] [Review][Defer] Array element types not validated (`owned_items`, `run_history`) — only hand-edited saves can produce wrong elements; add when PlayerData/Shop consume them — deferred, not caused by a bug in this change
- [x] [Review][Defer] Fractional float in an int-default field resets the field to 0 (`best_wpm`, `brains`) — decide when best_wpm semantics are defined (Epic 3/5) — deferred
- [x] [Review][Defer] Stale `save.tmp` (complete, newest) is ignored on load after a crash between write and rename — one extra generation lost; nice-to-have — deferred
- [x] [Review][Defer] UTF-8 BOM in a hand-edited or imported save fails to parse — handle in Story 1.8 import — deferred
- [x] [Review][Defer] `load_save()` is public and does not assign `_data` (diverges from `get_data()` if called twice) — make private when a caller other than `_ready()`/tests exists — deferred
- [x] [Review][Defer] Close request misses `get_tree().quit()`, mobile pause and focus-out paths — revisit with a Quit button or mobile target (Story 1.7+) — deferred
- [x] [Review][Defer] Two browser tabs share one IndexedDB and last writer wins; unbounded `run_history`; storage-unavailable (private window / quota) is only logged — Story 1.7 browser evidence / Epic 5 — deferred
- [x] [Review][Defer] Windows/web `rename_absolute` over an existing file may fail, which makes every later save a non-atomic direct write — already tracked in deferred-work.md for Story 1.7 to measure — deferred

## Dev Notes

### Scope boundaries (what this story is NOT)

- **No `PlayerData`.** `player_data.gd` stays a stub. Mutation methods (`add_brains`, `set_setting`), change signals and the reload-proof counter are Story 1.7. Nothing in this story calls `request_save()` in game code yet; only the tests do. (So in a normal run the file is written only on window close or tab hide.)
- **No web persistence test.** The 10-reload / 10-tab-close check (NFR4), "is `rename` reliable on the web file system" and the deferred Firefox checks all belong to Story 1.7. This story builds the code so 1.7 can measure it. A quick web smoke (export, load, no `[ERROR]` in the console) is welcome but not required.
- **No FR27 notice** (1.7), **no debug overlay, F8 reset or Ctrl+Shift+E** (1.8). `export_json()` and `last_write_ticks_msec` exist now so 1.8 only wires them up. Don't add a `reset()` yet; 1.8 decides its shape.
- **No run-history cap or best-WPM logic.** `PlayerData.record_run()` owns the 500 cap (Story 2.8). `SaveService` stores whatever it is given.
- **No schema v2.** `level_unlocks` and `migrate_1_to_2` are Story 6.8. Only the framework and its test seam land here. `GameConstants.CURRENT_SCHEMA` stays `1`.

### Current state of files being modified

- **`scripts/autoloads/save_service.gd`**: a 2-line stub (`extends Node` + one `##` line). Replace it. Registered 2nd: `SaveService="*res://scripts/autoloads/save_service.gd"`. Keep the order and no `class_name`. `tests/unit/test_project_settings.gd` already asserts the order and that it is an enabled singleton; it must still pass.
- **`scripts/core/game_constants.gd`**: already has `CURRENT_SCHEMA: int = 1` and `RUN_HISTORY_CAP: int = 500`. No change needed. (End-reason constants are added by Epic 2, not here.)
- **`scripts/autoloads/web_platform.gd`**: emits `visibility_hidden` (web only; desktop never emits). No change. Its `offer_download()` will receive `export_json()` bytes in 1.8.
- **`tests/fixtures/saves/`**: contains only `.gitkeep`.
- **`project.godot`, `export_presets.cfg`, `.github/workflows/build.yml`**: no change. Fixtures under `tests/` are already export-excluded.

### v1 shape (architecture → Data Persistence; FR51)

```json
{
  "schema_version": 1,
  "active_profile": "p1",
  "profiles": {
    "p1": {
      "name": "",
      "brains": 0,
      "owned_items": [],
      "equipped": { "hat": "", "pet": "" },
      "flags": { "welcome_bonus_claimed": false, "tutorial_seen": false, "placement_done": false },
      "tier": 0,
      "settings": { "music_on": true, "sound_on": true },
      "best_wpm": { "zombie_run": 0 },
      "run_history": []
    }
  }
}
```

- An empty string in `equipped` means "slot empty" (FR43: either slot can be empty).
- **Run record** (written by `PlayerData.record_run()` in 2.8, used here only in the full fixture): `{ "timestamp", "level_id", "duration_s", "keys_typed", "errors", "wpm", "accuracy", "brains", "letter_pool_or_tier", "per_key": { "f": [attempts, errors, { "g": 2, "d": 1 }] }, "end_reason" }`. `end_reason` is `"timer"`, `"caught"` or `"escaped"`; quit runs are never recorded. Use whole numbers (`timestamp` as Unix seconds, e.g. `1790000000`; `letter_pool_or_tier` as a string such as `"all"`).
- IDs are stored as plain strings (`"hat_pumpkin"`, `"zombie_run"`), never Resource paths (architecture Data Patterns). Looking up a `String` key with a `StringName` works in 4.7.2 (`{"zombie_run": 1}.get(&"zombie_run")` → `1`, verified), so `PlayerData` can use `&"..."` ids.

### Engine facts (verified on the local Godot 4.7.2 on 2026-10-03)

- `JSON.parse` returns every number as **`float`** (`typeof` = `TYPE_FLOAT` for `120`). `JSON.stringify` writes floats as `120.0` and ints as `120`. Without `normalize_numbers`, a round-trip would turn `"brains": 120` into `"brains": 120.0` and `int`-typed code in `PlayerData` would get floats. `fill_defaults`' type check would also wrongly see `float` ≠ `int` and reset every number: **normalize before filling**.
- `JSON.stringify(data, "\t")` sorts keys by default (`sort_keys = true`), so output is deterministic. A `StringName` value is written as a plain string.
- `DirAccess.rename_absolute(from, to)` with `to` already existing returns `OK` and replaces it on Windows (verified). `DirAccess.copy_absolute(from, to)` returns `OK`. Both accept `user://` paths.
- `FileAccess.store_string()` returns `bool` in 4.7. Check it **and** `file.get_error()`; close the file before renaming.
- Godot web: `user://` is a virtual file system that Godot syncs to IndexedDB after a file opened for writing is closed; the sync is asynchronous and runs from the engine's main loop. A hidden tab stops `requestAnimationFrame`, so a write made inside the `visibility_hidden` handler may not reach IndexedDB if the tab is then closed. Writes made while the tab is visible (every `request_save()` from 1.7 on) sync within a frame or so. **This is a known risk for Story 1.7's tab-close test, not something to solve here.** If 1.7 loses data, the fix belongs in `WebPlatform` (Boundary 3). Record nothing about it as verified in this story.

### Architecture's `_read_json` (copy this shape)

```gdscript
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error(&"save", "open failed %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		Log.warn(&"save", "parse failed %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data
```

Add: an empty dictionary also counts as "not a save" (the architecture's `load_save()` uses `data.is_empty()` to decide the fallback). `untyped_declaration = Error` is on: every `var` needs a type or an obvious `:=`. `json.data` is a `Variant`; assign it to a typed `Dictionary` explicitly.

### Write algorithm

```gdscript
func save_now() -> Error:
	var text: String = _serialize()
	var main: String = save_dir.path_join(SAVE_FILE)
	var tmp: String = save_dir.path_join(TMP_FILE)
	var bak: String = save_dir.path_join(BACKUP_FILE)
	var err: Error = _write_text(tmp, text)              # opens, store_string, checks, closes
	if err != OK:
		Log.error(&"save", "write failed %s: %s" % [tmp, error_string(err)])
		_dirty = true
		return err
	if _main_valid and FileAccess.file_exists(main):
		var copy_err: Error = DirAccess.copy_absolute(main, bak)
		if copy_err != OK:
			Log.warn(&"save", "backup copy failed: %s" % error_string(copy_err))
	err = DirAccess.rename_absolute(tmp, main)
	if err != OK:
		Log.warn(&"save", "rename failed (%s), writing save.json directly" % error_string(err))
		err = _write_text(main, text)
		DirAccess.remove_absolute(tmp)
		if err != OK:
			Log.error(&"save", "direct write failed: %s" % error_string(err))
			_dirty = true
			return err
	_dirty = false
	_main_valid = true
	last_write_ticks_msec = Time.get_ticks_msec()
	Log.info(&"save", "written (%d bytes)" % text.length())
	save_written.emit()
	return OK
```

- **Copy, not rename, for the backup.** Renaming `save.json` → `save.bak` first would leave a moment with no `save.json`; copying keeps `save.json` present at every step. The architecture's wording ("keeping the previous file as save.bak") is met either way.
- After a successful write, no `save.tmp` is left behind (test it).
- The `_dirty = false` line sits at the end so a failed write stays dirty.

### Architecture compliance

- **Boundary 3 / consistency rule "Save writes":** only `SaveService` uses `FileAccess`/`DirAccess` in `scripts/`. `SaveSchema` never touches files.
- **Boundary 1:** `scripts/core/save_schema.gd` is pure: static functions, no autoloads, no nodes. It must have `tests/unit/test_save_schema.gd` (rule: every class in `scripts/core/` has a test).
- **Autoload rules:** 2nd in order; uses only `WebPlatform` in `_ready()`; no `class_name`; typed past-tense signal (`save_written`); handler named `_on_<emitter>_<signal>` (`_on_web_platform_visibility_hidden`); connected with a Callable in `_ready()`, disconnected in `_exit_tree()`.
- **Error handling (architecture table):** IO open failure → `Log.error` + fallback; parse failure → `Log.warn` + fallback; never `assert` on runtime conditions (asserts are stripped from release); errors never pause the game and never show text to the player (EXPERIENCE.md: "Save write fails → silent").
- **Logging:** tag `&"save"`. `info` for loaded-from and written; `warn` for fallbacks and bad types; `error` for IO failures. Never the contents, never in `_process` (there is no `_process`).
- **Static typing everywhere** (`untyped_declaration = Error`). `Array[Callable]` for the migration steps.
- **Config:** file names are local `const`s in `SaveService`; `CURRENT_SCHEMA` and `RUN_HISTORY_CAP` come from `GameConstants`. No gameplay numbers here.
- **NFR12 (privacy):** the save holds no personal data in the MVP (`name` is `""` until Epic 11); still, never log it.

### File structure requirements

New:
```
scripts/core/save_schema.gd (+ .uid)
tests/unit/test_save_schema.gd (+ .uid)
tests/unit/test_save_service.gd (+ .uid)
tests/fixtures/saves/save_v1_fresh.json
tests/fixtures/saves/save_v1_full.json
tests/fixtures/saves/save_corrupt.json
```
Modified: `scripts/autoloads/save_service.gd` (stub replaced), `_bmad-output/implementation-artifacts/sprint-status.yaml`, `deferred-work.md` (if anything is deferred), this story file. Deleted: `tests/fixtures/saves/.gitkeep`. Not touched: `player_data.gd`, `project.godot`, `game_constants.gd`.

### Testing requirements

GUT 9.7.1 facts (from 1.1–1.5):
- An unexpected `push_error` **fails** the test; every test that triggers `Log.error()` must `assert_push_error("...")`. `push_warning` doesn't fail, but assert the ones you expect with `assert_push_warning("...")` so silent fallbacks are proven, not assumed.
- **Never test through the live autoload.** `const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")`, then `var sut: Node = SaveServiceScript.new()`, **set `sut.save_dir = TEST_DIR` before `add_child_autofree(sut)`** (its `_ready()` loads). Forgetting this would read, and on write overwrite, the real `user://save.json`.
- `TEST_DIR = "user://test_save_service/"`. `before_each`: create it and delete every file in it; `after_each`: delete the files again. Write a small helper `_put(file_name, text)` that writes fixture text into `TEST_DIR` (tests may use `FileAccess`).
- **Never emit the live `WebPlatform.visibility_hidden`** in a test: the live `SaveService` autoload is connected to it and would write the real save. Call `sut._on_web_platform_visibility_hidden()` directly and, separately, assert `WebPlatform.visibility_hidden.is_connected(sut._on_web_platform_visibility_hidden)`. Same for close: call `sut._notification(NOTIFICATION_WM_CLOSE_REQUEST)` directly.
- Frame waits: `await wait_process_frames(2)` (GUT 9.7 has `wait_frames`, `wait_process_frames`, `wait_physics_frames`; the keyboard-test tests use `wait_frames(2)`). Count writes with `watch_signals(sut)` + `assert_signal_emit_count(sut, "save_written", 1)`.
- Parse errors are silent: grep the GUT output for `Parse Error|Failed to load script|SCRIPT ERROR`. Run `--import` after adding the new `class_name`.
- Godot: `"/c/Program Files/Godot/Godot.exe"` (4.7.2 standard). GUT: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- GUT quits with `-gexit` (no `NOTIFICATION_WM_CLOSE_REQUEST`), so the live `SaveService` writes nothing during a test run. Don't change that.

`tests/unit/test_save_schema.gd` (pure, no files except reading fixtures):
- `test_defaults_match_v1_fixture` (AC 1): `SaveSchema.defaults()` deep-equals the parsed + `normalize_numbers`'d `save_v1_fresh.json`. Also `JSON.stringify(SaveSchema.defaults(), "\t")` equals the fixture text (trim a trailing newline if the file has one).
- `test_defaults_returns_fresh_copies`: mutate one `defaults()` result (`profiles.p1.brains = 5`, append to `owned_items`); a second call is untouched.
- `test_normalize_numbers_turns_integral_floats_into_ints`: nested dict/array; `120.0` → `int 120`, `2.5` stays `float`, strings/bools untouched.
- `test_fill_adds_missing_fields` (AC 3): remove `flags.tutorial_seen`, `settings`, `best_wpm.zombie_run` and the root `active_profile`; after fill they are back with default values.
- `test_fill_keeps_unknown_fields` (AC 3): the full fixture's `x_future_root` and `x_future_profile` survive, and so does an extra `best_wpm` key (`"horde_rush": 9`).
- `test_fill_replaces_wrong_types_with_defaults`: `brains: "lots"`, `flags: []` → defaults, with `assert_push_warning`.
- `test_fill_fills_every_profile`: a second profile `p2` missing most fields gets profile defaults.
- `test_fill_repairs_profiles_and_active_profile`: empty `profiles` → `p1` added; `active_profile: "zz"` → `"p1"` with a warning.
- `test_migrate_runs_steps_in_order` (AC 4): with fake steps `[step_a, step_b]` (each appends its name to a `"trace"` array and checks the incoming `schema_version`), `migrate(v1_data, steps, 3)` → `trace == ["a", "b"]`, `schema_version == 3`.
- `test_migrate_noop_at_current`: a v1 save with the real defaults is returned unchanged.
- `test_migrate_starts_mid_chain`: a `schema_version: 2` save with `target 3` runs only step index 1.
- `test_migrate_missing_step_logs_error`: `steps = []`, `target 2` → `assert_push_error`, data returned, no crash.
- `test_migrate_future_version_left_alone`: `schema_version: 9` → unchanged, `assert_push_warning`.
- `test_prepare_round_trips_full_fixture`: `prepare(parse(full))` then `JSON.stringify(…, "\t")` → parse again → deep-equal (numbers stay ints: e.g. `typeof(brains) == TYPE_INT`).

`tests/unit/test_save_service.gd` (fresh instance in `TEST_DIR`):
- `test_fresh_start_uses_defaults_and_writes_nothing`: empty folder → `get_data()` equals `SaveSchema.defaults()`; no file exists in `TEST_DIR` after `_ready()`.
- `test_write_creates_save_json_and_no_tmp` (AC 2): `save_now()` → `OK`, `save.json` exists, `save.tmp` doesn't, its text equals `export_json()`.
- `test_second_write_keeps_previous_as_bak` (AC 2): write; change `get_active_profile()["brains"] = 7`; write → `save.bak` text equals the first write's text, `save.json` has `7`.
- `test_round_trip_full_fixture` (AC 7): put `save_v1_full.json` as `save.json`; new instance loads it; `get_data()` deep-equals the prepared fixture, including the unknown fields; `save_now()` and reload → still equal.
- `test_corrupt_main_falls_back_to_bak` (AC 2): `save.json` = corrupt fixture, `save.bak` = full fixture → full data loaded; `assert_push_warning`.
- `test_both_corrupt_uses_defaults` (AC 2): both corrupt → defaults; warnings asserted; no `push_error` (a corrupt file is not an error).
- `test_corrupt_main_is_not_rotated_into_bak` (Task 3.9): corrupt main + good bak → `save_now()` → `save.bak` still the good fixture text, `save.json` now valid.
- `test_missing_fields_filled_on_load` / `test_unknown_fields_kept_on_load` (AC 3): through the file path, not just `SaveSchema` (one test each, short).
- `test_request_save_coalesces_same_frame` (AC 5): `watch_signals`; `request_save()` ×3; assert `save_written` count is 0 right away; `await wait_process_frames(2)`; count is 1. Then one more `request_save()` + wait → count 2.
- `test_save_now_writes_immediately` (AC 5): `save_now()` → `save_written` emitted once without waiting a frame.
- `test_visibility_hidden_writes_immediately` (AC 5): call `sut._on_web_platform_visibility_hidden()` → `save.json` exists without waiting. Plus `test_connected_to_visibility_hidden`.
- `test_close_request_writes_immediately` (AC 5): `sut._notification(NOTIFICATION_WM_CLOSE_REQUEST)` → written.
- `test_export_json_matches_file_and_touches_nothing` (AC 6): in an empty folder, `export_json()` → no files appear; it parses back to `get_data()`; after `save_now()`, the file text equals `export_json()` exactly.
- `test_disconnects_on_exit`: after `remove_child` + `free`, `WebPlatform.visibility_hidden` is no longer connected to it.

### Previous story intelligence (1.1–1.5)

- **Test pattern for autoloads** (1.3 Router, 1.4 AudioManager, 1.5 WebPlatform): fresh instance from the preloaded script, `add_child_autofree`, private handlers called directly as seams (`_on_blur`, `_emit_if_hidden`); the live autoload is only read, never driven. Do the same here.
- **`untyped_declaration = Error`**: every declaration typed; `for key: String in dict.keys()` style typed loops; `Array[Callable]`, `Dictionary` (untyped dictionaries are fine for the save; JSON is untyped by nature).
- `--import` must run after adding scripts or a new `class_name`, or GUT can't resolve `SaveSchema`. It also regenerates `.import` files under `build/` (harmless; gitignored). `_bmad-output/.gdignore` already exists (1.5).
- **1.5 deferrals that land on 1.7, not here:** Firefox per-key table, Esc-in-fullscreen, persistence values in normal and private windows. `WebPlatform` fires both `focus_lost` and `visibility_hidden` on one tab switch; `SaveService` listens only to `visibility_hidden`, so one tab switch = one write.
- **1.5 deferral for 1.8:** desktop `offer_download()` ignores the bytes. Not this story, but `export_json()` is what 1.8 will pass to it.
- The live autoload `WebPlatform.capture_keys` guard in `test_web_platform.gd` shows the house style for "nothing in the suite may leave live state changed". Here the equivalent is: no test writes outside `TEST_DIR`.
- Placeholder screens and the Router are untouched by this story.

### Git intelligence

- Recent commits: `803a575` Story 1.5 (WebPlatform, keyboard test), `580aba1` Story 1.4 (AudioManager), `ab8585a` Story 1.3 (Router, title, placeholders), `b3166e8`/`64cb50f` Story 1.2 (CI, Pages), `9450abe` Story 1.1. Working tree was clean at story creation.
- Commit style: `Story 1.N: <summary>`, wrapped bullet body, `Co-Authored-By` trailer. Commit only when Smuck asks.
- Test count at HEAD: 98 GUT tests passing (1.5 record).

### Latest tech information (checked 2026-10-03)

- Godot 4.7.2-stable (official) is the installed engine (verified with `Engine.get_version_info()`). `JSON`, `FileAccess`, `DirAccess.rename_absolute/copy_absolute/remove_absolute/make_dir_recursive_absolute`, `Object.call_deferred` and `NOTIFICATION_WM_CLOSE_REQUEST` are stable 4.x APIs; nothing deprecated is needed.
- `NOTIFICATION_WM_CLOSE_REQUEST` reaches every node in the tree (autoloads included) on desktop when the window's close button is pressed; with the default `auto_accept_quit = true` the app quits right after the notification returns, so the write must be synchronous (it is). The web export doesn't get this notification for a tab close; `visibility_hidden` covers that case.
- GUT 9.7.1: `assert_push_warning(text)`, `assert_push_error(text)`, `assert_push_warning_count`, `wait_process_frames`, `assert_signal_emit_count` are available (checked in `addons/gut/test.gd`).

### Project Structure Notes

- Matches the architecture exactly: `scripts/autoloads/save_service.gd`, `scripts/core/save_schema.gd` (`class_name SaveSchema`, "defaults, migrations"), fixtures in `tests/fixtures/saves/` with the three architecture-named files.
- **Variance (small, additive):** `SaveService.save_dir` (test seam), `save_written` signal and `last_write_ticks_msec` (for the 1.8 overlay), `get_data()`/`get_active_profile()` (the hand-off to `PlayerData` in 1.7) are not named in the architecture. They don't change any documented behaviour.
- **Variance:** the backup is made by **copy** rather than rename, so `save.json` always exists (rationale above).

### Project Context Rules

- There is no `project-context.md`. The rules come from the architecture (Data Persistence, Error Handling, Logging, Boundaries, Consistency Rules, Naming) and Stories 1.1–1.5: strict static typing, `Log` for all logging, tests first for logic, standard Godot build only, the GUT parse-error grep, fresh instances instead of live autoloads in tests.
- Tools: Godot MCP (`run_project`, `get_debug_output`, `stop_project`) for the desktop run; the Godot binary at `/c/Program Files/Godot/Godot.exe` for `--import` and GUT.

### Open Questions for Smuck (none block starting)

1. **Write the defaults on first boot?** Plan: no. A fresh game writes `save.json` on the first real change (from 1.7 on) or when the window closes / tab hides. Say if you'd rather have the file appear immediately.
2. ~~Keep a copy of a corrupt save?~~ **Decided by Smuck (2026-10-03): no.** Hobby project, no forensic debugging. If both files are corrupt, the game starts fresh and the next write overwrites the corrupt `save.json`. Do **not** add a `save.corrupt.json` (or any other extra copy).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.6: Versioned Save File]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements → Data] (ADR-2/3, atomic write, coalescing, only SaveService touches files)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.7, #Story 1.8, #Story 2.8] (later users: PlayerData, export, run history)
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27-b.md] (schema v2 `level_unlocks` and `migrate_1_to_2` in Story 6.8, which uses this framework)
- [Source: _bmad-output/game-architecture.md#Data Persistence, #Error Handling, #Logging, #Architectural Boundaries, #Consistency Rules, #Data Patterns, #Directory Structure]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] (save contents, save integrity, saves stored per browser)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] ("Save write fails → silent")
- [Source: _bmad-output/implementation-artifacts/1-5-web-platform-service-and-keyboard-capture-test.md] (WebPlatform signals, test patterns, deferrals)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (1.5 deferrals that land on 1.7/1.8)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Red phase: `test_save_schema.gd` failed with `Identifier "SaveSchema" not declared`; `test_save_service.gd` failed with `Invalid assignment of property 'save_dir'` on the stub. Both green after implementation.
- GUT final: 131/131 passing (98 existing + 15 `test_save_schema` + 18 `test_save_service`), exit 0, zero `Parse Error` / `Failed to load script` / `SCRIPT ERROR` lines. The single "Deprecated" line is pre-existing (`wait_frames` in `test_keyboard_test.gd`, Story 1.5).
- Desktop run 1 (no save present): boot logged `[INFO][save] no valid save, starting fresh`, no errors. Window closed with a real WM_CLOSE (`Process.CloseMainWindow()`, not `stop_project`, which kills the process) → `save.json` (443 bytes, v1 defaults).
- Desktop run 2: boot logged `[INFO][save] loaded save.json`; close → `save.bak` created, byte-identical to the previous `save.json`.
- Hand-corrupt check (4.4): `save.json` replaced with truncated JSON, good `save.bak` kept → boot logged `[WARN][save] parse failed user://save.json …` and `[WARN][save] save.json unreadable, using save.bak`; game ran normally; on close `save.json` was rewritten (443 bytes) and `save.bak` was not overwritten with the garbage.
- Boundary check: `grep -rl "FileAccess\|DirAccess" scripts/` → only `scripts/autoloads/save_service.gd`.
- Before the desktop runs, `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/` had no `save.json`, confirming the GUT run never touched the real save.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `SaveSchema` (`scripts/core/save_schema.gd`, pure static): `profile_defaults()`/`defaults()` build new dictionaries every call; `normalize_numbers()` turns integral floats into ints in place; `fill_defaults()` deep-merges against the defaults for the root and **every** profile, keeps unknown keys, replaces wrong-typed fields with a `bad type at <path>` warning, adds `p1` to an empty `profiles` and repairs a dangling `active_profile` (p1, else first sorted id); `migration_steps()` is `[]`; `migrate()` takes `steps`/`target` as the test seam, treats a missing/bad version as 1, logs an error and stops on a missing step, leaves newer saves alone; `prepare()` = normalize → migrate → fill.
- `SaveService` (stub replaced): load order save.json → save.bak → defaults, all fallbacks logged as warnings (plain `info` when no file existed at all); `_read_json` treats parse failure, non-Dictionary and empty Dictionary as "not a save". Write order tmp → copy good main to bak → rename (direct-write fallback). Backup only when `_main_valid`. `request_save()` coalesces via `call_deferred`; `save_now()` on window close and `visibility_hidden` (writes even when not dirty). `export_json()` and the file share `_serialize()`. Added `save_written`, `last_write_ticks_msec`, `save_dir` seam, `_ensure_dir()`.
- Decision: the "using save.bak" warning names why (`save.json unreadable` vs `missing`) and is only logged when the backup actually loaded, so a normal fresh start logs a single `info` line and no warnings.
- Decision: `save_v1_full.json` is written in canonical form (sorted keys, tabs), so `test_prepare_round_trips_full_fixture` also checks `JSON.stringify(prepare(full))` equals the fixture text byte-for-byte.
- Open question 1 kept as planned: no write on first boot; the file first appears on window close / tab hide (or on `request_save()` from Story 1.7 on).
- Smuck: the desktop check left a defaults-only `save.json` and `save.bak` in `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/` (also an empty `test_save_service/` folder from GUT). Harmless; not deleted pending your OK.
- Deferred to `deferred-work.md`: web IndexedDB sync after a `visibility_hidden` write and `rename` reliability on web (Story 1.7 measures them), untested IO-failure branches, routing 1.8's desktop export file write through `SaveService`, the pre-existing `wait_frames` deprecation.

### File List

- `scripts/core/save_schema.gd` (new)
- `scripts/core/save_schema.gd.uid` (new)
- `scripts/autoloads/save_service.gd` (modified: stub replaced)
- `tests/unit/test_save_schema.gd` (new)
- `tests/unit/test_save_schema.gd.uid` (new)
- `tests/unit/test_save_service.gd` (new)
- `tests/unit/test_save_service.gd.uid` (new)
- `tests/fixtures/saves/save_v1_fresh.json` (new)
- `tests/fixtures/saves/save_v1_full.json` (new)
- `tests/fixtures/saves/save_corrupt.json` (new)
- `tests/fixtures/saves/.gitkeep` (deleted)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/1-6-versioned-save-file.md` (this file)

### Change Log

- 2026-10-03: Story 1.6 created (ready-for-dev).
- 2026-10-03: Smuck decided: no `save.corrupt.json` copy.
- 2026-10-03: Implemented `SaveSchema` and `SaveService` with fixtures and 33 new GUT tests (131/131 passing); desktop save/backup/corrupt-fallback verified; status → review.
- 2026-10-03: Code review: 8 patches applied (dirty-guarded hide/close writes, read-only newer-schema saves, tmp cleanup, bytes log, migration/overflow guards, test fix), 5 tests added (136/136 passing); 8 items deferred; status → done.
