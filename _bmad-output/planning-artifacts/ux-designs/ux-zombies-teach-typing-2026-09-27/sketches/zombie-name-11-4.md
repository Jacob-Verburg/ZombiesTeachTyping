# Zombie name on the menu and report card (Story 11.4)

Status: **approved by Smuck, 2026-10-18 ("Switch"; placements as drawn; Esc only on the picker from the menu; Switch always shown)**

Canvas 640 × 360 logical, 16 px margin (safe rect x 16–624, y 16–344), 4 px grid.
Font: Press Start 2P (theme font): every glyph is exactly as wide as the font size (16 px at 16).
No new art, no new sounds. The name is plain text in the pixel font (no sign plank around it), never
wraps, never shrinks: 12 letters (the longest name) = 12 × 16 = 192 px.

## Hat height (measured from the shipped PNGs)

| Hat | Top opaque row | Rise above the head point |
|---|---|---|
| Witch hat, Bunny ears (tallest) | 13 | **17 px** |
| Heart headband, Santa hat, Top hat | 15 | 15 px |
| Leprechaun hat | 17 | 13 px |
| Crown, Pirate hat, Pumpkin | 19 | 11 px |

- **Menu zombie** (`%Zombie` at (48, 284), body x 32–64, y 253–284; idle head point y 254–255):
  the tallest hat reaches **y 237** (x 38–58). Pets stand at x 68–100, y 253–284 (tallest pet top y 265).
- **Professor** (`%Professor` at (430, 270), head point (446, 275)): the tallest hat reaches y 258 and
  the mortarboard stacked on it reaches **y 254** (x 436–456). His pet stands at x 474–506, y 269–300.

## Frame A: main menu, short name, Switch focused

```
x: 16                 112        224 240                         624
y=16  (brains)          Zombies Teach Typing             [Progress]
y=64  ┌─ Zombie Run ─┐ ┌─ Horde Rush ─┐ ┌─ Pitchfork ──┐               cards unchanged, y 64–188
y=188 └──────────────┘ └──────────────┘ └──────────────┘
y=204 Sam                                                               %ZombieName: 16 px chalk #F4F1E4,
y=220                                                                   x 16–208, y 204–220, left-aligned
y=237    ^hat
y=248              ╔╔═ Switch ═╗╗                                       %SwitchZombieButton (PixelButton)
y=253  ▓zom▓ ░pet░ ║           ║                                        x 112–224, y 248–280, focus ring shown
y=280              ╚╚══════════╝╝
y=296 ╔══ Crypt Closet ══╗  Music   Sound   Fullscreen                 bottom row unchanged
y=328 ╚══════════════════╝
```

## Frame B: main menu, 12 W's + witch hat + pet + storage notice

```
x: 16                 112        224     288                       624
y=200                                    ┌─ This browser might ────┐   %StorageNotice x 288–624, y 200–280
y=204 WWWWWWWWWWWW                       │  forget your brains     │   name ends at x 208 (80 px clear of
y=220                                    │                         │   the notice)
y=237    🧙 (hat top)                    │                         │
y=248              ╔═ Switch ═╗          │                         │
y=253  ▓zom▓ ░pet░ ║          ║          │                         │
y=280              ╚══════════╝          └─────────────────────────┘
y=296 ╔══ Crypt Closet ══╗  Music   Sound   Fullscreen
```

- Gaps: name bottom y 220 → hat top y 237 = 17 px. Pet right edge x 100 → Switch x 112 = 12 px.
  Switch bottom y 280 → Closet top y 296 = 16 px. Switch right x 224 → notice x 288 = 64 px.

## Frame C: report card, 12 W's + witch hat + mortarboard + pet + "New best!" + bonus row

```
x: 16                                         432                    624
y=6                              ┌New best!┐  ┌───── window ────────┐   stamp and window unchanged
y=12  ┌── chalkboard ─────────────────────┐   │                     │
      │ Zombie Run                        │   └─────────────────────┘ y 122
      │ ... stats ...       +10 bonus     │
y=216 ─────────────────────────────────────── wall line ─────────────
y=220 │                                   │ WWWWWWWWWWWW                 %ZombieName: 16 px ink #1E1428,
y=236 │                                   │                              x 432–624, y 220–236, left-aligned
y=240 ─────────────────────────────────────── wall line ─────────────   (sits between two wall lines)
y=254 │                                   │  ▀▀ mortarboard top
y=270 │                                   │ ▓prof▓    ░pet░
y=288 └───────────────────────────────────┘ ─── floor ───
y=308  ╔ Play Again ╗ [Enter]  ╔ Menu ╗ [Esc]                           buttons unchanged
```

- Left-aligned from x 432 so a short name ("Sam") sits right above the professor's head (x 436–456);
  12 W's end exactly on the right margin (x 624).
- Name y 220–236 sits in the gap between the wall lines at y 216 and y 240, so no stripe runs through
  the letters. Name bottom y 236 → mortarboard top y 254 = 18 px.
- Contrast: ink `#1E1428` on parchment-shade `#D9BC84` = **9.7:1** (≥ 4.5:1).

## Keys and mouse (menu)

- Switch: Enter / Space / click opens "Who's playing?". Hover moves focus to it (PixelButton).
- On the picker opened from the menu, Esc goes back to the menu (switching nothing); Enter on the
  already-focused current zombie also goes back. Opened from the title, Esc still does nothing.
- The name is decoration: it never takes focus and ignores the mouse, on both screens.

## Focus map (menu; only the Switch-related moves change)

| From | Up | Down | Left | Right |
|---|---|---|---|---|
| Any card | Progress | Crypt Closet | card − 1 | card + 1 |
| **Switch** | first choosable card (else Progress) | Crypt Closet | — | — |
| Crypt Closet | **Switch** | — | — | Music |
| Music / Sound / Fullscreen | first choosable card | — | row | row |
| Progress | — | first choosable card (else Closet) | — | — |

Tab: cards → Switch → Closet → Music → Sound → Fullscreen → Progress → (wrap). Opening focus unchanged.

## Copy list

| Where | Copy |
|---|---|
| Menu button beside the zombie | "Switch" |
| Name of a zombie with no valid name (hand-edited save) | "Zombie" (`GameConstants.ZOMBIE_NAME_DEFAULT`) |
