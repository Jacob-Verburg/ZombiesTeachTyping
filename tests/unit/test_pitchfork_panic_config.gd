extends GutTest
## PitchforkPanicConfig (Stories 8.3, 8.4): the shipped .tres validates and holds the GDD numbers; each bad
## number is rejected with its own message.

const PATH: String = "res://data/levels/pitchfork_panic.tres"


func _shipped() -> PitchforkPanicConfig:
	var config: PitchforkPanicConfig = load(PATH) as PitchforkPanicConfig
	assert_not_null(config, "pitchfork_panic.tres loads as a PitchforkPanicConfig")
	return config.duplicate(true) as PitchforkPanicConfig


func test_shipped_config_validates_with_the_spec_numbers() -> void:
	var config: PitchforkPanicConfig = _shipped()
	assert_eq(config.validate(), "")
	assert_eq(config.duration_s, 300.0)
	assert_true(config.case_sensitive)
	assert_true(config.space_is_input)
	assert_eq(config.target_mode, LevelConfig.TargetMode.PARAGRAPH)
	assert_eq(config.completion_bonus, 0)
	assert_eq(config.music_id, &"")
	assert_not_null(config.paragraphs)
	assert_not_null(config.tier_word_pools)
	assert_eq(config.start_gap_steps, 15.0)
	assert_eq(config.mob_start_wpm_eq, 4.0)
	assert_eq(config.mob_accel_wpm_eq, 1.0)
	assert_eq(config.mob_accel_every_s, 10.0)
	assert_eq(config.step_px, 16.0)
	assert_eq(config.zombie_screen_x_frac, 0.6)
	assert_eq(config.mob_visible_gap_steps, 20.0)
	assert_eq(config.step_time_s, 0.1)
	assert_eq(config.pickup_min_steps, 10)
	assert_eq(config.pickup_max_steps, 30)
	assert_eq(config.brains_per_pickup, 5)


func test_default_config_is_rejected() -> void:
	assert_ne(PitchforkPanicConfig.new().validate(), "")


func test_bad_numbers_are_rejected_with_their_message() -> void:
	var cases: Array[Array] = [
		["start_gap_steps", 0.0, "start_gap_steps"],
		["start_gap_steps", NAN, "start_gap_steps"],
		["mob_start_wpm_eq", -1.0, "mob_start_wpm_eq"],
		["mob_accel_wpm_eq", INF, "mob_accel_wpm_eq"],
		["mob_accel_every_s", 0.0, "mob_accel_every_s"],
		["step_px", 0.0, "step_px"],
		["step_px", 0.001, "step_px must be at least 1"],
		["zombie_screen_x_frac", 1.0, "zombie_screen_x_frac"],
		["zombie_screen_x_frac", 0.0, "zombie_screen_x_frac"],
		["mob_visible_gap_steps", 0.0, "mob_visible_gap_steps"],
		["step_time_s", -0.1, "step_time_s"],
		["duration_s", 0.0, "duration_s"],
		["target_mode", LevelConfig.TargetMode.WORD, "target_mode"],
		["case_sensitive", false, "case_sensitive"],
		["space_is_input", false, "space_is_input"],
		["paragraphs", null, "paragraphs"],
		["pickup_min_steps", 0, "pickup_min_steps must be at least 1"],
		["pickup_max_steps", 9, "pickup_max_steps must not be below pickup_min_steps"],
		["brains_per_pickup", 0, "brains_per_pickup must be at least 1"],
	]
	for c: Array in cases:
		var config: PitchforkPanicConfig = _shipped()
		config.set(c[0], c[1])
		assert_string_contains(config.validate(), c[2], "%s = %s" % [c[0], c[1]])


func test_mob_needs_some_speed() -> void:
	var config: PitchforkPanicConfig = _shipped()
	config.mob_start_wpm_eq = 0.0
	config.mob_accel_wpm_eq = 0.0
	assert_ne(config.validate(), "")
