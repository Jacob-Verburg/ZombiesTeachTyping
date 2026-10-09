extends GutTest
## SentenceGenerator (Story 8.1, FR67): sentence shape, words from the shipped tier 1-2 pools, commas
## per tier, seed determinism, small pools and bad inputs.

const POOLS_PATH: String = "res://data/content/word_pools.json"
const CONFIG_PATH: String = "res://data/tier_config.tres"
## The GDD row letters, written out again here on purpose (independent of WordTagger's constants).
const TIER_LETTERS: Array[String] = ["asdfghjkl", "asdfghjklqwertyuiop"]
const SENTENCES: int = 500

var _pools: Array = [[] as Array[String], [] as Array[String]]
var _loaded: bool = false


func before_each() -> void:
	var json: JSON = load(POOLS_PATH) as JSON
	var config: TierConfig = load(CONFIG_PATH) as TierConfig
	assert_not_null(json, "word_pools.json loads")
	assert_not_null(config, "tier_config.tres loads")
	_loaded = false
	if json == null or config == null:
		return
	for tier: int in [1, 2]:
		var band: Vector2i = config.word_band_of(tier)
		_pools[tier - 1] = WordSource.tier_pool_from_json(json, tier, band.x, band.y)
	assert_eq((_pools[0] as Array).size(), 40, "tier 1 has 40 words")
	assert_gt((_pools[1] as Array).size(), 0, "tier 2 has words")
	_loaded = (_pools[0] as Array).size() > 0 and (_pools[1] as Array).size() > 0


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _pool(tier: int) -> Array[String]:
	return _pools[tier - 1]


func _sentences(gen: SentenceGenerator, n: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in n:
		out.append(gen.next_sentence())
	return out


## The sentence's words with their comma stripped and lowercased.
func _bare_words(sentence: String) -> PackedStringArray:
	var words: PackedStringArray = sentence.trim_suffix(".").split(" ")
	for i: int in words.size():
		words[i] = words[i].replace(",", "").to_lower()
	return words


func test_sentence_shape_and_words_for_tiers_1_and_2() -> void:
	if not _loaded:
		return
	for tier: int in [1, 2]:
		var pool: Array[String] = _pool(tier)
		var letters: String = TIER_LETTERS[tier - 1]
		var allowed: String = letters + letters.to_upper() + " .,"
		var counts_seen: Dictionary = {}
		var gen: SentenceGenerator = SentenceGenerator.for_tier(_rng(81 + tier), pool, tier)
		for s: String in _sentences(gen, SENTENCES):
			var words: PackedStringArray = s.split(" ")
			counts_seen[words.size()] = true
			assert_between(words.size(), 4, 7, "word count: %s" % s)
			assert_true(s[0] >= "A" and s[0] <= "Z", "capital first letter: %s" % s)
			var rest: String = words[0].substr(1).replace(",", "")
			assert_eq(rest, rest.to_lower(), "rest of the first word is lowercase: %s" % s)
			assert_true(s.ends_with(".") and not s.ends_with(".."), "one . at the end: %s" % s)
			assert_eq(s.count("."), 1, "no other .: %s" % s)
			assert_false(s.contains("  "), "no double space: %s" % s)
			assert_eq(s, s.strip_edges(), "no edge space: %s" % s)
			for w: String in _bare_words(s):
				assert_true(pool.has(w), "'%s' is in the tier %d pool" % [w, tier])
			for c: String in s:
				assert_true(allowed.contains(c), "'%s' is a tier %d character: %s" % [c, tier, s])
		for n: int in range(4, 8):
			assert_true(counts_seen.has(n), "tier %d: some sentence has %d words" % [tier, n])


func test_tier_1_never_has_a_comma() -> void:
	if not _loaded:
		return
	var gen: SentenceGenerator = SentenceGenerator.for_tier(_rng(1), _pool(1), 1)
	for s: String in _sentences(gen, SENTENCES):
		assert_false(s.contains(","), "no comma in tier 1: %s" % s)


func test_tier_2_commas() -> void:
	if not _loaded:
		return
	var gen: SentenceGenerator = SentenceGenerator.for_tier(_rng(2), _pool(2), 2)
	var with_comma: int = 0
	for s: String in _sentences(gen, SENTENCES):
		assert_lte(s.count(","), 1, "at most one comma: %s" % s)
		if not s.contains(","):
			continue
		with_comma += 1
		var words: PackedStringArray = s.split(" ")
		assert_false(words[0].contains(","), "not after the first word: %s" % s)
		assert_false(words[-1].contains(","), "not after the last word: %s" % s)
		assert_eq(s[s.find(",") + 1], " ", "a space after the comma: %s" % s)
	assert_gt(with_comma, 0, "some tier 2 sentences have a comma")
	assert_lt(with_comma, SENTENCES, "some tier 2 sentences have none")


func test_comma_rule_by_tier() -> void:
	assert_eq(ParagraphRules.COMMA_TIERS, [2] as Array[int])
	for tier: int in [1, 2]:
		var gen: SentenceGenerator = SentenceGenerator.for_tier(_rng(5), ["dad", "sad", "lad"] as Array[String], tier)
		var commas: int = 0
		for s: String in _sentences(gen, 100):
			commas += s.count(",")
		if tier == 1:
			assert_eq(commas, 0)
		else:
			assert_gt(commas, 0)


func test_same_seed_same_sentences() -> void:
	if not _loaded:
		return
	for tier: int in [1, 2]:
		var a: Array[String] = _sentences(SentenceGenerator.for_tier(_rng(42), _pool(tier), tier), 50)
		var b: Array[String] = _sentences(SentenceGenerator.for_tier(_rng(42), _pool(tier), tier), 50)
		var c: Array[String] = _sentences(SentenceGenerator.for_tier(_rng(43), _pool(tier), tier), 50)
		assert_eq(a, b, "tier %d: same seed, same sentences" % tier)
		assert_ne(a, c, "tier %d: another seed, other sentences" % tier)


func test_two_word_pool() -> void:
	var gen: SentenceGenerator = SentenceGenerator.new(_rng(7), ["dad", "sad"] as Array[String], true)
	for s: String in _sentences(gen, 100):
		var words: PackedStringArray = _bare_words(s)
		assert_between(words.size(), 4, 7, s)
		for i: int in range(1, words.size()):
			assert_ne(words[i], words[i - 1], "no word twice in a row: %s" % s)


func test_bad_inputs_give_empty_sentences() -> void:
	var bad: Array = [
		[null, ["dad", "sad"] as Array[String]],
		[_rng(1), ["dad"] as Array[String]],
		[_rng(1), [] as Array[String]],
		[_rng(1), ["dad", "sad", "dad"] as Array[String]],
		[_rng(1), ["Dad", "sad"] as Array[String]],
		[_rng(1), ["a1", "sad"] as Array[String]],
	]
	for args: Array in bad:
		var pool: Array[String] = args[1]
		var gen: SentenceGenerator = SentenceGenerator.new(args[0], pool, true)
		assert_eq(gen.next_sentence(), "", "empty for %s" % [pool])
		assert_eq(gen.next_sentence(), "", "still empty")
	assert_push_error_count(bad.size(), "one error line per bad generator")
