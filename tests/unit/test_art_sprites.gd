extends GutTest
## Prototype sprite sheets (Story 1.9, NFR13), the Professor Zombie (Story 2.9), the party-hat zombie
## (Story 3.3), the Story 3.6 Zombie Run set (hop, hug, dance, poof, party walk, brain block, brain
## pop, down-arrow), the Story 4.3 cosmetics (Pumpkin hat overlay, Cute ghost idle) and the Story 6.6
## Horde Rush set (zombie flash and melt, the Farmer's idle/walk/throw, the tomato and its splat): size,
## hard alpha, palette-only pixels, the 1 px ink outline rule, non-empty distinct frames on one ground
## line, and pixel-crisp import settings.
## Read from the committed PNG bytes (Image.load_from_file), so import state doesn't matter.
## Frame size per sheet: characters (and the poof) 32x32, props 16x16 (style sheet section 3).

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const FRAME: int = 32
const PROP_FRAME: int = 16
const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie/"
const PROPS_DIR: String = "res://assets/sprites/props/"
const FARMER_DIR: String = "res://assets/sprites/characters/farmer/"
const WALK_PATH: String = ZOMBIE_DIR + "zombie_walk.png"
const FLASH_PATH: String = ZOMBIE_DIR + "zombie_flash.png"
const MELT_PATH: String = ZOMBIE_DIR + "zombie_melt.png"
const TOMATO_FLY_PATH: String = PROPS_DIR + "tomato_fly.png"
const TOMATO_SPLAT_PATH: String = PROPS_DIR + "tomato_splat.png"
## Story 6.6 sheets: never stamp red (the flash and the tomato are pumpkin, DESIGN.md D16).
const HORDE_RUSH_SHEETS: Array[String] = [
	FLASH_PATH, MELT_PATH, FARMER_DIR + "farmer_idle.png", FARMER_DIR + "farmer_walk.png",
	FARMER_DIR + "farmer_throw.png", TOMATO_FLY_PATH, TOMATO_SPLAT_PATH,
]
## The tomato in flight is small next to a 32 px copy.
const TOMATO_MAX_WIDTH: int = 8
## Character sheet path -> frame count (FRAME x FRAME frames).
const SHEETS: Dictionary[String, int] = {
	"res://assets/sprites/characters/zombie/zombie_idle.png": 2,
	"res://assets/sprites/characters/zombie/zombie_walk.png": 4,
	"res://assets/sprites/characters/villager/villager_wave.png": 2,
	"res://assets/sprites/characters/professor/professor_point.png": 2,
	"res://assets/sprites/characters/party_zombie/party_zombie_idle.png": 2,
	"res://assets/sprites/characters/zombie/zombie_hop.png": 3,
	"res://assets/sprites/characters/zombie/zombie_hug.png": 3,
	"res://assets/sprites/characters/zombie/zombie_dance.png": 4,
	"res://assets/sprites/characters/villager/villager_poof.png": 4,
	"res://assets/sprites/characters/party_zombie/party_zombie_walk.png": 4,
	PET_GHOST_PATH: 4,
	FLASH_PATH: 4,
	MELT_PATH: 6,
	FARMER_DIR + "farmer_idle.png": 2,
	FARMER_DIR + "farmer_walk.png": 4,
	FARMER_DIR + "farmer_throw.png": 3,
}
## Prop sheet path -> frame count (PROP_FRAME x PROP_FRAME frames).
const PROP_SHEETS: Dictionary[String, int] = {
	PROPS_DIR + "brain_block_idle.png": 2,
	PROPS_DIR + "brain_block_bonk.png": 3,
	PROPS_DIR + "brain_pop.png": 2,
	TOMATO_FLY_PATH: 2,
	TOMATO_SPLAT_PATH: 3,
}
const HAT_PUMPKIN_PATH: String = "res://assets/sprites/cosmetics/hats/hat_pumpkin.png"
const PET_GHOST_PATH: String = "res://assets/sprites/cosmetics/pets/pet_cute_ghost_idle.png"
const PARTY_ZOMBIE_PATH: String = "res://assets/sprites/characters/party_zombie/party_zombie_idle.png"
const PARTY_ZOMBIE_WALK_PATH: String = "res://assets/sprites/characters/party_zombie/party_zombie_walk.png"
const POOF_PATH: String = "res://assets/sprites/characters/villager/villager_poof.png"
const BLOCK_BONK_PATH: String = PROPS_DIR + "brain_block_bonk.png"
const ARROW_PATH: String = PROPS_DIR + "down_arrow.png"
## One-frame overlays drawn over a sheet or a scene (not animations, so not in SHEETS): same pixel
## rules. Path -> frame size.
const OVERLAYS: Dictionary[String, int] = {
	"res://assets/sprites/characters/professor/professor_mortarboard.png": FRAME,
	ARROW_PATH: PROP_FRAME,
	HAT_PUMPKIN_PATH: FRAME,
}
## Hats (Story 4.3): one 32x32 frame whose seat (the brim's bottom-centre) is pixel (16, 30).
const HATS: Array[String] = [HAT_PUMPKIN_PATH]
const HAT_SEAT_ROW: int = 30
## The party-hat zombie walk changes the legs only: rows above this are the idle frame's pixels.
const PARTY_LEGS_TOP: int = 24
## The poof (and every frame of it) is never wider than the 24 px tag (ZombieRunTarget.HALF_WIDTH).
const POOF_MAX_WIDTH: int = 24
const POP_MAX_WIDTH: int = 10
const INK: String = "1e1428"
const ZOMBIE_GREEN: String = "6cc24a"
const ZOMBIE_GREEN_DARK: String = "2e6b26"
const ART_SKIN_LIGHT: String = "f2c9a0"
const ART_SKIN_DARK: String = "b07850"
const CHALK: String = "f4f1e4"
const STONE_LIGHT: String = "bdb6c4"
const STONE: String = "6f6a80"
const BRAIN_PINK: String = "f29ab8"
const BRAIN_SHADE: String = "c9607f"
const CANDY_YELLOW: String = "ffd23f"
const PUMPKIN: String = "f07a1c"
const PUMPKIN_LIGHT: String = "ffa94a"
const WOOD_DARK: String = "5a3218"
const STAMP_RED: String = "b02a25"
const ZOMBIE_GREEN_BRIGHT: String = "b8f27c"
const BAT_PURPLE: String = "7a4bb3"
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


