---
baseline_commit: 4d7b1974e40ffa25fd28baa711423ea021733291
---

# Story 2.1: Typing Input Filtering

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want only real typing keys to count, and stray keys like Shift, arrows or held-down repeats to be ignored,
so that I am never marked wrong for something that wasn't a typing mistake.

## Acceptance Criteria

1. **Ignored events emit nothing.** Given `TypingInput` (Node) receives an `InputEventKey`, when the event is a key release, a key-repeat (`echo`), has `unicode == 0` (dead key, IME composition, a modifier on its own), has a control-character `unicode` (< 32 or 127), is pressed while Ctrl, Alt or Meta is held, or its keycode is Shift, Ctrl, Alt, Meta, an arrow, a function key (F1–F35), Tab, Backspace, Enter (main or keypad), Caps Lock or Escape, then no `char_typed` signal is emitted (FR3).
2. **`LevelConfig` Resource.** Given the `LevelConfig` Resource class (new in this story at `scripts/resources/level_config.gd`, starting with `duration_s`, `case_sensitive`, `space_is_input` and `target_mode`; later stories add fields), when it is inspected, then it is a typed custom Resource (`class_name LevelConfig extends Resource`, `@export`ed typed fields) that loads from a `.tres` file as a `LevelConfig`.
3. **Lowercase level.** Given a `LevelConfig` with `case_sensitive = false` and `space_is_input = false`, when `A` (with Shift or with Caps Lock) or `a` is typed, then `char_typed("a")` is emitted; and Space emits nothing (FR4).
4. **Case-sensitive level.** Given a `LevelConfig` with `case_sensitive = true` and `space_is_input = true`, when `A`, `a` and Space are typed, then `char_typed` emits `"A"`, `"a"` and `" "` unchanged.
5. **Matching by character, not key.** Given any configuration, when a key event arrives, then the emitted character comes from the event's `unicode`, never from its `keycode` (e.g. an AZERTY `a` reported as `KEY_Q` with `unicode` 97 emits `"a"`), so other layouts can play (FR4, NFR6).
6. **Caps Lock hint.** Given a lowercase level (`case_sensitive = false`), when 3 capital letters in a row are typed (checked on the raw character before lowercasing), then `caps_lock_suspected` is emitted once; and the next lowercase letter emits `caps_lock_cleared` (FR5). A case-sensitive level never emits either signal.
7. **Tests.** Given `tests/unit/test_typing_input.gd` using synthetic `InputEventKey`s, when GUT runs, then every rule above is covered and passes, and the full suite has no regressions (209 tests passing at `HEAD` `4d7b197`).

## Tasks / Subtasks

