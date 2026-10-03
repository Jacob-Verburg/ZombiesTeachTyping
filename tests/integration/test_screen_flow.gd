extends GutTest
## Every routed screen instantiates and reads its payload once (FR24 skeleton).
## Screens are instanced directly; Router.go() is never called (it would swap GUT's own scene).
## Instances are disabled so real input during the run can't press a focused button.

const FLOW_BUTTONS: Dictionary = {
	"MAIN_MENU": ["%PlayButton", "%ClosetButton", "%GiftButton", "%KeyboardTestButton"],
	"RUN": ["%FinishButton", "%QuitButton"],
	"REPORT_CARD": ["%PlayAgainButton", "%MenuButton"],
	"WELCOME_GIFT": ["%OpenClosetButton"],
	"CRYPT_CLOSET": ["%BackButton"],
	"KEYBOARD_TEST": ["%FullscreenButton", "%DownloadButton", "%BackButton", "%BrainButton"],
}


# The keyboard test screen sets capture_keys in _ready(); every freed instance must have reset it.
# Checked before each test and after all, because autofree runs after after_each().
func before_each() -> void:
	assert_false(WebPlatform.capture_keys, "keyboard test left capture_keys on")


func after_each() -> void:
	Router.take_payload()


func after_all() -> void:
	assert_false(WebPlatform.capture_keys, "keyboard test left capture_keys on")


func _instance(screen: Router.Screen) -> Control:
	var packed: PackedScene = load(Router.SCREEN_PATHS[screen]) as PackedScene
	var node: Control = packed.instantiate() as Control
	node.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(node)
	return node


func test_every_screen_instantiates() -> void:
	for screen: Router.Screen in Router.Screen.values():
		assert_not_null(_instance(screen), Router.Screen.keys()[screen])


func test_placeholder_buttons_exist() -> void:
	for screen_name: String in FLOW_BUTTONS:
		var node: Control = _instance(Router.Screen[screen_name])
		for button_path: String in FLOW_BUTTONS[screen_name]:
			assert_true(node.get_node_or_null(button_path) is Button, "%s %s" % [screen_name, button_path])


func test_run_shows_level_id_payload_and_consumes_it() -> void:
	Router._store_payload({"level_id": &"zombie_run"})
	var run: Control = _instance(Router.Screen.RUN)
	var label: Label = run.get_node("%PayloadLabel") as Label
	assert_string_contains(label.text, "zombie_run")
	assert_eq(Router.take_payload(), {})


func test_empty_payload_shows_nothing() -> void:
	var menu: Control = _instance(Router.Screen.MAIN_MENU)
	assert_eq((menu.get_node("%PayloadLabel") as Label).text, "")
