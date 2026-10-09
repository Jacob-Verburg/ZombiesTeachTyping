extends GutTest
## Zombie Run follows the tier (Story 7.5, FR64): tier 1 deals the home row, tier 2 home + top, tiers 3-5
## and tier 0 deal the same letters as an untiered level for the same seed, the run record label, the
## too-small fallback, and the FR64 invariance (the amble and the config never depend on the tier).
## The level is disabled; tests call _process(delta) by hand, like test_zombie_run_level.gd.

const LevelScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_level.tscn")
const LevelScript := preload("res://scripts/levels/zombie_run/zombie_run_level.gd")
const TIER_CONFIG: TierConfig = preload("res://data/tier_config.tres")
const SEEDS: Array[int] = [1, 7, 42, 12345]
## Written out on purpose (6.1 review): not WordTagger's constants.
const HOME_ROW: String = "asdfghjkl"
const TOP_ROW: String = "qwertyuiop"
const BOTTOM_ROW: String = "zxcvbnm"


## A level with the recorders set, tier handed down (unless `tier` < 0: no set_tier call at all) and a
## source built from `rng_seed`.
func _make(rng_seed: int, tier: int = -1, tier_config: TierConfig = TIER_CONFIG) -> LevelScript:
	var level: LevelScript = LevelScene.instantiate() as LevelScript
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.play_sfx = func(_id: StringName) -> void: pass
	level.request_voice = func(_id: StringName) -> void: pass
	add_child_autofree(level)
	if tier >= 0:
		level.set_tier(tier, tier_config)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	assert_not_null(level.create_target_source(rng), "the level builds a source")
	return level


## The next `count` letters of the level's source (drawn straight from the source).
func _deal(level: LevelScript, count: int) -> Array[String]:
	var source: LetterBagSource = level._source
	var out: Array[String] = []
	for i: int in count:
		out.append(source.current())
		source.advance()
	return out


func test_tier_1_deals_only_and_all_of_the_home_row() -> void:
	for rng_seed: int in SEEDS:
		var letters: Array[String] = _deal(_make(rng_seed, 1), 18)
		var seen: Dictionary = {}
		for letter: String in letters:
			assert_true(HOME_ROW.contains(letter), "seed %d: '%s' is home row" % [rng_seed, letter])
			seen[letter] = true
		assert_eq(seen.size(), 9, "seed %d: two bags deal all 9 home-row letters" % rng_seed)


func test_tier_1_pool_is_the_home_row_in_letter_pool_order() -> void:
	var level: LevelScript = _make(1, 1)
	assert_eq(level._letter_pool(), ["a", "d", "f", "g", "h", "j", "k", "l", "s"] as Array[String])


func test_tier_2_is_home_and_top_without_the_bottom_row() -> void:
	var level: LevelScript = _make(1, 2)
	var pool: Array[String] = level._letter_pool()
	assert_eq(pool.size(), 19)
	for letter: String in pool:
		assert_true(HOME_ROW.contains(letter) or TOP_ROW.contains(letter), "'%s' is home or top" % letter)
		assert_false(BOTTOM_ROW.contains(letter), "'%s' is not bottom row" % letter)
	for letter: String in _deal(_make(42, 2), 60):
		assert_false(BOTTOM_ROW.contains(letter), "dealt '%s' is not bottom row" % letter)


func test_tiers_0_3_4_5_deal_the_untiered_sequence() -> void:
	for rng_seed: int in SEEDS:
		var untiered: Array[String] = _deal(_make(rng_seed), 80)
		for tier: int in [0, 3, 4, 5]:
			assert_eq(_deal(_make(rng_seed, tier), 80), untiered, "seed %d tier %d" % [rng_seed, tier])


func test_labels() -> void:
	assert_eq(_make(1).get_pool_label(), "all", "never handed a tier")
	assert_eq(_make(1, 0).get_pool_label(), "all", "tier 0 (placement run)")
	assert_eq(_make(1, 1).get_pool_label(), "tier_1")
	assert_eq(_make(1, 2).get_pool_label(), "tier_2")
	assert_eq(_make(1, 5).get_pool_label(), "tier_5")


func test_a_tier_above_tier_count_is_untiered() -> void:
	var level: LevelScript = _make(42, TIER_CONFIG.tier_count() + 1)
	assert_eq(level.get_pool_label(), "all")
	assert_eq(_deal(level, 40), _deal(_make(42), 40))


func test_a_null_config_is_untiered() -> void:
	var level: LevelScript = _make(42, 1, null)
	assert_eq(level.get_pool_label(), "all")
	assert_eq(_deal(level, 40), _deal(_make(42), 40))


func test_a_too_small_tier_pool_falls_back_to_all_letters() -> void:
	# validate() forbids a 0 row count, so this config is never validated on purpose.
	var broken: TierConfig = TIER_CONFIG.duplicate(true) as TierConfig
	broken.tier_row_counts = [0, 0, 0, 0, 0] as Array[int]
	var level: LevelScript = _make(42, 1, broken)
	assert_push_error("[ERROR][level]")
	assert_eq(level.get_pool_label(), "all")
	assert_eq(_deal(level, 40), _deal(_make(42), 40), "the whole letter_pool, same seed order")


func test_a_node_run_twice_resets_the_label() -> void:
	var level: LevelScript = _make(1, 1)
	assert_eq(level.get_pool_label(), "tier_1")
	level.set_tier(0, TIER_CONFIG)
	level._letter_pool()
	assert_eq(level.get_pool_label(), "all")


func test_fr64_the_amble_does_not_depend_on_the_tier() -> void:
	var low: LevelScript = _make(42, 1)
	var high: LevelScript = _make(42, 5)
	assert_eq(low.get_zombie_x(), high.get_zombie_x(), "same start")
	for i: int in 30:
		low._process(0.1)
		high._process(0.1)
		assert_eq(low.get_zombie_x(), high.get_zombie_x(), "same x after %d steps" % (i + 1))


func test_fr64_the_level_never_changes_its_config() -> void:
	var level: LevelScript = LevelScene.instantiate() as LevelScript
	var before: Dictionary = _snapshot(level.config)
	level.free()
	for tier: int in [0, 1, 2, 5]:
		var played: LevelScript = _make(42, tier)
		_deal(played, 30)
		played._process(1.0)
		assert_eq(_snapshot(played.config), before, "tier %d leaves the config alone" % tier)


## Every stored property of `resource`, arrays copied, so a later change shows up.
func _snapshot(resource: Resource) -> Dictionary:
	var out: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = resource.get(property["name"])
		out[property["name"]] = (value as Array).duplicate() if value is Array else value
	return out
