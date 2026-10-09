---
baseline_commit: 1be5377e21fa07694965e0d26ab44c1d0daac331
---

# Story 7.5: Zombie Run and Horde Rush Follow the Tier

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the letters and words I get to match what I'm ready for,
so that I learn one keyboard row at a time.

## Acceptance Criteria

1. **The run hands the tier down; levels never read `PlayerData` (ADR-1, call down).** `RunFrame._start_level` reads `player_data.get_tier()` and `player_data.tier_config` and calls a new `LevelBase.set_tier(tier, config)` on the level **after** it is added under `%LevelHost` and **before** `create_target_source(rng)`. A missing or invalid config (`config == null` or `config.validate() != ""`) is passed as tier 0. `LevelBase` stores both (defaults: tier 0, config null = untiered) and gains `get_pool_label() -> String`, defaulting to `GameConstants.LETTER_POOL_ALL` (`"all"`).
2. **Zombie Run's letters follow the tier (FR64).** With tier 0 (not placed yet, so the placement run, FR61) the pool is `ZombieRunConfig.letter_pool` (all 26), exactly as today. With tier *n* ≥ 1 it is `letter_pool` filtered to the letters of `WordTagger.letters_for_rows(config.row_count_of(n))`, **kept in `letter_pool`'s order**: tier 1 = the 9 home-row letters (`a d f g h j k l s`), tier 2 = home + top (19 letters), tiers 3–5 = all 26. Because tiers 3–5 give the identical array, a seed replays the same letters as before this story. A tiered pool with fewer than 2 letters logs an error and falls back to the full `letter_pool` (NFR16: never stuck, never asserts).
3. **Horde Rush's words follow the tier (FR62).** `LevelConfig` gains `@export var tier_word_pools: JSON` (null = the level is not tiered). `data/levels/horde_rush.tres` points it at `res://data/content/word_pools.json`. With tier *n* ≥ 1 and a non-null `tier_word_pools`, the pool is tier *n*'s words from that file, filtered to `config.word_band_of(n)` (2–4, 3–4, 3–5, 4–6, 5–8; tier 1 widened to 2–4, Smuck, Story 7.3 review 2026-10-08), via a new pure `WordSource.tier_pool_from_json(json, tier, min_len, max_len)`. With tier 0, a null `tier_word_pools`, a zero band, or a tier pool with fewer than 2 words (that last case logs an error), it uses today's fixed band: `word_list` (`words.json`) with `word_min_length..word_max_length` (3–5, FR59). If that is short too, `create_target_source` returns null as today.
4. **The run record stores the pool used (FR51).** `RunFrame._record_result` passes `_level.get_pool_label()` as `letter_pool_or_tier`. Zombie Run and Horde Rush return `"tier_%d" % tier` (`GameConstants.TIER_POOL_FORMAT`) when they actually used a tier pool, and `"all"` when untiered or fallen back. The test levels stay untiered (`"all"`). `RunFrame.LETTER_POOL_ALL` moves to `GameConstants.LETTER_POOL_ALL` (same value).
5. **Nothing about speed or behaviour scales with the tier (FR64).** No tier-dependent code touches `ZombieRunConfig` / `HordeRushConfig` numbers, pacing, the amble/scoot, brain blocks, the conga line, the defender, projectiles, crossing times, size classes (size classes stay by word length, as specified in FR55), bonuses or music. Tests prove it: the same seed at tier 1 and tier 5 gives the same Zombie Run zombie x after the same amble time and the same Horde Rush defender lane positions over the same logic steps with no words typed; neither level mutates its config.
6. **The tier stays hidden (FR60, NFR10).** No screen, HUD text or log line shows the tier, the pool label or the rolling average. `Log` lines added in this story name the level and the problem, never the tier number (e.g. "horde rush: tier pool too small, using the fixed band"). The only place the tier appears is the saved run record (FR51) and the save export.
7. **End-to-end (Epic 7 deliverable).** A new integration test plays two new saves through a real `RunFrame`: a "beginner" (placement Zombie Run at a low WPM, then two more completed runs) and a "fast typist" (high WPM). Afterwards the beginner's Zombie Run deals only home-row letters and its Horde Rush only home-row words of 2–4 letters; the fast typist's Zombie Run deals bottom-row letters too and its Horde Rush only words of 5–8 letters. Their saved run records carry `"all"` for the placement run and `"tier_N"` after it.
8. **Web build loads the pools.** In a real web export, a tiered Horde Rush draws from `word_pools.json` (no "tier pool" error in the console, tier-appropriate words on screen); this closes the 6.1 deferral "verify in a real web export that it loads".
9. **Tests and suite.** Unit tests for `WordSource.tier_pool_from_json` (happy path and malformed data), `LevelBase.set_tier` / `get_pool_label`, Zombie Run's tier pools, Horde Rush's tier pool and fallbacks, the FR64 invariance checks, the HUD fit of the longest tier word, and the RunFrame hand-off. Existing seed-dependent tests (`test_run_frame.gd`, `test_zombie_run_level.gd`, `test_horde_rush_level.gd`, `test_horde_rush_tuning.gd`, `test_debug_overlay.gd`, `test_level_unlocks.gd`, `test_placement.gd`) pass unchanged except the `"all"` constant move. Full suite green, no `Parse Error|Compile Error|Failed to load script` lines.

