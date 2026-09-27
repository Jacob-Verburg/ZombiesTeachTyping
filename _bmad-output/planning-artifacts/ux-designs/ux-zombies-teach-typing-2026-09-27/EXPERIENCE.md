---
name: zombies-teach-typing
status: final
created: 2026-09-27
updated: 2026-09-27
form_factor: Desktop web (keyboard + mouse), Windows fallback
sources:
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md
  - _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/decision-log.md
  - _bmad-output/game-architecture.md
  - _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/.decision-log.md
---

# EXPERIENCE.md — Zombies Teach Typing

> **Spines win.** `DESIGN.md` (how it looks) and this file (how it works) are the contract; on conflict with any mock, wireframe, layout sketch or import, the spines win. The UX decision log (`.decision-log.md`, D1–D16) is canonical and overrides upstream sources where they disagree — see **Upstream changes required**.

**Visual references** (F8): [Main Menu mock](mockups/key-main-menu.html), [Run HUD mock](mockups/key-run-hud.html) (letter + word mode, wrong key), [Report Card mock](mockups/key-report-card.html). Spine-only, no mock: Title, boot splash, pause panel + countdown, Welcome Gift, Crypt Closet + confirm prompt, paragraph-mode HUD. The layout-sketch gates on Stories 2.5 and 4.4 still apply.

## Foundation

- **Form factor:** desktop web in Chrome, Edge and Firefox (Safari best-effort), on a family desktop or laptop; Windows desktop export as a fallback. Mobile and touch are out of scope (GDD Platform-Specific Details).
- **Input:** a physical keyboard is required; typing is the only gameplay input. Mouse drives menus and the in-run pause button only. US QWERTY is assumed for the finger guide; matching is by typed character (GDD A1).
- **Engine / UI system:** Godot 4.7, Compatibility renderer, GDScript. All UI is Control nodes styled by one Theme, `data/ui_theme.tres`. Screen flow is the `Router` autoload (`Router.go(screen, payload)`) with a CanvasLayer fade (ARCH D1). This spine specifies **only the behavioral delta** over Godot Control defaults.
- **Canvas:** fixed 640×360 logical, fractional scaling, nearest filter (U1). Visual identity: `DESIGN.md`.
- **Audience:** kids 6–13, reading at a 6-year-old level; parents secondary (GDD Target Audience). Stakes: hobby (D3).

## Information Architecture

Screens map 1:1 to `Router.Screen` (ARCH Screen Flow). Mocked surfaces link to their mock.

| Surface | Reached from | Purpose | Leaves to |
|---|---|---|---|
| Boot splash (web) | Opening the link | Load progress in game style (D11) | Title |
| Title | Boot | Logo + "Click or press any key"; unlocks browser audio | Main Menu |
| [Main Menu](mockups/key-main-menu.html) | Title, Report Card (Menu), Closet (Esc), Pause (Quit to Menu) | Zombie with hat + pet, brain counter, 3 level cards, Crypt Closet button, Music / Sound / Fullscreen toggles, storage notice when needed | Run, Crypt Closet |
| [Run](mockups/key-run-hud.html) (`RunFrame`) | Level card, Play Again | Playfield + shared HUD band; pause panel and countdown overlay it | Report Card, Main Menu (quit) |
| [Report Card](mockups/key-report-card.html) | Run end (timer / caught / escaped) | Chalkboard stats, Professor Zombie, New best! | Run (Play Again), Main Menu, Welcome Gift (first completed run ever) |
| Welcome Gift | Report Card, once per save | +100 brains, one button | Crypt Closet |
| Crypt Closet | Main Menu, Welcome Gift | 3×3 hats + 3×3 pets, preview zombie, brain counter; first-visit tutorial | Main Menu (Esc) |

Flow (GDD Screens & Flow, FR24): `Title → Main Menu → [Level → Report Card → (Welcome Gift → Crypt Closet, first time only) → Play Again | Menu] | Crypt Closet`.

