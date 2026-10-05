extends GutTest
## PlayerData: brains, settings, wallet, inventory, equipment and flag mutations, their signals, coalesced
## save requests, live profile reads.
## Always a fresh SaveService (save_dir = TEST_DIR) and a fresh PlayerData wired to it through the
## save_service seam before add_child. The live autoloads are only read, so the real save is never touched.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_player_data/"
const FULL_PATH: String = "res://tests/fixtures/saves/save_v1_full.json"

var _save: SaveServiceScript = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()


func after_each() -> void:
	_clear()
	_save = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make() -> PlayerDataScript:
	_save = SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	add_child_autofree(sut)
	return sut


func _put_fixture(path: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join("save.json"), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(path))
	file.close()


func _written_profile() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR.path_join("save.json")))
	return data["profiles"][data["active_profile"]]


func test_get_brains_reads_loaded_save() -> void:
	_put_fixture(FULL_PATH)
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_brains(), 340)
	assert_false(sut.get_setting(&"music_on"))
	assert_true(sut.get_setting(&"sound_on"))


func test_fresh_save_defaults() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_brains(), 0)
	assert_true(sut.get_setting(&"music_on"))
	assert_true(sut.get_setting(&"sound_on"))


func test_add_brains_updates_total_and_emits() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	sut.add_brains(5)
	sut.add_brains(3)
	assert_eq(sut.get_brains(), 8)
	assert_signal_emit_count(sut, "brains_changed", 2)
	assert_signal_emitted_with_parameters(sut, "brains_changed", [8, 3])
	assert_eq(int(_save.get_active_profile()["brains"]), 8, "writes into the save's own dictionary")


func test_add_brains_requests_one_coalesced_save() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(_save)
	sut.add_brains(1)
	sut.add_brains(1)
	sut.add_brains(1)
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq(int(_written_profile()["brains"]), 3)


func test_add_brains_zero_is_a_noop() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	watch_signals(_save)
	sut.add_brains(0)
	await wait_process_frames(2)
	assert_eq(sut.get_brains(), 0)
	assert_signal_not_emitted(sut, "brains_changed")
	assert_signal_not_emitted(_save, "save_written")


func test_add_brains_negative_is_rejected() -> void:
	var sut: PlayerDataScript = _make()
	sut.add_brains(4)
	watch_signals(sut)
	sut.add_brains(-5)
	assert_push_error("negative")
	assert_eq(sut.get_brains(), 4)
	assert_signal_not_emitted(sut, "brains_changed")


func test_set_setting_changes_value_emits_and_saves() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	watch_signals(_save)
	sut.set_setting(&"music_on", false)
	assert_false(sut.get_setting(&"music_on"))
	assert_signal_emit_count(sut, "settings_changed", 1)
	assert_signal_emitted_with_parameters(sut, "settings_changed", [&"music_on", false])
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_false(_written_profile()["settings"]["music_on"])


func test_set_setting_writes_string_key() -> void:
	var sut: PlayerDataScript = _make()
	sut.set_setting(&"sound_on", false)
	var settings: Dictionary = _save.get_active_profile()["settings"]
	assert_eq(settings.keys().count("sound_on"), 1, "one sound_on key")
	assert_eq(settings.size(), SaveSchema.profile_defaults()["settings"].size(), "no extra key")
	for key: Variant in settings.keys():
		assert_eq(typeof(key), TYPE_STRING, "key %s is a String" % str(key))
	assert_false(settings["sound_on"])


func test_set_setting_same_value_is_a_noop() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	watch_signals(_save)
	sut.set_setting(&"music_on", true)
	await wait_process_frames(2)
	assert_signal_not_emitted(sut, "settings_changed")
	assert_signal_not_emitted(_save, "save_written")


func test_set_setting_unknown_key_is_rejected() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	sut.set_setting(&"volume", true)
	assert_push_error("unknown setting")
	assert_false(_save.get_active_profile()["settings"].has("volume"))
	assert_signal_not_emitted(sut, "settings_changed")
	assert_false(sut.get_setting(&"volume"))
	assert_push_error("unknown setting", "get_setting logs too")


