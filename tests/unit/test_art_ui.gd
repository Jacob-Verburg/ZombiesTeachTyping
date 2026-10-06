extends GutTest
## The Story 5.0 MVP UI art (NFR13, NFR8): every PNG under assets/sprites/ui/ is listed in UI_SHEETS (the
## story's "UI sheet list", docs/art-style-sheet.md section 7) with its size and frames; hard alpha;
## palette only; Lossless, no mipmaps; the 1 px ink outline rule except the listed exemptions; candy-yellow
## and stamp-red only where DESIGN.md allows them; glow sheets the size of their hand; every 9-slice big
## enough for its margins, and its StyleBoxTexture margins in ui_theme.tres equal to the table. Plus the
## grayscale guard: the lit finger is clearly brighter than the resting one, and its candy ring is 2 px in
## the strong frame and 1 px in the weak one.
## Read from the committed PNG bytes (Image.load_from_file), so import state doesn't matter.

const UI_DIR: String = "res://assets/sprites/ui/"
const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const THEME_PATH: String = "res://data/ui_theme.tres"
const C: String = UI_DIR + "common/"
const M: String = UI_DIR + "menu/"
const HU: String = UI_DIR + "hud/"
const HA: String = UI_DIR + "hands/"
const RC: String = UI_DIR + "report_card/"
const CL: String = UI_DIR + "closet/"
## 9-slice margins [left, top, right, bottom].
const M4: Array[int] = [4, 4, 4, 4]
const M8: Array[int] = [8, 8, 8, 8]
const NONE: Array[int] = []
## path -> [size, frames (side by side), 9-slice margins or NONE].
const UI_SHEETS: Dictionary[String, Array] = {
	C + "ui_button.png": [Vector2i(16, 18), 1, [4, 4, 4, 6]],
	C + "ui_button_focus.png": [Vector2i(16, 18), 1, [4, 4, 4, 6]],
	C + "ui_button_pressed.png": [Vector2i(16, 18), 1, [4, 4, 4, 6]],
	C + "ui_button_disabled.png": [Vector2i(16, 18), 1, [4, 4, 4, 6]],
	C + "ui_focus_ring.png": [Vector2i(12, 12), 1, M4],
	C + "ui_ink_md.png": [Vector2i(16, 16), 1, M4],
	C + "ui_ink_lg.png": [Vector2i(24, 24), 1, M8],
	C + "ui_panel_wood.png": [Vector2i(24, 24), 1, M8],
	C + "ui_panel_stone.png": [Vector2i(32, 32), 1, M8],
	C + "ui_sign.png": [Vector2i(12, 12), 1, M4],
	C + "ui_sign_grey.png": [Vector2i(12, 12), 1, M4],
	C + "ui_keycap.png": [Vector2i(12, 12), 1, M4],
	C + "ui_candy_sign.png": [Vector2i(12, 12), 1, M4],
	C + "ui_brain_pill.png": [Vector2i(28, 28), 1, [12, 12, 12, 12]],
	C + "ui_brain_icon.png": [Vector2i(16, 16), 1, NONE],
	C + "ui_brain_icon_big.png": [Vector2i(32, 32), 1, NONE],
	C + "ui_icon_music.png": [Vector2i(40, 20), 2, NONE],
	C + "ui_icon_sound.png": [Vector2i(40, 20), 2, NONE],
	C + "ui_icon_fullscreen.png": [Vector2i(40, 20), 2, NONE],
	C + "ui_icon_pause.png": [Vector2i(12, 12), 1, NONE],
	C + "ui_pause_button.png": [Vector2i(24, 24), 1, NONE],
	C + "ui_pause_button_hover.png": [Vector2i(24, 24), 1, NONE],
	C + "ui_pause_button_pressed.png": [Vector2i(24, 24), 1, NONE],
	C + "ui_arrow_down.png": [Vector2i(24, 20), 1, NONE],
	C + "ui_arrow_right.png": [Vector2i(24, 20), 1, NONE],
	C + "ui_check.png": [Vector2i(12, 10), 1, NONE],
	M + "ui_logo.png": [Vector2i(292, 114), 1, NONE],
	M + "ui_logo_small.png": [Vector2i(282, 36), 1, NONE],
	M + "ui_level_card_zombie_run.png": [Vector2i(184, 72), 1, NONE],
	M + "ui_level_card_horde_rush.png": [Vector2i(184, 72), 1, NONE],
	M + "ui_level_card_pitchfork_panic.png": [Vector2i(184, 72), 1, NONE],
	M + "ui_card_frame.png": [Vector2i(24, 24), 1, M8],
	M + "ui_coming_soon.png": [Vector2i(156, 50), 1, NONE],
	M + "ui_signpost.png": [Vector2i(8, 16), 1, NONE],
	M + "ui_thumbtack.png": [Vector2i(8, 8), 1, NONE],
	HU + "ui_hud_band.png": [Vector2i(24, 24), 1, M8],
	HU + "ui_cushion.png": [Vector2i(48, 48), 1, NONE],
	HA + "ui_hand_left.png": [Vector2i(64, 48), 1, NONE],
	HA + "ui_hand_right.png": [Vector2i(64, 48), 1, NONE],
	HA + "ui_finger_glow_l_pinky.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_l_ring.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_l_middle.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_l_index.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_l_thumb.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_r_pinky.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_r_ring.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_r_middle.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_r_index.png": [Vector2i(128, 48), 2, NONE],
	HA + "ui_finger_glow_r_thumb.png": [Vector2i(128, 48), 2, NONE],
	RC + "ui_chalkboard.png": [Vector2i(32, 32), 1, M8],
	RC + "ui_chalk_tray.png": [Vector2i(408, 14), 1, NONE],
	RC + "ui_new_best.png": [Vector2i(144, 59), 1, NONE],
	RC + "ui_moon.png": [Vector2i(28, 26), 1, NONE],
	RC + "ui_bat.png": [Vector2i(16, 8), 1, NONE],
	CL + "ui_tile_parchment.png": [Vector2i(16, 16), 1, M4],
	CL + "ui_tile_stone.png": [Vector2i(16, 16), 1, M4],
	CL + "ui_tile_disabled.png": [Vector2i(16, 16), 1, M4],
	CL + "ui_tag_pumpkin.png": [Vector2i(12, 12), 1, M4],
	CL + "ui_tag_green.png": [Vector2i(12, 12), 1, M4],
	CL + "ui_tag_bright.png": [Vector2i(12, 12), 1, M4],
	CL + "ui_locked.png": [Vector2i(32, 32), 1, NONE],
	CL + "ui_closet_sign.png": [Vector2i(152, 32), 1, NONE],
	CL + "ui_mirror.png": [Vector2i(24, 24), 1, M8],
	CL + "ui_ribbon.png": [Vector2i(24, 12), 1, [4, 1, 4, 1]],
	CL + "ui_bow.png": [Vector2i(48, 20), 1, NONE],
}
const FINGERS: Array[String] = ["pinky", "ring", "middle", "index", "thumb"]
const HAND_SIZE: Vector2i = Vector2i(64, 48)
const INK: String = "1e1428"
const CANDY_YELLOW: String = "ffd23f"
const STAMP_RED: String = "b02a25"
const ZOMBIE_GREEN: String = "6cc24a"
const ZOMBIE_GREEN_BRIGHT: String = "b8f27c"
## Rec. 709 luma gap the lit finger's fill must keep over the resting green (AC 5).
const MIN_LUMA_GAP: float = 0.15
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
	return path.trim_prefix(UI_DIR)


