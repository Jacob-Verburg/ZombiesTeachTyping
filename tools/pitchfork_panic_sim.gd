extends SceneTree
## Dev-only (Story 8.7): a headless Pitchfork Panic run, the tuning instrument for pitchfork_panic.tres. It
## runs a whole run on a PitchforkPanicConfig through the real ChaseModel and PickupTrail in the level's
## order, with a perfect, steady typist at a fixed WPM, and reports how the run ends and what it pays.
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/pitchfork_panic_sim.gd
## Options: -- --wpm=5,10,20,30 --seeds=200 --gap=30 --start=8 --accel=2 --every=10 --duration=300
##   --pickup=10,30 (min,max steps) --pay=5 (brains per pickup) --bonus=5 --escape-bonus=25. Overrides go
##   on a deep copy of the shipped config; nothing is ever saved or written.
## Prints one row per WPM: end reason, end time, keys, the mean pickups and Pitchfork Panic brains/min over
## seeds 1..N, Zombie Run's brains/min at that WPM (from zombie_run.tres) and the parity (PP / ZR), then
## the escape threshold (the lowest WPM that escapes, by bisection).
## Rules (must match pitchfork_panic_level.gd, or the tuning is fiction):
## - t = 0 is the first correct key: on_run_started() starts the mob and the same key is the first step().
##   Key k lands at k * 12 / wpm s. Every correct key is one step (Space and capitals too), so the
##   Pitchfork Panic WPM keys / 5 / minutes is the wpm.
## - Each logic step of step_s covering (t, t + step_s]: every key landing by t + step_s steps first (input
##   lands before _process), then model.advance(step_s), then a catch ends the run caught at t + step_s.
##   The catch is checked before RunFrame's timer, so a catch in the last step is caught; a run not caught
##   by duration_s escapes there.
## - The chase draws no RNG, so chase() is seed-free. Pickups: one run RNG seeded with the seed; its first
##   randi() seeds the paragraph child (drawn and discarded here), its second the pickup trail
##   (create_target_source). Every pickup at or behind the final zombie_steps is collected (by position,
##   never by time) and pays brains_per_pickup. The global RNG is never used.
## - Brains = pickup brains + completion_bonus + escape_bonus if escaped (RunFrame + get_end_bonus);
##   brains/min divides by the run's end time. Perfect accuracy, no pauses, no hitches (the level's frame
##   cap only ever slows the mob, so a hitch can only help the kid). No quit runs (FR13).
## Tests preload this script for chase(), run(), mean_over_seeds() and escape_threshold_wpm() (tools/ is
## export-excluded); Zombie Run's rate comes from horde_rush_sim.gd, not a copy.

const HordeSim := preload("res://tools/horde_rush_sim.gd")
const PITCHFORK_PANIC_PATH: String = "res://data/levels/pitchfork_panic.tres"
const ZOMBIE_RUN_PATH: String = "res://data/levels/zombie_run.tres"
## The level's own frame step at 60 Hz.
const DEFAULT_STEP_S: float = 1.0 / 60.0
## Characters per word in WPM (FR7).
const CHARS_PER_WORD: float = 5.0
## Slack for float key times landing exactly on a step's end.
const TIME_EPS: float = 1e-9


