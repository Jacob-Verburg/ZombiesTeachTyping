extends SceneTree
## Dev-only (Story 6.7): a headless Horde Rush run, the tuning instrument for horde_rush.tres. It runs a
## whole run on a HordeRushConfig through the real WordSource, HordeField and HordeDefender in the level's
## step order, with a perfect typist at a fixed WPM, and reports what the level would have paid.
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/horde_rush_sim.gd
## Options: -- --wpm=5,10,20,30 --seeds=10 --lane-time=1.2 --cooldown=0.8 --projectile=1.0 --bonus=25
##   --duration=180
##   --brains=1,2,3 (small, medium, brute arrival brains). Overrides go on a deep copy of the shipped
##   config; nothing is ever saved or written.
## Prints one row per WPM: the mean over seeds 1..N of arrival rate, arrivals, brains/min, Zombie Run's
## brains/min at that WPM (from zombie_run.tres) and the parity (Horde Rush / Zombie Run).
## Rules (must match horde_rush_level.gd, or the tuning is fiction):
## - One run RNG seeded with the seed; the word RNG is seeded with its first randi(), the lane RNG with
##   its second (create_target_source). The defender has no RNG. The global RNG is never used.
## - t = 0 is the first correct key (the clock and the defender start there), so it is word 1's first
##   letter. One character every 12 / wpm s; a word of length L completes L - 1 slots after its first key,
##   and each finished word's implied space takes one slot, so the Horde Rush WPM
##   (keys + words) / 5 / minutes is the wpm. (Fixed in the 6.7 review: copies used to spawn one slot late.)
## - Before each logic step, every word completed by the step's start spawns (a key lands before the
##   next _process). Each step: field.advance(dt), arrivals pay their class's arrival_brains, then
##   defender.advance(dt, field).
## - At duration_s the run ends: copies still marching never pay. Perfect accuracy, no pauses, no hitches
##   (the level's hitch cap only ever drops time, so a hitch can only cost brains).
## Tests preload this script for run() and zombie_run_brains_per_min() (tools/ is export-excluded).

const HORDE_RUSH_PATH: String = "res://data/levels/horde_rush.tres"
const ZOMBIE_RUN_PATH: String = "res://data/levels/zombie_run.tres"
## The level's own frame step at 60 Hz.
const DEFAULT_STEP_S: float = 1.0 / 60.0
## Characters per word in WPM (FR7).
const CHARS_PER_WORD: float = 5.0


func _init() -> void:
	var wpms: Array[float] = [5.0, 10.0, 20.0, 30.0]
	var seeds: int = 10
	var hr: HordeRushConfig = (load(HORDE_RUSH_PATH) as HordeRushConfig).duplicate(true) as HordeRushConfig
	var zr: ZombieRunConfig = load(ZOMBIE_RUN_PATH) as ZombieRunConfig
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		if arg.begins_with("--wpm="):
			wpms.clear()
			for part: String in value.split(","):
				if not part.is_valid_float() or part.to_float() <= 0.0:
					printerr("horde_rush_sim: --wpm needs positive numbers, got '%s'" % part)
					quit(1)
					return
				wpms.append(part.to_float())
		elif arg.begins_with("--seeds="):
			if not value.is_valid_int() or value.to_int() < 1:
				printerr("horde_rush_sim: --seeds needs a whole number >= 1, got '%s'" % value)
				quit(1)
				return
			seeds = value.to_int()
		elif arg.begins_with("--lane-time="):
			hr.defender_lane_time_s = value.to_float()
		elif arg.begins_with("--cooldown="):
			hr.defender_throw_cooldown_s = value.to_float()
		elif arg.begins_with("--projectile="):
			hr.projectile_cross_time_s = value.to_float()
		elif arg.begins_with("--duration="):
			hr.duration_s = value.to_float()
		elif arg.begins_with("--bonus="):
			hr.completion_bonus = value.to_int()
		elif arg.begins_with("--brains="):
			var parts: PackedStringArray = value.split(",")
			for i: int in mini(parts.size(), hr.size_classes.size()):
				hr.size_classes[i].arrival_brains = parts[i].to_int()
		else:
			printerr("horde_rush_sim: unknown argument '%s'" % arg)
			quit(1)
			return
	var problem: String = hr.validate()
	if problem != "":
		printerr("horde_rush_sim: config invalid: %s" % problem)
		quit(1)
		return
	print("lane %.2f s, cooldown %.2f s, projectile %.2f s, bonus %d, brains %s, seeds 1..%d" % [
		hr.defender_lane_time_s, hr.defender_throw_cooldown_s, hr.projectile_cross_time_s,
		hr.completion_bonus, _brains_text(hr), seeds])
	print("WPM | arrival % | arrived | stopped | HR brains/min | ZR brains/min | parity")
	for wpm: float in wpms:
		var rate: float = 0.0
		var arrived: float = 0.0
		var stopped: float = 0.0
		var per_min: float = 0.0
		for s: int in range(1, seeds + 1):
			var result: Dictionary = run(hr, wpm, s)
			rate += result.arrival_rate
			arrived += result.arrived
			stopped += result.stopped
			per_min += result.brains_per_min
		rate /= seeds
		arrived /= seeds
		stopped /= seeds
		per_min /= seeds
		var zr_per_min: float = zombie_run_brains_per_min(zr, wpm)
		print("%3d | %8.1f%% | %7.1f | %7.1f | %13.2f | %13.2f | %5.0f%%" % [
			roundi(wpm), rate * 100.0, arrived, stopped, per_min, zr_per_min, per_min / zr_per_min * 100.0])
	quit(0)


