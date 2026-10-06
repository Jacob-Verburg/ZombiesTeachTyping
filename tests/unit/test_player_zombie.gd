extends GutTest
## Player zombie (Story 3.1): idle and walk animations from the approved prototype sheets.
## Hop (Story 3.2): a sine arc on Body, one hop tween at a time, never the node's own position.
## Hug (Story 3.3): a lean on Body.position.x, independent of the hop on Body.position.y.
## Dance (Story 3.5): a code bounce on Body.position.y; it cuts the hop and the hug. Without dance frames
## (a stripped SpriteFrames) it plays idle and flips per beat; with the Story 3.6 frames the sheet sways.
## Story 3.6: hop/hug/dance play their frames, and play_walk()/play_idle() never clobber them.

const PlayerZombieScene: PackedScene = preload("res://scenes/characters/player_zombie.tscn")


func _zombie() -> PlayerZombie:
	var zombie: PlayerZombie = PlayerZombieScene.instantiate() as PlayerZombie
	add_child_autofree(zombie)
	return zombie


func _body(zombie: PlayerZombie) -> AnimatedSprite2D:
	return zombie.get_node("Body") as AnimatedSprite2D


func test_animations() -> void:
	var frames: SpriteFrames = _body(_zombie()).sprite_frames
	assert_not_null(frames)
	assert_true(frames.has_animation(&"idle"))
	assert_eq(frames.get_frame_count(&"idle"), 2)
	assert_eq(frames.get_animation_speed(&"idle"), 8.0)
	assert_true(frames.get_animation_loop(&"idle"))
	assert_true(frames.has_animation(&"walk"))
	assert_eq(frames.get_frame_count(&"walk"), 4)
	assert_eq(frames.get_animation_speed(&"walk"), 10.0)
	assert_true(frames.get_animation_loop(&"walk"))


## Story 3.6: hop and hug play once, the dance loops at one cycle per DANCE_BEAT_HZ beat.
func test_story_3_6_animations() -> void:
	var frames: SpriteFrames = _body(_zombie()).sprite_frames
	for spec: Array in [[PlayerZombie.ANIM_HOP, 3, 10.0, false], [PlayerZombie.ANIM_HUG, 3, 10.0, false],
			[PlayerZombie.ANIM_DANCE, 4, 8.0, true]]:
		var anim: StringName = spec[0]
		assert_true(frames.has_animation(anim), anim)
		assert_eq(frames.get_frame_count(anim), spec[1], "%s frames" % anim)
		assert_eq(frames.get_animation_speed(anim), spec[2], "%s fps" % anim)
		assert_eq(frames.get_animation_loop(anim), spec[3], "%s loop" % anim)
		for i: int in frames.get_frame_count(anim):
			var atlas: AtlasTexture = frames.get_frame_texture(anim, i) as AtlasTexture
			assert_not_null(atlas.atlas, "%s frame %d texture" % [anim, i])
			assert_eq(atlas.region, Rect2(i * 32, 0, 32, 32))
	assert_eq(frames.get_animation_speed(PlayerZombie.ANIM_DANCE) / frames.get_frame_count(PlayerZombie.ANIM_DANCE),
			PlayerZombie.DANCE_BEAT_HZ, "one sway cycle per bounce")


func test_origin_is_the_feet_centre() -> void:
	var body: AnimatedSprite2D = _body(_zombie())
	assert_false(body.centered)
	assert_eq(body.position, Vector2(-16, -31), "soles (sheet row 30) end on the node's y = 0")


func test_play_walk_and_idle_switch() -> void:
	var zombie: PlayerZombie = _zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.play_walk()
	assert_eq(body.animation, &"walk")
	assert_true(body.is_playing())
	body.frame = 2
	zombie.play_walk()
	assert_eq(body.frame, 2, "already walking: not restarted")
	zombie.play_idle()
	assert_eq(body.animation, &"idle")
	assert_true(body.is_playing())


## Story 4.3: a HatSlot following Body with the zombie's anchors (test_hat_slot.gd covers the rest).
func test_hat_slot_exists() -> void:
	var zombie: PlayerZombie = _zombie()
	var slot: HatSlot = zombie.get_node("%HatSlot") as HatSlot
	assert_not_null(slot, "%HatSlot is a HatSlot")
	assert_eq(slot.sprite, _body(zombie))
	assert_eq(slot.get_parent(), _body(zombie), "a child of Body, so the tweens carry it")
	assert_eq(slot.anchors, load("res://data/anchors/zombie_anchors.tres"))


