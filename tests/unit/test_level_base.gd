extends GutTest
## Level contract (Story 2.4): LevelBase defaults. The base create_target_source is a contract
## violation (debug assert) and is never called here.
## Story 7.5: the tier hand-off (set_tier, get_pool_label, _tier_active).

const CONFIG_PATH: String = "res://tests/fixtures/levels/level_config_lowercase.tres"
const TIER_CONFIG: TierConfig = preload("res://data/tier_config.tres")


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
	assert_true(level.has_signal("used_passages_changed"))


func test_is_a_node_2d() -> void:
	assert_true(_level() is Node2D)


func test_tier_defaults_are_untiered() -> void:
	var level: LevelBase = _level()
	assert_eq(level.tier, 0)
	assert_null(level.tier_config)
	assert_eq(level.get_pool_label(), "all")
	assert_false(level._tier_active())


func test_set_tier_stores_both() -> void:
	var level: LevelBase = _level()
	level.set_tier(2, TIER_CONFIG)
	assert_eq(level.tier, 2)
	assert_eq(level.tier_config, TIER_CONFIG)
	assert_true(level._tier_active())
	assert_eq(level.get_pool_label(), "all", "the base level never uses a tier pool")


func test_tier_active_needs_a_known_tier_and_a_config() -> void:
	var level: LevelBase = _level()
	level.set_tier(0, TIER_CONFIG)
	assert_false(level._tier_active(), "tier 0")
	level.set_tier(TIER_CONFIG.tier_count() + 1, TIER_CONFIG)
	assert_false(level._tier_active(), "above tier_count()")
	level.set_tier(1, null)
	assert_false(level._tier_active(), "null config")
	level.set_tier(TIER_CONFIG.tier_count(), TIER_CONFIG)
	assert_true(level._tier_active(), "the top tier")


## Story 8.2: the used passage hand-off.
func test_used_passages_default_empty() -> void:
	assert_eq(_level().used_passages, [] as Array[String])


func test_set_used_passages_stores_a_copy() -> void:
	var level: LevelBase = _level()
	var ids: Array[String] = ["t3_01", "t4_02"]
	level.set_used_passages(ids)
	assert_eq(level.used_passages, ["t3_01", "t4_02"] as Array[String])
	ids.append("t5_03")
	assert_eq(level.used_passages.size(), 2, "a copy: the caller's list can change freely")
