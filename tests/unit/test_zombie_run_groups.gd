extends GutTest
## Zombie Run groups (Story 3.2, FR32): every group of brain_block_every slots holds exactly 1 brain
## block, shuffled with the injected RNG only (never the global RNG), so a seed replays the layout.

const Kind := ZombieRunGroups.Kind
const GROUP_SIZE: int = 4


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng


func _deal(rng_seed: int, count: int, size: int = GROUP_SIZE) -> Array[Kind]:
	var dealer: ZombieRunGroups = ZombieRunGroups.new(_rng(rng_seed), size)
	var out: Array[Kind] = []
	for i: int in count:
		out.append(dealer.next())
	return out


func test_every_group_has_exactly_one_block() -> void:
	for rng_seed: int in [1, 2, 42, 777, 123456]:
		var rng: RandomNumberGenerator = _rng(rng_seed)
		for i: int in 1000:
			var group: Array[Kind] = ZombieRunGroups.shuffled_group(rng, GROUP_SIZE)
			assert_eq(group.size(), GROUP_SIZE)
			assert_eq(group.count(Kind.BRAIN_BLOCK), 1, "seed %d group %d" % [rng_seed, i])
			assert_eq(group.count(Kind.VILLAGER), GROUP_SIZE - 1)


func test_block_position_is_spread_out() -> void:
	var rng: RandomNumberGenerator = _rng(9)
	var counts: Array[int] = [0, 0, 0, 0]
	var groups: int = 4000
	for i: int in groups:
		counts[ZombieRunGroups.shuffled_group(rng, GROUP_SIZE).find(Kind.BRAIN_BLOCK)] += 1
	for position: int in GROUP_SIZE:
		var share: float = float(counts[position]) / groups
		assert_between(share, 0.2, 0.3, "position %d gets %.3f of the blocks" % [position, share])


func test_dealer_windows_line_up_with_slots() -> void:
	var kinds: Array[Kind] = _deal(5, 400)
	for k: int in 100:
		var window: Array[Kind] = kinds.slice(k * GROUP_SIZE, (k + 1) * GROUP_SIZE)
		assert_eq(window.count(Kind.BRAIN_BLOCK), 1, "slots %d..%d" % [k * GROUP_SIZE, k * GROUP_SIZE + 3])


func test_same_seed_same_kinds() -> void:
	var first: Array[Kind] = _deal(42, 200)
	assert_eq(_deal(42, 200), first)
	assert_ne(_deal(43, 200), first)


func test_independent_of_the_global_rng() -> void:
	seed(1)
	var first: Array[Kind] = _deal(42, 50)
	seed(999)
	assert_eq(_deal(42, 50), first, "only the injected RNG decides the layout")


func test_group_of_one_is_always_a_block() -> void:
	var kinds: Array[Kind] = _deal(3, 20, 1)
	for kind: Kind in kinds:
		assert_eq(kind, Kind.BRAIN_BLOCK)
