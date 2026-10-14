extends SceneTree
## Dev-only: writes the Story 10.2 Zombie Run theme backdrops (FR76): Pumpkin Patch Farm and Snowy Town,
## each a full parallax set (clouds, far, near, the ground tiles and the ground strip) in its own folder.
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_zombie_run_themes_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Both looks are drawn on the Sunny Village Green recipe (tools/gen_zombie_run_art.gd, Story 3.6): shapes
## (rects, triangles, discs) at fixed, hard-coded positions, no RNG, so a rerun writes the same bytes. Every
## shape wraps around x (it is drawn at posmod(x, 640)), so each 640 px layer tiles with no seam, and the
## features that cross the seam are centred on it (x = 0) on purpose; _check_seam fails the run otherwise.
## The shape helpers are copied from that tool, not shared (SceneTree instance methods can't be, and the old
## tools' PNGs must stay byte-identical). The palette is read from tools/gen_art_prototypes.gd (one source).
##
## Backdrops are exempt from the ink-outline rule only: palette colours, hard alpha, and never candy-yellow
## (focus), stamp-red (stamp) or art-moon (the moon): _color fails the run on any of them. The tag band
## (y 96-166 of the three layers) and the whole ground strip never use parchment, chalk or candy-yellow (the
## tag and arrow colours), so snow is art-sky-light, never chalk. The day readability band: near.png rows
## 160-191 (where the characters' legs and bodies pass) and the ground strip's top 4 rows never use
## zombie-green or zombie-green-bright, so the zombie and the party zombies never sit on their own skin.
## The ground strip is composed from ground_tiles.png with a hard-coded index map: row 0 is the path tile
## (the last tile), rows 1-3 never are. Rules: docs/art-style-sheet.md; tests: test_art_backdrop.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")

const FARM_DIR: String = "res://assets/sprites/backdrops/pumpkin_patch_farm"
const SNOW_DIR: String = "res://assets/sprites/backdrops/snowy_town"

## Every layer is PERIOD wide, so two copies side by side always cover the 640 px screen.
const PERIOD: int = 640
## Layers cover the playfield above the ground line (y 0-192); the ground strip covers y 192-256.
const LAYER_H: int = 192
const GROUND_ROWS: int = 4
const TILE: int = 16
const PATH_TILE: int = 3
const TAG_BAND_TOP: int = 96
const TAG_BAND_BOTTOM: int = 166
const DAY_BAND_TOP: int = 160
const RESERVED: Array[String] = ["candy-yellow", "stamp-red", "art-moon"]
const TAG_COLOURS: Array[String] = ["parchment", "chalk", "candy-yellow"]
const DAY_BAND_FORBIDDEN: Array[String] = ["zombie-green", "zombie-green-bright"]

## Shared dressing: a sagging ink string with flags hanging under it, alternating colours.
const BUNTING_SPAN: int = 128
const BUNTING_TOP_Y: int = 8
const BUNTING_SAG_PX: float = 7.0
const FLAG_STEP: int = 16
const BUNTING_COLOURS: Array[String] = ["bat-purple", "pumpkin"]

## A friendly little bat (far layer dressing), 9 x 4.
const BAT: Array[String] = [
	"b.......b",
	"bb.b.b.bb",
	".bbbbbbb.",
	"..b...b..",
]
const BAT_LEGEND: Dictionary[String, String] = {"b": "bat-purple"}

# --- Pumpkin Patch Farm: an autumn afternoon ---

const FARM_GROUND_LEGEND: Dictionary[String, String] = {
	"g": "art-grass",
	"d": "zombie-green-dark",
	"o": "pumpkin-light",
	"p": "pumpkin",
	"w": "wood-light",
	"a": "parchment-shade",
	"f": "ink-faded",
}

const FARM_TILE_GRASS: Array[String] = [
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggdggggggggggggg",
	"ggdggggggggdgggg",
	"gggggggggggdgggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggdgggggggggg",
	"gggggdgggggggggg",
	"gggggggggggggggg",
	"gggggggggggggdgg",
	"gggggggggggggdgg",
	"gggggggggggggggg",
	"ggggggggdggggggg",
	"ggggggggdggggggg",
	"gggggggggggggggg",
]

