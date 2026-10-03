extends Control
## Placeholder main menu (Story 1.3): walks the FR24 screen flow. Story 4.2 builds the real one
## and must keep the FR27 storage notice (Story 1.7): a non-interactive corner note shown only when
## WebPlatform.is_storage_persistent() is false.

const STORAGE_NOTICE_TEXT: String = "Progress may not be saved in this browser mode"


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%PlayButton.pressed.connect(_on_play_button_pressed)
	%ClosetButton.pressed.connect(_on_closet_button_pressed)
	%GiftButton.pressed.connect(_on_gift_button_pressed)
	%KeyboardTestButton.pressed.connect(_on_keyboard_test_button_pressed)
	%StorageNoticeLabel.text = STORAGE_NOTICE_TEXT
	_show_storage_notice(WebPlatform.is_storage_persistent())
	%PlayButton.grab_focus()


func _show_storage_notice(persistent: bool) -> void:
	%StorageNotice.visible = not persistent


func _on_play_button_pressed() -> void:
	Router.go(Router.Screen.RUN, {"level_id": &"zombie_run"})


func _on_closet_button_pressed() -> void:
	Router.go(Router.Screen.CRYPT_CLOSET)


func _on_gift_button_pressed() -> void:
	Router.go(Router.Screen.WELCOME_GIFT)


func _on_keyboard_test_button_pressed() -> void:
	Router.go(Router.Screen.KEYBOARD_TEST)