- Nothing is more than one step from the main menu. Pause replaces nothing: it overlays the frozen run.
- After a first purchase, the way to play in the new hat is Closet → Esc → Menu → level card (2 steps, deliberate for MVP; Story 4.5 design note).
- **Main menu hierarchy:** level cards are the primary focus; the zombie (with hat and pet) is the emotional anchor; brain counter and Closet button second; toggles and the storage notice last.
- **HUD hierarchy:** see HUD & Diegetic UI.

## Voice and Tone

Microcopy. Brand voice lives in `DESIGN.md` Brand & Style. Every label uses words a 6-year-old can read; zombie slang ("Brainsss…") lives only in voice lines and flavor art, never in labels (NFR9). No technical error text ever reaches the player (NFR16).

| Context | Copy (verbatim from sources unless tagged) |
|---|---|
| Title | "Click or press any key" |
| Run, before first key | "Type the letter to start!" / "Type the word to start!" / "Type the text to start!" |
| Caps Lock | "Caps Lock is on" |
| Pause | "Resume" · "Quit to Menu" · "Music" · "Sound"; panel title "Paused" `[ASSUMPTION]` |
| Report card stats | "Keys Typed" · "Errors" · "WPM" · "Accuracy" · "Lesson Time" · "Brains Collected" · "+N bonus" |
| Report card | "New best!" · "Play Again" · "Menu"; key hints "Enter" / "Esc" beside the buttons `[ASSUMPTION — from mock]`; board heading = the level name, e.g. "Zombie Run" (D16) |
| Pitchfork Panic endings | "Got you!" · "Escaped!" |
| Welcome Gift | "Welcome gift!" · "+100" · "Open the Crypt Closet" |
| Closet tiles | "Coming soon" · "Need N more" · "Buy" · "Wear" · "Wearing" |
| Closet confirm | "Buy the Pumpkin hat for 100 brains?" · "Yes" · "No" `[ASSUMPTION]` |
| Level card — Coming soon | "Coming soon" |
| Level card — Locked (D12, D14) | Focus-only hint: "Finish Zombie Run to open!" / "Finish Horde Rush to open!" `[ASSUMPTION — copy]`. The card itself shows only the padlock; the hint sign hangs below the card while it has focus, so the copy is no longer squeezed onto the card and can grow if needed. |
| Level card — unlocked | "New!" `[ASSUMPTION — copy]` |
| Main menu toggles | "Music" · "Sound" · "Fullscreen" |
| Storage notice | "Progress may not be saved in this browser mode" |

| Do | Don't |
|---|---|
| Short, cheerful, plain: "Need 40 more" | "Insufficient brains" |
| Praise the action, not the kid's rank | Ranks, grades, "easy mode", difficulty labels (NFR10) |
| Silence on a wrong key (just the bonk) | "Wrong!", "Oops!", red text |
| "Brainsss…" in the zombie's voice | "Brainsss" on a button |

## Component Patterns

Behavioral delta only; visual specs live in `DESIGN.md` Components. Anything not listed behaves as the Godot Control default.

