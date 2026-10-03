extends GutTest
## FrameTracker: last frame, worst frame in the last WINDOW_SEC, clear. Time is passed in, so no waits.

const FrameTrackerScript := preload("res://scripts/debug/frame_tracker.gd")

var _tracker: FrameTrackerScript


func before_each() -> void:
	_tracker = FrameTrackerScript.new()


func test_empty_reports_zero() -> void:
	assert_eq(_tracker.worst_ms(), 0.0)
	assert_eq(_tracker.last_ms(), 0.0)


func test_records_last_and_worst() -> void:
	_tracker.record(0.0, 16.0)
	_tracker.record(0.1, 40.0)
	_tracker.record(0.2, 17.0)
	assert_eq(_tracker.last_ms(), 17.0)
	assert_eq(_tracker.worst_ms(), 40.0)


func test_entries_older_than_the_window_drop_out() -> void:
	_tracker.record(0.0, 50.0)
	_tracker.record(5.0, 10.0)
	_tracker.record(10.5, 8.0)
	assert_eq(_tracker.worst_ms(), 10.0, "the 50 ms frame is more than WINDOW_SEC old")
	assert_eq(_tracker.last_ms(), 8.0)


func test_window_is_ten_seconds() -> void:
	assert_eq(FrameTrackerScript.WINDOW_SEC, 10.0)


func test_long_run_keeps_only_the_window() -> void:
	for i: int in 2000:
		_tracker.record(i / 60.0, 99.0 if i == 10 else 16.0)
	assert_eq(_tracker.worst_ms(), 16.0, "the spike at frame 10 is long gone")
	assert_lte(_tracker.size(), int(FrameTrackerScript.WINDOW_SEC * 60.0) + 1)


func test_clear_empties_it() -> void:
	_tracker.record(0.0, 30.0)
	_tracker.clear()
	assert_eq(_tracker.worst_ms(), 0.0)
	assert_eq(_tracker.last_ms(), 0.0)
	assert_eq(_tracker.size(), 0)