func test_profile_is_read_live() -> void:
	var sut: PlayerDataScript = _make()
	_save.get_active_profile()["brains"] = 77
	assert_eq(sut.get_brains(), 77)
	_save._data = SaveSchema.defaults()
	assert_eq(sut.get_brains(), 0, "follows a replaced save without re-creating PlayerData")
	sut.add_brains(2)
	assert_eq(int(_save.get_active_profile()["brains"]), 2)


func test_uses_live_save_service_by_default() -> void:
	var sut: PlayerDataScript = PlayerDataScript.new()
	add_child_autofree(sut)
	assert_eq(sut.save_service, SaveService)


func test_reset_all_returns_to_defaults_and_emits() -> void:
	var sut: PlayerDataScript = _make()
	sut.add_brains(5)
	sut.set_setting(&"music_on", false)
	await wait_process_frames(2)
	watch_signals(sut)
	watch_signals(_save)
	sut.reset_all()
	assert_eq(sut.get_brains(), 0)
	assert_true(sut.get_setting(&"music_on"))
	assert_signal_emit_count(sut, "profile_replaced", 1)
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq(int(_written_profile()["brains"]), 0)


func test_reset_all_emits_no_delta_signals() -> void:
	var sut: PlayerDataScript = _make()
	sut.add_brains(5)
	watch_signals(sut)
	sut.reset_all()
	assert_signal_not_emitted(sut, "brains_changed")
	assert_signal_not_emitted(sut, "settings_changed")


# --- record_run (Story 2.8) ----------------------------------------------------

## A run of `keys` correct keys in 60 s: WPM = keys / 5 (letter mode), so keys 50 -> 10 WPM.
func _result(level: StringName, keys: int, brains: int = 0, bonus: int = 0) -> RunResult:
	return RunResult.create(
		level, 1000, 60.0, keys, 0, {"a": [keys, 0, {}]}, brains, bonus, "all",
		GameConstants.END_REASON_TIMER)


func _history() -> Array:
	return _save.get_active_profile()["run_history"]


func _best() -> Dictionary:
	return _save.get_active_profile()["best_wpm"]


func test_record_run_appends_the_record() -> void:
	var sut: PlayerDataScript = _make()
	var result: RunResult = _result(&"zombie_run", 50, 2)
	sut.record_run(result)
	assert_eq(_history().size(), 1)
	assert_eq(_history()[0], result.to_record())


func test_record_run_adds_level_and_bonus_brains_with_one_signal() -> void:
	var sut: PlayerDataScript = _make()
	sut.add_brains(5)
	watch_signals(sut)
	sut.record_run(_result(&"zombie_run", 50, 3, 10))
	assert_eq(sut.get_brains(), 18)
	assert_signal_emit_count(sut, "brains_changed", 1)
	assert_signal_emitted_with_parameters(sut, "brains_changed", [18, 13])


func test_record_run_with_no_brains_adds_none_and_emits_none() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	sut.record_run(_result(&"zombie_run", 50, 0, 0))
	assert_eq(sut.get_brains(), 0)
	assert_signal_not_emitted(sut, "brains_changed")


## A SaveService that counts request_save() calls (the real one coalesces them).
class CountingSave extends SaveServiceScript:
	var requests: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()


func test_record_run_requests_exactly_one_save() -> void:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	add_child_autofree(sut)
	watch_signals(_save)
	sut.record_run(_result(&"zombie_run", 50, 4))
	assert_eq((_save as CountingSave).requests, 1)
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq(int(_written_profile()["brains"]), 4)
	assert_eq(_written_profile()["run_history"].size(), 1)


func test_history_keeps_the_newest_500() -> void:
	var sut: PlayerDataScript = _make()
	for i: int in GameConstants.RUN_HISTORY_CAP + 1:
		sut.record_run(RunResult.create(
			&"zombie_run", i, 60.0, 50, 0, {}, 0, 0, "all", GameConstants.END_REASON_TIMER))
	assert_eq(_history().size(), GameConstants.RUN_HISTORY_CAP)
	assert_eq(int(_history()[0]["timestamp"]), 1, "the oldest run was dropped")
	assert_eq(int(_history()[-1]["timestamp"]), GameConstants.RUN_HISTORY_CAP, "the newest is last")