| Component | Behavioral rules |
|---|---|
| **pixel-button** | Enter or click activates (Godot default commit); the press plays the squish and the UI click without delaying the action. Hovering with the mouse **moves keyboard focus** to the button, so there is only ever one highlighted control `[ASSUMPTION]`. Disabled buttons are skipped by arrow navigation. |
| **panel-wood / panel-stone** | Non-interactive containers. |
| **sign** | Non-interactive text. |
| **level-card** | Arrow-focusable in a row; Enter/click on *Available* or *New* starts the level via `Router.go(RUN, {level_id})`. *Locked* and *Coming soon* stay focusable but Enter/click does nothing except a soft "nope" wiggle and no sound `[ASSUMPTION]`. *Locked* shows only its padlock at rest; the hint sign appears below the card while it has focus (arrow focus or hover, which moves focus) and hides when focus leaves (D14). Cards are driven by `level_registry.tres` `available` + the D12 unlock rule; see Level Unlocks. |
| **closet-item-tile** | Arrow keys move within and between the two 3×3 grids; focusing (or hovering) a tile shows it on the preview zombie. Enter/click acts by state: *Buy* → confirm-prompt; *Wear* → equip, becomes *Wearing*; *Wearing* → take off, becomes *Wear*; *Can't afford* and *Locked — coming soon* → nothing (tile wiggles). Exactly one state per tile (FR40). |
| **confirm-prompt** | Modal; focus trapped between Yes and No. Default focus on **Yes** so the tutorial arrow path is Enter-Enter `[ASSUMPTION]`. Esc = No. Yes buys, plays the purchase jingle, updates the brain counter, saves immediately (FR41). No changes nothing. |
| **toggle** | Enter/click flips it. Music/Sound mute the matching bus and save via `PlayerData.set_setting()`; restored on launch (FR46). Fullscreen calls `WebPlatform.toggle_fullscreen()` **from the input callback** (browser gesture rule), reflects `is_fullscreen()` each time the menu shows, and is **not saved**. Same Music/Sound toggles appear on the pause panel (U4). |
| **chalkboard** | Non-interactive. Stats appear in order on open; see Game Feel. |
| **new-best-stamp** | Shown when the run beats that level's best WPM; never on a level's first run (FR20). |
| **tutorial-arrow** | Closet from Welcome Gift with `tutorial_seen` false: points at the first affordable item → Buy → Yes → Wear in turn; ends (and sets `tutorial_seen`) when the first item is worn or the kid leaves the Closet (FR45). Never blocks other input. |
| **welcome-gift-card** | Single button, pre-focused; Enter/click goes to the Closet. Grants +100 and sets `welcome_bonus_claimed` on show (Story 4.5). |
| **storage-notice** | Shown on the main menu only when `OS.is_userfs_persistent()` is false; non-interactive, never dismissable, never blocks (ARCH Persistence check). |
| **title-prompt** | Any key or click advances and calls `AudioManager.unlock()` from that input (FR23). |
| **boot-splash** | Web only; shows load progress until the title screen is ready. No interaction. |
| **brain-counter** | Shown on the main menu, the Closet and the HUD of **every** level (D15). Updates immediately on any brain change (`PlayerData` signal); counts up with a short tick on gains (see Game Feel). |
| **hud-band** | Fixed; never hides during a run. |
| **target-letter / target-word / target-paragraph** | Driven by `TypingSession`; the next target is shown in the **same frame** as the correct key (≤ 17 ms, NFR2). Word: typed letters green, next letter underlined; completes on its last letter, no Space. Paragraph: 2-line window, current line green/underlined, next line dimmed; passage ends with a visible space marker; Space starts the next passage and counts as a key (E8-1). |
| **zombie-hands** | On `target_changed(next)`, the next character's finger(s) light; Shift characters also light the opposite pinky; Space lights both thumbs; f/j bumps always shown (Story 2.6). |
| **key-hint** | Non-interactive label beside a report-card button naming its key `[ASSUMPTION — from mock]`. |
| **stats-column** | Timer shows time left and counts down to 0:00, starting on the first correct key (GDD Win/Loss); Keys Typed and Errors update the same frame as each judgment; WPM hidden for the first 5 s of run time, then updates at 1 Hz (FR8). |
| **caps-lock-hint** | Appears on `caps_lock_suspected` (3 consecutive capitals in lowercase levels), hides on `caps_lock_cleared` (FR5). Never pauses or blocks. |
| **pause-button** | Click only (mouse); same as Esc. Not keyboard-focusable during a run so typing never lands on it `[ASSUMPTION]`. |
| **pause-panel** | Pre-focus **Resume**. Arrows/Enter/click. Esc on the panel = Resume `[ASSUMPTION]`. Quit to Menu keeps brains, awards no bonus, records no run (FR13). |
| **countdown** | 3-2-1 at 0.5 s each; world stays frozen; all typing rejected; focus loss returns to Paused (ARCH RunFrame). |
| **pet-slot / hat-slot** | Update on `equipment_changed` everywhere at once; empty shows nothing; a missing texture never stops a run (Story 4.3). |

