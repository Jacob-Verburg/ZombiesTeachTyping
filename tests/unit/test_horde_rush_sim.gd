extends GutTest
## The headless Horde Rush sim (Story 6.7, tools/horde_rush_sim.gd): determinism, the WPM pacing (Horde
## Rush WPM, implied space included, FR7), every copy accounted for, a defender that never throws lets
## every decided copy arrive, the global RNG is never used, and Zombie Run's brains/min from its resource
## match the GDD economy table. Runs use the shipped config (read only) or a deep duplicate of it.

const Sim := preload("res://tools/horde_rush_sim.gd")
const HORDE_RUSH_PATH: String = "res://data/levels/horde_rush.tres"
const ZOMBIE_RUN_PATH: String = "res://data/levels/zombie_run.tres"


func _shipped() -> HordeRushConfig:
	return load(HORDE_RUSH_PATH) as HordeRushConfig


## A deep duplicate of the shipped config with a `duration_s` run, so short runs stay fast.
func _short(duration_s: float) -> HordeRushConfig:
	var config: HordeRushConfig = _shipped().duplicate(true) as HordeRushConfig
	config.duration_s = duration_s
	return config


func test_same_config_wpm_and_seed_give_identical_numbers() -> void:
	var config: HordeRushConfig = _short(60.0)
	var first: Dictionary = Sim.run(config, 20.0, 3)
	assert_eq(Sim.run(config, 20.0, 3), first)


func test_another_seed_gives_another_run() -> void:
	var config: HordeRushConfig = _short(120.0)
	var first: Dictionary = Sim.run(config, 20.0, 3)
	var other: Dictionary = Sim.run(config, 20.0, 4)
	assert_ne(other, first, "other words and lanes, other counts")


func test_measured_wpm_matches_the_requested_wpm() -> void:
	var config: HordeRushConfig = _shipped()
	for wpm: float in [5.0, 10.0, 30.0]:
		var result: Dictionary = Sim.run(config, wpm, 1)
		assert_almost_eq(result.measured_wpm as float, wpm, 0.5, "%d WPM over a whole run" % roundi(wpm))


func test_every_copy_is_accounted_for() -> void:
	var result: Dictionary = Sim.run(_short(90.0), 30.0, 2)
	assert_gt(result.spawned as int, 0)
	assert_eq(result.spawned as int, (result.arrived as int) + (result.stopped as int) + (result.marching as int))
	assert_eq(result.words, result.spawned, "one copy per completed word")


func test_a_defender_that_never_throws_again_lets_every_other_decided_copy_arrive() -> void:
	var config: HordeRushConfig = _short(90.0)
	config.defender_throw_cooldown_s = 1e6
	var result: Dictionary = Sim.run(config, 20.0, 5)
	# The first throw is ready at t = 0, so at most one copy (a small one, one hit) can ever be stopped.
	assert_lte(result.stopped as int, 1)
	assert_gt(result.arrived as int, 10)
	assert_gt(result.arrival_rate as float, 0.9)


func test_a_non_positive_wpm_or_step_is_refused() -> void:
	var config: HordeRushConfig = _short(30.0)
	assert_eq(Sim.run(config, 0.0, 1), {})
	assert_push_error("must be positive")
	assert_eq(Sim.run(config, -5.0, 1), {})
	assert_push_error("must be positive")
	assert_eq(Sim.run(config, 10.0, 1, 0.0), {})
	assert_push_error("must be positive")


func test_brains_per_minute_includes_the_bonus() -> void:
	var config: HordeRushConfig = _short(60.0)
	var result: Dictionary = Sim.run(config, 10.0, 1)
	assert_almost_eq(result.brains_per_min as float,
		float((result.arrival_brains as int) + config.completion_bonus), 1e-4, "a one-minute run")


func test_copies_still_marching_at_the_end_never_pay() -> void:
	var config: HordeRushConfig = _short(5.0)
	var result: Dictionary = Sim.run(config, 30.0, 1)
	# A small crossing is 8 s: in a 5 s run nothing can arrive.
	assert_eq(result.arrived, 0)
	assert_eq(result.arrival_brains, 0)
	assert_gt(result.marching as int, 0)


func test_never_touches_the_global_rng() -> void:
	var config: HordeRushConfig = _short(60.0)
	seed(1)
	var first: Dictionary = Sim.run(config, 20.0, 9)
	seed(999)
	assert_eq(Sim.run(config, 20.0, 9), first, "only the run seed decides anything")


func after_each() -> void:
	randomize() # whatever a test seeded, leave the global RNG unseeded for later tests


func test_zombie_run_brains_per_minute_matches_the_gdd_table() -> void:
	var zr: ZombieRunConfig = load(ZOMBIE_RUN_PATH) as ZombieRunConfig
	assert_almost_eq(Sim.zombie_run_brains_per_min(zr, 5.0), 11.25, 1e-4)
	assert_almost_eq(Sim.zombie_run_brains_per_min(zr, 10.0), 17.5, 1e-4)
	assert_almost_eq(Sim.zombie_run_brains_per_min(zr, 20.0), 30.0, 1e-4)
