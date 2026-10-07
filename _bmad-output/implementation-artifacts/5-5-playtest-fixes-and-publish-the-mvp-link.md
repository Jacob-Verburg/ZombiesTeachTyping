---
baseline_commit: 4704855
---
# Story 5.5: Playtest Fixes and Publish the MVP Link

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Smuck,
I want to fix the must-fix items and publish the link,
so that family and friends can play Zombies Teach Typing.

## Acceptance Criteria

1. **Must-fix items fixed.** **Given** the must-fix items from Stories 5.3 and 5.4 **When** they are fixed **Then** each fix has a passing test or a re-check noted in the story file, and CI is green. The input list is **F1** (5.3: the main-menu Fullscreen toggle shows the wrong state) and nothing from 5.4 (its only finding, P1 "no kid playtested", was Smuck's call: no action). `## Must-Fix Register` below lists every item, its fix and its evidence; Smuck confirms the list at Gate A (he may add or drop items).
2. **Release build, full MVP loop.** **Given** the release build on GitHub Pages **When** a fresh browser profile opens the link **Then** the full MVP loop works: title → menu → Zombie Run → report card → welcome gift → Closet → buy and wear → play again with the hat visible. **And** the debug overlay and cheats are absent from the release build. Each step is recorded in `## Release Check` as Pass / Fail / Skipped with Smuck's reason verbatim.
3. **Published.** **Given** the published link **When** it is shared **Then** the release is published by pushing the `v1.0.0` tag (the CI deploys only from tags, ADR-4), and a short plain-words "how to play" note (physical keyboard, desktop Chrome/Edge/Firefox) accompanies the link. The tag push is outward-facing: it needs Smuck's explicit yes at Gate B, after the green CI run on the fix commit.
4. **Honest record.** Nothing in `## Release Check` is written from guesswork: a step done by the agent in the built-in browser pane says so; a step Smuck did says "Smuck, reported"; a step not done is "Skipped" with Smuck's reason verbatim. No scope creep: post-MVP backlog items and the other 5.x deferrals stay in `deferred-work.md` unless Smuck promotes one at Gate A.

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 1)**
  - [x] 1.1 Starting commit `4704855` (clean `main`). `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then the full GUT run; 5.4 ended at **1319** passing (confirm the count yourself; no `Parse Error|Compile Error|Failed to load script` in the output). Hash the real dev save (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`, sha256) before and after every suite run (the 4.5 / 5.3 real-save trap). The new tests must not touch it (temp `SaveService`, fake fullscreen seams, as `test_main_menu.gd` does).
  - [x] 1.2 Reproduce F1 before changing anything: write the failing test first (Task 2.1), watch it fail, then fix. Note in the Debug Log what the failing test showed.
