class_name HordeTomatoSplat
extends Node2D
## A tomato splat (Story 6.6): where a tomato lands on a copy, a self-freeing one-shot under the level's
## %Effects, spawned at the logical landing point. 3 frames (squish, burst, drips) in pumpkin with seeds
## and a leaf bit: clearly fruit, never blood (stamp red is reserved, DESIGN.md D16). A node-bound tween
## steps the frames (the poof pattern), so it pauses with the tree and tests can custom_step it; the sprite
## never plays on its own. It never gates input or logic.

## Look values (art spec "splat 3f at 12 fps", not GDD numbers). FRAMES matches the sheet.
const FRAMES: int = 3
const FPS: float = 12.0

var _frame: int = 0
var _tween: Tween

@onready var _sprite: AnimatedSprite2D = %Sprite


func _ready() -> void:
	# NFR16: a missing sprite never stops a run (the tween still runs and frees the node).
	if _sprite.sprite_frames == null:
		Log.warn(&"level", "tomato splat has no sprite frames")
	_sprite.frame = 0
	_tween = create_tween()
	_tween.tween_method(_set_frame, 0.0, float(FRAMES), FRAMES / FPS)
	_tween.tween_callback(queue_free)


func get_frame() -> int:
	return _frame


## The frame tween (for tests).
func get_tween() -> Tween:
	return _tween


func _set_frame(t: float) -> void:
	var frame: int = mini(floori(t), FRAMES - 1)
	if frame != _frame:
		_frame = frame
		_sprite.frame = frame
