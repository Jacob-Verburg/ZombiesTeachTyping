extends GutTest
## Level registry (Story 2.4): level_id -> PackedScene, and the shipped registry's contents.

const REGISTRY_PATH: String = "res://data/levels/level_registry.tres"
const SCENE_A: PackedScene = preload("res://scenes/levels/test_level/test_level.tscn")
const SCENE_B: PackedScene = preload("res://scenes/run/run_frame.tscn")


func _entry(id: StringName, scene: PackedScene, debug_only: bool = false) -> LevelEntry:
	var entry: LevelEntry = LevelEntry.new()
	entry.id = id
	entry.scene = scene
	entry.debug_only = debug_only
	return entry


func _registry() -> LevelRegistry:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_entry(&"a", SCENE_A), _entry(&"b", SCENE_B, true), _entry(&"empty", null)]
	return registry


func test_get_scene_returns_registered_scene() -> void:
	var registry: LevelRegistry = _registry()
	assert_eq(registry.get_scene(&"a"), SCENE_A)
	assert_eq(registry.get_scene(&"b"), SCENE_B)


func test_unknown_id_returns_null() -> void:
	var registry: LevelRegistry = _registry()
	assert_null(registry.get_scene(&"nope"))
	assert_null(registry.get_entry(&"nope"))
	assert_null(registry.get_scene(&""), "empty id")


func test_entry_without_scene_returns_null_scene() -> void:
	var registry: LevelRegistry = _registry()
	assert_not_null(registry.get_entry(&"empty"))
	assert_null(registry.get_scene(&"empty"))


func test_get_entry_keeps_flags() -> void:
	assert_true(_registry().get_entry(&"b").debug_only)
	assert_false(_registry().get_entry(&"a").debug_only)


func test_debug_only_level_is_refused_in_release_builds() -> void:
	var registry: LevelRegistry = _registry()
	assert_null(registry.get_scene(&"b", false), "debug_only entry in a release build")
	assert_eq(registry.get_scene(&"b", true), SCENE_B, "debug_only entry in a debug build")
	assert_eq(registry.get_scene(&"a", false), SCENE_A, "normal entry in a release build")


func test_first_duplicate_wins() -> void:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_entry(&"a", SCENE_A), _entry(&"a", SCENE_B)]
	assert_eq(registry.get_scene(&"a"), SCENE_A)


func test_shipped_registry() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	assert_not_null(registry, "level_registry.tres loads as a LevelRegistry")
	var ids: Array[StringName] = []
	for entry: LevelEntry in registry.entries:
		assert_false(entry.id in ids, "duplicate id %s" % entry.id)
		ids.append(entry.id)
	var test_entry: LevelEntry = registry.get_entry(&"test_level")
	assert_not_null(test_entry)
	assert_true(test_entry.debug_only, "test_level is debug-only")
	var level: Node = registry.get_scene(&"test_level").instantiate()
	assert_true(level is LevelBase)
	assert_not_null((level as LevelBase).get_level_config())
	level.free()


func test_shipped_registry_has_zombie_run() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	var entry: LevelEntry = registry.get_entry(&"zombie_run")
	assert_not_null(entry, "Zombie Run is registered (Story 3.1)")
	assert_eq(entry.display_name, "Zombie Run")
	assert_false(entry.debug_only)
	assert_eq(registry.entries[0].id, &"zombie_run", "listed first (menu order)")
	var scene: PackedScene = registry.get_scene(&"zombie_run", false)
	assert_not_null(scene, "visible in release builds")
	var level: Node = scene.instantiate()
	assert_true(level is LevelBase)
	assert_true((level as LevelBase).get_level_config() is ZombieRunConfig)
	level.free()


## Story 4.2: the menu lists the non-null, non-debug entries in registry order.
func test_menu_entries_skip_debug_only_and_null_and_keep_order() -> void:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_entry(&"c", null), null, _entry(&"dbg", SCENE_A, true), _entry(&"a", SCENE_A)]
	var ids: Array[StringName] = []
	for entry: LevelEntry in registry.menu_entries():
		ids.append(entry.id)
	assert_eq(ids, [&"c", &"a"] as Array[StringName])


func test_menu_entries_of_an_empty_registry_is_empty() -> void:
	assert_eq(LevelRegistry.new().menu_entries().size(), 0)