# --- hop (Story 3.2) --------------------------------------------------------

const REST_Y: float = -31.0


func _still_zombie() -> PlayerZombie:
	var zombie: PlayerZombie = PlayerZombieScene.instantiate() as PlayerZombie
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(zombie)
	zombie.position = Vector2(100, 192)
	return zombie


func test_size_const() -> void:
	assert_eq(PlayerZombie.SIZE_PX, 32.0)


func test_hop_arc() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	assert_false(zombie.is_hopping())
	zombie.hop(0.35, 16.0)
	assert_true(zombie.is_hopping())
	zombie.get_hop_tween().custom_step(0.175)
	assert_almost_eq(body.position.y, REST_Y - 16.0, 0.01, "top of the arc at half time")
	assert_eq(zombie.position, Vector2(100, 192), "the node never moves")
	zombie.get_hop_tween().custom_step(0.2)
	assert_eq(body.position.y, REST_Y, "back at rest")
	assert_false(zombie.is_hopping())
	assert_eq(zombie.position, Vector2(100, 192))


func test_second_hop_restarts_with_one_tween() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hop(0.35, 16.0)
	var first: Tween = zombie.get_hop_tween()
	first.custom_step(0.1)
	assert_lt(body.position.y, REST_Y)
	zombie.hop(0.35, 16.0)
	var second: Tween = zombie.get_hop_tween()
	assert_ne(second, first)
	assert_false(first.is_valid(), "the old hop tween was killed")
	assert_true(second.is_valid())
	assert_eq(body.position.y, REST_Y, "restarts from t = 0")
	second.custom_step(0.175)
	assert_almost_eq(body.position.y, REST_Y - 16.0, 0.01, "a full arc from the restart")
	assert_eq(zombie.position, Vector2(100, 192))


func test_stop_hop_mid_hop() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.stop_hop()
	assert_eq(body.position.y, REST_Y, "no-op when not hopping")
	zombie.hop(0.35, 16.0)
	var tween: Tween = zombie.get_hop_tween()
	tween.custom_step(0.1)
	zombie.stop_hop()
	assert_false(zombie.is_hopping())
	assert_false(tween.is_valid())
	assert_eq(body.position.y, REST_Y)
	assert_eq(zombie.position, Vector2(100, 192))


## The hop lifts Body and the slot rides along; the slot's own position follows the hop frame (the
## crouch's head point is 2 px lower than idle's), so compare against Body + that frame's anchor.
func test_hop_carries_the_hat_slot() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var slot: HatSlot = zombie.get_node("%HatSlot") as HatSlot
	var body: AnimatedSprite2D = _body(zombie)
	var rest: float = body.global_position.y
	zombie.hop(0.35, 16.0)
	zombie.get_hop_tween().custom_step(0.175)
	var anchor: Vector2 = slot.anchors.get_head(body.animation, body.frame)
	assert_eq(body.animation, &"hop")
	assert_almost_eq(slot.global_position.y, rest - 16.0 + anchor.y, 0.01)


func test_hop_without_sprite_frames_does_not_crash() -> void:
	var zombie: PlayerZombie = PlayerZombieScene.instantiate() as PlayerZombie
	_body(zombie).sprite_frames = null
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(zombie)
	assert_push_warning("player zombie has no sprite frames")
	zombie.hop(0.35, 16.0)
	assert_true(zombie.is_hopping())
	zombie.get_hop_tween().custom_step(1.0)
	assert_false(zombie.is_hopping())


# --- hug (Story 3.3) --------------------------------------------------------

const REST_X: float = -16.0


func test_hug_lean_and_back() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	assert_false(zombie.is_hugging())
	zombie.hug(0.4)
	assert_true(zombie.is_hugging())
	zombie.get_hug_tween().custom_step(0.2)
	assert_almost_eq(body.position.x, REST_X + PlayerZombie.HUG_LEAN_PX, 0.01, "full lean at half time")
	assert_eq(body.position.y, REST_Y, "the hug never moves y")
	assert_eq(zombie.position, Vector2(100, 192), "the node never moves")
	zombie.get_hug_tween().custom_step(0.25)
	assert_eq(body.position.x, REST_X, "back at rest")
	assert_false(zombie.is_hugging())


