extends GutTest
## Typing input filtering (Story 2.1): ignored keys, case rule, character matching, Caps Lock hint.

const LOWERCASE_PATH: String = "res://tests/fixtures/levels/level_config_lowercase.tres"
const CASE_SENSITIVE_PATH: String = "res://tests/fixtures/levels/level_config_case_sensitive.tres"

var _node: TypingInput
var _events: Array[String] = []


func before_each() -> void:
	_node = autofree(TypingInput.new()) as TypingInput
	_events = []
	watch_signals(_node)


func _key(keycode: Key, unicode: int = 0, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.unicode = unicode
	event.pressed = pressed
	event.echo = echo
	return event


func _shift_key(keycode: Key, unicode: int) -> InputEventKey:
	var event: InputEventKey = _key(keycode, unicode)
	event.shift_pressed = true
	return event


## Capital A typed with Caps Lock on (no Shift).
func _cap_a() -> InputEventKey:
	return _key(KEY_A, 65)


func _low_a() -> InputEventKey:
	return _key(KEY_A, 97)


func _space() -> InputEventKey:
	return _key(KEY_SPACE, 32)


func _lowercase() -> LevelConfig:
	return load(LOWERCASE_PATH) as LevelConfig


func _case_sensitive() -> LevelConfig:
	return load(CASE_SENSITIVE_PATH) as LevelConfig


## Records char_typed and both caps signals into one ordered list.
func _record_all() -> void:
	_node.char_typed.connect(func(c: String) -> void: _events.append("char:" + c))
	_node.caps_lock_suspected.connect(func() -> void: _events.append("suspected"))
	_node.caps_lock_cleared.connect(func() -> void: _events.append("cleared"))


func _send(events: Array[InputEventKey]) -> void:
	for event: InputEventKey in events:
		_node.handle_key(event)


func _assert_ignored(event: InputEventKey, label: String) -> void:
	assert_false(_node.handle_key(event), label)
	assert_signal_not_emitted(_node, "char_typed", label)


# --- AC 1: ignored events ---------------------------------------------------

func test_release_is_ignored() -> void:
	_assert_ignored(_key(KEY_A, 97, false), "release")


func test_echo_is_ignored() -> void:
	_assert_ignored(_key(KEY_A, 97, true, true), "echo")


func test_null_event_is_ignored() -> void:
	assert_false(_node.handle_key(null))
	assert_signal_not_emitted(_node, "char_typed")


func test_zero_unicode_is_ignored() -> void:
	_assert_ignored(_key(KEY_A, 0), "dead key / IME")
	_assert_ignored(_key(KEY_SHIFT, 0), "shift alone")


func test_every_ignored_keycode_is_ignored_even_with_printable_unicode() -> void:
	for keycode: Key in GameConstants.IGNORED_KEYCODES:
		_assert_ignored(_key(keycode, 97), "keycode %d" % keycode)


func test_function_keys_are_ignored_even_with_printable_unicode() -> void:
	for keycode: Key in [KEY_F1, KEY_F3, KEY_F12, KEY_F35]:
		_assert_ignored(_key(keycode, 97), "F-key %d" % keycode)


func test_control_character_unicodes_are_ignored() -> void:
	for code: int in [8, 9, 13, 27, 127]:
		_assert_ignored(_key(KEY_NONE, code), "unicode %d" % code)


func test_unicode_boundaries() -> void:
	for code: int in [31, 127, 128, 159, 0xD800, 0xDFFF, 0x110000]:
		_assert_ignored(_key(KEY_NONE, code), "unicode %d" % code)
	for code: int in [32, 126]:
		_node.configure(_case_sensitive())
		var before: int = get_signal_emit_count(_node, "char_typed")
		assert_true(_node.handle_key(_key(KEY_NONE, code)), "unicode %d" % code)
		assert_eq(get_signal_emit_count(_node, "char_typed"), before + 1)


func test_function_key_range_is_contiguous() -> void:
	assert_eq(KEY_F35 - KEY_F1, 34)
	assert_eq(GameConstants.FUNCTION_KEY_LAST - GameConstants.FUNCTION_KEY_FIRST, 34)


func test_modifier_combos_are_ignored() -> void:
	for modifier: String in ["ctrl_pressed", "alt_pressed", "meta_pressed"]:
		var event: InputEventKey = _low_a()
		event.set(modifier, true)
		_assert_ignored(event, modifier)


# --- AC 3: lowercase level --------------------------------------------------

func test_lowercase_level_emits_lowercase_letters() -> void:
	_node.configure(_lowercase())
	assert_true(_node.handle_key(_low_a()))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
	assert_true(_node.handle_key(_shift_key(KEY_A, 65)))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
	assert_true(_node.handle_key(_cap_a()))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
	assert_signal_emit_count(_node, "char_typed", 3)


func test_lowercase_level_ignores_space() -> void:
	_node.configure(_lowercase())
	assert_false(_node.handle_key(_space()))
	assert_signal_not_emitted(_node, "char_typed")


func test_lowercase_level_passes_digits_and_punctuation_unchanged() -> void:
	_node.configure(_lowercase())
	_record_all()
	_send([_key(KEY_1, 49), _key(KEY_SEMICOLON, 59), _shift_key(KEY_1, 33), _key(KEY_KP_1, 49)])
	assert_eq(_events, ["char:1", "char:;", "char:!", "char:1"] as Array[String])


# --- AC 4: case-sensitive level ---------------------------------------------

func test_case_sensitive_level_keeps_case_and_space() -> void:
	_node.configure(_case_sensitive())
	_record_all()
	_send([_shift_key(KEY_A, 65), _low_a(), _space()])
	assert_eq(_events, ["char:A", "char:a", "char: "] as Array[String])


func test_unconfigured_node_behaves_as_lowercase() -> void:
	assert_true(_node.handle_key(_cap_a()))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
	assert_false(_node.handle_key(_space()))
	assert_signal_emit_count(_node, "char_typed", 1)


# --- AC 5: character, not key -----------------------------------------------

func test_character_comes_from_unicode_not_keycode() -> void:
	assert_true(_node.handle_key(_key(KEY_Q, 97)))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
	assert_true(_node.handle_key(_key(KEY_A, 113)))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["q"])


