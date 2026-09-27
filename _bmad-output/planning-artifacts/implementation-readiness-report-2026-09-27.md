---
stepsCompleted:
  - step-01-document-discovery
  - step-02-gdd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
documentsIncluded:
  gdd: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md
  gddSupporting:
    - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/decision-log.md
    - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md
  architecture: _bmad-output/game-architecture.md
  epics: _bmad-output/planning-artifacts/epics.md
  ux: null
  context:
    - _bmad-output/planning-artifacts/briefs/brief-zombies-teach-typing-2026-09-27/brief.md
    - _bmad-output/brainstorming-session-2026-09-27.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-09-27
**Project:** zombies-teach-typing

## Document Inventory

| Type | File | Format | Notes |
|---|---|---|---|
| GDD | `planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md` | Whole | Includes `decision-log.md` |
| GDD epic overview | `planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md` | Whole | Renamed from `epics.md` to avoid a duplicate name; references updated |
| Architecture | `_bmad-output/game-architecture.md` | Whole | Outside `planning-artifacts/` |
| Epics & Stories | `planning-artifacts/epics.md` | Whole | Source of truth for stories |
| UX Design | — | — | **Not found** |
| Context | brief.md, brainstorming-session-2026-09-27.md | Whole | Background only |

**Issues:**
- Resolved: duplicate `epics.md` name (GDD sketch renamed to `gdd-epics-overview.md`).
- Warning: no UX/HUD design document. UX alignment will be checked against the GDD and architecture only.
- Note: the architecture document is outside `planning-artifacts/`.

## GDD Analysis

The GDD has no numbered requirements, so the IDs below were extracted by this assessment in GDD section order. Tags: **[MVP]** = required for the Epic 1–5 MVP link; **[Post]** = post-MVP.

### Functional Requirements

**Typing core (M1–M3)**
- FR1 [MVP]: Exactly one active target character exists at a time. A correct key is accepted with zero delay and the next target becomes active in the same frame. Feedback plays at the same time, and animation length never limits typing speed (animations may overlap or be skipped at 60+ WPM, ≈5 keys/s).
- FR2 [MVP]: A wrong printable key makes no progress and changes nothing in the world. It adds 1 to the error count, plays a soft "bonk" tick (at most 1 per 150 ms) and shakes the target for 0.2 s. There is no other penalty.
- FR3 [MVP]: These keys are ignored and never count as errors: Shift (except as part of a capital), Ctrl, Alt, Meta, arrows, F-keys, Tab, Backspace, Enter and Caps Lock. Space is also ignored in Zombie Run and Horde Rush.
- FR4 [MVP]: Zombie Run and Horde Rush are lowercase-only and accept a letter regardless of Caps Lock or Shift. A "Caps Lock is on" hint appears after 3 consecutive capitals. Pitchfork Panic is case-sensitive.
- FR5 [MVP]: The run timer starts on the first correct keystroke. Before that, the HUD shows the first target and "Type the letter to start!" (or "word" / "text").
- FR6 [MVP]: Stats are Keys Typed (correct keystrokes; a capital counts as 1), Errors (wrong printable keys), Accuracy (Keys ÷ (Keys + Errors), whole %), WPM ((Keys ÷ 5) ÷ run minutes, whole number, with +1 per completed word in Horde Rush for the implied space), Lesson Time (from first correct key to end, m:ss) and Brains (bonuses shown as a separate "+N bonus" line).
- FR7 [MVP]: Live HUD WPM updates once per second and appears only after 5 s of run time.
- FR8 [MVP]: Esc or the pause button pauses the game: the timer stops and the world freezes. The options are Resume and Quit to Menu.
- FR9 [MVP]: The game auto-pauses when the browser tab or window loses focus.
- FR10 [MVP]: Resuming shows a 3-2-1 count (0.5 s per number) before input is accepted.
- FR11 [MVP]: Quitting mid-run keeps the brains collected, awards no completion bonus and does not record the run in stats history.

**Shared HUD and finger guide (M2b, Finger Guide)**
- FR12 [MVP]: The bottom HUD band (104 px of 360) holds, left to right: the pet slot, the target area (letter, word or 2-line text, always in the same spot) with the zombie hands below it, and a stats column (Timer, Keys Typed, WPM, Errors). A pause button sits top-right on the playfield. Zombie Run adds a brain counter.
- FR13 [MVP]: Two green zombie hands appear in every level. The finger for the next character glows (brighter green plus a pulsing outline) and follows along through words and paragraphs.
- FR14 [MVP]: The finger map follows the GDD table (standard touch typing, including punctuation, numbers, Shift, Enter and Space).
- FR15 [Post]: For capitals and shifted symbols, both the character's finger and the opposite hand's pinky on Shift light up.
- FR16 [MVP]: The `f` and `j` fingertips always show a home-row bump mark.

**Curriculum and judgment**
- FR17 [MVP]: Every expected character records attempts and errors, including which wrong characters were typed. This is saved and never shown to the kid in the MVP.
- FR18 [MVP]: Zombie Run letters come from a shuffled bag. Every letter appears once before any repeats, and the same letter never appears twice in a row, even across bag boundaries. The MVP pool is all 26 letters on every run.

**Brains, Closet and onboarding (M4, M5)**
- FR19 [MVP]: Brains are the single currency. They buy cosmetics only, persist in the save and are never lost. No learning content is gated.
- FR20 [MVP]: There is 1 hat slot and 1 pet slot, and either can be empty. The hat is drawn on the zombie in every level, on all Horde Rush copies and on Professor Zombie. The pet sits in the HUD pet slot with an idle animation and also appears on the report card and main menu.
- FR21 [MVP]: After the first completed run ever, a "Welcome gift!" card follows the report card. It awards +100 brains and has one button, "Open the Crypt Closet". This happens once per save.
- FR22 [MVP]: The Closet tutorial shows an arrow pointing at the first affordable item, then walks through Buy → confirm → Wear. It ends when the first item is worn or the kid leaves the Closet, and is shown once per save.
- FR23 [MVP]: The Crypt Closet has 3×3 hat and pet grids priced by row (100/200/300), a brain counter and a preview of the zombie wearing the selected item. Item states are Locked-coming-soon, Can't afford ("Need N more"), Buy (with confirm), Wear, and Wearing (click to take off).
- FR24 [MVP]: In the MVP catalogue, Pumpkin hat and Cute ghost are live. The other 16 slots show a locked "?" silhouette labeled "Coming soon".
- FR25 [Post]: The full catalogue has 18 named items (see the GDD table), all purchasable.