## State Patterns

| Surface | State | Treatment |
|---|---|---|
| Boot splash | Loading | Styled splash with progress bar (D11). Slow network: bar keeps moving; no text beyond the logo `[ASSUMPTION]`. |
| Title | Audio locked | Silent until the first key/click; that input both advances and unlocks audio. |
| Main Menu | First visit (fresh save) | Brain counter 0; zombie with no hat or pet; Zombie Run card focused; other cards Coming soon (MVP) or Locked (post-MVP). |
| Main Menu | Returning | Focus on the card of the level just played `[ASSUMPTION]`; brain counter current. |
| Main Menu | Unlock pending | Unlock moment plays once on arrival, then focus moves to the new card (see Level Unlocks). |
| Main Menu | Storage not persistent | storage-notice visible; everything else normal. |
| Main Menu | Fullscreen on/off | Toggle reflects `is_fullscreen()` on every menu show (browser Esc may have exited). |
| Run | Waiting for first key | First target + "Type the … to start!"; timer shows the full run length, WPM hidden; zombie idles. Pausing here and resuming keeps the clock stopped. |
| Run | Running | Live HUD; wrong key → shake + bonk only. |
| Run | Caps Lock suspected | caps-lock-hint shown; letters still accepted (lowercase levels). |
| Run | Paused (Esc / button / tab blur) | World and clock frozen; pause-panel over scrim; keys still swallowed (`capture_keys` true for the whole run). |
| Run | Countdown | 3-2-1; typing rejected; blur → back to Paused. |
| Run | Ending | Input stops; end animation (Zombie Run dance 2.0 s; caught/escaped sequences per GDD Level 3). |
| Run | Level fails to load | Silent recovery to Main Menu, brains kept (ARCH error handling; NFR16). |
| Report Card | First 1.0 s | Enter/Esc/clicks ignored (mash guard, FR21). |
| Report Card | New best | Stamp shown. |
| Report Card | First run of a level | No stamp (sets the best silently). |
| Report Card | Bonus earned | Separate "+N bonus" line. |
| Report Card | Quit run | Never reached — quitting goes straight to the menu. |
| Welcome Gift | Once per save | After the first **completed** run's report card; never again. |
| Crypt Closet | Tutorial active | tutorial-arrow on the current step; everything else still usable. |
| Crypt Closet | Nothing affordable | All live tiles show "Need N more"; no arrow (tutorial can only start from the gift, which guarantees 100). |
| Crypt Closet | Confirm open | Modal; grids unreachable until Yes/No. |
| Crypt Closet | Empty slots | Preview zombie with no hat / no pet; valid, not an error. |
| Any screen | Save write fails | Silent; nothing shown to the kid beyond the storage notice (ARCH). |
| Any screen | Router transition | Quick fade; input to the outgoing screen is ignored during the fade `[ASSUMPTION]`. |

## Interaction Primitives

- **Type a character** — the only gameplay action. Correct → accepted instantly, next target same frame. Wrong printable → no progress, Errors +1, bonk (≤ 1 per 150 ms), target shakes 0.2 s. Ignored keys never count as errors (GDD M1).
- **Esc** — pause during a run; back one level in menus and the Closet; Menu on the report card (after 1.0 s); No on the confirm prompt.
- **Enter** — select / confirm in menus; Play Again on the report card (after 1.0 s). Never an input during typing.
- **Arrow keys** — move focus in menus, level cards, Closet grids, prompts (FR25).
- **Mouse click / hover** — every menu control; the pause button in a run. Never required for typing.
- **Any key / click** — advance the title screen.
- **Banned:** combos, multipliers, health, lives, timing windows, mid-run choices, timers outside runs, hold-to-confirm, drag and drop, right-click, scroll wheel.

## HUD & Diegetic UI

See the [Run HUD mock](mockups/key-run-hud.html) (its Horde Rush frame predates D15 and lacks the brain counter; this section wins).

