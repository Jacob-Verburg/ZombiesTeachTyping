extends GutTest
## Shipped word list (Story 6.1, FR59, FR66): data/content/words.json loads as a JSON resource, has
## enough words in the 3-5 letter band, matches a fresh WordTagger run on the source list (so a stale
## words.json fails CI) and holds none of the obviously unsafe words. Smuck's review is the real gate.

const WORDS_PATH: String = "res://data/content/words.json"
const SOURCE_PATH: String = "res://tools/word_lists/starter_words.txt"
## FR59 / Story 6.1 AC 3.
const MIN_WORDS: int = 200
## Independent golden entries (word -> rows), not derived from WordTagger.
const GOLDEN: Dictionary = {
	"dad": ["home"],
	"quiz": ["top", "bottom"],
	"cat": ["home", "top", "bottom"],
	"the": ["home", "top"],
}
## Backstop only: the Story 6.1 exclusion examples (scary, violent, rude, branded).
const BANNED: Array[String] = [
	"dead", "kill", "die", "bone", "grave", "skull", "blood", "bite", "ghost", "monster",
	"gun", "hit", "punch", "fight", "war", "sword",
	"butt", "poop", "fart", "dumb", "stupid", "ugly", "fat", "hate", "shut",
	"lego", "oreo",
]

var _doc: Dictionary = {}
var _words: Array = []


func before_each() -> void:
	var res: JSON = load(WORDS_PATH) as JSON
	_doc = res.data if res != null and res.data is Dictionary else {}
	_words = _doc.get("words", [])
	assert_gt(_words.size(), 0, "words.json loaded with at least one word")


func _word_strings() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _words:
		out.append(entry["word"])
	return out


func test_loads_as_json_resource_with_schema_1() -> void:
	assert_not_null(load(WORDS_PATH) as JSON, "words.json loads as a JSON resource")
	assert_eq(int(_doc.get("schema", 0)), 1)


func test_enough_words_and_enough_in_the_starter_band() -> void:
	assert_gte(_words.size(), MIN_WORDS)
	assert_gte(WordTagger.count_in_band(_words, WordTagger.STARTER_BAND_MIN_LEN, WordTagger.STARTER_BAND_MAX_LEN), WordTagger.STARTER_BAND_MIN_COUNT)


func test_no_duplicates_and_sorted() -> void:
	var words: Array[String] = _word_strings()
	var seen: Dictionary = {}
	for w: String in words:
		assert_false(seen.has(w), "duplicate '%s'" % w)
		seen[w] = true
	var sorted: Array[String] = words.duplicate()
	sorted.sort()
	assert_eq(words, sorted)


## JSON numbers load as float, so length is compared with int().
func test_every_entry_matches_a_fresh_tag() -> void:
	for entry: Dictionary in _words:
		var w: String = entry["word"]
		assert_eq(WordTagger.rejection_reason(w), "", w)
		var rows: Array[String] = []
		rows.assign(entry["rows"])
		assert_eq(rows, WordTagger.rows_for(w), "rows for '%s'" % w)
		assert_eq(int(entry["length"]), w.length(), "length for '%s'" % w)


func test_golden_entries_match_the_gdd_row_table() -> void:
	var by_word: Dictionary = {}
	for entry: Dictionary in _words:
		by_word[entry["word"]] = entry
	for w: String in GOLDEN:
		assert_true(by_word.has(w), "'%s' is in the list" % w)
		if not by_word.has(w):
			continue
		var rows: Array[String] = []
		rows.assign(by_word[w]["rows"])
		var expected: Array[String] = []
		expected.assign(GOLDEN[w])
		assert_eq(rows, expected, "rows for '%s'" % w)


func test_matches_the_tagged_source_list() -> void:
	var text: String = FileAccess.get_file_as_string(SOURCE_PATH)
	assert_ne(text, "", "the source list exists")
	var result: Dictionary = WordTagger.tag_lines(text.split("\n"))
	assert_eq((result["rejected"] as Array).size(), 0, "no rejected lines in the source list")
	var fresh: Array[String] = []
	for entry: Dictionary in result["words"]:
		fresh.append(entry["word"])
	assert_eq(_word_strings(), fresh, "words.json is up to date (re-run tools/tag_words.gd)")


func test_no_banned_words() -> void:
	var words: Array[String] = _word_strings()
	for banned: String in BANNED:
		assert_does_not_have(words, banned)
