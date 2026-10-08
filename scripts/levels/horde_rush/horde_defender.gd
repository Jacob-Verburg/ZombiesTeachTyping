class_name HordeDefender
extends RefCounted
## Horde Rush's defender and its projectiles (Story 6.4, FR56), as pure logic: no nodes, no pixels, no
## RNG at all (seeds change only the words and the lanes). It paces the lanes in front of the house,
## throws down the lane it is level with (roundi(position())) when that lane has a marching copy and its
## cooldown allows, aimed at the front-most copy; a projectile flies left at one field per
## projectile_cross_time_s and hits whichever copy it reaches first (contact, not aim, decides). No
## overkill avoidance: a spare projectile flies on to the next copy or misses at the left edge.
##
## Step order (the level and Story 6.7's headless simulation both follow it, nothing else changes field
## state): march first (field.advance(dt), arrivals removed), then defender.advance(dt, field), which
## (a) moves and lands the projectiles in throw order, (b) paces and ticks the cooldown, (c) throws at
## most once. A copy that reaches the house in the same step a projectile would reach it is an arrival.

## Float sums of 60 Hz deltas land a hair over the cooldown; this lets 48 steps of 1/60 meet 0.8 s
## (seconds, like HordeMarcher.ARRIVE_EPSILON_S, not a GDD number).
const TIME_EPSILON_S: float = 1e-4


## What one advance() did, for the level's views.
class Step extends RefCounted:
	## Projectiles thrown this step (at most one), at position 1.0.
	var thrown: Array[HordeProjectile] = []
	## Projectiles that landed this step, hits and misses, in throw order.
	var landed: Array[HordeProjectile] = []


var _config: HordeRushConfig
## Lanes paced since the start; position() folds it with pingpong(), so there is no direction to drift.
var _travel: float = 0.0
## Ready at run start.
var _cooldown_left_s: float = 0.0
## In throw order.
var _flying: Array[HordeProjectile] = []
var _thrown: int = 0
var _hits: int = 0
var _misses: int = 0


func _init(config: HordeRushConfig) -> void:
	_config = config


## 0 = the top lane, lane_count - 1 = the bottom one; continuous between them. One lane stays at 0.
func position() -> float:
	return pingpong(_travel, float(_config.lane_count - 1))


## The lane it is level with.
func current_lane() -> int:
	return roundi(position())


## True while it paces toward the bottom lane (for the view's facing).
func is_heading_down() -> bool:
	var length: float = float(_config.lane_count - 1)
	if length <= 0.0:
		return true
	return fmod(_travel, length * 2.0) < length


## One logic step of `delta` seconds against `field` (already marched this step). A zero, negative or
## non-finite delta returns an empty Step and changes nothing.
func advance(delta: float, field: HordeField) -> Step:
	var step: Step = Step.new()
	if not (delta > 0.0 and is_finite(delta)):
		return step
	var still: Array[HordeProjectile] = []
	for projectile: HordeProjectile in _flying:
		projectile.position -= delta / _config.projectile_cross_time_s
		var target: HordeMarcher = field.front_most_in_lane(projectile.lane, projectile.position)
		if target != null:
			projectile.hit_marcher = target
			projectile.stopped_marcher = field.hit(target)
			_hits += 1
			step.landed.append(projectile)
		elif projectile.position <= 0.0:
			_misses += 1
			step.landed.append(projectile)
		else:
			still.append(projectile)
	_flying = still
	_cooldown_left_s -= delta
	_travel += delta / _config.defender_lane_time_s
	if _cooldown_left_s <= TIME_EPSILON_S:
		var lane: int = current_lane()
		var aim: HordeMarcher = field.front_most_in_lane(lane)
		if aim != null:
			var projectile: HordeProjectile = HordeProjectile.new(_thrown, lane, aim)
			_thrown += 1
			_flying.append(projectile)
			step.thrown.append(projectile)
			_cooldown_left_s = _config.defender_throw_cooldown_s
	return step


## The projectiles in the air, in throw order (a copy of the list).
func get_flying() -> Array[HordeProjectile]:
	return _flying.duplicate()


func get_thrown_count() -> int:
	return _thrown


func get_hit_count() -> int:
	return _hits


func get_miss_count() -> int:
	return _misses
