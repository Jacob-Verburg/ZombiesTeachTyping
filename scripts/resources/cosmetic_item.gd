class_name CosmeticItem
extends Resource
## One Crypt Closet item: a hat or a pet, its price and its art. The shipped items are
## data/cosmetics/<id>.tres, listed by data/cosmetics/catalogue.tres. Saves store the id, never the
## resource, so an id is permanent once shipped; display_name can change freely.
## The defaults here are neutral.

enum Slot { HAT, PET }

## The save's `equipped` keys. The only place the slot names live; they match SaveSchema.
const SLOT_HAT: StringName = &"hat"
const SLOT_PET: StringName = &"pet"

## Permanent id, e.g. &"hat_pumpkin". Hats start with hat_, pets with pet_.
@export var id: StringName
## The item's name as kids read it, e.g. "Pumpkin hat".
@export var display_name: String = ""
## Which slot the item is worn in.
@export var slot: Slot = Slot.HAT
## Price in brains (GDD: 100 / 200 / 300 by row).
@export var price: int = 0
## Grid row in the Closet, 1..3.
@export var row: int = 0
## False shows a "Coming soon" tile that can't be bought.
@export var is_available: bool = false
## The Closet tile picture.
@export var icon: Texture2D
## Hats: the picture drawn on the zombie's head.
@export var overlay: Texture2D
## Pets: the pet's animations.
@export var pet_frames: SpriteFrames


## The save's `equipped` key for this item's slot.
func slot_key() -> StringName:
	return SLOT_PET if slot == Slot.PET else SLOT_HAT


## True for a key of the save's `equipped` dictionary.
static func is_slot_key(key: StringName) -> bool:
	return key == SLOT_HAT or key == SLOT_PET
