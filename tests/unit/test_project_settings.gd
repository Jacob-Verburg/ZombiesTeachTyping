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


## Order matters: an autoload may only use earlier ones in _ready() (architecture D2).
func test_autoloads_registered_in_order() -> void:
	var names: Array[String] = []
	for prop: Dictionary in ProjectSettings.get_property_list():
		var prop_name: String = prop["name"]
		if prop_name.begins_with("autoload/"):
			names.append(prop_name)
	assert_eq(names, [
		"autoload/WebPlatform",
		"autoload/SaveService",
		"autoload/PlayerData",
		"autoload/AudioManager",
		"autoload/Router",
	])


func test_autoloads_are_enabled_singletons() -> void:
	for autoload_name: String in ["WebPlatform", "SaveService", "PlayerData", "AudioManager", "Router"]:
		var value: String = ProjectSettings.get_setting("autoload/" + autoload_name, "")
		assert_true(value.begins_with("*res://scripts/autoloads/"), "%s -> %s" % [autoload_name, value])


func test_main_scene_is_set_and_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_ne(path, "", "application/run/main_scene must be set so the export has something to run")
	if path == "":
		return
	var scene: PackedScene = load(path) as PackedScene
	assert_not_null(scene)


## Story 5.0 (AC 3): the engine boot splash is the night page with the 1x title logo (Nearest, no stretch), and
## the clear colour is night, so loading page -> splash -> title never shows a grey frame.
func test_boot_splash_is_night_with_the_logo() -> void:
	var night: Color = Color("#2B1D3F")
	assert_true((ProjectSettings.get_setting("application/boot_splash/bg_color") as Color).is_equal_approx(night))
	assert_eq(ProjectSettings.get_setting("application/boot_splash/image"), "res://assets/sprites/ui/menu/ui_logo.png")
	assert_eq(ProjectSettings.get_setting("application/boot_splash/use_filter"), false)
	assert_eq(ProjectSettings.get_setting("application/boot_splash/stretch_mode"), 0, "Disabled: no stretch")
	assert_eq(ProjectSettings.get_setting("application/boot_splash/show_image"), true)
	assert_true((ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color") as Color)
			.is_equal_approx(night), "no grey frame between the splash and the first screen")
