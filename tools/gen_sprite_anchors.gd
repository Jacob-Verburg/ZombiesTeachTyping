extends SceneTree
## Dev-only: writes data/anchors/zombie_anchors.tres and professor_anchors.tres (Story 4.3) by measuring
## the committed sheets. Rule (the same as tests/unit/test_sprite_anchors.gd): in each 32x32 frame, y = the
## first row with an opaque pixel, x = (min opaque x + max opaque x + 1) / 2 on that row.
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_sprite_anchors.gd
## Rerun it whenever a character sheet is redrawn; the test fails until you do.

const SpriteAnchorsScript := preload("res://scripts/resources/sprite_anchors.gd")
const FRAME: int = 32
const ZOMBIE_DIR: String = "res://assets/sprites/characters/zombie/"
const PROFESSOR_DIR: String = "res://assets/sprites/characters/professor/"
## Output path -> animation -> sheet.
const SETS: Dictionary[String, Dictionary] = {
	"res://data/anchors/zombie_anchors.tres": {
		&"idle": ZOMBIE_DIR + "zombie_idle.png",
		&"walk": ZOMBIE_DIR + "zombie_walk.png",
		&"hop": ZOMBIE_DIR + "zombie_hop.png",
		&"hug": ZOMBIE_DIR + "zombie_hug.png",
		&"dance": ZOMBIE_DIR + "zombie_dance.png",
	},
	"res://data/anchors/professor_anchors.tres": {
		&"point": PROFESSOR_DIR + "professor_point.png",
	},
}


func _init() -> void:
	var errors: Array[Error] = []
	errors.append(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/anchors")))
	for out_path: String in SETS:
		var anchors: Resource = SpriteAnchorsScript.new()
		var sheets: Dictionary = SETS[out_path]
		var head: Dictionary[StringName, PackedVector2Array] = {}
		for anim: StringName in sheets:
			var points: PackedVector2Array = _measure(sheets[anim])
			if points.is_empty():
				errors.append(ERR_INVALID_DATA)
			head[anim] = points
			print("%s %s %s" % [out_path.get_file(), anim, points])
		anchors.set(&"head", head)
		var err: Error = ResourceSaver.save(anchors, out_path)
		print("%s -> %s" % [out_path, error_string(err)])
		errors.append(err)
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## One head point per frame of the sheet at `path`; empty on a missing sheet or an empty frame.
func _measure(path: String) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		push_error("cannot load %s" % path)
		return points
	@warning_ignore("integer_division")
	var frames: int = image.get_width() / FRAME
	for frame: int in frames:
		var found: bool = false
		for y: int in FRAME:
			var left: int = FRAME
			var right: int = -1
			for x: int in FRAME:
				if image.get_pixel(frame * FRAME + x, y).a8 == 255:
					left = mini(left, x)
					right = maxi(right, x)
			if right >= 0:
				@warning_ignore("integer_division")
				points.append(Vector2((left + right + 1) / 2, y))
				found = true
				break
		if not found:
			push_error("%s frame %d is empty" % [path, frame])
			return PackedVector2Array()
	return points
