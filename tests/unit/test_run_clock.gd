extends GutTest
## Run clock (Story 2.4): accumulates only the deltas it is given while running.

var _clock: RunClock


func before_each() -> void:
	_clock = RunClock.new()


func test_stopped_clock_ignores_advance() -> void:
	assert_false(_clock.is_running())
	_clock.advance(5.0)
	assert_eq(_clock.get_elapsed(), 0.0)


func test_start_then_advance() -> void:
	_clock.start()
	assert_true(_clock.is_running())
	assert_eq(_clock.get_elapsed(), 0.0, "starts from 0")
	_clock.advance(0.5)
	_clock.advance(0.5)
	assert_eq(_clock.get_elapsed(), 1.0)


func test_pause_freezes_and_resume_continues() -> void:
	_clock.start()
	_clock.advance(1.0)
	_clock.pause()
	assert_false(_clock.is_running())
	_clock.advance(3.0)
	assert_eq(_clock.get_elapsed(), 1.0)
	_clock.resume()
	assert_true(_clock.is_running())
	_clock.advance(0.25)
	assert_eq(_clock.get_elapsed(), 1.25)


func test_second_start_keeps_the_time() -> void:
	_clock.start()
	_clock.advance(2.0)
	_clock.start()
	assert_eq(_clock.get_elapsed(), 2.0, "no reset mid-run")
	_clock.pause()
	_clock.start()
	assert_eq(_clock.get_elapsed(), 2.0)


func test_resume_before_start_does_nothing() -> void:
	_clock.resume()
	assert_false(_clock.is_running())
	_clock.advance(1.0)
	assert_eq(_clock.get_elapsed(), 0.0)


func test_bad_deltas_are_ignored() -> void:
	_clock.start()
	_clock.advance(1.0)
	_clock.advance(-0.5)
	_clock.advance(INF)
	_clock.advance(NAN)
	assert_eq(_clock.get_elapsed(), 1.0)


func test_frame_deltas_sum() -> void:
	_clock.start()
	for i: int in 600:
		_clock.advance(1.0 / 60.0)
	assert_almost_eq(_clock.get_elapsed(), 10.0, 0.000001)
