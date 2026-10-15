class_name TrendsCalculator
## The Progress screen's numbers (Story 10.5, FR77): which runs and days its charts show, the bar heights and
## the "Time Practiced" text. Pure and static: no nodes, no autoloads, no clock. It reads run records (the
## save's run_history shape) leniently: a non-Dictionary record is skipped and a junk number reads as 0.

## The shortest bar a non-zero value draws, so a tiny value never vanishes (a look value).
const MIN_BAR_PX: int = 2
const SECONDS_PER_DAY: int = 86400


## The newest `count` Dictionary records of `history`, oldest first. Junk entries are skipped.
static func recent_runs(history: Array, count: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Variant in history:
		if record is Dictionary:
			records.append(record as Dictionary)
	if count <= 0:
		records.clear()
	elif records.size() > count:
		records = records.slice(records.size() - count)
	return records


## Each run's WPM (a junk value reads as 0).
static func wpm_series(runs: Array[Dictionary]) -> Array[int]:
	var values: Array[int] = []
	for run: Dictionary in runs:
		values.append(_whole(run.get("wpm")))
	return values


## Each run's accuracy percent, clamped to 0..100 (a junk value reads as 0).
static func accuracy_series(runs: Array[Dictionary]) -> Array[int]:
	var values: Array[int] = []
	for run: Dictionary in runs:
		values.append(mini(_whole(run.get("accuracy")), 100))
	return values


## Practice seconds per local calendar day: the newest `day_count` days that have practice, oldest first.
## A day is floor((timestamp + bias_minutes * 60) / 86400), bias = local minus UTC in minutes. Days with no
## practice are skipped (never shown as empty bars). Records without a positive timestamp are left out.
static func daily_seconds(history: Array, day_count: int, bias_minutes: int) -> Array[int]:
	var per_day: Dictionary = {}
	for record: Variant in history:
		if not record is Dictionary:
			continue
		var stamp: int = _whole((record as Dictionary).get("timestamp"))
		var seconds: int = _whole((record as Dictionary).get("duration_s"))
		if stamp <= 0 or seconds <= 0:
			continue
		var day: int = floori((stamp + bias_minutes * 60) / float(SECONDS_PER_DAY))
		per_day[day] = int(per_day.get(day, 0)) + seconds
	var days: Array = per_day.keys()
	days.sort()
	if day_count <= 0:
		days.clear()
	elif days.size() > day_count:
		days = days.slice(days.size() - day_count)
	var values: Array[int] = []
	for day: Variant in days:
		values.append(int(per_day[day]))
	return values


## Bar heights in whole pixels for `values` in a `max_px` tall area. The scale is the largest value or
## `scale_floor`, whichever is bigger; a value > 0 is at least MIN_BAR_PX; 0 (or less) is 0; never above max_px.
static func bar_heights(values: Array[int], max_px: int, scale_floor: int) -> Array[int]:
	var heights: Array[int] = []
	var top: int = maxi(scale_floor, 1)
	for value: int in values:
		top = maxi(top, value)
	for value: int in values:
		if value <= 0 or max_px <= 0:
			heights.append(0)
			continue
		var height: int = roundi(float(value) * float(max_px) / float(top))
		heights.append(clampi(height, mini(MIN_BAR_PX, max_px), max_px))
	return heights


## "N min" under an hour, "N hr N min" from an hour; minutes round down. Negative reads as "0 min".
static func format_practice_time(seconds: int) -> String:
	var whole: int = maxi(0, seconds)
	var minutes: int = floori(whole / 60.0)
	if minutes < 60:
		return "%d min" % minutes
	return "%d hr %d min" % [floori(minutes / 60.0), minutes % 60]


## A non-negative int as itself; anything else (negative, float, string, null) as 0.
static func _whole(value: Variant) -> int:
	if value is int and int(value) >= 0:
		return value
	return 0
