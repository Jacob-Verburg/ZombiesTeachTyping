extends SceneTree
## Dev-only: writes the Story 6.6 Horde Rush art: the zombie's flash and melt, the Farmer (idle, walk,
## throw), the tomato in flight and its splat, and the Farmhouse backdrop (the lane field and the house).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_horde_rush_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Characters and props follow tools/gen_art_prototypes.gd exactly: ASCII maps, one character per pixel,
## '.' = transparent (keeps what earlier parts painted), '_' = clear to transparent, a legend maps a
## character to a palette NAME. The palette, the zombie legend and the approved zombie maps are read from
## that tool and tools/gen_zombie_run_art.gd (one source); a part here is [map, first row].
## The flash is the walk with a legend swap only (same mask, same ink, so the same anchors).
## Characters are 32x32 frames standing on row 30, props 16x16 (style sheet section 3).
##
## The backdrop is two static layers (they never scroll or tile, so there is no seam rule) drawn from
## shapes at fixed, hard-coded positions: no RNG, so a rerun writes the same bytes. Layers are exempt
## from the ink-outline rule only: palette colours, hard alpha, never candy-yellow (focus) or stamp-red
## (stamp), and no zombie-green or zombie-green-bright where a copy walks (the lanes, x 0-547, y 36-255),
## so a copy never camouflages. The farmhouse has one doorway per lane whose bottom row sits on that
## lane's feet line (horde_rush_level.gd layout). Rules: docs/art-style-sheet.md; tests:
## test_art_sprites.gd, test_art_backdrop.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")
const ZombieRun := preload("res://tools/gen_zombie_run_art.gd")

const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie"
const FARMER_DIR: String = "res://assets/sprites/characters/farmer"
const PROPS_DIR: String = "res://assets/sprites/props"
const BACKDROP_DIR: String = "res://assets/sprites/backdrops/farmhouse"
const CHARACTER_FRAME: int = 32
const PROP_FRAME: int = 16

# --- zombie flash and melt ---

## The flash: ZOMBIE_LEGEND with the skin and the shirt swapped to the pumpkin ramp ("splatted"); ink,
## chalk eyes and teeth and the trousers stay. Stamp red is reserved (DESIGN.md D16).
const FLASH_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"G": "pumpkin",
	"L": "pumpkin-light",
	"g": "wood",
	"w": "chalk",
	"p": "pumpkin-light",
	"d": "pumpkin",
	"b": "wood",
	"B": "wood-dark",
}
## The legend characters the flash recolours; every other one is ZOMBIE_LEGEND's (_init checks it).
const FLASH_OWN_KEYS: Array[String] = ["G", "L", "g", "p", "d"]

## Melt 1 (sit): the head and shirt sit down, legs out in front; from row 23, after the head at row 9.
const MELT_SIT: Array[String] = [
	"..........kppppppppppk..........",
	"..........kdppppppppdk..........",
	"..........kdppppppppdkkkkkkkkkk.",
	"..........kbbbbbbbbbbbbbbbbkGGk.",
	"..........kbbbbbbbbbbbbbbbbkGGk.",
	"..........kBBBBBBBBBBBBBBBBkGGk.",
	"..........kBBBBBBBBBBBBBBBBkggk.",
	"..........kkkkkkkkkkkkkkkkkkkkk.",
]

## Melt 2 (slump): the head sinks onto a spreading green puddle; from row 26, after the head at row 13.
const MELT_SLUMP: Array[String] = [
	"......kkkkggGGGGGGGGGGkkkkkk....",
	".....kGGGGGGGGGLGGGGGGGGGGGGk...",
	"....kgGGGGLGGGGGGGGGGGGGGGGGgk..",
	"...kgggGGGGGGGGGGGGGGGGGGGGgggk.",
	"...kkkkkkkkkkkkkkkkkkkkkkkkkkkk.",
]

