class_name Poof
extends Node2D
## The dust cloud a hugged villager turns into (Story 3.3, FR34): 4 code-drawn frames (a small puff, a
## big puff, the big puff breaking up, a few tiny puffs), hard pixels in palette colours with a 1 px ink
## outline, never wider than the 24 px tag. A node-bound tween drives the frames, so it pauses with the
## tree and tests can custom_step it. When the last frame ends it emits finished and frees itself; the
## villager shows its party-hat zombie on finished (an effect chain, never input gating).
## The origin is the cloud's centre. Placeholder until Story 3.6's poof frames.

signal finished

## Look values (art spec "poof 4f", not GDD numbers).
const FRAMES: int = 4
const FPS: float = 12.0
const INK: Color = Color("#1E1428")
const FILL: Color = Color("#F4F1E4")
const SHADE: Color = Color("#BDB6C4")
## Per frame, one Vector3i per puff: x, y of the centre and the radius (the ink ring adds 1 px).
const PUFFS: Array[Array] = [
	[Vector3i(0, 0, 3)],
	[Vector3i(-5, 1, 4), Vector3i(5, 1, 4), Vector3i(0, -3, 6)],
	[Vector3i(-6, 2, 3), Vector3i(6, 1, 3), Vector3i(-2, -4, 4), Vector3i(4, -5, 2)],
	[Vector3i(-7, -6, 1), Vector3i(6, -4, 2), Vector3i(0, 3, 1)],
]

var _frame: int = 0
var _tween: Tween


## The puffs drawn on `frame` (for tests and _draw).
static func puffs(frame: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(PUFFS[frame])
	return out


func _ready() -> void:
	_tween = create_tween()
	_tween.tween_method(_set_frame, 0.0, float(FRAMES), FRAMES / FPS)
	_tween.tween_callback(_finish)


func get_frame() -> int:
	return _frame


## The frame tween (for tests).
func get_tween() -> Tween:
	return _tween


func _set_frame(t: float) -> void:
	var frame: int = mini(floori(t), FRAMES - 1)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _finish() -> void:
	finished.emit()
	queue_free()


## Ink discs first, then the shade, then the fill raised 1 px, so touching puffs merge into one cloud.
func _draw() -> void:
	var frame_puffs: Array[Vector3i] = puffs(_frame)
	for puff: Vector3i in frame_puffs:
		_disc(puff.x, puff.y, puff.z + 1, INK)
	for puff: Vector3i in frame_puffs:
		_disc(puff.x, puff.y, puff.z, SHADE)
	for puff: Vector3i in frame_puffs:
		_disc(puff.x, puff.y - 1, puff.z - 1, FILL)


## A hard-pixel disc: one 1 px tall rect per row.
func _disc(cx: int, cy: int, radius: int, color: Color) -> void:
	if radius < 0:
		return
	for dy: int in range(-radius, radius + 1):
		var half: int = floori(sqrt(float(radius * radius - dy * dy)) + 0.5)
		draw_rect(Rect2(cx - half, cy + dy, 2 * half + 1, 1), color)
