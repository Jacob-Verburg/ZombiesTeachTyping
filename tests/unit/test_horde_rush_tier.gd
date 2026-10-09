extends GutTest
## Horde Rush follows the tier (Story 7.5, FR62/FR64): tier n draws tier n's words in its band from
## LevelConfig.tier_word_pools; tier 0, no pools, or a missing tier keep the fixed 3-5 band with today's
## seed order; the run record label; and FR64 invariance (the defender and the config never depend on the
## tier). The level is disabled; tests call the logic by hand, like test_horde_rush_level.gd.

const LevelScene: PackedScene = preload("res://scenes/levels/horde_rush/horde_rush_level.tscn")
const LevelScript := preload("res://scripts/levels/horde_rush/horde_rush_level.gd")
const TIER_CONFIG: TierConfig = preload("res://data/tier_config.tres")
const SEEDS: Array[int] = [1, 7, 42, 12345]
const STEP: float = 1.0 / 60.0
## Written out on purpose (6.1 review): not WordTagger's constants.
const HOME_ROW: String = "asdfghjkl"


## A level with the recorders set, the tier handed down (unless `tier` < 0: no set_tier call) and a
## source built from `rng_seed`. `tweak` (optional) changes a deep duplicate of the shipped config.
func _make(rng_seed: int, tier: int = -1, tweak: Callable = Callable()) -> LevelScript:
	var level: LevelScript = LevelScene.instantiate() as LevelScript
	level.process_mode = Node.PROCESS_MODE_DISABLED
	if tweak.is_valid():
		var config: HordeRushConfig = (level.config as HordeRushConfig).duplicate(true) as HordeRushConfig
		tweak.call(config)
		level.config = config
	level.request_voice = func(_id: StringName) -> void: pass
	level.play_sfx = func(_id: StringName) -> void: pass
	add_child_autofree(level)
	if tier >= 0:
		level.set_tier(tier, TIER_CONFIG)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	assert_not_null(level.create_target_source(rng), "the level builds a source")
	return level


func _deal(level: LevelScript, count: int) -> Array[String]:
	var source: WordSource = level._source
	var out: Array[String] = []
	for i: int in count:
		out.append(source.current())
		source.advance()
	return out


func _assert_band(words: Array[String], low: int, high: int, label: String) -> void:
	assert_false(words.is_empty(), "%s: words were dealt" % label)
	for word: String in words:
		if word.length() < low or word.length() > high:
			fail_test("%s: '%s' is outside %d-%d" % [label, word, low, high])
			return
	pass_test("%s: every word is %d-%d letters" % [label, low, high])


func test_tier_1_words_are_home_row_and_2_to_4_letters() -> void:
	for rng_seed: int in SEEDS:
		var words: Array[String] = _deal(_make(rng_seed, 1), 80)
		_assert_band(words, 2, 4, "seed %d" % rng_seed)
		for word: String in words:
			for c: String in word:
				assert_true(HOME_ROW.contains(c), "seed %d: '%s' is home row" % [rng_seed, word])


func test_tiers_2_to_4_use_their_own_bands() -> void:
	var bands: Dictionary = {2: Vector2i(3, 4), 3: Vector2i(3, 5), 4: Vector2i(4, 6)}
	for tier: int in bands:
		var band: Vector2i = bands[tier]
		assert_eq(TIER_CONFIG.word_band_of(tier), band, "tier %d band in the shipped config" % tier)
		for rng_seed: int in SEEDS:
			var level: LevelScript = _make(rng_seed, tier)
			assert_eq(level.get_pool_label(), "tier_%d" % tier)
			_assert_band(_deal(level, 100), band.x, band.y, "tier %d seed %d" % [tier, rng_seed])


func test_tier_5_words_are_5_to_8_letters() -> void:
	for rng_seed: int in SEEDS:
		_assert_band(_deal(_make(rng_seed, 5), 200), 5, 8, "seed %d" % rng_seed)


