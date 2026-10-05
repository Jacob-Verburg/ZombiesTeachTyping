---
baseline_commit: d981c9b75f2e7089e6077dfe7e282a1b40add4c7
---

# Story 3.5: Run End Dance and Brains Award

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want my zombie and its conga line to dance when time runs out,
so that every run ends as a celebration.

## Acceptance Criteria

1. **Input stops at 0:00 (FR36).** When the clock reaches the level duration, `RunFrame` enters `ENDING`. From that moment no key is judged: correct and wrong keys change nothing (keys, errors, targets, brains, conga count). This already works (Story 2.4 `TypingInput.active = false` + the state check). It must keep working, with a Zombie Run test proving it.
2. **The dance lasts the config's 2.0 s (FR36).** `ZombieRunLevel.on_run_ending()` returns `ZombieRunConfig.dance_time_s` (a new field, 2.0 in `zombie_run.tres`, not a literal). `RunFrame` waits that long in `ENDING`, then enters `DONE` and opens the report card. Not before: the report card is not opened at 1.9 s.
3. **The zombie dances in place.** On `on_run_ending()`, the level stops all movement: the scoot tween is killed, the amble stops, and `_process` no longer switches walk/idle. The zombie stays where it is (the camera does not move), its hop and hug are cut, and `PlayerZombie.dance(duration_s)` plays a visible placeholder dance (code bounce + left/right flip) for the dance time, then puts `Body` back at rest. Story 3.6 adds the `dance` 4f frames: when the zombie's `SpriteFrames` has a `dance` animation, `dance()` plays it.
4. **The conga line dances too.** `CongaLine.dance()` switches every drawn follower from the walk bob to a dance (a bigger bounce and a left/right flip per beat, phased by index so the line ripples). Followers still settle into their slots (the leader has stopped, so they converge). The "×N" badge stays and rides the last follower. A villager whose poof finishes during the dance still joins the line (and dances). The line never shrinks.
5. **Completion bonus from config (FR36).** On a completed run (`ENDING` reached through the timer, F6 or `end_requested`), `RunFrame` builds the `RunResult` with `brains` = the level's brain-block total and `bonus_brains` = the level config's `completion_bonus` (10 for Zombie Run, 0 for the test level). No `10` literal anywhere in code.
6. **Wallet and save (FR22, FR52).** `PlayerData.record_run()` (unchanged) adds `brains + bonus_brains` to the wallet with one `brains_changed` and one save request, still on entering `ENDING` (before the dance). The run record's `"brains"` is the total.
7. **Report card bonus line (FR19).** The report card for a Zombie Run shows Brains Collected = brains + 10 and the "+10 bonus" line (already built in Story 2.9; proven here end to end).
8. **Quit gives no bonus (FR13).** Quit to Menu from the pause panel adds only the brain blocks collected, records nothing and gives no bonus. Pause is still refused while `ENDING` (Esc, the pause button and focus loss do nothing during the dance).
9. **Play Again starts fresh.** The report card's Play Again sends `Router.go(RUN, {"level_id": &"zombie_run"})` with no seed, so a new `RunFrame` builds a new level: a fresh letter bag (a new random seed, unless a debug seed is pinned with F2, Story 2.10) and an empty conga line (count 0, joined 0, no followers, no badge).
10. **Nothing else changes.** Letters, layout and Brainsss rolls for a seed are exactly as in 3.4 (`test_run_rng_has_one_consumer` passes unchanged: the dance draws nothing from any RNG). Pause, countdown, quit and the conga behaviour during `RUNNING` are untouched.
11. **Tests.** GUT tests cover the config field, `PlayerZombie.dance()`, `CongaLine.dance()`, the level's `on_run_ending()` (stop + dance + return value), the bonus in `RunFrame`, the wallet/save total, the timing of `DONE`, quit without bonus, and a fresh level on Play Again. The full suite passes.

## Tasks / Subtasks

- [x] **Task 1: Config (AC: 2)**
  - [x] 1.1 `scripts/resources/zombie_run_config.gd`: add `@export var dance_time_s: float = 0.0` with the doc comment "How long the zombie and the conga line dance at the end of a run before the report card, in seconds (FR36: 2.0)". In `validate()`: `if not (dance_time_s > 0.0): return "dance_time_s must be above 0"` (the `not (x > 0)` form also rejects NaN, like `hug_time_s`).
  - [x] 1.2 `data/levels/zombie_run.tres`: `dance_time_s = 2.0`. `completion_bonus = 10` is already there; keep it. Keep LF.
  - [x] 1.3 `LevelConfig.completion_bonus` doc: "Read by RunFrame from Story 3.5" → "Added to every completed run's RunResult.bonus_brains by RunFrame (Zombie Run 10); never on quit".

