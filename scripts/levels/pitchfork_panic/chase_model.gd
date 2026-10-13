class_name ChaseModel
extends RefCounted
## Pitchfork Panic's chase, as pure logic (Story 8.3, FR70): no nodes, no RNG, no clock. The zombie's
## logical position is zombie_steps (one correct key = one step); the mob's is mob_steps, which advance()
## moves by run time. gap() = zombie_steps - mob_steps, caught() when it reaches 0. The level reads only
## these numbers, never a sprite position (ADR-1, logic leads, visuals chase).
##
## The mob's speed is mob_wpm_eq(t) WPM-eq, rising continuously from mob_start_wpm_eq by
## mob_accel_wpm_eq every mob_accel_every_s; 1 WPM-eq = STEPS_PER_WPM_EQ_MIN steps a minute (GDD). advance()
## integrates that speed exactly over each slice, so the result does not depend on the frame rate.

## GDD: 1 WPM-eq is 5 steps a minute. Not a config number.
const STEPS_PER_WPM_EQ_MIN: float = 5.0

## The zombie's logical position in steps (starts at 0).
var zombie_steps: int = 0
## The mob's position in steps (starts start_gap_steps behind the zombie).
var mob_steps: float = 0.0
## Run time the mob has been advanced through, in seconds.
var elapsed_s: float = 0.0

var _config: PitchforkPanicConfig = null
## False for a null or invalid config: the model never moves and is never caught.
var _valid: bool = false


func _init(config: PitchforkPanicConfig) -> void:
	_config = config
	_valid = config != null and config.validate() == ""
	if _valid:
		mob_steps = -config.start_gap_steps


## One correct key: the zombie takes a step.
func step() -> void:
	if not _valid:
		return
	zombie_steps += 1


## Moves the mob through `dt` seconds of run time. Ignores a non-positive or non-finite dt.
func advance(dt: float) -> void:
	if not _valid or not (dt > 0.0 and is_finite(dt)):
		return
	var t0: float = elapsed_s
	var t1: float = t0 + dt
	var steps_per_s_per_wpm_eq: float = STEPS_PER_WPM_EQ_MIN / 60.0
	var base: float = _config.mob_start_wpm_eq * steps_per_s_per_wpm_eq * dt
	var accel: float = _config.mob_accel_wpm_eq * steps_per_s_per_wpm_eq / _config.mob_accel_every_s
	mob_steps += base + accel * (t1 * t1 - t0 * t0) * 0.5
	elapsed_s = t1


## Steps between the mob and the zombie.
func gap() -> float:
	return float(zombie_steps) - mob_steps


## The mob's speed at run time `t`, in WPM-eq.
func mob_wpm_eq(t: float) -> float:
	if not _valid:
		return 0.0
	return _config.mob_start_wpm_eq + _config.mob_accel_wpm_eq * (t / _config.mob_accel_every_s)


## True once the mob has reached the zombie.
func caught() -> bool:
	return _valid and gap() <= 0.0
