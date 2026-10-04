extends Control
## The resume countdown (FR12, GDD M3): big numbers counting down on the playfield while the tree stays
## paused; RunFrame unpauses only when `finished` fires. Runs only while the tree is paused
## (PROCESS_MODE_WHEN_PAUSED). Driven by _process with a remaining-time counter (deterministic for
## tests). The numbers and step come from the caller (GameConstants). Placeholder look until Story 5.0.

## Emitted once when the last number has been shown for its full step. Never emitted after cancel().
signal finished

## A remaining time below this has run out (float sums of frame deltas).
const _DONE_S: float = 1e-6

var _from: int = 0
var _step_s: float = 0.0
var _left: float = 0.0
var _running: bool = false
var _shown: int = 0


func _process(delta: float) -> void:
	if not _running:
		return
	_left -= delta
	if _left <= _DONE_S:
		_running = false
		visible = false
		_shown = 0
		finished.emit()
		return
	_show(clampi(ceili(_left / _step_s - _DONE_S), 1, _from))


## Shows `from`, then counts down one number per `step_s` to 1, then hides and emits `finished`.
func start(from: int, step_s: float) -> void:
	_from = maxi(1, from)
	_step_s = maxf(step_s, _DONE_S)
	_left = _from * _step_s
	_running = true
	visible = true
	_show(_from)


## Stops and hides without emitting `finished` (focus loss sends the run back to the pause panel).
func cancel() -> void:
	_running = false
	visible = false
	_shown = 0


## True from start() until it finishes or is cancelled.
func is_running() -> bool:
	return _running


## The number on screen, 0 when hidden.
func get_shown_number() -> int:
	return _shown if visible else 0


func _show(n: int) -> void:
	if n == _shown:
		return
	_shown = n
	%NumberLabel.text = str(n)
	%ShadowLabel.text = str(n)
