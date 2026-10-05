class_name BrainPop
extends Node2D
## The brain that pops out of a bonked brain block (Story 3.2): the cartoon brain (art-brain-pink and
## art-brain-shade with a 1 px ink outline, never anatomical, NFR10). It rises and then frees itself;
## nothing waits on it. Story 3.6: %Sprite plays brain_pop.png (2 frames, a 1 px stretch bob), placed so
## the node origin stays the brain's bottom centre.

const ANIM_POP: StringName = &"brain_pop"
## Look values (UX, not GDD numbers).
const RISE_PX: float = 16.0
const RISE_TIME_S: float = 0.4

var _tween: Tween


func _ready() -> void:
	_tween = create_tween()
	_tween.tween_property(self, "position:y", position.y - RISE_PX, RISE_TIME_S)
	_tween.tween_callback(queue_free)


## The rise tween (for tests).
func get_tween() -> Tween:
	return _tween
