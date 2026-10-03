extends GutTest
## The master palette file (Story 1.9, NFR13): 32x1 px, one opaque pixel per color, exactly the
## 32 colors of DESIGN.md in their order. Read from the committed PNG bytes, not the import.

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
## DESIGN.md -> Colors, in order: 24 UI colors, then the 8 reserved art colors.
const EXPECTED_HEX: Array[String] = [
	"1e1428", "2b1d3f", "4a3366", "f6e7c1", "d9bc84", "8a7552", "4e4757", "5a3218",
	"8a5228", "c08447", "6f6a80", "bdb6c4", "24402f", "f4f1e4", "a8c4a6", "f07a1c",
	"ffa94a", "ffd23f", "6cc24a", "b8f27c", "2e6b26", "7a4bb3", "b02a25", "cfc6b6",
	"7ec8e3", "bfe6f2", "4e9a34", "f2c9a0", "b07850", "f29ab8", "c9607f", "fff3b0",
]


func _load() -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(PALETTE_PATH))


func test_expected_list_has_32_distinct_colors() -> void:
	var unique: Dictionary[String, bool] = {}
	for hex: String in EXPECTED_HEX:
		unique[hex] = true
	assert_eq(EXPECTED_HEX.size(), 32)
	assert_eq(unique.size(), 32)


func test_palette_file_exists_and_is_32_by_1() -> void:
	assert_true(FileAccess.file_exists(PALETTE_PATH))
	var image: Image = _load()
	assert_not_null(image)
	if image == null:
		return
	assert_eq(image.get_width(), 32)
	assert_eq(image.get_height(), 1)


func test_every_pixel_is_opaque_and_matches_design_in_order() -> void:
	var image: Image = _load()
	assert_not_null(image)
	if image == null or image.get_width() != 32 or image.get_height() != 1:
		return
	var unique: Dictionary[String, bool] = {}
	for x: int in 32:
		var color: Color = image.get_pixel(x, 0)
		assert_eq(color.a8, 255, "index %d not opaque" % x)
		var hex: String = color.to_html(false)
		unique[hex] = true
		assert_eq(hex, EXPECTED_HEX[x], "index %d" % x)
	assert_eq(unique.size(), 32, "32 distinct colors")
