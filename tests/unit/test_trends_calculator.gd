extends GutTest
## TrendsCalculator (Story 10.5): recent runs, WPM / accuracy series, practice seconds per local day, bar
## heights and the practice-time text. Pure; code-built records only.

const DAY: int = 86400
## 2026-09-01 00:00:00 UTC, a whole day boundary.
const DAY0: int = 1788220800


func _run(stamp: int, wpm: int = 10, accuracy: int = 90, seconds: int = 120) -> Dictionary:
	return {"timestamp": stamp, "wpm": wpm, "accuracy": accuracy, "duration_s": seconds}


func test_day0_is_a_utc_midnight() -> void:
	assert_eq(DAY0 % DAY, 0)


func test_recent_runs_keeps_the_newest_oldest_first() -> void:
	var history: Array = []
	for i: int in 25:
		history.append(_run(i + 1, i))
	var runs: Array[Dictionary] = TrendsCalculator.recent_runs(history, 20)
	assert_eq(runs.size(), 20)
	assert_eq(int(runs[0]["timestamp"]), 6, "the 5 oldest are left out")
	assert_eq(int(runs[-1]["timestamp"]), 25, "newest last")


func test_recent_runs_with_fewer_runs_than_count() -> void:
	var runs: Array[Dictionary] = TrendsCalculator.recent_runs([_run(1), _run(2)], 20)
	assert_eq(runs.size(), 2)
	assert_eq(int(runs[0]["timestamp"]), 1)
	assert_eq(TrendsCalculator.recent_runs([], 20).size(), 0)
	assert_eq(TrendsCalculator.recent_runs([_run(1)], 0).size(), 0)


func test_recent_runs_skips_junk() -> void:
	var history: Array = [_run(1), "oops", null, 5, [], _run(2), _run(3)]
	var runs: Array[Dictionary] = TrendsCalculator.recent_runs(history, 2)
	assert_eq(runs.size(), 2)
	assert_eq(int(runs[0]["timestamp"]), 2)
	assert_eq(int(runs[1]["timestamp"]), 3)
	assert_eq(TrendsCalculator.recent_runs(["x", 1], 20).size(), 0, "only junk is empty")


func test_wpm_series_reads_junk_as_zero() -> void:
	var runs: Array[Dictionary] = [_run(1, 12), {"wpm": -3}, {"wpm": 4.5}, {"wpm": "9"}, {}]
	assert_eq(TrendsCalculator.wpm_series(runs), [12, 0, 0, 0, 0] as Array[int])


func test_accuracy_series_clamps_to_100() -> void:
	var runs: Array[Dictionary] = [_run(1, 0, 88), {"accuracy": 140}, {"accuracy": -1}, {"accuracy": "x"}, {}]
	assert_eq(TrendsCalculator.accuracy_series(runs), [88, 100, 0, 0, 0] as Array[int])


func test_daily_seconds_groups_by_utc_day() -> void:
	var history: Array = [
		_run(DAY0 + 100, 0, 0, 120),
		_run(DAY0 + 5000, 0, 0, 180),
		_run(DAY0 + DAY + 10, 0, 0, 60),
	]
	assert_eq(TrendsCalculator.daily_seconds(history, 7, 0), [300, 60] as Array[int])


func test_daily_seconds_negative_bias_moves_early_utc_runs_to_the_day_before() -> void:
	# 02:00 UTC is 21:00 the day before at UTC-5 (bias -300 minutes).
	var history: Array = [_run(DAY0 - 3 * 3600, 0, 0, 100), _run(DAY0 + 2 * 3600, 0, 0, 200)]
	assert_eq(TrendsCalculator.daily_seconds(history, 7, 0), [100, 200] as Array[int], "two UTC days")
	assert_eq(TrendsCalculator.daily_seconds(history, 7, -300), [300] as Array[int], "one local day")


func test_daily_seconds_positive_bias_moves_late_utc_runs_to_the_next_day() -> void:
	# 23:00 UTC is 01:00 the next day at UTC+2 (bias 120 minutes).
	var history: Array = [_run(DAY0 + 23 * 3600, 0, 0, 100), _run(DAY0 + DAY + 3600, 0, 0, 200)]
	assert_eq(TrendsCalculator.daily_seconds(history, 7, 0), [100, 200] as Array[int])
	assert_eq(TrendsCalculator.daily_seconds(history, 7, 120), [300] as Array[int])


