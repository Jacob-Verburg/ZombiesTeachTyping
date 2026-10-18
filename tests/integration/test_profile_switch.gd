extends GutTest
## Story 11.2 (AC 8, epic AC 3): after a profile switch every profile_replaced listener shows the new zombie. A live
## main menu (brain counter, Music/Sound toggles, worn hat and pet, level card states) and an AudioManager (saved
## music/sound settings) built on a temp-dir PlayerData holding two different profiles; switch_profile and
## create_profile must leave all of them showing the newly active zombie. No listener code is expected to change.
## Story 11.3 (AC 8) adds the Progress screen (totals, best, charts), the Crypt Closet (tile states and the tutorial)
## and the report card's Welcome Gift redirect: each follows the active zombie after a switch.
## Never the real save: a temp SaveService, and every seam (the menu's slots, the AudioManager) points at it.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")
const AudioManagerScript := preload("res://scripts/autoloads/audio_manager.gd")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const TrendsScene: PackedScene = preload("res://scenes/screens/trends.tscn")
const TrendsScript := preload("res://scripts/screens/trends.gd")
const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const TEST_DIR: String = "user://test_profile_switch/"

var _save: SaveServiceScript
var _player: PlayerDataScript
var _nav: Array = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_save = SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)
	# p1: 30 brains, pumpkin hat, no pet, music on, nothing unlocked.
	var first: Dictionary = _save.get_active_profile()
	first["name"] = "Sam"
	first["brains"] = 30
	first["owned_items"] = ["hat_pumpkin"]
	first["equipped"] = {"hat": "hat_pumpkin", "pet": ""}
	# Story 11.3: one 10 WPM run.
	first["run_history"] = [_run_record(1790000000, 50)]
	first["best_wpm"] = {"zombie_run": 10}
	first["lifetime"] = {"runs": 1, "keys_typed": 50, "seconds": 60, "brains": 30}
	# p2: 250 brains, witch hat and a ghost, music off, Horde Rush open.
	var second: Dictionary = SaveSchema.profile_defaults()
	second["name"] = "Bo"
	second["brains"] = 250
	second["owned_items"] = ["hat_witch", "pet_cute_ghost"]
	second["equipped"] = {"hat": "hat_witch", "pet": "pet_cute_ghost"}
	second["settings"] = {"music_on": false, "sound_on": true}
	second["level_unlocks"] = {"horde_rush": {"moment_seen": true, "chosen": true}}
	# Story 11.3: two runs (30 then 40 WPM) and far bigger totals.
	second["run_history"] = [_run_record(1790000000, 150), _run_record(1790086400, 200)]
	second["best_wpm"] = {"zombie_run": 40}
	second["lifetime"] = {"runs": 2, "keys_typed": 4321, "seconds": 3600, "brains": 900}
	_save.get_data()["profiles"]["p2"] = second


func after_each() -> void:
	Router.take_payload()
	_clear()
	_nav = []
	_player = null
	_save = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


## A disabled main menu whose PlayerData seam and cosmetic slots all read the temp save.
func _menu() -> MainMenuScript:
	var menu: MainMenuScript = MenuScene.instantiate() as MainMenuScript
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.navigate = func(_screen: int, _payload: Dictionary) -> void: pass
	menu.is_transitioning = func() -> bool: return false
	menu.toggle_fullscreen = func() -> void: pass
	menu.is_fullscreen = func() -> bool: return false
	menu.player_data = _player
	(menu.get_node("%PetSlot") as PetSlot).player_data = _player
	(menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).player_data = _player
	add_child_autofree(menu)
	return menu


func _audio() -> AudioManagerScript:
	var am: AudioManagerScript = AudioManagerScript.new()
	am.library = AudioManagerScript.LIBRARY
	am.player_data = _player
	add_child_autofree(am)
	return am


func _brains(menu: MainMenuScript) -> String:
	return (menu.get_node("%BrainCounter").get_node("%CountLabel") as Label).text


func _hat(menu: MainMenuScript) -> StringName:
	return (menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).get_item_id()


