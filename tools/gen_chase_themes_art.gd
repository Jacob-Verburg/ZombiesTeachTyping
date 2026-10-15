extends SceneTree
## Dev-only: writes the Story 10.4 Pitchfork Panic settings (FR74, FR76): Cornfield Path (a farm track
## between the corn at sunset) and Spooky Forest Bridge (a plank bridge over a creek, at night under friendly
## trees), each a full parallax set (clouds, far, near, the ground tiles and the ground strip) in its own
## folder, and each setting's escape cover (FR73): the haystack and the hollow log, 48x48, 3 frames, with the
## escape bush's exact contract (frame 0 still, frames 1-2 rustled with bits popping off, standing on row 46).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_chase_themes_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Drawn on the Moonlit Village recipe (tools/gen_pitchfork_panic_art.gd, Story 8.6): shapes (rects,
## triangles, discs) at fixed, hard-coded positions, no RNG, so a rerun writes the same bytes. Every shape
## wraps around x (it is drawn at posmod(x, 640)), so each 640 px layer tiles with no seam, and the features
## that cross the seam are centred on it (x = 0) and mirror-symmetric on purpose; _check_seam fails the run
## otherwise. That tool's layout consts are read by preload; its helpers are copied, not shared (SceneTree
## instance methods can't be, and its PNGs must stay byte-identical). The palette is read from
## tools/gen_art_prototypes.gd (one source).
##
## The covers are painted as fills only (no ink), then grown a 1 px ink outline (_outline), so every non-ink
## pixel has four opaque neighbours (the outline rule) and the bits popping off are outlined too. Backdrops
## are exempt from the ink-outline rule only: palette colours, hard alpha, and never candy-yellow (the end
## labels and focus), stamp-red (the stamp) or art-moon (the moon): _color fails the run on any of them.
## The chase readability band: near.png rows 160-191 (where the characters' legs and bodies pass) are fully
## opaque and use none of ink, night, zombie-green, zombie-green-bright, bat-purple, art-brain-pink or
## art-brain-shade, and the ground strip's top 4 rows use none of those nor wood or wood-dark (the zombie's
## trousers and shoes), so the zombie's outline, skin and shirt, the mob and the brains always stand out.
## The ground strip is composed from ground_tiles.png with a hard-coded index map: row 0 (the walking path)
## only the setting's path tiles, every tile used. Each setting carries a pumpkin and bat-purple (D6).
## Rules: docs/art-style-sheet.md; tests: test_art_backdrop.gd, test_art_sprites.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")
const Chase := preload("res://tools/gen_pitchfork_panic_art.gd")

const CORN_DIR: String = "res://assets/sprites/backdrops/cornfield_path"
const FOREST_DIR: String = "res://assets/sprites/backdrops/spooky_forest_bridge"
const PROPS_DIR: String = "res://assets/sprites/props"
const HAYSTACK_PATH: String = PROPS_DIR + "/escape_haystack.png"
const LOG_PATH: String = PROPS_DIR + "/escape_hollow_log.png"

const PERIOD: int = Chase.PERIOD
const LAYER_H: int = Chase.LAYER_H
const GROUND_ROWS: int = Chase.GROUND_ROWS
const TILE: int = Chase.TILE
const BAND_TOP: int = Chase.BAND_TOP
const EFFECT_FRAME: int = Chase.EFFECT_FRAME
## The covers stand on this row (the bush's contract): fills end on row 45, the ink outline on row 46.
const COVER_GROUND_ROW: int = 46
const COVER_FRAMES: int = 3
## The path rows checked in the strip (its top 4 px rows, under the feet).
const PATH_ROWS: int = 4
const RESERVED: Array[String] = ["candy-yellow", "stamp-red", "art-moon"]
const CHASE_BAND_FORBIDDEN: Array[String] = [
	"ink", "night", "zombie-green", "zombie-green-bright", "bat-purple", "art-brain-pink", "art-brain-shade",
]
const PATH_FORBIDDEN_EXTRA: Array[String] = ["wood", "wood-dark"]
const DRESSING: Array[String] = ["pumpkin", "bat-purple"]

## A friendly little bat, 9 x 4, with two chalk eyes.
const BAT: Array[String] = [
	"b.......b",
	"bb.b.b.bb",
	".bcbbbcb.",
	"..b...b..",
]
const BAT_LEGEND: Dictionary[String, String] = {"b": "bat-purple", "c": "chalk"}

# --- Cornfield Path: a farm track between tall corn at sunset ---

## Packed dirt, dirt with a straw wisp, dirt with a pebble (the path tiles), and field soil with corn stubble.
const CORN_GROUND_LEGEND: Dictionary[String, String] = {
	"d": "parchment-shade",
	"f": "ink-faded",
	"s": "wood-light",
	"p": "stone-light",
	"q": "stone",
	"w": "wood",
	"m": "wood-dark",
	"g": "zombie-green-dark",
	"a": "art-grass",
}

const CORN_TILE_DIRT: Array[String] = [
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddfdddddddddddd",
	"dddddddddddfdddd",
	"dddddddddddddddd",
	"dddddddfdddddddd",
	"dddddddddddddddd",
	"ddfddddddddddfdd",
	"dddddddddddddddd",
	"dddddddddfdddddd",
	"dddddddddddddddd",
	"ddddfddddddddddd",
	"ddddddddddddfddd",
	"dddddddddddddddd",
	"ddddddddfddddddd",
	"dddddddddddddddd",
]

const CORN_TILE_STRAW: Array[String] = [
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"ddddsssddddddddd",
	"dddddddssddddddd",
	"dddddddddssdfddd",
	"dddddddddddddddd",
	"ddfddddddddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"ddddddddddsssddd",
	"dddddssssssddddd",
	"dddddddddddddddd",
	"ddddddddddddfddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
]

const CORN_TILE_PEBBLE: Array[String] = [
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddddddddddfdddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddddpppdddddddd",
	"ddddpppppddddddd",
	"ddddqpppqddddddd",
	"dddddqqqdddddddd",
	"dddddddddddddddd",
	"ddfddddddddddddd",
	"dddddddddddpdddd",
	"ddddddddddpqdddd",
	"dddddddddddddddd",
	"dddddddfdddddddd",
	"dddddddddddddddd",
]

const CORN_TILE_STUBBLE: Array[String] = [
	"wwwwwwwwwwwwwwww",
	"wwwwwwwwwwwwwwww",
	"wwgwwwwwwwagwwww",
	"wwgawwwwwwgwwwww",
	"wwgwwwwmwwgwwwww",
	"wwmmwwwwwwmmwwww",
	"wwwwwwwwwwwwwwww",
	"wwwwwwagwwwwwwww",
	"wwwwwwgwwwwwwgww",
	"wwwmwwgawwwwwgaw",
	"wwwwwwmmwwwwwgww",
	"wwwwwwwwwwwwwmmw",
	"wwgwwwwwwwwwwwww",
	"wwgawwwwwwwmwwww",
	"wwmmwwwwwwwwwwww",
	"wwwwwwwwwwwwwwww",
]