- **Non-diegetic:** the entire HUD band (pet slot, target sign, zombie hands, stats column, brain counter), the pause button, pause panel, countdown and caps-lock hint. It is one shared frame in every level and never changes layout between levels (GDD Pillar 4; M2b). The **brain counter is in every level's HUD** — every level earns brains, so every level shows the count (D15; overrides GDD M2b, see Upstream changes).
- **Diegetic / in-world:** the targets themselves in the playfield (Zombie Run brain blocks and villagers each carry their letter on a parchment tag; the active one bobs under a candy-yellow down-arrow and matches the HUD target `[ASSUMPTION — from mock]`), the conga line (with "×N" badge beyond 12), Horde Rush lane zombies, the Pitchfork Panic mob distance. These *are* the progress feedback — there is no score bar.
- **Hierarchy in the band:** (1) target — biggest, centered, never moves; (2) zombie hands — directly under the target so eyes don't travel; (3) stats and brain counter — quiet, right side, glanceable; (4) pet — delight, left side, idle only.
- **Nothing hides during active play.** Nothing fades on idle. The HUD is the same the whole run.
- **Readability:** targets ≥ 32 px, paragraph ≥ 24 px, all other text ≥ 16 px (NFR7) — tokens in `{typography.target}`, `{typography.paragraph}`, `{typography.label}`.

## Input Schemes

- **Keyboard (required):** typing reads `InputEventKey.unicode`, not InputMap actions; menus use Godot's `ui_*` actions (arrows, Enter = `ui_accept`, Esc = `ui_cancel`) (ARCH Input).
- **Browser key capture:** during a run (including pause and countdown) Space, `'`, `/`, Backspace and Tab are swallowed so the page never scrolls and quick-find never opens; in menus normal browser keys work (ARCH `capture_keys`; Story 5.3).
- **Case:** Zombie Run and Horde Rush accept a letter regardless of Caps Lock/Shift; Pitchfork Panic is case-sensitive (GDD M1).
- **Mouse:** menus, Closet, report card buttons, pause button.
- **Remapping:** none — targets are characters, menus use fixed `ui_*` keys `[ASSUMPTION — not specified upstream]`.
- **Not supported:** gamepad, touch (GDD Out of Scope). No prompt-glyph adaptation needed; on-screen key references use plain words ("Enter", "Esc").
- **Hidden parent/dev input:** Ctrl+Shift+E on the main menu downloads `save.json`; invisible to kids, no UI (G3).

## Game Feel & Juice

**Gentle** (D9). Two standing rules override everything here: **animation never delays typing**, and **no screen shake**. All values are `[ASSUMPTION]` starting points for tuning unless cited.

| Moment | Response |
|---|---|
| Correct key | Next target in the same frame; level reward animation plays concurrently and may overlap or be skipped at speed (GDD M1). Soft reward SFX per level. |
| Wrong key | Target glyph shakes horizontally 0.2 s (±2 px `[ASSUMPTION]`) + quiet bonk tick (≤ 1/150 ms). Nothing else moves. |
| Active finger | Pulsing candy-yellow outline, ~2 Hz `[ASSUMPTION]`, below any flash-risk threshold. |
| Button focus | Small bounce (1 px up and back, ~0.1 s) — PvZ bounciness at pixel scale. |
| Button press | Squish: drops 2 px onto its shadow, squashes ~1 frame, springs back on release; UI click SFX. Input is committed on the frame it arrives; the squish never waits. |
| Level card focus | Lifts 2 px with a gentle bob while focused. |
| Screen change | Quick Router fade (D11), ~0.15 s out / 0.15 s in `[ASSUMPTION]`; music crossfades 0.5 s (Story 5.1). |
| Report card open | Chalk-scratch as stats write on top to bottom (~0.1 s each), then the chime; "New best!" stamp thumps on last. The 1.0 s input guard runs in parallel, not after. |
| Brain gain | brain-counter ticks up with a small pop. |
| Purchase | Purchase jingle; tile flips to Wear; brain counter ticks down. |
| Unlock moment (D12) | See Level Unlocks. |

## Level Unlocks

