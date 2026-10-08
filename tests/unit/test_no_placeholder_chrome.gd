extends GutTest
## Story 5.0 (AC 1, AC 4, AC 7): the placeholder chrome is gone and stays gone. No StyleBoxFlat and no corner
## radius in the UI scenes or the shared theme (stepped corners come from 9-slice StyleBoxTextures); no
## code-drawn shapes in the UI scripts or the zombie hands (they draw sprites). Palette ColorRect backdrops
## and the night scrim are allowed; the debug keyboard-test screen is exempt (dev only).
## Story 5.2 (AC 5): the in-run Zombie Run scenes are walked too (letter tags, the base target box, the conga
## badge use the theme's 9-slice variations).
## Story 6.6: the Horde Rush scenes are walked too, and its level and tomato have no ColorRect left (the field,
## the house and the tomato are sprites).

const SCENE_DIRS: Array[String] = [
	"res://scenes/ui/", "res://scenes/screens/", "res://scenes/run/", "res://scenes/levels/zombie_run/",
	"res://scenes/levels/horde_rush/",
]
const HORDE_RUSH_ART_SCENES: Array[String] = [
	"res://scenes/levels/horde_rush/horde_rush_level.tscn", "res://scenes/levels/horde_rush/tomato.tscn",
]
const EXEMPT_SCENES: Array[String] = ["res://scenes/screens/keyboard_test.tscn"]
const THEME_PATH: String = "res://data/ui_theme.tres"
const SCRIPT_DIR: String = "res://scripts/ui/"
const EXTRA_SCRIPTS: Array[String] = ["res://scripts/run/zombie_hands.gd"]
const FORBIDDEN_SCENE_TEXT: Array[String] = ["StyleBoxFlat", "corner_radius"]
const FORBIDDEN_DRAW_CALLS: Array[String] = ["draw_rect", "draw_colored_polygon", "draw_line", "draw_polyline", "draw_circle"]


func _files(dir: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == extension:
			found.append(dir + file)
	return found


func _ui_scenes() -> Array[String]:
	var scenes: Array[String] = []
	for dir: String in SCENE_DIRS:
		for path: String in _files(dir, "tscn"):
			if not EXEMPT_SCENES.has(path):
				scenes.append(path)
	return scenes


func test_the_walk_finds_the_ui() -> void:
	assert_gt(_ui_scenes().size(), 27, "scenes found (incl. the 7 Zombie Run and 5 Horde Rush scenes)")
	assert_gt(_files(SCRIPT_DIR, "gd").size(), 5, "scripts found")


func test_no_flat_boxes_in_ui_scenes_or_the_theme() -> void:
	var paths: Array[String] = _ui_scenes()
	paths.append(THEME_PATH)
	for path: String in paths:
		var text: String = FileAccess.get_file_as_string(path)
		for needle: String in FORBIDDEN_SCENE_TEXT:
			assert_false(text.contains(needle), "%s contains %s" % [path, needle])


func test_no_code_drawn_shapes_in_ui_scripts() -> void:
	var paths: Array[String] = _files(SCRIPT_DIR, "gd")
	paths.append_array(EXTRA_SCRIPTS)
	for path: String in paths:
		var text: String = FileAccess.get_file_as_string(path)
		for call: String in FORBIDDEN_DRAW_CALLS:
			assert_false(text.contains(call + "("), "%s calls %s" % [path, call])


func test_horde_rush_has_no_placeholder_rects() -> void:
	for path: String in HORDE_RUSH_ART_SCENES:
		var text: String = FileAccess.get_file_as_string(path)
		assert_ne(text, "", "%s found" % path)
		assert_false(text.contains("ColorRect"), "%s still has a ColorRect" % path)