func _pet(menu: MainMenuScript) -> StringName:
	return (menu.get_node("%PetSlot") as PetSlot).get_item_id()


func _card_state(menu: MainMenuScript, level_id: StringName) -> LevelCard.State:
	for card: LevelCard in menu.get_cards():
		if card.get_level_id() == level_id:
			return card.get_state()
	fail_test("no card for %s" % level_id)
	return LevelCard.State.LOCKED


func test_switch_profile_refreshes_the_menu_and_the_audio_settings() -> void:
	var menu: MainMenuScript = _menu()
	var am: AudioManagerScript = _audio()
	assert_eq(_brains(menu), "30")
	assert_eq((menu.get_node("%ZombieName") as Label).text, "Sam", "Story 11.4: the name")
	assert_true((menu.get_node("%MusicToggle") as MenuToggle).is_on())
	assert_eq(_hat(menu), &"hat_pumpkin")
	assert_eq(_pet(menu), &"")
	assert_eq(_card_state(menu, &"horde_rush"), LevelCard.State.LOCKED)
	assert_false(am.is_music_muted())
	assert_true(_player.switch_profile(&"p2"))
	assert_eq(_brains(menu), "250")
	assert_eq((menu.get_node("%ZombieName") as Label).text, "Bo", "Story 11.4: the name follows the switch")
	assert_false((menu.get_node("%MusicToggle") as MenuToggle).is_on())
	assert_true((menu.get_node("%SoundToggle") as MenuToggle).is_on())
	assert_eq(_hat(menu), &"hat_witch")
	assert_eq(_pet(menu), &"pet_cute_ghost")
	assert_ne(_card_state(menu, &"horde_rush"), LevelCard.State.LOCKED, "p2's unlock shows")
	assert_true(am.is_music_muted(), "p2's music_on = false is applied")
	assert_true(_player.switch_profile(&"p1"))
	assert_eq(_brains(menu), "30")
	assert_eq(_hat(menu), &"hat_pumpkin")
	assert_eq(_pet(menu), &"")
	assert_eq(_card_state(menu, &"horde_rush"), LevelCard.State.LOCKED)
	assert_false(am.is_music_muted())


func test_create_profile_shows_a_fresh_zombie_everywhere() -> void:
	assert_true(_player.switch_profile(&"p2"))
	var menu: MainMenuScript = _menu()
	var am: AudioManagerScript = _audio()
	assert_true(am.is_music_muted())
	assert_eq(_player.create_profile("Al"), &"p3")
	assert_eq(_brains(menu), "0")
	assert_eq((menu.get_node("%ZombieName") as Label).text, "Al", "Story 11.4: the new zombie's name")
	assert_true((menu.get_node("%MusicToggle") as MenuToggle).is_on())
	assert_eq(_hat(menu), &"")
	assert_eq(_pet(menu), &"")
	assert_eq(_card_state(menu, &"horde_rush"), LevelCard.State.LOCKED, "a new zombie starts with Zombie Run only")
	assert_false(am.is_music_muted(), "a new zombie has music on")


# --- Story 11.3 (AC 8): Progress, Crypt Closet and report card follow the active zombie ---------------------

## A run record of `keys` correct keys in 60 s on zombie_run (WPM = keys / 5), stamped `stamp`.
func _run_record(stamp: int, keys: int) -> Dictionary:
	return RunResult.create(
			&"zombie_run", stamp, 60.0, keys, 0, {}, 0, 0, "all", GameConstants.END_REASON_TIMER).to_record()


func _mute(_id: StringName) -> void:
	pass


func _nav_to(target: int, payload: Dictionary) -> void:
	_nav.append([target, payload])


func _trends() -> TrendsScript:
	var screen: TrendsScript = TrendsScene.instantiate() as TrendsScript
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.navigate = _nav_to
	screen.play_sfx = _mute
	screen.play_music = _mute
	screen.is_transitioning = func() -> bool: return false
	screen.time_zone_bias = func() -> int: return 0
	screen.player_data = _player
	add_child_autofree(screen)
	return screen