Decision D12 (developer), overriding the GDD's "all levels unlocked from start"; D14 sets the Locked card's hint behavior. Illustrated in the [Main Menu mock](mockups/key-main-menu.html), section B (its Locked cards predate D14 and show the hint at rest).

- **Rule:** Horde Rush (Level 2) unlocks after the first **completed** Zombie Run — timer reached 0:00, not quit `[ASSUMPTION — condition]`. Pitchfork Panic (Level 3) unlocks after the first completed Horde Rush by the same rule `[ASSUMPTION]`.
- **Gates access only.** No difficulty labels, ranks or "harder" wording appear (Pillar 3, NFR10). The hint says what to play, not how hard the next level is.
- **Precedence:** a level with `available = false` shows **Coming soon** regardless of lock state. In the MVP, Levels 2 and 3 are Coming soon, so no Locked card and no unlock moment ever appear in the MVP build.
- **Locked card:** padlock only on the card (D14). While the card has focus (arrow focus or hover), a hint sign below it names the level to finish; it hides when focus leaves. Enter/click → wiggle, no start.
- **Unlock moment:** plays the **first time the main menu is shown after the qualifying run**, whatever the route (Report Card → Menu, Pause → never qualifies, Welcome Gift → Closet → Esc → Menu, or after several Play Agains). Sequence `[ASSUMPTION — motion values]`: menu fades in normally → ~0.3 s beat → padlock on the card wiggles, pops off and falls away (a showing hint sign leaves with it `[ASSUMPTION]`) → purple tint clears to full color → "New!" badge thumps on with a short jingle → keyboard focus moves to the newly unlocked card. **Input is live throughout**: any arrow/Enter/Esc/click completes the animation instantly and is processed normally.
- **Persistence:** "unlock seen" must be saved per level so the moment plays once; requires a save field (see Upstream changes required). Saves that already contain a qualifying run when the feature ships see the moment on their next menu visit `[ASSUMPTION]`.
- **Storage not persistent:** unlocks follow the save; if the save is lost, the level re-locks. Accepted (same as brains).

## Accessibility Floor

Behavioral; contrast ratios live in `DESIGN.md` Colors.

- **Keyboard-complete:** every menu, the Closet and every prompt work with arrows/Enter/Esc alone; everything also works by mouse (FR25). Typing never needs the mouse.
- **Never color alone:** finger, typed-text and tile states use brightness plus shape (pulse outline, underline, check mark, toggle slash, padlock vs plank) (NFR8). Grayscale review in Story 5.2.
- **Reading level:** every label a 6-year-old can read; no slang in labels; no technical errors (NFR9).
- **No pressure outside runs:** no timers on menus, report card or Closet (NFR11). Report card input guard is 1.0 s only.
- **Audio optional:** fully playable muted; Music and Sound toggles on the menu and pause panel, saved (GDD Session Length & Accessibility; U4). No information is carried by sound alone (the wrong-key bonk has the shake).
- **Interruptions are free:** auto-pause on tab/window blur; 3-2-1 countdown before input resumes (GDD M3). Windows-fallback auto-pause is deferred (G5).
- **Motion:** gentle only; no screen shake; no flashing faster than 3 times per second `[ASSUMPTION]`. No reduced-motion toggle is planned (juice is already minimal).
- **Readability floors** per HUD & Diegetic UI; pixel font with distinct `l`/`I`/`1`, `O`/`0`.
- **Not in scope:** screen readers (canvas-rendered game), remapping, non-US finger maps.

## Responsive & Platform

- **One layout.** The 640×360 canvas scales to fill the browser window with fractional scaling and nearest filtering; slight pixel unevenness at non-whole scales is accepted (U1). Aspect is kept; letterbox bars are `{colors.night}` `[ASSUMPTION]`.
- **Target check:** a maximised Chrome/Edge/Firefox window on a 1366×768 laptop must fill the available height and keep 16 px text readable from a normal seat (Story 1.2, 5.3).
- **Fullscreen:** a menu toggle (not saved; browsers start windowed). The browser owns Esc for leaving fullscreen.
- **Windows fallback:** identical UI and save contents; no boot splash difference required; auto-pause on focus loss deferred (G5).
- **Safari:** best-effort; no UI adaptation.

