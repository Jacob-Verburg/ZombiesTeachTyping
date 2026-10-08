---
baseline_commit: bc5c3834a1beda4db73bddf3837cc8bfe346ad43
---

# Story 7.1: Tier Calculator with Hysteresis

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the game to quietly match my typing level and not bounce me down after one bad run,
so that practice always feels just right and never feels like a demotion.

## Acceptance Criteria

1. **Tier numbers live in a config Resource.** A new `TierConfig` Resource (`scripts/resources/tier_config.gd`, `class_name TierConfig`) holds every number the calculator uses; the shipped values are in `data/tier_config.tres`: `tier_floors = [0.0, 8.0, 15.0, 22.0, 30.0]` (tiers 1–5; tier 1's floor is 0), `drop_margin_wpm = 2.0`, `window_runs = 5`, `level_wpm_scale = {}` (per-level weighting, see AC 6), `ignored_levels = [&"test_level", &"test_word_level"]`. Script defaults are neutral (empty / 0), like every other config here. `validate() -> String` returns `""` for the shipped file and a message when floors are not strictly rising from 0, there are fewer than 2 tiers, the margin is negative or not finite, the window is below 1, or a scale is not finite or not above 0, or an ignored id is empty. No tier number appears as a literal in a script. (FR62, architecture Static Game Data)
2. **Rolling average.** A pure `TierCalculator` (`scripts/typing/tier_calculator.gd`, static-only like `StatsCalculator`: no nodes, no autoloads, no clock, no file I/O) has `rolling_average(history: Array, config: TierConfig) -> float`. It walks the history newest-first (array order, which is append order — never sort by `timestamp`), keeps only **completed** records (`end_reason` is `"timer"`, `"caught"` or `"escaped"`; anything else, including a missing or `"quit"` reason, is skipped), skips levels in `ignored_levels` and junk records (not a Dictionary, `wpm` not a finite number ≥ 0), takes up to `window_runs` of them and returns the **unrounded** mean of their stored `wpm` × the level's `level_wpm_scale` (1.0 when absent). With no counted runs it returns `TierCalculator.NO_AVERAGE` (-1.0). It uses the record's stored `wpm`, not a recompute from `keys_typed` / `duration_s` (see Dev Notes). (FR60)
3. **Tier from an average.** `tier_for_wpm(average: float, config) -> int` returns the tier whose range contains the average: the highest tier whose floor ≤ average (tiers are 1-based). 14.5 → 2; 15.0 → 3; 7.99 → 1; 0 → 1; 30 and 95 → 5. A negative / `NO_AVERAGE` / non-finite input returns 1 and is never used to move a placed tier (AC 4). (FR62, FR63)
4. **Hysteresis.** `next_tier(current: int, average: float, config) -> int`:
   - `average` is `NO_AVERAGE` or not finite → `current` unchanged (no data never moves a tier).
   - `current` outside 1..tier count (the save's `tier: 0` = not placed yet, or junk) → `tier_for_wpm(average)`.
   - **Up:** `tier_for_wpm(average) > current` → that tier, as soon as the average reaches the next floor (it can skip tiers on the way up too: 7 → 25 WPM is tier 1 → tier 4).
   - **Down:** only when `average < floor(current) − drop_margin_wpm`; the result is `tier_for_wpm(average)` (can skip tiers). Otherwise hold. Tier 1 never drops.
   - Comparisons use the unrounded average. Tier 3 at 13.0 holds; at 12.99 it drops to tier 2; tier 4 at 7 drops straight to tier 1; tier 2 at 6.5 holds; tier 2 at 5.99 drops to tier 1. (FR63)
5. **Convenience entry point.** `compute_tier(current: int, history: Array, config) -> int` = `next_tier(current, rolling_average(history, config), config)`. This is what Story 7.2's `PlayerData` will call; this story does **not** call it from `PlayerData`, `RunFrame` or any screen, and does not change the save (the profile's `tier` field and `placement_done` flag already exist in v1, untouched here).
6. **Per-level weighting decision (GDD designer note).** Before this story closes, per-level WPM in exported run history is reviewed (Ctrl+Shift+E export → `tools/playtest/summarize_save.py`, which gains a per-level WPM summary), and a `### Per-level weighting review` section in this file records: the data looked at (source, runs per level, per-level mean / median WPM), the decision (no weighting, or a `level_wpm_scale` value with its reason), and who made it (Smuck, Gate A). Any weighting chosen is set in `data/tier_config.tres` and covered by a test. If there is not enough data, the record says so and the decision is Smuck's (default: no weighting, revisit with real kid saves).
7. **Tests.** `tests/unit/test_tier_calculator.gd` (GUT, scripted run histories built in code) passes for: rising (one tier and skipping tiers), holding in the hysteresis band, single drops, multi-tier drops, the boundary examples in AC 3 / AC 4, fewer than 5 runs (1–4 counted runs average only those), more than 5 (only the newest 5 count), quit-run exclusion (and other non-completed / junk records), ignored levels, per-level scale, `NO_AVERAGE` never moving a placed tier, and tier 0 placement. `tests/unit/test_tier_config.gd` loads the shipped `.tres`, checks every value and `validate()` (shipped valid; each broken case returns a message), and checks `ignored_levels` equals the registry's `debug_only` ids. Full suite green; no existing assertion weakened.
8. **No regressions, nothing visible.** No screen, HUD, report card or log shows a tier or average (FR60, NFR10). Run recording, best WPM, unlocks, save load/migrate and every existing test behave as before.

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC 8)
  - [x] 1.1 Count tests at the starting commit (`git grep -c '^func test_' -- tests | …` or the GUT summary; 6.8 ended at **1648/1648**, 86 scripts). Hash the real dev save (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`, sha256) before and after every suite run (the 4.5 / 5.3 / 6.8 real-save trap). This story's new tests never touch `PlayerData` or `SaveService`, so the hash must not move.
- [x] **Task 2: `TierConfig` resource + shipped data** (AC 1)
  - [x] 2.1 `scripts/resources/tier_config.gd`: `class_name TierConfig extends Resource`, `##` header (what it is, where the shipped file is, "defaults are neutral"), fields from AC 1 with `##` docs citing FR62 / FR63 / GDD numbers. Types: `@export var tier_floors: Array[float] = []`, `@export var drop_margin_wpm: float = 0.0`, `@export var window_runs: int = 0`, `@export var level_wpm_scale: Dictionary[StringName, float] = {}`, `@export var ignored_levels: Array[StringName] = []`.
  - [x] 2.2 Helpers on the config (keeps the calculator short): `tier_count() -> int` (= `tier_floors.size()`), `floor_of(tier: int) -> float`, `scale_for(level_id: StringName) -> float` (1.0 when absent).
  - [x] 2.3 `validate() -> String`, first problem wins, plain message (pattern: `ZombieRunConfig.validate()` / `LevelRegistry.validate()`).
  - [x] 2.4 `data/tier_config.tres` with the shipped values (write it by hand in the same text format as `data/economy.tres`; `script_class="TierConfig"`). Open it once headless (`--import`) so Godot doesn't rewrite it later with a diff.
- [x] **Task 3: `TierCalculator`** (AC 2–5)
  - [x] 3.1 `scripts/typing/tier_calculator.gd`: `class_name TierCalculator`, static only, `##` header citing GDD *Adaptive Difficulty* + FR60/62/63, stating it is pure and that 7.2 (`PlayerData`) is its caller. `const NO_AVERAGE: float = -1.0`. The completed end reasons are the `GameConstants.END_REASON_*` values compared as Strings (records store Strings): `String(GameConstants.END_REASON_TIMER)` etc. — no new literals.
  - [x] 3.2 `rolling_average`, `tier_for_wpm`, `next_tier`, `compute_tier` exactly per AC 2–5. A null config: `Log.error(&"tier", …)` and return the safe value (`NO_AVERAGE`, 1, `current`) — no `assert` (debug GUT would trip it; PlayerData's house rule).
  - [x] 3.3 Numbers from JSON: after `SaveSchema.normalize_numbers` a whole `wpm` is `int`, but accept `int` or `float` (`value is int or value is float`), reject bool/String/NaN/inf/negative.
  - [x] 3.4 No logging per call (it will run on every recorded run); at most one `Log.warn(&"tier", …)` per call when junk records were skipped, with a count, never record contents.
- [x] **Task 4: Tests** (AC 7)
  - [x] 4.1 `tests/unit/test_tier_calculator.gd`: `extends GutTest`, `##` doc line. A small helper `_run(level: String, wpm: Variant, end_reason: String = "timer") -> Dictionary` building a record shaped like `RunResult.to_record()`; a code-built `TierConfig` via a `_config()` helper with the GDD numbers (do not load the `.tres` here, so a data tweak can't silently change hysteresis tests; `test_tier_config.gd` checks the file).
  - [x] 4.2 Cases (one `test_` each, names say the rule): average of 1, 3, 5, 7 runs (only newest 5); order = array order even when timestamps are shuffled; unrounded (14 + 15 → 14.5 → tier 2); quit / `""` / missing / unknown end reason skipped; `"caught"` and `"escaped"` counted; ignored level skipped; junk records (String, null, `wpm` "fast", -3, NaN) skipped and a warning asserted with `assert_push_warning` (`Log.warn` calls `push_warning`); scale applied; empty / all-skipped history → `NO_AVERAGE`; `tier_for_wpm` boundary table (0, 7.99, 8, 14.5, 14.99, 15, 21.99, 22, 29.99, 30, 95, -1); rising 1→2, 1→4; holds (tier 3 at 13.0, 14.9; tier 2 at 6.0, 6.5); single drop (tier 3 at 12.99 → 2); multi-tier drop (tier 5 at 10 → 2, tier 4 at 7 → 1); tier 1 at 0 stays 1; `NO_AVERAGE` keeps tiers 1–5; tier 0 / 6 / -1 → `tier_for_wpm`; `compute_tier` end-to-end on a scripted history that rises then dips (bad-day run held) then drops.
  - [x] 4.3 Mutation check (record in Debug Log): flip `<` to `<=` in the drop test, drop the margin, or take the oldest 5 instead of newest — at least one test must fail for each.
  - [x] 4.4 `tests/unit/test_tier_config.gd`: shipped values; `validate()` empty for shipped; each invalid case from AC 1 gives a non-empty message; `ignored_levels` == ids of `LevelRegistry` entries with `debug_only` (load `res://data/levels/level_registry.tres`, as `test_level_registry.gd` does).
- [x] **Task 5: Per-level WPM review tool** (AC 6)
  - [x] 5.1 `tools/playtest/summarize_save.py` (standard library only, LF endings): add a "Per-level WPM" block to the text output and a `per_level` object to `--json`: for each `level_id` with completed runs, the count, mean (1 decimal) and median WPM, plus the newest-5 rolling average the game would compute (all levels together, no weighting) so the review sees it. Extend `selftest()` for the new block. Keep every existing line/field unchanged.
- [x] **Task 6: Gate A — per-level weighting decision with Smuck** (AC 6)
  - [x] 6.1 Run the tool on a **scratchpad copy** of the dev save (never the live path). At story creation (2026-10-08) the dev save held **one** run (zombie_run, 18 WPM, no Horde Rush runs): not enough to compare levels. No kid export exists (5.4 had no kid session).
  - [x] 6.2 Ask Smuck once, with the numbers in hand: (a) play ~3 Zombie Run + ~3 Horde Rush runs on the dev build, export with Ctrl+Shift+E, review the per-level means; (b) decide without data: no weighting now, revisit when a real kid save exists (add a deferred-work line); (c) a weighting from the analysis in Dev Notes. Recommend (a) if Smuck has 15 minutes, else (b).
  - [x] 6.3 Record the outcome under `### Per-level weighting review` (data, decision, Smuck's words). If a scale is chosen, set it in `data/tier_config.tres` and assert it in `test_tier_config.gd`.
- [x] **Task 7: Housekeeping** (AC 8)
  - [x] 7.1 `scripts/typing/stats_calculator.gd` header says "the tier rolling average (Epic 7) all call it" — no longer true (the average uses stored `wpm`). Fix the sentence.
  - [x] 7.2 `deferred-work.md`: strike the 2.3 item "Run record `duration_s` is floored … Use the stored `wpm` …" with `~~…~~ Done in 7.1: TierCalculator averages the stored wpm.`; leave the `letter_pool_or_tier` format items for 7.5. Add a "Deferred from: dev of story 7-1" section for anything new (e.g. a weighting revisit).
  - [x] 7.3 Grep `scripts/` for "Epic 7" / "7.1" in headers and update any that this story makes stale (don't touch ones that belong to 7.2–7.5).
- [x] **Task 8: Verify** (AC 7, 8)
  - [x] 8.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record before/after counts. Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0). Real save hash unchanged.
  - [x] 8.2 `python tools/playtest/summarize_save.py --selftest` passes.

### Review Findings

- [x] [Review][Patch] Add tests for a record with a missing / non-String `level_id` (counts, scale 1.0) and for `window_runs <= 0` (NO_AVERAGE) [tests/unit/test_tier_calculator.gd]
- [x] [Review][Patch] Assert the shipped `ignored_levels` values by name in `test_shipped_values` (AC 7 "checks every value") [tests/unit/test_tier_config.gd]
- [x] [Review][Defer] Runtime never calls `TierConfig.validate()`; a bad or neutral config (window_runs 0, empty floors, unsorted floors, NaN scale) silently no-ops [scripts/typing/tier_calculator.gd:24] — deferred, validate at load in 7.2 where PlayerData loads the config
- [x] [Review][Defer] `StringName` `level_id` / `end_reason` in hand-built records are mishandled; `to_record()` writes Strings so saved data is fine [scripts/typing/tier_calculator.gd:33] — deferred, no current caller builds such records
- [x] [Review][Defer] `TierConfig.floor_of` returns 0.0 for an out-of-range tier [scripts/resources/tier_config.gd] — deferred, only called with range-guarded tiers today

Dismissed as noise (9): Python bool/inf wpm (`as_num` already rejects both), Python window order (rows keep history order), junk warning repeating each call, junk count under-reporting for non-completed runs, hard-coded warning text in tests, multi-tier drop (intended per AC 4), Python constants drifting from the .tres (already deferred in dev), typed-array equality / .tres syntax (Godot 4.7 fine), naming nits.

## Dev Notes

### What this story is / isn't

- **Is:** the pure tier math (rolling average + tier lookup + hysteresis), its config Resource and shipped numbers, exhaustive unit tests, the per-level WPM review tool tweak, and a recorded weighting decision.
- **Isn't:** wiring. Placement, `placement_done`, recomputing the tier in `PlayerData.record_run`, the MVP-save backfill and "the tier never appears" checks are **Story 7.2**. Letter pools / word bands per tier and the `letter_pool_or_tier` string format are **7.5** (and 7.4 for pools). Do not add rows or length bands to `TierConfig` now; 7.4/7.5 may extend this same resource (note that in its header).

### Rules in one place (GDD *Adaptive Difficulty*, FR60–FR63)

| Tier | Range (unrounded avg) | Floor | Drops below |
|---|---|---|---|
| 1 | < 8 | 0 | never |
| 2 | 8 ≤ avg < 15 | 8 | 6 |
| 3 | 15 ≤ avg < 22 | 15 | 13 |
| 4 | 22 ≤ avg < 30 | 22 | 20 |
| 5 | ≥ 30 | 30 | 28 |

- Signal: mean WPM of the most recent 1–5 completed runs across **all** levels; quit runs never count (they are never recorded anyway — `RunFrame._quit_to_menu` skips `record_run` — the filter is belt-and-braces for hand-edited / future saves).
- Up as soon as the average reaches the next floor (skipping allowed). Down only below current floor − 2, landing on the tier whose range contains the average (skipping allowed).
- Worked example (scripted history for `compute_tier`): tier 2 kid; runs 12, 14, 16, 16, 17 → avg 15.0 → tier 3. Next run 9 (bad day) → newest five 14, 16, 16, 17, 9 → 14.4 → holds tier 3 (14.4 ≥ 13). Two more 9s → 16, 17, 9, 9, 9 → 12.0 → < 13 → tier 2.
- The kid never sees the value or the tier (FR60, NFR10: no ranks, no labels). Nothing in this story renders anything.

### Why stored `wpm`, not a recompute

`RunResult.to_record()` floors `duration_s` to whole seconds but computes `wpm` from the unrounded duration, and Horde Rush's `completed_words` (implied spaces) is not saved at all (`scripts/typing/run_result.gd`, deferred-work 2.3 note). Recomputing from the record would differ from what the kid saw and would drop Horde Rush's spaces. The stored whole-number `wpm` is the same number the report card showed; averaging those is unrounded (14 and 15 → 14.5), which is what FR63 means.

### Per-level weighting background (for Gate A)

- GDD note: WPM is not fully comparable across levels — Horde Rush adds +1 per completed word (implied space), Pitchfork Panic includes Shift and punctuation (Epic 8, not shipped).
- Rough size of the Horde Rush effect: with the pre-tier 3–5 letter band (mean ≈ 4 letters), counted characters = keys × (L+1)/L ≈ ×1.25. Pulling the other way, real words are usually typed faster than Zombie Run's random letters. The two may roughly cancel — that's why the GDD asks for data, not a formula.
- `level_wpm_scale` multiplies a level's stored WPM before averaging (e.g. `{&"horde_rush": 0.8}`). Missing = 1.0. Pitchfork Panic gets its own review in Epic 8 (8.7 tuning) once it exists.
- A suggested rule for (a): if the same player's Horde Rush mean is more than ±20 % off their Zombie Run mean over ≥ 3 runs each, set `horde_rush` scale = ZR mean ÷ HR mean (rounded to 0.05); else no weighting. This is a suggestion; Smuck decides.

### Current state of the files you'll touch (read before editing)

- `scripts/typing/stats_calculator.gd`: static, pure; header claims the tier average calls it (Task 7.1). Model for `TierCalculator`'s style: `##` header, constants with reasons, `_non_negative`-style guards that `Log.error` instead of crashing.
- `scripts/core/game_constants.gd`: `END_REASON_TIMER/CAUGHT/ESCAPED` StringNames; `RUN_HISTORY_CAP = 500`; "balancing numbers live in data/ Resources, not here" — tier numbers go in `TierConfig`, not here.
- `scripts/core/save_schema.gd`: profile defaults already have `"tier": 0` and `flags.placement_done: false`; `normalize_numbers` turns whole floats into ints. **Do not change** (no schema bump in Epic 7: "New save fields go inside the profile…", and these already exist).
- `scripts/autoloads/player_data.gd`: `record_run` appends `result.to_record()` to `run_history` (newest last, capped at 500). **Do not change** in 7.1.
- `tools/playtest/summarize_save.py`: std-lib, has `--json` and a `selftest()`; per-run rows + medians today.
- `data/economy.tres` / `scripts/resources/economy_config.gd`: the minimal config-Resource pattern to copy.

### Must preserve

- Every existing test and the 1648 baseline (plus your new ones).
- `run_history` format, `best_wpm`, unlocks, schema v2 and migrations: untouched.
- The real dev save must not be written by any test (hash it).

### Architecture compliance

- Pure logic under `scripts/typing/` (next to `StatsCalculator`, which the architecture tree already pairs with "tier rolling average"); Resource class under `scripts/resources/`; data under `data/`. Every class in `scripts/typing/` has a `tests/unit/test_*.gd` (architecture Testing).
- "No GDD gameplay number appears as a literal in a script" — floors, margin, window, scales, ignored ids all in `tier_config.tres`.
- Static typing everywhere (`untyped_declaration = Error` in project settings), `##` docs on public members, StringName ids in the API, Strings in saved records.
- Error handling: return safe values + `Log.error`/`Log.warn`; no `assert` in reachable paths; never crash on junk save data (the 6.8 review lesson: guard nulls before acting).
- Logging: `[LEVEL][tag]` via `Log`, tag `&"tier"`; no per-record logs; never log save contents.

### Library / framework

Godot **4.7.2**, GDScript only, GUT **9.7.1** (architecture D9). Typed exported dictionaries (`Dictionary[StringName, float]`) are supported (Godot ≥ 4.4) and already used in the codebase (`router.gd`, `audio_manager.gd`). Nothing new to install; no web research needed (no new APIs). Python for the tool: standard library only.

### File list (expected)

NEW: `scripts/resources/tier_config.gd` (+ `.uid`), `data/tier_config.tres`, `scripts/typing/tier_calculator.gd` (+ `.uid`), `tests/unit/test_tier_calculator.gd` (+ `.uid`), `tests/unit/test_tier_config.gd` (+ `.uid`).
UPDATE: `tools/playtest/summarize_save.py`, `scripts/typing/stats_calculator.gd` (header only), `_bmad-output/implementation-artifacts/deferred-work.md`, this story file.

### Testing standards

GUT 9.7.1 under `tests/unit`; `extends GutTest`; a `##` file doc line saying what's covered; build configs and histories in code; no autoloads, no SaveService, no files except loading the shipped `.tres` / registry. Assert any pushed warnings/errors you trigger (`assert_push_warning` / `assert_push_error`, see how `test_save_schema.gd` does it). `assert_eq_deep` takes no message in GUT 9.7.1 (6.8). Float compares: `assert_almost_eq(avg, 14.5, 1e-9)`. Never weaken an existing assertion.

### Previous story intelligence (6.8 and earlier)

- Code reviews in Epic 6 kept catching: stale doc headers, tests that couldn't fail (hence the mutation check, Task 4.3), live autoloads leaking into tests (6.8 wrote the real save through `test_screen_flow.gd` — hash the save), and tasks ticked `[x]` that weren't done (mark skipped steps "skipped: reason").
- 6.8 froze literals inside `SaveSchema` and guarded them with a test against the registry; same idea here for `ignored_levels` vs the registry's `debug_only` ids.
- Debug "jump to level" runs that reach 0:00 (or F6) write real `timer` records into the dev save; `test_level` / `test_word_level` records would skew the average, hence `ignored_levels`. A debug Horde Rush run is a real Horde Rush record and does count (fine).
- Horde Rush is 3:00 since 6.7 (playtest feedback); Zombie Run 2:00. Duration does not matter for the average (one run = one sample).
- Story 6.1 `WordTagger` already holds the row strings 7.5 will use; nothing to do with them here.

### Git intelligence

Recent: `bc5c383 Story 6.8: level unlocks, code review patches applied, done`, `9866c54 Story 6.7 …`, `bccbf75 / c41cafa Story 6.6 …`. Pattern: one implementation commit (`Story 7.1: tier calculator with hysteresis`) then a "code review patches applied, done" commit, both with the Co-Authored-By trailer.

### Project Structure Notes

- No `project-context.md`; conventions come from `_bmad-output/game-architecture.md` and the code's own headers.
- `TierCalculator` in `scripts/typing/` (architecture tree: pure typing logic, "tier rolling average" is already named next to `StatsCalculator`). An alternative is `scripts/core/` (the epic AC allows either); `typing/` is chosen to sit with the WPM code and its test-coverage rule.
- `data/tier_config.tres` at the `data/` root beside `economy.tres` (a cross-level config, not a level config).

### Per-level weighting review

- **Data looked at (2026-10-08):** a scratchpad copy of the real dev save (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`, never the live path), through `tools/playtest/summarize_save.py`'s new Per-level WPM block. No kid export exists (5.4 had no kid session).
- **Per-level numbers:** `zombie_run`: 1 run, mean 18, median 18 (93 % accuracy). `horde_rush`: 0 runs. Rolling average (newest 5, all levels, no weighting): 18 (1 run). Not enough data to compare levels (the suggested rule needs ≥ 3 runs on each).
- **Decision:** no weighting. `level_wpm_scale` ships empty (`{}`) in `data/tier_config.tres`; `test_tier_config.gd::test_shipped_values` asserts it is empty. Revisit when a real kid save with ≥ 3 runs on each level exists (deferred-work, "Deferred from: dev of story-7-1").
- **Who:** Smuck, Gate A, 2026-10-08 — chose "(b) No weighting now" when offered (a) play & export, (b) no weighting now, (c) a weighting from analysis.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.1: Tier Calculator with Hysteresis] (ACs); #Epic 7 intro ("new save fields go inside the profile"); #Story 7.2 (wiring, placement), #Story 7.5 (tier use); FR60, FR61, FR62, FR63, NFR10
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Adaptive Difficulty] (tier table, hysteresis, boundaries, designer note on per-level WPM)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/decision-log.md] item 1 (5 tiers, rolling avg, 2-WPM hysteresis)
- [Source: _bmad-output/game-architecture.md#Data Persistence] (run record, end reasons, quit runs never recorded, `tier: 0` default); #Static Game Data (config Resources, no literals); #Testing ("tier hysteresis (Epic 7)" must be unit-tested); project tree (`scripts/typing/stats_calculator.gd`)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 2.3 notes (stored wpm vs floored duration; `letter_pool_or_tier` for Epic 7)
- [Source: _bmad-output/implementation-artifacts/6-8-level-unlocks.md] review findings and Debug Log (real-save trap, frozen literals guarded by tests)
- [Source: _bmad-output/implementation-artifacts/5-4-first-kid-playtest.md] (`summarize_save.py`, no kid export exists)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Implementation Plan

- `TierConfig` (Resource, neutral defaults) + `data/tier_config.tres` hand-written in the `economy.tres` format; helpers `tier_count` / `floor_of` / `scale_for` keep the calculator short.
- `TierCalculator` static-only in `scripts/typing/`: `rolling_average` walks the history from the end (array order) and stops once `window_runs` runs counted, so a 500-record history costs at most a few steps past the window; non-completed and ignored-level runs are skipped silently (they are legal), non-Dictionary records and bad `wpm` (non-number, bool, NaN/inf, negative) are "junk" and produce one `Log.warn` with a count. Completed reasons come from `GameConstants.END_REASON_*` as Strings.
- `next_tier` order: no average (NO_AVERAGE / negative / non-finite) → keep `current` (so an unplaced `0` stays `0` with no data); `current` outside 1..count → `tier_for_wpm`; up → target; down only when `avg < floor(current) − margin` → target; else hold. Tier 1's floor is 0 and averages are ≥ 0, so tier 1 can never drop.
- Null config → `Log.error(&"tier", …)` + safe value, no `assert`.

### Debug Log References

- Baseline at `bc5c383`: GUT 1648/1648, 86 scripts, 48510 asserts. Real dev save sha256 `dee4b37b…80919ec` before and after every suite run (unchanged throughout).
- Red phase: with `test_tier_calculator.gd` written before `tier_calculator.gd`, the script hit `Parse Error: Identifier "TierCalculator" not declared` and GUT silently skipped it (suite still "passed" 1661/1661 with only the 13 config tests added) — the known broken-script trap; the final run greps for parse errors.
- Green: 1695/1695, 88 scripts, 48627 asserts, 0 `Parse Error|Compile Error|Failed to load script` lines. The 4 "Villager state can only move forward" assertion lines are pre-existing (same count in the baseline log).
- Mutation check (Task 4.3), each mutant run against `test_tier_calculator.gd` then reverted (diff-checked):
  - M1 drop `<` → `<=`: 1 failing (`test_holds_inside_the_hysteresis_band`, tier 3 at exactly 13.0).
  - M2 margin removed (`avg < floor(current)`): 2 failing (hysteresis band, compute_tier bad-day sequence).
  - M3 oldest-first walk: 3 failing (seven-run window, array-order-not-timestamp, compute_tier sequence).
- `--import` left `data/tier_config.tres` byte-identical (no editor rewrite diff).
- `python tools/playtest/summarize_save.py --selftest`: PASS (all old checks + 9 new per-level / rolling checks).
- Dev save copy summary: 1 zombie_run run, 18 WPM; per-level block printed as expected.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- AC 1: `TierConfig` with neutral defaults, `validate()` (first problem wins) covering <2 tiers, first floor ≠ 0, non-rising / non-finite floors, negative / non-finite margin, window < 1, non-finite / ≤ 0 scale, empty ignored id. Shipped `data/tier_config.tres` = floors 0/8/15/22/30, margin 2, window 5, no scale, ignored `test_level` / `test_word_level`. No tier number is a literal in a script.
- AC 2–5: `TierCalculator.rolling_average / tier_for_wpm / next_tier / compute_tier` exactly per the ACs; `NO_AVERAGE = -1.0`. Not called from `PlayerData`, `RunFrame` or any screen (grep-checked); save format untouched.
- AC 6: `summarize_save.py` gained a `per_level` JSON object and a "Per-level WPM" text block (count, mean, median per level for completed runs + the game's newest-5 rolling average); existing lines/fields unchanged. Gate A decision recorded under *Per-level weighting review*: no weighting (Smuck, option b).
- AC 7: 34 calculator tests + 13 config tests (incl. `ignored_levels` == the registry's `debug_only` ids). Mutation check passed.
- AC 8: nothing renders or logs a tier/average; full suite green with no assertion changed; real save untouched.
- Housekeeping: `StatsCalculator` header no longer claims the tier average calls it; deferred-work 2.3 `duration_s` item struck as done; new "Deferred from: dev of story-7-1" section (weighting revisit, hand-mirrored tool constants). Other "Epic 7" header mentions belong to 7.4/7.5 and were left.

### File List

NEW:
- `scripts/resources/tier_config.gd`
- `scripts/resources/tier_config.gd.uid`
- `data/tier_config.tres`
- `scripts/typing/tier_calculator.gd`
- `scripts/typing/tier_calculator.gd.uid`
- `tests/unit/test_tier_calculator.gd`
- `tests/unit/test_tier_calculator.gd.uid`
- `tests/unit/test_tier_config.gd`
- `tests/unit/test_tier_config.gd.uid`

UPDATED:
- `tools/playtest/summarize_save.py`
- `scripts/typing/stats_calculator.gd` (header only)
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/7-1-tier-calculator-with-hysteresis.md`

## Change Log

- 2026-10-08: Story 7.1 implemented — TierConfig + shipped tier_config.tres, pure TierCalculator (rolling average, tier lookup, hysteresis), 47 new unit tests (1648 → 1695), per-level WPM block in summarize_save.py, Gate A decision (no per-level weighting), housekeeping. Status → review.