func _text(screen: Node, path: String) -> String:
	return (screen.get_node(path) as Label).text


## The bars a TrendChart shows (its values).
func _bars(screen: Node, path: String) -> int:
	return (screen.get_node(path) as TrendChart).get_bar_heights().size()


func test_progress_screen_shows_only_the_active_zombie() -> void:
	var screen: TrendsScript = _trends()
	assert_eq(_text(screen, "%KeysValue"), "50")
	assert_eq(_text(screen, "%BestWpmValue"), "10")
	assert_eq(_text(screen, "%BrainsValue"), "30")
	assert_eq(_text(screen, "%TimeValue"), TrendsCalculator.format_practice_time(60))
	assert_eq(_bars(screen, "%WpmChart"), 1, "Sam's one run")
	assert_true(_player.switch_profile(&"p2"))
	assert_eq(_text(screen, "%KeysValue"), "4321", "Bo's lifetime keys")
	assert_eq(_text(screen, "%BestWpmValue"), "40", "Bo's best")
	assert_eq(_text(screen, "%BrainsValue"), "900", "Bo's lifetime brains")
	assert_eq(_text(screen, "%TimeValue"), TrendsCalculator.format_practice_time(3600))
	assert_eq(_bars(screen, "%WpmChart"), 2, "Bo's two runs")
	assert_true(_player.switch_profile(&"p1"))
	assert_eq(_text(screen, "%KeysValue"), "50", "back to Sam's")
	assert_eq(_text(screen, "%BestWpmValue"), "10")
	assert_eq(_bars(screen, "%WpmChart"), 1)


func test_a_new_zombie_shows_the_empty_progress_sign() -> void:
	var screen: TrendsScript = _trends()
	assert_false((screen.get_node("%EmptySign") as Control).visible)
	assert_eq(_player.create_profile("Al"), &"p3")
	assert_true((screen.get_node("%EmptySign") as Control).visible, "Al has no runs: no one else's charts")
	assert_eq(_text(screen, "%KeysValue"), "0")
	assert_eq(_text(screen, "%BestWpmValue"), "0")


func _closet() -> Control:
	var closet: Control = ClosetScene.instantiate() as Control
	closet.process_mode = Node.PROCESS_MODE_DISABLED
	closet.set("navigate", _nav_to)
	closet.set("is_transitioning", func() -> bool: return false)
	closet.set("play_sfx", _mute)
	closet.set("play_music", _mute)
	closet.set("player_data", _player)
	add_child_autofree(closet)
	await wait_process_frames(2)
	return closet


func _tile_state(closet: Control, item_id: StringName) -> ClosetItemTile.State:
	return (closet.call("get_tile", item_id) as ClosetItemTile).get_state()


func test_crypt_closet_shows_the_active_zombies_items_and_tutorial() -> void:
	# Sam: no gift yet, so no tutorial. Bo: gift claimed, tutorial not seen yet, so Bo's visit guides.
	_save.get_data()["profiles"]["p2"]["flags"]["welcome_bonus_claimed"] = true
	var closet: Control = await _closet()
	assert_eq(_tile_state(closet, &"hat_pumpkin"), ClosetItemTile.State.WEARING)
	assert_eq(_tile_state(closet, &"hat_witch"), ClosetItemTile.State.CANT_AFFORD, "Sam has 30 brains")
	assert_eq(_tile_state(closet, &"pet_cute_ghost"), ClosetItemTile.State.CANT_AFFORD)
	assert_false(closet.call("is_tutorial_active"))
	assert_true(_player.switch_profile(&"p2"))
	assert_eq(_tile_state(closet, &"hat_pumpkin"), ClosetItemTile.State.BUY, "Bo doesn't own Sam's hat")
	assert_eq(_tile_state(closet, &"hat_witch"), ClosetItemTile.State.WEARING)
	assert_eq(_tile_state(closet, &"pet_cute_ghost"), ClosetItemTile.State.WEARING)
	assert_eq((closet.get_node("%BrainCounter").get_node("%CountLabel") as Label).text, "250")
	assert_true(closet.call("is_tutorial_active"), "Bo's tutorial state: gift claimed, tutorial not seen")
	assert_true((closet.call("get_tutorial_arrow") as TutorialArrow).visible)
	assert_true(_player.switch_profile(&"p1"))
	assert_eq(_tile_state(closet, &"hat_pumpkin"), ClosetItemTile.State.WEARING)
	assert_false(closet.call("is_tutorial_active"), "Sam's tutorial state: no gift yet")
	assert_false((closet.call("get_tutorial_arrow") as TutorialArrow).visible)
	assert_false(_save.get_data()["profiles"]["p2"]["flags"]["tutorial_seen"], "switching away spends no tutorial")
	assert_false(_save.get_data()["profiles"]["p1"]["flags"]["tutorial_seen"])


