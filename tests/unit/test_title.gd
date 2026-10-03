extends GutTest
## Title screen structure and which input events advance it (FR23).
## The advance itself calls Router.go(), which is never triggered here (it would swap GUT's scene),
## so the instance is disabled: a real key or click during the run can't reach the live Router.

const TitleScene: PackedScene = preload("res://scenes/screens/title.tscn")

var _title: Control


func before_each() -> void:
	_title = TitleScene.instantiate() as Control
	_title.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_title)


func _key(pressed: bool, echo: bool, keycode: Key = KEY_SPACE) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func test_prompt_text_and_size() -> void:
	var prompt: Label = _title.get_node("%Prompt") as Label
	assert_not_null(prompt)
	assert_eq(prompt.text, "Click or press any key")
	assert_gte(prompt.get_theme_font_size("font_size"), 16)


func test_placeholder_logo_is_shown() -> void:
	var logo: Label = _title.get_node("%Logo") as Label
	assert_not_null(logo)
	assert_eq(logo.text.replace("\n", " "), "Zombies Teach Typing")
	assert_gte(logo.get_theme_font_size("font_size"), 32)


func test_controls_let_clicks_through() -> void:
	assert_eq(_title.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child: Node in _title.get_children():
		if child is Control:
			assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, child.name)


func test_key_press_advances() -> void:
	assert_true(_title._is_advance_event(_key(true, false)))


func test_key_echo_and_release_do_not_advance() -> void:
	assert_false(_title._is_advance_event(_key(true, true)))
	assert_false(_title._is_advance_event(_key(false, false)))


func test_mouse_press_advances() -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_true(_title._is_advance_event(click))
	click.pressed = false
	assert_false(_title._is_advance_event(click))


func test_escape_does_not_advance() -> void:
	assert_false(_title._is_advance_event(_key(true, false, KEY_ESCAPE)))


func test_mouse_wheel_does_not_advance() -> void:
	for wheel: MouseButton in _title.WHEEL_BUTTONS:
		var scroll: InputEventMouseButton = InputEventMouseButton.new()
		scroll.button_index = wheel
		scroll.pressed = true
		assert_false(_title._is_advance_event(scroll), str(wheel))


func test_mouse_motion_does_not_advance() -> void:
	assert_false(_title._is_advance_event(InputEventMouseMotion.new()))
