class_name HordeArrivalPop
extends Node2D
## The "+N" brain pop over the house front when a Horde Rush copy gets inside (Story 6.5, FR57): the
## shared cartoon brain prop (brain_pop.png, never anatomical, NFR10) with the brains it paid in ink at
## 16 px (NFR7) to its left (the house is on the right). It rises and then frees itself; nothing waits
## on it. The node origin is the brain's bottom centre. A placeholder: Story 6.6 may replace it.

const ANIM_POP: StringName = &"brain_pop"
## Look values (UX, not GDD numbers).
const RISE_PX: float = 16.0
const RISE_TIME_S: float = 0.6

var _brains: int = 0
var _tween: Tween

@onready var _amount: Label = %Amount


## Call before add_child: the label will show "+`brains`".
func setup(brains: int) -> void:
	_brains = brains


func _ready() -> void:
	_amount.text = "+%d" % _brains
	_tween = create_tween()
	_tween.tween_property(self, "position:y", position.y - RISE_PX, RISE_TIME_S)
	_tween.tween_callback(queue_free)


## The rise tween (for tests).
func get_tween() -> Tween:
	return _tween


## The "+N" text (for tests).
func get_amount_text() -> String:
	return _amount.text if _amount != null else ""