- [x] **Task 1: `LevelConfig` Resource (AC: 2)**
  - [x] 1.1 Create `scripts/resources/level_config.gd`: `class_name LevelConfig extends Resource`, a `##` doc comment, `enum TargetMode { LETTER, WORD, PARAGRAPH }`, and exactly these four exported, statically typed fields: `@export var duration_s: float = 0.0`, `@export var case_sensitive: bool = false`, `@export var space_is_input: bool = false`, `@export var target_mode: TargetMode = TargetMode.LETTER`. Doc-comment each field (what it means, which FR). `duration_s` defaults to `0.0` on purpose: the real value (120 for Zombie Run) lives in the level's `.tres`, never as a literal in a script (architecture: Configuration rules). Add no other fields: later stories add their own (`target_spacing_px`, `completion_bonus`, … in Epic 3).
  - [x] 1.2 Create two test fixtures in a new folder `tests/fixtures/levels/`: `level_config_lowercase.tres` (`duration_s = 120.0`, `case_sensitive = false`, `space_is_input = false`, `target_mode = LETTER`) and `level_config_case_sensitive.tres` (`duration_s = 300.0`, `case_sensitive = true`, `space_is_input = true`, `target_mode = PARAGRAPH`). Write them as text `.tres` files with `script_class="LevelConfig"`, an `[ext_resource type="Script" ... path="res://scripts/resources/level_config.gd"]` line and a `[resource]` section (look at `data/audio/audio_library.tres` for the format this project's Godot writes; run `--import` afterwards so Godot fills in or checks UIDs). No real level `.tres` goes in `data/levels/` in this story: Story 2.4 adds the test level's config and Epic 3 adds `zombie_run.tres`.

- [x] **Task 2: `GameConstants.IGNORED_KEYCODES` (AC: 1)**
  - [x] 2.1 In `scripts/core/game_constants.gd`, add `IGNORED_KEYCODES`: the keys the GDD names as never-errors that are not covered by the `unicode` check, as a typed constant, e.g. `const IGNORED_KEYCODES: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_CAPSLOCK, KEY_ESCAPE]`, with a `##` comment citing FR3. The architecture names `IGNORED_KEYCODES` as a `GameConstants` member (Configuration table). If the typed `const` array fails to parse in 4.7.2, fall back to `const IGNORED_KEYCODES: Array = [...]` and say so in the Debug Log.
  - [x] 2.2 Function keys are a range, not a list: add `const FUNCTION_KEY_FIRST: Key = KEY_F1` and `const FUNCTION_KEY_LAST: Key = KEY_F35` (contiguous in Godot 4's `Key` enum), or keep the range check private inside `TypingInput`; either is fine, just don't list 35 keys.

- [x] **Task 3: `TypingInput` filtering and case rule (AC: 1, 3, 4, 5)**
  - [x] 3.1 Create the folder `scripts/typing/` and `scripts/typing/typing_input.gd`: `class_name TypingInput extends Node`, a `##` doc comment explaining the pipeline position (`InputEventKey` → filter → case rule → `char_typed`; `TypingSession` judges, Story 2.2) and that it never judges, never touches the clock and never knows the target.
  - [x] 3.2 Signals (typed, past tense, ADR-5 local ownership): `signal char_typed(c: String)`, `signal caps_lock_suspected`, `signal caps_lock_cleared`.
  - [x] 3.3 State: `var _case_sensitive: bool = false`, `var _space_is_input: bool = false` (lowercase defaults, matching Zombie Run, so an unconfigured node behaves like a lowercase level), `var _capital_streak: int = 0`, `var _caps_suspected: bool = false`.
  - [x] 3.4 `func configure(config: LevelConfig) -> void`: copies `case_sensitive` and `space_is_input` and resets the Caps Lock state **silently** (streak 0, suspected false, no signal). A `null` config is a contract violation: `assert(config != null, ...)` plus `Log.error(&"typing", ...)`, then return with the current settings kept (architecture Error Handling: "Bug" row). `RunFrame` (Story 2.4) calls `configure()` once at run start; this story adds no caller.
  - [x] 3.5 `func handle_key(event: InputEventKey) -> bool`: the whole rule, public so tests feed synthetic events without the scene tree. Returns `true` only when `char_typed` was emitted. Order:
    1. `null`, `not event.pressed` or `event.echo` → `false`.
    2. `event.ctrl_pressed or event.alt_pressed or event.meta_pressed` → `false` (Ctrl+A, Alt+letter and browser/OS shortcuts are never typing). Shift is allowed: Shift+`a` is how capitals and `!` are typed.
    3. `event.keycode in GameConstants.IGNORED_KEYCODES` or a function key (F1–F35) → `false`.
    4. `event.unicode == 0` → `false` (dead key, IME composition, modifier alone).
    5. `event.unicode < 32 or event.unicode == 127` → `false` (control characters; belt and braces for Tab 9, Enter 13, Esc 27, Backspace 8 and Delete 127 if a platform ever reports them with a `unicode`).
    6. `var raw: String = String.chr(event.unicode)`.
    7. `raw == " "` and not `_space_is_input` → `false` (Space is ignored in lowercase levels, FR3). Space never touches the Caps Lock streak.
    8. If not `_case_sensitive`: update the Caps Lock state from `raw` (Task 4), then `c = raw.to_lower()`. Otherwise `c = raw`.
    9. Emit `char_typed(c)`, return `true`.
  - [x] 3.6 `func _unhandled_input(event: InputEvent) -> void`: cast to `InputEventKey` (`as`); if `null`, return. If `handle_key(key)` returns `true`, call `get_viewport().set_input_as_handled()`. Do **not** mark ignored keys as handled: Esc must still reach `RunFrame`'s pause handler (Story 2.7), and F3/F5/F6/F7/F8 are read earlier by the debug overlay's `_input` anyway. Use `_unhandled_input`, not `_input`, so the overlay's handled F-keys and GUI controls get first refusal (Godot order: `_input` → GUI → `_shortcut_input` → `_unhandled_key_input` → `_unhandled_input`).
  - [x] 3.7 Logging: when `Log.verbose_typing` is on, `Log.debug(&"typing", "typed '%s'" % c)` on each emission (the deferred 1.1 item "verbose_typing is declared but not consumed"; F7 toggles it in Story 2.10). Guard with `if Log.verbose_typing:` **before** formatting, because `Log.debug` evaluates its argument even when DEBUG is off (1.1 deferral). Nothing logs ignored keys. No `print`.
  - [x] 3.8 No `await`, no timers, no autoload use, no `JavaScriptBridge`/`OS.has_feature("web")` in this file. It stays a pure filter (Architectural Boundary 1: `TypingInput` is the one node in `scripts/typing/`, but it still uses no autoloads).

- [x] **Task 4: Caps Lock hint (AC: 6)**
  - [x] 4.1 Inside `handle_key`, only when not `_case_sensitive`, on the **raw** character before lowercasing:
    - Capital letter = `raw != raw.to_lower()`: `_capital_streak += 1`; when it reaches 3 (`CAPS_HINT_STREAK`) and `_caps_suspected` is false → set `_caps_suspected = true`, emit `caps_lock_suspected` **once** (a 4th, 5th … capital emits nothing more).
    - Lowercase letter = `raw != raw.to_upper()`: `_capital_streak = 0`; if `_caps_suspected` → set false, emit `caps_lock_cleared` once.
    - Anything else (digits, punctuation, accented characters without case, Space in a case-sensitive level) leaves the streak and the flag unchanged.
  - [x] 4.2 `const CAPS_HINT_STREAK: int = 3` local to `typing_input.gd` with a `##` comment citing FR5. It is a fixed GDD rule, not a playtest-tuned balance number, so it is a script constant, not a `LevelConfig` field (same reasoning as `RUN_HISTORY_CAP` in `GameConstants`).
  - [x] 4.3 Emit order for a capital that completes the streak: `caps_lock_suspected` first, then `char_typed("a")`. For a lowercase letter that clears: `caps_lock_cleared` first, then `char_typed`. (The HUD can show the hint in the same frame as the judgment; the order is tested.)
  - [x] 4.4 The hint is advisory only: capitals are still accepted as lowercase in lowercase levels (EXPERIENCE.md "Caps Lock suspected: letters still accepted").

- [x] **Task 5: Tests `tests/unit/test_typing_input.gd` (AC: 1–7)**
  - [x] 5.1 Header `extends GutTest` with a `##` line naming the story. Helper `_key(keycode: Key, unicode: int = 0, pressed: bool = true, echo: bool = false) -> InputEventKey` (same shape as `tests/unit/test_keyboard_test.gd`) plus a modifier variant or `event.set("shift_pressed", true)`. Make a fresh `TypingInput.new()` per test with `autofree()` (no tree needed for `handle_key`); `watch_signals(node)`. Load the two fixtures with `load("res://tests/fixtures/levels/...tres") as LevelConfig`.
  - [x] 5.2 Ignored (AC 1), each asserting `handle_key` returns `false` and `assert_signal_not_emitted(node, "char_typed")`:
    - release (`pressed = false`) of `a`; echo of `a` (`echo = true`, unicode 97);
    - `unicode == 0` with `KEY_A` (dead key / IME) and `KEY_SHIFT` alone;
    - every keycode in `GameConstants.IGNORED_KEYCODES`, each sent **with a printable unicode** (e.g. 97) so the test proves the keycode rule, not just the unicode rule;
    - `KEY_F1`, `KEY_F3`, `KEY_F12`, `KEY_F35` (with unicode 97, same reason);
    - control-character unicodes 8, 9, 13, 27, 127 on a non-listed keycode (e.g. `KEY_NONE`);
    - `a` with `ctrl_pressed`, with `alt_pressed`, with `meta_pressed` (loop like `test_apply_key_ignores_modifier_combos`).
  - [x] 5.3 Lowercase config (AC 3), via the `level_config_lowercase.tres` fixture: `a` → `"a"`; `A` with `shift_pressed` (unicode 65) → `"a"`; `A` without Shift (Caps Lock: unicode 65, `shift_pressed = false`) → `"a"`; Space (unicode 32) → nothing and returns `false`; `1` (unicode 49), `;` and `!` (Shift+1, unicode 33) pass unchanged; keypad `KEY_KP_1` with unicode 49 → `"1"`. Use `assert_signal_emitted_with_parameters(node, "char_typed", ["a"])` and `assert_signal_emit_count`.
  - [x] 5.4 Case-sensitive config (AC 4), via `level_config_case_sensitive.tres`: `A`, `a`, Space emit `"A"`, `"a"`, `" "` in that order (record emissions with a lambda appending to an `Array[String]`, or `get_signal_parameters(node, "char_typed", i)`).
  - [x] 5.5 Unconfigured node behaves as lowercase (default state): `A` → `"a"`, Space → nothing.
  - [x] 5.6 Character matching (AC 5): `KEY_Q` with unicode 97 → `"a"`; `KEY_A` with unicode 113 → `"q"`.
  - [x] 5.7 Caps Lock (AC 6), lowercase config:
    - `A A A` → `caps_lock_suspected` count 1; a 4th and 5th `A` → still 1; then `a` → `caps_lock_cleared` count 1; another `a` → still 1;
    - `A A a A` → never suspected (streak broken), no cleared;
    - two full cycles (`AAA a AAA a`) → suspected 2, cleared 2;
    - `A A 1 A` → suspected (non-letters are neutral) and `A A ! A` too;
    - Space between capitals in the lowercase level (`A A Space A`) → suspected (ignored Space does not reset);
    - emit order: the 3rd capital produces `caps_lock_suspected` before `char_typed` (record both into one ordered `Array[String]` via lambdas);
    - echo / ignored / modifier events never change the streak (`A A` + echo `A` + `A` → suspected only on the real 3rd capital: count after the echo is 0, after the next `A` is 1).
  - [x] 5.8 Case-sensitive config: `A A A A a` → neither caps signal is emitted.
  - [x] 5.9 `configure()` resets the streak silently: `A A`, `configure(lowercase)`, `A` → no suspected; and after `A A A` (suspected), `configure(lowercase)` emits no `caps_lock_cleared`, then `A A A` suspects again (count 2 total).
  - [x] 5.10 `configure(null)`: GUT treats a failed `assert()` in a debug runner as an error that fails the test, so **do not** call `configure(null)` in a test unless you can show it doesn't fail the run; cover the null guard by code review instead and say so in the Debug Log (same approach as earlier contract-violation guards in this repo).
  - [x] 5.11 `_unhandled_input` path: add the node with `add_child_autofree(node)`, call `node._unhandled_input(_key(KEY_A, 97))` → `char_typed("a")`; a non-key event (`InputEventMouseButton.new()`) → nothing, no error. Don't assert the viewport's handled flag (unreliable outside real input dispatch).
  - [x] 5.12 `LevelConfig` (AC 2), in the same file or `tests/unit/test_level_config.gd`: `LevelConfig.new()` has `duration_s == 0.0`, `case_sensitive == false`, `space_is_input == false`, `target_mode == LevelConfig.TargetMode.LETTER`; both fixtures load with `is LevelConfig` true and their four values as written in Task 1.2.
  - [x] 5.13 `GameConstants.IGNORED_KEYCODES` contains Shift, Ctrl, Alt, Meta, the 4 arrows, Tab, Backspace, Enter, keypad Enter, Caps Lock and Escape, and does **not** contain `KEY_SPACE` (Space is a per-level rule, not a global ignore).

- [x] **Task 6: Run and verify (AC: 7)**
  - [x] 6.1 Red first: write the tests before `typing_input.gd`/`level_config.gd` exist and record the failure (parse/preload errors) in the Debug Log.
  - [x] 6.2 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: all tests pass (209 at `HEAD` + new), exit 0, and the log has no `Parse Error`, `Failed to load script` or `SCRIPT ERROR`. Commit the `.uid` files Godot generates for the new scripts (every earlier story did).
  - [x] 6.3 Boundary greps: `JavaScriptBridge` / `has_feature("web")` still only in `web_platform.gd`; `FileAccess` under `scripts/` still only in `save_service.gd`; no `randi(`/`randf(` in `scripts/typing/`; no `await` in `scripts/typing/`.
  - [x] 6.4 No manual browser check is required: `TypingInput` has no scene or caller until Story 2.4 builds `RunFrame`. Story 2.4's run is the first end-to-end keyboard check of this filter (add a note to its story when it's created; see Dev Notes "What later stories rely on").
  - [x] 6.5 `deferred-work.md`: strike the 1.1 item "`Log.verbose_typing` is declared but not consumed" as done in 2.1, and the 1.8 note "F-keys may conflict with typing screens in Story 2.1" as resolved (function keys are ignored by `TypingInput`, and the overlay reads them first in `_input`). Add a "Deferred from: dev of story-2-1" section for anything new (at least the AltGr limitation below, unless you find Godot reports AltGr without `ctrl_pressed`/`alt_pressed`).

### Review Findings

- [x] [Review][Defer] Shift-held capitals count toward the Caps Lock streak [scripts/typing/typing_input.gd:100] — deferred by decision: kept as AC 6 specifies (raw-character capitals). Known false positive for Shift-held capitals such as "NASA"; revisit if playtests show it.
- [x] [Review][Patch] Reject invalid code points before emitting: C1 controls (128–159), surrogates (0xD800–0xDFFF), values above 0x10FFFF, and any case-folded result whose length is not 1 [scripts/typing/typing_input.gd:47]
- [x] [Review][Patch] Header comment says "uses no autoloads" but the node calls `Log` (autoload) [scripts/typing/typing_input.gd:4]
- [x] [Review][Patch] Add a test asserting `KEY_F35 - KEY_F1 == 34`, since the F-key range check assumes contiguous enum values [tests/unit/test_typing_input.gd]
- [x] [Review][Patch] `test_unhandled_input_forwards_key_events`: use `add_child_autofree`, and assert the event is marked handled for emitted keys and not for ignored ones [tests/unit/test_typing_input.gd]
- [x] [Review][Patch] Add boundary tests for `unicode` 31 / 32 / 126 / 127 / 128 [tests/unit/test_typing_input.gd]
- [x] [Review][Defer] Caps Lock state is not reset on focus loss or pause, so a stuck `_caps_suspected` never re-fires [scripts/typing/typing_input.gd:62] — deferred to Story 2.4/2.7 (run lifecycle owns `configure()` and pause)
- [x] [Review][Defer] Node marks printable keys handled whenever it is in the tree, so it could swallow keys other UI needs [scripts/typing/typing_input.gd:66] — deferred to Story 2.4 (add an enabled flag or active-run gate when `RunFrame` exists)
- [x] [Review][Defer] An unconfigured node silently acts as a lowercase level and consumes keys [scripts/typing/typing_input.gd:62] — deferred to Story 2.4 (same enabled gate)
- [x] [Review][Defer] Web Caps Lock state is not read directly; the hint relies on the capital streak alone — deferred to Epic 2 polish / web QA (`JavaScriptBridge` via `PlatformService`)

## Dev Notes

### What this story is (and isn't)

- It builds the **first stage of the typing pipeline** (ADR-1): `TypingInput` turns raw `InputEventKey`s into `char_typed(c)` for the characters that count. It doesn't judge right or wrong (that's `TypingSession`, Story 2.2), doesn't know the current target, doesn't count errors and doesn't touch a clock.
- Nothing calls it yet. `RunFrame` (Story 2.4) adds it as a `%TypingInput` child, calls `configure(level.get_level_config())`, connects `char_typed` to its handler, which forwards to `TypingSession.judge()` only in `WAITING_FIRST_KEY`/`RUNNING`. Don't touch `scripts/run/run_frame.gd` (still the Story 1.3 placeholder), `keyboard_test.gd`, `project.godot` or any autoload in this story.
- Don't build: the HUD Caps Lock label (2.5), a test level (2.4), `TypingSession`/`TargetSource` (2.2), `data/levels/*.tres` (2.4 / 3.1), the finger map (2.6).

