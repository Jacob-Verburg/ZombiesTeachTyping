class_name HordeProjectile
extends RefCounted
## One thrown tomato's logical state (Story 6.4). HordeDefender owns and moves it; the level draws a
## placeholder from position and lane and never reads the sprite back. No nodes, no pixels: field units.

## Unique per run, in throw order from 0.
var id: int = 0
## The lane it was thrown into; it never leaves it.
var lane: int = 0
## Field units like HordeMarcher.progress(): 1.0 = the house line where the defender throws, 0.0 = the
## left edge. It only moves left.
var position: float = 1.0
## The front-most copy when it was thrown (debug and tests only: contact decides what it hits).
var aimed_at: HordeMarcher
## The copy it landed on; null for a miss (or while it is still flying).
var hit_marcher: HordeMarcher
## True when that hit was the copy's last one (it stopped).
var stopped_marcher: bool = false


func _init(p_id: int, p_lane: int, p_aimed_at: HordeMarcher) -> void:
	id = p_id
	lane = p_lane
	aimed_at = p_aimed_at
