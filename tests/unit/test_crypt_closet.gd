extends GutTest
## The Crypt Closet (Story 4.4): tiles from the catalogue, the five states, buying through the confirm
## prompt, wear / take off, the preview, live updates from PlayerData, focus wiring, Esc and Menu, the
## modal prompt, disconnects, and the approved sketch's layout (text fit, 16 px, the margin, the rects).
## Disabled instances: no real input reaches them, so handlers and _gui_input are called directly.
## The live Router, AudioManager and save are never touched (recorder seams, temp SaveService).

const ClosetScene: PackedScene = preload("res://scenes/screens/crypt_closet.tscn")
const ClosetScript := preload("res://scripts/screens/crypt_closet.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const SHIPPED: Catalogue = preload("res://data/cosmetics/catalogue.tres")
const TEST_DIR: String = "user://test_crypt_closet/"
## The 16 px margin every control stays inside (640 x 360 canvas).
const SAFE_RECT: Rect2 = Rect2(16, 16, 608, 328)

## A SaveService that counts request_save() calls (the real one coalesces them).
class CountingSave extends SaveServiceScript:
	var requests: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()


var _closet: ClosetScript
var _player: PlayerDataScript
var _save: CountingSave
var _nav: Array = []
var _sfx: Array[StringName] = []
var _transitioning: bool = false


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_sfx = []
	_transitioning = false
	_player = _make_player_data()


func after_each() -> void:
	Router.take_payload()
	_clear()
	_closet = null
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make_player_data(catalogue: Catalogue = null) -> PlayerDataScript:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = _save
	player.catalogue = catalogue
	add_child_autofree(player)
	return player


## A disabled Closet with every seam injected. `use_catalogue` swaps the scene's shipped catalogue.
func _make(catalogue: Catalogue = null, use_catalogue: bool = false) -> ClosetScript:
	var closet: ClosetScript = ClosetScene.instantiate() as ClosetScript
	closet.process_mode = Node.PROCESS_MODE_DISABLED
	closet.navigate = func(screen: int, payload: Dictionary) -> void: _nav.append([screen, payload])
	closet.is_transitioning = func() -> bool: return _transitioning
	closet.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	closet.player_data = _player
	if use_catalogue:
		closet.catalogue = catalogue
	add_child_autofree(closet)
	_closet = closet
	return closet


## The shipped catalogue with the Witch hat (hat index 1, row 1) made available with the pumpkin's art.
func _two_hat_catalogue() -> Catalogue:
	var catalogue: Catalogue = Catalogue.new()
	var pumpkin: CosmeticItem = SHIPPED.get_item(&"hat_pumpkin")
	for source: CosmeticItem in SHIPPED.items:
		var item: CosmeticItem = source.duplicate() as CosmeticItem
		if item.id == &"hat_witch":
			item.is_available = true
			item.overlay = pumpkin.overlay
			item.icon = pumpkin.icon
		catalogue.items.append(item)
	return catalogue


func _tile(id: StringName) -> ClosetItemTile:
	return _closet.get_tile(id)


func _hats() -> Array[ClosetItemTile]:
	return _closet.get_tiles().slice(0, 9)


func _pets() -> Array[ClosetItemTile]:
	return _closet.get_tiles().slice(9, 18)


func _node(path: String) -> Control:
	return _closet.get_node(path) as Control


func _prompt() -> ConfirmPrompt:
	var prompt: ConfirmPrompt = _closet.get_confirm_prompt()
	prompt.answer_delay_ms = 0
	return prompt


func _hat_slot() -> HatSlot:
	return _closet.get_node("%PreviewZombie").get_node("%HatSlot") as HatSlot


func _pet_slot() -> PetSlot:
	return _closet.get_node("%PreviewPet") as PetSlot


func _neighbor(from: Control, side: Side) -> Node:
	return from.get_node_or_null(from.get_focus_neighbor(side))


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


func _count() -> String:
	return (_closet.get_node("%BrainCounter").get_node("%CountLabel") as Label).text


func _info() -> PackedStringArray:
	return PackedStringArray([(_node("%InfoName") as Label).text, (_node("%InfoState") as Label).text])


func _activate(id: StringName) -> void:
	_tile(id)._gui_input(_accept())


# --- Contents ------------------------------------------------------------------------------------------

func test_nine_hats_and_nine_pets_in_catalogue_order() -> void:
	_make()
	assert_eq(_closet.get_tiles().size(), 18)
	var hats: Array[CosmeticItem] = SHIPPED.items_for_slot(CosmeticItem.Slot.HAT)
	var pets: Array[CosmeticItem] = SHIPPED.items_for_slot(CosmeticItem.Slot.PET)
	for i: int in 9:
		assert_eq(_hats()[i].get_item_id(), hats[i].id)
		assert_eq(_pets()[i].get_item_id(), pets[i].id)
		assert_eq(_hats()[i].get_parent(), _node("%HatGrid"))
		assert_eq(_pets()[i].get_parent(), _node("%PetGrid"))
	assert_eq((_node("%HatGrid") as GridContainer).columns, Catalogue.GRID_COLUMNS)


func test_prices_by_row() -> void:
	_make()
	for grid: Array[ClosetItemTile] in [_hats(), _pets()]:
		for i: int in 9:
			var label: Label = grid[i].get_node("%TagLabel") as Label
			@warning_ignore("integer_division")
			assert_eq(label.text, str((i / 3 + 1) * 100), "%s price" % grid[i].get_item_id())


func test_fresh_save_shows_cant_afford_and_locked() -> void:
	_make()
	assert_eq(_count(), "0")
	for tile: ClosetItemTile in _closet.get_tiles():
		var id: StringName = tile.get_item_id()
		if id == &"hat_pumpkin" or id == &"pet_cute_ghost":
			assert_eq(tile.get_state(), ClosetItemTile.State.CANT_AFFORD, String(id))
		else:
			assert_eq(tile.get_state(), ClosetItemTile.State.LOCKED, String(id))
	assert_eq(_info(), PackedStringArray(["Pumpkin hat", "Need 100 more"]))


func test_with_100_brains_both_mvp_items_are_buy() -> void:
	_player.add_brains(100)
	_make()
	assert_eq(_count(), "100")
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.BUY)
	assert_eq(_tile(&"pet_cute_ghost").get_state(), ClosetItemTile.State.BUY)
	assert_eq(_info(), PackedStringArray(["Pumpkin hat", "Buy"]))


