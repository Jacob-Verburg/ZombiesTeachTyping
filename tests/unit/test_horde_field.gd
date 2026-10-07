extends GutTest
## HordeField / HordeMarcher (Story 6.3): class by word length, ids, progress, exact arrival timing (also
## from 60 Hz steps), independent arrivals in spawn order, bad deltas, the copy getter, and lanes (in
## range, all used, seeded, never the global RNG). The config is built in-test with round numbers.

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
