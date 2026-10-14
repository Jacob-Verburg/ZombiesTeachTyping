extends GutTest
## The hat & pet fit check (Story 4.3, debug-only): instantiates headless, builds 30 hat cells (28 zombie
## frames: idle 2 + walk 4 + hop 3 + hug 3 + dance 4 + flash 4 + melt 6 + dazed 2, + 2 professor frames) at
## 1x and 3x on stopped sprites, plus (Story 9.1) a size-class page: per Horde Rush class a walk 0 cell at
## its sprite_scale and a detail cell at sprite_scale x 3. Cycles hats, pets and backgrounds with the shipped
## catalogue, an all-hats copy (every hat given its own overlay PNG, so the cycle is tested apart from the
## data wiring) and an empty one, stacks the professor's mortarboard on the hat, and wears for real through
## an injected PlayerData on a temp save (never the live one). Story 9.2: the pet cycle over an all-pets copy
## (every pet given frames from its own idle PNG), and the menu and report card views (a stopped zombie and
## the professor, each wearing the hat, the pet at the scene's own spacing).

const FitCheckScene: PackedScene = preload("res://scenes/debug/hat_fit_check.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_hat_fit_check/"
## 28 zombie frames + 2 professor frames.
const FRAME_CELLS_PER_SCALE: int = 30
const ArtSprites := preload("res://tests/unit/test_art_sprites.gd")
const HORDE_CONFIG: HordeRushConfig = preload("res://data/levels/horde_rush.tres")
## The catalogue's hats in grid order (Story 9.1: the pumpkin and the eight new ones).
const GRID_HATS: Array[StringName] = [&"hat_pumpkin", &"hat_witch", &"hat_bunny_ears", &"hat_santa",
		&"hat_leprechaun", &"hat_heart_headband", &"hat_top_hat", &"hat_pirate", &"hat_crown"]
## The catalogue's pets in grid order (Story 9.2: the ghost and the eight new ones).
const GRID_PETS: Array[StringName] = [&"pet_cute_ghost", &"pet_black_cat", &"pet_spider", &"pet_orange_cat",
		&"pet_bat", &"pet_crow", &"pet_wolf_dog", &"pet_eyeball", &"pet_brain_buddy"]
const CATALOGUE: Catalogue = preload("res://data/cosmetics/catalogue.tres")
const PETS_DIR: String = "res://assets/sprites/cosmetics/pets/"
## The main menu's pet spacing (main_menu.tscn: Zombie at (48, 284), PetSlot at (84, 284)).
const MENU_PET_OFFSET: Vector2 = Vector2(36, 0)
## The professor's %PetSlot position (professor_zombie.tscn).
const PROFESSOR_PET_OFFSET: Vector2 = Vector2(60, 30)
## Hat slots beyond the cells: the menu view's zombie and the report card view's professor.
const VIEW_HAT_SLOTS: int = 2
## Pet slots: the cushion at 1x and 3x, the menu view's and the professor's.
const PET_SLOTS: int = 4

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


## Every cell: the frames at 1x and 3x, plus a scaled and a 3x detail cell per Horde Rush size class.
func _all_cell_count() -> int:
	return (FRAME_CELLS_PER_SCALE + HORDE_CONFIG.size_classes.size()) * 2


## 5 frame columns a page (HatFitCheck.PAGE_SIZE), then the size-class page.
func _expected_pages() -> int:
	return ceili(float(FRAME_CELLS_PER_SCALE) / HatFitCheck.PAGE_SIZE) + 1


## A per-item copy of the shipped catalogue (a deep duplicate would share the items) whose every pet plays
## its own idle PNG (4 frames at 8 fps), so the pet cycle is tested apart from the .tres wiring.
func _all_pets_catalogue() -> Catalogue:
	var copy: Catalogue = Catalogue.new()
	var items: Array[CosmeticItem] = []
	for item: CosmeticItem in CATALOGUE.items:
		var dup: CosmeticItem = item.duplicate() as CosmeticItem
		if dup.slot == CosmeticItem.Slot.PET:
			var sheet: Texture2D = load(PETS_DIR + String(dup.id) + "_idle.png") as Texture2D
			var frames: SpriteFrames = SpriteFrames.new()
			frames.add_animation(&"idle")
			for i: int in (sheet.get_width() / 32 if sheet != null else 0):
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = Rect2(i * 32, 0, 32, 32)
				frames.add_frame(&"idle", atlas)
			dup.pet_frames = frames
		items.append(dup)
	copy.items = items
	return copy


func _cycle_to_none(check: HatFitCheck) -> int:
	var cycles: int = 0
	while check.current_hat() != null and cycles < 100:
		check.cycle_hat()
		cycles += 1
	return cycles


func test_builds_every_frame_at_both_scales_plus_the_size_classes() -> void:
	var check: HatFitCheck = _make()
	var cells: Array[AnimatedSprite2D] = check.get_cells()
	assert_eq(cells.size(), _all_cell_count())
	var size_cells: Array[AnimatedSprite2D] = check.get_size_class_cells()
	assert_eq(size_cells.size(), HORDE_CONFIG.size_classes.size() * 2)
	assert_eq(cells.slice(FRAME_CELLS_PER_SCALE * 2), size_cells, "the size classes come last")
	var seen: Dictionary[String, int] = {}
	for sprite: AnimatedSprite2D in cells.slice(0, FRAME_CELLS_PER_SCALE * 2):
		assert_false(sprite.is_playing(), "stopped")
		var key: String = "%s %d" % [sprite.animation, sprite.frame]
		seen[key] = seen.get(key, 0) + 1
	assert_eq(seen.size(), FRAME_CELLS_PER_SCALE, "30 distinct (animation, frame) pairs")
	for key: String in seen:
		assert_eq(seen[key], 2, "%s at 1x and 3x" % key)
	for key: String in ["idle 1", "walk 3", "hop 2", "hug 2", "dance 3", "flash 3", "melt 5", "dazed 1", "point 0",
			"point 1"]:
		assert_true(seen.has(key), key)
	assert_eq(check.page_count(), _expected_pages(), "5 columns a page, then the size-class page")


## Story 9.1: the size-class cells use the config's scales (never literals) and their hat slots sit on the
## anchors' head point, so the hat scales with the body.
func test_size_class_cells_use_the_config_scales() -> void:
	var check: HatFitCheck = _make()
	var size_cells: Array[AnimatedSprite2D] = check.get_size_class_cells()
	assert_eq(size_cells.size(), HORDE_CONFIG.size_classes.size() * 2)
	if size_cells.size() != HORDE_CONFIG.size_classes.size() * 2:
		return
	var anchors: SpriteAnchors = load("res://data/anchors/zombie_anchors.tres") as SpriteAnchors
	for i: int in HORDE_CONFIG.size_classes.size():
		var expected: float = HORDE_CONFIG.size_classes[i].sprite_scale
		var cell: AnimatedSprite2D = size_cells[i * 2]
		var detail: AnimatedSprite2D = size_cells[i * 2 + 1]
		assert_almost_eq((cell.get_parent() as Node2D).scale.x, expected, 0.0001, "class %d scale" % i)
		assert_almost_eq((detail.get_parent() as Node2D).scale.x, expected * HatFitCheck.DETAIL_SCALE, 0.0001,
				"class %d detail scale" % i)
		for sprite: AnimatedSprite2D in [cell, detail]:
			assert_false(sprite.is_playing(), "stopped")
			assert_eq(sprite.animation, &"walk")
			assert_eq(sprite.frame, 0)
			var slot: HatSlot = sprite.get_node("HatSlot") as HatSlot
			assert_not_null(slot)
			if slot != null:
				assert_eq(slot.position, anchors.get_head(&"walk", 0))
				assert_eq(slot.get_item_id(), &"hat_pumpkin")


func test_no_horde_config_means_no_size_class_page() -> void:
	var check: HatFitCheck = FitCheckScene.instantiate() as HatFitCheck
	check.process_mode = Node.PROCESS_MODE_DISABLED
	check.player_data = _player
	check.horde_config = null
	add_child_autofree(check)
	assert_eq(check.get_size_class_cells().size(), 0)
	assert_eq(check.get_cells().size(), FRAME_CELLS_PER_SCALE * 2)
	assert_eq(check.page_count(), _expected_pages() - 1, "no size-class page")


## Story 9.1: the hat cycle visits exactly the catalogue's hats in grid order, then none.
func test_hat_cycle_visits_every_catalogue_hat_in_grid_order() -> void:
	var check: HatFitCheck = _make()
	var visited: Array[StringName] = []
	while check.current_hat() != null and visited.size() < 100:
		visited.append(check.current_hat().id)
		check.cycle_hat()
	assert_eq(visited, GRID_HATS)
	assert_null(check.current_hat(), "then none")
	check.cycle_hat()
	assert_eq(check.current_hat().id, &"hat_pumpkin", "and round again")


func test_every_hat_slot_follows_its_frame_and_ignores_player_data() -> void:
	var check: HatFitCheck = _make()
	var slots: Array[HatSlot] = check.get_hat_slots()
	assert_eq(slots.size(), _all_cell_count() + VIEW_HAT_SLOTS)
	for slot: HatSlot in slots:
		assert_false(slot.follow_equipped)
		assert_eq(slot.position, slot.anchors.get_head(slot.sprite.animation, slot.sprite.frame))


func test_starts_on_the_pumpkin_and_the_ghost() -> void:
	var check: HatFitCheck = _make()
	assert_eq(check.current_hat().id, &"hat_pumpkin")
	assert_eq(check.current_pet().id, &"pet_cute_ghost")
	for slot: HatSlot in check.get_hat_slots():
		assert_eq(slot.get_item_id(), &"hat_pumpkin")
	assert_eq(check.get_pet_slots().size(), PET_SLOTS)
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
	_cycle_to_none(check)
	assert_null(check.current_hat(), "none after the last hat")
	for sprite: AnimatedSprite2D in check.get_cells():
		if sprite.animation == &"point":
			assert_eq((sprite.get_node("Mortarboard") as Sprite2D).position.y, 0.0)


## Story 9.1: a tall hat lifts the mortarboard by its own rise (30 - its top opaque row).
func test_a_tall_hat_lifts_the_mortarboard_by_its_rise() -> void:
	var check: HatFitCheck = _make()
	while check.current_hat() != null and check.current_hat().id != &"hat_witch":
		check.cycle_hat()
	assert_not_null(check.current_hat(), "the witch hat is in the cycle")
	if check.current_hat() == null:
		return
	var rise: int = ArtSprites.HAT_SEAT_ROW - check.current_hat().overlay.get_image().get_used_rect().position.y
	assert_gt(rise, 11, "taller than the pumpkin")
	var professors: int = 0
	for sprite: AnimatedSprite2D in check.get_cells():
		if sprite.animation != &"point":
			continue
		professors += 1
		assert_eq((sprite.get_node("Mortarboard") as Sprite2D).position.y, -float(rise))
	assert_eq(professors, 4)


func test_cycling_never_crashes() -> void:
	var check: HatFitCheck = _make()
	for i: int in 12:
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
	_cycle_to_none(check)
	var pet_cycles: int = 0
	while check.current_pet() != null and pet_cycles < 100:
		check.cycle_pet()
		pet_cycles += 1
	check.wear_for_real()
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_HAT), &"")
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_PET), &"")
	assert_true(_player.owns(&"hat_pumpkin"), "unequip keeps it owned")
	assert_push_error_count(0)


