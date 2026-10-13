class_name EscapeBush
extends Node2D
## Placeholder bush the zombie dives into when it escapes in Pitchfork Panic (Story 8.5): overlapping
## art-grass and zombie-green-dark circles with an ink outline, about 40x32 px, origin at the bottom centre
## on the ground. rustle() wiggles it with a node-bound tween and ends at scale 1. One bush for every setting
## for now; Story 8.6 may swap the drawing for sprites.

const ART_GRASS: Color = Color("#4E9A34")
const GREEN_DARK: Color = Color("#2E6B26")
const INK: Color = Color("#1E1428")
## Leaf clumps as (centre x, centre y, radius), back to front. Layout values.
const CLUMPS: Array[Vector3] = [
	Vector3(-12.0, -10.0, 9.0), Vector3(12.0, -10.0, 9.0), Vector3(-5.0, -20.0, 10.0),
	Vector3(7.0, -21.0, 9.0), Vector3(0.0, -11.0, 11.0),
]
## Wiggles per rustle (look value).
const WIGGLES: int = 4
## How far a wiggle squashes and stretches (look value).
const WIGGLE_SCALE: float = 0.12

var _tween: Tween


## Wiggles the bush for duration_s; it always ends at scale 1. A second call restarts it.
func rustle(duration_s: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	var beat: float = maxf(0.0, duration_s) / (WIGGLES + 1)
	_tween = create_tween()
	for i: int in WIGGLES:
		var k: float = WIGGLE_SCALE if i % 2 == 0 else -WIGGLE_SCALE
		_tween.tween_property(self, "scale", Vector2(1.0 + k, 1.0 - k), beat)
	_tween.tween_property(self, "scale", Vector2.ONE, beat)


## The running rustle tween (tests step it with custom_step); null before rustle().
func get_tween() -> Tween:
	return _tween


func _draw() -> void:
	for clump: Vector3 in CLUMPS:
		draw_circle(Vector2(clump.x, clump.y), clump.z + 1.0, INK)
	for i: int in CLUMPS.size():
		var clump: Vector3 = CLUMPS[i]
		draw_circle(Vector2(clump.x, clump.y), clump.z, GREEN_DARK if i < 2 else ART_GRASS)