- [ ] **Task 2: Fix F1, the Fullscreen toggle icon state (AC: 1)**
  - [x] 2.1 **Failing test first** in `tests/unit/test_main_menu.gd` (or a new `test_main_menu_fullscreen.gd` if the file is long): a fake window whose `is_fullscreen` flips **N frames after** `toggle_fullscreen` is called (the real behaviour: the browser applies the mode later, the desktop maybe a frame late). Cases: (a) press the toggle: the icon follows the mode once it lands (on after it enters fullscreen, off after it leaves), and never stays on the stale state; (b) the mode never changes (the browser refused the request): the icon returns to the real state instead of showing a state the window is not in; (c) the browser's own Esc exit while the menu is open: the icon follows without any press; (d) one flip calls `toggle_fullscreen` exactly once and plays the click once (existing test `test_fullscreen_flip_calls_the_toggle_once_and_follows_the_mode`, line ~305, must still pass or be updated to the new timing). Use `await wait_frames(...)` / `wait_physical_frames` from GUT, not real time.
  - [x] 2.2 **Fix** in `scripts/screens/main_menu.gd`. Recommended: keep `_sync_fullscreen()` as the single place that reads `is_fullscreen.call()` and calls `%FullscreenToggle.show_state(...)`, and call it **every frame while the menu is open** from `_process` (a bool compare; `show_state` only when the value differs from `toggle.is_on()`, so no redraw churn). In `_on_fullscreen_flipped` remove the immediate `_sync_fullscreen()` that reads the stale mode and overwrites the optimistic flip (keep the call to `toggle_fullscreen.call()` inside the input callback: the browser only allows fullscreen from a user gesture). Keep the existing `get_tree().root.size_changed.connect(_sync_fullscreen)` (harmless, helps the windowed desktop case). Stop processing when `_leaving` is set. Do **not** change `WebPlatform.toggle_fullscreen` / `is_fullscreen` semantics (they already re-read the engine on every call, `web_platform.gd:62-73`). If the polling approach turns out wrong on the Windows exe, the alternative is a short `SceneTreeTimer` re-read after the flip plus `NOTIFICATION_WM_SIZE_CHANGED`; pick by what the re-check shows, and write the reason in the Debug Log.
  - [x] 2.3 **Why the old code failed (documented in 5.3 F1):** `main_menu.gd:219-221` called `toggle_fullscreen` then immediately `_sync_fullscreen()` → `is_fullscreen()`, but the window-mode change lands later, so it re-read the old state. `window/stretch/mode="viewport"` keeps the root viewport at 640×360, so `root.size_changed` (line 66) never fired to correct it. The icon is a 2-frame sheet (`MenuToggle._show_icon`, frame 0 on / frame 1 off with the red slash); `MenuToggle._on_icon_button_pressed` already flips optimistically, which is correct once the stale re-read is gone.
  - [ ] 2.4 Re-check in the real thing, recorded in the Debug Log (Smuck does the exe, the agent does the web pane): (a) **Web** (a local Web export served from `build/web` with `python -m http.server`, or the Pages build after the tag): menu → click Fullscreen: the icon is on (no slash) while fullscreen, slash while windowed; browser Esc out: the icon flips back with no press. (b) **Windows exe** (`build/windows/ZombiesTeachTyping.exe`, rebuilt from the fix; the dev PC save is backed up first, as in 5.3): same two checks. If the agent cannot drive fullscreen in the pane (the browser may refuse without a real user gesture), say so and ask Smuck to do (a) too: record it as "Smuck, reported".
- [ ] **Task 3: Release build has no debug (AC: 2)**
  - [x] 3.1 Confirm by code and by test that every debug path is gated and that release is covered: `Router._is_debug_build()` → overlay (`router.gd:59,151`); `RunFrame.is_debug_build` seam gates `debug_seed` and `debug_end_run` (`run_frame.gd:202,286`, tests `test_release_ignores_the_pinned_seed`, `test_release_refuses_the_debug_end_run` in `tests/integration/test_run_frame.gd:922,931`); `LevelRegistry.get_scene(..., debug_build)` hides `debug_only` levels (`level_registry.gd:23`); `Log.debug_enabled = OS.is_debug_build()`. Grep `scripts/` for any other `Input.is_key_pressed` / `KEY_F*` handler outside `scripts/debug/` (the `KEY_F1..F35` in `game_constants.gd:15` is the typing filter, not a cheat). The only release-safe debug-ish feature is the **Ctrl+Shift+E save export on the main menu** (Story 1.8, by design: it is what lets families send a save); list it in `## Release Check` as "present by design". If a gap is found (a cheat reachable in release), that is a new must-fix: add it to the register and fix it with a test; do not stretch the story silently.
  - [x] 3.2 Add or confirm one automated guard that the shipped release has no overlay: the existing `test_debug_overlay.gd` / `test_screen_flow.gd` release-case test(s) via the `_is_debug_build` seam. If none asserts "release build → no `DebugOverlay` child on the Router", add one test (do not call the real `OS.is_debug_build`).
  - [ ] 3.3 On the **published release build** (Task 6 re-check): F3, F5–F9, F2 do nothing on the title, menu, run and report card; no `DebugOverlay` node. In the pane, `javascript_tool` can only inspect the page, not the Godot tree, so judge by the keys doing nothing and by the title/menu looking unchanged; record exactly that.
