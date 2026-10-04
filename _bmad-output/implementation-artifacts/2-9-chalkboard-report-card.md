---
baseline_commit: 986b9d334f132b01a575a50add08c62e13c3f0a5
---

# Story 2.9: Chalkboard Report Card

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want a fun report card after every run showing how I did,
so that I feel proud and want to play again.

## Acceptance Criteria

1. **Matches the mock and the spines.** Given the Report Card mock (`ux-designs/ux-zombies-teach-typing-2026-09-27/mockups/key-report-card.html`) and `DESIGN.md` (chalkboard, Professor Zombie, "New best!" stamp, buttons, key hints, report-card backdrop), when the screen is built, then it follows their layout: the level name as the board heading, a night-classroom backdrop (parchment-shade wall, window onto the night, wood floor), the chalkboard on the left, Professor Zombie on the right pointing at it, Play Again and Menu side by side on the floor with "Enter" / "Esc" key hints, and every text at 16 px or more. No separate sketch is needed; the mock is the approved layout. Only the font-forced size changes listed in Dev Notes → "Layout" are allowed, and they are recorded in the Completion Notes.
2. **Stats.** Given a `REPORT_CARD` payload `{"result": RunResult, "new_best": bool}`, when the screen opens, then the chalkboard shows Keys Typed, Errors, WPM, Accuracy (`N%`), Lesson Time (`m:ss`) and Brains Collected (`result.total_brains()`), labels in chalk-dim and values in chalk, and, only when `result.bonus_brains > 0`, a separate candy-yellow "+N bonus" line under Brains Collected (FR19, FR7).
3. **Professor Zombie.** The player zombie in a cap and gown, in a pointing pose (2-frame animation at 8 fps), stands on the floor at 1× sprite scale and points at the board. The scene has an empty `HatSlot` node at the head point (the mortarboard sits there now and stacks on top of the worn hat in Story 4.3) and an empty `PetSlot` node beside him; their behaviour is added in Story 4.3 (FR19, FR43, D16).
4. **New best.** Given `new_best == true`, a "New best!" stamp shows on the board's top-right corner. Given `false` or a missing key (including the first run of a level), no stamp shows (FR20).
5. **Mash guard.** Given the report card has just opened, when Enter, Esc, Space or a mouse click arrives within the first 1.0 s of the screen being live, then nothing happens. After 1.0 s, Enter (or the Play Again button) restarts the same level, `Router.go(RUN, {"level_id": result.level_id})`, and Esc (or the Menu button) goes to the main menu (FR21). Only one navigation ever happens per report card.
6. **Keyboard and mouse.** Play Again has focus when the screen opens; Left/Right arrows move focus between the two buttons; Enter activates the focused button; Esc always means Menu; both buttons work by mouse click. Held-key repeats (`echo`) never activate anything (FR25, EXPERIENCE.md Interaction Primitives).
7. **Plain words.** Every text on the card uses the exact words in EXPERIENCE.md Voice and Tone ("Keys Typed", "Errors", "WPM", "Accuracy", "Lesson Time", "Brains Collected", "+N bonus", "New best!", "Play Again", "Menu", "Enter", "Esc", and the level name), at 16 px or more (NFR7, NFR9).
8. **Robust.** A payload without a `RunResult` (e.g. the screen-flow test) logs a warning, shows the board with 0 values and the fallback heading, and never crashes. A missing Professor sprite or level-name entry never stops the screen (NFR16).
9. **Tests.** `tests/unit/test_report_card.gd` (replacing `test_report_card_placeholder.gd`) covers: every stat value and its formatting, the bonus line shown/hidden, the stamp shown/hidden (true, false, missing), the heading from the level registry plus its fallback, the 1.0 s guard for Enter, Esc and click (blocked at 0.99 s, works at 1.0 s), Play Again's payload, Menu's navigation, one navigation only, echo ignored, initial focus. `test_art_sprites.gd` covers the two new Professor sheets. The full GUT suite passes.

## Tasks / Subtasks

- [x] **Task 1: Level display name (AC: 1, 8)**
  - [x] 1.1 `scripts/resources/level_entry.gd`: add `@export var display_name: String = ""` (`##` doc: "The level's name as kids read it, e.g. "Zombie Run". Shown as the report card heading."). Update the header comment ("Card art, availability and unlock rules arrive with Stories 4.2 / 6.8" stays).
  - [x] 1.2 `data/levels/level_registry.tres`: set `display_name = "Test level"` on the `test_level` entry. (Story 3.1 adds `zombie_run` with `display_name = "Zombie Run"`; add a line to its Dev Notes hand-off in `deferred-work.md`.)
  - [x] 1.3 Heading rule (in `report_card.gd`): registry entry's `display_name` if non-empty, else `String(level_id).capitalize()` (`zombie_run` → "Zombie Run"), else (empty id) "Report Card". Never shown as an error.

