extends GutTest
## The headless Pitchfork Panic sim (Story 8.7, tools/pitchfork_panic_sim.gd): determinism, a seed-free
## chase with seed-dependent pickups, the WPM pacing (1 key = 1 step), the level's RNG order for pickups,
## the global RNG never used, mean_over_seeds equal to the mean of run(), both endings and their bonus, the
## refusals, the escape threshold, agreement with test_chase_model's closed-form catch times, and one
## cross-check against the real PitchforkPanicLevel (catch frame and brains), which resolves the 6.7 "nothing
## cross-checks a sim against the real level" defer for this level. Runs use the shipped config (read only)
## or a deep duplicate of it.

const Sim := preload("res://tools/pitchfork_panic_sim.gd")
const PATH: String = "res://data/levels/pitchfork_panic.tres"
const LevelScene: PackedScene = preload("res://scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn")
const STEP: float = 1.0 / 60.0


func _shipped() -> PitchforkPanicConfig:
	return load(PATH) as PitchforkPanicConfig


func _copy() -> PitchforkPanicConfig:
	return _shipped().duplicate(true) as PitchforkPanicConfig


func after_each() -> void:
	randomize() # whatever a test seeded, leave the global RNG unseeded for later tests


func test_same_config_wpm_and_seed_give_identical_numbers() -> void:
	var first: Dictionary = Sim.run(_shipped(), 10.0, 3)
	assert_false(first.is_empty())
	assert_eq(Sim.run(_shipped(), 10.0, 3), first)


func test_another_seed_moves_only_the_pickups() -> void:
	var a: Dictionary = Sim.run(_shipped(), 30.0, 3)
	var b: Dictionary = Sim.run(_shipped(), 30.0, 4)
	for key: String in ["end_reason", "end_s", "keys"]:
		assert_eq(b[key], a[key], "%s is seed-free" % key)
	# A 751-key run over 10-30 step gaps: two seeds placing the same count is unlikely, the same trail more so.
	var trail_a: PickupTrail = _trail_for(3)
	var trail_b: PickupTrail = _trail_for(4)
	trail_a.fill_to(751)
	trail_b.fill_to(751)
	assert_ne(trail_b.upcoming(), trail_a.upcoming(), "another seed places another trail")


func test_measured_wpm_matches_the_requested_wpm() -> void:
	for wpm: float in [5.0, 10.0, 30.0]:
		var result: Dictionary = Sim.chase(_shipped(), wpm)
		assert_almost_eq(result.measured_wpm as float, wpm, 0.5, "%d WPM over a whole run" % roundi(wpm))


## The pickup trail the level builds for run seed `rng_seed`: the run RNG's second draw.
func _trail_for(rng_seed: int) -> PickupTrail:
	var cfg: PitchforkPanicConfig = _shipped()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	rng.randi()
	var pickup_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pickup_rng.seed = rng.randi()
	return PickupTrail.new(pickup_rng, cfg.pickup_min_steps, cfg.pickup_max_steps)


func test_pickups_follow_the_levels_rng_order() -> void:
	for s: int in [1, 7, 42]:
		var result: Dictionary = Sim.run(_shipped(), 20.0, s)
		var trail: PickupTrail = _trail_for(s)
		var keys: int = result.keys
		trail.fill_to(keys)
		var expected: int = 0
		for step: int in trail.upcoming():
			if step <= keys:
				expected += 1
		assert_eq(result.pickups, expected, "seed %d" % s)
		assert_eq(result.pickup_brains, expected * _shipped().brains_per_pickup)


func test_never_touches_the_global_rng() -> void:
	seed(1)
	var first: Dictionary = Sim.run(_shipped(), 20.0, 9)
	seed(999)
	assert_eq(Sim.run(_shipped(), 20.0, 9), first, "only the run seed decides anything")


func test_mean_over_seeds_is_the_mean_of_run() -> void:
	var seeds: Array[int] = [1, 2, 3, 4, 5, 6, 7]
	var mean: Dictionary = Sim.mean_over_seeds(_shipped(), 10.0, seeds)
	var pickups: float = 0.0
	var brains: float = 0.0
	var per_min: float = 0.0
	for s: int in seeds:
		var result: Dictionary = Sim.run(_shipped(), 10.0, s)
		pickups += result.pickups as int
		brains += result.brains as int
		per_min += result.brains_per_min as float
	assert_eq(mean.pickups, pickups / seeds.size())
	assert_eq(mean.brains, brains / seeds.size())
	assert_eq(mean.brains_per_min, per_min / seeds.size())
	var chase: Dictionary = Sim.chase(_shipped(), 10.0)
	for key: String in chase:
		assert_eq(mean[key], chase[key], key)


func test_a_mob_that_barely_moves_lets_the_zombie_escape_with_both_bonuses() -> void:
	var cfg: PitchforkPanicConfig = _copy()
	cfg.mob_start_wpm_eq = 0.0
	cfg.mob_accel_wpm_eq = 0.001
	var result: Dictionary = Sim.run(cfg, 5.0, 1)
	assert_eq(result.end_reason, GameConstants.END_REASON_ESCAPED)
	assert_eq(result.end_s, cfg.duration_s)
	assert_eq(result.bonus, cfg.completion_bonus + cfg.escape_bonus)
	assert_almost_eq(result.brains_per_min as float,
		float((result.pickup_brains as int) + (result.bonus as int)) / (cfg.duration_s / 60.0), 1e-4)


