extends GutTest
## Player zombie (Story 3.1): idle and walk animations from the approved prototype sheets.
## Hop (Story 3.2): a sine arc on Body, one hop tween at a time, never the node's own position.

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


func test_hat_slot_exists() -> void:
	var zombie: PlayerZombie = _zombie()
	var slot: Node = zombie.get_node("%HatSlot")
	assert_true(slot is Node2D)
	assert_eq(slot.get_child_count(), 0, "empty until Story 4.3")


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


func test_hop_carries_the_hat_slot() -> void:
	var zombie: PlayerZombie = _still_zombie()
	var slot: Node2D = zombie.get_node("%HatSlot") as Node2D
	var rest: float = slot.global_position.y
	zombie.hop(0.35, 16.0)
	zombie.get_hop_tween().custom_step(0.175)
	assert_almost_eq(slot.global_position.y, rest - 16.0, 0.01)


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
