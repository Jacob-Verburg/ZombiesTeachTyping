extends GutTest
## Guards the pixel-art project settings (Story 1.1) against the editor silently reverting them.


func test_viewport_is_logical_size() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)


func test_logical_size_constant_matches_viewport() -> void:
	var viewport_size := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	assert_eq(GameConstants.LOGICAL_SIZE, viewport_size)


func test_stretch_is_viewport_keep_fractional() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "fractional")


func test_canvas_texture_filter_is_nearest() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_2d_transforms_snap_to_pixel() -> void:
	assert_true(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"))


func test_untyped_declaration_is_error() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)


## Godot 4.7 replaced warnings/exclude_addons with directory_rules; 0 = exclude.
## GUT's own scripts must stay exempt from our strict-typing rule.
func test_addons_excluded_from_warnings() -> void:
	var rules: Dictionary = ProjectSettings.get_setting("debug/gdscript/warnings/directory_rules", {})
	assert_eq(rules.get("res://addons"), 0)


func test_dotnet_section_removed() -> void:
	assert_false(ProjectSettings.has_setting("dotnet/project/assembly_name"))


func test_main_scene_is_set_and_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_ne(path, "", "application/run/main_scene must be set so the export has something to run")
	if path == "":
		return
	var scene: PackedScene = load(path) as PackedScene
	assert_not_null(scene)
