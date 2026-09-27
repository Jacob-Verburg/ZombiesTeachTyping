---
name: zombies-teach-typing
description: Cute-Halloween, early-90s pixel-art menus and HUD for a kids' typing game where you are the zombie. Chunky wood and stone panels, hand-lettered signs, a chalkboard that follows you everywhere.
status: final
created: 2026-09-27
updated: 2026-09-27
sources:
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/decision-log.md
  - _bmad-output/game-architecture.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/.decision-log.md
colors:
  # --- UI palette (24) — approved by the developer 2026-09-27 (D13) ---
  ink: '#1E1428'
  night: '#2B1D3F'
  dusk: '#4A3366'
  parchment: '#F6E7C1'
  parchment-shade: '#D9BC84'
  ink-faded: '#8A7552'
  ink-muted: '#4E4757'
  wood-dark: '#5A3218'
  wood: '#8A5228'
  wood-light: '#C08447'
  stone: '#6F6A80'
  stone-light: '#BDB6C4'
  chalkboard: '#24402F'
  chalk: '#F4F1E4'
  chalk-dim: '#A8C4A6'
  pumpkin: '#F07A1C'
  pumpkin-light: '#FFA94A'
  candy-yellow: '#FFD23F'
  zombie-green: '#6CC24A'
  zombie-green-bright: '#B8F27C'
  zombie-green-dark: '#2E6B26'
  bat-purple: '#7A4BB3'
  stamp-red: '#B02A25'
  disabled-fill: '#CFC6B6'
  # --- Reserved for level/character art (8) — same shared 32-colour budget ---
  art-sky: '#7EC8E3'
  art-sky-light: '#BFE6F2'
  art-grass: '#4E9A34'
  art-skin-light: '#F2C9A0'
  art-skin-dark: '#B07850'
  art-brain-pink: '#F29AB8'
  art-brain-shade: '#C9607F'
  art-moon: '#FFF3B0'
typography:
  # One SIL OFL pixel font for everything (specific font deferred — D11).
  # Sizes must be whole multiples of the chosen font's native pixel size.
  target:
    fontFamily: 'project-pixel-font'
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 32px
  paragraph:
    fontFamily: 'project-pixel-font'
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 24px
  heading:
    fontFamily: 'project-pixel-font'
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 28px
  label:
    fontFamily: 'project-pixel-font'
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 20px
  stat:
    fontFamily: 'project-pixel-font'
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 20px
    note: 'Digits must be fixed-width in the chosen font (or tabular via per-glyph advance) so Timer/WPM do not jitter'
  countdown:
    fontFamily: 'project-pixel-font'
    fontSize: 64px
    fontWeight: '400'
    lineHeight: 64px
rounded:
  none: 0px
  sm: 2px
  md: 4px
  lg: 8px
  full: 9999px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '6': 24px
  '8': 32px
  outline: 1px
  focus-ring: 2px
  drop-shadow: 2px
  viewport-width: 640px
  viewport-height: 360px
  screen-margin: 16px
  hud-band-height: 104px
  hud-pad: 4px
  hud-pet-slot-width: 64px
  hud-stats-width: 136px
  hud-hands-height: 48px
  button-min-height: 32px
