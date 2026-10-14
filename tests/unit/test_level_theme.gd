extends GutTest
## LevelTheme (Story 10.1, FR76): a theme is art and music only. Pinning the script's property list means a
## gameplay field (timing, speed, count, brains, words) can never be added to a theme by accident.


func test_only_art_and_music_fields() -> void:
	var names: Array[String] = []
	for property: Dictionary in LevelTheme.new().get_script().get_script_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(str(property["name"]))
	names.sort()
	assert_eq(names, ["backdrop", "defender", "id", "music_id"] as Array[String])


func test_defaults() -> void:
	var theme: LevelTheme = LevelTheme.new()
	assert_eq(theme.id, &"")
	assert_null(theme.backdrop)
	assert_null(theme.defender)
	assert_eq(theme.music_id, &"")


func test_entry_get_theme() -> void:
	var entry: LevelEntry = LevelEntry.new()
	assert_eq(entry.themes.size(), 0, "no themes by default")
	assert_null(entry.get_theme(&"a"))
	var a: LevelTheme = LevelTheme.new()
	a.id = &"a"
	var b: LevelTheme = LevelTheme.new()
	b.id = &"b"
	entry.themes = [null, a, b]
	assert_eq(entry.get_theme(&"b"), b)
	assert_eq(entry.get_theme(&"a"), a)
	assert_null(entry.get_theme(&"c"))
	assert_null(entry.get_theme(&""))
