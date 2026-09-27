---
title: Sprint Change Proposal — Readiness Report Fixes
project: zombies-teach-typing
date: 2026-09-27
author: Smuck (with gds-correct-course)
status: approved (2026-09-27)
trigger: implementation-readiness-report-2026-09-27.md
scope: Moderate
mode: Incremental (all edits reviewed one by one)
---

# Sprint Change Proposal: Readiness Report Fixes

## 1. Issue Summary

**Trigger:** the implementation-readiness check (`implementation-readiness-report-2026-09-27.md`), run before any story was built. No sprint status or story files exist yet (`implementation-artifacts/` is empty), so nothing has to be rolled back.

**Problem type:** gaps in the original requirements, not a technical failure. The report rated the plan **NEEDS WORK (light)**: 0 critical, 7 major and 18 minor findings. They fall into four groups:

1. **GDD requirements no story owns:** key swallowing is never switched on in real runs (G1), there's no MVP UI art story (G2), and run history can't be read from the web build, so the success metrics can't be measured (G3).
2. **Story defects:** a forward dependency on the pixel font (Q2), Story 2.4 is too big (Q5), CI deploys every push to the public link (Q1), and a few ownership and test-timing issues (Q7–Q13).
3. **Layout and scaling that were never checked:** integer scaling renders at 1× on the 1366×768 target laptop (U1), the Pitchfork Panic text doesn't fit the HUD band at 32 px (U2), there are no wireframes for the dense screens (U3), and toggle placement was never decided (U4).
4. **Small GDD gaps:** how passages are joined (G7) and the missing PlayerData flag API (G8).

**Evidence:** every finding points to a specific line in the story or document. See sections G1–G8, U1–U5 and Q1–Q15 of the readiness report.

## 2. Impact Analysis

### Epic impact

| Epic | Impact |
|---|---|
| 1 Foundation & Web Pipeline | Changes to ACs in 1.1, 1.2, 1.3, 1.5, 1.6, 1.8 and 1.9 (scaling, deploy on tags, font moved earlier, fullscreen, save export) |
| 2 Typing Core & Shared Frame | 2.4 split and **new Story 2.10**; changes to ACs in 2.5, 2.7 and 2.9 |
| 3 Zombie Run | Placeholder-art ACs in 3.1–3.3; audio ownership and tests moved (3.2, 3.7); checklist line in 3.6 |
| 4 Meta | Flag API (4.1), Fullscreen toggle, sketch and export (4.2), checklist (4.3), sketch (4.4), flags and path note (4.5) |
| 5 MVP Polish | **New Story 5.0** (UI art pass); changes to ACs in 5.1, 5.3, 5.4 and 5.5 |
| 6, 8 | Levels enabled only in their final story (6.3→6.7, 8.3→8.7); 8.2 paragraph text size and Space join |
| 7 | 7.1 reads history through the export; profile-scope note |
| 9, 10 | None |
| 11 | 11.3 wording ("fields that exist at the time") |

No epic is added, removed or reordered. Every epic can still be completed as planned.

### Artifact conflicts

- **GDD:** 5 clarifications (scaling, Fullscreen toggle, pause-panel toggles, paragraph text size, passage join), plus a decision-log entry.
- **Architecture:** scale mode, deploy trigger (ADR-4), `WebPlatform` API (`capture_keys` lifecycle, fullscreen, download), `PlayerData.set_flag()`, `SaveService.export_json()`, debug and export keys.
- **UX:** there's no UX doc. Instead of writing one, layout-sketch approval ACs go on 2.5, 2.9, 4.2 and 4.4.
- **CI/CD:** `build.yml` (not written yet) is specified to deploy only from `v*` tags.

### Technical impact

No code exists yet, so there's no rework. The MVP grows by 2 stories (2.10, which was split out of 2.4, and 5.0). Story 5.0 covers art the GDD's MVP asset list already assumed.

## 3. Recommended Approach

**Selected: Option 1, direct adjustment.**

| Option | Verdict |
|---|---|
| 1. Direct adjustment (edit stories, add 2) | ✅ Viable. Effort: low. Risk: low. |
| 2. Rollback | N/A, nothing has been built |
| 3. MVP review | Not needed. Scope and goals are unchanged. |