components:
  pixel-button:
    background: '{colors.wood}'
    border: '{colors.ink}'
    text: '{colors.chalk}'
    typography: '{typography.label}'
    rounded: '{rounded.md}'
    minHeight: '{spacing.button-min-height}'
    padding: '{spacing.2}'
  pixel-button-focus:
    background: '{colors.pumpkin-light}'
    text: '{colors.ink}'
    ring: '{colors.candy-yellow}'
    ringWidth: '{spacing.focus-ring}'
  pixel-button-pressed:
    background: '{colors.pumpkin}'
    text: '{colors.ink}'
    offsetY: '{spacing.drop-shadow}'
  pixel-button-disabled:
    background: '{colors.disabled-fill}'
    text: '{colors.ink-muted}'
  panel-wood:
    background: '{colors.wood}'
    frame: '{colors.wood-dark}'
    highlight: '{colors.wood-light}'
    border: '{colors.ink}'
    rounded: '{rounded.lg}'
    padding: '{spacing.2}'
  panel-stone:
    background: '{colors.stone}'
    highlight: '{colors.stone-light}'
    border: '{colors.ink}'
    rounded: '{rounded.lg}'
  sign:
    background: '{colors.parchment}'
    shade: '{colors.parchment-shade}'
    text: '{colors.ink}'
    post: '{colors.wood-dark}'
    typography: '{typography.heading}'
    rounded: '{rounded.sm}'
  level-card:
    frame: '{colors.wood-dark}'
    picture: 'ui_level_card_<level_id>.png'
    nameSign: '{components.sign}'
    rounded: '{rounded.lg}'
  level-card-focus:
    ring: '{colors.candy-yellow}'
    ringWidth: '{spacing.focus-ring}'
    liftY: '{spacing.drop-shadow}'
  level-card-locked:
    pictureTint: '{colors.dusk}'
    padlock: '{colors.stone-light}'
    hintText: '{colors.ink}'
    hintBackground: '{colors.parchment}'
    hintTypography: '{typography.label}'
    note: 'Padlock only at rest; hint sign shows only while the card has focus (D14)'
  level-card-coming-soon:
    pictureTint: '{colors.stone}'
    plank: '{colors.wood}'
    plankText: '{colors.chalk}'
  level-card-new:
    badge: '{colors.pumpkin}'
    badgeText: '{colors.ink}'
    note: 'Badge sits on the top-right corner, overlapping the frame (D16)'
  closet-item-tile:
    background: '{colors.parchment}'
    border: '{colors.ink}'
    priceText: '{colors.ink}'
    rounded: '{rounded.md}'
    size: 48px
  closet-item-tile-locked:
    background: '{colors.stone}'
    silhouette: '{colors.ink-muted}'
    text: '{colors.chalk}'
  closet-item-tile-cant-afford:
    background: '{colors.disabled-fill}'
    text: '{colors.ink-muted}'
  closet-item-tile-buy:
    tag: '{colors.pumpkin}'
    tagText: '{colors.ink}'
  closet-item-tile-wear:
    tag: '{colors.zombie-green}'
    tagText: '{colors.ink}'
  closet-item-tile-wearing:
    tag: '{colors.zombie-green-bright}'
    tagText: '{colors.ink}'
    check: '{colors.zombie-green-dark}'
  toggle:
    base: '{components.pixel-button}'
    onIcon: '{colors.zombie-green-bright}'
    offIcon: '{colors.stone-light}'
    offSlash: '{colors.stamp-red}'
  chalkboard:
    background: '{colors.chalkboard}'
    frame: '{colors.wood}'
    text: '{colors.chalk}'
    labelText: '{colors.chalk-dim}'
    accentText: '{colors.candy-yellow}'
    typography: '{typography.label}'
  new-best-stamp:
    ink: '{colors.stamp-red}'
    text: '{colors.chalk}'
    rotation: -8deg
  confirm-prompt:
    panel: '{components.panel-wood}'
    body: '{components.sign}'
    scrim: '{colors.night}'
    scrimOpacity: 0.6
  tutorial-arrow:
    fill: '{colors.candy-yellow}'
    border: '{colors.ink}'
  storage-notice:
    background: '{colors.parchment}'
    text: '{colors.ink}'
    typography: '{typography.label}'
  welcome-gift-card:
    panel: '{components.panel-wood}'
    ribbon: '{colors.pumpkin}'
    text: '{colors.ink}'
  brain-counter:
    icon: '{colors.art-brain-pink}'
    iconShade: '{colors.art-brain-shade}'
    text: '{colors.chalk}'
    background: '{colors.wood-dark}'
    typography: '{typography.stat}'
  pet-slot:
    cushion: '{colors.parchment}'
    cushionShade: '{colors.parchment-shade}'
    width: '{spacing.hud-pet-slot-width}'
  hat-slot:
    note: 'No chrome; overlay sprite anchored to the zombie head point'
  hud-band:
    height: '{spacing.hud-band-height}'
    background: '{colors.wood-dark}'
    frame: '{colors.wood}'
    border: '{colors.ink}'
    pad: '{spacing.hud-pad}'
  target-letter:
    sign: '{colors.parchment}'
    text: '{colors.ink}'
    typography: '{typography.target}'
  target-word:
    sign: '{colors.parchment}'
    untyped: '{colors.ink}'
    typed: '{colors.zombie-green-dark}'
    nextUnderline: '{colors.ink}'
    typography: '{typography.target}'
  target-tag:
    sign: '{colors.parchment}'
    text: '{colors.ink}'
    border: '{colors.ink}'
    activeArrow: '{colors.candy-yellow}'
    rounded: '{rounded.sm}'
    note: 'In-world letter tag above each playfield target; from mock'
  target-paragraph:
    sign: '{colors.parchment}'
    untyped: '{colors.ink}'
    typed: '{colors.zombie-green-dark}'
    nextUnderline: '{colors.ink}'
    nextLine: '{colors.ink-faded}'
    spaceMarker: '{colors.ink-faded}'
    typography: '{typography.paragraph}'
  zombie-hands:
    skin: '{colors.zombie-green}'
    outline: '{colors.ink}'
    activeFinger: '{colors.zombie-green-bright}'
    activeOutline: '{colors.candy-yellow}'
    homeBump: '{colors.zombie-green-dark}'
    height: '{spacing.hud-hands-height}'
  stats-column:
    background: '{components.chalkboard}'
    label: '{colors.chalk-dim}'
    value: '{colors.chalk}'
    typography: '{typography.stat}'
    width: '{spacing.hud-stats-width}'
  key-hint:
    background: '{colors.parchment}'
    border: '{colors.ink}'
    text: '{colors.ink}'
    typography: '{typography.label}'
    rounded: '{rounded.sm}'
  report-card-backdrop:
    wall: '{colors.parchment-shade}'
    window: '{colors.night}'
    floor: '{colors.wood}'
  caps-lock-hint:
    background: '{colors.candy-yellow}'
    text: '{colors.ink}'
    typography: '{typography.label}'
  pause-button:
    base: '{components.pixel-button}'
    icon: '{colors.chalk}'
    size: 24px
  pause-panel:
    panel: '{components.panel-stone}'
    scrim: '{colors.night}'
    scrimOpacity: 0.6
  countdown:
    text: '{colors.candy-yellow}'
    outline: '{colors.ink}'
    typography: '{typography.countdown}'
  title-prompt:
    text: '{colors.chalk}'
    typography: '{typography.label}'
  boot-splash:
    background: '{colors.night}'
    progress: '{colors.pumpkin}'
    progressTrack: '{colors.dusk}'
