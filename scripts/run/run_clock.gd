class_name RunClock
extends RefCounted
## The run's stopwatch. Accumulates only the deltas it is given while running and never reads wall
## time, so a pause is exact (architecture State Management). RunFrame._process feeds it; tests call
## advance() with chosen deltas. Pure: no nodes, no autoloads.

var _elapsed: float = 0.0
var _running: bool = false
var _started: bool = false


## Starts from 0 on the first call (the run's first correct key). Later calls do nothing: the clock
## is never reset mid-run; use resume() after pause().
func start() -> void:
	if _started:
		return
	_started = true
	_running = true


## Stops accumulating; the elapsed time is kept.
func pause() -> void:
	_running = false


## Continues after pause(). Does nothing before start().
func resume() -> void:
	if _started:
		_running = true


## Adds delta while running. Negative or non-finite deltas are ignored.
func advance(delta: float) -> void:
	if not _running or not is_finite(delta) or delta < 0.0:
		return
	_elapsed += delta


## Seconds accumulated while running.
func get_elapsed() -> float:
	return _elapsed


## True between start()/resume() and pause().
func is_running() -> bool:
	return _running
