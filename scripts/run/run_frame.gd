extends Control
## The run frame: third stage of the typing pipeline (ADR-1). TypingInput -> TypingSession -> RunFrame
## -> level. Owns the run lifecycle (state machine), the RunClock, the run RNG, the TypingSession and
## the level instance, and builds the RunResult at the end. The HUD (2.5), hands (2.6), pause and
## countdown (2.7), PlayerData.record_run (2.8) and the overlay's run fields (2.10) attach here later.
## Everything in the typing path is synchronous: nothing in it waits or defers a call.
## A level config with duration_s <= 0 means "no timer": the level must end the run with end_requested.

enum RunState { WAITING_FIRST_KEY, RUNNING, PAUSED, COUNTDOWN, ENDING, DONE }

## MVP value for RunResult.letter_pool_or_tier; Epic 7 replaces it with the tier.
const LETTER_POOL_ALL: String = "all"

## level_id -> scene lookup (data/levels/level_registry.tres, set in run_frame.tscn).
@export var level_registry: LevelRegistry

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready; tests assign a
## recorder before add_child so the live Router never swaps GUT's scene.
var navigate: Callable

var _state: RunState = RunState.WAITING_FIRST_KEY
var _clock: RunClock = RunClock.new()
var _rng: RandomNumberGenerator
var _seed: int = -1
var _session: TypingSession
var _level: LevelBase
var _level_id: StringName = &""
var _duration: float = 0.0
var _end_reason: StringName = &""
var _outro_left: float = 0.0
var _uses_router: bool = false


func _ready() -> void:
	# First, so the _exit_tree reset always pairs with it, even after a failed load.
	WebPlatform.capture_keys = true
	if not navigate.is_valid():
		navigate = Router.go
		_uses_router = true
	var payload: Dictionary = Router.take_payload()
	var error: String = _start_level(payload)
	if error != "":
		_fail_to_menu(error)


func _exit_tree() -> void:
	WebPlatform.capture_keys = false


func _process(delta: float) -> void:
	_clock.advance(delta)
	match _state:
		RunState.RUNNING:
			if _duration > 0.0 and _clock.get_elapsed() >= _duration:
				_end_run(GameConstants.END_REASON_TIMER)
		RunState.ENDING:
			_outro_left -= delta
			if _outro_left <= 0.0:
				_set_state(RunState.DONE)


## Current lifecycle state.
func get_state() -> RunState:
	return _state


## Lesson Time so far: seconds since the first correct key, paused time excluded.
func get_elapsed() -> float:
	return _clock.get_elapsed()


## The run's seed (always >= 0 once a level started; the overlay shows it for replay, Story 2.10).
func get_seed() -> int:
	return _seed


## The run's judgment session; null after a failed load.
func get_session() -> TypingSession:
	return _session


## The level instance under %LevelHost; null after a failed load.
func get_level() -> LevelBase:
	return _level


## Builds the level, RNG, session and input wiring. Returns "" on success, else the failure reason.
func _start_level(payload: Dictionary) -> String:
	var raw_id: Variant = payload.get("level_id")
	if typeof(raw_id) != TYPE_STRING_NAME and typeof(raw_id) != TYPE_STRING:
		return "missing level_id"
	_level_id = StringName(raw_id)
	if level_registry == null:
		return "no level registry"
	var scene: PackedScene = level_registry.get_scene(_level_id)
	if scene == null:
		return "unknown level_id %s" % _level_id
	var instance: Node = scene.instantiate()
	var level: LevelBase = instance as LevelBase
	if level == null:
		if instance != null:
			instance.free()
		return "level %s is not a LevelBase" % _level_id
	var config: LevelConfig = level.get_level_config()
	if config == null:
		level.free()
		return "level %s has no LevelConfig" % _level_id
	_level = level
	%LevelHost.add_child(level)
	_seed_rng(payload.get("seed", -1))
	var source: TargetSource = level.create_target_source(_rng)
	if source == null:
		return "level %s gave no target source" % _level_id
	_session = TypingSession.new(source, config)
	_duration = config.duration_s
	%TypingInput.configure(config)
	%TypingInput.char_typed.connect(_on_typing_input_char_typed)
	_session.run_started.connect(_on_session_run_started)
	_session.char_accepted.connect(_level.on_char_accepted)
	_session.char_rejected.connect(_level.on_char_rejected)
	_level.end_requested.connect(_on_level_end_requested)
	Log.info(&"run", "started level=%s seed=%d" % [_level_id, _seed])
	return ""


