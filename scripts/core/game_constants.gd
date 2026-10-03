class_name GameConstants
## Shared values that never change. Balancing numbers live in data/ Resources, not here.

const LOGICAL_SIZE: Vector2i = Vector2i(640, 360)
const RUN_HISTORY_CAP: int = 500
const CURRENT_SCHEMA: int = 1
## Keys that are never typing input, even if a platform reports a character for them (FR3).
## Function keys are a range; see FUNCTION_KEY_FIRST/LAST. Space is a per-level rule, not listed here.
const IGNORED_KEYCODES: Array[Key] = [
	KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META,
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_CAPSLOCK, KEY_ESCAPE,
]
## F1..F35 are consecutive in the Key enum and are never typing input (FR3).
const FUNCTION_KEY_FIRST: Key = KEY_F1
const FUNCTION_KEY_LAST: Key = KEY_F35