**Rationale:** every finding can be fixed with a story-level edit before the affected story starts. Fixing them now costs about an hour of document edits. Finding them during development would cost rework in the shared HUD (U2), a broken public link (Q1) or MVP metrics that can't be measured (G3).

**Timeline impact:** about +2 stories on a 35-story MVP (≈ +6%). There's no change to Epic 1's start.

### Design decisions made in this session

| ID | Decision |
|---|---|
| U1 | `scale_mode = fractional` with nearest filtering, plus a Fullscreen toggle (through `WebPlatform`) on the main menu |
| Q1 | Push to `main` or a PR runs tests and export only. A `v*` tag deploys. `available = true` for Horde Rush and Pitchfork Panic moves to 6.7 and 8.7 |
| U2 | Paragraph lines are ≥ 24 px. The 32 px minimum stays for letter and word targets. The HUD band stays at 104 px in every level |
| U4 | Music and Sound toggles also go on the pause panel |
| G7 | Passages are joined by a single typed Space |
| G2 | New Story 5.0, "MVP UI Art Pass" |
| G3 | Ctrl+Shift+E on the main menu downloads `save.json` (release-safe, invisible to kids), plus F9 in the debug overlay |
| U3 | "Layout sketch approved" ACs instead of a UX document |
| Q5 | 2.4 keeps the run lifecycle. The debug and replay extras become Story 2.10 (appended, so no renumbering) |
| G6 | Windows build smoke check added to 5.3 |

### Deferred (recorded, no edits)

- **G5:** auto-pause on focus loss in the Windows fallback build.
- The custom web boot splash (the default Godot splash stays for now).
- **Q14:** giving Epic 1 a player-facing title.
- **Q15:** Stories 1.8 and 5.2 are candidates to trim if the timeline gets tight.

## 4. Detailed Change Proposals

All of the following were approved one by one in Incremental mode.

### 4.1 GDD (`gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md`)

**GDD-1 · Art Style › Production · U1**
- OLD: `Logical resolution 640×360, scaled to the window by whole numbers where possible.`
- NEW: `Logical resolution 640×360, scaled to fill the browser window (fractional scaling with nearest-neighbor filtering, so pixels may be slightly uneven at non-whole sizes). A Fullscreen toggle on the main menu gives the biggest picture.`

**GDD-2 · Screens › Main Menu · U1**
- OLD: `…a Crypt Closet button, and Music/Sound toggles.`
- NEW: `…a Crypt Closet button, and Music, Sound and Fullscreen toggles.`

**GDD-3 · M3 Pause + Accessibility › Audio · U4**
- OLD (M3): `Options: Resume / Quit to Menu.` → NEW: `Options: Resume / Quit to Menu, plus the Music and Sound toggles.`
- OLD (Audio): `separate Music and Sound toggles, saved.` → NEW: `separate Music and Sound toggles on the main menu and the pause panel, saved.`

**GDD-4 · Accessibility › Readability · U2**
- OLD: `the target character or word is at least 32 px tall at the 640×360 logical resolution. UI text is at least 16 px.`
- NEW: `the target character or word (letter and word levels) is at least 32 px tall at the 640×360 logical resolution. Pitchfork Panic's 2-line paragraph text is at least 24 px, so both lines and the zombie hands fit the 104 px HUD band. UI text is at least 16 px.`

**GDD-5 · Level 3 › Text display · G7**
- OLD: `…Paragraphs flow continuously, and the next passage starts when one ends.`
- NEW: `…Passages are joined by a single Space: after the last character of a passage the kid types Space (both thumbs light), and the next passage starts on the next line. The joining Space counts as a typed key.`

**GDD-6 · `decision-log.md`:** append a "Course correction (2026-09-27)" entry recording GDD-1 to GDD-5, linked to the readiness report IDs.

### 4.2 Architecture (`game-architecture.md`)

**ARCH-1 · Scaling · U1**
- Project Initialization: `scale_mode = "integer"` → `scale_mode = "fractional"`, with the note: "nearest filtering keeps pixels sharp; slight unevenness at non-whole scales is accepted so 1366×768 laptops fill the window instead of rendering at 1×".
- Technical constraints: `integer scaling where possible` → `fractional scaling with nearest filtering, plus a fullscreen toggle`.
- Engine table › Rendering: `Pixel-perfect via viewport stretch + integer scale + nearest filtering` → `Pixel art via viewport stretch + fractional scale + nearest filtering`.
- Setup step 1: `integer` scale → `fractional` scale.

