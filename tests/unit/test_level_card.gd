extends GutTest
## LevelCard (Story 4.2): setup from a LevelEntry, the AVAILABLE / COMING_SOON looks, Enter and click,
## the Coming soon wiggle, the focus ring and lift, and that only the card itself takes the mouse.
## Story 6.8: state precedence, the LOCKED / NEW looks, the hint sign (focus only, clamped, on strings), the
## unlock moment (natural end, forced finish, jingle once through the play_sfx seam, whole pixels).
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
	assert_eq((card.get_node("%NameSign") as Panel).theme_type_variation, &"Sign")


func test_unavailable_entry_is_coming_soon() -> void:
	var card: LevelCard = _card(_entry(&"horde_rush", false, "Horde Rush"))
	assert_eq(card.get_state(), LevelCard.State.COMING_SOON)
	assert_true((card.get_node("%ComingSoonPlank") as Control).visible)
	assert_true((card.get_node("%Tint") as Control).visible)
	# Story 5.0: the hand-lettered plank sprite and the greyed sign variation.
	assert_eq((card.get_node("%ComingSoonPlank") as TextureRect).texture.resource_path,
			"res://assets/sprites/ui/menu/ui_coming_soon.png")
	assert_eq((card.get_node("%NameSign") as Panel).theme_type_variation, &"SignGrey", "the sign is greyed")


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


## Story 5.0: while focused the frame bobs 1 px above the lift, in whole pixels, never sideways; on unfocus it
## is exactly at rest.
func test_focus_bob_stays_on_whole_pixels_and_rests_at_zero() -> void:
	var card: LevelCard = _card(_entry(&"zombie_run", true))
	card.grab_focus()
	var seen: Dictionary[float, bool] = {}
	for i: int in 10:
		card._process(LevelCard.BOB_PERIOD_S / 4.0)
		var y: float = _frame(card).position.y
		seen[y] = true
		assert_eq(y, roundf(y), "whole pixels")
		assert_eq(_frame(card).position.x, 0.0, "the bob never moves x")
	assert_eq_deep(seen.keys().size(), 2)
	assert_true(seen.has(-LevelCard.LIFT_PX) and seen.has(-LevelCard.LIFT_PX - LevelCard.BOB_PX))
	card.release_focus()
	assert_eq(_frame(card).position.y, 0.0)
	assert_false(card.is_processing(), "no bob while unfocused")


# --- Locked / New, the hint sign and the unlock moment (Story 6.8) -----------------------------------------

const LOCKED: Dictionary = {"unlocked": false, "moment_seen": false, "chosen": false}
const PENDING: Dictionary = {"unlocked": true, "moment_seen": false, "chosen": false}
const NEW: Dictionary = {"unlocked": true, "moment_seen": true, "chosen": false}
const OPEN: Dictionary = {"unlocked": true, "moment_seen": true, "chosen": true}
const MOMENT_TOTAL_S: float = (LevelCard.MOMENT_BEAT_S + LevelCard.WIGGLE_S + LevelCard.PADLOCK_POP_S
		+ LevelCard.PADLOCK_FALL_S + LevelCard.TINT_CLEAR_S + LevelCard.BADGE_THUMP_S)

var _sfx: Array[StringName] = []
var _finished: Array[StringName] = []


func _unlock_card(unlock: Dictionary, available: bool = true) -> LevelCard:
	_sfx = []
	_finished = []
	var card: LevelCard = CardScene.instantiate() as LevelCard
	card.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	card.setup(_entry(&"horde_rush", available, "Horde Rush"), unlock)
	card.set_hint_text("Finish Zombie Run to open!")
	card.chosen.connect(func(id: StringName) -> void: _chosen.append(id))
	card.unlock_moment_finished.connect(func(id: StringName) -> void: _finished.append(id))
	add_child_autofree(card)
	return card


func _visible(card: LevelCard, node: String) -> bool:
	return (card.get_node(node) as CanvasItem).visible


