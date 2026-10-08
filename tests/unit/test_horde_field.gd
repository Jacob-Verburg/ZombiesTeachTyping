extends GutTest
## HordeField / HordeMarcher (Story 6.3): class by word length, ids, progress, exact arrival timing (also
## from 60 Hz steps), independent arrivals in spawn order, bad deltas, the copy getter, and lanes (in
## range, all used, seeded, never the global RNG). The config is built in-test with round numbers.
## Story 6.4: hit() and the stopped state, the spawned = marching + arrived + stopped invariant, and
## front_most_in_lane() (highest progress, ties to the lower id, at_or_past).

const LANES: int = 5


func _config() -> HordeRushConfig:
	var config: HordeRushConfig = HordeRushConfig.new()
	config.lane_count = LANES
	config.size_classes = [_size(&"small", 3, 8.0, 1), _size(&"medium", 5, 10.0, 2), _size(&"brute", 0, 13.0, 3)]
	return config


func _size(id: StringName, max_len: int, crossing: float, hits: int) -> HordeSizeClass:
	var size_class: HordeSizeClass = HordeSizeClass.new()
	size_class.id = id
	size_class.max_word_length = max_len
	size_class.crossing_time_s = crossing
	size_class.hits_to_stop = hits
	size_class.arrival_brains = hits
	return size_class


func _field(lane_seed: int = 7) -> HordeField:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = lane_seed
	return HordeField.new(_config(), rng)


func _lanes(lane_seed: int, count: int) -> Array[int]:
	var field: HordeField = _field(lane_seed)
	var lanes: Array[int] = []
	for i: int in count:
		lanes.append(field.spawn("cat").lane)
	return lanes


func test_spawn_picks_the_class_by_length_and_sets_hits() -> void:
	var field: HordeField = _field()
	var expected: Dictionary[String, StringName] = {
		"at": &"small", "cat": &"small", "frog": &"medium", "tiger": &"medium", "rabbit": &"brute",
		"elephants": &"brute",
	}
	for word: String in expected:
		var marcher: HordeMarcher = field.spawn(word)
		assert_eq(marcher.size_class.id, expected[word], word)
		assert_eq(marcher.hits_left, marcher.size_class.hits_to_stop, word)
		assert_eq(marcher.word, word)
		assert_eq(marcher.elapsed_s, 0.0)
		assert_eq(marcher.progress(), 0.0)


func test_ids_count_up_in_spawn_order() -> void:
	var field: HordeField = _field()
	for i: int in 3:
		assert_eq(field.spawn("cat").id, i)
	assert_eq(field.get_spawned_count(), 3)
	assert_eq(field.get_marching().size(), 3)


func test_small_arrives_exactly_at_its_crossing_time() -> void:
	var field: HordeField = _field()
	var marcher: HordeMarcher = field.spawn("cat")
	assert_eq(field.advance(7.9).size(), 0, "not there at 7.9 s")
	assert_almost_eq(marcher.progress(), 7.9 / 8.0, 1e-6)
	assert_false(marcher.has_arrived())
	var arrived: Array[HordeMarcher] = field.advance(0.1)
	assert_eq(arrived.size(), 1, "there at 8.0 s")
	assert_eq(arrived[0], marcher)
	assert_eq(marcher.progress(), 1.0)
	assert_eq(field.get_marching().size(), 0)
	assert_eq(field.get_arrived_count(), 1)


func test_small_arrives_on_the_480th_60hz_frame() -> void:
	var field: HordeField = _field()
	field.spawn("cat")
	for i: int in 479:
		assert_eq(field.advance(1.0 / 60.0).size(), 0, "frame %d" % (i + 1))
	assert_eq(field.advance(1.0 / 60.0).size(), 1, "frame 480 = 8.0 s")


func test_marchers_arrive_independently_in_spawn_order() -> void:
	var field: HordeField = _field()
	var medium: HordeMarcher = field.spawn("frog")
	field.advance(2.0)
	var small: HordeMarcher = field.spawn("cat")
	# medium at 2 s needs 8 more; small needs 8: both arrive on the same step, in spawn order.
	assert_eq(field.advance(7.0).size(), 0)
	assert_almost_eq(medium.progress(), 0.9, 1e-6)
	assert_almost_eq(small.progress(), 7.0 / 8.0, 1e-6)
	var arrived: Array[HordeMarcher] = field.advance(1.0)
	assert_eq(arrived, [medium, small] as Array[HordeMarcher])


