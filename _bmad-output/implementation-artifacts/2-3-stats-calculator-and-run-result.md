---
baseline_commit: beb485e90d77a67b05ce3efe26db9edac23143af
---

# Story 2.3: Stats Calculator and Run Result

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want my Keys Typed, Errors, Accuracy, WPM and time to be calculated correctly,
so that the report card tells me the truth about how I did.

## Acceptance Criteria

1. **Accuracy.** Given `StatsCalculator` (`scripts/typing/stats_calculator.gd`, `class_name StatsCalculator`, static functions only), when `accuracy_percent(keys, errors)` is called, then it returns Keys ÷ (Keys + Errors) as a whole-number percent, **rounded down** (so 100 % only when `errors == 0`), and `0` when both are 0, without dividing by zero (FR7).
2. **WPM.** Given `wpm(keys, seconds, completed_words = 0)`, then it returns ((Keys + completed_words) ÷ 5) ÷ (seconds ÷ 60) as a whole number, **rounded down**; `seconds <= 0` or `keys + completed_words == 0` gives `0` without dividing by zero. `wpm_exact(...)` returns the same value unrounded as a `float` (FR7; Epic 7's rolling average and Story 2.5's live HUD reuse it).
3. **Implied spaces.** Given word mode, when `completed_words > 0` is passed, then each completed word adds 1 to the WPM key count only; Keys Typed and Accuracy are unchanged (FR7: "Horde Rush adds +1 per completed word for the implied space").
4. **Lesson Time.** Given `format_time(seconds)`, then it returns `m:ss` with whole seconds rounded down (`120.0 → "2:00"`, `119.9 → "1:59"`, `5.0 → "0:05"`, `0 → "0:00"`, `600.0 → "10:00"`); negative input gives `"0:00"` (FR7).
5. **End reasons.** Given `GameConstants`, then it defines `END_REASON_TIMER = &"timer"`, `END_REASON_CAUGHT = &"caught"` and `END_REASON_ESCAPED = &"escaped"` (architecture Data Persistence: "Defined once as constants in `GameConstants`"). There is no quit reason (quit runs are never recorded).
6. **RunResult contents.** Given `RunResult` (`scripts/typing/run_result.gd`, `class_name RunResult extends RefCounted`) built at run end through `RunResult.create(...)`, then it holds `level_id`, `timestamp`, `duration_s`, `keys_typed`, `errors`, `wpm`, `accuracy`, `brains`, `bonus_brains`, `letter_pool_or_tier`, `per_key` and `end_reason`; `wpm` and `accuracy` are computed by `StatsCalculator` (never passed in), and `per_key` is a deep copy of the input.
7. **Run record.** Given a `RunResult`, when `to_record()` is called, then it returns the save's run-record `Dictionary` with exactly the keys `timestamp, level_id, duration_s, keys_typed, errors, wpm, accuracy, brains, letter_pool_or_tier, per_key, end_reason` (the same key set as `tests/fixtures/saves/save_v1_full.json` run records); every number is an `int` (`duration_s` rounded down to whole seconds, `brains` = level brains + bonus brains), `level_id` and `end_reason` are `String`, and `per_key` is a deep copy in the shape `{"f": [attempts, errors, {"g": 2}]}`.
8. **Tests.** Given `tests/unit/test_stats_calculator.gd` and `tests/unit/test_run_result.gd`, when GUT runs, then the known case 100 keys, 5 errors, 120 s → 95 %, 10 WPM, `"2:00"` passes, along with every rule above (zero cases, rounding-down edges, implied spaces, record shape and JSON round-trip through `SaveSchema.prepare`), and the full suite has no regressions (268 tests passing at `HEAD` `beb485e`; confirm the count in the first run).

## Tasks / Subtasks

- [x] **Task 1: End-reason constants (AC: 5)**
  - [x] 1.1 In `scripts/core/game_constants.gd`, add `END_REASON_TIMER: StringName = &"timer"`, `END_REASON_CAUGHT: StringName = &"caught"`, `END_REASON_ESCAPED: StringName = &"escaped"`, with one `##` comment above the group: timer = the level's clock reached its duration (Zombie Run, Horde Rush); caught/escaped = Pitchfork Panic; quit runs are never recorded, so there is no quit reason. Keep the existing constants untouched.

