extends GutTest
## Prototype sprite sheets (Story 1.9, NFR13), the Professor Zombie (Story 2.9) and the party-hat zombie
## (Story 3.3): size, hard alpha, palette-only pixels, the 1 px ink
## outline rule, non-empty distinct frames on one ground line, and pixel-crisp import settings.
## Read from the committed PNG bytes (Image.load_from_file), so import state doesn't matter.

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const FRAME: int = 32
## Sheet path -> frame count.
const SHEETS: Dictionary[String, int] = {
	"res://assets/sprites/characters/zombie/zombie_idle.png": 2,
	"res://assets/sprites/characters/zombie/zombie_walk.png": 4,
	"res://assets/sprites/characters/villager/villager_wave.png": 2,
	"res://assets/sprites/characters/professor/professor_point.png": 2,
	"res://assets/sprites/characters/party_zombie/party_zombie_idle.png": 2,
}
const PARTY_ZOMBIE_PATH: String = "res://assets/sprites/characters/party_zombie/party_zombie_idle.png"
## One-frame overlays drawn over a sheet (not animations, so not in SHEETS): same pixel rules.
const OVERLAYS: Array[String] = ["res://assets/sprites/characters/professor/professor_mortarboard.png"]
const INK: String = "1e1428"
const ZOMBIE_GREEN: String = "6cc24a"
const ZOMBIE_GREEN_DARK: String = "2e6b26"
const ART_SKIN_LIGHT: String = "f2c9a0"
## Orthogonal neighbours (up, down, left, right).
const NEIGHBOURS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var _palette: Dictionary[String, bool] = {}


func before_all() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PALETTE_PATH))
	if image == null:
		return
	for x: int in image.get_width():
		_palette[image.get_pixel(x, 0).to_html(false)] = true


func _load(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _name(path: String) -> String:
	return path.get_file().get_basename()


## Sheets and overlays -> frame count (an overlay is one frame).
func _frame_counts(with_overlays: bool) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = SHEETS.duplicate()
	if with_overlays:
		for path: String in OVERLAYS:
			counts[path] = 1
	return counts


## Sheets (and overlays) that exist with the right size; anything else fails the size test, not every test.
func _valid_sheets(with_overlays: bool = false) -> Dictionary[String, Image]:
	var counts: Dictionary[String, int] = _frame_counts(with_overlays)
	var found: Dictionary[String, Image] = {}
	for path: String in counts:
		var image: Image = _load(path)
		if image != null and image.get_width() == counts[path] * FRAME and image.get_height() == FRAME:
			found[path] = image
	return found


func _opaque(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).a8 == 255


func _frame_bytes(image: Image, frame: int) -> PackedByteArray:
	return image.get_region(Rect2i(frame * FRAME, 0, FRAME, FRAME)).get_data()


func _lowest_opaque_row(image: Image, frame: int) -> int:
	for y: int in range(FRAME - 1, -1, -1):
		for x: int in FRAME:
			if _opaque(image, frame * FRAME + x, y):
				return y
	return -1


func _colors(image: Image) -> Dictionary[String, bool]:
	var found: Dictionary[String, bool] = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _opaque(image, x, y):
				found[image.get_pixel(x, y).to_html(false)] = true
	return found


func test_palette_loaded() -> void:
	assert_eq(_palette.size(), 32)


func test_sheets_exist_with_frame_size_and_count() -> void:
	for path: String in SHEETS:
		var frames: int = SHEETS[path]
		assert_between(frames, 2, 6, "%s frame count" % _name(path))
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % path)
		if image == null:
			continue
		assert_eq(image.get_width(), frames * FRAME, "%s width" % _name(path))
		assert_eq(image.get_height(), FRAME, "%s height" % _name(path))


func test_overlays_exist_one_frame() -> void:
	for path: String in OVERLAYS:
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % path)
		if image == null:
			continue
		assert_eq(image.get_size(), Vector2i(FRAME, FRAME), "%s size" % _name(path))


func test_hard_alpha_and_palette_only() -> void:
	var sheets: Dictionary[String, Image] = _valid_sheets(true)
	assert_eq(sheets.size(), SHEETS.size() + OVERLAYS.size())
	for path: String in sheets:
		var image: Image = sheets[path]
		var bad: Array[String] = []
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a8 != 0 and color.a8 != 255:
					bad.append("(%d,%d) alpha %d" % [x, y, color.a8])
				elif color.a8 == 255 and not _palette.has(color.to_html(false)):
					bad.append("(%d,%d) rgb %s off palette" % [x, y, color.to_html(false)])
		assert_eq(bad.size(), 0, "%s: %s" % [_name(path), ", ".join(bad.slice(0, 10))])


