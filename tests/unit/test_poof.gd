extends GutTest
## Poof (Story 3.3): the 4-frame dust cloud a hugged villager turns into. Tween-driven, so it advances
## with custom_step even on a disabled node; emits finished once and frees itself.
## Story 3.6: the frames come from villager_poof.png (drawn from the feet, never wider than the tag).

const PoofScene: PackedScene = preload("res://scenes/levels/zombie_run/poof.tscn")
const SHEET_PATH: String = "res://assets/sprites/characters/villager/villager_poof.png"
const FRAME: int = 32


func _poof() -> Poof:
	var poof: Poof = PoofScene.instantiate() as Poof
	poof.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(poof)
	return poof


func _sprite(poof: Poof) -> AnimatedSprite2D:
	return poof.get_node("%Sprite") as AnimatedSprite2D


func test_four_frames_at_twelve_fps() -> void:
	assert_eq(Poof.FRAMES, 4)
	assert_eq(Poof.FPS, 12.0)
	var poof: Poof = _poof()
	var sprite: AnimatedSprite2D = _sprite(poof)
	assert_eq(poof.get_frame(), 0)
	assert_eq(sprite.frame, 0)
	var step: float = 1.0 / Poof.FPS
	poof.get_tween().custom_step(step * 0.5)
	assert_eq(poof.get_frame(), 0, "half a frame in")
	for frame: int in range(1, Poof.FRAMES):
		poof.get_tween().custom_step(step)
		assert_eq(poof.get_frame(), frame, "frame %d after %d frame times" % [frame, frame])
		assert_eq(sprite.frame, frame, "the sprite shows frame %d" % frame)


func test_finished_once_then_frees_itself() -> void:
	var poof: Poof = _poof()
	watch_signals(poof)
	poof.get_tween().custom_step((Poof.FRAMES - 0.5) / Poof.FPS)
	assert_signal_not_emitted(poof, "finished", "still on the last frame")
	assert_false(poof.is_queued_for_deletion())
	poof.get_tween().custom_step(1.0 / Poof.FPS)
	assert_signal_emit_count(poof, "finished", 1)
	assert_eq(poof.get_frame(), Poof.FRAMES - 1, "never past the last frame")
	assert_eq(_sprite(poof).frame, Poof.FRAMES - 1)
	assert_true(poof.is_queued_for_deletion(), "self-freeing one-shot")
	poof.get_tween().custom_step(1.0)
	assert_signal_emit_count(poof, "finished", 1, "only once")


## The sheet and the code agree: FRAMES frames of 32 x 32, and the tween never asks for more.
func test_sprite_frames_match_the_sheet() -> void:
	var sprite: AnimatedSprite2D = _sprite(_poof())
	assert_false(sprite.centered)
	assert_eq(sprite.position, Vector2(-16, -31), "drawn from the feet like every character")
	assert_eq(sprite.sprite_frames.get_frame_count(sprite.animation), Poof.FRAMES)
	assert_false(sprite.is_playing(), "the tween steps the frames, the sprite never plays on its own")
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	assert_not_null(image)
	if image != null:
		assert_eq(image.get_size(), Vector2i(Poof.FRAMES * FRAME, FRAME))


## Read the PNG: every frame has pixels and is at most the 24 px tag wide.
func test_every_frame_draws_something_within_the_tag_width() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	assert_not_null(image)
	if image == null:
		return
	for frame: int in Poof.FRAMES:
		var left: int = FRAME
		var right: int = -1
		for y: int in FRAME:
			for x: int in FRAME:
				if image.get_pixel(frame * FRAME + x, y).a8 == 255:
					left = mini(left, x)
					right = maxi(right, x)
		assert_gt(right, -1, "frame %d has pixels" % frame)
		assert_true(right - left + 1 <= 2 * ZombieRunTarget.HALF_WIDTH, "frame %d inside 24 px" % frame)


func test_missing_sprite_frames_still_finishes() -> void:
	var poof: Poof = PoofScene.instantiate() as Poof
	(poof.get_node("%Sprite") as AnimatedSprite2D).sprite_frames = null
	poof.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(poof)
	assert_push_warning("poof has no sprite frames")
	watch_signals(poof)
	poof.get_tween().custom_step(1.0)
	assert_signal_emit_count(poof, "finished", 1, "the party zombie still appears (NFR16)")