func test_a_tutorial_in_progress_resumes_for_its_zombie_after_a_round_trip() -> void:
	# Sam is mid-tutorial (gift claimed, the pumpkin owned but not worn: Wear is next); Bo has seen it.
	var sam: Dictionary = _save.get_data()["profiles"]["p1"]
	sam["flags"]["welcome_bonus_claimed"] = true
	sam["equipped"] = {"hat": "", "pet": ""}
	_save.get_data()["profiles"]["p2"]["flags"]["welcome_bonus_claimed"] = true
	_save.get_data()["profiles"]["p2"]["flags"]["tutorial_seen"] = true
	Router._store_payload({"tutorial": true})
	var closet: Control = await _closet()
	assert_true(closet.call("is_tutorial_active"), "Sam's tutorial")
	# Sam is part-way (the pumpkin is what to wear next), not at the first BUY tile the tutorial starts on.
	closet.set("_tutorial_target", &"hat_pumpkin")
	assert_true(_player.switch_profile(&"p2"))
	assert_false(closet.call("is_tutorial_active"), "Bo has seen the tutorial")
	assert_false((closet.call("get_tutorial_arrow") as TutorialArrow).visible)
	_player.equip(&"hat_witch")
	assert_false(_save.get_data()["profiles"]["p1"]["flags"]["tutorial_seen"], "Bo's Wear doesn't spend Sam's tutorial")
	assert_true(_player.switch_profile(&"p1"))
	assert_true(closet.call("is_tutorial_active"), "Sam's tutorial is back (re-decided from his flags)")
	assert_eq(closet.get("_tutorial_target"), &"hat_pumpkin", "and it resumes on the item Sam left off at")
	assert_true((closet.call("get_tutorial_arrow") as TutorialArrow).visible)


func _report_card() -> Control:
	var result: RunResult = RunResult.create(
			&"zombie_run", 1790000000, 60.0, 50, 0, {}, 5, 0, "all", GameConstants.END_REASON_TIMER)
	Router._store_payload({"result": result, "new_best": false})
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	card.set("navigate", _nav_to)
	card.set("play_sfx", _mute)
	card.set("play_music", _mute)
	card.set("player_data", _player)
	add_child_autofree(card)
	card._process(GameConstants.REPORT_CARD_INPUT_GUARD_S)
	return card


func test_report_card_gift_redirect_follows_the_active_zombie() -> void:
	# Sam has no gift yet; Bo claimed one.
	_save.get_data()["profiles"]["p2"]["flags"]["welcome_bonus_claimed"] = true
	var sam_card: Control = _report_card()
	(sam_card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]], "Sam's card goes to Sam's gift")
	_nav = []
	assert_true(_player.switch_profile(&"p2"))
	var bo_card: Control = _report_card()
	(bo_card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]], "Bo's gift is claimed: Bo's card goes where asked")
	_nav = []
	# A card left open across a switch reads the flag when the kid leaves.
	var open_card: Control = _report_card()
	assert_true(_player.switch_profile(&"p1"))
	(open_card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]], "the redirect reads the zombie playing now")