func test_locked_tile_info_is_a_mystery() -> void:
	_make()
	_hats()[1].grab_focus()
	assert_eq(_info(), PackedStringArray(["Coming soon", ""]))


func test_menu_focus_blanks_the_info_sign() -> void:
	_make()
	_node("%MenuButton").grab_focus()
	assert_eq(_info(), PackedStringArray(["", ""]))


# --- Buying --------------------------------------------------------------------------------------------

func test_buy_opens_the_prompt_with_yes_focused_and_the_background_off() -> void:
	_player.add_brains(100)
	_make()
	_activate(&"hat_pumpkin")
	assert_true(_prompt().is_open())
	assert_true(_prompt().visible)
	assert_eq((_prompt().get_node("%QuestionLabel") as Label).text, "Buy the Pumpkin hat for 100 brains?")
	assert_true((_prompt().get_node("%YesButton") as Control).has_focus(), "focus starts on Yes")
	for tile: ClosetItemTile in _closet.get_tiles():
		assert_eq(tile.focus_mode, Control.FOCUS_NONE, "%s can't take focus" % tile.get_item_id())
	assert_eq(_node("%MenuButton").focus_mode, Control.FOCUS_NONE)
	assert_eq(_player.get_brains(), 100, "nothing bought yet")
	assert_eq(_sfx, [] as Array[StringName])


func test_yes_buys_plays_the_jingle_and_saves() -> void:
	_player.add_brains(100)
	_make()
	var before: int = _save.requests
	_activate(&"hat_pumpkin")
	(_prompt().get_node("%YesButton") as Button).pressed.emit()
	assert_eq(_player.get_brains(), 0)
	assert_true(_player.owns(&"hat_pumpkin"))
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEAR)
	assert_eq(_tile(&"pet_cute_ghost").get_state(), ClosetItemTile.State.CANT_AFFORD)
	assert_eq(_sfx, [&"sfx_purchase"] as Array[StringName], "the jingle, once")
	assert_eq(_count(), "0")
	assert_false(_prompt().is_open())
	assert_false(_prompt().visible)
	assert_true(_tile(&"hat_pumpkin").has_focus(), "focus back on the tile")
	assert_eq(_save.requests - before, 1, "the purchase requested the save")
	for tile: ClosetItemTile in _closet.get_tiles():
		assert_eq(tile.focus_mode, Control.FOCUS_ALL)
	assert_eq(_node("%MenuButton").focus_mode, Control.FOCUS_ALL)
	assert_eq(_info(), PackedStringArray(["Pumpkin hat", "Wear"]))
	_pets()[0].grab_focus()
	assert_eq(_info(), PackedStringArray(["Cute ghost", "Need 100 more"]))


