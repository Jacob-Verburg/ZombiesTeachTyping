extends GutTest
## Sunny Village Green backdrop art (Story 3.6, FR37, NFR13): layer and tile sizes, hard alpha,
## palette-only pixels, never candy-yellow or stamp-red, the in-world tag band free of the tag and arrow
## colours, the 640 px seam (a cheap heuristic: a clipped feature fails it, a wrapped one passes), the
## ground strip built from the tiles, and pixel-crisp import settings. Backdrop layers and ground tiles are
## exempt from the ink-outline rule only. Read from the committed PNG bytes (Image.load_from_file).
## Story 6.6 adds the Farmhouse layers (Horde Rush): static, never tiled (so no seam test), the same
## palette/alpha/colour rules, no zombie green in the lanes (a copy must never camouflage) and a doorway
## per lane on the farmhouse's field edge.
## Story 8.6 adds the Moonlit Village (Pitchfork Panic): the Sunny Village rules plus art-moon on the moon
## only, seamless cobble tiles, and the night readability band (near.png rows 160-191 opaque and free of the
## characters' colours, and so is the ground strip's top).
## Story 10.2 adds the Zombie Run themes Pumpkin Patch Farm and Snowy Town: each folder goes through the Sunny
## rules (sizes, palette and hard alpha, reserved colours, the tag band, the seam, seamless tiles, the strip built
## from its tiles with the path last) plus art-moon nowhere, the day readability band (near.png rows 160-191
## and the strip's top 4 rows free of the zombie's greens) and the Halloween dressing (pumpkin and bat-purple).
## Story 10.3 adds the Horde Rush pairs Castle and Beach Hut: each folder goes through the Farmhouse rules (sizes,
## palette and hard alpha, candy-yellow, stamp-red and art-moon nowhere, no zombie greens in the lanes or the house
## front, the field opaque, a doorway per lane on the soles row against that house's own wall colours) and the
## pixel-crisp import.

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const DIR: String = "res://assets/sprites/backdrops/sunny_village_green/"
const LAYERS: Array[String] = ["clouds.png", "far.png", "near.png"]
const TILES: String = "ground_tiles.png"
const STRIP: String = "ground_strip.png"
const PERIOD: int = 640
const PLAYFIELD_GROUND_Y: int = 192
const STRIP_H: int = 64
const TILE: int = 16
## The in-world tag band (DESIGN.md: villager tags ~139-163, brain block tags ~102-126, arrows above).
const TAG_BAND_TOP: int = 96
const TAG_BAND_BOTTOM: int = 166
const CANDY_YELLOW: String = "ffd23f"
const STAMP_RED: String = "b02a25"
const PARCHMENT: String = "f6e7c1"
const CHALK: String = "f4f1e4"
## The Halloween dressing (DESIGN.md): a pumpkin on a fence post and bat-purple bunting.
const PUMPKIN: String = "f07a1c"
const BAT_PURPLE: String = "7a4bb3"
## Farmhouse (Story 6.6): field.png at (0, 0), farmhouse.png at (HOUSE_FRONT_X, 0); horde_rush_level.gd layout.
const FARM_DIR: String = "res://assets/sprites/backdrops/farmhouse/"
const FARM_FILES: Dictionary[String, Vector2i] = {
	"field.png": Vector2i(640, 256),
	"farmhouse.png": Vector2i(92, 256),
}
const FARM_FIELD_TOP_Y: int = 36
const FARM_LANE_HEIGHT: int = 44
const FARM_FEET_INSET: int = 6
const FARM_LANE_COUNT: int = 5
const HOUSE_FRONT_X: int = 548
const ZOMBIE_GREEN: String = "6cc24a"
const ZOMBIE_GREEN_BRIGHT: String = "b8f27c"
## The farmhouse wall: plank fill, plank seams and the ink corner. Anything else at the field edge is a
## doorway (the dark opening and its floor).
const WALL_COLOURS: Array[String] = ["c08447", "8a5228", "1e1428"]
## The doorway's column band at the farmhouse's field edge, and its shortest opening.
const DOOR_COLUMNS: int = 4
const DOOR_MIN_H: int = 24

var _palette: Dictionary[String, bool] = {}


func before_all() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PALETTE_PATH))
	if image == null:
		return
	for x: int in image.get_width():
		_palette[image.get_pixel(x, 0).to_html(false)] = true


func _load(file: String) -> Image:
	var path: String = DIR + file
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _all_files() -> Array[String]:
	var files: Array[String] = LAYERS.duplicate()
	files.append_array([TILES, STRIP])
	return files


func _colors(image: Image, from_y: int = 0, to_y: int = -1) -> Dictionary[String, bool]:
	var found: Dictionary[String, bool] = {}
	var last: int = image.get_height() - 1 if to_y < 0 else mini(to_y, image.get_height() - 1)
	for y: int in range(from_y, last + 1):
		for x: int in image.get_width():
			if image.get_pixel(x, y).a8 == 255:
				found[image.get_pixel(x, y).to_html(false)] = true
	return found


