---
baseline_commit: 90bebbd98d13b994caf82712b187f05f4c0b1e30
---

# Story 6.1: Word Tagging Tool and Starter Word List

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer,
I want a headless tool that tags words by keyboard rows and length, and a small kid-safe starter list,
so that Horde Rush has words now and the full curriculum can reuse the same tool later.

## Acceptance Criteria

1. **Tool writes tagged JSON (FR66).** Given `tools/tag_words.gd`, when it runs with `godot --headless --path . -s tools/tag_words.gd` on a plain word list (one word per line), then it writes `data/content/words.json` where each word has its `rows` (any of `home`, `top`, `bottom`, in that fixed order) and its `length`.
2. **Bad lines are rejected and reported.** Words with non-letters, uppercase letters, or duplicates (and words outside the 2–8 letter range, see Dev Notes) are left out of `words.json` and each one is printed with its line number and reason. Blank lines and `#` comment lines are skipped, not rejected. The tool exits non-zero when anything was rejected, the band check (AC 3) fails, or the file can't be read or written.
3. **Starter list (FR59, FR65 criteria).** Given a starter list of at least 200 kid-safe lowercase words (no scary, violent, rude or brand words), reviewed by Smuck, when it is tagged, then at least 150 words fall in the 3–5 letter band used before Epic 7.
4. **Smuck review gate.** The list is shown to Smuck before the story closes; removals are applied, the tool is re-run, and the review (date, answer verbatim, removed words) is recorded in this file's **Word List Review** section. `words.json` is not considered final until then.
5. **Unit tests (FR66).** Given the tagging logic, when GUT runs, then row and length tagging pass for sample words: `dad` → `["home"]`, 3; `quiz` → `["top", "bottom"]`, 4 (see the note on the epic's example below); plus the rejection rules.
6. **Shipped data guard.** A GUT test loads `res://data/content/words.json` with `load()` and checks: at least 200 words, at least 150 in 3–5 letters, no duplicates, every entry's tags equal a fresh `WordTagger` result, and the words equal the tagged source list (so a stale `words.json` fails CI).
7. **It ships.** `words.json` is included in both export presets (Web and Windows Desktop) so Story 6.2 can load it at runtime; `test_export_presets.gd` guards it.

> **Epic example corrected:** `epics.md` says `quiz` → top+bottom+home. That is wrong: `q u i` are top-row keys and `z` is bottom-row; `quiz` has no home-row key. The GDD row table (gdd.md, *Curriculum*) is the source of truth, so the test expects `["top", "bottom"]`. Do not "fix" the tagger to match the epic text.

## Tasks / Subtasks

- [x] **Task 1: `WordTagger` pure logic** (AC: 1, 2, 5)
  - [x] 1.1 Create `scripts/typing/word_tagger.gd`: `class_name WordTagger extends RefCounted`, static functions only, no nodes, no autoloads, no `FileAccess` (boundary 1 + 3).
  - [x] 1.2 Constants from the GDD row table: `ROW_HOME := "asdfghjkl"`, `ROW_TOP := "qwertyuiop"`, `ROW_BOTTOM := "zxcvbnm"`; row names `"home"`, `"top"`, `"bottom"` in that canonical order; `MIN_LENGTH := 2`, `MAX_LENGTH := 8` (doc-comment each with its source).
  - [x] 1.3 `static func rows_for(word: String) -> Array[String]` — the rows the word needs, canonical order, no repeats.
  - [x] 1.4 `static func rejection_reason(word: String) -> String` — `""` when valid; otherwise a short reason. Check in this order so the reason is the useful one: uppercase (any `A–Z`) → non-letter (anything not `a–z`, incl. digits, `'`, `-`, spaces inside, accented letters) → too short → too long.
  - [x] 1.5 `static func tag_lines(lines: PackedStringArray) -> Dictionary` returning `{ "words": Array[Dictionary], "rejected": Array[Dictionary] }`. Per line: strip `\r` and surrounding whitespace; skip empty and `#` lines; reject per 1.4; reject a repeat as `"duplicate of line N"` (the first one wins). Word entries are `{ "word": String, "rows": Array[String], "length": int }`; rejected entries are `{ "line": int (1-based), "text": String, "reason": String }`. Output words sorted alphabetically (stable diffs).
  - [x] 1.6 `static func count_in_band(words: Array, min_len: int, max_len: int) -> int` (used by the tool and the tests).
- [x] **Task 2: `tools/tag_words.gd` headless tool** (AC: 1, 2, 3)
  - [x] 2.1 `extends SceneTree`, header comment in the style of `tools/gen_finger_map.gd` (what it does, the exact run command, exit codes, story number).
  - [x] 2.2 Defaults: in `res://tools/word_lists/starter_words.txt`, out `res://data/content/words.json`. Optional overrides via `OS.get_cmdline_user_args()` (`-- --in=res://... --out=res://...`) so Story 7.4 can reuse it on the master list.
  - [x] 2.3 Read with `FileAccess.get_file_as_string()`; a missing/empty file → `printerr` + `quit(1)`. Split on `"\n"`, pass to `WordTagger.tag_lines`.
  - [x] 2.4 Print each rejection: `tag_words: line 12 "Dad": uppercase`. Print a summary: accepted, rejected, count per length 2..8, count per row set (e.g. `home`, `home+top`, `top+bottom`, `home+top+bottom`), and the 3–5 band count vs the minimum (constants `STARTER_BAND_MIN_LEN := 3`, `STARTER_BAND_MAX_LEN := 5`, `STARTER_BAND_MIN_COUNT := 150`, each citing FR59 / Story 6.1).
  - [x] 2.5 Write `{ "schema": 1, "source": <in path>, "words": [...] }` with `JSON.stringify(doc, "\t") + "\n"`. No timestamp (re-runs must not create a diff). Create `res://data/content/` if missing (`DirAccess.make_dir_recursive_absolute`). Write the accepted words even when some lines were rejected, then exit 1.
  - [x] 2.6 `quit(0)` only when nothing was rejected, the band check passed and the write returned `OK`.
- [x] **Task 3: Starter word list** (AC: 3)
  - [x] 3.1 Create `tools/word_lists/starter_words.txt` (LF endings, one word per line, a short `#` header saying what it is, the rules, and that Smuck reviewed it). Author about 220–250 words: at least 180 in 3–5 letters (margin over the 150 minimum so Smuck's removals don't break the check), the rest 2- and 6–8-letter words (Epic 7's tier bands 2–3 and 4–8 will need some; Story 6.3's brute class needs ≥6).
  - [x] 3.2 Content rules (GDD *Content*, NFR9, NFR10): common words a 6–8-year-old knows (Dolch sight words and everyday nouns/verbs/adjectives: animals, food, home, school, play, nature, colors, body-neutral actions). Exclude: scary or death words (`dead`, `kill`, `die`, `bone`, `grave`, `skull`, `blood`, `bite`, `ghost`, `monster`), violence and weapons (`gun`, `hit`, `punch`, `fight`, `war`, `sword`), rude/toilet/insult words (`butt`, `poop`, `fart`, `dumb`, `stupid`, `ugly`, `fat`, `hate`, `shut`), brands and proper nouns (`lego`, `oreo`, names, places), and words with a common rude second meaning. When in doubt, leave it out.
  - [x] 3.3 Prefer words that are fun to see as a zombie sign but stay neutral (`hat`, `cake`, `frog`, `jump`, `sun`, `pizza`). `brain`/`brains` are fine (the game's currency).
  - [x] 3.4 Run the tool (`"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/tag_words.gd`); it must exit 0. Commit `data/content/words.json`.
- [x] **Task 4: Ship the JSON** (AC: 7)
  - [x] 4.1 Set `include_filter="data/content/*.json"` on both presets in `export_presets.cfg` (currently `""`; keep the exclude filters unchanged). Godot should export `.json` as a `JSON` resource anyway, but the filter makes it explicit and testable.
  - [x] 4.2 Extend `tests/unit/test_export_presets.gd` with `test_both_presets_include_content_json` (reuse `_load_and_find` / `_split_filter`).
- [x] **Task 5: Tests** (AC: 5, 6)
  - [x] 5.1 `tests/unit/test_word_tagger.gd` (required: every class in `scripts/typing/` has a test). Cover: `dad` → `["home"]`, 3; `quiz` → `["top", "bottom"]`, 4; `the` → `["home", "top"]`; `cab` → `["home", "bottom"]`; `quick` → all three; `flag` → `["home"]`; canonical order regardless of letter order; the three row strings cover `a–z` exactly once (26, no overlap, written out independently in the test); rejections: `Dad` (uppercase), `it's`, `ice-cream`, `café`, `ab1` (non-letter), `a` (too short), `watermelon` (too long), second `dog` (duplicate of line N); `"  dog \r"` accepted as `dog`; blank and `# comment` lines skipped (not in `rejected`); output sorted; `count_in_band`.
  - [x] 5.2 `tests/unit/test_word_list.gd` (shipped data): `load("res://data/content/words.json") as JSON`, `.data` is a Dictionary with `schema == 1`; ≥200 words; ≥150 in 3–5; no duplicates; sorted; each entry's `rows` and `int(length)` equal `WordTagger`'s result and `rejection_reason(word) == ""`; re-tag `res://tools/word_lists/starter_words.txt` (tests may read files; `FileAccess` is already used in tests) and assert zero rejections and the same word list (stale-JSON guard). Add a small banned-word guard (the 3.2 examples) as a backstop — the human review is the real gate.
  - [x] 5.3 Note: JSON numbers load as `float` (verified in Godot 4.7.2: `length` comes back `3.0`), so compare with `int(...)`.
- [x] **Task 6: Smuck review gate** (AC: 3, 4)
  - [x] 6.1 Show the list to Smuck (grouped by length is easiest to scan; the file pane can open `tools/word_lists/starter_words.txt`). Ask one question with `AskUserQuestion`: approve as is / remove some words (Other: list them). Recommendation first.
  - [x] 6.2 Apply removals, re-run the tool (exit 0, band ≥150), re-run the tests.
  - [x] 6.3 Fill in **Word List Review** below: date, Smuck's answer verbatim, removed words, final counts.
- [x] **Task 7: Full suite and wrap-up**
  - [x] 7.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command (Testing notes). Baseline is **1323** passing (after Story 5.5); record the new total. Grep the output for `Parse Error|Compile Error|Failed to load script` like CI does.
  - [x] 7.2 Commit the generated `.uid` files for the new scripts (as for every other script).
  - [x] 7.3 Add Story 6.2 hand-offs to `deferred-work.md` only if you find something new (the known ones are listed under *Forward notes* below; don't duplicate them).

## Word List Review

- **Date:** 2026-10-07
- **Shown:** all 246 words grouped by length, with the borderline words kept (`cow`, `pig`, `tiger`, `dinosaur`, `hot`, `sock`) and the words left out as "when in doubt" (`bun`, `melon`, `crab`, `clap`, `fairy`, `monkey`, `muffin`, `cherry`, `mug`, `bat`, `snake`, `shark`, `spider`, `fire`, `wolf`) listed.
- **Question:** "Is the starter word list OK to ship (246 words shown above)?"
- **Smuck's answer (verbatim):** "Approve as is (Recommended)"
- **Removed words:** none.
- **Final counts:** 246 words; 3–5 letter band 191 (minimum 150). Per length: 2: 15 · 3: 81 · 4: 62 · 5: 48 · 6: 23 · 7: 10 · 8: 7. Per row set: home 3 · home+bottom 10 · home+top 81 · home+top+bottom 102 · top 13 · top+bottom 37.
- `words.json` is final for this story (tool re-run after the review: exit 0, no diff).

## Dev Notes

### What this story is (and isn't)

- It is: one pure tagging class, one offline headless tool, one hand-authored word list, the generated `words.json`, its export inclusion, and tests. Nothing in the game uses `words.json` yet.
- It isn't: `WordSource` or word mode (Story 6.2), the Horde Rush level (6.3+), tier pools or the pool validation report (7.4), the 1,500-word master list (7.3). Don't add a runtime loader, a `LevelConfig` field or a CI step for the tool.
- No game scene, autoload, save, asset or `project.godot` change.

### Design decisions already made (follow them)

- **Logic in `scripts/typing/word_tagger.gd`, I/O in `tools/tag_words.gd`.** The architecture puts the tool at `tools/tag_words.gd` and says `scripts/typing/` is pure logic. Keeping the tagger pure lets GUT test it without running the tool, and Epic 7 can reuse the row constants at runtime (Zombie Run's tier letter pools: tier 1 = home row, tier 2 = home + top). `tools/` is export-excluded, so a `class_name` there would be a global class missing from the export; keep `class_name` out of `tools/` (none of the existing tools has one).
- **Boundary 3 ("only `SaveService` touches files")** is about the shipped game. The offline tool may use `FileAccess`/`DirAccess` (existing tools write with `ResourceSaver`/`Image.save_png`); `WordTagger` must not. Runtime code in 6.2 should read the list with `load("res://data/content/words.json") as JSON` (a `JSON` resource, verified in Godot 4.7.2), not `FileAccess`, which keeps the `grep FileAccess` rule true.
- **Length range 2–8.** Not in the epic AC, but every later consumer agrees: the GDD tier bands span 2–8 (tier 1: 2–3 … tier 5: 5–8), and the HUD word sign fits about 9 letters at 32 px (`deferred-work.md`, Story 2.5 note: "a word over about 9 letters … overflows the 312 px target area"). Rejecting outside 2–8 at tag time keeps bad words out of every pool.
- **Reject, don't fix.** Uppercase is rejected, not lowercased: the source list should be clean, and a silently changed word hides a typo.
- **Output order and schema.** Sorted words, `schema: 1`, no timestamp. `JSON.stringify` sorts dictionary keys by default (`length`, `rows`, `word`), which is fine.
- **Source list location:** `tools/word_lists/starter_words.txt` (export-excluded; the master list for 7.3 goes next to it).

### Row table (GDD *Curriculum*, the only source of truth)

| Row | Keys |
|---|---|
| Home | `a s d f g h j k l` |
| Top | `q w e r t y u i o p` |
| Bottom | `z x c v b n m` |

Worked examples for the tests: `dad` home · `flag` home · `the` home+top · `cab` home+bottom · `zoo` top+bottom · `quiz` top+bottom · `quick` home+top+bottom.

### Existing code to read first

- **`tools/gen_finger_map.gd`** (read only, pattern to copy): `extends SceneTree`, work in `_init()`, `_fail()` collects errors into `_ok`, `quit(0 if _ok else 1)`, `printerr` with a `toolname:` prefix, header with the exact Windows run command.
- **`scripts/typing/letter_bag_source.gd`, `target_source.gd`** (read only): the pure-class style in `scripts/typing/` (typed arrays, `##` doc comments, `Log.error(&"typing", ...)` on misuse).
- **`tests/unit/test_finger_map.gd`** (read only): the "independent oracle in the test" style — the row strings in `test_word_tagger.gd` must be written out again, not imported from `WordTagger`.
- **`export_presets.cfg`** (UPDATE): both presets have `include_filter=""` (lines 9 and 45) and the exclude list. Change only `include_filter`. Preserve everything else (head include CSS, thread support off, PWA off).
- **`tests/unit/test_export_presets.gd`** (UPDATE): add one test; keep `REQUIRED_EXCLUDES` and the rest unchanged.
- **`scripts/core/log.gd`**: `Log` is for game code; the tool prints with `print`/`printerr` like the other tools.

### Architecture and rules to follow

- Godot **4.7.2** (standard), GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): `var x: int`, typed arrays (`Array[String]`, `Array[Dictionary]`), typed returns, typed loop vars (`for c: String in word`). Tabs. `##` doc comments, short, saying *why*.
- `snake_case` files, `PascalCase` `class_name`, `UPPER_SNAKE` constants, test files `test_<unit>.gd` in `tests/unit/`.
- `data/content/` is the architecture's home for generated JSON (`words.json`, later `paragraphs.json`).
- Kid-facing safety (NFR9, NFR10, GDD *Content*): nothing scary, violent, rude or branded. The words will appear in big letters on a zombie sign in front of a 6-year-old.
- Export exclusions stay: `addons/gut/*, tests/*, tools/*, docs/*, _bmad/*, _bmad-output/*, build/*, .gutconfig.json`.

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. GUT skips a script that fails to parse and still exits 0, so grep the log for `Parse Error|Compile Error|Failed to load script` (CI does).
- Run `--import` after adding `words.json` and the new scripts so `class_name WordTagger` is registered before GUT runs.
- Baseline 1323 passing (Story 5.5). These tests don't touch the save; no real-save risk.
- To check rejections and exit codes by hand: run the tool with `-- --in=res://<scratch list> --out=res://<scratch json>` on a small bad list and check `echo $?`; delete the scratch files afterwards (don't commit them). The unit tests cover the rules; this is a smoke check of the I/O.

### Forward notes (for 6.2+, don't implement here)

- `WordSource` loads `words.json` via `load()`; `length` is a float in the parsed data. The band (3–5 before Epic 7) belongs in `data/levels/horde_rush.tres` / `LevelConfig`, not as literals.
- Already in `deferred-work.md` for 6.2: `TypingSession` has no `target_completed` yet and returns `WRONG` on an exhausted source; word mode must pass the cursor character to `ZombieHands.show_char()`; the word sign width is unclamped above ~9 letters.
- Before Epic 7 the band is 3–5, so no ≥6-letter word reaches Horde Rush; Story 6.3's big brute class can only be seen through tests or a debug band until tiers arrive. Mention it in 6.3, not here.

### Previous story intelligence

- **5.5:** last MVP story; v1.0.0 published from a `v*` tag. Suite at 1323 passing. Lessons kept: edit story-file sections line-anchored (a whole-section replace once cut half a story in 5.2); LF endings for new text files (`.gitattributes` is `* text=auto eol=lf`); gates as one `AskUserQuestion` per decision, recommendation first, answer recorded verbatim with the date; record Smuck's skips/passes as Smuck's call, not as measured.
- **5.2:** new *player-facing* copy must go into `test_plain_words.gd` `APPROVED_COPY` and EXPERIENCE.md. Word-list words are content, not UI copy, and nothing shows them yet — no copy-test change in this story.
- **2.6 (finger map):** the offline-generator + independent-test-oracle pattern this story repeats.

### Git intelligence

- One commit per story on `main`, then a "(code review patches applied, done)" commit after review: e.g. `90bebbd Story 5.5: code review patches applied, done`. Use `Story 6.1: word tagging tool and starter word list`.
- Expected changes: `scripts/typing/word_tagger.gd` (+ `.uid`), `tools/tag_words.gd` (+ `.uid`), `tools/word_lists/starter_words.txt`, `data/content/words.json`, `tests/unit/test_word_tagger.gd` (+ `.uid`), `tests/unit/test_word_list.gd` (+ `.uid`), `export_presets.cfg`, `tests/unit/test_export_presets.gd`, this story file, `sprint-status.yaml`. Nothing under `assets/`, `scenes/`, `scripts/autoloads/`, `.github/`, `project.godot`.
- No tag push: Horde Rush isn't published until after Story 6.8 (sprint change proposal Q1).

### Project Structure Notes

- New folders: `data/content/` (architecture-planned) and `tools/word_lists/` (new, export-excluded via `tools/*`).
- `scripts/typing/word_tagger.gd` is not in the architecture tree; it fits the folder's purpose ("key filtering, judgment, stats, target sources" — pure typing curriculum logic) and the rule that pure, tested logic lives there. Variance noted, no conflict.

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md`, the GDD and the UX spines:
  - Boundaries 1 (pure `scripts/typing/`), 3 (file I/O only in `SaveService` for the shipped game), 5 (`data/` holds instances and generated JSON).
  - D5: static data as typed Resources; generated content as JSON under `res://data/content/`, produced by the headless GDScript tool (no Python toolchain).
  - Consistency rules: static typing, tests for every class in `scripts/typing/`, CI fails on any GUT failure.
  - NFR9/NFR10 and GDD *Content*: kid-safe words only, reviewed by Smuck by hand.
  - Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, Godot MCP available (not needed here).

### Latest tech information

- No new libraries. Verified locally on Godot 4.7.2 (2026-10-07): `load("res://x.json")` returns a `JSON` resource; `(res as JSON).data` is the parsed value; integers come back as `float`. `JSON.stringify(data, indent, sort_keys = true, full_precision = false)`. `OS.get_cmdline_user_args()` returns the arguments after `--`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.1: Word Tagging Tool and Starter Word List] (ACs); Epic 6 header; Stories 6.2, 6.3, 7.3, 7.4, 7.5 (consumers)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR59, FR62, FR65, FR66; Additional Requirements → Data ("Post-MVP generated content as JSON in `res://data/content/`, produced by a headless GDScript tool (`tools/tag_words.gd`)")
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] *Curriculum* row table; *Adaptive Difficulty* tier table (length bands); *Content: Word Lists & Paragraphs*
- [Source: _bmad-output/game-architecture.md] D5, Static Game Data, Directory Structure (`data/content/`, `tools/`), Architectural Boundaries 1/3/5, Consistency Rules, Export exclusions
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] Story 2.5 word-sign width note; TypingSession notes for Epic 6
- [Source: tools/gen_finger_map.gd], [scripts/typing/letter_bag_source.gd], [tests/unit/test_finger_map.gd], [tests/unit/test_export_presets.gd], [export_presets.cfg:9,45]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Red phase: `test_word_tagger.gd` failed to parse (`Identifier "WordTagger" not declared`) before `word_tagger.gd` existed; green after `--import`.
- Tool smoke check on a scratch list (outside the project, deleted afterwards): `Dad` uppercase, `it's` non-letter, second `dog` "duplicate of line 2", `watermelon` too long, band check failure → accepted word still written, exit 1. Missing input file → `File not found`, exit 1. Default run → exit 0.
- First draft of the list had 377 words; trimmed to 246 (the story's ~220–250 target, a shorter review) by dropping function words and rarer nouns.
- Suite: 1344 passing, 0 failing, 0 `Parse Error|Compile Error|Failed to load script`. The suite before this story counted 1326 here, not the 1323 the story states (1337 after adding only the 11 tagger tests); +18 new tests (11 tagger, 6 word list, 1 export presets).

### Completion Notes List

- `WordTagger` (`scripts/typing/word_tagger.gd`): pure static class; GDD row constants, `MIN_LENGTH` 2 / `MAX_LENGTH` 8, `rows_for` (canonical home/top/bottom order), `rejection_reason` (uppercase → non-letter → too short → too long), `tag_lines` (strips ``/whitespace, skips blank and `#` lines, first duplicate wins, sorted output), `count_in_band` (accepts parsed JSON floats).
- `tools/tag_words.gd`: headless `SceneTree` tool in the `gen_finger_map.gd` style; `-- --in= --out=` overrides for Story 7.4; prints rejections with line numbers, per-length and per-row-set summary and the 3–5 band check; writes `{schema: 1, source, words}` with tabs and no timestamp (re-runs give no diff); writes accepted words even on rejections, then exits 1.
- `tools/word_lists/starter_words.txt`: 246 kid-safe words (191 in 3–5), LF, `#` header with the rules. Approved by Smuck as is (see Word List Review).
- `data/content/words.json` generated and committed; `include_filter="data/content/*.json"` on both presets, guarded by `test_both_presets_include_content_json`.
- Tests: `test_word_tagger.gd` (independent row-table oracle, the epic's `quiz` correction, all rejection rules, whitespace, blanks/comments, sort, band count) and `test_word_list.gd` (JSON resource + schema, ≥200 words, ≥150 in band, no duplicates, sorted, every entry equals a fresh tag, equals the tagged source list, banned-word backstop).
- No new `deferred-work.md` entries: nothing new for 6.2 beyond the forward notes already listed.

### File List

- `scripts/typing/word_tagger.gd` (new) + `.uid`
- `tools/tag_words.gd` (new) + `.uid`
- `tools/word_lists/starter_words.txt` (new)
- `data/content/words.json` (new, generated)
- `tests/unit/test_word_tagger.gd` (new) + `.uid`
- `tests/unit/test_word_list.gd` (new) + `.uid`
- `tests/unit/test_export_presets.gd` (modified)
- `export_presets.cfg` (modified)
- `_bmad-output/implementation-artifacts/6-1-word-tagging-tool-and-starter-word-list.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- 2026-10-07: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-07: Implemented WordTagger, tools/tag_words.gd, 246-word starter list (Smuck approved as is), words.json shipped in both presets, 18 new tests (suite 1344 passing). Status → review.
