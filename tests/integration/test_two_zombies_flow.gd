extends GutTest
## Story 11.3 (FR78, epic AC): two kids share one save and each gets a whole, separate first visit. Kid A (p1) finishes
## a run -> report card -> Welcome Gift (+100) -> Crypt Closet tutorial -> buys and wears the Pumpkin hat. Then Bo
## (p2) is added, the picker switches back and forth, and kid B gets its own report card -> its own gift -> its own
## Closet tutorial -> buys the Witch hat and the Cute Ghost. Each kid ends with exactly what it earned, and a hat and
## pet slot following PlayerData show whoever is playing.
## Copied from test_first_purchase_flow.gd (no shared base): one temp-dir PlayerData through every screen's seams,
## navigation to a recorder, the shipped catalogue and tier config. The real save, Router and AudioManager are never
## touched.

const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const GiftScene: PackedScene = preload("res://scenes/screens/welcome_gift.tscn")
const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const PlayerZombieScene: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
const PetSlotScene: PackedScene = preload("res://scenes/cosmetics/pet_slot.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_two_zombies_flow/"
const GIFT: int = 100
## Kid A: 80 keys in 60 s = 16 WPM (tier 3), 35 brains.
const A_KEYS: int = 80
const A_BRAINS: int = 35
## Kid B: 200 keys in 60 s = 40 WPM (tier 5), 100 brains.
const B_KEYS: int = 200
const B_BRAINS: int = 100

var _player: PlayerDataScript
var _nav: Array = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	_player = PlayerDataScript.new()
	_player.save_service = save
	add_child_autofree(_player)


func after_each() -> void:
	Router.take_payload()
	_clear()
	_reset_input_handled()
	_player = null


## Calling _unhandled_input() by hand marks GUT's viewport input as handled; a no-op event clears it.
func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _record(screen: int, payload: Dictionary) -> void:
	_nav.append([screen, payload])


func _mute(_id: StringName) -> void:
	pass


## Takes the one recorded navigation and hands its payload to the Router, like Router.go would.
func _follow(expected_screen: Router.Screen) -> Dictionary:
	assert_eq(_nav.size(), 1, "one navigation to %s" % Router.Screen.keys()[expected_screen])
	if _nav.size() != 1:
		return {}
	var step: Array = _nav[0]
	_nav = []
	assert_eq(step[0], expected_screen)
	Router._store_payload(step[1])
	return step[1]


## A finished Zombie Run, recorded like RunFrame does, then its report card (past the guard).
func _finish_run(keys: int, brains: int) -> Control:
	var result: RunResult = RunResult.create(
			&"zombie_run", 1790000000, 60.0, keys, 4, {}, brains, 0, "all", GameConstants.END_REASON_TIMER)
	var new_best: bool = _player.record_run(result)
	Router._store_payload({"result": result, "new_best": new_best})
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	card.set("navigate", _record)
	card.set("play_sfx", _mute)
	card.set("play_music", _mute)
	card.set("player_data", _player)
	add_child_autofree(card)
	card._process(GameConstants.REPORT_CARD_INPUT_GUARD_S)
	return card


func _open_gift() -> Control:
	var gift: Control = GiftScene.instantiate() as Control
	gift.process_mode = Node.PROCESS_MODE_DISABLED
	gift.set("navigate", _record)
	gift.set("play_sfx", _mute)
	gift.set("play_music", _mute)
	gift.set("player_data", _player)
	add_child_autofree(gift)
	gift._process(1.0)
	return gift


func _open_closet() -> Control:
	var closet: Control = ClosetScene.instantiate() as Control
	closet.process_mode = Node.PROCESS_MODE_DISABLED
	closet.set("navigate", _record)
	closet.set("is_transitioning", func() -> bool: return false)
	closet.set("play_sfx", _mute)
	closet.set("play_music", _mute)
	closet.set("player_data", _player)
	add_child_autofree(closet)
	await wait_process_frames(2)
	return closet


func _accept() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _esc() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


## Run -> report card (Play Again) -> the gift (+100) -> the Closet with the tutorial on; returns the Closet.
func _first_visit(keys: int, brains: int) -> Control:
	assert_false(_player.get_flag(&"welcome_bonus_claimed"), "this zombie has no gift yet")
	var card: Control = _finish_run(keys, brains)
	(card.get_node("%PlayAgainButton") as Button).pressed.emit()
	assert_eq(_follow(Router.Screen.WELCOME_GIFT), {}, "this zombie's first report card goes to its gift")
	var gift: Control = _open_gift()
	assert_eq(_player.get_brains(), brains + GIFT, "the gift is this zombie's own +100")
	assert_true(_player.get_flag(&"welcome_bonus_claimed"))
	(gift.get_node("%OpenClosetButton") as Button).pressed.emit()
	assert_eq(_follow(Router.Screen.CRYPT_CLOSET), {"tutorial": true})
	var closet: Control = await _open_closet()
	assert_true(closet.call("is_tutorial_active"), "this zombie gets its own Closet tutorial")
	return closet


## Buy `item_id` on its tile (Buy -> Yes), then Wear it.
func _buy_and_wear(closet: Control, item_id: StringName) -> void:
	var tile: ClosetItemTile = closet.call("get_tile", item_id)
	assert_eq(tile.get_state(), ClosetItemTile.State.BUY, "%s is for sale to this zombie" % item_id)
	tile._gui_input(_accept())
	var prompt: ConfirmPrompt = closet.call("get_confirm_prompt")
	prompt.answer_delay_ms = 0
	(prompt.get_node("%YesButton") as Button).pressed.emit()
	assert_true(_player.owns(item_id), "bought %s" % item_id)
	tile._gui_input(_accept())
	assert_eq(tile.get_state(), ClosetItemTile.State.WEARING, "wearing %s" % item_id)


func _price(item_id: StringName) -> int:
	return _player.catalogue.get_item(item_id).price


func _profile(id: String) -> Dictionary:
	return _player.save_service.get_data()["profiles"][id]


## The zombie's own end state: everything that came from its run, gift and purchases.
func _assert_kid(id: String, keys: int, brains: int, owned: Array, equipped: Dictionary, tier: int) -> void:
	var p: Dictionary = _profile(id)
	var wpm: int = keys / 5
	assert_eq(p["owned_items"], owned, "%s owns only its own items" % id)
	assert_eq(p["equipped"], equipped, "%s wears only its own items" % id)
	assert_eq(p["flags"], {"welcome_bonus_claimed": true, "tutorial_seen": true, "placement_done": true},
			"%s: its own gift, tutorial and placement" % id)
	assert_eq(int(p["tier"]), tier, "%s: placed by its own run" % id)
	assert_eq((p["run_history"] as Array).size(), 1, "%s: only its own run" % id)
	assert_eq(int(p["run_history"][0]["wpm"]), wpm, "%s: its own run's WPM" % id)
	assert_eq(int(p["best_wpm"]["zombie_run"]), wpm, "%s: its own best" % id)
	assert_eq(p["lifetime"], {"runs": 1, "keys_typed": keys, "seconds": 60, "brains": brains + GIFT},
			"%s: its own lifetime totals" % id)


func test_two_kids_each_get_their_own_run_gift_tutorial_and_hat() -> void:
	# Kid A: the whole first visit on p1.
	assert_true(_player.set_zombie_name("Sam"))
	var closet_a: Control = await _first_visit(A_KEYS, A_BRAINS)
	assert_eq(((closet_a.call("get_tutorial_arrow") as TutorialArrow)).visible, true)
	_buy_and_wear(closet_a, &"hat_pumpkin")
	assert_true(_player.get_flag(&"tutorial_seen"))
	closet_a._unhandled_input(_esc())
	assert_eq(_follow(Router.Screen.MAIN_MENU), {})
	assert_eq(_player.get_brains(), A_BRAINS + GIFT - _price(&"hat_pumpkin"))

	# A second kid joins; the picker switches back and forth.
	assert_eq(_player.create_profile("Bo"), &"p2")
	assert_true(_player.switch_profile(&"p1"))
	assert_eq(_player.get_equipped(&"hat"), &"hat_pumpkin")
	assert_true(_player.switch_profile(&"p2"))
	assert_eq(_player.get_brains(), 0, "Bo starts with nothing of Sam's")
	assert_eq(_player.get_owned_items(), [] as Array[StringName])

	# Kid B: its own first visit, a different hat (not the arrow's Pumpkin) and a pet.
	var closet_b: Control = await _first_visit(B_KEYS, B_BRAINS)
	_buy_and_wear(closet_b, &"hat_witch")
	assert_false(closet_b.call("is_tutorial_active"), "Bo's first Wear ends Bo's tutorial")
	assert_true(_player.get_flag(&"tutorial_seen"))
	_buy_and_wear(closet_b, &"pet_cute_ghost")
	closet_b._unhandled_input(_esc())
	assert_eq(_follow(Router.Screen.MAIN_MENU), {})
	assert_eq(_player.get_brains(), B_BRAINS + GIFT - _price(&"hat_witch") - _price(&"pet_cute_ghost"))

	# Each kid has exactly what it earned, and nothing of the other's.
	_assert_kid("p1", A_KEYS, A_BRAINS, ["hat_pumpkin"], {"hat": "hat_pumpkin", "pet": ""}, 3)
	assert_eq(int(_profile("p1")["brains"]), A_BRAINS + GIFT - _price(&"hat_pumpkin"))
	_assert_kid("p2", B_KEYS, B_BRAINS, ["hat_witch", "pet_cute_ghost"],
			{"hat": "hat_witch", "pet": "pet_cute_ghost"}, 5)
	assert_eq(int(_profile("p2")["brains"]), B_BRAINS + GIFT - _price(&"hat_witch") - _price(&"pet_cute_ghost"))

	# Slots that follow PlayerData show whoever is playing.
	var zombie: Node2D = PlayerZombieScene.instantiate() as Node2D
	var hat_slot: HatSlot = zombie.get_node("%HatSlot") as HatSlot
	hat_slot.player_data = _player
	add_child_autofree(zombie)
	var pet_slot: PetSlot = PetSlotScene.instantiate() as PetSlot
	pet_slot.player_data = _player
	add_child_autofree(pet_slot)
	assert_eq(hat_slot.get_item_id(), &"hat_witch")
	assert_eq(pet_slot.get_item_id(), &"pet_cute_ghost")
	assert_true(_player.switch_profile(&"p1"))
	assert_eq(hat_slot.get_item_id(), &"hat_pumpkin", "Sam's hat")
	assert_eq(pet_slot.get_item_id(), &"", "Sam has no pet")
	assert_true(_player.switch_profile(&"p2"))
	assert_eq(hat_slot.get_item_id(), &"hat_witch", "Bo's hat")
	assert_eq(pet_slot.get_item_id(), &"pet_cute_ghost", "Bo's pet")

	# Sam's next report card goes where asked: Sam's gift is claimed (and so is Bo's).
	assert_true(_player.switch_profile(&"p1"))
	var again: Control = _finish_run(A_KEYS, 0)
	(again.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_follow(Router.Screen.MAIN_MENU), {})
	assert_eq((_profile("p2")["run_history"] as Array).size(), 1, "Sam's second run is not in Bo's history")