func test_layers_exist_at_the_expected_size() -> void:
	for file: String in LAYERS:
		var image: Image = _load(file)
		assert_not_null(image, "%s missing" % file)
		if image == null:
			continue
		assert_eq(image.get_width(), PERIOD, "%s is one 640 px period wide" % file)
		assert_between(image.get_height(), 1, PLAYFIELD_GROUND_Y, "%s fits y 0-192" % file)
	var strip: Image = _load(STRIP)
	assert_not_null(strip)
	if strip != null:
		assert_eq(strip.get_size(), Vector2i(PERIOD, STRIP_H))
	var tiles: Image = _load(TILES)
	assert_not_null(tiles)
	if tiles != null:
		assert_eq(tiles.get_width() % TILE, 0, "tile strip width is a multiple of 16")
		assert_eq(tiles.get_height(), TILE)
		assert_gt(tiles.get_width() / TILE, 3, "grass, tuft, flower and path at least")


func test_hard_alpha_and_palette_only() -> void:
	for file: String in _all_files():
		var image: Image = _load(file)
		if image == null:
			fail_test("%s missing" % file)
			continue
		var bad: Array[String] = []
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a8 != 0 and color.a8 != 255:
					bad.append("(%d,%d) alpha %d" % [x, y, color.a8])
				elif color.a8 == 255 and not _palette.has(color.to_html(false)):
					bad.append("(%d,%d) rgb %s off palette" % [x, y, color.to_html(false)])
		assert_eq(bad.size(), 0, "%s: %s" % [file, ", ".join(bad.slice(0, 10))])


## Candy-yellow is focus only, stamp-red the stamp only (style sheet section 5).
func test_no_candy_yellow_or_stamp_red() -> void:
	for file: String in _all_files():
		var image: Image = _load(file)
		if image == null:
			continue
		var colors: Dictionary[String, bool] = _colors(image)
		assert_false(colors.has(CANDY_YELLOW), "%s uses candy-yellow" % file)
		assert_false(colors.has(STAMP_RED), "%s uses stamp-red" % file)


## AC 6's mechanical guard: nothing behind a tag or the arrow wears their colours.
func test_tag_band_is_free_of_the_tag_and_arrow_colours() -> void:
	for file: String in ["far.png", "near.png", "clouds.png"]:
		var image: Image = _load(file)
		if image == null:
			continue
		var colors: Dictionary[String, bool] = _colors(image, TAG_BAND_TOP, TAG_BAND_BOTTOM)
		for hex: String in [PARCHMENT, CHALK, CANDY_YELLOW]:
			assert_false(colors.has(hex), "%s has %s in the tag band" % [file, hex])


func test_the_ground_strip_has_no_tag_colours() -> void:
	var colors: Dictionary[String, bool] = _colors(_load(STRIP))
	for hex: String in [PARCHMENT, CHALK, CANDY_YELLOW]:
		assert_false(colors.has(hex), "ground strip has %s" % hex)


## A cheap seam heuristic: in every row, x 0 and x 639 are both transparent or both opaque.
## Opacity only: x 0 and x 639 are neighbours when the layer tiles, so an outline next to fill is fine; colour
## continuity is not required (and the 2:00 scroll check by eye is the real proof).
func test_seam_rows_match() -> void:
	for file: String in _all_files():
		if file == TILES:
			continue
		var image: Image = _load(file)
		if image == null or image.get_width() != PERIOD:
			continue
		var bad: Array[int] = []
		for y: int in image.get_height():
			if (image.get_pixel(0, y).a8 == 255) != (image.get_pixel(PERIOD - 1, y).a8 == 255):
				bad.append(y)
		assert_eq(bad.size(), 0, "%s seam rows %s" % [file, bad.slice(0, 10)])


## The seam check would pass a layer with nothing at the seam; the art puts features across it on purpose.
func test_features_cross_the_seam_on_purpose() -> void:
	for file: String in LAYERS:
		var image: Image = _load(file)
		if image == null:
			continue
		var crossing: int = 0
		for y: int in image.get_height():
			if image.get_pixel(0, y).a8 == 255 and image.get_pixel(PERIOD - 1, y).a8 == 255:
				crossing += 1
		assert_gt(crossing, 0, "%s has something across the seam" % file)


## Tiles sit side by side with no seam: each tile's left column equals its right column. The grass tiles
## also stack (rows 1-3), so their top row equals their bottom row; the path's faded top edge is the
## ground line and only ever meets the layers above it.
func test_tiles_are_seamless() -> void:
	var tiles: Image = _load(TILES)
	if tiles == null:
		fail_test("tiles missing")
		return
	var count: int = tiles.get_width() / TILE
	for tile: int in count:
		for y: int in TILE:
			assert_eq(tiles.get_pixel(tile * TILE, y), tiles.get_pixel(tile * TILE + TILE - 1, y),
					"tile %d row %d left/right edge" % [tile, y])
		if tile == count - 1:
			continue
		for x: int in TILE:
			assert_eq(tiles.get_pixel(tile * TILE + x, 0), tiles.get_pixel(tile * TILE + x, TILE - 1),
					"grass tile %d column %d top/bottom edge" % [tile, x])


