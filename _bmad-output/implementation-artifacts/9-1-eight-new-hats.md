---
baseline_commit: 9f382bea477648cf659f6cad6333529654b34610
---

# Story 9.1: Eight New Hats

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want lots of silly hats to save up for,
so that I always have a next goal.

## Acceptance Criteria

1. **Eight hat overlays (FR75, NFR10, NFR13).** The 8 remaining hats (Witch hat, Bunny ears, Santa hat, Leprechaun hat, Valentine heart headband, New Year's top hat, Pirate hat, Golden crown) are drawn by `tools/gen_cosmetics_art.gd` as 32×32 one-frame overlays at `assets/sprites/cosmetics/hats/hat_<name>.png` (+ `.import`, Lossless, no mipmaps). Each follows `docs/art-style-sheet.md`: palette only, hard alpha, 1 px `ink` outline, seat on row 30 centred on x 16, at least 12 px wide, no `candy-yellow`, no `stamp-red`, kid-safe (cute-Halloween, nothing scary, no skull and crossbones or other bones).
2. **Height cap (new, tested).** No hat rises more than `HAT_MAX_RISE` = 18 px above its seat (top opaque row ≥ 12). Reason: a brute copy (1.5×) in Horde Rush lane 0 has its crown at y ≈ 29, so a taller hat would leave the top of the screen. The cap and its reason go into the style sheet and the test.
3. **Data (FR75).** Each of the 8 existing `data/cosmetics/hat_*.tres` gets its `overlay` (the new PNG) and its Closet `icon` (an `AtlasTexture` of the overlay cropped to its opaque pixels and padded back to 32×32, centred, exactly like `hat_pumpkin.tres`). Ids, display names, rows and prices stay as they are (row prices 100 / 200 / 300). **`is_available` stays `false` on all 8.** Story 9.3 switches the full catalogue on; until then the Closet keeps showing "Coming soon" for them.
4. **Fit check covers everything (Epic 9 AC 2).** `scenes/debug/hat_fit_check.tscn` shows each hat on every player-zombie frame (idle, walk, hop, hug, dance, flash, melt, dazed), on Professor Zombie's two `point` frames (mortarboard stacked on the hat) and, new in this story, on the three Horde Rush size classes (scales read from `data/levels/horde_rush.tres`, not literals). Every hat sits correctly on every cell. Any anchor fix is made in the `SpriteAnchors` data (`data/anchors/*.tres` via `tools/gen_sprite_anchors.gd`), never by redrawing a character sheet. (Expected: no anchor change is needed; the anchors are hat-independent.)
5. **Approval gates.** Gate 1: Smuck approves the 8 overlays (fit-check screenshots at 3× on night and parchment) **before** they are wired into the `.tres` files. Gate 2: Smuck approves the in-game look (menu, report card with mortarboard, Closet preview, a Zombie Run hop/hug, a Horde Rush brute, the Pitchfork Panic dazed sit) with at least the tall hats (Witch, Top hat, Bunny ears) and the widest hat. Each answer verbatim with the date in `## Art Approval`. The **Hat Fit Checklist** in Dev Notes is filled in pass/fail per hat.
6. **No regressions.** The Pumpkin hat and Cute ghost PNGs are pixel-identical after rerunning the tool; no pet changes (9.2); `PlayerData`, the save schema, `HatSlot`, `PetSlot`, `ClosetItemTile`, `CryptCloset`, `ProfessorZombie` and every level script are unchanged. Full GUT suite green (baseline **2031** after 8.7; re-count at the start).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 6)
  - [x] 1.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the full suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count (2031 expected). Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 1.2 Record the sha256 of `hat_pumpkin.png` and `pet_cute_ghost_idle.png` (they must not change in Task 2).

- [x] **Task 2: Generalise the cosmetics art tool and draw the hats** (AC: 1, 2, 6) — `tools/gen_cosmetics_art.gd`
  - [x] 2.1 Today `_sheet_image()` assumes every map is `MAP_W` = 14 wide with `PAD` = 9. Hats need other widths (a witch brim is wider than 14; bunny ears narrower at the top). Make the padding per part: each part's rows share one width `w`, **`w` must be even** (the centring test is `used.position.x + used.end.x == 32`, which only an even, symmetric width satisfies), and the map is placed at x `(32 − w) / 2`. Keep the existing error paths (bad width, bad legend, part out of frame) and the non-zero exit. The pumpkin and ghost maps stay 14 wide, so their output is unchanged.
  - [x] 2.2 Keep `HAT_LEGEND` for the pumpkin. Either extend it with the new characters or give each hat its own legend constant; every legend value must be a key of `Proto.PALETTE`. Keep a short `##` doc above each map saying what it is, its top row and its width.
  - [x] 2.3 Draw the 8 maps (see **Hat design notes** below). Each map's last row is the brim/band's bottom ink row and is placed so it lands on **row 30**; row 31 stays empty; top row ≥ 12 (AC 2); an **even** number of rows and an even width (so the Closet icon centres exactly, Task 6.1). Every opaque non-`ink` pixel must have 4 opaque orthogonal neighbours (so the silhouette edge is `ink`, including between bunny ears and around heart cut-outs).
  - [x] 2.4 `_init()`: write all nine hats (pumpkin + 8) and the ghost. Output names: `hat_witch.png`, `hat_bunny_ears.png`, `hat_santa.png`, `hat_leprechaun.png`, `hat_heart_headband.png`, `hat_top_hat.png`, `hat_pirate.png`, `hat_crown.png` (they match the `.tres` ids; `hat_<name>.png` naming).
  - [x] 2.5 Update the tool's header doc (it says "the Pumpkin hat overlay and the Cute ghost"; add Story 9.1 and the per-part even-width rule).
  - [x] 2.6 Run headless, then `--import`. Confirm `git status` shows `hat_pumpkin.png` and `pet_cute_ghost_idle.png` unchanged (sha256 from 1.2). If bytes differ but pixels match, `git checkout` them; never commit a re-encoded approved PNG.