## Melt 3: only the eyes and the brow stay above the goo; from row 25, after the head at row 17.
const MELT_SINK: Array[String] = [
	"....kkkkkGGGGGGGGGGGGGGkkkkk....",
	"...kGGGGGGGGGLGGGGGGGGGGGGGGk...",
	"..kgGGLLGGGGGGGGGGGGGGGGGGGGgk..",
	".kgGGGGGGGGGGGGGGGGGGGGGGGGGGgk.",
	".kggGGGGGGGGGGGGGGGGGGGGGGGGggk.",
	".kkkkkkkkkkkkkkkkkkkkkkkkkkkkkk.",
]

## Melt 4: a flat puddle with two goofy eyes on top and a wobbly smile; from row 24.
const MELT_PUDDLE: Array[String] = [
	"..........kkkk..kkkk............",
	"..........kwwk..kwwk............",
	"..........kwkk..kwkk............",
	"....kkkkkkkkkkkkkkkkkkkkkkkk....",
	"...kGGGGLLGGGGkGGGGkGGGGGGGGk...",
	"..kgGGGGGGGGGGGkkkkGGGGGGGGGgk..",
	"..kkkkkkkkkkkkkkkkkkkkkkkkkkkk..",
]

## Melt 5 (held): a small content puddle, eyes closed; from row 26.
const MELT_SMALL: Array[String] = [
	"............kk..kk..............",
	"........kkkkkkkkkkkkkkkk........",
	".......kGGGGGGLGGGGGGGGGk.......",
	"......kgGGGGGGGGGGGGGGGGgk......",
	"......kkkkkkkkkkkkkkkkkkkk......",
]

# --- the Farmer: faces left (toward the field), straw hat, white shirt, stone overalls ---

## s/S are the only skin characters (like the villager); m is the moustache.
const FARMER_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"h": "parchment-shade",
	"H": "wood-light",
	"m": "wood-dark",
	"c": "chalk",
	"o": "stone",
	"O": "ink-muted",
	"B": "wood-dark",
}

## Hat, face and body from row 2 (row 3 on the bob frames); the legs are drawn over rows 25-30.
const FARMER_UPPER: Array[String] = [
	"............kkkkkkkk............",
	"...........khhhhhhhhk...........",
	"...........khhhhhhhhk...........",
	"...........kHHHHHHHHk...........",
	"......kkkkkkhhhhhhhhkkkkkk......",
	".....khhhhhhhhhhhhhhhhhhhhk.....",
	".....kkkkkkkkkkkkkkkkkkkkkk.....",
	".........ksssssssssssSk.........",
	"........ksskssssksssSSk.........",
	"........ksskssssksssSSk.........",
	".......ksssssssssssSSSk.........",
	".......kmmmmmmssssssSSk.........",
	"........kmkkkkksssssSk..........",
	".........kSsssssssssSk..........",
	"..........kkkkkkkkkkk...........",
	"..........kcccccccccck..........",
	".......kkkkcoccccccockkkk.......",
	".......kcckcoccccccockcck.......",
	".......kcckooooooooookcck.......",
	".......ksskookkooooookssk.......",
	".......ksskooooooooookssk.......",
	".......kkkkooooooooookkkk.......",
	"..........kOooooooooOk..........",
]

## Legs from row 25: standing (idle, throw).
const FARMER_LEGS_STAND: Array[String] = [
	"..........kooookkooook..........",
	"..........kOoookkoooOk..........",
	"..........kOoookkoooOk..........",
	"........kkkkkkkkkkkkkk..........",
	"........kBBBBBkkBBBBBk..........",
	"........kkkkkkkkkkkkkk..........",
]

## Walk: contact (front leg forward, shaded far leg back), passing, and the swaps.
const FARMER_WALK_A: Array[String] = [
	"..........kooookkooook..........",
	".........kOOOok..kooook.........",
	"........kOOOok....kooook........",
	".......kkkkkkk....kkkkkk........",
	".......kBBBBBk....kBBBBk........",
	".......kkkkkkk....kkkkkk........",
]

const FARMER_PASS_A: Array[String] = [
	"..........kooookkooook..........",
	"..........kOOOokkoooOk..........",
	"..........kOOOokkoooOk..........",
	"........kkkkkkkkkkkkkk..........",
	"........kBBBBBkkBBBBBk..........",
	"........kkkkkkkkkkkkkk..........",
]

