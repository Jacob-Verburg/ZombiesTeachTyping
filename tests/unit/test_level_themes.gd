extends GutTest
## Levels apply a theme (Story 10.1, FR76): LevelBase.apply_theme swaps the backdrop slot (and Horde Rush's
## defender) before the level enters the tree. A level's shipped theme is a no-op (nothing rebuilt); a
## different scene really replaces the node; a missing scene warns and keeps the built-in look (NFR16).

const ZombieRunScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_level.tscn")
const HordeRushScene: PackedScene = preload("res://scenes/levels/horde_rush/horde_rush_level.tscn")
const PitchforkScene: PackedScene = preload("res://scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn")
const TestBackdrop: PackedScene = preload("res://tests/fixtures/levels/test_backdrop.tscn")
const TestDefender: PackedScene = preload("res://tests/fixtures/levels/test_defender.tscn")
const REGISTRY_PATH: String = "res://data/levels/level_registry.tres"
const HordeRushScript := preload("res://scripts/levels/horde_rush/horde_rush_level.gd")


func _shipped_theme(level_id: StringName) -> LevelTheme:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	return registry.get_entry(level_id).themes[0]


func _theme(id: StringName, backdrop: PackedScene, defender: PackedScene = null) -> LevelTheme:
	var theme: LevelTheme = LevelTheme.new()
	theme.id = id
	theme.backdrop = backdrop
	theme.defender = defender
	return theme


## A level instance with its sound seams stubbed, not yet in the tree.
func _level(scene: PackedScene) -> LevelBase:
	var level: LevelBase = scene.instantiate() as LevelBase
	level.process_mode = Node.PROCESS_MODE_DISABLED
	if "request_voice" in level:
		level.set("request_voice", func(_id: StringName) -> void: pass)
	if "play_sfx" in level:
		level.set("play_sfx", func(_id: StringName) -> void: pass)
	return level


func test_unique_slots_resolve_before_the_level_is_in_the_tree() -> void:
	var level: LevelBase = _level(ZombieRunScene)
	assert_false(level.is_inside_tree())
	assert_not_null(level.get_node_or_null("%Backdrop"), "%Backdrop resolves out of the tree")
	level.free()
	level = _level(HordeRushScene)
	assert_not_null(level.get_node_or_null("%Field"))
	assert_not_null(level.get_node_or_null("%Defender"))
	level.free()


func test_null_theme_changes_nothing() -> void:
	var level: LevelBase = _level(ZombieRunScene)
	var before: int = level.get_node("%Backdrop").get_instance_id()
	level.apply_theme(null)
	assert_eq(level.theme_id, &"")
	assert_eq(level.get_node("%Backdrop").get_instance_id(), before)
	level.free()
	assert_push_warning_count(0)


func test_each_shipped_theme_is_a_no_op() -> void:
	var cases: Dictionary[StringName, Array] = {
		&"zombie_run": [ZombieRunScene, "%Backdrop"],
		&"horde_rush": [HordeRushScene, "%Field"],
		&"pitchfork_panic": [PitchforkScene, "%Backdrop"],
	}
	for level_id: StringName in cases:
		var level: LevelBase = _level(cases[level_id][0] as PackedScene)
		var slot: String = str(cases[level_id][1])
		var before: int = level.get_node(slot).get_instance_id()
		var defender_before: int = 0
		if level_id == &"horde_rush":
			defender_before = level.get_node("%Defender").get_instance_id()
		var theme: LevelTheme = _shipped_theme(level_id)
		level.apply_theme(theme)
		assert_eq(level.theme_id, theme.id, "%s theme id" % level_id)
		assert_eq(level.get_node(slot).get_instance_id(), before, "%s keeps its built-in backdrop node" % level_id)
		if level_id == &"horde_rush":
			assert_eq(level.get_node("%Defender").get_instance_id(), defender_before, "the farmer is kept")
		add_child_autofree(level)
	assert_push_warning_count(0)
	assert_push_error_count(0)


