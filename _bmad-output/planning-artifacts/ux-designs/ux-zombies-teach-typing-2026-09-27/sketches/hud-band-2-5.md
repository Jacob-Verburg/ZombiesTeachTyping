# HUD band layout sketch (Story 2.5)

Status: **approved by Smuck, 2026-10-04 ("Approve as drawn")**

Canvas 640 × 360 logical. Playfield y 0–256, HUD band y 256–360 (104 px, every level, every mode).
Font: Press Start 2P (theme font). Measured in Godot: every character, spaces included, is exactly as wide as the font size (16 px at 16, 24 px at 24, 32 px at 32), and the line height equals the font size. All rects below are in canvas pixels, relative to the HUD root (0, 0).

## Frame 1: letter mode (waiting for the first key)

```
x: 0      64                    220                  376             552      640
   ┌──────────────────────────────────────────────────────────────────────── 640 ─┐ y=0
   │                                                                     [II]    │ pause 24×24 at (600,16)
   │                         playfield (level)                                   │
   │                                                                             │
   │                ┌── Caps Lock is on ──┐  (only when suspected)               │ y=196–224
   │ ▓Type the letter to start!▓  (chalk on an ink strip, waiting only)          │ y=228–252
   ├─────────────────────────────────────────────────────────────────────────────┤ y=256 (1 px ink edge)
   │ pet    │               ┌────┐                │ Timer  2:00 │ ┌──────────┐  │
   │ slot   │               │ f  │  sign 48×40    │ Keys      0 │ │(B)  0    │  │
   │ ┌────┐ │               └────┘                │ WPM       – │ └──────────┘  │
   │ │cush│ │      (L)   zombie hands 48 px  (R)  │ Errors    0 │               │
   │ └────┘ │                                     │             │               │
   └─────────────────────────────────────────────────────────────────────────────┘ y=360
```

## Frame 2: word mode (running)

Same band. The sign grows with the word: width = letters × 32 + 16, centred on x = 220. The longest word that fits is 9 letters (9 × 32 + 16 = 304 ≤ 312); the Epic 6 word list tops out at 8.

```
   ├─────────────────────────────────────────────────────────────────────────────┤ y=256
   │ pet    │     ┌──────────────────────┐        │ Timer  1:23 │ ┌──────────┐  │
   │        │     │  z o m b i e         │ 6×32+16│ Keys     42 │ │(B) 12    │  │
   │        │     └──────────────────────┘ = 208  │ WPM      11 │ └──────────┘  │
   │        │      (L)   zombie hands     (R)     │ Errors    3 │               │
   └─────────────────────────────────────────────────────────────────────────────┘
```

## Frame 3: paragraph mode (2 lines, Epic 8)

```
   ├─────────────────────────────────────────────────────────────────────────────┤ y=256
   │ pet    │ ┌────────────────────────────────┐  │ Timer  1:23 │ ┌──────────┐  │
   │        │ │the cat sat  (12 chars × 24 px) │  │ Keys     42 │ │(B) 12    │  │
   │        │ │on the mat.                     │  │ WPM      11 │ └──────────┘  │
   │        │ └────────────────────────────────┘  │ Errors    3 │               │
   │        │      (L)   zombie hands     (R)     │             │               │
   └─────────────────────────────────────────────────────────────────────────────┘
```

Vertical budget: 4 pad + 2 × 24 px lines + 48 px hands + 4 pad = 104 px (DESIGN.md).

## Element table

| Element | x | y | w | h | Font size | Notes |
|---|---|---|---|---|---|---|
| Band (wood-dark, 1 px ink top edge) | 0 | 256 | 640 | 104 | – | never changes height |
| Pet slot | 0 | 256 | 64 | 104 | – | |
| Pet cushion (parchment placeholder) | 8 | 300 | 48 | 48 | – | empty until Story 4.3 |
| Target area | 64 | 256 | 312 | 104 | – | centre x = 220 |
| Target sign, letter mode | 196 | 260 | 48 | 40 | 32 | 1 glyph + 8 px side pad, 4 px top/bottom pad |
| Target sign, word mode | 220 − w/2 | 260 | n × 32 + 16 | 40 | 32 | grows with the word |
| Target sign, paragraph mode | 68 | 260 | 304 | 48 | 24 | 2 lines × 24 px, 12 chars per line (288 px + 8 px pad each side) |
| Zombie hands area | 64 | 308 | 312 | 48 | – | empty until Story 2.6; 4 px bottom pad |
| Stats panel (chalkboard, 1 px ink border) | 376 | 260 | 176 | 96 | – | |
| Stats row 1: "Timer" / value | 380 / 480 | 270 | 96 / 64 | 16 | 16 | labels chalk-dim, left; values chalk, right-aligned in a 4-char slot |
| Stats row 2: "Keys" / value | 380 / 480 | 290 | 96 / 64 | 16 | 16 | row pitch 20 px |
| Stats row 3: "WPM" / value | 380 / 480 | 310 | 96 / 64 | 16 | 16 | |
| Stats row 4: "Errors" / value | 380 / 480 | 330 | 96 / 64 | 16 | 16 | |
| Brain counter (wood-dark pill, ink border) | 556 | 264 | 80 | 28 | 16 | icon 16 + 4 gap + 3 digits (48) + 6 px pad each side |
| Start prompt (chalk on an ink strip) | 220 − w/2 | 228 | text + 8 | 24 | 16 | "letter": 25 chars = 400 px → strip 408 (x 16–424); "word"/"text": 23 chars → 376 |
| Caps Lock hint (candy-yellow sign, ink text) | 92 | 196 | 256 | 28 | 16 | 15 chars = 240 px + 8 px pad each side |
| Pause button | 600 | 16 | 24 | 24 | 16 | "II", 16 px from the top and right edges |

## Deviations from DESIGN.md / FR14 (all forced by the font)

1. **Stats label "Keys"** instead of "Keys Typed". "Keys Typed" + 4 digits needs 224 px. The report card keeps "Keys Typed". (DESIGN.md's own band drawing already says "Keys".)
2. **Stats column 176 px** instead of 136 px: the longest row is "Errors" (6 chars = 96 px) + a 4-char value (64 px) = 160 px, plus 1 px border and 3–4 px padding each side. The target area shrinks to 312 px to pay for it.
3. **Start prompt and Caps Lock hint sit above the band**, in the playfield's bottom strip, centred on the target area's centre (x = 220). "Type the letter to start!" is 400 px wide and doesn't fit inside the 312 px target area. DESIGN.md already places both just above the sign; this moves them out of the band.
4. **Paragraph mode fits 12 characters per line** at 24 px. Epic 8 has to accept that, find another font size that works, or widen the target area.
5. **WPM placeholder is "–"** (en dash), confirmed present in Press Start 2P.
6. The brain counter is 80 px wide (3 digits). A run never earns 1000 brains.

Placeholder chrome only: flat palette colours, 1 px ink borders, zero corner radius. Final 9-slice art is Story 5.0.
