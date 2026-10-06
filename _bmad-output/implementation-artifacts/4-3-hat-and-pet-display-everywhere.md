---
baseline_commit: 1cb89a9f2945ceb2b22f53fd8db352de51966eb2
---

# Story 4.3: Hat and Pet Display Everywhere

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the hat I wear to sit on my zombie in every pose and my pet to hang out beside me,
so that my reward is always on screen.

## Acceptance Criteria

1. **Per-frame head anchors (FR43, architecture D6).** A new `SpriteAnchors` Resource (`scripts/resources/sprite_anchors.gd`) holds a head point for every frame of every animation. `data/anchors/zombie_anchors.tres` covers the player zombie's `idle` (2), `walk` (4), `hop` (3), `hug` (3) and `dance` (4) frames. `data/anchors/professor_anchors.tres` covers Professor Zombie's `point` (2) frames. Each head point is the top-centre of that frame's crown, measured from the PNG (see Dev Notes "Anchor values"). A unit test re-measures every sheet and fails if an anchor no longer matches the art.
2. **`HatSlot` follows the pose.** `scenes/cosmetics/hat_slot.tscn` + `scripts/cosmetics/hat_slot.gd` (`class_name HatSlot extends Node2D`) replace the empty `HatSlot` `Node2D`s in `player_zombie.tscn` and `professor_zombie.tscn` (same node name, still `%HatSlot`, still a child of `Body`). On **every** `frame_changed` **and** `animation_changed` of its `AnimatedSprite2D`, it moves to that animation/frame's head point. So the hat fits idle, walk, hop, hug and dance, and Professor Zombie's pointing pose. The hop/hug/dance tweens move `Body`, and the hat rides along as a child (already true today, keep it).
3. **`PetSlot` plays the pet's idle.** `scenes/cosmetics/pet_slot.tscn` + `scripts/cosmetics/pet_slot.gd` (`class_name PetSlot extends Node2D`) play the equipped pet's `idle` animation, with the pet's feet at the node origin. One is placed in each of these: the HUD pet slot (on the parchment cushion), the report card (beside Professor Zombie, replacing his empty `%PetSlot`), and the main menu (beside the zombie, replacing the empty `%PetSpot` marker).
4. **Live updates from `PlayerData`.** Every `HatSlot` and `PetSlot` connects to `PlayerData.equipment_changed` (its own slot key only) and `PlayerData.profile_replaced`, and disconnects in `_exit_tree()`. When the hat or pet changes, every visible slot updates in the same call. An empty slot shows nothing (the HUD cushion stays, DESIGN "empty slot shows only the cushion").
5. **Never stops a run (NFR16).** An equipped id missing from the catalogue, an item with no `overlay` / no `pet_frames`, `pet_frames` without an `idle` animation, an anchor set missing an animation or frame, or a null `anchors` logs **one** `Log.warn(&"cosmetics", ...)` per cause and slot, then hides that slot's art (or keeps the last good position, for an anchor gap). It never errors, asserts or crashes.
6. **The art (style sheet gate).** `assets/sprites/cosmetics/hats/hat_pumpkin.png` (1 frame, 32×32 overlay, brim seated on row 30, centred on column 16) and `assets/sprites/cosmetics/pets/pet_cute_ghost_idle.png` (4 frames × 32×32, 8 fps loop, "idle float") are made with the code-authored ASCII-map method from a new `tools/gen_cosmetics_art.gd`. They pass every rule in `test_art_sprites.gd` (sheet, hard alpha, palette only, ink outline, distinct frames, one ground line on row 30, Lossless + no mipmaps). `hat_pumpkin.tres` gets `overlay`, and `pet_cute_ghost.tres` gets `pet_frames` (a `SpriteFrames` with `idle`, 4 frames, 8 fps, loop). `icon` stays empty (the Closet art is Story 4.4).
7. **Mortarboard stacks on the hat (D16).** On Professor Zombie, with a hat worn, the mortarboard is lifted by the hat's height so it sits on top of the hat. With no hat it sits on the crown exactly as today.
8. **Fit-check scene + named checklist.** A debug-only scene `scenes/debug/hat_fit_check.tscn` (Boundary 7, run directly like `art_review.tscn`) shows the chosen hat on **every** frame of every player-zombie animation and on both professor frames, at 1× and 3×, plus the chosen pet's idle on a cushion. The "Hat & Pet Fit Checklist" in this file (Dev Notes) is filled in with pass/fail per item, and Smuck records approval in `## Art Approval` before the story goes to review.
9. **Preview hook for the Closet (4.4).** Both slots have `@export var follow_equipped: bool = true` and `show_item(item: CosmeticItem)`. With `follow_equipped = false` they ignore `PlayerData` and show only what `show_item` gives them (null = empty). The fit-check scene uses this, and Story 4.4's preview zombie will too.
10. **Tests.** New `tests/unit/test_sprite_anchors.gd`, `test_hat_slot.gd`, `test_pet_slot.gd` and `test_hat_fit_check.gd`. Updated: `test_player_zombie.gd`, `test_report_card.gd`, `test_hud.gd`, `test_main_menu.gd`, `test_art_sprites.gd`, `test_catalogue.gd` (shipped items now have art) and `test_art_style_sheet.gd` if it pins the style sheet tables. The full suite passes.

## Tasks / Subtasks

