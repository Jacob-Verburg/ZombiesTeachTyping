extends GutTest
## The Story 6.7 tuning guard: on the shipped horde_rush.tres and zombie_run.tres, the headless sim
## (tools/horde_rush_sim.gd) must keep the GDD Level 2 arrival targets (35-45 % at 10 WPM, 65-75 % at
## 30 WPM) and economy parity (NFR15: Horde Rush brains/min within +-20 % of Zombie Run's at 5, 10 and
## 20 WPM), mean over SEEDS. A failure here means a number in horde_rush.tres moved away from the tuning
## in the story's Tuning Results: re-run the sim and the Tuning gate, never widen these bands.
## Speed: 5 seeds x 4 WPMs of a whole (3:00) run at the level's 60 Hz step, about a second here.

const Sim := preload("res://tools/horde_rush_sim.gd")
const SEEDS: Array[int] = [1, 2, 3, 4, 5]
## Smuck's floor (Audio gate 2026-10-08): the Farmer paces at half the 6.6 speed or slower.
const MIN_LANE_TIME_S: float = 1.2

var _hr: HordeRushConfig
var _zr: ZombieRunConfig
## Mean sim results by WPM, filled once.
var _means: Dictionary[float, Dictionary] = {}


func before_all() -> void:
	_hr = load("res://data/levels/horde_rush.tres") as HordeRushConfig
	_zr = load("res://data/levels/zombie_run.tres") as ZombieRunConfig
	for wpm: float in [5.0, 10.0, 20.0, 30.0]:
		var rate: float = 0.0
		var per_min: float = 0.0
		for s: int in SEEDS:
			var result: Dictionary = Sim.run(_hr, wpm, s)
			rate += result.arrival_rate as float
			per_min += result.brains_per_min as float
		_means[wpm] = {"arrival_rate": rate / SEEDS.size(), "brains_per_min": per_min / SEEDS.size()}


func test_arrival_rate_at_10_wpm() -> void:
	var rate: float = _means[10.0].arrival_rate
	assert_between(rate, 0.35, 0.45, "10 WPM arrival rate %.3f" % rate)


func test_arrival_rate_at_30_wpm() -> void:
	var rate: float = _means[30.0].arrival_rate
	assert_between(rate, 0.65, 0.75, "30 WPM arrival rate %.3f" % rate)


func test_economy_parity_with_zombie_run() -> void:
	for wpm: float in [5.0, 10.0, 20.0]:
		var hr: float = _means[wpm].brains_per_min
		var zr: float = Sim.zombie_run_brains_per_min(_zr, wpm)
		assert_between(hr / zr, 0.8, 1.2, "%d WPM: Horde Rush %.2f vs Zombie Run %.2f brains/min" % [
			roundi(wpm), hr, zr])


func test_the_farmer_paces_at_half_speed_or_slower() -> void:
	assert_gte(_hr.defender_lane_time_s, MIN_LANE_TIME_S)