const CORN_TILES: Array = [CORN_TILE_DIRT, CORN_TILE_STRAW, CORN_TILE_PEBBLE, CORN_TILE_STUBBLE]
## The tiles the walking path (row 0) may use: plain dirt, straw and pebble.
const CORN_PATH_TILES: String = "012"
## Row 0 the track, rows 1-3 the field soil with stubble.
const CORN_GROUND_MAP: Array[String] = [
	"0010002000100000200100002000010002000010",
	"3333333333333333333333333333333333333333",
	"3333333333333333333333333333333333333333",
	"3333333333333333333333333333333333333333",
]

## Sunset sky in the clouds layer: horizontal bands from these rows down (dusk Sky above them).
const SUNSET_PURPLE_Y: int = 96
const SUNSET_ORANGE_Y: int = 106
const SUNSET_GLOW_Y: int = 114
## Long thin sunset clouds: [centre x, y, length]. The first is centred on the seam (x 0) on purpose.
const CORN_STREAKS: Array[Vector3i] = [
	Vector3i(0, 82, 60),
	Vector3i(150, 64, 44),
	Vector3i(290, 88, 72),
	Vector3i(470, 70, 52),
]
## First stars high up (above y 60): count, rows.
const CORN_STAR_COUNT: int = 14
const CORN_STAR_TOP_Y: int = 44
const CORN_STAR_BOTTOM_Y: int = 60

## Far hills: a crest around this row, a peak at the seam (two cosines of whole periods).
const CORN_HILL_BASE_Y: float = 120.0
const CORN_HILL_A_PX: float = 5.0
const CORN_HILL_B_PX: float = 3.0
const CORN_BARN_X: int = 210
const CORN_SILO_X: int = 230
const CORN_FARMHOUSE_X: int = 520
## The distant pumpkin patch: [from x, to x) on the hill face.
const CORN_PATCHES: Array[Vector2i] = [Vector2i(40, 150), Vector2i(330, 460)]
const CORN_PATCH_STEP: int = 9
const CORN_BATS: Array[Vector2i] = [Vector2i(120, 104), Vector2i(380, 100), Vector2i(600, 108)]

## The corn wall: a dark mass from CORN_BACK_TOP, plants every CORN_STEP px (the first CORN_STEP from the
## seam; the seam plant is drawn mirror-symmetric on x 0), each top 0..CORN_TOP_SPREAD-1 px under CORN_TOP_Y.
const CORN_BACK_TOP: int = 146
const CORN_STEP: int = 10
const CORN_TOP_Y: int = 122
const CORN_TOP_SPREAD: int = 17
const CORN_LEAF_STEP: int = 9
const CORN_SOIL_TOP: int = 188
## The split-rail fence along the track: rails at these rows, posts every 64 px from x 32.
const CORN_RAILS: Array[int] = [168, 178]
const CORN_POST_FIRST: int = 32
const CORN_POST_STEP: int = 64
const CORN_POST_TOP: int = 164
const CORN_SCARECROW_X: int = 300
## Pumpkins at the foot of the corn: [centre x, centre y, radius]. The first sits on the seam.
const CORN_PUMPKINS: Array[Vector3i] = [
	Vector3i(0, 186, 4), Vector3i(142, 185, 5), Vector3i(155, 187, 3), Vector3i(424, 186, 4),
	Vector3i(536, 185, 5),
]

# --- Spooky Forest Bridge: a plank bridge over a creek, at night under friendly trees ---

## Bridge plank, plank with a knot (the path tiles), creek water, and reeds and stones in the creek.
const FOREST_GROUND_LEGEND: Dictionary[String, String] = {
	"l": "wood-light",
	"h": "parchment-shade",
	"n": "stone-light",
	"f": "ink-faded",
	"w": "wood",
	"m": "wood-dark",
	"d": "dusk",
	"s": "art-sky",
	"c": "art-sky-light",
	"g": "zombie-green-dark",
	"a": "art-grass",
	"q": "stone",
}

const FOREST_TILE_PLANK: Array[String] = [
	"hhhhhhhhhhhhhhhh",
	"llllllllllllllll",
	"lllllllfllllllll",
	"lnllllllflllllll",
	"lllllllflhllllll",
	"llllllllflllllll",
	"lllhlllflllllnll",
	"llllllllflllllll",
	"lllllllflllllhll",
	"ffffffffffffffff",
	"wwwwwwwwwwwwwwww",
	"wwwmmmwwwwwwwwww",
	"wwwwwwwwwwmmmmww",
	"wwwwwwwwwwwwwwww",
	"mmmmmmmmmmmmmmmm",
	"dddddddddddddddd",
]

const FOREST_TILE_KNOT: Array[String] = [
	"hhhhhhhhhhhhhhhh",
	"llllllllllllllll",
	"llllllllllllllll",
	"lllllfffllllllll",
	"llllfllhflllllll",
	"llllfllhflllllll",
	"lllllffflllllnll",
	"llllllllllllllll",
	"lhllllllllllllll",
	"ffffffffffffffff",
	"wwwwwwwwwwwwwwww",
	"wwwwwwwwwmmmwwww",
	"wwmmmmwwwwwwwwww",
	"wwwwwwwwwwwwwwww",
	"mmmmmmmmmmmmmmmm",
	"dddddddddddddddd",
]

const FOREST_TILE_WATER: Array[String] = [
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddssssddddddddd",
	"dddddddddddddddd",
	"dddddddddddcdddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"ddddddddddssssdd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"ddcddddddddddddd",
	"dddddddddddddddd",
	"ddddddsssddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
]

const FOREST_TILE_REEDS: Array[String] = [
	"dddddddddddddddd",
	"ddddddddddddagdd",
	"ddagddddddddgddd",
	"dddgdddddddagddd",
	"dddgaddddddgdddd",
	"dddgdddddddgdddd",
	"dddgddddddqgqddd",
	"ddqgqddddqqqqqdd",
	"dqqqqqdddddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"ddddddddsssddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
	"dddddddddddddddd",
]

const FOREST_TILES: Array = [FOREST_TILE_PLANK, FOREST_TILE_KNOT, FOREST_TILE_WATER, FOREST_TILE_REEDS]
## The tiles the walking path (row 0) may use: the planks. Rows 1-3 are the creek under the bridge.
const FOREST_PATH_TILES: String = "01"
const FOREST_GROUND_MAP: Array[String] = [
	"0001000010000000100000010000001000000100",
	"2223222222322222223222222232222222322222",
	"2222232222222232222222232222222322222232",
	"3222222223222222222322222222223222222222",
]

