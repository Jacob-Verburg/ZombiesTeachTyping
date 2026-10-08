---
baseline_commit: 48071fd7685945c08c283342f15f82a5801e90af
---

# Story 6.5: Arrivals, Brains and Run End

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want my zombies that reach the house to grab brains,
so that getting through the defence pays off.

## Acceptance Criteria

1. **Arrival brains (FR57).** Given a copy reaches the house (`HordeField.advance` returns it), when the level handles the arrival, then in the same logic step and before any visual it adds its class's `arrival_brains` (small 1, medium 2, brute 3, read from `horde_rush.tres`) to the level's run total, and `get_brains_earned()` returns that total. A stopped (melted) copy still earns nothing.
2. **HUD counter (FR14).** Given an arrival that pays more than 0, when it is awarded, then the level emits `brains_earned_changed(total)` once with the new total (one emit per paying arrival, in arrival order), so RunFrame's existing wiring updates the shared HUD brain counter.
3. **"Brainsss" (FR57, FR48).** Given an arrival, when it is awarded, then the level asks for `vo_brainsss` through a `request_voice` seam (default `AudioManager.play_voice`). Every arrival asks; `AudioManager`'s 8 s voice gap is the throttle. No chance roll and no RNG draw, so the words and lanes of a seed are unchanged.
4. **Shuffle-in and pop.** Given an arrival, when it is shown, then the copy's sprite leaves the march at once, shuffles into the house (a short self-freeing one-shot: it steps right and slips out of sight, then is freed) and a brain pop with a "+N" label (N = the brains it paid) rises from the house front and frees itself. Neither gates input or logic. A copy whose sprite is missing still pays.
5. **Hitch cap.** Given a single frame `delta` longer than `MAX_FRAME_S` (0.5 s, a robustness const), when `_process` runs, then only `MAX_FRAME_S` of logic is advanced (still split into steps of at most `MAX_STEP_S`), so a hitch can neither pay a burst of brains nor run hundreds of steps in one frame (closes the 6.3/6.4 deferred items).
6. **Run end (FR57, FR7).** Given the clock reaches 5:00, when RunFrame calls `on_run_ending(&"timer")`, then the march, the defender and every projectile freeze (as in 6.4); tomatoes still in the air are removed from screen; every marching copy dances in place; and the level returns `outro_time_s` (2.0 s, from `horde_rush.tres`) so RunFrame waits that long before the report card. `horde_rush.tres` sets `completion_bonus = 25`, so the RunResult has `brains` = arrival brains and `bonus_brains` = 25, and the report card shows the stats (WPM already includes implied spaces, Story 6.2) and the "+25 bonus" line. No arrival can pay after `on_run_ending`.
7. **Quit (FR13).** Given a run quit from the pause menu, when it ends, then the arrival brains so far are added to the wallet, no bonus is given and nothing is recorded in history (RunFrame's existing quit path; the level only has to report the right `get_brains_earned()`).
8. **No regressions.** The 6.3 spawn/march/seed-replay and 6.4 defender/projectile/flash/melt behaviour is unchanged except where this story says so (arrival now pays and shuffles instead of vanishing; the end dances instead of idling; tomatoes are cleared at the end; long frames are capped). Horde Rush stays `available = false`. Play Again from the report card starts a fresh Horde Rush run with 0 brains.
9. **Tests.** GUT covers the config fields, the arrival award per class, the signal, the voice seam, the shuffle and pop one-shots, the hitch cap, the outro (dance, tomatoes cleared, returned length), reset on re-create, and RunFrame integration (timer end: brains + 25 bonus; quit: brains kept, no bonus, no record). Full suite green.

## Tasks / Subtasks

- [x] **Task 1: Config** (AC: 1, 6)
  - [x] 1.1 `scripts/resources/horde_rush_config.gd`: add `@export var outro_time_s: float = 0.0` with a `##` doc ("FR57: seconds the run-end dance lasts before the report card"). Update the class doc ("Story 6.4 adds the defender numbers" → also mention 6.5's outro).
  - [x] 1.2 `validate()`: append after the existing checks (keep every existing message and order; tests assert them): `outro_time_s` must be `> 0` and finite → `"outro_time_s must be above 0"`. (Zero is rejected, like `ZombieRunConfig.dance_time_s`, so the end never jumps straight to the report card.)
  - [x] 1.3 `data/levels/horde_rush.tres`: `completion_bonus = 25` (was 0) and `outro_time_s = 2.0`. Leave `arrival_brains` 1/2/3 and every defender number untouched: 6.7 owns tuning and economy parity.
- [x] **Task 2: Arrival award** (AC: 1, 2, 3, 4)
  - [x] 2.1 `horde_rush_level.gd`: add `var _brains: int = 0` (logical run total) and a `request_voice: Callable` test seam, defaulted in `_ready()` to `AudioManager.play_voice` unless a test assigned one before `add_child` (copy `zombie_run_level.gd`'s pattern exactly, including the doc). `_reset()` sets `_brains = 0`.
  - [x] 2.2 Replace the body of `_on_marcher_arrived(marcher)` (keep it one method, still called only from `_logic_step`): logic first: `var gained: int = marcher.size_class.arrival_brains`; if `gained > 0`: `_brains += gained`, `brains_earned_changed.emit(_brains)`. Then `if request_voice.is_valid(): request_voice.call(&"vo_brainsss")` (every arrival, no roll). Then the visuals: erase the sprite from `_views`, kill and erase its flash tween (6.4 review patch: never leave a stale entry), `_spawn_pop(marcher, gained)`, and `_shuffle_in(view, marcher)` if the view exists.
  - [x] 2.3 `get_brains_earned()` returns `_brains` (update its doc).
  - [x] 2.4 Do not touch the RNG: the class doc's "the run RNG itself is unused for now and reserved; Story 6.5 takes it or a third child" becomes "unused (6.5's Brainsss has no roll; AudioManager's voice gap throttles it)".
- [x] **Task 3: Shuffle-in and brain pop views** (AC: 4)
  - [x] 3.1 `_shuffle_in(view, marcher)`: `view.modulate = Color.WHITE`, `view.play_walk()`, then a node-bound `view.create_tween()` (parallel) over `SHUFFLE_S` that moves `position.x` by `+SHUFFLE_PX` and squashes `scale.x` to 0 (slipping through the door edge-on), then `tween_callback(_on_shuffle_done.bind(view))` frees it. Track in `_shuffle_tweens: Dictionary[PlayerZombie, Tween]` (mirror `_melt_tweens`: erase on done; `_reset()` kills and frees them with the same untyped-loop + `is_instance_valid` guard the 6.4 review added for melts). Expose `get_shuffling_count()` and `get_shuffle_tween(view)` for tests. Look consts with a doc saying they are look values and 6.6 may replace them: `SHUFFLE_S = 0.3`, `SHUFFLE_PX = 8.0`.
  - [x] 3.2 New `scenes/levels/horde_rush/arrival_pop.tscn` + `scripts/levels/horde_rush/arrival_pop.gd` (`class_name HordeArrivalPop extends Node2D`). Do **not** instance `scenes/levels/zombie_run/brain_pop.tscn` (levels never import another level, architecture boundary 2); reuse the asset `res://assets/sprites/props/brain_pop.png` (16 × 16 frames, 2 frames, 8 fps, an `AnimatedSprite2D` %Sprite set up like `brain_pop.tscn`, origin = the brain's bottom centre) plus a `Label` %Amount beside or above it: font size 16 (NFR7), ink `Color(0.11764706, 0.078431375, 0.15686275, 1)` font colour like the target tag, `mouse_filter = 2`. Script: `func setup(brains: int) -> void` (call before `add_child`; sets `"+%d" % brains`), `_ready()` makes a node-bound tween that rises `RISE_PX` (16) over `RISE_TIME_S` (0.6) then `queue_free`; `get_tween()` for tests. Mirror `brain_pop.gd`'s doc style. If `brains <= 0` the level spawns no pop.
  - [x] 3.3 `scenes/levels/horde_rush/horde_rush_level.tscn`: add a `%Effects` `Node2D` after `%Projectiles` (drawn on top). `_spawn_pop(marcher, gained)`: instance, `setup(gained)`, `position = Vector2(arrive_x(scale), lane_feet_y(marcher.lane) - PlayerZombie.SIZE_PX * scale)` (above the copy's head at the house front; check it is not under the top-right pause button for lane 0, nudge with a layout const if needed), then `add_child` to `%Effects`. `_reset()` frees every child of `%Effects`. Preload the scene as a const.
- [x] **Task 4: Hitch cap** (AC: 5)
  - [x] 4.1 `_process(delta)`: after the bad-delta guard, `delta = minf(delta, MAX_FRAME_S)` with `const MAX_FRAME_S: float = 0.5` documented as robustness, not GDD ("a hitch longer than this is dropped: the field falls a little behind RunClock, invisible, and no burst of brains"). Keep the equal-step split (`0.5` stays exactly 15 steps).
  - [x] 4.2 Update the class doc paragraph about substeps accordingly.
  - [x] 4.3 `deferred-work.md`: mark the 6.3 "huge frame delta" item and the 6.4 cross-ref as resolved by 6.5 (append a short "Resolved in 6.5" line under them; do not delete history).
- [x] **Task 5: Run end** (AC: 6, 8)
  - [x] 5.1 `on_run_ending(_reason)`: if `_cfg == null` return `0.0`. If already frozen return `_cfg.outro_time_s` (idempotent like Zombie Run). Otherwise `_frozen = true`, `_defender_running = false`; free every projectile view and clear `_projectile_views` (closes the 6.4 review defer; the defender's logical flying projectiles stay as they are, nothing advances them); every marching copy's view: kill its flash tween, `modulate = Color.WHITE`, `view.dance(_cfg.outro_time_s)` (PlayerZombie already has `dance()`; it is node-bound and self-ending). Melts and shuffles already running finish. Return `_cfg.outro_time_s`.
  - [x] 5.2 The completion bonus is RunFrame's (it reads `config.completion_bonus` once at start and never adds it on quit); do not add the bonus inside the level and do not touch `run_frame.gd`, `run_result.gd`, `report_card.gd` or `player_data.gd`.
  - [x] 5.3 Update the class doc: arrivals (award, signal, voice, shuffle, pop), the outro, the cap, and "Still to come" now only 6.6 (Farmhouse, Farmer, tomato, flash/melt/arrival art, march music, spawn/throw/hit/melt sounds), 6.7 (tuning, parity, stress), 6.8 (unlocks).
- [x] **Task 6: Tests** (AC: 1–9)
  - [x] 6.1 `tests/unit/test_horde_rush_config.gd`: the shipped `.tres` has `completion_bonus == 25` and `outro_time_s == 2.0` (replace the `completion_bonus == 0` assert at ~line 53, "Story 6.5 sets the +25") and still validates; `validate()` rejects `outro_time_s` of 0, −1, INF and NAN with `"outro_time_s"` in the message; add `outro_time_s` to the in-test valid config builder so the existing per-case bad tests still isolate one problem each.
  - [x] 6.2 `tests/unit/test_horde_rush_level.gd` — set `_level.request_voice` to a recorder **before** `add_child` in `_make` (add a `_voices: Array[StringName]` field reset per test) so no test calls the live AudioManager. Replace `test_no_brains_yet` with: a small copy (`"cat"`) arriving pays 1, a medium (`"frog"`) pays 2 (and a brute `"rabbit"` pays 3, spawned through `on_target_completed` directly — brutes never spawn from the 3–5 band but the class exists); `watch_signals(_level)` → `brains_earned_changed` emitted once per arrival with the running totals `[1]`, `[3]`…; one `vo_brainsss` request per arrival; an `arrival_brains = 0` tweak pays 0, emits nothing, still requests the voice and spawns no pop. Keep `test_no_brains_when_copies_are_stopped` (rename to "a stopped copy earns nothing"; still 0). Update `test_arrival_frees_the_copy`: `get_view(0)` is null and `get_view_count() == 0` in the arrival step, `get_shuffling_count() == 1`, `custom_step` the shuffle tween past `SHUFFLE_S` → freed after a frame; an `%Effects` child exists (the pop) and its `get_tween().custom_step(RISE_TIME_S + 0.01)` frees it. A copy without a sprite (precedent: `test_a_stopped_copy_without_a_sprite_is_fine`) still pays. Hitch: `_process(10.0)` advances exactly as much logic as `_process(0.5)` (compare marcher `elapsed_s` and defender position); change `test_a_hitch_never_skips_a_throw`'s hitchy run from `2 × 2.0 s` to `8 × 0.5 s` (still 4 s total). Outro: after a copy is marching and a tomato is in the air, `on_run_ending(&"timer")` returns 2.0, `get_projectile_view_count() == 0`, the copy's view `is_dancing()`, a second call returns 2.0 and changes nothing, further `_process` calls change neither brains nor progress. Re-create: `create_target_source` again → brains 0, no shuffles, no `%Effects` children (after a frame). Update the file's header doc for 6.5. Remember the level is `PROCESS_MODE_DISABLED`: node-bound tweens move only with `custom_step`.
  - [x] 6.3 `tests/integration/test_run_frame.gd`: rename `test_horde_rush_end_freezes_and_pays_nothing_yet` → "...end_freezes_and_pays_the_bonus": `result.brains == 0` (no copy reached the house in 5 s; small crossing is 8 s) and `result.bonus_brains == 25`, `result.total_brains() == 25`. Add: (a) arrivals reach the result: through the frame the first key always starts the defender, so type a burst of words (e.g. 8) on a fixed seed, `watch_signals(level)`, drive `level._process(1.0 / 30.0)` for ~12 s of logic, and assert `level.get_brains_earned() > 0` — if the seed lets nothing through, pick another seed that does and pin it with a comment; then `debug_end_run()`, step `frame._process` past 2.0 s → DONE, and `result.brains == level.get_brains_earned()`, `result.bonus_brains == 25`, and the last `brains_earned_changed` parameter equals that total (the HUD receives it through RunFrame's connection). (b) quit: mirror `test_zombie_run_quit_commits_the_level_brains` for `horde_rush` with `_fake_player_data()` — wallet `+= level.get_brains_earned()`, no bonus, `run_history` size 0. The existing 6.3/6.4 Horde Rush cases must keep passing.
- [x] **Task 7: Verification and wrap-up** (AC: 8, 9)
  - [x] 7.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` (new `class_name HordeArrivalPop`), then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Re-count the baseline before starting (last recorded: 1490 after 6.4, plus any review-patch tests) and record before/after. Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 7.2 `grep` for global `randi(`/`randf(` in `scripts/levels/horde_rush/` stays clean.
  - [x] 7.3 Visual check (real window via Godot MCP `run_project` or a scratch capture script with a temp `SaveService` dir, as in 6.3/6.4 — never touch the real `user://save.json`; record its hash before/after): jump to Horde Rush from F3, type words until copies get through, capture (a) a copy shuffling in with its "+N" pop and the HUD counter above 0 (`screenshots/6-5/arrival-pop.png` + a 3× crop), (b) the outro with copies dancing and no tomatoes in the air (`outro.png`), (c) the report card showing the Horde Rush heading, brains and "+25 bonus" (`report-card.png`). Look for: the pop is readable (16 px, ink on sky) and not under the pause button; the shuffle reads as "went inside", not as vanishing; nothing scary (NFR10).
  - [x] 7.4 Commit the generated `.uid` files. No tag push. Horde Rush stays `available = false` (6.7 flips it).

## Dev Notes

### What this story is (and isn't)

- It is: the arrival award (brains, signal, throttled voice), the shuffle-in and "+N" brain pop placeholders, the run-end outro (copies dance, tomatoes cleared), the +25 bonus value and outro length in config, the hitch cap, tests.
- It isn't: Farmhouse/Farmer/tomato/flash/melt/arrival art, march music, spawn/throw/hit/melt sounds (6.6); tuning to 40%/70%, economy parity (NFR15, the GDD notes Horde Rush is ~30% under parity at 5–10 WPM — **do not change 1/2/3 or +25 here**), the 30-zombie stress check (6.7); unlocks (6.8). No save change, no changes to RunFrame, RunResult, the report card or PlayerData.

### What already works (do not rebuild it)

- **RunFrame** (`scripts/run/run_frame.gd`) already: reads `config.completion_bonus` once at start (`_completion_bonus`, line ~251) and puts it in `RunResult.bonus_brains` for every recorded run; on quit (`_quit_to_menu`, ~397) adds only `_level.get_brains_earned()` and records nothing (FR13); connects `_level.brains_earned_changed` to `%Hud.set_brains` (~263); waits the float `on_run_ending()` returns as the outro (`_outro_left`, ~366) and then opens the report card; builds the RunResult with `_session.get_implied_spaces()` so WPM includes implied spaces (FR7, Story 6.2); records on entering ENDING, so a close during the outro keeps the run.
- **Report card** (`scripts/screens/report_card.gd`) shows `total_brains()` and a "+N bonus" row only when `bonus_brains > 0`; the heading comes from the registry's `display_name` ("Horde Rush"); Play Again sends `{"level_id": _level_id}` with no seed.
- **HUD** resets the counter to 0 in `setup()` and shows whatever `set_brains(total)` receives.
- **AudioManager.play_voice** drops a voice inside `voice_min_gap_s` (8 s in `audio_library.tres`), before unlock, or for an unknown id; `vo_brainsss` exists (2 takes). That *is* the "throttled" in FR57.
- So the level's whole job for AC 6/7 is: return the right `get_brains_earned()`, emit the signal, return the outro length. And `horde_rush.tres` carries the +25.

### Design decisions already made (follow them)

- **Logic first, in the step.** The award happens inside `_logic_step` as `HordeField.advance` returns arrivals (march first, then defender — 6.4's order), before any sprite work. Never award from a tween callback or a sprite position.
- **Every arrival asks for the voice; no roll.** Zombie Run rolls 20% per brain from the run RNG; Horde Rush's GDD says only "throttled". Rolling would add a run-RNG consumer whose draw count depends on arrivals (which depend on the defender), and it is unnecessary: the 8 s gap already keeps it rare. Keeps 6.3's RNG order intact.
- **Emit only when something was paid.** `arrival_brains` may be 0 in a tuning config; then no emit and no pop (nothing changed), but the copy still shuffles in and the voice is still asked.
- **Hitch cap at 0.5 s.** 6.3/6.4 left "a huge delta arrives every copy at once" open for 6.5. Background tabs already pause the run (`visibility_hidden` → PAUSED), so a big delta is rare (window drag, GC stall). Dropping time beyond 0.5 s bounds both the brain burst and the step count (≤ 15 steps per frame); the field running a fraction behind `RunClock` is invisible. 0.5 keeps 6.4's `test_a_long_frame_is_split_into_substeps` (one 0.5 s frame = 15 steps) valid unchanged.
- **Outro = dance, like Zombie Run.** "A short outro plays" (FR57): marching copies dance in place for `outro_time_s` (2.0 s, same as FR36's dance so both levels end the same way), the defender stands still, tomatoes in the air vanish (a frozen tomato looks broken). It is config, not a literal.
- **Placeholders, palette only.** Shuffle = slide 8 px + squash x to 0 over 0.3 s (no fade, no glow: pixel-art rule); pop = the existing approved brain sprite plus a 16 px "+N" in ink. 6.6 replaces both with real art.

### Existing code to read first (current state → what changes → what must be preserved)

- **`scripts/levels/horde_rush/horde_rush_level.gd`** (UPDATE). Today: `_on_marcher_arrived` only frees the sprite and erases the flash tween; `get_brains_earned()` returns 0; `on_run_ending` freezes, stops the defender, idles copies and returns 0.0; `_process` substeps with no cap; `_reset` clears views, flashes, melts, tomatoes. Changes: `_brains`, `request_voice`, award in `_on_marcher_arrived`, shuffle/pop views, `MAX_FRAME_S`, the outro, `_reset` extensions, docs. Preserve: the step order (`_field.advance` then `_defender.advance`), RNG order (words, lanes; defender none), spawn in the key's own call, `get_view()` null once a copy arrived or stopped, scale-aware `spawn_x/arrive_x/march_x`, the null-view guards, `on_run_started` gating the defender, 6.4's melt/flash code.
- **`scripts/resources/horde_rush_config.gd`** + **`data/levels/horde_rush.tres`** (UPDATE): one field, one validate check, two values.
- **`scenes/levels/horde_rush/horde_rush_level.tscn`** (UPDATE): add `%Effects` after `%Projectiles`; bump `load_steps` only if you add ext/sub resources here (you shouldn't need to: the pop is preloaded in script).
- **`scripts/levels/zombie_run/zombie_run_level.gd`** (read only): the `request_voice` seam (`var request_voice: Callable`, defaulted in `_ready`), the award+emit pattern in `on_char_accepted`, the idempotent `on_run_ending` returning `dance_time_s`.
- **`scripts/levels/zombie_run/brain_pop.gd`** + `scenes/levels/zombie_run/brain_pop.tscn` (read only, do not instance): the self-freeing rise pattern and the sprite setup to copy into `arrival_pop`.
- **`scripts/characters/player_zombie.gd`** (read only): `dance(duration_s)`, `is_dancing()`, `get_dance_tween()`, `play_walk()`, `play_idle()`, `SIZE_PX`; origin at the feet; root scale/modulate carry Body and the hat.
- **`scripts/run/run_frame.gd`**, **`level_base.gd`**, **`report_card.gd`**, **`run_result.gd`** (no change; see "What already works").

### Architecture and rules to follow

- Godot **4.7.2** (standard), Compatibility renderer, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed dictionaries (`Dictionary[PlayerZombie, Tween]`), typed loop vars, except the documented untyped loop over a dictionary whose keys may be freed. Tabs. Short `##` docs that say why.
- "Logic leads, visuals chase": brains from `HordeField` arrivals only; one-shots self-free and never gate input; never `await` in level callbacks.
- No GDD number as a literal: 25, 2.0 and 1/2/3 live in `horde_rush.tres`. Look (`SHUFFLE_S`, `SHUFFLE_PX`, pop rise) and robustness (`MAX_FRAME_S`) values may be script consts with a doc saying so.
- Boundaries: the level never reads input, the clock or `PlayerData`, never imports another level's scenes; it may call `AudioManager` (through the seam).
- Entities: `preload` scenes as consts, set position/scale before `add_child`, free when done. No pooling (6.7 decides).
- Logging: nothing per frame or per arrival at info level. A `Log.debug(&"level", …)` per arrival is acceptable (like the 6.4 stop log).

### UX contract

- GDD Level 2 Arrival: "the zombie shuffles into the door → 'Brainsss' (throttled) → +brains pop." Win/loss table: "Always completed; brains = zombies that reached the house"; stopped copies "simply earn nothing".
- UX D15: the brain counter is in the HUD in every level and shows the level's local run total (architecture: fed by `brains_earned_changed`, never `PlayerData.brains_changed`).
- Pop text ≥ 16 px (NFR7), ink outline/colour from the shared palette, nothing in the top-right 40 × 40 (pause button). Copies in lane 0 have their heads near y 40: place the pop so it stays clear of x ≥ 600, y ≤ 40 (it is at x ≈ 532, so it is fine horizontally; still check the screenshot).
- Pillar 1 / NFR10: going "into the house" is goofy, not menacing — no screams, no villagers shown inside.

### Testing notes

- Run `--import` after adding the new `class_name`, before GUT.
- Drive the level with `_level._process(STEP)`; drive node-bound tweens with `tween.custom_step(t)` (the test level is disabled).
- A `queue_free`d node stays valid until the frame ends: assert through dictionary sizes / getters, or `await wait_process_frames(1)` before `is_instance_valid`.
- Never assign to the shipped `horde_rush.tres` in a test: use `_make(seed, tweak)` (deep duplicate) or `HordeRushConfig.new()`.
- The voice recorder must be set before `add_child` (else `_ready` binds the live `AudioManager`).
- Integration: `_fake_player_data()` and `_make(payload, null, data)` + `add_child_autofree(frame)` are the quit-test pattern; `_start(payload)` for the rest; `frame._process(t)` drives the clock and outro; the level's own `_process` must be called on `frame.get_level()` to march copies.

### Previous story intelligence (6.4)

- `HordeDefender`/`HordeProjectile` are pure; step order is field first, defender second; `_process` splits frames into equal steps ≤ 1/30 s. The defender only runs between `on_run_started()` and `on_run_ending()`; 6.3-style tests that never call `on_run_started()` have defender-free marches — use that for deterministic arrival tests.
- Review patches you must keep: erase `_flash_tweens` on arrival; untyped loop + `is_instance_valid` when resetting a dictionary keyed by possibly-freed views; integration tests reset `get_tree().paused` in `after_each`.
- Deferred to 6.5 (all closed by this story): the huge-delta burst/step count (deferred-work ~528, ~535) and tomatoes frozen mid-air after the end (~539).
- Feel note for 6.7: with the GDD defender numbers very few copies arrive (≈1% at 10 WPM, 20% at 40 WPM in 6.4's headless minute), so in a real 5:00 run brains will be low. That is expected here; do not tune. It also means integration/visual checks need several words (or no `on_run_started`) to see arrivals.
- Test count after 6.4: 1490 (plus review-patch tests; re-count).
- Lessons kept: edit story-file sections line-anchored; LF endings for new text files; record any Smuck decision verbatim with a date; never touch the real save in a visual check (hash before/after).

### Git intelligence

- One commit per story on `main`: `Story 6.5: arrivals, brains and run end`, then "Story 6.5: code review patches applied, done" after review.
- Expected changes: `scripts/levels/horde_rush/horde_rush_level.gd`, `scripts/levels/horde_rush/arrival_pop.gd` (new + `.uid`), `scenes/levels/horde_rush/arrival_pop.tscn` (new), `scenes/levels/horde_rush/horde_rush_level.tscn`, `scripts/resources/horde_rush_config.gd`, `data/levels/horde_rush.tres`, tests (`test_horde_rush_level.gd`, `test_horde_rush_config.gd`, `tests/integration/test_run_frame.gd`), screenshots under `screenshots/6-5/`, `deferred-work.md`, this file, `sprint-status.yaml`. Nothing in `scripts/autoloads/`, `scripts/typing/`, `scripts/run/`, `scripts/screens/`, `scripts/characters/`, `project.godot`, `export_presets.cfg`, `.github/`, `assets/`, `level_registry.tres`.

### Project Structure Notes

- The pop is a Horde Rush scene (`scenes/levels/horde_rush/`, script mirrored in `scripts/levels/horde_rush/`), reusing the shared prop asset `assets/sprites/props/brain_pop.png` — asset reuse, not a cross-level scene import (same rule 6.4 used for `villager_wave.png`).
- Known variance carried forward: a debug-jump Horde Rush run that ends writes a real `run_history` entry (6.3 defer, for 6.8's backfill). Unchanged here.

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md` (Logic Leads Visuals Chase ~783–836, Architectural Boundaries ~764, Entity Patterns, Configuration, brains-during-a-run rule ~235), the GDD (Level 2: Horde Rush ~308–325, win/loss table ~103, economy table ~268–271) and the UX spines (D15 brain counter, NFR7 text size) plus `docs/art-style-sheet.md` §5–6.
- Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, Godot MCP available (`run_project`, `get_debug_output`) for the visual check.

### Latest tech information

- No new libraries or engine features. Godot 4.7.2 notes: `Tween.set_parallel()` (or `tween.parallel()`) runs the shuffle's move and squash together; `Node.create_tween()` is node-bound (pauses with the tree, dies with the node); `Tween.custom_step()` advances a tween by hand; GUT `watch_signals(obj)` + `assert_signal_emit_count` / `get_signal_parameters(obj, name, index)` check the `brains_earned_changed` totals.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.5: Arrivals, Brains and Run End] (ACs); Stories 6.6–6.8 (consumers)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR7, FR13, FR14, FR48, FR57; NFR7, NFR10, NFR15
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Level 2: Horde Rush (~308–325), win/loss (~103), economy (~268–271), WPM (~130)
- [Source: _bmad-output/game-architecture.md] brains during a run (~235), Architectural Boundaries (~764), Logic Leads, Visuals Chase (~783–836)
- [Source: _bmad-output/implementation-artifacts/6-4-pacing-defender-projectiles-and-melting.md] design decisions, review findings
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] ~528, ~535, ~539
- [Source: scripts/levels/horde_rush/horde_rush_level.gd], [scripts/resources/horde_rush_config.gd], [data/levels/horde_rush.tres], [scripts/run/run_frame.gd:251,263,366,397-408,422-433], [scripts/levels/zombie_run/zombie_run_level.gd] (request_voice, award, on_run_ending), [scripts/levels/zombie_run/brain_pop.gd], [scripts/characters/player_zombie.gd:165], [scripts/screens/report_card.gd:83,140-170], [tests/unit/test_horde_rush_level.gd:21-50,146,227,503-545], [tests/unit/test_horde_rush_config.gd:53], [tests/integration/test_run_frame.gd:1073,1665]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Test baseline before the story: 1490 (matches the 6.4 record). After: 1505 passing, 0 failing, 82 scripts; no `Parse Error|Compile Error|Failed to load script` in the log.
- `grep` for global `randi(`/`randf(` in `scripts/levels/horde_rush/`: clean.
- Visual check: a scratch capture script (`tools/scratch_capture_6_5.gd`, deleted after use) ran the real RunFrame on `horde_rush` seed 7 in a real window with a temp `SaveService` dir (`user://scratch_6_5`, removed), typing 8 words at once, capturing the first arrival, then typing 6 more and ending with copies marching and a tomato in the air. Real `user://save.json` sha256 `c34c7559…761d` identical before and after both runs.

### Completion Notes List

- Config (Task 1): `HordeRushConfig.outro_time_s` (FR57) with a validate check appended last (`> 0` and finite, "outro_time_s must be above 0"); `horde_rush.tres` now has `completion_bonus = 25`, `outro_time_s = 2.0`. Size-class brains and defender numbers untouched (6.7 owns tuning).
- Arrivals (Task 2): `_on_marcher_arrived` awards `size_class.arrival_brains` to `_brains` inside the logic step before any visual, emits `brains_earned_changed(total)` only when it paid > 0, then asks `request_voice(&"vo_brainsss")` on every arrival (no roll, no RNG draw; the seam copies Zombie Run's). Then it erases the view, kills and erases the flash tween, spawns the pop and starts the shuffle. `get_brains_earned()` returns `_brains`; `_reset()` zeroes it.
- Views (Task 3): shuffle = node-bound parallel tween (+`SHUFFLE_PX` x, scale.x → 0 over `SHUFFLE_S`), tracked in `_shuffle_tweens` and freed on done; `_reset()` kills and frees them with the untyped-loop + `is_instance_valid` guard. New `HordeArrivalPop` (`arrival_pop.tscn/.gd`) reuses the `brain_pop.png` asset (no cross-level scene import) with a 16 px ink "+N" label; it rises 16 px over 0.6 s and frees itself. `setup()` stores the amount and `_ready()` applies it (no `await`). Pops go under the new `%Effects` node (after `%Projectiles`).
- Layout decision (story allowed a nudge): the "+N" sits to the left of the brain, not above it, and the pop's y is clamped at `POP_MIN_Y = 32` so a medium/brute pop in lane 0 never rises off the top of the screen. The pop is at x ≈ 532, well clear of the pause button (x ≥ 600). Screenshot: readable ink on lane green.
- Hitch cap (Task 4): `MAX_FRAME_S = 0.5` applied after the bad-delta guard; still split into equal steps (a 0.5 s frame stays 15 steps). Deferred items 6.3 (~528), 6.4 (~535) and the 6.4 review defer (~539) are marked resolved in `deferred-work.md`.
- Run end (Task 5): `on_run_ending` is idempotent (returns `outro_time_s` again on a second call, null config → 0.0), stops the defender, frees every projectile view, kills flash tweens and makes every marching copy dance for `outro_time_s`. No changes to RunFrame/RunResult/report card/PlayerData: the +25 comes from config through RunFrame's existing path, never on quit.
- Tests (Task 6): config (+25, 2.0, four bad outro cases); level (+13 tests: per-class pay 1/2/3 with running signal totals and one voice per arrival, award before visuals, a free arrival emits nothing and has no pop but still asks the voice and shuffles, pop text/position, lane-0 clamp, sprite-less copy still pays, arrival kills a running flash, nothing pays after the end, shipped bonus/outro, outro clears tomatoes and dances, second end changes nothing, end clears a flash, cap = 0.5 s of logic, no brain burst on a 30 s hitch, re-create clears brains/shuffles/pops; updated the arrival, freeze and hitch tests); integration (+2: arrivals reach the HUD counter and the RunResult with the +25 on seed 7 (8 instant words, 12 s of logic); a quit keeps the arrival brains with no bonus and no history; existing Horde Rush cases updated for the 2 s outro and the +25).
- Visual check (7.3): `arrival-pop.png` (+3× crop) shows a copy squashing into the door with "+2" and the HUD counter at 2; `outro.png` (+3× crop) shows six copies dancing and no tomato (1 in the air just before the end, 0 after); `report-card.png` shows "Horde Rush", Brains Collected 27 and "+25 bonus". Nothing scary (NFR10).
- Horde Rush stays `available = false`; `level_registry.tres` untouched.

### File List

- `scripts/levels/horde_rush/horde_rush_level.gd` (modified)
- `scripts/levels/horde_rush/arrival_pop.gd` (new)
- `scripts/levels/horde_rush/arrival_pop.gd.uid` (new)
- `scenes/levels/horde_rush/arrival_pop.tscn` (new)
- `scenes/levels/horde_rush/horde_rush_level.tscn` (modified)
- `scripts/resources/horde_rush_config.gd` (modified)
- `data/levels/horde_rush.tres` (modified)
- `tests/unit/test_horde_rush_level.gd` (modified)
- `tests/unit/test_horde_rush_config.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/screenshots/6-5/arrival-pop.png`, `arrival-pop-3x.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/6-5/outro.png`, `outro-3x.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/6-5/report-card.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/6-5-arrivals-brains-and-run-end.md` (this file)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)

### Review Findings

- [x] [Review][Patch] `on_run_ending` dances views without `is_instance_valid`, so a view freed externally crashes the outro; `_on_shuffle_done` and `_reset` shuffle bookkeeping also assume the view is alive [scripts/levels/horde_rush/horde_rush_level.gd:271]
- [x] [Review][Patch] `_shuffle_in` tweens from the stale `view.position.x` of the previous frame (up to ~30 px off after a capped 0.5 s frame), while the pop sits at `arrive_x`; start the shuffle from `arrive_x` [scripts/levels/horde_rush/horde_rush_level.gd:493]
- [x] [Review][Defer] Frame cap drops hitch time from the field while RunClock keeps counting, so arrivals depend on hitches [scripts/levels/horde_rush/horde_rush_level.gd:350] — deferred, spec-mandated by AC5; revisit in 6.7 economy parity
- [x] [Review][Defer] Integration test relies on magic `HORDE_ARRIVAL_SEED = 7` and real RNG for "some copies got past" [tests/integration/test_run_frame.gd] — deferred, brittle but works today; revisit when 6.7 retunes the defender
- [x] [Review][Defer] Simultaneous pops in the same lane stack at the identical point and overlap [scripts/levels/horde_rush/horde_rush_level.gd:520] — deferred, cosmetic; fix with jitter if playtest shows it

## Change Log

- 2026-10-07: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-07: Implemented arrival brains (award, HUD signal, throttled "Brainsss" seam), shuffle-in and "+N" pop placeholders, the hitch cap, the dancing outro with tomatoes cleared, +25 bonus and 2 s outro in config; 15 new tests (1505 passing), screenshots. Status → review.