func test_shipped_registry_menu_levels() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	var ids: Array[StringName] = []
	for entry: LevelEntry in registry.entries:
		ids.append(entry.id)
	assert_eq(ids, [&"zombie_run", &"horde_rush", &"pitchfork_panic", &"test_level", &"test_word_level",
			&"test_paragraph_level"] as Array[StringName])
	for debug_id: StringName in [&"test_level", &"test_word_level", &"test_paragraph_level"]:
		assert_true(registry.get_entry(debug_id).debug_only, "%s stays debug-only" % debug_id)
	# Story 8.2: the debug-only "Test text" paragraph level.
	var text_entry: LevelEntry = registry.get_entry(&"test_paragraph_level")
	assert_true(text_entry.debug_only)
	assert_eq(text_entry.display_name, "Test text")
	var text_level: Node = registry.get_scene(&"test_paragraph_level").instantiate()
	assert_true(text_level is LevelBase)
	assert_eq((text_level as LevelBase).get_level_config().target_mode, LevelConfig.TargetMode.PARAGRAPH)
	text_level.free()
	var zombie_run: LevelEntry = registry.get_entry(&"zombie_run")
	assert_true(zombie_run.available)
	assert_eq(zombie_run.card_picture.resource_path, "res://assets/sprites/ui/menu/ui_level_card_zombie_run.png")
	var names: Dictionary[StringName, String] = {&"horde_rush": "Horde Rush", &"pitchfork_panic": "Pitchfork Panic"}
	for id: StringName in names:
		var entry: LevelEntry = registry.get_entry(id)
		assert_not_null(entry, String(id))
		# Story 6.7 switched Horde Rush on; Story 8.7 switched Pitchfork Panic on.
		assert_true(entry.available, "%s available" % id)
		assert_false(entry.debug_only)
		# Story 5.0: Coming soon cards show their level's picture too (greyed by the card).
		assert_eq(entry.card_picture.resource_path, "res://assets/sprites/ui/menu/ui_level_card_%s.png" % id)
		assert_eq(entry.display_name, names[id])
	# Story 6.3: Horde Rush has its scene (reachable from the debug jump); Story 6.7 makes its card selectable.
	var horde_rush: LevelEntry = registry.get_entry(&"horde_rush")
	assert_not_null(horde_rush.scene, "Horde Rush has its level scene")
	assert_not_null(registry.get_scene(&"horde_rush"))
	var root: Node = horde_rush.scene.instantiate()
	assert_true(root is LevelBase, "Horde Rush's root is a LevelBase")
	root.free()
	var pitchfork: LevelEntry = registry.get_entry(&"pitchfork_panic")
	# Story 8.3 gave it its level scene; Story 8.7 makes its card selectable (locked behind Horde Rush).
	assert_not_null(pitchfork.scene, "Pitchfork Panic has its level scene")
	assert_true(pitchfork.available, "Pitchfork Panic is switched on")
	assert_eq(pitchfork.unlocked_by, &"horde_rush", "it opens after a Horde Rush run ends on its timer")
	assert_eq(registry.get_scene(&"pitchfork_panic"), pitchfork.scene)
	var pitchfork_root: Node = pitchfork.scene.instantiate()
	assert_true(pitchfork_root is LevelBase, "Pitchfork Panic's root is a LevelBase")
	pitchfork_root.free()
	var menu_ids: Array[StringName] = []
	for entry: LevelEntry in registry.menu_entries():
		menu_ids.append(entry.id)
	assert_eq(menu_ids, [&"zombie_run", &"horde_rush", &"pitchfork_panic"] as Array[StringName])


func _chain_entry(id: StringName, unlocked_by: StringName, debug_only: bool = false) -> LevelEntry:
	var entry: LevelEntry = _entry(id, SCENE_A, debug_only)
	entry.unlocked_by = unlocked_by
	return entry


## Story 6.8 (FR79): Zombie Run opens Horde Rush, Horde Rush opens Pitchfork Panic; the chain is valid.
func test_shipped_unlock_chain() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	assert_eq(registry.validate(), "", "shipped registry validates")
	var expected: Dictionary[StringName, StringName] = {
		&"zombie_run": &"", &"horde_rush": &"zombie_run", &"pitchfork_panic": &"horde_rush",
		&"test_level": &"", &"test_word_level": &"", &"test_paragraph_level": &"",
	}
	for id: StringName in expected:
		assert_eq(registry.get_entry(id).unlocked_by, expected[id], "%s unlocked_by" % id)
	var opened: Array[StringName] = []
	for entry: LevelEntry in registry.unlocks_of(&"zombie_run"):
		opened.append(entry.id)
	assert_eq(opened, [&"horde_rush"] as Array[StringName])


func test_validate_accepts_a_good_chain() -> void:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_chain_entry(&"a", &""), _chain_entry(&"b", &"a"), _chain_entry(&"c", &"b"), null]
	assert_eq(registry.validate(), "")


