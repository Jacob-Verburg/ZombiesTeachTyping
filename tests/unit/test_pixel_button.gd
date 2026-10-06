extends GutTest
## PixelButton (Story 4.2): the theme variation, hover moves focus, and the focused fill swap. Story 5.0: the
## swap is dropped when the button is disabled or hidden while focused; the focus bounce ends at rest and
## is skipped inside a container.


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


func test_disabled_while_focused_drops_the_focused_fill() -> void:
	var button: PixelButton = _make()
	button.grab_focus()
	assert_true(button.has_theme_stylebox_override(&"normal"))
	button.disabled = true
	await wait_process_frames(3)
	assert_false(button.has_theme_stylebox_override(&"normal"), "a disabled button never keeps the focused fill")


func test_hidden_while_focused_drops_the_focused_fill() -> void:
	var button: PixelButton = _make()
	button.grab_focus()
	button.hide()
	assert_false(button.has_theme_stylebox_override(&"normal"))


func test_focus_bounce_ends_exactly_at_rest() -> void:
	var holder: Control = Control.new()
	add_child_autofree(holder)
	var button: PixelButton = PixelButton.new()
	button.text = "Go"
	button.position = Vector2(40, 30)
	holder.add_child(button)
	button.grab_focus()
	assert_true(button.is_bouncing())
	await wait_until(func() -> bool: return not button.is_bouncing(), 2.0)
	assert_eq(button.position, Vector2(40, 30))
	button.release_focus()
	button.grab_focus()
	button.release_focus()
	button.grab_focus()
	await wait_until(func() -> bool: return not button.is_bouncing(), 2.0)
	assert_eq(button.position, Vector2(40, 30), "restarted bounces still end at rest")


func test_bounce_keeps_a_move_made_mid_bounce() -> void:
	var holder: Control = Control.new()
	add_child_autofree(holder)
	var button: PixelButton = PixelButton.new()
	button.text = "Go"
	button.position = Vector2(40, 30)
	holder.add_child(button)
	button.grab_focus()
	button.position.y += 10.0
	await wait_until(func() -> bool: return not button.is_bouncing(), 2.0)
	assert_eq(button.position, Vector2(40, 40), "the owner's move is kept; the bounce nets to zero")


func test_rest_rect_ignores_the_bounce_offset() -> void:
	var holder: Control = Control.new()
	add_child_autofree(holder)
	var button: PixelButton = PixelButton.new()
	button.text = "Go"
	button.position = Vector2(40, 30)
	holder.add_child(button)
	var rest: Rect2 = button.get_rest_rect()
	button.grab_focus()
	button._apply_bounce(-PixelButton.BOUNCE_PX)
	assert_eq(button.get_rest_rect(), rest)


func test_bounce_runs_while_the_tree_is_paused() -> void:
	var holder: Control = Control.new()
	holder.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child_autofree(holder)
	var button: PixelButton = PixelButton.new()
	button.text = "Go"
	button.position = Vector2(40, 30)
	holder.add_child(button)
	get_tree().paused = true
	button.grab_focus()
	await get_tree().create_timer(PixelButton.BOUNCE_S + 0.2, true).timeout
	get_tree().paused = false
	assert_false(button.is_bouncing(), "the bounce finished while paused")
	assert_eq(button.position, Vector2(40, 30))


func test_re_enabled_while_focused_gets_the_focused_fill_back() -> void:
	var button: PixelButton = _make()
	button.grab_focus()
	button.disabled = true
	await wait_process_frames(3)
	assert_false(button.has_theme_stylebox_override(&"normal"))
	button.disabled = false
	await wait_process_frames(3)
	assert_true(button.has_theme_stylebox_override(&"normal"), "still focused: the fill returns")


func test_no_bounce_inside_a_container() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child_autofree(box)
	var button: PixelButton = PixelButton.new()
	button.text = "Go"
	box.add_child(button)
	button.grab_focus()
	assert_false(button.is_bouncing())


func test_no_bounce_when_disabled() -> void:
	var button: PixelButton = _make()
	button.disabled = true
	button._on_focus_changed(true)
	assert_false(button.is_bouncing())
