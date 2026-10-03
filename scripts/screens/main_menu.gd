extends Control
## Placeholder main menu (Story 1.3): walks the FR24 screen flow. Story 4.2 builds the real one
## and must keep the FR27 storage notice (Story 1.7): a non-interactive corner note shown only when
## WebPlatform.is_storage_persistent() is false.
## Hidden parent/dev save export (Story 1.8): Ctrl+Shift+E calls SaveService.offer_export() in every
## build, release included. Nothing on screen changes (no sound, label, focus or fade). Story 4.2 keeps it.

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


## Ctrl+Shift+E, pressed, not a repeat, no Alt/Meta.
static func is_export_chord(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.alt_pressed or event.meta_pressed:
		return false
	return event.keycode == KEY_E and event.ctrl_pressed and event.shift_pressed


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not is_export_chord(key):
		return
	get_viewport().set_input_as_handled()
	SaveService.offer_export()


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