---

# DESIGN.md — Zombies Teach Typing

> **Spines win.** This file and `EXPERIENCE.md` are the contract. On any conflict with a mock, wireframe, layout sketch or import, the spines win and the other artifact is updated. The layout sketches required by Stories 2.5, 2.9, 4.2 and 4.4 must conform to the tokens below.

**Visual references** (F8). Three key-screen mocks illustrate these tokens; they are references, not specs:

- Mocked: [Main Menu mock](mockups/key-main-menu.html) (MVP, plus post-MVP Locked / unlock moment / New!), [Run HUD mock](mockups/key-run-hud.html) (letter mode, word mode, wrong key), [Report Card mock](mockups/key-report-card.html) (New best, first run).
- Spine-only (no mock): Title, boot splash, pause panel + countdown, Welcome Gift, Crypt Closet + confirm prompt, paragraph-mode HUD.
- Known mock drift, superseded by later decisions: the Run HUD mock's Horde Rush frame has no brain counter (D15 puts it in every level); the Main Menu mock's Locked cards show the hint sign at rest (D14 shows it only on focus). Sprite pixel scale varies between mocks for legibility only (D16).

## Brand & Style

A Halloween party thrown by a very polite zombie, on a 1992 family PC. Everything is cute-Halloween — pumpkins, friendly bats, candy colors, a moon that's smiling rather than looming — including the daytime levels, which keep a light dusting of Halloween dressing (a pumpkin on a fence post, a bat bunting across Sunny Village Green) so the whole game feels like one place (D6).

The posture borrows from two games and refuses a third. From *Mario Teaches Typing* it takes the structure and the era: big picture level cards, the player's character standing right on the menu, chunky framed panels, hand-drawn signs, and a chalkboard that isn't only on the report card — it's the stats column in the HUD too (D1, D7). From *Plants vs. Zombies* it takes the warmth: chunky rounded wood and stone panels, bouncy squishy buttons, saturated warm colors, hand-lettered signs (D2, D8). From *The Typing of the Dead* it takes nothing — no grit, no gore, no horror lighting, no guns.

The result is rendered as honest early-90s / late-DOS pixel art at 640×360: 1 px dark outlines, hard pixel shadows, stepped corners, no gradients, no soft glows. It should look like it shipped on floppies and still feel good to touch. Goofy, never babyish — a 13-year-old should find it charming, a 6-year-old should never find it scary.

## Colors

The developer approved this palette on 2026-09-27 after reviewing the key-screen mocks (D13). It fits the GDD's hard budget of **≤ 32 colors shared by every sprite and UI element**: 24 UI colors plus 8 reserved for level and character art. Story 1.9's art-style gate checks the first art against it.

**Night and dusk — the Halloween frame**

