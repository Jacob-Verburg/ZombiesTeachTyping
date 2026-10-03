extends GutTest
## Guards the shared UI theme and its pixel font (Story 1.3, NFR7).

const THEME_PATH: String = "res://data/ui_theme.tres"
const LICENSE_PATH: String = "res://assets/fonts/press_start_2p_OFL.txt"
## The font's native grid; every UI size must be a whole multiple so no glyph pixel smears.
const NATIVE_PX: int = 8

var _theme: Theme


func before_each() -> void:
	_theme = load(THEME_PATH) as Theme


func test_theme_loads() -> void:
	assert_not_null(_theme)


func test_project_uses_ui_theme() -> void:
	var custom: String = ProjectSettings.get_setting("gui/theme/custom", "")
	assert_ne(custom, "")
	assert_true(load(custom) is Theme)
	assert_eq(ResourceLoader.load(custom).resource_path, THEME_PATH)


func test_default_font_is_project_pixel_font() -> void:
	var font: Font = _theme.default_font
	assert_not_null(font)
	assert_true(font.resource_path.begins_with("res://assets/fonts/"), font.resource_path)


func test_default_font_size_is_readable_and_on_grid() -> void:
	assert_gte(_theme.default_font_size, 16)
	assert_eq(_theme.default_font_size % NATIVE_PX, 0)


func test_font_is_imported_pixel_crisp() -> void:
	var font: FontFile = _theme.default_font as FontFile
	assert_not_null(font)
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	assert_eq(font.hinting, TextServer.HINTING_NONE)
	assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)


func test_ofl_license_ships_with_font() -> void:
	assert_true(FileAccess.file_exists(LICENSE_PATH))
	var text: String = FileAccess.get_file_as_string(LICENSE_PATH)
	assert_string_contains(text, "SIL OPEN FONT LICENSE Version 1.1")


func test_font_has_confusable_glyphs_and_title_copy() -> void:
	var font: Font = _theme.default_font
	for c: String in "lI1O0" + "Click or press any key":
		assert_true(font.has_char(c.unicode_at(0)), "missing glyph '%s'" % c)
