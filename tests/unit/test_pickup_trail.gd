extends GutTest
## PickupTrail (Story 8.4, FR72): brain pickup positions by distance, one inclusive randi_range(min, max)
## per pickup from its own RNG; collection by the zombie's logical step. The oracles are separately seeded
## RNGs and written-out numbers, never the trail against itself.

const MIN: int = 10
const MAX: int = 30


func _trail(rng_seed: int, min_steps: int = MIN, max_steps: int = MAX) -> PickupTrail:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return PickupTrail.new(rng, min_steps, max_steps)


func test_positions_are_a_running_sum_of_draws_from_an_independent_oracle() -> void:
	var trail: PickupTrail = _trail(1234)
	var placed: Array[int] = trail.fill_to(500)
	assert_gt(placed.size(), 0)
	var oracle: RandomNumberGenerator = RandomNumberGenerator.new()
	oracle.seed = 1234
	var expected: Array[int] = []
	var at: int = 0
	while at < 500:
		at += oracle.randi_range(MIN, MAX)
		expected.append(at)
	assert_eq(placed, expected)
	assert_eq(trail.upcoming(), expected)


func test_gaps_cover_10_to_30_with_a_mean_of_20() -> void:
	var trail: PickupTrail = _trail(99)
	var seen: Dictionary[int, int] = {}
	var previous: int = 0
	var count: int = 0
	var total: int = 0
	var step: int = 0
	while count < 10000:
		step += 1000
		for position: int in trail.fill_to(step):
			var gap: int = position - previous
			assert_between(gap, MIN, MAX)
			seen[gap] = seen.get(gap, 0) + 1
			total += gap
			previous = position
			count += 1
	assert_eq(seen.size(), 21, "every gap from 10 to 30 appears")
	assert_almost_eq(float(total) / count, 20.0, 0.5)


func test_collect_takes_each_pickup_once_when_the_zombie_reaches_it() -> void:
	var trail: PickupTrail = _trail(5)
	trail.fill_to(200)
	var first: int = trail.upcoming()[0]
	assert_gte(first, MIN)
	assert_eq(trail.collect(MIN - 1), 0, "nothing before the first pickup")
	assert_eq(trail.collect(first - 1), 0, "not one step early")
	assert_eq(trail.collect(first), 1)
	assert_eq(trail.collect(first), 0, "never twice")
	assert_false(trail.upcoming().has(first))


func test_a_jump_past_two_pickups_collects_both() -> void:
	var trail: PickupTrail = _trail(5)
	trail.fill_to(200)
	var second: int = trail.upcoming()[1]
	assert_eq(trail.collect(second), 2)
	assert_eq(trail.upcoming()[0] > second, true)


func test_fill_to_is_idempotent_and_draws_once_per_pickup() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var trail: PickupTrail = PickupTrail.new(rng, MIN, MAX)
	var placed: Array[int] = trail.fill_to(300)
	assert_gt(placed.size(), 0)
	assert_eq(trail.fill_to(300), [] as Array[int])
	assert_eq(trail.fill_to(10), [] as Array[int])
	var oracle: RandomNumberGenerator = RandomNumberGenerator.new()
	oracle.seed = 77
	for i: int in placed.size():
		oracle.randi_range(MIN, MAX)
	assert_eq(rng.state, oracle.state, "one draw per placed pickup")


func test_fill_places_until_the_last_position_reaches_the_step() -> void:
	var trail: PickupTrail = _trail(3)
	var placed: Array[int] = trail.fill_to(1)
	assert_eq(placed.size(), 1, "the first pickup is placed for any step above 0")
	assert_eq(trail.fill_to(placed[0]), [] as Array[int], "the last one already reaches the step")
	assert_eq(trail.fill_to(placed[0] + 1).size(), 1)


func test_same_seed_same_positions() -> void:
	assert_eq(_trail(8).fill_to(1000), _trail(8).fill_to(1000))
	assert_ne(_trail(8).fill_to(1000), _trail(9).fill_to(1000))


func test_bad_inputs_place_nothing() -> void:
	var cases: Array[PickupTrail] = [
		PickupTrail.new(null, MIN, MAX),
		_trail(1, 0, MAX),
		_trail(1, MIN, MIN - 1),
	]
	for trail: PickupTrail in cases:
		assert_eq(trail.fill_to(1000), [] as Array[int])
		assert_eq(trail.collect(1000), 0)
		assert_eq(trail.upcoming(), [] as Array[int])


func test_upcoming_is_a_copy() -> void:
	var trail: PickupTrail = _trail(2)
	trail.fill_to(100)
	var copy: Array[int] = trail.upcoming()
	copy.clear()
	assert_gt(trail.upcoming().size(), 0)


func test_economy_is_a_quarter_brain_per_correct_character() -> void:
	var trail: PickupTrail = _trail(2026)
	var collected: int = 0
	for step: int in range(1, 10001):
		trail.fill_to(step + 20)
		collected += trail.collect(step)
	var per_char: float = collected * 5.0 / 10000.0
	assert_almost_eq(per_char, 0.25, 0.25 * 0.05)
