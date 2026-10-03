---
baseline_commit: 2f37adf31ec03769e5b5dc359d9efae60edcd6a7
---

# Story 1.1: Project Settings, Folder Skeleton and Test Harness

Status: done

## Story

As the developer,
I want the existing Godot project configured for 640×360 pixel art with the agreed folder structure, core helpers and a working GUT test run,
so that every later story starts from correct settings and can be unit-tested.

## Acceptance Criteria

1. **Project settings.** Given the existing `project.godot`, when the story is complete, then the viewport is 640×360, stretch mode `viewport`, aspect `keep`, scale mode `fractional`, default canvas texture filter Nearest and `snap_2d_transforms_to_pixel = true`; and the `[dotnet]` section is removed and `debug/gdscript/warnings/untyped_declaration` is set to Error.
2. **Folder skeleton.** Given the architecture's Project Structure, when the folders are created, then `scenes/`, `scripts/`, `data/`, `assets/`, `tests/unit/`, `tests/integration/`, `tests/fixtures/saves/` and `tools/` exist with the mirrored feature sub-folders needed so far; and `build/` is listed in `.gitignore`.
3. **Log and GameConstants.** Given `scripts/core/log.gd` (`class_name Log`) and `scripts/core/game_constants.gd` (`class_name GameConstants`), when `Log.debug()` is called in a release build, then nothing is printed, while `error`/`warn`/`info` print in the `[LEVEL][tag] message` format; and `GameConstants` holds `LOGICAL_SIZE`, `RUN_HISTORY_CAP = 500` and `CURRENT_SCHEMA = 1`.
4. **GUT harness.** Given GUT 9.7.1 is installed in `addons/gut/`, when `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` runs, then a smoke test and a `Log` unit test pass and the command exits with code 0; and a deliberately failing test makes the command exit non-zero.

## Tasks / Subtasks

