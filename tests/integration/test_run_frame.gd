extends GutTest
## Run frame (Story 2.4): state machine, clock, level calls, run end, seed replay, failed loads.
## Debug hooks (Story 2.10): last_seed, pinned debug_seed, debug_end_run, the is_debug_build seam.
## Ambience (Story 3.7): set_ambience is a recorder too; only one test uses the live AudioManager.
## Instances are disabled (no engine _process, no real keys): tests call _process(delta) and
## %TypingInput.handle_key(event) by hand. navigate is a recorder, so the live Router never swaps
## GUT's scene.

const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")

var _nav: Array = []
## pause_tree recorder (Story 2.7): GUT's own tree is never paused.
var _paused: Array[bool] = []
## set_ambience recorder (Story 3.7): the live AudioManager never groans for a test frame.
var _ambience: Array[bool] = []
## play_music / duck_music / play_sfx recorders (Story 5.1): the live AudioManager is never asked.
var _music: Array[StringName] = []
var _duck: Array[bool] = []
var _sfx: Array[StringName] = []


func before_each() -> void:
	assert_false(WebPlatform.capture_keys, "a run frame left capture_keys on")
	_nav = []
	_paused = []
	_ambience = []
	_music = []
	_duck = []
	_sfx = []


func after_each() -> void:
	get_tree().paused = false
	Router.take_payload()
	_restore_audio()
	assert_false(AudioManager.is_ambience_on(), "a run frame left ambience on")
	AudioManager.stop_ambience()
	_reset_input_handled()
	RunFrameScript.debug_seed = -1
	RunFrameScript.debug_seed_level = &""
	RunFrameScript.last_seed = -1
	RunFrameScript.last_seed_level = &""


func after_all() -> void:
	assert_false(WebPlatform.capture_keys, "a run frame left capture_keys on")
	_clear_pause_saves()


func _record(screen: int, payload: Dictionary) -> void:
	_nav.append([screen, payload])


func _make(
		payload: Dictionary, registry: LevelRegistry = null, data: PlayerDataScript = null
) -> RunFrameScript:
	Router._store_payload(payload)
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.navigate = _record
	frame.pause_tree = func(paused: bool) -> void: _paused.append(paused)
	frame.set_ambience = func(on: bool) -> void: _ambience.append(on)
	frame.play_music = func(id: StringName) -> void: _music.append(id)
	frame.duck_music = func(on: bool) -> void: _duck.append(on)
	frame.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	# A finished run writes through record_run: never to the real save. Tests may pass their own.
	frame.player_data = data if data != null else _fake_player_data()
	if registry != null:
		frame.level_registry = registry
	return frame


func _start(payload: Dictionary, registry: LevelRegistry = null) -> RunFrameScript:
	var frame: RunFrameScript = _make(payload, registry)
	add_child_autofree(frame)
	return frame


func _key(c: String) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.unicode = c.unicode_at(0)
	event.keycode = OS.find_keycode_from_string(c.to_upper())
	return event


func _input_node(frame: RunFrameScript) -> TypingInput:
	return frame.get_node("%TypingInput") as TypingInput


func _send(frame: RunFrameScript, c: String) -> bool:
	return _input_node(frame).handle_key(_key(c))


func _type_correct(frame: RunFrameScript) -> String:
	var target: String = frame.get_session().get_current_target()
	_send(frame, target)
	return target


func _type_wrong(frame: RunFrameScript) -> void:
	var target: String = frame.get_session().get_current_target()
	_send(frame, "b" if target == "a" else "a")


func _letter(frame: RunFrameScript) -> String:
	return (frame.get_level().get_node("%LetterLabel") as Label).text


func _result(index: int = 0) -> RunResult:
	var payload: Dictionary = _nav[index][1]
	return payload["result"] as RunResult


func test_start() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_not_null(frame.get_level())
	assert_eq(frame.get_level().get_parent(), frame.get_node("%LevelHost"))
	assert_not_null(frame.get_session())
	assert_true(WebPlatform.capture_keys)
	assert_eq(frame.get_seed(), 42)
	assert_eq(Router.take_payload(), {}, "payload consumed")
	assert_eq(_letter(frame), frame.get_session().get_current_target(), "first target shown")
	assert_eq(_nav, [])


func test_level_id_as_string_is_accepted() -> void:
	var frame: RunFrameScript = _start({"level_id": "test_level", "seed": 1})
	assert_not_null(frame.get_session())


func test_waiting_clock_stays_at_zero() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	frame._process(5.0)
	assert_eq(frame.get_elapsed(), 0.0)
	_type_wrong(frame)
	assert_eq(frame.get_session().get_errors(), 1, "a wrong key before the start is an error")
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	frame._process(2.0)
	assert_eq(frame.get_elapsed(), 0.0)


func test_first_correct_key_starts_the_clock() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	frame._process(3.0)
	_type_correct(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(frame.get_elapsed(), 0.0)
	frame._process(0.5)
	assert_eq(frame.get_elapsed(), 0.5)


func test_level_reacts_in_the_same_call() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	for i: int in 3:
		var before: String = _letter(frame)
		assert_true(_send(frame, frame.get_session().get_current_target()))
		assert_eq(_letter(frame), frame.get_session().get_current_target(), "label updated before handle_key returned")
		assert_ne(_letter(frame), before)


func test_fourth_correct_key_earns_a_brain() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	for i: int in 3:
		_type_correct(frame)
	assert_eq(frame.get_level().get_brains_earned(), 0)
	_type_correct(frame)
	assert_eq(frame.get_level().get_brains_earned(), 1)


func test_timer_end() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	_type_wrong(frame)
	_type_correct(frame)
	frame._process(0.5)
	for i: int in 3:
		_type_correct(frame)
	frame._process(200.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(frame.get_session().get_keys_typed(), 4)
	assert_eq(frame.get_session().get_errors(), 1)
	# Typing is rejected while ending: the gate is off and nothing is counted.
	assert_false(_send(frame, frame.get_session().get_current_target()))
	assert_false(_send(frame, "q" if frame.get_session().get_current_target() != "q" else "w"))
	assert_eq(frame.get_session().get_keys_typed(), 4)
	assert_eq(frame.get_session().get_errors(), 1)
	frame._process(0.4)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING, "outro is 0.5 s")
	assert_eq(_nav, [])
	frame._process(0.2)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_nav.size(), 1)
	assert_eq(_nav[0][0], Router.Screen.REPORT_CARD)
	var result: RunResult = _result()
	assert_not_null(result)
	assert_eq(result.level_id, &"test_level")
	assert_eq(result.end_reason, GameConstants.END_REASON_TIMER)
	assert_eq(result.duration_s, 120.0, "clamped to the level duration")
	assert_eq(result.keys_typed, 4)
	assert_eq(result.errors, 1)
	assert_eq(result.brains, 1)
	assert_eq(result.bonus_brains, 0)
	assert_eq(result.letter_pool_or_tier, "all")
	assert_gt(result.per_key.size(), 0)
	for i: int in 5:
		frame._process(1.0)
	assert_eq(_nav.size(), 1, "the result is sent once")


func test_timer_ends_at_exactly_the_duration() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	_type_correct(frame)
	frame._process(119.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING, "ends at exactly the duration")


func test_end_requested_end() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	frame.get_level().end_requested.emit(GameConstants.END_REASON_CAUGHT)
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY, "ignored before the run starts")
	_type_correct(frame)
	_type_correct(frame)
	frame._process(3.25)
	frame.get_level().end_requested.emit(GameConstants.END_REASON_CAUGHT)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	frame.get_level().end_requested.emit(GameConstants.END_REASON_ESCAPED)
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_nav.size(), 1)
	var result: RunResult = _result()
	assert_eq(result.end_reason, GameConstants.END_REASON_CAUGHT, "the second request is ignored")
	assert_eq(result.duration_s, 3.25, "not clamped")
	assert_eq(result.keys_typed, 2)


