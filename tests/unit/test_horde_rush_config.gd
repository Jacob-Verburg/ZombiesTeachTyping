extends GutTest
## HordeRushConfig (Story 6.3): the shipped numbers in horde_rush.tres, size_class_for() band edges and
## validate() on bad configs. Bad configs are built in-test; the shipped resource is never edited.

const CONFIG_PATH: String = "res://data/levels/horde_rush.tres"


func _shipped() -> HordeRushConfig:
	return load(CONFIG_PATH) as HordeRushConfig


## A valid in-test config: small ≤3, medium ≤5, brute rest.
func _valid() -> HordeRushConfig:
	var config: HordeRushConfig = HordeRushConfig.new()
	config.duration_s = 60.0
	config.target_mode = LevelConfig.TargetMode.WORD
	config.word_list = _shipped().word_list
	config.word_min_length = 3
	config.word_max_length = 5
	config.lane_count = 3
	config.size_classes = [_size(&"small", 3, 8.0, 1), _size(&"medium", 5, 10.0, 2), _size(&"brute", 0, 13.0, 3)]
	return config


func _size(id: StringName, max_len: int, crossing: float, hits: int) -> HordeSizeClass:
	var size_class: HordeSizeClass = HordeSizeClass.new()
	size_class.id = id
	size_class.max_word_length = max_len
	size_class.crossing_time_s = crossing
	size_class.hits_to_stop = hits
	size_class.arrival_brains = hits
	size_class.sprite_scale = 1.0
	return size_class


func test_shipped_config_loads_and_is_valid() -> void:
	var config: HordeRushConfig = _shipped()
	assert_not_null(config, "horde_rush.tres is a HordeRushConfig")
	assert_eq(config.validate(), "")
	assert_eq(config.duration_s, 300.0)
	assert_eq(config.lane_count, 5)
	assert_eq(config.target_mode, LevelConfig.TargetMode.WORD)
	assert_false(config.space_is_input)
	assert_false(config.case_sensitive)
	assert_eq(config.word_min_length, 3)
	assert_eq(config.word_max_length, 5)
	assert_eq(config.completion_bonus, 0, "Story 6.5 sets the +25")
	assert_eq(config.music_id, &"", "march music is Story 6.6")
	assert_eq(config.word_list.resource_path, "res://data/content/words.json")


func test_shipped_size_classes() -> void:
	var config: HordeRushConfig = _shipped()
	var ids: Array[StringName] = []
	var scales: Array[float] = []
	for size_class: HordeSizeClass in config.size_classes:
		ids.append(size_class.id)
		scales.append(size_class.sprite_scale)
	assert_eq(ids, [&"small", &"medium", &"brute"] as Array[StringName])
	assert_eq(scales, [1.0, 1.25, 1.5] as Array[float])


func _assert_class(config: HordeRushConfig, length: int, id: StringName, crossing: float, hits: int,
		brains: int) -> void:
	var size_class: HordeSizeClass = config.size_class_for(length)
	assert_not_null(size_class, "class for length %d" % length)
	if size_class == null:
		return
	assert_eq(size_class.id, id, "length %d" % length)
	assert_eq(size_class.crossing_time_s, crossing, "length %d crossing" % length)
	assert_eq(size_class.hits_to_stop, hits, "length %d hits" % length)
	assert_eq(size_class.arrival_brains, brains, "length %d brains" % length)


func test_size_class_for_band_edges() -> void:
	var config: HordeRushConfig = _shipped()
	for length: int in [1, 2, 3]:
		_assert_class(config, length, &"small", 8.0, 1, 1)
	for length: int in [4, 5]:
		_assert_class(config, length, &"medium", 10.0, 2, 2)
	for length: int in [6, 7, 12]:
		_assert_class(config, length, &"brute", 13.0, 3, 3)


func test_size_class_for_without_classes_is_null() -> void:
	assert_null(HordeRushConfig.new().size_class_for(3))


func test_in_test_config_is_valid() -> void:
	assert_eq(_valid().validate(), "")


func test_validate_catches_each_bad_case() -> void:
	var cases: Dictionary[String, Callable] = {
		"no classes": func(c: HordeRushConfig) -> void: c.size_classes = [],
		"null class": func(c: HordeRushConfig) -> void: c.size_classes[1] = null,
		"zero crossing": func(c: HordeRushConfig) -> void: c.size_classes[0].crossing_time_s = 0.0,
		"inf crossing": func(c: HordeRushConfig) -> void: c.size_classes[0].crossing_time_s = INF,
		"zero hits": func(c: HordeRushConfig) -> void: c.size_classes[1].hits_to_stop = 0,
		"negative brains": func(c: HordeRushConfig) -> void: c.size_classes[1].arrival_brains = -1,
		"zero scale": func(c: HordeRushConfig) -> void: c.size_classes[2].sprite_scale = 0.0,
		"non-ascending max": func(c: HordeRushConfig) -> void: c.size_classes[1].max_word_length = 3,
		"0 max not last": func(c: HordeRushConfig) -> void: c.size_classes[1].max_word_length = 0,
		"last has a max": func(c: HordeRushConfig) -> void: c.size_classes[2].max_word_length = 9,
		"lane_count 0": func(c: HordeRushConfig) -> void: c.lane_count = 0,
		"letter mode": func(c: HordeRushConfig) -> void: c.target_mode = LevelConfig.TargetMode.LETTER,
		"null word list": func(c: HordeRushConfig) -> void: c.word_list = null,
		"min > max": func(c: HordeRushConfig) -> void: c.word_min_length = 6,
		"min 0": func(c: HordeRushConfig) -> void: c.word_min_length = 0,
		"duration 0": func(c: HordeRushConfig) -> void: c.duration_s = 0.0,
	}
	for label: String in cases:
		var config: HordeRushConfig = _valid()
		cases[label].call(config)
		assert_ne(config.validate(), "", label)


func test_a_single_unbounded_class_is_valid() -> void:
	var config: HordeRushConfig = _valid()
	config.size_classes = [_size(&"only", 0, 5.0, 1)]
	assert_eq(config.validate(), "")
	assert_eq(config.size_class_for(1).id, &"only")
	assert_eq(config.size_class_for(40).id, &"only")
