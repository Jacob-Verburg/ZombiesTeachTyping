extends GutTest
## Finger map (Story 2.6): the shipped data/finger_map.tres against an independent copy of the GDD
## touch-typing table (US QWERTY), the Shift pairing rule (FR17), Space on both thumbs, warnings.

const MAP_PATH: String = "res://data/finger_map.tres"
const L: int = FingerMap.Hand.LEFT
const R: int = FingerMap.Hand.RIGHT
const PINKY: int = FingerMap.Finger.PINKY
const RING: int = FingerMap.Finger.RING
const MIDDLE: int = FingerMap.Finger.MIDDLE
const INDEX: int = FingerMap.Finger.INDEX
const THUMB: int = FingerMap.Finger.THUMB
## The GDD table, written out again here on purpose (independent of tools/gen_finger_map.gd).
const TABLE: Dictionary = {
	"1qaz": [L, PINKY],
	"2wsx": [L, RING],
	"3edc": [L, MIDDLE],
	"45rtfgvb": [L, INDEX],
	"0p;/'-=": [R, PINKY],
	"9ol.": [R, RING],
	"8ik,": [R, MIDDLE],
	"67yuhjnm": [R, INDEX],
}
## 26 letters + 10 digits + 7 punctuation + Space + 17 shifted symbols + 26 capitals.
const EXPECTED_COUNT: int = 87

var _map: FingerMap


func before_each() -> void:
	_map = load(MAP_PATH) as FingerMap


func _f(hand: int, finger: int) -> Vector2i:
	return Vector2i(hand, finger)


func _oracle(c: String) -> Vector2i:
	for keys: String in TABLE:
		if keys.contains(c):
			var pair: Array = TABLE[keys]
			return _f(pair[0], pair[1])
	return Vector2i(-1, -1)


func _expect(c: String, expected: Array[Vector2i]) -> void:
	assert_eq(_map.fingers_for(c), expected, "fingers for '%s'" % c)


func _opposite_pinky(hand_finger: Vector2i) -> Vector2i:
	return _f(R if hand_finger.x == L else L, PINKY)


func test_shipped_map_loads() -> void:
	assert_not_null(_map, "finger_map.tres loads as a FingerMap")


func test_every_lowercase_letter() -> void:
	for code: int in range(97, 123):
		var c: String = String.chr(code)
		_expect(c, [_oracle(c)])


func test_digits_and_punctuation() -> void:
	for c: String in "0123456789;/'-=.,":
		_expect(c, [_oracle(c)])


func test_acceptance_cases() -> void:
	_expect("a", [_f(L, PINKY)])
	_expect("J", [_f(R, INDEX), _f(L, PINKY)])
	_expect("A", [_f(L, PINKY), _f(R, PINKY)])
	_expect(" ", [_f(L, THUMB), _f(R, THUMB)])


func test_every_capital_adds_the_opposite_pinky() -> void:
	for code: int in range(97, 123):
		var lower: String = String.chr(code)
		var own: Vector2i = _oracle(lower)
		_expect(lower.to_upper(), [own, _opposite_pinky(own)])


func test_shifted_symbols() -> void:
	_expect("!", [_f(L, PINKY), _f(R, PINKY)])
	_expect("?", [_f(R, PINKY), _f(L, PINKY)])
	_expect("\"", [_f(R, PINKY), _f(L, PINKY)])
	_expect("(", [_f(R, RING), _f(L, PINKY)])
	_expect("<", [_f(R, MIDDLE), _f(L, PINKY)])
	_expect("%", [_f(L, INDEX), _f(R, PINKY)])


func test_every_shifted_symbol_uses_its_base_key() -> void:
	var pairs: Array[String] = [
		"1!", "2@", "3#", "4$", "5%", "6^", "7&", "8*", "9(", "0)", "-_", "=+", ";:", "'\"", ",<", ".>", "/?",
	]
	for pair: String in pairs:
		var own: Vector2i = _oracle(pair[0])
		_expect(pair[1], [own, _opposite_pinky(own)])


func test_unmapped_character_warns() -> void:
	assert_eq(_map.fingers_for("€"), [] as Array[Vector2i])
	assert_push_warning("[WARN][hands]")
	assert_eq(_map.fingers_for("`"), [] as Array[Vector2i])
	assert_push_warning_count(2)


func test_more_than_one_character_warns() -> void:
	assert_eq(_map.fingers_for("ab"), [] as Array[Vector2i])
	assert_push_warning("[WARN][hands]")


func test_empty_target_is_silent() -> void:
	assert_eq(_map.fingers_for(""), [] as Array[Vector2i])
	assert_push_warning_count(0)


func test_entries_count_and_ranges() -> void:
	assert_eq(_map.entries.size(), EXPECTED_COUNT)
	for c: String in _map.entries:
		var entry: Vector3i = _map.entries[c]
		assert_eq(c.length(), 1, "key '%s' is one character" % c)
		assert_true(entry.x >= L and entry.x <= R, "'%s' hand %d" % [c, entry.x])
		assert_true(entry.y >= PINKY and entry.y <= THUMB, "'%s' finger %d" % [c, entry.y])
		assert_true(entry.z == 0 or entry.z == 1, "'%s' shift %d" % [c, entry.z])


func test_result_is_typed() -> void:
	var result: Array[Vector2i] = _map.fingers_for("a")
	assert_eq(result.get_typed_builtin(), TYPE_VECTOR2I)


func test_finger_id() -> void:
	assert_eq(FingerMap.finger_id(_f(L, PINKY)), 0)
	assert_eq(FingerMap.finger_id(_f(L, THUMB)), 4)
	assert_eq(FingerMap.finger_id(_f(R, PINKY)), 5)
	assert_eq(FingerMap.finger_id(_f(R, INDEX)), 8)
	assert_eq(FingerMap.finger_id(_f(R, THUMB)), 9)