func _init() -> void:
	var wpms: Array[float] = [5.0, 10.0, 20.0, 30.0]
	var seed_count: int = 200
	var pp: PitchforkPanicConfig = (load(PITCHFORK_PANIC_PATH) as PitchforkPanicConfig).duplicate(true) as PitchforkPanicConfig
	var zr: ZombieRunConfig = load(ZOMBIE_RUN_PATH) as ZombieRunConfig
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--wpm="):
			wpms.clear()
			for part: String in value.split(","):
				if not _is_finite_number(part) or part.to_float() <= 0.0:
					_fail("--wpm needs positive numbers, got '%s'" % part)
					return
				wpms.append(part.to_float())
		elif arg.begins_with("--seeds="):
			if not value.is_valid_int() or value.to_int() < 1:
				_fail("--seeds needs a whole number >= 1, got '%s'" % value)
				return
			seed_count = value.to_int()
		elif arg.begins_with("--gap="):
			if not _is_finite_number(value):
				_fail("--gap needs a number, got '%s'" % value)
				return
			pp.start_gap_steps = value.to_float()
		elif arg.begins_with("--start="):
			if not _is_finite_number(value):
				_fail("--start needs a number, got '%s'" % value)
				return
			pp.mob_start_wpm_eq = value.to_float()
		elif arg.begins_with("--accel="):
			if not _is_finite_number(value):
				_fail("--accel needs a number, got '%s'" % value)
				return
			pp.mob_accel_wpm_eq = value.to_float()
		elif arg.begins_with("--every="):
			if not _is_finite_number(value):
				_fail("--every needs a number, got '%s'" % value)
				return
			pp.mob_accel_every_s = value.to_float()
		elif arg.begins_with("--duration="):
			if not _is_finite_number(value):
				_fail("--duration needs a number, got '%s'" % value)
				return
			pp.duration_s = value.to_float()
		elif arg.begins_with("--pickup="):
			var parts: PackedStringArray = value.split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				_fail("--pickup needs min,max whole numbers, got '%s'" % value)
				return
			pp.pickup_min_steps = parts[0].to_int()
			pp.pickup_max_steps = parts[1].to_int()
		elif arg.begins_with("--pay="):
			if not value.is_valid_int():
				_fail("--pay needs a whole number, got '%s'" % value)
				return
			pp.brains_per_pickup = value.to_int()
		elif arg.begins_with("--bonus="):
			if not value.is_valid_int():
				_fail("--bonus needs a whole number, got '%s'" % value)
				return
			pp.completion_bonus = value.to_int()
		elif arg.begins_with("--escape-bonus="):
			if not value.is_valid_int():
				_fail("--escape-bonus needs a whole number, got '%s'" % value)
				return
			pp.escape_bonus = value.to_int()
		else:
			_fail("unknown argument '%s'" % arg)
			return
	var problem: String = pp.validate()
	if problem != "":
		_fail("config invalid: %s" % problem)
		return
	var seeds: Array[int] = []
	for s: int in range(1, seed_count + 1):
		seeds.append(s)
	print("gap %.1f, mob %.2f + %.2f WPM-eq every %.1f s, duration %.0f s, pickups %d-%d x %d, bonus %d + %d escaped, seeds 1..%d" % [
		pp.start_gap_steps, pp.mob_start_wpm_eq, pp.mob_accel_wpm_eq, pp.mob_accel_every_s, pp.duration_s,
		pp.pickup_min_steps, pp.pickup_max_steps, pp.brains_per_pickup, pp.completion_bonus, pp.escape_bonus,
		seed_count])
	print("WPM | end     | end s | keys | pickups | PP brains/min | ZR brains/min | parity")
	for wpm: float in wpms:
		var mean: Dictionary = mean_over_seeds(pp, wpm, seeds)
		if mean.is_empty():
			_fail("no result at %s WPM" % wpm)
			return
		var zr_per_min: float = HordeSim.zombie_run_brains_per_min(zr, wpm)
		var per_min: float = mean.brains_per_min
		if zr_per_min <= 0.0:
			_fail("Zombie Run pays nothing at %s WPM" % wpm)
			return
		print("%3d | %-7s | %5.1f | %4d | %7.2f | %13.2f | %13.2f | %+5.1f%%" % [
			roundi(wpm), mean.end_reason, mean.end_s, mean.keys, mean.pickups, per_min, zr_per_min,
			(per_min / zr_per_min - 1.0) * 100.0])
	var threshold: float = escape_threshold_wpm(pp)
	if threshold < 0.0:
		print("escape threshold: none up to 60 WPM")
	else:
		print("escape threshold: %.1f WPM" % threshold)
	quit(0)


static func _is_finite_number(text: String) -> bool:
	return text.is_valid_float() and is_finite(text.to_float())


func _fail(message: String) -> void:
	printerr("pitchfork_panic_sim: %s" % message)
	quit(1)


