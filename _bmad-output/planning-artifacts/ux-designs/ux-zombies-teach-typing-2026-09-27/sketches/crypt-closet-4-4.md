# Crypt Closet layout sketch (Story 4.4)

Status: **approved by Smuck, 2026-10-06 ("Approve as drawn")**

Canvas 640 × 360 logical, 16 px margin (safe rect x 16–624, y 16–344), 4 px grid.
Font: Press Start 2P (theme font). Measured in Godot 4.7 on 2026-10-06: every character, spaces included, is exactly as wide as the font size (16 px at 16, 24 px at 24, 32 px at 32), and the line height equals the font size. The font has `?` and `–` (U+2013) and `×`, but **no check mark** (U+2713 and U+2714 are missing), so the Wearing check is drawn (a 3 px polyline), never typed.
All rects are in canvas pixels. Placeholder chrome only: flat palette colours, 1 px ink borders, zero corner radius. Final 9-slice art is Story 5.0.

Hats on the left, pets on the right, the preview zombie between them, so the zombie trying things on sits in the middle of the screen.

## Frame A: the Closet at rest (fresh save + Welcome Gift: 100 brains)

Focus is on the Pumpkin hat (hat tile 0). Pumpkin hat and Cute ghost are **Buy**, the other 16 are **Locked**.

```
x: 16    96     168                    472     544     624
y=16 ┌(B) 100┐      ┌──── Crypt Closet ────┐        ┌ Menu ┐   counter / title sign (24 px) / Menu button
y=48 └───────┘      └──────────────────────┘        └──────┘
y=56          Hats                                          Pets       16 px chalk headings
y=76 ╔════╗┌────┐┌────┐  ┌───────────────┐  ┌────┐┌────┐┌────┐
     ║ 🎃 ║│ ?  ││ ?  │  │    mirror     │  │ 👻 ││ ?  ││ ?  │  tiles 68×68, 4 px gaps
     ║[100]║│100 ││100 │  │               │  │[100]││100 ││100 │  [100] = pumpkin tag (Buy)
     ╚════╝└────┘└────┘  │    zombie  pet│  └────┘└────┘└────┘  ╔╗ = candy-yellow focus ring
     ┌────┐┌────┐┌────┐  └───────────────┘  ┌────┐┌────┐┌────┐
     │ ?  ││ ?  ││ ?  │        y=196        │ ?  ││ ?  ││ ?  │
     │200 ││200 ││200 │                     │200 ││200 ││200 │
     └────┘└────┘└────┘                     └────┘└────┘└────┘
     ┌────┐┌────┐┌────┐                     ┌────┐┌────┐┌────┐
     │ ?  ││ ?  ││ ?  │                     │ ?  ││ ?  ││ ?  │
     │300 ││300 ││300 │                     │300 ││300 ││300 │
y=288└────┘└────┘└────┘                     └────┘└────┘└────┘
y=296┌──────────────────────────── info sign (parchment) ─────────────────────────┐
     │ Pumpkin hat                                                                │  line 1: the focused item's name
     │ Buy                                                                        │  line 2: its state in words
y=344└────────────────────────────────────────────────────────────────────────────┘
```

The preview zombie wears whatever the focused available tile is (here the Pumpkin hat) and the pet slot keeps the equipped pet (none on a fresh save).

## Frame B: after the Pumpkin hat is bought and worn (0 brains)

Focus on the Pumpkin hat. The hat tile is **Wearing** (green-bright tag with a drawn check mark), the Cute ghost is **Can't afford**.

```
y=16 ┌(B)   0┐      ┌──── Crypt Closet ────┐        ┌ Menu ┐
y=76 ╔════╗┌────┐┌────┐  ┌───────────────┐  ┌────┐┌────┐┌────┐
     ║ 🎃 ║│ ?  ││ ?  │  │      🎃       │  │ 👻 ││ ?  ││ ?  │  ghost: disabled fill, price in ink-muted, no tag box
     ║[ ✓]║│100 ││100 │  │    zombie     │  │100 ││100 ││100 │  [ ✓] = zombie-green-bright tag + green-dark check
     ╚════╝└────┘└────┘  └───────────────┘  └────┘└────┘└────┘
     ...                                                         (rows 2 and 3 as in frame A)
y=296┌──────────────────────────────────────────────────────────────────────────┐
     │ Pumpkin hat                                                               │
     │ Wearing                                                                   │
y=344└──────────────────────────────────────────────────────────────────────────┘
```