func test_tier_0_deals_todays_words() -> void:
	for rng_seed: int in SEEDS:
		var untiered: Array[String] = _deal(_make(rng_seed), 100)
		_assert_band(untiered, 3, 5, "untiered seed %d" % rng_seed)
		assert_eq(_deal(_make(rng_seed, 0), 100), untiered, "seed %d tier 0" % rng_seed)


func test_no_tier_pools_ignores_the_tier() -> void:
	var level: LevelScript = _make(42, 1, func(c: HordeRushConfig) -> void: c.tier_word_pools = null)
	assert_eq(level.get_pool_label(), "all")
	assert_eq(_deal(level, 60), _deal(_make(42), 60), "the fixed band, same seed order")


func test_a_tier_missing_from_the_pools_falls_back_to_the_fixed_band() -> void:
	var json: JSON = JSON.new()
	assert_eq(json.parse('{"schema": 1, "tiers": [{"tier": 2, "words": ["sky", "hat"]}]}'), OK)
	var level: LevelScript = _make(42, 1, func(c: HordeRushConfig) -> void: c.tier_word_pools = json)
	assert_push_error("[ERROR][typing]", "WordSource: no words for the tier")
	assert_push_error("[ERROR][level]", "the level falls back")
	assert_eq(level.get_pool_label(), "all")
	assert_eq(_deal(level, 60), _deal(_make(42), 60), "the fixed 3-5 band, same seed order")


func test_a_one_word_tier_pool_falls_back_to_the_fixed_band() -> void:
	var json: JSON = JSON.new()
	assert_eq(json.parse('{"tiers": [{"tier": 1, "words": ["dad"]}]}'), OK)
	var level: LevelScript = _make(42, 1, func(c: HordeRushConfig) -> void: c.tier_word_pools = json)
	assert_push_error("[ERROR][level]")
	assert_eq(level.get_pool_label(), "all")
	_assert_band(_deal(level, 40), 3, 5, "fallback")


func test_labels() -> void:
	assert_eq(_make(1).get_pool_label(), "all", "never handed a tier")
	assert_eq(_make(1, 0).get_pool_label(), "all", "tier 0")
	assert_eq(_make(1, 1).get_pool_label(), "tier_1")
	assert_eq(_make(1, 5).get_pool_label(), "tier_5")


func test_a_node_run_again_untiered_resets_the_label() -> void:
	var level: LevelScript = _make(1, 1)
	assert_eq(level.get_pool_label(), "tier_1")
	level.set_tier(0, TIER_CONFIG)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	assert_not_null(level.create_target_source(rng))
	assert_eq(level.get_pool_label(), "all")


func test_fr64_the_defender_does_not_depend_on_the_tier() -> void:
	var low: LevelScript = _make(42, 1)
	var high: LevelScript = _make(42, 5)
	low.on_run_started()
	high.on_run_started()
	for i: int in 600:
		low._logic_step(STEP)
		high._logic_step(STEP)
		assert_eq(low.get_defender().position(), high.get_defender().position(), "step %d" % i)
	assert_eq(low.get_defender().get_thrown_count(), high.get_defender().get_thrown_count())


func test_fr64_the_level_never_changes_its_config() -> void:
	var fresh: LevelScript = LevelScene.instantiate() as LevelScript
	var before: Dictionary = _snapshot(fresh.config)
	fresh.free()
	for tier: int in [0, 1, 5]:
		var level: LevelScript = _make(42, tier)
		level.on_run_started()
		for word: String in _deal(level, 5):
			level.on_target_completed(word)
		for i: int in 120:
			level._logic_step(STEP)
		assert_eq(_snapshot(level.config), before, "tier %d leaves the config alone" % tier)


## Every stored property of `resource`, arrays and nested resources copied, so a later change shows up.
func _snapshot(resource: Resource) -> Dictionary:
	var out: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		out[property["name"]] = _copy(resource.get(property["name"]))
	return out


func _copy(value: Variant) -> Variant:
	if value is JSON:
		return (value as JSON).resource_path
	if value is Resource:
		return _snapshot(value as Resource)
	if value is Array:
		var items: Array = []
		for item: Variant in value as Array:
			items.append(_copy(item))
		return items
	return value
