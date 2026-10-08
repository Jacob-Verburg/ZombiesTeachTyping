class_name ArtReview
extends Control
## Art review scene (Story 1.9, the art-style gate). Dev/Smuck only (Boundary 7): never routed to,
## never instanced by the Router, no menu button, no autoload. Run it directly:
##   "/c/Program Files/Godot/Godot.exe" --path . res://scenes/debug/art_review.tscn
## (or the Godot MCP run_project with that scene). Shows, at 640x360 with the project's stretch and
## Nearest filter: the 32-color palette strip, each animation at 1x and 3x (PAGE_SIZE per page), a type
## specimen in the project font at 16/24/32 px, and a footer with the window scale and background.
## Story 3.6 adds the Zombie Run set (hop, hug, dance, poof, party walk, brain block, bonk, brain pop);
## props are 16x16 frames (an animation's "size", default FRAME). Story 6.6 adds the Horde Rush set
## (zombie flash and melt, the Farmer's idle/walk/throw, the tomato and its splat).
## B cycles the plain background (palette colors only), N the animation page, Esc quits. F3/F5/F8/F9 are left alone (the
## debug overlay, added by the Router in debug runs, owns them).

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const FRAME: int = 32
const VIEWPORT: Vector2i = Vector2i(640, 360)
const DETAIL_SCALE: int = 3
const PROP_FRAME: int = 16
## Style sheet: idle/wave at the 8 fps floor, walk at 10 fps (suits the 24 px/s amble). Names are keys,
## so the party-hat zombie's idle (Story 3.3) is "party_idle". Story 3.6: hop and hug at 10 fps, the
## dance at 8 fps (one 4-frame cycle = one 2 Hz bounce), the poof and the bonk at 12 fps (they play once
## in the game and loop here), the block idle and the brain pop at 8 fps.
const IDLE_FPS: float = 8.0
const WALK_FPS: float = 10.0
const WAVE_FPS: float = 8.0
const HOP_FPS: float = 10.0
const HUG_FPS: float = 10.0
const DANCE_FPS: float = 8.0
const POOF_FPS: float = 12.0
const BLOCK_IDLE_FPS: float = 8.0
const BONK_FPS: float = 12.0
const POP_FPS: float = 8.0
## Story 6.6: the flash swaps with the walk at the walk's rate; the melt is tween-stepped over melt_s in
## the game (10 fps at 0.6 s), the throw and the splat play once at 12 fps, the tomato spins at 10 fps.
const FLASH_FPS: float = WALK_FPS
const MELT_FPS: float = 10.0
const FARMER_THROW_FPS: float = 12.0
const TOMATO_FPS: float = 10.0
const SPLAT_FPS: float = 12.0
const ANIMATIONS: Array[Dictionary] = [
	{"name": "idle", "path": "res://assets/sprites/characters/zombie/zombie_idle.png", "frames": 2, "fps": IDLE_FPS},
	{"name": "walk", "path": "res://assets/sprites/characters/zombie/zombie_walk.png", "frames": 4, "fps": WALK_FPS},
	{"name": "wave", "path": "res://assets/sprites/characters/villager/villager_wave.png", "frames": 2, "fps": WAVE_FPS},
	{"name": "party_idle", "path": "res://assets/sprites/characters/party_zombie/party_zombie_idle.png", "frames": 2, "fps": IDLE_FPS},
	{"name": "hop", "path": "res://assets/sprites/characters/zombie/zombie_hop.png", "frames": 3, "fps": HOP_FPS},
	{"name": "hug", "path": "res://assets/sprites/characters/zombie/zombie_hug.png", "frames": 3, "fps": HUG_FPS},
	{"name": "dance", "path": "res://assets/sprites/characters/zombie/zombie_dance.png", "frames": 4, "fps": DANCE_FPS},
	{"name": "poof", "path": "res://assets/sprites/characters/villager/villager_poof.png", "frames": 4, "fps": POOF_FPS},
	{"name": "party_walk", "path": "res://assets/sprites/characters/party_zombie/party_zombie_walk.png", "frames": 4, "fps": WALK_FPS},
	{"name": "block_idle", "path": "res://assets/sprites/props/brain_block_idle.png", "frames": 2, "fps": BLOCK_IDLE_FPS, "size": PROP_FRAME},
	{"name": "block_bonk", "path": "res://assets/sprites/props/brain_block_bonk.png", "frames": 3, "fps": BONK_FPS, "size": PROP_FRAME},
	{"name": "brain_pop", "path": "res://assets/sprites/props/brain_pop.png", "frames": 2, "fps": POP_FPS, "size": PROP_FRAME},
	{"name": "flash", "path": "res://assets/sprites/characters/zombie/zombie_flash.png", "frames": 4, "fps": FLASH_FPS},
	{"name": "melt", "path": "res://assets/sprites/characters/zombie/zombie_melt.png", "frames": 6, "fps": MELT_FPS},
	{"name": "farmer_idle", "path": "res://assets/sprites/characters/farmer/farmer_idle.png", "frames": 2, "fps": IDLE_FPS},
	{"name": "farmer_walk", "path": "res://assets/sprites/characters/farmer/farmer_walk.png", "frames": 4, "fps": WALK_FPS},
	{"name": "farmer_throw", "path": "res://assets/sprites/characters/farmer/farmer_throw.png", "frames": 3, "fps": FARMER_THROW_FPS},
	{"name": "tomato_fly", "path": "res://assets/sprites/props/tomato_fly.png", "frames": 2, "fps": TOMATO_FPS, "size": PROP_FRAME},
	{"name": "tomato_splat", "path": "res://assets/sprites/props/tomato_splat.png", "frames": 3, "fps": SPLAT_FPS, "size": PROP_FRAME},
]
## Animations shown at once (one row of columns); N shows the next page.
const PAGE_SIZE: int = 4
## [name, background, text color]; palette colors only (DESIGN.md -> Colors).
const BACKGROUNDS: Array[Array] = [
	["night", Color("#2b1d3f"), Color("#f4f1e4")],
	["parchment", Color("#f6e7c1"), Color("#1e1428")],
	["art-sky", Color("#7ec8e3"), Color("#1e1428")],
	["chalkboard", Color("#24402f"), Color("#f4f1e4")],
	["art-grass", Color("#4e9a34"), Color("#1e1428")],
]
## Layout (viewport px), top to bottom: palette strip, animations, type specimen, footer.
const MARGIN: int = 16
const SWATCH: int = 16
const SWATCH_STEP: int = 18
const PALETTE_Y: int = 8
const ANIM_LABEL_Y: int = 48
const ANIM_Y: int = 64
const ANIM_COLUMN: int = 152
const SPECIMEN: Array[Array] = [
	[16, "lI1O0 Zombies teach typing: 0123456789"],
	[24, "lI1O0 Hug a villager!"],
	[32, "lI1O0 Brains!"],
]
const SPECIMEN_Y: int = 176
const SPECIMEN_GAP: int = 8
const SMALL_FONT: int = 8
const FOOTER_Y: int = 344