func test_validate_catches_unknown_self_debug_and_loops() -> void:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_chain_entry(&"a", &""), _chain_entry(&"b", &"nope")]
	assert_string_contains(registry.validate(), "unknown level nope")
	registry.entries = [_chain_entry(&"a", &"a")]
	assert_string_contains(registry.validate(), "unlocked by itself")
	registry.entries = [_chain_entry(&"dbg", &"", true), _chain_entry(&"b", &"dbg")]
	assert_string_contains(registry.validate(), "debug-only level dbg")
	registry.entries = [_chain_entry(&"a", &"b"), _chain_entry(&"b", &"a")]
	assert_string_contains(registry.validate(), "loops")
	registry.entries = [_chain_entry(&"x", &"a"), _chain_entry(&"a", &"b"), _chain_entry(&"b", &"c"), _chain_entry(&"c", &"b")]
	assert_string_contains(registry.validate(), "loops", "a loop the start entry isn't part of")


func test_unlocks_of_keeps_registry_order_and_ignores_empty() -> void:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_chain_entry(&"a", &""), _chain_entry(&"c", &"a"), null, _chain_entry(&"b", &"a")]
	var ids: Array[StringName] = []
	for entry: LevelEntry in registry.unlocks_of(&"a"):
		ids.append(entry.id)
	assert_eq(ids, [&"c", &"b"] as Array[StringName])
	assert_eq(registry.unlocks_of(&"").size(), 0, "empty id opens nothing")
	assert_eq(registry.unlocks_of(&"c").size(), 0)


# --- themes (Story 10.1) -----------------------------------------------------------

func _themed(id: StringName, backdrop: PackedScene = SCENE_A) -> LevelTheme:
	var theme: LevelTheme = LevelTheme.new()
	theme.id = id
	theme.backdrop = backdrop
	return theme


func _themed_registry(themes: Array[LevelTheme]) -> LevelRegistry:
	var entry: LevelEntry = _entry(&"a", SCENE_A)
	entry.themes = themes
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [entry]
	return registry


func test_validate_accepts_good_themes() -> void:
	assert_eq(_themed_registry([_themed(&"x"), _themed(&"y")] as Array[LevelTheme]).validate(), "")
	assert_eq(_themed_registry([] as Array[LevelTheme]).validate(), "", "no themes is fine")


func test_validate_catches_a_null_theme() -> void:
	assert_eq(_themed_registry([_themed(&"x"), null] as Array[LevelTheme]).validate(), "a has a null theme")


func test_validate_catches_a_theme_with_no_id() -> void:
	assert_eq(_themed_registry([_themed(&"")] as Array[LevelTheme]).validate(), "a has a theme with no id")


func test_validate_catches_a_duplicate_theme_id() -> void:
	assert_eq(_themed_registry([_themed(&"x"), _themed(&"x")] as Array[LevelTheme]).validate(), "a has two themes called x")


func test_validate_catches_a_theme_with_no_backdrop() -> void:
	assert_eq(_themed_registry([_themed(&"x", null)] as Array[LevelTheme]).validate(), "a theme x has no backdrop")


func test_shipped_registry_themes() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	assert_eq(registry.validate(), "", "shipped registry validates")
	# Story 10.2: Zombie Run ships three looks, Sunny first (the level scene's built-in look, so themes[0] is
	# the no-op); the other two levels ship one.
	var expected: Dictionary[StringName, Array] = {
		&"zombie_run": [&"sunny_village_green", &"pumpkin_patch_farm", &"snowy_town"],
		&"horde_rush": [&"farmhouse"],
		&"pitchfork_panic": [&"moonlit_village"],
	}
	for entry: LevelEntry in registry.entries:
		if entry.debug_only:
			assert_eq(entry.themes.size(), 0, "%s (debug) has no themes" % entry.id)
			continue
		assert_gte(entry.themes.size(), 1, "%s has at least one theme" % entry.id)
	for id: StringName in expected:
		var themes: Array[LevelTheme] = registry.get_entry(id).themes
		var ids: Array = themes.map(func(theme: LevelTheme) -> StringName: return theme.id)
		assert_eq(ids, expected[id], "%s ships its themes in order (Stories 10.1, 10.2)" % id)
		for theme: LevelTheme in themes:
			assert_not_null(theme.backdrop, "%s backdrop" % theme.id)
			assert_eq(theme.music_id, &"", "%s uses its config's music" % theme.id)
			if id == &"horde_rush":
				assert_not_null(theme.defender, "the farmhouse theme has the farmer")
				assert_eq(theme.defender.resource_path, "res://scenes/levels/horde_rush/farmer.tscn")
			else:
				assert_null(theme.defender, "%s has no defender" % theme.id)
