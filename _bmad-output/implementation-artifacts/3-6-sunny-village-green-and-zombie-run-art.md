---
baseline_commit: 7e2316eeba5254aba20c745968725d8bf7432ed7
---

# Story 3.6: Sunny Village Green and Zombie Run Art

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want Zombie Run to look like a bright, cheerful village,
so that the level feels calm and inviting.

## Acceptance Criteria

1. **Parallax backdrop (FR37).** The flat `Sky` / `Grass` / `Path` rects in `zombie_run_level.tscn` are replaced by the Sunny Village Green backdrop: sky, a far layer, a near layer and 16×16 ground tiles. Whenever the zombie moves (amble or scoot), the layers scroll at different speeds (clouds slowest, ground exactly with the world). Each layer tiles seamlessly, so there is never a gap or a visible seam for a whole 2:00 run at any typing speed, including the negative camera x at the start of a run.
2. **The final MVP sprite set is in the game (NFR13).** Every item below exists as a committed PNG sheet, is wired into its scene and replaces the code-drawn or missing placeholder:
   - player zombie: `idle` 2f and `walk` 4f (already approved, keep), plus new `hop` 3f, `hug` 3f and `dance` 4f;
   - villager: `wave` 2f (already approved, keep; this is the "idle/wave 2f"), plus new `poof` 4f (replaces the code-drawn `Poof`);
   - party-hat zombie: `idle` 2f (keep) plus new `walk` 4f (the conga followers use it);
   - brain block: `idle` 2f and `bonk` 3f (replaces the `Panel` + `ColorRect` block); brain pop (replaces `BrainPop._draw`); the down-arrow marker (replaces the `Polygon2D` + `Line2D` arrows in all three target scenes).