## Animation sheets (characters and props) -> frame count.
func _animation_sheets() -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = SHEETS.duplicate()
	counts.merge(PROP_SHEETS)
	return counts


## Sheets and overlays -> frame count (an overlay is one frame).
func _frame_counts(with_overlays: bool) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = _animation_sheets()
	if with_overlays:
		for path: String in OVERLAYS:
			counts[path] = 1
	return counts


## The square frame size of a sheet or overlay.
func _size(path: String) -> int:
	if OVERLAYS.has(path):
		return OVERLAYS[path]
	return PROP_FRAME if PROP_SHEETS.has(path) else FRAME


## Sheets (and overlays) that exist with the right size; anything else fails the size test, not every test.
func _valid_sheets(with_overlays: bool = false) -> Dictionary[String, Image]:
	var counts: Dictionary[String, int] = _frame_counts(with_overlays)
	var found: Dictionary[String, Image] = {}
	for path: String in counts:
		var image: Image = _load(path)
		var size: int = _size(path)
		if image != null and image.get_width() == counts[path] * size and image.get_height() == size:
			found[path] = image
	return found


func _opaque(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).a8 == 255


func _frame_bytes(image: Image, frame: int, size: int) -> PackedByteArray:
	return image.get_region(Rect2i(frame * size, 0, size, size)).get_data()


func _lowest_opaque_row(image: Image, frame: int, size: int) -> int:
	for y: int in range(size - 1, -1, -1):
		for x: int in size:
			if _opaque(image, frame * size + x, y):
				return y
	return -1


## Opaque columns of one frame: right - left + 1 (0 when empty).
func _opaque_width(image: Image, frame: int, size: int) -> int:
	var left: int = size
	var right: int = -1
	for y: int in size:
		for x: int in size:
			if _opaque(image, frame * size + x, y):
				left = mini(left, x)
				right = maxi(right, x)
	return right - left + 1 if right >= 0 else 0


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
	var counts: Dictionary[String, int] = _animation_sheets()
	for path: String in counts:
		var frames: int = counts[path]
		var size: int = _size(path)
		assert_between(frames, 2, 6, "%s frame count" % _name(path))
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % path)
		if image == null:
			continue
		assert_eq(image.get_width(), frames * size, "%s width" % _name(path))
		assert_eq(image.get_height(), size, "%s height" % _name(path))