func _brains_text(config: HordeRushConfig) -> String:
	var parts: PackedStringArray = []
	for size_class: HordeSizeClass in config.size_classes:
		parts.append(str(size_class.arrival_brains))
	return "/".join(parts)


## One whole run on `config` by a perfect typist at `wpm` (Horde Rush WPM, implied space included) with
## run seed `seed`, in logic steps of `step_s`. Returns {spawned, arrived, stopped, marching,
## arrival_brains, arrival_rate, brains_per_min, words, keys, measured_wpm}, or {} (and an error) when
## `wpm`, `step_s` or the duration is not positive. Never touches the global RNG.
static func run(config: HordeRushConfig, wpm: float, seed: int, step_s: float = DEFAULT_STEP_S) -> Dictionary:
	if wpm <= 0.0 or step_s <= 0.0 or config.duration_s <= 0.0:
		push_error("horde_rush_sim: wpm, step_s and duration_s must be positive")
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var word_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	word_rng.seed = rng.randi()
	var lane_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	lane_rng.seed = rng.randi()
	var source: WordSource = WordSource.new(word_rng, WordSource.pool_from_json(
		config.word_list, config.word_min_length, config.word_max_length))
	var field: HordeField = HordeField.new(config, lane_rng)
	var defender: HordeDefender = HordeDefender.new(config)

	var duration: float = config.duration_s
	var char_s: float = 60.0 / (CHARS_PER_WORD * wpm)
	# Character slots used before the current word starts (each finished word plus its space). The first
	# key is t = 0, so a word of length L is complete at (slots_before + L - 1) character slots.
	var slots_before: int = 0
	var next_word: String = source.current()
	var next_done_s: float = (next_word.length() - 1) * char_s
	var words: int = 0
	var keys: int = 0
	var arrival_brains: int = 0
	var steps: int = roundi(duration / step_s)
	for i: int in steps:
		var start_s: float = i * step_s
		while next_done_s <= start_s:
			field.spawn(next_word)
			words += 1
			keys += next_word.length()
			slots_before += next_word.length() + 1
			source.advance()
			next_word = source.current()
			next_done_s = (slots_before + next_word.length() - 1) * char_s
		for marcher: HordeMarcher in field.advance(step_s):
			arrival_brains += marcher.size_class.arrival_brains
		defender.advance(step_s, field)
	# The letters of the unfinished word typed before the end count as keys (they are correct keys).
	# Slot 0 is the key at t = 0, so floori(duration / char_s) + 1 slots have been typed by the end.
	var partial: int = clampi(floori(duration / char_s) + 1 - slots_before, 0, next_word.length())
	keys += partial
	var arrived: int = field.get_arrived_count()
	var stopped: int = field.get_stopped_count()
	var decided: int = arrived + stopped
	var minutes: float = duration / 60.0
	return {
		"spawned": field.get_spawned_count(),
		"arrived": arrived,
		"stopped": stopped,
		"marching": field.get_marching().size(),
		"arrival_brains": arrival_brains,
		"arrival_rate": float(arrived) / decided if decided > 0 else 0.0,
		"brains_per_min": (arrival_brains + config.completion_bonus) / minutes,
		"words": words,
		"keys": keys,
		"measured_wpm": (keys + words) / CHARS_PER_WORD / minutes,
	}


## Zombie Run's brains per minute for a perfect typist at `wpm` (one key per letter target): every
## brain_block_every keys pays brains_per_block, plus the completion bonus, over the run's minutes.
static func zombie_run_brains_per_min(zr: ZombieRunConfig, wpm: float) -> float:
	var minutes: float = zr.duration_s / 60.0
	var keys: float = CHARS_PER_WORD * wpm * minutes
	return (keys / zr.brain_block_every * zr.brains_per_block + zr.completion_bonus) / minutes
