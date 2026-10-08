extends GutTest
## HordeDefender / HordeProjectile (Story 6.4): pacing and reversal, the one-lane field, the throw
## cooldown, front-most aiming, flight time, multi-hit stops, contact over aim (overtaking), spare
## projectiles hitting the next copy or missing, the march-first tie rule, bad deltas, a pinned 60 s
## headless run, and no global RNG. Configs are built in-test; every run steps the field first, then the
## defender (the level's step order).

const STEP: float = 1.0 / 60.0
const LANES: int = 5

var _field: HordeField
var _defender: HordeDefender
## Every Step the helper got back, in order.
var _steps_seen: Array[HordeDefender.Step] = []
var _arrived: Array[HordeMarcher] = []


func _config(lanes: int = LANES) -> HordeRushConfig:
	var config: HordeRushConfig = HordeRushConfig.new()
	config.lane_count = lanes
	config.size_classes = [_size(&"small", 3, 8.0, 1), _size(&"medium", 5, 10.0, 2), _size(&"brute", 0, 13.0, 3)]
	config.defender_lane_time_s = 0.6
	config.defender_throw_cooldown_s = 0.8
	config.projectile_cross_time_s = 1.0
	config.hit_flash_s = 0.15
	config.melt_s = 0.6
	return config


func _size(id: StringName, max_len: int, crossing: float, hits: int) -> HordeSizeClass:
	var size_class: HordeSizeClass = HordeSizeClass.new()
	size_class.id = id
	size_class.max_word_length = max_len
	size_class.crossing_time_s = crossing
	size_class.hits_to_stop = hits
	size_class.arrival_brains = hits
	return size_class


func _setup(lanes: int = LANES, lane_seed: int = 7) -> void:
	var config: HordeRushConfig = _config(lanes)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = lane_seed
	_field = HordeField.new(config, rng)
	_defender = HordeDefender.new(config)
	_steps_seen = []
	_arrived = []


## A copy in `lane` (set by hand; the field reads lanes only from the marchers) at `progress`.
func _copy(word: String, lane: int, progress: float = 0.0) -> HordeMarcher:
	var marcher: HordeMarcher = _field.spawn(word)
	marcher.lane = lane
	marcher.elapsed_s = progress * marcher.size_class.crossing_time_s
	return marcher


## One logic step in the level's order: march first, then the defender.
func _step() -> HordeDefender.Step:
	_arrived.append_array(_field.advance(STEP))
	var step: HordeDefender.Step = _defender.advance(STEP, _field)
	_steps_seen.append(step)
	return step


func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_step()


func _thrown_steps() -> Array[int]:
	var steps: Array[int] = []
	for i: int in _steps_seen.size():
		if not _steps_seen[i].thrown.is_empty():
			steps.append(i + 1)
	return steps


# --- pacing ---------------------------------------------------------------------------------------

func test_pacing_positions_and_reversal() -> void:
	_setup()
	assert_eq(_defender.position(), 0.0)
	assert_eq(_defender.current_lane(), 0)
	assert_true(_defender.is_heading_down())
	var checks: Dictionary[float, float] = {0.3: 0.5, 0.6: 1.0, 2.4: 4.0, 3.0: 3.0, 4.8: 0.0}
	var done: float = 0.0
	for at: float in checks:
		_run(at - done)
		done = at
		assert_almost_eq(_defender.position(), checks[at], 1e-3, "position at %s s" % at)
	_setup()
	_run(0.25)
	assert_eq(_defender.current_lane(), 0, "0.42 rounds to lane 0")
	_run(0.1)
	assert_eq(_defender.current_lane(), 1, "0.58 rounds to lane 1")


func test_heading_follows_the_bounces() -> void:
	_setup()
	_run(1.2)
	assert_true(_defender.is_heading_down(), "lane 2 on the way down")
	_run(1.8)
	assert_false(_defender.is_heading_down(), "lane 3 on the way back up")
	_run(1.9)
	assert_true(_defender.is_heading_down(), "past the top again")


