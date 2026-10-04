class_name LevelBase
extends Node2D
## The level contract (ADR-1): RunFrame calls down into a level, the level signals up. Every level
## scene's root extends this; the defaults here are safe no-ops.
##
## Rules: a level never reads input, never touches the clock, never writes PlayerData and never calls
## the Router. It reacts to the calls below and emits end_requested / brains_earned_changed.
##
## Randomness: create_target_source() must give the source its OWN RandomNumberGenerator seeded from
## the run RNG (child.seed = rng.randi()). The level may keep the run rng for its own draws; the
## source then never interleaves with them, so a seed always replays the same targets.
##
## Call order inside one run (all synchronous, in the key event's call stack):
##   RunFrame._ready: level instanced -> added under %LevelHost (level _ready) -> create_target_source(rng)
##     -> TypingSession built -> TypingInput configured
##   first correct key: on_run_started() -> on_char_accepted(expected, 0)
##   each correct key: on_char_accepted(expected, index)
##   each wrong key: on_char_rejected(expected, typed) (also before the first correct key; never starts the run)
##   end: clock reaches duration_s (RunFrame) or end_requested(reason) -> on_run_ending(reason) -> outro wait
##     -> RunFrame reads get_brains_earned() and builds the RunResult

## Emitted by the level to end the run early (one of GameConstants.END_REASON_*). RunFrame honours
## it only while the run is RUNNING.
signal end_requested(reason: StringName)
## Emitted by the level whenever its brain total for this run changes (the HUD counter, Story 2.5).
signal brains_earned_changed(total: int)

## The level's settings (duration, case and Space rules, target mode). Set in the level scene.
@export var config: LevelConfig


## Called by RunFrame in _ready, before the session is built. Returns `config`.
func get_level_config() -> LevelConfig:
	return config


## Called once by RunFrame in _ready. Every level must override it and return a source that owns a
## child RNG seeded from `rng` (see the class doc). The base version is a contract violation.
func create_target_source(_rng: RandomNumberGenerator) -> TargetSource:
	assert(false, "LevelBase.create_target_source() must be overridden")
	Log.error(&"level", "%s does not override create_target_source" % name)
	return null


## Called by RunFrame on the first correct key, after the clock starts and before on_char_accepted.
func on_run_started() -> void:
	pass


## Called by RunFrame for each correct key, in the same call as the key event. The source has
## already advanced, so its current() is the next target. `index` is 0-based.
func on_char_accepted(_expected: String, _index: int) -> void:
	pass


## Called by RunFrame for each wrong key (including before the run starts).
func on_char_rejected(_expected: String, _typed: String) -> void:
	pass


## Word and paragraph targets only. Not called until Epic 6 adds TypingSession.target_completed.
func on_target_completed(_target: String) -> void:
	pass


## Called by RunFrame once when the run ends. Returns the outro length in seconds that RunFrame waits
## before the report card (0.0 = none).
func on_run_ending(_reason: StringName) -> float:
	return 0.0


## Read by RunFrame when it builds the RunResult: brains earned in this run, without any bonus.
func get_brains_earned() -> int:
	return 0
