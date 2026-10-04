extends GutTest
## Placeholder main menu: the FR27 storage notice (Story 1.7). Desktop storage is always persistent,
## so the hidden case is the real _ready() and the shown case calls the _show_storage_notice() seam.
## Debug-only "Test level" button (Story 2.4): the release case overrides the _is_debug_build() seam.
## Disabled instance: no real input can press a menu button (that would call the live Router).

const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")

var _menu: Control


## The menu as a release build sees it.
class ReleaseMenu extends MainMenuScript:
	func _is_debug_build() -> bool:
		return false


func before_each() -> void:
	_menu = MenuScene.instantiate() as Control
	_menu.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_menu)


func after_each() -> void:
	Router.take_payload()


func _notice() -> PanelContainer:
	return _menu.get_node("%StorageNotice") as PanelContainer


func test_notice_hidden_when_storage_is_persistent() -> void:
	assert_true(WebPlatform.is_storage_persistent(), "desktop storage is persistent")
	assert_false(_notice().visible)


func test_notice_shown_when_storage_is_not_persistent() -> void:
	_menu.call("_show_storage_notice", false)
	assert_true(_notice().visible)
	var label: Label = _menu.get_node("%StorageNoticeLabel") as Label
	assert_eq(label.text, "Progress may not be saved in this browser mode")
	assert_eq(MainMenuScript.STORAGE_NOTICE_TEXT, label.text)
	_menu.call("_show_storage_notice", true)
	assert_false(_notice().visible)


func test_notice_never_blocks_or_takes_focus() -> void:
	_menu.call("_show_storage_notice", false)
	assert_eq(_notice().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_menu.get_node("%StorageNoticeLabel") as Label).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_notice().focus_mode, Control.FOCUS_NONE)
	assert_true((_menu.get_node("%PlayButton") as Button).has_focus(), "Play keeps focus")


func _chord(keycode: Key, ctrl: bool, shift: bool, alt: bool = false, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.alt_pressed = alt
	event.pressed = pressed
	event.echo = echo
	return event


func test_export_chord_is_ctrl_shift_e_only() -> void:
	assert_true(MainMenuScript.is_export_chord(_chord(KEY_E, true, true)))
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, false, false)), "plain E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, false)), "Ctrl+E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, false, true)), "Shift+E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, true, true)), "Ctrl+Shift+Alt+E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_R, true, true)), "Ctrl+Shift+R")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, true, false, false)), "release")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, true, false, true, true)), "echo")
	var meta: InputEventKey = _chord(KEY_E, true, true)
	meta.meta_pressed = true
	assert_false(MainMenuScript.is_export_chord(meta), "Ctrl+Shift+Meta+E")


func test_test_level_button_in_debug_builds() -> void:
	var button: Button = _menu.get_node_or_null("%TestLevelButton") as Button
	assert_not_null(button)
	assert_eq(button.text, "Test level")
	assert_true(OS.is_debug_build(), "tests run in a debug build")
	assert_true(button.visible)
	assert_true((_menu.get_node("%PlayButton") as Button).has_focus(), "Play keeps focus")


func test_test_level_button_hidden_in_release_builds() -> void:
	var menu: Control = MenuScene.instantiate() as Control
	menu.set_script(ReleaseMenu)
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(menu)
	assert_false((menu.get_node("%TestLevelButton") as Button).visible)
	assert_true((menu.get_node("%PlayButton") as Button).visible)
