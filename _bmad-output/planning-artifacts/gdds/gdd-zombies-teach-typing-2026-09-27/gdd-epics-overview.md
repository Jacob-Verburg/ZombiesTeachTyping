---
title: 'Development Epics: Zombies Teach Typing'
gdd: gdd.md
created: '2026-09-27'
updated: '2026-09-27'
---

# Development Epics: Zombies Teach Typing

Each epic ends in something playable. The stories listed are high-level; `gds-create-epics-and-stories` refines them. MVP = Epics 1–5.

---

## Epic 1: Foundation & Web Pipeline (MVP)

**Goal:** remove the web-export risks and fix the art standard before any gameplay is built.
**Delivers mechanics:** the platform base for M1–M5; save contents; the art-style standard.
**Dependencies:** none.

**In scope:**
- A hello-world web build deployed to the chosen static host [A2]
- Swallowing browser-shortcut keys (Space, `'`, `/`, Backspace, Tab) during gameplay
- Audio unlock on the title screen
- A save/load round trip that survives reloads and tab closes
- A screen-flow skeleton (Title → Menu → Level → Report Card → Menu)
- An art-style sheet: 32-color palette, sprite sizes, outline rule, readable pixel font
- Prototypes of the zombie and one villager, approved by Smuck

**Out:** any gameplay.

**Stories:**
1. Export and host an empty web build, and verify load time and that no special headers are needed.
2. Keyboard capture test page: show every typed character, with browser shortcuts swallowed.
3. Title screen with audio unlock.
4. Save service with the MVP save contents (all fields, defaults), plus a reload test.
5. Screen-flow skeleton with placeholder screens.
6. Art-style sheet plus zombie and villager prototype sprites (review gate).

**Playable deliverable:** a hosted link that opens the title, plays a sound after the first click, echoes typed keys and keeps a counter after reload.

---

## Epic 2: Typing Core & Shared Frame (MVP)

**Goal:** build the reusable typing frame that every level runs on.
**Delivers mechanics:** M1 blocking input, M2 stats, M3 pause, the finger guide, the shared HUD, the report card.
**Dependencies:** Epic 1.

**In scope:**
- Target/judgment system: one active character, correct/error handling, ignored keys, case rules, and the timer starting on the first correct key
- Stats: Keys Typed, Errors, Accuracy, WPM, Lesson Time, per-key attempts and errors
- Shared bottom HUD: target area, timer, typed count, WPM (after 5 s), errors, pet slot
- Green zombie hands with the finger map, Shift coaching and f/j bumps
- Pause (Esc, focus loss) with a 3-2-1 resume
- Chalkboard report card with Professor Zombie, "New best!", Play Again/Menu, a 1.0 s input guard, and writing the run to history

**Out:** level-specific worlds.

**Stories:**
1. Judgment rules, with automated tests for correct, wrong, ignored and case handling.
2. Stats calculator matching the GDD definitions (tests with known inputs).
3. HUD layout at 640×360, with a live WPM that is hidden for the first 5 s.
4. Zombie hands: finger map table, next-character highlight, Shift pairing.
5. Pause and focus-loss handling.
6. Report card screen, personal-best check and run-history save (capped at 500).

**Playable deliverable:** a test scene where random letters appear, typing is judged, the hands guide, and a 2:00 timer ends on a correct report card.

---

## Epic 3: Zombie Run (MVP)

**Goal:** the complete Level 1 experience on the Sunny Village Green backdrop.
**Delivers:** the Zombie Run level spec (letter bag, 1-in-4 brain blocks, hop and bonk, hug → conga, dance ending).
**Dependencies:** Epic 2.

**In scope:**
- Targets 48 px apart; 24 px/s amble while waiting, idling before an untyped target; instant resolve plus a 0.15 s chained scoot on correct keys
- 3 visible upcoming targets with an active marker
- Letter bag (26 letters, no immediate repeats) and the 1-in-4 brain-block group shuffle
- Brain-block bonk with +1 brain and the throttled "Brainsss"
- Villager hug → poof → party-hat zombie; conga line (12 drawn, then a ×N badge)
- End dance (2.0 s) → report card, with the +10 completion bonus
- Sunny Village Green backdrop and ground
- Groan ambience (every 3–8 s)

