---
baseline_commit: 91ed00cfbc3b45a452e1569c14fbc56cf5b4adff
---
# Story 5.4: First Kid Playtest

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Smuck,
I want to watch at least one kid play the MVP before I share it,
so that I learn whether it's fun and fix what confuses them.

## Acceptance Criteria

1. **Playtest plan.** **Given** this story file **When** the session starts **Then** `## Playtest Plan` holds the setup steps, an observer checklist, the no-coaching rules (what the observer may and may not say), and the questions for after play, and Smuck has seen it before the session (Gate A).
2. **Core hypothesis.** **Given** at least 1 kid aged 6–13 playing a first session on a fresh save **When** the session ends **Then** `## Session Notes` records, per kid: whether they **started a second Zombie Run unprompted** (observed, not read from the save: quit runs are never saved) and whether they **bought an item in the first session** (and whether it was only the guided purchase or one they chose on their own) (GDD Success Metrics, Pillar 1).
3. **Save export and run data.** **Given** the session is over **When** the kid's save is exported with Ctrl+Shift+E on the main menu **Then** the export file is kept (see Gate A for where), and the notes record from its run history: number of finished runs, accuracy per run and the median, WPM per run, brains, owned and worn items (via `tools/playtest/summarize_save.py`).
4. **Confusion and tone.** **Given** the observer checklist **When** the session is watched **Then** the notes record every moment of confusion (where, what the kid did, how long, whether they got past it alone), whether the kid found anything scary, and, for an 11–13-year-old, whether they called it "babyish" (asked directly after play; GDD Success Metrics, Tone).
5. **6-year-old full keyboard.** **Given** a 6-year-old playtester (if available) **When** they play with the full keyboard **Then** the notes record whether it frustrated them, as input to the GDD's "home-row-only first run" designer note. If no 6-year-old is available, the row is Skipped with Smuck's reason.
6. **Triage.** **Given** the playtest notes **When** they are triaged at Gate B **Then** every finding has an id (P1…) in `## Findings and Triage` and is marked **must-fix-before-publish**, **post-MVP backlog** or **no action**, by Smuck's call (recorded verbatim with the date). Must-fix items are the input to Story 5.5 next to 5.3's F1; post-MVP items go to `deferred-work.md`.
7. **Honest record.** Nothing in `## Session Notes` is written by the agent from guesswork: every entry is what Smuck reported (words kept as words, marked "observed") or what the export file shows. A check that wasn't done is "Skipped" with Smuck's reason verbatim. No game code changes in this story; the full GUT suite still passes.

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 7)**
  - [x] 1.1 Run the full GUT suite at the starting commit (`91ed00c`; 5.3 ended at **1319** passing, confirm the count yourself). Hash the real dev save (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`, sha256) before and after every suite run (the 4.5 / 5.3 real-save trap). No Windows export run is expected here.
  - [x] 1.2 Check the Pages link still serves `v0.9.0` (`https://jacob-verburg.github.io/ZombiesTeachTyping/`, title screen in the browser pane; F3 does nothing). Note that 5.3's F1 (Fullscreen toggle icon shows the wrong state) is in that build and is a known issue, not a playtest finding.
- [x] **Task 2: Save summary tool (AC: 3)**
  - [x] 2.1 New `tools/playtest/summarize_save.py`, **standard library only** (no `uv --with`, no pip install; Python is already on the dev PC). Usage: `python tools/playtest/summarize_save.py <zts-save-YYYYMMDD.json>`. It reads the exported save (the same JSON as `save.json`: `schema_version`, `active_profile`, `profiles.<id>`) and prints, for the active profile:
    - one row per `run_history` record, in order: #, local date-time (from `timestamp`, Unix seconds UTC), minutes since the previous run, `level_id`, `duration_s` as m:ss, `keys_typed`, `errors`, `accuracy` %, `wpm`, `brains`, `end_reason`;
    - totals: finished runs, median accuracy (GDD Pillar 2 target ≥ 85 %), median WPM, total keys, `best_wpm`, current `brains`, `owned_items`, `equipped` hat/pet, flags (`welcome_bonus_claimed`, `tutorial_seen`), and settings (`music_on`, `sound_on` — did the kid turn sound off?);
    - the 5 most-missed keys across all runs from `per_key` (`expected char -> [attempts, errors, {typed: count}]`): key, attempts, errors, error %, most common wrong key. This is the 6-year-old frustration evidence (AC 5).
    - `--json` prints the same numbers as one JSON object (to paste into the story file).
  - [x] 2.2 It never crashes on a hand-edited or partial save: missing fields print "—", wrong types are skipped with a one-line warning (mirror the spirit of `SaveSchema.fill_defaults`, but don't import Godot code). It never writes any file and never touches the network (NFR12).
  - [x] 2.3 `--selftest` runs the summary on a built-in fixture (2 runs, known per_key) and prints PASS/FAIL against known numbers (median accuracy, top missed key, minutes between runs). No Python test runner exists in the project and none may be installed without asking (same rule as 5.3's probe). Run it once; record the output in the Debug Log.
  - [x] 2.4 Try it on real data, two ways: (a) in the browser pane on the Pages link, reach the main menu and press Ctrl+Shift+E; confirm a `zts-save-YYYYMMDD.json` download is offered (5.3 never re-tried the chord on Pages). (b) Copy the dev `save.json` to the scratchpad (the export is byte-identical to the save, `save_service.gd:152`) and run the tool on the copy, never on the live file path. Record both in the Debug Log.
  - [x] 2.5 Short header docstring like `tools/encode_ogg.py` (what it is, how to run it, "tools/ is export-excluded, so this never ships"). LF line endings (`.gitattributes eol=lf`).
- [x] **Task 3: Playtest plan (AC: 1)**
  - [x] 3.1 Finish `## Playtest Plan` below (already drafted): adjust to what Gate A decides (computer, browser, who observes). Plain words, one check per line. Smuck prints it or keeps it on a phone beside the kid.
- [x] **Task 4: Gate A — before the session (AC: 1, 3, 5)** — ask with `AskUserQuestion`, one question per decision, recommendation first; record verbatim with the date in `## Review Approval`.
  - [x] 4.1 **Show the plan.** Point Smuck at `## Playtest Plan` and ask if anything should change.
  - [x] 4.2 **Playtester(s).** How many kids, and their ages (age only, never names: "Kid A, 8"). Is a 6-year-old available (AC 5)? Is an 11–13-year-old available (the "babyish" question)?
  - [x] 4.3 **Computer and browser.** Recommend: a family computer that is not the dev PC, in desktop **Chrome or Edge** (not Firefox: Firefox binds Ctrl+Shift+E to its Network tool and the chord is unverified there, 1.8 deferral), at 100 % zoom, with a physical keyboard and a mouse. Record the computer type (not whose it is), OS, browser version, screen size.
  - [x] 4.4 **Build.** Recommend: the `v0.9.0` Pages link as it is (no new tag; F1 is known). Re-tagging is outward-facing and needs its own explicit yes.
  - [x] 4.5 **Where the export file goes.** Recommend: copy it into `_bmad-output/implementation-artifacts/playtest/5-4/kid-a-save.json` and commit it (the save holds no personal data: profile `name` is `""` in the MVP, no accounts; check before committing). Alternative: keep it out of git and paste only the tool's `--json` output into the story file.
  - [x] 4.6 **Optional frame check.** The 5.3 deferral asks for the frame probe on the weakest family computer "e.g. during the 5.4 playtest". Recommend: **don't** run it during the kid's session (DevTools steals focus and pauses the run, FR11; it distracts from watching). If Smuck wants it, do it on the same computer after the kid is done, with `tools/perf/README.md`, and record the numbers in `deferred-work.md` under 5.3's item, not in this story's notes.
- [ ] **Task 5: The session (AC: 2–5)** — Smuck runs it; the agent can't watch. _(Skipped: no kid session)_
  - [ ] 5.1 Smuck follows `## Playtest Plan` and reports in chat (notes, quotes, the export file). The agent asks follow-up questions only for missing checklist rows, one batch, no leading questions about what the kid "probably" felt. _(Skipped: no kid session, Smuck's Gate B 2026-10-07)_
  - [ ] 5.2 Run the tool on the export (copy it into the project path from 4.5 first, or into the scratchpad if Smuck chose not to commit). Paste the `--json` output into `### Save summary` under that kid. _(Skipped: no kid session, Smuck's Gate B 2026-10-07)_
  - [ ] 5.3 Fill `## Session Notes` per kid from Smuck's report and the tool. Keep Smuck's words as words ("observed"). Cross-check: the save's finished-run count vs what Smuck saw (a quit run is not in the save: if Smuck saw 3 runs and the save has 2, one was quit — ask, and record why if known). _(Skipped: no kid session, Smuck's Gate B 2026-10-07)_
  - [ ] 5.4 More than one kid: one `### Kid X` block each. The hypothesis tally line counts toward the GDD metric "2 of the first 3 kids" (1 in Epic 5, the rest after sharing). _(Skipped: no kid session, Smuck's Gate B 2026-10-07)_
- [x] **Task 6: Findings and Gate B (AC: 6)**
  - [x] 6.1 Turn every confusion, frustration, bug, tone remark and "no" on a checklist row into a `## Findings and Triage` row (P1…): what happened, where (screen/moment), how often, a likely cause with a code or doc ref when there is one, a suggested fix, and the agent's recommendation (must-fix-before-publish / post-MVP backlog / no action). Watch-list items from the Dev Notes go in only if they actually showed up.
  - [x] 6.2 Recommend must-fix only for things that would stop or upset a kid who opens the shared link alone (can't find how to play again, scared, stuck, broken). Feel and tuning ideas are post-MVP unless the core hypothesis failed because of them.
  - [ ] 6.3 Ask Smuck per finding (batch up to 4 per `AskUserQuestion`), recommendation first. Record the answers verbatim with the date in `## Review Approval`. **No status change to review without it.** _(Replaced by one blanket answer at Gate B; one finding, P1)_
- [x] **Task 7: Wrap-up (AC: 6, 7)**
  - [ ] 7.1 `deferred-work.md`: add a "Deferred from: dev of story 5-4" section with every post-MVP finding (one line each, P-id, pointer to this story). For the existing items this playtest answers, append "**5.4 (date):** <what was seen>" or strike them with `~~…~~ Done in 5.4: …`: the dance-time arrow (5.0 item, line ~327), the 32 px letter size / squinting (5.2 item, ~469), the Caps Lock hint with Shift-held capitals (~128), accuracy/WPM rounding down (~144), Firefox Ctrl+Shift+E (~84, only if the playtest used Firefox), and Story 4.5's "Play with it!" design note (if kids got lost after buying). Leave items the playtest didn't touch alone. _(Section added; no existing items annotated because no kid evidence touched them)_
  - [x] 7.2 Add a line under the GDD success-metric tracking in `deferred-work.md`: "Core hypothesis: N of 1 kids so far (needs 2 of the first 3); the other 2 after the link is shared."
  - [x] 7.3 Full GUT suite twice (`--import` first), real `save.json` hash unchanged. No change under `scripts/`, `scenes/`, `data/`, `assets/`, `project.godot`, `export_presets.cfg` or `.github/` is expected; a needed game fix is a 5.5 must-fix row, not a change here.
  - [x] 7.4 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`. Suggested commit: `Story 5.4: first kid playtest`.

### Review Findings

Code review 2026-10-07 (Blind Hunter, Edge Case Hunter, Acceptance Auditor). 1 decision_needed, 10 patch, 2 defer, 15 dismissed.

- [x] [Review][Decision] Story moved to `review` with no kid session — Dev Notes say a story without a held session stays `in-progress`; AC 2 is conditioned on a kid playing. Smuck's Gate B answer ("mark all as good, no action") accepted the gap and P1 is "no action", but that wording could be misread as the checks passing. Options: (a) close 5.4 as `done` with every kid check explicitly Skipped (Gate B answer stands), (b) keep `in-progress` until one kid plays. **Resolved 2026-10-07: (a), close as `done`; kid checks stay Skipped.**
- [x] [Review][Patch] `as_num` passes NaN/Infinity/1e999 through, crashing `mmss`, and `--json` can emit invalid JSON; reject non-finite values (return None) [tools/playtest/summarize_save.py:29]
- [x] [Review][Patch] `datetime.fromtimestamp(ts)` unguarded; huge, inf or negative timestamps raise OverflowError/OSError/ValueError (Windows rejects negatives); wrap in try/except, fall back to None plus a warning [tools/playtest/summarize_save.py:126]
- [x] [Review][Patch] `mmss` prints a negative duration as garbage (`-5` → `-1:55`); show a dash for negatives [tools/playtest/summarize_save.py:188]
- [x] [Review][Patch] `json.load` only guards OSError/ValueError; add RecursionError. Read with `utf-8-sig` so a BOM-prefixed export (Notepad, PowerShell 5) loads [tools/playtest/summarize_save.py:308]
- [x] [Review][Patch] Wrong-typed run and profile fields become "—" silently; Task 2.2 says wrong types get a one-line warning. Add warnings in the `summarize` field reads [tools/playtest/summarize_save.py:99]
- [x] [Review][Patch] Median accuracy/WPM silently ignore runs without a value and print full float precision (`86.6666…`); show how many runs the median covers and round for display [tools/playtest/summarize_save.py:180]
- [x] [Review][Patch] Selftest has no case for non-finite numbers, out-of-range timestamps, negative duration or `print_text` on a broken save; add them [tools/playtest/summarize_save.py:258]
- [x] [Review][Patch] Tasks 5.1–5.4, 6.3 and 7.1 are `[x]` though no session, export, per-finding triage or item annotations happened; mark them skipped / not applicable with the reason [5-4-first-kid-playtest.md:50-60]
- [x] [Review][Patch] P1 row recommendation says "track in `deferred-work.md`" while Smuck's call is "no action", yet the item was still added; make the row and the file agree (note the tracking is for the watch-list, not an action) [5-4-first-kid-playtest.md:164]
- [x] [Review][Patch] Completion Notes keep the boilerplate line "Ultimate context engine analysis completed - comprehensive developer guide created." and the hypothesis line differs from Task 7.2 wording; remove the boilerplate and note the deliberate "0 of 0" wording [5-4-first-kid-playtest.md:314]
- [x] [Review][Defer] No warning when `schema_version` is missing or newer than the script knows (the game goes read-only above `CURRENT_SCHEMA`) [tools/playtest/summarize_save.py:159] — deferred, low value until the schema changes
- [x] [Review][Defer] `per_key` entries with negative counts, `errors > attempts` or non-numeric `typed` values are accepted without a warning [tools/playtest/summarize_save.py:61] — deferred, game never writes these

## Playtest Plan

_(Final after Gate A, 2026-10-07: used as drafted. One kid, aged 11–13, so the "babyish" question (5) is asked and O17 is not used. A family computer that is not the dev PC, desktop Chrome or Edge. Build: the `v0.9.0` Pages link as is, https://jacob-verburg.github.io/ZombiesTeachTyping/. The export file comes to the agent; it is committed under `playtest/5-4/`. No frame check during the session. Smuck runs it; one observer, sitting a little behind the kid.)_

**Before the kid sits down (about 5 minutes)**

1. Computer: the family computer (not the dev PC), desktop Chrome or Edge, 100 % zoom, physical keyboard and mouse, sound on at a normal level. Close other tabs.
2. **Fresh save.** Open the link once, then F12 → Application → Storage → **Clear site data**, close DevTools, reload. (Or use a new browser profile.) The kid must get the first-run welcome gift and the guided first purchase. Check: the menu shows **0 brains** and the Crypt Closet has nothing owned.
3. Go back to the title screen (reload) and leave it there. Don't start anything.
4. Have this page and a pen ready. Note the start time.

**What to say (the only coaching allowed)**

- Before: "This is a game I made. Play it however you like, for as long as you like. I can't help, I'm just watching. Tell me out loud what you're thinking if you want."
- If the kid asks a question: "What do you think?" or "Try it and see." Nothing more.
- If the kid is stuck for **60 seconds** or is getting upset: help with the smallest possible hint, and **write down exactly what you said and when**. This is a finding, not a failure.
- Never say "play again", "try the shop", "buy something" or "you can stop now". The whole point is to see whether they do these alone.
- Let them stop whenever they want. When they say they're done, or after about 15 minutes, the session is over.

**Observer checklist (tick or write a few words)**

| # | Watch for | Note |
| --- | --- | --- |
| O1 | Title screen: do they know to press a key or click? How long? | |
| O2 | Main menu: do they pick Zombie Run on their own? Do they notice the "Coming soon" cards, and does that bother them? | |
| O3 | Run start: do they understand "Type the letter to start!"? | |
| O4 | During the first run: do they look at the zombie hands (finger guide)? Keyboard hunting, or one-finger typing? Any sign of the Caps Lock hint? | |
| O5 | Wrong keys: do they notice the shake/tick? Do they get annoyed or laugh? Key-mashing? | |
| O6 | Brain blocks, villager hugs, conga line: any reaction (laugh, comment, "whoa")? | |
| O7 | End dance and report card: do they read it? Do they react to brains or "New best!"? Do they find the button to move on? | |
| O8 | Welcome gift → Crypt Closet: do they follow the arrow, buy, say Yes and Wear without help? Which item? | |
| O9 | **After buying: do they find the way back to play (Esc / back to the menu → Zombie Run)?** How long, any help? | |
| O10 | **Second run started unprompted?** (yes / no / after a hint — what hint) | |
| O11 | Do they notice their hat or pet on the zombie in the run, on the report card, on the menu? | |
| O12 | Later runs: do they go back to the Closet on their own to look at or buy something else? | |
| O13 | Pause (Esc) or clicking outside the game: did it happen, and did they get back in? | |
| O14 | Sound: did they turn music or sound off? Any sound that annoyed them? | |
| O15 | Anything scary, or anything they called "for babies"? (exact words) | |
| O16 | Any moment of confusion not listed above: where, what they did, how long, got past it alone? | |
| O17 | 6-year-old only: does the full keyboard frustrate them (sighs, giving up, asking for help finding letters)? | |
| O18 | How did the session end (they chose to stop / time up / something stopped them)? Total minutes. | |

**Right after they stop**

1. Ask the questions below, in this order, in a relaxed way. Write their exact words.
2. Then (with the kid gone or not looking): go to the **main menu** and press **Ctrl+Shift+E**. The browser downloads `zts-save-YYYYMMDD.json`. Send that file to the agent (or put it where Gate A said). If nothing downloads, write that down: it's a finding.
3. Don't clear the save afterwards. If the kid opens the game again on another day within a week without being asked, tell the agent (GDD "Return" metric; optional).

**Questions for after play**

1. "What was that game about?"
2. "What was the best part?" / "What was the worst or most boring part?"
3. "Was anything confusing?"
4. "Was anything scary?"
5. 11–13 only: "Is this game for kids your age, or for little kids?" (the "babyish" check, asked directly)
6. "Would you play it again tomorrow?" / "What would you buy next?"
7. "What do the green hands at the bottom do?"
8. Anything they want to add.

## Session Notes

_(Filled from Smuck's report and the export file. One block per kid. Words stay words, marked "observed". Not done → "Skipped: <Smuck's reason>".)_

**Session:** no kid playtest was held. Smuck instead demoed the MVP to coworkers (adults); date, computer, browser and length not reported. Smuck's report, verbatim (2026-10-07): "lets mark all as good, no action, while not a kid I gave demo to coworkers"

### Kid A (not held)

**Core hypothesis (AC 2)**

| Check | Result | Evidence |
| --- | --- | --- |
| Started a second Zombie Run unprompted | Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers" | none (no kid session) |
| Bought an item in the first session | Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers" | none (no kid session) |
| Purchase was only the guided one, or also a free choice | Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers" | none (no kid session) |

**Run data from the export (AC 3):** Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers". No kid export exists; nothing committed under `playtest/5-4/`. The export chord itself was verified on the Pages build (Debug Log 2.4a), and `tools/playtest/summarize_save.py` is ready for the first real kid's save.

**Observer checklist (O1–O18):** Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers". The coworker demo was not recorded against the checklist; no observations were reported.

**Confusion moments (AC 4):** Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers". None reported from the coworker demo.

**Tone (AC 4):** scary? Skipped (no kid). "Babyish" (11–13): Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers".

**6-year-old full keyboard (AC 5):** Skipped: no 6-year-old was available (Gate A: one kid aged 11–13), and no kid session was held: "lets mark all as good, no action, while not a kid I gave demo to coworkers".

**After-play answers (exact words):** Skipped: "lets mark all as good, no action, while not a kid I gave demo to coworkers".

### Save summary

_(No kid export. Nothing to paste.)_

**Hypothesis tally:** 0 of 0 kids (no kid playtest in Story 5.4; a coworker demo instead). The GDD target (2 of the first 3 kids) is still open and is checked after the link is shared.

## Findings and Triage

_(P1… : what happened · where · how often · likely cause (ref) · suggested fix · agent's recommendation · Smuck's call: must-fix-before-publish / post-MVP backlog / no action.)_

| Id | What happened | Where | How often | Likely cause | Suggested fix | Recommendation | Smuck's call |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1 | No kid playtested before publishing; the core hypothesis (second run unprompted + a purchase) and the kid-specific checks (tone, "babyish", confusion, finger guide) are untested. A coworker demo stood in, with no issues reported. | Whole MVP | n/a | No kid available for this story | Watch the first kids who open the shared link; count them toward "2 of the first 3" | post-MVP backlog (no game change) | **no action**: "lets mark all as good, no action, while not a kid I gave demo to coworkers" (2026-10-07) |

No other findings: the coworker demo reported none. The must-fix input to Story 5.5 is therefore 5.3's F1 only.

## Review Approval

_(Gate A and Gate B answers, verbatim with the date.)_

**Gate A (2026-10-07), Smuck's answers:**

- 4.1 Plan: "Use it as is (Recommended)"
- 4.2 Playtesters: "One kid (age in notes)"; age follow-up: "11–13" (exact age not given; no 6-year-old, so AC 5 will be Skipped with Smuck's reason at the session report; the "babyish" question applies)
- 4.3 Computer and browser: "Family PC, Chrome/Edge (Recommended)" (computer type, OS, browser version and screen size to be reported with the session)
- 4.4 Build: "v0.9.0 Pages link as is (Recommended)" (no new tag)
- 4.5 Export file: "Commit it in the repo (Recommended)" → `_bmad-output/implementation-artifacts/playtest/5-4/kid-a-save.json`, after checking it holds no personal data
- 4.6 Frame check: "Not during the session (Recommended)"

**Gate B (2026-10-07), Smuck's answer (chat, verbatim):** "lets mark all as good, no action, while not a kid I gave demo to coworkers"

- Recorded as: no kid session; every kid check Skipped with that reason; P1 (playtest gap) → **no action**; no must-fix items from 5.4. The agent did not mark any check as passed: no kid observations or export exist (AC 7).

## Dev Notes

### What this story is (and isn't)

- **Is:** prepare and record one (or more) real kid playtests of the MVP: a plan Smuck can run without the agent, a small read-only tool that turns the exported save into the numbers the AC asks for, honest session notes, and a triaged finding list feeding 5.5.
- **Isn't:** fixing anything (that's 5.5: "the must-fix items from Stories 5.3 and 5.4"); publishing `v1.0.0` or the how-to-play note (5.5); new telemetry or analytics in the game (NFR12: none, ever; the save export is the only data path and the kid's parent/Smuck carries it by hand); measuring performance (5.3; optional, Gate A 4.6).
- The agent cannot watch the kid. The story's value depends on Smuck's real observations, so the agent must never fill a note it wasn't given. If the session hasn't happened yet, the story stays `in-progress`; don't move it to review with empty notes.

### What the save can and can't tell you

- `PlayerData.record_run()` (`scripts/autoloads/player_data.gd:72`) saves **finished runs only**. A quit run (pause → Quit) is never in `run_history` (FR13). So "started a second run" is an **observation**; the save confirms only finished runs. If the counts differ, a run was quit: ask Smuck why (bored? confused? by accident?), that's a finding.
- Each run record (`RunResult.to_record()`, `scripts/typing/run_result.gd:~80`): `timestamp` (Unix s UTC), `level_id`, `duration_s` (int), `keys_typed`, `errors`, `wpm`, `accuracy` (whole %, rounded **down**: 100 only with zero errors, 2.3 decision), `brains` (level brains + completion bonus), `letter_pool_or_tier` (`"all"` in the MVP), `per_key` (`char -> [attempts, errors, {typed: count}]`), `end_reason` (`"timer"` for a Zombie Run).
- Profile fields worth reading (`scripts/core/save_schema.gd`, `profile_defaults()`): `brains`, `owned_items`, `equipped {hat, pet}`, `flags {welcome_bonus_claimed, tutorial_seen, placement_done}`, `settings {music_on, sound_on}`, `best_wpm {zombie_run}`. `name` is `""` in the MVP (Epic 11 adds names), so the export has no personal data. Still: record ages, never names, in this file.
- Brains math to sanity-check "bought in the first session": welcome gift +100 (once, after the first **finished** run). The MVP's only live items are the Pumpkin hat and the Cute ghost, **100 brains each** (`is_available = true` in `data/cosmetics/hat_pumpkin.tres` and `pet_cute_ghost.tres`; the other 16 show "Coming soon"). So after one run the kid can always afford the first item, and the guided purchase is almost certain if they follow the arrow. That's why AC 2 asks whether a purchase was **only** the guided one. A second, self-chosen purchase (the other item, about 3 runs away per the GDD pacing check), or a clear wish for one ("I want the ghost!"), is the stronger signal. A 15-minute session (~5 runs at 2:00 + screens) can reach it; a visit to the Closet just to look counts as interest (O12).

### The export chord (release-safe, main menu only)

- Ctrl+Shift+E on the **main menu** calls `SaveService.offer_export()` (`scripts/screens/main_menu.gd:97`, predicate `is_export_chord` at `:80`: no Alt/Meta, not echo, `keycode == KEY_E`). On the web it downloads `zts-save-YYYYMMDD.json` through `WebPlatform.offer_download()` → `JavaScriptBridge.download_buffer` (`web_platform.gd:78`); there's no on-screen confirmation, only the browser's download bubble. It's the one debug-style feature kept in release builds on purpose (architecture: "Save export (release-safe)").
- It does **nothing** on other screens (run, report card, Closet). Go to the menu first.
- Firefox: Ctrl+Shift+E opens the Network tool; unverified whether the game still gets it (1.8 deferral). Use Chrome/Edge. Browser storage is per browser, so a save made in Firefox can't be exported from Chrome. If a playtest happens in Firefox anyway and the chord fails, record "export failed in Firefox" as a finding (must-fix candidate for 5.5: a second chord) and take the run notes from observation only.
- 5.3 noted Ctrl+Shift+E wasn't re-tried on the Pages build (only on a local release export). Task 2.4 retries it in the pane on Pages before the session, so a broken export is found before a kid's data depends on it.
- The export is byte-identical to `save.json` (`export_json()` returns `_serialize()`), so for the tool's own testing a copy of the dev `save.json` is a fine fixture. Copy it; never point the tool at the live file path while Godot might write it.

### Screen flow the kid will meet (first session)

- `Title → Main Menu → Zombie Run → Report Card → (Enter) Welcome Gift (+100, one button "Open the Crypt Closet") → Crypt Closet with tutorial arrow (item → Buy → Yes → Wear) → Esc → Main Menu → Zombie Run …` (EXPERIENCE.md Flow; Story 4.5).
- The report card's Play Again is **replaced** by the Welcome Gift after the first finished run: the kid's first chance to start a second run is from the menu after the Closet (2 steps: Esc, then the level card). Story 4.5's design note says this is deliberate and a "Play with it!" button after Wear is the post-MVP idea **if playtests show kids get lost**. O9 exists to answer exactly that.
- From the second report card on, Play Again (Enter, after the 1.0 s guard, FR21) starts another run directly.

### Watch-list from earlier stories (only report what actually shows up)

- **Dance-time arrow** (5.0 decision: left as is, "revisit only if the 5.4 playtest shows confusion").
- **Letter size** (5.2: 32 px font, ~20 px ink for lowercase; "if playtests show kids squinting", next size 40 or 48 px + a new HUD sketch).
- **Caps Lock hint** (2.1: Shift-held capitals count as Caps Lock evidence; "revisit after playtests"). In letter mode capitals are rare; note if the hint appeared and confused anyone.
- **Accuracy/WPM round down** (2.3: "Smuck may overrule after playtest"). Note if a kid seemed disappointed by a number.
- **Coming-soon cards** on the menu (FR26): do they frustrate a kid who wants to try them?
- **Fullscreen icon** (5.3 F1, already must-fix): don't count it again; add a note only if a kid was confused by it.
- **The green hands** (FR15): the after-play question 7 checks whether the finger guide is understood at all.
- **6-year-old full keyboard** (GDD designer note, line ~259: "If the full keyboard frustrates them, pull forward a simple home-row-only first run"). The tool's top-missed keys and per-run accuracy are the numbers; O17 is the observation. Recommend post-MVP (it's Epic 7 territory: tiers, `letter_pool_or_tier`) unless the 6-year-old couldn't finish a run at all.

### Triage guidance (for the agent's recommendations)

- **Must-fix-before-publish:** a kid alone with the link would be stuck, upset, scared, or lose progress; the export failed; any player-visible technical text (NFR9/NFR16); anything gory or scary (NFR10).
- **Post-MVP backlog:** tuning, "would be nice", feature wishes (more levels, more hats), the home-row-first-run idea, a "Play with it!" button if the kid found the way back after a short hesitation.
- **No action:** one-off slips the kid fixed alone in a few seconds; things the GDD rules out on purpose (no difficulty labels, no timers outside runs, no names in the MVP).
- One kid is a tiny sample. Say so in the recommendation when a finding rests on one moment.

### Tool design notes (`tools/playtest/summarize_save.py`)

- Python stdlib only (`json`, `statistics`, `datetime`, `argparse`, `sys`). Precedent for Python in `tools/`: `tools/encode_ogg.py` (that one needs `uv --with soundfile`; this one needs nothing). Run with `python` (5.3 used it for gzip sizes).
- Read the active profile: `data["profiles"][data["active_profile"]]`, falling back to `"p1"` then the first profile, like `SaveSchema.fill_defaults`.
- Local time: `datetime.fromtimestamp(ts)` (local zone of the machine running the tool; note that in the output header). Gap = minutes since the previous record's timestamp (blank for the first).
- Median with `statistics.median` over the finished runs' `accuracy`; with 0 runs print "no finished runs" (a kid who quit every run is a big finding).
- Top missed keys: sum `per_key[char][0]` (attempts) and `[1]` (errors) across runs; sort by errors then error %; most common wrong key from the merged `{typed: count}` maps. Treat any malformed entry as absent.
- Godot writes every number as float in JSON sometimes (`SaveSchema.normalize_numbers` exists for this): accept `9.0` as `9`.
- No `.uid` or `.import` is created for `.py` files; if Godot makes stray imports under `tools/`, don't commit them.

### Existing code: read-only references (nothing changes)

- `scripts/screens/main_menu.gd` (export chord, `_unhandled_input`), `scripts/autoloads/save_service.gd` (`export_json`, `offer_export`, `export_file_name` → `zts-save-%04d%02d%02d.json` local date), `scripts/autoloads/web_platform.gd` (`offer_download`), `scripts/autoloads/player_data.gd` (`record_run`, `RUN_HISTORY_CAP` 500), `scripts/typing/run_result.gd` (record shape), `scripts/core/save_schema.gd` (profile shape), Story 4.5's welcome gift and tutorial arrow, `data/cosmetics/` prices.
- `export_presets.cfg` excludes `tools/*` in both presets, so the new tool never ships.

### Testing notes

- GUT 9.7.1: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Expect 1319 passing (no game code changed in 5.3 or here). CI grep is now `Parse Error|Compile Error|Failed to load script` (5.3 change).
- The tool's own check is `--selftest` (Task 2.3) plus one run on a real copied save (Task 2.4).
- Built-in pane: keep it on screen (a hidden pane throttles to ~1–2 fps); it sends empty `key` for `/` and `'` (2.4), irrelevant here. Ctrl+Shift+E in the pane: check the download is offered (console line `download offered: zts-save-… (N bytes)` is engine-side `Log.info`, which the release build may not print; the browser download is the proof).

### Previous story intelligence

- **5.3:** gates as `AskUserQuestion`, one question per decision, recommendation first, answers verbatim with the date; Smuck often decides to skip or pass items — record those exactly as Smuck's call, never as measured; a story-file section replace once cut half a story (5.2): match headings line-anchored when filling tables; hash the real save around every suite run; LF endings for new `.py`/`.md`; outward-facing actions (tag push, sending anything) only after an explicit yes. 5.3's open fix item F1 (Fullscreen icon) is already must-fix for 5.5. 5.3 deferred NFR1 on weak hardware "e.g. during the 5.4 playtest" (Gate A 4.6 handles it).
- **5.2:** plain-words check passed: any text a kid stumbles over in the playtest is a real finding against NFR9.
- **4.5:** the guided purchase and the deliberate 2-step way back to play; "Play with it!" waits for playtest evidence.
- **1.8:** the export chord; Firefox conflict; no tests drive `_unhandled_input` → the chord is only manually verified (Task 2.4 re-verifies on Pages).

### Git intelligence

- One commit per story, on `main`: `91ed00c Story 5.3: technical metrics on family computers (code review patches applied, done)`, `7670453 …`, `485b928 Story 5.3: frame probe tools and CI grep fix (in progress)`. 5.3 needed two commits because of the tag; this story needs one (no tag), unless Smuck wants the tool committed before the session (fine: `Story 5.4: playtest save summary tool (in progress)`).
- 5.3 added `tools/perf/` with a README; this story adds `tools/playtest/` with a docstring only (no README needed for one script).

### Project Structure Notes

- New: `tools/playtest/summarize_save.py`; optionally `_bmad-output/implementation-artifacts/playtest/5-4/kid-a-save.json` (Gate A 4.5).
- Modified: this story file, `sprint-status.yaml`, `deferred-work.md`.
- No conflicts with the unified structure: dev tools live in `tools/` (export-excluded); story evidence lives under `_bmad-output/implementation-artifacts/`.

### Project Context Rules

- No `project-context.md` exists. Binding rules from `_bmad-output/game-architecture.md`, the GDD and the spines:
  - **NFR12 privacy:** no network, analytics or personal data. The tool reads a local file and prints; it sends nothing. The story file names no child: ages only ("Kid A, 8"), computer types not owners.
  - **Save export is release-safe and read-only** (architecture, Debug Tools); don't add any other release debug feature for the playtest.
  - **Boundary 7:** debug code only in debug builds; the playtest uses the release Pages build, which has no overlay and no cheats.
  - **ADR-4:** Pages deploys only from `v*` tags; no new tag in this story without Smuck's explicit yes.
  - **NFR9/NFR10/NFR11/NFR16:** any kid-visible text problem, scary moment, pressure or technical error seen in the playtest is a finding.
  - Playtest is how the architecture validates feel ("Feel, timing, audio mix and readability are playtested manually with checklists in story files").
- Tools: Godot 4.7.2 (`/c/Program Files/Godot/Godot.exe`), GUT 9.7.1, Python (stdlib), the built-in browser pane, `gh`.

### Latest tech information

- No new libraries or engine features. Web research skipped on purpose: the tool uses only the Python standard library, and the game build under test is the existing `v0.9.0`.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.4: First Kid Playtest] (ACs); Epic 5 goal; NFR9–NFR12, NFR16, NFR17
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Success Metrics] core hypothesis (2 of first 3), Pillar 2 accuracy ≥ 85 %, Tone, Return; line ~259 home-row designer note; line ~275 economy pacing; Assumption A4
- [Source: _bmad-output/planning-artifacts/briefs/brief-zombies-teach-typing-2026-09-27/brief.md] the MVP hypothesis
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] screen flow, Welcome Gift, tutorial-arrow, report card keys
- [Source: _bmad-output/game-architecture.md] Save export (release-safe), testing strategy (feel is playtested), NFR12
- [Source: _bmad-output/implementation-artifacts/4-5-welcome-gift-and-guided-first-purchase.md] design note on the 2-step way back; `1-8-debug-overlay-and-save-export.md` export chord; `5-3-technical-metrics-on-family-computers.md` gate pattern, F1, weak-hardware deferral
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] items at ~84, ~128, ~144, ~327, ~469, ~484 named in Task 7.1
- [Source: scripts/screens/main_menu.gd, scripts/autoloads/save_service.gd, scripts/autoloads/web_platform.gd, scripts/autoloads/player_data.gd, scripts/typing/run_result.gd, scripts/core/save_schema.gd, tools/encode_ogg.py, export_presets.cfg]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **1.1 Baseline (2026-10-07):** GUT at `91ed00c` after `--import`: **1319 passing**, 41676 asserts, exit 0, no `Parse Error|Compile Error|Failed to load script`. Real `save.json` sha256 `c34c7559b3761b07…` before and after: unchanged.
- **1.2 Pages:** https://jacob-verburg.github.io/ZombiesTeachTyping/ loads the title screen ("Click or press any key") in the built-in pane. Latest tag `v0.9.0`; the last tag-triggered build is run 37556023613 (`v0.9.0`, success); the later `main` push (run 37559936392) doesn't deploy (ADR-4). F3 on the menu shows no overlay (release build). 5.3's F1 (Fullscreen icon state) is in this build: known issue, not a playtest finding.
- **2.3 `--selftest`:** 15 checks, all PASS (finished runs 2, median accuracy 87, median WPM 7.5, gap 6.5 min, top missed key `'b'` 6/18 most often `'d'`, second `'q'`, float `41.0` → `41`, music off seen, malformed `per_key` warned, 4 broken saves summarized without a crash). Exit 0.
- **2.4 (a) Pages chord:** on the Pages build in the pane (Chromium), title → menu → Ctrl+Shift+E offered `zts-save-20261007.json` (443 B, `application/json`, blob anchor click seen through a log-only hook on `URL.createObjectURL` / `HTMLAnchorElement.click`). Content: a fresh profile (0 brains, no runs). First time the chord is verified on Pages (5.3 had only a local release export).
- **2.4 (b) Real data:** dev `save.json` copied to the scratchpad; the tool on the copy: 1 finished run (2026-10-05 13:52, 2:00, 181 keys, 12 errors, 93 %, 18 WPM, 55 brains, timer), median accuracy 93 %, owned/worn Pumpkin hat + Cute ghost, top missed `'n'` 6/13 (typed `'s'`), `'m'` 5/12 (typed `'n'`). The Pages export (saved to the scratchpad) prints "no finished runs" and dashes. Malformed JSON → `can't read …` and exit 2; no argument → usage, exit 2.
- **5 Session (2026-10-07):** no kid session. Smuck: "lets mark all as good, no action, while not a kid I gave demo to coworkers". No export, no observations; nothing committed under `playtest/5-4/`.
- **7.3 Final suite:** `--import`, then GUT twice: **1319 passing** both runs, exit 0, no parse/compile/load errors; real `save.json` sha256 `c34c7559b3761b07…` unchanged before, between and after. `git diff 91ed00c` under `scripts/ scenes/ data/ assets/ project.godot export_presets.cfg .github/`: empty.
- **2.x Console fix:** the first run printed `—`/`·` garbled on the Windows console (cp1252); the tool now reconfigures stdout/stderr to UTF-8. Checked in Git Bash and PowerShell 7.

### Completion Notes List

- Built `tools/playtest/summarize_save.py` (stdlib only, read-only, `--json`, `--selftest` 15/15 PASS); verified on a copy of the dev save and on a fresh export taken from the Pages build with Ctrl+Shift+E (first Pages check of the chord).
- Playtest plan finalized at Gate A (one kid 11–13, family PC with Chrome/Edge, `v0.9.0` as is, export to be committed, no frame check).
- **No kid playtest happened.** Smuck demoed to coworkers instead and called it "all good, no action". Per AC 7, every kid check is recorded as Skipped with that reason, not as passed; the core hypothesis tally is 0 of 0 (deliberately not Task 7.2's "N of 1" wording: no kid played). P1 (the untested hypothesis) → Smuck's call: no action; the watch-list and tally are noted in `deferred-work.md` for the first kids after sharing, not as an action. Story 5.5's must-fix input is 5.3's F1 only.
- `deferred-work.md`: new "dev of story 5-4" section (playtest gap, the hypothesis tally line, NFR1 still unmeasured, the export verified on Pages). Watch-list items were left alone (no kid evidence touched them).
- No game code changed; GUT 1319 passing (×3 runs), real save untouched.

### File List

- `tools/playtest/summarize_save.py` (new)
- `_bmad-output/implementation-artifacts/5-4-first-kid-playtest.md` (this story)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`

## Change Log

- 2026-10-07: Story 5.4 dev. Added `tools/playtest/summarize_save.py`; finalized the playtest plan at Gate A; recorded the coworker demo in place of a kid playtest (all kid checks Skipped, Gate B: no action); deferred-work updated. Status → review.
