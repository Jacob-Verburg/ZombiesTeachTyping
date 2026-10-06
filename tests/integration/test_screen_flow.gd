extends GutTest
## Every routed screen instantiates and reads its payload once (FR24 skeleton).
## Screens are instanced directly; Router.go() is never called (it would swap GUT's own scene).
## Instances are disabled so real input during the run can't press a focused button.
## RUN (Story 2.4) navigates on its own when it cannot start a level; its navigate seam gets a
## recorder before add_child, so the live Router never runs.

const FLOW_BUTTONS: Dictionary = {
	"MAIN_MENU": ["%ClosetButton"],
	"REPORT_CARD": ["%PlayAgainButton", "%MenuButton"],
	"WELCOME_GIFT": ["%OpenClosetButton"],
	"CRYPT_CLOSET": ["%BackButton"],
	"KEYBOARD_TEST": ["%FullscreenButton", "%DownloadButton", "%BackButton", "%BrainButton"],
}


var _nav: Array = []


# The keyboard test screen and the run frame set capture_keys in _ready(); every freed instance must have reset it.
# Checked before each test and after all, because autofree runs after after_each().
func before_each() -> void:
	assert_false(WebPlatform.capture_keys, "keyboard test left capture_keys on")
	_nav = []


func after_each() -> void:
	Router.take_payload()


func after_all() -> void:
	assert_false(WebPlatform.capture_keys, "keyboard test left capture_keys on")


func _instance(screen: Router.Screen) -> Control:
	var packed: PackedScene = load(Router.SCREEN_PATHS[screen]) as PackedScene
	var node: Control = packed.instantiate() as Control
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if screen == Router.Screen.RUN:
		node.set("navigate", _record)
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