- **Ink (`#1E1428`)** — a purple-black, not pure black. The 1 px outline on every character, prop, panel and button; the default text color on light surfaces. Using a warm purple instead of `#000` is what keeps the outlines cute rather than harsh.
- **Night (`#2B1D3F`)** — the backdrop behind menus, the boot splash, the letterbox bars and the pause scrim. The "evening sky" of the whole UI.
- **Dusk (`#4A3366`)** — secondary night tone; the tint laid over a **Locked** level card's picture, the boot-splash progress track.
- **Bat Purple (`#7A4BB3`)** — decoration only: bat bunting, ribbon trims, moon halos. Never a state color.

**Wood, stone and paper — the PvZ panels and MTT signs**

- **Wood Dark / Wood / Wood Light (`#5A3218` / `#8A5228` / `#C08447`)** — the three-tone plank ramp for every framed panel, the HUD band frame and the default button. Wood Light is the 1 px top-left bevel highlight.
- **Stone / Stone Light (`#6F6A80` / `#BDB6C4`)** — the alternative panel material (pause panel, locked Closet tiles) and the grey-out tint for **Coming soon** level cards.
- **Parchment / Parchment Shade (`#F6E7C1` / `#D9BC84`)** — hand-lettered signs, the target sign in the HUD, Closet tiles, notices. Every "read this" surface is parchment.
- **Ink Faded (`#8A7552`)** — the dimmed *next line* in paragraph mode and the visible space marker. Only ever on parchment, only ever at ≥ 24 px.
- **Ink Muted (`#4E4757`)** — text on disabled and can't-afford surfaces.
- **Disabled Fill (`#CFC6B6`)** — disabled buttons, can't-afford Closet tiles.

**Chalkboard — carried beyond the report card**

- **Chalkboard (`#24402F`)** — the report card board and the HUD stats column. A green board, like a 1992 classroom.
- **Chalk / Chalk Dim (`#F4F1E4` / `#A8C4A6`)** — values in Chalk, labels in Chalk Dim. Chalk is also the light text color on wood and night.

**Candy — the accents**

- **Pumpkin / Pumpkin Light (`#F07A1C` / `#FFA94A`)** — the primary action color: focused and pressed buttons, the **Buy** tag, the **New!** badge, the Welcome Gift ribbon, the boot-splash bar.
- **Candy Yellow (`#FFD23F`)** — *focus*. The 2 px focus ring on buttons, cards and tiles; the pulsing outline on the active finger; the down-arrow over the active in-world target; the tutorial arrow; the countdown numbers; the Caps Lock hint. If it's candy yellow, it's "look here now".
- **Stamp Red (`#B02A25`)** — only the "New best!" stamp and the slash on an "off" toggle icon. Never an error color — this game has no red error states — and never level art: thrown tomatoes and other red-ish props are drawn in Pumpkin `[ASSUMPTION]` (D16).

**Zombie green — the player**

- **Zombie Green / Bright / Dark (`#6CC24A` / `#B8F27C` / `#2E6B26`)** — the zombie's skin, the finger-guide hands (base / active finger / f-j bumps), the **Wear** and **Wearing** tags, and typed characters in word and paragraph mode (Dark, for contrast on parchment).

**Reserved art colors** — `art-sky`, `art-sky-light`, `art-grass`, `art-skin-light`, `art-skin-dark`, `art-brain-pink`, `art-brain-shade`, `art-moon`. These close the 32-color budget; the brain pair is also the brain-counter icon. Level art reuses UI colors wherever it can (wood fences, pumpkin pumpkins, stone walls) — adding a 33rd color requires dropping one.

**Contrast (WCAG 2.x, computed):**

| Text / foreground | On | Ratio | Where |
|---|---|---|---|
| `ink` | `parchment` | 14.4:1 | target letter/word/paragraph, signs, notices |
| `zombie-green-dark` | `parchment` | 5.3:1 | typed characters |
| `ink-faded` | `parchment` | 3.6:1 | next paragraph line (24 px = large text, AA ≥ 3:1) |
| `chalk` | `chalkboard` | 10.0:1 | stat values, report card |
| `chalk-dim` | `chalkboard` | 6.0:1 | stat labels |
| `candy-yellow` | `chalkboard` | 7.9:1 | "+N bonus" line |
| `chalk` | `wood-dark` | 9.7:1 | brain counter, HUD text on the band |
| `chalk` | `wood` | 5.6:1 | resting button labels |
| `ink` | `pumpkin-light` | 9.3:1 | focused button labels |
| `ink` | `pumpkin` | 6.3:1 | pressed button, Buy tag, New! badge |
| `ink` | `candy-yellow` | 12.3:1 | Caps Lock hint, tutorial arrow text |
| `chalk` | `stamp-red` | 5.8:1 | "New best!" stamp |
| `chalk` | `night` | 13.7:1 | title prompt, text on backdrops |
| `ink-muted` | `disabled-fill` | 5.3:1 | disabled / can't-afford text |
| `ink` | `zombie-green-bright` | 13.5:1 | Wearing tag |

