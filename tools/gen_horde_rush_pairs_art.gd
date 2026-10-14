extends SceneTree
## Dev-only: writes the Story 10.3 Horde Rush house + defender pairs: the Castle with the Knight (a toy
## suction-cup dart and its boing) and the Beach Hut with the Lifeguard (a water balloon and its splash).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_horde_rush_pairs_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Characters and props follow tools/gen_horde_rush_art.gd (the Farmhouse pair, Story 6.6) exactly: ASCII
## maps, one character per pixel, '.' = transparent (keeps what earlier parts painted), '_' = clear to
## transparent, a legend maps a character to a palette NAME; a part is [map, first row]. Characters are 32x32
## frames standing on row 30, facing left; props 16x16 (style sheet section 3). The palette and the Farmer's
## leg rhythm and arm erasers are read from those tools (one source); that tool is never edited, so its PNGs
## stay byte-identical.
##
## Each backdrop is two static layers (field.png at (0, 0), the house at (548, 0)) drawn from shapes at
## fixed, hard-coded positions: no RNG, so a rerun writes the same bytes. The Farmhouse layout: a sky band
## (y 0-35), five 44 px lanes, one doorway per lane whose bottom row is that lane's soles row, the roof/top
## under the pause button. Layers are exempt from the ink-outline rule only.
## Never anywhere: candy-yellow (focus), stamp-red (the stamp, never blood, D16), art-moon (the moon); _init
## exits non-zero when a legend or a shape asks for one. No zombie-green or zombie-green-bright where a copy
## walks (the lanes, x 0-547, y 36-255, and the house's first 8 px), so a copy never camouflages; a lane
## floor is never wood. No weapons: the Knight throws a toy dart by hand (big rubber cup, no point), the
## Lifeguard lobs a water balloon. No letters, numbers or text-like marks.
## Rules: docs/art-style-sheet.md; tests: test_art_sprites.gd, test_art_backdrop.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")
const Farm := preload("res://tools/gen_horde_rush_art.gd")

const KNIGHT_DIR: String = "res://assets/sprites/characters/knight"
const LIFEGUARD_DIR: String = "res://assets/sprites/characters/lifeguard"
const PROPS_DIR: String = "res://assets/sprites/props"
const CASTLE_DIR: String = "res://assets/sprites/backdrops/castle"
const BEACH_DIR: String = "res://assets/sprites/backdrops/beach_hut"
const CHARACTER_FRAME: int = 32
const PROP_FRAME: int = 16
## Never drawn by this tool (see the header).
const RESERVED: Array[String] = ["candy-yellow", "stamp-red", "art-moon"]

# --- the Knight: faces left, round helmet with the visor up, pumpkin plume, sky tabard ---

## s/S are the only skin characters. The leg maps are the Farmer's (o = greaves, O = the far leg, B = boots).
const KNIGHT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"h": "stone-light",
	"H": "stone",
	"O": "ink-muted",
	"o": "stone-light",
	"p": "pumpkin",
	"P": "pumpkin-light",
	"t": "art-sky",
	"c": "chalk",
	"B": "wood-dark",
}

## Plume, helmet, face and body from row 2; the legs are drawn over rows 25-30. Arms on rows 18-23 like
## the Farmer's, so his arm erasers fit.
const KNIGHT_UPPER: Array[String] = [
	"...............kkkk.............",
	"..............kPPppk............",
	"..............kpPppk............",
	"...............kpppk............",
	"..........kkkkkkpppkkkk.........",
	".........khhhhhhhhhhhhk.........",
	"........khhhhhhhhhhhhHk.........",
	"........kHHHHHHHHHhhhHk.........",
	"........ksssssssshhhhHk.........",
	"........ksksssksshhhhHk.........",
	"........ksksssksshhhhHk.........",
	".......ksssssssssshhhHk.........",
	"........ksskkkkssSShhHk.........",
	".........kSssssssSShhHk.........",
	"..........kkkkkkkkkkkkk.........",
	"..........khhhhhhhhhhk..........",
	".......kkkkhtttttttthkkkk.......",
	".......khhkhtttttttthkhhk.......",
	".......kHHkhtttttttthkHHk.......",
	".......kOOkhtttttttthkOOk.......",
	".......ksskBBBBBBBBBBkssk.......",
	".......kkkkhtttttttthkkkk.......",
	"..........khtttttttthk..........",
]

## Throw 1 (wind-up), from row 7: the back arm raised over the shoulder, the dart (cup leading, no point)
## held flat above the helmet's back. The hand is near where the dart appears (x DEFENDER_X + 12).
const KNIGHT_ARM_WINDUP: Array[String] = [
	"...................kk......kk...",
	"..................kpPkkkkkktk...",
	"..................kpPkccccctk...",
	"..................kpPkkkkkktk...",
	"...................kk.kssk.kk...",
	"......................kssk......",
	"......................khhk......",
	"......................kHhk......",
	"......................kOOk......",
	".....................khhhk......",
	".....................khhhk......",
	".....................kkkkk......",
]