## Each 16 x 16 cell of the strip is exactly one tile; the top row (the ground line) is the path.
func test_ground_strip_is_built_from_the_tiles() -> void:
	var tiles: Image = _load(TILES)
	var strip: Image = _load(STRIP)
	if tiles == null or strip == null:
		fail_test("tiles or strip missing")
		return
	var tile_bytes: Array[PackedByteArray] = []
	for tile: int in tiles.get_width() / TILE:
		tile_bytes.append(tiles.get_region(Rect2i(tile * TILE, 0, TILE, TILE)).get_data())
	var path_tile: int = tile_bytes.size() - 1
	var used: Dictionary[int, bool] = {}
	for row: int in STRIP_H / TILE:
		for col: int in PERIOD / TILE:
			var cell: PackedByteArray = strip.get_region(Rect2i(col * TILE, row * TILE, TILE, TILE)).get_data()
			var index: int = tile_bytes.find(cell)
			assert_ne(index, -1, "cell (%d,%d) is a tile" % [col, row])
			used[index] = true
			if row == 0:
				assert_eq(index, path_tile, "row 0 is the path (%d)" % col)
			else:
				assert_ne(index, path_tile, "rows 1-3 are grass (%d,%d)" % [col, row])
	assert_eq(used.size(), tile_bytes.size(), "every tile is used")


## DESIGN.md's Halloween dressing on Sunny Village Green: a pumpkin and bat-purple bunting.
func test_near_layer_carries_the_halloween_dressing() -> void:
	var colors: Dictionary[String, bool] = _colors(_load("near.png"))
	assert_true(colors.has(PUMPKIN), "a pumpkin on a fence post")
	assert_true(colors.has(BAT_PURPLE), "bat-purple bunting")


func test_import_settings_lossless_no_mipmaps() -> void:
	for file: String in _all_files():
		var config: ConfigFile = ConfigFile.new()
		var err: Error = config.load(DIR + file + ".import")
		assert_eq(err, OK, "%s.import missing" % file)
		if err != OK:
			continue
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % file)
		assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % file)


# --- Farmhouse (Story 6.6) ---

func _load_farm(file: String) -> Image:
	var path: String = FARM_DIR + file
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


## Colours of the opaque pixels in the rect.
func _rect_colors(image: Image, rect: Rect2i) -> Dictionary[String, bool]:
	var found: Dictionary[String, bool] = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a8 == 255:
				found[image.get_pixel(x, y).to_html(false)] = true
	return found


func _feet_y(lane: int) -> int:
	return FARM_FIELD_TOP_Y + FARM_LANE_HEIGHT * (lane + 1) - FARM_FEET_INSET


func test_farmhouse_layers_exist_at_their_size() -> void:
	for file: String in FARM_FILES:
		var image: Image = _load_farm(file)
		assert_not_null(image, "%s missing" % file)
		if image != null:
			assert_eq(image.get_size(), FARM_FILES[file], "%s size" % file)


func test_farmhouse_hard_alpha_and_palette_only() -> void:
	for file: String in FARM_FILES:
		var image: Image = _load_farm(file)
		if image == null:
			fail_test("%s missing" % file)
			continue
		var bad: Array[String] = []
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a8 != 0 and color.a8 != 255:
					bad.append("(%d,%d) alpha %d" % [x, y, color.a8])
				elif color.a8 == 255 and not _palette.has(color.to_html(false)):
					bad.append("(%d,%d) rgb %s off palette" % [x, y, color.to_html(false)])
		assert_eq(bad.size(), 0, "%s: %s" % [file, ", ".join(bad.slice(0, 10))])


func test_farmhouse_no_candy_yellow_or_stamp_red() -> void:
	for file: String in FARM_FILES:
		var image: Image = _load_farm(file)
		if image == null:
			continue
		var colors: Dictionary[String, bool] = _colors(image)
		assert_false(colors.has(CANDY_YELLOW), "%s uses candy-yellow" % file)
		assert_false(colors.has(STAMP_RED), "%s uses stamp-red" % file)


## Where copies walk (the lanes left of the house, and the house's first 8 px below the sky band) there
## is no zombie-green or zombie-green-bright, so a copy never camouflages.
func test_no_zombie_green_where_copies_walk() -> void:
	_assert_no_zombie_green_where_copies_walk(_load_farm("field.png"), _load_farm("farmhouse.png"), "farmhouse")


