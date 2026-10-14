extends GutTest
## The defender sprite (Story 6.6, the Farmer; Story 10.3 HordeDefenderSprite, also the Knight and the Lifeguard):
## idle/walk/throw SpriteFrames from each defender's sheets, the pair each scene brings, the play API (loops restart
## only on change, the throw is a one-shot that holds off the loops and then returns to the last wanted
## loop), and a stripped SpriteFrames never crashes (NFR16). The sprite never advances by itself here, so
## the throw's end is emitted by hand.

const FarmerScene: PackedScene = preload("res://scenes/levels/horde_rush/farmer.tscn")


func _farmer() -> HordeDefenderSprite:
	var farmer: HordeDefenderSprite = FarmerScene.instantiate() as HordeDefenderSprite
	farmer.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(farmer)
	return farmer


## Story 10.3: every defender scene (the Farmer, the Knight, the Lifeguard) -> its sheet folder and prefix, and
## the pair it brings: projectile scene, hit scene, throw and hit sound ids.
const DEFENDERS: Dictionary[String, Array] = {
	"res://scenes/levels/horde_rush/farmer.tscn": ["farmer", "res://scenes/levels/horde_rush/tomato.tscn",
			"res://scenes/levels/horde_rush/tomato_splat.tscn", &"sfx_tomato_throw", &"sfx_tomato_hit"],
	"res://scenes/levels/horde_rush/knight.tscn": ["knight", "res://scenes/levels/horde_rush/dart.tscn",
			"res://scenes/levels/horde_rush/dart_hit.tscn", &"sfx_dart_throw", &"sfx_dart_hit"],
	"res://scenes/levels/horde_rush/lifeguard.tscn": ["lifeguard", "res://scenes/levels/horde_rush/water_balloon.tscn",
			"res://scenes/levels/horde_rush/water_balloon_splash.tscn", &"sfx_balloon_throw", &"sfx_balloon_hit"],
}
const AUDIO_LIBRARY_PATH: String = "res://data/audio/audio_library.tres"


func test_animations_frames_and_fps() -> void:
	for path: String in DEFENDERS:
		var defender: HordeDefenderSprite = (load(path) as PackedScene).instantiate() as HordeDefenderSprite
		assert_not_null(defender, "%s root is a HordeDefenderSprite" % path)
		if defender == null:
			continue
		defender.process_mode = Node.PROCESS_MODE_DISABLED
		add_child_autofree(defender)
		var prefix: String = DEFENDERS[path][0]
		var body: AnimatedSprite2D = defender.get_body()
		assert_eq(body.position, Vector2(-16, -31), "%s origin at the feet" % prefix)
		assert_false(body.centered)
		assert_eq(body.autoplay, "idle", "%s autoplays idle" % prefix)
		var frames: SpriteFrames = body.sprite_frames
		assert_not_null(frames)
		for spec: Array in [[HordeDefenderSprite.ANIM_IDLE, 2, 8.0, true], [HordeDefenderSprite.ANIM_WALK, 4, 10.0, true],
				[HordeDefenderSprite.ANIM_THROW, 3, 12.0, false]]:
			var anim: StringName = spec[0]
			assert_true(frames.has_animation(anim), "%s %s" % [prefix, anim])
			assert_eq(frames.get_frame_count(anim), spec[1], "%s %s frames" % [prefix, anim])
			assert_eq(frames.get_animation_speed(anim), spec[2], "%s %s fps" % [prefix, anim])
			assert_eq(frames.get_animation_loop(anim), spec[3], "%s %s loop" % [prefix, anim])
			for i: int in frames.get_frame_count(anim):
				var atlas: AtlasTexture = frames.get_frame_texture(anim, i) as AtlasTexture
				assert_eq(atlas.region, Rect2(i * 32, 0, 32, 32))
				assert_eq(atlas.atlas.resource_path,
						"res://assets/sprites/characters/%s/%s_%s.png" % [prefix, prefix, anim])


