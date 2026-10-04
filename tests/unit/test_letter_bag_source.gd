extends GutTest
## Letter bag (Story 2.2): every letter once per bag, no immediate repeat (also across bags), seeded.

const SEEDS: Array[int] = [1, 2, 3, 42, 12345]


func _alphabet() -> Array[String]:
	var out: Array[String] = []
	for code: int in range(97, 123):
		out.append(String.chr(code))
	return out


func _make(rng_seed: int, pool: Array[String] = _alphabet()) -> LetterBagSource:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return LetterBagSource.new(rng, pool)


func _draw(source: LetterBagSource, count: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in count:
		out.append(source.current())
		source.advance()
	return out


func _assert_no_adjacent_repeat(draws: Array[String], label: String) -> void:
	for i: int in range(1, draws.size()):
		if draws[i] == draws[i - 1]:
			fail_test("%s: repeat '%s' at index %d" % [label, draws[i], i])
			return
	pass_test("%s: no adjacent repeat" % label)


func _assert_chunks_are_permutations(draws: Array[String], pool: Array[String], label: String) -> void:
	var size: int = pool.size()
	var expected: Array[String] = pool.duplicate()
	expected.sort()
	var chunk_start: int = 0
	while chunk_start + size <= draws.size():
		var chunk: Array[String] = []
		for i: int in size:
			chunk.append(draws[chunk_start + i])
		chunk.sort()
		if chunk != expected:
			fail_test("%s: chunk at %d is not a permutation: %s" % [label, chunk_start, chunk])
			return
		chunk_start += size
	pass_test("%s: all chunks are permutations" % label)


func test_every_letter_once_per_bag_over_1000_draws() -> void:
	for rng_seed: int in SEEDS:
		_assert_chunks_are_permutations(_draw(_make(rng_seed), 1000), _alphabet(), "seed %d" % rng_seed)


func test_never_same_letter_twice_in_a_row_across_bag_boundaries() -> void:
	for rng_seed: int in SEEDS:
		_assert_no_adjacent_repeat(_draw(_make(rng_seed), 1000), "seed %d" % rng_seed)


func test_two_letter_pool_strictly_alternates() -> void:
	var pool: Array[String] = ["a", "b"]
	for rng_seed: int in SEEDS:
		var draws: Array[String] = _draw(_make(rng_seed, pool), 1000)
		_assert_no_adjacent_repeat(draws, "pool 2 seed %d" % rng_seed)
		_assert_chunks_are_permutations(draws, pool, "pool 2 seed %d" % rng_seed)


func test_three_letter_pool_bags_and_no_repeat() -> void:
	var pool: Array[String] = ["a", "b", "c"]
	for rng_seed: int in SEEDS:
		var draws: Array[String] = _draw(_make(rng_seed, pool), 999)
		_assert_no_adjacent_repeat(draws, "pool 3 seed %d" % rng_seed)
		_assert_chunks_are_permutations(draws, pool, "pool 3 seed %d" % rng_seed)


func test_same_seed_gives_identical_sequence() -> void:
	assert_eq(_draw(_make(7), 200), _draw(_make(7), 200))


func test_different_seed_gives_different_sequence() -> void:
	assert_ne(_draw(_make(7), 200), _draw(_make(8), 200))


func test_peek_does_not_change_the_sequence() -> void:
	var plain: Array[String] = _draw(_make(99), 130)
	var source: LetterBagSource = _make(99)
	var peeked: Array[String] = []
	for i: int in 120:
		var current: String = source.current()
		var ahead: Array[String] = source.peek(10)
		assert_eq(source.current(), current, "peek must not change current()")
		peeked.append(current)
		assert_eq(ahead, plain.slice(i + 1, i + 11), "peek(10) at %d is the next 10 targets" % i)
		source.advance()
	assert_eq(peeked, plain.slice(0, 120))


func test_peek_edge_cases() -> void:
	var source: LetterBagSource = _make(5)
	assert_eq(source.peek(0), [] as Array[String])
	assert_eq(source.peek(-3), [] as Array[String])
	assert_eq(source.peek(3).size(), 3)
	var far: Array[String] = source.peek(60)
	assert_eq(far.size(), 60)
	var with_current: Array[String] = [source.current()]
	with_current.append_array(far)
	_assert_no_adjacent_repeat(with_current, "peek(60)")


func test_peek_excludes_current() -> void:
	var source: LetterBagSource = _make(11)
	var first: String = source.current()
	assert_ne(source.peek(1)[0], first)
	source.advance()
	assert_eq(source.current(), _make(11).peek(1)[0])


func test_injected_rng_is_used() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var before: int = rng.state
	var source: LetterBagSource = LetterBagSource.new(rng, _alphabet())
	source.current()
	assert_ne(rng.state, before, "dealing a bag must consume the injected RNG")


func test_two_sources_sharing_one_rng_both_advance_it() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var a: LetterBagSource = LetterBagSource.new(rng, _alphabet())
	var b: LetterBagSource = LetterBagSource.new(rng, _alphabet())
	var start: int = rng.state
	_draw(a, 26)
	var after_a: int = rng.state
	assert_ne(after_a, start, "source a must deal from the shared RNG")
	var b_draws: Array[String] = _draw(b, 26)
	assert_ne(rng.state, after_a, "source b must deal from the shared RNG")
	# b dealt after a consumed the RNG, so its bag differs from a fresh source on the same seed.
	assert_ne(b_draws, _draw(_make(3), 26), "source b must not use a hidden RNG of its own")


func test_pool_is_not_mutated() -> void:
	var pool: Array[String] = _alphabet()
	var source: LetterBagSource = _make(4, pool)
	_draw(source, 100)
	assert_eq(pool, _alphabet())
