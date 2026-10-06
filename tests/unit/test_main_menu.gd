extends GutTest
## The main menu (Story 4.2): cards from the registry, focus wiring, navigation through the navigate seam,
## the wallet and toggles from an injected PlayerData on a temp save, the fullscreen seams, Esc, text fit and
## the 16 px margin. Kept from Stories 1.7 / 1.8: the FR27 storage notice and the Ctrl+Shift+E chord.
## Disabled instances: no real input reaches them, so handlers and _gui_input are called directly.
## The live Router, window and save are never touched (navigate recorder, fake fullscreen, temp SaveService).

const MenuScene: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const MainMenuScript := preload("res://scripts/screens/main_menu.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_main_menu/"
## The 16 px margin every control stays inside (640 x 360 canvas).
const SAFE_RECT: Rect2 = Rect2(16, 16, 608, 328)
const CANVAS_RECT: Rect2 = Rect2(0, 0, 640, 360)

var _menu: MainMenuScript
var _player: PlayerDataScript
var _nav: Array = []
var _transitioning: bool = false
var _fullscreen: bool = false
var _toggles: int = 0


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_transitioning = false
	_fullscreen = false
	_toggles = 0
	_player = _make_player_data()


func after_each() -> void:
	Router.take_payload()
	_clear()
	_menu = null
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


## A disabled menu with every seam injected. `registry` null = the shipped one from the scene.
func _make(registry: LevelRegistry = null, use_registry: bool = false) -> MainMenuScript:
	var menu: MainMenuScript = MenuScene.instantiate() as MainMenuScript
	menu.process_mode = Node.PROCESS_MODE_DISABLED
	menu.navigate = func(screen: int, payload: Dictionary) -> void: _nav.append([screen, payload])
	menu.is_transitioning = func() -> bool: return _transitioning
	menu.player_data = _player
	# The cosmetic slots listen to PlayerData themselves; point them at the temp save too.
	(menu.get_node("%PetSlot") as PetSlot).player_data = _player
	(menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot).player_data = _player
	menu.toggle_fullscreen = func() -> void:
		_toggles += 1
		_fullscreen = not _fullscreen
	menu.is_fullscreen = func() -> bool: return _fullscreen
	if use_registry:
		menu.level_registry = registry
	add_child_autofree(menu)
	_menu = menu
	return menu


func _entry(id: StringName, available: bool, debug_only: bool = false) -> LevelEntry:
	var entry: LevelEntry = LevelEntry.new()
	entry.id = id
	entry.display_name = String(id).capitalize()
	entry.available = available
	entry.scene = PackedScene.new()
	entry.debug_only = debug_only
	return entry


func _registry(entries: Array[LevelEntry]) -> LevelRegistry:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = entries
	return registry


func _cards() -> Array[LevelCard]:
	return _menu.get_cards()


func _node(path: String) -> Control:
	return _menu.get_node(path) as Control


func _target(toggle_path: String) -> Button:
	return (_menu.get_node(toggle_path) as MenuToggle).get_focus_target()


func _neighbor(from: Control, side: Side) -> Node:
	return from.get_node_or_null(from.get_focus_neighbor(side))


# --- Cards ---------------------------------------------------------------------------------------------

func test_shipped_registry_gives_three_cards_in_order() -> void:
	_make()
	var ids: Array[StringName] = []
	var states: Array[LevelCard.State] = []
	for card: LevelCard in _cards():
		ids.append(card.get_level_id())
		states.append(card.get_state())
	assert_eq(ids, [&"zombie_run", &"horde_rush", &"pitchfork_panic"] as Array[StringName])
	assert_eq(states, [LevelCard.State.AVAILABLE, LevelCard.State.COMING_SOON, LevelCard.State.COMING_SOON]
			as Array[LevelCard.State])
	assert_eq(_node("%Cards").get_child_count(), 3, "no test_level card")


func test_initial_focus_is_the_zombie_run_card() -> void:
	_make()
	assert_true(_cards()[0].has_focus())


func test_debug_only_entries_never_get_a_card() -> void:
	_make(_registry([_entry(&"dbg", true, true), _entry(&"a", true)]), true)
	assert_eq(_cards().size(), 1)
	assert_eq(_cards()[0].get_level_id(), &"a")


func test_no_registry_logs_and_focuses_the_closet() -> void:
	_make(null, true)
	assert_push_error("main menu: no level registry")
	assert_eq(_cards().size(), 0)
	assert_true(_node("%ClosetButton").has_focus())


func test_no_menu_levels_logs_and_focuses_the_closet() -> void:
	_make(_registry([_entry(&"dbg", true, true)]), true)
	assert_push_error("main menu: no menu levels")
	assert_eq(_cards().size(), 0)
	assert_true(_node("%ClosetButton").has_focus())


func test_first_available_card_gets_focus_when_not_first() -> void:
	_make(_registry([_entry(&"a", false), _entry(&"b", true)]), true)
	assert_true(_cards()[1].has_focus())


func test_choosing_the_available_card_runs_it_once() -> void:
	_make()
	_cards()[0]._activate()
	assert_eq(_nav, [[Router.Screen.RUN, {"level_id": &"zombie_run"}]])
	_cards()[0]._activate()
	_menu.call("_on_closet_button_pressed")
	assert_eq(_nav.size(), 1, "the _leaving guard: one navigation per menu")


func test_leaving_is_released_when_the_transition_ends_without_freeing_the_menu() -> void:
	_make()
	_transitioning = false
	_menu.navigate = func(screen: int, payload: Dictionary) -> void:
		_nav.append([screen, payload])
		_transitioning = true
	_cards()[0]._activate()
	assert_eq(_nav.size(), 1)
	_transitioning = false
	await wait_process_frames(2)
	_cards()[0]._activate()
	assert_eq(_nav.size(), 2, "a failed swap leaves the menu usable")


func test_a_click_during_a_router_transition_is_ignored() -> void:
	_make()
	_transitioning = true
	_cards()[0]._activate()
	assert_eq(_nav.size(), 0)


func test_available_entry_without_a_scene_shows_coming_soon() -> void:
	var broken: LevelEntry = _entry(&"a", true)
	broken.scene = null
	_make(_registry([broken, _entry(&"b", true)]), true)
	assert_push_error("available but has no scene or id")
	assert_eq(_cards()[0].get_state(), LevelCard.State.COMING_SOON)
	assert_eq(_cards()[1].get_state(), LevelCard.State.AVAILABLE)
	assert_eq(broken.available, true, "the registry entry itself is untouched")


func test_choosing_a_coming_soon_card_goes_nowhere() -> void:
	_make()
	_cards()[1]._activate()
	_cards()[2]._activate()
	assert_eq(_nav, [])
	assert_true(_cards()[1].is_wiggling())


func test_closet_button_opens_the_closet() -> void:
	_make()
	(_node("%ClosetButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.CRYPT_CLOSET, {}]])


# --- Focus ---------------------------------------------------------------------------------------------

func test_card_row_neighbours() -> void:
	_make()
	var cards: Array[LevelCard] = _cards()
	var closet: Control = _node("%ClosetButton")
	assert_eq(_neighbor(cards[0], SIDE_RIGHT), cards[1])
	assert_eq(_neighbor(cards[1], SIDE_RIGHT), cards[2])
	assert_eq(_neighbor(cards[2], SIDE_LEFT), cards[1])
	assert_eq(_neighbor(cards[0], SIDE_LEFT), cards[0], "left end stops")
	assert_eq(_neighbor(cards[2], SIDE_RIGHT), cards[2], "right end stops")
	for card: LevelCard in cards:
		assert_eq(_neighbor(card, SIDE_BOTTOM), closet, "down from %s" % card.get_level_id())
		assert_eq(_neighbor(card, SIDE_TOP), card, "nothing above the cards")


func test_bottom_row_neighbours() -> void:
	_make()
	var row: Array[Control] = [
		_node("%ClosetButton"), _target("%MusicToggle"), _target("%SoundToggle"), _target("%FullscreenToggle")
	]
	for i: int in row.size() - 1:
		assert_eq(_neighbor(row[i], SIDE_RIGHT), row[i + 1])
		assert_eq(_neighbor(row[i + 1], SIDE_LEFT), row[i])
	assert_eq(_neighbor(row[0], SIDE_LEFT), row[0], "left end stops")
	assert_eq(_neighbor(row[3], SIDE_RIGHT), row[3], "right end stops")
	for control: Control in row:
		assert_eq(_neighbor(control, SIDE_TOP), _cards()[0], "up from %s" % control.name)
		assert_eq(_neighbor(control, SIDE_BOTTOM), control, "nothing below the bottom row")


func test_up_goes_to_the_first_available_card() -> void:
	_make(_registry([_entry(&"a", false), _entry(&"b", true), _entry(&"c", false)]), true)
	assert_eq(_neighbor(_node("%ClosetButton"), SIDE_TOP), _cards()[1])


func test_tab_order_walks_cards_then_bottom_row() -> void:
	_make()
	var order: Array[Control] = []
	order.assign(_cards())
	order.append_array([
		_node("%ClosetButton"), _target("%MusicToggle"), _target("%SoundToggle"), _target("%FullscreenToggle")
	])
	for i: int in order.size():
		var next: Node = order[i].get_node_or_null(order[i].focus_next)
		assert_eq(next, order[(i + 1) % order.size()])


func test_decor_never_takes_focus_or_the_mouse() -> void:
	_make()
	for path: String in ["%Logo", "%BrainCounter", "%StorageNotice", "%StorageNoticeLabel", "%Background", "%Cards"]:
		assert_eq(_node(path).focus_mode, Control.FOCUS_NONE, path)
		assert_eq(_node(path).mouse_filter, Control.MOUSE_FILTER_IGNORE, path)


# --- Wallet and toggles --------------------------------------------------------------------------------

func test_brain_counter_shows_and_follows_the_wallet() -> void:
	_player.add_brains(42)
	_make()
	var count: Label = _menu.get_node("%BrainCounter/%CountLabel") as Label
	assert_eq(count.text, "42")
	_player.add_brains(8)
	assert_eq(count.text, "50")
	_player.reset_all()
	assert_eq(count.text, "0", "profile_replaced re-reads the wallet")


func test_toggles_show_the_saved_settings() -> void:
	_player.set_setting(&"music_on", false)
	_make()
	assert_false((_menu.get_node("%MusicToggle") as MenuToggle).is_on())
	assert_true((_menu.get_node("%SoundToggle") as MenuToggle).is_on())


func test_flipping_music_and_sound_writes_the_setting() -> void:
	_make()
	_target("%MusicToggle").pressed.emit()
	assert_false(_player.get_setting(&"music_on"))
	_target("%SoundToggle").pressed.emit()
	assert_false(_player.get_setting(&"sound_on"))
	_target("%SoundToggle").pressed.emit()
	assert_true(_player.get_setting(&"sound_on"))
	assert_eq(_nav, [], "toggles never navigate")


func test_profile_replaced_rereads_the_toggles() -> void:
	_make()
	_target("%MusicToggle").pressed.emit()
	assert_false((_menu.get_node("%MusicToggle") as MenuToggle).is_on())
	_player.reset_all()
	assert_true((_menu.get_node("%MusicToggle") as MenuToggle).is_on())


func test_fullscreen_flip_calls_the_toggle_once_and_follows_the_mode() -> void:
	_make()
	var toggle: MenuToggle = _menu.get_node("%FullscreenToggle") as MenuToggle
	assert_false(toggle.is_on(), "windowed on open")
	toggle.get_focus_target().pressed.emit()
	assert_eq(_toggles, 1)
	assert_true(toggle.is_on())
	_fullscreen = false  # the browser's own Esc left fullscreen
	_menu.call("_sync_fullscreen")
	assert_false(toggle.is_on())


func test_fullscreen_state_is_read_on_open() -> void:
	_fullscreen = true
	_make()
	assert_true((_menu.get_node("%FullscreenToggle") as MenuToggle).is_on())
	assert_eq(_toggles, 0)


func test_window_resize_resyncs_fullscreen() -> void:
	_make()
	_fullscreen = true
	get_tree().root.size_changed.emit()
	assert_true((_menu.get_node("%FullscreenToggle") as MenuToggle).is_on())


# --- Esc and the payload -------------------------------------------------------------------------------

func test_esc_goes_nowhere() -> void:
	_make()
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	_menu._unhandled_input(esc)
	assert_eq(_nav, [])


func test_payload_is_consumed() -> void:
	Router._store_payload({"stale": true})
	_make()
	assert_eq(Router.take_payload(), {})


# --- Storage notice (Story 1.7) ------------------------------------------------------------------------

func _notice() -> PanelContainer:
	return _menu.get_node("%StorageNotice") as PanelContainer


func test_notice_has_its_sign_panel() -> void:
	_make()
	assert_true(_notice().get_theme_stylebox(&"panel") is StyleBoxTexture, "the Sign variation's panel shows on a PanelContainer")


func test_notice_hidden_when_storage_is_persistent() -> void:
	_make()
	assert_true(WebPlatform.is_storage_persistent(), "desktop storage is persistent")
	assert_false(_notice().visible)


func test_notice_shown_when_storage_is_not_persistent() -> void:
	_make()
	_menu.call("_show_storage_notice", false)
	assert_true(_notice().visible)
	var label: Label = _menu.get_node("%StorageNoticeLabel") as Label
	assert_eq(label.text, "Progress may not be saved in this browser mode")
	assert_eq(MainMenuScript.STORAGE_NOTICE_TEXT, label.text)
	_menu.call("_show_storage_notice", true)
	assert_false(_notice().visible)


func test_notice_never_blocks_or_takes_focus() -> void:
	_make()
	_menu.call("_show_storage_notice", false)
	assert_eq(_notice().mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((_menu.get_node("%StorageNoticeLabel") as Label).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(_notice().focus_mode, Control.FOCUS_NONE)
	assert_true(_cards()[0].has_focus(), "the Zombie Run card keeps focus")


func test_notice_overlaps_no_control() -> void:
	_make()
	_menu.call("_show_storage_notice", false)
	await wait_process_frames(2)
	var notice: Rect2 = _notice().get_global_rect()
	assert_true(SAFE_RECT.encloses(notice), "notice inside the margin: %s" % notice)
	for control: Control in _interactive_and_decor():
		assert_false(notice.intersects(control.get_global_rect()), "notice overlaps %s" % control.name)


# --- Export chord (Story 1.8) --------------------------------------------------------------------------

func _chord(keycode: Key, ctrl: bool, shift: bool, alt: bool = false, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.alt_pressed = alt
	event.pressed = pressed
	event.echo = echo
	return event


func test_export_chord_is_ctrl_shift_e_only() -> void:
	assert_true(MainMenuScript.is_export_chord(_chord(KEY_E, true, true)))
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, false, false)), "plain E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, false)), "Ctrl+E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, false, true)), "Shift+E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, true, true)), "Ctrl+Shift+Alt+E")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_R, true, true)), "Ctrl+Shift+R")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, true, false, false)), "release")
	assert_false(MainMenuScript.is_export_chord(_chord(KEY_E, true, true, false, true, true)), "echo")
	var meta: InputEventKey = _chord(KEY_E, true, true)
	meta.meta_pressed = true
	assert_false(MainMenuScript.is_export_chord(meta), "Ctrl+Shift+Meta+E")


# --- Layout --------------------------------------------------------------------------------------------

## The menu's own controls (cards as whole cards), excluding the background and the notice.
func _interactive_and_decor() -> Array[Control]:
	var result: Array[Control] = [_node("%BrainCounter"), _node("%Logo"), _node("%ClosetButton")]
	result.append_array(_cards())
	for path: String in ["%MusicToggle", "%SoundToggle", "%FullscreenToggle"]:
		var toggle: MenuToggle = _menu.get_node(path) as MenuToggle
		result.append(toggle.get_focus_target())
		result.append(toggle.get_node("%Caption") as Control)
	return result


func test_every_control_is_inside_the_margin() -> void:
	_make()
	await wait_process_frames(2)
	for control: Control in _interactive_and_decor():
		var rect: Rect2 = control.get_global_rect()
		assert_true(SAFE_RECT.encloses(rect), "%s %s outside the 16 px margin" % [control.name, rect])
	# The focused card's ring and lift may reach into the margin, never off the canvas.
	for card: LevelCard in _cards():
		card.grab_focus()
		var ring: Control = card.get_node("%FocusRing") as Control
		var grown: Rect2 = ring.get_global_rect().grow(2.0)
		assert_true(CANVAS_RECT.encloses(grown), "%s ring %s off the canvas" % [card.get_level_id(), grown])


func test_zombie_stands_inside_the_margin() -> void:
	_make()
	var feet: Vector2 = (_menu.get_node("%Zombie") as Node2D).position
	assert_true(SAFE_RECT.has_point(feet - Vector2(16, 32)) and SAFE_RECT.has_point(feet + Vector2(16, 0)))


## Story 4.3: the pet stands beside the zombie and the zombie wears the hat; both follow the wallet's
## PlayerData with no call from the menu.
func test_hat_and_pet_slots() -> void:
	_make()
	var pet: PetSlot = _menu.get_node("%PetSlot") as PetSlot
	assert_not_null(pet, "%PetSlot is a PetSlot")
	assert_eq(pet.position, Vector2(84, 284))
	var hat: HatSlot = _menu.get_node("%Zombie").get_node("%HatSlot") as HatSlot
	assert_not_null(hat, "the zombie's %HatSlot is a HatSlot")
	assert_false(pet.is_showing(), "fresh save: no pet")
	assert_false(hat.is_showing(), "fresh save: no hat")
	_player.add_brains(200)
	for id: StringName in [&"hat_pumpkin", &"pet_cute_ghost"]:
		_player.buy_item(_player.catalogue.get_item(id))
		_player.equip(id)
	assert_eq(hat.get_item_id(), &"hat_pumpkin")
	assert_eq(pet.get_item_id(), &"pet_cute_ghost")
	assert_true(hat.is_showing())
	assert_true(pet.is_showing())


## The pet (32 px, feet origin) and the hat (up to 11 px above the head) stay inside the margin and clear
## of every control.
func test_hat_and_pet_overlap_nothing() -> void:
	_make()
	var feet: Vector2 = (_menu.get_node("%PetSlot") as Node2D).position
	var pet_rect: Rect2 = Rect2(feet + Vector2(-16, -31), Vector2(32, 32))
	var zombie_feet: Vector2 = (_menu.get_node("%Zombie") as Node2D).position
	var hat_rect: Rect2 = Rect2(zombie_feet + Vector2(-16, -31 + 1 - 11), Vector2(32, 11))
	assert_true(SAFE_RECT.encloses(pet_rect), "pet inside the margin")
	assert_true(SAFE_RECT.encloses(hat_rect), "hat inside the margin")
	for node: Node in _menu.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control == _menu or control.name == "Background":
			continue
		var rect: Rect2 = control.get_global_rect()
		assert_false(rect.intersects(pet_rect), "pet clear of %s" % control.name)
		assert_false(rect.intersects(hat_rect), "hat clear of %s" % control.name)


func test_text_fits_and_is_at_least_16px() -> void:
	_make()
	_menu.call("_show_storage_notice", false)
	await wait_process_frames(2)
	var checked: int = 0
	for node: Node in _menu.find_children("*", "Control", true, false):
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
	# Fewer since Story 5.0: the logo and the two "Coming soon" planks are hand-lettered sprites, not Labels.
	assert_gt(checked, 8, "the walk found the menu's text")


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
