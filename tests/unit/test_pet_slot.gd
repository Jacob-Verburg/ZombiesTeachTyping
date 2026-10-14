extends GutTest
## PetSlot (Story 4.3): the worn pet from an injected PlayerData on a temp save and a code-built catalogue
## (equip, unequip, the slot filter, profile_replaced, the _exit_tree disconnect), the warn-once-and-hide
## rules (NFR16), the follow_equipped = false preview hook, and every shipped pet's frames (Stories 4.3, 9.2).
## The live save is never touched.

const PetSlotScene: PackedScene = preload("res://scenes/cosmetics/pet_slot.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const CATALOGUE_PATH: String = "res://data/cosmetics/catalogue.tres"
const PETS_DIR: String = "res://assets/sprites/cosmetics/pets/"
## Style sheet section 3: a pet idle plays at 8-12 fps (every frame at duration 1.0).
const PET_MIN_FPS: float = 8.0
const PET_MAX_FPS: float = 12.0
const TEST_DIR: String = "user://test_pet_slot/"

var _player: PlayerDataScript
var _catalogue: Catalogue
var _pet: CosmeticItem
var _bare_pet: CosmeticItem
var _no_idle_pet: CosmeticItem
var _hat: CosmeticItem


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_pet = _item(&"pet_test", CosmeticItem.Slot.PET)
	_pet.pet_frames = _frames(&"idle")
	_bare_pet = _item(&"pet_bare", CosmeticItem.Slot.PET)
	_no_idle_pet = _item(&"pet_noidle", CosmeticItem.Slot.PET)
	_no_idle_pet.pet_frames = _frames(&"walk")
	_hat = _item(&"hat_test", CosmeticItem.Slot.HAT)
	_catalogue = Catalogue.new()
	_catalogue.items = [_hat, _pet, _bare_pet, _no_idle_pet]
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = TEST_DIR
	add_child_autofree(save)
	_player = PlayerDataScript.new()
	_player.save_service = save
	_player.catalogue = _catalogue
	add_child_autofree(_player)
	_player.add_brains(1000)


func after_each() -> void:
	_clear()


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _item(id: StringName, slot: CosmeticItem.Slot) -> CosmeticItem:
	var item: CosmeticItem = CosmeticItem.new()
	item.id = id
	item.slot = slot
	item.price = 100
	item.row = 1
	item.is_available = true
	return item


## Two frames of `anim` at 8 fps, looping.
func _frames(anim: StringName) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	for i: int in 2:
		frames.add_frame(anim, PlaceholderTexture2D.new())
	return frames


func _wear(item: CosmeticItem) -> void:
	_player.buy_item(item)
	_player.equip(item.id)


func _slot(follow: bool = true) -> PetSlot:
	var slot: PetSlot = PetSlotScene.instantiate() as PetSlot
	slot.player_data = _player
	slot.catalogue = _catalogue
	slot.follow_equipped = follow
	add_child_autofree(slot)
	return slot


func _sprite(slot: PetSlot) -> AnimatedSprite2D:
	return slot.get_node("%Pet") as AnimatedSprite2D


func _shows(slot: PetSlot, item: CosmeticItem) -> void:
	var pet: AnimatedSprite2D = _sprite(slot)
	assert_true(slot.is_showing(), "showing %s" % item.id)
	assert_true(pet.visible)
	assert_eq(pet.sprite_frames, item.pet_frames)
	assert_eq(pet.animation, &"idle")
	assert_true(pet.is_playing(), "plays idle")
	assert_eq(slot.get_item_id(), item.id)


func _empty(slot: PetSlot) -> void:
	assert_false(slot.is_showing(), "empty")
	assert_false(_sprite(slot).visible)
	assert_eq(slot.get_item_id(), &"")


func test_scene_shape() -> void:
	var slot: PetSlot = PetSlotScene.instantiate() as PetSlot
	var pet: AnimatedSprite2D = slot.get_node("%Pet") as AnimatedSprite2D
	assert_false(pet.centered)
	assert_eq(pet.position, Vector2(-16, -31), "feet centre at the origin, soles on row 30")
	assert_false(pet.visible, "hidden by default")
	assert_true(slot.follow_equipped)
	assert_not_null(slot.catalogue, "the shipped catalogue is set in the scene")
	slot.free()


func test_empty_on_a_fresh_save() -> void:
	_empty(_slot())


func test_equip_plays_idle_in_the_same_call() -> void:
	var slot: PetSlot = _slot()
	_wear(_pet)
	_shows(slot, _pet)


func test_already_worn_pet_shows_on_ready() -> void:
	_wear(_pet)
	_shows(_slot(), _pet)


func test_unequip_hides() -> void:
	var slot: PetSlot = _slot()
	_wear(_pet)
	_player.unequip(CosmeticItem.SLOT_PET)
	_empty(slot)
	assert_false(_sprite(slot).is_playing())


func test_hat_change_is_ignored() -> void:
	var slot: PetSlot = _slot()
	_wear(_pet)
	_wear(_hat)
	_player.unequip(CosmeticItem.SLOT_HAT)
	_shows(slot, _pet)


## The filter itself: a hat-slot signal never re-reads, so a pet swapped in the save behind the slot's
## back stays unseen until a pet-slot change.
func test_slot_filter_skips_hat_signals() -> void:
	var slot: PetSlot = _slot()
	_wear(_pet)
	var shown: CosmeticItem = slot.get_item()
	_player.equipment_changed.emit(CosmeticItem.SLOT_HAT, &"hat_test")
	assert_eq(slot.get_item(), shown)
	_player.save_service.get_active_profile()["equipped"]["pet"] = ""
	_player.equipment_changed.emit(CosmeticItem.SLOT_HAT, &"")
	assert_eq(slot.get_item(), shown, "hat signals never touch the pet")
	_player.equipment_changed.emit(CosmeticItem.SLOT_PET, &"")
	_empty(slot)


func test_reset_all_hides() -> void:
	var slot: PetSlot = _slot()
	_wear(_pet)
	_player.reset_all()
	_empty(slot)


func test_exit_tree_disconnects() -> void:
	var slot: PetSlot = _slot()
	assert_true(_player.equipment_changed.is_connected(slot._on_equipment_changed))
	remove_child(slot)
	assert_false(_player.equipment_changed.is_connected(slot._on_equipment_changed))
	assert_false(_player.profile_replaced.is_connected(slot._on_profile_replaced))
	slot.free()
	_wear(_pet)
	_player.reset_all()
	assert_push_error_count(0)


func test_pet_without_frames_warns_once_and_hides() -> void:
	var slot: PetSlot = _slot()
	_wear(_pet)
	_wear(_bare_pet)
	_empty(slot)
	_wear(_pet)
	_wear(_bare_pet)
	assert_push_warning("pet slot: pet_bare has no pet_frames")
	assert_push_warning_count(1)
	assert_push_error_count(0)


func test_frames_without_idle_warn_once_and_hide() -> void:
	var slot: PetSlot = _slot()
	_wear(_no_idle_pet)
	_empty(slot)
	slot.show_item(_no_idle_pet)
	assert_push_warning("pet slot: pet_noidle has no idle")
	assert_push_warning_count(1)


func test_equipped_id_missing_from_the_slot_catalogue_warns_and_hides() -> void:
	var slot: PetSlot = _slot()
	slot.catalogue = Catalogue.new()
	_wear(_pet)
	_empty(slot)
	assert_push_warning("pet slot: pet_test not in catalogue")


func test_not_following_shows_only_show_item() -> void:
	var slot: PetSlot = _slot(false)
	_wear(_pet)
	_empty(slot)
	slot.show_item(_pet)
	_shows(slot, _pet)
	_player.reset_all()
	_shows(slot, _pet)
	slot.show_item(null)
	_empty(slot)
	slot.show_item(_hat)
	_empty(slot)


func test_show_item_before_add_child_applies_on_ready() -> void:
	var slot: PetSlot = PetSlotScene.instantiate() as PetSlot
	slot.follow_equipped = false
	slot.show_item(_pet)
	add_child_autofree(slot)
	_shows(slot, _pet)


## Inherits process_mode: a paused tree (or a disabled parent) freezes the pet.
func test_inherits_process_mode() -> void:
	var slot: PetSlot = _slot()
	assert_eq(slot.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(_sprite(slot).process_mode, Node.PROCESS_MODE_INHERIT)


## Stories 4.3, 9.2: every shipped pet with frames plays a looping idle from its own sheet: one frame per
## 32 px of the sheet, each a Rect2(i * 32, 0, 32, 32) region at duration 1.0, PET_MIN_FPS-PET_MAX_FPS.
## The Cute ghost always has its frames.
func test_shipped_pet_frames() -> void:
	var catalogue: Catalogue = load(CATALOGUE_PATH) as Catalogue
	assert_not_null(catalogue)
	if catalogue == null:
		return
	var with_frames: int = 0
	for item: CosmeticItem in catalogue.items:
		if item.slot != CosmeticItem.Slot.PET:
			continue
		if item.id == &"pet_cute_ghost":
			assert_not_null(item.pet_frames, "the Cute ghost has frames")
			if item.pet_frames != null and item.pet_frames.has_animation(&"idle"):
				assert_eq(item.pet_frames.get_frame_count(&"idle"), 4, "ghost frame count")
				assert_eq(item.pet_frames.get_animation_speed(&"idle"), 8.0, "ghost speed")
		var frames: SpriteFrames = item.pet_frames
		if frames == null:
			continue
		with_frames += 1
		assert_true(frames.has_animation(&"idle"), "%s idle" % item.id)
		if not frames.has_animation(&"idle"):
			continue
		assert_true(frames.get_animation_loop(&"idle"), "%s loops" % item.id)
		assert_between(frames.get_animation_speed(&"idle"), PET_MIN_FPS, PET_MAX_FPS, "%s fps" % item.id)
		var sheet_path: String = PETS_DIR + String(item.id) + "_idle.png"
		var sheet: Texture2D = load(sheet_path) as Texture2D
		assert_not_null(sheet, "%s sheet %s" % [item.id, sheet_path])
		if sheet == null:
			continue
		assert_eq(frames.get_frame_count(&"idle"), sheet.get_width() / 32, "%s frame count" % item.id)
		for i: int in frames.get_frame_count(&"idle"):
			var atlas: AtlasTexture = frames.get_frame_texture(&"idle", i) as AtlasTexture
			assert_not_null(atlas, "%s frame %d is an AtlasTexture" % [item.id, i])
			if atlas == null:
				continue
			assert_eq(atlas.atlas, sheet, "%s frame %d atlas" % [item.id, i])
			assert_eq(atlas.region, Rect2(i * 32, 0, 32, 32), "%s frame %d region" % [item.id, i])
			assert_eq(frames.get_frame_duration(&"idle", i), 1.0, "%s frame %d duration" % [item.id, i])
	assert_gt(with_frames, 0, "at least the Cute ghost")


## Story 9.2 (AC 6, "fits every slot"): every shipped pet's idle frames are 32 x 32 AtlasTexture regions of a
## sheet exactly 32 px high, so the frame-rect layout tests (test_hud.gd, test_report_card.gd,
## test_main_menu.gd), written for a 32 x 32 frame, hold for every pet.
func test_every_shipped_pet_frame_is_a_32px_cell() -> void:
	var catalogue: Catalogue = load(CATALOGUE_PATH) as Catalogue
	var pets: int = 0
	for item: CosmeticItem in catalogue.items_for_slot(CosmeticItem.Slot.PET):
		pets += 1
		assert_not_null(item.pet_frames, "%s has frames" % item.id)
		if item.pet_frames == null or not item.pet_frames.has_animation(&"idle"):
			continue
		for i: int in item.pet_frames.get_frame_count(&"idle"):
			var atlas: AtlasTexture = item.pet_frames.get_frame_texture(&"idle", i) as AtlasTexture
			assert_not_null(atlas, "%s frame %d" % [item.id, i])
			if atlas == null or atlas.atlas == null:
				continue
			assert_eq(atlas.atlas.get_height(), 32, "%s sheet height" % item.id)
			assert_eq(atlas.region.size, Vector2(32, 32), "%s frame %d size" % [item.id, i])
			assert_eq(atlas.get_size(), Vector2(32, 32), "%s frame %d drawn size" % [item.id, i])
	assert_eq(pets, 9, "all nine pets")
