extends GutTest
## Zombie hands (Story 2.6): which fingers light, the lit/rest look, the ~2 Hz outline pulse, the f/j
## bumps, focus/mouse rules and a missing finger map. Disabled instance: _process driven by hand.
## Story 5.0: the hands are sprites; the glow frame follows the outline width; the art mirrors about x 156.

const HandsScene: PackedScene = preload("res://scenes/run/zombie_hands.tscn")
const HandsScript := preload("res://scripts/run/zombie_hands.gd")
const L: int = FingerMap.Hand.LEFT
const R: int = FingerMap.Hand.RIGHT
const RESTING_GREEN: Color = Color("#6CC24A")
const BRIGHT_GREEN: Color = Color("#B8F27C")

var _hands: HandsScript


func before_each() -> void:
	_hands = HandsScene.instantiate() as HandsScript
	_hands.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_hands)


func _f(hand: int, finger: int) -> Vector2i:
	return Vector2i(hand, finger)


func _all_fingers() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for hand: int in [L, R]:
		for finger: int in FingerMap.Finger.values():
			out.append(_f(hand, finger))
	return out


func _assert_only_lit(expected: Array[Vector2i]) -> void:
	assert_eq(_hands.get_lit_fingers(), expected)
	for hand_finger: Vector2i in _all_fingers():
		var lit: bool = hand_finger in expected
		assert_eq(_hands.is_lit(hand_finger), lit, "is_lit %s" % hand_finger)
		assert_eq(_hands.get_finger_fill(hand_finger), BRIGHT_GREEN if lit else RESTING_GREEN, "fill %s" % hand_finger)


func test_size_and_starts_unlit() -> void:
	assert_eq(_hands.size, Vector2(312, 48))
	_assert_only_lit([])
	assert_eq(_hands.get_outline_width(), 0)


func test_f_lights_left_index() -> void:
	_hands.show_char("f")
	_assert_only_lit([_f(L, FingerMap.Finger.INDEX)])
	assert_eq(_hands.get_outline_width(), 2, "a new cue starts strong")


func test_capital_lights_both_pinkies() -> void:
	_hands.show_char("A")
	_assert_only_lit([_f(L, FingerMap.Finger.PINKY), _f(R, FingerMap.Finger.PINKY)])


func test_space_lights_both_thumbs() -> void:
	_hands.show_char(" ")
	_assert_only_lit([_f(L, FingerMap.Finger.THUMB), _f(R, FingerMap.Finger.THUMB)])


func test_word_lights_its_first_character() -> void:
	_hands.show_char("jam")
	_assert_only_lit([_f(R, FingerMap.Finger.INDEX)])


func test_empty_target_lights_nothing() -> void:
	_hands.show_char("f")
	_hands.show_char("")
	_assert_only_lit([])
	assert_eq(_hands.get_outline_width(), 0)


func test_unmapped_character_lights_nothing() -> void:
	_hands.show_char("€")
	assert_push_warning("[WARN][hands]")
	_assert_only_lit([])
	assert_eq(_hands.get_outline_width(), 0)


func test_pulse_toggles_every_quarter_second() -> void:
	_hands.show_char("f")
	assert_eq(_hands.get_outline_width(), 2)
	_hands._process(0.25)
	assert_eq(_hands.get_outline_width(), 1)
	_hands._process(0.25)
	assert_eq(_hands.get_outline_width(), 2)
	_hands._process(0.125)
	assert_eq(_hands.get_outline_width(), 2, "not yet a half period")
	_hands._process(0.125)
	assert_eq(_hands.get_outline_width(), 1)


func test_new_letter_restarts_the_pulse_strong() -> void:
	_hands.show_char("f")
	_hands._process(0.3)
	assert_eq(_hands.get_outline_width(), 1)
	_hands.show_char("k")
	assert_eq(_hands.get_outline_width(), 2)
	_hands._process(0.2)
	assert_eq(_hands.get_outline_width(), 2, "the restart reset the phase")


func test_same_finger_again_keeps_the_pulse_running() -> void:
	_hands.show_char("f")
	_hands._process(0.3)
	assert_eq(_hands.get_outline_width(), 1)
	_hands.show_char("f")
	assert_eq(_hands.get_outline_width(), 1, "the same finger does not restart the pulse")
	_hands.show_char("g")
	assert_eq(_hands.get_outline_width(), 1, "g is the same finger (left index) too")
	_hands.show_char("k")
	assert_eq(_hands.get_outline_width(), 2, "another finger restarts it")


