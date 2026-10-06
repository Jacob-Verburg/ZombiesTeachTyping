class_name PetSlot
extends Node2D
## The worn pet hanging out beside the zombie (Story 4.3, FR43): plays the pet's `idle` with its feet at
## the node origin (soles on sheet row 30, like the characters, so %Pet sits at (-16, -31)). Placed on the
## HUD cushion, beside Professor Zombie on the report card, and beside the zombie on the main menu.
## A pet follows no pose, so it needs no anchors. It inherits process_mode: the HUD pet freezes with the
## tree while a run is paused.
## With follow_equipped, it listens to PlayerData itself (equipment_changed for the pet slot only, and
## profile_replaced) and disconnects in _exit_tree. With follow_equipped = false it shows only what
## show_item() gives it (the fit check, and the Closet preview in 4.4).
## NFR16: a missing item, pet_frames or idle animation logs one warning per cause and hides the pet.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const ANIM_IDLE: StringName = &"idle"

## Where equipped ids are looked up (data/cosmetics/catalogue.tres, set in pet_slot.tscn).
@export var catalogue: Catalogue
## True: show what PlayerData has equipped. False: show only what show_item() gives.
@export var follow_equipped: bool = true

## Test seam: defaults to the PlayerData autoload in _ready (only when following).
var player_data: PlayerDataScript = null

var _item: CosmeticItem = null
## Warning keys already logged by this slot (one warning per cause).
var _warned: Dictionary[String, bool] = {}

@onready var _pet: AnimatedSprite2D = %Pet


func _ready() -> void:
	if follow_equipped and player_data == null:
		player_data = PlayerData
	if follow_equipped:
		player_data.equipment_changed.connect(_on_equipment_changed)
		player_data.profile_replaced.connect(_on_profile_replaced)
		_show_equipped()
	else:
		# A show_item() before add_child only stored the item; apply it now the sprite exists.
		show_item(_item)


func _exit_tree() -> void:
	if player_data == null:
		return
	if player_data.equipment_changed.is_connected(_on_equipment_changed):
		player_data.equipment_changed.disconnect(_on_equipment_changed)
	if player_data.profile_replaced.is_connected(_on_profile_replaced):
		player_data.profile_replaced.disconnect(_on_profile_replaced)


## Plays `item`'s idle, or shows nothing for null or a non-pet. A pet without pet_frames or without an
## idle animation warns once and shows nothing.
func show_item(item: CosmeticItem) -> void:
	var shown: CosmeticItem = null
	if item != null and item.slot == CosmeticItem.Slot.PET:
		if item.pet_frames == null:
			_warn_once("frames:%s" % item.id, "pet slot: %s has no pet_frames" % item.id)
		elif not item.pet_frames.has_animation(ANIM_IDLE):
			_warn_once("idle:%s" % item.id, "pet slot: %s has no idle" % item.id)
		else:
			shown = item
	var unchanged: bool = shown != null and shown == _item
	_item = shown
	if _pet == null:
		return
	if shown == null:
		_pet.stop()
		_pet.sprite_frames = null
		_pet.hide()
		return
	if unchanged and _pet.is_playing() and _pet.sprite_frames == shown.pet_frames:
		return
	_pet.sprite_frames = shown.pet_frames
	_pet.play(ANIM_IDLE)
	_pet.show()


## The shown pet (null when empty).
func get_item() -> CosmeticItem:
	return _item


## The shown pet's id, &"" when empty.
func get_item_id() -> StringName:
	return _item.id if _item != null else &""


func is_showing() -> bool:
	return _item != null and _pet != null and _pet.visible


func _show_equipped() -> void:
	if catalogue == null:
		_warn_once("catalogue", "pet slot: no catalogue")
		show_item(null)
		return
	var id: StringName = player_data.get_equipped(CosmeticItem.SLOT_PET)
	var item: CosmeticItem = catalogue.get_item(id)
	if id != &"" and item == null:
		_warn_once("missing:%s" % id, "pet slot: %s not in catalogue" % id)
	show_item(item)


func _on_equipment_changed(slot: StringName, _item_id: StringName) -> void:
	if not follow_equipped or slot != CosmeticItem.SLOT_PET:
		return
	_show_equipped()


func _on_profile_replaced() -> void:
	if not follow_equipped:
		return
	_show_equipped()


func _warn_once(key: String, msg: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	Log.warn(&"cosmetics", msg)