## Inspiration & Anti-patterns

- **Lifted from *Mario Teaches Typing* (D1, D7), all of:** big picture level cards; the player's character standing on the menu; chunky framed panels; hand-drawn signs; chalkboard feel beyond the report card (it's also the HUD stats column); finger-guide hands and a report card as structure. Era: early-90s / late-DOS.
- **Lifted from *Plants vs. Zombies* (D2, D8), all of:** chunky rounded wood/stone panels; bouncy squishy buttons; warm saturated colors; hand-lettered signs; goofy, kid-safe zombies.
- **Rejected — *The Typing of the Dead* (D2):** gritty/gory horror tone, guns, adult framing.
- **Rejected — arcade scoring:** combos, multipliers, health, lives (GDD Input & Judgment Model; Pillar 2).
- **Rejected — visible difficulty:** difficulty menus, ranks, tiers, "easy mode" (Pillar 3).
- **Rejected — heavy juice:** screen shake, hit-stop, anything that makes the next key wait (D9).

## Key Flows

### Flow 1 — "Jacob, 8, first time playing, on the family desktop after school in the year 1992"

Mocks: [Main Menu](mockups/key-main-menu.html) (steps 2, 8), [Run HUD](mockups/key-run-hud.html) (steps 3–4, 9), [Report Card](mockups/key-report-card.html) (step 6).

Protagonist verbatim from D10. "1992" is era framing for the look and feel (the menus should feel like that desktop); the practical surface is the family computer's browser, keyboard and mouse. **This flow needs the post-MVP build** (Horde Rush `available = true` and the D12 unlock rule); in the MVP, the Horde Rush card reads "Coming soon" and the climax cannot happen.

