# Decision Log — GDD: Zombies Teach Typing

## 2026-09-27

- **Intent:** Create a new GDD. Inputs: final game brief (+ its decision log) and the brainstorming session (96 ideas).
- **Carried from brief (established):** ages 6–13; goofy, never babyish; player is always the zombie; 3 standalone levels; 4 pillars (goofy zombie / typing is the only skill / adapts invisibly / small, classic, finishable); brains → cosmetics only; 3×3 hat + 3×3 pet grids at 100/200/300; web primary, Godot 4.7 Compatibility, GDScript only; Claude-generated code-authored art; MVP as defined in the brief.
- **Scope/stakes:** solo non-commercial passion project, weekend mornings, also a BMAD/BMGD learning vehicle → GDD right-sized: full depth on MVP (Zombie Run + shared frame + Closet), lighter-but-numeric on post-MVP levels.
- **Workspace created:** gdd.md skeleton from template, this log.
- **Game type (user):** `general` (low complexity) + custom "Educational Typing Design" section. No canonical type fits; rhythm and party-game were considered.
- **Working mode (user):** Hybrid: facilitator proposes numbered answers to the 7 open questions in one batch, user accepts/tweaks, then full draft.
- **Open questions resolved (user accepted all proposals):**
  1. WPM → difficulty: 5 tiers (<8 / 8–14 / 15–21 / 22–29 / 30+) scoping rows (home → +top → +bottom) and word length (2–3 … 5–8); rolling avg of last 1–5 runs across all levels; 2-WPM downward hysteresis; first run = full-keyboard placement.
  2. Economy: equal brains-per-minute principle. Zombie Run 1 brain per brain block (1 in 4 targets) + 10 completion; Horde Rush 1/2/3 by zombie size + 25 completion; Pitchfork Panic pickups every 5–30 s + 10 for runs ≥30 s. Welcome bonus 100; MVP items cost 100 each.
  3. Naming: **keep "Zombie Run"** (user chose to accept the overlap).
  4. Cosmetics grid: hats 100 Pumpkin/Witch/Bunny ears · 200 Santa/Leprechaun/Valentine headband · 300 New Year's top hat/Pirate/Golden crown. Pets 100 Ghost/Black cat/Spider · 200 Orange cat/Bat/Crow · 300 Wolf-dog/Floating eyeball/Brain buddy. Graduation cap dropped (Professor Zombie already wears one).
  5. Art themes: Zombie Run = Sunny Village Green (MVP)/Pumpkin Patch Farm/Snowy Town; Horde Rush = Farmhouse+Farmer (tomatoes)/Castle+Knight (suction-cup darts)/Beach Hut+Lifeguard (water balloons), no guns; Pitchfork Panic = Moonlit Village/Cornfield Path/Spooky Forest Bridge.
  6. Caught moment: dust cloud (1.5 s) → dazed zombie with stars + "Got you!" → report card (~3 s total); brains kept.
  7. Sources: curated ~1,500-word kid-safe master list (Claude-authored, checked against public-domain Dolch), tagged by rows/length by build-time script, human-reviewed once; ~40 original goofy paragraphs for tiers 3–5; tiers 1–2 of Pitchfork Panic use generated sentences from row-filtered words.
  - MVP Closet items: **Pumpkin hat + Cute ghost**, 100 brains each.
- **Facilitator correction during drafting (flagged to user):** Pitchfork Panic pickup value lowered 10 → 5 brains (parity math: 10 gave ~34/min regardless of skill, ~2× Zombie Run at 10 WPM). Added 5:00 run cap = "Escaped!" with +25 bonus (the mob model otherwise let ≥19 WPM typists run indefinitely). Pending user confirmation at review.
- **Draft v1 written:** gdd.md (full) + epics.md (11 epics; MVP = 1–5).
- **Drafting-time resolutions (facilitator, for audit):** report card buttons are Play Again / Menu (the brainstorm's "NEXT" is dropped because levels are standalone); the Pitchfork Panic text sits in the shared bottom target area (2-line window) per #39, not "on the side" (#32); run timer starts on the first correct key; quitting a run keeps brains but records no stats; Zombie Run shows 3 upcoming targets and the zombie idles before an untyped target; Closet button lives on the main menu in the MVP (no profile screen yet); logical resolution 640×360, 32-color palette, 32×32 characters.
- **Input reconciliation (brief + brainstorm vs draft):** all 96 brainstorm ideas are covered, superseded or listed in Out of Scope. Gap fixed: the brief's player-experience line ("clever and a bit mischievous") added to the Executive Summary. Added the inline A4 tag.
- **Validation pass (validator subagent, checklist):** chain intact, no template tokens, assumptions index consistent, arithmetic largely confirmed. Findings applied:
  - **F1 (user-approved):** Zombie Run movement changed to an instant resolve on a correct key + a 0.15 s chained scoot; targets 48 px apart; 24 px/s amble only while waiting (the fixed walk would have capped typing at ≈7 WPM).
  - **F2 (user-approved):** Pitchfork Panic pickups spawn by **distance** (every 10–30 steps, 5 brains), not time; +10 on every finished run; economy table corrected (Horde Rush ≈120 at 20 WPM; Pitchfork Panic ≈40 / ≈160).
  - Autofixes: shared HUD spec added (M2b); tier boundary and multi-tier drop rules; Pillar 3 dial wording includes punctuation; the performance test uses Zombie Run for the MVP; save on quit; playtest counts aligned (≥1 before publishing, 3 for the metric); naming decision recorded in the GDD; terminology unified (party-hat zombie, "Educational Typing Specific Design"); `game_type: general`; stories added to Epics 9–11; Epic 9 depends on Epic 6.
  - New designer notes: Horde Rush low-WPM parity (Epic 6), cross-level WPM comparability (Epic 7).
- **Open-items review:** 5 assumptions (A1–A5) + 5 designer notes, all tuning or playtest items tied to specific epics; **0 phase-blockers** for architecture.
- **Polish:** no doc_standards configured; manual coherence pass done. **Narrative handoff:** not applicable (general type, no narrative flag; the brief rules out story). **External handoffs:** none configured.
- **Status → final (v1.0).**

## 2026-09-27 — Course correction (gds-correct-course)

- **Trigger:** implementation-readiness-report-2026-09-27.md (NEEDS WORK, light). Full proposal: `planning-artifacts/sprint-change-proposal-2026-09-27.md`. All edits approved by Smuck in incremental review.
- **GDD clarifications applied:**
  - **Scaling (U1):** "whole numbers where possible" → fractional scaling with nearest filtering to fill the browser window, plus a Fullscreen toggle on the main menu. Reason: at 1366×768 the browser canvas is ~620–660 px tall, so integer scaling rendered at 1×.
  - **Main menu (U1):** adds a Fullscreen toggle next to Music and Sound.
  - **Pause panel (U4):** Music and Sound toggles also appear on the pause panel (kids want to mute mid-run).
  - **Readability (U2):** the 32 px minimum applies to letter and word targets; Pitchfork Panic's 2-line paragraph text is ≥ 24 px so both lines and the zombie hands fit the 104 px HUD band.
  - **Passage join (G7):** passages are joined by a single typed Space (counts as a key); no new input rule needed.
- **Status:** stays final (clarifications only; no scope change).
