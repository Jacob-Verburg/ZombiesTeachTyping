extends GutTest
## Run frame (Story 2.4): state machine, clock, level calls, run end, seed replay, failed loads.
## Debug hooks (Story 2.10): last_seed, pinned debug_seed, debug_end_run, the is_debug_build seam.
## Instances are disabled (no engine _process, no real keys): tests call _process(delta) and
## %TypingInput.handle_key(event) by hand. navigate is a recorder, so the live Router never swaps
## GUT's scene.

const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")

var _nav: Array = []
## pause_tree recorder (Story 2.7): GUT's own tree is never paused.
var _paused: Array[bool] = []


func before_each() -> void:
	assert_false(WebPlatform.capture_keys, "a run frame left capture_keys on")
	_nav = []
	_paused = []


func after_each() -> void:
	Router.take_payload()
	_restore_audio()
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
	assert_eq((_panel(frame).get_node("%MusicToggle") as Button).text, "Music: off", "reopened with the saved value")
	assert_eq((_panel(frame).get_node("%SoundToggle") as Button).text, "Sound: off")
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
	frame._process(0.016)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE, "no outro until Story 3.5")
	assert_eq(_nav.size(), 1)
	assert_eq(_nav[0][0], Router.Screen.REPORT_CARD)
	var result: RunResult = _result()
	assert_eq(result.level_id, &"zombie_run")
	assert_eq(result.keys_typed, 4)
	assert_eq(result.errors, 1)
	assert_eq(result.duration_s, 120.0)
	assert_eq(result.brains, 0, "brain blocks arrive in Story 3.2")
	assert_eq(result.bonus_brains, 0, "completion bonus wiring is Story 3.5")