func _opaque(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).a8 == 255


func _hex(image: Image, x: int, y: int) -> String:
	return image.get_pixel(x, y).to_html(false)


## Every .png under assets/sprites/ui/, walking the folders (so an unlisted file is found).
func _ui_pngs() -> Array[String]:
	var found: Array[String] = []
	var dirs: Array[String] = [UI_DIR]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(dir):
			dirs.append(dir + sub + "/")
		for file: String in DirAccess.get_files_at(dir):
			if file.get_extension() == "png":
				found.append(dir + file)
	found.sort()
	return found


## Outline-exempt (DESIGN / story Dev Notes): the focus ring is its own edge, the card pictures are scenes
## like the backdrops, and the glow overlays' candy outline is their edge.
func _outline_exempt(path: String) -> bool:
	return path.ends_with("ui_focus_ring.png") or path.get_file().begins_with("ui_level_card_") \
			or path.get_file().begins_with("ui_finger_glow_")


## candy-yellow means "look here": the focus ring, the glow overlays, the tutorial arrows, the Caps Lock sign.
func _candy_allowed(path: String) -> bool:
	return path.ends_with("ui_focus_ring.png") or path.get_file().begins_with("ui_finger_glow_") \
			or path.get_file().begins_with("ui_arrow_") or path.ends_with("ui_candy_sign.png")


