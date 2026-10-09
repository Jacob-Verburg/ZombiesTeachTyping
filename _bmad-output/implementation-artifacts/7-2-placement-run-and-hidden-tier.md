---
baseline_commit: 35be6d9a69d338dd1d4293f440ad1b17ef79ad23
---

# Story 7.2: Placement Run and Hidden Tier

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a new player,
I want my first Zombie Run to find my level without any test or menu,
so that I start at the right difficulty without being labelled.

## Acceptance Criteria

1. **Placement config lives in `TierConfig`.** `TierConfig` gains `@export var placement_level: StringName = &""` (neutral default); `data/tier_config.tres` ships `placement_level = &"zombie_run"`. `validate()` also returns a message when `placement_level` is empty or is in `ignored_levels`. No `"zombie_run"` literal is added to `PlayerData` for this. `test_tier_config.gd` asserts the shipped value, the two new invalid cases, and that the registry has a non-`debug_only` entry with that id. (GDD *Adaptive Difficulty*, FR61, architecture Static Game Data)
2. **PlayerData owns the tier, and validates its config.** `PlayerData` gets a `tier_config: TierConfig` test seam (null = the shipped `data/tier_config.tres`, `preload`ed like `CATALOGUE`). In `_ready`, only for the shipped file, `validate()` is called and a problem is `Log.error(&"tier", …)`'d (closes the 7.1 review deferral). When the config in use is invalid, every tier path below changes nothing (tier and flag stay as they are) and logs one error per call site — never a crash, never a garbage tier.
3. **Placement on the first completed Zombie Run.** In `PlayerData.record_run(result)`, after the record is appended: when `placement_done` is false and `result.level_id == tier_config.placement_level` (end reason is any completed reason; `record_run` is only ever called for completed runs), the profile's `tier` is set to `TierCalculator.tier_for_wpm(result.wpm × scale_for(placement_level))` — **that run's WPM alone**, not an average with older runs — and `flags.placement_done` is set to `true`. Both are written inline (not through `set_flag`) so `record_run` still makes exactly **one** `request_save()`; `flags_changed(&"placement_done", true)` is emitted. (FR61)
   - The placement run itself already uses all 26 letters: `data/levels/zombie_run.tres` `letter_pool` is a..z and nothing in this story changes that. A test asserts the shipped Zombie Run pool is exactly the 26 lowercase letters, so 7.5 can't silently break placement (7.5 must keep a..z while `placement_done` is false).
   - Before placement, a recorded run of **any other level** (e.g. Horde Rush after the debug "Unlock all", or a debug test level) leaves `tier` at 0 and `placement_done` false.
4. **Quit placement runs don't count.** A Zombie Run quit through the pause panel never reaches `record_run` (`RunFrame._quit_to_menu`), so `tier` stays 0 and `placement_done` stays false; a test proves it through `RunFrame` with an injected `PlayerData` (pattern: `test_level_unlocks.gd::test_quitting_a_run_never_unlocks`). (FR61, FR13)
5. **Every later completed run recomputes the tier.** When `placement_done` is true at the start of `record_run`, the tier becomes `TierCalculator.compute_tier(current_tier, run_history, tier_config)` after the append (rolling 1–5 average, hysteresis, ignored levels, all in 7.1). The same single save request covers it. Nothing is emitted for a tier change (no listener needs it; 7.5 reads the tier at run start). (FR60, FR62, FR63)
6. **Read access for 7.5, nothing else.** `PlayerData.get_tier() -> int` returns the stored tier when it is an int in 1..`tier_count()`, else 0 (= not placed yet). `get_flag(&"placement_done")` already exists. No other new public API.
7. **Load-time reconcile for MVP and odd saves (no schema bump).** `PlayerData` runs `_reconcile_tier()` once in `_ready` (after the seams are set) and again on `profile_replaced`-style replacement paths it owns (`reset_all`). It enforces **`placement_done == true` ⇔ `tier` in 1..tier count**:
   - `placement_done` false and `TierCalculator.rolling_average(history)` is not `NO_AVERAGE` (the MVP-save case: completed, non-ignored runs exist) → `tier = tier_for_wpm(average)`, `placement_done = true`.
   - `placement_done` false and no counted runs → set `tier` to 0 if it isn't (a hand-edited stray tier), nothing else.
   - `placement_done` true and `tier` outside 1..count (hand edit) → `tier = tier_for_wpm(average)` when there is an average, else `tier = 0` and `placement_done = false` (the next Zombie Run places again).
   - Otherwise nothing changes. When something changed: one `request_save()` and a `Log.info(&"tier", "reconciled placement")` line **without** the tier or the average. When nothing changed: no save request (existing `CountingSave` tests must not see an extra request).
   - `CURRENT_SCHEMA` stays 2; `SaveSchema` is not edited (the fields exist since v1). (FR51, Epic 7 intro)
