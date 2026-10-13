extends GutTest
## The Story 8.7 tuning guard: on the shipped pitchfork_panic.tres and zombie_run.tres, the headless sim
## (tools/pitchfork_panic_sim.gd) must keep the Level 3 run lengths Smuck set at the 8.7 Tuning gate (the GDD
## mob doubled, a 10 WPM minimum target; FR70 as tuned: a steady 5 WPM typist caught after about 47 s, 10 WPM typist caught after about 70 s,
## 63-77 s; 20 WPM after about 2.4 min, 130-158 s; 37 and 40 WPM escape; the escape threshold at most
## 37 WPM) and economy parity (NFR15: Pitchfork Panic brains/min within +-20 % of Zombie
## Run's at 5, 10 and 20 WPM), mean over SEEDS. These bands are AC numbers. A failure means a number in
## pitchfork_panic.tres moved away from the tuning in the story's Tuning Results: re-run the sim and the
## Tuning gate, never widen these bands.
## Speed: mean_over_seeds runs one chase per WPM plus 200 cheap pickup trails, and the threshold is a
## bisection of chases; well under a second here.

const Sim := preload("res://tools/pitchfork_panic_sim.gd")
const HordeSim := preload("res://tools/horde_rush_sim.gd")
const SEED_COUNT: int = 200

var _pp: PitchforkPanicConfig
var _zr: ZombieRunConfig
## Seeds 1..SEED_COUNT, built once (never chosen for a result).
var _seeds: Array[int] = []
## Mean sim results by WPM, filled once.
var _means: Dictionary[float, Dictionary] = {}


func before_all() -> void:
	_pp = load("res://data/levels/pitchfork_panic.tres") as PitchforkPanicConfig
	_zr = load("res://data/levels/zombie_run.tres") as ZombieRunConfig
	for s: int in range(1, SEED_COUNT + 1):
		_seeds.append(s)
	for wpm: float in [5.0, 10.0, 20.0, 37.0, 40.0]:
		_means[wpm] = Sim.mean_over_seeds(_pp, wpm, _seeds)


func test_5_wpm_is_caught_after_about_47_s() -> void:
	var result: Dictionary = _means[5.0]
	assert_eq(result.end_reason, GameConstants.END_REASON_CAUGHT)
	assert_between(result.end_s as float, 43.0, 52.0, "5 WPM caught at %.1f s" % result.end_s)


func test_10_wpm_is_caught_after_about_70_s() -> void:
	var result: Dictionary = _means[10.0]
	assert_eq(result.end_reason, GameConstants.END_REASON_CAUGHT)
	assert_between(result.end_s as float, 63.0, 77.0, "10 WPM caught at %.1f s" % result.end_s)


func test_20_wpm_is_caught_after_about_2_4_minutes() -> void:
	var result: Dictionary = _means[20.0]
	assert_eq(result.end_reason, GameConstants.END_REASON_CAUGHT)
	assert_between(result.end_s as float, 130.0, 158.0, "20 WPM caught at %.1f s" % result.end_s)


func test_37_and_40_wpm_escape() -> void:
	for wpm: float in [37.0, 40.0]:
		assert_eq(_means[wpm].end_reason, GameConstants.END_REASON_ESCAPED, "%d WPM" % roundi(wpm))


func test_escape_threshold_is_at_most_37_wpm() -> void:
	var threshold: float = Sim.escape_threshold_wpm(_pp)
	assert_gt(threshold, 0.0, "some WPM escapes")
	assert_lte(threshold, 37.0, "escape threshold %.2f WPM" % threshold)


func test_economy_parity_with_zombie_run() -> void:
	for wpm: float in [5.0, 10.0, 20.0]:
		var pp: float = _means[wpm].brains_per_min
		var zr: float = HordeSim.zombie_run_brains_per_min(_zr, wpm)
		assert_between(pp / zr, 0.8, 1.2, "%d WPM: Pitchfork Panic %.2f vs Zombie Run %.2f brains/min" % [
			roundi(wpm), pp, zr])