1. His mom opens the shared link. The boot splash — night sky, logo, a pumpkin-orange bar — fills and gives way to the title screen. Jacob presses Space; the menu music starts with it.
2. **Main menu.** His zombie is standing right there on the menu, no hat yet, beside three picture cards. Zombie Run is bright and already focused, bouncing gently. Horde Rush and Pitchfork Panic are purple-tinted, each with a big padlock. He arrows over to Horde Rush and a little sign drops in below it: "Finish Zombie Run to open!" He presses Enter anyway; the card wiggles. Fine. He arrows back and picks Zombie Run.
3. **Zombie Run, waiting.** The HUD says "Type the letter to start!" above a big **f**; on the green zombie hands, the left pointer finger glows and pulses. He looks for f, hits g — the f wobbles, a soft bonk, Errors 1. He finds f. The timer starts, his zombie hops and bonks a brain block, a brain pops out.
4. **Zombie Run, running.** He hunts and pecks, the hands moving each time. After 5 seconds WPM appears. He bumps Caps Lock by accident — three letters later "Caps Lock is on" appears, but his letters still count. Villagers get hugged into a conga line behind him.
5. His sister calls him; he clicks the other browser tab. The run auto-pauses. He comes back to the pause panel, clicks Resume; 3, 2, 1 — then he can type again. *(Failure path: if he'd chosen Quit to Menu, he'd keep his brains but the run wouldn't count — Horde Rush stays locked, and arrowing onto it still shows "Finish Zombie Run to open!")*
6. **0:00.** His zombie and the conga line dance. The chalkboard report card writes itself out, stat by stat, with Professor Zombie pointing. No "New best!" — it's his first run. He mashes Enter and nothing happens for a second; then Enter moves on.
7. **Welcome gift!** +100 brains; he opens the Crypt Closet and buys the Pumpkin hat (Flow 2). Esc takes him back to the menu.
8. **Unlock moment.** The menu fades in. A beat — then the padlock on the Horde Rush card wiggles, pops off and bounces away, the purple drains into full color, and a "New!" badge thumps on with a jingle. Focus jumps to the card. He presses Enter.
9. **Climax — it plays differently.** The HUD band is the same, the hands are the same — but the sign says "Type the word to start!" and shows a whole word: **dad**. He types d; it turns green and the underline slides to a. He finishes the word — no Space needed — and a copy of his zombie, *wearing his pumpkin hat*, shuffles off down a lane toward a farmhouse while the next word is already waiting. It's not the letter game any more. He leans in.
10. At 5:00 the report card shows his first Horde Rush; he hits Play Again.

Failure / edge paths: quit mid-run → no unlock (step 5); storage not persistent → notice on the menu, and the unlock (like brains) may not survive a browser restart; if he'd played Zombie Run again instead of going to the menu, the unlock moment simply waits for his next menu visit.

### Flow 2 — Jacob's first Crypt Closet purchase *(derived from GDD M5 and Story 4.5; no developer narration)*

1. After his first completed run's report card, Enter shows the Welcome Gift card: "+100" with one pre-focused button, "Open the Crypt Closet".
2. The Closet opens: two 3×3 grids. The Pumpkin hat and Cute ghost show price 100; the other 16 tiles are "?" silhouettes marked "Coming soon". Brain counter: his run's brains plus 100.
3. The candy-yellow tutorial arrow bobs beside the Pumpkin hat (first affordable item). He arrows to it; the preview zombie tries it on.
4. Enter → Buy → the confirm prompt; the arrow moves to Yes. Enter.
5. Purchase jingle; brain counter ticks down by 100; the tile flips to Wear and the arrow points at Wear.
6. **Climax:** Enter → Wearing. His preview zombie has a pumpkin on its head. The tutorial is over for good.
7. The Cute ghost now reads "Need N more" — his next goal (about 3 runs away, GDD Economy). Esc → menu, where his zombie is wearing the hat.

Failure path: if he presses Esc before wearing anything, the tutorial ends anyway (`tutorial_seen` set) and never returns; the hat can still be bought any time.

## Upstream changes required

Route through **gds-correct-course** after this UX is finalized:

1. **D12 level gating vs GDD/epics.** GDD Win/Loss ("nothing is locked"), Level Progression ("All levels are unlocked from the start"), Difficulty Curve ("nothing is gated"), Curriculum Model ("all levels are open from the start"), M4 ("no learning content is ever gated") and Pillar 3 wording; epics FR26 and Story 4.2 (card states), plus a new save field for per-level "unlock seen" (ARCH save contents, Story 4.1/`PlayerData` flags) and unlock logic reading run history end reasons.
2. **D11 styled web boot splash vs sprint-change-proposal**, which deferred the custom boot splash ("the default Godot splash stays for now"). The UX log accepts a styled splash; it needs a story (Epic 5 candidate) or an explicit re-deferral.
3. **D15 brain counter in every level vs GDD/epics.** GDD M2b and Story 2.5 say "Zombie Run adds a brain counter"; change to "the brain counter shows in every level's HUD".
4. **Layout sketch ACs** (Stories 2.5, 2.9, 4.2, 4.4, and the 5.0 art pass): add "conforms to DESIGN.md tokens and EXPERIENCE.md patterns" so the sketches inherit the spines.

## Open Questions

1. **Pixel font** — which SIL OFL font (D11 deferred); its native size must divide 16/24/32/64 px.
2. **Unlock condition (D12)** — confirm "first completed run, not quit" and that Level 3 follows Level 2 by the same rule.
3. **Locked-card and unlock copy** — "Finish Zombie Run to open!" / "New!" are placeholders; the focus-only hint sign (D14) leaves room for longer copy.
4. **Esc in browser fullscreen** — the browser consumes Esc to leave fullscreen; confirm whether a run should also pause (likely yes via the resulting focus/resize events) and test in Story 5.3.
5. **Hover moves focus** — confirm the single-highlight rule (mouse hover sets keyboard focus).
6. **Confirm-prompt default** — Yes pre-focused (fast tutorial) vs No (safer against mash-buying).
7. **"New!" badge lifetime** — until first chosen, or only for the one menu visit.
8. **Main-menu initial focus on return** — last-played card vs always Zombie Run.
