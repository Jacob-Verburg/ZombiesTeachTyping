extends GutTest
## Grayscale states (Story 5.2, AC 2, NFR8): every state DESIGN.md / EXPERIENCE.md say must "read without hue"
## is carried by shape, content, motion or brightness, never hue alone. The screenshots are made by
## tools/capture_screens.gd (color + grayscale, 640×360, _bmad-output/implementation-artifacts/screenshots/5-2/);
## these tests keep what the review found from regressing. Read through public APIs and node visibility, not
## pixels. Grayscale is stricter than any colour-vision type (it removes all hue), so passing it covers
## protan / deutan / tritan kids for state reading.
##
## Palette luma (Rec. 709 on sRGB, test_art_ui.gd::_luma): ink 0.092 · night 0.135 · wood-dark 0.222 ·
## dusk 0.234 · stamp-red 0.275 · ink-muted 0.289 · zombie-green-dark 0.349 · wood 0.356 · stone 0.426 ·
## pumpkin 0.550 · zombie-green 0.655 · pumpkin-light 0.708 · stone-light 0.724 · parchment-shade 0.746 ·
## disabled-fill 0.779 · candy-yellow 0.819 · zombie-green-bright 0.867 · parchment 0.908 · chalk 0.944.
## Buy (pumpkin 0.550) vs Wear (green 0.655) tags are only 0.105 apart: they stay apart by content (a price
## number vs the word "Wear"), which the tile test below pins. The candy ring (0.819) is weak against
## parchment (0.908) by brightness alone, so every focus ring is drawn OUTSIDE an ink edge (0.092): a light
## rim beyond a dark one (the Closet tile moved there in this story's review).
## Covered elsewhere, referenced by the Grayscale Checklist: the lit finger's luma gap
## (test_art_ui.gd::test_lit_finger_is_brighter_in_grayscale), the toggle-off slash (test_menu_toggle.gd), the
## Coming soon plank (test_level_card.gd).

const TileScene: PackedScene = preload("res://scenes/ui/closet_item_tile.tscn")
const CardScene: PackedScene = preload("res://scenes/ui/level_card.tscn")
const ToggleScene: PackedScene = preload("res://scenes/ui/menu_toggle.tscn")
const HudScene: PackedScene = preload("res://scenes/run/hud.tscn")
const RING_TEXTURE: String = "res://assets/sprites/ui/common/ui_focus_ring.png"
const STATES: Array[ClosetItemTile.State] = [
	ClosetItemTile.State.LOCKED, ClosetItemTile.State.CANT_AFFORD, ClosetItemTile.State.BUY,
	ClosetItemTile.State.WEAR, ClosetItemTile.State.WEARING,
]


func _item() -> CosmeticItem:
	var item: CosmeticItem = CosmeticItem.new()
	item.id = &"hat_test"
	item.display_name = "Test hat"
	item.price = 100
	item.row = 1
	item.is_available = true
	item.icon = PlaceholderTexture2D.new()
	return item


## What a kid sees on a tile with the colour taken away: the "?" or the art, a tag box or none, a number, the
## word, the check. Frame and tag fills are left out on purpose: they only add brightness on top.
func _signature(tile: ClosetItemTile) -> String:
	var tag: Panel = tile.get_node("%Tag") as Panel
	var text: String = (tile.get_node("%TagLabel") as Label).text
	var kind: String = "empty"
	if text.is_valid_int():
		kind = "number"
	elif not text.is_empty():
		kind = "word:" + text
	return "q=%s art=%s box=%s check=%s text=%s" % [
		(tile.get_node("%Question") as CanvasItem).visible, (tile.get_node("%Art") as CanvasItem).visible,
		tag.theme_type_variation != &"Bare", (tile.get_node("%Check") as CanvasItem).visible, kind]


func test_the_five_tile_states_differ_by_shape_or_content() -> void:
	var tile: ClosetItemTile = TileScene.instantiate() as ClosetItemTile
	tile.setup(_item())
	add_child_autofree(tile)
	var seen: Dictionary[String, ClosetItemTile.State] = {}
	for state: ClosetItemTile.State in STATES:
		tile.show_state(state)
		var signature: String = _signature(tile)
		assert_false(seen.has(signature), "%s looks like %s without colour: %s" % [
				ClosetItemTile.State.keys()[state], ClosetItemTile.State.keys()[seen.get(signature, 0)], signature])
		seen[signature] = state
	assert_eq(seen.size(), 5)