func test_a_tiny_start_gap_is_caught_with_the_completion_bonus_only() -> void:
	var cfg: PitchforkPanicConfig = _copy()
	cfg.start_gap_steps = 0.5
	var result: Dictionary = Sim.run(cfg, 1.0, 1)
	assert_eq(result.end_reason, GameConstants.END_REASON_CAUGHT)
	assert_eq(result.keys, 1, "caught before the second key (12 s)")
	assert_lt(result.end_s as float, 12.0)
	assert_eq(result.bonus, cfg.completion_bonus)


func test_a_non_positive_wpm_or_step_or_bad_config_is_refused() -> void:
	assert_eq(Sim.run(_shipped(), 0.0, 1), {})
	assert_push_error("must be positive")
	assert_eq(Sim.chase(_shipped(), -5.0), {})
	assert_push_error("must be positive")
	assert_eq(Sim.chase(_shipped(), 10.0, 0.0), {})
	assert_push_error("must be positive")
	var bad: PitchforkPanicConfig = _copy()
	bad.start_gap_steps = 0.0
	assert_eq(Sim.chase(bad, 10.0), {})
	assert_push_error("config invalid")


func test_escape_threshold_on_the_shipped_config() -> void:
	var threshold: float = Sim.escape_threshold_wpm(_shipped())
	assert_gt(threshold, 36.0)
	assert_lte(threshold, 37.0)
	assert_eq(Sim.chase(_shipped(), threshold).end_reason, GameConstants.END_REASON_ESCAPED)
	assert_eq(Sim.chase(_shipped(), threshold - 0.05).end_reason, GameConstants.END_REASON_CAUGHT)


func test_escape_threshold_is_minus_one_when_even_hi_is_caught() -> void:
	var cfg: PitchforkPanicConfig = _copy()
	cfg.mob_accel_wpm_eq = 100.0
	assert_eq(Sim.escape_threshold_wpm(cfg, 1.0, 20.0), -1.0)


## test_chase_model.gd's closed-form oracle catches the GDD 8.3 mob at 70.8 / 144.8 s at 5 / 10 WPM (its
## helper steps one key-interval after t = 0); the sim steps on the key at t = 0 (71.4 / 145.1 s), so the
## agreement is its +-3 s. The 8.7 mob doubles gap, speed and ramp, so the same times hold at 10 / 20 WPM.
func test_catch_times_agree_with_the_closed_form() -> void:
	var gdd: PitchforkPanicConfig = _copy()
	gdd.start_gap_steps = 15.0
	gdd.mob_start_wpm_eq = 4.0
	gdd.mob_accel_wpm_eq = 1.0
	assert_almost_eq(Sim.chase(gdd, 5.0).end_s as float, 70.8, 3.0)
	assert_almost_eq(Sim.chase(gdd, 10.0).end_s as float, 144.8, 3.0)
	assert_almost_eq(Sim.chase(_shipped(), 10.0).end_s as float, 70.8, 3.0)
	assert_almost_eq(Sim.chase(_shipped(), 20.0).end_s as float, 144.8, 3.0)


## Drives the real level (key at t = 0 through a TypingSession, then one on_char_accepted per key every
## 12 / wpm s, _process(1/60) per frame) to the catch: the catch frame matches Sim.chase() within one frame
## and the level's pickup brains match Sim.run() for the same seed.
func test_the_real_level_catches_on_the_sims_frame_with_the_sims_brains() -> void:
	var wpm: float = 10.0
	var rng_seed: int = 42
	var level: PitchforkPanicLevel = LevelScene.instantiate() as PitchforkPanicLevel
	level.play_sfx = func(_id: StringName) -> void: pass
	add_child_autofree(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var source: TargetSource = level.create_target_source(rng)
	assert_not_null(source)
	if source == null:
		return
	var session: TypingSession = TypingSession.new(source, level.get_level_config())
	session.run_started.connect(level.on_run_started)
	session.char_accepted.connect(level.on_char_accepted)
	var caught_at: Array[float] = []
	level.end_requested.connect(func(_reason: StringName) -> void: caught_at.append(-1.0))
	assert_eq(session.judge(session.get_current_target()[0]), TypingSession.Verdict.CORRECT)
	var key_s: float = 12.0 / wpm
	var keys: int = 1
	var frame: int = 0
	while caught_at.is_empty() and frame < 300 * 60:
		var frame_end: float = (frame + 1) * STEP
		while keys * key_s <= frame_end + 1e-9:
			level.on_char_accepted("x", keys)
			keys += 1
		level._process(STEP)
		frame += 1
		if not caught_at.is_empty():
			caught_at[0] = frame_end
	var sim: Dictionary = Sim.run(_shipped(), wpm, rng_seed)
	assert_eq(caught_at.size(), 1, "the real level catches a steady 10 WPM typist")
	if caught_at.is_empty():
		return
	assert_almost_eq(caught_at[0], sim.end_s as float, STEP + 1e-6, "catch frame")
	assert_eq(level.get_model().zombie_steps, sim.keys)
	assert_eq(level.get_brains_earned(), sim.pickup_brains, "pickup brains for seed 42")
