---
baseline_commit: 27568434220523abc774e751ba06e9c6886e25f3
---

# Story 3.4: Conga Line

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want every zombie I make to join a bobbing conga line behind me,
so that I can see how much I've done this run.

## Acceptance Criteria

1. **Logical count first (FR35, architecture "Logic Leads, Visuals Chase").** The level keeps an authoritative `_conga_count`. A villager key adds 1 to it **in the same `on_char_accepted` call**, in the logic block before any visuals. A brain-block key or a wrong key leaves it unchanged. `get_conga_count()` exposes it, and Story 3.5's dance reads it.
2. **A new party-hat zombie joins the end of the line (FR34, FR35).** When a villager's poof ends (`Villager.poofed(party_zombie)`), the level hands the zombie to the conga line: the villager's own `PartyZombie` is hidden, and `CongaLine.join(x)` adds a follower at the same world spot. Nothing visibly jumps (same sprite, same feet point). The follower then walks to its slot at the end of the line.
3. **The line trails the zombie, bobs and follows its scoots (FR35).** Follower `i` (0 = right behind the zombie) has the slot `leader_x − (i + 1) × SPACING_PX` on the ground line. Every frame, each follower chases its slot (frame-rate-independent smoothing), so the line follows every scoot and amble with a short ease and never passes the zombie. Each follower bobs on y with a phase offset by index, so a wave runs down the line. The bob never changes x. A follower faces the way it is moving (the newcomer walking back to the tail faces left).
4. **Capped at 12 with a "×N" badge (FR35, architecture Entity Patterns).** The cap is a new `ZombieRunConfig.conga_max_drawn` (12), not a literal. At most `conga_max_drawn` follower nodes are ever created. Once more than that have joined, a pumpkin "×N" badge (N = everyone who has joined this run, e.g. "×13") rides above the last drawn follower. A join beyond the cap creates **no node**: the badge number goes up.
5. **Never shrinks.** No code path removes a follower or lowers either count. A wrong key, a pause (tree paused, then Resume → 3-2-1) and a focus-loss pause leave `get_conga_count()`, the follower nodes and the badge unchanged. While paused, the chase and the bob freeze (node-bound, `_process`-driven).
6. **Every hugged villager joins, even at high speed.** `_free_off_screen()` never frees a villager whose poof hasn't handed off its party zombie yet. It frees it on a later pass, once `is_party_zombie_shown()` is true. So `poofed` always fires, and the conga line's joined count always catches up with `_conga_count` (deferred-work 3.3 hand-off note).
7. **Layout fits.** The full drawn line (`conga_max_drawn × SPACING_PX`) plus the badge fits on screen behind the zombie at `ZOMBIE_SCREEN_X` (224), and nothing sits below the ground line (y 192). The conga line draws above the targets and below the player zombie.
8. **Nothing else changes.** Brains, the brain signal, the Brainsss roll, the hop and hug, and the letters and layout for a seed are exactly as in 3.3. The conga line draws nothing from any RNG (the run RNG still has one consumer). `RunFrame`, `LevelBase`, the HUD and the run result are untouched.
9. **Performance check (first step toward NFR1).** The debug overlay gains a "Worst run" frame time (the worst frame since the current run started, kept on screen after the run ends). On the **web debug export**, a full 2:00 Zombie Run with a fixed seed and 12+ followers (badge showing) has a worst frame **under 33 ms** on the development machine. The numbers, browser, seed and method are recorded in this story file. The target-laptop check is Story 5.3.
10. **Tests.** New and updated GUT tests cover the conga line (join, chase, bob, cap, badge, no shrink), the level wiring (logical count, hand-off, freeing guard, cap from config), the config, the overlay's run-worst value, and pause in `RunFrame`. The full suite passes.

## Tasks / Subtasks

- [x] **Task 1: Config (AC: 4)**
  - [x] 1.1 `scripts/resources/zombie_run_config.gd`: add `@export var conga_max_drawn: int = 0` with the doc comment "How many conga-line followers are drawn at most; beyond this a ×N badge shows the total (FR35: 12)". Extend `validate()`: `if conga_max_drawn < 1: return "conga_max_drawn must be at least 1"`.
  - [x] 1.2 `data/levels/zombie_run.tres`: `conga_max_drawn = 12`. Keep LF.

