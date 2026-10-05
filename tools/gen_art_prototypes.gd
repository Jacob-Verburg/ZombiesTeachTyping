extends SceneTree
## Dev-only: writes the master palette, the Story 1.9 prototype sprite sheets (art-style gate) and
## the Story 2.9 Professor Zombie (pointing sheet + mortarboard overlay).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_art_prototypes.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
## Pixels are authored here as ASCII maps: one string per row, one character per pixel, '.' = transparent
## (leaves what earlier parts painted), '_' = clear to transparent (erases what earlier parts painted).
## A legend maps each character to a palette NAME, so a recolor (villager -> party-hat zombie) is a
## legend change. A frame is built from parts (map + first row); later parts paint over earlier ones.
## Rules the maps keep (docs/art-style-sheet.md, enforced by tests/unit/test_art_sprites.gd): palette
## colors only, hard alpha, a 1 px ink outline on every silhouette edge, a 1 px transparent margin,
## and the same ground row (30) in every frame.

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie"
const VILLAGER_DIR: String = "res://assets/sprites/characters/villager"
const PROFESSOR_DIR: String = "res://assets/sprites/characters/professor"
const PARTY_ZOMBIE_DIR: String = "res://assets/sprites/characters/party_zombie"
const FRAME: int = 32

## DESIGN.md -> Colors, in order (index = pixel x in palette_32.png): 24 UI colors, then 8 art colors.
const PALETTE: Dictionary[String, String] = {
	"ink": "1e1428",
	"night": "2b1d3f",
	"dusk": "4a3366",
	"parchment": "f6e7c1",
	"parchment-shade": "d9bc84",
	"ink-faded": "8a7552",
	"ink-muted": "4e4757",
	"wood-dark": "5a3218",
	"wood": "8a5228",
	"wood-light": "c08447",
	"stone": "6f6a80",
	"stone-light": "bdb6c4",
	"chalkboard": "24402f",
	"chalk": "f4f1e4",
	"chalk-dim": "a8c4a6",
	"pumpkin": "f07a1c",
	"pumpkin-light": "ffa94a",
	"candy-yellow": "ffd23f",
	"zombie-green": "6cc24a",
	"zombie-green-bright": "b8f27c",
	"zombie-green-dark": "2e6b26",
	"bat-purple": "7a4bb3",
	"stamp-red": "b02a25",
	"disabled-fill": "cfc6b6",
	"art-sky": "7ec8e3",
	"art-sky-light": "bfe6f2",
	"art-grass": "4e9a34",
	"art-skin-light": "f2c9a0",
	"art-skin-dark": "b07850",
	"art-brain-pink": "f29ab8",
	"art-brain-shade": "c9607f",
	"art-moon": "fff3b0",
}

## The player zombie: three greens for skin, a bat-purple shirt (dusk shade), wood trousers.
## In the leg maps b/B mark the near/far leg, so a walk cycle swaps them.
const ZOMBIE_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"G": "zombie-green",
	"L": "zombie-green-bright",
	"g": "zombie-green-dark",
	"w": "chalk",
	"p": "bat-purple",
	"d": "dusk",
	"b": "wood",
	"B": "wood-dark",
}

## The villager: s/S are the only skin characters. The party-hat zombie (Story 3.3) is this legend
## with s -> zombie-green and S -> zombie-green-dark; every other entry stays.
const VILLAGER_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "art-skin-light",
	"S": "art-skin-dark",
	"h": "wood-dark",
	"H": "wood",
	"o": "pumpkin",
	"O": "pumpkin-light",
	"n": "stone",
	"N": "ink-muted",
	"B": "wood-dark",
}

