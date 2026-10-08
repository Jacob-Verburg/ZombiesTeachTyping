class_name LevelCard
extends Control
## One level card on the main menu (Story 4.2; DESIGN.md / EXPERIENCE.md "level card"): a picture in a
## wooden frame with the level's name on a parchment sign. Every card is this one scene; its State picks
## the look. Precedence (state_for): COMING_SOON > LOCKED > NEW > AVAILABLE (FR26, FR79).
## AVAILABLE: Enter or a click emits chosen(level_id). NEW (Story 6.8): the same, plus a pumpkin "New!" badge
## on the frame's top-right corner until the level is first chosen. COMING_SOON: a stone tint and a wooden
## "Coming soon" plank over the picture, a greyed sign. LOCKED (Story 6.8): a dusk tint and a big padlock over
## the picture, a normal sign; while it has focus a parchment hint sign ("Finish Zombie Run to open!", text
## from set_hint_text) hangs below the card on two strings. COMING_SOON and LOCKED stay focusable and Enter
## or a click only wiggles them (no sound, no signal). Locked and Coming soon differ by shape (padlock vs
## plank), not only by hue.
## The unlock moment (Story 6.8, EXPERIENCE "Level Unlocks"): play_unlock_moment() runs on a LOCKED-looking
## card: a short beat, the padlock wiggles, pops off and falls away, the tint clears, the badge thumps on with
## the jingle (play_sfx seam), and the card ends NEW. finish_unlock_moment() snaps to that end at once. Both
## emit unlock_moment_finished once. The tween belongs to the card, so it waits while the Router's fade
## has the tree paused.
## The focused card shows a 2 px candy-yellow ring, lifts 2 px and bobs 1 px more while it keeps focus
## (EXPERIENCE "lifts 2 px with a gentle bob"); unfocused, the frame is back at 0.
## Call setup() before add_child (architecture Entity Patterns). The menu's HBoxContainer owns the card's
## own position, so the lift and the wiggle move the inner %Frame, never the card. The hint is a card child
## outside %Frame (it doesn't lift or wiggle); it is clamped into the 16 px screen margin and drawn over
## later siblings (z_index), e.g. the menu's storage notice.
## Every child ignores the mouse, so the card itself gets clicks and hover; real mouse motion moves focus here (a resting cursor never does).
## Story 5.0 art: the CardFrame / Sign / SignGrey / FocusRing / ShadowLg theme boxes, the level's picture
## (ui_level_card_<id>.png) and the hand-lettered "Coming soon" plank sprite; the name stays font text.

## Append only: tests and saves of state values rely on the order.
enum State { AVAILABLE, COMING_SOON, LOCKED, NEW }

signal chosen(level_id: StringName)
## The unlock moment ended, by itself or through finish_unlock_moment().
signal unlock_moment_finished(level_id: StringName)

## Look value, not a GDD number: how far a focused card's frame lifts.
const LIFT_PX: float = 2.0
## Look value, not a GDD number: how far a Coming soon / Locked card (and the moment's padlock) wiggles.
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
## Picture tints: stone for Coming soon, dusk for Locked (DESIGN.md colors), same alpha.
const TINT_ALPHA: float = 0.85
const TINT_COMING_SOON: Color = Color(0.43529412, 0.41568628, 0.5019608, TINT_ALPHA)
const TINT_LOCKED: Color = Color(0.2901961, 0.2, 0.4, TINT_ALPHA)
## Where %Padlock rests in level_card.tscn: centred on the 184 x 72 picture (4..188 x 4..76).
const PADLOCK_REST: Vector2 = Vector2(80, 20)
## The screen's 16 px margin rect (640 x 360 logical); the hint sign never leaves it.
const MARGIN_RECT: Rect2 = Rect2(16, 16, 608, 328)

## Look value, not a GDD number: the pause after the menu's fade-in before the moment starts.
const MOMENT_BEAT_S: float = 0.3
## Look value, not a GDD number: the padlock's pop up, then its fall (with the fade).
const PADLOCK_POP_PX: float = 6.0
const PADLOCK_POP_S: float = 0.1
const PADLOCK_FALL_PX: float = 24.0
const PADLOCK_FALL_S: float = 0.25
## Look value, not a GDD number: the dusk tint clearing.
const TINT_CLEAR_S: float = 0.3
## Look value, not a GDD number: the badge thump, from this scale down to 1.
const BADGE_THUMP_SCALE: float = 1.4
const BADGE_THUMP_S: float = 0.15
const JINGLE_ID: StringName = &"sfx_unlock_jingle"