## Night clouds (dusk puffs): [centre x, bottom y, puff size]. The first is centred on the seam on purpose.
const FOREST_CLOUDS: Array[Vector3i] = [
	Vector3i(0, 50, 6),
	Vector3i(230, 38, 5),
	Vector3i(420, 58, 7),
]
const FOREST_STAR_COUNT: int = 30
const FOREST_STAR_TOP_Y: int = 44
const FOREST_STAR_BOTTOM_Y: int = 92
## Fireflies (pumpkin-light dots, never candy-yellow or art-moon) in the upper sky only.
const FOREST_FIREFLY_COUNT: int = 12
const FOREST_FIREFLY_TOP_Y: int = 60
const FOREST_FIREFLY_BOTTOM_Y: int = 100

## Far woods: rows of rounded tree tops (back to front), each a crest of discs every `step` px.
const FOREST_FAR_ROWS: Array[Dictionary] = [
	{"y": 104, "r": 14, "step": 24, "colour": "dusk"},
	{"y": 122, "r": 12, "step": 20, "colour": "ink-muted"},
	{"y": 138, "r": 10, "step": 16, "colour": "zombie-green-dark"},
]
## The owl sits on the back row's tree top at this x (its feet on that crest).
const FOREST_OWL_X: int = 336
const FOREST_BATS: Array[Vector2i] = [Vector2i(90, 74), Vector2i(270, 86), Vector2i(500, 70)]

## Near trees: [trunk centre x, trunk width]. The first is centred on the seam on purpose.
const FOREST_TREES: Array[Vector2i] = [
	Vector2i(0, 20), Vector2i(170, 16), Vector2i(300, 22), Vector2i(470, 18),
]
## Canopy discs over each trunk: [dx, cy, r]; mirrored dx keeps the seam tree symmetric.
const FOREST_CANOPY: Array[Vector3i] = [
	Vector3i(0, 6, 34), Vector3i(-30, 24, 20), Vector3i(30, 24, 20),
]
## The bridge's far handrail along the band: a top rail, a lower rail, posts every 40 px from x 20.
const FOREST_RAIL_TOP: int = 163
const FOREST_RAIL_LOW: int = 176
const FOREST_POST_FIRST: int = 20
const FOREST_POST_STEP: int = 40
## A jack-o'-lantern on a stump (bottom row FOREST_STUMP_TOP, well above the zombie's crown).
const FOREST_STUMP_X: int = 392
const FOREST_STUMP_TOP: int = 138
## Toadstools by the rail: [x, cap row].
const FOREST_TOADSTOOLS: Array[Vector2i] = [
	Vector2i(110, 180), Vector2i(118, 183), Vector2i(236, 181), Vector2i(560, 180), Vector2i(572, 184),
]
## Stones on the bank: [centre x, centre y, radius].
const FOREST_STONES: Array[Vector3i] = [Vector3i(60, 188, 4), Vector3i(350, 189, 3), Vector3i(522, 188, 5)]

var _ok: bool = true


func _init() -> void:
	for legend: Dictionary[String, String] in [CORN_GROUND_LEGEND, FOREST_GROUND_LEGEND, BAT_LEGEND]:
		for key: String in legend:
			_color(legend[key])
	var errors: Array[Error] = [DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROPS_DIR))]
	errors.append(_save(_cover_sheet(_haystack_frame), HAYSTACK_PATH))
	errors.append(_save(_cover_sheet(_log_frame), LOG_PATH))
	errors.append_array(_write_theme(CORN_DIR, CORN_TILES, CORN_GROUND_LEGEND, CORN_GROUND_MAP, CORN_PATH_TILES,
			[_corn_clouds(), _corn_far(), _corn_near()]))
	errors.append_array(_write_theme(FOREST_DIR, FOREST_TILES, FOREST_GROUND_LEGEND, FOREST_GROUND_MAP,
			FOREST_PATH_TILES, [_forest_clouds(), _forest_far(), _forest_near()]))
	# Non-zero exit on any failure, so a bad map, colour, seam, band, path or cwd doesn't look like success.
	quit(0 if _ok and errors.all(func(err: Error) -> bool: return err == OK) else 1)


## Writes one setting's five files; layers are [clouds, far, near]. Checks the seams, the chase readability
## band, the path rows and the Halloween dressing.
func _write_theme(dir: String, tiles: Array, legend: Dictionary[String, String], map: Array[String],
		path_tiles: String, layers: Array[Image]) -> Array[Error]:
	var errors: Array[Error] = [DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))]
	var tiles_image: Image = _tiles_image(tiles, legend)
	errors.append(_save(tiles_image, dir + "/ground_tiles.png") if tiles_image != null else ERR_INVALID_DATA)
	var strip: Image = _ground_strip(tiles_image, tiles.size(), map, path_tiles) if tiles_image != null else null
	if strip != null:
		_check_seam(strip, dir + "/ground_strip.png")
		var path_forbidden: Array[String] = CHASE_BAND_FORBIDDEN.duplicate()
		path_forbidden.append_array(PATH_FORBIDDEN_EXTRA)
		_check_band(strip, 0, PATH_ROWS, path_forbidden, dir + "/ground_strip.png path rows")
	errors.append(_save(strip, dir + "/ground_strip.png") if strip != null else ERR_INVALID_DATA)
	var names: Array[String] = ["clouds.png", "far.png", "near.png"]
	for i: int in names.size():
		_check_seam(layers[i], dir + "/" + names[i])
		errors.append(_save(layers[i], dir + "/" + names[i]))
	_check_opaque(layers[2], BAND_TOP, LAYER_H, dir + "/near.png band")
	_check_band(layers[2], BAND_TOP, LAYER_H, CHASE_BAND_FORBIDDEN, dir + "/near.png band")
	for colour: String in DRESSING:
		if not (_uses(layers[1], colour) or _uses(layers[2], colour)):
			push_error("%s: no %s in the near or far layer" % [dir, colour])
			_ok = false
	return errors


func _color(color_name: String) -> Color:
	if color_name in RESERVED or not Proto.PALETTE.has(color_name):
		push_error("colour '%s' is reserved or not on the palette" % color_name)
		_ok = false
		return Color(0, 0, 0, 0)
	return Color.html(Proto.PALETTE[color_name])


## Fails the run when x 0 and x 639 differ in opacity on any row, or nothing crosses the seam.
func _check_seam(image: Image, label: String) -> void:
	var crossing: int = 0
	for y: int in image.get_height():
		var left: bool = image.get_pixel(0, y).a8 == 255
		if left != (image.get_pixel(PERIOD - 1, y).a8 == 255):
			push_error("%s: seam row %d" % [label, y])
			_ok = false
		elif left:
			crossing += 1
	if crossing == 0:
		push_error("%s: nothing crosses the seam" % label)
		_ok = false