## The party-hat zombie (Story 3.3, style sheet section 6): VILLAGER_LEGEND with s -> zombie-green and
## S -> zombie-green-dark, plus the hat's y/p. Must mirror VILLAGER_LEGEND otherwise (_init checks it).
const PARTY_ZOMBIE_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"s": "zombie-green",
	"S": "zombie-green-dark",
	"h": "wood-dark",
	"H": "wood",
	"o": "pumpkin",
	"O": "pumpkin-light",
	"n": "stone",
	"N": "ink-muted",
	"B": "wood-dark",
	"y": "candy-yellow",
	"p": "bat-purple",
}
## The legend characters the party-hat zombie recolours or adds; every other one is the villager's.
const PARTY_ZOMBIE_OWN_KEYS: Array[String] = ["s", "S", "y", "p"]

## Head, shirt and the forward arm; drawn from row 1 (row 2 on the bob frames).
const ZOMBIE_UPPER: Array[String] = [
	"..........kkkkkkkkkkkk..........",
	".........kLLLLGGGGGGGGk.........",
	"........kLLGGGGGGGGGGGGk........",
	"........kgGkkkGGGkkkGGGk........",
	"........kgkwwwkGkwwwkGGk........",
	"........kgkwkkkGkwkkkGGk........",
	"........kgkwkkkGkwkkkGGk........",
	"........kgGkkkGGGkkkGGGk........",
	"........kgGkGGGGGGGGGkGk........",
	"........kgGGkkkkkkkkkGGk........",
	"........kgGkwkwwwwwkGGGk........",
	"........kggGGkkkkkkkGGgk........",
	".........kggGGGGGGGGggk.........",
	"..........kkkkkkkkkkkk..........",
	"..........kppppppppppkkkkkkkk...",
	"..........kpppppppppppppGGGGGk..",
	"..........kdpppppppppppdGGGGGk..",
	"..........kdpppppppppkkkkGkGk...",
	"..........kdpppppppppk...k.k....",
	"..........kddpppppppdk..........",
	"..........kdpppppppppk..........",
	"..........kpkpppkppkpk..........",
]

## Legs from row 23 (all leg maps). Standing pose for idle.
const LEGS_STAND: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	"..........kBbbbbbbbbBk..........",
	"..........kBbbkkkkbbBk..........",
	"..........kBbbk..kbbBk..........",
	"..........kkkkk..kkkkkk.........",
	"..........kGGGGk.kGGGGGk........",
	"..........kgGGGGkkgGGGGGk.......",
	"..........kkkkkkkkkkkkkkk.......",
]

## Walk frame 1 (contact): near leg (b) forward, far leg (B) back.
const WALK_A: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	"..........kBbbbbbbbbbk..........",
	".........kBBBkkkkkkbbbk.........",
	"........kBBBk......kbbbk........",
	"........kkkkk......kkkkk........",
	"........kgggk......kGGGGk.......",
	"........kggggk.....kGGGGGk......",
	"........kkkkkk.....kkkkkkk......",
]

## Walk frame 2 (passing): legs together, far leg on the left.
const PASS_A: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	"..........kBBBbbbbbbbk..........",
	"..........kBBBkkkkbbbk..........",
	"..........kBBBk..kbbbk..........",
	"..........kkkkk..kkkkkk.........",
	"..........kggggk.kGGGGGk........",
	"..........kgggggkkGGGGGGk.......",
	"..........kkkkkkkkkkkkkkk.......",
]

## Walk frame 3 (contact): far leg forward; frame 1 with near/far swapped.
const WALK_B: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	"..........kbbbbbbbbbBk..........",
	".........kbbbkkkkkkBBBk.........",
	"........kbbbk......kBBBk........",
	"........kkkkk......kkkkk........",
	"........kGGGk......kggggk.......",
	"........kGGGGk.....kgggggk......",
	"........kkkkkk.....kkkkkkk......",
]

## Walk frame 4 (passing): frame 2 with near/far swapped.
const PASS_B: Array[String] = [
	"..........kbbbbbbbbbbk..........",
	"..........kbbbbbbbBBBk..........",
	"..........kbbbkkkkBBBk..........",
	"..........kbbbk..kBBBk..........",
	"..........kkkkk..kkkkkk.........",
	"..........kGGGGk.kgggggk........",
	"..........kGGGGGkkggggggk.......",
	"..........kkkkkkkkkkkkkkk.......",
]