func test_unknown_end_reason_is_ignored() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	_type_correct(frame)
	frame.get_level().end_requested.emit(&"quit")
	frame.get_level().end_requested.emit(&"")
	assert_push_error("unknown reason 'quit'")
	assert_push_error("unknown reason ''")
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING, "bad reasons never end the run")
	frame.get_level().end_requested.emit(GameConstants.END_REASON_ESCAPED)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)


func _targets(rng_seed: int, count: int) -> Array[String]:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": rng_seed})
	var out: Array[String] = []
	for i: int in count:
		out.append(_type_correct(frame))
	return out


func test_seed_replay() -> void:
	var first: Array[String] = _targets(7, 20)
	assert_eq(_targets(7, 20), first)
	assert_ne(_targets(8, 20), first)


func test_no_seed_is_random_but_known() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level"})
	assert_true(frame.get_seed() >= 0)
	var negative: RunFrameScript = _start({"level_id": &"test_level", "seed": -1})
	assert_true(negative.get_seed() >= 0)


func test_wrong_seed_type_is_random() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": "abc"})
	assert_true(frame.get_seed() >= 0)
	assert_not_null(frame.get_session())


func _assert_failed(frame: RunFrameScript) -> void:
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_null(frame.get_session())
	assert_push_error("[ERROR][run]")
	assert_false(_send(frame, "a"), "typing does nothing")
	assert_eq(frame.get_node("%LevelHost").get_child_count(), 0)
	assert_eq(_nav.size(), 1)


func test_unknown_level_falls_back_to_menu() -> void:
	_assert_failed(_start({"level_id": &"nope"}))


func test_missing_level_id_falls_back_to_menu() -> void:
	_assert_failed(_start({}))


func test_wrong_level_id_type_falls_back_to_menu() -> void:
	_assert_failed(_start({"level_id": 5}))


func test_scene_that_is_not_a_level_falls_back_to_menu() -> void:
	var registry: LevelRegistry = LevelRegistry.new()
	var entry: LevelEntry = LevelEntry.new()
	entry.id = &"menu"
	entry.scene = MenuScene
	registry.entries = [entry]
	_assert_failed(_start({"level_id": &"menu"}, registry))


func test_level_without_config_falls_back_to_menu() -> void:
	var bare: LevelBase = LevelBase.new()
	var packed: PackedScene = PackedScene.new()
	packed.pack(bare)
	bare.free()
	var registry: LevelRegistry = LevelRegistry.new()
	var entry: LevelEntry = LevelEntry.new()
	entry.id = &"bare"
	entry.scene = packed
	registry.entries = [entry]
	_assert_failed(_start({"level_id": &"bare"}, registry))


func test_capture_keys_reset_on_exit() -> void:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 3})
	add_child(frame)
	assert_true(WebPlatform.capture_keys)
	remove_child(frame)
	frame.free()
	assert_false(WebPlatform.capture_keys)


func test_capture_keys_reset_after_failed_load() -> void:
	var frame: RunFrameScript = _make({})
	add_child(frame)
	assert_true(WebPlatform.capture_keys, "set first, even when the load fails")
	assert_push_error("[ERROR][run]")
	remove_child(frame)
	frame.free()
	assert_false(WebPlatform.capture_keys)


# --- HUD wiring (Story 2.5) -------------------------------------------------

func _hud(frame: RunFrameScript) -> Control:
	return frame.get_node("%Hud") as Control


func _hud_text(frame: RunFrameScript, path: String) -> String:
	return (_hud(frame).get_node(path) as Label).text


func _capital(c: String) -> InputEventKey:
	var event: InputEventKey = _key(c.to_upper())
	event.shift_pressed = true
	return event


func test_hud_shows_first_target_and_prompt() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	assert_true(_hud(frame).visible)
	assert_eq(_hud_text(frame, "%TargetLabel"), frame.get_session().get_current_target())
	assert_eq(_hud_text(frame, "%StartPromptLabel"), "Type the letter to start!")
	assert_true((_hud(frame).get_node("%StartPrompt") as Control).visible)
	assert_eq(_hud_text(frame, "%TimerValue"), "2:00")


func test_wrong_key_updates_hud_in_the_same_call() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	_type_wrong(frame)
	assert_eq(_hud_text(frame, "%ErrorsValue"), "1", "before handle_key returned")
	_hud(frame).call("_process", 0.05)
	assert_ne(_hud(frame).call("get_target_offset_x"), 0.0, "the glyph shakes")
	assert_true((_hud(frame).get_node("%StartPrompt") as Control).visible, "a wrong key doesn't start the run")


func test_first_correct_key_updates_hud() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	_type_correct(frame)
	assert_false((_hud(frame).get_node("%StartPrompt") as Control).visible)
	assert_eq(_hud_text(frame, "%KeysValue"), "1")
	assert_eq(_hud_text(frame, "%TargetLabel"), frame.get_session().get_current_target())


func test_brain_counter_follows_the_level() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	for i: int in 3:
		_type_correct(frame)
	assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), "0")
	_type_correct(frame)
	assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), "1", "same call as the 4th key")


func test_process_drives_timer_and_live_wpm() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	frame._process(3.0)
	assert_eq(_hud_text(frame, "%TimerValue"), "2:00", "waiting: full length")
	_type_correct(frame)
	for i: int in 9:
		_type_correct(frame)
	frame._process(4.0)
	assert_eq(_hud_text(frame, "%TimerValue"), "1:56")
	assert_eq(_hud_text(frame, "%WpmValue"), _hud(frame).get("WPM_PLACEHOLDER"))
	frame._process(1.0)
	assert_eq(_hud_text(frame, "%WpmValue"), "24", "10 keys in 5 s")


func test_caps_lock_hint() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	var hint: Control = _hud(frame).get_node("%CapsHint") as Control
	assert_false(hint.visible)
	for c: String in ["q", "w", "e"]:
		_input_node(frame).handle_key(_capital(c))
	assert_true(hint.visible)
	_send(frame, "x")
	assert_false(hint.visible)


func test_caps_lock_hint_clears_when_the_run_ends() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	var hint: Control = _hud(frame).get_node("%CapsHint") as Control
	_type_correct(frame)
	for c: String in ["q", "w", "e"]:
		_input_node(frame).handle_key(_capital(c))
	assert_true(hint.visible, "precondition: the hint is showing")
	frame.get_level().end_requested.emit(GameConstants.END_REASON_ESCAPED)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_false(hint.visible, "the hint does not linger through the outro")


func test_failed_load_hides_hud() -> void:
	var frame: RunFrameScript = _start({"level_id": &"nope"})
	assert_push_error("[ERROR][run]")
	assert_false(_hud(frame).visible)


# --- zombie hands (Story 2.6) -----------------------------------------------

func _hands(frame: RunFrameScript) -> Node:
	return _hud(frame).get_node("%ZombieHands")


func _finger_for(frame: RunFrameScript) -> Vector2i:
	var map: FingerMap = load("res://data/finger_map.tres") as FingerMap
	return map.fingers_for(frame.get_session().get_current_target())[0]


func test_hands_light_the_next_finger() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	assert_true(_hands(frame).call("is_lit", _finger_for(frame)), "waiting: first target's finger")
	for i: int in 5:
		_type_correct(frame)
		var lit: Array[Vector2i] = _hands(frame).call("get_lit_fingers")
		assert_eq(lit, [_finger_for(frame)] as Array[Vector2i], "after key %d, same call" % i)


func test_hands_go_dark_when_the_run_ends() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	_type_correct(frame)
	assert_false((_hands(frame).call("get_lit_fingers") as Array[Vector2i]).is_empty(), "precondition")
	frame.get_level().end_requested.emit(GameConstants.END_REASON_ESCAPED)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(_hands(frame).call("get_lit_fingers"), [] as Array[Vector2i], "no cue through the outro")
	assert_eq(_hands(frame).call("get_outline_width"), 0)


func test_wrong_key_keeps_the_lit_finger() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	var before: Array[Vector2i] = _hands(frame).call("get_lit_fingers")
	_type_wrong(frame)
	assert_eq(_hands(frame).call("get_lit_fingers"), before)


