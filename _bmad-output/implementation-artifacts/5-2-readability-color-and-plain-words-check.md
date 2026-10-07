---
baseline_commit: 2f3fb43ea45402ce7138d00031a8bf1d79af43e3
---

# Story 5.2: Readability, Color and Plain-Words Check

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a parent,
I want every screen readable by a 6-year-old and usable by a colorblind kid,
so that nobody is left out.

## Acceptance Criteria

1. **Sizes at 640×360 (NFR7).** **Given** every MVP screen (title, main menu, run HUD + Zombie Run playfield, pause panel + countdown, report card, Welcome Gift, Crypt Closet + confirm prompt) **When** it is checked at the 640×360 logical resolution **Then** the typing target is at least 32 px (the HUD target letter; see Dev Notes "What '32 px' means"), every piece of UI text a kid can see is at least 16 px, and every control a kid can click or focus is at least 32 px tall. Each finding is fixed or listed with Smuck's decision in `## Readability Audit`. A new GUT test walks every MVP screen and enforces the text floor and the click-target floor so they can't regress.
2. **Grayscale (NFR8).** **Given** grayscale screenshots of the zombie hands and the HUD **When** they are reviewed **Then** the active finger and the wrong-key feedback are still clear without color. The same review covers every other state that DESIGN.md / EXPERIENCE.md say must "read without hue": the five Closet tile states, focus on every focusable kind (button, level card, toggle, tile), toggle on vs off, and Available vs Coming soon level cards. Screenshots (color + grayscale, 640×360) are saved under `screenshots/5-2/`; luminance tests back the fill-based states.
3. **Plain words (NFR9, NFR16).** **Given** all player-facing text **When** it is reviewed **Then** every label uses words a 6-year-old can read, zombie slang appears only in voice and flavor art, and no technical error text can appear anywhere, including the web page when the engine fails to start. The full copy inventory and Smuck's verdict per line are in `## Copy Review`; a GUT test pins the approved copy and bans slang and technical text in labels.
4. **No ranks, no pressure (NFR10, NFR11).** **And** no difficulty labels, ranks or grades, and no timers outside runs exist anywhere a kid can reach (menu, Closet, Welcome Gift, report card, pause panel, title). Recorded as audit rows; the copy test bans the words.
5. **Carry-in from 5.0 (deferred to 5.2 by Smuck).** **And** the in-run Zombie Run scenes no longer use `StyleBoxFlat` placeholders: the letter tags on villagers, brain blocks and the base target, the base target's box, and the conga "×N" badge use the shared theme's 9-slice variations. `test_no_placeholder_chrome.gd` covers `scenes/levels/zombie_run/`. The tag letters keep their size, colour and position.
6. **Approval.** Smuck approves the copy decisions (Gate A) and the grayscale / size review (Gate B); both answers are recorded verbatim with the date in `### Review Findings

Code review 2026-10-06 (Blind Hunter, Edge Case Hunter, Acceptance Auditor): 1 decision_needed (resolved: keep), 6 patch, 3 defer, 23 dismissed.

- [x] [Review][Decision] (resolved 2026-10-06: keep the current text, dismissed) Web failure notice always says "needs a newer browser", even for a network or download failure — keep it, make it generic ("The game could not start. Try again, or try Chrome, Edge or Firefox on a computer."), or scope the text to the missing-features path [export_presets.cfg:33]
- [x] [Review][Patch] Plain-words copy walk drops strings: `_collect_labels` keys on node name only, so same-named labels (e.g. `TagLabel` on every Closet tile) overwrite each other and only the last is checked; `_scene_strings` has the same collision for same-named nodes in one scene [tests/unit/test_plain_words.gd:103-202]
- [x] [Review][Patch] Click-target floor test only walks `BaseButton`, so `LevelCard` and `ClosetItemTile` (both `extends Control`) are never checked; Readability Audit R4 and the art-style-sheet claim ("tiles 68, cards 124") are read from code, not tested [tests/unit/test_readability.gd:244-262]
- [x] [Review][Patch] `_scene_strings` does `(load(path) as PackedScene).get_state()`; a failed load crashes the whole test instead of reporting the path [tests/unit/test_plain_words.gd:110]
- [x] [Review][Patch] Red-colour ban in the export-preset test is a bare `"red"` substring match ("hundred", "preferred" trip it; `rgb(...)` reds pass); use a word-boundary regex on colour tokens [tests/unit/test_export_presets.gd]
- [x] [Review][Patch] 4.4's approved deviation in `deferred-work.md` still says "the focus ring sits on the tile's own edge", but this story moved the ring outside the ink edge; update that record and `crypt-closet-4-4.md` if it carries the same line [_bmad-output/implementation-artifacts/deferred-work.md]
- [x] [Review][Patch] `BadgePumpkin` (new variation instead of the spec'd `TagPumpkin`) lives only in the Debug Log and Gate B notes; add it to the Change Log and File List rationale [this file, Change Log]
- [x] [Review][Defer] `test_no_placeholder_chrome` uses `> 22` scene count and `test_plain_words` uses `> 80` / literal "Need 40 more" — brittle counts, assert specific scenes/derive from constants [tests/unit/test_no_placeholder_chrome.gd] — deferred, low risk, already listed as brittle label counts
- [x] [Review][Defer] `tools/capture_screens_runner.gd` lacks a null-image guard under `--headless`, a frame timeout, and cleanup on the size-mismatch early exit [tools/capture_screens_runner.gd] — deferred, dev-only tool (export-excluded)
- [x] [Review][Defer] Plain-words test does not cover `level_card.gd`'s `String(id).capitalize()` fallback or `tooltip_text` [tests/unit/test_plain_words.gd] — deferred, no such copy ships in the MVP

## Review Approval`. The full GUT suite passes.

## Tasks / Subtasks

