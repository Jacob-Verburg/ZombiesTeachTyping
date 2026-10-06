extends GutTest
## HatSlot (Story 4.3): the worn hat from an injected PlayerData on a temp save and a code-built catalogue
## (equip, unequip, the slot filter, profile_replaced, two slots at once, the _exit_tree disconnect), the
## warn-once-and-hide rules (NFR16), the follow_equipped = false preview hook, and following the pose on a
## real player_zombie.tscn Body: every shipped frame, the idle 0 -> hop 0 trap (only animation_changed
## fires), the hug lean and the flip_h mirror. The live save is never touched.

const HatSlotScene: PackedScene = preload("res://scenes/cosmetics/hat_slot.tscn")
const PlayerZombieScene: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const ZOMBIE_ANCHORS: SpriteAnchors = preload("res://data/anchors/zombie_anchors.tres")
const TEST_DIR: String = "user://test_hat_slot/"

var _player: PlayerDataScript
var _catalogue: Catalogue
var _hat: CosmeticItem
var _bare_hat: CosmeticItem
var _pet: CosmeticItem


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_hat = _item(&"hat_test", CosmeticItem.Slot.HAT)
	_hat.overlay = ImageTexture.create_from_image(Image.create_empty(32, 32, false, Image.FORMAT_RGBA8))
	_bare_hat = _item(&"hat_bare", CosmeticItem.Slot.HAT)
	_pet = _item(&"pet_test", CosmeticItem.Slot.PET)
	_catalogue = Catalogue.new()
	_catalogue.items = [_hat, _bare_hat, _pet]
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
	item.display_name = String(id)
	item.slot = slot
	item.price = 100
	item.row = 1
	item.is_available = true
	return item


func _wear(item: CosmeticItem) -> void:
	_player.buy_item(item)
	_player.equip(item.id)


## A slot on a stopped zombie Body (the real scene's frames and anchors), seams set before add_child.
func _slot(follow: bool = true) -> HatSlot:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.centered = false
	sprite.sprite_frames = _zombie_frames()
	sprite.animation = &"idle"
	var slot: HatSlot = HatSlotScene.instantiate() as HatSlot
	slot.player_data = _player
	slot.catalogue = _catalogue
	slot.sprite = sprite
	slot.anchors = ZOMBIE_ANCHORS
	slot.follow_equipped = follow
	sprite.add_child(slot)
	add_child_autofree(sprite)
	return slot


func _zombie_frames() -> SpriteFrames:
	var zombie: Node = PlayerZombieScene.instantiate()
	var frames: SpriteFrames = (zombie.get_node("Body") as AnimatedSprite2D).sprite_frames
	zombie.free()
	return frames


func _overlay(slot: HatSlot) -> Sprite2D:
	return slot.get_node("%Overlay") as Sprite2D


func _shows(slot: HatSlot, item: CosmeticItem) -> void:
	assert_true(slot.is_showing(), "showing %s" % item.id)
	assert_true(_overlay(slot).visible)
	assert_eq(_overlay(slot).texture, item.overlay)
	assert_eq(slot.get_item_id(), item.id)


func _empty(slot: HatSlot) -> void:
	assert_false(slot.is_showing(), "empty")
	assert_false(_overlay(slot).visible)
	assert_eq(slot.get_item_id(), &"")
	assert_null(slot.get_item())


# --- scene ------------------------------------------------------------------------------------------

func test_scene_shape() -> void:
	var slot: HatSlot = HatSlotScene.instantiate() as HatSlot
	var overlay: Sprite2D = slot.get_node("%Overlay") as Sprite2D
	assert_false(overlay.centered)
	assert_eq(overlay.position, -HatSlot.SEAT)
	assert_false(overlay.visible, "hidden by default")
	assert_eq(HatSlot.SEAT, Vector2(16, 30))
	assert_true(slot.follow_equipped)
	assert_not_null(slot.catalogue, "the shipped catalogue is set in the scene")
	slot.free()


# --- PlayerData -------------------------------------------------------------------------------------

func test_empty_on_a_fresh_save() -> void:
	_empty(_slot())


func test_equip_shows_the_overlay_in_the_same_call() -> void:
	var slot: HatSlot = _slot()
	_wear(_hat)
	_shows(slot, _hat)


func test_already_worn_hat_shows_on_ready() -> void:
	_wear(_hat)
	_shows(_slot(), _hat)


func test_unequip_hides() -> void:
	var slot: HatSlot = _slot()
	_wear(_hat)
	_player.unequip(CosmeticItem.SLOT_HAT)
	_empty(slot)


