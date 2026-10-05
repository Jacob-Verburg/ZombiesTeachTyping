extends GutTest
## Poof (Story 3.3): the code-drawn 4-frame dust cloud a hugged villager turns into. Tween-driven, so it
## advances with custom_step even on a disabled node; emits finished once and frees itself.

const PoofScene: PackedScene = preload("res://scenes/levels/zombie_run/poof.tscn")
const PALETTE_PATH: String = "res://assets/palette/palette_32.png"


func _poof() -> Poof:
	var poof: Poof = PoofScene.instantiate() as Poof
	poof.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(poof)
	return poof


func test_four_frames_at_twelve_fps() -> void:
	assert_eq(Poof.FRAMES, 4)
	assert_eq(Poof.FPS, 12.0)
	var poof: Poof = _poof()
	assert_eq(poof.get_frame(), 0)
	var step: float = 1.0 / Poof.FPS
	poof.get_tween().custom_step(step * 0.5)
	assert_eq(poof.get_frame(), 0, "half a frame in")
	for frame: int in range(1, Poof.FRAMES):
		poof.get_tween().custom_step(step)
		assert_eq(poof.get_frame(), frame, "frame %d after %d frame times" % [frame, frame])


func test_finished_once_then_frees_itself() -> void:
	var poof: Poof = _poof()
	watch_signals(poof)
	poof.get_tween().custom_step((Poof.FRAMES - 0.5) / Poof.FPS)
	assert_signal_not_emitted(poof, "finished", "still on the last frame")
	assert_false(poof.is_queued_for_deletion())
	poof.get_tween().custom_step(1.0 / Poof.FPS)
	assert_signal_emit_count(poof, "finished", 1)
	assert_eq(poof.get_frame(), Poof.FRAMES - 1, "never past the last frame")
	assert_true(poof.is_queued_for_deletion(), "self-freeing one-shot")
	poof.get_tween().custom_step(1.0)
	assert_signal_emit_count(poof, "finished", 1, "only once")


func test_every_frame_draws_something_within_the_tag_width() -> void:
	for frame: int in Poof.FRAMES:
		var puffs: Array[Vector3i] = Poof.puffs(frame)
		assert_gt(puffs.size(), 0, "frame %d has puffs" % frame)
		for puff: Vector3i in puffs:
			# The ink ring is radius + 1.
			assert_true(absi(puff.x) + puff.z + 1 <= ZombieRunTarget.HALF_WIDTH,
					"frame %d puff %s inside 24 px" % [frame, puff])
	assert_ne(Poof.puffs(0), Poof.puffs(1), "frames differ")
	assert_ne(Poof.puffs(2), Poof.puffs(3), "frames differ")


func test_palette_colours_only() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PALETTE_PATH))
	var palette: Dictionary[String, bool] = {}
	for x: int in image.get_width():
		palette[image.get_pixel(x, 0).to_html(false)] = true
	for color: Color in [Poof.INK, Poof.FILL, Poof.SHADE]:
		assert_true(palette.has(color.to_html(false)), "%s is a palette colour" % color.to_html(false))
