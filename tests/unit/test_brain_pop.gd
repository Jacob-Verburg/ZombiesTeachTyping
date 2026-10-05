extends GutTest
## Brain pop (Story 3.2, Story 3.6 frames): the cartoon brain that rises out of a bonked block, plays
## brain_pop.png and frees itself. The origin is the brain's bottom centre.

const PopScene: PackedScene = preload("res://scenes/levels/zombie_run/brain_pop.tscn")


func _pop(at: Vector2 = Vector2(0, -16)) -> BrainPop:
	var pop: BrainPop = PopScene.instantiate() as BrainPop
	pop.position = at
	pop.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(pop)
	return pop


func _sprite(pop: BrainPop) -> AnimatedSprite2D:
	return pop.get_node("%Sprite") as AnimatedSprite2D


func test_rises_then_frees_itself() -> void:
	var pop: BrainPop = _pop()
	pop.get_tween().custom_step(BrainPop.RISE_TIME_S * 0.5)
	assert_lt(pop.position.y, -16.0, "rising")
	assert_false(pop.is_queued_for_deletion())
	pop.get_tween().custom_step(BrainPop.RISE_TIME_S)
	assert_almost_eq(pop.position.y, -16.0 - BrainPop.RISE_PX, 0.01)
	assert_eq(pop.position.x, 0.0, "straight up")
	assert_true(pop.is_queued_for_deletion(), "self-freeing one-shot")


func test_plays_the_brain_pop_frames() -> void:
	var sprite: AnimatedSprite2D = _sprite(_pop())
	assert_not_null(sprite.sprite_frames)
	assert_eq(sprite.animation, BrainPop.ANIM_POP)
	assert_eq(sprite.sprite_frames.get_frame_count(BrainPop.ANIM_POP), 2)
	assert_eq(sprite.sprite_frames.get_animation_speed(BrainPop.ANIM_POP), 8.0)
	assert_true(sprite.sprite_frames.get_animation_loop(BrainPop.ANIM_POP))
	assert_eq(sprite.autoplay, String(BrainPop.ANIM_POP))


## The sheet's brain bottom (ink) is cell row 14 and its centre is x 8: placed at (-8, -15), the brain's
## bottom edge sits on the node's y 0 and it is centred on x 0.
func test_origin_is_the_bottom_centre() -> void:
	var sprite: AnimatedSprite2D = _sprite(_pop())
	assert_false(sprite.centered)
	assert_eq(sprite.position, Vector2(-8, -15))
	var atlas: AtlasTexture = sprite.sprite_frames.get_frame_texture(BrainPop.ANIM_POP, 0) as AtlasTexture
	var image: Image = atlas.atlas.get_image().get_region(Rect2i(atlas.region))
	var lowest: int = -1
	var left: int = 16
	var right: int = -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a8 == 255:
				lowest = y
				left = mini(left, x)
				right = maxi(right, x)
	assert_eq(sprite.position.y + lowest + 1, 0.0, "bottom edge on y 0")
	assert_eq(sprite.position.x + (left + right + 1) * 0.5, 0.0, "centred on x 0")