## Fails the run when rows [from_y, to_y) use any of the colours.
func _check_band(image: Image, from_y: int, to_y: int, colours: Array[String], label: String) -> void:
	var hexes: Dictionary[String, String] = {}
	for color_name: String in colours:
		hexes[Proto.PALETTE[color_name]] = color_name
	var bad: int = 0
	for y: int in range(from_y, mini(to_y, image.get_height())):
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 == 255 and hexes.has(color.to_html(false)):
				if bad == 0:
					push_error("%s: %s at (%d,%d)" % [label, hexes[color.to_html(false)], x, y])
				bad += 1
	if bad > 0:
		push_error("%s: %d forbidden pixels" % [label, bad])
		_ok = false


## Fails the run when any pixel in rows [from_y, to_y) is not fully opaque.
func _check_opaque(image: Image, from_y: int, to_y: int, label: String) -> void:
	for y: int in range(from_y, to_y):
		for x: int in image.get_width():
			if image.get_pixel(x, y).a8 != 255:
				push_error("%s: hole at (%d,%d)" % [label, x, y])
				_ok = false
				return


func _uses(image: Image, color_name: String) -> bool:
	var hex: String = Proto.PALETTE[color_name]
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 == 255 and color.to_html(false) == hex:
				return true
	return false


## One horizontal strip of 16 x 16 tiles. Returns null (after push_error) on a bad map.
func _tiles_image(tiles: Array, legend: Dictionary[String, String]) -> Image:
	var image: Image = Image.create_empty(tiles.size() * TILE, TILE, false, Image.FORMAT_RGBA8)
	for i: int in tiles.size():
		var rows: Array[String] = tiles[i]
		if rows.size() != TILE:
			push_error("tile %d: %d rows, want %d" % [i, rows.size(), TILE])
			return null
		for y: int in TILE:
			var row: String = rows[y]
			if row.length() != TILE:
				push_error("tile %d row %d: %d chars, want %d" % [i, y, row.length(), TILE])
				return null
			for x: int in TILE:
				if not legend.has(row[x]):
					push_error("tile %d (%d,%d): '%s' not in legend" % [i, x, y, row[x]])
					return null
				image.set_pixel(i * TILE + x, y, _color(legend[row[x]]))
	return image


## 640 x 64, each 16 x 16 cell copied from the tiles by the map (no randomness). Row 0 only the path tiles;
## every tile is used.
func _ground_strip(tiles: Image, count: int, map: Array[String], path_tiles: String) -> Image:
	var image: Image = Image.create_empty(PERIOD, GROUND_ROWS * TILE, false, Image.FORMAT_RGBA8)
	if map.size() != GROUND_ROWS:
		push_error("ground map has %d rows, want %d" % [map.size(), GROUND_ROWS])
		return null
	var used: Dictionary[int, bool] = {}
	for row: int in GROUND_ROWS:
		var line: String = map[row]
		if line.length() != PERIOD / TILE:
			push_error("ground map row %d: %d tiles, want %d" % [row, line.length(), PERIOD / TILE])
			return null
		for col: int in line.length():
			var index: int = line[col].to_int()
			if not line[col].is_valid_int() or index < 0 or index >= count \
					or (row == 0 and not path_tiles.contains(line[col])):
				push_error("ground map (%d,%d): tile '%s'" % [col, row, line[col]])
				return null
			used[index] = true
			image.blit_rect(tiles, Rect2i(index * TILE, 0, TILE, TILE), Vector2i(col * TILE, row * TILE))
	if used.size() != count:
		push_error("ground map uses %d of %d tiles" % [used.size(), count])
		return null
	return image


# --- shape helpers: every x wraps around PERIOD ---

func _layer() -> Image:
	return Image.create_empty(PERIOD, LAYER_H, false, Image.FORMAT_RGBA8)


func _put(image: Image, x: int, y: int, color_name: String) -> void:
	if y < 0 or y >= image.get_height():
		return
	image.set_pixel(posmod(x, PERIOD), y, _color(color_name))