- [x] **Task 2: `StatsCalculator` (AC: 1, 2, 3, 4)**
  - [x] 2.1 Create `scripts/typing/stats_calculator.gd`: `class_name StatsCalculator` on line 1 (no `extends` line needed for a static-only class, as in `game_constants.gd`/`save_schema.gd`; if a parse warning appears, add `extends RefCounted`). `##` doc block: the report card's formulas (FR7) in one place; pure and static, no nodes, no autoloads, no clock; Story 2.5 (live HUD WPM), RunResult (this story) and Epic 7 (rolling average) all call it.
  - [x] 2.2 `const CHARS_PER_WORD: int = 5` (standard WPM definition, a formula constant, not a balance number; it lives in the owning script per architecture Configuration).
  - [x] 2.3 `static func accuracy_percent(keys: int, errors: int) -> int`: `total := keys + errors`; `0` if `total <= 0`; else `floori(float(keys) * 100.0 / float(total))`. One float division: when the exact quotient is a whole number IEEE gives it exactly, so 57/57 → 100 and 95/100 → 95 floor correctly.
  - [x] 2.4 `static func wpm_exact(keys: int, seconds: float, completed_words: int = 0) -> float`: `counted := keys + completed_words`; `0.0` if `seconds <= 0.0` or `counted <= 0`; else `float(counted) * 60.0 / (float(CHARS_PER_WORD) * seconds)`. Write it as a **single division** (not `(k / 5) / (s / 60)`), which keeps exact cases exact (`100 * 60 / (5 * 120) = 10.0`).
  - [x] 2.5 `static func wpm(keys: int, seconds: float, completed_words: int = 0) -> int`: `floori(wpm_exact(...) + 1e-9)`. The tiny epsilon guards a float result like `9.999999999` for a mathematically whole value (seconds from `RunClock` are accumulated deltas). Name it `_EPSILON` as a private const with a comment.
  - [x] 2.6 `static func format_time(seconds: float) -> String`: `var whole: int = maxi(0, floori(seconds))`; return `"%d:%02d" % [whole / 60, whole % 60]`. `whole / 60` is integer division of two ints: it raises Godot's `INTEGER_DIVISION` warning, so write `floori(whole / 60.0)` or `@warning_ignore("integer_division")` on that line. Check the import/test output for warnings.
  - [x] 2.7 Negative `keys`/`errors`/`completed_words` are a caller bug: `assert(...)` + `Log.error(&"stats", ...)` + treat as 0 (via `maxi(0, ...)`). Tests do **not** call these (a debug `assert` fails the GUT run; same rule as 2.1/2.2). Note it in the Debug Log. `NaN`/`INF` seconds: `wpm_exact` returns `0.0` for a non-finite `seconds` (`not is_finite(seconds)`), `format_time` returns `"0:00"`; these are safe fallbacks, testable, no assert.
  - [x] 2.8 No live-HUD rules here: the 5 s hide and 1 Hz refresh (FR8) belong to the HUD (2.5); it calls `StatsCalculator.wpm(keys, elapsed)`.

