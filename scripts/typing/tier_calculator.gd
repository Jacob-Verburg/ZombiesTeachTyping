class_name TierCalculator
## The adaptive-difficulty tier (GDD Adaptive Difficulty, FR60, FR62, FR63): the rolling average WPM of the
## newest completed runs, the tier whose range holds it, and hysteresis so one bad run never drops a tier.
## Pure and static: no nodes, no autoloads, no clock, no file I/O. Every number comes from a TierConfig
## (data/tier_config.tres). PlayerData calls compute_tier() after each recorded run (Story 7.2).
## The average uses each record's stored wpm (the number the report card showed), not a recompute from
## keys_typed / duration_s: the record floors duration_s and does not save Horde Rush's implied spaces.

## rolling_average() result when no run counts. Never moves a placed tier.
const NO_AVERAGE: float = -1.0


## Unrounded mean of the stored wpm (times the level's scale) of the newest config.window_runs completed
## runs in `history` (RunResult.to_record() dictionaries, newest last). Skips runs that did not finish,
## ignored levels and junk records. NO_AVERAGE when no run counts.
static func rolling_average(history: Array, config: TierConfig) -> float:
	if config == null:
		Log.error(&"tier", "rolling_average without a TierConfig")
		return NO_AVERAGE
	var total: float = 0.0
	var counted: int = 0
	var junk: int = 0
	for i: int in range(history.size() - 1, -1, -1):
		if counted >= config.window_runs:
			break
		if not history[i] is Dictionary:
			junk += 1
			continue
		var record: Dictionary = history[i]
		if not _is_completed(record.get("end_reason")):
			continue
		var level_value: Variant = record.get("level_id", "")
		var level_id: StringName = StringName(level_value) if level_value is String else &""
		if level_id in config.ignored_levels:
			continue
		var wpm: Variant = record.get("wpm")
		if not ((wpm is int or wpm is float) and is_finite(float(wpm)) and float(wpm) >= 0.0):
			junk += 1
			continue
		total += float(wpm) * config.scale_for(level_id)
		counted += 1
	if junk > 0:
		Log.warn(&"tier", "skipped %d junk run records" % junk)
	if counted == 0:
		return NO_AVERAGE
	return total / float(counted)


## The tier whose range holds `average`: the highest tier whose floor is at or below it (1-based).
## Negative, NO_AVERAGE or non-finite input gives 1.
static func tier_for_wpm(average: float, config: TierConfig) -> int:
	if config == null:
		Log.error(&"tier", "tier_for_wpm without a TierConfig")
		return 1
	if not is_finite(average) or average < 0.0:
		return 1
	var tier: int = 1
	for t: int in range(2, config.tier_count() + 1):
		if average >= config.floor_of(t):
			tier = t
	return tier


## The tier after a run, given the `current` tier and the new rolling `average` (FR63). Up as soon as the
## average reaches a higher floor; down only below current floor - drop_margin_wpm, to the tier holding the
## average. No average (NO_AVERAGE, negative, non-finite) keeps `current`. A `current` outside 1..tier
## count (0 = not placed yet) takes the average's tier.
static func next_tier(current: int, average: float, config: TierConfig) -> int:
	if config == null:
		Log.error(&"tier", "next_tier without a TierConfig")
		return current
	if not is_finite(average) or average < 0.0:
		return current
	var target: int = tier_for_wpm(average, config)
	if current < 1 or current > config.tier_count():
		return target
	if target > current:
		return target
	if average < config.floor_of(current) - config.drop_margin_wpm:
		return target
	return current


## next_tier(current, rolling_average(history)): the tier after the newest run in `history`.
static func compute_tier(current: int, history: Array, config: TierConfig) -> int:
	return next_tier(current, rolling_average(history, config), config)


## True for the end reasons of a finished run (timer, caught, escaped). Records store Strings.
static func _is_completed(end_reason: Variant) -> bool:
	if not end_reason is String:
		return false
	return end_reason in [
		String(GameConstants.END_REASON_TIMER),
		String(GameConstants.END_REASON_CAUGHT),
		String(GameConstants.END_REASON_ESCAPED),
	]