## The seed-free chase on `config` by a perfect typist at `wpm`, in logic steps of `step_s`. Returns
## {end_reason, end_s, keys, measured_wpm}, or {} (and an error) when `wpm` or `step_s` is not positive or
## the config is invalid.
static func chase(config: PitchforkPanicConfig, wpm: float, step_s: float = DEFAULT_STEP_S) -> Dictionary:
	if not (wpm > 0.0 and is_finite(wpm)) or not (step_s > 0.0 and is_finite(step_s)):
		push_error("pitchfork_panic_sim: wpm and step_s must be positive")
		return {}
	var problem: String = config.validate() if config != null else "no config"
	if problem != "":
		push_error("pitchfork_panic_sim: config invalid: %s" % problem)
		return {}
	var model: ChaseModel = ChaseModel.new(config)
	var key_s: float = 60.0 / (CHARS_PER_WORD * wpm)
	var duration: float = config.duration_s
	var steps: int = ceili(duration / step_s - TIME_EPS)
	var keys: int = 0
	var end_reason: StringName = GameConstants.END_REASON_ESCAPED
	var end_s: float = duration
	for i: int in steps:
		var step_end: float = minf((i + 1) * step_s, duration)
		while keys * key_s <= step_end + TIME_EPS:
			model.step()
			keys += 1
		model.advance(step_end - model.elapsed_s)
		if model.caught():
			end_reason = GameConstants.END_REASON_CAUGHT
			end_s = step_end
			break
	return {
		"end_reason": end_reason,
		"end_s": end_s,
		"keys": keys,
		"measured_wpm": keys / CHARS_PER_WORD / (end_s / 60.0),
	}


## chase() plus the pickups run seed `seed` places. Adds {seed, pickups, pickup_brains, bonus, brains,
## brains_per_min}; {} (and an error) as chase(). Never touches the global RNG.
static func run(config: PitchforkPanicConfig, wpm: float, seed: int, step_s: float = DEFAULT_STEP_S) -> Dictionary:
	var result: Dictionary = chase(config, wpm, step_s)
	if result.is_empty():
		return {}
	return _with_pickups(config, result, seed)


## chase() once, then the pickups for every seed in `seeds`: the chase fields plus the means of pickups,
## brains and brains_per_min. Exactly the mean of run() over the same seeds, at one chase's cost.
static func mean_over_seeds(config: PitchforkPanicConfig, wpm: float, seeds: Array[int],
		step_s: float = DEFAULT_STEP_S) -> Dictionary:
	var base: Dictionary = chase(config, wpm, step_s)
	if base.is_empty() or seeds.is_empty():
		return {}
	var pickups: float = 0.0
	var brains: float = 0.0
	var per_min: float = 0.0
	for s: int in seeds:
		var result: Dictionary = _with_pickups(config, base, s)
		pickups += result.pickups as int
		brains += result.brains as int
		per_min += result.brains_per_min as float
	var mean: Dictionary = base.duplicate()
	mean.pickups = pickups / seeds.size()
	mean.brains = brains / seeds.size()
	mean.brains_per_min = per_min / seeds.size()
	return mean


## The lowest WPM (within `tol`) whose chase escapes, by bisection between `lo` and `hi`; -1.0 when `hi`
## is caught. Escaping is monotone in WPM: the gap is concave in time, so ahead at the end means ahead all run.
static func escape_threshold_wpm(config: PitchforkPanicConfig, lo: float = 1.0, hi: float = 60.0,
		tol: float = 0.05) -> float:
	if not _escapes(config, hi):
		return -1.0
	if _escapes(config, lo):
		return lo
	while hi - lo > tol:
		var mid: float = (lo + hi) * 0.5
		if _escapes(config, mid):
			hi = mid
		else:
			lo = mid
	return hi


static func _escapes(config: PitchforkPanicConfig, wpm: float) -> bool:
	var result: Dictionary = chase(config, wpm)
	return not result.is_empty() and result.end_reason == GameConstants.END_REASON_ESCAPED


## `chase_result` plus the pickups, bonus and brains for run seed `seed` (create_target_source's RNG order).
static func _with_pickups(config: PitchforkPanicConfig, chase_result: Dictionary, seed: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	rng.randi() # the paragraph child's seed: the sim deals no text
	var pickup_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pickup_rng.seed = rng.randi()
	var trail: PickupTrail = PickupTrail.new(pickup_rng, config.pickup_min_steps, config.pickup_max_steps)
	var keys: int = chase_result.keys
	trail.fill_to(keys)
	var pickups: int = trail.collect(keys)
	var pickup_brains: int = pickups * config.brains_per_pickup
	var bonus: int = maxi(0, config.completion_bonus)
	if chase_result.end_reason == GameConstants.END_REASON_ESCAPED:
		bonus += maxi(0, config.escape_bonus)
	var end_s: float = chase_result.end_s
	var result: Dictionary = chase_result.duplicate()
	result.seed = seed
	result.pickups = pickups
	result.pickup_brains = pickup_brains
	result.bonus = bonus
	result.brains = pickup_brains + bonus
	result.brains_per_min = (pickup_brains + bonus) / (end_s / 60.0)
	return result
