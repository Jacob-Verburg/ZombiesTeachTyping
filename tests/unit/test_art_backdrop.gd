extends GutTest
## Sunny Village Green backdrop art (Story 3.6, FR37, NFR13): layer and tile sizes, hard alpha,
## palette-only pixels, never candy-yellow or stamp-red, the in-world tag band free of the tag and arrow
## colours, the 640 px seam (a cheap heuristic: a clipped feature fails it, a wrapped one passes), the
## ground strip built from the tiles, and pixel-crisp import settings. Backdrop layers and ground tiles are
## exempt from the ink-outline rule only. Read from the committed PNG bytes (Image.load_from_file).
## Story 6.6 adds the Farmhouse layers (Horde Rush): static, never tiled (so no seam test), the same
## palette/alpha/colour rules, no zombie green in the lanes (a copy must never camouflage) and a doorway
## per lane on the farmhouse's field edge.

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
	var field: Image = _load_farm("field.png")
	var house: Image = _load_farm("farmhouse.png")
	if field == null or house == null:
		fail_test("farmhouse layers missing")
		return
	var lanes: Dictionary[String, bool] = _rect_colors(field,
			Rect2i(0, FARM_FIELD_TOP_Y, HOUSE_FRONT_X, field.get_height() - FARM_FIELD_TOP_Y))
	var front: Dictionary[String, bool] = _rect_colors(house,
			Rect2i(0, FARM_FIELD_TOP_Y, 8, house.get_height() - FARM_FIELD_TOP_Y))
	for hex: String in [ZOMBIE_GREEN, ZOMBIE_GREEN_BRIGHT]:
		assert_false(lanes.has(hex), "field lanes use %s" % hex)
		assert_false(front.has(hex), "farmhouse front uses %s" % hex)


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
	var house: Image = _load_farm("farmhouse.png")
	if house == null:
		fail_test("farmhouse.png missing")
		return
	for lane: int in FARM_LANE_COUNT:
		var bottom: int = _feet_y(lane) - 1
		for x: int in DOOR_COLUMNS:
			assert_false(_is_opening(house, x, bottom + 1),
					"lane %d column %d: the opening runs past the feet line" % [lane, x])
			var run: int = 0
			while bottom - run >= 0 and _is_opening(house, x, bottom - run):
				run += 1
			assert_true(run >= DOOR_MIN_H, "lane %d column %d: opening %d px tall, want >= %d" % [
					lane, x, run, DOOR_MIN_H])


## An opening pixel is opaque and not a wall colour.
func _is_opening(image: Image, x: int, y: int) -> bool:
	var color: Color = image.get_pixel(x, y)
	return color.a8 == 255 and not _is_wall(image, x, y)


func _is_wall(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).to_html(false) in WALL_COLOURS


func test_farmhouse_import_settings_lossless_no_mipmaps() -> void:
	for file: String in FARM_FILES:
		var config: ConfigFile = ConfigFile.new()
		var err: Error = config.load(FARM_DIR + file + ".import")
		assert_eq(err, OK, "%s.import missing" % file)
		if err != OK:
			continue
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % file)
		assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % file)
