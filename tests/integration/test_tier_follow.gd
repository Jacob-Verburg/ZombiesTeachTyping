extends GutTest
## Epic 7 end-to-end (Story 7.5, FR60-FR64): two new saves, a beginner and a fast typist, are placed by a
## Zombie Run and two more completed runs, then play real RunFrames on zombie_run and horde_rush. The
## beginner gets only home-row letters and home-row 2-4 letter words; the fast typist gets the bottom row
## and 5-8 letter words. Their run records carry "all" for the placement run and "tier_N" after it.
## Each kid has a fresh SaveService under user://test_tier_follow_* and a PlayerData on the SHIPPED
## TierConfig (its _ready default): the real save is never touched. Every RunFrame seam is a recorder.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const DIR_PREFIX: String = "user://test_tier_follow_"
const RUN_SECONDS: float = 120.0
const TARGETS_PER_RUN: int = 30
## Written out on purpose (6.1 review): not WordTagger's constants.
const HOME_ROW: String = "asdfghjkl"
const BOTTOM_ROW: String = "zxcvbnm"

var _dirs: Array[String] = []


func after_each() -> void:
	get_tree().paused = false
	Router.take_payload()
	for dir: String in _dirs:
		_clear(dir)
	_dirs.clear()


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))


## A fresh save for `kid`, placed by a Zombie Run at `wpm` plus two more completed runs at the same speed.
func _kid(kid: String, wpm: int) -> PlayerDataScript:
	var dir: String = DIR_PREFIX + kid + "/"
	DirAccess.make_dir_recursive_absolute(dir)
	_clear(dir)
	_dirs.append(dir)
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = dir
	add_child_autofree(save)
	var data: PlayerDataScript = PlayerDataScript.new()
	data.save_service = save
	add_child_autofree(data)
	assert_eq(data.get_tier(), 0, "%s: a new save is not placed" % kid)
	for level_id: StringName in [&"zombie_run", &"zombie_run", &"horde_rush"]:
		var result: RunResult = RunResult.create(
				level_id, 1000, RUN_SECONDS, wpm * 10, 0, {}, 0, 0, GameConstants.LETTER_POOL_ALL,
				GameConstants.END_REASON_TIMER)
		assert_eq(result.wpm, wpm)
		data.record_run(result)
	return data


## A real RunFrame on `level_id` for `data`: types TARGETS_PER_RUN targets letter by letter, lets the clock
## run as if typed at `wpm` (below the duration), ends it with debug F6, and returns the targets.
func _play(data: PlayerDataScript, level_id: StringName, wpm: int) -> Array[String]:
	Router._store_payload({"level_id": level_id, "seed": 7})
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.navigate = func(_screen: int, _payload: Dictionary) -> void: pass
	frame.pause_tree = func(_paused: bool) -> void: pass
	frame.set_ambience = func(_on: bool) -> void: pass
	frame.play_music = func(_id: StringName) -> void: pass
	frame.duck_music = func(_on: bool) -> void: pass
	frame.play_sfx = func(_id: StringName) -> void: pass
	frame.is_debug_build = func() -> bool: return true
	frame.player_data = data
	add_child_autofree(frame)
	assert_not_null(frame.get_session(), "%s starts" % level_id)
	var input: TypingInput = frame.get_node("%TypingInput") as TypingInput
	var targets: Array[String] = []
	var keys: int = 0
	for i: int in TARGETS_PER_RUN:
		var target: String = frame.get_session().get_current_target()
		targets.append(target)
		for c: String in target:
			var key: InputEventKey = InputEventKey.new()
			key.pressed = true
			key.unicode = c.unicode_at(0)
			key.keycode = OS.find_keycode_from_string(c.to_upper())
			assert_true(input.handle_key(key), "'%s' of '%s' is accepted" % [c, target])
			keys += 1
	# keys / 5 words at `wpm` -> keys * 12 / wpm seconds, kept inside the level's duration.
	frame._process(minf(keys * 12.0 / wpm, frame.get_duration() - 1.0))
	assert_true(frame.debug_end_run(), "%s ends like the clock ran out" % level_id)
	return targets


func _labels(data: PlayerDataScript) -> Array[String]:
	var out: Array[String] = []
	for record: Dictionary in data.save_service.get_active_profile()["run_history"]:
		out.append(String(record["letter_pool_or_tier"]))
	return out


func _levels(data: PlayerDataScript) -> Array[String]:
	var out: Array[String] = []
	for record: Dictionary in data.save_service.get_active_profile()["run_history"]:
		out.append(String(record["level_id"]))
	return out


func _only_letters_of(text: String, allowed: String) -> bool:
	for c: String in text:
		if not allowed.contains(c):
			return false
	return true


func test_a_beginner_and_a_fast_typist_get_their_own_letters_and_words() -> void:
	var beginner: PlayerDataScript = _kid("beginner", 5)
	var fast: PlayerDataScript = _kid("fast", 40)
	assert_eq(beginner.get_tier(), 1, "5 WPM places at tier 1")
	assert_eq(fast.get_tier(), 5, "40 WPM places at tier 5")

	var beginner_letters: Array[String] = _play(beginner, &"zombie_run", 5)
	var beginner_words: Array[String] = _play(beginner, &"horde_rush", 5)
	var fast_letters: Array[String] = _play(fast, &"zombie_run", 40)
	var fast_words: Array[String] = _play(fast, &"horde_rush", 40)
	assert_eq(beginner.get_tier(), 1, "the beginner stays at tier 1")
	assert_eq(fast.get_tier(), 5, "the fast typist stays at tier 5")

	for letter: String in beginner_letters:
		assert_true(HOME_ROW.contains(letter), "beginner letter '%s' is home row" % letter)
	for word: String in beginner_words:
		assert_true(_only_letters_of(word, HOME_ROW), "beginner word '%s' is home row" % word)
		assert_between(word.length(), 2, 4, "beginner word '%s' is 2-4 letters" % word)
	var bottom: bool = false
	for letter: String in fast_letters:
		bottom = bottom or BOTTOM_ROW.contains(letter)
	assert_true(bottom, "the fast typist meets the bottom row")
	for word: String in fast_words:
		assert_between(word.length(), 5, 8, "fast word '%s' is 5-8 letters" % word)
	assert_ne(beginner_letters, fast_letters, "different letters")
	assert_ne(beginner_words, fast_words, "different words")

	assert_eq(_levels(beginner), ["zombie_run", "zombie_run", "horde_rush", "zombie_run", "horde_rush"] as Array[String])
	assert_eq(_labels(beginner), ["all", "all", "all", "tier_1", "tier_1"] as Array[String],
			"the placement runs say all, the runs after it say the tier")
	assert_eq(_labels(fast), ["all", "all", "all", "tier_5", "tier_5"] as Array[String])
