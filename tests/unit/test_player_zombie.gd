extends GutTest
## Player zombie (Story 3.1): idle and walk animations from the approved prototype sheets.

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
