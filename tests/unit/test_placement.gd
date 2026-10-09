extends GutTest
## Story 7.2 (FR60-FR63, FR61): the placement run and the hidden tier in PlayerData. The first completed
## placement-level run places from its own WPM with one save request; other levels and debug levels never
## place; later runs move the tier with TierCalculator.compute_tier; the load-time reconcile (MVP saves, hand
## edits, consistent saves untouched); an invalid config changes nothing; get_tier(); reload; reset_all; a
## quit run (real RunFrame) never places while a finished one does.
## Always a fresh SaveService on TEST_DIR and a fresh PlayerData with a code-built TierConfig: the real save
## is never touched.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const TestLevelScene: PackedScene = preload("res://scenes/levels/test_level/test_level.tscn")
const TEST_DIR: String = "user://test_placement/"
## 120 s runs: keys / 10 = WPM (keys / 5 per word, 2 minutes).
const RUN_SECONDS: float = 120.0


class CountingSave extends SaveServiceScript:
	var requests: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()


var _save: CountingSave = null
var _player: PlayerDataScript = null
var _nav: Array = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []


func after_each() -> void:
	get_tree().paused = false
	Router.take_payload()
	_clear()
	_save = null
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


## The GDD numbers, placing on zombie_run, ignoring the two debug levels.
func _config() -> TierConfig:
	var config: TierConfig = TierConfig.new()
	config.tier_floors = [0.0, 8.0, 15.0, 22.0, 30.0]
	config.drop_margin_wpm = 2.0
	config.window_runs = 5
	config.ignored_levels = [&"test_level", &"test_word_level"]
	config.placement_level = &"zombie_run"
	return config


## A fresh CountingSave on TEST_DIR. `seed` (profile Dictionary -> void) edits the loaded profile before
## PlayerData's _ready runs the reconcile; the save requests are reset after it, so only PlayerData counts.
func _make(config: TierConfig = null, seed: Callable = Callable(), registry: LevelRegistry = null) -> PlayerDataScript:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	if seed.is_valid():
		seed.call(_save.get_active_profile())
	_save.requests = 0
	_player = PlayerDataScript.new()
	_player.save_service = _save
	_player.tier_config = config if config != null else _config()
	_player.level_registry = registry
	add_child_autofree(_player)
	return _player


## A completed run of `level_id` at `wpm` (120 s, wpm * 10 keys).
func _run(level_id: StringName, wpm: int, end_reason: StringName = GameConstants.END_REASON_TIMER) -> RunResult:
	var result: RunResult = RunResult.create(
		level_id, 1000, RUN_SECONDS, wpm * 10, 0, {}, 0, 0, "all", end_reason)
	assert_eq(result.wpm, wpm, "helper builds a %d WPM run" % wpm)
	return result


func _record(level_id: StringName, wpm: int) -> Dictionary:
	return _run(level_id, wpm).to_record()


func _profile() -> Dictionary:
	return _save.get_active_profile()


func _placed() -> bool:
	return bool(_profile()["flags"]["placement_done"])


# --- placement ---------------------------------------------------------------------------------------------

func test_first_zombie_run_places_from_its_own_wpm() -> void:
	for row: Array in [[6, 1], [12, 2], [18, 3], [40, 5]]:
		_clear()
		var sut: PlayerDataScript = _make()
		watch_signals(sut)
		assert_eq(sut.get_tier(), 0, "not placed yet")
		sut.record_run(_run(&"zombie_run", row[0]))
		assert_eq(sut.get_tier(), row[1], "%d WPM places at %d" % row)
		assert_true(sut.get_flag(&"placement_done"))
		assert_eq(_save.requests, 1, "one save request for the record, the tier and the flag")
		assert_signal_emitted_with_parameters(sut, "flags_changed", [&"placement_done", true])
		assert_signal_emit_count(sut, "flags_changed", 1)


func test_a_caught_or_escaped_placement_run_also_places() -> void:
	for reason: StringName in [GameConstants.END_REASON_CAUGHT, GameConstants.END_REASON_ESCAPED]:
		_clear()
		var sut: PlayerDataScript = _make()
		sut.record_run(_run(&"zombie_run", 12, reason))
		assert_eq(sut.get_tier(), 2, String(reason))
		assert_true(_placed())