- [x] **Task 4: How-to-play note (AC: 3)**
  - [x] 4.1 Write the note, plain words a parent can read in 20 seconds, 5–7 short lines max (see `## How To Play Note` below for the draft). Fixed facts: needs a **computer with a physical keyboard** (no phones or tablets), **desktop Chrome, Edge or Firefox**, no sign-up, no ads, nothing is sent anywhere; progress is saved in the browser on that computer, so use the same browser each time (and the "This browser might forget your brains" notice on the menu means the browser may clear it). Mention the one hidden grown-up feature only if Smuck wants it: Ctrl+Shift+E on the main menu downloads a copy of the save (Chrome/Edge verified; Firefox uses that chord for its own tool, so it is unverified there; 1.8 deferral).
  - [x] 4.2 Where it goes (Gate A decides): recommended **the GitHub Release notes for `v1.0.0`** (created with `gh release create v1.0.0 --notes-file …` at Gate B, only after Smuck's yes) and the same text pasted wherever Smuck shares the link. Do **not** add a game screen or a repo `README` unless Smuck asks (no game code beyond F1 in this story; UX has no how-to-play screen, the tutorial arrow and the Welcome Gift teach the loop). If Smuck wants a README, it is a small separate docs-only change in the same commit and not under `docs/` (export-excluded folder).
- [x] **Task 5: Gate A — before the work (AC: 1, 3, 4)** — ask with `AskUserQuestion`, one question per decision, recommendation first; record verbatim with the date in `## Review Approval`.
  - [x] 5.1 **Must-fix list.** "F1 is the only must-fix input (5.4 added none). Anything else you saw while demoing to coworkers?" Options: "F1 only (Recommended)" / "Add an item (tell me)".
  - [x] 5.2 **Promote any deferral?** Candidates worth a thought before strangers play: NFR1/NFR2 on a weak computer is unmeasured (5.3), the one-off ~110–165 ms OGG-decode hitch on first music play (5.1), Firefox Ctrl+Shift+E unverified. Recommend: promote none (all are known and measured or declared; they can follow in a 1.0.x patch). Record the answer.
  - [x] 5.3 **How-to-play note: wording and home.** Show the draft; ask if anything should change and where it lives (GitHub Release notes recommended).
  - [x] 5.4 **Release shape.** Recommend: tag `v1.0.0` on the fix commit after the push to `main` is green, and `gh release create` for the notes. Confirm the tag name `v1.0.0` (the epic's AC) and that Pages stays the host (ADR-4, NFR12: no analytics).
- [ ] **Task 6: Gate B — publish (AC: 2, 3)**
  - [ ] 6.1 Commit the fix (Task 2, 3.2, 4 draft) on `main` as one commit `Story 5.5: playtest fixes (in progress)` and push. Wait for the `build` workflow on `main` to go green (GUT, Web export; **it does not deploy**, deploy only runs on `v*`). If CI is red, fix first; do not tag. Watch the Ubuntu runner note from 5.3: GitHub moves `ubuntu-latest` to Ubuntu 26 on **2026-10-19**; if the tag build happens after that date and the Godot install step fails, that is the likely cause (not a game bug).
  - [ ] 6.2 **Smuck's explicit yes** to publish ("Push the `v1.0.0` tag now? This deploys the build to the public Pages link."). Only after a clear yes: `git tag v1.0.0` on the pushed commit and `git push origin v1.0.0`; use the `ccd_pr`/`gh` tools only for what they are for (no PR here). Watch the tag run: `gh run list --branch v1.0.0` / `gh run watch` (a single check, not a poll loop). Record the run id and result in the Debug Log.
  - [ ] 6.3 **Release check on the live link** (AC 2). Fresh profile = a new private/incognito window or cleared site data (the built-in pane's storage may not be fresh: clear it via DevTools → Application → "Clear site data" first and say so). Open https://jacob-verburg.github.io/ZombiesTeachTyping/ and walk the loop: title ("Click or press any key") → menu → pick Zombie Run → play the 2:00 run (the agent may type with `computer`; or Smuck plays and reports) → report card → welcome gift opens → Closet → buy the guided item → wear it → Play Again → hat visible on the zombie in the run. Plus: F1 fix visible on the live menu (Task 2.4a), debug keys do nothing (Task 3.3), reload keeps the brains and the worn hat, no console errors (`read_console_messages`). Anything the agent cannot do in the pane (real keyboard capture, fullscreen) is "Skipped" with the reason or "Smuck, reported". Record each step in `## Release Check`.
  - [ ] 6.4 Create the GitHub Release `v1.0.0` with the note (only with the same yes as 6.2 or a separate one if Smuck prefers) and show the final link + note to Smuck for sharing. Nothing is sent to anyone by the agent.
- [ ] **Task 7: Wrap-up (AC: 1, 4)**
  - [ ] 7.1 `deferred-work.md`: add "Deferred from: dev of story 5-5" with anything found and not fixed (one line each); strike the 5.3 deferral lines this story closes (F1) with `~~…~~ Done in 5.5: …`. Update the hypothesis tally line: still "0 of 0 kids so far (needs 2 of the first 3); all 3 come after the link is shared", now with the live link and the instruction to ask families for the Ctrl+Shift+E export and run `python tools/playtest/summarize_save.py <file>`.
  - [ ] 7.2 Full GUT suite twice (`--import` first), real `save.json` hash unchanged before, between and after; local Web export once (`"/c/Program Files/Godot/Godot.exe" --headless --path . --export-release "Web" build/web/index.html`; `build/` is git-ignored) to prove the fix exports; the Windows export only if Smuck does the exe re-check (Task 2.4b).
  - [ ] 7.3 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review` (and `last_updated`). Suggested final commit: `Story 5.5: playtest fixes and publish the MVP link`. After review, Epic 5's other stories are all done: the epic stays `in-progress` until Smuck marks it done (retrospective optional).

## Must-Fix Register

_(The agent fills Evidence as it works. Gate A may add rows.)_

| Id | Source | What | Fix | Evidence (test or re-check) |
| --- | --- | --- | --- | --- |
| F1 | 5.3 (Smuck, Gate B 2026-10-06: "Must-fix before publish") | Main-menu Fullscreen toggle shows the wrong state: Windows exe icon flips backwards; web icon always shows the red slash. Fullscreen itself works. NFR8: the slash carries the state. | `main_menu.gd`: re-read the mode every frame while the menu is open (`_process`); no stale re-read right after the flip; a press holds the asked-for state up to `FULLSCREEN_SETTLE_FRAMES` (60) until the window switches, then the real mode shows (Task 2.2) | `tests/unit/test_main_menu_fullscreen.gd`: 3 of 4 failed on the old code, 4/4 pass on the fix; existing `test_main_menu.gd` 37/37. Web pane (local export): the refused-request path returns to the slash (the pane refuses fullscreen). Accept path + Esc exit: Smuck (web, exe) — see Debug Log |
| — | 5.4 | None. P1 ("no kid playtested") → Smuck: no action. | — | — |

## How To Play Note

_(Draft for Gate A. Plain words; Smuck edits. Goes in the `v1.0.0` GitHub Release notes and wherever the link is shared.)_

> **Zombies Teach Typing**
> A typing game for kids. You are a friendly zombie who loves brains, and every letter you type moves the zombie along.
>
> - Play on a **computer with a keyboard** (not a phone or tablet), in **Chrome, Edge or Firefox**.
> - Open the link and press any key. There is nothing to sign up for and nothing to download.
> - Put your fingers on the **home row** (the little bumps on **F** and **J**). The green zombie hands show which finger to use.
> - Get brains for typing, then spend them on hats and pets in the Crypt Closet.
> - Your brains are saved in the browser on that computer, so use the same browser next time.

## Release Check

_(Filled live. Pass / Fail / Skipped; Skipped carries Smuck's reason verbatim; say who did each step.)_

| Step | Result | Who / how | Notes |
| --- | --- | --- | --- |
| CI on the fix commit is green | | | |
| Tag `v1.0.0` pushed (Smuck's yes, date) | | | |
| Tag run deployed to Pages | | | |
| Fresh profile: title → menu | | | |
| Menu → Zombie Run → full run | | | |
| Report card | | | |
| Welcome gift | | | |
| Closet: buy and wear | | | |
| Play again: hat visible | | | |
| Fullscreen icon follows the mode (F1 fixed) | | | |
| Debug keys do nothing; no overlay | | | |
| Reload keeps brains and hat | | | |
| No console errors | | | |
| How-to-play note ready with the link | | | |

## Review Approval

_(Gate A and Gate B answers, verbatim with the date.)_

**Gate A (2026-10-07, Smuck via `AskUserQuestion`):**
- 5.1 Must-fix list: "F1 only (Recommended)"
- 5.2 Promote any deferral: "Promote none (Recommended)"
- 5.3 How-to-play note: "Draft as-is, Release notes (Recommended)"
- 5.4 Release shape: "Yes, v1.0.0 on Pages (Recommended)"

## Dev Notes

### What this story is (and isn't)

- It is: one small code fix (F1), its test, a check that release has no debug, the how-to-play note, and the publish (tag `v1.0.0`) with a walkthrough of the live link. It is the last story of Epic 5.
- It isn't: new features, balancing, new art or audio, or anything from the 5.x deferral lists unless Smuck promotes it at Gate A. Kid evidence does not exist yet (5.4 had no kid), so no tuning is justified by it.
- The tag push and the GitHub Release are outward-facing (public link): explicit yes first, per item, never batched with other approvals.

### Existing code you will touch (read it first)

**`scripts/screens/main_menu.gd`** (UPDATE). Current state:
- Test seams `toggle_fullscreen` / `is_fullscreen` (Callables) default in `_ready()` to `WebPlatform.toggle_fullscreen` / `WebPlatform.is_fullscreen` (lines ~49-52).
- `_ready()` wires `%FullscreenToggle.flipped` → `_on_fullscreen_flipped`, connects `get_tree().root.size_changed` → `_sync_fullscreen`, and calls `_sync_fullscreen()` once (lines ~61-66).
- `_on_fullscreen_flipped(_on)` (line ~217): `toggle_fullscreen.call()`, then `_sync_fullscreen()`, then `AudioManager.play_sfx(&"sfx_ui_click")`. The comment "Runs inside the input callback: the browser only allows fullscreen from a user gesture" must stay true.
- `_sync_fullscreen()` (below, not shown above) reads `is_fullscreen.call()` and calls `%FullscreenToggle.show_state(...)` (`main_menu.gd:170-171`; keep that single path).
- Also in this file: `is_export_chord` + `_unhandled_input` (Ctrl+Shift+E → `SaveService.offer_export()`), Esc does nothing on the root screen, `_wire_focus`, level cards, storage notice. **None of that changes.**

What this story changes: only the *timing* of the fullscreen re-read (a per-frame check while the menu is open; no stale re-read after the flip). What must be preserved: the one-call-per-flip rule, the click sound once per flip, focus wiring (`get_focus_target()`), `_leaving` guarding after navigation, the storage notice, the export chord, and `MenuToggle`'s optimistic flip.

**`scripts/ui/menu_toggle.gd`** (read only): `show_state(on)` sets the look without emitting `flipped`; `_on_icon_button_pressed` flips and emits. Do not add logic there.

**`scripts/autoloads/web_platform.gd`** (read only): `toggle_fullscreen()` uses `DisplayServer.window_set_mode`; `is_fullscreen()` re-reads `window_get_mode()` every call. The mode change is applied by the browser/OS after the call returns, which is the bug's root cause.

**`tests/unit/test_main_menu.gd`** (UPDATE): has fakes (`menu.toggle_fullscreen`, `menu.is_fullscreen` with a `_fullscreen` bool, lines ~69-72), tests at ~305 (`test_fullscreen_flip_calls_the_toggle_once_and_follows_the_mode`), ~317, ~324. Extend the fake with a *delayed* mode (the new flip only becomes visible in `is_fullscreen` after N frames). If you change the existing tests' timing, keep their intent.

### Architecture and rules to follow

- Godot **4.7.2**, GDScript, GUT 9.7.1; static typing everywhere (project style: `var x: int`, typed returns, `Callable` seams with the comment style above); tabs for indentation; doc comments `##`. Match the surrounding comment density: short, explaining *why*.
- Test seams over globals: no test touches the live `Router`, `WebPlatform`, `AudioManager` state or the real save. Use the existing injection pattern in `test_main_menu.gd`.
- **Boundary 7 / release-safety:** debug code only in debug builds; Ctrl+Shift+E export is the single release-safe tool (architecture, Debug Tools).
- **ADR-4:** Pages deploys only from `v*` tags (`.github/workflows/build.yml`: `on.push.tags: ['v*']`, `deploy` job `if: startsWith(github.ref, 'refs/tags/v')`). The Web export on `main` is artifact-only. Do not edit the workflow in this story.
- **NFR12:** no network, analytics or personal data; the how-to-play note says so.
- **NFR8:** state is carried by shape (the slash), not by colour only; the fix must keep the icon's 2-frame on/off look unchanged.
- **NFR9/NFR16:** the how-to-play note and any text added are plain words.
- No game assets change. No `project.godot`, `export_presets.cfg` or workflow change is expected (`test_export_presets.gd` guards the presets).

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. CI fails the build on `Parse Error|Compile Error|Failed to load script` in the log (GUT skips an unparseable script and still exits 0): grep your own output for the same.
- Expect **1319** passing at the baseline; the new F1 tests add to the count. Record the new total.
- GUT: use `await wait_frames(n)` for frame-delayed fakes; add the menu with `add_child_autofree` (see the existing helper in the file). A per-frame `_process` check is only exercised if the node is in the tree and processing; the test must prove the icon changes **without** a call to `_sync_fullscreen` from the test.
- Web re-check with the built-in browser pane: keep it on screen (a hidden pane throttles to ~1–2 fps); the pane may not allow a real fullscreen; if so, that part is Smuck's.
- The real-save trap: hash `save.json` around every suite run (see Task 1.1).

### Previous story intelligence

- **5.4:** no kid playtest (coworker demo, "mark all as good, no action"); every kid check Skipped; must-fix input to 5.5 is F1 only; hypothesis tally 0 of 0, all kids come after sharing. It added `tools/playtest/summarize_save.py` (stdlib, read-only; use it on any export families send). The Ctrl+Shift+E export was verified on the Pages build in a Chromium pane (`zts-save-YYYYMMDD.json`); Firefox unverified.
- **5.3:** gates as `AskUserQuestion`, one question per decision, recommendation first; answers verbatim with the date. Smuck often passes or skips items — record those as Smuck's call, never as measured. Chrome was skipped for every session, Firefox skipped; M3/M5/M6/M8 passed by Smuck's call without measurement; NFR1/NFR2 measured only in emulated Edge on the dev PC (60.05 fps, 0 frames over 33 ms, key→frame p95 15.2 ms). F1 found in the Windows exe and on web (Edge). CI grep narrowed to the load-failure patterns.
- **5.2:** plain-words check passed; any new player-facing text must be added to `test_plain_words.gd` `APPROVED_COPY` and EXPERIENCE.md **only if** it ships in the game. The how-to-play note is outside the game, so no copy test is needed.
- **5.1/5.0/4.x:** the Fullscreen/Music/Sound toggles are `MenuToggle`s (4.2) with the 2-frame icon sheets from 5.0 (`ui_icon_fullscreen.png`); the `sfx_ui_click` plays after a setting change (5.1).
- Lessons from earlier reviews: a story-file section replace once cut half a story (5.2) — edit sections line-anchored; LF endings for any new `.md`/`.py`; outward-facing actions only after an explicit yes.

### Git intelligence

- One commit per story on `main`, with a second "(code review patches applied, done)" commit after review: `4704855 Story 5.4: first kid playtest (code review patches applied, done)`, `91ed00c Story 5.3 …`. For 5.5 use `Story 5.5: playtest fixes (in progress)` for the fix commit (so CI runs on `main` before tagging), then the final story commit. The tag `v1.0.0` goes on the commit that passed CI. Existing tags: `v0.0.1`, `v0.9.0` (last deployed build, run 37556023613).
- No file outside `scripts/screens/main_menu.gd`, `tests/…`, the story/sprint/deferred docs is expected to change (plus nothing under `assets/`, `data/`, `.github/`, `project.godot`, `export_presets.cfg`).

### Project Structure Notes

- Modified: `scripts/screens/main_menu.gd`, `tests/unit/test_main_menu.gd` (or a new `tests/unit/test_main_menu_fullscreen.gd` + its `.uid`, which Godot generates on import: commit it as the other tests do), this story file, `sprint-status.yaml`, `deferred-work.md`.
- New (optional, Smuck's call at Gate A): a README. The how-to-play note otherwise lives in the GitHub Release notes. `docs/` and `_bmad-output/` are export-excluded, so nothing here ships in the game.
- No conflicts with the unified structure.

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md`, the GDD and the UX spines:
  - **ADR-4:** Pages deploys only from `v*` tags; publishing is deliberate. **NFR12:** privacy, no analytics. **NFR17:** the game must load and play without help on family computers. **NFR9/10/11/16:** plain words, no rank labels, no timers outside runs, no technical error text. **NFR8:** state is never colour only.
  - **Boundary 7:** debug code only in debug builds. The release build keeps only the main-menu save export.
  - Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, Python stdlib, `gh`, the built-in browser pane. Windows export: `build/windows/ZombiesTeachTyping.exe` (git-ignored `build/`).

### Latest tech information

- No new libraries. Web research skipped on purpose: the fix uses engine calls the game already uses (`DisplayServer.window_get_mode`), and the build/deploy pipeline is the existing one (Godot 4.7.2 single-threaded web template, `actions/deploy-pages@v5` from `v*` tags). One date to remember: GitHub switches `ubuntu-latest` to Ubuntu 26 on 2026-10-19 (5.3 note).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.5: Playtest Fixes and Publish the MVP Link] (ACs); Epic 5 goal; Stories 5.3, 5.4
- [Source: _bmad-output/implementation-artifacts/5-3-technical-metrics-on-family-computers.md#Fix Items for 5.5] F1 and its suspected cause
- [Source: _bmad-output/implementation-artifacts/5-4-first-kid-playtest.md#Findings and Triage] P1 (no action)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 5.1, 5.3, 5.4 deferrals (post-MVP unless promoted)
- [Source: _bmad-output/game-architecture.md] ADR-4 publishing, Debug Tools / Boundary 7, NFR1–NFR17
- [Source: .github/workflows/build.yml] tag-only deploy; [Source: scripts/screens/main_menu.gd], [scripts/ui/menu_toggle.gd], [scripts/autoloads/web_platform.gd], [scripts/autoloads/router.gd:151], [scripts/run/run_frame.gd:202,286], [tests/unit/test_main_menu.gd:305-330]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **Baseline (2026-10-07):** `4704855`, `--import` then full GUT: 74 scripts, **1319/1319** passing, 0 `Parse Error|Compile Error|Failed to load script`. Real `save.json` sha256 `c34c7559b3761b0…` before and after.
- **F1 red:** new `test_main_menu_fullscreen.gd` (fake window lands a flip 5 process frames late, or never) on the old `main_menu.gd`: 3 of 4 failed. The press left the icon on the stale off state (old `_sync_fullscreen()` right after `toggle_fullscreen` read the old mode: the web "always the slash" symptom), and the browser's own exit was never followed (no `size_changed` under viewport stretch). The 4th test (leaving stops following) passed trivially (nothing followed).
- **F1 green:** `_process` re-reads the mode every frame while the menu is open (stops once `_leaving`); `_sync_fullscreen` only calls `show_state` when the value differs. Deviation from the plain per-frame poll in 2.2: a press arms a settle window (`FULLSCREEN_SETTLE_FRAMES` = 60, ~1 s) that keeps the asked-for state until the mode differs from the one before the press, then shows the real mode. Reason: the browser applies fullscreen after its own transition (several frames), so a bare poll would flick the icon back to the stale state and then forward again on every press; the settle window keeps case (b) (refused request → back to the real state) while removing the flicker. One `toggle_fullscreen` call and one `sfx_ui_click` per press (`_on_fullscreen_flipped`, unchanged structure; the click has no test seam on the live `AudioManager`, so it is by code, the toggle count is by test). Result: 4/4 new, `test_main_menu.gd` 37/37 (the old flip test still passes unchanged).
- **Full suite after the fix:** 75 scripts, **1323/1323** passing, 0 load errors, save hash unchanged.
- **Release audit (Task 3.1):** outside `scripts/debug/`, the only `OS.is_debug_build` gates are `Router._is_debug_build()` (overlay), `RunFrame.is_debug_build` (seed, end run), `LevelRegistry.get_scene(debug_build)`, `Log.debug_enabled`. No `Input.is_key_pressed`/F-key handler elsewhere (`game_constants.gd` F1..F35 is the typing filter). `KEYBOARD_TEST` and the debug scenes are reached only from the overlay; the `debug_only` level is the test level. Ctrl+Shift+E export: present by design. No new must-fix. Guard (3.2): already present, `tests/unit/test_router.gd:121` `test_release_build_never_instances_the_overlay` (a `ReleaseRouter` overriding `_is_debug_build`); no new test needed.
- **Web re-check (2.4a, agent, built-in pane, local `--export-release "Web"` served on :8060):** menu opens with the slash (windowed). Click Fullscreen: the pane refused the request (`document.fullscreenElement` stayed `null`); 2 s later the icon showed the slash again = the refused-request path works in a real browser. The accept path and the browser Esc exit cannot be driven in the pane: Smuck's.
- **Windows exe** rebuilt from the fix (`build/windows/ZombiesTeachTyping.exe`, 2026-10-07 12:18); dev save backed up first to `%TEMP%/save-backup-5-5.json` (same hash).

### Completion Notes List

### File List

## Change Log

- 2026-10-07: Story 5.5 created (ready-for-dev).
