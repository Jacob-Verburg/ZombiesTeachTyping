extends Control
## The run frame: third stage of the typing pipeline (ADR-1). TypingInput -> TypingSession -> RunFrame
## -> level. Owns the run lifecycle (state machine), the RunClock, the run RNG, the TypingSession and
## the level instance, and builds the RunResult at the end. It drives the shared HUD (%Hud, Story 2.5)
## by calling down: target, counts, clock, brains, shake + wrong-key tick, Caps Lock hint, hands (2.6).
## Pause (Story 2.7): Esc, the HUD pause button or focus loss -> PAUSED (tree paused, %PausePanel open);
## Resume -> COUNTDOWN (%Countdown 3-2-1, tree still paused) -> back to the state it was paused from, and
## only then is the tree unpaused; Quit to Menu commits the level's brains and records nothing.
## A finished run is built and saved through PlayerData.record_run (2.8) on entering ENDING, so closing the
## game during the outro loses nothing; DONE only opens the report card.
## Debug hooks (Story 2.10): the overlay reads the plain getters, pins a replay seed in the debug_seed
## static and ends a run with debug_end_run(); both are gated by the is_debug_build seam.
## Everything in the typing path is synchronous: nothing in it waits or defers a call.
## A level config with duration_s <= 0 means "no timer": the level must end the run with end_requested.

enum RunState { WAITING_FIRST_KEY, RUNNING, PAUSED, COUNTDOWN, ENDING, DONE }

## MVP value for RunResult.letter_pool_or_tier; Epic 7 replaces it with the tier.
const LETTER_POOL_ALL: String = "all"
const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")

## Debug builds only (Story 2.10): the replay seed the debug overlay pins; -1 = off. Used when the RUN
## payload has no seed and the level is debug_seed_level. Release never reads it.
static var debug_seed: int = -1
## The level the pinned seed came from: other levels ignore the pin.
static var debug_seed_level: StringName = &""
## Seed and level of the most recent run that started (the overlay's F2 pins them). Set once
## _start_level succeeds, so a failed load never becomes the last run.
static var last_seed: int = -1
static var last_seed_level: StringName = &""

## level_id -> scene lookup (data/levels/level_registry.tres, set in run_frame.tscn).
@export var level_registry: LevelRegistry

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready; tests assign a
## recorder before add_child so the live Router never swaps GUT's scene.
var navigate: Callable
## Test seam: called as pause_tree.call(paused). Defaults (in _ready) to setting get_tree().paused; every
## pause and unpause goes through it, so tests never pause GUT's tree.
var pause_tree: Callable
## Test seam: the PlayerData the run commits brains and settings to. Defaults to the autoload; tests
## inject one on a temp SaveService before add_child, so no test writes the real save.
var player_data: PlayerDataScript
## Test seam: is_debug_build.call() -> bool. Defaults to OS.is_debug_build in _ready; tests assign
## a false one before add_child for the release case. Gates debug_seed and debug_end_run.
var is_debug_build: Callable

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
## Built and recorded on entering ENDING; DONE sends them to the report card.
var _result: RunResult
var _new_best: bool = false
var _uses_router: bool = false
## The state a pause came from; the countdown returns to it.
var _resume_to: RunState = RunState.WAITING_FIRST_KEY
## Set by Quit to Menu: nothing pauses, resumes or quits again after it.
var _quitting: bool = false
## True when the seed came from the pinned debug_seed.
var _replayed: bool = false


func _ready() -> void:
	# First, so the _exit_tree reset always pairs with it, even after a failed load.
	WebPlatform.capture_keys = true
	if not navigate.is_valid():
		navigate = Router.go
		_uses_router = true
	if not pause_tree.is_valid():
		pause_tree = func(paused: bool) -> void: get_tree().paused = paused
	if player_data == null:
		player_data = PlayerData
	if not is_debug_build.is_valid():
		is_debug_build = func() -> bool: return OS.is_debug_build()
	var payload: Dictionary = Router.take_payload()
	var error: String = _start_level(payload)
	if error != "":
		_fail_to_menu(error)


func _exit_tree() -> void:
	WebPlatform.capture_keys = false
	# The autoload outlives the run: drop its connections explicitly.
	if WebPlatform.focus_lost.is_connected(_on_web_platform_focus_lost):
		WebPlatform.focus_lost.disconnect(_on_web_platform_focus_lost)
	if WebPlatform.visibility_hidden.is_connected(_on_web_platform_focus_lost):
		WebPlatform.visibility_hidden.disconnect(_on_web_platform_focus_lost)


