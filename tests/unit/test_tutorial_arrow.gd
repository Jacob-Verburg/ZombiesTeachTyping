extends GutTest
## The tutorial arrow (Story 4.5): hidden until it points, exact rest positions for DOWN and RIGHT (the
## approved sketch's frame D), never focusable, never takes the mouse, and the bob is drawn, never moved.

const ArrowScene: PackedScene = preload("res://scenes/ui/tutorial_arrow.tscn")


func _arrow() -> TutorialArrow:
	var arrow: TutorialArrow = ArrowScene.instantiate() as TutorialArrow
	add_child_autofree(arrow)
	return arrow


func test_hidden_until_it_points() -> void:
	var arrow: TutorialArrow = _arrow()
	assert_false(arrow.visible)
	assert_eq(arrow.size, Vector2(24, 20))


func test_down_sits_centred_above_the_target() -> void:
	var arrow: TutorialArrow = _arrow()
	arrow.point_at(Rect2(16, 76, 68, 68), TutorialArrow.Direction.DOWN)
	assert_true(arrow.visible)
	assert_eq(arrow.global_position, Vector2(38, 52))
	assert_eq(arrow.size, Vector2(24, 20))
	assert_eq(arrow.get_direction(), TutorialArrow.Direction.DOWN)


func test_down_on_the_first_pet_tile() -> void:
	var arrow: TutorialArrow = _arrow()
	arrow.point_at(Rect2(412, 76, 68, 68), TutorialArrow.Direction.DOWN)
	assert_eq(arrow.global_position, Vector2(434, 52))


func test_right_sits_left_of_the_target() -> void:
	var arrow: TutorialArrow = _arrow()
	arrow.point_at(Rect2(208, 216, 96, 32), TutorialArrow.Direction.RIGHT)
	assert_eq(arrow.global_position, Vector2(176, 222))
	assert_eq(arrow.get_direction(), TutorialArrow.Direction.RIGHT)


func test_positions_are_whole_pixels() -> void:
	var arrow: TutorialArrow = _arrow()
	arrow.point_at(Rect2(10, 40, 33, 33), TutorialArrow.Direction.DOWN)
	assert_eq(arrow.global_position, arrow.global_position.round())


func test_never_focusable_and_ignores_the_mouse() -> void:
	var arrow: TutorialArrow = _arrow()
	assert_eq(arrow.focus_mode, Control.FOCUS_NONE)
	assert_eq(arrow.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_bob_never_moves_the_position() -> void:
	var arrow: TutorialArrow = _arrow()
	arrow.point_at(Rect2(16, 76, 68, 68), TutorialArrow.Direction.DOWN)
	var offsets: Array[float] = []
	for i: int in 6:
		arrow._process(TutorialArrow.BOB_PERIOD_S / 6.0)
		offsets.append(arrow.get_bob_offset())
		assert_eq(arrow.global_position, Vector2(38, 52), "rest position at step %d" % i)
	assert_eq(offsets.max(), TutorialArrow.BOB_PX, "bobs the full distance")
	assert_eq(offsets.min(), 0.0, "and back")


## Story 5.0: the hand-drawn arrow sprites, one per direction, the arrow's own 24 x 20 size.
func test_arrow_art_fits_the_arrow() -> void:
	for direction: TutorialArrow.Direction in TutorialArrow.ARROWS:
		var texture: Texture2D = TutorialArrow.ARROWS[direction]
		assert_eq(texture.get_size(), TutorialArrow.ARROW_SIZE, "direction %d" % direction)
	assert_string_contains(TutorialArrow.ARROWS[TutorialArrow.Direction.DOWN].resource_path, "ui_arrow_down.png")
	assert_string_contains(TutorialArrow.ARROWS[TutorialArrow.Direction.RIGHT].resource_path, "ui_arrow_right.png")
