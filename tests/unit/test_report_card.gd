extends GutTest
## Chalkboard report card (Story 2.9, FR19-FR21): stats, bonus line, "New best!" stamp, heading,
## the 1.0 s mash guard, one navigation, focus, the write-on reveal and Professor Zombie.
## Navigation goes to a recorder through the `navigate` seam, never the live Router. Time is driven by
## calling _process by hand (real processing is switched off). Keys go through the real viewport
## (push_input), so the focused button and _unhandled_input see them in Godot's own order.
## Story 4.5: every card gets a temp-dir PlayerData (never the real save) with welcome_bonus_claimed set,
## so the navigation tests mean the same on any machine; the Welcome Gift redirect tests clear it.

const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")
const ProfessorScene: PackedScene = preload("res://scenes/characters/professor_zombie.tscn")
const ReportScript: GDScript = preload("res://scripts/screens/report_card.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const GUARD: float = GameConstants.REPORT_CARD_INPUT_GUARD_S
const TEST_DIR: String = "user://test_report_card/"
const STATS: Array[String] = ["%KeysValue", "%ErrorsValue", "%WpmValue", "%AccuracyValue", "%TimeValue", "%BrainsValue"]

var _nav: Array = []
var _player: PlayerDataScript


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_player = _make_player_data()
	_player.set_flag(&"welcome_bonus_claimed", true)


func after_each() -> void:
	Router.take_payload()
	_reset_input_handled()
	_clear()
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make_player_data() -> PlayerDataScript:
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	add_child_autofree(player)
	return player


func _record(screen: int, payload: Dictionary) -> void:
	_nav.append([screen, payload])


## The mock's example run: 142 keys, 9 errors, 2:00, 35 brains (+ bonus).
func _result(bonus: int = 0, level_id: StringName = &"test_level") -> RunResult:
	return RunResult.create(
			level_id, 1790000000, 120.0, 142, 9, {}, 35, bonus, "all", GameConstants.END_REASON_TIMER)


func _card(payload: Dictionary, registry: bool = true) -> Control:
	Router._store_payload(payload)
	var card: Control = ReportScene.instantiate() as Control
	card.set("navigate", _record)
	card.set("player_data", _player)
	if not registry:
		card.set("level_registry", null)
	add_child_autofree(card)
	card.set_process(false)
	return card


func _text(card: Control, path: String) -> String:
	return (card.get_node(path) as Label).text


func _shown(card: Control, path: String) -> bool:
	return (card.get_node(path) as CanvasItem).is_visible_in_tree()


func _key(keycode: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


## Press and release through the real viewport: _input -> focused GUI control -> _unhandled_input.
func _tap(keycode: Key) -> void:
	get_viewport().push_input(_key(keycode, true))
	get_viewport().push_input(_key(keycode, false))


func _click(pressed: bool = true) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


# --- Stats ------------------------------------------------------------------------------------------

func test_mock_example_values() -> void:
	var card: Control = _card({"result": _result(10), "new_best": true})
	var values: Array[String] = []
	for path: String in STATS:
		values.append(_text(card, path))
	assert_eq(values, ["142", "9", "14", "94%", "2:00", "45"] as Array[String])
	assert_eq(_text(card, "%BonusLabel"), "+10 bonus")


func test_labels_use_the_plain_words() -> void:
	var card: Control = _card({"result": _result()})
	var words: Array[String] = []
	for i: int in 6:
		words.append((card.get_node("%%Row%d/Label" % i) as Label).text)
	assert_eq(words, ["Keys Typed", "Errors", "WPM", "Accuracy", "Lesson Time", "Brains Collected"] as Array[String])
	# Story 5.0: "New best!" is the hand-lettered stamp sprite.
	assert_eq((card.get_node("%Stamp") as TextureRect).texture.resource_path,
			"res://assets/sprites/ui/report_card/ui_new_best.png")
	assert_eq((card.get_node("%PlayAgainButton") as Button).text, "Play Again")
	assert_eq((card.get_node("%MenuButton") as Button).text, "Menu")
	assert_eq(_text(card, "%EnterHint"), "Enter")
	assert_eq(_text(card, "%EscHint"), "Esc")


func test_bonus_line_shown_after_reveal_when_bonus() -> void:
	var card: Control = _card({"result": _result(10)})
	card._process(GUARD)
	assert_true(_shown(card, "%BonusLabel"))


func test_bonus_zero_hides_bonus_line() -> void:
	var card: Control = _card({"result": _result(0)})
	card._process(GUARD)
	assert_true(_shown(card, "%BrainsValue"), "stats shown")
	assert_false(_shown(card, "%BonusLabel"), "no bonus line")
	assert_eq(_text(card, "%BrainsValue"), "35")


# --- Stamp ------------------------------------------------------------------------------------------

func test_stamp_when_new_best() -> void:
	var card: Control = _card({"result": _result(), "new_best": true})
	card._process(GUARD)
	assert_true(_shown(card, "%Stamp"))


func test_no_stamp_when_not_new_best_missing_or_not_bool() -> void:
	for payload: Dictionary in [
			{"result": _result(), "new_best": false},
			{"result": _result()},
			{"result": _result(), "new_best": 1},
			{"result": _result(), "new_best": "true"}]:
		var card: Control = _card(payload)
		card._process(GUARD)
		assert_false(_shown(card, "%Stamp"), str(payload.get("new_best", "missing")))


func test_stamp_clear_of_heading_and_rows() -> void:
	var card: Control = _card({"result": _result(10), "new_best": true})
	card._process(GUARD)
	var stamp: Rect2 = (card.get_node("%Stamp") as Control).get_global_rect()
	var heading: Label = card.get_node("%Heading")
	var font: Font = heading.get_theme_font(&"font")
	var width: float = font.get_string_size(
			heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, heading.get_theme_font_size(&"font_size")).x
	var text_rect: Rect2 = Rect2(heading.global_position, Vector2(width, heading.size.y))
	assert_false(stamp.intersects(text_rect), "stamp %s over heading %s" % [stamp, text_rect])
	for i: int in 7:
		var row: Rect2 = (card.get_node("%%Row%d" % i) as Control).get_global_rect()
		assert_false(stamp.intersects(row), "stamp over row %d" % i)


# --- Heading ----------------------------------------------------------------------------------------

func test_heading_from_registry() -> void:
	assert_eq(_text(_card({"result": _result()}), "%Heading"), "Test level")


func test_heading_capitalizes_unregistered_id() -> void:
	assert_eq(_text(_card({"result": _result(0, &"pitchfork_panic")}), "%Heading"), "Pitchfork Panic")


func test_heading_without_registry_still_shows() -> void:
	assert_eq(_text(_card({"result": _result()}, false), "%Heading"), "Test Level")


# --- Robust payload ---------------------------------------------------------------------------------

func test_payload_consumed() -> void:
	_card({"result": _result()})
	assert_eq(Router.take_payload(), {})


func test_no_result_warns_and_shows_zeros() -> void:
	var card: Control = _card({"result": "not a result", "new_best": true})
	assert_push_warning("report card opened without a RunResult")
	var values: Array[String] = []
	for path: String in STATS:
		values.append(_text(card, path))
	assert_eq(values, ["0", "0", "0", "0%", "0:00", "0"] as Array[String])
	assert_eq(_text(card, "%Heading"), "Report Card")
	card._process(GUARD)
	assert_false(_shown(card, "%BonusLabel"), "no bonus line")
	assert_false(_shown(card, "%Stamp"), "no result, no stamp")
	_tap(KEY_ENTER)
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"zombie_run"}]], "Play Again uses the fallback level")


