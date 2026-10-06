class_name UiArtReview
extends Control
## UI art review scene (Story 5.0, Gate 1). Dev/Smuck only, like scenes/debug/art_review.tscn: never routed
## to, never instanced by the Router, no menu button. Run it directly:
##   "/c/Program Files/Godot/Godot.exe" --path . res://scenes/debug/ui_art_review.tscn
## Pages (N): every UI sheet at 1x and 3x; the 9-slices stretched to two real sizes each; the hands with
## each finger lit (strong and weak frames); the hands at 3x with a grayscale copy (Rec. 709 luma, a debug
## view only, not palette art); the menu and report card pieces at 1x. B cycles the background (palette
## colours), Esc quits. F3/F5/F8/F9 are left to the debug overlay.

const UI_DIR: String = "res://assets/sprites/ui/"
const HANDS_DIR: String = "res://assets/sprites/ui/hands/"
const DETAIL_SCALE: int = 3
const MARGIN: int = 16
const GAP: int = 8
const LABEL_PX: int = 8
const VIEWPORT: Vector2i = Vector2i(640, 360)
const FINGERS: Array[String] = ["pinky", "ring", "middle", "index", "thumb"]
## Where each hand sits in the HUD's 312 x 48 hands area (ZombieHands.LEFT_X / RIGHT_X).
const LEFT_X: int = 56
const RIGHT_X: int = 192
## [name, background]; palette colours only (DESIGN.md -> Colors).
const BACKGROUNDS: Array[Array] = [
	["night", Color("#2b1d3f")],
	["parchment", Color("#f6e7c1")],
	["wood-dark", Color("#5a3218")],
	["chalkboard", Color("#24402f")],
	["art-sky", Color("#7ec8e3")],
]
## 9-slices whose middle is patterned (plank grain, stone courses): tiled, as the theme does, not stretched.
const TILED: Array[String] = ["common/ui_panel_wood.png", "common/ui_panel_stone.png"]
## 9-slice sheet -> [margins l, t, r, b] and the two real sizes it is shown at.
const NINE_SLICES: Dictionary[String, Array] = {
	"common/ui_button.png": [[4, 4, 4, 6], Vector2i(96, 34), Vector2i(176, 34)],
	"common/ui_button_focus.png": [[4, 4, 4, 6], Vector2i(96, 34), Vector2i(176, 34)],
	"common/ui_button_pressed.png": [[4, 4, 4, 6], Vector2i(96, 34), Vector2i(176, 34)],
	"common/ui_button_disabled.png": [[4, 4, 4, 6], Vector2i(96, 34), Vector2i(176, 34)],
	"common/ui_focus_ring.png": [[4, 4, 4, 4], Vector2i(100, 38), Vector2i(72, 72)],
	"common/ui_panel_wood.png": [[8, 8, 8, 8], Vector2i(96, 64), Vector2i(176, 96)],
	"common/ui_panel_stone.png": [[8, 8, 8, 8], Vector2i(96, 64), Vector2i(176, 96)],
	"common/ui_sign.png": [[4, 4, 4, 4], Vector2i(48, 40), Vector2i(184, 40)],
	"common/ui_sign_grey.png": [[4, 4, 4, 4], Vector2i(48, 40), Vector2i(184, 40)],
	"common/ui_keycap.png": [[4, 4, 4, 4], Vector2i(56, 24), Vector2i(88, 24)],
	"common/ui_candy_sign.png": [[4, 4, 4, 4], Vector2i(96, 28), Vector2i(256, 28)],
	"common/ui_brain_pill.png": [[12, 12, 12, 12], Vector2i(80, 28), Vector2i(120, 28)],
	"common/ui_ink_md.png": [[4, 4, 4, 4], Vector2i(68, 68), Vector2i(176, 24)],
	"common/ui_ink_lg.png": [[8, 8, 8, 8], Vector2i(96, 64), Vector2i(192, 124)],
	"menu/ui_card_frame.png": [[8, 8, 8, 8], Vector2i(96, 64), Vector2i(192, 124)],
	"hud/ui_hud_band.png": [[8, 8, 8, 8], Vector2i(176, 52), Vector2i(320, 52)],
	"report_card/ui_chalkboard.png": [[8, 8, 8, 8], Vector2i(176, 96), Vector2i(208, 138)],
	"closet/ui_tile_parchment.png": [[4, 4, 4, 4], Vector2i(68, 68), Vector2i(48, 48)],
	"closet/ui_tile_stone.png": [[4, 4, 4, 4], Vector2i(68, 68), Vector2i(48, 48)],
	"closet/ui_tile_disabled.png": [[4, 4, 4, 4], Vector2i(68, 68), Vector2i(48, 48)],
	"closet/ui_tag_pumpkin.png": [[4, 4, 4, 4], Vector2i(64, 20), Vector2i(40, 20)],
	"closet/ui_tag_green.png": [[4, 4, 4, 4], Vector2i(64, 20), Vector2i(40, 20)],
	"closet/ui_tag_bright.png": [[4, 4, 4, 4], Vector2i(64, 20), Vector2i(40, 20)],
	"closet/ui_mirror.png": [[8, 8, 8, 8], Vector2i(152, 120), Vector2i(64, 64)],
	"closet/ui_ribbon.png": [[4, 1, 4, 1], Vector2i(24, 120), Vector2i(24, 64)],
}

