---
baseline_commit: 453ff65
---

# Story 3.1: Zombie Run Level, Target Queue and Zombie Movement

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want my zombie to walk toward the next letter and zip forward every time I type it right,
so that fast typing makes my zombie race along.

## Acceptance Criteria

1. **Level, registry and config.** `scenes/levels/zombie_run/zombie_run_level.tscn` (root script `scripts/levels/zombie_run/zombie_run_level.gd`, extends `LevelBase`) is registered as `&"zombie_run"` in `data/levels/level_registry.tres` with `display_name = "Zombie Run"` and `debug_only = false`. Its config `data/levels/zombie_run.tres` holds: duration 120 s, target spacing 48 px, 3 visible upcoming targets, amble 24 px/s, idle stop 24 px before the target, scoot 0.15 s, brain block every 4, completion bonus 10, `case_sensitive = false`, `space_is_input = false`, letter target mode, and all 26 lowercase letters (FR28). No tuning number from this list appears as a literal in the level scripts.
2. **Menu entry.** On the placeholder main menu, choosing Zombie Run starts a run through `Router.go(Router.Screen.RUN, { "level_id": &"zombie_run" })`, and the run actually loads (it no longer falls back to the menu).
3. **Target queue (FR30).** In a running Zombie Run, targets sit 48 px apart along the path; the active target plus the next 3 are shown, each with its letter on a small parchment tag; only the active one bobs and carries the candy-yellow down-arrow marker, and its letter always equals the HUD target (`TypingSession` current target). Targets are generic placeholders (brain blocks and villagers arrive in 3.2 / 3.3). The letters come from a `LetterBagSource` with its own child RNG, so the same seed always gives the same targets.
4. **Amble and idle (FR31).** While the zombie is short of the active target's approach point (target x − 24 px) and no scoot is running, it ambles forward at 24 px/s, stops exactly at the approach point and idles there (never overshoots).
5. **Correct key = instant advance + scoot (FR1, FR31, NFR2).** On `on_char_accepted`, in the same call: the logical active index advances, the old target resolves, the next target becomes active (bob + arrow), one new target is spawned at the far end of the queue, and the zombie's single move tween is killed and restarted from its current visual position to the new approach point over 0.15 s. Several keys in quick succession chain scoots (each retargets the same tween), so walking never caps typing speed. Nothing in the typing path awaits or defers.
6. **Wrong key (FR2).** `on_char_rejected` changes nothing in the world (index, zombie, targets).
7. **Camera.** The view follows the zombie so it stays at a fixed screen x, upcoming targets never leave the screen, and resolved targets are freed once they have scrolled off the left edge. The HUD band, pause button, start prompt, Caps Lock hint, pause panel and countdown do **not** move with the camera.
8. **Pause and end.** The level freezes with the tree while paused / counting down (amble, bob and scoot stop and resume where they were). At the end of the clock the run ends through `RunFrame` as today (`on_run_ending` returns 0.0 for now; the dance is Story 3.5) and the report card shows "Zombie Run". `get_brains_earned()` is 0 until Story 3.2.
9. **Placeholder art.** The player zombie uses the approved prototype sheets (`zombie_idle.png` 2f @ 8 fps, `zombie_walk.png` 4f @ 10 fps). Targets, the arrow marker and the playfield backdrop are placeholders in palette colours only, with 1 px ink outlines on props; final frames arrive in Story 3.6.
10. **Tests.** New GUT tests cover the config values, the registry entry, the queue (count, spacing, letters, active marker, HUD match), amble/idle, scoot + chaining, camera bounds, off-screen freeing, wrong-key no-op and seed determinism; `test_level_registry.gd`'s "Zombie Run arrives with Story 3.1" assertion is flipped; an integration test runs a Zombie Run through the real `RunFrame`. The full suite passes.

## Tasks / Subtasks

- [x] **Task 1: Config resources (AC: 1)**
  - [x] 1.1 `scripts/resources/level_config.gd`: add `@export var completion_bonus: int = 0` with a `##` doc ("Brains added on a completed run (Zombie Run 10). Read by RunFrame from Story 3.5."). Base class because every level has one and `RunFrame` must read it without knowing the level. **Do not wire it into `RunResult` here** — `RunFrame._record_result()` keeps passing `0` until Story 3.5 (deferred-work 2.4 line).
  - [x] 1.2 New `scripts/resources/zombie_run_config.gd`: `class_name ZombieRunConfig extends LevelConfig`, with typed, documented exports (neutral defaults, real values only in the `.tres`):
    - `target_spacing_px: float` (48), `visible_upcoming: int` (3), `amble_speed_px_s: float` (24), `approach_gap_px: float` (24, "the zombie idles this far before the active target"), `scoot_time_s: float` (0.15), `brain_block_every: int` (4, used by Story 3.2), `letter_pool: Array[String]` (a–z).
    - Why a subclass and not more fields on `LevelConfig`: these numbers are Zombie Run only (Horde Rush / Pitchfork Panic have their own), and a `ZombieRunConfig` *is* a `LevelConfig`, so `LevelBase.config`, `RunFrame`, `TypingInput` and the HUD keep working unchanged. Architecture's "LevelConfig holds tuning numbers" is still true.
  - [x] 1.3 New `data/levels/zombie_run.tres` (`script_class="ZombieRunConfig"`): `duration_s = 120.0`, `case_sensitive = false`, `space_is_input = false`, `target_mode = 0` (LETTER), `completion_bonus = 10`, and the 7 fields above; `letter_pool` = the 26 letters `"a"`..`"z"` written out in order. Hand-written `.tres` like `test_level.tres` (ext_resource the script; let Godot add the uid on import).

