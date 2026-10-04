extends GutTest
## Run frame (Story 2.4): state machine, clock, level calls, run end, seed replay, failed loads.
## Instances are disabled (no engine _process, no real keys): tests call _process(delta) and
## %TypingInput.handle_key(event) by hand. navigate is a recorder, so the live Router never swaps
## GUT's scene.

const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")

var _nav: Array = []


func before_each() -> void:
	assert_false(WebPlatform.capture_keys, "a run frame left capture_keys on")
	_nav = []


func after_each() -> void:
	Router.take_payload()


func after_all() -> void:
	assert_false(WebPlatform.capture_keys, "a run frame left capture_keys on")


func _record(screen: int, payload: Dictionary) -> void:
	_nav.append([screen, payload])


func _make(payload: Dictionary, registry: LevelRegistry = null) -> RunFrameScript:
	Router._store_payload(payload)
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.navigate = _record
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