var _background_index: int = 0
var _pages: Array[Control] = []
var _page_names: Array[String] = []
var _page_index: int = 0
var _shown_paths: Dictionary[String, bool] = {}


func _ready() -> void:
	_build_sheets_pages()
	_build_nine_slice_pages()
	_build_hands_page()
	_build_hands_detail_page()
	_build_pieces_page()
	for i: int in _pages.size():
		_pages[i].visible = i == 0
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_B:
		_cycle_background()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_N:
		_next_page()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().quit()


## Every .png under assets/sprites/ui/ (relative paths), walking the folders. An export lists .import files
## instead of the PNGs, so those count too.
static func ui_sheets() -> Array[String]:
	var found: Array[String] = []
	var dirs: Array[String] = [""]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub: String in DirAccess.get_directories_at(UI_DIR + dir):
			dirs.append(dir + sub + "/")
		for file: String in DirAccess.get_files_at(UI_DIR + dir):
			var sheet: String = file.trim_suffix(".import")
			if sheet.get_extension() == "png" and not found.has(dir + sheet):
				found.append(dir + sheet)
	found.sort()
	return found


## A grayscale copy (Rec. 709 luma) of an image: a debug view for the NFR8 check, not palette art.
static func grayscale(image: Image) -> Image:
	var out: Image = image.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	for y: int in out.get_height():
		for x: int in out.get_width():
			var c: Color = out.get_pixel(x, y)
			var luma: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			out.set_pixel(x, y, Color(luma, luma, luma, c.a))
	return out


func page_count() -> int:
	return _pages.size()


func page_index() -> int:
	return _page_index


func page_name() -> String:
	return _page_names[_page_index] if not _page_names.is_empty() else ""


func page_names() -> Array[String]:
	return _page_names.duplicate()


func background_name() -> String:
	return BACKGROUNDS[_background_index][0]


func background_color() -> Color:
	return BACKGROUNDS[_background_index][1]


## The sheets shown on any page (relative paths).
func shown_sheets() -> Array[String]:
	var paths: Array[String] = []
	paths.assign(_shown_paths.keys())
	paths.sort()
	return paths


func _next_page() -> void:
	if _pages.is_empty():
		return
	_page_index = (_page_index + 1) % _pages.size()
	for i: int in _pages.size():
		_pages[i].visible = i == _page_index
	_refresh()


func _cycle_background() -> void:
	_background_index = (_background_index + 1) % BACKGROUNDS.size()
	_refresh()


func _refresh() -> void:
	%Background.color = background_color()
	%Footer.text = "%s  (page %d/%d)  bg %s   B: background  N: page  Esc: quit" % [
		page_name(), _page_index + 1, _pages.size(), background_name()]


func _new_page(title: String) -> Control:
	var page: Control = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size = Vector2(VIEWPORT)
	add_child(page)
	_pages.append(page)
	_page_names.append(title)
	return page


func _texture(rel: String) -> Texture2D:
	var texture: Texture2D = load(UI_DIR + rel) as Texture2D
	if texture == null:
		push_error("UiArtReview: cannot load %s" % rel)
	else:
		_shown_paths[rel] = true
	return texture


