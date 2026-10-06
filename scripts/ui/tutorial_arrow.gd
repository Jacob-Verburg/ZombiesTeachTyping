class_name TutorialArrow
extends Control
## The tutorial arrow (Story 4.5; DESIGN.md / EXPERIENCE.md "tutorial-arrow", approved sketch
## sketches/crypt-closet-4-4.md frame D): a 24 x 20 candy-yellow triangle with a 1 px ink outline that bobs
## while it points. point_at() places it next to a target's global rect: DOWN sits centred above the target,
## RIGHT sits left of it, centred on its height. It never takes focus and ignores the mouse, so it never
## blocks input. The bob is drawn (draw_set_transform), so `position` stays at rest and exact. Carries no
## text. Hidden until point_at(). Placeholder chrome until Story 5.0 (the hand-drawn arrow).

enum Direction { DOWN, RIGHT }

## Look value, not a GDD number: how far the arrow bobs towards its target.
const BOB_PX: float = 2.0
## Look value, not a GDD number: one bob, there and back.
const BOB_PERIOD_S: float = 0.6
const ARROW_SIZE: Vector2 = Vector2(24, 20)
## Gap between the arrow's tip and a DOWN target's top, and a RIGHT target's left edge (with the arrow).
const DOWN_OFFSET: Vector2 = Vector2(-12, -24)
const RIGHT_OFFSET: Vector2 = Vector2(-32, -10)

## Palette (DESIGN.md Colors).
const CANDY_YELLOW: Color = Color("#FFD23F")
const INK: Color = Color("#1E1428")

var _direction: Direction = Direction.DOWN
var _bob_s: float = 0.0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	size = ARROW_SIZE
	custom_minimum_size = ARROW_SIZE
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_bob_s = fmod(_bob_s + delta, BOB_PERIOD_S)
	queue_redraw()


## Points at `target` (a global rect) and shows the arrow.
func point_at(target: Rect2, direction: Direction) -> void:
	_direction = direction
	var anchor: Vector2
	if direction == Direction.DOWN:
		anchor = Vector2(target.get_center().x, target.position.y) + DOWN_OFFSET
	else:
		anchor = Vector2(target.position.x, target.get_center().y) + RIGHT_OFFSET
	global_position = anchor.round()
	size = ARROW_SIZE
	show()
	queue_redraw()


func get_direction() -> Direction:
	return _direction


## The bob's current offset along the pointing direction, 0..BOB_PX px.
func get_bob_offset() -> float:
	return roundf(BOB_PX * 0.5 * (1.0 - cos(TAU * _bob_s / BOB_PERIOD_S)))


func _draw() -> void:
	var offset: float = get_bob_offset()
	var points: PackedVector2Array
	if _direction == Direction.DOWN:
		draw_set_transform(Vector2(0, offset))
		points = PackedVector2Array([Vector2(0, 0), Vector2(24, 0), Vector2(12, 20)])
	else:
		draw_set_transform(Vector2(offset, 0))
		points = PackedVector2Array([Vector2(0, 0), Vector2(24, 10), Vector2(0, 20)])
	draw_colored_polygon(points, CANDY_YELLOW)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, INK, 1.0)