**ARCH-2 · CI and deploy · Q1**
- CI workflow: on each push to `main` and each PR, run download → import + GUT → Web export → upload as a workflow artifact (no deploy). On a `v*` tag, run the same steps and then deploy to GitHub Pages. Publishing is deliberate (`git tag vX.Y.Z && git push --tags`), so unfinished levels on `main` never reach kids.
- ADR-4 consequence, append: "Deploys run only from version tags, so the public link changes only on purpose."
- Summary, D9, the project tree comment and setup step 4: "→ Pages deploy" → "→ Pages deploy (tags only)".

**ARCH-3 · Web Platform · G1, U1, G3**
- `capture_keys` defaults to false. `RunFrame` sets it true in `_ready()` and false in `_exit_tree()` (the whole run, including pause and countdown; never in menus).
- `toggle_fullscreen()` / `is_fullscreen()` wrap `DisplayServer.window_set_mode`. On web they must be called from an input callback. The state is not saved.
- `offer_download(bytes: PackedByteArray, file_name: String)`: `JavaScriptBridge.download_buffer()` on web; on desktop it opens the `user://` folder with `OS.shell_open()`.

**ARCH-4 · PlayerData / SaveService APIs · G8, G3**
- The PlayerData mutation list gains `set_flag()` (plus the read-only `get_flag()`).
- `SaveService.export_json() -> String` returns the current save text. Only SaveService reads files; WebPlatform delivers the bytes.

**ARCH-5 · Debug tooling · G3**
- F9: export the save.
- Release-safe save export: Ctrl+Shift+E on the main menu downloads `zts-save-YYYYMMDD.json`. It's the only debug-style feature kept in release, and it's read-only.

### 4.3 Stories (`epics.md`)

#### Epic 1

**E1-1 · Story 1.1 › AC 1 · U1:** `scale mode integer` → `scale mode fractional`.

**E1-2 · Story 1.2 · Q1, U1**
- User story NEW: "I want every push to `main` to run the tests and export the web build, and every version tag to publish it to GitHub Pages, So that broken tests never ship and kids only ever see finished releases."
- AC 2 NEW: **When** a commit is pushed to `main` or a pull request is opened **Then** the workflow downloads Godot 4.7.2 headless and its export templates, imports the project, runs GUT, exports the Web preset and uploads it as a workflow artifact, without deploying **And** when a tag matching `v*` is pushed, the same steps run and the build is deployed to GitHub Pages **And** the hello-world is published by tagging `v0.0.1`.
- NEW AC: **Given** the deployed page in a maximised Chrome, Edge and Firefox window on a 1366×768 screen (or a dev-tools emulation of it) **When** the title screen is shown **Then** the game fills the available height with fractional scaling and nearest filtering, with no blurry pixels, and a screenshot per browser is kept in the story file.

**E1-3 · Story 1.3 · Q2**
- Title AC: `in a pixel font at 16 px or larger` → `in the project pixel font at 16 px or larger`.
- NEW AC (moved from 1.9): **Given** an SIL OFL pixel font in `assets/fonts/` with its license file **When** `l`, `I`, `1`, `O` and `0` are rendered at 16 px and 32 px **Then** each is clearly distinguishable (NFR7) **And** `data/ui_theme.tres` uses it as the default font and is set as the project's custom theme.