func test_one_lane_stays_put() -> void:
	_setup(1)
	_run(5.0)
	assert_eq(_defender.position(), 0.0)
	assert_eq(_defender.current_lane(), 0)


func test_bad_deltas_change_nothing() -> void:
	_setup()
	var copy: HordeMarcher = _copy("cat", 0, 0.5)
	for delta: float in [0.0, -1.0, INF, -INF, NAN]:
		var step: HordeDefender.Step = _defender.advance(delta, _field)
		assert_eq(step.thrown.size(), 0, str(delta))
		assert_eq(step.landed.size(), 0, str(delta))
		assert_eq(_defender.position(), 0.0, str(delta))
	assert_eq(_defender.get_thrown_count(), 0)
	assert_eq(copy.hits_left, 1)


# --- throwing -------------------------------------------------------------------------------------

func test_no_throw_into_an_empty_lane() -> void:
	_setup()
	_copy("cat", 3, 0.0)
	_run(0.25)
	assert_eq(_defender.get_thrown_count(), 0, "lane 0 is empty")
	assert_eq(_defender.get_flying().size(), 0)


func test_throws_on_the_first_step_at_the_front_most() -> void:
	_setup()
	var back: HordeMarcher = _copy("cat", 0, 0.1)
	var front: HordeMarcher = _copy("dog", 0, 0.3)
	var step: HordeDefender.Step = _step()
	assert_eq(step.thrown.size(), 1, "ready at run start")
	var projectile: HordeProjectile = step.thrown[0]
	assert_eq(projectile.id, 0)
	assert_eq(projectile.lane, 0)
	assert_eq(projectile.position, 1.0, "starts at the house line and waits a step")
	assert_eq(projectile.aimed_at, front)
	assert_ne(projectile.aimed_at, back)
	assert_null(projectile.hit_marcher)
	assert_eq(_defender.get_flying(), [projectile] as Array[HordeProjectile])


func test_cooldown_spaces_throws_even_with_every_lane_full() -> void:
	_setup()
	for lane: int in LANES:
		_copy("rabbit", lane, 0.0)
		_copy("rabbit", lane, 0.0)
	_run(3.0)
	var thrown: Array[int] = _thrown_steps()
	assert_eq(thrown[0], 1)
	for i: int in range(1, thrown.size()):
		assert_eq(thrown[i] - thrown[i - 1], 48, "0.8 s = 48 steps between throws (%d)" % i)
	assert_eq(thrown.size(), 4, "steps 1, 49, 97, 145 in 3 s")
	for step: HordeDefender.Step in _steps_seen:
		assert_true(step.thrown.size() <= 1, "at most one throw per step")


func test_throw_lane_is_the_rounded_position() -> void:
	_setup()
	for lane: int in LANES:
		_copy("rabbit", lane, 0.0)
	_run(0.85)
	var flying: Array[HordeProjectile] = _defender.get_flying()
	assert_eq(flying.size(), 2)
	# Step 49 = 0.8167 s: 1.361 lanes paced, so lane 1.
	assert_eq(flying[1].lane, 1)


func test_get_flying_is_a_copy() -> void:
	_setup()
	_copy("cat", 0, 0.0)
	_step()
	_defender.get_flying().clear()
	assert_eq(_defender.get_flying().size(), 1)


# --- flight and hits ------------------------------------------------------------------------------

func test_flight_time_to_a_marching_copy() -> void:
	_setup()
	var p: float = 0.2
	var copy: HordeMarcher = _copy("cat", 0, p)
	var hit_at: int = -1
	for i: int in 120:
		if not _step().landed.is_empty():
			hit_at = i + 1
			break
	assert_gt(hit_at, 0, "it landed")
	# Thrown on step 1 from 1.0; closing speed 1/1.0 + 1/8.0 per second.
	var expected_s: float = STEP + (1.0 - (p + STEP / 8.0)) / (1.0 / 1.0 + 1.0 / 8.0)
	assert_almost_eq(hit_at * STEP, expected_s, STEP, "lands within one step of the closing time")
	assert_true(copy.is_stopped())
	assert_eq(_defender.get_hit_count(), 1)