## One RNG per run. A payload seed (an int >= 0) replays a run; anything else gets a fresh seed that
## is still a known number.
func _seed_rng(requested: Variant) -> void:
	_rng = RandomNumberGenerator.new()
	if typeof(requested) == TYPE_INT and int(requested) >= 0:
		_seed = int(requested)
	else:
		var seeder: RandomNumberGenerator = RandomNumberGenerator.new()
		seeder.randomize()
		_seed = seeder.randi()
	_rng.seed = _seed


## NFR16: log, drop the half-built level, go back to the menu. RunFrame._ready runs inside Router.go(),
## which ignores a new go() while transitioning, so the real Router is asked once its swap is done.
func _fail_to_menu(reason: String) -> void:
	Log.error(&"run", "cannot start run: %s" % reason)
	%TypingInput.active = false
	_session = null
	if _level != null:
		_level.get_parent().remove_child(_level)
		_level.free()
		_level = null
	_navigate_when_idle(Router.Screen.MAIN_MENU, {})


## navigate.call, but a real Router that is still mid-transition drops go(): wait for its swap first.
func _navigate_when_idle(screen: Router.Screen, payload: Dictionary) -> void:
	if _uses_router and Router.is_transitioning():
		Router.screen_changed.connect(
				func(_changed: Router.Screen) -> void: navigate.call(screen, payload), CONNECT_ONE_SHOT)
	else:
		navigate.call(screen, payload)


## Every state change goes through here.
func _set_state(new_state: RunState) -> void:
	if new_state == _state:
		return
	Log.debug(&"run", "state %s -> %s" % [RunState.keys()[_state], RunState.keys()[new_state]])
	_state = new_state
	match new_state:
		RunState.RUNNING:
			# start() only counts the first time; resume() continues after a pause (Story 2.7).
			_clock.start()
			_clock.resume()
		RunState.ENDING:
			_clock.pause()
			%TypingInput.active = false
			var outro: float = _level.on_run_ending(_end_reason)
			_outro_left = maxf(0.0, outro) if is_finite(outro) else 0.0
		RunState.DONE:
			_send_result()


func _end_run(reason: StringName) -> void:
	_end_reason = reason
	_set_state(RunState.ENDING)


func _send_result() -> void:
	var duration: float = _clock.get_elapsed()
	if _end_reason == GameConstants.END_REASON_TIMER:
		duration = minf(duration, _duration)
	var result: RunResult = RunResult.create(
		_level_id, int(Time.get_unix_time_from_system()), duration, _session.get_keys_typed(),
		_session.get_errors(), _session.get_per_key(), _level.get_brains_earned(), 0, LETTER_POOL_ALL,
		_end_reason)
	Log.info(&"run", "ended level=%s reason=%s wpm=%d" % [result.level_id, result.end_reason, result.wpm])
	_navigate_when_idle(Router.Screen.REPORT_CARD, {"result": result})


func _on_typing_input_char_typed(c: String) -> void:
	if _session == null:
		return
	if _state == RunState.WAITING_FIRST_KEY or _state == RunState.RUNNING:
		_session.judge(c)


## The first correct key: the clock starts before the level hears about it.
func _on_session_run_started() -> void:
	_set_state(RunState.RUNNING)
	_level.on_run_started()


func _on_level_end_requested(reason: StringName) -> void:
	if reason not in [
			GameConstants.END_REASON_TIMER, GameConstants.END_REASON_CAUGHT,
			GameConstants.END_REASON_ESCAPED]:
		Log.error(&"run", "ignored end_requested with unknown reason '%s'" % reason)
		return
	if _state != RunState.RUNNING:
		Log.debug(&"run", "ignored end_requested(%s) in %s" % [reason, RunState.keys()[_state]])
		return
	_end_run(reason)
