extends GutTest
## ThemePicker (Story 10.1, FR76): one theme per run, never the previous one when there is a choice, drawn
## from its own RNG built from the run seed.


func _theme(id: StringName) -> LevelTheme:
	var theme: LevelTheme = LevelTheme.new()
	theme.id = id
	return theme


func _themes(ids: Array[StringName]) -> Array[LevelTheme]:
	var result: Array[LevelTheme] = []
	for id: StringName in ids:
		result.append(_theme(id))
	return result


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## The ids picked over `draws` draws from one rng, as sorted Strings (never sort StringNames).
func _picked(themes: Array[LevelTheme], last_id: StringName, draws: int) -> Array[String]:
	var rng: RandomNumberGenerator = _rng(7)
	var seen: Array[String] = []
	for i: int in draws:
		var id: String = String(ThemePicker.pick(themes, last_id, rng).id)
		if not seen.has(id):
			seen.append(id)
	seen.sort()
	return seen


func test_no_themes_is_null() -> void:
	assert_null(ThemePicker.pick([] as Array[LevelTheme], &"", _rng(1)))
	var only_nulls: Array[LevelTheme] = [null, null]
	assert_null(ThemePicker.pick(only_nulls, &"", _rng(1)))


func test_a_single_theme_is_picked_without_a_draw() -> void:
	var themes: Array[LevelTheme] = _themes([&"a"])
	var rng: RandomNumberGenerator = _rng(5)
	var state: int = rng.state
	assert_eq(ThemePicker.pick(themes, &"", rng), themes[0])
	assert_eq(ThemePicker.pick(themes, &"a", rng), themes[0], "the only theme even when it was the last")
	assert_eq(rng.state, state, "no draw for a single theme")


func test_two_themes_never_repeat_the_last() -> void:
	var themes: Array[LevelTheme] = _themes([&"a", &"b"])
	assert_eq(_picked(themes, &"a", 100), ["b"] as Array[String])
	assert_eq(_picked(themes, &"b", 100), ["a"] as Array[String])


func test_three_themes_skip_the_last_and_use_the_rest() -> void:
	var themes: Array[LevelTheme] = _themes([&"a", &"b", &"c"])
	assert_eq(_picked(themes, &"b", 200), ["a", "c"] as Array[String])


func test_unknown_or_empty_last_uses_all() -> void:
	var themes: Array[LevelTheme] = _themes([&"a", &"b", &"c"])
	assert_eq(_picked(themes, &"", 200), ["a", "b", "c"] as Array[String])
	assert_eq(_picked(themes, &"zzz", 200), ["a", "b", "c"] as Array[String])


func test_null_entries_are_skipped() -> void:
	var themes: Array[LevelTheme] = [null, _theme(&"a"), null, _theme(&"b")]
	assert_eq(_picked(themes, &"a", 100), ["b"] as Array[String])
	var one: Array[LevelTheme] = [null, _theme(&"a")]
	var rng: RandomNumberGenerator = _rng(3)
	var state: int = rng.state
	assert_eq(ThemePicker.pick(one, &"", rng).id, &"a")
	assert_eq(rng.state, state, "one usable theme draws nothing")


func test_duplicate_ids_all_last_fall_back_to_all() -> void:
	var themes: Array[LevelTheme] = _themes([&"a", &"a"])
	assert_not_null(ThemePicker.pick(themes, &"a", _rng(1)))


func test_same_seed_same_pick() -> void:
	var themes: Array[LevelTheme] = _themes([&"a", &"b", &"c", &"d"])
	for run_seed: int in [1, 42, 999]:
		var first: LevelTheme = ThemePicker.pick(themes, &"", ThemePicker.theme_rng(run_seed))
		var second: LevelTheme = ThemePicker.pick(themes, &"", ThemePicker.theme_rng(run_seed))
		assert_eq(first, second, "seed %d" % run_seed)


func test_theme_rng_is_deterministic_and_seed_dependent() -> void:
	var a: RandomNumberGenerator = ThemePicker.theme_rng(42)
	var b: RandomNumberGenerator = ThemePicker.theme_rng(42)
	var c: RandomNumberGenerator = ThemePicker.theme_rng(43)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	var seq_c: Array[int] = []
	for i: int in 5:
		seq_a.append(a.randi())
		seq_b.append(b.randi())
		seq_c.append(c.randi())
	assert_eq(seq_a, seq_b)
	assert_ne(seq_a, seq_c)


func test_theme_rng_does_not_mirror_the_run_rng() -> void:
	var run: RandomNumberGenerator = _rng(42)
	assert_ne(ThemePicker.theme_rng(42).randi(), run.randi(), "the theme draw is not the run's first draw")
