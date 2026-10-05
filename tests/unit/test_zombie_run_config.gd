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


func test_letter_pool_is_a_to_z() -> void:
	var pool: Array[String] = _config().letter_pool
	assert_eq(pool.size(), 26)
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
	}
	for field: String in fields:
		var config: ZombieRunConfig = _config().duplicate() as ZombieRunConfig
		config.set(field, fields[field])
		assert_ne(config.validate(), "", "%s should be rejected" % field)
