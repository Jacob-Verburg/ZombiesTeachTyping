extends GutTest
## The Welcome Gift card (Story 4.5, FR44): the grant on show (once, one save, from the economy), the
## already-claimed and no-economy paths, the one button to the Closet with the tutorial payload, the mash
## guard, Esc, and the layout (text fit, 16 px, the margin, the rects).
## Every seam is injected: a temp-dir PlayerData with a counting SaveService, recorder navigate and sfx.
## The real save, Router and AudioManager are never touched. Time is driven by calling _process by hand.

const GiftScene: PackedScene = preload("res://scenes/screens/welcome_gift.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const SHIPPED_ECONOMY: EconomyConfig = preload("res://data/economy.tres")
const TEST_DIR: String = "user://test_welcome_gift/"
const SAFE_RECT: Rect2 = Rect2(16, 16, 608, 328)
const GUARD: float = 0.5

## A SaveService that counts request_save() calls and the writes they coalesce into.
class CountingSave extends SaveServiceScript:
	var requests: int = 0
	var writes: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()

	func save_now() -> Error:
		writes += 1
		return super.save_now()


var _player: PlayerDataScript
var _save: CountingSave
var _nav: Array = []
var _sfx: Array[StringName] = []
## play_music recorder (Story 5.1).
var _music: Array[StringName] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_sfx = []
	_music = []
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)


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


## A disabled gift with every seam injected. `swap_economy` replaces the shipped economy with `economy`.
func _gift(economy: EconomyConfig = null, swap_economy: bool = false) -> Control:
	var gift: Control = GiftScene.instantiate() as Control
	gift.process_mode = Node.PROCESS_MODE_DISABLED
	gift.set("navigate", func(screen: int, payload: Dictionary) -> void: _nav.append([screen, payload]))
	gift.set("play_sfx", func(id: StringName) -> void: _sfx.append(id))
	gift.set("play_music", func(id: StringName) -> void: _music.append(id))
	gift.set("player_data", _player)
	if swap_economy:
		gift.set("economy", economy)
	add_child_autofree(gift)
	return gift