## Shared (Story 10.3): no zombie greens in a pair's lanes or its house front.
func _assert_no_zombie_green_where_copies_walk(field: Image, house: Image, label: String) -> void:
	if field == null or house == null:
		fail_test("%s layers missing" % label)
		return
	var lanes: Dictionary[String, bool] = _rect_colors(field,
			Rect2i(0, FARM_FIELD_TOP_Y, HOUSE_FRONT_X, field.get_height() - FARM_FIELD_TOP_Y))
	var front: Dictionary[String, bool] = _rect_colors(house,
			Rect2i(0, FARM_FIELD_TOP_Y, 8, house.get_height() - FARM_FIELD_TOP_Y))
	for hex: String in [ZOMBIE_GREEN, ZOMBIE_GREEN_BRIGHT]:
		assert_false(lanes.has(hex), "%s field lanes use %s" % [label, hex])
		assert_false(front.has(hex), "%s front uses %s" % [label, hex])


## The field is fully opaque (it is the whole backdrop behind the lanes and the sky).
func test_field_is_opaque() -> void:
	var field: Image = _load_farm("field.png")
	if field == null:
		fail_test("field.png missing")
		return
	assert_eq(field.detect_alpha(), Image.ALPHA_NONE, "field.png has no transparent pixels")


## A doorway per lane: in every one of the farmhouse's first DOOR_COLUMNS columns, the run of non-wall
## pixels (anything but the plank fill, the seams and the ink edge) that ends on the lane's soles row
## (feet line - 1) is at least DOOR_MIN_H tall, and the feet-line row itself is not part of it (the step).
## So an arriving copy's soles meet the bottom of its own lane's opening.
func test_a_doorway_per_lane_on_the_feet_line() -> void:
	_assert_a_doorway_per_lane(_load_farm("farmhouse.png"), WALL_COLOURS, "farmhouse")


## Shared (Story 10.3): the doorway rule for any house, given its wall colours.
func _assert_a_doorway_per_lane(house: Image, wall: Array[String], label: String) -> void:
	if house == null:
		fail_test("%s house missing" % label)
		return
	for lane: int in FARM_LANE_COUNT:
		var bottom: int = _feet_y(lane) - 1
		for x: int in DOOR_COLUMNS:
			assert_false(_is_opening(house, x, bottom + 1, wall),
					"%s lane %d column %d: the opening runs past the feet line" % [label, lane, x])
			var run: int = 0
			while bottom - run >= 0 and _is_opening(house, x, bottom - run, wall):
				run += 1
			assert_true(run >= DOOR_MIN_H, "%s lane %d column %d: opening %d px tall, want >= %d" % [
					label, lane, x, run, DOOR_MIN_H])


## An opening pixel is opaque and not one of the house's wall colours.
func _is_opening(image: Image, x: int, y: int, wall: Array[String]) -> bool:
	var color: Color = image.get_pixel(x, y)
	return color.a8 == 255 and not color.to_html(false) in wall


func test_farmhouse_import_settings_lossless_no_mipmaps() -> void:
	for file: String in FARM_FILES:
		var config: ConfigFile = ConfigFile.new()
		var err: Error = config.load(FARM_DIR + file + ".import")
		assert_eq(err, OK, "%s.import missing" % file)
		if err != OK:
			continue
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % file)
		assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % file)


# --- Moonlit Village (Story 8.6, Pitchfork Panic) ---

const MOON_DIR: String = "res://assets/sprites/backdrops/moonlit_village/"
const MOON_FILE: String = "moon.png"
const MOON_SIZE: int = 48
const ART_MOON: String = "fff3b0"
const PUMPKIN_LIGHT: String = "ffa94a"
## The night readability band (Story 8.6 Dev Notes): near.png rows 160-191 fully opaque, and neither those
## rows nor the ground strip's top rows use a colour the characters rely on to stand out (ink, night, the
## zombie's greens and bat-purple shirt, the brain pinks).
const NIGHT_BAND_TOP: int = 160
const NIGHT_STRIP_ROWS: int = 4
const NIGHT_BAND_FORBIDDEN: Array[String] = [
	"1e1428", "2b1d3f", "6cc24a", "b8f27c", "7a4bb3", "f29ab8", "c9607f",
]
## Ground tiles the walking path (the strip's top row) may use: plain and cracked cobble.
const MOON_PATH_TILES: Array[int] = [0, 2]


func _load_moon(file: String) -> Image:
	var path: String = MOON_DIR + file
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _moon_files() -> Array[String]:
	var files: Array[String] = LAYERS.duplicate()
	files.append_array([TILES, STRIP, MOON_FILE])
	return files


## Shared check: every pixel hard alpha and on the palette. Returns the problems (empty when clean).
func _alpha_palette_problems(image: Image) -> Array[String]:
	var bad: Array[String] = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 != 0 and color.a8 != 255:
				bad.append("(%d,%d) alpha %d" % [x, y, color.a8])
			elif color.a8 == 255 and not _palette.has(color.to_html(false)):
				bad.append("(%d,%d) rgb %s off palette" % [x, y, color.to_html(false)])
	return bad


