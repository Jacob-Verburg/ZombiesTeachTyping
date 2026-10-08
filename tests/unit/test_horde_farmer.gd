extends GutTest
## The Farmer (Story 6.6): idle/walk/throw SpriteFrames from the farmer sheets, the play API (loops restart
## only on change, the throw is a one-shot that holds off the loops and then returns to the last wanted
## loop), and a stripped SpriteFrames never crashes (NFR16). The sprite never advances by itself here, so
## the throw's end is emitted by hand.

const FarmerScene: PackedScene = preload("res://scenes/levels/horde_rush/farmer.tscn")


func _farmer() -> HordeFarmer:
	var farmer: HordeFarmer = FarmerScene.instantiate() as HordeFarmer
	farmer.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(farmer)
	return farmer


func test_animations_frames_and_fps() -> void:
	var body: AnimatedSprite2D = _farmer().get_body()
	var frames: SpriteFrames = body.sprite_frames
	assert_not_null(frames)
	for spec: Array in [[HordeFarmer.ANIM_IDLE, 2, 8.0, true], [HordeFarmer.ANIM_WALK, 4, 10.0, true],
			[HordeFarmer.ANIM_THROW, 3, 12.0, false]]:
		var anim: StringName = spec[0]
		assert_true(frames.has_animation(anim), String(anim))
		assert_eq(frames.get_frame_count(anim), spec[1], "%s frames" % anim)
		assert_eq(frames.get_animation_speed(anim), spec[2], "%s fps" % anim)
		assert_eq(frames.get_animation_loop(anim), spec[3], "%s loop" % anim)
		for i: int in frames.get_frame_count(anim):
			var atlas: AtlasTexture = frames.get_frame_texture(anim, i) as AtlasTexture
			assert_eq(atlas.region, Rect2(i * 32, 0, 32, 32))
			assert_eq(atlas.atlas.resource_path, "res://assets/sprites/characters/farmer/farmer_%s.png" % anim)


func test_origin_is_the_feet_centre() -> void:
	var body: AnimatedSprite2D = _farmer().get_body()
	assert_eq(body.position, Vector2(-16, -31))
	assert_false(body.centered)
	assert_eq(body.animation, HordeFarmer.ANIM_IDLE, "idle by default")


func test_loops_restart_only_on_change() -> void:
	var farmer: HordeFarmer = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_walk()
	assert_eq(body.animation, HordeFarmer.ANIM_WALK)
	body.frame = 2
	farmer.play_walk()
	assert_eq(body.frame, 2, "the same loop is not restarted")
	farmer.play_idle()
	assert_eq(body.animation, HordeFarmer.ANIM_IDLE)


func test_the_throw_blocks_the_loops_until_it_ends() -> void:
	var farmer: HordeFarmer = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_walk()
	body.frame = 3
	farmer.play_throw()
	assert_true(farmer.is_throwing())
	assert_eq(body.animation, HordeFarmer.ANIM_THROW)
	assert_eq(body.frame, 0, "from its first frame")
	farmer.play_walk()
	farmer.play_idle()
	assert_eq(body.animation, HordeFarmer.ANIM_THROW, "the loops wait")
	body.animation_finished.emit()
	assert_false(farmer.is_throwing())
	assert_eq(body.animation, HordeFarmer.ANIM_IDLE, "the last wanted loop takes over")
	farmer.play_walk()
	assert_eq(body.animation, HordeFarmer.ANIM_WALK)


func test_a_new_throw_restarts_it() -> void:
	var farmer: HordeFarmer = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_throw()
	body.frame = 2
	farmer.play_throw()
	assert_eq(body.frame, 0)
	assert_true(farmer.is_throwing())


func test_a_loop_ending_never_ends_the_throw_state() -> void:
	var farmer: HordeFarmer = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_walk()
	body.animation_finished.emit()
	assert_false(farmer.is_throwing())
	assert_eq(body.animation, HordeFarmer.ANIM_WALK)


func test_no_sprite_frames_does_not_crash() -> void:
	var farmer: HordeFarmer = FarmerScene.instantiate() as HordeFarmer
	(farmer.get_node("Body") as AnimatedSprite2D).sprite_frames = null
	add_child_autofree(farmer)
	farmer.play_idle()
	farmer.play_walk()
	farmer.play_throw()
	assert_false(farmer.is_throwing())
	assert_false(farmer.get_body().visible, "hidden")


func test_a_missing_throw_keeps_walking() -> void:
	var farmer: HordeFarmer = FarmerScene.instantiate() as HordeFarmer
	var body: AnimatedSprite2D = farmer.get_node("Body") as AnimatedSprite2D
	var frames: SpriteFrames = body.sprite_frames.duplicate() as SpriteFrames
	frames.remove_animation(HordeFarmer.ANIM_THROW)
	body.sprite_frames = frames
	add_child_autofree(farmer)
	farmer.play_walk()
	farmer.play_throw()
	farmer.play_throw()
	assert_false(farmer.is_throwing())
	assert_eq(body.animation, HordeFarmer.ANIM_WALK)
