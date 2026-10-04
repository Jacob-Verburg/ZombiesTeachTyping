extends SceneTree
## Dev-only: writes data/finger_map.tres from the GDD touch-typing table (US QWERTY, Story 2.6).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_finger_map.gd
## then --import. Exits non-zero on a duplicate key, a wrong entry count or a failed save.
## Not mapped on purpose: ` ~ [ ] { } \ | (outside the GDD table; never in MVP or Pitchfork Panic text),
## and Tab, Enter and the Shift keys (pressed by the pinkies, but never typed characters).

const OUT_PATH: String = "res://data/finger_map.tres"
## 26 letters + 10 digits + 7 punctuation + Space + 17 shifted symbols + 26 capitals.
const EXPECTED_COUNT: int = 87
const L: int = FingerMap.Hand.LEFT
const R: int = FingerMap.Hand.RIGHT
## The GDD table: one string of keys per (hand, finger).
const TABLE: Array[Array] = [
	["1qaz", L, FingerMap.Finger.PINKY],
	["2wsx", L, FingerMap.Finger.RING],
	["3edc", L, FingerMap.Finger.MIDDLE],
	["45rtfgvb", L, FingerMap.Finger.INDEX],
	["0p;/'-=", R, FingerMap.Finger.PINKY],
	["9ol.", R, FingerMap.Finger.RING],
	["8ik,", R, FingerMap.Finger.MIDDLE],
	["67yuhjnm", R, FingerMap.Finger.INDEX],
]
## Base key -> the character it types with Shift.
const SHIFTED: Array[String] = [
	"1!", "2@", "3#", "4$", "5%", "6^", "7&", "8*", "9(", "0)", "-_", "=+", ";:", "'\"", ",<", ".>", "/?",
]

var _ok: bool = true


func _init() -> void:
	var map: FingerMap = FingerMap.new()
	for row: Array in TABLE:
		var keys: String = row[0]
		for c: String in keys:
			_add(map, c, Vector3i(row[1], row[2], 0))
	_add(map, " ", Vector3i(L, FingerMap.Finger.THUMB, 0))
	for pair: String in SHIFTED:
		var base: Vector3i = map.entries.get(pair[0], Vector3i(-1, -1, -1))
		if base.x < 0:
			_fail("shifted pair '%s' has no base key" % pair)
			continue
		_add(map, pair[1], Vector3i(base.x, base.y, 1))
	for code: int in range(97, 123):
		var lower: String = String.chr(code)
		var base: Vector3i = map.entries[lower]
		_add(map, lower.to_upper(), Vector3i(base.x, base.y, 1))
	print("finger map: %d entries (expected %d)" % [map.entries.size(), EXPECTED_COUNT])
	if map.entries.size() != EXPECTED_COUNT:
		_fail("wrong entry count")
	if _ok:
		var err: Error = ResourceSaver.save(map, OUT_PATH)
		print("%s -> %s" % [OUT_PATH, error_string(err)])
		_ok = err == OK
	quit(0 if _ok else 1)


func _add(map: FingerMap, c: String, entry: Vector3i) -> void:
	if map.entries.has(c):
		_fail("duplicate key '%s'" % c)
		return
	map.entries[c] = entry


func _fail(message: String) -> void:
	printerr("gen_finger_map: " + message)
	_ok = false