## Tasks / Subtasks

- [x] **Task 0: Baseline** (AC: 9)
  - [x] 0.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command (*Testing notes*). Record the passing total and script count as the baseline (7.4's dev run was 1749 / 91 scripts before its review patches added tests; use the number you measure).
- [x] **Task 1: Constants and the `LevelBase` tier hand-off** (AC: 1, 4)
  - [x] 1.1 `scripts/core/game_constants.gd`: add `LETTER_POOL_ALL: String = "all"` and `TIER_POOL_FORMAT: String = "tier_%d"` with `##` comments (FR51 run record field; the label is saved, never shown).
  - [x] 1.2 `scripts/run/level_base.gd`: add `var tier: int = 0` and `var tier_config: TierConfig = null` (doc: set by RunFrame, 0/null = untiered; a level never reads `PlayerData`), `func set_tier(p_tier: int, p_config: TierConfig) -> void` and `func get_pool_label() -> String` (default `GameConstants.LETTER_POOL_ALL`). Add a protected helper `func _tier_active() -> bool` returning true only when `tier >= 1 and tier_config != null and tier <= tier_config.tier_count()`. Update the class doc's call-order block: `... -> set_tier(tier, config) -> create_target_source(rng) -> ...`.
  - [x] 1.3 `scripts/run/run_frame.gd`: in `_start_level`, right after `%LevelHost.add_child(level)` and before `create_target_source`, call `level.set_tier(_tier_for_run(), player_data.tier_config)` where `_tier_for_run()` returns 0 when `player_data.tier_config` is null or invalid, else `player_data.get_tier()`. (`get_tier()` already returns 0 when not placed or junk.) Pass null as the config when invalid. Do **not** log the tier.
  - [x] 1.4 `run_frame.gd`: remove `const LETTER_POOL_ALL`; `_record_result` passes `_level.get_pool_label()`. Update the class doc ("Tier (Story 7.5): ...") and remove the "Story 7.5 replaces it" comment.
  - [x] 1.5 Grep for `LETTER_POOL_ALL` and fix any reference (only `run_frame.gd` today; the tests compare the literal `"all"`, which stays valid).
- [x] **Task 2: Zombie Run follows the tier** (AC: 2, 4, 5)
  - [x] 2.1 `scripts/levels/zombie_run/zombie_run_level.gd`: new `func _letter_pool() -> Array[String]`: untiered (`not _tier_active()`) → `_cfg.letter_pool`; tiered → keep the letters of `_cfg.letter_pool` that are in `WordTagger.letters_for_rows(tier_config.row_count_of(tier))`, in `letter_pool` order. Fewer than 2 → `Log.error(&"level", "zombie run: tier letter pool too small, using all letters")` and return `_cfg.letter_pool`. Record whether the tier pool was used in a `_tiered: bool` for the label.
  - [x] 2.2 `create_target_source`: `LetterBagSource.new(child, _letter_pool())` instead of `_cfg.letter_pool`. Keep the RNG order (letters child first, groups second): a seed at tiers 0/3/4/5 must deal exactly the letters it deals today.
  - [x] 2.3 Override `get_pool_label()`: `GameConstants.TIER_POOL_FORMAT % tier` when `_tiered`, else `GameConstants.LETTER_POOL_ALL`.
  - [x] 2.4 Class doc: one short paragraph "Tier (Story 7.5, FR64): ..." stating tier 0 = placement (all 26), the filter, and that nothing else reads the tier. Do not change `ZombieRunConfig` or `zombie_run.tres`.
- [x] **Task 3: `WordSource.tier_pool_from_json`** (AC: 3, 9)
  - [x] 3.1 `scripts/typing/word_source.gd`: `static func tier_pool_from_json(json: JSON, tier: int, min_len: int, max_len: int) -> Array[String]`, reading the 7.4 shape `{"schema": 1, "tiers": [{"tier": n, "words": ["..."], ...}]}`. Same tolerance style as `pool_from_json`: null JSON, non-Dictionary data, missing/non-Array `tiers`, non-Dictionary tier entries, a `tier` that is not a number (JSON numbers load as float: compare `int(value) == tier`), missing/non-Array `words`, non-String words → log once (the first two/three as errors like `pool_from_json`) and skip; a word failing `WordTagger.rejection_reason`, outside `[min_len, max_len]`, or repeated → skipped silently. Returns words in file order (the file is sorted). No tier found → `[]` with one `Log.error`.
  - [x] 3.2 It re-applies the band on purpose: the file is built from the same `TierConfig`, but this makes the runtime rule ("the tier's pool with its band", AC) hold even if the config changes before the tool is re-run. It does **not** re-check rows: `test_word_pools.gd` already proves pool membership with an independent oracle and a stale guard.
  - [x] 3.3 Update the class doc (Story 7.5: tier pools) and keep the class pure (no file access: the JSON resource is injected through `LevelConfig`).
- [x] **Task 4: Horde Rush follows the tier** (AC: 3, 4, 5)
  - [x] 4.1 `scripts/resources/level_config.gd`: `@export var tier_word_pools: JSON` with a `##` doc (Story 7.5: the per-tier pools `word_pools.json`, Story 7.4; null = the level ignores the tier and uses `word_list` with the fixed band). Reword the two "Epic 7 replaces the fixed band" comments on `word_min_length` / `word_max_length` to say the fixed band is the fallback before placement (FR59).
  - [x] 4.2 `data/levels/horde_rush.tres`: add `[ext_resource type="JSON" path="res://data/content/word_pools.json" id="4_pools"]` (bump `load_steps` by 1) and `tier_word_pools = ExtResource("4_pools")`. Keep `word_list`, `word_min_length = 3`, `word_max_length = 5` as the fallback. Do **not** add it to `test_word_level.tres` (debug level stays untiered, it is in `ignored_levels`).
  - [x] 4.3 `scripts/levels/horde_rush/horde_rush_level.gd`: extract `func _word_pool() -> Array[String]` from `create_target_source`: when `_tier_active()`, `_cfg.tier_word_pools != null` and `tier_config.word_band_of(tier) != Vector2i.ZERO`, try `WordSource.tier_pool_from_json(_cfg.tier_word_pools, tier, band.x, band.y)`; 2+ words → use it and set `_tiered = true`; else `Log.error(&"level", "horde rush: tier pool too small, using the fixed band")` and fall through. Fallback: today's `pool_from_json(_cfg.word_list, _cfg.word_min_length, _cfg.word_max_length)`. Keep the existing "< 2 words → null" check and message after it. RNG order unchanged (word child, then lane child), so untiered seeds replay exactly.
  - [x] 4.4 `_reset()` must reset `_tiered` (a level node can run twice in tests). Override `get_pool_label()` as in 2.3.
  - [x] 4.5 Do not touch `HordeRushConfig.validate()` (word_list stays required as the fallback), the size classes, the defender, the sim tool or `horde_rush.tres` numbers.
  - [x] 4.6 Class doc: one short "Tier (Story 7.5, FR62/FR64)" paragraph.
- [x] **Task 5: Tests** (AC: 1–7, 9)
  - [x] 5.1 `tests/unit/test_word_source.gd`: `tier_pool_from_json` — a code-built JSON (`JSON.new()` + `parse(...)`): picks the right tier (float `tier` from JSON), band filter inclusive at both ends, skips duplicates and rejected words, keeps file order; null JSON, non-Dictionary data, no `tiers`, tier missing → `[]`; a malformed tier entry or a non-String word is skipped while the rest still load. One test against the shipped `word_pools.json` (`load(...) as JSON`, assert non-empty first): tier 1 with band 2–4 returns 40 words, all home-row.
  - [x] 5.2 `tests/unit/test_level_base.gd`: defaults (tier 0, null config, label `"all"`); `set_tier` stores both; `_tier_active()` false for 0, for a tier above `tier_count()`, and with a null config.
  - [x] 5.3 `tests/unit/test_zombie_run_level.gd` (or a new `test_zombie_run_tier.gd` if the file is already long): with the shipped `TierConfig` (`preload("res://data/tier_config.tres")`), tier 1 deals only from the 9 home-row letters and over 2 bags (18 targets) deals all 9; tier 2 has 19 letters and none from `zxcvbnm`; tiers 3, 4, 5 and tier 0 deal the **same sequence** as an untiered level for the same seed (seed-stability); labels `"all"` / `"tier_1"`; a code-built config whose row count gives < 2 letters is impossible through `validate()`, so test the fallback by passing a tier above `tier_count()` (untiered) and by a config with `tier_row_counts` hand-set to `[0, …]` without validating (falls back, logs, label `"all"`).
  - [x] 5.4 `tests/unit/test_horde_rush_level.gd` (or new `test_horde_rush_tier.gd`): tier 1 words are all home-row (independent letters `"asdfghjkl"`, not imported from `WordTagger`) with length 2–4; tier 5 words are 5–8; tier 0 deals exactly today's words for the same seed (seed-stability); a config with `tier_word_pools = null` ignores the tier; a `tier_word_pools` JSON with no entry for the tier falls back to the 3–5 band, label `"all"`; labels `"tier_1"` / `"tier_5"`.
  - [x] 5.5 FR64 invariance (AC 5): same seed, tier 1 vs tier 5. Zombie Run: drive the amble the way existing tests do (call `_process(delta)` by hand on a disabled node) and assert the zombie's x is equal after the same time. Horde Rush: start a run, step `_logic_step(dt)` the same number of times without typing, and assert the defender's lane position is equal at every step. Also assert neither level changed any exported value of its config (compare `config` property values before/after, or `config.duplicate()` fields).
  - [x] 5.6 HUD fit (UX: the word sign must stay in the 312 px target area): for each tier pool in the shipped `word_pools.json`, measure the widest word with the HUD target font at `LINE_FONT_SIZE` (as `_layout_target` does) and assert `width + 2 * SIGN_PAD_X <= 312` (the `TargetArea` width, 64→376 in `hud.tscn`). Today the longest is 8 letters; this guards a later list change. Put it in `test_hud.gd` next to the other sign tests.
  - [x] 5.7 `tests/integration/test_run_frame.gd`: a frame whose injected PlayerData is placed at tier 1 (seed its profile: `flags.placement_done = true`, `tier = 1`, as `test_placement.gd`'s seed callable does) deals only home-row letters in Zombie Run and records `letter_pool_or_tier == "tier_1"`; with an unplaced PlayerData it records `"all"` (the existing `assert_eq(result.letter_pool_or_tier, "all")` at line ~206 keeps passing).
  - [x] 5.8 New `tests/integration/test_tier_follow.gd` (AC 7, the Epic 7 end-to-end check). Two fresh `SaveService` dirs under `user://test_tier_follow_*` (never the real save) and two `PlayerData` with the **shipped** `TierConfig` (needs the 7.4 pool arrays; `PlayerData` validates injected configs on every `record_run`, see 7.4's deferral). For each kid: record a placement Zombie Run (beginner 5 WPM, fast 40 WPM) and two more completed runs at the same speed, through `record_run` (RunResult like `test_placement._run`). Then start real `RunFrame`s (all seams recorded, as `test_placement._start_run`) on `zombie_run` and on `horde_rush`, type 30 targets each through `%TypingInput.handle_key`, and collect the targets. Assert: beginner letters ⊆ home row, words ⊆ home-row letters with length 2–4; fast letters include at least one of `zxcvbnm`, words all 5–8 letters; the two kids' sets differ; each save's history shows `"all"` for the placement run and `"tier_1"` / `"tier_5"` for runs started after it (finish one run per level with `debug_end_run()` or the timer).
  - [x] 5.9 `tests/unit/test_run_result.gd` / `test_tier_calculator.gd`: unchanged (they use the literal `"all"`).
- [x] **Task 6: Web check** (AC: 8)
  - [x] 6.1 Build a web debug export as earlier stories did (see 6.7 / 5.3 notes: export preset "Web", serve `build/web`, open it in the browser pane). Use a fresh browser storage state (or the debug overlay's reset, F3 → reset all) so Smuck's real desktop save is untouched; never edit `user://save.json` on the desktop.
  - [x] 6.2 Place the save at tier 1: start Zombie Run, type one or two letters, wait about a minute, end it with F6 (debug end run). Its WPM is near 0, so it places tier 1 and unlocks Horde Rush. Play Zombie Run again: only home-row letters. Start Horde Rush: words are home-row, 2–4 letters. Console: no `tier pool` error and no JSON load error. Screenshot both to `_bmad-output/implementation-artifacts/screenshots/7-5/` (`zombie-run-tier1.png`, `horde-rush-tier1.png`).
  - [x] 6.3 If F6 is not available in that build, record why and use the integration test (5.8) as the proof; do not skip silently.
- [x] **Task 7: Wrap-up** (AC: 9)
  - [x] 7.1 `--import`, full GUT run; record the new total vs the Task 0 baseline and the script count; grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 7.2 Commit new `.uid` files for new test scripts.
  - [x] 7.3 `deferred-work.md`: strike the 6.1 item "When the runtime loader for `words.json` lands, verify in a real web export..." with "Done in 7.5: ..." (or record why not); under the 7.4 code-review deferral about `pool_words`/`pool_report` crashing on malformed entries, note that the runtime reader is `WordSource.tier_pool_from_json`, which skips malformed data (the `WordTagger` functions still see only tool data); strike `RunFrame.LETTER_POOL_ALL` placeholder (~line 159) and "Epic 7 decides the tier string format" (~line 147) with "Done in 7.5: `"tier_N"` (`GameConstants.TIER_POOL_FORMAT`)". Add "Deferred from: dev of story-7-5" for new items only (at least the tuning note below if not done).
  - [x] 7.4 Mark `7-5-zombie-run-and-horde-rush-follow-the-tier: review` in sprint-status when done (dev-story does this).

## Dev Notes

### What this story is (and isn't)

- It is: a tier hand-off from `RunFrame` to the level, tier-filtered letters in Zombie Run, tier pools in Horde Rush (from 7.4's `word_pools.json`), the run-record label, tests including the Epic 7 end-to-end check, and one web check.
- It isn't: any UI (the tier stays hidden), a change to how the tier is computed (`TierCalculator`, `PlayerData._update_tier` / `_reconcile_tier` are done in 7.1/7.2), any change to the word lists or pools (7.3/7.4), Pitchfork Panic or sentences (Epic 8), a save schema change (`tier` and `letter_pool_or_tier` already exist in v1/v2), or tuning changes.

### Design decisions (follow them)

- **Where the tier comes from:** `RunFrame` already holds `player_data` (a test seam that defaults to the autoload) and already reads it (settings, `record_run`). Levels must not read `PlayerData` (architecture *Rules*; "dependencies that aren't autoloads are injected by the owner through a `setup()` method"). So `RunFrame` calls down with `set_tier`. Do not change the `create_target_source(rng)` signature: every level and many tests implement or call it.
- **Use `player_data.tier_config`, not a second preload.** It is the same config that computed the stored tier (shipped `data/tier_config.tres`, or the test's injected one), so the rows/bands always match the tier. `PlayerData` has no getter for it; reading the public `tier_config` var is fine (it is a documented test seam). If you prefer, add a tiny `get_tier_config() -> TierConfig` next to `get_tier()`; either way don't preload the `.tres` in `RunFrame` (architecture: no hard-coded `res://` data paths outside autoload/registry preloads).
- **Tier 0 = untiered = today's behaviour.** Tier 0 means "not placed" (`PlayerData.get_tier()` doc), so Zombie Run's placement run uses all 26 (FR61) and everything that runs without a tier (direct level tests, the capture tool, the debug test levels) is unchanged. Horde Rush is unlocked by a completed Zombie Run (`level_registry.tres`: `unlocked_by = &"zombie_run"`), which is the same run that places the save, so a real kid never meets Horde Rush at tier 0; only the debug "Unlock all" can (7.2 deferral). That path keeps the 6.x fixed 3–5 band from `words.json`, which is why `words.json`, `word_list` and `test_word_list.gd`'s starter guard all stay. This resolves 7.4's forward note "`horde_rush.tres`'s fixed `word_list` / 3–5 band and `test_word_list.gd`'s starter guard need a decision": keep them as the pre-placement fallback.
- **Filter `letter_pool`, don't build from `letters_for_rows`.** `letters_for_rows(3)` is `asdf…qwer…zxcv…` (row order), while `letter_pool` is `a..z`. Filtering `letter_pool` keeps its order, so tiers 3–5 give the identical array and every existing Zombie Run seed (tests, replay pins, capture scripts) deals the same letters. The `.tres` still decides which letters exist at all.
- **Label format:** `"tier_1"`..`"tier_5"` when a tier pool was used, `"all"` otherwise (placement run, test levels, fallbacks). The 2.x deferral asked Epic 7 to decide this ("e.g. `tier_3`"). It is the level's answer because only the level knows whether it fell back.
- **Seed replay (Story 2.10):** a pinned seed replays the same targets only at the same tier. Expected; mention it in the `RunFrame` doc line. Don't add the tier to the overlay (FR60 holds for debug text too unless Smuck asks).
- **Logging and FR60:** `PlayerData`'s doc says "no copy, no label, no log line carries [the tier] or the average". Keep it: new error lines must not include the tier number. The saved record and save export do carry it (FR51 asks for that).

### Existing code to read first

- **`scripts/run/run_frame.gd`** (UPDATE): `_start_level` (level instanced → `%LevelHost.add_child` → `_seed_rng` → `create_target_source(_rng)`); `_record_result` (passes `LETTER_POOL_ALL` today, line ~430); `player_data` seam; the long class doc (add one line, don't rewrite).
- **`scripts/run/level_base.gd`** (UPDATE): the contract and call-order doc block. All defaults are safe no-ops; keep that.
- **`scripts/levels/zombie_run/zombie_run_level.gd`** (UPDATE): `create_target_source` builds `LetterBagSource.new(child, _cfg.letter_pool)` first, then `ZombieRunGroups` with a second child RNG; keep that order. Very long class doc: add a short paragraph only.
- **`scripts/levels/horde_rush/horde_rush_level.gd`** (UPDATE): `create_target_source` (~line 202): validate config, lanes fit, `_reset()`, word child RNG, lane child RNG, `pool_from_json(...)`, `< 2` → null, `WordSource.new`, `HordeField`, `HordeDefender`. `_reset()` (~232) zeroes per-run state.
- **`scripts/typing/word_source.gd`** (UPDATE): `pool_from_json` is the style to copy for `tier_pool_from_json`.
- **`scripts/resources/level_config.gd`** / **`data/levels/horde_rush.tres`** (UPDATE): `word_list` is a JSON `ext_resource`; add `tier_word_pools` the same way.
- **`scripts/resources/tier_config.gd`** (read only): `row_count_of(tier)` → 0 out of range; `word_band_of(tier)` → `Vector2i.ZERO` out of range; `validate()`.
- **`scripts/typing/word_tagger.gd`** (read only): `ROW_HOME/TOP/BOTTOM`, `letters_for_rows(row_count)` (returns "" outside 1–3).
- **`scripts/autoloads/player_data.gd`** (read only unless you add a getter): `get_tier()` (0 when not placed, junk, or no config), `tier_config` seam, `_tier_config_ok()` validates injected configs on every `record_run`.
- **`data/content/word_pools.json`** (read only): `{schema: 1, source, tiers: [{tier, rows, min_length, max_length, words: [...]}]}`, tier counts 40 / 304 / 901 / 951 / 904.
- **`scripts/core/game_constants.gd`** (UPDATE): constants only, `##` doc each.
- **`scripts/run/hud.gd`** (read only): `_layout_target` sizes the sign to the text, centred at `TARGET_CENTRE_X` 156 in the `TargetArea` (x 64–376, width 312) of `scenes/run/hud.tscn`.

### What must keep working (regressions to watch)

- Every RunFrame-based test injects its own `PlayerData` on a temp save (checked: `test_run_frame.gd`, `test_placement.gd`, `test_level_unlocks.gd`, `test_debug_overlay.gd`, `tools/capture_screens_runner.gd`), so they run at tier 0 and stay deterministic. Keep it that way: a new test that used the live `PlayerData` autoload would read the developer's real save (which may be placed) and become machine-dependent.
- Level tests that instance a level directly never call `set_tier` → tier 0 → unchanged words and letters.
- `test_horde_rush_tuning.gd` and `tools/horde_rush_sim.gd` run on the fixed 3–5 band; they are untouched and must stay green.
- `test_word_list.gd` (starter `words.json` guard) and `test_word_pools.gd` stay as they are.
- The test configs passed to `PlayerData` must include `tier_row_counts`, `tier_word_min_length`, `tier_word_max_length` (7.4 deferral). Using the shipped `.tres` avoids this.

### Architecture and rules to follow

- Godot **4.7.2**, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed vars, arrays, returns and loop vars. Tabs. `##` doc comments that say *why*. `UPPER_SNAKE` constants.
- ADR-1 / *Rules*: levels never read input, never touch the clock, never write `PlayerData`. Call down, signal up. Injection by the owner.
- `scripts/typing/` and `scripts/core/` are pure (no autoloads, scenes or tree): `WordSource.tier_pool_from_json` takes the JSON as a parameter.
- Static data via `@export` / registries, no hard-coded `res://` data paths in scripts (that is why the pools come through `LevelConfig.tier_word_pools`).
- NFR16: bad content never asserts or crashes; log and fall back or fail to the menu.
- FR60 / NFR10: the tier is never shown. `test_plain_words.gd`'s rank/tier word check stays green (no new player-facing copy).

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. GUT skips a script that fails to parse and still exits 0: grep for `Parse Error|Compile Error|Failed to load script`.
- Run `--import` after adding test scripts or changing `.tres` ext_resources, or `load()` may return stale data.
- JSON numbers load as float: compare `int(entry["tier"]) == tier`.
- Use independent letter tables in tests (`"asdfghjkl"`, `"qwertyuiop"`, `"zxcvbnm"` written out), not `WordTagger`'s constants (6.1 review lesson).
- Assert a loaded JSON is non-empty before looping over it (6.1 review: vacuous passes).
- For the end-to-end test, a 30-target sample is enough: the tier 1 Zombie Run pool has 9 letters (all appear within 18 targets); the fast typist's 26-letter bag shows a bottom-row letter within any 26 consecutive targets, so type at least 26 Zombie Run targets.

### Previous story intelligence

- **7.4:** `TierConfig` has `row_count_of()` / `word_band_of()` "for 7.5 at runtime"; `word_pools.json` ships in the web build (`include_filter="data/content/*.json"`) but nothing loads it yet; forward note: "verify a real web export loads `word_pools.json` (`load()` vs `FileAccess`)". Loading through an `ext_resource` in a `.tres` is the same path `words.json` uses, which already works in the web build (Horde Rush has been played in web builds since 6.x), but AC 8 checks it explicitly. 7.4's story wrongly said a code-built config "is never validated": `PlayerData._tier_config_ok()` validates injected configs too. Review patch: `validate()` requires bands non-decreasing across tiers.
- **7.2:** `get_tier()` is "the one read (Story 7.5)". Placement happens inside `record_run` of the first completed `zombie_run` run; the next `RunFrame` (Play Again goes through `Router` to a new frame) reads the new tier. A quit placement run doesn't place.
- **7.1:** tier comparisons use the unrounded average; per-level weighting is off (`level_wpm_scale` empty).
- **6.2/6.3:** `WordSource` extends `LetterBagSource` (bag of words, seed-stable); Horde Rush draws words first, lanes second; `create_target_source` may be called on a node that ran before (`_reset()`).
- **6.6:** brute (≥ 6 letters) art and hat fit are done, so tiers 4–5 spawning brutes is safe visually.
- **6.7:** tuning (lane 1.5 s, cooldown 2.4 s, projectile 1.2 s, 3:00, +30) was measured on the 3–5 band. FR64 says the defender never scales, so don't retune; see the tuning note below.
- Edit story files and docs line-anchored; never replace whole sections (5.2 lesson).

### Git intelligence

- One commit per story on `main`, then "(code review patches applied, done)". Latest: `1be5377 Story 7.4: tier word pools and validation, code review patches applied, done`. Use `Story 7.5: zombie run and horde rush follow the tier`.
- Expected changes: `scripts/core/game_constants.gd`, `scripts/run/level_base.gd`, `scripts/run/run_frame.gd`, `scripts/levels/zombie_run/zombie_run_level.gd`, `scripts/levels/horde_rush/horde_rush_level.gd`, `scripts/typing/word_source.gd`, `scripts/resources/level_config.gd`, `data/levels/horde_rush.tres`, tests (`test_word_source.gd`, `test_level_base.gd`, `test_zombie_run_level.gd` or a new tier test, `test_horde_rush_level.gd` or a new tier test, `test_hud.gd`, `test_run_frame.gd`, new `test_tier_follow.gd` + `.uid`), screenshots under `screenshots/7-5/`, `deferred-work.md`, this file, `sprint-status.yaml`. Possibly `player_data.gd` (getter only).
- **Not** expected: `data/tier_config.tres`, `tier_config.gd`, `word_tagger.gd`, `tools/*`, `data/content/*.json`, `zombie_run.tres`, `test_word_level.tres`, `horde_rush_config.gd`, `save_schema.gd`, any screen or HUD script, `project.godot`, `export_presets.cfg`, `.github/`.

### Tuning note (not in scope, record if not checked)

- Tier bands change how many copies a given WPM makes (tier 1: 2–4 letters, mostly small 1-hit copies; tier 5: 5–8 letters, medium and brutes). The 6.7 targets (about 40 % arrivals at 10 WPM, 70 % at 30) were measured on 3–5 words. FR64 forbids scaling the defender, so this story changes nothing; add a deferred item suggesting a `horde_rush_sim.gd` run per tier band (e.g. tier 1 at 6 WPM, tier 5 at 32 WPM) when tuning is next revisited.

### Project Structure Notes

- No new folders except `screenshots/7-5/`. New tests in `tests/unit/` and `tests/integration/` as before.
- No conflicts with the architecture tree. `LevelConfig` gaining a JSON export mirrors `word_list` (6.2).

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md`, the GDD and the UX spines:
  - ADR-1: one typing pipeline; levels implement `LevelBase` only and never read input, the clock or write `PlayerData`.
  - Injection by the owner (`setup()`-style methods or `@export`); static data via Resources; no hard-coded data paths in scripts.
  - Pure `scripts/typing/` and `scripts/core/`.
  - Consistency rules: static typing; tests for every new unit; CI fails on any GUT failure.
  - FR60 / NFR10: no tier, rank or difficulty label anywhere the kid can see.
  - Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1.

### Latest tech information

- No new libraries or engine features. Already proven here on Godot 4.7.2: JSON files as `ext_resource type="JSON"` in a `.tres` (`words.json` in `horde_rush.tres`) load on desktop and web; JSON numbers parse as float; typed `Array[String]` filtering with `String.contains()` / `in`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.5: Zombie Run and Horde Rush Follow the Tier] (ACs)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR51, FR55, FR59, FR60, FR61, FR62, FR64; NFR10, NFR16
- [Source: _bmad-output/game-architecture.md] Typing pipeline / `LevelBase` contract and *Rules*; *Data Persistence* (run record `letter_pool_or_tier`); *Static Game Data*; injection pattern (~line 880); no hard-coded data paths (~line 963)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] *Adaptive Difficulty* tier table
- [Source: _bmad-output/implementation-artifacts/7-4-tier-word-pools-and-validation.md] forward notes for 7.5, pools file shape, review findings
- [Source: _bmad-output/implementation-artifacts/7-2-placement-run-and-hidden-tier.md] placement, `get_tier()`
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 2.x `letter_pool_or_tier` format, `RunFrame.LETTER_POOL_ALL` placeholder, 6.1 web-load check, 7.2 debug-unlock note, 7.4 injected-config validation and malformed-entry notes
- [Source: scripts/run/run_frame.gd], [scripts/run/level_base.gd], [scripts/levels/zombie_run/zombie_run_level.gd], [scripts/levels/horde_rush/horde_rush_level.gd], [scripts/typing/word_source.gd], [scripts/resources/level_config.gd], [scripts/resources/tier_config.gd], [scripts/autoloads/player_data.gd:327-334], [data/levels/horde_rush.tres], [data/levels/level_registry.tres], [scripts/run/hud.gd:180-200], [scenes/run/hud.tscn]

### Review Findings

- [x] [Review][Patch] Pool label can go stale and is duplicated: `_tiered` + `get_pool_label()` live in both levels and read the live `tier`, so a later `set_tier` call would mislabel the run; move the flag/label into `LevelBase` (store the label when the pool is built) and add the missing `##` doc comment [scripts/levels/zombie_run/zombie_run_level.gd:163, scripts/levels/horde_rush/horde_rush_level.gd:237]
- [x] [Review][Patch] Test gaps: no Horde Rush test for tiers 2-4 bands, and no end-to-end Horde Rush test for a null/invalid `TierConfig` falling back to tier 0 [tests/unit/test_horde_rush_tier.gd, tests/integration/test_run_frame.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Task 0 baseline: 1751 passing / 91 scripts, no `Parse Error|Compile Error|Failed to load script` lines (the 3-4 `Villager state can only move forward` assertion lines are pre-existing noise, also in the baseline log).
- `-gtest=` does not narrow the run here (`.gutconfig.json` adds `res://tests/`), so every check ran the full suite.
- First full run with the new tests: 1 failure, `test_a_tier_missing_from_the_pools_falls_back_to_the_fixed_band` (that path logs twice: `WordSource` "no words for the requested tier" and the level's fallback line). Fixed the test to expect both errors.
- Task 7.1 final: 1789 passing / 94 scripts (+38 tests, +3 scripts), 0 failing, 0 parse/compile/load errors.

### Completion Notes List

- **Hand-off (AC 1):** `LevelBase` gained `tier`, `tier_config`, `set_tier()`, `get_pool_label()` (default `"all"`) and `_tier_active()` (tier 1..`tier_count()` with a config). `RunFrame._start_level` calls `level.set_tier(...)` after `%LevelHost.add_child` and before `create_target_source`; `_valid_tier_config()` passes null and tier 0 when `player_data.tier_config` is missing or fails `validate()`. No `PlayerData` getter was added (the public `tier_config` seam is read). Nothing logs the tier.
- **Zombie Run (AC 2):** `_letter_pool()` filters `letter_pool` by `WordTagger.letters_for_rows(row_count_of(tier))` in `letter_pool` order (tier 1 = `a d f g h j k l s`, tier 2 = 19 letters, tiers 3-5 = the identical 26). Under 2 letters logs (no tier number) and falls back. RNG order unchanged; tests prove tiers 0/3/4/5 deal the untiered sequence for 4 seeds.
- **Horde Rush (AC 3):** `LevelConfig.tier_word_pools` (JSON), set in `horde_rush.tres` to `word_pools.json` (`load_steps` 7 -> 8). `_word_pool()` uses `WordSource.tier_pool_from_json` with `word_band_of(tier)`; tier 0 / null pools / zero band / < 2 words fall back to `word_list` 3-5 (the last logs). `_tiered` is reset in `_word_pool()` and `_reset()`. `test_word_level.tres`, `HordeRushConfig`, size classes, defender, sim tool untouched.
- **`WordSource.tier_pool_from_json` (Task 3):** pure, same tolerance as `pool_from_json`: null / non-Dictionary / no `tiers` array -> error and `[]`; malformed tier entries, non-number `tier`, non-Array `words`, non-String words -> skipped with one error line per call; rejected, out-of-band or repeated words skipped silently (a Dictionary set for repeats); no matching tier -> one error. File order kept. Shipped tier 1 with 2-4 gives 40 home-row words.
- **Label (AC 4):** `RunFrame.LETTER_POOL_ALL` removed; `GameConstants.LETTER_POOL_ALL` / `TIER_POOL_FORMAT` added. Records carry `"tier_N"` only when the tier pool was used.
- **FR64 (AC 5):** tests show tier 1 vs 5 give the same Zombie Run zombie x over 30 amble steps and the same Horde Rush defender position at each of 600 logic steps (and throw count), and neither level changes any stored config value (deep snapshot incl. size classes).
- **Hidden tier (AC 6):** new log lines: "zombie run: tier letter pool too small, using all letters", "horde rush: tier pool too small, using the fixed band", and the `WordSource` lines; none carries a tier number. No UI change; `test_plain_words.gd` green.
- **End-to-end (AC 7):** `test_tier_follow.gd`: two fresh saves on the shipped `TierConfig`; beginner (5 WPM) places at tier 1, fast (40 WPM) at tier 5; 30 targets typed per real `RunFrame` (letter by letter through `%TypingInput.handle_key`, clock advanced to the kid's speed, ended with `debug_end_run()`). Beginner: home-row letters, home-row 2-4 words; fast: a bottom-row letter, 5-8 words; histories `["all","all","all","tier_1","tier_1"]` / `[... "tier_5","tier_5"]`.
- **Web check (AC 8):** debug web export served by `web-debug` in the browser pane; reset the pane's own browser save with F8 (the desktop `user://save.json` was not touched). Placement Zombie Run: full alphabet (`o`, `e`, `j`), 1 key then F6 (needs the F3 overlay open) -> tier 1, Horde Rush unlocked (the first-run welcome gift / closet flow came first). Zombie Run again: `l s g a j h d k` only. Horde Rush: `had`, `asks`, `ha`, `sags` (home row, 2-4; `ha` cannot come from the 3-5 fallback, so `word_pools.json` loaded). Console: no errors, no "tier pool" lines. Screenshots in `screenshots/7-5/`. Both test runs were quit to the menu (not recorded).
- **Task 7.2:** the three new test scripts' `.uid` files are generated and listed below, ready for the story commit (nothing committed in dev-story).
- **Task 7.3:** `deferred-work.md`: struck the 2.x tier-format and `LETTER_POOL_ALL` placeholder items and the 6.1 web-load item ("Done in 7.5"), noted the runtime reader under the 7.4 `pool_words`/`pool_report` item, added "Deferred from: dev of story-7-5" (tuning per tier band, replay seed vs tier, pane `type` vs `key`).

### File List

- `scripts/core/game_constants.gd` (modified)
- `scripts/run/level_base.gd` (modified)
- `scripts/run/run_frame.gd` (modified)
- `scripts/levels/zombie_run/zombie_run_level.gd` (modified)
- `scripts/levels/horde_rush/horde_rush_level.gd` (modified)
- `scripts/typing/word_source.gd` (modified)
- `scripts/resources/level_config.gd` (modified)
- `data/levels/horde_rush.tres` (modified)
- `tests/unit/test_word_source.gd` (modified)
- `tests/unit/test_level_base.gd` (modified)
- `tests/unit/test_hud.gd` (modified)
- `tests/unit/test_zombie_run_tier.gd` (new) + `.uid`
- `tests/unit/test_horde_rush_tier.gd` (new) + `.uid`
- `tests/integration/test_run_frame.gd` (modified)
- `tests/integration/test_tier_follow.gd` (new) + `.uid`
- `_bmad-output/implementation-artifacts/screenshots/7-5/zombie-run-tier1.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/7-5/horde-rush-tier1.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/7-5-zombie-run-and-horde-rush-follow-the-tier.md` (this file)

## Change Log

- 2026-10-08: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-08: Implemented (dev-story): tier hand-off RunFrame -> LevelBase, tier letter pools in Zombie Run, tier word pools in Horde Rush via `WordSource.tier_pool_from_json` and `LevelConfig.tier_word_pools`, `"tier_N"` run record label, FR64 invariance and Epic 7 end-to-end tests, web export check. Suite 1751 -> 1789 passing. Status -> review.
