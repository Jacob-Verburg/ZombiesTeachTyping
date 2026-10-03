class_name ArtReview
extends Control
## Art review scene (Story 1.9, the art-style gate). Dev/Smuck only (Boundary 7): never routed to,
## never instanced by the Router, no menu button, no autoload. Run it directly:
##   "/c/Program Files/Godot/Godot.exe" --path . res://scenes/debug/art_review.tscn
## (or the Godot MCP run_project with that scene). Shows, at 640x360 with the project's stretch and
## Nearest filter: the 32-color palette strip, each prototype animation at 1x and 3x, a type specimen
## in the project font at 16/24/32 px, and a footer with the window scale and background.
## B cycles the plain background (palette colors only), Esc quits. F3/F5/F8/F9 are left alone (the
## debug overlay, added by the Router in debug runs, owns them).

const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const FRAME: int = 32
const VIEWPORT: Vector2i = Vector2i(640, 360)
const DETAIL_SCALE: int = 3
## Style sheet: idle/wave at the 8 fps floor, walk at 10 fps (suits the 24 px/s amble).
const IDLE_FPS: float = 8.0
const WALK_FPS: float = 10.0
const WAVE_FPS: float = 8.0
const ANIMATIONS: Array[Dictionary] = [
	{"name": "idle", "path": "res://assets/sprites/characters/zombie/zombie_idle.png", "frames": 2, "fps": IDLE_FPS},
	{"name": "walk", "path": "res://assets/sprites/characters/zombie/zombie_walk.png", "frames": 4, "fps": WALK_FPS},
	{"name": "wave", "path": "res://assets/sprites/characters/villager/villager_wave.png", "frames": 2, "fps": WAVE_FPS},
]
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


## One looping animation, one 32x32 AtlasTexture region per frame (frames side by side in the sheet).
static func build_frames(sheet: Texture2D, frame_count: int, fps: float, anim_name: StringName = &"default") -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	if anim_name != &"default":
		frames.rename_animation(&"default", anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, true)
	for i: int in frame_count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME, 0, FRAME, FRAME)
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


func _cycle_background() -> void:
	_background_index = (_background_index + 1) % BACKGROUNDS.size()
	_refresh()


func _refresh() -> void:
	%Background.color = background_color()
	var text_color: Color = BACKGROUNDS[_background_index][2]
	for label: Label in _labels:
		label.add_theme_color_override("font_color", text_color)
	var window: Vector2i = get_window().size
	%Footer.text = "window %dx%d  scale %.2fx  bg %s   B: background  Esc: quit" % [
		window.x, window.y, minf(float(window.x) / VIEWPORT.x, float(window.y) / VIEWPORT.y), background_name()]


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
		var spec: Dictionary = ANIMATIONS[i]
		var anim_name: String = spec["name"]
		var sheet: Texture2D = load(spec["path"]) as Texture2D
		if sheet == null:
			push_error("ArtReview: cannot load %s" % spec["path"])
			continue
		var frames: SpriteFrames = build_frames(sheet, spec["frames"], spec["fps"], anim_name)
		_animations[anim_name] = frames
		var x: int = MARGIN + i * ANIM_COLUMN
		_add_label("%s %d fps" % [anim_name, roundi(spec["fps"])], SMALL_FONT, Vector2(x, ANIM_LABEL_Y))
		# 1x sits on the 3x sprite's ground line, so the two rows can be compared.
		_add_sprite(frames, anim_name, Vector2(x, ANIM_Y + FRAME * (DETAIL_SCALE - 1)), 1)
		_add_sprite(frames, anim_name, Vector2(x + FRAME + 8, ANIM_Y), DETAIL_SCALE)


func _add_sprite(frames: SpriteFrames, anim_name: String, at: Vector2, scale_factor: int) -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.position = at
	sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)
	sprite.play(anim_name)


func _build_specimen() -> void:
	var y: int = SPECIMEN_Y
	for line: Array in SPECIMEN:
		var size: int = line[0]
		_add_label(line[1], size, Vector2(MARGIN, y))
		y += size + SPECIMEN_GAP


func _add_label(text: String, font_size: int, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	_labels.append(label)
	return label
