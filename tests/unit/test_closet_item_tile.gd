extends GutTest
## ClosetItemTile (Story 4.4): the pure state_for() / need_more() / info_lines() rules, one look per state,
## Enter and click (activated only on BUY / WEAR / WEARING, a wiggle on LOCKED / CANT_AFFORD), the focus
## ring, hover, mouse filters and the missing-icon warning. Input goes through _gui_input() with synthetic
## events.

const TileScene: PackedScene = preload("res://scenes/ui/closet_item_tile.tscn")

var _activated: Array[StringName] = []


func before_each() -> void:
	_activated = []


func _item(id: StringName = &"hat_test", price: int = 100, available: bool = true, with_icon: bool = true) -> CosmeticItem:
	var item: CosmeticItem = CosmeticItem.new()
	item.id = id
	item.display_name = "Test hat"
	item.price = price
	item.row = 1
	item.is_available = available
	if with_icon:
		item.icon = PlaceholderTexture2D.new()
	return item


func _tile(item: CosmeticItem, state: ClosetItemTile.State = ClosetItemTile.State.BUY) -> ClosetItemTile:
	var tile: ClosetItemTile = TileScene.instantiate() as ClosetItemTile
	tile.setup(item)
	tile.activated.connect(func(id: StringName) -> void: _activated.append(id))
	add_child_autofree(tile)
	tile.show_state(state)
	return tile


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


func _node(tile: ClosetItemTile, path: String) -> Node:
	return tile.get_node(path)


func _tag_fill(tile: ClosetItemTile) -> Variant:
	var box: StyleBox = (_node(tile, "%Tag") as Panel).get_theme_stylebox(&"panel")
	return (box as StyleBoxFlat).bg_color if box is StyleBoxFlat else null