### Pipeline (architecture: Typing Pipeline & Level Contract)

```
TypingInput (Node)
  InputEventKey → reject echo, unicode == 0, ignored keys → apply case rule → emit char_typed(char)
      ↓
TypingSession (RefCounted, Story 2.2) → RunFrame (2.4) → Level (extends LevelBase)
```

- `RunFrame` configures `TypingInput` from the level's `LevelConfig` (`case_sensitive`, `space_is_input`). Lowercase levels lowercase letters and ignore Space; Pitchfork Panic keeps case and treats Space as input.
- Caps Lock hint: `TypingInput` emits `caps_lock_suspected` after 3 consecutive capitals (raw character, before lowercasing) and `caps_lock_cleared` on the next lowercase; the `Hud` (2.5) shows/hides "Caps Lock is on".
- Feedback latency (NFR2): everything is synchronous in the input callback. No `await`, no deferred calls, no timers in the typing path ("Logic leads, visuals chase").

### Filtering rules, with the reasoning

| Event | Result | Why |
|---|---|---|
| Release (`pressed == false`) | ignored | Only presses type. |
| `echo == true` | ignored | Held-key repeat (FR3). Without this a held `a` would fire errors at the OS repeat rate. |
| Ctrl / Alt / Meta held | ignored | Shortcuts (Ctrl+R, Alt+Tab, Cmd+L) are never typing. Matches `WebPlatform`'s JS listener and the keyboard test's `apply_key`, which also skip modifier combos. |
| keycode in `IGNORED_KEYCODES`, or F1–F35 | ignored | GDD M1 list: Shift, Ctrl, Alt, Meta, arrows, function keys, Tab, Backspace, Enter, Caps Lock. Escape added: it is the pause key (Story 2.7), never a typed character. |
| `unicode == 0` | ignored | Dead keys, IME composition and lone modifiers carry no character (FR3). |
| `unicode < 32` or `== 127` | ignored | Control characters. Some platforms may report Tab/Enter/Esc/Backspace with one; never a typing error. |
| Space, `space_is_input == false` | ignored | Zombie Run and Horde Rush (FR3). Not an error, not emitted. |
| Shift + letter | **emitted** | Shift is how capitals and `!`/`?` are typed (FR3: "Shift, except as part of a capital"). |
| any other printable | emitted (lowercased if not case-sensitive) | Wrong printable keys must reach `TypingSession` so they count as errors (FR2). Digits and punctuation in a lowercase level are emitted unchanged; they're errors there, which is correct. |

