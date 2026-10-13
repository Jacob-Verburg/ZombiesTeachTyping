extends GutTest
## ChaseModel (Story 8.3, FR70): start values, one step per key, the WPM-eq ramp, exact (frame-rate
## independent) integration, a hand-computed oracle and the GDD's closed-form catch times.

const TICK: float = 1.0 / 60.0


## A duplicate of the shipped config with the mob pinned to the GDD 8.3 numbers (gap 15, 4 WPM-eq + 1 every
## 10 s), so these tests check the model, not the tuning (Story 8.7 retuned the shipped mob; see its Tuning
## Results and test_pitchfork_panic_tuning.gd).
func _config() -> PitchforkPanicConfig:
	var config: PitchforkPanicConfig = (load("res://data/levels/pitchfork_panic.tres") as PitchforkPanicConfig).duplicate(true)
	config.start_gap_steps = 15.0
	config.mob_start_wpm_eq = 4.0
	config.mob_accel_wpm_eq = 1.0
	config.mob_accel_every_s = 10.0
	assert_eq(config.validate(), "", "shipped config is valid")
	return config


func _model() -> ChaseModel:
	return ChaseModel.new(_config())


func test_start_values() -> void:
	var m: ChaseModel = _model()
	assert_eq(m.gap(), 15.0)
	assert_eq(m.mob_steps, -15.0)
	assert_eq(m.zombie_steps, 0)
	assert_eq(m.elapsed_s, 0.0)
	assert_false(m.caught())


func test_step_raises_gap_by_one() -> void:
	var m: ChaseModel = _model()
	m.step()
	assert_eq(m.zombie_steps, 1)
	assert_eq(m.gap(), 16.0)


func test_mob_wpm_eq_ramp() -> void:
	var m: ChaseModel = _model()
	assert_almost_eq(m.mob_wpm_eq(0.0), 4.0, 1e-9)
	assert_almost_eq(m.mob_wpm_eq(10.0), 5.0, 1e-9)
	assert_almost_eq(m.mob_wpm_eq(50.0), 9.0, 1e-9)


func test_integration_is_frame_rate_independent() -> void:
	var one: ChaseModel = _model()
	one.advance(10.0)
	var many: ChaseModel = _model()
	for i: int in 600:
		many.advance(1.0 / 60.0)
	var three: ChaseModel = _model()
	for i: int in 3:
		three.advance(10.0 / 3.0)
	assert_almost_eq(many.mob_steps, one.mob_steps, 1e-6)
	assert_almost_eq(three.mob_steps, one.mob_steps, 1e-6)
	assert_almost_eq(many.elapsed_s, 10.0, 1e-6)


func test_ten_seconds_hand_computed() -> void:
	# 4*5/60*10 + (1*5/60/10)*50 = 3.3333 + 0.41667 = 3.75 steps.
	var m: ChaseModel = _model()
	m.advance(10.0)
	assert_almost_eq(m.mob_steps - -15.0, 3.75, 1e-6)
	assert_almost_eq(m.gap(), 11.25, 1e-6)


func test_bad_dt_changes_nothing() -> void:
	var m: ChaseModel = _model()
	for dt: float in [0.0, -1.0, NAN, INF]:
		m.advance(dt)
	assert_eq(m.mob_steps, -15.0)
	assert_eq(m.elapsed_s, 0.0)


## Time the model is first caught when the zombie types at `wpm`, or -1.0 if not by `limit_s`.
func _catch_time(wpm: float, limit_s: float) -> float:
	var m: ChaseModel = _model()
	var per_tick: float = wpm * 5.0 / 60.0 * TICK
	var acc: float = 0.0
	var t: float = 0.0
	while t < limit_s:
		t += TICK
		acc += per_tick
		while acc >= 1.0:
			acc -= 1.0
			m.step()
		m.advance(TICK)
		if m.caught():
			return t
	return -1.0


func test_caught_at_5_wpm() -> void:
	assert_almost_eq(_catch_time(5.0, 300.0), 70.8, 3.0)


func test_caught_at_10_wpm() -> void:
	assert_almost_eq(_catch_time(10.0, 300.0), 144.8, 3.0)


func test_escapes_at_19_wpm_and_faster() -> void:
	for wpm: float in [19.0, 20.0, 30.0]:
		assert_eq(_catch_time(wpm, 300.0), -1.0, "%s WPM is not caught by 300 s" % wpm)


func test_null_and_invalid_config_never_move() -> void:
	var bad: PitchforkPanicConfig = _config()
	bad.start_gap_steps = 0.0
	for m: ChaseModel in [ChaseModel.new(null), ChaseModel.new(bad)]:
		m.step()
		m.advance(100.0)
		assert_eq(m.zombie_steps, 0)
		assert_eq(m.mob_steps, 0.0)
		assert_eq(m.elapsed_s, 0.0)
		assert_false(m.caught())
