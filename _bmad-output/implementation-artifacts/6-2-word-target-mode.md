---
baseline_commit: 183ebd21028dc078e4429b6138040dc00c3547c7
---

# Story 6.2: Word Target Mode

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want to type whole words, with each letter turning green as I go,
so that I can see my progress through the word.

## Acceptance Criteria

1. **WordSource (FR59, FR66).** Given `WordSource` (a `TargetSource`) built from the words in `res://data/content/words.json` filtered to a length band, using a child RNG seeded from the run RNG (the `LevelBase` rule), when words are drawn, then the same word never appears twice in a row (also across bag boundaries), and the same seed always gives the same words.
2. **Word judging.** Given a `TypingSession` whose current target is a word, when a key is judged, then it is compared with the word's next letter (the cursor). A correct letter moves the cursor and emits `char_accepted(letter, index)`; a wrong letter emits `char_rejected(letter, typed)`, adds 1 to Errors and moves nothing. Per-key stats (FR9) are recorded per letter, never per word.
3. **Completion with no Space (FR54, FR7).** Given the last letter of a word is typed correctly, when it is judged, then `target_completed(word)` fires (no Space needed), the next word is current in the same call, and the session's implied-space count rises by 1. Signal order inside the one `judge()` call: `char_accepted` → `target_completed` → `target_changed(next_word)`.
4. **Letter mode unchanged.** In letter mode (`LevelConfig.TargetMode.LETTER`, or no config), every existing behaviour and signal stays exactly as it is: `target_changed` after every correct key, no `target_completed`, implied spaces stay 0. Zombie Run and the test level play the same as before (whole existing suite green).
5. **HUD word display (FR54, FR15, NFR7, NFR8).** Given the HUD target area in word mode, when a word is being typed, then the typed letters are drawn in `zombie-green-dark` (`#2E6B26`), the untyped letters stay `ink`, the next letter has a 2 px ink underline bar (shape cue, not colour alone), the text stays 32 px, and the zombie hands light the finger for the **next letter** (not the word's first letter). In letter mode there is no underline and no green.
6. **WPM counts implied spaces (FR7, FR8).** The run's `RunResult` gets the implied-space count as `completed_words` (so report-card WPM includes them), and the live HUD WPM and the debug overlay WPM include them too.
7. **Space stays ignored (FR3).** In a word-mode level with `space_is_input = false`, pressing Space is not judged: no error, no progress, no sound.
8. **Playable word level (debug only).** A debug-only `test_word_level` (registry entry, `data/levels/test_word_level.tres` with `target_mode = WORD` and the 3–5 band) can be started from a new "Test words" button in the debug overlay jump row; the start prompt reads "Type the word to start!" and a whole run can be played to the report card.
9. **Tests (AC from epics).** Given `test_word_source.gd` and word-mode `TypingSession` tests, when GUT runs, then word completion, implied spaces and no-immediate-repeat pass, plus the HUD, run-frame and test-level cases in Task 7. Full suite green.

## Tasks / Subtasks

- [x] **Task 1: `LevelConfig` word band fields** (AC: 1, 8)
  - [x] 1.1 In `scripts/resources/level_config.gd` add, with `##` docs: `@export var word_list: JSON` (the tagged list, `res://data/content/words.json`; null = no words), `@export var word_min_length: int = 0`, `@export var word_max_length: int = 0` (neutral defaults; real values in each word level's `.tres`; "Epic 7 replaces the fixed band with the tier band").
  - [x] 1.2 Don't touch `zombie_run.tres` / `test_level.tres` (defaults are fine). `ZombieRunConfig extends LevelConfig` inherits the fields harmlessly.
- [x] **Task 2: `WordSource`** (AC: 1)
  - [x] 2.1 Create `scripts/typing/word_source.gd`: `class_name WordSource extends LetterBagSource`. `_init(rng: RandomNumberGenerator, words: Array[String])` calls `super(rng, words)`. The bag gives "every word once before any repeat" and the bag-boundary no-repeat rule for free, using only the injected RNG. Doc comment says why it extends the bag (no duplicated shuffle code).
  - [x] 2.2 Update `LetterBagSource`'s class doc: it deals any unique strings (letters for Zombie Run, words via `WordSource`); nothing in its logic depends on length 1. Don't change its code.
  - [x] 2.3 `static func pool_from_json(json: JSON, min_len: int, max_len: int) -> Array[String]`: reads `json.data["words"]`, keeps entries whose `"word"` is a String with `WordTagger.rejection_reason(word) == ""` and `min_len <= word.length() <= max_len` (use `word.length()`, not the float `"length"` field), skips repeats, keeps file order. A null JSON, a non-Dictionary `data`, a missing/non-Array `"words"` or a non-Dictionary entry → `Log.error(&"typing", ...)` once and return what is valid so far (often `[]`). Never asserts (bad content data must not crash a debug build, NFR16).
  - [x] 2.4 Pure: no nodes, no autoloads except `Log`, no `FileAccess`. Loading the file is the `.tres`'s job (`ext_resource` of the JSON), so `WordSource` never names a path.
- [x] **Task 3: `TypingSession` word mode** (AC: 2, 3, 4, 6)
  - [x] 3.1 Add a cursor (`_cursor: int`, index of the next letter inside `_source.current()`), `signal target_completed(target: String)` (doc: word and paragraph modes only), and `_implied_spaces: int`. Remove the "target_completed is deliberately not declared" note and the "`config` … nothing reads it yet" note.
  - [x] 3.2 `judge(c)`: `var target := _source.current()`; `""` → WRONG (unchanged). `expected := target[_cursor]` (a one-letter String; guard `_cursor < target.length()`, reset to 0 if not). Per-key stats, errors, `char_rejected(expected, c)` all use the letter.
  - [x] 3.3 On a correct letter: count the key, `run_started` on the first one (before anything else, as now), then:
    - **not the last letter**: `_cursor += 1`, emit `char_accepted(expected, index)`. No `target_changed` (the target did not change).
    - **last letter** (or a 1-letter target): `_cursor = 0`, `_source.advance()`, emit `char_accepted(expected, index)`, then — only when `_word_like()` — `target_completed(target)` and, only in WORD mode, `_implied_spaces += 1` (increment **before** emitting so handlers read the new count); then `target_changed(_source.current())`.
    - In letter mode every target has length 1, so this path is exactly today's order: advance → `char_accepted` → `target_changed`. Keep the verbose-typing log lines.
  - [x] 3.4 `_word_like()`: `_config != null and _config.target_mode != LevelConfig.TargetMode.LETTER`. Implied spaces count only for `TargetMode.WORD` (paragraph Spaces are typed keys, FR7 / Story 8.2).
  - [x] 3.5 Getters: `get_cursor() -> int` (letters of the current target already typed; 0 in letter mode), `get_implied_spaces() -> int`. Keep `get_current_target()` returning the whole word.
- [x] **Task 4: `RunFrame` wiring** (AC: 3, 5, 6)
  - [x] 4.1 Connect `_session.target_completed.connect(_level.on_target_completed)` next to the other level connections (after `char_accepted`/`char_rejected`, before the HUD connections), so the level hears completion in the key's call stack.
  - [x] 4.2 Drive the HUD from one place: replace `_session.target_changed.connect(%Hud.show_target)` with a call in `_on_session_char_accepted`: `%Hud.show_target(_session.get_current_target(), _session.get_cursor())` (plus `set_counts` as now). `setup()` still shows the first target with 0 typed. In letter mode this is the same text at the same moment as before (the existing "label updated before handle_key returned" test must still pass).
  - [x] 4.3 `_process`: pass `_session.get_implied_spaces()` to `%Hud.update_clock(elapsed, keys, implied_spaces)`.
  - [x] 4.4 `_record_result`: pass `_session.get_implied_spaces()` as the last argument (`p_completed_words`) of `RunResult.create`. No save-format change (`completed_words` is not written to the record; `deferred-work.md` Story 2.3 note).
  - [x] 4.5 Update the class doc's pipeline summary in one line (word mode: cursor, completion, implied spaces).
- [x] **Task 5: HUD word display** (AC: 5, 6)
  - [x] 5.1 `scenes/run/hud.tscn`: add two children **under `%TargetLabel`** (so the wrong-key shake, which moves `%TargetLabel.position.x`, moves them too): `TypedLabel` (Label, unique name, same 32 px font, `font_color` `#2E6B26`, left-aligned, `mouse_filter` ignore, hidden by default) and `NextUnderline` (ColorRect, unique name, ink colour — the same ink `Color(0.1176, 0.0784, 0.1569, 1)` as `TargetLabel`'s `font_color`, height 2, hidden by default).
  - [x] 5.2 `hud.gd`: `show_target(target: String, typed: int = 0)`. Clamp `typed` to `[0, target.length()]`. `%TargetLabel.text = target` stays the **whole** word (tests and the overlay rely on it). In WORD mode: `%TypedLabel.text = target.left(typed)` at x 0, visible when `typed > 0`; `%NextUnderline` under letter `typed` (x = width of `target.left(typed)` from `font.get_string_size`, width = width of that one letter, y = `LINE_FONT_SIZE + UNDERLINE_GAP`, h = `UNDERLINE_PX` = 2), visible while `typed < target.length()`. In LETTER and PARAGRAPH modes both stay hidden (paragraph rendering is Story 8.2).
  - [x] 5.3 Hands: `%ZombieHands.show_char(target.substr(typed, 1))` (resolves the 2.6 deferred note; `show_char` lights the first character it is given).
  - [x] 5.4 Alignment: `%TargetLabel` is centred in a box exactly `text_width` wide, so its glyphs start at x 0 and the overlay lines up. Press Start 2P is monospaced (32 px advance at 32 px) — still measure with the font, don't hard-code 32. New constants `UNDERLINE_PX: float = 2.0` and `UNDERLINE_GAP: float` (a HUD-owned layout value; start at 0 and adjust after a screenshot so the bar sits under the baseline, inside the 40 px sign, clear of descenders of `g j p q y`). Document both as UX/DESIGN.md "2 px ink bar".
  - [x] 5.5 `update_clock(elapsed: float, keys: int, implied_spaces: int = 0)` → `StatsCalculator.wpm(keys, elapsed, implied_spaces)`.
  - [x] 5.6 Keep the HUD a view: it never reads the session; RunFrame passes everything.
- [x] **Task 6: Debug word level** (AC: 7, 8)
  - [x] 6.1 `data/levels/test_word_level.tres`: `LevelConfig`, `duration_s = 120.0`, `case_sensitive = false`, `space_is_input = false`, `target_mode = 1` (WORD), `word_list` = `res://data/content/words.json` (ext_resource type `JSON`), `word_min_length = 3`, `word_max_length = 5` (FR59 fixed band), `completion_bonus = 0`, `music_id = &""`.
  - [x] 6.2 `scenes/levels/test_level/test_word_level.tscn`: same as `test_level.tscn` (same script, same two labels) but `config` = the new `.tres`. Registry: add `Resource_test_word_level` (`id = &"test_word_level"`, `display_name = "Test words"`, `debug_only = true`) after `test_level` in `data/levels/level_registry.tres`.
  - [x] 6.3 `test_level.gd`: in `create_target_source`, branch on `config.target_mode`: WORD → `WordSource.pool_from_json(config.word_list, config.word_min_length, config.word_max_length)`; if the pool has fewer than 2 words, `Log.error` and return `null` (RunFrame then fails safely to the menu, NFR16 — and the `LetterBagSource` assert is never reached); else `WordSource.new(child, pool)`. LETTER keeps the alphabet bag. Override `on_target_completed(_target)` to add 1 brain per word (word mode demo rule, emits `brains_earned_changed`); in word mode skip the `BRAIN_EVERY` per-key rule. `%LetterLabel` shows `_source.current()` as now. Update the class doc.
  - [x] 6.4 Debug overlay: add `JumpWordLevelButton` ("Test words", font 8, `focus_mode = 0`) to `JumpRow` after "Test level", wired like the others with `{"level_id": &"test_word_level"}`, and include it in the button loop at `debug_overlay.gd:289`. Check the row still fits the panel (screenshot); if not, shorten the label.
  - [x] 6.5 Debug overlay WPM line: `StatsCalculator.wpm(keys, elapsed, session.get_implied_spaces())`.
- [x] **Task 7: Tests** (AC: 1–9)
  - [x] 7.1 `tests/unit/test_word_source.gd` (new): no immediate repeat over ≥500 draws for seeds `[1, 2, 3, 42, 12345]` (with a small pool too, e.g. 3 words, where boundary repeats are likely); same seed → same sequence; different seeds differ; `peek` doesn't consume and matches later `current()`s; `pool_from_json` with a `JSON` built in-test (`JSON.new()` + `parse(text)`): band filter inclusive at both ends, skips uppercase / non-letter / non-String / duplicate entries, keeps order, returns `[]` (no crash) for null, wrong `data` type, missing `"words"`; the shipped `words.json` at 3–5 gives ≥ `WordTagger.STARTER_BAND_MIN_COUNT` words, all 3–5 letters.
  - [x] 7.2 `tests/unit/test_typing_session.gd` (extend; a word-mode `LevelConfig` built in-test, the existing `StubSource` with `["dad", "cat"]`): cursor moves 0→1→2; `char_accepted` gets letters `d`,`a`,`d` with indexes 0,1,2; no `target_changed` mid-word; wrong key mid-word keeps the cursor and records `per_key["a"]`; last letter → `target_completed("dad")` once, `target_changed("cat")`, cursor 0, `get_current_target() == "cat"`; exact signal order `accepted → completed → target` via the `_log`; `get_implied_spaces()` is 1 inside the `target_completed` handler and after; two words → 2; letter-mode config and `null` config → `target_completed` never emitted, implied spaces 0, `get_cursor()` 0; PARAGRAPH-mode config → `target_completed` emitted, implied spaces stay 0; `run_started` still once, before the first `char_accepted`.
  - [x] 7.3 `tests/unit/test_hud.gd` (extend): word mode `show_target("dad", 1)` → `%TargetLabel.text == "dad"`, `%TypedLabel.text == "d"`, underline visible, its x = one glyph width and width = one glyph width, height 2; `typed == 3` → underline hidden, typed `"dad"`; `typed == 0` → typed label hidden/empty, underline under the first letter; out-of-range typed is clamped; hands light the cursor letter (`show_target("dad", 1)` lights `a`'s finger, not `d`'s); letter mode never shows underline or typed label; the shake offset moves the underline and typed label with the target (they're children); `update_clock(10.0, 50, 10)` shows WPM `StatsCalculator.wpm(50, 10.0, 10)` once due.
  - [x] 7.4 `tests/unit/test_grayscale_states.gd` (extend): typed vs untyped target text differ in luma (zombie-green-dark 0.349 vs ink 0.092 per the file header's palette luma table; compute luma the way `test_art_ui.gd::_luma` does, Rec. 709 on sRGB) and the next letter carries a non-colour cue (the underline node is visible).
  - [x] 7.5 `tests/integration/test_run_frame.gd` (extend, using the real `test_word_level` and a fixed `seed` payload): typing a whole word letter by letter → after the last letter the HUD shows the next word with 0 typed **before `handle_key` returns**, the level's brain total is 1 (its `on_target_completed` ran), `get_implied_spaces() == 1`; Space is not judged (errors 0, cursor unchanged, returns false from `handle_key`); a wrong letter mid-word shakes and counts 1 error; ending the run (`debug_end_run`) after N words gives `RunResult.completed_words == N` and `wpm == StatsCalculator.wpm(keys, duration, N)`. Copy the existing helpers (`_send`, recorder seams, temp `PlayerData`) — never write the real save.
  - [x] 7.6 Fix the tests this story knowingly changes: `test_level_registry.gd:110` (ids list gains `&"test_word_level"` after `&"test_level"`), any debug-overlay test that counts or lists jump buttons, and `test_level_base.gd` if the doc'd call order is asserted. Don't weaken any other assertion.
  - [x] 7.7 `test_test_level.gd`: word-mode instance builds a `WordSource`, a too-small band (e.g. min 7, max 7 on the shipped list) returns `null` without asserting, `on_target_completed` adds a brain and emits `brains_earned_changed`.
- [x] **Task 8: Docs, verification, wrap-up** (AC: 8, 9)
  - [x] 8.1 `LevelBase` doc: the call order gains `on_char_accepted` → `on_target_completed(word)` on a word's last letter, and "the source has already advanced" becomes "on the last letter of a target the source has already advanced; mid-word `current()` is still the same word". Remove "Not called until Epic 6 adds …" from `on_target_completed`.
  - [x] 8.2 `deferred-work.md`: strike through (with "Done in 6.2: …") the notes this story resolves — `target_completed` not declared (line ~132), `config` unused (~133), `ZombieHands` cursor character (~193). Leave the exhausted-source note open (WordSource is infinite) and say so in one line. Add new items only if found.
  - [x] 8.3 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Baseline **1344** passing (after Story 6.1 review patches — re-count before you start, record both numbers). Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 8.4 Visual check (Godot MCP `run_project` or the in-app browser on a web debug export): start "Test words" from the F3 overlay, type part of a word, take a screenshot showing green typed letters, the underline under the next letter and the matching lit finger; tune `UNDERLINE_GAP` from it. Save it as `_bmad-output/implementation-artifacts/screenshots/6-2/word-mode-hud.png`. If you run a web export, also confirm `words.json` loads there (closes the 6.1 review defer on `include_filter`).
  - [x] 8.5 Commit the generated `.uid` files for new scripts.

## Dev Notes

### What this story is (and isn't)

- It is: word targets end to end through the shared pipeline — `WordSource`, cursor + completion + implied spaces in `TypingSession`, `RunFrame` wiring, the HUD's green/underline display and hands-follow-the-cursor, live/final WPM with implied spaces, a debug-only word level to play it, and tests.
- It isn't: the Horde Rush level, `horde_rush.tres`, lanes, zombie copies (6.3+), size classes (6.3), defender (6.4), tier bands (Epic 7), paragraph rendering (8.2). `horde_rush` stays `available = false` with no scene. No save schema change, no new audio, no new art.

### Design decisions already made (follow them)

- **The word is the target; the session owns the cursor.** Architecture (Typing Pipeline): `TargetSource.current()` returns the target, `TypingSession` "tracks … implied spaces" and emits `target_completed(target)`. So `WordSource.current()` returns `"dad"`, and the session judges `"dad"[cursor]`. `ParagraphSource` (8.2) will reuse the same cursor with a passage as the target — don't build anything word-specific into the cursor logic.
- **Signal semantics.** `target_changed(next)` means "the current target changed": every key in letter mode (unchanged), only on completion in word mode. `char_accepted(expected, index)` always carries the single letter and the run-wide 0-based index (Zombie Run's groups rely on the index; don't make it per-word).
- **Emission order on a word's last letter:** `char_accepted` → `target_completed` → `target_changed`. The source advances before `char_accepted` (as today), so every handler in that call sees the next word as `current()` and cursor 0.
- **Implied spaces only in WORD mode.** FR7: "Horde Rush adds +1 per completed word". Paragraph Spaces are real keys (E8-1), so PARAGRAPH emits `target_completed` per passage but counts no implied spaces.
- **HUD driven from `char_accepted`, not `target_changed`.** The HUD must refresh on every letter (green progress), which `target_changed` no longer fires for in word mode. One call site (`_on_session_char_accepted`) keeps it simple and in the key's call stack (NFR2).
- **Overlay rendering, not RichTextLabel.** `%TargetLabel` is typed `Label` in at least `test_hud.gd`, `test_grayscale_states.gd`, `test_readability.gd`, `test_run_frame.gd`, and its `.text` is asserted to equal the current target. Keep it, and paint the typed prefix with a green `Label` on top plus a `ColorRect` underline. With a pixel font and nearest filtering the green glyphs cover the ink glyphs exactly. RichTextLabel's underline also isn't a guaranteed 2 px bar.
- **`WordSource` extends `LetterBagSource`.** A bag is stricter than the AC (no repeat within ~190 words, not just "not twice in a row") and is already tested and seed-stable. 191 words in the 3–5 band ≈ more than a 5:00 run at 30 WPM needs, so kids rarely see a repeat.
- **Word list via `LevelConfig.word_list: JSON` (ext_resource).** 6.1 note: runtime reads `words.json` as a `JSON` resource (`load()`/ext_resource), never `FileAccess` (only `SaveService` touches files). Injecting it through the config keeps `WordSource` pure and lets tests pass their own JSON. Band numbers live in the `.tres`, never as literals in scripts (architecture: "No GDD gameplay number appears as a literal").
- **Bad word data fails safe.** `pool_from_json` logs and filters; the level returns `null` when the pool is too small; `RunFrame._start_level` already turns a null source into "fail to menu" (NFR16). Never hit `LetterBagSource`'s debug asserts with content data.

### Existing code to read first (current state → what changes → what must be preserved)

- **`scripts/typing/typing_session.gd`** (UPDATE). Today: `expected = _source.current()`; a match advances the source, emits `char_accepted` then `target_changed`; per-key map keyed by expected char; `config` stored but unused. Change: cursor, `target_completed`, implied spaces, two getters. Preserve: verdict enum, `run_started` once before the first `char_accepted`, synchronous signals, `get_per_key()` deep copy, `get_upcoming()` delegating to `peek`, null-source guard, the guarded verbose logs.
- **`scripts/typing/letter_bag_source.gd`** (doc only). Its `_init` asserts pool ≥ 2 and unique — callers must pre-check.
- **`scripts/run/run_frame.gd`** (UPDATE, lines ~244–262 wiring, 155–158 `_process`, 420–431 `_record_result`, 452–453 `_on_session_char_accepted`). Preserve: connection order "level first, then HUD"; everything synchronous; state machine; seams; `LETTER_POOL_ALL` stays `"all"`.
- **`scripts/run/hud.gd`** + **`scenes/run/hud.tscn`** (UPDATE). `show_target` is also called by `setup()`; `_layout_target()` sizes the sign to the word (`test_word_sign_grows_with_the_word` expects `Rect2(116, 260, 208, 40)` for "zombie"); `_set_shake_offset` moves only `%TargetLabel` — that's why the overlay nodes are its children. Preserve all sign rects, the prompt strip, font sizes, the start prompt copy (already in `test_plain_words.gd` `APPROVED_COPY`: "Type the word to start!").
- **`scripts/run/zombie_hands.gd`** (read only): `show_char(target)` lights `target.left(1)`; same finger again keeps the pulse. No change needed.
- **`scripts/run/level_base.gd`** (doc update), **`scripts/levels/test_level/test_level.gd`** (UPDATE), **`scripts/debug/debug_overlay.gd`** (UPDATE lines ~77, ~249–256, ~289), **`scenes/debug/debug_overlay.tscn`** (add one button), **`data/levels/level_registry.tres`** (add one entry; bump `load_steps` if you add ext_resources).
- **`scripts/typing/stats_calculator.gd`**, **`run_result.gd`**: already take `completed_words` (Story 2.3). No change.
- **`scripts/typing/word_tagger.gd`** (read only): reuse `rejection_reason` and `STARTER_BAND_MIN_COUNT`.

### Architecture and rules to follow

- Godot **4.7.2** (standard), Compatibility renderer, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed vars, typed arrays (`Array[String]`), typed loop vars, typed returns. Tabs. `##` doc comments, short, saying why.
- Boundaries: `scripts/typing/` is pure (no nodes except `TypingInput`, no autoloads except `Log`); levels never read input, touch the clock or write `PlayerData`; the HUD is a view; "logic leads, visuals chase" — never `await` in typing callbacks.
- Randomness: the source gets its own child RNG (`child.seed = rng.randi()`), so seed replay (Story 2.10) stays exact.
- Every class in `scripts/typing/` has `tests/unit/test_<name>.gd` → `test_word_source.gd` is required.
- Logging: `Log.error/warn/debug(&"tag", ...)`; no logging in `_process`; per-key logs only behind `Log.verbose_typing`.
- Colours: palette only (`test_art_palette.gd`): ink and `zombie-green-dark #2E6B26`. Text ≥ 16 px; targets 32 px (NFR7).

### UX contract (DESIGN.md / EXPERIENCE.md)

- `target-word`: sign parchment, untyped `ink`, typed `zombie-green-dark`, `nextUnderline` ink, typography target (32 px). "The next letter underlined with a 2 px ink bar (shape cue)." The sign grows with the word; text never shrinks.
- EXPERIENCE: "Word: typed letters green, next letter underlined; completes on its last letter, no Space. The next target is shown in the same frame as the correct key." Flow 1 step 9: "He types d; it turns green and the underline slides to a."
- NFR8 / grayscale review: typed vs untyped must read without hue (luma 0.349 vs ink, plus the underline).
- The wrong-key shake moves the whole word (glyph label + overlay). FR2 says "shake the target character"; the HUD has always shaken the target label, and the whole word wobbling is the clearer cue for a kid. Keep it.

### Testing notes

- Commands in Task 8.3. Run `--import` after adding `word_source.gd` so `class_name WordSource` registers before GUT.
- JSON numbers load as `float`; `pool_from_json` uses `word.length()`.
- To build a JSON in a test: `var j := JSON.new(); j.parse('{"words": [{"word": "dad"}]}')` — `j.data` then holds the Dictionary. Assigning to a `JSON` typed var works because `JSON` is a `Resource`.
- Integration tests use recorder seams and a temp `PlayerData`; copy the patterns in `tests/integration/test_run_frame.gd` (never the real save).
- `LetterBagSource`/`TypingSession` contract asserts must not be triggered from tests (debug assert = test crash).

### Previous story intelligence (6.1)

- `words.json`: 246 words, 191 in 3–5; schema `{schema: 1, source, words: [{word, rows, length}]}`; shipped via `include_filter="data/content/*.json"` on both presets. A review defer asks to confirm it loads in a real web export once a runtime loader exists — that's this story (Task 8.4).
- Band minimums live in `WordTagger` (`STARTER_BAND_MIN_LEN/MAX_LEN/MIN_COUNT`) after review patches; reuse, don't duplicate.
- Lessons kept from Epic 5/6: edit story-file sections line-anchored; LF endings for new text files; new kid-facing copy goes into `test_plain_words.gd` `APPROVED_COPY` and EXPERIENCE.md ("Test words" is debug-only, not kid-facing; don't add it). Record any Smuck decision verbatim with a date.

### Git intelligence

- One commit per story on `main`, then "Story 6.2: code review patches applied, done" after review. Use `Story 6.2: word target mode`.
- Expected changes: `scripts/typing/word_source.gd` (+`.uid`), `scripts/typing/typing_session.gd`, `scripts/typing/letter_bag_source.gd` (doc), `scripts/resources/level_config.gd`, `scripts/run/run_frame.gd`, `scripts/run/hud.gd`, `scenes/run/hud.tscn`, `scripts/run/level_base.gd` (doc), `scripts/levels/test_level/test_level.gd`, `scenes/levels/test_level/test_word_level.tscn`, `data/levels/test_word_level.tres`, `data/levels/level_registry.tres`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`, tests (`test_word_source.gd` new + extensions), `deferred-work.md`, the screenshot, this file, `sprint-status.yaml`. Nothing in `scripts/autoloads/`, `project.godot`, `export_presets.cfg`, `.github/`, `assets/`.
- No tag push: Horde Rush publishes after Story 6.8.

### Project Structure Notes

- `scripts/typing/word_source.gd` is in the architecture tree (Epic 6). `test_word_level` lives with the test level under `scenes/levels/test_level/` and `data/levels/` (debug-only, same as `test_level`) — a variance from "one folder per level id", acceptable because it reuses `test_level.gd`.
- Word band on `LevelConfig` (not a Horde Rush subclass) because the test level, Horde Rush (6.3) and Pitchfork Panic's sentence generator (8.1) all need a word pool; Epic 7 swaps the fixed band for the tier band.

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md` (Typing Pipeline & Level Contract, Static Game Data, Boundaries, Consistency Rules), the GDD (*Horde Rush* word loop, *Stats* WPM, *Readability*) and the UX spines (DESIGN.md `target-word`, EXPERIENCE.md target patterns, NFR8).
- Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, Godot MCP available (`run_project`, `get_debug_output`) for the visual check.

### Latest tech information

- No new libraries. Godot 4.7.2 (verified in 6.1): `load("res://…json")` returns a `JSON` resource, `.data` is the parsed value, integers come back as `float`. `Font.get_string_size(text, alignment, width, font_size)` gives the pixel width used by `_layout_target`. GDScript subclass constructors pass arguments with `super(a, b)` inside `_init`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.2: Word Target Mode] (ACs); Epic 6 header; Stories 6.3, 6.7, 8.2 (consumers)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR3, FR4, FR7, FR8, FR9, FR15, FR54, FR59; NFR2, NFR7, NFR8, NFR16
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract] (`target_completed`, implied spaces, `TargetSource`, `LevelBase.on_target_completed`), #Static Game Data, #Directory Structure
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Horde Rush word loop (line ~312), Stats WPM (line ~130), finger guide (line ~197)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] `target-word` tokens (~249), Components > target word (~512), contrast table (~377)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] target patterns (~103), Flow 1 step 9 (~251), never colour alone (~209); mock `mockups/key-run-hud.html` (word mode)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] Story 2.2 notes (target_completed, exhausted source), 2.5 (word sign), 2.6 (hands cursor character)
- [Source: _bmad-output/implementation-artifacts/6-1-word-tagging-tool-and-starter-word-list.md] Forward notes, review defers
- [Source: scripts/typing/typing_session.gd], [scripts/typing/letter_bag_source.gd], [scripts/run/run_frame.gd:244-262], [scripts/run/hud.gd:100-104,131-143,168-205], [scripts/run/zombie_hands.gd:71-79], [scripts/levels/test_level/test_level.gd], [scripts/debug/debug_overlay.gd:77,249-256,289], [tests/unit/test_level_registry.gd:110]

### Review Findings

- [x] [Review][Decision] Underline sits directly under descenders (UNDERLINE_GAP 0) — RESOLVED: accepted gap 0 as shipped (dismissed) — Task 5.4 says the bar should be "clear of descenders of g j p q y", but the 40 px sign leaves 3 rows under a descender, so a 2 px bar cannot clear both descenders and the sign's dark edge. Options: (1) accept gap 0 as shipped; (2) gap 1, which fuses the bar with the sign edge; (3) enlarge the sign, which breaks "preserve all sign rects". Flagged by the Acceptance Auditor and by the dev's own completion notes. [scripts/run/hud.gd]
- [x] [Review][Patch] `pool_from_json` truncates the whole pool at the first non-Dictionary entry but skips other bad entries — use `continue` with a logged error, and log the non-String `word` skip too [scripts/typing/word_source.gd:32-37]
- [x] [Review][Patch] `judge` silently resets `_cursor` to 0 when `_cursor >= target.length()`, hiding a source/session desync — add a `Log.warn` [scripts/typing/typing_session.gd:57-58]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- GUT baseline before work: **1346** passing (story expected 1344; the 6.1 review patches added 2). After: **1395** passing (+49), 78 scripts, 0 `Parse Error|Compile Error|Failed to load script`.
- Red phase: `test_word_source.gd` failed to parse (no `WordSource`) before Task 2.
- Visual check: a real-window run (scratch capture script modelled on `tools/capture_screens.gd`, temp save dir, recorder seams) of the real `RunFrame` on `test_word_level`, seed 7, first word "fog". Pixel rows measured on the 640x360 frame: glyph top 264, baseline 291, `g` descender to 295, underline 296-297, one parchment row (298), sign's dark bottom edge 299.

### Completion Notes List

- `WordSource extends LetterBagSource` (no new shuffle code); `pool_from_json` filters by `WordTagger.rejection_reason` and `word.length()` in the band, skips repeats, keeps file order, and logs (never asserts) on bad data.
- `TypingSession`: cursor into the current target, `target_completed(target)` on the last letter (order `char_accepted` -> `target_completed` -> `target_changed`), implied spaces only in WORD mode (incremented before emitting), `get_cursor()` / `get_implied_spaces()`. In letter mode the path is unchanged (every target is 1 letter, so the "last letter" branch runs every key).
- `RunFrame`: level hears `on_target_completed`; the HUD target is refreshed only from `_on_session_char_accepted` (the `target_changed -> Hud.show_target` connection is gone); implied spaces go to live HUD WPM and `RunResult.completed_words`.
- HUD: `%TypedLabel` (zombie-green-dark) and `%NextUnderline` (2 px ink `ColorRect`) are children of `%TargetLabel`, so the shake moves them; `%TargetLabel.text` stays the whole word. Hands light `target.substr(typed, 1)`.
- `UNDERLINE_GAP` tuned to **0**: the 40 px sign leaves only 3 rows under a descender, so a 2 px bar cannot clear both the `g j p q y` descenders and the sign's dark edge. Gap 0 puts the bar 4 px under the baseline and directly under descenders, with 1 px of parchment above the edge; gap 1 would fuse it with the edge and lose the shape cue. The sign rects were kept (AC: "Preserve all sign rects"). Shown in `word-mode-hud-descender-sign-3x.png`; worth a look at review.
- `test_word_level` (debug-only registry entry + "Test words" jump button). Word mode earns 1 brain per word, no per-key brains. A band with < 2 words returns `null`, so RunFrame fails safely to the menu.
- Debug overlay jump row with 4 buttons still fits (row 404 px inside a 412 px panel; `debug-overlay-jump-row.png`).
- Not done: the web export check of `words.json` loading (Task 8.4 asks for it only "if you run a web export"; this check used a desktop window). The 6.1 `include_filter` defer stays open for the next web build.
- `deferred-work.md`: struck through the 2.2 `target_completed` and `config` notes and the 2.6 hands-cursor note; the exhausted-source note stays open with a one-line update.

### File List

- `scripts/typing/word_source.gd` (new) + `scripts/typing/word_source.gd.uid` (new)
- `scripts/typing/typing_session.gd`
- `scripts/typing/letter_bag_source.gd` (doc only)
- `scripts/resources/level_config.gd`
- `scripts/run/run_frame.gd`
- `scripts/run/hud.gd`
- `scenes/run/hud.tscn`
- `scripts/run/level_base.gd` (doc only)
- `scripts/levels/test_level/test_level.gd`
- `scenes/levels/test_level/test_word_level.tscn` (new)
- `data/levels/test_word_level.tres` (new)
- `data/levels/level_registry.tres`
- `scripts/debug/debug_overlay.gd`
- `scenes/debug/debug_overlay.tscn`
- `tests/unit/test_word_source.gd` (new) + `tests/unit/test_word_source.gd.uid` (new)
- `tests/unit/test_typing_session.gd`
- `tests/unit/test_hud.gd`
- `tests/unit/test_grayscale_states.gd`
- `tests/unit/test_test_level.gd`
- `tests/unit/test_level_registry.gd`
- `tests/unit/test_debug_overlay.gd`
- `tests/integration/test_run_frame.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/screenshots/6-2/word-mode-hud.png`, `word-mode-hud-sign-3x.png`, `word-mode-hud-descender.png`, `word-mode-hud-descender-sign-3x.png`, `debug-overlay-jump-row.png` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/6-2-word-target-mode.md`

## Change Log

- 2026-10-07: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-07: Implemented word target mode (WordSource, session cursor / completion / implied spaces, RunFrame wiring, HUD green + underline + hands on the cursor letter, debug Test words level, tests). GUT 1346 -> 1395. Status: review.