func _assert_new_look(card: LevelCard) -> void:
	assert_eq(card.get_state(), LevelCard.State.NEW)
	assert_true(_visible(card, "%NewBadge"), "badge shown")
	assert_eq((card.get_node("%NewBadge") as Control).scale, Vector2.ONE, "badge at scale 1")
	assert_false(_visible(card, "%Padlock"), "no padlock")
	assert_false(_visible(card, "%Tint"), "no tint")
	assert_false(_visible(card, "%ComingSoonPlank"))
	assert_false(_visible(card, "%Hint"))
	var padlock: Control = card.get_node("%Padlock") as Control
	assert_eq(padlock.position, LevelCard.PADLOCK_REST, "padlock reset for a later Locked look")
	assert_eq(padlock.modulate.a, 1.0)


func test_state_precedence() -> void:
	var on: LevelEntry = _entry(&"x", true)
	var off: LevelEntry = _entry(&"x", false)
	assert_eq(LevelCard.state_for(off, OPEN), LevelCard.State.COMING_SOON)
	assert_eq(LevelCard.state_for(off, LOCKED), LevelCard.State.COMING_SOON, "Coming soon > Locked")
	assert_eq(LevelCard.state_for(off, NEW), LevelCard.State.COMING_SOON, "Coming soon > New")
	assert_eq(LevelCard.state_for(on, LOCKED), LevelCard.State.LOCKED)
	assert_eq(LevelCard.state_for(on, PENDING), LevelCard.State.NEW)
	assert_eq(LevelCard.state_for(on, NEW), LevelCard.State.NEW, "New > Available")
	assert_eq(LevelCard.state_for(on, OPEN), LevelCard.State.AVAILABLE)
	assert_eq(LevelCard.state_for(on, {}), LevelCard.State.AVAILABLE, "missing fields read as open")
	assert_eq(LevelCard.state_for(null, OPEN), LevelCard.State.COMING_SOON)
	assert_eq([LevelCard.State.AVAILABLE, LevelCard.State.COMING_SOON, LevelCard.State.LOCKED, LevelCard.State.NEW],
			[0, 1, 2, 3], "append-only enum order")


func test_locked_look() -> void:
	var card: LevelCard = _unlock_card(LOCKED)
	assert_eq(card.get_state(), LevelCard.State.LOCKED)
	assert_true(_visible(card, "%Tint"))
	assert_eq((card.get_node("%Tint") as ColorRect).color, LevelCard.TINT_LOCKED, "dusk tint")
	assert_eq(LevelCard.TINT_LOCKED.to_html(false), "4a3366")
	assert_true(_visible(card, "%Padlock"))
	assert_eq((card.get_node("%Padlock") as TextureRect).texture.resource_path,
			"res://assets/sprites/ui/menu/ui_padlock.png")
	assert_false(_visible(card, "%ComingSoonPlank"), "no plank: shape tells Locked from Coming soon")
	assert_false(_visible(card, "%NewBadge"))
	assert_eq((card.get_node("%NameSign") as Panel).theme_type_variation, &"Sign", "normal parchment sign")
	assert_false(_visible(card, "%Hint"), "nothing else at rest")
	assert_false(card.is_choosable())


func test_coming_soon_look_has_no_padlock_or_badge() -> void:
	var card: LevelCard = _unlock_card(PENDING, false)
	assert_eq(card.get_state(), LevelCard.State.COMING_SOON)
	assert_eq((card.get_node("%Tint") as ColorRect).color, LevelCard.TINT_COMING_SOON, "stone tint")
	assert_false(_visible(card, "%Padlock"))
	assert_false(_visible(card, "%NewBadge"))


func test_new_look() -> void:
	var card: LevelCard = _unlock_card(NEW)
	_assert_new_look(card)
	var label: Label = card.get_node("%NewBadgeLabel") as Label
	assert_eq(label.text, "New!")
	assert_eq(label.get_theme_font_size(&"font_size"), 16)
	assert_eq((card.get_node("%NewBadge") as Control).theme_type_variation, &"BadgePumpkin")
	assert_true(card.is_choosable())


func test_new_badge_overlaps_the_top_right_corner_inside_the_card_width() -> void:
	var card: LevelCard = _unlock_card(NEW)
	await wait_process_frames(1)
	var badge: Control = card.get_node("%NewBadge") as Control
	var rect: Rect2 = Rect2(badge.position, badge.size)
	assert_lt(rect.position.y, 0.0, "pokes above the frame")
	assert_gt(rect.end.y, 0.0, "overlaps the frame")
	assert_eq(rect.end.x, 192.0, "flush with the right edge, so the last card stays inside the margin")
	assert_gte(rect.position.y, -4.0, "clear of the logo above the cards")
	var label: Label = card.get_node("%NewBadgeLabel") as Label
	assert_gte(label.size.x, label.get_minimum_size().x, "the text fits")