## Shared check: the rows where x 0 and the last column differ in opacity (empty when the layer wraps).
func _seam_mismatch_rows(image: Image) -> Array[int]:
	var bad: Array[int] = []
	var last: int = image.get_width() - 1
	for y: int in image.get_height():
		if (image.get_pixel(0, y).a8 == 255) != (image.get_pixel(last, y).a8 == 255):
			bad.append(y)
	return bad


## Shared check: Lossless, no mipmaps.
func _assert_pixel_crisp_import(path: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(path + ".import")
	assert_eq(err, OK, "%s.import missing" % path)
	if err != OK:
		return
	assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % path)
	assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % path)


func test_moonlit_files_exist_at_their_size() -> void:
	for file: String in LAYERS:
		var image: Image = _load_moon(file)
		assert_not_null(image, "%s missing" % file)
		if image != null:
			assert_eq(image.get_size(), Vector2i(PERIOD, PLAYFIELD_GROUND_Y), "%s size" % file)
	var strip: Image = _load_moon(STRIP)
	assert_not_null(strip)
	if strip != null:
		assert_eq(strip.get_size(), Vector2i(PERIOD, STRIP_H))
	var tiles: Image = _load_moon(TILES)
	assert_not_null(tiles)
	if tiles != null:
		assert_eq(tiles.get_size(), Vector2i(4 * TILE, TILE), "cobble, moss, crack and puddle")
	var moon: Image = _load_moon(MOON_FILE)
	assert_not_null(moon)
	if moon != null:
		assert_eq(moon.get_size(), Vector2i(MOON_SIZE, MOON_SIZE))


func test_moonlit_hard_alpha_and_palette_only() -> void:
	for file: String in _moon_files():
		var image: Image = _load_moon(file)
		if image == null:
			fail_test("%s missing" % file)
			continue
		var bad: Array[String] = _alpha_palette_problems(image)
		assert_eq(bad.size(), 0, "%s: %s" % [file, ", ".join(bad.slice(0, 10))])


## Candy-yellow is focus only, stamp-red the stamp only, art-moon the moon only.
func test_moonlit_reserved_colours() -> void:
	for file: String in _moon_files():
		var image: Image = _load_moon(file)
		if image == null:
			continue
		var colors: Dictionary[String, bool] = _colors(image)
		assert_false(colors.has(CANDY_YELLOW), "%s uses candy-yellow" % file)
		assert_false(colors.has(STAMP_RED), "%s uses stamp-red" % file)
		if file == MOON_FILE:
			assert_true(colors.has(ART_MOON), "the moon is art-moon")
		else:
			assert_false(colors.has(ART_MOON), "%s uses art-moon" % file)


func test_moonlit_seam_rows_match_and_features_cross() -> void:
	for file: String in [LAYERS[0], LAYERS[1], LAYERS[2], STRIP]:
		var image: Image = _load_moon(file)
		if image == null or image.get_width() != PERIOD:
			fail_test("%s missing" % file)
			continue
		var bad: Array[int] = _seam_mismatch_rows(image)
		assert_eq(bad.size(), 0, "%s seam rows %s" % [file, bad.slice(0, 10)])
		var crossing: int = 0
		for y: int in image.get_height():
			if image.get_pixel(0, y).a8 == 255 and image.get_pixel(PERIOD - 1, y).a8 == 255:
				crossing += 1
		assert_gt(crossing, 0, "%s has something across the seam" % file)


## Every tile repeats seamlessly with itself: left column = right column, top row = bottom row.
func test_moonlit_tiles_are_seamless() -> void:
	var tiles: Image = _load_moon(TILES)
	if tiles == null:
		fail_test("tiles missing")
		return
	for tile: int in tiles.get_width() / TILE:
		for i: int in TILE:
			assert_eq(tiles.get_pixel(tile * TILE, i), tiles.get_pixel(tile * TILE + TILE - 1, i),
					"tile %d row %d left/right edge" % [tile, i])
			assert_eq(tiles.get_pixel(tile * TILE + i, 0), tiles.get_pixel(tile * TILE + i, TILE - 1),
					"tile %d column %d top/bottom edge" % [tile, i])


## Each 16 x 16 cell of the strip is one tile, the top row (the walking path) only plain or cracked cobble,
## and every tile is used.
func test_moonlit_strip_is_built_from_the_tiles() -> void:
	var tiles: Image = _load_moon(TILES)
	var strip: Image = _load_moon(STRIP)
	if tiles == null or strip == null:
		fail_test("tiles or strip missing")
		return
	var tile_bytes: Array[PackedByteArray] = []
	for tile: int in tiles.get_width() / TILE:
		tile_bytes.append(tiles.get_region(Rect2i(tile * TILE, 0, TILE, TILE)).get_data())
	var used: Dictionary[int, bool] = {}
	for row: int in STRIP_H / TILE:
		for col: int in PERIOD / TILE:
			var cell: PackedByteArray = strip.get_region(Rect2i(col * TILE, row * TILE, TILE, TILE)).get_data()
			var index: int = tile_bytes.find(cell)
			assert_ne(index, -1, "cell (%d,%d) is a tile" % [col, row])
			used[index] = true
			if row == 0:
				assert_true(index in MOON_PATH_TILES, "path cell %d is cobble (tile %d)" % [col, index])
	assert_eq(used.size(), tile_bytes.size(), "every tile is used")


