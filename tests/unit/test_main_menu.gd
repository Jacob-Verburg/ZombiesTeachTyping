extends GutTest
## Placeholder main menu: the FR27 storage notice (Story 1.7). Desktop storage is always persistent,
## so the hidden case is the real _ready() and the shown case calls the _show_storage_notice() seam.
## Disabled instance: no real input can press a menu button (that would call the live Router).

const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")

var _menu: Control


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