func test_empty_payload_never_crashes() -> void:
	var card: Control = _card({})
	assert_push_warning("report card opened without a RunResult")
	card._process(GUARD)
	assert_false(_shown(card, "%Stamp"))


# --- Focus and buttons ------------------------------------------------------------------------------

func test_play_again_focused_on_open() -> void:
	var card: Control = _card({"result": _result()})
	assert_eq(get_viewport().gui_get_focus_owner(), card.get_node("%PlayAgainButton"))


func test_focus_neighbours_keep_focus_on_the_two_buttons() -> void:
	var card: Control = _card({"result": _result()})
	var play: Button = card.get_node("%PlayAgainButton")
	var menu: Button = card.get_node("%MenuButton")
	for side: Side in [SIDE_LEFT, SIDE_RIGHT]:
		assert_eq(play.get_node(play.get_focus_neighbor(side)), menu, "play side %d" % side)
		assert_eq(menu.get_node(menu.get_focus_neighbor(side)), play, "menu side %d" % side)
	for side: Side in [SIDE_TOP, SIDE_BOTTOM]:
		assert_eq(play.get_node(play.get_focus_neighbor(side)), play)
		assert_eq(menu.get_node(menu.get_focus_neighbor(side)), menu)


func test_right_arrow_moves_focus_after_guard_and_enter_picks_menu() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	_tap(KEY_RIGHT)
	assert_eq(get_viewport().gui_get_focus_owner(), card.get_node("%MenuButton"))
	_tap(KEY_ENTER)
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