const FARMER_WALK_B: Array[String] = [
	"..........kooookkooook..........",
	".........kooook..kOOOok.........",
	"........kooook....kOOOok........",
	".......kkkkkkk....kkkkkk........",
	".......kBBBBBk....kBBBBk........",
	".......kkkkkkk....kkkkkk........",
]

const FARMER_PASS_B: Array[String] = [
	"..........kooookkooook..........",
	"..........kOoookkOOOOk..........",
	"..........kOoookkOOOOk..........",
	"........kkkkkkkkkkkkkk..........",
	"........kBBBBBkkBBBBBk..........",
	"........kkkkkkkkkkkkkk..........",
]

## Clears the front (left) or back (right) hanging arm, rows 18-23; the torso keeps its ink edge.
const FARMER_FRONT_ARM_ERASE: Array[String] = [
	".......___......................",
	".......___......................",
	".......___......................",
	".......___......................",
	".......___......................",
	".......___......................",
]

const FARMER_BACK_ARM_ERASE: Array[String] = [
	"......................___.......",
	"......................___.......",
	"......................___.......",
	"......................___.......",
	"......................___.......",
	"......................___.......",
]

## Throw 1 (wind-up): the back arm out behind at chest height, from row 17. The empty hand is where the
## tomato appears (horde_rush_level.gd: x DEFENDER_X + 12, TOMATO_RISE_PX above the feet).
const FARMER_ARM_BACK: Array[String] = [
	".....................kkkkkkkkk..",
	".....................kcccccsssk.",
	".....................kcccccsssk.",
	".....................kkkkkkkkkk.",
]

## Throw 2 (release): the front arm straight out toward the field, from row 17.
const FARMER_ARM_FORWARD: Array[String] = [
	".kkkkkkkkkk.....................",
	".ksssccccc......................",
	".ksssccccc......................",
	".kkkkkkkkkk.....................",
]

## Throw 3 (follow-through): the front arm swung down and forward, from row 17.
const FARMER_ARM_DOWN: Array[String] = [
	"......kkkk......................",
	"......kcck......................",
	".....kcck.......................",
	"....kcck........................",
	"...kssk.........................",
	"...kssk.........................",
	"...kkkk.........................",
]

# --- props: 16x16 ---

## A tomato (pumpkin, D16: never stamp red) with a leaf and seeds; it is fruit, never blood.
const TOMATO_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"T": "pumpkin",
	"t": "pumpkin-light",
	"l": "zombie-green-dark",
	"e": "parchment-shade",
}

const TOMATO_A: Array[String] = [
	".......kk.......",
	"......kllk......",
	".....kTllTk.....",
	"....ktTTTTTk....",
	"....kttTTTTk....",
	"....kTTTTTTk....",
	".....kTTTTk.....",
	"......kkkk......",
]

## Spun a quarter turn: the leaf on the side.
const TOMATO_B: Array[String] = [
	"................",
	"......kkkk......",
	".....kTTTlk.....",
	"....kTTTTllk....",
	"....kTTTTTtk....",
	"....kTTTTttk....",
	".....kTTTtk.....",
	"......kkkk......",
]

## Splat 1: squished flat, from row 8.
const SPLAT_SQUISH: Array[String] = [
	"....kkkkkkkk....",
	"...kTtTTTTTTk...",
	"..kTTTTllTTTTk..",
	"..kTTTTTTTTTTk..",
	"...kkkkkkkkkk...",
]

## Splat 2: burst wide, seeds and a leaf bit, two drips, from row 4.
const SPLAT_BURST: Array[String] = [
	"......kk........",
	"..kk.kttk...kk..",
	".kTTkkTTTkkkTTk.",
	".kTTTTTeTTTTTTk.",
	"kTTeTTlTTTTTeTTk",
	".kTTTTTTTTTTTTk.",
	"..kkTkkkkkkTkk..",
	"...kTk....kTk...",
	"....k......k....",
]

## Splat 3: a small puddle with two drips running off, from row 8.
const SPLAT_DRIP: Array[String] = [
	"...kkkkkkkkkk...",
	"..kTTeTTTTeTTk..",
	"...kkTkkkkTkk...",
	"....kTk..kTk....",
	".....k....k.....",
]

