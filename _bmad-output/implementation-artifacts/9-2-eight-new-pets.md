---
baseline_commit: 9d498a4469d7a5584d717614e33dc61241a96610
---

# Story 9.2: Eight New Pets

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want lots of cute pets to keep me company while I type,
so that collecting feels fun.

## Acceptance Criteria

1. **Eight pet sheets (FR75, NFR10, NFR13).** The 8 remaining pets (Black cat, Spider, Orange cat, Bat, Crow, Wolf-dog, Floating eyeball, Brain buddy) are drawn by `tools/gen_cosmetics_art.gd` as horizontal strips of 32×32 frames at `assets/sprites/cosmetics/pets/pet_<name>_idle.png` (+ `.import`, Lossless, no mipmaps). Names: `pet_black_cat_idle.png`, `pet_spider_idle.png`, `pet_orange_cat_idle.png`, `pet_bat_idle.png`, `pet_crow_idle.png`, `pet_wolf_dog_idle.png`, `pet_eyeball_idle.png`, `pet_brain_buddy_idle.png` (they match the `.tres` ids). Each follows `docs/art-style-sheet.md`: palette only, hard alpha, 1 px `ink` outline, **2–6 frames, no two identical**, soles on **row 30 in every frame** (a bob or float moves the body, never the lowest row), never `candy-yellow`, `stamp-red` or `art-moon`.
2. **Cute, never scary (NFR10).** Every pet reads as a friendly cartoon for a 6-year-old: big round eyes or dot eyes, no teeth, fangs, claws, drool, blood, veins or bones. The **Floating eyeball** is a friendly one-eyed creature (a round chalk ball with one big iris and an eyelid blink), never a body part: no veins, no red, no optic nerve. The **Wolf-dog** is a puppy, not a wolf (floppy or soft ears, tongue out is fine, no snarl). The **Spider** has dot eyes and a smile, a round body and short legs. The **Brain buddy** is the game's cartoon brain (the `art-brain-pink` / `art-brain-shade` ramp) with tiny feet and dot eyes.
3. **Pet size (new, tested).** Every frame of every pet (the Cute ghost included) is between **`PET_MIN_HEIGHT` = 12** and **`PET_MAX_HEIGHT` = 22** px tall and at most **`PET_MAX_WIDTH` = 28** px wide (opaque extents), so it reads as a pet beside a 32 px zombie and keeps a gap inside the 32 px frame. The existing `test_ghost_is_pet_sized` (16–20) is generalised to all pets with these bounds; the ghost still passes. The numbers and their reason go into the style sheet.
4. **Data (FR75).** Each of the 8 existing `data/cosmetics/pet_*.tres` gets `pet_frames` (a `SpriteFrames` with one looping `idle` animation, one `AtlasTexture` per 32×32 frame, region `Rect2(i * 32, 0, 32, 32)`, **8–12 fps**, exactly like `pet_cute_ghost.tres`) and a Closet `icon` (see AC 5). Ids, display names, rows and prices stay as they are (row prices 100 / 200 / 300). **`is_available` stays `false` on all 8.** Story 9.3 switches the full catalogue on; until then the Closet keeps showing "Coming soon" for them.
5. **Closet icons centred (consistency with the hats).** Every pet's `icon` is an `AtlasTexture` of its idle sheet's **frame 0 cropped to its opaque pixels and padded back to 32×32**, centred (to within 1 px vertically when the height is odd; exactly when it is even). The **Cute ghost's icon is changed the same way** (data only: its PNG and frames are untouched), so all 9 pet tiles line up in the grid. Tested for all 9.
6. **Fits every slot (Epic 9 AC 2).** Each pet in the HUD pet slot (on the cushion, inside the 64 px column, clear of the target area and stats), on the report card (beside Professor Zombie, clear of the board, the stamp and the buttons), on the main menu (beside the zombie, inside the margin, clear of every control) and in the Crypt Closet preview (inside the mirror) fits and never covers the target or stats. The existing layout tests use the 32×32 frame rect, so they hold for any pet that stays in its frame; this story adds a data-driven test that every shipped pet's frames are 32×32 regions of a 32-px-high sheet, and checks the real look at Gate 2.
7. **Fit check shows every pet.** `scenes/debug/hat_fit_check.tscn` already cycles every catalogue pet with `pet_frames` (`_with_art`), so all 9 appear once wired. Add a **pet page** (or extend the pet area) that shows the chosen pet on all four backgrounds' worth of places a pet appears: the HUD cushion at 1× and 3× (today), plus the pet beside a 1× player zombie at the menu spacing (pet feet 36 px right of the zombie's) and beside Professor Zombie at the report-card spacing (his `%PetSlot` at (60, 30)), so Gate 1 can judge scale against the zombie.
8. **Approval gates.** Gate 1: Smuck approves the 8 sheets (fit-check screenshots at 3× on night and parchment, animated or as a frame strip) **before** they are wired into the `.tres` files. Gate 2: Smuck approves the in-game look (HUD cushion during a Zombie Run, report card beside the professor, main menu beside the zombie, Crypt Closet tiles and preview) for at least the Wolf-dog (largest), the Spider (smallest), the Bat or Crow (a flyer) and the Floating eyeball (the tone check). Each answer verbatim with the date in `## Art Approval`. The **Pet Fit Checklist** in Dev Notes is filled in pass/fail per pet.
9. **No regressions.** All 9 hat PNGs and `pet_cute_ghost_idle.png` are pixel-identical after rerunning the tool; the ghost's `pet_frames` is unchanged (only its `icon` changes); `PlayerData`, the save schema, `HatSlot`, `PetSlot`, `ClosetItemTile`, `CryptCloset`, `ProfessorZombie`, the HUD, the menu, the report card and every level script are unchanged. Full GUT suite green (baseline **2040** after 9.1; re-count at the start).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 9)
  - [x] 1.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the full suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count (2040 expected; the recount is authoritative). Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 1.2 Record the sha256 of all 9 hat PNGs and `pet_cute_ghost_idle.png` (they must not change in Task 2).