func test_first_run_sets_the_best_but_is_not_a_new_best() -> void:
	var sut: PlayerDataScript = _make()
	assert_false(sut.record_run(_result(&"zombie_run", 50)))
	assert_eq(int(_best()["zombie_run"]), 10)


func test_higher_wpm_is_a_new_best() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_result(&"zombie_run", 50))
	assert_true(sut.record_run(_result(&"zombie_run", 100)))
	assert_eq(int(_best()["zombie_run"]), 20)


func test_equal_and_lower_wpm_change_nothing() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_result(&"zombie_run", 100))
	assert_false(sut.record_run(_result(&"zombie_run", 100)), "equal")
	assert_false(sut.record_run(_result(&"zombie_run", 50)), "lower")
	assert_eq(int(_best()["zombie_run"]), 20)


func test_level_without_a_best_entry_is_a_first_run() -> void:
	var sut: PlayerDataScript = _make()
	assert_false(_best().has("horde_rush"))
	assert_false(sut.record_run(_result(&"horde_rush", 50)))
	assert_eq(int(_best()["horde_rush"]), 10)
	assert_eq(int(_best()["zombie_run"]), 0, "other levels are untouched")
	assert_true(sut.record_run(_result(&"horde_rush", 100)))


func test_first_run_with_zero_wpm_stores_no_best() -> void:
	var sut: PlayerDataScript = _make()
	assert_false(sut.record_run(_result(&"zombie_run", 0)))
	assert_eq(int(_best()["zombie_run"]), 0)
	assert_false(sut.record_run(_result(&"zombie_run", 50)), "still counts as a first run")
	assert_eq(int(_best()["zombie_run"]), 10)


func test_record_run_emits_run_recorded_with_the_answer() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	sut.record_run(_result(&"zombie_run", 50))
	assert_signal_emitted_with_parameters(sut, "run_recorded", [&"zombie_run", false])
	sut.record_run(_result(&"zombie_run", 100))
	assert_signal_emitted_with_parameters(sut, "run_recorded", [&"zombie_run", true])
	assert_signal_emit_count(sut, "run_recorded", 2)


func test_record_run_null_changes_nothing() -> void:
	var sut: PlayerDataScript = _make()
	watch_signals(sut)
	watch_signals(_save)
	assert_false(sut.record_run(null))
	assert_push_error("record_run")
	assert_eq(_history().size(), 0)
	assert_signal_not_emitted(sut, "run_recorded")
	await wait_process_frames(2)
	assert_signal_not_emitted(_save, "save_written")

func test_oversized_loaded_history_is_trimmed_to_the_newest_500() -> void:
	var sut: PlayerDataScript = _make()
	var loaded: Array = []
	for i: int in GameConstants.RUN_HISTORY_CAP + 300:
		loaded.append({"timestamp": i})
	_save.get_active_profile()["run_history"] = loaded
	sut.record_run(_result(&"zombie_run", 50))
	assert_eq(_history().size(), GameConstants.RUN_HISTORY_CAP)
	assert_eq(int(_history()[0]["timestamp"]), 301, "only the newest kept")
	assert_eq(int(_history()[-1]["timestamp"]), 1000, "the new run is last")


func test_non_numeric_or_negative_best_counts_as_no_best() -> void:
	var sut: PlayerDataScript = _make()
	_best()["horde_rush"] = null
	_best()["zombie_run"] = -5
	_best()["pitchfork_panic"] = {"wpm": 30}
	watch_signals(sut)
	assert_false(sut.record_run(_result(&"horde_rush", 50, 2)))
	assert_false(sut.record_run(_result(&"zombie_run", 50)))
	assert_false(sut.record_run(_result(&"pitchfork_panic", 50)))
	assert_eq(int(_best()["horde_rush"]), 10)
	assert_eq(int(_best()["zombie_run"]), 10)
	assert_eq(int(_best()["pitchfork_panic"]), 10)
	assert_eq(sut.get_brains(), 2, "the run finished: brains added")
	assert_signal_emit_count(sut, "run_recorded", 3)