## Story 5.0: the buttons are PixelButtons, so the focused one shows the theme's pumpkin-light fill (and ink
## text), the other the wood plank; the look is unchanged from 2.9.
func test_focused_button_gets_the_focus_fill() -> void:
	var card: Control = _card({"result": _result()})
	var play: Button = card.get_node("%PlayAgainButton")
	var menu: Button = card.get_node("%MenuButton")
	assert_true(play is PixelButton)
	assert_true(menu is PixelButton)
	var focused: StyleBox = play.get_theme_stylebox(&"normal_focused")
	assert_eq(play.get_theme_stylebox(&"normal"), focused)
	assert_ne(menu.get_theme_stylebox(&"normal"), focused)
	menu.grab_focus()
	assert_ne(play.get_theme_stylebox(&"normal"), focused)
	assert_eq(menu.get_theme_stylebox(&"normal"), focused)
	assert_eq(menu.get_theme_color(&"font_focus_color"), Color("#1E1428"), "ink text when focused")
	assert_eq(play.get_theme_color(&"font_color"), Color("#F4F1E4"), "chalk text at rest")


func test_decor_never_takes_mouse_or_focus() -> void:
	var card: Control = _card({"result": _result()})
	for path: String in ["Backdrop", "Board", "%Stamp", "%EnterHint", "%EscHint", "%Heading"]:
		var node: Control = card.get_node(path)
		assert_eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, path)
		assert_eq(node.focus_mode, Control.FOCUS_NONE, path)


# --- Mash guard and the one exit --------------------------------------------------------------------

func test_enter_blocked_before_guard_then_plays_again() -> void:
	var card: Control = _card({"result": _result()})
	card._process(0.99)
	_tap(KEY_ENTER)
	assert_eq(_nav, [], "0.99 s: nothing")
	card._process(0.01)
	_tap(KEY_ENTER)
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"test_level"}]])


func test_esc_blocked_before_guard_then_menu() -> void:
	var card: Control = _card({"result": _result()})
	card._process(0.99)
	_tap(KEY_ESCAPE)
	assert_eq(_nav, [], "0.99 s: nothing")
	card._process(0.01)
	_tap(KEY_ESCAPE)
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_space_blocked_before_guard() -> void:
	var card: Control = _card({"result": _result()})
	card._process(0.99)
	_tap(KEY_SPACE)
	assert_eq(_nav, [])


func test_click_handled_during_guard_only() -> void:
	var card: Control = _card({"result": _result()})
	card._process(0.99)
	card._input(_click())
	assert_true(get_viewport().is_input_handled(), "click swallowed at 0.99 s")
	_reset_input_handled()
	card._process(0.01)
	card._input(_click())
	assert_false(get_viewport().is_input_handled(), "click reaches the button at 1.0 s")


func test_button_pressed_blocked_before_guard() -> void:
	var card: Control = _card({"result": _result()})
	card._process(0.99)
	(card.get_node("%PlayAgainButton") as Button).pressed.emit()
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [])
	card._process(0.01)
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_play_again_button_payload() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	(card.get_node("%PlayAgainButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"test_level"}]], "no seed: a fresh letter bag")


func test_echo_enter_ignored_after_guard() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	card._input(_key(KEY_ENTER, true, true))
	assert_true(get_viewport().is_input_handled(), "echo swallowed")
	_reset_input_handled()
	get_viewport().push_input(_key(KEY_ENTER, true, true))
	assert_true(get_viewport().is_input_handled(), "echo swallowed through the real viewport")
	assert_eq(_nav, [])


func test_only_one_navigation() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	_tap(KEY_ENTER)
	_tap(KEY_ESCAPE)
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"test_level"}]])


func test_presses_swallowed_after_leaving() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	(card.get_node("%MenuButton") as Button).pressed.emit()
	card._input(_click())
	assert_true(get_viewport().is_input_handled())


func test_enter_without_focus_still_plays_again() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	get_viewport().gui_release_focus()
	_tap(KEY_ENTER)
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"test_level"}]])


