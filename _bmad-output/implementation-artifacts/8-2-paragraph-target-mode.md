---
baseline_commit: 278d631a6c8611fb09efc08e7f579998610429df
---

# Story 8.2: Paragraph Target Mode

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want to see my text in two lines, with the part I've typed turning green,
so that I can read ahead and keep my place.

## Acceptance Criteria

1. **`ParagraphSource` deals the tier's text (FR67, FR62, FR69).** `ParagraphSource` (`scripts/typing/paragraph_source.gd`, a pure `TargetSource`) gives one target per passage: the passage text plus one join Space at the end.
   - Tiers 3–5: valid authored passages of that tier from `paragraphs.json`.
   - Tiers 1–2: generated passages, each `GENERATED_SENTENCES` (3) sentences from `SentenceGenerator.for_tier(...)` over the tier's word pool and band.
   - Untiered (tier 0), or a tier whose text can't be built: tier 3's authored passages, with pool label `"all"`.
   - The source never runs dry. It uses only its own child RNG, so the same seed, tier and used-passage list always deal the same text.
2. **2-line window (FR69, DESIGN.md *Paragraph*).** In paragraph mode the target sign shows two 24 px lines of at most 12 characters each, word-wrapped by `ParagraphLayout`:
   - Line 1 is the line holding the cursor: typed characters zombie-green-dark, untyped characters ink, and the next character underlined with a 2 px ink bar.
   - Line 2 is the next line in ink-faded (`#8A7552`). On a passage's last line, line 2 is the first line of the next passage.
   - Typing scrolls the window one line at a time, and the next passage starts on a fresh line.
3. **Fits the band (U2, NFR7).** Paragraph lines are 24 px tall (font 24, line height 24). Both lines sit in the 304 × 48 sign at (68, 260), and the hands keep their 312 × 48 area at (64, 308), all inside the 104 px band. Letter and word mode look exactly as before.
4. **Space join (G7, E8-1).** Each passage's last line ends with a visible space marker: a small `␣`-style bracket in ink-faded, drawn with shapes rather than a glyph. That Space is the passage target's last character. Typing it completes the passage (`target_completed`), counts as a typed key and an accepted character, and makes the next passage current. A wrong key there shakes the line and counts as an error, like any other key.
5. **Exact matching and Shift hands (FR4, FR17).** With `case_sensitive = true` and `space_is_input = true`, capitals, punctuation, digits and Space must match exactly; `t` for `T` is a wrong key. The hands light the next character's finger, plus the opposite pinky for a capital or shifted symbol, and both thumbs for Space. Tests prove this through the HUD for a capital, a shifted symbol, an unshifted symbol, a digit and Space.
6. **No repeats per save (FR68).** An authored passage is used once it becomes current. No passage repeats until every valid passage of its tier has been used; then that tier starts a new cycle, which never begins with the passage just shown. The used ids live in the save at `profiles.<id>.used_passages` (an Array of ids) and are persisted every time the list changes, so a quit or a closed tab keeps them. Generated tier 1–2 text is not tracked.
7. **Save migration v2 → v3 with a fixture test (AC deviation, see Dev Notes).** The save is already at v2 (Story 6.8), so the new field arrives through `SaveSchema.migrate_2_to_3`, which adds `used_passages: []` to every profile. `GameConstants.CURRENT_SCHEMA` becomes 3. There is a new `tests/fixtures/saves/save_v3_fresh.json`, and the v1 and v2 fixtures are kept byte-identical as migration inputs. Tests cover v2 → v3 and v1 → v3, junk tolerance, and that existing ids are kept.
8. **The data flow keeps the level contract (ADR-1).**
   - RunFrame hands the save's used ids down with `level.set_used_passages(...)`, after `set_tier` and before `create_target_source`.
   - The level signals changes up with `LevelBase.used_passages_changed(ids)`.
   - RunFrame forwards each change to `PlayerData.set_used_passages(ids)`, the only writer.
   - A level still never reads `PlayerData`.
9. **Playable now: a debug "Test text" level.** `test_paragraph_level` (debug-only registry entry, `data/levels/test_paragraph_level.tres` with `target_mode = PARAGRAPH`, `case_sensitive = true`, `space_is_input = true`) runs paragraph mode from the F3 overlay's new "Test text" jump button. Pitchfork Panic itself (scene, `pitchfork_panic.tres`, chase) is Story 8.3.
10. **Hidden tier (FR60).** No log line, label or string that this story adds names a tier number, average or validator message. The run record's `letter_pool_or_tier` is `"tier_n"` for a tiered run and `"all"` for the fallback, as in 7.5.
11. **Nothing else regresses.** Letter and word modes, Zombie Run, Horde Rush, the report card and all existing tests keep working, with only the test expectations named in the tasks changed. The full GUT suite is green with no parse errors.

## Tasks / Subtasks