func test_other_levels_before_placement_change_nothing() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	sut.record_run(_run(&"horde_rush", 40))
	sut.record_run(_run(&"test_level", 40))
	assert_eq(int(_profile()["tier"]), 0)
	assert_false(_placed())
	assert_signal_not_emitted(sut, "flags_changed")
	# Placement then uses the Zombie Run's WPM alone, not the average with the Horde Rush run (23 -> 4).
	sut.record_run(_run(&"zombie_run", 6))
	assert_eq(sut.get_tier(), 1, "the placement run's own WPM")
	assert_true(_placed())


func test_an_ignored_debug_level_never_places() -> void:
	var config: TierConfig = _config()
	config.placement_level = &"horde_rush"
	var sut: PlayerDataScript = _make(config)
	sut.record_run(_run(&"test_word_level", 30))
	sut.record_run(_run(&"zombie_run", 30))
	assert_eq(sut.get_tier(), 0, "only the configured placement level places")
	assert_false(_placed())
	sut.record_run(_run(&"horde_rush", 30))
	assert_eq(sut.get_tier(), 5)


func test_an_ignored_level_never_places_even_if_configured() -> void:
	var config: TierConfig = _config()
	config.placement_level = &"test_word_level"
	var sut: PlayerDataScript = _make(config)
	sut.record_run(_run(&"test_word_level", 30))
	assert_push_error_count(2)  # the config is invalid (ignored placement level): one error per call site
	assert_eq(sut.get_tier(), 0, "an ignored level must not place")
	assert_false(_placed())


func test_a_non_completed_placement_run_never_places() -> void:
	var sut: PlayerDataScript = _make(_config())
	var quit: RunResult = _run(&"zombie_run", 30)
	quit.end_reason = &"quit"  # RunResult.create asserts on unknown labels, so set it after
	sut.record_run(quit)
	assert_eq(sut.get_tier(), 0)
	assert_false(_placed())
	sut.record_run(_run(&"zombie_run", 30))
	assert_eq(sut.get_tier(), 5, "the next completed run still places")


func test_a_placed_save_never_drops_to_tier_zero() -> void:
	var sut: PlayerDataScript = _make(_config())
	sut.record_run(_run(&"zombie_run", 20))
	assert_eq(sut.get_tier(), 3)
	_profile()["run_history"] = []
	sut.record_run(_run(&"test_level", 30))
	assert_eq(sut.get_tier(), 3, "no counted run keeps the tier")


func test_placement_uses_the_level_scale() -> void:
	var config: TierConfig = _config()
	config.level_wpm_scale = {&"zombie_run": 0.5}
	var sut: PlayerDataScript = _make(config)
	sut.record_run(_run(&"zombie_run", 40))
	assert_eq(sut.get_tier(), 3, "40 * 0.5 = 20 WPM -> tier 3")


# --- later runs ----------------------------------------------------------------------------------------------

## GDD worked example: 12 places at 2; 20 -> avg 16 -> 3; 9 -> 13.67 holds 3; 8 -> 12.25 < 13 -> 2.
func test_later_runs_use_compute_tier() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_run(&"zombie_run", 12))
	assert_eq(sut.get_tier(), 2)
	watch_signals(sut)
	sut.record_run(_run(&"horde_rush", 20))
	assert_eq(sut.get_tier(), 3, "rises as soon as the average reaches a floor; the placement run counts")
	sut.record_run(_run(&"zombie_run", 9))
	assert_eq(sut.get_tier(), 3, "holds inside the drop margin")
	sut.record_run(_run(&"zombie_run", 8))
	assert_eq(sut.get_tier(), 2, "drops below floor - margin")
	assert_eq(_save.requests, 4, "still one save request per run")
	assert_signal_not_emitted(sut, "flags_changed", "a tier change emits nothing")
	assert_true(_placed())


func test_an_ignored_run_after_placement_keeps_the_tier() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_run(&"zombie_run", 12))
	sut.record_run(_run(&"test_level", 60))
	assert_eq(sut.get_tier(), 2)


func test_later_runs_can_skip_tiers() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_run(&"zombie_run", 6))
	sut.record_run(_run(&"zombie_run", 60))
	assert_eq(sut.get_tier(), 5, "avg 33 -> straight to 5")


# --- load-time reconcile ---------------------------------------------------------------------------------------