func test_a_projectile_keeps_its_lane() -> void:
	_setup()
	_copy("cat", 0, 0.0)
	var projectile: HordeProjectile = _step().thrown[0]
	_run(0.6)
	assert_ne(_defender.current_lane(), 0, "the defender moved on")
	assert_eq(projectile.lane, 0)
	assert_almost_eq(projectile.position, 1.0 - 0.6, 1e-3)


func test_a_small_stops_on_one_hit_and_a_medium_on_two() -> void:
	_setup(1)
	var small: HordeMarcher = _copy("cat", 0, 0.0)
	var landed: Array[HordeProjectile] = []
	while landed.is_empty():
		landed.append_array(_step().landed)
	assert_eq(landed[0].hit_marcher, small)
	assert_true(landed[0].stopped_marcher)
	assert_true(small.is_stopped())
	assert_eq(_field.get_stopped_count(), 1)

	_setup(1)
	var medium: HordeMarcher = _copy("frog", 0, 0.0)
	landed = []
	while landed.size() < 2:
		landed.append_array(_step().landed)
	assert_eq(landed[0].hit_marcher, medium)
	assert_false(landed[0].stopped_marcher, "first hit: still marching")
	assert_eq(landed[1].hit_marcher, medium)
	assert_true(landed[1].stopped_marcher)
	assert_eq(_field.get_stopped_count(), 1)
	assert_eq(_defender.get_hit_count(), 2)


func test_a_stopped_copy_never_arrives() -> void:
	_setup(1)
	var small: HordeMarcher = _copy("cat", 0, 0.0)
	_run(20.0)
	assert_true(small.is_stopped())
	assert_eq(_field.get_arrived_count(), 0)
	assert_eq(_arrived.size(), 0)
	assert_lt(small.progress(), 1.0)


func test_contact_decides_not_aim() -> void:
	_setup()
	var medium: HordeMarcher = _copy("frog", 0, 0.5)
	var small: HordeMarcher = _copy("cat", 0, 0.495)
	var projectile: HordeProjectile = _step().thrown[0]
	assert_eq(projectile.aimed_at, medium, "the medium is ahead when thrown")
	while projectile.hit_marcher == null and projectile.position > 0.0:
		_step()
	# The faster small overtakes after 0.2 s; contact is after about 0.45 s.
	assert_eq(projectile.hit_marcher, small, "the small had overtaken")
	assert_true(small.is_stopped())
	assert_eq(medium.hits_left, 2)


func test_a_spare_projectile_hits_the_copy_behind() -> void:
	_setup(1)
	var front: HordeMarcher = _copy("cat", 0, 0.0)
	var behind: HordeMarcher = _copy("frog", 0, 0.0)
	var projectiles: Array[HordeProjectile] = []
	while projectiles.size() < 2:
		projectiles.append_array(_step().thrown)
	# Both were aimed at the small (faster, so in front); the first stops it after ~0.9 s.
	assert_eq(projectiles[0].aimed_at, front)
	assert_eq(projectiles[1].aimed_at, front)
	while projectiles[1].hit_marcher == null and projectiles[1].position > 0.0:
		_step()
	assert_eq(projectiles[0].hit_marcher, front)
	assert_true(front.is_stopped())
	assert_eq(projectiles[1].hit_marcher, behind, "the spare flew on into the next copy")
	assert_eq(behind.hits_left, 1)


