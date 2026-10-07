extends GutTest
## Word source (Story 6.2): a bag of whole words, no immediate repeat (also across bags), seeded, and
## the band filter that builds its pool from the tagged word list.

const SEEDS: Array[int] = [1, 2, 3, 42, 12345]
const WORDS_PATH: String = "res://data/content/words.json"


func _pool() -> Array[String]:
	var out: Array[String] = ["dad", "cat", "fish", "jump", "sky", "hat", "ram"]
	return out


func _make(rng_seed: int, pool: Array[String] = _pool()) -> WordSource:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return WordSource.new(rng, pool)


func _draw(source: WordSource, count: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in count:
		out.append(source.current())
		source.advance()
	return out


func _json(text: String) -> JSON:
	var json: JSON = JSON.new()
	assert_eq(json.parse(text), OK, "test JSON parses")
	return json


func _assert_no_adjacent_repeat(draws: Array[String], label: String) -> void:
	for i: int in range(1, draws.size()):
		if draws[i] == draws[i - 1]:
			fail_test("%s: repeat '%s' at index %d" % [label, draws[i], i])
			return
	pass_test("%s: no adjacent repeat" % label)


func test_is_a_target_source() -> void:
	assert_true(_make(1) is TargetSource)


func test_never_same_word_twice_in_a_row() -> void:
	for rng_seed: int in SEEDS:
		_assert_no_adjacent_repeat(_draw(_make(rng_seed), 600), "seed %d" % rng_seed)


func test_never_same_word_twice_in_a_row_with_a_tiny_pool() -> void:
	# Three words: the bag boundary repeats often unless the rule holds.
	var tiny: Array[String] = ["dad", "cat", "sky"]
	for rng_seed: int in SEEDS:
		_assert_no_adjacent_repeat(_draw(_make(rng_seed, tiny), 600), "tiny seed %d" % rng_seed)


func test_whole_words_are_dealt() -> void:
	var draws: Array[String] = _draw(_make(5), 50)
	for word: String in draws:
		assert_has(_pool(), word)


func test_same_seed_same_words() -> void:
	for rng_seed: int in SEEDS:
		assert_eq(_draw(_make(rng_seed), 200), _draw(_make(rng_seed), 200), "seed %d" % rng_seed)


func test_different_seeds_differ() -> void:
	assert_ne(_draw(_make(1), 50), _draw(_make(2), 50))


func test_peek_does_not_consume_and_matches_later_currents() -> void:
	var source: WordSource = _make(42)
	var first: String = source.current()
	var ahead: Array[String] = source.peek(5)
	assert_eq(ahead.size(), 5)
	assert_eq(source.current(), first, "peek does not consume")
	for word: String in ahead:
		source.advance()
		assert_eq(source.current(), word)


func test_pool_band_filter_is_inclusive_and_keeps_order() -> void:
	var json: JSON = _json('{"words": [{"word": "at"}, {"word": "dad"}, {"word": "fish"},'
			+ ' {"word": "jumps"}, {"word": "jumped"}, {"word": "cat"}]}')
	assert_eq(WordSource.pool_from_json(json, 3, 5), ["dad", "fish", "jumps", "cat"] as Array[String])


func test_pool_skips_bad_and_repeated_entries() -> void:
	var json: JSON = _json('{"words": [{"word": "Dad"}, {"word": "c-t"}, {"word": 123},'
			+ ' {"rows": ["home"]}, {"word": "sky"}, {"word": "sky"}, {"word": "hat"}]}')
	assert_eq(WordSource.pool_from_json(json, 3, 5), ["sky", "hat"] as Array[String])


func test_pool_uses_the_word_length_not_the_length_field() -> void:
	var json: JSON = _json('{"words": [{"word": "dad", "length": 9}]}')
	assert_eq(WordSource.pool_from_json(json, 3, 5), ["dad"] as Array[String])


func test_pool_from_null_json_is_empty() -> void:
	assert_eq(WordSource.pool_from_json(null, 3, 5), [] as Array[String])
	assert_push_error("[ERROR][typing]")


func test_pool_from_non_dictionary_data_is_empty() -> void:
	assert_eq(WordSource.pool_from_json(_json('["dad", "cat"]'), 3, 5), [] as Array[String])
	assert_push_error("[ERROR][typing]")


func test_pool_without_words_array_is_empty() -> void:
	assert_eq(WordSource.pool_from_json(_json('{"schema": 1}'), 3, 5), [] as Array[String])
	assert_eq(WordSource.pool_from_json(_json('{"words": "dad"}'), 3, 5), [] as Array[String])
	assert_push_error_count(2)


func test_pool_skips_a_non_dictionary_entry_and_keeps_the_rest() -> void:
	var json: JSON = _json('{"words": [{"word": "dad"}, "cat", {"word": "sky"}]}')
	assert_eq(WordSource.pool_from_json(json, 3, 5), ["dad", "sky"] as Array[String])
	assert_push_error("[ERROR][typing]")


func test_shipped_word_list_has_the_starter_band() -> void:
	var json: JSON = load(WORDS_PATH) as JSON
	assert_not_null(json, "words.json loads as a JSON resource")
	var pool: Array[String] = WordSource.pool_from_json(
			json, WordTagger.STARTER_BAND_MIN_LEN, WordTagger.STARTER_BAND_MAX_LEN)
	assert_true(pool.size() >= WordTagger.STARTER_BAND_MIN_COUNT, "%d words in 3-5" % pool.size())
	for word: String in pool:
		if word.length() < 3 or word.length() > 5:
			fail_test("'%s' is outside 3-5" % word)
			return
	pass_test("every pool word is 3-5 letters")
