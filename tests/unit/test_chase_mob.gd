extends GutTest
## The Pitchfork Panic mob (Story 8.6, FR70): four members from two recoloured bases, front to back, each on
## a different starting frame so the legs never march in lockstep; run() plays the 10 fps run, freeze()
## stops it dead on the current frame; get_back_px() is how far the mob reaches behind its origin (the front
## member's feet). A missing SpriteFrames warns once and never stops the run (NFR16).

const MobScene: PackedScene = preload("res://scenes/levels/pitchfork_panic/chase_mob.tscn")


func _make() -> ChaseMob:
	var mob: ChaseMob = MobScene.instantiate() as ChaseMob
	add_child_autofree(mob)
	return mob


func test_four_members_with_the_run_at_10_fps_and_different_starting_frames() -> void:
	var mob: ChaseMob = _make()
	var members: Array[AnimatedSprite2D] = mob.get_members()
	assert_eq(members.size(), 4)
	var frames_seen: Dictionary[int, bool] = {}
	for member: AnimatedSprite2D in members:
		assert_not_null(member.sprite_frames, member.name)
		assert_true(member.sprite_frames.has_animation(ChaseMob.ANIM_RUN), member.name)
		assert_eq(member.sprite_frames.get_animation_speed(ChaseMob.ANIM_RUN), 10.0, member.name)
		assert_eq(member.sprite_frames.get_frame_count(ChaseMob.ANIM_RUN), 4, member.name)
		assert_eq(member.animation, ChaseMob.ANIM_RUN)
		assert_false(member.centered)
		frames_seen[member.frame] = true
	assert_eq(frames_seen.size(), 4, "every member starts on its own frame")


func test_members_trail_behind_the_origin_front_drawn_last() -> void:
	var mob: ChaseMob = _make()
	var members: Array[AnimatedSprite2D] = mob.get_members()
	for i: int in members.size():
		assert_eq(members[i].position, Vector2(ChaseMob.MEMBER_OFFSETS[i] - 16.0, -31.0), members[i].name)
	assert_eq(ChaseMob.MEMBER_OFFSETS[0], 0.0, "the front member's feet are the origin")
	assert_true(ChaseMob.MEMBER_OFFSETS[3] >= -48.0, "the back member trails within 48 px")
	assert_gt(members[0].get_index(), members[3].get_index(), "the front member is drawn last")


func test_run_plays_and_freeze_pauses_on_the_current_frame() -> void:
	var mob: ChaseMob = _make()
	for member: AnimatedSprite2D in mob.get_members():
		assert_false(member.is_playing(), "frozen until run()")
	mob.run()
	for member: AnimatedSprite2D in mob.get_members():
		assert_true(member.is_playing())
		assert_eq(member.animation, ChaseMob.ANIM_RUN)
	var front: AnimatedSprite2D = mob.get_members()[0]
	front.frame = 2
	mob.freeze()
	assert_false(front.is_playing())
	assert_eq(front.frame, 2, "stops dead on the current frame")
	assert_eq(front.animation, ChaseMob.ANIM_RUN)


func test_back_reach_is_58_px() -> void:
	var mob: ChaseMob = _make()
	assert_eq(mob.get_back_px(), 58.0)


func test_no_sprite_frames_warns_once_and_keeps_going() -> void:
	var mob: ChaseMob = MobScene.instantiate() as ChaseMob
	for member: AnimatedSprite2D in mob.get_members():
		member.sprite_frames = null
	add_child_autofree(mob)
	assert_push_warning_count(1)
	mob.run()
	mob.freeze()
	assert_eq(mob.get_back_px(), 58.0)