## The night readability band: near.png rows 160-191 fully opaque and free of the characters' colours, and
## the ground strip's top rows free of them too (so the ink outline, the zombie and the brains stand out).
func test_moonlit_night_readability_band() -> void:
	var near: Image = _load_moon("near.png")
	var strip: Image = _load_moon(STRIP)
	if near == null or strip == null:
		fail_test("near or strip missing")
		return
	var holes: int = 0
	for y: int in range(NIGHT_BAND_TOP, PLAYFIELD_GROUND_Y):
		for x: int in PERIOD:
			if near.get_pixel(x, y).a8 != 255:
				holes += 1
	assert_eq(holes, 0, "near.png rows 160-191 are fully opaque")
	var band: Dictionary[String, bool] = _colors(near, NIGHT_BAND_TOP, PLAYFIELD_GROUND_Y - 1)
	var path: Dictionary[String, bool] = _colors(strip, 0, NIGHT_STRIP_ROWS - 1)
	for hex: String in NIGHT_BAND_FORBIDDEN:
		assert_false(band.has(hex), "near.png band uses %s" % hex)
		assert_false(path.has(hex), "ground strip top rows use %s" % hex)


## DESIGN.md's cute-Halloween dressing: jack-o'-lanterns, lit windows, friendly bats.
func test_moonlit_carries_the_halloween_dressing() -> void:
	var near_img: Image = _load_moon("near.png")
	var far_img: Image = _load_moon("far.png")
	if near_img == null or far_img == null:
		fail_test("moonlit layers missing")
		return
	var near: Dictionary[String, bool] = _colors(near_img)
	var far: Dictionary[String, bool] = _colors(far_img)
	assert_true(near.has(PUMPKIN), "a jack-o'-lantern on the wall")
	assert_true(near.has(PUMPKIN_LIGHT) and far.has(PUMPKIN_LIGHT), "lit pumpkin-light windows")
	assert_true(far.has(BAT_PURPLE), "friendly bats over the hills")


func test_moonlit_import_settings_lossless_no_mipmaps() -> void:
	for file: String in _moon_files():
		_assert_pixel_crisp_import(MOON_DIR + file)


# --- Zombie Run themes (Story 10.2): Pumpkin Patch Farm and Snowy Town ---

const ZR_THEME_DIRS: Array[String] = [
	"res://assets/sprites/backdrops/pumpkin_patch_farm/",
	"res://assets/sprites/backdrops/snowy_town/",
]
## The day readability band: near.png rows 160-191 and the strip's top rows never wear the zombie's and the
## party zombies' skin, so a character never camouflages on its own colour.
const DAY_BAND_TOP: int = 160
const DAY_STRIP_ROWS: int = 4
const DAY_BAND_FORBIDDEN: Array[String] = [ZOMBIE_GREEN, ZOMBIE_GREEN_BRIGHT]


func _load_from(dir: String, file: String) -> Image:
	var path: String = dir + file
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


## Shared check: the colours of the opaque pixels in rows [from_y, to_y] (to_y -1 = the last row).
func _colors_in(dir: String, file: String, from_y: int = 0, to_y: int = -1) -> Dictionary[String, bool]:
	var image: Image = _load_from(dir, file)
	if image == null:
		fail_test("%s%s missing" % [dir, file])
		return {}
	return _colors(image, from_y, to_y)


## Shared check: true when something opaque sits on both x 0 and the last column in at least one row.
func _crosses_seam(image: Image) -> bool:
	var last: int = image.get_width() - 1
	for y: int in image.get_height():
		if image.get_pixel(0, y).a8 == 255 and image.get_pixel(last, y).a8 == 255:
			return true
	return false


func test_zr_themes_files_exist_at_their_size() -> void:
	for dir: String in ZR_THEME_DIRS:
		for file: String in LAYERS:
			var image: Image = _load_from(dir, file)
			assert_not_null(image, "%s%s missing" % [dir, file])
			if image != null:
				assert_eq(image.get_size(), Vector2i(PERIOD, PLAYFIELD_GROUND_Y), "%s%s size" % [dir, file])
		var tiles: Image = _load_from(dir, TILES)
		assert_not_null(tiles, "%s tiles missing" % dir)
		if tiles != null:
			assert_eq(tiles.get_size(), Vector2i(4 * TILE, TILE), "%s three ground tiles and the path" % dir)
		var strip: Image = _load_from(dir, STRIP)
		assert_not_null(strip, "%s strip missing" % dir)
		if strip != null:
			assert_eq(strip.get_size(), Vector2i(PERIOD, STRIP_H), "%s strip size" % dir)


