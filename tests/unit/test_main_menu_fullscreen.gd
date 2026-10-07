extends GutTest
## The main-menu Fullscreen toggle follows the real window mode (Story 5.5, F1 from 5.3). The fake window
## applies a flip LAND_FRAMES process frames after toggle_fullscreen is called, as the browser (and maybe the
## desktop) does, or never (a refused request). The menu processes here, so the icon must follow the mode on
## its own: no test calls _sync_fullscreen. The live Router, window and save are never touched.

const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_main_menu_fullscreen/"
## How late the fake window applies a flip.
const LAND_FRAMES: int = 5

var _menu: MainMenuScript
var _player: PlayerDataScript
## The fake window: the mode it is in, the mode a flip asked for and the frame it lands on (-1: none pending).
var _fullscreen: bool = false
var _requested: bool = false
var _land_frame: int = -1
## A refusing window (the browser said no): toggle_fullscreen is counted but the mode never changes.
var _refuse: bool = false
var _toggles: int = 0


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_fullscreen = false
	_land_frame = -1
	_refuse = false
	_toggles = 0
	_player = _make_player_data()


func after_each() -> void:
	Router.take_payload()
	_clear()
	_menu = null
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make_player_data() -> PlayerDataScript:
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	add_child_autofree(player)
	return player


## The fake window's mode as the engine would report it this frame.
func _read_mode() -> bool:
	if _land_frame >= 0 and Engine.get_process_frames() >= _land_frame:
		_fullscreen = _requested
		_land_frame = -1
	return _fullscreen


## A processing menu with every seam injected.
func _make() -> MainMenuScript:
	var menu: MainMenuScript = MenuScene.instantiate() as MainMenuScript
	menu.navigate = func(_screen: int, _payload: Dictionary) -> void: pass
	menu.is_transitioning = func() -> bool: return false
	menu.player_data = _player
	(menu.get_node("%PetSlot") as PetSlot).player_data = _player
	(menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).player_data = _player
	menu.toggle_fullscreen = func() -> void:
		_toggles += 1
		if _refuse:
			return
		_requested = not _read_mode()
		_land_frame = Engine.get_process_frames() + LAND_FRAMES
	menu.is_fullscreen = _read_mode
	add_child_autofree(menu)
	_menu = menu
	return menu


func _toggle() -> MenuToggle:
	return _menu.get_node("%FullscreenToggle") as MenuToggle


func _press() -> void:
	_toggle().get_focus_target().pressed.emit()


func test_icon_follows_a_late_flip_into_and_out_of_fullscreen() -> void:
	_make()
	assert_false(_toggle().is_on(), "windowed on open")
	_press()
	assert_true(_toggle().is_on(), "the press shows the asked-for state at once")
	await wait_process_frames(2)
	assert_false(_read_mode(), "the fake window has not switched yet")
	assert_true(_toggle().is_on(), "no flicker back to the stale state while the switch is on its way")
	await wait_process_frames(LAND_FRAMES + 2)
	assert_true(_read_mode(), "the fake window switched")
	assert_true(_toggle().is_on(), "on once fullscreen lands")
	_press()
	await wait_process_frames(LAND_FRAMES + 2)
	assert_false(_read_mode(), "the fake window switched back")
	assert_false(_toggle().is_on(), "off once it is windowed again")
	assert_eq(_toggles, 2, "one toggle call per press")


func test_icon_returns_to_the_real_state_when_the_request_is_refused() -> void:
	_refuse = true
	_make()
	_press()
	assert_true(_toggle().is_on(), "optimistic on the press")
	await wait_process_frames(MainMenuScript.FULLSCREEN_SETTLE_FRAMES + 5)
	assert_false(_toggle().is_on(), "the window never switched, so the slash comes back")
	assert_eq(_toggles, 1, "a refused request is not retried")


func test_icon_follows_the_browsers_own_exit_without_a_press() -> void:
	_fullscreen = true
	_make()
	assert_true(_toggle().is_on())
	_fullscreen = false  # Esc in the browser left fullscreen; no size_changed in viewport stretch
	await wait_process_frames(2)
	assert_false(_toggle().is_on(), "the slash shows without a press")
	_fullscreen = true  # F11 or the OS put it back
	await wait_process_frames(2)
	assert_true(_toggle().is_on())
	assert_eq(_toggles, 0, "following the mode never calls the toggle")


func test_leaving_menu_stops_following_the_mode() -> void:
	_make()
	_menu.call("_leave", Router.Screen.CRYPT_CLOSET, {})
	_fullscreen = true
	await wait_process_frames(2)
	assert_false(_toggle().is_on(), "nothing moves after the one navigation")