## Throw 2 (release): the front arm straight out toward the field at chest height, from row 17.
const KNIGHT_ARM_FORWARD: Array[String] = [
	".kkkkkkkkkk.....................",
	".ksssHhhhh......................",
	".ksssHHHHH......................",
	".kkkkkkkkkk.....................",
]

## Throw 3 (follow-through): the front arm swung down and forward, from row 17.
const KNIGHT_ARM_DOWN: Array[String] = [
	"......kkkk......................",
	"......khhk......................",
	".....khhk.......................",
	"....khhk........................",
	"...kssk.........................",
	"...kssk.........................",
	"...kkkk.........................",
]

# --- the Lifeguard: faces left, dark hair and a visor, zinc on the nose, a whistle, pumpkin tank top ---

## S (art-skin-dark) is the main skin, s (art-skin-light) the highlights. The leg maps are the Farmer's:
## o = knee-length board shorts, O = the far leg's shade, B = bare feet.
const LIFEGUARD_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"w": "wood-dark",
	"c": "chalk",
	"V": "art-sky",
	"r": "stone",
	"W": "stone-light",
	"p": "pumpkin",
	"a": "art-sky",
	"o": "art-sky",
	"O": "stone",
	"B": "art-skin-dark",
	"A": "art-sky-light",
}

const LIFEGUARD_UPPER: Array[String] = [
	"................................",
	"................................",
	"...........kkkkkkkkk............",
	"..........kwwwwwwwwwk...........",
	".........kwwwwwwwwwwwk..........",
	"......kkkkkccccccccccck.........",
	".....kVVVVVkkkkkkkkwwwk.........",
	"......kkkkSSSSSSSSSwwk..........",
	"........kSkSSSkSSSSSwk..........",
	"........kSkSSSkSSSSSwk..........",
	".......kcccSSSSSSSSSSk..........",
	"........kSskkkkSSSSSSk..........",
	".........kSSSSSSSSSSk...........",
	"..........kkkkkkkkkk............",
	"..........kSSSSSSSSk............",
	"..........kSrSSSSrSk............",
	".......kkkkpprpppprpkkkkk.......",
	".......kSSkppprpprpppkSSk.......",
	".......kSSkppppWWppppkSSk.......",
	".......kSSkppppppppppkSSk.......",
	".......kSskaaaaaaaaaakSsk.......",
	".......kkkkaaaaaaaaaakkkk.......",
	"..........kaaaaaaaaaak..........",
]

## Throw 1 (wind-up), from row 18: the back arm low behind him, the balloon in his hand.
const LIFEGUARD_ARM_LOW_BACK: Array[String] = [
	".....................kkkk.......",
	".....................kSSk.......",
	"......................kSSkkkkkk.",
	".......................kSsscAaak",
	".......................ksssAaaak",
	".......................kkkkaaaak",
	"...........................kkkk.",
]

## Throw 2 (release): the front arm swung forward at chest height, from row 17.
const LIFEGUARD_ARM_FORWARD: Array[String] = [
	".kkkkkkkkkk.....................",
	".ksssSSSSS......................",
	".ksssSSSSS......................",
	".kkkkkkkkkk.....................",
]

## Throw 3 (follow-through): the front arm swung up and forward (an underarm lob ends high), from row 11.
const LIFEGUARD_ARM_UP: Array[String] = [
	"..kkkk..........................",
	"..kssk..........................",
	"..kssk..........................",
	"...kSSk.........................",
	"....kSSk........................",
	".....kSSk.......................",
	"......kSSk......................",
	".......kkkk.....................",
]

# --- props: 16x16 ---

## The toy dart: a big rubber cup leading (pumpkin rim, pumpkin-light cup), a chalk shaft, sky fletching.
const DART_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"p": "pumpkin",
	"P": "pumpkin-light",
	"c": "chalk",
	"t": "art-sky",
}

## In flight, from row 7: 11 x 5, the cup on the left.
const DART_A: Array[String] = [
	"...kk......kk...",
	"..kpPkkkkkktk...",
	"..kpPkccccctk...",
	"..kpPkkkkkktk...",
	"...kk......kk...",
]

## The wobble, from row 6: the fletching up 1 px.
const DART_B: Array[String] = [
	"...........kk...",
	"...kk.....ktk...",
	"..kpPkkkkkktk...",
	"..kpPkccccckk...",
	"..kpPkkkkkk.....",
	"...kk...........",
]

## Hit 1, from row 3: the cup squashed flat against the copy, two impact dashes on the copy's side.
const DART_SQUASH: Array[String] = [
	"kkkk............",
	"kcck.kk.........",
	"kkkkkpPk........",
	"....kpPkkkkkkkk.",
	"....kpPkccccctk.",
	"....kpPkkkkkkkk.",
	"kkkkkpPk........",
	"kcck.kk.........",
	"kkkk............",
]

