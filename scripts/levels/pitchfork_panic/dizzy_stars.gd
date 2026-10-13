class_name DizzyStars
extends Node2D
## Placeholder dizzy stars for Pitchfork Panic's caught outro (Story 8.5): three small candy-yellow 5-point
## stars with an ink outline orbiting on an ellipse about 20x6 px around this node's origin (put it above the
## zombie's head). The orbit runs in _process while visible, so it never needs a looping tween. start() /
## stop(). Story 8.6 may swap the drawing for sprites.

const CANDY_YELLOW: Color = Color("#FFD23F")
const INK: Color = Color("#1E1428")
const STAR_COUNT: int = 3
## Ellipse half-width and half-height in px (layout values).
const ORBIT: Vector2 = Vector2(10.0, 3.0)
## Outer and inner star radius in px (layout values).
const STAR_OUTER_PX: float = 3.5
const STAR_INNER_PX: float = 1.5
## Orbits per second (look value).
const TURNS_PER_S: float = 1.0

var _angle: float = 0.0


func _ready() -> void:
	set_process(visible)


## Shows the stars and starts the orbit.
func start() -> void:
	_angle = 0.0
	visible = true
	set_process(true)
	queue_redraw()


## Hides the stars and stops the orbit.
func stop() -> void:
	visible = false
	set_process(false)


## The orbit angle in radians (for tests).
func get_angle() -> float:
	return _angle


func _process(delta: float) -> void:
	_angle = fmod(_angle + TAU * TURNS_PER_S * delta, TAU)
	queue_redraw()


func _draw() -> void:
	for i: int in STAR_COUNT:
		var a: float = _angle + TAU * i / STAR_COUNT
		_draw_star(Vector2(cos(a) * ORBIT.x, sin(a) * ORBIT.y))


func _draw_star(centre: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var r: float = STAR_OUTER_PX if i % 2 == 0 else STAR_INNER_PX
		var a: float = -PI / 2.0 + PI * i / 5.0
		points.append(centre + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, CANDY_YELLOW)
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, INK, 1.0)