# --- AC 6: Caps Lock hint ---------------------------------------------------

func test_three_capitals_suspect_once_and_lowercase_clears_once() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 0)
	_send([_cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)
	_send([_cap_a(), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)
	assert_signal_emit_count(_node, "caps_lock_cleared", 0)
	_send([_low_a()])
	assert_signal_emit_count(_node, "caps_lock_cleared", 1)
	_send([_low_a()])
	assert_signal_emit_count(_node, "caps_lock_cleared", 1)
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)


func test_lowercase_breaks_the_streak() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a(), _low_a(), _cap_a()])
	assert_signal_not_emitted(_node, "caps_lock_suspected")
	assert_signal_not_emitted(_node, "caps_lock_cleared")


func test_two_full_cycles() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a(), _cap_a(), _low_a(), _cap_a(), _cap_a(), _cap_a(), _low_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 2)
	assert_signal_emit_count(_node, "caps_lock_cleared", 2)


func test_digits_and_punctuation_are_neutral_for_the_streak() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a(), _key(KEY_1, 49), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)
	_send([_low_a()])
	_send([_cap_a(), _cap_a(), _shift_key(KEY_1, 33), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 2)


func test_ignored_space_does_not_reset_the_streak() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a(), _space(), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)


func test_suspected_is_emitted_before_char_typed() -> void:
	_node.configure(_lowercase())
	_record_all()
	_send([_cap_a(), _cap_a(), _cap_a(), _low_a()])
	assert_eq(_events, ["char:a", "char:a", "suspected", "char:a", "cleared", "char:a"] as Array[String])