Every load-bearing pair meets AA (4.5:1) except `ink-faded`, which is used only for ≥ 24 px text where AA-large (3:1) applies. The palette must also pass a **grayscale review** (Story 5.2): the active finger, typed-vs-untyped text and every tile state must still read without hue.

## Typography

One pixel font, SIL Open Font License, with unmistakable `l` / `I` / `1` and `O` / `0` (GDD Asset Requirements; Story 1.3). The specific font is **deferred** (D11); the traits are the spec: a chunky, friendly, slightly rounded bitmap face in the spirit of early-90s DOS edutainment, readable by a 6-year-old — no condensed, no script, no all-caps-only faces. It is the default font of `data/ui_theme.tres`.

| Role | Token | Size | Use |
|---|---|---|---|
| Target | `{typography.target}` | 32 px | the single letter (letter mode) and the word (word mode) |
| Paragraph | `{typography.paragraph}` | 24 px, 24 px line | the 2-line window in paragraph mode — no extra leading, so both lines plus the hands fit the band |
| Heading | `{typography.heading}` | 24 px | panel titles, confirm-prompt question, Welcome Gift heading |
| Label | `{typography.label}` | 16 px | every button, toggle, hint, notice and caption |
| Stat | `{typography.stat}` | 16 px | Timer, Keys Typed, WPM, Errors, brain counts, chalkboard values |
| Countdown | `{typography.countdown}` | 64 px | the 3-2-1 after Resume |

Rules:

- **16 px is the floor** for any text anywhere; 32 px for letter/word targets; 24 px for paragraph lines (GDD Readability, U2).
- Sizes are whole multiples of the chosen font's native pixel size — never a fractional size that smears glyphs. If the chosen font's native size doesn't divide these values, the sizes snap to the nearest multiple at or above the floor.
- Digits in stats must not jitter as they change: pick a font with uniform digit widths, or right-align stats in fixed-width slots.
- **Hand-lettered signs** — the title logo, level names on the level cards, "Coming soon", "New best!", "Crypt Closet" — are drawn as pixel-art sprites (`ui_<element>.png`), not set in the font. Anything dynamic (numbers, prices, "Need N more", notices) uses the font. `[ASSUMPTION]`
- Level-name signs get tuned (tightened) letter-spacing in the sprite lettering so the longest name, "Pitchfork Panic", fits the card width without shrinking the letters `[ASSUMPTION]` (D16).
- Sentence case everywhere. No all-caps labels except inside hand-lettered sign art.

## Layout & Spacing

Fixed **640 × 360 logical** canvas (`{spacing.viewport-width}` × `{spacing.viewport-height}`), stretch mode `viewport`, aspect `keep`, fractional scaling with nearest filtering (GDD Art Style; ARCH Scaling; U1). Letterbox bars are `{colors.night}` `[ASSUMPTION]`. Layout never reflows — the canvas scales as a whole.

Scale is a 4 px grid: 4 / 8 / 12 / 16 / 24 / 32. `{spacing.screen-margin}` (16 px) keeps every control off the canvas edge.

**Run screen (every level)** — see the [Run HUD mock](mockups/key-run-hud.html):

```
┌──────────────────────────────────────────────────────── 640 ─┐
│                                                          [II]│ ← pause-button, top-right, 16 px margin
│                     playfield (level art)                    │
│                                                     256 px   │
├──────────────────────────────────────────────────────────────┤
│ [pet ]│        ┌── target sign ──┐        │ Timer   1:23 │ B │ ← hud-band, 104 px
│ [slot]│        │       f         │        │ Keys      42 │ 12│   (B = brain-counter: every level, D15)
│  64px │        └─────────────────┘        │ WPM       11 │   │
│       │     (L) zombie-hands (R) 48 px    │ Errors     3 │   │
└──────────────────────────────────────────────────────────────┘
```

