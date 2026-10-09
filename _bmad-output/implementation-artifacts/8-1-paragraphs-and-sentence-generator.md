---
baseline_commit: c46e72066f92f18ab29a8ee8b986e612be40c608
---

# Story 8.1: Paragraphs and Sentence Generator

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want funny zombie stories to type, and simple sentences when I'm still learning,
so that practising real writing feels like part of the game.

## Acceptance Criteria

1. **Paragraph file (FR67).** `data/content/paragraphs.json` holds about 40 original passages that are goofy, zombie-themed and in plain words: 13 per tier for tiers 3, 4 and 5 (each tier 12–15, total 38–42). Each passage has 2–4 sentences and 150–400 characters. The shape is `{"schema": 1, "passages": [{"id": "t3_01", "tier": 3, "text": "..."}, ...]}`, tab-indented with LF endings and a final newline. Every `id` is unique and never reused.
2. **Tier character rules (FR67, GDD tier table).** A validator confirms:
   - Tier 3 uses only `A–Z a–z`, Space and `. , ! ?`.
   - Tier 4 adds the digits `0–9` and the apostrophe `'`. Every tier 4 passage uses at least one digit or apostrophe.
   - Tier 5 may use any character in the game's typeable set (every character `data/finger_map.tres` maps). Every tier 5 passage uses at least one character outside tier 4's set.
   - Every passage passes the shared format rules in *Validator rules* (Dev Notes): ASCII only, no doubled or edge spaces, capitalised sentences, end punctuation, no word longer than 12 characters, no ALL-CAPS words.
