# "Who's playing?" screen layout sketch (Story 11.2)

Status: **approved by Smuck, 2026-10-15 ("Approve as drawn"; name first then picker; 4 zombies, "New zombie" hidden at the cap; duplicate names refused; a plain zombie on the name screen in new-zombie mode)**

Canvas 640 × 360 logical, 16 px margin (safe rect x 16–624, y 16–344), 4 px grid.
Font: Press Start 2P (theme font): every character is exactly as wide as the font size (16 px at 16, 24 px at 24).
Panels use the existing theme variations (no new art): `Sign` (parchment heading), `TileParchment` + `ShadowMd` (the Crypt Closet tile look) for each zombie card, `FocusRing` (candy yellow, focus only), `PixelButton` (wood plank).
Colours: night background `#2B1D3F` (as the main menu, the welcome gift and the name screen), ink `#1E1428` on parchment.
Reached from the title when at least one zombie has a name. Leaves to the main menu (pick a named zombie), the name screen (pick an unnamed zombie, or "New zombie").

## Frame A: one zombie (the usual case right after Story 11.1)

Focus starts on the card of the zombie that played last.

```
x: 16        144                                         496        624
y=16          ┌───────────── Who's playing? ─────────────┐             Sign, heading 24 px ink, x 144–496, y 16–56
y=56          └──────────────────────────────────────────┘
y=68         ╔┌──────────────────────────────────────────┐╗            Card 1 (focused): x 144–496, y 68–120
              │  🎩                                       │             hat on the zombie's head (1×), pet beside it
              │ ▓zom▓ ░pet░   Sam                         │             zombie x 160–192, pet x 196–228, name 16 px x 248
y=120        ╚└──────────────────────────────────────────┘╝            candy-yellow FocusRing around the focused card only
y=132                     ╔═══ New zombie ═══╗                          PixelButton x 224–416, y 132–164
y=164                     ╚══════════════════╝
```

- The list is **top-aligned** under the sign; "New zombie" sits 12 px under the last card. With one zombie the lower half of the screen is empty night sky.

## Frame B: four zombies (MAX_ZOMBIES), 12-character names, hats and pets

```
x: 16        144                                         496        624
y=16          ┌───────────── Who's playing? ─────────────┐
y=56          └──────────────────────────────────────────┘
y=68          ┌──────────────────────────────────────────┐             Card 1: y 68–120
              │ ▓zom▓ ░pet░   WWWWWWWWWWWW               │             12 × 16 = 192 px: name x 248–440 (card inner edge 488)
y=120         └──────────────────────────────────────────┘
y=124        ╔┌──────────────────────────────────────────┐╗            Card 2 (focused): y 124–176
              │ ▓zom▓ ░pet░   WWWWWWWWWWWW               │
y=176        ╚└──────────────────────────────────────────┘╝
y=180         ┌──────────────────────────────────────────┐             Card 3: y 180–232
              │ ▓zom▓         WWWWWWWWWWWW               │             (no pet: the space stays empty)
y=232         └──────────────────────────────────────────┘
y=236         ┌──────────────────────────────────────────┐             Card 4: y 236–288
              │ ▓zom▓         Zombie                     │             (a hand-edited save with no valid name shows "Zombie")
y=288         └──────────────────────────────────────────┘
y=300                     ╔═══ New zombie ═══╗                          New zombie: y 300–332 (hidden at the cap, see Frame C)
y=332                     ╚══════════════════╝
```

## Frame C: at the cap (MAX_ZOMBIES zombies)

Same as Frame B **without** the "New zombie" button: it is not shown and focus can't reach it. The last card is the end of the focus list.

## Frame D: the name screen in new-zombie mode (one screen, Story 11.1's)

Opened by "New zombie". The field starts **empty** (not the last zombie's name). A **Back** plank sits left of Done.

```
y=16        ┌──────────── Name your zombie! ─────────────────┐            unchanged from 11.1
y=112                          ▓▓▓▓▓▓▓▓                                  a plain zombie: no hat, no pet (the new zombie
y=176                          ▓▓▓▓▓▓▓▓                                  owns nothing yet; approved at Gate 1)
y=196       ┌── Chalkboard ─────────────────────────────────┐
            │ ▁▁▁                                           │             empty field, caret at the start
y=244       └───────────────────────────────────────────────┘
y=272         ╔═ Back ═╗      ╔══ Done ══╗ [Enter]                        Back x 144–240, Done x 256–352 (unchanged), keycap x 360–440
y=304         ╚════════╝      ╚══════════╝
```

- Focus starts on Done (as in 11.1). Left/Right move between Back and Done. Esc = Back.
- Done with an empty name, a name with no letters, or a name another zombie already has (ignoring capitals): the chalkboard wiggles (0.2 s), no sound, no text. The kid can look at the picker's cards to see the names already used.
- Back (or Esc) returns to "Who's playing?" and nothing is created. The new zombie only exists once Done saves a good name.
- Without "New zombie" (the title sending an unnamed zombie, or picking an unnamed card) the screen is exactly Story 11.1's: no Back, Esc does nothing, an empty Done saves "Zombie".

## Measurements

- Heading "Who's playing?" = 14 glyphs × 24 px = 336 px + 8 px padding each side = 352 px sign (x 144–496), centred on x 320.
- Card 352 × 52 (x 144–496), 4 px gap between cards: 4 cards = 4 × 52 + 3 × 4 = 220 px → y 68–288.
- Inside a card: zombie (32 px sprite, 1×) x 160–192 with feet 8 px above the card's bottom, hat on its head (reaches ~10 px above the head, still inside the card); pet (32 px) x 196–228; name 16 px ink from x 248, 12 glyphs end at x 440, 48 px before the card's right edge.
- "New zombie" = 10 glyphs × 16 = 160 px + 32 px plank padding = 192 px (x 224–416), 32 px tall. Every control ≥ 32 px tall (cards 52).
- Everything sits inside x 16–624, y 16–344. No brains, WPM, tier, dates or "best" on the cards: no comparing zombies (NFR10).

## Keys and mouse

- Up/Down (and Left/Right) move focus one card at a time, in list order, then to "New zombie"; ends stop (no wrap). Tab / Shift+Tab walk the same order.
- Enter, Space or a left click picks the focused or clicked card. Hovering a card moves the focus to it, so only one thing is ever highlighted.
- Esc does nothing (the title is not a place to go back to, same as the main menu).

## Focus map

| From | Up | Down | Left | Right |
|---|---|---|---|---|
| Card 1 | — | Card 2 | — | Card 2 |
| Card k | Card k−1 | Card k+1 (last card → New zombie) | Card k−1 | Card k+1 |
| New zombie | last card | — | last card | — |

Name screen, new-zombie mode: Back ↔ Done (Left/Right, Tab), ends stop.

## Copy list (approved 2026-10-15)

| Where | Copy |
|---|---|
| Heading on the sign | "Who's playing?" |
| Button under the cards | "New zombie" |
| Name screen, new-zombie mode, left of Done | "Back" |
| Card of a zombie with no valid name | "Zombie" (GameConstants.ZOMBIE_NAME_DEFAULT) |