## The focus box of every focusable kind is the stepped candy ring drawn outside the control's ink edge.
func _assert_outside_ring(box: StyleBox, what: String) -> void:
	var ring: StyleBoxTexture = box as StyleBoxTexture
	assert_not_null(ring, "%s focus is the ring 9-slice" % what)
	if ring == null:
		return
	assert_eq(ring.texture.resource_path, RING_TEXTURE, "%s uses the candy ring" % what)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_gte(ring.get_expand_margin(side), 2.0, "%s ring sits outside the ink edge" % what)


func test_every_focusable_kind_shows_the_ring_outside_its_edge() -> void:
	var button: Button = Button.new()
	button.theme_type_variation = &"PixelButton"
	button.text = "Menu"
	add_child_autofree(button)
	_assert_outside_ring(button.get_theme_stylebox(&"focus"), "PixelButton")

	var toggle: MenuToggle = ToggleScene.instantiate() as MenuToggle
	add_child_autofree(toggle)
	_assert_outside_ring(toggle.get_focus_target().get_theme_stylebox(&"focus"), "MenuToggle")

	var entry: LevelEntry = LevelEntry.new()
	entry.id = &"zombie_run"
	entry.display_name = "Zombie Run"
	entry.available = true
	var card: LevelCard = CardScene.instantiate() as LevelCard
	card.setup(entry)
	add_child_autofree(card)
	card.grab_focus()
	var card_ring: Panel = card.get_node("%FocusRing") as Panel
	assert_true(card_ring.visible, "the card shows its ring on focus")
	_assert_outside_ring(card_ring.get_theme_stylebox(&"panel"), "LevelCard")

	var tile: ClosetItemTile = TileScene.instantiate() as ClosetItemTile
	tile.setup(_item())
	add_child_autofree(tile)
	tile.grab_focus()
	var tile_ring: Panel = tile.get_node("%FocusRing") as Panel
	assert_true(tile_ring.visible, "the tile shows its ring on focus")
	_assert_outside_ring(tile_ring.get_theme_stylebox(&"panel"), "ClosetItemTile")


## FR2: a wrong key moves only the glyph. No colour, modulate or sign change at any point of the shake.
func test_wrong_key_shake_changes_position_only() -> void:
	var hud: Control = HudScene.instantiate() as Control
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hud)
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = 120.0
	config.target_mode = LevelConfig.TargetMode.LETTER
	hud.call("setup", config, "k")
	var label: Label = hud.get_node("%TargetLabel") as Label
	var sign_panel: Control = hud.get_node("%TargetSign") as Control
	var look: Array = [label.get_theme_color(&"font_color"), label.modulate, label.self_modulate,
			sign_panel.modulate, sign_panel.self_modulate, sign_panel.get_theme_stylebox(&"panel"),
			label.get_theme_font_size(&"font_size")]
	var rest_x: float = label.position.x
	hud.call("shake_target")
	var moved: bool = false
	for i: int in 16:
		var now: Array = [label.get_theme_color(&"font_color"), label.modulate, label.self_modulate,
				sign_panel.modulate, sign_panel.self_modulate, sign_panel.get_theme_stylebox(&"panel"),
				label.get_theme_font_size(&"font_size")]
		assert_eq(now, look, "frame %d: the look is unchanged (no red, no flash)" % i)
		moved = moved or label.position.x != rest_x
		hud._process(GameConstants.WRONG_KEY_SHAKE_S / 8.0)
	assert_true(moved, "the glyph moved")
	assert_eq(label.position.x, rest_x, "and settled back")


## Story 6.2 (NFR8): in word mode the typed letters (zombie-green-dark) read apart from the untyped ones
## (ink) by brightness, and the next letter carries a shape cue, the underline, not colour alone.
func test_word_progress_reads_without_hue() -> void:
	var hud: Control = HudScene.instantiate() as Control
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hud)
	var config: LevelConfig = LevelConfig.new()
	config.duration_s = 120.0
	config.target_mode = LevelConfig.TargetMode.WORD
	hud.call("setup", config, "dad")
	hud.call("show_target", "dad", 1)
	var typed: Color = (hud.get_node("%TypedLabel") as Label).get_theme_color(&"font_color")
	var untyped: Color = (hud.get_node("%TargetLabel") as Label).get_theme_color(&"font_color")
	assert_almost_eq(_luma(typed), 0.349, 0.002, "typed is zombie-green-dark")
	assert_almost_eq(_luma(untyped), 0.092, 0.002, "untyped is ink")
	assert_true(_luma(typed) - _luma(untyped) > 0.2, "typed vs untyped differ in luma")
	assert_true((hud.get_node("%NextUnderline") as Control).visible, "the next letter is underlined")


## Rec. 709 on sRGB, as test_art_ui.gd::_luma.
func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
