class_name DustCloud
extends Node2D
## The cartoon dust cloud over the scuffle in Pitchfork Panic's caught outro (Story 8.5; sprite in 8.6): a
## 48x48 sheet of chalk puffs, ink action lines and sparks (props/dust_cloud.png, 4 frames), its origin at
## the bottom centre on the ground (the sheet stands on row 46, so the sprite sits at (-24, -47)). play()
## steps the frames at FPS with a node-bound tween (so tests can custom_step it), jitters the cloud by whole
## px and hides it at the end. Pixel art is never scaled or rotated: frames and whole-px moves only. The
## sprite child is built in code (tests create this node with new()); a missing sheet logs one warning and
## the outro goes on without the picture (NFR16).

const SHEET_PATH: String = "res://assets/sprites/props/dust_cloud.png"
const ANIM: StringName = &"dust_cloud"
const FRAME_COUNT: int = 4
const FRAME_PX: int = 48
## Frames per second while it plays (style sheet: tween-stepped at 10 fps).
const FPS: float = 10.0
## The sheet's ground row 46 sits on the node's origin. Layout value.
const SPRITE_OFFSET: Vector2 = Vector2(-24.0, -47.0)
## Side-to-side jitter in whole px, and how often it flips (look values).
const JITTER_PX: float = 2.0
const JITTERS_PER_S: float = 4.0

var _tween: Tween
var _base_x: float = 0.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = SPRITE_OFFSET
	_sprite.sprite_frames = SheetFrames.build(SHEET_PATH, FRAME_COUNT, FRAME_PX, FPS, ANIM, true, "dust cloud")
	if _sprite.sprite_frames != null:
		_sprite.animation = ANIM
	add_child(_sprite)


## Shows the cloud and steps its frames for duration_s, then hides it. A second call restarts it.
func play(duration_s: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if _tween != null:
		position.x = _base_x
	_base_x = position.x
	visible = true
	_set_t(0.0)
	var d: float = maxf(0.0, duration_s)
	_tween = create_tween()
	_tween.tween_method(_set_t, 0.0, d, d)
	_tween.tween_callback(_finish)


## The running frame tween (tests step it with custom_step); null before play().
func get_tween() -> Tween:
	return _tween


## The frame showing (0 without a sprite). For tests.
func get_frame() -> int:
	return _sprite.frame if _sprite != null else 0


## `t` is the elapsed play time in seconds: the frame at FPS and the whole-px jitter (it starts on its base x,
## then right, left, right ...).
func _set_t(t: float) -> void:
	var beat: int = int(t * JITTERS_PER_S)
	var dx: float = 0.0 if beat == 0 else (JITTER_PX if beat % 2 == 1 else -JITTER_PX)
	position.x = _base_x + dx
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.frame = int(t * FPS) % FRAME_COUNT


func _finish() -> void:
	position.x = _base_x
	visible = false
	if _sprite != null:
		_sprite.frame = 0
