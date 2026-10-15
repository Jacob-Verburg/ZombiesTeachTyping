extends Control
## Title screen: any key press (except Esc) or click goes on, once (FR23): to the "Name your zombie!" screen
## when the active zombie has no name yet (Story 11.1, FR78: an MVP save or a brand-new one), else to the main
## menu. next_screen() makes that choice. That same input unlocks browser audio, so the unlock must stay inside
## the input callback. player_data is a test seam (defaults to the PlayerData autoload in _ready).

const WHEEL_BUTTONS: Array[MouseButton] = [
	MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
]

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")

## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null

var _advanced: bool = false


func _ready() -> void:
	if player_data == null:
		player_data = PlayerData
	# Audio is still locked here, so this only marks the loop pending; unlock() starts it (FR47).
	AudioManager.play_music(&"mus_menu")


func _unhandled_input(event: InputEvent) -> void:
	if _advanced or not _is_advance_event(event):
		return
	_advanced = true
	get_viewport().set_input_as_handled()
	AudioManager.unlock()
	AudioManager.play_sfx(&"sfx_ui_click")
	Router.go(next_screen())


## Where the title goes: NAME_ZOMBIE while the active zombie has no (valid) name, else MAIN_MENU.
func next_screen() -> Router.Screen:
	if player_data.get_zombie_name().is_empty():
		return Router.Screen.NAME_ZOMBIE
	return Router.Screen.MAIN_MENU


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