- [x] **Task 2: Player zombie scene (AC: 9)**
  - [x] 2.1 New `scenes/characters/player_zombie.tscn` + `scripts/characters/player_zombie.gd` (`class_name PlayerZombie extends Node2D`). Child `Body` (`AnimatedSprite2D`, `centered = false`) with an inline `SpriteFrames`: `idle` (2 `AtlasTexture` regions of `zombie_idle.png`, 8 fps, loop) and `walk` (4 regions of `zombie_walk.png`, 10 fps, loop) — follow `scenes/characters/professor_zombie.tscn` exactly (32×32 regions, frames side by side). Place `Body` so the node origin is the zombie's **feet centre** (`Body.position = Vector2(-16, -31)` if the soles are on local row 30 like the professor — check the sheet's lowest opaque row; the style sheet's "one ground line" rule guarantees it is the same in every frame).
  - [x] 2.2 Add an empty `%HatSlot` (`Node2D`) under `Body` at the head point as a placeholder for Story 4.3 (same as Professor Zombie). No hat code.
  - [x] 2.3 API: `play_idle()` / `play_walk()` (no-op if already playing that animation). If `sprite_frames` is null, `Log.warn` and hide (NFR16: a missing sprite never stops a run — mirror `professor_zombie.gd`).
  - [x] 2.4 Do **not** add hop/hug/dance animations or sheets (3.2/3.3/3.5/3.6).

- [x] **Task 3: Generic target scene (AC: 3, 5, 9)**
  - [x] 3.1 New `scenes/levels/zombie_run/zombie_run_target.tscn` + `scripts/levels/zombie_run/zombie_run_target.gd`, `class_name ZombieRunTarget extends Node2D`. This is the **base** that Story 3.2's `brain_block` and 3.3's `villager` will extend, so keep its API small and virtual-friendly:
    - `setup(letter: String, slot: int) -> void` — called **before** `add_child` (architecture Entity Patterns). Stores both; the node origin is the target's feet centre on the ground line.
    - `get_letter() -> String`, `get_slot() -> int`, `is_active() -> bool`, `is_resolved() -> bool`.
    - `set_active(active: bool) -> void` — shows/hides `%Arrow` and starts/stops the bob.
    - `resolve() -> int` — marks it resolved (never goes back), hides the tag and the arrow, stops the bob, switches the body to its resolved look, returns brains earned (**0** for the generic target; 3.2 overrides to return 1). Calling it twice is a no-op returning 0.
  - [x] 3.2 Visuals (placeholder, palette colours only — hex values in `docs/art-style-sheet.md` §2):
    - **Body:** a code-drawn box about 20×20 px standing on the ground line (`_draw()`): fill `parchment-shade` `#D9BC84` with a 1 px `ink` `#1E1428` outline; resolved look = fill `stone-light` `#BDB6C4`. (Code-drawn shapes are the accepted placeholder pattern, cf. `zombie_hands.gd`.)
    - **Tag (`%Tag`):** a small parchment `#F6E7C1` panel with 1 px ink border (flat `StyleBoxFlat`, zero corner radius like the HUD placeholders) above the body, holding a `Label` with the letter in ink at **16 px** (text floor; font comes from the project theme, Press Start 2P — 16 px glyph is 16×16). Tag ≈ 24×24 px.
    - **Arrow (`%Arrow`):** a small down-pointing triangle above the tag, `candy-yellow` `#FFD23F` with 1 px ink outline (`Polygon2D` + `Line2D`, or `_draw()`). Visible only while active.
    - **Bob:** only the active target; moves the body+tag+arrow up and down by a couple of pixels (layout constants in this script, e.g. `BOB_PX := 2.0`, `BOB_PERIOD_S := 0.6` — UX look values, not GDD numbers). Drive it from `_process` with an accumulated time (it then freezes with the tree), or a looping tween created with the node's own `create_tween()`. Bob a child `%Visual` node, never the target's own `position` (the level owns that).
  - [x] 3.3 No collision, no physics, no input, no autoloads. No sound (3.2/3.7).