- [x] **Task 3: Art tests and the style sheet** (AC: 1, 2)
  - [x] 3.1 `tests/unit/test_art_sprites.gd`: add the 8 paths to `OVERLAYS` (all `FRAME`) and to `HATS`. Update the header doc. Check every test that sums sheet counts (`test_overlays_exist_one_frame`, the `sheets.size()` checks at ~280 and ~357, the import-settings loop) still adds up.
  - [x] 3.2 New const `HAT_MAX_RISE: int = 18` with a `##` doc giving the Horde Rush lane-0 brute reason. In `test_hats_seat_on_row_30_centred` (or a new `test_hats_fit_under_the_screen_top`) assert `HAT_SEAT_ROW − used.position.y <= HAT_MAX_RISE` for every hat.
  - [x] 3.3 A new test (in `tests/unit/test_horde_rush_level.gd`) that ties the cap to the real geometry, data-driven so a future scale or lane change fails here and not on screen: `scale` = the largest `sprite_scale` in `horde_rush.tres`; `crown_row` = the smallest head-point y over the `walk` frames in `zombie_anchors.tres`; `feet_y` = the level's `lane_feet_y(0)` (or `FIELD_TOP_Y + LANE_HEIGHT_PX − LANE_FEET_INSET_PX` from the consts); Body's y offset is −31 (`player_zombie.tscn`). Assert `feet_y + scale * (−31 + crown_row) − scale * HAT_MAX_RISE >= 0`. Also assert, for every shipped hat, that its own rise passes the same check (so the test covers the real hats, not only the cap).
  - [x] 3.4 Optional per-hat colour tests in the style of `test_pumpkin_hat_colours` (one assertion set per hat: its signature colours). At minimum a single test asserting no hat uses `art-moon` (the style sheet reserves it for the moon).
  - [x] 3.5 `docs/art-style-sheet.md`: section 1 (Epic 9 hats: Story 9.1), section 3 table (one row per new overlay: `hat_<name>.png` (9.1) | overlay | 32×32 | – | seat on row 30 at x 16), the Hats paragraph (even widths; `HAT_MAX_RISE` 18 and why; the generator places each part centred), section 5 (pirate hats carry no skull and crossbones: no bones rule). Keep rule text that tests quote in step with the tests.

- [x] **Task 4: Fit check gains the Horde Rush size classes** (AC: 4)
  - [x] 4.1 `scripts/debug/hat_fit_check.gd`: `@export var horde_config: HordeRushConfig` (set in `hat_fit_check.tscn` to `res://data/levels/horde_rush.tres`; static data by `@export`, no literals). Add one more set of cells: for each size class, a player-zombie `walk` frame 0 cell at that class's `sprite_scale`, plus a detail cell at `sprite_scale × DETAIL_SCALE`. Label them `small 1.0`, `medium 1.25`, `brute 1.5` (from the class `id` and scale). They go on their own page after the professor cells, using the same `_add_zombie_cell` (so the hat follows the anchors) and the same paging.
  - [x] 4.2 Keep everything else: H/P/B/N/E/Esc, both pet cells, the debug-only Boundary 7 rule, the seams. Update the class doc (size-class page) and the footer if it helps ("E only wears available items").
  - [x] 4.3 `wear_for_real()` on an unavailable hat: `buy_item` returns `UNAVAILABLE` and the scene warns `fit check: could not buy`. That is correct until 9.3; leave the behaviour, but say so in the class doc so nobody "fixes" `PlayerData`.
  - [x] 4.4 `tests/unit/test_hat_fit_check.gd`: update the header doc and `CELLS_PER_SCALE` (30 → 30 + the new cells; decide whether size-class cells are counted per scale the same way and adjust `test_builds_28_cells_at_both_scales`, whose name is already stale: rename it to describe what it checks). Fix the tests that assume one hat: `test_professor_mortarboard_stacks_on_the_hat` ("none after the only hat" → cycle until `current_hat()` is null, i.e. 9 cycles; also assert the rise for one tall hat equals `30 − used_rect.position.y` of its overlay), `test_e_wears_for_real_and_none_unequips` (cycle hat and pet to "none" by cycling until null, not once), and `test_cycling_never_crashes` (still zero warnings while cycling; E is not pressed there). Add: the hat cycle visits exactly the 9 catalogue hats in grid order, then none; the size-class cells use the config's scales and their hat slots sit at `anchors.get_head(anim, frame)`.

- [x] **Task 5: Gate 1: the overlays** (AC: 5) — **don't touch the `.tres` files before this passes**
  - [x] 5.1 Gate 1 needs the hats in the fit check *without* wiring the shipped data: run the fit check with a scratch catalogue (a scratch script in the scratchpad that duplicates `catalogue.tres`, assigns each new overlay, and instances `hat_fit_check.tscn` with that catalogue before `add_child`), or wire the overlays in a local uncommitted change and revert if Smuck asks for redraws. Never write to the real `user://save.json`.
  - [x] 5.2 Capture (real window, not `--headless`) per hat: the zombie page at 3× on `night` and on `parchment`, the professor cells, and the new size-class page. Save to `_bmad-output/implementation-artifacts/screenshots/9-1/gate1-<hat>-*.png` (keep the set small: one combined sheet per hat is fine).
  - [x] 5.3 Show Smuck. Record the verbatim answer with the date in `## Art Approval`. Redraw in the tool only what Smuck asks for, regenerate, re-show.

