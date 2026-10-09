extends GutTest
## TierConfig (Story 7.1): the shipped data/tier_config.tres values, validate() on each broken case, and
## ignored_levels matching the registry's debug-only levels. Story 7.2: placement_level (shipped, invalid
## cases, a real non-debug registry level). Story 7.4: per-tier row counts and word length bands (shipped,
## helpers, invalid cases).

const CONFIG_PATH: String = "res://data/tier_config.tres"
const REGISTRY_PATH: String = "res://data/levels/level_registry.tres"


func _shipped() -> TierConfig:
	return load(CONFIG_PATH) as TierConfig


func _valid() -> TierConfig:
	var config: TierConfig = TierConfig.new()
	config.tier_floors = [0.0, 8.0, 15.0, 22.0, 30.0]
	config.drop_margin_wpm = 2.0
	config.window_runs = 5
	config.ignored_levels = [&"test_level"]
	config.placement_level = &"zombie_run"
	config.tier_row_counts = [1, 2, 3, 3, 3]
	config.tier_word_min_length = [2, 3, 3, 4, 5]
	config.tier_word_max_length = [4, 4, 5, 6, 8]
	return config


func test_shipped_values() -> void:
	var config: TierConfig = _shipped()
	assert_not_null(config, "tier_config.tres loads as a TierConfig")
	assert_eq(config.tier_floors, [0.0, 8.0, 15.0, 22.0, 30.0] as Array[float])
	assert_eq(config.drop_margin_wpm, 2.0)
	assert_eq(config.window_runs, 5)
	assert_eq(config.level_wpm_scale.size(), 0, "no per-level weighting (Gate A)")
	assert_eq(config.tier_count(), 5)
	assert_eq(config.ignored_levels, [&"test_level", &"test_word_level"] as Array[StringName])
	assert_eq(config.placement_level, &"zombie_run")
	assert_eq(config.tier_row_counts, [1, 2, 3, 3, 3] as Array[int])
	# Tier 1 is 2-4, not the GDD's 2-3: Smuck's decision at the Story 7.3 review gate (2026-10-08).
	assert_eq(config.tier_word_min_length, [2, 3, 3, 4, 5] as Array[int])
	assert_eq(config.tier_word_max_length, [4, 4, 5, 6, 8] as Array[int])


func test_shipped_is_valid() -> void:
	assert_eq(_shipped().validate(), "")


func test_ignored_levels_are_the_registry_debug_levels() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	var debug_ids: Array[StringName] = []
	for entry: LevelEntry in registry.entries:
		if entry != null and entry.debug_only:
			debug_ids.append(entry.id)
	var ignored: Array[StringName] = _shipped().ignored_levels.duplicate()
	debug_ids.sort()
	ignored.sort()
	assert_eq(ignored, debug_ids)
	assert_eq(ignored.size(), 2)


func test_defaults_are_neutral() -> void:
	var config: TierConfig = TierConfig.new()
	assert_eq(config.tier_floors.size(), 0)
	assert_eq(config.drop_margin_wpm, 0.0)
	assert_eq(config.window_runs, 0)
	assert_eq(config.level_wpm_scale.size(), 0)
	assert_eq(config.ignored_levels.size(), 0)
	assert_eq(config.placement_level, &"")
	assert_eq(config.tier_row_counts.size(), 0)
	assert_eq(config.tier_word_min_length.size(), 0)
	assert_eq(config.tier_word_max_length.size(), 0)
	assert_ne(config.validate(), "", "neutral defaults are not a usable config")


func test_helpers() -> void:
	var config: TierConfig = _valid()
	config.level_wpm_scale = {&"horde_rush": 0.8}
	assert_eq(config.floor_of(1), 0.0)
	assert_eq(config.floor_of(3), 15.0)
	assert_eq(config.floor_of(5), 30.0)
	assert_eq(config.floor_of(0), 0.0)
	assert_eq(config.floor_of(6), 0.0)
	assert_almost_eq(config.scale_for(&"horde_rush"), 0.8, 1e-6)
	assert_eq(config.scale_for(&"zombie_run"), 1.0)


func test_valid_config_passes() -> void:
	var config: TierConfig = _valid()
	config.level_wpm_scale = {&"horde_rush": 0.8}
	config.drop_margin_wpm = 0.0
	assert_eq(config.validate(), "")


func test_too_few_tiers() -> void:
	var config: TierConfig = _valid()
	config.tier_floors = [0.0]
	assert_ne(config.validate(), "")


func test_first_floor_not_zero() -> void:
	var config: TierConfig = _valid()
	config.tier_floors = [1.0, 8.0, 15.0]
	assert_ne(config.validate(), "")
	config.tier_floors = [NAN, 8.0, 15.0]
	assert_ne(config.validate(), "")


