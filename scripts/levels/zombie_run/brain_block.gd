class_name BrainBlock
extends ZombieRunTarget
## A brain block on the Zombie Run path (Story 3.2, FR33): a pink block floating above the ground line,
## with the letter tag above it. Typing its letter pays brains: resolve() returns the configured
## brains_per_block, switches to the grey used look, bonks the block and pops a brain out. The bonk and
## the pop are fire-and-forget node-bound tweens; the level never waits on them.
## The node origin is the feet centre on the ground line like every target; %Lift raises the block, tag
## and arrow by the float height, the base bob moves %Visual, and the level owns `position`.
## Placeholder look until Story 3.6.

const BRAIN_POP_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/brain_pop.tscn")

## Look values (UX, not GDD numbers). The block is 16 x 16 with its bottom edge at %Lift's y 0.
const BLOCK_SIZE_PX: float = 16.0
const BONK_PX: float = 3.0
const BONK_TIME_S: float = 0.25
## Used look: stone-light, no pink, so a bonked block reads as "done" (docs/art-style-sheet.md palette).
const USED_FILL: Color = Color("#BDB6C4")

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


func is_used() -> bool:
	return is_resolved()


## The bonk tween (null before the bonk). For tests.
func get_bonk_tween() -> Tween:
	return _bonk_tween


func _on_resolved() -> int:
	_apply_used_look()
	_bonk()
	var pop: Node2D = BRAIN_POP_SCENE.instantiate() as Node2D
	pop.position = Vector2(0.0, -BLOCK_SIZE_PX)
	%Lift.add_child(pop)
	return _brains


func _apply_used_look() -> void:
	var base: StyleBoxFlat = %Block.get_theme_stylebox(&"panel") as StyleBoxFlat
	if base != null:
		var style: StyleBoxFlat = base.duplicate() as StyleBoxFlat
		style.bg_color = USED_FILL
		%Block.add_theme_stylebox_override(&"panel", style)
	%Band.hide()


## Nudges %Lift up and back. Never touches %Visual (the bob) or `position` (the level).
func _bonk() -> void:
	var rest_y: float = -_float_px
	_bonk_tween = create_tween()
	_bonk_tween.tween_property(%Lift, "position:y", rest_y - BONK_PX, BONK_TIME_S * 0.5)
	_bonk_tween.tween_property(%Lift, "position:y", rest_y, BONK_TIME_S * 0.5)