- [x] **Task 6: Wire the data** (AC: 3)
  - [x] 6.1 For each of the 8 `hat_*.tres`: add the PNG `ext_resource` (with its uid from the `.import` file, as in `hat_pumpkin.tres`), an `AtlasTexture` sub-resource `icon` whose `region` is the overlay's `get_used_rect()` and whose `margin` centres it exactly in 32×32 (`margin.position * 2 + region.size == (32, 32)`). Exact centring needs an even opaque width **and height**, so draw every hat with an even number of rows (Task 2.3; the pumpkin is 14×12). Don't loosen the test to fit an odd hat; redraw it. Then `overlay = ExtResource(...)`, and fix `load_steps`. **Keep `is_available = false`.** Simplest route: a scratch tool in the scratchpad that loads each item, builds the icon from `get_used_rect()`, and `ResourceSaver.save()`s it; then diff the `.tres` text and hand-tidy ids to match the pumpkin's style.
  - [x] 6.2 `tests/unit/test_catalogue.gd`: replace the "Epic 9 items have no art" loop in `test_shipped_mvp_items_have_art` with: every hat has a 32×32 overlay and a 32×32 icon; every unavailable **pet** still has no icon, overlay or frames (9.2 adds them). Generalise `test_pumpkin_icon_is_centred` to every hat (same three assertions per hat). `test_shipped_only_mvp_items_are_available` stays exactly as it is (it is the guard that 9.1 does not switch anything on).
  - [x] 6.3 `tests/unit/test_closet_item_tile.gd` / `test_crypt_closet.gd`: nothing should break (a locked tile hides `%Art` and shows `%Question`). Add one test that a shipped unavailable hat with an icon still renders `LOCKED` with `%Art` hidden, so the new icons never leak through "Coming soon" before 9.3.

- [x] **Task 7: Gate 2: in-game check** (AC: 4, 5)
  - [x] 7.1 Scratch capture script (pattern: `tools/capture_screens.gd` and the 6.6 / 8.6 capture scripts; temp `SaveService` dir; record `user://save.json` sha256 before/after). Because the hats are unavailable, `PlayerData.get_equipped()` filters them out: inject a `PlayerData` whose `catalogue` is a duplicate of the shipped one with `is_available = true` on the hats (test seam), never edit the shipped `.tres` for this.
  - [x] 7.2 Shots for at least Witch, Top hat, Bunny ears and the widest hat, others optional: main menu (zombie + hat, nothing touches the logo or cards), report card (professor, mortarboard on the hat; the board edge at x 432/434 and the window at y 14–122 untouched; note the tallest mortarboard top y), Crypt Closet preview (hat inside the mirror panel 244–396 × 76–196), Zombie Run mid-hop and mid-hug, Horde Rush brute in lane 0 (3× crop: hat fully on screen), Pitchfork Panic dazed sit. Save under `screenshots/9-1/gate2-*.png`, plus one grayscale copy of the menu shot (`tools/capture_screens.gd -- --convert <png>`).
  - [x] 7.3 Fill in the **Hat Fit Checklist**. Show Smuck; record the verbatim answer with the date in `## Art Approval`.

- [x] **Task 8: Verification and wrap-up** (AC: 6)
  - [x] 8.1 `--import`, full suite; record before/after counts; grep for `Parse Error|Compile Error|Failed to load script`; report new warning counts honestly.
  - [x] 8.2 Mutation pass (the project habit): move one hat's seat to row 29; make one map 15 wide (odd); raise a hat to rise 19; put `candy-yellow` in the crown; drop one hat from `OVERLAYS`; set one hat `is_available = true`; break one icon's margin; make the fit check ignore `horde_config`. Each should be caught. Report honestly any that survive.
  - [x] 8.3 `deferred-work.md`: add "Deferred from: dev of story-9.1" with what is left (at least: the hats become buyable in 9.3; anything accepted at a gate). Mark nothing as resolved unless this story resolved it.
  - [x] 8.4 Update this file's Dev Agent Record and File List; `sprint-status.yaml` 9-1 → `review`.

### Review Findings

- [x] [Review][Decision] (Resolved: keep the preload, dismissed by Smuck 2026-10-13) Cross-test coupling: `test_horde_rush_level.gd` preloads the GutTest script `test_art_sprites.gd` to read `HATS` and `HAT_MAX_RISE` — this coupling is what flipped the StringName sort order and forced the out-of-scope stress-test edit. Options: (a) move the shared constants to a non-test script (e.g. a `tests/support/` helper or the tool/art constants) and have both tests use it; (b) keep the preload and accept it. (blind+auditor)
- [x] [Review][Patch] (fixed: band now 12 wide, PNG regenerated; Smuck to glance at it) Top hat band is 1 px wider than the body: row 9 `"..kccccccccccck."` ends at col 14, every other body row ends at col 13, so the band bulges right [tools/gen_cosmetics_art.gd:184] (then regenerate `hat_top_hat.png`/icon region if it changes; the brim hides it from the centring tests). Note the art was approved at Gate 1/2; re-show Smuck the 1 px fix.
- [x] [Review][Patch] Brute lane-0 test passes vacuously: if `anchors.head[&"walk"]` is empty/missing, `crown_row` stays INF and every `>= 0.0` assertion passes; add a guard (`assert_lt(crown_row, INF)`) and handle a missing key [tests/unit/test_horde_rush_level.gd, `test_hats_stay_on_screen_on_a_brute_in_lane_0`]
- [x] [Review][Patch] `_all_hats_catalogue()` is dead logic: all shipped hats now have an `overlay`, so the `copy.overlay == null` fallback never fires and the docstring is false; use the shipped catalogue directly or remove the helper [tests/unit/test_hat_fit_check.gd, `_all_hats_catalogue`]
- [x] [Review][Patch] `CELLS_PER_SCALE = 33` is misnamed (the extra cells are per size class: scaled + 3x detail) and hard-codes 3 classes while other assertions derive from `size_classes.size()`; `page_count() == 7` likewise. Derive from the config [tests/unit/test_hat_fit_check.gd]
- [x] [Review][Patch] Unbounded loop in `test_e_wears_for_real_and_none_unequips`: `while check.current_pet() != null: check.cycle_pet()` has no cap (other loops cap at 100) [tests/unit/test_hat_fit_check.gd]
- [x] [Review][Patch] Stale style-sheet line: "Later epics (9, 10) reuse these rules…" now contradicts the new "Epic 9: Story 9.1" bullet directly above it [docs/art-style-sheet.md:27]
- [x] [Review][Patch] Generator does not enforce its own documented hat rules (bottom row 30, top row ≥ 12, even row count, non-zero width); a bad map writes a PNG and is only caught later by the art tests [tools/gen_cosmetics_art.gd, `_sheet_image`]
- [x] [Review][Patch] Size-class page appends a blank page when `size_classes` is empty (only a null config is guarded), so `page_count()` is 7 with nothing on it [scripts/debug/hat_fit_check.gd, `_build_size_class_page`]
- [x] [Review][Patch] Pirate badge is a diamond/plus, but the map comment and style sheet say "star badge"; align the wording to the approved art [tools/gen_cosmetics_art.gd, `PIRATE_HAT`; docs/art-style-sheet.md]
- [x] [Review][Patch] Test nits: hard-coded `30` instead of `HAT_SEAT_ROW` in the mortarboard test [tests/unit/test_hat_fit_check.gd]; `page.visible = _pages.is_empty()` is always false at that point (dead/misleading) [scripts/debug/hat_fit_check.gd:~353]
- [x] [Review][Defer] Brute lane-0 test ignores `Body` scale/rotation and uses only the lowest walk crown row, so it has no margin on the 18 px cap (the `HAT_MAX_RISE` assertion is the real guard) — deferred, already documented by the dev in deferred-work.md
- [x] [Review][Defer] `HatSlot.show_item` does not check `is_available` and `ClosetItemTile._apply_art` still assigns the texture to its hidden `Art` rect — deferred, pre-existing behaviour; revisit in Story 9.3 when the hats go on sale

