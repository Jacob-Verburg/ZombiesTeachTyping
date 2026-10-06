extends GutTest
## The hat & pet fit check (Story 4.3, debug-only): instantiates headless, builds 18 hat cells (16 zombie
## frames + 2 professor frames) at 1x and 3x on stopped sprites, cycles hats, pets and backgrounds with
## the shipped catalogue and an empty one, stacks the professor's mortarboard on the hat, and wears for
## real through an injected PlayerData on a temp save (never the live one).

const FitCheckScene: PackedScene = preload("res://scenes/debug/hat_fit_check.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_hat_fit_check/"
const CELLS_PER_SCALE: int = 18

var _player: PlayerDataScript


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	_player = PlayerDataScript.new()
	_player.save_service = save
	add_child_autofree(_player)


func after_each() -> void:
	_clear()


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make(catalogue: Catalogue = null) -> HatFitCheck:
	var check: HatFitCheck = FitCheckScene.instantiate() as HatFitCheck
	check.process_mode = Node.PROCESS_MODE_DISABLED
	check.player_data = _player
	if catalogue != null:
		check.catalogue = catalogue
	add_child_autofree(check)
	return check


func test_builds_18_cells_at_both_scales() -> void:
	var check: HatFitCheck = _make()
	var cells: Array[AnimatedSprite2D] = check.get_cells()
	assert_eq(cells.size(), CELLS_PER_SCALE * 2)
	var seen: Dictionary[String, int] = {}
	for sprite: AnimatedSprite2D in cells:
		assert_false(sprite.is_playing(), "stopped")
		var key: String = "%s %d" % [sprite.animation, sprite.frame]
		seen[key] = seen.get(key, 0) + 1
	assert_eq(seen.size(), CELLS_PER_SCALE, "18 distinct (animation, frame) pairs")
	for key: String in seen:
		assert_eq(seen[key], 2, "%s at 1x and 3x" % key)
	for key: String in ["idle 1", "walk 3", "hop 2", "hug 2", "dance 3", "point 0", "point 1"]:
		assert_true(seen.has(key), key)
	assert_eq(check.page_count(), 4, "5 cells a page")


func test_every_hat_slot_follows_its_frame_and_ignores_player_data() -> void:
	var check: HatFitCheck = _make()
	var slots: Array[HatSlot] = check.get_hat_slots()
	assert_eq(slots.size(), CELLS_PER_SCALE * 2)
	for slot: HatSlot in slots:
		assert_false(slot.follow_equipped)
		assert_eq(slot.position, slot.anchors.get_head(slot.sprite.animation, slot.sprite.frame))


func test_starts_on_the_pumpkin_and_the_ghost() -> void:
	var check: HatFitCheck = _make()
	assert_eq(check.current_hat().id, &"hat_pumpkin")
	assert_eq(check.current_pet().id, &"pet_cute_ghost")
	for slot: HatSlot in check.get_hat_slots():
		assert_eq(slot.get_item_id(), &"hat_pumpkin")
	for slot: PetSlot in check.get_pet_slots():
		assert_eq(slot.get_item_id(), &"pet_cute_ghost")


func test_professor_mortarboard_stacks_on_the_hat() -> void:
	var check: HatFitCheck = _make()
	var professors: int = 0
	for sprite: AnimatedSprite2D in check.get_cells():
		if sprite.animation != &"point":
			continue
		professors += 1
		var mortarboard: Sprite2D = sprite.get_node("Mortarboard")
		assert_eq(mortarboard.position.y, -11.0, "pumpkin rise")
	assert_eq(professors, 4)
	check.cycle_hat()
	assert_null(check.current_hat(), "none after the only hat")
	for sprite: AnimatedSprite2D in check.get_cells():
		if sprite.animation == &"point":
			assert_eq((sprite.get_node("Mortarboard") as Sprite2D).position.y, 0.0)


func test_cycling_never_crashes() -> void:
	var check: HatFitCheck = _make()
	for i: int in 5:
		check.cycle_hat()
		check.cycle_pet()
		check.cycle_background()
		check.next_page()
	assert_push_error_count(0)
	assert_push_warning_count(0)


func test_backgrounds_cycle() -> void:
	var check: HatFitCheck = _make()
	var names: Array[String] = []
	for i: int in 4:
		names.append(check.background_name())
		check.cycle_background()
	assert_eq(names, ["night", "art-sky", "chalkboard", "parchment"])
	assert_eq(check.background_name(), "night")


func test_empty_catalogue_shows_none() -> void:
	var check: HatFitCheck = _make(Catalogue.new())
	assert_null(check.current_hat())
	assert_null(check.current_pet())
	check.cycle_hat()
	check.cycle_pet()
	assert_null(check.current_hat())
	for slot: HatSlot in check.get_hat_slots():
		assert_false(slot.is_showing())
	assert_push_error_count(0)


func test_hat_without_overlay_is_skipped() -> void:
	var bare: CosmeticItem = CosmeticItem.new()
	bare.id = &"hat_bare"
	bare.slot = CosmeticItem.Slot.HAT
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items = [bare]
	var check: HatFitCheck = _make(catalogue)
	assert_null(check.current_hat(), "only none")
	check.cycle_hat()
	assert_null(check.current_hat())


func test_e_wears_for_real_and_none_unequips() -> void:
	var check: HatFitCheck = _make()
	check.wear_for_real()
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_HAT), &"hat_pumpkin")
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_PET), &"pet_cute_ghost")
	assert_eq(_player.get_brains(), 0, "the price was given, then spent")
	check.wear_for_real()
	assert_eq(_player.get_brains(), 0, "owned items are not bought twice")
	check.cycle_hat()
	check.cycle_pet()
	check.wear_for_real()
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_HAT), &"")
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_PET), &"")
	assert_true(_player.owns(&"hat_pumpkin"), "unequip keeps it owned")
	assert_push_error_count(0)