# --- wallet, inventory, equipment, flags (Story 4.1) ---------------------------

const HAT_PRICE: int = 30
const HAT2_PRICE: int = 45
const PET_PRICE: int = 20
const LOCKED_PRICE: int = 10


func _cosmetic(id: StringName, slot: CosmeticItem.Slot, price: int, available: bool) -> CosmeticItem:
	var item: CosmeticItem = CosmeticItem.new()
	item.id = id
	item.slot = slot
	item.price = price
	item.row = 1
	item.is_available = available
	return item


## Test prices, not the shipped ones; includes the fixture save's ids.
func _test_catalogue() -> Catalogue:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(_cosmetic(&"hat_pumpkin", CosmeticItem.Slot.HAT, HAT_PRICE, true))
	catalogue.items.append(_cosmetic(&"hat_witch", CosmeticItem.Slot.HAT, HAT2_PRICE, true))
	catalogue.items.append(_cosmetic(&"hat_crown", CosmeticItem.Slot.HAT, LOCKED_PRICE, false))
	catalogue.items.append(_cosmetic(&"pet_cute_ghost", CosmeticItem.Slot.PET, PET_PRICE, true))
	return catalogue


## A PlayerData on the test catalogue holding `brains`; `counting` swaps in CountingSave.
func _make_shop(brains: int = 0, counting: bool = false) -> PlayerDataScript:
	_save = CountingSave.new() if counting else SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	sut.catalogue = _test_catalogue()
	add_child_autofree(sut)
	_save.get_active_profile()["brains"] = brains
	return sut


func _item_of(sut: PlayerDataScript, id: StringName) -> CosmeticItem:
	return sut.catalogue.get_item(id)


func _owned_raw() -> Array:
	return _save.get_active_profile()["owned_items"]


func _equipped_raw() -> Dictionary:
	return _save.get_active_profile()["equipped"]


## After a rejected call: nothing changed, no signal and no save.
func _assert_untouched(sut: PlayerDataScript, brains: int, owned: Array) -> void:
	assert_eq(sut.get_brains(), brains, "brains unchanged")
	assert_eq(_owned_raw(), owned, "owned unchanged")
	assert_signal_not_emitted(sut, "brains_changed")
	assert_signal_not_emitted(sut, "inventory_changed")
	await wait_process_frames(2)
	assert_signal_not_emitted(_save, "save_written")


func test_uses_shipped_catalogue_by_default() -> void:
	var sut: PlayerDataScript = PlayerDataScript.new()
	add_child_autofree(sut)
	assert_eq(sut.catalogue, load("res://data/cosmetics/catalogue.tres"))


func test_buy_ok_deducts_owns_emits_and_saves_once() -> void:
	var sut: PlayerDataScript = _make_shop(100, true)
	var order: Array[String] = []
	sut.brains_changed.connect(func(_t: int, _d: int) -> void: order.append("brains"))
	sut.inventory_changed.connect(func(_id: StringName) -> void: order.append("inventory"))
	watch_signals(sut)
	watch_signals(_save)
	var result: PlayerDataScript.PurchaseResult = sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	assert_eq(result, PlayerDataScript.PurchaseResult.OK)
	assert_eq(sut.get_brains(), 100 - HAT_PRICE)
	assert_eq(_owned_raw(), ["hat_pumpkin"])
	assert_eq(typeof(_owned_raw()[0]), TYPE_STRING, "stored as a String")
	assert_true(sut.owns(&"hat_pumpkin"))
	assert_eq(sut.get_owned_items(), [&"hat_pumpkin"] as Array[StringName])
	assert_signal_emitted_with_parameters(sut, "brains_changed", [100 - HAT_PRICE, -HAT_PRICE])
	assert_signal_emitted_with_parameters(sut, "inventory_changed", [&"hat_pumpkin"])
	assert_eq(order, ["brains", "inventory"] as Array[String], "brains first, then inventory")
	assert_eq((_save as CountingSave).requests, 1)
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq(int(_written_profile()["brains"]), 100 - HAT_PRICE)
	assert_eq(_written_profile()["owned_items"], ["hat_pumpkin"])


