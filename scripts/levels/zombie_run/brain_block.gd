class_name BrainBlock
extends ZombieRunTarget
## A brain block on the Zombie Run path (Story 3.2, FR33): a pink block floating above the ground line,
## with the letter tag above it. Typing its letter pays brains: resolve() returns the configured
## brains_per_block, plays the bonk frames (which end on the grey used block and hold it), nudges the
## block and pops a brain out. The nudge and the pop are fire-and-forget node-bound tweens; the level
## never waits on them.
## The node origin is the feet centre on the ground line like every target; %Lift raises the block, tag
## and arrow by the float height, the base bob moves %Visual, and the level owns `position`.
## Story 3.6: %Sprite plays brain_block_idle.png (idle) and brain_block_bonk.png (bonk, once).

const BRAIN_POP_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/brain_pop.tscn")
const ANIM_IDLE: StringName = &"idle"
const ANIM_BONK: StringName = &"bonk"

## Look values (UX, not GDD numbers). The block is 16 x 16 with its bottom edge at %Lift's y 0.
const BLOCK_SIZE_PX: float = 16.0
const BONK_PX: float = 3.0
const BONK_TIME_S: float = 0.25

var _float_px: float = 0.0
var _brains: int = 0
var _bonk_tween: Tween


## Called after setup() and before add_child: how high the block floats and the brains it pays.
func configure(float_px: float, brains: int) -> void:
	_float_px = float_px
	_brains = brains


func _ready() -> void:
	super._ready()
	%Lift.position.y = -_float_px
	# NFR16: a missing sprite never stops a run.
	if %Sprite.sprite_frames == null:
		Log.warn(&"level", "brain block has no sprite frames")


func is_used() -> bool:
	return is_resolved()


## The bonk tween (null before the bonk). For tests.
func get_bonk_tween() -> Tween:
	return _bonk_tween


func _on_resolved() -> int:
	_play_bonk()
	_bonk()
	var pop: Node2D = BRAIN_POP_SCENE.instantiate() as Node2D
	pop.position = Vector2(0.0, -BLOCK_SIZE_PX)
	%Lift.add_child(pop)
	return _brains


## The bonk frames play once and hold the last one: the used block (stone, no pink).
func _play_bonk() -> void:
	var sprite: AnimatedSprite2D = %Sprite
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(ANIM_BONK):
		return
	sprite.play(ANIM_BONK)


## Nudges %Lift up and back. Never touches %Visual (the bob) or `position` (the level).
func _bonk() -> void:
	var rest_y: float = -_float_px
	_bonk_tween = create_tween()
	_bonk_tween.tween_property(%Lift, "position:y", rest_y - BONK_PX, BONK_TIME_S * 0.5)
	_bonk_tween.tween_property(%Lift, "position:y", rest_y, BONK_TIME_S * 0.5)
