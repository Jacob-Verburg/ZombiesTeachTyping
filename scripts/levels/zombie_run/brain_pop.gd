class_name BrainPop
extends Node2D
## The brain that pops out of a bonked brain block (Story 3.2): a code-drawn cartoon brain, the same pink
## and shade as the HUD counter icon with a 1 px ink outline (never anatomical, NFR10). It rises and then
## frees itself; nothing waits on it. Placeholder until Story 3.6. The origin is the brain's bottom centre.

## Look values (UX, not GDD numbers).
const RISE_PX: float = 16.0
const RISE_TIME_S: float = 0.4
const PINK: Color = Color("#F29AB8")
const SHADE: Color = Color("#C9607F")
const INK: Color = Color("#1E1428")

var _tween: Tween


func _ready() -> void:
	_tween = create_tween()
	_tween.tween_property(self, "position:y", position.y - RISE_PX, RISE_TIME_S)
	_tween.tween_callback(queue_free)


## The rise tween (for tests).
func get_tween() -> Tween:
	return _tween


## About 10 x 8 px: an ink outline with clipped corners, pink fill, a shade line down the middle and
## two little folds.
func _draw() -> void:
	draw_rect(Rect2(-4, -8, 8, 1), INK)
	draw_rect(Rect2(-4, -1, 8, 1), INK)
	draw_rect(Rect2(-5, -7, 1, 6), INK)
	draw_rect(Rect2(4, -7, 1, 6), INK)
	draw_rect(Rect2(-4, -7, 8, 6), PINK)
	draw_rect(Rect2(0, -7, 1, 5), SHADE)
	draw_rect(Rect2(-3, -5, 2, 1), SHADE)
	draw_rect(Rect2(2, -4, 2, 1), SHADE)