## Esc pauses (TypingInput ignores Esc, so it reaches here). While paused this node is frozen with the
## tree, and Esc goes to the pause panel instead.
func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or key.keycode != KEY_ESCAPE or not key.pressed or key.echo:
		return
	if _session == null:
		return
	get_viewport().set_input_as_handled()
	_request_pause()


func _process(delta: float) -> void:
	_clock.advance(delta)
	if _session != null:
		%Hud.update_clock(_clock.get_elapsed(), _session.get_keys_typed())
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


## The level being played (&"" before a level id was read).
func get_level_id() -> StringName:
	return _level_id


## The level config's duration_s; <= 0 means no timer.
func get_duration() -> float:
	return _duration


## True when this run uses the overlay's pinned replay seed.
func is_replay() -> bool:
	return _replayed


## Debug builds only (F6 in the overlay): ends a RUNNING run exactly as if the clock ran out. Refused
## while waiting (the clock never ran), paused or counting down (the tree is paused, so the outro would
## never count down), ending or done. Returns true when the run was ended.
func debug_end_run() -> bool:
	if not is_debug_build.call() or _state != RunState.RUNNING or _quitting:
		Log.debug(&"run", "debug end run refused in %s" % RunState.keys()[_state])
		return false
	_end_run(GameConstants.END_REASON_TIMER)
	return true


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
	_seed_rng(_requested_seed(payload))
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
	# HUD after the level, so the level reacts first; all in the same call as the key.
	%Hud.setup(config, _session.get_current_target())
	_session.target_changed.connect(%Hud.show_target)
	_session.char_accepted.connect(_on_session_char_accepted)
	_session.char_rejected.connect(_on_session_char_rejected)
	_level.brains_earned_changed.connect(%Hud.set_brains)
	%TypingInput.caps_lock_suspected.connect(_on_typing_input_caps_lock_suspected)
	%TypingInput.caps_lock_cleared.connect(_on_typing_input_caps_lock_cleared)
	# Pause flow (Story 2.7).
	%Hud.pause_pressed.connect(_request_pause)
	%PausePanel.resume_chosen.connect(_on_pause_panel_resume_chosen)
	%PausePanel.quit_chosen.connect(_quit_to_menu)
	%PausePanel.music_toggled.connect(_on_pause_panel_music_toggled)
	%PausePanel.sound_toggled.connect(_on_pause_panel_sound_toggled)
	%Countdown.finished.connect(_on_countdown_finished)
	WebPlatform.focus_lost.connect(_on_web_platform_focus_lost)
	WebPlatform.visibility_hidden.connect(_on_web_platform_focus_lost)
	last_seed = _seed
	last_seed_level = _level_id
	Log.info(&"run", "started level=%s seed=%d%s" % [_level_id, _seed, " (replay)" if _replayed else ""])
	return ""


## The payload's seed wins (even -1 or a wrong type = random); without one, a debug build uses the
## overlay's pinned debug_seed when it was pinned on this level; else -1 (random).
func _requested_seed(payload: Dictionary) -> Variant:
	if payload.has("seed"):
		return payload["seed"]
	if is_debug_build.call() and debug_seed >= 0 and debug_seed_level == _level_id:
		_replayed = true
		return debug_seed
	return -1


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
	%Hud.visible = false
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
	var from_state: RunState = _state
	_state = new_state
	# The tree is unpaused only when a countdown ends (into RUNNING or WAITING_FIRST_KEY).
	if from_state == RunState.COUNTDOWN and (new_state == RunState.RUNNING or new_state == RunState.WAITING_FIRST_KEY):
		pause_tree.call(false)
	match new_state:
		RunState.RUNNING:
			# start() only counts the first time; resume() continues after a pause. Back in
			# WAITING_FIRST_KEY (paused before the first key) the clock is not started.
			_clock.start()
			_clock.resume()
		RunState.PAUSED:
			_clock.pause()
			pause_tree.call(true)
			%PausePanel.open(player_data.get_setting(&"music_on"), player_data.get_setting(&"sound_on"))
		RunState.COUNTDOWN:
			# The tree stays paused until the countdown has finished.
			%PausePanel.close()
			%Countdown.start(GameConstants.COUNTDOWN_FROM, GameConstants.COUNTDOWN_STEP_S)
		RunState.ENDING:
			_clock.pause()
			%TypingInput.active = false
			# Input is off from here, so caps_lock_cleared can never fire: clear the hint now.
			%Hud.set_caps_hint(false)
			%Hud.clear_hands()
			var outro: float = _level.on_run_ending(_end_reason)
			_outro_left = maxf(0.0, outro) if is_finite(outro) else 0.0
			_record_result()
		RunState.DONE:
			_send_result()