func test_ignored_events_do_not_change_the_streak() -> void:
	_node.configure(_lowercase())
	var ctrl_a: InputEventKey = _cap_a()
	ctrl_a.ctrl_pressed = true
	_send([_cap_a(), _cap_a(), _key(KEY_A, 65, true, true), ctrl_a, _key(KEY_A, 65, false)])
	assert_signal_emit_count(_node, "caps_lock_suspected", 0)
	_send([_cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)


func test_case_sensitive_level_never_emits_caps_signals() -> void:
	_node.configure(_case_sensitive())
	_send([_cap_a(), _cap_a(), _cap_a(), _cap_a(), _low_a()])
	assert_signal_not_emitted(_node, "caps_lock_suspected")
	assert_signal_not_emitted(_node, "caps_lock_cleared")
	assert_signal_emit_count(_node, "char_typed", 5)


func test_configure_resets_the_streak_silently() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a()])
	_node.configure(_lowercase())
	_send([_cap_a()])
	assert_signal_not_emitted(_node, "caps_lock_suspected")


func test_configure_clears_suspicion_without_a_signal() -> void:
	_node.configure(_lowercase())
	_send([_cap_a(), _cap_a(), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 1)
	_node.configure(_lowercase())
	assert_signal_not_emitted(_node, "caps_lock_cleared")
	_send([_cap_a(), _cap_a(), _cap_a()])
	assert_signal_emit_count(_node, "caps_lock_suspected", 2)


# --- _unhandled_input path --------------------------------------------------

func test_unhandled_input_forwards_key_events() -> void:
	add_child_autofree(_node)
	_node._unhandled_input(_key(KEY_SHIFT, 0))
	assert_false(_node.get_viewport().is_input_handled())
	_node._unhandled_input(_low_a())
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
	assert_true(_node.get_viewport().is_input_handled())
	_node._unhandled_input(InputEventMouseButton.new())
	assert_signal_emit_count(_node, "char_typed", 1)


# --- AC 2: LevelConfig ------------------------------------------------------

func test_level_config_defaults() -> void:
	var config: LevelConfig = LevelConfig.new()
	assert_eq(config.duration_s, 0.0)
	assert_false(config.case_sensitive)
	assert_false(config.space_is_input)
	assert_eq(config.target_mode, LevelConfig.TargetMode.LETTER)


func test_lowercase_fixture_loads_as_level_config() -> void:
	var res: Resource = load(LOWERCASE_PATH)
	assert_true(res is LevelConfig)
	var config: LevelConfig = res as LevelConfig
	assert_eq(config.duration_s, 120.0)
	assert_false(config.case_sensitive)
	assert_false(config.space_is_input)
	assert_eq(config.target_mode, LevelConfig.TargetMode.LETTER)


func test_case_sensitive_fixture_loads_as_level_config() -> void:
	var res: Resource = load(CASE_SENSITIVE_PATH)
	assert_true(res is LevelConfig)
	var config: LevelConfig = res as LevelConfig
	assert_eq(config.duration_s, 300.0)
	assert_true(config.case_sensitive)
	assert_true(config.space_is_input)
	assert_eq(config.target_mode, LevelConfig.TargetMode.PARAGRAPH)


# --- GameConstants.IGNORED_KEYCODES -----------------------------------------

func test_ignored_keycodes_list() -> void:
	for keycode: Key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
			KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_CAPSLOCK, KEY_ESCAPE]:
		assert_has(GameConstants.IGNORED_KEYCODES, keycode, "keycode %d" % keycode)
	assert_does_not_have(GameConstants.IGNORED_KEYCODES, KEY_SPACE)


# --- active gate (Story 2.4) ------------------------------------------------

func test_inactive_node_emits_nothing() -> void:
	_node.active = false
	assert_false(_node.handle_key(_low_a()))
	assert_signal_not_emitted(_node, "char_typed")
	_node.active = true
	assert_true(_node.handle_key(_low_a()))
	assert_signal_emitted_with_parameters(_node, "char_typed", ["a"])