# --- pause, focus loss and resume countdown (Story 2.7) ----------------------

const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PAUSE_SAVE_DIR: String = "user://test_run_frame_saves"


func _clear_pause_saves() -> void:
	if not DirAccess.dir_exists_absolute(PAUSE_SAVE_DIR):
		return
	for file_name: String in DirAccess.get_files_at(PAUSE_SAVE_DIR):
		DirAccess.remove_absolute(PAUSE_SAVE_DIR.path_join(file_name))


## A PlayerData on a temp SaveService, so no test writes the real save.
func _fake_player_data() -> PlayerDataScript:
	DirAccess.make_dir_recursive_absolute(PAUSE_SAVE_DIR)
	_clear_pause_saves()
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = PAUSE_SAVE_DIR
	add_child_autofree(save)
	var data: PlayerDataScript = PlayerDataScript.new()
	data.save_service = save
	add_child_autofree(data)
	return data


## A test-level run that uses a fake PlayerData.
func _start_pausable(data: PlayerDataScript) -> RunFrameScript:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 42}, null, data)
	add_child_autofree(frame)
	return frame


func _restore_audio() -> void:
	AudioManager.set_music_muted(false)
	AudioManager.set_sfx_muted(false)


func _esc(echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	return event


func _panel(frame: RunFrameScript) -> Control:
	return frame.get_node("%PausePanel") as Control


func _countdown(frame: RunFrameScript) -> Control:
	return frame.get_node("%Countdown") as Control


func _resume(frame: RunFrameScript) -> void:
	_panel(frame).emit_signal("resume_chosen")


func _run_countdown(frame: RunFrameScript) -> void:
	for i: int in GameConstants.COUNTDOWN_FROM:
		_countdown(frame).call("_process", GameConstants.COUNTDOWN_STEP_S)


func _running_frame(data: PlayerDataScript) -> RunFrameScript:
	var frame: RunFrameScript = _start_pausable(data)
	_type_correct(frame)
	frame._process(2.0)
	return frame


func test_esc_pauses_a_running_run() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_eq(_paused, [true] as Array[bool])
	assert_true(_panel(frame).call("is_open"))
	frame._process(5.0)
	assert_eq(frame.get_elapsed(), 2.0, "the clock is stopped")
	var keys: int = frame.get_session().get_keys_typed()
	var errors: int = frame.get_session().get_errors()
	_type_correct(frame)
	_type_wrong(frame)
	assert_eq(frame.get_session().get_keys_typed(), keys)
	assert_eq(frame.get_session().get_errors(), errors)
	assert_true(WebPlatform.capture_keys, "keys stay captured while paused")


func test_esc_echo_and_esc_while_ending_do_nothing() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc(true))
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING, "echo ignored")
	frame._process(200.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	frame._unhandled_input(_esc())
	frame.get_node("%Hud").emit_signal("pause_pressed")
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(_paused, [] as Array[bool])


func test_pause_button_pauses() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame.get_node("%Hud").emit_signal("pause_pressed")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_true(_panel(frame).call("is_open"))


func test_resume_counts_down_with_the_tree_still_paused() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	_resume(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.COUNTDOWN)
	assert_false(_panel(frame).call("is_open"))
	assert_eq(_countdown(frame).call("get_shown_number"), 3)
	assert_eq(_paused, [true] as Array[bool], "no unpause before the countdown ends")
	var keys: int = frame.get_session().get_keys_typed()
	_type_correct(frame)
	assert_eq(frame.get_session().get_keys_typed(), keys, "typing rejected during the countdown")
	_countdown(frame).call("_process", 0.5)
	_countdown(frame).call("_process", 0.5)
	assert_eq(frame.get_state(), RunFrameScript.RunState.COUNTDOWN)
	_countdown(frame).call("_process", 0.5)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(_paused, [true, false] as Array[bool])
	frame._process(1.0)
	assert_eq(frame.get_elapsed(), 3.0, "the clock continues from where it stopped")
	_type_correct(frame)
	assert_eq(frame.get_session().get_keys_typed(), keys + 1)


func test_resume_is_ignored_unless_paused() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	_resume(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)


func test_focus_loss_pauses_once() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_eq(_paused, [true] as Array[bool], "a tab switch (blur + hidden) pauses once")


func test_focus_lost_signal_is_connected() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	WebPlatform.focus_lost.emit()
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)


func test_focus_loss_during_countdown_returns_to_the_panel() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	_resume(frame)
	_countdown(frame).call("_process", 0.5)
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_false(_countdown(frame).visible, "countdown cancelled")
	assert_true(_panel(frame).call("is_open"))
	_resume(frame)
	_run_countdown(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING, "still resumes to RUNNING")


func test_focus_loss_while_waiting_does_nothing() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(_paused, [] as Array[bool])


