class_name HordeField
extends RefCounted
## Horde Rush's logical field (Story 6.3): every marching copy as a HordeMarcher, advanced in seconds.
## Logic leads, visuals chase: the level spawns here first and derives each sprite's x from progress();
## arrivals are decided here, never from sprite positions. Pure (no nodes, no global RNG), so Story 6.4's
## defender and Story 6.7's headless WPM simulation run on it unchanged.
##
## Lanes: exactly one lane_rng.randi_range() per spawn and nothing else draws from lane_rng, so a seed
## always replays the same lanes in the same order.

var _config: HordeRushConfig
var _lane_rng: RandomNumberGenerator
## Marching copies, spawn order.
var _marching: Array[HordeMarcher] = []
var _spawned: int = 0
var _arrived: int = 0


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


## The marching copies in spawn order (a copy of the list).
func get_marching() -> Array[HordeMarcher]:
	return _marching.duplicate()


func get_spawned_count() -> int:
	return _spawned


func get_arrived_count() -> int:
	return _arrived