## Dev Notes

### What this story is (and isn't)

- **Is:** 8 hat overlays drawn in the existing cosmetics tool, their data (overlay + Closet icon) in the existing `.tres` files, art tests and the style sheet updated, a height cap, a Horde Rush size-class page in the fit check, two art gates.
- **Isn't:** making the hats buyable (`is_available` flip is **Story 9.3**, with its save-compatibility check). Pets (9.2). Any change to `PlayerData`, the save, `HatSlot`, `PetSlot`, `ProfessorZombie`, `ClosetItemTile`, `CryptCloset`, the menu, the report card or any level. New anchors (only if the fit check proves one wrong, which would be a character-art bug, not a hat bug). A "Play with it!" button. Seasonal logic (the Santa/Valentine/New Year's hats are always available once 9.3 ships; no dates).

### What already works (do not rebuild it)

- **The display system is done (4.3) and hat-agnostic.** `HatSlot` (`scripts/cosmetics/hat_slot.gd`) puts `%Overlay` at `-SEAT` (16, 30) from the per-frame head point in `SpriteAnchors`, mirrors on `flip_h`, follows `PlayerData.equipment_changed` itself, and warns once (never crashes) on a missing overlay or anchor (NFR16). Any overlay that follows the seat rule fits every pose with no code change.
- **The professor lifts the mortarboard by the hat's rise automatically** (`ProfessorZombie._hat_rise`: `SEAT.y − overlay.get_image().get_used_rect().position.y`, cached per id). Tall hats just lift it higher. Pumpkin rise is 11; with the cap (18) the mortarboard tops out about 7 px higher than today (the 4.3 note put the pumpkin's at y ≈ 258). Nothing above the professor at x 430–462 until the window bottom at y 122, so this is safe; confirm in Gate 2.
- **Horde Rush copies** are `player_zombie.tscn` scaled at the root (`HordeSizeClass.sprite_scale` 1.0 / 1.25 / 1.5 in `data/levels/horde_rush.tres`), so the hat scales with the body (6.6 proved the seat equals the scaled head point through walk, flash, melt, idle, dance). That proof holds for any overlay; what 9.1 adds is the visual check and the screen-top cap.
- **The Closet** shows `item.icon` in `%Art` only when the tile is not `LOCKED`; a locked tile shows `%Question` ("?") and "Coming soon" (`ClosetItemTile.show_state`, `info_lines`). The preview zombie only previews available items (`crypt_closet.gd:262`). So adding icons now is invisible to kids until 9.3.
- **`PlayerData.buy_item` returns `UNAVAILABLE`** and `get_equipped` filters unavailable ids. That's why Gate 2 needs an injected catalogue (Task 7.1).

### Existing code: current state, what changes, what must be preserved

- `tools/gen_cosmetics_art.gd` (UPDATE). ASCII maps, one char per pixel, `.` transparent, legend char → palette **name** from `Proto.PALETTE` (`tools/gen_art_prototypes.gd`). `_sheet_image(frames, legend)` builds a strip of 32×32 frames from `[map, top_row]` parts, all 14 wide, padded by 9. Change: per-part even width, centred. Preserve: the pumpkin and ghost maps and output, the error checks, the non-zero exit, the `Proto` palette as the only colour source.
- `data/cosmetics/hat_{witch,bunny_ears,santa,leprechaun,heart_headband,top_hat,pirate,crown}.tres` (UPDATE). Today: script, id, display_name, slot 0, price, row, `is_available = false`, no art. Change: `icon`, `overlay`. Preserve: ids (saves store them, permanent once shipped), names, prices, rows, `is_available = false`.
- `data/cosmetics/catalogue.tres` (READ ONLY). Already lists all 18 in grid order.
- `scripts/debug/hat_fit_check.gd` + `scenes/debug/hat_fit_check.tscn` (UPDATE). Cycles every catalogue hat **with an overlay** (`_with_art`), so all 8 appear automatically once wired. Change: the size-class page, the config export, doc. Preserve: the 30 existing cells per scale, paging, keys, seams, Boundary 7.
- `tests/unit/test_art_sprites.gd`, `test_catalogue.gd`, `test_hat_fit_check.gd` (UPDATE, see Tasks 3, 4, 6).
- `docs/art-style-sheet.md` (UPDATE, Task 3.5).
- **Must not change:** `scripts/autoloads/*`, `scripts/cosmetics/*`, `scripts/characters/*`, `scripts/ui/closet_item_tile.gd`, `scripts/screens/*`, `scripts/levels/*`, `data/anchors/*` (unless a fit failure proves an anchor wrong; then rerun `tools/gen_sprite_anchors.gd`, never hand-edit), `data/levels/*`, the save schema, `project.godot`.