func test_pause_while_waiting_resumes_to_waiting() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	frame._unhandled_input(_esc())
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	_resume(frame)
	_run_countdown(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(_paused, [true, false] as Array[bool])
	frame._process(3.0)
	assert_eq(frame.get_elapsed(), 0.0, "the clock is not started")
	assert_true((_hud(frame).get_node("%StartPrompt") as Control).visible)
	_type_correct(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	frame._process(0.5)
	assert_eq(frame.get_elapsed(), 0.5)


func test_quit_commits_brains_and_goes_to_the_menu_once() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var before: int = data.get_brains()
	var frame: RunFrameScript = _start_pausable(data)
	for i: int in 4:
		_type_correct(frame)
	assert_eq(frame.get_level().get_brains_earned(), 1)
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(data.get_brains(), before + 1, "brains kept, no bonus")
	assert_ne(frame.get_state(), RunFrameScript.RunState.DONE)
	_panel(frame).emit_signal("quit_chosen")
	frame._unhandled_input(_esc())
	frame.call("_on_web_platform_focus_lost")
	_resume(frame)
	_run_countdown(frame)
	frame._process(300.0)
	assert_eq(_nav.size(), 1, "one navigation, never a report card")
	assert_eq(data.get_brains(), before + 1, "brains committed once")
	assert_eq(_paused, [true] as Array[bool], "the Router unpauses after its swap, not the run")


func test_quit_guards_hold_outside_the_paused_state() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var before: int = data.get_brains()
	var frame: RunFrameScript = _running_frame(data)
	# A stray quit_chosen while RUNNING must not commit brains or navigate.
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_nav.size(), 0)
	assert_eq(data.get_brains(), before)
	# After Quit the pause sources are ignored even in a live state (the guard, not the state, stops them).
	frame.set("_quitting", true)
	frame._unhandled_input(_esc())
	frame.get_node("%Hud").emit_signal("pause_pressed")
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(_paused, [] as Array[bool])
	# Toggles are ignored after Quit.
	_panel(frame).emit_signal("music_toggled", false)
	assert_true(data.get_setting(&"music_on"), "setting untouched after Quit")
	_restore_audio()


func test_run_frame_pauses_with_the_tree() -> void:
	# Esc during the countdown is ignored because the tree is paused: RunFrame must not opt out of it.
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	assert_eq(frame.process_mode, Node.PROCESS_MODE_INHERIT)
	frame.free()


func test_quit_with_no_brains_is_fine() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var before: int = data.get_brains()
	var frame: RunFrameScript = _start_pausable(data)
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(data.get_brains(), before)


func test_toggles_mute_and_save() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var frame: RunFrameScript = _running_frame(data)
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("music_toggled", false)
	assert_true(AudioManager.is_music_muted())
	assert_false(data.get_setting(&"music_on"))
	_panel(frame).emit_signal("sound_toggled", false)
	assert_true(AudioManager.is_sfx_muted())
	assert_false(data.get_setting(&"sound_on"))
	_resume(frame)
	_run_countdown(frame)
	frame._unhandled_input(_esc())
	assert_false((_panel(frame).get_node("%MusicToggle") as MenuToggle).is_on(), "reopened with the saved value")
	assert_false((_panel(frame).get_node("%SoundToggle") as MenuToggle).is_on())
	_panel(frame).emit_signal("music_toggled", true)
	assert_false(AudioManager.is_music_muted())
	assert_true(data.get_setting(&"music_on"))
	_restore_audio()


func test_clean_resume_focus_and_caps_hint() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	for c: String in ["q", "w", "e"]:
		_input_node(frame).handle_key(_capital(c))
	var hint: Control = _hud(frame).get_node("%CapsHint") as Control
	assert_true(hint.visible)
	frame._unhandled_input(_esc())
	_resume(frame)
	_run_countdown(frame)
	var owner: Control = get_viewport().gui_get_focus_owner()
	assert_true(owner == null or not _panel(frame).is_ancestor_of(owner), "no panel button keeps focus")
	assert_false(hint.visible, "Caps hint reset on resume")
	_input_node(frame).handle_key(_capital("r"))
	assert_false(hint.visible, "the streak restarted: one capital is not enough")
	_input_node(frame).handle_key(_capital("t"))
	_input_node(frame).handle_key(_capital("y"))
	assert_true(hint.visible, "3 new capitals bring the hint back")


func test_process_modes() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	assert_eq(_panel(frame).process_mode, Node.PROCESS_MODE_WHEN_PAUSED)
	assert_eq(_countdown(frame).process_mode, Node.PROCESS_MODE_WHEN_PAUSED)
	assert_eq(frame.get_node("%Hud").process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(frame.get_node("%LevelHost").process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(frame.get_node("%TypingInput").process_mode, Node.PROCESS_MODE_INHERIT)

## Calling _unhandled_input() by hand marks GUT's viewport input as handled, and headless no real
## event ever clears it. Pushing a no-op event resets the flag so later tests start clean.
func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


# --- run recording (Story 2.8) -------------------------------------------------

## A test-level run to DONE: 4 correct keys (1 brain), then the timer.
func _finish_run(frame: RunFrameScript) -> void:
	for i: int in 4:
		_type_correct(frame)
	frame._process(200.0)
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)


func test_finished_run_is_recorded_once_and_brains_added_once() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var frame: RunFrameScript = _start_pausable(data)
	_finish_run(frame)
	for i: int in 3:
		frame._process(1.0)
	var history: Array = data.save_service.get_active_profile()["run_history"]
	assert_eq(history.size(), 1)
	assert_eq(history[0], _result().to_record())
	assert_eq(data.get_brains(), 1, "level brains added once")


## A short run (3 s, ended by the level) so the WPM is above 0.
func _finish_short_run(frame: RunFrameScript) -> void:
	for i: int in 4:
		_type_correct(frame)
	frame._process(3.0)
	frame.get_level().end_requested.emit(GameConstants.END_REASON_CAUGHT)
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)


func test_first_run_payload_says_not_a_new_best() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	_finish_short_run(frame)
	var payload: Dictionary = _nav[0][1]
	assert_gt(_result().wpm, 0, "a 0-WPM run would be 'not a new best' whatever the rule")
	assert_true(payload.has("new_best"))
	assert_false(payload["new_best"])
	assert_not_null(payload["result"])


func test_run_is_recorded_on_ending_before_the_outro() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var frame: RunFrameScript = _start_pausable(data)
	for i: int in 4:
		_type_correct(frame)
	frame._process(3.0)
	frame.get_level().end_requested.emit(GameConstants.END_REASON_CAUGHT)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(data.save_service.get_active_profile()["run_history"].size(), 1, "saved before the outro")
	assert_eq(data.get_brains(), 1)
	assert_eq(_nav.size(), 0, "the report card waits for the outro")
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_nav.size(), 1)
	assert_eq(data.save_service.get_active_profile()["run_history"].size(), 1, "recorded once")
	assert_eq(data.save_service.get_active_profile()["run_history"][0], _result().to_record())


func test_payload_says_new_best_when_the_saved_best_is_lower() -> void:
	var data: PlayerDataScript = _fake_player_data()
	data.save_service.get_active_profile()["best_wpm"]["test_level"] = 1
	var frame: RunFrameScript = _start_pausable(data)
	_finish_short_run(frame)
	assert_gt(_result().wpm, 1)
	assert_true(_nav[0][1]["new_best"])
	assert_eq(int(data.save_service.get_active_profile()["best_wpm"]["test_level"]), _result().wpm)


func test_quit_records_no_run() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var frame: RunFrameScript = _start_pausable(data)
	for i: int in 4:
		_type_correct(frame)
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	var profile: Dictionary = data.save_service.get_active_profile()
	assert_eq(profile["run_history"].size(), 0)
	assert_false(profile["best_wpm"].has("test_level"))
	assert_eq(data.get_brains(), 1, "brains still committed once")


# --- debug hooks (Story 2.10) -------------------------------------------------

func _start_release(payload: Dictionary) -> RunFrameScript:
	var frame: RunFrameScript = _make(payload)
	frame.is_debug_build = func() -> bool: return false
	add_child_autofree(frame)
	return frame


## Pins seed on test_level, as F2 in the overlay does.
func _pin(seed: int) -> void:
	RunFrameScript.debug_seed = seed
	RunFrameScript.debug_seed_level = &"test_level"


func test_last_seed_is_the_started_frames_seed() -> void:
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	assert_eq(RunFrameScript.last_seed, 42)
	assert_eq(RunFrameScript.last_seed_level, &"test_level")
	var random: RunFrameScript = _start({"level_id": &"test_level"})
	assert_eq(RunFrameScript.last_seed, random.get_seed())
	assert_false(frame.is_replay())


func test_pinned_debug_seed_replays_a_payload_without_seed() -> void:
	var expected: Array[String] = _targets(777, 20)
	_pin(777)
	var frame: RunFrameScript = _start({"level_id": &"test_level"})
	assert_eq(frame.get_seed(), 777)
	assert_true(frame.is_replay())
	assert_eq(RunFrameScript.last_seed, 777)
	var got: Array[String] = []
	for i: int in 20:
		got.append(_type_correct(frame))
	assert_eq(got, expected)


func test_payload_seed_wins_over_the_pinned_seed() -> void:
	_pin(777)
	var frame: RunFrameScript = _start({"level_id": &"test_level", "seed": 42})
	assert_eq(frame.get_seed(), 42)
	assert_false(frame.is_replay())
	var random: RunFrameScript = _start({"level_id": &"test_level", "seed": -1})
	assert_false(random.is_replay(), "an explicit -1 means random, not the pinned seed")


func test_pinned_seed_is_ignored_on_another_level() -> void:
	_pin(777)
	var registry: LevelRegistry = LevelRegistry.new()
	var entry: LevelEntry = LevelEntry.new()
	entry.id = &"other_level"
	entry.scene = load("res://scenes/levels/test_level/test_level.tscn") as PackedScene
	registry.entries = [entry]
	var frame: RunFrameScript = _start({"level_id": &"other_level"}, registry)
	assert_false(frame.is_replay())
	# 1 in 2^32 that randi() picks 777 by chance.
	assert_ne(frame.get_seed(), 777)
	assert_eq(RunFrameScript.last_seed_level, &"other_level")


func test_release_ignores_the_pinned_seed() -> void:
	_pin(777)
	var frame: RunFrameScript = _start_release({"level_id": &"test_level"})
	assert_false(frame.is_replay())
	assert_true(frame.get_seed() >= 0)
	# 1 in 2^32 that randi() picks 777 by chance.
	assert_ne(frame.get_seed(), 777)