- **Character, not key (FR4, NFR6):** always build the character from `event.unicode` (`String.chr(event.unicode)`). `keycode` is used only for the ignore list. `key_label` and `physical_keycode` are not used.
- **Case folding:** `raw.to_lower()` leaves non-letters unchanged, so `!` stays `!`.
- **Capital / lowercase test:** `raw != raw.to_lower()` (capital) and `raw != raw.to_upper()` (lowercase). Works for any letter, not just ASCII; a character with no case (digit, `ß` edge cases aside) is neutral.
- **Known limitation — AltGr:** on Windows, AltGr arrives as Ctrl+Alt, so AltGr characters (e.g. `@` on German layouts) are ignored by the modifier rule. The MVP only needs lowercase letters, and the finger guide assumes US QWERTY (NFR6), so this is accepted; record it in `deferred-work.md` for Epic 8 (Pitchfork Panic punctuation). Don't try to detect AltGr in this story.

### Input routing in this project (read before choosing `_input` vs `_unhandled_input`)

- `scripts/debug/debug_overlay.gd` reads F3/F5/F8/F9 in `_input` (debug builds) and marks them handled, so they never reach `_unhandled_input`. F6/F7 arrive in Story 2.10, same place. Function keys are also in `TypingInput`'s ignore rule, so there is no conflict either way (resolves the 1.8 review note "F-keys may conflict with typing screens").
- `scripts/screens/title.gd` and `keyboard_test.gd` use `_unhandled_input` and swallow keys there. `TypingInput` follows the same pattern.
- Esc must stay unhandled by `TypingInput` so `RunFrame` (2.7) can pause on it. Enter is never typing input (EXPERIENCE.md Interaction Primitives).
- GUI buttons get keys before `_unhandled_input`. Run-screen buttons must be `FOCUS_NONE` (as on the keyboard test screen) or Space/Enter could press them; that's a 2.4/2.5/2.7 concern, noted here so it isn't missed.
- On web, `WebPlatform.capture_keys` (set by `RunFrame` in 2.4) stops the browser acting on Space, `'`, `/`, Backspace and Tab. `TypingInput` doesn't touch it.
- When the tree is paused (pause/countdown, 2.7), a default-`process_mode` node gets no input callbacks. That's fine: `RunFrame` also rejects typing by state. Don't set `PROCESS_MODE_ALWAYS` on `TypingInput`.

