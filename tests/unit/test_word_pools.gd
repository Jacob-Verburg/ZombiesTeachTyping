extends GutTest
## Tier word pools (Story 7.4, FR62, FR66): data/content/word_pools.json and word_pool_report.json load,
## match TierConfig's tiers, meet WordTagger.TIER_POOL_MINIMUMS (the CI gate), agree with an independent
## row oracle in both directions, and match a fresh build from master_words.txt (so a stale file fails CI).

const POOLS_PATH: String = "res://data/content/word_pools.json"
const REPORT_PATH: String = "res://data/content/word_pool_report.json"
const MASTER_PATH: String = "res://tools/word_lists/master_words.txt"
const CONFIG_PATH: String = "res://data/tier_config.tres"
## The GDD row table, written out again here on purpose (independent of WordTagger's constants).
const ROWS: Array[String] = ["asdfghjkl", "qwertyuiop", "zxcvbnm"]
const ROW_NAMES: Array[String] = ["home", "top", "bottom"]
const STALE_POOLS: String = "word_pools.json is out of date (re-run tools/tag_words.gd -- --pools)"
const STALE_REPORT: String = "word_pool_report.json is out of date (re-run tools/tag_words.gd -- --pools)"

var _config: TierConfig = null
var _tiers: Array = []
var _report: Array = []
var _pools_doc: Dictionary = {}
var _report_doc: Dictionary = {}
var _master: Array[String] = []
## False when before_each could not load everything; the tests then stop after its failed asserts.
var _loaded: bool = false


func _load_doc(path: String) -> Dictionary:
	var res: JSON = load(path) as JSON
	return res.data if res != null and res.data is Dictionary else {}


func _strings(values: Variant) -> Array[String]:
	var out: Array[String] = []
	out.assign(values)
	return out


func before_each() -> void:
	_config = load(CONFIG_PATH) as TierConfig
	_pools_doc = _load_doc(POOLS_PATH)
	_report_doc = _load_doc(REPORT_PATH)
	_tiers = _pools_doc.get("tiers", [])
	_report = _report_doc.get("tiers", [])
	_master.clear()
	var text: String = FileAccess.get_file_as_string(MASTER_PATH)
	for entry: Dictionary in WordTagger.tag_lines(text.split("\n"))["words"]:
		_master.append(entry["word"])
	assert_not_null(_config, "tier_config.tres loads as a TierConfig")
	assert_gt(_tiers.size(), 0, "word_pools.json loaded with at least one tier")
	assert_gt(_report.size(), 0, "word_pool_report.json loaded with at least one tier")
	assert_gt(_master.size(), 0, "master_words.txt loaded")
	_loaded = _config != null and _tiers.size() > 0 and _report.size() > 0 and _master.size() > 0


## The oracle's letters for a tier: the first `row_count` rows of the table above.
func _letters(row_count: int) -> String:
	return "".join(ROWS.slice(0, row_count))


func _fits(word: String, letters: String, min_len: int, max_len: int) -> bool:
	if word.length() < min_len or word.length() > max_len:
		return false
	for c: String in word:
		if not letters.contains(c):
			return false
	return true


func test_schema_and_tiers_match_tier_config() -> void:
	if not _loaded:
		return
	assert_eq(int(_pools_doc.get("schema", 0)), 1)
	assert_eq(int(_report_doc.get("schema", 0)), 1)
	assert_eq(_pools_doc.get("source", ""), MASTER_PATH)
	assert_eq(_tiers.size(), _config.tier_count())
	for i: int in _tiers.size():
		var tier: Dictionary = _tiers[i]
		var n: int = i + 1
		assert_eq(int(tier["tier"]), n, "tiers numbered 1..n in order")
		assert_eq(_strings(tier["rows"]), ROW_NAMES.slice(0, _config.row_count_of(n)), "tier %d rows" % n)
		assert_eq(Vector2i(int(tier["min_length"]), int(tier["max_length"])), _config.word_band_of(n), "tier %d band" % n)