## Sheet path -> size, legend and frames; a frame is a list of parts. A var, not a const: the melt
## frames slice the zombie's upper map (head only).
var sheets: Dictionary[String, Dictionary] = {
	ZOMBIE_DIR + "/zombie_flash.png": {
		"size": CHARACTER_FRAME,
		"legend": FLASH_LEGEND,
		"frames": [
			[[Proto.WALK_A, 23], [Proto.ZOMBIE_UPPER, 2]],
			[[Proto.PASS_A, 23], [Proto.ZOMBIE_UPPER, 1]],
			[[Proto.WALK_B, 23], [Proto.ZOMBIE_UPPER, 2]],
			[[Proto.PASS_B, 23], [Proto.ZOMBIE_UPPER, 1]],
		],
	},
	ZOMBIE_DIR + "/zombie_melt.png": {
		"size": CHARACTER_FRAME,
		"legend": Proto.ZOMBIE_LEGEND,
		"frames": [
			# Topple: the hop's crouch with both arms flung up ("ouch!").
			[[ZombieRun.LEGS_CROUCH, 25], [Proto.ZOMBIE_UPPER, 3], [ZombieRun.ARM_ERASE, 17],
					[ZombieRun.LEFT_ARM_UP, 10], [ZombieRun.RIGHT_ARM_UP, 10]],
			[[Proto.ZOMBIE_UPPER.slice(0, 14), 9], [MELT_SIT, 23]],
			[[Proto.ZOMBIE_UPPER.slice(0, 13), 13], [MELT_SLUMP, 26]],
			[[Proto.ZOMBIE_UPPER.slice(0, 8), 17], [MELT_SINK, 25]],
			[[MELT_PUDDLE, 24]],
			[[MELT_SMALL, 26]],
		],
	},
	FARMER_DIR + "/farmer_idle.png": {
		"size": CHARACTER_FRAME,
		"legend": FARMER_LEGEND,
		"frames": [
			[[FARMER_UPPER, 2], [FARMER_LEGS_STAND, 25]],
			[[FARMER_UPPER, 3], [FARMER_LEGS_STAND, 25]],
		],
	},
	FARMER_DIR + "/farmer_walk.png": {
		"size": CHARACTER_FRAME,
		"legend": FARMER_LEGEND,
		"frames": [
			[[FARMER_UPPER, 3], [FARMER_WALK_A, 25]],
			[[FARMER_UPPER, 2], [FARMER_PASS_A, 25]],
			[[FARMER_UPPER, 3], [FARMER_WALK_B, 25]],
			[[FARMER_UPPER, 2], [FARMER_PASS_B, 25]],
		],
	},
	FARMER_DIR + "/farmer_throw.png": {
		"size": CHARACTER_FRAME,
		"legend": FARMER_LEGEND,
		"frames": [
			[[FARMER_UPPER, 2], [FARMER_LEGS_STAND, 25], [FARMER_BACK_ARM_ERASE, 18], [FARMER_ARM_BACK, 17]],
			[[FARMER_UPPER, 2], [FARMER_LEGS_STAND, 25], [FARMER_FRONT_ARM_ERASE, 18], [FARMER_ARM_FORWARD, 17]],
			[[FARMER_UPPER, 2], [FARMER_LEGS_STAND, 25], [FARMER_FRONT_ARM_ERASE, 18], [FARMER_ARM_DOWN, 17]],
		],
	},
	PROPS_DIR + "/tomato_fly.png": {
		"size": PROP_FRAME,
		"legend": TOMATO_LEGEND,
		"frames": [[[TOMATO_A, 4]], [[TOMATO_B, 4]]],
	},
	PROPS_DIR + "/tomato_splat.png": {
		"size": PROP_FRAME,
		"legend": TOMATO_LEGEND,
		"frames": [[[SPLAT_SQUISH, 8]], [[SPLAT_BURST, 4]], [[SPLAT_DRIP, 8]]],
	},
}

# --- backdrop: field.png (640 x 256, at (0, 0)) and farmhouse.png (92 x 256, at (548, 0)) ---