### Files to create / modify

| File | Action | Notes |
|---|---|---|
| `scripts/typing/typing_input.gd` | NEW | `class_name TypingInput extends Node`. First file in `scripts/typing/`. |
| `scripts/resources/level_config.gd` | NEW | `class_name LevelConfig extends Resource`, 4 fields + `TargetMode` enum. |
| `scripts/core/game_constants.gd` | UPDATE | Add `IGNORED_KEYCODES` (+ F-key range constants if you choose that option). Today it holds `LOGICAL_SIZE`, `RUN_HISTORY_CAP`, `CURRENT_SCHEMA`; keep them unchanged. |
| `tests/unit/test_typing_input.gd` | NEW | All AC rules. |
| `tests/unit/test_level_config.gd` | NEW (optional) | Or put the `LevelConfig` tests in `test_typing_input.gd`. |
| `tests/fixtures/levels/level_config_lowercase.tres` | NEW | Test-only config. |
| `tests/fixtures/levels/level_config_case_sensitive.tres` | NEW | Test-only config. |
| `_bmad-output/implementation-artifacts/deferred-work.md` | UPDATE | Strike two resolved notes, add the 2.1 section. |
| `.uid` files for the new scripts | NEW | Generated by `--import`; commit them. |

`tests/` is already excluded from both export presets (`tests/*`), so the fixtures never ship.

