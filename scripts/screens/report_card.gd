extends Control
## Placeholder report card (Story 1.3): walks the FR24 screen flow. Story 2.9 builds the real one.


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%PlayAgainButton.pressed.connect(_on_play_again_button_pressed)
	%MenuButton.pressed.connect(_on_menu_button_pressed)
	%MenuButton.grab_focus()


func _on_play_again_button_pressed() -> void:
	Router.go(Router.Screen.RUN, {"level_id": &"zombie_run"})


func _on_menu_button_pressed() -> void:
	Router.go(Router.Screen.MAIN_MENU)