**Controls and input**
- FR26 [MVP]: On the report card, Enter = Play Again and Esc = Menu, both ignored for the first 1.0 s. Buttons are also clickable.
- FR27 [MVP]: In menus and the Closet, arrow keys move focus, Enter selects and Esc goes back. Mouse clicks also work.
- FR28 [MVP]: On the title screen, any key or click starts the game and unlocks browser audio.
- FR29 [MVP]: During gameplay, keys that trigger browser actions are swallowed: Space, `'`, `/`, Backspace and Tab.
- FR30 [MVP]: Matching uses the typed character, so non-US layouts can still play. The finger guide assumes US QWERTY.

**Screens and flow**
- FR31 [MVP]: The screen flow is Title → Main Menu → [Level → Report Card → (Welcome Gift → Crypt Closet, first time only) → Play Again | Menu] | Crypt Closet.
- FR32 [MVP]: The main menu shows the logo, the player's zombie wearing its hat with the pet beside it, the brain counter, 3 level cards (Horde Rush and Pitchfork Panic show a "Coming soon" sign and can't be selected in the MVP), a Crypt Closet button, and Music/Sound toggles.
- FR33 [MVP]: The report card is a chalkboard with Keys Typed, Errors, WPM, Accuracy, Lesson Time and Brains Collected (+ bonus line). A "New best!" stamp appears when the run beats that level's best WPM (after the first run). Professor Zombie (graduation cap and gown, plus hat and pet) points at the board. Buttons are Play Again and Menu.
- FR34 [MVP]: Best WPM is tracked per level.

**Zombie Run [MVP]**
- FR35: The run lasts 2:00 with a calm mood on the Sunny Village Green backdrop.
- FR36: Targets are 48 px apart and the next 3 are visible with their letters. The active target bobs, has a down-arrow, and its letter matches the HUD target.
- FR37: While waiting, the zombie ambles at 24 px/s and stops 24 px before the active target to idle. A correct key resolves the target instantly and the zombie scoots to the next approach point in 0.15 s. Scoots chain, and targets never scroll away.
- FR38: Each group of 4 targets has 1 brain block and 3 villagers, shuffled per group.
- FR39: A brain block floats 48 px above the ground. A correct key triggers a hop (0.35 s) and bonk, and a brain pops out (+1), with a 20% chance of a "Brainsss…" line.
- FR40: A villager gets a hug (0.4 s), then poofs into a party-hat zombie that joins the conga line.
- FR41: The conga line bobs behind the zombie. At most 12 followers are drawn, with a "×N" badge beyond that. The line never shrinks during a run.
- FR42: At 0:00, input stops, the zombie and conga line dance for 2.0 s, then the report card appears. A completed run earns +10 brains.
- FR43: Zombie Run pacing never scales.

**Horde Rush [Post]**
- FR44: Content is lowercase words (a fixed 3–5 letter band before adaptive difficulty). A run lasts 5:00.
- FR45: The field has 5 lanes. Zombies enter at the left, the house fills the right edge, and the defender paces in front of it.
- FR46: Typed letters turn green and the next letter is underlined. A word completes on its last letter (no Space). A zombie copy wearing the player's hat spawns in a random lane, and the next word appears instantly.
- FR47: Size classes are: ≤3 letters = small (8 s crossing, 1 hit, 1 brain); 4–5 = medium (10 s, 2, 2); ≥6 = big brute (13 s, 3, 3).
- FR48: The defender moves 1 lane per 0.6 s, reversing at the edges, and throws at the front-most zombie in its lane (0.8 s cooldown, 1.0 s projectile). A hit flashes the zombie red for 0.15 s. The final hit makes it fall and melt over 0.6 s.
- FR49: An arriving zombie shuffles into the door with a throttled "Brainsss" and a brains pop. A completed run earns +25 brains.
- FR50: Each run picks a random house and defender pair: Farmhouse/Farmer/tomatoes, Castle/Knight/suction darts or Beach Hut/Lifeguard/water balloons. There are no guns.
- FR51: The defender is tuned so that about 40% of zombies arrive at 10 WPM and about 70% at 30 WPM.

**Pitchfork Panic [Post]**
- FR52: Content is tier-based paragraphs. A run lasts until the zombie is caught, up to 5:00, and is case-sensitive.
- FR53: The 2-line text window shows typed characters in green, underlines the next character and dims the next line. Passages flow continuously.
- FR54: Each correct character is 1 step forward. The start gap is 15 steps. The mob starts at 4 WPM-eq (1 WPM-eq = 5 steps/min) and gains +1 WPM-eq every 10 s.
- FR55: The camera holds the zombie at 60% of screen width. The mob's distance is always readable, and the mob appears on screen when the gap is under 20 steps.
- FR56: A brain pickup appears every 10–30 steps (uniform random) and is worth 5 brains.
- FR57: Every finished run earns +10 brains, and Escaped! earns +25.
- FR58: When caught: dust cloud (1.5 s) → dazed zombie with stars and "Got you!" (1.0 s) → fade (0.5 s) → report card. All brains are kept.
- FR59: At 5:00, the zombie dives through a hedge (1.5 s) → "Escaped!" → report card.
- FR60: Each run picks a random chase setting (Moonlit Village, Cornfield Path or Spooky Forest Bridge). The mob sprites are reused.

**Adaptive curriculum [Post]**
- FR61: The difficulty signal is the rolling average WPM of the last 1–5 completed runs across all levels. Quit runs are excluded, and the value is never shown.
- FR62: Placement uses the save's first Zombie Run (26 letters). Its WPM sets the starting tier.
- FR63: Five tiers (<8 / 8–14 / 15–21 / 22–29 / 30+) set the keys in play, the Horde Rush word length and the Pitchfork Panic text rules, as in the GDD table.
- FR64: A tier goes up immediately and down only at 2 WPM below the current floor. Comparisons use the unrounded average, and a drop can skip tiers.
- FR65: The Zombie Run letter pool follows the tier's rows.
- FR66: Zombie Run pacing, the defender and the mob never scale.

**Content pipeline**
- FR67 [Post]: A master list of about 1,500 kid-safe lowercase words, cross-checked against Dolch, with exclusions, reviewed by hand once.
- FR68 [Post]: Build-time tagging records each word's rows and length. Tier pools are filtered by rows and length band, and tier 1 must have at least 40 home-row words of 2–3 letters.
- FR69 [Post]: About 40 original paragraphs (2–4 sentences, 150–400 characters, about 13 each for tiers 3–5). Tiers 1–2 generate sentences at runtime: 4–7 words, a capital first letter, end punctuation.
- FR70 [Post]: No passage repeats until every passage in its tier has been used (per save).

**Variety, trends, profiles [Post]**
- FR71: Each level has 3 art themes, picked at random per run without repeating the previous theme. Rules stay the same across themes.
- FR72: A trends and lifetime-stats screen.
- FR73: Profiles: a "Who's playing?" picker, per-zombie saves, and zombie names on the report card.