- [x] **Task 1 — Fix `project.godot`** (AC: 1)
  - [x] 1.1 Add under `[display]`: `window/size/viewport_width=640`, `window/size/viewport_height=360`; change `window/stretch/mode` to `"viewport"` and `window/stretch/aspect` to `"keep"`; set `window/stretch/scale_mode="fractional"` (see note on defaults below).
  - [x] 1.2 Add under `[rendering]`: `textures/canvas_textures/default_texture_filter=0` (0 = Nearest) and `2d/snap/snap_2d_transforms_to_pixel=true`. Keep `renderer/rendering_method="gl_compatibility"` and `rendering_method.mobile`.
  - [x] 1.3 Add a `[debug]` section with `gdscript/warnings/untyped_declaration=2` (2 = Error). Do **not** touch `gdscript/warnings/exclude_addons` (default `true` — it must stay true so GUT's own scripts are not held to our strict-typing rule).
  - [x] 1.4 Delete the whole `[dotnet]` section (`project/assembly_name`).
  - [x] 1.5 Leave `config/features`, `config/icon`, `config/name` as-is. `[physics] 3d/physics_engine` and `rendering_device/driver.windows` are irrelevant (no 3D, Compatibility renderer) — leave them; removing them is optional, not required.
  - [x] 1.6 Add `tests/unit/test_project_settings.gd` that asserts the values via `ProjectSettings.get_setting(...)` (viewport 640/360, stretch mode/aspect/scale_mode, texture filter 0, snap true, untyped_declaration 2) and that `ProjectSettings.has_setting("dotnet/project/assembly_name")` is false. This guards against the editor silently reverting them (see the .NET-editor risk in Dev Notes).
- [x] **Task 2 — Folder skeleton** (AC: 2)
  - [x] 2.1 Create the top-level type folders and the sub-folders needed by Epic 1 (list in Dev Notes → File Structure). Put an empty `.gitkeep` in every folder that has no other file so Git tracks it.
  - [x] 2.2 Append `build/` to `.gitignore` (keep the existing `.godot/`, `/android/` and `.claude/settings.local.json` lines).
- [x] **Task 3 — `Log` static class** (AC: 3)
  - [x] 3.1 Create `scripts/core/log.gd` with `class_name Log`, static functions `error`, `warn`, `info`, `debug` (`(tag: StringName, msg: String) -> void`) and `static var verbose_typing: bool = false`, exactly as in the architecture (Logging section).
  - [x] 3.2 Add a testable seam (no print capture exists in GUT): `static func format_line(level: String, tag: StringName, msg: String) -> String` returning `"[%s][%s] %s" % [level, tag, msg]`, used by all four functions; `static var debug_enabled: bool = OS.is_debug_build()`; and `static func is_level_enabled(level: String) -> bool` (false only for `"DEBUG"` when `debug_enabled` is false) that `debug()` checks instead of calling `OS.is_debug_build()` inline. Tests flip `debug_enabled` to simulate a release build and restore it in `after_each`.
  - [x] 3.3 `error` → `push_error(line)`, `warn` → `push_warning(line)`, `info` → `print(line)`, `debug` → `print(line)` only if `debug_enabled`.
- [x] **Task 4 — `GameConstants`** (AC: 3)
  - [x] 4.1 Create `scripts/core/game_constants.gd`: `class_name GameConstants`, `const LOGICAL_SIZE: Vector2i = Vector2i(640, 360)`, `const RUN_HISTORY_CAP: int = 500`, `const CURRENT_SCHEMA: int = 1`. Nothing else yet (`IGNORED_KEYCODES` belongs to Story 2.1, end reasons to Epic 2).
- [x] **Task 5 — Install GUT 9.7.1** (AC: 4)
  - [x] 5.1 Download the **v9.7.1** release from https://github.com/bitwes/Gut/releases (tag `v9.7.1`), copy only its `addons/gut/` folder to `res://addons/gut/`. Commit it (CI in Story 1.2 needs it in the repo).
  - [x] 5.2 Enable the plugin in `project.godot` (`[editor_plugins] enabled=PackedStringArray("res://addons/gut/plugin.cfg")`) so the GUT panel is available in the editor. Not needed for CLI runs, but expected for editor use.
  - [x] 5.3 Add `res://.gutconfig.json`: `{ "dirs": ["res://tests/"], "include_subdirs": true, "prefix": "test_", "suffix": ".gd", "should_exit": true, "log_level": 1 }`. **Why:** the AC command passes `-gdir=res://tests` **without** `-ginclude_subdirs`; without `include_subdirs: true` GUT would find zero tests in `tests/unit/`. GUT loads `res://.gutconfig.json` automatically.
  - [x] 5.4 Run a headless import once before the first test run so `class_name` globals (`GutTest`, `Log`, `GameConstants`) are registered: `godot --headless --path . --import`.
- [x] **Task 6 — Tests** (AC: 3, 4)
  - [x] 6.1 `tests/unit/test_smoke.gd`: `extends GutTest`, one test asserting `true` and one asserting `GameConstants.LOGICAL_SIZE == Vector2i(640, 360)`, `RUN_HISTORY_CAP == 500`, `CURRENT_SCHEMA == 1`.
  - [x] 6.2 `tests/unit/test_log.gd`: format_line output (`[INFO][save] hello`); `debug_enabled = false` → `is_level_enabled("DEBUG")` is false and `"ERROR"`/`"WARN"`/`"INFO"` stay true; `Log.error(...)` is caught with `assert_push_error("[ERROR][test]")`; `Log.warn(...)` with `assert_push_warning("[WARN][test]")`.
  - [x] 6.3 `tests/unit/test_project_settings.gd` (Task 1.6).
  - [x] 6.4 Run the AC command; record the exit code (expect 0) and the GUT summary in the Dev Agent Record.
  - [x] 6.5 Temporarily add `tests/unit/test_deliberate_failure.gd` with `assert_true(false)`, run the AC command, record the non-zero exit code, then **delete the file** (it must not be committed — CI in Story 1.2 would fail forever).
- [x] **Task 7 — Verify nothing regressed**
  - [x] 7.1 Open the project in the editor (or `--headless --quit`) with no new errors in the output; re-check `project.godot` afterwards that `[dotnet]` did not come back.
  - [x] 7.2 `git status` shows only intended files (no `.godot/`, no `build/`).

### Review Findings

- [x] [Review][Patch] Add `window_width_override=1280` / `window_height_override=720` under `[display]` so the desktop window is usable (decision: option 1) [project.godot:[display]]
- [x] [Review][Patch] Nothing ties `GameConstants.LOGICAL_SIZE` to the project viewport settings — add one test asserting it equals `display/window/size/viewport_width/height` so the two can't drift [tests/unit/test_project_settings.gd]
- [x] [Review][Defer] `test_debug_disabled_in_release` asserts no print output; only the `is_level_enabled` seam is checked (GUT cannot capture print; spec accepts) [tests/unit/test_log.gd:test_debug_disabled_in_release] — deferred, pre-existing
- [x] [Review][Defer] `Log.verbose_typing` declared but not consumed yet; wire it up in the typing story [scripts/core/log.gd:verbose_typing] — deferred, pre-existing
- [x] [Review][Defer] `directory_rules={"res://addons": 0}` is not persisted in `project.godot`; test passes on the 4.7 default (16/16 green), but an explicit entry would harden it [project.godot, tests/unit/test_project_settings.gd] — deferred, pre-existing
- [x] [Review][Defer] `Log.debug` builds its `msg` argument even when DEBUG is off — keep out of hot paths [scripts/core/log.gd:debug] — deferred, pre-existing
- [x] [Review][Defer] GUT editor plugin enabled in `project.godot`; make sure the web export excludes `addons/gut` (Story 1.2) [project.godot:[editor_plugins]] — deferred, pre-existing

## Dev Notes

### Scope boundaries (what this story is NOT)

- No autoloads, no scenes, no export presets, no CI workflow (Stories 1.2 and 1.3). The architecture's "First Steps" lists those together; this story only covers settings, folders, `Log`, `GameConstants`, GUT.
- No custom boot splash / letterbox color (`#2B1D3F`) — that belongs to Story 5.0 (sprint-change-proposal-2026-09-27-b, Proposal 5).
- No pixel font or `ui_theme.tres` — Story 1.3.
- No `save_schema.gd` — Story 1.6 (folder `scripts/core/` exists already).

### Current state of files being modified

**`project.godot` (today):**
```
config_version=5
[application] config/name="ZombiesTeachTyping", config/features=PackedStringArray("4.7", "GL Compatibility"), config/icon="res://icon.svg"
[display] window/stretch/mode="canvas_items", window/stretch/aspect="expand"    ← WRONG, conflicts with pixel-art spec
[dotnet] project/assembly_name="ZombiesTeachTyping"                              ← REMOVE
[physics] 3d/physics_engine="Jolt Physics"                                         ← unused, harmless
[rendering] rendering_device/driver.windows="d3d12", renderer/rendering_method="gl_compatibility", renderer/rendering_method.mobile="gl_compatibility"
```
Must preserve: name, features `"4.7", "GL Compatibility"`, icon, Compatibility renderer settings. Architecture lists these settings as a known technical risk ("Current project.godot stretch settings conflict with the 640×360 pixel-art spec").

**`.gitignore` (today):** `.godot/`, `/android/`, `.claude/settings.local.json` — add `build/`.

**`.editorconfig`** (`charset = utf-8`) and **`.gitattributes`** (`* text=auto eol=lf`) — leave untouched. GDScript uses **tabs** (Godot default).

### Technical requirements and gotchas

- **Default values are not written by Godot.** `scale_mode = "fractional"` is Godot 4's default for `display/window/stretch/scale_mode`, and the editor strips settings that equal their default when it re-saves `project.godot`. If the line disappears after opening the editor, that is correct behaviour, not a regression. That is why AC 1 is verified by `test_project_settings.gd` reading `ProjectSettings`, not by grepping the file.
- **Exact setting keys (Godot 4.7):**
  | Setting | Key | Value |
  |---|---|---|
  | Viewport size | `display/window/size/viewport_width` / `_height` | `640` / `360` |
  | Stretch mode | `display/window/stretch/mode` | `"viewport"` |
  | Aspect | `display/window/stretch/aspect` | `"keep"` |
  | Scale mode | `display/window/stretch/scale_mode` | `"fractional"` |
  | Texture filter | `rendering/textures/canvas_textures/default_texture_filter` | `0` (Nearest) |
  | Pixel snap | `rendering/2d/snap/snap_2d_transforms_to_pixel` | `true` |
  | Strict typing | `debug/gdscript/warnings/untyped_declaration` | `2` (Error) |
  The editor also writes a `window/size/window_width_override` etc. only if you set them — don't; the window size defaults to the viewport size.
- **Why fractional, not integer:** sprint-change-proposal-2026-09-27 (U1) — 1366×768 laptops would otherwise render at 1×. Nearest filtering keeps pixels sharp; slight unevenness is accepted.
- **Strict typing applies to our code only.** With `untyped_declaration = Error`, every `var`, parameter, return type and test method must be typed (`func test_x() -> void:`). Type `for` loop variables too (`for i: int in range(3):`) to be safe. GUT is exempt because `exclude_addons` stays `true`.
- **GUT fails tests on `push_error` by default.** GUT's `failure_error_types` defaults to `["engine", "gut", "push_error"]`. `Log.error()` calls `push_error`, so any test that triggers it must consume the error with `assert_push_error(...)`, or the test fails. Same idea for `push_warning` with `assert_push_warning(...)` (added in GUT 9.6). Keep this in mind for every later story whose tests exercise `Log.error()` (save fallbacks, unknown ids).
- **GUT exit codes:** 0 when all tests pass, 1 when any fail. `-gexit` exits after the run regardless.
- **`Log` is a static class, not an autoload** (pure-logic classes and tests must use it). No `extends` needed (defaults to RefCounted); never instantiate it.
- **Autoload naming rule (for later stories):** autoload scripts have no `class_name`; `Log` and `GameConstants` are not autoloads so they do use `class_name`.

### Godot build to use (verified 2026-10-02)

- **Use the standard build:** `C:\Program Files\Godot\Godot.exe`, which reports `4.7.2.stable.official.ed1daf0bf` (not `mono`). The Godot MCP server (`mcp__godot__get_godot_version`) reports the same build, so MCP runs use it too.
- **Don't use the .NET builds** still on this machine: `C:\Program Files\Godot\Godot_C#.exe` and `C:\Users\smuck\Godot_v4.7.2-stable_mono_win64\`. Opening the project in a .NET editor can add `[dotnet] project/assembly_name` back to `project.godot`. `test_project_settings.gd` and Task 7.1 catch this.
- **The console wrapper only works if the exe keeps its original name.** `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe` launches `Godot_v4.7.2-stable_win64.exe` from its own folder. Since the exe was renamed to `Godot.exe`, the wrapper currently fails with "Main executable … not found". If you need the console wrapper, rename or copy `Godot.exe` back to `Godot_v4.7.2-stable_win64.exe`. Otherwise call `Godot.exe` directly. From Git Bash it was tested to return its exit code (`--headless --version` → exit 0), but always check the GUT exit code with `echo $?` (bash) or `$LASTEXITCODE` (PowerShell).
  ```
  "/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
  ```
- **No export templates are installed yet** (`%APPDATA%\Godot\export_templates\` is empty). This story doesn't need them. Story 1.2 needs the standard 4.7.2 templates for local web export (Editor → Manage Export Templates).
- `.godot/` holds editor cache from the .NET editor (including `.godot/mono/`). It's gitignored and harmless. Deleting `.godot/` before the first headless `--import` gives a clean cache (optional).
- Record which exe was used in the Dev Agent Record.

### Architecture compliance

- Paths, names and class names exactly as in `_bmad-output/game-architecture.md` → Project Structure and Logging.
- `snake_case` files/folders; PascalCase `class_name`; `UPPER_SNAKE_CASE` constants; tabs for indentation.
- Boundary: `scripts/core/` is pure — no autoloads, no scene tree. `Log` may only use `OS.is_debug_build()`, `print`, `push_error`, `push_warning`.
- Never log personal data; never log in `_process` (not relevant yet, but the `Log` doc comment should state it).
- Errors in code use `assert` only for contract violations; not applicable here.

### File structure requirements

Create (✱ = has a real file; others get `.gitkeep`):

```
addons/gut/                         ✱ GUT 9.7.1 (vendored)
assets/                             (sub-folders arrive with Stories 1.3/1.4/1.9)
data/
scenes/
scenes/screens/
scenes/debug/
scripts/
scripts/autoloads/
scripts/core/log.gd                 ✱
scripts/core/game_constants.gd      ✱
scripts/screens/
scripts/resources/
scripts/debug/
tests/unit/test_smoke.gd            ✱
tests/unit/test_log.gd              ✱
tests/unit/test_project_settings.gd ✱
tests/integration/
tests/fixtures/saves/
tools/
.gutconfig.json                     ✱
```

"Mirrored feature sub-folders needed so far" = those Epic 1 uses (`screens`, `debug`, `autoloads`, `core`, `resources`). Do **not** pre-create the Epic 2+ folders (`run/`, `levels/`, `typing/`, `characters/`, `cosmetics/`, `ui/`) — they come with their stories. Don't use `.gdignore` as a placeholder: it makes Godot ignore the folder.

Modify: `project.godot`, `.gitignore`.

### Testing requirements

- Framework: GUT 9.7.1, tests in `tests/unit/` named `test_<unit>.gd`, `extends GutTest`, every test function typed `-> void`.
- `test_log.gd` must cover:
  - `Log.format_line("INFO", &"save", "hello") == "[INFO][save] hello"` (and ERROR/WARN/DEBUG levels).
  - Release simulation: set `Log.debug_enabled = false`, call `Log.debug(...)` (must not error); assert `Log.is_level_enabled("DEBUG")` is false and true for `"ERROR"`, `"WARN"`, `"INFO"`. Restore `debug_enabled` in `after_each`.
  - `Log.error(&"test", "boom")` then `assert_push_error("[ERROR][test] boom")`.
  - `Log.warn(&"test", "careful")` then `assert_push_warning("[WARN][test] careful")`.
- The architecture rule "every class in `scripts/core/` has a `tests/unit/test_*.gd`" starts here: `log.gd` → `test_log.gd`; `game_constants.gd` is covered by `test_smoke.gd` (or a small `test_game_constants.gd` — either is fine).
- Exit-code proof (AC 4) is a manual, recorded check; the failing test file is deleted afterwards.

### Library / framework requirements

- **Godot 4.7.2** stable, Compatibility renderer, GDScript only.
- **GUT 9.7.1** — the release that carries the Godot 4.7 stricter-return-type fixes for doubles (9.7.0 was the breaking change for 4.7; 9.7.1 is the bug-fix follow-up). Don't use 9.6.x (pre-4.7) or GUT's `main` branch.
- No other addons.

### Latest tech information (checked 2026-10-02)

- GUT CLI: `-gdir`, `-ginclude_subdirs`, `-gexit`, `-gexit_on_success`, `-gconfig` (use `-gconfig=` to skip the config file). `res://.gutconfig.json` loads automatically; keys include `dirs`, `include_subdirs`, `prefix`, `suffix`, `should_exit`, `log_level`.
- GUT 9.6.0 added `assert_push_warning`, automatic headless handling; 9.7.0 made doubles return typed defaults for Godot 4.7.

### Project Structure Notes

- Matches the architecture's hybrid layout. `docs/` already exists (empty). `_bmad/`, `_bmad-output/` stay as-is.
- Variance: the AC's GUT command lacks `-ginclude_subdirs`; resolved by `include_subdirs: true` in `.gutconfig.json` (no AC change needed). Story 1.2's CI should use the same command.

### Project Context Rules

- No `project-context.md` exists yet. Rules come from the architecture's Consistency Rules: static typing everywhere, `Log` for all logging (`[LEVEL][tag] message`), no gameplay literals in scripts, no global `randi()`/`randf()`, tests for every `scripts/core/` class.
- MCP: Godot MCP is connected and may be used for running/verifying; Context7 optional.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements → Project setup, Testing]
- [Source: _bmad-output/game-architecture.md#Project Initialization]
- [Source: _bmad-output/game-architecture.md#Logging] and [#Configuration]
- [Source: _bmad-output/game-architecture.md#Directory Structure], [#Naming Conventions], [#Architectural Boundaries], [#Consistency Rules]
- [Source: _bmad-output/game-architecture.md#Testing], [#Development Environment]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27.md — U1 fractional scaling]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27-b.md — Proposal 5, boot splash is Story 5.0]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md — layout: 640×360, viewport/keep, fractional, nearest]
- GUT releases: https://github.com/bitwes/Gut/releases · GUT CLI: https://gut.readthedocs.io/en/latest/Command-Line.html

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Implementation Plan

- Vendored GUT 9.7.1 first (GitHub tag `v9.7.1`, `addons/gut/` only, `plugin.cfg` version 9.7.1) so tests could be written before the code (red → green).
- Red: the three test files with no implementation gave GUT exit 1: the settings tests failed and `Log`/`GameConstants` were undeclared identifiers.
- Green: `project.godot` settings, `Log`, `GameConstants`. All 16 tests pass.
- `Log` seam as specified: `format_line()`, `static var debug_enabled = OS.is_debug_build()`, `is_level_enabled()`. Public API matches the architecture (`error`/`warn`/`info`/`debug`, `verbose_typing`).

### Debug Log References

- Godot build used: `C:\Program Files\Godot\Godot.exe`, `4.7.2.stable.official.ed1daf0bf` (standard, not .NET), called directly from Git Bash (the console wrapper is broken by the rename, see Dev Notes).
- AC 4 command `Godot.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` → **exit 0**, Scripts 3, Tests 16, Passing 16, Asserts 27.
- Deliberate failure (`tests/unit/test_deliberate_failure.gd`, `assert_true(false)`) → **exit 1** (16 passing, 1 failing). File and `.uid` deleted afterwards. Clean rerun → exit 0.
- Strict typing probe (`var x = 1` in a temp test) → `Parse Error: Variable "x" has no static type. (Warning treated as error.)`. Probe deleted.
- `--headless --editor --quit` with the standard build: `project.godot` byte-identical before and after, no `[dotnet]` re-added, no errors. Explicit `scale_mode="fractional"` was not stripped.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- AC 1: `project.godot` has viewport 640×360, `viewport`/`keep`/`fractional`, Nearest canvas filter (0), pixel snap on, `untyped_declaration=2`. `[dotnet]` removed. Guarded by `tests/unit/test_project_settings.gd` (7 tests reading `ProjectSettings`).
- **Deviation (Godot 4.7 API):** `debug/gdscript/warnings/exclude_addons` no longer exists in 4.7. It was replaced by `debug/gdscript/warnings/directory_rules`, default `{"res://addons": 0}` (0 = exclude). The test asserts that instead. Intent unchanged: GUT is exempt from strict typing.
- AC 2: folder skeleton per the story's File Structure list, with `.gitkeep` in empty folders. `build/` added to `.gitignore`.
- AC 3: `Log` prints `[LEVEL][tag] message`. DEBUG is gated by `debug_enabled` (default `OS.is_debug_build()`). `GameConstants` has `LOGICAL_SIZE`, `RUN_HISTORY_CAP = 500`, `CURRENT_SCHEMA = 1`. Covered by `test_log.gd` (7 tests, using `assert_push_error`/`assert_push_warning`) and `test_smoke.gd`.
- AC 4: GUT 9.7.1 installed, plugin enabled, `.gutconfig.json` with `include_subdirs: true`. Exit codes verified as above.
- **⚠ Finding for Story 1.2 (CI):** a test script that fails to **parse** (for example a strict-typing error) is skipped by GUT and the run still **exits 0**. CI must also fail on `Parse Error` / `Failed to load script` lines in the GUT output, or a broken test file passes silently.
- Godot generates `.uid` files for every script. They are committed with their scripts.

### File List

- `project.godot` (modified)
- `.gitignore` (modified)
- `.gutconfig.json` (new)
- `addons/gut/**` (new, vendored GUT 9.7.1)
- `scripts/core/log.gd`, `scripts/core/log.gd.uid` (new)
- `scripts/core/game_constants.gd`, `scripts/core/game_constants.gd.uid` (new)
- `tests/unit/test_smoke.gd`, `tests/unit/test_smoke.gd.uid` (new)
- `tests/unit/test_log.gd`, `tests/unit/test_log.gd.uid` (new)
- `tests/unit/test_project_settings.gd`, `tests/unit/test_project_settings.gd.uid` (new)
- `.gitkeep` (new) in: `assets/`, `data/`, `scenes/screens/`, `scenes/debug/`, `scripts/autoloads/`, `scripts/screens/`, `scripts/resources/`, `scripts/debug/`, `tests/integration/`, `tests/fixtures/saves/`, `tools/`
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/1-1-project-settings-folder-skeleton-and-test-harness.md` (this file)

### Change Log

- 2026-10-02: Story 1.1 implemented: pixel-art project settings, folder skeleton, `Log`, `GameConstants`, GUT 9.7.1 harness with 16 passing tests. Status → review.
