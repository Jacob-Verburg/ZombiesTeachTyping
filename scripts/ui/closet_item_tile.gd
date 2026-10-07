class_name ClosetItemTile
extends Control
## One Crypt Closet tile (Story 4.4; DESIGN.md / EXPERIENCE.md "closet-item-tile", approved sketch
## sketches/crypt-closet-4-4.md): a 68 px square with the item's 32 px art and a 64 px tag strip. It shows
## exactly one State, picked by the pure state_for() rule, with its own shape so the state never rests on
## colour alone. LOCKED: stone fill, a "?" and the price in chalk. CANT_AFFORD: disabled fill, the art and
## the price in ink-muted. BUY: the price on a pumpkin tag. WEAR: "Wear" on a zombie-green tag. WEARING: a
## check mark sprite (the font has none) on a zombie-green-bright tag. The long words ("Coming soon",
## "Need N more", "Wearing") don't fit a tile, so info_lines() gives them to the Closet's info sign.
## The tile shows what the Closet tells it and never touches PlayerData: Enter or a click on BUY, WEAR or
## WEARING emits activated(item_id), and the Closet acts; LOCKED and CANT_AFFORD only wiggle (no sound).
## Call setup() before add_child. Every child ignores the mouse, so the tile gets clicks and hover; real
## mouse motion moves focus here. The focused tile shows a 2 px candy-yellow ring just outside its ink edge.
## Story 5.0 art: the tile frames and tags are theme boxes (9-slices with stepped corners: TileParchment /
## TileStone / TileDisabled, TagPumpkin / TagGreen / TagBright, Bare for no tag), the "?" silhouette and the
## check are sprites, the ring is FocusRing and the drop shadow ShadowMd.
## Story 5.2 (grayscale review): the ring moved from FocusRingInset (on the edge) to FocusRing (2 px outside the
## ink edge): on the edge it vanished against the parchment without colour.

enum State { LOCKED, CANT_AFFORD, BUY, WEAR, WEARING }

signal activated(item_id: StringName)

## Look value, not a GDD number: how far a tile wiggles each way.
const WIGGLE_PX: float = 2.0
## Look value, not a GDD number: the whole wiggle, out and back.
const WIGGLE_S: float = 0.2

## Tag text colours (DESIGN.md Colors).
const INK: Color = Color("#1E1428")
const INK_MUTED: Color = Color("#4E4757")
const CHALK: Color = Color("#F4F1E4")
## The frame's and the tag's theme box per state (data/ui_theme.tres).
const FRAME_VARIATIONS: Dictionary[State, StringName] = {
	State.LOCKED: &"TileStone",
	State.CANT_AFFORD: &"TileDisabled",
	State.BUY: &"TileParchment",
	State.WEAR: &"TileParchment",
	State.WEARING: &"TileParchment",
}
const TAG_VARIATIONS: Dictionary[State, StringName] = {
	State.LOCKED: &"Bare",
	State.CANT_AFFORD: &"Bare",
	State.BUY: &"TagPumpkin",
	State.WEAR: &"TagGreen",
	State.WEARING: &"TagBright",
}

const WEAR_TEXT: String = "Wear"

var _item: CosmeticItem = null
var _state: State = State.LOCKED
var _wiggle_tween: Tween = null


func _ready() -> void:
	focus_entered.connect(_show_focus.bind(true))
	focus_exited.connect(_show_focus.bind(false))
	_show_focus(has_focus())
	_apply_art()
	show_state(_state)


## LOCKED wins over everything (an unavailable item can't be worn, like PlayerData.equip()), then
## WEARING, WEAR, BUY (brains == price is enough) and CANT_AFFORD.
static func state_for(item: CosmeticItem, brains: int, owned: bool, equipped_id: StringName) -> State:
	if item == null or not item.is_available:
		return State.LOCKED
	if owned and equipped_id == item.id:
		return State.WEARING
	if owned:
		return State.WEAR
	if brains >= item.price:
		return State.BUY
	return State.CANT_AFFORD


## How many more brains `item` needs; never negative.
static func need_more(item: CosmeticItem, brains: int) -> int:
	if item == null:
		return 0
	return maxi(item.price - brains, 0)


## The info sign's two lines for a tile: [name, state words]. A locked item stays a mystery.
static func info_lines(item: CosmeticItem, state: State, need: int) -> PackedStringArray:
	if item == null or state == State.LOCKED:
		return PackedStringArray(["Coming soon", ""])
	var words: String = ""
	match state:
		State.CANT_AFFORD:
			words = "Need %d more" % need
		State.BUY:
			words = "Buy"
		State.WEAR:
			words = WEAR_TEXT
		State.WEARING:
			words = "Wearing"
	return PackedStringArray([item.display_name, words])


## Fills the tile from its catalogue item. Call before add_child. An available item without an icon warns
## once and shows an empty art box (NFR16).
func setup(item: CosmeticItem) -> void:
	_item = item
	if item == null:
		Log.error(&"ui", "ClosetItemTile.setup: null item")
	elif item.is_available and item.icon == null:
		Log.warn(&"ui", "closet tile: %s has no icon" % item.id)
	if is_node_ready():
		_apply_art()
		show_state(_state)


## Shows one state's look. Never emits.
func show_state(state: State) -> void:
	if _item == null or not _item.is_available:
		state = State.LOCKED
	_state = state
	if not is_node_ready():
		return
	var locked: bool = state == State.LOCKED
	(%Frame as Panel).theme_type_variation = FRAME_VARIATIONS[state]
	(%Tag as Panel).theme_type_variation = TAG_VARIATIONS[state]
	%Art.visible = not locked
	%Question.visible = locked
	%Check.visible = state == State.WEARING
	var text_color: Color = INK
	var text: String = str(_item.price) if _item != null else ""
	match state:
		State.LOCKED:
			text_color = CHALK
		State.CANT_AFFORD:
			text_color = INK_MUTED
		State.WEAR:
			text = WEAR_TEXT
		State.WEARING:
			text = ""
	var label: Label = %TagLabel
	label.text = text
	label.add_theme_color_override(&"font_color", text_color)


func get_item() -> CosmeticItem:
	return _item


func get_item_id() -> StringName:
	return _item.id if _item != null else &""


func get_state() -> State:
	return _state


func is_wiggling() -> bool:
	return _wiggle_tween != null and _wiggle_tween.is_running()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus() and focus_mode != FOCUS_NONE:
		grab_focus()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed(&"ui_accept"):
		_activate()
		accept_event()


func _activate() -> void:
	match _state:
		State.BUY, State.WEAR, State.WEARING:
			activated.emit(get_item_id())
		_:
			_wiggle()


## One wiggle, ending exactly at rest; a new one replaces a running one.
func _wiggle() -> void:
	if _wiggle_tween != null:
		_wiggle_tween.kill()
	var frame: Control = %Frame
	frame.position.x = 0.0
	_wiggle_tween = create_tween()
	_wiggle_tween.tween_property(frame, ^"position:x", WIGGLE_PX, WIGGLE_S / 4.0)
	_wiggle_tween.tween_property(frame, ^"position:x", -WIGGLE_PX, WIGGLE_S / 2.0)
	_wiggle_tween.tween_property(frame, ^"position:x", 0.0, WIGGLE_S / 4.0)


func _apply_art() -> void:
	(%Art as TextureRect).texture = _item.icon if _item != null else null


func _show_focus(focused: bool) -> void:
	# focus_exited also fires while the tile is being freed, after its children are gone.
	var ring: Control = get_node_or_null(^"%FocusRing") as Control
	if ring != null:
		ring.visible = focused