func test_release_refuses_the_debug_end_run() -> void:
	var frame: RunFrameScript = _start_release({"level_id": &"test_level", "seed": 42})
	_type_correct(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_false(frame.debug_end_run())
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(_nav, [])


func test_debug_end_run_ends_like_the_timer() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var frame: RunFrameScript = _start_pausable(data)
	for i: int in 4:
		_type_correct(frame)
	frame._process(12.5)
	assert_true(frame.debug_end_run())
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(data.save_service.get_active_profile()["run_history"].size(), 1, "recorded on ENDING")
	assert_false(frame.debug_end_run(), "a second call does nothing")
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_nav.size(), 1)
	assert_eq(_nav[0][0], Router.Screen.REPORT_CARD)
	var result: RunResult = _result()
	assert_eq(result.end_reason, GameConstants.END_REASON_TIMER)
	assert_eq(result.duration_s, 12.5, "the elapsed time so far, not the level duration")
	assert_eq(result.keys_typed, 4)
	assert_false(frame.debug_end_run(), "nothing after DONE")


func test_debug_end_run_on_a_no_timer_level_keeps_the_elapsed_time() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	frame._duration = 0.0
	for i: int in 3:
		_type_correct(frame)
	frame._process(7.5)
	assert_true(frame.debug_end_run())
	frame._process(1.0)
	assert_eq(_result().duration_s, 7.5, "a no-timer level has no duration to clamp to")


func test_debug_end_run_is_refused_outside_running() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	assert_false(frame.debug_end_run())
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	_type_correct(frame)
	frame._process(2.0)
	frame._unhandled_input(_esc())
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_false(frame.debug_end_run())
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	_resume(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.COUNTDOWN)
	assert_false(frame.debug_end_run())
	assert_eq(frame.get_state(), RunFrameScript.RunState.COUNTDOWN)
	assert_eq(_nav, [])


func test_level_id_and_duration_getters() -> void:
	var frame: RunFrameScript = _start({"level_id": "test_level", "seed": 1})
	assert_eq(frame.get_level_id(), &"test_level")
	assert_eq(frame.get_duration(), 120.0)


# --- Zombie Run through the real run frame (Story 3.1) -----------------------

const ZombieRunLevelScript := preload("res://scripts/levels/zombie_run/zombie_run_level.gd")


func _zombie_queue_letter(frame: RunFrameScript) -> String:
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	return level.get_queue()[0].get_letter()


func test_zombie_run_loads_and_matches_the_hud() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	assert_eq(_nav, [], "no failed-load navigation")
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	assert_not_null(level, "the Zombie Run level is loaded")
	assert_eq(frame.get_level_id(), &"zombie_run")
	assert_eq(_zombie_queue_letter(frame), frame.get_session().get_current_target())
	assert_eq(_hud_text(frame, "%TargetLabel"), _zombie_queue_letter(frame), "HUD letter = arrowed target")


func test_zombie_run_keys_and_timer_end() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	_type_correct(frame)
	assert_eq(level.get_active_index(), 1, "advanced in the same call")
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(_zombie_queue_letter(frame), frame.get_session().get_current_target())
	var letters: Array[String] = []
	for target: ZombieRunTarget in level.get_queue():
		letters.append(target.get_letter())
	_type_wrong(frame)
	assert_eq(frame.get_session().get_errors(), 1)
	assert_eq(level.get_active_index(), 1, "a wrong key changes nothing")
	var after: Array[String] = []
	for target: ZombieRunTarget in level.get_queue():
		after.append(target.get_letter())
	assert_eq(after, letters)
	for i: int in 3:
		_type_correct(frame)
	frame._process(121.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	frame._process(1.9)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING, "still dancing at 1.9 s")
	assert_eq(_nav, [], "no report card before the dance ends")
	frame._process(0.2)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE, "the 2.0 s dance is over")
	assert_eq(_nav.size(), 1)
	assert_eq(_nav[0][0], Router.Screen.REPORT_CARD)
	var result: RunResult = _result()
	assert_eq(result.level_id, &"zombie_run")
	assert_eq(result.keys_typed, 4)
	assert_eq(result.errors, 1)
	assert_eq(result.duration_s, 120.0)
	assert_eq(result.brains, 1, "one brain block per group of 4: Story 3.2")
	var bonus: int = frame.get_level().get_level_config().completion_bonus
	assert_gt(bonus, 0, "Zombie Run pays a completion bonus")
	assert_eq(result.bonus_brains, bonus, "the bonus comes from the level config (Story 3.5)")


# --- Zombie Run brains (Story 3.2) -------------------------------------------

func test_zombie_run_brain_counter_follows_brain_blocks() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), "0")
	for i: int in 8:
		if level.get_brains_earned() == 1:
			break
		_type_correct(frame)
		if level.get_brains_earned() == 1:
			assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), "1", "the HUD shows it in the same call")
	assert_eq(level.get_brains_earned(), 1)
	for i: int in 4:
		_type_correct(frame)
	assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), str(level.get_brains_earned()))


func test_zombie_run_quit_commits_the_level_brains() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var before: int = data.get_brains()
	var frame: RunFrameScript = _make({"level_id": &"zombie_run", "seed": 42}, null, data)
	add_child_autofree(frame)
	for i: int in 12:
		_type_correct(frame)
	var earned: int = frame.get_level().get_brains_earned()
	assert_eq(earned, 3, "12 keys = 3 groups = 3 brains")
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(data.get_brains(), before + earned, "brains kept, no bonus (FR13)")
	assert_eq(data.save_service.get_active_profile()["run_history"].size(), 0, "a quit records nothing")


# --- Zombie Run villagers (Story 3.3) ----------------------------------------

func test_zombie_run_villager_key_hugs_and_pays_nothing() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	for i: int in 8:
		if level.get_queue()[0] is Villager:
			break
		_type_correct(frame)
	var villager: Villager = level.get_queue()[0] as Villager
	assert_not_null(villager, "a villager within the first group")
	var brains: int = level.get_brains_earned()
	_type_correct(frame)
	assert_eq(villager.get_state(), Villager.State.HUGGED)
	assert_ne(level.get_queue()[0], villager, "the queue head moved on")
	assert_eq(_zombie_queue_letter(frame), frame.get_session().get_current_target())
	assert_eq(level.get_brains_earned(), brains, "villagers pay nothing")


# --- Zombie Run conga line (Story 3.4) ----------------------------------------

func _finish_villager_poofs(level: ZombieRunLevelScript) -> void:
	for node: Node in level.get_node("%Targets").get_children():
		var villager: Villager = node as Villager
		if villager == null or villager.get_state() == Villager.State.WAITING:
			continue
		if villager.is_party_zombie_shown():
			continue
		villager.get_sequence_tween().custom_step(1.0)
		for child: Node in villager.get_children():
			if child is Poof:
				(child as Poof).get_tween().custom_step(1.0)


func _conga_snapshot(level: ZombieRunLevelScript) -> Array:
	var line: CongaLine = level.get_conga_line()
	return [level.get_conga_count(), line.get_joined_count(), line.get_followers()]


