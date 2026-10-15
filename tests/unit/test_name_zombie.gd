extends GutTest
## The "Name your zombie!" screen (Story 11.1, FR78): typing rules on screen, Done (Enter or a click) saves and
## goes to the main menu once, an empty Done only wiggles, Esc does nothing, Space never presses the focused
## button, the payload is consumed, capture_keys is on while open, and the layout (24 px name, one focusable
## control, the widest name fits).
## Always a temp-dir SaveService + PlayerData and recorder seams: the real save and the live Router are never
## touched. Instances are disabled and handlers are called directly, except the Space/Enter tests that push
## real events through the viewport (navigate is still a recorder there).

const NameZombieScene: PackedScene = preload("res://scenes/screens/name_zombie.tscn")
const NameZombieScript := preload("res://scripts/screens/name_zombie.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_name_zombie/"
const SAFE_RECT: Rect2 = Rect2(16, 16, 608, 328)


## A SaveService that counts request_save() calls.
class CountingSave extends SaveServiceScript:
	var requests: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()


var _save: CountingSave
var _player: PlayerDataScript
var _screen: NameZombieScript
var _nav: Array = []
var _sfx: Array[StringName] = []
var _music: Array[StringName] = []
var _transitioning: bool = false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_sfx = []
	_music = []
	_transitioning = false
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)


func after_each() -> void:
	Router.take_payload()
	_clear()
	_reset_input_handled()
	_screen = null
	_player = null
	_save = null


## Calling _unhandled_input() by hand marks GUT's viewport input as handled, and headless no real event ever
## clears it. Pushing a no-op event resets the flag so later tests start clean.
func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make(enabled: bool = false) -> NameZombieScript:
	var screen: NameZombieScript = NameZombieScene.instantiate() as NameZombieScript
	if not enabled:
		screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.navigate = func(target: int, payload: Dictionary) -> void:
		_nav.append([target, payload])
		_transitioning = true  # the real Router starts its transition synchronously
	screen.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	screen.play_music = func(id: StringName) -> void: _music.append(id)
	screen.is_transitioning = func() -> bool: return _transitioning
	screen.player_data = _player
	add_child_autofree(screen)
	_screen = screen
	return screen


## A key press as the OS sends it: keycode plus the typed character (unicode), Shift for capitals.
func _key(keycode: Key, text: String = "", pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	if not text.is_empty():
		event.unicode = text.unicode_at(0)
		event.shift_pressed = text != text.to_lower()
	return event


func _letter(c: String) -> InputEventKey:
	return _key(OS.find_keycode_from_string(c.to_upper()), c)


func _type(screen: NameZombieScript, text: String) -> void:
	for i: int in text.length():
		var c: String = text[i]
		if c == " ":
			screen._input(_key(KEY_SPACE, " "))
		else:
			screen._unhandled_input(_letter(c))


func _enter(screen: NameZombieScript) -> void:
	screen._unhandled_input(_key(KEY_ENTER))


# --- typing ---------------------------------------------------------------------

func test_typing_shows_the_letters_as_typed() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "Sam")
	assert_eq(screen.get_text(), "Sam")
	assert_eq((screen.get_node("%NameLabel") as Label).text, "Sam")


func test_ignored_keys_add_nothing() -> void:
	var screen: NameZombieScript = _make()
	screen._input(_key(KEY_SPACE, " "))
	assert_eq(screen.get_text(), "", "no leading space")
	_type(screen, "Sam")
	screen._unhandled_input(_key(KEY_7, "7"))
	screen._unhandled_input(_key(KEY_EXCLAM, "!"))
	screen._unhandled_input(_key(KEY_E, "é"))
	screen._unhandled_input(_key(KEY_TAB))
	screen._unhandled_input(_key(KEY_LEFT))
	var echo: InputEventKey = _letter("m")
	echo.echo = true
	screen._unhandled_input(echo)
	var ctrl_a: InputEventKey = _letter("a")
	ctrl_a.ctrl_pressed = true
	screen._unhandled_input(ctrl_a)
	var alt_b: InputEventKey = _letter("b")
	alt_b.alt_pressed = true
	screen._unhandled_input(alt_b)
	var release: InputEventKey = _key(KEY_Z, "z", false)
	screen._unhandled_input(release)
	assert_eq(screen.get_text(), "Sam")
	screen._input(_key(KEY_SPACE, " "))
	screen._input(_key(KEY_SPACE, " "))
	assert_eq(screen.get_text(), "Sam ", "no double space")
	assert_eq(_sfx, [] as Array[StringName], "ignored keys are silent")
	assert_eq(_nav, [], "and never navigate")


func test_thirteenth_letter_is_ignored() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "WWWWWWWWWWWWW")
	assert_eq(screen.get_text(), "WWWWWWWWWWWW")


