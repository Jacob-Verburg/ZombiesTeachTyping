class_name ProfessorZombie
extends Node2D
## Professor Zombie (Story 2.9): the player zombie in a cap and gown, pointing at the report card's
## chalkboard. Drawn at 1x sprite scale, soles on the node's local row 30.
## Story 4.3: the worn hat and pet fill the slots, and the mortarboard stacks on the hat (D16). %HatSlot
## (at the head point, top-centre of the crown) and %PetSlot (on the floor to his right) listen to
## PlayerData themselves; the professor only listens to the hat slot's item_shown and lifts the mortarboard
## by how far the hat reaches above the head point. No autoload but Log.

var _rise_cache: Dictionary[StringName, float] = {}

@onready var _mortarboard: Sprite2D = $Body/Mortarboard


func _ready() -> void:
	var body: AnimatedSprite2D = $Body
	if body.sprite_frames == null:
		Log.warn(&"ui", "professor zombie has no sprite frames")
		body.hide()
	var hat: HatSlot = %HatSlot
	hat.item_shown.connect(_stack_mortarboard)
	# The slot's own _ready already showed the worn hat, before this connection existed.
	_stack_mortarboard(hat.get_item())


## Rests the mortarboard on the hat's top row, or on the crown with no hat.
func _stack_mortarboard(item: CosmeticItem) -> void:
	_mortarboard.position.y = -_hat_rise(item)


## How far the hat reaches above the head point (its seat row minus its top opaque row); 0 with no hat.
## Cached per item id.
func _hat_rise(item: CosmeticItem) -> float:
	if item == null or item.overlay == null:
		return 0.0
	if _rise_cache.has(item.id):
		return _rise_cache[item.id]
	var rise: float = 0.0
	var image: Image = item.overlay.get_image()
	if image == null:
		Log.warn(&"ui", "professor: hat %s overlay has no image" % item.id)
	elif image.get_used_rect().size == Vector2i.ZERO:
		Log.warn(&"ui", "professor: hat %s overlay is empty" % item.id)
	else:
		rise = HatSlot.SEAT.y - image.get_used_rect().position.y
	_rise_cache[item.id] = rise
	return rise
