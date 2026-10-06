class_name HatSlot
extends Node2D
## The worn hat on a character's head (Story 4.3, FR43, architecture D6). A child of the character's
## AnimatedSprite2D (`sprite`): on every frame_changed, animation_changed and sprite_frames_changed it moves
## to that frame's head point from `anchors`, so the hat fits every pose. The hop/hug/dance tweens move the
## sprite, and the slot rides along as its child. `flip_h` on the sprite mirrors the point and the overlay.
## With follow_equipped, it listens to PlayerData itself (equipment_changed for the hat slot only, and
## profile_replaced) and disconnects in _exit_tree, so the screens and characters stay passive.
## With follow_equipped = false it ignores PlayerData and shows only what show_item() gives it (the fit
## check, and the Closet preview in 4.4).
## NFR16: a missing item, overlay, sprite or anchor logs one warning per cause and hides the hat (or keeps
## the last good position, for an anchor gap); it never stops a run.

## Emitted on every show, including an empty one (item null). Professor Zombie stacks his mortarboard on it.
signal item_shown(item: CosmeticItem)

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
## The overlay pixel that sits on the head point: the bottom-centre of the brim. Every hat overlay is a
## 32x32 frame with its lowest opaque row on row 30, centred on column 16 (it mirrors the characters'
## "soles on row 30" rule; docs/art-style-sheet.md section 3).
const SEAT: Vector2 = Vector2(16, 30)
## Character frame width: a flipped sprite mirrors a head point's x about it.
const FRAME_W: float = 32.0

## The body this slot follows (set in the character scene to the parent sprite).
@export var sprite: AnimatedSprite2D
## The body's per-frame head points.
@export var anchors: SpriteAnchors
## Where equipped ids are looked up (data/cosmetics/catalogue.tres, set in hat_slot.tscn).
@export var catalogue: Catalogue
## True: show what PlayerData has equipped. False: show only what show_item() gives.
@export var follow_equipped: bool = true

## Test seam: defaults to the PlayerData autoload in _ready (only when following).
var player_data: PlayerDataScript = null

var _item: CosmeticItem = null
## The sprite's flip_h at the last _follow: flip_h emits no signal, so _process watches for a change.
var _followed_flip: bool = false
## Warning keys already logged by this slot (one warning per cause).
var _warned: Dictionary[String, bool] = {}

@onready var _overlay: Sprite2D = %Overlay


func _ready() -> void:
	if follow_equipped and player_data == null:
		player_data = PlayerData
	if sprite == null:
		_warn_once("sprite", "hat slot: no sprite to follow")
		show_item(null)
		hide()
		return
	sprite.frame_changed.connect(_follow)
	sprite.animation_changed.connect(_follow)
	sprite.sprite_frames_changed.connect(_follow)
	_follow()
	if follow_equipped:
		player_data.equipment_changed.connect(_on_equipment_changed)
		player_data.profile_replaced.connect(_on_profile_replaced)
		_show_equipped()
	else:
		# A show_item() before add_child only stored the item; apply it now the overlay exists.
		show_item(_item)


func _process(_delta: float) -> void:
	if sprite != null and sprite.flip_h != _followed_flip:
		_follow()


func _exit_tree() -> void:
	if player_data == null:
		return
	if player_data.equipment_changed.is_connected(_on_equipment_changed):
		player_data.equipment_changed.disconnect(_on_equipment_changed)
	if player_data.profile_replaced.is_connected(_on_profile_replaced):
		player_data.profile_replaced.disconnect(_on_profile_replaced)


## Shows `item`'s overlay, or nothing for null or a non-hat. A hat without an overlay warns once and shows
## nothing.
func show_item(item: CosmeticItem) -> void:
	var shown: CosmeticItem = null
	if item != null and item.slot == CosmeticItem.Slot.HAT:
		if item.overlay == null:
			_warn_once("overlay:%s" % item.id, "hat slot: %s has no overlay" % item.id)
		else:
			shown = item
	_item = shown
	if _overlay != null:
		_overlay.texture = shown.overlay if shown != null else null
		_overlay.visible = shown != null
	item_shown.emit(shown)


## The shown hat (null when empty).
func get_item() -> CosmeticItem:
	return _item


## The shown hat's id, &"" when empty.
func get_item_id() -> StringName:
	return _item.id if _item != null else &""


func is_showing() -> bool:
	return _item != null and _overlay != null and _overlay.visible


## Moves to the current animation frame's head point. A missing anchor keeps the last good position.
func _follow() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: StringName = sprite.animation
	var frame: int = sprite.frame
	# AnimatedSprite2D emits animation_changed before it resets the frame, so for a moment the old index
	# may not exist in the new animation. Skip it quietly: the reset emits frame_changed right after.
	if sprite.sprite_frames.has_animation(anim) and frame >= sprite.sprite_frames.get_frame_count(anim):
		return
	if anchors == null:
		_warn_once("anchors", "hat slot: no anchors")
		return
	if not anchors.has_head(anim, frame):
		_warn_once("anchor:%s" % anim, "hat slot: no anchor for %s %d" % [anim, frame])
		return
	var point: Vector2 = anchors.get_head(anim, frame)
	_followed_flip = sprite.flip_h
	if sprite.flip_h:
		point.x = FRAME_W - point.x
	position = point
	if _overlay != null:
		_overlay.flip_h = sprite.flip_h
	Log.debug(&"cosmetics", "hat slot %s %d at %s" % [anim, frame, point])


func _show_equipped() -> void:
	if catalogue == null:
		_warn_once("catalogue", "hat slot: no catalogue")
		show_item(null)
		return
	var id: StringName = player_data.get_equipped(CosmeticItem.SLOT_HAT)
	var item: CosmeticItem = catalogue.get_item(id)
	if id != &"" and item == null:
		_warn_once("missing:%s" % id, "hat slot: %s not in catalogue" % id)
	show_item(item)


func _on_equipment_changed(slot: StringName, _item_id: StringName) -> void:
	if not follow_equipped or slot != CosmeticItem.SLOT_HAT:
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
