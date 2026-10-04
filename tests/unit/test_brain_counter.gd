extends GutTest
## Brain counter widget (Story 2.5): shows a number it is given; never focusable or mouse-blocking.

const CounterScene: PackedScene = preload("res://scenes/ui/brain_counter.tscn")

var _counter: BrainCounter


func before_each() -> void:
	_counter = CounterScene.instantiate() as BrainCounter
	add_child_autofree(_counter)


func _label() -> Label:
	return _counter.get_node("%CountLabel") as Label


func test_starts_at_zero() -> void:
	assert_eq(_label().text, "0")


func test_set_count() -> void:
	_counter.set_count(12)
	assert_eq(_label().text, "12")
	_counter.set_count(0)
	assert_eq(_label().text, "0")


func test_negative_count_shows_zero_and_logs() -> void:
	_counter.set_count(5)
	_counter.set_count(-3)
	assert_eq(_label().text, "0")
	assert_push_error("[ERROR][ui]")


func test_font_size() -> void:
	var size: int = _label().get_theme_font_size("font_size")
	assert_true(size >= 16, "font size %d" % size)
	assert_eq(size % 8, 0, "8 px grid")


func test_size_matches_sketch() -> void:
	assert_eq(_counter.size, Vector2(80, 28))


func test_nothing_focusable_or_mouse_blocking() -> void:
	var nodes: Array[Node] = [_counter]
	nodes.append_array(_counter.find_children("*", "Control", true, false))
	for node: Node in nodes:
		var control: Control = node as Control
		assert_eq(control.focus_mode, Control.FOCUS_NONE, "%s focus" % control.name)
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s mouse" % control.name)
