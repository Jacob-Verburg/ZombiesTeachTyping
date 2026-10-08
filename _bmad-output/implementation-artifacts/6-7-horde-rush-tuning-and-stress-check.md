---
baseline_commit: bccbf753f4eb56897a522042429cce6bba9fe3a4
---

# Story 6.7: Horde Rush Tuning and Stress Check

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Smuck,
I want Horde Rush tuned so kids at different speeds get a fair share of brains,
so that no level becomes the one kids grind.

## Acceptance Criteria

1. **A headless Horde Rush simulation exists and is the tuning instrument.** A pure sim (`tools/horde_rush_sim.gd`, no nodes, no global RNG) runs a full 5:00 run on a given `HordeRushConfig` through the real `WordSource`, `HordeField` and `HordeDefender` in the level's step order, feeding words at a fixed WPM (WPM counted the Horde Rush way, implied space included, FR7) with a fixed seed, and reports spawned / arrived / stopped / still marching / arrival brains / brains per minute. Same config + WPM + seed → identical numbers. A headless runner (`godot --headless -s tools/horde_rush_sim.gd -- …`) prints a sweep table used for tuning.
2. **Arrival targets (GDD Level 2 tuning target).** On the shipped `horde_rush.tres`, averaged over the fixed seed set, the arrival rate (arrived ÷ (arrived + stopped)) is **35–45 % at 10 WPM** and **65–75 % at 30 WPM**. Only numbers in `horde_rush.tres` change to get there, starting with Smuck's recorded request: the Farmer paces at **half speed or slower** (`defender_lane_time_s` ≥ 1.2). Crossing times and hits to stop (FR55) change only with Smuck's explicit OK.
3. **Economy parity (NFR15).** Horde Rush brains per minute at **5, 10 and 20 WPM** are each within **±20 %** of Zombie Run's at the same WPM, Zombie Run's rate computed from `zombie_run.tres` (not a literal). Gaps are closed by adjusting the completion bonus and/or arrival brains in `horde_rush.tres` (GDD note: Horde Rush ran ~30 % under at 5–10 WPM). The final numbers and the before/after tables are recorded in `## Tuning Results`.
4. **The tuning is guarded by tests.** A GUT test runs the sim on the shipped config and fails if AC 2 or AC 3 stops holding; the sim's determinism and its WPM pacing are unit-tested; tests that exercise defender *mechanics* keep pinning their own numbers, so the shipped retune does not silently change what they test.
5. **30-zombie stress check (NFR1).** In a debug build, with a Horde Rush run RUNNING, the debug overlay's new **F4 stress hold** keeps at least 30 copies marching (the defender, tomatoes, splats, melts and arrivals all live). On the **web** build (debug export, desktop Chrome on the dev PC) held for at least 60 s, the overlay's run-worst frame is **≤ 33 ms**. If it is not, pooling is added for zombie copies (architecture: no pooling unless profiling demands it) and the check is re-run. Results go in `## Stress Results`.
6. **Full-run frame check (NFR1 post-MVP).** One full 5:00 Horde Rush on a local **release** web export, measured with the frame probe (`zts_probe.arm({seconds: 300})`, new option), has no frame over 33 ms in the RUNNING window — or the row is recorded as Skipped with Smuck's reason.
7. **Kid playtest.** A kid (or, if none is available, the stand-in Smuck chooses) plays at least one full Horde Rush on the tuned build, and the **Horde Rush playtest checklist** (Dev Notes) is filled pass/fail per item with notes. Smuck's verdict that the defender feels goofy, not frustrating, is recorded verbatim with the date. Any fail is fixed (numbers only) and re-checked, or explicitly accepted by Smuck.
8. **Horde Rush is switched on.** After AC 2–7 pass, `horde_rush.available = true` in `level_registry.tres`: the menu card is selectable (Story 6.8 then adds the lock). Pitchfork Panic stays `available = false`. No version tag is pushed (the next tag comes after 6.8).
9. **No regressions.** Word dealing, seeds/lanes replay, the march, the defender rules (pacing, rounded lane, front-most aim, contact hits, no overkill avoidance, step order), arrivals, the hitch cap, the outro, art, sounds and Zombie Run are unchanged except for the tuned numbers. Full GUT suite green.

## Tasks / Subtasks

- [x] **Task 1: The sim (AC: 1)** — new `tools/horde_rush_sim.gd`
  - [x] 1.1 A pure, preloadable script (no `class_name`: tools are export-excluded; tests `preload("res://tools/horde_rush_sim.gd")` like `gen_art_prototypes.gd` is preloaded). Static `run(config: HordeRushConfig, wpm: float, seed: int, step_s: float = 1.0 / 60.0) -> Dictionary` returning `{spawned, arrived, stopped, marching, arrival_brains, arrival_rate, brains_per_min, words, keys, measured_wpm}`.
  - [x] 1.2 Mirror the level exactly (Dev Notes "Sim rules"): one run RNG seeded with `seed`; word RNG = `rng.randi()` first, lane RNG = `rng.randi()` second (`horde_rush_level.gd:create_target_source`); `WordSource.new(word_rng, WordSource.pool_from_json(config.word_list, config.word_min_length, config.word_max_length))`; `HordeField.new(config, lane_rng)`; `HordeDefender.new(config)`. Defender runs from t = 0 (the first key). Each logic step: `field.advance(dt)` (count arrivals and their `size_class.arrival_brains`), then `defender.advance(dt, field)`.
  - [x] 1.3 Typing model: one character every `12.0 / wpm` s (= 60 / (5·wpm)); a word of length L completes `L` characters after the previous word's implied space, and the implied space takes one character slot, so the word cycle is `(L + 1) * 12 / wpm` s and the measured Horde Rush WPM ((keys + words) / 5 / minutes, FR7) equals `wpm`. Spawn (`field.spawn(word)`) in the step whose time window contains the completion (before that step's `advance`, like a key arriving before `_process`). Stop at `config.duration_s`: copies still marching never pay (the level freezes them, FR57).
  - [x] 1.4 `brains_per_min = (arrival_brains + config.completion_bonus) / (duration_s / 60)`. Also a static `zombie_run_brains_per_min(zr: ZombieRunConfig, wpm: float) -> float` = `(keys / brain_block_every * brains_per_block + completion_bonus) / minutes` with `keys = 5 * wpm * minutes`, `minutes = zr.duration_s / 60` (perfect accuracy on both sides; errors only lower WPM).
  - [x] 1.5 `_init` path for `godot --headless --path . -s tools/horde_rush_sim.gd -- [--wpm=5,10,20,30] [--seeds=N] [--lane-time=…] [--cooldown=…] [--projectile=…] [--bonus=…]`: loads the shipped `horde_rush.tres` (deep duplicate; overrides applied to the copy, never saved), prints one row per WPM (mean over seeds 1..N of arrival rate, arrivals, brains/min, Zombie Run brains/min, parity %) and quits with 0. Header doc in the 3.6/6.6 tool style (what it does, the run line, the rules). Never writes any file.
