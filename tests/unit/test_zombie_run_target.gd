extends GutTest
## Generic Zombie Run target (Story 3.1): letter tag, active arrow + bob, one-way resolve. It stays the
## placeholder box; Story 3.6 makes its arrow the down_arrow.png sprite.

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


func test_arrow_is_the_sprite_above_the_tag() -> void:
	ArrowTipAssert.assert_tip(self, _target(), -50.0)


## Story 5.2 (AC 5): the tag and the base box are the theme's parchment sign (a 9-slice StyleBoxTexture, not a
## StyleBoxFlat); the letter keeps its ink, 16 px, centred look.
func test_tag_and_box_are_the_theme_sign() -> void:
	var target: ZombieRunTarget = _target()
	for path: String in ["%Tag", "%Box"]:
		var panel: Panel = target.get_node(path) as Panel
		assert_eq(panel.theme_type_variation, &"Sign", "%s uses the Sign variation" % path)
		assert_true(panel.get_theme_stylebox(&"panel") is StyleBoxTexture, "%s resolves to the 9-slice" % path)
	var letter: Label = target.get_node("%Letter") as Label
	assert_eq(letter.get_theme_font_size(&"font_size"), 16)
	assert_eq(letter.get_theme_color(&"font_color"), Color("#1E1428"), "ink")
	assert_eq(letter.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(letter.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	assert_eq((target.get_node("%Tag") as Control).size, Vector2(24, 24), "tag size unchanged")


## Story 5.2 (AC 5): a resolved base target greys out by switching its box to the grey sign.
func test_resolved_box_turns_to_the_grey_sign() -> void:
	var target: ZombieRunTarget = _target()
	var before: StyleBox = (target.get_node("%Box") as Panel).get_theme_stylebox(&"panel")
	target.resolve()
	var box: Panel = target.get_node("%Box") as Panel
	assert_eq(box.theme_type_variation, &"SignGrey")
	var after: StyleBox = box.get_theme_stylebox(&"panel")
	assert_true(after is StyleBoxTexture)
	assert_ne(after, before, "a visible change")
