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
	assert_null(registry.get_entry(&"zombie_run"), "Zombie Run arrives with Story 3.1")
	var level: Node = registry.get_scene(&"test_level").instantiate()
	assert_true(level is LevelBase)
	assert_not_null((level as LevelBase).get_level_config())
	level.free()