var _animations: Dictionary[String, SpriteFrames] = {}
var _swatches: Array[Color] = []
var _labels: Array[Label] = []
var _background_index: int = 0
var _pages: Array[Control] = []
var _page_index: int = 0


## One looping animation, one size x size AtlasTexture region per frame (frames side by side in the sheet).
static func build_frames(sheet: Texture2D, frame_count: int, fps: float, anim_name: StringName = &"default",
		frame_px: int = FRAME) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if anim_name != &"default":
		frames.rename_animation(&"default", anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	for i: int in frame_count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_px, 0, frame_px, frame_px)
		frames.add_frame(anim_name, atlas)
	return frames


func _ready() -> void:
	_build_palette_strip()
	_build_animations()
	_build_specimen()
	%Footer.position = Vector2(MARGIN, FOOTER_Y)
	_labels.append(%Footer)
	get_window().size_changed.connect(_refresh)
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


func get_animations() -> Dictionary[String, SpriteFrames]:
	return _animations


func swatch_colors() -> Array[Color]:
	return _swatches


func background_name() -> String:
	return BACKGROUNDS[_background_index][0]


func background_color() -> Color:
	return BACKGROUNDS[_background_index][1]


func page_count() -> int:
	return _pages.size()


func page_index() -> int:
	return _page_index


