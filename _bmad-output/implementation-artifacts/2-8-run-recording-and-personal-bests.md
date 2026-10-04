---
baseline_commit: 06d94bb0fdc474c6612838df96d7086fdaa8fa10
---

# Story 2.8: Run Recording and Personal Bests

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a parent,
I want every completed run saved with its stats and per-key data,
so that progress can be seen and adaptive difficulty can use it later.

## Acceptance Criteria

1. **Record a run.** Given a completed run's `RunResult`, when `RunFrame` calls `PlayerData.record_run(result)`, then `result.to_record()` is appended to the active profile's `run_history`, the run's brains (`result.total_brains()`: level brains plus bonus) are added to the profile's `brains`, and **one** save is requested (FR22, FR52). `brains_changed(total, delta)` is emitted when the brains are above 0.
2. **History cap.** The history keeps only the newest 500 runs (`GameConstants.RUN_HISTORY_CAP`): the 501st run drops the oldest.
3. **Personal best.** Given a level with a saved best WPM, when a recorded run's WPM is higher, then `best_wpm[level_id]` is updated and `record_run` returns `true` ("new best", FR20). An equal or lower WPM changes nothing and returns `false`.
4. **First run.** The very first run of a level (no best saved yet, i.e. the stored best is 0 or the level has no entry) sets the best but returns `false` (not a new best).
5. **Quit is not recorded.** A quit run (Pause → Quit to Menu) does not call `record_run`; its brains still go through `PlayerData.add_brains()` as in 2.7 (FR13). Unchanged.
6. **Wiring.** `RunFrame._send_result()` calls `record_run(result)` exactly once per run, before navigating to the report card, and hands the "new best" answer to the report card in the payload: `{"result": RunResult, "new_best": bool}`. The report card (Story 2.9) is the one that shows the stamp; this story only delivers the flag.
7. **Tests.** `test_player_data.gd` covers append, the 500 cap (501st drops the oldest), the best-WPM update and the first-run rule; `test_run_frame.gd` covers the wiring and the quit rule. The full GUT suite passes.

## Tasks / Subtasks

- [x] **Task 1: `PlayerData.record_run` (AC: 1–4)**
  - [x] 1.1 `scripts/autoloads/player_data.gd`: add `signal run_recorded(level_id: StringName, new_best: bool)` and `func record_run(result: RunResult) -> bool` (`##`-documented). Steps, in this order, on the live profile (`_profile()`):
    1. Append `result.to_record()` to `run_history`; while `size() > GameConstants.RUN_HISTORY_CAP`, `remove_at(0)`.
    2. Best: `var best: Dictionary = _profile()["best_wpm"]`; `var key: String = String(result.level_id)`; `var previous: int = int(best.get(key, 0))`; `new_best = previous > 0 and result.wpm > previous`; `if result.wpm > previous: best[key] = result.wpm`.
    3. Brains: `var earned: int = result.total_brains()`; if `earned > 0`, add to `_profile()["brains"]` directly (do **not** call `add_brains()`: it would request a second save) and emit `brains_changed(total, earned)`.
    4. Emit `run_recorded(result.level_id, new_best)`, then `save_service.request_save()` **once**, and return `new_best`.
  - [x] 1.2 A `null` result is a contract violation: `Log.error(&"run", ...)`, change nothing, return `false` (no `assert()`, like the other `PlayerData` contract checks).
  - [x] 1.3 Update the file's header comment: `record_run` is no longer "later" (keep the rest of the list). Add a `Log.info(&"run", "recorded level=%s wpm=%d new_best=%s history=%d")` line (once per run, not per frame).