## Villager from row 4, without the waving arm. The left arm hangs.
const VILLAGER_BODY: Array[String] = [
	"...........kkkkkkkkkk...........",
	"..........khhHHhhhhhhk..........",
	".........khhhhhhhhhhhhk.........",
	".........khhssshsssshhk.........",
	".........khssssssssssshk........",
	".........khsskssssksshk.........",
	".........khsskssssksshk.........",
	".........khssssssssssshk........",
	".........kSssskssksssSk.........",
	"..........kSssskksssSk..........",
	"...........kkkkkkkkkk...........",
	"..........kooooSSooook..........",
	".........kOoooooooooook.........",
	"........kOooooooooooook.........",
	"........kOokoooooooooook........",
	"........kOokoooooooooook........",
	"........kOokoooooooooook........",
	"........ksskoooooooooook........",
	"........kSSkoooooooooook........",
	".........kkknnnnnnnnnnk.........",
	"...........knnnnnnnnnnk.........",
	"...........knnnnkknnnnk.........",
	"...........kNnnk..knnNk.........",
	"...........kNnnk..knnNk.........",
	"..........kBBBBk..kBBBBk........",
	"..........kBBBBk..kBBBBk........",
	"..........kkkkkk..kkkkkk........",
]

## Waving arm from row 6: straight up, then tilted out.
const ARM_UP: Array[String] = [
	".......................kkk......",
	"......................ksssk.....",
	"......................ksssk.....",
	"......................kSssk.....",
	"......................ksssk.....",
	"......................ksssk.....",
	"......................kkkkk.....",
	"......................koook.....",
	"......................koook.....",
	"......................koook.....",
	"......................ooook.....",
	"......................ooook.....",
	".......................kkkk.....",
]

const ARM_TILT: Array[String] = [
	".........................kkk....",
	"........................ksssk...",
	"........................ksssk...",
	".......................kkSssk...",
	".......................ksssk....",
	"......................ksssk.....",
	"......................kkkkk.....",
	"......................koook.....",
	"......................koook.....",
	"......................koook.....",
	"......................ooook.....",
	"......................ooook.....",
	".......................kkkk.....",
]

## Party-hat zombie: evens the head's right edge from row 8 (the villager's rows 8 and 11 stick out 1 px
## under the waving arm), so it mirrors the left edge.
const PARTY_HEAD_EDGE: Array[String] = [
	".....................hk_........",
	"................................",
	"................................",
	".....................hk_........",
]

## Party-hat zombie: a hanging right arm from row 18 (the villager's waving arm is not drawn), the
## mirror of the villager's hanging left arm.
const PARTY_ARM: Array[String] = [
	"....................kook........",
	"....................kook........",
	"....................kook........",
	"....................kssk........",
	"....................kSSk........",
	".....................kkk........",
]

## Party hat from row 1: a bat-purple cone with a candy-yellow stripe and pom-pom; its ink brim sits on
## the hair at row 6. The second frame shifts the pom-pom 1 px (the soles never move).
const PARTY_HAT: Array[String] = [
	"...............kk...............",
	"..............kyyk..............",
	"..............kppk..............",
	".............kpyypk.............",
	"............kppppppk............",
	"...........kkkkkkkkkk...........",
]

const PARTY_HAT_TILT: Array[String] = [
	"................kk..............",
	"...............kyyk.............",
	"..............kppk..............",
	".............kpyypk.............",
	"............kppppppk............",
	"...........kkkkkkkkkk...........",
]

## Professor Zombie (Story 2.9): the player zombie's skin greens, a night gown with dusk folds, a
## wood-light pointer stick, a bat-purple mortarboard tassel (never candy-yellow or stamp-red).
const PROFESSOR_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"G": "zombie-green",
	"L": "zombie-green-bright",
	"g": "zombie-green-dark",
	"w": "chalk",
	"n": "night",
	"d": "dusk",
	"c": "wood-light",
	"p": "bat-purple",
}

