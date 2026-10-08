class_name HordeField
extends RefCounted
## Horde Rush's logical field (Story 6.3): every marching copy as a HordeMarcher, advanced in seconds.
## Logic leads, visuals chase: the level spawns here first and derives each sprite's x from progress();
## arrivals are decided here, never from sprite positions. Pure (no nodes, no global RNG), so Story 6.4's
## defender and Story 6.7's headless WPM simulation run on it unchanged.
##
## Hits (Story 6.4): HordeDefender acts on the field only through hit() and front_most_in_lane(). A copy
## whose last hit lands is removed from the march (stopped), so every spawned copy is exactly one of
## marching, arrived or stopped.
##
## Lanes: exactly one lane_rng.randi_range() per spawn and nothing else draws from lane_rng, so a seed
## always replays the same lanes in the same order.

var _config: HordeRushConfig
var _lane_rng: RandomNumberGenerator
## Marching copies, spawn order.
var _marching: Array[HordeMarcher] = []
var _spawned: int = 0
var _arrived: int = 0
var _stopped: int = 0


func _init(config: HordeRushConfig, lane_rng: RandomNumberGenerator) -> void:
	_config = config
	_lane_rng = lane_rng


## Adds a copy for a completed word: its class from the word's length, its lane from the lane RNG.
## Null (and nothing drawn) when the config has no class for that length or no lane.
func spawn(word: String) -> HordeMarcher:
	if _config.lane_count < 1:
		Log.error(&"level", "horde field has no lanes")
		return null
	var size_class: HordeSizeClass = _config.size_class_for(word.length())
	if size_class == null:
		Log.error(&"level", "horde field has no size class for a %d-letter word" % word.length())
		return null
	var lane: int = _lane_rng.randi_range(0, _config.lane_count - 1)
	var marcher: HordeMarcher = HordeMarcher.new(_spawned, word, lane, size_class)
	_spawned += 1
	_marching.append(marcher)
	return marcher


## Marches every copy `delta` seconds. Returns the copies that arrived (removed from the field), in
## spawn order. A zero, negative or non-finite delta changes nothing.
func advance(delta: float) -> Array[HordeMarcher]:
	var arrived: Array[HordeMarcher] = []
	if not (delta > 0.0 and is_finite(delta)):
		return arrived
	var still: Array[HordeMarcher] = []
	for marcher: HordeMarcher in _marching:
		marcher.elapsed_s += delta
		if marcher.has_arrived():
			arrived.append(marcher)
		else:
			still.append(marcher)
	_marching = still
	_arrived += arrived.size()
	return arrived


## One hit on a marching copy. On its last hit it leaves the march (stopped) and this returns true.
## A copy that is not marching here (arrived, stopped, another field's, null) is ignored: false.
func hit(marcher: HordeMarcher) -> bool:
	var index: int = _marching.find(marcher)
	if marcher == null or index < 0:
		return false
	marcher.hits_left -= 1
	if not marcher.is_stopped():
		return false
	_marching.remove_at(index)
	_stopped += 1
	return true


## The marching copy in `lane` with the highest progress() that is at least `at_or_past`; ties go to the
## lower id; null when there is none. The defender aims with it, and a projectile's contact is
## front_most_in_lane(lane, projectile position).
func front_most_in_lane(lane: int, at_or_past: float = -INF) -> HordeMarcher:
	var best: HordeMarcher = null
	var best_progress: float = -INF
	for marcher: HordeMarcher in _marching:
		if marcher.lane != lane:
			continue
		var progress: float = marcher.progress()
		if progress < at_or_past:
			continue
		# Spawn order is id order, so a strict > keeps the lower id on a tie.
		if best == null or progress > best_progress:
			best = marcher
			best_progress = progress
	return best


## The marching copies in spawn order (a copy of the list).
func get_marching() -> Array[HordeMarcher]:
	return _marching.duplicate()


func get_spawned_count() -> int:
	return _spawned


func get_arrived_count() -> int:
	return _arrived


func get_stopped_count() -> int:
	return _stopped
