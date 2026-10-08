extends GutTest
## Debug overlay (Story 1.8): F3 toggle, cheats only while open, F8 two-step confirm, F9 export,
## never blocks the mouse, save-age text. A fresh SaveService (save_dir = TEST_DIR, download seam
## recorded) and a fresh PlayerData are injected before add_child, so the real save is never touched.
## Keys go through _handle_key() directly (no synthetic InputEvent plumbing).
## Story 2.10: run section, F2 seed pin, F6 end run, F7 typing log. Run frames are built like
## test_run_frame.gd (disabled, recorder navigate / pause_tree, a PlayerData on the temp save) and
## reached through the find_run_frame seam.
## Story 3.4: the run-worst frame time, driven through the pure _note_run_frame() bookkeeping.
## Story 4.2: the jump row, through the navigate / current_screen seams (the live Router never swaps).
## Story 6.7: F4 stress hold on a real, disabled Horde Rush run frame (the level's stress floor).

const OverlayScene: PackedScene = preload("res://scenes/debug/debug_overlay.tscn")
const OverlayScript := preload("res://scripts/debug/debug_overlay.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const TEST_DIR: String = "user://test_debug_overlay/"

var _save: SaveServiceScript = null
var _player: PlayerDataScript = null
var _downloads: Array[String] = []
var _frame: RunFrameScript = null
var _nav: Array = []
var _jumps: Array = []
var _screen: Router.Screen = Router.Screen.MAIN_MENU


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_downloads = []
	_jumps = []
	_screen = Router.Screen.MAIN_MENU


func after_each() -> void:
	_clear()
	_save = null
	_player = null
	_frame = null
	_nav = []
	Router.take_payload()
	Log.verbose_typing = false
	RunFrameScript.debug_seed = -1
	RunFrameScript.debug_seed_level = &""
	RunFrameScript.last_seed = -1
	RunFrameScript.last_seed_level = &""


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _record_download(_bytes: PackedByteArray, file_name: String) -> void:
	_downloads.append(file_name)


func _make() -> OverlayScript:
	_save = SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	_save.offer_download = _record_download
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)
	var sut: OverlayScript = OverlayScene.instantiate() as OverlayScript
	sut.player_data = _player
	sut.save_service = _save
	sut.find_run_frame = func() -> Node: return _frame
	sut.navigate = func(screen: int, payload: Dictionary) -> void: _jumps.append([screen, payload])
	sut.current_screen = func() -> Router.Screen: return _screen
	add_child_autofree(sut)
	return sut


## A disabled test-level run frame on the temp save; the overlay finds it through find_run_frame.
func _start_frame(payload: Dictionary = {"level_id": &"test_level", "seed": 42}) -> RunFrameScript:
	Router._store_payload(payload)
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.navigate = func(screen: int, data: Dictionary) -> void: _nav.append([screen, data])
	frame.pause_tree = func(_paused: bool) -> void: pass
	frame.set_ambience = func(_on: bool) -> void: pass
	frame.player_data = _player
	add_child_autofree(frame)
	_frame = frame
	return frame


func _type_correct(frame: RunFrameScript) -> void:
	var target: String = frame.get_session().get_current_target()
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.unicode = target.unicode_at(0)
	event.keycode = OS.find_keycode_from_string(target.to_upper())
	(frame.get_node("%TypingInput") as TypingInput).handle_key(event)


func _text(sut: OverlayScript, label: String) -> String:
	return (sut.get_node("%" + label) as Label).text


func _controls(node: Node, found: Array[Control]) -> Array[Control]:
	if node is Control:
		found.append(node as Control)
	for child: Node in node.get_children():
		_controls(child, found)
	return found


