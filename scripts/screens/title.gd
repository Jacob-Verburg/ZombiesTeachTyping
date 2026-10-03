extends Control
## Title screen: any key press (except Esc) or click goes to the main menu, once (FR23).
## That same input unlocks browser audio, so the unlock must stay inside the input callback.

const WHEEL_BUTTONS: Array[MouseButton] = [
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
]

var _advanced: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if _advanced or not _is_advance_event(event):
		return
	_advanced = true
	get_viewport().set_input_as_handled()
	AudioManager.unlock()
	Router.go(Router.Screen.MAIN_MENU)


func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		# Escape isn't a browser user gesture, so it couldn't unlock audio.
		return key.pressed and not key.echo and key.keycode != KEY_ESCAPE
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		# Wheel "presses" aren't clicks and aren't browser user gestures either.
		return button.pressed and button.button_index not in WHEEL_BUTTONS
	return false
