extends GutTest
## BrainPickup (Story 8.4): the brain on the Pitchfork Panic path. It shows the existing brain art sitting on
## the ground line; collect() leaves a BrainPop rising in its parent and frees the pickup.

const PickupScene: PackedScene = preload("res://scenes/levels/pitchfork_panic/brain_pickup.tscn")

var _parent: Node2D


func _make() -> BrainPickup:
	_parent = Node2D.new()
	add_child_autofree(_parent)
	var pickup: BrainPickup = PickupScene.instantiate() as BrainPickup
	pickup.position = Vector2(160.0, 192.0)
	_parent.add_child(pickup)
	return pickup


func _pops() -> Array[BrainPop]:
	var pops: Array[BrainPop] = []
	for child: Node in _parent.get_children():
		if child is BrainPop:
			pops.append(child as BrainPop)
	return pops


func test_uses_the_brain_pop_frames_and_sits_above_the_ground_line() -> void:
	var pickup: BrainPickup = _make()
	var sprite: AnimatedSprite2D = pickup.get_node("%Sprite")
	assert_not_null(sprite.sprite_frames)
	assert_true(sprite.is_playing())
	var frame: AtlasTexture = sprite.sprite_frames.get_frame_texture(sprite.animation, 0) as AtlasTexture
	assert_not_null(frame)
	if frame != null:
		assert_eq(frame.atlas.resource_path, "res://assets/sprites/props/brain_pop.png")
	# The sprite's bottom edge is LIFT_PX above the node origin (the ground line).
	assert_gt(BrainPickup.LIFT_PX, 0.0)
	assert_eq(sprite.position.y + 16.0, -BrainPickup.LIFT_PX)
	assert_eq(sprite.position.x, -8.0)


func test_collect_leaves_one_pop_in_the_parent_and_frees_the_pickup() -> void:
	var pickup: BrainPickup = _make()
	pickup.collect()
	assert_true(pickup.is_queued_for_deletion())
	var pops: Array[BrainPop] = _pops()
	assert_eq(pops.size(), 1)
	if pops.size() == 1:
		assert_eq(pops[0].position.x, 160.0)
		assert_eq(pops[0].position.y, 192.0 - BrainPickup.LIFT_PX)


func test_collect_can_put_the_pop_in_another_node() -> void:
	var pickup: BrainPickup = _make()
	var other: Node2D = Node2D.new()
	other.position = Vector2(10.0, 0.0)
	add_child_autofree(other)
	pickup.collect(other)
	assert_eq(_pops().size(), 0, "nothing in the pickup's own parent")
	assert_eq(other.get_child_count(), 1)
	var pop: BrainPop = other.get_child(0) as BrainPop
	assert_not_null(pop)
	if pop != null:
		assert_eq(pop.global_position, Vector2(160.0, 192.0 - BrainPickup.LIFT_PX), "same place on screen")


func test_collect_twice_is_harmless() -> void:
	var pickup: BrainPickup = _make()
	pickup.collect()
	pickup.collect()
	assert_eq(_pops().size(), 1)