3. **Every sprite follows the approved style sheet** (`docs/art-style-sheet.md`): palette only (the 32 colors), hard alpha, 1 px `ink` outline on every silhouette edge, 2–6 frames at 8–12 fps, one ground row per sheet, Lossless import with no mipmaps. The generalized `test_art_sprites.gd` enforces it for every new sheet (sizes below). The backdrop layers and ground tiles are exempt from the outline rule only (see Dev Notes) and get their own tests.
4. **Party-hat zombie = villager recolor + hat (NFR10, NFR13).** The new `walk` sheet is built from the villager's maps and `PARTY_ZOMBIE_LEGEND` only (no new colors, no new legend characters beyond leg poses), and `test_party_zombie_is_a_recoloured_villager` is extended to the walk frames. No scary or gory detail anywhere: the poof is a white dust cloud, the brain block and pop are cartoon pink with no anatomy.
5. **Animations play at the right moments, and nothing clobbers them.** `PlayerZombie.hop()` plays `hop`, `hug()` plays `hug`, `dance()` plays `dance`, each non-looping except `dance`. While a hop, hug or dance is running, `play_walk()` / `play_idle()` do nothing (this closes the 3.2 deferral "don't clobber hop animation": the level's `_process` and `_scoot_to` call `play_walk()` every frame). When the one-shot ends, the next `play_walk()` / `play_idle()` takes over. Conga followers play `walk` while moving and `idle` while settled. The brain block plays `bonk` when typed (and holds its last frame as the used block); the villager's `poof` plays when it poofs.
6. **Readability of the target letters (named manual checklist).** With the backdrop in place, every in-world letter tag and the arrow read at 1× against every part of the backdrop. Checked with the **"Zombie Run letter readability checklist"** in Task 8 (what to look for, pass/fail per item), recorded in the Dev Agent Record. A mechanical guard backs it: the backdrop's tag band (y 96–166) contains no `parchment`, `chalk` or `candy-yellow` pixels (those are the tag and arrow colors).
7. **Kid-safe palette use.** The backdrop never uses `candy-yellow` (focus only) or `stamp-red` (stamp only). It carries the Halloween dressing from `DESIGN.md` (a pumpkin on a fence post, bat-purple bat bunting) and stays cute, not spooky.
8. **Nothing about the game changes.** Letters, layout, Brainsss rolls, timings, scoring, the conga rules, the dance and the bonus are exactly as in 3.5 (`test_run_rng_has_one_consumer` passes unchanged; the backdrop draws nothing from any RNG). Sprites are drawn at 1×, so every hit-width the level relies on still holds (`ZombieRunTarget.HALF_WIDTH` 12, the tag width, `test_full_line_fits_behind_the_zombie`).
9. **Tests and performance.** New and changed GUT tests (Task 9) pass with the full suite. A full 2:00 web debug run with 12+ followers keeps the worst frame under 33 ms (NFR1) with the new art, and the console is clean.

## Tasks / Subtasks

- [x] **Task 1: Pixel-art tool and generalized art tests (AC: 2, 3)**
  - [x] 1.1 New dev tool `tools/gen_zombie_run_art.gd` (`extends SceneTree`, run headless like `gen_art_prototypes.gd`, then `--import`). It reuses the existing legends and maps: `const Proto := preload("res://tools/gen_art_prototypes.gd")` and read `Proto.PALETTE`, `Proto.ZOMBIE_LEGEND`, `Proto.VILLAGER_LEGEND`, `Proto.PARTY_ZOMBIE_LEGEND` and the existing map constants (a `const` on a script resource is readable without instancing it; if that fails in Godot 4.7, copy the helpers into the new tool and keep one legend source). Do **not** hand-edit PNGs. Same rules as the prototype tool: ASCII maps, `.` keeps, `_` erases, a legend maps a character to a palette **name**. Non-zero exit on any bad map.
  - [x] 1.2 Frame size is no longer always 32: characters and the poof are 32×32; props (brain block, brain pop, down-arrow) are **16×16** (tile size, style sheet section 3). Add an optional `size` per sheet in the new tool (default 32).
  - [x] 1.3 `tests/unit/test_art_sprites.gd`: `SHEETS` is `path -> frame count` with `FRAME = 32` baked in. Generalize to `path -> {frames, size}` (or add a second dict `PROP_SHEETS` with `PROP_FRAME = 16`) and add every new sheet from Task 2 and Task 3. Keep every existing assertion for the existing sheets (do not weaken them). The one-frame overlay path (`OVERLAYS`) is reused for the down-arrow (1 frame, 16×16): it must also be allowed a size. Update the "frame count 2–6" check so one-frame overlays stay exempt as today.
  - [x] 1.4 `docs/art-style-sheet.md`: update section 3 (props 16×16, the poof 32×32, backdrop layers and ground tiles exempt from the outline rule but hard-alpha and palette-only, the new sheet list with frames and fps, new file paths) and the "current prototypes" sentence; section 1's "waits for approval" list drops the 3.x frames now made. Keep the rules that tests quote word-for-word in step with the test text.
  - [x] 1.5 `scripts/debug/art_review.gd` `ANIMATIONS` and `tests/unit/test_art_review.gd`: add the new animations (hop, hug, dance, poof, party_walk, block_idle, block_bonk, brain_pop) so Smuck can review them at 1× and 3×. Read both files first; follow their pattern (names are keys, fps constants).

- [x] **Task 2: Character sheets (AC: 2–4)** — all 32×32, soles on the sheet's ground row (30) in every frame of a sheet, flat crown on the zombie kept (hats anchor there in 4.3)
  - [x] 2.1 `assets/sprites/characters/zombie/zombie_hop.png`, **3 frames**: crouch/launch, peak (arms up, legs tucked), land. The code already lifts `Body` by the hop arc, so draw the frames **grounded** (same soles row in all three, body squash and stretch plus arm and leg poses), and let the tween do the lift (a lift drawn into the pixels would double up, and the ground-row test then needs no exception).
  - [x] 2.2 `zombie_hug.png`, **3 frames**: reach (arms out forward), squeeze (arms wrapped, slight lean), release. Grounded (same soles row). The villager stands 24 px ahead, so the arms stay inside the 32 px frame (forward edge x ≤ 30).
  - [x] 2.3 `zombie_dance.png`, **4 frames**, plays looping at **8 fps**: one cycle is 0.5 s, exactly one bounce of `DANCE_BEAT_HZ = 2.0`, so the sprite's sway and the code bounce stay in step. Arms up left, up right, up both, down (or similar); cute and goofy.
  - [x] 2.4 `assets/sprites/characters/villager/villager_poof.png`, **4 frames** (32×32, play once, 12 fps, as `Poof.FPS`): a small puff, a big puff over the villager's body, the big puff breaking up, a few tiny puffs. `chalk` fill, `stone-light` shade, `ink` outline; never wider than **24 px** per frame (the tag width, `HALF_WIDTH`). Keep the same soles row (30) in all frames: the cloud rests on the ground line and rises, so it passes the "one ground line" test.
  - [x] 2.5 `assets/sprites/characters/party_zombie/party_zombie_walk.png`, **4 frames** at **10 fps** (like the zombie walk): the party zombie's head, hat (tilt the pom-pom between frames like the idle), hanging arms and clothes from the villager maps, with four leg poses (contact, passing, contact, passing; the same swap pattern as `WALK_A/B`, `PASS_A/B` for the zombie). Only `PARTY_ZOMBIE_LEGEND` colors.
  - [x] 2.6 Import settings as the existing sheets (`.import` files committed: `compress/mode=0`, no mipmaps). Each new PNG is committed with its `.import` and `.uid` files, LF where text.

- [x] **Task 3: Prop sheets (AC: 2, 3)** — 16×16 frames, `assets/sprites/props/`
  - [x] 3.1 `brain_block_idle.png`, **2 frames** at 8 fps: a pink block (`art-brain-pink`, `art-brain-shade` band, `ink` outline) with a tiny sparkle or blink between frames. Same bottom row in both frames. Cute, not anatomical (no folds that read as a real brain).
  - [x] 3.2 `brain_block_bonk.png`, **3 frames**, play once at 12 fps: squash, rebound, settle as the **used** block (`stone-light` and `stone`, no pink: it replaces the code `USED_FILL`/`Band` look). Its last frame is the held used look. Same bottom row in all 3 (the node-level `%Lift` tween still does the up-and-back nudge).
  - [x] 3.3 `brain_pop.png`, **2 frames** at 8 fps: the pink cartoon brain from `BrainPop._draw`, a 1-px bobbed variant on frame 2. At most 10 px wide.
  - [x] 3.4 `down_arrow.png`, **1 frame** (overlay): the candy-yellow down-arrow with an `ink` outline, about 10×7 px, in a 16×16 cell. The bob stays code (`ZombieRunTarget._process`).
  - [x] 3.5 One 16×16 frame at 1× is the on-screen size; the old block was 16×16 with its bottom edge at `%Lift` y 0: keep that (`BLOCK_SIZE_PX = 16`).

- [x] **Task 4: Backdrop art and the scrolling backdrop (AC: 1, 6, 7)**
  - [x] 4.1 Generator output in `assets/sprites/backdrops/sunny_village_green/`:
    - `ground_tiles.png`: a strip of 16×16 tiles (grass, grass tuft, grass with a small flower, path). Seamless on every edge by design (tile edges match when repeated).
    - `ground_strip.png`: **640×64**, composed by the tool from `ground_tiles.png` with a fixed pattern (no randomness, no RNG: a hard-coded index map in the tool). Row 0 is the path strip at the playfield's ground line (y 192), rows 1–3 are grass (to y 256, where the HUD band starts). Soles must read as standing on the path.
    - `near.png`, `far.png`, `clouds.png`: **640 px wide** each (period = 640 so two copies always cover the screen), heights fit y 0–192. Author with **wraparound** (every feature drawn at x and x±640 so nothing is clipped at the seam).
      - far: soft rolling hills in `chalk-dim` with a `zombie-green` crest over the sky (review: accepted; solid `zombie-green` put skin on its own colour), a few distant tiny houses/windmill silhouettes in `stone-light`; no outline needed.
      - near: village cottages (`wood`, `wood-dark` roofs, `stone` chimneys), a fence with a **pumpkin on a post** (`pumpkin`/`pumpkin-light`), a round tree (`zombie-green-dark` / `wood`), and a **bat bunting** string across the top (`bat-purple` triangles). Keep the **tag band y 96–166** free of `parchment`, `chalk`, `candy-yellow` and large flat light areas; put the roofs and wall tones in `wood`/`wood-light`/`stone`.
      - clouds: `art-sky-light` clouds on a transparent layer over the flat `art-sky` fill.
    - Allowed colors: the 32 palette colors; **never** `candy-yellow` or `stamp-red` in the backdrop. Hard pixels only: no gradient, no glow.
  - [x] 4.2 `scripts/levels/zombie_run/sunny_village_backdrop.gd` (`class_name SunnyVillageBackdrop`, `extends Node2D`, typed GDScript): one layer = a `Node2D` holding **two `Sprite2D` copies** of the same 640-wide texture side by side (`centered = false`, no region, no repeat flags, so there is no float-repeat risk). API: `scroll_to(camera_x: float) -> void`, `get_layer_offset(layer: StringName) -> float` (tests). For each layer: `offset = fposmod(roundf(camera_x * factor), PERIOD)`; copy A at `-offset`, copy B at `PERIOD - offset`. Use `roundf` (not `floorf`) to match the project's pixel snapping, so the ground layer (factor 1.0) never slides against `%World` (whose position is snapped by `snap_2d_transforms_to_pixel`).
    - Factors are look values in named consts with a "look value, not a GDD number" comment: `FAR_FACTOR = 0.25`, `NEAR_FACTOR = 0.5`, `CLOUD_FACTOR = 0.1`, ground `1.0`. **Regex guard:** `test_no_tuning_literals_in_level_scripts` bans `\b(120|0\.15|26|0\.35|48|0\.2)\b` in `scripts/levels/zombie_run/*.gd`; `0.25`, `0.5`, `0.1` and `640` are fine (the regex needs a word boundary right after `0.2`); don't write `0.2`, `48`, `120`, `26` or `0.35`.
    - No `_process`, no tween, no timer: it moves only when the level calls `scroll_to`. No per-frame allocation, no logging. Missing textures: a `Log.warn` once and keep running (NFR16).
  - [x] 4.3 `zombie_run_level.tscn`: under `Backdrop`, keep `Sky` (a `ColorRect`, `art-sky`, 0–192, static), remove `Grass` and `Path`, add the layers in this draw order: clouds, far, near, ground (all behind `%World`). Pixel snapping for the layer sprites: whole-pixel positions only.
  - [x] 4.4 `zombie_run_level.gd`: `@onready var _backdrop: SunnyVillageBackdrop = %Backdrop` (add `unique_name_in_owner` on the node) and, inside `_set_zombie_x(x)`, one more line: `_backdrop.scroll_to(x - ZOMBIE_SCREEN_X)`. Both the amble and the scoot already go through `_set_zombie_x`, so the backdrop follows with no other code. `get_camera_x()` is the single source of the camera. Add a short backdrop paragraph to the class doc and drop "real backdrop" from "Later stories" (leave groans, 3.7).
  - [x] 4.5 Do **not** touch `create_target_source`, the RNG order, `_spawn`, the brains logic, the dance or `_free_off_screen`.

- [x] **Task 5: Animations in the scenes (AC: 2, 5)**
  - [x] 5.1 `player_zombie.tscn`: add `hop` (3f, 10 fps, loop off), `hug` (3f, 10 fps, loop off), `dance` (4f, 8 fps, loop on) `SpriteFrames` animations (one `AtlasTexture` per frame, the pattern already in the scene).
  - [x] 5.2 `player_zombie.gd`: `const ANIM_HOP` and `ANIM_HUG` (next to `ANIM_DANCE`). `hop()` plays `hop`, `hug()` plays `hug`, `dance()` already plays `dance` when present: when it is present, **drop the `flip_h` beat** (the sheet carries the sway) but keep the y bounce. Guard each with `has_animation` and a null `sprite_frames` check (same style as `dance()`). **Clobber guard:** `_play()` returns immediately while `is_hopping() or is_hugging() or is_dancing()`. `stop_hop()` / `stop_hug()` do not change the animation (the next `play_*` after the one-shot ends restores it). A hug started during a hop lets the hop's animation win only until the hop ends; a block key still cuts the hug and hops.
  - [x] 5.3 `party_zombie.tscn` / `party_zombie.gd`: add `walk` (4f, 10 fps, loop on) and a `play_walk()` mirroring `play_idle()`. Update the header (idle plus walk, Story 3.6).
  - [x] 5.4 `conga_line.gd`: each follower plays `walk` while it is moving and `idle` while settled. Decide "moving" from the follower's own x change in `step()`: `abs(new_x - old_x) / delta > WALK_SPEED_MIN_PX_S` (a named look const, with no `0.2`/`48`-style literal). Keep the code bob (the index-phased wave is the conga read; the legs do the rest). During the dance (`_dancing`) followers play `idle` plus the existing code bounce and flip: **decision: no party-zombie dance sheet** (not in the GDD sprite list; closes the 3.5 deferral).
  - [x] 5.5 `brain_block.tscn` / `brain_block.gd`: replace `%Block` (`Panel`) and `%Band` (`ColorRect`) with `%Sprite` (an `AnimatedSprite2D`, `centered = false`, at (-8, -16), `idle` autoplay, `bonk` once). `_on_resolved()` plays `bonk` instead of `_apply_used_look()` and the sprite's last frame is the used look; `is_used()` stays `is_resolved()`. Remove `USED_FILL` (no longer used) and update `test_brain_block.gd` accordingly. Keep `%Lift`, `%Visual`, `%Tag`, `%Letter`, `%Arrow`, `BLOCK_SIZE_PX`, `BONK_*`, `get_bonk_tween()` and the pop spawn (the pop still starts at `(0, -BLOCK_SIZE_PX)` in `%Lift`).
  - [x] 5.6 `brain_pop.gd` / `brain_pop.tscn`: replace `_draw()` with an `AnimatedSprite2D` playing `brain_pop` (2f, 8 fps, loop on) at (-8, -15) so the origin stays the brain's bottom centre; keep the rise tween, `RISE_PX`, `RISE_TIME_S` and `get_tween()`.
  - [x] 5.7 `poof.gd` / `poof.tscn`: replace `_draw()`, `puffs()`, the colour consts and `PUFFS` with an `AnimatedSprite2D` (`villager_poof.png`, 4f). Keep `FRAMES = 4`, `FPS = 12.0`, the tween-driven `_set_frame` (set `sprite.frame` instead of `queue_redraw()`), `finished`, `get_frame()`, `get_tween()` and the self-free on finish (tests drive it with `custom_step`). The poof now draws from the feet (origin at the feet centre, `Body` at (-16, -31) like every character), so `Villager.POOF_Y` becomes 0.0 (or remove the constant and its use).
  - [x] 5.8 The three target scenes' `%Arrow`: replace the `Polygon2D` + `Line2D` pair with a `Sprite2D` of `down_arrow.png` (`centered = false`), positioned so the **tip stays where it is today** (generic target −50, brain block −46, villager −57; the tag top is 4 px below the tip). Keep `%Arrow` as the unique-named `Node2D` parent (tests read `visible` on it).
  - [x] 5.9 `zombie_run_target.gd` and `test_zombie_run_target.gd`: the generic target stays the placeholder box (`%Box`) and the base class; only its arrow changes. Update its docs: "candy-yellow down-arrow" becomes the sprite.
  - [x] 5.10 `villager.tscn`: unchanged except the arrow (it keeps `wave` and the hidden `PartyZombie`).

- [x] **Task 6: Backdrop tests (AC: 1, 6, 7)**
  - [x] 6.1 `tests/unit/test_art_backdrop.gd` (reads PNG bytes like `test_art_sprites.gd`): each layer and the ground tiles exist at the expected size (layers 640 wide, height ≤ 192; `ground_strip` 640×64; `ground_tiles` width and height multiples of 16); hard alpha; palette only; **no `candy-yellow` or `stamp-red`**; the tag band (y 96–166) of `far` and `near` has no `parchment`, `chalk` or `candy-yellow`; **seam check**: for every row, pixel x 0 and pixel x 639 are both transparent or both opaque (a clipped feature fails it; a wrapped one passes); `ground_strip` is built from the tiles (each 16×16 cell equals one tile from `ground_tiles.png`); `.import` files are Lossless with no mipmaps.
  - [x] 6.2 `tests/unit/test_sunny_village_backdrop.gd`: `scroll_to` moves layers by their factors (rounded to whole pixels); the ground offset equals `fposmod(roundf(camera_x), 640)`; an offset is always in `[0, 640)`, including negative camera x (the run starts at about −72) and very large x (sweep 0 to 1,000,000 in steps); for every camera x in a sweep the two copies cover x 0–640 with no gap (copy A's left edge ≤ 0 and copy B's right edge ≥ 640); scrolling is deterministic and draws nothing from any RNG.
  - [x] 6.3 `tests/unit/test_zombie_run_level.gd` (new section `# --- backdrop (Story 3.6) ---`): the level's ground layer offset follows `get_camera_x()` after a key (scoot to the end with `custom_step`) and after the amble (`_level._process(0.1)` several times); the ground layer stays in step with `%World` to the pixel (offset == round of `-_world.position.x`) while scooting; `test_run_rng_has_one_consumer` and the layout/letter regression tests pass unchanged.

- [x] **Task 7: Character and prop tests (AC: 2, 4, 5)**
  - [x] 7.1 `test_art_sprites.gd`: every new sheet has the frame count, size, hard alpha, palette, outline, non-empty distinct frames, ground-row rule (hop and hug exercise the documented exception only if the frames differ; the ground-row test must still pass for them as drawn, see 2.1), import settings; `test_party_zombie_is_a_recoloured_villager` also covers `party_zombie_walk.png` (every non-leg pixel with the head, hat and clothes of the villager recolor); the poof frames are at most 24 px wide; the brain block, pop and arrow cells are at most 16 px.
  - [x] 7.2 `tests/unit/test_player_zombie.gd`: `hop()` plays `hop`, `hug()` plays `hug`, `dance()` plays `dance` (with the real scene frames, not a fake); while hopping, hugging or dancing `play_walk()` and `play_idle()` do not change the animation; after the tween ends the next `play_walk()` plays `walk`; with the real `dance` frames `flip_h` stays false during the dance and Body's y bounce still runs (the existing bounce test for a fake no-`dance` SpriteFrames keeps the flip rule); no sprite frames means no crash.
  - [x] 7.3 `tests/unit/test_party_zombie.gd`: `walk` exists with 4 frames at 10 fps, `play_walk()` and `play_idle()` switch animations and restart only on change.
  - [x] 7.4 `tests/unit/test_conga_line.gd`: a follower plays `walk` while chasing a moving leader and `idle` once settled; plays `idle` during the dance; badge and counts untouched.
  - [x] 7.5 `tests/unit/test_brain_block.gd`: replace the `%Block` / `%Band` / `USED_FILL` checks with the sprite: `idle` before the bonk, `bonk` plays once after it and ends on the used frame; `is_used()` true; the tag and arrow rules, `BLOCK_SIZE_PX` and `HALF_WIDTH` checks stay.
  - [x] 7.6 `tests/unit/test_poof.gd`: rewrite around the sheet: `FRAMES == 4`, `FPS == 12.0`, the tween steps frames 0–3 at 1/12 s, `finished` fires once after the last frame and the node frees itself, never past the last frame; every frame of the sheet is at most 24 px wide (read the PNG). Drop `puffs()` and the colour-const tests with the code that went.
  - [x] 7.7 `tests/unit/test_villager.gd` and `tests/unit/test_zombie_run_level.gd`: `Poof.FRAMES / Poof.FPS` stays valid; fix the poof position check if it asserted `POOF_Y`; add one assertion that the poof is at the villager's feet origin.
  - [x] 7.8 `tests/unit/test_brain_pop.gd` (new if none exists; check first): the rise, the frame animation, the free on finish, the bottom-centre origin.

- [x] **Task 8: Manual checks (AC: 1, 5, 6, 9)** — Godot MCP `run_project` + `get_debug_output` for load errors (the MCP cannot type: mark that part partial, as in 3.1–3.5); web check with `--export-debug "Web" build/web/index.html`, `web-debug` on port 8060, the in-app browser driven with `key` presses (the pane's `type` is ignored). Save screenshots to `_bmad-output/implementation-artifacts/screenshots/3-6/`.
  - [x] 8.1 **Zombie Run letter readability checklist** (AC 6). Look at 1× (the 640×360 canvas, not zoomed), pass/fail each, record in the Dev Agent Record:
    1. Each active-target letter on its parchment tag is readable over the far hills.
    2. The same over the cottages, fence and pumpkin (the busiest part of the near layer), for a villager tag (y ~139–163) and a brain block tag (y ~102–126).
    3. The same over the clouds and bunting.
    4. The candy-yellow down-arrow is clearly visible against the sky, the hills and the cottages (not lost on any part).
    5. A resolved target (grey/used block, party zombie) does not look like a target to type.
    6. The tag's ink outline separates it from every backdrop part; no backdrop element looks like a letter or a second tag.
    7. The HUD target letter (top left) is unaffected.
    8. Characters (zombie, villager, party zombies) read by silhouette against the near layer, not only by fill (the 1.9 note about dark backdrops does not apply here, but check the cottages).
    Pass means all eight pass. Any fail: adjust the art (move or recolor the offender), regenerate, re-check.
  - [x] 8.2 **Scrolling check**: a full 2:00 run (and F6 early): the layers scroll at different speeds, nothing tears at the 640 px seam, no flicker, the ground slides exactly with the targets (a target never swims on the ground), the run never shows a gap at any speed (type a fast burst of 10 keys and a long pause).
  - [x] 8.3 **Animation check**: hop plays on a block key (and the zombie is not walking mid-hop), hug on a villager key, dance for 2 s at the end, poof dust cloud, party zombies walking in the line, and the bonk block turning grey.
  - [x] 8.4 Tone check: cute, not scary; no gore; the backdrop reads sunny and calm.
  - [x] 8.5 Perf (NFR1): a full 2:00 run with 12+ followers, worst frame under 33 ms (the 3.4 method: `frame_tracker`/F3 overlay worst frame), console clean.

- [x] **Task 9: Wrap-up**
  - [x] 9.1 Full suite, headless: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. **Confirm the baseline yourself at `7e2316e`** (3.5 had review patches; report real numbers). Expect 0 `Parse Error`, the 3 expected villager-assert `SCRIPT ERROR` lines (`test_villager.gd`), 50 anchor warnings (new animations may change the anchor-warning count: report the difference honestly), nothing new.
  - [x] 9.2 Mutation habit (break once, confirm a test fails, restore, report honestly): the ground layer factor 0.9 instead of 1.0; the offset not wrapped (no `fposmod`); `floorf` instead of `roundf`; `_play()` guard removed; the arrow fill changed to a non-palette color; a `candy-yellow` pixel added to `near.png`; `Poof.FRAMES` mismatch with the sheet.
  - [x] 9.3 `deferred-work.md` "Deferred from: dev of story-3-6": record what is left (party-zombie dance sheet decided no; no groans/SFX (3.7/5.1); anchors for hats on the new frames (4.3); the 5.0 art pass for the HUD/UI; any checklist item accepted rather than fixed). Mark done with `~~…~~ Done in 3.6: …` the earlier entries this story closes: the 3.1 "Placeholder visuals … backdrop and parallax art = Story 3.6" and "Optional ground tick marks"; the 3.2 "Placeholder brain block, bonk, brain pop and hop arc" (the hop frames and the "don't clobber hop animation" guard) and "hop was not visible"; the 3.3 "hug is a placeholder 3 px lean" (the hug frames now play; the 3 px lean stays as motion) and "party-hat zombie is an idle-only prototype"; the 3.4 "followers use idle frames plus a code bob"; the 3.5 "code dance until 3.6's dance 4f".
  - [x] 9.4 Dev Agent Record, File List and Change Log; Status → `review`, and `sprint-status.yaml` → `review`.

### Review Findings

- [x] [Review][Patch] Far hills are `chalk-dim` with a `zombie-green` crest (decision: accept) — update Task 4.1 / AC 6-7 spec text to match the shipped art
- [x] [Review][Decision] Manual checks and perf waived but ticked `[x]` — resolved: accepted (waiver stands; perf re-run in Story 5.3), tasks stay ticked
- [x] [Review][Patch] Move the pumpkin (decision: move) so it is on a fence post per AC 7 / Task 4.1 without overlapping a character head at run start or reading as a hat; regenerate the near layer via `tools/gen_zombie_run_art.gd`, fix the generator comment [tools/gen_zombie_run_art.gd:~3837-4095]
- [x] [Review][Patch] Hug frames never start if a hop is cut while a hug waits (`stop_hop` bypasses `_end_hop`) [scripts/characters/player_zombie.gd:101-128]; add a test that `hop()` itself cuts a hug
- [x] [Review][Patch] Dance animation keeps looping after the dance tween ends; `_reset_dance` never changes the animation [scripts/characters/player_zombie.gd:165-181]
- [x] [Review][Patch] `test_used_look` waits on wall-clock `wait_seconds(0.4)` for a 0.25 s animation; drive it with `custom_step` like the other tests [tests/unit/test_brain_block.gd:~1872-1898]
- [x] [Review][Patch] Poof header comment says the cloud "rises" but frames 1-3 do not (Task 2.4); fix the comment or redraw [scripts/levels/zombie_run/poof.gd:header]
- [x] [Review][Patch] `size` shadows `Control.size` in `build_frames` and `_build_specimen` [scripts/debug/art_review.gd:~886-966]
- [x] [Review][Patch] `%Backdrop` is a hard dependency in `_set_zombie_x`; null-guard it per NFR16 [scripts/levels/zombie_run/zombie_run_level.gd:~266-269]
- [x] [Review][Patch] Arrow tip row documented as row 14 but tests use `+ Vector2(8, 15)`; align the comments and share the copy-pasted `_assert_arrow_tip` helper [tests/unit/test_villager.gd, tests/unit/test_zombie_run_target.gd]
- [x] [Review][Patch] `test_seam_rows_match` compares alpha only — no change to the check (x 0 and x 639 are neighbours, so an outline beside fill is correct); documented the intent in a comment [tests/unit/test_art_backdrop.gd]
- [x] [Review][Defer] Re-hug, re-hop and `_end_hop` restart the sheet from frame 0 while the lean resumes mid-arc [scripts/characters/player_zombie.gd:106-128] — deferred, cosmetic
- [x] [Review][Defer] No hysteresis on the follower walk/idle threshold (4 px/s); may flicker at easing transitions [scripts/levels/zombie_run/conga_line.gd:124-127] — deferred, only at transitions
- [x] [Review][Defer] Ground layer `roundf` vs renderer snap at exact .5 camera x (snap setting is on; no tie test) [scripts/levels/zombie_run/sunny_village_backdrop.gd:~2709] — deferred, unverified
- [x] [Review][Defer] Art-review pages read the static `ANIMATIONS` list even if a sheet fails to load [scripts/debug/art_review.gd:~199-230] — deferred, debug tool only

## Dev Notes

### What this story is (and isn't)

- It turns the Zombie Run placeholders into the final MVP art: a parallax village backdrop plus the hop, hug, dance, poof, party walk, brain block, brain pop and arrow sprites, and the code to play them. **Gameplay does not change.**
- **New files:** `tools/gen_zombie_run_art.gd`, `scripts/levels/zombie_run/sunny_village_backdrop.gd`, the PNGs (and their `.import` files) under `assets/sprites/{characters,props,backdrops/sunny_village_green}/`, `tests/unit/test_art_backdrop.gd`, `tests/unit/test_sunny_village_backdrop.gd`, maybe `tests/unit/test_brain_pop.gd`, screenshots.
- **Updated files:** `zombie_run_level.tscn` / `.gd`; `player_zombie.tscn` / `.gd`; `party_zombie.tscn` / `.gd`; `conga_line.gd`; `brain_block.tscn` / `.gd`; `brain_pop.tscn` / `.gd`; `poof.tscn` / `.gd`; `villager.tscn` / `.gd`; `zombie_run_target.tscn` / `.gd`; `docs/art-style-sheet.md`; `scripts/debug/art_review.gd`; `tests/unit/test_art_sprites.gd` and the tests named in Tasks 6–7; `deferred-work.md`; `sprint-status.yaml`.
- **Don't build:** the final HUD, pause panel, report card, menu or button art (5.0); hat/pet anchors and cosmetics (4.3); groans, `start_ambience` (3.7); any audio (5.1); a second backdrop or theme rotation (Epic 10); a party-zombie dance sheet; per-level sprite variants; any change to `PlayerData`, `RunResult`, `RunFrame`, `LevelBase`, `Router`, `TypingInput` or the save schema.

### Key design decisions (follow these)

- **Backdrop is outside `%World`; the level scrolls it, nothing else does.** The HUD, pause panel and countdown share the canvas layer with `%LevelHost`, so a `Camera2D` would scroll them too (3.1 decision). `_set_zombie_x()` is already the one place the camera moves, so one `scroll_to()` call there keeps backdrop, world and zombie in lock step (no one-frame lag).
- **Two copies of a 640 px texture, not region repeat.** Region tiling with `texture_repeat` is easy to get wrong in the web (Compatibility) renderer, and at sub-pixel offsets it shimmers. Two integer-positioned sprites are boring and exact.
- **Wraparound authoring is the seamlessness guarantee**, the seam test is a cheap heuristic, and the 2:00 manual scroll check (8.2) is the real proof. Put features across the seam deliberately (a cloud over the edge) so the heuristic means something.
- **`roundf`, not `floorf`.** `snap_2d_transforms_to_pixel` rounds node positions; a `floorf` ground would drift against `%World` by 1 px about half the time and targets would appear to swim on the path.
- **Sprites are drawn grounded; code does the lift.** The hop/bonk/bounce tweens already move the nodes (3.2–3.5). Frames that also lift would double the motion and break the ground-row test. Frames carry pose (squash, arms, legs).
- **One animation owner at a time.** `_play()` is called every frame by the level and again by `_scoot_to`; without the guard the `hop`/`hug` animations are overwritten the same frame. The guard keys off the tweens' `is_running()`, so a cut hop (`stop_hop`) releases it immediately.
- **No new colors.** The palette is full (32). Anything new is built from the 32 names; the tests prove it.
- **Dance at 8 fps / 4f = 2 Hz**, so the sprite cycle and the code bounce (`DANCE_BEAT_HZ`) agree. With real dance frames the `flip_h` beat goes; the fake-frames path keeps it (tests exist for both).

### Existing code: current state, what changes, what must be preserved

- **`zombie_run_level.tscn`**: `Backdrop` holds three `ColorRect`s (Sky 0–192, Grass 192–256, Path 192–200); `%World` holds `%Targets`, `%CongaLine`, `%Zombie`. **Change:** Backdrop contents (Sky stays); add `unique_name_in_owner` to `Backdrop`. **Preserve:** the node names and order of `%World` children.
- **`zombie_run_level.gd`**: `GROUND_Y = 192`, `ZOMBIE_SCREEN_X = 224`, `_set_zombie_x()` moves zombie and world, `on_run_ending` stops the scoot and dances, `_process` ambles and switches walk/idle (returns early when `_dancing`). **Change:** one `scroll_to` line, an `@onready`, docs. **Preserve:** everything else.
- **`player_zombie.gd`**: `hop` (tween on Body y), `hug` (Body x), `dance` (y bounce plus flip, plays `dance` if present else `idle`), `_play()` restarts only on a change. `SpriteFrames` has `idle` 2f and `walk` 4f. **Change:** the three animations, the guard, the flip rule. **Preserve:** tween ownership (hop y, hug x, dance y + flip), `SIZE_PX`, anchors (`%HatSlot` at (16, 1) on Body).
- **`conga_line.gd`**: `step()` chases slots, bobs, faces, dances; badge rides the last follower; time accumulates from `delta`. **Change:** the follower animation choice only. **Preserve:** spacing 16, chase, bob, cap, "never shrinks", no RNG.
- **`brain_block.gd`**: `%Lift` / `%Visual` / `%Tag` / `%Arrow`, `_on_resolved()` returns brains and pops a `BrainPop`. **Change:** the visuals (`%Block`/`%Band` → `%Sprite`).
- **`poof.gd`**: tween-driven frames + `finished`, code-drawn. **Change:** drawing only. **Preserve:** the API the villager and the tests use (`FRAMES`, `FPS`, `get_frame`, `get_tween`, `finished`).
- **`villager.gd`**: HUGGED → POOFED → `poofed(party_zombie)`; `POOF_Y` -14 places the code cloud. **Change:** `POOF_Y` (the sheet is feet-anchored) and nothing else.
- **`HUD`/screen layout**: the playfield is y 0–256, the HUD band is y 256–360 (`test_hud` pins `%Band` at (0, 256, 640, 104)); the Caps Lock hint is at y 196–224, the start prompt strip at 228–252, both **over** the ground strip. The ground strip is plain enough that those parchment/ink texts stay readable: check it in 8.1.

### Testing notes

- GUT 9.7.1; no new `class_name` other than `SunnyVillageBackdrop` (run `--import` before the suite).
- Art tests read PNG bytes with `Image.load_from_file` (import state doesn't matter), like `test_art_sprites.gd`. `ground_strip` ↔ `ground_tiles` equality is a pixel compare of 16×16 cells.
- Node-bound tweens: advance with `get_*_tween().custom_step(dt)` on process-disabled nodes (the existing pattern).
- Keep every touched text file LF (`.gitattributes` `eol=lf`). Commit the PNGs, `.import` and `.uid` files.
- `assert` in headless GUT logs a `SCRIPT ERROR` and doesn't abort: use `Log` plus safe returns in code the tests reach.

### Previous story intelligence (3.5 and earlier)

- 3.5 left `PlayerZombie.dance()` ready for a `dance` animation, `Body` rests at (-16, -31), `centered = false`, so `flip_h` mirrors around the feet. Your sheets use the same 32×32 frame with soles on row 30.
- The baseline test count is often a few off the story's figure: confirm it at the baseline commit yourself.
- Mutation passes found rules no test could catch (3.4 clamp): report honestly rather than forcing a test.
- Short motions (hop 0.35 s, 16 px) were hard to see in browser-pane screenshots: step the tween in a test and look at the `hop`/`hug` frames in the art review scene at 3×, then confirm in the web build.
- The art-review scene (Task 1.5) is the place Smuck judges new frames; add the animations there even though the 1.9 gate is already passed.
- 1.9 note: on `night` and `chalkboard` backgrounds the ink outline barely separates; the daytime village does not have that problem, but the cottage roofs (`wood-dark`) are the closest to ink: check them in 8.1 item 8.
- Reuse rules (style sheet section 6): party-hat zombie = villager recolor plus hat; never introduce a new skin color.

### Git intelligence

- One commit per story; HEAD is `7e2316e Story 3.5: run end dance and brains award` and the working tree was clean at story creation. Suggested message: `Story 3.6: Sunny Village Green and Zombie Run art`.
- Recent commits (3.1–3.5) touched `scripts/levels/zombie_run/*`, `scripts/characters/*`, `scenes/**`, the matching `tests/unit/test_*.gd`, `deferred-work.md` and `sprint-status.yaml`; art in 1.9/2.9/3.3 came from `tools/gen_art_prototypes.gd` plus `tests/unit/test_art_sprites.gd`.

### Project Structure Notes

- Sprites: characters in `assets/sprites/characters/<subject>/`, props in `assets/sprites/props/`, backdrop in `assets/sprites/backdrops/sunny_village_green/` (the architecture's tree). File names `<subject>_<animation>.png`; the backdrop layers are `far.png`, `near.png`, `clouds.png`, `ground_tiles.png`, `ground_strip.png`.
- Scenes mirror scripts: backdrop script `scripts/levels/zombie_run/sunny_village_backdrop.gd`; no separate scene (the layers are children of `Backdrop` in the level scene).
- `docs/` is excluded from the export presets; the style sheet update does not affect the build.

### Project Context Rules

- No `project-context.md` exists in this repo. Rules carried from the architecture and earlier stories: typed GDScript with `untyped_declaration = Error`; no GDD gameplay number as a literal in a script (look values are named consts with a comment); `Log` instead of `print`, never in `_process`; no `await` in typing callbacks; no global RNG in gameplay; entities `queue_free()` off screen; NFR16 (a missing sprite never stops a run); Godot 4.7.2 Compatibility renderer, web build single-threaded; Windows paths in the shell are Git Bash (`/c/...`).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.6: Sunny Village Green and Zombie Run Art]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Zombie Run, #Art Style (sprite list: Props, Backdrop; sizes; reuse)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md#Colors, #Do's and Don'ts, in-world target tag, candy-yellow rule; the Halloween dressing on Sunny Village Green]
- [Source: _bmad-output/game-architecture.md#Project structure (assets tree), #Art standards]
- [Source: docs/art-style-sheet.md sections 2, 3, 5, 6]
- [Source: _bmad-output/implementation-artifacts/3-5-run-end-dance-and-brains-award.md (dance, level state, deferrals)]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md: stories 3.1–3.5 sections (placeholder art, hop clobber guard, conga walk, dance frames)]
- [Source: NFR1, NFR7, NFR8, NFR10, NFR13, NFR16; FR37]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline at `7e2316e` (confirmed): 50 scripts, 752 tests, 752 passing, 33,575 asserts, 0 `Parse Error`, 3 `SCRIPT ERROR` (the expected `test_villager.gd` asserts), 50 anchor warnings.
- After 3.6: 53 scripts, 813 tests, 813 passing, 35,387 asserts, 0 `Parse Error`, the same 3 `SCRIPT ERROR` lines, 50 anchor warnings (unchanged). New warnings vs the baseline come only from the new "no sprite frames" NFR16 tests that expect them (`brain block`, `poof`, one more each for `player zombie` / `party zombie`).
- `const Proto := preload("res://tools/gen_art_prototypes.gd")` works in Godot 4.7.2: the new tool reads `Proto.PALETTE`, the legends and the approved maps without instancing, so there is one legend source.
- Heredocs with apostrophes were mis-parsed by the shell wrapper in this session; edits went through small Python scripts in the scratchpad instead (no effect on the repo).
- Godot MCP `run_project` on `zombie_run_level.tscn`: clean load (Compatibility renderer, RTX 3070), no errors. Web debug console: no errors.

### Implementation Plan

- **Art tool** (`tools/gen_zombie_run_art.gd`): characters and props as ASCII maps like the prototype tool, with an optional x shift per part (the hug lean) and a `size` per sheet (32 characters/poof, 16 props). Hop, hug and dance reuse `ZOMBIE_UPPER` plus overlays (`ARM_ERASE` clears the forward arm, then raised/hanging/hugging arms); every frame is grounded on row 30. The poof maps were derived once from the old disc logic (rounder discs) and pasted in as ASCII. The party walk is the idle body + hat + four leg poses after clearing rows 24-30, with `PARTY_ZOMBIE_LEGEND` only. The backdrop is drawn from shapes at hard-coded positions with x wraparound; seam features are centred on x 0 with even-width discs so x 639 and x 0 match. The ground strip is blitted from the tiles by a fixed index map.
- **Backdrop** (`SunnyVillageBackdrop`): four layers of two `Sprite2D` copies (A at 0, B at 640), layer x = -fposmod(roundf(camera_x * factor), 640). The level calls `scroll_to(x - ZOMBIE_SCREEN_X)` inside `_set_zombie_x`, the one place the camera moves.
- **Animation ownership** (`PlayerZombie`): `_play()` returns while a hop, hug or dance runs; one-shots start via `_play_action()` (stop + play, so a restart begins at frame 0). A hug during a hop keeps the hop frames; the hop's end callback hands over to the hug frames if it is still running. With real dance frames the `flip_h` beat is off (`_dance_flips`); a stripped SpriteFrames keeps the 3.5 code flip.
- **Conga**: a follower plays walk when `abs(dx) / delta > WALK_SPEED_MIN_PX_S` (4 px/s, look value), idle otherwise and always while dancing.
- **Props**: `%Sprite` replaces the block's Panel/Band (`bonk` once, holds the used frame), the pop's `_draw`, and the poof's `_draw` (the tween sets `sprite.frame`; poof now feet-anchored, `Villager.POOF_Y` removed). All three arrows are an `Icon` Sprite2D under `%Arrow` with the tip where the polygon tip was (-50 / -46 / -57).

### Completion Notes List

- All 14 art files are generated by `tools/gen_zombie_run_art.gd` (re-running it writes byte-identical PNGs; checked with md5). Art tests: every new sheet passes size, hard alpha, palette, outline, distinct-frame and ground-row rules; the party walk's rows 0-23 equal the idle frames byte for byte.
- **Readability changes from the 1x check (deviations from the story's look notes):** far hills are `chalk-dim` with a `zombie-green` crest (solid `zombie-green` put the zombie's and party zombies' skin on their own colour), and the pumpkin first moved to a short post at x 120. Code review (2026-10-05) moved it onto a real fence post at layer x 592, which shows at screen x 64 at run start (far left of the zombie, clear of the first targets). Not re-checked by eye at 1x after that move. Both recorded in `deferred-work.md`.
- **Zombie Run letter readability checklist (8.1), at 1x on the 640x360 web canvas** (`screenshots/3-6/02`-`05`):
  1. Letters over the far hills: **pass** (o, l, s, k tags over the pale hills).
  2. Over cottages, fence and pumpkin: **pass** (y and c villager tags over the wood-dark roofs; block tags above the roofs).
  3. Over clouds and bunting: **pass**, and by construction: clouds and bunting stay above y ~70, tags never go above y ~96.
  4. Candy-yellow arrow vs sky, hills, cottages and tree: **pass** (seen over the tree canopy, the hills and the sky).
  5. Resolved targets don't look typeable: **pass** (grey used blocks and party zombies carry no tag).
  6. Tag ink outline separates every tag; nothing in the backdrop looks like a letter or a second tag: **pass** (the tag band test also proves no parchment, chalk or candy-yellow there).
  7. HUD target letter unaffected: **pass**.
  8. Characters read by silhouette against the near layer: **pass** after the hill recolour (before it, the zombie's head sat on same-colour hills; the ink outline still separated it).
- **Scrolling (8.2):** about 60 s of a web run with bursts and pauses: layers moved at different speeds, the seam tree, clouds, fence and bunting showed no tear, and targets stayed fixed on the path. The ground-to-world lock is proven by `test_ground_layer_stays_in_step_with_the_world_while_scooting`. A full 2:00 by-eye scroll was not completed (see 8.5).
- **Animations (8.3):** seen in the web build: hop (lifted, arms up) on a block key, hug on villager keys, grey used blocks, brain pop, poof dust clouds, party zombies walking in the line. The dance is covered by tests (real frames, no flip, bounce runs, `_process` does not clobber it); not watched by eye this time.
- **Tone (8.4):** pass: sunny, calm, cute; no gore; the brain block and pop are cartoon pink, the poof is a white dust cloud.
- **Perf (8.5): waived by Smuck (2026-10-05), not measured validly.** The Browser pane was hidden, so the canvas was throttled and I couldn't show it from my side. Readings taken anyway (not valid NFR1 evidence): 60 FPS and a 16.9 ms run-worst with about 13 followers while the pane still rendered at 60 FPS; 33.6 ms (one missed vsync) during a 4-key CDP burst; then 30 FPS and 50.2 ms while idle once the pane was hidden. The art adds 8 static sprites and a few `AnimatedSprite2D`s; 3.4's 22.7 ms baseline is the last valid number. Story 5.3 (target laptops) should re-run it.
- **Mutation habit (9.2), each caught:** ground factor 0.9 (backdrop 4 fails, level 4 fails); no `fposmod` (2 / 3 fails); `floorf` for `roundf` (2 / 4 fails); `_play()` guard removed (player zombie 2, level 3 fails); arrow fill off-palette pixel (art sprites 2 fails); a candy-yellow pixel in `near.png` (art backdrop 2 fails); `Poof.FRAMES = 5` (poof 4 fails). All restored; art regenerated byte-identical.
- Art review scene: 12 animations on 3 pages (N cycles), props at 16 px; Smuck can judge the new frames at 1x and 3x.
- Style sheet updated (section 1 list, section 3 sizes, sheet table, backdrop rules, tool); the phrases `test_art_style_sheet.gd` checks are unchanged.

### File List

New:
- `tools/gen_zombie_run_art.gd`, `tools/gen_zombie_run_art.gd.uid`
- `scripts/levels/zombie_run/sunny_village_backdrop.gd`, `.gd.uid`
- `assets/sprites/characters/zombie/zombie_hop.png`, `zombie_hug.png`, `zombie_dance.png` (+ `.import`)
- `assets/sprites/characters/villager/villager_poof.png` (+ `.import`)
- `assets/sprites/characters/party_zombie/party_zombie_walk.png` (+ `.import`)
- `assets/sprites/props/brain_block_idle.png`, `brain_block_bonk.png`, `brain_pop.png`, `down_arrow.png` (+ `.import`)
- `assets/sprites/backdrops/sunny_village_green/clouds.png`, `far.png`, `near.png`, `ground_tiles.png`, `ground_strip.png` (+ `.import`)
- `tests/unit/test_art_backdrop.gd`, `test_sunny_village_backdrop.gd`, `test_brain_pop.gd` (+ `.gd.uid`)
- `_bmad-output/implementation-artifacts/screenshots/3-6/00-1x-before-pumpkin-fix.jpg`, `01-run-start.jpg`, `02-1x-run-start.jpg`, `03-1x-hop-bonk-pop-conga.jpg`, `04-1x-used-blocks-grey.jpg`, `05-1x-poof-clouds.jpg`

Modified:
- `scenes/levels/zombie_run/zombie_run_level.tscn`, `brain_block.tscn`, `brain_pop.tscn`, `poof.tscn`, `villager.tscn`, `zombie_run_target.tscn`
- `scenes/characters/player_zombie.tscn`, `party_zombie.tscn`
- `scripts/levels/zombie_run/zombie_run_level.gd`, `brain_block.gd`, `brain_pop.gd`, `poof.gd`, `villager.gd`, `conga_line.gd`, `zombie_run_target.gd`
- `scripts/characters/player_zombie.gd`, `party_zombie.gd`
- `scripts/debug/art_review.gd`
- `docs/art-style-sheet.md`
- `tests/unit/test_art_sprites.gd`, `test_art_review.gd`, `test_player_zombie.gd`, `test_party_zombie.gd`, `test_conga_line.gd`, `test_brain_block.gd`, `test_poof.gd`, `test_villager.gd`, `test_zombie_run_level.gd`, `test_zombie_run_target.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`, `sprint-status.yaml`, this story file

## Change Log

- 2026-10-05: Story 3.6 implemented: the Sunny Village Green parallax backdrop (clouds, far hills, near village with bunting and a pumpkin post, ground tiles and strip) scrolled from the level's camera; the final MVP Zombie Run sprites (hop, hug, dance, poof, party walk, brain block idle/bonk, brain pop, down-arrow) from a new code-authored art tool; one animation owner at a time in `PlayerZombie` (closes the 3.2 "don't clobber hop" deferral); conga followers walk while moving; 61 new tests (813 total, all passing). Hills recoloured and pumpkin moved after the 1x readability check. Perf check waived by Smuck (pane hidden). Status set to review.