func test_locked_wiggles_and_never_emits() -> void:
	var card: LevelCard = _unlock_card(LOCKED)
	card._gui_input(_accept())
	assert_true(card.is_wiggling())
	card._gui_input(_click())
	assert_eq(_chosen, [] as Array[StringName])
	assert_eq(_sfx, [] as Array[StringName], "no sound")
	await wait_seconds(LevelCard.WIGGLE_S + 0.1)
	assert_eq(_frame(card).position.x, 0.0)


func test_new_emits_once_on_enter_and_click() -> void:
	var card: LevelCard = _unlock_card(NEW)
	card._gui_input(_accept())
	assert_eq(_chosen, [&"horde_rush"] as Array[StringName])
	card._gui_input(_click())
	assert_eq(_chosen, [&"horde_rush", &"horde_rush"] as Array[StringName], "one per press")
	assert_false(card.is_wiggling())


func test_hint_shows_only_while_locked_and_focused() -> void:
	var card: LevelCard = _unlock_card(LOCKED)
	assert_eq((card.get_node("%HintLabel") as Label).text, "Finish Zombie Run to open!")
	assert_eq(card.get_hint_text(), "Finish Zombie Run to open!")
	assert_false(_visible(card, "%Hint"))
	card.grab_focus()
	assert_true(_visible(card, "%Hint"), "focus shows the hint")
	card.release_focus()
	assert_false(_visible(card, "%Hint"), "focus loss hides it")
	card.grab_focus()
	for state: LevelCard.State in [LevelCard.State.AVAILABLE, LevelCard.State.NEW, LevelCard.State.COMING_SOON]:
		card.set_state(state)
		assert_false(_visible(card, "%Hint"), "no hint on state %d" % state)
	card.set_state(LevelCard.State.LOCKED)
	assert_true(_visible(card, "%Hint"), "back to Locked while focused")
	var focused_new: LevelCard = _unlock_card(NEW)
	focused_new.grab_focus()
	assert_false(_visible(focused_new, "%Hint"))


func test_hint_hangs_below_the_card_on_two_strings() -> void:
	var card: LevelCard = _unlock_card(LOCKED)
	card.position.x = 16.0
	card.grab_focus()
	var hint: Control = card.get_node("%Hint") as Control
	assert_gt(hint.z_index, 0, "drawn over later siblings (the storage notice)")
	assert_gte(hint.position.y, 124.0 - LevelCard.LIFT_PX - LevelCard.BOB_PX, "starts at the lifted frame's bottom")
	var sign: Control = card.get_node("%HintSign") as Control
	assert_eq(sign.theme_type_variation, &"Sign", "parchment")
	var strings: Array[ColorRect] = []
	for child: Node in hint.get_children():
		if child is ColorRect:
			strings.append(child)
	assert_eq(strings.size(), 2)
	for string: ColorRect in strings:
		assert_eq(string.size.x, 1.0, "1 px")
		assert_eq(string.color.to_html(false), "1e1428", "ink")
		assert_eq(string.position.y + string.size.y, sign.position.y, "reaches the sign")
		var x: float = hint.position.x + string.position.x
		assert_true(x >= 0.0 and x < card.size.x, "hangs from the card")
	var label: Label = card.get_node("%HintLabel") as Label
	assert_eq(label.get_theme_font_size(&"font_size"), 16)
	assert_eq(label.get_line_count(), 2, "two lines at 16 px")
	assert_lte(label.get_minimum_size().y, label.size.y, "text fits the sign")