## The animation names on the shown page.
func page_animations() -> Array[String]:
	var names: Array[String] = []
	for i: int in range(_page_index * PAGE_SIZE, mini((_page_index + 1) * PAGE_SIZE, ANIMATIONS.size())):
		names.append(ANIMATIONS[i]["name"])
	return names


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
	var text_color: Color = BACKGROUNDS[_background_index][2]
	for label: Label in _labels:
		label.add_theme_color_override("font_color", text_color)
	var window: Vector2i = get_window().size
	%Footer.text = "window %dx%d  scale %.2fx  bg %s  page %d/%d   B: background  N: page  Esc: quit" % [
		window.x, window.y, minf(float(window.x) / VIEWPORT.x, float(window.y) / VIEWPORT.y), background_name(),
		_page_index + 1, _pages.size()]


func _build_palette_strip() -> void:
	# Via the imported texture: exports ship the .ctex, not the source PNG (lossless, so exact colors).
	var texture: Texture2D = load(PALETTE_PATH) as Texture2D
	if texture == null:
		push_error("ArtReview: cannot load %s" % PALETTE_PATH)
		return
	var image: Image = texture.get_image()
	for x: int in image.get_width():
		var color: Color = image.get_pixel(x, 0)
		_swatches.append(color)
		var swatch: ColorRect = ColorRect.new()
		swatch.color = color
		swatch.position = Vector2(MARGIN + x * SWATCH_STEP, PALETTE_Y)
		swatch.size = Vector2(SWATCH, SWATCH)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(swatch)
		_add_label(str(x), SMALL_FONT, Vector2(MARGIN + x * SWATCH_STEP, PALETTE_Y + SWATCH + 2))


func _build_animations() -> void:
	for i: int in ANIMATIONS.size():
		if i % PAGE_SIZE == 0:
			var page: Control = Control.new()
			page.mouse_filter = Control.MOUSE_FILTER_IGNORE
			page.visible = _pages.is_empty()
			add_child(page)
			_pages.append(page)
		var spec: Dictionary = ANIMATIONS[i]
		var anim_name: String = spec["name"]
		var frame_px: int = spec.get("size", FRAME)
		var sheet: Texture2D = load(spec["path"]) as Texture2D
		if sheet == null:
			push_error("ArtReview: cannot load %s" % spec["path"])
			continue
		var frames: SpriteFrames = build_frames(sheet, spec["frames"], spec["fps"], anim_name, frame_px)
		_animations[anim_name] = frames
		var page_node: Control = _pages.back()
		var x: int = MARGIN + (i % PAGE_SIZE) * ANIM_COLUMN
		_add_label("%s %d fps" % [anim_name, roundi(spec["fps"])], SMALL_FONT, Vector2(x, ANIM_LABEL_Y), page_node)
		# 1x sits on the 3x sprite's ground line, so the two rows can be compared.
		_add_sprite(page_node, frames, anim_name, Vector2(x, ANIM_Y + frame_px * (DETAIL_SCALE - 1)), 1)
		_add_sprite(page_node, frames, anim_name, Vector2(x + frame_px + 8, ANIM_Y), DETAIL_SCALE)


func _add_sprite(parent: Node, frames: SpriteFrames, anim_name: String, at: Vector2, scale_factor: int) -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2(scale_factor, scale_factor)
	parent.add_child(sprite)
	sprite.play(anim_name)


func _build_specimen() -> void:
	var y: int = SPECIMEN_Y
	for line: Array in SPECIMEN:
		var size: int = line[0]
		_add_label(line[1], size, Vector2(MARGIN, y))
		y += size + SPECIMEN_GAP


func _add_label(text: String, font_size: int, at: Vector2, parent: Node = null) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	(parent if parent != null else self).add_child(label)
	_labels.append(label)
	return label