Focusing the Cute ghost here: the preview shows the ghost beside the zombie (the hat stays on), the sign reads "Cute ghost" / "Need 100 more".
An owned hat that is not worn shows a zombie-green tag with the word **Wear** (4 chars, exactly 64 px) and the sign reads "Wear".

## Frame C: the confirm prompt

Opened by Enter or a click on a Buy tile. The night scrim (60 %) covers the whole screen and eats every click. Focus starts on **Yes** and stays on Yes / No.

```
y=0  ┌─────────────────────────── night scrim, 60 % ──────────────────────────────┐
     │                                                                             │
y=96 │    ┌──────────────────────── wood panel ─────────────────────────────┐     │  x 56–584
y=104│    │ ┌───────────────────── parchment sign ────────────────────────┐ │     │  x 64–576
     │    │ │              Buy the Pumpkin hat                            │ │     │  24 px, ink, centred
     │    │ │               for 100 brains?                               │ │     │
y=204│    │ └─────────────────────────────────────────────────────────────┘ │     │
y=216│    │            ╔══ Yes ══╗          ┌── No ───┐                     │     │  Yes x 208–304, No x 336–432
y=248│    │            ╚═════════╝          └─────────┘                     │     │
y=264│    └─────────────────────────────────────────────────────────────────┘     │
y=360└─────────────────────────────────────────────────────────────────────────────┘
```

The question wraps at 21 characters a line (21 × 24 = 504 ≤ 512). Shipped: "Buy the Pumpkin hat" / "for 100 brains?" and "Buy the Cute ghost" / "for 100 brains?" (2 lines). The longest Epic 9 name, "Buy the Floating" / "eyeball for 300" / "brains?", takes 3 lines (72 px), still inside the 100 px sign.

## Frame D: tutorial arrow positions (built in Story 4.5)

The arrow is a 24 × 20 candy-yellow triangle with an ink border. Its steps (EXPERIENCE "tutorial-arrow"): first affordable tile → Yes → the same tile again, now **Wear**.

```
y=52      ▼  (x 38–62, y 52–72: over hat tile 0, centred, bottom 4 px above the tile;
               it sits in the headings row, left of "Hats" which starts at x 90)
y=76 ┌────┐
     │ 🎃 │  step 1: "Buy" (the first affordable tile, hat tile 0 on a Welcome Gift save)
     └────┘

     prompt open:      ► ╔ Yes ╗      step 2: x 176–200, y 222–242, left of Yes, pointing right

y=52      ▼  step 3: back over hat tile 0, now Wear (focus returned to the tile after Yes)
```

If the first affordable tile is a pet (pet tile 0 at x 412), the arrow is at x 434–458, y 52–72, left of "Pets" (x 486). Every tile in row 1 has room for the arrow above it in the headings row; no arrow ever needs a row 2 or 3 tile (only row 1 items are 100 brains).

## Element table

