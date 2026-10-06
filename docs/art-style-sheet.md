# Art Style Sheet — Zombies Teach Typing

The one page every piece of art in this game follows. Written in Story 1.9 (the art-style gate). The
rules marked *tested* are checked by GUT (`tests/unit/test_art_*.gd`), so a later art story cannot drift
from them without a failing test.

## 1. Purpose and the gate rule

The palette, the pixel font, the sprite standards and the first two characters (the player zombie and
one villager) must be **approved by Smuck before any other final art is made**. The record is the
`## Art Approval` section of Story 1.9 (see [Approval](#approval)).

Stories that make final art and wait for that approval:

- **Epic 3:** done in Story 3.6 (Sunny Village Green, the hop, hug, dance and poof frames, the party-hat
  zombie's walk, the brain block, brain pop and down-arrow; see section 3).
- **Epic 4:** Story 4.3 (hats and pets shown everywhere) and the Crypt Closet art.
- **Epic 5:** Story 5.0 (MVP UI art pass: panels, buttons, signs, level cards, logo).
- Later epics (6, 8, 9, 10) reuse these rules for their characters, hats, pets and backdrops.

Before its final-art story, any story may use **placeholder art**: plain shapes in palette colors.

## 2. Palette

**At most 32 colors, shared by every sprite and every UI element: 24 UI colors + 8 reserved art colors.
Adding a 33rd color means dropping one.** The list is the one Smuck approved on 2026-09-27 (UX D13),
copied from `DESIGN.md` → Colors.

The master file is `assets/palette/palette_32.png`: **32×1 px, one opaque pixel per color, index = the
row order below** (pixel x = index). It is raw data, not a swatch sheet. *Tested.*

| # | Name | Hex | Role |
|---|---|---|---|
| 0 | ink | #1E1428 | 1 px outline on everything; text on light surfaces |
| 1 | night | #2B1D3F | menu backdrop, letterbox, pause scrim |
| 2 | dusk | #4A3366 | secondary night tone, locked-card tint |
| 3 | parchment | #F6E7C1 | signs, notices, target sign |
| 4 | parchment-shade | #D9BC84 | parchment shading |
| 5 | ink-faded | #8A7552 | dimmed next line, space marker (on parchment) |
| 6 | ink-muted | #4E4757 | text on disabled surfaces |
| 7 | wood-dark | #5A3218 | plank ramp: dark / frame |
| 8 | wood | #8A5228 | plank ramp: base, default button |
| 9 | wood-light | #C08447 | plank ramp: bevel highlight |
| 10 | stone | #6F6A80 | stone panels |
| 11 | stone-light | #BDB6C4 | stone highlight, "coming soon" grey |
| 12 | chalkboard | #24402F | report card, HUD stats column |
| 13 | chalk | #F4F1E4 | chalk values, light text, eye whites and teeth |
| 14 | chalk-dim | #A8C4A6 | chalk labels |
| 15 | pumpkin | #F07A1C | primary action, red-ish props |
| 16 | pumpkin-light | #FFA94A | focused button, highlight |
| 17 | candy-yellow | #FFD23F | focus / "look here now" only |
| 18 | zombie-green | #6CC24A | zombie skin base, hands |
| 19 | zombie-green-bright | #B8F27C | zombie skin highlight, active finger |
| 20 | zombie-green-dark | #2E6B26 | zombie skin shade, typed text |
| 21 | bat-purple | #7A4BB3 | decoration (bunting, trims); zombie shirt |
| 22 | stamp-red | #B02A25 | the "New best!" stamp and toggle slash only |
| 23 | disabled-fill | #CFC6B6 | disabled buttons and tiles |
| 24 | art-sky | #7EC8E3 | daytime sky (backdrops) |
| 25 | art-sky-light | #BFE6F2 | sky highlight, clouds |
| 26 | art-grass | #4E9A34 | grass (backdrops) |
| 27 | art-skin-light | #F2C9A0 | human skin base |
| 28 | art-skin-dark | #B07850 | human skin shade |
| 29 | art-brain-pink | #F29AB8 | brain props, brain counter |
| 30 | art-brain-shade | #C9607F | brain shading |
| 31 | art-moon | #FFF3B0 | moon (night backdrops) |

**The one alpha exception:** the pause/confirm scrim is `night` at 60% opacity, blended at runtime by
the UI. It is never in a sprite and not in the palette file.

## 3. Sprites

**Sizes:** characters **32×32**, brutes **48×48**, tiles **16×16** (px, authored 1:1 at the 640×360
viewport). Props (the brain block, the brain pop, the down-arrow) use the tile size, 16×16; the villager's
poof is a character-size effect, 32×32, drawn from the feet like the characters. No 48×48 sprite exists
yet.

**Rules** (*tested* in `tests/unit/test_art_sprites.gd`; the wording here matches the test; rule 5 is the exception):

1. **Sheet:** one horizontal strip, `frames × size` wide, `size` high, frames side by side.
2. **Hard alpha:** every pixel has alpha 0 or 255. Nothing semi-transparent.
3. **Palette only:** every opaque pixel's RGB is exactly one of the 32 palette colors.
4. **Outline:** the outline is 1 px of `ink` (#1E1428), not black. Rule as tested: *an opaque pixel
   that is not `ink` must have all four orthogonal neighbours (up, down, left, right) opaque, within
   the same frame; a neighbour outside the frame counts as transparent.* So the silhouette edge is
   always `ink`, and stepped (diagonal) corners are fine. Interior lines are optional, in `ink` or a
   darker tone from the sprite's own ramp.
5. **Transparent margin ≥ 1 px** on every side of every frame (only implied by rule 4, which allows `ink` on a
   frame border, so it is not tested on its own; check it by eye at the gate).
6. **Not empty, not static:** every frame has opaque pixels; no two frames of a sheet are identical.
7. **One ground line:** the lowest opaque row is the same in every frame of a sheet, so swapping
   frames never makes the sprite jump (a bob moves the body, not the soles). Deliberate hops are the
   only exception and get their own sheet.

**Animation limits:** **2–6 frames** per animation at **8–12 fps** (*tested* for every sheet listed here: the frame counts and
sizes in `test_art_sprites.gd` and the fps in the art review scene; a new sheet must be added to those tests). Per-frame duration
multipliers are not used to get below 8 fps. One-frame overlays (`OVERLAYS` in the test) are not
animations and are exempt from the frame count only; every pixel rule applies to them.

| Sheet | Frames | Size | fps | Plays |
|---|---|---|---|---|
| zombie `idle` | 2 | 32×32 | 8 | loop |
| zombie `walk` | 4 | 32×32 | 10 | loop |
| zombie `hop` (3.6) | 3 | 32×32 | 10 | once: crouch, peak, land |
| zombie `hug` (3.6) | 3 | 32×32 | 10 | once: reach, squeeze, release |
| zombie `dance` (3.6) | 4 | 32×32 | 8 | loop (one cycle = one 2 Hz bounce) |
| villager `wave` | 2 | 32×32 | 8 | loop |
| villager `poof` (3.6) | 4 | 32×32 | 12 | once (frames stepped by the poof's tween) |
| party-hat zombie `idle` | 2 | 32×32 | 8 | loop |
| party-hat zombie `walk` (3.6) | 4 | 32×32 | 10 | loop |
| professor `point` (2.9) | 2 | 32×32 | 8 | loop |
| brain block `idle` (3.6) | 2 | 16×16 | 8 | loop |
| brain block `bonk` (3.6) | 3 | 16×16 | 12 | once, holds the last (used) frame |
| brain `pop` (3.6) | 2 | 16×16 | 8 | loop while it rises |
| `professor_mortarboard.png` | overlay | 32×32 | – | drawn at the body's origin |
| `down_arrow.png` (3.6) | overlay | 16×16 | – | the active target's arrow; the bob is code |
| pet `cute_ghost` `idle` (4.3) | 4 | 32×32 | 8 | loop (the float: a 1 px body bob and a wavy tail) |
| `hat_pumpkin.png` (4.3) | overlay | 32×32 | – | seat on row 30 at x 16 |

**Hats** (Story 4.3) are 32×32 one-frame overlays whose **seat** (the bottom-centre of the brim) is pixel
(16, 30): the lowest opaque row is row 30 and the opaque columns are centred on column 16 (*tested*). Row
31 stays empty. `HatSlot` sits on the character's per-frame head point and draws the overlay with the seat
on it, so the brim's bottom ink row overlaps the crown's top ink row. **Pets** are 32×32 sheets drawn from
the feet like the characters (soles on row 30; a float is drawn in the frames without moving the lowest
row). Paths: `assets/sprites/cosmetics/hats/hat_<name>.png`, `assets/sprites/cosmetics/pets/pet_<name>_idle.png`;
made by `tools/gen_cosmetics_art.gd`.

Hop and hug are drawn **grounded** (the soles stay on row 30): the zombie's hop and hug tweens move the
body, so frames that also lifted it would double the motion.

**File naming:** `<subject>_<animation>.png` (`zombie_walk.png`, `villager_wave.png`), animation names
are lowercase verbs (`idle`, `walk`, `wave`, `hop`, `hug`, `dance`, `poof`). Paths:
`assets/sprites/characters/<subject>/`, props in `assets/sprites/props/`, backdrops in
`assets/sprites/backdrops/<level>/`. Sheets become `SpriteFrames` with one `AtlasTexture` region per
frame.

**Backdrops** (Story 3.6, Sunny Village Green): parallax layers `clouds.png`, `far.png`, `near.png`, each
**640 px wide** (the screen width, so two copies side by side always cover it) and at most 192 px high
(the playfield above the ground line), plus `ground_tiles.png` (16×16 tiles: grass, grass tuft, flower,
path) and `ground_strip.png` (640×64, built from the tiles). Backdrop layers and ground tiles are
**exempt from the outline rule only**: they keep hard alpha and palette colours (*tested* in
`tests/unit/test_art_backdrop.gd`), never use `candy-yellow` or `stamp-red`, keep the in-world tag band
(y 96–166) free of `parchment`, `chalk` and `candy-yellow`, and are authored with wraparound so the 640 px
seam never shows.

**Import settings:** Lossless compression (`compress/mode=0`), no mipmaps (*tested*). Filtering is the
project default, Nearest; do not set a per-file filter.

**Scaling:** the game renders at **640×360** and stretches with mode `viewport`, aspect `keep`, scale
mode `fractional`, Nearest filtering and 2D transforms snapped to pixels. Consequence: at non-whole
window scales (for example 1366×768, about 2.13×) some pixels are one screen pixel wider than others.
This is accepted. The same sprite scale is used on every screen; characters are never scaled up per
screen for legibility.

**How sprites are made:** code-authored pixel art. Each frame is an ASCII map in
`tools/gen_art_prototypes.gd` (the prototypes), `tools/gen_zombie_run_art.gd` (Story 3.6, which reads
the palette, legends and approved maps from the first) or `tools/gen_cosmetics_art.gd` (Story 4.3), one character per pixel, a legend from
character to palette **name**, written to PNG by running the tool headless and then `--import`. The
backdrop is drawn by the same tool from shapes at fixed positions (no randomness). Never hand-edit a
PNG. Commit the PNGs and `.import` files.

## 4. Font

- **Press Start 2P**, Version 3.000, by CodeMan38, from github.com/google/fonts (`ofl/pressstart2p`).
- License: **SIL Open Font License 1.1**; the license file ships next to the font:
  `assets/fonts/press_start_2p_OFL.txt`. Reserved Font Name "Press Start 2P".
- Native grid **8 px**. Every size is a whole multiple: **16 px** UI, labels and stats; **24 px**
  headings and paragraph lines; **32 px** targets; **64 px** countdown. 16 px is the text floor for
  anything a kid reads (8 px is for dev-only screens such as the debug overlay).
- Import: antialiasing none, hinting none, subpixel positioning disabled (`tests/unit/test_ui_theme.gd`).
- Confusable glyphs `lI1O0` were checked in Story 1.3 and are shown in the art review scene.
- Why not Pixelify Sans: it is rounder (closer to "chunky, friendly, slightly rounded"), but it failed
  the `O`/`0` check in Story 1.3, which matters for a typing game.

## 5. Kid-safe art rules

From NFR10 and `DESIGN.md` → Do's and Don'ts:

- **Cute-Halloween** everywhere, daytime levels included: goofy, never babyish (a 13-year-old finds it
  charming), never scary (a 6-year-old).
- **No** gore, blood, wounds, exposed bones or brains, body-part gags, guns or horror lighting.
  Tattered clothes are clean stepped edges.
- **Defeat is melting, dust or stars**, never injury.
- **Stamp red** (#B02A25) only on the "New best!" stamp and the toggle slash. Never an error color,
  never level art; red-ish props (thrown tomatoes) are pumpkin.
- No soft shadows, glows, blur, gradients or anti-aliasing: hard pixels only.

## 6. Reuse rules

The sprites are drawn so that later art can be made by reuse (GDD → Reuse):

- **Party-hat zombie = villager recolor + hat.** The villager's skin uses only `art-skin-light` and
  `art-skin-dark` (legend characters `s`/`S`); the recolor swaps them for `zombie-green` and
  `zombie-green-dark` and keeps the clothes. The result is still palette-only.
- **Horde Rush copies = the player sprite, scaled** for size classes. Note: a 1.5× nearest scale of a
  32 px sprite gives uneven pixels; Story 6.3 decides between redrawn 48×48 brutes and an integer scale.
- **The mob = 2 base sprites, recolored.**
- **Hats anchor to a head point.** Story 4.3 set the anchors: one head point per frame of every animation
  (the top-centre of the crown), in `data/anchors/` (`zombie_anchors.tres`, `professor_anchors.tres`),
  measured from the sheets by `tools/gen_sprite_anchors.gd` and re-measured by
  `tests/unit/test_sprite_anchors.gd`. Redraw a character sheet, rerun the tool. The zombie keeps a flat
  crown (about 12 px wide) so a pumpkin hat, party hat or mortarboard can sit on it; the professor's
  mortarboard is lifted onto a worn hat.

## Approval

The approval record is the `## Art Approval` section of
`_bmad-output/implementation-artifacts/1-9-art-style-sheet-and-prototype-sprites-review-gate.md`.
No final art is produced until it says **Approved**. A rule Smuck changes there is changed here and in
its test in the same change.
