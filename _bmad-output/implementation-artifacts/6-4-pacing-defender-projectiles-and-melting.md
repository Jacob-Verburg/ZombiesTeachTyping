---
baseline_commit: ac148325bc19e389b98154f37f50714e1e293ba0
---

# Story 6.4: Pacing Defender, Projectiles and Melting

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want a silly defender who throws tomatoes at my zombies,
so that there's a goofy challenge to beat with fast typing.

## Acceptance Criteria

1. **Pacing (FR56).** Given the defender in front of the house, when the run is running (from `on_run_started()` until `on_run_ending()`), then it paces continuously at 1 lane per `defender_lane_time_s` (0.6 s in `horde_rush.tres`) and reverses at the top and bottom lanes. It starts on the top lane (lane 0) heading down. Before the first key, while the tree is paused (PAUSED, COUNTDOWN) and after `on_run_ending()` it does not move.
2. **Throwing.** Given the defender is level with a lane (its lane = `roundi(position)`) that has at least one marching zombie, when its cooldown allows (`defender_throw_cooldown_s`, 0.8 s; ready at run start), then it throws one projectile down that lane, aimed at the front-most zombie there (highest progress), and the cooldown restarts. A projectile flies at a speed of one whole field per `projectile_cross_time_s` (1.0 s) and stays in the lane it was thrown into.
3. **Hits (FR56).** Given a projectile meets a zombie (logical contact: the projectile's field position has reached the front-most marching zombie in its lane), when it hits, then that zombie loses one hit and flashes red for `hit_flash_s` (0.15 s). On its final hit (`hits_left` reaches 0) it stops at once (it never marches again and can never arrive), falls and melts into the ground over `melt_s` (0.6 s), then its sprite is freed. It earns nothing. A projectile that reaches the left edge without meeting a zombie is a miss and is freed.
4. **Logic, not sprites.** Hits, contact and targeting use logical positions only (`HordeMarcher.progress()` and the projectile's field position in the same 0..1 units), never sprite positions. Every GDD number above lives in `horde_rush.tres`, never as a literal in a script.
5. **Step order (deterministic).** Each logic step runs in this order: (1) march (`HordeField.advance`, arrivals removed first, so a copy that reaches the house in a step is safe), (2) projectiles move and land, in throw order, (3) the defender paces and its cooldown ticks, (4) it throws if it can. The level splits a long frame into steps of at most `MAX_STEP_S` so a hitch never skips a throw.
6. **Headless determinism.** Given the defender logic with a fixed lane seed and a fixed spawn schedule, when a headless simulation runs (pure `HordeField` + `HordeDefender`, no nodes), then pacing, targeting, throw, hit, stop and arrival counts are identical on every run, and unit tests pin them.
7. **No regressions.** Brains stay 0 and `completion_bonus` stays 0 (Story 6.5); the 6.3 march, spawn, arrival, freeze, pause and seed-replay behaviour is unchanged; Horde Rush is still `available = false`. No sounds yet (6.6).
8. **Tests.** GUT covers the config fields and their `validate()` checks, `HordeDefender` (pacing positions and reversal, one-lane field, cooldown, front-most targeting, flight time, multi-hit stops, overtaking, misses, arrival-before-hit tie, determinism), the new `HordeField` hit/stop API, and the level (defender idle until the run starts, a throw creates a projectile view, flash on a non-final hit, melt then free on the final hit, end freezes the defender and projectiles, re-create resets). Full suite green.

## Tasks / Subtasks

- [x] **Task 1: Config numbers** (AC: 1, 2, 3, 4)
  - [x] 1.1 `scripts/resources/horde_rush_config.gd`: add `@export var defender_lane_time_s: float = 0.0` (seconds to pace one lane), `defender_throw_cooldown_s: float = 0.0`, `projectile_cross_time_s: float = 0.0` (seconds for a projectile to fly the whole field), `hit_flash_s: float = 0.0`, `melt_s: float = 0.0`, each with a short `##` doc naming FR56. Neutral defaults, real values only in the `.tres`.
  - [x] 1.2 `validate()`: append checks after the existing ones (keep the existing messages and order; tests assert them): `defender_lane_time_s`, `defender_throw_cooldown_s` and `projectile_cross_time_s` must be `>= MIN_CROSSING_TIME_S` and finite; `hit_flash_s` and `melt_s` must be `>= 0` and finite (0 = no flash / instant melt, still valid).
  - [x] 1.3 `data/levels/horde_rush.tres`: `defender_lane_time_s = 0.6`, `defender_throw_cooldown_s = 0.8`, `projectile_cross_time_s = 1.0`, `hit_flash_s = 0.15`, `melt_s = 0.6`. These are the GDD starting values; Story 6.7 tunes them. Do not tune here.
- [x] **Task 2: Field hit API** (AC: 3, 4, 5)
  - [x] 2.1 `horde_marcher.gd`: add `func is_stopped() -> bool: return hits_left <= 0`. Update the class doc ("6.4 adds the stopped state" becomes what it now is). A stopped marcher's `elapsed_s` is never advanced again.
  - [x] 2.2 `horde_field.gd`: add `func hit(marcher: HordeMarcher) -> bool` — ignores a marcher that is not in `_marching` (returns false, no change); otherwise `hits_left -= 1`; at 0 it is removed from `_marching`, `_stopped += 1`, and returns true (stopped). Add `func get_stopped_count() -> int`. Invariant to keep (and test): `spawned == marching + arrived + stopped`.
  - [x] 2.3 `horde_field.gd`: add `func front_most_in_lane(lane: int, at_or_past: float = -INF) -> HordeMarcher`: among marching copies in `lane` with `progress() >= at_or_past`, the one with the highest progress; ties go to the lower `id`; null when none. Used both for aiming and for contact. No allocation-heavy work (iterate `_marching` directly, don't call `get_marching()`).
  - [x] 2.4 Leave `advance()`'s signature, return value and behaviour exactly as 6.3 shipped them (all 6.3 field tests must pass untouched).
- [x] **Task 3: Pure defender model** (AC: 1, 2, 3, 4, 5, 6)
  - [x] 3.1 `scripts/levels/horde_rush/horde_projectile.gd`: `class_name HordeProjectile extends RefCounted`: `id: int` (per run, throw order from 0), `lane: int`, `position: float` (field units, 1.0 = the house line where the defender throws, 0.0 = the left edge), `aimed_at: HordeMarcher` (the front-most copy when thrown; for debug/tests only — contact decides what it hits), `hit_marcher: HordeMarcher` (set when it lands on a copy; null for a miss), `stopped_marcher: bool` (that hit was the final one). No nodes.
  - [x] 3.2 `scripts/levels/horde_rush/horde_defender.gd`: `class_name HordeDefender extends RefCounted`. `_init(config: HordeRushConfig)`. State: `_travel: float` (lanes paced since the start), `_cooldown_left_s: float = 0.0`, `_flying: Array[HordeProjectile]`, counters. `func position() -> float`: `pingpong(_travel, config.lane_count - 1)` (Godot's `pingpong()`; with one lane the length is 0 and it stays at 0). `func current_lane() -> int: return roundi(position())`. `func is_heading_down() -> bool` (for the view's facing later; derive from `_travel`, no extra state).
  - [x] 3.3 An inner `class Step extends RefCounted` with `thrown: Array[HordeProjectile]` and `landed: Array[HordeProjectile]` (hits and misses, in throw order). `func advance(delta: float, field: HordeField) -> Step`: a zero, negative or non-finite delta returns an empty Step and changes nothing. Otherwise, in this order: (a) every flying projectile `position -= delta / projectile_cross_time_s`; then `field.front_most_in_lane(lane, position)` — if one exists it is hit (`field.hit`), recorded on the projectile, and the projectile lands; else if `position <= 0.0` it lands as a miss; (b) `_cooldown_left_s -= delta`, `_travel += delta / defender_lane_time_s`; (c) if `_cooldown_left_s <= TIME_EPSILON_S` and `field.front_most_in_lane(current_lane())` is not null, throw: a new projectile at `position = 1.0` in that lane (it does not move until the next step), `_cooldown_left_s = defender_throw_cooldown_s`. At most one throw per step.
  - [x] 3.4 `TIME_EPSILON_S = 1e-4` (a float-sum tolerance like `HordeMarcher.ARRIVE_EPSILON_S`, not a GDD number) so 48 steps of 1/60 meet a 0.8 s cooldown on the 48th step. Getters: `get_flying() -> Array[HordeProjectile]` (copy, throw order), `get_thrown_count()`, `get_hit_count()`, `get_miss_count()`.
  - [x] 3.5 Keep it pure: no nodes, no autoloads except `Log`, no RNG at all (the defender is fully deterministic; the only randomness in a run is the words and the lanes). No pixels. This is the model 6.7's headless 10/30 WPM simulation drives, so document the step order (AC 5) in the class doc: "march first (`field.advance`), then `defender.advance`".
- [x] **Task 4: The level** (AC: 1–5, 7)
  - [x] 4.1 `horde_rush_level.gd` `create_target_source`: after building `_field`, build `_defender = HordeDefender.new(_cfg)`. RNG order is unchanged (words first, lanes second; the defender takes no RNG). `_reset()` also frees projectile views and melting copies, clears `_defender_running`.
  - [x] 4.2 `on_run_started()` (new override): `_defender_running = true`. The defender view starts walking.
  - [x] 4.3 `_process(delta)`: keep the 6.3 guard (`_field == null or _frozen` → return). Split `delta` into steps of at most `MAX_STEP_S` (`1.0 / 30.0`, a robustness const, not GDD) and run `_logic_step(dt)` for each; then update every view once (copies' x from progress as in 6.3, projectile views' x/y, the defender view's y). `_logic_step(dt)`: `for m in _field.advance(dt): _on_marcher_arrived(m)` (unchanged), then if `_defender_running`: `var step := _defender.advance(dt, _field)`; for each thrown → `_add_projectile_view(p)`; for each landed → free its projectile view, and if `p.hit_marcher != null`: `_on_marcher_stopped(m)` when `p.stopped_marcher`, else `_flash(view)`. Never read a sprite position for logic. Leave `process_mode` inherited (the tree pause must freeze everything).
  - [x] 4.4 `_flash(view)`: hard flash, no fade (pixel-art rule: no soft effects): `view.modulate = HIT_FLASH_MODULATE`, then a node-bound `view.create_tween()` that waits `_cfg.hit_flash_s` and sets `modulate` back to `Color.WHITE`. Keep one flash tween per copy in `_flash_tweens: Dictionary[int, Tween]` (by marcher id) and kill the old one on a new hit. `HIT_FLASH_MODULATE` is a look const (e.g. `Color(1.0, 0.45, 0.4)`), documented as a placeholder tint: stamp red is reserved and tomatoes are pumpkin (DESIGN.md D16, style sheet §5), and Story 6.6 owns the final red-flash effect.
  - [x] 4.5 `_on_marcher_stopped(m)`: erase the copy from `_views` (and its flash tween; kill it) and hand it to the melt: `view.play_idle()`, `view.modulate = Color.WHITE`, then a node-bound tween over `_cfg.melt_s` that squashes it into the ground (origin is at the feet: `scale.y` → 0 and `scale.x` → about 1.3× its class scale, a puddle) and frees it at the end (`tween_callback(view.queue_free)`). Track it in `_melting: Array[PlayerZombie]` (removed when freed) and expose `get_melting_count()` and `get_melt_tween(view)` or similar for tests. It is a self-freeing one-shot: nothing waits for it, it never gates input. With `melt_s == 0` free it at once. Doc: "Story 6.6 replaces the squash with the melt art."
  - [x] 4.6 `on_run_ending`: also stop the defender (`_defender_running = false`, the defender view idles). The existing `_frozen` already stops `_process`, so projectiles freeze in the air and nothing lands after the end. Melts and flashes already running may finish (they are visual one-shots). Still return `0.0`; `get_brains_earned()` still `0`.
  - [x] 4.7 Views. Defender placeholder (6.6 draws the Farmer): a `Sprite2D` (or a small `Node2D` + `Sprite2D`) named `Defender` (unique) under `%Zombies` so it y-sorts with the copies, origin at its feet: texture `res://assets/sprites/characters/villager/villager_wave.png` as an `AtlasTexture` of frame 0 (32 × 32, region `Rect2(0, 0, 32, 32)`), `offset`/position so its feet sit on the origin like the zombie (Body at (-16, -31) pattern), flipped if needed so it faces the zombies (left) — check in the screenshot. Its feet x is `DEFENDER_X = 520.0` (mock frame B draws the farmer at x 512–532, in front of the house wall at 548) and its feet y is `defender_feet_y(_defender.position())`, a float version of `lane_feet_y` (add `lane_feet_y_at(lane_pos: float)` and have `lane_feet_y(int)` call it). A reused existing human sprite keeps the placeholder palette-only and kid-safe; no new texture.
  - [x] 4.8 Projectile placeholder (6.6 draws the tomato): `scenes/levels/horde_rush/tomato.tscn`, root `Node2D` "Tomato" with two `ColorRect`s centred on the origin: an ink `#1E1428` 6 × 6 edge and a pumpkin `#F07A1C` 4 × 4 fill (`mouse_filter = 2` on both). No script. `preload` it as a const; `_add_projectile_view` sets `position` before `add_child` to a new `%Projectiles` Node2D (sibling after `%Zombies`, drawn on top). View x = `march_x(p.position)` (scale 1, so a tomato starts at 532, the farmer's hand, and visually lands inside the copy it hits); y = `lane_feet_y(p.lane) - TOMATO_RISE_PX` (about 14, chest height). `_projectile_views: Dictionary[int, Node2D]` by projectile id; getters `get_projectile_view_count()`, `get_defender() -> HordeDefender`, `get_defender_view() -> Node2D`.
  - [x] 4.9 Update the level class doc: the defender (pure `HordeDefender`, no RNG), the step order, what's placeholder, and "Still to come" (6.5 arrivals/brains/outro, 6.6 Farmer, tomato, flash and melt art plus throw/hit/melt sounds).
- [x] **Task 5: Tests** (AC: 1–8)
  - [x] 5.1 `tests/unit/test_horde_rush_config.gd`: the shipped `.tres` has 0.6 / 0.8 / 1.0 / 0.15 / 0.6 and still validates; `validate()` catches a zero/negative/INF `defender_lane_time_s`, `defender_throw_cooldown_s`, `projectile_cross_time_s`, and a negative `hit_flash_s` / `melt_s`, each with its expected message (as the existing per-case test does); `hit_flash_s = 0` and `melt_s = 0` are valid. Add the new fields to the test's in-test valid config builder so existing bad-case tests still isolate one problem each.
  - [x] 5.2 `tests/unit/test_horde_field.gd` (extend): `hit()` decrements; a 2-hit medium needs 2; the final hit removes it from `get_marching()`, bumps `get_stopped_count()` and it never arrives however long you advance; hitting a marcher not in the field (arrived, already stopped, from another field) returns false and changes nothing; `spawned == marching + arrived + stopped` after a mixed sequence; `front_most_in_lane` picks the highest progress, ties to the lower id, respects `at_or_past`, null for an empty lane.
  - [x] 5.3 `tests/unit/test_horde_defender.gd` (new; config built in-test with round numbers, 5 lanes, the GDD defender numbers; drive with a helper `_run(seconds)` that calls `field.advance(STEP)` then `defender.advance(STEP, field)` with `STEP = 1.0 / 60.0`):
    - pacing: `position()` is 0 at the start, 0.5 at 0.3 s, 1.0 at 0.6 s, 4.0 at 2.4 s (bottom), 3.0 at 3.0 s (reversed), back to 0 at 4.8 s; `current_lane()` follows `roundi`; a 1-lane config stays at 0; a zero delta changes nothing.
    - no throw into an empty lane; a copy in lane 0 at the start is thrown at on the first step; the next throw comes no earlier than 0.8 s later (count steps) even with copies in every lane.
    - flight: a stationary-equivalent check — a small copy at progress p in lane 0 is hit after about `(1 - p) / (1/1.0 + 1/8.0)` s (within one step); a projectile thrown into a lane keeps its lane after the defender moves on.
    - a small copy is stopped by 1 hit, a medium by 2; a stopped copy is out of the field and never arrives.
    - overtaking/contact: with two copies in one lane, the projectile hits whichever is front-most at contact, not the one it was aimed at if that changed; an extra projectile into a lane whose copy was already stopped flies on and hits the next copy behind it, or lands as a miss at the left edge (`get_miss_count()`).
    - tie rule: a copy that arrives in the same step a projectile would reach it is an arrival, not a hit (march runs first).
    - determinism: a 60 s headless run (spawn a fixed word list on a fixed schedule, e.g. one word every 2.5 s, lane seed 7) gives the same thrown/hit/miss/stopped/arrived counts and the same sequence of (step index, lane, hit id) twice; a different lane seed gives a different sequence. Pin the seed-7 counts as literals in the test once observed (record them in the Debug Log), so a later change to the step order shows up.
    - never touches the global RNG (seed global, run, compare, restore global state — as `test_horde_field.gd::test_independent_of_the_global_rng`).
  - [x] 5.4 `tests/unit/test_horde_rush_level.gd` (extend; reuse `_make`, `_type_word`, `_steps`; call `_level.on_run_started()` where the defender should run): the defender view exists under `%Zombies` at `DEFENDER_X` and lane 0's feet y; without `on_run_started()` the defender never moves or throws (the existing 6.3 tests keep passing because of this — do not add `on_run_started()` to them); after it, a copy in the defender's lane gets a projectile view in the step it is thrown and the view count drops when it lands; a non-final hit sets `modulate` to the flash tint and the copy keeps marching (custom_step its flash tween past `hit_flash_s` → white); a final hit removes the copy from `get_view(id)` at once, `get_melting_count() == 1`, and custom_stepping the melt tween past `melt_s` frees it; `on_run_ending` freezes the defender position and every projectile view; `create_target_source` again clears projectiles, melts and the running flag; `get_brains_earned()` is still 0 after copies are stopped; a single `_process(0.5)` gives the same logic state (defender position, throws, hits, progress, within float tolerance) as 15 calls of `_process(1.0 / 30.0)` (substepping). Remember the test level is `PROCESS_MODE_DISABLED`, so node-bound tweens only move with `custom_step` (precedent: `test_brain_block.gd:141`).
  - [x] 5.5 `tests/integration/test_run_frame.gd`: the two 6.3 Horde Rush cases must still pass unchanged. Add one: start `{"level_id": &"horde_rush", "seed": 7}`, type a word, `await` a short real wait (or drive `level._process` steps) and check the defender has moved off position 0 after the first key and does not move while `pause_tree` has paused the tree (use the existing pause helpers); `debug_end_run()` → `RunResult.brains == 0`.
- [x] **Task 6: Verification and wrap-up** (AC: 7, 8)
  - [x] 6.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` (new `class_name`s), then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Re-count the baseline before starting (last recorded: 1439 after the 6.3 review patches) and record before/after. Grep the log for `Parse Error|Compile Error|Failed to load script` (GUT skips a broken script and still exits 0).
  - [x] 6.2 `grep` for global `randi(`/`randf(` in `scripts/levels/horde_rush/` stays clean.
  - [x] 6.3 Visual check (real window via Godot MCP `run_project` or a scratch capture script with a temp save dir, as in 6.3 — never touch the real `user://save.json`): jump to Horde Rush from F3, type several words, capture (a) the defender mid-pace with a tomato in the air (`screenshots/6-4/defender-throw.png`), (b) a copy flashing (`hit-flash.png`), (c) a melt mid-way (`melt.png`). Look for: the farmer stand-in faces left and doesn't cover the pause button; tomatoes fly along the lane at chest height and vanish inside the copy they hit; the flash reads as "hit" and isn't scary; the melt reads as goofy squash, not injury (NFR10).
  - [x] 6.4 Record a quick feel note (not tuning): roughly how many copies get through when you type at your normal speed for a minute. This is input for 6.7, which owns the 40%/70% targets — do not change the numbers here.
  - [x] 6.5 `deferred-work.md`: add new items only if found (e.g. if the long-frame substep reveals anything for 6.5's arrival burst note at ~line 528, cross-reference it). Commit the generated `.uid` files. No tag push.

## Dev Notes

### What this story is (and isn't)

- It is: the defender's pure logic (`HordeDefender`, `HordeProjectile`), hit/stop on the field (`HordeField.hit`, `front_most_in_lane`, stopped count), the config numbers, the level wiring (step order, substeps, placeholder defender/tomato views, red flash, squash-melt, freeze at end), tests.
- It isn't: arrival brains, shuffle-in, "Brainsss", `brains_earned_changed`, the +25 bonus, the outro (6.5); the Farmhouse/Farmer art, throw animation, tomato sprite, final flash/melt art, march music, throw/hit/melt sounds (6.6); tuning to 40%/70% and economy parity, the 30-zombie stress check (6.7); unlocks (6.8). No save change, no audio, no new textures, no `AudioManager` calls.

### Design decisions already made (follow them)

- **One pure step, two objects.** `HordeField` stays the march model (6.3 API unchanged); `HordeDefender` is the defender + its projectiles and acts on the field through `hit()` and `front_most_in_lane()`. The level and 6.7's headless sim both call `field.advance(dt)` then `defender.advance(dt, field)`. That is the whole step order; no other code may change field state.
- **Everything in field units.** A copy's position is `progress()` (0 = left edge, 1 = house line). The defender throws from 1.0 and the projectile moves left at `1 / projectile_cross_time_s` per second, so "the projectile takes 1.0 s to cross the field" (GDD) is literally true. Because it starts at the house line and every copy is short of it, a throw always meets its lane's front copy before that copy could arrive (continuous time); only frame quantisation can make them meet in the same step, and then march-first makes it an arrival (kid-friendly tie rule).
- **Contact decides, not aim.** A projectile flies down a lane and hits the first copy it reaches (the front-most at contact). A small copy (8 s) can overtake a medium (10 s) in the same lane, so the copy hit may differ from the one aimed at; that's correct and looks right. `aimed_at` is kept only for debugging and tests.
- **No overkill avoidance.** The GDD says the defender throws at the front-most zombie whenever its lane has one and the cooldown allows. It does not skip lanes where tomatoes already in the air will stop every copy. A spare tomato flies on and hits the next copy or misses. That's the literal rule, it is goofy, and it keeps the defender a bit weaker. If 6.7's tuning needs a smarter defender, that's a new config flag there, not here.
- **"Level with a lane" = `roundi(position)`.** With continuous pacing the defender is never exactly on a lane. Rounding gives each lane visit the same 0.6 s window (the edge lanes get one 0.6 s visit per 4.8 s cycle, the middle lanes two). Cooldown 0.8 s > 0.6 s, so at most one throw per visit at the GDD numbers.
- **Pacing by `pingpong`.** Store only `_travel` (lanes paced). `position = pingpong(_travel, lane_count - 1)` handles any number of reversals in one step and has no direction state to drift.
- **Defender only while running.** It stands still before the first key (AC: "when the run is running"); `on_run_started()` starts it, `on_run_ending()` stops it, the tree pause freezes it. The 6.3 tests never call `on_run_started()`, which keeps their marches defender-free on purpose.
- **Substeps, no cap.** `_process` splits long frames into steps of at most 1/30 s, so a background-tab hitch can't skip a throw or a contact. Total time is not capped: the march must stay in step with `RunClock`. The deferred "huge delta pays a burst of brains" item (deferred-work ~line 528) stays with 6.5.
- **Placeholders, palette only.** Defender = the existing villager sprite (a human, palette-only, approved art) as a stand-in; tomato = two `ColorRect`s in ink and pumpkin (stamp red is reserved, tomatoes are pumpkin: DESIGN.md D16, style sheet §5); flash = a hard modulate tint for 0.15 s (no fade, no glow); melt = squash into a puddle at the feet. 6.6 replaces all four. Defeat stays melting, never injury (NFR10).
- **No defender RNG.** The defender is deterministic. Seeds only change words and lanes, so replay (AC 7 of 6.3) still holds and the 6.3 RNG order is untouched.

### Existing code to read first (current state → what changes → what must be preserved)

- **`scripts/levels/horde_rush/horde_rush_level.gd`** (UPDATE). Today: validates config, seeds words then lanes, spawns a marcher + `player_zombie.tscn` copy in `on_target_completed`, `_process` advances the field and sets copy x from `march_x(progress, scale)`, `_on_marcher_arrived` frees the sprite, `on_run_ending` freezes and idles copies, `_reset` on re-create. Changes: `_defender`, `on_run_started`, substepped `_logic_step`, projectile/defender/melt views, flash, `_reset` and `on_run_ending` extensions, doc. Preserve: RNG order, spawn in the key's call (no await), the 6.3 getters and their meaning (`get_view` is null once a copy is stopped too), `_on_marcher_arrived` as one small method for 6.5 to replace, scale-aware `spawn_x/arrive_x/march_x`.
- **`scripts/levels/horde_rush/horde_field.gd`**, **`horde_marcher.gd`** (UPDATE, additive only). `advance()` unchanged; add `hit`, `front_most_in_lane`, `get_stopped_count`, `is_stopped`.
- **`scripts/resources/horde_rush_config.gd`** + **`data/levels/horde_rush.tres`** (UPDATE): add five fields, append validate checks, set values.
- **`scenes/levels/horde_rush/horde_rush_level.tscn`** (UPDATE): add `Defender` under `%Zombies` and a `%Projectiles` Node2D after `%Zombies`; bump `load_steps` for the new ext/sub resources.
- **`scripts/characters/player_zombie.gd`** (read only): origin at the feet, `play_idle()`/`play_walk()`; the `HatSlot` is under Body, so modulating or scaling the copy's root takes the hat along. Don't add flash/melt methods here; keep them in the level (only Horde Rush needs them).
- **`scripts/levels/zombie_run/poof.gd`** (read only): the self-freeing one-shot + node-bound tween + `get_tween()` for `custom_step` tests pattern.
- **`scripts/run/run_frame.gd`** (no change): `on_run_started` is called on the first correct key after RUNNING; the tree is not paused in WAITING_FIRST_KEY (so `_process` runs there — the defender must check `_defender_running`), it is paused in PAUSED/COUNTDOWN, and `on_run_ending` is called on entering ENDING.
- **`scripts/run/level_base.gd`** (read only): `on_run_started()` is a no-op hook you now override.

### Architecture and rules to follow

- Godot **4.7.2** (standard), Compatibility renderer, GDScript only, GUT **9.7.1**. Static typing everywhere (`untyped_declaration` is an Error): typed arrays (`Array[HordeProjectile]`), typed dictionaries (`Dictionary[int, Node2D]`, `Dictionary[int, Tween]`), typed loop vars. Tabs. Short `##` docs that say why.
- "Logic leads, visuals chase": hits and arrivals from logical values only; one-shot effects self-free and never gate input; never `await` in level callbacks.
- No GDD number as a literal in a script: 0.6 / 0.8 / 1.0 / 0.15 / 0.6 live in `horde_rush.tres`. Layout (`DEFENDER_X`, `TOMATO_RISE_PX`), look (`HIT_FLASH_MODULATE`, the puddle spread) and robustness (`MAX_STEP_S`, `TIME_EPSILON_S`) values may be script consts with a doc saying so.
- Boundaries: the level never reads input, the clock or `PlayerData`; the defender and field are pure (no nodes, no autoloads but `Log`, no global RNG).
- Entities: `preload` scenes as consts, set position/scale before `add_child`, free when done. No pooling (6.7 decides after the stress check).
- Logging: nothing per frame. One `Log.debug(&"level", …)` per stop is fine behind nothing; don't log per throw.

### UX contract

- Mock `ux-designs/.../mockups/key-run-hud.html` frame B: the farmer stands in front of the house (about x 512–532, house wall from 548), copies walk the 5 lanes, the thrown tomato is drawn in pumpkin orange because stamp red is reserved.
- GDD Level 2: "Hit → the zombie flashes red for 0.15 s. Final hit → it falls and melts into the ground over 0.6 s." Pillar 1: all violence is cartoon; defeat is melting. A stopped copy "simply earns nothing" (GDD win/loss table) — no sad sound, no penalty, no counter.
- Keep the top-right 40 × 40 clear (HUD pause button); the defender at lane 0 has its head at about y 43, below it.

### Testing notes

- Run `--import` after adding the new `class_name` scripts, before GUT.
- Drive the level with `_level._process(STEP)` directly (the test level is `PROCESS_MODE_DISABLED`); drive node-bound flash/melt tweens with `tween.custom_step(t)`.
- A `queue_free`d view stays valid until the frame ends: assert through `get_view(id) == null`, `get_projectile_view_count()`, `get_melting_count()` (dictionary/array entries are updated in the same call), or `await wait_frames(1)` before `is_instance_valid`.
- Never assign to the shipped `horde_rush.tres` in a test: `duplicate(true)` it (the `_make(tweak)` helper already does) or build `HordeRushConfig.new()`.
- Pin exact expectations with round numbers in in-test configs (1 lane per 1.0 s, cooldown 2.0 s, cross time 1.0 s) where the GDD numbers make hand-checks awkward, and keep one test on the real numbers.

### Previous story intelligence (6.3)

- `HordeField`/`HordeMarcher` are pure RefCounteds advanced in seconds; `ARRIVE_EPSILON_S = 1e-4` lives on `HordeMarcher`; `progress()` returns 1.0 once arrived. 6.3 review patches: scale-aware `spawn_x/arrive_x` (medium spawns at 20, arrives at 528), re-create resets state, null-view guard (a marcher can exist without a sprite — your hit/melt code must tolerate a missing view), stricter `validate()` with per-case messages asserted in tests, `test_horde_rush_level.gd` already has a pause-freeze test and a spawn-after-end test.
- Deferred from 6.3: huge-delta arrival burst (6.5), debug-jump run counted by 6.8's backfill, five hard-coded lane `ColorRect`s.
- The 3–5 band spawns small (3 letters) and medium (4–5) copies; brutes never spawn before Epic 7. Medium copies (2 hits) are the common case, so the flash path matters as much as the melt path.
- Lessons kept: edit story-file sections line-anchored; LF endings for new text files; record any Smuck decision verbatim with a date; never touch the real save in a visual check (6.3 checked the save hash before/after).
- Test count after 6.3 review: 1439, all passing.

### Git intelligence

- One commit per story on `main`: `Story 6.4: pacing defender, projectiles and melting`, then "Story 6.4: code review patches applied, done" after review.
- Expected changes: `scripts/levels/horde_rush/horde_defender.gd`, `horde_projectile.gd` (new + `.uid`s), `horde_field.gd`, `horde_marcher.gd`, `horde_rush_level.gd`, `scripts/resources/horde_rush_config.gd`, `data/levels/horde_rush.tres`, `scenes/levels/horde_rush/horde_rush_level.tscn`, `scenes/levels/horde_rush/tomato.tscn` (new), tests (`test_horde_defender.gd` new + `.uid`; `test_horde_field.gd`, `test_horde_rush_config.gd`, `test_horde_rush_level.gd`, `tests/integration/test_run_frame.gd`), screenshots under `screenshots/6-4/`, this file, `sprint-status.yaml`, maybe `deferred-work.md`. Nothing in `scripts/autoloads/`, `scripts/typing/`, `scripts/run/`, `scripts/characters/`, `project.godot`, `export_presets.cfg`, `.github/`, `assets/`.

### Project Structure Notes

- New logic classes sit with the level in `scripts/levels/horde_rush/` (Horde Rush rules, like `HordeField`); the tomato placeholder scene in `scenes/levels/horde_rush/`. No mirrored script for `tomato.tscn` (no behaviour).
- Reusing `villager_wave.png` from `assets/sprites/characters/villager/` is an asset reuse, not a level importing another level's scene (allowed; don't instance `villager.tscn`, which belongs to Zombie Run).

### Project Context Rules

- No `project-context.md` exists. Binding rules come from `_bmad-output/game-architecture.md` (Logic Leads Visuals Chase, Entity Patterns, Configuration, Architectural Boundaries, Consistency Rules), the GDD (*Level 2: Horde Rush* defender bullet, win/loss table, Pillar 1) and the UX spines (mock frame B, DESIGN.md D16 tomato colour) plus `docs/art-style-sheet.md` §5.
- Dev environment: Godot 4.7.2 at `/c/Program Files/Godot/Godot.exe`, GUT 9.7.1, Godot MCP available (`run_project`, `get_debug_output`) for the visual check.

### Latest tech information

- No new libraries or engine features. Godot 4.7.2 notes that matter here: `@GlobalScope.pingpong(value, length)` returns 0 when `length` is 0; `roundi()` rounds halves away from zero (deterministic); `Node.create_tween()` makes a node-bound tween that pauses with the tree (default `TWEEN_PAUSE_BOUND`) and dies with the node; `Tween.custom_step()` advances a tween by hand in tests; `CanvasItem.modulate` multiplies the node and all its children (Body and the hat flash together).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.4: Pacing Defender, Projectiles and Melting] (ACs); Stories 6.5–6.7 (consumers)
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] FR56, FR58; NFR1, NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] Level 2: Horde Rush (~308–325), win/loss table (~103), Pillar 1 (~76), tuning target (~322)
- [Source: _bmad-output/game-architecture.md] Logic Leads, Visuals Chase (~783–836), Entity Patterns (~900)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/mockups/key-run-hud.html] frame B (farmer x 512–532, pumpkin tomato note); [DESIGN.md] Stamp Red rule (~365), D16 (~537)
- [Source: docs/art-style-sheet.md] §5 Kid-safe art rules, §6 Reuse rules
- [Source: _bmad-output/implementation-artifacts/6-3-horde-rush-field-spawning-and-size-classes.md] design decisions, review findings
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] ~528–530 (6.3 defers)
- [Source: scripts/levels/horde_rush/horde_rush_level.gd], [horde_field.gd], [horde_marcher.gd], [scripts/resources/horde_rush_config.gd], [data/levels/horde_rush.tres], [scripts/run/run_frame.gd:331-371,448-451], [scripts/run/level_base.gd], [scripts/levels/zombie_run/poof.gd], [tests/unit/test_horde_rush_level.gd], [tests/unit/test_horde_field.gd], [tests/integration/test_run_frame.gd:1639-1678]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), Claude Code dev-story workflow.

### Debug Log References

- Baseline before starting: 1439 tests, 1439 passing (matches the 6.3 record). After: 1490 tests, 1490 passing (+51), 82 scripts; `Parse Error|Compile Error|Failed to load script` count 0. `--import` run after adding the two `class_name` scripts.
- Red phase: `test_horde_defender.gd` first failed to parse (`HordeDefender`/`HordeProjectile` not declared), then went green. The config and field tests were written before their code but run only after it (not seen red).
- Seed-7 headless run (5 lanes, GDD numbers, one word every 2.5 s from a fixed 8-word list, 60 s at 1/60): `[spawned, thrown, hits, misses, stopped, arrived] = [24, 31, 31, 0, 20, 3]`, 1 still marching. Pinned as `PINNED_SEED_7_COUNTS` in `test_horde_defender.gd`.
- `grep` for global `randi(`/`randf(` in `scripts/levels/horde_rush/`: clean.
- Visual check: a scratch capture script (`tools/scratch_capture_6_4*.gd`, deleted after use) ran the real RunFrame on `horde_rush` seed 7 in a real window with a temp `SaveService` dir, typing a word every 1.5 s and stepping the level by hand. Real `user://save.json` sha256 `c34c7559…761d` identical before and after both runs.
- Feel note (AC task 6.4, input for 6.7, not tuning): I can't type at a "normal speed" myself, so the same scratch script simulated a minute on the shipped numbers at fixed typing speeds (10 seeds each, remaining copies allowed to finish): about 1% of copies get through at 10 WPM, 3% at 15, 6% at 20, 11% at 25-30, 20% at 40. The defender as specified is far stronger than the GDD 40%/70% targets; recorded in `deferred-work.md` for 6.7.

### Completion Notes List

- Config (Task 1): five new `HordeRushConfig` fields with FR56 docs and neutral defaults; `validate()` appends the checks after the existing ones (lane time, cooldown, cross time `>= MIN_CROSSING_TIME_S` and finite; flash and melt `>= 0` and finite). `horde_rush.tres` carries the GDD starting values 0.6 / 0.8 / 1.0 / 0.15 / 0.6.
- Field (Task 2): `HordeMarcher.is_stopped()`; `HordeField.hit()` (ignores anything not marching here, removes on the final hit and counts it), `front_most_in_lane(lane, at_or_past)` (iterates `_marching` directly, strict `>` keeps the lower id on ties), `get_stopped_count()`. `advance()` untouched; all 6.3 field tests pass unchanged.
- Defender (Task 3): pure `HordeProjectile` and `HordeDefender` (inner `Step`), no RNG, no nodes. Pacing is `pingpong(_travel, lane_count - 1)`; heading is derived from `_travel`. Step order and the march-first tie rule are in the class doc. `TIME_EPSILON_S = 1e-4` makes 48 steps of 1/60 meet 0.8 s (tested: throws on steps 1, 49, 97, 145).
- Level (Task 4): `on_run_started()` starts the defender, `on_run_ending()` stops it (projectiles freeze in the air because `_frozen` stops `_process`). `_process` splits a frame into equal steps of at most `MAX_STEP_S` (equal steps rather than "1/30 + remainder", so a 0.5 s frame is exactly 15 steps); bad deltas do nothing. `_logic_step` follows the field-then-defender order; views are updated once per frame from logic. Hard flash (`HIT_FLASH_MODULATE`, one node-bound tween per copy, killed on a new hit); final hit erases the copy from `_views` at once and squashes it to `(1.3 × class scale, 0)` over `melt_s`, then frees it (`melt_s == 0` frees at once). Defender stand-in is a `Sprite2D` (`%Defender`, villager wave frame 0, feet at the origin) under `%Zombies`; tomatoes are `tomato.tscn` (ink 6×6, pumpkin 4×4) under `%Projectiles`. `lane_feet_y_at()` added; `lane_feet_y()` calls it. The villager is drawn front-facing, so no flip was needed (checked in the screenshot).
- Tests (Task 5): config (shipped values, neutral defaults, 13 new bad cases with messages, zero flash/melt valid); field (9 new: hits, multi-hit, never arrives, foreign/arrived/stopped/null hits, invariant, front-most, ties, at_or_past, skips stopped); `test_horde_defender.gd` (21: pacing and reversal, heading, one lane, bad deltas, empty lane, first-step throw at the front-most, cooldown spacing, rounded throw lane, flight time, lane kept, 1/2-hit stops, stopped never arrives, contact over aim, spare hits the copy behind, spare misses, arrival-before-hit tie, landed in throw order, determinism, pinned seed-7 counts, global RNG); level (17 new: view placement and draw order, idle until started, view pacing, tomato view life, flash and its reset, flash restart, melt then free, instant melt, no flash at 0, stop without a sprite, end freeze, re-create reset, no brains, substep equivalence, hitch keeps throws, bad deltas, tree pause); integration (1 new: defender still before the first key, paces after it, still while the real tree is paused, paces after the countdown, brains 0). The 6.3 Horde Rush tests pass unchanged.
- Visual check (Task 6.3): `defender-throw.png` (stand-in between lanes 0 and 1, clear of the pause button, a tomato at chest height in lane 0), `hit-flash.png` + 3× crop (a medium copy tinted pink-red, reads as "bonk", not scary), `melt.png` + 3× crop (a small copy half-squashed into a puddle at its feet, goofy). The tomato placeholder is tiny at 6 px; 6.6 draws the real one.
- No sounds, no save change, no autoload/typing/run/characters changes; Horde Rush is still `available = false`; brains and `completion_bonus` stay 0.

### File List

- `scripts/resources/horde_rush_config.gd` (modified)
- `data/levels/horde_rush.tres` (modified)
- `scripts/levels/horde_rush/horde_marcher.gd` (modified)
- `scripts/levels/horde_rush/horde_field.gd` (modified)
- `scripts/levels/horde_rush/horde_projectile.gd` (new) + `.uid`
- `scripts/levels/horde_rush/horde_defender.gd` (new) + `.uid`
- `scripts/levels/horde_rush/horde_rush_level.gd` (modified)
- `scenes/levels/horde_rush/horde_rush_level.tscn` (modified)
- `scenes/levels/horde_rush/tomato.tscn` (new)
- `tests/unit/test_horde_rush_config.gd` (modified)
- `tests/unit/test_horde_field.gd` (modified)
- `tests/unit/test_horde_defender.gd` (new) + `.uid`
- `tests/unit/test_horde_rush_level.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/screenshots/6-4/defender-throw.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/6-4/hit-flash.png`, `hit-flash-3x.png` (new)
- `_bmad-output/implementation-artifacts/screenshots/6-4/melt.png`, `melt-3x.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/6-4-pacing-defender-projectiles-and-melting.md` (this file)

## Change Log

- 2026-10-07: Story created (ready-for-dev). Ultimate context engine analysis completed - comprehensive developer guide created.
- 2026-10-07: Implemented the pacing defender, projectiles, hit flash and melt (pure `HordeDefender`/`HordeProjectile`, field hit API, config numbers, level wiring with substeps, placeholder views), 51 new tests (1490 passing), screenshots, feel note for 6.7. Status → review.

### Review Findings

- [x] [Review][Patch] Stale `_flash_tweens` entry when a flashing copy arrives at the house; erase it in `_on_marcher_arrived` [scripts/levels/horde_rush/horde_rush_level.gd:398]
- [x] [Review][Patch] `_reset` iterates `_melt_tweens` with a typed `PlayerZombie` loop variable; a view freed externally would abort the reset. Iterate untyped and check `is_instance_valid` [scripts/levels/horde_rush/horde_rush_level.gd:169]
- [x] [Review][Patch] Integration test resets `get_tree().paused = false` only at the end, so a failed assertion leaves the tree paused for later tests; move cleanup to `after_each` [tests/integration/test_run_frame.gd:1714]
- [x] [Review][Defer] Projectile views and tomatoes freeze mid-air after `on_run_ending` until `_reset`; 6.5's outro must clear them [scripts/levels/horde_rush/horde_rush_level.gd] — deferred, belongs to story 6.5