- [x] **Task 2: `PlayerZombie.dance()` (AC: 3)** in `scripts/characters/player_zombie.gd`
  - [x] 2.1 `const ANIM_DANCE: StringName = &"dance"`. Look constants (named, with a "look value, not a GDD number" comment): `DANCE_HOP_PX := 4.0` (bounce height), `DANCE_BEAT_HZ := 2.0` (bounces per second; Body flips facing on every beat).
  - [x] 2.2 `func dance(duration_s: float) -> void`:
    1. `stop_hop()`, `stop_hug()` (Body back at rest), kill any running dance tween;
    2. if `_body.sprite_frames != null and _body.sprite_frames.has_animation(ANIM_DANCE)`: `_body.play(ANIM_DANCE)`; else `_play(ANIM_IDLE)`;
    3. `_dance_tween = create_tween()`, `tween_method(_set_dance_s, 0.0, duration_s, duration_s)`, then `tween_callback(_reset_dance)`.
    - `_set_dance_s(s)`: `Body.position.y = _body_rest_y - roundf(DANCE_HOP_PX * absf(sin(PI * DANCE_BEAT_HZ * s)))`; `Body.flip_h = int(floorf(DANCE_BEAT_HZ * s)) % 2 == 1`.
    - `_reset_dance()`: Body y back to rest, `flip_h = false`.
    - `Body` is `centered = false` at (−16, −31) on a 32 px sheet, so `flip_h` mirrors in place around the feet (same as `PartyZombie.face_left`). The `%HatSlot` rides with Body's y (it is Body's child), which is what Story 4.3 wants.
  - [x] 2.3 `func is_dancing() -> bool` and `func get_dance_tween() -> Tween` (tests), like the hop/hug getters.
  - [x] 2.4 `dance()` with null `sprite_frames` must not crash (Body is hidden; the tween still runs harmlessly). Same guard style as `hop`.
  - [x] 2.5 Header doc: replace "the dance arrives with 3.5" with a Dance paragraph (one dance tween; it owns Body y and flip_h; it cuts hop and hug; code bounce + flip until Story 3.6's `dance` 4f, which `dance()` plays when present).

- [x] **Task 3: `CongaLine.dance()` (AC: 4)** in `scripts/levels/zombie_run/conga_line.gd`
  - [x] 3.1 `var _dancing: bool = false` and `var _dance_time: float = 0.0`. `func dance() -> void`: sets `_dancing = true`, `_dance_time = 0.0`. No duration: the line dances until the run frame is freed (the report card replaces the scene). `func is_dancing() -> bool`.
  - [x] 3.2 In `step(delta)`: the chase stays exactly as it is (leader stopped → followers converge on their slots; the forward clamp still holds). Only the y and the facing change while `_dancing`:
    - `_dance_time += delta`;
    - `y = -roundf(DANCE_HOP_PX * absf(sin(PI * DANCE_BEAT_HZ * _dance_time + i * BOB_PHASE_STEP)))`;
    - facing: a follower still walking back to its slot (`slot < x - FACE_DEADZONE_PX`) faces left as today; once settled, `face_left(int(floorf(DANCE_BEAT_HZ * _dance_time + i * DANCE_BEAT_OFFSET)) % 2 == 1)`.
    - Look constants in `conga_line.gd`: `DANCE_HOP_PX := 4.0`, `DANCE_BEAT_HZ := 2.0`, `DANCE_BEAT_OFFSET := 0.5` (beats between neighbours, so they flip in a ripple). **Regex guard:** `test_no_tuning_literals_in_level_scripts` bans `\b(120|0\.15|26|0\.35|48|0\.2)\b` in `scripts/levels/zombie_run/*.gd`; `4.0`, `2.0` and `0.5` are fine; don't write `0.2`.
  - [x] 3.3 `join()` during the dance works unchanged (the newcomer walks back, then dances). `_place_badge()` still runs at the end of `step`, so the badge rides the last follower's bounce.
  - [x] 3.4 Header doc: replace "Story 3.5 adds the dance" with the dance rule (dance() switches the bob for a bounce and a beat flip, the chase is unchanged, no RNG, still no removal API).

- [x] **Task 4: Zombie Run level (AC: 2–4, 10)** in `scripts/levels/zombie_run/zombie_run_level.gd`
  - [x] 4.1 `var _dancing: bool = false`.
  - [x] 4.2 `on_run_ending(_reason)`:
    ```gdscript
    if _cfg == null:
        return 0.0
    _dancing = true
    if _move_tween != null and _move_tween.is_valid():
        _move_tween.kill()
    _zombie.dance(_cfg.dance_time_s)
    _conga.dance()
    return _cfg.dance_time_s
    ```
    Doc: "The end dance (Story 3.5, FR36): stops the zombie where it is and starts the zombie's and the line's dance; RunFrame waits the returned dance time before the report card." It reads `_conga_count` nowhere new: the line dances with what it draws (the logical count is the report's job, not the dance's).
  - [x] 4.3 `_process(delta)`: after the `_cfg` check, `if _dancing: _free_off_screen(); return`. This stops the amble and keeps `play_walk()`/`play_idle()` from overriding the dance animation. Freeing still runs (harmless: the camera no longer moves).
  - [x] 4.4 `func is_dancing() -> bool` (tests).
  - [x] 4.5 `on_char_accepted`: **no change**. `RunFrame` never judges a key after `ENDING`, so it is unreachable while dancing. Don't add a guard that could desync the queue from the session.
  - [x] 4.6 Class doc: an "End dance (Story 3.5, FR36)" paragraph; "Later stories" drops 3.5. Close the 3.1 review deferral ("`on_run_ending` returns 0.0 without stopping movement") in `deferred-work.md` (Task 8).
  - [x] 4.7 **Do not touch** `create_target_source`, the RNG order, `_spawn`, the brains/voice logic, the hand-off or `_free_off_screen`'s rules.

- [x] **Task 5: Completion bonus in `RunFrame` (AC: 5, 6, 8)** in `scripts/run/run_frame.gd`
  - [x] 5.1 `var _completion_bonus: int = 0`. In `_start_level`, next to `_duration = config.duration_s`: `_completion_bonus = maxi(0, config.completion_bonus)`.
  - [x] 5.2 `_record_result()`: pass `_completion_bonus` instead of the literal `0` as `p_bonus_brains`. Add `bonus=%d` to the existing `"ended level=..."` info log line (one line per run, not per frame).
  - [x] 5.3 Every recorded run is a completed run (quit never reaches `_record_result`), so the bonus applies to every end reason the frame records: `timer`, F6 (`debug_end_run` ends as `timer`), `caught`, `escaped`. Epic 8's different Pitchfork Panic bonuses (caught +10 / escaped +25) are not this story's problem: note it in `deferred-work.md`.
  - [x] 5.4 Update the header doc: "Quit to Menu commits the level's brains" stays; add "a completed run adds the level config's completion_bonus as the RunResult's bonus (Story 3.5)".
  - [x] 5.5 **No change** to the state machine, `_quit_to_menu`, `_request_pause` (it already ignores `ENDING`), `_on_web_platform_focus_lost`, `_send_result` or `PlayerData`.

- [x] **Task 6: Tests (AC: 11).** Read each file before editing; follow its patterns (process disabled, `custom_step` for tweens, `duplicate()` the config before `add_child`, a fake `PlayerData` on a temp `SaveService`).
  - [x] 6.1 `tests/unit/test_zombie_run_config.gd`: `dance_time_s == 2.0`; `validate()` rejects 0, negative and NaN (add a row to `test_each_bad_number_is_rejected` if that is its pattern); `completion_bonus == 10` already exists.
  - [x] 6.2 `tests/unit/test_player_zombie.gd`:
    - `dance(d)`: `is_dancing()`; stepping the dance tween shows Body y within [rest − DANCE_HOP_PX, rest], whole pixels, at least one lifted sample; `flip_h` true in the second beat and false in the first; after `custom_step(d + 0.01)` Body is at rest, `flip_h` false, not dancing.
    - `dance()` cuts a running hop and a running hug (both report not running, Body x at rest).
    - A second `dance()` restarts with one tween (the old one invalid).
    - With a fake `SpriteFrames` that has a `dance` animation, `dance()` plays `dance`; without it, it plays `idle`.
    - No sprite frames → no crash (pattern: `test_hop_without_sprite_frames_does_not_crash`).
  - [x] 6.3 `tests/unit/test_conga_line.gd`:
    - after `dance()`, y stays a whole number within [−DANCE_HOP_PX, 0], reaches below −BOB_PX at some step (it's bigger than the walk bob), and neighbours differ in phase;
    - settled followers flip facing over beats (a follower is left-facing at some step and right-facing at another);
    - followers still converge to their slots with the leader still; none ever passes `leader.x − SPACING_PX`;
    - `join()` during the dance adds a follower (or ticks the badge past the cap); counts never go down;
    - no step → nothing moves (pause freezes the dance too);
    - the badge still rides the last follower during the dance.
  - [x] 6.4 `tests/unit/test_zombie_run_level.gd` (new section `# --- end dance (Story 3.5) ---`):
    - `test_contract` currently asserts `on_run_ending(...) == 0.0`: change only that line to `_cfg().dance_time_s`.
    - `on_run_ending` returns the config's value (`_make(42, func(c): c.dance_time_s = 3.0)` → 3.0; catches a hard-coded 2.0).
    - Mid-scoot `on_run_ending` → the move tween is killed; the zombie x and the camera stay put over many `_level._process(0.1)` calls (no amble); `is_dancing()`; the zombie's dance tween is running; the conga line `is_dancing()`.
    - `_process` while dancing does not switch the zombie's animation to walk/idle (check `Body.animation` stays as `dance()` set it).
    - A villager hugged just before the end still poofs and joins during the dance (finish its poof after `on_run_ending`).
    - Regression guards, unchanged and run before/after: `test_run_rng_has_one_consumer`, `test_same_seed_same_letters_and_blocks`, `test_layout_does_not_depend_on_the_voice_rolls`, `test_letters_match_the_story_3_1_letter_bag`, the conga, hop/hug, camera and freeing tests.
    - Bad config: `dance_time_s = 0` → no source (`assert_push_error`, like `test_bad_conga_config_returns_no_source`).
  - [x] 6.5 `tests/integration/test_run_frame.gd`:
    - `test_zombie_run_keys_and_timer_end`: replace only the "no outro until Story 3.5" `DONE` check and the `bonus_brains == 0` check: after `_process(121.0)` → `ENDING`; `_process(1.9)` → still `ENDING`, `_nav` empty; `_process(0.2)` → `DONE`, one REPORT_CARD navigation; `result.bonus_brains == 10` read from the level's config (`frame.get_level().get_level_config().completion_bonus`), not a literal.
    - New: `test_zombie_run_end_rejects_keys_and_dances` — at `ENDING`, correct and wrong keys return false from `handle_key` and change keys, errors, active index, brains and conga count; `level.is_dancing()`.
    - New: `test_zombie_run_completed_run_pays_the_bonus_once` — fake `PlayerData`; type until 1+ brain; end by timer → on entering `ENDING` wallet == before + brains + bonus, run history has one record with `"brains" == brains + bonus`; after the dance and a few more `_process` calls still once.
    - New: `test_zombie_run_pause_is_refused_while_dancing` — Esc, the HUD pause button and `_on_web_platform_focus_lost` in `ENDING` leave it `ENDING`; `_paused` stays empty; the report card still arrives after the dance.
    - `test_zombie_run_quit_commits_the_level_brains` already proves FR13 (brains only, no bonus); add an `assert_eq(data.save_service.get_active_profile()["run_history"].size(), 0)` there.
    - New: `test_zombie_run_play_again_starts_fresh` — finish a run (timer + dance), take the report payload's level id, start a second frame with `{"level_id": that_id}` (no seed): its level is a new instance, `get_conga_count() == 0`, the conga line has 0 joined / 0 drawn / no badge, `get_active_index() == 0`, and its seed differs from the first frame's (seed 42 vs a random one; if they collide by chance the test is meaningless, so compare against a fixed first seed).
    - `test_timer_end` (test level) keeps `bonus_brains == 0`: the test level's config has no bonus. Leave it.
  - [x] 6.6 `tests/unit/test_report_card.gd` already covers the bonus line. Optionally add one test that builds the payload from a Zombie Run-like result (brains 7, bonus 10) and checks Brains Collected "17" and "+10 bonus"; skip if an equivalent exists.
  - [x] 6.7 Full suite, headless: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. **Confirm the baseline yourself at `d981c9b`** (3.4 ended at 720 plus 3 review-patch tests; report real numbers). Expect 0 `Parse Error`, the 3 expected villager-assert `SCRIPT ERROR` lines (`test_villager.gd`), 50 anchor warnings, nothing new.
  - [x] 6.8 Mutation habit (break once, confirm a test fails, restore, report honestly):
    - `on_run_ending` returns a hard-coded 2.0;
    - `RunFrame` passes 0 (or a literal 10) as the bonus;
    - the level keeps ambling while dancing;
    - the move tween not killed at the end;
    - `_process` still calls `play_idle()` while dancing;
    - `CongaLine.dance()` not called;
    - the dance draws from `_rng`.

- [ ] **Task 7: Manual (partial) checks (AC: 1–4, 7, 9)**
  - [ ] 7.1 (partial) Desktop (Godot MCP `run_project` + `get_debug_output`): the project and the level load with no new errors or warnings. The MCP can't type, so mark it partial, as in 3.1–3.4.
  - [ ] 7.2 (partial: the 2:00 timeout dance was not seen on screen) Web debug export (`--export-debug "Web" build/web/index.html`, `web-debug` on port 8060, the in-app browser pane, driven with `key` presses since the pane's `type` action is ignored):
    - play a short Zombie Run with 12+ followers (a burst early), then press **F6** (debug end, same path as the timer) to avoid waiting 2:00; also let one run time out at 2:00 to see the real path once;
    - the zombie stops and dances (bounce + flip), the line ripples, the badge rides along, keys during the dance do nothing, Esc does nothing;
    - after about 2 s the report card shows Brains Collected = brain blocks + 10 and the "+10 bonus" line;
    - Play Again → a fresh run: empty line, new letters, timer at 0:00, "Type the letter to start!";
    - quit a run from the pause panel → the menu's brains go up by the blocks only (read the overlay F3 or the save export);
    - console clean.
    Save screenshots (mid-dance with the badge, the report card with "+10 bonus", the fresh Play Again run) to `_bmad-output/implementation-artifacts/screenshots/3-5/`.
  - [x] 7.3 Look and tone at 1×: the dance reads as a happy wiggle, not a glitch (a 4 px bounce at 2 Hz; tune the look constants by eye if not, and record the final values). Nothing drops below the ground line y 192.

- [x] **Task 8: Wrap-up**
  - [x] 8.1 `deferred-work.md` "Deferred from: dev of story-3-5":
    - code dance (bounce + flip) until Story 3.6's `dance` 4f; party zombies have no dance frames in the GDD list, so the line keeps the code dance (3.6 decides);
    - no dance music or SFX (5.1);
    - the active target's arrow and the HUD letter stay visible during the dance (decide in 5.0 if it looks odd);
    - the bonus applies to every recorded end reason; Epic 8 must split caught/escaped bonuses (GDD: escaped +25);
    - the Router fade freezes the last moment of the dance (tree paused during the fade).
    Mark as done: the 2.4 "Completion bonus is `0` … until Story 3.5", the 2.9 "`test_level` has no completion bonus, so the '+N bonus' line is only seen in tests until Story 3.5" (now seen in Zombie Run), and the 3.1 review "`on_run_ending` returns 0.0 without stopping movement" (`~~…~~ Done in 3.5: …`, as earlier entries do).
  - [x] 8.2 Dev Agent Record, File List and Change Log. Set Status → `review` here, and `sprint-status.yaml` → `review`.

### Review Findings

- [x] [Review][Patch] `test_dance_frozen_without_step` is vacuous: it snapshots then compares with no `step()`/time in between, so it cannot fail [tests/unit/test_conga_line.gd:386]
- [x] [Review][Patch] Tasks 7.1 / 7.2 ticked `[x]` although the Dev Record says they were only partial (2:00 timeout dance not seen on screen); untick or mark "(partial)" [3-5 story file, Task 7]
- [x] [Review][Patch] `CongaLine.dance()` / `on_run_ending` not idempotent: a second call resets `_dance_time` and restarts the tween; add an `if _dancing: return` guard [scripts/levels/zombie_run/conga_line.gd:86]
- [x] [Review][Patch] `ZombieRunConfig.validate` accepts `INF` for `dance_time_s`; add `is_finite()` [scripts/resources/zombie_run_config.gd:65]
- [x] [Review][Patch] Header comment spliced mid-sentence ("...the x N badge / ... and \"never shrinks\"") [tests/unit/test_conga_line.gd:3]
- [x] [Review][Defer] Dance constants (`DANCE_HOP_PX` 4.0, `DANCE_BEAT_HZ` 2.0) duplicated in player_zombie.gd and conga_line.gd, can drift [scripts/characters/player_zombie.gd:36] — deferred, pre-existing
- [x] [Review][Defer] Nothing ties `dance_time_s` to `hug_time_s`; a late villager could poof after the report card opens with odd config [scripts/levels/zombie_run/zombie_run_level.gd:182] — deferred, pre-existing
- [x] [Review][Defer] AC7 "end to end" report-card proof is manual plus `test_mock_example_values`; no Zombie Run payload test (Task 6.6 optional) [tests/unit/test_report_card.gd:89] — deferred, pre-existing

## Dev Notes

### What this story is (and isn't)

- It closes the Zombie Run loop: the 2.0 s end dance (zombie + conga line), the +10 completion bonus from config through `RunResult` into the wallet, and proof that quit and Play Again behave.
- **Most of the plumbing already exists.** `RunFrame` already has `ENDING` (input off, clock paused, `on_run_ending()` → outro wait → `DONE` → report card), already records on entering `ENDING`, and `record_run` already adds `total_brains()`. The report card already shows "+N bonus" when `bonus_brains > 0`. `completion_bonus = 10` is already in `zombie_run.tres`. **Don't rebuild any of that.** The real gaps are: the literal `0` bonus in `RunFrame._record_result`, `ZombieRunLevel.on_run_ending()` returning 0.0, and no dance.
- **New files:** none (screenshots only).
- **Updated files:**
  - `scripts/resources/zombie_run_config.gd`, `scripts/resources/level_config.gd` (doc only), `data/levels/zombie_run.tres`
  - `scripts/characters/player_zombie.gd`
  - `scripts/levels/zombie_run/conga_line.gd`, `scripts/levels/zombie_run/zombie_run_level.gd`
  - `scripts/run/run_frame.gd`
  - tests: `test_zombie_run_config.gd`, `test_player_zombie.gd`, `test_conga_line.gd`, `test_zombie_run_level.gd`, `tests/integration/test_run_frame.gd` (+ optionally `test_report_card.gd`)
  - `deferred-work.md`, `sprint-status.yaml`
- **Don't build:**
  - dance frames or any art (3.6); the code dance is a placeholder;
  - groans / `start_ambience` / `stop_ambience` (3.7);
  - dance music, SFX, the brain-counter count-up (5.0/5.1);
  - the Welcome Gift redirect after the first completed run (4.5, in `report_card.gd` `_leave()`);
  - different bonuses per end reason (Epic 8);
  - any change to `PlayerData`, `RunResult`, `report_card.gd`, `LevelBase`, `Router` or the save schema.

### Key design decisions (follow these)

- **The level owns the outro; `RunFrame` owns the timing and the money.** The level never writes `PlayerData` (architecture rule) and never touches the clock: it only returns the outro length from `on_run_ending()` and plays visuals. `RunFrame` waits with `_outro_left` (already there) and adds the bonus. Keep it that way.
- **Bonus source = `LevelConfig.completion_bonus`, read once in `_start_level`.** It's a balancing value (architecture Configuration table: "completion bonus" lives in the `LevelConfig`). The test level's 0 keeps every Story 2.x test unchanged.
- **Recorded before the dance.** `_record_result()` runs on entering `ENDING`, so a tab close during the dance keeps the run and the brains (Story 2.8 decision). Don't move it to `DONE`.
- **Stop, don't finish, the scoot.** Killing `_move_tween` at the end freezes the zombie (and the camera, which `_set_zombie_x` moves with it) mid-scoot. It is deterministic and costs nothing; a 0.15 s glide into the dance adds nothing a kid would see.
- **The dance is a tween on the zombie, `_process` on the line.** Same split as 3.2–3.4: the player zombie's one-shot moves (hop, hug, now dance) are node-bound tweens on `Body`; the followers are driven every frame by `CongaLine.step()`. Both freeze with the tree and draw no randomness.
- **`dance()` owns Body y and `flip_h`.** It cuts the hop (y) and the hug (x) first, so nothing fights it. Nothing restarts a hop or hug after it: no key is judged in `ENDING`.
- **Never shrinks still holds.** The dance changes only y and facing. Joins during the dance are fine.
- **No RNG.** Phases come from the index and accumulated time. `test_run_rng_has_one_consumer` must pass unchanged.

### Existing code: current state, what changes, what must be preserved

- **`run_frame.gd`**: `_process` → `RUNNING`: ends at `elapsed >= _duration` via `_end_run(TIMER)`; `ENDING`: counts `_outro_left` down, then `DONE` → `_send_result()` → REPORT_CARD `{result, new_best}`. `_set_state(ENDING)`: clock pause, `TypingInput.active = false`, caps hint off, hands cleared, `outro = _level.on_run_ending(reason)` (non-finite → 0), `_record_result()`. `_record_result()` builds `RunResult.create(..., _level.get_brains_earned(), 0, LETTER_POOL_ALL, reason)` → `record_run`. `_quit_to_menu()` (PAUSED only): `add_brains(level brains)`, menu. `_request_pause()` ignores `ENDING`/`DONE`. **Change:** the bonus only. **Preserve:** everything else.
- **`zombie_run_level.gd`** (after 3.4): `on_run_ending` returns 0.0; `_process` ambles, switches walk/idle and frees off-screen targets; `_move_tween` is the single scoot tween; `%CongaLine` configured in `_ready`. **Change:** `on_run_ending`, the `_dancing` early return in `_process`, `is_dancing()`. **Preserve:** the rest, byte-for-byte in behaviour.
- **`player_zombie.gd`**: hop (tween on Body y), hug (tween on Body x), `_play()` restarts an animation only when it changes. `SpriteFrames` has `idle` 2f and `walk` 4f only. **Add** `dance()` and its getters.
- **`conga_line.gd`**: `join()`, `step()` (chase + walk bob + facing + badge), getters. **Add** `dance()`, `is_dancing()` and the dancing branch in `step()`.
- **`report_card.gd`**: shows `%BonusLabel` "+N bonus" and adds the bonus row to the reveal only when `bonus_brains > 0`; `%BrainsValue` = `total_brains()`. Play Again → `RUN {"level_id": _level_id}` with no seed. **No change.**
- **`player_data.gd` `record_run`**: appends the record, updates best WPM, adds `result.total_brains()` inline with one `brains_changed`, emits `run_recorded`, one `request_save`. **No change.**

### Testing notes

- GUT 9.7.1. No new `class_name`, but run `--import` anyway before the suite.
- `PlayerZombie` tests: the dance tween is node-bound; on a process-disabled node, advance it with `get_dance_tween().custom_step(dt)` (as the hop/hug tests do).
- `CongaLine` tests: the node is disabled; drive it with `step(delta)`.
- Integration: `frame._process(delta)` drives the clock and the outro; the level is a child of the disabled frame, so its `_process` doesn't run by itself (call `level._process` where needed).
- `test_zombie_run_keys_and_timer_end` already exists; edit only its last assertions. Don't hard-code brain counts that depend on the layout for seed 42 in new tests (3.3/3.4 review deferral): read `get_brains_earned()` and the config.
- Keep every touched file LF (`.gitattributes` `eol=lf`).

### Previous story intelligence (3.4)

- The baseline is often off by a few from the story's number (review patches add tests): confirm it yourself.
- 3.4's mutation pass found one rule (the forward clamp) that no test could catch because it was redundant; report such cases honestly instead of forcing a test.
- `assert` in headless GUT logs a `SCRIPT ERROR` and doesn't abort: use `Log` + safe returns in code that tests reach.
- Small, short motions (hop 16 px, hug 3 px) were hard to see in browser-pane screenshots; the dance lasts 2 s and the whole line moves, so it should be visible, but prove the rules with tests first.
- F6 (debug end run) ends exactly like the timer and is the fastest way to see the dance in the web build.
- The perf check in 3.4 (22.7 ms worst frame) covered a full run with 12+ followers; the dance adds 12 extra `sin` calls per frame and one tween, so no new perf check is needed.

### Git intelligence

- One commit per story; HEAD is `d981c9b Story 3.4: conga line`, and the working tree was clean at story creation. Suggested message: `Story 3.5: run end dance and brains award`.

### Latest tech notes (Godot 4.7.2)

- `SpriteFrames.has_animation(name)` checks for the `dance` animation before playing it.
- `Tween.tween_method(callable, from, to, duration)` with `from = 0.0, to = duration` passes elapsed seconds to the method, which keeps the beat in Hz independent of the dance length.
- `AnimatedSprite2D.flip_h` with `centered = false` and a 32 px frame at x −16 mirrors around the node origin (the feet).
- Killing a `Tween` (`kill()`) leaves the property at its last value: the zombie stays where the scoot was cut, and the camera with it.

### Project Structure Notes

- No new files or folders; all changes sit in the files the architecture tree already lists.
- No new autoloads, InputMap actions, save fields, audio or art.

### Project Context Rules

There is no `project-context.md`. The binding rules come from `_bmad-output/game-architecture.md`, `docs/art-style-sheet.md` and the UX spines:
- Static typing everywhere; `:=` only when the type is obvious.
- Levels never read input, never touch the clock, never write `PlayerData`, never call the Router; `RunFrame` awards brains and records the run.
- Every `RunFrame` transition goes through `_set_state()`; typing is rejected in `PAUSED`, `COUNTDOWN`, `ENDING`, `DONE`.
- Game numbers come only from config (`dance_time_s`, `completion_bonus`); look values are named consts.
- Randomness only through injected RNGs; the dance uses none.
- Tweens are node-bound and fire-and-forget; never `await` in typing callbacks.
- Logging via `Log`, never in `_process` or per key.
- Kid-safe, goofy tone (NFR10): a happy dance, nothing scary.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.5: Run End Dance and Brains Award; #Story 3.6 (dance 4f); #Story 4.5 (Welcome Gift after the first completed run)]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory (FR13, FR19, FR22, FR36, FR52, NFR10, NFR16)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Win/Loss Conditions; #Level 1: Zombie Run ("End"); #Economy table (+10 on completion)]
- [Source: _bmad-output/game-architecture.md#State Management (ENDING = level outro); #Typing Pipeline & Level Contract (`on_run_ending` returns the outro length; levels never write PlayerData); #Configuration (completion bonus in LevelConfig)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md (Run "Ending" state: input stops, Zombie Run dance 2.0 s)]
- [Source: _bmad-output/implementation-artifacts/3-4-conga-line.md; deferred-work.md (2.4 bonus 0, 2.9 bonus line, 3.1 on_run_ending)]
- [Source: scripts/run/run_frame.gd; scripts/levels/zombie_run/zombie_run_level.gd, conga_line.gd; scripts/characters/player_zombie.gd; scripts/resources/level_config.gd, zombie_run_config.gd; scripts/screens/report_card.gd; scripts/autoloads/player_data.gd; tests/integration/test_run_frame.gd; tests/unit/test_zombie_run_level.gd, test_conga_line.gd, test_player_zombie.gd, test_zombie_run_config.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), Claude Code desktop.

### Debug Log References

- Baseline at `d981c9b`: **722** tests, all passing (not 723 as the story guessed), 0 `Parse Error`, 3 expected villager-assert `SCRIPT ERROR`s, 50 anchor warnings.
- Final: **752** tests (+30), all passing; 0 `Parse Error`; the same 3 `SCRIPT ERROR`s; 50 anchor warnings. One extra "player zombie has no sprite frames" warning comes from the new `test_dance_without_sprite_frames_does_not_crash` (expected, consumed with `assert_push_warning`).
- Red first for every task: config (missing field), `PlayerZombie` / `CongaLine` (parse errors on the missing members), level (8 failures: 0.0 outro, amble, walk animation, hop not cut, ...), `RunFrame` (3 failures on `bonus_brains` 0 vs 10).

### Completion Notes List

- **Config:** `ZombieRunConfig.dance_time_s` (2.0 in `zombie_run.tres`, `validate()` rejects 0, negative and NaN with the `not (x > 0)` form). `completion_bonus = 10` was already there; `LevelConfig.completion_bonus` doc updated.
- **`PlayerZombie.dance(duration_s)`:** cuts hop and hug, kills any running dance, plays `dance` if the SpriteFrames has it (else `idle`), then one tween runs `_set_dance_s` over elapsed seconds: Body y = rest - round(4 * |sin(pi * 2 * s)|), `flip_h` on odd beats; `_reset_dance` puts y and facing back. `is_dancing()`, `get_dance_tween()`. Look constants `DANCE_HOP_PX = 4.0`, `DANCE_BEAT_HZ = 2.0`, unchanged after the 1x look check.
- **`CongaLine.dance()`:** sets `_dancing` and resets `_dance_time`. In `step()` the chase and forward clamp are untouched; while dancing, y = -round(4 * |sin(pi * 2 * t + i * 0.6)|) and facing = walking back OR odd beat (beat = floor(2 * t + i * 0.5)). The badge still rides the last follower. No RNG, no removal API. Look constants `DANCE_HOP_PX 4.0`, `DANCE_BEAT_HZ 2.0`, `DANCE_BEAT_OFFSET 0.5` (the literal-guard regex is still clean).
- **Zombie Run level:** `on_run_ending()` sets `_dancing`, kills `_move_tween` (zombie and camera freeze mid-scoot), starts both dances and returns `_cfg.dance_time_s`. `_process` returns early after `_free_off_screen()` while dancing, so there is no amble and no walk/idle switching. `is_dancing()`. `on_char_accepted`, the RNG order, `_spawn`, the hand-off and the freeing rules are unchanged. Also removed two stale doc claims that "Story 3.5's dance reads" `_conga_count` (per Task 4.2 it does not).
- **`RunFrame`:** `_completion_bonus = maxi(0, config.completion_bonus)` in `_start_level`, passed as `bonus_brains` in `_record_result()`; the "ended" log line now says `bonus=%d`. State machine, quit, pause and `PlayerData` are unchanged.
- **Tests (+30):** config +2 (value, rejects 0/-2/NaN) plus a row in the bad-number table; `PlayerZombie` +7 (bounce range, whole px, flip per beat, rest after, cuts hop/hug, restart with one tween, `idle` vs `dance` frames, no frames); `CongaLine` +7 (bigger than the bob, ripple, beat flips, converge/never pass, join mid-dance and the badge tick, frozen without step, badge rides the dance); level +9 (returns the config value with 3.0, mid-scoot stop plus camera lock, no amble from idle, animation kept (placeholder), animation kept with real `dance` frames, cuts hop, late poof joins, no RNG draws, bad config) and `test_contract` now expects `dance_time_s`; `RunFrame` +5 (keys rejected while dancing, bonus paid once with the record total, F6 pays the bonus, pause refused while dancing, Play Again fresh), and `test_zombie_run_keys_and_timer_end` now checks ENDING at 1.9 s, DONE at 2.1 s and the bonus from config; the quit test also asserts an empty run history.
- **6.6 skipped:** `test_report_card.gd::test_mock_example_values` already builds a result with brains 35 + bonus 10 and checks Brains Collected "45" and "+10 bonus".
- **Mutation pass (6.8), full suite each time, all restored:** hard-coded 2.0 -> 1 failing; bonus 0 -> 3; literal 10 -> 4 (the test-level runs expect 0); amble while dancing -> 4; scoot tween not killed -> 1; `play_idle()` while dancing -> 1; `CongaLine.dance()` not called -> 2; the dance draws from `_rng` -> 1. The `play_idle()` mutation was invisible at first: with placeholder art the dance plays `idle`, so I added `test_process_while_dancing_keeps_the_dance_frames` (real `dance` frames on the zombie), which catches it.
- **7.1 desktop (partial, as in 3.1-3.4):** Godot MCP `run_project` loads with no errors or warnings (`[INFO][save] loaded save.json` only). The MCP can't type.
- **7.2 web debug** (fresh `--export-debug "Web"`, `web-debug` :8060, browser pane, `key` presses): 20 keys gave 5 brains and a 12-follower line with "×15". F6 needs the overlay open (F3, F6, F3). In the dance the clock froze, a key was not judged (Keys/Errors unchanged), Esc did nothing, the hands went dark, the followers bounced at staggered heights, a late poof joined mid-dance and the badge went to "×16" riding along (`mid-dance-badge-x16.jpg`). A later run caught the zombie flipped left and then right, with newcomers walking in (`dance-zombie-flipped-left.jpg`, `dance-facing-right-newcomers-join.jpg`). The report card showed Brains Collected 15 = 5 + 10 and "+10 bonus" (`report-card-plus-10-bonus-f6.jpg`); the saved record has `"brains": 15`. Play Again gave a fresh run: new letters, empty line, 2:00, "Type the letter to start!" (`play-again-fresh-run.jpg`). Quit from the pause panel after 1 block: wallet 52 -> 53 (blocks only), run history still 8 (read from IndexedDB `/userfs`). A full 2:00 timeout reached the report card with Lesson Time 2:00, Brains 11 = 1 + 10 and "+10 bonus" (`report-card-plus-10-bonus-timer-2-00.jpg`). Console clean: one `ended ... bonus=10` per completed run, none on quit. **Partial / disclosed:** the dance of the 2:00 run itself wasn't caught on screen (batch timing), and a third F6 run stayed in ENDING because the browser pane had been hidden: `requestAnimationFrame` made 0 calls in 2.5 s, so the game only advanced on screenshots. That is the environment, not the code: the same flow worked while the pane was visible, and the 1.9 s / 2.1 s timing is pinned by tests. Noted in `deferred-work.md`.
- **7.3 look:** at 1x the dance reads as a happy wiggle (a 4 px bounce with a left/right flip), and the line ripples. Nothing drops below the ground line y 192 (the bounce only lifts). Look values kept as specified.
- **Deferred-work:** closed the 2.4 bonus-0, the 2.9 "+N bonus only in tests" and the 3.1 review `on_run_ending` entries; added the 3.5 dev section (placeholder dance, no SFX, arrow/HUD letter during the dance, bonus on every end reason with Epic 8 to split, Router fade freeze, hidden-pane rAF note).

### File List

- `data/levels/zombie_run.tres` (modified)
- `scripts/resources/zombie_run_config.gd` (modified)
- `scripts/resources/level_config.gd` (modified, doc only)
- `scripts/characters/player_zombie.gd` (modified)
- `scripts/levels/zombie_run/conga_line.gd` (modified)
- `scripts/levels/zombie_run/zombie_run_level.gd` (modified)
- `scripts/run/run_frame.gd` (modified)
- `tests/unit/test_zombie_run_config.gd` (modified)
- `tests/unit/test_player_zombie.gd` (modified)
- `tests/unit/test_conga_line.gd` (modified)
- `tests/unit/test_zombie_run_level.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/3-5-run-end-dance-and-brains-award.md` (this story)
- `_bmad-output/implementation-artifacts/screenshots/3-5/` (new: `mid-dance-badge-x16.jpg`, `dance-zombie-flipped-left.jpg`, `dance-facing-right-newcomers-join.jpg`, `report-card-plus-10-bonus-f6.jpg`, `report-card-plus-10-bonus-timer-2-00.jpg`, `play-again-fresh-run.jpg`)

### Change Log

- 2026-10-05: Story 3.5 implemented: the 2.0 s end dance (`dance_time_s` in config; `PlayerZombie.dance()` with a code bounce and flip; `CongaLine.dance()` with a rippling bounce and beat flips; the level stops the scoot and the amble and returns the dance time), the +10 completion bonus from `LevelConfig` through `RunResult` into the wallet and run history, 30 new tests (752 total, all passing), a mutation pass and web checks with screenshots. Status set to review.
