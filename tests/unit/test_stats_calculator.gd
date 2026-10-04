extends GutTest
## Stats calculator (Story 2.3): Accuracy, WPM, implied spaces and Lesson Time (FR7).


func test_story_example() -> void:
	assert_eq(StatsCalculator.accuracy_percent(100, 5), 95)
	assert_eq(StatsCalculator.wpm(100, 120.0), 10)
	assert_eq(StatsCalculator.format_time(120.0), "2:00")


func test_report_card_mock_example() -> void:
	assert_eq(StatsCalculator.accuracy_percent(142, 9), 94)
	assert_eq(StatsCalculator.wpm(142, 120.0), 14)
	assert_eq(StatsCalculator.format_time(120.0), "2:00")


func test_accuracy_zero_cases() -> void:
	assert_eq(StatsCalculator.accuracy_percent(0, 0), 0, "nothing typed: 0, no division by zero")
	assert_eq(StatsCalculator.accuracy_percent(0, 5), 0)


func test_accuracy_perfect_only_without_errors() -> void:
	assert_eq(StatsCalculator.accuracy_percent(10, 0), 100)
	assert_eq(StatsCalculator.accuracy_percent(57, 0), 100)
	assert_eq(StatsCalculator.accuracy_percent(999, 1), 99, "99.9 % rounds down, never shows 100 %")


func test_accuracy_rounds_down() -> void:
	assert_eq(StatsCalculator.accuracy_percent(2, 1), 66, "66.67 floors")
	assert_eq(StatsCalculator.accuracy_percent(1, 2), 33)


func test_wpm_zero_cases() -> void:
	assert_eq(StatsCalculator.wpm(0, 120.0), 0)
	assert_eq(StatsCalculator.wpm(100, 0.0), 0)
	assert_eq(StatsCalculator.wpm(100, -5.0), 0)


func test_wpm_below_minimum_duration_is_zero() -> void:
	assert_eq(StatsCalculator.wpm(1, 0.016), 0, "one frame is not a typing rate")
	assert_eq(StatsCalculator.wpm(1, 1e-320), 0, "denormal seconds cannot overflow")
	assert_eq(StatsCalculator.wpm_exact(1, 0.5), 0.0)
	assert_eq(StatsCalculator.wpm(1, GameConstants.MIN_WPM_SECONDS), 12, "the minimum itself counts")


func test_wpm_non_finite_seconds() -> void:
	assert_eq(StatsCalculator.wpm(100, INF), 0)
	assert_eq(StatsCalculator.wpm(100, NAN), 0)
	assert_eq(StatsCalculator.wpm_exact(100, INF), 0.0)
	assert_eq(StatsCalculator.wpm_exact(100, NAN), 0.0)


func test_wpm_values_and_rounding_down() -> void:
	assert_eq(StatsCalculator.wpm(5, 60.0), 1)
	assert_eq(StatsCalculator.wpm(9, 60.0), 1, "1.8 floors")
	assert_eq(StatsCalculator.wpm(51, 60.0), 10, "10.2 floors")
	assert_eq(StatsCalculator.wpm(100, 60.0), 20)
	assert_eq(StatsCalculator.wpm(1, 1.0), 12)


func test_wpm_exact_is_unrounded() -> void:
	assert_almost_eq(StatsCalculator.wpm_exact(51, 60.0), 10.2, 0.0001)
	assert_eq(StatsCalculator.wpm_exact(0, 0.0), 0.0)
	assert_eq(StatsCalculator.wpm_exact(100, 120.0), 10.0)


func test_implied_spaces_add_to_wpm() -> void:
	assert_eq(StatsCalculator.wpm(20, 60.0), 4)
	assert_eq(StatsCalculator.wpm(20, 60.0, 5), 5)
	assert_eq(StatsCalculator.wpm(0, 60.0, 5), 1, "completed words alone count")
	assert_almost_eq(StatsCalculator.wpm_exact(20, 60.0, 5), 5.0, 0.0001)


func test_accuracy_ignores_completed_words() -> void:
	# accuracy_percent has no word argument: implied spaces never change Keys Typed or Accuracy.
	assert_eq(StatsCalculator.accuracy_percent(20, 0), 100)
	assert_eq(StatsCalculator.accuracy_percent(20, 5), 80)


func _frame_seconds(frames: int) -> float:
	# Seconds built from 60 FPS deltas, as RunClock accumulates them.
	var s: float = 0.0
	for i: int in frames:
		s += 1.0 / 60.0
	return s


func test_wpm_with_accumulated_frame_seconds() -> void:
	# 7200 frames sum to just under 120 s, so this one is a regression guard, not the epsilon test.
	var s: float = _frame_seconds(7200)
	assert_eq(StatsCalculator.wpm(100, s), 10)
	assert_almost_eq(StatsCalculator.wpm_exact(100, s), 10.0, 0.001)


func test_wpm_epsilon_guards_float_overshoot() -> void:
	# 600 frames sum to 10.00000000000008 s, so 50 keys give 59.9999... WPM: must still show 60.
	var s: float = _frame_seconds(600)
	assert_true(s > 10.0, "precondition: the float sum overshoots 10 s")
	assert_eq(StatsCalculator.wpm(50, s), 60)
	assert_almost_eq(StatsCalculator.wpm_exact(50, s), 60.0, 0.001)


func test_format_time() -> void:
	assert_eq(StatsCalculator.format_time(0.0), "0:00")
	assert_eq(StatsCalculator.format_time(5.0), "0:05")
	assert_eq(StatsCalculator.format_time(59.99), "0:59")
	assert_eq(StatsCalculator.format_time(60.0), "1:00")
	assert_eq(StatsCalculator.format_time(119.9), "1:59")
	assert_eq(StatsCalculator.format_time(120.0), "2:00")
	assert_eq(StatsCalculator.format_time(125.0), "2:05")
	assert_eq(StatsCalculator.format_time(300.0), "5:00")
	assert_eq(StatsCalculator.format_time(600.0), "10:00")


func test_format_time_invalid_input() -> void:
	assert_eq(StatsCalculator.format_time(-3.0), "0:00")
	assert_eq(StatsCalculator.format_time(INF), "0:00")
	assert_eq(StatsCalculator.format_time(NAN), "0:00")
