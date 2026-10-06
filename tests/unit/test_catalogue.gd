extends GutTest
## Catalogue lookups and validate() on code-built catalogues, plus the shipped catalogue.tres and
## economy.tres. The GDD table is written out literally here: this test is the guard on the data.

const CATALOGUE_PATH: String = "res://data/cosmetics/catalogue.tres"
const ECONOMY_PATH: String = "res://data/economy.tres"
const HAT_IDS: Array[StringName] = [
	&"hat_pumpkin", &"hat_witch", &"hat_bunny_ears",
	&"hat_santa", &"hat_leprechaun", &"hat_heart_headband",
	&"hat_top_hat", &"hat_pirate", &"hat_crown",
]
const PET_IDS: Array[StringName] = [
	&"pet_cute_ghost", &"pet_black_cat", &"pet_spider",
	&"pet_orange_cat", &"pet_bat", &"pet_crow",
	&"pet_wolf_dog", &"pet_eyeball", &"pet_brain_buddy",
]
const ROW_PRICES: Array[int] = [100, 200, 300]


func _item(id: StringName, slot: CosmeticItem.Slot, row: int, price: int = 100) -> CosmeticItem:
	var item: CosmeticItem = CosmeticItem.new()
	item.id = id
	item.slot = slot
	item.row = row
	item.price = price
	return item


## A sound catalogue: 9 hats then 9 pets, rows 1..3 in grid order.
@warning_ignore("integer_division")
func _valid() -> Catalogue:
	var catalogue: Catalogue = Catalogue.new()
	for i: int in 9:
		catalogue.items.append(_item(StringName("hat_%d" % i), CosmeticItem.Slot.HAT, i / 3 + 1))
	for i: int in 9:
		catalogue.items.append(_item(StringName("pet_%d" % i), CosmeticItem.Slot.PET, i / 3 + 1))
	return catalogue


# --- lookups --------------------------------------------------------------------

func test_get_item_finds_known_id() -> void:
	var catalogue: Catalogue = _valid()
	assert_eq(catalogue.get_item(&"pet_4"), catalogue.items[13])


func test_get_item_unknown_or_empty_is_null() -> void:
	var catalogue: Catalogue = _valid()
	assert_null(catalogue.get_item(&"hat_nope"))
	assert_null(catalogue.get_item(&""))


func test_get_item_skips_null_entries() -> void:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(null)
	catalogue.items.append(_item(&"hat_a", CosmeticItem.Slot.HAT, 1))
	assert_eq(catalogue.get_item(&"hat_a"), catalogue.items[1])
	assert_null(catalogue.get_item(&"hat_b"))


func test_get_item_first_duplicate_wins() -> void:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(_item(&"hat_a", CosmeticItem.Slot.HAT, 1, 100))
	catalogue.items.append(_item(&"hat_a", CosmeticItem.Slot.HAT, 1, 200))
	assert_eq(catalogue.get_item(&"hat_a").price, 100)


func test_items_for_slot_keeps_grid_order() -> void:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(_item(&"pet_a", CosmeticItem.Slot.PET, 1))
	catalogue.items.append(_item(&"hat_a", CosmeticItem.Slot.HAT, 1))
	catalogue.items.append(null)
	catalogue.items.append(_item(&"pet_b", CosmeticItem.Slot.PET, 1))
	catalogue.items.append(_item(&"hat_b", CosmeticItem.Slot.HAT, 1))
	var hats: Array[StringName] = []
	for item: CosmeticItem in catalogue.items_for_slot(CosmeticItem.Slot.HAT):
		hats.append(item.id)
	var pets: Array[StringName] = []
	for item: CosmeticItem in catalogue.items_for_slot(CosmeticItem.Slot.PET):
		pets.append(item.id)
	assert_eq(hats, [&"hat_a", &"hat_b"] as Array[StringName])
	assert_eq(pets, [&"pet_a", &"pet_b"] as Array[StringName])


func test_slot_key_and_is_slot_key() -> void:
	assert_eq(_item(&"hat_a", CosmeticItem.Slot.HAT, 1).slot_key(), &"hat")
	assert_eq(_item(&"pet_a", CosmeticItem.Slot.PET, 1).slot_key(), &"pet")
	assert_true(CosmeticItem.is_slot_key(&"hat"))
	assert_true(CosmeticItem.is_slot_key(&"pet"))
	assert_false(CosmeticItem.is_slot_key(&"shoes"))
	assert_false(CosmeticItem.is_slot_key(&""))


func test_slot_keys_match_the_save_schema() -> void:
	var keys: Array = SaveSchema.profile_defaults()["equipped"].keys()
	keys.sort()
	assert_eq(keys, [String(CosmeticItem.SLOT_HAT), String(CosmeticItem.SLOT_PET)])


func test_cosmetic_item_defaults_are_neutral() -> void:
	var item: CosmeticItem = CosmeticItem.new()
	assert_eq(item.price, 0)
	assert_eq(item.row, 0)
	assert_false(item.is_available)
	assert_eq(item.id, &"")
	assert_null(item.icon)
	assert_null(item.overlay)
	assert_null(item.pet_frames)
	assert_eq(EconomyConfig.new().welcome_bonus, 0)


# --- validate() -----------------------------------------------------------------

func test_validate_sound_catalogue() -> void:
	assert_eq(_valid().validate(), "")