func _assert_nothing_bought(label: String) -> void:
	assert_eq(_player.get_brains(), 100, label)
	assert_false(_player.owns(&"hat_pumpkin"), label)
	assert_eq(_sfx, [] as Array[StringName], label)
	assert_eq(_nav, [], label + ": no navigation")
	assert_false(_prompt().is_open(), label)
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.BUY, label)
	assert_true(_tile(&"hat_pumpkin").has_focus(), label + ": focus back on the tile")
	assert_eq(_node("%MenuButton").focus_mode, Control.FOCUS_ALL, label)


func test_no_changes_nothing() -> void:
	_player.add_brains(100)
	_make()
	_activate(&"hat_pumpkin")
	(_prompt().get_node("%NoButton") as Button).pressed.emit()
	_assert_nothing_bought("No")


func test_cancel_changes_nothing() -> void:
	_player.add_brains(100)
	_make()
	_activate(&"hat_pumpkin")
	_prompt().cancel()
	_assert_nothing_bought("cancel")


func test_esc_while_open_is_no_and_stays() -> void:
	_player.add_brains(100)
	_make()
	_activate(&"hat_pumpkin")
	_closet._unhandled_input(_esc())
	_assert_nothing_bought("Esc")


func test_a_second_activation_while_open_is_ignored() -> void:
	_player.add_brains(200)
	_make()
	_activate(&"hat_pumpkin")
	_closet.call("_on_tile_activated", &"pet_cute_ghost")
	assert_eq((_prompt().get_node("%QuestionLabel") as Label).text, "Buy the Pumpkin hat for 100 brains?")
	(_prompt().get_node("%YesButton") as Button).pressed.emit()
	assert_true(_player.owns(&"hat_pumpkin"))
	assert_false(_player.owns(&"pet_cute_ghost"))


func test_an_unexpected_buy_result_warns_and_refreshes() -> void:
	_player.add_brains(100)
	_make()
	_activate(&"hat_pumpkin")
	# The wallet drains behind the open prompt (a debug key, a second screen).
	_player.get("save_service").get_active_profile()["brains"] = 0
	(_prompt().get_node("%YesButton") as Button).pressed.emit()
	assert_push_warning("closet: unexpected buy result NOT_ENOUGH_BRAINS for hat_pumpkin")
	assert_false(_player.owns(&"hat_pumpkin"))
	assert_eq(_sfx, [] as Array[StringName])
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.CANT_AFFORD)
	assert_eq(_count(), "0")


# --- Wear and take off ---------------------------------------------------------------------------------

func _own_pumpkin() -> void:
	_player.add_brains(100)
	_player.buy_item(SHIPPED.get_item(&"hat_pumpkin"))


func test_wear_then_take_off() -> void:
	_own_pumpkin()
	_make()
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEAR)
	var before: int = _save.requests
	_activate(&"hat_pumpkin")
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEARING)
	assert_eq(_player.get_equipped(&"hat"), &"hat_pumpkin")
	assert_eq(_hat_slot().get_item_id(), &"hat_pumpkin")
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	assert_eq(_save.requests - before, 1, "equip requested the save")
	assert_eq(_info(), PackedStringArray(["Pumpkin hat", "Wearing"]))
	_activate(&"hat_pumpkin")
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEAR)
	assert_eq(_player.get_equipped(&"hat"), &"")
	assert_eq(_sfx, [&"sfx_ui_click", &"sfx_ui_click"] as Array[StringName])
	assert_false(_prompt().is_open(), "no prompt for wear or take off")
	# The focused hat still previews (it's the focused tile); on Menu the preview shows the equipped: none.
	_node("%MenuButton").grab_focus()
	assert_eq(_hat_slot().get_item_id(), &"")


