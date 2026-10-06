extends GutTest
## Story 4.5, the Epic 4 deliverable (AC 8): on a fresh save, a finished run -> report card -> Welcome Gift
## (+100) -> Crypt Closet with the tutorial -> Buy -> Yes -> Wear on the Pumpkin hat -> Esc -> the hat and
## the pet slots show it -> the next report card goes where asked, and the Closet never guides again.
## One temp-dir PlayerData is shared by every screen through their seams; navigation goes to a recorder.
## The real save, Router and AudioManager are never touched.

const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const GiftScene: PackedScene = preload("res://scenes/screens/welcome_gift.tscn")
const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const PlayerZombieScene: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
const PetSlotScene: PackedScene = preload("res://scenes/cosmetics/pet_slot.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_first_purchase_flow/"
const RUN_BRAINS: int = 35

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
	_player = null


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


## A finished run, recorded like RunFrame does, then its report card (past the guard).
func _finish_run() -> Control:
	var result: RunResult = RunResult.create(
			&"zombie_run", 1790000000, 60.0, 80, 4, {}, RUN_BRAINS, 0, "all", GameConstants.END_REASON_TIMER)
	var new_best: bool = _player.record_run(result)
	Router._store_payload({"result": result, "new_best": new_best})
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	card.set("navigate", _record)
	card.set("player_data", _player)
	add_child_autofree(card)
	card._process(GameConstants.REPORT_CARD_INPUT_GUARD_S)
	return card


func _open_gift() -> Control:
	var gift: Control = GiftScene.instantiate() as Control
	gift.process_mode = Node.PROCESS_MODE_DISABLED
	gift.set("navigate", _record)
	gift.set("play_sfx", _mute)
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


func test_first_run_to_wearing_the_pumpkin_hat() -> void:
	# Report card -> the gift, whichever exit the kid takes (here Play Again).
	var card: Control = _finish_run()
	(card.get_node("%PlayAgainButton") as Button).pressed.emit()
	assert_eq(_follow(Router.Screen.WELCOME_GIFT), {})

	# The gift grants on show and opens the Closet with the tutorial.
	var gift: Control = _open_gift()
	assert_eq(_player.get_brains(), RUN_BRAINS + 100)
	assert_true(_player.get_flag(&"welcome_bonus_claimed"))
	(gift.get_node("%OpenClosetButton") as Button).pressed.emit()
	assert_eq(_follow(Router.Screen.CRYPT_CLOSET), {"tutorial": true})

	# The Closet guides Buy -> Yes -> Wear on the Pumpkin hat.
	var closet: Control = await _open_closet()
	assert_true(closet.call("is_tutorial_active"))
	var arrow: TutorialArrow = closet.call("get_tutorial_arrow")
	var hat_tile: ClosetItemTile = closet.call("get_tile", &"hat_pumpkin")
	assert_true(hat_tile.has_focus())
	assert_eq(arrow.global_position, Vector2(38, 52), "arrow over the Pumpkin hat")
	hat_tile._gui_input(_accept())
	var prompt: ConfirmPrompt = closet.call("get_confirm_prompt")
	prompt.answer_delay_ms = 0
	assert_eq(arrow.global_position, Vector2(176, 222), "arrow left of Yes")
	(prompt.get_node("%YesButton") as Button).pressed.emit()
	assert_true(_player.owns(&"hat_pumpkin"))
	assert_eq(_player.get_brains(), RUN_BRAINS)
	assert_eq(arrow.global_position, Vector2(38, 52), "arrow back over the tile, now Wear")
	hat_tile._gui_input(_accept())
	assert_eq(_player.get_equipped(&"hat"), &"hat_pumpkin")
	assert_true(_player.get_flag(&"tutorial_seen"))
	assert_false(arrow.visible)

	# Esc -> the menu.
	closet._unhandled_input(_esc())
	assert_eq(_follow(Router.Screen.MAIN_MENU), {})

	# The worn hat shows on any zombie that follows PlayerData (the menu, the run, the report card).
	var zombie: Node2D = PlayerZombieScene.instantiate() as Node2D
	var hat_slot: HatSlot = zombie.get_node("%HatSlot") as HatSlot
	hat_slot.player_data = _player
	add_child_autofree(zombie)
	assert_eq(hat_slot.get_item_id(), &"hat_pumpkin")
	var pet_slot: PetSlot = PetSlotScene.instantiate() as PetSlot
	pet_slot.player_data = _player
	add_child_autofree(pet_slot)
	assert_eq(pet_slot.get_item_id(), &"", "no pet bought, the pet slot stays empty")

	# The next run's report card goes where asked: the gift is once per save.
	var second: Control = _finish_run()
	(second.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_follow(Router.Screen.MAIN_MENU), {})

	# Even a stray tutorial payload never guides again.
	_player.add_brains(100)
	Router._store_payload({"tutorial": true})
	var again: Control = await _open_closet()
	assert_false(again.call("is_tutorial_active"))
	assert_false((again.call("get_tutorial_arrow") as TutorialArrow).visible)


func test_skipping_the_closet_with_esc_keeps_the_tutorial_for_the_next_visit() -> void:
	var card: Control = _finish_run()
	card._unhandled_input(_esc())
	assert_eq(_follow(Router.Screen.WELCOME_GIFT), {})
	var gift: Control = _open_gift()
	(gift.get_node("%OpenClosetButton") as Button).pressed.emit()
	_follow(Router.Screen.CRYPT_CLOSET)
	var closet: Control = await _open_closet()
	assert_true(closet.call("is_tutorial_active"))
	closet._unhandled_input(_esc())
	assert_eq(_follow(Router.Screen.MAIN_MENU), {})
	assert_false(_player.get_flag(&"tutorial_seen"), "Esc doesn't spend the tutorial")
	# The menu opens the Closet with no payload: the gift is claimed and the tutorial unseen, so it resumes.
	var from_menu: Control = await _open_closet()
	assert_true(from_menu.call("is_tutorial_active"))
	assert_eq(_player.get_brains(), RUN_BRAINS + 100, "nothing spent")
