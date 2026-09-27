---
title: 'Game Brief: Zombies Teach Typing'
status: final
created: '2026-09-27'
updated: '2026-09-27'
inputs:
  - _bmad-output/brainstorming-session-2026-09-27.md
---

# Game Brief: Zombies Teach Typing

## Executive Summary

Zombies Teach Typing is a small, goofy typing tutor for kids aged 6–13, in the spirit of the 1990s classic *Mario Teaches Typing*, with one twist: **the kid is the zombie.** Instead of blasting zombies, the player's own named zombie shambles through three short, replayable lessons, hugging villagers into a conga line, sending a horde of copies at a defended house, and fleeing a torch-and-pitchfork mob. Every correct key moves the zombie forward, and every lesson ends on a chalkboard report card.

Under the humor sits a real typing curriculum. Single letters come first, then words, then full paragraphs with punctuation. Keys unlock row by row (home, then top, then bottom), and an invisible system tunes the challenge to each kid's actual skill rather than their age. Brains earned by playing buy hats and pets in the Crypt Closet, so practice has a visible payoff.

This is a non-commercial passion project, built by one developer on occasional weekend mornings as a hands-on way to learn the BMAD/BMGD AI-assisted development workflow. It ships as a browser game that friends and family can open from a link.

## Vision

**Core fantasy:** *You're a lovable cartoon zombie, and the better you type, the more mischief you get up to.*

**Elevator pitch:** Mario Teaches Typing meets Plants vs. Zombies, from the zombie's side: three bite-sized typing lessons where kids play a goofy zombie that gets faster, stronger and better-dressed the better they type.

**Player experience:** Kids should walk away feeling *clever and a bit mischievous*, never drilled or judged. Parents should see a practice tool their kid chooses to open. Sessions are short (5–15 minutes) and the tone is goofy but never babyish, so a 13-year-old doesn't feel talked down to and a 6-year-old never gets scared.

## Target Players & Market

**Primary:** Kids aged 6–13 who are learning or improving touch typing, playing on a family computer or laptop in short bursts (after school, before dinner). Skill varies widely and doesn't track age: a fast 8-year-old and a beginner 13-year-old must both be well served.

**Secondary:** Parents (and possibly teachers) who want a friendly practice tool and a simple view of progress.

**Distribution reality:** Friends and family via a shared web link. There is no commercial market goal, so success means *kids in the author's circle actually choose to play it*.

## Core Fundamentals

**Genre:** Educational typing game / arcade mini-games.

**Core loop (every level):** A target letter or word appears in a fixed spot at the bottom of the screen, and green zombie hands light up the correct finger. The kid types it. A correct key triggers an immediate reward (bonk a brain, zombify a villager, spawn a zombie, outrun the mob). A wrong key simply doesn't count; nothing happens until the right key is pressed. After a timed run (or getting caught), a chalkboard report card shows keys typed, errors, WPM, accuracy, time and brains collected, and the brains feed the Crypt Closet.

**Gameplay pillars:**
1. **You're the goofy zombie.** The player is always the zombie, the role reversal is the hook, and all "violence" is cartoonish (hugs, melting, fleeing).
2. **Typing is the only skill.** No lane choices, strategy or menus mid-run. All challenge comes from typing, and wrong keys block rather than punish.
3. **Adapts to skill, invisibly.** A placement run, then a rolling average of the last 5 runs' WPM, scopes which keyboard rows appear and how long words are. The kid never sees a rank or a "demotion".
4. **Small, classic and finishable.** 90s-style sprites, one shared HUD/report-card frame, variety through art rather than rules, and a hard line on scope.

**The three levels** (standalone, replayable, chosen from a menu):
- **Zombie Run** (letters, 2 min, calm): bonk brain blocks and hug letter-carrying villagers into a conga line. The first run is a full-keyboard placement test.
- **Horde Rush** (lowercase words, 5 min, rising pressure): each word spawns a zombie in a random lane (longer word, bigger zombie) that marches on a house guarded by one pacing defender. Each arrival earns a brain.
- **Pitchfork Panic** (paragraphs with capitals, punctuation and numbers, survival): type to stay ahead of an accelerating mob and grab randomly spawned brains until caught.

**Meta layer (full vision):** Profiles ("Who's playing?") with a named zombie per kid; lifetime stats and a trends view; brains spent in the **Crypt Closet** on cosmetics only (a 3×3 hat grid and a 3×3 pet grid, priced 100/200/300 by row). A one-time welcome bonus after the first run leads into the first purchase.

## References & Differentiation

| Title | Taking | Deliberately not taking |
|---|---|---|
| *Mario Teaches Typing* (1990s) | Level-select structure, a letter-per-target gimmick level, glove/finger-guide HUD, chalkboard report card with a mascot professor, profiles | Licensed mascot; dated difficulty selection by menu |
| *Plants vs. Zombies* | Goofy, kid-safe zombie tone; lane-based siege (Horde Rush) | Strategy, resource placement and defender building; the player never makes tactical choices |
| *The Typing of the Dead* | Proof that zombies + typing works | Horror tone, shooting zombies, adult audience |