func test_zombie_run_pause_and_resume_keep_the_conga_line() -> void:
	var frame: RunFrameScript = _make({"level_id": &"zombie_run", "seed": 42}, null, _fake_player_data())
	add_child_autofree(frame)
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	for i: int in 8:
		_type_correct(frame)
	_finish_villager_poofs(level)
	assert_gt(level.get_conga_line().get_joined_count(), 1, "2+ villagers in the line")
	var before: Array = _conga_snapshot(level)
	frame._unhandled_input(_esc())
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	_type_wrong(frame)
	assert_eq(_conga_snapshot(level), before, "paused: unchanged")
	_resume(frame)
	_run_countdown(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(_conga_snapshot(level), before, "resumed: nothing lost")
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_eq(_conga_snapshot(level), before, "a focus-loss pause loses nothing either")


# --- Zombie Run end dance and brains award (Story 3.5) -------------------------

## The level state a key could change, for "nothing changes" checks.
func _zombie_snapshot(frame: RunFrameScript) -> Array:
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	var session: TypingSession = frame.get_session()
	return [
		session.get_keys_typed(), session.get_errors(), level.get_active_index(),
		level.get_brains_earned(), level.get_conga_count(), level.get_conga_line().get_joined_count(),
	]


func test_zombie_run_end_rejects_keys_and_dances() -> void:
	var frame: RunFrameScript = _make({"level_id": &"zombie_run", "seed": 42}, null, _fake_player_data())
	add_child_autofree(frame)
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	for i: int in 8:
		_type_correct(frame)
	frame._process(121.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_true(level.is_dancing(), "the level dances on ENDING")
	var before: Array = _zombie_snapshot(frame)
	var target: String = frame.get_session().get_current_target()
	assert_false(_send(frame, target), "a correct key is not judged")
	assert_false(_send(frame, "b" if target == "a" else "a"), "a wrong key is not judged")
	assert_eq(_zombie_snapshot(frame), before, "keys, errors, targets, brains and conga unchanged")


func test_zombie_run_completed_run_pays_the_bonus_once() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var wallet: int = data.get_brains()
	var frame: RunFrameScript = _make({"level_id": &"zombie_run", "seed": 42}, null, data)
	add_child_autofree(frame)
	var level: ZombieRunLevelScript = frame.get_level() as ZombieRunLevelScript
	for i: int in 20:
		if level.get_brains_earned() > 0:
			break
		_type_correct(frame)
	var brains: int = level.get_brains_earned()
	assert_gt(brains, 0, "1+ brain block collected")
	var bonus: int = level.get_level_config().completion_bonus
	frame._process(121.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(data.get_brains(), wallet + brains + bonus, "paid on entering ENDING, before the dance")
	var history: Array = data.save_service.get_active_profile()["run_history"]
	assert_eq(history.size(), 1)
	assert_eq(int(history[0]["brains"]), brains + bonus, "the record holds the total")
	for i: int in 5:
		frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(data.get_brains(), wallet + brains + bonus, "paid once")
	assert_eq(data.save_service.get_active_profile()["run_history"].size(), 1, "recorded once")
	assert_eq(_result().brains, brains)
	assert_eq(_result().bonus_brains, bonus)
	assert_eq(_result().total_brains(), brains + bonus, "the report card's Brains Collected")


func test_zombie_run_debug_end_pays_the_bonus() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	_type_correct(frame)
	frame._process(5.0)
	assert_true(frame.debug_end_run())
	frame._process(2.1)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_result().bonus_brains, frame.get_level().get_level_config().completion_bonus, "F6 = the timer path")


func test_zombie_run_pause_is_refused_while_dancing() -> void:
	var frame: RunFrameScript = _make({"level_id": &"zombie_run", "seed": 42}, null, _fake_player_data())
	add_child_autofree(frame)
	_type_correct(frame)
	frame._process(121.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	frame._unhandled_input(_esc())
	frame.get_node("%Hud").emit_signal("pause_pressed")
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(_paused, [] as Array[bool], "the tree is never paused")
	assert_false(_panel(frame).call("is_open"))
	frame._process(2.1)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_nav.size(), 1)
	assert_eq(_nav[0][0], Router.Screen.REPORT_CARD, "the report card still arrives after the dance")


func test_zombie_run_play_again_starts_fresh() -> void:
	var first: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	var first_level: ZombieRunLevelScript = first.get_level() as ZombieRunLevelScript
	for i: int in 12:
		_type_correct(first)
	_finish_villager_poofs(first_level)
	assert_gt(first_level.get_conga_line().get_joined_count(), 0, "the first run had a line")
	first._process(121.0)
	first._process(2.1)
	assert_eq(_nav.size(), 1)
	var level_id: StringName = _result().level_id
	assert_eq(level_id, &"zombie_run")
	# What the report card's Play Again sends: the level id, no seed.
	var second: RunFrameScript = _start({"level_id": level_id})
	var level: ZombieRunLevelScript = second.get_level() as ZombieRunLevelScript
	assert_not_null(level)
	assert_ne(level, first_level, "a new level instance")
	assert_ne(second.get_seed(), 42, "a new random seed")
	assert_false(second.is_replay())
	assert_eq(second.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(second.get_elapsed(), 0.0)
	assert_eq(level.get_active_index(), 0)
	assert_eq(level.get_brains_earned(), 0)
	assert_eq(level.get_conga_count(), 0)
	assert_eq(level.get_conga_line().get_joined_count(), 0)
	assert_eq(level.get_conga_line().get_drawn_count(), 0)
	assert_false(level.get_conga_line().is_badge_shown())
	assert_false(level.is_dancing())


# --- ambience on/off (Story 3.7, FR48) ---------------------------------------
# set_ambience is a recorder in every test but the last; _ambience lists its calls in order.

func test_ambience_starts_on_the_first_correct_key() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	frame._process(2.0)
	assert_eq(_ambience, [] as Array[bool], "no groans while waiting for the first key")
	_type_wrong(frame)
	_type_wrong(frame)
	assert_eq(_ambience, [] as Array[bool], "wrong keys do not start the run")
	_type_correct(frame)
	assert_eq(_ambience, [true] as Array[bool])
	_type_correct(frame)
	_type_wrong(frame)
	assert_eq(_ambience, [true] as Array[bool], "keys never touch ambience once running")


func test_ambience_stops_on_every_pause_and_restarts_after_the_countdown() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	assert_eq(_ambience, [true, false] as Array[bool], "Esc")
	_resume(frame)
	assert_eq(_ambience, [true, false] as Array[bool], "no groans during the countdown")
	frame.call("_on_web_platform_focus_lost")
	assert_eq(_ambience, [true, false] as Array[bool], "focus loss during the countdown adds nothing")
	_resume(frame)
	_run_countdown(frame)
	assert_eq(_ambience, [true, false, true] as Array[bool], "back on at RUNNING")
	frame.get_node("%Hud").emit_signal("pause_pressed")
	assert_eq(_ambience, [true, false, true, false] as Array[bool], "pause button")
	_resume(frame)
	_run_countdown(frame)
	frame.call("_on_web_platform_focus_lost")
	assert_eq(_ambience, [true, false, true, false, true, false] as Array[bool], "focus loss")


func test_pause_while_waiting_never_starts_ambience() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	frame._unhandled_input(_esc())
	_resume(frame)
	_run_countdown(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(_ambience, [] as Array[bool])
	_type_correct(frame)
	assert_eq(_ambience, [true] as Array[bool])


func test_ambience_stops_at_the_timer_end_and_stays_off() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._process(200.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(_ambience, [true, false] as Array[bool])
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_ambience, [true, false] as Array[bool], "no groans during the outro or after")


func test_ambience_stops_on_debug_end_run() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	assert_true(frame.debug_end_run())
	frame._process(1.0)
	assert_eq(_ambience, [true, false] as Array[bool])


func test_ambience_stops_on_end_requested() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame.get_level().end_requested.emit(GameConstants.END_REASON_CAUGHT)
	frame._process(1.0)
	assert_eq(_ambience, [true, false] as Array[bool])


func test_quit_from_pause_adds_no_ambience_call() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_ambience, [true, false] as Array[bool])
	remove_child(frame)
	frame.free()
	assert_eq(_ambience, [true, false] as Array[bool], "already off: freeing adds nothing")


func test_frame_freed_while_running_stops_ambience() -> void:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 42})
	add_child(frame)
	_type_correct(frame)
	remove_child(frame)
	frame.free()
	assert_eq(_ambience, [true, false] as Array[bool])


func test_frame_freed_while_waiting_adds_no_ambience_call() -> void:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 42})
	add_child(frame)
	remove_child(frame)
	frame.free()
	assert_eq(_ambience, [] as Array[bool])


func test_zombie_run_ambience_on_and_off() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	_type_correct(frame)
	assert_eq(_ambience, [true] as Array[bool])
	frame._process(121.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	assert_eq(_ambience, [true, false] as Array[bool], "no groans during the dance")


func test_default_ambience_seam_drives_the_audio_manager() -> void:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 42})
	frame.set_ambience = Callable()
	add_child(frame)
	assert_false(AudioManager.is_ambience_on(), "waiting: off")
	_type_correct(frame)
	assert_true(AudioManager.is_ambience_on(), "RUNNING: on")
	frame._unhandled_input(_esc())
	assert_false(AudioManager.is_ambience_on(), "paused: off")
	_resume(frame)
	_run_countdown(frame)
	assert_true(AudioManager.is_ambience_on(), "resumed: on")
	remove_child(frame)
	frame.free()
	assert_false(AudioManager.is_ambience_on(), "freed: off")
	assert_eq(_ambience, [] as Array[bool], "the recorder was not used")


