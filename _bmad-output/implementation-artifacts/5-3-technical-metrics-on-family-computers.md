---
baseline_commit: a173428c44dea16f4af6a6f5877ba44dc9a7c52f
---

# Story 5.3: Technical Metrics on Family Computers

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Smuck,
I want proof that the MVP runs smoothly and keeps saves on real family computers,
so that I can share the link with confidence.

## Acceptance Criteria

1. **Frame rate (NFR1).** **Given** a 2018-era laptop with integrated graphics (or the closest available; its make, CPU, GPU, RAM, screen and refresh rate recorded) in desktop Chrome, Edge and Firefox **When** a full 2:00 Zombie Run with 12+ conga followers is recorded with the browser performance tools on the **release** build from the Pages link **Then** it holds 60 FPS with no frame over 33 ms (NFR1). The measured window is the RUNNING part of the run (first correct key → 0:00); load-time hitches before the first key and at the report card are recorded separately (see Dev Notes "What NFR1 measures"). Results per browser go in `## Metrics Results` (M1).
2. **Input latency (NFR2).** **Given** the same machine **When** input feedback is checked **Then** a correct key shows the target advance and the effect start on the next rendered frame (≤ 17 ms): the frame probe's keydown → next-frame times are recorded per browser (M2), and the existing same-call tests are cited as the code-level proof.
   - *Probe tolerances (review 2026-10-06, Smuck's call: keep and document):* NFR1 passes at FPS >= 59 (59.94 Hz panels) and counts a frame as over 33 ms only above 33.4 ms (vsync rounding); NFR2 passes at <= 17.2 ms (16.7 + 0.5). See `tools/perf/README.md`, "Thresholds".
3. **Load (NFR3).** **Given** the Pages link **When** first and cached loads are timed at 25 Mbit/s **Then** first load to the title screen is ≤ 10 s and cached load ≤ 3 s, with the compressed transfer size recorded against 40 MB (M3).
4. **Save integrity (NFR4).** **Given** Chrome and Firefox **When** 10 consecutive reloads and 10 tab closes mid-menu are done after earning brains and buying an item **Then** no data is lost (brains, owned item, equipped item, best WPM), recorded per round (M4).
5. **Browser keys during a real run.** **Given** a real Zombie Run (not the Keyboard Test screen) in Chrome and Firefox **When** Space, `'`, `/`, Backspace and Tab are pressed during a run and while paused **Then** the page never scrolls and quick-find never opens; **and** in the menu afterwards normal browser keys work again (M5). The same session records what Esc does in browser fullscreen during a run (2.7 deferral).
6. **Screen and fullscreen.** **Given** the target laptop's 1366×768 screen **When** the game runs windowed (maximised) and in fullscreen **Then** it fills the window (fractional scaling, nearest filtering, no blur), and the 16 px text is readable from a normal seating distance — one note and one screenshot per browser (M6).
7. **Windows fallback.** **Given** the Windows Desktop export **When** it is run on one Windows PC **Then** it starts, plays a Zombie Run and keeps its save across a restart (M7). (The epic says "NFR8 fallback smoke check"; the fallback is NFR5's — see Dev Notes.)
8. **Reach (NFR17).** **Given** 3 different family computers **When** someone opens the link **Then** the game loads and plays without help (M8) **And** any failure in M1–M8 becomes a numbered fix item in `## Fix Items for 5.5`. This story measures and records; it does not fix the game.
9. **Evidence and approval.** Every M-table row is Pass / Fail / Skipped; a Skipped row carries Smuck's reason verbatim. Smuck approves the results (`## Review Approval`, verbatim with the date). The open Firefox and browser items in `deferred-work.md` that this story measures are struck with a pointer. The full GUT suite passes.

## Tasks / Subtasks

- [x] **Task 1: Baseline (AC: 9)**
  - [x] 1.1 Run the full suite at the starting commit (`a173428`, 5.2 ended at **1319** + its review patches; confirm the count yourself). Hash the real `save.json` (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`) before and after every full run, every local export run and the Windows smoke test (the 4.5 real-save trap; see Task 6).
  - [x] 1.2 Local release export to `build/web/` (`"/c/Program Files/Godot/Godot.exe" --headless --path . --export-release "Web" build/web/index.html`; check `index.html/.js/.wasm/.pck` exist, like CI). Record each file's raw size and its gzip size (`python -c "import gzip,sys; ..."` at level 6, the Pages-like estimate) and the total. Compare to 1.2's 10,350,910 B transfer (hello world). Expected: the pck grew a lot (two 96 s OGG loops, all sprites); if the gzip total is near 30 MB (architecture's 10 s ≈ 30 MB on the wire), say so at Gate A before any tag.
  - [x] 1.3 List the debug-only scenes that still ship in release (`scenes/debug/art_review.tscn`, `ui_art_review.tscn`, `hat_fit_check.tscn`, `scenes/screens/keyboard_test.tscn`, `scenes/levels/test_level/`; deferrals 1.5 / 1.9 / 2.4 / 5.0) with their share of the pck (`--export-pack` listing or a byte search). Don't exclude them here; record the size so 5.5 can decide (a fix item only if it matters for M3).
- [x] **Task 2: Measurement tools (AC: 1, 2, 5)**
  - [x] 2.1 New `tools/perf/frame_probe.js` (export-excluded with the rest of `tools/`; never added to the head include or any shipped file). A paste-into-console snippet that works the same in Chrome, Edge and Firefox on the **release** Pages build (no game code, no Godot API):
    - `zts_probe.arm()` — waits for the next keydown of a letter `a`–`z` (the run's first correct key starts RUNNING) and then records every `requestAnimationFrame` interval for `ZTS_PROBE_SECONDS` = 120 s (+0.5 s), then stops by itself and prints the summary. `zts_probe.stop()` ends early.
    - Frame stats: frame count, mean / p50 / p95 / p99 / max interval (ms), count of intervals > 33.4 ms (the NFR1 fail line) and > 17.5 ms (missed 60 Hz vsync), effective FPS, and the detected refresh interval (median of the first second). On a 120/144 Hz screen report both raw and "frames over 33 ms"; NFR1 is judged on > 33 ms and FPS ≥ 60.
    - Latency (NFR2): on each keydown (`a`–`z`, not repeat), `evt.timeStamp` → the next rAF callback's timestamp; report count / p50 / p95 / max. Godot's single-threaded web main loop runs inside that rAF callback (it polls the queued key event and draws the frame there), so "next rAF − keydown ≤ one refresh interval" is the next-rendered-frame check. Note in the summary that the visual is presented at the following vsync.
    - Keys (AC 5): a bubble-phase `keydown` listener (added after the game's capture-phase one) records, for `" "`, `"'"`, `"/"`, `"Backspace"`, `"Tab"` and `"Escape"`: `evt.defaultPrevented`, `window.__zts && window.__zts.capture` (WebPlatform's flag, Story 1.5) and `window.scrollY` / `document.scrollingElement.scrollTop` before and after. `zts_probe.keys()` prints the table.
    - `zts_probe.result()` returns one JSON object (also `copy()`-able in Chrome/Edge) with the browser `navigator.userAgent`, `devicePixelRatio`, `screen.width/height`, `innerWidth/innerHeight`, the canvas size, and all of the above. The probe observes only; it never calls `preventDefault`, never touches storage, never sends anything (NFR12).
    - Low overhead: one `performance.now()` push per frame into a preallocated `Float64Array` (120 s × 240 Hz max), no console output while recording.
    - Focus: sample `document.hasFocus()` every 250 ms; report "frames while unfocused" and leave them out of the NFR1 numbers (a click into DevTools blurs the page and pauses the run, FR11).
    - `zts_probe.arm({startNow: true})` starts recording at once instead of on the first letter (to catch the load / first-music hitch before the first key; Dev Notes "What NFR1 measures"); its summary is labeled "load window", never mixed into M1's RUNNING row.
  - [x] 2.2 New `tools/perf/README.md` (short): how to paste the probe (Chrome/Edge: DevTools Console, allow pasting; Firefox: type `allow pasting` first), when to call `arm()`, how to read the summary, and the DevTools steps for each check (Dev Notes "Browser tool steps"). Smuck reads this on the laptop.
  - [x] 2.3 Try the probe yourself in the built-in browser pane on a local release export (`preview_start {name: "web-debug"}` — `.claude/launch.json` serves `build/web/` on 8060 whatever build is in it, so a release export there is fine). **Keep the pane on screen** — a hidden pane throttles rAF to ~1–2 fps (1.8 / 4.5 deferrals) and gives nonsense. Do one full 2:00 run typing through the pane, take the summary, and record it as the dev-machine reference row in M1 (not the target laptop). Compare against 3.4's debug-build reference: worst frame 22.7 ms. If the pane can't type fast enough, a shorter run labeled as such is fine for the reference.
  - [x] 2.4 Unit-test nothing in JS (no JS test runner in this project, and none may be installed without asking). Instead, a self-check in the probe: `zts_probe.selftest()` feeds a fixed interval list through the same summary function and prints PASS/FAIL against known numbers (e.g. `[16.7×58, 40, 16.7]` → max 40, over33 = 1). Run it once in the pane; record the output.
- [x] **Task 3: Gate A — prerequisites and decisions (AC: 1, 3, 8, 9)** — ask with `AskUserQuestion`, one question per decision, recommendation first; record verbatim with the date in `## Review Approval`.
  - [x] 3.1 **Firefox (Smuck installs it; the agent must not download or install software).** Firefox is still not installed on the dev PC (checked 2026-10-06), and AC 1, 4 and 5 require it. Ask Smuck to install it on the target laptop (and on the dev PC if Smuck wants the deferred 1.2/1.5/1.7 Firefox items closed there too).
  - [x] 3.2 **The build on the Pages link.** Pages still serves the **v0.0.1 hello world** (Story 1.2; deploys happen only from `v*` tags, ADR-4). AC 1/3/4/8 need the MVP on the Pages link. Recommend: Smuck approves pushing a pre-release tag `v0.9.0` from the tip of `main` after this story's tools commit (CI runs GUT, exports release, deploys). The link becomes public-reachable with the MVP before 5.5's `v1.0.0`; that's acceptable for friends-and-family (no one has the link yet), but it is Smuck's call. **Pushing a tag is outward-facing: do it only after an explicit yes in chat.** Alternatives to offer: (b) measure on a local release export served on the LAN (no Pages, so M3 stays an estimate and M8 needs the laptop on the same network); (c) a separate test repo / Pages site (more setup, not recommended).
  - [x] 3.3 **The target laptop.** Which machine is "2018-era with integrated graphics (or closest)"? Record make/model, CPU, GPU, RAM, OS, screen resolution and refresh rate, power state (plugged in; Windows power mode "Balanced"), browser versions. Also: which 3 family computers for M8 (they may include the target laptop; NFR17 says "3 different" — recommend the target laptop counts as one).
  - [x] 3.4 **What NFR1 measures** (Dev Notes): recommend "RUNNING window only; load hitches recorded and judged separately: a hitch over 100 ms that a kid can see (the 5.1 OGG decode ~110–165 ms on the dev PC, likely longer on the laptop) becomes a 5.5 fix item if it shows as a visible freeze on the target laptop".
  - [x] 3.5 **Who drives which session.** The agent can't use the target laptop. Recommend: the agent prepares everything (build, tag after approval, probe, tables, the runbook below) and Smuck runs Sessions 1–3 and pastes the probe JSON / numbers into chat; the agent fills the tables. Offer: Smuck may instead let the agent drive Smuck's Chrome on the dev PC through Claude in Chrome for the NFR4 rounds (if connected) — it can't close and reopen tabs as realistically, so the real-hand rounds stay the record.
- [x] **Task 4: Publish the test build (AC: 1, 3, 8)** — only after a yes at 3.2.
  - [x] 4.1 Commit the tools (Task 2) and the story file progress on `main` first, so the tag builds the tested state. CI on `main` must be green before tagging (`gh run list --branch main --limit 1`).
  - [x] 4.2 `git tag v0.9.0 && git push origin v0.9.0` (exactly the name Smuck approved). Watch the run once with `gh run watch <id>` (one wait, no polling loop). Record the run URL, artifact size, and the deploy result.
  - [x] 4.3 Check the link (`https://jacob-verburg.github.io/ZombiesTeachTyping/`) in the browser pane: title screen shows, console has no errors, F3 does nothing (release build: no overlay, Boundary 7), and the response headers for `index.wasm` / `index.pck` (`curl -sI -H "Accept-Encoding: gzip" <url>/index.wasm`): `content-encoding`, `content-length`, `cache-control`. Record them (1.2 saw `max-age=600`). If `index.pck` is not gzip-encoded by Pages (it's served as `application/octet-stream`, which GitHub Pages may not compress), the wire size is the raw pck: record that, it's the number M3 is judged on.
- [x] **Task 5: Runbook and result tables (AC: 1–9)**
  - [x] 5.1 Fill `## Smuck's Runbook` below with the concrete steps (already drafted; adjust to what Gate A decided and to the real tag/URL), one short block per session. Plain steps, one check per line, what "pass" looks like. Show it to Smuck before Session 1.
  - [x] 5.2 As Smuck reports each session, fill the `## Metrics Results` tables (M1–M8) with the numbers exactly as reported or as printed by the probe (paste the probe's `result()` JSON into `### Probe output` collapsed under each browser). Don't round a failing number into a pass. Anything Smuck reports in words ("felt smooth") is recorded as words, marked "observed", not as a number.
  - [x] 5.3 Each Fail → a `## Fix Items for 5.5` row: id (F1…), what failed, on which machine/browser, the measured number, a suspected cause (cite code), a suggested fix, and must-fix-before-publish vs post-MVP (Smuck's call at Gate B). Known candidates to pre-fill **only if they show up**: the OGG first-play decode hitch (5.1 deferral: `PLAYBACK_TYPE_STREAM` on the music players or shorter loops), the debug-only scenes in the pck (Task 1.3), Firefox Ctrl+Shift+E captured by the Network tool (1.8 deferral — matters for 5.4's save export if the playtest uses Firefox), letterbox bars black (1.2/5.0 deferral — cosmetic).
- [x] **Task 6: Windows Desktop smoke test (AC: 7)**
  - [x] 6.1 Export release: `"/c/Program Files/Godot/Godot.exe" --headless --path . --export-release "Windows Desktop" build/windows/ZombiesTeachTyping.exe`; check the exe and `.pck` exist and record their sizes. Windows templates were installed in 1.2 (`%APPDATA%/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe`); if missing, stop and ask (no downloads without Smuck).
  - [x] 6.2 **Trap — the real save.** The Windows export and the editor/dev runs share `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/` (no custom user dir in `project.godot`). On the dev PC: copy `save.json`, `save.bak` (and `save.tmp` if present) to the scratchpad first, run the smoke test, then restore them byte-for-byte and re-check the hash. Better: run the smoke test on a different Windows PC (Smuck's call at Gate A; it's "one Windows PC").
  - [x] 6.3 Smuck (or the agent, if on the dev PC and Smuck agrees; the agent can launch the exe from Bash but can't type a run for 2:00 — Smuck plays): start the exe → title → menu → one full Zombie Run → note brains on the report card → close the window (the X) → start again → same brains, same equipped hat/pet. Also check: windowed 1280×720 start (`window_size_override`), fullscreen toggle works, no console window, no debug overlay on F3. Record in M7. *(Review 2026-10-06: only a quit run was done, with no relaunch after the brains write; see M7.)*
- [x] **Task 7: Gate B — results review (AC: 8, 9)**
  - [x] 7.1 Show Smuck the filled M1–M8 tables, the fix-item list with a must-fix / post-MVP / no-action recommendation per row, and the screenshots under `_bmad-output/implementation-artifacts/screenshots/5-3/`. Ask per fix item (batch up to 4 per `AskUserQuestion`), recommendation first. *(Review 2026-10-06: no screenshots were taken; see Review Approval.)*
  - [x] 7.2 Record the verbatim answers with the date in `## Review Approval`. **No status change to review without it.**
- [x] **Task 8: Wrap-up (AC: 9)**
  - [x] 8.1 `deferred-work.md`: strike with `~~…~~ Done in 5.3: …` (or add "5.3: measured, <result>") each item this story measured: 1.2 Firefox load/1366 checks; 1.5 Firefox per-key table and Firefox Esc-in-fullscreen; 1.7 NFR4 in Firefox; 1.8 "Firefox Ctrl+Shift+E" (record what happened; the fix, if any, is 5.5); 2.7 "Esc in browser fullscreen … whether it also pauses is Story 5.3's check"; 3.4 "target-laptop check is Story 5.3"; 5.1 "OGG first-play hitch … part of 5.3"; 1.6 "`run_history` bounds still open for Epic 5" (bounded: `GameConstants.RUN_HISTORY_CAP = 500`, `PlayerData.record_run`; strike it); 2.10 / 1.8 "real Chrome/Edge F6/F7" (debug-only keys; release has no F-key bindings — note "release: n/a", leave the debug question open or answer it if Smuck tried it). Add "Deferred from: dev of story 5-3" for anything left open.
  - [x] 8.2 Full suite twice (import first), real `save.json` hash unchanged. No game code is expected to change in this story; if anything in `scripts/`, `scenes/`, `data/` or `project.godot` changed, it needs its own test and a reason in the Change Log (and is probably a 5.5 item instead).
  - [x] 8.3 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`. Suggested commit: `Story 5.3: technical metrics on family computers`. Screenshots under `screenshots/5-3/` are committed; probe JSON stays inline in this file.

## Smuck's Runbook

_(Updated after Gate A, 2026-10-06. Machine: the dev PC (it stands in for the laptop). Browsers: Chrome and Edge (Firefox skipped). Link: https://jacob-verburg.github.io/ZombiesTeachTyping/ (v0.9.0). Paste results into chat; the agent fills the tables.)_

**Before you start:** close other apps and tabs; browser zoom 100 %; open `tools/perf/README.md` beside the browser. To get the probe, open `tools/perf/frame_probe.js` in your editor, select all and copy.

**Session 1: dev PC, Chrome, then Edge**

1. **Load (M3).** F12 → Network. Tick **Disable cache**; throttling → your "25 Mbit/s" custom profile (README). Reload. Note: "transferred" at the bottom, and seconds until the title screen shows. Then untick Disable cache (throttle still on), reload, note the seconds again. Pass: first ≤ 10 s, cached ≤ 3 s, transferred ≤ 40 MB.
2. **Frame rate + latency (M1, M2).** Throttling off. Console tab: paste the probe, Enter. Title → menu → Zombie Run. On "Type the letter to start!": `zts_probe.arm()`, Enter, **click the game**, type. Play the full 2:00; get the conga badge past ×12. Don't touch DevTools until the report card. Then `copy(JSON.stringify(zts_probe.result()))` and paste into chat. Pass: `> 33 ms: 0`, FPS ≥ 59, latency max ≤ ~16.7 ms.
3. **Load hitch (M1 "load hitches").** Reload. On the title screen: paste the probe, `zts_probe.arm({startNow: true})`, click the game, go menu → Zombie Run, wait on "Type the letter to start!", then `zts_probe.stop()` and send the summary lines. Also say whether you *saw* a freeze.
4. **Evidence (M1).** Performance tab, tick Screenshots, record ~20 s mid-run, stop, screenshot the frames track. Save it as `screenshots/5-3/m1-<browser>-perf.png` under `_bmad-output/implementation-artifacts/`.
5. **Keys (M5).** During a run press Space, `'`, `/`, Backspace, Tab a few times each. Esc to pause, press them again (note: Space resumes). Pass: no scrolling, no find bar, focus stays on the game. Quit to Menu, check `/` and Tab work normally in the browser. Send `zts_probe.keys()` output (or a screenshot of it). Then turn on fullscreen (menu button), start a run, press Esc once: does it leave fullscreen, pause, or both?
6. **Screen (M6).** The dev PC screen is 1920×1080, so emulate the 1366×768 laptop: DevTools → device toolbar (Ctrl+Shift+M) → Responsive → 1366 × 768. Does the game fill it (bars only at the sides), are pixels sharp, is the small text ("Crypt Closet", HUD stats) readable from your seat? Then real fullscreen at 1920×1080: same questions. Save `screenshots/5-3/m6-<browser>-1366.png` and `m6-<browser>-fullscreen.png`.

**Session 2: save integrity (M4), Chrome and Edge.** DevTools → Application → Storage → "Clear site data" (or a fresh profile). Play one Zombie Run, open the gift, buy and wear an item. Note brains, item, best WPM. Then 10 reloads (F5; rounds 3, 6 and 9 within 1 s of a purchase or Wear) and 10 tab closes on the main menu (Ctrl+W, reopen the link). One line per round, e.g. `R4 reload: 37 brains, owns+wears Party Hat, best 9 WPM, ok`.

**Session 3: Windows Desktop (M7), dev PC.** Tell me when you start; your real save is backed up and I'll restore it afterwards. Run `build/windows/ZombiesTeachTyping.exe`. Check: it opens windowed 1280×720, no console window, F3 does nothing. Title → menu → one full Zombie Run → note brains on the report card → close with the X → start again → same brains and same hat/pet? Fullscreen toggle works? Tell me when done.

**Session 4: one family computer (M8).** Someone else opens the link on another family computer, sent the way you'd share it, with no help. Note: computer type + browser, did it load, did they get into a run, anything that stopped them. (Recorded as "family computer #1", no names.)

## Metrics Results

_(Filled from Smuck's reports and the probe output. Pass / Fail / Skipped (+ Smuck's reason) per row.)_

**Target laptop:** none. Per Smuck's Gate A answer ("Dev PC is closest"), the dev PC stands in: HP OMEN by HP 40L Gaming Desktop GT21-0xxx, AMD Ryzen 7 5700G, NVIDIA GeForce RTX 3070 (discrete, not integrated), 15.6 GB RAM, Windows 11 Home, 1920×1080 at 60 Hz, Windows power plan Balanced, Chrome 154.0.8037.98, Edge 154.0.4258.53. **Deviation:** this is far stronger than the 2018-era integrated-graphics laptop NFR1 names, so a pass here is weak evidence for weaker family computers (the gap is recorded in `deferred-work.md`). · **Build:** `v0.9.0` at `485b928`, CI https://github.com/Jacob-Verburg/ZombiesTeachTyping/actions/runs/37556023613 (build + deploy green; artifact `github-pages` 12,493,831 B) · **Dates:** dev-PC pane reference 2026-10-06

**M1 — Frame rate, RUNNING window (NFR1)**

| Browser (version) | Frames | Mean ms | p99 ms | Max ms | > 33 ms | FPS | Conga total / drawn | Load hitches (ms, where) | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Dev PC reference (pane, Chromium 152, **local release export**, 2026-10-06) | 7236 | 16.65 | 16.8 | 18.4 | 0 | 60.05 | ×62 at 0:08 (badge showing) / 12 | not armed (see 5.1: 110–165 ms OGG decode) | ref (NFR1 met on dev PC) |
| Chrome | — | — | — | — | — | — | — | — | Skipped: "lets skip chrome and continue" |
| Edge 154 (dev PC; **DevTools device emulation on**: UA "Android 16; Pixel 10 … Edg/154", DPR 2, 1366×768 viewport, canvas 2732×1536) | 7236 | 16.65 | 16.8 | 17.0 | 0 | 60.05 | over 100 (observed, Smuck: "I got the gonga line over 100") / 12 | not captured | Pass |
| Firefox | — | — | — | — | — | — | — | — | Skipped: "Skip Firefox" |

**M2 — Input latency (NFR2):** keydown → next frame

| Browser | Keys | p50 ms | p95 ms | Max ms | Refresh ms | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Chrome | — | — | — | — | — | Skipped: "lets skip chrome and continue" |
| Edge 154 (emulated 1366×768, DPR 2) | 196 | 7.6 | 15.2 | 16.9 | 16.7 | Pass (max 16.9 ≤ 16.7 + 0.5 tolerance) |
| Firefox | — | — | — | — | — | Skipped: "Skip Firefox" |

Code-level proof (same call, no frame wait): `tests/integration/test_run_frame.gd::test_level_reacts_in_the_same_call`, `::test_first_correct_key_updates_hud`, `::test_wrong_key_updates_hud_in_the_same_call`, `tests/unit/test_zombie_run_level.gd::test_correct_key_advances_in_the_same_call`, `::test_brain_block_key_pays_in_the_same_call`, `::test_chaining_never_caps_typing`.

**M3 — Load (NFR3)**

| Browser | Throttle used | Transferred MB | First load s | Cached load s | Result |
| --- | --- | --- | --- | --- | --- |
| Chrome | — | — | — | — | Skipped: "lets skip chrome and continue" |
| Edge | not run | wire total ≈ 12.55 MB (agent, curl on Pages, Task 4.3) | not timed (estimate: ≈ 4 s transfer at 25 Mbit/s + wasm compile) | not timed | Pass (Smuck's call, **not measured**: "mark these as pass and continue") |
| Firefox | — | — | — | — | Skipped: "Skip Firefox" |

Local export sizes (Task 1.2, release, 2026-10-06; gzip level 6, the Pages-like estimate):

| File | Raw B | Gzip B |
| --- | --- | --- |
| index.wasm | 39,514,754 | 10,114,291 |
| index.pck | 2,497,016 | 2,212,419 |
| index.js | 279,815 | 68,740 |
| index.apple-touch-icon.png | 11,939 | 11,962 |
| index.audio.worklet.js | 7,298 | 2,204 |
| index.html | 6,667 | 2,588 |
| index.icon.png | 5,765 | 5,788 |
| index.png | 2,984 | 3,007 |
| index.audio.position.worklet.js | 2,973 | 1,167 |
| **Total shipped** | **42,329,211** | **12,422,166** |

vs 1.2's hello world 10,350,910 B on the wire: +~2.1 MB, nearly all the pck (the two OGG loops are 1,055,210 + 806,482 B of the 2,448,833 B of pck content). Far below the ~30 MB 10-second budget and the 40 MB check. (Three stale `*.import` files in `build/web/` are local Godot imports, not part of the CI artifact; excluded.)

Debug-only content in the pck (Task 1.3, parsed from the pck directory, format 4, 471 files): 49,962 B in total (scripts/debug/* incl. the debug overlay and frame tracker 35,746; keyboard_test 6,648; test_level 3,160; art_review 2,775; hat_fit_check 1,212; scenes/debug remaps 421). That is 2.0 % of the pck and ~0.4 % of the download: no M3 impact, so no fix item. 5.5 may still drop them for tidiness.

Pages headers (Task 4.3, 2026-10-06, `curl -sI -H "Accept-Encoding: gzip"`): every file `Content-Encoding: gzip`, `Cache-Control: max-age=600`. Wire `Content-Length`: index.wasm 10,248,949 (`application/wasm`), index.pck 2,224,190 (`application/octet-stream`, compressed too), index.js 69,442, index.html 2,586. Wire total ≈ 12.55 MB. Live check in the pane: title → menu loads, console only engine/info lines (no errors), F3 does nothing (release).

**M4 — Save integrity (NFR4):** one row per round per browser (round, kind: normal / fast after buy / mid-menu close, brains, owned, worn, best WPM, lost?)

| Browser | Round | Kind | Brains | Owned / worn | Best WPM | Lost? |
| --- | --- | --- | --- | --- | --- | --- |
| Edge 154, dev PC (2026-10-06) | R1–R10 | reload (F5); R3, R6, R9 fast after a buy/Wear | not reported per round | not reported per round | not reported per round | none (observed) |
| Edge 154, dev PC (2026-10-06) | R11–R20 | tab close on the main menu (Ctrl+W, reopen) | not reported per round | not reported per round | not reported per round | none (observed) |
| Chrome | — | — | — | — | — | Skipped: "lets skip chrome and continue" |
| Firefox | — | — | — | — | — | Skipped: "Skip Firefox" |

M4 result: **Pass** for Edge. Smuck's report, verbatim: "all 20 rounds good". The procedure was given in chat (clear site data → run → gift → buy + Wear → 10 reloads incl. 3 fast → 10 mid-menu tab closes). Per-round values weren't reported, so the rows are summarized. Firefox IndexedDB persistence is still unmeasured (1.7 deferral stays open).

**M5 — Browser keys in a real run**

| Browser | Key | Run: scroll / find / focus | Paused: scroll / find / focus | `defaultPrevented` | Menu after: normal? | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Pane (Chromium 152, agent, local release) | Space, Backspace, Tab | no scroll / — / canvas | no scroll / — / canvas | true | not checked | reference only |
| Pane | `/`, `'` | not sent by the pane (2.4 limitation) | — | — | — | not tested |
| Edge | all five | not run | not run | — | not run | Pass (Smuck's call, **not measured**: "mark these as pass and continue") |
| Chrome | — | — | — | — | — | Skipped: "lets skip chrome and continue" |
| Firefox | — | — | — | — | — | Skipped: "Skip Firefox" |

Esc in fullscreen during a run: not tested (Smuck: "mark these as pass and continue"). The 2.7 deferral stays open.

**M6 — Screen 1366×768**

| Browser | Windowed: fills / sharp / 16 px readable | Fullscreen: fills / sharp / readable | Screenshot | Result |
| --- | --- | --- | --- | --- |
| Edge | not run | not run | none | Pass (Smuck's call, **not measured**: "mark these as pass and continue") |

**M7 — Windows Desktop fallback**

| PC | Starts | Zombie Run plays | Save kept across restart | Notes | Result |
| --- | --- | --- | --- | --- | --- |
| Dev PC (Windows 11, RTX 3070), release exe 2026-10-06 | yes, 3 launches (logs 18:33:29, 18:35:58, latest) | started and played; the logged run ended by **quit** (`[run] quit level=zombie_run brains=9`), not a full 2:00 | the exe loaded `save.json` on every launch, and the quit run's 9 brains were written (`save.json` brains 59 → 68 at 18:36:20, `save.bak` = previous generation); no exe launch is logged after that write | Smuck: "These look good". Fullscreen button icon wrong (F1). Shares the dev save folder (Gate A choice). The agent's first hash check ran while the exe was still open and wrongly reported "unchanged"; caught at the final check, and the real save was restored byte-for-byte from the scratchpad backup (sha256 `c34c…1761d` both files) | Pass (Smuck: "passing"; gap: reloading the newly written save after a restart not exercised) |

**M8 — Reach (NFR17)**

| # | Computer / OS / browser | Loaded | Played without help | What stopped them | Result |
| --- | --- | --- | --- | --- | --- |
| 1 | not run | — | — | — | Pass (Smuck's call, **not measured**: "Mark as pass") |
| 2 | not required (Gate A: "One computer is fine, dont need 3") | — | — | — | n/a |
| 3 | not required (same) | — | — | — | n/a |

### Probe output

_(Paste each browser's `zts_probe.result()` JSON here inside a `<details>` block.)_

<details><summary>Edge 154, dev PC, device emulation on (pasted by Smuck 2026-10-06)</summary>

```json
{"probe":"zts_probe 5.3","user_agent":"Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 (KHTML, like Gecko) Edg/154.0.0.0 Mobile Safari/537.36","device_pixel_ratio":2,"screen":{"width":1366,"height":768},"inner":{"width":1366,"height":768},"canvas":{"width":2732,"height":1536,"css_width":1366,"css_height":768},"state":"done","run":{"label":"RUNNING (first letter -> 120 s)","duration_s":120.5,"frames_while_unfocused":0,"nfr1":{"frames":7236,"mean_ms":16.65,"p50_ms":16.7,"p95_ms":16.7,"p99_ms":16.8,"max_ms":17,"over_33ms":0,"over_17_5ms":0,"fps":60.05,"refresh_ms":16.7,"nfr1_pass":true},"raw_including_unfocused":{"frames":7236,"mean_ms":16.65,"p50_ms":16.7,"p95_ms":16.7,"p99_ms":16.8,"max_ms":17,"over_33ms":0,"over_17_5ms":0,"fps":60.05,"refresh_ms":16.7,"nfr1_pass":true},"nfr2_latency":{"keys":196,"p50_ms":7.6,"p95_ms":15.2,"max_ms":16.9,"refresh_ms":16.7,"nfr2_pass":true,"note":"keydown timeStamp -> next rAF frame timestamp; the visual is presented at the following vsync"}},"keys":[]}
```

</details>

## Fix Items for 5.5

_(F1… : what failed · machine / browser · number · suspected cause (code ref) · suggested fix · Smuck's call: must-fix-before-publish / post-MVP / no action.)_

| Id | What failed | Where | Measured | Suspected cause | Suggested fix | Smuck's call |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | Main-menu Fullscreen toggle shows the wrong state. In the Windows exe the icon flips but backwards (red slash on the wrong state); on the web the icon always shows the red slash. Fullscreen itself works. NFR8: the slash carries the state. | Windows exe (dev PC); web (Edge) | observed by Smuck, 2026-10-06 | `main_menu.gd:219-221` calls `toggle_fullscreen` then immediately `_sync_fullscreen()` → `is_fullscreen()` (`web_platform.gd:72`), but the window-mode change is applied later (async in the browser, and possibly a frame late on desktop), so it reads the old state. The resync hook `get_tree().root.size_changed` (`main_menu.gd:66`) probably never fires because `window/stretch/mode="viewport"` keeps the root viewport at 640×360. | Resync after the mode change lands: a deferred/short-timer re-read after the flip plus a window-level signal (`get_window()` / `DisplayServer` window size or `NOTIFICATION_WM_SIZE_CHANGED`), or poll `is_fullscreen()` while the menu is open. Add a test with a delayed `is_fullscreen` seam. | **Must-fix before publish** (Gate B: "Must-fix before publish (Recommended)") |


## Review Approval

**Gate A (2026-10-06)**, AskUserQuestion answers verbatim:

- 3.2 Pages build: "Yes, tag v0.9.0 (Recommended)"
- 3.4 NFR1 scope: "Running window only (Recommended)"
- 3.5 Sessions: "You run, I fill (Recommended)"
- 6.2 Windows PC for M7: "Dev PC, save backed up"
- 3.1 Firefox: "Skip Firefox". (No further reason given; AC 1, 4, 5 Firefox rows are Skipped with these words.)
- 3.3 Target laptop: "Dev PC is closest"
- 3.3 M8 computers: "One computer is fine, dont need 3"
- After the Edge run (2026-10-06): "yes I got the gonga line over 100.  lets skip chrome and continue"
- M3, M5, M6 (2026-10-06): "mark these as pass and continue"
- M4 (2026-10-06): "doing number 2, i will report if anything is lost" … "all 20 rounds good"
- M7 (2026-10-06): "These look good, however  the fullscreen button behaves a little differently in the .exe vs web, in the .exe it toggles the graphic (but seems backwards with the red slash on the wrong one) and in the web the graphic always has red slash"
- M7 gap (2026-10-06), asked whether to re-run a full exe run or record with the gap: "passing"
- CI blocker (found at Task 4.1: CI red on `main` since Story 3.3): "Narrow the CI grep (Recommended)"


**Gate B (2026-10-06)**, AskUserQuestion answers verbatim:

- M8 (reach): "Mark as pass"
- F1 (Fullscreen toggle icon state): "Must-fix before publish (Recommended)"

Results shown to Smuck in chat during the sessions (M1/M2 Edge numbers, M4, M7 log findings, F1 cause). No screenshots were taken for M6 or the Performance recordings (M6 marked pass by Smuck's call), so `screenshots/5-3/` stays empty and isn't committed.

### Review Findings

Code review 2026-10-06 (Blind Hunter, Edge Case Hunter, Acceptance Auditor; range `485b928^..7670453`).

- [x] [Review][Decision] (resolved: keep as is, Smuck's call, dismissed) CI grep no longer fails on runtime `SCRIPT ERROR` — Smuck narrowed the pattern to `Parse Error|Compile Error|Failed to load script` because deliberate `assert_engine_error` lines in `test_villager.gd` failed every `main` build. Side effect: real runtime script errors no longer fail CI (Story 1.2 wanted that). Options: keep as is, or restore `SCRIPT ERROR` and filter only the known Villager assertion line (`grep -E "SCRIPT ERROR" gut.log | grep -v "Villager state can only move forward"`). [.github/workflows/build.yml:60]
- [x] [Review][Decision] (resolved: keep Smuck's Pass calls as recorded, dismissed) M3, M5, M6, M8 are marked Pass with no measurement, and M1/M2 Edge is emulated mobile Chrome-UA, not desktop Edge — AC9 says every row is Pass, Fail or Skipped with Smuck's reason; the cells say "not run"/"not timed". M8 still says "3 family computers" in the AC after Gate A cut it to one. Gate B approval covers only M8 and F1, not an overall sign-off (Task 7.2). Options: relabel these rows Skipped (with the reason) and keep the open items in `deferred-work.md`, or leave Smuck's Pass calls as recorded. [story: Metrics Results]
- [x] [Review][Patch] (resolved from decision: keep thresholds, document them in the AC and README) Probe thresholds are looser than the spec — NFR1 passes at FPS >= 59 (spec: >= 60), `> 33 ms` is actually `> 33.4 ms` (so one dropped 60 Hz frame at 33.33 ms never counts), and NFR2 passes at `max(refresh, 16.7) + 0.5` ms (spec: <= 17 ms). All are deliberate for 59.94 Hz panels and vsync rounding but undocumented in the story. Options: tighten the code, or keep it and document the tolerances in the AC/README. [tools/perf/frame_probe.js:110,209]
- [x] [Review][Patch] `refresh_ms` is taken from the first second of the run (startup hitches, includes unfocused frames), and it drives the NFR2 limit — a 30 Hz-capped tab reports NFR2 PASS at ~33.8 ms. Use the median of all focused intervals and floor the limit at 16.7 ms. [tools/perf/frame_probe.js:196-209]
- [x] [Review][Patch] Letter detection is lowercase `a-z` only — Caps Lock, Shift, Dead or IME keys never start `arm()` and are never counted as latency samples. Lowercase `evt.key` first and ignore `evt.repeat`. [tools/perf/frame_probe.js:135-138]
- [x] [Review][Patch] Load-window runs still print `NFR1 PASS/FAIL` and fill `nfr1_pass`, which can be mistaken for the M1 RUNNING verdict (Task 2.1 says never to mix them). Print a neutral label in load-window mode. [tools/perf/frame_probe.js: `buildRun`, `printSummary`]
- [x] [Review][Patch] Key rows and latency buffer drop silently: `MAX_KEY_ROWS = 500` fills up with auto-repeat rows and `MAX_KEYS = 4000` discards latencies, with no warning. Skip `repeat` events for rows and report a truncation count in `result()`. [tools/perf/frame_probe.js:281-299]
- [x] [Review][Patch] `arm()` after "done" does not clear `lastRun` and `keyRows`, so a second run mixes keys from earlier runs and screens. Reset both in `arm()`. [tools/perf/frame_probe.js:332-342]
- [x] [Review][Patch] Hidden-tab / blur gaps can leak into the stats because the focus flag is polled every 250 ms and goes stale (background timers throttle to ~1 s). Also treat `document.hidden` as unfocused (listen to `visibilitychange`), and drop intervals longer than a sanity bound from the pass/fail counts but report them. [tools/perf/frame_probe.js:197-205,266]
- [x] [Review][Patch] The frame cap (`MAX_FRAMES = ceil(121*240)`) ends a run early on > 240 Hz screens with only `duration_s` as a hint. Set a `truncated` flag and print a warning. [tools/perf/frame_probe.js:238-254]
- [x] [Review][Patch] README drift: `> 33 ms` row should say 33.4, `selftest PASS` only covers the pure math (not the capture path), `scrolled: false` is not proof (smooth scrolling, a page without overflow) so `defaultPrevented` is the reliable signal, and the "No more than one refresh" row needs the 144 Hz caveat. [tools/perf/README.md]
- [x] [Review][Patch] Dangling "(see Fix Items)" in the Metrics Results header — `## Fix Items for 5.5` has only F1; the weak-hardware gap lives in `deferred-work.md`. Fix the pointer. [story: Metrics Results]
- [x] [Review][Patch] Task checkboxes overstate: 6.3 (full run, close, relaunch, same brains and hat/pet) was only a quit run with no relaunch, and 7.1 ("show the screenshots") has none. Untick or annotate them. [story: Tasks 6.3, 7.1]
- [x] [Review][Defer] NFR1/NFR2 on weak (2018-era) hardware, Chrome, and Firefox are unmeasured — deferred, pending measurement (already in `deferred-work.md`)
- [x] [Review][Defer] M4 not recorded per round (aggregate rows only) and not run for Chrome — deferred, pending measurement
- [x] [Review][Defer] M7: exe not relaunched after the 59 → 68 brains write; windowed start, no console window, F3 overlay and fullscreen toggle sub-checks not recorded — deferred, pending measurement
- [x] [Review][Defer] Load hitch (5.1 OGG decode, runbook step 3) not captured, with no Skipped label — deferred, pending measurement
- [x] [Review][Defer] Key watcher matches `evt.key`, so `'` as a Dead key (US-International) and Shift+`/` are not logged; the game's `CAPTURED_KEYS` has the same limit — deferred, low
- [x] [Review][Defer] Selftest covers only `summarize`/`latencySummary`, not `buildRun`, the state machine or the key/scroll paths; Firefox timer precision (`resistFingerprinting`) is not in the README — deferred, low

Dismissed as noise (8): latency measured to frame start (inherent, stated in the probe's `note`), negative-delta clamp, `===` float compare in selftest, `removeEventListener` options, listener-order worry (verified: the game's capture listener on `window` registers first and `window.__zts.capture` is the real flag; `tools/*` is in the export `exclude_filter`), README paste-into-console warning, empty `screenshots/5-3/`, Task 5.1 evidence.

## Dev Notes

### What this story is (and isn't)

- **Is:** measurement and evidence. Prepare a release test build on the Pages link (with Smuck's OK), a console frame/latency/key probe, a runbook Smuck can follow on real family computers, the M1–M8 result tables, and a triaged fix list for 5.5. Close the Firefox and target-laptop items that earlier stories deferred to here.
- **Isn't:** fixing the game (failures → `## Fix Items for 5.5`; 5.5's AC: "the must-fix items from Stories 5.3 and 5.4"); the kid playtest (5.4); publishing `v1.0.0` or the how-to-play note (5.5); new debug features in the game; removing the debug-only scenes from exports (record their size; 5.5 decides); any install or download (Firefox is Smuck's to install; no npm/pip packages).
- The only new files are dev tools under `tools/perf/` (export-excluded by both presets' `exclude_filter`: `tools/*`) and screenshots. No change under `scripts/`, `scenes/`, `data/`, `assets/`, `project.godot` or `export_presets.cfg` is expected.

### What NFR1 measures (Gate A 3.4)

- NFR1: "a full 2:00 Zombie Run with 12 conga followers drawn, with no frame over 33 ms". The run is 2:00 from the first correct key (FR6: the timer starts there), so the window is RUNNING: first letter → 0:00. The end dance (2.0 s) and the report card are outside it, and so is the level load before the first key.
- Known hitches outside the window (5.1 deferral, dev PC, Chromium): the first play of each 96 s OGG music loop is one long main-thread task (Godot decodes the whole OGG into a Web Audio buffer): ~110–145 ms at the title unlock, ~165 ms entering the first run. On a 2018 laptop this may be 300–600 ms — a visible freeze while "Type the letter to start!" shows. It does not break NFR1 as written, but it's what a kid sees. Record it (the probe isn't armed yet at that point: read it from the Performance recording of the load, or arm the probe early with `zts_probe.arm({startNow: true})` for one extra capture — add that option) and let Gate B decide.
- The 3.4 debug overlay "run worst" also counts RUNNING frames only, so the reference numbers line up. The release build has no overlay (Boundary 7: debug code instanced only when `OS.is_debug_build()`), which is why the probe lives in the browser console, not in the game.
- Measure the **release** build (CI `--export-release`). The 3.4 reference (22.7 ms worst, RTX 3070) was a debug build in the pane; debug GDScript is slower, so release on the same machine should be no worse.
- 12+ followers: the conga line draws at most 12 and shows "×N" beyond (FR35, `conga_max_drawn`); a normal 2:00 run at ~1 key/s gets 20–90 joins (3.4: conga total 87). If Smuck types slowly, check the badge showed; otherwise the run doesn't meet "12+".

### Why a console probe (and not the game) for frame times

- `requestAnimationFrame` pacing is the browser's frame clock; Godot's web export (single-threaded, `emscripten_set_main_loop`) runs one engine iteration per rAF, so rAF intervals = the game's frame times, including GC and audio decode stalls. It works identically in Chrome, Edge and Firefox, on the release build, with no code shipped to kids (NFR12: no analytics; nothing leaves the page).
- The AC asks for "the browser performance tools": the probe runs in DevTools' Console, and one short Performance / Firefox Profiler recording per browser is the visual evidence. A 2:00 profiler recording on a weak laptop distorts the result (profiling overhead), so it's not the number.
- Latency: a key event is queued by the browser, Godot reads it at the start of its next iteration (inside the next rAF callback), the level advances the target in that same call (tests listed under M2), and the frame drawn in that callback shows it; it's presented at the next vsync. So "keydown → next rAF ≤ one refresh interval" plus the same-call tests is the NFR2 proof. If the max is over one interval but frames are fine, check whether the key landed during a long frame (it'll match a > 17 ms frame in M1).

### Browser tool steps (for the README and the runbook)

- **Chrome / Edge (154):** DevTools → Network → throttling dropdown → "Add…" a custom profile "25 Mbit/s": download 25000 kbit/s, upload 5000 kbit/s, latency 20 ms. "Disable cache" for the first load. Performance panel → record, "Screenshots" checked; the Frames track shows long frames in red/yellow. Pasting into the Console asks you to type "allow pasting" once.
- **Firefox:** Network throttling has presets only (no custom value as far as known — verify on the machine); the closest to 25 Mbit/s is "Wi-Fi" (30 Mbit/s). Use it and note it in M3; the Chrome/Edge 25 Mbit/s numbers are the governing ones. Profiling: the built-in Firefox Profiler (Performance tab → "Graphics" preset). Pasting needs "allow pasting" typed first. `copy()` exists in Firefox's console too, but if it fails, print the JSON and copy by hand.
- **Throttle realism:** DevTools throttling caps throughput but not the CPU; a first load on the laptop also includes wasm compile time (CPU-bound, much slower on a 2018 CPU than the dev PC). That's what M3 wants to catch: time to the title screen, not just the transfer.
- **Cached load:** Godot's loader re-requests files; Pages sends `Cache-Control: max-age=600` with a weak ETag (1.2). Within 10 minutes the cached load is from disk cache; after that, 304 revalidations. 1.2 saw the pane re-download `index.wasm` every time (small HTTP cache); real browsers (Chrome ~1.2 s, Edge ~1.3 s cached in 1.2) didn't. Record which happened (the Size column shows "(disk cache)" or a 304).

### Expected weak spots (check, don't assume)

- **Download size (M3):** 1.2's hello world was 10.35 MB on the wire (mostly the 10.2 MB wasm template). The MVP adds the pck (sprites, two 60–120 s OGG loops, WAVs, font). Measure in Task 1.2 before tagging. The architecture says the 10 s budget ≈ 30 MB on the wire at 25 Mbit/s; the 40 MB "check" is secondary (NFR3: "The 10 s load time is the governing rule").
- **Firefox (never tested in this project):** IndexedDB persistence (NFR4), quick-find on `'` and `/` (the JS key listener ships enabled as a hedge, 1.5), Ctrl+Shift+E taken by the Network tool (1.8), Esc in fullscreen. Firefox's WebGL 2 on an old Intel iGPU may also be slower than Chromium's ANGLE.
- **Integrated GPUs at fractional scale:** the 640×360 viewport is drawn at 640×360 then scaled (`window/stretch/mode="viewport"`), so fill cost is tiny; the risk is CPU (GDScript `_process` of up to 12 followers + targets + backdrop parallax) and GC, not the GPU.
- **Background tabs / hidden pane:** throttled rAF reads as ~1–2 FPS; only a visible, focused tab gives real numbers (1.8 deferral). The run auto-pauses on blur (FR11), so clicking into DevTools mid-run **pauses the run** — arm the probe before the first key and don't touch DevTools until the report card.
- **The probe vs. pause:** if Smuck clicks DevTools by accident, the run pauses (blur) and rAF keeps running — the summary will include paused time. The probe should also record `document.hasFocus()` per frame (cheap: sample once per 250 ms) and report "frames while unfocused" so a paused stretch is visible; exclude unfocused frames from the NFR1 numbers and say so.

### Existing code: what this story touches and must preserve

- **No game code changes.** Read-only references: `scripts/autoloads/web_platform.gd` (`CAPTURED_KEYS = [" ", "'", "/", "Backspace", "Tab"]`, `window.__zts.capture`, the capture-phase listener that skips Ctrl/Meta/Alt combos), `scripts/run/run_frame.gd` (`capture_keys = true` in `_ready()`, false in `_exit_tree()`: on for the whole run including pause and countdown, off on the report card and menu — M5's "menu afterwards"), `scripts/debug/frame_tracker.gd` + `debug_overlay.gd` (debug-only frame tracking; don't reuse in release), `scripts/autoloads/save_service.gd` (atomic write, `visibility_hidden` immediate write; 1.7 measured no loss in Chrome/Edge), `scripts/autoloads/player_data.gd` (`RUN_HISTORY_CAP` 500), `scripts/autoloads/audio_manager.gd` (music players; the OGG hitch).
- **`.github/workflows/build.yml`:** unchanged. Tags `v*` deploy; `main` builds an artifact only. Existing tags: `v0.0.1`. The tag must point at a commit whose CI on `main` passed.
- **`export_presets.cfg`:** unchanged; `test_export_presets.gd` pins the head include byte-for-byte.
- **The probe must never ship:** it lives in `tools/perf/`, which both presets exclude. Don't add it to the head include "just for the test".

### NFR8 in the epic's AC 7

- The epic writes "(NFR8 fallback smoke check)" for the Windows export, but NFR8 is color accessibility. The fallback is NFR5 ("Windows desktop is a fallback with the same save contents"). Use NFR5 in the tables; note the epic typo in the Change Log (don't edit `epics.md` silently — list it in deferred-work for the PM, like 5.2's FR27 wording note).

### Testing notes

- GUT 9.7.1: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Expect 1319+ (5.2 end), all passing, no new tests unless game code changes.
- Serving locally: `python -m http.server 8060 -d build/web` (1.7) or the `.claude/launch.json` config for `preview_start` (read it; reuse the existing entry, don't add a second server on 8060).
- Built-in pane: Chromium 152-ish; not one of the three target browsers, so pane numbers are a reference only. It can't throttle the network.
- `gh` CLI for CI: `gh run list`, `gh run watch` (one wait). Don't schedule or loop polls.

### Previous story intelligence

- **5.2:** gates as `AskUserQuestion`, one question per decision, recommendation first, answers recorded verbatim with the date; checklists as tables with Pass/Fail + note; screenshots under `screenshots/<story>/`; hash the real save around every run; a story-file section replace once cut half the story — match headings line-anchored when filling tables. Suite 1319. Its deferrals: brittle counts, the capture tool's missing guards (dev-only) — not this story's.
- **5.1:** the OGG first-play decode hitch (named for 5.3); the pane crossfade stretched because the pane ran ~15 fps after a level load — pane timing is not representative.
- **3.4:** first NFR1 check (debug build, pane, dev PC): worst 22.7 ms, 116 keys, conga 87, badge showing; the overlay's run-worst counts RUNNING frames only.
- **1.7:** NFR4 procedure (10 reloads incl. 3 fast, 10 tab closes incl. 3 mid-menu and 3 fast) in Chrome + Edge, all pass, no per-round table (deferred: re-run with one). This story's M4 uses real brains + a purchase (the Keyboard Test counter is a debug screen) and records per round.
- **1.5:** the JS key listener is a hedge for Firefox quick-find; `'` and `/` were never proven on a real keyboard in a real run (2.4 deferral: the pane sends an empty `key` for them).
- **1.2:** Pages URL `https://jacob-verburg.github.io/ZombiesTeachTyping/`; Pages gzip; `max-age=600`; 10,350,910 B hello world; throttled loads and Firefox skipped by Smuck's decision then — this story is where they're due.
- **Traps:** the real save (Windows export shares `app_userdata/ZombiesTeachTyping`); hidden-pane throttling; blur pauses the run; LF line endings (`.gitattributes eol=lf`) for the new `.js`/`.md`; never edit `build/` for a commit; outward-facing actions (tag push) only after an explicit yes.

### Git intelligence

- One commit per story (code, tools, story file, sprint status, screenshots). Recent: `a173428 Story 5.2: readability, color and plain-words check …`, `2f3fb43 Story 5.1 …`, `4d3fb6f Story 5.0 …`. This story may need **two** commits: the tools commit before the tag (Task 4.1) and the results commit at the end. Both go on `main`.

### Project Structure Notes

- New: `tools/perf/frame_probe.js`, `tools/perf/README.md`, `_bmad-output/implementation-artifacts/screenshots/5-3/`.
- Modified: this story file, `sprint-status.yaml`, `deferred-work.md`.
- No `.uid` files for `.js`/`.md` (Godot only makes them for scripts/resources); if Godot creates a `.import` for anything under `tools/`, don't commit stray imports.

### Project Context Rules

- No `project-context.md`. Binding rules from `_bmad-output/game-architecture.md` and the spines:
  - Boundary 3: only `WebPlatform` touches browser APIs from GDScript — the probe is outside the game, so it's fine; don't add a GDScript `JavaScriptBridge` call for metrics.
  - Boundary 7: debug code only in `scenes/debug/`/`scripts/debug/`, instanced only in debug builds; release has no overlay and no cheats.
  - NFR12: no network, analytics or personal data — the probe sends nothing and the results contain no personal data (record computer models, not people's names; "family computer #2", not whose it is).
  - ADR-4: Pages deploys only from `v*` tags; publishing is deliberate (Smuck's yes).
  - NFR9/NFR16: unchanged by this story; any player-visible text problem seen on the laptop is a fix item.
- Tools: Godot `/c/Program Files/Godot/Godot.exe` (4.7.2), GUT 9.7.1, the Godot MCP server, the built-in browser pane, `gh`, Python (for gzip sizes and the local server). Chrome 154 and Edge 154 are on the dev PC; Firefox is not.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.3: Technical Metrics on Family Computers] (ACs); Epic 5 goal; NFR1–NFR5, NFR12, NFR17; FR6, FR11, FR35
- [Source: _bmad-output/game-architecture.md] Technical Requirements (frame rate, latency, load ≈ 30 MB), Technical Risks (low-end iGPU latency), Web Platform (key swallowing, `capture_keys` lifecycle), Hosting, Build & CI (tag deploys, gzip), Debug Tools ("Browser developer tools (Performance tab) for the web frame-time check in Epic 5"), Architectural Boundaries 3 and 7
- [Source: _bmad-output/implementation-artifacts/1-2-web-export-ci-and-github-pages-deploy.md] Pages URL, sizes, cache headers, skipped Firefox/throttled checks; `1-5-…` key capture; `1-7-…` NFR4 procedure; `3-4-conga-line.md` NFR1 reference; `5-1-…` OGG hitch; `5-2-…` gate pattern
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] items under 1.2, 1.5, 1.6, 1.7, 1.8, 2.7, 3.4, 5.1 named in Task 8.1
- [Source: scripts/autoloads/web_platform.gd, scripts/run/run_frame.gd, scripts/debug/frame_tracker.gd, scripts/debug/debug_overlay.gd, scripts/autoloads/save_service.gd, scripts/autoloads/player_data.gd, scripts/autoloads/audio_manager.gd, .github/workflows/build.yml, export_presets.cfg, project.godot]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline 2026-10-06 at `a173428`: GUT 1319/1319, 41,676 asserts. Real `save.json` sha256 `c34c7559…1761d` before/after every suite and export run.
- Probe selftest: PASS in Node (`node -e`, no package installed) and in the pane (Chromium 152): all 13 checks.
- Pane reference run 1 (full 2:00, local release export): frames 7236, mean 16.65, p50 16.7, p95 16.7, p99 16.8, max 18.4 ms, >33 ms 0, >17.5 ms 2, FPS 60.05, refresh 16.6 ms, unfocused 0. 90 keys typed, 7 errors, 32 brains, conga ×62.
- Run 1's latency (max 20.7 ms) exposed a probe bug: it measured to `performance.now()` inside the probe's rAF callback, which can run after Godot's frame work. Fixed to the story's definition (keydown `timeStamp` → next rAF frame timestamp, clamped at 0). Pane run 2 (41 s, latency check incl. pause/resume): 32 keys, p50 5.5, p95 14.4, max 14.5 ms (≤ 16.7, pass); frames 2472, max 17.2 ms.
- Pane key check (run 2): Space, Backspace, Tab during the run and while paused: `defaultPrevented` true, `__zts.capture` true, no scroll, focus stayed on `canvas#canvas`; Escape also `defaultPrevented` (by the engine). `/` and `'` produced no keydown in the pane (known 2.4 limitation: the pane sends an empty `key`), so they're unproven here.
- CI on `main` red since Story 3.3 (run 37323763735 onward): all 1319 tests pass in CI, but the "Run GUT" step's grep matched `SCRIPT ERROR: Assertion failed: Villager state can only move forward`, which is printed by `test_villager.gd`'s deliberate `assert_engine_error` checks. The old pattern matched 3 lines locally; the new `Parse Error|Compile Error|Failed to load script` matches 0, and still matches a temporary broken test (GUT exited 0 with it, which is why the check exists).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Measurement story; no game code changed (`scripts/`, `scenes/`, `data/`, `assets/`, `project.godot`, `export_presets.cfg` untouched). New dev tools: `tools/perf/frame_probe.js` (console probe: rAF frame stats, keydown → next-frame latency, watched-key table, focus exclusion, load-window mode, `selftest()`) and `tools/perf/README.md`.
- Out-of-plan change on Smuck's call: `.github/workflows/build.yml` GUT log grep narrowed. CI had been red on every `main` push since Story 3.3 because of deliberate engine asserts. Green again (runs 37555952386, 37556023613).
- v0.9.0 tagged and deployed to Pages (Smuck's yes at Gate A); wire size ≈ 12.55 MB, all gzip, `max-age=600`.
- Results: M1/M2 Edge (dev PC, Pages build) pass: worst frame 17.0 ms, 0 > 33 ms, 60.05 FPS, latency max 16.9 ms, conga over 100. M4 Edge pass (20/20, as reported). M7 pass with a gap. M3, M5, M6, M8 marked pass by Smuck **without measurement**, recorded as such. Chrome and Firefox Skipped (Smuck's words). Target laptop: the dev PC stood in, a large hardware deviation.
- Fix items for 5.5: F1 Fullscreen toggle icon state (must-fix before publish).
- `deferred-work.md`: 5.3 outcomes appended to the 1.2/1.5/1.7/1.8/2.7/3.4/5.1 items; Pages release gating and `run_history` bounds struck; new "dev of story 5-3" section.
- Final: GUT 1319/1319 twice after `--import`, no load errors under the new grep. Real save restored to and verified at its pre-story hash.

### File List

- `tools/perf/frame_probe.js` (new)
- `tools/perf/README.md` (new)
- `.github/workflows/build.yml` (modified: GUT log grep narrowed; Smuck's Gate A call)
- `_bmad-output/implementation-artifacts/5-3-technical-metrics-on-family-computers.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`

## Change Log

- 2026-10-06: Tools commit before the v0.9.0 tag. Added the console frame/latency/key probe and its README under `tools/perf/` (export-excluded). Baseline sizes and debug-content share recorded. Gate A recorded. `.github/workflows/build.yml`: the "Run GUT" grep changed from `Parse Error|Failed to load script|SCRIPT ERROR` to `Parse Error|Compile Error|Failed to load script`. The old pattern failed every `main` build since Story 3.3 on deliberate engine asserts (`test_villager.gd`), which blocked the tag deploy. Out of the story's planned scope, so done on Smuck's explicit call.
- 2026-10-06: Sessions recorded (M1–M8), Gate B (F1 must-fix), deferred-work updated, Status → review. Epic AC 7's "NFR8" is NFR5 (noted in deferred-work for the PM; `epics.md` not edited).
