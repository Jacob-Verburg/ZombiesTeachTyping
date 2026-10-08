extends GutTest
## TierCalculator (Story 7.1, FR60-FR63): rolling average of the newest completed runs, the tier
## lookup, hysteresis on the way down, and compute_tier on scripted run histories.


## The GDD numbers, built in code so a data tweak can't silently change these tests.
func _config() -> TierConfig:
	var config: TierConfig = TierConfig.new()
	config.tier_floors = [0.0, 8.0, 15.0, 22.0, 30.0]
	config.drop_margin_wpm = 2.0
	config.window_runs = 5
	config.ignored_levels = [&"test_level", &"test_word_level"]
	return config


## A record shaped like RunResult.to_record().
func _run(level: String, wpm: Variant, end_reason: String = "timer", timestamp: int = 0) -> Dictionary:
	return {
		"timestamp": timestamp,
		"level_id": level,
		"duration_s": 120,
		"keys_typed": 100,
		"errors": 0,
		"wpm": wpm,
		"accuracy": 100,
		"brains": 0,
		"letter_pool_or_tier": "all",
		"per_key": {},
		"end_reason": end_reason,
	}


## Zombie Run records with these WPMs, oldest first.
func _history(wpms: Array) -> Array:
	var history: Array = []
	for wpm: Variant in wpms:
		history.append(_run("zombie_run", wpm))
	return history


# --- rolling_average ---

func test_average_of_one_run() -> void:
	assert_almost_eq(TierCalculator.rolling_average(_history([12]), _config()), 12.0, 1e-9)


func test_average_of_three_runs_uses_only_those() -> void:
	assert_almost_eq(TierCalculator.rolling_average(_history([10, 12, 20]), _config()), 14.0, 1e-9)


func test_average_of_five_runs() -> void:
	assert_almost_eq(TierCalculator.rolling_average(_history([12, 14, 16, 16, 17]), _config()), 15.0, 1e-9)


func test_average_of_seven_runs_uses_only_newest_five() -> void:
	var history: Array = _history([40, 40, 10, 10, 10, 10, 10])
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 10.0, 1e-9)


func test_newest_is_array_order_not_timestamp() -> void:
	var history: Array = [
		_run("zombie_run", 40, "timer", 9000),
		_run("zombie_run", 10, "timer", 5),
		_run("zombie_run", 10, "timer", 1),
		_run("zombie_run", 10, "timer", 7000),
		_run("zombie_run", 10, "timer", 3),
		_run("zombie_run", 10, "timer", 2),
	]
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 10.0, 1e-9,
			"the first-appended record is the oldest, whatever its timestamp")


func test_average_is_unrounded() -> void:
	var avg: float = TierCalculator.rolling_average(_history([14, 15]), _config())
	assert_almost_eq(avg, 14.5, 1e-9)
	assert_eq(TierCalculator.tier_for_wpm(avg, _config()), 2)


func test_float_wpm_accepted() -> void:
	assert_almost_eq(TierCalculator.rolling_average(_history([14.0, 15]), _config()), 14.5, 1e-9)


func test_non_completed_end_reasons_skipped() -> void:
	var history: Array = [
		_run("zombie_run", 10),
		_run("zombie_run", 50, "quit"),
		_run("zombie_run", 50, ""),
		_run("zombie_run", 50, "exploded"),
	]
	var missing: Dictionary = _run("zombie_run", 50)
	missing.erase("end_reason")
	history.append(missing)
	var not_string: Dictionary = _run("zombie_run", 50)
	not_string["end_reason"] = 7
	history.append(not_string)
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 10.0, 1e-9)


func test_quit_runs_do_not_take_a_window_slot() -> void:
	var history: Array = _history([20, 10, 10, 10, 10])
	history.append(_run("zombie_run", 50, "quit"))
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 12.0, 1e-9,
			"the quit run is skipped, so the 20 stays inside the newest five")


func test_caught_and_escaped_count() -> void:
	var history: Array = [_run("pitchfork_panic", 10, "caught"), _run("pitchfork_panic", 20, "escaped")]
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 15.0, 1e-9)


func test_all_levels_count_together() -> void:
	var history: Array = [_run("zombie_run", 10), _run("horde_rush", 20)]
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 15.0, 1e-9)