func _sprite(parent: Control, texture: Texture2D, at: Vector2, scale_factor: int = 1, region: Rect2 = Rect2()) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	if region.has_area():
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		rect.texture = atlas
	else:
		rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = at
	rect.size = rect.texture.get_size() * scale_factor if rect.texture != null else Vector2.ZERO
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label(parent: Control, text: String, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", LABEL_PX)
	label.add_theme_color_override("font_color", Color("#f4f1e4"))
	label.add_theme_color_override("font_outline_color", Color("#1e1428"))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


## Pages of every sheet that is not a 9-slice, the hands or a big piece: 1x beside 3x, flowed in rows.
func _build_sheets_pages() -> void:
	var small: Array[String] = []
	for rel: String in ui_sheets():
		var texture: Texture2D = load(UI_DIR + rel) as Texture2D
		if texture == null or NINE_SLICES.has(rel) or rel.begins_with("hands/") or texture.get_width() > 64:
			continue
		small.append(rel)
	var page: Control = _new_page("sheets 1x / 3x")
	var x: int = MARGIN
	var y: int = MARGIN
	var row_h: int = 0
	var count: int = 1
	for rel: String in small:
		var texture: Texture2D = _texture(rel)
		var size: Vector2i = Vector2i(texture.get_size())
		var caption: String = rel.get_file().trim_prefix("ui_").get_basename()
		var w: int = maxi(size.x * (1 + DETAIL_SCALE) + GAP, caption.length() * LABEL_PX)
		var h: int = size.y * DETAIL_SCALE + LABEL_PX + 4
		if x + w > VIEWPORT.x - MARGIN:
			x = MARGIN
			y += row_h + GAP
			row_h = 0
		if y + h > VIEWPORT.y - 24:
			count += 1
			page = _new_page("sheets 1x / 3x (%d)" % count)
			x = MARGIN
			y = MARGIN
			row_h = 0
		_label(page, caption, Vector2(x, y))
		_sprite(page, texture, Vector2(x, y + LABEL_PX + 4 + size.y * (DETAIL_SCALE - 1)))
		_sprite(page, texture, Vector2(x + size.x + GAP, y + LABEL_PX + 4), DETAIL_SCALE)
		x += w + GAP
		row_h = maxi(row_h, h)


## Each 9-slice stretched to two real sizes (NinePatchRect with the theme's margins), flowed in rows.
func _build_nine_slice_pages() -> void:
	var page: Control = _new_page("9-slices at real sizes")
	var count: int = 1
	var x: int = MARGIN
	var y: int = MARGIN
	var row_h: int = 0
	for rel: String in NINE_SLICES:
		var spec: Array = NINE_SLICES[rel]
		var a: Vector2i = spec[1]
		var b: Vector2i = spec[2]
		var w: int = a.x + GAP + b.x
		var h: int = maxi(a.y, b.y) + LABEL_PX + 4
		if x + w > VIEWPORT.x - MARGIN:
			x = MARGIN
			y += row_h + GAP
			row_h = 0
		if y + h > VIEWPORT.y - 24:
			count += 1
			page = _new_page("9-slices at real sizes (%d)" % count)
			x = MARGIN
			y = MARGIN
			row_h = 0
		var texture: Texture2D = _texture(rel)
		_label(page, rel.get_file().trim_prefix("ui_").get_basename(), Vector2(x, y))
		_nine(page, texture, spec[0], Rect2(x, y + LABEL_PX + 4, a.x, a.y), TILED.has(rel))
		_nine(page, texture, spec[0], Rect2(x + a.x + GAP, y + LABEL_PX + 4, b.x, b.y), TILED.has(rel))
		x += w + GAP * 2
		row_h = maxi(row_h, h)


func _nine(parent: Control, texture: Texture2D, margins: Array, rect: Rect2, tiled: bool = false) -> void:
	var patch: NinePatchRect = NinePatchRect.new()
	if tiled:
		patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	patch.texture = texture
	patch.patch_margin_left = margins[0]
	patch.patch_margin_top = margins[1]
	patch.patch_margin_right = margins[2]
	patch.patch_margin_bottom = margins[3]
	patch.position = rect.position
	patch.size = rect.size
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(patch)


## Every finger lit, both frames, on its hand at 1x: rows strong / weak, left hand then right hand.
func _build_hands_page() -> void:
	var page: Control = _new_page("hands: each finger lit (strong / weak)")
	var hands: Dictionary[String, Texture2D] = {"l": _texture("hands/ui_hand_left.png"), "r": _texture("hands/ui_hand_right.png")}
	var row: int = 0
	for side: String in ["l", "r"]:
		for frame: int in 2:
			var y: int = MARGIN + row * 76
			_label(page, "%s hand, %s" % ["left" if side == "l" else "right", "strong" if frame == 0 else "weak"],
					Vector2(MARGIN, y))
			for i: int in FINGERS.size():
				var x: int = MARGIN + i * 120
				var glow: Texture2D = _texture("hands/ui_finger_glow_%s_%s.png" % [side, FINGERS[i]])
				_sprite(page, hands[side], Vector2(x, y + 12))
				_sprite(page, glow, Vector2(x, y + 12), 1, Rect2(frame * 64, 0, 64, 48))
				_label(page, FINGERS[i], Vector2(x + 66, y + 30))
			row += 1


## The hands as the HUD shows them (left index + right pinky lit, a capital) at 3x, and a grayscale copy.
func _build_hands_detail_page() -> void:
	var page: Control = _new_page("hands 3x and grayscale (capital F: left index + right pinky)")
	var composite: Image = Image.create_empty(312, 48, false, Image.FORMAT_RGBA8)
	for part: Array in [["hands/ui_hand_left.png", LEFT_X, 0], ["hands/ui_hand_right.png", RIGHT_X, 0],
			["hands/ui_finger_glow_l_index.png", LEFT_X, 0], ["hands/ui_finger_glow_r_pinky.png", RIGHT_X, 0]]:
		var texture: Texture2D = _texture(part[0])
		if texture == null:
			continue
		var image: Image = texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var region: Rect2i = Rect2i(0, 0, 64, 48)
		composite.blend_rect(image, region, Vector2i(part[1], part[2]))
	var color: ImageTexture = ImageTexture.create_from_image(composite)
	var gray: ImageTexture = ImageTexture.create_from_image(grayscale(composite))
	_label(page, "colour, 1x (the HUD hands area)", Vector2(MARGIN, MARGIN))
	_sprite(page, color, Vector2(MARGIN, MARGIN + 12))
	_label(page, "grayscale, 1x", Vector2(MARGIN + 320, MARGIN))
	_sprite(page, gray, Vector2(MARGIN + 320, MARGIN + 12))
	var left: Image = composite.get_region(Rect2i(LEFT_X, 0, 64, 48))
	_label(page, "left hand 3x, colour and grayscale", Vector2(MARGIN, 84))
	_sprite(page, ImageTexture.create_from_image(left), Vector2(MARGIN, 96), DETAIL_SCALE)
	_sprite(page, ImageTexture.create_from_image(grayscale(left)), Vector2(MARGIN + 64 * DETAIL_SCALE + GAP, 96),
			DETAIL_SCALE)


## The big pieces at 1x: logos, the level cards in their frames with the Coming soon plank, the report card
## extras, the Closet sign and the Welcome Gift bow.
func _build_pieces_page() -> void:
	var page: Control = _new_page("logos and level cards, 1x")
	_sprite(page, _texture("menu/ui_logo.png"), Vector2(MARGIN, MARGIN))
	_sprite(page, _texture("menu/ui_logo_small.png"), Vector2(MARGIN, 140))
	var frame: Texture2D = _texture("menu/ui_card_frame.png")
	_card(page, frame, "zombie_run", Vector2(328, MARGIN), false)
	_card(page, frame, "horde_rush", Vector2(MARGIN, 192), true)
	_card(page, frame, "pitchfork_panic", Vector2(MARGIN + 208, 192), true)
	var extras: Control = _new_page("report card, closet and gift pieces, 1x")
	_sprite(extras, _texture("report_card/ui_chalk_tray.png"), Vector2(MARGIN, MARGIN))
	_sprite(extras, _texture("report_card/ui_new_best.png"), Vector2(MARGIN, 40))
	_sprite(extras, _texture("closet/ui_closet_sign.png"), Vector2(MARGIN + 160, 40))
	_sprite(extras, _texture("menu/ui_coming_soon.png"), Vector2(MARGIN + 330, 40))
	_sprite(extras, _texture("hud/ui_cushion.png"), Vector2(MARGIN, 120))
	_sprite(extras, _texture("closet/ui_bow.png"), Vector2(MARGIN + 64, 120))
	_sprite(extras, _texture("report_card/ui_moon.png"), Vector2(MARGIN + 128, 120))
	_sprite(extras, _texture("report_card/ui_bat.png"), Vector2(MARGIN + 170, 120))
	_sprite(extras, _texture("menu/ui_signpost.png"), Vector2(MARGIN + 200, 120))
	_sprite(extras, _texture("menu/ui_thumbtack.png"), Vector2(MARGIN + 220, 120))
	_sprite(extras, _texture("closet/ui_locked.png"), Vector2(MARGIN + 240, 120))
	_sprite(extras, _texture("common/ui_brain_icon_big.png"), Vector2(MARGIN + 290, 120))
	_label(extras, "3x", Vector2(MARGIN, 176))
	_sprite(extras, _texture("report_card/ui_new_best.png"), Vector2(MARGIN, 188), 2)
	_sprite(extras, _texture("hud/ui_cushion.png"), Vector2(MARGIN + 300, 188), DETAIL_SCALE)


## A level card as the menu builds it: the frame 9-slice, the picture at (4, 4), the plank if coming soon.
func _card(parent: Control, frame: Texture2D, id: String, at: Vector2, coming_soon: bool) -> void:
	_nine(parent, frame, [8, 8, 8, 8], Rect2(at, Vector2(192, 124)))
	_sprite(parent, _texture("menu/ui_level_card_%s.png" % id), at + Vector2(4, 4))
	if coming_soon:
		var plank: Texture2D = _texture("menu/ui_coming_soon.png")
		_sprite(parent, plank, at + Vector2(4, 4) + (Vector2(184, 72) - plank.get_size()) / 2.0)
