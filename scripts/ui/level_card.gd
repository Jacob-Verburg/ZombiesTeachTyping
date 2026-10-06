class_name LevelCard
extends Control
## One level card on the main menu (Story 4.2; DESIGN.md / EXPERIENCE.md "level card"): a picture in a
## wooden frame with the level's name on a parchment sign. Every card is this one scene; its State picks
## the look. AVAILABLE: Enter or a click emits chosen(level_id). COMING_SOON: a stone tint and a wooden
## "Coming soon" plank over the picture, a greyed sign; it stays focusable and Enter or a click only
## wiggles it (no sound, no signal). The focused card shows a 2 px candy-yellow ring and lifts 2 px.
## Call setup() before add_child (architecture Entity Patterns). The menu's HBoxContainer owns the card's
## own position, so the lift and the wiggle move the inner %Frame, never the card.
## Every child ignores the mouse, so the card itself gets clicks and hover; real mouse motion moves focus here (a resting cursor never does).
## Placeholder chrome until Story 5.0 (card art, the focus bob).

## Story 6.8 adds LOCKED and NEW; COMING_SOON wins over LOCKED.
enum State { AVAILABLE, COMING_SOON }

signal chosen(level_id: StringName)

## Look value, not a GDD number: how far a focused card's frame lifts.
const LIFT_PX: float = 2.0
## Look value, not a GDD number: how far a Coming soon card wiggles each way.
const WIGGLE_PX: float = 2.0
## Look value, not a GDD number: the whole wiggle, out and back.
const WIGGLE_S: float = 0.2

## The name sign's box (parchment), and the greyed one (stone-light) a Coming soon card swaps in.
@export var sign_style: StyleBox
@export var sign_coming_soon_style: StyleBox

var _level_id: StringName = &""
var _state: State = State.COMING_SOON
var _wiggle_tween: Tween = null


func _ready() -> void:
	focus_entered.connect(_show_focus.bind(true))
	focus_exited.connect(_show_focus.bind(false))
	_show_focus(has_focus())


## Fills the card from its registry entry. Call before add_child.
func setup(entry: LevelEntry) -> void:
	if entry == null:
		Log.error(&"ui", "LevelCard.setup: null entry")
		return
	_level_id = entry.id
	%NameLabel.text = entry.display_name if not entry.display_name.is_empty() else String(entry.id).capitalize()
	%Picture.texture = entry.card_picture
	_set_state(State.AVAILABLE if entry.available else State.COMING_SOON)


func get_state() -> State:
	return _state


func get_level_id() -> StringName:
	return _level_id


func is_wiggling() -> bool:
	return _wiggle_tween != null and _wiggle_tween.is_running()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus():
		grab_focus()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed(&"ui_accept"):
		_activate()
		accept_event()


func _set_state(state: State) -> void:
	_state = state
	var coming_soon: bool = state == State.COMING_SOON
	%Tint.visible = coming_soon
	%ComingSoonPlank.visible = coming_soon
	var style: StyleBox = sign_coming_soon_style if coming_soon else sign_style
	if style != null:
		%NameSign.add_theme_stylebox_override(&"panel", style)


func _activate() -> void:
	if _state == State.AVAILABLE:
		chosen.emit(_level_id)
	else:
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


func _show_focus(focused: bool) -> void:
	# focus_exited also fires while the card is being freed, after its children are gone.
	var ring: Control = get_node_or_null(^"%FocusRing") as Control
	var frame: Control = get_node_or_null(^"%Frame") as Control
	if ring == null or frame == null:
		return
	ring.visible = focused
	frame.position.y = -LIFT_PX if focused else 0.0