- [x] **Task 2: Baseline and sweep (AC: 2, 3)**
  - [x] 2.1 Run the sim on the shipped (6.6) numbers at 5/10/20/30 WPM, 10 seeds; record it as the **Before** table in `## Tuning Results` (expect roughly the 6.4 feel note: ~1 % at 10 WPM).
  - [x] 2.2 Set `defender_lane_time_s = 1.2` (Smuck's "half speed") and re-run. Then sweep `defender_throw_cooldown_s` and `projectile_cross_time_s` (and lane time only upward, ≥ 1.2) until 10 WPM lands in 35–45 % and 30 WPM in 65–75 %. Keep the sweep rows you used (a compact table) in `## Tuning Results`.
  - [x] 2.3 Prefer the combination that keeps the Farmer looking busy and goofy: a cooldown he visibly uses (not a Farmer standing idle for seconds), a tomato you can follow with the eye (`projectile_cross_time_s` ≥ 1.0). If the targets cannot be met without touching FR55 numbers (crossing time / hits), stop and ask Smuck with the options and their sim rows.
  - [x] 2.4 Parity: with the defender settled, compute Horde Rush vs Zombie Run at 5/10/20 WPM. Close gaps with `completion_bonus` first (it lifts slow typists most, which is where the gap is) and `arrival_brains` second; keep `arrival_brains` ordered small < medium < brute. Record the final parity table (HR, ZR, % difference per WPM).
  - [x] 2.5 **Tuning gate:** show Smuck the Before/After tables and the chosen numbers; record the verbatim answer with the date in `## Tuning Results`. Only then edit `data/levels/horde_rush.tres` (the numbers only; leave `music_id`, word band, lane count, scales, flash/melt/outro as they are unless the gate says otherwise).
- [x] **Task 3: Tests (AC: 1, 4, 9)**
  - [x] 3.1 New `tests/unit/test_horde_rush_sim.gd`: same config/WPM/seed → identical Dictionary; another seed → different lanes/counts; `measured_wpm` within 0.5 of the requested WPM at 5/10/30 on a 300 s run; `spawned == arrived + stopped + marching`; a config with an impossible defender (e.g. `defender_throw_cooldown_s = 1e6`) arrives 100 % of decided copies; never touches the global RNG (`seed(1)` vs `seed(999)`, then `randomize()`, the `test_horde_defender.gd` pattern); `zombie_run_brains_per_min` on the shipped `zombie_run.tres` gives 11.25 / 17.5 / 30.0 at 5 / 10 / 20 WPM (the GDD economy table).
  - [x] 3.2 New `tests/unit/test_horde_rush_tuning.gd`: on the **shipped** `horde_rush.tres` and `zombie_run.tres`, mean over the fixed seed list (a const, e.g. 1..5): arrival rate at 10 WPM in [0.35, 0.45], at 30 WPM in [0.65, 0.75]; parity ratio at 5, 10, 20 WPM in [0.8, 1.2]; the defender lane time ≥ 1.2 (Smuck's floor). Messages print the measured numbers. Keep the whole file under ~5 s: measure it; if slower, drop to fewer seeds or `step_s = 1.0 / 30.0` (the level's own `MAX_STEP_S`) and say so in the file doc.
  - [x] 3.3 `tests/unit/test_horde_rush_config.gd`: `test_shipped_defender_numbers` and the `completion_bonus` assert follow the new shipped numbers (comment: tuned in 6.7, see the story's Tuning Results); `test_size_class_for_band_edges` follows any arrival-brains change. `_valid()` keeps its own 6.4 numbers (it is an in-test config).
  - [x] 3.4 `tests/unit/test_horde_rush_level.gd`: run it after the retune. Any test that checks a defender *mechanic* with timing that assumed 0.6 / 0.8 / 1.0 must pin those numbers through `_make(seed, tweak)` instead of being re-fitted to the new shipped values (the mechanic is what it tests). `test_the_shipped_config_ends_with_a_bonus_and_an_outro` follows the new bonus. Do not weaken an assertion to make it pass.
  - [x] 3.5 `tests/integration/test_run_frame.gd` Horde Rush tests (`HORDE_ARRIVAL_SEED = 7`, the bonus line, quit keeps arrival brains): re-run; update the expected bonus to the shipped value (read it from the config, not a new literal, where the test allows). If "some copies got past" changes, keep the assertion's intent (> 0 arrivals) and note it.
  - [x] 3.6 `tests/unit/test_horde_defender.gd` uses its own 0.6/0.8 config and the pinned seed-7 counts: it must pass untouched (it proves the rules didn't change).
  - [x] 3.7 `tests/unit/test_level_registry.gd` (`test_shipped_registry_menu_levels`) and `tests/unit/test_main_menu.gd` (`test_shipped_registry_gives_three_cards_in_order`): Horde Rush is available / `LevelCard.State.AVAILABLE`, Pitchfork Panic still Coming soon (done in Task 7).
- [x] **Task 4: F4 stress hold (AC: 5)**
  - [x] 4.1 `horde_rush_level.gd`: extract the body of `on_target_completed` after the `_field == null or _frozen` guard into `_spawn_copy(word: String)` (same order: logic marcher, `SFX_SPAWN`, view) so the key path is unchanged. Add `debug_set_stress_floor(count: int)` / `get_stress_floor()`: while `count > 0` and the run is running (`_defender_running` and not `_frozen`), each `_process` (after the logic steps, before `_update_views`) spawns **at most one** extra copy when `_field.get_marching().size() < count`, using a fixed cycle of words (`STRESS_WORDS`, a const mixing 3-, 4- and 6-letter words so all three classes appear) — **never** the run's `WordSource` (it is the TypingSession's source; drawing from it would desync the HUD word). Stress copies go through the normal field (lane RNG draws: a stressed run's lanes no longer replay a seed — fine for a debug tool, say so in the doc), pay on arrival like any copy, and stop at `on_run_ending` and `_reset` (which also zeroes the floor). Doc it as debug-only: only the debug overlay calls it.
  - [x] 4.2 `debug_overlay.gd`: **F4** (overlay open, a RUNNING Horde Rush run frame found through the existing `find_run_frame` / `_run_frame()` path, level `has_method("debug_set_stress_floor")`) toggles the floor between 0 and `STRESS_COPIES` (30, a debug const, not a balance number). Show "stress: 30" / "stress: off" in the run section; add `F4 stress` to `HELP_TEXT`. Refused (logged at debug) on any other level or state. The overlay already exists only in debug builds (Boundary 7), so release can never reach it. Update the class doc's key list.
  - [x] 4.3 Tests: `test_horde_rush_level.gd` — with a floor of 30 and the defender running, after enough `_process` steps the marching count reaches 30 and stays ≥ 30 within one copy per frame; at most one stress spawn per `_process`; `on_run_ending` and `_reset` stop it; the HUD word (`_session.get_current_target()`) is unchanged by stress spawns; with floor 0 nothing extra spawns. `test_debug_overlay.gd` — F4 toggles the floor on a fake run frame whose level records the calls; refused when not RUNNING or not Horde Rush; help text lists F4.
- [x] **Task 5: Stress and full-run measurement (AC: 5, 6)**
  - [x] 5.1 Debug web export: `"/c/Program Files/Godot/Godot.exe" --headless --path . --export-debug "Web" build/web/index.html`, serve with `preview_start {name: "web-debug"}` (port 8060), and **keep the browser pane visible** (a hidden pane throttles rAF to 1–2 fps and gives nonsense; 1.8/4.5/5.3 deferrals). F3 → "Horde Rush" jump → type a key → F4 → hold ≥ 60 s (keep typing a word now and then is fine) → read "run worst" from the overlay (it counts RUNNING frames only). Screenshot the overlay to `screenshots/6-7/stress-overlay.png`. The F3 overlay jump starts a real run that writes the real save if it ends: quit to menu instead of letting it reach 5:00, or use F6 knowingly (6.3 known defer). Record machine (dev PC: Ryzen 7 5700G / RTX 3070 — far stronger than the NFR1 2018 laptop; note the deviation like 5.3), browser version, run worst, copies on screen.
  - [x] 5.2 If run worst > 33 ms: profile (Chrome Performance tab) to confirm spawn/free cost is the cause, then add pooling for copies only (a small free list of `PlayerZombie` views in the level, reset on reuse: scale, flashing, melting, modulate, hat follows by itself; freed views returned instead of `queue_free`), test it (`get_view_count`, reuse resets state, `_reset` drains), and re-measure. If it is under 33 ms, **no pooling** (architecture Entity Patterns) and say so.
  - [x] 5.3 `tools/perf/frame_probe.js`: `arm({seconds: N})` overrides `ZTS_PROBE_SECONDS` (default stays 120; `startNow` still works with it). The frame buffer is sized from it (`MAX_FRAMES = ceil((ZTS_PROBE_SECONDS + 1) * 240)`, line 17), so size it per arm from the chosen seconds, or a 300 s run at 144 Hz truncates; the summary label says the seconds; `selftest()` still passes; README gains one line for Horde Rush (`zts_probe.arm({seconds: 300})`).
  - [x] 5.4 Full-run check (AC 6): release web export (`--export-release "Web" build/web/index.html`), same server, probe armed with `{seconds: 300}`, one full 5:00 Horde Rush with real typing (Smuck, or the pane if it can type steadily; a pane run must stay visible). Record the probe summary in `## Stress Results`. If nobody can do it this story, record **Skipped** with Smuck's reason and leave a deferred-work line.
- [x] **Task 6: Kid playtest (AC: 7)**
  - [x] 6.1 Ask Smuck who plays (a kid, or which stand-in if none: 5.4 precedent), on which build (local release export, or the editor run), and when. Record the answer verbatim with the date.
  - [x] 6.2 Fill the **Horde Rush playtest checklist** (Dev Notes) from Smuck's report: pass / fail / not seen per item, with the report card numbers (WPM, brains) and the player's age only (NFR12: no names or personal data).
  - [x] 6.3 A fail → adjust numbers only (back through the sim, Task 2.2–2.4, and keep AC 2/3 true) and re-check, or Smuck accepts it (verbatim). Record Smuck's final verdict on "goofy, not frustrating" verbatim with the date.
- [x] **Task 7: Switch Horde Rush on (AC: 8)**
  - [x] 7.1 Only after Tasks 2, 5 and 6 pass: `data/levels/level_registry.tres` `Resource_horde_rush` `available = true`. Nothing else in the registry (6.8 adds `unlocked_by`).
  - [x] 7.2 Update the tests in Task 3.7. Check that choosing the Horde Rush card from the menu starts a real run (the existing card → RUN path; an integration check in `test_screen_flow.gd` only if one doesn't already cover "an available card runs its level").
  - [x] 7.3 Docs: `debug_overlay.gd` class doc ("starts the hidden level (still Coming soon on the menu)" → the jump is now a shortcut), `horde_rush_level.gd` class doc "Still to come" (drop 6.7; keep 6.8 unlocks and the Epic 10 pairs; add one line on the stress hold).
  - [x] 7.4 **Do not push a tag.** Until 6.8 lands, main has Horde Rush selectable with no lock; that is expected and never deployed (Pages deploys only from `v*` tags).
- [x] **Task 8: Docs, defers and wrap-up (AC: 3, 9)**
  - [x] 8.1 GDD (`gdds/.../gdd.md`): in Level 2 the defender "starting values" line and the Economy table's Horde Rush row get the tuned numbers with "(tuned in Story 6.7, 2026-10-xx)"; mark the two NOTE FOR DESIGNER items for Horde Rush (Level 2 tuning, the 5–10 WPM parity note) resolved in place. Do not rewrite anything else. Mirror only number changes into `epics.md` FR55/FR56/FR57 if those numbers changed (a short "(tuned 6.7)" mark).
  - [x] 8.2 `audio_library.tres`: give `sfx_tomato_throw` a `min_interval_s` (e.g. 0.1) so throws from a hitch frame's substeps never stack (6.6 review defer), and add it to `test_audio_library.gd`'s `test_burst_cues_are_throttled`.
  - [x] 8.3 `deferred-work.md` (append, never delete history): resolve "Feel input for 6.7" (6.4), "Smuck's tuning request for 6.7" (6.6), "Several throws in one frame … stack `sfx_tomato_throw`" (6.6 review), and "Frame cap (`MAX_FRAME_S`) drops hitch time … revisit in 6.7 economy parity" (6.5 review: decision — kept; the sim models no hitches, a hitch only ever costs the kid brains, never pays extra; note it). Re-check "`HORDE_ARRIVAL_SEED = 7` brittleness" after the retune and note the result. Add "Deferred from: dev of story-6.7" for anything left (e.g. NFR1 on a real 2018 laptop still unmeasured for Horde Rush; a Skipped AC 6 row).
  - [x] 8.4 Verification: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Re-count the baseline first (1556 after 6.6 + review patches; re-count with `git grep '^func test_'`) and record before/after. Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0). `grep` for global `randi(`/`randf(` in `scripts/levels/horde_rush/` and `tools/horde_rush_sim.gd`: clean.
  - [x] 8.5 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`. Commit `.uid` files for new scripts. No tag push.

### Review Findings

- [x] [Review][Patch] Sim places every copy one character slot late — the first correct key is t = 0 and is word 1's first letter, so word 1 finishes at `(L-1)·char_s`, not `L·char_s` (the spec's Task 1.3 / Sim rules say `L × 12 / wpm`). Decided by Smuck (2026-10-08, "1"): fix the sim to `(slots_before + L - 1)·char_s`, keep `keys`/`partial` consistent, then re-check the 35–45 % / 65–75 % / ±20 % bands and the sim/tuning tests (a numbers touch-up in `horde_rush.tres` may follow, only with the sim rows shown) [tools/horde_rush_sim.gd:121,135]
- [x] [Review][Patch] Sim has no input validation: `--wpm=-5` loops forever in the spawn `while`, `--wpm=abc`/empty parses to 0 (all zeros, `parity` nan/inf), `--seeds=0|ten` silently becomes 1, `run()` with `wpm <= 0` or `step_s <= 0` misbehaves. Reject with an error and `quit(1)`; guard `run()` with an assert/early return [tools/horde_rush_sim.gd:~20-90,117,125]
- [x] [Review][Patch] `frame_probe.arm({seconds})` is not exception-safe: `probeSeconds`/`MAX_FRAMES` are committed before `new Float64Array(...)`, and `Infinity`/huge values pass the `> 0` check and throw RangeError, leaving the buffers undersized and frames silently dropped. Require `Number.isFinite`, allocate the new arrays first, then commit [tools/perf/frame_probe.js:~290-300]
- [x] [Review][Patch] F4 refusal tests prove nothing: `test_f4_is_refused_before_the_first_key`, `test_f4_is_refused_after_the_run_ends` and `test_f4_does_nothing_while_closed` assert `get_stress_floor() == 0` when it was already 0. Turn the floor on via `debug_set_stress_floor(…)` first (or assert the call was never made) so deleting the guard fails the test [tests/unit/test_debug_overlay.gd:615,623,645]
- [x] [Review][Patch] Weak sim tests: `test_a_defender_that_never_throws_…` promises "every decided copy arrives" but only asserts `stopped <= 1` and its second (`parked`) half repeats the first; make the assertion say what is guaranteed (exactly the first-throw case) or drop the duplicate. `test_never_touches_the_global_rng` ends with `randomize()` only if no earlier step aborts — restore in `after_each` [tests/unit/test_horde_rush_sim.gd:50,81]
- [x] [Review][Patch] Stale number in deferred-work: the 6.7 "Resolved" line says "(39 % / 68 %)" — the pre-3:00 result; shipped is 37.4 % / 68.4 % [deferred-work.md:538]
- [x] [Review][Defer] Nothing cross-checks the sim against the real level: the tuning bands validate a re-implementation (spawn → field → defender order). The shipped 1.5 / 2.4 / 1.2 numbers only run through the real level in the seed-7 integration tests — deferred, accepted design (spec: pure sim)
- [x] [Review][Defer] Stress copies pay brains into the run result/save and replay-break the seed; `_top_up_stress` reads `get_marching()` (array copy) every frame — deferred, debug-only and spec-documented (6.7 deferred-work already notes the lane RNG)

Triage: 1 decision_needed, 5 patch, 2 defer, 14 dismissed as noise or spec-intended (e.g. 5:00 → 3:00 wording, stress copies paying per spec, test brittleness nits, `0.08` vs `0.1` throttle). Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor all completed; the Auditor found no AC violation. GUT was not re-run by the reviewers.

## Dev Notes

### What this story is (and isn't)

- **Is:** a headless sim, the numbers in `horde_rush.tres` (defender, then bonus/arrival brains), tests that guard them, a debug stress hold and the NFR1 measurements, the kid playtest, flipping `available`.
- **Isn't:** new defender rules (no overkill avoidance, no smarter aim, no new config fields for behaviour), unlocks/locks/"New!" (6.8), tiers or new word bands (Epic 7: the band stays 3–5), art or audio changes (except one `min_interval_s`), a release.
- **No logic-class changes:** `HordeField`, `HordeDefender`, `HordeMarcher`, `HordeProjectile`, `HordeRushConfig`, `HordeSizeClass`, `WordSource`, `RunFrame` stay as they are. The level changes only by the `_spawn_copy` extraction, the stress floor and (only if 5.2 fails) pooling.

### The numbers today and what they do

- Shipped (`data/levels/horde_rush.tres`): lane time 0.6 s, cooldown 0.8 s, projectile 1.0 s, flash 0.15, melt 0.6, outro 2.0, bonus 25; small ≤3: 8 s / 1 hit / 1 brain; medium 4–5: 10 s / 2 / 2; brute ≥6: 13 s / 3 / 3 (none spawn in the 3–5 band).
- 6.4 feel note (deferred-work): on these numbers ~1 % of copies arrive at 10 WPM, 6 % at 20, 11 % at 25–30, 20 % at 40. Far below 40 % / 70 %.
- Smuck (Audio gate 2026-10-08, verbatim): "I do want to slow down the defending person move speed by half, a child will not type fast enough to get any points at this speed." → `defender_lane_time_s` 0.6 → 1.2 is the starting point and the floor (slower is allowed, faster is not).
- Word band mix (`data/content/words.json`, band 3–5): 81 three-letter (small), 62 four-letter, 48 five-letter (medium) = 191 words; the word bag deals each once per bag, so ~42 % small / 58 % medium, mean length ≈ 3.83, mean arrival brains ≈ 1.58 per copy (before the defender picks favourites: smalls die in 1 hit, so arrivals skew medium).
- Words per minute at Horde Rush WPM W: 5W / (L + 1) ≈ 1.035 W.

### Economy reference (GDD Economy and Resources)

- Zombie Run (from `zombie_run.tres`: 120 s, `brain_block_every = 4`, `brains_per_block = 1`, `completion_bonus = 10`): brains/min = 1.25 W + 5 → **11.25 at 5, 17.5 at 10, 30 at 20 WPM**. The sim computes this from the resource; the test checks these three values.
- Horde Rush brains/min = (arrival brains in the 5:00 run + completion_bonus) / 5.
- Rough feasibility (for orientation, not a target): at 40 % arriving and ~1.5 brains per arrival, 10 WPM pays ≈ 10.35 × 0.4 × 1.5 + bonus/5 ≈ 6.2 + bonus/5. With bonus 25 that is ≈ 11/min vs 17.5 (−37 %). Because the gap is largest for slow typists and Zombie Run's own +5/min is flat, the completion bonus is the natural lever (a bonus around 40–55 likely lands all three WPMs inside ±20 %, but the sim decides). Raising arrival brains instead scales with WPM and tends to overshoot at 20 WPM.
- Assumptions to state in the results: 100 % accuracy on both sides (errors only lower WPM; neither level pays for accuracy), no pauses, no hitches.

### Sim rules (must match the level, or the tuning is fiction)

- RNG order: `rng.seed = seed`; `word_rng.seed = rng.randi()`; `lane_rng.seed = rng.randi()` (exactly `horde_rush_level.gd:create_target_source`). The defender has no RNG.
- Step order per logic step: `field.advance(dt)` → arrivals pay; then `defender.advance(dt, field)`. The level runs 60 Hz frames as single steps (≤ `MAX_STEP_S` 1/30), so `step_s = 1/60` is the reference.
- Spawn timing: a word's copy spawns in the key's call, i.e. before the next `_process`. In the sim: spawn every word whose completion time ≤ the step's start time, then advance.
- The defender starts on the first correct key (`on_run_started`); the clock runs `duration_s` from that key (RunFrame). The sim's t = 0 is that key; the first word completes at `L × 12 / wpm`.
- End: at `duration_s` the level freezes (`on_run_ending`); marching copies never arrive or pay. Report them as `marching`, excluded from the arrival rate's denominator.
- Arrival rate = arrived / (arrived + stopped). Report it per seed and the mean.
- Do not reach into the level node: the sim is pure so the test is fast and deterministic (the 6.3/6.4 docs promised "Story 6.7's headless simulation runs on it unchanged").

### Defender behaviour to keep in mind while tuning

- Pacing: `position() = pingpong(travel, lane_count − 1)`, throws only down `roundi(position())`, so the Farmer is "level with" a middle lane for one lane-time per pass and with an end lane for one lane-time per bounce (two half-windows back to back). At 1.2 s/lane a full sweep (top → bottom → top) is 9.6 s, about one small copy's crossing.
- A throw needs a marching copy in that lane and the cooldown ready; projectiles fly at 1 field per `projectile_cross_time_s` from the house line and hit by contact (no overkill avoidance, a spare tomato hits the next copy behind or misses).
- Throw animation is 0.25 s (3 frames at 12 fps): any cooldown above that animates cleanly.
- Arrival rate rises with WPM because the defender's throw rate is capped: more copies per minute saturate it. That's the design ("tension from the kid's own speed against a fixed defender"); never scale the defender with WPM (GDD: the defender never scales).

### Horde Rush playtest checklist (Task 6; pass / fail / not seen, with a note)

| # | Look for | Pass when |
|---|---|---|
| P1 | First minute | Some copies reach the house and the brain counter goes up in the first minute without help. |
| P2 | Gets it | The player connects "finish a word → a zombie runs" within the first few words (from what they say or do), at most one hint. |
| P3 | Farmer is funny | Smiles, laughs or comments at throws, splats or melts; no upset at a melt. |
| P4 | Not frustrating | No "unfair" / "too hard" / giving up; the player keeps typing to the end of 5:00 (no quit). |
| P5 | Watches, still types | Glancing at the field doesn't stall typing for long stretches. |
| P6 | Pays fairly | Report card brains feel worth it next to their last Zombie Run (player or Smuck's read; compare the numbers). |
| P7 | Wants more | Asks to play again or picks Horde Rush again. |
| P8 | Nothing scary | No fear at the march music, the Farmer or the melt (NFR10). |

Record per session: age, level(s) played, report card WPM / brains / errors, and Smuck's notes. No names (NFR12).

### Existing code to read first (current state → change → preserve)

- **`data/levels/horde_rush.tres`** (UPDATE, numbers only after the Tuning gate).
- **`data/levels/level_registry.tres`** (UPDATE, `available = true` for Horde Rush, last).
- **`scripts/levels/horde_rush/horde_rush_level.gd`** (UPDATE). Today: `on_target_completed` spawns logic then view in the key's call; `_process` caps the frame at `MAX_FRAME_S` 0.5 s and substeps at ≤ `MAX_STEP_S` 1/30 s; `_reset`, `on_run_ending`, every 6.4–6.6 bookkeeping rule (`_flash_tweens` erase/kill, untyped loops + `is_instance_valid` over dicts keyed by possibly-freed views). Change: `_spawn_copy` extraction, stress floor, docs. Preserve: everything else, especially RNG order (words, then lanes) for unstressed runs and logic-before-visual.
- **`scripts/debug/debug_overlay.gd`** (UPDATE): `_handle_key(keycode)` is where F-keys live (F2, F5–F9); `_run_frame()` finds the RunFrame; `_refresh_run()` writes the run section; `HELP_TEXT`. Keys only while the overlay is open.
- **`tools/perf/frame_probe.js`**, **`tools/perf/README.md`** (UPDATE: the `seconds` option).
- **`data/audio/audio_library.tres`** (UPDATE: one `min_interval_s`).
- Read only: `horde_field.gd`, `horde_defender.gd`, `horde_marcher.gd`, `horde_projectile.gd`, `horde_rush_config.gd`, `horde_size_class.gd`, `word_source.gd`, `zombie_run_config.gd`, `run_frame.gd` (seed, bonus, end), `tests/unit/test_horde_defender.gd` (`_headless` is a minimal sim to learn from).

### Architecture and rules to follow

- Godot **4.7.2**, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error), typed arrays/dicts/loop vars, tabs, short `##` docs that say why, LF endings.
- Tuning numbers live in `LevelConfig` resources, never as literals in scripts (architecture ~282, ~461, ~992). The sim reads them; the tests read the shipped resources. Debug consts (`STRESS_COPIES`, `STRESS_WORDS`) are not balance numbers and say so.
- Logic leads, visuals chase; the level never reads input, the clock or `PlayerData`.
- Entities: no pooling unless profiling shows the need (architecture ~902: "the candidate is Horde Rush with 30 zombies on screen"). AC 5 decides.
- Debug code (Boundary 7): only the debug overlay (instanced in debug builds only) calls the stress hook.
- `tools/` is export-excluded: the sim never ships.

### Testing notes

- Run `--import` after adding scripts, before GUT.
- Level tests: the level is `PROCESS_MODE_DISABLED`; drive with `_level._process(STEP)`; set `request_voice` and `play_sfx` recorders before `add_child`; never assign to the shipped resource (use `_make(seed, tweak)`).
- The tuning test is the slowest file: time it and keep it reasonable (Task 3.2).
- `seed()`/`randomize()` pattern for the global-RNG test (from `test_horde_defender.gd:372`).

### Previous story intelligence (6.6)

- 6.6 shipped the art, the Farmer (`HordeFarmer`: idle/walk/throw), splats, flash/melt frames, the march and four SFX; Gate 1, Gate 2, Audio gate all "Approved". Test count after 6.6: 1556 (+ review patches; re-count).
- Smuck played Horde Rush through F3 → "Horde Rush" (the card says Coming soon) and asked for the half-speed Farmer: logged for this story.
- Review defers that land here: throw-sound stacking (Task 8.2). Others stay open (Farmer `_throwing` fallback, lane geometry duplication, doorway test fragility, `PlayerZombie._play` silent miss).
- Lessons kept: record Smuck's decisions verbatim with the date; never touch the real `user://save.json` in an automated capture (hash before/after); keep the browser pane visible for any frame measurement; scratch scripts deleted after use; edit story sections line-anchored.

### Git intelligence

- One commit per story on `main` ("Story 6.7: horde rush tuning and stress check"), then "Story 6.7: code review patches applied, done". 6.3–6.6 all touched `scripts/levels/horde_rush/`, `tests/unit/test_horde_rush_level.gd`, `tests/integration/test_run_frame.gd`.
- Expected changes: `tools/horde_rush_sim.gd` (+ `.uid`, new), `data/levels/horde_rush.tres`, `data/levels/level_registry.tres`, `data/audio/audio_library.tres`, `scripts/levels/horde_rush/horde_rush_level.gd`, `scripts/debug/debug_overlay.gd`, `tools/perf/frame_probe.js`, `tools/perf/README.md`, tests (`test_horde_rush_sim` and `test_horde_rush_tuning` new; `test_horde_rush_config`, `test_horde_rush_level`, `test_debug_overlay`, `test_level_registry`, `test_main_menu`, `test_audio_library`, `tests/integration/test_run_frame.gd`), GDD/epics number notes, `screenshots/6-7/`, `deferred-work.md`, this file, `sprint-status.yaml`. Not touched: the logic classes, `scripts/autoloads/`, `scripts/typing/`, `scripts/run/`, `scripts/screens/`, art, music, `project.godot`, `export_presets.cfg`, `.github/`.

### Project Structure Notes

- The sim goes in `tools/` (export-excluded, like `tag_words.gd`), preloaded by tests; no new folders except `screenshots/6-7/`.
- Variance carried forward: the field art bakes 5 lanes (6.6); the dev PC stands in for the 2018 laptop (5.3).

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md` (D5 static data ~164; tuning in `LevelConfig` ~280–282, ~461, ~992; Entity Patterns / pooling ~902; Boundary 7 debug code; Logic Leads Visuals Chase ~783–836; NFR1 targets ~74), the GDD (Economy and Resources ~261–279, Level 2: Horde Rush ~308–325, Performance ~388) and the epics (FR55–FR59, NFR1, NFR15).
- Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, the built-in browser pane with `.claude/launch.json` `web-debug` (serves `build/web/` on 8060), the Godot MCP for load checks (it cannot type).

### Latest tech information

- No new libraries or engine features; web research not needed. Godot 4.7.2: `RandomNumberGenerator.randi()` / `randi_range()` are seed-stable; `Resource.duplicate(true)` deep-copies the size-class sub-resources for sim overrides; `--export-debug "Web"` gives a build with `OS.is_debug_build()` true (the overlay exists), `--export-release` without it.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.7: Horde Rush Tuning and Stress Check] (ACs); Stories 6.3–6.6 (built on), 6.8 (lock, publish); FR55–FR59, FR7, NFR1, NFR10, NFR12, NFR15
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Economy and Resources (~261–279), Level 2: Horde Rush (~308–325), Difficulty Curve (~255–259), Performance (~388)
- [Source: _bmad-output/game-architecture.md] ~74, ~164, ~280–283, ~461, ~902, ~992
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] ~537 (6.4 feel note), ~548–549 (6.5 frame cap, seed-7 brittleness), ~554 (Smuck's half-speed request), ~562 (throw-sound stacking)
- [Source: _bmad-output/implementation-artifacts/6-6-farmhouse-farmer-and-march-music.md] Audio Approval; [5-3-technical-metrics-on-family-computers.md] probe, pane rules, dev-PC deviation; [5-4-first-kid-playtest.md] playtest process
- [Source: scripts/levels/horde_rush/horde_rush_level.gd:189-216 (create_target_source), :259-281 (on_target_completed), :377-418 (_process, _logic_step)], [horde_defender.gd], [horde_field.gd], [word_source.gd], [scripts/debug/debug_overlay.gd], [tools/perf/frame_probe.js:15], [tests/unit/test_horde_defender.gd:331-376], [tests/unit/test_horde_rush_config.gd], [tests/unit/test_level_registry.gd:105-125], [tests/unit/test_main_menu.gd:114-124], [tests/integration/test_run_frame.gd:1640-1780]

## Tuning Results

Instrument: `tools/horde_rush_sim.gd`, step 1/60 s, mean over seeds 1..10. Assumptions: 100 % accuracy on both sides, no pauses, no hitches (the hitch cap only drops time, so a hitch can only cost brains). Zombie Run brains/min computed from `zombie_run.tres` (1.25·W + 5).

**Before** (shipped 6.6 numbers: lane 0.6 s, cooldown 0.8 s, projectile 1.0 s, bonus 25, arrival brains 1/2/3):

| WPM | Arrival % | Arrived | Stopped | HR brains/min | ZR brains/min | Parity |
|---|---|---|---|---|---|---|
| 5 | 0.0 % | 0.0 | 25.6 | 5.00 | 11.25 | 44 % |
| 10 | 2.0 % | 1.0 | 50.0 | 5.34 | 17.50 | 31 % |
| 20 | 7.1 % | 7.2 | 94.9 | 7.44 | 30.00 | 25 % |
| 30 | 14.1 % | 21.5 | 130.8 | 12.60 | 42.50 | 30 % |

(Matches the 6.4 feel note: ~1 % / 6 % / 11 %.)

**Sweep** (arrival % at 10 / 30 WPM; bonus 25):

| Lane s | Cooldown s | Projectile s | 10 WPM | 30 WPM | Note |
|---|---|---|---|---|---|
| 1.2 | 0.8 | 1.0 | 2.7 % | 17.7 % | half speed alone barely helps: the cooldown is the cap |
| 1.2 | 0.8 | 1.5 | 3.3 % | 18.9 % | projectile time hardly matters |
| 1.2 | 1.2 | 1.0 | 25.6 % | 45.8 % | cooldown = lane time: one throw per lane window |
| 1.2 | 1.6 | 1.0 | 26.0 % | 53.1 % | |
| 1.2 | 2.0 | 1.0 | 28.6 % | 60.3 % | |
| 1.2 | 2.5 | 1.0 | 34.6 % | 68.3 % | |
| 1.2 | 2.6 | 1.2 | 34.6 % | 69.6 % | just under 35 % |
| 1.2 | 2.8 | 1.2 | 37.0 % | 72.4 % | in, but near the 30 WPM top |
| 1.5 | 1.2 | 1.2 | 14.8 % | 35.6 % | |
| 1.5 | 1.6 | 1.2 | 36.1 % | 58.7 % | |
| 1.5 | 2.0 | 1.2 | 37.7 % | 65.7 % | |
| 1.5 | 2.2 | 1.2 | 37.7 % | 66.8 % | |
| **1.5** | **2.4** | **1.2** | **39.1 %** | **68.3 %** | **chosen: both near the band centres** |
| 1.4 | 2.2 | 1.2 | 35.7 % | 65.6 % | edges |
| 1.6 | 2.2 | 1.2 | 43.8 % | 67.5 % | |
| 1.8 | 2.0 | 1.2 | 48.0 % | 66.4 % | 10 WPM over |
| 2.0 | 2.0 | 1.2 | 54.6 % | 69.6 % | 10 WPM over |
| 2.4 | 1.6 | 1.2 | 36.7 % | 56.0 % | 30 WPM under |

**Parity sweep** (lane 1.5, cooldown 2.4, projectile 1.2; arrival brains 1/2/3 unchanged), HR / ZR at 5 · 10 · 20 · 30 WPM:

| Bonus | 5 WPM | 10 WPM | 20 WPM | 30 WPM |
|---|---|---|---|---|
| 25 | 65 % | 68 % | 87 % | 94 % |
| 40 | 92 % | 85 % | 97 % | 101 % |
| **50** | **110 %** | **97 %** | **103 %** | **106 %** |
| 60 | 127 % | 108 % | 110 % | 110 % |

**After** (proposed: lane 1.5 s, cooldown 2.4 s, projectile 1.2 s, bonus 50, arrival brains 1/2/3; seeds 1..10):

| WPM | Arrival % | Arrived | Stopped | HR brains/min | ZR brains/min | Parity |
|---|---|---|---|---|---|---|
| 5 | 25.2 % | 6.3 | 18.9 | 12.32 | 11.25 | +10 % |
| 10 | 39.1 % | 19.7 | 30.7 | 16.96 | 17.50 | −3 % |
| 20 | 60.3 % | 60.6 | 40.0 | 30.96 | 30.00 | +3 % |
| 30 | 68.3 % | 103.0 | 47.8 | 44.84 | 42.50 | +6 % |

Robustness: seeds 1..5 → 40.3 % / 67.3 %, parity 109 / 98 / 104 %; seeds 1..20 → 38.7 % / 69.4 %, parity 109 / 97 / 101 %. Crossing times and hits to stop (FR55) unchanged.

**Tuning gate (2026-10-08):** asked with the After numbers above (lane 1.5 s, cooldown 2.4 s, projectile 1.2 s, bonus 50, arrival brains unchanged), alternatives "Exact half speed" (lane 1.2 s, cooldown 2.8 s) and "Not yet". Smuck's answer, verbatim: "Approve (Recommended)".

**3:00 retune (2026-10-08, after playtest P4):** Smuck, verbatim: "5 minutes felt too long, lets modify the level timer to 3 minutes". `duration_s` 300 → 180; bonus re-swept with the sim's new `--duration` option (lane 1.5, cooldown 2.4, projectile 1.2, arrival brains 1/2/3; seeds 1..10):

| Bonus | 5 WPM | 10 WPM | 20 WPM | 30 WPM |
|---|---|---|---|---|
| 25 | 93 % | 85 % | 96 % | 100 % |
| **30** | **108 %** | **94 %** | **102 %** | **104 %** |
| 35 | 123 % | 104 % | 107 % | 108 % |

**Final shipped** (duration 180 s, lane 1.5 s, cooldown 2.4 s, projectile 1.2 s, bonus 30, arrival brains 1/2/3; seeds 1..10):

| WPM | Arrival % | Arrived | Stopped | HR brains/min | ZR brains/min | Parity |
|---|---|---|---|---|---|---|
| 5 | 23.7 % | 3.5 | 11.4 | 12.13 | 11.25 | +8 % |
| 10 | 37.4 % | 11.1 | 18.7 | 16.53 | 17.50 | −6 % |
| 20 | 60.5 % | 36.0 | 23.5 | 30.57 | 30.00 | +2 % |
| 30 | 68.4 % | 60.9 | 28.2 | 44.13 | 42.50 | +4 % |

Seeds 1..5 (the test's set): 38.1 % / 67.6 %, parity 104 / 94 / 102 %. Bonus 30 keeps the per-minute bonus at exactly the approved 10/min, so the Tuning gate's economy is unchanged.

## Stress Results

**Stress check (AC 5), 2026-10-08**

| Item | Value |
|---|---|
| Machine | Dev PC (Ryzen 7 5700G / RTX 3070), far stronger than the NFR1 2018 laptop (same deviation as 5.3) |
| Browser | The Claude desktop app's built-in browser pane, Chromium 152.0.7977.130 (Electron, not stand-alone desktop Chrome: a deviation from the task text; same Blink/V8 engine) |
| Build | Debug web export (`--export-debug "Web"`), served by `web-debug` on localhost:8060, pane visible the whole time (checked before and after) |
| Run | Overlay jump "Horde Rush" (seed 606114939), "jar" typed (RUNNING), F4 → "stress: 30", held from clock 4.0 s to 91.8 s (~88 s), then F4 off, pause, Quit to Menu (never reached 5:00) |
| Copies | 30 marching held by the floor (more on screen counting arrivals shuffling in and melts); the Farmer, tomatoes, splats, melts, arrivals and pops all live; the brain counter ran to 480 |
| FPS | 60 throughout |
| Run worst (RUNNING frames only) | **19.0 ms** (≤ 33 ms: pass) |
| Pooling | **Not added**: under 33 ms, so no pooling (architecture Entity Patterns) |
| Evidence | `screenshots/6-7/stress-overlay.png` (clock 78.8 s, stress: 30, run worst 19.0 ms) |

**Full-run frame check (AC 6): Skipped.** 2026-10-08, Smuck's answer to "who does the full 5:00 release-build probe run?", verbatim: "Skip it". No reason was given beyond the choice. The probe's `arm({seconds: 300})` option is ready for it (deferred-work line added).

## Playtest Results

**Who / when (2026-10-08):** asked "who plays at least one full Horde Rush on the tuned build, and on which build?" (options: a kid later, Smuck as stand-in, a kid today). Smuck's answer, verbatim: "Me as stand-in". Build: the tuned debug web export on localhost:8060 (overlay jump "Horde Rush", since the menu card stays Coming soon until Task 7).

**Session 1 (2026-10-08):** player: Smuck (adult stand-in, 5.4 precedent); level: Horde Rush, one full 5:00 run on the tuned numbers (lane 1.5 / cooldown 2.4 / projectile 1.2 / bonus 50). Report card numbers: not reported. Smuck's report, verbatim: "This all felt good, except for p4, 5 minutes felt too long, lets modify the level timer to 3 minutes"

| # | Item | Result | Note |
|---|---|---|---|
| P1 | First minute | Pass | "all felt good" |
| P2 | Gets it | Pass | "all felt good" |
| P3 | Farmer is funny | Pass | "all felt good" |
| P4 | Not frustrating | **Fail** | "5 minutes felt too long" → fix: `duration_s` 300 → 180 (numbers only) |
| P5 | Watches, still types | Pass | "all felt good" |
| P6 | Pays fairly | Pass | "all felt good" |
| P7 | Wants more | Pass | "all felt good" |
| P8 | Nothing scary | Pass | "all felt good" |

**P4 fix (numbers only, back through the sim):** `duration_s` 300 → 180 at Smuck's request; to keep the bonus worth the same per minute (50 / 5 min = 10/min), `completion_bonus` 50 → 30 (30 / 3 min = 10/min). Defender numbers unchanged. See "3:00 retune" in Tuning Results; AC 2 and AC 3 still hold.

**P4 close-out (2026-10-08):** asked whether to replay 3:00 first or accept; Smuck's answer, verbatim: "Accept, switch it on". P4 recorded as fixed by the 3:00 change, accepted by Smuck without a replay.

**Smuck's verdict (2026-10-08), verbatim:** "Goofy, not frustrating".

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline sim (6.6 numbers): 2.0 % at 10 WPM, 14.1 % at 30, matching the 6.4 feel note. The throw cooldown, not the pace, is the cap: halving the pace alone gave 2.7 % / 17.7 %.
- Sim speed: 10 seeds × 4 WPMs of 300 s at 1/60 s ran in ~3.6 s including engine start; the tuning test is negligible in the ~19 s suite, so it keeps the 60 Hz step and 5 seeds.
- GUT's `-gtest=` is overridden by `.gutconfig.json` here (it ran the whole suite), so every check was a full-suite run.
- Browser pane: `computer type` sends no keydown events to the Godot canvas; `computer key` does. A hidden pane gave FPS 6; the measured run was taken with the pane visible.
- Tests: GUT 1556 before → 1582 after (+26: sim 9, tuning 4, level stress 7, overlay F4 5, screen flow 1). `git grep '^func test_'` only counts tracked files, so it reads lower until the new files are committed.
- Global RNG grep (`scripts/levels/horde_rush/`, `tools/horde_rush_sim.gd`): one hit, a doc comment. Log grep for Parse/Compile/Failed-to-load: 0.

### Completion Notes List

- **Sim (AC 1):** `tools/horde_rush_sim.gd`, a pure static `run()` mirroring the level's RNG order (words, then lanes), step order (field, then defender), spawn timing and end freeze, plus `zombie_run_brains_per_min()` read from `zombie_run.tres`. Headless runner with `--wpm/--seeds/--lane-time/--cooldown/--projectile/--bonus/--brains/--duration`. It never writes a file.
- **Tuning (AC 2, 3):** Tuning gate approved lane 1.5 s, cooldown 2.4 s, projectile 1.2 s and bonus 50. After the playtest (P4: "5 minutes felt too long") the run became 3:00 and the bonus 30 (same 10 brains/min). Final: 37.4 % / 68.4 % arrivals at 10 / 30 WPM; parity +8 % / −6 % / +2 % at 5 / 10 / 20 WPM. Crossing times, hits and arrival brains (FR55) are unchanged.
- **Tests (AC 4, 9):** `test_horde_rush_sim.gd` covers determinism, WPM pacing, accounting, the never-throwing defender, the global RNG and the GDD Zombie Run rates. `test_horde_rush_tuning.gd` guards the bands and the 1.2 s floor. Level mechanic tests pin 0.6 / 0.8 / 1.0 through `_make` / `_pinned_config`, so no assertion was weakened. Bonus asserts in `test_run_frame.gd` now read the config. `test_horde_defender.gd` passes untouched.
- **Stress (AC 5):** `_spawn_copy` extraction, `debug_set_stress_floor` / `get_stress_floor`, and a one-copy-per-frame top-up from `STRESS_WORDS` that never touches the run's WordSource. The overlay's F4 toggles 0 ↔ 30 on a RUNNING Horde Rush only, shows "stress: N/off" and lists F4 in its help. Measured 60 FPS, run worst 19.0 ms, so no pooling.
- **AC 6:** Skipped by Smuck ("Skip it"). The probe's `arm({seconds: N})` option is ready (buffer sized per arm, label shows the seconds, selftest passes in node).
- **AC 7:** Smuck stand-in playtest. Every item passed except P4, which was fixed with the 3:00 run and accepted ("Accept, switch it on"). Verdict, verbatim: "Goofy, not frustrating".
- **AC 8:** `horde_rush.available = true`, with Pitchfork Panic still Coming soon. Added a screen-flow test that the Horde Rush card starts a real run. No tag was pushed.
- **Also:** `sfx_tomato_throw` `min_interval_s = 0.08`. GDD, epics, probe README and deferred-work updated (resolved items annotated in place, new 6.7 section).
- Not committed: the commit (including the three new `.uid` files) is left for Smuck.

### File List

- `tools/horde_rush_sim.gd` (new), `tools/horde_rush_sim.gd.uid` (new)
- `tests/unit/test_horde_rush_sim.gd` (new), `tests/unit/test_horde_rush_sim.gd.uid` (new)
- `tests/unit/test_horde_rush_tuning.gd` (new), `tests/unit/test_horde_rush_tuning.gd.uid` (new)
- `screenshots/6-7/stress-overlay.png` (new)
- `data/levels/horde_rush.tres`
- `data/levels/level_registry.tres`
- `data/audio/audio_library.tres`
- `scripts/levels/horde_rush/horde_rush_level.gd`
- `scripts/debug/debug_overlay.gd`
- `tools/perf/frame_probe.js`
- `tools/perf/README.md`
- `tests/unit/test_horde_rush_config.gd`
- `tests/unit/test_horde_rush_level.gd`
- `tests/unit/test_debug_overlay.gd`
- `tests/unit/test_level_registry.gd`
- `tests/unit/test_main_menu.gd`
- `tests/unit/test_audio_library.gd`
- `tests/integration/test_run_frame.gd`
- `tests/integration/test_screen_flow.gd`
- `_bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md`
- `_bmad-output/planning-artifacts/epics.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/6-7-horde-rush-tuning-and-stress-check.md`

## Change Log

- 2026-10-08: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-08: Dev: headless sim, defender retune (lane 1.5 / cooldown 2.4 / projectile 1.2), F4 stress hold (60 FPS, run worst 19.0 ms, no pooling), probe `seconds` option, throw-sound throttle, docs and defers.
- 2026-10-08: Playtest P4 ("5 minutes felt too long"): Horde Rush shortened 5:00 → 3:00, completion bonus 30 (10 brains/min, parity kept). Note: AC 6 and the Dev Notes still say 5:00 / `seconds: 300`, the pre-playtest length; the shipped run is 3:00.
- 2026-10-08: Horde Rush switched on in the menu (Pitchfork Panic still Coming soon). AC 6 Skipped by Smuck. Status → review. 1582 tests green.
