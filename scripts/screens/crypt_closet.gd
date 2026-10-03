extends Control
## Placeholder crypt closet (Story 1.3): walks the FR24 screen flow. Story 4.4 builds the real one.


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%BackButton.pressed.connect(_on_back_button_pressed)
	%BackButton.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.go(Router.Screen.MAIN_MENU)


func _on_back_button_pressed() -> void:
	Router.go(Router.Screen.MAIN_MENU)