## Test seam: called as play_sfx.call(id) for the moment's jingle. Defaults to AudioManager.play_sfx.
var play_sfx: Callable

var _level_id: StringName = &""
var _state: State = State.COMING_SOON
var _wiggle_tween: Tween = null
var _moment_tween: Tween = null
var _jingle_played: bool = false
var _bob_s: float = 0.0


func _ready() -> void:
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	focus_entered.connect(_show_focus.bind(true))
	focus_exited.connect(_show_focus.bind(false))
	item_rect_changed.connect(_place_hint)
	_show_focus(has_focus())


## The focus bob: whole pixels, the lift plus 0 or BOB_PX, never touching position.x (the wiggle owns x).
func _process(delta: float) -> void:
	_bob_s = fmod(_bob_s + delta, BOB_PERIOD_S)
	var frame: Control = get_node_or_null(^"%Frame") as Control
	if frame != null:
		frame.position.y = -LIFT_PX - (BOB_PX if _bob_s >= BOB_PERIOD_S / 2.0 else 0.0)


## The card state for a registry entry and its PlayerData.get_unlock_state(): Coming soon wins over Locked,
## Locked over New, New over Available. Missing unlock fields read as true (open).
static func state_for(entry: LevelEntry, unlock: Dictionary) -> State:
	if entry == null or not entry.available:
		return State.COMING_SOON
	if not bool(unlock.get("unlocked", true)):
		return State.LOCKED
	if not bool(unlock.get("chosen", true)):
		return State.NEW
	return State.AVAILABLE


## Fills the card from its registry entry and unlock state (default: open). Call before add_child.
func setup(entry: LevelEntry, unlock: Dictionary = {"unlocked": true, "moment_seen": true, "chosen": true}) -> void:
	if entry == null:
		Log.error(&"ui", "LevelCard.setup: null entry")
		return
	_level_id = entry.id
	%NameLabel.text = entry.display_name if not entry.display_name.is_empty() else String(entry.id).capitalize()
	%Picture.texture = entry.card_picture
	_set_state(state_for(entry, unlock))


## Changes the look without a moment (the menu re-reads unlocks on profile_replaced / unlocks_changed).
func set_state(state: State) -> void:
	if _moment_tween != null:
		_moment_tween.kill()
		_moment_tween = null
	_set_state(state)


## The Locked hint sign's words, e.g. "Finish Zombie Run to open!".
func set_hint_text(text: String) -> void:
	%HintLabel.text = text


func get_hint_text() -> String:
	return %HintLabel.text


func get_state() -> State:
	return _state


func get_level_id() -> StringName:
	return _level_id


## True when Enter or a click starts the level (Available or New).
func is_choosable() -> bool:
	return _state == State.AVAILABLE or _state == State.NEW


func is_wiggling() -> bool:
	return _wiggle_tween != null and _wiggle_tween.is_running()


func is_playing_moment() -> bool:
	return _moment_tween != null


