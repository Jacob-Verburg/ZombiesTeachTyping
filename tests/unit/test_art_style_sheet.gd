extends GutTest
## The art style sheet (Story 1.9, NFR13) records the palette, sprite sizes, animation limits,
## the font and its license, and points at the approval record.

const SHEET_PATH: String = "res://docs/art-style-sheet.md"
const PALETTE_HEX: Array[String] = [
	"1e1428", "2b1d3f", "4a3366", "f6e7c1", "d9bc84", "8a7552", "4e4757", "5a3218",
	"8a5228", "c08447", "6f6a80", "bdb6c4", "24402f", "f4f1e4", "a8c4a6", "f07a1c",
	"ffa94a", "ffd23f", "6cc24a", "b8f27c", "2e6b26", "7a4bb3", "b02a25", "cfc6b6",
	"7ec8e3", "bfe6f2", "4e9a34", "f2c9a0", "b07850", "f29ab8", "c9607f", "fff3b0",
]
const REQUIRED_PHRASES: Array[String] = [
	"Press Start 2P", "SIL Open Font License", "32×32", "48×48", "16×16", "8–12 fps", "2–6 frames",
	"press_start_2p_OFL.txt", "palette_32.png",
]


func _text() -> String:
	return FileAccess.get_file_as_string(SHEET_PATH)


func test_style_sheet_exists() -> void:
	assert_true(FileAccess.file_exists(SHEET_PATH))


func test_lists_all_32_palette_colors() -> void:
	var text: String = _text().to_lower()
	for hex: String in PALETTE_HEX:
		assert_string_contains(text, "#" + hex)


func test_records_sizes_limits_and_font() -> void:
	var text: String = _text()
	for phrase: String in REQUIRED_PHRASES:
		assert_string_contains(text, phrase)


func test_has_approval_heading() -> void:
	var regex: RegEx = RegEx.create_from_string(r"(?m)^#+ Approval\s*$")
	assert_not_null(regex.search(_text()), "no Approval heading")
