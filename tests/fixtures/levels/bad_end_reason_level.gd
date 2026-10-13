extends "res://scripts/levels/test_level/test_level.gd"
## Test fixture (Story 8.5): the test level with a clock end reason that is not an END_REASON_* constant,
## so RunFrame must log it and record timer.


func get_timer_end_reason() -> StringName:
	return &"bogus"
