class_name Catalogue
extends Resource
## Every Crypt Closet item (FR39, FR42). The shipped catalogue is data/cosmetics/catalogue.tres; ids
## must be unique there (validate() checks), and if two entries ever share an id the first one wins.

## The Closet grid per slot: GRID_SIZE items in GRID_COLUMNS columns (FR39's 3x3). Layout, not balance.
const GRID_SIZE: int = 9
const GRID_COLUMNS: int = 3
@warning_ignore("integer_division")
const ROWS: int = GRID_SIZE / GRID_COLUMNS

## Every item, each slot's items in grid order (row-major).
@export var items: Array[CosmeticItem] = []


## The item for `id`, or null when the id is unknown or empty.
func get_item(id: StringName) -> CosmeticItem:
	if id == &"":
		return null
	for item: CosmeticItem in items:
		if item != null and item.id == id:
			return item
	return null


## That slot's items in grid order: index 0..8 = row 1 col 1 .. row 3 col 3.
func items_for_slot(slot: CosmeticItem.Slot) -> Array[CosmeticItem]:
	var result: Array[CosmeticItem] = []
	for item: CosmeticItem in items:
		if item != null and item.slot == slot:
			result.append(item)
	return result


## Empty when the catalogue can fill the Closet; otherwise the first problem found.
func validate() -> String:
	var seen: Dictionary = {}
	for i: int in items.size():
		var item: CosmeticItem = items[i]
		if item == null:
			return "item %d is null" % i
		if item.id == &"":
			return "item %d has an empty id" % i
		if seen.has(item.id):
			return "duplicate id %s" % item.id
		seen[item.id] = true
		var prefix: String = "pet_" if item.slot == CosmeticItem.Slot.PET else "hat_"
		if not String(item.id).begins_with(prefix):
			return "id %s must start with %s" % [item.id, prefix]
		if item.row < 1 or item.row > ROWS:
			return "id %s row must be within 1..%d" % [item.id, ROWS]
		if item.price <= 0:
			return "id %s price must be above 0" % item.id
	for slot: CosmeticItem.Slot in [CosmeticItem.Slot.HAT, CosmeticItem.Slot.PET]:
		var grid: Array[CosmeticItem] = items_for_slot(slot)
		var slot_name: String = CosmeticItem.Slot.keys()[slot]
		if grid.size() != GRID_SIZE:
			return "slot %s needs exactly %d items, has %d" % [slot_name, GRID_SIZE, grid.size()]
		for index: int in grid.size():
			@warning_ignore("integer_division")
			if grid[index].row != index / GRID_COLUMNS + 1:
				return "id %s is out of grid order" % grid[index].id
	return ""