**Also in the space:** browser typing trainers and typing games (school curriculum tools, typing-racer and typing-shooter games). The market is crowded, but this project doesn't need to win it.

**Genuine differentiators (honest, not moats):**
- The player *is* the zombie, a rare framing for a kids' typing game.
- Difficulty adapts to measured skill without the kid ever seeing it (sibling- and bad-day-proof).
- The curriculum is built into the structure (letters → words → paragraphs; home → top → bottom row).
- The real edge, if any, is charm and execution, not features.

## Scope & MVP

**Platforms:** Web (Godot HTML5 export), primary. Windows desktop as a fallback if a web constraint blocks something.

**Team & timeline:** One developer, occasional weekend mornings, no deadline. Art is **AI-generated by Claude** (see Content & Direction).

**Technical constraints:**
- Godot 4.7 with the **Compatibility renderer** (required for web export; switched from Forward+ on 2026-09-27).
- **GDScript only, no C#**, because C# web export has historically been unsupported in Godot 4.
- Saves live in browser storage (`user://` maps to IndexedDB on web), so progress is per-browser and lost if site data is cleared. This is acceptable for a family project.
- Browser keyboard quirks (shortcuts such as Ctrl+W, Tab, and audio that only starts after the first click or keypress) need handling.

**MVP (the first shareable link):**
- **Main menu** with a level select (Zombie Run playable; Horde Rush and Pitchfork Panic shown as "coming soon")
- **A single zombie save**, with no profile picker yet
- **Zombie Run**, complete: brain blocks, villagers + conga line, finger-guide hands, shared HUD, 2-minute timer, blocking input, one backdrop
- **Chalkboard report card** with keys typed, errors, WPM, accuracy, time and brains
- **Crypt Closet** with **one hat and one pet**, buy and equip, with the pet shown in the HUD and the hat on the zombie
- **Welcome bonus** so the first purchase is possible after one run
- Local save of brains, owned/equipped items and per-run stats
- **Deferred from MVP:** adaptive difficulty and row scoping (the MVP uses the full keyboard, but stats are saved so the system can be added later), profiles and zombie naming, the trends screen, randomized art, Horde Rush, Pitchfork Panic, and the remaining 16 cosmetics

**The MVP validates the core hypothesis: *is typing as a goofy zombie fun enough that a kid chooses to play a second run, and to earn a hat?***

**Post-MVP order:** Horde Rush (the most novel level), then adaptive difficulty with row unlocking, then Pitchfork Panic, then filling out the cosmetics, then art variety and the trends screen. Profiles slot in whenever siblings start sharing the game.

## Content & Direction

**World and narrative:** None beyond the premise. Each level is a standalone, self-explanatory scene, with no story, dialogue or lore. All text uses plain words a 6-year-old can read.

**Content breadth (full vision):** 3 levels; about 3 art themes per level; 18 cosmetics (9 hats including year-round holiday hats, 9 pets); graded word lists filtered by keyboard row; paragraph texts for Level 3. Replayability comes from short timed runs, personal bests, brains and art variety.

**Art direction:** 2D, early-90s pixel-art feel inspired by Mario Teaches Typing: bright, readable sprites, a cartoon zombie with a big goofy face, green zombie hands in the HUD. Kid-safe, with no gore. **Production approach:** Claude generates the art as code-authored pixel art or vector (SVG) sprites. This caps visual fidelity at a simple, clean style, which suits the 90s direction. Keep the sprite count low, and reuse and recolor wherever possible.

**Audio direction:** Restrained. Ambient zombie groans every 3–8 seconds at random (never on every keypress), an occasional "Brainsss…" on brain pickups, and light background music that doesn't become grating for older kids. Audio comes from free sound libraries or simple generated sounds.

## Risks & Open Questions

**Risks:**
- **Scope creep versus weekend-morning capacity.** *Mitigation:* the MVP is one level, and every other feature waits in the post-MVP queue.
- **AI-generated art quality and consistency.** A code-generated sprite style may look inconsistent across assets. *Mitigation:* define a tiny palette and sprite-size standard first, and prototype the zombie and one villager before committing.
- **Web export surprises** (keyboard capture, audio unlock, save persistence). *Mitigation:* do a hello-world web export in the first session, before building gameplay.
- **Is Zombie Run fun on its own?** It is the calmest level, and the brief bets the MVP on it. *Mitigation:* test with a real kid as early as possible.
- **Difficulty tuning across ages 6–13** (post-MVP). Needs real playtest data; the saved per-run stats provide it.

**Open questions for the GDD:**
- Exact WPM → difficulty mapping (row-unlock thresholds and word-length bands).
- Brain payout per level, and the welcome-bonus amount against the 100/200/300 prices.
- Naming overlap: "Zombie Run" is the calm level while Pitchfork Panic is the actual chase.
- Remaining cosmetic slots, the three art themes per level, and the Level 3 "caught" moment.
- Word-list and paragraph sources (age-appropriate, row-filterable).