- [x] **Task 2: `PartyZombie` facing (AC: 3)** in `scripts/characters/party_zombie.gd`
  - [x] 2.1 Add `func face_left(left: bool) -> void` → `_body.flip_h = left`. (`Body` is `centered = false` at (−16, −31) and the sheet is 32 px wide, centred on the feet, so `flip_h` mirrors in place.) Guard a missing `_body.sprite_frames` as `play_idle()` does.
  - [x] 2.2 Update the header: "Story 3.4 makes it walk in the conga line" → it follows in the conga line (idle frames plus a code bob until Story 3.6's walk 4f).

- [x] **Task 3: `CongaLine` (AC: 2–5, 7)**: new `scenes/levels/zombie_run/conga_line.tscn` + `scripts/levels/zombie_run/conga_line.gd`, `class_name CongaLine extends Node2D` (both paths are in the architecture tree)
  - [x] 3.1 Scene: root `CongaLine` (Node2D), `%Followers` (Node2D; followers go here, in join order), and `%Badge` (a `PanelContainer`, `visible = false`, `mouse_filter = 2`). Give `%Badge` a `StyleBoxFlat` panel: `pumpkin` `#F07A1C` background, 1 px `ink` `#1E1428` border, about 2 px content margins. Inside it, `%BadgeLabel` (`Label`, ink font colour, `font_size = 16`, the theme's Press Start 2P; DESIGN `level-card-new` badge tokens: badge pumpkin, badge text ink). `%Badge` is a sibling **after** `%Followers`, so it draws on top.
  - [x] 3.2 Look constants (named, with a "look value, not a GDD number" comment):
    - `SPACING_PX := 16.0`: one party zombie's opaque width, so they touch like a conga;
    - `CHASE_RATE := 12.0` (1/s, exponential smoothing; steady lag ≈ speed / rate, so 20 px at 5 keys/s);
    - `BOB_PX := 2.0` and `BOB_HZ := 2.0`;
    - `BOB_PHASE_STEP := 0.6` (radians per index).

    Tune by eye in Task 9, and keep `conga_max_drawn × SPACING_PX` within the AC 7 fit.
  - [x] 3.3 `const PARTY_ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/party_zombie.tscn")`.
  - [x] 3.4 `func configure(leader: Node2D, max_drawn: int) -> void`: stores both. The level calls it in its `_ready()` (the conga line is a static child, so it is already in the tree). Never read the config from here, so the line stays testable on its own.
  - [x] 3.5 `func join(from_x: float) -> void`:
    1. `_joined += 1`;
    2. if `_followers.size() < _max_drawn`: instance `PARTY_ZOMBIE_SCENE`, set `position = Vector2(from_x, 0.0)` **before** `add_child` (to `%Followers`), and append it to `_followers: Array[PartyZombie]`;
    3. `_update_badge()`.

    No randomness, no logging per join.
  - [x] 3.6 `func step(delta: float) -> void` (public so tests can drive it; `_process(delta)` just calls `step(delta)`):
    - `_time += delta`; return early if there is no leader.
    - For each follower `i`:
      - `slot := _leader.position.x - (i + 1) * SPACING_PX`;
      - `new_x := lerpf(x, slot, 1.0 - exp(-CHASE_RATE * delta))`;
      - `face_left(slot < x - 0.5)`, so it faces left only while heading back to the tail and faces right again once it is there;
      - never move **forward** past `_leader.position.x - SPACING_PX`: `new_x = minf(new_x, maxf(x, _leader.position.x - SPACING_PX))`. This stops it passing the zombie and never makes a newcomer jump;
      - `x = new_x`;
      - `y = -round(BOB_PX * (0.5 + 0.5 * sin(TAU * BOB_HZ * _time + i * BOB_PHASE_STEP)))`, which gives whole pixels within [−BOB_PX, 0]. Note that `snap_2d_transforms_to_pixel` is on.
    - Place the badge (3.7).

    Use time accumulated from `delta`, never `Time.get_ticks_*`, so pause freezes the line and tests are deterministic. No allocation and no logging in `step`.
  - [x] 3.7 `_update_badge()`: `%Badge.visible = _joined > _max_drawn`; text `"×%d" % _joined` (U+00D7; Press Start 2P has the glyph, checked with fontTools at story creation). In `step`, while the badge is visible, put its **bottom-left** just above the last drawn follower's head: the left edge on the follower's left edge (x − 8), the bottom about 2 px above the hat top (the sheet's top row is y −31, so the bottom is at about y −33), riding that follower's bob. Anchoring the left edge means "×100" grows to the right and never clips off the left of the screen.
  - [x] 3.8 Getters for tests and Story 3.5: `get_joined_count() -> int`, `get_drawn_count() -> int`, `get_followers() -> Array[PartyZombie]` (a copy), `get_badge_text() -> String`, `is_badge_shown() -> bool`. There is no removal API. Story 3.5 will add the dance.
  - [x] 3.9 Header `##` doc: logical vs view (the level owns the authoritative count; the line's joined count catches up as poofs finish), the cap and the badge, the "no nodes beyond the cap" rule, the chase/bob/facing rules, "never shrinks, no removal API", and the placeholder note (idle + code bob until the 3.6 walk 4f).

- [x] **Task 4: Zombie Run level (AC: 1, 2, 6–8)** in `scripts/levels/zombie_run/zombie_run_level.gd` and `scenes/levels/zombie_run/zombie_run_level.tscn`
  - [x] 4.1 Scene: instance `conga_line.tscn` as `%CongaLine` under `World`, **between** `Targets` and `Zombie` (draw order: targets, then line, then zombie). Add the `ext_resource` and bump `load_steps`.
  - [x] 4.2 `_ready()`: after the config check, `_conga.position.y = GROUND_Y` and `_conga.configure(_zombie, _cfg.conga_max_drawn)`. `@onready var _conga: CongaLine = %CongaLine`.
  - [x] 4.3 `var _conga_count: int = 0`. In `on_char_accepted`, right after the brains block (still logic, before `_resolved.append`/spawn/visuals): `if done is Villager: _conga_count += 1`. Keep every existing line and its order.
  - [x] 4.4 `_spawn`, villager branch: `villager.poofed.connect(_on_villager_poofed)` (connected in code; the villager is freed with its connection). `_on_villager_poofed(party_zombie: PartyZombie)`: `var x: float = _conga.to_local(party_zombie.global_position).x`, then `party_zombie.hide()`, then `_conga.join(x)`. This is an effect chain, not input gating, so it's allowed by the "never await" rule.
  - [x] 4.5 `_free_off_screen()`: skip (don't free, keep in `_resolved`) a `Villager` whose `is_party_zombie_shown()` is false. Update its doc line. Brain blocks are unchanged.
  - [x] 4.6 `func get_conga_count() -> int` and `func get_conga_line() -> CongaLine` (tests, Story 3.5).
  - [x] 4.7 Class doc: a "Conga line (Story 3.4, FR35)" paragraph (logical count at resolve, hand-off on `poofed`, the freeing guard, the cap from config, never shrinks, draws nothing from any RNG). Update "Later stories" (drop 3.4), and the `ZOMBIE_SCREEN_X` comment ("Story 3.4 may retune it" → it fits `conga_max_drawn × CongaLine.SPACING_PX` plus the badge behind the zombie). Keep 224 unless Task 9 shows a real problem.
  - [x] 4.8 **Do not touch** `create_target_source`, the RNG order, the brains/voice logic, the hop/hug calls or `_scoot_to`.

- [x] **Task 5: Debug overlay "Worst run" (AC: 9)** in `scripts/debug/debug_overlay.gd`
  - [x] 5.1 Track the worst frame since the current run started: while the overlay is open (`_process` already records every frame) and `_run_frame()` returns a frame whose state is `RUNNING`, `_run_worst_ms = maxf(_run_worst_ms, frame_ms)`. When a **different** run frame instance appears (compare `get_instance_id()`), reset to 0 first. After the run ends the value stays, so it can be read on the report card.
  - [x] 5.2 Show it in the stats label: `"FPS %d   Frame %.1f ms\nWorst 10 s: %.1f ms   Run: %.1f ms"` (or a third line, if `test_fits_above_the_hud_band_with_every_section` still passes; run it).
  - [x] 5.3 Put the bookkeeping in a small pure method (e.g. `_note_run_frame(frame_ms: float, run_id: int, running: bool)`) so it can be tested without real time. Debug-only code stays in `scripts/debug/` (Boundary 7). Don't log per frame.
  - [x] 5.4 Update the overlay header doc (stats section).

- [x] **Task 6: Tests (AC: 10)**. Read each file before editing it and follow its patterns (process disabled, `custom_step` for tweens, `duplicate()` the config before `add_child`, never mutate the cached `.tres`).
  - [x] 6.1 New `tests/unit/test_conga_line.gd` (a bare `Node2D` leader, the line configured with a small cap such as 3, process disabled, driven by `step()`):
    - `join(x)` below the cap → one `PartyZombie` under `%Followers` at `(x, 0)`; joined = drawn = 1; badge hidden.
    - Cap: 5 joins with cap 3 → exactly 3 `PartyZombie` nodes anywhere under the line (count recursively, so "no hidden nodes" is proven), joined 5, badge shown with text `"×5"`. With cap 12 and 13 joins → `"×13"`.
    - Chase: with the leader at x 200 and followers joined at 200, many small steps → follower `i` converges to `200 − (i+1)·SPACING_PX` (within 0.5 px); leader jumps +48 → every follower x increases monotonically over the next steps and none ever reaches `leader.x − SPACING_PX + ε`.
    - Frame-rate independence: 60 steps of 1/60 vs 30 steps of 1/30 end within 1 px.
    - Newcomer: with 2 followers settled, join a third at `leader.x − SPACING_PX` (ahead of its tail slot, where a real poof lands) → it moves back toward the tail slot and `face_left` is true while moving back; it ends at the tail slot and order is preserved.
    - Bob: y is always a whole number within [−BOB_PX, 0]; two neighbours differ in phase at some step; x is unaffected by the bob (step with the leader still at its slot: x stays put).
    - No step → nothing moves (frozen time = pause).
    - Badge rides the last drawn follower: its bottom is above that follower's head (≤ −32) and its left edge ≈ follower x − 8.
    - The "×" glyph: the theme font `has_char(0xD7)`.
    - Never shrinks: there is no public method that lowers the counts (just assert the counts after a long mixed sequence are monotonic).
  - [x] 6.2 `tests/unit/test_party_zombie.gd`: `face_left(true)` flips `Body`, `face_left(false)` restores it; the null-frames guard.
  - [x] 6.3 `tests/unit/test_zombie_run_level.gd` (new section `# --- conga line (Story 3.4) ---`):
    - A villager key → `get_conga_count()` +1 in the same call (before any tween step); a block key → unchanged; a wrong key → unchanged.
    - Hand-off: villager key, step the villager's sequence and poof → the conga's joined count +1, a follower exists at the villager's x (before any `step`), and the villager's `get_party_zombie().visible` is false while `is_party_zombie_shown()` stays true.
    - Burst: 12 keys → `get_conga_count() == 9` immediately; after finishing every poof, joined == 9 (this mirrors `test_burst_every_villager_still_poofs`; derive the expected 9 from counting villagers rather than hard-coding it if you can, see the 3.3 review deferral about brittle counts).
    - Freeing guard: resolve a villager, move the camera so it is off screen (scoot/amble via `_process`/tween steps) **before** its poof finishes → it is still in the tree after `_free_off_screen`; finish the poof → the line joined it; the next pass frees it.
    - Cap from config: `_make(42, func(c): c.conga_max_drawn = 3)`, enough villagers poofed → 3 followers, badge `"×N"` with N = `get_conga_count()`. This catches a hard-coded 12, which the regex guard can't ban (`HALF_WIDTH = 12` lives in the same folder).
    - Draw order: `%CongaLine` index is after `%Targets` and before `%Zombie` under `%World`.
    - Fit: `ZOMBIE_SCREEN_X - cfg.conga_max_drawn * CongaLine.SPACING_PX >= 16` (room for the tail sprite and the badge's left edge on screen).
    - Never shrinks: after poofs, 10 wrong keys → count, joined and follower nodes unchanged.
    - **Regression guards (must pass unchanged):** `test_run_rng_has_one_consumer`, `test_same_seed_same_letters_and_blocks`, `test_layout_does_not_depend_on_the_voice_rolls`, `test_letters_match_the_story_3_1_letter_bag`, the Brainsss, hop/hug, camera, freeing and chaining tests. Run them before and after, and report. `test_resolved_targets_are_freed_off_screen` may need its villagers' poofs finished first; if so, adjust **only** the setup and say so.
    - Config validation: `conga_max_drawn = 0` → no source (`assert_push_error`).
  - [x] 6.4 `tests/unit/test_zombie_run_config.gd`: `conga_max_drawn == 12`; `validate()` flags 0 and negative values (add to `test_each_bad_number_is_rejected` if that is its pattern).
  - [x] 6.5 `tests/unit/test_debug_overlay.gd`: run-worst resets on a new run frame instance, grows only while `RUNNING`, ignores `PAUSED`/`COUNTDOWN`/`WAITING_FIRST_KEY` frames, keeps its value after the frame goes away, and shows in the stats label. Use the existing `find_run_frame` seam and fake frames as the run-section tests do.
  - [x] 6.6 `tests/integration/test_run_frame.gd` (Zombie Run section): type until 2+ villagers are resolved, finish their poofs, then Esc → `PAUSED` → count, joined and followers unchanged; Resume → countdown → `RUNNING` → still unchanged. A focus-loss pause, if cheap, is the same check.
  - [x] 6.7 Full suite, headless: run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` first (new `class_name CongaLine`), then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. **Confirm the baseline yourself at `2756843`** (3.3 ended at 682 plus review patches) and report real numbers. Expect 0 `Parse Error`, the 3 expected villager-assert `SCRIPT ERROR` lines from `test_villager.gd` (deferred-work 3.3) and nothing else, and 50 anchor warnings.
  - [x] 6.8 Mutation habit: break each rule once, confirm a test fails, restore, and report honestly:
    - count on `poofed` instead of at resolve;
    - a hard-coded cap of 12;
    - a node created beyond the cap (even hidden);
    - the freeing guard removed (needs the high-speed freeing test);
    - a follower allowed to pass the zombie;
    - a bob that changes x, or uses `Time` instead of accumulated delta;
    - the villager's party zombie not hidden on hand-off;
    - the conga line drawing from `_rng`.

- [x] **Task 7: Manual checks (AC: 2–7)**
  - [x] 7.1 Desktop (Godot MCP `run_project` + `get_debug_output`): the project and the level scene load with no new errors or warnings. The MCP can't type, so mark this partial, as in 3.1–3.3.
  - [x] 7.2 Web debug export (`--export-debug "Web" build/web/index.html`, `web-debug` on port 8060, the in-app browser pane, driven with `key` presses since the pane's `type` action is ignored):
    - each poof becomes a party zombie that walks back to the tail;
    - the line follows each scoot with a little ease and bobs in a wave;
    - nothing passes the zombie;
    - past 12 the "×N" badge rides the last follower and counts up on each new poof;
    - Esc freezes the line, and Resume → 3-2-1 → it carries on with nothing lost;
    - the console is clean.

    Save screenshots (a short line mid-bob, a newcomer walking back, the full line with the badge, the pause) to `_bmad-output/implementation-artifacts/screenshots/3-4/`.
  - [x] 7.3 Look and tone at 1×: the line reads as a goofy conga, not a march; the badge digits read clearly against the sky; nothing sits below y 192; the tail and the badge stay on screen at normal typing speeds (note what happens at very fast bursts).

- [x] **Task 8: Performance check (AC: 9)**, recorded in the Dev Agent Record under "Performance (NFR1 first check)"
  - [x] 8.1 Fixed seed: start a run, quit, press F2 to pin its seed (Story 2.10), then start Zombie Run again. Note the seed.
  - [x] 8.2 Know the letters without reading the canvas: write a throwaway headless script in the scratchpad (not in the repo) that rebuilds `create_target_source` for that seed (run RNG seed → first `randi()` seeds the `LetterBagSource` child) and prints the first ~300 letters. Or read the overlay's "Target … > …" line from screenshots.
  - [x] 8.3 Open the overlay (F3) **before** the first key (opening clears the tracker). Type at least 20 villager-producing keys early (12+ followers and the badge), then keep typing a burst of keys about every 10 s until 2:00 so spawning, poofs and joins happen throughout. Let the clock run out.
  - [x] 8.4 On the report card, read "Run: X ms" from the overlay. Record:
    - the worst frame;
    - browser and version, the machine (CPU/GPU), the seed, the conga total;
    - how many keys, and how they were sent;
    - also the 10 s worst at a few points, if seen.

    Pass = under 33 ms. If it fails: don't optimise blindly. Note the spike's timing (load? first poof? badge text change?), check `preview_logs` / console, and record it. Fix only if the cause is in this story's code; otherwise defer it to Story 5.3 with the evidence.

- [x] **Task 9: Wrap-up**
  - [x] 9.1 `deferred-work.md` "Deferred from: dev of story-3-4":
    - followers use idle frames plus a code bob until the 3.6 walk 4f;
    - no join SFX (5.1);
    - a join beyond the cap only ticks the badge (no extra walk-in; 5.0 polish could add a pop);
    - what happens to the tail and the badge at extreme speed;
    - the perf result and the target-laptop check in 5.3.

    On the 3.3 "Conga hand-off" entry, note "3.4: counted at resolve; villagers aren't freed before their hand-off". On the 3.1 `ZOMBIE_SCREEN_X` entry, note the decision.
  - [x] 9.2 Dev Agent Record, File List and Change Log. Set Status → `review` here, and `sprint-status.yaml` → `review`.

### Review Findings

- [x] [Review][Patch] Test gaps: real-frame run-worst test only covers WAITING_FIRST_KEY, so add PAUSED and COUNTDOWN real-frame cases [tests/unit/test_debug_overlay.gd]
- [x] [Review][Patch] Test gaps: no test that CongaLine `_process` really freezes under a tree pause (only manual `step()` is driven) [tests/unit/test_conga_line.gd]
- [x] [Review][Patch] Test gaps: hat-fidelity test checks only x/y, so also assert the follower and the villager copy share the same sprite frames [tests/unit/test_run_frame.gd / test_zombie_run_level.gd]
- [x] [Review][Defer] Newcomer pops up to 2 px on its first `step()` (join places y=0, bob sets y up to -2) [scripts/levels/zombie_run/conga_line.gd] — deferred, cosmetic
- [x] [Review][Defer] A villager poofing ahead of the zombie makes the follower walk back through it; followers ordered by join order, so they can cross mid-walk [scripts/levels/zombie_run/conga_line.gd:step] — deferred, matches spec "same spot" intent
- [x] [Review][Defer] `CongaLine.join()` before `configure()` (max_drawn 0) shows a badge with no followers; `ZombieRunConfig.validate` has no upper bound for `conga_max_drawn` [scripts/levels/zombie_run/conga_line.gd, scripts/resources/zombie_run_config.gd] — deferred, shipped config valid and only the level calls it
- [x] [Review][Defer] Badge placed after `reset_size()` in the same frame may use a stale size for one frame [scripts/levels/zombie_run/conga_line.gd:_place_badge] — deferred, unconfirmed and cosmetic
- [x] [Review][Defer] Test brittleness: `OS.delay_msec(5)` timing and hardcoded `brains_earned == 10` for seed 42 [tests/unit/test_debug_overlay.gd, tests/integration/test_run_frame.gd] — deferred
- [x] [Review][Defer] Perf check used the first run's seed rather than an F2-pinned one (disclosed); replay is only via run history [story Dev Agent Record] — deferred, disclosed

## Dev Notes

### What this story is (and isn't)

- It adds the conga line: a logical count in the level, a `CongaLine` view that collects each party-hat zombie when its villager's poof ends, a 12 cap with a "×N" badge, and a "worst frame this run" readout for the first NFR1 check.
- **New files:**
  - `scripts/levels/zombie_run/conga_line.gd` + `scenes/levels/zombie_run/conga_line.tscn`
  - `tests/unit/test_conga_line.gd`
- **Updated files:**
  - `scripts/resources/zombie_run_config.gd`, `data/levels/zombie_run.tres`
  - `scripts/characters/party_zombie.gd`
  - `scripts/levels/zombie_run/zombie_run_level.gd`, `scenes/levels/zombie_run/zombie_run_level.tscn`
  - `scripts/debug/debug_overlay.gd`
  - tests `test_zombie_run_level.gd`, `test_zombie_run_config.gd`, `test_party_zombie.gd`, `test_debug_overlay.gd`, `tests/integration/test_run_frame.gd`
  - `deferred-work.md`, `sprint-status.yaml`
- **Don't build:**
  - the end dance, the outro, the completion bonus or the Play Again reset (3.5; Play Again builds a new level instance anyway, so the line starts empty for free);
  - walk frames or the backdrop (3.6);
  - groans or a join SFX (3.7 / 5.1);
  - hats on the player zombie (4.3);
  - pooling (the architecture forbids it unless profiling demands it, and 12 nodes per run doesn't).
- **No changes to** `RunFrame`, `LevelBase`, `ZombieRunTarget`, `BrainBlock`, `Villager`, `Poof`, `ZombieRunGroups`, `AudioManager`, the HUD, `FrameTracker` or the save.

### Key design decisions (follow these)

- **Logical count vs view (architecture: "conga count" is logical state in the level).** `_conga_count` changes at resolve time, in the same call, and is the truth for 3.5 and for "never shrinks". `CongaLine` is a view whose `joined` count catches up as poofs finish. The **badge shows the view's joined count**, so "×13" appears the moment the 13th zombie visibly joins (poof → number goes up). That reads as "it went into the line"; ticking the badge at the hug, before the poof, would look wrong.
- **The hand-off.** The villager keeps its 3.3 sequence untouched (hug → poof → shows its `PartyZombie` → `poofed`). The level's handler hides that node in the same call and the line instances its own follower at the same world point. No `reparent()`: the villager's `%PartyZombie` is a unique-name node owned by the villager scene, and its 3.3 getters and tests rely on it. `is_party_zombie_shown()` stays a "the hand-off happened" flag.
- **Freeing guard instead of a fallback join.** At more than about 7 keys/s, a villager can scroll off before its poof ends (3.3 deferral). Keeping it alive until the hand-off is one line in `_free_off_screen` and guarantees `poofed` fires. The newcomer then walks in from the left edge to the tail. `_resolved` grows by at most a couple of entries.
- **Chase, not tweens, for followers.** The architecture's "one retargeting tween per moving actor" is about the actor driven by logic (the zombie's scoot). Followers chase a moving slot every frame, so a frame-rate-independent `lerp` with `1 − exp(−rate·dt)` in `_process` is the right tool. It allocates nothing, pauses with the tree, and costs 12 lerps a frame. It also covers the newcomer walking back to the tail with no special case.
- **Cap means no nodes.** A join beyond the cap only increments `_joined` and updates the badge. Never create-and-hide, and count nodes recursively in tests (architecture Entity Patterns: "No hidden nodes are created beyond the cap").
- **GDD numbers vs look numbers.**
  - GDD number, config only: `conga_max_drawn` 12 (FR35).
  - Look values, named consts in `conga_line.gd`: spacing, chase rate, bob, phase step, badge offset.
  - The regex guard (`120|0.15|26|0.35|48|0.2` in `scripts/levels/zombie_run/*.gd`) still applies to `conga_line.gd`. Don't write `0.2` or `48` there, and remember `12` can't be guarded by regex, so the cap test with `conga_max_drawn = 3` is the guard.
- **No randomness.** The bob phase comes from the index and the time, never from an RNG. `test_run_rng_has_one_consumer` must pass unchanged.

### Existing code: current state, what changes, what must be preserved

- **`zombie_run_level.gd`** (after 3.3):
  - Current state: `on_char_accepted`: guards → `peek` → pop → `_active_index += 1` → `resolve()` → brains + signal + one `randf()` roll → `_resolved.append` → spawn far slot → activate next → visuals (block: `stop_hug` + `hop`; villager: `hug`) → `_scoot_to`. `_spawn` instances villagers with `setup` + `configure(hug_time_s)`. `_process` ambles, picks walk/idle and calls `_free_off_screen`, which frees resolved targets past `camera_x − HALF_WIDTH`.
  - Changes: the `_conga_count` line; `poofed` connect; the handler; the freeing guard; the `%CongaLine` wiring in `_ready`.
  - Preserve: everything else, byte-for-byte in behaviour.
- **`villager.gd`**: emits `poofed(party_zombie)` once, from `_show_party_zombie()` after the poof's `finished`. Sets `_party_zombie_shown = true` before emitting. **No change.**
- **`party_zombie.gd`**: `Body` `AnimatedSprite2D` at (−16, −31), `idle` 2f at 8 fps, autoplay, null-frames guard. Add `face_left` only.
- **`player_zombie.gd`**: hop (y) and hug (x) on `Body`. The node's own `position.x` is set only by the level's `_set_zombie_x`, which is what `CongaLine` reads as the leader x. **No change.**
- **`debug_overlay.gd`**: `_process` (only while open) records `(now, frame_ms)` into `FrameTracker`; `_set_open(true)` clears it; `_refresh_stats()` formats the stats label every `REFRESH_SEC`; `_run_frame()` resolves the run frame through the `find_run_frame` seam. Add the run-worst bookkeeping next to the `record` call. **Don't** change `FrameTracker` (its tests pin the 10 s window).
- **`test_zombie_run_level.gd`**: `_make(seed, tweak)`, `_key()`, `_type_until(_is_villager)`, `_step`, `_finish_scoot`, `_zombie()`. Level tests call `_level._process(delta)` (process is disabled). `CongaLine` will also be disabled (it inherits the mode), so drive it with `get_conga_line().step(delta)` in tests.

### Testing notes

- GUT 9.7.1. After adding `CongaLine`, run `--import` before the suite.
- A node-bound tween on a disabled node still advances with `custom_step` (3.1–3.3). The villager's sequence and the poof are stepped as in `test_effects_complete_after_a_cut`.
- `PartyZombie` nodes created by `join()` inherit `PROCESS_MODE_DISABLED` in tests, so their `AnimatedSprite2D` won't animate there. That's harmless.
- Use `watch_signals` / `assert_signal_emit_count` as in 3.3; `assert_push_error` for config validation; `duplicate()` the config before `add_child`.
- Keep every touched file LF (`.gitattributes` `eol=lf`; normalise only files you edit).

### Previous story intelligence (3.3, 3.2)

- 3.3:
  - The baseline is often off by one from the story's number, so confirm it yourself.
  - The art tool was not needed this time (no new sheet).
  - Review decision: the hug restarts from its current lean (`hug()` reads `Body.x`), so don't add `stop_hug()` before villager keys.
  - Review deferrals relevant here: `poofed` may never fire if the villager is freed (fixed by AC 6); tests hard-code layout-dependent counts (prefer derived counts in new tests).
  - A hidden `PartyZombie` autoplays in every villager (accepted).
- 3.3 found that a GDScript `assert` in headless GUT logs a `SCRIPT ERROR` and doesn't abort, which is why `assert_engine_error` is used. Avoid new asserts in paths tests exercise. Use `Log` + safe returns instead.
- 3.2/3.3 manual checks: small, short motions (hop 16 px, hug 3 px) were hard to see in pane screenshots. The conga line is large and persistent, so it should be easy. Still verify chase and bob by tests first.
- Review habits: one test per rule, honest mutation reports, real test counts, and partial manual checks marked partial.

### Git intelligence

- One commit per story; HEAD is `2756843 Story 3.3: villager hugs and party-hat zombies`, and the working tree was clean at story creation. Suggested message: `Story 3.4: conga line`.

### Latest tech notes (Godot 4.7.2)

- `lerpf(a, b, 1.0 - exp(-rate * delta))` is the standard frame-rate-independent smoothing.
- `Node2D.to_local(global_point)` converts the villager's party zombie's global position into the line's space (the line sits at `(0, GROUND_Y)` inside `%World`, which is scrolled).
- `AnimatedSprite2D.flip_h` mirrors the texture within its rect. With `centered = false` and a 32 px frame at x −16, the mirror axis is the node origin.
- A `PanelContainer` with a `StyleBoxFlat` and a `Label` child sizes itself to the text. Read `size` after a frame, or call `reset_size()` after changing the text, before positioning it by its bottom edge.
- `Font.has_char(0xD7)` on the theme's default font (`ThemeDB.get_project_theme().default_font`, or load `res://data/ui_theme.tres`) checks the "×" glyph.

### Project Structure Notes

- Paths follow the architecture tree: `scenes/levels/zombie_run/conga_line.tscn` ↔ `scripts/levels/zombie_run/conga_line.gd` (both are listed there).
- Debug code changes stay in `scripts/debug/` (Boundary 7).
- No new autoloads, InputMap actions, save fields, audio or art.

### Project Context Rules

There is no `project-context.md`. The binding rules come from `_bmad-output/game-architecture.md`, `docs/art-style-sheet.md` and the UX spines:
- Static typing everywhere; `:=` only when the type is obvious.
- Typing callbacks are synchronous: logic before visuals, no `await`, and nothing gates input on a tween or signal.
- Game numbers come only from `ZombieRunConfig`; no GDD literals in scripts.
- Randomness only through injected RNGs; the conga line uses none.
- `preload`ed scene consts; set the position/`setup` before `add_child`; capped visuals create no hidden nodes; no pooling.
- Signals are typed, past tense and connected in code; node refs via `%Unique` / `@onready`.
- Logging via `Log`, never in `_process` or per key.
- UI: Press Start 2P at multiples of 8 px (16 here); palette colours only; badge pumpkin with ink text (DESIGN `level-card-new` badge tokens); kid-safe tone (NFR10).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.4: Conga Line; #Story 3.5 (dance reads the line); #Story 3.6 (walk frames)]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory (FR34, FR35, NFR1, NFR10, NFR13)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Level 1: Zombie Run (conga line), #Performance (NFR1 measurement)]
- [Source: _bmad-output/game-architecture.md#Logic Leads Visuals Chase, #Entity Patterns (capped visuals, no pooling), #Debug Tools, #Directory Structure]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md (diegetic progress: conga line with ×N badge beyond 12); DESIGN.md (badge tokens, typography)]
- [Source: _bmad-output/implementation-artifacts/3-3-villager-hugs-and-party-hat-zombies.md (hand-off seam, review findings)]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md (3.1 ZOMBIE_SCREEN_X, 3.3 conga hand-off)]
- [Source: scripts/levels/zombie_run/zombie_run_level.gd, villager.gd; scripts/characters/party_zombie.gd, player_zombie.gd; scripts/debug/debug_overlay.gd, frame_tracker.gd; scripts/resources/zombie_run_config.gd; tests/unit/test_zombie_run_level.gd, test_debug_overlay.gd; tests/integration/test_run_frame.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline at `2756843`: 682/682 passing, 0 `Parse Error`, 3 expected `SCRIPT ERROR` lines (`test_villager.gd`), 50 anchor warnings (100 log lines).
- Final: 720/720 passing (+38), 0 `Parse Error`, the same 3 `SCRIPT ERROR` lines, 50 anchor warnings. The only new log warning is the expected `party zombie has no sprite frames` from the new `test_face_left_without_sprite_frames` (consumed with `assert_push_warning`).
- Regression guards before/after: `test_run_rng_has_one_consumer`, `test_same_seed_same_letters_and_blocks`, `test_layout_does_not_depend_on_the_voice_rolls`, `test_letters_match_the_story_3_1_letter_bag`, the Brainsss, hop/hug, camera, freeing and chaining tests all pass unchanged, except `test_resolved_targets_are_freed_off_screen`. It failed once the freeing guard landed (its villagers never poofed, so they were correctly kept). Only its setup changed: one `_finish_poofs()` call per key.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- **Config:** `ZombieRunConfig.conga_max_drawn` (12 in `zombie_run.tres`); `validate()` rejects values below 1.
- **PartyZombie:** `face_left(left)` flips `Body.flip_h` in place (guarded on missing frames).
- **CongaLine** (`conga_line.gd/.tscn`), view only: `configure(leader, max_drawn)`; `join(from_x)` instances a follower (position set before `add_child`) only below the cap, otherwise just counts; `step(delta)` does the exp-smoothed chase to `leader.x - (i+1)*16`, the forward clamp, facing (0.5 px deadzone), the whole-pixel index-phased bob on accumulated delta, and the badge placement. The pumpkin/ink `PanelContainer` badge shows "×N" (N = joined) once joined > cap, bottom-left anchored above the last drawn follower's hat, riding its bob. No removal API, no RNG, no logging, no allocation in `step`.
- **Level:** `_conga_count += 1` for a villager right after the brains block in `on_char_accepted`; `villager.poofed` goes to `_on_villager_poofed` (line-local x via `to_local`, hide the villager's copy, `join`). `_free_off_screen()` skips villagers whose `is_party_zombie_shown()` is false. `%CongaLine` sits between `%Targets` and `%Zombie` under `%World` at y `GROUND_Y`. New getters `get_conga_count()` and `get_conga_line()`. `ZOMBIE_SCREEN_X` kept at 224 (12 x 16 = 192 px of line; tail sprite and badge start at screen x 24).
- **Debug overlay:** `_note_run_frame(frame_ms, run_id, running)` keeps the worst RUNNING frame of the current run frame instance (reset on a new instance, kept after it goes away). The stats line reads `Worst 10 s: X ms   Run: Y ms`; the fit test still passes.
- **Tests:** new `test_conga_line.gd` (17). Level +11 (count at resolve, block/wrong keys, hand-off, burst with a derived count, freeing guard, cap from config, draw order, fit, on screen at normal speed, never shrinks, bad config), plus `test_conga_line_draws_nothing_from_the_run_rng`, which finishes the poofs (the 3.3 RNG test never does). Config +2 and a row in the bad-number table; party zombie +2; overlay +4; run frame +1 (Esc pause, resume countdown and a focus-loss pause keep the count, joined count and followers).
- **Mutation pass (each one broke at least 1 test, then restored):** count on `poofed` (2 failed); hard-coded cap 12 (1: `test_cap_comes_from_the_config`); a hidden node beyond the cap (3); freeing guard removed (1: `test_villager_is_not_freed_before_its_hand_off`); followers chasing past the zombie (5); a bob that changes x (5); a bob on `Time` (1: `test_bob_runs_on_accumulated_delta`); villager copy not hidden (1); a `_rng.randf()` in the hand-off (1: the new RNG test; the 3.3 RNG test alone would not catch it). **Not caught:** removing only the forward clamp line. It is mathematically redundant (the lerp weight is in [0, 1) and every slot is behind `leader - SPACING_PX`), so no test can fail on it. Kept as the spec'd guard and noted in deferred-work.
- **7.1 (partial):** Godot MCP `run_project` on `zombie_run_level.tscn` loads with no errors or warnings. The MCP can't type.
- **7.2 web debug** (fresh `--export-debug "Web"`, `web-debug` on :8060, browser pane, `key` presses): poofs become green party-hat zombies that line up behind the zombie (`short-line.jpg`, `burst-poofs-joining.jpg`). A 20-key burst filled the line to 12 with a readable pumpkin "×17" riding the last follower (`full-line-badge-x17.jpg`; 23 keys = 6 blocks + 17 villagers). The line follows each scoot and never passes the zombie. Esc froze it (two identical frames 2 s apart, `pause-1.jpg` / `pause-2-two-seconds-later.jpg`); Resume, then 3-2-1, and it carried on with nothing lost (`resume-countdown.jpg`). Console: clean lifecycle, no errors or warnings. **Partial:** the newcomer's left-facing walk back and the bob wave are too short or small to catch reliably in pane screenshots; they are covered by `test_newcomer_walks_back_to_the_tail_facing_left` and the bob tests.
- **7.3:** it reads as a goofy conga at 1x; the "×N" digits read clearly against the sky; nothing sits below y 192; the tail and badge stayed on screen through the run. In fast bursts, newcomers walk in from where their villager poofed, which can be well behind the tail (noted in deferred-work).

### Performance (NFR1 first check)

- **Result: PASS. Worst frame 22.7 ms** over the whole 2:00 run (target under 33 ms), read from the overlay's new "Run" value on the report card (`perf-report-card-run-worst.jpg`, `perf-end-of-run.jpg`).
- Build: web debug export of this story's code, served by `web-debug` (python http.server, port 8060).
- Browser: the Claude desktop app's built-in browser pane, Chromium 152.0.7977.130 (Windows 11, WebGL 2, Compatibility renderer, single-threaded build). Machine: the development PC, NVIDIA GeForce RTX 3070, 16 logical CPUs.
- Seed: **3282930552** (Zombie Run). Deviation from 8.1: instead of quit, F2 pin and restart, the overlay was opened on the first run while it was still in WAITING_FIRST_KEY (before any key), the seed was read from the overlay and that run was used. The seed is in the run history and can be pinned with F2 to replay.
- Letters: a throwaway headless script (temporary, deleted, never committed) rebuilt the letter bag from the seed (run RNG, first `randi()`, `LetterBagSource`); its first letters matched the screen (`d > c t a`).
- Keys: 116 correct, 0 errors, sent as browser-pane `key` presses: 3 keys, a 20-key burst (12 followers and the badge by about 0:10), then 10-key bursts about every 10 s until the end, with one Esc pause and Resume at 0:25. 29 brains, so a conga total of 87 (116 keys minus 29 blocks).
- The 10 s worst seen along the way: 21.4, 17.2, 18.6, 18.9, 18.0, 18.3 and 22.7 ms. 60 FPS throughout (the pane showed 30 FPS / 33 ms once, on the idle shot before typing, outside the run window).

### File List

- `scripts/levels/zombie_run/conga_line.gd` (new)
- `scripts/levels/zombie_run/conga_line.gd.uid` (new, generated)
- `scenes/levels/zombie_run/conga_line.tscn` (new)
- `scripts/levels/zombie_run/zombie_run_level.gd`
- `scenes/levels/zombie_run/zombie_run_level.tscn`
- `scripts/characters/party_zombie.gd`
- `scripts/resources/zombie_run_config.gd`
- `data/levels/zombie_run.tres`
- `scripts/debug/debug_overlay.gd`
- `tests/unit/test_conga_line.gd` (new)
- `tests/unit/test_conga_line.gd.uid` (new, generated)
- `tests/unit/test_zombie_run_level.gd`
- `tests/unit/test_zombie_run_config.gd`
- `tests/unit/test_party_zombie.gd`
- `tests/unit/test_debug_overlay.gd`
- `tests/integration/test_run_frame.gd`
- `_bmad-output/implementation-artifacts/screenshots/3-4/` (new, 8 screenshots)
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/3-4-conga-line.md`

### Change Log

- 2026-10-05: Story 3.4 implemented: the conga line (logical count at resolve; a `CongaLine` view with chase, bob and facing; a 12 cap from config with a "×N" badge; a freeing guard so every villager joins), the debug overlay's "Run" worst frame, 38 new tests, and the web perf check (22.7 ms worst frame). Status set to review.
