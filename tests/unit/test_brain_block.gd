extends GutTest
## Brain block (Story 3.2, FR33): a ZombieRunTarget that floats above the ground line, pays brains on
## resolve, bonks (Story 3.6: the bonk frames play once and hold the grey used block) and pops a
## self-freeing brain.

const BlockScene: PackedScene = preload("res://scenes/levels/zombie_run/brain_block.tscn")
const FLOAT_PX: float = 48.0


func _block(letter: String = "k", slot: int = 3, brains: int = 1) -> BrainBlock:
	var block: BrainBlock = BlockScene.instantiate() as BrainBlock
	block.setup(letter, slot)
	block.configure(FLOAT_PX, brains)
	block.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(block)
	return block


func _pops(block: BrainBlock) -> Array[BrainPop]:
	var out: Array[BrainPop] = []
	for child: Node in block.get_node("%Lift").get_children():
		if child is BrainPop:
			out.append(child as BrainPop)
	return out


func _sprite(block: BrainBlock) -> AnimatedSprite2D:
	return block.get_node("%Sprite") as AnimatedSprite2D


func test_is_a_target_with_its_letter_floating() -> void:
	var block: BrainBlock = _block("q", 7)
	assert_true(block is ZombieRunTarget)
	assert_eq(block.get_letter(), "q")
	assert_eq(block.get_slot(), 7)
	assert_eq((block.get_node("%Letter") as Label).text, "q", "tag shows the letter")
	assert_eq((block.get_node("%Lift") as Node2D).position.y, -FLOAT_PX, "floats 48 px above the ground")
	assert_eq(block.position, Vector2.ZERO, "the origin stays on the ground line")
	assert_false(block.is_used())


func test_tag_and_arrow_sit_above_the_block() -> void:
	var block: BrainBlock = _block()
	var sprite: AnimatedSprite2D = _sprite(block)
	var tag: Panel = block.get_node("%Tag") as Panel
	assert_eq(sprite.get_parent(), block.get_node("%Lift"), "the block rides %Lift")
	assert_false(sprite.centered)
	assert_eq(sprite.position, Vector2(-8, -BrainBlock.BLOCK_SIZE_PX), "16 x 16, centred on x 0")
	var cell: Vector2 = Vector2(sprite.sprite_frames.get_frame_texture(&"idle", 0).get_size())
	assert_eq(cell, Vector2(BrainBlock.BLOCK_SIZE_PX, BrainBlock.BLOCK_SIZE_PX))
	assert_eq(sprite.position.y + cell.y, 0.0, "the block's bottom edge is at %Lift y 0")
	assert_eq(tag.size, Vector2(24, 24), "same tag as the generic target")
	assert_lt(tag.position.y + tag.size.y, sprite.position.y, "tag above the block")
	assert_true(tag.size.x * 0.5 <= ZombieRunTarget.HALF_WIDTH, "nothing wider than the tag")
	assert_true(cell.x * 0.5 <= ZombieRunTarget.HALF_WIDTH)
	var icon: Sprite2D = block.get_node("%Arrow/Icon") as Sprite2D
	assert_eq(icon.position + Vector2(8, 15), Vector2(0, -46), "the arrow tip stays where it was")
	assert_eq(tag.position.y - (icon.position.y + 15), 4.0, "the tag top is 4 px below the tip")


func test_active_shows_the_arrow() -> void:
	var block: BrainBlock = _block()
	block.set_active(true)
	assert_true((block.get_node("%Arrow") as CanvasItem).visible)
	block.set_active(false)
	assert_false((block.get_node("%Arrow") as CanvasItem).visible)


func test_resolve_pays_brains_once() -> void:
	var block: BrainBlock = _block("k", 3, 1)
	block.set_active(true)
	assert_eq(block.resolve(), 1, "brains_per_block")
	assert_true(block.is_resolved())
	assert_true(block.is_used())
	assert_false((block.get_node("%Tag") as CanvasItem).visible)
	assert_false((block.get_node("%Arrow") as CanvasItem).visible)
	assert_eq(block.resolve(), 0, "a second resolve pays nothing")
	assert_eq(_pops(block).size(), 1, "no second pop")


func test_resolve_pays_the_configured_brains() -> void:
	assert_eq(_block("k", 0, 3).resolve(), 3)


