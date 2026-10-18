extends GutTest
## The "Who's playing?" screen (Story 11.2, FR78, FR25): one card per profile in id order with that profile's
## name, hat and pet; New zombie only while there is room; focus starts on the active zombie and walks the cards
## then New zombie with the ends stopping; a pick switches the profile and goes to the main menu (named) or the
## name screen (unnamed) once; New zombie opens the name screen in new-zombie mode and creates nothing; Esc does
## nothing, unless the payload is {"from_menu": true} (Story 11.4: Esc goes back to the menu once, switching
## nothing); the cards rebuild on profile_replaced; the payload is consumed.
## Always a temp-dir SaveService + PlayerData and recorder seams: the real save and the live Router are never
## touched (the screen writes through switch_profile).

const WhosPlayingScene: PackedScene = preload("res://scenes/screens/whos_playing.tscn")
const WhosPlayingScript := preload("res://scripts/screens/whos_playing.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_whos_playing/"
const SAFE_RECT: Rect2 = Rect2(16, 16, 608, 328)

var _save: SaveServiceScript
var _player: PlayerDataScript
var _nav: Array = []
var _sfx: Array[StringName] = []
var _music: Array[StringName] = []
var _transitioning: bool = false
## False: the navigate recorder doesn't start a transition (the Router refused).
var _starts_transition: bool = true


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_sfx = []
	_music = []
	_transitioning = false
	_starts_transition = true
	_save = SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)


func after_each() -> void:
	Router.take_payload()
	_clear()
	_reset_input_handled()
	_player = null
	_save = null


func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


## Adds profile `id` (profile_defaults() plus `fields`) to the temp save.
func _add_profile(id: String, fields: Dictionary = {}) -> void:
	var profile: Dictionary = SaveSchema.profile_defaults()
	profile.merge(fields, true)
	_save.get_data()["profiles"][id] = profile


func _make() -> WhosPlayingScript:
	var screen: WhosPlayingScript = WhosPlayingScene.instantiate() as WhosPlayingScript
	screen.navigate = func(target: int, payload: Dictionary) -> void:
		_nav.append([target, payload])
		_transitioning = _starts_transition
	screen.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	screen.play_music = func(id: StringName) -> void: _music.append(id)
	screen.is_transitioning = func() -> bool: return _transitioning
	screen.player_data = _player
	add_child_autofree(screen)
	return screen


func _names(screen: WhosPlayingScript) -> Array[String]:
	var names: Array[String] = []
	for card: ZombieCard in screen.get_cards():
		names.append(card.get_shown_name())
	return names


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


# --- open ------------------------------------------------------------------------

func test_payload_is_consumed_and_music_requested() -> void:
	Router._store_payload({"stale": true})
	_player.set_zombie_name("Sam")
	_make()
	assert_eq(Router.take_payload(), {})
	assert_eq(_music, [&"mus_menu"] as Array[StringName])
	assert_eq(_nav, [])


func test_one_card_per_profile_in_id_order_with_its_own_look() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p10", {"name": "Al"})
	_add_profile("p2", {"name": "Bo", "owned_items": ["hat_pumpkin", "pet_cute_ghost"],
			"equipped": {"hat": "hat_pumpkin", "pet": "pet_cute_ghost"}})
	var screen: WhosPlayingScript = _make()
	assert_eq(_names(screen), ["Sam", "Bo", "Al"] as Array[String])
	var cards: Array[ZombieCard] = screen.get_cards()
	assert_eq(cards[1].get_profile_id(), &"p2")
	assert_eq(cards[1].get_hat_id(), &"hat_pumpkin")
	assert_eq(cards[1].get_pet_id(), &"pet_cute_ghost")
	assert_eq(cards[0].get_hat_id(), &"", "p1 wears nothing")
	assert_eq(cards[2].get_pet_id(), &"")


func test_a_profile_with_no_valid_name_shows_the_default_name() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "!!!"})
	var screen: WhosPlayingScript = _make()
	assert_eq(_names(screen), ["Sam", GameConstants.ZOMBIE_NAME_DEFAULT] as Array[String])


func test_focus_starts_on_the_active_zombie() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo"})
	_add_profile("p3", {"name": "Al"})
	_save.get_data()["active_profile"] = "p2"
	var screen: WhosPlayingScript = _make()
	assert_eq(_focused(), screen.get_cards()[1])


# --- focus -----------------------------------------------------------------------