func test_new_sheet_frame_counts_and_sizes() -> void:
	assert_eq(SHEETS[ZOMBIE_DIR + "zombie_hop.png"], 3)
	assert_eq(SHEETS[ZOMBIE_DIR + "zombie_hug.png"], 3)
	assert_eq(SHEETS[ZOMBIE_DIR + "zombie_dance.png"], 4)
	assert_eq(SHEETS[POOF_PATH], 4)
	assert_eq(SHEETS[PARTY_ZOMBIE_WALK_PATH], 4)
	assert_eq(PROP_SHEETS[PROPS_DIR + "brain_block_idle.png"], 2)
	assert_eq(PROP_SHEETS[BLOCK_BONK_PATH], 3)
	assert_eq(PROP_SHEETS[PROPS_DIR + "brain_pop.png"], 2)
	assert_eq(OVERLAYS[ARROW_PATH], PROP_FRAME, "the arrow is a 16 x 16 cell")


## One-frame overlays stay exempt from the 2-6 frame count.
func test_overlays_exist_one_frame() -> void:
	for path: String in OVERLAYS:
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % path)
		if image == null:
			continue
		assert_eq(image.get_size(), Vector2i(OVERLAYS[path], OVERLAYS[path]), "%s size" % _name(path))


func test_hard_alpha_and_palette_only() -> void:
	var sheets: Dictionary[String, Image] = _valid_sheets(true)
	assert_eq(sheets.size(), SHEETS.size() + PROP_SHEETS.size() + OVERLAYS.size())
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
		var size: int = _size(path)
		var bad: Array[String] = []
		for frame: int in counts[path]:
			for y: int in size:
				for x: int in size:
					var px: int = frame * size + x
					if not _opaque(image, px, y):
						continue
					var hex: String = image.get_pixel(px, y).to_html(false)
					if hex == INK:
						continue
					for step: Vector2i in NEIGHBOURS:
						var nx: int = x + step.x
						var ny: int = y + step.y
						if nx < 0 or ny < 0 or nx >= size or ny >= size \
								or not _opaque(image, frame * size + nx, ny):
							bad.append("%s frame %d (%d,%d) rgb %s open edge" % [_name(path), frame, x, y, hex])
							break
		assert_eq(bad.size(), 0, ", ".join(bad.slice(0, 10)))


## Rule 7 for every sheet, hop and hug included: they are drawn grounded and the tween does the lift.
func test_frames_not_empty_distinct_and_grounded() -> void:
	var counts: Dictionary[String, int] = _animation_sheets()
	var sheets: Dictionary[String, Image] = _valid_sheets()
	assert_eq(sheets.size(), counts.size())
	for path: String in sheets:
		var image: Image = sheets[path]
		var frames: int = counts[path]
		var size: int = _size(path)
		var ground: int = _lowest_opaque_row(image, 0, size)
		for frame: int in frames:
			var lowest: int = _lowest_opaque_row(image, frame, size)
			assert_ne(lowest, -1, "%s frame %d empty" % [_name(path), frame])
			assert_eq(lowest, ground, "%s frame %d ground line" % [_name(path), frame])
			for other: int in range(frame + 1, frames):
				assert_ne(_frame_bytes(image, frame, size), _frame_bytes(image, other, size),
						"%s frames %d and %d identical" % [_name(path), frame, other])


## Characters (and the poof) stand on sheet row 30: Body sits at (-16, -31) in every scene.
func test_characters_stand_on_row_30() -> void:
	var sheets: Dictionary[String, Image] = _valid_sheets()
	for path: String in SHEETS:
		if not sheets.has(path) or path.contains("/professor/"):
			continue
		assert_eq(_lowest_opaque_row(sheets[path], 0, FRAME), 30, "%s soles row" % _name(path))


