class_name BrainPickup
extends Node2D
## A brain lying on the Pitchfork Panic path (Story 8.4, FR72): the cartoon brain from brain_pop.png
## (NFR10), its bottom centre LIFT_PX above the node origin, which the level puts on the ground line. The
## level owns `position`, decides when it is collected and plays the sound; collect() only shows the
## existing BrainPop rise (added to another node, so it keeps rising after the pickup is gone) and frees
## the pickup. No new art.

const BRAIN_POP_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/brain_pop.tscn")
## Look value (UX, not a GDD number): how far the brain sits above the ground line, so it reads as lying on
## the path, not sunk into it.
const LIFT_PX: float = 2.0

var _collected: bool = false


func _ready() -> void:
	# NFR16: a missing sprite never stops a run.
	if %Sprite.sprite_frames == null:
		Log.warn(&"level", "brain pickup has no sprite frames")


## Pops the brain up from where it lies and frees the pickup. The pop goes into `pop_parent` (default: the
## pickup's parent), so the level can draw it in front of the zombie while the pickup stays behind. A
## second call does nothing.
func collect(pop_parent: Node2D = null) -> void:
	if _collected:
		return
	_collected = true
	var target: Node2D = pop_parent if pop_parent != null else get_parent() as Node2D
	if target != null:
		var pop: Node2D = BRAIN_POP_SCENE.instantiate() as Node2D
		pop.position = target.to_local(global_position) + Vector2(0.0, -LIFT_PX)
		target.add_child(pop)
	queue_free()
