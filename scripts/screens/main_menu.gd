extends Control
## Placeholder main menu (Story 1.3): walks the FR24 screen flow. Story 4.2 builds the real one.


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%PlayButton.pressed.connect(_on_play_button_pressed)
	%ClosetButton.pressed.connect(_on_closet_button_pressed)
	%GiftButton.pressed.connect(_on_gift_button_pressed)
	%PlayButton.grab_focus()


func _on_play_button_pressed() -> void:
	Router.go(Router.Screen.RUN, {"level_id": &"zombie_run"})


func _on_closet_button_pressed() -> void:
	Router.go(Router.Screen.CRYPT_CLOSET)


func _on_gift_button_pressed() -> void:
	Router.go(Router.Screen.WELCOME_GIFT)