func test_second_hug_restarts_with_one_tween() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hug(0.4)
	var first: Tween = zombie.get_hug_tween()
	first.custom_step(0.1)
	assert_gt(body.position.x, REST_X)
	zombie.hug(0.4)
	var second: Tween = zombie.get_hug_tween()
	assert_ne(second, first)
	assert_false(first.is_valid(), "the old hug tween was killed")
	assert_true(second.is_valid())
	var lean: float = body.position.x
	assert_gt(lean, REST_X, "a restart does not snap Body back to rest")
	second.custom_step(0.0)
	assert_almost_eq(body.position.x, lean, 0.01, "it picks up from the current lean")
	second.custom_step(0.1)
	assert_almost_eq(body.position.x, REST_X + PlayerZombie.HUG_LEAN_PX, 0.01, "the lean still peaks")
	second.custom_step(0.5)
	assert_eq(body.position.x, REST_X, "and ends at rest")


func test_stop_hug() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.stop_hug()
	assert_eq(body.position.x, REST_X, "no-op when not hugging")
	zombie.hug(0.4)
	var tween: Tween = zombie.get_hug_tween()
	tween.custom_step(0.1)
	zombie.stop_hug()
	assert_false(zombie.is_hugging())
	assert_false(tween.is_valid())
	assert_eq(body.position.x, REST_X)


func test_hop_and_hug_together() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hop(0.4, 16.0)
	zombie.hug(0.4)
	assert_true(zombie.is_hopping(), "the hug does not kill the hop")
	zombie.get_hop_tween().custom_step(0.1)
	zombie.get_hug_tween().custom_step(0.1)
	var y: float = REST_Y - 16.0 * sin(PI * 0.25)
	var x: float = REST_X + PlayerZombie.HUG_LEAN_PX * sin(PI * 0.25)
	assert_almost_eq(body.position.y, y, 0.01, "y follows the hop arc")
	assert_almost_eq(body.position.x, x, 0.01, "x follows the hug arc")
	zombie.stop_hug()
	assert_true(zombie.is_hopping(), "stop_hug() leaves the hop running")
	assert_almost_eq(body.position.y, y, 0.01, "stop_hug() leaves y alone")
	assert_eq(body.position.x, REST_X)
	zombie.hug(0.4)
	zombie.get_hug_tween().custom_step(0.1)
	zombie.hop(0.4, 16.0)
	assert_true(zombie.is_hugging(), "hop() leaves the hug running")
	assert_almost_eq(body.position.x, x, 0.01, "hop() leaves x alone")
	zombie.stop_hop()
	assert_true(zombie.is_hugging(), "stop_hop() leaves the hug running")
	assert_almost_eq(body.position.x, x, 0.01, "stop_hop() leaves x alone")
	assert_eq(body.position.y, REST_Y)


# --- dance (Story 3.5) ------------------------------------------------------

const DANCE_S: float = 2.0


## A still zombie whose SpriteFrames has no dance animation (the code bounce + flip path).
func _no_dance_zombie() -> PlayerZombie:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	var frames: SpriteFrames = body.sprite_frames.duplicate() as SpriteFrames
	frames.remove_animation(PlayerZombie.ANIM_DANCE)
	body.sprite_frames = frames
	return zombie


func test_dance_bounces_and_flips_then_rests() -> void:
	var zombie: PlayerZombie = _no_dance_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	assert_false(zombie.is_dancing())
	zombie.dance(DANCE_S)
	assert_true(zombie.is_dancing())
	var tween: Tween = zombie.get_dance_tween()
	var lifted: int = 0
	var beat_seconds: float = 1.0 / PlayerZombie.DANCE_BEAT_HZ
	var t: float = 0.0
	var dt: float = 0.05
	while t + dt < DANCE_S - 0.001:
		tween.custom_step(dt)
		t += dt
		var y: float = body.position.y
		assert_true(y >= REST_Y - PlayerZombie.DANCE_HOP_PX and y <= REST_Y, "y %.2f within the bounce" % y)
		assert_eq(y, roundf(y), "whole pixels")
		if y < REST_Y:
			lifted += 1
		# Away from the beat edges, the facing is fixed by the beat number.
		var beat_pos: float = fmod(t, beat_seconds)
		if beat_pos > 0.06 and beat_pos < beat_seconds - 0.06:
			var odd: bool = int(floorf(t / beat_seconds)) % 2 == 1
			assert_eq(body.flip_h, odd, "facing at %.2f s" % t)
	assert_gt(lifted, 0, "the bounce lifts Body")
	assert_eq(zombie.position, Vector2(100, 192), "the node never moves")
	tween.custom_step(DANCE_S + 0.01)
	assert_false(zombie.is_dancing())
	assert_eq(body.position.y, REST_Y, "back at rest")
	assert_false(body.flip_h, "facing right again")


