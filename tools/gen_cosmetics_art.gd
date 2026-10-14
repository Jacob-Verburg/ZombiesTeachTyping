extends SceneTree
## Dev-only: writes the cosmetics art: the Story 4.3 Pumpkin hat overlay and the Cute ghost pet's idle float,
## and the Story 9.1 hats (Witch, Bunny ears, Santa, Leprechaun, Heart headband, Top hat, Pirate, Crown).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_cosmetics_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Same method as tools/gen_zombie_run_art.gd: ASCII maps, one character per pixel, '.' = transparent, a
## legend maps a character to a palette NAME (the palette is read from tools/gen_art_prototypes.gd). A part
## is [map, first row]; every row of a part has the part's width, which must be EVEN, and the part is placed
## at x (32 - width) / 2, so it is centred on column 16 (an odd width can't have symmetric extents about 16).
## Hats (docs/art-style-sheet.md section 3): a 32x32 one-frame overlay whose seat (the bottom-centre of the
## brim) is pixel (16, 30): lowest opaque row 30, symmetric extents about x 16, row 31 empty. HatSlot puts
## the seat on the head point. A hat map's last row is its bottom ink row (row 30), its top row is >= 12
## (HAT_MAX_RISE 18: a 1.5x Horde Rush copy in lane 0 must keep its hat on screen), and it has an even
## number of rows, so the Closet icon (the cropped overlay) centres exactly in 32x32.
## Pets are 32x32 sheets drawn from the feet like characters (soles row 30).
## Rules: docs/art-style-sheet.md; tests: test_art_sprites.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")

const HATS_DIR: String = "res://assets/sprites/cosmetics/hats"
const PETS_DIR: String = "res://assets/sprites/cosmetics/pets"
const FRAME: int = 32

## Shared by every hat. Never candy-yellow (focus only), stamp-red (the stamp only) or art-moon (the moon).
const HAT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"o": "pumpkin",
	"l": "pumpkin-light",
	"w": "wood-dark",
	"g": "zombie-green-dark",
	"b": "zombie-green-bright",
	"G": "art-grass",
	"p": "bat-purple",
	"d": "dusk",
	"c": "chalk",
	"s": "stone-light",
	"t": "stone",
	"m": "ink-muted",
	"P": "art-brain-pink",
	"R": "art-brain-shade",
}

## Pumpkin hat from row 19 (12 rows, so its top is 11 px above the seat): a stem with a leaf, a round
## pumpkin with a highlight down the left, two dot eyes and a small smile (cute, no teeth). The bottom ink
## row (row 30) is the brim the seat sits on; rows 24-28 are the widest (14 px, covering the 12 px crown).
const PUMPKIN_HAT: Array[String] = [
	"......kk.kk...",
	".....kwwkggk..",
	"...kkkwwkkkk..",
	"..kllooooook..",
	".kllooooooook.",
	"kllooooooooook",
	"klookooookoook",
	"klookooookoook",
	"kloookookooook",
	"koooookkoooook",
	".kooooooooook.",
	"..kkkkkkkkkk..",
]

## Witch hat from row 13 (18 rows, 20 wide, rise 17): a bat-purple cone with a dusk shade down the right, its
## tip bent over to the right, a pumpkin band with a pumpkin-light buckle and a wide brim (dusk underside).
const WITCH_HAT: Array[String] = [
	"..............kk....",
	".............kppk...",
	"...........kkpdk....",
	"..........kppdk.....",
	".........kppdk......",
	"........kpppdk......",
	".......kppppdk......",
	".......kppppddk.....",
	"......kpppppddk.....",
	"......kpppppddk.....",
	".....kppppppdddk....",
	".....kppppppdddk....",
	"....koooolloooook...",
	"....kooookklooook...",
	"..kkkpppppppddddkk..",
	".kppppppppppppppddk.",
	"kddddddddddddddddddk",
	".kkkkkkkkkkkkkkkkkk.",
]