- [x] **Task 2: Professor Zombie art (AC: 3)**
  - [x] 2.1 Extend `tools/gen_art_prototypes.gd` (one art tool, same ASCII-map method, same palette, same `_sheet_image` / `_save` helpers): add `PROFESSOR_DIR = "res://assets/sprites/characters/professor"` and write
    - `professor_point.png`: 2 frames × 32×32. The player zombie (same head, face and greens as `ZOMBIE_LEGEND`, flat ~12 px crown kept free for the hat) in a gown (`night` body, `ink` outline, optional `dusk` folds), facing **left**, one arm raised holding a pointer stick (`wood-light` with `ink` outline) that reaches the frame's left margin. Frame 2 moves the pointer tip 1 px (a "tap"); the soles stay on row 30 in both frames.
    - `professor_mortarboard.png`: 1 frame × 32×32: a flat mortarboard (`ink` board, `night` cap) sitting at the top of the frame so that, drawn at the same origin as the body, it rests on the zombie's crown. An optional tassel is `bat-purple` (decoration); **never** `candy-yellow` (focus only) or `stamp-red`.
  - [x] 2.2 Run the tool headless, then `--import` (header of the tool has the exact command). Commit PNG + `.import` files. Lossless, no mipmaps, no per-file filter (project default Nearest).
  - [x] 2.3 `tests/unit/test_art_sprites.gd` (read it first; three traps):
    - Add `professor_point.png: 2` to `SHEETS`. **Do not** put the mortarboard in `SHEETS`: `test_sheets_exist_with_frame_size_and_count` asserts 2–6 frames for every sheet. Add a separate `const OVERLAYS: Array[String] = ["res://assets/sprites/characters/professor/professor_mortarboard.png"]` (32×32, one frame, not an animation) and run the size, hard-alpha/palette, outline and import-settings checks over it too (extend those tests or add overlay twins; keep the existing `assert_eq(sheets.size(), SHEETS.size())` guards meaningful).
    - `test_right_color_ramps_used` treats every non-`/zombie/` path as a villager (expects `art-skin-light`). Change the condition so `/professor/` sheets are checked like the zombie (ink, zombie-green, zombie-green-dark); the mortarboard overlay is checked for ink only.
    - If the outline rule fights the pointer stick, fix the map, not the test.
    - Frame counts and fps for existing prototypes are also asserted in `test_art_review.gd` / `scripts/debug/art_review.gd`; adding the professor to the art review scene is optional (if you do, 8 fps and update that test).
  - [x] 2.4 `docs/art-style-sheet.md` § 3 "Current prototypes": add `professor point 2 frames at 8 fps` and the mortarboard overlay.

