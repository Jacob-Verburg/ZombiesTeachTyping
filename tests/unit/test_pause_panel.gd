extends GutTest
## Pause panel (Story 2.7): Resume (pre-focused), Quit to Menu, Music and Sound toggles over a night
## scrim; Esc on the panel = Resume; signals only while open; focus released on close. The panel
## touches no autoload: RunFrame applies what it emits.

const PanelScene: PackedScene = preload("res://scenes/run/pause_panel.tscn")
const PanelScript := preload("res://scripts/run/pause_panel.gd")
const THEME_PATH: String = "res://data/ui_theme.tres"

var _panel: PanelScript


func before_each() -> void:
	_panel = PanelScene.instantiate() as PanelScript
	add_child_autofree(_panel)
	_panel.size = Vector2(640, 360)
	watch_signals(_panel)


func after_each() -> void:
	_reset_input_handled()


func _button(path: String) -> Button:
	return _panel.get_node(path) as Button


func _esc(echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	return event


func _focus_inside_panel() -> bool:
	var owner: Control = get_viewport().gui_get_focus_owner()
	return owner != null and _panel.is_ancestor_of(owner)


func test_hidden_and_runs_while_paused() -> void:
	assert_false(_panel.visible)
	assert_false(_panel.is_open())
	assert_eq(_panel.process_mode, Node.PROCESS_MODE_WHEN_PAUSED)


func test_open_shows_settings_and_focuses_resume() -> void:
	_panel.open(true, false)
	assert_true(_panel.is_open())
	assert_true(_button("%ResumeButton").has_focus())
	assert_eq(_button("%MusicToggle").text, "Music: on")
	assert_true(_button("%MusicToggle").button_pressed)
	assert_eq(_button("%SoundToggle").text, "Sound: off")
	assert_false(_button("%SoundToggle").button_pressed)
	assert_signal_emit_count(_panel, "music_toggled", 0, "open never emits a toggle")
	assert_signal_emit_count(_panel, "sound_toggled", 0, "open never emits a toggle")


func test_reopen_shows_new_settings() -> void:
	_panel.open(true, true)
	_panel.close()
	_panel.open(false, true)
	assert_eq(_button("%MusicToggle").text, "Music: off")
	assert_false(_button("%MusicToggle").button_pressed)
	assert_signal_emit_count(_panel, "music_toggled", 0)


func test_labels() -> void:
	assert_eq((_panel.get_node("%Title") as Label).text, "Paused")
	assert_eq(_button("%ResumeButton").text, "Resume")
	assert_eq(_button("%QuitButton").text, "Quit to Menu")


func test_resume_and_quit_emit_once() -> void:
	_panel.open(true, true)
	_button("%ResumeButton").pressed.emit()
	assert_signal_emit_count(_panel, "resume_chosen", 1)
	_button("%QuitButton").pressed.emit()
	assert_signal_emit_count(_panel, "quit_chosen", 1)


func test_presses_while_closed_emit_nothing() -> void:
	_button("%ResumeButton").pressed.emit()
	_button("%QuitButton").pressed.emit()
	_button("%MusicToggle").toggled.emit(false)
	assert_signal_emit_count(_panel, "resume_chosen", 0)
	assert_signal_emit_count(_panel, "quit_chosen", 0)
	assert_signal_emit_count(_panel, "music_toggled", 0)


func test_music_toggle() -> void:
	_panel.open(true, true)
	_button("%MusicToggle").button_pressed = false
	assert_signal_emitted_with_parameters(_panel, "music_toggled", [false])
	assert_eq(_button("%MusicToggle").text, "Music: off")
	_button("%MusicToggle").button_pressed = true
	assert_signal_emitted_with_parameters(_panel, "music_toggled", [true])
	assert_eq(_button("%MusicToggle").text, "Music: on")


func test_sound_toggle() -> void:
	_panel.open(true, true)
	_button("%SoundToggle").button_pressed = false
	assert_signal_emitted_with_parameters(_panel, "sound_toggled", [false])
	assert_eq(_button("%SoundToggle").text, "Sound: off")
	assert_signal_emit_count(_panel, "music_toggled", 0)


func test_esc_on_panel_resumes() -> void:
	_panel.open(true, true)
	_panel._unhandled_input(_esc(true))
	assert_signal_emit_count(_panel, "resume_chosen", 0, "echo ignored")
	_panel._unhandled_input(_esc())
	assert_signal_emit_count(_panel, "resume_chosen", 1)


func test_esc_while_closed_does_nothing() -> void:
	_panel._unhandled_input(_esc())
	assert_signal_emit_count(_panel, "resume_chosen", 0)


func test_close_hides_and_releases_focus() -> void:
	_panel.open(true, true)
	assert_true(_focus_inside_panel())
	_panel.close()
	assert_false(_panel.is_open())
	assert_false(_focus_inside_panel())


func test_buttons_are_keyboard_focusable_and_wrap() -> void:
	var order: Array[String] = ["%ResumeButton", "%QuitButton", "%MusicToggle", "%SoundToggle"]
	for i: int in order.size():
		var button: Button = _button(order[i])
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "%s focusable" % order[i])
		var below: Button = _button(order[(i + 1) % order.size()])
		var above: Button = _button(order[(i - 1 + order.size()) % order.size()])
		assert_eq(button.get_node(button.focus_neighbor_bottom), below, "%s down" % order[i])
		assert_eq(button.get_node(button.focus_neighbor_top), above, "%s up" % order[i])


