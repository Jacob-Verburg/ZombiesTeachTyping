class_name PickupTrail
extends RefCounted
## Where Pitchfork Panic's brain pickups sit on the path (Story 8.4, FR72), in logical steps. Pure logic: no
## nodes, no clock, like ChaseModel. The first pickup is randi_range(min, max) steps after the start (step
## 0), each next one randi_range(min, max) steps after the previous one (inclusive). The trail owns its RNG
## (a child of the run RNG) and draws exactly one value per pickup placed, so positions depend only on the
## seed, never on time, frame rate or how far ahead the level asks.
##
## A null RNG or bad numbers (min < 1, max < min) give a trail that places nothing; the level refuses an
## invalid config before it gets here.

var _rng: RandomNumberGenerator
var _min_steps: int
var _max_steps: int
## The furthest position placed so far (0 = the start, nothing placed yet).
var _last: int = 0
## Placed, not yet collected, in order.
var _queue: Array[int] = []


func _init(rng: RandomNumberGenerator, min_steps: int, max_steps: int) -> void:
	_rng = rng
	_min_steps = min_steps
	_max_steps = max_steps


## Places pickups while the last placed position is below `step`, one draw each, and returns the newly
## placed positions in order (empty when nothing new was needed).
func fill_to(step: int) -> Array[int]:
	var placed: Array[int] = []
	if not _usable():
		return placed
	while _last < step:
		_last += _rng.randi_range(_min_steps, _max_steps)
		_queue.append(_last)
		placed.append(_last)
	return placed


## Takes every uncollected pickup at or behind `zombie_steps` and returns how many.
func collect(zombie_steps: int) -> int:
	var count: int = 0
	while not _queue.is_empty() and _queue[0] <= zombie_steps:
		_queue.pop_front()
		count += 1
	return count


## A copy of the placed, uncollected positions, in order.
func upcoming() -> Array[int]:
	return _queue.duplicate()


func _usable() -> bool:
	return _rng != null and _min_steps >= 1 and _max_steps >= _min_steps