func _rect(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_put(image, xx, yy, color_name)


## A rect with a 1 px border in `edge`.
func _box(image: Image, x: int, y: int, w: int, h: int, color_name: String, edge: String = "ink") -> void:
	_rect(image, x, y, w, h, edge)
	_rect(image, x + 1, y + 1, w - 2, h - 2, color_name)


## An even-width disc centred on the pixel boundary at cx (columns cx - h .. cx + h - 1), rows
## cy - r .. cy + r - 1. Centred on x 0, it is mirror-symmetric across the seam.
func _blob(image: Image, cx: int, cy: int, r: int, color_name: String) -> void:
	for dy: int in range(-r, r):
		var yc: float = dy + 0.5
		var h: int = maxi(1, roundi(sqrt(maxf(0.0, r * r - yc * yc))))
		for x: int in range(cx - h, cx + h):
			_put(image, x, cy + dy, color_name)


## A triangle with its apex at (cx, top), widening by 1 px each side per row, down to `bottom`.
func _roof(image: Image, cx: int, top: int, bottom: int, color_name: String) -> void:
	for y: int in range(top, bottom):
		var half: int = y - top + 1
		for x: int in range(cx - half, cx + half):
			_put(image, x, y, color_name)


## An ASCII map at (x, y): '.' = leave, any other character through the legend.
func _stamp(image: Image, rows: Array[String], legend: Dictionary[String, String], x: int, y: int) -> void:
	for row: int in rows.size():
		for col: int in rows[row].length():
			var ch: String = rows[row][col]
			if ch != ".":
				_put(image, x + col, y + row, legend[ch])


## Moonlit's puffy cloud: a flat base and three discs.
func _cloud(image: Image, cloud: Vector3i, color_name: String) -> void:
	var s: int = cloud.z
	_rect(image, cloud.x - 2 * s, cloud.y - s, 4 * s, s, color_name)
	_blob(image, cloud.x - s, cloud.y - s, s, color_name)
	_blob(image, cloud.x + s, cloud.y - s, s, color_name)
	_blob(image, cloud.x, cloud.y - s - s / 2, s + 2, color_name)


## A crest line of two cosines with whole periods across 640 px and a peak on the seam.
func _hill_y(x: int, base: float, a: float, ka: int, b: float, kb: int) -> int:
	var t: float = TAU * x / PERIOD
	return roundi(base - a * cos(ka * t) - b * cos(kb * t))


## Stars at fixed, spread positions (a fixed stride, no RNG), never on the seam columns.
func _stars(image: Image, count: int, top: int, bottom: int, stride_x: int, stride_y: int, color_name: String) -> void:
	for i: int in count:
		var x: int = (i * stride_x + 23) % PERIOD
		if x == 0 or x == PERIOD - 1:
			x = 2
		var y: int = top + (i * stride_y) % (bottom - top)
		_put(image, x, y, color_name)


## A pumpkin for the band (no ink there): a wood-dark rim, a pumpkin-light shine and an art-grass stem.
func _band_pumpkin(image: Image, p: Vector3i) -> void:
	_blob(image, p.x, p.y, p.z + 1, "wood-dark")
	_blob(image, p.x, p.y, p.z, "pumpkin")
	_rect(image, p.x - p.z / 2 - 1, p.y - p.z + 2, 1, maxi(1, p.z - 2), "pumpkin-light")
	_rect(image, p.x - 1, p.y - p.z - 3, 2, 2, "art-grass")


## A friendly jack-o'-lantern (14 x 14), its bottom ink row on `bottom`: pumpkin with a pumpkin-light shine,
## a wood-dark smiling face and a green stem (Moonlit's, unchanged).
func _jack_o_lantern(image: Image, cx: int, bottom: int) -> void:
	var cy: int = bottom - 6
	_blob(image, cx, cy, 7, "ink")
	_blob(image, cx, cy, 6, "pumpkin")
	_rect(image, cx - 4, cy - 4, 2, 3, "pumpkin-light")
	_rect(image, cx - 1, cy - 9, 2, 3, "ink")
	_rect(image, cx - 1, cy - 8, 1, 2, "zombie-green-dark")
	for side: int in [-3, 1]:
		_rect(image, cx + side, cy - 2, 2, 1, "wood-dark")
		_put(image, cx + side + (1 if side < 0 else 0), cy - 3, "wood-dark")
	_rect(image, cx - 3, cy + 1, 6, 1, "wood-dark")
	_put(image, cx - 4, cy, "wood-dark")
	_put(image, cx + 3, cy, "wood-dark")
	_put(image, cx - 1, cy + 2, "wood-dark")


# --- Cornfield Path ---

## The sunset in bands (bat-purple, pumpkin, then the pumpkin-light glow down to the hills; one dithered row
## at each change), long thin sunset streaks and a few first stars high up.
func _corn_clouds() -> Image:
	var image: Image = _layer()
	_stars(image, CORN_STAR_COUNT, CORN_STAR_TOP_Y, CORN_STAR_BOTTOM_Y, 157, 7, "chalk")
	var bands: Array[Array] = [
		[SUNSET_PURPLE_Y, "bat-purple"], [SUNSET_ORANGE_Y, "pumpkin"], [SUNSET_GLOW_Y, "pumpkin-light"],
	]
	for i: int in bands.size():
		var top: int = bands[i][0]
		var bottom: int = bands[i + 1][0] if i + 1 < bands.size() else LAYER_H
		_rect(image, 0, top, PERIOD, bottom - top, bands[i][1])
		# Dithered every other pair of columns (x % 4 in 0, 3), mirror-symmetric across the seam.
		for x: int in PERIOD:
			if x % 4 == 0 or x % 4 == 3:
				_put(image, x, top - 1, bands[i][1])
	for streak: Vector3i in CORN_STREAKS:
		var half: int = streak.z / 2
		_rect(image, streak.x - half, streak.y, 2 * half, 2, "pumpkin")
		_rect(image, streak.x - half + 3, streak.y + 2, 2 * half - 6, 1, "pumpkin-light")
		_rect(image, streak.x - half + 6, streak.y - 1, 2 * half - 12, 1, "bat-purple")
	return image


func _corn_hill_y(x: int) -> int:
	return _hill_y(x, CORN_HILL_BASE_Y, CORN_HILL_A_PX, 2, CORN_HILL_B_PX, 3)


## Rolling hills in ink-muted silhouette against the glow, a dusk crest line, a barn, a silo and a farmhouse
## as night silhouettes with lit pumpkin-light windows (no windmill: that is the Moonlit Village's), a
## distant pumpkin patch on the hill face, and friendly bats over the glow.
func _corn_far() -> Image:
	var image: Image = _layer()
	for x: int in PERIOD:
		var top: int = _corn_hill_y(x)
		_rect(image, x, top, 1, LAYER_H - top, "ink-muted")
		_put(image, x, top, "dusk")
	for patch: Vector2i in CORN_PATCHES:
		for x: int in range(patch.x, patch.y, CORN_PATCH_STEP):
			for row: int in 3:
				var px: int = x + (row % 2) * CORN_PATCH_STEP / 2
				var py: int = _corn_hill_y(px) + 6 + row * 6
				_rect(image, px, py, 2, 2, "pumpkin")
				_put(image, px, py - 1, "zombie-green-dark")
	# The barn: a gambrel-ish roof (a triangle on a box) with a lit loft window and doors.
	var ground: int = _corn_hill_y(CORN_BARN_X) + 2
	_rect(image, CORN_BARN_X - 9, ground - 13, 18, 13, "night")
	_roof(image, CORN_BARN_X, ground - 22, ground - 13, "night")
	_rect(image, CORN_BARN_X - 1, ground - 17, 2, 2, "pumpkin-light")
	_rect(image, CORN_BARN_X - 3, ground - 8, 6, 8, "ink-muted")
	_rect(image, CORN_BARN_X, ground - 8, 1, 8, "night")
	# The silo: a tower with a dome.
	var silo_ground: int = _corn_hill_y(CORN_SILO_X) + 2
	_rect(image, CORN_SILO_X - 3, silo_ground - 22, 6, 22, "night")
	_blob(image, CORN_SILO_X, silo_ground - 22, 3, "night")
	# The farmhouse: a cottage with two lit windows and a chimney.
	var house_ground: int = _corn_hill_y(CORN_FARMHOUSE_X) + 2
	_rect(image, CORN_FARMHOUSE_X - 8, house_ground - 10, 16, 10, "night")
	_roof(image, CORN_FARMHOUSE_X, house_ground - 17, house_ground - 10, "night")
	_rect(image, CORN_FARMHOUSE_X + 3, house_ground - 19, 3, 6, "night")
	_rect(image, CORN_FARMHOUSE_X - 5, house_ground - 7, 2, 2, "pumpkin-light")
	_rect(image, CORN_FARMHOUSE_X + 3, house_ground - 7, 2, 2, "pumpkin-light")
	for bat: Vector2i in CORN_BATS:
		_stamp(image, BAT, BAT_LEGEND, bat.x - 4, bat.y - 2)
	return image


## The corn wall over a dark mass (fully covering the band), the dark soil at its feet, a split-rail fence
## along the track, a smiling scarecrow and pumpkins at the foot of the corn.
func _corn_near() -> Image:
	var image: Image = _layer()
	_rect(image, 0, CORN_BACK_TOP, PERIOD, LAYER_H - CORN_BACK_TOP, "zombie-green-dark")
	_corn_plant(image, 0, CORN_TOP_Y + 4, true)
	for i: int in range(1, PERIOD / CORN_STEP):
		var top: int = CORN_TOP_Y + (i * 7) % CORN_TOP_SPREAD
		_corn_plant(image, i * CORN_STEP, top, false)
	_rect(image, 0, CORN_SOIL_TOP, PERIOD, LAYER_H - CORN_SOIL_TOP, "ink-muted")
	for x: int in range(0, PERIOD, 5):
		_put(image, x + 2, CORN_SOIL_TOP, "stone")
	_scarecrow(image, CORN_SCARECROW_X)
	_corn_fence(image)
	for pumpkin: Vector3i in CORN_PUMPKINS:
		_band_pumpkin(image, pumpkin)
	return image


## A corn plant: a zombie-green-dark stalk (columns cx - 1, cx) from `top` down, a wood-light tassel, art-grass
## leaves arching out (alternating sides; both sides when `mirrored`, so a plant on x 0 is symmetric across the
## seam) and, above the band only, a parchment-shade cob in wood-light husks.
func _corn_plant(image: Image, cx: int, top: int, mirrored: bool) -> void:
	_rect(image, cx - 1, top, 2, LAYER_H - top, "zombie-green-dark")
	_rect(image, cx - 1, top - 3, 2, 3, "wood-light")
	_put(image, cx - 2, top - 2, "wood-light")
	_put(image, cx + 1, top - 2, "wood-light")
	var side: int = 1 if (cx / CORN_STEP) % 2 == 0 else -1
	var y: int = top + 6
	while y < CORN_SOIL_TOP - 2:
		for s: int in ([-1, 1] if mirrored else [side]):
			_corn_leaf(image, cx, y, s)
		side = -side
		y += CORN_LEAF_STEP
	var cob_y: int = top + 12
	if cob_y + 8 < BAND_TOP:
		for s: int in ([-1, 1] if mirrored else [-side]):
			var x0: int = cx + 1 if s > 0 else cx - 4
			_rect(image, x0, cob_y + 1, 3, 6, "wood-light")
			_rect(image, x0 + (1 if s > 0 else 0), cob_y, 2, 6, "parchment-shade")


## One leaf: out 6 px from the stalk on `side`, rising 2 px then drooping, art-grass over a zombie-green-dark
## underside.
func _corn_leaf(image: Image, cx: int, y: int, side: int) -> void:
	for i: int in range(1, 7):
		var x: int = cx + i - 1 if side > 0 else cx - i
		var dy: int = -mini(i, 2) + maxi(0, i - 4)
		_put(image, x, y + dy, "art-grass")
		_put(image, x, y + dy + 1, "zombie-green-dark")


## Two wood-light rails with a wood underside across the width, wood-light posts with wood sides every 64 px.
func _corn_fence(image: Image) -> void:
	for rail_y: int in CORN_RAILS:
		_rect(image, 0, rail_y, PERIOD, 2, "wood-light")
		_rect(image, 0, rail_y + 2, PERIOD, 1, "wood")
	for x: int in range(CORN_POST_FIRST, PERIOD, CORN_POST_STEP):
		_rect(image, x, CORN_POST_TOP, 4, CORN_SOIL_TOP - CORN_POST_TOP, "wood")
		_rect(image, x + 1, CORN_POST_TOP + 1, 2, CORN_SOIL_TOP - CORN_POST_TOP - 1, "wood-light")


## A smiling scarecrow on a post: a wood-dark hat with a pumpkin band, a burlap face with button eyes and a
## plain smile, a bat-purple shirt with a wood patch, straw at the cuffs and hem. All above the band (only the
## wood post goes down into it).
func _scarecrow(image: Image, cx: int) -> void:
	_rect(image, cx - 1, 128, 2, CORN_SOIL_TOP - 128, "wood")
	_rect(image, cx - 14, 134, 28, 2, "wood")
	_rect(image, cx - 17, 133, 3, 4, "wood-light")
	_rect(image, cx + 14, 133, 3, 4, "wood-light")
	_box(image, cx - 8, 130, 16, 20, "bat-purple")
	_rect(image, cx + 2, 139, 4, 4, "wood")
	_rect(image, cx - 6, 150, 2, 2, "wood-light")
	_rect(image, cx - 1, 150, 2, 3, "wood-light")
	_rect(image, cx + 4, 150, 2, 2, "wood-light")
	_blob(image, cx, 122, 7, "ink")
	_blob(image, cx, 122, 6, "parchment-shade")
	_rect(image, cx - 3, 120, 1, 1, "ink")
	_rect(image, cx + 2, 120, 1, 1, "ink")
	for x: int in range(cx - 3, cx + 3):
		_put(image, x, 125, "ink")
	_put(image, cx - 4, 124, "ink")
	_put(image, cx + 3, 124, "ink")
	_rect(image, cx - 9, 115, 18, 2, "wood-dark")
	_rect(image, cx - 5, 108, 10, 7, "wood-dark")
	_rect(image, cx - 5, 113, 10, 1, "pumpkin")


# --- Spooky Forest Bridge ---

## A few dusk clouds, chalk stars and pumpkin-light fireflies in the upper sky.
func _forest_clouds() -> Image:
	var image: Image = _layer()
	_stars(image, FOREST_STAR_COUNT, FOREST_STAR_TOP_Y, FOREST_STAR_BOTTOM_Y, 139, 53, "chalk")
	for cloud: Vector3i in FOREST_CLOUDS:
		_cloud(image, cloud, "dusk")
	for i: int in FOREST_FIREFLY_COUNT:
		var x: int = (i * 211 + 61) % PERIOD
		var y: int = FOREST_FIREFLY_TOP_Y + (i * 29) % (FOREST_FIREFLY_BOTTOM_Y - FOREST_FIREFLY_TOP_Y)
		_put(image, x, y, "pumpkin-light")
	return image


## Rows of rounded tree tops, back to front (dusk, ink-muted, zombie-green-dark), each filled down to the
## bottom; a friendly owl on a back tree top and bats.
func _forest_far() -> Image:
	var image: Image = _layer()
	for row: Dictionary in FOREST_FAR_ROWS:
		var crest: int = row["y"]
		var r: int = row["r"]
		var step: int = row["step"]
		var colour: String = row["colour"]
		_rect(image, 0, crest, PERIOD, LAYER_H - crest, colour)
		for x: int in range(0, PERIOD, step):
			_blob(image, x, crest - r / 3, r, colour)
	_owl(image, FOREST_OWL_X, FOREST_FAR_ROWS[0]["y"] - FOREST_FAR_ROWS[0]["r"] / 3 - 13)
	for bat: Vector2i in FOREST_BATS:
		_stamp(image, BAT, BAT_LEGEND, bat.x - 4, bat.y - 2)
	return image


## A friendly owl, 10 x 12, its feet on `feet_y`: a wood body with a parchment-shade belly, two big round
## parchment eyes with round ink pupils looking ahead, a pumpkin beak, ear tufts and pumpkin feet.
func _owl(image: Image, cx: int, feet_y: int) -> void:
	var top: int = feet_y - 11
	_rect(image, cx - 4, top + 2, 8, 9, "wood")
	_rect(image, cx - 5, top + 4, 10, 6, "wood")
	_put(image, cx - 4, top + 1, "wood")
	_put(image, cx + 3, top + 1, "wood")
	_rect(image, cx - 2, top + 7, 4, 4, "parchment-shade")
	for ex: int in [cx - 4, cx + 1]:
		_rect(image, ex, top + 3, 3, 3, "parchment")
		_put(image, ex + 1, top + 4, "ink")
	_put(image, cx - 1, top + 6, "pumpkin")
	_put(image, cx, top + 6, "pumpkin")
	_rect(image, cx - 3, feet_y, 2, 1, "pumpkin")
	_rect(image, cx + 1, feet_y, 2, 1, "pumpkin")


## Big friendly trees (smooth wood trunks, round leafy canopies at the top), a jack-o'-lantern on a stump, and
## the band: ferns over the creek bank, the bridge's far handrail, toadstools and stones.
func _forest_near() -> Image:
	var image: Image = _layer()
	for tree: Vector2i in FOREST_TREES:
		_tree(image, tree.x, tree.y)
	_stump(image, FOREST_STUMP_X)
	_forest_band(image)
	return image


## A smooth trunk (wood, a wood-dark side and a few long bark lines, no knots or holes) and its canopy
## (zombie-green-dark discs with art-grass highlights). Symmetric about cx, so a tree on x 0 crosses the seam.
func _tree(image: Image, cx: int, width: int) -> void:
	var half: int = width / 2
	_rect(image, cx - half, 0, 2 * half, BAND_TOP, "wood")
	_rect(image, cx - half, 0, 2, BAND_TOP, "wood-dark")
	_rect(image, cx + half - 2, 0, 2, BAND_TOP, "wood-dark")
	for line: int in [-half / 2, half / 2 - 1]:
		_rect(image, cx + line, 50 + absi(line) * 3, 1, 40, "wood-dark")
	# Roots flaring into the band (hidden by the ferns, which start lower).
	_rect(image, cx - half - 3, BAND_TOP - 6, 2 * half + 6, 6, "wood")
	_rect(image, cx - half - 3, BAND_TOP - 6, 2, 6, "wood-dark")
	_rect(image, cx + half + 1, BAND_TOP - 6, 2, 6, "wood-dark")
	for disc: Vector3i in FOREST_CANOPY:
		_blob(image, cx + disc.x, disc.y, disc.z, "zombie-green-dark")
	for disc: Vector3i in FOREST_CANOPY:
		_blob(image, cx + disc.x, disc.y + disc.z - 5, 3, "art-grass")


## A stump with a smiling jack-o'-lantern on top (its bottom FOREST_STUMP_TOP, well above the zombie's
## crown, so it never reads as a hat).
func _stump(image: Image, cx: int) -> void:
	_rect(image, cx - 9, FOREST_STUMP_TOP, 18, BAND_TOP - FOREST_STUMP_TOP, "wood")
	_rect(image, cx - 9, FOREST_STUMP_TOP, 18, 2, "wood-light")
	_rect(image, cx - 9, FOREST_STUMP_TOP + 2, 1, BAND_TOP - FOREST_STUMP_TOP - 2, "wood-dark")
	_rect(image, cx + 8, FOREST_STUMP_TOP + 2, 1, BAND_TOP - FOREST_STUMP_TOP - 2, "wood-dark")
	_jack_o_lantern(image, cx, FOREST_STUMP_TOP)


## Rows 160-191, fully opaque: zombie-green-dark ferns with art-grass fronds, an ink-muted shadow at the
## water's edge, the far handrail (wood-light rails with a parchment-shade top, posts every 40 px),
## toadstools (pumpkin caps with chalk dots) and stones.
func _forest_band(image: Image) -> void:
	_rect(image, 0, BAND_TOP, PERIOD, LAYER_H - BAND_TOP, "zombie-green-dark")
	for x: int in range(0, PERIOD, 6):
		var y: int = BAND_TOP + 2 + (x / 6) % 3
		for i: int in 4:
			_put(image, x + i, y + i, "art-grass")
			_put(image, x - i - 1, y + i, "art-grass")
	_rect(image, 0, LAYER_H - 3, PERIOD, 3, "ink-muted")
	for stone: Vector3i in FOREST_STONES:
		_blob(image, stone.x, stone.y, stone.z, "stone")
		_rect(image, stone.x - stone.z / 2, stone.y - stone.z + 1, stone.z, 1, "stone-light")
	for x: int in range(FOREST_POST_FIRST, PERIOD, FOREST_POST_STEP):
		_rect(image, x - 1, FOREST_RAIL_TOP, 3, LAYER_H - FOREST_RAIL_TOP, "wood-light")
		_rect(image, x - 1, FOREST_RAIL_TOP, 1, LAYER_H - FOREST_RAIL_TOP, "parchment-shade")
	_rect(image, 0, FOREST_RAIL_TOP, PERIOD, 3, "wood-light")
	_rect(image, 0, FOREST_RAIL_TOP, PERIOD, 1, "parchment-shade")
	_rect(image, 0, FOREST_RAIL_LOW, PERIOD, 2, "wood-light")
	for toadstool: Vector2i in FOREST_TOADSTOOLS:
		var x: int = toadstool.x
		var cap: int = toadstool.y
		_rect(image, x - 1, cap + 3, 2, LAYER_H - 3 - cap - 3, "parchment")
		_rect(image, x - 4, cap + 2, 8, 1, "wood-dark")
		_rect(image, x - 4, cap, 8, 2, "pumpkin")
		_rect(image, x - 3, cap - 1, 6, 1, "pumpkin")
		_rect(image, x - 2, cap - 2, 4, 1, "wood-dark")
		_put(image, x - 2, cap, "chalk")
		_put(image, x + 1, cap - 1, "chalk")


# --- escape covers: 48 x 48, 3 frames, fills only, then the ink outline ---

## The three frames side by side; `frame_fn(i)` returns frame i's fills (Dictionary[Vector2i, String]).
func _cover_sheet(frame_fn: Callable) -> Image:
	var image: Image = Image.create_empty(COVER_FRAMES * EFFECT_FRAME, EFFECT_FRAME, false, Image.FORMAT_RGBA8)
	for i: int in COVER_FRAMES:
		var fills: Dictionary = frame_fn.call(i)
		for p: Vector2i in fills:
			if p.x < 1 or p.x > EFFECT_FRAME - 2 or p.y < 1 or p.y > COVER_GROUND_ROW - 1:
				push_error("cover frame %d: fill at %s outside the frame" % [i, p])
				_ok = false
				continue
			image.set_pixel(i * EFFECT_FRAME + p.x, p.y, _color(fills[p]))
		_outline(image, i)
	return image


## Grows a 1 px ink outline around frame `i`'s fills: every empty pixel beside a fill becomes ink.
func _outline(image: Image, i: int) -> void:
	var ink: Color = _color("ink")
	var edge: Array[Vector2i] = []
	for y: int in EFFECT_FRAME:
		for x: int in EFFECT_FRAME:
			if image.get_pixel(i * EFFECT_FRAME + x, y).a8 == 255:
				continue
			for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var n: Vector2i = Vector2i(x, y) + step
				if n.x >= 0 and n.y >= 0 and n.x < EFFECT_FRAME and n.y < EFFECT_FRAME \
						and image.get_pixel(i * EFFECT_FRAME + n.x, n.y).a8 == 255:
					edge.append(Vector2i(x, y))
					break
	for p: Vector2i in edge:
		image.set_pixel(i * EFFECT_FRAME + p.x, p.y, ink)


## Fills a disc (the _blob rule, centred on the pixel boundary at cx) into `fills`.
func _fill_disc(fills: Dictionary, cx: int, cy: int, r: int, color_name: String) -> void:
	for dy: int in range(-r, r):
		var yc: float = dy + 0.5
		var h: int = maxi(1, roundi(sqrt(maxf(0.0, r * r - yc * yc))))
		for x: int in range(cx - h, cx + h):
			fills[Vector2i(x, cy + dy)] = color_name


## Fills an ellipse centred on pixel (cx, cy) with radii rx, ry into `fills`.
func _fill_ellipse(fills: Dictionary, cx: int, cy: int, rx: float, ry: float, color_name: String) -> void:
	for y: int in range(cy - ceili(ry), cy + ceili(ry) + 1):
		for x: int in range(cx - ceili(rx), cx + ceili(rx) + 1):
			var nx: float = (x - cx) / rx
			var ny: float = (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				fills[Vector2i(x, y)] = color_name


## The haystack: a round parchment-shade stack with wood-light straw lines and a wood-light base, a small
## pumpkin resting on its side. Frames 1-2 lean (rows shifted more toward the top) and straw wisps pop off.
func _haystack_frame(i: int) -> Dictionary:
	var lean: int = [0, 2, -1][i]
	var top: int = 14
	var cy: int = 32
	var r: int = 18
	var fills: Dictionary = {}
	for y: int in range(top, COVER_GROUND_ROW):
		var half: int = r
		if y < cy:
			var yc: float = y + 0.5 - cy
			half = roundi(sqrt(maxf(0.0, r * r - yc * yc)))
		elif y >= COVER_GROUND_ROW - 3:
			half = r - 1
		if half <= 0:
			continue
		var shift: int = roundi(lean * float(COVER_GROUND_ROW - 1 - y) / float(COVER_GROUND_ROW - 1 - top))
		for x: int in range(24 - half + shift, 24 + half + shift):
			var colour: String = "wood-light" if y >= COVER_GROUND_ROW - 4 else "parchment-shade"
			if y < COVER_GROUND_ROW - 4 and y % 5 == 4 and posmod(x + y, 4) < 2 \
					and x > 24 - half + shift + 1 and x < 24 + half + shift - 2:
				colour = "wood-light"
			fills[Vector2i(x, y)] = colour
	# The pumpkin on its side, bottom right, with its own ring (an inner outline: ink is allowed inside).
	_fill_disc(fills, 35, 41, 4, "ink")
	_fill_disc(fills, 35, 41, 3, "pumpkin")
	fills[Vector2i(33, 40)] = "pumpkin-light"
	fills[Vector2i(34, 39)] = "pumpkin-light"
	fills[Vector2i(35, 37)] = "zombie-green-dark"
	fills[Vector2i(35, 36)] = "zombie-green-dark"
	var wisps: Array = [[], [Vector2i(19, 8), Vector2i(29, 6), Vector2i(25, 10)],
			[Vector2i(16, 10), Vector2i(31, 9), Vector2i(22, 5)]]
	for w: Vector2i in wisps[i]:
		fills[w] = "wood-light"
		fills[w + Vector2i(1, 0)] = "wood-light"
	return fills


## The hollow log lying on the path: a wood body with wood-dark bark lines and a wood-dark underside, its
## round cut end facing the zombie (a wood-light rim with a parchment-shade ring around a dusk opening),
## art-grass moss along the top and a pumpkin toadstool with chalk dots. Frames 1-2 rock 1 px (the upper rows
## shift) and moss bits pop off.
func _log_frame(i: int) -> Dictionary:
	var rock: int = [0, 1, -1][i]
	var body: Dictionary = {}
	var cy: int = 32
	var ry: float = 12.5
	for y: int in range(20, COVER_GROUND_ROW):
		var ny: float = (y - cy) / ry
		if absf(ny) > 1.0:
			continue
		var cap: int = roundi(4.0 * sqrt(1.0 - ny * ny))
		for x: int in range(12, 38 + cap):
			var colour: String = "wood"
			if y >= COVER_GROUND_ROW - 3:
				colour = "wood-dark"
			elif (y == 24 and x % 7 < 4) or (y == 29 and (x + 3) % 9 < 5) or (y == 35 and (x + 1) % 8 < 4) \
					or (y == 40 and (x + 5) % 7 < 3):
				colour = "wood-dark"
			body[Vector2i(x, y)] = colour
	# The cut end: a wood-light rim (an ink line where it meets the bark), a parchment-shade ring, a dusk opening.
	_fill_ellipse(body, 12, cy, 7.5, 13.0, "wood-light")
	var rim: Dictionary = {}
	_fill_ellipse(rim, 12, cy, 6.5, 12.0, "wood-light")
	for p: Vector2i in body.keys():
		if p.x >= 12 and body[p] == "wood-light" and not rim.has(p):
			body[p] = "ink"
	_fill_ellipse(body, 12, cy, 5.0, 10.0, "parchment-shade")
	_fill_ellipse(body, 12, cy, 4.0, 9.0, "dusk")
	# Moss along the top, and the toadstool.
	for mx: int in [20, 21, 22, 23, 24, 31, 32, 33, 34, 35]:
		body[Vector2i(mx, 20)] = "art-grass"
		body[Vector2i(mx, 19)] = "art-grass"
	body[Vector2i(22, 18)] = "art-grass"
	body[Vector2i(33, 18)] = "art-grass"
	for sy: int in range(15, 19):
		body[Vector2i(27, sy)] = "parchment"
		body[Vector2i(28, sy)] = "parchment"
	for cx: int in range(24, 32):
		body[Vector2i(cx, 14)] = "pumpkin"
	for cx: int in range(25, 31):
		body[Vector2i(cx, 13)] = "pumpkin"
	for cx: int in range(26, 30):
		body[Vector2i(cx, 12)] = "pumpkin"
	body[Vector2i(26, 13)] = "chalk"
	body[Vector2i(29, 12)] = "chalk"
	var fills: Dictionary = {}
	for p: Vector2i in body:
		var shift: int = rock if p.y < cy else 0
		fills[p + Vector2i(shift, 0)] = body[p]
	var bits: Array = [[], [Vector2i(16, 9), Vector2i(40, 13)], [Vector2i(20, 7), Vector2i(42, 16)]]
	for b: Vector2i in bits[i]:
		fills[b] = "art-grass"
		fills[b + Vector2i(1, 0)] = "art-grass"
	return fills


func _save(image: Image, path: String) -> Error:
	if image == null:
		return ERR_INVALID_DATA
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
