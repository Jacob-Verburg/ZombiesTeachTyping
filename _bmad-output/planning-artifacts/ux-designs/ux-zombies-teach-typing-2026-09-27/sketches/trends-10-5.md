# Progress screen layout sketch (Story 10.5)

Status: **approved by Smuck, 2026-10-14 ("Approve as drawn")**

Canvas 640 × 360 logical, 16 px margin (safe rect x 16–624, y 16–344), 4 px grid.
Font: Press Start 2P (theme font): every character is exactly as wide as the font size (16 px at 16, 24 px at 24).
Panels use the existing theme variations (no new art): `Chalkboard` (8 px frame), `Sign` (parchment), `PixelButton`, `Keycap`.
Colours: night background (as the main menu), chalk `#F4F1E4` for values and bars, chalk-dim `#A8C4A6` for labels and chart titles.

## Frame A: Progress, filled (12 runs over 5 days)

Focus on **Menu** (the only control on the screen).

```
x: 16             272 288                                            624
y=16                 ┌──────── Progress ────────┐                          Sign, 24 px, x 216–424, y 16–52
y=52                 └──────────────────────────┘
y=64 ┌── Chalkboard ───────┐ ┌── Chalkboard: WpmChart ─────────────────────┐
     │ Keys Typed    (dim) │ │ Words per minute                    (dim)   │  title y 72–88
     │ 6120        (chalk) │ │          ▄   ▄ ▆ ▄ ▆ ▆ █ ▆ █ █ █            │  bars y 94–126 (32 px), 12 px wide, 4 px gap
     │                     │ └─────────────────────────────────────────────┘  y 64–136
     │ Best WPM            │ ┌── Chalkboard: AccuracyChart ────────────────┐
     │ 17                  │ │ Accuracy                                    │  fixed 0–100 scale
     │                     │ │ ▆ ▆ ▇ ▆ ▇ ▇ █ ▇ ▇ █ █ █                    │
     │ Brains Earned       │ └─────────────────────────────────────────────┘  y 144–216
     │ 940                 │ ┌── Chalkboard: PracticeChart ────────────────┐
     │                     │ │ Practice time                               │  one bar per day with practice
     │ Time Practiced      │ │ ███    ██████   ███    ██████   █████       │  (≤ 7 bars, 32 px wide, 8 px gap)
     │ 1 hr 5 min          │ └─────────────────────────────────────────────┘  y 224–296
y=296└─────────────────────┘
y=312                                                 ╔═ Menu ═╗ [Esc]       Menu x 480–560, Esc keycap x 568–624
y=344                                                 ╚════════╝
```

- Totals board x 16–272, y 64–296. Text 16 px in from the board's edge: label (dim, 16 px) over value (chalk, 16 px), four pairs 56 px apart starting at y 78. Widest label "Time Practiced" = 14 glyphs = 224 px ≤ 232 px. Widest value "99 hr 59 min" = 192 px.
- Charts x 288–624. Title at the top (12 px in, 10 px down), bar area 316 × 32 px under it (10 px in, 30 px down), bars bottom-aligned, chalk `ColorRect`s, no outline, no numbers on bars.
  - **Words per minute**: the newest 20 runs, oldest left. 20 × 12 + 19 × 4 = 316 px. Scale = the biggest shown WPM (at least 10).
  - **Accuracy**: the same runs, 0–100 % (100 % is a full bar).
  - **Practice time**: minutes per day for the newest 7 days that have practice, oldest left. Days with no practice are skipped, never an empty bar. Scale = the biggest day (at least 10 min).
  - A value above 0 always shows at least a 2 px bar.
- No dates, no goal lines, no grades, no ranks, no comparison, no timer.

## Frame B: Progress, empty (no finished game yet)

```
y=16                 ┌──────── Progress ────────┐
y=64 ┌── Chalkboard ───────┐ ┌── Sign (parchment) ─────────────────────────┐
     │ Keys Typed          │ │                                             │
     │ 0                   │ │                                             │
     │ Best WPM            │ │              Finish a game to               │  16 px, ink, centred, 2 lines
     │ 0                   │ │              see your charts!               │
     │ Brains Earned       │ │                                             │
     │ 0                   │ │                                             │
     │ Time Practiced      │ │                                             │
     │ 0 min               │ │                                             │
y=296└─────────────────────┘ └─────────────────────────────────────────────┘  sign x 288–624, y 64–296
y=312                                                 ╔═ Menu ═╗ [Esc]
```

The totals still show (Brains Earned can be above 0 from quit games or the Welcome Gift).

## Frame C: main menu with the new Progress button

```
x: 16  96   144                        461 480        624
y=16 ┌(B) 100┐  ZOMBIES TEACH TYPING (logo)   ╔═ Progress ═╗    button x 480–624, y 16–48 (focused here)
y=48 └───────┘                                ╚════════════╝
y=64 ┌──────────── level cards ───────────────────────────┐
     ...                                     (rest of the menu unchanged)
y=296┌ Crypt Closet ┐  [Music] [Sound] [Fullscreen]
```

"Progress" = 8 glyphs = 128 px + 16 px button padding = 144 px. The logo's drawn pixels end at x 461, so nothing overlaps.

## Focus map

- Progress screen: only **Menu**; it starts focused. Enter / click on it or **Esc** anywhere → back to the main menu (one UI click).
- Main menu: the Progress button is its own top row. Up from any level card → Progress. Down from Progress → the first card you can choose (or Crypt Closet when there is none). Left / Right on Progress stay put. Tab order: cards → bottom row → Progress → back to the first card.

## Copy list

| Where | Copy |
|---|---|
| Menu button, screen heading | "Progress" |
| Chart titles | "Words per minute", "Accuracy", "Practice time" |
| Totals labels | "Keys Typed", "Best WPM", "Brains Earned", "Time Practiced" |
| Time values | "45 min", "1 hr 5 min", "0 min" |
| Empty state | "Finish a game to see your charts!" |
| Back | "Menu" + keycap "Esc" (already approved) |
