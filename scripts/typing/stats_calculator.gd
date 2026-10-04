class_name StatsCalculator
## The report card's formulas (FR7) in one place: Accuracy, WPM (with implied spaces) and Lesson Time (m:ss).
## Pure and static: no nodes, no autoloads, no clock. The live HUD WPM (Story 2.5), RunResult and the
## tier rolling average (Epic 7) all call it. Every result rounds down: a kid sees 100 % only with
## zero errors, and WPM never overstates.

## Characters per word in the standard WPM definition (a formula constant, not a balance number).
const CHARS_PER_WORD: int = 5
## Guards a float like 9.999999999 for a mathematically whole WPM (seconds are accumulated frame deltas).
const _EPSILON: float = 1e-9


## Keys ÷ (Keys + Errors) as a whole percent, rounded down. 0 when nothing was typed.
static func accuracy_percent(keys: int, errors: int) -> int:
	var k: int = _non_negative(keys, "keys")
	var e: int = _non_negative(errors, "errors")
	var total: int = k + e
	if total <= 0:
		return 0
	return floori(float(k) * 100.0 / float(total))


## Unrounded WPM: ((keys + completed_words) ÷ 5) ÷ minutes. Each completed word adds one implied
## space (word mode only). 0.0 for non-finite seconds, seconds below GameConstants.MIN_WPM_SECONDS
## (a near-instant run has no meaningful rate), or nothing counted.
static func wpm_exact(keys: int, seconds: float, completed_words: int = 0) -> float:
	var counted: int = _non_negative(keys, "keys") + _non_negative(completed_words, "completed_words")
	if not is_finite(seconds) or seconds < GameConstants.MIN_WPM_SECONDS or counted <= 0:
		return 0.0
	return float(counted) * 60.0 / (float(CHARS_PER_WORD) * seconds)


## Whole-number WPM, rounded down. Same rules as wpm_exact().
static func wpm(keys: int, seconds: float, completed_words: int = 0) -> int:
	return floori(wpm_exact(keys, seconds, completed_words) + _EPSILON)


## Lesson Time as "m:ss", whole seconds rounded down. Negative or non-finite input gives "0:00".
static func format_time(seconds: float) -> String:
	if not is_finite(seconds):
		return "0:00"
	var whole: int = maxi(0, floori(seconds))
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


## Negative counts are a caller bug: report it and treat the value as 0.
static func _non_negative(value: int, label: String) -> int:
	if value < 0:
		assert(false, "StatsCalculator got a negative %s" % label)
		Log.error(&"stats", "negative %s (%d) treated as 0" % [label, value])
		return 0
	return value