- [x] **Task 1: Baseline and inventory (AC: 1, 3, 4)**
  - [x] 1.1 Run the full suite at the starting commit and record the count (5.1 ended at 1298 + its review patches; confirm it yourself). Hash `user://save.json` (`%APPDATA%/Godot/app_userdata/<project>/save.json`) before and after every full run and every capture run (the 4.5 real-save trap).
  - [x] 1.2 Fill `## Copy Review` from the inventory in Dev Notes "Copy inventory": confirm each row against the code (grep `text = ` in `scenes/` and `.text =` / string constants in `scripts/`; the grep commands are in Dev Notes), add anything the table misses, and mark each row **Keep** or **Change → "new words"** with a one-line reason. Debug-only screens (keyboard test, debug overlay, art reviews, the "Test level" card in debug builds) are listed once as exempt.
  - [x] 1.3 Fill the `## Readability Audit` rows for sizes (Task 3), technical text (Task 5) and ranks/timers (Task 5.4) as you go: **Pass / Fixed / Listed (Smuck's call)** + note.
- [x] **Task 2: Gate A — copy and size decisions (AC: 1, 3, 6)**
  - [x] 2.1 Show Smuck the Copy Review table (only the rows marked **Change** or **Ask**, plus the full list as a link) and the open size decisions (Dev Notes "Open decisions": the 24 × 24 pause button, the 32 px measure, the web failure notice wording). Ask with `AskUserQuestion` (one question per decision, recommendation first).
  - [x] 2.2 Record the answers verbatim with the date under `## Review Approval`. Spec copy changes must also be made in `EXPERIENCE.md` Voice and Tone (the spine is the copy contract; spines > mocks > sketches) — note the edit in the Change Log.
- [x] **Task 3: Size checks and the readability guard test (AC: 1)**
  - [x] 3.1 New `tests/unit/test_readability.gd`. For each MVP screen scene, instance it the way `tests/integration/test_screen_flow.gd::_instance` does (direct instance, `PROCESS_MODE_DISABLED`, recorder seams, a temp-dir `PlayerData` for the Welcome Gift and the Closet), plus the HUD, pause panel, countdown, confirm prompt (opened), level card, closet tile, menu toggle, brain counter and the Zombie Run target/villager/brain block/conga line scenes. Walk every visible `Label` and `Button` (including text set at runtime: fill the screens with realistic values the way each screen's own test does) and assert `get_theme_font_size(&"font_size") >= 16`. Assert the HUD `%TargetLabel` in LETTER mode is `>= 32` (and PARAGRAPH `>= 24`, already a `hud.gd` const; keep it covered).
  - [x] 3.2 Same walk: every `BaseButton` that is visible, not `FOCUS_NONE`-and-`MOUSE_FILTER_IGNORE`, has `get_global_rect().size.y >= 32` (click/focus target floor). Allow-list only what Smuck keeps at Gate A (e.g. the pause button if kept at 24), with the reason in a comment. Level cards and Closet tiles are far above it; the menu toggles' `IconButton` is 32 × 32; the PixelButtons are 32 tall today.
  - [x] 3.3 Don't duplicate the per-screen fit/margin tests (`test_main_menu.gd::test_text_fits_and_is_at_least_16px`, `test_welcome_gift.gd`, `test_crypt_closet.gd`, `test_report_card.gd`, `test_hud.gd`): the new test is the cross-screen floor; the screen tests keep owning layout. If you find a screen without a fit test (pause panel, countdown, confirm prompt with the longest question), add the fit check here: text width ≤ its rect, no word wider than its rect (copy `test_main_menu.gd`'s helper), longest real question = the longest live item name.
  - [x] 3.4 Fix what fails, or list it. Expected findings (verify, don't assume): the pause button is 24 × 24 (approved Story 2.5 sketch rect `Rect2(600, 16, 24, 24)`, asserted in `test_hud.gd`) — Gate A decides; everything else is expected to pass (5.0 kept the 16 px floor). Any layout change updates its layout test and the sketch note.
- [x] **Task 4: Grayscale and state review (AC: 2)**
  - [x] 4.1 Capture tool `tools/capture_screens.gd` (`extends SceneTree`, export-excluded with the rest of `tools/`): run in a **real window** (not `--headless`; the Dummy renderer draws nothing): `"/c/Program Files/Godot/Godot.exe" --path . -s tools/capture_screens.gd`. For each shot it instances the screen (same seams as 3.1, never the real save), sets the state, waits 2–3 frames, reads `root.get_texture().get_image()` (640 × 360 logical with stretch mode `viewport`; assert the size), and writes `screenshots/5-2/<nn>-<name>.png` plus `<nn>-<name>-gray.png` (Rec. 709 luma `0.2126 r + 0.7152 g + 0.0722 b` on the sRGB values, the formula `test_art_ui.gd::_luma` uses). Deterministic: fixed seeds, fixed values. 5.0 made `gate2-run-hud-capital-grayscale.png` this way ("rendered in a real Godot window"); this tool makes it repeatable. If a screen can't be driven from the tool, take it from the web debug build in the browser pane (pane **on screen**) and convert it with the same tool in a `--convert <png>` mode.
  - [x] 4.2 Shots (minimum): HUD with each hand lit at least once incl. a thumb (Space isn't a Zombie Run key: use the HUD/hands directly, `ZombieHands` getters), both glow frames (strong / weak); HUD mid wrong-key shake **and** at rest (same letter) side by side; run HUD with the Caps Lock hint; main menu with focus on the Zombie Run card, then on a Coming soon card, then on a toggle (one toggle off); pause panel with Resume focused and Music off; countdown; report card with the stamp and the bonus line; Welcome Gift; Closet with all five tile states visible at once (seed a temp save: one locked tile, one can't-afford, one buy, one wear, one wearing) and focus on a tile; confirm prompt open.
  - [x] 4.3 Review each grayscale shot against the `## Grayscale Checklist` (pass / fail + note). A fail gets a shape or brightness fix (never a hue-only fix), approved at Gate B.
  - [x] 4.4 Tests that make the review stick (new `tests/unit/test_grayscale_states.gd`, or extend the owning test file where it is clearly local):
    - Closet tiles: for every pair of the 5 states, they differ by shape/content (no tag / price number / "Wear" word / check sprite / "?" sprite and tile fill variation) — read through `ClosetItemTile`'s public API and node visibility, not pixels. Record the luma table (Dev Notes) in the test's header.
    - Focus: the focus ring (candy-yellow, luma 0.819) replaces or sits outside an ink edge (luma 0.092) on every focusable kind — assert the theme's focus box is the ring texture for `PixelButton`, `LevelCard`, `MenuToggle`'s icon button and `ClosetItemTile` (whatever each uses today; read `data/ui_theme.tres` and each script first).
    - Wrong key: `shake_target()` changes only the glyph's position — the target label's colour / modulate and the sign's style are unchanged during the shake (FR2: no colour change, "no red"). The finger luma test already exists (`test_art_ui.gd::test_lit_finger_is_brighter_in_grayscale`): keep it, don't duplicate.
    - Toggle off = slash (already pixel-tested in `test_menu_toggle.gd`) and Coming soon = plank sprite (`test_level_card.gd`): keep, reference them in the checklist.
  - [x] 4.5 This also closes the 5.0 review deferral "HUD grayscale legibility (AC 5) is covered by a screenshot only, not a test" (the luma test exists in `test_art_ui.gd`; the HUD shot is now produced by a tool): strike it in deferred-work with a pointer.
- [x] **Task 5: Plain words, technical text, ranks and timers (AC: 3, 4)**
  - [x] 5.1 Apply the Gate A copy changes (scene `text =`, script constants, `.tres` display names). Keep `%UniqueName`s; update the tests that assert the old strings (grep the old string in `tests/`).
  - [x] 5.2 New `tests/unit/test_plain_words.gd`: collect every player-facing string from the MVP scenes (static `text` of `Label`/`Button` in `scenes/screens/` except `keyboard_test.tscn`, `scenes/run/`, `scenes/ui/`, `scenes/levels/zombie_run/`), the script copy (`hud.gd` `PROMPTS`, `menu_toggle.gd` `CAPTIONS`, `ClosetItemTile.info_lines()` for each state, the confirm-prompt question for every **live** catalogue item, `report_card.gd` `FALLBACK_HEADING`, `main_menu.gd` `STORAGE_NOTICE_TEXT`), the live catalogue items' `display_name`s and the non-debug level names. Assert: (a) every string is in an `APPROVED_COPY` list in the test (exact match, or a pattern for `Need %d more` / `+%d bonus` / `+%d` / numbers / times) — new copy can't ship without being added on purpose; (b) no slang (`brains+s`, `braa+ins`, `uuh`, `grr`… case-insensitive regex; "Brains" the currency word is fine); (c) no technical text (`error:`, `null`, `nil`, `invalid`, `exception`, `failed`, `res://`, `user://`, `%s`, `%d` left unformatted, `_` in a word, `StringName`/`&"`); (d) no rank / difficulty words (`easy`, `hard`, `difficulty`, `rank`, `grade`, `beginner`, `expert`, `level \d`, `noob`, `pro`); (e) sentence case (no all-caps word except the allow-listed `WPM` and `Esc` if kept).
  - [x] 5.3 Technical error text, every path a kid could see it:
    - **Web failure notice.** The default shell's `#status-notice` shows the engine's own message when the game can't start (missing WebGL 2 / features, a failed download): technical English. Read the shell again from `%APPDATA%/Godot/export_templates/4.7.2.stable/web_nothreads_release.zip → godot.html` (5.0 did) to confirm how the notice is filled. Replace what a kid sees with a plain message through the existing `html/head_include` CSS — hide the engine text and show plain words with `#status-notice::after { content: "…" }` (e.g. "This game needs a newer browser. Try Chrome, Edge or Firefox on a computer." — wording at Gate A), parchment + ink as today, ≥ 16 px equivalent, never red. The engine message stays in the console (`console.error`) for Smuck. Only if CSS can't do it, use a `html/custom_html_shell` and write the reason here (same rule as 5.0 AC 2). `tests/unit/test_export_presets.gd`: assert the head include has the plain message and hides the engine text. Check it once in the browser pane by forcing the notice (e.g. temporarily run the exported page with WebGL disabled, or call the shell's notice function from the console in a scratch copy — never edit `build/` by hand for the commit).
    - **In-game fallbacks**: `level_card.gd` falls back to `String(entry.id).capitalize()`; `report_card.gd` to "Report Card"; screens recover silently to the menu on a failed load (NFR16). Confirm no `Log` text, `push_error` text, `OS.alert` or error string ever reaches a `Label` (grep: `OS.alert` has no hits today; keep it that way — the copy test's technical-text rule covers labels).
    - **Windows fallback**: an OS-level driver dialog from Godot itself (e.g. no OpenGL 3.3) is out of scope; list it in the audit as "engine, not ours, Windows fallback only".
  - [x] 5.4 Ranks and timers outside runs: audit the menu, Closet, Welcome Gift, report card, pause panel and title for any countdown, clock or rank text (the report card's 1.0 s input guard is invisible: Pass; "Lesson Time" is a stat of the finished run, not a timer: Pass; the pause countdown 3-2-1 is inside the run: Pass; "New best!" praises the run, not a rank: Pass). Record each row.
- [x] **Task 6: In-run placeholder boxes → theme (AC: 5)**
  - [x] 6.1 `scenes/levels/zombie_run/villager.tscn`, `brain_block.tscn`, `zombie_run_target.tscn`: replace `StyleBoxFlat_tag` (parchment fill, 1 px ink border) with `theme_type_variation = &"Sign"` on the `%Tag` `Panel` (the parchment 9-slice with `sm` stepped corners, 9s 4; read `data/ui_theme.tres` `sign` first). The tag is 24 × 24, so a 4 px corner margin fits. `zombie_run_target.tscn`'s `%Box` (parchment-shade placeholder body, only seen in the base/test fixture: the real run spawns villagers and brain blocks) gets `Sign` (parchment), so the resolved look in 6.3 (`SignGrey`) is a visible change. The project theme is global (`project.godot` `gui/theme/custom = "res://data/ui_theme.tres"`), so a `Panel` under a `Node2D` still resolves the variation; confirm it in a test (`get_theme_stylebox(&"panel")` is a `StyleBoxTexture`) and check the letter stays ink, 16 px, centred.
  - [x] 6.2 `conga_line.tscn` `%Badge`: replace `StyleBoxFlat_badge` (pumpkin fill, ink border, content margin 2) with `TagPumpkin` (the Closet's pumpkin tag 9-slice). Keep the content margins so "×13" doesn't move more than 1 px; the badge stays ink text at 16 px (`ink` on `pumpkin` = 6.3:1).
  - [x] 6.3 **Trap:** `ZombieRunTarget._on_resolved()` (`zombie_run_target.gd:73-79`) reads `%Box`'s panel `as StyleBoxFlat`, duplicates it and sets `bg_color = RESOLVED_FILL`; with a `StyleBoxTexture` the cast is null and it silently returns without greying. Rewrite it to switch `%Box` to the `SignGrey` variation (`theme_type_variation = &"SignGrey"`; same intent: a resolved target greys out), drop `RESOLVED_FILL` (or keep it only if a test needs the colour), and update its test in `test_zombie_run_target.gd`. `BrainBlock` and `Villager` override `_on_resolved()` with their own looks (bonk, poof): leave them.
  - [x] 6.4 `tests/unit/test_no_placeholder_chrome.gd`: add `res://scenes/levels/zombie_run/` to `SCENE_DIRS`; `test_the_walk_finds_the_ui` count goes up accordingly. Update `test_zombie_run_target.gd` / `test_villager.gd` / `test_brain_block.gd` / `test_conga_line.gd` only where they asserted the `StyleBoxFlat` look.
  - [x] 6.5 Look at it at 1× and 3× (capture tool or art review) next to the HUD target sign: the in-world tags and the HUD sign are now the same family. Include in Gate B.
- [x] **Task 7: Gate B — review and approval (AC: 2, 6)**
  - [x] 7.1 Show Smuck the `screenshots/5-2/` color + grayscale pairs (grouped: hands/HUD, menu, pause/countdown, report card, gift, Closet, in-run tags), the filled `## Grayscale Checklist` and `## Readability Audit`.
  - [x] 7.2 Record the verbatim answer with the date in `## Review Approval`. **No status change to review without it.** Re-show after any requested fix.
- [x] **Task 8: Wrap-up**
  - [x] 8.1 Full suite twice (import first: new `class_name`s / scenes), real `save.json` hash unchanged. Mutation pass (break, see a test fail, restore; report survivors honestly): a 14 px label in a screen; a 24 px-tall PixelButton; "Brainsss" on a button; "Error: null" in a label; the word "easy" in a level name; a new unapproved string; a `StyleBoxFlat` back in `villager.tscn`; the target label turning red during the shake; two tile states with the same shape/content; the web head include without the plain notice.
  - [x] 8.2 `deferred-work.md`: strike with `~~…~~ Done in 5.2: …` — the 5.0 in-run `StyleBoxFlat` item (both entries), the 4.4 "grayscale review of the five tile states" reminder, the 5.0 review "HUD grayscale … screenshot only". Mark the Coming soon `Tint` item "accepted for MVP at the 5.0 review; 5.2 grayscale: <result>". Add "Deferred from: dev of story 5-2" with whatever Gate A/B left open.
  - [x] 8.3 `docs/art-style-sheet.md`: one short "Readability and grayscale (Story 5.2)" note: the 16 px / 32 px floors and what 32 px measures, the luma table, the capture tool command. Keep test-quoted wording in step.
  - [x] 8.4 Header comments of every touched script record the story (house style). LF line endings, UTF-8.
  - [x] 8.5 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`. Suggested commit: `Story 5.2: readability, color and plain-words check`.

## Readability Audit

_(Tasks 1.3, 3, 5. One row per finding or check. Result: Pass / Fixed / Listed — Smuck's call.)_

| # | Screen / element | Check | Measured | Result | Note |
|---|------------------|-------|----------|--------|------|
| R1 | Run HUD target letter | ≥ 32 px (NFR7) | font size 32 (PARAGRAPH 24); Press Start 2P ink: caps / ascenders 28 px, lowercase x-height ~20 px | Pass | Gate A: "32 px" = font size (the `{typography.target}` token). Ink ≥ 32 px would need font 40/48 and a new HUD sketch: not taken. `test_readability.gd::test_hud_target_letter_is_at_least_32px` |
| R2 | Every MVP Label / Button (title, menu + storage notice, report card all rows + stamp, gift, Closet, HUD, pause, countdown, confirm, card, tile, toggle, counter, in-run tags + badge) | text ≥ 16 px | min 16 (theme default 16; 24/32/64 headings and digits) | Pass | `test_readability.gd::test_every_label_and_button_is_at_least_16px` (60+ nodes walked) |
| R3 | Pause button | click target ≥ 32 px tall | was 24 × 24 at (600, 16) | Fixed | Gate A "Grow hit area": 32 × 32 at (592, 16); the three pause styleboxes have −4 px expand margins so the 24 px art is drawn unchanged, centred; icon moved +4/+4 to stay on it. `test_hud.gd` rect + `test_pause_art_stays_24px_and_centred_in_the_hit_area`; sketch `hud-band-2-5.md` row updated |
| R4 | Every other clickable (PixelButtons, toggles' icon buttons, level cards, Closet tiles, Yes/No, Menu/Hats/Pets, Play Again/Menu, Open the Crypt Closet, Resume/Quit) | ≥ 32 px tall | all ≥ 32 (PixelButtons 32, IconButton 32, tiles 68, cards 124) | Pass | `test_readability.gd::test_every_clickable_is_at_least_32px_tall` (no allow-list) |
| R5 | In-world letter tags (villager, brain block, base target) and the ×N badge | ≥ 16 px (labels, not the target) | 16 | Pass | the HUD sign is the 32 px target (FR30 matches it to the active tag) |
| R6 | Web failure notice | no technical text | was the engine's English ("Error / The following features required to run Godot projects on the Web are missing: …") | Fixed | Gate A wording via the head include: engine text `font-size: 0` (kept in the DOM and `console.error`), `::after` shows "This game needs a newer browser. Try Chrome, Edge or Firefox on a computer." in ink on parchment, `max(16px, 16 units)`. Checked in the browser pane on a scratch copy of the real 4.7.2 shell with the missing-features path forced: `screenshots/5-2/30-web-failure-notice.jpg` (18.75 px). `test_export_presets.gd::test_web_failure_notice_shows_plain_words_not_the_engine_text` |
| R7 | Ranks / difficulty words | none (NFR10) | none in any MVP string | Pass | `test_plain_words.gd` bans easy/hard/difficult/rank/grade/beginner/expert/level N/noob/pro |
| R8 | Timers outside runs: title, menu, Closet, Welcome Gift, report card, pause panel | none (NFR11) | no clock or countdown text on any of them | Pass | report card 1.0 s and gift 0.5 s input guards are invisible; "Lesson Time" is a stat of the finished run; the pause 3-2-1 is inside the run; "New best!" praises the run, not a rank |
| R9 | In-game fallbacks | no technical text in a Label | `level_card.gd` falls back to `String(id).capitalize()` ("Zombie Run"); `report_card.gd` to "Report Card"; failed loads recover to the menu; no `OS.alert`, no `Log` / `push_error` text reaches a Label (grep) | Pass | the copy test's technical-text rule covers every Label/Button string |
| R10 | Windows: OS-level driver dialog (no OpenGL 3.3) | — | engine, not ours | Listed | Windows fallback only; out of scope |
| R11 | Pause panel, countdown, confirm prompt (every live item's question) | text fits its box | fits | Pass | new fit checks in `test_readability.gd` (no screen test of their own) |
| R12 | Storage notice copy | plain words | "Progress may not be saved in this browser mode" | Fixed | Gate A: "This browser might forget your brains"; fits the 260 px note (menu fit test) |

## Grayscale Checklist

_(Task 4.3. Look at the `-gray.png` of each shot. Pass when the state is obvious to someone who has never seen the colour version.)_ Shots: `screenshots/5-2/` from `tools/capture_screens.gd` (640×360, colour + `-gray`, 3× crops `*-3x*`).

| # | State | Must read as | Carried by (shape / brightness) | Result |
|---|-------|--------------|----------------------------------|--------|
| G1 | Active finger vs resting fingers | the one to press | lit fill luma 0.867 vs 0.655 + 2 px candy ring (strong) / 1 px (weak) pulse | Pass — shots 01–06 + `-hands-3x-gray`: the lit finger (index, pinky, both thumbs) is the brightest shape with a rim in both glow frames. Test: `test_art_ui.gd::test_lit_finger_is_brighter_in_grayscale` |
| G2 | f / j bumps | home keys | bump shape on the index fingers | Pass — dark bump visible on both index fingers in every hands crop |
| G3 | Wrong key | "that wasn't it" | the target letter shakes ±2 px for 0.2 s + the tick sound; no colour change at all (FR2) | Pass — 07 vs 08 `-sign-3x-gray`: same glyph, same ink, 2 px apart; motion + sound carry it. Test: `test_grayscale_states.gd::test_wrong_key_shake_changes_position_only` |
| G4 | Caps Lock on | a hint is showing | candy sign + the words "Caps Lock is on" | Pass — 09: bright sign with words above the prompt strip |
| G5 | Focus (button, card, toggle, tile) | "you are here" | 2 px candy ring (0.819) outside an ink edge (0.092); PixelButton fill pumpkin-light 0.708 vs wood 0.356; card bob | **Fail → Fixed (Gate B)** for Closet tiles: before the fix the inset ring replaced the ink edge next to the parchment (sampled 208 vs 231) and the focused tile only looked 1 px bigger. Moved the tile to `FocusRing` (2 px outside the ink edge, like the level card): `26-closet-tile-focus-before-after-3x.png`. Pass for PixelButtons (10–14, 16, 17, 20: bright fill + rim), level cards (10, 11: rim + lift), toggles (12: rim on the icon). Test: `test_grayscale_states.gd::test_every_focusable_kind_shows_the_ring_outside_its_edge` |
| G6 | Pressed button | "I pressed it" | 2 px squish onto the shadow | Pass — art (the `pressed` box is drawn 2 px lower); not a hue cue |
| G7 | Toggle on vs off | music/sound/fullscreen state | off = stamp-red diagonal slash + stone-light icon; on = bright icon | Pass — 12 `-toggles-3x-gray`: off icons darker with a dark diagonal; on icon bright. Test: `test_menu_toggle.gd` (slash) |
| G8 | Available vs Coming soon card | can / can't play | Coming soon = grey stone tint + the hand-lettered plank | Pass — 10/11: plank with words + darker picture; Available is bright. Test: `test_level_card.gd` (plank). The `Tint` alpha overlay accepted at the 5.0 review stays |
| G9 | Closet: Locked | not yet in the shop | stone tile + "?" silhouette, no tag | Pass — 18: dark tiles with "?" |
| G10 | Closet: Can't afford | need more brains | disabled fill (0.779), price with no tag box, info "Need N more" | Pass — 18 (heart headband, 200): light tile, art shown, bare muted price, no box |
| G11 | Closet: Buy | can buy | pumpkin tag (0.550) with the price | Pass — 18: boxed number |
| G12 | Closet: Wear | owned, not worn | zombie-green tag (0.655) with the word "Wear" | Pass — boxed word (apart from Buy by content, not brightness) |
| G13 | Closet: Wearing | worn now | bright tag (0.867) with the check mark | Pass — bright box with the check. Test: `test_grayscale_states.gd::test_the_five_tile_states_differ_by_shape_or_content` |
| G14 | New best | a personal best | the stamp shape + words | Pass — 16: tilted stamp with "New best!" |
| G15 | Active in-world target | the one to type | bob + candy down-arrow above the tag | Pass — 21/22/23: arrow above the active tag; the in-world tags are now the same parchment sign as the HUD letter (AC 5) |
| G16 | Web failure notice (extra) | plain message | ink on parchment | Pass — `30-web-failure-notice.jpg` |

## Copy Review

_(Task 1.2 fills the Verdict column; Gate A decided the rows marked Ask (2026-10-06). "Spec" = verbatim in EXPERIENCE.md Voice and Tone or the FRs.)_ Confirmed against the code with the Dev Notes greps; `test_plain_words.gd` `APPROVED_COPY` is this table.

| Where | Text | Source | Recommendation | Verdict |
|-------|------|--------|----------------|---------|
| Title | Click or press any key | spec | Keep | Keep |
| Menu | Zombie Run · Horde Rush · Pitchfork Panic | level names (spec) | Keep (names; picture on the card) | Keep |
| Menu | Coming soon (plank sprite) | spec | Keep | Keep (hand-lettered sprite) |
| Menu | Crypt Closet | spec (name, D16) | Keep (name; signpost + mirror art) | Keep |
| Menu / pause | Music · Sound · Fullscreen | spec | Keep | Keep |
| Menu | Progress may not be saved in this browser mode | spec (FR27) | **Ask** | **Change → "This browser might forget your brains"** (Gate A; EXPERIENCE.md updated) |
| HUD | Timer · Keys · WPM · Errors | spec (FR14) | **Ask** on "WPM" — recommend Keep | Keep (Gate A; "WPM" is the copy test's one allowed all-caps word) |
| HUD | – (WPM before 5 s) | 2.5 | Keep (not a word) | Keep |
| HUD | Type the letter to start! (word / text: post-MVP modes) | spec | Keep | Keep |
| HUD | Caps Lock is on | spec | Keep | Keep |
| Run | ×13 (conga badge) | spec | Keep | Keep |
| Pause | Paused · Resume · Quit to Menu | spec ([ASSUMPTION] in UX) | **Ask** on "Resume" — recommend Keep | Keep (Gate A) |
| Countdown | 3 · 2 · 1 | spec | Keep | Keep |
| Report card | (level name heading) · Keys Typed · Errors · WPM · Accuracy · Lesson Time · Brains Collected · +N bonus · N% · M:SS | spec (FR19) | Keep | Keep all (Gate A) |
| Report card | New best! (stamp) · Play Again · Menu · Enter · Esc | spec | Keep | Keep (Gate A: "Esc" matches the key cap) |
| Report card | Report Card (fallback heading, only without a result) | 2.9 | Keep | Keep |
| Welcome Gift | Welcome gift! · +100 · Open the Crypt Closet | spec | Keep | Keep |
| Closet | Menu · Hats · Pets | 4.4 | Keep | Keep |
| Closet | Coming soon · Need N more · Buy · Wear · Wearing | spec | Keep | Keep |
| Closet | Buy the Pumpkin hat for 100 brains? · Yes · No | spec | Keep | Keep (every live item's question is pinned by pattern) |
| Closet | Pumpkin hat · Cute ghost (live items) | catalogue | Keep (locked items show no name) | Keep; a newly live item must be added to `APPROVED_COPY` on purpose |
| Web | engine failure notice | Godot shell | **Change** → plain words, wording **Ask** | **Change → "This game needs a newer browser. Try Chrome, Edge or Firefox on a computer."** (Gate A; EXPERIENCE.md row added) |
| Debug only | keyboard test, F3 overlay, art reviews, "Test level" card, the test level's "Brains: N" / "Time!" | dev | Exempt (not in release; 5.5 checks the release build) | Exempt |

Notes: title-case labels ("Keys Typed", "Play Again", "Quit to Menu") are spec verbatim and kept; the copy test bans all-caps words, not title case. No zombie slang appears in any label.

## Review Approval

_(Gate A and Gate B: Smuck's words, verbatim, with the date.)_

**Gate A — copy and size decisions (2026-10-06).** Asked with `AskUserQuestion`, one question per decision; Smuck's answers verbatim:

- Pause button (24×24, under the 32 px floor): **"Grow hit area (Recommended)"** — 32×32 at (592, 16), the 24 px icon centred, art unchanged.
- What "32 px" measures: **"Font size (Recommended)"** — the `{typography.target}` token; ink heights recorded in R1.
- Storage notice: **"Kid words (Recommended)"** — "This browser might forget your brains".
- Web failure notice: **"Newer browser (Recommended)"** — "This game needs a newer browser. Try Chrome, Edge or Firefox on a computer."
- WPM: **"Keep WPM (Recommended)"**.
- Resume: **"Keep Resume (Recommended)"**.
- Report card stat names: **"Keep all (Recommended)"**.
- "Esc" key hint: **"Keep Esc (Recommended)"**.

**Gate B — grayscale and size review (2026-10-06).** Shown: `screenshots/5-2/gate-b-1-hands-hud.png`, `gate-b-2-menu-pause.png`, `gate-b-3-report-gift-closet.png`, `gate-b-4-run-tags.png` (colour | grayscale, 640×360), `26-closet-tile-focus-before-after-3x.png`, `30-web-failure-notice.jpg`, plus the filled Grayscale Checklist and Readability Audit. Smuck's answers verbatim:

- Grayscale and size review: **"Approve (Recommended)"**.
- Closet tile focus fix (ring 2 px outside the ink edge, `FocusRing`, deviating from the 4.4 inset ring): **"Keep the fix (Recommended)"**.
- Conga badge `BadgePumpkin` variation (the TagPumpkin art as a PanelContainer, 3 px content margins): **"Keep BadgePumpkin (Recommended)"**.

## Dev Notes

### What this story is (and isn't)

- **Is:** an audit with teeth: measure every MVP screen against NFR7/8/9/10/11/16, fix or list each finding, and leave tests that keep it that way (text floor, click-target floor, approved copy, banned words, tile-state distinctness, no-colour wrong key); a repeatable 640×360 capture tool for color + grayscale review; the plain-words web failure notice; the in-run `StyleBoxFlat` tags Smuck deferred from 5.0; two approval gates.
- **Isn't:** new art (reuse the 5.0 theme variations; if Gate B asks for a new shape, add it to `tools/gen_ui_art.gd` and its tests, never hand-edit a PNG); layout changes beyond what Gate A approves; performance or 1366×768 checks (Story 5.3); the playtest (5.4); release-build checks (5.5); a colourblind simulation mode in the game; screen-reader support (out of scope, EXPERIENCE Accessibility Floor); post-MVP copy (Locked / New! cards, word/paragraph modes) — only note it.

### What "32 px" means (decide at Gate A, record in R1)

- NFR7 / GDD Readability: "the target character … is at least 32 px tall". DESIGN Typography makes it the `{typography.target}` token = **font size 32 px**, and every story since 2.5 built it that way (`hud.gd` `LINE_FONT_SIZE = 32`; the sign is 48 × 40 for one letter).
- Press Start 2P draws on an 8 px grid inside the em: at 32 px a capital's ink is 28 px tall and a lowercase x-height letter (`a`, `e`, `o` …) is ~20 px; ascenders (`b d f h k l t`) 28 px; descenders go below. Zombie Run is lowercase-only.
- **Recommendation:** keep "32 px = font size" (the token, the em box; whole multiple of the 8 px grid), record the ink heights in R1, and let Smuck decide. If Smuck wants ink ≥ 32 px, the next clean size is **40 px** (x-height 25) or **48 px** (x-height 30, sign 64 × 56) — both change the approved 2.5 HUD sketch (sign rects asserted in `test_hud.gd`, the 104 px band budget) and need a sketch update: list as a follow-up rather than doing it silently.
- The in-world tags (villager, brain block) are labels at 16 px, not "the target"; FR30 makes the HUD sign match the active one, and the active tag gets the bob + arrow.

### Open decisions for Gate A (recommendations first)

1. **Pause button 24 × 24** (approved 2.5 sketch, `Rect2(600, 16, 24, 24)`): recommend growing the **hit area** to 32 × 32 at `(592, 16)` with the 24 px round icon centred (art unchanged, still inside the 16 px margin; Esc stays the keyboard path), or keep and allow-list it.
2. **The 32 px measure** (above): recommend font size.
3. **Copy rows marked Ask** (storage notice, WPM, Resume, report card stat names): recommend Keep except the storage notice; Smuck's words win. Any change also edits EXPERIENCE.md Voice and Tone.
4. **Web failure notice wording**: recommend "This game needs a newer browser. Try Chrome, Edge or Firefox on a computer."

### Palette luma (Rec. 709 on sRGB, the `test_art_ui.gd::_luma` formula)

ink 0.092 · night 0.135 · wood-dark 0.222 · dusk 0.234 · stamp-red 0.275 · ink-muted 0.289 · zombie-green-dark 0.349 · wood 0.356 · stone 0.426 · pumpkin **0.550** · zombie-green **0.655** · pumpkin-light 0.708 · stone-light 0.724 · parchment-shade 0.746 · disabled-fill 0.779 · candy-yellow 0.819 · zombie-green-bright **0.867** · parchment 0.908 · chalk 0.944.

- Buy (pumpkin 0.550) vs Wear (green 0.655) tags are only 0.105 apart: they **must** stay apart by content (price number vs the word "Wear"), which is what the tile test pins (4.4 note in deferred-work).
- Candy ring on parchment (0.819 vs 0.908) is weak by brightness alone; it works because the ring replaces / sits beside the ink edge (0.092). Check focus on parchment tiles and signs specifically in grayscale (G5).
- Stamp-red slash (0.275) on stone-light (0.724) is a strong dark diagonal: good.
- Grayscale is stricter than any colour-vision type (it removes all hue), so passing it covers protan/deutan/tritan kids for state reading; no separate simulation is required.

### Copy inventory: where the strings live (for Task 1.2 and the copy test)

- Scenes (`text = `): `scenes/screens/title.tscn` (prompt), `main_menu.tscn` (Closet button, storage notice), `report_card.tscn` (labels, buttons, key hints, fallback heading), `welcome_gift.tscn`, `crypt_closet.tscn` (Menu, Hats, Pets), `scenes/run/hud.tscn` (Timer/Keys/WPM/Errors, start prompt, Caps Lock hint), `pause_panel.tscn` (Paused, Resume, Quit to Menu), `countdown.tscn` (digits), `scenes/ui/confirm_prompt.tscn` (Yes/No), `menu_toggle.tscn` (caption, overwritten by `CAPTIONS`), `brain_counter.tscn` ("0").
- Scripts: `hud.gd` `PROMPTS`, `WPM_PLACEHOLDER`; `menu_toggle.gd` `CAPTIONS`; `closet_item_tile.gd` `info_lines()` + `WEAR_TEXT`; `crypt_closet.gd:308` confirm question format; `main_menu.gd` `STORAGE_NOTICE_TEXT`; `report_card.gd` `FALLBACK_HEADING`, `"+%d bonus"`, `"%d%%"`; `welcome_gift.gd` `"+%d"`; `level_card.gd:61` name fallback; `conga_line.gd` `BADGE_PREFIX "×"`; `stats_calculator.gd` time format.
- Data: `data/levels/level_registry.tres` display names (Test level is debug-only), `data/cosmetics/*.tres` display names (only `available = true` items are ever named in the MVP; locked tiles show "Coming soon").
- Sprites with words (hand-lettered, not font): logo, "Coming soon" plank, "New best!" stamp, "Crypt Closet" sign — include them in the review by eye; they can't change without `tools/gen_ui_art.gd`.
- Greps: `grep -rn '^text = ' scenes --include=*.tscn | grep -v scenes/debug`; `grep -rn '\.text = \|const .*: String = "' scripts | grep -v 'scripts/debug\|Log\.'`; `grep -rhn 'display_name = ' data`; font sizes: `grep -rn 'font_size = ' scenes | grep -v scenes/debug` (only debug scenes use 8 px; `keyboard_test.tscn` 20 px is debug).

### Existing code: current state, what changes, what must be preserved

- **`scenes/levels/zombie_run/{villager,brain_block,zombie_run_target,conga_line}.tscn`** — today: `StyleBoxFlat` tag (parchment `#F6E7C1`, 1 px ink border, 24 × 24 `Panel` `%Tag` with a 16 px ink `%Letter`), the base target's 20 × 20 parchment-shade `%Box`, the conga `%Badge` `PanelContainer` (pumpkin, margins 2). **Change:** theme variations (Task 6). **Preserve:** node names / `%UniqueName`s, offsets (tag positions are tied to the arrow tip "4 px above the tag", Story 3.6, and to `HALF_WIDTH = 12`), `mouse_filter = 2`, the letter size/colour, the villager → party-zombie swap, the brain-block hop moving `%Lift` with its tag, `test_run_rng_has_one_consumer`.
- **`scripts/run/hud.gd`** — `shake_target()` moves only the glyph by `SHAKE_PX` for `GameConstants.WRONG_KEY_SHAKE_S`; `get_shake_offset()` getter. The test for "no colour change" reads the label colour before/after; don't add colour feedback.
- **`scripts/ui/closet_item_tile.gd`** — `State` enum (LOCKED, CANT_AFFORD, BUY, WEAR, WEARING), `state_for()`, `info_lines()`, tag variations `TagPumpkin`/`TagGreen`/`TagBright`, `Bare` for no box, the check and "?" sprites. Read-only for this story unless Gate B asks for a shape fix.
- **`export_presets.cfg` `html/head_include`** — 5.0's CSS for `body`, `#status`, `#status-splash`, `#status-progress` (incl. `:indeterminate` stripes), `#status-notice` (parchment, ink, 2 px ink border). Add the notice rules there; keep everything else byte-identical (asserted by `test_export_presets.gd`). Web preset only; the Windows preset has no shell.
- **`tests/unit/test_no_placeholder_chrome.gd`** — `SCENE_DIRS` gains the zombie_run scene dir; `EXEMPT_SCENES` unchanged.
- **Layout tests** (`test_hud.gd` pause-button rect, the screens' fit/margin tests) — only change with a Gate A decision.
- **`tests/integration/test_screen_flow.gd`** — the pattern for instancing screens safely (disabled, recorder seams, temp-dir `PlayerData`); reuse its approach, don't call `Router.go()` in tests.

### Testing notes

- GUT 9.7.1: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- `get_theme_font_size()` works headless on a node in the tree; text width via `get_theme_font(&"font").get_string_size(...)`. Global rects need the node in the tree and one layout pass (see how `test_main_menu.gd` waits).
- Never assert on the live `AudioManager` / `PlayerData` state; inject seams before `add_child` (house pattern). The Closet and Welcome Gift need a temp-dir `PlayerData` (they write).
- Typed declarations everywhere (`untyped_declaration = Error`, tests too). `assert()` prints SCRIPT ERROR in headless GUT: use `Log` + safe returns in game code.
- The capture tool runs in a real window: the browser pane throttles a hidden web build to ~1 fps (4.4/4.5/5.0), so prefer the tool; if you use the pane, keep it on screen.

### Previous story intelligence

- **5.1:** gates recorded verbatim in their own section; checklists as tables with Pass/Fail + note; recorder seams on every screen (`play_sfx`, `play_music`), so instancing a screen in a test or tool never starts audio; 1298 tests at the end. Its open deferrals are audio-only.
- **5.0:** the shared theme (`data/ui_theme.tres`, 30 `StyleBoxTexture`s; variations `Sign`, `SignGrey`, `TagPumpkin`, `TagGreen`, `TagBright`, `Bare`, `FocusRing`, `FocusRingInset`, `PixelButton`, …); `test_art_ui.gd` (finger luma ≥ 0.15 gap, ring widths), `test_no_placeholder_chrome.gd`; Gate 2 already eyeballed "the five tile states distinct in grayscale — pass" and "Coming soon vs Available clearly different — pass": this story makes them tested. 5.0 rendered 640×360 shots "in a real Godot window" (`gate2-run-hud-capital-grayscale.png`) and browser-pane shots at 800 × 450 — the AC wants 640×360, so use the tool. Its review deferred the in-run `StyleBoxFlat`s to 5.2 (Smuck's choice) and accepted the Coming soon `Tint` alpha overlay for the MVP.
- **4.4:** tile-state shapes were designed for this check (sketch `crypt-closet-4-4.md` "Tile states … each with its own shape for Story 5.2's grayscale check"); approved deviations: long words live on the info sign, Wearing is a drawn check (Press Start 2P has no U+2713), tiles 68 px.
- **2.6:** finger contrast is by design (resting `#6CC24A` vs bright `#B8F27C` + candy outline on the lit finger only); its early grayscale look passed.
- **1.3:** Press Start 2P was chosen for the slashed zero and distinct `l`/`I`/`1`; 16/24/32/64 are clean multiples of its 8 px grid.
- **Traps:** the real save (hash before/after); LF line endings; Godot-written UIDs only; commit `.import`/`.uid` files Godot generates; don't edit `build/`.

### Git intelligence

- One commit per story (code, data, assets + `.import`, tests, story, sprint status). Recent: `2f3fb43 Story 5.1: MVP audio pass and mix …`, `4d3fb6f Story 5.0: MVP UI art pass …`. Screenshots are committed under `_bmad-output/implementation-artifacts/screenshots/<story>/`.

### Project Structure Notes

- New: `tools/capture_screens.gd` (+ `.uid`; `tools/` is export-excluded), `tests/unit/test_readability.gd`, `tests/unit/test_plain_words.gd`, `tests/unit/test_grayscale_states.gd` (or local extensions), `_bmad-output/implementation-artifacts/screenshots/5-2/`.
- Modified: the four zombie_run scenes, `export_presets.cfg`, `tests/unit/test_no_placeholder_chrome.gd`, `test_export_presets.gd`, possibly `scenes/run/hud.tscn` + `test_hud.gd` (pause hit area), copy files per Gate A, `docs/art-style-sheet.md`, `deferred-work.md`, maybe `EXPERIENCE.md` (copy changes only).
- No new autoloads, no Router/save/economy change, no new art files (unless Gate B asks).

### Project Context Rules

- No `project-context.md`. Binding rules from `_bmad-output/game-architecture.md` and the spines:
  - Typed GDScript; `%UniqueName`; seams as `Callable`s set before `add_child`; no global EventBus; only `SaveService` touches files (the capture tool writes screenshots only, never the save).
  - UI look lives in `data/ui_theme.tres` variations (9-slice `StyleBoxTexture`, stepped corners); never `StyleBoxFlat` / corner radius (DESIGN Do's and Don'ts; 5.0 guard).
  - Palette only; candy-yellow = focus/"look here"; stamp-red only on the stamp and the toggle slash; **no red for errors** — this game has no error colours (DESIGN Colors, EXPERIENCE Voice "Silence on a wrong key").
  - 16 px text floor; shrink nothing to fit — enlarge the panel or cut words (DESIGN Don'ts).
  - Sentence case everywhere; no all-caps labels except inside hand-lettered sign art (DESIGN Typography).
  - `WebPlatform` is the only GDScript using `JavaScriptBridge`; the web shell is styled only through the export preset's head include.
  - NFR16: nothing a kid sees is technical; failures recover silently.
- Tools: Godot `/c/Program Files/Godot/Godot.exe` (4.7.2), GUT 9.7.1, the Godot MCP server, the built-in browser pane (`web-debug`, port 8060). No downloads or installs needed; ask Smuck first if that changes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.2: Readability, Color and Plain-Words Check] (ACs); Epic 5 goal (verifies NFR7–NFR9); NFR7–NFR11, NFR16; FR2, FR7, FR14, FR19, FR26, FR27, FR30
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Reading level (l.44), Readability (l.240); decision-log U2 (l.40)
- [Source: …/ux-designs/…/DESIGN.md] Colors + contrast table + grayscale review (l.336–393), Typography (l.395–415), Do's and Don'ts (l.526–540)
- [Source: …/ux-designs/…/EXPERIENCE.md] Voice and Tone copy table (l.51–79), State Patterns (l.112–141), HUD readability (l.161), Accessibility Floor (l.203–215)
- [Source: …/ux-designs/…/sketches/crypt-closet-4-4.md] Tile states (l.130), `hud-band-2-5.md` (pause button rect)
- [Source: _bmad-output/implementation-artifacts/5-0-mvp-ui-art-pass.md] Review Findings (in-run StyleBoxFlat → 5.2, Tint accepted), Debug Log (grayscale guard luma, 10.5 checklist), `5-1-mvp-audio-pass-and-mix.md` (gate/checklist pattern), `4-4-crypt-closet.md`, `2-6-green-zombie-hands-finger-guide.md`, `1-3-screen-router-and-title-screen.md` (font)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 4.4 tile-state reminder, 5.0 Tint and in-run StyleBoxFlat items, 5.0 review HUD grayscale item
- [Source: scripts/run/hud.gd, scripts/ui/closet_item_tile.gd, scripts/ui/level_card.gd, scripts/ui/menu_toggle.gd, scripts/screens/*.gd, scripts/levels/zombie_run/zombie_run_target.gd, scenes/levels/zombie_run/*.tscn, data/ui_theme.tres, export_presets.cfg, tests/unit/test_no_placeholder_chrome.gd, test_art_ui.gd, test_main_menu.gd, tests/integration/test_screen_flow.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), Claude Code desktop, gds-dev-story.

### Debug Log References

- Baseline at `2f3fb43`: 71 scripts, **1299/1299** passing (one GUT `wait_frames` deprecation notice, pre-existing). Real `save.json` sha256 `c34c7559b3761b07…` before and after every full run, every capture run and the mutation pass.
- First readability walk (before any fix): only finding `Hud/PauseButton click target height 24 < 32`; every Label/Button ≥ 16 px. Setting `size` on full-rect HUD / pause panel in the new test raised "non-equal opposite anchors" engine errors: dropped (they lay out full-rect anyway).
- Web shell (4.7.2 `web_nothreads_release.zip → godot.html`): `displayFailureNotice()` → `setStatusNotice()` fills `#status-notice` with text nodes + `<br>`, so `font-size: 0; line-height: 0` hides them and `::after` draws the plain words. Verified in the browser pane on a scratch page (the real shell + the head include, `Engine.getMissingFeatures()` stubbed to report WebGL2): `::after` content = the Gate A sentence, 18.75 px, parchment `rgb(246,231,193)` / ink `rgb(30,20,40)`; engine text still in the DOM. The temporary `scratch-notice` launch config was reverted.
- Pause hit area: a `StyleBoxTexture` with negative expand margins is accepted by Godot 4.7.2 (probe: expand −4 → draw rect (4,4)-(28,28) in a 32 box), so the art is unchanged and no new PNG was needed.
- Capture tool: a `-s` SceneTree script is compiled before the autoloads are registered, so preloading the screens failed ("Identifier not found: Router/AudioManager/PlayerData"). Split into a launcher (`capture_screens.gd`, also `--convert`) and a runtime-loaded runner Node (`capture_screens_runner.gd`); the launcher quits with 1 if the runner can't load (an early version hung the window). `ZombieHands` has no `class_name`: typed through a script preload. Temp saves are cleared between shots so values are deterministic.
- Grayscale review found **one fail**: Closet tile focus. The inset ring (`FocusRingInset`) replaced the ink edge next to the parchment: sampled luma 208 (ring) vs 231 (parchment) vs 23/34 (ink / night) — the focused tile only looked 1 px larger. Fix: `FocusRing` (2 px outside the ink edge, the level card's look; fits the 4 px grid gap). Approved at Gate B.
- Conga badge: `TagPumpkin` has no content margins, so a `StyleBoxTexture` falls back to its 4 px texture margins and "×13" would shift 2 px (badge pinned by left + bottom). Added `BadgePumpkin` (same texture, PanelContainer, content 3 px → 1 px shift). Approved at Gate B.
- Mutation pass (12, all caught): 14 px title label → readability; Yes button 24 px tall → readability; "Brainsss" on the Closet Menu button, "Error: null" storage notice, "Horde Rush easy", "Click or press a key" → plain words; `StyleBoxFlat` in `villager.tscn` → no-placeholder-chrome (+ the scene failed to load); red font colour during the shake → grayscale states; CANT_AFFORD given the Buy tag box → grayscale states; head include without the `::after` line → export presets; tile ring back to `FocusRingInset` → grayscale states + tile test; pause rect back to 24 → readability. No survivors.
- Story-file slip: while filling the audit tables, a section replace matched the backticked mention of `## Readability Audit` inside AC 1 instead of the heading and cut AC 1's tail, AC 2-6 and the Tasks list. Restored word for word from the original story text read at the start of the session (boxes ticked); headings are now matched line-anchored.
- `test_brain_block.gd` working copy was CRLF (autocrlf); the appended test made it mixed: normalised to LF (`.gitattributes eol=lf`).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- **Gate A (2026-10-06):** pause hit area grows to 32 × 32 (art unchanged); "32 px" = font size; storage notice → "This browser might forget your brains"; web notice → "This game needs a newer browser. Try Chrome, Edge or Firefox on a computer."; WPM, Resume, report card stat names and "Esc" kept. EXPERIENCE.md Voice and Tone updated (storage row + new web row); `hud-band-2-5.md` pause row updated.
- **AC 1 (sizes):** new `test_readability.gd` instances every MVP screen (title, menu + storage notice, report card with every row + stamp, gift, Closet, HUD in LETTER mode with Caps hint, pause panel open, countdown, confirm prompt) plus level card, tile, toggle, brain counter and the in-run target / villager / brain block / conga badge, and enforces text ≥ 16, HUD target ≥ 32 (PARAGRAPH ≥ 24), every visible clickable ≥ 32 tall (no allow-list), and fit checks for the pause panel, countdown and the confirm question of every live item. Pause button fixed (R3); everything else passed.
- **AC 2 (grayscale):** `tools/capture_screens.gd` (+ runner) renders 34 shots at 640×360 in a real window (colour + Rec. 709 gray, 3× crops of the hands, the sign, the toggles, the in-run tags and the badge) into `screenshots/5-2/`; Gate B sheets `gate-b-1..4`, the tile-focus before/after (26) and the web notice (30). Checklist G1–G16 filled; one fail (G5 Closet tile focus) fixed. New `test_grayscale_states.gd`: five tile states differ by shape/content, every focusable kind's focus is the candy ring drawn outside its edge, the wrong-key shake changes position only (colour, modulate, sign style, size unchanged every step).
- **AC 3 (plain words):** new `test_plain_words.gd` collects every MVP scene's static `text`, the script copy, the live screens' formatted strings (every live confirm question, report card, gift, ×13 badge), catalogue names and non-debug level names; asserts each is approved copy and bans slang, technical text, rank words and all-caps words (WPM allowed). Web failure notice replaced via the head include (CSS only, no custom shell); `test_export_presets.gd` covers it. No `OS.alert`, no log text in labels.
- **AC 4 (no ranks, no pressure):** audit rows R7/R8 pass; the copy test bans the rank words.
- **AC 5 (in-run chrome):** villager / brain block / base target tags and the base box use `Sign`; a resolved base target switches its box to `SignGrey` (the old `StyleBoxFlat` cast silently did nothing on a texture); the conga badge uses `BadgePumpkin`. Letter size, colour, centring, node names, offsets and mouse filters unchanged. `test_no_placeholder_chrome.gd` walks `scenes/levels/zombie_run/`.
- **AC 6:** Gate A and Gate B recorded verbatim with the date in `## Review Approval`. Full suite twice: **1319/1319** (74 scripts; +20 tests over the 1299 baseline), real save unchanged.
- Deferred-work: struck the 4.4 tile-state reminder, the 5.0 review's HUD-grayscale and in-run `StyleBoxFlat` items; Tint marked "5.2 grayscale: pass"; new "Deferred from: dev of story 5-2" section (32 px ink follow-up if playtests need it, FR27 wording in epics/architecture, the notice not forced in a real export, title-case labels, post-MVP copy must join the approved list, the Windows driver dialog).
- `docs/art-style-sheet.md` section 8 "Readability and grayscale (Story 5.2)" (floors, what 32 px means, the luma table, the outside-ring rule, the capture command); `BadgePumpkin` added to the section 7 variation list. `FocusRingInset` stays in the theme (no longer used by a scene).

### File List

- `_bmad-output/implementation-artifacts/5-2-readability-color-and-plain-words-check.md` (this story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/screenshots/5-2/` (new: 34 shots × colour + `-gray`, `gate-b-1..4` sheets, `26-closet-tile-focus-before-after-3x.png`, `30-web-failure-notice.jpg`)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md`
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/hud-band-2-5.md`
- `data/ui_theme.tres`
- `docs/art-style-sheet.md`
- `export_presets.cfg`
- `scenes/levels/zombie_run/brain_block.tscn`
- `scenes/levels/zombie_run/conga_line.tscn`
- `scenes/levels/zombie_run/villager.tscn`
- `scenes/levels/zombie_run/zombie_run_target.tscn`
- `scenes/run/hud.tscn`
- `scenes/screens/main_menu.tscn`
- `scenes/ui/closet_item_tile.tscn`
- `scripts/levels/zombie_run/zombie_run_target.gd`
- `scripts/screens/main_menu.gd`
- `scripts/ui/closet_item_tile.gd`
- `tests/unit/test_brain_block.gd`
- `tests/unit/test_closet_item_tile.gd`
- `tests/unit/test_conga_line.gd`
- `tests/unit/test_export_presets.gd`
- `tests/unit/test_grayscale_states.gd` (+ `.uid`, new)
- `tests/unit/test_hud.gd`
- `tests/unit/test_main_menu.gd`
- `tests/unit/test_no_placeholder_chrome.gd`
- `tests/unit/test_plain_words.gd` (+ `.uid`, new)
- `tests/unit/test_readability.gd` (+ `.uid`, new)
- `tests/unit/test_villager.gd`
- `tests/unit/test_zombie_run_target.gd`
- `tools/capture_screens.gd` (+ `.uid`, new)
- `tools/capture_screens_runner.gd` (+ `.uid`, new)

## Change Log

- 2026-10-06: Story 5.2 implemented. Readability floors tested across every MVP screen (pause button hit area 24 → 32 px, art unchanged); plain-words copy guard and the Gate A copy changes (storage notice; plain web failure notice through the head include); grayscale capture tool + review (Closet tile focus ring moved outside the ink edge); in-run Zombie Run tags, base box and conga badge moved from `StyleBoxFlat` to theme 9-slices (`Sign` / `SignGrey` / new `BadgePumpkin`). Spec edits: EXPERIENCE.md Voice and Tone (storage notice row, new web notice row), `hud-band-2-5.md` pause row. Gates A and B approved by Smuck. Suite 1299 → 1319, all passing. Status → review.
- 2026-10-06: Deviation from Task 6.2: the conga badge uses a new `BadgePumpkin` variation (same texture as `TagPumpkin`, content margin 3) instead of `TagPumpkin` itself, so the "×N" fits the 16 px floor without growing the tag; approved at Gate B. Code review patches: copy walk keyed by node path, click-floor test now covers Closet tiles and level cards, null-load guard, word-boundary red ban.