### Existing code to reuse and stay consistent with

- **`scripts/core/log.gd`**: `Log.debug(tag, msg)`, `Log.error`, `Log.verbose_typing` (static bool, currently unused; this story is its first reader). Tag `&"typing"`.
- **`scripts/screens/keyboard_test.gd` `apply_key()`**: the earlier echo rule (pressed/echo/modifier/unicode < 32). Same spirit, but it's a throwaway debug screen that appends Backspace; don't import or reuse it, and don't change it.
- **`tests/unit/test_keyboard_test.gd`**: the synthetic `InputEventKey` helper and the `event.set(modifier, true)` loop to copy.
- **`scripts/resources/audio_cue.gd`**: the house style for a small custom Resource (`class_name` first, `extends Resource`, `##` doc, `@export` typed fields).
- **`data/audio/audio_library.tres`**: what a text `.tres` with a script class looks like in this project.

### Coding conventions (architecture: Naming Conventions, Consistency Rules)

- Static typing everywhere: `debug/gdscript/warnings/untyped_declaration` is **Error** in `project.godot`, so an untyped `var`, parameter or return fails the parse. Use `:=` only where the type is obvious.
- Tabs, `snake_case` files/functions, `_` prefix for private members, `UPPER_SNAKE` constants, PascalCase `class_name`, signals past tense and typed.
- Doc comments with `##` at the top of each script and on public members (see `log.gd`, `web_platform.gd`).
- Contract violations: `assert` + `Log.error` + safe early return. Runtime oddities (unmapped key etc.) are simply ignored, never errors.
- No `get_node("/root/...")`, no autoload access from `scripts/typing/`.

### Testing standards

- GUT 9.7.1, tests in `tests/unit/`, files `test_<unit>.gd`, `extends GutTest`. `.gutconfig.json` runs everything under `res://tests/` with prefix `test_`.
- Signal assertions: `watch_signals(obj)`, `assert_signal_emitted(obj, "sig")`, `assert_signal_not_emitted`, `assert_signal_emit_count(obj, "sig", n)`, `assert_signal_emitted_with_parameters(obj, "sig", [args])` (checks the most recent emission; use `get_signal_parameters(obj, "sig", index)` for older ones).
- `autofree(TypingInput.new())` is enough for `handle_key` tests; use `add_child_autofree` only for the `_unhandled_input` test.
- The existing suite prints some expected `ERROR` lines (from earlier error-path tests); judge success by GUT's pass count and exit code, plus no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.