## Hit 2, from row 5: the dart springs off, tilted, with a boing squiggle where it was.
const DART_BOING: Array[String] = [
	".......kk...kkk.",
	"......kpPkkkkctk",
	"......kpPkcccckk",
	"......kpPkkkkk..",
	".......kk.......",
	"..k...k.........",
	".k.k.k.k........",
]

## Hit 3, from row 7: a tiny chalk star puff, nothing left on the copy.
const DART_PUFF: Array[String] = [
	".......k........",
	"..k...kck...k...",
	".....kccck......",
	"......kck.......",
	"...k...k...k....",
]

## The water balloon: sky with a light highlight and a chalk glint, a knot trailing behind.
const BALLOON_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"a": "art-sky",
	"A": "art-sky-light",
	"c": "chalk",
}

## In flight, from row 5: 8 x 6, the knot on the right.
const BALLOON_A: Array[String] = [
	".....kkkk.......",
	"....kcAaak......",
	"....kAaaakk.....",
	"....kaaaaaak....",
	"....kaaaakk.....",
	".....kkkk.......",
]

## The wobble, from row 6: squished 1 px.
const BALLOON_B: Array[String] = [
	".....kkkk.......",
	"....kcAaakk.....",
	"....kAaaaaak....",
	"....kaaaakk.....",
	".....kkkk.......",
]

## Splash 1, from row 6: the balloon flattens with a burst ring of dashes.
const SPLASH_FLATTEN: Array[String] = [
	"..k.........k...",
	"....kkkkkkkk....",
	"...kcAaaaaaak...",
	"...kaaaaaaaak...",
	"....kkkkkkkk....",
	"..k.........k...",
]

## Splash 2, from row 2: a wide splash, droplets thrown up, a puddle below.
const SPLASH_WIDE: Array[String] = [
	".kkk......kkk...",
	".kAk..kkk.kak...",
	".kkk..kck.kkk...",
	"......kkk.......",
	"...kkk.....kkk..",
	"...kak.....kAk..",
	".kkkkkkkkkkkkkk.",
	"kaAaacaaaaAaaak.",
	"kaaaaaaaaaaaaak.",
	".kkkkkkkkkkkkkk.",
]

## Splash 3, from row 4: a few drops falling at different heights into a flat puddle.
const SPLASH_DROPS: Array[String] = [
	"..kkk...........",
	"..kak.....kkk...",
	"..kkk.....kAk...",
	"..........kkk...",
	"......kkk.......",
	"......kak.......",
	"...kkkkkkkkkk...",
	"...kaaacaaaak...",
	"...kkkkkkkkkk...",
]

## Sheet path -> size, legend and frames; a frame is a list of parts.
var sheets: Dictionary[String, Dictionary] = {
	KNIGHT_DIR + "/knight_idle.png": {
		"size": CHARACTER_FRAME,
		"legend": KNIGHT_LEGEND,
		"frames": [
			[[KNIGHT_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25]],
			[[KNIGHT_UPPER, 3], [Farm.FARMER_LEGS_STAND, 25]],
		],
	},
	KNIGHT_DIR + "/knight_walk.png": {
		"size": CHARACTER_FRAME,
		"legend": KNIGHT_LEGEND,
		"frames": [
			[[KNIGHT_UPPER, 3], [Farm.FARMER_WALK_A, 25]],
			[[KNIGHT_UPPER, 2], [Farm.FARMER_PASS_A, 25]],
			[[KNIGHT_UPPER, 3], [Farm.FARMER_WALK_B, 25]],
			[[KNIGHT_UPPER, 2], [Farm.FARMER_PASS_B, 25]],
		],
	},
	KNIGHT_DIR + "/knight_throw.png": {
		"size": CHARACTER_FRAME,
		"legend": KNIGHT_LEGEND,
		"frames": [
			[[KNIGHT_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25], [Farm.FARMER_BACK_ARM_ERASE, 18],
					[KNIGHT_ARM_WINDUP, 7]],
			[[KNIGHT_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25], [Farm.FARMER_FRONT_ARM_ERASE, 18],
					[KNIGHT_ARM_FORWARD, 17]],
			[[KNIGHT_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25], [Farm.FARMER_FRONT_ARM_ERASE, 18],
					[KNIGHT_ARM_DOWN, 17]],
		],
	},
	LIFEGUARD_DIR + "/lifeguard_idle.png": {
		"size": CHARACTER_FRAME,
		"legend": LIFEGUARD_LEGEND,
		"frames": [
			[[LIFEGUARD_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25]],
			[[LIFEGUARD_UPPER, 3], [Farm.FARMER_LEGS_STAND, 25]],
		],
	},
	LIFEGUARD_DIR + "/lifeguard_walk.png": {
		"size": CHARACTER_FRAME,
		"legend": LIFEGUARD_LEGEND,
		"frames": [
			[[LIFEGUARD_UPPER, 3], [Farm.FARMER_WALK_A, 25]],
			[[LIFEGUARD_UPPER, 2], [Farm.FARMER_PASS_A, 25]],
			[[LIFEGUARD_UPPER, 3], [Farm.FARMER_WALK_B, 25]],
			[[LIFEGUARD_UPPER, 2], [Farm.FARMER_PASS_B, 25]],
		],
	},
	LIFEGUARD_DIR + "/lifeguard_throw.png": {
		"size": CHARACTER_FRAME,
		"legend": LIFEGUARD_LEGEND,
		"frames": [
			[[LIFEGUARD_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25], [Farm.FARMER_BACK_ARM_ERASE, 18],
					[LIFEGUARD_ARM_LOW_BACK, 18]],
			[[LIFEGUARD_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25], [Farm.FARMER_FRONT_ARM_ERASE, 18],
					[LIFEGUARD_ARM_FORWARD, 17]],
			[[LIFEGUARD_UPPER, 2], [Farm.FARMER_LEGS_STAND, 25], [Farm.FARMER_FRONT_ARM_ERASE, 18],
					[LIFEGUARD_ARM_UP, 11]],
		],
	},
	PROPS_DIR + "/dart_fly.png": {
		"size": PROP_FRAME,
		"legend": DART_LEGEND,
		"frames": [[[DART_A, 7]], [[DART_B, 6]]],
	},
	PROPS_DIR + "/dart_hit.png": {
		"size": PROP_FRAME,
		"legend": DART_LEGEND,
		"frames": [[[DART_SQUASH, 3]], [[DART_BOING, 5]], [[DART_PUFF, 7]]],
	},
	PROPS_DIR + "/water_balloon_fly.png": {
		"size": PROP_FRAME,
		"legend": BALLOON_LEGEND,
		"frames": [[[BALLOON_A, 5]], [[BALLOON_B, 6]]],
	},
	PROPS_DIR + "/water_balloon_splash.png": {
		"size": PROP_FRAME,
		"legend": BALLOON_LEGEND,
		"frames": [[[SPLASH_FLATTEN, 6]], [[SPLASH_WIDE, 2]], [[SPLASH_DROPS, 3]]],
	},
}

