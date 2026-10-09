---
baseline_commit: 008ca25ff3c41c3fb3589ca1d6a42fa59571ad91
---

# Story 7.4: Tier Word Pools and Validation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer,
I want each tier's word pool generated and checked automatically,
so that no tier ever runs short of words.

## Acceptance Criteria

1. **Tier pool definitions live in `TierConfig` (one source of truth, FR62).** `scripts/resources/tier_config.gd` gains three per-tier arrays, tier 1 first, the same length as `tier_floors`: `tier_row_counts: Array[int]` (how many keyboard rows, cumulative in `WordTagger.ROW_NAMES` order: 1 = home, 2 = home + top, 3 = all), `tier_word_min_length: Array[int]` and `tier_word_max_length: Array[int]`. `data/tier_config.tres` ships `[1, 2, 3, 3, 3]`, `[2, 3, 3, 4, 5]`, `[4, 4, 5, 6, 8]`. Tier 1's band is **2–4**, not the GDD's 2–3 (Smuck's decision at the Story 7.3 review gate, 2026-10-08; see *Tier 1 band*). `validate()` rejects wrong sizes, row counts outside 1–3 or falling between tiers, and bands outside `WordTagger.MIN_LENGTH..MAX_LENGTH` or with min > max.
2. **The tagging tool writes the pools (FR66, FR62).** `tools/tag_words.gd` run with `-- --pools` on `tools/word_lists/master_words.txt` (the default `--in` in pools mode) writes `data/content/word_pools.json`: for each tier, its number, rows, length band and its words (sorted, the master words using **only** the tier's rows **and** within its length band). It also writes the pool validation report `data/content/word_pool_report.json` (per tier: count, minimum, ok) and prints the same table. Neither file has a timestamp, so a re-run on the same inputs makes no diff.
3. **Minimums are set in the tool's logic.** `WordTagger` holds `TIER_POOL_MINIMUMS: Array[int] = [40, 100, 100, 100, 100]` (tier 1 first). Tier 1 needs at least 40 home-row words of 2–4 letters (FR66, widened band); tiers 2–5 need at least 100 (no tier below 100 without a recorded reason; none is needed: 7.3 measured 304 / 901 / 951 / 904). The tool exits 1 when any tier is below its minimum (it still writes both files, so the report shows the shortfall).
4. **CI fails when a tier is short or the pools are stale.** A new GUT test (`tests/unit/test_word_pools.gd`) loads `word_pools.json` and `word_pool_report.json` and fails if any tier is below its minimum, if the committed pools differ from a fresh build from `master_words.txt` + `data/tier_config.tres` (stale-file guard, like `test_word_list.gd`), or if any pool word breaks its tier's rule when checked with an **independent** row table. CI already fails on any GUT failure (`.github/workflows/build.yml`), so no workflow change is needed.
5. **Nothing the kid sees changes.** `data/content/words.json`, `data/levels/horde_rush.tres`, `test_word_level.tres`, `WordSource`, `LevelConfig`, `HordeRushLevel`, Zombie Run and `PlayerData` logic are unchanged. Horde Rush keeps its 3–5 band from the starter `words.json` until Story 7.5 wires the tier in. Running the tool with no arguments still does exactly what it did in 6.1 (starter list → `words.json`, starter-band check).
6. **Planning docs match the decision.** The tier 1 band of 2–4 is written into FR62 and FR66 (`epics.md` requirements inventory), the Story 7.4 and 7.5 ACs in `epics.md`, and the GDD *Adaptive Difficulty* table and *Content* tier 1 line, each with a short "(widened to 2–4, Smuck, Story 7.3 review 2026-10-08)" note. The 7.3 deferral in `deferred-work.md` is marked done.
7. **Tests and suite.** Unit tests cover the new `WordTagger` pool logic, the new `TierConfig` fields and `validate()` cases, and the pool files. `test_master_word_list.gd`'s tier test uses the shared minimums instead of its own copies. Full suite stays green (baseline **1734**, 90 scripts) with no `Parse Error|Compile Error|Failed to load script` lines.

## Tasks / Subtasks

- [x] **Task 1: Tier pool fields in `TierConfig`** (AC: 1)
  - [x] 1.1 Add `tier_row_counts`, `tier_word_min_length`, `tier_word_max_length` (`@export`, typed `Array[int]`, default `[]`, `##` doc comments saying why: FR62 table, tier 1 widened). Keep the "defaults are neutral" rule.
  - [x] 1.2 Add helpers next to `floor_of()`: `row_count_of(tier: int) -> int`, `word_band_of(tier: int) -> Vector2i` (x = min, y = max). Out-of-range tier → `0` / `Vector2i.ZERO`, same style as `floor_of()`. Story 7.5 will call these at runtime.
  - [x] 1.3 Extend `validate()` (append checks after the existing ones so existing error messages and their tests don't move): each array's size == `tier_count()`; each row count in 1..`WordTagger.ROW_NAMES.size()` and never lower than the previous tier's; each band `WordTagger.MIN_LENGTH <= min <= max <= WordTagger.MAX_LENGTH`. One short message per problem, naming the tier, matching the existing message style.
  - [x] 1.4 Update `data/tier_config.tres` with the shipped values (`Array[int]([1, 2, 3, 3, 3])` etc.). **Do this in the same change as 1.3**: `PlayerData._ready` validates the shipped config (`player_data.gd:79-81`), so a stricter `validate()` with an old `.tres` would break boot and many tests.
  - [x] 1.5 Update the class doc comment (it already says "Stories 7.4 / 7.5 may extend this same resource with per-tier pools").
- [x] **Task 2: Pool logic in `WordTagger`** (AC: 2, 3)
  - [x] 2.1 `const TIER_POOL_MINIMUMS: Array[int] = [40, 100, 100, 100, 100]` with a `##` comment: FR66 tier 1 (40, band widened to 2–4 by Smuck at the 7.3 gate), Story 7.4 AC (100 for every other tier). This is the single source for the tool, `test_word_pools.gd` and `test_master_word_list.gd`.
  - [x] 2.2 `static func letters_for_rows(row_count: int) -> String`: concatenation of the first `row_count` rows (`ROW_HOME`, `ROW_TOP`, `ROW_BOTTOM`). Clamp or return "" outside 1..3 (document which).
  - [x] 2.3 `static func pool_words(words: Array, row_count: int, min_len: int, max_len: int) -> Array[String]`: from tagged entries (the `tag_lines` shape; also accept the parsed-JSON shape where `length` is a float, like `count_in_band` does), the words whose `rows` are all within the first `row_count` row names and whose length is in the band, sorted. Use the entry's `rows` tags (that is what "tagged by rows" means in FR66), not a second letter scan.
  - [x] 2.4 `static func build_tier_pools(words: Array, config: TierConfig) -> Array[Dictionary]`: one entry per tier `{ "tier": n, "rows": [...row names...], "min_length": a, "max_length": b, "words": [...] }`. Pure: takes the config as a parameter, never loads a file.
  - [x] 2.5 `static func pool_report(pools: Array, minimums: Array[int]) -> Array[Dictionary]`: per tier `{ "tier": n, "count": c, "minimum": m, "ok": c >= m }`. A tier with no entry in `minimums` (more tiers than minimums) reports `minimum` 0 and `ok = false`, documented in the doc comment, so adding a 6th tier without setting its minimum fails loudly instead of passing.
  - [x] 2.6 Keep the class pure (no nodes, autoloads or file access): it is shipped code in `scripts/typing/`. `TierConfig` is a Resource class, fine to reference.
- [x] **Task 3: Pools mode in `tools/tag_words.gd`** (AC: 2, 3, 5)
  - [x] 3.1 New args: `--pools` (flag), `--pools-out=` (default `res://data/content/word_pools.json`), `--report-out=` (default `res://data/content/word_pool_report.json`). In pools mode the default `--in` is `res://tools/word_lists/master_words.txt` and `words.json` is **not** written. Without `--pools` the tool behaves exactly as today (same defaults, same output, same starter-band check).
  - [x] 3.2 In pools mode skip the starter-band check (it is a 6.1 starter-list rule) and resolve that `deferred-work.md` 6.1 item ("may need it relaxed or parameterised"): strike it with "Done in 7.4: only the default (starter) mode runs it; `--pools` mode checks the tier minimums".
  - [x] 3.3 Load `res://data/tier_config.tres` as `TierConfig` (`load(...) as TierConfig`, like `tools/horde_rush_sim.gd` loads level configs); fail with a clear message if it is null or `validate()` returns a problem.
  - [x] 3.4 Rejected lines still fail the run (exit 1), as today. Build pools with `WordTagger.build_tier_pools`, report with `WordTagger.pool_report(pools, WordTagger.TIER_POOL_MINIMUMS)`. Print one line per tier, e.g. `tier 1 (home, 2-4): 40 words (minimum 40) ok`; `_fail` any tier that is not ok.
  - [x] 3.5 Write both files with `JSON.stringify(doc, "\t") + "\n"`, like `words.json`. Pools doc: `{ "schema": 1, "source": <in_path>, "tiers": [ ...build_tier_pools... ] }`. Report doc: `{ "schema": 1, "source": <in_path>, "tiers": [ ...pool_report... ] }`. No timestamps. Refactor the existing write block into a small `_write_json(path, doc)` helper used by both modes rather than copying it.
  - [x] 3.6 Cheap fix for the 6.1 deferral "does not validate `--in`/`--out`": reject an empty value or one not starting with `res://` (all three out args and `--in`), with a clear `_fail` message. Strike that deferral too.
  - [x] 3.7 Update the file's header comment: both run lines (default and `-- --pools`), what each writes, the exit codes.
  - [x] 3.8 Run it: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/tag_words.gd -- --pools`. Expect accepted 1512, rejected 0, and tiers 40 / 304 / 901 / 951 / 904 (7.3's measured counts; if the tool disagrees, find out why before going on, don't adjust the test to match). Then `--import`. Commit both JSON files. Also run the tool with no arguments and confirm `git diff --exit-code data/content/words.json` is clean.
- [x] **Task 4: Tests** (AC: 1, 3, 4, 7)
  - [x] 4.1 `tests/unit/test_word_tagger.gd`: add tests for `letters_for_rows` (1 → home, 2 → home+top, 3 → all 26), `pool_words` (a small hand-built tagged list: a home-only word in, a top-row word out of tier 1, length band edges inclusive, sorted output, float `length` from JSON), `build_tier_pools` with a code-built `TierConfig`, `pool_report` (ok / short / missing minimum).
  - [x] 4.2 `tests/unit/test_tier_config.gd`: shipped values for the three arrays; `_valid()` gets them so existing cases stay valid; new broken cases (wrong size, row count 0 or 4, row count falling 2 → 1, min > max, min < 2, max > 8). Neutral defaults test: the new arrays are empty.
  - [x] 4.3 `tests/unit/test_word_pools.gd` (new). Load both JSON files with `load(path) as JSON` (as `test_word_list.gd` does) and assert non-empty first (6.1's review found vacuous passes). Assert:
    - schema 1; exactly `tier_count()` tiers, numbered 1..n in order; each tier's rows and band equal `TierConfig`'s.
    - **Minimums (the CI gate):** each tier's word count >= `WordTagger.TIER_POOL_MINIMUMS[tier - 1]`, and the report says `ok` for every tier with the same counts as the pools file.
    - **Independent oracle:** write the rows out again (`"asdfghjkl"`, `"qwertyuiop"`, `"zxcvbnm"`, not imported from `WordTagger`; same rule as `test_master_word_list.gd`). Every pool word uses only its tier's letters and fits its band; and every master word that fits a tier's letters and band is in that tier's pool (pool == oracle filter, both directions).
    - **Stale guard:** re-tag `master_words.txt` with `WordTagger.tag_lines`, rebuild with `build_tier_pools(…, shipped TierConfig)` and compare to the file's tiers; message "word_pools.json is out of date (re-run tools/tag_words.gd -- --pools)". Do the same for the report.
    - Sorted, no duplicates within each pool; pools are subsets of the master list.
    - Tier 1 is exactly the 40 home-row words 7.3 recorded is **not** asserted word-by-word (too brittle); the count check covers it.
  - [x] 4.4 `tests/unit/test_master_word_list.gd`: replace `TIER_MIN`, `TIER1_MIN` and `TIER1_MIN_LEN/MAX_LEN` with `WordTagger.TIER_POOL_MINIMUMS` and the shipped `TierConfig` bands (keep its independent letter oracle). Keep the comment about Smuck's decision. This is the "keep one source of truth" item from the 7.3 deferral.
  - [x] 4.5 `test_word_list.gd`, `test_word_source.gd`, `test_horde_rush_*`, `test_placement.gd`, `test_tier_calculator.gd` must pass **unchanged** (they prove AC 5).
- [x] **Task 5: Planning docs** (AC: 6)
  - [x] 5.1 `_bmad-output/planning-artifacts/epics.md`: FR62 "(2–3, 3–4, …)" → "(2–4, 3–4, …)"; FR66 "at least 40 home-row words of 2–3 letters" → "2–4 letters"; Story 7.4 AC tier 1 text; Story 7.5 band list "(2–3, 3–4, 3–5, 4–6, 5–8)" → "(2–4, 3–4, 3–5, 4–6, 5–8)". Each with the short decision note. Edit line-anchored; do not rewrite whole sections.
  - [x] 5.2 GDD (`_bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md`): the *Adaptive Difficulty* table's tier 1 Horde Rush cell (line ~218) and the *Content* "Tier 1 pool check" line (~233), with the same note. Its example list (`flag` was already 4 letters) now fits.
  - [x] 5.3 `deferred-work.md`: mark the "Tier 1 band decision" item under *Deferred from: dev of story-7-3* as done in 7.4 (docs edited, band in `TierConfig`); mark the "Tier pool counts … keep one source of truth" item done (Task 4.4).
- [x] **Task 6: Wrap-up**
  - [x] 6.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command (*Testing notes*). Baseline **1734**. Record the new total and script count. Grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 6.2 Commit the new `.uid` file (`test_word_pools.gd.uid`). JSON files have no `.import` / `.uid` (same as `words.json`).
  - [x] 6.3 Mutation check once: temporarily raise `TIER_POOL_MINIMUMS[0]` to 41 and confirm the tool exits 1 and `test_word_pools.gd` fails; hand-delete one word from `word_pools.json` and confirm the stale guard fails; revert both (`git diff` clean).
  - [x] 6.4 `deferred-work.md`: add a "Deferred from: dev of story 7-4" section only for new items.
  - [x] 6.5 Mark sprint-status `7-4-tier-word-pools-and-validation: review` when done (dev-story does this).

## Dev Notes

### What this story is (and isn't)

- It is: three `TierConfig` fields, pure pool logic in `WordTagger`, a `--pools` mode in the existing tool, two generated JSON files under `data/content/`, tests, and the doc edits for Smuck's tier 1 decision.
- It isn't: any runtime use of the pools (Story 7.5 wires `WordSource` and Zombie Run to the tier), a change to `words.json` or `horde_rush.tres`, a change to the master list (7.3, reviewed and closed), paragraphs or the sentence generator (8.1), any UI. No scene, autoload, save schema, asset or `project.godot` change.
- `word_pools.json` will ship in the web build (export `include_filter="data/content/*.json"`) but nothing loads it yet. That is fine and lets 7.5 just point at it. The report is tiny and ships too; the architecture puts the "pool validation report" under `res://data/content/` (*Static Game Data*).

### Tier 1 band (read first)

- FR62, FR66 and the GDD say tier 1 is home row, 2–3 letters, minimum 40. Story 7.3 measured only **21** kid-safe home-row words of 2–3 letters (`a` is the only home-row vowel). At the 7.3 review gate Smuck chose **"Widen band to 2-4 (Recommended)"** (2026-10-08, verbatim in the 7.3 file's *Word List Review*). With 2–4 there are exactly **40**.
- So tier 1 here is home row, **2–4**, minimum 40. The exact 40 means any removal of a home-row word from `master_words.txt` breaks both `test_master_word_list.gd` and `test_word_pools.gd`. That is on purpose: do not lower the minimum to make a test pass.
- The epics AC for this story still says "2–3"; AC 1/3/6 above apply Smuck's decision and Task 5 brings the planning docs in line. Story 7.5 reads the band from `TierConfig`, so it gets 2–4 automatically.

### Design decisions (follow them)

- **Where the tier numbers live:** `TierConfig` (`data/tier_config.tres`) already holds the tier floors and says 7.4/7.5 may extend it. The rows and bands are tier tuning numbers that 7.5 needs at runtime (architecture: "Tuning numbers from the GDD live in … resources, never as literals in scripts"), so they go there, not in the tool. Rows are stored as a **count** (1/2/3) because the GDD tiers add rows cumulatively (home → +top → all) and GDScript can't export `Array[Array[String]]`.
- **Where the minimums live:** content-validation thresholds, not runtime tuning, so they go with the tagging logic in `WordTagger`, next to the existing `STARTER_BAND_MIN_COUNT` (same pattern 6.1 used: the tool and the test both read the one constant). This is what the epic's "a minimum count set in the tool" means: `WordTagger` is the tool's logic, `tag_words.gd` is its I/O.
- **Pool rule (FR66):** a word is in tier *n*'s pool when every row tag it has is one of the tier's rows **and** its length is in the tier's band. Tiers 3–5 allow all rows, so they are just length bands. Tier 2 excludes every word with a bottom-row letter (`can`, `man`, `bad` are out; `the`, `ride` are in).
- **Pools file shape** (7.5 and 8.1 will read it):
  ```json
  { "schema": 1, "source": "res://tools/word_lists/master_words.txt",
    "tiers": [ { "tier": 1, "rows": ["home"], "min_length": 2, "max_length": 4, "words": ["ad", "add", ...] }, ... ] }
  ```
  Words are plain strings (the per-word row tags already decided membership; repeating them would triple the file). JSON numbers load as float: compare with `int()`.
- **Reject, don't fix** stays: a bad master line is a rejection and fails the run, as in 6.1.
- **CI:** the workflow runs only `--import` and GUT. "CI fails if any tier falls below its minimum" is met by `test_word_pools.gd`: it checks both the committed counts and that the committed file is fresh, so a master-list edit without a re-run, or a re-run that comes up short, fails CI. Don't add a separate CI step that runs the tool (it would need a writable checkout and duplicates the test).

### Existing code to read first

- **`tools/tag_words.gd`** (UPDATE): `_init` parses `--in=`/`--out=`, `_run` reads, tags, prints the summary, runs the starter-band check, writes `{schema, source, words}`; `_fail` prints and sets `_ok`; `quit(0 if _ok else 1)`. Preserve the no-argument behaviour byte-for-byte in its output file.
- **`scripts/typing/word_tagger.gd`** (UPDATE): `ROW_HOME/TOP/BOTTOM`, `ROW_NAMES`, `MIN_LENGTH` 2, `MAX_LENGTH` 8, `STARTER_BAND_*`, `rows_for`, `rejection_reason`, `tag_lines` (sorted output), `count_in_band` (accepts float lengths from JSON). Add to it; change nothing existing.
- **`scripts/resources/tier_config.gd`** / **`data/tier_config.tres`** (UPDATE): `tier_floors`, `drop_margin_wpm`, `window_runs`, `level_wpm_scale`, `ignored_levels`, `placement_level`; `tier_count()`, `floor_of()`, `scale_for()`, `validate()`. Used by `TierCalculator` and `PlayerData` (validated on `_ready`).
- **`tests/unit/test_tier_config.gd`** (UPDATE): `_shipped()`, `_valid()` (code-built config; must get the new arrays or every "valid" case fails after Task 1.3), `test_defaults_are_neutral`, one test per broken case.
- **`tests/unit/test_master_word_list.gd`** (UPDATE): independent row oracle `HOME/TOP/BOTTOM`, `TIER_MIN`, `TIER1_*` constants, `_count_fitting`, `test_tier_pools_have_enough_words`.
- **`tests/unit/test_word_list.gd`** (read only): the stale-JSON guard pattern to copy for `test_word_pools.gd`.
- **`tests/unit/test_word_tagger.gd`** (UPDATE): style for small hand-built inputs and the independent table.
- **`scripts/typing/word_source.gd`** (read only): `pool_from_json(json, min_len, max_len)` reads the `{"words":[{"word":…}]}` shape; 7.5 will add a tier-pool reader. Don't change it here.
- **`tools/horde_rush_sim.gd`**: example of a `-s` SceneTree tool loading a typed `.tres` with `load(...) as …`.

### Architecture and rules to follow

- Godot **4.7.2**, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed vars, typed arrays, typed returns, typed loop vars. Tabs. `##` doc comments saying *why*. `UPPER_SNAKE` constants.
- D5 / *Static Game Data*: generated content is JSON under `res://data/content/`, produced by the headless GDScript tool. No Python.
- Boundary 3 (only `SaveService` touches files) applies to shipped code: `WordTagger` and `TierConfig` stay file-free; the tool and tests may read and write files.
- The tier is hidden from the kid (FR60, NFR10; 7.2's `RANKS` self-check includes `\btier`). Nothing here reaches a screen. `test_plain_words.gd` is unaffected (no player-facing copy).
- Export exclusions stay: `addons/gut/*, tests/*, tools/*, docs/*, _bmad/*, _bmad-output/*, build/*, .gutconfig.json`. `export_presets.cfg` is not touched.
- `.gitattributes` forces LF; `JSON.stringify` output plus `"\n"` matches `words.json`.

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. GUT skips a script that fails to parse and still exits 0: grep the log for `Parse Error|Compile Error|Failed to load script` (CI does).
- Baseline **1734** passing, 90 scripts (Story 7.3 final). Expect +1 script and roughly 20–25 tests.
- Run `--import` after the tool writes the JSON files and after adding the test script, or `load()` may return a stale or null resource.
- Tests don't touch the save. Checked at story creation: only `test_tier_config.gd` calls `validate()`. The code-built configs in `test_tier_calculator.gd:8` and `test_placement.gd:56` never validate (PlayerData's seam validates only the shipped config), so they need no new arrays. In `test_tier_config.gd`, the broken-case tests use `assert_ne(validate(), "")`: once `_valid()` has the new arrays, each one still fails on its own check because 1.3 appends the new checks last. Add the arrays to `_valid()` first, or `test_valid_config_passes` goes red.

### Previous story intelligence

- **7.3 (master list):** 1,512 words, reviewed by Smuck, shipped as is; tier counts 40 / 304 / 901 / 951 / 904; tier 1 band widened to 2–4; `test_master_word_list.gd` has an independent row oracle. Its review asked for one source of truth for the tier minimums (Task 4.4). Edit story-file and doc sections line-anchored (a whole-section replace once cut half a story in 5.2).
- **7.2:** `PlayerData` validates the shipped `TierConfig` on `_ready` and logs/handles a problem; a stricter `validate()` needs the `.tres` updated in the same commit. Tier never shown.
- **7.1:** `TierConfig` style: neutral defaults, `validate()` returns the first problem string, one test per broken case.
- **6.1 (tool):** code review found a vacuous test when the JSON failed to load (assert non-empty first), tests reproducing the tagger's own table (use an independent oracle), band minimums duplicated in tool and test (keep one constant), and story vs measured baseline disagreeing (record the real total).

### Git intelligence

- One commit per story on `main`, then a "(code review patches applied, done)" commit: latest `008ca25 Story 7.3: master word list, code review patches applied, done`. Use `Story 7.4: tier word pools and validation`.
- Expected changes: `scripts/typing/word_tagger.gd`, `scripts/resources/tier_config.gd`, `data/tier_config.tres`, `tools/tag_words.gd`, `data/content/word_pools.json` (new), `data/content/word_pool_report.json` (new), `tests/unit/test_word_pools.gd` (+ `.uid`, new), `tests/unit/test_word_tagger.gd`, `tests/unit/test_tier_config.gd`, `tests/unit/test_master_word_list.gd`, `epics.md`, `gdd.md`, `deferred-work.md`, this file, `sprint-status.yaml`. **Not** expected: `data/content/words.json`, `data/levels/*`, `scripts/levels/*`, `scripts/autoloads/*`, `word_source.gd`, `level_config.gd`, `tools/word_lists/*`, `.github/`, `export_presets.cfg`, `project.godot`.

### Forward notes (for 7.5 / 8.1, don't implement here)

- **7.5:** Horde Rush draws from `word_pools.json`'s tier entry (via a new `WordSource` reader or a pool-by-tier helper) using `TierConfig.word_band_of(tier)`; Zombie Run's letter pool is `WordTagger.letters_for_rows(TierConfig.row_count_of(tier))` after placement. `horde_rush.tres`'s fixed `word_list` / 3–5 band and `test_word_list.gd`'s starter guard need a decision there. Verify a real web export loads `word_pools.json` (`deferred-work.md` 6.1 item, `load()` vs `FileAccess`).
- **8.1:** tiers 1–2 build 4–7-word sentences from these pools; tier 1 has only 40 words, so the generator must cope with a small pool.

### Project Structure Notes

- New files follow existing places: generated JSON next to `words.json` in `data/content/` (architecture tree: "Post-MVP generated JSON"), the test in `tests/unit/`. No new folders.
- Variance: the architecture tree lists `words.json, paragraphs.json` only; `word_pools.json` and `word_pool_report.json` are the "word list … and a pool validation report" its *Static Game Data* section describes. No conflict.

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md`, the GDD and the UX spines:
  - D5: typed Resources for static data; generated JSON under `res://data/content/` from the headless GDScript tool.
  - Tuning numbers live in resources, never as literals in scripts (so tier bands/rows go in `TierConfig`).
  - Consistency rules: static typing; tests for every new unit; CI fails on any GUT failure.
  - FR60 / NFR10: the tier is never shown.
  - Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1.

### Latest tech information

- No new libraries or engine features. Already proven in this repo on Godot 4.7.2: `OS.get_cmdline_user_args()` returns args after `--`; `-s` SceneTree tools can `load()` typed `.tres` resources (`tools/horde_rush_sim.gd`); `JSON` files under `data/content/` load as `JSON` resources with `load()` and need no `.import`; typed `Array[int]` exports serialize as `Array[int]([...])` in `.tres`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.4: Tier Word Pools and Validation] (ACs); #Story 7.5 (consumer); #Story 6.1 (tool)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR62, FR64, FR66
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] *Adaptive Difficulty* (tier table), *Content: Word Lists & Paragraphs*
- [Source: _bmad-output/game-architecture.md] *Static Game Data* (generated JSON, pool validation report), project tree `data/content/`, D5
- [Source: _bmad-output/implementation-artifacts/7-3-master-word-list.md] *Word List Review* (tier 1 decision, counts), forward notes
- [Source: _bmad-output/implementation-artifacts/6-1-word-tagging-tool-and-starter-word-list.md] tool, review findings
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 6.1 tool deferrals; 7.3 tier 1 band and single-source items
- [Source: scripts/typing/word_tagger.gd], [tools/tag_words.gd], [scripts/resources/tier_config.gd], [data/tier_config.tres], [scripts/autoloads/player_data.gd:79-81], [tests/unit/test_word_list.gd], [tests/unit/test_master_word_list.gd], [tests/unit/test_tier_config.gd], [.github/workflows/build.yml]

### Review Findings

Code review 2026-10-08: Blind Hunter, Edge Case Hunter and Acceptance Auditor all ran. No AC violations. 15 findings dismissed as noise.

- [x] [Review][Patch] `validate()` must require length bands non-decreasing across tiers (min and max each), with a test; decided by Smuck [scripts/resources/tier_config.gd:validate]
- [x] [Review][Patch] `--out=` (and `--pools-out`/`--report-out` outside `--pools`) are accepted and silently ignored; fail with a message instead [tools/tag_words.gd:_init]
- [x] [Review][Patch] `test_word_pools.gd` `before_each` asserts `_config`/`_tiers` but does not stop, so later tests null-deref instead of failing cleanly [tests/unit/test_word_pools.gd:before_each]
- [x] [Review][Patch] Stale guard does not compare the report's `source`/`schema` against a fresh build [tests/unit/test_word_pools.gd:test_matches_a_fresh_build]
- [x] [Review][Patch] `pool_words` clamps a bad `row_count` to a full pool while `letters_for_rows` returns "" for the same input; make them agree [scripts/typing/word_tagger.gd:pool_words]
- [x] [Review][Defer] `pool_words`/`pool_report` crash on JSON entries missing `word`/`rows`/`length` or given an untyped `minimums` array — deferred, only trusted generated data reaches them; revisit when 7.5 reads the file
- [x] [Review][Defer] Pools mode can leave `word_pools.json` and `word_pool_report.json` out of sync if the second write fails — deferred, tool run is manual and CI's fresh-build test catches a stale pair
- [x] [Review][Defer] Tier 1 pool is exactly at its minimum (40/40), so dropping one word fails the gate — deferred, acknowledged as intentional in the story
- [x] [Review][Defer] Tests `load()` the pool JSONs as `JSON` resources, which needs an editor import on a fresh clone — deferred, same as the existing content tests

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Tool run (`-- --pools`): accepted 1512, rejected 0; tier 1 (home, 2-4) 40, tier 2 (home+top, 3-4) 304, tier 3 (all, 3-5) 901, tier 4 (all, 4-6) 951, tier 5 (all, 5-8) 904. All ok, the same as 7.3's measured counts.
- Tool with no arguments: exit 0, `git diff --exit-code data/content/words.json` clean. Bad paths (`--in=C:/x.txt`, `--out=`) fail with a clear message, exit 1.
- First full run after Tasks 1-4: 21 failures, all in `test_placement.gd`. `PlayerData._tier_config_ok()` (`player_data.gd:347`, added in the 7.2 review) validates the injected code-built config on every `record_run`, so the stricter `validate()` rejected its config, which had no pool arrays. The story's testing note said this config is never validated, which is wrong.
- Mutation check (6.3): with `TIER_POOL_MINIMUMS[0]` = 41 the tool printed `tier 1 ... 40 words (minimum 41) SHORT` and exited 1, and `test_word_pools.gd` had 2 failures. With `glad` deleted from `word_pools.json`, the stale guard failed ("tier 1: word_pools.json is out of date ..."). All three files were restored byte-for-byte (`cmp`).
- Final suite: 1749/1749 passing, 91 scripts (baseline 1734 / 90: +15 tests, +1 script). No `Parse Error|Compile Error|Failed to load script` lines.

### Completion Notes List

- **TierConfig:** added `tier_row_counts`, `tier_word_min_length` and `tier_word_max_length` (neutral `[]` defaults), plus `row_count_of()` and `word_band_of()` helpers. The new `validate()` checks go after the existing ones: sizes, row counts 1-3 that never fall between tiers, and bands within 2-8 with min <= max. `data/tier_config.tres` ships `[1,2,3,3,3]`, `[2,3,3,4,5]` and `[4,4,5,6,8]` in the same change.
- **WordTagger:** added `TIER_POOL_MINIMUMS` `[40,100,100,100,100]` (the single source), `letters_for_rows()`, `pool_words()`, `build_tier_pools()` and `pool_report()`. `letters_for_rows()` returns "" outside 1-3 rather than clamping. `pool_words()` uses each entry's row tags and accepts float lengths. A tier with no minimum reports `ok = false`. The class is still pure.
- **tools/tag_words.gd:** new `--pools` mode (default `--in` is the master list) writes `word_pools.json` and `word_pool_report.json`, prints one line per tier, and exits 1 on a short tier while still writing both files. Default mode behaves as before. The shared `_read_and_tag()` and `_write_json()` helpers replace the old inline code. All path arguments must be non-empty `res://` paths. Both 6.1 deferrals are struck.
- **Tests:** `test_word_pools.gd` (new) is the CI gate. It checks schema and tiers against `TierConfig`, minimums, report vs pool counts, an independent row oracle in both directions, sorted and unique words that all come from the master list, and a stale guard for both files. `test_word_tagger.gd` (+6 tests) and `test_tier_config.gd` (+4 tests, shipped values, neutral defaults) are extended. `test_master_word_list.gd` now reads `WordTagger.TIER_POOL_MINIMUMS` and the shipped `TierConfig` (its own oracle stays).
- **Deviation from 4.5 ("pass unchanged"):** `test_placement.gd`'s `_config()` fixture got the three pool arrays (4 lines, with a comment). Its assertions and all shipped runtime logic are unchanged, so AC 5 still holds. The fixture had to change because `PlayerData` validates injected configs (see Debug Log). This is recorded in `deferred-work.md` for Story 7.5. `test_word_list.gd`, `test_word_source.gd`, `test_horde_rush_*` and `test_tier_calculator.gd` are untouched and pass.
- **Docs:** FR62, FR66 and the 7.4/7.5 ACs in `epics.md`, plus the GDD tier table and tier 1 pool check, now say 2-4 with the decision note. Both 7.3 deferrals are struck.
- **6.2:** `tests/unit/test_word_pools.gd.uid` was generated and is in the File List. Nothing has been committed yet; the story commit is left to Smuck, as with earlier stories.

### File List

- scripts/resources/tier_config.gd (modified)
- data/tier_config.tres (modified)
- scripts/typing/word_tagger.gd (modified)
- tools/tag_words.gd (modified)
- data/content/word_pools.json (new)
- data/content/word_pool_report.json (new)
- tests/unit/test_word_pools.gd (new)
- tests/unit/test_word_pools.gd.uid (new)
- tests/unit/test_word_tagger.gd (modified)
- tests/unit/test_tier_config.gd (modified)
- tests/unit/test_master_word_list.gd (modified)
- tests/unit/test_placement.gd (modified: fixture only)
- _bmad-output/planning-artifacts/epics.md (modified)
- _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md (modified)
- _bmad-output/implementation-artifacts/deferred-work.md (modified)
- _bmad-output/implementation-artifacts/sprint-status.yaml (modified)
- _bmad-output/implementation-artifacts/7-4-tier-word-pools-and-validation.md (this file)

## Change Log

- 2026-10-08: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-08: Implemented (review). Tier pool table in TierConfig, pool logic and minimums in WordTagger, `--pools` mode in tag_words.gd, generated word_pools.json and word_pool_report.json, test_word_pools.gd CI gate, planning docs updated for the tier 1 band of 2-4. Suite 1749/1749 (91 scripts).
