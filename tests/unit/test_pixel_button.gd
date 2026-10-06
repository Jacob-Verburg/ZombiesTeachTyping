extends GutTest
## PixelButton (Story 4.2): the theme variation, hover moves focus, and the focused fill swap.


func _make() -> PixelButton:
	var button: PixelButton = PixelButton.new()
	button.text = "Go"
	add_child_autofree(button)
	return button


func test_uses_the_pixel_button_variation() -> void:
	assert_eq(_make().theme_type_variation, &"PixelButton")


func test_hover_moves_focus() -> void:
	var button: PixelButton = _make()
	button._gui_input(InputEventMouseMotion.new())
	assert_true(button.has_focus())


func test_mouse_entered_alone_does_not_move_focus() -> void:
	var button: PixelButton = _make()
	button.mouse_entered.emit()
	assert_false(button.has_focus(), "a resting cursor must not steal focus")


func test_hover_does_not_focus_a_disabled_or_unfocusable_button() -> void:
	var disabled: PixelButton = _make()
	disabled.disabled = true
	disabled._gui_input(InputEventMouseMotion.new())
	assert_false(disabled.has_focus())
	var unfocusable: PixelButton = _make()
	unfocusable.focus_mode = Control.FOCUS_NONE
	unfocusable._gui_input(InputEventMouseMotion.new())
	assert_false(unfocusable.has_focus())


func test_focus_swaps_the_normal_box_to_the_focused_fill() -> void:
	var button: PixelButton = _make()
	var plain: StyleBox = button.get_theme_stylebox(&"normal")
	button.grab_focus()
	assert_eq(button.get_theme_stylebox(&"normal"), button.get_theme_stylebox(&"normal_focused"))
	assert_ne(button.get_theme_stylebox(&"normal"), plain)
	button.release_focus()
	assert_eq(button.get_theme_stylebox(&"normal"), plain)
