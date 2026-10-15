# Name your zombie screen layout sketch (Story 11.1)

Status: **approved by Smuck, 2026-10-15 ("Approve as drawn"; new saves asked too, case kept as typed, no word check)**

Canvas 640 × 360 logical, 16 px margin (safe rect x 16–624, y 16–344), 4 px grid.
Font: Press Start 2P (theme font): every character is exactly as wide as the font size (16 px at 16, 24 px at 24).
Panels use the existing theme variations (no new art): `Sign` (parchment), `Chalkboard` (8 px frame), `PixelButton`, `Keycap`.
Colours: night background `#2B1D3F` (as the main menu and the welcome gift), ink `#1E1428` on parchment, chalk `#F4F1E4` on the chalkboard.
Reached only from the title, when the active zombie has no name yet. Leaves only to the main menu.

## Frame A: empty (just arrived)

Focus on **Done** (the only control on the screen), drawn with the plank's "off" look: grey plank and grey text, candy-yellow focus ring still on.

```
x: 16      108                                              532       624
y=16        ┌──────────── Name your zombie! ─────────────────┐            Sign, heading 24 px ink, x 108–532, y 16–56
y=56        └────────────────────────────────────────────────┘
                                                                          (the hat sits above the head, up to y ~92)
y=112                          ▓▓▓▓▓▓▓▓      ░░░░░░░░                     Zombie x 252–316, pet x 324–388
                               ▓ zombie ▓    ░ pet  ░                     both 32 px sprites drawn at 2× (64 px), feet on y 176
y=176                          ▓▓▓▓▓▓▓▓      ░░░░░░░░
y=196       ┌── Chalkboard ─────────────────────────────────┐             NameField x 152–488, y 196–244
            │ ▁▁▁                                           │             caret: 24 × 4 chalk underline where the next letter goes
y=244       └───────────────────────────────────────────────┘
y=272                         ╔══ Done ══╗ [Enter]                        Done x 256–352, y 272–304; Enter keycap x 360–440, y 276–300
y=304                         ╚══════════╝
```

## Frame B: filled (12 characters, Done ready)

```
y=196       ┌── Chalkboard ─────────────────────────────────┐
            │ WWWWWWWWWWWW                                  │             name 24 px chalk, starts x 164 (frame 8 + 4 padding)
y=244       └───────────────────────────────────────────────┘             12 × 24 = 288 px → ends x 452; caret hidden when full
y=272                         ╔══ Done ══╗ [Enter]                        Done back to the normal plank (pumpkin-light while focused)
```

- With fewer than 12 characters the caret sits right after the last letter (e.g. "Sam" → caret x 236–260). Steady, no blinking.
- Done with an empty name: Enter or a click gives the chalkboard a small side-to-side wiggle (0.2 s), no sound, no text.
- The name is the kid's own words: never checked by the plain-words test, never logged.

## Measurements

- Heading "Name your zombie!" = 17 glyphs × 24 px = 408 px + 8 px padding each side = 424 px sign (x 108–532), centred.
- NameField inner width 336 − 16 (frame) = 320 px; 12 letters (288 px) + caret (24 px) = 312 px fits with 4 px padding left.
- Zombie and pet at 2×: integer scale keeps the pixels crisp; the pair is centred on x 320.
- Done: "Done" = 4 glyphs = 64 px + 32 px plank padding = 96 px, 32 px tall. Keycap "Enter" = 5 glyphs × 16 = 80 → x 360–440 (keycap style as the report card).
- Everything sits inside x 16–624, y 16–344. Nothing in the corners (no brain counter, no Progress button: this screen is only about the name).

## Keys

- Letters A–Z / a–z add a letter (case as typed). Space adds one space between words (never first, never two in a row). Backspace removes the last character.
- Enter = Done. Esc does nothing (there is nowhere to go back to). Every other key does nothing, silently.
- While this screen is open the browser doesn't scroll on Space or go back on Backspace (same key capture as during a game).

## Focus map

- Only **Done**; it starts focused. Tab / arrows stay on it. Space never presses it (Space types a space).

## Copy list (approved 2026-10-15)

| Where | Copy |
|---|---|
| Heading on the sign | "Name your zombie!" |
| Button | "Done" |
| Keycap beside the button | "Enter" |