- [x] **Task 3: Professor Zombie scene (AC: 3)**
  - [x] 3.1 `scenes/characters/professor_zombie.tscn` + `scripts/characters/professor_zombie.gd` (architecture paths). Root `Node2D` "ProfessorZombie":
    - `Body` (`AnimatedSprite2D`, `SpriteFrames` sub-resource with animation `point`, 2 `AtlasTexture` frames from `professor_point.png`, 8 fps, loop, autoplay `point`, `centered = false`).
    - `Body/HatSlot` (`Node2D`, `unique_name_in_owner`), placed at the head point (top-centre of the crown). Empty: Story 4.3 adds the hat and the `SpriteAnchors` follow.
    - `Body/Mortarboard` (`Sprite2D`, `centered = false`, texture `professor_mortarboard.png`) at the body origin, drawn after `HatSlot` so it is on top (D16: the mortarboard stacks on top of the worn hat; Story 4.3 lifts it by the hat's height).
    - `PetSlot` (`Node2D`, `unique_name_in_owner`) on the floor to the professor's right. Empty until Story 4.3.
  - [x] 3.2 `professor_zombie.gd` stays tiny: `## ` header (what the slots are for and that 4.3 fills them), no autoload use, no `PlayerData`. `_ready()` logs a warning (`Log.warn(&"ui", ...)`) and hides `Body` if its `sprite_frames` is null (NFR16: never stop the screen).
  - [x] 3.3 1× scale only. Do **not** scale the professor up (art-style sheet § 3 "Scaling": one sprite scale on every screen; DESIGN.md/D16: mock pixel scale is for legibility only).

- [x] **Task 4: Report card scene (AC: 1–4, 7)**
  - [x] 4.1 Rebuild `scenes/screens/report_card.tscn` (root `Control` "ReportCard", full rect, keep the existing script uid `uid://blk6yqcckri1j`). Layout in Dev Notes → "Layout". Placeholder chrome = `StyleBoxFlat` in palette colours, square corners (no `corner_radius`: DESIGN.md forbids anti-aliased radii; stepped 9-slice textures arrive in Story 5.0), exactly like the HUD and pause panel.
  - [x] 4.2 Unique nodes the script and tests use: `%Heading`, `%KeysValue`, `%ErrorsValue`, `%WpmValue`, `%AccuracyValue`, `%TimeValue`, `%BrainsValue`, `%BonusLabel`, `%Stamp`, `%Professor` (instance of `professor_zombie.tscn`), `%PlayAgainButton`, `%MenuButton`, `%EnterHint`, `%EscHint`. One row container per stat (`%Row0` … `%Row6`, row 6 = bonus) so the write-on reveal can show rows one by one. Keep `PlayAgainButton` / `MenuButton` names: `tests/integration/test_screen_flow.gd` looks them up.
  - [x] 4.3 Buttons: `focus_mode = FOCUS_ALL`, `focus_neighbor_left/right` pointing at each other (top/bottom to themselves), pixel-button placeholder look (Dev Notes → "Placeholder chrome"). Key hints, backdrop, board, professor and stamp: `mouse_filter = IGNORE`, never focusable.
  - [x] 4.4 `@export var level_registry: LevelRegistry` on the script, set in the scene to `res://data/levels/level_registry.tres` (same pattern as `run_frame.tscn`).

- [x] **Task 5: Report card script (AC: 2, 4–8)** — rewrite `scripts/screens/report_card.gd`
  - [x] 5.1 `_ready()`: `var payload := Router.take_payload()` (exactly once). `result` is `payload.get("result")` if it `is RunResult`, else `null` → `Log.warn(&"ui", "report card opened without a RunResult")`, show 0 / "0%" / "0:00", hide bonus and stamp, heading from `FALLBACK_LEVEL_ID`. `new_best` = `payload.get("new_best", false)` only if it is a `bool`, else `false`. Fill the board (Task 5.2), hide all rows and the stamp for the reveal, connect buttons in code, `%PlayAgainButton.grab_focus()`.
  - [x] 5.2 Values: `str(result.keys_typed)`, `str(result.errors)`, `str(result.wpm)`, `"%d%%" % result.accuracy`, `result.lesson_time()`, `str(result.total_brains())`; bonus line `"+%d bonus" % result.bonus_brains`, visible only when `bonus_brains > 0`. Do not recompute any stat: `RunResult` / `StatsCalculator` own the formulas (Story 2.3).
  - [x] 5.3 Guard and reveal in `_process(delta)` with one accumulator `_open_s` (it only runs while the tree is unpaused, so the Router's fade-in does not eat the guard; see Dev Notes → "Guard timing"). Guard: `_open_s >= GameConstants.REPORT_CARD_INPUT_GUARD_S`. Reveal: row `i` becomes visible at `_open_s >= i * REVEAL_STEP_S` (`REVEAL_STEP_S = 0.1`, a local UX-assumption const like `hud.gd`'s `SHAKE_PX`), the stamp (when `new_best`) after the last shown row. The reveal never blocks input after the guard: choosing early is fine. Stop doing work in `_process` once everything is shown and the guard has passed (`set_process(false)`).
  - [x] 5.4 Input. `_input(event)`: if the event is an `InputEventKey` with `echo`, or (`_open_s` < guard or `_leaving`) and the event is a key press or a mouse-button press → `get_viewport().set_input_as_handled()` and return. `_input` runs before GUI, so this also stops a focused button from taking Enter/Space and stops clicks (Dev Notes → "Input order"). `_unhandled_input(event)`: `ui_cancel` → `_leave_to_menu()`; `ui_accept` with no button focused → `_play_again()` (so Enter still means Play Again if focus was lost). Buttons: `pressed` → `_play_again()` / `_leave_to_menu()`.
  - [x] 5.5 One exit: `_play_again()` and `_leave_to_menu()` both go through `_leave(screen, payload)`, which returns at once if `_leaving` or the guard is still on, sets `_leaving = true`, and calls `navigate.call(screen, payload)`. Play Again payload: `{"level_id": _level_id}` (no seed: a replay gets a fresh RNG, Story 3.5's "fresh letter bag"). Menu: `Router.Screen.MAIN_MENU`, `{}`. Story 4.5 will redirect the first completed run through the Welcome Gift here: keep this the only place that navigates and say so in the header.
  - [x] 5.6 Test seam, same as `RunFrame`: `var navigate: Callable`; if not valid in `_ready()`, `navigate = Router.go`. Tests assign a recorder before `add_child`.
  - [x] 5.7 `## ` header: what the screen shows, the payload contract (`result`, `new_best`), the guard, the one-exit rule, "placeholder chrome until Story 5.0; sounds (chalk-scratch per row, chime, stamp thump) are Story 5.1; hat/pet in the slots are Story 4.3". Static types everywhere.
  - [x] 5.8 `scripts/core/game_constants.gd`: add `## FR21: Enter / Esc / clicks on the report card do nothing for this many seconds after it opens.` `const REPORT_CARD_INPUT_GUARD_S: float = 1.0`.

- [x] **Task 6: Tests (AC: 9)**
  - [x] 6.1 `git mv tests/unit/test_report_card_placeholder.gd tests/unit/test_report_card.gd` and `git mv` its `.gd.uid` alongside (it exists), then rewrite it. Pattern: `Router._store_payload(payload)` → instantiate → assign `navigate` recorder → `add_child_autofree`; `after_each` drains `Router.take_payload()`. Drive time with `card._process(delta)` and input with `card._input(event)` / `card._unhandled_input(event)` on synthetic events (`InputEventKey` with `keycode`, `pressed`, `echo`; `InputEventAction` for `ui_accept` / `ui_cancel` where simpler; `InputEventMouseButton`). Keep the `after_each` input-handled reset pattern from `test_run_frame.gd` if you call input handlers by hand.
  - [x] 6.2 Cases: mock example numbers (142 keys, 9 errors, 120 s, 35 brains + 10 bonus → "142", "9", "14", "94%", "2:00", "45", "+10 bonus"); bonus 0 hides the bonus line; `new_best` true / false / missing / non-bool; heading from the registry (`test_level` → "Test level"), capitalize fallback for an unregistered id, "Report Card" for no result; payload consumed; no-result path logs a warning (`assert_push_warning("...")`, as `test_audio_manager.gd` does) and shows zeros; Play Again focused on open; Enter at 0.99 s → no navigation, at 1.0 s → `[RUN, {"level_id": ...}]`; Esc same with `MAIN_MENU`; click during the guard handled and ignored; echo Enter after the guard ignored; a second choice after the first → still one navigation; button `pressed` before the guard → nothing; reveal: rows hidden at 0, all shown by `7 * REVEAL_STEP_S`, stamp last; every `Label` in the scene has an effective font size ≥ 16.
  - [x] 6.3 `tests/integration/test_screen_flow.gd` must stay green (it instantiates the card with an empty payload, disabled). Expect the new warning there if the test asserts on log output.
  - [x] 6.4 Red first, then green. Mutation checks, one at a time with a byte-for-byte restore: guard `>=` → `>`, guard removed from `_input`, echo check removed, `_leaving` check removed, bonus shown when 0, stamp shown when `new_best` missing, Play Again sends `MAIN_MENU`. Record each result honestly in the Debug Log (killed / survived).
  - [x] 6.5 Full GUT suite (baseline after 2.8: **505** passing). No `Parse Error`, `SCRIPT ERROR` or unexpected GUT warning.

- [ ] **Task 7: Manual check in the browser (PARTIAL after review: screenshots were rendered, not captured from a played run that earned the stamp; the 1.0 s mash window and a mouse click were not checked by hand) (AC: 1, 3, 4, 5)**
  - [ ] 7.1 (partial, see Task 7) Debug web build (or desktop run): main menu → Test level → type until the 2:00 clock ends (F6 "end run" only arrives in Story 2.10; do not shorten `test_level.tres` for this) → report card. Screenshot at 1280×720 into `_bmad-output/implementation-artifacts/screenshots/2-9/`: (a) first run (no stamp), (b) a second, faster run (stamp). Check by eye: layout vs the mock, Professor's pointer reaches the board, nothing below 16 px, Enter mash in the first second does nothing, Enter after it replays the level, Esc goes to the menu, arrows move focus, click works.
  - [x] 7.2 Smuck looks at the Professor Zombie sprite (new character art after the 1.9 gate) and the screenshots; record "OK" or the requested changes in the Completion Notes.

- [x] **Task 8: Housekeeping**
  - [x] 8.1 `deferred-work.md`: add "Deferred from: dev of story-2-9" with anything left open (at least: final chalkboard/stamp/button art → 5.0; chalk-scratch, chime, stamp-thump, menu music on the card → 5.1; hat and pet in the slots → 4.3; Welcome Gift redirect → 4.5; `zombie_run` `display_name` → 3.1; long headings vs the stamp → Epic 8).
  - [x] 8.2 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`.

### Review Findings

- [x] [Review][Patch] No-result card still shows the "New best!" stamp: force `_new_best = false` when `result == null` (Task 5.1 says hide bonus and stamp) and flip the assertion in `test_no_result_warns_and_shows_zeros` [scripts/screens/report_card.gd:52]
- [x] [Review][Patch] Empty `level_id` replays an empty level: guard added so `&""` keeps `FALLBACK_LEVEL_ID` (no test: `RunResult.create` asserts on an empty id, so it is unreachable in practice) [scripts/screens/report_card.gd:56]
- [x] [Review][Patch] Click guard test proves nothing about a real click: `test_click_handled_during_guard_only` only checks `is_input_handled()`, and `test_echo_enter_ignored_after_guard` is partly vacuous; add a click-after-1.0 s navigation check (AC 9) and make the echo assertion real [tests/unit/test_report_card.gd]
- [x] [Review][Patch] Story record is inconsistent: Debug Log says 32 tests, Change Log says 33, the diff has 34 `test_` functions in `test_report_card.gd`; and Task 7 / 7.1 are ticked although the played-run screenshots, 1.0 s mash window and mouse click were not checked by hand [2-9-chalkboard-report-card.md: Task 7, Debug Log, Change Log]
- [x] [Review][Defer] Soft-lock if navigation does nothing: `_leave()` sets `_leaving` before `navigate`, so if the Router ignores or fails the call the card stays dead — deferred, Router already falls back to the menu; only a missing menu scene triggers it
- [x] [Review][Defer] No hover cue on the unfocused button (hover box equals normal) [scenes/screens/report_card.tscn] — deferred, placeholder chrome until Story 5.0
- [x] [Review][Defer] Brittle tests: hard-coded `checked == 19` label count and 0.99 + 0.01 float guard boundary [tests/unit/test_report_card.gd] — deferred, low value

## Dev Notes

### What this story is (and isn't)

- It replaces the 1.3/2.4 placeholder report card with the real screen: chalkboard stats, Professor Zombie, the "New best!" stamp, Play Again / Menu with the 1.0 s mash guard.
- **New files:** `scenes/characters/professor_zombie.tscn`, `scripts/characters/professor_zombie.gd`, `assets/sprites/characters/professor/professor_point.png` (+ `.import`), `assets/sprites/characters/professor/professor_mortarboard.png` (+ `.import`), `tests/unit/test_report_card.gd` (moved from the placeholder test).
- **Updated files:** `scenes/screens/report_card.tscn`, `scripts/screens/report_card.gd`, `scripts/resources/level_entry.gd`, `data/levels/level_registry.tres`, `scripts/core/game_constants.gd`, `tools/gen_art_prototypes.gd`, `tests/unit/test_art_sprites.gd`, `docs/art-style-sheet.md`, `deferred-work.md`, `sprint-status.yaml`.
- **Don't build:** the hat or pet in the slots, `SpriteAnchors`, `HatSlot`/`PetSlot` scripts (Story 4.3); the Welcome Gift redirect (4.5); sounds or music on this screen (5.1: no `AudioCue`s exist for chalk-scratch/chime yet, and `AudioManager.play_sfx` with an unknown id logs a warning, so don't call it); final art for board, stamp, buttons (5.0); a `pixel_button.tscn` widget (not needed yet); any change to `RunFrame`, `RunResult`, `PlayerData` or the `Router`.

### Existing code: current state, what changes, what must be preserved

- **`scripts/screens/report_card.gd`** (placeholder): reads the payload once, shows the stats as one text label, `FALLBACK_LEVEL_ID = &"zombie_run"`, Play Again → `Router.go(RUN, {"level_id": _level_id})`, Menu → `MAIN_MENU`, focuses Menu, no guard. **Changes:** everything visible, focus goes to Play Again, guard, one exit, `navigate` seam. **Keep:** reading the payload exactly once in `_ready()`, `FALLBACK_LEVEL_ID` for a missing result (zombie_run is not registered until 3.1, so Play Again from a resultless card lands on RunFrame's failed-load path → main menu; that's the intended NFR16 path).
- **`scripts/run/run_frame.gd`** sends `Router.go(REPORT_CARD, {"result": _result, "new_best": _new_best})` from `DONE` (via `_navigate_when_idle`). The run is already recorded on entering `ENDING` (2.8 review). **No change.** The report card never writes `PlayerData`.
- **`scripts/typing/run_result.gd`**: `keys_typed`, `errors`, `wpm`, `accuracy`, `brains`, `bonus_brains`, `level_id`, `total_brains()`, `lesson_time()`. Brains Collected = `total_brains()` (the mock's 45 = 35 + 10 bonus, and the bonus is also listed on its own line). **No change.**
- **`scripts/autoloads/router.gd`**: `go()` pauses the tree, fades out 0.15 s, swaps the scene (new `_ready()` runs while paused), fades in 0.15 s, then unpauses. Paused screens get no input and no `_process`. `go()` during a transition is ignored. **No change.**
- **`tests/integration/test_screen_flow.gd`** instantiates every screen disabled with an empty payload and checks `%PlayAgainButton` / `%MenuButton` exist as `Button`s. Keep those names and node types.
- **`data/levels/level_registry.tres`** has one entry (`test_level`, `debug_only`). Adding the `display_name` field keeps old `.tres` files valid (default `""`).

### Payload contract

`{"result": RunResult, "new_best": bool}` (Story 2.8 decision: the flag travels in the payload, not on `RunResult`). Read both defensively: `result` must be a `RunResult`; `new_best` must be a `bool` (anything else → `false`). A first run of a level arrives as `new_best = false` (2.8 rule), so "no stamp on a first run" needs no extra logic here.

### Layout (640×360 logical; screen coordinates unless noted)

Lifted from the mock's section A (exact numbers from its SVG/HTML), with the font-forced button sizes changed because Press Start 2P is 16 px per glyph at 16 px (the mock used a narrow system mono):

| Element | Rect / position | Notes |
|---|---|---|
| Wall | (0,0) 640×296, parchment-shade `#D9BC84` | 1 px wood-light `#C08447` lines at y 24, 48 … 288 (every 24 px) |
| Window | outer (452,14) 172×104 ink → wood `#8A5228` frame (1 px wood-light top bevel) → glass (459,21) 158×90 night `#2B1D3F` | wood mullions: vertical (537,20) 2×92, horizontal (458,65) 160×2; sill (448,116) 180×6 wood-light with ink top/bottom lines |
| Moon / stars | moon ≈ (580,26) 26×24 art-moon `#FFF3B0`; a few 1–2 px chalk stars; optional bat-purple bat | decoration only; smiling moon is 5.0 art |
| Floor | (0,296) 640×64 wood | ink line y 296, wood-light y 297, wood-dark `#5A3218` lines y 316, 338 |
| Chalkboard frame | (16,12) 416×276, wood, ink 1 px outline, wood-light top-left bevel, 2 px ink drop shadow (down-right) | `{rounded.lg}` is placeholder-square |
| Board surface | frame-local (7,7) 400×254 → screen (23,19), chalkboard `#24402F`, ink 1 px border | |
| Heading | board-local (20,10), 24 px, chalk `#F4F1E4` | the level name |
| Rule line | board-local (20,40) 360×1, chalk-dim `#A8C4A6` | |
| Stat rows | labels board-local x 20; values right-aligned in x 230..380; rows at y 48, 72, 96, 120, 144, 168; 16 px | labels chalk-dim, values chalk; "Brains Collected" (256 px wide) ends at x 276, clear of the value column's 3-4 digits |
| Bonus line | value column, y 192, candy-yellow `#FFD23F`, right-aligned | only when bonus > 0 |
| Chalk tray | frame-local (3,262) 408×10 wood-light, ink border; two chalk stubs at frame-local (40,258) 16×4 and (70,259) 10×3, chalk with ink border | |
| "New best!" stamp (placeholder) | (288,20) 160×32: stamp-red `#B02A25` fill, 1 px chalk inner border inset 3 px, "New best!" 16 px chalk, centred | overhangs the frame's top-right corner onto the wall, like a rubber stamp. Final art (5.0) is a hand-lettered sprite pre-rotated −8°; the placeholder is **not** rotated (a rotated Label smears under Nearest). Must not overlap the heading text or any stat row (test it with the label rects) |
| Professor Zombie | 32×32 body, soles on y 300 (4 px into the floor's top band), frame left x ≈ 436 | the pointer stick's tip overlaps the board frame's right edge (x ≤ 432) around y 276–284. Tune by eye; keep 1× |
| Pet slot | ≈ (476, 268), on the floor right of the professor | empty node |
| Play Again | (32,308) 176×32 | 10 glyphs × 16 = 160 + 8 px padding each side |
| "Enter" hint | (216,312) 88×24 | parchment keycap, ink outline, 16 px ink |
| Menu | (328,308) 80×32 | |
| "Esc" hint | (416,312) 56×24 | |

The font-forced widths (Play Again 120 → 176, Enter 56 → 88, Esc 40 → 56, button row shifted left, stamp 142×40 → 160×32 and moved right of the heading) are mechanical consequences of the approved font (Story 1.9 gate kept Press Start 2P), the same kind of change Story 2.5 recorded for the HUD. List them in the Completion Notes.

### Placeholder chrome (until Story 5.0)

- `StyleBoxFlat`, palette colours only, square corners, 1 px ink borders, `shadow_size`/`shadow_offset` only for the hard 2 px ink drop shadow (`shadow_size = 0`, `shadow_offset = Vector2(2, 2)`, `shadow_color = ink`) — no blur.
- **Pixel button** (DESIGN.md Components): normal = wood fill, ink 1 px border, chalk 16 px text; hover = same as normal; **focus** = pumpkin-light `#FFA94A` fill, ink text, plus a 2 px candy-yellow ring outside the ink outline (a `focus` `StyleBoxFlat` with `bg_color` pumpkin-light, `border_width_*` 2 in candy-yellow, `expand_margin_*` 2 drawn over the normal box; set `font_focus_color` ink and `font_hover_pressed_color`/`font_pressed_color` ink); pressed = pumpkin `#F07A1C` fill, ink text. Put these on the two buttons in the scene (no new Theme type yet; 4.2/5.0 decide on a shared widget). Verify in the screenshot that the focus fill shows under the label; if Godot draws the focus box over the text, use a theme type variation on `normal`/`focus` swaps from the script instead (`add_theme_stylebox_override` on `focus_entered`/`focus_exited`).
- Use `Label` text colours via `theme_override_colors/font_color` (as the HUD does).

### Guard timing

- The guard counts **interactive** time: `_open_s += delta` in `_process`, which does not run while `Router.go()` keeps the tree paused for the fade-in. So "the first 1.0 s" is the first second the kid can actually see and press. (Wall-clock from `_ready()` would lose ~0.15 s to the fade.)
- Keys already held when the screen appears: a held Enter arrives only as `echo` events → always ignored (AC 6). A new press after 1.0 s works.
- Router fade note (EXPERIENCE.md State Patterns): input during a fade is already ignored by the paused tree.

### Input order (Godot 4.7)

- Event flow: `_input` → GUI (`_gui_input`, focused `Button` reacts to `ui_accept` = Enter / KP Enter / Space) → `_shortcut_input` → `_unhandled_key_input` → `_unhandled_input`. Calling `get_viewport().set_input_as_handled()` in `_input` stops GUI handling too, which is why the guard lives in `_input` (it must stop the focused button and mouse clicks, not only the unhandled Esc).
- After the guard: Enter is taken by the focused button (Play Again by default; Menu if the kid arrowed to it — EXPERIENCE.md "Enter — select / confirm in menus"); Esc (`ui_cancel`) is never taken by a Button, so it reaches `_unhandled_input` → Menu.
- Arrow focus: `ui_left` / `ui_right` move focus through `focus_neighbor_*`; set them explicitly so focus never leaves the two buttons.
- Mouse: a button click arrives as `pressed`; during the guard the click never reaches the button (handled in `_input`). Also guard inside `_leave()` so a `pressed` emitted any other way (e.g. a test calling `emit`) is still blocked.

### Design decisions in this story (flag to Smuck in the completion summary)

1. **Enter activates the focused button**, which is Play Again on open, so Enter = Play Again by default (FR21); after arrowing to Menu, Enter picks Menu. Esc is always Menu. Alternative (Enter always Play Again, even with Menu focused) was rejected as confusing.
2. **Guard counts from when the screen is live** (after the Router fade-in), not from scene load.
3. **Write-on reveal** (EXPERIENCE.md Game Feel "Report card open"): rows appear top to bottom 0.1 s apart, the stamp last (≈ 0.8 s, inside the guard); sounds come in 5.1.
4. **Professor at 1×** (32×32), per the art-style sheet and D16, so he is much smaller than in the mock. If he reads too small at 1280×720, that's a decision for Smuck (an exception to the one-scale rule, or a 48×48 professor sprite) — not to be made silently.
5. **Font-forced layout changes** (table above).
6. **Level name** comes from a new `LevelEntry.display_name`, with `capitalize()` of the id as fallback.

### Known edges (record in deferred-work.md if you leave them)

- Long level names: "Pitchfork Panic" at 24 px is 360 px and would run under the stamp. Epic 8 (or the 5.0 stamp art) resolves it.
- Report card can celebrate a best that never reached disk (pre-existing, deferred in 2.8).
- `test_level` has no completion bonus, so the bonus line is only seen in tests until Story 3.5.

### Testing approach

- Unit-test the screen directly: no `Router.go` (it would swap GUT's scene); the `navigate` recorder catches navigation.
- Drive `_process` by hand for time; feed synthetic events to `_input` / `_unhandled_input`. When a test calls `_input` on a node outside a real viewport event, `get_viewport().set_input_as_handled()` still works (the HUD/RunFrame tests already do this); reset in `after_each` as `test_run_frame.gd` does.
- Button `pressed`: call `%PlayAgainButton.emit_signal("pressed")` / `.pressed.emit()` to simulate a click that got through; the guard in `_leave()` must still block it before 1.0 s.
- GUT trap (from earlier stories): a preload constant named `Test…` is treated as an inner test class — name preloads `ReportScene`, `ProfessorScene`.
- Every test must be able to fail (mutation list in Task 6.4).

### Coding conventions

- Static typing everywhere (`untyped_declaration = Error`), lambda params included; `##` docs on public members; `%UniqueName` for nodes used from script; handlers `_on_<emitter>_<signal>`; signals connected in code in `_ready()`, never by string.
- Logging: `Log.warn(&"ui", ...)` for a missing result or sprite; nothing in `_process`.
- No literal 1.0 for the guard in the script (GameConstants). Layout pixel numbers live in the `.tscn`, not in code.
- Boundary 4: the screen reads nothing from `PlayerData` in this story and navigates only through `Router` (via the seam).

### Project Structure Notes

- Paths match the architecture: `scenes/screens/report_card.tscn`, `scripts/screens/report_card.gd`, `scenes/characters/professor_zombie.tscn`, `scripts/characters/professor_zombie.gd`, `assets/sprites/characters/professor/` ("Cap/gown overlay + pointing pose").
- `data/anchors/professor_anchors.tres` (`SpriteAnchors`) is Story 4.3, not this one; the `HatSlot` is placed by hand for now.
- Variance: no `assets/sprites/ui/report_card/` art yet (placeholder `StyleBoxFlat`, Story 5.0 fills that folder).

### Previous story intelligence (2.8, 2.7, 2.5)

- **2.8:** delivered `new_best` in the payload and moved recording to `ENDING`; the report card only displays. First run of a level → `false`. `test_run_frame.gd` already asserts the REPORT_CARD navigation and payload.
- **2.7:** `navigate` / `pause_tree` seam pattern; menus inside the run use `ui_cancel` in `_unhandled_input`; focus is released when a panel closes. Reuse the `navigate` seam shape exactly.
- **2.5:** placeholder `StyleBoxFlat` chrome, palette colours as `Color(r, g, b, 1)` floats in `.tscn`, Press Start 2P width math (16 px per glyph at 16 px) forced layout changes that were recorded as approved deviations. The HUD label says "Keys"; the report card keeps "Keys Typed" (deferred-work note).
- **Review habits 2.4–2.8:** state that outlives its trigger needs an explicit test (here: `_leaving`, the guard); honest mutation reporting; correct test counts in the Dev Agent Record.

### Git intelligence

- One commit per story (`986b9d3 Story 2.8: run recording and personal bests`, `06d94bb Story 2.7…`, `cc90031 Story 2.6…`). Working tree clean at story creation. Suggested message if asked: `Story 2.9: chalkboard report card`.
- 2.6 added a `tools/gen_finger_map.gd` generator and 1.9 `tools/gen_art_prototypes.gd`: generated data is committed together with the tool change.

### Latest tech notes (Godot 4.7.2, verified against this repo's patterns)

- `Viewport.set_input_as_handled()` in `_input` prevents GUI and unhandled handlers from seeing the event.
- `Button`: theme items `normal`, `hover`, `pressed`, `focus`, `disabled` (StyleBox) and `font_color`, `font_focus_color`, `font_hover_color`, `font_pressed_color`, `font_hover_pressed_color` (Color). `focus_neighbor_left/right/top/bottom` are `NodePath`s.
- `AnimatedSprite2D` + `SpriteFrames` with `AtlasTexture` regions, `autoplay`, `speed` per animation (8 fps). Nearest filtering is the project default; don't set per-node filters.
- `String.capitalize()` turns `"zombie_run"` into `"Zombie Run"`.
- Godot binary: `/c/Program Files/Godot/Godot.exe` (headless GUT run and tool runs as in earlier stories).

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md` (Screen Flow payloads; Architectural Boundaries 4–6; Naming Conventions; Error Handling "never stop a screen"; Configuration "no GDD number as a literal"), `DESIGN.md` / `EXPERIENCE.md` (spines win over the mock) and `docs/art-style-sheet.md` (sprite rules, one scale).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.9: Chalkboard Report Card] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR19, FR20, FR21, FR25, FR43; NFR7, NFR9, NFR16.
- [Source: ux-designs/ux-zombies-teach-typing-2026-09-27/mockups/key-report-card.html] — sections A (new best, Play Again focused) and B (first run, Menu focused); geometry in the table above.
- [Source: ux-designs/.../DESIGN.md#Layout & Spacing (Report card), #Components (Chalkboard, "New best!" stamp, Pixel button, Key hint, Pet slot / hat slot), #Colors, #Typography] — look.
- [Source: ux-designs/.../EXPERIENCE.md#Voice and Tone, #State Patterns (Report Card rows), #Interaction Primitives, #Game Feel & Juice (Report card open), #Accessibility Floor] — behaviour.
- [Source: ux-designs/.../.decision-log.md D16] — mortarboard on top of the hat, level-name heading, night classroom, one sprite scale.
- [Source: _bmad-output/planning-artifacts/gdds/.../gdd.md#Screens & Flow, #Asset Requirements] — Professor Zombie overlay (cap, gown, pointing pose).
- [Source: _bmad-output/game-architecture.md#Screen Flow, #Cosmetics, #Project Structure, #Architectural Boundaries] — payload, slots, paths.
- [Source: docs/art-style-sheet.md] — sprite rules, generator method, 1× scale.
- [Source: _bmad-output/implementation-artifacts/2-8-run-recording-and-personal-bests.md] — `new_best` payload decision.
- [Source: scripts/screens/report_card.gd, scripts/run/run_frame.gd, scripts/autoloads/router.gd, scripts/typing/run_result.gd, scripts/resources/level_entry.gd, tests/integration/test_screen_flow.gd] — current state described above.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline before the story: 505 GUT tests passing (Story 2.8). After: **538 / 538** passing at dev time (3566 asserts; review added 1 more test), no `Parse Error` / `SCRIPT ERROR` / `Failed to load`. New tests: 34 in `test_report_card.gd` (35 after review) (they replace the 2 placeholder tests) and 1 in `test_art_sprites.gd` (`test_overlays_exist_one_frame`).
- Order of work: the screen script and scene were written before `test_report_card.gd`. Red was then shown by running the new tests against the HEAD placeholder `report_card.gd` / `.tscn`, restored byte for byte afterwards: 32 of 538 failing. For the art, the new sprite tests were run with `assets/sprites/characters/professor/` moved aside: missing-file, size-guard and `.import` failures; green once restored.
- Re-running `gen_art_prototypes.gd` rewrote the four existing PNGs byte-identical (no git change). The two professor PNGs and their `.import` files (Lossless, no mipmaps) are new.
- Mutation checks (each applied alone to `report_card.gd`, full suite, byte-for-byte restore verified):
  1. guard `>=` -> `>`: **killed** (10 failing: Enter/Esc/click/button at exactly 1.0 s).
  2. guard removed from `_input`: **killed** (1 failing: `test_click_handled_during_guard_only`). Enter/Esc/button tests still pass because `_leave()` has its own guard. This is by design: there are two guards.
  3. echo check removed: **killed** (`test_echo_enter_ignored_after_guard`).
  4. `_leaving` check removed from `_leave()`: **killed** (`test_only_one_navigation`).
  5. bonus row shown when the bonus is 0: **killed** (`test_bonus_zero_hides_bonus_line`, `test_no_result_warns_and_shows_zeros`).
  6. stamp when `new_best` is missing (`get("new_best", true)`): **killed** (`test_no_stamp_when_not_new_best_missing_or_not_bool`, `test_empty_payload_never_crashes`).
  7. Play Again sends `MAIN_MENU`: **killed** (5 failing).
- GUT note: with this repo's `.gutconfig.json` (`dirs`), `-gtest=` still runs the whole suite, so every run above is a full run.
- The "non-equal opposite anchors" engine warnings in the log come from `test_hud.gd` (they were there before this story).

### Completion Notes List

- **Level name:** `LevelEntry.display_name` (default `""`, so old `.tres` files stay valid). `test_level` -> "Test level". Heading rule: the registry name, else `capitalize()` of the id, else "Report Card".
- **Decision (two parts of the spec disagreed):** Task 5.1 says a card without a result takes its heading "from `FALLBACK_LEVEL_ID`", but AC 8 and Task 6.2 say the fallback heading is "Report Card". I used "Report Card", because such a card has no level to name. Play Again on that card still uses `FALLBACK_LEVEL_ID` (`zombie_run`): the intended NFR16 path back to the menu.
- **Professor Zombie art:** `professor_point.png` (2 frames, 8 fps): the player zombie's head mirrored to face left, a flat 12 px crown at row 5, a night gown with dusk folds, bare green feet, and a raised arm with a wood-light pointer stick whose ink tip sits in column 1. Frame 2 lowers the arm and stick 1 px (the tap). Soles are on row 30 in both frames. `professor_mortarboard.png` (1 frame): an ink board, a night cap resting on the crown (row 5) and a bat-purple tassel. Both pass the palette, hard-alpha and outline tests; the outline rule needed no test change.
- **Sprite tests:** the professor sheet is in `SHEETS`. The mortarboard is in a new `OVERLAYS` list and gets the size, palette/alpha, outline and import checks. `/professor/` sheets are checked for the zombie greens; overlays for ink only. The art review scene is unchanged (optional); the 8 fps and 2 frames are asserted in `test_report_card.gd` instead.
- **Professor scene:** `Body` (AnimatedSprite2D, `point`, autoplay, not centered), `%HatSlot` at the crown's top-centre (16, 5), and `Mortarboard` drawn after the slot. `%PetSlot` sits at (44, 0) on the floor to his right. Scale is 1x. `_ready()` logs a warning and hides `Body` if it has no frames.
- **Report card:** the layout follows Dev Notes -> Layout at 640x360, with placeholder chrome only (square `StyleBoxFlat`, palette colours). The board's hard 2 px drop shadow is an ink `ColorRect` behind the frame, because `StyleBoxFlat` draws no shadow when `shadow_size` is 0. The Professor is at (430, 270): soles on y 300, pointer tip at x 431 on the board frame's right edge, y 279-281.
- **Size changes forced by the font (the same kind Story 2.5 recorded):** Play Again 120 -> 176 px wide at (32, 308); "Enter" hint 56 -> 88 at (216, 312); Menu 80 at (328, 308); "Esc" hint 40 -> 56 at (416, 312), so the button row moved left; "New best!" stamp 142x40 -> 160x32, moved to (288, 20) to the right of the heading and not rotated. There are no other size changes. Every text is 16 px or more (the heading is 24 px), and a test checks it.
- **Pixel-button focus look:** the scene's `focus` box draws only the 2 px candy-yellow ring outside the ink outline. On focus, `report_card.gd` swaps `normal`/`hover` to the pumpkin-light fill (with a 1 px ink border) and swaps back when focus leaves. This is the script-swap variant the story allows, and it keeps the ink outline between the fill and the ring. The focused button has ink text, hovered or not. The screenshots show the fill under the label.
- **Input:** the guard lives in `_input`. While `_open_s < REPORT_CARD_INPUT_GUARD_S`, and after the card has navigated, every press is swallowed before the GUI sees it; echoes are always swallowed. `_leave()` has the same guard. I used `event.is_pressed()` rather than checking for key and mouse-button types only, so joypad and `InputEventAction` presses are guarded too. Releases pass through, so a press made during the guard can never complete a button click later. Esc -> Menu, and Enter with no focused button -> Play Again, are handled in `_unhandled_input`. Arrow keys are also swallowed during the first second, because they are key presses (Task 5.4).
- **Reveal:** rows appear 0.1 s apart; the bonus row appears only when there is a bonus; the stamp comes one step after the last row (0.6-0.7 s, inside the guard). `set_process(false)` runs once everything is shown and the guard is over.
- **Tests use Godot's real input order:** key tests use `get_viewport().push_input()` (press, then release), so the focused Button, GUI focus navigation and `_unhandled_input` run as they do in the game. Time is driven by calling `_process` by hand, with real processing switched off.
- **Manual check (Task 7):** screenshots (a) first run and (b) new best at 1280x720 were rendered from the real scene with real `RunResult` payloads by a throwaway script (now deleted); they were not captured from a played run. Then, in the debug web build, two real Test level runs (2:00 each, 1-2 keys typed) reached the report card with no stamp (0 WPM, the 2.8 first-run rule). Enter replayed the level, the arrow keys moved focus (the pumpkin fill moved to Menu), and Esc went to the main menu. Not checked by hand: the 1.0 s mash window itself (the tool's delay is too unpredictable to time it; the viewport tests cover it), a mouse click on a button, and a played run that earns the stamp.
- **Smuck's review (7.2), 2026-10-04: "OK as is".** The Professor sprite and the layout are approved, and he stays at 1x (one sprite scale). The size question is logged in `deferred-work.md`.

### File List

- `_bmad-output/implementation-artifacts/2-9-chalkboard-report-card.md` (this story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/screenshots/2-9/a-first-run.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/2-9/b-new-best.png` (new)
- `assets/sprites/characters/professor/professor_point.png` (+ `.import`) (new)
- `assets/sprites/characters/professor/professor_mortarboard.png` (+ `.import`) (new)
- `data/levels/level_registry.tres`
- `docs/art-style-sheet.md`
- `scenes/characters/professor_zombie.tscn` (new)
- `scenes/screens/report_card.tscn`
- `scripts/characters/professor_zombie.gd` (+ `.gd.uid`) (new)
- `scripts/core/game_constants.gd`
- `scripts/resources/level_entry.gd`
- `scripts/screens/report_card.gd`
- `tests/unit/test_art_sprites.gd`
- `tests/unit/test_report_card.gd` (+ `.gd.uid`) (renamed from `test_report_card_placeholder.gd` and rewritten)
- `tools/gen_art_prototypes.gd`

## Change Log

- 2026-10-04: Story 2.9 created.
- 2026-10-04: Story 2.9 implemented: chalkboard report card (stats, bonus line, "New best!" stamp, level-name heading, 1.0 s mash guard, one exit, Play Again focused on open), Professor Zombie sprite and scene with empty hat/pet slots, `LevelEntry.display_name`, 35 new tests (34 in `test_report_card.gd`, 1 in `test_art_sprites.gd`; 538 passing at dev time). Status -> review.