## The professor is the player zombie in a gown, so his sheet uses the zombie greens. Overlays: ink only.
## Pets (Story 4.3): the Cute ghost is chalk with an ink outline.
## The poof is a white dust cloud; the props are cartoon brain pink (the bonk ends grey), the tomato
## props pumpkin. The flash is the zombie recoloured to pumpkin (test_flash_is_a_recoloured_walk).
func test_right_color_ramps_used() -> void:
	var sheets: Dictionary[String, Image] = _valid_sheets(true)
	assert_eq(sheets.size(), SHEETS.size() + PROP_SHEETS.size() + OVERLAYS.size())
	for path: String in sheets:
		var colors: Dictionary[String, bool] = _colors(sheets[path])
		assert_true(colors.has(INK), "%s has no ink" % _name(path))
		if OVERLAYS.has(path):
			continue
		if path == POOF_PATH:
			assert_true(colors.has(CHALK), "poof has no chalk fill")
			assert_true(colors.has(STONE_LIGHT), "poof has no stone-light shade")
		elif path.contains("/cosmetics/pets/"):
			assert_true(colors.has(CHALK), "%s has no chalk" % _name(path))
		elif path == TOMATO_FLY_PATH or path == TOMATO_SPLAT_PATH:
			assert_true(colors.has(PUMPKIN), "%s has no pumpkin" % _name(path))
			assert_true(colors.has(PUMPKIN_LIGHT), "%s has no pumpkin-light" % _name(path))
		elif path == FLASH_PATH:
			assert_true(colors.has(PUMPKIN), "flash has no pumpkin")
		elif PROP_SHEETS.has(path):
			assert_true(colors.has(BRAIN_PINK), "%s has no art-brain-pink" % _name(path))
			assert_true(colors.has(BRAIN_SHADE), "%s has no art-brain-shade" % _name(path))
		elif path.contains("/zombie/") or path.contains("/professor/") or path.contains("/party_zombie/"):
			assert_true(colors.has(ZOMBIE_GREEN), "%s has no zombie-green" % _name(path))
			assert_true(colors.has(ZOMBIE_GREEN_DARK), "%s has no zombie-green-dark" % _name(path))
		else:
			assert_true(colors.has(ART_SKIN_LIGHT), "%s has no art-skin-light" % _name(path))


func test_import_settings_lossless_no_mipmaps() -> void:
	var paths: Array[String] = [PALETTE_PATH]
	paths.append_array(SHEETS.keys())
	paths.append_array(PROP_SHEETS.keys())
	paths.append_array(OVERLAYS.keys())
	for path: String in paths:
		var config: ConfigFile = ConfigFile.new()
		var err: Error = config.load(path + ".import")
		assert_eq(err, OK, "%s.import missing" % path)
		if err != OK:
			continue
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % path)
		assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % path)


## Style sheet section 6: the party-hat zombie is a villager recolour, so no villager skin is left.
## Story 3.6: the walk sheet too, built from the same colours, and its frames change the legs only (rows
## above PARTY_LEGS_TOP are the idle frame with the same hat pose: 0/2 straight hat, 1/3 tilted).
func test_party_zombie_is_a_recoloured_villager() -> void:
	var image: Image = _load(PARTY_ZOMBIE_PATH)
	assert_not_null(image, "party zombie sheet missing")
	if image == null:
		return
	for path: String in [PARTY_ZOMBIE_PATH, PARTY_ZOMBIE_WALK_PATH]:
		var sheet: Image = _load(path)
		assert_not_null(sheet, "%s missing" % path)
		if sheet == null:
			continue
		var colors: Dictionary[String, bool] = _colors(sheet)
		assert_false(colors.has(ART_SKIN_LIGHT), "%s: no art-skin-light left" % _name(path))
		assert_false(colors.has(ART_SKIN_DARK), "%s: no art-skin-dark left" % _name(path))
		assert_true(colors.has(ZOMBIE_GREEN), _name(path))
		assert_true(colors.has(PUMPKIN), "%s keeps the villager's pumpkin shirt" % _name(path))
	var walk: Image = _load(PARTY_ZOMBIE_WALK_PATH)
	if walk == null or walk.get_width() != 4 * FRAME:
		return
	var idle_colors: Dictionary[String, bool] = _colors(image)
	for hex: String in _colors(walk):
		assert_true(idle_colors.has(hex), "walk colour %s is not in the idle sheet" % hex)
	for frame: int in 4:
		var upper: Rect2i = Rect2i(frame * FRAME, 0, FRAME, PARTY_LEGS_TOP)
		var idle_upper: Rect2i = Rect2i((frame % 2) * FRAME, 0, FRAME, PARTY_LEGS_TOP)
		assert_eq(walk.get_region(upper).get_data(), image.get_region(idle_upper).get_data(),
				"walk frame %d: head, hat and clothes are the idle frame's" % frame)


