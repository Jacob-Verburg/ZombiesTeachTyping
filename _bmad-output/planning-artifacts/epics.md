---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md
  - _bmad-output/game-architecture.md
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/decision-log.md
---

# zombies-teach-typing - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for zombies-teach-typing, decomposing the requirements from the GDD, UX Design if it exists, and Architecture requirements into implementable stories.

The GDD's epic sketch (`gdds/.../gdd-epics-overview.md`, 11 epics, MVP = Epics 1–5) is used as the skeleton. Each requirement is tagged **[MVP]** or **[Post-MVP]**.

## Requirements Inventory

### Functional Requirements

**Typing input & judgment (M1)**

- FR1 [MVP]: Exactly one active target character exists at any time. A correct key is accepted with zero delay and the next target character becomes active in the same frame; feedback (animation, sound) plays concurrently and never limits typing speed (overlapping or skipped animations allowed at 5+ keys/s).
- FR2 [MVP]: A wrong printable key causes no progress and no world change, adds 1 to Errors, plays a soft "bonk" tick (at most 1 per 150 ms) and shakes the target character for 0.2 s. There is no other penalty.
- FR3 [MVP]: Ignored keys are never errors: Shift (except as part of a capital), Ctrl, Alt, Meta, arrows, function keys, Tab, Backspace, Enter, Caps Lock; key-repeat (echo) events; events with no printable character (dead keys, IME composition). In Zombie Run and Horde Rush, Space is also ignored.
- FR4 [MVP]: Matching uses the typed character, not the physical key. Zombie Run and Horde Rush are lowercase-only and accept a letter regardless of Caps Lock or Shift; Pitchfork Panic is case-sensitive and treats Space as input.
- FR5 [MVP]: A "Caps Lock is on" hint appears after 3 consecutive capital letters in a lowercase level and hides on the next lowercase letter.
- FR6 [MVP]: The run timer starts on the first correct keystroke, not on scene load. Before that, the HUD shows the first target and the label "Type the letter to start!" (or "word" / "text").

**Stats (M2)**

- FR7 [MVP]: The run computes Keys Typed (correct keystrokes; a capital counts as 1), Errors (wrong printable keystrokes), Accuracy (Keys ÷ (Keys + Errors), whole %), WPM ((Keys ÷ 5) ÷ run minutes, whole number; Horde Rush adds +1 per completed word for the implied space), Lesson Time (first correct key to end, m:ss) and Brains (including bonuses, shown as a separate "+N bonus" line).
- FR8 [MVP]: Live HUD WPM updates once per second and is shown only after 5 s of run time.
- FR9 [MVP]: For every expected character, the run records attempts, errors and what was typed instead (e.g. expected `f`: 14 attempts, 3 errors, `g`×2, `d`×1). This is saved but never shown to the kid in the MVP.

**Pause (M3) and quitting**

- FR10 [MVP]: Esc or the pause button pauses the run: the timer stops and the world freezes. The pause panel offers Resume, Quit to Menu, and the Music and Sound toggles.
- FR11 [MVP]: The run auto-pauses when the browser tab or window loses focus.
- FR12 [MVP]: Resuming shows a 3-2-1 countdown (0.5 s per number); typing input is rejected until it finishes, and focus loss during the countdown returns to the paused state.
- FR13 [MVP]: Quitting mid-run keeps brains already collected, awards no completion bonus, and does not record the run in stats history.

**Shared HUD (M2b) and finger guide**

- FR14 [MVP]: The bottom band (104 px of 360) holds, left to right: the pet slot; the target area (letter, word or 2-line text window, always in the same spot) with the zombie hands below it; and a stats column with Timer, Keys Typed, WPM and Errors. A pause button sits in the top-right of the playfield. A brain counter beside the stats shows this run's brains in every level.
- FR15 [MVP]: Two cartoon green zombie hands show the finger for the next character with a brighter green plus a pulsing outline, and the highlight moves along as words and paragraphs are typed.
- FR16 [MVP]: The finger map follows the GDD touch-typing table (left/right pinky, ring, middle, index; Space on both thumbs).
- FR17 [MVP]: For capitals and shifted symbols, the character's finger and the opposite hand's pinky (Shift) both light.
- FR18 [MVP]: The `f` and `j` fingertips show a small bump mark at all times.

**Report card**