# --- music and clicks (Story 5.1) ------------------------------------------------------------------
# play_music, duck_music and play_sfx are recorders in every test here but the last.

func test_zombie_run_asks_for_its_music_once_at_start() -> void:
	var frame: RunFrameScript = _start({"level_id": &"zombie_run", "seed": 42})
	assert_eq(_music, [&"mus_zombie_run"] as Array[StringName])
	_type_correct(frame)
	frame._process(121.0)
	frame._process(5.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_music, [&"mus_zombie_run"] as Array[StringName], "the loop plays on through the dance")


func test_test_level_never_asks_for_music() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	_type_correct(frame)
	frame._process(200.0)
	frame._process(5.0)
	assert_eq(_music, [] as Array[StringName], "an empty music_id leaves the music alone")


func test_failed_load_never_asks_for_music() -> void:
	_start({"level_id": &"nope"})
	assert_push_error("[ERROR][run]")
	assert_eq(_music, [] as Array[StringName])


func test_music_is_ducked_from_pause_until_the_countdown_ends() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	assert_eq(_duck, [] as Array[bool], "not ducked while running")
	frame._unhandled_input(_esc())
	assert_eq(_duck, [true] as Array[bool], "paused: ducked")
	_resume(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.COUNTDOWN)
	assert_eq(_duck, [true] as Array[bool], "still ducked during the countdown")
	_run_countdown(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_eq(_duck, [true, false] as Array[bool], "back to full when the run is live")


func test_pause_from_the_countdown_ducks_again() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	_resume(frame)
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_eq(_duck, [true, true] as Array[bool])
	_resume(frame)
	_run_countdown(frame)
	assert_eq(_duck, [true, true, false] as Array[bool])


func test_pause_while_waiting_unducks_back_in_waiting() -> void:
	var frame: RunFrameScript = _start_pausable(_fake_player_data())
	frame._unhandled_input(_esc())
	_resume(frame)
	_run_countdown(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(_duck, [true, false] as Array[bool])


func test_quit_to_menu_unducks_when_the_frame_leaves() -> void:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 42}, null, _fake_player_data())
	add_child(frame)
	_type_correct(frame)
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_duck, [true] as Array[bool])
	remove_child(frame)
	frame.free()
	assert_eq(_duck, [true, false] as Array[bool], "never left ducked behind the run")


func test_pause_clicks_for_esc_and_the_button_not_focus_loss() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName], "Esc")
	_resume(frame)
	_run_countdown(frame)
	_sfx.clear()
	frame.get_node("%Hud").emit_signal("pause_pressed")
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName], "pause button")
	_resume(frame)
	_run_countdown(frame)
	_sfx.clear()
	frame.call("_on_web_platform_focus_lost")
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_eq(_sfx, [] as Array[StringName], "focus loss is silent")


func test_pause_panel_clicks_once_per_press() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var frame: RunFrameScript = _running_frame(data)
	frame._unhandled_input(_esc())
	_sfx.clear()
	_panel(frame).emit_signal("music_toggled", false)
	assert_eq(_sfx.size(), 1, "Music toggle")
	_panel(frame).emit_signal("sound_toggled", false)
	assert_eq(_sfx.size(), 2, "Sound toggle")
	_resume(frame)
	assert_eq(_sfx.size(), 3, "Resume")
	_resume(frame)
	assert_eq(_sfx.size(), 3, "a Resume ignored in the countdown is silent")
	_run_countdown(frame)
	frame._unhandled_input(_esc())
	_sfx.clear()
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName], "Quit to Menu")
	_panel(frame).emit_signal("quit_chosen")
	_panel(frame).emit_signal("music_toggled", true)
	assert_eq(_sfx.size(), 1, "nothing after quitting")
	_restore_audio()


func test_esc_while_paused_does_not_click_twice() -> void:
	var frame: RunFrameScript = _running_frame(_fake_player_data())
	frame._unhandled_input(_esc())
	frame.get_node("%Hud").emit_signal("pause_pressed")
	assert_eq(_sfx.size(), 1, "already paused: no second click")


func test_default_music_seams_drive_the_audio_manager() -> void:
	var frame: RunFrameScript = _make({"level_id": &"test_level", "seed": 42})
	frame.play_music = Callable()
	frame.duck_music = Callable()
	frame.play_sfx = Callable()
	add_child(frame)
	assert_eq(frame.play_music, Callable(AudioManager.play_music))
	assert_eq(frame.duck_music, Callable(AudioManager.set_music_ducked))
	assert_eq(frame.play_sfx, Callable(AudioManager.play_sfx))
	_type_correct(frame)
	frame._unhandled_input(_esc())
	assert_true(AudioManager.is_music_ducked(), "paused: the live music is ducked")
	remove_child(frame)
	frame.free()
	assert_false(AudioManager.is_music_ducked(), "freed: un-ducked")


# --- word mode (Story 6.2): the real test_word_level --------------------------------

func _start_words() -> RunFrameScript:
	return _start({"level_id": &"test_word_level", "seed": 42})


## Types the current word letter by letter; returns it.
func _type_word(frame: RunFrameScript) -> String:
	var word: String = frame.get_session().get_current_target()
	for c: String in word:
		assert_true(_send(frame, c), "'%s' of '%s' handled" % [c, word])
	return word


func _space() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	event.unicode = 32
	return event


func test_word_level_starts_with_a_word() -> void:
	var frame: RunFrameScript = _start_words()
	var word: String = frame.get_session().get_current_target()
	assert_between(word.length(), 3, 5, "a 3-5 letter word: '%s'" % word)
	assert_eq(_hud_text(frame, "%TargetLabel"), word)
	assert_eq(_hud_text(frame, "%StartPromptLabel"), "Type the word to start!")
	assert_eq(_letter(frame), word)


func test_word_mid_word_letter_turns_green_in_the_same_call() -> void:
	var frame: RunFrameScript = _start_words()
	var word: String = frame.get_session().get_current_target()
	assert_true(_send(frame, word[0]))
	assert_eq(frame.get_session().get_cursor(), 1)
	assert_eq(_hud_text(frame, "%TargetLabel"), word, "still the same word")
	assert_eq(_hud_text(frame, "%TypedLabel"), word.left(1), "the first letter is green before handle_key returned")
	assert_true((_hud(frame).get_node("%NextUnderline") as Control).visible)


func test_word_completes_on_its_last_letter() -> void:
	var frame: RunFrameScript = _start_words()
	var first: String = frame.get_session().get_current_target()
	var next: String = frame.get_session().get_upcoming(1)[0]
	for i: int in first.length() - 1:
		_send(frame, first[i])
	assert_eq(frame.get_level().get_brains_earned(), 0)
	assert_true(_send(frame, first[first.length() - 1]))
	# All of this before handle_key returned.
	assert_eq(_hud_text(frame, "%TargetLabel"), next, "the next word, same call")
	assert_false((_hud(frame).get_node("%TypedLabel") as Control).visible, "0 typed")
	assert_eq(frame.get_session().get_cursor(), 0)
	assert_eq(frame.get_level().get_brains_earned(), 1, "on_target_completed ran")
	assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), "1")
	assert_eq(frame.get_session().get_implied_spaces(), 1)
	assert_eq(_letter(frame), next)
	assert_ne(next, first, "never the same word twice in a row")