func test_a_different_backdrop_really_swaps() -> void:
	var level: LevelBase = _level(ZombieRunScene)
	var old: Node = level.get_node("%Backdrop")
	var index: int = old.get_index()
	var old_ref: WeakRef = weakref(old)
	level.apply_theme(_theme(&"test", TestBackdrop))
	assert_null(old_ref.get_ref(), "the old backdrop is freed")
	var node: Node = level.get_node("%Backdrop")
	assert_eq(node.scene_file_path, TestBackdrop.resource_path)
	assert_eq(String(node.name), "Backdrop")
	assert_eq(node.get_index(), index, "same draw order")
	assert_eq(node.owner, level)
	assert_eq(level.theme_id, &"test")
	add_child_autofree(level)
	var backdrop: SunnyVillageBackdrop = node as SunnyVillageBackdrop
	level.call("_set_zombie_x", 1000.0)
	assert_ne(backdrop.get_layer(SunnyVillageBackdrop.LAYER_GROUND).position.x, 0.0, "the level scrolls the new backdrop")
	assert_push_warning_count(0)


func test_pitchfork_backdrop_swaps_too() -> void:
	var level: LevelBase = _level(PitchforkScene)
	var index: int = level.get_node("%Backdrop").get_index()
	level.apply_theme(_theme(&"test", TestBackdrop))
	assert_eq(level.get_node("%Backdrop").scene_file_path, TestBackdrop.resource_path)
	assert_eq(level.get_node("%Backdrop").get_index(), index)
	assert_not_null(level.get_node_or_null("%EscapeBush"), "the dive props stay in the level")
	add_child_autofree(level)
	assert_push_warning_count(0)


func test_horde_rush_swaps_field_and_defender() -> void:
	var level: HordeRushScript = _level(HordeRushScene) as HordeRushScript
	var old_defender: Node2D = level.get_node("%Defender") as Node2D
	var zombies: Node = level.get_node("%Zombies")
	var defender_index: int = old_defender.get_index()
	var defender_pos: Vector2 = old_defender.position
	level.apply_theme(_theme(&"test", TestBackdrop, TestDefender))
	assert_eq(level.get_node("%Field").scene_file_path, TestBackdrop.resource_path)
	var defender: Node = level.get_node("%Defender")
	assert_eq(defender.scene_file_path, TestDefender.resource_path)
	assert_eq(defender.get_parent(), zombies, "still under %Zombies, so it y-sorts")
	assert_eq(defender.get_index(), defender_index)
	assert_eq((defender as Node2D).position, defender_pos)
	add_child_autofree(level)
	assert_eq(level.get_defender_view(), defender, "the level drives the theme's defender")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	assert_not_null(level.create_target_source(rng))
	level.on_run_started()
	for i: int in 120:
		level._process(1.0 / 60.0)
	assert_true(level.is_defender_running(), "the logic still paces with a non-Farmer defender")
	assert_push_warning_count(0)
	assert_push_error_count(0)


func test_null_backdrop_warns_and_keeps_the_built_in_look() -> void:
	var level: LevelBase = _level(ZombieRunScene)
	var before: int = level.get_node("%Backdrop").get_instance_id()
	level.apply_theme(_theme(&"broken", null))
	assert_push_warning("theme broken has no Backdrop")
	assert_eq(level.get_node("%Backdrop").get_instance_id(), before)
	assert_eq(level.theme_id, &"broken")
	level.free()


func test_null_defender_warns_and_keeps_the_farmer() -> void:
	var level: HordeRushScript = _level(HordeRushScene) as HordeRushScript
	var before: int = level.get_node("%Defender").get_instance_id()
	level.apply_theme(_theme(&"half", TestBackdrop))
	assert_push_warning("theme half has no Defender")
	assert_eq(level.get_node("%Defender").get_instance_id(), before)
	add_child_autofree(level)
	assert_true(level.get_defender_view() is HordeFarmer)