**Out:** tier-based letter pools (Epic 7), other backdrops (Epic 10).

**Stories:**
1. World scroll, zombie amble/scoot/idle and the target queue.
2. Brain block target plus bonk feedback.
3. Villager target, hug, poof and conga line.
4. Run end, dance and brains award.
5. Backdrop art and audio pass.

**Playable deliverable:** play a full 2-minute Zombie Run from the menu and land on a correct report card.

---

## Epic 4: Meta: Menu, Brains & Crypt Closet (MVP)

**Goal:** close the meta loop so brains mean something.
**Delivers mechanics:** M4 brains and Closet, M5 welcome bonus and first purchase, cosmetic display.
**Dependencies:** Epics 2 and 3.

**In scope:**
- Main menu with the zombie preview, brain counter, 3 level cards (2 "Coming soon") and Music/Sound toggles
- Crypt Closet with two 3×3 grids: Pumpkin hat and Cute ghost live (100 each), 16 locked slots; buy/confirm/wear/take off; "Need N more"
- Welcome Gift (+100, once) after the first completed run, and a one-time guided first purchase
- The hat drawn on the zombie in Zombie Run, the menu and the report card; the pet in the HUD and on the report card

**Out:** the other 16 cosmetics (Epic 9), profiles (Epic 11).

**Stories:**
1. Main menu and level cards.
2. Brain wallet in the save (earn and spend).
3. Crypt Closet grids and item states.
4. Buy and equip flow, saved immediately.
5. Welcome Gift plus guided first purchase.
6. Cosmetic overlays: hat anchor on all zombie poses; pet slot in the HUD.
7. Pumpkin hat and Cute ghost art.

**Playable deliverable:** a new save goes run → welcome gift → buys and wears the Pumpkin hat → plays again with it visible → earns and buys the Cute ghost.

---

## Epic 5: MVP Polish & First Link (MVP)

**Goal:** a link Smuck is happy to send to family.
**Dependencies:** Epics 1–4.

**In scope:**
- SFX and music pass (MVP audio list)
- Wrong-key shake and tick
- "Caps Lock is on" hint
- Readability and colorblind check
- Performance and save-integrity checks against the Technical Metrics
- A playtest with at least 1 kid before publishing (observe the second-run and first-purchase behavior); the success metric completes once 3 kids have played
- Fixes from the playtest
- Publishing the link

**Stories:**
1. Audio implementation and mix.
2. Feedback polish (wrong-key shake, tick, Caps Lock hint).
3. Technical metric checks on 3 computers.
4. Kid playtest session and notes.
5. Playtest fixes, then publish.

**Playable deliverable:** the public MVP link.

---

## Epic 6: Horde Rush (Post-MVP)

**Goal:** Level 2, the reverse-PvZ typing siege.
**Dependencies:** Epics 2 and 4; a basic word list (fixed 3–5 letter band until Epic 7).

**In scope:**
- 5-lane field
- Word display with per-letter progress; the word completes on its last letter
- Random-lane spawn of player copies wearing the hat
- Size classes (≤3 / 4–5 / ≥6 letters)
- Pacing defender, projectiles, red flash and melt
- House arrival with brains 1/2/3; 5:00 timer; +25 completion bonus
- 1 house+defender pair (Farmhouse + Farmer) at launch
- Starter word list (tagged)
- Menu card enabled

**Stories:**
1. Word target mode in the typing frame.
2. Lanes, spawning and size classes.
3. Defender pacing, throwing and hit/melt.
4. Arrival and brains; run end.
5. Tuning pass toward the 40% / 70% arrival targets and economy parity.
6. Farmhouse + Farmer art; march music.

**Playable deliverable:** Horde Rush selectable and complete from the menu.

---

## Epic 7: Adaptive Curriculum (Post-MVP)

**Goal:** the invisible skill-based curriculum.
**Dependencies:** Epics 3 and 6 (and run-history data from the MVP).