func test_zr_themes_hard_alpha_and_palette_only() -> void:
	for dir: String in ZR_THEME_DIRS:
		for file: String in _all_files():
			var image: Image = _load_from(dir, file)
			if image == null:
				fail_test("%s%s missing" % [dir, file])
				continue
			var bad: Array[String] = _alpha_palette_problems(image)
			assert_eq(bad.size(), 0, "%s%s: %s" % [dir, file, ", ".join(bad.slice(0, 10))])


## Candy-yellow is focus only, stamp-red the stamp only, art-moon the moon only: none of them here.
func test_zr_themes_reserved_colours() -> void:
	for dir: String in ZR_THEME_DIRS:
		for file: String in _all_files():
			var colors: Dictionary[String, bool] = _colors_in(dir, file)
			for hex: String in [CANDY_YELLOW, STAMP_RED, ART_MOON]:
				assert_false(colors.has(hex), "%s%s uses %s" % [dir, file, hex])


func test_zr_themes_tag_band_and_strip_free_of_tag_colours() -> void:
	for dir: String in ZR_THEME_DIRS:
		for file: String in LAYERS:
			var band: Dictionary[String, bool] = _colors_in(dir, file, TAG_BAND_TOP, TAG_BAND_BOTTOM)
			for hex: String in [PARCHMENT, CHALK, CANDY_YELLOW]:
				assert_false(band.has(hex), "%s%s has %s in the tag band" % [dir, file, hex])
		var strip: Dictionary[String, bool] = _colors_in(dir, STRIP)
		for hex: String in [PARCHMENT, CHALK, CANDY_YELLOW]:
			assert_false(strip.has(hex), "%s ground strip has %s" % [dir, hex])


func test_zr_themes_seam_rows_match_and_features_cross() -> void:
	for dir: String in ZR_THEME_DIRS:
		for file: String in [LAYERS[0], LAYERS[1], LAYERS[2], STRIP]:
			var image: Image = _load_from(dir, file)
			if image == null or image.get_width() != PERIOD:
				fail_test("%s%s missing" % [dir, file])
				continue
			var bad: Array[int] = _seam_mismatch_rows(image)
			assert_eq(bad.size(), 0, "%s%s seam rows %s" % [dir, file, bad.slice(0, 10)])
			assert_true(_crosses_seam(image), "%s%s has something across the seam" % [dir, file])


## Every tile repeats with itself left to right; the three ground tiles also top to bottom (they stack in
## rows 1-3); the path's top edge is the ground line and only ever meets the layers above it.
func test_zr_themes_tiles_are_seamless() -> void:
	for dir: String in ZR_THEME_DIRS:
		var tiles: Image = _load_from(dir, TILES)
		if tiles == null:
			fail_test("%s tiles missing" % dir)
			continue
		var count: int = tiles.get_width() / TILE
		for tile: int in count:
			for i: int in TILE:
				assert_eq(tiles.get_pixel(tile * TILE, i), tiles.get_pixel(tile * TILE + TILE - 1, i),
						"%s tile %d row %d left/right edge" % [dir, tile, i])
				if tile < count - 1:
					assert_eq(tiles.get_pixel(tile * TILE + i, 0), tiles.get_pixel(tile * TILE + i, TILE - 1),
							"%s tile %d column %d top/bottom edge" % [dir, tile, i])


## Each 16 x 16 cell of the strip is exactly one tile; row 0 only the path (the last tile), rows 1-3 never;
## every tile is used.
func test_zr_themes_strip_is_built_from_the_tiles() -> void:
	for dir: String in ZR_THEME_DIRS:
		var tiles: Image = _load_from(dir, TILES)
		var strip: Image = _load_from(dir, STRIP)
		if tiles == null or strip == null:
			fail_test("%s tiles or strip missing" % dir)
			continue
		var tile_bytes: Array[PackedByteArray] = []
		for tile: int in tiles.get_width() / TILE:
			tile_bytes.append(tiles.get_region(Rect2i(tile * TILE, 0, TILE, TILE)).get_data())
		var path_tile: int = tile_bytes.size() - 1
		var used: Dictionary[int, bool] = {}
		var problems: Array[String] = []
		for row: int in STRIP_H / TILE:
			for col: int in PERIOD / TILE:
				var cell: PackedByteArray = strip.get_region(Rect2i(col * TILE, row * TILE, TILE, TILE)).get_data()
				var index: int = tile_bytes.find(cell)
				if index == -1:
					problems.append("(%d,%d) not a tile" % [col, row])
					continue
				used[index] = true
				if (row == 0) != (index == path_tile):
					problems.append("(%d,%d) tile %d" % [col, row, index])
		assert_eq(problems.size(), 0, "%s strip: %s" % [dir, ", ".join(problems.slice(0, 10))])
		assert_eq(used.size(), tile_bytes.size(), "%s: every tile is used" % dir)


