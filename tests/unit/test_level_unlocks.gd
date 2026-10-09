extends GutTest
## Story 6.8 (FR79, FR13): the level-unlock flow end to end. State precedence (Coming soon > Locked > New >
## Available); a finished (timer) run unlocks the next level while a quit never does (real RunFrame paths);
## the one-time unlock moment on the real main menu, saved as seen; the "New!" badge cleared by the first
## choice; a Coming soon level's pending moment waits; an old v1 save is backfilled and shows the moment.
## Always temp saves (SaveService on TEST_DIR / RUN_DIR) and seams: the real save, Router and audio are
## never touched. The menu is disabled, so its moment tweens never run: the tests finish them by hand.

const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")
const RunFrameScene: PackedScene = preload("res://scenes/run/run_frame.tscn")
const RunFrameScript := preload("res://scripts/run/run_frame.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TestLevelScene: PackedScene = preload("res://scenes/levels/test_level/test_level.tscn")
const TEST_DIR: String = "user://test_level_unlocks/"
const BACKFILL_PATH: String = "res://tests/fixtures/saves/save_v1_backfill.json"

var _save: SaveServiceScript = null
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


## A fresh SaveService on TEST_DIR (it loads whatever save.json is there) and a PlayerData on it.
func _make_player(registry: LevelRegistry = null) -> PlayerDataScript:
	_save = SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	_player.level_registry = registry
	add_child_autofree(_player)
	return _player


## The real main menu (shipped registry) on _player, disabled, with a navigate recorder.
func _make_menu() -> MainMenuScript:
	var menu: MainMenuScript = MenuScene.instantiate() as MainMenuScript
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.navigate = func(screen: int, payload: Dictionary) -> void: _nav.append([screen, payload])
	menu.is_transitioning = func() -> bool: return false
	menu.player_data = _player
	(menu.get_node("%PetSlot") as PetSlot).player_data = _player
	(menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).player_data = _player
	menu.toggle_fullscreen = func() -> void: pass
	menu.is_fullscreen = func() -> bool: return false
	add_child_autofree(menu)
	return menu


func _card(menu: MainMenuScript, id: StringName) -> LevelCard:
	for card: LevelCard in menu.get_cards():
		if card.get_level_id() == id:
			return card
	return null


func _finish_zombie_run() -> void:
	_player.record_run(RunResult.create(
		&"zombie_run", 1000, 60.0, 50, 0, {}, 0, 0, "all", GameConstants.END_REASON_TIMER))


# --- precedence ------------------------------------------------------------------------------------------

func test_state_precedence_table() -> void:
	var entry: LevelEntry = LevelEntry.new()
	# [available, unlock state, expected]
	var rows: Array = [
		[false, {"unlocked": false, "moment_seen": false, "chosen": false}, LevelCard.State.COMING_SOON],
		[false, {"unlocked": true, "moment_seen": true, "chosen": false}, LevelCard.State.COMING_SOON],
		[false, {"unlocked": true, "moment_seen": true, "chosen": true}, LevelCard.State.COMING_SOON],
		[true, {"unlocked": false, "moment_seen": false, "chosen": false}, LevelCard.State.LOCKED],
		[true, {"unlocked": true, "moment_seen": false, "chosen": false}, LevelCard.State.NEW],
		[true, {"unlocked": true, "moment_seen": true, "chosen": false}, LevelCard.State.NEW],
		[true, {"unlocked": true, "moment_seen": true, "chosen": true}, LevelCard.State.AVAILABLE],
	]
	for row: Array in rows:
		entry.available = row[0]
		assert_eq(LevelCard.state_for(entry, row[1]), row[2], "available=%s %s" % [row[0], row[1]])


# --- finished vs quit runs (real RunFrame) ------------------------------------------------------------------

## test_level (open) -> next: a run of the test level is the "previous level" here.
func _run_registry() -> LevelRegistry:
	var first: LevelEntry = LevelEntry.new()
	first.id = &"test_level"
	first.display_name = "Test level"
	first.scene = TestLevelScene
	first.available = true
	var next: LevelEntry = LevelEntry.new()
	next.id = &"next"
	next.display_name = "Next"
	next.available = true
	next.unlocked_by = &"test_level"
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [first, next]
	return registry


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


func test_quitting_a_run_never_unlocks() -> void:
	var registry: LevelRegistry = _run_registry()
	_make_player(registry)
	watch_signals(_player)
	var frame: RunFrameScript = _start_run(registry)
	frame._unhandled_input(_esc())
	(frame.get_node("%PausePanel") as Control).emit_signal("quit_chosen")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]], "quit to the menu")
	assert_signal_not_emitted(_player, "run_recorded", "a quit is never recorded")
	assert_signal_not_emitted(_player, "level_unlocked")
	assert_false(_player.get_unlock_state(&"next")["unlocked"])
	assert_eq_deep(_save.get_active_profile()["level_unlocks"], {})


