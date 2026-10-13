class_name DizzyStars
extends Node2D
## Dizzy stars for Pitchfork Panic's caught outro (Story 8.5; sprites in 8.6): three small parchment stars
## (props/dizzy_star.png, 2 frames twinkling at FPS) orbiting on an ellipse around this node's origin (put it
## just above the dazed zombie's head). The orbit runs in _process while visible, so it never needs a looping
## tween; positions are rounded to whole px. start() / stop(). The star sprites are built in code (tests
## create this node with new()); a missing sheet logs one warning and the stars stay empty (NFR16).

const SHEET_PATH: String = "res://assets/sprites/props/dizzy_star.png"
const ANIM: StringName = &"twinkle"
const FRAME_COUNT: int = 2
const FRAME_PX: int = 16
const FPS: float = 8.0
const STAR_COUNT: int = 3
## Ellipse half-width and half-height in px (layout values).
const ORBIT: Vector2 = Vector2(12.0, 3.0)
## Puts the star's centre (sheet pixel about (7, 9)) on its orbit point. Layout value.
const STAR_OFFSET: Vector2 = Vector2(-7.0, -9.0)
## Orbits per second (look value).
const TURNS_PER_S: float = 1.0

var _angle: float = 0.0
var _stars: Array[AnimatedSprite2D] = []


func _ready() -> void:
	var frames: SpriteFrames = SheetFrames.build(SHEET_PATH, FRAME_COUNT, FRAME_PX, FPS, ANIM, true, "dizzy stars")
	if frames != null:
		for i: int in STAR_COUNT:
			var star: AnimatedSprite2D = AnimatedSprite2D.new()
			star.name = "Star%d" % i
			star.centered = false
			star.sprite_frames = frames
			star.animation = ANIM
			star.frame = i % FRAME_COUNT
			add_child(star)
			_stars.append(star)
	_place_stars()
	set_process(visible)


## Shows the stars and starts the orbit and the twinkle.
func start() -> void:
	_angle = 0.0
	visible = true
	set_process(true)
	for star: AnimatedSprite2D in _stars:
		star.play(ANIM)
	_place_stars()


## Hides the stars and stops the orbit.
func stop() -> void:
	visible = false
	set_process(false)
	for star: AnimatedSprite2D in _stars:
		star.stop()


## The orbit angle in radians (for tests).
func get_angle() -> float:
	return _angle


## The star sprites (empty without the sheet). For tests.
func get_stars() -> Array[AnimatedSprite2D]:
	return _stars


func _process(delta: float) -> void:
	_angle = fmod(_angle + TAU * TURNS_PER_S * delta, TAU)
	_place_stars()


func _place_stars() -> void:
	for i: int in _stars.size():
		var a: float = _angle + TAU * i / STAR_COUNT
		_stars[i].position = Vector2(roundf(cos(a) * ORBIT.x), roundf(sin(a) * ORBIT.y)) + STAR_OFFSET