## Bunny ears from row 13 (18 rows, 16 wide, rise 17): two chalk ears (stone-light shade, art-brain-pink
## inside) on a pink band; the right ear tips over. Each ear has its own ink outline, the gap between them
## is transparent.
const BUNNY_EARS: Array[String] = [
	"...kk...........",
	"..kcck..........",
	".kcccsk.........",
	".kcPPsk.....kk..",
	".kcPPsk....kcck.",
	".kcPPsk...kcccsk",
	".kcPPsk...kcPPsk",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcPPsk..kcPPsk.",
	".kcccsk..kcccsk.",
	".kccsskkkkccssk.",
	"kPPPPPPPPPPPPPPk",
	"kRRRRRRRRRRRRRRk",
	".kkkkkkkkkkkkkk.",
]

## Santa hat from row 15 (16 rows, 18 wide, rise 15): an art-brain-shade cap (art-brain-pink highlight on the
## left, never stamp-red) flopping to the right onto a chalk pom-pom, over a chalk fur trim.
const SANTA_HAT: Array[String] = [
	".....kkkk.........",
	"....kPRRRkkk......",
	"...kPRRRRRRRkk....",
	"...kPRRRRRRRRRk...",
	"..kPRRRRRRkkRRRk..",
	"..kPRRRRRRk.kRRk..",
	"..kPRRRRRRkkcccck.",
	".kPRRRRRRRkkccssk.",
	".kPRRRRRRRRkccssk.",
	".kPRRRRRRRRkkssk..",
	".kPRRRRRRRRRkkk...",
	".kPRRRRRRRRRRkkkk.",
	"kcccccccccccccccck",
	"kcccccccccccccccck",
	"kssssssssssssssssk",
	".kkkkkkkkkkkkkkkk.",
]

## Leprechaun hat from row 17 (14 rows, 16 wide, rise 13): a short art-grass top hat (zombie-green-dark shade,
## zombie-green-bright highlight; the ink outline keeps it apart from the green skin), a wood-dark band with
## a pumpkin-light square buckle, a flat brim.
const LEPRECHAUN_HAT: Array[String] = [
	"...kkkkkkkkkk...",
	"..kbGGGGGGGggk..",
	"..kbGGGGGGGggk..",
	"...kkkkkkkkkk...",
	"...kbGGGGGggk...",
	"...kbGGGGGggk...",
	"...kbGGGGGggk...",
	"...kbGGGGGggk...",
	"...kwwllllwwk...",
	"...kwwlkklwwk...",
	".kkkbGGllGggkkk.",
	"kbGGGGGGGGGGGggk",
	"kggggggggggggggk",
	".kkkkkkkkkkkkkk.",
]

## Valentine heart headband from row 15 (16 rows, 16 wide, rise 15): a thin art-brain-shade band on the
## crown with two pink hearts (chalk glint) bobbing on ink-only zigzag springs (ink needs no neighbours).
const HEART_HEADBAND: Array[String] = [
	".kk.kk..........",
	"kPPkPPk...kk.kk.",
	"kcPPPRk..kPPkPPk",
	".kPPRk...kcPPPRk",
	"..kRk.....kPPRk.",
	"...k.......kRk..",
	"...k........k...",
	"....k......k....",
	"...k......k.....",
	"....k......k....",
	"...k......k.....",
	"....k......k....",
	"...k......k.....",
	".kkkkkkkkkkkkkk.",
	"kRRRRRRRRRRRRRRk",
	".kkkkkkkkkkkkkk.",
]

## The hat seat row, and how far a hat may rise above it (style sheet section 3).
const HAT_SEAT_ROW: int = 30
const HAT_MAX_RISE: int = 18

## New Year's top hat from row 15 (16 rows, 16 wide, rise 15): an ink-muted top hat with a stone highlight
## stripe (so it never turns into an ink blob on night), a chalk band, confetti dots (pumpkin-light,
## art-brain-pink, zombie-green-bright).
const TOP_HAT: Array[String] = [
	"...kkkkkkkkkk...",
	"..ktmmmmmmmmmk..",
	"..ktmmmmmmmmmk..",
	"..ktmmlmmmmPmk..",
	"..ktmmmmmmmmmk..",
	"..ktmmmmbmmmmk..",
	"..ktmPmmmmmmmk..",
	"..ktmmmmmmlmmk..",
	"..ktmmmmmmmmmk..",
	"..kcccccccccck..",
	"..kssssssssssk..",
	"..ktmmmmmmmmmk..",
	".kktmmmmmmmmmkk.",
	"ktmmmmmmmmmmmmmk",
	"kmmmmmmmmmmmmmmk",
	".kkkkkkkkkkkkkk.",
]