func test_zr_themes_day_readability_band() -> void:
	for dir: String in ZR_THEME_DIRS:
		var band: Dictionary[String, bool] = _colors_in(dir, "near.png", DAY_BAND_TOP, PLAYFIELD_GROUND_Y - 1)
		var path: Dictionary[String, bool] = _colors_in(dir, STRIP, 0, DAY_STRIP_ROWS - 1)
		for hex: String in DAY_BAND_FORBIDDEN:
			assert_false(band.has(hex), "%snear.png rows 160-191 use %s" % [dir, hex])
			assert_false(path.has(hex), "%s ground strip top rows use %s" % [dir, hex])


## DESIGN.md D6's light dusting of Halloween: a pumpkin and bat-purple in the near or far layer.
func test_zr_themes_carry_the_halloween_dressing() -> void:
	for dir: String in ZR_THEME_DIRS:
		var colors: Dictionary[String, bool] = _colors_in(dir, "near.png")
		colors.merge(_colors_in(dir, "far.png"))
		assert_true(colors.has(PUMPKIN), "%s has a pumpkin" % dir)
		assert_true(colors.has(BAT_PURPLE), "%s has bat-purple" % dir)


func test_zr_themes_import_settings_lossless_no_mipmaps() -> void:
	for dir: String in ZR_THEME_DIRS:
		for file: String in _all_files():
			_assert_pixel_crisp_import(dir + file)


# --- Castle and Beach Hut (Story 10.3, Horde Rush pairs) ---

## Each pair's folder, its house file and the house's wall colours (fill, joints or seams, ink edge):
## anything else at the field edge is a doorway.
const HR_PAIRS: Dictionary[String, Dictionary] = {
	"res://assets/sprites/backdrops/castle/": {
		"house": "castle.png",
		"wall": ["bdb6c4", "6f6a80", "1e1428"],
	},
	"res://assets/sprites/backdrops/beach_hut/": {
		"house": "beach_hut.png",
		"wall": ["f4f1e4", "bfe6f2", "8a5228", "1e1428"],
	},
}


func _hr_files(dir: String) -> Dictionary[String, Vector2i]:
	var house: String = HR_PAIRS[dir]["house"]
	return {"field.png": FARM_FILES["field.png"], house: FARM_FILES["farmhouse.png"]}


func _hr_wall(dir: String) -> Array[String]:
	var wall: Array[String] = []
	wall.assign(HR_PAIRS[dir]["wall"])
	return wall


func test_hr_pairs_layers_exist_at_their_size() -> void:
	for dir: String in HR_PAIRS:
		var files: Dictionary[String, Vector2i] = _hr_files(dir)
		for file: String in files:
			var image: Image = _load_from(dir, file)
			assert_not_null(image, "%s%s missing" % [dir, file])
			if image != null:
				assert_eq(image.get_size(), files[file], "%s%s size" % [dir, file])


func test_hr_pairs_hard_alpha_and_palette_only() -> void:
	for dir: String in HR_PAIRS:
		for file: String in _hr_files(dir):
			var image: Image = _load_from(dir, file)
			if image == null:
				fail_test("%s%s missing" % [dir, file])
				continue
			var bad: Array[String] = _alpha_palette_problems(image)
			assert_eq(bad.size(), 0, "%s%s: %s" % [dir, file, ", ".join(bad.slice(0, 10))])


func test_hr_pairs_reserved_colours() -> void:
	for dir: String in HR_PAIRS:
		for file: String in _hr_files(dir):
			var colors: Dictionary[String, bool] = _colors_in(dir, file)
			for hex: String in [CANDY_YELLOW, STAMP_RED, ART_MOON]:
				assert_false(colors.has(hex), "%s%s uses %s" % [dir, file, hex])


func test_hr_pairs_no_zombie_green_where_copies_walk() -> void:
	for dir: String in HR_PAIRS:
		_assert_no_zombie_green_where_copies_walk(_load_from(dir, "field.png"),
				_load_from(dir, HR_PAIRS[dir]["house"]), dir)


func test_hr_pairs_field_is_opaque() -> void:
	for dir: String in HR_PAIRS:
		var field: Image = _load_from(dir, "field.png")
		if field == null:
			fail_test("%sfield.png missing" % dir)
			continue
		assert_eq(field.detect_alpha(), Image.ALPHA_NONE, "%sfield.png has no transparent pixels" % dir)


func test_hr_pairs_a_doorway_per_lane_on_the_feet_line() -> void:
	for dir: String in HR_PAIRS:
		_assert_a_doorway_per_lane(_load_from(dir, HR_PAIRS[dir]["house"]), _hr_wall(dir), dir)


func test_hr_pairs_import_settings_lossless_no_mipmaps() -> void:
	for dir: String in HR_PAIRS:
		for file: String in _hr_files(dir):
			_assert_pixel_crisp_import(dir + file)
