extends GutTest
## Every routed screen instantiates and reads its payload once (FR24 skeleton).
## Screens are instanced directly; Router.go() is never called (it would swap GUT's own scene).
## Instances are disabled so real input during the run can't press a focused button.
## RUN (Story 2.4) navigates on its own when it cannot start a level; its navigate seam gets a
## recorder before add_child, so the live Router never runs.
## WELCOME_GIFT (Story 4.5) grants brains and sets a flag in _ready(), so it gets a temp-dir PlayerData and
## recorder seams before add_child: the real save is never written.

const FLOW_BUTTONS: Dictionary = {
	"MAIN_MENU": ["%ClosetButton"],
	"REPORT_CARD": ["%PlayAgainButton", "%MenuButton"],
	"WELCOME_GIFT": ["%OpenClosetButton"],
	"CRYPT_CLOSET": ["%MenuButton"],
	"KEYBOARD_TEST": ["%FullscreenButton", "%DownloadButton", "%BackButton", "%BrainButton"],
}


const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_screen_flow/"

var _nav: Array = []


# The keyboard test screen and the run frame set capture_keys in _ready(); every freed instance must have reset it.
# Checked before each test and after all, because autofree runs after after_each().
func before_each() -> void:
	assert_false(WebPlatform.capture_keys, "keyboard test left capture_keys on")
	_nav = []
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()


func after_each() -> void:
	Router.take_payload()
	_clear()


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


## A PlayerData on a temp-dir SaveService, so a screen that writes never reaches the real save.
func _temp_player_data() -> PlayerDataScript:
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	add_child_autofree(player)
	return player


func after_all() -> void:
	assert_false(WebPlatform.capture_keys, "keyboard test left capture_keys on")


func _instance(screen: Router.Screen) -> Control:
	var packed: PackedScene = load(Router.SCREEN_PATHS[screen]) as PackedScene
	var node: Control = packed.instantiate() as Control
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if screen == Router.Screen.RUN:
		node.set("navigate", _record)
	if screen == Router.Screen.WELCOME_GIFT:
		node.set("navigate", _record)
		node.set("play_sfx", func(_id: StringName) -> void: pass)
		node.set("player_data", _temp_player_data())
	add_child_autofree(node)
	return node


func _record(screen: int, payload: Dictionary) -> void:
	_nav.append([screen, payload])


func test_every_screen_instantiates() -> void:
	for screen: Router.Screen in Router.Screen.values():
		assert_not_null(_instance(screen), Router.Screen.keys()[screen])
	# RUN had no payload, so it logged and asked for the menu (through the recorder).
	assert_push_error("[ERROR][run]")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_placeholder_buttons_exist() -> void:
	for screen_name: String in FLOW_BUTTONS:
		var node: Control = _instance(Router.Screen[screen_name])
		for button_path: String in FLOW_BUTTONS[screen_name]:
			assert_true(node.get_node_or_null(button_path) is Button, "%s %s" % [screen_name, button_path])


func test_run_starts_level_from_payload_and_consumes_it() -> void:
	Router._store_payload({"level_id": &"test_level", "seed": 1})
	var run: Control = _instance(Router.Screen.RUN)
	assert_eq(Router.take_payload(), {})
	assert_not_null(run.call("get_session"), "the run built a typing session")
	assert_eq(_nav, [])


func test_run_with_empty_payload_returns_to_menu() -> void:
	var run: Control = _instance(Router.Screen.RUN)
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_null(run.call("get_session"))
	assert_push_error("[ERROR][run]")


## Story 4.2: the real menu has no payload label; it consumes whatever payload it was given.
func test_main_menu_consumes_the_payload() -> void:
	Router._store_payload({"stale": true})
	var menu: Control = _instance(Router.Screen.MAIN_MENU)
	assert_not_null(menu)
	assert_eq(Router.take_payload(), {})


## Story 4.4: the real Closet consumes whatever payload it was given (Story 4.5 reads its tutorial key).
func test_closet_consumes_the_payload() -> void:
	Router._store_payload({"stale": true})
	var closet: Control = _instance(Router.Screen.CRYPT_CLOSET)
	assert_not_null(closet)
	assert_eq(Router.take_payload(), {})


## Story 4.5: the real gift consumes whatever payload it was given (and grants into a temp save).
func test_welcome_gift_consumes_the_payload() -> void:
	Router._store_payload({"stale": true})
	var gift: Control = _instance(Router.Screen.WELCOME_GIFT)
	assert_not_null(gift)
	assert_eq(Router.take_payload(), {})
	var player: PlayerDataScript = gift.get("player_data")
	assert_eq(player.get_brains(), 100, "granted into the temp save, not the real one")


## Story 4.2 (closes the 3.1 deferral): the menu's Zombie Run card asks for a Zombie Run, and that
## payload starts the zombie_run level in a real RunFrame.
func test_menu_card_routes_to_a_zombie_run() -> void:
	var packed: PackedScene = load(Router.SCREEN_PATHS[Router.Screen.MAIN_MENU]) as PackedScene
	var menu: Control = packed.instantiate() as Control
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.set("navigate", _record)
	add_child_autofree(menu)
	var cards: Array[LevelCard] = menu.call("get_cards")
	cards[0]._activate()
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"zombie_run"}]])
	Router._store_payload(_nav[0][1])
	_nav = []
	var run: Control = _instance(Router.Screen.RUN)
	assert_eq(run.call("get_level_id"), &"zombie_run")
	assert_not_null(run.call("get_session"), "the run built a typing session")
	assert_eq(_nav, [], "the run started instead of bouncing back to the menu")


## Story 6.7: the Horde Rush card is available and its payload starts the horde_rush level in a real
## RunFrame.
func test_menu_card_routes_to_a_horde_rush() -> void:
	var packed: PackedScene = load(Router.SCREEN_PATHS[Router.Screen.MAIN_MENU]) as PackedScene
	var menu: Control = packed.instantiate() as Control
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.set("navigate", _record)
	add_child_autofree(menu)
	var cards: Array[LevelCard] = menu.call("get_cards")
	assert_eq(cards[1].get_level_id(), &"horde_rush")
	assert_eq(cards[1].get_state(), LevelCard.State.AVAILABLE)
	cards[1]._activate()
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"horde_rush"}]])
	Router._store_payload(_nav[0][1])
	_nav = []
	var run: Control = _instance(Router.Screen.RUN)
	assert_eq(run.call("get_level_id"), &"horde_rush")
	assert_not_null(run.call("get_session"), "the run built a typing session")
	assert_eq(_nav, [], "the run started instead of bouncing back to the menu")
