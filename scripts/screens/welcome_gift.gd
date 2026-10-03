extends Control
## Placeholder welcome gift (Story 1.3): walks the FR24 screen flow. Story 4.5 builds the real one.


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%OpenClosetButton.pressed.connect(_on_open_closet_button_pressed)
	%OpenClosetButton.grab_focus()


func _on_open_closet_button_pressed() -> void:
	Router.go(Router.Screen.CRYPT_CLOSET)