### Hat geometry (the 4.3 convention, plus this story's rules)

- 32×32 one-frame PNG. **Seat** = bottom-centre of the brim = pixel (16, 30): lowest opaque row 30, opaque columns symmetric about x 16 (`used.position.x + used.end.x == 32`), so **even widths only**. Row 31 empty. Width ≥ 12 (covers the 12 px crown `[10..21]`). Even width **and** even height (rows), so the Closet icon centres exactly (Task 6.1).
- The brim's bottom ink row overlaps the crown's top ink row (that reads as "sitting on it"). No gap row, no green crown pixels poking out beside a narrow band: a band narrower than 12 px leaves crown showing, which the ≥ 12 test prevents.
- **Height cap (new):** top opaque row ≥ 12, i.e. rise ≤ 18. Lane 0 feet are at y 74 (`FIELD_TOP_Y` 36 + `LANE_HEIGHT_PX` 44 − `LANE_FEET_INSET_PX` 6). Body is at (−16, −31) scaled by the root; the walk crown is row 1–2, so a brute's crown is at about 74 + 1.5 × (−31 + 1) = 29. Hat top = 29 − 1.5 × rise; rise 18 → 2 (on screen), rise 20 → −1 (cut). Pumpkin is rise 11 for comparison; aim tall hats at about 15–17 (an even height means an odd rise, so 17 is the tallest that fits both rules).
- Suggested max width 20 (x 6–25): a wide witch or pirate brim still clears the report-card board (professor body x 430–462, hat ≤ x 436–456, board edge 432/434).
- Asymmetric hats are fine (a tilted pirate hat, a feather on one side) as long as the opaque **extents** are symmetric about x 16; the centring test only checks extents. `flip_h` mirrors the overlay with the zombie, so a feather on the right becomes a feather on the left when the zombie turns (expected, fine).

### Hat design notes (suggestions; Smuck decides at Gate 1)