**In scope:**
- Rolling average (last 1–5 completed runs)
- Placement on the first run
- The 5-tier table with hysteresis
- Row-scoped letter pool in Zombie Run
- Master word list (~1,500 words, Dolch cross-check, Smuck review) and the build-time row/length tagging script
- Tier word pools for Horde Rush (at least 40 home-row words for tier 1)

**Stories:**
1. Tier calculation plus hysteresis (automated tests with scripted run histories).
2. Placement flag and first-run behavior.
3. Master word list authoring and review.
4. Tagging script plus pool validation (minimum counts per tier).
5. Hook Zombie Run and Horde Rush to tier pools.

**Playable deliverable:** a new save's placement run sets the tier, and later runs silently show the right rows and word lengths.

---

## Epic 8: Pitchfork Panic (Post-MVP)

**Goal:** Level 3, the paragraph chase.
**Dependencies:** Epics 2 and 7 (tiers for text selection).

**In scope:**
- 2-line paragraph display
- Case-sensitive input with Shift coaching
- Step movement; mob model (15-step gap, 4 WPM-eq start, +1 per 10 s)
- Brain pickups every 10–30 steps, 5 brains each
- Caught sequence (dust cloud, stars, "Got you!") and Escaped! at 5:00 (+25)
- +10 bonus on every finished run
- About 40 authored paragraphs (tiers 3–5) and a sentence generator for tiers 1–2
- Moonlit Village setting; chase music; menu card enabled

**Stories:**
1. Paragraph target mode (2-line window, flow between passages).
2. Chase movement, mob and camera.
3. Pickups and economy.
4. Caught and Escaped endings.
5. Paragraph authoring and the tier 1–2 sentence generator.
6. Tuning pass (start gap and acceleration against run-length targets).

**Playable deliverable:** Pitchfork Panic selectable and complete.

---

## Epic 9: Full Crypt Closet (Post-MVP)

**Goal:** complete the 18-item collection.
**Dependencies:** Epic 4; Epic 6 (for fit-checks on the Horde Rush size classes).
**In scope:** the 8 remaining hats and 8 remaining pets from the GDD catalogue, at their prices; overlay fit-checks on every zombie pose and the Horde Rush size classes.
**Stories:**
1. Hat art (8) with fit-checks on all poses and size classes.
2. Pet art (8) with idle animations.
3. Catalogue and prices live in the Closet; remove the "Coming soon" slots.

**Playable deliverable:** every Closet slot can be bought and worn.

---

## Epic 10: Art Variety & Trends (Post-MVP)

**Goal:** freshness through art, plus visible progress.
**Dependencies:** Epics 3, 6 and 8.

**In scope:**
- Pumpkin Patch Farm and Snowy Town (Zombie Run)
- Castle + Knight and Beach Hut + Lifeguard (Horde Rush)
- Cornfield Path and Spooky Forest Bridge (Pitchfork Panic)
- Random theme per run with no immediate repeat
- A trends screen showing WPM, accuracy and practice time over recent runs, plus lifetime totals (keys typed, best WPM, total brains, time practiced)

**Stories:**
1. Zombie Run backdrops (2).
2. Horde Rush house and defender pairs (2).
3. Pitchfork Panic chase settings (2).
4. Random theme rotation with no immediate repeat.
5. Trends and lifetime-stats screen from run history.

**Playable deliverable:** each level rotates between 3 looks, and the trends screen shows progress.

---

## Epic 11: Profiles & Zombie Naming (Post-MVP, as needed)

**Goal:** sibling-safe shared computers.
**Dependencies:** Epic 4 (can land any time after Epic 5).

**In scope:**
- A "Who's playing?" picker at launch
- Create a zombie with a name (plain-word, length-limited)
- Per-zombie brains, cosmetics, run history and tier
- The name shown on the report card and the menu
- Migrating the single MVP save into the first profile

**Stories:**
1. Profile picker and creation (name entry).
2. Per-profile save separation.
3. Migrate the MVP save into the first profile.
4. Name on the menu and report card.

**Playable deliverable:** two kids on one computer keep separate zombies.