- [x] **Task 2: `RunFrame` wiring (AC: 5, 6)**
  - [x] 2.1 `scripts/run/run_frame.gd` `_send_result()`: after building the `RunResult`, `var new_best: bool = player_data.record_run(result)`; navigate with `{"result": result, "new_best": new_best}`. Update the header comment ("PlayerData.record_run (2.8) … attach here later" → done; the overlay's run fields (2.10) still attach later).
  - [x] 2.2 Do not touch `_quit_to_menu` (it must stay unrecorded) and do not add a second brains commit: `record_run` is now the only place a finished run's brains reach `PlayerData`.
  - [x] 2.3 `scripts/screens/report_card.gd` (the 1.x placeholder) is **not** changed here; it ignores the extra `new_best` key. Story 2.9 reads it.

- [x] **Task 3: Tests (AC: 7)**
  - [x] 3.1 `tests/unit/test_player_data.gd`, using the existing `_make()` (temp `SaveService`): a `_result(level, wpm, brains, bonus)` helper built with `RunResult.create(...)`. Cases: appends one record equal to `to_record()`; brains added (level + bonus) with one `brains_changed(total, delta)`; zero-brain run adds none and emits no `brains_changed`; exactly one save requested per `record_run` (use the same coalescing/`save_requested` check `test_add_brains_requests_one_coalesced_save` uses); 501 runs keep 500 and the first record is gone, the newest is last; first run sets the best and returns `false`; a higher WPM returns `true` and updates; equal and lower WPM return `false` and keep the best; a level with no `best_wpm` entry (`&"horde_rush"`) works as a first run; a first run with WPM 0 stores nothing new and returns `false`; `null` result changes nothing; `run_recorded` is emitted with the answer.
  - [x] 3.2 `tests/integration/test_run_frame.gd`: make `_make()` inject a `_fake_player_data()` by default (a finished run now writes through `record_run`, and no existing run-to-DONE test may touch the real save; tests that already pass their own data keep doing so). New tests: a run that ends records exactly one history entry in the injected `PlayerData` and its brains are added once; the payload carries `new_best` `false` for a first run; with a seeded higher-WPM best removed/lower (set `best_wpm` on the fake profile before the run) the payload carries `true`; Quit to Menu leaves `run_history` empty and still commits its brains once (existing 2.7 test stays green).
  - [x] 3.3 Red run first (tests fail for the missing method), then green; mutation checks, one change at a time with a byte-for-byte restore: drop the cap, `>` → `>=` on the best, `previous > 0` removed, call `add_brains()` instead of the direct add (second save), `record_run` called in `_quit_to_menu`, `new_best` left out of the payload. Record each result honestly in the Debug Log.
  - [x] 3.4 Run the whole GUT suite (baseline from 2.7: 484 passing); no `Parse Error`, `SCRIPT ERROR` or GUT warning.

- [x] **Task 4: Housekeeping**
  - [x] 4.1 `_bmad-output/implementation-artifacts/deferred-work.md`: add a "Deferred from: dev of story-2-8" section for anything left open (see Dev Notes "Known edges").
  - [x] 4.2 Fill in the Dev Agent Record, File List and Change Log; set Status to `review` and update `sprint-status.yaml`.

### Review Findings

- [x] [Review][Patch] Record the run on entering ENDING, not DONE (decision resolved: option 1) — closing/hiding during the outro lost the run, best and level brains; build the `RunResult` and call `record_run` at ENDING, keep result + `new_best`, navigate with them at DONE [scripts/run/run_frame.gd:248]
- [x] [Review][Patch] Non-numeric `best_wpm` value crashes `record_run` mid-way (`int(null)`/`int(Dictionary)` script error after the history append; strings and negatives silently misread) [scripts/autoloads/player_data.gd:63]
- [x] [Review][Patch] History cap trims with `remove_at(0)` in a loop — quadratic on an oversized loaded history; use one `slice` [scripts/autoloads/player_data.gd:58]
- [x] [Review][Patch] Integration test `test_first_run_payload_says_not_a_new_best` finishes at 0 WPM, so it can't fail if `previous > 0` is dropped; end the run with WPM > 0 [tests/integration/test_run_frame.gd:777]
- [x] [Review][Patch] `_start_pausable(data)` builds a throwaway fake PlayerData/SaveService in `_make()` (and clears the shared dir) before overriding it [tests/integration/test_run_frame.gd:476]
- [x] [Review][Patch] Dev Agent Record says 18 new tests / 502 total; the diff adds 16 `test_` functions — re-run GUT and correct the counts [_bmad-output/implementation-artifacts/2-8-run-recording-and-personal-bests.md:139]
- [x] [Review][Patch] Header "contract violations" line doesn't mention the new null-result check [scripts/autoloads/player_data.gd:9]
- [x] [Review][Defer] Report card can show a "new best" that never reached disk (read-only newer-schema save or failed write) [scripts/autoloads/player_data.gd:72] — deferred, pre-existing

## Dev Notes

### What this story is (and isn't)

- It makes finished runs persistent: history, per-level best WPM, and the run's brains. It is a small data-layer story plus one call in `RunFrame`.
- **Updated files:** `scripts/autoloads/player_data.gd`, `scripts/run/run_frame.gd`, `tests/unit/test_player_data.gd`, `tests/integration/test_run_frame.gd`, `deferred-work.md`. **No new files.**
- **Don't build:** the report card or the "New best!" stamp (2.9), level unlocks / `level_unlocked` (FR79, Epic 6; `record_run` gets that rule in Story 6.8), a schema change (`best_wpm` and `run_history` already exist in schema v1), the debug overlay's run fields (2.10), any change to `SaveService`, `SaveSchema`, `RunResult` or the Router.

### Existing code: current state, what changes, what must be preserved

- **`scripts/autoloads/player_data.gd`**: only `add_brains`, `get_setting`/`set_setting`, `reset_all`. Getters read the live profile through `save_service.get_active_profile()` every call (nothing cached). Mutations emit a typed signal and call `save_service.request_save()` (coalesced). Contract violations `Log.error` and change nothing. Keep this style; keep `add_brains` and the settings code untouched.
- **`scripts/core/save_schema.gd`**: profile defaults already hold `"best_wpm": {"zombie_run": 0}` and `"run_history": []`; `fill_defaults` keeps unknown keys, so a new level's key (`horde_rush`) can be added to `best_wpm` at runtime and survives a round trip. Numbers come back as ints (`normalize_numbers`). No change.
- **`scripts/typing/run_result.gd`**: `to_record()` already returns the architecture's run record (ints, String ids, `brains` = `total_brains()`, deep-copied `per_key`); `completed_words` and `bonus_brains` are not saved separately. No change. `RunResult` has no "new best" field on purpose (its fields are write-once, set by `create()`); the flag travels in the payload.
- **`scripts/core/game_constants.gd`**: `RUN_HISTORY_CAP = 500` exists. Use it; no literal 500.
- **`scripts/run/run_frame.gd`**: `_send_result()` builds the `RunResult` and calls `_navigate_when_idle(REPORT_CARD, {"result": result})`; it runs once, on entering `DONE`. `_quit_to_menu()` commits `_level.get_brains_earned()` through `player_data.add_brains()` and records nothing (2.7). `player_data` is a seam (autoload by default, a temp-save instance in tests). Today a **finished** run's brains reach no `PlayerData` call at all (only a quit commits them): `record_run` fixes that, and that is a requirement even though the AC only says "the level's brains are added".
- **`tests/integration/test_run_frame.gd`**: `_make()` currently does **not** inject `player_data`, so every existing test that runs to `DONE` would now hit the real autoload and **write the player's real save** once `record_run` is wired. Injecting `_fake_player_data()` in `_make()` is mandatory, not optional (Task 3.2). `_fake_player_data()` lives lower in the same file; calling it from `_make()` is fine (GDScript resolves methods at call time). Existing tests that pass their own data override the default.

### Design decisions in this story (flag to Smuck in the completion summary)

1. **The "new best" flag goes in the REPORT_CARD payload** (`"new_best": bool`), not on `RunResult`. Story 2.9's AC says "Given the run was a new best"; it reads `payload.get("new_best", false)`.
2. **"First run of a level" means "no positive best stored yet"** (`previous == 0`), not "no history entry": the history is capped at 500 and would forget a level's first run. Edge: if the very first run scores 0 WPM, the best stays 0 and the next run with WPM > 0 is again treated as "first" (sets the best, no stamp). Acceptable for a 6-year-old's first run; note it in `deferred-work.md`.
3. **Brains: `record_run` adds `result.total_brains()`** (level brains + bonus), the same number `to_record()["brains"]` saves, so history and wallet always agree. In the MVP the bonus is 0 until Epic 3.
4. **One save request per run**, by adding the brains inline instead of calling `add_brains()`. (The save requests are coalesced anyway; the single call keeps the AC literal and testable.)
5. **Every end reason is recorded** (`timer`, `caught`, `escaped`): all are completed runs. Only Quit skips recording.

### Known edges (record in deferred-work.md if you leave them)

- `record_run` does not validate `result` fields beyond `null`; a `RunResult` already guards its own label problems in `create()`.
- Unlock rule (FR79) and `level_unlocked` are not part of `record_run` yet (Story 6.8).
- Hand-edited or corrupt saves: `run_history` or `best_wpm` of the wrong type are already replaced by `fill_defaults`; a non-int value inside `best_wpm` would be read through `int(...)`.

### Testing approach

- Same pattern as 2.1–2.7: `PlayerData` on a temp `SaveService` (`TEST_DIR`), never the real autoload's save; `_fake_player_data()` in the run-frame tests; `navigate` recorder keeps the Router out; `pause_tree` recorder keeps GUT's tree running.
- Read results back through the live profile (`data.get_brains()`, `_save.get_active_profile()["run_history"]`), not through signals alone.
- Every test must be able to fail (Task 3.3); record each mutation result honestly, including ones that survive.
- GUT trap: a preload constant named `Test…` is treated as an inner test class. Tests that call `_unhandled_input()` by hand need the `after_each` input-handled reset already in `test_run_frame.gd`.

### Coding conventions

- Static typing everywhere (`untyped_declaration = Error`), including lambda parameters.
- `##` docs on every public member; signal and method names as in the architecture (`record_run`, typed signals); logging via `Log.info(&"run", ...)` once per run, nothing per frame.
- No `assert()` for contract violations in `PlayerData`; `Log.error` and return.

### Project Structure Notes

- Matches the architecture: `PlayerData` is the single writer of profile fields ("All mutations go through its methods … `record_run()`"); `RunFrame` calls it once at run end.
- No conflicts, no new dependencies.

### Previous story intelligence (2.7, 2.6, 2.3)

- **2.7:** introduced the `player_data` and `pause_tree` seams and `_fake_player_data()`; Quit must stay unrecorded and commit brains once (its tests guard this). `_send_result()` was left as the attach point for 2.8 on purpose.
- **2.3:** `RunResult.to_record()` and `create()` are final; the per-key shape is `char -> [attempts, errors, {typed: count}]`, already JSON-safe through `normalize_numbers`.
- **Review habits from 2.4–2.7:** state that outlives its trigger needs an explicit test; mutation checks with byte-for-byte restore; honest reporting of surviving mutants.

### Git intelligence

- One commit per story; latest `cc90031 Story 2.6: green zombie hands finger guide`. Story 2.7's work is still uncommitted in the working tree (its files are modified: `run_frame.gd`, `run_frame.tscn`, `typing_input.gd`, `game_constants.gd`, tests). Build 2.8 on top of it; do not revert or commit it unasked. Suggested message if asked: `Story 2.8: run recording and personal bests`.

### Latest tech notes (Godot 4.7.2)

- `Array.remove_at(0)` on 500 elements is trivial; no ring buffer needed.
- `Dictionary.get(key, default)` for the missing-level case; JSON numbers load as floats and `SaveSchema.normalize_numbers` turns them into ints before `PlayerData` reads them.
- No new engine APIs. Godot binary: `/c/Program Files/Godot/Godot.exe` (GUT run as in the earlier stories).

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md` (Data Persistence: run record and 500 cap; PlayerData ownership and mutation rules; Communication Patterns: call down, signal up; Game constants).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.8: Run Recording and Personal Bests] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR13, FR20, FR22, FR52.
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.9: Chalkboard Report Card] — consumer of the `new_best` flag.
- [Source: _bmad-output/game-architecture.md#Data Persistence] — run record shape, 500-run cap, quit not recorded; `PlayerData` mutation rules (line ~175).
- [Source: scripts/autoloads/player_data.gd], [scripts/typing/run_result.gd], [scripts/core/save_schema.gd], [scripts/run/run_frame.gd] — current state described above.
- [Source: _bmad-output/implementation-artifacts/2-7-pause-focus-loss-and-resume-countdown.md] — seams, Quit rules, test habits.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5.5

### Debug Log References

- Red run: 15 new tests failed (`record_run` missing); green after implementation: 502/502 (baseline 486 + 16 new; the 484 baseline quoted from 2.7 was off by 2, corrected in review). No Parse Error / SCRIPT ERROR; the only WARN lines are the deliberate ones from existing audio/hands tests.
- One of my own tests first failed: the new-best run-frame test ended on the 120 s timer with 4 keys (WPM 0). Fixed by ending that run at 3 s through `end_requested(caught)`.
- Mutation checks (one change each, byte-for-byte restore, diff size unchanged afterwards), all killed: drop the cap; `>` to `>=` on best; remove `previous > 0`; `add_brains()` instead of the inline add (second save); `record_run` inside `_quit_to_menu`; `new_best` left out of the payload.
- `SaveService` has no `save_requested` signal, so the "exactly one save request" test uses a `CountingSave` subclass counting `request_save()` calls.

### Completion Notes List

- `PlayerData.record_run(result) -> bool` and `run_recorded(level_id, new_best)`: append record, 500 cap, best WPM (first run sets it and returns false), brains added inline (level + bonus, one `brains_changed`), one save request, `null` logs and returns false.
- `RunFrame._send_result()` calls `record_run` once and navigates with `{"result", "new_best"}`; `_quit_to_menu` untouched (still unrecorded, brains once).
- `test_run_frame.gd` `_make()` now injects a fake `PlayerData` by default, so no run-to-DONE test touches the real save.
- Design decisions for Smuck: flag travels in the payload not on `RunResult`; "first run" means no positive stored best; every end reason is recorded, only Quit is not. Edges logged in `deferred-work.md`.

### File List

- scripts/autoloads/player_data.gd (modified)
- scripts/run/run_frame.gd (modified)
- scripts/run/level_base.gd (modified, code review: call-order comment)
- tests/unit/test_player_data.gd (modified)
- tests/integration/test_run_frame.gd (modified)
- _bmad-output/implementation-artifacts/deferred-work.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/2-8-run-recording-and-personal-bests.md (this file)

## Change Log

- 2026-10-04: Story 2.8 created.
- 2026-10-04: Story 2.8 implemented: `PlayerData.record_run`, RunFrame wiring with the `new_best` payload flag, 16 new tests; status review.
- 2026-10-04: Code review: 7 patches applied (record on entering ENDING instead of DONE, `best_wpm` type guard, single-slice history trim, stronger first-run test, `_make(data)` seam, counts corrected, header); 3 new tests, GUT 505/505; status done.