const FIELD_W: int = 640
const FIELD_H: int = 256
const HOUSE_W: int = 92
## horde_rush_level.gd layout: FIELD_TOP_Y, LANE_HEIGHT_PX, LANE_FEET_INSET_PX, HOUSE_FRONT_X.
const SKY_H: int = 36
const LANE_H: int = 44
const LANE_COUNT: int = 5
const FEET_INSET: int = 6
const HOUSE_X: int = 548
## Each lane: a grass and crop edge of EDGE_PX at its top and bottom (so lanes are split by an 8 px crop
## strip), soil in between with a furrow line every FURROW_STEP px.
const EDGE_PX: int = 4
const FURROW_STEP: int = 6
const FURROW_PERIOD: int = 37
const FURROW_DASH: int = 26
## Clouds in the sky band: [centre x, bottom y, puff size].
const CLOUDS: Array[Vector3i] = [Vector3i(70, 20, 4), Vector3i(250, 14, 3), Vector3i(410, 22, 5)]
## Small pumpkins in the crop strips: [x, strip index]; strip 0 is above lane 0, strip i (1-4) between
## lanes i-1 and i, strip 5 below lane 4. Kept to the strips so the middle of every lane stays calm.
const PUMPKINS: Array[Vector2i] = [
	Vector2i(120, 1), Vector2i(330, 1), Vector2i(60, 2), Vector2i(270, 2), Vector2i(470, 2),
	Vector2i(190, 3), Vector2i(400, 3), Vector2i(90, 4), Vector2i(310, 4), Vector2i(150, 5), Vector2i(450, 5),
]
## The hay bale on the horizon (left edge x), like the level card's.
const HAY_X: int = 470
## The doorway: an opening of DOOR_W x DOOR_H at the house's field edge, its bottom row on the lane's
## feet line - 1 (the copies' soles row), the open door leaf beside it.
const DOOR_W: int = 16
const DOOR_H: int = 30
const LEAF_W: int = 8
const WINDOW_X: int = 44
## The roof: its left edge rises one px per row from (ROOF_LEFT_Y, x 0) to the flat top at ROOF_TOP_Y;
## the eave (wood-dark, under the pause button) runs to EAVE_BOTTOM_Y.
const ROOF_TOP_Y: int = 4
const ROOF_LEFT_Y: int = 30
const EAVE_BOTTOM_Y: int = 40
const CHIMNEY_X: int = 66


func _init() -> void:
	var errors: Array[Error] = [_check_flash_legend()]
	for dir: String in [ZOMBIE_DIR, FARMER_DIR, PROPS_DIR, BACKDROP_DIR]:
		errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	for path: String in sheets:
		var sheet: Dictionary = sheets[path]
		var legend: Dictionary[String, String] = sheet["legend"]
		var image: Image = _sheet_image(sheet["frames"], legend, sheet["size"])
		errors.append(_save(image, path) if image != null else ERR_INVALID_DATA)
	errors.append(_save(_field_image(), BACKDROP_DIR + "/field.png"))
	errors.append(_save(_farmhouse_image(), BACKDROP_DIR + "/farmhouse.png"))
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## The flash is a walk recolour: every legend entry it doesn't own is the zombie's.
func _check_flash_legend() -> Error:
	for ch: String in Proto.ZOMBIE_LEGEND:
		if ch in FLASH_OWN_KEYS:
			continue
		if FLASH_LEGEND.get(ch, "") != Proto.ZOMBIE_LEGEND[ch]:
			push_error("FLASH_LEGEND '%s' does not mirror ZOMBIE_LEGEND" % ch)
			return ERR_INVALID_DATA
	return OK


func _color(color_name: String) -> Color:
	return Color.html(Proto.PALETTE[color_name])


## One horizontal strip, `size` px per frame. Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String], size: int) -> Image:
	var image: Image = Image.create_empty(frames.size() * size, size, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array = part[0]
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
					if ch == "_":
						image.set_pixel(i * size + x, top + y, Color(0, 0, 0, 0))
						continue
					if not legend.has(ch) or not Proto.PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * size + x, top + y, _color(legend[ch]))
	return image


