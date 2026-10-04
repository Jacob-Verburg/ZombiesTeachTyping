extends Control
## The green zombie hands finger guide (FR15-FR18) in the HUD's hands area (312 x 48). The finger(s)
## for the next character glow brighter green and get a pulsing candy-yellow outline (brightness plus
## shape, never hue alone, NFR8); the f and j fingertips always carry a home-row bump. The HUD calls
## show_char() with the current target; the hands never read input, the session, the clock or any
## autoload except Log. Placeholder drawing in code until Story 5.0's sprites (2 hands + 10 glow states); the
## getters below are the contract that version keeps.

## Active finger pulse, about 2 Hz (EXPERIENCE.md Game Feel [ASSUMPTION]), below the 3 flashes/s limit.
const PULSE_HZ: float = 2.0
## The outline switches between these widths every half period; a new cue starts at the strong one.
const OUTLINE_STRONG: int = 2
const OUTLINE_WEAK: int = 1

## Palette colours (DESIGN.md hands tokens).
const RESTING_GREEN: Color = Color("#6CC24A")
const BRIGHT_GREEN: Color = Color("#B8F27C")
const DARK_GREEN: Color = Color("#2E6B26")
const INK: Color = Color("#1E1428")
const CANDY_YELLOW: Color = Color("#FFD23F")

## Left-hand geometry in local px (outline included); the right hand is its mirror about x = 156.
## Fingers, outer to inner: pinky (shortest), ring, middle (tallest), index, then the thumb pointing inward.
const LEFT_FINGERS: Dictionary[FingerMap.Finger, Rect2i] = {
	FingerMap.Finger.PINKY: Rect2i(62, 16, 8, 15),
	FingerMap.Finger.RING: Rect2i(72, 10, 8, 21),
	FingerMap.Finger.MIDDLE: Rect2i(82, 6, 8, 25),
	FingerMap.Finger.INDEX: Rect2i(92, 10, 8, 21),
	FingerMap.Finger.THUMB: Rect2i(103, 32, 15, 8),
}
## The left palm, under the fingers.
const LEFT_PALM: Rect2i = Rect2i(60, 30, 44, 16)
## Home-row bump on the index fingertips, relative to the finger rect's top-left.
const BUMP: Rect2i = Rect2i(2, 3, 4, 2)
## The hands mirror about this x (the hands area's centre, under the target sign).
const MIRROR_WIDTH: int = 312

## The touch-typing table; set in zombie_hands.tscn (injection, no data path in this script).
@export var finger_map: FingerMap

var _lit: Array[Vector2i] = []
var _pulse_time: float = 0.0
var _outline_width: int = 0


func _ready() -> void:
	if finger_map == null:
		Log.error(&"hands", "ZombieHands has no FingerMap; no finger will light")


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


func _draw() -> void:
	# Pulse outlines first, so the palm and the ink outlines sit on top of them.
	for hand_finger: Vector2i in _lit:
		_fill(_finger_rect(hand_finger).grow(_outline_width), CANDY_YELLOW)
	for hand: int in [FingerMap.Hand.LEFT, FingerMap.Hand.RIGHT]:
		_draw_part(_mirror(LEFT_PALM, hand), RESTING_GREEN)
		for finger: FingerMap.Finger in LEFT_FINGERS:
			var hand_finger: Vector2i = Vector2i(hand, finger)
			var rect: Rect2i = _finger_rect(hand_finger)
			_draw_part(rect, get_finger_fill(hand_finger))
			if has_bump(hand_finger):
				_fill(Rect2i(rect.position + BUMP.position, BUMP.size), DARK_GREEN)


func _finger_rect(hand_finger: Vector2i) -> Rect2i:
	return _mirror(LEFT_FINGERS[hand_finger.y as FingerMap.Finger], hand_finger.x)


func _mirror(rect: Rect2i, hand: int) -> Rect2i:
	if hand == FingerMap.Hand.LEFT:
		return rect
	return Rect2i(MIRROR_WIDTH - rect.position.x - rect.size.x, rect.position.y, rect.size.x, rect.size.y)


## A 1 px ink outline around a filled body, as two filled rects (hard pixels, no anti-aliasing).
func _draw_part(rect: Rect2i, fill: Color) -> void:
	_fill(rect, INK)
	_fill(rect.grow(-1), fill)


func _fill(rect: Rect2i, color: Color) -> void:
	draw_rect(Rect2(rect), color, true)