# --- backdrops: field.png (640 x 256, at (0, 0)) and the house (92 x 256, at (548, 0)) ---

## Each lane: a separator edge of EDGE_PX at its top and bottom (8 px between lanes), the floor between.
const EDGE_PX: int = 4

## Castle: clouds [centre x, bottom y, puff size]; distant towers [left x, top y, width] on the horizon,
## each with a pennant (no emblem); the jousting fence posts every POST_STEP px; pennants on the rails every
## PENNANT_STEP px; rake lines every RAKE_STEP rows.
const CASTLE_CLOUDS: Array[Vector3i] = [Vector3i(60, 14, 3), Vector3i(300, 18, 4), Vector3i(470, 12, 3)]
const TOWERS: Array[Vector3i] = [Vector3i(130, 14, 12), Vector3i(150, 20, 10), Vector3i(380, 16, 12),
		Vector3i(398, 22, 9)]
const POST_STEP: int = 48
const PENNANT_STEP: int = 12
const RAKE_STEP: int = 6
## The castle wall: a course every COURSE_H rows, a joint every BLOCK_W px, offset by half a block each
## course (a running bond); merlons MERLON_W wide every MERLON_STEP px from WALL_TOP_Y - MERLON_H.
const COURSE_H: int = 6
const BLOCK_W: int = 12
const WALL_TOP_Y: int = 14
const MERLON_H: int = 8
const MERLON_W: int = 10
const MERLON_STEP: int = 16
## The banner between the merlons (left x, width, bottom y), a swallowtail at the bottom.
const BANNER_X: int = 58
const BANNER_W: int = 12
const BANNER_BOTTOM_Y: int = 34
## The arrow-slit window beside each gateway.
const SLIT_X: int = 46

## Beach: the sun (centre, radius) high and away from the pause corner; the sea rows at the bottom of the
## sky band; beach things on the separator strips: towels [x, strip, colour index], sandcastles, shells,
## beach balls [x, strip]. Strip 0 is above lane 0, strip i (1-4) between lanes i-1 and i, strip 5 below
## lane 4 (Farm's PUMPKINS convention).
const SUN_X: int = 150
const SUN_Y: int = 12
const SUN_R: int = 7
const SEA_TOP_Y: int = 25
const TOWELS: Array[Vector3i] = [Vector3i(40, 1, 0), Vector3i(300, 2, 1), Vector3i(150, 3, 0),
		Vector3i(420, 4, 1), Vector3i(250, 5, 0)]
const TOWEL_W: int = 22
const SANDCASTLES: Array[Vector2i] = [Vector2i(200, 1), Vector2i(90, 4), Vector2i(470, 2), Vector2i(380, 5)]
const SHELLS: Array[Vector2i] = [Vector2i(120, 1), Vector2i(360, 1), Vector2i(60, 2), Vector2i(230, 3),
		Vector2i(500, 3), Vector2i(330, 4), Vector2i(140, 5), Vector2i(440, 0)]