func _key(keycode: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func _action(action: StringName) -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _click() -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


func _button(gift: Control) -> Button:
	return gift.get_node("%OpenClosetButton") as Button


# --- The grant -----------------------------------------------------------------------------------------

func test_fresh_save_grants_the_bonus_once_with_one_save() -> void:
	watch_signals(_player)
	var before: int = _save.writes
	_gift()
	assert_eq(_player.get_brains(), SHIPPED_ECONOMY.welcome_bonus)
	assert_eq(_player.get_brains(), 100)
	assert_true(_player.get_flag(&"welcome_bonus_claimed"))
	assert_signal_emit_count(_player, "brains_changed", 1)
	assert_signal_emitted_with_parameters(_player, "brains_changed", [100, 100])
	assert_signal_emit_count(_player, "flags_changed", 1)
	assert_eq(_save.writes - before, 0, "nothing written mid-frame")
	await wait_process_frames(2)
	assert_eq(_save.writes - before, 1, "the grant and the flag land in one write")
	var reloaded: SaveServiceScript = SaveServiceScript.new()
	reloaded.save_dir = TEST_DIR
	add_child_autofree(reloaded)
	var again: PlayerDataScript = PlayerDataScript.new()
	again.save_service = reloaded
	add_child_autofree(again)
	assert_eq(again.get_brains(), 100, "a reload sees the brains")
	assert_true(again.get_flag(&"welcome_bonus_claimed"), "and the flag")


func test_grant_adds_to_the_run_brains() -> void:
	_player.add_brains(35)
	_gift()
	assert_eq(_player.get_brains(), 135)


func test_already_claimed_grants_nothing_but_still_shows() -> void:
	_player.set_flag(&"welcome_bonus_claimed", true)
	watch_signals(_player)
	var gift: Control = _gift()
	assert_eq(_player.get_brains(), 0)
	assert_signal_not_emitted(_player, "brains_changed")
	assert_eq((gift.get_node("%AmountLabel") as Label).text, "+100", "the card reads the same")
	assert_true(_button(gift).has_focus())
	gift._process(GUARD)
	_button(gift).pressed.emit()
	assert_eq(_nav, [[Router.Screen.CRYPT_CLOSET, {"tutorial": true}]])


func test_a_second_gift_never_grants_twice() -> void:
	_gift()
	_gift()
	assert_eq(_player.get_brains(), 100)


func test_no_economy_logs_grants_nothing_claims_and_the_button_still_works() -> void:
	var gift: Control = _gift(null, true)
	assert_push_error("welcome gift: no economy")
	assert_eq(_player.get_brains(), 0)
	assert_true(_player.get_flag(&"welcome_bonus_claimed"), "claimed anyway, so the report card never loops back here")
	gift._process(GUARD)
	_button(gift).pressed.emit()
	assert_eq(_nav, [[Router.Screen.CRYPT_CLOSET, {"tutorial": true}]])


func test_amount_comes_from_the_economy() -> void:
	var economy: EconomyConfig = EconomyConfig.new()
	economy.welcome_bonus = 7
	var gift: Control = _gift(economy, true)
	assert_eq((gift.get_node("%AmountLabel") as Label).text, "+7")
	assert_eq(_player.get_brains(), 7)


func test_payload_consumed() -> void:
	Router._store_payload({"stale": true})
	_gift()
	assert_eq(Router.take_payload(), {})


# --- The button, the guard, Esc ------------------------------------------------------------------------

func test_the_button_is_focused_on_open() -> void:
	var gift: Control = _gift()
	assert_eq(get_viewport().gui_get_focus_owner(), _button(gift))
	assert_eq(_button(gift).text, "Open the Crypt Closet")
	assert_true(_button(gift) is PixelButton)


func test_presses_before_the_guard_do_nothing() -> void:
	var gift: Control = _gift()
	gift._process(GUARD - 0.01)
	_button(gift).pressed.emit()
	gift._input(_key(KEY_ENTER))
	assert_true(get_viewport().is_input_handled(), "Enter swallowed during the guard")
	_reset_input_handled()
	gift._input(_click())
	assert_true(get_viewport().is_input_handled(), "click swallowed during the guard")
	_reset_input_handled()
	assert_eq(_nav, [])
	assert_eq(_sfx, [] as Array[StringName])


func test_after_the_guard_the_button_opens_the_closet_once() -> void:
	var gift: Control = _gift()
	gift._process(GUARD)
	gift._input(_key(KEY_ENTER))
	assert_false(get_viewport().is_input_handled(), "Enter reaches the button after the guard")
	_button(gift).pressed.emit()
	_button(gift).pressed.emit()
	assert_eq(_nav, [[Router.Screen.CRYPT_CLOSET, {"tutorial": true}]])
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	gift._input(_click())
	assert_true(get_viewport().is_input_handled(), "presses swallowed after leaving")


func test_echo_is_swallowed() -> void:
	var gift: Control = _gift()
	gift._process(GUARD)
	gift._input(_key(KEY_ENTER, true, true))
	assert_true(get_viewport().is_input_handled())


func test_enter_without_focus_opens_the_closet() -> void:
	var gift: Control = _gift()
	gift._process(GUARD)
	get_viewport().gui_release_focus()
	gift._unhandled_input(_action(&"ui_accept"))
	assert_eq(_nav, [[Router.Screen.CRYPT_CLOSET, {"tutorial": true}]])


func test_esc_does_nothing_and_is_handled() -> void:
	var gift: Control = _gift()
	gift._process(GUARD)
	gift._unhandled_input(_action(&"ui_cancel"))
	assert_true(get_viewport().is_input_handled())
	assert_eq(_nav, [])
	assert_eq(_sfx, [] as Array[StringName])


# --- Layout (Dev Notes "Welcome Gift layout") ----------------------------------------------------------

func test_rects_match_the_layout_table() -> void:
	var gift: Control = _gift()
	await wait_process_frames(2)
	var expected: Dictionary[String, Rect2] = {
		"%Background": Rect2(0, 0, 640, 360),
		"%Panel": Rect2(120, 52, 400, 240),
		"%Ribbon": Rect2(308, 52, 24, 240),
		"%Bow": Rect2(296, 36, 48, 20),
		"%Sign": Rect2(156, 68, 328, 40),
		"%Heading": Rect2(164, 76, 312, 24),
		"%BrainIcon": Rect2(236, 140, 32, 32),
		"%AmountLabel": Rect2(276, 140, 128, 32),
		"%OpenClosetButton": Rect2(144, 236, 352, 32),
	}
	for path: String in expected:
		assert_eq((gift.get_node(path) as Control).get_global_rect(), expected[path], path)


func test_draw_order_puts_the_ribbon_behind_the_words() -> void:
	var gift: Control = _gift()
	var ribbon: int = gift.get_node("%Ribbon").get_index()
	for path: String in ["%Sign", "%BrainIcon", "%AmountLabel", "%OpenClosetButton"]:
		assert_gt(gift.get_node(path).get_index(), ribbon, path)
	assert_gt(ribbon, gift.get_node("%Panel").get_index())


func test_every_control_is_inside_the_margin() -> void:
	var gift: Control = _gift()
	await wait_process_frames(2)
	var checked: int = 0
	for node: Node in gift.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.name == &"Background":
			continue
		assert_true(SAFE_RECT.encloses(control.get_global_rect()), "%s %s outside the margin" % [control.name, control.get_global_rect()])
		checked += 1
	assert_gt(checked, 7)


func test_decor_never_takes_focus_or_the_mouse() -> void:
	var gift: Control = _gift()
	for path: String in ["%Background", "%Panel", "%Ribbon", "%Bow", "%Sign", "%Heading", "%BrainIcon", "%AmountLabel"]:
		var control: Control = gift.get_node(path) as Control
		assert_eq(control.focus_mode, Control.FOCUS_NONE, path)
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, path)


func test_plain_words_fit_at_16px_or_more() -> void:
	var gift: Control = _gift()
	await wait_process_frames(2)
	assert_eq((gift.get_node("%Heading") as Label).text, "Welcome gift!")
	assert_eq((gift.get_node("%Heading") as Label).get_theme_font_size(&"font_size"), 24)
	_assert_label_fits(gift.get_node("%Heading") as Label)
	var amount: Label = gift.get_node("%AmountLabel") as Label
	_assert_label_fits(amount)
	amount.text = "+999"
	_assert_label_fits(amount)
	var button: Button = _button(gift)
	assert_gte(button.get_theme_font_size(&"font_size"), 16)
	assert_lte(button.get_minimum_size().x, button.size.x, "button text overflows")


func _assert_label_fits(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	assert_gte(font_size, 16, "%s font size" % label.name)
	var text_size: Vector2 = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	assert_lte(text_size.x, label.size.x, "%s '%s' overflows" % [label.name, label.text])
	assert_lte(float(font_size), label.size.y, "%s too short for its font" % label.name)


# --- Sounds (Story 5.1) --------------------------------------------------------------------------------

func test_opening_asks_for_the_menu_loop() -> void:
	_gift()
	assert_eq(_music, [&"mus_menu"] as Array[StringName])