func test_buy_listeners_see_the_new_state() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	var seen: Array = []
	sut.brains_changed.connect(func(_t: int, _d: int) -> void: seen.append([sut.get_brains(), sut.owns(&"hat_pumpkin")]))
	sut.inventory_changed.connect(func(_id: StringName) -> void: seen.append([sut.get_brains(), sut.owns(&"hat_pumpkin")]))
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	assert_eq(seen, [[100 - HAT_PRICE, true], [100 - HAT_PRICE, true]], "listeners read the new state")


func test_buy_exact_change_leaves_zero() -> void:
	var sut: PlayerDataScript = _make_shop(HAT_PRICE)
	assert_eq(sut.buy_item(_item_of(sut, &"hat_pumpkin")), PlayerDataScript.PurchaseResult.OK)
	assert_eq(sut.get_brains(), 0)


func test_buy_one_short_is_not_enough_brains() -> void:
	var sut: PlayerDataScript = _make_shop(HAT_PRICE - 1)
	watch_signals(sut)
	watch_signals(_save)
	assert_eq(sut.buy_item(_item_of(sut, &"hat_pumpkin")), PlayerDataScript.PurchaseResult.NOT_ENOUGH_BRAINS)
	await _assert_untouched(sut, HAT_PRICE - 1, [])


func test_buy_twice_is_already_owned() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	await wait_process_frames(2)
	watch_signals(sut)
	watch_signals(_save)
	assert_eq(sut.buy_item(_item_of(sut, &"hat_pumpkin")), PlayerDataScript.PurchaseResult.ALREADY_OWNED)
	await _assert_untouched(sut, 100 - HAT_PRICE, ["hat_pumpkin"])


func test_owned_beats_cant_afford() -> void:
	var sut: PlayerDataScript = _make_shop(HAT_PRICE)
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	assert_eq(sut.get_brains(), 0)
	assert_eq(sut.buy_item(_item_of(sut, &"hat_pumpkin")), PlayerDataScript.PurchaseResult.ALREADY_OWNED)


func test_buy_unavailable_item() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	watch_signals(sut)
	watch_signals(_save)
	assert_eq(sut.buy_item(_item_of(sut, &"hat_crown")), PlayerDataScript.PurchaseResult.UNAVAILABLE)
	await _assert_untouched(sut, 100, [])


func test_unavailable_beats_owned() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_owned_raw().append("hat_crown")
	assert_eq(sut.buy_item(_item_of(sut, &"hat_crown")), PlayerDataScript.PurchaseResult.UNAVAILABLE)


func test_buy_null_item_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	watch_signals(sut)
	watch_signals(_save)
	assert_eq(sut.buy_item(null), PlayerDataScript.PurchaseResult.UNAVAILABLE)
	assert_push_error("not in catalogue")
	await _assert_untouched(sut, 100, [])


func test_buy_non_catalogue_item_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	watch_signals(sut)
	watch_signals(_save)
	var stray: CosmeticItem = _cosmetic(&"hat_stray", CosmeticItem.Slot.HAT, 5, true)
	assert_eq(sut.buy_item(stray), PlayerDataScript.PurchaseResult.UNAVAILABLE)
	assert_push_error("not in catalogue")
	await _assert_untouched(sut, 100, [])


func test_catalogue_record_wins_over_the_passed_item() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	var cheap: CosmeticItem = _cosmetic(&"hat_witch", CosmeticItem.Slot.HAT, 1, true)
	assert_eq(sut.buy_item(cheap), PlayerDataScript.PurchaseResult.OK)
	assert_eq(sut.get_brains(), 100 - HAT2_PRICE, "the catalogue price is charged")
	var unlocked: CosmeticItem = _cosmetic(&"hat_crown", CosmeticItem.Slot.HAT, LOCKED_PRICE, true)
	assert_eq(sut.buy_item(unlocked), PlayerDataScript.PurchaseResult.UNAVAILABLE, "catalogue availability")
	var pricey: CosmeticItem = _cosmetic(&"hat_pumpkin", CosmeticItem.Slot.HAT, 999, true)
	assert_eq(sut.buy_item(pricey), PlayerDataScript.PurchaseResult.OK, "a wrong higher price is ignored too")
	assert_eq(sut.get_brains(), 100 - HAT2_PRICE - HAT_PRICE)


