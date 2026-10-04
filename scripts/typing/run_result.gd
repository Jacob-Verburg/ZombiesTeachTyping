class_name RunResult
extends RefCounted
## The result of one finished run. Built once by RunFrame at run end (Story 2.4) through create(),
## carried in the REPORT_CARD payload { "result": RunResult }, read by the report card (2.9) and saved
## through PlayerData.record_run(result) -> to_record() (2.8). Plain data plus two derived values
## (wpm, accuracy): no nodes, no autoloads, no clock, no file I/O.
## Fields are set by create() and read by everyone; nobody writes them afterwards.

## Level that produced the run, e.g. &"zombie_run".
var level_id: StringName = &""
## When the run ended, Unix seconds UTC (from the caller; RunResult never reads the clock).
var timestamp: int = 0
## Lesson Time in seconds: first correct key to run end, unrounded.
var duration_s: float = 0.0
## Correct keystrokes (a capital counts as 1).
var keys_typed: int = 0
## Wrong printable keystrokes.
var errors: int = 0
## Completed words, one implied space each for WPM (0 in letter mode). Not written to the record.
var completed_words: int = 0
## Whole-number WPM, computed by StatsCalculator.
var wpm: int = 0
## Whole-number accuracy percent, computed by StatsCalculator.
var accuracy: int = 0
## Brains earned in the level during the run, without the completion bonus.
var brains: int = 0
## Completion bonus brains (e.g. +10), shown on its own report-card line.
var bonus_brains: int = 0
## Letter pool or tier the run used; "all" in the MVP (Epic 7 decides the tier format).
var letter_pool_or_tier: String = ""
## expected char -> [attempts, errors, {typed char: count}]; a deep copy owned by this result.
var per_key: Dictionary = {}
## One of the GameConstants.END_REASON_* values.
var end_reason: StringName = &""


## Builds a result and computes wpm and accuracy. per_key is deep-copied. A bad level id or end
## reason is reported but kept: a run must never be lost to a bad label.
static func create(
		p_level_id: StringName, p_timestamp: int, p_duration_s: float, p_keys_typed: int,
		p_errors: int, p_per_key: Dictionary, p_brains: int, p_bonus_brains: int,
		p_letter_pool_or_tier: String, p_end_reason: StringName, p_completed_words: int = 0
) -> RunResult:
	if p_level_id == &"":
		assert(false, "RunResult needs a level id")
		Log.error(&"run", "RunResult built with an empty level_id")
	if p_end_reason not in [
			GameConstants.END_REASON_TIMER, GameConstants.END_REASON_CAUGHT,
			GameConstants.END_REASON_ESCAPED]:
		assert(false, "RunResult got an unknown end reason")
		Log.error(&"run", "RunResult built with unknown end_reason '%s'" % p_end_reason)
	var result: RunResult = RunResult.new()
	result.level_id = p_level_id
	result.timestamp = p_timestamp
	result.duration_s = p_duration_s
	result.keys_typed = p_keys_typed
	result.errors = p_errors
	result.completed_words = p_completed_words
	result.brains = p_brains
	result.bonus_brains = p_bonus_brains
	result.letter_pool_or_tier = p_letter_pool_or_tier
	result.per_key = p_per_key.duplicate(true)
	result.end_reason = p_end_reason
	result.wpm = StatsCalculator.wpm(p_keys_typed, p_duration_s, p_completed_words)
	result.accuracy = StatsCalculator.accuracy_percent(p_keys_typed, p_errors)
	return result


## All brains the run awarded: level brains plus the completion bonus.
func total_brains() -> int:
	return brains + bonus_brains


## Lesson Time as "m:ss".
func lesson_time() -> String:
	return StatsCalculator.format_time(duration_s)


## The save's run record (architecture Data Persistence). Every number is an int and ids are plain
## Strings, so JSON writes canonical whole numbers. bonus_brains and completed_words are not saved.
func to_record() -> Dictionary:
	return {
		"timestamp": timestamp,
		"level_id": String(level_id),
		"duration_s": maxi(0, floori(duration_s)) if is_finite(duration_s) else 0,
		"keys_typed": keys_typed,
		"errors": errors,
		"wpm": wpm,
		"accuracy": accuracy,
		"brains": total_brains(),
		"letter_pool_or_tier": letter_pool_or_tier,
		"per_key": per_key.duplicate(true),
		"end_reason": String(end_reason),
	}