## The CI gate: every tier meets its minimum and the report agrees with the pools.
func test_every_tier_meets_its_minimum() -> void:
	if not _loaded:
		return
	assert_eq(_report.size(), _tiers.size(), "one report line per tier")
	for i: int in _tiers.size():
		var count: int = (_tiers[i]["words"] as Array).size()
		assert_true(i < WordTagger.TIER_POOL_MINIMUMS.size(), "tier %d has a minimum" % (i + 1))
		if i < WordTagger.TIER_POOL_MINIMUMS.size():
			assert_gte(count, WordTagger.TIER_POOL_MINIMUMS[i], "tier %d pool size" % (i + 1))
		if i < _report.size():
			var line: Dictionary = _report[i]
			assert_eq(int(line["tier"]), i + 1)
			assert_eq(int(line["count"]), count, "report count for tier %d" % (i + 1))
			assert_true(bool(line["ok"]), "report says tier %d is ok" % (i + 1))


## Pool == oracle filter of the master list, both directions.
func test_pools_match_an_independent_row_oracle() -> void:
	if not _loaded:
		return
	for i: int in _tiers.size():
		var n: int = i + 1
		var letters: String = _letters(_config.row_count_of(n))
		var band: Vector2i = _config.word_band_of(n)
		var pool: Array[String] = _strings(_tiers[i]["words"])
		var in_pool: Dictionary = {}
		for w: String in pool:
			in_pool[w] = true
			assert_true(_fits(w, letters, band.x, band.y), "tier %d: '%s' breaks the tier's rule" % [n, w])
		var missing: Array[String] = []
		for w: String in _master:
			if _fits(w, letters, band.x, band.y) and not in_pool.has(w):
				missing.append(w)
		assert_eq(missing, [] as Array[String], "tier %d is missing master words that fit it" % n)


func test_pools_are_sorted_unique_and_from_the_master_list() -> void:
	if not _loaded:
		return
	var master: Dictionary = {}
	for w: String in _master:
		master[w] = true
	for i: int in _tiers.size():
		var pool: Array[String] = _strings(_tiers[i]["words"])
		var sorted: Array[String] = pool.duplicate()
		sorted.sort()
		assert_eq(pool, sorted, "tier %d sorted" % (i + 1))
		var seen: Dictionary = {}
		for w: String in pool:
			assert_false(seen.has(w), "tier %d duplicate '%s'" % [i + 1, w])
			seen[w] = true
			assert_true(master.has(w), "tier %d word '%s' is a master word" % [i + 1, w])


## Stale guard: the committed files equal a fresh build from master_words.txt + the shipped TierConfig.
func test_matches_a_fresh_build() -> void:
	if not _loaded:
		return
	var text: String = FileAccess.get_file_as_string(MASTER_PATH)
	var tagged: Dictionary = WordTagger.tag_lines(text.split("\n"))
	assert_eq((tagged["rejected"] as Array).size(), 0, "no rejected lines in the master list")
	assert_eq(_report_doc.get("source", ""), MASTER_PATH, STALE_REPORT)
	assert_eq(int(_report_doc.get("schema", 0)), 1, STALE_REPORT)
	var fresh: Array[Dictionary] = WordTagger.build_tier_pools(tagged["words"], _config)
	assert_eq(_tiers.size(), fresh.size(), STALE_POOLS)
	for i: int in mini(_tiers.size(), fresh.size()):
		var tier: Dictionary = _tiers[i]
		assert_eq(_strings(tier["words"]), _strings(fresh[i]["words"]), "tier %d: %s" % [i + 1, STALE_POOLS])
		assert_eq(_strings(tier["rows"]), _strings(fresh[i]["rows"]), "tier %d: %s" % [i + 1, STALE_POOLS])
		assert_eq(int(tier["min_length"]), int(fresh[i]["min_length"]), STALE_POOLS)
		assert_eq(int(tier["max_length"]), int(fresh[i]["max_length"]), STALE_POOLS)
	var fresh_report: Array[Dictionary] = WordTagger.pool_report(fresh, WordTagger.TIER_POOL_MINIMUMS)
	assert_eq(_report.size(), fresh_report.size(), STALE_REPORT)
	for i: int in mini(_report.size(), fresh_report.size()):
		var line: Dictionary = _report[i]
		assert_eq(int(line["count"]), int(fresh_report[i]["count"]), "tier %d: %s" % [i + 1, STALE_REPORT])
		assert_eq(int(line["minimum"]), int(fresh_report[i]["minimum"]), "tier %d: %s" % [i + 1, STALE_REPORT])
		assert_eq(bool(line["ok"]), bool(fresh_report[i]["ok"]), "tier %d: %s" % [i + 1, STALE_REPORT])
