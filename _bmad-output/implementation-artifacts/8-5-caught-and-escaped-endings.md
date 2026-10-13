---
baseline_commit: acb15721bbeb69733c73d520e19bbf1403b09198
---

# Story 8.5: Caught and Escaped! Endings

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want getting caught to be funny, and escaping to feel like a big win,
so that every chase ends with a laugh and I keep what I earned.

## Acceptance Criteria

1. **Caught outro (FR73).** When the mob's logical position reaches the zombie (`ChaseModel.caught()`, unchanged from 8.3), the level emits `end_requested(&"caught")` once, RunFrame enters ENDING (input stops: `%TypingInput.active = false`, existing behaviour) and calls `on_run_ending(&"caught")`, which starts this sequence and returns its full length (**3.0 s** with the shipped config):
   - **dust cloud, 1.5 s** (`caught_dust_s`): a cartoon dust cloud covers the zombie and the mob at the zombie's spot;
   - **dazed, 1.0 s** (`caught_dazed_s`): the cloud is gone, the zombie sits dazed with stars circling its head and a **"Got you!"** label shows;
   - **fade, 0.5 s** (`caught_fade_s`): the whole screen fades to `night` (#2B1D3F);
   - then RunFrame's existing outro countdown reaches DONE and the report card appears. All brains are kept.
2. **Escaped! at 5:00 (FR73).** When the run clock reaches `duration_s` (300 s) and the zombie has not been caught, the run ends with reason **`escaped`**, not `timer`. `on_run_ending(&"escaped")` starts: the zombie **dives through a bush (1.5 s, `escape_dive_s`)** and disappears into it, then an **"Escaped!"** label shows for `escape_label_s` (1.0 s, look value), then the report card appears (returns **2.5 s** with the shipped config). The HUD still counts 5:00 down to 0:00 as today.
3. **Bonuses (FR73).** Every caught or escaped run gets the **+10** finished-run bonus; an escaped run also gets **+25** (so `RunResult.bonus_brains` is 10 for caught and 35 for escaped; the report card's existing bonus row shows the total). `RunResult.end_reason` is `caught` or `escaped` and is saved in the run record. The wallet grows by pickup brains + bonus.
4. **Quit (FR13).** Quit to Menu from a Pitchfork Panic run keeps the pickup brains, adds no bonus and records nothing (existing RunFrame behaviour; tested for Pitchfork here).
5. **Catch beats the clock.** A catch in the same frame the clock reaches 5:00 still ends as `caught` with bonus 10 (the 8.3 process-priority rule, unchanged). The debug F6 "end run" on Pitchfork Panic ends it as `escaped` (it ends "exactly as if the clock ran out").
6. **Unlocks (FR79, no new code).** The Pitchfork Panic card stays Locked until a Horde Rush run ends on its timer; a caught or escaped Pitchfork run unlocks nothing. Still `available = false` (Coming soon) until 8.7. Zombie Run and Horde Rush still end with `timer` and unlock exactly as before.
7. **Logic first, visuals never gate.** The end reason, the bonus and the saved record are decided in the call that ends the run (RunFrame `_record_result` on entering ENDING, unchanged order). The outro is only visuals driven by node-bound tweens on the level; nothing in it awaits, and freeing the level mid-outro leaves nothing running.
8. **Tone and plain words (NFR10, FR60).** The only new kid-facing text is "Got you!" and "Escaped!" (EXPERIENCE.md string table). Placeholder visuals are cartoon, kid-safe (dust puff, dizzy stars, a bush), palette colours only. Real art for the dust cloud and stars comes in 8.6. A missing piece of visual never stops the run (NFR16).
9. **Nothing else regresses.** Zombie Run, Horde Rush, the test levels, the report card, the menu and unlocks behave as before. Full GUT suite green, no parse errors.

## Tasks / Subtasks

- [x] **Task 1: Two small, generic hooks in the level contract** (AC: 2, 3, 5, 6)
  - [x] 1.1 `scripts/run/level_base.gd`: add
    - `func get_timer_end_reason() -> StringName: return GameConstants.END_REASON_TIMER` — "The end reason RunFrame records when the run clock reaches duration_s (or the debug F6 end). Pitchfork Panic returns escaped."
    - `func get_end_bonus(_reason: StringName) -> int: return 0` — "Bonus brains on top of LevelConfig.completion_bonus for a recorded run that ended with `reason`. Pitchfork Panic's Escaped! (+25)."
    - Add both to the class doc's call order (`end:` line): RunFrame asks `get_timer_end_reason()` when its clock ends the run and `get_end_bonus(reason)` when it builds the result.
  - [x] 1.2 `scripts/run/run_frame.gd`:
    - new helper `_clock_end_reason() -> StringName`: `_level.get_timer_end_reason()`; if the value is not one of the three `END_REASON_*` constants, `Log.error(&"run", ...)` and return `END_REASON_TIMER` (NFR16, a bad label never loses a run);
    - `_process` (RUNNING, clock reached `_duration`) and `debug_end_run()` call `_end_run(_clock_end_reason())` instead of `_end_run(GameConstants.END_REASON_TIMER)`;
    - `_record_result()`: bonus = `_completion_bonus + maxi(0, _level.get_end_bonus(_end_reason))`; the duration clamp becomes "a clock-ended run never records more than `_duration`": clamp whenever `_duration > 0.0` (a caught run always ends before the clock, so this is identical for it), keep the no-timer F6 case (no clamp when `_duration <= 0.0`);
    - update the class doc ("A completed run adds the level config's completion_bonus …") to mention the level's end bonus and the clock end reason.
  - [x] 1.3 Do **not** touch `PlayerData`, `RunResult`, `TierCalculator` or the report card: they already accept `caught`/`escaped` (`run_result.gd:46`, `tier_calculator.gd:90`), unlock only on `timer` (`player_data.gd:137`), and show `bonus_brains` on one row (`report_card.gd:83,154`).
- [x] **Task 2: Config numbers** (AC: 1, 2, 3)
  - [x] 2.1 `scripts/resources/pitchfork_panic_config.gd`: add with `##` docs (neutral 0 defaults like the rest):
    - `escape_bonus: int` (FR73: brains added on top of completion_bonus when the zombie escapes);
    - `caught_dust_s`, `caught_dazed_s`, `caught_fade_s`, `escape_dive_s` (FR73 / GDD timings) and `escape_label_s` (look value: how long "Escaped!" shows before the report card; the GDD gives no number).
    - `validate()`: `escape_bonus >= 0`; each of the five times finite and `>= 0` ("caught_dust_s must not be negative", …). Also `completion_bonus >= 0` is already clamped by RunFrame; no check needed.
  - [x] 2.2 `data/levels/pitchfork_panic.tres`: `completion_bonus = 10` (was 0), `escape_bonus = 25`, `caught_dust_s = 1.5`, `caught_dazed_s = 1.0`, `caught_fade_s = 0.5`, `escape_dive_s = 1.5`, `escape_label_s = 1.0`.
  - [x] 2.3 `tests/unit/test_pitchfork_panic_config.gd`: shipped-values test asserts the seven values; bad-numbers table adds `escape_bonus = -1` and a negative / `INF` time for each of the five, each rejected with its own message.
- [x] **Task 3: Placeholder ending visuals (no new art files)** (AC: 1, 2, 8)
  - [x] 3.1 `scripts/levels/pitchfork_panic/dust_cloud.gd` (`class_name DustCloud extends Node2D`, class doc): draws 5–7 overlapping puff circles in `chalk` #F4F1E4 / `stone-light` #BDB6C4 with a 1 px `ink` #1E1428 outline (`draw_circle` + `draw_arc`), about 56×36 px, origin at bottom centre on the ground. `play(duration_s)`: a node-bound tween that wobbles the puffs (scale 0.9 ↔ 1.1 a few times, a little jitter on `position.x` of ±2 px) and hides itself at the end. Optional: a couple of short "action lines" or tiny star sparks inside. No RNG (fixed offsets), so seed replay is untouched.
  - [x] 3.2 `scripts/levels/pitchfork_panic/dizzy_stars.gd` (`class_name DizzyStars extends Node2D`): 3 small 5-point stars (`draw_colored_polygon`, `candy-yellow` #FFD23F, ink outline via `draw_polyline`) on an ellipse about 20×6 px, `rotation`-free orbit driven in `_process` while visible (so it never needs a looping tween). `start()` / `stop()`.
  - [x] 3.3 `scripts/levels/pitchfork_panic/escape_bush.gd` (`class_name EscapeBush extends Node2D`): a round bush from overlapping circles in `art-grass` #4E9A34 / `zombie-green-dark` #2E6B26 with an ink outline, about 40×32 px, origin bottom centre. `rustle(duration_s)`: a short node-bound scale wiggle. (Hedge vs gate vs bush is a per-setting choice later; one bush is enough here.)
  - [x] 3.4 These three are pure drawing nodes (scripts only, built in code or as tiny `.tscn` files under `scenes/levels/pitchfork_panic/`, your choice; keep them consistent). They read no config and play no sound. 8.6 may swap the drawing for sprites without changing the level.
- [x] **Task 4: The level's endings** (AC: 1, 2, 5, 7, 8)
  - [x] 4.1 `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn` (keep `load_steps` right):
    - under `World`, after `Zombie`: `EscapeBush` (hidden), `DustCloud` (hidden), so both draw in front of the zombie and the mob;
    - `DizzyStars` (hidden) also under `World`, after `Zombie` (not inside the zombie scene, which stays untouched); the level moves it to the zombie's head when the dazed beat starts;
    - at the level root (screen space, not scrolled): `EndLabel` (`Label`, hidden, unique name, `mouse_filter = 2`) styled like `scenes/run/countdown.tscn`'s `NumberLabel`: `candy-yellow` #FFD23F font colour, `ink` outline size 2, font size 32 (≥ 16 px rule; 32 so it reads as a moment), centred text;
    - `FadeLayer` (`CanvasLayer`, `layer = 10`, below Router's 100) with a full-rect `ColorRect` `%Fade` (`night` #2B1D3F, `modulate.a = 0`, `mouse_filter = 2`). A CanvasLayer is the only way a level can cover the HUD band; Router's own 0.15 s fade then fades night to night, so the swap is seamless.
  - [x] 4.2 `pitchfork_panic_level.gd`:
    - `get_timer_end_reason()` → `GameConstants.END_REASON_ESCAPED`;
    - `get_end_bonus(reason)` → `_cfg.escape_bonus` for `escaped`, else 0 (null-guard `_cfg`);
    - `on_run_ending(reason)`: keep the existing stop (`_running = false`, kill the walk tween). Guard a second call with an `_ending_reason` field: a repeat call starts nothing and returns the same length. Hide `%Pickups` (pickups left on the path disappear; pops already rising in `%World` finish on their own). Then:
      - `caught` → `_play_caught()` and return `caught_dust_s + caught_dazed_s + caught_fade_s`;
      - `escaped` → `_play_escape()` and return `escape_dive_s + escape_label_s`;
      - anything else (only a test or a bad call) → idle, return 0.0 as before;
    - `_play_caught()`: one node-bound `create_tween()` chain (never `await`): show `%DustCloud` at the zombie's world x on `GROUND_Y` and `play(caught_dust_s)` (the zombie stays visible; the cloud covers it and the mob); after `caught_dust_s`: hide the cloud, put the zombie in its dazed pose (placeholder: `play_idle()` and lower/tilt the zombie node a little, e.g. `rotation_degrees = -12`, `position.y = GROUND_Y + 2`; 8.6 may give a real sit frame), place `%DizzyStars` above its head and `start()`, show `%EndLabel` "Got you!" centred over the zombie's screen x (clamped inside 0–640) at about y 100; after `caught_dazed_s`: tween `%Fade.modulate.a` 0 → 1 over `caught_fade_s`;
    - `_play_escape()`: show `%EscapeBush` a short way ahead of the zombie sprite (`_zombie.position.x + ESCAPE_BUSH_AHEAD_PX`, a layout constant ~48 px, "not a GDD number") on `GROUND_Y`; tween the zombie's **own** `position` (not `_set_zombie_x`: the camera stops for the dive) forward to the bush with a small hop arc (`play_walk()` during the run-up), hide the zombie as it reaches the bush centre and `rustle()` the bush, all within `escape_dive_s`; then show `%EndLabel` "Escaped!" centred on the playfield (x 320, about y 100) for `escape_label_s`. No fade (the Router's fade follows);
    - update the class doc: drop "Interim endings (replaced by Story 8.5)", describe both outros, the two hooks and that the camera stops for the dive (the "nothing else ever tweens the zombie's position" sentence needs the exception);
    - mob: stays where it froze in both endings (its last logical spot, so on a catch it overlaps the zombie under the cloud; the 8.3 deferred overlap note is covered by the cloud).
  - [x] 4.3 Strings: put "Got you!" and "Escaped!" in `const` StringName/String constants in the level (e.g. `TEXT_CAUGHT`, `TEXT_ESCAPED`); check whether the project keeps kid-facing strings elsewhere (grep for an existing strings table, e.g. how the hint "Finish Horde Rush to open!" is stored) and follow that pattern if one exists.
- [x] **Task 5: Level tests** (`tests/unit/test_pitchfork_panic_level.gd`) (AC: 1, 2, 5, 7, 8)
  - [x] 5.1 Replace `test_run_ending_returns_no_outro` with: `on_run_ending(&"caught")` returns `1.5 + 1.0 + 0.5` and `on_run_ending(&"escaped")` returns `1.5 + 1.0` (written-out numbers, not read back from the config); a second call returns the same and does not restart the tweens; an unknown reason returns 0.0.
  - [x] 5.2 `get_timer_end_reason() == END_REASON_ESCAPED`; `get_end_bonus(&"escaped") == 25`, `get_end_bonus(&"caught") == 0`; both safe with a null config (a level built with a broken config).
  - [x] 5.3 Caught sequence by beats (drive the tweens with `await wait_seconds` or GUT's `simulate`, or call the tween step manually; pick one and document it): at t≈0.1 the cloud is visible and the label is not; at t≈1.6 the cloud is hidden, the stars and "Got you!" are visible, the fade alpha is 0; at t≈2.9 the fade alpha is > 0.5; the zombie is still in the tree throughout.
  - [x] 5.4 Escape sequence: at t≈0.1 the bush is visible and the zombie is visible; by t≈1.6 the zombie is hidden and "Escaped!" is visible; `%World.position.x` did not change during the dive (camera stopped).
  - [x] 5.5 Pickups are hidden after either ending; brains are unchanged by the ending; keys after the ending still collect and move nothing (the existing tests keep passing; their `on_run_ending(&"timer")` calls stay valid as the "unknown reason → no outro" path, or switch them to `caught`).
  - [x] 5.6 Freeing the level mid-outro raises no errors (node-bound tweens die with it).
  - [x] 5.7 Short drawing-node tests (own file or the level file): `DustCloud.play(d)` hides itself after `d`; `DizzyStars.stop()` hides; `EscapeBush.rustle(d)` ends at scale 1.
- [x] **Task 6: RunFrame integration tests** (`tests/integration/test_run_frame.gd`, Pitchfork section ~1960–2075) (AC: 2–6)
  - [x] 6.1 `test_pitchfork_caught_run_keeps_the_pickup_brains`: `bonus_brains == 10`, wallet `before + 5 + 10`. Its `frame._process(1.0)` no longer reaches DONE (the outro is 3.0 s): step past the outro (e.g. `frame._process(3.1)`) and assert ENDING before, DONE after.
  - [x] 6.2 Rename/rewrite `test_pitchfork_timer_run_keeps_the_pickup_brains` → `…escaped_run_…`: `end_reason == END_REASON_ESCAPED`, `brains == 5`, `bonus_brains == 35`, `duration_s == 300.0` (clamped), wallet `before + 5 + 35`, the saved record's `end_reason` is `"escaped"`, and no level was unlocked.
  - [x] 6.3 `test_pitchfork_caught_run_ends_as_caught_and_unlocks_nothing` and `test_pitchfork_catch_in_the_timers_last_frame_ends_as_caught`: adjust the DONE step for the 3.0 s outro; the last-frame test also asserts `bonus_brains == 10` (not 35).
  - [x] 6.4 New: debug F6 (`debug_end_run()` with the debug seam true) on Pitchfork records `escaped` with bonus 35.
  - [x] 6.5 New: Quit to Menu mid-chase after one pickup: wallet +5 only, `record_run` not called (history unchanged), no report card navigation (mirror `test_horde_rush_quit_keeps_the_arrival_brains_without_a_bonus` ~line 1722).
  - [x] 6.6 New: a level whose `get_timer_end_reason()` returns a bad value records `timer` and logs (a tiny inline `LevelBase` subclass or a test-level override; skip if the existing test levels make it awkward and note why). Zombie Run and Horde Rush timer tests stay unchanged and green (they prove the default hook).
  - [x] 6.7 FR79: check `test_level_unlocks.gd` already proves a Horde Rush `timer` run unlocks Pitchfork Panic (Coming soon still wins while `available = false`); add one assertion only if it does not.
- [x] **Task 7: Visual check and wrap-up** (AC: 1, 2, 8, 9)
  - [x] 7.1 Run the import, then the full GUT suite. Re-run the baseline first (8.4 recorded **1954 passing / 104 scripts** before its review patches, so expect a few more). Grep the log for `Parse Error|Compile Error|Failed to load script`. Record new totals.
  - [x] 7.2 Visual check like 8.4 Task 7.2 (throwaway scene under `tools/_scratch_8_5/`, deleted afterwards, on the real `RunFrame`, tier 3 temp save, never the real save, fixed seed). Capture: (a) the dust cloud mid-puff; (b) the dazed zombie with stars and "Got you!"; (c) mid-fade; (d) the bush with the zombie mid-dive; (e) "Escaped!"; (f) the report card for each ending showing the bonus row (+10 / +35). For the escape use F6 (`debug_end_run`) instead of waiting 5 minutes. Save to `_bmad-output/implementation-artifacts/screenshots/8-5/`. Show Smuck for layout, readability and tone (art is placeholder until 8.6); record the verdict verbatim.
  - [x] 7.3 New `.uid` files commit with the story; list every new file in the File List.
  - [x] 7.4 `deferred-work.md`: add "Deferred from: dev of story 8-5" (see Known limitations) and mark the 8.3/8.4 items this story resolves (completion bonus split, `timer` → `escaped`, interim caught ending, pickups left on the path, mob/zombie overlap at the catch) as resolved in 8.5.
  - [x] 7.5 Sprint status `8-5-caught-and-escaped-endings: review` (dev-story does this).

### Review Findings

- [x] [Review][Patch] Restore missing-node guards in `on_run_ending` (`_zombie`, `_pickups`) and the overlay nodes used by `_play_caught` / `_play_escape` (AC8 "a missing visual never stops the run") [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:224]
- [x] [Review][Patch] An unknown end reason sets `_ending_reason` and leaves `_outro_length` 0, so a later real `caught`/`escaped` call is ignored; only latch the reason for known reasons [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:228]
- [x] [Review][Patch] Add `uid=` to the three new script `ext_resource` lines (`escape_bush`, `dust_cloud`, `dizzy_stars`), values from their `.uid` files [scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn]
- [x] [Review][Patch] INF/NAN time values report "must not be negative"; give them an accurate message (update the tests' expected text too) [scripts/resources/pitchfork_panic_config.gd:356]
- [x] [Review][Defer] Level instance reuse: `_ending_reason`, `_outro_length`, zombie tilt/visibility are never reset in `create_target_source` [scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:272] — deferred, retry builds a fresh scene so it is unreachable today
- [x] [Review][Defer] Zero or huge outro durations pass `validate()` (0 collapses the outro to one frame, 1e9 stalls the report card) [scripts/resources/pitchfork_panic_config.gd:352] — deferred, spec allows >= 0 and only a hand-edited .tres can hit it
- [x] [Review][Defer] Test fragility: integration tests use literal timings (2.9, 3.1, 2.4, 2.6) tied to config totals; the mid-outro free test needs two frames and mixes `remove_child`/`free()` with autofree [tests/integration/test_run_frame.gd, tests/unit/test_pitchfork_panic_level.gd] — deferred, works today

## Dev Notes

### What this story is (and isn't)

- **It is:** the two Pitchfork Panic endings (caught outro, Escaped! at 5:00) with placeholder cartoon visuals, the +10 / +25 bonuses, `caught`/`escaped` recorded, and two tiny generic hooks on `LevelBase` that RunFrame asks.
- **It isn't:** Moonlit Village, mob sprites, real dust-cloud / star art, the dust-cloud sound or chase music (8.6); tuning or `available = true` (8.7). No new audio cue in this story (8.6 adds `sfx_dust_cloud` or similar and credits it). No save schema change.

### Why hooks, and not "the level ends itself at 300 s"

The 8.3 deferred note offered two ways: `duration_s = 0` and the level emits `escaped`, or end before the timer. Both are worse than a hook:
- The level must never read the clock (ADR-1); `ChaseModel.elapsed_s` lags the run clock when a frame is over `MAX_FRAME_S` (8.3 deferred note), so a level-side 300 s check would drift from the HUD.
- `duration_s = 0` would turn the HUD's 5:00 countdown into a count-up (`hud.gd:206`), losing the kid's "how long until I escape" cue.
- With `get_timer_end_reason()` RunFrame's clock stays the single authority, the HUD keeps counting down, F6 works for free, and the catch-before-timer priority (8.3 `PROCESS_PRIORITY = -1`) is untouched.
- `get_end_bonus(reason)` keeps the reason-specific bonus in the level's config without RunFrame knowing anything about Pitchfork. `completion_bonus = 10` stays the generic "every recorded run" bonus.

### The numbers (don't re-derive)

- Caught outro: 1.5 + 1.0 + 0.5 = **3.0 s** (GDD Level 3 / FR73). Escape outro: 1.5 dive + 1.0 label = **2.5 s** (the 1.0 s label hold is a look value; the GDD gives none).
- Bonuses: caught **+10**, escaped **+10 +25 = 35** on `RunResult.bonus_brains`; the record's `brains` field is `total_brains()` (`run_result.gd:83`), so it includes the bonus (existing behaviour for every level).
- GDD economy check (context for 8.7, not tested here): 10 WPM caught ≈ 30 pickup + 10 = 40; 20 WPM escape ≈ 125 + 10 + 25 = 160.

### Existing code to read first

| File | Current state | This story |
|---|---|---|
| `scripts/run/level_base.gd` | Contract; `on_run_ending` returns the outro length; `get_brains_earned` | Add `get_timer_end_reason()` and `get_end_bonus(reason)` with safe defaults |
| `scripts/run/run_frame.gd` | `_process` / `debug_end_run` end with `END_REASON_TIMER` (`:191`, `:229`-ish); `_record_result` adds `_completion_bonus` and clamps duration only for `timer` (`:441–455`); ENDING calls `on_run_ending` then `_record_result` | Ask the hooks; clamp for any `_duration > 0` |
| `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` | Interim ending: `on_run_ending` stops and returns 0.0; catch emits `caught` once | Both outros, hooks, hide pickups |
| `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn` | `Backdrop`, `World/{Pickups, Mob, Zombie}`, `MobGlow` | Add bush, cloud, stars, `EndLabel`, `FadeLayer/Fade` |
| `scripts/resources/pitchfork_panic_config.gd`, `data/levels/pitchfork_panic.tres` | Chase + pickup numbers; `completion_bonus = 0` | Bonus and outro numbers |
| `scripts/autoloads/player_data.gd:110–150` | `record_run`: history, best, brains, unlocks only on `timer`, tier | **No change** (escaped/caught unlock nothing, which is right) |
| `scripts/typing/run_result.gd`, `tier_calculator.gd:90` | Already accept caught/escaped | **No change** |
| `scripts/screens/report_card.gd:83,154` | One "+N bonus" row when `bonus_brains > 0` | **No change** |
| `scripts/characters/player_zombie.gd` | idle/walk/hop/hug/dance/flash/melt; no sit | **No change**; the level tilts the node for the dazed pose |
| `scenes/run/countdown.tscn` | Candy-yellow 64 px number with ink outline | Copy the label style (32 px) |
| `scripts/autoloads/router.gd:25–28` | 0.15 s fade to `night` on layer 100 | Fade to the same colour below it |

### What must keep working (regression guard)

- `test_run_frame.gd` Zombie Run / Horde Rush bonus and timer tests (they prove the default hook still records `timer` and unlocks), `test_level_unlocks.gd`, `test_main_menu.gd`, `test_level_card.gd`, `test_report_card.gd`, `test_player_data*.gd`, `test_tier_calculator.gd`, `test_zombie_run_level.gd`, `test_horde_rush_level.gd`, `test_test_level.gd`, `test_chase_model.gd`, `test_pickup_trail.gd`, `test_brain_pickup.gd`.
- 8.3/8.4 behaviours: one step per key in the key's call, camera at x 384 while running, catch emitted once, catch before the timer, pickups collected only while running, run RNG drawn exactly twice (the ending visuals draw nothing).
- Welcome Gift: the report card's first-completed-run redirect still fires after a Pitchfork run (it keys off a result existing, unchanged).

### Logic leads, visuals chase

- RunFrame enters ENDING → `on_run_ending(reason)` (starts tweens, returns the length) → `_record_result()` (reason, bonus, save) — all in one synchronous call. The outro cannot change the result.
- The tree is **not** paused during ENDING (pause is refused there), so level tweens run; use `create_tween()` on the level or its children so they die with the level.
- The camera: during the caught outro nothing moves; during the dive only the zombie node moves (the world and backdrop stay), so the zombie runs off its 60% spot into the bush.

### Known limitations (note in deferred-work; don't fix here)

- Placeholder dust cloud, stars and bush are code-drawn; 8.6 replaces them with style-sheet sprites (and may add a sit/dazed frame to the zombie).
- No ending sounds (dust cloud thump, escape cheer) until 8.6.
- One bush for every setting; hedge/gate variants arrive with the chase settings (Epic 10.4).
- The report card shows one "+35 bonus" line for an escape, not "+10" and "+25" separately; the "Escaped!" moment carries the win. Revisit if playtest kids don't connect the bonus to escaping.

### Architecture and rules

- **ADR-1:** a level never reads input, the clock or `PlayerData`, never calls the Router; RunFrame calls down (hooks), the level signals up. The hooks are pure getters.
- **Same-frame rule (NFR2):** no `await`, deferred call or timer in the key or end path.
- **GDScript:** static typing everywhere (`untyped_declaration = Error`), typed loop variables and arrays, tabs, `##` docs on classes and public functions, `snake_case` files, `PascalCase` classes, `UPPER_SNAKE` constants, StringName log tags. Content/config errors never `assert` (NFR16).
- **Never mutate shared resources:** tests `duplicate(true)` the config before tweaking (`_make(seed, tweak)` does).
- **Palette:** only `docs/art-style-sheet.md` colours (ink #1E1428, night #2B1D3F, chalk #F4F1E4, stone-light #BDB6C4, candy-yellow #FFD23F, art-grass #4E9A34, zombie-green-dark #2E6B26). Candy-yellow is reserved for "look here now", which these two labels are.

### Testing notes

- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. One script: `-gdir=res://tests/unit -gselect=<name>`.
- GUT skips a script that fails to parse and still exits 0: grep for `Parse Error|Compile Error|Failed to load script`.
- Tween timing in tests: GUT `await wait_seconds(t)` uses real time; `simulate(node, frames, delta)` drives `_process` and is not a reliable way to advance tweens. Prefer `Tween.custom_step(delta)` on the level's tweens (keep a reference, e.g. `get_outro_tween()` for tests) so beat checks are deterministic and fast.
- Written-out oracles: 3.0 / 2.5 s, 10 / 35 bonus, "Got you!" / "Escaped!", `"escaped"` in the saved record.
- Tests never write the real save (inject `PlayerData` on a temp `SaveService`, as `test_run_frame.gd` does).

### Previous story intelligence (8.4)

- Reuse `_make(seed, tweak)`, `_type(count)`, `_set_gap`, `_first_pickup()`, `_pickup_nodes()` in the level test; `_start_pitchfork(data)`, `_paragraph_player_data`, `_send_char`, `_result()`, `_hud_text` in `test_run_frame.gd`.
- Smuck's visual gate changes layout: 8.4's pop moved in front of the zombie on review. Expect label position/size calls; keep layout values as named constants so they're quick to move.
- Review lessons: keep `.tscn` `load_steps` and uids right; null-guard getters that read `_cfg`; a test must exercise what its name says; read constants instead of hardcoding layout numbers in tests where the code has a constant; don't let a test depend on the dealt passage's length.
- `-s` SceneTree scripts can't see autoloads: use a throwaway scene for screenshots and delete it.

### Git intelligence

- One commit per story ("Story 8.N: …, code review patches applied, done"); new scripts commit with their `.uid` files.
- 8.1 content, 8.2 paragraph display + save v2, 8.3 chase level, 8.4 pickups. This story touches `level_base.gd` and `run_frame.gd` for the first time in Epic 8: keep those diffs to the two hooks, the clamp and docs.

### Project Structure Notes

- New: `scripts/levels/pitchfork_panic/dust_cloud.gd`, `dizzy_stars.gd`, `escape_bush.gd` (+ `.uid`, + `.tscn` if you make scenes), new test file(s), `screenshots/8-5/`.
- Modified: `level_base.gd`, `run_frame.gd`, `pitchfork_panic_config.gd`, `pitchfork_panic.tres`, `pitchfork_panic_level.gd`, `pitchfork_panic_level.tscn`, `test_pitchfork_panic_config.gd`, `test_pitchfork_panic_level.gd`, `test_run_frame.gd`, `deferred-work.md`, `sprint-status.yaml`.
- Untouched: `player_data.gd`, `run_result.gd`, `tier_calculator.gd`, `report_card.gd`, `hud.gd`, `chase_model.gd`, `pickup_trail.gd`, `player_zombie.gd`, `audio_library.tres`, `CREDITS.md`, `assets/`, save schema, Zombie Run / Horde Rush files.

### Project Context Rules

- No `project-context.md` exists. Rules come from `_bmad-output/game-architecture.md` and `epics.md` *Additional Requirements*: Godot 4.7.2, GDScript only, GUT 9.7.1; typed Resources and data under `res://data/`; `Log` with tags; audio only through `AudioManager`; exports exclude `tests/*` and `tools/*`.
- MCP: the `godot` server (`run_project`, `get_debug_output`) is available for the visual check; the headless CLI is the test path.

### Latest tech information

No new libraries. Godot 4.7.2 / GUT 9.7.1. APIs used: `Node2D._draw` with `draw_circle`, `draw_arc`, `draw_colored_polygon`, `draw_polyline`, `queue_redraw`; `create_tween()`, `tween_property`, `tween_interval`, `tween_callback`, `set_parallel`, `Tween.custom_step`; `CanvasLayer.layer`; `Label` theme overrides (`font_color`, `font_outline_color`, `outline_size`, `font_size`). No web research needed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 8.5: Caught and Escaped! Endings], FR13, FR73, FR79, NFR10, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Win/loss table (~line 104), Level 3: Pitchfork Panic (~326–339), Economy table (~269)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] strings table ("Got you!" · "Escaped!", ~line 63), Run → Ending (~129)
- [Source: docs/art-style-sheet.md] palette
- [Source: _bmad-output/implementation-artifacts/8-4-brain-pickups-on-the-path.md], [8-3-chase-movement-mob-and-camera.md]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] ~669–701 (8.3 / 8.4 notes this story resolves)
- [Source: scripts/run/run_frame.gd] `_process`, `debug_end_run`, `_record_result`, `_set_state(ENDING)`
- [Source: scripts/autoloads/player_data.gd:137] unlocks only on `timer`

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline before the story: 8.4 recorded 1954 passing / 104 scripts before its review patches. After this story: **1970 passing / 104 scripts**, 0 failing, no `Parse Error|Compile Error|Failed to load script` in the log (Godot 4.7.2 headless, GUT 9.7.1).
- `test_freeing_the_level_mid_outro_stops_everything` first failed: a tween bound to a freed node is only killed on its next tree step, so the test now waits two process frames before checking `is_valid()`.
- Expected `ERROR` lines in the log: the three Pitchfork config/no-config tests and the new bad-end-reason test (`level bad_end gave unknown timer end reason 'bogus'`), each asserted with `assert_push_error_count`.

### Completion Notes List

- **Hooks (Task 1):** `LevelBase.get_timer_end_reason()` (default `timer`) and `get_end_bonus(reason)` (default 0). RunFrame's clock end and the debug F6 both call `_clock_end_reason()`, which logs and falls back to `timer` for a value outside `END_REASON_*`. `_record_result()` adds `completion_bonus + max(0, get_end_bonus(reason))` and clamps the duration whenever `_duration > 0` (the no-timer F6 case keeps the elapsed time). `PlayerData`, `RunResult`, `TierCalculator` and the report card are untouched.
- **Config (Task 2):** `escape_bonus`, `caught_dust_s`, `caught_dazed_s`, `caught_fade_s`, `escape_dive_s`, `escape_label_s` with `##` docs and validation (each time finite and >= 0, each with its own message). Shipped: completion 10, escape 25, 1.5 / 1.0 / 0.5, 1.5 / 1.0.
- **Placeholder visuals (Task 3):** `DustCloud`, `DizzyStars`, `EscapeBush` are script-only `Node2D`s placed directly in the level scene (no extra `.tscn`), palette colours only, no RNG, no config, no sound. The cloud wobbles with a node-bound tween and hides itself; the stars orbit in `_process` while shown; the bush rustles and ends at scale 1.
- **Endings (Task 4):** `on_run_ending()` is guarded by `_ending_reason` (a repeat returns the same length and starts nothing), stops the chase, hides `%Pickups`, then plays one node-bound tween chain: caught = cloud on the zombie (1.5 s) -> dazed tilt, stars, "Got you!" over the zombie (1.0 s) -> `%Fade` to night on a `CanvasLayer` at layer 10 (0.5 s), returns 3.0; escaped = bush 48 px ahead, the zombie node hops/runs to it in 80% of the dive (camera stopped), vanishes, bush rustles, then "Escaped!" centred, returns 2.5. Unknown reason = 0.0. Strings are `TEXT_CAUGHT` / `TEXT_ESCAPED` constants in the level (the project has no strings table; kid-facing strings live in their scripts/scenes). Layout values are named constants.
- **Tests (Tasks 5, 6):** level tests drive the outro with `Tween.custom_step()` on `get_outro_tween()` (documented in the file header) and check every beat; drawing-node tests in the same file. RunFrame: caught +10 (ENDING at 2.9 s, DONE after 3.0), escaped +35 with duration clamped to 300 and `"escaped"` in the saved record and nothing unlocked, catch in the last frame stays caught with +10, F6 records escaped +35, Quit keeps pickup brains without a bonus and records nothing, a bad hook value records `timer` and logs (fixture `tests/fixtures/levels/bad_end_reason_level.gd` extends the test level; the test packs it into a one-entry registry). FR79: no existing test proved a Horde Rush `timer` run opens Pitchfork Panic, so `test_lazily_uses_the_shipped_registry` gained one assertion.
- **Visual check (Task 7.2):** throwaway `tools/_scratch_8_5/capture.{gd,tscn}` on the real `RunFrame` and report card, tier 3 temp save under `user://scratch_8_5_saves` (never the real save), seed 42, catch forced after 12 keys, escape via F6 after 30 keys; scene and temp saves deleted afterwards. During the check `EndLabel` was widened from 160 to 320 px (offsets 160-480) so "Got you!" fits its box instead of relying on the label growing; the screenshots were retaken after. Screenshots in `screenshots/8-5/`. Smuck's verdict: "approved".
- `deferred-work.md`: 8.3/8.4 items marked resolved in 8.5 (bonus split, `timer` -> `escaped`, interim caught ending, pickups left on the path, overlap at the catch); new "Deferred from: dev of story 8-5" section.

### File List

New:
- `scripts/levels/pitchfork_panic/dust_cloud.gd` (+ `.uid`)
- `scripts/levels/pitchfork_panic/dizzy_stars.gd` (+ `.uid`)
- `scripts/levels/pitchfork_panic/escape_bush.gd` (+ `.uid`)
- `tests/fixtures/levels/bad_end_reason_level.gd` (+ `.uid`)
- `_bmad-output/implementation-artifacts/screenshots/8-5/` (caught-a-dust-cloud, caught-b-dazed-got-you, caught-c-mid-fade, caught-d-report-card, escape-0-before, escape-a-mid-dive, escape-b-in-the-bush, escape-c-escaped, escape-d-report-card)

Modified:
- `scripts/run/level_base.gd`
- `scripts/run/run_frame.gd`
- `scripts/resources/pitchfork_panic_config.gd`
- `data/levels/pitchfork_panic.tres`
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd`
- `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`
- `tests/unit/test_pitchfork_panic_config.gd`
- `tests/unit/test_pitchfork_panic_level.gd`
- `tests/integration/test_run_frame.gd`
- `tests/unit/test_player_data.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/8-5-caught-and-escaped-endings.md`

Created and deleted (throwaway): `tools/_scratch_8_5/capture.gd`, `tools/_scratch_8_5/capture.tscn`

## Change Log

- 2026-10-13: Story 8.5 implemented: `LevelBase` end-reason and end-bonus hooks used by RunFrame; Pitchfork Panic caught outro (dust cloud, dazed "Got you!", fade to night) and Escaped! outro (bush dive), +10 / +35 bonuses, `caught` / `escaped` recorded; placeholder drawing nodes; config numbers; tests (1970 passing). Visual check approved by Smuck; status review.