## Grass with fallen leaves.
const FARM_TILE_LEAVES: Array[String] = [
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggooggggggggggg",
	"ggggogggggggwggg",
	"ggggggggggwwgggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggggggpggggggggg",
	"gggggppggggggggg",
	"gggggggggggggggg",
	"ggggggggggggoggg",
	"gggwggggggggoogg",
	"gggwwggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
]

## Grass with loose straw.
const FARM_TILE_STRAW: Array[String] = [
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggggggwwwggggggg",
	"gggggggggwwggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"ggggggggggggdggg",
	"ggggggggggggdggg",
	"ggwwgggggggggggg",
	"gggggwwggggggggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
	"gggggggggwwwgggg",
	"gggggggggggggggg",
	"gggggggggggggggg",
]

## The path: the Sunny recipe (a faded edge line where the soles stand, dirt, pebbles), new pebble layout.
const FARM_TILE_PATH: Array[String] = [
	"ffffffffffffffff",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaawaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaafaaaaaaaaaaaa",
	"aaaaaaaaaaaaawaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaawwaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaafaaaa",
	"aawaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaawaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaafaa",
	"aaaaaaaaaaaaaaaa",
]

const FARM_TILES: Array = [FARM_TILE_GRASS, FARM_TILE_LEAVES, FARM_TILE_STRAW, FARM_TILE_PATH]

## Row 0 the path, rows 1-3 grass (0 grass, 1 leaves, 2 straw), 40 tiles a row.
const FARM_GROUND_MAP: Array[String] = [
	"3333333333333333333333333333333333333333",
	"0100020010002001000101000020100010200100",
	"1000100200010001000210010002000100100010",
	"0020001000100020001000100020010001000200",
]

## Clouds: [centre x, bottom y, puff size]. The first is centred on the seam on purpose.
const FARM_CLOUDS: Array[Vector3i] = [
	Vector3i(0, 36, 7),
	Vector3i(176, 52, 8),
	Vector3i(328, 26, 6),
	Vector3i(500, 46, 9),
]

## Harvested hills: crest = 146 - 8 cos(2t) - 4 cos(5t), t = 2 pi x / 640, a peak on the seam.
const FARM_HILL_BASE_Y: float = 146.0
const FARM_HILL_A_PX: float = 8.0
const FARM_HILL_B_PX: float = 4.0
const FARM_FURROW_STEP: int = 6
const FARM_HEDGE_STEP: int = 40
## Distant pumpkin patches on the hillside: [from x, to x). Kept clear of far x ~150-190 (behind the
## zombie at the start of a run: far offset 584, so the zombie's screen x 224 is far x 168).
const FARM_PATCHES: Array[Vector2i] = [Vector2i(30, 130), Vector2i(430, 570)]
const FARM_PATCH_STEP: int = 10
const FARM_BARN_X: int = 300
const FARM_SILO_X: int = 318
const FARM_BATS: Array[Vector2i] = [Vector2i(200, 40), Vector2i(452, 66)]

## Near layer: bunting, a fence, a smiling scarecrow, a haystack with pumpkins, two vine patches and a cart
## of pumpkins centred on the seam. At the start of a run the near layer is offset 528 px, so the zombie
## (screen x 224) stands in front of near x 112: nothing round sits near its crown (~y 150-162) there; the
## cart shows at screen x 112, the scarecrow at 362.
const FARM_FENCE_POST_STEP: int = 32
const FARM_FENCE_POST_FIRST: int = 16
const FARM_FENCE_POST_TOP: int = 168
const FARM_SCARECROW_X: int = 250
const FARM_HAY_X: int = 404
const FARM_VINES: Array[Vector2i] = [Vector2i(124, 196), Vector2i(504, 576)]
const FARM_VINE_PUMPKINS: Array[int] = [140, 174, 522, 556]

# --- Snowy Town: a winter day ---

const SNOW_GROUND_LEGEND: Dictionary[String, String] = {
	"s": "art-sky-light",
	"l": "stone-light",
	"n": "stone",
}

const SNOW_TILE_SNOW: Array[String] = [
	"ssssssssssssssss",
	"ssssssssssssssss",
	"sssslsssssssssss",
	"ssssssssssssssss",
	"ssssssssssslssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"sslsssssssssssss",
	"ssssssssssssssss",
	"sssssssslsssssss",
	"ssssssssssssssss",
	"ssssssssssssssls",
	"ssssssssssssssss",
	"sssssslsssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
]

