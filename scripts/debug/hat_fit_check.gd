class_name HatFitCheck
extends Control
## Hat & pet fit check (Story 4.3, the cosmetics gate). Dev/Smuck only (Boundary 7): never routed to,
## never instanced by the Router, no menu button. Run it directly:
##   "/c/Program Files/Godot/Godot.exe" --path . res://scenes/debug/hat_fit_check.tscn
## Shows the chosen hat on every frame of every player-zombie animation (idle, walk, hop, hug, dance, and
## Story 6.6's flash and melt) and
## on both Professor Zombie frames (the real professor scene, so the mortarboard stacks on the hat), each
## at 1x and 3x on a stopped sprite, PAGE_SIZE cells per page. Below: the chosen pet's idle on a HUD-size
## parchment cushion at 1x, and at 3x beside it. Every slot here has follow_equipped = false and shows only
## what this scene gives it.
## Keys: H cycles the hat (every catalogue hat with an overlay, then none), P the pet the same way, B the
## background (the places a hat appears), N the page, Esc quits. E wears for real: it gives the live
## PlayerData each shown item's price, buys it (unless owned) and equips it, or unequips a "none" slot. The
## only way to wear something before the Crypt Closet (4.4); it lives here because this scene is debug-only.
## F3/F5/F8/F9 are left alone (the debug overlay owns them).
## Seams (tests assign them before add_child): player_data and the exported catalogue.

const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const PLAYER_ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
const PROFESSOR_SCENE: PackedScene = preload("res://scenes/characters/professor_zombie.tscn")
const HAT_SLOT_SCENE: PackedScene = preload("res://scenes/cosmetics/hat_slot.tscn")
const PET_SLOT_SCENE: PackedScene = preload("res://scenes/cosmetics/pet_slot.tscn")
const ZOMBIE_ANCHORS: SpriteAnchors = preload("res://data/anchors/zombie_anchors.tres")
## The player zombie's animations in show order.
const ZOMBIE_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"hop", &"hug", &"dance", &"flash", &"melt"]
const PROFESSOR_ANIMATION: StringName = &"point"
const FRAME: int = 32
const DETAIL_SCALE: int = 3
## [name, background, text color]; the places a hat appears (palette colors only).
const BACKGROUNDS: Array[Array] = [
	["night", Color("#2b1d3f"), Color("#f4f1e4")],
	["art-sky", Color("#7ec8e3"), Color("#1e1428")],
	["chalkboard", Color("#24402f"), Color("#f4f1e4")],
	["parchment", Color("#f6e7c1"), Color("#1e1428")],
]
const CUSHION_COLOR: Color = Color("#f6e7c1")
const CUSHION_BORDER: Color = Color("#1e1428")
## Layout (viewport px). A page is PAGE_SIZE columns: the label, the 1x cell, the 3x cell below it.
const PAGE_SIZE: int = 5
const MARGIN: int = 8
const COLUMN: int = 124
const LABEL_Y: int = 8
const CELL_1X_Y: int = 40
const CELL_3X_Y: int = 120
const FONT_SIZE: int = 16
## The HUD cushion (48x48) and where a pet's feet sit on it (as on the HUD: (32, 80) in a slot whose
## cushion starts at (8, 44)).
const CUSHION_RECT: Rect2 = Rect2(16, 232, 48, 48)
const CUSHION_FEET: Vector2 = Vector2(24, 36)
const PET_3X_FEET: Vector2 = Vector2(176, 296)
const FOOTER_Y: int = 300
const FOOTER_STEP: int = 20

## Hats and pets to cycle through (data/cosmetics/catalogue.tres, set in the scene).
@export var catalogue: Catalogue

## Test seam: defaults to the PlayerData autoload in _ready. Only E touches it.
var player_data: PlayerDataScript = null

## Every cell's stopped sprite (both scales, page order).
var _cells: Array[AnimatedSprite2D] = []
var _hat_slots: Array[HatSlot] = []
var _pet_slots: Array[PetSlot] = []
var _pages: Array[Control] = []
var _page_index: int = 0
var _labels: Array[Label] = []
var _footer: Array[Label] = []
## The cycle lists; null is "none" (always last).
var _hats: Array[CosmeticItem] = []
var _pets: Array[CosmeticItem] = []
var _hat_index: int = 0
var _pet_index: int = 0
var _background_index: int = 0