## Story 9.3: E buys and wears a new shipped item (all live); an unavailable one (none ship) warns "could not
## buy" and leaves the slot as it was.
func test_e_wears_a_new_hat_and_warns_on_an_unavailable_one() -> void:
	var check: HatFitCheck = _make()
	while check.current_hat() != null and check.current_hat().id != &"hat_witch":
		check.cycle_hat()
	check.wear_for_real()
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_HAT), &"hat_witch", "a live Epic 9 hat wears")
	assert_push_warning_count(0)
	var copy: Catalogue = Catalogue.new()
	for item: CosmeticItem in CATALOGUE.items:
		var dup: CosmeticItem = item.duplicate() as CosmeticItem
		dup.is_available = dup.id != &"hat_crown"
		copy.items.append(dup)
	var shipped_catalogue: Catalogue = _player.catalogue
	_player.catalogue = copy
	var locked: HatFitCheck = _make(copy)
	while locked.current_hat() != null and locked.current_hat().id != &"hat_crown":
		locked.cycle_hat()
	locked.wear_for_real()
	assert_push_warning("could not buy hat_crown")
	assert_false(_player.owns(&"hat_crown"))
	assert_eq(_player.get_equipped(CosmeticItem.SLOT_HAT), &"hat_witch", "unchanged")
	_player.catalogue = shipped_catalogue


