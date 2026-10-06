extends Control
## The Crypt Closet (Story 4.4, FR39-FR43; approved sketch sketches/crypt-closet-4-4.md): the 3x3 hat grid
## on the left and the 3x3 pet grid on the right, one ClosetItemTile per Catalogue.items_for_slot() item in
## grid order, the preview zombie and pet in the mirror between them, the brain counter, a Menu button and
## the info sign, which spells out the focused tile's name and state (the long words don't fit a tile).
## Each tile's state comes from ClosetItemTile.state_for(); the tiles never touch PlayerData. Enter or a
## click on Buy opens the ConfirmPrompt ("Buy the <name> for <price> brains?", Yes focused); Yes calls
## PlayerData.buy_item() (which requests the save) and plays the purchase jingle. Wear / Wearing call
## equip() / unequip(). The counter, the tiles and the preview refresh from PlayerData's signals, never
## after a call, so a debug F5/F8 change shows at once too.
## Preview: both slots have follow_equipped = false (set in crypt_closet.tscn, because children are ready
## before this script) and only show what show_item() gives them: the focused available tile's item in its
## slot, the equipped item in the other. A Locked item is never shown (it has no art).
## Focus: on open, the first hat tile. Arrows move inside a grid; Right from a hat in the right column goes
## to the pet in the left column of the same row, and back; Up from the top row goes to Menu; Menu Down goes
## to the pet tile under it; outer edges stop. Hover moves focus (tiles and PixelButton do it).
## While the prompt is open, every tile and the Menu button are FOCUS_NONE, and the scrim eats clicks.
## Esc: back to the menu, except while the prompt is open, where Esc = No. This script owns Esc.
## Seams (tests assign them before add_child): navigate, is_transitioning, player_data, play_sfx and the
## exported catalogue. The payload is consumed (Story 4.5 reads a tutorial flag from it).
## Later: the tutorial arrow (4.5; get_tile() and get_confirm_prompt() are its hooks), final art and juice
## (5.0 / 5.1), Closet music (5.1).

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const TILE_SCENE: PackedScene = preload("res://scenes/ui/closet_item_tile.tscn")
## The pet tile under the Menu button (Menu Down goes there).
const MENU_DOWN_PET_INDEX: int = 2

## Every Closet item (data/cosmetics/catalogue.tres, set in crypt_closet.tscn).
@export var catalogue: Catalogue

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready.
var navigate: Callable
## Test seam: defaults to Router.is_transitioning in _ready.
var is_transitioning: Callable
## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null
## Test seam: called as play_sfx.call(cue_id). Defaults to AudioManager.play_sfx in _ready.
var play_sfx: Callable

var _hat_tiles: Array[ClosetItemTile] = []
var _pet_tiles: Array[ClosetItemTile] = []
## The tile the info sign and the preview follow; null while Menu has focus.
var _focused_tile: ClosetItemTile = null
## The item the open prompt asks about.
var _pending: CosmeticItem = null
## Set by the one navigation; nothing navigates after it.
var _leaving: bool = false


func _ready() -> void:
	if not navigate.is_valid():
		navigate = Router.go
	if not is_transitioning.is_valid():
		is_transitioning = Router.is_transitioning
	if player_data == null:
		player_data = PlayerData
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	Router.take_payload()
	_build_tiles()
	player_data.brains_changed.connect(_on_brains_changed)
	player_data.inventory_changed.connect(_on_inventory_changed)
	player_data.equipment_changed.connect(_on_equipment_changed)
	player_data.profile_replaced.connect(_on_profile_replaced)
	%MenuButton.pressed.connect(_leave)
	%MenuButton.focus_entered.connect(_on_menu_focused)
	%ConfirmPrompt.answered.connect(_on_confirm_answered)
	_wire_focus()
	var tiles: Array[ClosetItemTile] = get_tiles()
	if tiles.is_empty():
		%MenuButton.grab_focus()
	else:
		_focused_tile = tiles[0]
		tiles[0].grab_focus()
	_refresh()


func _exit_tree() -> void:
	if player_data == null:
		return
	if player_data.brains_changed.is_connected(_on_brains_changed):
		player_data.brains_changed.disconnect(_on_brains_changed)
	if player_data.inventory_changed.is_connected(_on_inventory_changed):
		player_data.inventory_changed.disconnect(_on_inventory_changed)
	if player_data.equipment_changed.is_connected(_on_equipment_changed):
		player_data.equipment_changed.disconnect(_on_equipment_changed)
	if player_data.profile_replaced.is_connected(_on_profile_replaced):
		player_data.profile_replaced.disconnect(_on_profile_replaced)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if %ConfirmPrompt.is_open():
		%ConfirmPrompt.cancel()
	else:
		_leave()


## Every tile: hats 0..8, then pets 0..8.
func get_tiles() -> Array[ClosetItemTile]:
	return _hat_tiles + _pet_tiles