func test_daily_seconds_skips_empty_days_and_keeps_the_newest_7() -> void:
	var history: Array = []
	# 9 practice days spread over 20 calendar days (every other day + gaps), 60 s * (index + 1) each.
	var day_offsets: Array[int] = [0, 2, 4, 5, 9, 12, 13, 17, 19]
	for i: int in day_offsets.size():
		history.append(_run(DAY0 + day_offsets[i] * DAY + 600, 0, 0, 60 * (i + 1)))
	var values: Array[int] = TrendsCalculator.daily_seconds(history, 7, 0)
	assert_eq(values, [180, 240, 300, 360, 420, 480, 540] as Array[int], "no empty days, oldest first")


func test_daily_seconds_ignores_junk_and_zero_durations() -> void:
	var history: Array = [
		"oops",
		{"timestamp": DAY0, "duration_s": -5},
		{"timestamp": DAY0, "duration_s": 0},
		{"timestamp": 0, "duration_s": 60},
		{"timestamp": "x", "duration_s": 60},
		{"duration_s": 60},
		{"timestamp": DAY0, "duration_s": 2.5},
		_run(DAY0, 0, 0, 90),
	]
	assert_eq(TrendsCalculator.daily_seconds(history, 7, 0), [90] as Array[int])
	assert_eq(TrendsCalculator.daily_seconds([], 7, 0), [] as Array[int])
	assert_eq(TrendsCalculator.daily_seconds([_run(DAY0)], 0, 0), [] as Array[int])


func test_daily_seconds_handles_huge_durations() -> void:
	var history: Array = [_run(DAY0, 0, 0, 10_000_000), _run(DAY0 + 60, 0, 0, 10_000_000)]
	assert_eq(TrendsCalculator.daily_seconds(history, 7, 0), [20_000_000] as Array[int])


func test_bar_heights_scale_to_the_largest_value() -> void:
	assert_eq(TrendsCalculator.bar_heights([10, 20, 5] as Array[int], 40, 1), [20, 40, 10] as Array[int])


func test_bar_heights_use_the_scale_floor() -> void:
	# A first slow run (5 WPM) under a floor of 10 is half height, not full.
	assert_eq(TrendsCalculator.bar_heights([5] as Array[int], 40, 10), [20] as Array[int])
	assert_eq(TrendsCalculator.bar_heights([100] as Array[int], 40, 100), [40] as Array[int])


func test_bar_heights_minimum_and_zero() -> void:
	var heights: Array[int] = TrendsCalculator.bar_heights([0, 1, 1000] as Array[int], 40, 10)
	assert_eq(heights, [0, TrendsCalculator.MIN_BAR_PX, 40] as Array[int])
	assert_eq(TrendsCalculator.bar_heights([-4] as Array[int], 40, 10), [0] as Array[int])
	assert_eq(TrendsCalculator.bar_heights([] as Array[int], 40, 10), [] as Array[int])
	assert_eq(TrendsCalculator.bar_heights([5] as Array[int], 0, 10), [0] as Array[int])
	assert_eq(TrendsCalculator.bar_heights([5] as Array[int], 40, 0), [40] as Array[int], "floor 0 is safe")


func test_bar_heights_never_exceed_max() -> void:
	for height: int in TrendsCalculator.bar_heights([1, 9, 10, 11, 999999] as Array[int], 44, 10):
		assert_between(height, 0, 44)


func test_format_practice_time_boundaries() -> void:
	assert_eq(TrendsCalculator.format_practice_time(0), "0 min")
	assert_eq(TrendsCalculator.format_practice_time(59), "0 min")
	assert_eq(TrendsCalculator.format_practice_time(60), "1 min")
	assert_eq(TrendsCalculator.format_practice_time(3599), "59 min")
	assert_eq(TrendsCalculator.format_practice_time(3600), "1 hr 0 min")
	assert_eq(TrendsCalculator.format_practice_time(3660), "1 hr 1 min")
	assert_eq(TrendsCalculator.format_practice_time(36000), "10 hr 0 min")
	assert_eq(TrendsCalculator.format_practice_time(359940), "99 hr 59 min")
	assert_eq(TrendsCalculator.format_practice_time(-5), "0 min")
