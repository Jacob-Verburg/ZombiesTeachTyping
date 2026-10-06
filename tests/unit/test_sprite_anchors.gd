extends GutTest
## SpriteAnchors (Story 4.3, architecture D6): lookups and validate() on code-built resources, the shipped
## anchor sets against the characters' SpriteFrames, and the art match: every head point is re-measured
## from the committed PNG (top row with an opaque pixel, centre of that row's opaque run), so a redrawn
## sheet fails here until tools/gen_sprite_anchors.gd is rerun.

const ZOMBIE_ANCHORS_PATH: String = "res://data/anchors/zombie_anchors.tres"
const PROFESSOR_ANCHORS_PATH: String = "res://data/anchors/professor_anchors.tres"
const PlayerZombieScene: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
const ProfessorScene: PackedScene = preload("res://scenes/characters/professor_zombie.tscn")
const FRAME: int = 32
const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie/"
const PROFESSOR_DIR: String = "res://assets/sprites/characters/professor/"
## Anchor set -> animation -> the sheet it was measured from.
const SHEETS: Dictionary[String, Dictionary] = {
	ZOMBIE_ANCHORS_PATH: {
		&"idle": ZOMBIE_DIR + "zombie_idle.png",
		&"walk": ZOMBIE_DIR + "zombie_walk.png",
		&"hop": ZOMBIE_DIR + "zombie_hop.png",
		&"hug": ZOMBIE_DIR + "zombie_hug.png",
		&"dance": ZOMBIE_DIR + "zombie_dance.png",
	},
	PROFESSOR_ANCHORS_PATH: {
		&"point": PROFESSOR_DIR + "professor_point.png",
	},
}


func _anchors(head: Dictionary[StringName, PackedVector2Array]) -> SpriteAnchors:
	var anchors: SpriteAnchors = SpriteAnchors.new()
	anchors.head = head
	return anchors


func _frames(counts: Dictionary) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: StringName in counts:
		frames.add_animation(anim)
		for i: int in counts[anim]:
			frames.add_frame(anim, PlaceholderTexture2D.new())
	return frames


func _scene_frames(scene: PackedScene) -> SpriteFrames:
	var node: Node = scene.instantiate()
	var frames: SpriteFrames = (node.get_node("Body") as AnimatedSprite2D).sprite_frames
	node.free()
	return frames


func test_neutral_default_is_empty() -> void:
	var anchors: SpriteAnchors = SpriteAnchors.new()
	assert_eq(anchors.head.size(), 0)
	assert_false(anchors.has_head(&"idle", 0))


func test_get_head_and_has_head() -> void:
	var anchors: SpriteAnchors = _anchors({&"idle": PackedVector2Array([Vector2(16, 1), Vector2(16, 2)])})
	assert_true(anchors.has_head(&"idle", 0))
	assert_true(anchors.has_head(&"idle", 1))
	assert_eq(anchors.get_head(&"idle", 1), Vector2(16, 2))
	assert_false(anchors.has_head(&"walk", 0), "missing animation")
	assert_eq(anchors.get_head(&"walk", 0), Vector2.ZERO)
	assert_false(anchors.has_head(&"idle", 2), "frame out of range")
	assert_false(anchors.has_head(&"idle", -1), "negative frame")
	assert_eq(anchors.get_head(&"idle", 2), Vector2.ZERO)


func test_validate_passes_on_a_match() -> void:
	var anchors: SpriteAnchors = _anchors({
		&"idle": PackedVector2Array([Vector2(16, 1), Vector2(16, 2)]),
		&"hop": PackedVector2Array([Vector2(16, 3)]),
	})
	assert_eq(anchors.validate(_frames({&"idle": 2, &"hop": 1})), "")


func test_validate_catches_a_missing_animation() -> void:
	var anchors: SpriteAnchors = _anchors({&"idle": PackedVector2Array([Vector2(16, 1), Vector2(16, 2)])})
	assert_string_contains(anchors.validate(_frames({&"idle": 2, &"hop": 1})), "hop")


func test_validate_catches_a_wrong_count() -> void:
	var anchors: SpriteAnchors = _anchors({&"idle": PackedVector2Array([Vector2(16, 1)])})
	assert_string_contains(anchors.validate(_frames({&"idle": 2})), "1 anchors, want 2")


func test_validate_catches_an_extra_animation() -> void:
	var anchors: SpriteAnchors = _anchors({
		&"idle": PackedVector2Array([Vector2(16, 1)]),
		&"wave": PackedVector2Array([Vector2(16, 1)]),
	})
	assert_string_contains(anchors.validate(_frames({&"idle": 1})), "wave")


func test_validate_null_frames() -> void:
	assert_ne(SpriteAnchors.new().validate(null), "")


func test_shipped_sets_match_their_sprite_frames() -> void:
	var zombie: SpriteAnchors = load(ZOMBIE_ANCHORS_PATH) as SpriteAnchors
	var professor: SpriteAnchors = load(PROFESSOR_ANCHORS_PATH) as SpriteAnchors
	assert_not_null(zombie)
	assert_not_null(professor)
	if zombie == null or professor == null:
		return
	assert_eq(zombie.validate(_scene_frames(PlayerZombieScene)), "")
	assert_eq(professor.validate(_scene_frames(ProfessorScene)), "")


## The story's measured table, written out: a guard against a silent regeneration.
func test_shipped_values() -> void:
	var zombie: SpriteAnchors = load(ZOMBIE_ANCHORS_PATH) as SpriteAnchors
	assert_eq(zombie.head[&"idle"], PackedVector2Array([Vector2(16, 1), Vector2(16, 2)]))
	assert_eq(zombie.head[&"hop"][0], Vector2(16, 3), "the hop crouch drops the crown")
	assert_eq(zombie.head[&"hug"][1], Vector2(17, 1), "the hug squeeze leans 1 px right")
	var professor: SpriteAnchors = load(PROFESSOR_ANCHORS_PATH) as SpriteAnchors
	assert_eq(professor.head[&"point"], PackedVector2Array([Vector2(16, 5), Vector2(16, 5)]))


func test_every_anchor_matches_the_art() -> void:
	for path: String in SHEETS:
		var anchors: SpriteAnchors = load(path) as SpriteAnchors
		assert_not_null(anchors, path)
		if anchors == null:
			continue
		var sheets: Dictionary = SHEETS[path]
		assert_eq(anchors.head.size(), sheets.size(), "%s animations" % path.get_file())
		for anim: StringName in sheets:
			var image: Image = Image.load_from_file(ProjectSettings.globalize_path(sheets[anim]))
			assert_not_null(image, sheets[anim])
			if image == null:
				continue
			@warning_ignore("integer_division")
			var count: int = image.get_width() / FRAME
			assert_true(anchors.has_head(anim, count - 1), "%s %s covers %d frames" % [path.get_file(), anim, count])
			for frame: int in count:
				assert_eq(anchors.get_head(anim, frame), _measure(image, frame),
						"%s %s frame %d" % [path.get_file(), anim, frame])


## Top row with an opaque pixel; x = (min + max + 1) / 2 of that row's opaque pixels.
func _measure(image: Image, frame: int) -> Vector2:
	for y: int in FRAME:
		var left: int = FRAME
		var right: int = -1
		for x: int in FRAME:
			if image.get_pixel(frame * FRAME + x, y).a8 == 255:
				left = mini(left, x)
				right = maxi(right, x)
		if right >= 0:
			@warning_ignore("integer_division")
			return Vector2((left + right + 1) / 2, y)
	return Vector2(-1, -1)
