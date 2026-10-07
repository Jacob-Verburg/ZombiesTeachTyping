class_name HordeMarcher
extends RefCounted
## One Horde Rush zombie copy's logical state (Story 6.3). HordeField owns and advances it; the level
## draws a sprite from progress() and never reads the sprite back. No nodes, no pixels: only seconds.
## Story 6.4 adds the stopped state (hits_left reaching 0); Story 6.5 reads size_class.arrival_brains.

## Unique per run, in spawn order from 0.
var id: int = 0
## The completed word that spawned it.
var word: String = ""
## 0 = top lane.
var lane: int = 0
var size_class: HordeSizeClass
## Seconds marched so far.
var elapsed_s: float = 0.0
## Hits still needed to stop it (size_class.hits_to_stop at spawn; Story 6.4 decrements).
var hits_left: int = 0


func _init(p_id: int, p_word: String, p_lane: int, p_size_class: HordeSizeClass) -> void:
	id = p_id
	word = p_word
	lane = p_lane
	size_class = p_size_class
	hits_left = p_size_class.hits_to_stop


## How far across the field it is, 0 (left edge) .. 1 (at the house).
func progress() -> float:
	return clampf(elapsed_s / size_class.crossing_time_s, 0.0, 1.0)


## True once it has marched its class's crossing time (within HordeField.ARRIVE_EPSILON_S).
func has_arrived() -> bool:
	return elapsed_s >= size_class.crossing_time_s - HordeField.ARRIVE_EPSILON_S