**Save**
- FR74 [MVP]: The save holds brains, owned items, equipped hat and pet, the welcome-bonus flag, the tutorial-seen flag, the placement-done flag, the current tier (post-MVP), settings (music, sound), best WPM per level, and run history. Run history keeps the last 500 runs with date/time, level, duration, keys, errors, WPM, accuracy, brains, letter pool or tier, per-key attempts and errors, and end reason.
- FR75 [MVP]: The save is written at run end, on quitting a run (brains only), after each purchase or equip, and on settings changes.

**Audio**
- FR76 [MVP]: Separate Music and Sound toggles are saved, and the game is fully playable muted.
- FR77 [MVP]: Zombie groans play at random every 3–8 s and are muted within 2 s of a voice line. "Brainsss" has a 20% chance on a brain collect, with at least 8 s between lines.
- FR78 [MVP]: Audio starts only after the first click or key on the title screen.
- FR79 [MVP]: Music is a menu loop plus one loop per level (60–120 s each), mixed below SFX. The SFX set is as listed in the GDD.

**Total FRs: 79**

### Non-Functional Requirements

- NFR1 (Performance): A steady 60 FPS in desktop Chrome, Edge and Firefox on a 2018-era integrated-graphics laptop. The MVP test is a full 2:00 Zombie Run with 12 conga followers and no frame over 33 ms. Post-MVP adds a full Horde Rush run and a 30-zombie stress scene.
- NFR2 (Performance): A correct keystroke shows visible feedback on the next rendered frame (≤17 ms).
- NFR3 (Performance): First load to the title in ≤10 s at 25 Mbit/s, cached load in ≤3 s, total download ≤40 MB.
- NFR4 (Reliability): No save loss across 10 consecutive reloads and 10 mid-menu tab closes, on both Chrome and Firefox.
- NFR5 (Platform): Godot 4.7 with the Compatibility renderer, GDScript only.
- NFR6 (Platform): The HTML5 export runs on plain static hosting with no special headers (single-threaded). Desktop Chrome, Edge and Firefox are supported, Safari is best-effort, and mobile and touch are unsupported.
- NFR7 (Privacy/Platform): Saves are kept in browser storage per browser and device. No accounts, network or analytics.
- NFR8 (Platform): A Windows desktop fallback export uses the same save contents.
- NFR9 (Usability): The target character or word is at least 32 px tall at 640×360, and UI text is at least 16 px.
- NFR10 (Accessibility): Finger and typed-text states use brightness plus shape or underline, never color alone.
- NFR11 (Usability): All UI text is readable by a 6-year-old. Zombie slang appears only in voice and flavor, never in menu labels.
- NFR12 (Usability): Menus, the report card and the Closet have no timers.
- NFR13 (Content/Tone): Kid-safe throughout: no gore, blood or guns, defeat is shown as melting, dust or stars, and the tone is never babyish.
- NFR14 (Design constraint, Pillar 3): No difficulty labels, ranks or easy mode anywhere in the UI.
- NFR15 (Design constraint, Pillar 2): Runs contain no non-typing decisions, and failure costs time, never items or brains.
- NFR16 (Art standard): 640×360 logical resolution with integer scaling where possible, a palette of ≤32 colors, 32×32 characters (48×48 brutes), 16×16 tiles, a 1 px outline, animations of 2–6 frames at 8–12 fps, and cosmetics as overlays anchored to a head point or pet slot.
- NFR17 (Process gate): The palette, zombie and one villager must be approved before any other art is made.
- NFR18 (Asset): One pixel font under the OFL with clearly distinct `l`/`I`/`1` and `O`/`0`.
- NFR19 (Licensing): Audio is CC0 or similar free material, or self-generated or self-recorded.
- NFR20 (Hardware): A physical keyboard is required.
- NFR21 (Balance): Each level earns brains per minute within ±20% of Zombie Run at the same WPM.
- NFR22 (Deployability): The MVP link loads and plays on at least 3 family computers without help.

**Total NFRs: 22**

### Additional Requirements

- **MVP scope boundary:** main menu, Zombie Run, report card, a Closet with 1 hat and 1 pet, the welcome bonus, and a single local save. Horde Rush and Pitchfork Panic appear as "Coming soon" cards.
- **MVP asset list** (GDD Asset Requirements table): characters, props, cosmetics, 1 backdrop, UI set, font, and 4 groans, 2 voice lines, 5 SFX and 2 music loops.
- **Playtest gate:** at least 1 kid playtest before publishing the link (Epic 5), and 3 kids for the success metric.
- **Epic sequence:** 1→2→3→4→5 (MVP) → 6→7→8→9→10. Epic 11 can be slotted in any time after 5. Epic 9 depends on Epic 6.
- **Assumptions A1–A5:** US QWERTY, static hosting (itch.io or GitHub Pages), 2018 laptop, kid playtesters, free audio.
- **Designer notes (tuning, non-blocking):** Horde Rush defender and low-WPM parity (Epic 6), Pitchfork Panic gap and acceleration (Epic 8), cross-level WPM comparability (Epic 7), and 6-year-olds on the full keyboard (Epic 5).
- **Out of Scope:** a firm list, including touch, gamepad, non-US finger maps, leaderboards, real money and a parent dashboard.
- **Success metrics:** the core hypothesis (≥2 of 3 kids play a second run and buy an item), return within a week, median accuracy ≥85%, learning trend and tone checks. These need run history to be readable (for example an export or debug view).

### GDD Completeness Assessment

**Overall: strong.** The GDD is final (v1.0), numeric and unusually specific for its scope. Timings, sizes, economy math and state tables are all defined, and the decision log shows a validation pass with 0 phase blockers.

**Ambiguities to carry into coverage checks:**
1. **The Welcome Gift → Closet exit path is undefined.** After the first-time Closet visit, does the kid return to the Main Menu or to the report card? The Welcome card has only one button, so "Play Again" can't be reached on that path.
2. **The "New best!" first-run rule** is "after the first run", but it's unclear whether that means per level or per save. Per level is implied.
3. **Pitchfork Panic Space and Enter handling:** Space must count as a typed character there, but it's not stated whether passages are joined by a space or need Enter.
4. **Where settings live:** Music and Sound toggles are specified only on the main menu, and the pause panel is not mentioned.
5. **The brain counter** is only specified for the Zombie Run HUD. Horde Rush and Pitchfork Panic have no live brain display.
6. **Reading success metrics:** the metrics depend on saved run history, but there is no requirement for how the author reads it (export, debug screen or console dump).
7. **Window scaling:** "whole numbers where possible" doesn't say what happens with non-integer browser window sizes (letterbox or stretch).
8. **Section order:** M2b sits after M3, which is cosmetic only.