func test_root_is_a_hidden_canvas_layer_above_the_fade() -> void:
	var sut: OverlayScript = _make()
	assert_true(sut is CanvasLayer)
	assert_false(sut.visible)
	assert_gt(sut.layer, 100, "above the Router's fade layer")
	assert_eq(sut.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(sut.is_processing(), "closed = no per-frame work")


func test_f3_toggles_and_process_follows() -> void:
	var sut: OverlayScript = _make()
	assert_true(sut._handle_key(KEY_F3))
	assert_true(sut.visible)
	assert_true(sut.is_processing())
	assert_true(sut._handle_key(KEY_F3))
	assert_false(sut.visible)
	assert_false(sut.is_processing())


func test_cheats_do_nothing_while_closed() -> void:
	var sut: OverlayScript = _make()
	assert_false(sut._handle_key(KEY_F5))
	assert_false(sut._handle_key(KEY_F8))
	assert_false(sut._handle_key(KEY_F9))
	assert_eq(_player.get_brains(), 0)
	assert_false(sut.is_confirming())
	assert_eq(_downloads.size(), 0)


func test_f5_adds_cheat_brains_through_player_data() -> void:
	var sut: OverlayScript = _make()
	watch_signals(_player)
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F5))
	assert_true(sut._handle_key(KEY_F5))
	assert_eq(OverlayScript.CHEAT_BRAINS, 100)
	assert_eq(_player.get_brains(), 200)
	assert_signal_emit_count(_player, "brains_changed", 2)
	assert_signal_emitted_with_parameters(_player, "brains_changed", [200, 100])


func test_f8_needs_a_second_f8() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	assert_true(sut._handle_key(KEY_F8))
	assert_true(sut.is_confirming())
	assert_true((sut.get_node("%ConfirmLabel") as Label).visible)
	assert_eq(_player.get_brains(), 100, "first F8 only asks")
	assert_true(sut._handle_key(KEY_F8))
	assert_false(sut.is_confirming())
	assert_false((sut.get_node("%ConfirmLabel") as Label).visible)
	assert_eq(_player.get_brains(), 0)


func test_f8_reset_emits_profile_replaced() -> void:
	var sut: OverlayScript = _make()
	watch_signals(_player)
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F8)
	sut._handle_key(KEY_F8)
	assert_signal_emit_count(_player, "profile_replaced", 1)


func test_any_other_key_cancels_the_confirm() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	sut._handle_key(KEY_F8)
	assert_false(sut._handle_key(KEY_A), "a cancelling key is not swallowed")
	assert_false(sut.is_confirming())
	assert_false((sut.get_node("%ConfirmLabel") as Label).visible)
	sut._handle_key(KEY_F8)
	assert_true(sut.is_confirming(), "a fresh F8 asks again, it does not reset")
	assert_eq(_player.get_brains(), 100)


func test_closing_cancels_the_confirm() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	sut._handle_key(KEY_F8)
	sut._handle_key(KEY_F3)
	assert_false(sut.visible)
	assert_false(sut.is_confirming())
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F8)
	assert_true(sut.is_confirming(), "reopened: first F8 asks again")
	assert_eq(_player.get_brains(), 100)


func test_confirm_times_out() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	sut._handle_key(KEY_F8)
	var timer: Timer = sut.get_node("%ConfirmTimer") as Timer
	assert_false(timer.is_stopped(), "the cancel timer runs while confirming")
	assert_eq(timer.wait_time, OverlayScript.CONFIRM_SEC)
	sut._on_confirm_timer_timeout()
	assert_false(sut.is_confirming())
	sut._handle_key(KEY_F8)
	assert_eq(_player.get_brains(), 100, "after the timeout F8 asks again")


func test_f9_exports_only_while_open() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F9)
	assert_eq(_downloads.size(), 0)
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F9))
	assert_eq(_downloads.size(), 1)
	assert_true(_downloads[0].begins_with("zts-save-"))


func test_unused_keys_are_not_consumed() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_false(sut._handle_key(KEY_A))
	assert_false(sut._handle_key(KEY_F1), "F1 is free (F4 is the stress hold since Story 6.7)")
	assert_false(sut._handle_key(KEY_F10))
	assert_false(sut._handle_key(KEY_ESCAPE))


