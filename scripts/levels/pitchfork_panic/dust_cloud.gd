class_name DustCloud
extends Node2D
## Placeholder cartoon dust cloud for Pitchfork Panic's caught outro (Story 8.5): overlapping chalk and
## stone-light puffs with an ink outline, about 56x36 px, origin at the bottom centre on the ground. play()
## wobbles it with a node-bound tween and hides it at the end. Fixed offsets, no RNG. Story 8.6 may swap the
## drawing for sprites without changing the level.

const CHALK: Color = Color("#F4F1E4")
const STONE_LIGHT: Color = Color("#BDB6C4")
const INK: Color = Color("#1E1428")
## Puffs as (centre x, centre y, radius), drawn back to front. Layout values.
const PUFFS: Array[Vector3] = [
	Vector3(-18.0, -10.0, 10.0), Vector3(18.0, -10.0, 10.0), Vector3(-8.0, -22.0, 12.0),
	Vector3(10.0, -24.0, 11.0), Vector3(0.0, -12.0, 13.0), Vector3(-20.0, -6.0, 7.0), Vector3(21.0, -6.0, 7.0),
]
## Wobbles per second of play() (look value).
const WOBBLES_PER_S: float = 4.0
## Side-to-side jitter in px (look value).
const JITTER_PX: float = 2.0

var _tween: Tween
var _base_x: float = 0.0


## Shows the cloud and wobbles it for duration_s, then hides it. A second call restarts it.
func play(duration_s: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_base_x = position.x
	scale = Vector2.ONE
	visible = true
	queue_redraw()
	var d: float = maxf(0.0, duration_s)
	_tween = create_tween()
	var beats: int = maxi(1, roundi(d * WOBBLES_PER_S))
	var beat: float = d / beats
	for i: int in beats:
		var s: float = 1.1 if i % 2 == 0 else 0.9
		var dx: float = JITTER_PX if i % 2 == 0 else -JITTER_PX
		_tween.tween_property(self, "scale", Vector2(s, 2.0 - s), beat)
		_tween.parallel().tween_property(self, "position:x", _base_x + dx, beat)
	_tween.tween_callback(_finish)


## The running wobble tween (tests step it with custom_step); null before play().
func get_tween() -> Tween:
	return _tween


func _finish() -> void:
	scale = Vector2.ONE
	position.x = _base_x
	visible = false


func _draw() -> void:
	for puff: Vector3 in PUFFS:
		draw_circle(Vector2(puff.x, puff.y), puff.z + 1.0, INK)
	for i: int in PUFFS.size():
		var puff: Vector3 = PUFFS[i]
		draw_circle(Vector2(puff.x, puff.y), puff.z, STONE_LIGHT if i % 2 == 0 else CHALK)
	# Two little action lines inside, so it reads as a scuffle, not a cloud in the sky.
	draw_line(Vector2(-10.0, -16.0), Vector2(-4.0, -20.0), INK, 1.0)
	draw_line(Vector2(6.0, -14.0), Vector2(12.0, -18.0), INK, 1.0)