Palette only. **Banned in hats (tested):** `candy-yellow` (focus only), `stamp-red` (the stamp only). Also avoid `art-moon` (the style sheet reserves it for the moon). "Red-ish" things use `pumpkin` or the brain ramp (`art-brain-pink` #F29AB8 / `art-brain-shade` #C9607F). Kid-safe: cute-Halloween, never scary, **no bones** (so no skull and crossbones on the pirate hat).

| Hat | id | Row/price | Ideas |
|---|---|---|---|
| Witch hat | `hat_witch` | 1 / 100 | Tall cone (rise ~17), bent tip, wide brim; `bat-purple` with `dusk` shade, a `pumpkin` band with a `pumpkin-light` buckle. |
| Bunny ears | `hat_bunny_ears` | 1 / 100 | Two upright ears on a thin band; `chalk` with `stone-light` shade, `art-brain-pink` inner ear. Each ear needs its own ink outline (the gap between ears is transparent and edged in ink). One ear may flop for goofiness. |
| Santa hat | `hat_santa` | 2 / 200 | Floppy cone falling to one side, `chalk` fur trim along the brim and a `chalk` pom-pom; body in `art-brain-shade` with `art-brain-pink` highlight (not stamp-red). |
| Leprechaun hat | `hat_leprechaun` | 2 / 200 | Short top hat with a flat brim; `art-grass` body with `zombie-green-dark` shade (contrasts with the zombie's `zombie-green` skin; ink outline separates), `wood-dark` band, `pumpkin-light` square buckle, maybe a small clover. |
| Valentine heart headband | `hat_heart_headband` | 2 / 200 | A thin band on the crown (rows 29–30, ≥ 12 wide) with two hearts bobbing on springs (deely-boppers); hearts `art-brain-pink`/`art-brain-shade`, springs `ink` lines. Every non-ink pixel needs 4 opaque neighbours, so springs are ink only. |
| New Year's top hat | `hat_top_hat` | 3 / 300 | Tall straight top hat (rise ~16); `night`/`ink-muted` body (ink outline still reads: give it a `stone` highlight stripe), `chalk` band, a few confetti dots (`pumpkin-light`, `art-brain-pink`, `zombie-green-bright`) inside the outline. |
| Pirate hat | `hat_pirate` | 3 / 300 | A tricorn/bicorne, widest hat (up to 20 px); `ink-muted` or `wood-dark` body, `pumpkin-light` trim, a `chalk` feather or a `chalk` star/anchor badge. **No skull and crossbones** (no bones rule). |
| Golden crown | `hat_crown` | 3 / 300 | Five points, `pumpkin-light` base with `pumpkin` shade, `chalk` glints, gems in `art-brain-pink` and `bat-purple`. Gold without `candy-yellow`: ask Smuck at Gate 1 if `pumpkin-light` reads as gold; do not use `candy-yellow` or `art-moon` without changing the style sheet and its test in the same change (and only with Smuck's OK). |

Read every hat on all four fit-check backgrounds (night, art-sky, chalkboard, parchment) and on the Moonlit Village (Pitchfork Panic). Dark hats (top hat, pirate, witch) on night need a lighter inner highlight so they don't become an ink blob.

### Hat Fit Checklist (fill in during Tasks 5 and 7; pass/fail per hat)

Columns: Witch · Bunny · Santa · Leprechaun · Heart · Top hat · Pirate · Crown.

| # | Check | What to look for |
|---|---|---|
| 1 | Seat | Every zombie frame (idle, walk, hop, hug, dance, flash, melt, dazed): brim on the crown, no gap row, no green crown pixels beside the brim/band, hat bobs with the head |
| 2 | Centring | Looks centred at 3× (asymmetric decoration OK, extents symmetric) |
| 3 | Outline | Brim's bottom ink row merges with the crown's top ink row; no double-thick blob; separate parts (ears, hearts) each outlined |
| 4 | Professor | Hat on the crown, mortarboard resting on the hat's top (both frames), nothing over the board or window |
| 5 | Size classes | Small / medium / brute: hat on the crown, pixels readable at 1.25 and 1.5 |
| 6 | Screen top | Brute in Horde Rush lane 0: hat fully on screen |
| 7 | Backgrounds | Readable on night, art-sky, chalkboard, parchment and the Moonlit Village |
| 8 | Melt / dazed | Hat rides down onto the puddle (melt) and sits on the dazed head; still cute |
| 9 | Closet icon | Cropped, centred in the 32×32 art box (checked with a temporarily available item in Gate 2) |
| 10 | Kid-safe | Cute, never scary; no bones, no candy-yellow, no stamp-red |

**Results (2026-10-13, Gate 1 sheets + Gate 2 shots + tests):**

| # | Witch | Bunny | Santa | Leprechaun | Heart | Top hat | Pirate | Crown | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| 1 | pass | pass | pass | pass | pass | pass | pass | pass | gate1-<hat>.png pages 1–6 (all 30 frames incl. dazed); bottom ink ≥ 14 px covers the 12 px crown |
| 2 | pass | pass | pass | pass | pass | pass | pass | pass | `test_hats_seat_on_row_30_centred` (even widths, symmetric extents) |
| 3 | pass | pass | pass | pass | pass | pass | pass | pass | outline rule test; ears and hearts each ringed in ink; springs ink-only |
| 4 | pass | pass | pass | pass | pass | pass | pass | pass | gate1 page 6 (both point frames); gate2 report card: tallest mortarboard top y 254 (witch/bunny), far below the window bottom (122), professor x 430, board untouched |
| 5 | pass | pass | pass | pass | pass | pass | pass | pass | gate1 page 7 (small 1.0 / medium 1.25 / brute 1.5 + 3× details) |
| 6 | pass | pass | pass | pass | pass | pass | pass | pass | `test_hats_stay_on_screen_on_a_brute_in_lane_0` (all hats); gate2 brute lane 0: witch top y 5, bunny 5, top hat 8, pirate 14 |
| 7 | pass | pass | pass | pass | pass | pass | pass | pass | gate1-overview (night, parchment, art-sky, chalkboard); Moonlit Village in gate2 (witch, top hat, bunny, pirate) |
| 8 | pass | pass | pass | pass | pass | pass | pass | pass | gate1 page 5–6 (melt 0–5 rides down onto the puddle; dazed) |
| 9 | pass | pass | pass | pass | pass | pass | pass | pass | gate2 closet (all 9 hats available in the copy): icons centred; `test_hat_icons_are_centred` |
| 10 | pass | pass | pass | pass | pass | pass | pass | pass | colour tests (no candy-yellow, stamp-red, art-moon); pirate has a star badge, no bones |

### Testing notes

- Suite and import commands as in Task 1. Run `--import` after the new PNGs exist and before tests (the `.tres` uid references and `test_import_settings_lossless_no_mipmaps` need the `.import` files).
- Art tests read the committed PNG bytes (`Image.load_from_file`), so import state doesn't matter for them; the `.tres` tests do need the import.
- Never write the developer's real save: inject a temp-dir `SaveService` + `PlayerData` (patterns: `test_hat_fit_check.gd before_each`, `test_crypt_closet.gd`). For "available" behaviour, duplicate the shipped catalogue and flip `is_available` on the copy (`test_crypt_closet.gd _two_hat_catalogue` is the precedent).
- `assert_push_warning_count(0)` in `test_cycling_never_crashes` must stay true: cycling never buys.
- GUT is 9.7.1; `assert()` shows as `SCRIPT ERROR` in headless GUT, so use `Log` + safe returns in tools and scenes.

### Previous story intelligence

- **4.3 (the display system):** the hat convention, the fit-check scene, the mortarboard stack, "warn once, hide, carry on", the 14-row checklist format. Art approval was recorded verbatim with a date. Its catalogue test explicitly expected Epic 9 items to have no art: that is the assertion this story changes (Task 6.2).
- **4.4 / 5.0 (Closet):** icons are an `AtlasTexture` of the overlay cropped to `get_used_rect()` with a centring margin (5.0 fixed "the pumpkin sits low" this way; `test_pumpkin_icon_is_centred` pins it). Locked tiles never show `%Art`.
- **6.6 (Horde Rush art):** scaled copies keep the player sprite; the hat follows anchors × `sprite_scale`, proven by test; Gate 2 screenshots at 3× per class. Two-gate flow: Gate 1 approves sheets **before wiring**, Gate 2 approves in game. Tell Smuck how to see things that aren't reachable yet (here: the hats aren't buyable until 9.3).
- **8.6 (Pitchfork Panic art):** the generator style (header doc, run line, `Proto` palette, non-zero exit, reruns byte-identical, never hand-edit a PNG); `zombie_dazed` keeps a flat 12 px crown for hats, and the fit check already includes `dazed`. GUT silently skips a script that fails to parse (8.6 shipped a skipped test file; 8.7 caught it): always grep the log.
- **8.7:** baseline 2031 tests. One commit per story with code review patches applied.
- **Traps from earlier stories:** keep files LF (`.gitattributes eol=lf`). Write `×`/`–` as UTF-8. Prefer scratchpad scripts over shell heredocs with apostrophes. `untyped_declaration = Error` applies to tools too (type every `for` variable). The flaky `test_audio_manager` pool test (deferred-work 4.2): rerun once before investigating.

### Git intelligence

- Recent commits: `9f382be Story 8.7: chase tuning, sim, Pitchfork Panic switched on, code review patches applied, done`, `a00b096 Story 8.6: moonlit village, mob and chase music…`, `e00ad9a Story 8.5…`. Each story ships code, art, tests, screenshots, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- Suggested message: `Story 9.1: eight new hats`.
- Expected changes: `tools/gen_cosmetics_art.gd`; 8 new `assets/sprites/cosmetics/hats/hat_*.png` (+ `.import`); 8 `data/cosmetics/hat_*.tres`; `scripts/debug/hat_fit_check.gd`, `scenes/debug/hat_fit_check.tscn`; `tests/unit/test_art_sprites.gd`, `test_catalogue.gd`, `test_hat_fit_check.gd`, `test_closet_item_tile.gd` or `test_crypt_closet.gd`, and the Horde Rush cap test; `docs/art-style-sheet.md`; `_bmad-output/implementation-artifacts/screenshots/9-1/`; `deferred-work.md`; this file; `sprint-status.yaml`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries. Godot **4.7.2** standard, Compatibility renderer, GDScript only, statically typed.
- `Image.save_png()` is deterministic for the same pixels; reruns should be byte-identical. If the approved PNGs show as modified, compare pixels and restore from git.
- `AtlasTexture.margin` adds transparent padding: `get_size()` = `region.size + margin.size`. The pumpkin's icon is `region = Rect2(9, 19, 14, 12)`, `margin = Rect2(9, 10, 18, 20)` → 32×32, centred.
- `Texture2D.get_image()` on a Lossless-imported PNG returns its pixels at runtime (web too); the professor relies on it.
- A `.tres` `ext_resource` for a PNG should carry the uid from its `.import` file (`uid="uid://…"`), as `hat_pumpkin.tres` does.

### Project Structure Notes

- All paths follow the architecture's Directory Structure and naming (`assets/sprites/cosmetics/hats/hat_<name>.png`, `data/cosmetics/<id>.tres`, debug code only under `scenes/debug/` / `scripts/debug/`, generators under `tools/`).
- Variance: none. The size-class page in the fit check is new but stays in the debug scene.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Typed GDScript everywhere (`untyped_declaration = Error`), tabs, short `##` docs that say why, LF endings.
  - Static data comes through `@export` Resources (`data/` instances, `scripts/resources/` definitions); no GDD number as a literal in a script (the size-class scales come from `horde_rush.tres`).
  - `%UniqueName` node refs; no `/root/` paths or `get_parent()` chains.
  - Debug code only in `scenes/debug/` / `scripts/debug/` (Boundary 7).
  - Art follows the style sheet (32-colour palette, ink outline, hard alpha, Lossless, no mipmaps), is code-generated by a `tools/` script, and is never hand-edited. Final art waits for Smuck's approval recorded in the story file.
  - NFR16: a missing cosmetic logs a warning and never stops a run (already handled by `HatSlot`).
  - Saves store item ids; ids are permanent once shipped.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 9: Full Crypt Closet, Story 9.1: Eight New Hats, Story 9.3: Full Catalogue Live]; FR39, FR42, FR43, FR75; NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Crypt Closet price table (~l.280–286), cosmetic slots (~l.150), "overlays anchored to a head point" (~l.370), Pillar 1 tone (~l.76)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] hat-slot (no chrome, overlay anchored to the head point), D16 mortarboard stacks on the hat, Do's and Don'ts