func test_pet_change_is_ignored() -> void:
	var slot: HatSlot = _slot()
	var shows: Array[CosmeticItem] = []
	slot.item_shown.connect(func(item: CosmeticItem) -> void: shows.append(item))
	_wear(_pet)
	assert_eq(shows.size(), 0, "a pet change never re-shows the hat")
	_empty(slot)
	_wear(_hat)
	_player.unequip(CosmeticItem.SLOT_PET)
	_shows(slot, _hat)


func test_reset_all_hides() -> void:
	var slot: HatSlot = _slot()
	_wear(_hat)
	_player.reset_all()
	_empty(slot)


func test_two_slots_update_from_one_equip() -> void:
	var a: HatSlot = _slot()
	var b: HatSlot = _slot()
	_wear(_hat)
	_shows(a, _hat)
	_shows(b, _hat)


func test_item_shown_fires_on_every_show() -> void:
	var slot: HatSlot = _slot()
	var shows: Array = []
	slot.item_shown.connect(func(item: CosmeticItem) -> void: shows.append(item))
	_wear(_hat)
	_player.unequip(CosmeticItem.SLOT_HAT)
	assert_eq(shows, [_hat, null])


func test_exit_tree_disconnects() -> void:
	var slot: HatSlot = _slot()
	assert_true(_player.equipment_changed.is_connected(slot._on_equipment_changed))
	assert_true(_player.profile_replaced.is_connected(slot._on_profile_replaced))
	var body: Node = slot.get_parent()
	body.remove_child(slot)
	assert_false(_player.equipment_changed.is_connected(slot._on_equipment_changed))
	assert_false(_player.profile_replaced.is_connected(slot._on_profile_replaced))
	slot.free()
	_wear(_hat)
	_player.reset_all()
	assert_push_error_count(0)


# --- NFR16 ------------------------------------------------------------------------------------------

func test_item_without_overlay_warns_once_and_hides() -> void:
	var slot: HatSlot = _slot()
	_wear(_hat)
	_wear(_bare_hat)
	_empty(slot)
	_wear(_hat)
	_wear(_bare_hat)
	assert_push_warning("hat slot: hat_bare has no overlay")
	assert_push_warning_count(1, "one warning per cause and slot")
	assert_push_error_count(0)


func test_equipped_id_missing_from_the_slot_catalogue_warns_and_hides() -> void:
	var slot: HatSlot = _slot()
	slot.catalogue = Catalogue.new()
	_wear(_hat)
	_empty(slot)
	assert_push_warning("hat slot: hat_test not in catalogue")


func test_null_catalogue_warns_and_hides() -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = _zombie_frames()
	sprite.animation = &"idle"
	var slot: HatSlot = HatSlotScene.instantiate() as HatSlot
	slot.player_data = _player
	slot.catalogue = null
	slot.sprite = sprite
	slot.anchors = ZOMBIE_ANCHORS
	sprite.add_child(slot)
	add_child_autofree(sprite)
	assert_push_warning("hat slot: no catalogue")
	_empty(slot)


func test_no_sprite_warns_and_hides() -> void:
	var slot: HatSlot = HatSlotScene.instantiate() as HatSlot
	slot.player_data = _player
	add_child_autofree(slot)
	assert_push_warning("hat slot: no sprite to follow")
	assert_false(slot.visible)
	_wear(_hat)
	assert_push_error_count(0)


func test_null_anchors_warns_once_and_keeps_position() -> void:
	var slot: HatSlot = _slot()
	slot.anchors = null
	slot.position = Vector2(5, 5)
	slot.sprite.animation = &"walk"
	slot.sprite.frame = 1
	assert_eq(slot.position, Vector2(5, 5))
	assert_push_warning("hat slot: no anchors")
	assert_push_warning_count(1)


func test_missing_anchor_keeps_the_last_position_and_warns_once() -> void:
	var slot: HatSlot = _slot()
	var gappy: SpriteAnchors = SpriteAnchors.new()
	gappy.head = {&"idle": PackedVector2Array([Vector2(16, 1), Vector2(16, 2)])}
	slot.anchors = gappy
	slot.sprite.frame = 1
	assert_eq(slot.position, Vector2(16, 2))
	slot.sprite.animation = &"walk"
	assert_eq(slot.position, Vector2(16, 2), "kept the last good position")
	slot.sprite.frame = 2
	assert_eq(slot.position, Vector2(16, 2))
	assert_push_warning("hat slot: no anchor for walk")
	assert_push_warning_count(1, "one warning per animation")


# --- preview hook (4.4) -----------------------------------------------------------------------------

func test_not_following_ignores_player_data() -> void:
	var slot: HatSlot = _slot(false)
	_wear(_hat)
	_empty(slot)
	assert_false(_player.equipment_changed.is_connected(slot._on_equipment_changed))
	slot.show_item(_hat)
	_shows(slot, _hat)
	_player.unequip(CosmeticItem.SLOT_HAT)
	_player.reset_all()
	_shows(slot, _hat)
	slot.show_item(null)
	_empty(slot)