func _frame_fill(tile: ClosetItemTile) -> Color:
	return ((_node(tile, "%Frame") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color


# --- The state rule ------------------------------------------------------------------------------------

func test_unavailable_is_locked_even_when_owned_and_equipped() -> void:
	var item: CosmeticItem = _item(&"hat_test", 100, false)
	assert_eq(ClosetItemTile.state_for(item, 999, true, &"hat_test"), ClosetItemTile.State.LOCKED)
	assert_eq(ClosetItemTile.state_for(item, 0, false, &""), ClosetItemTile.State.LOCKED)


func test_null_item_is_locked() -> void:
	assert_eq(ClosetItemTile.state_for(null, 999, true, &""), ClosetItemTile.State.LOCKED)


func test_owned_and_equipped_is_wearing() -> void:
	assert_eq(ClosetItemTile.state_for(_item(), 0, true, &"hat_test"), ClosetItemTile.State.WEARING)


func test_owned_not_equipped_is_wear() -> void:
	assert_eq(ClosetItemTile.state_for(_item(), 0, true, &""), ClosetItemTile.State.WEAR)
	assert_eq(ClosetItemTile.state_for(_item(), 0, true, &"hat_other"), ClosetItemTile.State.WEAR)


func test_equipped_id_without_owning_is_not_wearing() -> void:
	assert_eq(ClosetItemTile.state_for(_item(), 0, false, &"hat_test"), ClosetItemTile.State.CANT_AFFORD)


func test_exact_price_is_buy_and_one_short_is_cant_afford() -> void:
	assert_eq(ClosetItemTile.state_for(_item(&"hat_test", 100), 100, false, &""), ClosetItemTile.State.BUY)
	assert_eq(ClosetItemTile.state_for(_item(&"hat_test", 100), 99, false, &""), ClosetItemTile.State.CANT_AFFORD)
	assert_eq(ClosetItemTile.state_for(_item(&"hat_test", 100), 500, false, &""), ClosetItemTile.State.BUY)


func test_need_more() -> void:
	assert_eq(ClosetItemTile.need_more(_item(&"hat_test", 100), 60), 40)
	assert_eq(ClosetItemTile.need_more(_item(&"hat_test", 300), 0), 300)
	assert_eq(ClosetItemTile.need_more(_item(&"hat_test", 100), 500), 0, "never negative")
	assert_eq(ClosetItemTile.need_more(null, 0), 0)


func test_info_lines() -> void:
	var item: CosmeticItem = _item()
	assert_eq(ClosetItemTile.info_lines(item, ClosetItemTile.State.LOCKED, 0), PackedStringArray(["Coming soon", ""]))
	assert_eq(ClosetItemTile.info_lines(null, ClosetItemTile.State.BUY, 0), PackedStringArray(["Coming soon", ""]))
	assert_eq(ClosetItemTile.info_lines(item, ClosetItemTile.State.CANT_AFFORD, 40), PackedStringArray(["Test hat", "Need 40 more"]))
	assert_eq(ClosetItemTile.info_lines(item, ClosetItemTile.State.BUY, 0), PackedStringArray(["Test hat", "Buy"]))
	assert_eq(ClosetItemTile.info_lines(item, ClosetItemTile.State.WEAR, 0), PackedStringArray(["Test hat", "Wear"]))
	assert_eq(ClosetItemTile.info_lines(item, ClosetItemTile.State.WEARING, 0), PackedStringArray(["Test hat", "Wearing"]))


# --- Looks ---------------------------------------------------------------------------------------------

func test_setup_fills_the_art_and_ids() -> void:
	var item: CosmeticItem = _item()
	var tile: ClosetItemTile = _tile(item)
	assert_eq(tile.get_item(), item)
	assert_eq(tile.get_item_id(), &"hat_test")
	assert_eq((_node(tile, "%Art") as TextureRect).texture, item.icon)


func test_locked_look() -> void:
	var tile: ClosetItemTile = _tile(_item(&"hat_test", 300, false), ClosetItemTile.State.LOCKED)
	assert_eq(tile.get_state(), ClosetItemTile.State.LOCKED)
	assert_true((_node(tile, "%Question") as Label).visible, "the ? shows")
	assert_false((_node(tile, "%Art") as Control).visible)
	assert_false((_node(tile, "%Check") as CanvasItem).visible)
	assert_eq(_frame_fill(tile), ClosetItemTile.STONE)
	assert_null(_tag_fill(tile), "no tag box")
	var label: Label = _node(tile, "%TagLabel") as Label
	assert_eq(label.text, "300", "the price shows by row")
	assert_eq(label.get_theme_color(&"font_color"), ClosetItemTile.CHALK)


func test_an_unavailable_item_can_never_show_another_state() -> void:
	var tile: ClosetItemTile = _tile(_item(&"hat_test", 100, false), ClosetItemTile.State.WEARING)
	assert_eq(tile.get_state(), ClosetItemTile.State.LOCKED)
	assert_false((_node(tile, "%Check") as CanvasItem).visible)


func test_cant_afford_look() -> void:
	var tile: ClosetItemTile = _tile(_item(), ClosetItemTile.State.CANT_AFFORD)
	assert_false((_node(tile, "%Question") as Label).visible)
	assert_true((_node(tile, "%Art") as Control).visible)
	assert_false((_node(tile, "%Check") as CanvasItem).visible)
	assert_eq(_frame_fill(tile), ClosetItemTile.DISABLED_FILL)
	assert_null(_tag_fill(tile), "no tag box")
	var label: Label = _node(tile, "%TagLabel") as Label
	assert_eq(label.text, "100")
	assert_eq(label.get_theme_color(&"font_color"), ClosetItemTile.INK_MUTED)


func test_buy_look() -> void:
	var tile: ClosetItemTile = _tile(_item(), ClosetItemTile.State.BUY)
	assert_true((_node(tile, "%Art") as Control).visible)
	assert_false((_node(tile, "%Question") as Label).visible)
	assert_false((_node(tile, "%Check") as CanvasItem).visible)
	assert_eq(_frame_fill(tile), ClosetItemTile.PARCHMENT)
	assert_eq(_tag_fill(tile), ClosetItemTile.PUMPKIN)
	var label: Label = _node(tile, "%TagLabel") as Label
	assert_eq(label.text, "100", "the price on the pumpkin tag")
	assert_eq(label.get_theme_color(&"font_color"), ClosetItemTile.INK)


func test_wear_look() -> void:
	var tile: ClosetItemTile = _tile(_item(), ClosetItemTile.State.WEAR)
	assert_false((_node(tile, "%Check") as CanvasItem).visible)
	assert_eq(_frame_fill(tile), ClosetItemTile.PARCHMENT)
	assert_eq(_tag_fill(tile), ClosetItemTile.ZOMBIE_GREEN)
	assert_eq((_node(tile, "%TagLabel") as Label).text, "Wear")


func test_wearing_look() -> void:
	var tile: ClosetItemTile = _tile(_item(), ClosetItemTile.State.WEARING)
	assert_true((_node(tile, "%Check") as CanvasItem).visible, "the drawn check mark")
	assert_eq(_tag_fill(tile), ClosetItemTile.ZOMBIE_GREEN_BRIGHT)
	assert_eq((_node(tile, "%TagLabel") as Label).text, "", "no word on the tile")
	assert_false((_node(tile, "%Question") as Label).visible)


func test_state_set_before_add_child_applies_on_ready() -> void:
	var tile: ClosetItemTile = TileScene.instantiate() as ClosetItemTile
	tile.setup(_item())
	tile.show_state(ClosetItemTile.State.WEARING)
	add_child_autofree(tile)
	assert_eq(tile.get_state(), ClosetItemTile.State.WEARING)
	assert_true((_node(tile, "%Check") as CanvasItem).visible)


func test_the_tag_text_fits_at_16px() -> void:
	var tile: ClosetItemTile = _tile(_item(&"hat_test", 300), ClosetItemTile.State.WEAR)
	var label: Label = _node(tile, "%TagLabel") as Label
	assert_gte(label.get_theme_font_size(&"font_size"), 16)
	var font: Font = label.get_theme_font(&"font")
	for text: String in ["Wear", "100", "200", "300"]:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		assert_lte(width, label.size.x, "'%s' fits the tag" % text)
	var question: Label = _node(tile, "%Question") as Label
	assert_gte(question.get_theme_font_size(&"font_size"), 16)


# --- Input ---------------------------------------------------------------------------------------------

func test_accept_and_click_emit_on_buy_wear_and_wearing() -> void:
	for state: ClosetItemTile.State in [ClosetItemTile.State.BUY, ClosetItemTile.State.WEAR, ClosetItemTile.State.WEARING]:
		_activated = []
		var tile: ClosetItemTile = _tile(_item(), state)
		tile._gui_input(_accept())
		assert_eq(_activated, [&"hat_test"] as Array[StringName], "accept on %s" % state)
		tile._gui_input(_click())
		assert_eq(_activated, [&"hat_test", &"hat_test"] as Array[StringName], "click on %s" % state)
		assert_false(tile.is_wiggling())


func test_locked_and_cant_afford_only_wiggle_back_to_rest() -> void:
	var locked: ClosetItemTile = _tile(_item(&"hat_test", 100, false), ClosetItemTile.State.LOCKED)
	var poor: ClosetItemTile = _tile(_item(), ClosetItemTile.State.CANT_AFFORD)
	for tile: ClosetItemTile in [locked, poor]:
		tile._gui_input(_accept())
		assert_true(tile.is_wiggling())
		tile._gui_input(_click())
		assert_true(tile.is_wiggling(), "a second press restarts the wiggle")
	assert_eq(_activated, [] as Array[StringName])
	await wait_seconds(ClosetItemTile.WIGGLE_S + 0.1)
	for tile: ClosetItemTile in [locked, poor]:
		assert_false(tile.is_wiggling())
		assert_eq((_node(tile, "%Frame") as Control).position.x, 0.0, "ends exactly at rest")


func test_wiggle_moves_the_frame_sideways() -> void:
	var tile: ClosetItemTile = _tile(_item(), ClosetItemTile.State.CANT_AFFORD)
	tile._gui_input(_accept())
	var max_x: float = 0.0
	for i: int in 10:
		await wait_process_frames(1)
		max_x = maxf(max_x, absf((_node(tile, "%Frame") as Control).position.x))
	assert_gt(max_x, 0.0)
	assert_lte(max_x, ClosetItemTile.WIGGLE_PX)


func test_other_clicks_and_releases_do_nothing() -> void:
	var tile: ClosetItemTile = _tile(_item(), ClosetItemTile.State.BUY)
	tile._gui_input(_click(MOUSE_BUTTON_RIGHT))
	tile._gui_input(_click(MOUSE_BUTTON_LEFT, false))
	var release: InputEventAction = _accept()
	release.pressed = false
	tile._gui_input(release)
	assert_eq(_activated, [] as Array[StringName])


func test_focus_shows_the_ring_inside_the_tile() -> void:
	var tile: ClosetItemTile = _tile(_item())
	var ring: Panel = _node(tile, "%FocusRing") as Panel
	assert_false(ring.visible)
	tile.grab_focus()
	assert_true(ring.visible)
	assert_eq(ring.get_global_rect(), tile.get_global_rect(), "on the tile's own edge")
	var box: StyleBoxFlat = ring.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(box.border_width_left, 2)
	assert_eq(box.expand_margin_left, 0.0)
	tile.release_focus()
	assert_false(ring.visible)


func test_hover_moves_focus_only_on_real_motion() -> void:
	var tile: ClosetItemTile = _tile(_item(&"hat_test", 100, false), ClosetItemTile.State.LOCKED)
	tile.mouse_entered.emit()
	assert_false(tile.has_focus(), "a resting cursor must not steal focus")
	tile._gui_input(InputEventMouseMotion.new())
	assert_true(tile.has_focus(), "locked tiles stay focusable")


func test_hover_never_focuses_a_tile_switched_off_by_the_prompt() -> void:
	var tile: ClosetItemTile = _tile(_item())
	tile.focus_mode = Control.FOCUS_NONE
	tile._gui_input(InputEventMouseMotion.new())
	assert_false(tile.has_focus())


func test_only_the_tile_takes_the_mouse() -> void:
	var tile: ClosetItemTile = _tile(_item())
	assert_eq(tile.focus_mode, Control.FOCUS_ALL)
	assert_ne(tile.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(tile.size, Vector2(68, 68))
	var children: Array[Node] = tile.find_children("*", "Control", true, false)
	assert_gt(children.size(), 5)
	for child: Node in children:
		assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, String(child.name))
		assert_eq((child as Control).focus_mode, Control.FOCUS_NONE, String(child.name))


# --- Missing art ---------------------------------------------------------------------------------------

func test_available_item_without_icon_warns_once_and_shows_an_empty_box() -> void:
	var tile: ClosetItemTile = _tile(_item(&"hat_bare", 100, true, false), ClosetItemTile.State.BUY)
	assert_push_warning("closet tile: hat_bare has no icon")
	assert_push_warning_count(1)
	assert_null((_node(tile, "%Art") as TextureRect).texture)
	tile.show_state(ClosetItemTile.State.WEAR)
	tile.show_state(ClosetItemTile.State.BUY)
	assert_push_warning_count(1, "still once")
	assert_push_error_count(0)


func test_locked_item_without_icon_is_quiet() -> void:
	_tile(_item(&"hat_soon", 100, false, false), ClosetItemTile.State.LOCKED)
	assert_push_warning_count(0)


func test_null_item_logs_and_stays_locked() -> void:
	var tile: ClosetItemTile = _tile(null, ClosetItemTile.State.BUY)
	assert_push_error("ClosetItemTile.setup: null item")
	assert_eq(tile.get_state(), ClosetItemTile.State.LOCKED)
	assert_eq(tile.get_item_id(), &"")
	tile._activate()
	assert_eq(_activated, [] as Array[StringName])
