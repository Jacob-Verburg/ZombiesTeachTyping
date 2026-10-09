extends GutTest
## ParagraphSource (Story 8.2, FR67 / FR68 / FR69): the join Space, no repeats per cycle, the cycle
## boundary, marking on current (never on peek), the used-list prune, seed determinism, generated mode,
## a generator golden passage, for_level for tiers 0-6 and the tolerant loader. The logic tests use small
## hand-made passage lists; the shipped files get one integration check per mode.

const PARAGRAPHS_PATH: String = "res://data/content/paragraphs.json"
const POOLS_PATH: String = "res://data/content/word_pools.json"
const CONFIG_PATH: String = "res://data/tier_config.tres"
## Golden first passage for seed 8201 over the shipped tier 1 pool (closes the 8.1 "golden output"
## defer). Update it ONLY on a deliberate SentenceGenerator, WordSource or word_pools.json change.
const GOLDEN_SEED: int = 8201
const GOLDEN_TIER1: String = "Lag alas gas had asks adds all. Dads ash half glad lass lags has. Gag dad ha ah gala gals gags."
## A valid tier 3 text (ParagraphRules: 150-400 characters, 2-4 sentences).
const VALID_T3: String = "The zombie woke up with a big smile on his face. He put on his party hat and his pink socks. Today was the day of the dance, and he did not want to be late!"


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## n hand-made passages "t<tier>_01".. with short texts (the source itself never validates).
func _passages(tier: int, n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({"id": "t%d_%02d" % [tier, i + 1], "text": "Passage %d of tier %d." % [i + 1, tier]})
	return out


func _ids_of(passages: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for passage: Dictionary in passages:
		ids.append(str(passage["id"]))
	return ids


## The ids of the next `n` current passages, advancing after each.
func _deal_ids(source: ParagraphSource, n: int) -> Array[String]:
	var ids: Array[String] = []
	for i: int in n:
		ids.append(source.get_current_id())
		source.advance()
	return ids


func _json(data: Variant) -> JSON:
	var json: JSON = JSON.new()
	json.data = data
	return json


## No error line names a tier number or a validator problem (FR60).
func _assert_errors_hide_tiers() -> void:
	var tier_word: RegEx = RegEx.create_from_string("(?i)tier[ _]?\\d|t\\d_\\d")
	for error: Variant in get_errors():
		var text: String = str(error.code) + " " + str(error.rationale)
		assert_null(tier_word.search(text), "no tier number in: %s" % text)
		assert_false(text.contains("not allowed") or text.contains("outside"), "no validator message in: %s" % text)


func _config() -> LevelConfig:
	var config: LevelConfig = LevelConfig.new()
	config.target_mode = LevelConfig.TargetMode.PARAGRAPH
	config.case_sensitive = true
	config.space_is_input = true
	config.paragraphs = load(PARAGRAPHS_PATH) as JSON
	config.tier_word_pools = load(POOLS_PATH) as JSON
	return config


func _tier1_pool() -> Array[String]:
	var config: TierConfig = load(CONFIG_PATH) as TierConfig
	var band: Vector2i = config.word_band_of(1)
	return WordSource.tier_pool_from_json(load(POOLS_PATH) as JSON, 1, band.x, band.y)


func test_current_ends_with_one_join_space_and_peek_never_consumes() -> void:
	var source: ParagraphSource = ParagraphSource.new(_rng(1), _passages(3, 4), [] as Array[String])
	var first: String = source.current()
	assert_true(first.ends_with(ParagraphSource.JOIN), "ends with the join Space")
	assert_false(first.ends_with("  "), "exactly one Space")
	var peeked: Array[String] = source.peek(3)
	assert_eq(peeked.size(), 3)
	assert_eq(source.peek(3), peeked, "peek twice, same targets")
	assert_eq(source.current(), first, "peek did not consume")
	for target: String in peeked:
		assert_true(target.ends_with(ParagraphSource.JOIN) and not target.ends_with("  "))
	source.advance()
	assert_eq(source.current(), peeked[0], "advance makes the first peeked target current")
	assert_eq(source.peek(0), [] as Array[String])


func test_every_passage_once_per_cycle_over_three_cycles() -> void:
	var passages: Array[Dictionary] = _passages(3, 4)
	var expected: Array[String] = _ids_of(passages)
	for seed_value: int in [1, 2, 3, 4, 5]:
		var source: ParagraphSource = ParagraphSource.new(_rng(seed_value), passages, [] as Array[String])
		var dealt: Array[String] = _deal_ids(source, 12)
		for cycle: int in 3:
			var group: Array[String] = dealt.slice(cycle * 4, cycle * 4 + 4)
			group.sort()
			assert_eq(group, expected, "seed %d cycle %d uses every passage once" % [seed_value, cycle])


func test_cycle_boundary_never_repeats_the_last_passage() -> void:
	for seed_value: int in 40:
		var source: ParagraphSource = ParagraphSource.new(_rng(seed_value), _passages(3, 3), [] as Array[String])
		var dealt: Array[String] = _deal_ids(source, 30)
		for i: int in range(1, dealt.size()):
			assert_ne(dealt[i], dealt[i - 1], "seed %d: no passage twice in a row at %d" % [seed_value, i])


## Review patch: a peek that reaches the next cycle must not drop the passage being typed from the used list.
func test_cycle_peek_keeps_the_current_passage_used() -> void:
	var used: Array[String] = ["t3_01", "t3_02"]
	var source: ParagraphSource = ParagraphSource.new(_rng(5), _passages(3, 3), used)
	assert_eq(source.get_current_id(), "t3_03", "the only unused passage is dealt")
	source.peek(2)
	assert_eq(source.get_used_ids().size(), 3, "a peek resets nothing: %s" % [source.get_used_ids()])
	assert_true(source.get_used_ids().has("t3_03"))
	var next: String = source.peek(1)[0]
	assert_ne(next, source.current(), "the next passage is not the current one")
	source.advance()
	assert_eq(source.get_used_ids(), [source.get_current_id()] as Array[String], "the reset happens when the new cycle starts")


## Review patch: a 2-passage list never queues the passage on screen as its own next passage.
func test_two_passage_list_never_queues_the_current_one() -> void:
	for seed_value: int in 20:
		var source: ParagraphSource = ParagraphSource.new(_rng(seed_value), _passages(3, 2), [] as Array[String])
		var dealt: Array[String] = _deal_ids(source, 10)
		for i: int in range(1, dealt.size()):
			assert_ne(dealt[i], dealt[i - 1], "seed %d at %d" % [seed_value, i])


## Review patch: a generated (tier 1-2) run hands the saved authored history back untouched.
func test_generated_mode_round_trips_the_used_list() -> void:
	var pool: Array[String] = ["dad", "sad", "lad", "gas", "has", "lag"] as Array[String]
	var used: Array[String] = ["t3_01", "t4_02", "gone_99"]
	var all_ids: Array[String] = ["t3_01", "t4_02", "t3_02"]
	var source: ParagraphSource = ParagraphSource.generated(_rng(1), SentenceGenerator.for_tier(_rng(1), pool, 1), used, all_ids)
	assert_ne(source.current(), "")
	assert_eq(source.get_used_ids(), ["t3_01", "t4_02"] as Array[String], "history kept, retired id pruned")
	source.advance()
	assert_eq(source.get_used_ids(), ["t3_01", "t4_02"] as Array[String], "advancing a generated source changes nothing")


## Review patch: an id with a trailing newline, or a fractional tier, is not a valid passage.
func test_id_with_newline_and_fractional_tier_are_skipped() -> void:
	var json: JSON = JSON.new()
	json.data = {"passages": [
		{"id": "t3_01
", "tier": 3, "text": VALID_T3},
		{"id": "t3_02", "tier": 3.5, "text": VALID_T3},
		{"id": "t3_03", "tier": 3, "text": VALID_T3}]}
	var out: Array[Dictionary] = ParagraphSource.passages_from_json(json, 3)
	assert_eq(_ids_of(out), ["t3_03"] as Array[String])
	assert_push_error_count(1)


func test_cycle_reset_keeps_other_tiers_ids() -> void:
	var used: Array[String] = ["t4_01", "t5_02"]
	var source: ParagraphSource = ParagraphSource.new(_rng(7), _passages(3, 4), used)
	_deal_ids(source, 9)
	var after: Array[String] = source.get_used_ids()
	assert_true(after.has("t4_01") and after.has("t5_02"), "other tiers survive the reset: %s" % [after])
	assert_eq(used, ["t4_01", "t5_02"] as Array[String], "the caller's list is copied, not changed")


func test_used_marked_on_current_not_on_peek() -> void:
	var source: ParagraphSource = ParagraphSource.new(_rng(3), _passages(3, 4), [] as Array[String])
	assert_eq(source.get_used_ids(), [source.get_current_id()] as Array[String], "the first passage is used at once")
	source.peek(3)
	assert_eq(source.get_used_ids().size(), 1, "peeking marks nothing")
	var before: String = source.get_current_id()
	source.advance()
	assert_eq(source.get_used_ids(), [before, source.get_current_id()] as Array[String], "marked in order")


func test_partly_used_list_deals_unused_first_and_prunes_retired_ids() -> void:
	var passages: Array[Dictionary] = _passages(3, 4)
	var used: Array[String] = ["t3_99", "t3_01", "t3_02"]
	var source: ParagraphSource = ParagraphSource.new(_rng(5), passages, used, _ids_of(passages))
	var first_two: Array[String] = _deal_ids(source, 2)
	first_two.sort()
	assert_eq(first_two, ["t3_03", "t3_04"] as Array[String], "the unused passages come first")
	assert_false(source.get_used_ids().has("t3_99"), "a retired id is pruned")
	var kept: ParagraphSource = ParagraphSource.new(_rng(5), passages, used)
	assert_true(kept.get_used_ids().has("t3_99"), "no all_ids: nothing is pruned")


func test_same_seed_same_passages() -> void:
	var passages: Array[Dictionary] = _passages(3, 8)
	var used: Array[String] = ["t3_02"]
	var a: Array[String] = _deal_ids(ParagraphSource.new(_rng(42), passages, used), 10)
	var b: Array[String] = _deal_ids(ParagraphSource.new(_rng(42), passages, used), 10)
	var c: Array[String] = _deal_ids(ParagraphSource.new(_rng(43), passages, used), 10)
	assert_eq(a, b, "same seed and used list, same passages")
	assert_ne(a, c, "another seed, another order")


func test_bad_inputs_leave_the_source_empty() -> void:
	var no_rng: ParagraphSource = ParagraphSource.new(null, _passages(3, 2), [] as Array[String])
	var no_passages: ParagraphSource = ParagraphSource.new(_rng(1), [] as Array[Dictionary], [] as Array[String])
	var no_generator: ParagraphSource = ParagraphSource.generated(_rng(1), null)
	for source: ParagraphSource in [no_rng, no_passages, no_generator]:
		assert_eq(source.current(), "")
		assert_eq(source.peek(2), [] as Array[String])
		source.advance()
		assert_eq(source.current(), "", "still empty")
	assert_push_error_count(3, "one error line per bad source")


func test_generated_mode() -> void:
	var pool: Array[String] = _tier1_pool()
	assert_gt(pool.size(), 1, "the tier 1 pool loads")
	var rng: RandomNumberGenerator = _rng(9)
	var source: ParagraphSource = ParagraphSource.generated(rng, SentenceGenerator.for_tier(rng, pool, 1))
	for i: int in 30:
		var target: String = source.current()
		assert_true(target.ends_with(ParagraphSource.JOIN))
		var text: String = target.trim_suffix(ParagraphSource.JOIN)
		assert_eq(ParagraphRules.sentence_count(text), ParagraphSource.GENERATED_SENTENCES, text)
		for word: String in text.split(" "):
			var bare: String = word.trim_suffix(".").trim_suffix(",").to_lower()
			assert_true(pool.has(bare), "'%s' is in the pool" % bare)
		assert_eq(source.get_current_id(), "", "generated text has no id")
		source.advance()
	assert_eq(source.get_used_ids(), [] as Array[String], "generated text is never tracked")


func test_generated_golden_passage() -> void:
	var pool: Array[String] = _tier1_pool()
	var rng: RandomNumberGenerator = _rng(GOLDEN_SEED)
	var source: ParagraphSource = ParagraphSource.generated(rng, SentenceGenerator.for_tier(rng, pool, 1))
	assert_eq(source.current(), GOLDEN_TIER1 + ParagraphSource.JOIN, "seed %d tier 1 golden passage" % GOLDEN_SEED)


func test_for_level_by_tier() -> void:
	var config: LevelConfig = _config()
	var tier_config: TierConfig = load(CONFIG_PATH) as TierConfig
	assert_not_null(config.paragraphs, "paragraphs.json loads")
	var none: Array[String] = []
	for tier: int in [0, 1, 2, 3, 4, 5, 6]:
		var source: ParagraphSource = ParagraphSource.for_level(_rng(10 + tier), config, tier, tier_config, none)
		assert_not_null(source, "tier %d gives a source" % tier)
		if source == null:
			continue
		assert_ne(source.current(), "", "tier %d deals text" % tier)
		match tier:
			1, 2:
				assert_eq(source.get_pool_label(), "tier_%d" % tier)
				assert_eq(source.get_current_id(), "", "tier %d is generated" % tier)
			3, 4, 5:
				assert_eq(source.get_pool_label(), "tier_%d" % tier)
				assert_true(source.get_current_id().begins_with("t%d_" % tier), "tier %d authored" % tier)
			_:
				assert_eq(source.get_pool_label(), GameConstants.LETTER_POOL_ALL, "tier %d falls back" % tier)
				assert_true(source.get_current_id().begins_with("t3_"), "tier %d uses tier 3 text" % tier)
	assert_push_error_count(1, "only tier 6 (no text for it) logs")
	_assert_errors_hide_tiers()


func test_for_level_without_a_tier_config_falls_back() -> void:
	var source: ParagraphSource = ParagraphSource.for_level(_rng(1), _config(), 1, null, [] as Array[String])
	assert_eq(source.get_pool_label(), GameConstants.LETTER_POOL_ALL)
	assert_true(source.get_current_id().begins_with("t3_"))
	assert_push_error_count(1)
	_assert_errors_hide_tiers()


func test_for_level_passes_the_used_list() -> void:
	var source: ParagraphSource = ParagraphSource.for_level(
			_rng(1), _config(), 3, load(CONFIG_PATH) as TierConfig, ["t3_01", "t4_02", "t9_99"] as Array[String])
	var used: Array[String] = source.get_used_ids()
	assert_true(used.has("t3_01") and used.has("t4_02"), "shipped ids are kept: %s" % [used])
	assert_false(used.has("t9_99"), "an id not in the file is pruned")
	assert_ne(source.get_current_id(), "t3_01", "a used passage is not dealt first")


func test_missing_paragraphs_gives_null() -> void:
	var config: LevelConfig = _config()
	config.paragraphs = null
	assert_null(ParagraphSource.for_level(_rng(1), config, 0, null, [] as Array[String]))
	assert_null(ParagraphSource.for_level(_rng(1), null, 3, null, [] as Array[String]))
	assert_push_error_count(3, "no paragraphs + no fallback, then no config")


func test_passages_from_json_drops_bad_entries() -> void:
	var data: Dictionary = {"schema": 1, "passages": [
		{"id": "t3_01", "tier": 3, "text": VALID_T3},
		{"id": "t3_02", "tier": 3, "text": "Too short."},
		{"id": "t4_03", "tier": 3, "text": VALID_T3 + " Yes."},
		{"id": "t3_01", "tier": 3, "text": VALID_T3 + " No."},
		{"id": "t4_01", "tier": 4.0, "text": "Another tier: ignored here."},
	]}
	var passages: Array[Dictionary] = ParagraphSource.passages_from_json(_json(data), 3)
	assert_eq(passages, [{"id": "t3_01", "text": VALID_T3}] as Array[Dictionary])
	assert_push_error_count(1, "one error line for the bad passages")
	_assert_errors_hide_tiers()


func test_passages_from_json_tolerates_junk() -> void:
	for junk: JSON in [null, _json([1, 2]), _json({"passages": "no"}), _json({})]:
		assert_eq(ParagraphSource.passages_from_json(junk, 3), [] as Array[Dictionary])
	assert_push_error_count(4, "one error line per junk document")


func test_shipped_passages_load_for_every_authored_tier() -> void:
	var json: JSON = load(PARAGRAPHS_PATH) as JSON
	for tier: int in ParagraphRules.AUTHORED_TIERS:
		var passages: Array[Dictionary] = ParagraphSource.passages_from_json(json, tier)
		assert_eq(passages.size(), 13, "tier %d: 13 shipped passages" % tier)
	assert_push_error_count(0, "the shipped file has no bad passage")
