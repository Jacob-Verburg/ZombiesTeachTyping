extends GutTest
## Title screen structure and which input events advance it (FR23).
## The advance itself calls Router.go(), which is never triggered here (it would swap GUT's scene),
## so the instance is disabled: a real key or click during the run can't reach the live Router.

const TitleScene: PackedScene = preload("res://scenes/screens/title.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_title/"

var _title: Control


func before_each() -> void:
	_title = TitleScene.instantiate() as Control
	_title.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_title)
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()


func after_each() -> void:
	_clear()


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


## A title wired to a fresh PlayerData on a temp save (never the real one).
func _title_with_temp_player() -> Control:
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	add_child_autofree(player)
	var title: Control = TitleScene.instantiate() as Control
	title.process_mode = Node.PROCESS_MODE_DISABLED
	title.set("player_data", player)
	add_child_autofree(title)
	return title


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


## Story 5.0: the hand-lettered logo sprite, shown at 1x and centred.
func test_logo_is_the_ui_logo_texture() -> void:
	var logo: TextureRect = _title.get_node("%Logo") as TextureRect
	assert_not_null(logo)
	assert_eq(logo.texture.resource_path, "res://assets/sprites/ui/menu/ui_logo.png")
	assert_eq(logo.stretch_mode, TextureRect.STRETCH_KEEP_CENTERED, "1x, never scaled")


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


func test_title_requests_menu_music_on_ready() -> void:
	# The live AudioManager is never unlocked under GUT, so play_music() only marks the id pending.
	# Clear it, show a fresh title, and check the title asked for the menu loop (FR47: nothing plays yet).
	AudioManager.stop_music()
	assert_eq(AudioManager._pending_music, &"")
	var title: Control = TitleScene.instantiate() as Control
	title.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(title)
	assert_false(AudioManager.is_unlocked())
	assert_eq(AudioManager._pending_music, &"mus_menu")


# --- Story 11.1: an unnamed zombie goes to the name screen first ----------------------

func test_next_screen_is_the_name_screen_without_a_name() -> void:
	var title: Control = _title_with_temp_player()
	assert_eq(title.call("next_screen"), Router.Screen.NAME_ZOMBIE)


func test_next_screen_is_the_menu_with_a_name() -> void:
	var title: Control = _title_with_temp_player()
	var player: PlayerDataScript = title.get("player_data")
	assert_true(player.set_zombie_name("Sam"))
	assert_eq(title.call("next_screen"), Router.Screen.MAIN_MENU)


func test_next_screen_junk_name_goes_to_the_name_screen() -> void:
	var title: Control = _title_with_temp_player()
	var player: PlayerDataScript = title.get("player_data")
	player.save_service.get_active_profile()["name"] = "!!!"
	assert_eq(title.call("next_screen"), Router.Screen.NAME_ZOMBIE)
	player.save_service.get_active_profile()["name"] = 42
	assert_eq(title.call("next_screen"), Router.Screen.NAME_ZOMBIE)