func test_show_item_before_add_child_applies_on_ready() -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = _zombie_frames()
	sprite.animation = &"idle"
	var slot: HatSlot = HatSlotScene.instantiate() as HatSlot
	slot.follow_equipped = false
	slot.sprite = sprite
	slot.anchors = ZOMBIE_ANCHORS
	slot.show_item(_hat)
	sprite.add_child(slot)
	add_child_autofree(sprite)
	_shows(slot, _hat)


func test_show_item_with_a_pet_shows_nothing() -> void:
	var slot: HatSlot = _slot(false)
	slot.show_item(_pet)
	_empty(slot)


# --- following the pose -----------------------------------------------------------------------------

func test_follows_every_shipped_frame() -> void:
	var slot: HatSlot = _slot(false)
	var sprite: AnimatedSprite2D = slot.sprite
	for anim: StringName in ZOMBIE_ANCHORS.head:
		sprite.animation = anim
		for frame: int in sprite.sprite_frames.get_frame_count(anim):
			sprite.frame = frame
			assert_eq(slot.position, ZOMBIE_ANCHORS.get_head(anim, frame), "%s %d" % [anim, frame])


## Frame index 0 stays 0, so frame_changed never fires: only animation_changed moves the hat.
func test_idle_0_to_hop_0_follows_the_crouch() -> void:
	var slot: HatSlot = _slot(false)
	var sprite: AnimatedSprite2D = slot.sprite
	assert_eq(sprite.frame, 0)
	assert_eq(slot.position, Vector2(16, 1))
	sprite.play(&"hop")
	sprite.stop()
	assert_eq(sprite.animation, &"hop")
	assert_eq(sprite.frame, 0)
	assert_eq(slot.position, Vector2(16, 3))


## animation_changed fires before the frame resets: dance frame 3 -> hop would read "hop 3" for a moment.
## That transient never warns, and the reset lands the hat on hop 0.
func test_switching_to_a_shorter_animation_never_warns() -> void:
	var slot: HatSlot = _slot(false)
	var sprite: AnimatedSprite2D = slot.sprite
	sprite.animation = &"dance"
	sprite.frame = 3
	assert_eq(slot.position, Vector2(16, 2))
	sprite.animation = &"hop"
	assert_eq(sprite.frame, 0)
	assert_eq(slot.position, Vector2(16, 3))
	sprite.play(&"dance")
	sprite.stop()
	sprite.frame = 3
	sprite.play(&"hug")
	assert_eq(slot.position, Vector2(16, 1))
	assert_push_warning_count(0)


func test_hug_squeeze_leans_right() -> void:
	var slot: HatSlot = _slot(false)
	slot.sprite.animation = &"hug"
	slot.sprite.frame = 1
	assert_eq(slot.position, Vector2(17, 1))


func test_flip_h_mirrors_the_point_and_the_overlay() -> void:
	var slot: HatSlot = _slot(false)
	slot.show_item(_hat)
	slot.sprite.flip_h = true
	slot.sprite.animation = &"hug"
	slot.sprite.frame = 1
	assert_eq(slot.position, Vector2(15, 1), "32 - 17")
	assert_true(_overlay(slot).flip_h)
	slot.sprite.flip_h = false
	slot.sprite.frame = 0
	assert_eq(slot.position, Vector2(16, 1))
	assert_false(_overlay(slot).flip_h)


func test_sprite_frames_swap_refollows() -> void:
	var slot: HatSlot = _slot(false)
	var sprite: AnimatedSprite2D = slot.sprite
	slot.position = Vector2.ZERO
	sprite.sprite_frames = _zombie_frames().duplicate()
	assert_eq(slot.position, ZOMBIE_ANCHORS.get_head(sprite.animation, sprite.frame))


func test_real_player_zombie_slot_is_wired() -> void:
	var zombie: PlayerZombie = PlayerZombieScene.instantiate() as PlayerZombie
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	var slot: HatSlot = zombie.get_node("%HatSlot") as HatSlot
	slot.player_data = _player
	add_child_autofree(zombie)
	var body: AnimatedSprite2D = zombie.get_node("Body")
	assert_eq(slot.sprite, body)
	assert_eq(slot.anchors, ZOMBIE_ANCHORS)
	assert_eq(slot.position, Vector2(16, 1))
	_wear(_hat)
	assert_false(slot.is_showing(), "hat_test is not in the slot's shipped catalogue")
	assert_push_warning("hat slot: hat_test not in catalogue")
	zombie.hop(0.35, 16.0)
	assert_eq(slot.position, Vector2(16, 3), "hop() plays the crouch frame")