## ZOMBIE_UPPER's head mirrored, so he faces left (toward the board); drawn from row 5.
## The flat 12 px crown (row 5) stays free for the hat slot and the mortarboard.
const PROFESSOR_HEAD: Array[String] = [
	"..........kkkkkkkkkkkk..........",
	".........kGGGGGGGGLLLLk.........",
	"........kGGGGGGGGGGGGLLk........",
	"........kGGGkkkGGGkkkGgk........",
	"........kGGkwwwkGkwwwkgk........",
	"........kGGkkkwkGkkkwkgk........",
	"........kGGkkkwkGkkkwkgk........",
	"........kGGGkkkGGGkkkGgk........",
	"........kGkGGGGGGGGGkGgk........",
	"........kGGkkkkkkkkkGGgk........",
	"........kGGGkwwwwwkwkGgk........",
	"........kgGGkkkkkkkGGggk........",
	".........kggGGGGGGGGggk.........",
	"..........kkkkkkkkkkkk..........",
]

## Gown and bare green feet from row 19; soles on row 30 like every other sheet.
const PROFESSOR_GOWN: Array[String] = [
	".........knnnnnnnnnnnnk.........",
	"........knnnnnnnnnnnnnnk........",
	"........kndnnnnnnnnnndnk........",
	"........knnnnnnnnnnnnnnk........",
	".......kndnnnnnnnnnnnndnk.......",
	".......knnnnnnnnnnnnnnnnk.......",
	".......kndnnnnnnnnnnnndnk.......",
	"......knnnnnnnnnnnnnnnnnnk......",
	"......kkkkkkkkkkkkkkkkkkkk......",
	"..........kgGGk..kgGGk..........",
	".........kgGGGk..kgGGGk.........",
	".........kkkkkk..kkkkkk.........",
]

## Raised arm and pointer stick, tip at the left margin; drawn from row 9, and from row 10 on the
## second frame (the "tap").
const PROFESSOR_ARM: Array[String] = [
	".kk.............................",
	".kck............................",
	".kkck...........................",
	"..kkck..........................",
	"...kkck.........................",
	"....kkckk.......................",
	".....kkGGk......................",
	".....kGGGk......................",
	".....kknnk......................",
	"......knnnk.....................",
	".......knnn.....................",
]

## Mortarboard overlay from row 1: drawn at the body's origin, its cap rests on the crown (row 5).
const MORTARBOARD: Array[String] = [
	"......kkkkkkkkkkkkkkkkkkkk......",
	"......kkkkkkkkkkkkkkkkkkkk......",
	".........knnnnnnnnnnnnkkpk......",
	".........knnnnnnnnnnnnkkpk......",
	".........kkkkkkkkkkkkkkkkk......",
]