- `{components.hud-band}` is **104 px** in every level and never changes height (U2).
- Left to right: pet slot (`{spacing.hud-pet-slot-width}`) · target area (flex) with zombie hands directly below (`{spacing.hud-hands-height}`) · stats column (`{spacing.hud-stats-width}`) · brain counter beside the stats, in **every** level (D15; overrides GDD M2b — see EXPERIENCE.md Upstream changes).
- The target sign is centered in the target area; in word mode its width grows with the word — the text never shrinks `[ASSUMPTION — from mock]`.
- Vertical budget in paragraph mode: 4 pad + 2 × 24 px lines + 48 px hands + 4 pad = 104 px. Letter and word mode: the 32 px target sits in a sign with 4 px padding, leaving room above the hands.
- The widths above are `[ASSUMPTION]` starting values; the approved Story 2.5 layout sketch fixes them.

**Menu screens** center on a single composition, not a list (GDD Screens & Flow; FR26). The main menu (see the [Main Menu mock](mockups/key-main-menu.html)) places the logo top-center, the brain counter top-left, the player's zombie and pet bottom-left, the three level cards in a row across the middle, the Crypt Closet button hanging on a wooden signpost beside the zombie (D16), and the Music / Sound / Fullscreen toggles bottom-right `[ASSUMPTION — from mock]`. Level cards are about 150 px wide `[ASSUMPTION — from mock]`; the Locked-card focus hint hangs just below the focused card (see Components).

**Report card** (see the [Report Card mock](mockups/key-report-card.html)): a night classroom backdrop — `{colors.parchment-shade}` wall, a window onto the Halloween night, a `{colors.wood}` floor (D16). The chalkboard sits left with the level name as its heading (D16), Professor Zombie stands right pointing at it, and Play Again / Menu sit side by side on the floor below, each with a key hint ("Enter" / "Esc") beside it `[ASSUMPTION — from mock]`.

Every arrangement above is `[ASSUMPTION]` until its sketch is approved: main menu by Story 4.2, Closet by Story 4.4, report card by Story 2.9.

## Elevation & Depth

No blur, no soft shadow, no glow — they don't exist on a 1992 VGA card. Depth comes from three things:

1. **The 1 px `{colors.ink}` outline** around every panel, button, card, tile and sprite.
2. **A hard 2 px drop shadow** (`{spacing.drop-shadow}`) in `{colors.ink}`, down and right, under buttons, cards and signs. A pressed button drops onto its shadow (moves down 2 px, shadow disappears).
3. **Tonal layers**, back to front: `{colors.night}` backdrop with Halloween dressing → wood/stone panels → parchment signs → focus ring.

One modal layer at most: the pause panel and the Closet confirm prompt sit over a `{colors.night}` scrim at 60% opacity. This scrim is the **only** alpha blend in the UI and is the one sanctioned exception to "palette colors only" `[ASSUMPTION]`. Nothing stacks two modals deep.

## Shapes

Corners are **stepped pixels**, not vector curves: `{rounded.sm}` (2 px) = one pixel notched from each corner, `{rounded.md}` (4 px) = a 2-step notch, `{rounded.lg}` (8 px) = a 3–4 step curve. They're drawn into 9-slice `StyleBoxTexture`s in the Theme, never generated by `StyleBoxFlat` corner radius (which anti-aliases).

- `{rounded.lg}` — panels, level cards, the chalkboard frame: chunky and friendly (PvZ).
- `{rounded.md}` — buttons, Closet tiles, toggles.
- `{rounded.sm}` — signs and notices (planks with nearly-square ends).
- `{rounded.full}` — only the pause button and the brain-counter pill.
- Nothing is sharp-cornered except the canvas itself.

## Components

Godot Control nodes with one shared Theme, `data/ui_theme.tres`; art files follow `ui_<element>[_<state>].png` (ARCH naming). Widget scenes named in the architecture are noted in brackets.

**Screen UI**

- **Pixel button** [`pixel_button`] — wooden plank, `{colors.wood}` fill, Wood Light top-left bevel, ink outline, `{rounded.md}`, 2 px drop shadow, label in `{typography.label}` `{colors.chalk}`. Min 32 px tall.
  - *Focus:* fill `{colors.pumpkin-light}`, label `{colors.ink}`, 2 px `{colors.candy-yellow}` ring outside the outline.
  - *Pressed:* fill `{colors.pumpkin}`, shifts down 2 px onto its shadow, squishes (see EXPERIENCE.md Game Feel).
  - *Disabled:* `{colors.disabled-fill}`, label `{colors.ink-muted}`, no shadow.
  - States art: `ui_button.png`, `ui_button_focus.png`, `ui_button_pressed.png`, `ui_button_disabled.png`.