8. **The tier is never shown.** No screen, HUD, report card, menu, closet, toast, debug overlay label or log line shows the tier number or the rolling average. `Log` lines for tier work say what happened ("placed", "reconciled placement") but never the value. `test_plain_words.gd`'s `RANKS` pattern gains `\btier` (with a positive self-check like the existing "Rank 3" ones) so tier copy can't ship. The offline dev tool `tools/playtest/summarize_save.py` (not in the game) may print `tier` and `placement_done` on its Flags line — that is how a dev checks this story by hand. (FR60, NFR10)
9. **Tests.** `tests/unit/test_placement.gd` (new, GUT, fresh `SaveService` on a temp `save_dir` + fresh `PlayerData` per test, code-built `TierConfig`) covers: first completed Zombie Run places (e.g. 6 WPM → 1, 12 → 2, 18 → 3, 40 → 5) and sets the flag with one save request; a non-placement level before placement changes nothing; ignored debug levels never place; the second and later runs use `compute_tier` (rise, hold in the band, drop) — the placement run counts in the window; reconcile cases from AC 7 (MVP save with history → placed from the average; MVP save with only `test_level` runs → not placed; `placement_done` true + tier 0 + history → recomputed; `placement_done` true + tier 0 + no history → unplaced; consistent saves → no save request); an invalid injected config → nothing changes and `assert_push_error`; `get_tier()` for 0 / junk / in-range; reload survives (`save_now`, new `SaveService` + `PlayerData` on the same dir → same tier and flag). Plus the RunFrame quit test (AC 4), the zombie_run pool test (AC 3), the `TierConfig` additions (AC 1) and the `RANKS` change (AC 8). Full suite green; no existing assertion weakened.
10. **No regressions.** Run recording, best WPM, brains, unlocks (6.8), save load / migrate / backfill, the debug overlay and every existing test behave as before. The real dev save is never written by a test (hash it).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC 10)
  - [x] 1.1 GUT count at the starting commit (7.1 ended at 1695 + its 2 review-patch tests; read the real number from the GUT summary). sha256 the real dev save (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`) before and after every suite run. Note: this story's `_reconcile_tier()` runs in the **live** `PlayerData._ready` too — running the game (not tests) on the dev save may legitimately place it (it holds one 18 WPM Zombie Run → tier 3). Tests must still never move the hash.
- [x] **Task 2: `TierConfig.placement_level`** (AC 1)
  - [x] 2.1 Add the field with a `##` doc (FR61: "the level whose first completed run places a new save"), keep defaults neutral; extend `validate()` (empty → message; in `ignored_levels` → message). Update the class header line "Stories 7.4 / 7.5 may extend…" to mention 7.2's placement field.
  - [x] 2.2 `data/tier_config.tres`: add `placement_level = &"zombie_run"` by hand (same text format), then `--import` once and confirm the file is byte-identical afterwards.
  - [x] 2.3 `tests/unit/test_tier_config.gd`: shipped value; the two invalid cases; the registry has a non-`debug_only` entry with id `placement_level` (load `res://data/levels/level_registry.tres` as the existing ignored-levels test does).
- [x] **Task 3: `PlayerData` wiring** (AC 2, 3, 5, 6, 7)
  - [x] 3.1 `const TIER_CONFIG: TierConfig = preload("res://data/tier_config.tres")`; `var tier_config: TierConfig = null` test seam with a `##` doc in the same style as `catalogue`. In `_ready`: default it, validate the shipped one only (log on problem), then `_reconcile_tier()`.
  - [x] 3.2 `_tier_config_ok() -> bool`: false (with `Log.error(&"tier", …)`) when null or `validate()` is non-empty. Cache nothing about the profile (the class rule: every read goes through `_profile()`).
  - [x] 3.3 `record_run`: after the history append/slice and before `run_recorded` is emitted, call `_update_tier(result, profile, history)`. Inline writes to `profile["tier"]` and `profile["flags"]["placement_done"]`; emit `flags_changed(&"placement_done", true)` only on placement. Keep the single `save_service.request_save()` at the end. Do **not** add the tier to the existing `Log.info(&"run", "recorded …")` line; a separate `Log.info(&"tier", "placed")` on placement is fine.
  - [x] 3.4 `get_tier() -> int` per AC 6 (`int` check: `value is int`; after `normalize_numbers` a whole JSON number is int, and `fill_defaults` already replaces a non-int `tier` with 0).
  - [x] 3.5 `_reconcile_tier()` per AC 7, called from `_ready` and at the end of `reset_all()` (after `reset_to_defaults`, before `profile_replaced` is emitted — a fresh profile is already consistent, so this is a no-op today; it is the hook Epic 11's profile switch must also call — say so in the header).
  - [x] 3.6 Update the `PlayerData` `##` header: a "Tier (Story 7.2, FR60–FR63)" paragraph — placement on the first completed `placement_level` run from that run's WPM alone, recompute with `TierCalculator.compute_tier` on every later run, load-time reconcile and its invariant, never shown (FR60), `tier_config` test seam.
- [x] **Task 4: Never shown** (AC 8)
  - [x] 4.1 `tests/unit/test_plain_words.gd`: add `\btier` to `RANKS` and `"Tier 3"` to the positive self-check list. Run it: no shipped copy contains "tier".
  - [x] 4.2 Grep `scripts/` and `scenes/` for any UI text, `%` format or label that could show `get_tier()` / `tier` / the average; there must be none outside `PlayerData`, `TierCalculator`, `TierConfig`.
  - [x] 4.3 `tools/playtest/summarize_save.py`: add `placement_done` and `tier` to the Flags line and the `--json` flags object (standard library only, LF endings); extend `selftest()`. Keep every existing line/field unchanged otherwise.
- [x] **Task 5: Tests** (AC 3, 4, 9)
  - [x] 5.1 `tests/unit/test_placement.gd` per AC 9. Build `RunResult`s with `RunResult.create(...)` (a real end reason, so its debug `assert`s never fire) and set wpm through keys/duration: `wpm = floor(keys/5 / minutes)` — e.g. 120 s and 60 keys → 6 WPM, 180 keys → 18 WPM (check against `StatsCalculator.wpm`). Seed histories for reconcile cases by writing a save file into the temp dir before the `SaveService` is added (pattern: `test_level_unlocks.gd::test_an_old_save_is_backfilled_and_shows_the_moment`) or by editing `_save.get_active_profile()` before `PlayerData` is added. Use the `CountingSave` idea from `test_player_data.gd` for the one-request and no-request assertions. Inject a code-built `TierConfig` (GDD numbers + `placement_level = &"zombie_run"`, `ignored_levels = [&"test_level", &"test_word_level"]`) and a code-built `LevelRegistry` if unlock code needs one (copy `test_player_data.gd`'s setup).
  - [x] 5.2 AC 4 quit test: copy the shape of `test_level_unlocks.gd::test_quitting_a_run_never_unlocks` (`_make_player`, `_start_run`, Esc, `quit_chosen`). That file's `_run_registry()` uses its own level ids, so inject a `TierConfig` whose `placement_level` is the id the run starts (otherwise the test passes for the wrong reason). Assert `tier == 0`, `placement_done == false`, and also the positive twin: the same run ended with `debug_end_run()` / timer → placed.
  - [x] 5.3 AC 3 pool test: `tests/unit/test_zombie_run_config.gd::test_letter_pool_is_a_to_z` (line ~45) already asserts the shipped pool is a..z — don't duplicate it; add a message/comment that this is also the placement guarantee (FR61, 7.5 must keep a..z while `placement_done` is false).
  - [x] 5.4 Mutation check (record in Debug Log): (a) place from `compute_tier` over the whole history instead of the run's own WPM, (b) skip the `placement_level` check, (c) always request a save in `_reconcile_tier` — at least one test must fail for each; revert and diff-check.
- [x] **Task 6: Housekeeping** (AC 10)
  - [x] 6.1 `deferred-work.md`: strike the 7.1 review item "`TierCalculator` never calls `TierConfig.validate()` … Validate (and log) at the load site in Story 7.2." with `~~…~~ Done in 7.2: PlayerData validates the shipped TierConfig in _ready and skips tier work on an invalid config.` Leave the `letter_pool_or_tier` items for 7.5. Add a "Deferred from: dev of story 7-2" section for anything new (e.g. Epic 11's profile switch must call `_reconcile_tier`).
  - [x] 6.2 `scripts/run/run_frame.gd` comment on `LETTER_POOL_ALL` ("Epic 7 replaces it with the tier") — leave the value; change the comment to "Story 7.5 replaces it" if you touch nothing else there. Don't change what the record stores (7.5 decides the format).
- [x] **Task 7: Verify** (AC 9, 10)
  - [x] 7.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record before/after counts. Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0). Real save hash unchanged by tests.
  - [x] 7.2 `python tools/playtest/summarize_save.py --selftest` passes.
  - [x] 7.3 Manual (optional, record what was done): on a **scratch copy** of a fresh save (debug F8 reset on a throwaway profile dir, never the real save unless Smuck agrees), play one Zombie Run, export (Ctrl+Shift+E), run `summarize_save.py` → `placement_done True`, a tier 1–5; confirm the report card and menu show nothing new.

## Dev Notes

### What this story is / isn't

- **Is:** wiring 7.1's pure `TierCalculator` into `PlayerData`: the placement rule, per-run recompute, the MVP-save reconcile at load, a `get_tier()` read for 7.5, and guards that the tier is never shown.
- **Isn't:** changing what Zombie Run or Horde Rush *plays* (letter pools per tier, word bands, `letter_pool_or_tier` format) — that is **7.5**. Word lists/pools are **7.3/7.4**. No schema bump, no new save field (`tier` and `flags.placement_done` exist since v1), no UI.

### The rules (GDD *Adaptive Difficulty*, FR60–FR63, FR61)

- Placement: "a save's very first Zombie Run uses all 26 letters. Its WPM sets the starting tier." → tier = `tier_for_wpm(that run's wpm)`. Not the rolling average over earlier runs: before placement there can be debug/test or (after debug Unlock all) Horde Rush records, and the GDD names the Zombie Run's own WPM.
- After placement: every recorded completed run → `compute_tier(current, history)` (newest 1–5 completed non-ignored runs, unrounded mean, up as soon as a floor is reached, down only below floor − 2, can skip tiers).
- Quit runs are never recorded (`RunFrame._quit_to_menu` only adds brains), so they never place or move the tier. `record_run` only ever sees completed runs.
- Tier numbers come only from `data/tier_config.tres` (floors 0/8/15/22/30, margin 2, window 5, ignored `test_level`/`test_word_level`, and now `placement_level = zombie_run`).
- Worked example: new save, first Zombie Run 12 WPM → tier 2, placed. Second run (Horde Rush) 20 → avg(12, 20) = 16 → tier 3. Third run 9 → avg(12, 20, 9) = 13.67 → holds 3 (≥ 13). Fourth 8 → avg 12.25 → < 13 → tier 2.

### Why reconcile at load (and not a migration)

- Epic 7 intro + AC: "works without a schema migration, because the fields already exist in v1". Migrations are for shape changes; this is a value fix that depends on `TierConfig` (a resource load), which `SaveSchema` (pure, no I/O) must not do.
- MVP saves (and 6.x dev saves) have `tier: 0`, `placement_done: false` and real history. Without reconcile, a player who already did 20 runs would get a "placement" on their next Zombie Run, ignoring their history. With it, they're placed from the rolling average on first load of this build.
- The invariant `placement_done ⇔ tier in 1..count` means 7.5 can ask one question: "placed?" → use `get_tier()`'s rows; "not placed?" → all 26 letters (placement run).
- The Story 6.8 backfill (`migrate_1_to_2`) is a different mechanism (a real v1→v2 step) — don't touch it.

### Current state of the files you'll touch (read before editing)

- `scripts/autoloads/player_data.gd`: the only writer of profile state. `record_run` appends `result.to_record()` (newest last, sliced to `RUN_HISTORY_CAP` 500), updates `best_wpm`, adds brains inline (to keep one save request), unlocks levels on `END_REASON_TIMER`, emits `run_recorded` then `level_unlocked`, then **one** `request_save()`, then logs. Test seams `save_service`, `catalogue`, `level_registry` are assigned before `add_child`; `_ready` defaults them. `set_flag` emits `flags_changed` and requests its own save — don't call it from `record_run` (two saves). `reset_all` → `save_service.reset_to_defaults()` then `profile_replaced`. House rule: no `assert`, `Log.error` + safe value.
- `scripts/typing/tier_calculator.gd` (7.1): `rolling_average(history, config)`, `tier_for_wpm(avg, config)`, `next_tier(current, avg, config)`, `compute_tier(current, history, config)`, `NO_AVERAGE = -1.0`. `next_tier` with `current` outside 1..count returns `tier_for_wpm(avg)`; with no average it returns `current` unchanged. Pure; don't change its behaviour (its tests are the spec). It logs one `Log.warn` per call when junk records were skipped.
- `scripts/resources/tier_config.gd` (7.1): fields, `tier_count()`, `floor_of()`, `scale_for()`, `validate()` (first problem wins). Neutral defaults.
- `scripts/core/save_schema.gd`: defaults `"tier": 0`, `flags.placement_done: false`; `normalize_numbers` makes whole floats ints; `fill_defaults` replaces wrong-typed fields with the default (+ warning). **Do not edit.**
- `scripts/run/run_frame.gd`: `_record_result()` builds the `RunResult` with `LETTER_POOL_ALL` ("all") and calls `player_data.record_run`; `_quit_to_menu` adds brains only. No change needed beyond an optional comment.
- `data/levels/zombie_run.tres`: `letter_pool` = a..z (the placement pool today).
- `tests/unit/test_plain_words.gd`: `RANKS` regex (d) and its self-check list at ~line 287.
- `tools/playtest/summarize_save.py`: Flags line prints `welcome_bonus_claimed` and `tutorial_seen` only; has `--json` and `selftest()`.

### Must preserve

- `record_run`'s single save request, signal order (`run_recorded` → `level_unlocked`), return value and log line.
- Every `CountingSave` assertion in `test_player_data.gd` / `test_level_unlocks.gd`: reconcile must not request a save on a consistent (fresh/default) profile.
- Save format, `CURRENT_SCHEMA = 2`, migrations, 6.8 unlock backfill.
- No `PlayerData` test may load the live autoload's save; always the temp `save_dir`.

### Architecture compliance

- Only `PlayerData` mutates profile state; only `SaveService` touches files (architecture Data Persistence / ADR-2/3).
- No GDD number or level id literal in scripts: floors, margin, window, ignored ids and now `placement_level` are in `tier_config.tres`.
- Static typing everywhere (`untyped_declaration` is an error), `##` docs on public members, StringName ids in the API, Strings in the saved data.
- Logging via `Log` with tag `&"tier"`; never the tier value, the average or save contents (FR60 — the console is reachable in the browser).
- Kid-facing copy: none added. NFR10: no ranks or difficulty labels anywhere.

### Library / framework

Godot **4.7.2**, GDScript, GUT **9.7.1** (architecture D9). No new APIs; no web research needed. `preload` of a small `.tres` in an autoload is fine (the registry is the one thing kept lazy because it references every level scene; `tier_config.tres` references only its script). Python tool: standard library only.

### File list (expected)

NEW: `tests/unit/test_placement.gd` (+ `.uid`).
UPDATE: `scripts/autoloads/player_data.gd`, `scripts/resources/tier_config.gd`, `data/tier_config.tres`, `tests/unit/test_tier_config.gd`, `tests/unit/test_plain_words.gd`, `tests/unit/test_zombie_run_config.gd` (or cite an existing assertion), `tests/unit/test_level_unlocks.gd` (if the quit test goes there), `tools/playtest/summarize_save.py`, `_bmad-output/implementation-artifacts/deferred-work.md`, optionally `scripts/run/run_frame.gd` (comment only), this story file, `sprint-status.yaml`.

### Testing standards

GUT 9.7.1 under `tests/unit`; `extends GutTest`; a `##` file doc line saying what's covered; fresh `SaveService` (temp `save_dir`) + fresh `PlayerData` per test, seams set before `add_child_autofree`; clean the temp dir in `before_each`/`after_each` like `test_player_data.gd`. Assert any warnings/errors you trigger (`assert_push_warning` / `assert_push_error`). `assert_eq_deep` takes no message in 9.7.1. Never weaken an existing assertion. Hash the real save around every run (the 4.5 / 5.3 / 6.8 trap: a test that falls back to the live `PlayerData`/`SaveService` writes the real save).

### Previous story intelligence (7.1 and Epic 6)

- 7.1 built `TierCalculator` / `TierConfig` pure and deferred all wiring here, including "validate the config at the load site" (review deferral) — closed by AC 2.
- 7.1's mutation check caught real gaps; repeat it (Task 5.4). A test file that fails to parse is silently skipped by GUT while the suite still "passes" — always grep the log for parse errors (7.1 hit this in its red phase).
- 6.8: `record_run` gained unlock writes with a single save request and a `CountingSave` test — follow the same inline-write pattern for the tier/flag. 6.8 also learned to guard nulls/junk before acting on hand-edited saves (`_stored_flag`, `_level_unlocks`) — `get_tier()` and reconcile must be equally lenient.
- 7.1 Gate A: no per-level weighting (`level_wpm_scale` empty), so `scale_for(placement_level)` is 1.0 today; still multiply by it so a future weighting applies to placement too.
- The dev save holds one 18 WPM Zombie Run: launching the game after this story reconciles it to tier 3, `placement_done` true. That's expected — note it in the Debug Log if it happens.

### Git intelligence

Recent: `35be6d9 Story 7.1: tier calculator with hysteresis, code review patches applied, done`, `bc5c383 Story 6.8: level unlocks …`. Pattern: one implementation commit (`Story 7.2: placement run and hidden tier`) then "code review patches applied, done", both with the Co-Authored-By trailer.

### Project Structure Notes

- No `project-context.md`; conventions come from `_bmad-output/game-architecture.md` and the code headers.
- New test file `tests/unit/test_placement.gd` (feature-named like `test_level_unlocks.gd`, which also exercises `PlayerData` + `RunFrame` for one feature). Unit-level `PlayerData` placement cases may instead go in `test_player_data.gd`; keep them in one place.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.2: Placement Run and Hidden Tier] (ACs); #Epic 7 intro (fields inside the profile, no Epic 11 migration); #Story 7.5 (what uses the tier); FR51, FR60, FR61, FR62, FR63, NFR10
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Adaptive Difficulty] (placement, tier table, hysteresis); #Save contents (placement-done flag, current tier)
- [Source: _bmad-output/game-architecture.md#Data Persistence] (profile shape, `tier`, `placement_done`, only PlayerData mutates); #Static Game Data (no literals); #Testing (tier hysteresis unit-tested)
- [Source: _bmad-output/implementation-artifacts/7-1-tier-calculator-with-hysteresis.md] (API, review deferrals, per-level weighting decision, mutation-check practice)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 7.1 review item (validate at load site), 2.3/2.4 `letter_pool_or_tier` items (left for 7.5)
- [Source: _bmad-output/implementation-artifacts/6-8-level-unlocks.md] (single save request in `record_run`, CountingSave tests, quit-never-unlocks test, hand-edited save leniency)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (35be6d9): GUT 1697/1697, 88 scripts. Real dev save sha256 `dee4b37b…80919ec`.
- Red: `test_tier_config.gd` failed (unknown `placement_level`) before the field existed.
- First full run with the new `PlayerData`: the **live** autoload's `_reconcile_tier()` placed the real dev save, as the story predicted (one 18 WPM Zombie Run → tier 3). Backed up save.json/save.bak to the session scratchpad first; a JSON diff showed exactly two changes: `flags.placement_done false → true`, `tier 0 → 3`. New hash `8d75be3b…01694e4`, unchanged by every later suite run (tests never wrote it). `summarize_save.py` on it: `placement_done yes · tier 3`.
- Test-side fixes on the first run: GUT 9.7.1 needs `assert_push_error_count(n)` for counts; `reset_to_defaults()` makes its own save request (reset test asserts 1, i.e. the reconcile adds none).
- Mutation check (5.4), each reverted and `cmp`-checked byte-identical: (a) placement via `compute_tier(0, history)` → 1 failing; (b) no `placement_level` check → 2 failing (incl. `test_an_ignored_debug_level_never_places`); (c) reconcile always requests a save → 26 failing (placement reconcile tests + existing `test_player_data.gd` CountingSave tests).
- `data/tier_config.tres` byte-identical after `--import`.
- Final: GUT 1721/1721, 89 scripts, 0 parse/compile errors, exit 0; `summarize_save.py --selftest` PASS.

### Completion Notes List

- `TierConfig.placement_level` (neutral `&""`, shipped `zombie_run`); `validate()` rejects empty or ignored. Tests: shipped value, both invalid cases, non-`debug_only` registry entry. Existing `_valid()` helper sets it (no assertion weakened).
- `PlayerData`: `TIER_CONFIG` preload + `tier_config` seam; shipped config validated in `_ready` (closes the 7.1 review deferral); `_tier_config_ok()` guards every tier path (invalid → nothing changes, one `Log.error` per call site). `record_run` → `_update_tier()` before `run_recorded`: not placed + placement level → `tier_for_wpm(run wpm × scale)`, flag set inline, `flags_changed(placement_done, true)`, `Log.info(&"tier", "placed")`; placed → `compute_tier(get_tier(), history)`. Still one save request. `get_tier()` returns 1..count or 0. `_reconcile_tier()` in `_ready` and `reset_all` enforces `placement_done ⇔ tier in 1..count`, saves and logs "reconciled placement" only when it changed something; it emits no signal (boot / `profile_replaced` make listeners re-read). No log line carries the tier or average.
- Never shown: `RANKS` gains `\btier` + "Tier 3" self-check; grep of scripts/scenes found no UI reading the tier; debug overlay reads no profile fields. `summarize_save.py` Flags line and `--json` flags gain `placement_done` and `tier` (selftest extended).
- `tests/unit/test_placement.gd`: 21 tests (placement per WPM band, caught/escaped, other/ignored levels, level scale, worked GDD example, skip tiers, 7 reconcile cases, invalid config ×2, `get_tier` junk, reload, reset, RunFrame quit vs finish with a config placing on the run's level). Pool guarantee documented on the existing `test_letter_pool_is_a_to_z`.
- 7.3 manual play (optional): not done. Verified instead on the real dev save via the live reconcile + `summarize_save.py` (above). No UI code changed, so nothing new can appear on the report card or menu.
- Deferred (deferred-work.md): Epic 11 profile switch must call `_reconcile_tier()`; a pre-placement non-placement run gets placed by the next load's reconcile (debug-unlock-only path).

### File List

- scripts/autoloads/player_data.gd (modified)
- scripts/resources/tier_config.gd (modified)
- scripts/run/run_frame.gd (modified, comment only)
- data/tier_config.tres (modified)
- tests/unit/test_placement.gd (new)
- tests/unit/test_placement.gd.uid (new)
- tests/unit/test_tier_config.gd (modified)
- tests/unit/test_plain_words.gd (modified)
- tests/unit/test_zombie_run_config.gd (modified)
- tools/playtest/summarize_save.py (modified)
- _bmad-output/implementation-artifacts/deferred-work.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/7-2-placement-run-and-hidden-tier.md (this file)

### Review Findings

- [x] [Review][Patch] Placement ignores `end_reason`: a non-completed result of the placement level places the player, though `TierCalculator` doesn't count that run. Gate placement on a completed reason, and add a test with a non-completed `end_reason` [scripts/autoloads/player_data.gd:369]
- [x] [Review][Patch] A placed save can end with tier 0: when `get_tier()` is 0 (junk tier) and no counted run is in the window, `compute_tier` returns 0 and is written, breaking placed <=> tier 1..N. Keep the old value or call `_reconcile_tier` when the result is below 1 [scripts/autoloads/player_data.gd:367]
- [x] [Review][Patch] `test_an_ignored_debug_level_never_places` only shows that the configured level places. Make it record an ignored level (e.g. `horde_rush` / a debug-only level) under a config that would otherwise place and assert no placement [tests/unit/test_placement.gd]
- [x] [Review][Defer] `_reconcile_tier` still mutates the profile and requests a save on every boot when the save is read-only (newer schema) [scripts/autoloads/player_data.gd:84] — deferred, pre-existing
- [x] [Review][Defer] `flags_changed(placement_done)` fires before `run_recorded`, `level_unlocked` and `request_save`, so a listener sees a half-finished `record_run` [scripts/autoloads/player_data.gd:374] — deferred, pre-existing
- [x] [Review][Defer] `TierConfig.validate()` doesn't check that `placement_level` exists in the registry (only a unit test does), so a typo'd id silently never places [scripts/resources/tier_config.gd] — deferred, pre-existing

## Change Log

- 2026-10-08: Story 7.2 implemented — placement on the first completed Zombie Run, per-run tier recompute, load-time reconcile, `get_tier()`, never-shown guards; 24 new tests (1697 → 1721). Status → review.