## Only the jump and unlock buttons take the mouse (Stories 4.2, 6.8); nothing here ever takes keyboard focus.
func test_never_blocks_the_mouse() -> void:
	var sut: OverlayScript = _make()
	var controls: Array[Control] = _controls(sut, [])
	assert_gt(controls.size(), 0)
	var jumps: Array[Control] = _jump_buttons(sut) + _unlock_buttons(sut)
	for control: Control in controls:
		assert_eq(control.focus_mode, Control.FOCUS_NONE, str(control.name))
		if control not in jumps:
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, str(control.name))


func test_labels_fill_in_when_opened() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_string_contains((sut.get_node("%StatsLabel") as Label).text, "FPS")
	var save_text: String = (sut.get_node("%SaveLabel") as Label).text
	assert_string_contains(save_text, "Last save: never")
	assert_string_contains(save_text, "Storage: persistent")
	assert_eq((sut.get_node("%HelpLabel") as Label).text,
			"F5 +100 brains  F6 end run  F7 typing log\nF8 reset  F9 export  F2 pin seed  F4 stress")


func test_format_save_age() -> void:
	assert_eq(OverlayScript.format_save_age(-1, 5000), "Last save: never")
	assert_eq(OverlayScript.format_save_age(1000, 3300), "Last save: 2.3 s ago")


func test_uses_live_autoloads_by_default() -> void:
	var sut: OverlayScript = OverlayScene.instantiate() as OverlayScript
	add_child_autofree(sut)
	assert_eq(sut.player_data, PlayerData)
	assert_eq(sut.save_service, SaveService)


# --- Story 2.10: run section, F2 / F6 / F7 ----------------------------------------

func test_new_keys_do_nothing_while_closed() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	_type_correct(frame)
	assert_false(sut._handle_key(KEY_F2))
	assert_false(sut._handle_key(KEY_F6))
	assert_false(sut._handle_key(KEY_F7))
	assert_false(Log.verbose_typing)
	assert_eq(RunFrameScript.debug_seed, -1)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)


func test_f7_toggles_the_typing_log() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_string_contains(_text(sut, "ToolsLabel"), "Typing log: off")
	assert_true(sut._handle_key(KEY_F7))
	assert_true(Log.verbose_typing)
	assert_string_contains(_text(sut, "ToolsLabel"), "Typing log: on")
	assert_true(sut._handle_key(KEY_F7))
	assert_false(Log.verbose_typing)
	assert_string_contains(_text(sut, "ToolsLabel"), "Typing log: off")


func test_f2_pins_and_clears_the_last_seed() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F2))
	assert_eq(RunFrameScript.debug_seed, -1, "no run yet: nothing to pin")
	assert_string_contains(_text(sut, "ToolsLabel"), "Replay seed: off")
	assert_string_contains(_text(sut, "ToolsLabel"), "Last run seed: none")
	_start_frame()
	assert_eq(RunFrameScript.last_seed, 42)
	assert_true(sut._handle_key(KEY_F2))
	assert_eq(RunFrameScript.debug_seed, 42)
	assert_eq(RunFrameScript.debug_seed_level, &"test_level")
	assert_string_contains(_text(sut, "ToolsLabel"), "Replay seed: 42 (test_level)")
	assert_string_contains(_text(sut, "ToolsLabel"), "Last run seed: 42")
	assert_true(sut._handle_key(KEY_F2))
	assert_eq(RunFrameScript.debug_seed, -1)
	assert_eq(RunFrameScript.debug_seed_level, &"")
	assert_string_contains(_text(sut, "ToolsLabel"), "Replay seed: off")


func test_tools_section_shows_without_a_run() -> void:
	var sut: OverlayScript = _make()
	RunFrameScript.last_seed = 1234567890
	sut._handle_key(KEY_F3)
	assert_true((sut.get_node("%ToolsLabel") as Label).visible)
	assert_string_contains(_text(sut, "ToolsLabel"), "Last run seed: 1234567890")