- **Panel (wood / stone)** — framed planks (wood) or blocks (stone), `{rounded.lg}`, 8 px inner padding. Wood is the default; stone is for the pause panel and anything "interrupting". Corners may carry a small Halloween detail (a nail, a tiny pumpkin, a cobweb) — decoration only.
- **Sign** — parchment plank on a wood post or nailed to a panel, ink text, `{rounded.sm}`. The MTT hand-drawn-sign trait lives here.
- **Level card** — a big picture window of the level's scene in a `{colors.wood-dark}` frame, with a parchment name sign (hand-lettered sprite) nailed at the bottom. On Coming soon cards the name sign is greyed with the picture `[ASSUMPTION — from mock]`.
  - *Available:* full-color picture.
  - *Focus:* 2 px candy-yellow ring, card lifts 2 px (shadow grows).
  - *Locked (D12, D14):* picture tinted `{colors.dusk}` with a big `{colors.stone-light}` padlock over it — **nothing else on the card at rest**. While the card has focus (arrow focus or hover), a parchment hint sign in `{typography.label}` hangs on two strings just below the card (copy in EXPERIENCE.md Voice and Tone) and disappears when focus leaves. Hint placement is from the Main Menu mock `[ASSUMPTION]`. The card stays focusable so the hint can be read.
  - *Coming soon:* picture tinted `{colors.stone}` (greyed), a `{colors.wood}` plank nailed diagonally across it with the hand-lettered "Coming soon" in chalk. Visually distinct from Locked: grey + plank vs purple + padlock. **Coming soon wins** when both apply.
  - *New (just unlocked):* full-color picture plus a `{colors.pumpkin}` "New!" badge on the **top-right** corner, overlapping the frame (D16, `[ASSUMPTION]`), until the card is first chosen `[ASSUMPTION — badge lifetime]`.
- **Closet item tile** [`closet_item_tile`] — 48 px parchment square with the item art, price in `{typography.stat}` below. Exactly one state at a time (FR40):
  - *Locked — coming soon:* `{colors.stone}` fill, ink-muted "?" silhouette, "Coming soon" in `{typography.label}`.
  - *Can't afford:* `{colors.disabled-fill}` fill, full item art, "Need N more" in `{colors.ink-muted}`.
  - *Buy:* parchment, item art, `{colors.pumpkin}` "Buy" tag.
  - *Wear:* parchment, `{colors.zombie-green}` "Wear" tag.
  - *Wearing:* parchment, `{colors.zombie-green-bright}` "Wearing" tag with a `{colors.zombie-green-dark}` check mark — the shape (check) carries the state, not only the color.
  - *Focus:* 2 px candy-yellow ring, same as buttons.
- **Toggle** (Music / Sound / Fullscreen) — a pixel button with an icon: note, speaker, four-corner arrows. *On:* icon in `{colors.zombie-green-bright}`. *Off:* icon in `{colors.stone-light}` with a `{colors.stamp-red}` diagonal slash. The slash, not the color, is the signal. Label below in `{typography.label}`.
- **Chalkboard** — `{colors.chalkboard}` board in a `{colors.wood}` frame with a chalk tray. Labels in `{colors.chalk-dim}`, values in `{colors.chalk}`, the "+N bonus" line in `{colors.candy-yellow}`. Faint chalk smudges are allowed as texture (palette colors only). Used on the report card and as the HUD stats column.
- **"New best!" stamp** — a slightly rotated (−8°, pre-rotated in the sprite, not rotated at runtime) rubber-stamp shape in `{colors.stamp-red}` with chalk lettering, stamped onto the chalkboard's corner. Hand-lettered sprite.
- **Confirm prompt** — wood panel over the night scrim, a parchment sign with the question in `{typography.heading}`, two pixel buttons side by side.
- **Tutorial arrow** — a chunky `{colors.candy-yellow}` pointing hand-drawn arrow with an ink outline, bobbing beside its target.
- **Welcome Gift card** — wood panel wrapped with a `{colors.pumpkin}` ribbon and bow, "Welcome gift!" sign, the +100 with the brain icon, one pixel button.
- **Storage notice** — a small parchment note in `{typography.label}`, pinned to a menu corner (a pixel thumbtack). Informational, not alarming: no red, no icon of danger.
- **Key hint** — a small parchment keycap ("Enter", "Esc") in `{typography.label}` with an ink outline, beside the button it triggers on the report card `[ASSUMPTION — from mock]`. Plain words, never glyphs.
- **Title prompt** — "Click or press any key" in chalk on the night backdrop under the logo.
- **Boot splash** (web, D11) — `{colors.night}` page with the logo and a chunky `{colors.pumpkin}` progress bar on a `{colors.dusk}` track; matches the title screen so load → title is seamless.