func test_dance_flips_in_the_second_beat_only() -> void:
	var zombie: PlayerZombie = _no_dance_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.dance(DANCE_S)
	var beat_seconds: float = 1.0 / PlayerZombie.DANCE_BEAT_HZ
	zombie.get_dance_tween().custom_step(beat_seconds * 0.5)
	assert_false(body.flip_h, "first beat faces right")
	zombie.get_dance_tween().custom_step(beat_seconds)
	assert_true(body.flip_h, "second beat faces left")


func test_dance_cuts_hop_and_hug() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hop(0.35, 16.0)
	zombie.hug(0.4)
	zombie.get_hop_tween().custom_step(0.1)
	zombie.get_hug_tween().custom_step(0.1)
	zombie.dance(DANCE_S)
	assert_false(zombie.is_hopping(), "the dance cuts the hop")
	assert_false(zombie.is_hugging(), "the dance cuts the hug")
	assert_eq(body.position.x, REST_X, "Body x back at rest")
	assert_eq(body.position.y, REST_Y, "Body y starts the dance at rest")
	assert_true(zombie.is_dancing())


func test_second_dance_restarts_with_one_tween() -> void:
	var zombie: PlayerZombie = _still_zombie()
	zombie.dance(DANCE_S)
	var first: Tween = zombie.get_dance_tween()
	first.custom_step(0.3)
	zombie.dance(DANCE_S)
	var second: Tween = zombie.get_dance_tween()
	assert_ne(second, first)
	assert_false(first.is_valid(), "the old dance tween was killed")
	assert_true(second.is_valid())
	assert_true(zombie.is_dancing())


func test_dance_plays_idle_without_dance_frames() -> void:
	var zombie: PlayerZombie = _no_dance_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	assert_false(body.sprite_frames.has_animation(PlayerZombie.ANIM_DANCE))
	zombie.play_walk()
	zombie.dance(DANCE_S)
	assert_eq(body.animation, PlayerZombie.ANIM_IDLE)
	assert_true(body.is_playing())


## With the real scene frames: the dance sheet plays, the y bounce still runs and Body never flips.
func test_dance_plays_the_real_dance_frames_without_flipping() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.play_walk()
	zombie.dance(DANCE_S)
	assert_eq(body.animation, PlayerZombie.ANIM_DANCE)
	assert_true(body.is_playing())
	assert_eq(body.frame, 0, "from the first frame")
	var tween: Tween = zombie.get_dance_tween()
	var lifted: int = 0
	var t: float = 0.0
	while t < DANCE_S - 0.1:
		tween.custom_step(0.05)
		t += 0.05
		assert_false(body.flip_h, "no flip at %.2f s: the sheet carries the sway" % t)
		if body.position.y < REST_Y:
			lifted += 1
	assert_gt(lifted, 0, "the code bounce still lifts Body")
	tween.custom_step(DANCE_S)
	assert_eq(body.position.y, REST_Y)
	assert_false(body.flip_h)


func test_play_walk_and_idle_do_not_clobber_the_dance() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.dance(DANCE_S)
	zombie.play_walk()
	zombie.play_idle()
	assert_eq(body.animation, PlayerZombie.ANIM_DANCE)
	zombie.get_dance_tween().custom_step(DANCE_S + 0.01)
	zombie.play_idle()
	assert_eq(body.animation, PlayerZombie.ANIM_IDLE, "the next play_idle() takes over after the dance")


# --- one-shot animations (Story 3.6) ----------------------------------------


func test_hop_plays_the_hop_frames_once() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.play_walk()
	body.frame = 2
	zombie.hop(0.35, 16.0)
	assert_eq(body.animation, PlayerZombie.ANIM_HOP)
	assert_eq(body.frame, 0, "from the first frame")
	assert_true(body.is_playing())
	assert_false(body.sprite_frames.get_animation_loop(PlayerZombie.ANIM_HOP), "plays once")