## Plays the one-time unlock moment on a Locked-looking card; it ends in the New look. The card must be in
## the tree. Logged and ignored when a moment is already playing.
func play_unlock_moment() -> void:
	if is_playing_moment():
		Log.warn(&"ui", "LevelCard %s: unlock moment already playing" % _level_id)
		return
	_moment_tween = create_tween()
	# After the tween exists: a playing moment keeps the hint sign down (the lock is on its way out).
	_set_state(State.LOCKED)
	_jingle_played = false
	Log.debug(&"ui", "unlock moment %s" % _level_id)
	var padlock: Control = %Padlock
	var tint: ColorRect = %Tint
	var badge: Control = %NewBadge
	var tween: Tween = _moment_tween
	tween.tween_interval(MOMENT_BEAT_S)
	tween.tween_method(_set_padlock_offset, Vector2.ZERO, Vector2(WIGGLE_PX, 0.0), WIGGLE_S / 4.0)
	tween.tween_method(_set_padlock_offset, Vector2(WIGGLE_PX, 0.0), Vector2(-WIGGLE_PX, 0.0), WIGGLE_S / 2.0)
	tween.tween_method(_set_padlock_offset, Vector2(-WIGGLE_PX, 0.0), Vector2.ZERO, WIGGLE_S / 4.0)
	# The lock is off: from here the card is New (choosable, no hint).
	tween.tween_callback(_on_padlock_popped)
	tween.tween_method(_set_padlock_offset, Vector2.ZERO, Vector2(0.0, -PADLOCK_POP_PX), PADLOCK_POP_S)
	tween.tween_method(_set_padlock_offset, Vector2(0.0, -PADLOCK_POP_PX), Vector2(0.0, PADLOCK_FALL_PX), PADLOCK_FALL_S)
	tween.parallel().tween_property(padlock, ^"modulate:a", 0.0, PADLOCK_FALL_S)
	tween.tween_property(tint, ^"color:a", 0.0, TINT_CLEAR_S)
	tween.tween_callback(_thump_badge)
	tween.tween_property(badge, ^"scale", Vector2.ONE, BADGE_THUMP_S)
	tween.tween_callback(_end_moment)


## Snaps a playing moment to its end (New look, jingle played once) and emits unlock_moment_finished.
## Does nothing when no moment is playing.
func finish_unlock_moment() -> void:
	if not is_playing_moment():
		return
	_moment_tween.kill()
	_end_moment()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus():
		grab_focus()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed(&"ui_accept"):
		_activate()
		accept_event()


## Applies a state's look. Resets everything the moment moves (padlock, tint alpha, badge scale).
func _set_state(state: State) -> void:
	_state = state
	var coming_soon: bool = state == State.COMING_SOON
	var locked: bool = state == State.LOCKED
	var tint: ColorRect = %Tint
	tint.visible = coming_soon or locked
	tint.color = TINT_LOCKED if locked else TINT_COMING_SOON
	%ComingSoonPlank.visible = coming_soon
	var padlock: Control = %Padlock
	padlock.visible = locked
	padlock.position = PADLOCK_REST
	padlock.modulate.a = 1.0
	var badge: Control = %NewBadge
	badge.visible = state == State.NEW
	badge.scale = Vector2.ONE
	%NameSign.theme_type_variation = SIGN_COMING_SOON_VARIATION if coming_soon else SIGN_VARIATION
	_update_hint()


func _activate() -> void:
	if is_choosable():
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


## The padlock at its rest position plus `offset`, on whole pixels (pixel-art rule).
func _set_padlock_offset(offset: Vector2) -> void:
	(%Padlock as Control).position = PADLOCK_REST + offset.round()


func _on_padlock_popped() -> void:
	_state = State.NEW
	_update_hint()


func _thump_badge() -> void:
	var badge: Control = %NewBadge
	badge.pivot_offset = badge.size / 2.0
	badge.scale = Vector2.ONE * BADGE_THUMP_SCALE
	badge.visible = true
	_play_jingle()


func _play_jingle() -> void:
	if _jingle_played:
		return
	_jingle_played = true
	play_sfx.call(JINGLE_ID)


func _end_moment() -> void:
	_moment_tween = null
	_set_state(State.NEW)
	_play_jingle()
	unlock_moment_finished.emit(_level_id)


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
	_update_hint()


## The hint shows only on a focused Locked card.
func _update_hint() -> void:
	var hint: Control = get_node_or_null(^"%Hint") as Control
	if hint == null:
		return
	hint.visible = _state == State.LOCKED and has_focus() and not is_playing_moment()
	if hint.visible:
		_place_hint()


## Centres the hint under the card, then clamps it (whole pixels) into MARGIN_RECT on screen.
func _place_hint() -> void:
	var hint: Control = get_node_or_null(^"%Hint") as Control
	if hint == null:
		return
	var left: float = global_position.x + roundf((size.x - hint.size.x) / 2.0)
	left = clampf(left, MARGIN_RECT.position.x, MARGIN_RECT.end.x - hint.size.x)
	hint.position.x = roundf(left - global_position.x)