func _ready() -> void:
	if player_data == null:
		player_data = PlayerData
	_hats = _with_art(CosmeticItem.Slot.HAT)
	_pets = _with_art(CosmeticItem.Slot.PET)
	_build_cells()
	_build_pet()
	for i: int in 3:
		_footer.append(_add_label("", Vector2(MARGIN, FOOTER_Y + i * FOOTER_STEP), self))
	_show_hat()
	_show_pet()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_H:
			cycle_hat()
		KEY_P:
			cycle_pet()
		KEY_B:
			cycle_background()
		KEY_N:
			next_page()
		KEY_E:
			wear_for_real()
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			get_tree().quit()
			return
		_:
			return
	get_viewport().set_input_as_handled()


## Every cell's sprite, both scales, in page order.
func get_cells() -> Array[AnimatedSprite2D]:
	return _cells


func get_hat_slots() -> Array[HatSlot]:
	return _hat_slots


func get_pet_slots() -> Array[PetSlot]:
	return _pet_slots


## The shown hat (null = none).
func current_hat() -> CosmeticItem:
	return _hats[_hat_index]


## The shown pet (null = none).
func current_pet() -> CosmeticItem:
	return _pets[_pet_index]


func background_name() -> String:
	return BACKGROUNDS[_background_index][0]


func page_count() -> int:
	return _pages.size()


func cycle_hat() -> void:
	_hat_index = (_hat_index + 1) % _hats.size()
	_show_hat()
	_refresh()


func cycle_pet() -> void:
	_pet_index = (_pet_index + 1) % _pets.size()
	_show_pet()
	_refresh()


func cycle_background() -> void:
	_background_index = (_background_index + 1) % BACKGROUNDS.size()
	_refresh()


func next_page() -> void:
	if _pages.is_empty():
		return
	_page_index = (_page_index + 1) % _pages.size()
	for i: int in _pages.size():
		_pages[i].visible = i == _page_index
	_refresh()


## Wears the shown hat and pet on the live profile: brains for the price, buy (unless owned), equip; a
## "none" slot is unequipped.
func wear_for_real() -> void:
	_wear(CosmeticItem.SLOT_HAT, current_hat())
	_wear(CosmeticItem.SLOT_PET, current_pet())
	Log.info(&"cosmetics", "fit check: wearing hat=%s pet=%s" % [_item_name(current_hat()), _item_name(current_pet())])


func _wear(slot: StringName, item: CosmeticItem) -> void:
	if item == null:
		player_data.unequip(slot)
		return
	if not player_data.owns(item.id):
		player_data.add_brains(item.price)
		var result: PlayerDataScript.PurchaseResult = player_data.buy_item(item)
		if result != PlayerDataScript.PurchaseResult.OK:
			Log.warn(&"cosmetics", "fit check: could not buy %s (%d)" % [item.id, result])
			return
	player_data.equip(item.id)


## The slot's catalogue items that have their art, then null ("none").
func _with_art(slot: CosmeticItem.Slot) -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	if catalogue != null:
		for item: CosmeticItem in catalogue.items_for_slot(slot):
			var has_art: bool = item.overlay != null if slot == CosmeticItem.Slot.HAT else item.pet_frames != null
			if has_art:
				result.append(item)
	result.append(null)
	return result


