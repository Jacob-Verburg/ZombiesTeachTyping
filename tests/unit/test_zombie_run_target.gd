extends GutTest
## Generic Zombie Run target (Story 3.1): letter tag, active arrow + bob, one-way resolve.

const TargetScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_target.tscn")


func _target(letter: String = "k", slot: int = 3) -> ZombieRunTarget:
	var target: ZombieRunTarget = TargetScene.instantiate() as ZombieRunTarget
	target.setup(letter, slot)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(target)
	return target


func _visual_y(target: ZombieRunTarget) -> float:
	return (target.get_node("%Visual") as Node2D).position.y


func test_setup_before_add_child() -> void:
	var target: ZombieRunTarget = _target("q", 7)
	assert_eq(target.get_letter(), "q")
	assert_eq(target.get_slot(), 7)
	assert_eq((target.get_node("%Letter") as Label).text, "q", "tag shows the letter")
	assert_true((target.get_node("%Tag") as Control).visible)
	assert_false(target.is_active())
	assert_false(target.is_resolved())
	assert_false((target.get_node("%Arrow") as CanvasItem).visible, "inactive: no arrow")


func test_set_active_toggles_the_arrow() -> void:
	var target: ZombieRunTarget = _target()
	target.set_active(true)
	assert_true(target.is_active())
	assert_true((target.get_node("%Arrow") as CanvasItem).visible)
	target.set_active(false)
	assert_false(target.is_active())
	assert_false((target.get_node("%Arrow") as CanvasItem).visible)


func test_resolve() -> void:
	var target: ZombieRunTarget = _target()
	target.set_active(true)
	assert_eq(target.resolve(), 0, "the generic target earns no brains")
	assert_true(target.is_resolved())
	assert_false(target.is_active())
	assert_false((target.get_node("%Tag") as CanvasItem).visible)
	assert_false((target.get_node("%Arrow") as CanvasItem).visible)
	assert_eq(target.resolve(), 0, "second resolve is a no-op")
	assert_true(target.is_resolved())
	target.set_active(true)
	assert_false(target.is_active(), "a resolved target never becomes active again")
	assert_false((target.get_node("%Arrow") as CanvasItem).visible)


func test_inactive_target_does_not_bob() -> void:
	var target: ZombieRunTarget = _target()
	for i: int in 10:
		target._process(0.07)
		assert_eq(_visual_y(target), 0.0)


func test_active_target_bobs_and_settles_when_deactivated() -> void:
	var target: ZombieRunTarget = _target()
	target.set_active(true)
	var ys: Dictionary = {}
	for i: int in 10:
		target._process(0.07)
		ys[_visual_y(target)] = true
		assert_true(absf(_visual_y(target)) <= ZombieRunTarget.BOB_PX, "bob stays within BOB_PX")
	assert_gt(ys.size(), 1, "the active target moves")
	assert_eq(target.position, Vector2.ZERO, "the bob never moves the target's own position")
	target.set_active(false)
	assert_eq(_visual_y(target), 0.0)
	target.set_active(true)
	target.resolve()
	assert_eq(_visual_y(target), 0.0, "resolve stops the bob")
	target._process(0.2)
	assert_eq(_visual_y(target), 0.0)
