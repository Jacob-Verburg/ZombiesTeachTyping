extends GutTest
## Master word list source (Story 7.3, FR65, FR66): tools/word_lists/master_words.txt passes the
## WordTagger rules, is the right size and shape, holds every starter word and every Dolch sight
## word (apart from the recorded exclusions), holds none of the obviously unsafe words, and has
## enough words for each tier pool Story 7.4 builds from it. Smuck's review is the real gate.

const MASTER_PATH: String = "res://tools/word_lists/master_words.txt"
const STARTER_PATH: String = "res://tools/word_lists/starter_words.txt"
const DOLCH_PATH: String = "res://tools/word_lists/dolch_words.txt"
## Story 7.3 AC 1: about 1,500 words, 1,400-1,600 accepted.
const MIN_WORDS: int = 1400
const MAX_WORDS: int = 1600
## Per-length floors (length -> minimum) so a lopsided list fails; the tier bands each need real choice.
const LENGTH_FLOORS: Dictionary = { 2: 15, 3: 150, 4: 250, 5: 250, 6: 200, 7: 120, 8: 70 }
## Dolch words deliberately left out of the master list, each with its reason.
const DOLCH_EXCLUSIONS: Array[String] = [
	"hurt",  # violence: on the Story 6.1 ban list
]
## Backstop only (exact matches): the Story 6.1 / 7.3 exclusion examples. The human review is the gate.
const BANNED: Array[String] = [
	"dead", "kill", "die", "bone", "grave", "skull", "blood", "bite", "ghost", "monster", "scary", "evil",
	"gun", "hit", "punch", "fight", "war", "sword", "knife", "bomb", "shoot", "hurt",
	"butt", "poop", "fart", "dumb", "stupid", "ugly", "fat", "hate", "shut", "sex", "pee", "bum",
	"beer", "wine", "drunk", "drug",
	"lego", "oreo", "nike",
	"ass", "cock", "dick", "hell", "damn", "crap", "piss", "slut", "gay", "bang", "choke", "strike",
	"gore", "rot", "flesh", "zombie",
	"fag", "hag", "hash", "lash", "slag", "shag", "nuts", "pot", "weed", "high", "kick", "cracker", "flask",
]
## The GDD row table, written out again here on purpose (independent of WordTagger's constants).
const HOME: String = "asdfghjkl"
const TOP: String = "qwertyuiop"
const BOTTOM: String = "zxcvbnm"
## FR62 / FR66 / Story 7.4: every tier pool except tier 1 needs at least this many words.
const TIER_MIN: int = 100
## Tier 1 (home row only): only 21 kid-safe home-row words have 2-3 letters, so Smuck widened tier 1's
## band to 2-4 at the Story 7.3 review gate (2026-10-08; see the Word List Review in that story file).
## That gives exactly 40: removing any home-row word from the master list fails this test on purpose.
const TIER1_MIN_LEN: int = 2
const TIER1_MAX_LEN: int = 4
const TIER1_MIN: int = 40

var _lines: PackedStringArray = PackedStringArray()
var _words: Array[String] = []
var _rejected: Array = []


func before_each() -> void:
	var text: String = FileAccess.get_file_as_string(MASTER_PATH)
	_lines = text.split("\n")
	var result: Dictionary = WordTagger.tag_lines(_lines)
	_rejected = result["rejected"]
	_words.clear()
	for entry: Dictionary in result["words"]:
		_words.append(entry["word"])
	assert_gt(_words.size(), 0, "master_words.txt loaded with at least one word")


func _word_list(path: String) -> Array[String]:
	var text: String = FileAccess.get_file_as_string(path)
	var out: Array[String] = []
	for entry: Dictionary in WordTagger.tag_lines(text.split("\n"))["words"]:
		out.append(entry["word"])
	return out


func _count_fitting(letters: String, min_len: int, max_len: int) -> int:
	var count: int = 0
	for w: String in _words:
		if w.length() < min_len or w.length() > max_len:
			continue
		var fits: bool = true
		for c: String in w:
			if not letters.contains(c):
				fits = false
				break
		if fits:
			count += 1
	return count


func test_size_in_range() -> void:
	assert_between(_words.size(), MIN_WORDS, MAX_WORDS)