- [x] **Task 4: Zombie Run level (AC: 1, 3–8)** — `scenes/levels/zombie_run/zombie_run_level.tscn`, `scripts/levels/zombie_run/zombie_run_level.gd`
  - [x] 4.1 Scene tree (root `ZombieRunLevel`, `Node2D`, script, `config = ExtResource(zombie_run.tres)`):
    ```
    ZombieRunLevel (Node2D)            # screen space = playfield space (LevelHost is at 0,0)
    ├── Backdrop (Node2D)              # static, NOT scrolled: sky + ground placeholder rects
    └── World (Node2D) %World          # scrolled by the "camera" (position.x = -camera_x)
        ├── Targets (Node2D) %Targets
        └── PlayerZombie %Zombie       # instance of player_zombie.tscn, drawn above targets
    ```
  - [x] 4.2 **Camera — do NOT use `Camera2D`.** `RunFrame` is a `Control`, and the HUD, pause panel and countdown are plain `Control`s in the same canvas layer as `%LevelHost`. A `Camera2D` changes the viewport's canvas transform, so it would scroll the whole HUD band with the world. Instead the level scrolls `%World`: one helper `_set_zombie_x(x: float)` sets `%Zombie.position.x = x` **and** `%World.position.x = ZOMBIE_SCREEN_X - x` in the same call, so the zombie's screen x is exactly constant and nothing jitters by a frame. Both the amble (`_process`) and the scoot tween go through this helper (`tween_method(_set_zombie_x, from, to, scoot_time_s)`); never tween `position:x` directly (that would leave the camera one frame behind the zombie).
  - [x] 4.3 Layout constants (UX/layout values, named `const`s in the level script with a `##` note; they are not GDD tuning numbers):
    - `GROUND_Y := 192.0` — feet line in playfield px. Chosen so characters (32 px) and tags sit **above** the HUD's Caps Lock hint (y 196–224) and start prompt strip (y 228–252) that overlay the playfield bottom (approved Story 2.5 sketch). Ground/path placeholder fills y 192–256 below it.
    - `ZOMBIE_SCREEN_X := 224.0` — where the zombie stays on screen. Leaves ~224 px behind it for the Story 3.4 conga line and puts the 4 queued targets at screen x ≈ 248–392, clear of the pause button (600, 16). Story 3.4 may retune it.
    - `FIRST_TARGET_X` — world x of slot 0; pick it so that at start the zombie (see 4.5) is on screen at `ZOMBIE_SCREEN_X` (e.g. derive: `FIRST_TARGET_X = ZOMBIE_SCREEN_X` and the zombie starts at `approach_x(0) - target_spacing_px`). Derive from config where possible so no GDD number is retyped.
  - [x] 4.4 Config access: `var _cfg: ZombieRunConfig` set from `config as ZombieRunConfig` in `_ready()`. If it is null (wrong resource), `assert` + `Log.error(&"level", ...)` (contract violation) — `RunFrame` already fails safe to the menu if `create_target_source` returns null, so return null from there in that case.
  - [x] 4.5 Pure position helpers (public so tests use them): `target_x(slot: int) -> float = FIRST_TARGET_X + slot * _cfg.target_spacing_px`; `approach_x(slot: int) -> float = target_x(slot) - _cfg.approach_gap_px`. Zombie start: `approach_x(0) - _cfg.target_spacing_px` (so the opening amble is visible: 2 s at 24 px/s), set via `_set_zombie_x` in `_ready()`.
  - [x] 4.6 `create_target_source(rng)` (called once by `RunFrame` right after the level's `_ready`, LevelBase doc):
    - child RNG rule from `LevelBase`: `var child := RandomNumberGenerator.new(); child.seed = rng.randi()`; `_source = LetterBagSource.new(child, _cfg.letter_pool)`. Keep `_rng = rng` for Story 3.2's group shuffle (draw nothing from it now).
    - Spawn slots `0 .. visible_upcoming` (4 targets): letters `[_source.current()] + _source.peek(_cfg.visible_upcoming)`. Slot 0 `set_active(true)`.
    - Return `_source`.
  - [x] 4.7 `on_char_accepted(expected, _index)` — **logic leads, visuals chase** (architecture Novel Pattern), all synchronous:
    1. `var done := _queue.pop_front()`; `_active_index += 1` (own counter; `expected` should equal `done.get_letter()` — `assert` it in debug, never branch on it).
    2. `_brains += done.resolve()` (0 today); move `done` to `_resolved`.
    3. `_queue[0].set_active(true)`.
    4. Spawn slot `_active_index + _cfg.visible_upcoming` with letter `_source.peek(_cfg.visible_upcoming)[_cfg.visible_upcoming - 1]` (the session has **already advanced** the source when this is called, so `current()` is the new active letter — LevelBase doc).
    5. `_scoot_to(approach_x(_active_index))`: if `_move_tween` is valid, `kill()` it; `_move_tween = create_tween()` (node-bound, so it pauses with the tree); `tween_method(_set_zombie_x, %Zombie.position.x, target, _cfg.scoot_time_s)`.
    - Zombie animation: `play_walk()` while scooting or ambling, `play_idle()` when at the approach point with no tween running (check in `_process`; no `await`, no `finished` signal gating input).
  - [x] 4.8 `_process(delta)`:
    - Amble: if no running tween and `%Zombie.position.x < approach_x(_active_index)`: `_set_zombie_x(minf(x + _cfg.amble_speed_px_s * delta, approach_x(_active_index)))` (exactly the architecture's implementation guide).
    - Free resolved targets once off screen: a resolved target whose `position.x + TARGET_HALF_WIDTH < camera_x` (`camera_x = -%World.position.x`) → `queue_free()` and drop it from `_resolved`. Unresolved targets are never freed.
    - No logging in `_process`.
  - [x] 4.9 `on_char_rejected` — not overridden (base no-op is correct: FR2 "no world change"). `on_run_started` — not needed. `on_run_ending(_reason) -> float` returns `0.0` (Story 3.5 adds the 2.0 s dance). `get_brains_earned() -> int` returns `_brains` (stays 0 until 3.2).
  - [x] 4.10 Getters for tests/debug (plain, no gate): `get_active_index() -> int`, `get_queue() -> Array[ZombieRunTarget]` (unresolved, active first; return a duplicate), `get_resolved_count() -> int`, `get_zombie_x() -> float`, `get_camera_x() -> float`, `get_move_tween() -> Tween`.
  - [x] 4.11 Backdrop placeholder (`Backdrop`, screen space, drawn first): sky `art-sky` `#7EC8E3` y 0–`GROUND_Y`, grass `art-grass` `#4E9A34` below, an optional path stripe `parchment-shade` `#D9BC84`. Optional (cheap, helps see the scroll): ground tick marks every `target_spacing_px` in world space drawn by a `World` child via `_draw()` over the visible range only (call `queue_redraw()` when the camera moves; never allocate per frame). Real parallax backdrop = Story 3.6.
  - [x] 4.12 Header `##` comment on the level script: what it does, the camera-without-Camera2D rule and why, the child-RNG rule, "logic leads, visuals chase", and what 3.2–3.5 will add.

- [x] **Task 5: Registry and menu (AC: 1, 2)**
  - [x] 5.1 `data/levels/level_registry.tres`: add a `LevelEntry` sub-resource `id = &"zombie_run"`, `display_name = "Zombie Run"`, `scene` = `zombie_run_level.tscn`, `debug_only = false`, listed **before** the test level (menu order; Story 4.2 builds cards from it). Bump `load_steps`.
  - [x] 5.2 `scripts/screens/main_menu.gd` + `scenes/screens/main_menu.tscn`: the existing `%PlayButton` already sends `&"zombie_run"` — keep the node name (tests use `%PlayButton`), change its text to `"Zombie Run"`, and rewrite the header comment's last sentence (it says zombie_run "is not registered until Story 3.1 … on purpose"). No other menu changes (Story 4.2 builds the real menu).

- [x] **Task 6: Tests (AC: 10)** — read each existing file before editing; follow their patterns
  - [x] 6.1 `tests/unit/test_level_registry.gd` `test_shipped_registry`: replace `assert_null(registry.get_entry(&"zombie_run"), ...)` with: entry exists, `display_name == "Zombie Run"`, `debug_only == false`, `get_scene(&"zombie_run", false)` is not null (release-visible), instance `is LevelBase` with a `ZombieRunConfig`.
  - [x] 6.2 New `tests/unit/test_zombie_run_config.gd`: load `res://data/levels/zombie_run.tres` → `is ZombieRunConfig`; every AC 1 value; `letter_pool` has 26 unique single lowercase letters a–z; `test_level.tres` still has `completion_bonus == 0`.
  - [x] 6.3 New `tests/unit/test_zombie_run_level.gd` (instantiate the scene, `process_mode = PROCESS_MODE_DISABLED` so nothing advances by itself, `add_child_autofree`, then `create_target_source(rng)` with a fixed seed; drive time with `level._process(delta)` and the scoot with `level.get_move_tween().custom_step(delta)`; drive keys through a real `TypingSession` built on the returned source with `char_accepted` connected to `level.on_char_accepted`, exactly like `RunFrame` does — so the "source already advanced" order is real). Cases:
    - queue: 4 targets after setup, slots 0..3, x positions exactly `target_spacing_px` apart, letters == `[source.current()] + source.peek(3)`, only slot 0 active (arrow visible), others not.
    - correct key: in the same call `get_active_index()` is 1, the old target `is_resolved()`, the new active letter == `source.current()`, the queue is still 4 long and its last letter == `source.peek(3)[2]`, the move tween targets `approach_x(1)`.
    - HUD match over 100 keys: after every key, `get_queue()[0].get_letter() == session.get_current_target()` and exactly one target is active.
    - amble: from the start position, `_process(1.0)` moves the zombie +24 px; `_process(10.0)` lands exactly on `approach_x(0)` and further `_process` calls never pass it.
    - scoot: after one key and `custom_step(scoot_time_s + 0.01)` the zombie is at `approach_x(1)`; a key mid-scoot (after `custom_step(0.05)`) retargets to `approach_x(2)` from the current position (not from the start), only one valid tween exists, and after another full step the zombie is at `approach_x(2)`.
    - chaining: 5 keys in one frame → zombie reaches `approach_x(5)` within one `scoot_time_s` (walking never caps typing).
    - camera: after any amble/scoot step, `get_zombie_x() + %World.position.x == ZOMBIE_SCREEN_X`; after 200 keys (with full steps) every unresolved target's screen x (`position.x + World.position.x`) is within `0 .. 640`.
    - freeing: after 50 keys with full steps and `_process`, `get_resolved_count()` stays small (≤ the number that fit left of `ZOMBIE_SCREEN_X`, e.g. ≤ 6) and freed targets are gone from `%Targets` after a frame (`await get_tree().process_frame` is fine **in tests**, or check `is_queued_for_deletion()`).
    - wrong key: `session.judge(<wrong letter>)` → index, zombie x, queue letters and tween unchanged.
    - determinism: two levels with the same seed show the same first 30 letters; a different seed differs.
    - contract: `get_brains_earned() == 0`, `on_run_ending(&"timer") == 0.0`, config is a `ZombieRunConfig`.
    - no-literal guard (recommended): read the source of every `scripts/levels/zombie_run/*.gd` with `FileAccess.get_file_as_string` and assert none contains the standalone tokens `120`, `0.15`, or `26` (regex `\b(120|0\.15|26)\b`, ignoring `##`/`#` comment lines). Don't add `24`/`48` to the regex (they collide with legitimate layout sizes); review those by eye.
  - [x] 6.4 New `tests/unit/test_zombie_run_target.gd`: `setup` before add_child stores letter/slot and fills the tag; `set_active` toggles `%Arrow.visible`; `resolve()` returns 0, hides tag + arrow, sets resolved, second call returns 0 and stays resolved; an inactive target doesn't bob (its `%Visual` y stays put across `_process` calls), the active one does.
  - [x] 6.5 New `tests/unit/test_player_zombie.gd`: scene loads with `idle` (2 frames, 8 fps) and `walk` (4 frames, 10 fps) animations; `play_walk()`/`play_idle()` switch; `%HatSlot` exists. If you add the sheets to the art tests' lists (`test_art_sprites.gd`) nothing changes — they are already covered there.
  - [x] 6.6 `tests/integration/test_run_frame.gd` (reuse `_make`/`_start`, `_send`, `_type_correct` helpers; real registry): a `{"level_id": &"zombie_run", "seed": 42}` run loads (`get_level()` is the Zombie Run level, no navigation), the HUD target equals the level's active letter; a correct key → level `get_active_index() == 1` in the same call and `RUNNING`; a wrong key → errors 1, level unchanged; `_process` past 120 s → `ENDING` → `DONE` → navigate `REPORT_CARD` with `result.level_id == &"zombie_run"`, `result.brains == 0`, `result.bonus == 0` (bonus is 3.5). `capture_keys` pairing is already checked by the file's `before_each`/`after_all`.
  - [x] 6.7 Full suite headless: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Baseline at `453ff65`: **562** passing — confirm before starting and report the real number. No `Parse Error` / `SCRIPT ERROR`; the "non-equal opposite anchors" warning count must not grow (it was 50).
  - [x] 6.8 Mutation habit (2.4–2.10): break each key rule once (tween not killed → two tweens; amble overshoots; new target spawned from `current()` instead of `peek`; camera via `position:x` tween; resolved targets never freed) and confirm a test fails. Report honestly.

- [x] **Task 7: Manual checks (AC: 3–9)**
  - [x] 7.1 Desktop debug run (Godot MCP `run_project` + `get_debug_output`): menu → "Zombie Run" → the zombie ambles in and idles before the first target; HUD letter matches the arrowed target; no errors or warnings in the output (besides the two known `UNUSED_SIGNAL` ones, see 8.2).
  - [x] 7.2 Web debug export (`--export-debug "Web" build/web/index.html`, launch config `web-debug`, in-app browser pane — same as 2.10): type steadily and in fast bursts (5+ keys/s): the zombie scoots and chains, targets never leave the screen, resolved targets scroll off, the HUD band does not move; Esc → the world freezes, Resume → 3-2-1 → continues; F6 (overlay open) → report card headed "Zombie Run", Brains 0. Take a screenshot of a running run and save it under `_bmad-output/implementation-artifacts/screenshots/3-1/`.
  - [x] 7.3 Readability eyeball at 1×: each tag letter is readable, the arrow is clearly on the active target, nothing in the playfield is hidden under the Caps Lock hint / start prompt strip (type 3 capitals to show the hint).
  - [x] 7.4 Note the overlay (F3) position vs the zombie/targets (deferred-work 2.10: overlay bottom ≈ 192 px top-left). Record, don't fix, unless it hides the active target.

- [x] **Task 8: Wrap-up**
  - [x] 8.1 `deferred-work.md`: strike through the 2.4 lines "Main menu Play sends `&"zombie_run"`, which is not registered until Story 3.1…" and the 2.9 hand-off "register `zombie_run` … `display_name = "Zombie Run"`" (done here). On the 2.4 line about a level emitting `end_requested` mid-judgment: note that Zombie Run never emits `end_requested` (the timer is RunFrame's), so it stays open for Epic 8. Add a "Deferred from: dev of story-3-1" section for anything left (e.g. `ZOMBIE_SCREEN_X` / conga room for 3.4, placeholder visuals for 3.6).
  - [x] 8.2 Optional, tiny: add `@warning_ignore("unused_signal")` above the two signal declarations in `scripts/run/level_base.gd` (deferred-work 2.10 last line) and strike that line. Skip if it causes any test change.
  - [x] 8.3 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`.

## Dev Notes

### What this story is (and isn't)

- The first real level: a `LevelBase` plug-in for the existing run frame. Everything about typing, the clock, pause, the HUD, recording and the report card **already works** (Epic 2) — this story only adds the world the kid sees above the HUD band.
- **New files:** `scripts/resources/zombie_run_config.gd`, `data/levels/zombie_run.tres`, `scenes/characters/player_zombie.tscn`, `scripts/characters/player_zombie.gd`, `scenes/levels/zombie_run/zombie_run_level.tscn`, `scripts/levels/zombie_run/zombie_run_level.gd`, `scenes/levels/zombie_run/zombie_run_target.tscn`, `scripts/levels/zombie_run/zombie_run_target.gd`, tests `test_zombie_run_config.gd`, `test_zombie_run_level.gd`, `test_zombie_run_target.gd`, `test_player_zombie.gd`.
- **Updated files:** `scripts/resources/level_config.gd` (+`completion_bonus`), `data/levels/level_registry.tres`, `scripts/screens/main_menu.gd`, `scenes/screens/main_menu.tscn` (button text), `tests/unit/test_level_registry.gd`, `tests/integration/test_run_frame.gd`, `deferred-work.md`, `sprint-status.yaml`; optionally `scripts/run/level_base.gd` (8.2).
- **Don't build:** brain blocks, villagers, the 1-in-4 group shuffle (3.2/3.3 — but keep `_rng` and `brain_block_every` ready), hop/hug/poof, brains, `play_voice` (3.2), conga line (3.4), end dance and completion-bonus wiring (3.5), backdrop art/parallax and final sprites (3.6), groans/ambience (3.7), the real main menu (4.2), hats (4.3). No changes to `RunFrame`, `TypingSession`, `TypingInput`, the HUD, `Router`, `PlayerData` or the save.

### Key design decisions (follow these)

- **Manual camera, not `Camera2D`** (Task 4.2). Verified from the scene tree: `run_frame.tscn` is `Control` → `Background` (ColorRect), `LevelHost` (Node2D), `Hud`, `PausePanel`, `Countdown` (all `Control`s, no `CanvasLayer`). A `Camera2D` anywhere under `LevelHost` would offset all of them. Moving those into a `CanvasLayer` would touch the shared frame and many Epic 2 tests — out of scope. Scrolling `%World` is one line and keeps every Epic 2 behaviour intact.
- **Zombie x and camera set together** through `_set_zombie_x`. Tween with `tween_method`, not `tween_property(…, "position:x", …)` — the architecture snippet tweens `position:x`, but that snippet assumed a camera that reads the zombie each frame; here the camera *is* the World offset, and updating it in a different callback than the tween would make the whole world jitter by up to ~5 px per frame during scoots (48 px / 0.15 s ÷ 60 fps).
- **Retargeting tween** (architecture "Logic Leads, Visuals Chase"): exactly one move tween; every key kills it and starts a new one from the current visual x. Never gate anything on `tween.finished`.
- **Amble is mostly the opening walk-in.** After a scoot the zombie sits exactly at the approach point, so the amble rule only moves it at run start (and if a scoot is ever cut short). That matches the GDD and the architecture's implementation guide — don't invent extra drift.
- **Source order.** `TypingSession.judge()` advances the source **before** emitting `char_accepted`, so inside `on_char_accepted` `_source.current()` is already the *new* active letter and `peek(3)[2]` is the letter for the newly spawned far slot. Spawning from `current()` would duplicate a letter — test it (6.3).
- **Child RNG.** `LevelBase` doc + deferred-work 2.2: the bag must own a child RNG seeded from the run RNG at creation, so later level draws (3.2 shuffle, 3.2 Brainsss roll) never shift the letters and seed replay (2.10) keeps working. The test level is the reference implementation (`create_target_source` in `scripts/levels/test_level/test_level.gd`).
- **Config subclass.** `ZombieRunConfig extends LevelConfig` (Task 1.2). `completion_bonus` goes on the base (Story 3.5 reads it from `RunFrame`, which only knows `LevelConfig`).
- **GDD numbers vs layout numbers.** GDD numbers (120, 48, 3, 24 px/s, 24 px, 0.15 s, 4, 10, 26 letters) live only in `zombie_run.tres`. Pure layout/look values (ground line, zombie screen x, bob amplitude, tag size, colours) are named `const`s in the owning script, as the HUD already does (`hud.gd` `TARGET_CENTRE_X` etc.).
- **Targets never scroll away** (GDD): targets have fixed world x; only the camera moves. "Zombie Run keeps at most the active target plus the next 3" (architecture Entity Patterns) refers to *unresolved* targets; resolved ones stay visible until off-screen, then the level frees them (AC 7). Story 3.3's villagers poof into party zombies; 3.2's blocks stay as bonked blocks — that's why the base keeps the resolved node instead of freeing it immediately.

### Existing code: current state, what changes, what must be preserved

- **`scripts/run/level_base.gd`** — the contract. Call order (documented at the top): `RunFrame._ready` instances the level → `add_child` under `%LevelHost` (level `_ready` runs) → `create_target_source(rng)` → session → input. First correct key: `on_run_started()` then `on_char_accepted(expected, 0)`. Rules: a level never reads input, never touches the clock, never writes `PlayerData`, never calls the Router. **No change** (except optional 8.2).
- **`scripts/run/run_frame.gd`** — owns state machine, clock, RNG, session, HUD wiring, pause, recording. Connects `_session.char_accepted` → `_level.on_char_accepted` **before** the HUD, so the level reacts first. `ENDING` calls `on_run_ending` and waits the returned seconds (0.0 → `DONE` next frame) after recording. Pause = `get_tree().paused` (level inherits, freezes; node-bound tweens pause too). Failed loads (`create_target_source` returning null, wrong class) → `Log.error` + main menu. **No change.**
- **`scripts/levels/test_level/test_level.gd`** — reference level; stays registered `debug_only`. **No change.**
- **`scripts/resources/level_config.gd`** — fields `duration_s`, `case_sensitive`, `space_is_input`, `target_mode`. **Add** `completion_bonus` only. `test_level.tres` and the two `tests/fixtures/levels/*.tres` get the default 0 implicitly — don't edit them.
- **`data/levels/level_registry.tres`** — one entry (`test_level`, `debug_only = true`). `LevelRegistry.get_scene(id, debug_build)` hides `debug_only` entries in release. **Add** the zombie_run entry; ids must stay unique (`test_shipped_registry` checks).
- **`scripts/screens/main_menu.gd`** — `_on_play_button_pressed` → `Router.go(Router.Screen.RUN, {"level_id": &"zombie_run"})` already. **Change** button text + header comment only. `test_main_menu.gd` asserts `%PlayButton` focus/visibility (unchanged); `test_screen_flow.gd` lists `%PlayButton`.
- **`scripts/screens/report_card.gd`** — heading = registry `display_name` (falls back to `id.capitalize()`); Play Again re-sends `result.level_id`, so it restarts a fresh Zombie Run (new RunFrame → new level → new bag, nothing to reset). **No change.**
- **HUD overlays in the playfield** (approved sketch `ux-designs/.../sketches/hud-band-2-5.md`): pause button 600,16 24×24; Caps Lock hint x 92–348, y 196–224; start prompt x 16–424, y 228–252 (waiting only). Hence `GROUND_Y = 192`.
- **Debug overlay** (`scripts/debug/debug_overlay.gd`) reads `RunFrame`/session getters only; shows "current + next 3" from the session — it will match the in-world queue. **No change.**

### Testing notes

- GUT 9.7.1; command in 6.7. Tests use `process_mode = PROCESS_MODE_DISABLED` + manual `_process(delta)` (pattern from `test_run_frame.gd`). For the scoot use `Tween.custom_step(delta)` on `get_move_tween()`; it advances a tween manually regardless of its bound node's processing. If it turns out not to step while the bound node is disabled in 4.7.2, fall back to leaving the level enabled and stepping only via `custom_step` + `set_process(false)` — record what worked in the Debug Log.
- `tween_method` callables: `_set_zombie_x` must take exactly one `float`.
- A target created with `setup()` before `add_child` must not touch `%`-unique nodes in `setup()` (they resolve in `_ready`); store values and apply them in `_ready()` (or use `@onready`).
- `TypingSession.new(source, config)`; signals `run_started`, `char_accepted(expected, index)`, `char_rejected(expected, typed)`, `target_changed(next)`; getters `get_current_target()`, `get_upcoming(n)`, `get_keys_typed()`, `get_errors()`.
- Statics: none added. `test_run_frame.gd` already resets RunFrame statics in `after_each`.
- Windows/Python CRLF trap (2.10): keep every touched file LF.

### Previous story intelligence (Epic 2)

- 2.4: the test level is the model; the child-RNG rule exists because of a real replay bug risk. `on_char_accepted` index is 0-based; the source is already advanced.
- 2.5: HUD layout is fixed by the approved sketch; playfield content must keep clear of the hint/prompt strips (y ≥ 196) — the test level's own label touched the hint by 4 px (deferred). Zombie Run must not repeat that.
- 2.7: pause is the tree pause; anything animated from `_process` or node-bound tweens freezes for free. Don't add your own pause handling.
- 2.8/2.9: `RunResult` built on entering `ENDING`; report card heading from the registry's `display_name`.
- 2.10: seed replay must keep working: same seed → same letters in the world (test 6.3 determinism). Overlay top-left down to ≈ y 192.
- Review habits: one test per rule, honest mutation reporting, correct test counts, mark partial manual checks as partial.

### Git intelligence

- One commit per story (`453ff65 Story 2.10: run debug tools and seed replay`, `295a7ea Story 2.9…`). Working tree clean at story creation. Suggested message if asked: `Story 3.1: zombie run level, target queue and zombie movement`.

### Latest tech notes (Godot 4.7.2)

- `Node.create_tween()` binds the tween to the node: with the default `TWEEN_PAUSE_BOUND` it stops while the tree is paused and is freed with the node. `SceneTree.create_tween()` is unbound — don't use it here.
- `Tween.kill()` invalidates the tween (`is_valid()` → false); `is_running()` is false for a finished or killed tween.
- `Tween.tween_method(callable, from, to, duration)` calls `callable(value)` every step.
- `Camera2D` sets the viewport canvas transform for canvas layer 0, which includes `Control`s not inside a `CanvasLayer` — the reason for the manual camera.
- `rendering/2d/snap/snap_2d_transforms_to_pixel = true` (project setting) snaps final transforms, so fractional world offsets are fine.
- Inline `SpriteFrames` + `AtlasTexture` sub-resources in a `.tscn` (see `professor_zombie.tscn`) are the existing pattern; `AnimatedSprite2D.play(&"walk")` restarts only if the animation changes when guarded by `animation != &"walk" or not is_playing()`.

### Project Structure Notes

- Paths follow the architecture tree exactly: `scenes/levels/zombie_run/` ↔ `scripts/levels/zombie_run/`, `scenes/characters/player_zombie.tscn` ↔ `scripts/characters/player_zombie.gd`, `data/levels/zombie_run.tres`, resource class in `scripts/resources/`.
- `zombie_run_target.tscn` is an addition to the architecture tree (which lists `brain_block.tscn`, `villager.tscn`, `conga_line.tscn`): it is the shared base those two will extend (its `ZombieRunTarget` class name already appears in the architecture's Entity Patterns example).
- No new autoloads (fixed at five, `test_project_settings.gd`), no InputMap actions, no audio, no save changes.
- Boundary 2: the level depends only on `LevelBase`, its own scenes, its config, (later) `AudioManager` and cosmetic slots. `PlayerZombie` lives in `scenes/characters/` because Professor Zombie, the menu (4.2) and the Closet (4.4) reuse it.

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md`:
- Static typing everywhere (`debug/gdscript/warnings/untyped_declaration = Error`); `:=` only when the type is obvious.
- Typing callbacks synchronous, no `await`, logic before visuals; one retargeting tween per moving actor; one-shot effects self-freeing.
- Game numbers only from config Resources; no GDD number as a literal in a script.
- Randomness only through the injected RNG (child RNG for the source); no global `randi()`/`randf()` in `scripts/levels`.
- Entities: `preload`ed scene constants, `setup()` before `add_child`, `queue_free()` off-screen, no pooling.
- Node refs via `%UniqueName` / `@onready`; no `/root/` paths, no `get_parent()` chains. Signals typed, past tense, connected in code.
- Logging `[LEVEL][tag]` via `Log`; never in `_process`. Tag `&"level"` for level messages.
- Kid-safe placeholder art: palette colours only, hard pixels, 1 px ink outline, no red.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 3.1: Zombie Run Level, Target Queue and Zombie Movement]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory (FR1, FR2, FR28–FR31; NFR2, NFR7, NFR13, NFR16)]
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Level 1: Zombie Run (MVP)]
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract, #Logic Leads Visuals Chase, #Entity Patterns, #Configuration, #Architectural Boundaries, #Directory Structure]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md#Colors, #Layout & Spacing, #Components (In-world target tag)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md#HUD & Diegetic UI]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/mockups/key-run-hud.html (section A: targets 48 px apart, active bob + candy-yellow arrow, parchment tags)]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/hud-band-2-5.md (playfield overlays: hint y 196–224, prompt y 228–252)]
- [Source: docs/art-style-sheet.md (palette, sprite rules, placeholder art rule)]
- [Source: _bmad-output/implementation-artifacts/2-4-run-frame-level-contract-and-test-level.md, 2-10-run-debug-tools-and-seed-replay.md]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md (2.2 child RNG, 2.4 menu/zombie_run + bonus 0, 2.5 test-level label overlap, 2.9 registry hand-off, 2.10 overlay position + UNUSED_SIGNAL)]
- [Source: scripts/run/level_base.gd, scripts/run/run_frame.gd, scenes/run/run_frame.tscn, scripts/levels/test_level/test_level.gd, scripts/typing/letter_bag_source.gd, scripts/resources/level_config.gd, data/levels/level_registry.tres, scripts/screens/main_menu.gd, scenes/characters/professor_zombie.tscn]

### Review Findings

- [x] [Review][Patch] Validate `ZombieRunConfig` and guard empty peek/queue — `visible_upcoming >= 1`, `letter_pool` has >= 2 distinct letters, `target_spacing_px > 0`, `amble_speed_px_s > 0`, `scoot_time_s > 0`; on failure `Log.error` and return null from `create_target_source` so RunFrame fails to the menu (NFR16). Also check `_queue` is non-empty after `pop_front` and `peek()` is non-empty before `.back()` in `on_char_accepted`. Neutral config defaults are all 0, so a partial .tres breaks on the first key. [scripts/levels/zombie_run/zombie_run_level.gd:74-100]
- [x] [Review][Patch] Null-check the `StyleBoxFlat` cast in `ZombieRunTarget._on_resolved` — a scene variant without the panel override crashes on `.duplicate()` [scripts/levels/zombie_run/zombie_run_target.gd:73]
- [x] [Review][Defer] Release builds strip the queue/session desync `assert`; log via `Log.error` or resync [zombie_run_level.gd:95] — deferred, pre-existing pattern, only reachable through another bug
- [x] [Review][Defer] `on_run_ending` doesn't stop movement or set an `_ended` flag; a key in the ending frame still spawns/scoots [zombie_run_level.gd] — deferred, matters once Story 3.5 adds the outro
- [x] [Review][Defer] `ZombieRunTarget.HALF_WIDTH` duplicates the tag width in the .tscn; `resolve()` before `add_child` crashes [zombie_run_target.gd] — deferred, unreachable today; 3.2/3.3 replace the box
- [x] [Review][Defer] `_resolved` has no cap if `_process` stops [zombie_run_level.gd] — deferred, bounded to ~6 in normal play
- [x] [Review][Defer] No direct test that the menu button calls `Router.go(RUN, {level_id: zombie_run})` (AC2) [tests/] — deferred, Story 4.2 replaces the menu
- [x] [Review][Defer] Optional ground tick marks (Task 4.11) not added, so scroll is only visible via targets — deferred, cosmetic, covered by Story 3.6 art

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), via Claude Code

### Debug Log References

- Baseline at `453ff65`: 562/562 passing, 50 "non-equal opposite anchors" warnings, 0 script errors.
- RED: new tests failed to parse (missing `ZombieRunConfig`, `PlayerZombie`, `ZombieRunTarget`, level script/scenes).
- After `--headless --import` (registers the new `class_name`s, writes `.uid` files) the full suite went green first run: **595/595** (+33 tests), 0 `SCRIPT ERROR`/`Parse Error`, anchor warnings still 50, warning/error log profile identical to baseline.
- Tween stepping in tests: `Tween.custom_step()` advances the level's node-bound tween while the level has `PROCESS_MODE_DISABLED`. The primary approach in the Testing notes worked; no fallback needed.
- Mutations (6.8), each run against `test_zombie_run_level.gd`, file restored and byte-compared after: M1 move tween not killed -> 1 fail; M2 amble without `minf` (overshoot) -> 1 fail; M3 far slot spawned from `current()` -> 6 fail; M4 `tween_property(position:x)` instead of `tween_method(_set_zombie_x)` -> 4 fail; M5 resolved targets never freed -> 1 fail. All five caught.
- Desktop (Godot MCP): project launch and the level scene run on its own both load clean; before 8.2 only the two known `UNUSED_SIGNAL` warnings printed, after 8.2 the error output is empty.
- Web debug export (`build/web`, served by the already-running `web-debug` server on 8060, in-app browser pane): menu -> "Zombie Run" -> zombie ambles in and idles before the arrowed target, HUD letter matches; key bursts (4-5 keys) scoot and chain; a wrong key changed nothing in the world; resolved targets scroll off the left; HUD band fixed; Esc froze the zombie mid-scoot, Resume -> 3-2-1 -> the scoot finished; F3 overlay queue matches the world; F6 -> report card "Zombie Run", Brains Collected 0. Console: clean `[run]` lifecycle, no errors/warnings. Note: the browser pane's `type` action sends text insertion that the game ignores; `key` presses work.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- **Implemented** the first real level as a `LevelBase` plug-in: `ZombieRunConfig` (subclass of `LevelConfig`, all GDD numbers in `zombie_run.tres`), `completion_bonus` on `LevelConfig` (not wired; RunFrame still passes 0 until 3.5), `PlayerZombie` (idle/walk from the prototype sheets, feet-centre origin, empty `%HatSlot`), `ZombieRunTarget` base (letter tag, active arrow + bob on `%Visual`, one-way `resolve()` with an `_on_resolved()` override point for 3.2/3.3), and the Zombie Run level (queue of active + 3, amble/idle, single retargeting scoot tween, manual camera via the `%World` offset, off-screen freeing, child-RNG letter bag).
- **Camera:** no `Camera2D`; `_set_zombie_x()` sets the zombie x and the `%World` offset in one call; both the amble and `tween_method` go through it, so the zombie's screen x is exactly `ZOMBIE_SCREEN_X` at all times (tested after every step).
- **Small deviations from the task text (same behaviour):** in `on_char_accepted` the far slot is spawned *before* `_queue[0].set_active(true)` (robust even if `visible_upcoming` were 0); the target body is a `Panel` with a flat `StyleBoxFlat` (fill + 1 px ink border) instead of `_draw()`, same look, and the resolved look swaps the fill to stone-light. The level script has no `class_name` (tests preload it, like `RunFrameScript`).
- **Registry/menu:** `zombie_run` registered first (release-visible, "Zombie Run"); `%PlayButton` text "Zombie Run", header comment rewritten.
- **Tests added:** `test_zombie_run_config.gd` (5), `test_player_zombie.gd` (4), `test_zombie_run_target.gd` (5), `test_zombie_run_level.gd` (17, incl. the no-literal guard), `test_level_registry.gd` +1 (`test_shipped_registry_has_zombie_run`; the old null assertion removed), `test_run_frame.gd` +2 Zombie Run integration tests. Total 595 passing.
- **8.2 done:** `@warning_ignore("unused_signal")` on the two `LevelBase` signals; no test change.
- **Manual checks, honestly:** 7.1 partial: the Godot MCP cannot click or type, so the desktop check is "launch + level scene load with no errors"; menu -> run was driven in the web build instead. 7.2 done (screenshot `screenshots/3-1/zombie-run-running.jpg`). 7.3 partial: tag letters readable and the arrow clearly on the active target; the Caps Lock hint did not appear from Shift+letter presses, so "nothing hidden under the hint" is verified by layout (everything at or above y 192; the hint starts at y 196); the start prompt was seen clear of the targets. 7.4 recorded: the open overlay covers the active arrow and the top of its tag (letter still readable) -> deferred-work.

### File List

New:
- `scripts/resources/zombie_run_config.gd` (+ `.uid`)
- `data/levels/zombie_run.tres`
- `scenes/characters/player_zombie.tscn`
- `scripts/characters/player_zombie.gd` (+ `.uid`)
- `scenes/levels/zombie_run/zombie_run_level.tscn`
- `scripts/levels/zombie_run/zombie_run_level.gd` (+ `.uid`)
- `scenes/levels/zombie_run/zombie_run_target.tscn`
- `scripts/levels/zombie_run/zombie_run_target.gd` (+ `.uid`)
- `tests/unit/test_zombie_run_config.gd` (+ `.uid`)
- `tests/unit/test_zombie_run_level.gd` (+ `.uid`)
- `tests/unit/test_zombie_run_target.gd` (+ `.uid`)
- `tests/unit/test_player_zombie.gd` (+ `.uid`)
- `_bmad-output/implementation-artifacts/screenshots/3-1/zombie-run-running.jpg`

Modified:
- `scripts/resources/level_config.gd`
- `scripts/run/level_base.gd`
- `data/levels/level_registry.tres`
- `scripts/screens/main_menu.gd`
- `scenes/screens/main_menu.tscn`
- `tests/unit/test_level_registry.gd`
- `tests/integration/test_run_frame.gd`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/3-1-zombie-run-level-target-queue-and-zombie-movement.md`

## Change Log

- 2026-10-04: Story 3.1 implemented: Zombie Run level (target queue, amble/idle, retargeting scoot, manual camera, off-screen freeing), `ZombieRunConfig` + `zombie_run.tres`, `PlayerZombie`, `ZombieRunTarget` base, registry entry and menu button, `completion_bonus` on `LevelConfig`, `UNUSED_SIGNAL` suppressions in `LevelBase`; 33 new tests (595 passing). Status -> review.
