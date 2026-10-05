extends GutTest
## SunnyVillageBackdrop (Story 3.6, FR37): scroll_to() places each layer's two copies by its parallax
## factor, rounded to whole pixels and wrapped into [0, 640), so the copies always cover the screen for
## any camera x, including the negative x at the start of a run. Built from the level scene's Backdrop
## node (the layers are children there, no separate scene).

const LevelScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_level.tscn")
const LAYERS: Array[StringName] = [
	SunnyVillageBackdrop.LAYER_CLOUDS, SunnyVillageBackdrop.LAYER_FAR, SunnyVillageBackdrop.LAYER_NEAR,
	SunnyVillageBackdrop.LAYER_GROUND,
]
const SCREEN_W: float = 640.0

var _backdrop: SunnyVillageBackdrop


func before_each() -> void:
	# Only the backdrop: take it out of an un-added level instance so no level code runs.
	var level: Node = LevelScene.instantiate()
	_backdrop = level.get_node("Backdrop") as SunnyVillageBackdrop
	level.remove_child(_backdrop)
	_backdrop.owner = null
	level.free()
	add_child_autofree(_backdrop)


func _copies(layer: StringName) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child: Node in _backdrop.get_layer(layer).get_children():
		out.append(child as Sprite2D)
	return out


func test_layers_in_draw_order_with_two_copies() -> void:
	var names: Array[StringName] = []
	for child: Node in _backdrop.get_children():
		names.append(child.name)
	assert_eq_deep(names, [&"Sky", &"Clouds", &"Far", &"Near", &"Ground"])
	for layer: StringName in LAYERS:
		var copies: Array[Sprite2D] = _copies(layer)
		assert_eq(copies.size(), 2, "%s has two copies" % layer)
		assert_eq(copies[0].position, Vector2.ZERO, "%s copy A at 0" % layer)
		assert_eq(copies[1].position, Vector2(SunnyVillageBackdrop.PERIOD, 0), "%s copy B at 640" % layer)
		for copy: Sprite2D in copies:
			assert_false(copy.centered)
			assert_false(copy.region_enabled, "no region tiling")
			assert_eq(copy.texture_repeat, CanvasItem.TEXTURE_REPEAT_PARENT_NODE, "no repeat flags")
			assert_not_null(copy.texture)
			assert_eq(copy.texture.get_width(), int(SunnyVillageBackdrop.PERIOD))
		assert_eq(copies[0].texture, copies[1].texture, "%s: the same texture twice" % layer)
	assert_eq(_backdrop.get_layer(SunnyVillageBackdrop.LAYER_GROUND).position.y, 192.0, "ground strip under the line")


func test_factors() -> void:
	assert_eq(SunnyVillageBackdrop.FACTORS[SunnyVillageBackdrop.LAYER_GROUND], 1.0, "the ground moves with the world")
	assert_lt(SunnyVillageBackdrop.CLOUD_FACTOR, SunnyVillageBackdrop.FAR_FACTOR, "clouds slowest")
	assert_lt(SunnyVillageBackdrop.FAR_FACTOR, SunnyVillageBackdrop.NEAR_FACTOR)
	assert_lt(SunnyVillageBackdrop.NEAR_FACTOR, SunnyVillageBackdrop.GROUND_FACTOR)


func test_scroll_moves_layers_by_their_factors() -> void:
	_backdrop.scroll_to(100.0)
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_GROUND), 100.0)
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_NEAR), 50.0)
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_FAR), 25.0)
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_CLOUDS), 10.0)
	for layer: StringName in LAYERS:
		assert_eq(_backdrop.get_layer(layer).position.x, -_backdrop.get_layer_offset(layer), "%s at -offset" % layer)


func test_offsets_are_rounded_to_whole_pixels() -> void:
	_backdrop.scroll_to(10.6)
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_GROUND), 11.0, "roundf, not floorf")
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_NEAR), 5.0, "5.3 rounds to 5")
	_backdrop.scroll_to(13.0)
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_NEAR), 7.0, "6.5 rounds away from zero")
	assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_FAR), 3.0, "3.25 rounds to 3")


func test_ground_offset_is_the_rounded_camera_mod_640() -> void:
	for camera_x: float in [-72.0, -0.4, 0.0, 0.5, 639.4, 640.0, 1279.6, 12345.67, -1000.2]:
		_backdrop.scroll_to(camera_x)
		assert_eq(_backdrop.get_layer_offset(SunnyVillageBackdrop.LAYER_GROUND),
				fposmod(roundf(camera_x), 640.0), "camera x %.2f" % camera_x)


## For every camera x (negative start, a long run, huge x) every offset is in [0, 640) and copy A's left
## edge is at or left of 0 and copy B's right edge at or right of 640: no gap.
func test_copies_always_cover_the_screen() -> void:
	var xs: Array[float] = []
	var x: float = -200.0
	while x < 2000.0:
		xs.append(x)
		x += 0.37
	x = 0.0
	while x <= 1000000.0:
		xs.append(x)
		x += 9973.3
	for camera_x: float in xs:
		_backdrop.scroll_to(camera_x)
		for layer: StringName in LAYERS:
			var offset: float = _backdrop.get_layer_offset(layer)
			if offset < 0.0 or offset >= SunnyVillageBackdrop.PERIOD:
				fail_test("%s offset %.2f out of range at camera x %.2f" % [layer, offset, camera_x])
				return
			var layer_x: float = _backdrop.get_layer(layer).position.x
			var copies: Array[Sprite2D] = _copies(layer)
			var a_left: float = layer_x + copies[0].position.x
			var b_right: float = layer_x + copies[1].position.x + copies[1].texture.get_width()
			if a_left > 0.0 or b_right < SCREEN_W or layer_x != roundf(layer_x):
				fail_test("%s gap or sub-pixel at camera x %.2f (A %.2f, B %.2f)" % [layer, camera_x, a_left, b_right])
				return
	pass_test("%d camera positions covered" % xs.size())


func test_deterministic_and_rng_free() -> void:
	seed(1234)
	var before: float = randf()
	seed(1234)
	_backdrop.scroll_to(4321.5)
	var first: Dictionary[StringName, float] = {}
	for layer: StringName in LAYERS:
		first[layer] = _backdrop.get_layer_offset(layer)
	_backdrop.scroll_to(-50.0)
	_backdrop.scroll_to(4321.5)
	for layer: StringName in LAYERS:
		assert_eq(_backdrop.get_layer_offset(layer), first[layer], "%s same offset for the same x" % layer)
	assert_eq(randf(), before, "scroll_to drew nothing from the global RNG")


func test_has_no_process() -> void:
	assert_false(_backdrop.is_processing(), "moves only when the level calls scroll_to")
	assert_false(_backdrop.is_physics_processing())