## Pirate hat from row 19 (12 rows, 20 wide, rise 11): an ink-muted bicorne with pumpkin-light trim, the
## brim tips turned up, a chalk diamond badge. No skull and crossbones (style sheet section 5: no bones).
const PIRATE_HAT: Array[String] = [
	"........kkkk........",
	".kk...kktmmmkk...kk.",
	"kllk.ktmmmmmmmk.kllk",
	"klllktmmmmmmmmmklllk",
	"kllltmmmmccmmmmmmllk",
	"kllmmmmmccccmmmmmllk",
	"klmmmmmmmccmmmmmmmlk",
	"klmmmmmmmmmmmmmmmmlk",
	"kllllllllllllllllllk",
	".kmmmmmmmmmmmmmmmmk.",
	"..kmmmmmmmmmmmmmmk..",
	"...kkkkkkkkkkkkkk...",
]

## Golden crown from row 19 (12 rows, 16 wide, rise 11): five pumpkin-light points (pumpkin shade, chalk
## glints; gold without candy-yellow), a bat-purple / art-brain-pink / bat-purple gem row.
const CROWN: Array[String] = [
	".......kk.......",
	"....kkkcckkk....",
	".kkkclkllkclkkk.",
	"kclkllkllkllkclk",
	"kllkllkllkllkllk",
	"kllllllllllllllk",
	"kllppllPPllpplok",
	"kllppllPPllpplok",
	"kllllllllllllllk",
	"kcllllllllllllok",
	"kooooooooooooook",
	".kkkkkkkkkkkkkk.",
]
## Story 9.1 hat file name (= its catalogue id) -> [map, first row].
const NEW_HATS: Dictionary[String, Array] = {
	"hat_witch": [WITCH_HAT, 13],
	"hat_bunny_ears": [BUNNY_EARS, 13],
	"hat_santa": [SANTA_HAT, 15],
	"hat_leprechaun": [LEPRECHAUN_HAT, 17],
	"hat_heart_headband": [HEART_HEADBAND, 15],
	"hat_top_hat": [TOP_HAT, 15],
	"hat_pirate": [PIRATE_HAT, 19],
	"hat_crown": [CROWN, 19],
}

const GHOST_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"c": "chalk",
	"s": "stone-light",
	"p": "art-brain-pink",
}

## Ghost head from its top row: the dome, dot eyes, pink cheeks and a tiny mouth (10 rows). The right
## column is the stone-light shade.
const GHOST_HEAD: Array[String] = [
	"....kkkkkk....",
	"..kkcccccckk..",
	".kcccccccccsk.",
	"kcccccccccccsk",
	"kcccccccccccsk",
	"kccckcccckccsk",
	"kccckcccckccsk",
	"kccpccccccpcsk",
	"kccccckkccccsk",
	"kcccccccccccsk",
]
## One body row: the filler between the head and the tail, so the head can bob 1 px while the tail tips
## stay on row 30.
const GHOST_BODY_ROW: String = "kcccccccccccsk"
## The wavy tail, rows 28-30; the ink tips on row 30 are the ghost's soles. A and B are the wave's two
## phases.
const GHOST_TAIL_A: Array[String] = [
	"kcccccccccccsk",
	"kccckkcckkccsk",
	"kkkk..kk..kkkk",
]
const GHOST_TAIL_B: Array[String] = [
	"kcccccccccccsk",
	"kcckcccccckcsk",
	"kkk.kkkkkk.kkk",
]
const GHOST_TAIL_TOP: int = 28
## The head's top row per frame: up, down, up, down (the 1 px float). With the tails A, B, B, A no two
## frames match.
const GHOST_TOPS: Array[int] = [12, 13, 12, 13]


