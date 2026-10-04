class_name TypingInput
extends Node
## First stage of the typing pipeline: InputEventKey -> filter -> case rule -> char_typed.
## TypingSession (Story 2.2) judges what this emits. This node never judges, never touches
## the clock and never knows the target. Its only autoload use is the Log helper.

## Emitted for every character that counts as typing (already lowercased in lowercase levels).
signal char_typed(c: String)
## Emitted once after CAPS_HINT_STREAK capitals in a row in a lowercase level.
signal caps_lock_suspected
## Emitted on the first lowercase letter after caps_lock_suspected.
signal caps_lock_cleared

## Consecutive capitals that suggest Caps Lock is on (FR5). A fixed GDD rule, not a balance number.
const CAPS_HINT_STREAK: int = 3

## When false, handle_key() emits nothing and returns false, so _unhandled_input no longer marks keys
## handled. RunFrame turns it off when the run ends (Story 2.4).
var active: bool = true

var _case_sensitive: bool = false
var _space_is_input: bool = false
var _capital_streak: int = 0
var _caps_suspected: bool = false


## Applies the level's case and Space rules and silently resets the Caps Lock hint.
func configure(config: LevelConfig) -> void:
	assert(config != null, "TypingInput.configure() needs a LevelConfig")
	if config == null:
		Log.error(&"typing", "configure() called with a null LevelConfig; keeping current settings")
		return
	_case_sensitive = config.case_sensitive
	_space_is_input = config.space_is_input
	_capital_streak = 0
	_caps_suspected = false


## Filters one key event. Returns true only when char_typed was emitted.
func handle_key(event: InputEventKey) -> bool:
	if not active:
		return false
	if event == null or not event.pressed or event.echo:
		return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return false
	if event.keycode in GameConstants.IGNORED_KEYCODES:
		return false
	if event.keycode >= GameConstants.FUNCTION_KEY_FIRST and event.keycode <= GameConstants.FUNCTION_KEY_LAST:
		return false
	if event.unicode == 0:
		return false
	if event.unicode < 32 or (event.unicode >= 127 and event.unicode <= 159):
		return false
	if (event.unicode >= 0xD800 and event.unicode <= 0xDFFF) or event.unicode > 0x10FFFF:
		return false
	var raw: String = String.chr(event.unicode)
	if raw == " " and not _space_is_input:
		return false
	var c: String = raw
	if not _case_sensitive:
		c = raw.to_lower()
	if c.length() != 1:
		return false
	if not _case_sensitive:
		_update_caps_hint(raw)
	if Log.verbose_typing:
		Log.debug(&"typing", "typed '%s'" % c)
	char_typed.emit(c)
	return true


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	if handle_key(key):
		get_viewport().set_input_as_handled()


func _update_caps_hint(raw: String) -> void:
	if raw != raw.to_lower():
		_capital_streak += 1
		if _capital_streak >= CAPS_HINT_STREAK and not _caps_suspected:
			_caps_suspected = true
			caps_lock_suspected.emit()
	elif raw != raw.to_upper():
		_capital_streak = 0
		if _caps_suspected:
			_caps_suspected = false
			caps_lock_cleared.emit()
