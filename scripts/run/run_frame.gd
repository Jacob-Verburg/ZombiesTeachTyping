extends Control
## Placeholder run frame (Story 1.3): walks the FR24 screen flow. Story 2.4 replaces it.


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%FinishButton.pressed.connect(_on_finish_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	%FinishButton.grab_focus()


func _on_finish_button_pressed() -> void:
	Router.go(Router.Screen.REPORT_CARD, {"result": null})


func _on_quit_button_pressed() -> void:
	Router.go(Router.Screen.MAIN_MENU)
