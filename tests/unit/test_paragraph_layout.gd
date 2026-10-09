extends GutTest
## ParagraphLayout (Story 8.2, FR69): greedy 12-character wrapping with the trailing Space on its line,
## the hyphen break, the hard-split fallback and line_of; then every shipped passage and 200 generated
## tier 1-2 passages wrap cleanly. The expected line starts are written out by hand.

const PARAGRAPHS_PATH: String = "res://data/content/paragraphs.json"
const POOLS_PATH: String = "res://data/content/word_pools.json"
const CONFIG_PATH: String = "res://data/tier_config.tres"
const GENERATED_PASSAGES: int = 200


func _lines(text: String, starts: PackedInt32Array) -> Array[String]:
	var lines: Array[String] = []
	for i: int in starts.size():
		var end: int = starts[i + 1] if i + 1 < starts.size() else text.length()
		lines.append(text.substr(starts[i], end - starts[i]))
	return lines


func _assert_clean(text: String) -> void:
	var lines: Array[String] = _lines(text, ParagraphLayout.wrap(text))
	assert_eq("".join(lines), text, "the lines join back to the text: %s" % text)
	for line: String in lines:
		assert_between(line.length(), 1, ParagraphLayout.LINE_CHARS, "line length '%s'" % line)
		assert_false(line.begins_with(" "), "no line starts with a Space: '%s'" % line)


func test_line_chars_is_12() -> void:
	assert_eq(ParagraphLayout.LINE_CHARS, 12)


func test_hand_made_text() -> void:
	var text: String = "The dog ran up the big hill. "
	assert_eq(ParagraphLayout.wrap(text), PackedInt32Array([0, 12, 23]))
	assert_eq(_lines(text, ParagraphLayout.wrap(text)), ["The dog ran ", "up the big ", "hill. "] as Array[String])


func test_trailing_space_counts_toward_the_line() -> void:
	# "aaaaa bbbbbb" is 12 characters, but with its Space "bbbbbb " no longer fits after "aaaaa ".
	var text: String = "aaaaa bbbbbb cc "
	assert_eq(_lines(text, ParagraphLayout.wrap(text)), ["aaaaa ", "bbbbbb cc "] as Array[String])


func test_brain_shaped_breaks_after_the_hyphen() -> void:
	assert_eq(ParagraphLayout.wrap("brain-shaped "), PackedInt32Array([0, 6]))
	var text: String = "a brain-shaped cookie "
	assert_eq(_lines(text, ParagraphLayout.wrap(text)), ["a brain-", "shaped ", "cookie "] as Array[String])


func test_long_word_without_hyphen_hard_splits() -> void:
	assert_eq(ParagraphLayout.wrap("abcdefghijkl "), PackedInt32Array([0, 11]))
	_assert_clean("abcdefghijklmnopqrstuvwxyz0123456789 ok ")
	# A hyphen right before the Space would leave the Space alone on a line: hard-split instead.
	_assert_clean("abcdefghijk- ")


func test_empty_text_is_one_line() -> void:
	assert_eq(ParagraphLayout.wrap(""), PackedInt32Array([0]))


func test_line_of_at_edges() -> void:
	var starts: PackedInt32Array = PackedInt32Array([0, 12, 23])
	assert_eq(ParagraphLayout.line_of(starts, 0), 0)
	assert_eq(ParagraphLayout.line_of(starts, 11), 0)
	assert_eq(ParagraphLayout.line_of(starts, 12), 1)
	assert_eq(ParagraphLayout.line_of(starts, 22), 1)
	assert_eq(ParagraphLayout.line_of(starts, 23), 2)
	assert_eq(ParagraphLayout.line_of(starts, 999), 2, "past the end clamps to the last line")
	assert_eq(ParagraphLayout.line_of(starts, -3), 0, "before the start clamps to line 0")
	assert_eq(ParagraphLayout.line_of(PackedInt32Array([0]), 5), 0)


func test_every_shipped_passage_wraps_cleanly() -> void:
	var json: JSON = load(PARAGRAPHS_PATH) as JSON
	assert_not_null(json, "paragraphs.json loads")
	if json == null:
		return
	var passages: Array = (json.data as Dictionary).get("passages", [])
	assert_gt(passages.size(), 0, "paragraphs.json has passages")
	for entry: Variant in passages:
		_assert_clean(str((entry as Dictionary)["text"]) + ParagraphSource.JOIN)


func test_generated_passages_wrap_cleanly() -> void:
	var json: JSON = load(POOLS_PATH) as JSON
	var config: TierConfig = load(CONFIG_PATH) as TierConfig
	assert_not_null(json, "word_pools.json loads")
	assert_not_null(config, "tier_config.tres loads")
	if json == null or config == null:
		return
	for tier: int in [1, 2]:
		var band: Vector2i = config.word_band_of(tier)
		var pool: Array[String] = WordSource.tier_pool_from_json(json, tier, band.x, band.y)
		assert_gt(pool.size(), 1, "tier %d pool has words" % tier)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 820 + tier
		var source: ParagraphSource = ParagraphSource.generated(rng, SentenceGenerator.for_tier(rng, pool, tier))
		for i: int in GENERATED_PASSAGES:
			var target: String = source.current()
			assert_ne(target, "", "tier %d passage %d" % [tier, i])
			_assert_clean(target)
			source.advance()
