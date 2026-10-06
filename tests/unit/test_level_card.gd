extends GutTest
## LevelCard (Story 4.2): setup from a LevelEntry, the AVAILABLE / COMING_SOON looks, Enter and click,
## the Coming soon wiggle, the focus ring and lift, and that only the card itself takes the mouse.
## Input goes through _gui_input() with synthetic events.

const CardScene: PackedScene = preload("res://scenes/ui/level_card.tscn")

var _chosen: Array[StringName] = []


func before_each() -> void:
	_chosen = []


func _entry(id: StringName, available: bool, display_name: String = "Zombie Run") -> LevelEntry:
	var entry: LevelEntry = LevelEntry.new()
	entry.id = id
	entry.display_name = display_name
	entry.available = available
	return entry


func _card(entry: LevelEntry) -> LevelCard:
	var card: LevelCard = CardScene.instantiate() as LevelCard
	card.setup(entry)
	card.chosen.connect(func(id: StringName) -> void: _chosen.append(id))
	add_child_autofree(card)
	return card


func _accept() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	return event


func _click(button: MouseButton = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _frame(card: LevelCard) -> Control:
	return card.get_node("%Frame") as Control


func test_available_entry() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	assert_eq(card.get_state(), LevelCard.State.AVAILABLE)
	assert_eq(card.get_level_id(), &"zombie_run")
	assert_eq((card.get_node("%NameLabel") as Label).text, "Zombie Run")
	assert_false((card.get_node("%ComingSoonPlank") as Control).visible)
	assert_false((card.get_node("%Tint") as Control).visible)


func test_unavailable_entry_is_coming_soon() -> void:
	var card: LevelCard = _card(_entry(&"horde_rush", false, "Horde Rush"))
	assert_eq(card.get_state(), LevelCard.State.COMING_SOON)
	assert_true((card.get_node("%ComingSoonPlank") as Control).visible)
	assert_true((card.get_node("%Tint") as Control).visible)
	assert_eq((card.get_node("%PlankLabel") as Label).text, "Coming soon")
	var sign_box: StyleBox = (card.get_node("%NameSign") as Panel).get_theme_stylebox(&"panel")
	assert_eq(sign_box, card.sign_coming_soon_style, "the sign is greyed")


func test_empty_display_name_falls_back_to_the_capitalized_id() -> void:
	var card: LevelCard = _card(_entry(&"pitchfork_panic", false, ""))
	assert_eq((card.get_node("%NameLabel") as Label).text, "Pitchfork Panic")


func test_picture_comes_from_the_entry() -> void:
	var entry: LevelEntry = _entry(&"zombie_run", true)
	entry.card_picture = PlaceholderTexture2D.new()
	var card: LevelCard = _card(entry)
	assert_eq((card.get_node("%Picture") as TextureRect).texture, entry.card_picture)


func test_null_entry_logs_and_keeps_coming_soon() -> void:
	var card: LevelCard = _card(null)
	assert_push_error("LevelCard.setup: null entry")
	assert_eq(card.get_state(), LevelCard.State.COMING_SOON)
	card._activate()
	assert_eq(_chosen, [] as Array[StringName])


func test_accept_on_available_emits_chosen_once() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	card._gui_input(_accept())
	assert_eq(_chosen, [&"zombie_run"] as Array[StringName])
	assert_false(card.is_wiggling())


func test_left_click_on_available_emits_chosen_once() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	card._gui_input(_click())
	assert_eq(_chosen, [&"zombie_run"] as Array[StringName])


func test_other_clicks_and_releases_do_nothing() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	card._gui_input(_click(MOUSE_BUTTON_RIGHT))
	card._gui_input(_click(MOUSE_BUTTON_LEFT, false))
	var release: InputEventAction = _accept()
	release.pressed = false
	card._gui_input(release)
	assert_eq(_chosen, [] as Array[StringName])


func test_coming_soon_never_emits_and_wiggles_back_to_rest() -> void:
	var card: LevelCard = _card(_entry(&"horde_rush", false))
	card._gui_input(_accept())
	assert_true(card.is_wiggling())
	card._gui_input(_click())
	assert_true(card.is_wiggling(), "a second press restarts the wiggle")
	assert_eq(_chosen, [] as Array[StringName])
	await wait_seconds(LevelCard.WIGGLE_S + 0.1)
	assert_false(card.is_wiggling())
	assert_eq(_frame(card).position.x, 0.0, "ends exactly at rest")


func test_wiggle_moves_the_frame_sideways() -> void:
	var card: LevelCard = _card(_entry(&"horde_rush", false))
	card._activate()
	var max_x: float = 0.0
	for i: int in 10:
		await wait_process_frames(1)
		max_x = maxf(max_x, absf(_frame(card).position.x))
	assert_gt(max_x, 0.0)
	assert_lte(max_x, LevelCard.WIGGLE_PX)


func test_focus_shows_ring_and_lifts_frame() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	var ring: Control = card.get_node("%FocusRing") as Control
	assert_false(ring.visible)
	assert_eq(_frame(card).position.y, 0.0)
	card.grab_focus()
	assert_true(ring.visible)
	assert_eq(_frame(card).position.y, -2.0)
	assert_eq(card.position, Vector2.ZERO, "the card itself never moves")
	card.release_focus()
	assert_false(ring.visible)
	assert_eq(_frame(card).position.y, 0.0)


func test_hover_moves_focus() -> void:
	var card: LevelCard = _card(_entry(&"horde_rush", false))
	card.mouse_entered.emit()
	assert_false(card.has_focus(), "a resting cursor must not steal focus")
	card._gui_input(InputEventMouseMotion.new())
	assert_true(card.has_focus(), "Coming soon cards stay focusable")


func test_only_the_card_takes_the_mouse() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	assert_eq(card.focus_mode, Control.FOCUS_ALL)
	assert_ne(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var children: Array[Node] = card.find_children("*", "Control", true, false)
	assert_gt(children.size(), 5)
	for child: Node in children:
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, String(child.name))
		assert_eq((child as Control).focus_mode, Control.FOCUS_NONE, String(child.name))