| Element | x | y | w | h | Font size | Notes |
|---|---|---|---|---|---|---|
| Background (night) | 0 | 0 | 640 | 360 | – | full rect |
| Brain counter | 16 | 16 | 80 | 28 | 16 | existing `brain_counter.tscn`, same place as on the menu |
| Title sign (parchment, ink border) + "Crypt Closet" | 168 | 16 | 304 | 32 | 24 | 12 × 24 = 288 + 8 px pad each side; placeholder for 5.0's hand-lettered sign |
| Menu button (`PixelButton`) | 544 | 16 | 80 | 32 | 16 | "Menu" 64 px + 8 px pad |
| "Hats" heading (chalk) | 90 | 56 | 64 | 16 | 16 | centred over the hat grid (centre x 122) |
| "Pets" heading (chalk) | 486 | 56 | 64 | 16 | 16 | centred over the pet grid (centre x 518) |
| Hat grid | 16 | 76 | 212 | 212 | – | 3 × 68 + 2 × 4 gaps |
| Pet grid | 412 | 76 | 212 | 212 | – | |
| Tile (whole control, = frame) | – | – | 68 | 68 | – | 1 px ink border; fill by state |
| Tile: art box | +18 | +6 | 32 | 32 | – | item icon, nearest |
| Tile: "?" (Locked only) | +18 | +6 | 32 | 32 | 32 | ink-muted, centred in the art box |
| Tile: tag strip + text | +2 | +46 | 64 | 20 | 16 | 4 characters max (64 px); text centred |
| Tile: check mark (Wearing only) | +24 | +48 | 20 | 16 | – | drawn polyline, 3 px, zombie-green-dark |
| Tile: focus ring | +0 | +0 | 68 | 68 | – | 2 px candy-yellow, on the tile's own edge (inside it) |
| Tile: drop shadow | +2 | +2 | 68 | 68 | – | 2 px ink, behind the tile |
| Mirror (wood frame, parchment-shade inside) | 244 | 76 | 152 | 120 | – | the preview stands on its bottom edge |
| Preview zombie (feet origin) | 302 | 188 | 32 | 32 | – | 1×; sprite x 286–318, y 157–189; with the hat the top is about y 146 |
| Preview pet (feet origin) | 338 | 188 | 32 | 32 | – | 36 px right of the zombie, like the menu; sprite x 322–354; the pair is centred on x 320 |
| Info sign (parchment, ink border) | 16 | 296 | 608 | 48 | – | |
| Info line 1: name | 24 | 302 | 592 | 16 | 16 | 37 chars max; ink |
| Info line 2: state words | 24 | 322 | 592 | 16 | 16 | ink |
| Confirm: scrim | 0 | 0 | 640 | 360 | – | night at 60 % alpha, stops the mouse |
| Confirm: wood panel | 56 | 96 | 528 | 168 | – | wood fill, wood-dark frame, 1 px ink border |
| Confirm: parchment sign + question | 64 | 104 | 512 | 100 | 24 | ink, centred, autowrap, 21 chars a line |
| Confirm: Yes button | 208 | 216 | 96 | 32 | 16 | `PixelButton`, focused on open |
| Confirm: No button | 336 | 216 | 96 | 32 | 16 | `PixelButton` |
| Tutorial arrow (4.5) | tile centre − 12 | tile top − 24 | 24 | 20 | – | step 2: x 176, y 222, pointing right |

## Tile states (exactly one each, each with its own shape for Story 5.2's grayscale check)

| State | Fill | Art box | Tag strip | Info sign line 1 / line 2 |
|---|---|---|---|---|
| Locked | stone | "?" 32 px, ink-muted | price, chalk, no tag box | "Coming soon" / (empty) — a locked item stays a mystery |
| Can't afford | disabled-fill | item icon | price, ink-muted, no tag box | name / "Need N more" |
| Buy | parchment | item icon | **pumpkin tag box** with the price, ink | name / "Buy" |
| Wear | parchment | item icon | zombie-green tag box, "Wear", ink | name / "Wear" |
| Wearing | parchment | item icon | zombie-green-bright tag box with a drawn zombie-green-dark **check mark**, no word | name / "Wearing" |

Focus on the Menu button: the info sign is blank.

## Navigation

- Arrows move inside a grid by row and column. Right from a hat tile in column 3 goes to the pet tile in column 1 of the same row, and Left comes back. Up from row 1 goes to Menu; Menu Down goes to pet tile 3 (the one under it). Every other outer edge stops (no wrap).
- Tab: hats 1–9, pets 1–9, Menu, then wraps.
- Esc: back to the main menu; while the prompt is open, Esc = No.

## Deviations from DESIGN.md / EXPERIENCE.md (all forced by the font, except 6)

1. **The long words live on the info sign, for the focused tile only.** "Coming soon" (176 px), "Need 300 more" (208 px) and "Wearing" (112 px) don't fit any tile that leaves room for two 3 × 3 grids and the preview across 608 px. FR40's "label on the tile" becomes "label for the focused tile". A mouse user hovering a tile also moves focus, so the sign follows the mouse too.
2. **Buy tiles show the price on the pumpkin tag**, not the word "Buy". The pumpkin tag box is what says "you can buy this"; the word is on the sign.
3. **Wearing is a drawn check mark** on a bright-green tag, with the word on the sign. The font has no ✓ glyph.
4. **Tiles are 68 × 68**, not 48 × 48: the 64 px tag strip (4 characters) plus a 32 px art box needs it.
5. **Locked items show no name** ("Coming soon" on the sign), and their price stays on the tile so every row shows its price (FR39 "prices by row").
6. **The focus ring is on the tile's own edge** (inside the 68 px box, like the level cards), not outside it, so the grids touch the 16 px margin exactly and nothing pokes past it. Only the 2 px drop shadow of the right-hand pet column reaches x 626; it is decoration and is excepted from the margin check, as on the menu.
