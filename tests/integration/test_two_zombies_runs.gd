extends GutTest
## Story 11.3 (FR78, AC 5): a run reads the active zombie live. One save holds two placed zombies with their own tier,
## used passages and last Pitchfork Panic theme; a real RunFrame on Pitchfork Panic for Sam gets Sam's values, then
## after switch_profile a second one for Bo gets Bo's. Each run's passage, theme and record land in its own zombie's
## profile only. (test_tier_follow.gd covers the tier's effect on letters and words, with one save per kid.)
## One temp SaveService under user://test_two_zombies_runs/ and a PlayerData on the shipped TierConfig and registry;
## every RunFrame seam is a recorder, so the real save is never touched.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const TEST_DIR: String = "user://test_two_zombies_runs/"
## Correct keys typed per run before the debug end.
const KEYS_PER_RUN: int = 3

var _player: PlayerDataScript


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	var sam: Dictionary = save.get_active_profile()
	sam["name"] = "Sam"
	sam["flags"]["placement_done"] = true
	sam["tier"] = 5
	sam["used_passages"] = ["t5_01", "t5_02"]
	sam["last_themes"] = {"pitchfork_panic": "moonlit_village"}
	var bo: Dictionary = SaveSchema.profile_defaults()
	bo["name"] = "Bo"
	bo["flags"]["placement_done"] = true
	bo["tier"] = 3
	bo["used_passages"] = ["t3_01"]
	bo["last_themes"] = {"pitchfork_panic": "cornfield_path"}
	save.get_data()["profiles"]["p2"] = bo
	_player = PlayerDataScript.new()
	_player.save_service = save
	add_child_autofree(_player)


func after_each() -> void:
	get_tree().paused = false
	Router.take_payload()
	_clear()
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _profile(id: String) -> Dictionary:
	return _player.save_service.get_data()["profiles"][id]


## A real Pitchfork Panic RunFrame for the active zombie, its first KEYS_PER_RUN letters typed (the first marks
## the passage used). Returned still running.
func _start() -> RunFrameScript:
	Router._store_payload({"level_id": &"pitchfork_panic", "seed": 7})
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.navigate = func(_screen: int, _payload: Dictionary) -> void: pass
	frame.pause_tree = func(_paused: bool) -> void: pass
	frame.set_ambience = func(_on: bool) -> void: pass
	frame.play_music = func(_id: StringName) -> void: pass
	frame.duck_music = func(_on: bool) -> void: pass
	frame.play_sfx = func(_id: StringName) -> void: pass
	frame.is_debug_build = func() -> bool: return true
	frame.player_data = _player
	add_child_autofree(frame)
	assert_not_null(frame.get_session(), "Pitchfork Panic starts")
	var input: TypingInput = frame.get_node("%TypingInput") as TypingInput
	var passage: String = frame.get_session().get_current_target()
	for i: int in KEYS_PER_RUN:
		var c: String = passage[i]
		var key: InputEventKey = InputEventKey.new()
		key.pressed = true
		key.unicode = c.unicode_at(0)
		key.keycode = KEY_SPACE if c == " " else OS.find_keycode_from_string(c.to_upper())
		assert_true(input.handle_key(key), "'%s' is accepted" % c)
	return frame


## Ends the run with debug F6 and lets the outro play out, so the run is recorded.
func _finish(frame: RunFrameScript) -> void:
	frame._process(5.0)
	assert_true(frame.debug_end_run(), "the run ends like the clock ran out")
	for i: int in 40:
		if frame.get_state() == RunFrameScript.RunState.DONE:
			break
		frame._process(0.25)
	assert_eq(frame.get_state(), RunFrameScript.RunState.DONE)


func _passage_id(frame: RunFrameScript) -> String:
	return ((frame.get_level() as LevelBase).get("_paragraphs") as ParagraphSource).get_current_id()


func test_each_zombies_run_reads_and_writes_only_that_zombie() -> void:
	# Sam's run: Sam's tier, used passages and last theme.
	var sam_frame: RunFrameScript = _start()
	var level: LevelBase = sam_frame.get_level()
	assert_eq(level.tier, 5, "Sam's tier reaches the level")
	assert_eq(level.get_pool_label(), "tier_5")
	assert_eq(level.used_passages, ["t5_01", "t5_02"] as Array[String], "Sam's used passages reach the level")
	var sam_passage: String = _passage_id(sam_frame)
	assert_true(sam_passage.begins_with("t5_") and not sam_passage in ["t5_01", "t5_02"], "a tier 5 passage Sam hasn't had")
	var sam_theme: StringName = sam_frame.get_theme_id()
	assert_ne(sam_theme, &"moonlit_village", "avoids Sam's last theme")
	assert_ne(sam_theme, &"", "Pitchfork Panic has themes")
	_finish(sam_frame)
	assert_eq(_profile("p1")["used_passages"], ["t5_01", "t5_02", sam_passage], "Sam's passage is saved to Sam")
	assert_eq(_profile("p1")["last_themes"], {"pitchfork_panic": String(sam_theme)})
	assert_eq((_profile("p1")["run_history"] as Array).size(), 1, "Sam's run is in Sam's history")
	assert_eq(int(_profile("p1")["lifetime"]["runs"]), 1)
	var bo_before: Dictionary = (_profile("p2") as Dictionary).duplicate(true)
	assert_eq(bo_before["used_passages"], ["t3_01"], "Bo untouched by Sam's run")
	assert_eq(bo_before["last_themes"], {"pitchfork_panic": "cornfield_path"})
	assert_eq((bo_before["run_history"] as Array).size(), 0)

	# Bo's run on the same save: Bo's values.
	assert_true(_player.switch_profile(&"p2"))
	var sam_after: Dictionary = (_profile("p1") as Dictionary).duplicate(true)
	var bo_frame: RunFrameScript = _start()
	level = bo_frame.get_level()
	assert_eq(level.tier, 3, "Bo's tier reaches the level")
	assert_eq(level.get_pool_label(), "tier_3")
	assert_eq(level.used_passages, ["t3_01"] as Array[String], "Bo's used passages reach the level")
	var bo_passage: String = _passage_id(bo_frame)
	assert_true(bo_passage.begins_with("t3_") and bo_passage != "t3_01", "a tier 3 passage Bo hasn't had")
	var bo_theme: StringName = bo_frame.get_theme_id()
	assert_ne(bo_theme, &"cornfield_path", "avoids Bo's last theme")
	_finish(bo_frame)
	assert_eq(_profile("p2")["used_passages"], ["t3_01", bo_passage], "Bo's passage is saved to Bo")
	assert_eq(_profile("p2")["last_themes"], {"pitchfork_panic": String(bo_theme)})
	assert_eq((_profile("p2")["run_history"] as Array).size(), 1, "Bo's run is in Bo's history")
	assert_eq(String(_profile("p2")["run_history"][0]["letter_pool_or_tier"]), "tier_3")
	assert_eq(int(_profile("p2")["lifetime"]["runs"]), 1)
	assert_eq(_profile("p1"), sam_after, "Bo's run changes nothing of Sam's")
	assert_false((_profile("p1")["used_passages"] as Array).has(bo_passage), "Bo's passage never reaches Sam")