## The tile for `item_id`, or null.
func get_tile(item_id: StringName) -> ClosetItemTile:
	for tile: ClosetItemTile in get_tiles():
		if tile.get_item_id() == item_id:
			return tile
	return null


func get_confirm_prompt() -> ConfirmPrompt:
	return %ConfirmPrompt


func _build_tiles() -> void:
	if catalogue == null:
		Log.error(&"ui", "crypt closet: no catalogue")
		return
	var problem: String = catalogue.validate()
	if not problem.is_empty():
		Log.error(&"ui", "crypt closet: invalid catalogue: %s" % problem)
		return
	_hat_tiles = _build_grid(catalogue.items_for_slot(CosmeticItem.Slot.HAT), %HatGrid)
	_pet_tiles = _build_grid(catalogue.items_for_slot(CosmeticItem.Slot.PET), %PetGrid)


func _build_grid(items: Array[CosmeticItem], grid: GridContainer) -> Array[ClosetItemTile]:
	var tiles: Array[ClosetItemTile] = []
	for item: CosmeticItem in items:
		var tile: ClosetItemTile = TILE_SCENE.instantiate() as ClosetItemTile
		tile.setup(item)
		tile.activated.connect(_on_tile_activated)
		tile.focus_entered.connect(_on_tile_focused.bind(tile))
		grid.add_child(tile)
		tiles.append(tile)
	return tiles


## Arrows inside each grid by row and column, hats <-> pets across the middle, Up to Menu from the top row,
## Menu Down to the pet tile under it; every other edge points at itself (stops). Tab walks hats, pets,
## Menu and wraps.
func _wire_focus() -> void:
	var columns: int = Catalogue.GRID_COLUMNS
	var menu: Control = %MenuButton
	var none: Array[ClosetItemTile] = []
	_wire_grid(_hat_tiles, none, _pet_tiles, columns, menu)
	_wire_grid(_pet_tiles, _hat_tiles, none, columns, menu)
	var own: NodePath = menu.get_path_to(menu)
	menu.focus_neighbor_left = own
	menu.focus_neighbor_right = own
	menu.focus_neighbor_top = own
	var below: Control = _tile_at(_pet_tiles, MENU_DOWN_PET_INDEX)
	if below == null:
		below = _tile_at(_hat_tiles, 0)
	menu.focus_neighbor_bottom = menu.get_path_to(below) if below != null else own
	var order: Array[Control] = []
	order.assign(get_tiles())
	order.append(menu)
	for i: int in order.size():
		var control: Control = order[i]
		control.focus_next = control.get_path_to(order[(i + 1) % order.size()])
		control.focus_previous = control.get_path_to(order[i - 1])


## `left_grid` / `right_grid`: the grid across that edge (empty = the edge stops).
func _wire_grid(tiles: Array[ClosetItemTile], left_grid: Array[ClosetItemTile], right_grid: Array[ClosetItemTile],
		columns: int, menu: Control) -> void:
	for i: int in tiles.size():
		var tile: ClosetItemTile = tiles[i]
		@warning_ignore("integer_division")
		var row: int = i / columns
		var col: int = i % columns
		var left: Control = _tile_at(tiles, i - 1) if col > 0 else _tile_at(left_grid, row * columns + columns - 1)
		var right: Control = _tile_at(tiles, i + 1) if col < columns - 1 else _tile_at(right_grid, row * columns)
		var up: Control = _tile_at(tiles, i - columns) if row > 0 else menu
		var down: Control = _tile_at(tiles, i + columns)
		tile.focus_neighbor_left = tile.get_path_to(left if left != null else tile)
		tile.focus_neighbor_right = tile.get_path_to(right if right != null else tile)
		tile.focus_neighbor_top = tile.get_path_to(up if up != null else tile)
		tile.focus_neighbor_bottom = tile.get_path_to(down if down != null else tile)


func _tile_at(tiles: Array[ClosetItemTile], index: int) -> ClosetItemTile:
	if index < 0 or index >= tiles.size():
		return null
	return tiles[index]


## Re-reads the wallet, the inventory and the equipment: the counter, every tile, the info sign and the
## preview. On open and on every PlayerData signal.
func _refresh() -> void:
	var brains: int = player_data.get_brains()
	%BrainCounter.set_count(brains)
	for tile: ClosetItemTile in get_tiles():
		var item: CosmeticItem = tile.get_item()
		tile.show_state(_state_of(item, brains))
	_show_info()
	_show_preview()


func _state_of(item: CosmeticItem, brains: int) -> ClosetItemTile.State:
	if item == null:
		return ClosetItemTile.State.LOCKED
	return ClosetItemTile.state_for(item, brains, player_data.owns(item.id), player_data.get_equipped(item.slot_key()))


