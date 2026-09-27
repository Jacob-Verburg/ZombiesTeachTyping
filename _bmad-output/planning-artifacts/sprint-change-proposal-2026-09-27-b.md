# Sprint Change Proposal — UX Spine Upstream Changes

- **Project:** zombies-teach-typing
- **Date:** 2026-09-27 (second course correction of the day; the first is `sprint-change-proposal-2026-09-27.md`)
- **Author:** Smuck (with gds-correct-course)
- **Mode:** Incremental — all 6 proposals approved one by one
- **Scope classification:** Moderate (backlog edits across 5 epics + 1 new post-MVP story; GDD + architecture text updates; no rollback, MVP scope unchanged)

---

## 1. Issue Summary

Finalizing the game UX spines (`ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md`, `EXPERIENCE.md`, UX decision log D1–D16) produced four decisions that conflict with, or are missing from, the GDD, epics and architecture. EXPERIENCE.md's "Upstream changes required" section routes them here:

1. **Level gating (D12, D14).** Level 2 unlocks after Level 1, Level 3 after Level 2. This contradicts the GDD's "nothing is locked / nothing is gated" (Win/Loss, M4, Curriculum Model, Difficulty Curve, Level Progression), FR26, FR38 and Story 4.2, and needs a new save field.
2. **Styled web boot splash (D11).** Contradicts the first sprint-change proposal, which deferred the custom splash ("the default Godot splash stays for now").
3. **Brain counter in every level's HUD (D15).** GDD M2b, FR14 and Story 3.2 say Zombie Run only.
4. **Layout-sketch gates.** Stories 2.5, 2.9, 4.2, 4.4 and 5.0 ask for layout sketches that the spines and three approved key-screen mocks now supersede or constrain.

**Issue type:** new requirement from the stakeholder (UX-phase design decisions).

**Discovered during analysis (not in the UX doc):**

- Gating is invisible in the MVP: L2/L3 are "Coming soon", and Coming soon takes precedence over Locked.
- Unlocks **cannot be derived from run history**: history is capped at 500 runs, so a qualifying run would eventually be dropped and the level would re-lock. The unlock must be persisted.
- A per-level brain counter in the **shared** HUD needs a push signal on `LevelBase`; today there is only the pull method `get_brains_earned()`, used at run end.
- `end_reason` values were never defined in the architecture; the unlock rule depends on them.
- The epics' "UX Design Requirements" section still says "No UX design document exists".

## 2. Impact Analysis

### Epic Impact

| Epic | Impact |
|---|---|
| 1 Foundation | None |
| 2 Typing Core & Shared Frame | Story 2.4: new `LevelBase` signal. Story 2.5: brain counter in the shared HUD; sketch gate narrowed to paragraph mode. Story 2.9: mock replaces the sketch |
| 3 Zombie Run | Story 3.2: emits the signal instead of owning its counter |
| 4 Meta | Story 4.2: mock replaces the sketch; level card built as a state-enum component. Story 4.4: sketch must follow the spines |
| 5 MVP Polish | Story 5.0: boot splash ACs; art checked against spines + mocks |
| 6 Horde Rush | **New Story 6.8 Level Unlocks** (FR79, save schema v2). Story 6.5: signal line |
| 8 Pitchfork Panic | Story 8.4: signal line. Story 8.5: FR79 data-only line |
| 7, 9, 10, 11 | None (Epic 11 profiles get per-profile unlocks for free via ADR-2) |

No epic becomes obsolete; order is unchanged (1 → … → 5 → 6 → …).

### Artifact Conflicts

- **GDD:** Win/Loss, M2b, M4, Curriculum Model, Difficulty Curve, Level Progression, Save contents, MVP asset list, decision log. Pillar 3 unchanged (unlocks show no difficulty labels).
- **Epics:** UX Design Requirements section, FR14, FR26, FR38, new FR79, coverage map, Epic 6 header, Stories 2.4, 2.5, 2.9, 3.2, 4.2, 4.4, 5.0, 6.5, 8.4, 8.5, new 6.8.
- **Architecture:** `LevelBase` contract, Brains during a run, Run record end reasons, schema v2 plan, `PlayerData` methods, `level_registry` field, web export preset note.
- **UX:** already reflects the decisions. One follow-up: EXPERIENCE.md Level Unlocks → Persistence should say the unlock itself is persisted (not derived from run history), per the analysis above.

### Technical Impact