func test_free_catalogue_record_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_item_of(sut, &"hat_pumpkin").price = 0
	_item_of(sut, &"hat_witch").price = -50
	watch_signals(sut)
	assert_eq(sut.buy_item(_item_of(sut, &"hat_pumpkin")), PlayerDataScript.PurchaseResult.UNAVAILABLE)
	assert_push_error("price")
	assert_eq(sut.buy_item(_item_of(sut, &"hat_witch")), PlayerDataScript.PurchaseResult.UNAVAILABLE)
	assert_push_error("price")
	assert_eq(sut.get_brains(), 100)
	assert_false(sut.owns(&"hat_pumpkin"))
	assert_false(sut.owns(&"hat_witch"))
	assert_signal_not_emitted(sut, "brains_changed")


func test_brains_never_go_negative() -> void:
	var sut: PlayerDataScript = _make_shop(0)
	var steps: Array[String] = [
		"hat_pumpkin", "+50", "hat_witch", "hat_pumpkin", "hat_crown", "+15",
		"hat_witch", "pet_cute_ghost", "+1", "pet_cute_ghost", "-5", "hat_witch",
	]
	for step: String in steps:
		if step.begins_with("+") or step.begins_with("-"):
			sut.add_brains(int(step))
		else:
			sut.buy_item(_item_of(sut, StringName(step)))
		assert_true(sut.get_brains() >= 0, "after %s brains=%d" % [step, sut.get_brains()])
	assert_push_error("negative")
	assert_eq(sut.get_brains(), 50 + 15 + 1 - HAT2_PRICE - PET_PRICE, "the pet bought with exact change")
	assert_eq(sut.get_owned_items(), [&"hat_witch", &"pet_cute_ghost"] as Array[StringName])


func test_loaded_string_ids_are_owned_and_equipped() -> void:
	_put_fixture(FULL_PATH)
	var sut: PlayerDataScript = _make()
	assert_true(sut.owns(&"hat_pumpkin"))
	assert_true(sut.owns(&"pet_cute_ghost"))
	assert_false(sut.owns(&"hat_witch"))
	assert_eq(sut.get_equipped(&"hat"), &"hat_pumpkin")
	assert_eq(sut.get_equipped(&"pet"), &"pet_cute_ghost")
	assert_eq(sut.buy_item(sut.catalogue.get_item(&"hat_pumpkin")), PlayerDataScript.PurchaseResult.ALREADY_OWNED)


func test_owned_items_skip_junk() -> void:
	var sut: PlayerDataScript = _make_shop()
	_save.get_active_profile()["owned_items"] = ["hat_pumpkin", 7, null, {"x": 1}, "", "pet_cute_ghost"]
	assert_eq(sut.get_owned_items(), [&"hat_pumpkin", &"pet_cute_ghost"] as Array[StringName])
	assert_true(sut.owns(&"pet_cute_ghost"))
	assert_false(sut.owns(&""))


func test_equip_owned_item_sets_slot_emits_and_saves() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	await wait_process_frames(2)
	watch_signals(sut)
	watch_signals(_save)
	assert_true(sut.equip(&"hat_pumpkin"))
	assert_eq(sut.get_equipped(&"hat"), &"hat_pumpkin")
	assert_eq(_equipped_raw()["hat"], "hat_pumpkin")
	assert_eq(typeof(_equipped_raw()["hat"]), TYPE_STRING)
	assert_signal_emitted_with_parameters(sut, "equipment_changed", [&"hat", &"hat_pumpkin"])
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq(_written_profile()["equipped"]["hat"], "hat_pumpkin")


