class_name Poof
extends Node2D
## The dust cloud a hugged villager turns into (Story 3.3, FR34): 4 frames (a small puff, a big puff over
## the body, the big puff breaking up, a few tiny puffs), a white chalk cloud with a stone-light shade and
## an ink outline, never wider than the 24 px tag. A node-bound tween steps the frames, so it pauses with
## the tree and tests can custom_step it (the sprite never plays on its own). When the last frame ends it
## emits finished and frees itself; the villager shows its party-hat zombie on finished (an effect chain,
## never input gating).
## Story 3.6: %Sprite shows villager_poof.png; the origin is the feet centre (Body at (-16, -31) like every
## character), and the cloud rests on the ground line (frame 0 sits low; the big puffs grow and break up from there).

signal finished

## Look values (art spec "poof 4f", not GDD numbers). FRAMES matches the sheet.
const FRAMES: int = 4
const FPS: float = 12.0

var _frame: int = 0
var _tween: Tween

@onready var _sprite: AnimatedSprite2D = %Sprite


func _ready() -> void:
	# NFR16: a missing sprite never stops a run (the frames and finished still run).
	if _sprite.sprite_frames == null:
		Log.warn(&"level", "poof has no sprite frames")
	_sprite.frame = 0
	_tween = create_tween()
	_tween.tween_method(_set_frame, 0.0, float(FRAMES), FRAMES / FPS)
	_tween.tween_callback(_finish)


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


func _finish() -> void:
	finished.emit()
	queue_free()