func test_finishing_a_run_unlocks_the_next_level() -> void:
	var registry: LevelRegistry = _run_registry()
	_make_player(registry)
	watch_signals(_player)
	var frame: RunFrameScript = _start_run(registry)
	assert_true(frame.debug_end_run(), "ends exactly like the clock running out (timer)")
	assert_signal_emit_count(_player, "run_recorded", 1)
	assert_signal_emitted_with_parameters(_player, "level_unlocked", [&"next"])
	assert_eq_deep(_player.get_unlock_state(&"next"), {"unlocked": true, "moment_seen": false, "chosen": false})


# --- the menu: one-time moment, New badge, Coming soon --------------------------------------------------------

func test_the_moment_plays_once_then_new_then_available() -> void:
	_make_player()
	_finish_zombie_run()
	var first: MainMenuScript = _make_menu()
	var horde: LevelCard = _card(first, &"horde_rush")
	assert_true(horde.is_playing_moment(), "plays on the first menu visit")
	assert_true(_player.get_unlock_state(&"horde_rush")["moment_seen"], "saved as seen")
	horde.finish_unlock_moment()
	assert_true(horde.has_focus(), "focus ends on Horde Rush")
	assert_eq(horde.get_state(), LevelCard.State.NEW)
	first.queue_free()
	await wait_process_frames(1)

	var second: MainMenuScript = _make_menu()
	horde = _card(second, &"horde_rush")
	assert_false(horde.is_playing_moment(), "never again")
	assert_eq(horde.get_state(), LevelCard.State.NEW, "New until chosen")
	horde._activate()
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"horde_rush"}]])
	assert_true(_player.get_unlock_state(&"horde_rush")["chosen"])
	second.queue_free()
	await wait_process_frames(1)

	var third: MainMenuScript = _make_menu()
	assert_eq(_card(third, &"horde_rush").get_state(), LevelCard.State.AVAILABLE, "the badge is gone")


func test_the_unlock_survives_a_reload() -> void:
	_make_player()
	_finish_zombie_run()
	_player.mark_unlock_seen(&"horde_rush")
	_save.save_now()
	_make_player()
	assert_eq_deep(_player.get_unlock_state(&"horde_rush"), {"unlocked": true, "moment_seen": true, "chosen": false})
	assert_eq(_card(_make_menu(), &"horde_rush").get_state(), LevelCard.State.NEW)


func test_a_coming_soon_level_keeps_its_moment_for_later() -> void:
	_make_player()
	_player.debug_set_all_unlocked(true)
	var menu: MainMenuScript = _make_menu()
	var pitchfork: LevelCard = _card(menu, &"pitchfork_panic")
	assert_eq(pitchfork.get_state(), LevelCard.State.COMING_SOON)
	assert_false(pitchfork.is_playing_moment())
	assert_false(_player.get_unlock_state(&"pitchfork_panic")["moment_seen"], "unseen until it is available")


# --- backfill ---------------------------------------------------------------------------------------------------

func test_an_old_save_is_backfilled_and_shows_the_moment() -> void:
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join("save.json"), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(BACKFILL_PATH))
	file.close()
	_make_player()
	assert_eq(int(_save.get_data()["schema_version"]), GameConstants.CURRENT_SCHEMA, "migrated to the current schema")
	var menu: MainMenuScript = _make_menu()
	var horde: LevelCard = _card(menu, &"horde_rush")
	assert_true(horde.is_playing_moment(), "the backfilled unlock plays its moment")
	assert_eq(_card(menu, &"pitchfork_panic").get_state(), LevelCard.State.COMING_SOON)
	assert_false(_player.get_unlock_state(&"pitchfork_panic")["unlocked"], "a caught Horde Rush run opens nothing")
	menu._input(_esc_action())
	assert_false(horde.is_playing_moment())
	assert_eq(horde.get_state(), LevelCard.State.NEW)


func _esc_action() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event