func test_hug_plays_the_hug_frames() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.play_walk()
	zombie.hug(0.4)
	assert_eq(body.animation, PlayerZombie.ANIM_HUG)
	assert_eq(body.frame, 0)
	assert_true(body.is_playing())


## The 3.2 deferral: the level calls play_walk() every frame and again in _scoot_to.
func test_play_walk_and_idle_do_not_clobber_hop_or_hug() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hop(0.35, 16.0)
	zombie.play_walk()
	zombie.play_idle()
	assert_eq(body.animation, PlayerZombie.ANIM_HOP, "mid-hop the zombie is not walking")
	zombie.get_hop_tween().custom_step(0.4)
	assert_false(zombie.is_hopping())
	zombie.play_walk()
	assert_eq(body.animation, PlayerZombie.ANIM_WALK, "the next play_walk() takes over after the hop")
	zombie.hug(0.4)
	zombie.play_walk()
	zombie.play_idle()
	assert_eq(body.animation, PlayerZombie.ANIM_HUG)
	zombie.get_hug_tween().custom_step(0.5)
	zombie.play_idle()
	assert_eq(body.animation, PlayerZombie.ANIM_IDLE, "the next play_idle() takes over after the hug")


func test_hug_during_a_hop_shows_the_hop_until_it_ends() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hop(0.35, 16.0)
	zombie.get_hop_tween().custom_step(0.1)
	zombie.hug(0.6)
	assert_eq(body.animation, PlayerZombie.ANIM_HOP, "the hop's frames win while it runs")
	zombie.get_hop_tween().custom_step(0.3)
	assert_false(zombie.is_hopping())
	assert_true(zombie.is_hugging())
	assert_eq(body.animation, PlayerZombie.ANIM_HUG, "then the hug's frames")


## A block key cuts the hug and hops: the hop's frames take over at once.
func test_hop_cuts_into_a_hug() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hug(0.4)
	zombie.stop_hug()
	assert_eq(body.animation, PlayerZombie.ANIM_HUG, "stop_hug() does not change the animation")
	zombie.hop(0.35, 16.0)
	assert_eq(body.animation, PlayerZombie.ANIM_HOP)


## Review patch: a hop cut while a hug is still leaning hands the hug its frames, as when the hop ends itself.
func test_stop_hop_during_a_hug_starts_the_hug_frames() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hug(0.4)
	zombie.hop(0.35, 16.0)
	assert_eq(body.animation, PlayerZombie.ANIM_HOP)
	zombie.stop_hop()
	assert_eq(body.animation, PlayerZombie.ANIM_HUG, "the hug frames take over when the hop is cut")


## Review patch: when the dance ends the loop gives way to idle instead of dancing in place.
func test_dance_end_returns_to_idle() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.dance(DANCE_S)
	assert_eq(body.animation, PlayerZombie.ANIM_DANCE)
	zombie.get_dance_tween().custom_step(DANCE_S + 0.01)
	assert_false(zombie.is_dancing())
	assert_eq(body.animation, PlayerZombie.ANIM_IDLE, "no dancing in place after the dance")


func test_stop_hop_releases_the_guard_at_once() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	zombie.hop(0.35, 16.0)
	zombie.stop_hop()
	assert_eq(body.animation, PlayerZombie.ANIM_HOP, "stop_hop() does not change the animation")
	zombie.play_walk()
	assert_eq(body.animation, PlayerZombie.ANIM_WALK)


func test_hug_and_play_without_sprite_frames_do_not_crash() -> void:
	var zombie: PlayerZombie = PlayerZombieScene.instantiate() as PlayerZombie
	_body(zombie).sprite_frames = null
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(zombie)
	assert_push_warning("player zombie has no sprite frames")
	zombie.hug(0.4)
	zombie.hop(0.35, 16.0)
	zombie.play_walk()
	zombie.get_hop_tween().custom_step(1.0)
	zombie.get_hug_tween().custom_step(1.0)
	zombie.play_idle()
	assert_false(zombie.is_hugging())


func test_dance_without_sprite_frames_does_not_crash() -> void:
	var zombie: PlayerZombie = PlayerZombieScene.instantiate() as PlayerZombie
	_body(zombie).sprite_frames = null
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(zombie)
	assert_push_warning("player zombie has no sprite frames")
	zombie.dance(DANCE_S)
	assert_true(zombie.is_dancing())
	zombie.get_dance_tween().custom_step(DANCE_S + 1.0)
	assert_false(zombie.is_dancing())
