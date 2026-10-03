extends GutTest
## Proves the GUT harness runs, and checks GameConstants.


func test_harness_runs() -> void:
	assert_true(true)


func test_game_constants() -> void:
	assert_eq(GameConstants.LOGICAL_SIZE, Vector2i(640, 360))
	assert_eq(GameConstants.RUN_HISTORY_CAP, 500)
	assert_eq(GameConstants.CURRENT_SCHEMA, 1)