func test_ignored_levels_skipped() -> void:
	var history: Array = [_run("zombie_run", 10), _run("test_level", 90), _run("test_word_level", 90)]
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 10.0, 1e-9)


func test_junk_records_skipped_with_one_warning() -> void:
	var history: Array = [
		_run("zombie_run", 10),
		"not a record",
		null,
		_run("zombie_run", "fast"),
		_run("zombie_run", -3),
		_run("zombie_run", NAN),
		_run("zombie_run", INF),
		_run("zombie_run", true),
	]
	var no_wpm: Dictionary = _run("zombie_run", 0)
	no_wpm.erase("wpm")
	history.append(no_wpm)
	assert_almost_eq(TierCalculator.rolling_average(history, _config()), 10.0, 1e-9)
	assert_push_warning("[WARN][tier] skipped 8 junk run records")
	assert_push_warning_count(1)


func test_clean_history_logs_nothing() -> void:
	TierCalculator.rolling_average(_history([10, 12]), _config())
	assert_push_warning_count(0)
	assert_push_error_count(0)


func test_zero_wpm_counts() -> void:
	assert_almost_eq(TierCalculator.rolling_average(_history([0, 10]), _config()), 5.0, 1e-9)


func test_level_scale_applied() -> void:
	var config: TierConfig = _config()
	config.level_wpm_scale = {&"horde_rush": 0.5}
	var history: Array = [_run("zombie_run", 10), _run("horde_rush", 20)]
	assert_almost_eq(TierCalculator.rolling_average(history, config), 10.0, 1e-9,
			"(10 x 1.0 + 20 x 0.5) / 2")


func test_empty_history_has_no_average() -> void:
	assert_eq(TierCalculator.rolling_average([], _config()), TierCalculator.NO_AVERAGE)


func test_all_skipped_history_has_no_average() -> void:
	var history: Array = [_run("zombie_run", 10, "quit"), _run("test_level", 10)]
	assert_eq(TierCalculator.rolling_average(history, _config()), TierCalculator.NO_AVERAGE)


func test_missing_or_non_string_level_id_still_counts() -> void:
	var no_level: Dictionary = _run("zombie_run", 10)
	no_level.erase("level_id")
	var int_level: Dictionary = _run("zombie_run", 20)
	int_level["level_id"] = 7
	assert_eq(TierCalculator.rolling_average([no_level, int_level], _config()), 15.0)


func test_non_positive_window_has_no_average() -> void:
	var config: TierConfig = _config()
	config.window_runs = 0
	assert_eq(TierCalculator.rolling_average(_history([10, 12]), config), TierCalculator.NO_AVERAGE)


func test_null_config_is_safe() -> void:
	assert_eq(TierCalculator.rolling_average(_history([10]), null), TierCalculator.NO_AVERAGE)
	assert_push_error("[ERROR][tier]")
	assert_eq(TierCalculator.tier_for_wpm(20.0, null), 1)
	assert_push_error("[ERROR][tier]")
	assert_eq(TierCalculator.next_tier(3, 40.0, null), 3)
	assert_push_error("[ERROR][tier]")


# --- tier_for_wpm ---

func test_tier_for_wpm_boundaries() -> void:
	var table: Array = [
		[0.0, 1], [7.99, 1], [8.0, 2], [14.5, 2], [14.99, 2], [15.0, 3], [21.99, 3], [22.0, 4],
		[29.99, 4], [30.0, 5], [95.0, 5],
	]
	for row: Array in table:
		assert_eq(TierCalculator.tier_for_wpm(row[0], _config()), row[1], "%s WPM" % row[0])


func test_tier_for_wpm_bad_input_is_tier_one() -> void:
	assert_eq(TierCalculator.tier_for_wpm(-1.0, _config()), 1)
	assert_eq(TierCalculator.tier_for_wpm(TierCalculator.NO_AVERAGE, _config()), 1)
	assert_eq(TierCalculator.tier_for_wpm(NAN, _config()), 1)
	assert_eq(TierCalculator.tier_for_wpm(INF, _config()), 1)


# --- next_tier ---