# --- Welcome Gift redirect (Story 4.5) ----------------------------------------------------------------

## A card with a result on a save whose gift is unclaimed, past the guard.
func _first_run_card() -> Control:
	_player.set_flag(&"welcome_bonus_claimed", false)
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	return card


func test_first_run_play_again_goes_to_the_gift() -> void:
	var card: Control = _first_run_card()
	(card.get_node("%PlayAgainButton") as Button).pressed.emit()
	(card.get_node("%PlayAgainButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]])


func test_first_run_menu_goes_to_the_gift() -> void:
	var card: Control = _first_run_card()
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]])


func test_first_run_esc_goes_to_the_gift() -> void:
	_first_run_card()
	_tap(KEY_ESCAPE)
	_tap(KEY_ESCAPE)
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]])


func test_first_run_enter_without_focus_goes_to_the_gift() -> void:
	_first_run_card()
	get_viewport().gui_release_focus()
	_tap(KEY_ENTER)
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]])


func test_no_result_never_spends_the_gift() -> void:
	_player.set_flag(&"welcome_bonus_claimed", false)
	var card: Control = _card({})
	assert_push_warning("report card opened without a RunResult")
	card._process(GUARD)
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_claimed_gift_goes_where_asked() -> void:
	var card: Control = _card({"result": _result()})
	card._process(GUARD)
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])


func test_the_guard_still_blocks_the_redirect() -> void:
	_player.set_flag(&"welcome_bonus_claimed", false)
	var card: Control = _card({"result": _result()})
	card._process(GUARD - 0.01)
	_tap(KEY_ENTER)
	(card.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [])


func test_the_flag_is_read_at_leave_time() -> void:
	var card: Control = _card({"result": _result()})
	_player.set_flag(&"welcome_bonus_claimed", false)
	card._process(GUARD)
	_tap(KEY_ENTER)
	assert_eq(_nav, [[Router.Screen.WELCOME_GIFT, {}]])


func test_the_card_never_sets_the_flag() -> void:
	var card: Control = _first_run_card()
	watch_signals(_player)
	_tap(KEY_ENTER)
	assert_false(_player.get_flag(&"welcome_bonus_claimed"))
	assert_signal_not_emitted(_player, "flags_changed")
	assert_not_null(card)


# --- Write-on reveal --------------------------------------------------------------------------------

func test_reveal_rows_in_order_then_stamp() -> void:
	var card: Control = _card({"result": _result(10), "new_best": true})
	var step: float = ReportScript.REVEAL_STEP_S
	for i: int in 7:
		assert_false(_shown(card, "%%Row%d" % i), "row %d hidden on open" % i)
	assert_false(_shown(card, "%Stamp"), "stamp hidden on open")
	card._process(step * 3.5)
	for i: int in 7:
		assert_eq(_shown(card, "%%Row%d" % i), i <= 3, "row %d at 3.5 steps" % i)
	assert_false(_shown(card, "%Stamp"), "stamp after the rows")
	card._process(step * 3.0)
	assert_true(_shown(card, "%Row6"), "bonus row by 6.5 steps")
	assert_false(_shown(card, "%Stamp"), "stamp still waits")
	var fresh: Control = _card({"result": _result(10), "new_best": true})
	fresh._process(step * 7)
	for i: int in 7:
		assert_true(_shown(fresh, "%%Row%d" % i), "row %d by 7 steps" % i)
	assert_true(_shown(fresh, "%Stamp"), "stamp by 7 steps")


func test_processing_stops_after_reveal_and_guard() -> void:
	var card: Control = _card({"result": _result(), "new_best": true})
	card.set_process(true)
	card._process(GUARD * 0.5)
	assert_true(card.is_processing(), "guard still on")
	card._process(GUARD * 0.5)
	assert_false(card.is_processing())


# --- Readability ------------------------------------------------------------------------------------

func test_every_text_at_least_16_px() -> void:
	var card: Control = _card({"result": _result(10), "new_best": true})
	var checked: int = 0
	for node: Node in card.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			var size: int = (node as Control).get_theme_font_size(&"font_size")
			assert_true(size >= 16, "%s font %d" % [node.name, size])
			checked += 1
	# 18 since Story 5.0: "New best!" is a hand-lettered sprite, no longer a Label.
	assert_eq(checked, 18, "checked %d texts" % checked)


# --- Professor Zombie -------------------------------------------------------------------------------