### What later stories rely on (keep these stable)

- **2.2** `TypingSession.judge(c: String)` receives exactly what `char_typed` emits: one character, already case-folded for lowercase levels. Wrong printable characters must be emitted (they become errors).
- **2.4** `RunFrame` calls `%TypingInput.configure(config)` and connects `char_typed`; it also adds `duration_s` use and the test level's `.tres`. The `LevelConfig` field names and the `TargetMode` enum names are referenced by later stories as written here (`TargetMode.LETTER/WORD/PARAGRAPH`; the HUD's "Type the letter/word/text to start!" label in 2.5 keys off `target_mode`).
- **2.5** `Hud` connects `caps_lock_suspected` / `caps_lock_cleared` to show/hide "Caps Lock is on".
- **2.10** F7 flips `Log.verbose_typing`; this story's per-emission DEBUG line is one of the logs it turns on.

### Previous story intelligence (Epic 1)

- **Test-first works here:** stories 1.6–1.9 recorded the red run (parse/preload errors) in the Debug Log, then green. Keep doing that.
- **Commands** (from 1.8/1.9): `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `... -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Run `--import` after adding new `class_name` scripts or `.tres` files, otherwise GUT can fail to resolve the new class names.
- **Reviews keep catching tests that can't fail** (1.4, 1.5 and 1.9 reviews: "passes with or without the guard", `assert_lte` that can't fail). Make every test able to fail: e.g. send ignored keycodes **with** a printable unicode, check emission counts, not just "emitted".
- **Contract-violation asserts in tests:** no earlier test calls a function that trips an `assert`; follow that (Task 5.10).
- **Deferred notes that touch this story:** 1.1 "`Log.verbose_typing` not consumed; wire up in Epic 2" and 1.8 "F-keys may conflict with typing screens in Story 2.1". Both are resolved here (Task 6.5).
- Epic 1 left placeholder screens (`run_frame.gd`, keyboard test, art review). Don't clean them up in this story; they have their own deferrals.

### Git intelligence

- Recent commits are one per story: `Story 1.9: art style sheet and prototype sprites`, `Story 1.8: debug overlay and save export`, … Each commits scripts with their `.uid` files, tests, the story file, `sprint-status.yaml` and `deferred-work.md` together. Follow the same "Story 2.1: typing input filtering" pattern if Smuck asks for a commit.
- No new dependencies: this story uses only built-in Godot APIs and GUT, which is already installed.

### Godot API notes (4.7.2, stable since 4.0)

- `InputEventKey`: `pressed`, `echo`, `keycode` (`Key` enum), `unicode` (int code point; 0 when no character), `shift_pressed` / `ctrl_pressed` / `alt_pressed` / `meta_pressed` (from `InputEventWithModifiers`). `KEY_F1`…`KEY_F35` are consecutive values in the `Key` enum.
- `String.chr(code: int) -> String` builds the character. `String.to_lower()` / `to_upper()` are Unicode-aware.
- Custom Resources: `class_name X extends Resource` + `@export` fields show in the Inspector and serialize in `.tres`. An enum declared in the Resource script is exported as an int with named values (`@export var target_mode: TargetMode`).

### Project Structure Notes

- Paths follow the architecture's directory tree exactly: `scripts/typing/typing_input.gd`, `scripts/resources/level_config.gd`, `tests/unit/test_typing_input.gd`. `scripts/typing/` doesn't exist yet; create it.
- `tests/fixtures/levels/` is new (the tree only shows `tests/fixtures/saves/`). It's a test-only fixtures folder, consistent with the existing pattern; noted as a small, intended addition.
- Boundary 5 ("`data/` holds instances, `scripts/resources/` holds definitions") is respected: `LevelConfig` is defined in `scripts/resources/`; the fixtures are test data, not game data, so they live under `tests/fixtures/`, not `data/`.

### Project Context Rules

