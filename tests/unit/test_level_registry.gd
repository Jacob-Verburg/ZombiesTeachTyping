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
	assert_eq(ids, [&"zombie_run", &"horde_rush", &"pitchfork_panic", &"test_level"] as Array[StringName])
	var zombie_run: LevelEntry = registry.get_entry(&"zombie_run")
	assert_true(zombie_run.available)
	assert_eq(zombie_run.card_picture.resource_path, "res://assets/sprites/ui/menu/ui_level_card_zombie_run.png")
	var names: Dictionary[StringName, String] = {&"horde_rush": "Horde Rush", &"pitchfork_panic": "Pitchfork Panic"}
	for id: StringName in names:
		var entry: LevelEntry = registry.get_entry(id)
		assert_not_null(entry, String(id))
		assert_false(entry.available, "%s is Coming soon" % id)
		assert_false(entry.debug_only)
		assert_null(entry.scene, "%s has no scene yet" % id)
		# Story 5.0: Coming soon cards show their level's picture too (greyed by the card).
		assert_eq(entry.card_picture.resource_path, "res://assets/sprites/ui/menu/ui_level_card_%s.png" % id)
		assert_eq(entry.display_name, names[id])
		assert_null(registry.get_scene(id), "%s has no scene to run" % id)
	var menu_ids: Array[StringName] = []
	for entry: LevelEntry in registry.menu_entries():
		menu_ids.append(entry.id)
	assert_eq(menu_ids, [&"zombie_run", &"horde_rush", &"pitchfork_panic"] as Array[StringName])