## Story 9.2: the pet cycle visits exactly the catalogue's pets in grid order, then none, and every pet slot
## (the cushion at both scales and both views) shows the current pet.
func test_pet_cycle_visits_every_catalogue_pet_in_grid_order() -> void:
	var check: HatFitCheck = _make(_all_pets_catalogue())
	var visited: Array[StringName] = []
	while check.current_pet() != null and visited.size() < 100:
		visited.append(check.current_pet().id)
		assert_eq(check.get_pet_slots().size(), PET_SLOTS)
		for slot: PetSlot in check.get_pet_slots():
			assert_false(slot.follow_equipped)
			assert_eq(slot.get_item_id(), check.current_pet().id, "every slot shows %s" % check.current_pet().id)
			assert_true(slot.is_showing(), "%s is shown" % check.current_pet().id)
		check.cycle_pet()
	assert_eq(visited, GRID_PETS)
	assert_null(check.current_pet(), "then none")
	for slot: PetSlot in check.get_pet_slots():
		assert_false(slot.is_showing(), "none hides every pet slot")
	check.cycle_pet()
	assert_eq(check.current_pet().id, &"pet_cute_ghost", "and round again")
	assert_push_error_count(0)
	assert_push_warning_count(0)


## Story 9.2: the menu view is a stopped player zombie on idle 0 wearing the hat, its pet at the menu's
## spacing; the report card view is the professor on point 0 wearing the hat, the pet in his own %PetSlot.
func test_menu_and_report_views_stand_at_the_scene_spacings() -> void:
	var check: HatFitCheck = _make(_all_pets_catalogue())
	var zombie: PlayerZombie = check.get_menu_zombie()
	var professor: ProfessorZombie = check.get_report_professor()
	assert_not_null(zombie, "menu view built")
	assert_not_null(professor, "report card view built")
	if zombie == null or professor == null:
		return
	var slots: Array[PetSlot] = check.get_pet_slots()
	var menu_pet: PetSlot = slots[PET_SLOTS - 2]
	var report_pet: PetSlot = slots[PET_SLOTS - 1]
	assert_eq(menu_pet.position - zombie.position, MENU_PET_OFFSET, "menu spacing")
	assert_eq(report_pet, professor.get_node("%PetSlot"), "the professor's own pet slot")
	assert_eq(report_pet.position, PROFESSOR_PET_OFFSET, "report card spacing")
	assert_eq(report_pet.global_position - professor.global_position, PROFESSOR_PET_OFFSET)
	var zombie_body: AnimatedSprite2D = zombie.get_node("Body")
	var professor_body: AnimatedSprite2D = professor.get_node("Body")
	assert_false(zombie_body.is_playing(), "the zombie is stopped")
	assert_eq([zombie_body.animation, zombie_body.frame], [&"idle", 0])
	assert_false(professor_body.is_playing(), "the professor is stopped")
	assert_eq([professor_body.animation, professor_body.frame], [&"point", 0])
	var zombie_hat: HatSlot = zombie.get_node("%HatSlot")
	var professor_hat: HatSlot = professor.get_node("%HatSlot")
	for i: int in GRID_HATS.size() + 1:
		var hat_id: StringName = &"" if check.current_hat() == null else check.current_hat().id
		assert_eq(zombie_hat.get_item_id(), hat_id, "the zombie wears %s" % hat_id)
		assert_eq(professor_hat.get_item_id(), hat_id, "the professor wears %s" % hat_id)
		check.cycle_hat()
	var pet_id: StringName = check.current_pet().id
	assert_eq(menu_pet.get_item_id(), pet_id)
	assert_eq(report_pet.get_item_id(), pet_id)
