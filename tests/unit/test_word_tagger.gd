extends GutTest
## WordTagger (Story 6.1, FR66): row and length tagging against an independent copy of the GDD row
## table, the rejection rules (uppercase, non-letter, 2-8 letters, duplicates) and the output order.

## The GDD row table, written out again here on purpose (independent of WordTagger's constants).
const HOME: String = "asdfghjkl"
const TOP: String = "qwertyuiop"
const BOTTOM: String = "zxcvbnm"


func _rows(names: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(names)
	return out


func test_dad_is_home_row_length_3() -> void:
	assert_eq(WordTagger.rows_for("dad"), _rows(["home"]))
	var result: Dictionary = WordTagger.tag_lines(PackedStringArray(["dad"]))
	var words: Array = result["words"]
	assert_eq(words.size(), 1)
	assert_eq(words[0]["word"], "dad")
	assert_eq(words[0]["rows"], _rows(["home"]))
	assert_eq(words[0]["length"], 3)


## The epic text says top+bottom+home; q u i are top keys and z is bottom, so no home row (GDD wins).
func test_quiz_is_top_and_bottom_length_4() -> void:
	assert_eq(WordTagger.rows_for("quiz"), _rows(["top", "bottom"]))
	var words: Array = WordTagger.tag_lines(PackedStringArray(["quiz"]))["words"]
	assert_eq(words[0]["length"], 4)


func test_worked_examples() -> void:
	assert_eq(WordTagger.rows_for("the"), _rows(["home", "top"]))
	assert_eq(WordTagger.rows_for("cab"), _rows(["home", "bottom"]))
	assert_eq(WordTagger.rows_for("zoo"), _rows(["top", "bottom"]))
	assert_eq(WordTagger.rows_for("quick"), _rows(["home", "top", "bottom"]))
	assert_eq(WordTagger.rows_for("flag"), _rows(["home"]))


func test_rows_are_in_canonical_order_regardless_of_letter_order() -> void:
	assert_eq(WordTagger.rows_for("mud"), _rows(["home", "top", "bottom"]))
	assert_eq(WordTagger.rows_for("bus"), _rows(["home", "top", "bottom"]))
	assert_eq(WordTagger.rows_for("zap"), _rows(["home", "top", "bottom"]))
	assert_eq(WordTagger.rows_for("bee"), _rows(["top", "bottom"]))


func test_rows_for_matches_the_independent_table_for_every_letter() -> void:
	for code: int in range(97, 123):
		var c: String = String.chr(code)
		var expected: String = "home" if HOME.contains(c) else ("top" if TOP.contains(c) else "bottom")
		assert_eq(WordTagger.rows_for(c), _rows([expected]), "row for '%s'" % c)


func test_row_strings_cover_a_to_z_exactly_once() -> void:
	var all_keys: String = WordTagger.ROW_HOME + WordTagger.ROW_TOP + WordTagger.ROW_BOTTOM
	assert_eq(all_keys.length(), 26)
	for code: int in range(97, 123):
		assert_eq(all_keys.count(String.chr(code)), 1, "'%s' once" % String.chr(code))
	assert_eq(WordTagger.ROW_HOME, HOME)
	assert_eq(WordTagger.ROW_TOP, TOP)
	assert_eq(WordTagger.ROW_BOTTOM, BOTTOM)


func test_rejection_reasons() -> void:
	assert_eq(WordTagger.rejection_reason("dog"), "")
	assert_eq(WordTagger.rejection_reason("Dad"), "uppercase")
	assert_eq(WordTagger.rejection_reason("DOG1"), "uppercase", "uppercase is checked first")
	for bad: String in ["it's", "ice-cream", "café", "ab1", "ice cream"]:
		assert_eq(WordTagger.rejection_reason(bad), "non-letter", bad)
	assert_eq(WordTagger.rejection_reason("a"), "too short")
	assert_eq(WordTagger.rejection_reason("watermelon"), "too long")
	assert_eq(WordTagger.rejection_reason("go"), "", "2 letters is the minimum")
	assert_eq(WordTagger.rejection_reason("elephant"), "", "8 letters is the maximum")


func test_tag_lines_rejects_with_line_numbers_and_skips_blanks_and_comments() -> void:
	var lines: PackedStringArray = PackedStringArray([
		"# starter words", "dog", "", "Dad", "it's", "   ", "a", "watermelon", "dog", "café", "ab1", "ice-cream",
	])
	var result: Dictionary = WordTagger.tag_lines(lines)
	var words: Array = result["words"]
	var rejected: Array = result["rejected"]
	assert_eq(words.size(), 1)
	assert_eq(words[0]["word"], "dog")
	var expected: Array = [
		{ "line": 4, "text": "Dad", "reason": "uppercase" },
		{ "line": 5, "text": "it's", "reason": "non-letter" },
		{ "line": 7, "text": "a", "reason": "too short" },
		{ "line": 8, "text": "watermelon", "reason": "too long" },
		{ "line": 9, "text": "dog", "reason": "duplicate of line 2" },
		{ "line": 10, "text": "café", "reason": "non-letter" },
		{ "line": 11, "text": "ab1", "reason": "non-letter" },
		{ "line": 12, "text": "ice-cream", "reason": "non-letter" },
	]
	assert_eq(rejected, expected)


func test_whitespace_and_carriage_returns_are_stripped() -> void:
	var result: Dictionary = WordTagger.tag_lines(PackedStringArray(["  dog \r", "cat\r"]))
	var words: Array = result["words"]
	assert_eq((result["rejected"] as Array).size(), 0)
	assert_eq(words.size(), 2)
	assert_eq(words[0]["word"], "cat")
	assert_eq(words[1]["word"], "dog")


func test_bom_and_crlf_are_stripped_without_merging_words() -> void:
	var result: Dictionary = WordTagger.tag_lines(PackedStringArray(["\ufeff# header\r", "dad\r", "ice\rcream"]))
	assert_eq((result["words"] as Array).size(), 1)
	assert_eq((result["rejected"] as Array).size(), 1)
	assert_eq(result["rejected"][0]["text"], "ice\rcream")


func test_output_is_sorted_alphabetically() -> void:
	var words: Array = WordTagger.tag_lines(PackedStringArray(["zoo", "apple", "mud", "bee"]))["words"]
	var order: Array[String] = []
	for entry: Dictionary in words:
		order.append(entry["word"])
	assert_eq(order, ["apple", "bee", "mud", "zoo"] as Array[String])


func test_count_in_band() -> void:
	var words: Array = WordTagger.tag_lines(PackedStringArray(["go", "cat", "frog", "apple", "banana"]))["words"]
	assert_eq(WordTagger.count_in_band(words, 3, 5), 3)
	assert_eq(WordTagger.count_in_band(words, 2, 8), 5)
	assert_eq(WordTagger.count_in_band(words, 6, 8), 1)
	assert_eq(WordTagger.count_in_band([], 3, 5), 0)