func test_backspace() -> void:
	var screen: NameZombieScript = _make()
	screen._unhandled_input(_key(KEY_BACKSPACE))
	assert_eq(screen.get_text(), "")
	_type(screen, "Sam")
	screen._unhandled_input(_key(KEY_BACKSPACE))
	assert_eq(screen.get_text(), "Sa")


func test_caret_follows_the_text_and_hides_when_full() -> void:
	var screen: NameZombieScript = _make()
	var caret: Control = screen.get_node("%Caret")
	assert_true(caret.visible)
	assert_eq(caret.position.x, NameZombieScript.TEXT_INSET_PX)
	_type(screen, "Sam")
	assert_eq(caret.position.x, NameZombieScript.TEXT_INSET_PX + 3 * 24.0, "one 24 px glyph per letter")
	_type(screen, "WWWWWWWWW")
	assert_false(caret.visible, "full: no caret")


# --- Done -------------------------------------------------------------------------

func test_enter_with_an_empty_name_saves_the_default_and_goes_on() -> void:
	var screen: NameZombieScript = _make()
	assert_true(screen.is_done_off(), "Done wears its off look while empty")
	_enter(screen)
	assert_eq(_player.get_zombie_name(), GameConstants.ZOMBIE_NAME_DEFAULT)
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]], "nobody is stuck on the name screen")
	assert_false(screen.is_wiggling())


func test_wiggle_returns_the_field_to_rest() -> void:
	var screen: NameZombieScript = _make(true)
	var field: Control = screen.get_node("%NameField")
	var rest: float = field.position.x
	screen._wiggle()
	screen._wiggle()
	await wait_seconds(NameZombieScript.WIGGLE_S + 0.1)
	assert_eq(field.position.x, rest, "mashing never drifts the field")


func test_a_space_alone_never_makes_a_name() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, " ")
	assert_eq(screen.get_text(), "", "a leading space is refused")
	_enter(screen)
	assert_eq(_player.get_zombie_name(), GameConstants.ZOMBIE_NAME_DEFAULT, "never a blank name")


func test_a_trailing_space_cannot_take_the_last_slot() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "WWWWWWWWWWW ")
	assert_eq(screen.get_text(), "WWWWWWWWWWW", "the 12th slot stays free for a letter")
	_type(screen, "W")
	assert_eq(screen.get_text(), "WWWWWWWWWWWW")


func test_surrogate_and_out_of_range_codes_are_ignored() -> void:
	var screen: NameZombieScript = _make()
	for code: int in [0xD800, 0xDFFF, 0x110000]:
		var event: InputEventKey = InputEventKey.new()
		event.pressed = true
		event.unicode = code
		screen._unhandled_input(event)
	assert_eq(screen.get_text(), "")


func test_a_replaced_profile_is_shown() -> void:
	var screen: NameZombieScript = _make(true)
	_type(screen, "Old")
	_player.set_zombie_name("Bones")
	_player.reset_all()
	assert_eq(screen.get_text(), "", "reset_all clears the name and the screen follows")


func test_enter_with_a_name_saves_and_goes_to_the_menu_once() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "Sam ")
	assert_false(screen.is_done_off(), "Done lights up")
	_enter(screen)
	assert_eq(_player.get_zombie_name(), "Sam", "saved without the trailing space")
	assert_eq(_save.requests, 1)
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	_enter(screen)
	screen._submit()
	_type(screen, "x")
	assert_eq(_nav.size(), 1, "exactly once")
	assert_eq(_save.requests, 1)
	assert_eq(screen.get_text(), "Sam ", "no typing after Done")


func test_done_button_press_saves_and_navigates() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "Bo")
	(screen.get_node("%DoneButton") as Button).pressed.emit()
	assert_eq(_player.get_zombie_name(), "Bo")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_done_during_a_transition_does_nothing() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "Bo")
	_transitioning = true
	_enter(screen)
	assert_eq(_nav, [])
	assert_eq(_player.get_zombie_name(), "")


func test_guard_is_released_when_the_transition_ends_without_leaving() -> void:
	var screen: NameZombieScript = _make(true)
	screen.is_transitioning = func() -> bool: return _transitioning
	screen.navigate = func(target: int, payload: Dictionary) -> void:
		_nav.append([target, payload])
		_transitioning = true
	_type(screen, "Bo")
	screen._submit()
	assert_eq(_nav.size(), 1)
	_transitioning = false
	await wait_process_frames(2)
	screen._submit()
	assert_eq(_nav.size(), 2, "the screen is not left dead when the menu failed to load")


func test_guard_is_released_when_the_router_never_starts() -> void:
	var screen: NameZombieScript = _make()
	screen.navigate = func(target: int, payload: Dictionary) -> void: _nav.append([target, payload])
	_type(screen, "Bo")
	screen._submit()
	screen._submit()
	assert_eq(_nav.size(), 2, "a navigation that never began leaves the screen usable")