func test_nothing_lit_keeps_width_zero() -> void:
	_hands._process(0.25)
	_hands._process(0.25)
	assert_eq(_hands.get_outline_width(), 0)


func test_pulse_is_below_the_flash_limit() -> void:
	assert_true(HandsScript.PULSE_HZ <= 3.0, "at most 3 flashes per second")
	assert_eq(HandsScript.PULSE_HZ, 2.0)


func test_bumps_on_f_and_j_in_every_state() -> void:
	for target: String in ["", "f", "k", "A"]:
		_hands.show_char(target)
		for hand_finger: Vector2i in _all_fingers():
			var expected: bool = hand_finger == _f(L, FingerMap.Finger.INDEX) or hand_finger == _f(R, FingerMap.Finger.INDEX)
			assert_eq(_hands.has_bump(hand_finger), expected, "bump %s with '%s'" % [hand_finger, target])


func test_lit_finger_is_clearly_brighter() -> void:
	# NFR8: the cue reads without hue (luminance) and has a shape cue (the outline, lit only).
	var difference: float = BRIGHT_GREEN.get_luminance() - RESTING_GREEN.get_luminance()
	assert_true(difference >= 0.2, "luminance difference %f" % difference)
	_hands.show_char("f")
	assert_true(_hands.get_outline_width() > 0)
	_hands.show_char("")
	assert_eq(_hands.get_outline_width(), 0, "no outline when nothing is lit")


func test_lit_copy_is_independent() -> void:
	_hands.show_char("f")
	var lit: Array[Vector2i] = _hands.get_lit_fingers()
	lit.clear()
	assert_eq(_hands.get_lit_fingers().size(), 1)


func test_focus_and_mouse_rules() -> void:
	var controls: Array[Node] = [_hands]
	controls.append_array(_hands.find_children("*", "Control", true, false))
	for node: Node in controls:
		var control: Control = node as Control
		assert_eq(control.focus_mode, Control.FOCUS_NONE, "%s focus" % control.name)
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s mouse" % control.name)


func test_missing_finger_map_lights_nothing() -> void:
	var hands: HandsScript = HandsScene.instantiate() as HandsScript
	hands.finger_map = null
	hands.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hands)
	assert_push_error("[ERROR][hands]")
	hands.show_char("a")
	assert_eq(hands.get_lit_fingers(), [] as Array[Vector2i])
	assert_eq(hands.get_outline_width(), 0)


## Story 5.0: the hands and every glow sheet load once; the glow frame is 0 (strong) or 1 (weak) with the pulse.
func test_hand_and_glow_art_loaded() -> void:
	for hand: int in [L, R]:
		assert_not_null(_hands._hand_textures.get(hand), "hand %d" % hand)
		for finger: int in FingerMap.Finger.values():
			var glow: Texture2D = _hands._glow_textures.get(_f(hand, finger))
			assert_not_null(glow, "glow %d %d" % [hand, finger])
			if glow != null:
				assert_eq(Vector2i(glow.get_size()), Vector2i(HandsScript.HAND_SIZE.x * 2, HandsScript.HAND_SIZE.y))
	_hands.show_char("f")
	assert_eq(_hands.get_glow_frame(), 0, "strong outline -> frame 0")
	_hands._process(0.25)
	assert_eq(_hands.get_glow_frame(), 1, "weak outline -> frame 1")


func test_hands_mirror_about_the_area_centre() -> void:
	assert_eq(HandsScript.LEFT_X + HandsScript.HAND_SIZE.x + HandsScript.RIGHT_X, 312, "mirrored about x 156")
	assert_lte(HandsScript.RIGHT_X + HandsScript.HAND_SIZE.x, 312)


func test_missing_art_warns_once_and_draws_nothing() -> void:
	var texture: Texture2D = _hands._load("res://assets/sprites/ui/hands/nope.png")
	assert_null(texture)
	assert_push_warning("[WARN][hands]")
	_hands._load("res://assets/sprites/ui/hands/nope_again.png")
	assert_push_warning_count(1)