## stamp-red: the "New best!" stamp and the toggle icons' off frame (frame 1) only.
func _stamp_allowed(path: String) -> bool:
	return path.ends_with("ui_new_best.png") or path.get_file().begins_with("ui_icon_") \
			and not path.ends_with("ui_icon_pause.png")


func _colors(image: Image, region: Rect2i) -> Dictionary[String, int]:
	var found: Dictionary[String, int] = {}
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if _opaque(image, x, y):
				var hex: String = _hex(image, x, y)
				found[hex] = found.get(hex, 0) + 1
	return found


func _luma(hex: String) -> float:
	var c: Color = Color(hex)
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func test_palette_loaded() -> void:
	assert_eq(_palette.size(), 32)


func test_every_ui_png_is_listed() -> void:
	var files: Array[String] = _ui_pngs()
	assert_gt(files.size(), 0, "no UI art found")
	for path: String in files:
		assert_true(UI_SHEETS.has(path), "%s is not in UI_SHEETS (the story's UI sheet list)" % _name(path))


func test_every_listed_sheet_exists_with_its_size() -> void:
	for path: String in UI_SHEETS:
		var image: Image = _load(path)
		assert_not_null(image, "%s missing" % _name(path))
		if image == null:
			continue
		var spec: Array = UI_SHEETS[path]
		assert_eq(image.get_size(), spec[0] as Vector2i, "%s size" % _name(path))
		var frames: int = spec[1]
		assert_eq(image.get_width() % frames, 0, "%s splits into %d frames" % [_name(path), frames])


func test_hard_alpha_and_palette_only() -> void:
	for path: String in _ui_pngs():
		var image: Image = _load(path)
		var bad: Array[String] = []
		for y: int in image.get_height():
			for x: int in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a8 != 0 and color.a8 != 255:
					bad.append("(%d,%d) alpha %d" % [x, y, color.a8])
				elif color.a8 == 255 and not _palette.has(color.to_html(false)):
					bad.append("(%d,%d) rgb %s off palette" % [x, y, color.to_html(false)])
		assert_eq(bad.size(), 0, "%s: %s" % [_name(path), ", ".join(bad.slice(0, 10))])


func test_import_settings_lossless_no_mipmaps() -> void:
	for path: String in _ui_pngs():
		var config: ConfigFile = ConfigFile.new()
		var err: Error = config.load(path + ".import")
		assert_eq(err, OK, "%s.import missing" % _name(path))
		if err != OK:
			continue
		assert_eq(config.get_value("params", "compress/mode", -1), 0, "%s compress/mode" % _name(path))
		assert_eq(config.get_value("params", "mipmaps/generate", true), false, "%s mipmaps" % _name(path))


## Style sheet rule 4 for every UI sheet but the exemptions: an opaque pixel that is not ink has all four
## neighbours opaque, inside its own frame.
func test_outline_rule() -> void:
	for path: String in _ui_pngs():
		if _outline_exempt(path) or not UI_SHEETS.has(path):
			continue
		var image: Image = _load(path)
		var frames: int = UI_SHEETS[path][1]
		var fw: int = image.get_width() / frames
		var bad: Array[String] = []
		for frame: int in frames:
			for y: int in image.get_height():
				for x: int in fw:
					var px: int = frame * fw + x
					if not _opaque(image, px, y) or _hex(image, px, y) == INK:
						continue
					for step: Vector2i in NEIGHBOURS:
						var nx: int = x + step.x
						var ny: int = y + step.y
						if nx < 0 or ny < 0 or nx >= fw or ny >= image.get_height() \
								or not _opaque(image, frame * fw + nx, ny):
							bad.append("frame %d (%d,%d) %s" % [frame, x, y, _hex(image, px, y)])
							break
		assert_eq(bad.size(), 0, "%s open edge: %s" % [_name(path), ", ".join(bad.slice(0, 10))])


