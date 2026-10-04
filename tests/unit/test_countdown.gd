extends GutTest
## Resume countdown (Story 2.7): 3-2-1 at 0.5 s per number while the tree stays paused, `finished`
## exactly once, cancel without a signal. Disabled instance: _process driven by hand.

const CountdownScene: PackedScene = preload("res://scenes/run/countdown.tscn")
const CountdownScript := preload("res://scripts/run/countdown.gd")

var _countdown: CountdownScript


func before_each() -> void:
	_countdown = CountdownScene.instantiate() as CountdownScript
	add_child_autofree(_countdown)
	watch_signals(_countdown)


func _label() -> Label:
	return _countdown.get_node("%NumberLabel") as Label


func _start() -> void:
	_countdown.start(GameConstants.COUNTDOWN_FROM, GameConstants.COUNTDOWN_STEP_S)


func test_constants() -> void:
	assert_eq(GameConstants.COUNTDOWN_FROM, 3)
	assert_eq(GameConstants.COUNTDOWN_STEP_S, 0.5)


func test_hidden_at_start() -> void:
	assert_false(_countdown.visible)
	assert_false(_countdown.is_running())
	assert_eq(_countdown.get_shown_number(), 0)


func test_counts_three_two_one_then_finishes_once() -> void:
	_start()
	assert_true(_countdown.visible)
	assert_true(_countdown.is_running())
	assert_eq(_countdown.get_shown_number(), 3)
	assert_eq(_label().text, "3")
	_countdown._process(0.5)
	assert_eq(_countdown.get_shown_number(), 2)
	assert_eq(_label().text, "2")
	_countdown._process(0.5)
	assert_eq(_countdown.get_shown_number(), 1)
	assert_signal_emit_count(_countdown, "finished", 0)
	_countdown._process(0.5)
	assert_false(_countdown.visible)
	assert_false(_countdown.is_running())
	assert_eq(_countdown.get_shown_number(), 0)
	assert_signal_emit_count(_countdown, "finished", 1)
	_countdown._process(0.5)
	_countdown._process(1.0)
	assert_signal_emit_count(_countdown, "finished", 1, "never twice")


func test_number_holds_for_the_whole_step() -> void:
	_start()
	_countdown._process(0.25)
	assert_eq(_countdown.get_shown_number(), 3)
	_countdown._process(0.125)
	assert_eq(_countdown.get_shown_number(), 3)
	_countdown._process(0.125)
	assert_eq(_countdown.get_shown_number(), 2)


func test_frame_deltas_finish_once() -> void:
	_start()
	for i: int in 100:
		_countdown._process(1.0 / 60.0)
	assert_signal_emit_count(_countdown, "finished", 1)
	assert_false(_countdown.visible)


func test_cancel_hides_without_signal() -> void:
	_start()
	_countdown._process(0.5)
	_countdown.cancel()
	assert_false(_countdown.visible)
	assert_false(_countdown.is_running())
	_countdown._process(2.0)
	assert_signal_emit_count(_countdown, "finished", 0)


func test_restart_after_cancel() -> void:
	_start()
	_countdown._process(0.75)
	_countdown.cancel()
	_start()
	assert_eq(_countdown.get_shown_number(), 3)
	_countdown._process(1.5)
	assert_signal_emit_count(_countdown, "finished", 1)


func test_hitch_finishes_once() -> void:
	_start()
	_countdown._process(5.0)
	assert_signal_emit_count(_countdown, "finished", 1)
	assert_false(_countdown.visible)


func test_numbers_come_from_the_caller() -> void:
	_countdown.start(5, 0.25)
	assert_eq(_countdown.get_shown_number(), 5)
	_countdown._process(0.25)
	assert_eq(_countdown.get_shown_number(), 4)


func test_runs_while_paused() -> void:
	assert_eq(_countdown.process_mode, Node.PROCESS_MODE_WHEN_PAUSED)


func test_look() -> void:
	assert_eq(_label().get_theme_font_size("font_size"), 64)
	var rect: Rect2 = Rect2(_label().position, _label().size)
	assert_eq(rect.get_center(), Vector2(320, 128), "centred on the playfield")


func test_focus_and_mouse_ignored() -> void:
	var controls: Array[Node] = [_countdown]
	controls.append_array(_countdown.find_children("*", "Control", true, false))
	for node: Node in controls:
		var control: Control = node as Control
		assert_eq(control.focus_mode, Control.FOCUS_NONE, "%s focus" % control.name)
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s mouse" % control.name)