- MVP: one extra signal on `LevelBase`, the HUD counter moves into the shared frame, `html/head_include` CSS plus boot-splash project settings. `CURRENT_SCHEMA` stays 1.
- Post-MVP (Epic 6): schema v2 migration with backfill, unlock rule in `PlayerData.record_run()`, Locked/New card states, unlock moment, debug unlock/relock.
- CI: the Web export preset carries the head-include; no pipeline change.

## 3. Recommended Approach

**Direct Adjustment (Option 1).**

- **Rollback:** not applicable; no story has been implemented (`implementation-artifacts/` is empty).
- **MVP review:** not needed. Gating is scheduled post-MVP (Epic 6) because it cannot appear while L2/L3 are Coming soon. The MVP additions (signal, splash styling) are small.
- **Effort:** Low (MVP), Medium-Low (Story 6.8). **Risk:** Low. **Timeline impact:** negligible for the MVP; +1 story in Epic 6.

**Decisions confirmed by Smuck:** incremental review; gating built in Epic 6; unlock rule = first run of the previous level that reaches 0:00 (quit never unlocks); boot splash lives in Story 5.0.

## 4. Detailed Change Proposals

`UX/` = `planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/`.

### Proposal 1 — GDD: level gating wording (D12) ✅

| Section | OLD | NEW |
|---|---|---|
| Win/Loss (intro) | "…replayable forever, and nothing is locked. Per run:" | "…replayable forever. Each level after the first opens once the previous level has one completed run (see Level Progression); nothing else is ever locked. Per run:" |
| M4, bullet 1 | "…Only cosmetics can be bought; no learning content is ever gated." | "…Only cosmetics can be bought; brains never gate learning content (level order is the only gate, see Level Progression)." |
| Curriculum Model | "…The level menu doubles as a skill ladder, but all levels are open from the start." | "…The level menu doubles as a skill ladder: each level opens after one completed run of the one before it." |
| Difficulty Curve | "…Players choose freely; nothing is gated." | "…Each level opens after one completed run of the previous one; after that, players choose freely between open levels." |
| Level Progression | "All levels are unlocked from the start. The main menu is … In the MVP, Horde Rush and Pitchfork Panic appear with a "Coming soon" sign and cannot be selected." | (1) "The main menu is a *Mario Teaches Typing*-style level select." (2) "**Level unlocks** *(post-MVP, UX D12)*: Horde Rush opens after the first Zombie Run that reaches 0:00; Pitchfork Panic opens after the first Horde Rush that reaches 0:00. Quit runs never unlock. An unlock is saved permanently and plays a one-time unlock moment on the menu. Unlocks gate access only; no difficulty labels are shown (Pillar 3)." (3) "In the MVP, Horde Rush and Pitchfork Panic appear with a "Coming soon" sign and cannot be selected. "Coming soon" takes precedence over Locked, so no lock ever shows in the MVP." |
| Save contents | "…placement-done flag; current tier…" | "…placement-done flag; level unlocks (post-MVP: per level, unlocked + unlock-moment-seen + first-chosen); current tier…" |

Plus a GDD decision-log entry "Course correction #2" recording D12, D15 and the D11 splash reversal. Pillar 3 unchanged.

