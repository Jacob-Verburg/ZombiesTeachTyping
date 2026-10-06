extends GutTest
## Pause panel (Story 2.7): Resume (pre-focused), Quit to Menu, Music and Sound toggles over a night
## scrim; Esc on the panel = Resume; signals only while open; focus released on close. The panel
## touches no autoload: RunFrame applies what it emits. Story 5.0: the toggles are MenuToggles (icon + caption,
## the slash carries off), driven through their focus target's `pressed`; Resume / Quit are PixelButtons.

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


func _toggle(path: String) -> MenuToggle:
	return _panel.get_node(path) as MenuToggle


## A user flip, as Enter or a click on the toggle's button does it.
func _flip(path: String) -> void:
	_toggle(path).get_focus_target().pressed.emit()


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
	assert_true(_toggle("%MusicToggle").is_on())
	assert_false(_toggle("%SoundToggle").is_on())
	assert_signal_emit_count(_panel, "music_toggled", 0, "open never emits a toggle")
	assert_signal_emit_count(_panel, "sound_toggled", 0, "open never emits a toggle")


func test_reopen_shows_new_settings() -> void:
	_panel.open(true, true)
	_panel.close()
	_panel.open(false, true)
	assert_false(_toggle("%MusicToggle").is_on())
	assert_signal_emit_count(_panel, "music_toggled", 0)


func test_labels() -> void:
	assert_eq((_panel.get_node("%Title") as Label).text, "Paused")
	assert_eq(_button("%ResumeButton").text, "Resume")
	assert_eq(_button("%QuitButton").text, "Quit to Menu")
	assert_eq((_toggle("%MusicToggle").get_node("%Caption") as Label).text, "Music")
	assert_eq((_toggle("%SoundToggle").get_node("%Caption") as Label).text, "Sound")
	assert_true(_button("%ResumeButton") is PixelButton)
	assert_true(_button("%QuitButton") is PixelButton)


func test_resume_and_quit_emit_once() -> void:
	_panel.open(true, true)
	_button("%ResumeButton").pressed.emit()
	assert_signal_emit_count(_panel, "resume_chosen", 1)
	_button("%QuitButton").pressed.emit()
	assert_signal_emit_count(_panel, "quit_chosen", 1)


func test_presses_while_closed_emit_nothing() -> void:
	_button("%ResumeButton").pressed.emit()
	_button("%QuitButton").pressed.emit()
	_toggle("%MusicToggle").flipped.emit(false)
	assert_signal_emit_count(_panel, "resume_chosen", 0)
	assert_signal_emit_count(_panel, "quit_chosen", 0)
	assert_signal_emit_count(_panel, "music_toggled", 0)


func test_music_toggle() -> void:
	_panel.open(true, true)
	_flip("%MusicToggle")
	assert_signal_emitted_with_parameters(_panel, "music_toggled", [false])
	assert_false(_toggle("%MusicToggle").is_on())
	_flip("%MusicToggle")
	assert_signal_emitted_with_parameters(_panel, "music_toggled", [true])
	assert_true(_toggle("%MusicToggle").is_on())


func test_sound_toggle() -> void:
	_panel.open(true, true)
	_flip("%SoundToggle")
	assert_signal_emitted_with_parameters(_panel, "sound_toggled", [false])
	assert_false(_toggle("%SoundToggle").is_on())
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


## Up / Down: Resume -> Quit -> the toggle row -> Resume; Left / Right between the two toggles.
func test_focus_moves_between_buttons_and_the_toggle_row() -> void:
	var resume: Button = _button("%ResumeButton")
	var quit_button: Button = _button("%QuitButton")
	var music: Button = _toggle("%MusicToggle").get_focus_target()
	var sound: Button = _toggle("%SoundToggle").get_focus_target()
	for button: Button in [resume, quit_button, music, sound]:
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "%s focusable" % button.name)
	assert_eq(resume.get_node(resume.focus_neighbor_bottom), quit_button)
	assert_eq(quit_button.get_node(quit_button.focus_neighbor_bottom), music)
	assert_eq(music.get_node(music.focus_neighbor_bottom), resume, "wraps")
	assert_eq(sound.get_node(sound.focus_neighbor_bottom), resume, "wraps")
	assert_eq(resume.get_node(resume.focus_neighbor_top), music, "wraps")
	assert_eq(music.get_node(music.focus_neighbor_top), quit_button)
	assert_eq(sound.get_node(sound.focus_neighbor_top), quit_button)
	assert_eq(music.get_node(music.focus_neighbor_right), sound)
	assert_eq(music.get_node(music.focus_neighbor_left), sound)
	assert_eq(sound.get_node(sound.focus_neighbor_left), music)


## The 4.2 decision holds: a MenuToggle keeps the state itself (not toggle_mode).
func test_toggles_are_menu_toggles() -> void:
	assert_true(_panel.get_node("%MusicToggle") is MenuToggle)
	assert_true(_panel.get_node("%SoundToggle") is MenuToggle)
	assert_false(_toggle("%MusicToggle").get_focus_target().toggle_mode)


func test_button_sizes() -> void:
	for path: String in ["%ResumeButton", "%QuitButton"]:
		assert_eq(_button(path).size, Vector2(240, 32), path)
	for path: String in ["%MusicToggle", "%SoundToggle"]:
		assert_eq(_toggle(path).get_focus_target().size, Vector2(32, 32), path)


## The toggle row sits inside the stone panel, below Quit.
func test_toggle_row_inside_the_panel() -> void:
	var panel: Rect2 = (_panel.get_node("%Panel") as Control).get_global_rect()
	var quit_rect: Rect2 = _button("%QuitButton").get_global_rect()
	for path: String in ["%MusicToggle", "%SoundToggle"]:
		var rect: Rect2 = _toggle(path).get_global_rect()
		assert_true(panel.encloses(rect), path)
		assert_gt(rect.position.y, quit_rect.end.y, "%s below Quit" % path)


func test_readable_text_and_glyphs() -> void:
	var font: Font = (load(THEME_PATH) as Theme).default_font
	for node: Node in _panel.find_children("*", "Label", true, false):
		var label: Label = node as Label
		var size: int = label.get_theme_font_size("font_size")
		assert_true(size >= 16 and size % 8 == 0, "%s font size %d" % [label.name, size])
	assert_eq((_panel.get_node("%Title") as Label).get_theme_font_size("font_size"), 24)
	for path: String in ["%ResumeButton", "%QuitButton"]:
		var size: int = _button(path).get_theme_font_size("font_size")
		assert_true(size >= 16 and size % 8 == 0, "%s font size %d" % [path, size])
	var strings: Array[String] = [
		"Paused", "Resume", "Quit to Menu", "Music", "Sound",
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