- [x] **Task 1: `ParagraphLayout`, a pure line-wrapper** (AC: 2, 3, 4)
  - [x] 1.1 Create `scripts/typing/paragraph_layout.gd`: `class_name ParagraphLayout extends RefCounted`, static only, no nodes or autoloads. Add `const LINE_CHARS: int = 12` (12 × 24 px = 288 px, the sign's inner width; sketch hud-band-2-5 deviation 4).
  - [x] 1.2 `static func wrap(text: String, line_chars: int = LINE_CHARS) -> PackedInt32Array` returns each line's start index into `text`. The rules are in *Wrapping rules* (Dev Notes). Every character, spaces included, belongs to exactly one line, and every line including its trailing Space is ≤ `line_chars`.
  - [x] 1.3 `static func line_of(starts: PackedInt32Array, index: int) -> int` returns the line holding character `index`: the last start ≤ index, clamped to a valid line.
  - [x] 1.4 `tests/unit/test_paragraph_layout.gd` checks:
    - the line starts for a hand-made text;
    - that `"brain-shaped "` breaks after the hyphen;
    - a 12-letter word with no hyphen (fallback hard split);
    - that `""` gives `[0]`;
    - that `line_of` works at line edges.
    - **Over every shipped passage + `" "`** (load `paragraphs.json`; assert it is non-empty first), and over 200 generated tier 1 and tier 2 passages: the lines joined back equal the text, every line is ≤ 12 characters, no line starts with a Space, and no line is empty.
- [x] **Task 2: `ParagraphSource`** (AC: 1, 6, 10)
  - [x] 2.1 Create `scripts/typing/paragraph_source.gd`: `class_name ParagraphSource extends TargetSource`. Constants:
    - `JOIN: String = " "`;
    - `GENERATED_SENTENCES: int = 3` (a content choice, not a GDD number: 3 sentences of 4–7 words make a 2–5-line passage);
    - `FALLBACK_TIER: int = 3`;
    - `ID_PATTERN` for `t<tier>_<2+ digits>`.
  - [x] 2.2 `static func passages_from_json(json: JSON, tier: int) -> Array[Dictionary]` returns `{"id", "text"}` for the entries of `tier` that pass `ParagraphRules.passage_problems(entry).is_empty()` **and** whose id matches `t<tier>_NN` with its own tier (closes 8.1 defer). It works in file order and skips duplicate ids.
    - Bad data never asserts (NFR16). Log one `Log.error(&"typing", "ParagraphSource: N passages failed checks; skipped")` with the count only, never the problem strings (they name tiers, FR60).
    - It is tolerant like `WordSource.tier_pool_from_json`: a null JSON, a non-Dictionary or no `passages` array gives `[]` with one log line.
  - [x] 2.3 Authored mode, `_init(rng: RandomNumberGenerator, passages: Array[Dictionary], used: Array[String], all_ids: Array[String] = [])`. It validates without asserting: a null RNG or empty passages logs once and leaves the source empty (`current()` gives `""`).
    - It keeps a copy of `used`. When `all_ids` is non-empty, it first drops used ids that are not in `all_ids` (retired ids), so the saved list can't grow forever.
    - **Selection** (fixed draw order): the candidates are the passages in file order whose id is not used and not already queued. If there are none, a new cycle starts: remove this tier's ids from `used` and make every passage a candidate except the queued ones and the one current or last shown, unless that leaves none. Then pick `candidates[_rng.randi_range(0, size - 1)]`.
    - A passage is **marked used when it becomes current**, at construction for the first one and in `advance()` for the rest. Peeking deals into the queue but never marks.
  - [x] 2.4 Generated mode, `static func generated(rng: RandomNumberGenerator, generator: SentenceGenerator) -> ParagraphSource`. Each passage is `GENERATED_SENTENCES` calls of `next_sentence()` joined by single spaces. The id is `""` and nothing is tracked. A null or empty generator (first sentence `""`) leaves the source empty with one log line.
  - [x] 2.5 `TargetSource` API:
    - `current()` returns `text + JOIN`;
    - `peek(n)` returns the next n targets, each `+ JOIN`, dealing into the queue on demand like `LetterBagSource._ensure`;
    - `advance()` pops, deals if needed and marks the new current used.

    Plus:
    - `get_current_id() -> String`;
    - `get_used_ids() -> Array[String]` (a copy, in the order marked);
    - `get_pool_label() -> String`, set by the factory below.
  - [x] 2.6 The factory both levels use (test level now, Pitchfork Panic in 8.3), `static func for_level(rng: RandomNumberGenerator, config: LevelConfig, tier: int, tier_config: TierConfig, used: Array[String]) -> ParagraphSource`:
    - **Tiers 1–2** (`tier in ParagraphRules.GENERATED_TIERS`, tier config valid): `WordSource.tier_pool_from_json(config.tier_word_pools, tier, band.x, band.y)` with `band = tier_config.word_band_of(tier)`. If the pool has ≥ 2 words, build `SentenceGenerator.for_tier(rng, pool, tier)` and return a generated source labelled `GameConstants.TIER_POOL_FORMAT % tier`.
    - **Tiers 3–5** (`tier in ParagraphRules.AUTHORED_TIERS`): `passages_from_json(config.paragraphs, tier)`. If it is non-empty, return an authored source labelled `TIER_POOL_FORMAT % tier`.
    - **Anything else, or a failure above:** log one error if it was a failure (no tier number), then authored `FALLBACK_TIER` passages labelled `GameConstants.LETTER_POOL_ALL`. If those are empty too, return `null`, and RunFrame fails safely to the menu (NFR16).
    - `all_ids` is every id in the file. Collect it with a small private reader so the prune in 2.3 works.
    - The `rng` passed in is the level's **child** RNG (LevelBase rule), and only the source draws from it.
  - [x] 2.7 Close the 8.1 defer in `scripts/typing/sentence_generator.gd`: `for_tier` with a tier not in `ParagraphRules.GENERATED_TIERS` logs one `Log.error(&"typing", ...)` (no tier number) and returns `null`. Update its doc, and add a test in `test_sentence_generator.gd` (`for_tier(..., 3)` is null with one error).
  - [x] 2.8 `tests/unit/test_paragraph_source.gd`. Use small hand-made passage lists for the logic and the shipped files for one integration check per mode. It covers:
    - `current()` ends with exactly one Space and `peek` never consumes;
    - every tier passage is used once before any repeat, over 3 full cycles with a 4-passage list;
    - the cycle boundary never repeats the last passage, and the cycle reset removes only this tier's ids (others survive);
    - the used list is marked on current, not on peek;
    - starting from a partly used list deals only unused passages first, and retired ids are pruned;
    - the same seed and used list give the same 10 passages, and a different seed gives a different order;
    - generated mode: 3 sentences per passage, every word in the pool, never tracked;
    - a **golden test**: seed 8201 with the tier 1 pool gives a fixed first passage string, recorded in the test (closes the 8.1 "golden output" defer; the comment says to update it only on a deliberate generator change);
    - `for_level` for tiers 0, 1, 2, 3, 4, 5 and 6, checking each label and mode;
    - a missing `paragraphs` JSON gives `null` with an error;
    - `passages_from_json` drops a bad passage and a mismatched id (`t4_03` with tier 3), with one error and no tier number in it.
- [x] **Task 3: Save field and v2 → v3 migration** (AC: 6, 7)
  - [x] 3.1 In `scripts/core/save_schema.gd`, add `"used_passages": []` to `profile_defaults()` and `migrate_2_to_3(data)`. The migration gives every Dictionary profile `used_passages = []` unless it already has an Array there (keep it). It skips junk with a warning, in the `migrate_1_to_2` style. Append it to `migration_steps()` and extend the class doc ("v3 (Story 8.2) adds profiles.<id>.used_passages ...").
  - [x] 3.2 In `scripts/core/game_constants.gd`, set `CURRENT_SCHEMA = 3`.
  - [x] 3.3 Fixtures:
    - Create `tests/fixtures/saves/save_v3_fresh.json` = `JSON.stringify(SaveSchema.defaults(), "\t")` exactly. Keys are sorted, so `used_passages` lands between `tier` and the end. Copy the v2 file's format and check it with the test, not by eye.
    - **Do not edit** `save_v2_fresh.json` or the v1 fixtures; they are migration inputs now.
  - [x] 3.4 Update the tests:
    - `test_save_schema.gd`:
      - `FRESH_PATH` → v3, and rename `test_defaults_match_v2_fixture` to `..._v3_fixture`;
      - add `V2_FRESH_PATH`;
      - `test_prepare_round_trips_full_fixture` now also expects `used_passages: []`;
      - new tests: `test_migrate_2_to_3_adds_used_passages` (v2 fixture → field present, v3), `test_migrate_2_to_3_keeps_existing_list`, `test_migrate_2_to_3_survives_junk` (non-dict profiles, profiles not a dict, `used_passages` a String → replaced by `[]`), and `test_prepare_v1_reaches_v3`;
      - `test_prepare_v1_reaches_v2` becomes v3, keeping its unlock checks.
    - `test_save_service.gd`: `FRESH_PATH` → v3.
    - `test_smoke.gd`: assert `CURRENT_SCHEMA == 3` with the message "Story 8.2: schema v3 (used_passages)".
    - Grep for other `schema_version": 2` or `save_v2_fresh` uses and update them on purpose.
  - [x] 3.5 `scripts/autoloads/player_data.gd`:
    - `signal used_passages_changed`;
    - `get_used_passages() -> Array[String]`: a copy of the String entries; a non-Array in the save reads as `[]`;
    - `set_used_passages(ids: Array[String]) -> void`: stores the unique non-empty Strings in order. If the result equals the stored list it does nothing. Otherwise it writes, emits and calls `request_save()`.

    Add a line to the class doc. Tests in `test_player_data.gd`: round trip, dedup, the no-op on an equal list (no signal), one save request, survival across `reset_all()` (back to `[]`), and a bad stored type.
- [x] **Task 4: LevelBase and RunFrame wiring** (AC: 8)
  - [x] 4.1 `scripts/run/level_base.gd`:
    - `signal used_passages_changed(ids: Array[String])` with `@warning_ignore("unused_signal")`, like the others;
    - `var used_passages: Array[String] = []`;
    - `func set_used_passages(ids: Array[String]) -> void` stores a copy.

    Update the call-order doc: `set_tier(...) -> set_used_passages(ids) -> create_target_source(rng)`. Tests go in `test_level_base.gd`.
  - [x] 4.2 `scripts/run/run_frame.gd` `_start_level`, right after `level.set_tier(...)`:
    - call `level.set_used_passages(player_data.get_used_passages())`;
    - next to the other level connections, add `_level.used_passages_changed.connect(_on_level_used_passages_changed)`, which calls `player_data.set_used_passages(ids)`.

    Extend the class doc with one line. `player_data` is the test seam: tests inject it, so never call the autoload directly.
  - [x] 4.3 HUD calls with the next target. Add `func _next_target() -> String`: the first of `_session.get_upcoming(1)` in PARAGRAPH mode, else `""`. Only paragraph mode peeks, so letter and word runs are untouched. Pass it in `%Hud.setup(config, first, _next_target())` and in `_on_session_char_accepted` → `%Hud.show_target(current, cursor, _next_target())`.
  - [x] 4.4 `tests/integration/test_run_frame.gd`, using the existing injection pattern and a temp-save `PlayerData`:
    - a paragraph test level receives the injected used ids before `create_target_source`;
    - a completed passage (type every character, then Space) persists the new used list to the injected `player_data`;
    - the join Space counts in `get_keys_typed()`;
    - `implied_spaces` stays 0;
    - a capital typed as lowercase is WRONG.
- [x] **Task 5: HUD paragraph rendering** (AC: 2, 3, 4, 5)
  - [x] 5.1 `scenes/run/hud.tscn`, new nodes, all `mouse_filter = 2`:
    - `NextLineLabel` (Label, unique), a child of `TargetSign`: font 24, colour ink-faded `Color("#8A7552")`, left-aligned, hidden by default;
    - `SpaceMarker` (Control, unique), a child of `TargetLabel` so it shakes with line 1, hidden. It holds three `ColorRect`s in ink-faded: a bottom bar and two short uprights, i.e. the `␣` bracket.

    Keep the existing nodes and their unique names.
  - [x] 5.2 `scripts/run/hud.gd`, `setup(config, first_target, next_target: String = "")`. In PARAGRAPH mode:
    - set `%TargetLabel` to font 24, `max_lines_visible = 1`, `HORIZONTAL_ALIGNMENT_LEFT`, `autowrap_mode = OFF`, `clip_text = false`;
    - set `%TypedLabel` to font 24, left-aligned.

    In LETTER and WORD mode, restore font 32, centre alignment and `%TypedLabel` font 32, and hide `%NextLineLabel` and `%SpaceMarker`. `setup` may run again on the same HUD in tests, so every mode sets every property it relies on.
  - [x] 5.3 `show_target(target, typed := 0, next_target := "")`. In paragraph mode, call a new `_show_paragraph(target, typed, next_target)`:
    - cache `ParagraphLayout.wrap(target)` per target string;
    - `L = line_of(starts, typed)`;
    - line 1 = `target.substr(start[L], len)` in `%TargetLabel` at (8, 0), size 288 × 24;
    - `%TypedLabel` = `line1.left(typed - start[L])` at (0, 0), visible when non-empty;
    - `%NextUnderline` sits under column `typed - start[L]`, measured with the font like word mode, `PARAGRAPH_UNDERLINE_Y` (start at 22, 2 px), and is visible while `typed < target.length()`;
    - line 2 = the next line of `target`, or else the first line of `wrap(next_target)` (or `""`), in `%NextLineLabel` at (8, 24), size 288 × 24;
    - `%SpaceMarker` goes at the join Space's column when the passage's last line is line 1 (y 0) or line 2 (y +24), and is hidden otherwise.

    Keep the hands call `%ZombieHands.show_char(target.substr(typed, 1))` unchanged. Remove the "(paragraph rendering is Story 8.2)" note from the doc and add a short paragraph-mode description to the class doc.
  - [x] 5.4 Constants: `PARAGRAPH_UNDERLINE_Y: float`, plus marker geometry `SPACE_MARKER_*` (bar thickness 2 px; uprights about 6 px; inset inside the 24 px cell). Document them as DESIGN.md `target-paragraph` tokens and tune both from the screenshot (Task 7). Rules:
    - the underline sits inside line 1's 24 px cell and never touches line 2;
    - the marker stays inside its cell and is visible next to the underline when the cursor is on the join Space.
  - [x] 5.5 The `_layout_target` paragraph branch sets `%TargetLabel` to (8, 0) and 288 × 24, not the full sign height, and still keeps the sign at `PARAGRAPH_SIGN`. The wrong-key shake moves `%TargetLabel` (line 1, its typed overlay, underline and marker); line 2 stays still.
  - [x] 5.6 `tests/unit/test_hud.gd`: update `test_paragraph_lines_are_24_px` (line 1 and line 2 labels both have line height 24), and keep `test_paragraph_sign_rect` and `test_target_line_count_by_mode`. New tests:
    - for a two-passage fixture: line 1 / line 2 text at cursor 0, mid-line, and on a line break (window scrolls);
    - the last line shows the next passage's first line in line 2, and the marker is visible on the right line and column;
    - typed text equals the line's typed prefix, and the underline x equals that prefix's width;
    - the line 1 and line 2 rects plus `%HandsArea` all lie inside the band (y 256–360) and do not overlap;
    - line 2's colour is ink-faded;
    - the hands light `[left index, right pinky]` for `T`, `[left pinky, right pinky]` for `!` (it's on the 1 key), the mapped finger alone for an unshifted symbol such as `.` or `,` (read every expected finger from `finger_map.tres` entries, not hard-coded), the digit's finger for a digit, and both thumbs for the join Space;
    - word and letter modes still pass all their old tests after a paragraph `setup` (call `setup` in paragraph mode, then word mode, and check the alignment, font and hidden nodes are restored);
    - every character of `ParagraphRules.allowed_chars(5)` has a glyph in the theme font (`font.has_char`).
- [x] **Task 6: Test level, config and overlay** (AC: 9)
  - [x] 6.1 `scripts/resources/level_config.gd`: add `@export var paragraphs: JSON` with a doc ("The authored passages (res://data/content/paragraphs.json, Story 8.1) a paragraph level draws from; null = none. Tiers 1–2 generate text from tier_word_pools instead (Story 8.2).").
  - [x] 6.2 `data/levels/test_paragraph_level.tres`: `duration_s = 120.0`, `case_sensitive = true`, `space_is_input = true`, `target_mode = 2`, `completion_bonus = 0`, `music_id = &""`, `paragraphs` = `paragraphs.json`, `tier_word_pools` = `word_pools.json`. Copy the header and ext_resource style from `test_word_level.tres`.
  - [x] 6.3 `scenes/levels/test_level/test_paragraph_level.tscn`: a copy of `test_word_level.tscn` with root `TestParagraphLevel` and the new config.
  - [x] 6.4 `scripts/levels/test_level/test_level.gd`, add a paragraph branch:
    - `create_target_source` uses `ParagraphSource.for_level(child, config, tier, tier_config, used_passages)` and `_pool_label = source.get_pool_label()` (`tier`/`tier_config` are LevelBase's, set by RunFrame); a `null` source returns `null`;
    - `%LetterLabel.text = ""` in paragraph mode (a 400-character passage must never be drawn in the playfield);
    - `on_run_started` emits `used_passages_changed(_paragraphs.get_used_ids())`;
    - `on_target_completed` adds a brain and emits it again.

    Keep the letter and word branches unchanged. Type the shared source field as `TargetSource` so both `LetterBagSource` and `ParagraphSource` fit, and keep a typed `_paragraphs: ParagraphSource` for `get_used_ids()`. Update the class doc.
  - [x] 6.5 `data/levels/level_registry.tres`: add a `test_paragraph_level` entry (`display_name = "Test text"`, `debug_only = true`), with the `load_steps` count updated.
  - [x] 6.6 `scripts/debug/debug_overlay.gd` + `scenes/debug/debug_overlay.tscn`:
    - Add a `JumpParagraphLevelButton` ("Test text", like the others, `focus_mode = 0`) on `%JumpRow` after "Test words", wired with `{"level_id": &"test_paragraph_level"}` and added to `_refresh_jumps`' button list. If the row no longer fits the panel (screenshot), move it to `%JumpRow2`.
    - The run line's targets would print 3 whole passages, so truncate each shown target to `TARGET_SHOWN_CHARS = 16` characters + `"..."` when longer, and show `@<cursor>` after the current one.
    - Update `test_debug_overlay.gd`.
  - [x] 6.7 `tests/unit/test_test_level.gd`: the paragraph test level builds a `ParagraphSource`, labels the pool by tier, earns 1 brain per completed passage, emits `used_passages_changed` on run start and on each completion, and leaves `%LetterLabel` empty. Also check `test_level_registry.gd` (entry counts or ids) and `test_plain_words.gd` (how "Test words" is exempted as debug copy) and update them in the same way.
- [x] **Task 7: Visual check and wrap-up** (AC: 2, 3, 4, 11)
  - [x] 7.1 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the GUT command. The baseline is **1829 passing / 97 scripts** (Story 8.1); re-run it first. Grep the log for `Parse Error|Compile Error|Failed to load script`. Record the new totals.
  - [x] 7.2 Visual check, as in 6.2 Task 8.4: run the project (Godot MCP `run_project`, or the in-app browser on a web debug export), open F3 → "Test text", and type into the first passage. Take screenshots of:
    - (a) mid-line with green typed characters, the underline and the dimmed line 2;
    - (b) the last line with the space marker, then after Space, the new passage on a fresh line;
    - (c) a capital with the Shift pinky lit.

    Tune `PARAGRAPH_UNDERLINE_Y` and the marker from them. Save them as `_bmad-output/implementation-artifacts/screenshots/8-2/paragraph-*.png` (also take a 3× crop of the sign). The paragraph HUD has no UX mock (spine-only, F8), so show Smuck the screenshots in chat. Their verdict is the visual gate; record it verbatim in Completion Notes.
  - [x] 7.3 Commit the new `.uid` files (`paragraph_layout.gd`, `paragraph_source.gd`, the new tests). List every new file in the File List.
  - [x] 7.4 `deferred-work.md`:
    - mark the 8.1 defers this story closes with "Done in 8.2: ...": `for_tier` tier check, generated passages exempt from MIN_CHARS (3 sentences, not validated), the id/tier prefix check in the loader, no validator messages at runtime, the generator golden test;
    - mark lines 177/178/187 (paragraph rendering, 12 chars per line, autowrap) done;
    - add new items under "Deferred from: dev of story 8-2" (at least the *Known limitations* below that you confirm).
  - [x] 7.5 Mark sprint-status `8-2-paragraph-target-mode: review` (dev-story does this).

### Review Findings

- [x] [Review][Patch] A 12-character word is split mid-word by `ParagraphLayout` — decided (Smuck): lower `ParagraphRules.MAX_WORD_CHARS` to 11 and drop the too-long words. Done: cap is 11, `brain-shaped` → `brainy` in t5_06 and t5_13, long-word test boundary moved to 11/12. The layout's hyphen/hard-split fallback stays as a defensive path. Full suite: 1890 passing. [scripts/typing/paragraph_rules.gd, data/content/paragraphs.json]
- [x] [Review][Patch] Peeking at a cycle boundary wipes the current passage from `_used` (blind+edge+auditor, AC 6) — `_deal_authored` → `_start_cycle()` runs on a peek and drops every tier id including the one being typed; the saved list lacks it and it can repeat 2 passages later. Fix: re-mark the current id after `_start_cycle()` or defer the reset to `advance()`; add a test that the current id stays in `get_used_ids()`. [scripts/typing/paragraph_source.gd:_deal_authored/_start_cycle]
- [x] [Review][Patch] A tier 1-2 (generated) paragraph run overwrites the saved `used_passages` with `[]` (edge) — `generated()` passes `[]`, `get_used_ids()` returns `[]`, the level emits it and `set_used_passages([])` wipes tier 3-5 history. Fix: seed the generated source with the incoming used list, or only emit when the source is authored; add a test. [scripts/typing/paragraph_source.gd:generated, scripts/levels/test_level/test_level.gd:on_run_started/on_target_completed]
- [x] [Review][Patch] New-cycle fallback ignores the "queued" exclusion (auditor, AC 6/2.3) — final `candidates = _passages.duplicate()` can re-queue the current passage for 1-2 passage lists. [scripts/typing/paragraph_source.gd:_deal_authored]
- [x] [Review][Patch] `SentenceGenerator.for_tier` now returns null outside `GENERATED_TIERS` (blind) — check every caller null-handles it; cover tiers 0 and 6 in tests. [scripts/typing/sentence_generator.gd:for_tier]
- [x] [Review][Patch] Passage id regex accepts a trailing newline (blind) — `$` matches before a final "\n", so "t3_01\n" validates; also `passages_from_json` accepts float tiers like 3.5 via `int()`. [scripts/typing/paragraph_source.gd:ID_PATTERN/_id_matches]
- [x] [Review][Patch] Test gaps and stale assertions (blind+edge) — no test for the used list surviving a cycle peek or a generated run (see above); `test_prepare_round_trips_full_fixture` asserts `"schema_version": 2.0` is absent, meaningless after v3; `test_save_service` still calls the fixture "v2". Optional: stop using `ParagraphLayout.wrap` as its own oracle in `test_paragraph_hud_shows_the_window_and_the_next_passage`. [tests/unit/test_save_schema.gd, tests/unit/test_save_service.gd, tests/integration/test_run_frame.gd]
- [x] [Review][Defer] Space marker shakes with line 1 while it sits on line 2 [scenes/run/hud.tscn, scripts/run/hud.gd:_place_space_marker] — deferred, already recorded in deferred-work (spec-mandated parent, 2 px for 0.2 s)
- [x] [Review][Defer] Layout assumes a monospace font (`LINE_CHARS = 12` vs measured pixel widths) [scripts/typing/paragraph_layout.gd] — deferred, unverified against the shipped font; check at 8.6/8.7
- [x] [Review][Defer] Quitting before the first correct key re-deals the same first passage next run [scripts/levels/test_level/test_level.gd:on_run_started] — deferred, benign; 8.3 should emit at the same point

## Dev Notes

### What this story is (and isn't)

- **It is:**
  - paragraph target mode end to end: `ParagraphLayout` (wrapping) and `ParagraphSource` (text per tier, no repeats);
  - the HUD's 2-line window with the green typed prefix, underline, dimmed next line and space marker;
  - the save field with its v2 → v3 migration;
  - the used-passage data flow through RunFrame;
  - a debug "Test text" level to play it.
- **It isn't** the Pitchfork Panic level or `pitchfork_panic.tres` (8.3), the chase, mob or camera (8.3), pickups (8.4), endings or bonuses (8.5), art or audio (8.6), or tuning (8.7). Don't touch the `pitchfork_panic` registry entry (`available = false`, no scene).
- **`TypingSession` and `TypingInput` need no change.** Paragraph judging already exists: the cursor walks the target, the last character completes it, and `target_completed` fires for any non-letter mode. PARAGRAPH counts no implied spaces (`test_typing_session.gd:355`). `TypingInput` already supports `case_sensitive` and `space_is_input` (fixture `tests/fixtures/levels/level_config_case_sensitive.tres`). Because the join Space is the target's last character, "typing Space starts the next passage and counts as a key" falls out with no new input rule (GDD decision-log G7).

### AC deviation: v2 → v3, not v1 → v2

The epics AC says "schema v1 → v2 migration". It was written before Story 6.8 used v2 for `level_unlocks` (`save_schema.gd` header, `CURRENT_SCHEMA = 2`). The intent is "a versioned migration step with a fixture test", which becomes `migrate_2_to_3`. Follow the 6.8 pattern exactly:
- one static func per step, appended to `migration_steps()`;
- migrations run before `fill_defaults` and must not assume any field's type;
- older fixtures stay byte-identical as migration inputs;
- the current-schema fresh fixture must equal `JSON.stringify(SaveSchema.defaults(), "\t")`.

`fill_defaults` would add the field anyway, but the explicit step is the AC and keeps the version meaningful. Epic 8 rule: new save fields live inside the profile, never at the top level (Epic 11 needs no migration).

### Wrapping rules (`ParagraphLayout.wrap`)

- The target is `passage + " "`. Tokens are a word (a run of non-space characters) plus its following Space, if any. The passage has single spaces only (`ParagraphRules`), and generated sentences are single-spaced too.
- Wrapping is greedy: a token goes on the current line if `line_len + token_len <= LINE_CHARS`, and otherwise starts a new line. A line's trailing Space counts toward the 12, because the kid types it and the underline must sit in a visible cell. Never let a Space start a line.
- A token that doesn't fit on an empty line (only possible for a 12-character word + Space) breaks after its last `-` if that piece fits. The shipped text has `brain-shaped` twice (12 characters, the only words over 11), so `"brain-"` goes on one line and `"shaped "` on the next. With no hyphen it hard-splits at `LINE_CHARS - 1` characters. Shipped content never does this, but it is the fallback so nothing overflows.
- ~~Don't lower `ParagraphRules.MAX_WORD_CHARS`~~ Superseded by code review: `MAX_WORD_CHARS` is now 11 and `brain-shaped` became `brainy` (Smuck's call), so a word plus its Space always fits a line. The hyphen break stays as a defensive fallback.
- Pure and deterministic. The HUD caches the result per target string; a passage only changes at a completion.

### `ParagraphSource` design notes

- **Why one target per passage (with the join Space inside it):** `TypingSession` already handles long targets with a cursor, `target_completed` lands exactly on the passage boundary (8.4/8.5 can hook it), and the per-key stats get `" "`, capitals and punctuation as their own keys. Don't split passages into word targets: that would need implied spaces and break FR69's continuous flow.
- **Used = became current.** A peeked passage (shown dimmed in line 2) isn't used until it's reached. The first passage is marked at construction, but the level emits `used_passages_changed` only from `on_run_started`. So a kid who opens the level and leaves without typing burns nothing, and every passage they typed in is saved even if they quit or close the tab.
- **The used list covers all tiers in one flat array of ids.** The id prefix (`t3_`, `t4_`, …) tells the tiers apart, and a tier's cycle reset removes only that tier's ids. A tier change between runs (7.5 hysteresis) just switches to another tier's set. Ids are save data (8.1: never renumber or reuse), so retiring an id is safe: the prune drops it.
- **Determinism:** the source's child RNG is drawn only by passage selection (authored) or by `SentenceGenerator` (generated). The order is fixed per passage, and peek only deals earlier, never differently. **Replay contract (document it in the class doc):** a seed replays the same text only at the same tier **and** the same starting used list. A debug replay after the list has moved deals different passages, which is expected (compare 7.5's "same tier" note in `run_frame.gd`).
- **Exhaustion:** the source is infinite (cycles), so deferred-work line 140 (`NO_TARGET` verdict) stays open, as it was for `WordSource`. Say so in the deferred note.
- **Validation at load is a second line of defence.** `test_paragraphs.gd` already gates the shipped file in CI. The runtime filter protects against a hand-edited or partly broken file (NFR16): skip, log once, never assert.

### HUD layout facts (don't re-derive)

All the facts below are measured, from `hud.tscn`, `hud.gd` and sketch hud-band-2-5 Frame 3:

- **Target area:** 312 × 104 at HUD (64, 256).
- **Paragraph sign:** `PARAGRAPH_SIGN = Rect2(4, 4, 304, 48)` in area coordinates, which is (68, 260) on screen, already tested.
- **Hands area:** (0, 52) 312 × 48 in the area, which is (64, 308) on screen, with a 4 px pad below.
- **Vertical budget:** 4 + 24 + 24 + 48 + 4 = 104.
- **Lines inside the sign:** 8 px side padding gives a 288 px text width. Line 1 is y 0–24 and line 2 is y 24–48. There is no inner vertical padding: the sign is exactly 2 lines tall (DESIGN.md *Paragraph*: "no extra leading").
- **Font:** Press Start 2P is monospaced with a 24 px advance at 24 px, and `Label.get_line_height()` is 24 at size 24 (`test_paragraph_lines_are_24_px`). Still measure x positions with `font.get_string_size(...)` as word mode does; don't hard-code 24.
- **`%TargetLabel` is centred in `hud.tscn`** (`horizontal_alignment = 1`). That was harmless in word mode because the label is sized to the text. In paragraph mode it must be left-aligned, or the typed overlay and underline drift on short lines, and other modes must restore centre.
- **Underline:** word mode's 2 px bar sits below a 32 px line inside a 40 px sign. In paragraph mode there is no spare row, so the bar goes inside line 1's cell (start y 22–24) and may touch the `g j p q y` descenders. Tune it from the screenshot, as 6.2 tuned `UNDERLINE_GAP`.
- **Colours (DESIGN.md `target-paragraph`):** ink `#1E1428` for untyped text and the underline; zombie-green-dark `#2E6B26` for typed text; ink-faded `#8A7552` for line 2 and the marker. Ink-faded on parchment is 3.6:1, AA-large at 24 px.
- **Space marker:** DESIGN.md says "a small `␣`-style bracket in ink-faded". Draw it with shapes. Press Start 2P has no `␣` glyph, and the marker must not be typed text.

### Hands and Shift (FR17): already implemented, prove it

`FingerMap.fingers_for(c)` returns the character's finger, then the opposite pinky for `shift == 1` entries (capitals, `! @ # $ % ^ & * ( ) _ + : " < > ?`), or the other thumb for Space. `Hud.show_target` already passes `target.substr(typed, 1)` with the case kept, because the session keeps the case in case-sensitive levels. This story adds tests through the HUD, not code. Read the expected fingers from `data/finger_map.tres` `entries` in tests, so the oracle is the data file and not `fingers_for` itself (6.1/7.4 independence lesson). Every character the source can produce is mapped: `test_paragraphs.gd` checks the file, and generated text is letters plus `,` `.` and Space.

### Existing code to read first

| File | Current state | This story |
|---|---|---|
| `scripts/typing/target_source.gd`, `letter_bag_source.gd`, `word_source.gd` | The `TargetSource` API (peek/current/advance); `_ensure`/queue pattern; `tier_pool_from_json` tolerant loader | Model `ParagraphSource` on them; reuse `tier_pool_from_json` |
| `scripts/typing/typing_session.gd` | Cursor judging; `target_completed` for WORD and PARAGRAPH; implied spaces only in WORD | **No change** |
| `scripts/typing/typing_input.gd` | `case_sensitive` / `space_is_input` from config; Caps hint only when not case-sensitive | **No change** |
| `scripts/typing/paragraph_rules.gd`, `sentence_generator.gd` (8.1) | Validator, `AUTHORED_TIERS`/`GENERATED_TIERS`/`COMMA_TIERS`, `for_tier` | Reuse; `for_tier` gets the tier check (2.7) |
| `scripts/run/hud.gd`, `scenes/run/hud.tscn` | Paragraph branch only sizes the sign, font 24, `max_lines_visible = 2`; no wrapping, no colouring | 2-line window (Task 5) |
| `scripts/run/zombie_hands.gd`, `scripts/resources/finger_map.gd` | Shift pinky and Space thumbs already work | Tests only |
| `scripts/run/run_frame.gd` | `_start_level` order: set_tier → seed → `create_target_source` → session → HUD setup; `_on_session_char_accepted` refreshes the HUD | Used-ids in and out; next target to the HUD |
| `scripts/run/level_base.gd` | `set_tier`, `_pool_label`, `_tier_active()` | `set_used_passages`, `used_passages_changed` |
| `scripts/levels/test_level/test_level.gd` | Letter and word branches; `%LetterLabel` shows the target | Paragraph branch |
| `scripts/core/save_schema.gd`, `game_constants.gd` | v2, `migrate_1_to_2`, `CURRENT_SCHEMA = 2` | v3 |
| `scripts/autoloads/player_data.gd` | Only writer; every mutation emits and `request_save()`s; getters read live | `get/set_used_passages` |
| `scripts/levels/horde_rush/horde_rush_level.gd` `_word_pool()` | The tiered-pool-with-fallback pattern and `_pool_label` | Same shape in `for_level` |
| `scripts/debug/debug_overlay.gd` | Jump row (88–90, 338); targets line at 291 joins whole targets | "Test text" + truncation |

### What must keep working (regression guard)

- Letter mode (Zombie Run, the test level) and word mode (Horde Rush, Test words): same HUD rects, fonts, centring, underline and typed overlay. Run `test_hud.gd`, `test_zombie_run_level.gd`, `test_horde_rush_level.gd` and `test_run_frame.gd`.
- `RunFrame` calls `_next_target()` only in PARAGRAPH mode. Calling `peek` on other sources is deterministic, but it's unnecessary work and could change the debug overlay's view timing.
- Save: v1 saves still reach the latest version with their unlock backfill (`test_prepare_v1_reaches_v3`). A save newer than v3 is still read-only. The export (F9) contains `used_passages`.
- PlayerData's 7.2 tier reconcile and the 6.8 unlocks are untouched. `reset_all()` resets `used_passages` through the defaults.

### Known limitations (note in deferred-work; don't fix here)

- **Caps Lock in case-sensitive levels:** `TypingInput` only runs the Caps hint when not case-sensitive, so in paragraph mode a kid with Caps Lock on gets only wrong keys and no hint. GDD M1 scopes the hint to the lowercase levels. Raise it for 8.7 tuning or the Pitchfork Panic playtest. Adding a case-sensitive hint would be a GDD change, so log it and don't implement it.
- **AltGr / dead keys:** on non-US layouts some symbols arrive as Ctrl+Alt and are ignored (deferred line 120). On US-International, `'` and `"` are dead keys. Tier 4–5 text makes this visible. It needs a browser check on a real layout, which belongs to 8.7.
- **Debug "Test text" writes the real save's used list,** as debug jumps already write run history (deferred line 531). This is acceptable for a debug-only level.

### Architecture and rules

- **Pipeline (ADR-1):** TypingInput → TypingSession → RunFrame → level. The level never reads input, the clock or `PlayerData`; RunFrame calls down and the level signals up. Everything in the key path is synchronous, and the HUD must show the next target in the same frame (NFR2, ≤ 17 ms). Wrapping at most 400 characters per completion is cheap; cache it anyway.
- **One RNG per run, a child RNG per source:** `child.seed = rng.randi()` in the level (LevelBase class doc). No global `randi()`/`randf()`/`shuffle()`.
- **GDScript:**
  - static typing everywhere (`untyped_declaration = Error`), and typed loop variables;
  - tabs;
  - `##` docs on classes and public functions;
  - `snake_case` files, `PascalCase` classes, `UPPER_SNAKE` constants;
  - StringName log tags (`&"typing"`, `&"level"`, `&"run"`, `&"save"`).
- **Errors:** content and save data never `assert` (NFR16). Log once, outside character loops, and fall back.
- **JSON numbers load as floats:** compare tiers with `int(...)` after an `is float or is int` check (7.5 lesson). `SaveSchema.normalize_numbers` already handles the save.
- **Placement:** pure logic in `scripts/typing/`, each with a `tests/unit/test_*.gd`. Data in `data/`. Levels in `scripts/levels/` + `scenes/levels/`.

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- To run one script: `-gdir=res://tests/unit -gselect=<name>`. `-gtest=` runs everything because `.gutconfig.json` sets `dirs` (8.1 learning).
- GUT skips a script that fails to parse and still exits 0, so grep for `Parse Error|Compile Error|Failed to load script`.
- Assert loaded data is non-empty before looping (6.1 lesson about vacuous passes). Use independent oracles: `finger_map.tres` entries for the hands, and written-out line expectations for the wrap.
- Log errors: use `assert_push_error_count(n)` as 8.1's generator tests do.
- Tests never write the real save: inject a `PlayerData` on a temp `SaveService` (`save_dir` in a temp folder), as `test_run_frame.gd` and `test_player_data.gd` already do.

### Previous story intelligence

- **8.1:**
  - `ParagraphRules` and `SentenceGenerator` are ready, with constants `AUTHORED_TIERS`, `GENERATED_TIERS` and `COMMA_TIERS`. 39 passages ship, 13 per tier, ids `t3_01`…`t5_13`, 155–281 characters, words ≤ 12 (`brain-shaped` is the only 12).
  - Six 8.1 review defers target this story; Task 7.4 lists which close.
  - Baseline: 1829 / 97 scripts.
- **7.5:**
  - Use the tier only through `set_tier`; `_pool_label` is fixed when the pool is built.
  - Fall back to the untiered pool with one log line and no tier number.
  - Review findings were about stale or duplicated state and missing in-between-tier tests. So test every tier 0–6 in `for_level`, and test that `setup()` called twice in different modes leaves no stale HUD state.
- **6.8:** the migration pattern, frozen constants and byte-identical old fixtures; `test_prepare_round_trips_full_fixture` builds its expected output by adding the migration's fields.
- **6.2:** word mode added the `%TypedLabel`/`%NextUnderline` overlay, the "Test words" debug level and jump button, and a screenshot-tuned underline. Mirror all of that here.

### Git intelligence

- One commit per story ("Story 8.N: …, code review patches applied, done").
- New scripts and tests commit with their `.uid` files.
- Content and logic stories add pure classes in `scripts/typing/` with matching unit tests. Integration goes through `tests/integration/test_run_frame.gd`.

### Project Structure Notes

- New:
  - `scripts/typing/paragraph_layout.gd`, `scripts/typing/paragraph_source.gd`;
  - `data/levels/test_paragraph_level.tres`, `scenes/levels/test_level/test_paragraph_level.tscn`;
  - `tests/fixtures/saves/save_v3_fresh.json`;
  - `tests/unit/test_paragraph_layout.gd`, `tests/unit/test_paragraph_source.gd`;
  - screenshots under `screenshots/8-2/`;
  - `.uid` files.
- Modified:
  - `scripts/typing/sentence_generator.gd`, `scripts/resources/level_config.gd`, `scripts/run/level_base.gd`, `scripts/run/run_frame.gd`, `scripts/run/hud.gd`, `scenes/run/hud.tscn`, `scripts/levels/test_level/test_level.gd`, `scripts/core/save_schema.gd`, `scripts/core/game_constants.gd`, `scripts/autoloads/player_data.gd`, `data/levels/level_registry.tres`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`;
  - tests: `test_save_schema.gd`, `test_save_service.gd`, `test_smoke.gd`, `test_player_data.gd`, `test_level_base.gd`, `test_hud.gd`, `test_test_level.gd`, `test_debug_overlay.gd`, `test_sentence_generator.gd`, `test_run_frame.gd`, plus whatever registry or plain-words tests need;
  - `deferred-work.md`, `sprint-status.yaml`.
- Untouched: `typing_session.gd`, `typing_input.gd`, `zombie_hands.gd`, `finger_map.*`, `paragraphs.json`, `word_pools.json`, `tier_config.*`, `project.godot`, `export_presets.cfg` (`data/content/*.json` already ships), `.github/`, `assets/`.
- `ParagraphLayout` lives in `scripts/typing/`, not `scripts/run/`. It is pure text logic shared by the HUD and the tests, like `ParagraphRules`. That is not a conflict with the architecture tree.

### Project Context Rules

- No `project-context.md` exists. The rules come from `_bmad-output/game-architecture.md` and `epics.md` *Additional Requirements*:
  - Godot 4.7.2, GDScript only, GUT 9.7.1;
  - typed Resources and JSON under `res://data/`;
  - `Log` with tags;
  - exports exclude `tests/*` and `tools/*` and include `data/content/*.json`.
- MCP: the `godot` server (`run_project`, `get_debug_output`) is available for the Task 7.2 visual check. The in-app browser also works on a web debug export. Headless CLI is the test path.

### Latest tech information

No new libraries. The project is pinned to Godot 4.7.2 and GUT 9.7.1. APIs used: `Label` (`horizontal_alignment`, `max_lines_visible`, `autowrap_mode`, `get_line_height()`), `Font.get_string_size()`, `Font.has_char()`, `ColorRect`, `PackedInt32Array`, `RegEx` (for `ID_PATTERN`, compiled once in a static var or checked by hand), and `RandomNumberGenerator.randi_range()`. No web research was needed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.2: Paragraph Target Mode], Epic 8 intro (save fields inside the profile)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Level 3 *Text display*, *Content: Word Lists & Paragraphs* (Selection), *Finger Guide* (Shift), *Readability*, tier table
- [Source: …/gdd-zombies-teach-typing-2026-09-27/decision-log.md] U2 (24 px), G7 (passage join)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] `target-paragraph` tokens, *Paragraph* HUD bullet, colour contrast table, vertical budget
- [Source: …/ux-designs/…/EXPERIENCE.md] target-paragraph state row (E8-1), NFR2 same-frame rule
- [Source: …/ux-designs/…/sketches/hud-band-2-5.md] Frame 3, element table, deviation 4
- [Source: _bmad-output/game-architecture.md] `TargetSource` (ParagraphSource Epic 8), TypingInput configuration, Static Game Data, ADR-1 level contract
- [Source: _bmad-output/implementation-artifacts/8-1-paragraphs-and-sentence-generator.md] Forward notes, Review Findings (defers)
- [Source: _bmad-output/implementation-artifacts/6-2-word-target-mode.md] overlay, test level, screenshot tuning
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] lines 120, 140, 177–178, 187, 194–195, 531, 646–651

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), Claude Code desktop, gds-dev-story workflow.

### Debug Log References

- Baseline re-run first: 1829 passing / 97 scripts, no parse errors (matches 8.1).
- Red phase: `test_paragraph_source.gd` failed first on the missing `LevelConfig.paragraphs` export (5 tests) and on the golden placeholder. The golden string was recorded from that first run: seed 8201, tier 1 = "Lag alas gas had asks adds all. Dads ash half glad lass lags has. Gag dad ha ah gala gals gags."
- The first full run after Tasks 1–6 had 2 failures, both guard tests doing their job: `test_tier_config.gd` (the registry's debug levels must all be in `ignored_levels`) and `test_level_unlocks.gd` (it hard-coded `schema_version == 2`). Fixed as described in the Completion Notes.
- Final: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` → **1890 passing / 99 scripts**, 0 failing, 0 `Parse Error|Compile Error|Failed to load script`.
- Visual check run: a throwaway SceneTree capture script (in `tools/_scratch_8_2/`, deleted afterwards) in a real window (OpenGL Compatibility, 640×360 root). It ran the real `RunFrame` on `test_paragraph_level`, seed 8202, with a tier 3 temp save and typed through `%TypingInput.handle_key`. First passage `t3_08` (17 lines), next `t3_07`; 165 keys, 0 errors; the temp save's used list ended as `["t3_08", "t3_07"]`. The real `user://save.json` MD5 was the same before and after.
- Pixel rows measured on the 640×360 frame: the sign's top frame row is y 260 and its parchment runs y 261–305 (306 shadow, 307 dark edge). Line 1 glyphs y 260–280, then 1 parchment row (281), then the underline at y 282–283. Line 2 glyphs start at y 284. The space marker spans y 274–280, clear of the underline.

### Completion Notes List

- Ultimate context engine analysis completed: comprehensive developer guide created.
- **ParagraphLayout** (`scripts/typing/paragraph_layout.gd`): greedy 12-character wrap where the trailing Space counts toward the line. Over-long words break after their last `-` (`brain-` / `shaped `), or hard-split at 11 characters. A guard stops a cut from leaving only the Space on the next line. `line_of` uses `bsearch`. Tests check hand-written line starts, every shipped passage + `" "`, and 200 generated passages per tier 1 and tier 2.
- **ParagraphSource** (`scripts/typing/paragraph_source.gd`): authored mode deals in a fixed draw order (candidates in file order, then one `randi_range`). A passage is marked used only when it becomes current. A new cycle drops this list's ids and its `t<tier>_` prefix from the used list (other tiers survive) and excludes the queued passages and the last one shown. The used list is pruned to the file's ids. Generated mode builds 3 sentences per passage and tracks nothing. `for_level` covers tiers 0–6 with one error and no tier number on a failure, and returns null when even the fallback is missing. `_init` has two extra optional parameters (`generator`, `generated_mode`) used by `generated()`, so a bad input logs exactly one line.
- **SentenceGenerator.for_tier** now refuses tiers outside `GENERATED_TIERS` (one error, null).
- **Save v3:** `migrate_2_to_3` and `"used_passages": []` in the profile defaults; `CURRENT_SCHEMA = 3`. `save_v3_fresh.json` was generated from the v2 file (with the new field and version) and is proven byte-equal to `JSON.stringify(SaveSchema.defaults(), "\t")` by `test_defaults_match_v3_fixture`. The v1 and v2 fixtures are untouched.
- **PlayerData** `get_used_passages` / `set_used_passages` / `used_passages_changed`: the unique non-empty ids are stored in order; an equal list is a no-op (no signal, no save request).
- **LevelBase / RunFrame:** `set_used_passages` is called after `set_tier` and before `create_target_source`. `used_passages_changed` is forwarded to `player_data.set_used_passages`. `_next_target()` peeks only when `_paragraph_mode` is set (in `_start_level`), and it feeds `Hud.setup` and `Hud.show_target`.
- **HUD:** a 2-line window with the green typed prefix, an ink underline at y 22–24 of line 1, line 2 in ink-faded (the next line, or on the last line the next passage's first line), and a shape-drawn `␣` marker (2 px bar, 6 px uprights, 4 px inset, bottom edge at y 20 of its cell). `_shape_space_marker()` builds the marker from the `SPACE_MARKER_*` constants. `setup()` resets every property it uses in every mode (alignment, font sizes, autowrap, clip, `max_lines_visible`, line 2 and the marker), and the HUD tests check that a paragraph → word → letter sequence restores word and letter mode. The hands needed no code: the HUD tests prove a capital, `!`, `.`, `,`, a digit and the join Space, using finger expectations read from `finger_map.tres` entries.
- **Test text level:** `test_paragraph_level.tres` / `.tscn`, a branch in `test_level.gd` (`_source` is typed `TargetSource`, `_paragraphs` is kept for `get_used_ids()`), a debug-only registry entry (`load_steps` 14 → 16), and the overlay's "Test text" button on `%JumpRow`, which fits (see `debug-overlay-jump-row.png`). The overlay run line now cuts each target to 16 characters + "..." and shows `@<cursor>`.
- **Deviations from the task text (all on purpose):**
  - `data/tier_config.tres` `ignored_levels` gained `test_paragraph_level`. The Dev Notes list `tier_config.*` as untouched, but the 7.2 guard test `test_ignored_levels_are_the_registry_debug_levels` requires every debug-only registry level to be ignored. Without it, a debug "Test text" run would move the hidden tier. `test_tier_config.gd` was updated (size 3, shipped values).
  - `test_level_unlocks.gd::test_an_old_save_is_backfilled_and_shows_the_moment` asserted `schema_version == 2` after loading a v1 save. It now asserts `GameConstants.CURRENT_SCHEMA`. The grep in Task 3.4 missed it because it reads `== 2`, not `"schema_version": 2`.
  - `test_hud.gd::test_paragraph_mode_never_shows_word_progress` (6.2) became `test_paragraph_mode_shows_progress_on_line_1`. AC 2 reverses that old rule.
  - `test_plain_words.gd` needed no change: debug-only registry names are skipped, and `scenes/levels/test_level/` is not in its scene dirs. The new HUD nodes carry no text.
- **Task 7.3:** the 4 new `.uid` files exist and are listed below. They will be committed with the story commit after code review, following the repo's one-commit-per-story pattern; nothing is committed yet.
- **Visual check (7.2):** screenshots are in `_bmad-output/implementation-artifacts/screenshots/8-2/`. `PARAGRAPH_UNDERLINE_Y = 22` and the marker geometry kept their starting values: the bar sits 1 parchment row under the glyphs and never touches line 2, and the marker is visible next to the underline on the join Space.
  - First round (48 px sign, no padding): line 1's capitals started on the sign's top frame row (y 260) and line 2's descenders reached the bottom frame. Smuck's verdict, verbatim: "lets add a little padding".
  - Change (AC 3 deviation, from that verdict): `PARAGRAPH_SIGN` became `Rect2(4, 4, 304, 52)` and the new `PARAGRAPH_LINE_TOP = 2.0` puts line 1 at y 2 and line 2 at y 26 inside the sign. On screen: frame y 260, parchment y 261–309, line 1 capitals from y 262, line 2 descenders end at y 309, bottom shadow and edge at y 310–311. The sign uses the top 4 rows of `%HandsArea`, which the hand sprites leave empty (`ui_hand_*.png` art starts at row 4; `test_paragraph_rects_fit_the_band` reads it from the sprites). `%HandsArea` stays at (64, 308) 312 × 48. The middle-finger glow sprite starts at row 2, so a lit middle finger's glow tip draws over the sign's bottom edge (16 px, y 310–311; `paragraph-d-middle-finger*.png`).
  - Second round, the padded sign with that overlap shown: Smuck's verdict, verbatim: "ship it like this".
- Full suite after the padding change: 1890 passing / 99 scripts, 0 parse errors.

### File List

- `scripts/typing/paragraph_layout.gd` (new)
- `scripts/typing/paragraph_layout.gd.uid` (new)
- `scripts/typing/paragraph_source.gd` (new)
- `scripts/typing/paragraph_source.gd.uid` (new)
- `scripts/typing/sentence_generator.gd` (modified)
- `scripts/resources/level_config.gd` (modified)
- `scripts/core/save_schema.gd` (modified)
- `scripts/core/game_constants.gd` (modified)
- `scripts/autoloads/player_data.gd` (modified)
- `scripts/run/level_base.gd` (modified)
- `scripts/run/run_frame.gd` (modified)
- `scripts/run/hud.gd` (modified)
- `scenes/run/hud.tscn` (modified)
- `scripts/levels/test_level/test_level.gd` (modified)
- `scenes/levels/test_level/test_paragraph_level.tscn` (new)
- `data/levels/test_paragraph_level.tres` (new)
- `data/levels/level_registry.tres` (modified)
- `data/tier_config.tres` (modified)
- `scripts/debug/debug_overlay.gd` (modified)
- `scenes/debug/debug_overlay.tscn` (modified)
- `tests/fixtures/saves/save_v3_fresh.json` (new)
- `tests/unit/test_paragraph_layout.gd` (new)
- `tests/unit/test_paragraph_layout.gd.uid` (new)
- `tests/unit/test_paragraph_source.gd` (new)
- `tests/unit/test_paragraph_source.gd.uid` (new)
- `tests/unit/test_sentence_generator.gd` (modified)
- `tests/unit/test_save_schema.gd` (modified)
- `tests/unit/test_save_service.gd` (modified)
- `tests/unit/test_smoke.gd` (modified)
- `tests/unit/test_player_data.gd` (modified)
- `tests/unit/test_level_base.gd` (modified)
- `tests/unit/test_hud.gd` (modified)
- `tests/unit/test_test_level.gd` (modified)
- `tests/unit/test_level_registry.gd` (modified)
- `tests/unit/test_debug_overlay.gd` (modified)
- `tests/unit/test_tier_config.gd` (modified)
- `tests/unit/test_level_unlocks.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/screenshots/8-2/paragraph-d-middle-finger.png`, `paragraph-d-middle-finger-sign-3x.png`, `paragraph-d-middle-finger-pulse.png`, `paragraph-d-middle-finger-pulse-sign-3x.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/8-2/paragraph-a-mid-line.png`, `paragraph-a-mid-line-sign-3x.png`, `paragraph-b-last-line.png`, `paragraph-b-last-line-sign-3x.png`, `paragraph-b-on-join-space.png`, `paragraph-b-on-join-space-sign-3x.png`, `paragraph-b-next-passage.png`, `paragraph-b-next-passage-sign-3x.png`, `paragraph-c-capital.png`, `paragraph-c-capital-sign-3x.png`, `debug-overlay-jump-row.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/8-2-paragraph-target-mode.md` (this file)

## Change Log

- 2026-10-09: Story 8.2 implemented: `ParagraphLayout`, `ParagraphSource` (authored and generated passages, no repeats per save), save v3 (`used_passages`, `migrate_2_to_3`), the used-passage data flow through RunFrame, the HUD's 2-line paragraph window with the join Space marker, and a debug "Test text" level. 61 new GUT tests (1829 → 1890). After Smuck's visual-gate verdicts ("lets add a little padding", then "ship it like this") the paragraph sign became 52 px with 2 px of line padding. Status set to review.