*Rationale:* aligns with D12 without making unlocks a skill system; Pillar 2 holds (a quit run just doesn't unlock).

### Proposal 2 — Epics: level gating (D12) ✅

- **FR26** — append: "\"Coming soon\" (driven by `available = false`) always takes precedence over Locked (FR79)."
- **FR38** — "no learning content is ever gated" → "brains never gate learning content (level order is the only gate, FR79)."
- **New FR79 [Post-MVP]:** A level after the first is **Locked** until the previous level has one run that ended because its timer reached 0:00 (Horde Rush ← Zombie Run; Pitchfork Panic ← Horde Rush). Quit runs never unlock. An unlock is saved permanently, not worked out from the 500-run history. A Locked card shows only a padlock; while the card has focus, a hint sign below it names the level to finish, and Enter or a click on it only makes the card wiggle. The first time the menu is shown after an unlock, a one-time unlock moment plays: the padlock pops off, the tint clears, a "New!" badge appears and focus moves to the card. Input stays live, so any key finishes the animation instantly. The "New!" badge stays until the card is chosen the first time. (UX D12, D14; EXPERIENCE.md Level Unlocks)
- **FR Coverage Map:** add "FR79: Epic 6 - Level unlocks (Locked / New card states, unlock moment, save)". Epic 6 header **FRs covered:** "FR53–FR59, FR66 (tool + starter list), FR79".
- **Story 4.2**, AC 2 "And" — append: "…and the level card is built as a single component with a state enum (Available / Coming soon, with Locked and New added in Story 6.8) so Epic 6 adds states rather than rebuilding the card".
- **New Story 6.8: Level Unlocks** (after 6.7):

  > As a kid,
  > I want the next level to open after I finish the one before it, with a fun moment when it does,
  > So that I have something to aim for, and a surprise when I get there.
  >
  > **Acceptance Criteria:**
  >
  > **Given** `LevelDef` in `level_registry.tres`
  > **When** it is inspected
  > **Then** each level has an `unlocked_by: StringName` (empty for Zombie Run, `&"zombie_run"` for Horde Rush, `&"horde_rush"` for Pitchfork Panic)
  >
  > **Given** save schema v2
  > **When** a v1 save loads
  > **Then** `migrate_1_to_2` adds `level_unlocks: {}` and backfills it: every level whose `unlocked_by` level has a run in `run_history` with `end_reason == &"timer"` is saved as unlocked with its moment not yet seen (so existing players see the moment on their next menu visit)
  > **And** `test_save_schema.gd` covers the migration with a fixture file
  >
  > **Given** `PlayerData.record_run(result)`
  > **When** the result's `end_reason` is `&"timer"` and a level has `unlocked_by == result.level_id` and is not yet unlocked
  > **Then** that level is saved as unlocked and `level_unlocked(level_id)` is emitted; quit runs never reach this path (FR13, FR79)
  >
  > **Given** a level card whose level is `available` but not unlocked
  > **When** the menu shows it
  > **Then** it shows the Locked state (dusk tint and padlock only); while it has focus a hint sign hangs below it ("Finish Zombie Run to open!"); Enter or a click only wiggles the card (FR79, DESIGN.md level-card)
  > **And** a level with `available = false` shows Coming soon whatever its lock state
  >
  > **Given** an unlocked level whose moment has not been seen
  > **When** the main menu is shown (from any route)
  > **Then** the unlock moment plays once (EXPERIENCE.md Level Unlocks), `PlayerData.mark_unlock_seen(level_id)` saves it, and focus moves to that card
  > **And** any arrow key, Enter, Esc or click during the animation finishes it instantly and is then handled normally
  >
  > **Given** a card showing "New!"
  > **When** it is chosen for the first time
  > **Then** the badge is cleared and that is saved
  >
  > **Given** `test_player_data.gd` and `test_level_unlocks.gd`
  > **When** GUT runs
  > **Then** the unlock-on-timer, no-unlock-on-quit, one-time-moment and backfill cases pass
  > **And** the debug overlay gains "Unlock all / Relock all" (debug builds only)

- **Story 8.5** — add: "**And** the Pitchfork Panic card follows FR79 (Locked until a Horde Rush reaches 0:00) with no new code".

*Rationale:* all gating stays post-MVP; Story 4.2 is shaped so Epic 6 doesn't rework the card; the backfill covers MVP players who already have completed runs.

### Proposal 3 — Architecture: level gating data model (D12) ✅

- **Save System → Run record** — add: "**End reasons:** `&"timer"` (the level's clock reached its duration: Zombie Run, Horde Rush), `&"caught"` and `&"escaped"` (Pitchfork Panic). Quit runs are never recorded, so there is no quit reason in history. Defined once as constants in `GameConstants`."
- **Save System** — add after the JSON block: "**Schema v2 (Epic 6, Story 6.8):** adds `\"level_unlocks\": { \"horde_rush\": { \"moment_seen\": false, \"chosen\": false } }` to each profile. A level's key being present means it is unlocked, and it is never removed. `migrate_1_to_2` backfills it from `run_history` (any `&\"timer\"` run of the `unlocked_by` level). Unlocks are saved permanently rather than derived from history, because history is capped at 500 runs."
- **PlayerData** method list — add "from Epic 6 `mark_unlock_seen()` / `mark_level_chosen()`", "unlocks are read with `get_unlock_state(level_id)`", and "`record_run()` applies the level unlock rule (FR79) and emits `level_unlocked(level_id)`."
- **Project Structure** — `level_registry.tres` comment: "level_id → scene + card art + available flag + unlocked_by (Epic 6)".
- No new ADR (fits ADR-2; per-profile unlocks come free with Epic 11).

### Proposal 4 — Brain counter in every level (D15) ✅

- **GDD M2b** — "…**Timer**, **Keys Typed**, **WPM** and **Errors**. A **pause button** … Zombie Run adds a brain counter next to the stats." → "…**Timer**, **Keys Typed**, **WPM** and **Errors**, with the **brain counter** (this run's brains) beside it in every level. A **pause button** sits in the top-right corner of the playfield."
- **FR14** — "Zombie Run adds a brain counter next to the stats." → "A brain counter beside the stats shows this run's brains in every level."
- **Architecture `LevelBase`** — add `signal brains_earned_changed(total: int)       # emitted whenever the level's run total changes; RunFrame forwards it to the HUD`. `get_brains_earned()` stays for the final award.
- **Architecture "Brains during a run"** — "the in-run brain counter shows the level's local total." → "the shared HUD's brain counter (every level, UX D15) shows the level's local total, fed by `LevelBase.brains_earned_changed`, never by `PlayerData.brains_changed`. The menu and Closet counters use `PlayerData`."
- **Story 2.4** — add `brains_earned_changed` signal to the contract list; test level AC: "**And** the test level emits `brains_earned_changed` +1 for every 4th correct key so the HUD counter can be seen working".
- **Story 2.5**, AC 2 "Then" — "…and a stats column with Timer, Keys Typed, WPM and Errors;…" → "…a stats column with Timer, Keys Typed, WPM and Errors, and the brain counter beside it (starts at 0 and updates on `brains_earned_changed` in the same frame);…"
- **Story 3.2**, AC 4 — "Given the Zombie Run HUD / When brains are collected / Then a brain counter next to the stats shows the level's running total (FR14)" → "Given a brain is collected / When the level's total changes / Then Zombie Run emits `brains_earned_changed(total)` and the shared HUD counter from Story 2.5 shows it (FR14)".
- **Stories 6.5 and 8.4** — add: "**And** the level emits `brains_earned_changed` on every award, so the shared HUD counter updates (FR14)".

### Proposal 5 — Styled web boot splash (D11) ✅

- **Story 5.0** — add ACs:

  > **Given** the web build loading on a slow connection
  > **When** the page opens
  > **Then** the loading screen matches the title screen: a night (`#2B1D3F`) page, the title logo, and a chunky pumpkin (`#F07A1C`) progress bar on a dusk (`#4A3366`) track, with no text beyond the logo and no default Godot logo (DESIGN.md boot-splash, UX D11)
  > **And** it is done through the Web export preset's `html/head_include` CSS, which restyles the default shell's `#status`, `#status-progress` and `#status-notice` elements. A full `html/custom_html_shell` is used only if the head-include approach can't reach the look, and the reason is noted in the story file
  >
  > **Given** the engine has loaded
  > **When** Godot's own boot splash shows
  > **Then** `application/boot_splash/bg_color` is `#2B1D3F`, the image is the title logo (Nearest filter, no stretch), and the change from loading page → boot splash → title screen has no white or grey flash on Chrome, Edge and Firefox. The Windows fallback uses the same boot splash settings

- **Story 5.0 asset list** — add "web loading page + boot splash (logo on night, pumpkin progress bar)".
- **GDD MVP asset list, UI row** — add "boot splash (logo on night, pumpkin progress bar)" after "Title logo,".
- **Architecture web export preset note** — append "; loading-page styling via `html/head_include` (Story 5.0), with project boot-splash bg `#2B1D3F`."
- Supersedes the deferral in `sprint-change-proposal-2026-09-27.md` §3 (that file is left unchanged as a record).

### Proposal 6 — Layout-sketch gates point at the UX spines ✅

Rule: **spines > mocks > layout sketches.** Known mock drift (the HUD mock's Horde Rush frame has no brain counter; the menu mock shows the Locked hint at rest) is resolved by the spines.

- **Epics "UX Design Requirements"** — replace "No UX design document exists…" with: "The UX spines are the visual and interaction contract for every screen: `UX/DESIGN.md` (look: palette, typography, components, layout) and `UX/EXPERIENCE.md` (behaviour: flows, states, input, Level Unlocks). Key-screen mocks: `UX/mockups/key-main-menu.html`, `key-run-hud.html`, `key-report-card.html`. On any conflict, spines > mocks > layout sketches. FRs stay the testable requirements; the spines say how they look and behave."
- **Story 2.5**, AC 1 → "**Given** the HUD band in `UX/DESIGN.md` (Layout, HUD band component) and the Run HUD mock (letter and word modes) / **When** the HUD is built / **Then** it matches them, including the brain counter in every mode (D15); and a layout sketch of the **2-line paragraph mode** (not mocked) that follows DESIGN.md is approved by Smuck in the story file before that mode is built".
- **Story 2.9**, AC 1 → "**Given** the Report Card mock and `UX/DESIGN.md` (chalkboard, Professor Zombie, \"New best!\" stamp, buttons) / **When** the screen is built / **Then** it matches them (the level name as the heading, night classroom backdrop, mortarboard stacked on the worn hat, D16), with every text at 16 px or more. No separate sketch is needed; the mock is the approved layout".
- **Story 4.2**, AC 1 → "**Given** the Main Menu mock (section A, MVP) and `UX/DESIGN.md` Layout and Components (level-card states, Closet button on the signpost, toggles bottom-right) / **When** the screen is built / **Then** it matches them. No separate sketch is needed; the mock is the approved layout".
- **Story 4.4**, AC 1 "Given" → "a layout sketch of the Closet at 640×360 that follows `UX/DESIGN.md` (closet-item-tile states and colors, brain counter pill, panel materials) and `UX/EXPERIENCE.md` (grid navigation, confirm prompt with default focus on Yes, first-visit tutorial) (two 3×3 grids with prices, tile states, preview zombie, brain counter, the tutorial arrow's positions)". "Then" unchanged.
- **Story 5.0**, AC 2 → "…and matches `UX/DESIGN.md` (palette tokens, typography, component states), the three key-screen mocks, and the approved layout sketches from Stories 2.5 (paragraph mode) and 4.4 (NFR13); screens without a mock or sketch (title, boot splash, pause panel and countdown, Welcome Gift) follow the spines directly".

### UX follow-up (minor, from analysis)

- **EXPERIENCE.md → Level Unlocks → Persistence:** "'unlock seen' must be saved per level … requires a save field" → state that the **unlock itself** is persisted (`level_unlocks`, schema v2) together with moment-seen and first-chosen, and is not derived from run history (capped at 500). Upstream-changes item 1 → mark as routed to this proposal.

## 5. Implementation Handoff

**Scope: Moderate** — backlog and document edits; no replan.

| Role | Responsibility |
|---|---|
| Developer agent (doc edits) | Apply Proposals 1–6 + the UX follow-up to `gdd.md` (+ decision log), `epics.md`, `game-architecture.md`, `EXPERIENCE.md` exactly as written |
| PO / Scrum (sprint planning) | No `sprint-status.yaml` exists yet; when `gds-sprint-planning` runs, include new Story 6.8 in Epic 6 |
| Developer agent (implementation) | Build MVP stories against the updated ACs (2.4, 2.5, 2.9, 3.2, 4.2, 4.4, 5.0) |

**Success criteria**

- `grep -i "nothing is locked\|nothing is gated\|open from the start\|unlocked from the start\|Zombie Run adds a brain counter\|No UX design document exists"` over the GDD and epics returns nothing.
- FR79 is present and mapped to Epic 6; Story 6.8 exists with the ACs above.
- `LevelBase` in the architecture and Story 2.4 both list `brains_earned_changed`; end reasons are defined.
- Stories 2.5, 2.9, 4.2, 4.4 and 5.0 reference `UX/` spines/mocks; sketch gates remain only for paragraph-mode HUD and the Closet.
- Story 5.0 has the boot-splash ACs; the GDD asset list includes the boot splash.

## 6. Approval and Execution Log

- **2026-09-27:** Proposal approved by Smuck ("yes"), including the UX follow-up.
- **Applied** to `gdd.md` (+ decision log "Course correction #2"), `epics.md`, `game-architecture.md` and `EXPERIENCE.md` (Persistence line; "Upstream changes required" marked routed, closing Open Questions 2 and 7).
- **Consistency fix made while applying:** Story 6.7's last AC said flipping `horde_rush.available` makes the card "selectable" and the next tag publishes it. With FR79 that card is Locked until a Zombie Run reaches 0:00, so it now reads "selectable once unlocked (Story 6.8), and the next version tag after Story 6.8 publishes it".
- **Success criteria verified:** stale-phrase grep empty; FR79 present and mapped to Epic 6; Story 6.8 sits before Epic 7; `brains_earned_changed` in the architecture and Stories 2.4, 2.5, 3.2, 6.5, 8.4; end reasons defined; boot-splash ACs in Story 5.0.
- **Sprint status:** no `sprint-status.yaml` exists yet; include Story 6.8 when `gds-sprint-planning` runs.
