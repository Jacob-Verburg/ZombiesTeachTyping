extends SceneTree
## Dev-only: writes the Story 4.3 cosmetics art: the Pumpkin hat overlay and the Cute ghost pet's idle float.
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_cosmetics_art.gd
## then --import, so the .png.import files are written (Lossless, no mipmaps; Nearest is the project default).
##
## Same method as tools/gen_zombie_run_art.gd: ASCII maps, one character per pixel, '.' = transparent, a
## legend maps a character to a palette NAME (the palette is read from tools/gen_art_prototypes.gd). A part
## is [map, first row]; the maps here are 14 px wide and padded to the 32 px frame, centred on column 16.
## Hats (docs/art-style-sheet.md section 3): a 32x32 one-frame overlay whose seat (the bottom-centre of the
## brim) is pixel (16, 30): lowest opaque row 30, symmetric extents about x 16, row 31 empty. HatSlot puts
## the seat on the head point. Pets are 32x32 sheets drawn from the feet like characters (soles row 30).
## Rules: docs/art-style-sheet.md; tests: test_art_sprites.gd.

const Proto := preload("res://tools/gen_art_prototypes.gd")

const HATS_DIR: String = "res://assets/sprites/cosmetics/hats"
const PETS_DIR: String = "res://assets/sprites/cosmetics/pets"
const FRAME: int = 32
## The maps are this wide; PAD columns each side centre them on x 16 (9 + 14 + 9 = 32).
const MAP_W: int = 14
const PAD: int = 9

const HAT_LEGEND: Dictionary[String, String] = {
	"k": "ink",
	"o": "pumpkin",
	"l": "pumpkin-light",
	"w": "wood-dark",
	"g": "zombie-green-dark",
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


## One horizontal strip of FRAME x FRAME frames, each map padded by PAD columns. Returns null (after
## push_error) on a bad map.
func _sheet_image(frames: Array, legend: Dictionary[String, String]) -> Image:
	var image: Image = Image.create_empty(frames.size() * FRAME, FRAME, false, Image.FORMAT_RGBA8)
	for i: int in frames.size():
		for part: Array in frames[i]:
			var rows: Array = part[0]
			var top: int = part[1]
			if top < 0 or top + rows.size() > FRAME:
				push_error("frame %d: part from row %d does not fit" % [i, top])
				return null
			for y: int in rows.size():
				var row: String = rows[y]
				if row.length() != MAP_W:
					push_error("frame %d row %d: %d chars, want %d" % [i, top + y, row.length(), MAP_W])
					return null
				for x: int in MAP_W:
					var ch: String = row[x]
					if ch == ".":
						continue
					if not legend.has(ch) or not Proto.PALETTE.has(legend[ch]):
						push_error("frame %d (%d,%d): '%s' not in legend/palette" % [i, x, top + y, ch])
						return null
					image.set_pixel(i * FRAME + PAD + x, top + y, _color(legend[ch]))
	return image


func _save(image: Image, path: String) -> Error:
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s (%dx%d)" % [path, error_string(err), image.get_width(), image.get_height()])
	return err