## Epic Coverage Validation

The epics document has its own inventory of 78 FRs and 17 NFRs, plus an FR Coverage Map. Every one of its 78 FRs is mapped to an epic, and every epic lists the FRs it covers. The matrix below traces **this assessment's GDD FR IDs** (step 2) to the epics document's FR IDs (E-FR) and the stories that implement them.

### Coverage Matrix

| GDD FR | Requirement (short) | E-FR | Stories | Status |
|---|---|---|---|---|
| FR1 | One target, instant accept, non-blocking feedback | E-FR1 | 2.2, 2.4, 3.1 | ✓ |
| FR2 | Wrong key: no progress, +1 error, tick, shake | E-FR2 | 2.2, 2.5 | ✓ |
| FR3 | Ignored keys; Space ignored in ZR/HR | E-FR3 | 2.1, 6.2 | ✓ |
| FR4 | Case rules + Caps Lock hint | E-FR4, E-FR5 | 2.1, 2.5, 8.2 | ✓ |
| FR5 | Timer on first correct key; start prompt | E-FR6 | 2.2, 2.4, 2.5 | ✓ |
| FR6 | Stats definitions | E-FR7 | 2.3, 6.2 | ✓ |
| FR7 | Live WPM after 5 s at 1 Hz | E-FR8 | 2.5 | ✓ |
| FR8 | Esc or pause-button pause, Resume/Quit | E-FR10 | 2.7 | ✓ |
| FR9 | Auto-pause on focus loss | E-FR11 | 1.5, 2.7 | ⚠ Partial: web only (see G5) |
| FR10 | 3-2-1 resume countdown | E-FR12 | 2.7 | ✓ |
| FR11 | Quit keeps brains, no bonus, no record | E-FR13 | 2.7, 2.8, 3.5, 6.5, 8.5 | ✓ |
| FR12 | Shared bottom HUD layout | E-FR14 | 2.5, 3.2 | ✓ |
| FR13 | Zombie-hand next-finger glow | E-FR15 | 2.6, 6.2 | ✓ |
| FR14 | Finger map table | E-FR16 | 2.6 | ✓ |
| FR15 | Shift pairing for capitals | E-FR17 | 2.6, 8.2 | ✓ (pulled into MVP) |
| FR16 | f/j bumps | E-FR18 | 2.6 | ✓ |
| FR17 | Per-key attempts, errors, mistypes | E-FR9 | 2.2, 2.3, 2.8 | ✓ |
| FR18 | Shuffled letter bag, no repeats | E-FR29 | 2.2 | ✓ |
| FR19 | Brains as currency, cosmetics only, never lost | E-FR38 | 4.1 | ✓ |
| FR20 | Hat and pet slots shown everywhere | E-FR43 | 4.3, 6.3, 6.6, 9.1 | ✓ |
| FR21 | Welcome gift +100 once | E-FR44 | 4.5 | ✓ |
| FR22 | Guided first purchase once | E-FR45 | 4.5 | ✓ |
| FR23 | Closet grids, prices, preview, item states | E-FR39–41 | 4.1, 4.4 | ✓ |
| FR24 | MVP: 2 live items + 16 "Coming soon" | E-FR42 | 4.1, 4.4 | ✓ |
| FR25 | Full 18-item catalogue | E-FR75 | 9.1–9.3 | ✓ |
| FR26 | Report card keys with 1.0 s guard | E-FR21 | 2.9 | ✓ |
| FR27 | Menu and Closet keyboard/mouse navigation | E-FR25 | 4.2, 4.4 | ✓ |
| FR28 | Title: any key or click, audio unlock | E-FR23 | 1.3, 1.4 | ✓ |
| FR29 | Swallow Space, `'`, `/`, Backspace, Tab during gameplay | *(Additional Req only)* | 1.5 | ⚠ Partial: proven on a test screen only (see G1) |
| FR30 | Match by character | E-FR4, NFR6 | 2.1 | ✓ |
| FR31 | Screen flow | E-FR24 | 1.3, 4.5 | ✓ |
| FR32 | Main menu contents | E-FR26 | 4.2, 4.3 | ✓ |
| FR33 | Chalkboard report card, New best!, Professor Zombie | E-FR19, E-FR20 | 2.9, 4.3 | ✓ |
| FR34 | Per-level best WPM | E-FR22 | 2.8 | ✓ |
| FR35 | ZR 2:00, Sunny Village Green | E-FR28, E-FR37 | 3.1, 3.6 | ✓ |
| FR36 | ZR target spacing, 3 visible, marker | E-FR30 | 3.1 | ✓ |
| FR37 | ZR amble, idle, chained scoot | E-FR31 | 3.1 | ✓ |
| FR38 | 1 brain block in every 4 targets | E-FR32 | 3.2 | ✓ |
| FR39 | Brain block hop, bonk, +1, voice chance | E-FR33 | 3.2 | ✓ |
| FR40 | Villager hug to party-hat zombie | E-FR34 | 3.3 | ✓ |
| FR41 | Conga line, 12 cap, ×N badge | E-FR35 | 3.4 | ✓ |
| FR42 | End dance, +10 bonus | E-FR36 | 3.5 | ✓ |
| FR43 | ZR pacing never scales | E-FR64 | 3.1 (config), 7.5 | ✓ |
| FR44 | HR 5:00, fixed 3–5 band | E-FR53, E-FR59 | 6.1, 6.3 | ✓ |
| FR45 | HR 5-lane field | E-FR53 | 6.3 | ✓ |
| FR46 | HR word loop and spawn | E-FR54 | 6.2, 6.3 | ✓ |
| FR47 | HR size classes | E-FR55 | 6.3 | ✓ |
| FR48 | HR defender behavior | E-FR56 | 6.4 | ✓ |
| FR49 | HR arrival brains, +25 bonus | E-FR57 | 6.5 | ✓ |
| FR50 | HR 3 house/defender pairs, no guns | E-FR58 | 6.6, 10.3 | ✓ |
| FR51 | HR arrival-rate tuning targets | *(story only)* | 6.7 | ✓ |
| FR52 | PP until caught, max 5:00, case-sensitive | E-FR4, E-FR73 | 8.2, 8.5 | ✓ |
| FR53 | PP 2-line text window | E-FR69 | 8.2 | ✓ |
| FR54 | PP step and mob model | E-FR70 | 8.3 | ✓ |
| FR55 | PP camera and mob visibility | E-FR71 | 8.3 | ✓ |
| FR56 | PP brain pickups by distance | E-FR72 | 8.4 | ✓ |
| FR57 | PP +10 finished, +25 escaped | E-FR73 | 8.5 | ✓ |
| FR58 | PP caught sequence | E-FR73 | 8.5 | ✓ |
| FR59 | PP escaped sequence | E-FR73 | 8.5 | ✓ |
| FR60 | PP 3 chase settings | E-FR74 | 8.6, 10.4 | ✓ |
| FR61 | Rolling average WPM signal | E-FR60 | 7.1 | ✓ |
| FR62 | Placement run | E-FR61 | 7.2 | ✓ |
| FR63 | 5-tier table | E-FR62 | 7.4, 7.5, 8.1 | ✓ |
| FR64 | Hysteresis and multi-tier drops | E-FR63 | 7.1 | ✓ |
| FR65 | ZR pool follows tier | E-FR64 | 7.5 | ✓ |
| FR66 | Pacing, defender and mob never scale | E-FR64 | 7.5, 8.3 | ✓ |
| FR67 | 1,500-word master list | E-FR65 | 7.3 | ✓ |
| FR68 | Build-time tagging and tier pools | E-FR66 | 6.1, 7.4 | ✓ |
| FR69 | Paragraphs and sentence generator | E-FR67 | 8.1 | ✓ |
| FR70 | No passage repeats per tier | E-FR68 | 8.2 | ✓ |
| FR71 | Art theme rotation | E-FR76 | 10.1–10.4 | ✓ |
| FR72 | Trends and lifetime stats screen | E-FR77 | 10.5 | ✓ |
| FR73 | Profiles and naming | E-FR78 | 11.1–11.4 | ✓ |
| FR74 | Save contents and run history | E-FR51 | 1.6, 2.3, 2.8 | ✓ |
| FR75 | Save write triggers | E-FR52 | 1.6, 1.7, 2.7, 2.8, 4.1, 4.2 | ✓ |
| FR76 | Music/Sound toggles, playable muted | E-FR46 | 4.2, 5.1 | ✓ |
| FR77 | Groan and voice-line spacing | E-FR48 | 3.2, 3.7 | ✓ |
| FR78 | No audio before first input | E-FR47 | 1.4 | ✓ |
| FR79 | Music loops and SFX set | E-FR49, E-FR50 | 5.1, 6.6, 8.6 | ✓ |

