extends Control
## The green zombie hands finger guide (FR15-FR18) in the HUD's hands area (312 x 48). The finger(s)
## for the next character glow brighter green and get a pulsing candy-yellow outline (brightness plus
## shape, never hue alone, NFR8); the f and j fingertips always carry a home-row bump. The HUD calls
## show_char() with the current target; the hands never read input, the session, the clock or any
## autoload except Log. Story 5.0 art: two hand sprites (assets/sprites/ui/hands/ui_hand_<left|right>.png) and
## one glow overlay per finger (ui_finger_glow_<l|r>_<finger>.png: 2 frames, strong and weak outline, each the
## size of the hand), drawn at the hand's own position. The getters below are the contract the art keeps.

## Active finger pulse, about 2 Hz (EXPERIENCE.md Game Feel [ASSUMPTION]), below the 3 flashes/s limit.
const PULSE_HZ: float = 2.0
## The outline switches between these widths every half period; a new cue starts at the strong one.
const OUTLINE_STRONG: int = 2
const OUTLINE_WEAK: int = 1

## The palette fills the sprites use for a resting and a lit finger (DESIGN.md hands tokens).
const RESTING_GREEN: Color = Color("#6CC24A")
const BRIGHT_GREEN: Color = Color("#B8F27C")

## Where each 64 x 48 hand sprite sits in the 312 x 48 area: mirrored about x 156, under the target sign.
const LEFT_X: int = 56
const RIGHT_X: int = 192
const HAND_SIZE: Vector2i = Vector2i(64, 48)
const HANDS_DIR: String = "res://assets/sprites/ui/hands/"
## Finger -> its name in the glow sheet file names.
const FINGER_NAMES: Dictionary[FingerMap.Finger, String] = {
	FingerMap.Finger.PINKY: "pinky",
	FingerMap.Finger.RING: "ring",
	FingerMap.Finger.MIDDLE: "middle",
	FingerMap.Finger.INDEX: "index",
	FingerMap.Finger.THUMB: "thumb",
}

## The touch-typing table; set in zombie_hands.tscn (injection, no data path in this script).
@export var finger_map: FingerMap

## Hand -> sprite, and (hand, finger) -> its glow sheet, loaded once in _ready.
var _hand_textures: Dictionary[int, Texture2D] = {}
var _glow_textures: Dictionary[Vector2i, Texture2D] = {}
var _warned_missing: bool = false
var _lit: Array[Vector2i] = []
var _pulse_time: float = 0.0
var _outline_width: int = 0


func _ready() -> void:
	if finger_map == null:
		Log.error(&"hands", "ZombieHands has no FingerMap; no finger will light")
	for hand: int in [FingerMap.Hand.LEFT, FingerMap.Hand.RIGHT]:
		var side: String = "left" if hand == FingerMap.Hand.LEFT else "right"
		_hand_textures[hand] = _load(HANDS_DIR + "ui_hand_%s.png" % side)
		for finger: FingerMap.Finger in FINGER_NAMES:
			_glow_textures[Vector2i(hand, finger)] = _load(
					HANDS_DIR + "ui_finger_glow_%s_%s.png" % [side.left(1), FINGER_NAMES[finger]])


func _process(delta: float) -> void:
	if _lit.is_empty():
		return
	_pulse_time += delta
	var half_period: float = 1.0 / (2.0 * PULSE_HZ)
	var width: int = OUTLINE_STRONG if floori(_pulse_time / half_period) % 2 == 0 else OUTLINE_WEAK
	if width != _outline_width:
		_outline_width = width
		queue_redraw()


## Lights the finger(s) for the target's first character (word mode refines this in Story 6.2). An empty
## or unmapped target lights nothing and never stops the run. A change restarts the pulse; the same
## finger again keeps it going.
func show_char(target: String) -> void:
	var c: String = target.left(1)
	var next: Array[Vector2i] = finger_map.fingers_for(c) if finger_map != null else ([] as Array[Vector2i])
	if next == _lit:
		return  # the same finger again ("ff"): keep the pulse running
	_lit = next
	_pulse_time = 0.0
	_outline_width = 0 if _lit.is_empty() else OUTLINE_STRONG
	queue_redraw()


## The lit fingers as (Hand, Finger), the character's own finger first. A copy.
func get_lit_fingers() -> Array[Vector2i]:
	return _lit.duplicate()


## True when this (Hand, Finger) is lit.
func is_lit(hand_finger: Vector2i) -> bool:
	return hand_finger in _lit


## The current pulse outline width in px: 2 or 1 while something is lit, 0 otherwise.
func get_outline_width() -> int:
	return _outline_width


## The finger's fill colour: bright green when lit, resting green otherwise.
func get_finger_fill(hand_finger: Vector2i) -> Color:
	return BRIGHT_GREEN if is_lit(hand_finger) else RESTING_GREEN


## True for the home-row fingers (left index on f, right index on j), whatever is lit.
func has_bump(hand_finger: Vector2i) -> bool:
	return hand_finger.y == FingerMap.Finger.INDEX


## The glow frame shown: 0 (strong outline) or 1 (weak).
func get_glow_frame() -> int:
	return 0 if _outline_width == OUTLINE_STRONG else 1


func _draw() -> void:
	for hand: int in [FingerMap.Hand.LEFT, FingerMap.Hand.RIGHT]:
		var texture: Texture2D = _hand_textures.get(hand)
		if texture != null:
			draw_texture(texture, _hand_origin(hand))
	var frame: Rect2 = Rect2(get_glow_frame() * HAND_SIZE.x, 0, HAND_SIZE.x, HAND_SIZE.y)
	for hand_finger: Vector2i in _lit:
		var glow: Texture2D = _glow_textures.get(hand_finger)
		if glow != null:
			draw_texture_rect_region(glow, Rect2(_hand_origin(hand_finger.x), HAND_SIZE), frame)


func _hand_origin(hand: int) -> Vector2:
	return Vector2(LEFT_X if hand == FingerMap.Hand.LEFT else RIGHT_X, 0)


## A missing texture warns once and draws nothing (NFR16): the run never stops for art.
func _load(path: String) -> Texture2D:
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if texture == null and not _warned_missing:
		_warned_missing = true
		Log.warn(&"hands", "missing hand art %s; drawing what is there" % path)
	return texture