# --- shape helpers (clipped to the image, no wrap: these layers never tile) ---

func _put(image: Image, x: int, y: int, color_name: String) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, _color(color_name))


func _rect(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_put(image, xx, yy, color_name)


## A rect with a 1 px ink border.
func _box(image: Image, x: int, y: int, w: int, h: int, color_name: String) -> void:
	_rect(image, x, y, w, h, "ink")
	_rect(image, x + 1, y + 1, w - 2, h - 2, color_name)


## An even-width disc centred on the pixel boundary at cx, rows cy - r .. cy + r - 1.
func _blob(image: Image, cx: int, cy: int, r: int, color_name: String) -> void:
	for dy: int in range(-r, r):
		var yc: float = dy + 0.5
		var h: int = maxi(1, roundi(sqrt(maxf(0.0, r * r - yc * yc))))
		for x: int in range(cx - h, cx + h):
			_put(image, x, cy + dy, color_name)


## Feet line (field y) of lane `lane`: the copies' soles sit on the row above it.
func _feet_y(lane: int) -> int:
	return SKY_H + LANE_H * (lane + 1) - FEET_INSET


func _field_image() -> Image:
	var image: Image = Image.create_empty(FIELD_W, FIELD_H, false, Image.FORMAT_RGBA8)
	_rect(image, 0, 0, FIELD_W, SKY_H, "art-sky")
	for cloud: Vector3i in CLOUDS:
		var s: int = cloud.z
		_rect(image, cloud.x - 2 * s, cloud.y - s, 4 * s, s, "art-sky-light")
		_blob(image, cloud.x - s, cloud.y - s, s, "art-sky-light")
		_blob(image, cloud.x + s, cloud.y - s, s, "art-sky-light")
		_blob(image, cloud.x, cloud.y - s - s / 2, s + 1, "art-sky-light")
	# The horizon: low green hills (above the lanes, so the zombie greens are allowed here).
	for x: int in FIELD_W:
		var top: int = SKY_H - 4 - roundi(2.0 + 2.0 * sin(TAU * x / 160.0))
		_rect(image, x, top, 1, SKY_H - top, "art-grass")
		_put(image, x, top, "zombie-green-dark")
	_hay_bale(image, HAY_X, SKY_H - 1)
	for lane: int in LANE_COUNT:
		_lane(image, SKY_H + lane * LANE_H)
	for pumpkin: Vector2i in PUMPKINS:
		_pumpkin(image, pumpkin.x, _strip_bottom(pumpkin.y))
	return image


## The bottom row of crop strip `strip` (see PUMPKINS).
func _strip_bottom(strip: int) -> int:
	return mini(SKY_H + strip * LANE_H + EDGE_PX - 1, FIELD_H - 1)


## One lane from `top`: a grass and crop edge, soil rows with furrows, a grass and crop edge.
func _lane(image: Image, top: int) -> void:
	_rect(image, 0, top, FIELD_W, LANE_H, "parchment-shade")
	# Plough lines: broken furrows (FURROW_DASH px on, the rest of FURROW_PERIOD off), each row offset, so
	# the soil reads as earth, not planks.
	for y: int in range(top + EDGE_PX + FURROW_STEP - 2, top + LANE_H - EDGE_PX, FURROW_STEP):
		for x: int in FIELD_W:
			if posmod(x + y * 13, FURROW_PERIOD) < FURROW_DASH:
				_put(image, x, y, "wood-light")
	# A few clods along the furrows, at fixed spots (no RNG).
	for i: int in 24:
		var x: int = (i * 53 + top * 7) % (FIELD_W - 8)
		var y: int = top + EDGE_PX + FURROW_STEP - 2 + FURROW_STEP * (i % 5)
		_rect(image, x, y, 2, 1, "wood")
	for edge_top: int in [top, top + LANE_H - EDGE_PX]:
		_rect(image, 0, edge_top, FIELD_W, EDGE_PX, "art-grass")
	# Crop leaves on the strips: little dark-green sprouts every 8 px.
	for x: int in range(3, FIELD_W, 8):
		for edge_top: int in [top, top + LANE_H - EDGE_PX]:
			_put(image, x, edge_top + 1, "zombie-green-dark")
			_put(image, x - 1, edge_top + 2, "zombie-green-dark")
			_put(image, x + 1, edge_top + 2, "zombie-green-dark")


## A small pumpkin (7 x 5 with its stem) whose bottom ink row is `bottom`.
func _pumpkin(image: Image, x: int, bottom: int) -> void:
	_box(image, x, bottom - 4, 7, 5, "pumpkin")
	_rect(image, x + 1, bottom - 3, 1, 2, "pumpkin-light")
	_put(image, x + 3, bottom - 3, "wood-dark")
	_put(image, x + 3, bottom - 5, "zombie-green-dark")


## The hay bale: parchment-shade with wood-light bands and an ink border, standing on `bottom`.
func _hay_bale(image: Image, x: int, bottom: int) -> void:
	_box(image, x, bottom - 8, 16, 9, "parchment-shade")
	_rect(image, x + 4, bottom - 7, 1, 7, "wood-light")
	_rect(image, x + 11, bottom - 7, 1, 7, "wood-light")


func _farmhouse_image() -> Image:
	var image: Image = Image.create_empty(HOUSE_W, FIELD_H, false, Image.FORMAT_RGBA8)
	# The wall: wood-light planks with wood seams, an ink corner on the field side.
	_rect(image, 0, SKY_H, HOUSE_W, FIELD_H - SKY_H, "wood-light")
	for y: int in range(SKY_H + 3, FIELD_H, 5):
		_rect(image, 1, y, HOUSE_W - 1, 1, "wood")
	_rect(image, 0, SKY_H, 1, FIELD_H - SKY_H, "ink")
	# The roof: rises from the corner to a flat top, shingle rows, an ink edge; the eave below it.
	for y: int in range(ROOF_TOP_Y, SKY_H):
		var left: int = maxi(0, ROOF_LEFT_Y - y)
		_rect(image, left, y, HOUSE_W - left, 1, "wood-dark")
		_put(image, left, y, "ink")
		if (y - ROOF_TOP_Y) % 4 == 3:
			_rect(image, left + 1, y, HOUSE_W - left - 1, 1, "wood")
	_rect(image, ROOF_LEFT_Y - ROOF_TOP_Y, ROOF_TOP_Y, HOUSE_W, 1, "ink")
	_box(image, 0, SKY_H - 4, HOUSE_W + 1, EAVE_BOTTOM_Y - SKY_H + 4, "wood-dark")
	_box(image, CHIMNEY_X, 0, 9, ROOF_TOP_Y + 3, "stone")
	_rect(image, CHIMNEY_X + 1, 1, 7, 1, "stone-light")
	for lane: int in LANE_COUNT:
		_doorway(image, _feet_y(lane))
	return image


## One lane's doorway: a dark opening at the field edge whose bottom row is `feet` - 1 (the soles row),
## an ink lintel and jamb, the pumpkin door swung open beside it, a stone step, and a window.
func _doorway(image: Image, feet: int) -> void:
	var top: int = feet - DOOR_H
	_rect(image, 0, top - 1, DOOR_W + 1, DOOR_H + 1, "ink")
	_rect(image, 0, top, DOOR_W, DOOR_H, "night")
	_rect(image, 0, feet - 3, DOOR_W, 3, "dusk")
	_box(image, DOOR_W, top - 1, LEAF_W + 1, DOOR_H + 1, "pumpkin")
	_rect(image, DOOR_W + 2, top + 2, LEAF_W - 3, 1, "pumpkin-light")
	_put(image, DOOR_W + 2, top + DOOR_H / 2, "ink")
	_box(image, 0, feet, DOOR_W + LEAF_W + 1, 3, "stone-light")
	_box(image, WINDOW_X, top + 4, 14, 12, "art-sky-light")
	_rect(image, WINDOW_X + 7, top + 5, 1, 10, "ink")
	_rect(image, WINDOW_X + 1, top + 10, 12, 1, "ink")
	_box(image, WINDOW_X - 2, top + 15, 18, 3, "wood-dark")


func _save(image: Image, path: String) -> Error:
	if image == null:
		return ERR_INVALID_DATA
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