**HUD**

- **HUD band** — a wood-framed shelf across the bottom 104 px, `{colors.wood-dark}` fill, `{colors.wood}` frame with a 1 px ink top edge. Solid, never transparent over the playfield.
- **Target display** — the target sits on a parchment sign centered in the target area:
  - *Letter:* one glyph, `{typography.target}`, ink.
  - *Word:* the word in `{typography.target}`; typed letters `{colors.zombie-green-dark}`; the next letter underlined with a 2 px ink bar (shape cue).
  - *Paragraph:* two 24 px lines. Current line: typed characters green, next character underlined; next line `{colors.ink-faded}`. At a passage's end, a visible space marker (a small `␣`-style bracket in ink-faded) shows where Space is expected (E8-1).
  - *Wrong key:* the target character shakes (motion spec in EXPERIENCE.md); no color change.
  - *Waiting to start:* the "Type the letter to start!" label sits above the sign in `{typography.label}` chalk.
- **Zombie hands** [finger guide] — two cartoon green hands, palms down, `{colors.zombie-green}` with ink outline, 48 px tall. The next finger is `{colors.zombie-green-bright}` **and** gets a pulsing 1–2 px `{colors.candy-yellow}` outline — brightness plus shape, never hue alone. `f` and `j` fingertips carry a small `{colors.zombie-green-dark}` bump at all times. Art: 2 hands + 10 finger-glow states (`ui_finger_glow_l_index.png` …).
- **Stats column** — a mini chalkboard: four rows, label left (chalk-dim), value right (chalk), `{typography.stat}`. WPM shows "–" until it appears `[ASSUMPTION]`.
- **Brain counter** [`brain_counter`] — `{rounded.full}` wood-dark pill with the pink brain icon and the count in chalk. Used on the HUD in every level (D15), the main menu and the Closet.
- **Pet slot / hat slot** [`pet_slot`, `hat_slot`] — no chrome; the pet idles on a small parchment cushion in the HUD pet slot; empty slot shows only the cushion. On Professor Zombie (report card) the mortarboard stacks on top of the worn hat rather than replacing it `[ASSUMPTION]` (D16).
- **In-world target tag** — each playfield target (villager, brain block) carries its letter on a small parchment tag with an ink outline, `{rounded.sm}`; the active target also bobs under a `{colors.candy-yellow}` down-arrow `[ASSUMPTION — from mock]`. Tag glyphs respect the 16 px floor.
- **Caps Lock hint** — a small `{colors.candy-yellow}` sign with ink text "Caps Lock is on", hung just above the target sign.
- **Pause button** — 24 px round pixel button, two-bar pause icon in chalk, top-right of the playfield.
- **Pause panel** — stone panel over the night scrim: title sign, Resume, Quit to Menu, Music and Sound toggles.
- **Countdown** — 64 px candy-yellow numerals with a 1 px ink outline (plus a 2 px ink shadow), centered on the playfield.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Keep everything cute-Halloween, daytime levels included | Horror lighting, blood, gore, body-part gags, guns (Typing of the Dead) |
| 1 px ink outline and hard 2 px shadow on every piece | Soft shadows, glows, blur, gradients |
| Palette colors only (≤ 32 total); the night scrim is the one alpha exception | Introduce a 33rd color without dropping one |
| Brightness + shape (underline, pulse outline, check, slash) for every state | Signal any state by hue alone |
| 16 px text floor; 32 px targets; 24 px paragraph lines | Shrink text to fit — enlarge the panel or cut words |
| Stepped-pixel corners from 9-slice textures | `StyleBoxFlat` anti-aliased radii |
| Candy yellow means focus/"look here" | Candy yellow as decoration |
| Stamp red only on the stamp and toggle slash; Pumpkin for red-ish level props like thrown tomatoes `[ASSUMPTION]` (D16) | Red for errors or wrong keys — there are no error colors |
| Hand-lettered sprites for fixed sign text | Faux hand-lettering with a second font |
| Distinct Locked (purple + padlock) vs Coming soon (grey + plank) | Make them look alike |
| HUD band identical in every level, brain counter included (D15) | Per-level HUD skins or heights, or dropping a HUD element in some levels |
| One sprite pixel scale on every screen, authored 1:1 at 640×360 `[ASSUMPTION]` (D16) | Scale characters up per screen for legibility, as the mocks did |