const BALLS: Array[Vector2i] = [Vector2i(420, 1), Vector2i(330, 3), Vector2i(60, 5)]
const RIPPLE_PERIOD: int = 31
## The hut: a gable peaking at PEAK_X, PEAK_Y, its eaves at EAVE_Y (an eave board to SKY_H + 2).
const PLANK_W: int = 6
const PEAK_X: int = 46
const PEAK_Y: int = 2
const EAVE_Y: int = 30
const HUT_WINDOW_X: int = 46

var _bad_colour: bool = false


func _init() -> void:
	var errors: Array[Error] = []
	for dir: String in [KNIGHT_DIR, LIFEGUARD_DIR, PROPS_DIR, CASTLE_DIR, BEACH_DIR]:
		errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	for path: String in sheets:
		var sheet: Dictionary = sheets[path]
		var legend: Dictionary[String, String] = sheet["legend"]
		if not _legend_ok(legend, path):
			errors.append(ERR_INVALID_DATA)
			continue
		var image: Image = _sheet_image(sheet["frames"], legend, sheet["size"])
		errors.append(_save(image, path) if image != null else ERR_INVALID_DATA)
	errors.append(_save(_castle_field_image(), CASTLE_DIR + "/field.png"))
	errors.append(_save(_castle_image(), CASTLE_DIR + "/castle.png"))
	errors.append(_save(_beach_field_image(), BEACH_DIR + "/field.png"))
	errors.append(_save(_beach_hut_image(), BEACH_DIR + "/beach_hut.png"))
	if _bad_colour:
		errors.append(ERR_INVALID_DATA)
	# Non-zero exit on any failure, so a bad map, legend, colour, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


func _legend_ok(legend: Dictionary[String, String], path: String) -> bool:
	for ch: String in legend:
		if legend[ch] in RESERVED:
			push_error("%s: legend '%s' is the reserved %s" % [path, ch, legend[ch]])
			return false
	return true


func _color(color_name: String) -> Color:
	if color_name in RESERVED or not Proto.PALETTE.has(color_name):
		push_error("colour %s is reserved or off the palette" % color_name)
		_bad_colour = true
		return Color(0, 0, 0, 0)
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
	return Farm.SKY_H + Farm.LANE_H * (lane + 1) - Farm.FEET_INSET


## The top row of separator strip `strip` (strip 0 is the first lane's top edge, strip 5 the last lane's
## bottom edge; strips 1-4 are 8 px, the bottom edge of one lane and the top edge of the next).
func _strip_top(strip: int) -> int:
	return Farm.SKY_H + strip * Farm.LANE_H - (EDGE_PX if strip > 0 else 0)


func _clouds(image: Image, clouds: Array[Vector3i]) -> void:
	for cloud: Vector3i in clouds:
		var s: int = cloud.z
		_rect(image, cloud.x - 2 * s, cloud.y - s, 4 * s, s, "art-sky-light")
		_blob(image, cloud.x - s, cloud.y - s, s, "art-sky-light")
		_blob(image, cloud.x + s, cloud.y - s, s, "art-sky-light")
		_blob(image, cloud.x, cloud.y - s - s / 2, s + 1, "art-sky-light")


# --- the Castle ---

func _castle_field_image() -> Image:
	var image: Image = Image.create_empty(Farm.FIELD_W, Farm.FIELD_H, false, Image.FORMAT_RGBA8)
	_rect(image, 0, 0, Farm.FIELD_W, Farm.SKY_H, "art-sky")
	_clouds(image, CASTLE_CLOUDS)
	for i: int in TOWERS.size():
		_tower(image, TOWERS[i], "pumpkin" if i % 2 == 0 else "bat-purple")
	# The horizon: a low grass bank (above the lanes, so the zombie greens are allowed here).
	for x: int in Farm.FIELD_W:
		var top: int = Farm.SKY_H - 3 - roundi(1.0 + sin(TAU * x / 200.0))
		_rect(image, x, top, 1, Farm.SKY_H - top, "art-grass")
		_put(image, x, top, "zombie-green-dark")
	for lane: int in Farm.LANE_COUNT:
		_jousting_lane(image, Farm.SKY_H + lane * Farm.LANE_H)
	for strip: int in range(1, Farm.LANE_COUNT + 1):
		_fence(image, _strip_top(strip))
	return image


## A distant tower: stone-light with a crenellated top, a dark window, a pennant on a pole (no emblem).
func _tower(image: Image, tower: Vector3i, flag: String) -> void:
	var x: int = tower.x
	var top: int = tower.y
	var w: int = tower.z
	_rect(image, x, top, w, Farm.SKY_H - top, "stone-light")
	_rect(image, x + w - 2, top, 2, Farm.SKY_H - top, "stone")
	for mx: int in range(x, x + w, 4):
		_rect(image, mx, top - 2, 2, 2, "stone-light")
	_rect(image, x + w / 2 - 1, top + 4, 2, 3, "dusk")
	_rect(image, x + 2, top - 8, 1, 6, "wood-dark")
	_rect(image, x + 3, top - 8, 4, 1, flag)
	_rect(image, x + 3, top - 7, 3, 1, flag)
	_rect(image, x + 3, top - 6, 2, 1, flag)
	_put(image, x + 3, top - 5, flag)