func test_reconcile_places_an_mvp_save_from_its_average() -> void:
	var sut: PlayerDataScript = _make(null, func(profile: Dictionary) -> void:
		profile["run_history"] = [_record(&"zombie_run", 12), _record(&"horde_rush", 20)])
	assert_eq(sut.get_tier(), 3, "avg 16")
	assert_true(_placed())
	assert_eq(_save.requests, 1)


func test_reconcile_does_not_place_on_debug_runs_only() -> void:
	var sut: PlayerDataScript = _make(null, func(profile: Dictionary) -> void:
		profile["run_history"] = [_record(&"test_level", 20), _record(&"test_word_level", 20)])
	assert_eq(sut.get_tier(), 0)
	assert_false(_placed())
	assert_eq(_save.requests, 0)
	sut.record_run(_run(&"zombie_run", 18))
	assert_eq(sut.get_tier(), 3, "the next Zombie Run places")


func test_reconcile_clears_a_stray_tier_on_an_unplaced_save() -> void:
	_make(null, func(profile: Dictionary) -> void:
		profile["tier"] = 4)
	assert_eq(int(_profile()["tier"]), 0)
	assert_false(_placed())
	assert_eq(_save.requests, 1)


func test_reconcile_recomputes_a_placed_save_with_no_tier() -> void:
	for stored: int in [0, 9, -1]:
		_clear()
		var sut: PlayerDataScript = _make(null, func(profile: Dictionary) -> void:
			profile["tier"] = stored
			profile["flags"]["placement_done"] = true
			profile["run_history"] = [_record(&"zombie_run", 12), _record(&"horde_rush", 20)])
		assert_eq(sut.get_tier(), 3, "tier %d recomputed from avg 16" % stored)
		assert_true(_placed())
		assert_eq(_save.requests, 1)


func test_reconcile_unplaces_a_placed_save_with_no_tier_and_no_runs() -> void:
	var sut: PlayerDataScript = _make(null, func(profile: Dictionary) -> void:
		profile["flags"]["placement_done"] = true)
	assert_eq(sut.get_tier(), 0)
	assert_false(_placed(), "the next Zombie Run places again")
	assert_eq(_save.requests, 1)
	sut.record_run(_run(&"zombie_run", 12))
	assert_eq(sut.get_tier(), 2)


func test_reconcile_leaves_consistent_saves_alone() -> void:
	_make()
	assert_eq(_save.requests, 0, "a fresh save")
	assert_eq(int(_profile()["tier"]), 0)
	_clear()
	var sut: PlayerDataScript = _make(null, func(profile: Dictionary) -> void:
		profile["tier"] = 2
		profile["flags"]["placement_done"] = true
		profile["run_history"] = [_record(&"zombie_run", 60)])
	assert_eq(_save.requests, 0, "a placed save is not recomputed at load")
	assert_eq(sut.get_tier(), 2)


# --- invalid config ------------------------------------------------------------------------------------------

func test_an_invalid_config_changes_nothing() -> void:
	var config: TierConfig = _config()
	config.window_runs = 0
	var sut: PlayerDataScript = _make(config, func(profile: Dictionary) -> void:
		profile["run_history"] = [_record(&"zombie_run", 12)])
	assert_false(_placed(), "the MVP save is not reconciled")
	assert_eq(_save.requests, 0)
	sut.record_run(_run(&"zombie_run", 18))
	assert_push_error_count(2, "the load reconcile and record_run each log once")
	assert_eq(int(_profile()["tier"]), 0)
	assert_false(_placed())
	assert_eq(_save.requests, 1, "the run itself still saves")
	assert_eq(_profile()["run_history"].size(), 2, "the run is still recorded")


func test_a_placed_save_keeps_its_tier_on_an_invalid_config() -> void:
	var config: TierConfig = _config()
	config.placement_level = &""
	var sut: PlayerDataScript = _make(config, func(profile: Dictionary) -> void:
		profile["tier"] = 4
		profile["flags"]["placement_done"] = true)
	sut.record_run(_run(&"zombie_run", 6))
	assert_push_error_count(2, "the load reconcile and record_run each log once")
	assert_eq(sut.get_tier(), 4)
	assert_true(_placed())


# --- get_tier, reload, reset ---------------------------------------------------------------------------------------