## The poof is a white dust cloud no wider than the tag, in every frame.
func test_poof_frames_within_the_tag_width() -> void:
	var image: Image = _load(POOF_PATH)
	assert_not_null(image)
	if image == null:
		return
	for frame: int in SHEETS[POOF_PATH]:
		assert_between(_opaque_width(image, frame, FRAME), 1, POOF_MAX_WIDTH, "poof frame %d width" % frame)
	var colors: Dictionary[String, bool] = _colors(image)
	assert_eq(colors.size(), 3, "ink, chalk and stone-light only")
	for hex: String in [INK, CHALK, STONE_LIGHT]:
		assert_true(colors.has(hex), "poof uses %s" % hex)


## Props fit their 16 px cell; the pop is at most 10 px wide; the arrow is candy-yellow and ink only.
func test_props_fit_their_cells() -> void:
	for path: String in PROP_SHEETS:
		var image: Image = _load(path)
		if image == null:
			continue
		for frame: int in PROP_SHEETS[path]:
			assert_between(_opaque_width(image, frame, PROP_FRAME), 1, PROP_FRAME,
					"%s frame %d" % [_name(path), frame])
	var pop: Image = _load(PROPS_DIR + "brain_pop.png")
	if pop != null:
		for frame: int in PROP_SHEETS[PROPS_DIR + "brain_pop.png"]:
			assert_between(_opaque_width(pop, frame, PROP_FRAME), 1, POP_MAX_WIDTH, "brain pop frame %d" % frame)
	var arrow: Image = _load(ARROW_PATH)
	assert_not_null(arrow)
	if arrow != null:
		var colors: Dictionary[String, bool] = _colors(arrow)
		assert_eq(colors.size(), 2, "ink and candy-yellow only")
		assert_true(colors.has(INK))
		assert_true(colors.has(CANDY_YELLOW))
		assert_between(_opaque_width(arrow, 0, PROP_FRAME), 8, 12, "about 10 px wide")


## The bonk ends on the used look: the held last frame is stone and stone-light, no pink, full size.
func test_bonk_ends_on_the_used_block() -> void:
	var image: Image = _load(BLOCK_BONK_PATH)
	assert_not_null(image)
	if image == null or image.get_width() != 3 * PROP_FRAME:
		return
	var colors: Dictionary[String, bool] = _colors(image.get_region(Rect2i(2 * PROP_FRAME, 0, PROP_FRAME, PROP_FRAME)))
	assert_false(colors.has(BRAIN_PINK), "no pink on the used block")
	assert_false(colors.has(BRAIN_SHADE), "no pink shade on the used block")
	assert_true(colors.has(STONE_LIGHT))
	assert_true(colors.has(STONE))
	assert_eq(_opaque_width(image, 2, PROP_FRAME), PROP_FRAME, "the used block is the full 16 px block")


## The hug's reach stays inside the frame: the forward edge is at x 30 or less.
func test_hug_reach_stays_in_the_frame() -> void:
	var image: Image = _load(ZOMBIE_DIR + "zombie_hug.png")
	assert_not_null(image)
	if image == null:
		return
	for frame: int in SHEETS[ZOMBIE_DIR + "zombie_hug.png"]:
		for y: int in FRAME:
			assert_false(_opaque(image, frame * FRAME + 31, y), "hug frame %d row %d touches x 31" % [frame, y])


## Story 4.3: a hat sits on row 30 (its seat), centred on column 16, and never uses the focus or stamp
## colours; row 31 is the empty margin.
func test_hats_seat_on_row_30_centred() -> void:
	for path: String in HATS:
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % path)
		if image == null:
			continue
		assert_eq(_lowest_opaque_row(image, 0, FRAME), HAT_SEAT_ROW, "%s seat row" % _name(path))
		var used: Rect2i = image.get_used_rect()
		assert_eq(used.position.x + used.end.x, FRAME, "%s centred on x 16" % _name(path))
		assert_true(used.size.x >= 12, "%s covers the 12 px crown" % _name(path))
		var colors: Dictionary[String, bool] = _colors(image)
		assert_false(colors.has(CANDY_YELLOW), "%s: no candy-yellow" % _name(path))
		assert_false(colors.has(STAMP_RED), "%s: no stamp-red" % _name(path))


## The pumpkin hat: pumpkin, its highlight, a wood stem and a green leaf.
func test_pumpkin_hat_colours() -> void:
	var image: Image = _load(HAT_PUMPKIN_PATH)
	assert_not_null(image)
	if image == null:
		return
	var colors: Dictionary[String, bool] = _colors(image)
	for hex: String in [INK, PUMPKIN, PUMPKIN_LIGHT, WOOD_DARK, ZOMBIE_GREEN_DARK]:
		assert_true(colors.has(hex), "pumpkin hat uses %s" % hex)