func test_run_section_is_hidden_without_a_run() -> void:
	var sut: OverlayScript = _make()
	assert_false((sut.get_node("%RunLabel") as Label).visible, "hidden at start")
	sut._handle_key(KEY_F3)
	assert_false((sut.get_node("%RunLabel") as Label).visible)


func test_run_section_shows_the_run() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	var run_label: Label = sut.get_node("%RunLabel") as Label
	assert_true(run_label.visible)
	var text: String = run_label.text
	var session: TypingSession = frame.get_session()
	var upcoming: Array[String] = session.get_upcoming(OverlayScript.UPCOMING_SHOWN)
	assert_eq(upcoming.size(), 3)
	assert_string_contains(text, "Run test_level WAITING_FIRST_KEY")
	assert_string_contains(text, "Clock 0.0 / 120 s")
	assert_string_contains(text, "Target %s > %s" % [session.get_current_target(), " ".join(upcoming)])
	assert_string_contains(text, "Keys 0  Errors 0  WPM 0")
	assert_string_contains(text, "Seed 42")
	assert_false(text.contains("(replay)"))
	for i: int in 5:
		_type_correct(frame)
	frame._process(6.0)
	sut._refresh()
	text = run_label.text
	assert_string_contains(text, "Run test_level RUNNING")
	assert_string_contains(text, "Clock 6.0 / 120 s")
	assert_string_contains(text, "Keys 5  Errors 0  WPM %d" % StatsCalculator.wpm(5, 6.0))
	assert_string_contains(text, "Target %s > " % session.get_current_target())


func test_run_section_marks_a_replay() -> void:
	var sut: OverlayScript = _make()
	RunFrameScript.debug_seed = 777
	RunFrameScript.debug_seed_level = &"test_level"
	_start_frame({"level_id": &"test_level"})
	sut._handle_key(KEY_F3)
	assert_string_contains(_text(sut, "RunLabel"), "Seed 777 (replay)")


func test_run_section_hides_when_the_frame_goes_away() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	assert_true((sut.get_node("%RunLabel") as Label).visible)
	frame.queue_free()
	sut._refresh()
	assert_false((sut.get_node("%RunLabel") as Label).visible, "queued for deletion = no run")


func test_f6_ends_a_running_run() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	_type_correct(frame)
	frame._process(3.0)
	assert_true(sut._handle_key(KEY_F6))
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	var history: Array = _save.get_active_profile()["run_history"]
	assert_eq(history.size(), 1)
	assert_eq(str(history[0]["end_reason"]), "timer")
	assert_string_contains(_text(sut, "RunLabel"), "ENDING")


func test_f6_does_nothing_before_the_first_key() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F6), "the overlay's key even when refused")
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(_save.get_active_profile()["run_history"].size(), 0)


func test_f6_without_a_run_is_harmless() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F6))
	assert_eq(_nav, [])
	assert_false((sut.get_node("%RunLabel") as Label).visible)
	assert_eq(_save.get_active_profile()["run_history"].size(), 0)


func test_new_keys_cancel_the_f8_confirm() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	for key: Key in [KEY_F2, KEY_F6, KEY_F7]:
		sut._handle_key(KEY_F8)
		assert_true(sut.is_confirming())
		sut._handle_key(key)
		assert_false(sut.is_confirming(), OS.get_keycode_string(key))


