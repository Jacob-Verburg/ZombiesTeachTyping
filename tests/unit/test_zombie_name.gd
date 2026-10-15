extends GutTest
## ZombieName (Story 11.1, FR78): letters and single spaces, 1..ZOMBIE_NAME_MAX_LENGTH characters.

const MAX: int = GameConstants.ZOMBIE_NAME_MAX_LENGTH


func test_max_length_is_twelve() -> void:
	assert_eq(MAX, 12, "FR78 / Story 11.1: names are 1-12 characters")


func test_is_letter_accepts_ascii_letters_in_both_cases() -> void:
	for c: String in ["a", "z", "A", "Z", "m", "Q"]:
		assert_true(ZombieName.is_letter(c), c)


func test_is_letter_rejects_everything_else() -> void:
	for c: String in ["", " ", "0", "7", "!", "'", "-", "_", "@", "[", "`", "{", "é", "ß", "ñ", "Ж", "😀", "ab", "\t", "\n"]:
		assert_false(ZombieName.is_letter(c), "rejects '%s'" % c)


func test_append_adds_letters_keeping_case() -> void:
	var text: String = ""
	for c: String in ["s", "A", "m"]:
		text = ZombieName.append(text, c)
	assert_eq(text, "sAm")


func test_append_never_starts_with_a_space() -> void:
	assert_eq(ZombieName.append("", " "), "")


func test_append_never_adds_two_spaces_in_a_row() -> void:
	assert_eq(ZombieName.append("Sam", " "), "Sam ")
	assert_eq(ZombieName.append("Sam ", " "), "Sam ")
	assert_eq(ZombieName.append("Sam ", "Z"), "Sam Z")


func test_append_ignores_non_letters() -> void:
	for c: String in ["7", "!", "é", "", "ab", "\t", "😀"]:
		assert_eq(ZombieName.append("Sam", c), "Sam", "ignores '%s'" % c)


func test_append_stops_at_the_max_length() -> void:
	var full: String = "W".repeat(MAX)
	assert_eq(ZombieName.append("W".repeat(MAX - 1), "W"), full, "the 12th character fits")
	assert_eq(ZombieName.append(full, "W"), full, "the 13th letter is ignored")
	assert_eq(ZombieName.append(full, " "), full, "so is a 13th space")


func test_backspace() -> void:
	assert_eq(ZombieName.backspace(""), "")
	assert_eq(ZombieName.backspace("S"), "")
	assert_eq(ZombieName.backspace("Sam "), "Sam")
	assert_eq(ZombieName.backspace("Sam"), "Sa")


func test_clean_collapses_and_strips_spaces() -> void:
	assert_eq(ZombieName.clean("  sam   the  zombie "), "sam the zomb", "collapsed then cut to 12")
	assert_eq(ZombieName.clean("  Sam  Z "), "Sam Z")


func test_clean_drops_a_space_the_cut_leaves_at_the_end() -> void:
	assert_eq(ZombieName.clean("abcdefghijk lmno"), "abcdefghijk")


func test_clean_keeps_only_letters_and_spaces() -> void:
	assert_eq(ZombieName.clean("S4m!é"), "Sm")
	assert_eq(ZombieName.clean("123"), "")
	assert_eq(ZombieName.clean("   "), "")
	assert_eq(ZombieName.clean(""), "")
	assert_eq(ZombieName.clean("Bo\tBo"), "BoBo", "a tab is not a space")


func test_is_valid() -> void:
	assert_false(ZombieName.is_valid(""))
	assert_false(ZombieName.is_valid(" "))
	assert_true(ZombieName.is_valid("Sam"))
	assert_false(ZombieName.is_valid("Sam "), "a trailing space is not stored")
	assert_false(ZombieName.is_valid(" Sam"))
	assert_false(ZombieName.is_valid("Sam  Z"))
	assert_true(ZombieName.is_valid("Sam Z"))
	assert_true(ZombieName.is_valid("W".repeat(MAX)))
	assert_false(ZombieName.is_valid("W".repeat(MAX + 1)))
	assert_false(ZombieName.is_valid("S4m"))
	assert_false(ZombieName.is_valid("!!!"))
	assert_false(ZombieName.is_valid("Zoë"))