func test_candy_yellow_and_stamp_red_only_where_allowed() -> void:
	for path: String in _ui_pngs():
		var image: Image = _load(path)
		var colors: Dictionary[String, int] = _colors(image, Rect2i(Vector2i.ZERO, image.get_size()))
		if not _candy_allowed(path):
			assert_false(colors.has(CANDY_YELLOW), "%s: candy-yellow" % _name(path))
		if not _stamp_allowed(path):
			assert_false(colors.has(STAMP_RED), "%s: stamp-red" % _name(path))


## The level card pictures are scenes: never the focus or stamp colours.
func test_card_pictures_have_no_candy_or_stamp() -> void:
	for id: String in ["zombie_run", "horde_rush", "pitchfork_panic"]:
		var image: Image = _load(M + "ui_level_card_%s.png" % id)
		assert_not_null(image, id)
		if image == null:
			continue
		var colors: Dictionary[String, int] = _colors(image, Rect2i(Vector2i.ZERO, image.get_size()))
		assert_false(colors.has(CANDY_YELLOW), "%s: candy-yellow" % id)
		assert_false(colors.has(STAMP_RED), "%s: stamp-red" % id)
		assert_eq(image.get_used_rect(), Rect2i(0, 0, 184, 72), "%s fills its window" % id)


## The toggle icons: the off frame carries a stamp-red diagonal slash, the on frame none (the slash, not the
## colour, is the signal).
func test_toggle_off_frame_has_the_slash() -> void:
	for kind: String in ["music", "sound", "fullscreen"]:
		var image: Image = _load(C + "ui_icon_%s.png" % kind)
		assert_not_null(image, kind)
		if image == null:
			continue
		assert_false(_colors(image, Rect2i(0, 0, 20, 20)).has(STAMP_RED), "%s on frame: no slash" % kind)
		var diagonal: int = 0
		for y: int in range(4, 16):
			var x: int = 20 + 19 - y
			if _hex(image, x, y) == STAMP_RED or _hex(image, x - 1, y) == STAMP_RED:
				diagonal += 1
		assert_eq(diagonal, 12, "%s off frame: a slash from bottom-left to top-right" % kind)


func test_glow_sheets_are_two_frames_of_their_hand() -> void:
	for side: String in ["l", "r"]:
		var hand: Image = _load(HA + "ui_hand_%s.png" % ("left" if side == "l" else "right"))
		assert_not_null(hand)
		if hand == null:
			continue
		assert_eq(hand.get_size(), HAND_SIZE)
		for finger: String in FINGERS:
			var glow: Image = _load(HA + "ui_finger_glow_%s_%s.png" % [side, finger])
			assert_not_null(glow, "%s %s" % [side, finger])
			if glow == null:
				continue
			assert_eq(glow.get_size(), Vector2i(hand.get_width() * 2, hand.get_height()), "%s %s" % [side, finger])


## The right hand and its glow sheets are the left ones mirrored (frame by frame).
func test_right_hand_mirrors_the_left() -> void:
	var left: Image = _load(HA + "ui_hand_left.png")
	var right: Image = _load(HA + "ui_hand_right.png")
	if left == null or right == null:
		fail_test("hand sheets missing")
		return
	left.flip_x()
	assert_eq(left.get_data(), right.get_data())
	for finger: String in FINGERS:
		var l: Image = _load(HA + "ui_finger_glow_l_%s.png" % finger)
		var r: Image = _load(HA + "ui_finger_glow_r_%s.png" % finger)
		if l == null or r == null:
			continue
		for frame: int in 2:
			var lf: Image = l.get_region(Rect2i(frame * 64, 0, 64, 48))
			lf.flip_x()
			assert_eq(lf.get_data(), r.get_region(Rect2i(frame * 64, 0, 64, 48)).get_data(), "%s frame %d" % [finger, frame])