No `project-context.md` exists in this repo. The binding rules come from `_bmad-output/game-architecture.md` (Consistency Rules, Architectural Boundaries, Naming Conventions) and are summarised under "Coding conventions" above. Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; the Godot MCP server is available but not needed (no scene to run in this story).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1: Typing Input Filtering] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR1–FR6 (typing input & judgment), FR3/FR4/FR5 directly.
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements] — "Testing" (`TypingInput` filtering unit-tested with synthetic `InputEventKey`s) and "Core architecture" (`TypingInput` configured from `LevelConfig`, emits `caps_lock_suspected`/`caps_lock_cleared`).
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract] — pipeline, configuration, Caps Lock rule.
- [Source: _bmad-output/game-architecture.md#Configuration] — `IGNORED_KEYCODES` in `GameConstants`; no GDD numbers as literals; `LevelConfig` fields.
- [Source: _bmad-output/game-architecture.md#Directory Structure] — `scripts/typing/typing_input.gd`, `scripts/resources/level_config.gd`, `tests/unit/test_typing_input.gd`.
- [Source: _bmad-output/game-architecture.md#Architectural Boundaries] — `scripts/typing/` purity, Boundary 5.
- [Source: _bmad-output/game-architecture.md#Logging] — `Log.verbose_typing`, no hot-path logging.
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#M1 Typing input] (lines ~116–121) — ignored keys, case rule, Caps Lock hint.
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md#Interaction Primitives] — Esc = pause, Enter never typing input; "Caps Lock suspected: letters still accepted".
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — 1.1 `verbose_typing` note, 1.8 F-key note.
- [Source: scripts/screens/keyboard_test.gd, tests/unit/test_keyboard_test.gd] — existing echo rule and synthetic-event test helpers.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Red (6.1): tests and fixtures written first. GUT run: `test_typing_input.gd` failed to load with `Parse Error: Could not find type "TypingInput"` / `"LevelConfig"` and `Cannot find member "IGNORED_KEYCODES" in base "GameConstants"`; the other 209 tests passed. Note: GUT still exits 0 when a test script fails to parse, so the pass count is the real check.
- `const IGNORED_KEYCODES: Array[Key] = [...]` parses fine in 4.7.2; no fallback needed. Function keys use `FUNCTION_KEY_FIRST`/`FUNCTION_KEY_LAST` constants in `GameConstants`.
- Green (6.2): `--import`, then full GUT run: 238/238 passing (209 + 29 new), exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`. The only warnings are the existing expected ones from `test_audio_manager.gd`.
- Mutation check: disabling the keycode ignore rule fails 1 test; forcing the lowercase rule in case-sensitive mode fails 2. Restored afterwards.
- 5.10: `configure(null)` is not called in tests (the debug `assert` would fail the run); the guard (`assert` + `Log.error(&"typing", ...)` + early return keeping current settings) is covered by code review.
- 5.11: the `_unhandled_input` test uses `autofree` + `add_child` (same effect as `add_child_autofree`), since the node is made in `before_each`.
- 6.3 greps: `JavaScriptBridge`/`has_feature("web")` only in `web_platform.gd`; `FileAccess` only in `save_service.gd`; no `randi(`/`randf(`/`await` in `scripts/typing/`.
- Fixture `.tres` files were written without a `uid=` header; Godot imports them fine by path and did not rewrite them.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `LevelConfig` Resource (`scripts/resources/level_config.gd`): `TargetMode { LETTER, WORD, PARAGRAPH }` and the four exported fields, neutral defaults (`duration_s = 0.0`). Two test fixtures in `tests/fixtures/levels/`.
- `GameConstants.IGNORED_KEYCODES` (typed `Array[Key]`, no Space) plus `FUNCTION_KEY_FIRST`/`FUNCTION_KEY_LAST` for F1–F35.
- `TypingInput` (`scripts/typing/typing_input.gd`): `handle_key()` filters release/echo/Ctrl-Alt-Meta/ignored keycodes/F-keys/zero and control unicodes, builds the character from `unicode` only, ignores Space unless `space_is_input`, lowercases in lowercase levels, emits `char_typed`. `_unhandled_input` marks only emitted keys as handled, so Esc still reaches the future pause handler. `configure()` resets the Caps Lock hint silently.
- Caps Lock hint: `CAPS_HINT_STREAK = 3` capitals in a row (raw character) emit `caps_lock_suspected` once, before `char_typed`; the next lowercase letter emits `caps_lock_cleared` before `char_typed`. Non-letters and ignored events are neutral. Case-sensitive levels never emit either.
- First reader of `Log.verbose_typing` (DEBUG line per emitted character, guarded before formatting).
- 29 tests in `tests/unit/test_typing_input.gd` cover AC 1–6 (ignored keys sent with printable unicode, emission counts and emit order). No caller exists yet; Story 2.4 is the first end-to-end keyboard check.
- `deferred-work.md`: struck the 1.1 `verbose_typing` and 1.8 F-key notes; added a 2.1 section (AltGr limitation, null-guard coverage, 2.4 follow-ups).

### File List

- `scripts/resources/level_config.gd` (new)
- `scripts/resources/level_config.gd.uid` (new)
- `scripts/typing/typing_input.gd` (new)
- `scripts/typing/typing_input.gd.uid` (new)
- `scripts/core/game_constants.gd` (modified)
- `tests/unit/test_typing_input.gd` (new)
- `tests/unit/test_typing_input.gd.uid` (new)
- `tests/fixtures/levels/level_config_lowercase.tres` (new)
- `tests/fixtures/levels/level_config_case_sensitive.tres` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-1-typing-input-filtering.md` (this file)

### Change Log

- 2026-10-03: Story 2.1 created (ready-for-dev).
- 2026-10-03: Implemented `LevelConfig`, `IGNORED_KEYCODES`, `TypingInput` filter and Caps Lock hint with 29 tests (238/238 passing). Status → review.