func test_each_arrival_is_returned_once() -> void:
	var field: HordeField = _field()
	field.spawn("cat")
	var later: HordeMarcher = field.spawn("tiger")
	assert_eq(field.advance(8.0).size(), 1)
	assert_eq(field.advance(1.0).size(), 0, "the small one is gone")
	assert_eq(field.get_marching(), [later] as Array[HordeMarcher])
	assert_eq(field.advance(1.0), [later] as Array[HordeMarcher])
	assert_eq(field.advance(5.0).size(), 0)
	assert_eq(field.get_arrived_count(), 2)


func test_bad_deltas_change_nothing() -> void:
	var field: HordeField = _field()
	var marcher: HordeMarcher = field.spawn("cat")
	for delta: float in [0.0, -1.0, INF, -INF, NAN]:
		assert_eq(field.advance(delta).size(), 0, str(delta))
		assert_eq(marcher.elapsed_s, 0.0, str(delta))
	assert_eq(field.get_marching().size(), 1)


func test_get_marching_is_a_copy() -> void:
	var field: HordeField = _field()
	field.spawn("cat")
	field.get_marching().clear()
	assert_eq(field.get_marching().size(), 1)


func test_lanes_stay_in_range_and_all_are_used() -> void:
	var lanes: Array[int] = _lanes(3, 500)
	var used: Dictionary[int, bool] = {}
	for lane: int in lanes:
		assert_true(lane >= 0 and lane < LANES, "lane %d" % lane)
		used[lane] = true
	assert_eq(used.size(), LANES, "every lane is used over 500 spawns")


func test_same_lane_seed_same_lanes() -> void:
	assert_eq(_lanes(11, 40), _lanes(11, 40))
	assert_ne(_lanes(11, 40), _lanes(12, 40))


func test_one_lane_draw_per_spawn() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	var expected: Array[int] = []
	for i: int in 20:
		expected.append(rng.randi_range(0, LANES - 1))
	assert_eq(_lanes(21, 20), expected)


func test_independent_of_the_global_rng() -> void:
	seed(1)
	var first: Array[int] = _lanes(5, 50)
	seed(999)
	assert_eq(_lanes(5, 50), first, "only the injected RNG decides the lanes")
	randomize() # leave the global RNG unseeded for later tests


func test_spawn_without_lanes_returns_null() -> void:
	var config: HordeRushConfig = _config()
	config.lane_count = 0
	var field: HordeField = HordeField.new(config, RandomNumberGenerator.new())
	assert_null(field.spawn("cat"))
	assert_push_error("horde field has no lanes")
	assert_eq(field.get_spawned_count(), 0)


func test_progress_is_one_as_soon_as_a_copy_has_arrived() -> void:
	var field: HordeField = _field()
	var marcher: HordeMarcher = field.spawn("cat")
	marcher.elapsed_s = 8.0 - HordeMarcher.ARRIVE_EPSILON_S / 2.0
	assert_true(marcher.has_arrived())
	assert_eq(marcher.progress(), 1.0, "has_arrived() and progress() agree")


func _assert_counts_add_up(field: HordeField) -> void:
	assert_eq(field.get_spawned_count(),
		field.get_marching().size() + field.get_arrived_count() + field.get_stopped_count(),
		"spawned == marching + arrived + stopped")


func test_hit_decrements_and_a_small_stops_on_one() -> void:
	var field: HordeField = _field()
	var small: HordeMarcher = field.spawn("cat")
	assert_false(small.is_stopped())
	assert_true(field.hit(small), "1 hit stops a small")
	assert_eq(small.hits_left, 0)
	assert_true(small.is_stopped())
	assert_eq(field.get_marching().size(), 0)
	assert_eq(field.get_stopped_count(), 1)
	_assert_counts_add_up(field)


func test_a_medium_needs_two_hits() -> void:
	var field: HordeField = _field()
	var medium: HordeMarcher = field.spawn("frog")
	assert_false(field.hit(medium), "first hit does not stop it")
	assert_eq(medium.hits_left, 1)
	assert_false(medium.is_stopped())
	assert_eq(field.get_marching(), [medium] as Array[HordeMarcher])
	assert_eq(field.get_stopped_count(), 0)
	assert_true(field.hit(medium), "second hit stops it")
	assert_eq(field.get_stopped_count(), 1)
	assert_eq(field.get_marching().size(), 0)