func test_wearing_a_second_hat_flips_the_first_back_to_wear() -> void:
	var catalogue: Catalogue = _two_hat_catalogue()
	_player = _make_player_data(catalogue)
	_player.add_brains(200)
	_player.buy_item(catalogue.get_item(&"hat_pumpkin"))
	_player.buy_item(catalogue.get_item(&"hat_witch"))
	_player.equip(&"hat_pumpkin")
	_make(catalogue, true)
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEARING)
	assert_eq(_tile(&"hat_witch").get_state(), ClosetItemTile.State.WEAR)
	_activate(&"hat_witch")
	assert_eq(_tile(&"hat_witch").get_state(), ClosetItemTile.State.WEARING)
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEAR)
	assert_eq(_player.get_equipped(&"hat"), &"hat_witch")


func test_locked_and_cant_afford_only_wiggle() -> void:
	_make()
	var poor: ClosetItemTile = _tile(&"hat_pumpkin")
	var locked: ClosetItemTile = _hats()[1]
	for tile: ClosetItemTile in [poor, locked]:
		tile._gui_input(_accept())
		assert_true(tile.is_wiggling(), String(tile.get_item_id()))
	assert_false(_prompt().is_open())
	assert_eq(_sfx, [] as Array[StringName], "no sound on a wiggle")
	assert_eq(_player.get_brains(), 0)
	assert_eq(_player.get_owned_items(), [] as Array[StringName])


func test_a_stale_tile_acts_on_the_current_state() -> void:
	_player.add_brains(100)
	_make()
	# The tile still looks like Buy, but the wallet emptied without a signal.
	_player.get("save_service").get_active_profile()["brains"] = 0
	_closet.call("_on_tile_activated", &"hat_pumpkin")
	assert_false(_prompt().is_open())
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.CANT_AFFORD, "refreshed")


# --- Preview -------------------------------------------------------------------------------------------

func test_preview_slots_do_not_follow_player_data() -> void:
	_make()
	assert_false(_hat_slot().follow_equipped)
	assert_false(_pet_slot().follow_equipped)
	assert_null(_hat_slot().player_data, "never connected to a PlayerData")
	assert_null(_pet_slot().player_data)
	for signal_name: StringName in [&"equipment_changed", &"profile_replaced"]:
		for connection: Dictionary in _player.get_signal_connection_list(signal_name):
			var target: Object = (connection["callable"] as Callable).get_object()
			assert_false(target is HatSlot or target is PetSlot, "a preview slot listens to %s" % signal_name)


func test_preview_follows_focus_and_keeps_the_other_slot_equipped() -> void:
	_player.add_brains(100)
	_player.buy_item(SHIPPED.get_item(&"pet_cute_ghost"))
	_player.equip(&"pet_cute_ghost")
	_make()
	# Focus on the pumpkin hat (not owned): the hat previews, the equipped ghost stays.
	assert_eq(_hat_slot().get_item_id(), &"hat_pumpkin")
	assert_eq(_pet_slot().get_item_id(), &"pet_cute_ghost")
	_node("%MenuButton").grab_focus()
	assert_eq(_hat_slot().get_item_id(), &"", "Menu: the equipped hat (none)")
	assert_eq(_pet_slot().get_item_id(), &"pet_cute_ghost")


func test_focusing_a_locked_tile_shows_the_equipped_items_quietly() -> void:
	_own_pumpkin()
	_player.equip(&"hat_pumpkin")
	_make()
	for tile: ClosetItemTile in _closet.get_tiles():
		if tile.get_state() != ClosetItemTile.State.LOCKED:
			continue
		tile.grab_focus()
		assert_eq(_hat_slot().get_item_id(), &"hat_pumpkin", String(tile.get_item_id()))
		assert_eq(_pet_slot().get_item_id(), &"", String(tile.get_item_id()))
	assert_push_warning_count(0, "no slot ever warns because of the Closet")


func test_pet_tile_previews_the_pet_and_keeps_the_hat() -> void:
	_own_pumpkin()
	_player.equip(&"hat_pumpkin")
	_make()
	_tile(&"pet_cute_ghost").grab_focus()
	assert_eq(_pet_slot().get_item_id(), &"pet_cute_ghost")
	assert_eq(_hat_slot().get_item_id(), &"hat_pumpkin")


# --- Live updates --------------------------------------------------------------------------------------

func test_brains_arriving_flip_cant_afford_to_buy() -> void:
	_make()
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.CANT_AFFORD)
	_player.add_brains(100)
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.BUY)
	assert_eq(_tile(&"pet_cute_ghost").get_state(), ClosetItemTile.State.BUY)
	assert_eq(_count(), "100")
	assert_eq(_info(), PackedStringArray(["Pumpkin hat", "Buy"]))


