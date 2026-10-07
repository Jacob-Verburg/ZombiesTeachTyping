extends GutTest
## Test level (Story 2.4): shows the current letter, a brain every 4th correct key, short outro.

const LevelScene: PackedScene = preload("res://scenes/levels/test_level/test_level.tscn")
const LevelScript := preload("res://scripts/levels/test_level/test_level.gd")


func _level() -> LevelBase:
	var level: LevelBase = LevelScene.instantiate() as LevelBase
	add_child_autofree(level)
	return level


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func _letter(level: LevelBase) -> String:
	return (level.get_node("%LetterLabel") as Label).text


func test_config() -> void:
	var config: LevelConfig = _level().get_level_config()
	assert_not_null(config)
	assert_eq(config.duration_s, 120.0)
	assert_false(config.case_sensitive)
	assert_false(config.space_is_input)
	assert_eq(config.target_mode, LevelConfig.TargetMode.LETTER)


func test_alphabet() -> void:
	var letters: Array[String] = LevelScript.alphabet()
	assert_eq(letters.size(), 26)
	assert_eq(letters[0], "a")
	assert_eq(letters[25], "z")


func test_shows_current_letter() -> void:
	var level: LevelBase = _level()
	var source: TargetSource = level.create_target_source(_rng(3))
	assert_not_null(source)
	assert_true(source is LetterBagSource)
	assert_eq(_letter(level), source.current())
	assert_ne(_letter(level), "")


func test_brain_every_fourth_correct_key() -> void:
	var level: LevelBase = _level()
	var source: TargetSource = level.create_target_source(_rng(5))
	watch_signals(level)
	for index: int in 8:
		var expected: String = source.current()
		source.advance()
		level.on_char_accepted(expected, index)
		assert_eq(_letter(level), source.current(), "label shows the new target after key %d" % index)
		if index == 2:
			assert_signal_emit_count(level, "brains_earned_changed", 0)
	assert_signal_emit_count(level, "brains_earned_changed", 2)
	assert_eq(get_signal_parameters(level, "brains_earned_changed", 0), [1])
	assert_eq(get_signal_parameters(level, "brains_earned_changed", 1), [2])
	assert_eq(level.get_brains_earned(), 2)


func test_brain_lands_on_index_three() -> void:
	var level: LevelBase = _level()
	var source: TargetSource = level.create_target_source(_rng(5))
	watch_signals(level)
	for index: int in 3:
		source.advance()
		level.on_char_accepted("x", index)
	assert_signal_emit_count(level, "brains_earned_changed", 0)
	source.advance()
	level.on_char_accepted("x", 3)
	assert_signal_emit_count(level, "brains_earned_changed", 1)
	assert_eq(level.get_brains_earned(), 1)


func test_run_ending_returns_outro() -> void:
	var level: LevelBase = _level()
	level.create_target_source(_rng(1))
	assert_eq(level.on_run_ending(GameConstants.END_REASON_TIMER), LevelScript.OUTRO_S)
	assert_eq((level.get_node("%StatusLabel") as Label).text, "Time!")


func test_same_seed_same_letters() -> void:
	var a: TargetSource = _level().create_target_source(_rng(11))
	var b: TargetSource = _level().create_target_source(_rng(11))
	var c: TargetSource = _level().create_target_source(_rng(12))
	var seq_a: Array[String] = []
	var seq_b: Array[String] = []
	var seq_c: Array[String] = []
	for i: int in 10:
		seq_a.append(a.current())
		seq_b.append(b.current())
		seq_c.append(c.current())
		a.advance()
		b.advance()
		c.advance()
	assert_eq(seq_a, seq_b)
	assert_ne(seq_a, seq_c)


func test_source_has_its_own_rng() -> void:
	# Drawing from the run RNG after creation must not change the letters (2.2 RNG-sharing fix).
	var rng_a: RandomNumberGenerator = _rng(21)
	var rng_b: RandomNumberGenerator = _rng(21)
	var a: TargetSource = _level().create_target_source(rng_a)
	var b: TargetSource = _level().create_target_source(rng_b)
	for i: int in 30:
		rng_b.randi()
		assert_eq(a.current(), b.current(), "letter %d" % i)
		a.advance()
		b.advance()


# --- word mode (Story 6.2) ------------------------------------------------------

const WordLevelScene: PackedScene = preload("res://scenes/levels/test_level/test_word_level.tscn")


func _word_level() -> LevelBase:
	var level: LevelBase = WordLevelScene.instantiate() as LevelBase
	add_child_autofree(level)
	return level


func test_word_config() -> void:
	var config: LevelConfig = _word_level().get_level_config()
	assert_eq(config.target_mode, LevelConfig.TargetMode.WORD)
	assert_eq(config.duration_s, 120.0)
	assert_false(config.space_is_input)
	assert_eq(config.word_min_length, 3)
	assert_eq(config.word_max_length, 5)
	assert_not_null(config.word_list)
	assert_eq(config.word_list.resource_path, "res://data/content/words.json")


func test_word_mode_builds_a_word_source() -> void:
	var level: LevelBase = _word_level()
	var source: TargetSource = level.create_target_source(_rng(3))
	assert_true(source is WordSource)
	assert_between(source.current().length(), 3, 5)
	assert_eq(_letter(level), source.current())


func test_word_mode_same_seed_same_words() -> void:
	var a: TargetSource = _word_level().create_target_source(_rng(9))
	var b: TargetSource = _word_level().create_target_source(_rng(9))
	assert_eq(a.peek(20), b.peek(20))


func test_word_mode_too_small_band_returns_null() -> void:
	var level: LevelBase = _word_level()
	var config: LevelConfig = level.get_level_config().duplicate() as LevelConfig
	config.word_min_length = 7
	config.word_max_length = 7
	level.config = config
	var json: JSON = JSON.new()
	json.parse('{"words": [{"word": "pumpkin"}]}')
	config.word_list = json
	assert_null(level.create_target_source(_rng(1)))
	assert_push_error("[ERROR][level]")


func test_word_mode_brain_per_completed_word() -> void:
	var level: LevelBase = _word_level()
	var source: TargetSource = level.create_target_source(_rng(5))
	watch_signals(level)
	var word: String = source.current()
	for i: int in word.length() - 1:
		level.on_char_accepted(word[i], i)
	assert_signal_emit_count(level, "brains_earned_changed", 0, "no per-key brains in word mode")
	source.advance()
	level.on_char_accepted(word[word.length() - 1], word.length() - 1)
	level.on_target_completed(word)
	assert_signal_emit_count(level, "brains_earned_changed", 1)
	assert_signal_emitted_with_parameters(level, "brains_earned_changed", [1])
	assert_eq(level.get_brains_earned(), 1)
	assert_eq(_letter(level), source.current())