## One jousting lane from `top`: packed sand (parchment-shade) with wood-light rake lines (short arcs
## every RAKE_STEP rows, offset per row); the edges belong to the fence strips.
func _jousting_lane(image: Image, top: int) -> void:
	_rect(image, 0, top, Farm.FIELD_W, Farm.LANE_H, "parchment-shade")
	var row: int = 0
	for y: int in range(top + EDGE_PX + 3, top + Farm.LANE_H - EDGE_PX - 1, RAKE_STEP):
		for x: int in Farm.FIELD_W:
			var phase: int = posmod(x + row * 9, 18)
			if phase < 9:
				# A gentle arc: rows y and y + 1 alternate every 3 px, so the line waves like a rake drag.
				_put(image, x, y + (1 if phase % 6 < 3 else 0), "wood-light")
		row += 1


## The 8 px fence between two lanes (or 4 px at the field edges) from `top`: a wood-light rail with wood
## shading and posts, then a row of small pennant triangles (pumpkin and bat-purple alternating).
func _fence(image: Image, top: int) -> void:
	_rect(image, 0, top, Farm.FIELD_W, 1, "wood")
	_rect(image, 0, top + 1, Farm.FIELD_W, 2, "wood-light")
	_rect(image, 0, top + 3, Farm.FIELD_W, 1, "wood")
	for x: int in range(8, Farm.FIELD_W, POST_STEP):
		_rect(image, x, top, 3, 4, "wood-dark")
	var flag: int = 0
	for x: int in range(2, Farm.FIELD_W - 6, PENNANT_STEP):
		var colour: String = "pumpkin" if flag % 2 == 0 else "bat-purple"
		_rect(image, x, top + 4, 5, 1, colour)
		_rect(image, x + 1, top + 5, 3, 1, colour)
		_put(image, x + 2, top + 6, colour)
		flag += 1


func _castle_image() -> Image:
	var image: Image = Image.create_empty(Farm.HOUSE_W, Farm.FIELD_H, false, Image.FORMAT_RGBA8)
	# The wall: stone-light blocks with stone mortar in a running bond, an ink edge on the field side.
	_rect(image, 0, WALL_TOP_Y, Farm.HOUSE_W, Farm.FIELD_H - WALL_TOP_Y, "stone-light")
	var course: int = 0
	for y: int in range(WALL_TOP_Y + COURSE_H - 1, Farm.FIELD_H, COURSE_H):
		_rect(image, 1, y, Farm.HOUSE_W - 1, 1, "stone")
		var offset: int = (BLOCK_W / 2) * (course % 2)
		for x: int in range(offset + 4, Farm.HOUSE_W, BLOCK_W):
			_rect(image, x, y - COURSE_H + 1, 1, COURSE_H - 1, "stone")
		course += 1
	# Merlons along the top (under the pause button), each with an ink outline.
	for x: int in range(0, Farm.HOUSE_W, MERLON_STEP):
		_box(image, x, WALL_TOP_Y - MERLON_H, MERLON_W, MERLON_H + 1, "stone-light")
	_rect(image, 0, WALL_TOP_Y, Farm.HOUSE_W, 1, "ink")
	_rect(image, 0, WALL_TOP_Y + 1, Farm.HOUSE_W, 2, "stone")
	# The banner hangs from the wall top, a swallowtail at the bottom (no emblem).
	_box(image, BANNER_X, WALL_TOP_Y + 1, BANNER_W, BANNER_BOTTOM_Y - WALL_TOP_Y, "bat-purple")
	_rect(image, BANNER_X + 2, WALL_TOP_Y + 3, 1, BANNER_BOTTOM_Y - WALL_TOP_Y - 6, "dusk")
	for i: int in 3:
		_rect(image, BANNER_X + BANNER_W / 2 - 2 + i, BANNER_BOTTOM_Y - 2 + i, 4 - 2 * i, 1, "ink")
	_rect(image, BANNER_X + BANNER_W / 2 - 1, BANNER_BOTTOM_Y, 2, 1, "ink")
	_rect(image, 0, WALL_TOP_Y - MERLON_H, 1, Farm.FIELD_H - WALL_TOP_Y + MERLON_H, "ink")
	for lane: int in Farm.LANE_COUNT:
		_gateway(image, _feet_y(lane))
	return image