## Rule 4: an opaque pixel that is not ink has all four neighbours opaque, inside its own frame.
func test_outline_rule() -> void:
	var counts: Dictionary[String, int] = _frame_counts(true)
	var sheets: Dictionary[String, Image] = _valid_sheets(true)
	assert_eq(sheets.size(), counts.size())
	for path: String in sheets:
		var image: Image = sheets[path]
		var bad: Array[String] = []
		for frame: int in counts[path]:
			for y: int in FRAME:
				for x: int in FRAME:
					var px: int = frame * FRAME + x
					if not _opaque(image, px, y):
						continue
					var hex: String = image.get_pixel(px, y).to_html(false)
					if hex == INK:
						continue
					for step: Vector2i in NEIGHBOURS:
						var nx: int = x + step.x
						var ny: int = y + step.y
						if nx < 0 or ny < 0 or nx >= FRAME or ny >= FRAME \
								or not _opaque(image, frame * FRAME + nx, ny):
							bad.append("%s frame %d (%d,%d) rgb %s open edge" % [_name(path), frame, x, y, hex])
							break
		assert_eq(bad.size(), 0, ", ".join(bad.slice(0, 10)))


func test_frames_not_empty_distinct_and_grounded() -> void:
	var sheets: Dictionary[String, Image] = _valid_sheets()
	assert_eq(sheets.size(), SHEETS.size())
	for path: String in sheets:
		var image: Image = sheets[path]
		var frames: int = SHEETS[path]
		var ground: int = _lowest_opaque_row(image, 0)
		for frame: int in frames:
			var lowest: int = _lowest_opaque_row(image, frame)
			assert_ne(lowest, -1, "%s frame %d empty" % [_name(path), frame])
			assert_eq(lowest, ground, "%s frame %d ground line" % [_name(path), frame])
			for other: int in range(frame + 1, frames):
				assert_ne(_frame_bytes(image, frame), _frame_bytes(image, other),
						"%s frames %d and %d identical" % [_name(path), frame, other])


## The professor is the player zombie in a gown, so his sheet uses the zombie greens. Overlays: ink only.
func test_right_color_ramps_used() -> void:
	var sheets: Dictionary[String, Image] = _valid_sheets(true)
	assert_eq(sheets.size(), SHEETS.size() + OVERLAYS.size())
	for path: String in sheets:
		var colors: Dictionary[String, bool] = _colors(sheets[path])
		assert_true(colors.has(INK), "%s has no ink" % _name(path))
		if path in OVERLAYS:
			continue
		if path.contains("/zombie/") or path.contains("/professor/") or path == PARTY_ZOMBIE_PATH:
			assert_true(colors.has(ZOMBIE_GREEN), "%s has no zombie-green" % _name(path))
			assert_true(colors.has(ZOMBIE_GREEN_DARK), "%s has no zombie-green-dark" % _name(path))
		else:
			assert_true(colors.has(ART_SKIN_LIGHT), "%s has no art-skin-light" % _name(path))


func test_import_settings_lossless_no_mipmaps() -> void:
	var paths: Array[String] = [PALETTE_PATH]
	paths.append_array(SHEETS.keys())
	paths.append_array(OVERLAYS)
	for path: String in paths:
		var config: ConfigFile = ConfigFile.new()
		var err: Error = config.load(path + ".import")
		assert_eq(err, OK, "%s.import missing" % path)
		if err != OK:
			continue
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % path)
		assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % path)


## Style sheet section 6: the party-hat zombie is a villager recolour, so no villager skin is left.
func test_party_zombie_is_a_recoloured_villager() -> void:
	var image: Image = _load(PARTY_ZOMBIE_PATH)
	assert_not_null(image, "party zombie sheet missing")
	if image == null:
		return
	var colors: Dictionary[String, bool] = _colors(image)
	assert_false(colors.has(ART_SKIN_LIGHT), "no art-skin-light left")
	assert_false(colors.has("b07850"), "no art-skin-dark left")
	assert_true(colors.has(ZOMBIE_GREEN))
	assert_true(colors.has("f07a1c"), "keeps the villager's pumpkin shirt")
