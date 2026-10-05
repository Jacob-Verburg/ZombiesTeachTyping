class_name SunnyVillageBackdrop
extends Node2D
## The Sunny Village Green backdrop (Story 3.6, FR37): a static sky and four parallax layers behind
## Zombie Run's %World, drawn in this order: clouds, far hills, near village, ground strip.
##
## Each layer is a Node2D holding two Sprite2D copies of the same 640 px wide texture side by side (copy A
## at local x 0, copy B at PERIOD; centered = false, no region, no repeat flags). scroll_to() places the
## layer at -offset, where offset = fposmod(roundf(camera_x * factor), PERIOD), so copy A's left edge is at
## or left of 0 and copy B's right edge at or right of 640: the two always cover the screen, for any
## camera x including the negative x at the start of a run. Every texture is authored with wraparound
## (tools/gen_zombie_run_art.gd), so the joint never shows.
##
## roundf, not floorf: the renderer snaps node positions to whole pixels by rounding
## (snap_2d_transforms_to_pixel), so the ground layer (factor 1.0) moves exactly with %World and a target
## never swims on the path.
##
## It only moves when the level calls scroll_to() (from _set_zombie_x, the one place the camera moves):
## no _process, no tween, no timer, no RNG, no per-frame allocation and no logging. A missing texture
## logs one warning and the run goes on (NFR16).

const PERIOD: float = 640.0
const LAYER_CLOUDS: StringName = &"Clouds"
const LAYER_FAR: StringName = &"Far"
const LAYER_NEAR: StringName = &"Near"
const LAYER_GROUND: StringName = &"Ground"
## Parallax factors: look values, not GDD numbers. The ground moves exactly with the world.
const CLOUD_FACTOR: float = 0.1
const FAR_FACTOR: float = 0.25
const NEAR_FACTOR: float = 0.5
const GROUND_FACTOR: float = 1.0
const FACTORS: Dictionary[StringName, float] = {
	LAYER_CLOUDS: CLOUD_FACTOR,
	LAYER_FAR: FAR_FACTOR,
	LAYER_NEAR: NEAR_FACTOR,
	LAYER_GROUND: GROUND_FACTOR,
}

var _layers: Dictionary[StringName, Node2D] = {}
var _offsets: Dictionary[StringName, float] = {}


func _ready() -> void:
	var missing: Array[String] = []
	for layer_name: StringName in FACTORS:
		var layer: Node2D = get_node_or_null(NodePath(layer_name)) as Node2D
		if layer == null:
			missing.append(String(layer_name))
			continue
		_layers[layer_name] = layer
		_offsets[layer_name] = 0.0
		for copy: Node in layer.get_children():
			var sprite: Sprite2D = copy as Sprite2D
			if sprite == null or sprite.texture == null:
				missing.append("%s/%s" % [layer_name, copy.name])
	if not missing.is_empty():
		Log.warn(&"level", "sunny village backdrop is missing %s" % ", ".join(missing))


## Places every layer for the camera's world x (the world x at the screen's left edge).
func scroll_to(camera_x: float) -> void:
	for layer_name: StringName in _layers:
		var offset: float = fposmod(roundf(camera_x * FACTORS[layer_name]), PERIOD)
		_offsets[layer_name] = offset
		_layers[layer_name].position.x = -offset


## The layer's current offset in [0, PERIOD): copy A sits at -offset, copy B at PERIOD - offset. For tests.
func get_layer_offset(layer: StringName) -> float:
	return _offsets.get(layer, 0.0)


## The layer node (its two copies are its children), or null. For tests.
func get_layer(layer: StringName) -> Node2D:
	return _layers.get(layer, null)