## One lane's arched gateway: a night opening at the field edge whose bottom row is `feet` - 1 (the soles
## row), a dusk floor, an ink arch, a raised portcullis band (wood with wood-dark bars, never closed over the
## opening) at the arch top, a stone step, and an arrow-slit window.
func _gateway(image: Image, feet: int) -> void:
	var w: int = Farm.DOOR_W
	var top: int = feet - Farm.DOOR_H
	_rect(image, 0, top - 1, w + 1, Farm.DOOR_H + 1, "ink")
	_rect(image, 0, top, w, Farm.DOOR_H, "night")
	# Round the arch's far corner: the ink steps in over the top rows.
	for i: int in 3:
		_rect(image, w - 3 + i, top + i, 3 - i, 1, "ink")
	_rect(image, 0, feet - 3, w, 3, "dusk")
	_rect(image, 0, top + 1, w - 3, 3, "wood")
	for x: int in range(1, w - 3, 3):
		_rect(image, x, top + 1, 1, 3, "wood-dark")
	_rect(image, 0, top + 4, w - 3, 1, "wood-dark")
	# The voussoirs: a stone ring around the arch.
	_rect(image, 0, top - 3, w + 2, 2, "stone")
	_rect(image, w + 1, top - 1, 2, Farm.DOOR_H + 1, "stone")
	_box(image, 0, feet, w + 4, 3, "stone")
	_box(image, SLIT_X, top + 6, 3, 12, "night")


# --- the Beach Hut ---

func _beach_field_image() -> Image:
	var image: Image = Image.create_empty(Farm.FIELD_W, Farm.FIELD_H, false, Image.FORMAT_RGBA8)
	_rect(image, 0, 0, Farm.FIELD_W, Farm.SKY_H, "art-sky")
	_clouds(image, [Vector3i(330, 12, 3), Vector3i(470, 16, 4)] as Array[Vector3i])
	# The sun: a pumpkin-light disc with a pumpkin rim (never candy-yellow or the moon).
	_blob(image, SUN_X, SUN_Y, SUN_R + 1, "pumpkin")
	_blob(image, SUN_X, SUN_Y, SUN_R, "pumpkin-light")
	# The sea: light water with sky wave dashes, chalk foam scalloping onto the sand (all above y 36).
	_rect(image, 0, SEA_TOP_Y, Farm.FIELD_W, Farm.SKY_H - SEA_TOP_Y, "art-sky-light")
	_rect(image, 0, SEA_TOP_Y, Farm.FIELD_W, 1, "art-sky")
	for y: int in range(SEA_TOP_Y + 2, Farm.SKY_H - 3, 3):
		for x: int in Farm.FIELD_W:
			if posmod(x + y * 7, 16) < 6:
				_put(image, x, y, "art-sky")
	for x: int in Farm.FIELD_W:
		var foam: int = Farm.SKY_H - 2 + (1 if posmod(x, 10) < 5 else 0)
		_rect(image, x, foam, 1, Farm.SKY_H - foam, "chalk")
	for lane: int in Farm.LANE_COUNT:
		_sand_lane(image, Farm.SKY_H + lane * Farm.LANE_H)
	for towel: Vector3i in TOWELS:
		_towel(image, towel.x, _strip_top(towel.y), towel.z)
	for castle: Vector2i in SANDCASTLES:
		_sandcastle(image, castle.x, _strip_top(castle.y))
	for shell: Vector2i in SHELLS:
		_shell(image, shell.x, _strip_top(shell.y))
	for ball: Vector2i in BALLS:
		_ball(image, ball.x, _strip_top(ball.y))
	return image


## One sand lane from `top`: parchment with wood-light ripple dashes near its edges (the middle rows stay
## calm), parchment-shade edges where the beach things lie.
func _sand_lane(image: Image, top: int) -> void:
	_rect(image, 0, top, Farm.FIELD_W, Farm.LANE_H, "parchment")
	_rect(image, 0, top, Farm.FIELD_W, EDGE_PX, "parchment-shade")
	_rect(image, 0, top + Farm.LANE_H - EDGE_PX, Farm.FIELD_W, EDGE_PX, "parchment-shade")
	for y: int in [top + EDGE_PX + 4, top + Farm.LANE_H - EDGE_PX - 5]:
		for x: int in Farm.FIELD_W:
			var phase: int = posmod(x + y * 11, RIPPLE_PERIOD)
			if phase < 10:
				_put(image, x, y - (1 if phase >= 3 and phase < 7 else 0), "wood-light")


## The strip rows a beach thing sits on: the top EDGE_PX rows of strip 0, else the middle of the strip.
func _strip_mid(strip_top: int) -> int:
	return strip_top + (1 if strip_top == Farm.SKY_H else EDGE_PX - 2)


## A striped towel, TOWEL_W x 5 (`kind` 0: bat-purple and chalk, 1: sky and chalk).
func _towel(image: Image, x: int, strip_top: int, kind: int) -> void:
	var y: int = _strip_mid(strip_top) - 1
	var colour: String = "bat-purple" if kind == 0 else "art-sky"
	_rect(image, x, y, TOWEL_W, 5, "chalk")
	for sx: int in range(x, x + TOWEL_W, 4):
		_rect(image, sx, y, 2, 5, colour)


