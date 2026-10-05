extends GutTest
## Brain block (Story 3.2, FR33): a ZombieRunTarget that floats above the ground line, pays brains on
## resolve, switches to its used look, bonks and pops a self-freeing brain.

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


func _block_fill(block: BrainBlock) -> Color:
	return ((block.get_node("%Block") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color


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
	var box: Panel = block.get_node("%Block") as Panel
	var tag: Panel = block.get_node("%Tag") as Panel
	assert_eq(box.size, Vector2(16, 16))
	assert_eq(box.position.y + box.size.y, 0.0, "the block's bottom edge is at %Lift y 0")
	assert_eq(tag.size, Vector2(24, 24), "same tag as the generic target")
	assert_lt(tag.position.y + tag.size.y, box.position.y, "tag above the block")
	assert_true(tag.size.x * 0.5 <= ZombieRunTarget.HALF_WIDTH, "nothing wider than the tag")
	assert_true(box.size.x * 0.5 <= ZombieRunTarget.HALF_WIDTH)


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


func test_used_look() -> void:
	var block: BrainBlock = _block()
	assert_eq(_block_fill(block), Color("#F29AB8"), "pink before the bonk")
	assert_true((block.get_node("%Band") as CanvasItem).visible)
	block.resolve()
	assert_eq(_block_fill(block), BrainBlock.USED_FILL, "stone-light after the bonk")
	assert_false((block.get_node("%Band") as CanvasItem).visible, "no pink left")


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