## Snow with drift lines.
const SNOW_TILE_DRIFT: Array[String] = [
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"sssllllsssssssss",
	"ssssssslllssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssllllss",
	"sllsssssssssslss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
]

## Snow with footprints.
const SNOW_TILE_PRINTS: Array[String] = [
	"ssssssssssssssss",
	"ssssssssssssssss",
	"sssnnsssssssssss",
	"sssnnsssssssssss",
	"ssslsssssssnnsss",
	"sssssssssssnnsss",
	"ssssssssssslssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
	"ssssnnssssssssss",
	"ssssnnssssssssss",
	"sssslssssssnnsss",
	"sssssssssssnnsss",
	"ssssssssssslssss",
	"ssssssssssssssss",
	"ssssssssssssssss",
]

## The cleared path: stone-light slush, a stone edge line where the soles stand, a few snow patches.
const SNOW_TILE_PATH: Array[String] = [
	"nnnnnnnnnnnnnnnn",
	"llllllllllllllll",
	"lllllllsslllllll",
	"llllllllllllllll",
	"llnlllllllllllll",
	"llllllllllllslll",
	"lllllllllllsssll",
	"llllllllllllllll",
	"lllllnllllllllll",
	"llllllllllllllll",
	"lssslllllllllnll",
	"llllllllllllllll",
	"lllllllllsllllll",
	"llllllllllllllll",
	"llllllnlllllllll",
	"llllllllllllllll",
]

const SNOW_TILES: Array = [SNOW_TILE_SNOW, SNOW_TILE_DRIFT, SNOW_TILE_PRINTS, SNOW_TILE_PATH]

## Row 0 the path, rows 1-3 snow (0 snow, 1 drift, 2 footprints), 40 tiles a row.
const SNOW_GROUND_MAP: Array[String] = [
	"3333333333333333333333333333333333333333",
	"0010002000100010002001000020010002001000",
	"1000020010001000100020001001000100020001",
	"0200010000200100010000102000101000010020",
]

## Snow clouds: [centre x, bottom y, puff size]. The first is centred on the seam on purpose.
const SNOW_CLOUDS: Array[Vector3i] = [
	Vector3i(0, 40, 8),
	Vector3i(160, 56, 7),
	Vector3i(320, 30, 9),
	Vector3i(484, 50, 6),
]
## Static flakes (they drift with the cloud parallax): fixed positions from a formula, no RNG. x stays in
## [4, 634) so no flake touches the seam columns; y in [4, 124), so most sit above the tag band.
const SNOW_FLAKES: int = 48
const SNOW_FLAKE_X_MIN: int = 4
const SNOW_FLAKE_X_SPAN: int = 630
const SNOW_FLAKE_Y_MIN: int = 4
const SNOW_FLAKE_Y_SPAN: int = 120

## Snowy hills: crest = 150 - 7 cos(2t) - 5 cos(3t), a peak on the seam.
const SNOW_HILL_BASE_Y: float = 150.0
const SNOW_HILL_A_PX: float = 7.0
const SNOW_HILL_B_PX: float = 5.0
const SNOW_PINES: Array[int] = [36, 96, 214, 470, 604]
const SNOW_HOUSES: Array[int] = [130, 384, 536]
const SNOW_CHURCH_X: int = 300

## Near layer: bunting, a snowy fence and drift, two cottages (left edge x) with snow roofs and icicles, a
## smiling snowman in a pumpkin hat and scarf, and a lamp post centred on the seam. At the start of a run
## the zombie stands in front of near x 112: clear of the cottages (24-80) and the snowman (250).
const SNOW_COTTAGES: Array[int] = [24, 384]
const SNOW_COTTAGE_W: int = 56
const SNOW_FENCE_POST_STEP: int = 32
const SNOW_FENCE_POST_FIRST: int = 16
const SNOW_FENCE_POST_TOP: int = 168
const SNOW_DRIFT_Y: int = 185
const SNOW_DRIFT_WAVE: int = 80
const SNOW_SNOWMAN_X: int = 250
const SNOW_LAMP_TOP: int = 128

