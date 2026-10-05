extends GutTest
## Art review scene (Story 1.9): SpriteFrames built from the sheets, fps and frame counts inside the
## style-sheet limits, and the B background cycle using palette colors only. The scene owns input,
## so instances are disabled; the cycle is driven through the _cycle_background() seam.

const ReviewScene: PackedScene = preload("res://scenes/debug/art_review.tscn")
const ArtReviewScript := preload("res://scripts/debug/art_review.gd")
const PALETTE_PATH: String = "res://assets/palette/palette_32.png"
const WALK_PATH: String = "res://assets/sprites/characters/zombie/zombie_walk.png"

var _palette: Dictionary[String, bool] = {}


func before_all() -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(PALETTE_PATH))
	if image == null:
		return
	for x: int in image.get_width():
		_palette[image.get_pixel(x, 0).to_html(false)] = true


func _make() -> ArtReviewScript:
	var sut: ArtReviewScript = ReviewScene.instantiate() as ArtReviewScript
	sut.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(sut)
	return sut


func test_build_frames_slices_walk_sheet() -> void:
	var sheet: Texture2D = load(WALK_PATH) as Texture2D
	assert_not_null(sheet)
	var frames: SpriteFrames = ArtReviewScript.build_frames(sheet, 4, 10.0)
	assert_eq(frames.get_animation_names().size(), 1)
	var anim: StringName = frames.get_animation_names()[0]
	assert_eq(frames.get_frame_count(anim), 4)
	assert_eq(frames.get_animation_speed(anim), 10.0)
	assert_true(frames.get_animation_loop(anim))
	for i: int in 4:
		var atlas: AtlasTexture = frames.get_frame_texture(anim, i) as AtlasTexture
		assert_not_null(atlas)
		assert_eq(atlas.region, Rect2(i * 32, 0, 32, 32))
		assert_eq(atlas.atlas, sheet)


func test_scene_builds_animations_within_limits() -> void:
	var sut: ArtReviewScript = _make()
	var animations: Dictionary[String, SpriteFrames] = sut.get_animations()
	assert_eq_deep(animations.keys(), ["idle", "walk", "wave", "party_idle"])
	for spec: Dictionary in ArtReviewScript.ANIMATIONS:
		var first: AtlasTexture = animations[spec["name"]].get_frame_texture(spec["name"], 0) as AtlasTexture
		assert_not_null(first.atlas, "%s sheet texture loaded" % spec["name"])
	for anim_name: String in animations:
		var frames: SpriteFrames = animations[anim_name]
		assert_true(frames.has_animation(anim_name), anim_name)
		assert_between(frames.get_animation_speed(anim_name), 8.0, 12.0, "%s fps" % anim_name)
		assert_between(frames.get_frame_count(anim_name), 2, 6, "%s frames" % anim_name)
		for i: int in frames.get_frame_count(anim_name):
			# No per-frame multipliers hiding a sub-8 fps animation.
			assert_eq(frames.get_frame_duration(anim_name, i), 1.0, "%s frame %d duration" % [anim_name, i])


func test_background_cycle_uses_palette_and_wraps() -> void:
	var sut: ArtReviewScript = _make()
	var count: int = ArtReviewScript.BACKGROUNDS.size()
	assert_eq(count, 5)
	var first: String = sut.background_name()
	var seen: Array[String] = []
	for i: int in count:
		seen.append(sut.background_name())
		assert_true(_palette.has(sut.background_color().to_html(false)),
				"%s not a palette color" % sut.background_name())
		sut._cycle_background()
	assert_eq(sut.background_name(), first, "cycle wraps")
	assert_eq_deep(seen, ["night", "parchment", "art-sky", "chalkboard", "art-grass"])


func test_every_background_is_a_palette_color() -> void:
	for entry: Array in ArtReviewScript.BACKGROUNDS:
		var color: Color = entry[1]
		assert_true(_palette.has(color.to_html(false)), "%s %s" % [entry[0], color.to_html(false)])


func test_palette_strip_shows_all_32_colors() -> void:
	var sut: ArtReviewScript = _make()
	var swatches: Array[Color] = sut.swatch_colors()
	assert_eq(swatches.size(), 32)
	for color: Color in swatches:
		assert_true(_palette.has(color.to_html(false)))