func test_equip_replaces_same_slot_only() -> void:
	var sut: PlayerDataScript = _make_shop(200)
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	sut.buy_item(_item_of(sut, &"hat_witch"))
	sut.buy_item(_item_of(sut, &"pet_cute_ghost"))
	sut.equip(&"hat_pumpkin")
	sut.equip(&"pet_cute_ghost")
	assert_eq(sut.get_equipped(&"hat"), &"hat_pumpkin")
	assert_eq(sut.get_equipped(&"pet"), &"pet_cute_ghost", "a hat and a pet at once")
	watch_signals(sut)
	assert_true(sut.equip(&"hat_witch"))
	assert_eq(sut.get_equipped(&"hat"), &"hat_witch", "replaced")
	assert_eq(sut.get_equipped(&"pet"), &"pet_cute_ghost", "pet untouched")
	assert_signal_emit_count(sut, "equipment_changed", 1)
	assert_signal_emitted_with_parameters(sut, "equipment_changed", [&"hat", &"hat_witch"])


func test_equip_same_item_again_is_a_noop() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	sut.equip(&"hat_pumpkin")
	await wait_process_frames(2)
	watch_signals(sut)
	watch_signals(_save)
	assert_true(sut.equip(&"hat_pumpkin"))
	assert_signal_not_emitted(sut, "equipment_changed")
	await wait_process_frames(2)
	assert_signal_not_emitted(_save, "save_written")


func test_equip_not_owned_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	watch_signals(sut)
	watch_signals(_save)
	assert_false(sut.equip(&"hat_pumpkin"))
	assert_push_error("not owned")
	assert_eq(_equipped_raw()["hat"], "")
	assert_signal_not_emitted(sut, "equipment_changed")
	await wait_process_frames(2)
	assert_signal_not_emitted(_save, "save_written")


func test_equip_unknown_id_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_owned_raw().append("hat_stray")
	watch_signals(sut)
	assert_false(sut.equip(&"hat_stray"))
	assert_push_error("not in catalogue")
	assert_false(sut.equip(&""))
	assert_push_error("not in catalogue")
	assert_eq(_equipped_raw(), {"hat": "", "pet": ""})
	assert_signal_not_emitted(sut, "equipment_changed")


func test_unequip_empties_slot_emits_and_saves() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	sut.buy_item(_item_of(sut, &"pet_cute_ghost"))
	sut.equip(&"pet_cute_ghost")
	await wait_process_frames(2)
	watch_signals(sut)
	watch_signals(_save)
	sut.unequip(&"pet")
	assert_eq(sut.get_equipped(&"pet"), &"")
	assert_eq(_equipped_raw()["pet"], "")
	assert_signal_emitted_with_parameters(sut, "equipment_changed", [&"pet", &""])
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq(_written_profile()["equipped"]["pet"], "")


func test_unequip_empty_slot_is_a_noop() -> void:
	var sut: PlayerDataScript = _make_shop()
	watch_signals(sut)
	watch_signals(_save)
	sut.unequip(&"hat")
	assert_signal_not_emitted(sut, "equipment_changed")
	await wait_process_frames(2)
	assert_signal_not_emitted(_save, "save_written")


func test_equip_unavailable_owned_item_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_owned_raw().append("hat_crown")
	watch_signals(sut)
	assert_false(sut.equip(&"hat_crown"))
	assert_push_error("not available")
	assert_eq(sut.get_equipped(&"hat"), &"")
	assert_signal_not_emitted(sut, "equipment_changed")


func test_get_equipped_hides_an_unavailable_item() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_owned_raw().append("hat_crown")
	_equipped_raw()["hat"] = "hat_crown"
	assert_eq(sut.get_equipped(&"hat"), &"")


func test_unequip_clears_junk_without_a_signal() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_equipped_raw()["pet"] = 42
	watch_signals(sut)
	sut.unequip(&"pet")
	assert_eq(_equipped_raw()["pet"], "")
	assert_signal_not_emitted(sut, "equipment_changed")


func test_unequip_unowned_stored_id_is_silent() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_equipped_raw()["hat"] = "hat_witch"
	watch_signals(sut)
	sut.unequip(&"hat")
	assert_eq(_equipped_raw()["hat"], "")
	assert_signal_not_emitted(sut, "equipment_changed")


func test_get_owned_items_dedupes() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	_owned_raw().append_array(["hat_pumpkin", "hat_pumpkin"])
	assert_eq(sut.get_owned_items(), [&"hat_pumpkin"] as Array[StringName])