var _ok: bool = true


func _init() -> void:
	for legend: Dictionary[String, String] in [FARM_GROUND_LEGEND, SNOW_GROUND_LEGEND, BAT_LEGEND]:
		for key: String in legend:
			_color(legend[key])
	var errors: Array[Error] = []
	errors.append_array(_write_theme(FARM_DIR, FARM_TILES, FARM_GROUND_LEGEND, FARM_GROUND_MAP,
			[_farm_clouds(), _farm_far(), _farm_near()]))
	errors.append_array(_write_theme(SNOW_DIR, SNOW_TILES, SNOW_GROUND_LEGEND, SNOW_GROUND_MAP,
			[_snow_clouds(), _snow_far(), _snow_near()]))
	# Non-zero exit on any failure, so a bad map, colour, seam, path or cwd doesn't look like success.
	quit(0 if _ok and errors.all(func(err: Error) -> bool: return err == OK) else 1)


## Writes one theme's five files; layers are [clouds, far, near]. Checks the seam and the colour bands.
func _write_theme(dir: String, tiles: Array, legend: Dictionary[String, String], map: Array[String],
		layers: Array[Image]) -> Array[Error]:
	var errors: Array[Error] = [DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))]
	var tiles_image: Image = _tiles_image(tiles, legend)
	errors.append(_save(tiles_image, dir + "/ground_tiles.png") if tiles_image != null else ERR_INVALID_DATA)
	var strip: Image = _ground_strip(tiles_image, tiles.size(), map) if tiles_image != null else null
	if strip != null:
		_check_seam(strip, dir + "/ground_strip.png")
		_check_band(strip, 0, strip.get_height(), TAG_COLOURS, dir + "/ground_strip.png")
		_check_band(strip, 0, GROUND_ROWS, DAY_BAND_FORBIDDEN, dir + "/ground_strip.png top")
	errors.append(_save(strip, dir + "/ground_strip.png") if strip != null else ERR_INVALID_DATA)
	var names: Array[String] = ["clouds.png", "far.png", "near.png"]
	for i: int in names.size():
		var path: String = dir + "/" + names[i]
		_check_seam(layers[i], path)
		_check_band(layers[i], TAG_BAND_TOP, TAG_BAND_BOTTOM + 1, TAG_COLOURS, path + " tag band")
		errors.append(_save(layers[i], path))
	_check_band(layers[2], DAY_BAND_TOP, LAYER_H, DAY_BAND_FORBIDDEN, dir + "/near.png day band")
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


## One horizontal strip, `size` px per frame. Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String], size: int) -> Image:
	var image: Image = Image.create_empty(frames.size() * size, size, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array[String] = part[0]
			var top: int = part[1]
			if top < 0 or top + rows.size() > size:
				push_error("frame %d: part from row %d does not fit" % [i, top])
				return null
			for y: int in rows.size():
				var row: String = rows[y]
				if row.length() != size:
					push_error("frame %d row %d: %d chars, want %d" % [i, top + y, row.length(), size])
					return null
				for x: int in size:
					var ch: String = row[x]
					if ch == ".":
						continue
					if not legend.has(ch) or not Proto.PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * size + x, top + y, _color(legend[ch]))
	return image


func _tiles_image(tiles: Array, legend: Dictionary[String, String]) -> Image:
	var frames: Array = []
	for tile: Array[String] in tiles:
		frames.append([[tile, 0]])
	return _sheet_image(frames, legend, TILE)


## 640 x 64, each 16 x 16 cell copied from the tiles by the map (no randomness). Row 0 is the path tile
## only, rows 1-3 never are, and every tile is used.
func _ground_strip(tiles: Image, count: int, map: Array[String]) -> Image:
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
			if index < 0 or index >= count or (row == 0) != (index == PATH_TILE):
				push_error("ground map (%d,%d): tile %d" % [col, row, index])
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