**E1-4 · Story 1.5 › new ACs · G1, U1, G3**
- **Given** `WebPlatform.capture_keys` **When** the game starts **Then** it is false, and only the keyboard test screen (here) and `RunFrame` (Story 2.4) set it to true.
- **Given** `WebPlatform.toggle_fullscreen()` called from a click or key handler **When** it runs on the web build in Chrome, Edge and Firefox **Then** the page enters and leaves browser fullscreen, `is_fullscreen()` reports it, and Esc (the browser's exit) is reflected the next time `is_fullscreen()` is called **And** the keyboard test screen gets a temporary Fullscreen button to prove it.
- **Given** `WebPlatform.offer_download(bytes, file_name)` **When** it is called on web **Then** the browser downloads the file; on desktop the `user://` folder opens.

**E1-5 · Story 1.6 › new AC · G3:** **Given** `SaveService.export_json()` **When** it is called **Then** it returns the current save as the same pretty-printed JSON that is written to `save.json`, without touching the file system.

**E1-6 · Story 1.8 · G3**
- Title → "Debug Overlay and Save Export". User story NEW: "…with frame timing, save status and a few cheats, plus a save export that also works in release, So that I can check performance, test saves quickly and pull playtest run history, without shipping cheats."
- AC 2 add: **And** F9 exports the save (as below).
- NEW AC: **Given** any build (debug or release) on the main menu (placeholder for now) **When** Ctrl+Shift+E is pressed **Then** `SaveService.export_json()` is passed to `WebPlatform.offer_download()` as `zts-save-YYYYMMDD.json`, and nothing on screen changes.
- AC 3: `F3/F5/F8 do nothing` → `F3/F5/F8/F9 do nothing, while Ctrl+Shift+E still works`.

**E1-7 · Story 1.9 · Q2, Q9**
- AC 2 NEW: **Given** the pixel font chosen in Story 1.3 **When** the style sheet is written **Then** it records the font, its sizes (16 px UI, 32 px targets, 24 px paragraph text) and license.
- AC 3 And NEW: "…no final art is produced until approval is given; placeholder art (plain shapes in palette colors) is allowed in any story before its final-art story (3.6, 4.3, 5.0)".

#### Epic 2

**E2-1 · Story 2.4: slimmed down · Q5, G1, Q12**
- AC 1: `(honouring debug_seed)` → `(seeded from the payload's optional seed, randomised otherwise)`.
- NEW AC: **Given** `RunFrame` enters the scene tree **When** the run screen is shown **Then** it sets `WebPlatform.capture_keys = true`, and sets it back to false in `_exit_tree()` (report card, quit to menu or a failed load) (FR29 key swallowing).
- AC 5 NEW: **Given** a `test_level` (registered in the level registry, not shown on the real menu) that displays the current letter from a `LetterBagSource` with a 2:00 `LevelConfig` **When** "Test level" is chosen on the placeholder menu (the button exists only in debug builds) **Then** a full run can be typed from start to end. The debug-overlay lines move to 2.10.
- Integration test AC add: "and `capture_keys` is true during the run and false after it".

**E2-2 · NEW Story 2.10: Run Debug Tools and Seed Replay · Q5**
As the developer, I want the debug overlay to show what the run is doing and to replay a run with a fixed seed, so that I can reproduce and diagnose typing bugs quickly.
- **Given** a debug build during a run **When** the overlay (F3) is open **Then** it also shows the run state, clock, current and next 3 targets, keys/errors/WPM and the run seed.
- **Given** the overlay **When** F6 is pressed during a run **Then** the run ends as if the clock ran out; F7 toggles verbose typing logs (`Log.debug` per judgment).
- **Given** a `debug_seed` set in the overlay **When** the next run starts **Then** `RunFrame` passes it as the payload `seed`, and the same inputs produce the same target sequence.
- **Given** a release export **When** it runs **Then** none of these fields or keys exist (gated by `OS.is_debug_build()`).

**E2-3 · Story 2.5 · U2, U3, Q7**
- NEW first AC: **Given** a layout sketch (ASCII or PNG) of the HUD band at 640×360 for letter, word and 2-line paragraph modes **When** it is reviewed **Then** Smuck approves it in the story file before the HUD is built.
- AC 1 add: **And** the target area's size comes from the target mode: 32 px for letter and word targets, and 2 lines of 24 px for paragraph mode, with the zombie hands below in every mode.
- AC 4 add: **And** `tests/unit/test_audio_manager.gd` covers the 150 ms wrong-key throttle with a fake clock.

**E2-4 · Story 2.7 › pause AC · U4:** the pause panel shows Resume, Quit to Menu, and Music and Sound toggles that work like the menu ones (bus mute plus `PlayerData.set_setting()`) (FR10, FR46).

**E2-5 · Story 2.9 › new first AC · U3:** **Given** a layout sketch of the report card at 640×360 (chalkboard stats, Professor Zombie, pet slot, "New best!" stamp spot, both buttons) **When** it is reviewed **Then** Smuck approves it in the story file before the screen is built, with every text at 16 px or more.

#### Epic 3

**E3-1 · Stories 3.1, 3.2, 3.3 · Q9:** NEW AC in each: **Given** the sprites this story needs **When** final art isn't ready yet **Then** placeholder sprites in palette colors are used; final frames arrive in Story 3.6. The 3.3 "party-hat zombie art … reviewed" AC moves to 3.6.

**E3-2 · Story 3.2 › voice AC · Q8, Q7:** "…`play_voice(&"vo_brainsss")` is requested; this story implements `play_voice()`, which drops any voice line within 8 s of the last one **And** `test_audio_manager.gd` covers the 8 s spacing with a fake clock."

**E3-3 · Story 3.7 · Q8, Q7**
- AC 1: "(this story implements `start_ambience()` and `stop_ambience()`)".
- AC 4 NEW: "Then the 3–8 s groan interval and the 2 s groan mute after a voice line pass (the throttle and voice tests live in 2.5 and 3.2)".

**E3-4 · Stories 3.6, 4.3, 5.1, 6.7 · Q13:** each subjective AC gets "…checked against a named manual checklist written in the story file (what to look for, pass/fail per item)".

#### Epic 4

**E4-1 · Story 4.1 › new AC · G8/Q11:** **Given** `PlayerData.set_flag(name: StringName, value: bool)` and `get_flag(name)` **When** a known flag (`welcome_bonus_claimed`, `tutorial_seen`, `placement_done`) is set **Then** it emits `flags_changed(name, value)` and requests a save **And** an unknown flag name logs `Log.error()` and changes nothing; the tests cover both cases.

**E4-2 · Story 4.2 · U1, U3, G3**
- NEW first AC: layout sketch of the main menu at 640×360 (logo, zombie with hat and pet, brain counter, 3 level cards, Closet button, Music/Sound/Fullscreen toggles), approved by Smuck before the screen is built.
- AC 1: `…and Music and Sound toggles (FR26)` → `…and Music, Sound and Fullscreen toggles (FR26)`.
- NEW AC: **Given** the Fullscreen toggle **When** it is clicked or selected with Enter **Then** `WebPlatform.toggle_fullscreen()` is called from that input and the toggle shows the current state.
- NEW AC: **Given** the real main menu **When** Ctrl+Shift+E is pressed **Then** the save export from Story 1.8 still works.

**E4-3 · Story 4.4 › new first AC · U3:** layout sketch of the Closet at 640×360 (two 3×3 grids with prices, tile states, preview zombie, brain counter, tutorial arrow positions), approved by Smuck before the screen is built, with every text at 16 px or more.

**E4-4 · Story 4.5 · G8, U5**
- AC 1: `sets the flag` → `calls PlayerData.set_flag(&"welcome_bonus_claimed", true)`.
- AC 2: `tutorial_seen is set` → `set_flag(&"tutorial_seen", true) is called`.
- NEW design note: after the first purchase, the way to play with the new hat is Closet → (Esc) Menu → level card. That's 2 steps, and it's deliberate for the MVP. A "Play with it!" button is a post-MVP idea if playtests show kids get lost.

#### Epic 5

**E5-1 · NEW Story 5.0: MVP UI Art Pass · G2/Q4**
As a kid, I want every screen to look as good as the zombie does, so that the whole game feels finished, not just the level.
- **Given** the GDD's MVP UI asset list **When** this story is done **Then** final art replaces the placeholders for: title logo; 3 level cards (2 with a "Coming soon" sign); HUD band frame; zombie hands (2 hands, 10 finger-glow states with pulsing outline, f/j bumps); chalkboard report card and "New best!" stamp; Closet grid tiles, the locked "?" silhouette and all 5 tile states; buttons (normal/focus/pressed); the brain icon; the Welcome Gift card; the pause panel; and the Music/Sound/Fullscreen toggle icons.
- **Given** every asset **When** it is checked against the style sheet from Story 1.9 **Then** it uses only palette colors, the 1 px outline rule and the pixel font, and matches the approved layout sketches from 2.5, 2.9, 4.2 and 4.4.
- **Given** the zombie hands and HUD in grayscale **When** they are reviewed **Then** the active finger is still clear without color (NFR8).
- **Given** the new art in game **When** the MVP flow is walked end to end **Then** no screen still shows placeholder art, and Smuck records approval in the story file.
- Epic 5's summary line gets "UI art pass" added at the front.

**E5-2 · Story 5.1 › new AC · G4:** **Given** the screens and runs **When** they are entered **Then** the menu loop plays on the title, menu, Closet, Welcome Gift and report card; the Zombie Run loop plays during a run (paused runs keep it at a lower volume); and switching between them is a 0.5 s crossfade, with the same loop never restarting when it's already playing.

**E5-3 · Story 5.3 › new ACs · G1, U1, G6**
- **Given** a real Zombie Run in Chrome and Firefox **When** Space, `'`, `/`, Backspace and Tab are pressed during a run and while paused **Then** the page never scrolls and quick-find never opens; in the menu afterwards, normal browser keys work again.
- **Given** the target laptop's 1366×768 screen **When** the game runs windowed and in fullscreen **Then** it fills the window, and the 16 px text is readable from a normal seating distance (a note per browser goes in the story file).
- **Given** the Windows Desktop export **When** it is run on one Windows PC **Then** it starts, plays a Zombie Run and keeps its save across a restart (NFR8 fallback smoke check).

**E5-4 · Story 5.4 › AC 1 · G3/Q3:** `And the notes record accuracy from saved run history…` → `And after the session the save is exported with Ctrl+Shift+E, and the notes record accuracy from its run history…`

**E5-5 · Story 5.5 › publish AC · Q1:** `the version is tagged in git` → `the release is published by pushing the v1.0.0 tag (the CI deploys only from tags)`.

#### Post-MVP

**E6-1 · Stories 6.3/6.7 and 8.3/8.7 · Q1**
- 6.3 AC 1: register with `available = false` (the menu still shows "Coming soon"); runs start from the debug "Test level" menu with `level_id = &"horde_rush"`.
- 6.7 NEW last AC: **Given** tuning is done and the kid playtest passed **When** `horde_rush.available` is set to true **Then** the menu card is selectable, and the next version tag publishes it.
- 8.3 and 8.7: the same change for `pitchfork_panic`.

**E7-1 · Story 7.1 › last AC · Q3:** `Given saved run history from MVP play` → `Given run history exported (Ctrl+Shift+E) from the playtest saves`.

**E8-1 · Story 8.2 › AC 1 · G7, U2:** add: **And** paragraph lines are at least 24 px tall and both lines plus the zombie hands fit in the 104 px band **And** passages are joined by a single Space: the last line ends with a visible space marker, typing Space starts the next passage, and that Space counts as a typed key.

**E11-1 · Story 11.3 + Epics 7/8 · Q10**
- 11.3: "…every profile field that exists at the time (brains, items, flags, settings, bests, history, and tier and used passages if Epics 7 and 8 have landed) stays separate per profile".
- Epics 7 and 8 summary, add: "New save fields go inside the profile, never at the top level, so Epic 11 needs no migration."

## 5. Implementation Handoff

**Scope: Moderate.** These are document edits only, with no code impact yet. They add 2 stories and reorganise the backlog (one split), before sprint planning.

| Role | Responsibility |
|---|---|
| **Developer agent (this session or `gds-quick-dev`)** | Apply all approved edits above to `gdd.md`, `decision-log.md`, `game-architecture.md` and `epics.md`. Update the FR coverage map in `epics.md` for 2.10 and 5.0. |
| **Scrum Master (`gds-sprint-planning`)** | Generate `sprint-status.yaml` from the updated `epics.md`, including `2-10-run-debug-tools-and-seed-replay` and `5-0-mvp-ui-art-pass`. No existing status file needs to be migrated. |
| **Smuck** | Approve the layout sketches (2.5, 2.9, 4.2, 4.4) and art (1.9, 3.6, 4.3, 5.0) when those stories run. Publish releases by pushing a `v*` tag. |

### Success criteria

- All 40 approved edits appear in the four documents, with no leftover wording like "integer", "deploys every push", "honouring debug_seed" or "F3/F5/F8 do nothing".
- The G1, G2, G3 and G8 gaps each have an owning story, and Q2 has no forward dependency left.
- `gds-sprint-planning` runs cleanly and lists 2.10 and 5.0.
- Optional: a re-run of `gds-check-implementation-readiness` rates the plan READY.