- [x] **Task 2: Draw the pets in the cosmetics tool** (AC: 1, 2, 3, 9) — `tools/gen_cosmetics_art.gd`
  - [x] 2.1 Add a `PET_LEGEND` (or extend `GHOST_LEGEND`; keep the ghost's output identical) whose values are all keys of `Proto.PALETTE`. Never `candy-yellow`, `stamp-red` or `art-moon`.
  - [x] 2.2 Draw each pet as frames of parts (`[map, top_row]`, every part even-width and centred by `_sheet_image`, exactly like the ghost: a head part that bobs and a feet/tail part that stays on row 30 is the cheapest way to animate without moving the soles). Keep a short `##` doc above each map: what it is, its size and how the idle moves. See **Pet design notes** below.
  - [x] 2.3 A pet-rules guard like `_hat_part_ok`: before writing a sheet, check each frame's lowest opaque row is 30, its height is within `PET_MIN_HEIGHT..PET_MAX_HEIGHT`, its width ≤ `PET_MAX_WIDTH`, 2–6 frames, and no two frames identical. `push_error` + no PNG + non-zero exit on a bad sheet (the 9.1 review asked the generator to enforce its own documented rules).
  - [x] 2.4 `_init()`: write the 8 new sheets after the ghost (a `NEW_PETS` dictionary like `NEW_HATS`). Output names as in AC 1.
  - [x] 2.5 Update the tool's header doc (Story 9.2, the pet size bounds, "soles on row 30 in every frame").
  - [x] 2.6 Run headless, then `--import`. Confirm the 9 hats and the ghost are byte-identical to 1.2. If bytes differ but pixels match, `git checkout` them; never commit a re-encoded approved PNG. Run the tool twice: the second run is byte-identical.

- [x] **Task 3: Art tests and the style sheet** (AC: 1, 2, 3)
  - [x] 3.1 `tests/unit/test_art_sprites.gd`: add the 8 paths to `SHEETS` with their frame counts (pets are character-sized sheets, so `test_characters_stand_on_row_30`, the outline rule, distinct/grounded frames and the import-settings loop cover them). Update the header doc. Check every test that counts sheets (`test_right_color_ramps_used`'s `sheets.size()` sum, etc.) still adds up.
  - [x] 3.2 Note `test_characters_stand_on_row_30` checks frame 0 only and `test_frames_not_empty_distinct_and_grounded` checks every frame against frame 0: together that is "row 30 in every frame". Keep both passing; don't add a duplicate.
  - [x] 3.3 `test_right_color_ramps_used` today asserts every `/cosmetics/pets/` sheet has `chalk` (written for the ghost). Replace it with per-pet signature colours (a small `PET_COLOURS: Dictionary[String, Array]` path → palette hexes, one entry per pet, the ghost keeping chalk). Don't just delete the chalk check: a black cat with chalk eye highlights still passes, a brain buddy may not, so make it per pet.
  - [x] 3.4 Replace `test_ghost_is_pet_sized` with `test_pets_are_pet_sized`: consts `PET_MIN_HEIGHT` 12, `PET_MAX_HEIGHT` 22, `PET_MAX_WIDTH` 28 (each with a `##` reason), every frame of every pet sheet. Add one test: no pet uses `candy-yellow`, `stamp-red` or `art-moon` (like the hats').
  - [x] 3.5 Every pet sheet's fps lives in its `.tres` (8–12, AC 4); assert it in `tests/unit/test_pet_slot.gd` (generalise `test_shipped_cute_ghost_frames` to every shipped pet with frames: `idle` exists, loops, frame count = the sheet's frame count from the PNG width / 32, speed in [8, 12], region `Rect2(i * 32, 0, 32, 32)`, atlas is `pet_<id-without-prefix>_idle.png`).
  - [x] 3.6 `docs/art-style-sheet.md`: section 1 (Epic 9: Story 9.2), section 3 table (one row per new sheet: `pet <name> idle` (9.2) | frames | 32×32 | fps | loop (what moves)), the Pets paragraph (size bounds and why, soles on row 30 in every frame, floaters keep a shadow or tail on row 30, the Closet icon is frame 0 cropped and centred), section 5 (kid-safe: the eyeball is a creature, not a body part; puppy not wolf; no fangs or claws). Fix the stale "Later epics (9, 10)" line if it still reads oddly. Keep rule text that tests quote in step with the tests.

- [x] **Task 4: Fit check pet views** (AC: 7)
  - [x] 4.1 `scripts/debug/hat_fit_check.gd`: add the pet-beside-zombie and pet-beside-professor views (AC 7). Build them from the real scenes (`player_zombie.tscn` stopped on idle 0 with the current hat; `professor_zombie.tscn`, whose own `%PetSlot` today is detached and hidden, so here set it `follow_equipped = false` and `show_item(current_pet())`). Spacings: read the menu offset from `main_menu.tscn` (zombie at (48, 284), pet at (84, 284) → +36 px) and the professor's `%PetSlot` position from the professor scene rather than new literals where you can; if a literal is unavoidable, name it with a `##` doc saying where it comes from.
  - [x] 4.2 Register every new `PetSlot` in `_pet_slots` so `cycle_pet()` and `_show_pet()` drive them. Keep H/P/B/N/E/Esc, the hat cells, the size-class page, paging, the seams and Boundary 7. Update the class doc and keep the existing note that E only wears available items (unavailable pets now warn "could not buy" like the hats; correct until 9.3).
  - [x] 4.3 `tests/unit/test_hat_fit_check.gd`: the pet cycle visits exactly the 9 catalogue pets in grid order, then none; every pet slot in the scene shows the current pet; the new views' pets sit at the expected offset from their zombie/professor; `test_cycling_never_crashes` stays at zero warnings; fix any test that assumes the ghost is the only pet (cycle until null, capped at 100 iterations, as 9.1 did for hats).

- [x] **Task 5: Gate 1: the sheets** (AC: 8) — **don't touch the `.tres` files before this passes**
  - [x] 5.1 Run the fit check with a scratch catalogue (a scratch script in the scratchpad that duplicates `catalogue.tres` item by item, since a deep duplicate shares external resources, gives each new pet a `SpriteFrames` built from its new PNG, and instances `hat_fit_check.tscn` with that catalogue before `add_child`). Never write the real `user://save.json` (record its sha256 before/after).
  - [x] 5.2 Capture (real window, not `--headless`) per pet: the cushion at 1× and 3×, beside the zombie and beside the professor, on `night` and `parchment`, plus a frame strip at 4× so every idle frame is visible in a still image. Save to `_bmad-output/implementation-artifacts/screenshots/9-2/gate1-<pet>.png` and one `gate1-overview.png` (all 9 pets side by side at 3×, frame 0, so their sizes compare).
  - [x] 5.3 Show Smuck. Ask specifically: approve all 8 or name redraws; is the eyeball cute enough; is the wolf-dog clearly a puppy. Record the verbatim answer with the date in `## Art Approval`. Redraw in the tool only what Smuck asks for, regenerate, re-show.

- [x] **Task 6: Wire the data** (AC: 4, 5)
  - [x] 6.1 For each of the 8 `pet_*.tres`: add the PNG `ext_resource` (uid from the `.import` file, as in `pet_cute_ghost.tres`), one `AtlasTexture` per frame, a `SpriteFrames` sub-resource with `idle` (loop true, the chosen fps), the `icon` `AtlasTexture` (frame 0's `get_used_rect()` as `region`, a `margin` padding it to 32×32 centred), `pet_frames = SubResource(...)`, `icon = SubResource(...)`, and fix `load_steps`. **Keep `is_available = false`.** Simplest route: a scratch tool that builds them and `ResourceSaver.save()`s, then diff the `.tres` text and hand-tidy ids to match the ghost's style (`AtlasTexture_idle_<i>`, `AtlasTexture_icon`, `SpriteFrames_<name>`). LF endings.
  - [x] 6.2 `pet_cute_ghost.tres`: change only `AtlasTexture_icon` (region = frame 0's used rect, plus a centring margin). Its frames, fps, id, price and `is_available = true` stay as they are.
  - [x] 6.3 `tests/unit/test_catalogue.gd`: in `test_shipped_mvp_items_have_art` replace the "unavailable pets have no art (Story 9.2)" loop with: every pet has `pet_frames` with an `idle` and a 32×32 `icon`; no pet has an `overlay`. Add `test_pet_icons_are_centred` (mirrors `test_hat_icons_are_centred`: atlas is the pet's idle sheet, region = frame 0's used rect, icon size 32×32, `abs((margin.position * 2 + region.size) - (32, 32))` ≤ (0, 1) — exact horizontally, within 1 px vertically). `test_shipped_only_mvp_items_are_available` stays exactly as it is (the guard that 9.2 switches nothing on).
  - [x] 6.4 `tests/unit/test_closet_item_tile.gd` / `test_crypt_closet.gd`: nothing should break. Add one test (or extend 9.1's hat one) that a shipped unavailable **pet** with an icon still renders `LOCKED` with `%Art` hidden, and that the Closet preview never shows an unavailable pet on focus (`crypt_closet.gd` previews only available items; pin it).
  - [x] 6.5 Data-driven slot test (AC 6): for every shipped pet, its `pet_frames` `idle` frames are 32×32 `AtlasTexture` regions of a sheet exactly 32 px high (`test_pet_slot.gd` or `test_catalogue.gd`). Together with the 32×32 frame-rect layout tests in `test_hud.gd`, `test_report_card.gd` and `test_main_menu.gd`, this is the "fits the slot" guarantee.

- [x] **Task 7: Gate 2: in-game check** (AC: 6, 8)
  - [x] 7.1 Scratch capture script (pattern: `tools/capture_screens.gd` and the 9.1 gate-2 script; temp `SaveService` dir; record `user://save.json` sha256 before/after). Because the pets are unavailable, `PlayerData.get_equipped()` filters them out: inject a `PlayerData` whose `catalogue` is a per-item duplicate of the shipped one with `is_available = true` on the pets (test seam). Never edit the shipped `.tres` for this.
  - [x] 7.2 Shots for at least the Wolf-dog, Spider, Bat or Crow and the Floating eyeball (others optional): HUD during a Zombie Run (pet on the cushion, animating, clear of the target sign and stats; a 3× crop of the pet column), report card (beside the professor, clear of the board, stamp and buttons), main menu (beside the zombie wearing a hat), Crypt Closet (the 9 pet tiles with all pets available in the copy: icons centred and lined up; the preview mirror with the pet). Also one Pitchfork Panic HUD shot on the Moonlit Village (the night setting; the cushion is parchment, but check the pet is not lost). Save under `screenshots/9-2/gate2-*.png`, plus one grayscale copy of the HUD shot (`tools/capture_screens.gd -- --convert <png>`).
  - [x] 7.3 Fill in the **Pet Fit Checklist**. Show Smuck; record the verbatim answer with the date in `## Art Approval`.

- [x] **Task 8: Verification and wrap-up** (AC: 9)
  - [x] 8.1 `--import`, full suite; record before/after counts; grep for `Parse Error|Compile Error|Failed to load script`; report new warning counts honestly.
  - [x] 8.2 Mutation pass (the project habit): lift one pet frame's soles to row 29; make a pet 23 px tall; make two frames identical; put `candy-yellow` in a pet; give a pet 7 frames; set one pet `is_available = true`; break one pet icon's margin; set a pet's fps to 6; drop a pet from `SHEETS`; make the fit check's new view ignore `current_pet()`. Each should be caught (by the tool's guard or a test). Report honestly any that survive and close the gap.
  - [x] 8.3 `deferred-work.md`: add "Deferred from: dev of story-9.2" with what is left (at least: the pets become buyable in 9.3; anything accepted at a gate). Mark nothing resolved unless this story resolved it.
  - [x] 8.4 Update this file's Dev Agent Record and File List; `sprint-status.yaml` 9-2 → `review`.

### Review Findings

- [x] [Review][Patch] Style sheet says Closet icon is centred "exactly across", but cats' frame 0 is 17 px wide and the test allows 1 px off [docs/art-style-sheet.md, tests/unit/test_catalogue.gd:949]
- [x] [Review][Dismissed] (false positive: test_frames_not_empty_distinct_and_grounded already checks every frame) Soles-on-row-30 is only tested on frame 0, though docs claim every frame; assert it per frame (e.g. in test_pets_are_pet_sized) [tests/unit/test_art_sprites.gd:426]
- [x] [Review][Patch] Floating eyeball frames 2-3 hover 1 px above the shadow; style sheet says 2-3 px. Redraw at row 14 or change the doc to "1-3 px" [tools/gen_cosmetics_art.gd:1735, docs/art-style-sheet.md]
- [x] [Review][Patch] Fit check Menu/Report views are parented to the root, not a page, so they show on every page and can overlap cells [scripts/debug/hat_fit_check.gd:376]
- [x] [Review][Patch] _menu_pet_offset treats a node with no saved `position` as missing; default to Vector2.ZERO [scripts/debug/hat_fit_check.gd:677]
- [x] [Review][Patch] test_shipped_pet_frames no longer pins the ghost's 4 frames and 8 fps; restore the old strict check for it [tests/unit/test_pet_slot.gd:1186]
- [x] [Review][Patch] Stale comment points at nonexistent test_pet_colours (it is test_right_color_ramps_used) [tests/unit/test_art_sprites.gd:435]
- [x] [Review][Patch] Orange-cat recolour test skips frame 3 (ear flick); assert it differs from the Black cat only in the ear rows [tests/unit/test_art_sprites.gd:859]
- [x] [Review][Defer] Cat frame 0 is 17 px wide, so Closet icon is 1 px off across (already logged in deferred-work.md) — deferred, pre-existing
- [x] [Review][Defer] Closet/focus tests only cover the unavailable-pet path; pets become available in Story 9.3 — deferred, belongs to 9.3
- [x] [Review][Defer] Black cat blink only drops the glint (reads as no closed eye); art was approved at Gate 1 — deferred, cosmetic

## Dev Notes

### What this story is (and isn't)

- **Is:** 8 pet idle sheets drawn in the existing cosmetics tool, their data (`pet_frames` + Closet icon) in the existing `.tres` files, a re-centred Cute ghost icon, art tests and the style sheet updated, a pet size rule, fit-check pet views beside the zombie and the professor, two art gates.
- **Isn't:** making the pets buyable (the `is_available` flip is **Story 9.3**, with its save-compatibility check). Any change to `PlayerData`, the save, `PetSlot`, `HatSlot`, `ProfessorZombie`, `ClosetItemTile`, `CryptCloset`, the HUD, the menu, the report card or any level. Pet animations other than `idle` (no walk, react or "happy on correct key"). Pet sounds. Moving or resizing the cushion or any slot.

### What already works (do not rebuild it)

- **The display system is done (4.3) and pet-agnostic.** `PetSlot` (`scripts/cosmetics/pet_slot.gd`) plays `pet_frames`'s `idle` with `%Pet` at (−16, −31), so the sheet's row 30 lands on the node origin (the feet). It follows `PlayerData.equipment_changed` itself and warns once, hides and carries on for a missing `pet_frames` or `idle` (NFR16). Any sheet that follows the soles rule fits every slot with no code change.
- **Where pets appear** (all `pet_slot.tscn`, feet at the node position, frame = feet + (−16, −31) .. +32×32):
  - HUD: `scenes/run/hud.tscn` `%PetSlot` column Rect2(0, 256, 64, 104), `%PetCushion` (8, 300, 48, 48), `%Pet` at (32, 80) in the column → feet (32, 336), frame x 16–48, y 305–337. Tested by `test_hud.gd::test_pet_sits_on_the_cushion` (frame inside the 64 px column, feet on the cushion). The target area starts at x 64.
  - Report card: `professor_zombie.tscn` `%PetSlot` at (60, 30) from the professor; feet y 300. `test_report_card.gd::test_pet_stands_clear_of_the_board_stamp_and_buttons`.
  - Main menu: `main_menu.tscn` zombie at (48, 284), `%PetSlot` at (84, 284). `test_main_menu.gd::test_hat_and_pet_overlap_nothing`. The zombie's frame is x 32–64 and the pet's x 68–100: a 28 px-wide pet leaves 2 px each side of its frame, so the zombie and the pet never touch.
  - Crypt Closet preview: `%PreviewPet` at (338, 188), `follow_equipped = false`, shown only for available items (`crypt_closet.gd:~262–268`); the mirror panel is about 244–396 × 76–196.
- **The Closet** shows `item.icon` in `%Art` only when the tile isn't `LOCKED`; a locked tile shows `%Question` and "Coming soon". So new icons are invisible to kids until 9.3 (9.1 pinned this for hats; Task 6.4 pins it for pets).
- **`PlayerData.buy_item` returns `UNAVAILABLE`** and `get_equipped` filters unavailable ids. That's why Gate 2 needs an injected catalogue (Task 7.1), and why the fit check's E warns "could not buy" on new pets (correct).
- **The fit check cycles pets with art** (`_with_art`: `pet_frames != null`), so all 9 appear in it once wired (Gate 1 needs the scratch catalogue because the shipped data isn't wired yet).

### Existing code: current state, what changes, what must be preserved

- `tools/gen_cosmetics_art.gd` (UPDATE). ASCII maps, one char per pixel, `.` transparent, legend char → palette **name** from `Proto.PALETTE` (`tools/gen_art_prototypes.gd`). `_sheet_image(frames, legend)` builds a strip of 32×32 frames; each frame is a list of `[map, top_row]` parts, each part's rows share one **even** width and are centred at x `(32 − w) / 2`. The ghost is built by `_ghost_frames()` from a head that bobs (`GHOST_TOPS` 12/13/12/13), filler body rows and two tail phases on rows 28–30. Change: a pet legend, 8 pet builders, `NEW_PETS`, a pet guard. Preserve: every hat map and output, the ghost map and output, the error paths, the non-zero exit, `Proto` as the only colour source.
- `data/cosmetics/pet_{black_cat,spider,orange_cat,bat,crow,wolf_dog,eyeball,brain_buddy}.tres` (UPDATE). Today: script, id, display_name, slot 1, price, row, `is_available = false`, no art. Change: `pet_frames`, `icon`. Preserve: ids (permanent once shipped: note `pet_eyeball` and `pet_wolf_dog`, not "floating_eyeball"/"wolfdog"), names, prices, rows, `is_available = false`.
- `data/cosmetics/pet_cute_ghost.tres` (UPDATE, icon only).
- `data/cosmetics/catalogue.tres` (READ ONLY). Already lists all 18 in grid order: ghost, black cat, spider / orange cat, bat, crow / wolf-dog, eyeball, brain buddy.
- `scripts/debug/hat_fit_check.gd` (+ `.tscn` if an export is added) (UPDATE, Task 4).
- `tests/unit/test_art_sprites.gd`, `test_catalogue.gd`, `test_pet_slot.gd`, `test_hat_fit_check.gd`, `test_closet_item_tile.gd` or `test_crypt_closet.gd` (UPDATE).
- `docs/art-style-sheet.md` (UPDATE, Task 3.6).
- **Must not change:** `scripts/autoloads/*`, `scripts/cosmetics/*`, `scripts/characters/*`, `scripts/ui/*`, `scripts/screens/*`, `scripts/levels/*`, `scenes/run/hud.tscn`, `scenes/screens/*`, `scenes/characters/*`, `scenes/cosmetics/*`, `data/anchors/*`, `data/levels/*`, the save schema, `project.godot`, every hat PNG and `.tres`.

### Pet geometry (the 4.3 convention, plus this story's rules)

- A horizontal strip of 32×32 frames, 2–6 frames, 8–12 fps (the ghost: 4 frames at 8 fps). Soles (the lowest opaque row) on **row 30 in every frame**; row 31 empty. The idle moves the body (a 1 px bob, a blink, a tail flick, wing flaps), never the lowest row.
- **Size:** 12–22 px tall, ≤ 28 px wide, every frame. The ghost is 14 wide and 18–19 tall. Aim small pets (spider, bat, crow, eyeball, brain buddy) at about 12–16 tall, cats at about 16–18, the wolf-dog at about 18–22 and up to about 24 wide. The zombie is about 30 tall, so even the biggest pet is clearly smaller.
- **Facing:** `PetSlot` never flips. On the HUD the target is to the pet's right; on the menu and the report card the zombie/professor is to its **left**. Draw pets facing the viewer or three-quarter facing **left** (toward the zombie on the menu and report card, where a kid looks at them longest); Smuck decides at Gate 1.
- **Floaters** (Bat, Floating eyeball; optionally the Crow mid-hop): the soles rule still applies. Either keep a small ink-only shadow on row 30 (a 1-row ink dash, 6–10 px; all-ink, so the outline rule holds) with the body hovering 2–4 px above it and bobbing, or give it a ghost-style wisp tail touching row 30. A perched bat (wings folded, flapping open and shut, feet on row 30) is also fine.
- **Odd heights:** the Closet icon centres exactly only for an even opaque height of frame 0; within 1 px is accepted for pets (the ghost's frame 0 is 19 rows). Widths are even by construction (the generator centres even-width parts).
- **Outline rule (tested):** every opaque non-`ink` pixel has 4 opaque orthogonal neighbours, so the silhouette edge is ink everywhere, including spider legs (draw legs ink-only), whiskers (ink-only), the gap between a cat's ears and the bat's wing fingers.

### Pet design notes (suggestions; Smuck decides at Gate 1)

Palette only. **Banned in pets (tested):** `candy-yellow` (focus only), `stamp-red` (the stamp only), `art-moon` (the moon only). "Red-ish" uses `pumpkin` or the brain ramp (`art-brain-pink` #F29AB8 / `art-brain-shade` #C9607F). Eyes: `chalk` whites with an `ink` pupil, or `ink` dots; a `chalk` glint reads well on dark pets. Cheeks: `art-brain-pink`. Every pet must read on the **parchment** cushion (the HUD), the **chalkboard** (report card) and **night** (menu): dark pets (black cat, bat, crow, spider) need a lighter inner shade or highlight so they aren't an ink blob, and the ink outline must still separate them from the night backdrop.

| Pet | id | Row/price | Ideas | Idle (2–6 frames) |
|---|---|---|---|---|
| Black cat | `pet_black_cat` | 1 / 100 | Sitting cat; `ink-muted` body with `dusk` shade (not pure ink, so the outline reads), big `chalk`/`zombie-green-bright` eyes, `art-brain-pink` nose and inner ears, a curled tail. | Tail sway + one blink |
| Spider | `pet_spider` | 1 / 100 | Round `bat-purple` body with `dusk` shade, 2 big chalk eyes with ink pupils and a smile, 6–8 short **ink-only** legs (stubby, never long or hairy). Smallest pet (~12 tall). | Body bob 1 px, legs alternate (a little tap dance) |
| Orange cat | `pet_orange_cat` | 2 / 200 | Same pose as the black cat (share the mask: a legend swap is cheap and consistent) in `pumpkin` / `pumpkin-light` with `wood` stripes, `chalk` muzzle and chest. | Tail sway + ear flick |
| Bat | `pet_bat` | 2 / 200 | Round fuzzy `bat-purple` body, `dusk` wings, big chalk eyes, tiny `chalk` (not sharp) tooth-free smile; floater shadow or perched. | Wing flap (up, mid, down, mid) |
| Crow | `pet_crow` | 2 / 200 | Plump round `ink-muted` crow with `stone` wing highlight, `pumpkin-light` beak and feet, a chalk eye glint. | Head bob/peck + a hop pose (soles stay on row 30) |
| Wolf-dog | `pet_wolf_dog` | 3 / 300 | A puppy: sitting, `stone` / `stone-light` coat with `chalk` muzzle and chest, soft ears (one flops), `art-brain-pink` tongue out, a wagging tail. Largest pet. | Tail wag + panting tongue |
| Floating eyeball | `pet_eyeball` | 3 / 300 | A round `chalk` ball with `stone-light` shade, one big iris (`zombie-green` or `bat-purple`) with an ink pupil and a chalk glint, maybe tiny `bat-purple` wings or a ghost-style wisp tail. **No veins, no red, no stalk.** | Float bob + a blink (eyelid in `stone-light` closing) |
| Brain buddy | `pet_brain_buddy` | 3 / 300 | The game's cartoon brain (the brain-block ramp `art-brain-pink` / `art-brain-shade`, ink folds) on two tiny `zombie-green` or `ink` feet, dot eyes, a smile. It's "a tiny walking brain" (GDD). | Walk in place: feet alternate, body bobs |

Keep the pets in the same family as the ghost and the zombie: chunky 1 px ink outline, flat fills with one shade, dot or big round eyes, no fine detail that disappears at 1×.

### Pet Fit Checklist (fill in during Tasks 5 and 7; pass/fail per pet)

Columns: Black cat · Spider · Orange cat · Bat · Crow · Wolf-dog · Eyeball · Brain buddy.

| # | Check | What to look for |
|---|---|---|
| 1 | Soles | Feet (or shadow/tail) on row 30 in every frame; the pet doesn't jump between frames |
| 2 | Size | Clearly a pet beside the 32 px zombie; in the size bounds (tested) |
| 3 | Outline | 1 px ink all round; legs, whiskers, ear gaps and wings outlined; no double-thick blob |
| 4 | Idle | 2–6 frames, reads as alive (blink, wag, flap, bob), not jittery at 8–12 fps |
| 5 | HUD | On the cushion, inside the 64 px column, clear of the target sign and stats |
| 6 | Report card | Beside the professor, clear of the board, the stamp and the buttons |
| 7 | Menu | Beside the zombie (with a hat on), inside the margin, not touching the zombie or any control |
| 8 | Closet | Icon cropped and centred in its tile, lines up with the other 8 pets; preview inside the mirror |
| 9 | Backgrounds | Readable on parchment (cushion), chalkboard, night and the Moonlit Village |
| 10 | Kid-safe | Cute, never scary; no teeth, fangs, claws, veins, blood or bones; the eyeball is a creature |

**Results** (Gate 1 fit check 2026-10-14, Gate 2 in-game shots 2026-10-14; P = pass):

| # | Black cat | Spider | Orange cat | Bat | Crow | Wolf-dog | Eyeball | Brain buddy |
|---|---|---|---|---|---|---|---|---|
| 1 Soles | P | P | P | P (shadow) | P | P | P (shadow) | P |
| 2 Size | P 17×18 | P 22×13–14 | P 17×18 | P 28×14–15 | P 20×16–17 | P ≤22×19 | P 20×16–17 | P 16×13–14 |
| 3 Outline | P | P (filled legs) | P | P | P | P | P | P |
| 4 Idle | P tail + blink | P bob + tap | P tail + ear | P flap 10 fps | P squat, blink, tail | P wag + pant 10 fps | P flap + blink | P walk in place |
| 5 HUD | P | P | P | P | P | P | P (also Pitchfork Panic) | P |
| 6 Report card | P | P | P | P | P | P | P | P |
| 7 Menu | P | P | P | P | P | P | P | P |
| 8 Closet | P | P | P | P | P | P | P | P |
| 9 Backgrounds | P (lighter fill and dusk shade read on night) | P | P | P | P | P | P | P |
| 10 Kid-safe | P | P | P | P (no fangs) | P | P (puppy) | P (creature, cheeks + smile) | P (cartoon brain) |

Gate 2 shots for all eight: `screenshots/9-2/gate2-<pet>-hud-zombie-run.png` (+ `-hud-pet-column-3x`), `-report-card`,
`-main-menu`, `-closet`; `gate2-eyeball-hud-pitchfork-panic.png` (+ column crop); `gate2-wolf_dog-hud-zombie-run-gray.png`.

### Testing notes

- Suite and import commands as in Task 1. Run `--import` after the new PNGs exist and before tests (the `.tres` uid references and `test_import_settings_lossless_no_mipmaps` need the `.import` files).
- Art tests read the committed PNG bytes (`Image.load_from_file`), so import state doesn't matter for them; the `.tres` tests do need the import.
- Never write the developer's real save: inject a temp-dir `SaveService` + `PlayerData` (patterns: `test_pet_slot.gd`, `test_hat_fit_check.gd before_each`, `test_crypt_closet.gd`). For "available" behaviour, duplicate the shipped catalogue per item and flip `is_available` on the copy.
- `test_hud.gd` and `test_report_card.gd` use the live `PlayerData` autoload (deferred-work 4.3): a pet equipped in the dev machine's save can change their results. Nothing here should need it, but if a layout test flakes, check the real save first.
- Sort `String`s, never `StringName`s (they compare by interned pointer; 9.1 hit this).
- GUT is 9.7.1; `assert()` shows as `SCRIPT ERROR` in headless GUT, so use `Log` + safe returns in tools and scenes; `push_error` + non-zero exit in tools.

### Previous story intelligence

- **9.1 (the hats, same epic, same tool):** per-part even widths centred by `_sheet_image`; a scratch helper that adds the ink ring and checks the rules before maps go into the tool saved a lot of redraws; Gate 1 with a scratch catalogue (copy each item, since a deep duplicate shares external resources); Gate 2 with an injected `PlayerData` whose catalogue has the items available; the save's sha256 recorded before/after both gates; per-item signature-colour tests; "every X is in the test's list" assertion added after a mutation survived; review asked the generator to enforce its own rules (Task 2.3 here). Its icons are an `AtlasTexture` cropped to the used rect with a centring margin (Task 6 follows that). Final count 2040.
- **4.3 (the display system):** the pet convention (feet at the node, soles row 30), the ghost's float (head bob, tail phases), "warn once, hide, carry on", the fit-check scene and checklist format, art approval verbatim with a date.
- **4.4 / 5.0 (Closet):** the ghost's icon is idle frame 0 uncropped (`region = Rect2(0, 0, 32, 32)`); hats were re-centred in 5.0 ("the pumpkin sits low"). This story brings the pets in line (AC 5).
- **8.6 / 8.7:** GUT silently skips a script that fails to parse (8.6 shipped a skipped test file): always grep the log. One commit per story with code review patches applied.
- **Traps from earlier stories:** keep files LF (`.gitattributes eol=lf`). Write `×`/`–` as UTF-8. Prefer scratchpad scripts over shell heredocs with apostrophes. `untyped_declaration = Error` applies to tools too (type every `for` variable). The flaky `test_audio_manager` pool test (deferred-work 4.2): rerun once before investigating.

### Git intelligence

- Recent commits: `9d498a4 Story 9.1: eight new hats, code review patches applied, done`, `9f382be Story 8.7: chase tuning…`, `a00b096 Story 8.6: moonlit village…`. Each story ships code, art, tests, screenshots, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- 9.1's diff touched `tools/gen_cosmetics_art.gd`, 8 PNG + `.import`, 8 `.tres`, the fit check, 5 test files, the style sheet and `screenshots/9-1/`; expect the same shape here.
- Untracked `screenshots/8-7/*.jpg.import` files are in the working tree from an earlier session; leave them out of this story's commit unless Smuck says otherwise.
- Suggested message: `Story 9.2: eight new pets`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries. Godot **4.7.2** standard, Compatibility renderer, GDScript only, statically typed.
- `SpriteFrames` in a `.tres`: `animations = [{ "frames": [{ "duration": 1.0, "texture": SubResource(...) }, ...], "loop": true, "name": &"idle", "speed": 8.0 }]` (copy the ghost's block). Keep every frame `duration` 1.0 (the style sheet forbids duration multipliers to get below 8 fps).
- `AtlasTexture.margin` adds transparent padding: `get_size()` = `region.size + margin.size`. Centring: `margin = Rect2(pad, pad_size)` with `margin.position = (32 − region.size) / 2` (floored) and `margin.size = 32 − region.size` so `get_size()` = 32×32.
- `Image.save_png()` is deterministic for the same pixels; reruns should be byte-identical.
- A `.tres` `ext_resource` for a PNG should carry the uid from its `.import` file (`uid="uid://…"`), as `pet_cute_ghost.tres` does.

### Project Structure Notes

- All paths follow the architecture's Directory Structure and naming (`assets/sprites/cosmetics/pets/pet_<name>_idle.png`, `data/cosmetics/<id>.tres`, debug code only under `scenes/debug/` / `scripts/debug/`, generators under `tools/`).
- Variance: none. The pet views in the fit check are new but stay in the debug scene.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Typed GDScript everywhere (`untyped_declaration = Error`), tabs, short `##` docs that say why, LF endings.
  - Static data comes through `@export` Resources (`data/` instances, `scripts/resources/` definitions); no GDD number as a literal in a script.
  - `%UniqueName` node refs; no `/root/` paths or `get_parent()` chains.
  - Debug code only in `scenes/debug/` / `scripts/debug/` (Boundary 7).
  - Art follows the style sheet (32-colour palette, ink outline, hard alpha, Lossless, no mipmaps), is code-generated by a `tools/` script, and is never hand-edited. Final art waits for Smuck's approval recorded in the story file.
  - NFR10: kid-safe cartoon only, no gore, blood or body-part gags; goofy, never scary for a 6-year-old.
  - NFR16: a missing cosmetic logs a warning and never stops a run (already handled by `PetSlot`).
  - Saves store item ids; ids are permanent once shipped.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Epic 9: Full Crypt Closet, Story 9.2: Eight New Pets, Story 9.3: Full Catalogue Live]; FR43, FR75; NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] cosmetic slots (~l.150: the pet sits in the HUD next to the target with an idle animation, also on the report card), Crypt Closet price table (~l.280–284: Brain buddy "a tiny walking brain"), MVP cosmetics (~l.409: Cute ghost idle float 4f)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] pet-slot (no chrome, idles on a parchment cushion, `hud-pet-slot-width` 64 px), HUD band layout
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] band hierarchy (pet: delight, left side, idle only), pet-slot behaviour
- [Source: docs/art-style-sheet.md] §1 gate rule, §2 palette, §3 sprite rules, animation limits and the Pets paragraph, §5 kid-safe rules
- [Source: _bmad-output/implementation-artifacts/9-1-eight-new-hats.md] the tool changes, gates, icon centring, review findings
- [Source: _bmad-output/implementation-artifacts/4-3-hat-and-pet-display-everywhere.md] pet convention, fit-check checklist format
- [Source: _bmad-output/implementation-artifacts/4-4-crypt-closet.md] AC 9 (tile art: the ghost's frame-0 icon)
- [Source: tools/gen_cosmetics_art.gd _ghost_frames/_sheet_image/_hat_part_ok/NEW_HATS], [tools/gen_art_prototypes.gd PALETTE], [scripts/cosmetics/pet_slot.gd], [scripts/debug/hat_fit_check.gd _with_art/_build_pet/_add_professor_cell], [scripts/screens/crypt_closet.gd:~262–268], [scenes/run/hud.tscn PetSlot/PetCushion/Pet], [scenes/screens/main_menu.tscn Zombie/PetSlot], [scenes/characters/professor_zombie.tscn PetSlot], [scenes/screens/crypt_closet.tscn PreviewPet], [data/cosmetics/pet_cute_ghost.tres], [tests/unit/test_art_sprites.gd SHEETS/test_right_color_ramps_used/test_ghost_is_pet_sized/test_characters_stand_on_row_30], [tests/unit/test_catalogue.gd test_shipped_mvp_items_have_art/test_hat_icons_are_centred], [tests/unit/test_pet_slot.gd test_shipped_cute_ghost_frames], [tests/unit/test_hud.gd test_pet_sits_on_the_cushion], [tests/unit/test_report_card.gd test_pet_stands_clear_of_the_board_stamp_and_buttons], [tests/unit/test_main_menu.gd test_hat_and_pet_overlap_nothing]

## Art Approval

<!-- Gate 1 (the 8 sheets, before wiring) and Gate 2 (in game): Smuck's answers verbatim with the date. -->

**Gate 1 (the 8 sheets, 2026-10-14):** shown `screenshots/9-2/gate1-overview.png` and `gate1-<pet>.png` for the eight
new pets (fit check at 1× and 3× on night and parchment, beside the zombie and the professor, every idle frame at 4×).
Smuck: "i approve all 8"

**Gate 2 (in game, 2026-10-14):** shown `screenshots/9-2/gate2-*.png` (HUD on Zombie Run and Pitchfork Panic, report card,
main menu, Crypt Closet, for all eight pets; the Wolf-dog, Spider, Bat, Crow and Floating eyeball among them).
Smuck: "i approve the in-game look"

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): `--import`, full GUT suite 2040/2040, 0 `Parse Error|Compile Error|Failed to load script`, 3 `SCRIPT ERROR` lines and 160 `WARNING` lines (all pre-existing). sha256 of the 9 hat PNGs, `pet_cute_ghost_idle.png` and `user://save.json` recorded.
- Pets drawn first in a scratch Python previewer (same centring as `_sheet_image`, plus the outline, soles, size and distinct-frame checks), iterated against renders on parchment, night and chalkboard, then the maps were emitted into the tool as GDScript consts. The tool's PNGs were compared to the previews pixel for pixel (all 8 match).
- Generator run twice: the second run is byte-identical; the 9 hats and the ghost are byte-identical to the baseline.
- `-s` scratch capture scripts compile before the autoloads exist: Gate 1 drove the fit check dynamically (`call`/`set`), Gate 2 used a launcher that loads the runner Node at runtime (the `tools/capture_screens.gd` pattern).
- Working copies are CRLF here (`core.autocrlf=true`; `.gitattributes` `eol=lf` normalises on commit); scripted edits normalised line endings before matching.
- First full run after wiring: 1 failure, `test_pet_icons_are_centred` for the two cats (frame 0 is 17 px wide, so the floor-margin icon is 1 px off across). Resolved by testing "exact along an even side, within 1 px along an odd one" both ways (see Completion Notes); approved art untouched.
- Final (Task 8.1): `--import`, full suite **2049/2049** (2040 + 9: `test_ghost_is_pet_sized` replaced by `test_pets_are_pet_sized`, plus `test_every_pet_sheet_is_listed`, `test_pets_never_use_reserved_colours`, `test_orange_cat_is_a_recoloured_black_cat`, `test_pet_cycle_visits_every_catalogue_pet_in_grid_order`, `test_menu_and_report_views_stand_at_the_scene_spacings`, `test_pet_icons_are_centred`, `test_a_shipped_unavailable_pet_with_an_icon_stays_hidden`, `test_focusing_an_unavailable_pet_with_art_never_previews_it`, `test_every_shipped_pet_frame_is_a_32px_cell`; `test_shipped_cute_ghost_frames` generalised to `test_shipped_pet_frames`). 0 parse/compile/load errors; `SCRIPT ERROR` 3 and `WARNING` 160, both unchanged from the baseline.
- `user://save.json` sha256 `2859cbaa…647a` before and after both gates and the whole story.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- **Art (AC 1, 2, 3):** `tools/gen_cosmetics_art.gd` draws the 8 pets from ASCII part maps (`PET_LEGEND`, `ORANGE_CAT_LEGEND`, `NEW_PETS` name -> [frames, legend]), 4 frames each, soles (or a floater's 10 px ink `FLOAT_SHADOW`) on row 30 in every frame. Sizes: Black/Orange cat 17-18×18, Spider 22×13-14, Bat 28×14-15, Crow 20×16-17, Wolf-dog up to 22×19, Floating eyeball 20×16-17, Brain buddy 16×13-14. The Orange cat is the Black cat's maps with a legend swap (stripes are an `x` that is invisible ink-muted on the black cat). Thin parts (spider legs, tails) are filled, not ink-only, so they read on night. No candy-yellow, stamp-red or art-moon.
- **Generator guard (Task 2.3):** `_pet_sheet_ok` checks 2-6 frames, no repeated frame, and per frame the soles on row 30, 12-22 tall and <= 28 wide; `push_error`, no PNG and a non-zero exit on failure. It also runs on the ghost (which passes; its PNG is unchanged).
- **Data (AC 4, 5):** each `pet_*.tres` has its idle `SpriteFrames` (looping, every frame duration 1.0; 8 fps, the Bat and Wolf-dog 10 fps) and an `AtlasTexture_icon` of frame 0 cropped to its used rect with a centring margin; ids, names, rows, prices and `is_available = false` unchanged. The Cute ghost changes only its icon (region (9, 12, 14, 19), margin (9, 6, 18, 13)).
- **Deviation (AC 5 detail):** the Dev Notes said pet widths are even by construction; the cats' frame 0 is 17 wide. The icon test therefore checks "exact on an even side, within 1 px on an odd side" in both directions (which still pins the floor margin) instead of "exact across". Logged in `deferred-work.md`.
- **Fits every slot (AC 6):** `test_every_shipped_pet_frame_is_a_32px_cell` (all 9 pets: 32×32 atlas regions of a 32 px high sheet) plus the existing 32×32 frame-rect layout tests; confirmed by eye at Gate 2 for all 8 pets on the HUD (Zombie Run and Pitchfork Panic), report card, main menu and Crypt Closet.
- **Fit check (AC 7):** two 1× views next to the cushion: a stopped `player_zombie.tscn` (idle 0) wearing the chosen hat with the pet at the main menu's own spacing (read from `main_menu.tscn`'s SceneState: +36 px), and the real Professor Zombie (point 0) wearing it with the pet in his own `%PetSlot` (60, 30). Their hat and pet slots join the H/P cycles; every existing key, page and seam is unchanged.
- **Gates (AC 8):** Gate 1 and Gate 2 approved by Smuck on 2026-10-14 (verbatim in `## Art Approval`); Pet Fit Checklist filled in (all pass). The blink rate (about twice a second, forced by the 2-6 frame / 8-12 fps limits) was raised at Gate 1 and logged in `deferred-work.md`.
- **No regressions (AC 9):** hats and ghost PNGs byte-identical; no change to `PlayerData`, the save, `HatSlot`, `PetSlot`, `ClosetItemTile`, `CryptCloset`, `ProfessorZombie`, the HUD, menu, report card or any level.
- **Mutation pass (Task 8.2), all 11 caught:** soles lifted to row 29, a 23 px tall pet, two identical frames and 7 frames (tool guard, no PNG written); candy-yellow in the crow (`test_art_sprites`); `pet_black_cat` available (`test_shipped_only_mvp_items_are_available`); a broken spider icon margin (`test_pet_icons_are_centred`); crow at 6 fps (`test_shipped_pet_frames`); the bat dropped from `SHEETS` (`test_every_pet_sheet_is_listed`); the report view's and the menu view's pet slot not registered, i.e. ignoring `current_pet()` (`test_hat_fit_check`). Everything restored afterwards; regenerated PNGs identical to the approved ones.

### File List

- `tools/gen_cosmetics_art.gd` (modified)
- `assets/sprites/cosmetics/pets/pet_black_cat_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_spider_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_orange_cat_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_bat_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_crow_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_wolf_dog_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_eyeball_idle.png` (+ `.import`) (new)
- `assets/sprites/cosmetics/pets/pet_brain_buddy_idle.png` (+ `.import`) (new)
- `data/cosmetics/pet_black_cat.tres`, `pet_spider.tres`, `pet_orange_cat.tres`, `pet_bat.tres`, `pet_crow.tres`, `pet_wolf_dog.tres`, `pet_eyeball.tres`, `pet_brain_buddy.tres` (modified)
- `data/cosmetics/pet_cute_ghost.tres` (modified, icon only)
- `scripts/debug/hat_fit_check.gd` (modified)
- `tests/unit/test_art_sprites.gd` (modified)
- `tests/unit/test_pet_slot.gd` (modified)
- `tests/unit/test_hat_fit_check.gd` (modified)
- `tests/unit/test_catalogue.gd` (modified)
- `tests/unit/test_closet_item_tile.gd` (modified)
- `tests/unit/test_crypt_closet.gd` (modified)
- `docs/art-style-sheet.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/9-2/` (new: `gate1-*.png` ×10, `gate2-*.png` ×43)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/9-2-eight-new-pets.md` (this file)

### Change Log

- 2026-10-14: Story 9.2 implemented: 8 pet idle sheets drawn in `gen_cosmetics_art.gd` with a pet-rules guard, wired into their `.tres` (frames + centred Closet icons, still unavailable), the Cute ghost's icon re-centred, art/catalogue/slot/Closet/fit-check tests (2040 -> 2049), fit-check menu and report card views, style sheet updated, Gates 1 and 2 approved. Status -> review.