func _build_cells() -> void:
	var zombie: PlayerZombie = PLAYER_ZOMBIE_SCENE.instantiate() as PlayerZombie
	var zombie_frames: SpriteFrames = (zombie.get_node("Body") as AnimatedSprite2D).sprite_frames
	zombie.free()
	var specs: Array[Array] = []
	if zombie_frames != null:
		for anim: StringName in ZOMBIE_ANIMATIONS:
			if not zombie_frames.has_animation(anim):
				continue
			for frame: int in zombie_frames.get_frame_count(anim):
				specs.append([anim, frame, false])
	for frame: int in 2:
		specs.append([PROFESSOR_ANIMATION, frame, true])
	for i: int in specs.size():
		if i % PAGE_SIZE == 0:
			var page: Control = Control.new()
			page.mouse_filter = Control.MOUSE_FILTER_IGNORE
			page.visible = _pages.is_empty()
			add_child(page)
			_pages.append(page)
		var page_node: Control = _pages.back()
		var anim: StringName = specs[i][0]
		var frame: int = specs[i][1]
		var x: float = MARGIN + (i % PAGE_SIZE) * COLUMN
		_add_label("%s %d" % [anim, frame], Vector2(x, LABEL_Y), page_node)
		for scale_factor: int in [1, DETAIL_SCALE]:
			var holder: Node2D = Node2D.new()
			holder.position = Vector2(x, CELL_1X_Y if scale_factor == 1 else CELL_3X_Y)
			holder.scale = Vector2(scale_factor, scale_factor)
			if specs[i][2]:
				_add_professor_cell(holder, frame)
			else:
				_add_zombie_cell(holder, zombie_frames, anim, frame)
			page_node.add_child(holder)


## A stopped player-zombie sprite with a hat slot, set up before add_child.
func _add_zombie_cell(holder: Node2D, frames: SpriteFrames, anim: StringName, frame: int) -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.centered = false
	sprite.sprite_frames = frames
	sprite.animation = anim
	sprite.frame = frame
	var slot: HatSlot = HAT_SLOT_SCENE.instantiate() as HatSlot
	slot.follow_equipped = false
	slot.sprite = sprite
	slot.anchors = ZOMBIE_ANCHORS
	sprite.add_child(slot)
	holder.add_child(sprite)
	_cells.append(sprite)
	_hat_slots.append(slot)


## The real Professor Zombie scene (his mortarboard stacks on the hat), stopped on `frame`, slots detached
## from PlayerData and his pet hidden.
func _add_professor_cell(holder: Node2D, frame: int) -> void:
	var professor: ProfessorZombie = PROFESSOR_SCENE.instantiate() as ProfessorZombie
	var body: AnimatedSprite2D = professor.get_node("Body")
	body.autoplay = ""
	body.animation = PROFESSOR_ANIMATION
	body.frame = frame
	var slot: HatSlot = professor.get_node("%HatSlot")
	slot.follow_equipped = false
	var pet: PetSlot = professor.get_node("%PetSlot")
	pet.follow_equipped = false
	holder.add_child(professor)
	_cells.append(body)
	_hat_slots.append(slot)


func _build_pet() -> void:
	var cushion: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = CUSHION_COLOR
	box.border_color = CUSHION_BORDER
	box.set_border_width_all(1)
	cushion.add_theme_stylebox_override("panel", box)
	cushion.position = CUSHION_RECT.position
	cushion.size = CUSHION_RECT.size
	cushion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cushion)
	for scale_factor: int in [1, DETAIL_SCALE]:
		var slot: PetSlot = PET_SLOT_SCENE.instantiate() as PetSlot
		slot.follow_equipped = false
		slot.position = CUSHION_RECT.position + CUSHION_FEET if scale_factor == 1 else PET_3X_FEET
		slot.scale = Vector2(scale_factor, scale_factor)
		add_child(slot)
		_pet_slots.append(slot)


func _show_hat() -> void:
	for slot: HatSlot in _hat_slots:
		slot.show_item(current_hat())


func _show_pet() -> void:
	for slot: PetSlot in _pet_slots:
		slot.show_item(current_pet())


func _refresh() -> void:
	%Background.color = BACKGROUNDS[_background_index][1]
	var text_color: Color = BACKGROUNDS[_background_index][2]
	for label: Label in _labels:
		label.add_theme_color_override("font_color", text_color)
	_footer[0].text = "hat %s  pet %s" % [_item_name(current_hat()), _item_name(current_pet())]
	_footer[1].text = "bg %s  page %d/%d" % [background_name(), _page_index + 1, _pages.size()]
	_footer[2].text = "E = wear for real  H P B N Esc"


func _item_name(item: CosmeticItem) -> String:
	return "none" if item == null else item.display_name


func _add_label(text: String, at: Vector2, parent: Node) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(label)
	_labels.append(label)
	return label
