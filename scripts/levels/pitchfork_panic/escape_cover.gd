class_name EscapeCover
extends Node2D
## The cover the zombie dives into when it escapes in Pitchfork Panic (a bush, a haystack, a hollow log...),
## one per setting (Story 8.5; sprite in 8.6; renamed from the escape bush and made per setting in Story 10.4): a
## 48x48 sheet (frame 0 still, frames 1-2 rustled with bits popping off), its origin at the bottom centre on
## the ground (the sheet stands on row 46, so the sprite sits at (-24, -47)). rustle() steps frames 1, 2, 1,
## 2 ... across its time with a node-bound tween and always ends on frame 0. Pixel art is never scaled:
## frames only. The built-in picture is the Moonlit Village bush (props/escape_bush.png).
## use_sheet() swaps in the setting's own picture (the level hands it the ChaseBackdrop's escape_cover_sheet);
## only the frames change, never the contract or the rustle.
## The sprite child is built in code (tests create this node with new()); a missing sheet logs one warning
## and the dive goes on without the picture (NFR16).

const DEFAULT_SHEET_PATH: String = "res://assets/sprites/props/escape_bush.png"
const ANIM: StringName = &"rustle"
const FRAME_COUNT: int = 3
const FRAME_PX: int = 48
## Tween-stepped; this is only the SpriteFrames speed (the art review shows it at 8 fps).
const FPS: float = 8.0
const SPRITE_OFFSET: Vector2 = Vector2(-24.0, -47.0)
## Rustle frames per rustle() (look value): 1, 2, 1, 2 ... then back to the still frame 0.
const RUSTLE_STEPS: int = 4

var _tween: Tween
var _sprite: AnimatedSprite2D
## The sheet in use (null if even the built-in bush failed to load).
var _sheet: Texture2D = null


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = SPRITE_OFFSET
	_sprite.sprite_frames = SheetFrames.build(DEFAULT_SHEET_PATH, FRAME_COUNT, FRAME_PX, FPS, ANIM, false, "escape cover")
	if _sprite.sprite_frames != null:
		_sprite.animation = ANIM
		_sheet = load(DEFAULT_SHEET_PATH) as Texture2D
	add_child(_sprite)


## Shows `sheet` (the setting's cover, same contract as the bush) from now on, on its still frame, and returns
## true. Null (or a call before _ready) changes nothing and returns false; a sheet too small for 3 frames of 48 px warns once (via
## SheetFrames), keeps the current picture and returns false. A running rustle is stopped first.
func use_sheet(sheet: Texture2D) -> bool:
	if sheet == null or _sprite == null:
		return false
	var frames: SpriteFrames = SheetFrames.from_texture(sheet, FRAME_COUNT, FRAME_PX, FPS, ANIM, false, "escape cover")
	if frames == null:
		return false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_sprite.sprite_frames = frames
	_sprite.animation = ANIM
	_sprite.frame = 0
	_sheet = sheet
	return true


## The sheet in use: the built-in bush after _ready, the setting's after use_sheet(); null if none loaded.
func get_sheet() -> Texture2D:
	return _sheet


## Rustles the cover for duration_s; it always ends on the still frame. A second call restarts it.
func rustle(duration_s: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_set_t(0.0)
	_tween = create_tween()
	_tween.tween_method(_set_t, 0.0, 1.0, maxf(0.0, duration_s))
	_tween.tween_callback(_settle)


## The running rustle tween (tests step it with custom_step); null before rustle().
func get_tween() -> Tween:
	return _tween


## The frame showing (0 without a sprite). For tests.
func get_frame() -> int:
	return _sprite.frame if _sprite != null else 0


## `t` runs 0..1 over the rustle: rustle frames 1 and 2 alternate RUSTLE_STEPS times.
func _set_t(t: float) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var beat: int = mini(int(t * RUSTLE_STEPS), RUSTLE_STEPS - 1)
	_sprite.frame = 1 + beat % 2


func _settle() -> void:
	if _sprite != null:
		_sprite.frame = 0
