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
## Why a recorded run ended. timer: the level's clock reached its duration (Zombie Run, Horde Rush).
## caught / escaped: Pitchfork Panic. Quit runs are never recorded, so there is no quit reason.
const END_REASON_TIMER: StringName = &"timer"
const END_REASON_CAUGHT: StringName = &"caught"
const END_REASON_ESCAPED: StringName = &"escaped"
## Runs shorter than this many seconds report 0 WPM: a one-keystroke Pitchfork Panic run would
## otherwise show an absurd rate (1 key in 0.016 s = 750 WPM).
const MIN_WPM_SECONDS: float = 1.0
## FR8: the live WPM on the HUD stays hidden for the first this-many seconds of run time.
const LIVE_WPM_DELAY_S: float = 5.0
## FR8: after the delay, the live WPM refreshes once per this-many seconds of run time (1 Hz).
const LIVE_WPM_INTERVAL_S: float = 1.0
## FR2: how long the target glyph shakes after a wrong key.
const WRONG_KEY_SHAKE_S: float = 0.2
## FR12 / GDD M3: the resume countdown starts at this number ...
const COUNTDOWN_FROM: int = 3
## ... and shows each number for this many seconds, while the tree stays paused.
const COUNTDOWN_STEP_S: float = 0.5