func test_rises_one_tier_at_the_next_floor() -> void:
	assert_eq(TierCalculator.next_tier(1, 8.0, _config()), 2)
	assert_eq(TierCalculator.next_tier(2, 15.0, _config()), 3)
	assert_eq(TierCalculator.next_tier(2, 14.99, _config()), 2)


func test_rises_skipping_tiers() -> void:
	assert_eq(TierCalculator.next_tier(1, 25.0, _config()), 4)
	assert_eq(TierCalculator.next_tier(1, 30.0, _config()), 5)


func test_holds_inside_the_hysteresis_band() -> void:
	assert_eq(TierCalculator.next_tier(3, 13.0, _config()), 3, "exactly floor - margin holds")
	assert_eq(TierCalculator.next_tier(3, 14.9, _config()), 3)
	assert_eq(TierCalculator.next_tier(2, 6.0, _config()), 2)
	assert_eq(TierCalculator.next_tier(2, 6.5, _config()), 2)
	assert_eq(TierCalculator.next_tier(5, 28.0, _config()), 5)


func test_single_drop() -> void:
	assert_eq(TierCalculator.next_tier(3, 12.99, _config()), 2)
	assert_eq(TierCalculator.next_tier(2, 5.99, _config()), 1)
	assert_eq(TierCalculator.next_tier(5, 27.99, _config()), 4)


func test_multi_tier_drop() -> void:
	assert_eq(TierCalculator.next_tier(5, 10.0, _config()), 2)
	assert_eq(TierCalculator.next_tier(4, 7.0, _config()), 1)


func test_drop_uses_the_margin_from_config() -> void:
	var config: TierConfig = _config()
	config.drop_margin_wpm = 0.0
	assert_eq(TierCalculator.next_tier(3, 14.99, config), 2)
	assert_eq(TierCalculator.next_tier(3, 15.0, config), 3)


func test_tier_one_never_drops() -> void:
	assert_eq(TierCalculator.next_tier(1, 0.0, _config()), 1)


func test_no_average_never_moves_a_placed_tier() -> void:
	for tier: int in range(1, 6):
		assert_eq(TierCalculator.next_tier(tier, TierCalculator.NO_AVERAGE, _config()), tier)
		assert_eq(TierCalculator.next_tier(tier, NAN, _config()), tier)
		assert_eq(TierCalculator.next_tier(tier, INF, _config()), tier)


func test_negative_average_never_moves_a_placed_tier() -> void:
	assert_eq(TierCalculator.next_tier(4, -7.0, _config()), 4)


func test_unplaced_or_junk_tier_takes_the_average_tier() -> void:
	assert_eq(TierCalculator.next_tier(0, 18.0, _config()), 3, "tier 0 = not placed yet")
	assert_eq(TierCalculator.next_tier(0, 3.0, _config()), 1)
	assert_eq(TierCalculator.next_tier(6, 10.0, _config()), 2)
	assert_eq(TierCalculator.next_tier(-1, 31.0, _config()), 5)


func test_unplaced_with_no_average_stays_unplaced() -> void:
	assert_eq(TierCalculator.next_tier(0, TierCalculator.NO_AVERAGE, _config()), 0)


# --- compute_tier ---

func test_compute_tier_rises_holds_through_a_bad_day_then_drops() -> void:
	var config: TierConfig = _config()
	var history: Array = _history([12, 14, 16, 16, 17])
	var tier: int = TierCalculator.compute_tier(2, history, config)
	assert_eq(tier, 3, "avg 15.0 reaches tier 3")
	history.append(_run("zombie_run", 9))
	tier = TierCalculator.compute_tier(tier, history, config)
	assert_eq(tier, 3, "one bad run: avg 14.4 holds tier 3")
	history.append(_run("zombie_run", 9))
	tier = TierCalculator.compute_tier(tier, history, config)
	assert_eq(tier, 3, "avg 13.4 still holds")
	history.append(_run("zombie_run", 9))
	tier = TierCalculator.compute_tier(tier, history, config)
	assert_eq(tier, 2, "avg 12.0 drops to tier 2")


func test_compute_tier_empty_history_keeps_tier() -> void:
	assert_eq(TierCalculator.compute_tier(4, [], _config()), 4)
	assert_eq(TierCalculator.compute_tier(0, [], _config()), 0)