func test_toggles_are_toggle_buttons() -> void:
	assert_true(_button("%MusicToggle").toggle_mode)
	assert_true(_button("%SoundToggle").toggle_mode)


func test_button_sizes() -> void:
	for path: String in ["%ResumeButton", "%QuitButton", "%MusicToggle", "%SoundToggle"]:
		assert_eq(_button(path).size, Vector2(240, 32), path)


func test_readable_text_and_glyphs() -> void:
	var font: Font = (load(THEME_PATH) as Theme).default_font
	for node: Node in _panel.find_children("*", "Label", true, false):
		var label: Label = node as Label
		var size: int = label.get_theme_font_size("font_size")
		assert_true(size >= 16 and size % 8 == 0, "%s font size %d" % [label.name, size])
	assert_eq((_panel.get_node("%Title") as Label).get_theme_font_size("font_size"), 24)
	for path: String in ["%ResumeButton", "%QuitButton", "%MusicToggle", "%SoundToggle"]:
		var size: int = _button(path).get_theme_font_size("font_size")
		assert_true(size >= 16 and size % 8 == 0, "%s font size %d" % [path, size])
	var strings: Array[String] = [
		"Paused", "Resume", "Quit to Menu", "Music: on", "Music: off", "Sound: on", "Sound: off",
	]
	for s: String in strings:
		for i: int in s.length():
			assert_true(font.has_char(s.unicode_at(i)), "glyph '%s' in '%s'" % [s[i], s])


func test_scrim_covers_the_canvas_and_stops_the_mouse() -> void:
	var scrim: ColorRect = _panel.get_node("%Scrim") as ColorRect
	assert_eq(scrim.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(Rect2(scrim.position, scrim.size), Rect2(0, 0, 640, 360))
	assert_almost_eq(scrim.color.a, 0.6, 0.001)


func test_panel_keeps_off_the_edges() -> void:
	var panel: Control = _panel.get_node("%Panel") as Control
	var rect: Rect2 = Rect2(panel.position, panel.size)
	assert_true(rect.position.x >= 16 and rect.position.y >= 16, "%s" % rect)
	assert_true(rect.end.x <= 624 and rect.end.y <= 344, "%s" % rect)

## Calling _unhandled_input() by hand marks GUT's viewport input as handled, and headless no real
## event ever clears it. Pushing a no-op event resets the flag so later tests start clean.
func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())