- FR19 [MVP]: After every run, a chalkboard report card shows Keys Typed, Errors, WPM, Accuracy, Lesson Time and Brains Collected (+ bonus line). Professor Zombie (the player's zombie in cap and gown, wearing the hat, with the pet) points at the board. Buttons: Play Again and Menu.
- FR20 [MVP]: A "New best!" stamp appears when a run beats that level's best WPM (not on the first run of a level).
- FR21 [MVP]: On the report card, Enter = Play Again and Esc = Menu; both keys are ignored for the first 1.0 s to stop mash-through.
- FR22 [MVP]: A completed run is appended to run history (capped at the newest 500 runs) and the level's best WPM is updated.

**Screens & flow**

- FR23 [MVP]: The title screen says "Click or press any key"; any key or click advances to the main menu and unlocks browser audio.
- FR24 [MVP]: Flow: Title → Main Menu → Level → Report Card → (Welcome Gift → Crypt Closet, first completed run only) → Play Again (same level) or Menu. The Crypt Closet is also reachable from the main menu.
- FR25 [MVP]: In menus and the Closet, arrow keys move focus, Enter selects and Esc goes back; mouse clicks also work.
- FR26 [MVP]: The main menu shows the title logo, the player's zombie wearing the equipped hat with the pet beside it, the brain counter, 3 level cards, a Crypt Closet button, and Music, Sound and Fullscreen toggles. In the MVP, Horde Rush and Pitchfork Panic cards show a "Coming soon" sign and cannot be selected. "Coming soon" (driven by `available = false`) always takes precedence over Locked (FR79).
- FR27 [MVP]: If browser storage is not persistent, the main menu shows a small plain-words notice: "Progress may not be saved in this browser mode".

**Zombie Run (Level 1)**

- FR28 [MVP]: A Zombie Run lasts 2:00 and uses single lowercase letters, with all 26 letters in play in the MVP.
- FR29 [MVP]: Letters are drawn from a shuffled bag: every letter appears once before any repeat, and the same letter never appears twice in a row across bag boundaries.
- FR30 [MVP]: Targets are spaced 48 px apart and the next 3 are visible, each showing its letter. The active target bobs, has a down-arrow marker, and matches the HUD target.
- FR31 [MVP]: While waiting, the zombie ambles forward at 24 px/s and idles 24 px before the active target. On a correct key, the target resolves instantly and the zombie scoots to the next approach point in 0.15 s; scoots chain, so walking never caps typing speed. Targets never scroll away.
- FR32 [MVP]: In each group of 4 targets, 1 is a brain block and 3 are villagers, shuffled per group.
- FR33 [MVP]: Brain block (floating 48 px above ground): correct key → the zombie hops (0.35 s) and bonks it → a brain pops out (+1 brain), with a 20% chance of a "Brainsss…" voice line.
- FR34 [MVP]: Villager (standing, waving): correct key → the zombie hugs (0.4 s) → the villager poofs into a party-hat zombie that joins the conga line.
- FR35 [MVP]: The conga line trails the zombie in a bobbing line, draws at most 12 followers, shows a "×N" badge on the last follower beyond that, and never shrinks during a run.
- FR36 [MVP]: At 0:00, input stops, the zombie and conga line dance for 2.0 s, a +10 completion bonus is awarded, and the report card appears.
- FR37 [MVP]: Zombie Run uses the Sunny Village Green backdrop (sky, far layer, near layer, ground tiles).

**Brains, Crypt Closet and cosmetics (M4, M5)**

- FR38 [MVP]: Brains are the single currency, spent only on cosmetics; brains never gate learning content (level order is the only gate, FR79). Brains persist in the save and are never lost. In-run brains are committed at run end or quit.
- FR39 [MVP]: The Crypt Closet shows a 3×3 hat grid and a 3×3 pet grid (row prices 100 / 200 / 300), the brain counter, and a preview of the zombie wearing the selected item.
- FR40 [MVP]: Each Closet item shows one state: Locked (coming soon), Can't afford ("Need N more"), Buy, Wear, or Wearing (click to take off).
- FR41 [MVP]: Buying goes Buy → confirm → owned (brains deducted); Wear equips it. Purchases and equips are saved immediately. Items are never sold back.
- FR42 [MVP]: In the MVP, only the Pumpkin hat and Cute ghost (100 brains each) are live; the other 16 slots show a locked "?" silhouette labeled "Coming soon".
- FR43 [MVP]: There is 1 hat slot and 1 pet slot, either of which can be empty. The hat is drawn on the zombie in every level (and on every pose), on the main menu, on Professor Zombie and (post-MVP) on all Horde Rush copies. The pet sits in the HUD next to the target with an idle animation and also appears on the report card and main menu.
- FR44 [MVP]: After the first completed run ever, the report card is followed by a "Welcome gift!" card: +100 brains, with one button, "Open the Crypt Closet". It is given once per save.
- FR45 [MVP]: On that first Closet visit, an arrow points at the first affordable item → Buy → confirm → Wear. The guide ends when the first item is worn or when the kid leaves the Closet, and is shown once per save.

**Audio & settings**

- FR46 [MVP]: Separate Music and Sound toggles (main menu and pause panel) are saved, and the game is fully playable muted.
- FR47 [MVP]: No audio plays before the first key or click on the title screen.
- FR48 [MVP]: Zombie groans play at random every 3–8 s during a run (never on every keypress) and are muted within 2 s of a voice line; voice lines are at least 8 s apart.
- FR49 [MVP]: Music: one menu loop and one loop per level (Zombie Run calm loop in the MVP), each 60–120 s.
- FR50 [MVP]: The MVP SFX set is brain bonk, hug-poof, wrong-key tick, purchase jingle, report card chalk-scratch and chime, and UI click, plus 4 groans and 2 "Brainsss" lines.

**Save**

- FR51 [MVP]: The save holds brains; owned items; equipped hat and pet; welcome-bonus-claimed, tutorial-seen and placement-done flags; tier (post-MVP); settings (music, sound); per-level best WPM; and run history (last 500 runs: date/time, level, duration, keys typed, errors, WPM, accuracy, brains earned, letter pool or tier, per-key attempts and errors, end reason).
- FR52 [MVP]: The save is written at run end, on quitting a run (brains only), after each purchase or equip, on settings changes, and when the tab is hidden or the window is closed.

**Horde Rush (Level 2)**

- FR53 [Post-MVP]: Horde Rush lasts 5:00 on a 5-lane field, with zombies entering at the left and the defended house at the right edge.
- FR54 [Post-MVP]: One lowercase word is shown at the bottom; typed letters turn green and the next letter is underlined. The word completes on its last letter (no Space), a zombie copy of the player (wearing the hat) spawns in a random lane, and the next word appears instantly.
- FR55 [Post-MVP]: Size classes by word length: ≤3 small (8 s crossing, 1 hit, 1 brain); 4–5 medium (10 s, 2 hits, 2 brains); ≥6 big brute (13 s, 3 hits, 3 brains).
- FR56 [Post-MVP]: The defender paces 1 lane per 0.6 s, reversing at the edges, and throws at the front-most zombie in its lane (0.8 s cooldown, 1.0 s projectile travel). A hit flashes the zombie red for 0.15 s; the final hit makes it fall and melt over 0.6 s.
- FR57 [Post-MVP]: A zombie that reaches the house shuffles in, triggers a throttled "Brainsss" and pops its brains. A +25 completion bonus is awarded at 5:00.
- FR58 [Post-MVP]: House + defender pairs use food and toys only, never guns: Farmhouse + Farmer (tomatoes) at launch; Castle + Knight (suction-cup darts) and Beach Hut + Lifeguard (water balloons) later.
- FR59 [Post-MVP]: Before adaptive difficulty exists, Horde Rush uses a fixed 3–5 letter word band from a tagged starter list, and its menu card is enabled.

**Adaptive curriculum**

- FR60 [Post-MVP]: The input signal is the rolling average WPM of the most recent 1–5 completed runs across all levels (quit runs excluded). The kid never sees the value or the tier.
- FR61 [Post-MVP]: A save's first Zombie Run is a placement run with all 26 letters; its WPM sets the starting tier.
- FR62 [Post-MVP]: Five tiers (<8, 8–14, 15–21, 22–29, 30+ WPM) scope keys in play (home → +top → all), Horde Rush word length (2–3, 3–4, 3–5, 4–6, 5–8) and Pitchfork Panic text richness per the GDD table.
- FR63 [Post-MVP]: A tier rises as soon as the average reaches the next floor and drops only when the average falls 2 WPM below the current floor. Comparisons use the unrounded average, and a drop can skip tiers to the tier whose range contains the average.
- FR64 [Post-MVP]: Zombie Run's letter pool follows the tier's rows (tiers 3–5 use all 26). Pacing, the defender and the mob never scale.

**Content**

- FR65 [Post-MVP]: A master list of about 1,500 kid-safe lowercase words (no scary, violent, rude or brand words), cross-checked against Dolch sight words and reviewed once by Smuck.
- FR66 [Post-MVP]: Words are tagged offline by rows needed and length; a tier's pool is words using only its rows within its length band. The tier 1 pool has at least 40 home-row words of 2–3 letters.
- FR67 [Post-MVP]: About 40 original goofy paragraphs (2–4 sentences, 150–400 characters) tagged tiers 3–5 (about 13 each); tiers 1–2 generate 4–7-word sentences at runtime from the tier word pool, with a capital first letter and end punctuation.
- FR68 [Post-MVP]: No passage repeats until every passage in its tier has been used (tracked per save).

**Pitchfork Panic (Level 3)**

- FR69 [Post-MVP]: The target area shows a 2-line text window: typed characters green, the next character underlined, the next line dimmed. Passages flow continuously, joined by a single typed Space.
- FR70 [Post-MVP]: Each correct character moves the zombie 1 step. The mob starts 15 steps behind at 4 WPM-eq (1 WPM-eq = 5 steps/min) and gains +1 WPM-eq every 10 s.
- FR71 [Post-MVP]: The camera keeps the zombie at 60% of screen width; the mob's distance is always readable and the mob is on screen once the gap is under 20 steps.
- FR72 [Post-MVP]: Brain pickups are placed every 10–30 steps (uniform random from the previous pickup) and give 5 brains each.
- FR73 [Post-MVP]: Caught: input stops → dust cloud (1.5 s) → dazed zombie with stars and "Got you!" (1.0 s) → fade (0.5 s) → report card; brains kept. Escaped! at 5:00: dive through a hedge/gate/bush (1.5 s) → "Escaped!" → report card with +25. Every finished run gets +10.
- FR74 [Post-MVP]: Chase settings: Moonlit Village at launch; Cornfield Path and Spooky Forest Bridge later. Its menu card is enabled.

**Full Closet, variety, trends, profiles**

- FR75 [Post-MVP]: All 18 cosmetics from the GDD catalogue are purchasable at their row prices, with hats fit-checked on every pose and every Horde Rush size class.
- FR76 [Post-MVP]: Each level has 3 art themes and picks one at random per run, never repeating the previous theme. Rules never change with the theme.
- FR77 [Post-MVP]: A trends screen shows WPM, accuracy and practice time over recent runs, plus lifetime totals (keys typed, best WPM, total brains, time practiced).
- FR78 [Post-MVP]: A "Who's playing?" picker lets kids create a named zombie (plain-word, length-limited). Each zombie has its own brains, cosmetics, run history and tier, and its name shows on the menu and report card. The MVP save becomes the first profile.
- FR79 [Post-MVP]: A level after the first is **Locked** until the previous level has one run that ended because its timer reached 0:00 (Horde Rush ← Zombie Run; Pitchfork Panic ← Horde Rush). Quit runs never unlock. An unlock is saved permanently, not worked out from the 500-run history. A Locked card shows only a padlock; while the card has focus, a hint sign below it names the level to finish, and Enter or a click on it only makes the card wiggle. The first time the menu is shown after an unlock, a one-time unlock moment plays: the padlock pops off, the tint clears, a "New!" badge appears and focus moves to the card. Input stays live, so any key finishes the animation instantly. The "New!" badge stays until the card is chosen the first time. (UX D12, D14; EXPERIENCE.md Level Unlocks)

### NonFunctional Requirements

- NFR1 (Performance): A steady 60 FPS in desktop Chrome, Edge and Firefox on a 2018-era family laptop with integrated graphics. MVP check: a full 2:00 Zombie Run with 12 conga followers drawn, with no frame over 33 ms. Post-MVP: the same over a full Horde Rush run, plus a 30-zombie stress scene.
- NFR2 (Latency): A correct keystroke produces visible feedback (target advance plus effect start) on the next rendered frame (≤ 17 ms at 60 FPS).
- NFR3 (Load): First load to the title screen ≤ 10 s on 25 Mbit/s; cached repeat load ≤ 3 s. The 10 s load time is the governing rule; total compressed download ≤ 40 MB is a check measured in Epic 1 (hard cap 500 MB).
- NFR4 (Save integrity): Zero data loss across 10 consecutive browser reloads and 10 tab closes mid-menu, on Chrome and Firefox.
- NFR5 (Platform): The HTML5 build runs on plain static hosting with no special server headers (single-threaded). Desktop Chrome, Edge and Firefox are supported; Safari is best-effort; mobile and touch are unsupported. Windows desktop is a fallback with the same save contents.
- NFR6 (Hardware/layout): A physical keyboard is required. The finger guide assumes US QWERTY; other layouts can play because matching is by character.
- NFR7 (Readability): The target character or word (letter and word levels) is at least 32 px tall, Pitchfork Panic paragraph text at least 24 px, and UI text at least 16 px at the 640×360 logical resolution. The pixel font clearly distinguishes `l`/`I`/`1` and `O`/`0`.
- NFR8 (Color accessibility): Finger and typed-text states use brightness plus shape or underline, never color alone.
- NFR9 (Reading level): All UI text uses words a 6-year-old can read. Zombie slang appears only in voice and flavor, never in menu labels. The player never sees technical error text.
- NFR10 (Tone): Kid-safe cartoon only — no gore, blood or body-part gags, no guns; defeat is melting, dust clouds or dizzy stars. Goofy, never scary for a 6-year-old, never babyish for a 13-year-old. No difficulty labels, ranks or "easy mode" anywhere.
- NFR11 (Pressure): No timers outside runs (menus, report card, Closet). Session target 5–15 minutes; the longest run is 5:00.
- NFR12 (Privacy): No network, accounts, cloud saves or analytics. No personal data is logged.
- NFR13 (Art standard): 640×360 logical, fractional scaling with nearest filtering plus a fullscreen toggle; one shared palette of at most 32 colors; characters 32×32 (brutes 48×48), tiles 16×16, 1 px dark outline on characters and props; animations 2–6 frames at 8–12 fps; nearest-neighbour filtering. The palette, zombie and one villager are approved before any other art is produced.
- NFR14 (Audio mix): Music is mixed below SFX; audio uses CC0-style free sources or self-recorded voice lines.
- NFR15 (Economy parity): Every level pays within ±20% of Zombie Run's brains per minute at the same WPM.
- NFR16 (Robustness): Errors never pause the game; a missing sound, sprite or cosmetic never stops a run; a failed screen load returns to the main menu with brains kept.
- NFR17 (Reach): The MVP link loads and plays on at least 3 different family computers without help.

### Additional Requirements

**Project setup (no starter template; the existing Godot project is used — affects Epic 1 Story 1)**

- Fix `project.godot`: 640×360 viewport; stretch mode `viewport`, aspect `keep`, scale mode `fractional`; default canvas texture filter Nearest; `snap_2d_transforms_to_pixel = true`; remove the `[dotnet]` section; set `debug/gdscript/warnings/untyped_declaration = Error`.
- Godot 4.7.2 (standard build), Compatibility renderer, GDScript only.
- Export presets: Web (Thread Support off, no PWA, VRAM compression desktop only) and Windows Desktop, both excluding `addons/gut/*`, `tests/*`, `tools/*`, `docs/*`, `_bmad/*`, `_bmad-output/*`, `build/*`.
- Create the folder skeleton (hybrid: `scenes/`, `scripts/`, `data/`, `assets/` with mirrored feature folders), `Log` (static class) and `GameConstants`.

**Build, hosting & CI**

- Host on GitHub Pages from a public repository, deployed by GitHub Actions (ADR-4; resolves GDD assumption A2).
- `.github/workflows/build.yml` on push to `main` and PRs: download Godot 4.7.2 headless + templates → headless import → run GUT (fail on any failure) → export Web → upload as a workflow artifact; on a `v*` tag, the same steps plus deploy to Pages. Pin and verify current major versions of `actions/checkout`, `actions/upload-pages-artifact`, `actions/deploy-pages`.
- Record compressed transfer size and first-load time in Epic 1; if over 10 s, backlog a custom export template with 3D disabled.
- Verify whether `rename` is reliable on the web file system; if not, switch the save to direct write plus backup.
- Verify whether the Godot canvas already prevents browser defaults for Space, `'`, `/`, Backspace and Tab; if not, `WebPlatform` installs a JS `keydown` listener that calls `preventDefault()` while `capture_keys = true`.

**Testing**

- GUT 9.7.1 in `addons/gut`; tests in `tests/unit/` and `tests/integration/`, fixtures in `tests/fixtures/saves/`.
- Must be unit-tested: `TypingInput` filtering (synthetic `InputEventKey`s), `TypingSession` judgment and case rules, stats/WPM formulas, `LetterBagSource` (no immediate repeats across bags), brain-block group shuffle, economy awards, `PlayerData` wallet and purchase rules, save migration and defaults (fixture per migration), `FingerMap` (26 letters, `A`, `J`, Space), tier hysteresis (Epic 7).
- Every class in `scripts/typing/`, `scripts/core/` and `player_data.gd` has a `tests/unit/test_*.gd`. Feel, timing, audio mix and readability are playtested manually with checklists in story files.

**Core architecture**

- Five autoloads registered in order `WebPlatform → SaveService → PlayerData → AudioManager → Router`; an autoload may only use earlier ones in `_ready()`. No global EventBus (ADR-5); typed, past-tense signals connected in code.
- `Router`: `enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }`, `go(screen, payload)` / `take_payload()`, `change_scene_to_packed` with a CanvasLayer fade.
- Typing pipeline (ADR-1): `TypingInput` (Node) → `TypingSession` (RefCounted, pure) → `RunFrame` → level extending `LevelBase`. `TargetSource` interface (`peek`, `current`, `advance`) with `LetterBagSource` (MVP), `WordSource` (Epic 6), `ParagraphSource` (Epic 8). Levels never read input, never touch the clock, never write `PlayerData`.
- `TypingInput` is configured from `LevelConfig` (`case_sensitive`, `space_is_input`) and emits `caps_lock_suspected` / `caps_lock_cleared`.
- `RunFrame` state machine: `WAITING_FIRST_KEY → RUNNING ⇄ PAUSED → COUNTDOWN → RUNNING … → ENDING → DONE`, all transitions via `_set_state()`. The tree stays paused through `COUNTDOWN` and is unpaused only on entering `RUNNING`. `RunClock` accumulates `delta` only while running.
- "Logic leads, visuals chase": logical state updates synchronously in the typing callback; one retargeting tween per moving actor; one-shot effects are self-freeing; never `await` in typing callbacks.
- One `RandomNumberGenerator` per run, injected into the target source and level; a `debug_seed` from the debug overlay is passed as the run payload's `seed` for replay (Story 2.10). No global `randi()`/`randf()` in gameplay.

**Data**

- Save (ADR-2/3): JSON at `user://save.json`, `schema_version` 1, profile-shaped (`profiles` map, one profile in the MVP). Atomic write (`save.tmp` → rename, keep `save.bak`), fall back to `.bak` on parse failure, fill missing fields from defaults, keep unknown fields, ordered `migrate_N_to_N1` functions. `SaveService.request_save()` coalesces same-frame requests; `visibility_hidden` and close requests write immediately. Only `SaveService` touches files; only `PlayerData` mutates profile state (emits `brains_changed`, `equipment_changed`, etc.).
- Static data as typed Resources in `res://data/`: `CosmeticItem`, `Catalogue`, `FingerMap`, `LevelConfig`, `LevelRegistry`, `EconomyConfig`, `SpriteAnchors`, `AudioLibrary`. No GDD gameplay number appears as a literal in a script.
- Post-MVP generated content as JSON in `res://data/content/`, produced by a headless GDScript tool (`tools/tag_words.gd`) with a pool validation report.

**Platform, audio, cosmetics**

- `WebPlatform` is the only code using `JavaScriptBridge` / `OS.has_feature("web")`: emits `focus_lost` and `visibility_hidden`, owns key swallowing, exposes `is_storage_persistent()`; no-op on desktop.
- `AudioManager`: `Master → Music / SFX` buses (no bus effects), pool of 8 SFX players plus one music player, all throttling centralized, `unlock()` called from the title input callback. OGG for music, 16-bit WAV for SFX.
- Cosmetics: `HatSlot` follows `SpriteAnchors.head[animation][frame]` on `frame_changed` (Professor Zombie has its own anchor set; Horde Rush reuses anchors via scale). `PetSlot` in HUD and report card instances the pet's idle `SpriteFrames`. Both update from `PlayerData.equipment_changed`.

**Cross-cutting**

- Error handling: return `Error` codes / nullable lookups; `assert` only for contract violations (debug); recover silently to a safe state.
- Logging: `[LEVEL][tag] message` via `Log`; no logging in `_process`; per-keystroke logs DEBUG-only behind `Log.verbose_typing`.
- Debug tools (debug builds only): F3 overlay (FPS/worst frame, run state and clock, current + next 3 targets, keys/errors/WPM, RNG seed, save status); cheat keys F5 (+100 brains), F6 (end run), F7 (verbose typing logs), F8 (reset save with confirm).
- Entities: `preload`ed scenes, `setup()` before `add_child`, `queue_free()` off-screen; no pooling unless profiling demands it; Zombie Run keeps at most active + next 3 targets.
- Naming and file conventions per the architecture (snake_case files, mirrored scene/script paths, `hat_`/`pet_`/`sfx_`/`mus_`/`vo_` prefixes, StringName IDs).
- A new level extends `LevelBase`, lives in `scenes/levels/<id>/` + `scripts/levels/<id>/`, and is registered in `level_registry.tres`.

### UX Design Requirements

The UX spines in `ux-designs/ux-zombies-teach-typing-2026-09-27/` (called `UX/` below) are the visual and interaction contract for every screen: `UX/DESIGN.md` (look: palette, typography, components, layout) and `UX/EXPERIENCE.md` (behaviour: flows, states, input, Level Unlocks). Key-screen mocks: `UX/mockups/key-main-menu.html`, `key-run-hud.html`, `key-report-card.html`. On any conflict, spines > mocks > layout sketches. FRs stay the testable requirements; the spines say how they look and behave.

### FR Coverage Map

FR1: Epic 2 - One active target, instant accept, non-blocking feedback
FR2: Epic 2 - Wrong key: no progress, error +1, tick, 0.2 s shake
FR3: Epic 2 - Ignored keys, echo, non-printable events
FR4: Epic 2 - Character matching and per-level case/Space rules
FR5: Epic 2 - Caps Lock hint
FR6: Epic 2 - Timer starts on first correct key; start prompt
FR7: Epic 2 - Stats definitions
FR8: Epic 2 - Live WPM after 5 s, 1 Hz updates
FR9: Epic 2 - Per-key attempts/errors/mistypes
FR10: Epic 2 - Esc / pause button pause with Resume and Quit
FR11: Epic 2 - Auto-pause on focus loss
FR12: Epic 2 - 3-2-1 resume countdown
FR13: Epic 2 - Quit keeps brains, no bonus, not recorded
FR14: Epic 2 - Shared bottom HUD layout
FR15: Epic 2 - Zombie hands next-finger glow
FR16: Epic 2 - Finger map table
FR17: Epic 2 - Shift pairing for capitals/symbols
FR18: Epic 2 - f/j bumps
FR19: Epic 2 - Chalkboard report card with Professor Zombie
FR20: Epic 2 - "New best!" stamp
FR21: Epic 2 - Report card keys with 1.0 s guard
FR22: Epic 2 - Run history (500 cap) and best WPM
FR23: Epic 1 - Title screen, any key/click, audio unlock
FR24: Epic 1 (skeleton) / Epic 4 (full flow incl. Welcome Gift and Closet) - Screen flow
FR25: Epic 4 - Menu/Closet keyboard and mouse navigation
FR26: Epic 4 - Main menu contents and "Coming soon" cards
FR27: Epic 1 - Storage-not-persistent notice
FR28: Epic 3 - 2:00 run, 26 lowercase letters
FR29: Epic 2 (LetterBagSource, Story 2.2) / Epic 3 (used by Zombie Run) - Letter bag with no immediate repeats
FR30: Epic 3 - Target spacing, 3 visible, active marker
FR31: Epic 3 - Amble / idle / chained scoot movement
FR32: Epic 3 - 1-in-4 brain block group shuffle
FR33: Epic 3 - Brain block hop, bonk, +1, Brainsss chance
FR34: Epic 3 - Villager hug, poof, party-hat zombie
FR35: Epic 3 - Conga line with 12 cap and ×N badge
FR36: Epic 3 - End dance, +10 bonus, report card
FR37: Epic 3 - Sunny Village Green backdrop
FR38: Epic 4 - Brains currency rules and commit points
FR39: Epic 4 - Closet grids, prices, counter, preview
FR40: Epic 4 - Closet item states
FR41: Epic 4 - Buy/confirm/wear/take off, saved immediately
FR42: Epic 4 - MVP live items + 16 "Coming soon"
FR43: Epic 4 - Hat and pet slots shown everywhere
FR44: Epic 4 - Welcome gift +100 once
FR45: Epic 4 - Guided first purchase once
FR46: Epic 4 - Music/Sound toggles saved
FR47: Epic 1 - No audio before first input
FR48: Epic 3 - Groan ambience and voice spacing
FR49: Epic 5 - Menu and Zombie Run music loops
FR50: Epic 5 - MVP SFX and voice set
FR51: Epic 1 - Save contents and schema
FR52: Epic 1 - Save points (hooks); exercised by Epics 2 and 4
FR53: Epic 6 - 5:00, 5-lane field
FR54: Epic 6 - Word display, completion, spawn copy
FR55: Epic 6 - Size classes
FR56: Epic 6 - Defender pacing, throws, flash, melt
FR57: Epic 6 - Arrival brains and +25 bonus
FR58: Epic 6 - Farmhouse + Farmer pair (other pairs in Epic 10)
FR59: Epic 6 - Fixed 3-5 band from tagged starter list; card enabled
FR60: Epic 7 - Rolling WPM average
FR61: Epic 7 - Placement run
FR62: Epic 7 - 5-tier table
FR63: Epic 7 - Hysteresis and multi-tier drops
FR64: Epic 7 - Zombie Run pool follows tier; no pacing scaling
FR65: Epic 7 - 1,500-word master list
FR66: Epic 6 (tagging tool + starter list) / Epic 7 (full tier pools + validation) - Word tagging
FR67: Epic 8 - Paragraphs and tier 1-2 sentence generator
FR68: Epic 8 - No passage repeats per tier
FR69: Epic 8 - 2-line text window
FR70: Epic 8 - Step movement and mob model
FR71: Epic 8 - Chase camera
FR72: Epic 8 - Brain pickups by distance
FR73: Epic 8 - Caught / Escaped endings and bonuses
FR74: Epic 8 - Moonlit Village (other settings in Epic 10); card enabled
FR75: Epic 9 - All 18 cosmetics
FR76: Epic 10 - 3 themes per level with rotation
FR77: Epic 10 - Trends and lifetime stats screen
FR78: Epic 11 - Profiles and zombie naming
FR79: Epic 6 - Level unlocks (Locked / New card states, unlock moment, save)

## Epic List

Sequence: 1 → 2 → 3 → 4 → 5 (MVP link) → 6 → 7 → 8 → 9 → 10. Epic 11 can land any time after Epic 5. Dependencies only point backward.

### Epic 1: Foundation & Web Pipeline (MVP)
A hosted link opens the title screen, plays sound after the first click, echoes typed keys without triggering browser shortcuts, and keeps a counter across reloads and tab closes; the art style (palette, zombie, villager) is approved. Retires the web-platform risks before gameplay is built.
**FRs covered:** FR23, FR24 (skeleton), FR27, FR47, FR51, FR52 — plus the Additional Requirements for project setup, CI/Pages, GUT, autoloads, logging and debug overlay; NFR3, NFR4 (first measurement), NFR5, NFR13.

### Epic 2: Typing Core & Shared Frame (MVP)
In a test level, a kid types random letters with blocking judgment (including wrong-key shake/tick and the Caps Lock hint), zombie-hand guidance, a live HUD and pause, and lands on a correct chalkboard report card that is saved to run history.
**FRs covered:** FR1–FR22. NFR2, NFR7, NFR8.

### Epic 3: Zombie Run (MVP)
A kid plays a full 2-minute Zombie Run on Sunny Village Green: bonking brain blocks, hugging villagers into a conga line, dancing at the end and earning brains, then lands on the report card.
**FRs covered:** FR28–FR37, FR48. NFR1 (conga performance), NFR10.

### Epic 4: Meta: Menu, Brains & Crypt Closet (MVP)
A new save goes run → welcome gift → guided purchase → wears the Pumpkin hat in play → earns and buys the Cute ghost. The main menu, brain wallet, Closet and cosmetic display close the meta loop.
**FRs covered:** FR24 (full flow), FR25, FR26, FR38–FR46. NFR9, NFR11.

### Epic 5: MVP Polish & First Link (MVP)
The public MVP link: UI art pass, full audio pass, performance and save-integrity checks on 3 family computers, a kid playtest, fixes, publish.
**FRs covered:** FR49, FR50. Verifies NFR1–NFR4, NFR7–NFR9, NFR14, NFR17.

### Epic 6: Horde Rush (Post-MVP)
Horde Rush is selectable and playable end to end: words spawn zombie copies down 5 lanes against the Farmer defender, and arrivals earn brains. Includes the offline word-tagging tool and a tagged starter word list (fixed 3–5 letter band).
**FRs covered:** FR53–FR59, FR66 (tool + starter list), FR79. NFR1 (30-zombie stress), NFR15.

### Epic 7: Adaptive Curriculum (Post-MVP)
A new save's placement run sets a hidden tier, and later runs silently use the right keyboard rows (Zombie Run) and word lengths (Horde Rush). Full 1,500-word list with validated tier pools.
**FRs covered:** FR60–FR65, FR66 (full pools + validation).

### Epic 8: Pitchfork Panic (Post-MVP)
Pitchfork Panic is selectable and playable: tier-appropriate paragraphs or generated sentences, a step-by-step chase from an accelerating mob, brain pickups, and Caught / Escaped! endings.
**FRs covered:** FR67–FR74. NFR15.

### Epic 9: Full Crypt Closet (Post-MVP)
All 18 Closet slots can be bought and worn, with hats fitting every pose and Horde Rush size class.
**FRs covered:** FR75.

### Epic 10: Art Variety & Trends (Post-MVP)
Each level rotates between 3 looks with no immediate repeat, and a trends screen shows WPM, accuracy and practice time plus lifetime totals.
**FRs covered:** FR76, FR77 (plus the remaining FR58 / FR74 themes).

### Epic 11: Profiles & Zombie Naming (Post-MVP, as needed)
Two kids on one computer keep separate named zombies with their own brains, cosmetics, history and tier; the MVP save becomes the first profile.
**FRs covered:** FR78.

---

## Epic 1: Foundation & Web Pipeline

A hosted link opens the title screen, plays sound after the first click, echoes typed keys without triggering browser shortcuts, and keeps a counter across reloads and tab closes; the art style is approved. Retires the web-platform risks before any gameplay is built.

### Story 1.1: Project Settings, Folder Skeleton and Test Harness

As the developer,
I want the existing Godot project configured for 640×360 pixel art with the agreed folder structure, core helpers and a working GUT test run,
So that every later story starts from correct settings and can be unit-tested.

**Acceptance Criteria:**

**Given** the existing `project.godot`
**When** the story is complete
**Then** the viewport is 640×360, stretch mode `viewport`, aspect `keep`, scale mode `fractional`, default canvas texture filter Nearest and `snap_2d_transforms_to_pixel = true`
**And** the `[dotnet]` section is removed and `debug/gdscript/warnings/untyped_declaration` is set to Error

**Given** the architecture's Project Structure
**When** the folders are created
**Then** `scenes/`, `scripts/`, `data/`, `assets/`, `tests/unit/`, `tests/integration/`, `tests/fixtures/saves/` and `tools/` exist with the mirrored feature sub-folders needed so far
**And** `build/` is listed in `.gitignore`

**Given** `scripts/core/log.gd` (`class_name Log`) and `scripts/core/game_constants.gd` (`class_name GameConstants`)
**When** `Log.debug()` is called in a release build
**Then** nothing is printed, while `error`/`warn`/`info` print in the `[LEVEL][tag] message` format
**And** `GameConstants` holds `LOGICAL_SIZE`, `RUN_HISTORY_CAP = 500` and `CURRENT_SCHEMA = 1`

**Given** GUT 9.7.1 is installed in `addons/gut/`
**When** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` runs
**Then** a smoke test and a `Log` unit test pass and the command exits with code 0
**And** a deliberately failing test makes the command exit non-zero

### Story 1.2: Web Export, CI and GitHub Pages Deploy

As the developer,
I want every push to `main` to run the tests and export the web build, and every version tag to publish it to GitHub Pages,
So that broken tests never ship and kids only ever see finished releases.

**Acceptance Criteria:**

**Given** `export_presets.cfg`
**When** the presets are inspected
**Then** a `Web` preset exists with Thread Support off and no PWA, and a `Windows Desktop` preset exists
**And** both exclude `addons/gut/*`, `tests/*`, `tools/*`, `docs/*`, `_bmad/*`, `_bmad-output/*` and `build/*`

**Given** `.github/workflows/build.yml`
**When** a commit is pushed to `main` or a pull request is opened
**Then** the workflow downloads Godot 4.7.2 headless and its export templates, imports the project, runs GUT, exports the Web preset and uploads it as a workflow artifact, without deploying
**And** when a tag matching `v*` is pushed, the same steps run and the build is deployed to GitHub Pages
**And** the hello-world is published by tagging `v0.0.1`
**And** the current major versions of `actions/checkout`, `actions/upload-pages-artifact` and `actions/deploy-pages` are pinned and noted in the story file

**Given** a failing GUT test
**When** the workflow runs
**Then** the job fails before the export and nothing is deployed

**Given** the deployed hello-world page
**When** it is opened in desktop Chrome, Edge and Firefox from the Pages URL
**Then** it runs without any special server headers (NFR5)
**And** the compressed transfer size and the first-load and cached-load times at 25 Mbit/s (throttled dev tools) are recorded in the story file against the ≤ 10 s / ≤ 3 s / ≤ 40 MB targets (NFR3); if over 10 s, a "custom export template without 3D" item is added to the backlog

**Given** the deployed page in a maximised Chrome, Edge and Firefox window on a 1366×768 screen (or a dev-tools emulation of it)
**When** the title screen is shown
**Then** the game fills the available height with fractional scaling and nearest filtering, with no blurry pixels, and a screenshot per browser is kept in the story file

### Story 1.3: Screen Router and Title Screen

As a kid,
I want to see a title screen that moves on when I press any key or click,
So that the game starts the way I expect.

**Acceptance Criteria:**

**Given** the `Router` autoload with `enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }`
**When** `Router.go(screen, payload)` is called
**Then** a CanvasLayer fade covers the switch, the target scene is loaded with `change_scene_to_packed`, and the new screen can read the payload once with `take_payload()`
**And** a screen that fails to load is logged with `Log.error()` and the Router goes to `MAIN_MENU` instead

**Given** the title screen
**When** it is shown
**Then** it displays a placeholder logo and the text "Click or press any key" in the project pixel font at 16 px or larger
**And** any key press or mouse click goes to the main menu (FR23)

**Given** an SIL OFL pixel font in `assets/fonts/` with its license file
**When** `l`, `I`, `1`, `O` and `0` are rendered at 16 px and 32 px
**Then** each is clearly distinguishable (NFR7)
**And** `data/ui_theme.tres` uses it as the default font and is set as the project's custom theme

**Given** placeholder scenes for Main Menu, Run, Report Card, Welcome Gift and Crypt Closet
**When** the placeholder buttons are used
**Then** the flow Title → Main Menu → Run → Report Card → Menu can be walked end to end (FR24 skeleton)

**Given** the autoloads registered in `project.godot`
**When** the project starts
**Then** they are registered in the order `WebPlatform → SaveService → PlayerData → AudioManager → Router` (stubs are fine for services not built yet)

### Story 1.4: Audio Manager and Browser Audio Unlock

As a kid,
I want sound to start as soon as I click or press a key on the title screen,
So that the game is not silent on the web and never blasts sound before I interact.

**Acceptance Criteria:**

**Given** the audio bus layout
**When** it is inspected
**Then** `Master` has `Music` and `SFX` children with no bus effects

**Given** `AudioManager` with a pool of 8 SFX players and one music player, and `data/audio/audio_library.tres` mapping sound ids to streams and volumes
**When** `play_sfx(id)` is called before `unlock()`
**Then** nothing plays (FR47)
**And** an unknown sound id logs a warning and does not crash

**Given** the title screen
**When** the first key or click happens
**Then** `AudioManager.unlock()` is called from that input callback and a placeholder UI click and a placeholder menu music loop start playing on the web build

**Given** `AudioManager` bus mute methods
**When** the Music or SFX bus is muted
**Then** only that bus goes silent

### Story 1.5: Web Platform Service and Keyboard Capture Test

As a kid,
I want typing Space, `'`, `/`, Backspace and Tab to never scroll the page or open browser search,
So that my typing always goes to the game.

**Acceptance Criteria:**

**Given** `WebPlatform` (the only script allowed to use `JavaScriptBridge` or `OS.has_feature("web")`)
**When** the game runs on desktop
**Then** all `WebPlatform` behaviour is a no-op

**Given** the web build in Chrome and Firefox
**When** the browser tab loses focus or becomes hidden
**Then** `WebPlatform` emits `focus_lost` and `visibility_hidden` respectively
**And** `is_storage_persistent()` returns the result of `OS.is_userfs_persistent()`

**Given** a keyboard test screen reachable from the placeholder menu, with `WebPlatform.capture_keys = true`
**When** Space, `'`, `/`, Backspace and Tab are pressed in Chrome and Firefox
**Then** the page does not scroll, Firefox quick-find does not open, and focus does not leave the canvas
**And** every printable character typed is echoed on screen
**And** the story file records whether the Godot canvas already prevented these defaults or whether a JS `keydown` listener with `preventDefault()` was installed

**Given** `WebPlatform.capture_keys`
**When** the game starts
**Then** it is false, and only the keyboard test screen (here) and `RunFrame` (Story 2.4) set it to true

**Given** `WebPlatform.toggle_fullscreen()` called from a click or key handler
**When** it runs on the web build in Chrome, Edge and Firefox
**Then** the page enters and leaves browser fullscreen, `is_fullscreen()` reports it, and Esc (the browser's exit) is reflected the next time `is_fullscreen()` is called
**And** the keyboard test screen gets a temporary Fullscreen button to prove it

**Given** `WebPlatform.offer_download(bytes, file_name)`
**When** it is called on web
**Then** the browser downloads the file; on desktop the `user://` folder opens

### Story 1.6: Versioned Save File

As a kid,
I want my progress saved safely,
So that I never lose my brains or hats.

**Acceptance Criteria:**

**Given** `SaveSchema.defaults()`
**When** a fresh save is created
**Then** it matches the architecture's v1 JSON: `schema_version: 1`, `active_profile: "p1"`, and a `p1` profile with name, brains, owned_items, equipped hat/pet, flags (welcome_bonus_claimed, tutorial_seen, placement_done), tier, settings (music_on, sound_on), best_wpm and an empty run_history (FR51)

**Given** `SaveService` (the only script that touches files)
**When** a save is written
**Then** it writes `save.tmp`, renames it over `save.json` and keeps the previous file as `save.bak`
**And** if `save.json` fails to parse on load, `save.bak` is used; if both fail, defaults are used and no error is shown to the player

**Given** a loaded save that is missing fields or has unknown fields
**When** it is loaded
**Then** missing fields are filled from defaults and unknown fields are kept

**Given** the ordered migration framework (`migrate_N_to_N1`)
**When** a save with `schema_version` below `CURRENT_SCHEMA` is loaded
**Then** migrations run in order up to the current version

**Given** several `SaveService.request_save()` calls in the same frame
**When** the frame ends
**Then** exactly one write happens
**And** on `WebPlatform.visibility_hidden` or `NOTIFICATION_WM_CLOSE_REQUEST` the save is written immediately (FR52)

**Given** `SaveService.export_json()`
**When** it is called
**Then** it returns the current save as the same pretty-printed JSON that is written to `save.json`, without touching the file system

**Given** fixtures `save_v1_fresh.json`, `save_v1_full.json` and `save_corrupt.json`
**When** the GUT tests run
**Then** defaults, round-trip, missing-field fill, unknown-field keep, backup fallback and write coalescing are all covered and pass

### Story 1.7: Player Data Service and Reload-Proof Counter

As a kid,
I want what I earn to still be there after I reload or close the tab,
So that I trust the game with my progress.

**Acceptance Criteria:**

**Given** `PlayerData` (the single in-memory source of truth for the active profile)
**When** its mutation methods run (for now `add_brains()` and `set_setting()`)
**Then** each emits a typed change signal (`brains_changed(total, delta)`, `settings_changed`) and calls `SaveService.request_save()`
**And** no other script writes save fields directly

**Given** a test counter on the keyboard test screen backed by `PlayerData.add_brains(1)`
**When** the counter is clicked and the page is reloaded 10 times and the tab is closed and reopened 10 times in Chrome and Firefox
**Then** the counter value is never lost (NFR4, first measurement recorded in the story file)
**And** the story file records whether `rename` was reliable on the web file system, switching to direct write plus backup if it was not

**Given** `WebPlatform.is_storage_persistent()` returns false
**When** the placeholder main menu is shown
**Then** it shows the plain-words notice "Progress may not be saved in this browser mode" (FR27)

**Given** `PlayerData`
**When** the GUT tests run
**Then** `add_brains`, `set_setting` and their signals are covered and pass

### Story 1.8: Debug Overlay and Save Export

As the developer,
I want a debug-only overlay with frame timing, save status and a few cheats, plus a save export that also works in release,
So that I can check performance, test saves quickly and pull playtest run history, without shipping cheats.

**Acceptance Criteria:**

**Given** a debug build
**When** F3 is pressed
**Then** `scenes/debug/debug_overlay.tscn` toggles on top, showing FPS, frame time, the worst frame in the last 10 s, the last save write time and whether storage is persistent

**Given** the overlay is open
**When** F5 is pressed
**Then** 100 brains are added through `PlayerData.add_brains()`
**And** F8 asks for confirmation and then resets the save to defaults
**And** F9 exports the save (as below)

**Given** any build (debug or release) on the main menu (placeholder for now)
**When** Ctrl+Shift+E is pressed
**Then** `SaveService.export_json()` is passed to `WebPlatform.offer_download()` as `zts-save-YYYYMMDD.json`, and nothing on screen changes (no visible UI for kids)

**Given** a release export
**When** it runs
**Then** the overlay scene is never instanced and F3/F5/F8/F9 do nothing (gated by `OS.is_debug_build()`), while Ctrl+Shift+E still works

### Story 1.9: Art-Style Sheet and Prototype Sprites (Review Gate)

As Smuck (art director),
I want the palette, pixel font, sprite standards and the first zombie and villager sprites approved before other art is made,
So that every later asset looks like one consistent game.

**Acceptance Criteria:**

**Given** `assets/palette/palette_32.png`
**When** it is inspected
**Then** it holds at most 32 colors, and a style sheet in `docs/` records the palette, sprite sizes (characters 32×32, brutes 48×48, tiles 16×16), the 1 px dark outline rule and animation limits (2–6 frames at 8–12 fps) (NFR13)

**Given** the pixel font chosen in Story 1.3
**When** the style sheet is written
**Then** it records the font, its sizes (16 px UI, 32 px targets, 24 px paragraph text) and license

**Given** prototype sprites of the player zombie (idle 2f, walk 4f) and one villager (idle/wave 2f), using only palette colors
**When** they are shown in-game with the project's fractional scaling and nearest filtering
**Then** they are crisp, kid-safe (no gore) and readable against a plain background
**And** Smuck records approval (or requested changes) in the story file; no final art is produced until approval is given; placeholder art (plain shapes in palette colors) is allowed in any story before its final-art story (3.6, 4.3, 5.0)

---

## Epic 2: Typing Core & Shared Frame

In a test level, a kid types random letters with blocking judgment (including wrong-key shake/tick and the Caps Lock hint), zombie-hand guidance, a live HUD and pause, and lands on a correct chalkboard report card that is saved to run history.

### Story 2.1: Typing Input Filtering

As a kid,
I want only real typing keys to count, and stray keys like Shift, arrows or held-down repeats to be ignored,
So that I am never marked wrong for something that wasn't a typing mistake.

**Acceptance Criteria:**

**Given** `TypingInput` (Node) receives an `InputEventKey`
**When** the event is a key-repeat (`echo`), has `unicode == 0` (dead key, IME composition, modifiers alone), or is Ctrl, Alt, Meta, an arrow, a function key, Tab, Backspace, Enter or Caps Lock
**Then** no `char_typed` signal is emitted (FR3)

**Given** the `LevelConfig` Resource class (created in this story in `scripts/resources/level_config.gd`, starting with `duration_s`, `case_sensitive`, `space_is_input` and `target_mode`; later stories add fields)
**When** it is inspected
**Then** it is a typed custom Resource usable from `.tres` files

**Given** a `LevelConfig` with `case_sensitive = false` and `space_is_input = false`
**When** `A` (Shift or Caps Lock) or `a` is typed
**Then** `char_typed("a")` is emitted
**And** Space emits nothing (FR4)

**Given** a `LevelConfig` with `case_sensitive = true` and `space_is_input = true`
**When** `A`, `a` and Space are typed
**Then** `char_typed` emits `"A"`, `"a"` and `" "` unchanged

**Given** a lowercase level
**When** 3 capital letters in a row are typed (checked on the raw character before lowercasing)
**Then** `caps_lock_suspected` is emitted once
**And** the next lowercase letter emits `caps_lock_cleared` (FR5)

**Given** `tests/unit/test_typing_input.gd` using synthetic `InputEventKey`s
**When** GUT runs
**Then** every rule above is covered and passes

### Story 2.2: Judgment Session and Letter Bag

As a kid,
I want the right letter to be accepted instantly and a wrong letter to simply not count,
So that typing feels fair and snappy.

**Acceptance Criteria:**

**Given** the `TargetSource` base (`peek(n)`, `current()`, `advance()`) and `LetterBagSource` built with an injected `RandomNumberGenerator` and a letter pool
**When** letters are drawn
**Then** every letter in the pool appears once before any repeat, and the same letter never appears twice in a row, including across bag boundaries (FR29)
**And** a fixed seed produces the same sequence every time

**Given** `TypingSession` (RefCounted, no nodes) holding a `TargetSource`
**When** `judge(char)` receives the expected character
**Then** it emits `char_accepted(expected, index)` and `target_changed(next)` synchronously in the same call, and emits `run_started` on the first correct key only (FR1, FR6)

**Given** the same session
**When** `judge(char)` receives a different printable character
**Then** it emits `char_rejected(expected, typed)`, the target does not advance and the error count rises by 1 (FR2)

**Given** a sequence of judgments
**When** the per-key record is read
**Then** each expected character has attempts, errors and a map of what was typed instead, e.g. `"f": [14, 3, {"g": 2, "d": 1}]` (FR9)

**Given** `test_typing_session.gd` and `test_letter_bag_source.gd`
**When** GUT runs
**Then** judgment, first-key start, per-key tracking and the bag rules (tested over 1,000 draws with several seeds) pass

### Story 2.3: Stats Calculator and Run Result

As a kid,
I want my Keys Typed, Errors, Accuracy, WPM and time to be calculated correctly,
So that the report card tells me the truth about how I did.

**Acceptance Criteria:**

**Given** `StatsCalculator` (static)
**When** it computes stats from keys typed, errors, run seconds and completed words
**Then** Accuracy = Keys ÷ (Keys + Errors) as a whole %, WPM = (Keys ÷ 5) ÷ minutes as a whole number, and Lesson Time is formatted m:ss (FR7)
**And** when word mode adds implied spaces, each completed word adds 1 to the WPM key count
**And** 0 keys and 0 errors gives 0% accuracy and 0 WPM without dividing by zero

**Given** `RunResult`
**When** it is built at run end
**Then** it holds level_id, timestamp, duration, keys typed, errors, WPM, accuracy, brains, bonus brains, letter pool or tier, per-key data and end reason, and can convert itself to the save's run-record dictionary

**Given** `test_stats_calculator.gd` with known inputs (e.g. 100 keys, 5 errors, 120 s → 95%, 10 WPM, 2:00)
**When** GUT runs
**Then** all cases pass

### Story 2.4: Run Frame, Level Contract and Test Level

As a kid,
I want a run that waits for my first letter, then times me and ends cleanly,
So that I never lose time before I'm ready.

**Acceptance Criteria:**

**Given** `LevelBase` (extends Node2D) with the architecture's contract (`get_level_config`, `create_target_source`, `on_run_started`, `on_char_accepted`, `on_char_rejected`, `on_target_completed`, `on_run_ending`, `get_brains_earned`, `end_requested` and `brains_earned_changed` signals)
**When** `RunFrame` starts with a `RUN` payload `{ "level_id": ... }`
**Then** it instances the level from `level_registry.tres`, creates one `RandomNumberGenerator` for the run (seeded from the payload's optional `seed`, randomised otherwise), builds the `TypingSession`, configures `TypingInput` from the `LevelConfig`, and connects the signals in code

**Given** `RunFrame` enters the scene tree
**When** the run screen is shown
**Then** it sets `WebPlatform.capture_keys = true`, and sets it back to false in `_exit_tree()` (report card, quit to menu or a failed load) (FR29 key swallowing)

**Given** the run is in `WAITING_FIRST_KEY`
**When** the scene loads
**Then** the first target is shown and the clock is stopped (FR6)
**And** the first correct key moves the state to `RUNNING` and starts `RunClock`, which accumulates `delta` only while running

**Given** a `RUNNING` run
**When** a correct key arrives
**Then** the level's `on_char_accepted` is called in the same frame, with no `await` anywhere in the typing path (FR1, NFR2)

**Given** the clock reaches the level's duration or the level emits `end_requested`
**When** the run ends
**Then** the state becomes `ENDING`, input is rejected, the frame waits the outro time returned by `on_run_ending`, builds a `RunResult` and calls `Router.go(REPORT_CARD, { "result": ... })`

**Given** a `test_level` (registered in the level registry, not shown on the real menu) that displays the current letter from a `LetterBagSource` with a 2:00 `LevelConfig`
**When** "Test level" is chosen on the placeholder menu (the button exists only in debug builds)
**Then** a full run can be typed from start to end
**And** the test level emits `brains_earned_changed` +1 for every 4th correct key so the HUD counter can be seen working

**Given** `tests/integration/test_run_frame.gd`
**When** GUT runs with a fixed seed and synthetic input
**Then** the state transitions, clock start on first key and run end are covered and pass, and `capture_keys` is true during the run and false after it

### Story 2.5: Shared HUD with Wrong-Key Feedback

As a kid,
I want to see my target, timer and stats in the same place in every level, and a clear little wobble when I miss,
So that I always know what to type and how I'm doing.

**Acceptance Criteria:**

**Given** the HUD band in `UX/DESIGN.md` (Layout, HUD band component) and the Run HUD mock (letter and word modes)
**When** the HUD is built
**Then** it matches them, including the brain counter in every mode (D15); and a layout sketch of the **2-line paragraph mode** (not mocked) that follows DESIGN.md is approved by Smuck in the story file before that mode is built

**Given** the HUD inside `RunFrame`
**When** a run is shown at 640×360
**Then** the bottom 104 px band holds, left to right, a pet slot (empty for now), the target area with a space for the zombie hands below it, a stats column with Timer, Keys Typed, WPM and Errors, and the brain counter beside it (starts at 0 and updates on `brains_earned_changed` in the same frame); a pause button sits in the playfield's top-right (FR14)
**And** the target character is at least 32 px tall and all HUD text at least 16 px (NFR7)
**And** the target area's size comes from the target mode: 32 px for letter and word targets, and 2 lines of 24 px for paragraph mode, with the zombie hands below in every mode (Epic 8 needs no HUD rework)

**Given** the run is waiting for the first key
**When** the HUD is shown
**Then** it shows the first target and the label "Type the letter to start!" ("word" / "text" by target mode) (FR6)

**Given** a running run
**When** time passes
**Then** the live WPM stays hidden for the first 5 s and then updates once per second (FR8)
**And** Keys Typed and Errors update in the same frame as each judgment

**Given** a wrong printable key
**When** it is judged
**Then** the target character shakes for 0.2 s and `AudioManager` plays the wrong-key tick, at most once per 150 ms (throttled inside `AudioManager`) (FR2)
**And** `tests/unit/test_audio_manager.gd` covers the 150 ms wrong-key throttle with a fake clock

**Given** `caps_lock_suspected`
**When** it is emitted
**Then** the HUD shows "Caps Lock is on" in plain words, and hides it on `caps_lock_cleared` (FR5)

### Story 2.6: Green Zombie Hands Finger Guide

As a kid,
I want the zombie hands to light up the finger I should use next,
So that I learn to touch type without looking at a chart.

**Acceptance Criteria:**

**Given** `data/finger_map.tres` (`FingerMap`)
**When** it is inspected
**Then** it holds every character in the GDD finger table (letters, digits, punctuation, Space) with hand, finger and a Shift flag for capitals and shifted symbols (FR16)

**Given** `FingerMap.fingers_for(c)`
**When** it is called with `a`, `J`, `A` and Space
**Then** it returns left pinky; right index + left pinky; left pinky + right pinky; both thumbs (FR17)
**And** an unmapped character logs a warning and returns an empty list

**Given** `ZombieHands` below the target area
**When** `target_changed(next)` fires
**Then** the finger(s) for the next character glow brighter green with a pulsing outline, so the cue doesn't rely on color alone (FR15, NFR8)
**And** the `f` and `j` fingertips always show a small bump mark (FR18)

**Given** `test_finger_map.gd`
**When** GUT runs
**Then** all 26 letters, `A`, `J` and Space pass

### Story 2.7: Pause, Focus Loss and Resume Countdown

As a kid,
I want the game to freeze when I press Esc or switch tabs, and count me back in,
So that I never lose time when something interrupts me.

**Acceptance Criteria:**

**Given** a running run
**When** Esc or the pause button is pressed
**Then** the state becomes `PAUSED`, the clock stops, the tree is paused and the pause panel shows Resume, Quit to Menu, and Music and Sound toggles that work like the menu ones (bus mute plus `PlayerData.set_setting()`) (FR10, FR46)

**Given** a running run or a countdown
**When** `WebPlatform.focus_lost` fires
**Then** the run goes to `PAUSED` (FR11, FR12)

**Given** the pause panel
**When** Resume is chosen
**Then** a 3-2-1 countdown shows at 0.5 s per number while the tree stays paused and typing is rejected
**And** the tree unpauses only when the state enters `RUNNING` (FR12)

**Given** the pause panel
**When** Quit to Menu is chosen
**Then** brains earned so far are committed through `PlayerData.add_brains()`, no completion bonus is given, no run is recorded in history, and the Router goes to the main menu (FR13)

**Given** the run is waiting for its first key
**When** it is paused and resumed
**Then** the clock is still stopped until the first correct key

### Story 2.8: Run Recording and Personal Bests

As a parent,
I want every completed run saved with its stats and per-key data,
So that progress can be seen and adaptive difficulty can use it later.

**Acceptance Criteria:**

**Given** a completed run's `RunResult`
**When** `RunFrame` calls `PlayerData.record_run(result)`
**Then** the run record is appended to the profile's run history, the level's brains are added, and one save is requested (FR22, FR52)
**And** the history keeps only the newest 500 runs

**Given** a level with a saved best WPM
**When** a recorded run's WPM is higher
**Then** `best_wpm[level_id]` is updated and `record_run` reports it as a new best (FR20)
**And** the very first run of a level sets the best but is not reported as a new best

**Given** a quit run
**When** it ends
**Then** `record_run` is not called (FR13)

**Given** `test_player_data.gd`
**When** GUT runs
**Then** append, the 500 cap (501st run drops the oldest), best-WPM update and the first-run rule pass

### Story 2.9: Chalkboard Report Card

As a kid,
I want a fun report card after every run showing how I did,
So that I feel proud and want to play again.

**Acceptance Criteria:**

**Given** the Report Card mock and `UX/DESIGN.md` (chalkboard, Professor Zombie, "New best!" stamp, buttons)
**When** the screen is built
**Then** it matches them (the level name as the heading, night classroom backdrop, mortarboard stacked on the worn hat, D16), with every text at 16 px or more. No separate sketch is needed; the mock is the approved layout

**Given** a `REPORT_CARD` payload with a `RunResult`
**When** the screen opens
**Then** a chalkboard shows Keys Typed, Errors, WPM, Accuracy, Lesson Time and Brains Collected, with bonus brains on a separate "+N bonus" line (FR19)
**And** Professor Zombie (the player zombie with a cap-and-gown overlay in a pointing pose, with empty placeholder nodes where the hat and pet will go; their behaviour is added in Story 4.3) points at the board

**Given** the run was a new best
**When** the report card shows
**Then** a "New best!" stamp appears (FR20)

**Given** the report card has just opened
**When** Enter or Esc is pressed within the first 1.0 s
**Then** nothing happens
**And** after 1.0 s, Enter (or the Play Again button) restarts the same level and Esc (or the Menu button) goes to the main menu (FR21)

**Given** all report card text
**When** it is read
**Then** it uses plain words a 6-year-old can read and meets the 16 px minimum (NFR7, NFR9)

### Story 2.10: Run Debug Tools and Seed Replay

As the developer,
I want the debug overlay to show what the run is doing and to replay a run with a fixed seed,
So that I can reproduce and diagnose typing bugs quickly.

*Placement:* last in Epic 2 because no story depends on it; it may be pulled forward any time after Story 2.4.

**Acceptance Criteria:**

**Given** a debug build during a run
**When** the overlay (F3) is open
**Then** it also shows the run state, clock, current and next 3 targets, keys/errors/WPM and the run seed

**Given** the overlay
**When** F6 is pressed during a run
**Then** the run ends as if the clock ran out; F7 toggles verbose typing logs (`Log.debug` per judgment)

**Given** a `debug_seed` set in the overlay
**When** the next run starts
**Then** `RunFrame` passes it as the payload `seed`, and the same inputs produce the same target sequence

**Given** a release export
**When** it runs
**Then** none of these fields or keys exist (gated by `OS.is_debug_build()`)

---

## Epic 3: Zombie Run

A kid plays a full 2-minute Zombie Run on Sunny Village Green: bonking brain blocks, hugging villagers into a conga line, dancing at the end and earning brains, then lands on the report card.

### Story 3.1: Zombie Run Level, Target Queue and Zombie Movement

As a kid,
I want my zombie to walk toward the next letter and zip forward every time I type it right,
So that fast typing makes my zombie race along.

**Acceptance Criteria:**

**Given** `scenes/levels/zombie_run/zombie_run_level.tscn` extending `LevelBase`, registered as `&"zombie_run"` in `level_registry.tres`, with `data/levels/zombie_run.tres`
**When** the config is inspected
**Then** it holds duration 120 s, target spacing 48 px, 3 visible upcoming targets, amble 24 px/s, idle stop 24 px before the target, scoot 0.15 s, brain block every 4, completion bonus 10, `case_sensitive = false`, letter target mode, and all 26 letters (FR28)
**And** no tuning number appears as a literal in the level scripts

**Given** the placeholder main menu
**When** Zombie Run is chosen
**Then** a run starts through `Router.go(RUN, { "level_id": &"zombie_run" })`

**Given** a running Zombie Run
**When** it is shown
**Then** targets sit 48 px apart along the path, the active target plus the next 3 are visible, each shows its letter, and the active one bobs with a down-arrow marker and matches the HUD target (FR30)
**And** targets are generic placeholders for now (brain blocks and villagers come in 3.2 and 3.3)

**Given** the zombie is short of the active target's approach point
**When** no key is typed
**Then** it ambles at 24 px/s and stops 24 px before the target to idle (FR31)

**Given** a correct key
**When** it is judged
**Then** the logical target index advances in the same frame, the target resolves, and the zombie's move tween is killed and restarted from its current position to the next approach point over 0.15 s; repeated fast keys chain scoots so walking never caps typing speed (FR1, FR31)
**And** the camera follows the zombie so upcoming targets never scroll out of view, and resolved targets are freed once off screen

**Given** the sprites this story needs (player zombie, generic targets, down-arrow marker)
**When** final art isn't ready yet
**Then** placeholder sprites in palette colors are used; final frames arrive in Story 3.6

### Story 3.2: Brain Blocks and the Brain Counter

As a kid,
I want to hop and bonk brain blocks to pop out brains,
So that I earn brains while I type.

**Acceptance Criteria:**

**Given** the target generator
**When** targets are created
**Then** each group of 4 has exactly 1 brain block and 3 villager slots in a shuffled order, using the run's injected RNG (FR32)
**And** `test_zombie_run_groups.gd` verifies the 1-in-4 rule over many groups and seeds

**Given** a brain block floating 48 px above the ground as the active target
**When** its letter is typed correctly
**Then** the zombie plays a 0.35 s hop, the block plays its bonk, a brain pops out, and the level's brain total rises by 1 (FR33)
**And** if the next key arrives mid-hop, the hop restarts on the next target and input is never delayed

**Given** a brain is collected
**When** the 20% chance passes (rolled by the level with the run RNG)
**Then** `AudioManager.play_voice(&"vo_brainsss")` is requested; this story implements `play_voice()`, which drops any voice line within 8 s of the last one
**And** `test_audio_manager.gd` covers the 8 s spacing with a fake clock

**Given** a brain is collected
**When** the level's total changes
**Then** Zombie Run emits `brains_earned_changed(total)` and the shared HUD counter from Story 2.5 shows it (FR14)

**Given** the sprites this story needs (brain block, bonk, brain pop, zombie hop)
**When** final art isn't ready yet
**Then** placeholder sprites in palette colors are used; final frames arrive in Story 3.6

### Story 3.3: Villager Hugs and Party-Hat Zombies

As a kid,
I want my zombie to hug villagers and turn them into party-hat zombies,
So that every correct letter feels like goofy mischief.

**Acceptance Criteria:**

**Given** a waving villager standing on the path as the active target
**When** its letter is typed correctly
**Then** the zombie plays a 0.4 s hug, the villager poofs (4 frames) and a party-hat zombie appears in its place (FR34)
**And** the villager's state goes `WAITING → HUGGED → POOFED` and never goes backward

**Given** a villager being hugged
**When** the next key arrives before the hug ends
**Then** the hug is cut short and the zombie scoots on; the poof and party-hat zombie still complete as fire-and-forget effects

**Given** the sprites this story needs (villager, hug, poof, party-hat zombie)
**When** final art isn't ready yet
**Then** placeholder sprites in palette colors are used; final frames arrive in Story 3.6

### Story 3.4: Conga Line

As a kid,
I want every zombie I make to join a bobbing conga line behind me,
So that I can see how much I've done this run.

**Acceptance Criteria:**

**Given** a new party-hat zombie
**When** it is created
**Then** it joins the end of a conga line that trails the zombie with a bobbing walk and follows its scoots (FR35)

**Given** more than 12 party-hat zombies this run
**When** the line is drawn
**Then** only 12 followers are drawn and a "×N" badge on the last one shows the total, with no hidden nodes created beyond the cap

**Given** a wrong key or a pause
**When** it happens
**Then** the conga line never shrinks

**Given** a debug build and a fixed seed
**When** a full 2:00 run with 12+ followers is played on the web build
**Then** the debug overlay's worst frame stays under 33 ms on the development machine, and the result is recorded in the story file (first check toward NFR1; the target-laptop check happens in Epic 5)

### Story 3.5: Run End Dance and Brains Award

As a kid,
I want my zombie and its conga line to dance when time runs out,
So that every run ends as a celebration.

**Acceptance Criteria:**

**Given** the clock reaches 2:00
**When** the run ends
**Then** typing is rejected immediately, the zombie and conga line dance for 2.0 s, and then the report card appears (FR36)

**Given** the run's brain total
**When** the `RunResult` is built
**Then** brains = brain blocks collected and bonus = 10 (read from the `LevelConfig`), and the report card shows the "+10 bonus" line
**And** `PlayerData.record_run()` adds brains + bonus to the wallet and saves

**Given** a run quit from the pause menu
**When** it ends
**Then** only the brain blocks collected are added and no bonus is given (FR13)

**Given** the report card's Play Again
**When** it is chosen
**Then** a new Zombie Run starts with a fresh letter bag and an empty conga line

### Story 3.6: Sunny Village Green and Zombie Run Art

As a kid,
I want Zombie Run to look like a bright, cheerful village,
So that the level feels calm and inviting.

**Acceptance Criteria:**

**Given** the Sunny Village Green backdrop (sky, far layer, near layer, 16×16 ground tiles)
**When** the zombie moves
**Then** the layers scroll with parallax and tile seamlessly for a whole 2:00 run at any typing speed (FR37)

**Given** the final MVP sprite set for this level
**When** it is in the game
**Then** it includes player zombie idle 2f, walk 4f, hop 3f, hug 3f, dance 4f; villager idle/wave 2f and poof 4f; party-hat zombie walk 4f; brain block idle and bonk 3f; brain pop; and the down-arrow marker
**And** every sprite follows the approved style sheet (palette, sizes, 1 px outline, 2–6 frames at 8–12 fps) (NFR13)

**Given** the target letters over the backdrop
**When** they are viewed at 1× scale
**Then** each letter is readable against every part of the backdrop, checked against a named manual checklist written in the story file (what to look for, pass/fail per item)

**Given** the villager and party-hat zombie art
**When** it is reviewed
**Then** the party-hat zombie is the villager sprite recolored plus a party hat, using only palette colors, with no scary or gory details (NFR10, NFR13)

### Story 3.7: Zombie Groans and Voice Spacing

As a kid,
I want my zombie to groan now and then, but not constantly,
So that it sounds funny without getting annoying.

**Acceptance Criteria:**

**Given** a Zombie Run in `RUNNING`
**When** `AudioManager.start_ambience()` is active (this story implements `start_ambience()` and `stop_ambience()`)
**Then** a random groan from 4 plays every 3–8 s (random interval), never tied to keypresses (FR48)

**Given** a voice line has just played
**When** a groan would fire within 2 s of it
**Then** the groan is skipped

**Given** the run is paused, ending or done
**When** ambience is checked
**Then** no groans play, and `stop_ambience()` is called when the run leaves `RUNNING`

**Given** `AudioManager` throttling rules
**When** the unit tests run with a fake clock
**Then** the 3–8 s groan interval and the 2 s groan mute after a voice line pass (the throttle and voice tests live in Stories 2.5 and 3.2)

---

## Epic 4: Meta: Menu, Brains & Crypt Closet

A new save goes run → welcome gift → guided purchase → wears the Pumpkin hat in play → earns and buys the Cute ghost. The main menu, brain wallet, Closet and cosmetic display close the meta loop.

### Story 4.1: Cosmetic Catalogue and Brain Wallet Rules

As a kid,
I want my brains to be spent correctly when I buy something and never lost otherwise,
So that I can trust the shop.

**Acceptance Criteria:**

**Given** `CosmeticItem` (id, slot, price, row, is_available, icon, overlay texture, pet SpriteFrames), `Catalogue` and `EconomyConfig`
**When** `data/cosmetics/catalogue.tres` is inspected
**Then** it lists all 18 GDD items in their hat/pet grids with row prices 100 / 200 / 300; only `hat_pumpkin` and `pet_cute_ghost` have `is_available = true` (FR39, FR42)
**And** `data/economy.tres` holds the welcome bonus of 100

**Given** `PlayerData.buy_item(item)`
**When** it is called
**Then** it returns `OK` and deducts the price when the item is available, not owned and affordable; otherwise it returns `NOT_ENOUGH_BRAINS`, `ALREADY_OWNED` or `UNAVAILABLE` and changes nothing (FR38, FR41)
**And** a successful buy emits `brains_changed` and `inventory_changed` and requests a save

**Given** `PlayerData.set_flag(name: StringName, value: bool)` and `get_flag(name)`
**When** a known flag (`welcome_bonus_claimed`, `tutorial_seen`, `placement_done`) is set
**Then** it emits `flags_changed(name, value)` and requests a save
**And** an unknown flag name logs `Log.error()` and changes nothing; the tests cover both cases

**Given** `PlayerData.equip(item_id)` and `unequip(slot)`
**When** they are called
**Then** only owned items can be equipped, one hat and one pet at most, either slot can be empty, and `equipment_changed(slot, item_id)` is emitted and a save requested (FR43)

**Given** `test_player_data.gd`
**When** GUT runs
**Then** every purchase result, equip/unequip rule and the "brains never go negative" rule pass

### Story 4.2: Main Menu

As a kid,
I want a main menu where I can see my zombie and brains, pick a level and toggle sound,
So that I can choose what to do next.

**Acceptance Criteria:**

**Given** the Main Menu mock (section A, MVP) and `UX/DESIGN.md` Layout and Components (level-card states, Closet button on the signpost, toggles bottom-right)
**When** the screen is built
**Then** it matches them. No separate sketch is needed; the mock is the approved layout

**Given** the main menu
**When** it opens
**Then** it shows the title logo, the player's zombie, the brain counter, 3 level cards (Zombie Run, Horde Rush, Pitchfork Panic), a Crypt Closet button, and Music, Sound and Fullscreen toggles (FR26)
**And** Horde Rush and Pitchfork Panic show a "Coming soon" sign and cannot be selected; the cards are driven by the `available` flag in `level_registry.tres`, and the level card is built as a single component with a state enum (Available / Coming soon, with Locked and New added in Story 6.8) so Epic 6 adds states rather than rebuilding the card

**Given** the menu
**When** arrow keys, Enter and Esc are used, or items are clicked
**Then** arrows move a visible focus, Enter selects, and mouse clicks work on every control (FR25)

**Given** the Music or Sound toggle
**When** it is switched
**Then** the matching bus is muted or unmuted, `PlayerData.set_setting()` saves it, and the setting is restored on the next launch (FR46)

**Given** the Fullscreen toggle
**When** it is clicked or selected with Enter
**Then** `WebPlatform.toggle_fullscreen()` is called from that input and the toggle shows the current state

**Given** the real main menu
**When** Ctrl+Shift+E is pressed
**Then** the save export from Story 1.8 still works

**Given** storage is not persistent
**When** the menu opens
**Then** the "Progress may not be saved in this browser mode" notice from Story 1.7 is still shown (FR27)

**Given** the menu's labels
**When** they are read
**Then** they use plain words (no zombie slang) at 16 px or larger, and there is no timer on the screen (NFR9, NFR11)

### Story 4.3: Hat and Pet Display Everywhere

As a kid,
I want the hat I wear to sit on my zombie in every pose and my pet to hang out beside me,
So that my reward is always on screen.

**Acceptance Criteria:**

**Given** `SpriteAnchors` resources for the player zombie and Professor Zombie with a head point for every animation frame
**When** a `HatSlot` child is added to a zombie's `AnimatedSprite2D`
**Then** on every `frame_changed` it moves to that frame's head point, so the hat fits idle, walk, hop, hug and dance, and Professor Zombie's pointing pose (FR43)

**Given** a `PetSlot`
**When** a pet is equipped
**Then** it plays the pet's idle animation in the HUD pet slot, on the report card and beside the zombie on the main menu

**Given** `PlayerData.equipment_changed`
**When** the hat or pet changes
**Then** every visible `HatSlot` and `PetSlot` updates at once, and an empty slot shows nothing
**And** a missing texture logs a warning and never stops a run (NFR16)

**Given** the Pumpkin hat overlay and the Cute ghost pet (idle float 4f)
**When** they are drawn
**Then** they follow the style sheet and look right on every zombie pose, checked by a debug fit-check scene that shows the hat on every frame and a named manual checklist written in the story file (what to look for, pass/fail per item)

### Story 4.4: Crypt Closet

As a kid,
I want a closet where I can see every hat and pet, buy the ones I can afford and wear them,
So that my brains turn into something fun.

**Acceptance Criteria:**

**Given** a layout sketch of the Closet at 640×360 that follows `UX/DESIGN.md` (closet-item-tile states and colors, brain counter pill, panel materials) and `UX/EXPERIENCE.md` (grid navigation, confirm prompt with default focus on Yes, first-visit tutorial) (two 3×3 grids with prices, tile states, preview zombie, brain counter, the tutorial arrow's positions)
**When** it is reviewed
**Then** Smuck approves it in the story file before the screen is built, with every text at 16 px or more

**Given** the Crypt Closet (from the menu's Closet button)
**When** it opens
**Then** it shows the 3×3 hat grid and 3×3 pet grid with prices by row, the brain counter, and a preview zombie wearing the currently selected item (FR39)

**Given** each item tile
**When** it is drawn
**Then** it shows exactly one state: Locked "?" silhouette labeled "Coming soon"; Can't afford with "Need N more"; Buy; Wear; or Wearing (FR40, FR42)

**Given** an affordable item
**When** Buy is chosen
**Then** a confirm prompt appears; confirming buys it, plays the purchase jingle, updates the brain counter and changes the tile to Wear, and the save is written immediately (FR41)
**And** cancelling changes nothing

**Given** an owned item
**When** Wear is chosen
**Then** it is equipped and shows as Wearing; choosing a Wearing item takes it off (FR41, FR43)

**Given** the Closet
**When** it is used with arrow keys, Enter and Esc, or the mouse
**Then** everything works both ways, and Esc goes back to the menu (FR25)

### Story 4.5: Welcome Gift and Guided First Purchase

As a new player,
I want a gift of brains after my first run and a little help buying my first item,
So that I get a hat right away and understand what brains are for.

**Acceptance Criteria:**

**Given** a save whose `welcome_bonus_claimed` flag is false
**When** the first completed (not quit) run's report card moves on (Play Again or Menu)
**Then** the "Welcome gift!" card appears instead, grants +100 brains and calls `PlayerData.set_flag(&"welcome_bonus_claimed", true)`, and its only button, "Open the Crypt Closet", goes to the Closet (FR44, FR24)
**And** after that, later runs never show the gift again

**Given** the Closet opened from the Welcome gift with `tutorial_seen` false
**When** it opens
**Then** an arrow points at the first affordable item, then at Buy, confirm and Wear in turn (FR45)
**And** the guide ends and `PlayerData.set_flag(&"tutorial_seen", true)` is called when the first item is worn or when the kid leaves the Closet

**Given** a fresh save
**When** it plays one Zombie Run, takes the gift and follows the guide
**Then** the kid can buy and wear the Pumpkin hat, start another run and see the hat on the zombie in play, on the report card and on the menu (end-to-end check for the Epic 4 deliverable)

**Given** the Welcome gift and guide text
**When** it is read
**Then** it uses plain words a 6-year-old can read (NFR9)

> Design note: after the first purchase, the way to play with the new hat is Closet → (Esc) Menu → level card. That's 2 steps, and it's deliberate for the MVP. A "Play with it!" button after Wear is a post-MVP idea if playtests show kids get lost.

---

## Epic 5: MVP Polish & First Link

The public MVP link: UI art pass, full audio pass, performance and save-integrity checks on 3 family computers, a kid playtest, fixes, publish.

### Story 5.0: MVP UI Art Pass

As a kid,
I want every screen to look as good as the zombie does,
So that the whole game feels finished, not just the level.

**Acceptance Criteria:**

**Given** the GDD's MVP UI asset list
**When** this story is done
**Then** final art replaces the placeholders for: title logo; 3 level cards (2 with a "Coming soon" sign); HUD band frame; zombie hands (2 hands, 10 finger-glow states with pulsing outline, f/j bumps); chalkboard report card and "New best!" stamp; Closet grid tiles, the locked "?" silhouette and all 5 tile states; buttons (normal/focus/pressed); the brain icon; the Welcome Gift card; the pause panel; the Music/Sound/Fullscreen toggle icons; and the web loading page + boot splash (logo on night, pumpkin progress bar)

**Given** the web build loading on a slow connection
**When** the page opens
**Then** the loading screen matches the title screen: a night (`#2B1D3F`) page, the title logo, and a chunky pumpkin (`#F07A1C`) progress bar on a dusk (`#4A3366`) track, with no text beyond the logo and no default Godot logo (DESIGN.md boot-splash, UX D11)
**And** it is done through the Web export preset's `html/head_include` CSS, which restyles the default shell's `#status`, `#status-progress` and `#status-notice` elements. A full `html/custom_html_shell` is used only if the head-include approach can't reach the look, and the reason is noted in the story file

**Given** the engine has loaded
**When** Godot's own boot splash shows
**Then** `application/boot_splash/bg_color` is `#2B1D3F`, the image is the title logo (Nearest filter, no stretch), and the change from loading page → boot splash → title screen has no white or grey flash on Chrome, Edge and Firefox. The Windows fallback uses the same boot splash settings

**Given** every asset
**When** it is checked against the style sheet from Story 1.9
**Then** it uses only palette colors, the 1 px outline rule and the pixel font, and matches `UX/DESIGN.md` (palette tokens, typography, component states), the three key-screen mocks, and the approved layout sketches from Stories 2.5 (paragraph mode) and 4.4 (NFR13); screens without a mock or sketch (title, boot splash, pause panel and countdown, Welcome Gift) follow the spines directly

**Given** the zombie hands and HUD in grayscale
**When** they are reviewed
**Then** the active finger is still clear without color (NFR8)

**Given** the new art in game
**When** the MVP flow is walked end to end
**Then** no screen still shows placeholder art, and Smuck records approval in the story file

### Story 5.1: MVP Audio Pass and Mix

As a kid,
I want bouncy music and funny sounds that never get annoying,
So that the game feels alive and fun to play again.

**Acceptance Criteria:**

**Given** the MVP audio list
**When** `audio_library.tres` is inspected
**Then** it holds 4 groans, 2 "Brainsss" lines, brain bonk, hug-poof, wrong-key tick, purchase jingle, report card chalk-scratch and chime, UI click, a menu music loop and a Zombie Run music loop (60–120 s each), as OGG music and 16-bit WAV effects (FR49, FR50)
**And** every file's source and license (CC0-style or self-recorded) is listed in `assets/audio/CREDITS.md` (NFR14)

**Given** each sound event in the game
**When** it happens
**Then** the matching sound plays through `AudioManager` (bonk on brain block, hug-poof on villager, chime and chalk-scratch on the report card, click on UI buttons, jingle on purchase)

**Given** the screens and runs
**When** they are entered
**Then** the menu loop plays on the title, menu, Closet, Welcome Gift and report card; the Zombie Run loop plays during a run (paused runs keep it at a lower volume); and switching between them is a 0.5 s crossfade, with the same loop never restarting when it's already playing

**Given** a full Zombie Run at 30+ WPM
**When** it is played
**Then** music sits below the effects, the wrong-key tick is quiet, and no sound stacks into noise, checked against a named manual checklist written in the story file (what to look for, pass/fail per item) (NFR14)
**And** with both toggles off, the whole game is still fully playable (FR46)

### Story 5.2: Readability, Color and Plain-Words Check

As a parent,
I want every screen readable by a 6-year-old and usable by a colorblind kid,
So that nobody is left out.

**Acceptance Criteria:**

**Given** every MVP screen (title, menu, run HUD, pause, report card, welcome gift, Closet)
**When** it is checked at 640×360
**Then** targets are at least 32 px tall and all UI text at least 16 px (NFR7), and findings are fixed or listed in the story file

**Given** grayscale screenshots of the zombie hands and HUD
**When** they are reviewed
**Then** the active finger and wrong-key feedback are still clear without color (NFR8)

**Given** all player-facing text
**When** it is reviewed
**Then** every label uses words a 6-year-old can read, zombie slang appears only in voice and flavor, and no technical error text can appear (NFR9, NFR16)
**And** no difficulty labels, ranks or timers outside runs exist anywhere (NFR10, NFR11)

### Story 5.3: Technical Metrics on Family Computers

As Smuck,
I want proof that the MVP runs smoothly and keeps saves on real family computers,
So that I can share the link with confidence.

**Acceptance Criteria:**

**Given** a 2018-era laptop with integrated graphics (or the closest available) in desktop Chrome, Edge and Firefox
**When** a full 2:00 Zombie Run with 12+ conga followers is recorded with the browser performance tools
**Then** it holds 60 FPS with no frame over 33 ms (NFR1), and results are recorded in the story file

**Given** the same machine
**When** input feedback is checked
**Then** a correct key shows target advance and effect start on the next rendered frame (≤ 17 ms) (NFR2)

**Given** the Pages link
**When** first and cached loads are timed at 25 Mbit/s
**Then** first load is ≤ 10 s and cached load ≤ 3 s, with the compressed size recorded against 40 MB (NFR3)

**Given** Chrome and Firefox
**When** 10 consecutive reloads and 10 tab closes mid-menu are done after earning brains and buying an item
**Then** no data is lost (NFR4)

**Given** a real Zombie Run (not the test screen) in Chrome and Firefox
**When** Space, `'`, `/`, Backspace and Tab are pressed during a run and while paused
**Then** the page never scrolls and quick-find never opens; in the menu afterwards, normal browser keys work again

**Given** the target laptop's 1366×768 screen
**When** the game runs windowed and in fullscreen
**Then** it fills the window, and the 16 px text is readable from a normal seating distance (a note per browser goes in the story file)

**Given** the Windows Desktop export
**When** it is run on one Windows PC
**Then** it starts, plays a Zombie Run and keeps its save across a restart (NFR8 fallback smoke check)

**Given** 3 different family computers
**When** someone opens the link
**Then** the game loads and plays without help (NFR17)
**And** any failure becomes a fix item for Story 5.5

### Story 5.4: First Kid Playtest

As Smuck,
I want to watch at least one kid play the MVP before I share it,
So that I learn whether it's fun and fix what confuses them.

**Acceptance Criteria:**

**Given** a playtest plan in the story file (observer checklist, no coaching, questions for after play)
**When** at least 1 kid aged 6–13 plays a first session
**Then** the notes record whether they started a second Zombie Run unprompted and bought an item in the first session (core hypothesis)
**And** after the session the save is exported with Ctrl+Shift+E, and the notes record accuracy from its run history, any moment of confusion, and whether they found anything scary or (for 11–13) "babyish"

**Given** a 6-year-old playtester (if available)
**When** they play with the full keyboard
**Then** the notes record whether it frustrated them, as input to the GDD's "home-row-only first run" designer note

**Given** the playtest notes
**When** they are triaged
**Then** each finding is marked must-fix-before-publish, post-MVP backlog, or no action

### Story 5.5: Playtest Fixes and Publish the MVP Link

As Smuck,
I want to fix the must-fix items and publish the link,
So that family and friends can play Zombies Teach Typing.

**Acceptance Criteria:**

**Given** the must-fix items from Stories 5.3 and 5.4
**When** they are fixed
**Then** each fix has a passing test or a re-check noted in the story file, and CI is green

**Given** the release build on GitHub Pages
**When** a fresh browser profile opens the link
**Then** the full MVP loop works: title → menu → Zombie Run → report card → welcome gift → Closet → buy and wear → play again with the hat visible
**And** the debug overlay and cheats are absent from the release build

**Given** the published link
**When** it is shared
**Then** the release is published by pushing the `v1.0.0` tag (the CI deploys only from tags), and a short plain-words "how to play" note (physical keyboard, desktop Chrome/Edge/Firefox) accompanies the link

---

## Epic 6: Horde Rush

Horde Rush is selectable and playable end to end: words spawn zombie copies down 5 lanes against the Farmer defender, and arrivals earn brains. Includes the offline word-tagging tool and a tagged starter word list (fixed 3–5 letter band).

### Story 6.1: Word Tagging Tool and Starter Word List

As the developer,
I want a headless tool that tags words by keyboard rows and length, and a small kid-safe starter list,
So that Horde Rush has words now and the full curriculum can reuse the same tool later.

**Acceptance Criteria:**

**Given** `tools/tag_words.gd`
**When** it runs with `godot --headless -s tools/tag_words.gd` on a plain word list
**Then** it writes `data/content/words.json` where each word has its rows (home, top, bottom) and length (FR66)
**And** words with non-letters, uppercase or duplicates are rejected and reported

**Given** a starter list of at least 200 kid-safe lowercase words (no scary, violent, rude or brand words), reviewed by Smuck
**When** it is tagged
**Then** at least 150 words fall in the 3–5 letter band used before Epic 7 (FR59)

**Given** the tagging logic
**When** GUT runs
**Then** row and length tagging pass for sample words (e.g. `dad` → home, 3; `quiz` → top+bottom+home, 4)

### Story 6.2: Word Target Mode

As a kid,
I want to type whole words, with each letter turning green as I go,
So that I can see my progress through the word.

**Acceptance Criteria:**

**Given** `WordSource` (a `TargetSource`) filtered to a length band from `words.json`, using the run RNG
**When** words are drawn
**Then** the same word never appears twice in a row

**Given** the HUD target area in word mode
**When** a word is being typed
**Then** typed letters turn green, the next letter is underlined, and the zombie hands show the finger for the next letter (FR54, FR15)

**Given** the last letter of a word is typed correctly
**When** it is judged
**Then** `target_completed(word)` fires with no Space needed, the next word appears in the same frame, and the run's implied-space count rises by 1 for WPM (FR7, FR54)
**And** Space stays ignored in Horde Rush (FR3)

**Given** `test_word_source.gd` and word-mode `TypingSession` tests
**When** GUT runs
**Then** word completion, implied spaces and no-immediate-repeat pass

### Story 6.3: Horde Rush Field, Spawning and Size Classes

As a kid,
I want every word I finish to send a copy of my zombie marching toward the house,
So that fast typing builds a bigger horde.

**Acceptance Criteria:**

**Given** `horde_rush` extending `LevelBase`, registered in `level_registry.tres` with `available = false` (the menu still shows "Coming soon"), and `data/levels/horde_rush.tres`
**When** it is started from the debug "Test level" menu with `level_id = &"horde_rush"`
**Then** a 5:00 run starts on a 5-lane field with zombies entering at the left and the house on the right edge (FR53, FR59)

**Given** a completed word
**When** `on_target_completed` runs
**Then** a copy of the player zombie wearing the equipped hat spawns in a random lane (run RNG) and marches toward the house (FR54, FR43)

**Given** the word length
**When** the copy spawns
**Then** its size class, crossing time, hits to stop and arrival brains come from the config: ≤3 small (8 s, 1, 1), 4–5 medium (10 s, 2, 2), ≥6 big brute (13 s, 3, 3) (FR55)
**And** each zombie's logical progress is tracked separately from its sprite, per "logic leads, visuals chase"

### Story 6.4: Pacing Defender, Projectiles and Melting

As a kid,
I want a silly defender who throws tomatoes at my zombies,
So that there's a goofy challenge to beat with fast typing.

**Acceptance Criteria:**

**Given** the defender in front of the house
**When** the run is running
**Then** it paces continuously at 1 lane per 0.6 s and reverses at the top and bottom lanes (FR56)

**Given** the defender is level with a lane that has a zombie
**When** its 0.8 s cooldown allows
**Then** it throws at the front-most zombie in that lane, and the projectile takes 1.0 s to cross the field

**Given** a projectile reaches its zombie
**When** it hits
**Then** the zombie flashes red for 0.15 s; on its final hit it falls and melts into the ground over 0.6 s and earns nothing (FR56)
**And** hits use logical positions, never sprite positions

**Given** the defender logic with a fixed seed
**When** a headless simulation runs
**Then** pacing, targeting and hit counts are deterministic and pass unit tests

### Story 6.5: Arrivals, Brains and Run End

As a kid,
I want my zombies that reach the house to grab brains,
So that getting through the defence pays off.

**Acceptance Criteria:**

**Given** a zombie reaches the house door
**When** it arrives
**Then** it shuffles in, requests a (throttled) "Brainsss" and pops its size class's brains (1 / 2 / 3), adding them to the level's total (FR57)
**And** the level emits `brains_earned_changed` on every award, so the shared HUD counter updates (FR14)

**Given** the clock reaches 5:00
**When** the run ends
**Then** typing stops, a short outro plays, a +25 completion bonus is added, and the report card shows the stats (WPM includes implied spaces) and the bonus line (FR57, FR7)
**And** quitting mid-run keeps arrival brains with no bonus and no history record (FR13)

### Story 6.6: Farmhouse, Farmer and March Music

As a kid,
I want Horde Rush to look like a sunny farm with a funny farmer,
So that it feels like a new place to play.

**Acceptance Criteria:**

**Given** the Farmhouse + Farmer pair
**When** it is drawn
**Then** it includes the house, the farmer's pacing and throw animations, tomato projectiles, a red-flash and melt effect, the Horde Rush size classes (player sprite scaled), and a lane backdrop, all following the style sheet; no guns (FR58, NFR10, NFR13)

**Given** the hat on the medium and big brute size classes
**When** they march
**Then** the hat sits correctly through anchors plus scale

**Given** a march music loop (60–120 s) and zombie-spawn, throw, hit and melt sounds
**When** Horde Rush is played
**Then** they play through `AudioManager` and are credited in `CREDITS.md`

### Story 6.7: Horde Rush Tuning and Stress Check

As Smuck,
I want Horde Rush tuned so kids at different speeds get a fair share of brains,
So that no level becomes the one kids grind.

**Acceptance Criteria:**

**Given** a headless simulation that feeds words at 10 WPM and 30 WPM with fixed seeds
**When** it runs
**Then** about 40% of zombies arrive at 10 WPM and about 70% at 30 WPM; defender numbers are adjusted in `horde_rush.tres` until they do

**Given** the economy parity rule
**When** brains per minute at 5, 10 and 20 WPM are compared with Zombie Run
**Then** Horde Rush is within ±20% (NFR15), adjusting arrival brains or the completion bonus as the GDD note suggests; the final numbers are recorded in the story file

**Given** a stress scene with 30 zombies on screen
**When** it runs on the web build
**Then** no frame exceeds 33 ms (NFR1); if it does, pooling is added for zombie copies
**And** a kid playtest confirms the defender feels goofy, not frustrating, checked against a named manual checklist written in the story file (what to look for, pass/fail per item)

**Given** tuning is done and the kid playtest passed
**When** `horde_rush.available` is set to true
**Then** the menu card is selectable once unlocked (Story 6.8), and the next version tag after Story 6.8 publishes it

### Story 6.8: Level Unlocks

As a kid,
I want the next level to open after I finish the one before it, with a fun moment when it does,
So that I have something to aim for, and a surprise when I get there.

**Acceptance Criteria:**

**Given** `LevelDef` in `level_registry.tres`
**When** it is inspected
**Then** each level has an `unlocked_by: StringName` (empty for Zombie Run, `&"zombie_run"` for Horde Rush, `&"horde_rush"` for Pitchfork Panic)

**Given** save schema v2
**When** a v1 save loads
**Then** `migrate_1_to_2` adds `level_unlocks: {}` and backfills it: every level whose `unlocked_by` level has a run in `run_history` with `end_reason == &"timer"` is saved as unlocked with its moment not yet seen (so existing players see the moment on their next menu visit)
**And** `test_save_schema.gd` covers the migration with a fixture file

**Given** `PlayerData.record_run(result)`
**When** the result's `end_reason` is `&"timer"` and a level has `unlocked_by == result.level_id` and is not yet unlocked
**Then** that level is saved as unlocked and `level_unlocked(level_id)` is emitted; quit runs never reach this path (FR13, FR79)

**Given** a level card whose level is `available` but not unlocked
**When** the menu shows it
**Then** it shows the Locked state (dusk tint and padlock only); while it has focus a hint sign hangs below it ("Finish Zombie Run to open!"); Enter or a click only wiggles the card (FR79, DESIGN.md level-card)
**And** a level with `available = false` shows Coming soon whatever its lock state

**Given** an unlocked level whose moment has not been seen
**When** the main menu is shown (from any route)
**Then** the unlock moment plays once (EXPERIENCE.md Level Unlocks), `PlayerData.mark_unlock_seen(level_id)` saves it, and focus moves to that card
**And** any arrow key, Enter, Esc or click during the animation finishes it instantly and is then handled normally

**Given** a card showing "New!"
**When** it is chosen for the first time
**Then** the badge is cleared and that is saved

**Given** `test_player_data.gd` and `test_level_unlocks.gd`
**When** GUT runs
**Then** the unlock-on-timer, no-unlock-on-quit, one-time-moment and backfill cases pass
**And** the debug overlay gains "Unlock all / Relock all" (debug builds only)

---

## Epic 7: Adaptive Curriculum

A new save's placement run sets a hidden tier, and later runs silently use the right keyboard rows (Zombie Run) and word lengths (Horde Rush). Full 1,500-word list with validated tier pools.

New save fields go inside the profile, never at the top level, so Epic 11 needs no migration.

### Story 7.1: Tier Calculator with Hysteresis

As a kid,
I want the game to quietly match my typing level and not bounce me down after one bad run,
So that practice always feels just right and never feels like a demotion.

**Acceptance Criteria:**

**Given** `TierCalculator` (pure, in `scripts/typing/` or `scripts/core/`) and tier floors in a config Resource (8 / 15 / 22 / 30)
**When** it is given a run history
**Then** it averages the WPM of the most recent 1–5 completed runs across all levels, excluding quit runs, without rounding (FR60)

**Given** a current tier and the average
**When** the tier is computed
**Then** it goes up as soon as the average reaches the next floor, and goes down only when the average is below the current floor − 2, in which case it becomes the tier whose range contains the average, skipping tiers if needed (FR62, FR63)
**And** 14.5 WPM is tier 2; tier 3 drops to tier 2 only below 13 WPM

**Given** `test_tier_calculator.gd` with scripted run histories
**When** GUT runs
**Then** rising, holding in the hysteresis band, single drops, multi-tier drops, fewer than 5 runs and quit-run exclusion all pass

**Given** run history exported (Ctrl+Shift+E) from the playtest saves
**When** per-level WPM is reviewed before this story closes
**Then** the story file records whether per-level weighting is needed (GDD designer note), and any weighting is added to the config and tests

### Story 7.2: Placement Run and Hidden Tier

As a new player,
I want my first Zombie Run to find my level without any test or menu,
So that I start at the right difficulty without being labelled.

**Acceptance Criteria:**

**Given** a save with `placement_done = false`
**When** its first Zombie Run completes
**Then** that run uses all 26 letters, its WPM sets the starting tier, and `placement_done` is set (FR61)
**And** a quit placement run does not set the tier or the flag

**Given** any later completed run
**When** it is recorded
**Then** `PlayerData` recomputes the tier with `TierCalculator` and saves it

**Given** any screen
**When** it is shown
**Then** the tier and rolling average never appear anywhere (FR60, NFR10)

**Given** an MVP save (tier 0, `placement_done` false, existing history)
**When** it is loaded after this update
**Then** it works without a schema migration, because the fields already exist in v1; if history already has completed runs, the tier is computed from it and placement is marked done

### Story 7.3: Master Word List

As a parent,
I want a big list of safe, familiar words,
So that my kid practises real words and never sees anything inappropriate.

**Acceptance Criteria:**

**Given** a master list of about 1,500 lowercase words authored by Claude
**When** it is checked
**Then** it is cross-checked against the public-domain Dolch sight-word lists, and excludes scary, violent, rude or brand words (FR65)

**Given** the list
**When** Smuck reviews it once by hand
**Then** removals are applied and the review is recorded in the story file before the list is used in any build

### Story 7.4: Tier Word Pools and Validation

As the developer,
I want each tier's word pool generated and checked automatically,
So that no tier ever runs short of words.

**Acceptance Criteria:**

**Given** the tagging tool from Story 6.1 run on the master list
**When** it finishes
**Then** it writes each tier's pool (words using only the tier's rows, within its length band) and a pool validation report (FR66, FR62)

**Given** the validation report
**When** it is checked
**Then** tier 1 has at least 40 home-row words of 2–3 letters and every other tier meets a minimum count set in the tool (at least 100 words per tier unless the story records a reason)
**And** CI fails if any tier falls below its minimum

### Story 7.5: Zombie Run and Horde Rush Follow the Tier

As a kid,
I want the letters and words I get to match what I'm ready for,
So that I learn one keyboard row at a time.

**Acceptance Criteria:**

**Given** the profile's tier
**When** a Zombie Run starts after placement
**Then** its letter pool is the tier's rows: tier 1 home row, tier 2 home + top, tiers 3–5 all 26 letters (FR64)
**And** the run record stores the letter pool or tier used

**Given** the profile's tier
**When** a Horde Rush starts
**Then** `WordSource` draws from the tier's pool with its length band (2–3, 3–4, 3–5, 4–6, 5–8) instead of the fixed 3–5 band (FR62)

**Given** any tier
**When** Zombie Run pacing or the Horde Rush defender is checked
**Then** nothing about their speed or behaviour changes with the tier (FR64)

**Given** a new save played by a fast typist and a new save played by a beginner
**When** each finishes placement and plays two more runs
**Then** they silently see different rows and word lengths (end-to-end check for the Epic 7 deliverable)

---

## Epic 8: Pitchfork Panic

Pitchfork Panic is selectable and playable: tier-appropriate paragraphs or generated sentences, a step-by-step chase from an accelerating mob, brain pickups, and Caught / Escaped! endings.

New save fields go inside the profile, never at the top level, so Epic 11 needs no migration.

### Story 8.1: Paragraphs and Sentence Generator

As a kid,
I want funny zombie stories to type, and simple sentences when I'm still learning,
So that practising real writing feels like part of the game.

**Acceptance Criteria:**

**Given** `data/content/paragraphs.json`
**When** it is checked
**Then** it holds about 40 original goofy, zombie-themed passages in plain words, 2–4 sentences and 150–400 characters each, about 13 per tier for tiers 3, 4 and 5 (FR67)
**And** a validator confirms tier 3 uses only letters, spaces and `. , ! ?`; tier 4 adds numbers and apostrophes; tier 5 may use any punctuation in the set; Smuck reviews the passages once

**Given** a `SentenceGenerator` for tiers 1–2 using the tier's word pool and the run RNG
**When** it generates a sentence
**Then** the sentence has 4–7 words, a capital first letter and ends with `.`; tier 2 may also include `,` (FR67, FR62)
**And** unit tests check word count, capitalisation, punctuation and that every word is in the tier pool

### Story 8.2: Paragraph Target Mode

As a kid,
I want to see my text in two lines, with the part I've typed turning green,
So that I can read ahead and keep my place.

**Acceptance Criteria:**

**Given** `ParagraphSource` (a `TargetSource`) for the profile's tier
**When** text is shown
**Then** the target area shows a 2-line window: typed characters green, the next character underlined, the next line dimmed; passages flow continuously and the next passage starts when one ends (FR69)
**And** paragraph lines are at least 24 px tall and both lines plus the zombie hands fit in the 104 px band
**And** passages are joined by a single Space: the last line ends with a visible space marker, typing Space starts the next passage, and that Space counts as a typed key

**Given** Pitchfork Panic's `LevelConfig` (`case_sensitive = true`, `space_is_input = true`)
**When** capitals, punctuation and Space are typed
**Then** they must match exactly, and the zombie hands light the character's finger plus the opposite pinky for Shift (FR4, FR17)

**Given** a save
**When** passages are chosen
**Then** no passage repeats until every passage in its tier has been used, tracked per save (FR68)
**And** the new used-passages field is added through a schema v1 → v2 migration with a fixture test

### Story 8.3: Chase Movement, Mob and Camera

As a kid,
I want every letter I type to move my zombie one step away from the mob,
So that typing faster really feels like escaping.

**Acceptance Criteria:**

**Given** `pitchfork_panic` extending `LevelBase`, registered with `available = false` (the menu still shows "Coming soon"), and `data/levels/pitchfork_panic.tres`
**When** it is started from the debug "Test level" menu with `level_id = &"pitchfork_panic"`
**Then** a chase run starts (the menu card is enabled in Story 8.7) (FR74)

**Given** a running chase
**When** a correct character is typed
**Then** the zombie's logical position moves 1 step forward in the same frame and the sprite chases it (FR70)

**Given** the mob model from the config
**When** the run starts
**Then** the gap is 15 steps and the mob moves at 4 WPM-eq (1 WPM-eq = 5 steps/min), gaining +1 WPM-eq every 10 s of run time (FR70)
**And** the gap uses logical positions and freezes while paused

**Given** the camera
**When** the chase runs
**Then** it keeps the zombie at 60% of screen width, the mob's distance is always readable, and the mob is visible on screen whenever the gap is under 20 steps (FR71)

### Story 8.4: Brain Pickups on the Path

As a kid,
I want to scoop up brains along the path as I type,
So that typing more earns more.

**Acceptance Criteria:**

**Given** the path
**When** pickups are placed
**Then** each is 10–30 steps (uniform random with the run RNG) after the previous one, and each is worth 5 brains (FR72)

**Given** the zombie's logical position reaches a pickup
**When** it is collected
**Then** 5 brains are added, a pickup sound plays and the brain total updates
**And** the level emits `brains_earned_changed` on every award, so the shared HUD counter updates (FR14)

### Story 8.5: Caught and Escaped! Endings

As a kid,
I want getting caught to be funny, and escaping to feel like a big win,
So that every chase ends with a laugh and I keep what I earned.

**Acceptance Criteria:**

**Given** the mob's logical position reaches the zombie
**When** it is caught
**Then** input stops, a cartoon dust cloud plays (1.5 s), the zombie sits dazed with circling stars and a "Got you!" label (1.0 s), the screen fades (0.5 s) and the report card appears; all brains are kept (FR73)

**Given** the run reaches 5:00
**When** the zombie is still ahead
**Then** it dives through a hedge, gate or bush (1.5 s), "Escaped!" shows and the report card appears with a +25 bonus (FR73)

**Given** any caught or escaped run
**When** the result is built
**Then** a +10 finished-run bonus is added and the end reason (`caught` / `escaped`) is recorded (FR73)
**And** a quit run gets no bonus and no history record (FR13)
**And** the Pitchfork Panic card follows FR79 (Locked until a Horde Rush reaches 0:00) with no new code

### Story 8.6: Moonlit Village, Mob and Chase Music

As a kid,
I want the chase to look goofy-spooky, never scary,
So that it's exciting without giving me nightmares.

**Acceptance Criteria:**

**Given** the Moonlit Village setting, a mob made of 2 recolored base sprites with torches and pitchforks, the dust cloud and dizzy stars
**When** they are drawn
**Then** they follow the style sheet and read as cartoon villagers, not scary (NFR10, NFR13), approved by Smuck

**Given** a chase music loop (60–120 s) and the dust-cloud and pickup sounds
**When** the level is played
**Then** they play through `AudioManager` and are credited in `CREDITS.md`

### Story 8.7: Chase Tuning

As Smuck,
I want the chase tuned so beginners get a fair run and fast typists can escape,
So that every run ends in a fun crescendo.

**Acceptance Criteria:**

**Given** a headless simulation typing at a steady 5, 10 and 20 WPM with fixed seeds
**When** it runs
**Then** runs last about 70 s at 5 WPM and about 2.4 min at 10 WPM, and about 19+ WPM usually escapes; the start gap and acceleration in the config are adjusted until they do

**Given** the economy parity rule
**When** brains per minute are compared with Zombie Run at the same WPM
**Then** Pitchfork Panic is within ±20% (NFR15), and the final numbers are recorded in the story file

**Given** tuning is done
**When** `pitchfork_panic.available` is set to true
**Then** the menu card is selectable (FR74), and the next version tag publishes it

---

## Epic 9: Full Crypt Closet

All 18 Closet slots can be bought and worn, with hats fitting every pose and Horde Rush size class.

### Story 9.1: Eight New Hats

As a kid,
I want lots of silly hats to save up for,
So that I always have a next goal.

**Acceptance Criteria:**

**Given** the 8 remaining hats (Witch hat, Bunny ears, Santa hat, Leprechaun hat, Valentine heart headband, New Year's top hat, Pirate hat, Golden crown)
**When** they are drawn as overlays
**Then** they follow the style sheet and each has a `CosmeticItem` at its row price (FR75)

**Given** the hat fit-check scene from Story 4.3
**When** each hat is shown on every player-zombie frame, Professor Zombie's pose and all 3 Horde Rush size classes
**Then** every hat sits correctly; any anchor fixes are made in the `SpriteAnchors` data, not by redrawing sprites

### Story 9.2: Eight New Pets

As a kid,
I want lots of cute pets to keep me company while I type,
So that collecting feels fun.

**Acceptance Criteria:**

**Given** the 8 remaining pets (Black cat, Spider, Orange cat, Bat, Crow, Wolf-dog, Floating eyeball, Brain buddy)
**When** they are drawn
**Then** each has an idle animation (2–6 frames), follows the style sheet, stays cute rather than scary, and has a `CosmeticItem` at its row price (FR75, NFR10)

**Given** each pet in the HUD pet slot, on the report card and on the menu
**When** it is shown
**Then** it fits the slot and never covers the target or stats

### Story 9.3: Full Catalogue Live

As a kid,
I want every Closet slot to be something I can buy,
So that there are no more "Coming soon" signs.

**Acceptance Criteria:**

**Given** the catalogue
**When** all 18 items have `is_available = true`
**Then** the Closet shows no "Coming soon" tiles, and every item can be bought and worn with the existing flow (FR75)

**Given** an existing save with owned MVP items
**When** it loads after the update
**Then** owned and equipped items are unchanged and the brain balance is intact

---

## Epic 10: Art Variety & Trends

Each level rotates between 3 looks with no immediate repeat, and a trends screen shows WPM, accuracy and practice time plus lifetime totals.

### Story 10.1: Random Theme Rotation

As a kid,
I want each level to look a bit different each time I play,
So that it stays fresh even after many runs.

**Acceptance Criteria:**

**Given** a list of themes per level in the level registry (each theme: backdrop scenes and, for Horde Rush, a house + defender pair)
**When** a run starts
**Then** one theme is picked at random from that level's list, never the same as the level's previous run (FR76)
**And** the last theme per level is saved through a schema migration with a fixture test

**Given** any theme
**When** the level is played
**Then** the rules, timings and tuning are identical; only art and music may differ (FR76)

**Given** a level that currently has only 1 theme
**When** a run starts
**Then** that theme is used without error, so themes can be added one at a time

### Story 10.2: Pumpkin Patch Farm and Snowy Town

As a kid,
I want new places for Zombie Run,
So that my runs feel like trips to different towns.

**Acceptance Criteria:**

**Given** the Pumpkin Patch Farm and Snowy Town backdrops (sky, far, near, ground tiles) and matching villager recolors if needed
**When** they are added as Zombie Run themes
**Then** they tile seamlessly for a full run, keep target letters readable, and follow the style sheet (FR76, NFR13)

### Story 10.3: Castle + Knight and Beach Hut + Lifeguard

As a kid,
I want new houses and defenders in Horde Rush,
So that the siege stays surprising.

**Acceptance Criteria:**

**Given** Castle + Knight (suction-cup darts) and Beach Hut + Lifeguard (water balloons)
**When** they are added as Horde Rush themes
**Then** each has its house, defender pacing and throw animations, projectile and lane backdrop, uses the same defender tuning, and contains no guns (FR58, FR76, NFR10)

### Story 10.4: Cornfield Path and Spooky Forest Bridge

As a kid,
I want new chase settings in Pitchfork Panic,
So that each escape feels like a new adventure.

**Acceptance Criteria:**

**Given** Cornfield Path and Spooky Forest Bridge, each with a place for the Escaped! dive (hedge, gate or bush)
**When** they are added as Pitchfork Panic themes
**Then** they reuse the mob sprites, keep the text and mob distance readable, and stay goofy rather than scary (FR74, FR76, NFR10)

### Story 10.5: Trends and Lifetime Stats Screen

As a parent,
I want a simple screen showing how my kid's typing is improving,
So that I can see the practice is working.

**Acceptance Criteria:**

**Given** a trends screen reachable from the main menu
**When** it opens
**Then** it shows WPM, accuracy and practice time over recent runs as simple charts, and lifetime totals: keys typed, best WPM, total brains and time practised (FR77)
**And** it uses plain words, no ranks or difficulty labels, and never shows the tier (NFR9, NFR10)

**Given** a save with no completed runs
**When** the screen opens
**Then** it shows a friendly empty state instead of empty charts

**Given** the lifetime totals
**When** they are computed
**Then** they include history beyond the 500-run cap by keeping running totals in the profile (added through a schema migration with a fixture test)

---

## Epic 11: Profiles & Zombie Naming

Two kids on one computer keep separate named zombies with their own brains, cosmetics, history and tier; the MVP save becomes the first profile.

### Story 11.1: Name the Existing Zombie

As a kid who already plays,
I want to give my zombie a name when profiles arrive,
So that my brains and hats are clearly mine.

**Acceptance Criteria:**

**Given** a save whose active profile has an empty name
**When** the game starts after this update
**Then** a plain-words screen asks for a zombie name (letters and spaces only, 1–12 characters) with the existing profile's brains, items, history and tier untouched (FR78)
**And** the name is saved in the profile and never logged (NFR12)

**Given** the profile-shaped save from v1 (ADR-2)
**When** this story ships
**Then** no data migration of existing profile contents is needed, only the name is filled in

### Story 11.2: "Who's Playing?" Picker and New Zombies

As a kid sharing a computer,
I want to pick my own zombie when the game starts, or make a new one,
So that my sibling's runs never mix with mine.

**Acceptance Criteria:**

**Given** a save with one or more profiles
**When** the title screen moves on
**Then** a "Who's playing?" screen shows each zombie (name, hat, pet) and a "New zombie" button, usable by keyboard and mouse (FR78, FR25)

**Given** "New zombie"
**When** a name is entered
**Then** a new profile is created with defaults (0 brains, no items, no history, placement not done), becomes active and goes to the main menu

**Given** a picked profile
**When** it becomes active
**Then** `PlayerData` switches to it, `active_profile` is saved, and all signals refresh the menu, counters and cosmetics

### Story 11.3: Fully Separate Zombies

As a parent,
I want each zombie's progress kept completely separate,
So that one kid's bad day never changes the other kid's game.

**Acceptance Criteria:**

**Given** two profiles
**When** each plays runs, buys items and gets a welcome gift
**Then** every profile field that exists at the time (brains, owned and equipped items, flags, settings, bests, history, and tier and used passages if Epics 7 and 8 have landed) stays separate per profile (FR78)
**And** GUT tests cover switching profiles and confirm no data crosses between them

### Story 11.4: Zombie Name on Menu and Report Card

As a kid,
I want to see my zombie's name on the menu and report card,
So that the game feels like it's really mine.

**Acceptance Criteria:**

**Given** an active profile with a name
**When** the main menu or report card is shown
**Then** the name is displayed near the zombie in the pixel font, with a way to switch zombies from the menu (FR78)
