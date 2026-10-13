class_name EscapeBush
extends Node2D
## The bush the zombie dives into when it escapes in Pitchfork Panic (Story 8.5; sprite in 8.6): a 48x48
## sheet (props/escape_bush.png: frame 0 still, frames 1-2 rustled with leaves popping off), its origin at
## the bottom centre on the ground (the sheet stands on row 46, so the sprite sits at (-24, -47)). rustle()
## steps frames 1, 2, 1, 2 ... across its time with a node-bound tween and always ends on frame 0. Pixel art
## is never scaled: frames only. One bush for every setting for now (hedge and gate variants: Epic 10.4).
## The sprite child is built in code (tests create this node with new()); a missing sheet logs one warning
## and the dive goes on without the picture (NFR16).

const SHEET_PATH: String = "res://assets/sprites/props/escape_bush.png"
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


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.position = SPRITE_OFFSET
	_sprite.sprite_frames = SheetFrames.build(SHEET_PATH, FRAME_COUNT, FRAME_PX, FPS, ANIM, false, "escape bush")
	if _sprite.sprite_frames != null:
		_sprite.animation = ANIM
	add_child(_sprite)


## Rustles the bush for duration_s; it always ends on the still frame. A second call restarts it.
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