func test_validate_null_item() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[3] = null
	assert_string_contains(catalogue.validate(), "null")


func test_validate_empty_id() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[2].id = &""
	assert_string_contains(catalogue.validate(), "empty id")


func test_validate_duplicate_id() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[1].id = &"hat_0"
	assert_string_contains(catalogue.validate(), "duplicate")


func test_validate_id_prefix_must_match_slot() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[0].id = &"pet_x"
	assert_string_contains(catalogue.validate(), "must start with hat_")
	catalogue = _valid()
	catalogue.items[9].id = &"hat_x"
	assert_string_contains(catalogue.validate(), "must start with pet_")


func test_validate_row_out_of_range() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[0].row = 0
	assert_string_contains(catalogue.validate(), "row")
	catalogue = _valid()
	catalogue.items[8].row = 4
	assert_string_contains(catalogue.validate(), "row")


func test_validate_price_must_be_positive() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[4].price = 0
	assert_string_contains(catalogue.validate(), "price")
	catalogue = _valid()
	catalogue.items[4].price = -100
	assert_string_contains(catalogue.validate(), "price")


func test_validate_slot_needs_exactly_nine() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items.remove_at(17)
	assert_string_contains(catalogue.validate(), "exactly 9")
	catalogue = _valid()
	catalogue.items.append(_item(&"hat_extra", CosmeticItem.Slot.HAT, 3))
	assert_string_contains(catalogue.validate(), "exactly 9")


func test_validate_rows_must_be_in_grid_order() -> void:
	var catalogue: Catalogue = _valid()
	catalogue.items[2].row = 2
	catalogue.items[3].row = 1
	assert_string_contains(catalogue.validate(), "grid order")


# --- shipped data ---------------------------------------------------------------

func _shipped() -> Catalogue:
	var catalogue: Variant = load(CATALOGUE_PATH)
	assert_true(catalogue is Catalogue, "catalogue.tres is a Catalogue")
	return catalogue as Catalogue


func test_shipped_catalogue_validates() -> void:
	assert_eq(_shipped().validate(), "")
	assert_eq(_shipped().items.size(), 18)


@warning_ignore("integer_division")
func _check_slot(slot: CosmeticItem.Slot, expected_ids: Array[StringName]) -> void:
	var grid: Array[CosmeticItem] = _shipped().items_for_slot(slot)
	assert_eq(grid.size(), expected_ids.size())
	for i: int in grid.size():
		var item: CosmeticItem = grid[i]
		assert_eq(item.id, expected_ids[i], "index %d id" % i)
		assert_eq(item.row, i / 3 + 1, "%s row" % item.id)
		assert_eq(item.price, ROW_PRICES[i / 3], "%s price" % item.id)
		assert_ne(item.display_name, "", "%s has a name" % item.id)


func test_shipped_hats_in_grid_order_with_row_prices() -> void:
	_check_slot(CosmeticItem.Slot.HAT, HAT_IDS)


func test_shipped_pets_in_grid_order_with_row_prices() -> void:
	_check_slot(CosmeticItem.Slot.PET, PET_IDS)


func test_shipped_hats_come_before_pets() -> void:
	var ids: Array[StringName] = []
	for item: CosmeticItem in _shipped().items:
		ids.append(item.id)
	assert_eq(ids, HAT_IDS + PET_IDS)


func test_shipped_only_mvp_items_are_available() -> void:
	var available: Array[StringName] = []
	for item: CosmeticItem in _shipped().items:
		if item.is_available:
			available.append(item.id)
	assert_eq(available, [&"hat_pumpkin", &"pet_cute_ghost"] as Array[StringName])


func test_shipped_full_set_costs_3600() -> void:
	var total: int = 0
	for item: CosmeticItem in _shipped().items:
		total += item.price
	assert_eq(total, 3600)


func test_shipped_display_names() -> void:
	assert_eq(_shipped().get_item(&"hat_pumpkin").display_name, "Pumpkin hat")
	assert_eq(_shipped().get_item(&"pet_cute_ghost").display_name, "Cute ghost")


func test_shipped_economy_config() -> void:
	var economy: Variant = load(ECONOMY_PATH)
	assert_true(economy is EconomyConfig, "economy.tres is an EconomyConfig")
	assert_eq((economy as EconomyConfig).welcome_bonus, 100)


## Story 4.3: the MVP items carry their art; the Epic 9 items still have none. icon stays empty (4.4).
func test_shipped_mvp_items_have_art() -> void:
	var catalogue: Catalogue = _shipped()
	var hat: CosmeticItem = catalogue.get_item(&"hat_pumpkin")
	assert_not_null(hat.overlay, "the pumpkin hat has an overlay")
	assert_eq(hat.overlay.get_size(), Vector2(32, 32))
	var pet: CosmeticItem = catalogue.get_item(&"pet_cute_ghost")
	assert_not_null(pet.pet_frames, "the cute ghost has pet frames")
	assert_true(pet.pet_frames.has_animation(&"idle"))
	for item: CosmeticItem in catalogue.items:
		assert_null(item.icon, "%s icon is Story 4.4" % item.id)
		if not item.is_available:
			assert_null(item.overlay, "%s has no art yet (Epic 9)" % item.id)
			assert_null(item.pet_frames, "%s has no art yet (Epic 9)" % item.id)
