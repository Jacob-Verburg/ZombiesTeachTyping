extends GutTest
## Level contract (Story 2.4): LevelBase defaults. The base create_target_source is a contract
## violation (debug assert) and is never called here.

const CONFIG_PATH: String = "res://tests/fixtures/levels/level_config_lowercase.tres"


func _level() -> LevelBase:
	return autofree(LevelBase.new()) as LevelBase


func test_get_level_config_returns_the_export() -> void:
	var level: LevelBase = _level()
	assert_null(level.get_level_config())
	var config: LevelConfig = load(CONFIG_PATH) as LevelConfig
	level.config = config
	assert_eq(level.get_level_config(), config)


func test_defaults() -> void:
	var level: LevelBase = _level()
	assert_eq(level.on_run_ending(&"timer"), 0.0)
	assert_eq(level.get_brains_earned(), 0)


func test_callbacks_are_safe_no_ops() -> void:
	var level: LevelBase = _level()
	watch_signals(level)
	level.on_run_started()
	level.on_char_accepted("a", 0)
	level.on_char_rejected("a", "s")
	level.on_target_completed("cat")
	assert_signal_not_emitted(level, "end_requested")
	assert_signal_not_emitted(level, "brains_earned_changed")
	assert_eq(level.get_brains_earned(), 0)


func test_signals_exist() -> void:
	var level: LevelBase = _level()
	assert_true(level.has_signal("end_requested"))
	assert_true(level.has_signal("brains_earned_changed"))


func test_is_a_node_2d() -> void:
	assert_true(_level() is Node2D)