3. **Validator is code, and CI enforces it.** The rules live in a pure class, `ParagraphRules` (`scripts/typing/paragraph_rules.gd`). `tests/unit/test_paragraphs.gd` runs it over the shipped file and fails on any problem, so CI (GUT in `build.yml`) fails on bad content. `tests/unit/test_paragraph_rules.gd` proves each rule catches a bad passage.
4. **Kid-safe and hidden-tier-safe (NFR9, NFR10, FR60).** Passages follow the 7.3 content rules: nothing scary, violent, rude, or about toilets, brands or real names. There are no rank or difficulty words. A banned-word backstop in `test_paragraphs.gd` checks this. It is only a backstop; Smuck's review is the gate.
5. **Smuck review gate (AC "Smuck reviews the passages once").** Smuck reads all the passages once. Changes are applied and the file is re-validated. The review (date, the question, Smuck's answer verbatim, the passages changed or removed, final counts per tier) is recorded in this file's **Paragraph Review** section. The story is not done until that section is filled in.
6. **Sentence generator (FR67, FR62).** `SentenceGenerator` (`scripts/typing/sentence_generator.gd`, pure `RefCounted`) builds tier 1–2 sentences from a tier word pool using only the injected `RandomNumberGenerator`:
   - Each sentence has 4–7 words, a capital first letter and a single `.` at the end.
   - With commas allowed (tier 2), a sentence may also hold at most one `,`, attached to a word that is neither the first nor the last. Tier 1 never has a comma.
   - The same seed and pool always give the same sentences.
7. **Generator tests.** `tests/unit/test_sentence_generator.gd` covers:
   - word count, capitalisation and punctuation over many sentences,
   - that every word, lowercased and with its comma stripped, is in the tier pool (using the shipped `word_pools.json` tiers 1 and 2),
   - seed determinism,
   - tier 1 never having a comma and tier 2 having some,
   - small pools and bad inputs (null RNG, pool under 2 words, duplicates, invalid words): one error log, no crash, `next_sentence()` returns `""`.
8. **Nothing else changes.** No level, scene, `LevelConfig`, save schema, `TierConfig`, word list or `finger_map.tres` changes. `ParagraphSource`, the paragraph HUD, used-passage tracking and the v1 → v2 migration all belong to Story 8.2. The full GUT suite stays green.

## Tasks / Subtasks

- [x] **Task 1: `ParagraphRules` (pure validator)** (AC: 2, 3)
  - [x] 1.1 Create `scripts/typing/paragraph_rules.gd`: `class_name ParagraphRules extends RefCounted`. No nodes, no autoloads except `Log`, no file access. Follow `WordTagger`'s style: a class doc naming Story 8.1 / FR67, and constants for the content rules (see *Validator rules*).
  - [x] 1.2 Constants: `AUTHORED_TIERS: Array[int] = [3, 4, 5]`, `GENERATED_TIERS: Array[int] = [1, 2]`, `COMMA_TIERS: Array[int] = [2]`, `MIN_CHARS = 150`, `MAX_CHARS = 400`, `MIN_SENTENCES = 2`, `MAX_SENTENCES = 4`, `MAX_WORD_CHARS = 12`, `MIN_PER_TIER = 12`, `MAX_PER_TIER = 15`, `MIN_TOTAL = 38`, `MAX_TOTAL = 42`, `TIER3_PUNCTUATION = ".,!?"`, `TIER4_EXTRA = "0123456789'"`, `TIER5_EXTRA` (every mapped non-letter character not already allowed; see *Validator rules*).
  - [x] 1.3 `static func allowed_chars(tier: int) -> String`: letters + Space + that tier's extras, cumulative. Return `""` for a tier outside `AUTHORED_TIERS`.
  - [x] 1.4 `static func passage_problems(entry: Variant) -> Array[String]`: returns an empty array when the entry is valid; otherwise one short reason per rule broken. Bad data is reported, never asserted (NFR16). It must accept the parsed JSON, where numbers come in as floats.
  - [x] 1.5 `static func doc_problems(doc: Variant) -> Array[String]`: checks the schema is 1, `passages` is an Array, and every entry's problems (prefixed with its id or index). It also checks that ids and texts are unique, the per-tier count is within `MIN_PER_TIER..MAX_PER_TIER`, and the total is within `MIN_TOTAL..MAX_TOTAL`.
  - [x] 1.6 `static func sentence_count(text: String) -> int`: uses the counting rule in *Validator rules*. It is public so the tests and Story 8.2 can use it.
- [x] **Task 2: Author `data/content/paragraphs.json`** (AC: 1, 2, 4)
  - [x] 2.1 Write 13 passages per tier (39 total; 40 or 41 is fine if one tier has a 14th). Follow *Authoring guide* in Dev Notes for tone, length and the punctuation each tier uses.
  - [x] 2.2 Ids: `t3_01`…`t3_13`, `t4_01`…, `t5_01`…, in file order grouped by tier. Ids are save data from Story 8.2 on: never renumber or reuse one. Fix a passage in place and keep its id. If a passage is removed, retire its id.
  - [x] 2.3 Write the file by hand (no tool needed; the architecture's `tools/` pipeline is for generated content). Use tab indentation, LF line endings and a final newline. **ASCII only:** no curly quotes (`" " ' '`), em or en dashes, ellipsis characters or non-breaking spaces. Those can't be typed on the keyboard and the validator rejects them. Check with a grep for bytes > 0x7E before running tests.
  - [x] 2.4 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` so `load()` returns the new JSON resource. `data/content/*.json` is already in both export presets' `include_filter`, so it ships with no export change.
- [x] **Task 3: Validator tests** (AC: 3, 4)
  - [x] 3.1 `tests/unit/test_paragraph_rules.gd`: one test per rule, each with a bad passage that must fail it and a fixed good passage that passes. Cover: wrong tier, non-String text, too short or too long, 1 and 5 sentences, a tier 3 digit, a tier 3 apostrophe, a tier 4 `;`, tier 4 with no digit or apostrophe, tier 5 with only tier 4 characters, curly quote, em dash, tab or newline, double space, leading or trailing space, lowercase sentence start, missing end punctuation, a 13-character word, an ALL-CAPS word, a duplicate id, a duplicate text, and tier counts outside the limits. Test `sentence_count` on its edge cases (see *Validator rules*).
  - [x] 3.2 Cross-check `TIER5_EXTRA` against the real finger map. Load `res://data/finger_map.tres` and assert every character of `allowed_chars(5)` is a key of `entries`, so the hands can light every character the kid will see. Also assert `allowed_chars(3) ⊂ allowed_chars(4) ⊂ allowed_chars(5)`.
  - [x] 3.3 `tests/unit/test_paragraphs.gd` guards the shipped file:
    - It loads with `load("res://data/content/paragraphs.json") as JSON` and the data is non-empty (assert this before any loop; 6.1 lesson about vacuous passes).
    - `ParagraphRules.doc_problems(...)` is empty. Print each problem with `fail_test` so CI output names the passage.
    - Counts per tier are recorded in Completion Notes.
    - Banned-word backstop: split each passage into lowercase a–z tokens and check that none is in a `BANNED` list. Start from the 7.3 Task 2.4 examples (scary, death, violence, weapons, rude, toilet, adult) and add the NFR10 rank and difficulty words: `easy hard difficult beginner expert rank grade level tier noob pro`. Match exact tokens only and document that it is a backstop.
    - A check that every character in the file is in `finger_map.tres`'s `entries`, independent of the tier rules (belt and braces for Story 8.2's hands).
- [x] **Task 4: `SentenceGenerator`** (AC: 6)
  - [x] 4.1 Create `scripts/typing/sentence_generator.gd`: `class_name SentenceGenerator extends RefCounted`. Constants: `MIN_WORDS = 4`, `MAX_WORDS = 7` (FR67), and `COMMA_CHANCE = 0.5` (the chance that a comma-allowed sentence gets one; not a GDD number, so document it as a content choice).
  - [x] 4.2 `_init(rng: RandomNumberGenerator, pool: Array[String], allow_comma: bool)`.
    - **Don't `assert`:** the pool is content data (NFR16), and tests must reach the bad-input paths. Validate first: RNG not null, pool has at least 2 entries, no duplicates, and every word passes `WordTagger.rejection_reason(...) == ""`.
    - If anything fails, log one `Log.error(&"typing", ...)` line (no tier number in it, per FR60) and stay empty.
    - Build the internal `WordSource` only after validation passes. `LetterBagSource._init` asserts on a bad pool, and that would break the tests.
  - [x] 4.3 `static func for_tier(rng: RandomNumberGenerator, pool: Array[String], tier: int) -> SentenceGenerator`: sets `allow_comma = tier in ParagraphRules.COMMA_TIERS`. Story 8.2 calls this, so the tier-to-comma rule lives in one place.
  - [x] 4.4 `func next_sentence() -> String`. Fixed RNG draw order, so seeds replay:
    1. `count = _rng.randi_range(MIN_WORDS, MAX_WORDS)`.
    2. Take `count` words from the internal `WordSource` (`current()` then `advance()`). The bag gives every pool word once before any repeat and never the same word twice in a row.
    3. If `allow_comma`, roll `_rng.randf() < COMMA_CHANCE`. On a hit, put the comma after word `_rng.randi_range(1, count - 2)` (0-based, so never after the first or last word).
    4. Uppercase the first character of word 0 with `w.substr(0, 1).to_upper() + w.substr(1)`. **Don't use `String.capitalize()`**: it also rewrites underscores and camelCase, which is the wrong tool.
    5. Join the words with single spaces, attach the comma to its word (`"word,"`) and end with `"."`.

    Return `""` when the generator is empty.
  - [x] 4.5 No global `randi()`/`randf()` and no `Array.shuffle()`: only the injected RNG, via the `WordSource` bag (architecture: one RNG per run).
- [x] **Task 5: Generator tests** (AC: 7)
  - [x] 5.1 `tests/unit/test_sentence_generator.gd`. Load the real pools with `WordSource.tier_pool_from_json(load("res://data/content/word_pools.json") as JSON, tier, band.x, band.y)`, taking the band from `load("res://data/tier_config.tres") as TierConfig` `.word_band_of(tier)` for tiers 1 and 2. Assert each pool is non-empty first (tier 1 should have 40 words).
  - [x] 5.2 For 500 sentences per tier (seeded RNG), check:
    - the word count is 4–7, and every count 4..7 appears at least once;
    - character 0 is A–Z and the rest of the first word is lowercase;
    - the text ends with exactly one `.` and has no other `.`;
    - there are no double spaces and no leading or trailing space;
    - every word, after stripping `,` and lowercasing, is in the pool;
    - every character is in the tier's rows (independent row strings written out in the test: `"asdfghjkl"`, `"qwertyuiop"`) or is Space, `.`, `,` or an uppercase form of a row letter.
  - [x] 5.3 Commas:
    - tier 1 (`for_tier(..., 1)`): 0 commas in 500 sentences;
    - tier 2: some sentences have one and some have none;
    - no sentence has more than one;
    - a comma is never after the first or last word, and always comes before a space.
  - [x] 5.4 Determinism: two generators with the same seed and pool give the same 50 sentences. A different seed gives a different sequence.
  - [x] 5.5 Small pool: a 2-word pool (e.g. `["dad", "sad"]`) gives valid 4–7-word sentences with no word twice in a row.
  - [x] 5.6 Bad inputs: a null RNG, a 1-word pool, a duplicate pool, and a pool with an invalid word (`"Dad"` or `"a1"`). Each must give `next_sentence() == ""` with no crash. If the `Log` capture used elsewhere in the suite is available, also assert one error line (`grep -rn "Log\." tests/unit/test_word_source.gd` shows how 7.5 checked log output).
- [x] **Task 6: Smuck review gate** (AC: 5)
  - [x] 6.1 After the tests pass, show Smuck every passage in chat, grouped by tier, each with its id and character count. Open `data/content/paragraphs.json` in the file pane. Also show 10 sample tier 1 and 10 sample tier 2 generated sentences (seeded), so the generator's output is reviewed too.
  - [x] 6.2 Ask with `AskUserQuestion`, one decision per question, recommendation first:
    - (a) "Are the 39 passages OK to ship, or which should change?" Options: "Ship as is (Recommended)", "Change some" (Other: list ids and changes).
    - (b) "Are the generated tier 1–2 sentences OK?" Options: "Ship as is (Recommended)", "Adjust the comma chance or word count".
  - [x] 6.3 Apply the changes (keep ids), re-run the tests, and show only the changed passages again if anything changed.
  - [x] 6.4 Fill in **Paragraph Review** below: date, the exact questions, Smuck's answers verbatim, ids changed or removed, final counts per tier, and min/max characters per tier.
- [x] **Task 7: Wrap-up**
  - [x] 7.1 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command (Testing notes). The baseline was **1789** passing / 94 scripts at Story 7.5 (re-run first to confirm the baseline after its review patches). Record the new total, and grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 7.2 New `.uid` files for the 2 scripts and 3 tests are ready to commit. The existing `data/content/*.json` files have no `.import` sidecar in git; check `git status` after `--import` and list every new file (including any sidecar) in the File List.
  - [x] 7.3 `deferred-work.md`: add "Deferred from: dev of story 8-1" for new items only. The *Forward notes* below are already known; don't duplicate them.
  - [x] 7.4 Mark sprint-status `8-1-paragraphs-and-sentence-generator: review` when done (dev-story does this).

### Review Findings

- [x] [Review][Patch] Sentence end consumes only one closer, so `."` then `)` is not an end; a passage ending `.")` is rejected as "does not end with end punctuation" and the sentence count is understated [scripts/typing/paragraph_rules.gd:218]
- [x] [Review][Patch] `_char_problems` rebuilds `allowed_chars(tier)` on every character; hoist it out of the loop [scripts/typing/paragraph_rules.gd:156]
- [x] [Review][Defer] `SentenceGenerator.for_tier` accepts any tier silently (e.g. 0 or 3-5 gives word salad with no error) [scripts/typing/sentence_generator.gd:42] — deferred, belongs with 8.2 wiring
- [x] [Review][Defer] Generated tier 1-2 passages (2-4 sentences of 4-7 short words) cannot reach the 150-char minimum, so 8.2 must exempt generated passages or join more sentences [scripts/typing/sentence_generator.gd:49] — deferred, 8.2 design decision
- [x] [Review][Defer] `ParagraphRules` does not check id format or id/tier prefix; only the shipped-file test does, so 8.2's loader would accept `t4_03` with tier 3 [scripts/typing/paragraph_rules.gd:136] — deferred, 8.2 loader
- [x] [Review][Defer] Validator messages name tiers ("tier 3 has N passages"); keep them out of runtime logs in 8.2 (FR60) [scripts/typing/paragraph_rules.gd] — deferred, 8.2 logging
- [x] [Review][Defer] Generator replay depends on the shared RNG's call order and on `WordSource` internals; no golden-output test [scripts/typing/sentence_generator.gd:49] — deferred, document in 8.2
- [x] [Review][Defer] `test_paragraphs.gd` BANNED backstop uses exact tokens and includes common words (`hard`, `easy`, `level`) that may false-fail when 8.7 adds passages, and the test crashes rather than reports on malformed shipped JSON [tests/unit/test_paragraphs.gd] — deferred, revisit with 8.7

## Paragraph Review

**Date:** 2026-10-09. **Reviewer:** Smuck. The call is Smuck's.

All 39 passages were shown in chat, grouped by tier with id and character count, along with 10 seeded tier 1 sentences and 10 seeded tier 2 sentences (seeds 8101 and 8102). The file was linked in chat. Questions asked with `AskUserQuestion`:

- **(a) "Are the 39 passages OK to ship, or which should change?"**
  - Smuck's answer, verbatim: "Ship as is (Recommended)"
- **(b) "Are the generated tier 1–2 sentences OK?"**
  - Smuck's answer, verbatim: "Ship as is (Recommended)"

**Changed or removed:** none. All ids `t3_01`–`t3_13`, `t4_01`–`t4_13` and `t5_01`–`t5_13` ship as written, and no id is retired. `COMMA_CHANCE` (0.5) and `MIN_WORDS`/`MAX_WORDS` (4/7) are unchanged.

**Final counts:** 39 passages in total. Each row was re-validated by `test_paragraphs.gd` in the final run.

| Tier | Passages | Min chars | Max chars |
|---|---|---|---|
| 3 | 13 | 155 | 182 |
| 4 | 13 | 199 | 232 |
| 5 | 13 | 231 | 281 |

## Dev Notes

### What this story is (and isn't)

- **It is** three things: a content file (`paragraphs.json`), a pure validator (`ParagraphRules`) that CI runs on that file through GUT, and a pure `SentenceGenerator` for tiers 1–2. Plus their tests and Smuck's review.
- **It isn't** any of these, all of which are later stories:
  - `ParagraphSource` (the `TargetSource`), the 2-line paragraph HUD, Space joins, case-sensitive judging, used-passage tracking, the v1 → v2 save migration (all 8.2);
  - the Pitchfork Panic level, `pitchfork_panic.tres`, chase, pickups, endings (8.3–8.5);
  - any art or audio (8.6) and tuning (8.7).

  No scene, autoload, `LevelConfig`, `TierConfig`, `finger_map.tres`, word list or `project.godot` change.

### Validator rules (the contract `ParagraphRules` implements)

**Entry shape**
- A Dictionary with `id` (non-empty String), `tier` (a JSON number equal to 3, 4 or 5; compare with `int(...)`, and reject `3.5`) and `text` (String).
- Unknown extra keys are allowed and ignored, matching the save's "keep unknown fields" rule.

**Characters**
- Every character is printable ASCII (codes 32–126), and in `allowed_chars(tier)`:
  - Tier 3: `A–Z a–z`, Space, `. , ! ?`
  - Tier 4: tier 3 + `0–9` + `'`
  - Tier 5: tier 4 + `TIER5_EXTRA`. That is the rest of `finger_map.tres`'s non-letter keys: `; : - " ( ) / = + _ @ # $ % ^ & * < >`.

  Write `TIER5_EXTRA` out as a constant. Test 3.2 proves every character is mapped. `` ` ~ [ ] { } \ | `` are **not** mapped (`tools/gen_finger_map.gd` header, deferred-work 2.6) and must never appear.
- Tier 4 passages contain at least one digit or `'`. Tier 5 passages contain at least one character from `TIER5_EXTRA`. Otherwise the tiers would not actually differ in richness (GDD tier table).

**Length and spacing**
- `text.length()` is within 150–400.
- No leading or trailing space and no two spaces in a row. There is no tab or newline (already excluded by the ASCII range, but give it its own clear reason). Story 8.2 joins passages with exactly one typed Space, so a passage must not carry its own.
- No word (a run of non-space characters, with its punctuation) is longer than `MAX_WORD_CHARS = 12`. The paragraph sign fits **12 characters per 24 px line** in Press Start 2P (deferred-work, Story 2.5 dev note), so a longer word could never wrap.

**Sentences**
- A sentence end is a run of one or more `.!?`, optionally followed by one closing `"` or `)`, followed by a Space or the end of the text.
- `sentence_count` counts sentence ends and must be within 2–4. Edge cases to test:
  - `"Hi there. Bye now."` → 2
  - `"Wait... what?! Yes."` → 3 (`...` followed by a space counts as one end)
  - `"It cost 3.50 brains. Wow!"` → 2 (a `.` before a digit is not an end)
  - `"\"Run!\" said the farmer. Okay."` → `sentence_count` gives 3, but the passage **fails** the capital-after-end rule below, because `said` is lowercase after `!"`. So never put a dialogue tag after a quoted `!`, `?` or `.`. Write `The farmer said, "Run!"` instead. Test this case explicitly.
- The text's first character is `A–Z`, or `"`/`(` followed by `A–Z` (tier 5 only, since tiers 3–4 have no `"`).
- After each sentence end, the next character is `A–Z`, a digit, or `"`/`(` then `A–Z`.
- The text ends with a sentence end.

**Style**
- No ALL-CAPS words: no two capital letters in a row. "I" and a single capital are fine. This keeps Shift use reasonable and follows the plain-words rule (no shouting copy, `test_plain_words.gd` rule e).

**Document**
- `schema == 1`; ids unique; texts unique; per-tier counts 12–15; total 38–42.

### Authoring guide (for writing the 39 passages)

- **Voice:** the player *is* a friendly, goofy zombie (GDD). Pitchfork Panic's mood is "goofy panic": villagers with torches and pitchforks chase a zombie who only wants hugs, dancing and brain-shaped snacks. Keep it silly, never scary (NFR10, NFR13).
  - Good themes: a zombie's day (breakfast, lost sock, dance class), the conga line, party hats, the pet ghost, villagers who misunderstand, farmer tomatoes, moonlit village, a dog that likes the zombie, pumpkins, the Crypt Closet.
  - Avoid: biting, eating people, death, graves, blood, bones, skulls, weapons used on anyone, being hurt, fear words ("scary", "terror", "afraid of dying"), and gross-out or toilet humor.
  - Pitchforks and torches are fine as props; nobody is ever hit.
  - "Brains" are the game's treat and currency, so they are fine. Don't write zombie slang with stretched letters ("Brainsss", "Grrr"): stretched letters are hard to type and slang lives only in voice lines (Story 5.2).
- **Plain words:** a reading level of about 7–10 (ages 6–13). Short, common words. No rare words, no abbreviations (`Mr.`, `etc.`; they also break the sentence count), no real names of people, brands or places. Made-up names are fine if they are plain (e.g. "Farmer Fran").
- **Length:** 150–400 characters with 2–4 sentences. Aim for a spread inside each tier: tier 3 mostly 150–260, tier 4 200–330, tier 5 260–400. Longer passages for faster typists suit the tier table's "full authored paragraphs".
- **Tier 3** (15–21 WPM): letters, spaces and `. , ! ?` only. No contractions (no apostrophe, so "do not", not "don't"), no numbers, no quotes. Mix `!` and `?` across passages.
- **Tier 4** (22–29 WPM): add numbers and apostrophes. Use contractions ("can't", "it's") and small numbers ("7 hats", "3 pumpkins", "at 9 o'clock"). Each passage needs at least one of them.
- **Tier 5** (30+ WPM): full punctuation. Prefer natural prose marks: `" : ; - ( )`, with the odd `&` or `%` where it reads naturally ("100% sure"). Avoid `@ # $ ^ * _ = + < > /` unless a passage is genuinely about them. Each passage needs at least one `TIER5_EXTRA` character.
- **Capitals:** every sentence starts with a capital. Proper-noun capitals ("Farmer Fran") give Shift practice. No ALL-CAPS words.
- **Example of the format** (tier 3, 171 chars, 4 sentences). It illustrates the format only; the dev writes all passages new:

  `Zip the zombie loved to dance. Every night he did the wiggle on the village green, and the cows clapped along. Then the farmer woke up! Zip waved, grabbed his hat and ran.`

### `SentenceGenerator` design (decisions already made; follow them)

- **Composition, not inheritance:** it holds a `WordSource` (Story 6.2's word bag; it extends `LetterBagSource`). The bag already gives a seed-stable shuffle, every word before repeats, and no immediate repeats, so don't write a second shuffle.
- **Tier pools:** callers pass `WordSource.tier_pool_from_json(json, tier, band.x, band.y)` (Story 7.5). With today's pools, tier 1 has 40 home-row words of 2–4 letters (`word_pool_report.json`) and tier 2 has 304 words of 3–4 letters. The generator must cope with small pools (7.4 forward note); test 5.5 covers a 2-word pool.
- **Sentences are word salad on purpose** (GDD: "Generated sentences from row-filtered words"), e.g. "Dad had a sash, glad ask." Don't try to build grammar. Tier 1's capital and `.` are Shift and bottom-row keys, which the GDD table explicitly asks for.
- **It is not a `TargetSource`.** Story 8.2's `ParagraphSource` decides how sentences group into passages (e.g. one sentence per passage, or 2–3 joined) and owns the Space join. Generated sentences are not tracked for repeats; FR68's no-repeat rule applies to authored passages only.
- **Hidden tier (FR60, NFR10):** no log line or string the generator produces names a tier number.

### Existing code to read first (read only; nothing here is modified)

| File | Why |
|---|---|
| `scripts/typing/word_tagger.gd` | Style model for a pure static rules class (constants, `rejection_reason`, `##` docs). `rejection_reason()` validates generator words. |
| `scripts/typing/word_source.gd` | The bag the generator wraps, and `tier_pool_from_json` (the tolerant JSON-loading style: log once, never assert). |
| `scripts/typing/letter_bag_source.gd` | `_init` **asserts** on a bad pool (validate before constructing); Fisher-Yates on the injected RNG. |
| `scripts/resources/tier_config.gd`, `data/tier_config.tres` | `word_band_of(tier)`. Tiers 1–2 bands are (2,4) and (3,4). |
| `data/content/word_pools.json`, `word_pool_report.json` | Pool shape `{"tiers":[{"tier","rows","min_length","max_length","words"}]}`; counts 40/304/901/951/904. |
| `tools/gen_finger_map.gd`, `data/finger_map.tres` | The typeable set: 26 letters, 10 digits, `; / ' - = . ,`, Space, 17 shifted symbols, 26 capitals (87 entries). `entries` is `Dictionary` String → `Vector3i`. |
| `tests/unit/test_word_pools.gd`, `tests/unit/test_master_word_list.gd` | Test style for content files: `_loaded` guard, non-empty asserts, independent oracle strings, `BANNED` backstop. |
| `scripts/typing/typing_input.gd` | Pitchfork Panic will be `case_sensitive` + `space_is_input` (8.2). Every passage character must be producible by a plain keypress or Shift. |

### Architecture and rules to follow

- **Placement:** pure typing logic goes in `scripts/typing/` (architecture: `TargetSource` family, `WordTagger`). Every class in `scripts/typing/` needs a `tests/unit/test_*.gd` (architecture *Testing*). Generated or static content goes in `res://data/content/` as JSON (architecture D5, *Static Game Data*).
- **GDScript:** static typing everywhere. The project sets `debug/gdscript/warnings/untyped_declaration = Error`, so every `var`, parameter and return is typed and loop variables are typed (`for c: String in text`). Tabs for indentation. `##` doc comments on the class and public functions.
- **Errors:** return empty arrays or strings and log via `Log.error(&"typing", "...")`. `assert` only for contract violations, and not for content data (NFR16). No logging in loops per character.
- **RNG:** only the injected `RandomNumberGenerator`; never global `randi()`/`randf()`/`shuffle()` (architecture *Core architecture*).
- **Naming:** snake_case files, `PascalCase` class names, `UPPER_SNAKE` constants, StringName log tags (`&"typing"`).
- **JSON numbers load as float:** use `int(entry["tier"])` and check `is float or is int` before converting (7.5 lesson).

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. GUT skips a script that fails to parse and still exits 0, so grep the output for `Parse Error|Compile Error|Failed to load script`.
- Run `--import` after adding `paragraphs.json`, or `load()` returns null.
- Use independent oracle strings in tests (the row letters, the tier character sets in `test_paragraphs.gd`). Don't import `ParagraphRules`' constants to check the file's characters against `finger_map.tres` (6.1 / 7.4 review lesson).
- Assert loaded data is non-empty before looping (6.1 review: vacuous passes).
- The `BANNED` list is exact-token and a backstop only.

### Previous story intelligence (Epic 7)

- **7.3:** the human review gate is recorded in the story file with the question and the answer **verbatim**, and the call recorded as Smuck's. Present the content compactly in chat and open the file in the pane. Review patches came from small omissions: a missing date in the header and a placeholder line left above the filled section. Delete the `_To be filled in…_` line when you fill **Paragraph Review**.
- **7.4:** content minimums are constants in the pure class (`WordTagger.TIER_POOL_MINIMUMS`). Its forward note for 8.1 says tier 1 has only 40 words, so cope with a small pool.
- **7.5:**
  - `WordSource.tier_pool_from_json` is the runtime reader to reuse.
  - Tier labels in logs and records must not reveal the tier (FR60).
  - Review findings were about stale or duplicated state and missing tests for in-between tiers. Test tier 1 *and* tier 2, and both comma settings.
- Baseline at 7.5: 1789 passing / 94 scripts.

### Git intelligence

- The last 5 commits are the Epic 7 stories, one commit each ("Story 7.N: …, code review patches applied, done").
- Content stories add a pure class in `scripts/typing/`, data in `data/content/`, and GUT tests that guard the data file so CI fails on bad content (`test_word_pools.gd` pattern).
- The `.uid` files of new scripts and tests are committed with the story.

### Forward notes (for 8.2+, don't implement here)

- **8.2 `ParagraphSource`:**
  - Load `paragraphs.json` and keep only entries with `ParagraphRules.passage_problems(entry).is_empty()` for the tier. Bad data never asserts (NFR16).
  - Tiers 1–2 use `SentenceGenerator.for_tier(...)` with `WordSource.tier_pool_from_json`. Tier 0 (placement, untiered) needs a decision there; Pitchfork Panic is never the placement level, but a debug jump can be untiered.
  - Track used ids per save in the v2 migration (FR68).
- **8.2 hands:** every passage character is in `finger_map.tres` (guarded by `test_paragraphs.gd`), so `ZombieHands` never hits the unmapped-key warning.
- **8.2 layout:** 12 characters per 24 px line; `MAX_WORD_CHARS` assumes that. If 8.2 changes the font size or sign width, revisit the constant and re-validate.
- **AltGr (deferred-work, 2.x):** on non-US layouts some symbols arrive as Ctrl+Alt and are ignored by `TypingInput`. Tier 5's symbols make this matter in 8.2's web check, not here.
- **8.7:** the WPM comparability note for Pitchfork Panic (Shift and punctuation) is reviewed with per-level WPM there (deferred-work, 7.1 Gate A).

### Project Structure Notes

- New files only:
  - `scripts/typing/paragraph_rules.gd`
  - `scripts/typing/sentence_generator.gd`
  - `data/content/paragraphs.json`
  - `tests/unit/test_paragraph_rules.gd`, `tests/unit/test_paragraphs.gd`, `tests/unit/test_sentence_generator.gd`
  - plus the `.uid` files.
- They match the architecture tree (`data/content/` lists `paragraphs.json` by name; `scripts/typing/` holds the `TargetSource` family and helpers).
- Variance: the architecture says generated content is produced by a headless tool. `paragraphs.json` is **hand-authored**, not generated, so it has no tool. Its validator runs as a GUT test, which is what CI runs, so the AC's "a validator confirms" is enforced on every push. No conflict.

### Project Context Rules

- No `project-context.md` exists. The rules come from the architecture (`_bmad-output/game-architecture.md`) and `epics.md` *Additional Requirements*:
  - Godot 4.7.2, GDScript only, GUT 9.7.1.
  - Static data as typed Resources or JSON under `res://data/`.
  - Logging via `Log` with tags.
  - Exports exclude `tests/*` and `tools/*` and include `data/content/*.json`.
- MCP: a `godot` MCP server is available (`run_project`, `get_debug_output`), but headless CLI runs are the established test path. Nothing in this story needs the editor.

### Latest tech information

- No new libraries or engine features; the project is pinned to Godot 4.7.2 and GUT 9.7.1. APIs used: `String.to_upper()`, `substr()`, `unicode_at()`, `RandomNumberGenerator.randi_range()/randf()`, and `load()` of a `.json` as a `JSON` resource (already used by `horde_rush.tres` → `word_pools.json`). No web research was needed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.1: Paragraphs and Sentence Generator]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory] FR4, FR62, FR67, FR68, FR69, NFR7, NFR9, NFR10, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] *Adaptive Difficulty* (tier table: Pitchfork Panic text), *Content: Word Lists & Paragraphs*, *Finger Guide*, *Session Length & Accessibility*
- [Source: _bmad-output/game-architecture.md] D5 Static Game Data, `TargetSource` (ParagraphSource Epic 8), *Static Game Data* (`res://data/content/`), Finger Guide Resolution, project tree (`data/content/paragraphs.json`)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] Story 2.5 dev (12 characters per 24 px line; paragraph sign 304 × 48), 2.6 (unmapped keys), AltGr note, 7.1 Gate A (per-level WPM)
- [Source: _bmad-output/implementation-artifacts/7-3-master-word-list.md] content rules (Task 2.4), review-gate format
- [Source: _bmad-output/implementation-artifacts/7-4-tier-word-pools-and-validation.md] pools file shape, forward note for 8.1
- [Source: _bmad-output/implementation-artifacts/7-5-zombie-run-and-horde-rush-follow-the-tier.md] `tier_pool_from_json`, testing notes, hidden-tier logging

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline before the story: 1791 passing / 94 scripts. Story 7.5's review patches had added 2 tests after the 1789 noted in the story.
- First run of the new tests: `GOOD_T3` in `test_paragraph_rules.gd` was 146 characters (under 150), and two composed passages were too short. These were fixture fixes; the validator itself was right.
- With a trailing space, the sentence rules also fired ("no capital after a sentence end", "does not end with end punctuation"). `passage_problems` now runs the sentence rules on `text.strip_edges()`, so an edge space is reported once, by the spacing rule.
- `-gtest=<path>` ran the whole suite because `.gutconfig.json` sets `dirs`. Single scripts were run with `-gdir=res://tests/unit -gselect=<name>` (noted in deferred-work).
- Final run: `--import`, then the full GUT suite gave **1829 passing / 97 scripts**, with 0 matches for `Parse Error|Compile Error|Failed to load script`.

### Completion Notes List

- Ultimate context engine analysis completed: comprehensive developer guide created.
- **`ParagraphRules`** (`scripts/typing/paragraph_rules.gd`) is a pure static class.
  - It holds every Task 1.2 constant, with `TIER5_EXTRA = ;:-"()/=+_@#$%^&*<>` (19 characters).
  - Its public functions are `allowed_chars`, `sentence_count`, `passage_problems` and `doc_problems`.
  - It reports a problem and never asserts. It takes JSON floats for the tier and rejects 3.5.
  - Each broken rule gives one short reason. Rejected characters are listed by the character itself, never by tier name.
- **`paragraphs.json`** holds 13 passages for each of tiers 3, 4 and 5 (39 total).
  - The file is hand-written, tab-indented and ASCII only, with LF endings and a final newline.
  - It needed no `.import` sidecar and no export change.
  - Tier 5 uses ` - ` (a spaced hyphen) as a dash, because em dashes can't be typed.
  - No dialogue tag follows a quoted `!`, `?` or `.`.
- **`SentenceGenerator`** (`scripts/typing/sentence_generator.gd`) wraps a `WordSource`.
  - It validates its inputs before building the bag: RNG, pool size, duplicates, and `WordTagger.rejection_reason`.
  - On bad input it logs one `Log.error(&"typing", ...)` line with no tier number, stays empty and returns `""`.
  - `for_tier` reads `ParagraphRules.COMMA_TIERS`.
  - The RNG draw order is fixed: word count, then the bag's words, then the comma roll and slot.
- **Tests:** 38 new tests.
  - `test_paragraph_rules.gd` (25): one test per rule (each with a failing and a passing passage), the `sentence_count` edge cases from Dev Notes, document rules and tier counts, the subset chain, and `allowed_chars(5)` matched both ways with all 87 `finger_map.tres` keys.
  - `test_paragraphs.gd` (6): the shipped-file gate (`fail_test` per problem), counts per tier (logged as `{ 3: 13, 4: 13, 5: 13 }`), the id scheme, independent tier 3 and 4 character sets, finger-map coverage, and an exact-token `BANNED` backstop.
  - `test_sentence_generator.gd` (7): 500 sentences per tier from the shipped pools (tier 1 has 40 words). Checks cover the 4–7 word count with every count seen, capitals and the period, pool membership, row characters, comma placement per tier, seed determinism, a 2-word pool, and 6 bad inputs with `assert_push_error_count(6)`.
- **Review gate:** Smuck shipped both the passages and the generator as is (see **Paragraph Review**).
- **Scope:** nothing else changed. No level, scene, `LevelConfig`, save, `TierConfig`, word list, `finger_map.tres` or `project.godot` edits.

### File List

- `scripts/typing/paragraph_rules.gd` (new)
- `scripts/typing/paragraph_rules.gd.uid` (new)
- `scripts/typing/sentence_generator.gd` (new)
- `scripts/typing/sentence_generator.gd.uid` (new)
- `data/content/paragraphs.json` (new; no `.import` sidecar was created)
- `tests/unit/test_paragraph_rules.gd` (new)
- `tests/unit/test_paragraph_rules.gd.uid` (new)
- `tests/unit/test_paragraphs.gd` (new)
- `tests/unit/test_paragraphs.gd.uid` (new)
- `tests/unit/test_sentence_generator.gd` (new)
- `tests/unit/test_sentence_generator.gd.uid` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/8-1-paragraphs-and-sentence-generator.md` (this file)

## Change Log

- 2026-10-09: Story 8.1 implemented. Added the `ParagraphRules` validator, 39 passages in `paragraphs.json` and `SentenceGenerator`, plus 38 GUT tests (1791 → 1829). Smuck's review gate shipped everything as is. Status set to review.