**FRs in the epics document that are not in the GDD** (derived from the architecture, and acceptable):
- E-FR27: "Progress may not be saved in this browser mode" notice (Stories 1.7, 4.2).
- E-FR52 extension: an immediate save on tab hidden or window close (Story 1.6).
- NFR16 (Robustness): errors never stop a run, and a failed screen load returns to the menu.
- The Caps Lock hint hides on the next lowercase letter (E-FR5), a small clarification of the GDD.

### Missing Requirements

No GDD FR is completely missing. The gaps are partial coverage and GDD requirements that no story owns:

#### High priority (MVP)

- **G1: Key swallowing is never wired into gameplay (FR29).** Story 1.5 proves swallowing works on a keyboard *test screen* with `WebPlatform.capture_keys = true`. Neither `RunFrame` (Story 2.4) nor any later story turns `capture_keys` on when a run starts, or off in menus.
  - *Impact:* in a real Zombie Run, Space could scroll the page and `'` or `/` could open Firefox quick-find. The GDD calls this out as required.
  - *Recommendation:* add an AC to Story 2.4: "RunFrame sets `WebPlatform.capture_keys = true` on entering the run and false on leaving." Also re-test Space, `'` and `/` in Story 5.3.
- **G2: No story produces the MVP UI art.** The GDD's MVP asset list includes the title logo, 3 level cards (2 with a "Coming soon" sign), the HUD bar, zombie hands art (2 hands, 10 finger-glow states, f/j bumps), the chalkboard, Closet grids and the "?" silhouette, buttons, the brain icon, the "New best!" stamp, the Welcome Gift card and the pause panel. Story 1.3 only makes a *placeholder* logo. Stories 2.5, 2.6, 2.9, 4.2 and 4.4 describe function but never "final art per the style sheet". Only the Zombie Run sprites (3.6), the Pumpkin hat and Cute ghost (4.3) and Professor Zombie (2.9) are covered.
  - *Impact:* the MVP link could ship with programmer-art UI. Story 1.9's gate ("no other art until approval") leaves a hole for everything that isn't a character sprite.
  - *Recommendation:* add a story to Epic 5, or split it across 2.5, 2.6, 2.9, 4.2 and 4.4 as explicit ACs: "UI art for X is final, uses the palette and passes the style sheet."
- **G3: Saved run history can't be read, but the success metrics depend on it.** Story 5.4 says "notes record accuracy from saved run history", and the Epic 7 designer note needs a per-level WPM review. On the web, `user://save.json` lives in the browser's IndexedDB, and the debug overlay is stripped from the release build (Story 5.5). No story adds a way to view or export run history.
  - *Impact:* the core-hypothesis and accuracy metrics can't be measured on the published link.
  - *Recommendation:* add an AC to Story 1.8 or 5.4 for a hidden or debug "export save / copy run history" action (for example a key chord on the menu that downloads `save.json` through `JavaScriptBridge`), or a documented dev-tools recipe.

#### Medium / low priority

- **G4: Menu and level music switching has no owner.** Story 5.1 checks the audio list and mix but has no AC saying the menu loop plays on the title and menu, the Zombie Run loop plays in the run, and music crossfades or stops at transitions.
  - *Recommendation:* add one AC to Story 5.1.
- **G5: No auto-pause on focus loss in the Windows fallback (FR9).** `WebPlatform` is a no-op on desktop, so `focus_lost` never fires in the Windows build.
  - *Recommendation:* have `WebPlatform` (or `RunFrame`) also handle `NOTIFICATION_APPLICATION_FOCUS_OUT` on desktop. This is low priority because Windows is a fallback.
- **G6: The Windows fallback build is never verified (NFR8).** Story 1.2 creates the preset, but no story checks that the build runs and uses the same save.
  - *Recommendation:* add a smoke check to Story 5.3, or state explicitly that it's deferred until needed.
