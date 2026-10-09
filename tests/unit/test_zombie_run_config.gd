extends GutTest
## Zombie Run config (Story 3.1): every GDD tuning number lives in data/levels/zombie_run.tres.

const CONFIG_PATH: String = "res://data/levels/zombie_run.tres"
const TEST_LEVEL_CONFIG_PATH: String = "res://data/levels/test_level.tres"


func _config() -> ZombieRunConfig:
	return load(CONFIG_PATH) as ZombieRunConfig


func test_loads_as_zombie_run_config() -> void:
	var config: Resource = load(CONFIG_PATH)
	assert_true(config is ZombieRunConfig)
	assert_true(config is LevelConfig, "a ZombieRunConfig is a LevelConfig")


func test_base_values() -> void:
	var config: ZombieRunConfig = _config()
	assert_eq(config.duration_s, 120.0)
	assert_false(config.case_sensitive)
	assert_false(config.space_is_input)
	assert_eq(config.target_mode, LevelConfig.TargetMode.LETTER)
	assert_eq(config.completion_bonus, 10)


func test_zombie_run_values() -> void:
	var config: ZombieRunConfig = _config()
	assert_eq(config.target_spacing_px, 48.0)
	assert_eq(config.visible_upcoming, 3)
	assert_eq(config.amble_speed_px_s, 24.0)
	assert_eq(config.approach_gap_px, 24.0)
	assert_eq(config.scoot_time_s, 0.15)
	assert_eq(config.brain_block_every, 4)


func test_brain_block_values() -> void:
	var config: ZombieRunConfig = _config()
	assert_eq(config.brain_block_float_px, 48.0)
	assert_eq(config.hop_time_s, 0.35)
	assert_eq(config.brains_per_block, 1)
	assert_eq(config.brainsss_chance, 0.2)


## Also the placement guarantee (Story 7.2, FR61): a new save's first Zombie Run uses all 26 letters, so
## Story 7.5 must keep a..z here while placement_done is false.
func test_letter_pool_is_a_to_z() -> void:
	var pool: Array[String] = _config().letter_pool
	assert_eq(pool.size(), 26, "the placement run needs all 26 letters")
	var seen: Dictionary = {}
	for letter: String in pool:
		assert_eq(letter.length(), 1, "single letter '%s'" % letter)
		assert_eq(letter, letter.to_lower(), "lowercase '%s'" % letter)
		var code: int = letter.unicode_at(0)
		assert_true(code >= 97 and code <= 122, "a..z '%s'" % letter)
		seen[letter] = true
	assert_eq(seen.size(), 26, "no duplicates")


func test_other_levels_keep_no_completion_bonus() -> void:
	var config: LevelConfig = load(TEST_LEVEL_CONFIG_PATH) as LevelConfig
	assert_eq(config.completion_bonus, 0)
	assert_eq(LevelConfig.new().completion_bonus, 0, "neutral default")


func test_shipped_config_validates() -> void:
	assert_eq(_config().validate(), "")


func test_neutral_defaults_are_rejected() -> void:
	assert_ne(ZombieRunConfig.new().validate(), "")


func test_each_bad_number_is_rejected() -> void:
	var fields: Dictionary = {
		"visible_upcoming": 0,
		"target_spacing_px": 0.0,
		"amble_speed_px_s": 0.0,
		"scoot_time_s": 0.0,
		"letter_pool": ["a"] as Array[String],
		"brain_block_every": 0,
		"hop_time_s": 0.0,
		"brains_per_block": 0,
		"brainsss_chance": 1.5,
		"brain_block_float_px": 32.0,
		"conga_max_drawn": 0,
		"dance_time_s": 0.0,
	}
	for field: String in fields:
		var config: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
		config.set(field, fields[field])
		assert_ne(config.validate(), "", "%s should be rejected" % field)


func test_brainsss_chance_bounds() -> void:
	for chance: float in [0.0, 1.0]:
		var config: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
		config.brainsss_chance = chance
		assert_eq(config.validate(), "", "%.1f is allowed" % chance)
	var low: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
	low.brainsss_chance = -0.1
	assert_ne(low.validate(), "")
	var nan: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
	nan.brainsss_chance = NAN
	assert_ne(nan.validate(), "", "NaN is rejected")


# --- villagers (Story 3.3) --------------------------------------------------

func test_hug_time_value() -> void:
	assert_eq(_config().hug_time_s, 0.4)


func test_hug_time_must_be_positive() -> void:
	for bad: float in [0.0, -0.4, NAN]:
		var config: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
		config.hug_time_s = bad
		assert_ne(config.validate(), "", "hug_time_s %s is rejected" % bad)


# --- conga line (Story 3.4) ---------------------------------------------------

func test_conga_max_drawn_value() -> void:
	assert_eq(_config().conga_max_drawn, 12)


func test_conga_max_drawn_must_be_at_least_one() -> void:
	for bad: int in [0, -1]:
		var config: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
		config.conga_max_drawn = bad
		assert_ne(config.validate(), "", "conga_max_drawn %d is rejected" % bad)
	var one: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
	one.conga_max_drawn = 1
	assert_eq(one.validate(), "")


# --- end dance (Story 3.5) ----------------------------------------------------

func test_dance_time_value() -> void:
	assert_eq(_config().dance_time_s, 2.0)


func test_dance_time_must_be_positive() -> void:
	for bad: float in [0.0, -2.0, NAN]:
		var config: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
		config.dance_time_s = bad
		assert_ne(config.validate(), "", "dance_time_s %s is rejected" % bad)