## Story 4.3: the slots are a HatSlot (following the professor's anchors) and a PetSlot. They follow the
## live PlayerData, so the shown hat is set by hand here (show_item) rather than asserted empty.
func test_professor_points_at_1x_with_cosmetic_slots() -> void:
	var card: Control = _card({"result": _result()})
	var professor: Node2D = card.get_node("%Professor")
	assert_eq(professor.scale, Vector2.ONE)
	var body: AnimatedSprite2D = professor.get_node("Body")
	assert_eq(body.scale, Vector2.ONE)
	assert_eq(body.sprite_frames.get_frame_count(&"point"), 2)
	assert_eq(body.sprite_frames.get_animation_speed(&"point"), 8.0)
	assert_eq(body.animation, &"point")
	var hat: HatSlot = professor.get_node("%HatSlot") as HatSlot
	assert_not_null(hat, "%HatSlot is a HatSlot")
	assert_true(professor.get_node("%PetSlot") is PetSlot, "%PetSlot is a PetSlot")
	assert_eq(hat.sprite, body)
	assert_eq(hat.anchors, load("res://data/anchors/professor_anchors.tres"))
	assert_eq(hat.position, Vector2(16, 5), "on the crown")
	var mortarboard: Sprite2D = body.get_node("Mortarboard")
	assert_true(mortarboard.get_index() > hat.get_index(), "mortarboard drawn over the hat")
	hat.show_item(null)
	assert_eq(mortarboard.position.y, 0.0, "no hat: the mortarboard sits on the crown")


## D16: with a hat on, the mortarboard rises by how far the hat reaches above the head point.
func test_mortarboard_stacks_on_the_hat() -> void:
	var card: Control = _card({"result": _result()})
	var professor: Node2D = card.get_node("%Professor")
	var hat: HatSlot = professor.get_node("%HatSlot") as HatSlot
	var mortarboard: Sprite2D = professor.get_node("Body/Mortarboard")
	var pumpkin: CosmeticItem = load("res://data/cosmetics/hat_pumpkin.tres") as CosmeticItem
	hat.show_item(pumpkin)
	var top: int = pumpkin.overlay.get_image().get_used_rect().position.y
	assert_eq(top, 19, "the pumpkin's top row")
	assert_eq(mortarboard.position.y, -(HatSlot.SEAT.y - top), "lifted by the hat's rise")
	assert_eq(mortarboard.position.y, -11.0)
	hat.show_item(null)
	assert_eq(mortarboard.position.y, 0.0)
	# A lifted mortarboard (top row 1) stays clear of the board's heading and the stamp: it tops out
	# around y 258.
	hat.show_item(pumpkin)
	assert_almost_eq(mortarboard.global_position.y + 1.0, 260.0, 2.0)


func test_pet_stands_clear_of_the_board_stamp_and_buttons() -> void:
	var card: Control = _card({"result": _result()})
	var pet: Node2D = card.get_node("%Professor").get_node("%PetSlot")
	var feet: Vector2 = pet.global_position
	var pet_rect: Rect2 = Rect2(feet + Vector2(-16, -31), Vector2(32, 32))
	assert_eq(feet.y, 300.0, "on the floor with the professor's soles")
	for path: String in ["Board", "Stamp", "%PlayAgainButton", "%MenuButton"]:
		var rect: Rect2 = (card.get_node(path) as Control).get_global_rect()
		assert_false(pet_rect.intersects(rect), "pet clear of %s" % path)
	assert_true(pet_rect.end.x <= 640.0, "on screen")


func test_professor_stands_on_the_floor_and_reaches_the_board() -> void:
	var card: Control = _card({"result": _result()})
	var professor: Node2D = card.get_node("%Professor")
	var board: Rect2 = (card.get_node("Board") as Control).get_global_rect()
	# Soles on the sheet's row 30; the pointer tip in column 1.
	assert_eq(professor.global_position.y + 30.0, 300.0, "soles 4 px into the floor band")
	assert_true(professor.global_position.x + 1.0 <= board.end.x, "pointer tip reaches the board frame")


func test_professor_without_frames_hides_body() -> void:
	var professor: Node2D = ProfessorScene.instantiate() as Node2D
	(professor.get_node("Body") as AnimatedSprite2D).sprite_frames = null
	add_child_autofree(professor)
	assert_push_warning("professor zombie has no sprite frames")
	assert_false((professor.get_node("Body") as CanvasItem).visible)