- [x] **Task 1: `SpriteAnchors` resource + shipped anchors (AC: 1, 5)**
  - [x] 1.1 `scripts/resources/sprite_anchors.gd`: `class_name SpriteAnchors extends Resource`. `##` header: "Per-frame head points for one character's SpriteFrames (architecture D6). A point is in the AnimatedSprite2D's local pixels (centered = false, so (0, 0) is the frame's top-left): the top-centre of the crown, where a hat's seat goes. Measured from the art; tests/unit/test_sprite_anchors.gd re-measures the PNGs."
  - [x] 1.2 `@export var head: Dictionary[StringName, PackedVector2Array] = {}` (typed dictionaries are exportable since Godot 4.4). Neutral default: empty.
  - [x] 1.3 `func has_head(anim: StringName, frame: int) -> bool` and `func get_head(anim: StringName, frame: int) -> Vector2` (returns `Vector2.ZERO` when missing; the caller checks `has_head` first and handles the gap, so the getter doesn't log).
  - [x] 1.4 `func validate(frames: SpriteFrames) -> String`: empty when every animation in `frames` has an entry with exactly `get_frame_count(anim)` points. Otherwise it returns the first problem (an animation is missing, the count is wrong, or there's an extra animation with no frames). Same style as `Catalogue.validate()`.
  - [x] 1.5 `data/anchors/zombie_anchors.tres` and `data/anchors/professor_anchors.tres` with the values in Dev Notes "Anchor values". Hand-write them, or generate them with an optional `tools/gen_sprite_anchors.gd` (headless, measures the PNGs with the same rule as the test, then `ResourceSaver.save`). If you add the tool, commit it, since `tools/` is the home for offline generators and is not exported. LF, no absolute paths.
- [x] **Task 2: `HatSlot` (AC: 2, 4, 5, 9)**: `scenes/cosmetics/hat_slot.tscn` + `scripts/cosmetics/hat_slot.gd`
  - [x] 2.1 Scene: root `HatSlot` (`Node2D`, script) with one child `%Overlay` (`Sprite2D`, `centered = false`, `position = -SEAT` = (-16, -30), hidden by default). Export defaults set in the scene: `catalogue` = `data/cosmetics/catalogue.tres`.
  - [x] 2.2 Script API:
    - `const SEAT: Vector2 = Vector2(16, 30)`: the overlay pixel that sits on the head point (bottom-centre of the brim; it mirrors the characters' "soles on row 30" rule). `##` comment.
    - `@export var sprite: AnimatedSprite2D`: the body it follows (set in the character scene to `..`). This is an explicit export, not a `get_parent()` call (Consistency Rules).
    - `@export var anchors: SpriteAnchors`
    - `@export var catalogue: Catalogue`
    - `@export var follow_equipped: bool = true`
    - `var player_data: PlayerDataScript = null`: a test seam, defaults to `PlayerData` in `_ready()` when null. Use the same `const PlayerDataScript: GDScript = preload(...)` pattern as `main_menu.gd`.
    - `func show_item(item: CosmeticItem) -> void`: shows `item.overlay`, or hides it when the item is null or isn't a hat. A null `overlay` → warn once and hide.
    - `func get_item_id() -> StringName` (`&""` when empty) and `func is_showing() -> bool`, for tests and 4.4.
  - [x] 2.3 `_ready()`: default the seam. If `sprite` is null → warn once, hide, return. Connect `sprite.frame_changed`, `sprite.animation_changed` **and** `sprite.sprite_frames_changed` to `_follow()`, then call `_follow()` once. If `follow_equipped`, connect `player_data.equipment_changed` and `player_data.profile_replaced` and show `catalogue.get_item(player_data.get_equipped(CosmeticItem.SLOT_HAT))`. `_exit_tree()` disconnects the `player_data` signals if connected (architecture rule: autoload connections are disconnected in `_exit_tree`).
  - [x] 2.4 `_follow()`: `if anchors == null or not anchors.has_head(sprite.animation, sprite.frame)` → warn once per animation and keep the current position. Otherwise `position = anchors.get_head(...)`. **Mirror for `flip_h`:** when `sprite.flip_h`, use `x = FRAME_W - x` (32 − x, so 16 stays 16 and the hug's 17 becomes 15) and set `%Overlay.flip_h` to match. Today only the no-dance-frames fallback flips Body, but it's one line and Horde Rush lanes may flip later. `Log.debug(&"cosmetics", ...)` the position (DEBUG is for anchor positions, per the architecture's logging table).
  - [x] 2.5 `_on_equipment_changed(slot, item_id)`: ignore any slot other than `CosmeticItem.SLOT_HAT`. `_on_profile_replaced()`: re-read `get_equipped`. Both do nothing when `follow_equipped` is false.
- [x] **Task 3: `PetSlot` (AC: 3, 4, 5, 9)**: `scenes/cosmetics/pet_slot.tscn` + `scripts/cosmetics/pet_slot.gd`
  - [x] 3.1 Scene: root `PetSlot` (`Node2D`, script) with `%Pet` (`AnimatedSprite2D`, `centered = false`, `position = Vector2(-16, -31)` like the characters' `Body`, so the node origin is the feet centre with soles on sheet row 30; hidden by default). Export default: `catalogue` = `catalogue.tres`.
  - [x] 3.2 Same seams and API as `HatSlot` (`catalogue`, `follow_equipped`, `player_data`, `show_item`, `get_item_id`, `is_showing`), for `SLOT_PET`. `show_item` sets `%Pet.sprite_frames = item.pet_frames` and `play(&"idle")`. Null frames, or frames without `idle` → warn once and hide.
  - [x] 3.3 It needs no anchors (a pet doesn't follow a pose). It inherits `process_mode`, so the HUD pet freezes with the tree while the run is paused, which is correct.
- [x] **Task 4: Put the slots in the characters (AC: 2, 7)**
  - [x] 4.1 `scenes/characters/player_zombie.tscn`: replace the `HatSlot` `Node2D` under `Body` with an instance of `hat_slot.tscn`, keeping name `HatSlot`, `unique_name_in_owner = true`, `sprite = NodePath("..")` and `anchors = zombie_anchors.tres`. Its initial position comes from `_follow()`, so the hand-set (16, 1) can go. `player_zombie.gd`: update the header ("%HatSlot follows SpriteAnchors per frame (Story 4.3)"). **No logic change**: the hop/hug/dance tweens and the one-animation-owner rule stay exactly as they are.
  - [x] 4.2 `scenes/characters/professor_zombie.tscn`: the same for `Body/HatSlot` (`anchors = professor_anchors.tres`), keeping `Mortarboard` **after** `HatSlot` in the child order (drawn on top). Replace the root-level `%PetSlot` `Node2D` with a `pet_slot.tscn` instance named `PetSlot`. **Note:** the professor's origin is the top-left of the frame (his `Body` is at (0, 0), soles on row 30), not the feet. So the pet's feet go at about `(60, 30)` in professor space: on the floor, right of him. Tune it by eye, keeping it clear of the board, the stamp and both buttons (test 9.4).
  - [x] 4.3 `professor_zombie.gd`: connect `%HatSlot`'s new `signal item_shown(item: CosmeticItem)` (add it to `HatSlot`, emitted by every show, including null) to `_stack_mortarboard(item)`. That sets `$Body/Mortarboard.position.y = -_hat_rise(item)`, where `_hat_rise` = `SEAT.y - overlay.get_image().get_used_rect().position.y` (how far the hat reaches above the head point), or 0 with no hat or no overlay. Cache the rise per item id. `get_image()` on a Lossless import works at runtime. If it returns null, warn and use 0. Keep the professor free of `PlayerData`: the hat slot does the listening. Update the header ("Story 4.3: the worn hat and pet fill the slots, and the mortarboard stacks on the hat (D16)").
- [x] **Task 5: Put the slots on the screens (AC: 3, 4)**
  - [x] 5.1 **HUD** (`scenes/run/hud.tscn`): add a `pet_slot.tscn` instance named `Pet` (`%Pet`) as a child of the existing `%PetSlot` `Control`, after `%PetCushion`, with its feet on the cushion: start at `(32, 80)` in `%PetSlot` local space (cushion is 8..56 × 44..92), and tune by eye. **Don't rename the HUD's `%PetSlot` `Control`.** `test_hud.gd` pins its rect, and two `%PetSlot` unique names in one owner aren't allowed. `hud.gd`: no logic change. Update the header line "never touches ... any autoload except Log" to say the `%Pet` slot listens to `PlayerData` by itself (it's a cosmetics widget, Boundary 2 allows `HatSlot`/`PetSlot`) while the HUD script still doesn't.
  - [x] 5.2 **Main menu** (`scenes/screens/main_menu.tscn`): replace the `PetSpot` `Marker2D` with a `pet_slot.tscn` instance named `PetSlot` (`%PetSlot`) at the same position (84, 284). The menu zombie already carries `%HatSlot` through `player_zombie.tscn`. `main_menu.gd`: update the header line about Story 4.3. The menu script doesn't need to call anything, because the slots listen themselves. Check that the text-fit and 16 px margin tests in `test_main_menu.gd` still pass. The pet is a `Node2D`, so those tests ignore it, but check by eye that the hat (up to ~14 px above the head, y ≈ 239) and the pet (x 68..100) overlap nothing.
  - [x] 5.3 **Report card**: nothing in `report_card.gd`. The professor instance brings both slots. Update its header line "the hat and pet in the Professor's slots are Story 4.3" → done. It still reads nothing from `PlayerData` itself.
  - [x] 5.4 **Zombie Run**: nothing in `zombie_run_level.gd`. The level's `PlayerZombie` instance brings the `HatSlot`. Party-hat zombies and the conga line **do not** wear the player's hat (they have their own party hats). Horde Rush copies are Epic 6.
- [x] **Task 6: Pumpkin hat and Cute ghost art (AC: 6)**: `tools/gen_cosmetics_art.gd`
  - [x] 6.1 Follow `tools/gen_zombie_run_art.gd` exactly: `extends SceneTree`, `const Proto := preload("res://tools/gen_art_prototypes.gd")` for the palette and helpers, ASCII maps (one char per pixel, `.` transparent), a legend char → palette **name**, written with `Image.save_png`, then run `--import`. Never hand-edit a PNG. Commit the PNGs and `.import` files.
  - [x] 6.2 `hat_pumpkin.png`: **32×32, 1 frame**. A small jack-o'-lantern cap about 14 px wide (at least 12 px, so it covers the 12 px crown) and about 10–12 px tall, sitting on the brim: `pumpkin` body, `pumpkin-light` highlight, `wood-dark` stem, `zombie-green-dark` leaf/curl, `ink` 1 px outline. Cute face: no scary teeth, or none at all (cute-Halloween, NFR10). Its **lowest opaque row is row 30** (the seat), and it's horizontally centred: `used_rect.position.x + used_rect.end.x == 32`, so it's symmetric about x 16. Row 31 is empty (margin rule 5). Never `candy-yellow` or `stamp-red`.
  - [x] 6.3 `pet_cute_ghost_idle.png`: **4 frames × 32×32, 8 fps loop**. A small round ghost about 16–20 px tall, so it reads as a pet next to a 32 px zombie: `chalk` body, `stone-light` shade, `ink` outline and eyes, optional `art-brain-pink` cheeks. The "float" is drawn in the frames (body bob 1 px plus a wavy tail), but the **lowest opaque row stays on row 30 in every frame** (rule 7, one ground line; the tail tips are its "soles"), and no two frames are identical (rule 6). If you want a bigger float, add a code bob in a later story; don't break rule 7.
  - [x] 6.4 Data: `hat_pumpkin.tres` → `overlay = ExtResource(hat_pumpkin.png)`. `pet_cute_ghost.tres` → `pet_frames` = a sub-resource `SpriteFrames` with `idle`: 4 `AtlasTexture` regions (0/32/64/96, 0, 32, 32), speed 8, loop true (same shape as `player_zombie.tscn`). `icon` stays null (4.4). LF, `load_steps` correct.
  - [x] 6.5 `docs/art-style-sheet.md` § 3: add the two rows to the sheet table (`hat_pumpkin.png`: overlay 32×32, seat on row 30 at x 16; `pet_cute_ghost_idle.png`: 4 frames, 32×32, 8 fps, loop). Add a short "Hats" paragraph: hats are 32×32 one-frame overlays whose brim bottom (the seat) is on row 30, centred on column 16, and `HatSlot` puts the seat on the head point. Pets are 32×32 sheets drawn from the feet like characters. Paths: `assets/sprites/cosmetics/hats/`, `assets/sprites/cosmetics/pets/`. Update § 6 "Hats anchor to a head point (Story 4.3 sets the anchors)" to past tense, and point it at `data/anchors/`.
- [x] **Task 7: Fit-check scene (AC: 8)**: `scenes/debug/hat_fit_check.tscn` + `scripts/debug/hat_fit_check.gd`
  - [x] 7.1 `class_name HatFitCheck extends Control`. Dev/Smuck only (Boundary 7): never routed to, no menu button. Run it directly: `"/c/Program Files/Godot/Godot.exe" --path . res://scenes/debug/hat_fit_check.tscn`. Copy `art_review.gd`'s header style and key handling (`_unhandled_input`; leave F3/F5/F8/F9 to the debug overlay).
  - [x] 7.2 It builds, in code, one cell per frame: every animation and frame of `player_zombie.tscn`'s `SpriteFrames` (idle 0–1, walk 0–3, hop 0–2, hug 0–2, dance 0–3 = 16) and the professor's `point` 0–1 (18 cells). Each cell is a **stopped** `AnimatedSprite2D` (`animation` + `frame` set, not playing) with a `hat_slot.tscn` child (`follow_equipped = false`, `sprite` and `anchors` set). Set `follow_equipped`, `sprite` and `anchors` before `add_child` (Entity Patterns: setup before `add_child`). Show a 1× row and a 3× row (a `scale = 3` wrapper, which is fine for a debug viewer; the game itself stays at one scale), with a 16 px label per cell (`idle 0`, `hug 1`, …). Add the professor's mortarboard in his cells, so AC 7's stacking is visible. Also show one `pet_slot.tscn` on a parchment cushion (the HUD cushion size, 48×48), playing.
  - [x] 7.3 Keys: `H` cycles the hat (every catalogue hat with an `overlay`, plus "none"), `P` cycles the pet the same way, `B` cycles the background through `night`, `art-sky`, `chalkboard` and `parchment` (the places a hat appears), `Esc` quits. `E` **wears for real**: it gives the live `PlayerData` the item's price with `add_brains`, then calls `buy_item` (unless owned) and `equip` for the shown hat and pet. With "none" it calls `unequip`. This is the only way to wear something before the Closet (4.4) exists, and it lives here because this scene is debug-only (Boundary 7). Log it with `Log.info(&"cosmetics", ...)`. The footer shows the current hat, pet and background names at 16 px, plus "E = wear for real".
  - [x] 7.4 It must not crash with an empty catalogue or a hat without an overlay (it shows "none").
- [x] **Task 8: Tests (AC: 10)**
  - [x] 8.1 `tests/unit/test_sprite_anchors.gd`:
    - `get_head`/`has_head` with a code-built resource (present, missing animation, frame out of range);
    - `validate()` passes on the shipped pairs (`zombie_anchors.tres` vs the `player_zombie.tscn` `Body.sprite_frames`, `professor_anchors.tres` vs the professor's) and catches a missing animation, a wrong count and an extra animation;
    - **art match**: for every animation and frame, load the sheet PNG (`Image.load_from_file(ProjectSettings.globalize_path(...))`, as `test_art_sprites.gd` does) and measure the crown: top = the first row with an opaque pixel, x = (min opaque x + max opaque x + 1) / 2 on that row. Assert it equals the anchor. This is what makes a redrawn sheet fail loudly. Map animation → sheet path explicitly in the test.
  - [x] 8.2 `tests/unit/test_hat_slot.gd` (fresh `PlayerData` on a temp-dir `SaveService` + a code-built `Catalogue` with a hat that has a 32×32 `ImageTexture` overlay, and a second hat with none; inject before `add_child`, like `test_main_menu.gd`). Cover:
    - empty on a fresh save;
    - `buy_item` + `equip` shows the overlay in the same call;
    - `unequip(&"hat")` hides it;
    - an equipment change on `&"pet"` is ignored;
    - `reset_all()` hides it (via `profile_replaced`);
    - two slots on one `PlayerData` both update from one `equip`;
    - an item without an overlay warns once and hides (use `assert_push_warning` if your GUT version has it, or count via a `Log` seam; don't let it error);
    - `follow_equipped = false` ignores `equip` and shows only `show_item`;
    - `_exit_tree` disconnects (free the slot, then `equip`: no error, and `player_data.equipment_changed.get_connections()` no longer has it).
    - **Following:** with a real `player_zombie.tscn` instance (its `Body` + anchors) and a stopped sprite, set animation/frame for every shipped frame and assert `HatSlot.position == anchor`. Explicitly cover **idle frame 0 → hop frame 0** (`frame` stays 0, so only `animation_changed` fires; this is the trap) and hug frame 1 (x 17). `flip_h = true` mirrors x (17 → 15) and flips the overlay. A missing anchor keeps the previous position and warns once.
  - [x] 8.3 `tests/unit/test_pet_slot.gd`: the same seam shape. Equip a pet → `%Pet` visible and playing `idle`; unequip → hidden; frames without `idle` → warn and hide; the slot filter; `profile_replaced`; and the shipped `pet_cute_ghost.tres` frames have `idle` with 4 frames at 8 fps, looping.
  - [x] 8.4 Updates:
    - `test_player_zombie.gd::test_hat_slot_exists` → it is a `HatSlot` with `anchors` set and `sprite == Body`. Drop the "empty until 4.3" child-count assert. `test_hop_carries_the_hat_slot` must still pass: the hop moves `Body`, and the slot's own position follows the frame. If hop frame 0's anchor (y 3) differs from the rest anchor (y 1), compare against `Body` + anchor rather than the raw rest y.
    - `test_report_card.gd::test_professor_points_at_1x_with_empty_slots` → slots are `HatSlot` / `PetSlot`, the mortarboard is still after `HatSlot`, and with no hat `Mortarboard.position.y == 0`. Add: with a hat shown (`show_item` on the professor's `%HatSlot`), the mortarboard rises by the hat's rise. Add: the pet's 32×32 rect (feet origin −16..16 × −31..1) doesn't intersect the board, the stamp or either button rect.
    - `test_hud.gd`: `%Pet` exists inside `%PetSlot`, and its feet sit within the cushion rect. The existing rect asserts stay.
    - `test_main_menu.gd`: `%PetSlot` exists at (84, 284), is a `PetSlot`, and `%Zombie`'s `%HatSlot` is a `HatSlot`.
    - `test_art_sprites.gd`: add `pet_cute_ghost_idle.png: 4` to `SHEETS`, and `hat_pumpkin.png: FRAME` to `OVERLAYS`. **Trap:** `test_right_color_ramps_used` treats every non-zombie/professor/party path as a villager and requires `art-skin-light`. Add a branch for `/cosmetics/pets/` (require `chalk` for the ghost, or just `ink` for any pet). Hats are already skipped (overlays: ink only). Add `test_hats_seat_on_row_30_centred` (lowest opaque row 30, `used_rect.position.x + used_rect.end.x == 32`).
    - `test_catalogue.gd`: the neutral-defaults test is unchanged (it uses `CosmeticItem.new()`). Add: shipped `hat_pumpkin` has an overlay, `pet_cute_ghost` has `pet_frames` with `idle`, and every unavailable item still has none (Epic 9).
  - [x] 8.5 `tests/unit/test_hat_fit_check.gd`: the scene instantiates headless without errors, builds 18 hat cells (16 zombie + 2 professor) at both scales, every cell's sprite is stopped on a distinct (animation, frame), and `H`/`P` cycling never crashes with the shipped catalogue or an empty one. `E` goes through an injected `player_data` seam (temp `SaveService`): after it, `get_equipped(&"hat") == &"hat_pumpkin"`, and with "none" the slot is empty. Never touch the real save.
  - [x] 8.6 Run `--import` first (new `class_name`s: `SpriteAnchors`, `HatSlot`, `PetSlot`, `HatFitCheck`, plus the new PNGs), then the full suite. Record the baseline (measure it; it was **976** after 4.2's dev run, and code review may have added more) and the final counts.
- [x] **Task 9: Manual checks and approval (AC: 6, 7, 8)**
  - [x] 9.1 Run `hat_fit_check.tscn`. Fill in the **Hat & Pet Fit Checklist** below with pass/fail per item, then take a screenshot to `_bmad-output/implementation-artifacts/screenshots/4-3-hat-fit-check.png`.
  - [x] 9.2 In the fit-check scene, show the Pumpkin hat and the Cute ghost and press `E` (Task 7.3). Then run the game and play one Zombie Run. Check the hat through walk, hop (brain block), hug (villager) and the end dance, and the ghost bobbing on the HUD cushion (it freezes during pause). Then check the report card (hat under the mortarboard, ghost on the floor) and the menu (zombie with the hat, ghost beside it). Take screenshots `4-3-run.png`, `4-3-report-card.png` and `4-3-menu.png`.
  - [x] 9.3 Put the screenshots in front of Smuck. Record "Approved by Smuck on <date>" (or the requested changes) in `## Art Approval`. Don't move to review without it (style sheet § 1 gate).
- [x] **Task 10: Wrap-up**
  - [x] 10.1 LF line endings on every touched text file. `deferred-work.md`: strike, with "Done in 4.3: …", the 2.9 item (the worn hat and pet in the professor's slots, the anchors, the mortarboard lift) and the 3.6 item (hat anchors on the new frames). Add anything left open under "Deferred from: dev of story 4-3".
  - [x] 10.2 Fill in the File List, the Debug Log (counts and the mutation pass) and the Change Log.

### Review Findings

- [ ] [Review][Decision] Checklist rows 10 and 12 still say "Smuck to confirm live" but Task 9.1 is ticked and Art Approval is recorded — confirm the 8 fps motion and the end-dance frame check live, then either update the checklist rows to Pass or re-open Task 9.1 (AC8)
- [x] [Review][Patch] Hat does not re-anchor when `flip_h` changes without a frame/animation change (dance flip fallback, `_reset_dance`) [scripts/cosmetics/hat_slot.gd:_follow, scripts/characters/player_zombie.gd:190-198]
- [x] [Review][Patch] Fully transparent hat overlay makes the mortarboard rise 30 px (`get_used_rect()` is empty); guard with an empty-rect check and warn once [scripts/characters/professor_zombie.gd:_hat_rise]
- [x] [Review][Patch] `PetSlot.show_item` restarts the idle at frame 0 on every `equipment_changed`/`profile_replaced` even for the same pet; no-op when unchanged and playing [scripts/cosmetics/pet_slot.gd:show_item]
- [x] [Review][Defer] Slots connect to PlayerData only in `_ready` and disconnect in `_exit_tree`, so a reparent leaves them stale [scripts/cosmetics/hat_slot.gd, pet_slot.gd] — deferred, already recorded in deferred-work.md; nothing reparents today
- [x] [Review][Defer] Test robustness: HUD/report-card tests use the live PlayerData autoload, art-number magic constants, fit-check key bindings and warning counts untested [tests/unit/test_hud.gd, test_report_card.gd, test_hat_fit_check.gd] — deferred, low risk

## Dev Notes

### What this story is (and isn't)

- **Is:** the cosmetic display system: `SpriteAnchors` plus two shipped anchor sets, the `HatSlot` and `PetSlot` widgets, slots placed in the player zombie, the professor, the HUD and the menu, the mortarboard stack, the Pumpkin hat and Cute ghost art and data, and a debug fit-check scene with a manual checklist.
- **Isn't:** the Crypt Closet screen, tiles, icons, the confirm prompt or the preview zombie (4.4. Leave `icon` empty, and the `show_item`/`follow_equipped` hook is all 4.4 needs from here). The welcome gift (4.5). Any `PlayerData`/save change: `equip`, `unequip`, `get_equipped` and `equipment_changed` already exist (4.1) and are enough. Hats on Horde Rush copies or size classes (Epic 6, FR75). The 16 other items' art (Epic 9). A shop UI or a debug "equip" cheat in the shipped overlay. A code float bob for pets.

### Anchor values (measured from the shipped PNGs, 2026-10-05)

Rule: in the frame's 32×32 cell, `y` = the first row with any opaque pixel, `x` = (min opaque x + max opaque x + 1) / 2 on that row. In every frame the crown's top row is 12 px wide (`[10..21]`, so x = 16). Hug frame 1 leans 1 px right (`[11..22]`, so x = 17).

| Animation | Frames → head point (Body-local px) |
|---|---|
| zombie `idle` | (16, 1), (16, 2) |
| zombie `walk` | (16, 2), (16, 1), (16, 2), (16, 1) |
| zombie `hop` | (16, 3), (16, 1), (16, 2) |
| zombie `hug` | (16, 1), (17, 1), (16, 2) |
| zombie `dance` | (16, 1), (16, 1), (16, 1), (16, 2) |
| professor `point` | (16, 5), (16, 5) |

The idle frame 1 and walk crowns bob 1 px. That's the breathing/step bob, and the hat bobbing with it is the point. Today's hand-placed slots (zombie (16, 1), professor (16, 5)) agree with frame 0. The test (8.1) re-measures, so trust the test over this table if the art changes.

### Hat geometry (one convention for every future hat)

- A hat overlay is a **32×32 one-frame PNG** whose **seat** (the bottom-centre of the brim) is pixel **(16, 30)**: lowest opaque row 30, symmetric about x 16. `HatSlot` sits at the head point, and its `%Overlay` is at `-SEAT`, so the seat lands on the crown's top row. The brim's bottom ink row overlaps the crown's top ink row, which reads as "sitting on it".
- Why 32×32 and not 16×16: the 12 px crown plus a brim, and tall hats in Epic 9 (witch, top hat, bunny ears) need room. It's also the character size, so `test_art_sprites.gd`'s overlay rules apply as is.
- Why per-frame anchors and not one fixed point: the crown moves 1–2 px on idle, walk, hop, hug and dance frames (deferred-work 3.6). A fixed slot would float or sink into the head.

### Mortarboard stack (D16)

`professor_mortarboard.png` is drawn at the body origin with its cap resting on the crown (row 5). With a hat, raise it by `rise = SEAT.y − overlay.used_rect.position.y` (e.g. a pumpkin whose top row is 19 → rise 11). The cap then rests on the hat's top row. Use the `HatSlot.item_shown` signal so the professor never touches `PlayerData`. Check it in the fit-check scene (the professor cells) and on the real report card: the board, heading and stamp must not be overlapped (the professor stands at (430, 270) with his top at 271, so a lifted mortarboard tops out around y 258).

### Existing code: current state, what changes, what must be preserved

- `scenes/characters/player_zombie.tscn` / `player_zombie.gd` (UPDATE scene, comment-only script change). `Body` is an `AnimatedSprite2D` at (-16, -31), `centered = false`, autoplay `idle`. `%HatSlot` is an empty `Node2D` child of `Body` at (16, 1). The script owns the hop (Body y), hug (Body x) and dance (Body y + flip fallback) tweens, plus the one-animation-owner rule. **Preserve every bit of that.** The `HatSlot` must listen to the sprite's signals; it must never be driven from `player_zombie.gd` per frame.
- `scenes/characters/professor_zombie.tscn` / `professor_zombie.gd` (UPDATE). `Body` is at (0, 0) (origin = frame top-left, soles row 30), `point` 2f at 8 fps, `%HatSlot` at (16, 5), `Mortarboard` after it, `%PetSlot` `Node2D` at (44, 0). The script only hides `Body` when it has no frames. Keep that, and keep it free of autoloads apart from `Log`.
- `scenes/run/hud.tscn` (UPDATE). `%PetSlot` is a `Control` (0, 256, 64, 104) holding `%PetCushion` (8, 44, 48, 48, parchment). Both rects are pinned in `test_hud.gd`. Add `%Pet` inside it. Everything is `mouse_filter = IGNORE` and `FOCUS_NONE`. A `Node2D` has neither, so that's fine.
- `scenes/screens/main_menu.tscn` (UPDATE). `%PetSpot` `Marker2D` at (84, 284). `%Zombie` is an instance of `player_zombie.tscn` at (48, 284). Nothing in `main_menu.gd` or its tests references `%PetSpot` (checked with grep), so replace it.
- `data/cosmetics/hat_pumpkin.tres`, `pet_cute_ghost.tres` (UPDATE). Today they have the id, name, slot, price 100, row 1 and `is_available = true`, and no art. Keep the ids (saves store them).
- `scripts/autoloads/player_data.gd` (READ ONLY). `get_equipped(slot)` returns `&""` for empty, not-owned, unknown or unavailable ids, so a slot can trust it. `equipment_changed(slot: StringName, item_id: StringName)` fires on equip, and on unequip only when something was visible. `profile_replaced` fires on F8 reset. `CosmeticItem.SLOT_HAT`/`SLOT_PET` are the slot keys. Don't add methods. The slots look items up in their exported `Catalogue`.
- `tools/gen_art_prototypes.gd`, `tools/gen_zombie_run_art.gd` (READ ONLY): they're the model for the new generator. Don't rerun them; that would rewrite approved PNGs.

### Key design decisions (follow these; Smuck can overrule)

- **Connect `animation_changed` as well as `frame_changed`.** Godot's `AnimatedSprite2D` emits `frame_changed` only when the frame index actually changes. Going from idle frame 0 to hop frame 0 keeps index 0, so the hat would stay at y 1 while the crown is at y 3. `sprite_frames_changed` covers a frames swap. This is the one bug the AC wording invites.
- **Slots listen to `PlayerData` themselves** (architecture Cosmetics: "Both slots update from `PlayerData.equipment_changed`"). The screens, the HUD and the professor stay passive. That keeps `hud.gd` free of autoloads and `report_card.gd` free of `PlayerData`, and every slot updates in the same call.
- **The catalogue is an `@export` set in the slot scenes**, not reached through `PlayerData.catalogue` (a test seam, not API). This follows the architecture's Data Patterns: static data is injected with `@export`.
- **`sprite` is an exported node reference, not `get_parent()`** (Consistency Rules: no `get_parent()` chains).
- **Warn once, hide, carry on** for every missing-art case (NFR16, architecture "never let a missing cosmetic stop a run"). Use the new `Log` tag `&"cosmetics"`.
- **Party zombies don't wear the hat.** FR43 lists the player zombie, the menu, Professor Zombie and (post-MVP) Horde Rush copies. Conga followers are villagers turned party zombies, and they already wear party hats.
- **Pets are drawn from the feet** like characters (soles row 30, node origin = feet centre), so one convention places them on the cushion, the floor and the grass.

### Hat & Pet Fit Checklist (fill in during Task 9.1; pass/fail per item)

Run `hat_fit_check.tscn` with the Pumpkin hat and the Cute ghost.

| # | Check | What to look for | Pass/Fail |
|---|---|---|---|
| 1 | Idle seat | Both idle frames: brim on the crown, no gap row, no green pixels of the crown poking above the brim, hat bobs with the head | Pass: both idle frames seated, brim on the crown, no green above the brim; the hat moves with the 1 px breathing bob |
| 2 | Walk | All 4 frames: hat moves with the 1 px step bob, never floats or sinks | Pass: all 4 frames follow the step bob (y 2/1/2/1) |
| 3 | Hop | Crouch (frame 0) hat drops with the crown (y 3); peak and land frames seat correctly | Pass: crouch (frame 0) drops the hat to y 3 with the crown; peak and land seat |
| 4 | Hug | Squeeze (frame 1) hat shifts 1 px right with the lean; reach/release seat | Pass: squeeze (frame 1) shifts the hat 1 px right (x 17); reach and release seat |
| 5 | Dance | All 4 frames seated; frame 3 drops 1 px with the crown | Pass: all 4 seated, frame 3 drops 1 px; the raised arms clear the hat |
| 6 | Centring | Hat looks centred on the head (no 1 px lopsidedness) at 3× | Pass: extents symmetric about x 16 (tested); looks centred at 3x |
| 7 | Outline | Hat outline reads against the zombie's ink outline (no double-thick ink blob at the brim) | Pass: the brim's bottom ink row overlaps the crown's top ink row; one line, no blob |
| 8 | Professor | Hat on the crown, mortarboard sitting on top of the hat (not inside it, not floating) | Pass: pumpkin on the crown, mortarboard lifted 11 px and resting on the stem (both frames) |
| 9 | Backgrounds | Hat readable on night, art-sky, chalkboard and parchment | Pass: readable on night, art-sky, chalkboard and parchment |
| 10 | Ghost idle | 4 frames loop smoothly at 8 fps, reads as floating, soles row stable, cute not scary | Pass (frames): 4 distinct frames, tail tips on row 30 every frame, cute. Smuck to confirm the 8 fps motion live |
| 11 | Ghost on cushion | Sits on the HUD cushion without hiding it entirely or spilling out of the 64 px slot | Pass: the ghost sits in the middle of the 48 px cushion, inside the 64 px column (tested) |
| 12 | In play | During a real run: hat stays on through hops, hugs and the end dance at 5+ keys/s | Pass (scripted run at 6.25 keys/s): hat stayed on through hops and hugs (4-3-run.png, 4-3-run-hug.png). End dance checked frame by frame in the fit check; Smuck to confirm live |
| 13 | Report card / menu | Hat + ghost visible, nothing overlaps buttons, board, stamp, toggles or cards | Pass: hat + ghost on the menu and the report card; nothing overlaps (tested + screenshots) |
| 14 | Empty slots | A fresh save shows no hat, an empty cushion, no pet on the menu or card, no warnings in the log | Pass (tested): fresh save shows no hat or pet on the menu, no warnings in the suite log |

### Godot 4.7 notes

- `AnimatedSprite2D` signals: `frame_changed`, `animation_changed`, `sprite_frames_changed`, `animation_finished`, `animation_looped`. Set `animation` and `frame` directly on a stopped sprite for the fit-check cells (`stop()` first, then `animation = …`, `frame = …`). Setting `animation` resets `frame` to 0.
- `flip_h` flips only the sprite's own texture, never its children. That's why `HatSlot` mirrors itself (Task 2.4).
- Typed `Dictionary[StringName, PackedVector2Array]` exports serialize in `.tres` as `head = Dictionary[StringName, PackedVector2Array]({ &"idle": PackedVector2Array(16, 1, 16, 2), ... })`. Write one with `ResourceSaver` once if you're unsure of the text form, then hand-edit.
- `Texture2D.get_image()` on a Lossless-imported PNG returns the pixels at runtime (web too). `Image.get_used_rect()` gives the opaque bounds.
- Exported `Node` references (`@export var sprite: AnimatedSprite2D`) are stored as a `NodePath` in the `.tscn` and resolved before `_ready()`.
- An instanced sub-scene keeps `unique_name_in_owner` only if you set it on the instance node in the parent scene. Check `%HatSlot` still resolves from `player_zombie.gd`'s owner and from tests (`zombie.get_node("%HatSlot")`).

### Testing notes

- Suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` first.
- Never write the developer's real save: inject a temp-dir `SaveService` + `PlayerData` (patterns in `test_player_data.gd` and `test_main_menu.gd`). Slots in screens under test (HUD, report card, menu) will default to the **live** `PlayerData` autoload, which reads the developer's `user://` save. That's harmless for reading, but tests must not assert "empty" on those screens unless they inject. Assert on the slot type and position instead, or inject via `show_item` with `follow_equipped = false`.
- `Log.warn` → `push_warning`. In GUT, check with `assert_push_warning` / `get_push_warning_count` if available in 9.7.1, otherwise via a counter seam. Keep the warn strings distinctive (`"hat slot: %s has no overlay"`, `"pet slot: %s has no idle"`, `"hat slot: no anchor for %s %d"`).
- Mutation pass (the habit since 2.x): drop the `animation_changed` connection, ignore the slot filter, forget `profile_replaced`, skip the `_exit_tree` disconnect, forget the `flip_h` mirror, break one anchor value in the `.tres`, lift the mortarboard by 0, and let a missing overlay `push_error` instead of warn. Each should be caught. Report honestly any that survive.

### Previous story intelligence

- **4.2:** screens use seams (`navigate`, `player_data: PlayerDataScript`, `@export level_registry`) assigned **before** `add_child`, and tests use `PROCESS_MODE_DISABLED` instances. The menu placed `%PetSpot` and kept `player_zombie.gd` untouched for this story. Hover/focus code is irrelevant here (the slots aren't controls). Baseline was 909 → 976. One flaky `test_audio_manager` pool test exists (deferred-work 4.2). If it fails once, rerun before you investigate.
- **4.1:** `get_equipped` filters out junk, not-owned and unavailable ids. `equipment_changed` emits `&""` on a visible unequip. Error strings are distinctive for `assert_push_error`. The `.tres` files were generated with no uids, which is fine.
- **3.6:** art is ASCII maps in a `tools/` generator that reuses `Proto`. Approval is recorded in the story file. `test_art_sprites.gd` lists every sheet and overlay, and a new one must be added there. Hop and hug are drawn grounded (the tweens do the lift), which is why the crown only moves 1–2 px.
- **2.9:** the professor's slots and the mortarboard order were set up for this story. His origin is the frame top-left, not the feet.
- **Traps from earlier stories:** keep files LF (`.gitattributes eol=lf`). Write `×`/`–` as UTF-8. Prefer scratchpad scripts over heredocs with apostrophes. `assert()` shows as `SCRIPT ERROR` in headless GUT, so use `Log` + safe returns. GDScript's `untyped_declaration = Error` applies to tools too (type every `for` variable; a scratch measure script failed on that during story creation).

### Git intelligence

- One commit per story. The tree was clean at `1cb89a9 Story 4.2: main menu` when this story was created. Suggested message: `Story 4.3: hat and pet display everywhere`.
- Recent stories ship code, art, tests and the story file together, and record baseline/final counts plus a mutation pass in the Dev Agent Record.

### Project Structure Notes

- New: `scripts/resources/sprite_anchors.gd`, `data/anchors/zombie_anchors.tres`, `data/anchors/professor_anchors.tres`, `scenes/cosmetics/hat_slot.tscn`, `scenes/cosmetics/pet_slot.tscn`, `scripts/cosmetics/hat_slot.gd`, `scripts/cosmetics/pet_slot.gd`, `scenes/debug/hat_fit_check.tscn`, `scripts/debug/hat_fit_check.gd`, `tools/gen_cosmetics_art.gd` (optionally `tools/gen_sprite_anchors.gd`), `assets/sprites/cosmetics/hats/hat_pumpkin.png`, `assets/sprites/cosmetics/pets/pet_cute_ghost_idle.png` (+ `.import`), and the four new test files. These are all the paths the architecture's Directory Structure names (`scenes/cosmetics/`, `scripts/cosmetics/`, `data/anchors/`, `assets/sprites/cosmetics/{hats,pets}/`). Asset names follow `hat_<name>.png` and `pet_<name>_idle.png`.
- Updated: `player_zombie.tscn` (+ header in `.gd`), `professor_zombie.tscn` + `.gd`, `hud.tscn` (+ header in `hud.gd`), `main_menu.tscn` (+ header in `.gd`), the header in `report_card.gd`, `hat_pumpkin.tres`, `pet_cute_ghost.tres`, `docs/art-style-sheet.md`, the tests in Task 8.4, and `deferred-work.md`.
- Variance: the architecture says "`PetSlot` in HUD and report card instances the pet's idle `SpriteFrames`". This story's `PetSlot` assigns the item's `SpriteFrames` to its own `AnimatedSprite2D` (same effect, no scene per pet) and adds the menu placement FR26/FR43 require.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Typed GDScript everywhere (`untyped_declaration = Error`).
  - `%UniqueName` node refs; no `/root/` paths or `get_parent()` chains.
  - Typed past-tense signals, connected in code, with autoload connections dropped in `_exit_tree`. No event bus.
  - Screens change state only via `PlayerData` (and this story changes none). Static data comes through `@export` Resources (`data/` instances, `scripts/resources/` definitions; Boundary 5).
  - Debug code only in `scenes/debug/`/`scripts/debug/` (Boundary 7). Art follows the style sheet (32-colour palette, ink outline, hard alpha, 2–6 frames at 8–12 fps, Lossless, no mipmaps) and is code-generated.
  - One sprite scale in-game. NFR16: a missing cosmetic logs a warning and never stops a run.
  - Log tags: `&"cosmetics"` for the slots, `&"ui"` for the professor.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.3: Hat and Pet Display Everywhere]; FR19, FR26, FR43, FR75 (post-MVP scope line); NFR10, NFR13, NFR16
- [Source: _bmad-output/game-architecture.md] D6 Cosmetic Anchoring, Static Game Data (`SpriteAnchors`), Cosmetics, Error Handling ("never let a missing … cosmetic stop a run"), Logging (DEBUG for anchor positions), Event System (disconnect in `_exit_tree`), Directory Structure (`data/anchors/`, `scenes/cosmetics/`, `scripts/cosmetics/`), Naming (`hat_<name>.png`, `pet_<name>_idle.png`), Architectural Boundaries 2/5/7, Data Patterns, Consistency Rules
- [Source: _bmad-output/planning-artifacts/gdds/.../gdd.md] cosmetic slots (l.150), the MVP art list "Pumpkin hat (overlay); Cute ghost pet (idle float 4f)" (l.409), "overlays anchored to a head point" (l.370)
- [Source: …/ux-designs/…/DESIGN.md] Components → pet-slot (parchment cushion, 64 px), hat-slot ("No chrome; overlay sprite anchored to the zombie head point"), "Pet slot / hat slot" (empty shows only the cushion; mortarboard stacks on the hat, D16)
- [Source: …/ux-designs/…/EXPERIENCE.md] Component Patterns "pet-slot / hat-slot" (update everywhere at once; empty shows nothing; missing texture never stops a run), Main Menu state rows (fresh save: no hat or pet), HUD hierarchy (pet = delight, idle only)
- [Source: …/sketches/hud-band-2-5.md] pet slot 0/256/64/104 and cushion 8/300/48/48
- [Source: docs/art-style-sheet.md] §§ 1, 2, 3, 5, 6
- [Source: _bmad-output/implementation-artifacts/2-9-chalkboard-report-card.md] professor slots, mortarboard order, D16
- [Source: _bmad-output/implementation-artifacts/3-6-sunny-village-green-and-zombie-run-art.md] art generator pattern, approval flow
- [Source: _bmad-output/implementation-artifacts/4-1-…md, 4-2-main-menu.md] `PlayerData` equipment API, menu `%PetSpot`, seams
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 2.9 and 3.6 items closed by this story
- [Source: scripts/characters/player_zombie.gd, professor_zombie.gd], [Source: scenes/characters/*.tscn], [Source: scripts/autoloads/player_data.gd#equip/unequip/get_equipped], [Source: scripts/resources/cosmetic_item.gd, catalogue.gd], [Source: scenes/run/hud.tscn], [Source: tools/gen_zombie_run_art.gd], [Source: tests/unit/test_art_sprites.gd]

## Art Approval

<!-- Smuck records approval of the Pumpkin hat, the Cute ghost and the fit-check screenshots here (Task 9.3). -->

Approved by Smuck on 2026-10-05: the Pumpkin hat, the Cute ghost and the fit (screenshots `screenshots/4-3-*.png`).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (measured at `1cb89a9` in a scratch worktree): 980 tests, all passing. Final: **1050 tests, all passing** (61 scripts, 37170 asserts). +70 tests: 4 new files (`test_sprite_anchors` 10, `test_hat_slot` 26, `test_pet_slot` 16, `test_hat_fit_check` 9 = 61) plus 9 net new tests in the updated files (10 added, 1 renamed).
- The first run after writing the tests had 6 failures. Four were test mistakes: GUT's `assert_push_warning_count` also counts warnings already matched by `assert_push_warning`, so the "once" checks are now `count(1)`; and the frames-swap test reused the scene's shared `SpriteFrames`, so no signal fired. Two pointed at a real Godot quirk (below).
- **Godot quirk found:** `AnimatedSprite2D` emits `animation_changed` *before* it resets the frame index. Going from dance frame 3 to hop, the slot read "hop 3" for a moment and would log a spurious "no anchor" warning in a real run. `_follow()` now skips an index past the new animation's end, and the reset's `frame_changed` lands the hat. `test_switching_to_a_shorter_animation_never_warns` covers it.
- **Mutation pass (14 mutations, all caught):** drop the `animation_changed` connection (3 tests fail), ignore the hat slot filter (1), ignore the pet slot filter (1), forget `profile_replaced` on the hat (2) and the pet (1), skip the hat (1) and pet (1) `_exit_tree` disconnect, forget the `flip_h` mirror (1), break the hug-squeeze anchor in the `.tres` (4), lift the mortarboard by 0 (2), `push_error` instead of warn for a missing overlay (1) and missing pet frames (1), drop the transient-frame skip (1), and remove warn-once (3). None survived.
- The anchors were generated by `tools/gen_sprite_anchors.gd` (measures the PNGs with the test's rule). The output matches the Dev Notes table exactly.
- Manual-check screenshots came from a scratch capture script running the real game windowed. It typed one Zombie Run at 6.25 keys/s. That run recorded a bot "new best" (70 WPM) in the live save, so the save was backed up before and **restored after**, and only the fit check's "wear for real" was re-applied. Smuck's save is unchanged (best WPM 18, brains 59, same run history) apart from now owning and wearing the Pumpkin hat and the Cute ghost.
- Found `scripts/characters/player_zombie.gd` with CRLF in the working tree (the index is LF). Normalised to LF while editing the header.

### Completion Notes List

- `SpriteAnchors` resource (`head: Dictionary[StringName, PackedVector2Array]`, `has_head`, `get_head`, `validate`), plus `zombie_anchors.tres` (idle/walk/hop/hug/dance, 16 points) and `professor_anchors.tres` (point, 2 points). Optional generator `tools/gen_sprite_anchors.gd` committed.
- `HatSlot` (`scenes/cosmetics/hat_slot.tscn`, `scripts/cosmetics/hat_slot.gd`): follows `frame_changed`, `animation_changed` and `sprite_frames_changed`, mirrors for `flip_h`, and listens to `PlayerData.equipment_changed` (hat only) and `profile_replaced`, disconnecting in `_exit_tree`. It warns once per cause and hides, has the `follow_equipped`/`show_item` preview hook, and emits `item_shown` on every show. `get_item()` was added next to `get_item_id()` so the professor can stack the worn hat on connect: the slot's `_ready` runs before the professor's, so the first `item_shown` happens before he listens.
- `PetSlot` (`scenes/cosmetics/pet_slot.tscn`, `scripts/cosmetics/pet_slot.gd`): plays the item's `idle` with its feet at the origin. It has the same seams, filter, warnings and preview hook, and inherits `process_mode`.
- Placed: `player_zombie.tscn` `Body/HatSlot` (anchors set, hand position dropped, no logic change). `professor_zombie.tscn` `Body/HatSlot` (before `Mortarboard`) and a root `PetSlot` at (60, 30). `hud.tscn` `%Pet` inside `%PetSlot` at (32, 80). `main_menu.tscn` `%PetSlot` replaces `%PetSpot` at (84, 284). Header comments updated in `player_zombie.gd`, `hud.gd`, `main_menu.gd` and `report_card.gd`. No logic changes there.
- `professor_zombie.gd`: `_stack_mortarboard` lifts the mortarboard by the hat's rise (`SEAT.y - used_rect.position.y`, cached per id; 11 px for the pumpkin; 0 with no hat). The professor stays free of `PlayerData`.
- Art via `tools/gen_cosmetics_art.gd` (ASCII maps, `Proto` palette): `hat_pumpkin.png` (32x32, rows 19-30, x 9-22, a smiling jack-o'-lantern cap with a stem and leaf) and `pet_cute_ghost_idle.png` (4 frames of 32x32, 19 px tall, a 1 px bob plus a two-phase wavy tail, pink cheeks). Lossless, no mipmaps. `hat_pumpkin.tres` gets `overlay`, `pet_cute_ghost.tres` gets `pet_frames` (idle, 4 frames, 8 fps, loop). `icon` stays empty.
- Debug fit check (`scenes/debug/hat_fit_check.tscn`, `scripts/debug/hat_fit_check.gd`): 18 stopped cells at 1x and 3x in 4 pages. The professor cells use the real `professor_zombie.tscn`, so the mortarboard stacking is the shipped code. A pet on a 48 px cushion at 1x and 3x. Keys: H/P/B/N/E/Esc. E wears for real through the `player_data` seam.
- `docs/art-style-sheet.md`: the two sheet rows, a "Hats / Pets" paragraph, the generator list, and section 6's anchors note in the past tense pointing at `data/anchors/`. `test_art_style_sheet.gd` doesn't pin the table, so it is unchanged.
- `deferred-work.md`: struck the 2.9 and 3.6 items ("Done in 4.3"). Added a "dev of story 4-3" section: debug log volume, connect-once in `_ready`, the screen seams not reaching the slots, the Godot quirk, and the fit check's E writing the real save.
- Smuck approved the art on 2026-10-05 (Task 9.3). The story is ready for review.

### File List

New:
- `scripts/resources/sprite_anchors.gd` (+ `.uid`)
- `data/anchors/zombie_anchors.tres`
- `data/anchors/professor_anchors.tres`
- `scenes/cosmetics/hat_slot.tscn`
- `scenes/cosmetics/pet_slot.tscn`
- `scripts/cosmetics/hat_slot.gd` (+ `.uid`)
- `scripts/cosmetics/pet_slot.gd` (+ `.uid`)
- `scenes/debug/hat_fit_check.tscn`
- `scripts/debug/hat_fit_check.gd` (+ `.uid`)
- `tools/gen_cosmetics_art.gd` (+ `.uid`)
- `tools/gen_sprite_anchors.gd` (+ `.uid`)
- `assets/sprites/cosmetics/hats/hat_pumpkin.png` (+ `.import`)
- `assets/sprites/cosmetics/pets/pet_cute_ghost_idle.png` (+ `.import`)
- `tests/unit/test_sprite_anchors.gd` (+ `.uid`)
- `tests/unit/test_hat_slot.gd` (+ `.uid`)
- `tests/unit/test_pet_slot.gd` (+ `.uid`)
- `tests/unit/test_hat_fit_check.gd` (+ `.uid`)
- `_bmad-output/implementation-artifacts/screenshots/4-3-hat-fit-check.png`, `4-3-hat-fit-check-professor.png`, `4-3-hat-fit-check-sky.png`, `4-3-menu.png`, `4-3-run.png`, `4-3-run-hug.png`, `4-3-report-card.png`

Modified:
- `scenes/characters/player_zombie.tscn`, `scripts/characters/player_zombie.gd` (header only; CRLF to LF)
- `scenes/characters/professor_zombie.tscn`, `scripts/characters/professor_zombie.gd`
- `scenes/run/hud.tscn`, `scripts/run/hud.gd` (header only)
- `scenes/screens/main_menu.tscn`, `scripts/screens/main_menu.gd` (header only)
- `scripts/screens/report_card.gd` (header only)
- `data/cosmetics/hat_pumpkin.tres`, `data/cosmetics/pet_cute_ghost.tres`
- `docs/art-style-sheet.md`
- `tests/unit/test_player_zombie.gd`, `test_report_card.gd`, `test_hud.gd`, `test_main_menu.gd`, `test_art_sprites.gd`, `test_catalogue.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/4-3-hat-and-pet-display-everywhere.md`

### Change Log

- 2026-10-05: Story 4.3 implemented: `SpriteAnchors` and the shipped anchor sets, `HatSlot`/`PetSlot` live on the player zombie, Professor Zombie (mortarboard stacks on the hat), the HUD cushion and the main menu, Pumpkin hat and Cute ghost art and data, the debug fit-check scene, and the docs. Tests 980 to 1050, mutation pass 14/14 caught. Awaiting Smuck's art approval.
- 2026-10-05: Art approved by Smuck. Status set to review.