func test_escape_does_nothing() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "Bo")
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	screen._unhandled_input(_key(KEY_ESCAPE))
	assert_eq(_nav, [])
	assert_eq(screen.get_text(), "Bo")
	assert_eq(_sfx, [] as Array[StringName])


## Real events through the viewport: Space reaches _input before the focused button, so it types a space.
func test_space_with_done_focused_adds_a_space_and_never_navigates() -> void:
	var screen: NameZombieScript = _make(true)
	_type(screen, "Sam")
	assert_true((screen.get_node("%DoneButton") as Button).has_focus())
	get_viewport().push_input(_key(KEY_SPACE, " "))
	get_viewport().push_input(_key(KEY_SPACE, " ", false))
	await wait_process_frames(2)
	assert_eq(screen.get_text(), "Sam ")
	assert_eq(_nav, [], "Space never presses Done")
	assert_eq(_player.get_zombie_name(), "")


func test_real_enter_presses_done() -> void:
	var screen: NameZombieScript = _make(true)
	_type(screen, "Sam")
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_ENTER, "", false))
	await wait_process_frames(2)
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]], "once, whichever of the button or the screen takes Enter")
	assert_eq(_player.get_zombie_name(), "Sam")


func test_real_letters_type() -> void:
	var screen: NameZombieScript = _make(true)
	for c: String in ["B", "o"]:
		get_viewport().push_input(_letter(c))
		get_viewport().push_input(_key(_letter(c).keycode, c, false))
	await wait_process_frames(2)
	assert_eq(screen.get_text(), "Bo")


# --- open / close ---------------------------------------------------------------------

func test_payload_is_consumed_and_music_requested() -> void:
	Router._store_payload({"stale": true})
	_make()
	assert_eq(Router.take_payload(), {})
	assert_eq(_music, [&"mus_menu"] as Array[StringName])
	assert_eq(_nav, [])


func test_shows_an_existing_name() -> void:
	assert_true(_player.set_zombie_name("Sam"))
	var screen: NameZombieScript = _make()
	assert_eq(screen.get_text(), "Sam")


func test_capture_keys_on_while_open_and_off_after() -> void:
	assert_false(WebPlatform.capture_keys)
	var screen: NameZombieScript = _make()
	assert_true(WebPlatform.capture_keys)
	screen.queue_free()
	await get_tree().process_frame
	assert_false(WebPlatform.capture_keys)


# --- layout -----------------------------------------------------------------------------

func test_done_is_the_only_focusable_control_and_starts_focused() -> void:
	var screen: NameZombieScript = _make()
	var done: Button = screen.get_node("%DoneButton")
	assert_true(done.has_focus())
	assert_eq(done.focus_mode, Control.FOCUS_ALL)
	assert_false(done.disabled, "never disabled: Enter must keep working")
	assert_gte(done.size.y, 32.0)
	for node: Node in screen.find_children("*", "Control", true, false):
		if node != done:
			assert_eq((node as Control).focus_mode, Control.FOCUS_NONE, str(node.get_path()))


func test_name_text_is_24_px_and_copy_is_approved() -> void:
	var screen: NameZombieScript = _make()
	assert_eq((screen.get_node("%NameLabel") as Label).get_theme_font_size(&"font_size"), 24)
	assert_eq((screen.get_node("%Heading") as Label).text, "Name your zombie!")
	assert_eq((screen.get_node("%DoneButton") as Button).text, "Done")
	assert_eq((screen.get_node("%EnterKeycap") as Label).text, "Enter")


func test_widest_name_and_caret_fit_inside_the_field() -> void:
	var screen: NameZombieScript = _make()
	_type(screen, "WWWWWWWWWWW")
	var field: Control = screen.get_node("%NameField")
	var label: Label = screen.get_node("%NameLabel")
	var caret: Control = screen.get_node("%Caret")
	assert_true(caret.visible)
	var inner: Rect2 = Rect2(Vector2(8, 8), field.size - Vector2(16, 16))
	assert_true(inner.encloses(Rect2(caret.position, caret.size)), "caret after 11 letters: %s" % Rect2(caret.position, caret.size))
	_type(screen, "W")
	var font: Font = label.get_theme_font(&"font")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	assert_lte(label.position.x + width, field.size.x - 8.0, "12 W fit inside the frame")
	assert_lte(width, label.size.x)


func test_everything_sits_inside_the_safe_rect() -> void:
	var screen: NameZombieScript = _make()
	for path: String in ["%Sign", "%NameField", "%DoneButton", "%EnterKeycap"]:
		var control: Control = screen.get_node(path)
		assert_true(SAFE_RECT.encloses(control.get_global_rect()), "%s %s" % [path, control.get_global_rect()])