## Esc, the HUD pause button and focus loss all end here.
func _request_pause() -> void:
	if _quitting:
		return
	match _state:
		RunState.RUNNING, RunState.WAITING_FIRST_KEY:
			_resume_to = _state
			_set_state(RunState.PAUSED)
		RunState.COUNTDOWN:
			# Keep _resume_to: the run still returns where it was first paused from.
			%Countdown.cancel()
			_set_state(RunState.PAUSED)


## Quit to Menu (FR13): keep the brains earned so far (FR52), no bonus, no RunResult, nothing recorded.
## The tree stays paused; Router.go() pauses for its fade and unpauses after the swap.
func _quit_to_menu() -> void:
	if _quitting or _state != RunState.PAUSED:
		return
	_quitting = true
	%TypingInput.active = false
	var brains: int = _level.get_brains_earned()
	player_data.add_brains(brains)
	Log.info(&"run", "quit level=%s brains=%d" % [_level_id, brains])
	_navigate_when_idle(Router.Screen.MAIN_MENU, {})


## After the countdown: Caps Lock may have changed while away, so forget the streak and hide the hint.
func _after_resume() -> void:
	%TypingInput.reset_caps_hint()
	%Hud.set_caps_hint(false)


func _end_run(reason: StringName) -> void:
	_end_reason = reason
	_set_state(RunState.ENDING)


## On entering ENDING, after on_run_ending(): the clock is paused and input is off, so nothing in the
## result changes during the outro. Saved now, not at DONE, so a close during the outro keeps the run.
func _record_result() -> void:
	var duration: float = _clock.get_elapsed()
	# A no-timer level (duration <= 0) only ends on "timer" through the debug F6: keep the elapsed time.
	if _end_reason == GameConstants.END_REASON_TIMER and _duration > 0.0:
		duration = minf(duration, _duration)
	_result = RunResult.create(
		_level_id, int(Time.get_unix_time_from_system()), duration, _session.get_keys_typed(),
		_session.get_errors(), _session.get_per_key(), _level.get_brains_earned(), 0, LETTER_POOL_ALL,
		_end_reason)
	Log.info(&"run", "ended level=%s reason=%s wpm=%d" % [_result.level_id, _result.end_reason, _result.wpm])
	_new_best = player_data.record_run(_result)


func _send_result() -> void:
	_navigate_when_idle(Router.Screen.REPORT_CARD, {"result": _result, "new_best": _new_best})


func _on_typing_input_char_typed(c: String) -> void:
	if _session == null:
		return
	if _state == RunState.WAITING_FIRST_KEY or _state == RunState.RUNNING:
		_session.judge(c)


## The first correct key: the clock starts before the level hears about it.
func _on_session_run_started() -> void:
	_set_state(RunState.RUNNING)
	_level.on_run_started()
	%Hud.hide_start_prompt()


func _on_session_char_accepted(_expected: String, _index: int) -> void:
	%Hud.set_counts(_session.get_keys_typed(), _session.get_errors())


## Wrong key (FR2): count, shake the glyph and the quiet tick (AudioManager throttles it to 150 ms).
func _on_session_char_rejected(_expected: String, _typed: String) -> void:
	%Hud.set_counts(_session.get_keys_typed(), _session.get_errors())
	%Hud.shake_target()
	AudioManager.play_sfx(&"sfx_wrong_key")


func _on_typing_input_caps_lock_suspected() -> void:
	%Hud.set_caps_hint(true)


func _on_typing_input_caps_lock_cleared() -> void:
	%Hud.set_caps_hint(false)


func _on_pause_panel_resume_chosen() -> void:
	if _quitting or _state != RunState.PAUSED:
		return
	_set_state(RunState.COUNTDOWN)


func _on_countdown_finished() -> void:
	if _state != RunState.COUNTDOWN:
		return
	_set_state(_resume_to)
	_after_resume()


func _on_pause_panel_music_toggled(on: bool) -> void:
	if _quitting:
		return
	AudioManager.set_music_muted(not on)
	player_data.set_setting(&"music_on", on)


func _on_pause_panel_sound_toggled(on: bool) -> void:
	if _quitting:
		return
	AudioManager.set_sfx_muted(not on)
	player_data.set_setting(&"sound_on", on)


## Window blur or tab hidden (one tab switch fires both): pauses a running run or a countdown only.
func _on_web_platform_focus_lost() -> void:
	if _state == RunState.RUNNING or _state == RunState.COUNTDOWN:
		_request_pause()


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
