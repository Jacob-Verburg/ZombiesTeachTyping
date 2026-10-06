class_name LevelCard
extends Control
## One level card on the main menu (Story 4.2; DESIGN.md / EXPERIENCE.md "level card"): a picture in a
## wooden frame with the level's name on a parchment sign. Every card is this one scene; its State picks
## the look. AVAILABLE: Enter or a click emits chosen(level_id). COMING_SOON: a stone tint and a wooden
## "Coming soon" plank over the picture, a greyed sign; it stays focusable and Enter or a click only
## wiggles it (no sound, no signal). The focused card shows a 2 px candy-yellow ring, lifts 2 px and bobs 1 px
## more while it keeps focus (EXPERIENCE "lifts 2 px with a gentle bob"); unfocused, the frame is back at 0.
## Call setup() before add_child (architecture Entity Patterns). The menu's HBoxContainer owns the card's
## own position, so the lift and the wiggle move the inner %Frame, never the card.
## Every child ignores the mouse, so the card itself gets clicks and hover; real mouse motion moves focus here (a resting cursor never does).
## Story 5.0 art: the CardFrame / Sign / SignGrey / FocusRing / ShadowLg theme boxes, the level's picture
## (ui_level_card_<id>.png) and the hand-lettered "Coming soon" plank sprite; the name stays font text.

## Story 6.8 adds LOCKED and NEW; COMING_SOON wins over LOCKED.
enum State { AVAILABLE, COMING_SOON }

signal chosen(level_id: StringName)

## Look value, not a GDD number: how far a focused card's frame lifts.
const LIFT_PX: float = 2.0
## Look value, not a GDD number: how far a Coming soon card wiggles each way.
const WIGGLE_PX: float = 2.0
## Look value, not a GDD number: the whole wiggle, out and back.
const WIGGLE_S: float = 0.2

## Look value, not a GDD number: the focus bob's extra lift, on top of LIFT_PX.
const BOB_PX: float = 1.0
## Look value, not a GDD number: one bob, up and back.
const BOB_PERIOD_S: float = 0.5
## The name sign's theme box: parchment, and the greyed one a Coming soon card swaps in.
const SIGN_VARIATION: StringName = &"Sign"
const SIGN_COMING_SOON_VARIATION: StringName = &"SignGrey"

var _level_id: StringName = &""
var _state: State = State.COMING_SOON
var _wiggle_tween: Tween = null
var _bob_s: float = 0.0


func _ready() -> void:
	focus_entered.connect(_show_focus.bind(true))
	focus_exited.connect(_show_focus.bind(false))
	_show_focus(has_focus())


## The focus bob: whole pixels, the lift plus 0 or BOB_PX, never touching position.x (the wiggle owns x).
func _process(delta: float) -> void:
	_bob_s = fmod(_bob_s + delta, BOB_PERIOD_S)
	var frame: Control = get_node_or_null(^"%Frame") as Control
	if frame != null:
		frame.position.y = -LIFT_PX - (BOB_PX if _bob_s >= BOB_PERIOD_S / 2.0 else 0.0)


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
	%NameSign.theme_type_variation = SIGN_COMING_SOON_VARIATION if coming_soon else SIGN_VARIATION


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
	_bob_s = 0.0
	frame.position.y = -LIFT_PX if focused else 0.0
	set_process(focused)
