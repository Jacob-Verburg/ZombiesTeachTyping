extends GutTest
## Guards the export presets (Story 1.2): single-threaded web build, no PWA,
## and dev-only folders never shipped.

const PRESETS_PATH: String = "res://export_presets.cfg"
const REQUIRED_EXCLUDES: Array[String] = [
	"addons/gut/*", "tests/*", "tools/*", "docs/*", "_bmad/*", "_bmad-output/*", "build/*", ".gutconfig.json",
]

var _cfg: ConfigFile


func before_each() -> void:
	_cfg = ConfigFile.new()


func test_presets_file_loads() -> void:
	assert_eq(_cfg.load(PRESETS_PATH), OK, "export_presets.cfg must exist and parse")


func test_web_preset_is_single_threaded_without_pwa() -> void:
	var section: String = _load_and_find("Web")
	assert_ne(section, "", "a preset named Web must exist")
	if section == "":
		return
	assert_eq(_cfg.get_value(section, "platform"), "Web")
	var options: String = section + ".options"
	assert_eq(_cfg.get_value(options, "variant/thread_support"), false)
	assert_eq(_cfg.get_value(options, "progressive_web_app/enabled"), false)


## Story 5.0 (AC 2): the loading page matches the title: the head include restyles the default shell (night
## page, pixelated logo, a pumpkin bar on a dusk track); no script, no text, no custom shell.
func test_web_loading_page_is_restyled_by_the_head_include() -> void:
	var section: String = _load_and_find("Web")
	assert_ne(section, "")
	if section == "":
		return
	var options: String = section + ".options"
	var head: String = _cfg.get_value(options, "html/head_include", "")
	for needle: String in ["<style>", "#2B1D3F", "#F07A1C", "#4A3366", "#status-progress", "#status-splash",
			"image-rendering: pixelated", "body"]:
		assert_string_contains(head, needle)
	assert_false(head.contains("<script"), "CSS only")
	assert_false(head.contains("url("), "no external files or fonts")
	assert_eq(_cfg.get_value(options, "html/custom_html_shell", ""), "", "the default shell, restyled")


func test_windows_preset_exists() -> void:
	var section: String = _load_and_find("Windows Desktop")
	assert_ne(section, "", "a preset named Windows Desktop must exist")
	if section == "":
		return
	assert_eq(_cfg.get_value(section, "platform"), "Windows Desktop")


func test_both_presets_exclude_dev_folders() -> void:
	for preset_name: String in ["Web", "Windows Desktop"]:
		var section: String = _load_and_find(preset_name)
		assert_ne(section, "", "a preset named %s must exist" % preset_name)
		if section == "":
			continue
		var excludes: Array[String] = _split_filter(_cfg.get_value(section, "exclude_filter", ""))
		for pattern: String in REQUIRED_EXCLUDES:
			assert_has(excludes, pattern, "%s must exclude %s" % [preset_name, pattern])


func _load_and_find(preset_name: String) -> String:
	if _cfg.load(PRESETS_PATH) != OK:
		return ""
	for section: String in _cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") \
				and _cfg.get_value(section, "name", "") == preset_name:
			return section
	return ""


func _split_filter(filter: String) -> Array[String]:
	var result: Array[String] = []
	for part: String in filter.split(","):
		var trimmed: String = part.strip_edges()
		if trimmed != "":
			result.append(trimmed)
	return result