func test_a_spare_projectile_with_nobody_behind_misses() -> void:
	_setup(1)
	var only: HordeMarcher = _copy("cat", 0, 0.0)
	var landed: Array[HordeProjectile] = []
	var thrown: int = 0
	for i: int in roundi(2.5 / STEP):
		var step: HordeDefender.Step = _step()
		thrown += step.thrown.size()
		landed.append_array(step.landed)
	assert_true(only.is_stopped())
	assert_eq(thrown, 2, "a second throw while the first was still in the air, then an empty lane")
	assert_eq(landed.size(), 2)
	assert_eq(landed[0].hit_marcher, only)
	assert_null(landed[1].hit_marcher, "a miss")
	assert_false(landed[1].stopped_marcher)
	assert_true(landed[1].position <= 0.0, "it reached the left edge")
	assert_eq(_defender.get_miss_count(), 1)
	assert_eq(_defender.get_hit_count(), 1)
	assert_eq(_defender.get_flying().size(), 0)


func test_an_arrival_in_the_same_step_beats_the_hit() -> void:
	_setup(1)
	var copy: HordeMarcher = _copy("cat", 0, 0.0)
	copy.elapsed_s = 8.0 - 1.5 * STEP
	var projectile: HordeProjectile = _step().thrown[0]
	assert_eq(projectile.aimed_at, copy)
	assert_eq(_step().landed.size(), 0, "march first: it is home before the projectile moves")
	assert_eq(_arrived, [copy] as Array[HordeMarcher])
	assert_eq(copy.hits_left, 1)
	assert_null(projectile.hit_marcher)
	assert_eq(_defender.get_hit_count(), 0)


func test_landed_lists_follow_throw_order() -> void:
	_setup(1)
	for i: int in 3:
		_copy("rabbit", 0, 0.0)
	var landed: Array[HordeProjectile] = []
	_run(4.0)
	for step: HordeDefender.Step in _steps_seen:
		landed.append_array(step.landed)
	assert_gt(landed.size(), 2)
	for i: int in landed.size():
		assert_eq(landed[i].id, i, "landed in throw order")


# --- determinism ----------------------------------------------------------------------------------

const WORDS: Array[String] = ["cat", "frog", "tiger", "dog", "sun", "milk", "pig", "lamp"]
## One word every 2.5 s.
const SPAWN_EVERY_STEPS: int = 150


## A 60 s headless run on the GDD numbers: [counts, (step, lane, hit id) for every hit].
func _headless(lane_seed: int) -> Array:
	_setup(LANES, lane_seed)
	var hits: Array[Vector3i] = []
	var spawned: int = 0
	for i: int in roundi(60.0 / STEP):
		if i % SPAWN_EVERY_STEPS == 0:
			_field.spawn(WORDS[spawned % WORDS.size()])
			spawned += 1
		for projectile: HordeProjectile in _step().landed:
			if projectile.hit_marcher != null:
				hits.append(Vector3i(i + 1, projectile.lane, projectile.hit_marcher.id))
	var counts: Array[int] = [
		_field.get_spawned_count(), _defender.get_thrown_count(), _defender.get_hit_count(),
		_defender.get_miss_count(), _field.get_stopped_count(), _field.get_arrived_count(),
	]
	return [counts, hits]


func test_headless_run_is_deterministic() -> void:
	var first: Array = _headless(7)
	assert_eq(_headless(7), first, "same seed, same everything")
	assert_ne(_headless(8)[1], first[1], "another lane seed, another story")


func test_headless_run_on_seed_7_is_pinned() -> void:
	var run: Array = _headless(7)
	var counts: Array[int] = run[0]
	# [spawned, thrown, hits, misses, stopped, arrived], observed once (Story 6.4 Debug Log). A change
	# here means the step order or a rule changed.
	assert_eq(counts, PINNED_SEED_7_COUNTS)
	assert_eq(counts[0], counts[4] + counts[5] + _field.get_marching().size(), "every copy accounted for")
	assert_eq(counts[1], counts[2] + counts[3] + _defender.get_flying().size(), "every throw accounted for")


func test_never_touches_the_global_rng() -> void:
	seed(1)
	var first: Array = _headless(7)
	seed(999)
	assert_eq(_headless(7), first, "only the lane RNG decides anything")
	randomize() # leave the global RNG unseeded for later tests


const PINNED_SEED_7_COUNTS: Array[int] = [24, 31, 31, 0, 20, 3]
