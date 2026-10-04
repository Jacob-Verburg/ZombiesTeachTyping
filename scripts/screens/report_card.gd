extends Control
## Placeholder report card (Story 1.3): walks the FR24 screen flow. Story 2.9 builds the real one.
## Since Story 2.4 it lists a RunResult's stats as plain lines and Play Again replays its level.

## Level replayed by Play Again when the payload has no result.
const FALLBACK_LEVEL_ID: StringName = &"zombie_run"

var _level_id: StringName = FALLBACK_LEVEL_ID


func _ready() -> void:
	var payload: Dictionary = Router.take_payload()
	var raw: Variant = payload.get("result")
	if raw is RunResult:
		var result: RunResult = raw
		_level_id = result.level_id
		%PayloadLabel.text = _stats_text(result)
	else:
		%PayloadLabel.text = "" if payload.is_empty() else str(payload)
	%PlayAgainButton.pressed.connect(_on_play_again_button_pressed)
	%MenuButton.pressed.connect(_on_menu_button_pressed)
	%MenuButton.grab_focus()


static func _stats_text(result: RunResult) -> String:
	return "\n".join([
		"Keys Typed: %d" % result.keys_typed,
		"Errors: %d" % result.errors,
		"WPM: %d" % result.wpm,
		"Accuracy: %d%%" % result.accuracy,
		"Lesson Time: %s" % result.lesson_time(),
		"Brains: %d" % result.total_brains(),
	])


func _on_play_again_button_pressed() -> void:
	Router.go(Router.Screen.RUN, {"level_id": _level_id})


func _on_menu_button_pressed() -> void:
	Router.go(Router.Screen.MAIN_MENU)