- [x] **Task 3: `RunResult` (AC: 6, 7)**
  - [x] 3.1 Create `scripts/typing/run_result.gd`: `class_name RunResult` then `extends RefCounted`, `##` doc block: the result of one finished run; built once by `RunFrame` at run end (2.4), carried in the `REPORT_CARD` payload `{ "result": RunResult }`, read by the report card (2.9) and saved through `PlayerData.record_run(result)` → `to_record()` (2.8). Plain data plus two derived values; no nodes, no autoloads, no clock, no file I/O.
  - [x] 3.2 Public typed fields with `##` docs (set by `create`, read by everyone; nobody should write them afterwards, say so in the doc):
    - `level_id: StringName`
    - `timestamp: int` (Unix seconds, UTC, from the caller)
    - `duration_s: float` (Lesson Time: first correct key to run end, unrounded)
    - `keys_typed: int`, `errors: int`
    - `completed_words: int` (implied spaces; 0 in letter mode; kept for transparency, **not** written to the record)
    - `wpm: int`, `accuracy: int` (computed)
    - `brains: int` (earned in the level during the run, no bonus), `bonus_brains: int` (completion bonus, e.g. +10)
    - `letter_pool_or_tier: String` (`"all"` in the MVP, see Dev Notes)
    - `per_key: Dictionary` (`{char: [attempts, errors, {typed: count}]}`)
    - `end_reason: StringName` (one of the `GameConstants.END_REASON_*`)
  - [x] 3.3 `static func create(level_id: StringName, timestamp: int, duration_s: float, keys_typed: int, errors: int, per_key: Dictionary, brains: int, bonus_brains: int, letter_pool_or_tier: String, end_reason: StringName, completed_words: int = 0) -> RunResult`. Assigns every field, stores `per_key.duplicate(true)`, computes `wpm = StatsCalculator.wpm(keys_typed, duration_s, completed_words)` and `accuracy = StatsCalculator.accuracy_percent(keys_typed, errors)`. Keep `_init()` argument-free so `RunResult.new()` stays valid (GUT doubles and future `from_record` won't fight a required-argument constructor).
  - [x] 3.4 Contract checks in `create`: `assert` + `Log.error(&"run", ...)` for an empty `level_id` or an `end_reason` that is not one of the three constants; keep the values (the result is still built: a run must never be lost to a bad label). Not called in tests; note in the Debug Log.
  - [x] 3.5 `func total_brains() -> int`: `brains + bonus_brains` (what `PlayerData.record_run` adds in 2.8; what the report card shows as "Brains Collected", with the bonus on its own "+N bonus" line, mock: 45 collected, "+10 bonus").
  - [x] 3.6 `func lesson_time() -> String`: `StatsCalculator.format_time(duration_s)`.
  - [x] 3.7 `func to_record() -> Dictionary`: exactly
    ```
    {
      "timestamp": timestamp,
      "level_id": String(level_id),
      "duration_s": maxi(0, floori(duration_s)),
      "keys_typed": keys_typed,
      "errors": errors,
      "wpm": wpm,
      "accuracy": accuracy,
      "brains": total_brains(),
      "letter_pool_or_tier": letter_pool_or_tier,
      "per_key": per_key.duplicate(true),
      "end_reason": String(end_reason),
    }
    ```
    Every number is an `int` (`SaveSchema.normalize_numbers` documents "every number in the save is whole by design"; a float would be written as `120.0`). Convert `StringName`s with `String(...)` so `JSON.stringify` writes plain strings. Do **not** add `bonus_brains` or `completed_words` keys: the run record shape is fixed by the architecture; the save keeps unknown keys, but adding them is a schema decision, not this story's.
  - [x] 3.8 No `from_record()` (YAGNI: nothing reads history back into `RunResult` until Epic 10 trends). No `is_new_best` field: 2.8's `record_run` reports it, and 2.9 receives it separately.

- [x] **Task 4: Tests (AC: 1–8)**
  - [x] 4.1 Red first: write both test files before the scripts exist; record the parse errors (`Could not find type "StatsCalculator"` / `"RunResult"`) in the Debug Log. GUT exits 0 even when a test script fails to parse, so judge by the pass count.
  - [x] 4.2 `tests/unit/test_stats_calculator.gd` (`extends GutTest`, `##` line naming the story). Exact `assert_eq` on every value:
    - **story example:** `accuracy_percent(100, 5) == 95`, `wpm(100, 120.0) == 10`, `format_time(120.0) == "2:00"`;
    - **mock example:** 142 keys, 9 errors, 120 s → `94`, `14`, `"2:00"` (report-card mock values);
    - accuracy: `(0, 0) == 0`; `(0, 5) == 0`; `(10, 0) == 100`; `(999, 1) == 99` (**rounding down**: 99.9 must not show 100 %); `(2, 1) == 66` (66.67 floors); `(1, 2) == 33`; `(57, 0) == 100`;
    - WPM: `(0, 120.0) == 0`; `(100, 0.0) == 0`; `(100, -5.0) == 0`; `(5, 60.0) == 1`; `(9, 60.0) == 1` (1.8 floors); `(51, 60.0) == 10` (10.2 floors); `(100, 60.0) == 20`; `(1, 1.0) == 12`; a non-finite `seconds` (`INF`, `NAN`) → `0`;
    - `wpm_exact(51, 60.0)` is `10.2` (`assert_almost_eq` with 0.0001); `wpm_exact(0, 0.0) == 0.0`;
    - **implied spaces:** `wpm(20, 60.0, 5) == 5` vs `wpm(20, 60.0) == 4`; `wpm(0, 60.0, 5) == 1` (`counted > 0`); accuracy has no word argument (document by test name that accuracy ignores words);
    - **epsilon guard:** pick inputs where the exact answer is whole but float accumulation is not, e.g. seconds built as a sum `var s := 0.0; for i in 7200: s += 1.0 / 60.0` (≈ 120 s from 60 FPS deltas) with 100 keys → `10` (and `wpm_exact` within 0.001 of 10.0); verify by mutation (Task 4.4) that this test fails without the epsilon **only if** the sum lands below 120; if it lands at or above, keep the test as a regression guard and say so in the Debug Log (don't fake a failure);
    - `format_time`: `0.0 → "0:00"`, `5.0 → "0:05"`, `59.99 → "0:59"`, `60.0 → "1:00"`, `119.9 → "1:59"`, `125.0 → "2:05"`, `300.0 → "5:00"`, `600.0 → "10:00"`, `-3.0 → "0:00"`, `INF`/`NAN` → `"0:00"`.
  - [x] 4.3 `tests/unit/test_run_result.gd`:
    - `create` fills every field; `wpm`/`accuracy` come from `StatsCalculator` (e.g. 100 keys, 5 errors, 120.0 s → 10, 95);
    - `completed_words` affects `wpm` but not `accuracy` and is not in `to_record()`;
    - `per_key` is a deep copy on the way **in** (mutating the source dictionary's inner array/map after `create` leaves `result.per_key` unchanged) and on the way **out** (mutating `to_record()["per_key"]["f"][2]` leaves `result.per_key` unchanged);
    - `total_brains()` = brains + bonus (35 + 10 = 45), and `to_record()["brains"] == 45`;
    - `lesson_time()` for 120.0 → `"2:00"`;
    - **record key set:** `to_record().keys()` sorted equals the sorted keys of the first run record in `res://tests/fixtures/saves/save_v1_full.json` (read with `FileAccess.get_file_as_string` and `JSON.parse_string`, same as `test_save_schema.gd`'s fixture helper; reading fixtures from tests is allowed, the "only SaveService touches files" rule is for game code);
    - **record types:** every value except `level_id`, `end_reason`, `letter_pool_or_tier` (`TYPE_STRING`) and `per_key` (`TYPE_DICTIONARY`) is `TYPE_INT`; `duration_s` for 119.7 is `119` (int); `level_id` is `"zombie_run"` (String, not StringName: `typeof == TYPE_STRING`), `end_reason == "timer"`;
    - **save round-trip:** put the record in `SaveSchema.defaults()`'s `run_history`, `JSON.stringify` it, assert the text contains `"duration_s": 120` and not `120.0`, `JSON.parse_string` + `SaveSchema.prepare(...)`, and the record read back is `assert_eq_deep` to `to_record()` (ints survive via `normalize_numbers`);
    - every end reason constant round-trips as its plain string (`"timer"`, `"caught"`, `"escaped"`).
  - [x] 4.4 Mutation checks (record in the Debug Log, restore after, diff-verify): (a) swap `floori` for `roundi` in `accuracy_percent` → the `(999, 1) == 99` test fails; (b) compute WPM without `completed_words` → the implied-space test fails; (c) drop `.duplicate(true)` in `create` → the deep-copy-in test fails; (d) write `duration_s` unfloored in `to_record` → the type test and the `120.0` text check fail. Every test must be able to fail.
  - [x] 4.5 Contract asserts (negative counts, empty level id, unknown end reason) are not called in tests; covered by review.

- [x] **Task 5: Run and verify (AC: 8)**
  - [x] 5.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` (new `class_name` scripts), then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: all tests pass (268 at `HEAD` + new), no `Parse Error`, `Failed to load script`, `SCRIPT ERROR`, and no new `INTEGER_DIVISION` warning. Commit the `.uid` files Godot generates for the new scripts and tests.
  - [x] 5.2 Boundary greps: no `await`, `get_node("/root`, `JavaScriptBridge`, `Time.`, `FileAccess`, `randi(`/`randf(` in `scripts/typing/stats_calculator.gd` or `run_result.gd`; `FileAccess` still only in `save_service.gd` among game scripts; `typing_input.gd` is still the only node in `scripts/typing/`.
  - [x] 5.3 No manual or browser check: nothing builds a `RunResult` until Story 2.4 (note in the Debug Log).
  - [x] 5.4 `deferred-work.md`: add a "Deferred from: dev of story-2-3" section with at least: rounding-down decision for Accuracy and WPM (see Dev Notes; Smuck may overrule after playtest); `RunClock` overshoot clamp is 2.4's job; `letter_pool_or_tier` format for Epic 7; the 2.2 note "`TypingSession` `config` unused until 2.3/6.2" now reads "until 6.2" (implied spaces arrive with `WordSource`).

### Review Findings

- [x] [Review][Patch] Near-zero duration gives an absurd WPM (`wpm(1, 0.016)` = 750; denormal `seconds` overflows `floori`). Decision (Smuck): `StatsCalculator.wpm`/`wpm_exact` return 0 below a minimum duration, set by a new `GameConstants` value, with tests [scripts/typing/stats_calculator.gd:25-34]
- [x] [Review][Patch] `to_record()` non-finite `duration_s` guard (NaN/INF → 0) has no test — add a case to `tests/unit/test_run_result.gd` (spec Task 3.7 only listed the plain floor expression) [scripts/typing/run_result.gd:85]
- [x] [Review][Defer] Record `duration_s` is floored while `wpm` uses the unrounded duration, so recomputing WPM from a saved record can differ by 1 — deferred, spec mandates the floored int; `wpm` is stored, so only matters if Epic 7 recomputes [scripts/typing/run_result.gd:64,85]

Dismissed as noise (9): epsilon/accuracy float-floor worries (IEEE division of exact ints is exact; epsilon test asserts its precondition), positional-arg count and `p_` names (spec signature), fixture/substring test brittleness, `%s` with StringName, END_REASON list duplication, huge-float `floori` (unreachable), negative counts kept raw in `RunResult` (asserted caller bug, documented), `format_time` ≥ 3600 s, static-class instantiation.

## Dev Notes

### What this story is (and isn't)

- It adds the **stats layer** under the typing pipeline: one static calculator (formulas, FR7) and one data object (`RunResult`) that carries a finished run to the report card and the save. Both live in `scripts/typing/`, both are pure logic.
- Nothing calls them yet. `RunFrame` (2.4) builds the `RunResult`; the HUD (2.5) uses `StatsCalculator.wpm` for live WPM; `PlayerData.record_run` (2.8) saves `to_record()`; the report card (2.9) displays the fields.
- Files touched: **new** `scripts/typing/stats_calculator.gd`, `scripts/typing/run_result.gd`, `tests/unit/test_stats_calculator.gd`, `tests/unit/test_run_result.gd`; **update** `scripts/core/game_constants.gd` (three constants only).
- Don't touch: `typing_session.gd` (it already exposes `get_keys_typed()`, `get_errors()`, `get_per_key()`; no stats methods go into the session, 2.2 Dev Notes "StatsCalculator is separate and static"), `level_config.gd`, `player_data.gd` (`record_run` is 2.8), `save_schema.gd`, `run_frame.gd`, any scene, any autoload, `project.godot`.
- Don't build: `RunClock` (2.4), live-WPM 5 s hide / 1 Hz (2.5), best-WPM / history cap (2.8), report card UI (2.9), word-completion counting in the session (Epic 6), `from_record` (Epic 10).

### Formulas (GDD "Stats" table, FR7) and the decisions behind them

| Stat | Formula | Rounding | Zero case |
|---|---|---|---|
| Keys Typed | correct keystrokes (a capital counts as 1) | int already | 0 |
| Errors | wrong printable keystrokes | int already | 0 |
| Accuracy | Keys ÷ (Keys + Errors) × 100 | **down** to whole % | 0 keys & 0 errors → 0 |
| WPM | ((Keys + completed words) ÷ 5) ÷ minutes | **down** to whole number | ≤ 0 s or 0 counted keys → 0 |
| Lesson Time | first correct key → run end | **down** to whole seconds, `m:ss` | negative/non-finite → `0:00` |

- **Why round down (decision taken here, flag to Smuck):** the GDD says "whole number"/"whole-number %" without a direction. Rounding down means a kid only ever sees **100 %** when there were truly no errors (99.9 % is not perfect, and the story asks for "the truth"), and WPM never overstates, so "New best!" (2.8, compared on the saved whole-number WPM) needs a real improvement. Both examples in the docs agree with either choice (story: 100/5/120 s → 95 %, 10 WPM; report-card mock: 142 keys, 9 errors → 94 %, 14 WPM). If Smuck prefers normal rounding, it is a one-line change in each function plus the edge tests.
- **WPM minutes = Lesson Time.** The run's elapsed time from the first correct key, as accumulated by `RunClock` (2.4). For Zombie Run that is 120 s; for Pitchfork Panic "Caught" it is however long the chase lasted.
- **Implied spaces** (FR7, Horde Rush): `+1` to the WPM count per completed word, because the word completes on its last letter without a typed Space. Only WPM changes; Keys Typed and Accuracy don't. `StatsCalculator` takes `completed_words` as a plain number and has no idea about level modes; the caller (RunFrame, from the session's word count in Epic 6) passes 0 in letter mode.
- **Accuracy vs per-key attempts:** report-card accuracy is `keys ÷ (keys + errors)`; per-key `attempts` (2.2) is separate adaptive data. Don't derive one from the other.
- **Live WPM** (2.5) is the same `StatsCalculator.wpm(keys, elapsed_s)`; it is hidden for the first 5 s to avoid spikes like `wpm(1, 1.0) == 12`.

### RunResult ↔ save run record

Architecture "Data Persistence": run record = `{ timestamp, level_id, duration_s, keys_typed, errors, wpm, accuracy, brains, letter_pool_or_tier, per_key, end_reason }`; fixture `save_v1_full.json` has exactly these keys with int numbers and string ids (`"level_id": "zombie_run"`, `"end_reason": "timer"`, `"letter_pool_or_tier": "all"`, `"timestamp": 1790000000`, `"duration_s": 60`).

| RunResult field | Record key | Conversion |
|---|---|---|
| `level_id: StringName` | `level_id` | `String(...)` |
| `timestamp: int` | `timestamp` | as is (Unix seconds UTC) |
| `duration_s: float` | `duration_s` | `floori`, ≥ 0 |
| `keys_typed`, `errors`, `wpm`, `accuracy` | same | ints |
| `brains` + `bonus_brains` | `brains` | `total_brains()` (all brains the run awarded) |
| `letter_pool_or_tier: String` | same | as is |
| `per_key: Dictionary` | `per_key` | deep copy |
| `end_reason: StringName` | `end_reason` | `String(...)` |
| `completed_words` | — | not saved |

- **Brains:** the report card shows "Brains Collected 45" and "+10 bonus" on its own line (mock: 142 keys → ~35 level brains + 10 bonus = 45). So "Brains Collected" = `total_brains()` and the bonus line = `bonus_brains`. The record stores the total ("brains earned"), which is also what 2.8 adds to the wallet.
- **Timestamp:** `RunResult` does not read the clock (pure, testable). `RunFrame` (2.4) passes `int(Time.get_unix_time_from_system())`.
- **`letter_pool_or_tier`:** MVP Zombie Run always uses all 26 letters, so the MVP value is `"all"` (fixture). Epic 7 decides the tier format (e.g. `"tier_3"`). Keep it a `String`; 2.4's test level passes `"all"`.
- **`duration_s` overshoot:** `RunClock` accumulates `delta`, so the last frame can push it to 120.016 s. Clamping to the level duration is `RunFrame`'s job in 2.4 (pass `minf(elapsed, config.duration_s)` for `&"timer"` ends). `RunResult` doesn't know the level duration. Put this in `deferred-work.md` for 2.4.
- **Why ints in the save:** `SaveSchema.normalize_numbers` turns integral floats back into ints after parsing and documents "every number in the save is whole by design". `JSON.stringify(120.0)` writes `120.0`, which `test_save_schema.gd` treats as non-canonical. So `to_record()` must hand over ints.

### Existing code to reuse and stay consistent with

- **`scripts/typing/typing_session.gd`** (2.2): house style for `scripts/typing/` (`class_name` line 1, `extends` line 2, `##` doc block, `_` privates, typed everything, `assert` + `Log.error(tag, ...)` + safe fallback for contract violations). Its getters feed `RunResult.create`: `get_keys_typed()`, `get_errors()`, `get_per_key()` (already a deep copy; `create` copies again, harmless and keeps `RunResult` safe on its own).
- **`scripts/core/game_constants.gd`**: where the end-reason constants go; existing style `const NAME: Type = value` with `##` comments.
- **`scripts/core/save_schema.gd`**: `defaults()`, `prepare(raw)`, `normalize_numbers` for the round-trip test.
- **`scripts/core/log.gd`**: `Log.error(tag, msg)` / `Log.warn`. Tags in use: `&"typing"`, `&"save"`, `&"economy"`, `&"run"`. Use `&"stats"` in the calculator and `&"run"` in `RunResult`.
- **`tests/unit/test_save_schema.gd`**: fixture-loading helper pattern (`res://tests/fixtures/saves/...`), `assert_eq_deep`, canonical-JSON checks.
- **`tests/unit/test_typing_session.gd`**: test style for this folder.

### Coding conventions (architecture: Naming Conventions, Consistency Rules)

- Static typing everywhere: `debug/gdscript/warnings/untyped_declaration` is **Error** (`project.godot`), so every `var`, parameter, return and lambda parameter needs a type. Use `:=` only where the type is obvious from the right side.
- Godot 4.7 built-ins: `floori(x) -> int`, `roundi`, `maxi`, `minf`, `is_finite(x)`; `"%d:%02d" % [m, s]`; `String(StringName)`; `Dictionary.duplicate(true)` deep copies nested arrays and dictionaries; `typeof(x) == TYPE_INT`.
- Integer `/` between two ints triggers the `INTEGER_DIVISION` warning (Task 2.6).
- A local named `seed` shadows a built-in; not relevant here, but don't name locals `round`/`floor` either.
- Tabs, `snake_case` files/functions, `_` prefix for private members, `UPPER_SNAKE` constants, `##` docs on public members, past-tense signals (none in this story: `RunResult` and `StatsCalculator` have no signals).
- No logging in the hot path: `StatsCalculator.wpm` will run once per second from the HUD; no `Log` calls except contract violations.

### Testing standards

- GUT 9.7.1, `tests/unit/`, `extends GutTest`, functions prefixed `test_`; `.gutconfig.json` runs everything under `res://tests/`.
- Exact assertions (`assert_eq`, `assert_eq_deep`); `assert_almost_eq` only for `wpm_exact`.
- Every test must be able to fail: do the mutation checks in Task 4.4. Earlier reviews (1.4, 1.5, 1.9, 2.1, 2.2) all caught tests that passed with or without the code they guarded.
- The suite prints some expected `ERROR`/`WARN` lines from earlier error-path tests; judge by the pass count and exit code plus no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.

### What later stories rely on (keep these stable)

- **2.4 `RunFrame`:** at run end calls `RunResult.create(level_id, int(Time.get_unix_time_from_system()), clamped_elapsed, _session.get_keys_typed(), _session.get_errors(), _session.get_per_key(), _level.get_brains_earned(), bonus, "all", reason)` and sends `Router.go(REPORT_CARD, { "result": result })`. Logs `Log.info(&"run", "ended level=%s reason=%s wpm=%d" % [result.level_id, result.end_reason, result.wpm])` (architecture Logging example uses exactly these field names, so keep them).
- **2.5 HUD:** `StatsCalculator.wpm(keys, elapsed)` once per second after 5 s; `StatsCalculator.format_time` is available for the timer (the HUD timer counts **down**, EXPERIENCE.md stats-column, so the HUD decides whether to show remaining time with `ceil`; `format_time` itself always rounds down).
- **2.8 `PlayerData.record_run(result)`:** appends `result.to_record()`, adds `result.total_brains()`, compares `result.wpm` with `best_wpm[String(result.level_id)]`.
- **2.9 report card:** shows `keys_typed`, `errors`, `wpm`, `accuracy` (+ "%"), `lesson_time()`, `total_brains()` and a "+N bonus" line from `bonus_brains` when it is > 0.
- **Epic 7:** rolling average over the saved whole-number `wpm` values (or `wpm_exact` if re-computed); the GDD compares tiers against the unrounded **average**, not unrounded per-run WPM.

### Previous story intelligence (2.2, 2.1, Epic 1)

- **Test-first** is the project habit: write tests, record the red run (parse errors), then implement. GUT exits 0 on a parse failure, so read the pass count.
- **Commands:** `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `... -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. `--import` is needed after adding new `class_name` scripts.
- **Review lessons:** test edge values explicitly (2.1 added boundary `unicode` values; here: 99.9 %, 1.8 WPM, 59.99 s); isolated mutation checks (2.2 review made them redo a non-isolated one: change **one** thing per mutation); doc comments on every public member (2.2 review patch); contract asserts never called in tests.
- **2.2 deferrals touching this story:** `TypingSession.config` unused "until 2.3 / 6.2": implied spaces are not wired in this story (no word source yet), so update that line to "until 6.2" (Task 5.4). The exhausted-source and re-entrancy notes are unaffected.

### Git intelligence

- One commit per story, message `Story 2.N: <title in lower case>` (e.g. `Story 2.2: judgment session and letter bag`), containing the scripts with their `.uid` files, tests, the story file, `sprint-status.yaml` and `deferred-work.md`. If Smuck asks for a commit: `Story 2.3: stats calculator and run result`.
- 2.2 added three files to `scripts/typing/` and three tests and modified no existing source file; this story adds two scripts and two tests and modifies `game_constants.gd` only.
- No new dependencies: built-in Godot APIs and GUT only.

### Latest tech notes

- No web research needed: this story uses only core GDScript math and string formatting in Godot 4.7.2 (`floori`, `is_finite`, `%` formatting, `JSON.stringify`/`parse_string`), all stable across 4.x. Known behaviour to rely on: `JSON.parse_string` returns all numbers as `float` (handled by `SaveSchema.normalize_numbers`), and `JSON.stringify` writes a whole `float` as `120.0`.

### Project Structure Notes

- Paths follow the architecture directory tree exactly: `scripts/typing/stats_calculator.gd` (`class_name StatsCalculator`, static), `scripts/typing/run_result.gd` (`class_name RunResult`, RefCounted); tests `tests/unit/test_stats_calculator.gd` (named in the architecture) and `tests/unit/test_run_result.gd`.
- Architectural boundary 1: `scripts/typing/` stays pure logic; `typing_input.gd` remains its only node. Architecture rule "Every class in `scripts/typing/` … has a `tests/unit/test_*.gd`" is why `RunResult` gets its own test file.
- No conflicts with the unified structure detected.

### Project Context Rules

No `project-context.md` exists in this repo. The binding rules come from `_bmad-output/game-architecture.md` (Typing Pipeline & Level Contract, Data Persistence, Configuration, Logging, Architectural Boundaries, Naming Conventions) and are summarised above. Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; the Godot MCP server is available but not needed (no scene).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3: Stats Calculator and Run Result] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR7 (stats), FR8 (live WPM, for 2.5), FR9 (per-key), FR13 (quit not recorded), FR22 (history).
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Stats table (lines ~125–134)] — Accuracy, WPM, implied spaces, Lesson Time.
- [Source: _bmad-output/game-architecture.md#Data Persistence] — run-record keys, end reasons as `GameConstants`, 500 cap.
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract] — `RunFrame` builds `RunResult`; `REPORT_CARD` payload `{ "result": RunResult }`.
- [Source: _bmad-output/game-architecture.md#Logging] — `result.level_id`, `result.end_reason`, `result.wpm` field names.
- [Source: _bmad-output/game-architecture.md#Project Structure] — file locations for `stats_calculator.gd`, `run_result.gd`, `test_stats_calculator.gd`.
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/mockups/key-report-card.html] — 142 keys / 9 errors / 14 WPM / 94 % / 2:00 / 45 brains / +10 bonus.
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md#Report card stats, stats-column] — labels, bonus line, countdown timer.
- [Source: tests/fixtures/saves/save_v1_full.json] — run record shape and types.
- [Source: scripts/core/save_schema.gd#normalize_numbers] — "every number in the save is whole by design".
- [Source: _bmad-output/implementation-artifacts/2-2-judgment-session-and-letter-bag.md] — previous story: session getters, house style, review lessons.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline: 268 tests passing at `HEAD` `beb485e` (confirmed in the red run).
- Red run (4.1): both test files written first. GUT reported `Parse Error: Could not find type "RunResult"`, `Identifier "StatsCalculator" not declared` and `Cannot find member "END_REASON_TIMER" in base "GameConstants"`; 26 scripts / 268 passing (the two new scripts did not load; GUT still exited 0).
- Green run: 28 scripts, 297 tests, 297 passing; no `Parse Error`, `Failed to load script`, `SCRIPT ERROR` or `INTEGER_DIVISION` warning (`format_time` uses `floori(whole / 60.0)`).
- Epsilon (4.2): probed in Godot. 7200 × (1/60) sums to 119.99999999999447 s, so 100 keys give 10.0000000000005 WPM: that test passes with or without the epsilon and is kept as a regression guard (not faked). Searched for a real overshoot: 600 × (1/60) = 10.000000000000076 s, 50 keys → 59.9999999999995 WPM, which floors to 59 without the epsilon. Added `test_wpm_epsilon_guards_float_overshoot` for it.
- Mutation checks (4.4), one change at a time, restored and diff-verified after each:
  - (a) `roundi` in `accuracy_percent` → `test_accuracy_perfect_only_without_errors`, `test_accuracy_rounds_down` fail.
  - (b) WPM without `completed_words` → `test_implied_spaces_add_to_wpm`, `test_completed_words_affect_wpm_only` fail.
  - (c) no `.duplicate(true)` in `create` → `test_per_key_is_copied_on_the_way_in` fails.
  - (d) unfloored `duration_s` in `to_record` → `test_record_types`, `test_record_survives_save_round_trip` fail.
  - (e) no epsilon in `wpm` → `test_wpm_epsilon_guards_float_overshoot` fails.
  - (f) no `.duplicate(true)` in `to_record` → `test_per_key_is_copied_on_the_way_out` fails.
- Contract asserts (negative counts in `StatsCalculator`, empty `level_id` / unknown `end_reason` in `RunResult.create`) are not called in tests (debug `assert` would fail the run); covered by review (4.5, 2.7, 3.4).
- Boundary greps (5.2): no `await`, `get_node("/root`, `JavaScriptBridge`, `Time.`, `FileAccess`, `randi(`/`randf(` in the two new scripts (a doc comment ending "Lesson Time." matched `Time.` and was reworded); `FileAccess` only in `scripts/autoloads/save_service.gd`; `typing_input.gd` is still the only node in `scripts/typing/`.
- 5.3: no manual or browser check; nothing builds a `RunResult` until Story 2.4.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `GameConstants`: `END_REASON_TIMER/CAUGHT/ESCAPED` (`StringName`), no quit reason.
- `StatsCalculator` (static, pure): `accuracy_percent`, `wpm_exact`, `wpm` (floor + `_EPSILON` 1e-9), `format_time` (`m:ss`, floor, `"0:00"` for negative/non-finite), `CHARS_PER_WORD = 5`. WPM is one division, so exact cases stay exact. Non-finite seconds give 0 WPM. Negative counts go through `_non_negative` (assert + `Log.error(&"stats")` + 0).
- `RunResult` (RefCounted): typed, documented fields; `create(...)` deep-copies `per_key` and computes `wpm`/`accuracy` through `StatsCalculator`; argument-free `_init` so `RunResult.new()` works; `total_brains()`, `lesson_time()`, `to_record()` with exactly the fixture's 11 keys, all ints / plain Strings, `duration_s` floored (and 0 if non-finite), `per_key` deep-copied out. No `from_record`, no `is_new_best`.
- Decision flagged for Smuck: Accuracy and WPM round **down** (logged in `deferred-work.md`).
- Tests: 15 in `test_stats_calculator.gd`, 14 in `test_run_result.gd` (29 new; suite 268 → 297); story example 100/5/120 s → 95 %, 10 WPM, "2:00" passes, plus the report-card mock 142/9 → 94 %, 14 WPM.
- `deferred-work.md`: new "dev of story-2-3" section; 2.2's `config` note now reads "until Story 6.2".

### File List

- `scripts/core/game_constants.gd` (modified)
- `scripts/typing/stats_calculator.gd` (new)
- `scripts/typing/stats_calculator.gd.uid` (new)
- `scripts/typing/run_result.gd` (new)
- `scripts/typing/run_result.gd.uid` (new)
- `tests/unit/test_stats_calculator.gd` (new)
- `tests/unit/test_stats_calculator.gd.uid` (new)
- `tests/unit/test_run_result.gd` (new)
- `tests/unit/test_run_result.gd.uid` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-3-stats-calculator-and-run-result.md` (this story)

## Change Log

- 2026-10-04: Story 2.3 implemented: end-reason constants, `StatsCalculator`, `RunResult` with run-record export, 29 new tests (suite 268 → 297), mutation-checked. Status → review.
