extends GutTest
## Story 11.2 (AC 8, epic AC 3): after a profile switch every profile_replaced listener shows the new zombie. A live
## main menu (brain counter, Music/Sound toggles, worn hat and pet, level card states) and an AudioManager (saved
## music/sound settings) built on a temp-dir PlayerData holding two different profiles; switch_profile and
## create_profile must leave all of them showing the newly active zombie. No listener code is expected to change.
## Never the real save: a temp SaveService, and every seam (the menu's slots, the AudioManager) points at it.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")
const AudioManagerScript := preload("res://scripts/autoloads/audio_manager.gd")
const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const TEST_DIR: String = "user://test_profile_switch/"

var _save: SaveServiceScript
var _player: PlayerDataScript


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
	# p2: 250 brains, witch hat and a ghost, music off, Horde Rush open.
	var second: Dictionary = SaveSchema.profile_defaults()
	second["name"] = "Bo"
	second["brains"] = 250
	second["owned_items"] = ["hat_witch", "pet_cute_ghost"]
	second["equipped"] = {"hat": "hat_witch", "pet": "pet_cute_ghost"}
	second["settings"] = {"music_on": false, "sound_on": true}
	second["level_unlocks"] = {"horde_rush": {"moment_seen": true, "chosen": true}}
	_save.get_data()["profiles"]["p2"] = second


func after_each() -> void:
	Router.take_payload()
	_clear()
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
	assert_true((menu.get_node("%MusicToggle") as MenuToggle).is_on())
	assert_eq(_hat(menu), &"hat_pumpkin")
	assert_eq(_pet(menu), &"")
	assert_eq(_card_state(menu, &"horde_rush"), LevelCard.State.LOCKED)
	assert_false(am.is_music_muted())
	assert_true(_player.switch_profile(&"p2"))
	assert_eq(_brains(menu), "250")
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
	assert_true((menu.get_node("%MusicToggle") as MenuToggle).is_on())
	assert_eq(_hat(menu), &"")
	assert_eq(_pet(menu), &"")
	assert_eq(_card_state(menu, &"horde_rush"), LevelCard.State.LOCKED, "a new zombie starts with Zombie Run only")
	assert_false(am.is_music_muted(), "a new zombie has music on")
