extends GutTest
## UI art review scene (Story 5.0, Gate 1): it shows every UI sheet, its pages cycle and wrap, its
## backgrounds are palette colours, and the grayscale view is Rec. 709 luma. The scene owns input, so
## instances are disabled; the cycles are driven through the _next_page() / _cycle_background() seams.

const ReviewScene: PackedScene = preload("res://scenes/debug/ui_art_review.tscn")
const PALETTE_PATH: String = "res://assets/palette/palette_32.png"

var _palette: Dictionary[String, bool] = {}


func before_all() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PALETTE_PATH))
	if image == null:
		return
	for x: int in image.get_width():
		_palette[image.get_pixel(x, 0).to_html(false)] = true


func _make() -> UiArtReview:
	var sut: UiArtReview = ReviewScene.instantiate() as UiArtReview
	sut.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(sut)
	return sut


func test_every_ui_sheet_is_shown() -> void:
	var sut: UiArtReview = _make()
	var sheets: Array[String] = UiArtReview.ui_sheets()
	assert_gt(sheets.size(), 60, "the UI sheets were found")
	assert_eq_deep(sut.shown_sheets(), sheets)


func test_pages_cycle_and_wrap() -> void:
	var sut: UiArtReview = _make()
	var count: int = sut.page_count()
	assert_gte(count, 5)
	assert_true(sut.page_names().has("hands: each finger lit (strong / weak)"))
	assert_eq(sut.page_index(), 0)
	for i: int in count:
		sut._next_page()
	assert_eq(sut.page_index(), 0, "wraps")


func test_backgrounds_are_palette_colours_and_wrap() -> void:
	var sut: UiArtReview = _make()
	var first: String = sut.background_name()
	for i: int in UiArtReview.BACKGROUNDS.size():
		assert_true(_palette.has(sut.background_color().to_html(false)), sut.background_name())
		sut._cycle_background()
	assert_eq(sut.background_name(), first)


func test_grayscale_is_rec_709_luma() -> void:
	var image: Image = Image.create_empty(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color("#b8f27c"))
	image.set_pixel(1, 0, Color(0, 0, 0, 0))
	var gray: Image = UiArtReview.grayscale(image)
	var c: Color = Color("#b8f27c")
	var luma: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	assert_almost_eq(gray.get_pixel(0, 0).r, luma, 0.01)
	assert_eq(gray.get_pixel(0, 0).r, gray.get_pixel(0, 0).b)
	assert_eq(gray.get_pixel(1, 0).a8, 0, "transparent stays transparent")