func test_a_stopped_copy_never_marches_or_arrives() -> void:
	var field: HordeField = _field()
	var small: HordeMarcher = field.spawn("cat")
	field.advance(3.0)
	field.hit(small)
	var elapsed: float = small.elapsed_s
	for i: int in 10:
		assert_eq(field.advance(5.0).size(), 0)
	assert_eq(small.elapsed_s, elapsed, "never advanced again")
	assert_false(small.has_arrived())
	assert_eq(field.get_arrived_count(), 0)


func test_hitting_a_copy_not_in_the_field_changes_nothing() -> void:
	var field: HordeField = _field()
	var arrived: HordeMarcher = field.spawn("cat")
	field.advance(8.0)
	assert_eq(field.get_arrived_count(), 1)
	assert_false(field.hit(arrived), "arrived")
	assert_eq(arrived.hits_left, 1)
	var stopped: HordeMarcher = field.spawn("cat")
	assert_true(field.hit(stopped))
	assert_false(field.hit(stopped), "already stopped")
	assert_eq(stopped.hits_left, 0)
	var other: HordeMarcher = _field(3).spawn("frog")
	assert_false(field.hit(other), "from another field")
	assert_eq(other.hits_left, 2)
	assert_false(field.hit(null), "null")
	assert_eq(field.get_stopped_count(), 1)
	assert_eq(field.get_arrived_count(), 1)
	_assert_counts_add_up(field)


func test_counts_add_up_after_a_mixed_sequence() -> void:
	var field: HordeField = _field()
	var a: HordeMarcher = field.spawn("cat")
	var b: HordeMarcher = field.spawn("frog")
	field.spawn("rabbit")
	field.advance(2.0)
	field.hit(b)
	_assert_counts_add_up(field)
	field.hit(a)
	field.spawn("dog")
	_assert_counts_add_up(field)
	field.advance(8.0)
	_assert_counts_add_up(field)
	field.hit(b)
	field.advance(20.0)
	_assert_counts_add_up(field)
	assert_eq(field.get_spawned_count(), 4)
	assert_eq(field.get_stopped_count(), 1, "b had arrived before its second hit")
	assert_eq(field.get_arrived_count(), 3)


## A field whose copies are all in the lane the test says (lane draws come from the RNG, so the
## test sets marcher.lane by hand: the field reads lanes only from the marchers).
func _in_lane(field: HordeField, word: String, lane: int) -> HordeMarcher:
	var marcher: HordeMarcher = field.spawn(word)
	marcher.lane = lane
	return marcher


func test_front_most_in_lane_picks_the_highest_progress() -> void:
	var field: HordeField = _field()
	var back: HordeMarcher = _in_lane(field, "frog", 2)
	field.advance(1.0)
	var front: HordeMarcher = _in_lane(field, "cat", 2)
	_in_lane(field, "dog", 3).elapsed_s = 7.0
	# back: 1/10 = 0.1; front: 0 -> after 1 s: back 0.2, front 0.125.
	field.advance(1.0)
	assert_eq(field.front_most_in_lane(2), back)
	field.advance(4.0)
	# back 0.6, front 5/8 = 0.625: the small has overtaken.
	assert_eq(field.front_most_in_lane(2), front)
	assert_null(field.front_most_in_lane(0), "empty lane")
	assert_null(field.front_most_in_lane(9), "no such lane")


func test_front_most_ties_go_to_the_lower_id() -> void:
	var field: HordeField = _field()
	var first: HordeMarcher = _in_lane(field, "cat", 1)
	var second: HordeMarcher = _in_lane(field, "dog", 1)
	field.advance(2.0)
	assert_eq(first.progress(), second.progress())
	assert_eq(field.front_most_in_lane(1), first)


func test_front_most_respects_at_or_past() -> void:
	var field: HordeField = _field()
	var back: HordeMarcher = _in_lane(field, "cat", 0)
	var front: HordeMarcher = _in_lane(field, "dog", 0)
	back.elapsed_s = 2.0 # 0.25
	front.elapsed_s = 4.0 # 0.5
	assert_eq(field.front_most_in_lane(0, 0.25), front)
	assert_eq(field.front_most_in_lane(0, 0.5), front, "at counts")
	assert_null(field.front_most_in_lane(0, 0.51), "nobody that far")
	assert_eq(field.front_most_in_lane(0, -INF), front)


func test_front_most_skips_stopped_copies() -> void:
	var field: HordeField = _field()
	var back: HordeMarcher = _in_lane(field, "cat", 4)
	var front: HordeMarcher = _in_lane(field, "dog", 4)
	front.elapsed_s = 3.0
	field.hit(front)
	assert_eq(field.front_most_in_lane(4), back)