## WordTagger rejects uppercase, non-letters, lengths outside 2-8 and repeats.
func test_no_rejected_lines_so_no_duplicates_or_bad_words() -> void:
	assert_eq(_rejected.size(), 0, "rejected lines: %s" % [_rejected])


func test_lf_endings() -> void:
	assert_false(FileAccess.get_file_as_string(MASTER_PATH).contains("\r"), "LF line endings only")


## Each "# N letters" group holds only N-letter words, sorted; groups run 2 to 8 in order.
func test_grouped_by_length_and_sorted() -> void:
	var groups: Array[int] = []
	var group_words: Dictionary = {}
	var current: int = 0
	for raw: String in _lines:
		var text: String = raw.strip_edges()
		if text.begins_with("# ") and text.ends_with(" letters"):
			current = int(text.trim_prefix("# ").trim_suffix(" letters"))
			groups.append(current)
			group_words[current] = [] as Array[String]
			continue
		if text == "" or text.begins_with("#"):
			continue
		assert_ne(current, 0, "'%s' comes before the first length group" % text)
		if current == 0:
			continue
		assert_eq(text.length(), current, "'%s' is in the %d letters group" % [text, current])
		(group_words[current] as Array[String]).append(text)
	assert_eq(groups, [2, 3, 4, 5, 6, 7, 8] as Array[int], "length groups in order")
	for length: int in group_words:
		var listed: Array[String] = group_words[length]
		var sorted: Array[String] = listed.duplicate()
		sorted.sort()
		assert_eq(listed, sorted, "%d letters group sorted" % length)


func test_each_length_has_enough_words() -> void:
	var per_length: Dictionary = {}
	for w: String in _words:
		per_length[w.length()] = int(per_length.get(w.length(), 0)) + 1
	for length: int in LENGTH_FLOORS:
		assert_gte(int(per_length.get(length, 0)), int(LENGTH_FLOORS[length]), "%d-letter words" % length)


func test_holds_every_starter_word() -> void:
	var starter: Array[String] = _word_list(STARTER_PATH)
	assert_gt(starter.size(), 200, "starter list loaded")
	for w: String in starter:
		assert_has(_words, w, "starter word '%s'" % w)


func test_dolch_reference_parses_cleanly() -> void:
	var text: String = FileAccess.get_file_as_string(DOLCH_PATH)
	var result: Dictionary = WordTagger.tag_lines(text.split("\n"))
	assert_eq((result["rejected"] as Array).size(), 0, "dolch_words.txt has no rejected lines")
	assert_eq((result["words"] as Array).size(), 310, "310 Dolch words (217 service + 93 nouns; the header lists the 5 left out)")


func test_holds_every_dolch_word_except_the_recorded_exclusions() -> void:
	var dolch: Array[String] = _word_list(DOLCH_PATH)
	assert_gt(dolch.size(), 0, "Dolch list loaded")
	for w: String in dolch:
		if DOLCH_EXCLUSIONS.has(w):
			continue
		assert_has(_words, w, "Dolch word '%s'" % w)
	# The exclusions must stay real: each is a Dolch word and is really left out.
	for w: String in DOLCH_EXCLUSIONS:
		assert_has(dolch, w, "exclusion '%s' is a Dolch word" % w)
		assert_does_not_have(_words, w, "excluded Dolch word '%s'" % w)


func test_no_banned_words() -> void:
	for banned: String in BANNED:
		assert_does_not_have(_words, banned)


func test_tier_pools_have_enough_words() -> void:
	assert_eq((HOME + TOP + BOTTOM).length(), 26, "the three rows hold 26 letters")
	assert_gte(_count_fitting(HOME, TIER1_MIN_LEN, TIER1_MAX_LEN), TIER1_MIN, "tier 1: home row, %d-%d letters" % [TIER1_MIN_LEN, TIER1_MAX_LEN])
	assert_gte(_count_fitting(HOME + TOP, 3, 4), TIER_MIN, "tier 2: home + top, 3-4 letters")
	assert_gte(_count_fitting(HOME + TOP + BOTTOM, 3, 5), TIER_MIN, "tier 3: all rows, 3-5 letters")
	assert_gte(_count_fitting(HOME + TOP + BOTTOM, 4, 6), TIER_MIN, "tier 4: all rows, 4-6 letters")
	assert_gte(_count_fitting(HOME + TOP + BOTTOM, 5, 8), TIER_MIN, "tier 5: all rows, 5-8 letters")