func test_fits_above_the_hud_band_with_every_section() -> void:
	var sut: OverlayScript = _make()
	RunFrameScript.debug_seed = 1234567890
	RunFrameScript.debug_seed_level = &"test_level"
	_start_frame({"level_id": &"test_level"})
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F8)
	assert_true((sut.get_node("%RunLabel") as Label).visible)
	assert_true((sut.get_node("%ConfirmLabel") as Label).visible)
	assert_string_contains(_text(sut, "RunLabel"), "(replay)")
	assert_string_contains(_text(sut, "ToolsLabel"), "Replay seed: 1234567890 (test_level)", "widest pin")
	var panel: PanelContainer = sut.get_node("%Panel") as PanelContainer
	var size: Vector2 = panel.get_combined_minimum_size()
	assert_lte(panel.offset_top + size.y, 256.0, "bottom above the HUD band")
	assert_lte(panel.offset_left + size.x, 640.0, "inside the 640 px playfield")


# --- run-worst frame time (Story 3.4) ------------------------------------------

func test_run_worst_grows_only_while_running() -> void:
	var sut: OverlayScript = _make()
	assert_eq(sut.get_run_worst_ms(), 0.0)
	sut._note_run_frame(40.0, 7, false)
	assert_eq(sut.get_run_worst_ms(), 0.0, "WAITING_FIRST_KEY / PAUSED / COUNTDOWN frames do not count")
	sut._note_run_frame(12.0, 7, true)
	sut._note_run_frame(20.0, 7, true)
	sut._note_run_frame(16.0, 7, true)
	assert_eq(sut.get_run_worst_ms(), 20.0, "the worst so far")
	sut._note_run_frame(90.0, 7, false)
	assert_eq(sut.get_run_worst_ms(), 20.0, "a pause hitch is ignored")


func test_run_worst_resets_on_a_new_run_frame() -> void:
	var sut: OverlayScript = _make()
	sut._note_run_frame(30.0, 7, true)
	sut._note_run_frame(10.0, 8, true)
	assert_eq(sut.get_run_worst_ms(), 10.0, "a different run frame starts over")