- **G7: GDD ambiguities carried forward (step 2 #3, #4, #7) are not resolved in the stories:**
  - How Pitchfork Panic passages are joined (space or Enter) is unspecified (Story 8.2).
  - Whether Music/Sound toggles also appear on the pause panel is unspecified.
  - Non-integer window scaling: the architecture sets `scale mode integer`, so the GDD's "where possible" wording is resolved in practice. ✓
- **G8: The PlayerData flag API is implicit.** Story 4.5 sets `welcome_bonus_claimed` and `tutorial_seen`, but Stories 1.7 and 4.1 define no `PlayerData` method for flags. The single-writer rule (only `PlayerData` mutates the profile) means one is needed.
  - *Recommendation:* add `set_flag()` or equivalent methods to the Story 4.1 or 4.5 ACs.

### Coverage Statistics

- Total GDD FRs (this assessment): 79
- Fully covered: 77
- Partially covered: 2 (FR9, FR29)
- Missing entirely: 0
- **Coverage: 97.5% full, 100% at least partial**
- GDD requirements with no owning story (asset or metric level): G2 (MVP UI art) and G3 (reading run history)

## UX Alignment Assessment

### UX Document Status

**Not found.** No `*ux*.md` file exists in `planning-artifacts/`.

**UI is heavily implied.** The game is player-facing with 6 screens (Title, Main Menu, Run and HUD, Report Card, Welcome Gift, Crypt Closet), a pause panel, a countdown, a first-purchase tutorial overlay and a finger-guide widget. The target audience is 6–13-year-olds, with strict readability rules (NFR9–NFR11). The GDD specifies UI *content* in detail (M2b, Screens & Flow, Closet states) but not *layout*. The epics document says it captures UX from the GDD (FR14–FR27, FR39–FR45).

### Architecture Support for UI (what is covered)

- The screens map 1:1 to `Router.Screen` and `scenes/screens/*`, with fades and payloads. ✓
- HUD, `ZombieHands`, `PausePanel` and `Countdown` sit in `scenes/run/`, and the pause widgets use `PROCESS_MODE_WHEN_PAUSED`. ✓
- A shared `ui_theme.tres` with the pixel font, and reusable `pixel_button`, `brain_counter` and `closet_item_tile` widgets. ✓
- Menus use InputMap `ui_*` for arrow and Enter navigation, while typing uses raw characters, so the two are kept apart. ✓
- Cosmetic `HatSlot` and `PetSlot` update from `equipment_changed`, keeping the reward always visible. ✓
- The input-to-feedback latency path (≤17 ms) is designed in (D3, "logic leads, visuals chase"). ✓
- The asset folders already provide places for UI art (`assets/sprites/ui/hud|hands|menu|closet|report_card`), but no story fills them (see G2).

### Alignment Issues

- **U1: Integer scaling vs. the target laptop's browser viewport (High, MVP).** The architecture sets `stretch mode viewport, aspect keep, scale_mode integer` at 640×360. The GDD's target machine is a 2018-era family laptop, commonly 1366×768. Inside a browser, the usable canvas is about 1366×620–660 px, which is **below the 720 px needed for 2×**. The game would render at **1× (640×360)**, a small box in the middle of the screen, and the 16 px text minimum becomes 16 physical px on a 14″ screen. A 1920×1080 laptop with browser chrome also only reaches 2×.
  - *Recommendation:* make this an explicit check in Story 1.2 (open the hello-world build at 1366×768 in each browser) and decide there between (a) `scale_mode = fractional` with nearest filtering (accepting slight pixel unevenness), (b) a fullscreen button on the title or menu (the browser fullscreen API, owned by `WebPlatform`), or (c) both. The GDD's "whole numbers *where possible*" allows (a).
- **U2: The HUD band can't fit the Pitchfork Panic 2-line text at the 32 px readability minimum (Medium; affects the shared HUD built in Story 2.5).** The 104 px band must hold the target area *and* the zombie hands below it. For letters and words, 32 px of target plus about 60 px of hands fits. The Pitchfork Panic 2-line window at ≥32 px per line needs about 64–72 px before the hands. NFR9 ("the target character or word is at least 32 px") doesn't say whether it applies to paragraph text.
  - *Recommendation:* decide now (a GDD clarification) whether paragraph text may be smaller (for example 16–24 px), or whether the HUD band grows in Pitchfork Panic. Make Story 2.5's target area flexible by target mode, so Epic 8 doesn't need to rework the shared HUD.
- **U3: There is no layout spec for the densest screens (Medium, MVP).** At 640×360 with text of at least 16 px, the main menu has to hold the logo, the zombie with hat and pet, the brain counter, 3 level cards, the Closet button and 2 toggles. The Closet has to hold two 3×3 grids, prices, item states, a preview zombie, the brain counter and the tutorial arrow. Neither the GDD nor any story gives a wireframe. There's a risk that an AI dev agent improvises layouts that break the 16 px minimum or crowd the screen.
  - *Recommendation:* add lightweight ASCII or PNG wireframes for the Main Menu, HUD, Report Card and Closet, either through `gds-ux` in a slim mode or as an AC in Stories 2.5, 2.9, 4.2 and 4.4 ("layout sketch approved by Smuck before implementation").
- **U4: Where the settings toggles appear is inconsistent.** The GDD and Story 4.2 put the Music and Sound toggles only on the main menu. Kids often want to mute mid-run, but the pause panel only has Resume and Quit. This isn't a conflict, but it's an unmade decision.
  - *Recommendation:* either add the toggles to the pause panel (Story 2.7 or 4.2) or record that they're menu-only.
- **U5: The Welcome Gift → Closet exit is only partly specified.** Story 4.5 sends the kid to the Closet, and Story 4.4 says Esc returns to the menu. After the first purchase, the natural "play again with my new hat" path is Closet → Menu → level card, which is 2 steps. That's acceptable but should be deliberate.
  - *Recommendation:* confirm it. An optional "Play with it!" button after Wear is a possible later enhancement.

### Warnings

- ⚠ **There is no UX design document for a kids' game whose success depends on readability and flow.** The GDD and architecture cover the content and the component structure well, but layout, scaling (U1) and HUD space (U2) have not been validated on paper. None of this blocks Epic 1. U1 should be settled during Epic 1, and U2 and U3 before Stories 2.5, 2.9, 4.2 and 4.4 are developed.
- ⚠ **The Godot web boot screen** (the default splash and progress bar) is the first thing a kid sees, and no story customises it. This is low priority, but worth a one-line AC in Story 1.2 or 5.5 (a custom boot splash in the palette).

## Epic Quality Review

**Scope:** 11 epics and 54 stories (MVP: 35 stories across Epics 1–5). Every story was checked for player value, independence, forward dependencies, sizing, AC quality and traceability.

**Overall:** the quality is high. All 54 stories use Given/When/Then with concrete numbers, name their test files and cite FR/NFR IDs. Dependencies point backward almost everywhere. Save-schema changes are introduced when first needed, each with a migration and a fixture (8.2, 10.1, 10.5), which is exemplary. The findings below are the exceptions.

### Epic Structure

| Epic | Player value | Independent (uses only earlier epics) | Verdict |
|---|---|---|---|
| 1 Foundation & Web Pipeline | Borderline: a technical title, but the goal is phrased as a hosted link with title, sound, keys and a reload-proof counter | ✓ | 🟠 Accepted with note |
| 2 Typing Core & Shared Frame | ✓ A kid types letters and gets a report card (test level) | ✓ | ✓ |
| 3 Zombie Run | ✓ | ✓ | ✓ |
| 4 Meta: Menu, Brains & Closet | ✓ | ✓ | ✓ |
| 5 MVP Polish & First Link | ✓ The public link | ✓ | ✓ |
| 6 Horde Rush | ✓ | ✓ | ✓ |
| 7 Adaptive Curriculum | ✓ (invisible by design) | ✓ Needs 6 (word pools) | ✓ |
| 8 Pitchfork Panic | ✓ | ✓ Needs 7 (tiers, pools) | ✓ |
| 9 Full Crypt Closet | ✓ | ✓ Needs 6 (size classes) | ✓ |
| 10 Art Variety & Trends | ✓ | ✓ Needs 6 and 8 | ✓ |
| 11 Profiles & Naming | ✓ | ⚠ Claims "any time after Epic 5", but Story 11.3 assumes Epic 7/8 fields | 🟡 |

### 🔴 Critical Violations

None. There are no forward dependencies that break an epic, no purely technical epics without a deliverable, and no stories too big to finish.

### 🟠 Major Issues

- **Q1: CI deploys every push to `main` straight to the public link, and post-MVP epics enable their menu cards mid-epic.** ADR-4 and Story 1.2 deploy on every push. Story 6.3 sets `horde_rush.available = true` before the defender (6.4), arrivals (6.5) or art (6.6) exist. Story 8.3 does the same for Pitchfork Panic. After the MVP link is shared (5.5), kids would see half-built levels, and any mid-story commit to `main` goes live.
  - *Remediation:* (a) change the deploy trigger to tags or a `release` branch in Story 1.2 (Story 5.5 already tags the version), **and/or** (b) move "card enabled / `available = true`" to the *last* story of Epics 6 and 8 (6.7, 8.7).
- **Q2: Forward dependency, the pixel font (Story 1.3 needs 1.9).** Story 1.3's AC requires the title text "in a pixel font at 16 px or larger", but the SIL OFL pixel font and `ui_theme.tres` are only introduced in Story 1.9.
  - *Remediation:* move the font choice (NFR18) and `ui_theme.tres` into Story 1.1 or 1.3, or change the 1.3 AC to "a placeholder font; replaced in 1.9". Consider moving Story 1.9 (the art gate) earlier or running it in parallel, since the GDD calls it the first risk gate.
- **Q3: Success-metric data can't be retrieved (the G3 gap shows up as an AC defect).** Story 5.4 ("record accuracy from saved run history") and Story 7.1 ("per-level WPM reviewed from saved history") have ACs that can't be verified with any tool the plan builds. The release build has no debug overlay, and the web save sits in IndexedDB.
  - *Remediation:* add a run-history export or view AC, preferably to Story 1.8 (debug) plus a release-safe hidden export for playtests.
- **Q4: No story owns the MVP UI art (G2).** Stories 2.5, 2.6, 2.9, 4.2 and 4.4 have functional ACs but no "final art to the style sheet" AC. The zombie hands (10 glow states, f/j bumps), chalkboard, level cards, Closet tiles, buttons, stamp and Welcome card are unowned.
  - *Remediation:* add a "5.0 MVP UI Art Pass" story, or add art ACs to each screen story.
- **Q5: Story 2.4 is oversized.** It combines the `LevelBase` contract, the `RunFrame` state machine, `RunClock`, the level registry, RNG seeding, `TypingInput` configuration, run end and `RunResult` routing, a test level, 5 new debug-overlay fields plus F6/F7, and an integration test. It's the riskiest story in the MVP and should be split.
  - *Remediation:* split it into **2.4a** (`LevelBase`, level registry, `RunFrame` WAITING/RUNNING/ENDING, `RunClock`, test level, integration test) and **2.4b** (debug overlay run fields, F6/F7, `debug_seed` replay). Also add the missing `capture_keys` wiring (G1) to 2.4a.

### 🟡 Minor Concerns

- **Q6: Story 2.9 contains a planned forward reference.** "Placeholder nodes where the hat and pet will go; their behaviour is added in Story 4.3." This is acceptable staging, since 2.9 is complete without 4.3, but it's noted.
- **Q7: Throttle tests land two epics after the code.** Story 2.5 implements the 150 ms wrong-key throttle in `AudioManager`, but the unit test for it only arrives in Story 3.7. That goes against the architecture rule that every class has tests. Move the throttle test into Story 2.5, and the voice-spacing test into Story 3.2.
- **Q8: Ownership of `AudioManager.play_voice` is fuzzy.** Story 1.4 defines `play_sfx`. Story 3.2 *calls* `play_voice` and says "AudioManager enforces 8 s". Story 3.7 tests it. None says "implement `play_voice`, `start_ambience` and `stop_ambience`". Assign them to 3.2 and 3.7 explicitly.
- **Q9: Placeholder art is implicit before Story 3.6.** Stories 3.2 and 3.3 play hop, bonk, hug and poof animations whose final frames only arrive in 3.6. Add "placeholder sprites are acceptable" to 3.1–3.3 so a dev agent doesn't stall or produce final art early.
- **Q10: Epic 11 ordering claim.** Story 11.3 lists "tier and used passages" as per-profile. If Epic 11 lands right after Epic 5, those fields don't exist yet (used passages arrive with Epic 8). Reword it as "all profile fields that exist at the time" and add a note to Epics 7 and 8 to keep new fields profile-scoped.
- **Q11: No `PlayerData` API for flags (G8).** Story 4.5 sets `welcome_bonus_claimed` and `tutorial_seen`, but no story adds `set_flag()` or similar, and the single-writer rule forbids writing them directly. Add it to Story 4.1.
- **Q12: How to reach the test level is unclear.** Story 2.4 says the test level is "registered, not shown on the menu", but doesn't say how the developer launches it (placeholder menu button, debug key or `debug_level_id`). Add one line.
- **Q13: Subjective ACs.** Some ACs are feel checks with no pass bar: "readable against every part of the backdrop" (3.6), "look right on every pose" (4.3), "no sound stacks into noise" (5.1) and "defender feels goofy" (6.7). The architecture routes feel to manual checklists, so this is acceptable. Each should reference a named checklist in the story file.
- **Q14: Developer-persona stories.** Stories 1.1, 1.2, 1.6 (partly), 1.8 and 6.1 are "As the developer…". That's acceptable for a greenfield setup and tooling, but Epic 1's title could be player-framed (for example "A Shareable Link That Types, Sounds and Remembers").
- **Q15: MVP size vs. capacity.** The MVP is 35 stories for a solo developer on occasional weekend mornings. That's not a defect, but it's worth a sprint-planning check: consider whether Story 1.8 (debug overlay) or Story 5.2 could be trimmed if the timeline matters.

### Special Checks

- **Starter template:** the architecture specifies none; the existing Godot project is used. Story 1.1 correctly fixes `project.godot`, removes `[dotnet]` and sets strict typing. ✓
- **Greenfield setup:** project setup (1.1), CI and build pipeline early (1.2), test harness from day 1 (1.1). ✓
- **Data creation timing:** the save schema v1 deliberately includes post-MVP fields (`tier`, `placement_done`, `profiles`) up front. This is justified by ADR-2 to avoid migrations. Every other structure (`LevelConfig`, `Catalogue`, `EconomyConfig`, content JSON, v2+ fields) is created by the story that first needs it. ✓
- **Traceability:** every functional story cites FR or NFR IDs. Only the setup and tooling stories (1.1, 1.8) have none, which is appropriate.

### Best Practices Compliance

| Epic | Value | Independent | Sized | No fwd deps | Data timing | Clear ACs | Traceable |
|---|---|---|---|---|---|---|---|
| 1 | 🟠 | ✓ | ✓ | ❌ Q2 | ✓ | ✓ | ✓ |
| 2 | ✓ | ✓ | 🟠 Q5 | ✓ (Q6 staged) | ✓ | 🟡 Q7 | ✓ |
| 3 | ✓ | ✓ | ✓ | ✓ | ✓ | 🟡 Q8, Q9 | ✓ |
| 4 | ✓ | ✓ | ✓ | ✓ | 🟡 Q11 | ✓ | ✓ |
| 5 | ✓ | ✓ | ✓ | ✓ | ✓ | 🟠 Q3, Q4 | ✓ |
| 6 | ✓ | ✓ | ✓ | ✓ | ✓ | 🟠 Q1 | ✓ |
| 7 | ✓ | ✓ | ✓ | ✓ | ✓ | 🟠 Q3 | ✓ |
| 8 | ✓ | ✓ | ✓ | ✓ | ✓ | 🟠 Q1 | ✓ |
| 9 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 10 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 11 | ✓ | 🟡 Q10 | ✓ | ✓ | ✓ | ✓ | ✓ |

## Summary and Recommendations

### Overall Readiness Status

**NEEDS WORK (light), with Epic 1 cleared to start now.**

The planning set is strong. The GDD is final and numeric, the architecture is complete with 10 decisions and 5 ADRs, and the epics give 100% FR traceability with high-quality, testable ACs. There are no critical violations. The issues are a handful of **gaps where no story owns a GDD requirement**, **one real forward dependency**, **a deploy-strategy risk**, and **unvalidated screen layout and scaling**. All of them can be fixed by editing stories. None needs the GDD or architecture reworked.

### Critical Issues Requiring Immediate Action

Nothing is blocking. These are the highest-impact items, listed by the story they must be fixed before:

**Before or within Epic 1 (edit Stories 1.2, 1.3, 1.8, 1.9):**
1. **Q1: Deploy only on release.** Change Story 1.2 so GitHub Pages deploys from tags or a `release` branch, not every push to `main`. Otherwise half-built post-MVP levels go live to kids.
2. **Q2: Font forward dependency.** Story 1.3 needs the pixel font that only arrives in 1.9. Move the font and `ui_theme.tres` into 1.1 or 1.3, or allow a placeholder.
3. **U1: Integer scaling on 1366×768 laptops.** The game would render at 1× (640×360) in a browser window on the GDD's target hardware. Add a check to Story 1.2 and decide between fractional scaling and a fullscreen button.
4. **G3/Q3: Run-history export.** Add a way to read or export `save.json` from the web build (Story 1.8 plus a release-safe hidden export). Without it, the core-hypothesis metrics in Story 5.4 can't be measured.

**Before Epic 2 (edit Stories 2.4–2.7):**
5. **G1: Wire `capture_keys`** on and off in `RunFrame`. Right now key swallowing only works on the Story 1.5 test screen.
6. **Q5: Split Story 2.4** into the run lifecycle (2.4a) and the debug and replay extras (2.4b).
7. **U2: HUD space.** Decide the Pitchfork Panic text size and the HUD band rule now, so Story 2.5's shared HUD doesn't need reworking in Epic 8.

**Before Epics 4–5:**
8. **G2/Q4: Assign the MVP UI art.** Add an art-pass story or per-screen art ACs covering the hands, chalkboard, level cards, Closet tiles, buttons, stamp and Welcome card.
9. **U3: Wireframes.** Get quick layout sketches approved for the Main Menu, HUD, Report Card and Closet at 640×360 with 16 px text.

### Recommended Next Steps

1. **Patch `epics.md`** with the fixes above (G1, G2, G3, G8, Q1, Q2, Q5, Q7–Q12, U1–U4) through `gds-correct-course`, or by editing directly. About 15 small AC edits, 1 story split and 1 new story.
2. **Settle the 3 GDD clarifications** in a short GDD update:
   - How Pitchfork Panic passages are joined (Space or Enter).
   - Pitchfork Panic text size vs. the 32 px rule (U2).
   - Whether settings toggles appear on the pause panel (U4).
3. **Optional:** run `gds-ux` in a slim mode for wireframes of the 4 dense screens (U3), or add "layout sketch approved" ACs.
4. **Run `gds-sprint-planning`** to generate sprint status, then `gds-create-story` for Story 1.1. Epic 1 can begin in parallel with steps 1–3, as long as Stories 1.2, 1.3 and 1.8 get their edits before they're developed.

### Issue Tally

| Category | 🔴 Critical | 🟠 Major / High | 🟡 Minor / Medium-Low |
|---|---|---|---|
| FR coverage gaps (G1–G8) | 0 | 3 (G1, G2, G3) | 5 (G4–G8) |
| UX alignment (U1–U5 + 2 warnings) | 0 | 1 (U1) | 4 + 2 warnings |
| Epic quality (Q1–Q15, excluding the 3 that duplicate G items) | 0 | 3 (Q1, Q2, Q5) | 9 |
| **Total (deduplicated)** | **0** | **7** | **18 + 2 warnings** |

### Final Note

This assessment found **25 issues across 3 categories (plus 2 warnings)**: 0 critical, 7 major and 18 minor. FR coverage is 97.5% full and 100% at least partial. The major items are all story-level edits. Address them before the story each one affects is developed, rather than before implementation as a whole. You can also proceed as-is and absorb them through `gds-correct-course` as they come up.

**Assessed by:** Game Producer / Scrum Master (gds-check-implementation-readiness) for Smuck, 2026-09-27