## AC 5 / NFR8: the lit finger's fill (the glow sheet's main colour) is zombie-green-bright, the resting hand
## zombie-green, at least MIN_LUMA_GAP apart in Rec. 709 luma; the index sheets keep the bump.
func test_lit_finger_is_brighter_in_grayscale() -> void:
	var hand: Image = _load(HA + "ui_hand_left.png")
	if hand == null:
		fail_test("hand missing")
		return
	var rest: String = _most_common(_colors(hand, Rect2i(Vector2i.ZERO, HAND_SIZE)), [INK])
	assert_eq(rest, ZOMBIE_GREEN, "the resting hand is zombie-green")
	for finger: String in FINGERS:
		var glow: Image = _load(HA + "ui_finger_glow_l_%s.png" % finger)
		if glow == null:
			continue
		for frame: int in 2:
			var colors: Dictionary[String, int] = _colors(glow, Rect2i(frame * 64, 0, 64, 48))
			var lit: String = _most_common(colors, [INK, CANDY_YELLOW])
			assert_eq(lit, ZOMBIE_GREEN_BRIGHT, "%s frame %d fill" % [finger, frame])
			assert_gte(_luma(lit) - _luma(rest), MIN_LUMA_GAP, "%s luma gap" % finger)
			assert_eq(colors.has("2e6b26"), true, "%s keeps its zombie-green-dark shade or bump" % finger)
	gut.p("luma: rest %.3f, lit %.3f, gap %.3f; candy %.3f" % [_luma(ZOMBIE_GREEN), _luma(ZOMBIE_GREEN_BRIGHT),
			_luma(ZOMBIE_GREEN_BRIGHT) - _luma(ZOMBIE_GREEN), _luma(CANDY_YELLOW)])


## Candy pixels in one frame that touch no finger pixel and no candy pixel that does: a ring wider than 2 px.
func _candy_beyond_two_px(glow: Image, frame: int) -> int:
	var inner: Dictionary[Vector2i, bool] = {}
	var candy: Array[Vector2i] = []
	for y: int in 48:
		for x: int in 64:
			if not _opaque(glow, frame * 64 + x, y):
				continue
			if _hex(glow, frame * 64 + x, y) == CANDY_YELLOW:
				candy.append(Vector2i(x, y))
	for spot: Vector2i in candy:
		for step: Vector2i in NEIGHBOURS:
			var n: Vector2i = spot + step
			if n.x >= 0 and n.y >= 0 and n.x < 64 and n.y < 48 and _opaque(glow, frame * 64 + n.x, n.y) 					and _hex(glow, frame * 64 + n.x, n.y) != CANDY_YELLOW:
				inner[spot] = true
	var far: int = 0
	for spot: Vector2i in candy:
		if inner.has(spot):
			continue
		var next_to_inner: bool = false
		for step: Vector2i in NEIGHBOURS:
			if inner.has(spot + step):
				next_to_inner = true
		if not next_to_inner:
			far += 1
	return far


