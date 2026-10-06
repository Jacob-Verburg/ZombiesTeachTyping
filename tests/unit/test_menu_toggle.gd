extends GutTest
## MenuToggle (Story 4.2): captions per kind, show_state never emits, a user flip emits once with the new
## state, hover moves focus to the button, and the off state is carried by a slash.

const ToggleScene: PackedScene = preload("res://scenes/ui/menu_toggle.tscn")

var _flips: Array[bool] = []


func before_each() -> void:
	_flips = []


func _toggle(kind: MenuToggle.Kind) -> MenuToggle:
	var toggle: MenuToggle = ToggleScene.instantiate() as MenuToggle
	toggle.kind = kind
	toggle.flipped.connect(func(on: bool) -> void: _flips.append(on))
	add_child_autofree(toggle)
	return toggle


func test_captions_follow_the_kind() -> void:
	assert_eq((_toggle(MenuToggle.Kind.MUSIC).get_node("%Caption") as Label).text, "Music")
	assert_eq((_toggle(MenuToggle.Kind.SOUND).get_node("%Caption") as Label).text, "Sound")
	assert_eq((_toggle(MenuToggle.Kind.FULLSCREEN).get_node("%Caption") as Label).text, "Fullscreen")


func test_show_state_does_not_emit() -> void:
	var toggle: MenuToggle = _toggle(MenuToggle.Kind.MUSIC)
	toggle.show_state(false)
	assert_false(toggle.is_on())
	toggle.show_state(true)
	assert_true(toggle.is_on())
	assert_eq(_flips, [] as Array[bool])


func test_user_flip_emits_the_new_state_once() -> void:
	var toggle: MenuToggle = _toggle(MenuToggle.Kind.SOUND)
	toggle.show_state(true)
	toggle.get_focus_target().pressed.emit()
	assert_eq(_flips, [false] as Array[bool])
	assert_false(toggle.is_on())
	toggle.get_focus_target().pressed.emit()
	assert_eq(_flips, [false, true] as Array[bool])


func test_focus_target_is_a_32px_pixel_button() -> void:
	var toggle: MenuToggle = _toggle(MenuToggle.Kind.FULLSCREEN)
	var button: Button = toggle.get_focus_target()
	assert_true(button is PixelButton)
	assert_eq(button.custom_minimum_size, Vector2(32, 32))
	assert_false(button.toggle_mode, "the script keeps the state")
	assert_eq(toggle.focus_mode, Control.FOCUS_NONE, "the box itself never takes focus")
	button._gui_input(InputEventMouseMotion.new())
	assert_true(button.has_focus(), "mouse motion moves focus")


func test_icon_never_takes_the_mouse() -> void:
	var toggle: MenuToggle = _toggle(MenuToggle.Kind.MUSIC)
	assert_eq((toggle.get_node("%Icon") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((toggle.get_node("%Caption") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_slash_carries_the_off_state() -> void:
	# Colour alone must not carry the state (NFR8): off draws a slash in a third colour.
	assert_ne(MenuToggle.SLASH_COLOR, MenuToggle.OFF_COLOR)
	assert_ne(MenuToggle.SLASH_COLOR, MenuToggle.ON_COLOR)
	assert_gte(MenuToggle.SLASH_PX, 2.0)