func test_sprite_animations() -> void:
	var frames: SpriteFrames = _sprite(_block()).sprite_frames
	assert_not_null(frames)
	assert_eq(frames.get_frame_count(BrainBlock.ANIM_IDLE), 2)
	assert_eq(frames.get_animation_speed(BrainBlock.ANIM_IDLE), 8.0)
	assert_true(frames.get_animation_loop(BrainBlock.ANIM_IDLE))
	assert_eq(frames.get_frame_count(BrainBlock.ANIM_BONK), 3)
	assert_eq(frames.get_animation_speed(BrainBlock.ANIM_BONK), 12.0)
	assert_false(frames.get_animation_loop(BrainBlock.ANIM_BONK), "the bonk plays once")


## Idle before the bonk; the bonk plays once and ends on (and holds) the used frame.
func test_used_look() -> void:
	var block: BrainBlock = _block()
	block.process_mode = Node.PROCESS_MODE_INHERIT
	var sprite: AnimatedSprite2D = _sprite(block)
	assert_eq(sprite.animation, BrainBlock.ANIM_IDLE, "pink idle before the bonk")
	block.resolve()
	assert_true(block.is_used())
	assert_eq(sprite.animation, BrainBlock.ANIM_BONK)
	assert_eq(sprite.frame, 0)
	assert_true(sprite.is_playing())
	# Let the tree play it: 3 frames at 12 fps is 0.25 s.
	await wait_for_signal(sprite.animation_finished, 2.0)
	assert_eq(sprite.frame, 2, "ends on the last frame")
	assert_false(sprite.is_playing(), "plays once")
	await wait_frames(10)
	assert_eq(sprite.animation, BrainBlock.ANIM_BONK)
	assert_eq(sprite.frame, 2, "holds the used block")
	var used: AtlasTexture = sprite.sprite_frames.get_frame_texture(BrainBlock.ANIM_BONK, 2) as AtlasTexture
	var image: Image = used.atlas.get_image().get_region(Rect2i(used.region))
	for y: int in image.get_height():
		for x: int in image.get_width():
			var hex: String = image.get_pixel(x, y).to_html(false)
			assert_true(hex != "f29ab8" and hex != "c9607f", "no pink on the used block (%d,%d)" % [x, y])


func test_missing_sprite_frames_still_pays() -> void:
	var block: BrainBlock = BlockScene.instantiate() as BrainBlock
	block.setup("k", 0)
	block.configure(FLOAT_PX, 2)
	(block.get_node("%Sprite") as AnimatedSprite2D).sprite_frames = null
	block.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(block)
	assert_push_warning("brain block has no sprite frames")
	assert_eq(block.resolve(), 2, "a missing sprite never stops a run (NFR16)")
	assert_true(block.is_used())


func test_bonk_moves_lift_and_returns() -> void:
	var block: BrainBlock = _block()
	block.resolve()
	var lift: Node2D = block.get_node("%Lift") as Node2D
	var tween: Tween = block.get_bonk_tween()
	assert_not_null(tween)
	assert_true(tween.is_valid())
	tween.custom_step(BrainBlock.BONK_TIME_S * 0.5)
	assert_almost_eq(lift.position.y, -FLOAT_PX - BrainBlock.BONK_PX, 0.01, "nudged up")
	assert_eq((block.get_node("%Visual") as Node2D).position.y, 0.0, "the bob's node is untouched")
	tween.custom_step(BrainBlock.BONK_TIME_S)
	assert_almost_eq(lift.position.y, -FLOAT_PX, 0.01, "back at rest")
	assert_eq(block.position, Vector2.ZERO, "the level's position is untouched")


func test_brain_pops_out_and_frees_itself() -> void:
	var block: BrainBlock = _block()
	block.resolve()
	var pops: Array[BrainPop] = _pops(block)
	assert_eq(pops.size(), 1)
	var pop: BrainPop = pops[0]
	var start_y: float = pop.position.y
	assert_eq(start_y, -BrainBlock.BLOCK_SIZE_PX, "starts at the block's top")
	pop.get_tween().custom_step(BrainPop.RISE_TIME_S * 0.5)
	assert_lt(pop.position.y, start_y, "rising")
	assert_false(pop.is_queued_for_deletion())
	pop.get_tween().custom_step(BrainPop.RISE_TIME_S)
	assert_almost_eq(pop.position.y, start_y - BrainPop.RISE_PX, 0.01)
	assert_true(pop.is_queued_for_deletion(), "self-freeing one-shot")