- [Source: docs/art-style-sheet.md] §1 gate rule, §2 palette, §3 sprite rules and the Hats paragraph, §5 kid-safe rules, §6 reuse (Horde Rush scale, hat anchors)
- [Source: _bmad-output/implementation-artifacts/4-3-hat-and-pet-display-everywhere.md] hat geometry, mortarboard stack, fit checklist format
- [Source: _bmad-output/implementation-artifacts/6-6-farmhouse-farmer-and-march-music.md] AC 6 and Task 8.4 (hat on scaled copies), Gate 2 shots
- [Source: _bmad-output/implementation-artifacts/8-6-moonlit-village-mob-and-chase-music.md] generator rules, gates, dazed crown
- [Source: _bmad-output/implementation-artifacts/8-7-chase-tuning.md] test baseline 2031
- [Source: tools/gen_cosmetics_art.gd], [tools/gen_art_prototypes.gd PALETTE], [scripts/cosmetics/hat_slot.gd SEAT], [scripts/characters/professor_zombie.gd _hat_rise], [scripts/debug/hat_fit_check.gd], [scripts/ui/closet_item_tile.gd state_for/show_state], [scripts/screens/crypt_closet.gd:262], [scripts/levels/horde_rush/horde_rush_level.gd FIELD_TOP_Y/LANE_HEIGHT_PX/LANE_FEET_INSET_PX], [data/levels/horde_rush.tres sprite_scale], [data/cosmetics/hat_pumpkin.tres], [tests/unit/test_art_sprites.gd OVERLAYS/HATS/test_hats_seat_on_row_30_centred], [tests/unit/test_catalogue.gd test_shipped_mvp_items_have_art/test_pumpkin_icon_is_centred], [tests/unit/test_hat_fit_check.gd], [tests/unit/test_crypt_closet.gd _two_hat_catalogue]

## Art Approval

<!-- Gate 1 (the 8 overlays, before wiring) and Gate 2 (in game): Smuck's answers verbatim with the date. -->

**Gate 1 (2026-10-13)**, the 8 overlays (`screenshots/9-1/gate1-overview.png` and `gate1-<hat>.png`, fit check on night and parchment, professor and size-class pages). Asked: approve all 8 or name redraws; does `pumpkin-light` read as gold on the crown? Smuck:

> 1. I approve all. 2. It looks good