func test_floors_not_strictly_rising() -> void:
	var config: TierConfig = _valid()
	config.tier_floors = [0.0, 8.0, 8.0, 22.0]
	assert_ne(config.validate(), "", "equal floors")
	config.tier_floors = [0.0, 15.0, 8.0]
	assert_ne(config.validate(), "", "falling floors")
	config.tier_floors = [0.0, 8.0, INF]
	assert_ne(config.validate(), "", "infinite floor")
	config.tier_floors = [0.0, NAN, 15.0]
	assert_ne(config.validate(), "", "NaN floor")


func test_bad_margin() -> void:
	var config: TierConfig = _valid()
	config.drop_margin_wpm = -0.5
	assert_ne(config.validate(), "")
	config.drop_margin_wpm = NAN
	assert_ne(config.validate(), "")
	config.drop_margin_wpm = INF
	assert_ne(config.validate(), "")


func test_bad_window() -> void:
	var config: TierConfig = _valid()
	config.window_runs = 0
	assert_ne(config.validate(), "")


func test_bad_scale() -> void:
	var config: TierConfig = _valid()
	for bad: float in [0.0, -1.0, NAN, INF]:
		config.level_wpm_scale = {&"horde_rush": bad}
		assert_ne(config.validate(), "", "scale %s" % bad)


func test_empty_ignored_id() -> void:
	var config: TierConfig = _valid()
	config.ignored_levels = [&"test_level", &""]
	assert_ne(config.validate(), "")


func test_placement_level_is_a_real_registry_level() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	var entry: LevelEntry = registry.get_entry(_shipped().placement_level)
	assert_not_null(entry, "placement_level is in the registry")
	if entry != null:
		assert_false(entry.debug_only, "placement_level is a real level, not a debug one")


func test_empty_placement_level() -> void:
	var config: TierConfig = _valid()
	config.placement_level = &""
	assert_ne(config.validate(), "")


func test_ignored_placement_level() -> void:
	var config: TierConfig = _valid()
	config.placement_level = &"test_level"
	assert_ne(config.validate(), "")


func test_pool_helpers() -> void:
	var config: TierConfig = _valid()
	assert_eq(config.row_count_of(1), 1)
	assert_eq(config.row_count_of(2), 2)
	assert_eq(config.row_count_of(5), 3)
	assert_eq(config.row_count_of(0), 0)
	assert_eq(config.row_count_of(6), 0)
	assert_eq(config.word_band_of(1), Vector2i(2, 4))
	assert_eq(config.word_band_of(5), Vector2i(5, 8))
	assert_eq(config.word_band_of(0), Vector2i.ZERO)
	assert_eq(config.word_band_of(6), Vector2i.ZERO)


func test_pool_arrays_wrong_size() -> void:
	var config: TierConfig = _valid()
	config.tier_row_counts = [1, 2, 3, 3]
	assert_ne(config.validate(), "", "row counts short")
	config = _valid()
	config.tier_word_min_length = [2, 3, 3, 4, 5, 5]
	assert_ne(config.validate(), "", "min lengths long")
	config = _valid()
	config.tier_word_max_length = []
	assert_ne(config.validate(), "", "max lengths empty")


func test_bad_row_counts() -> void:
	var config: TierConfig = _valid()
	config.tier_row_counts = [0, 2, 3, 3, 3]
	assert_ne(config.validate(), "", "row count 0")
	config.tier_row_counts = [1, 2, 3, 3, 4]
	assert_ne(config.validate(), "", "row count 4")
	config.tier_row_counts = [1, 2, 1, 3, 3]
	assert_ne(config.validate(), "", "row count falls 2 -> 1")


func test_word_bands_must_not_fall_between_tiers() -> void:
	var config: TierConfig = _valid()
	config.tier_word_max_length = [4, 4, 5, 8, 6]
	assert_ne(config.validate(), "", "max falls from tier 4 to 5")
	config = _valid()
	config.tier_word_min_length = [2, 3, 4, 3, 5]
	assert_ne(config.validate(), "", "min falls from tier 3 to 4")


func test_bad_word_bands() -> void:
	var config: TierConfig = _valid()
	config.tier_word_min_length = [2, 5, 3, 4, 5]
	assert_ne(config.validate(), "", "min > max (tier 2: 5-4)")
	config = _valid()
	config.tier_word_min_length = [1, 3, 3, 4, 5]
	assert_ne(config.validate(), "", "min < 2")
	config = _valid()
	config.tier_word_max_length = [4, 4, 5, 6, 9]
	assert_ne(config.validate(), "", "max > 8")