func test_run_worst_ignores_non_running_states_of_a_real_frame() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	sut._process(0.0)
	assert_eq(frame.get_state(), RunFrameScript.RunState.WAITING_FIRST_KEY)
	assert_eq(sut.get_run_worst_ms(), 0.0, "waiting for the first key does not count")
	_type_correct(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	OS.delay_msec(5)
	sut._process(0.0)
	assert_gt(sut.get_run_worst_ms(), 0.0, "a running frame counts")


func test_run_worst_ignores_paused_and_countdown_frames_of_a_real_frame() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	_type_correct(frame)
	frame._request_pause()
	assert_eq(frame.get_state(), RunFrameScript.RunState.PAUSED)
	OS.delay_msec(5)
	sut._process(0.0)
	assert_eq(sut.get_run_worst_ms(), 0.0, "a paused frame does not count")
	frame._on_pause_panel_resume_chosen()
	assert_eq(frame.get_state(), RunFrameScript.RunState.COUNTDOWN)
	OS.delay_msec(5)
	sut._process(0.0)
	assert_eq(sut.get_run_worst_ms(), 0.0, "a countdown frame does not count")


func test_run_worst_survives_the_run_and_shows() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	sut._note_run_frame(25.0, frame.get_instance_id(), true)
	_frame = null
	sut._process(0.0)
	assert_eq(sut.get_run_worst_ms(), 25.0, "kept after the run frame goes away")
	sut._refresh()
	assert_string_contains(_text(sut, "StatsLabel"), "Run: 25.0 ms")


# --- Story 4.2: jump row ---------------------------------------------------------

func _jump_buttons(sut: OverlayScript) -> Array[Control]:
	return [
		sut.get_node("%JumpTestLevelButton") as Control, sut.get_node("%JumpWordLevelButton") as Control,
		sut.get_node("%JumpHordeRushButton") as Control, sut.get_node("%JumpGiftButton") as Control,
		sut.get_node("%JumpKeyboardTestButton") as Control,
	]


func _unlock_buttons(sut: OverlayScript) -> Array[Control]:
	return [sut.get_node("%UnlockAllButton") as Control, sut.get_node("%RelockAllButton") as Control]


func test_jump_buttons_exist_and_never_take_focus() -> void:
	var sut: OverlayScript = _make()
	var texts: Array[String] = []
	for control: Control in _jump_buttons(sut) + _unlock_buttons(sut):
		var button: Button = control as Button
		assert_not_null(button)
		assert_eq(button.focus_mode, Control.FOCUS_NONE, str(button.name))
		texts.append(button.text)
	assert_eq(texts, ["Test level", "Test words", "Horde Rush", "Welcome gift", "Keyboard test", "Unlock all",
			"Relock all"] as Array[String])


func test_jump_buttons_navigate_from_the_main_menu() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	for control: Control in _jump_buttons(sut):
		assert_false((control as Button).disabled, str(control.name))
		(control as Button).pressed.emit()
	assert_eq(_jumps, [
		[Router.Screen.RUN, {"level_id": &"test_level"}],
		[Router.Screen.RUN, {"level_id": &"test_word_level"}],
		[Router.Screen.RUN, {"level_id": &"horde_rush"}],
		[Router.Screen.WELCOME_GIFT, {}],
		[Router.Screen.KEYBOARD_TEST, {}],
	])


## Story 6.3: level jumps on the first row, screen jumps on the second, so the 8 px text never shrinks.
func test_jump_buttons_sit_on_two_rows() -> void:
	var sut: OverlayScript = _make()
	var rows: Dictionary[String, String] = {
		"JumpTestLevelButton": "JumpRow", "JumpWordLevelButton": "JumpRow", "JumpHordeRushButton": "JumpRow",
		"JumpGiftButton": "JumpRow2", "JumpKeyboardTestButton": "JumpRow2",
		"UnlockAllButton": "JumpRow2", "RelockAllButton": "JumpRow2",
	}
	for button_name: String in rows:
		var button: Button = sut.get_node("%" + button_name) as Button
		assert_eq(String(button.get_parent().name), rows[button_name], button_name)
		assert_eq(button.get_theme_font_size(&"font_size"), 8, button_name)


func test_jump_buttons_do_nothing_off_the_main_menu() -> void:
	var sut: OverlayScript = _make()
	_screen = Router.Screen.RUN
	sut._handle_key(KEY_F3)
	for control: Control in _jump_buttons(sut):
		assert_true((control as Button).disabled, str(control.name))
		(control as Button).pressed.emit()
	assert_eq(_jumps, [])


func test_jump_buttons_follow_the_screen_on_refresh() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	_screen = Router.Screen.REPORT_CARD
	sut._refresh()
	assert_true((sut.get_node("%JumpGiftButton") as Button).disabled)
	_screen = Router.Screen.MAIN_MENU
	sut._refresh()
	assert_false((sut.get_node("%JumpGiftButton") as Button).disabled)


func test_jump_buttons_do_nothing_while_closed() -> void:
	var sut: OverlayScript = _make()
	(sut.get_node("%JumpGiftButton") as Button).pressed.emit()
	assert_eq(_jumps, [])


func test_jump_seams_default_to_the_router() -> void:
	var sut: OverlayScript = OverlayScene.instantiate() as OverlayScript
	add_child_autofree(sut)
	assert_true(sut.navigate.is_valid())
	assert_eq(sut.current_screen.call(), Router.current_screen)


# --- F4 stress hold (Story 6.7) ------------------------------------------------

func _horde_frame() -> RunFrameScript:
	var frame: RunFrameScript = _start_frame({"level_id": &"horde_rush", "seed": 7})
	(frame.get_level() as Node).set("request_voice", func(_id: StringName) -> void: pass)
	(frame.get_level() as Node).set("play_sfx", func(_id: StringName) -> void: pass)
	return frame


func test_f4_toggles_the_stress_hold_on_a_running_horde_rush() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _horde_frame()
	sut._handle_key(KEY_F3)
	_type_correct(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	var level: LevelBase = frame.get_level()
	assert_string_contains(_text(sut, "RunLabel"), "stress: off")
	assert_true(sut._handle_key(KEY_F4))
	assert_eq(level.call("get_stress_floor"), OverlayScript.STRESS_COPIES)
	assert_eq(OverlayScript.STRESS_COPIES, 30, "NFR1: 30 zombies")
	assert_string_contains(_text(sut, "RunLabel"), "stress: 30")
	assert_true(sut._handle_key(KEY_F4))
	assert_eq(level.call("get_stress_floor"), 0, "F4 again: off")
	assert_string_contains(_text(sut, "RunLabel"), "stress: off")


func test_f4_is_refused_before_the_first_key() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _horde_frame()
	sut._handle_key(KEY_F3)
	frame.get_level().call("debug_set_stress_floor", 5)
	assert_true(sut._handle_key(KEY_F4), "the overlay's key even when refused")
	assert_eq(frame.get_level().call("get_stress_floor"), 5, "a refused F4 leaves the floor alone")


func test_f4_is_refused_after_the_run_ends() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _horde_frame()
	sut._handle_key(KEY_F3)
	_type_correct(frame)
	sut._handle_key(KEY_F6)
	assert_eq(frame.get_state(), RunFrameScript.RunState.ENDING)
	frame.get_level().call("debug_set_stress_floor", 5)
	sut._handle_key(KEY_F4)
	assert_eq(frame.get_level().call("get_stress_floor"), 5, "a refused F4 leaves the floor alone")


func test_f4_is_refused_on_another_level() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _start_frame()
	sut._handle_key(KEY_F3)
	_type_correct(frame)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	assert_true(sut._handle_key(KEY_F4))
	assert_false(frame.get_level().has_method("debug_set_stress_floor"))
	assert_false(_text(sut, "RunLabel").contains("stress"), "no stress line for a level without the hold")


func test_f4_does_nothing_while_closed() -> void:
	var sut: OverlayScript = _make()
	var frame: RunFrameScript = _horde_frame()
	_type_correct(frame)
	frame.get_level().call("debug_set_stress_floor", 5)
	assert_false(sut._handle_key(KEY_F4))
	assert_eq(frame.get_level().call("get_stress_floor"), 5, "a closed overlay ignores F4")


# --- Story 6.8: Unlock all / Relock all ------------------------------------------

func test_unlock_buttons_do_nothing_off_the_main_menu_or_closed() -> void:
	var sut: OverlayScript = _make()
	for control: Control in _unlock_buttons(sut):
		(control as Button).pressed.emit()
	_screen = Router.Screen.RUN
	sut._handle_key(KEY_F3)
	for control: Control in _unlock_buttons(sut):
		assert_true((control as Button).disabled, str(control.name))
		(control as Button).pressed.emit()
	assert_eq(_jumps, [])
	assert_eq_deep(_save.get_active_profile()["level_unlocks"], {})


func test_unlock_all_opens_every_level_and_reloads_the_menu() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	var button: Button = sut.get_node("%UnlockAllButton") as Button
	assert_false(button.disabled)
	watch_signals(_player)
	button.pressed.emit()
	assert_eq(_jumps, [[Router.Screen.MAIN_MENU, {}]], "reloads the menu once")
	assert_signal_emit_count(_player, "unlocks_changed", 1)
	for id: StringName in [&"horde_rush", &"pitchfork_panic"]:
		assert_eq_deep(_player.get_unlock_state(id), {"unlocked": true, "moment_seen": false, "chosen": false})


func test_relock_all_clears_every_unlock_and_reloads_the_menu() -> void:
	var sut: OverlayScript = _make()
	_player.debug_set_all_unlocked(true)
	sut._handle_key(KEY_F3)
	(sut.get_node("%RelockAllButton") as Button).pressed.emit()
	assert_eq(_jumps, [[Router.Screen.MAIN_MENU, {}]])
	assert_false(_player.get_unlock_state(&"horde_rush")["unlocked"])
	assert_eq_deep(_save.get_active_profile()["level_unlocks"], {})