## A little sandcastle: a parchment-shade keep with two turrets, wood-light shading, a dusk door.
func _sandcastle(image: Image, x: int, strip_top: int) -> void:
	var bottom: int = _strip_mid(strip_top) + 3
	_rect(image, x, bottom - 4, 9, 5, "wood-light")
	_rect(image, x + 1, bottom - 4, 7, 4, "parchment-shade")
	_rect(image, x, bottom - 6, 2, 2, "wood-light")
	_rect(image, x + 7, bottom - 6, 2, 2, "wood-light")
	_rect(image, x + 4, bottom - 2, 1, 2, "dusk")


func _shell(image: Image, x: int, strip_top: int) -> void:
	var y: int = _strip_mid(strip_top)
	_rect(image, x, y, 4, 2, "chalk")
	_rect(image, x + 1, y + 1, 2, 1, "pumpkin-light")


## A beach ball: a 6 px disc in pumpkin, chalk and sky segments.
func _ball(image: Image, x: int, strip_top: int) -> void:
	var cy: int = _strip_mid(strip_top) + 1
	_blob(image, x, cy, 3, "chalk")
	_rect(image, x - 3, cy - 1, 2, 2, "pumpkin")
	_rect(image, x + 1, cy - 1, 2, 2, "art-sky")
	_rect(image, x - 1, cy - 3, 2, 1, "pumpkin")
	_rect(image, x - 1, cy + 2, 2, 1, "art-sky")


func _beach_hut_image() -> Image:
	var image: Image = Image.create_empty(Farm.HOUSE_W, Farm.FIELD_H, false, Image.FORMAT_RGBA8)
	# The wall: vertical planks, chalk and sky-light alternating, wood seams, an ink edge on the field side.
	for x: int in range(0, Farm.HOUSE_W, PLANK_W):
		var colour: String = "chalk" if (x / PLANK_W) % 2 == 0 else "art-sky-light"
		_rect(image, x, EAVE_Y, PLANK_W, Farm.FIELD_H - EAVE_Y, colour)
		_rect(image, x + PLANK_W - 1, EAVE_Y, 1, Farm.FIELD_H - EAVE_Y, "wood")
	_rect(image, 0, EAVE_Y, 1, Farm.FIELD_H - EAVE_Y, "ink")
	# The roof: a bat-purple gable with dusk shingle rows and an ink edge, an eave board below it.
	for y: int in range(PEAK_Y, EAVE_Y):
		var half: int = (y - PEAK_Y) * 2 + 2
		var left: int = PEAK_X - half
		var right: int = PEAK_X + half
		_rect(image, left, y, right - left, 1, "bat-purple")
		if (y - PEAK_Y) % 4 == 3:
			_rect(image, left + 1, y, right - left - 2, 1, "dusk")
		_put(image, left, y, "ink")
		_put(image, left - 1, y, "ink")
		_put(image, right - 1, y, "ink")
		_put(image, right, y, "ink")
	_rect(image, PEAK_X - 2, PEAK_Y - 1, 4, 1, "ink")
	_box(image, 0, EAVE_Y, Farm.HOUSE_W + 1, Farm.SKY_H + 3 - EAVE_Y, "pumpkin")
	_rect(image, 1, EAVE_Y + 1, Farm.HOUSE_W, 1, "pumpkin-light")
	for lane: int in Farm.LANE_COUNT:
		_hut_doorway(image, _feet_y(lane))
	return image


## One lane's hut doorway: a night opening at the field edge whose bottom row is `feet` - 1 (the soles
## row), a dusk floor, the sky door leaf swung open beside it, a wood-light step, and a shuttered window
## (one sill bar: never a cross).
func _hut_doorway(image: Image, feet: int) -> void:
	var top: int = feet - Farm.DOOR_H
	_rect(image, 0, top - 1, Farm.DOOR_W + 1, Farm.DOOR_H + 1, "ink")
	_rect(image, 0, top, Farm.DOOR_W, Farm.DOOR_H, "night")
	_rect(image, 0, feet - 3, Farm.DOOR_W, 3, "dusk")
	_box(image, Farm.DOOR_W, top - 1, Farm.LEAF_W + 1, Farm.DOOR_H + 1, "art-sky")
	_rect(image, Farm.DOOR_W + 2, top + 2, 1, Farm.DOOR_H - 4, "art-sky-light")
	_put(image, Farm.DOOR_W + Farm.LEAF_W - 2, top + Farm.DOOR_H / 2, "ink")
	_box(image, 0, feet, Farm.DOOR_W + Farm.LEAF_W + 1, 3, "wood-light")
	_box(image, HUT_WINDOW_X, top + 5, 14, 10, "art-sky")
	_rect(image, HUT_WINDOW_X + 1, top + 6, 12, 2, "art-sky-light")
	_box(image, HUT_WINDOW_X - 4, top + 4, 5, 12, "pumpkin")
	_box(image, HUT_WINDOW_X + 13, top + 4, 5, 12, "pumpkin")
	_box(image, HUT_WINDOW_X - 2, top + 14, 18, 3, "wood-dark")


func _save(image: Image, path: String) -> Error:
	if image == null:
		return ERR_INVALID_DATA
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