## AC 5: the candy outline rings the finger: above its top, left and right of it, in both frames; the strong
## frame's ring is 2 px (some candy pixels touch no finger pixel), the weak one 1 px (every candy pixel does).
func test_glow_ring_is_two_px_strong_one_px_weak() -> void:
	for finger: String in FINGERS:
		var glow: Image = _load(HA + "ui_finger_glow_l_%s.png" % finger)
		if glow == null:
			fail_test("%s missing" % finger)
			continue
		for frame: int in 2:
			var outer: int = 0
			var finger_px: Rect2i = Rect2i()
			var first: bool = true
			for y: int in 48:
				for x: int in 64:
					var px: int = frame * 64 + x
					if not _opaque(glow, px, y):
						continue
					if _hex(glow, px, y) != CANDY_YELLOW:
						var here: Rect2i = Rect2i(x, y, 1, 1)
						finger_px = here if first else finger_px.merge(here)
						first = false
						continue
					var touches: bool = false
					for step: Vector2i in NEIGHBOURS:
						var nx: int = x + step.x
						var ny: int = y + step.y
						if nx >= 0 and ny >= 0 and nx < 64 and ny < 48 and _opaque(glow, frame * 64 + nx, ny) \
								and _hex(glow, frame * 64 + nx, ny) != CANDY_YELLOW:
							touches = true
					if not touches:
						outer += 1
			var too_far: int = _candy_beyond_two_px(glow, frame)
			assert_eq(too_far, 0, "%s frame %d: the ring is at most 2 px wide" % [finger, frame])
			if frame == 0:
				assert_gt(outer, 0, "%s strong frame: a 2 px ring" % finger)
			else:
				assert_eq(outer, 0, "%s weak frame: a 1 px ring" % finger)
			assert_false(first, "%s frame %d has the finger" % [finger, frame])
			if first:
				continue
			# Candy on the finger's far side from the palm (above it; left of the thumb's tip side: right).
			var tip: Vector2i = Vector2i(finger_px.get_center().x, finger_px.position.y - 1)
			if finger == "thumb":
				tip = Vector2i(finger_px.end.x, finger_px.get_center().y)
			assert_eq(_hex(glow, frame * 64 + tip.x, tip.y), CANDY_YELLOW, "%s frame %d ring at the tip" % [finger, frame])
			var mid_y: int = finger_px.get_center().y if finger != "thumb" else finger_px.position.y - 1
			if finger == "thumb":
				assert_eq(_hex(glow, frame * 64 + finger_px.get_center().x, mid_y), CANDY_YELLOW, "thumb ring above")
			else:
				assert_eq(_hex(glow, frame * 64 + finger_px.position.x - 1, mid_y), CANDY_YELLOW, "%s left side" % finger)
				assert_eq(_hex(glow, frame * 64 + finger_px.end.x, mid_y), CANDY_YELLOW, "%s right side" % finger)


func test_index_fingers_carry_the_bump() -> void:
	for side: String in ["left", "right"]:
		var hand: Image = _load(HA + "ui_hand_%s.png" % side)
		if hand == null:
			continue
		var dark: int = _colors(hand, Rect2i(0, 0, 64, 20)).get("2e6b26", 0)
		assert_gt(dark, 0, "%s index fingertip bump (rows 0-19)" % side)


func _most_common(colors: Dictionary[String, int], skip: Array[String]) -> String:
	var best: String = ""
	var count: int = -1
	for hex: String in colors:
		if hex in skip:
			continue
		if colors[hex] > count:
			best = hex
			count = colors[hex]
	return best


## A 9-slice source is at least 2 x margin + 1 in each axis.
func test_nine_slices_fit_their_margins() -> void:
	for path: String in UI_SHEETS:
		var margins: Array = UI_SHEETS[path][2]
		if margins.is_empty():
			continue
		var size: Vector2i = UI_SHEETS[path][0]
		assert_gte(size.x, int(margins[0]) + int(margins[2]) + 1, "%s width" % _name(path))
		assert_gte(size.y, int(margins[1]) + int(margins[3]) + 1, "%s height" % _name(path))


## Every StyleBoxTexture in the shared theme uses a listed 9-slice with the table's margins.
func test_theme_texture_margins_match_the_table() -> void:
	var theme: Theme = load(THEME_PATH) as Theme
	var seen: int = 0
	for type_name: StringName in theme.get_stylebox_type_list():
		for style_name: StringName in theme.get_stylebox_list(type_name):
			var box: StyleBoxTexture = theme.get_stylebox(style_name, type_name) as StyleBoxTexture
			if box == null:
				continue
			seen += 1
			var path: String = box.texture.resource_path if box.texture != null else ""
			assert_true(UI_SHEETS.has(path), "%s/%s texture %s is a listed UI sheet" % [type_name, style_name, path])
			if not UI_SHEETS.has(path):
				continue
			var margins: Array = UI_SHEETS[path][2]
			var actual: Array[int] = [int(box.texture_margin_left), int(box.texture_margin_top),
					int(box.texture_margin_right), int(box.texture_margin_bottom)]
			# A one-size sheet (the round pause button) is drawn whole: no margins.
			var expected: Array[int] = [0, 0, 0, 0]
			if not margins.is_empty():
				expected = [int(margins[0]), int(margins[1]), int(margins[2]), int(margins[3])]
			assert_eq(actual, expected, "%s/%s margins" % [type_name, style_name])
	assert_gt(seen, 0, "the theme has StyleBoxTextures")