func _show_info() -> void:
	var lines: PackedStringArray = PackedStringArray(["", ""])
	if _focused_tile != null:
		lines = ClosetItemTile.info_lines(_focused_tile.get_item(), _focused_tile.get_state(),
			ClosetItemTile.need_more(_focused_tile.get_item(), player_data.get_brains()))
	%InfoName.text = lines[0]
	%InfoState.text = lines[1]


## The focused available tile's item in its slot, the equipped item in the other. Never a Locked item.
func _show_preview() -> void:
	var hat: CosmeticItem = _equipped_item(CosmeticItem.SLOT_HAT)
	var pet: CosmeticItem = _equipped_item(CosmeticItem.SLOT_PET)
	var focused: CosmeticItem = _focused_tile.get_item() if _focused_tile != null else null
	if focused != null and focused.is_available:
		if focused.slot == CosmeticItem.Slot.HAT:
			hat = focused
		else:
			pet = focused
	(%PreviewZombie.get_node("%HatSlot") as HatSlot).show_item(hat)
	(%PreviewPet as PetSlot).show_item(pet)


func _equipped_item(slot: StringName) -> CosmeticItem:
	if catalogue == null:
		return null
	return catalogue.get_item(player_data.get_equipped(slot))


## Tiles and Menu can't take focus while the prompt is open (and can again after).
func _set_background_focus(enabled: bool) -> void:
	var mode: FocusMode = FOCUS_ALL if enabled else FOCUS_NONE
	for tile: ClosetItemTile in get_tiles():
		tile.focus_mode = mode
	%MenuButton.focus_mode = mode


func _on_tile_focused(tile: ClosetItemTile) -> void:
	_focused_tile = tile
	_show_info()
	_show_preview()


func _on_menu_focused() -> void:
	_focused_tile = null
	_show_info()
	_show_preview()


## Acts on the item's state now, not the tile's last look.
func _on_tile_activated(item_id: StringName) -> void:
	if %ConfirmPrompt.is_open():
		return
	var tile: ClosetItemTile = get_tile(item_id)
	if tile == null:
		return
	var item: CosmeticItem = tile.get_item()
	match _state_of(item, player_data.get_brains()):
		ClosetItemTile.State.BUY:
			_pending = item
			%ConfirmPrompt.open("Buy the %s for %d brains?" % [item.display_name, item.price])
			_set_background_focus(false)
		ClosetItemTile.State.WEAR:
			if player_data.equip(item_id):
				play_sfx.call(&"sfx_ui_click")
			else:
				_refresh()
		ClosetItemTile.State.WEARING:
			player_data.unequip(item.slot_key())
			play_sfx.call(&"sfx_ui_click")
		_:
			_refresh()


func _on_confirm_answered(yes: bool) -> void:
	var item: CosmeticItem = _pending
	_pending = null
	_set_background_focus(true)
	var tile: ClosetItemTile = get_tile(item.id) if item != null else null
	if tile != null:
		tile.grab_focus()
	else:
		%MenuButton.grab_focus()
	if not yes or item == null:
		return
	var result: PlayerDataScript.PurchaseResult = player_data.buy_item(item)
	if result == PlayerDataScript.PurchaseResult.OK:
		play_sfx.call(&"sfx_purchase")
		return
	Log.warn(&"economy", "closet: unexpected buy result %s for %s" % [PlayerDataScript.PurchaseResult.keys()[result], item.id])
	_refresh()


## The wallet or the inventory changed under an open prompt: its question is out of date, so it counts as No.
func _cancel_stale_prompt() -> void:
	if %ConfirmPrompt.is_open():
		%ConfirmPrompt.cancel()


func _on_brains_changed(_total: int, _delta: int) -> void:
	_cancel_stale_prompt()
	_refresh()


func _on_inventory_changed(_item_id: StringName) -> void:
	_cancel_stale_prompt()
	_refresh()


func _on_profile_replaced() -> void:
	_cancel_stale_prompt()
	_refresh()


func _on_equipment_changed(_slot: StringName, _item_id: StringName) -> void:
	_refresh()


## The only navigation, at most once. If the Router starts a transition that ends without freeing this
## screen (the target failed to load), the guard is released so the Closet is not left dead.
func _leave() -> void:
	if _leaving or is_transitioning.call():
		return
	_leaving = true
	play_sfx.call(&"sfx_ui_click")
	navigate.call(Router.Screen.MAIN_MENU, {})
	if not is_transitioning.call():
		return
	# A successful change frees this screen, and a coroutine must not wake up on a freed instance, so the
	# wait is a frame-signal callback (never resumed once the screen is gone) that unhooks itself.
	get_tree().process_frame.connect(_release_leave_when_idle)


func _release_leave_when_idle() -> void:
	if is_transitioning.call():
		return
	get_tree().process_frame.disconnect(_release_leave_when_idle)
	_leaving = false
