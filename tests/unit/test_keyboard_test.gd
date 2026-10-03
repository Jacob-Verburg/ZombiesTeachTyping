extends GutTest
## Keyboard test screen (Story 1.5): capture_keys lifecycle, echo rule, focus-free buttons.

const SCENE_PATH: String = "res://scenes/screens/keyboard_test.tscn"
const KeyboardTestScript := preload("res://scripts/screens/keyboard_test.gd")


func after_each() -> void:
	WebPlatform.capture_keys = false


func _key(keycode: Key, unicode: int = 0, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.unicode = unicode
	event.pressed = pressed
	event.echo = echo
	return event


func _instance() -> Control:
	var node: Control = (load(SCENE_PATH) as PackedScene).instantiate() as Control
	node.process_mode = Node.PROCESS_MODE_DISABLED
	return node


func test_sets_capture_keys_for_its_lifetime() -> void:
	assert_false(WebPlatform.capture_keys)
	var node: Control = _instance()
	add_child(node)
	assert_true(WebPlatform.capture_keys)
	remove_child(node)
	node.free()
	assert_false(WebPlatform.capture_keys)


func test_freeing_while_in_tree_restores_capture_keys() -> void:
	var node: Control = _instance()
	add_child(node)
	node.queue_free()
	await wait_frames(2)
	assert_false(WebPlatform.capture_keys)


func test_apply_key_appends_printable_characters() -> void:
	var text: String = ""
	text = KeyboardTestScript.apply_key(text, _key(KEY_A, 97))
	text = KeyboardTestScript.apply_key(text, _key(KEY_APOSTROPHE, 39))
	text = KeyboardTestScript.apply_key(text, _key(KEY_SLASH, 47))
	text = KeyboardTestScript.apply_key(text, _key(KEY_SPACE, 32))
	assert_eq(text, "a'/ ")


func test_apply_key_backspace_removes_last_and_is_safe_on_empty() -> void:
	assert_eq(KeyboardTestScript.apply_key("ab", _key(KEY_BACKSPACE)), "a")
	assert_eq(KeyboardTestScript.apply_key("", _key(KEY_BACKSPACE)), "")


func test_apply_key_ignores_echo_release_modifiers_tab_and_escape() -> void:
	assert_eq(KeyboardTestScript.apply_key("x", _key(KEY_A, 97, true, true)), "x")
	assert_eq(KeyboardTestScript.apply_key("x", _key(KEY_A, 97, false)), "x")
	assert_eq(KeyboardTestScript.apply_key("x", _key(KEY_SHIFT)), "x")
	assert_eq(KeyboardTestScript.apply_key("x", _key(KEY_TAB, 9)), "x")
	assert_eq(KeyboardTestScript.apply_key("x", _key(KEY_ESCAPE, 27)), "x")


func test_echo_keeps_only_the_last_characters() -> void:
	var text: String = "a".repeat(KeyboardTestScript.ECHO_MAX_CHARS)
	text = KeyboardTestScript.apply_key(text, _key(KEY_B, 98))
	assert_eq(text.length(), KeyboardTestScript.ECHO_MAX_CHARS)
	assert_true(text.ends_with("b"))


func test_buttons_do_not_take_focus() -> void:
	var node: Control = _instance()
	add_child_autofree(node)
	for path: String in ["%FullscreenButton", "%DownloadButton", "%BackButton"]:
		var button: Button = node.get_node(path) as Button
		assert_eq(button.focus_mode, Control.FOCUS_NONE, path)


func test_apply_key_ignores_modifier_combos() -> void:
	for modifier: String in ["ctrl_pressed", "alt_pressed", "meta_pressed"]:
		var event: InputEventKey = _key(KEY_A, 97)
		event.set(modifier, true)
		assert_eq(KeyboardTestScript.apply_key("x", event), "x", modifier)