**Gate 2 (2026-10-13)**, in game (`screenshots/9-1/gate2-<hat>.png` for Witch, Top hat, Bunny ears, Pirate: menu, report card with the mortarboard, Crypt Closet icons and preview, Zombie Run hop and hug, Horde Rush brute in lane 0, Pitchfork Panic dazed; `gate2-witch-horde-rush-brute-lane0-3x.png`, `gate2-menu-witch-gray.png`; Hat Fit Checklist all pass). Smuck:

> i approve please set to review

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): 2032 tests, all passing, no Parse/Compile/Failed-to-load lines (story expected 2031; the recount is authoritative). sha256 hat_pumpkin.png `2ce877eb…f60ea`, pet_cute_ghost_idle.png `917da905…439ded`; both unchanged after rerunning the tool, and a second run is byte-identical for all 9 hats.
- Hats designed as fill-only maps in a scratch helper that adds the 1 px ink ring (4-neighbour) and checks: even width/height, rise ≤ 18, top row and both edge columns opaque, bottom row ink and ≥ 12 wide, outline rule. Generated PNGs match the helper pixel for pixel.
- Sizes (w×h, rise): witch 20×18 (17), bunny ears 16×18 (17), santa 18×16 (15), leprechaun 16×14 (13), heart headband 16×16 (15), top hat 16×16 (15), pirate 20×12 (11, the widest with the witch), crown 16×12 (11).
- `test_stress_copies_cycle_all_three_classes` (test_horde_rush_level.gd) failed once the new cap test preloaded test_art_sprites.gd: it sorted `StringName`s, which compare by interned pointer, not alphabetically. Fixed the test to sort Strings (no level code touched).
- Gate 1 capture: scratch `-s` script in a real window; a copied catalogue (each item duplicated, since deep duplicate shares external resources) gives the 8 hats their overlays; shipped `.tres` untouched; `user://save.json` sha256 identical before/after.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Tool: `_sheet_image()` places each part centred at its own even width (odd or > 32 wide is refused, non-zero exit). One shared `HAT_LEGEND` (pumpkin chars kept, new chars added; never candy-yellow, stamp-red, art-moon). Eight maps with `##` docs (top row, size, rise), written by `NEW_HATS`. Pumpkin and ghost byte-identical; reruns byte-identical.
- Data: 8 `hat_*.tres` gained `overlay` and an `AtlasTexture` icon (region = used rect, margin centring it in 32×32, uid from the `.import`). Ids, names, rows, prices unchanged; `is_available = false` on all 8.
- Tests: art (8 hats in `OVERLAYS`/`HATS`, every hat in `OVERLAYS`, even width/height, no art-moon, `HAT_MAX_RISE` 18, per-hat signature colours); Horde Rush cap against the real config, anchors, Body offset and lane 0; fit check (size-class page from `horde_config`, grid-order cycle, tall-hat mortarboard rise, no-config fallback, tests no longer assume one hat); catalogue (every hat has art, every hat icon centred, unavailable pets still bare); Closet (a shipped unavailable hat with an icon stays LOCKED with `%Art` hidden).
- Fit check: a 7th page with one column per Horde Rush size class (scaled cell + 3× detail), scales from `horde_rush.tres` via `@export horde_config`.
- Style sheet: section 1 (Epic 9), section 3 rows, Hats paragraph (even sizes, the 18 px cap and why, no candy-yellow/stamp-red/art-moon), section 5 (no skull and crossbones).
- Both gates approved by Smuck (verbatim in Art Approval); Hat Fit Checklist all pass.
- Final suite: 2040 tests, all passing (baseline 2032; +8). No Parse/Compile/Failed-to-load lines; summary shows only the pre-existing Deprecated 1.
- Mutation pass (8): seat row 29, rise 19, candy-yellow in the crown, santa `is_available = true`, broken icon margin, fit check ignoring the config scales: each caught by a test. An odd 15 px map: refused by the tool (exit 1). Dropping a hat from `OVERLAYS` survived at first; added the "every hat is in OVERLAYS" assertion, now caught. Rise 19 passes the Horde Rush geometry test alone (top y 0.5 with crown row 1) but fails the cap test.
- Also fixed (test only): `test_stress_copies_cycle_all_three_classes` sorted StringNames (pointer order), which flipped when a test script preloaded another; now sorts Strings.

### File List

- `tools/gen_cosmetics_art.gd` (modified)
- `assets/sprites/cosmetics/hats/hat_witch.png`, `hat_bunny_ears.png`, `hat_santa.png`, `hat_leprechaun.png`, `hat_heart_headband.png`, `hat_top_hat.png`, `hat_pirate.png`, `hat_crown.png` and their `.png.import` (new)
- `data/cosmetics/hat_witch.tres`, `hat_bunny_ears.tres`, `hat_santa.tres`, `hat_leprechaun.tres`, `hat_heart_headband.tres`, `hat_top_hat.tres`, `hat_pirate.tres`, `hat_crown.tres` (modified)
- `scripts/debug/hat_fit_check.gd` (modified)
- `scenes/debug/hat_fit_check.tscn` (modified)
- `tests/unit/test_art_sprites.gd` (modified)
- `tests/unit/test_horde_rush_level.gd` (modified)
- `tests/unit/test_hat_fit_check.gd` (modified)
- `tests/unit/test_catalogue.gd` (modified)
- `tests/unit/test_closet_item_tile.gd` (modified)
- `docs/art-style-sheet.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/9-1/` (new: gate1-overview, gate1-<hat> ×8, gate2-<hat> ×4, gate2-<hat>-horde-rush-brute-lane0-3x ×4, gate2-menu-witch, gate2-menu-witch-gray)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/9-1-eight-new-hats.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- 2026-10-13: Dev. Eight new hats drawn by the cosmetics tool (per-part even widths), wired into their `.tres` files with centred Closet icons while staying unavailable until 9.3. Height cap (18 px) tested against the Horde Rush brute in lane 0; fit check gains the size-class page. Both art gates approved by Smuck. Fixed a latent StringName sort in a Horde Rush test. 2040 tests green. Status → review.
