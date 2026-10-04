class_name TypingSession
extends RefCounted
## Second stage of the typing pipeline: judges the character TypingInput emits against the
## current target, advances or rejects, and keeps per-key stats. Pure logic: no nodes, no
## autoloads, no clock, nothing asynchronous. RunFrame (Story 2.4) owns the instance and calls judge() only
## while waiting for the first key or running.
##
## target_completed is deliberately not declared: it only means something for word and paragraph
## targets, so Epic 6 adds it together with WordSource.

## Result of one judgment.
enum Verdict { CORRECT, WRONG }

## Emitted once, on the first correct key (before char_accepted).
signal run_started
## Emitted for each correct key. `index` is the zero-based count of keys accepted before this one.
signal char_accepted(expected: String, index: int)
## Emitted for each wrong key; the target does not advance.
signal char_rejected(expected: String, typed: String)
## Emitted after a correct key, once the next target is current.
signal target_changed(next: String)

var _source: TargetSource
var _config: LevelConfig
var _keys_typed: int = 0
var _errors: int = 0
var _started: bool = false
var _accepted_index: int = 0
## expected char -> [attempts, errors, {typed char: count}]
var _per_key: Dictionary = {}


## `config` is stored for later stories (implied spaces in word mode); nothing reads it yet.
func _init(source: TargetSource, config: LevelConfig = null) -> void:
	assert(source != null, "TypingSession needs a TargetSource")
	if source == null:
		Log.error(&"typing", "TypingSession built with a null TargetSource; judge() will always be WRONG")
	_source = source
	_config = config


## Judges one typed character. Everything happens synchronously, signals included.
func judge(c: String) -> Verdict:
	if _source == null:
		return Verdict.WRONG
	var expected: String = _source.current()
	if expected == "":
		return Verdict.WRONG
	if not _per_key.has(expected):
		_per_key[expected] = [0, 0, {}]
	var entry: Array = _per_key[expected]
	entry[0] = int(entry[0]) + 1
	if c == expected:
		_keys_typed += 1
		var index: int = _accepted_index
		_accepted_index += 1
		if not _started:
			_started = true
			run_started.emit()
		_source.advance()
		char_accepted.emit(expected, index)
		target_changed.emit(_source.current())
		return Verdict.CORRECT
	_errors += 1
	entry[1] = int(entry[1]) + 1
	var typed_map: Dictionary = entry[2]
	typed_map[c] = int(typed_map.get(c, 0)) + 1
	char_rejected.emit(expected, c)
	return Verdict.WRONG


## Correct keys so far.
func get_keys_typed() -> int:
	return _keys_typed


## Wrong keys so far.
func get_errors() -> int:
	return _errors


## True after the first correct key.
func has_started() -> bool:
	return _started


## Per-key record in the run-record shape; a deep copy, safe for callers to keep or change.
func get_per_key() -> Dictionary:
	return _per_key.duplicate(true)


## The target the player must type now, or "" when there is none (null or empty source).
func get_current_target() -> String:
	return _source.current() if _source != null else ""


## The `n` targets after the current one, without consuming them; [] for a null source or n <= 0.
func get_upcoming(n: int) -> Array[String]:
	if _source == null:
		var none: Array[String] = []
		return none
	return _source.peek(n)