func test_hint_is_clamped_into_the_margin() -> void:
	var card: LevelCard = _unlock_card(LOCKED)
	var hint: Control = card.get_node("%Hint") as Control
	for x: float in [16.0, 224.0, 432.0]:
		card.position.x = x
		card.grab_focus()
		var left: float = card.global_position.x + hint.position.x
		assert_gte(left, LevelCard.MARGIN_RECT.position.x, "left at card x %d" % x)
		assert_lte(left + hint.size.x, LevelCard.MARGIN_RECT.end.x, "right at card x %d" % x)
		assert_eq(hint.position.x, roundf(hint.position.x), "whole pixels")
		for child: Node in hint.get_children():
			if child is ColorRect:
				var string_x: float = hint.position.x + (child as ColorRect).position.x
				assert_true(string_x >= 0.0 and string_x < card.size.x, "strings hang from the card at x %d" % x)
		card.release_focus()
	card.position.x = 224.0
	card.grab_focus()
	assert_eq(card.global_position.x + hint.position.x + hint.size.x / 2.0, 224.0 + card.size.x / 2.0,
			"centred when it fits")


func test_moment_plays_to_the_new_look() -> void:
	var card: LevelCard = _unlock_card(PENDING)
	card.set_state(LevelCard.State.LOCKED)
	card.play_unlock_moment()
	assert_true(card.is_playing_moment())
	assert_true(_visible(card, "%Padlock"), "starts Locked-looking")
	assert_true(_visible(card, "%Tint"))
	var padlock: Control = card.get_node("%Padlock") as Control
	var moved: bool = false
	var elapsed: float = 0.0
	while card.is_playing_moment() and elapsed < MOMENT_TOTAL_S + 1.0:
		await wait_process_frames(1)
		elapsed += get_process_delta_time()
		assert_eq(padlock.position, padlock.position.round(), "padlock on whole pixels")
		moved = moved or padlock.position != LevelCard.PADLOCK_REST
	assert_false(card.is_playing_moment(), "ends by itself")
	assert_true(moved, "the padlock moved")
	_assert_new_look(card)
	assert_eq(_finished, [&"horde_rush"] as Array[StringName])
	assert_eq(_sfx, [&"sfx_unlock_jingle"] as Array[StringName], "jingle once")


func test_finish_mid_moment_snaps_to_the_end_once() -> void:
	var card: LevelCard = _unlock_card(PENDING)
	card.set_state(LevelCard.State.LOCKED)
	card.play_unlock_moment()
	await wait_seconds(LevelCard.MOMENT_BEAT_S + 0.15)
	card.finish_unlock_moment()
	assert_false(card.is_playing_moment())
	_assert_new_look(card)
	assert_eq(_finished, [&"horde_rush"] as Array[StringName])
	assert_eq(_sfx, [&"sfx_unlock_jingle"] as Array[StringName], "jingle once, even when skipped")
	card.finish_unlock_moment()
	await wait_seconds(MOMENT_TOTAL_S)
	assert_eq(_finished.size(), 1, "no second finish")
	assert_eq(_sfx.size(), 1)
	_assert_new_look(card)


func test_finish_after_the_thump_plays_no_second_jingle() -> void:
	var card: LevelCard = _unlock_card(PENDING)
	card.play_unlock_moment()
	await wait_seconds(MOMENT_TOTAL_S - LevelCard.BADGE_THUMP_S / 2.0)
	assert_true(card.is_playing_moment())
	assert_gt((card.get_node("%NewBadge") as Control).scale.x, 1.0, "mid-thump")
	card.finish_unlock_moment()
	assert_eq(_sfx, [&"sfx_unlock_jingle"] as Array[StringName])
	assert_eq(_finished.size(), 1)
	_assert_new_look(card)


func test_moment_card_is_choosable_after_the_lock_pops() -> void:
	var card: LevelCard = _unlock_card(PENDING)
	card.play_unlock_moment()
	assert_false(card.is_choosable(), "still locked during the beat")
	card.grab_focus()
	assert_false(_visible(card, "%Hint"), "no hint sign on a card whose lock is on its way out")
	await wait_seconds(LevelCard.MOMENT_BEAT_S + LevelCard.WIGGLE_S + 0.05)
	assert_true(card.is_choosable())
	assert_false(_visible(card, "%Hint"), "the hint stays down after the pop")
	card.finish_unlock_moment()


func test_finish_without_a_moment_does_nothing() -> void:
	var card: LevelCard = _unlock_card(LOCKED)
	card.finish_unlock_moment()
	assert_eq(card.get_state(), LevelCard.State.LOCKED)
	assert_eq(_finished.size(), 0)
	assert_eq(_sfx.size(), 0)
