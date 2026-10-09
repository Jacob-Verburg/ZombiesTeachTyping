---
baseline_commit: ee3dcb149b24ec2133b8667293b8a4c7b1d18791
---

# Story 7.3: Master Word List

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a parent,
I want a big list of safe, familiar words,
so that my kid practises real words and never sees anything inappropriate.

## Acceptance Criteria

1. **Master list authored (FR65).** `tools/word_lists/master_words.txt` holds about 1,500 lowercase words (accepted range 1,400–1,600 after review), one per line, same format and header style as `starter_words.txt` (LF endings, `#` header with the rules, blank and `#` lines skipped, grouped by length with `# N letters` comments). Every line passes `WordTagger.rejection_reason` (a–z only, 2–8 letters) and there are no duplicates.
2. **Superset of the starter list.** Every word in `tools/word_lists/starter_words.txt` (246 words, already approved by Smuck in Story 6.1) is also in the master list, so Horde Rush's current words stay available once Epic 7 switches to tier pools.
3. **Dolch cross-check (FR65).** `tools/word_lists/dolch_words.txt` is the public-domain Dolch sight-word reference (pre-primer, primer, grade 1, 2, 3 and the 95 nouns; about 315 words). It is committed as reference data, with the source and licence noted in its header. A test checks every Dolch word that fits the tagger's rules (a–z, 2–8 letters; so no apostrophe forms) is in the master list, except words on an explicit, reasoned exclusion list kept in the test (e.g. a Dolch word that is on the safety ban list). The master list is a superset of Dolch minus those recorded exclusions.
4. **Kid-safe (FR65, NFR9, NFR10).** The list excludes scary, violent, rude, toilet, insult and brand words, names and places, and words with a common rude second meaning (the 6.1 rules, Task 3.2 there). A banned-word backstop in the tests lists the examples from 6.1 plus more; it is a backstop, the human review is the gate.
5. **Fits Epic 7's pools.** The list is authored so Story 7.4 can meet its minimums (FR66, FR62): see *Tier pool feasibility* in Dev Notes. A test counts, per tier, the master words that use only the tier's rows within its length band, and the story file records the numbers. Tier 1 (home row, 2–3 letters) must be counted **first**; if it can't reach 40, that is raised to Smuck at the review gate, not silently lowered.
6. **Smuck review gate, before any build uses the list (FR65).** Smuck reviews the whole list by hand once. Removals are applied, the list is re-checked (tests, counts), and the review (date, the question, Smuck's answer verbatim, removed words, final counts) is recorded in this file's **Word List Review** section. Until that section is filled in, the story is not done.
7. **Not used by any build yet.** `master_words.txt` and `dolch_words.txt` live in `tools/` (export-excluded). `data/content/words.json` is **not** regenerated or changed in this story, and no game code reads the master list. Story 7.4 generates the tier pools from it.
8. **Tests.** A GUT test (`tests/unit/test_master_word_list.gd`) guards the file: size range, format and rules via `WordTagger`, no duplicates, sorted within each length group (or the stated order), starter superset, Dolch coverage, banned-word backstop, tier-pool counts (AC 5). Full suite stays green.

## Tasks / Subtasks

- [x] **Task 1: Dolch reference list** (AC: 3)
  - [x] 1.1 Create `tools/word_lists/dolch_words.txt`: one lowercase word per line, `#` header naming the source (Edward W. Dolch's sight-word lists, 1936 and 1948, public domain), the levels, and why it is here (FR65 cross-check). Include the 220 service words (pre-primer 40, primer 52, grade 1 41, grade 2 46, grade 3 41) and the 95 nouns. Write it from the published lists; keep apostrophe-free spellings as the list has them, and for any entry the tagger can't take (none expected; Dolch has no apostrophes or capitals) leave it out and note it in the header.
  - [x] 1.2 Run `tools/tag_words.gd` on it with `-- --in=res://tools/word_lists/dolch_words.txt --out=res://tools/word_lists/_scratch_dolch.json` to prove it parses (expect the starter-band check to **fail**: it is parameterised for the starter list, see deferred item; ignore that exit code or add the flag in Task 4). Delete the scratch JSON. Don't commit it.
- [x] **Task 2: Author the master list** (AC: 1, 2, 4, 5)
  - [x] 2.1 Start from `starter_words.txt` (all 246 words go in) and the Dolch list (minus recorded exclusions). Add everyday kid vocabulary until the list reaches about 1,500: animals, food, home, school, play, nature, weather, colours, numbers as words (`one`..`ten`, `twelve`), family, clothes, transport, actions, feelings, and plain adjectives. Aim for 6–8-year-old reading level (GDD *Content*); a 13-year-old should not find it babyish, so include some 6–8 letter words (`garden`, `bicycle`; nothing over 8 letters).
  - [x] 2.2 **Count tier-1 first.** Before writing the bulk, list every kid-safe word made only of `a s d f g h j k l` (2–3 letters) and count it. Record the number in Completion Notes. See *Tier pool feasibility*.
  - [x] 2.3 Length mix (a guide, not a test): 2 letters ~25, 3 letters ~200, 4 letters ~350, 5 letters ~350, 6 letters ~280, 7 letters ~180, 8 letters ~115. The tier bands (2–3, 3–4, 3–5, 4–6, 5–8) must each have real choice, and tiers 4–5 need long words.
  - [x] 2.4 Content rules, from 6.1 (apply strictly; when in doubt, leave it out): no scary or death words (`dead`, `kill`, `die`, `bone`, `grave`, `skull`, `blood`, `bite`, `ghost`, `monster`, `scary`, `evil`), no violence or weapons (`gun`, `hit`, `punch`, `fight`, `war`, `sword`, `knife`, `bomb`, `shoot`, `hurt`), no rude, toilet or insult words (`butt`, `poop`, `fart`, `dumb`, `stupid`, `ugly`, `fat`, `hate`, `shut`, `sex`, `pee`, `bum`), no drug, alcohol or adult words (`beer`, `wine`, `drunk`, `drug`), no brands, names or places (`lego`, `oreo`, `nike`, a first name, a city), no words with a common rude or violent second meaning (`ass`, `cock`, `dick`, `hell`, `damn`, `crap`, `piss`, `slut`, `gay` as a slur-use risk: leave out; `bang`, `choke`, `strike`). Zombie slang words that appear as NFR10 "flavour" (`brain`, `brains`, `zombie`) are fine only if already in the starter list; do not add new gore words (`gore`, `rot`, `flesh`).
  - [x] 2.5 Words must be real, common English: no abbreviations, no plurals-only oddities, no obscure words padded in to hit the 40 (see Task 2.2).
  - [x] 2.6 Format: header (what it is, the rules, "Reviewed by Smuck: see the Word List Review in the Story 7.3 file", plus the date of the review once done), then `# 2 letters` … `# 8 letters` groups, each sorted alphabetically. LF endings (`.gitattributes` is `* text=auto eol=lf`).
- [x] **Task 3: Run the tagger over it** (AC: 1, 7)
  - [x] 3.1 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/tag_words.gd -- --in=res://tools/word_lists/master_words.txt --out=res://tools/word_lists/_scratch_master.json`. Zero rejections is required. Read the per-length and per-row-set summary and record it. Delete the scratch JSON afterwards (the real tier pools come in 7.4). **Do not** write `data/content/words.json`.
  - [x] 3.2 The tool's starter-band check (>= 150 words of 3–5) will pass for the master list (it has hundreds). Leave `tag_words.gd` alone unless the run fails for another reason; Story 7.4 owns tool changes.
- [x] **Task 4: Tests** (AC: 2, 3, 4, 5, 8)
  - [x] 4.1 `tests/unit/test_master_word_list.gd` (new). Read both files with `FileAccess.get_file_as_string` (tests may read files; `tests/unit/test_word_list.gd` already re-tags the starter source the same way). Use `WordTagger.tag_lines` for the rules; assert `rejected` is empty.
  - [x] 4.2 Assertions: not vacuous (non-empty before any loop assertion; 6.1's review found vacuous passes); 1,400–1,600 words; no duplicates; every starter word present; every fit-able Dolch word present except the `DOLCH_EXCLUSIONS` constant (each with a one-line reason as a comment); no word in `BANNED` (the 2.4 examples; exact match only, document that it is a backstop); per-length counts each >= a floor (e.g. 2-letter >= 15, 3 >= 150, 4–5 >= 250, 6 >= 200, 7 >= 120, 8 >= 70) so a lopsided list fails.
  - [x] 4.3 Tier-pool counts as an **independent oracle**: write the three row strings out again in the test (`"asdfghjkl"`, `"qwertyuiop"`, `"zxcvbnm"`; do not import them from `WordTagger`, same rule as `test_word_tagger.gd`). Per tier (tier 1: letters in home only, 2–3; tier 2: home+top, 3–4; tier 3: all, 3–5; tier 4: all, 4–6; tier 5: all, 5–8) count the master words that fit. Assert tier 1 >= `TIER1_MIN` (40, from FR66 / the 7.4 AC; see feasibility) **or**, if Smuck's review gate records a different decision, the recorded number; assert tiers 2–5 >= 100 (the 7.4 minimum), with the real counts in Completion Notes.
  - [x] 4.4 No change to `test_word_list.gd` (it guards `words.json` and the starter list); it must still pass unchanged.
- [x] **Task 5: Smuck review gate** (AC: 6)
  - [x] 5.1 Show Smuck the list. 1,500 words is long: present it grouped by length in compact lines (one line per ~12 words), and separately call out the borderline words you kept and the "when in doubt" words you left out. Open `tools/word_lists/master_words.txt` in the file pane (inside the session folders).
  - [x] 5.2 Ask with `AskUserQuestion`, one decision per question, recommendation first: (a) is the list OK to ship / which words to remove (Other: list them); (b) only if Task 2.2 found tier 1 can't reach 40: how to handle it (options in *Tier pool feasibility*).
  - [x] 5.3 Apply removals; re-run Task 3 and the new tests; if removals drop a tier count below its minimum, add replacement words (and show Smuck only the additions), then re-run.
  - [x] 5.4 Fill in **Word List Review** below: date, the exact question, Smuck's answer verbatim, removed words, final counts per length and per tier. Record Smuck's call as Smuck's call.
- [x] **Task 6: Wrap-up**
  - [x] 6.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command (Testing notes). Baseline **1721** passing (Story 7.2). Record the new total. Grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 6.2 Commit new `.uid` files (only the new test script gets one; `.txt` files don't).
  - [x] 6.3 `deferred-work.md`: add a "Deferred from: dev of story 7-3" section only for new items. Known ones are listed under *Forward notes*; don't duplicate. Strike the 6.1 deferral "The starter-band check (>=150 words of length 3-5) runs on any `--in` list; Story 7.4's master list may need it relaxed or parameterised" only if you change the tool (you shouldn't here).
  - [x] 6.4 Mark sprint-status `7-3-master-word-list: review` when done (dev-story does this).

### Review Findings

Code review 2026-10-08 (Blind Hunter, Edge Case Hunter, Acceptance Auditor; no layer failed). No ACs violated.

- [x] [Review][Patch] `master_words.txt` header says "Reviewed by Smuck" but carries no review date (Task 2.6 asks for it) [tools/word_lists/master_words.txt:7]
- [x] [Review][Patch] Word List Review section still opens with the "_To be filled in at the review gate_" placeholder above the filled-in content [7-3-master-word-list.md: Word List Review]
- [x] [Review][Patch] `test_dolch_reference_parses_cleanly` accepts 300-320 words; the file has exactly 310, so losing up to 10 Dolch words would pass silently. Pin to 310 [tests/unit/test_master_word_list.gd:141]
- [x] [Review][Defer] `test_lf_endings` checks only `master_words.txt`, not `dolch_words.txt` or `starter_words.txt` [tests/unit/test_master_word_list.gd] — deferred, low risk: the tagger already rejects a stray `\r`

## Word List Review

- **Date:** 2026-10-08
- **Shown:** the whole list (1,512 words) in chat, grouped by length; the borderline keeps (`gag gags gas pea bun flash jigsaw frozen coffee wolf`, plus Dolch `fire` and `cut`); the "when in doubt" omissions (`hurt` (Dolch), `high flask cracker kick nut nuts pot bottom bull donkey turkey peacock beaver meat sausage nail horn bar hunt trap arrow dragon witch fairy toilet`, home-row near-words `hag hash lash slag shag sass haha jag dag hah la`, names, months, days, places, name-flowers `lily daisy holly`); and the tier 1 count (21 at 2–3 letters; 40 at 2–4; 48 at 2–5). File: `tools/word_lists/master_words.txt`.
- **Question:** (a) "Is the 1,512-word master list OK to ship, or which words should come out?" Options: Ship as is (Recommended) / Remove the borderline keeps. (b) "Only 21 home-row words fit tier 1's 2-3 letter band (minimum is 40). How should tier 1 work?" Options: Widen band to 2-4 (Recommended) / Widen band to 2-5 / Keep 2-3, minimum 21.
- **Smuck's answer (verbatim):** (a) "Ship as is (Recommended)" (b) "Widen band to 2-4 (Recommended)"
- **Removed words:** none at the gate (Smuck's call). Before the gate the author left out `high`, `flask`, `cracker` and Dolch `hurt` (recorded in `DOLCH_EXCLUSIONS`).
- **Final counts:** 1,512 words. Per length: 2: 30, 3: 223, 4: 355, 5: 323, 6: 273, 7: 180, 8: 128. Per tier: tier 1 (home, **2–4** per Smuck's decision) 40 (2–3 would be 21); tier 2 (home+top, 3–4) 304; tier 3 (all, 3–5) 901; tier 4 (all, 4–6) 951; tier 5 (all, 5–8) 904. Tier 1's 40 is exact: any home-row removal fails the test on purpose. Decision noted for 7.4/7.5 in `deferred-work.md` (FR62 / GDD tier table still say 2–3).

## Dev Notes

### What this story is (and isn't)

- It is: a hand-authored data file (`master_words.txt`), a committed Dolch reference list, one test file, and Smuck's one-time review. The deliverable is the *content* and its guarantees.
- It isn't: tier pools or the pool validation report (7.4), any change to `tools/tag_words.gd` or `WordTagger` (7.4), a runtime loader, a change to `words.json`, `WordSource`, `LevelConfig`, `TierConfig` or `PlayerData` (7.5). No scene, autoload, save, asset or `project.godot` change.
- Horde Rush keeps using the 246-word starter `words.json` (3–5 letters) until Story 7.5. Don't touch it: a changed `words.json` would break `test_word_list.gd`'s stale-JSON guard and change shipped gameplay before the review.

### Tier pool feasibility (read before writing the list)

- Tier pools (FR62/FR66) are words using **only** the tier's rows within its length band:

  | Tier | Allowed letters | Length band | 7.4 minimum |
  |---|---|---|---|
  | 1 | home `asdfghjkl` | 2–3 | **40** home-row words (GDD *Content*, FR66) |
  | 2 | home + top (`asdfghjkl` + `qwertyuiop`) | 3–4 | 100 |
  | 3 | all 26 | 3–5 | 100 |
  | 4 | all 26 | 4–6 | 100 |
  | 5 | all 26 | 5–8 | 100 |

- **Tier 1 is the hard one.** Real kid-safe English words from only `a s d f g h j k l` and 2–3 letters are few: `ad ah as ha la`, `add ads aha all ash ask dad fad gag gal gas had has jag lad lag sad sag` and not much else. That is roughly 20–25, **below the 40 the GDD and 7.4 require** (the GDD's own example list includes `flag`, which is 4 letters and so outside the 2–3 band). This is the author's estimate, not measured: count it for real in Task 2.2.
- If the real count is under 40, do **not** pad with obscure or nonsense words and do not lower the number yourself. Raise it at the review gate with these options (recommendation: the first), because each changes a planning document:
  1. Widen tier 1's Horde Rush length band to 2–4 (`flag`, `fall`, `hall`, `glass`-type 4-letter words; likely enough for 40), which edits FR62 / the GDD table and Story 7.5's band list.
  2. Keep 2–3 and lower tier 1's minimum to the real count, with the reason recorded (an AC change in 7.4).
  3. Keep 2–3 and add a handful of valid-but-uncommon words (`dag`, `hah`, `kas`), which hurts the "words a 6-year-old knows" rule (NFR9).
- Whatever Smuck decides, the master list itself just needs to contain every valid kid-safe home-row word it can; the decision only changes the thresholds in the test and in 7.4. Record it and the number in this file and as a note for 7.4 in `deferred-work.md`.
- Tier 2 (home + top, 3–4) and the others are easy by comparison, but check tier 2's count as well: with no bottom-row letters (`z x c v b n m`) it excludes words like `can`, `man` and `bad`. Count, don't assume.

### Design decisions already made (follow them)

- **Source and tool location:** word lists live in `tools/word_lists/` (export-excluded through `tools/*`), next to `starter_words.txt`. `master_words.txt` is the master for Story 7.4's `--in=`.
- **Format = the starter list's format** so `tools/tag_words.gd` and `WordTagger.tag_lines` take it as is: one lowercase word per line, `#` comments, 2–8 letters, no repeats. Reject, don't fix: a bad line must surface as a rejection, not be silently changed.
- **Length cap 8** is `WordTagger.MAX_LENGTH`: the HUD word sign fits ~9 letters (`deferred-work.md`, Story 2.5 / 6.2 notes), and tier 5's band stops at 8.
- **Authored by Claude, reviewed by Smuck** (GDD *Content*, FR65). The Dolch cross-check is *coverage* (Dolch words are in), not a safety filter: Check each Dolch word against the ban list and record any exclusion with its reason (words to look at: `cut`, `hot`, `pull`, `kiss`; none are expected to be banned but decide on purpose).
- **Zombie-flavoured words** (`brain`, `zombie`, `hat`, `cake`, `frog`, `pizza`) are fun and welcome, but no gore. The kid is 6–13: neutral and goofy, never scary (NFR10).
- **Dolch list licensing:** Dolch's lists (1936/1948) are public domain; the FR65 text says "public-domain Dolch sight-word lists". Don't paste any third-party curated list verbatim beyond Dolch (no frequency lists, no Fry list: Fry's list is copyrighted).

### Existing code to read first (read only; nothing here is modified)

- **`tools/word_lists/starter_words.txt`**: the format, header wording and the approved 246 words. The master list starts from these.
- **`scripts/typing/word_tagger.gd`**: `ROW_HOME/TOP/BOTTOM`, `MIN_LENGTH` 2, `MAX_LENGTH` 8, `rows_for`, `rejection_reason`, `tag_lines` (strips `\r`/whitespace/BOM, skips blank and `#` lines, first duplicate wins, sorted output), `count_in_band`.
- **`tools/tag_words.gd`**: `-- --in= --out=` overrides, prints rejections with line numbers and the per-length / per-row summary, exits 1 on any rejection or if the 3–5 band has < 150 words. It does not validate `--in`/`--out` (deferred, dev tool).
- **`tests/unit/test_word_list.gd`** and **`tests/unit/test_word_tagger.gd`**: the patterns to copy: non-vacuous setup, independent row-table oracle, banned-word backstop, re-tagging the source file with `FileAccess`.
- **`data/content/words.json`**: the shipped starter data; must stay byte-identical (it is the only list the game reads, until 7.4/7.5).
- **`data/tier_config.tres` / `scripts/resources/tier_config.gd`**: the tier floors and placement. Story 7.4 may extend this with per-tier pools; **not here**.
- GDD *Adaptive Difficulty* and *Content: Word Lists & Paragraphs* (`_bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md`): the tier table above and the "master list ~1,500 words, Dolch cross-check, Smuck reviews once" text.

### Architecture and rules to follow

- Godot **4.7.2**, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed vars, typed arrays (`Array[String]`), typed returns, typed loop vars (`for w: String in words`). Tabs. `##` doc comments saying *why*. `snake_case` files, `UPPER_SNAKE` constants, test file `test_master_word_list.gd` in `tests/unit/`.
- Boundary 3 (only `SaveService` touches files) is about the shipped game; tests and offline tools may read files. No `FileAccess` goes into `scripts/`.
- Kid-safe content (NFR9, NFR10, FR65): the list is the only thing standing between a 6-year-old and a rude word on a zombie sign. Be strict; a smaller clean list beats a 1,500-word one with a bad word in it. If the list lands near 1,400 clean words, that is acceptable (AC 1 range).
- Export exclusions stay: `addons/gut/*, tests/*, tools/*, docs/*, _bmad/*, _bmad-output/*, build/*, .gutconfig.json`. `export_presets.cfg` is not touched.
- New player-facing copy: none (word-list words are content, not UI copy; `test_plain_words.gd` is unaffected, same as 6.1).

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. GUT skips a script that fails to parse and still exits 0, so grep the log for `Parse Error|Compile Error|Failed to load script` (CI does).
- Baseline **1721** passing, 89 scripts (Story 7.2 final). Expect +1 script and roughly 10 tests.
- Tests don't touch the save. Do `--import` after adding the new test script.
- Mutation check worth doing once: add a banned word, a duplicate and an uppercase word to a scratch copy of the list and confirm the test fails each time; revert (`cmp`-check the real file is unchanged).
- Authoring tip: write the list in length groups, then run the tagger and the test; the per-row summary shows quickly if a tier is thin.

### Previous story intelligence

- **6.1 (word list + review gate):** the review pattern to repeat: show the list grouped by length, list borderline keeps and "when in doubt" omissions, one `AskUserQuestion` with the recommendation first, record the answer verbatim with the date and the final counts. Code review there caught: a vacuous test when the JSON failed to load (assert non-empty first), tests that reproduced the tagger's own table (use an independent oracle), and band minimums duplicated in tool and test (keep a single constant). Its review also found the story and the measured baseline disagreeing: record the real total.
- **7.1:** per-level WPM weighting was decided (Smuck 2026-10-08: none now); unrelated to word content.
- **7.2:** `PlayerData` now places and tiers saves; the tier is hidden everywhere (`RANKS` self-check includes `\btier`). Nothing in this story may surface a tier to the kid: the master list and its tier counts live only in tools, tests and this file. Suite is 1721 passing.
- **Edit discipline:** edit story-file sections line-anchored (a whole-section replace once cut half a story in 5.2); `.gitattributes` forces LF; record Smuck's skips/passes as his call, not as measured.

### Git intelligence

- One commit per story on `main`, then a "(code review patches applied, done)" commit: latest are `ee3dcb1 Story 7.2: placement run and hidden tier, code review patches applied, done` and `35be6d9 Story 7.1 ...`. Use `Story 7.3: master word list`.
- Expected changes: `tools/word_lists/master_words.txt` (new), `tools/word_lists/dolch_words.txt` (new), `tests/unit/test_master_word_list.gd` (+ `.uid`), this story file, `sprint-status.yaml`, possibly `deferred-work.md`. **Not** expected: anything under `scripts/`, `scenes/`, `assets/`, `data/`, `export_presets.cfg`, `.github/`, `project.godot`.

### Forward notes (for 7.4 / 7.5, don't implement here)

- **7.4:** run `tools/tag_words.gd` on `master_words.txt` to write each tier's pool and a validation report; CI fails when a tier is under its minimum. The tool's hard-coded starter-band check (>= 150 in 3–5, `WordTagger.STARTER_BAND_*`) and its default `--in/--out` need parameterising there (already in `deferred-work.md`). Tier 1's 40-word minimum depends on the decision recorded in this story's review (see feasibility).
- **7.4/7.5:** `words.json` today is the *starter* list tagged by the same tool; when 7.4 writes tier pools, keep `LevelConfig.word_list`, `WordSource.pool_from_json` and `test_word_list.gd` consistent (7.5 wires the tier into `WordSource` instead of the fixed 3–5 band).
- **Web export:** `deferred-work.md` still asks to verify a real web export loads `data/content/*.json` via `load()`; relevant when 7.4's new JSON ships.
- **8.1:** tiers 1–2 generate sentences at runtime from the tier's pool (4–7 words), so the pools must hold enough variety for sentence building; another reason to keep tier 1 and 2 as large as honestly possible.

### Project Structure Notes

- `tools/word_lists/` already exists (6.1) and is export-excluded. Adding `master_words.txt` and `dolch_words.txt` there needs no structural change. The test goes in `tests/unit/` like every other.
- Variance: the architecture tree doesn't list `tools/word_lists/`; 6.1 already established it. No conflict.

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md`, the GDD and the UX spines:
  - D5: static data as typed Resources; generated content as JSON under `res://data/content/`, produced by the headless GDScript tool (no Python toolchain). The master list is source text for that tool, not a runtime asset.
  - Consistency rules: static typing; tests for every new unit; CI fails on any GUT failure.
  - NFR9/NFR10 and GDD *Content*: kid-safe words only, reviewed by Smuck by hand.
  - Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1.

### Latest tech information

- No new libraries or engine features. Verified in 6.1 on Godot 4.7.2: `OS.get_cmdline_user_args()` returns args after `--`; `FileAccess.get_file_as_string` works for `res://tools/...` in the editor/headless runs (tools are not in exports, and neither are tests).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 7.3: Master Word List] (ACs); Stories 7.4 and 7.5 (consumers); Story 6.1 (starter list, tool, review gate)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR62, FR65, FR66; NFR9, NFR10
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] *Adaptive Difficulty* (tier table), *Content: Word Lists & Paragraphs*, *Curriculum* (row table)
- [Source: _bmad-output/implementation-artifacts/6-1-word-tagging-tool-and-starter-word-list.md] format, review pattern, review findings
- [Source: _bmad-output/implementation-artifacts/7-2-placement-run-and-hidden-tier.md] baseline, hidden-tier rule
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 6.1 deferrals on `tag_words.gd` (band check, `--in/--out`, web-export load check)
- [Source: scripts/typing/word_tagger.gd], [tools/tag_words.gd], [tools/word_lists/starter_words.txt], [tests/unit/test_word_list.gd], [tests/unit/test_word_tagger.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- `tools/tag_words.gd` on `dolch_words.txt`: accepted 310, rejected 0 (3–5 band 255, so the starter-band check passed too). Scratch JSON deleted.
- `tools/tag_words.gd` on `master_words.txt`: accepted 1512, rejected 0; length 2: 30, 3: 223, 4: 355, 5: 323, 6: 273, 7: 180, 8: 128; rows home 48, home+bottom 35, home+top 496, home+top+bottom 747, top 40, top+bottom 146; 3–5 band 901. Scratch JSON deleted; `data/content/words.json` unchanged.
- First GUT run of the new test (before the review gate): only `test_tier_pools_have_enough_words` failed, tier 1 21 < 40 (expected red; raised at the gate).
- Mutation check: appended `gun`, a second `cat` and `Dog` to the real list, ran the test: duplicate + uppercase rejected, `gun` caught by the banned check, group/sort checks failed too; restored from backup, `cmp` identical.
- Final suite: 1734/1734 passing, 90 scripts, 0 Parse/Compile/Failed-to-load lines. The story's 1721 baseline predates Story 7.2's code-review patches; HEAD's baseline is inferred as 1724 (1734 minus the 10 new tests), not separately measured.

### Completion Notes List

- **Tier 1 count (Task 2.2), measured first:** home row `asdfghjkl`, 2–3 letters = **21** (`ad ah as ha` + `add ads aha all ash ask dad fad gag gal gas had has lad lag sad sag`). `a` is the only home-row vowel, so this is the complete kid-safe set. 2–4 letters = 40, 2–5 = 48. Raised at the gate; Smuck chose to widen tier 1's band to 2–4 (minimum stays 40).
- **Dolch reference** (`dolch_words.txt`): 220 service words + 95 nouns written from Dolch's published public-domain lists; `a`, `I`, `don't`, `Christmas`, `Santa Claus` left out (tagger can't take them) and noted in the header, so 310 words. Only Dolch exclusion from the master list: `hurt` (Story 6.1 ban list). `cut`, `hot`, `pull`, `drink`, `fire` checked and kept on purpose (`kiss` isn't a Dolch word; not added).
- **Master list** (`master_words.txt`): 1,512 words = all 246 starter words + Dolch (minus `hurt`) + everyday kid words by theme, US spelling (matching `mom`/`color`), grouped `# 2 letters`..`# 8 letters`, sorted, LF. Built from a scratch draft with a throwaway merge script (not committed). Every home-row word that passes the content rules is included.
- **Tests** (`tests/unit/test_master_word_list.gd`, 10 tests): non-vacuous load; 1,400–1,600; no rejected lines (rules + duplicates via `WordTagger.tag_lines`); LF only; groups 2..8 in order, each holding only its length, sorted; per-length floors; starter superset; Dolch file parses cleanly (300–320 words); Dolch coverage minus `DOLCH_EXCLUSIONS` (and each exclusion must really be a Dolch word and really absent); banned-word backstop (6.1/7.3 examples plus the author's leave-outs); tier counts with an independent row table (tier 1 home 2–4 >= 40 per Smuck; tiers 2–5 >= 100). `test_word_list.gd` untouched and passing.
- Smuck review gate done (see Word List Review): shipped as is; tier 1 band widened to 2–4. Note for 7.4/7.5 added to `deferred-work.md`. `tag_words.gd`, `WordTagger`, `words.json` and all game code unchanged.

### File List

- `tools/word_lists/master_words.txt` (new)
- `tools/word_lists/dolch_words.txt` (new)
- `tests/unit/test_master_word_list.gd` (new)
- `tests/unit/test_master_word_list.gd.uid` (new)
- `_bmad-output/implementation-artifacts/7-3-master-word-list.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`

## Change Log

- 2026-10-08: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-08: Story 7.3 implemented — Dolch reference list (310), 1,512-word master list, `test_master_word_list.gd` (10 tests, 1724 → 1734), Smuck review gate passed (ship as is; tier 1 band widened to 2–4). Status → review.
