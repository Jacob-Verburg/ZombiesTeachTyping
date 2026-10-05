extends GutTest
## Party-hat zombie (Story 3.3): the hugged villager's replacement, an idle loop from the prototype sheet
## drawn at 1x with the origin at the feet centre. Story 3.4 makes it walk in the conga line.

const PartyZombieScene: PackedScene = preload("res://scenes/characters/party_zombie.tscn")
const SHEET_PATH: String = "res://assets/sprites/characters/party_zombie/party_zombie_idle.png"


func _party_zombie() -> PartyZombie:
	var zombie: PartyZombie = PartyZombieScene.instantiate() as PartyZombie
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(zombie)
	return zombie


func _body(zombie: PartyZombie) -> AnimatedSprite2D:
	return zombie.get_node("Body") as AnimatedSprite2D


func test_idle_from_the_party_zombie_sheet() -> void:
	var frames: SpriteFrames = _body(_party_zombie()).sprite_frames
	assert_not_null(frames)
	assert_true(frames.has_animation(&"idle"))
	assert_eq(frames.get_frame_count(&"idle"), 2)
	assert_eq(frames.get_animation_speed(&"idle"), 8.0)
	assert_true(frames.get_animation_loop(&"idle"))
	var sheet: Texture2D = load(SHEET_PATH) as Texture2D
	for i: int in 2:
		var atlas: AtlasTexture = frames.get_frame_texture(&"idle", i) as AtlasTexture
		assert_not_null(atlas)
		assert_eq(atlas.atlas, sheet)
		assert_eq(atlas.region, Rect2(i * 32, 0, 32, 32))


func test_origin_is_the_feet_centre() -> void:
	var body: AnimatedSprite2D = _body(_party_zombie())
	assert_false(body.centered)
	assert_eq(body.position, Vector2(-16, -31), "soles (sheet row 30) end on the node's y = 0")


func test_play_idle() -> void:
	var zombie: PartyZombie = _party_zombie()
	var body: AnimatedSprite2D = _body(zombie)
	body.stop()
	zombie.play_idle()
	assert_eq(body.animation, &"idle")
	assert_true(body.is_playing())


func test_missing_sprite_frames_hides_with_a_warning() -> void:
	var zombie: PartyZombie = PartyZombieScene.instantiate() as PartyZombie
	_body(zombie).sprite_frames = null
	add_child_autofree(zombie)
	assert_push_warning("party zombie has no sprite frames")
	assert_false(_body(zombie).visible)
	zombie.play_idle()
	pass_test("play_idle without frames does not crash")