func test_word_space_is_not_judged() -> void:
	var frame: RunFrameScript = _start_words()
	var word: String = frame.get_session().get_current_target()
	_send(frame, word[0])
	assert_false(_input_node(frame).handle_key(_space()), "Space is ignored")
	assert_eq(frame.get_session().get_errors(), 0)
	assert_eq(frame.get_session().get_cursor(), 1)
	assert_eq(frame.get_session().get_keys_typed(), 1)
	_hud(frame).call("_process", 0.05)
	assert_eq(_hud(frame).call("get_target_offset_x"), 0.0, "no shake")


func test_word_wrong_letter_mid_word_shakes_and_counts() -> void:
	var frame: RunFrameScript = _start_words()
	var word: String = frame.get_session().get_current_target()
	_send(frame, word[0])
	_send(frame, "q" if word[1] != "q" else "z")
	assert_eq(frame.get_session().get_errors(), 1)
	assert_eq(frame.get_session().get_cursor(), 1, "the cursor stays")
	assert_eq(_hud_text(frame, "%ErrorsValue"), "1")
	_hud(frame).call("_process", 0.05)
	assert_ne(_hud(frame).call("get_target_offset_x"), 0.0, "the word shakes")


func test_word_run_result_counts_implied_spaces() -> void:
	var frame: RunFrameScript = _start_words()
	var words: int = 4
	for i: int in words:
		_type_word(frame)
	var keys: int = frame.get_session().get_keys_typed()
	frame._process(30.0)
	assert_true(frame.debug_end_run())
	var duration: float = frame.get_elapsed()
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	var result: RunResult = _result()
	assert_eq(result.level_id, &"test_word_level")
	assert_eq(result.completed_words, words)
	assert_eq(result.keys_typed, keys)
	assert_eq(result.wpm, StatsCalculator.wpm(keys, duration, words))
	assert_eq(result.brains, words)


func test_word_live_wpm_counts_implied_spaces() -> void:
	var frame: RunFrameScript = _start_words()
	for i: int in 3:
		_type_word(frame)
	var keys: int = frame.get_session().get_keys_typed()
	frame._process(10.0)
	assert_eq(_hud_text(frame, "%WpmValue"), str(StatsCalculator.wpm(keys, 10.0, 3)))


# --- Horde Rush (Story 6.3): the real horde_rush level, hidden from the menu ----------------------

const HordeRushScript := preload("res://scripts/levels/horde_rush/horde_rush_level.gd")
## A seed whose 8 instant words let some copies past the defender within 12 s (Story 6.5).
const HORDE_ARRIVAL_SEED: int = 7


func test_horde_rush_spawns_a_copy_on_a_completed_word() -> void:
	var frame: RunFrameScript = _start({"level_id": &"horde_rush", "seed": 7})
	var level: HordeRushScript = frame.get_level() as HordeRushScript
	assert_not_null(level, "the horde rush level is running")
	assert_eq(frame.get_duration(), 300.0)
	assert_eq(_hud_text(frame, "%StartPromptLabel"), "Type the word to start!")
	var word: String = frame.get_session().get_current_target()
	assert_between(word.length(), 3, 5, word)
	for i: int in word.length() - 1:
		_send(frame, word[i])
	assert_false(_input_node(frame).handle_key(_space()), "Space is ignored")
	assert_eq(frame.get_session().get_errors(), 0)
	assert_eq(level.get_view_count(), 0)
	assert_true(_send(frame, word[word.length() - 1]))
	# No await since the last key: the copy exists in the key's own call.
	assert_eq(level.get_field().get_marching().size(), 1)
	assert_eq(level.get_view_count(), 1)
	assert_eq(level.get_field().get_marching()[0].word, word)


func test_horde_rush_end_freezes_and_pays_the_bonus() -> void:
	var frame: RunFrameScript = _start({"level_id": &"horde_rush", "seed": 7})
	var level: HordeRushScript = frame.get_level() as HordeRushScript
	_type_word(frame)
	_type_word(frame)
	frame._process(5.0)
	assert_true(frame.debug_end_run())
	assert_true(level.is_frozen())
	frame._process(1.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING, "the 2 s outro is still dancing")
	frame._process(1.01)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	var result: RunResult = _result()
	assert_eq(result.level_id, &"horde_rush")
	assert_eq(result.completed_words, 2)
	assert_eq(result.brains, 0, "no copy reached the house in 5 s (a small crossing is 8 s)")
	assert_eq(result.bonus_brains, 25)
	assert_eq(result.total_brains(), 25)


## Types `words` words on a horde_rush run (the first key starts the defender), then marches the level
## for `seconds` of logic. The frame is disabled, so the level's own _process is driven by hand.
func _horde_arrivals(frame: RunFrameScript, words: int, seconds: float) -> HordeRushScript:
	var level: HordeRushScript = frame.get_level() as HordeRushScript
	level.request_voice = func(_id: StringName) -> void: pass
	for i: int in words:
		_type_word(frame)
	for i: int in roundi(seconds * 30.0):
		level._process(1.0 / 30.0)
	return level


func test_horde_rush_arrivals_reach_the_hud_and_the_result() -> void:
	var frame: RunFrameScript = _start({"level_id": &"horde_rush", "seed": HORDE_ARRIVAL_SEED})
	var level: HordeRushScript = frame.get_level() as HordeRushScript
	watch_signals(level)
	_horde_arrivals(frame, 8, 12.0)
	var earned: int = level.get_brains_earned()
	assert_gt(earned, 0, "some copies got past the defender on this seed")
	var emits: int = get_signal_emit_count(level, "brains_earned_changed")
	assert_gt(emits, 0)
	assert_eq(get_signal_parameters(level, "brains_earned_changed", emits - 1), [earned])
	assert_eq(_hud_text(frame, "%BrainCounter/%CountLabel"), str(earned), "the HUD counter follows")
	assert_true(frame.debug_end_run())
	frame._process(2.01)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	var result: RunResult = _result()
	assert_eq(result.brains, earned)
	assert_eq(result.bonus_brains, 25)


func test_horde_rush_quit_keeps_the_arrival_brains_without_a_bonus() -> void:
	var data: PlayerDataScript = _fake_player_data()
	var before: int = data.get_brains()
	var frame: RunFrameScript = _make({"level_id": &"horde_rush", "seed": HORDE_ARRIVAL_SEED}, null, data)
	add_child_autofree(frame)
	var level: HordeRushScript = _horde_arrivals(frame, 8, 12.0)
	var earned: int = level.get_brains_earned()
	assert_gt(earned, 0)
	frame._unhandled_input(_esc())
	_panel(frame).emit_signal("quit_chosen")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(data.get_brains(), before + earned, "arrival brains kept, no bonus (FR13)")
	assert_eq(data.save_service.get_active_profile()["run_history"].size(), 0, "a quit records nothing")


func test_horde_rush_defender_paces_after_the_first_key_and_stops_on_pause() -> void:
	var frame: RunFrameScript = _make({"level_id": &"horde_rush", "seed": 7}, null, _fake_player_data())
	# This test lets the real tree pause, so the level's own _process proves the freeze.
	frame.pause_tree = func(paused: bool) -> void:
		_paused.append(paused)
		get_tree().paused = paused
	add_child_autofree(frame)
	var level: HordeRushScript = frame.get_level() as HordeRushScript
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	await wait_process_frames(3)
	assert_eq(level.get_defender().position(), 0.0, "still before the first key")
	_type_word(frame)
	assert_true(level.is_defender_running())
	await wait_process_frames(5)
	var moved: float = level.get_defender().position()
	assert_gt(moved, 0.0, "pacing after the first key")
	frame._unhandled_input(_esc())
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	assert_true(get_tree().paused)
	var paused_at: float = level.get_defender().position()
	await wait_process_frames(5)
	assert_eq(level.get_defender().position(), paused_at, "paused: it stands still")
	_resume(frame)
	_run_countdown(frame)
	assert_false(get_tree().paused, "the countdown unpaused the tree")
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	await wait_process_frames(3)
	assert_gt(level.get_defender().position(), paused_at, "paces again")
	assert_true(frame.debug_end_run())
	assert_false(level.is_defender_running())
	frame._process(2.01)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)
	assert_eq(_result().brains, level.get_brains_earned())
