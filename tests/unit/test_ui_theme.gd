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


## Story 4.2: the shared PixelButton variation.
func test_pixel_button_variation_exists_and_reads() -> void:
	assert_eq(_theme.get_type_variation_base(&"PixelButton"), &"Button")
	assert_true(_theme.has_font_size(&"font_size", &"PixelButton"))
	var size: int = _theme.get_font_size(&"font_size", &"PixelButton")
	assert_gte(size, 16)
	assert_eq(size % NATIVE_PX, 0)
	for style: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"normal_focused"]:
		assert_true(_theme.has_stylebox(style, &"PixelButton"), String(style))


## Story 5.0: every PixelButton box is 9-slice art (stepped corners in the texture, never a StyleBoxFlat
## radius), from assets/sprites/ui/, with margins.
func test_pixel_button_boxes_are_ui_art() -> void:
	for style: StringName in _theme.get_stylebox_list(&"PixelButton"):
		var box: StyleBoxTexture = _theme.get_stylebox(style, &"PixelButton") as StyleBoxTexture
		assert_not_null(box, "%s is a StyleBoxTexture" % style)
		if box == null:
			continue
		assert_not_null(box.texture, String(style))
		assert_true(box.texture.resource_path.begins_with("res://assets/sprites/ui/"), box.texture.resource_path)
		for side: int in 4:
			assert_gt(box.get_texture_margin(side), 0.0, "%s margin %d" % [style, side])


func test_pixel_button_focus_ring_sits_outside_the_outline() -> void:
	var ring: StyleBoxTexture = _theme.get_stylebox(&"focus", &"PixelButton") as StyleBoxTexture
	assert_not_null(ring)
	assert_false(ring.draw_center)
	assert_eq(ring.texture.resource_path, "res://assets/sprites/ui/common/ui_focus_ring.png")
	for side: int in 4:
		assert_eq(ring.get_expand_margin(side), 2.0)


## The squish: the pressed plank drops 2 px, and its label moves down with it.
func test_pressed_box_moves_the_label_down_2_px() -> void:
	var normal: StyleBox = _theme.get_stylebox(&"normal", &"PixelButton")
	var pressed: StyleBox = _theme.get_stylebox(&"pressed", &"PixelButton")
	assert_eq(pressed.get_content_margin(SIDE_TOP) - normal.get_content_margin(SIDE_TOP), 2.0)
	assert_eq(normal.get_content_margin(SIDE_BOTTOM) - pressed.get_content_margin(SIDE_BOTTOM), 2.0)
	assert_eq((pressed as StyleBoxTexture).texture.resource_path, "res://assets/sprites/ui/common/ui_button_pressed.png")


## The shared boxes every screen uses (Story 5.0, AC 7): one place each, all 9-slice art.
func test_shared_box_variations() -> void:
	for type_name: StringName in [&"WoodPanel", &"StonePanel", &"Sign", &"SignGrey", &"Chalkboard", &"CandySign",
			&"BrainPill", &"ShadowMd", &"ShadowLg", &"InkStrip", &"CardFrame", &"HudBand", &"Mirror", &"Ribbon",
			&"TileParchment", &"TileStone", &"TileDisabled", &"TagPumpkin", &"TagGreen", &"TagBright", &"FocusRing",
			&"FocusRingInset"]:
		assert_eq(_theme.get_type_variation_base(type_name), &"Panel", String(type_name))
		assert_true(_theme.get_stylebox(&"panel", type_name) is StyleBoxTexture, String(type_name))
	assert_eq(_theme.get_type_variation_base(&"Keycap"), &"Label")
	assert_true(_theme.get_stylebox(&"normal", &"Keycap") is StyleBoxTexture)


## Plank grain and stone courses tile; flat fills stretch.
func test_patterned_panels_tile() -> void:
	for type_name: StringName in [&"WoodPanel", &"StonePanel"]:
		var box: StyleBoxTexture = _theme.get_stylebox(&"panel", type_name) as StyleBoxTexture
		assert_eq(box.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, String(type_name))
		assert_eq(box.axis_stretch_vertical, StyleBoxTexture.AXIS_STRETCH_MODE_TILE, String(type_name))
	var sign_box: StyleBoxTexture = _theme.get_stylebox(&"panel", &"Sign") as StyleBoxTexture
	assert_eq(sign_box.axis_stretch_horizontal, StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH)


func test_no_flat_boxes_in_the_theme() -> void:
	for type_name: StringName in _theme.get_stylebox_type_list():
		for style: StringName in _theme.get_stylebox_list(type_name):
			assert_false(_theme.get_stylebox(style, type_name) is StyleBoxFlat, "%s/%s" % [type_name, style])