## Sheet path -> legend and frames; a frame is a list of [map, first row].
const SHEETS: Dictionary[String, Dictionary] = {
	ZOMBIE_DIR + "/zombie_idle.png": {
		"legend": ZOMBIE_LEGEND,
		"frames": [
			[[LEGS_STAND, 23], [ZOMBIE_UPPER, 1]],
			[[LEGS_STAND, 23], [ZOMBIE_UPPER, 2]],
		],
	},
	ZOMBIE_DIR + "/zombie_walk.png": {
		"legend": ZOMBIE_LEGEND,
		"frames": [
			[[WALK_A, 23], [ZOMBIE_UPPER, 2]],
			[[PASS_A, 23], [ZOMBIE_UPPER, 1]],
			[[WALK_B, 23], [ZOMBIE_UPPER, 2]],
			[[PASS_B, 23], [ZOMBIE_UPPER, 1]],
		],
	},
	VILLAGER_DIR + "/villager_wave.png": {
		"legend": VILLAGER_LEGEND,
		"frames": [
			[[VILLAGER_BODY, 4], [ARM_UP, 6]],
			[[VILLAGER_BODY, 4], [ARM_TILT, 6]],
		],
	},
	PROFESSOR_DIR + "/professor_point.png": {
		"legend": PROFESSOR_LEGEND,
		"frames": [
			[[PROFESSOR_HEAD, 5], [PROFESSOR_GOWN, 19], [PROFESSOR_ARM, 9]],
			[[PROFESSOR_HEAD, 5], [PROFESSOR_GOWN, 19], [PROFESSOR_ARM, 10]],
		],
	},
	PARTY_ZOMBIE_DIR + "/party_zombie_idle.png": {
		"legend": PARTY_ZOMBIE_LEGEND,
		"frames": [
			[[VILLAGER_BODY, 4], [PARTY_HEAD_EDGE, 8], [PARTY_ARM, 18], [PARTY_HAT, 1]],
			[[VILLAGER_BODY, 4], [PARTY_HEAD_EDGE, 8], [PARTY_ARM, 18], [PARTY_HAT_TILT, 1]],
		],
	},
	# One frame: an overlay, not an animation.
	PROFESSOR_DIR + "/professor_mortarboard.png": {
		"legend": PROFESSOR_LEGEND,
		"frames": [
			[[MORTARBOARD, 1]],
		],
	},
}


func _init() -> void:
	var errors: Array[Error] = [
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PALETTE_PATH.get_base_dir())),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZOMBIE_DIR)),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VILLAGER_DIR)),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROFESSOR_DIR)),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PARTY_ZOMBIE_DIR)),
		_check_party_zombie_legend(),
		_save(_palette_image(), PALETTE_PATH),
	]
	for path: String in SHEETS:
		var sheet: Dictionary = SHEETS[path]
		var legend: Dictionary[String, String] = sheet["legend"]
		var image: Image = _sheet_image(sheet["frames"], legend)
		errors.append(_save(image, path) if image != null else ERR_INVALID_DATA)
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## The party-hat zombie is a villager recolour: every legend entry it doesn't own is the villager's.
func _check_party_zombie_legend() -> Error:
	for ch: String in VILLAGER_LEGEND:
		if ch in PARTY_ZOMBIE_OWN_KEYS:
			continue
		if PARTY_ZOMBIE_LEGEND.get(ch, "") != VILLAGER_LEGEND[ch]:
			push_error("PARTY_ZOMBIE_LEGEND '%s' does not mirror VILLAGER_LEGEND" % ch)
			return ERR_INVALID_DATA
	return OK


## 32x1, one opaque pixel per color, in PALETTE order. The raw master data, not a swatch sheet.
func _palette_image() -> Image:
	var image: Image = Image.create_empty(PALETTE.size(), 1, false, Image.FORMAT_RGBA8)
	var x: int = 0
	for color_name: String in PALETTE:
		image.set_pixel(x, 0, Color.html(PALETTE[color_name]))
		x += 1
	return image


## One horizontal strip, FRAME px per frame. Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String]) -> Image:
	var image: Image = Image.create_empty(frames.size() * FRAME, FRAME, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array[String] = part[0]
			var top: int = part[1]
			if top + rows.size() > FRAME:
				push_error("frame %d: part from row %d does not fit" % [i, top])
				return null
			for y: int in rows.size():
				var row: String = rows[y]
				if row.length() != FRAME:
					push_error("frame %d row %d: %d chars, want %d" % [i, top + y, row.length(), FRAME])
					return null
				for x: int in FRAME:
					var ch: String = row[x]
					if ch == ".":
						continue
					if ch == "_":
						image.set_pixel(i * FRAME + x, top + y, Color(0, 0, 0, 0))
						continue
					if not legend.has(ch) or not PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * FRAME + x, top + y, Color.html(PALETTE[legend[ch]]))
	return image


func _save(image: Image, path: String) -> Error:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