func _init() -> void:
	var errors: Array[Error] = []
	for dir: String in [HATS_DIR, PETS_DIR]:
		errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir)))
	var hat: Image = _sheet_image([[[PUMPKIN_HAT, 19]]], HAT_LEGEND)
	errors.append(_save(hat, HATS_DIR + "/hat_pumpkin.png") if hat != null else ERR_INVALID_DATA)
	for hat_name: String in NEW_HATS:
		var new_hat: Image = null
		if _hat_part_ok(hat_name, NEW_HATS[hat_name]):
			new_hat = _sheet_image([[NEW_HATS[hat_name]]], HAT_LEGEND)
		errors.append(_save(new_hat, "%s/%s.png" % [HATS_DIR, hat_name]) if new_hat != null else ERR_INVALID_DATA)
	var ghost: Image = _sheet_image(_ghost_frames(), GHOST_LEGEND)
	errors.append(_save(ghost, PETS_DIR + "/pet_cute_ghost_idle.png") if ghost != null else ERR_INVALID_DATA)
	# Non-zero exit on any failure, so a bad map, path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## The four idle frames: head at GHOST_TOPS[i], body rows down to the tail, tails A, B, B, A.
func _ghost_frames() -> Array:
	var tails: Array = [GHOST_TAIL_A, GHOST_TAIL_B, GHOST_TAIL_B, GHOST_TAIL_A]
	var frames: Array = []
	for i: int in GHOST_TOPS.size():
		var top: int = GHOST_TOPS[i]
		var body_top: int = top + GHOST_HEAD.size()
		var body: Array[String] = []
		for _row: int in GHOST_TAIL_TOP - body_top:
			body.append(GHOST_BODY_ROW)
		frames.append([[GHOST_HEAD, top], [body, body_top], [tails[i], GHOST_TAIL_TOP]])
	return frames


func _color(color_name: String) -> Color:
	return Color.html(Proto.PALETTE[color_name])


## The documented hat rules (header comment): the last map row is row 30, the top row is >= 12, an even
## row count and a non-empty first row. push_error and false on a bad map, so it never writes a PNG.
func _hat_part_ok(hat_name: String, part: Array) -> bool:
	var rows: Array = part[0]
	var top: int = part[1]
	if rows.is_empty() or (rows[0] as String).is_empty():
		push_error("%s: empty map" % hat_name)
		return false
	if top + rows.size() - 1 != HAT_SEAT_ROW or top < HAT_SEAT_ROW - HAT_MAX_RISE or rows.size() % 2 != 0:
		push_error("%s: want the last row on %d, top row >= %d and an even row count (top %d, %d rows)" % [
				hat_name, HAT_SEAT_ROW, HAT_SEAT_ROW - HAT_MAX_RISE, top, rows.size()])
		return false
	return true


## One horizontal strip of FRAME x FRAME frames, each part centred on column 16 (its rows share one even
## width). Returns null (after push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String]) -> Image:
	var image: Image = Image.create_empty(frames.size() * FRAME, FRAME, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array = part[0]
			var top: int = part[1]
			if top < 0 or top + rows.size() > FRAME or rows.is_empty():
				push_error("frame %d: part from row %d does not fit" % [i, top])
				return null
			var width: int = (rows[0] as String).length()
			if width % 2 != 0 or width > FRAME:
				push_error("frame %d row %d: width %d, want an even width <= %d" % [i, top, width, FRAME])
				return null
			var left: int = (FRAME - width) / 2
			for y: int in rows.size():
				var row: String = rows[y]
				if row.length() != width:
					push_error("frame %d row %d: %d chars, want %d" % [i, top + y, row.length(), width])
					return null
				for x: int in width:
					var ch: String = row[x]
					if ch == ".":
						continue
					if not legend.has(ch) or not Proto.PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * FRAME + left + x, top + y, _color(legend[ch]))
	return image


func _save(image: Image, path: String) -> Error:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