func test_inventory_change_alone_refreshes() -> void:
	_player.add_brains(100)
	_make()
	# Write the purchase without brains_changed: only inventory_changed tells the Closet.
	(_player.get("save_service").get_active_profile()["owned_items"] as Array).append("hat_pumpkin")
	_player.inventory_changed.emit(&"hat_pumpkin")
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEAR)


func test_equipment_change_refreshes() -> void:
	_own_pumpkin()
	_make()
	_player.equip(&"hat_pumpkin")
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.WEARING)


func test_reset_all_rereads_everything() -> void:
	_own_pumpkin()
	_player.add_brains(50)
	_player.equip(&"hat_pumpkin")
	_make()
	assert_eq(_count(), "50")
	_player.reset_all()
	assert_eq(_count(), "0")
	assert_eq(_tile(&"hat_pumpkin").get_state(), ClosetItemTile.State.CANT_AFFORD)
	_node("%MenuButton").grab_focus()
	assert_eq(_hat_slot().get_item_id(), &"")


func test_exit_tree_disconnects() -> void:
	_make()
	var closet: ClosetScript = _closet
	remove_child(closet)
	for signal_name: StringName in [&"brains_changed", &"inventory_changed", &"equipment_changed", &"profile_replaced"]:
		for connection: Dictionary in _player.get_signal_connection_list(signal_name):
			assert_ne((connection["callable"] as Callable).get_object(), closet, "%s still connected" % signal_name)
	closet.free()
	_player.add_brains(100)
	_player.reset_all()
	assert_push_error_count(0)


# --- Focus ---------------------------------------------------------------------------------------------

func test_initial_focus_is_the_first_hat() -> void:
	_make()
	assert_true(_hats()[0].has_focus())


func test_neighbours_inside_and_across_the_grids() -> void:
	_make()
	var hats: Array[ClosetItemTile] = _hats()
	var pets: Array[ClosetItemTile] = _pets()
	var menu: Control = _node("%MenuButton")
	for row: int in 3:
		assert_eq(_neighbor(hats[row * 3 + 2], SIDE_RIGHT), pets[row * 3], "hat col 3 -> pet col 1, row %d" % row)
		assert_eq(_neighbor(pets[row * 3], SIDE_LEFT), hats[row * 3 + 2], "pet col 1 -> hat col 3, row %d" % row)
		assert_eq(_neighbor(hats[row * 3], SIDE_LEFT), hats[row * 3], "hat col 1 left stops")
		assert_eq(_neighbor(pets[row * 3 + 2], SIDE_RIGHT), pets[row * 3 + 2], "pet col 3 right stops")
	for grid: Array[ClosetItemTile] in [hats, pets]:
		assert_eq(_neighbor(grid[4], SIDE_LEFT), grid[3])
		assert_eq(_neighbor(grid[4], SIDE_RIGHT), grid[5])
		assert_eq(_neighbor(grid[4], SIDE_TOP), grid[1])
		assert_eq(_neighbor(grid[4], SIDE_BOTTOM), grid[7])
		for col: int in 3:
			assert_eq(_neighbor(grid[col], SIDE_TOP), menu, "row 1 up -> Menu")
			assert_eq(_neighbor(grid[6 + col], SIDE_BOTTOM), grid[6 + col], "row 3 down stops")
	assert_eq(_neighbor(menu, SIDE_BOTTOM), pets[2], "Menu down -> the pet tile under it")
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP]:
		assert_eq(_neighbor(menu, side), menu, "Menu side %d stops" % side)


func test_tab_order_walks_hats_pets_then_menu() -> void:
	_make()
	var order: Array[Control] = []
	order.assign(_closet.get_tiles())
	order.append(_node("%MenuButton"))
	for i: int in order.size():
		var control: Control = order[i]
		assert_eq(control.get_node(control.focus_next), order[(i + 1) % order.size()])
		assert_eq(control.get_node(control.focus_previous), order[i - 1])


func test_decor_never_takes_focus_or_the_mouse() -> void:
	_make()
	for path: String in ["%Background", "%BrainCounter", "%Title", "%HatsHeading", "%PetsHeading", "%HatGrid",
			"%PetGrid", "%Mirror", "%InfoSign", "%InfoName", "%InfoState"]:
		assert_eq(_node(path).focus_mode, Control.FOCUS_NONE, path)
		assert_eq(_node(path).mouse_filter, Control.MOUSE_FILTER_IGNORE, path)