func test_focus_walks_the_cards_then_new_zombie_and_the_ends_stop() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo"})
	var screen: WhosPlayingScript = _make()
	var cards: Array[ZombieCard] = screen.get_cards()
	var button: Button = screen.get_node("%NewZombieButton")
	assert_true(button.visible)
	assert_eq(cards[0].get_node(cards[0].focus_neighbor_top), cards[0], "top end stops")
	assert_eq(cards[0].get_node(cards[0].focus_previous), cards[0])
	assert_eq(cards[0].get_node(cards[0].focus_neighbor_bottom), cards[1])
	assert_eq(cards[0].get_node(cards[0].focus_next), cards[1])
	assert_eq(cards[1].get_node(cards[1].focus_neighbor_bottom), button)
	assert_eq(cards[1].get_node(cards[1].focus_neighbor_right), button)
	assert_eq(button.get_node(button.focus_neighbor_top), cards[1])
	assert_eq(button.get_node(button.focus_neighbor_bottom), button, "bottom end stops")
	assert_eq(button.get_node(button.focus_next), button)


func test_at_the_cap_new_zombie_is_hidden_and_unreachable() -> void:
	_player.set_zombie_name("Sam")
	for n: int in range(2, GameConstants.MAX_ZOMBIES + 1):
		_add_profile("p%d" % n, {"name": "Z" + "o".repeat(n)})
	var screen: WhosPlayingScript = _make()
	var button: Button = screen.get_node("%NewZombieButton")
	assert_false(button.visible)
	assert_eq(button.focus_mode, Control.FOCUS_NONE)
	var last: ZombieCard = screen.get_cards()[GameConstants.MAX_ZOMBIES - 1]
	assert_eq(last.get_node(last.focus_neighbor_bottom), last, "the last card is the end")
	screen._new_zombie()
	assert_eq(_nav, [], "a stray press does nothing at the cap")


func test_hover_moves_focus_to_a_card() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo"})
	var screen: WhosPlayingScript = _make()
	var card: ZombieCard = screen.get_cards()[1]
	card._gui_input(InputEventMouseMotion.new())
	assert_eq(_focused(), card)


# --- picking ---------------------------------------------------------------------

func test_picking_a_named_zombie_switches_and_goes_to_the_menu_once() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo", "brains": 7})
	var screen: WhosPlayingScript = _make()
	var card: ZombieCard = screen.get_cards()[1]
	card.picked.emit(card.get_profile_id())
	card.picked.emit(card.get_profile_id())
	screen.get_cards()[0].picked.emit(&"p1")
	assert_eq(_player.get_active_profile_id(), &"p2")
	assert_eq(_player.get_brains(), 7)
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_from_the_menu_the_name_screen_gets_the_flag_back() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2")
	Router._store_payload({"from_menu": true})
	var screen: WhosPlayingScript = _make()
	screen.get_cards()[1].picked.emit(&"p2")
	assert_eq(_nav, [[Router.Screen.NAME_ZOMBIE, {"from_menu": true}]], "Review of 11.4: Back must come home with Esc alive")