## A rect with a 1 px ink border.
func _box(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	_rect(image, x, y, w, h, "ink")
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


## Sunny's puffy cloud: a flat base and three discs.
func _cloud(image: Image, cloud: Vector3i, color_name: String) -> void:
	var s: int = cloud.z
	_rect(image, cloud.x - 2 * s, cloud.y - s, 4 * s, s, color_name)
	_blob(image, cloud.x - s, cloud.y - s, s, color_name)
	_blob(image, cloud.x + s, cloud.y - s, s, color_name)
	_blob(image, cloud.x, cloud.y - s - s / 2, s + 2, color_name)


## A crest line of two cosines with whole periods across 640 px and a peak on the seam, so x 639 and x 0
## sit on the same row.
func _hill_y(x: int, base: float, a: float, ka: int, b: float, kb: int) -> int:
	var t: float = TAU * x / PERIOD
	return roundi(base - a * cos(ka * t) - b * cos(kb * t))


## A sagging ink string from attach point to attach point, flags in BUNTING_COLOURS hanging under it.
func _bunting(image: Image) -> void:
	for x: int in PERIOD:
		_put(image, x, _bunting_y(x), "ink")
	for x: int in range(FLAG_STEP / 2, PERIOD, FLAG_STEP):
		var top: int = _bunting_y(x) + 1
		var colour: String = BUNTING_COLOURS[(x / FLAG_STEP) % BUNTING_COLOURS.size()]
		for row: int in 6:
			var half: int = (6 - row) / 2
			_rect(image, x - half, top + row, 2 * half + 1, 1, colour)
		_put(image, x, top + 6, "dusk")


func _bunting_y(x: int) -> int:
	return BUNTING_TOP_Y + roundi(BUNTING_SAG_PX * sin(PI * posmod(x, BUNTING_SPAN) / BUNTING_SPAN))


## An ink-outlined pumpkin with a highlight and a stem.
func _pumpkin(image: Image, cx: int, cy: int, r: int) -> void:
	_blob(image, cx, cy, r + 1, "ink")
	_blob(image, cx, cy, r, "pumpkin")
	_rect(image, cx - r / 2 - 1, cy - r + 2, 2, maxi(1, r - 2), "pumpkin-light")
	_rect(image, cx - 1, cy - r - 2, 2, 2, "zombie-green-dark")


## Two rails across the width (snow on top when `snow`), posts every `step` px; skips x where `skip` is true.
func _fence(image: Image, first: int, step: int, post_top: int, snow: bool, skip: Callable) -> void:
	for x: int in PERIOD:
		if skip.call(x):
			continue
		for rail_y: int in [174, 183]:
			if snow:
				_put(image, x, rail_y - 1, "art-sky-light")
			_put(image, x, rail_y, "ink")
			_put(image, x, rail_y + 1, "wood-light")
			_put(image, x, rail_y + 2, "wood-light")
			_put(image, x, rail_y + 3, "ink")
	for x: int in range(first, PERIOD, step):
		if skip.call(x) or skip.call(x + 3):
			continue
		_box(image, x, post_top, 4, LAYER_H - post_top, "wood")
		if snow:
			_rect(image, x - 1, post_top - 2, 6, 2, "art-sky-light")


# --- Pumpkin Patch Farm ---

func _farm_clouds() -> Image:
	var image: Image = _layer()
	for cloud: Vector3i in FARM_CLOUDS:
		_cloud(image, cloud, "art-sky-light")
	return image


func _farm_hill_y(x: int) -> int:
	return _hill_y(x, FARM_HILL_BASE_Y, FARM_HILL_A_PX, 2, FARM_HILL_B_PX, 5)


## Harvested wood-light fields with wood furrows, a zombie-green-dark hedgerow along the crest, rows of
## tiny pumpkins (the patch in the distance), a red-free barn and a silo, two friendly bats.
func _farm_far() -> Image:
	var image: Image = _layer()
	for x: int in PERIOD:
		var top: int = _farm_hill_y(x)
		_rect(image, x, top, 1, LAYER_H - top, "wood-light")
		for y: int in range(top + FARM_FURROW_STEP, LAYER_H, FARM_FURROW_STEP):
			_put(image, x, y, "wood")
		_rect(image, x, top, 1, 2, "zombie-green-dark")
	for x: int in range(0, PERIOD, FARM_HEDGE_STEP):
		_blob(image, x, _farm_hill_y(x), 3, "zombie-green-dark")
	for patch: Vector2i in FARM_PATCHES:
		for x: int in range(patch.x, patch.y, FARM_PATCH_STEP):
			for row: int in 2:
				var px: int = x + row * FARM_PATCH_STEP / 2
				var py: int = _farm_hill_y(px) + 8 + row * 8
				_rect(image, px, py, 2, 2, "pumpkin")
				_put(image, px, py - 1, "zombie-green-dark")
	# The barn: wood-dark walls with stone-light corner trim, a wood roof, a stone-light loft window.
	var ground: int = _farm_hill_y(FARM_BARN_X) + 2
	_rect(image, FARM_BARN_X - 8, ground - 12, 16, 12, "wood-dark")
	_rect(image, FARM_BARN_X - 8, ground - 12, 1, 12, "stone-light")
	_rect(image, FARM_BARN_X + 7, ground - 12, 1, 12, "stone-light")
	_roof(image, FARM_BARN_X, ground - 21, ground - 12, "wood")
	_rect(image, FARM_BARN_X - 1, ground - 16, 2, 2, "stone-light")
	_rect(image, FARM_BARN_X - 3, ground - 7, 6, 7, "wood")
	# The silo: a stone-light tower with a dome.
	var silo_ground: int = _farm_hill_y(FARM_SILO_X) + 2
	_rect(image, FARM_SILO_X - 3, silo_ground - 20, 6, 20, "stone-light")
	_blob(image, FARM_SILO_X, silo_ground - 20, 3, "stone-light")
	for bat: Vector2i in FARM_BATS:
		_stamp(image, BAT, BAT_LEGEND, bat.x, bat.y)
	return image


func _farm_near() -> Image:
	var image: Image = _layer()
	_bunting(image)
	_fence(image, FARM_FENCE_POST_FIRST, FARM_FENCE_POST_STEP, FARM_FENCE_POST_TOP, false,
			func(_x: int) -> bool: return false)
	_scarecrow(image, FARM_SCARECROW_X)
	_haystack(image, FARM_HAY_X)
	for vine: Vector2i in FARM_VINES:
		for x: int in range(vine.x, vine.y):
			_put(image, x, 189 + (1 if posmod(x, 12) < 6 else 0), "zombie-green-dark")
		for x: int in range(vine.x + 6, vine.y, 12):
			_rect(image, x, 186, 3, 2, "zombie-green-dark")
	for x: int in FARM_VINE_PUMPKINS:
		_pumpkin(image, x, 187, 4)
	_cart(image)
	return image


## A smiling scarecrow on a post: a wood-dark hat, a burlap face with button eyes, a bat-purple shirt with a
## wood patch, straw at the cuffs and hem. Nothing creepy: a plain smile, no stitches.
func _scarecrow(image: Image, cx: int) -> void:
	_rect(image, cx - 1, 128, 2, LAYER_H - 128, "wood")
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


## Two straw bales (parchment-shade with wood-light straw lines) and two pumpkins on top.
func _haystack(image: Image, x: int) -> void:
	_box(image, x, 178, 32, 14, "parchment-shade")
	_box(image, x + 6, 165, 20, 14, "parchment-shade")
	for y: int in [169, 173, 182, 186]:
		var left: int = x + 7 if y < 178 else x + 1
		var width: int = 18 if y < 178 else 30
		for xx: int in range(left, left + width, 3):
			_put(image, xx, y, "wood-light")
			_put(image, xx + 1, y, "wood-light")
	_pumpkin(image, x + 12, 160, 4)
	_pumpkin(image, x + 21, 161, 3)


## A wood cart heaped with pumpkins, centred on the seam (x 0) so it crosses it on purpose.
func _cart(image: Image) -> void:
	_pumpkin(image, -10, 161, 4)
	_pumpkin(image, 10, 161, 4)
	_pumpkin(image, 0, 159, 5)
	_box(image, -20, 164, 40, 13, "wood")
	_rect(image, -19, 170, 38, 1, "wood-dark")
	_rect(image, 20, 167, 10, 2, "wood-dark")
	for wheel_x: int in [-12, 12]:
		_blob(image, wheel_x, 184, 6, "ink")
		_blob(image, wheel_x, 184, 5, "wood-dark")
		_rect(image, wheel_x - 1, 183, 2, 2, "ink")


# --- Snowy Town ---

func _snow_clouds() -> Image:
	var image: Image = _layer()
	for cloud: Vector3i in SNOW_CLOUDS:
		_cloud(image, cloud, "stone-light")
	for i: int in SNOW_FLAKES:
		var x: int = SNOW_FLAKE_X_MIN + posmod(i * 83 + (i % 5) * 29, SNOW_FLAKE_X_SPAN)
		var y: int = SNOW_FLAKE_Y_MIN + posmod(i * 37, SNOW_FLAKE_Y_SPAN)
		var size: int = 2 if i % 3 == 0 else 1
		_rect(image, x, y, size, size, "art-sky-light")
	return image


func _snow_hill_y(x: int) -> int:
	return _hill_y(x, SNOW_HILL_BASE_Y, SNOW_HILL_A_PX, 2, SNOW_HILL_B_PX, 3)


## Snowy hills (art-sky-light, a stone-light crest and dashed shade lines), snowy pines, little houses with
## lit pumpkin-light windows and a church with a plain spire (no cross: it would read as a letter).
func _snow_far() -> Image:
	var image: Image = _layer()
	for x: int in PERIOD:
		var top: int = _snow_hill_y(x)
		_rect(image, x, top, 1, LAYER_H - top, "art-sky-light")
		_put(image, x, top, "stone-light")
		for y: int in range(top + 7, LAYER_H, 9):
			if posmod(x + y, 12) < 5:
				_put(image, x, y, "stone-light")
	for x: int in SNOW_PINES:
		var ground: int = _snow_hill_y(x) + 2
		_rect(image, x - 1, ground - 3, 2, 3, "wood-dark")
		_roof(image, x, ground - 18, ground - 3, "zombie-green-dark")
		for y: int in range(ground - 15, ground - 3, 4):
			var half: int = y - (ground - 18) + 1
			_put(image, x - half, y, "art-sky-light")
			_put(image, x + half - 1, y, "art-sky-light")
		_rect(image, x - 1, ground - 18, 2, 1, "art-sky-light")
	for x: int in SNOW_HOUSES:
		var ground: int = _snow_hill_y(x) + 2
		_rect(image, x - 5, ground - 7, 10, 7, "stone")
		_roof(image, x, ground - 12, ground - 6, "art-sky-light")
		_rect(image, x - 3, ground - 5, 2, 2, "pumpkin-light")
		_rect(image, x + 1, ground - 5, 2, 2, "pumpkin-light")
	var church_ground: int = _snow_hill_y(SNOW_CHURCH_X) + 2
	_rect(image, SNOW_CHURCH_X - 6, church_ground - 12, 12, 12, "ink-muted")
	_roof(image, SNOW_CHURCH_X, church_ground - 17, church_ground - 11, "art-sky-light")
	_rect(image, SNOW_CHURCH_X - 2, church_ground - 26, 4, 10, "ink-muted")
	_roof(image, SNOW_CHURCH_X, church_ground - 30, church_ground - 26, "art-sky-light")
	_rect(image, SNOW_CHURCH_X - 1, church_ground - 22, 2, 3, "pumpkin-light")
	_rect(image, SNOW_CHURCH_X - 2, church_ground - 7, 4, 7, "pumpkin-light")
	return image


func _snow_near() -> Image:
	var image: Image = _layer()
	_bunting(image)
	_fence(image, SNOW_FENCE_POST_FIRST, SNOW_FENCE_POST_STEP, SNOW_FENCE_POST_TOP, true, _behind_snow_cottage)
	for x: int in PERIOD:
		var top: int = SNOW_DRIFT_Y - roundi(2.0 * sin(TAU * x / SNOW_DRIFT_WAVE))
		_put(image, x, top, "stone-light")
		_rect(image, x, top + 1, 1, LAYER_H - top - 1, "art-sky-light")
	_snow_cottage(image, SNOW_COTTAGES[0], "wood", "wood-dark")
	_snow_cottage(image, SNOW_COTTAGES[1], "stone", "ink-muted")
	_snowman(image, SNOW_SNOWMAN_X)
	_lamp(image)
	return image


func _behind_snow_cottage(x: int) -> bool:
	for left: int in SNOW_COTTAGES:
		if x >= left - 1 and x <= left + SNOW_COTTAGE_W:
			return true
	return false


## A cottage on the ground line: a snow-capped chimney, a thick snow roof with a stone-light shaded eave,
## icicles, walls with plank or brick lines, a door with a pumpkin-light knob and a lit window.
func _snow_cottage(image: Image, x: int, wall_fill: String, wall_line: String) -> void:
	var wall_top: int = LAYER_H - 32
	_box(image, x + 38, wall_top - 24, 7, 16, "stone")
	_rect(image, x + 37, wall_top - 26, 9, 3, "art-sky-light")
	var cx: int = x + SNOW_COTTAGE_W / 2
	_roof(image, cx, wall_top - 28, wall_top + 1, "ink")
	_roof(image, cx, wall_top - 27, wall_top, "art-sky-light")
	for y: int in range(wall_top - 2, wall_top):
		var half: int = y - (wall_top - 27) + 1
		_rect(image, cx - half + 1, y, 2 * half - 2, 1, "stone-light")
	_box(image, x, wall_top, SNOW_COTTAGE_W, 32, wall_fill)
	for y: int in range(wall_top + 5, LAYER_H - 1, 5):
		_rect(image, x + 1, y, SNOW_COTTAGE_W - 2, 1, wall_line)
	for ix: int in range(x + 3, x + SNOW_COTTAGE_W - 2, 5):
		_rect(image, ix, wall_top + 1, 1, 1 + posmod(ix / 5, 3), "art-sky-light")
	_box(image, x + 8, wall_top + 12, 10, 20, "wood-dark")
	_put(image, x + 15, wall_top + 22, "pumpkin-light")
	_box(image, x + 32, wall_top + 9, 13, 11, "pumpkin-light")
	_rect(image, x + 38, wall_top + 10, 1, 9, "ink")
	_rect(image, x + 33, wall_top + 14, 11, 1, "ink")


## A smiling snowman: three ink-outlined balls (art-sky-light, stone-light shade), coal eyes and smile, a
## carrot nose, a pumpkin scarf and a little pumpkin for a hat, stick arms waving.
func _snowman(image: Image, cx: int) -> void:
	var balls: Array[Vector2i] = [Vector2i(180, 11), Vector2i(162, 8), Vector2i(148, 6)]
	for ball: Vector2i in balls:
		_blob(image, cx, ball.x, ball.y + 1, "ink")
	for ball: Vector2i in balls:
		_blob(image, cx, ball.x, ball.y, "stone-light")
		_blob(image, cx - 1, ball.x - 1, ball.y - 1, "art-sky-light")
	for side: int in [-1, 1]:
		var shoulder: int = cx - 9 if side < 0 else cx + 8
		for i: int in 9:
			_put(image, shoulder + side * i, 160 - i, "wood-dark")
		_put(image, shoulder + side * 9, 150, "wood-dark")
		_put(image, shoulder + side * 8, 149, "wood-dark")
	_put(image, cx - 3, 146, "ink")
	_put(image, cx + 2, 146, "ink")
	_rect(image, cx, 148, 4, 1, "pumpkin")
	_put(image, cx - 3, 150, "ink")
	_rect(image, cx - 2, 151, 4, 1, "ink")
	_put(image, cx + 2, 150, "ink")
	_rect(image, cx - 7, 153, 14, 2, "pumpkin")
	_rect(image, cx + 3, 155, 3, 5, "pumpkin")
	_rect(image, cx - 1, 158, 2, 2, "ink")
	_rect(image, cx - 1, 164, 2, 2, "ink")
	_pumpkin(image, cx, 139, 4)


## A lamp post centred on the seam (x 0): an ink-muted post, a lit pumpkin-light lamp and a snow cap.
func _lamp(image: Image) -> void:
	_rect(image, -1, SNOW_LAMP_TOP + 8, 2, LAYER_H - SNOW_LAMP_TOP - 8, "ink-muted")
	_rect(image, -3, LAYER_H - 4, 6, 4, "ink-muted")
	_box(image, -4, SNOW_LAMP_TOP, 8, 8, "pumpkin-light")
	_rect(image, -5, SNOW_LAMP_TOP - 2, 10, 2, "art-sky-light")


func _save(image: Image, path: String) -> Error:
	if not _ok:
		push_error("%s not written: an earlier check failed" % path)
		return ERR_INVALID_DATA
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