func test_get_tier_reads_only_a_real_tier() -> void:
	var sut: PlayerDataScript = _make()
	for row: Array in [[0, 0], [1, 1], [3, 3], [5, 5], [6, 0], [-2, 0], ["3", 0], [3.0, 0], [null, 0]]:
		_profile()["tier"] = row[0]
		assert_eq(sut.get_tier(), row[1], "stored %s" % [row[0]])
	_profile().erase("tier")
	assert_eq(sut.get_tier(), 0, "missing")


func test_the_tier_survives_a_reload() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_run(&"zombie_run", 18))
	sut.record_run(_run(&"zombie_run", 30))
	var tier: int = sut.get_tier()
	assert_eq(tier, 4, "avg 24")
	assert_eq(_save.save_now(), OK)
	var again: PlayerDataScript = _make()
	assert_eq(again.get_tier(), tier)
	assert_true(again.get_flag(&"placement_done"))
	assert_eq(_save.requests, 0, "a reloaded placed save needs no reconcile")


func test_reset_all_unplaces() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_run(&"zombie_run", 18))
	_save.requests = 0
	sut.reset_all()
	assert_eq(sut.get_tier(), 0)
	assert_false(sut.get_flag(&"placement_done"))
	assert_eq(_save.requests, 1, "only reset_to_defaults' own request: a fresh profile is already consistent")


# --- real RunFrame: quit vs finish (FR61, FR13) ---------------------------------------------------------------

## A one-level registry: the test level is the run. The config places on it (and so does not ignore it),
## otherwise the quit test would pass for the wrong reason.
func _run_registry() -> LevelRegistry:
	var entry: LevelEntry = LevelEntry.new()
	entry.id = &"test_level"
	entry.display_name = "Test level"
	entry.scene = TestLevelScene
	entry.available = true
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [entry]
	return registry


func _run_config() -> TierConfig:
	var config: TierConfig = _config()
	config.ignored_levels = []
	config.placement_level = &"test_level"
	return config


func _start_run(registry: LevelRegistry) -> RunFrameScript:
	Router._store_payload({"level_id": &"test_level", "seed": 42})
	var frame: RunFrameScript = RunFrameScene.instantiate() as RunFrameScript
	frame.process_mode = Node.PROCESS_MODE_DISABLED
	frame.navigate = func(screen: int, payload: Dictionary) -> void: _nav.append([screen, payload])
	frame.pause_tree = func(_paused: bool) -> void: pass
	frame.set_ambience = func(_on: bool) -> void: pass
	frame.play_music = func(_id: StringName) -> void: pass
	frame.duck_music = func(_on: bool) -> void: pass
	frame.play_sfx = func(_id: StringName) -> void: pass
	frame.is_debug_build = func() -> bool: return true
	frame.player_data = _player
	frame.level_registry = registry
	add_child_autofree(frame)
	for i: int in 4:
		var target: String = frame.get_session().get_current_target()
		var key: InputEventKey = InputEventKey.new()
		key.pressed = true
		key.unicode = target.unicode_at(0)
		key.keycode = OS.find_keycode_from_string(target.to_upper())
		(frame.get_node("%TypingInput") as TypingInput).handle_key(key)
	assert_eq(frame.get_state(), RunFrameScript.RunState.RUNNING)
	return frame


func _esc() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return event


func test_quitting_the_placement_run_never_places() -> void:
	var registry: LevelRegistry = _run_registry()
	_make(_run_config(), Callable(), registry)
	watch_signals(_player)
	var frame: RunFrameScript = _start_run(registry)
	frame._unhandled_input(_esc())
	(frame.get_node("%PausePanel") as Control).emit_signal("quit_chosen")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]], "quit to the menu")
	assert_signal_not_emitted(_player, "run_recorded", "a quit is never recorded")
	assert_eq(int(_profile()["tier"]), 0)
	assert_false(_placed())


func test_finishing_the_placement_run_places() -> void:
	var registry: LevelRegistry = _run_registry()
	_make(_run_config(), Callable(), registry)
	var frame: RunFrameScript = _start_run(registry)
	assert_true(frame.debug_end_run(), "ends exactly like the clock running out (timer)")
	assert_true(_placed())
	assert_eq(_player.get_tier(), 1, "4 keys is a tier 1 run")