## Story 10.3: each defender scene brings its whole pair: both scenes set and real, both sounds in the library.
func test_every_defender_brings_its_pair() -> void:
	var library: AudioLibrary = load(AUDIO_LIBRARY_PATH) as AudioLibrary
	for path: String in DEFENDERS:
		var defender: HordeDefenderSprite = (load(path) as PackedScene).instantiate() as HordeDefenderSprite
		var spec: Array = DEFENDERS[path]
		assert_not_null(defender.projectile_scene, "%s projectile" % spec[0])
		assert_not_null(defender.hit_scene, "%s hit" % spec[0])
		if defender.projectile_scene != null and defender.hit_scene != null:
			assert_eq(defender.projectile_scene.resource_path, spec[1], "%s projectile scene" % spec[0])
			assert_eq(defender.hit_scene.resource_path, spec[2], "%s hit scene" % spec[0])
			var hit: Node = defender.hit_scene.instantiate()
			assert_true(hit is HordeHitEffect, "%s hit effect script" % spec[0])
			assert_eq((hit.get_node("%Sprite") as AnimatedSprite2D).sprite_frames.get_frame_count(&"splat"),
					HordeHitEffect.FRAMES, "%s hit frames" % spec[0])
			hit.free()
			var fly: Node = defender.projectile_scene.instantiate()
			var sprite: AnimatedSprite2D = fly.get_node("%Sprite") as AnimatedSprite2D
			assert_true(sprite.centered and sprite.autoplay == "fly", "%s projectile sprite" % spec[0])
			assert_eq(sprite.sprite_frames.get_frame_count(&"fly"), 2, "%s projectile frames" % spec[0])
			fly.free()
		assert_eq(defender.throw_sfx, spec[3], "%s throw sound" % spec[0])
		assert_eq(defender.hit_sfx, spec[4], "%s hit sound" % spec[0])
		assert_not_null(library.get_cue(defender.throw_sfx), "%s in the audio library" % defender.throw_sfx)
		assert_not_null(library.get_cue(defender.hit_sfx), "%s in the audio library" % defender.hit_sfx)
		defender.free()


func test_origin_is_the_feet_centre() -> void:
	var body: AnimatedSprite2D = _farmer().get_body()
	assert_eq(body.position, Vector2(-16, -31))
	assert_false(body.centered)
	assert_eq(body.animation, HordeDefenderSprite.ANIM_IDLE, "idle by default")


func test_loops_restart_only_on_change() -> void:
	var farmer: HordeDefenderSprite = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_walk()
	assert_eq(body.animation, HordeDefenderSprite.ANIM_WALK)
	body.frame = 2
	farmer.play_walk()
	assert_eq(body.frame, 2, "the same loop is not restarted")
	farmer.play_idle()
	assert_eq(body.animation, HordeDefenderSprite.ANIM_IDLE)


func test_the_throw_blocks_the_loops_until_it_ends() -> void:
	var farmer: HordeDefenderSprite = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_walk()
	body.frame = 3
	farmer.play_throw()
	assert_true(farmer.is_throwing())
	assert_eq(body.animation, HordeDefenderSprite.ANIM_THROW)
	assert_eq(body.frame, 0, "from its first frame")
	farmer.play_walk()
	farmer.play_idle()
	assert_eq(body.animation, HordeDefenderSprite.ANIM_THROW, "the loops wait")
	body.animation_finished.emit()
	assert_false(farmer.is_throwing())
	assert_eq(body.animation, HordeDefenderSprite.ANIM_IDLE, "the last wanted loop takes over")
	farmer.play_walk()
	assert_eq(body.animation, HordeDefenderSprite.ANIM_WALK)


func test_a_new_throw_restarts_it() -> void:
	var farmer: HordeDefenderSprite = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_throw()
	body.frame = 2
	farmer.play_throw()
	assert_eq(body.frame, 0)
	assert_true(farmer.is_throwing())


func test_a_loop_ending_never_ends_the_throw_state() -> void:
	var farmer: HordeDefenderSprite = _farmer()
	var body: AnimatedSprite2D = farmer.get_body()
	farmer.play_walk()
	body.animation_finished.emit()
	assert_false(farmer.is_throwing())
	assert_eq(body.animation, HordeDefenderSprite.ANIM_WALK)


func test_no_sprite_frames_does_not_crash() -> void:
	var farmer: HordeDefenderSprite = FarmerScene.instantiate() as HordeDefenderSprite
	(farmer.get_node("Body") as AnimatedSprite2D).sprite_frames = null
	add_child_autofree(farmer)
	farmer.play_idle()
	farmer.play_walk()
	farmer.play_throw()
	assert_false(farmer.is_throwing())
	assert_false(farmer.get_body().visible, "hidden")


func test_a_missing_throw_keeps_walking() -> void:
	var farmer: HordeDefenderSprite = FarmerScene.instantiate() as HordeDefenderSprite
	var body: AnimatedSprite2D = farmer.get_node("Body") as AnimatedSprite2D
	var frames: SpriteFrames = body.sprite_frames.duplicate() as SpriteFrames
	frames.remove_animation(HordeDefenderSprite.ANIM_THROW)
	body.sprite_frames = frames
	add_child_autofree(farmer)
	farmer.play_walk()
	farmer.play_throw()
	farmer.play_throw()
	assert_false(farmer.is_throwing())
	assert_eq(body.animation, HordeDefenderSprite.ANIM_WALK)