func test_from_the_menu_new_zombie_carries_the_flag() -> void:
	_player.set_zombie_name("Sam")
	Router._store_payload({"from_menu": true})
	var screen: WhosPlayingScript = _make()
	(screen.get_node("%NewZombieButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.NAME_ZOMBIE, {"new_zombie": true, "from_menu": true}]])


func test_picking_an_unnamed_zombie_goes_to_the_name_screen() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2")
	var screen: WhosPlayingScript = _make()
	screen.get_cards()[1].picked.emit(&"p2")
	assert_eq(_player.get_active_profile_id(), &"p2")
	assert_eq(_nav, [[Router.Screen.NAME_ZOMBIE, {}]])


func test_picking_the_active_zombie_goes_to_the_menu() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	screen.get_cards()[0].picked.emit(&"p1")
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_a_real_click_picks_the_card() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.get_cards()[0]._gui_input(click)
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_the_screen_takes_input_again_when_the_router_never_starts() -> void:
	_player.set_zombie_name("Sam")
	_starts_transition = false
	var screen: WhosPlayingScript = _make()
	screen.get_cards()[0].picked.emit(&"p1")
	screen.get_cards()[0].picked.emit(&"p1")
	assert_eq(_nav.size(), 2, "not left dead after a refused navigation")


func test_the_screen_takes_input_again_after_a_transition_that_left_it_here() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	screen.get_cards()[0].picked.emit(&"p1")
	await wait_process_frames(2)
	screen.get_cards()[0].picked.emit(&"p1")
	assert_eq(_nav.size(), 1, "still transitioning")
	_transitioning = false
	await wait_process_frames(2)
	screen.get_cards()[0].picked.emit(&"p1")
	assert_eq(_nav.size(), 2)


func test_nothing_picks_while_the_router_is_transitioning() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	_transitioning = true
	screen.get_cards()[0].picked.emit(&"p1")
	screen._new_zombie()
	assert_eq(_nav, [])


# --- new zombie ------------------------------------------------------------------

func test_new_zombie_opens_the_name_screen_and_creates_nothing() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	(screen.get_node("%NewZombieButton") as Button).pressed.emit()
	(screen.get_node("%NewZombieButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.NAME_ZOMBIE, {"new_zombie": true}]])
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	assert_eq(_player.get_profile_ids(), [&"p1"] as Array[StringName])
	assert_eq(_player.get_active_profile_id(), &"p1")


# --- esc, rebuild, exit ----------------------------------------------------------

func test_esc_does_nothing() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	assert_eq(_nav, [])
	assert_eq(_sfx, [] as Array[StringName])


func _esc() -> InputEventAction:
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


func test_esc_from_the_menu_goes_back_once_and_switches_nothing() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo"})
	await wait_process_frames(1)  # the name's save is written
	Router._store_payload({"from_menu": true})
	var screen: WhosPlayingScript = _make()
	watch_signals(_player)
	screen._unhandled_input(_esc())
	screen._unhandled_input(_esc())
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]], "Story 11.4: Esc returns to the menu once")
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	assert_eq(_player.get_active_profile_id(), &"p1")
	assert_signal_not_emitted(_player, "profile_replaced")
	assert_false(_save._dirty, "no save requested")


func test_esc_from_the_title_payload_stays_dead() -> void:
	_player.set_zombie_name("Sam")
	Router._store_payload({})
	var screen: WhosPlayingScript = _make()
	screen._unhandled_input(_esc())
	assert_eq(_nav, [])


func test_esc_with_a_junk_from_menu_value_stays_dead() -> void:
	_player.set_zombie_name("Sam")
	for junk: Variant in ["yes", 1, "true", null]:
		Router._store_payload({"from_menu": junk})
		var screen: WhosPlayingScript = _make()
		screen._unhandled_input(_esc())
	assert_eq(_nav, [], "only a real true opens the way back")


func test_esc_from_the_menu_is_ignored_while_the_router_is_transitioning() -> void:
	_player.set_zombie_name("Sam")
	Router._store_payload({"from_menu": true})
	var screen: WhosPlayingScript = _make()
	_transitioning = true
	screen._unhandled_input(_esc())
	assert_eq(_nav, [])


func test_enter_on_the_focused_active_card_from_the_menu_returns_as_the_same_zombie() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo"})
	Router._store_payload({"from_menu": true})
	var screen: WhosPlayingScript = _make()
	watch_signals(_player)
	var focused: ZombieCard = _focused() as ZombieCard
	assert_not_null(focused)
	assert_eq(focused.get_profile_id(), &"p1", "focus starts on the active zombie")
	focused.picked.emit(focused.get_profile_id())
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_signal_not_emitted(_player, "profile_replaced")


func test_cards_rebuild_on_profile_replaced() -> void:
	_player.set_zombie_name("Sam")
	_add_profile("p2", {"name": "Bo"})
	var screen: WhosPlayingScript = _make()
	assert_eq(screen.get_cards().size(), 2)
	_player.reset_all()
	assert_eq(_names(screen), [GameConstants.ZOMBIE_NAME_DEFAULT] as Array[String])
	assert_eq(_focused(), screen.get_cards()[0])


func test_disconnects_from_player_data_on_exit() -> void:
	_player.set_zombie_name("Sam")
	var screen: WhosPlayingScript = _make()
	assert_true(_player.profile_replaced.is_connected(screen._on_profile_replaced))
	remove_child(screen)
	assert_false(_player.profile_replaced.is_connected(screen._on_profile_replaced))
	screen.free()


# --- layout ----------------------------------------------------------------------

func test_full_layout_fits_inside_the_margin_without_overlap() -> void:
	_player.set_zombie_name("W".repeat(GameConstants.ZOMBIE_NAME_MAX_LENGTH))
	for n: int in range(2, GameConstants.MAX_ZOMBIES):
		_add_profile("p%d" % n, {"name": "W".repeat(GameConstants.ZOMBIE_NAME_MAX_LENGTH)})
	var screen: WhosPlayingScript = _make()
	var button: Button = screen.get_node("%NewZombieButton")
	assert_true(button.visible, "one below the cap: the button is still shown")
	var rects: Array[Rect2] = [(screen.get_node("%Sign") as Control).get_global_rect()]
	for card: ZombieCard in screen.get_cards():
		rects.append(card.get_global_rect())
		assert_gte(card.size.y, 32.0)
	rects.append(button.get_global_rect())
	assert_gte(button.size.y, 32.0)
	for i: int in rects.size():
		assert_true(SAFE_RECT.encloses(rects[i]), "rect %d %s inside the margin" % [i, rects[i]])
		for j: int in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "rects %d and %d overlap" % [i, j])