func test_unequip_unknown_slot_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop()
	watch_signals(sut)
	sut.unequip(&"shoes")
	assert_push_error("unknown slot")
	assert_false(_equipped_raw().has("shoes"))
	assert_signal_not_emitted(sut, "equipment_changed")


func test_get_equipped_unknown_slot_logs() -> void:
	var sut: PlayerDataScript = _make_shop()
	assert_eq(sut.get_equipped(&"shoes"), &"")
	assert_push_error("unknown slot")


func test_get_equipped_hides_junk_and_not_owned() -> void:
	var sut: PlayerDataScript = _make_shop()
	_equipped_raw()["hat"] = "hat_witch"
	_equipped_raw()["pet"] = 42
	assert_eq(sut.get_equipped(&"hat"), &"", "not owned")
	assert_eq(sut.get_equipped(&"pet"), &"", "not a String")
	assert_eq(_equipped_raw()["hat"], "hat_witch", "getters never write")
	_owned_raw().append("hat_witch")
	assert_eq(sut.get_equipped(&"hat"), &"hat_witch")


func test_set_flag_changes_value_emits_and_saves() -> void:
	var sut: PlayerDataScript = _make_shop(0, true)
	watch_signals(sut)
	watch_signals(_save)
	assert_false(sut.get_flag(&"tutorial_seen"))
	sut.set_flag(&"tutorial_seen", true)
	assert_true(sut.get_flag(&"tutorial_seen"))
	assert_signal_emit_count(sut, "flags_changed", 1)
	assert_signal_emitted_with_parameters(sut, "flags_changed", [&"tutorial_seen", true])
	assert_eq((_save as CountingSave).requests, 1)
	var flags: Dictionary = _save.get_active_profile()["flags"]
	for key: Variant in flags.keys():
		assert_eq(typeof(key), TYPE_STRING, "key %s is a String" % str(key))
	assert_eq(flags.size(), SaveSchema.profile_defaults()["flags"].size(), "no extra key")
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_true(_written_profile()["flags"]["tutorial_seen"])


func test_set_flag_same_value_is_a_noop() -> void:
	var sut: PlayerDataScript = _make_shop()
	watch_signals(sut)
	watch_signals(_save)
	sut.set_flag(&"placement_done", false)
	assert_signal_not_emitted(sut, "flags_changed")
	await wait_process_frames(2)
	assert_signal_not_emitted(_save, "save_written")


func test_set_flag_unknown_name_is_rejected() -> void:
	var sut: PlayerDataScript = _make_shop()
	watch_signals(sut)
	sut.set_flag(&"cheat_mode", true)
	assert_push_error("unknown flag")
	assert_false(_save.get_active_profile()["flags"].has("cheat_mode"))
	assert_signal_not_emitted(sut, "flags_changed")
	assert_false(sut.get_flag(&"cheat_mode"))
	assert_push_error("unknown flag", "get_flag logs too")


func test_fixture_flags_read_true() -> void:
	_put_fixture(FULL_PATH)
	var sut: PlayerDataScript = _make()
	assert_true(sut.get_flag(&"welcome_bonus_claimed"))
	assert_true(sut.get_flag(&"tutorial_seen"))
	assert_true(sut.get_flag(&"placement_done"))


func test_reset_all_clears_shop_state_with_only_profile_replaced() -> void:
	var sut: PlayerDataScript = _make_shop(100)
	sut.buy_item(_item_of(sut, &"hat_pumpkin"))
	sut.equip(&"hat_pumpkin")
	sut.set_flag(&"welcome_bonus_claimed", true)
	await wait_process_frames(2)
	watch_signals(sut)
	sut.reset_all()
	assert_eq(sut.get_owned_items(), [] as Array[StringName])
	assert_eq(sut.get_equipped(&"hat"), &"")
	assert_false(sut.get_flag(&"welcome_bonus_claimed"))
	assert_signal_emit_count(sut, "profile_replaced", 1)
	assert_signal_not_emitted(sut, "equipment_changed")
	assert_signal_not_emitted(sut, "inventory_changed")
	assert_signal_not_emitted(sut, "flags_changed")
	assert_signal_not_emitted(sut, "brains_changed")