## The Cute ghost reads as a pet beside a 32 px zombie: 16-20 px tall in every frame.
func test_ghost_is_pet_sized() -> void:
	var image: Image = _load(PET_GHOST_PATH)
	assert_not_null(image)
	if image == null:
		return
	for frame: int in SHEETS[PET_GHOST_PATH]:
		var used: Rect2i = image.get_region(Rect2i(frame * FRAME, 0, FRAME, FRAME)).get_used_rect()
		assert_between(used.size.y, 16, 20, "ghost frame %d height" % frame)


## Story 6.6: the flash is the walk with a legend swap only: the same alpha mask and the same ink pixels
## in every frame (so the same anchors), and no zombie green or bat-purple left.
func test_flash_is_a_recoloured_walk() -> void:
	var walk: Image = _load(WALK_PATH)
	var flash: Image = _load(FLASH_PATH)
	assert_not_null(walk)
	assert_not_null(flash)
	if walk == null or flash == null or walk.get_size() != flash.get_size():
		fail_test("walk and flash sheets missing or different sizes")
		return
	var bad: Array[String] = []
	for y: int in walk.get_height():
		for x: int in walk.get_width():
			var w: Color = walk.get_pixel(x, y)
			var f: Color = flash.get_pixel(x, y)
			if (w.a8 == 255) != (f.a8 == 255):
				bad.append("(%d,%d) mask" % [x, y])
			elif w.a8 == 255 and (w.to_html(false) == INK) != (f.to_html(false) == INK):
				bad.append("(%d,%d) ink" % [x, y])
	assert_eq(bad.size(), 0, ", ".join(bad.slice(0, 10)))
	var colors: Dictionary[String, bool] = _colors(flash)
	for hex: String in [ZOMBIE_GREEN, ZOMBIE_GREEN_BRIGHT, ZOMBIE_GREEN_DARK, BAT_PURPLE]:
		assert_false(colors.has(hex), "flash still uses %s" % hex)


## The melt is green goo: the zombie greens with ink, never anything else in its last (held) frame.
func test_melt_ends_on_a_green_puddle() -> void:
	var image: Image = _load(MELT_PATH)
	assert_not_null(image)
	if image == null or image.get_width() != 6 * FRAME:
		return
	var last: Dictionary[String, bool] = _colors(image.get_region(Rect2i(5 * FRAME, 0, FRAME, FRAME)))
	for hex: String in last:
		assert_true(hex in [INK, ZOMBIE_GREEN, ZOMBIE_GREEN_BRIGHT, ZOMBIE_GREEN_DARK, CHALK],
				"melt puddle uses %s" % hex)


## The Farmer is a human: his skin is only art-skin-light/-dark (no zombie green on him at all).
func test_farmer_skin_is_human() -> void:
	for anim: String in ["idle", "walk", "throw"]:
		var image: Image = _load(FARMER_DIR + "farmer_%s.png" % anim)
		assert_not_null(image, "farmer %s missing" % anim)
		if image == null:
			continue
		var colors: Dictionary[String, bool] = _colors(image)
		assert_true(colors.has(ART_SKIN_LIGHT), "farmer %s has art-skin-light" % anim)
		for hex: String in [ZOMBIE_GREEN, ZOMBIE_GREEN_BRIGHT, ZOMBIE_GREEN_DARK, BAT_PURPLE]:
			assert_false(colors.has(hex), "farmer %s uses %s" % [anim, hex])


func test_horde_rush_sheets_never_use_stamp_red_or_candy_yellow() -> void:
	for path: String in HORDE_RUSH_SHEETS:
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % path)
		if image == null:
			continue
		var colors: Dictionary[String, bool] = _colors(image)
		assert_false(colors.has(STAMP_RED), "%s: no stamp-red" % _name(path))
		assert_false(colors.has(CANDY_YELLOW), "%s: no candy-yellow" % _name(path))


func test_tomato_is_small() -> void:
	var image: Image = _load(TOMATO_FLY_PATH)
	assert_not_null(image)
	if image == null:
		return
	for frame: int in PROP_SHEETS[TOMATO_FLY_PATH]:
		assert_between(_opaque_width(image, frame, PROP_FRAME), 1, TOMATO_MAX_WIDTH, "tomato frame %d width" % frame)