# --- Leaving -------------------------------------------------------------------------------------------

func test_esc_goes_to_the_menu_once() -> void:
	_make()
	_closet._unhandled_input(_esc())
	_closet._unhandled_input(_esc())
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])


func test_menu_button_goes_to_the_menu_once() -> void:
	_make()
	(_node("%MenuButton") as Button).pressed.emit()
	(_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_leaving_during_a_router_transition_is_ignored() -> void:
	_make()
	_transitioning = true
	_closet._unhandled_input(_esc())
	assert_eq(_nav, [])


func test_leaving_is_released_when_the_transition_ends_without_freeing_the_closet() -> void:
	_make()
	_closet.process_mode = Node.PROCESS_MODE_INHERIT
	_closet.navigate = func(screen: int, payload: Dictionary) -> void:
		_nav.append([screen, payload])
		_transitioning = true
	_closet._unhandled_input(_esc())
	assert_eq(_nav.size(), 1)
	_transitioning = false
	await wait_process_frames(2)
	_closet._unhandled_input(_esc())
	assert_eq(_nav.size(), 2, "the guard was released")


func test_payload_is_consumed() -> void:
	Router._store_payload({"tutorial": true})
	_make()
	assert_eq(Router.take_payload(), {})


# --- Bad data ------------------------------------------------------------------------------------------

func test_null_catalogue_logs_builds_nothing_and_focuses_menu() -> void:
	_make(null, true)
	assert_push_error("crypt closet: no catalogue")
	assert_eq(_closet.get_tiles().size(), 0)
	assert_true(_node("%MenuButton").has_focus())
	assert_eq(_neighbor(_node("%MenuButton"), SIDE_BOTTOM), _node("%MenuButton"))


func test_invalid_catalogue_logs_and_builds_nothing() -> void:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(SHIPPED.get_item(&"hat_pumpkin"))
	_make(catalogue, true)
	assert_push_error("crypt closet: invalid catalogue")
	assert_eq(_closet.get_tiles().size(), 0)
	assert_true(_node("%MenuButton").has_focus())


# --- Layout (approved sketch sketches/crypt-closet-4-4.md) ---------------------------------------------

func test_rects_match_the_sketch() -> void:
	_make()
	await wait_process_frames(2)
	var expected: Dictionary[String, Rect2] = {
		"%BrainCounter": Rect2(16, 16, 80, 28),
		"%Title": Rect2(168, 16, 304, 32),
		"%MenuButton": Rect2(544, 16, 80, 32),
		"%HatsHeading": Rect2(90, 56, 64, 16),
		"%PetsHeading": Rect2(486, 56, 64, 16),
		"%HatGrid": Rect2(16, 76, 212, 212),
		"%PetGrid": Rect2(412, 76, 212, 212),
		"%Mirror": Rect2(244, 76, 152, 120),
		"%InfoSign": Rect2(16, 296, 608, 48),
		"%InfoName": Rect2(24, 302, 592, 16),
		"%InfoState": Rect2(24, 322, 592, 16),
	}
	for path: String in expected:
		assert_eq(_node(path).get_global_rect(), expected[path], path)
	assert_eq(_hats()[0].get_global_rect(), Rect2(16, 76, 68, 68), "hat tile 1")
	assert_eq(_hats()[8].get_global_rect(), Rect2(160, 220, 68, 68), "hat tile 9")
	assert_eq(_pets()[0].get_global_rect(), Rect2(412, 76, 68, 68), "pet tile 1")
	assert_eq(_pets()[8].get_global_rect(), Rect2(556, 220, 68, 68), "pet tile 9")
	assert_eq((_closet.get_node("%PreviewZombie") as Node2D).position, Vector2(302, 188))
	assert_eq((_closet.get_node("%PreviewPet") as Node2D).position, Vector2(338, 188))
	var prompt_rects: Dictionary[String, Rect2] = {
		"%Panel": Rect2(56, 96, 528, 168),
		"%Sign": Rect2(64, 104, 512, 100),
		"%YesButton": Rect2(208, 216, 96, 32),
		"%NoButton": Rect2(336, 216, 96, 32),
		"%Scrim": Rect2(0, 0, 640, 360),
	}
	for path: String in prompt_rects:
		assert_eq((_prompt().get_node(path) as Control).get_global_rect(), prompt_rects[path], path)


func test_scrim_is_night_at_60_percent_and_stops_the_mouse() -> void:
	_make()
	var scrim: ColorRect = _prompt().get_node("%Scrim") as ColorRect
	assert_eq(scrim.color, Color("#2B1D3F", 0.6))
	assert_eq(scrim.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(_closet.get_child(_closet.get_child_count() - 1), _prompt(), "the prompt draws on top")


func test_every_control_is_inside_the_margin() -> void:
	_own_pumpkin()
	_make()
	await wait_process_frames(2)
	var checked: int = 0
	for node: Node in _closet.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.name == &"Background":
			continue
		if control.name == &"Shadow":
			# The 2 px drop shadow is decoration and may overhang the margin by its own offset, no more.
			assert_true(SAFE_RECT.grow(2.0).encloses(control.get_global_rect()), "Shadow %s overhangs too far" % control.get_global_rect())
			continue
		assert_true(SAFE_RECT.encloses(control.get_global_rect()), "%s %s outside the margin" % [control.name, control.get_global_rect()])
		checked += 1
	assert_gt(checked, 40)


func test_preview_stays_inside_the_mirror() -> void:
	_make()
	var mirror: Rect2 = _node("%Mirror").get_global_rect()
	var feet: Vector2 = (_closet.get_node("%PreviewZombie") as Node2D).position
	var zombie: Rect2 = Rect2(feet + Vector2(-16, -31 - 11), Vector2(32, 32 + 11))
	var pet_feet: Vector2 = (_closet.get_node("%PreviewPet") as Node2D).position
	var pet: Rect2 = Rect2(pet_feet + Vector2(-16, -31), Vector2(32, 32))
	assert_true(mirror.encloses(zombie), "zombie and hat inside the mirror")
	assert_true(mirror.encloses(pet), "pet inside the mirror")


func test_text_fits_and_is_at_least_16px() -> void:
	_own_pumpkin()
	_player.add_brains(300)
	_make()
	_prompt().open("Buy the Pumpkin hat for 100 brains?")
	await wait_process_frames(2)
	var checked: int = 0
	for node: Node in _closet.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		if control is Label:
			_assert_label_fits(control as Label)
			checked += 1
		elif control is Button and not (control as Button).text.is_empty():
			var button: Button = control as Button
			assert_gte(button.get_theme_font_size(&"font_size"), 16, "%s font size" % button.name)
			assert_lte(button.get_minimum_size().x, button.size.x, "%s text overflows" % button.name)
			checked += 1
	assert_gt(checked, 20, "the walk found the Closet's text")
	assert_eq((_prompt().get_node("%QuestionLabel") as Label).get_theme_font_size(&"font_size"), 24)


func test_every_info_line_fits() -> void:
	_make()
	var label: Label = _node("%InfoName") as Label
	for item: CosmeticItem in SHIPPED.items:
		for state: ClosetItemTile.State in ClosetItemTile.State.values():
			for line: String in ClosetItemTile.info_lines(item, state, item.price):
				label.text = line
				_assert_label_fits(label)


func test_the_question_fits_for_every_shipped_item() -> void:
	_make()
	var label: Label = _prompt().get_node("%QuestionLabel") as Label
	for item: CosmeticItem in SHIPPED.items:
		_prompt().open("Buy the %s for %d brains?" % [item.display_name, item.price])
		await wait_process_frames(1)
		_assert_label_fits(label)
	_prompt().close()


func _assert_label_fits(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	assert_gte(font_size, 16, "%s font size" % label.name)
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(width, label.size.x, "%s '%s' overflows" % [label.name, label.text])
		return
	for word: String in label.text.split(" "):
		var word_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(word_width, label.size.x, "%s word '%s' overflows" % [label.name, word])
	var lines_height: float = label.get_line_count() * label.get_line_height()
	assert_lte(lines_height, label.size.y, "%s wraps taller than its box" % label.name)


func test_an_open_prompt_is_cancelled_when_the_wallet_changes() -> void:
	_player.add_brains(100)
	_make()
	_tile(&"hat_pumpkin").activated.emit(&"hat_pumpkin")
	assert_true(_prompt().is_open())
	_player.add_brains(5)
	assert_false(_prompt().is_open(), "its question is out of date")
	assert_eq(_player.owns(&"hat_pumpkin"), false)
	assert_true(_tile(&"hat_pumpkin").has_focus())
