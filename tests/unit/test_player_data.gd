extends GutTest
## PlayerData: brains, settings, wallet, inventory, equipment, flag and level-unlock (Story 6.8) mutations,
## their signals, coalesced save requests, live profile reads, lifetime totals and Progress reads (Story 10.5).
## Always a fresh SaveService (save_dir = TEST_DIR) and a fresh PlayerData wired to it through the
## save_service seam before add_child. The live autoloads are only read, so the real save is never touched.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_player_data/"
const FULL_PATH: String = "res://tests/fixtures/saves/save_v1_full.json"
## Story 9.3: a schema-3 save from before the full catalogue went live (owns and wears the two MVP items).
const MVP_OWNED_PATH: String = "res://tests/fixtures/saves/save_v3_mvp_owned.json"

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


## Story 9.3 (Epic 9 AC 2): a save from before the full catalogue went live (schema 3, and a v1 save that
## migrates) loads with the shipped catalogue unchanged: same owned list in order, same worn hat and pet,
## same brains. A new item buys alongside and leaves the old two owned and worn.
func test_an_mvp_save_loads_unchanged_with_the_full_catalogue() -> void:
	for path: String in [MVP_OWNED_PATH, FULL_PATH]:
		_clear()
		_put_fixture(path)
		var sut: PlayerDataScript = _make()
		assert_eq(sut.catalogue, load("res://data/cosmetics/catalogue.tres"), path + ": the shipped catalogue")
		assert_eq(sut.get_owned_items(), [&"hat_pumpkin", &"pet_cute_ghost"] as Array[StringName], path)
		assert_eq(sut.get_equipped(&"hat"), &"hat_pumpkin", path)
		assert_eq(sut.get_equipped(&"pet"), &"pet_cute_ghost", path)
		assert_eq(sut.get_brains(), 340, path)
		assert_eq(sut.buy_item(sut.catalogue.get_item(&"hat_santa")), PlayerDataScript.PurchaseResult.OK, path)
		assert_eq(sut.get_brains(), 140, path)
		assert_eq(sut.get_owned_items(), [&"hat_pumpkin", &"pet_cute_ghost", &"hat_santa"] as Array[StringName], path)
		assert_eq(sut.get_equipped(&"hat"), &"hat_pumpkin", path + ": buying does not change what is worn")
		assert_eq(sut.get_equipped(&"pet"), &"pet_cute_ghost", path)
	assert_push_warning_count(0)


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


# --- level unlocks (Story 6.8, FR79) ---------------------------------------------

const UNSEEN: Dictionary = {"moment_seen": false, "chosen": false}


func _level(id: StringName, unlocked_by: StringName) -> LevelEntry:
	var entry: LevelEntry = LevelEntry.new()
	entry.id = id
	entry.display_name = String(id)
	entry.available = true
	entry.unlocked_by = unlocked_by
	return entry


## a (open) -> b -> c, plus d (open) that opens nothing. Not the shipped chain on purpose.
func _test_registry() -> LevelRegistry:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [_level(&"a", &""), _level(&"b", &"a"), _level(&"c", &"b"), _level(&"d", &"")]
	return registry


func _make_unlocks(counting: bool = false) -> PlayerDataScript:
	_save = CountingSave.new() if counting else SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	sut.level_registry = _test_registry()
	add_child_autofree(sut)
	return sut


func _run(level: StringName, reason: StringName = GameConstants.END_REASON_TIMER) -> RunResult:
	return RunResult.create(level, 1000, 60.0, 50, 0, {}, 0, 0, "all", reason)


func _unlocks_raw() -> Dictionary:
	return _save.get_active_profile()["level_unlocks"]


func test_timer_run_unlocks_the_next_level_once() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	assert_false(sut.get_unlock_state(&"b")["unlocked"])
	watch_signals(sut)
	var order: Array[String] = []
	sut.run_recorded.connect(func(_id: StringName, _best: bool) -> void: order.append("run_recorded"))
	sut.level_unlocked.connect(func(id: StringName) -> void: order.append("unlocked %s" % id))
	sut.record_run(_run(&"a"))
	assert_eq(order, ["run_recorded", "unlocked b"] as Array[String], "level_unlocked after run_recorded")
	assert_signal_emit_count(sut, "level_unlocked", 1)
	assert_signal_emitted_with_parameters(sut, "level_unlocked", [&"b"])
	assert_eq_deep(_unlocks_raw(), {"b": UNSEEN})
	assert_eq_deep(sut.get_unlock_state(&"b"), {"unlocked": true, "moment_seen": false, "chosen": false})
	assert_false(sut.get_unlock_state(&"c")["unlocked"], "only the next level, not the whole chain")
	sut.record_run(_run(&"a"))
	assert_signal_emit_count(sut, "level_unlocked", 1, "a second finish emits nothing")
	assert_eq_deep(_unlocks_raw(), {"b": UNSEEN})


func test_record_run_with_an_unlock_still_requests_one_save() -> void:
	var sut: PlayerDataScript = _make_unlocks(true)
	watch_signals(_save)
	sut.record_run(_run(&"a"))
	assert_eq((_save as CountingSave).requests, 1)
	await wait_process_frames(2)
	assert_signal_emit_count(_save, "save_written", 1)
	assert_eq_deep(_written_profile()["level_unlocks"], {"b": UNSEEN})


func test_non_timer_runs_unlock_nothing() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	watch_signals(sut)
	sut.record_run(_run(&"a", GameConstants.END_REASON_CAUGHT))
	sut.record_run(_run(&"a", GameConstants.END_REASON_ESCAPED))
	assert_signal_not_emitted(sut, "level_unlocked")
	assert_eq_deep(_unlocks_raw(), {})
	assert_false(sut.get_unlock_state(&"b")["unlocked"])


func test_run_of_a_level_that_opens_nothing_changes_nothing() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	watch_signals(sut)
	sut.record_run(_run(&"d"))
	sut.record_run(_run(&"unknown"))
	assert_signal_not_emitted(sut, "level_unlocked")
	assert_eq_deep(_unlocks_raw(), {})


func test_unlock_state_defaults() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	var open: Dictionary = {"unlocked": true, "moment_seen": true, "chosen": true}
	# empty unlocked_by is always open
	assert_eq_deep(sut.get_unlock_state(&"a"), open)
	# unknown id is open
	assert_eq_deep(sut.get_unlock_state(&"nope"), open)
	assert_eq_deep(sut.get_unlock_state(&"b"), {"unlocked": false, "moment_seen": false, "chosen": false})


func test_mark_unlock_seen_and_chosen() -> void:
	var sut: PlayerDataScript = _make_unlocks(true)
	sut.record_run(_run(&"a"))
	var requests: int = (_save as CountingSave).requests
	watch_signals(sut)
	sut.mark_unlock_seen(&"b")
	assert_eq_deep(sut.get_unlock_state(&"b"), {"unlocked": true, "moment_seen": true, "chosen": false})
	assert_signal_emit_count(sut, "unlocks_changed", 1)
	assert_signal_emitted_with_parameters(sut, "unlocks_changed", [&"b"])
	assert_eq((_save as CountingSave).requests, requests + 1)
	sut.mark_unlock_seen(&"b")
	assert_signal_emit_count(sut, "unlocks_changed", 1, "already seen: no-op")
	assert_eq((_save as CountingSave).requests, requests + 1)
	sut.mark_level_chosen(&"b")
	assert_eq_deep(sut.get_unlock_state(&"b"), {"unlocked": true, "moment_seen": true, "chosen": true})
	assert_signal_emit_count(sut, "unlocks_changed", 2)
	assert_eq((_save as CountingSave).requests, requests + 2)
	sut.mark_level_chosen(&"b")
	assert_eq((_save as CountingSave).requests, requests + 2, "already chosen: no-op")
	assert_eq_deep(_unlocks_raw(), {"b": {"moment_seen": true, "chosen": true}})


func test_marks_on_locked_or_open_levels_change_nothing() -> void:
	var sut: PlayerDataScript = _make_unlocks(true)
	watch_signals(sut)
	for id: StringName in [&"b", &"a", &"nope"]:
		sut.mark_unlock_seen(id)
		sut.mark_level_chosen(id)
	assert_signal_not_emitted(sut, "unlocks_changed")
	assert_eq((_save as CountingSave).requests, 0)
	assert_eq_deep(_unlocks_raw(), {})


func test_junk_entries_read_as_seen_and_are_repaired_by_a_mark() -> void:
	var sut: PlayerDataScript = _make_unlocks(true)
	_unlocks_raw()["b"] = 5
	_unlocks_raw()["c"] = {"moment_seen": "no"}
	assert_eq_deep(sut.get_unlock_state(&"b"), {"unlocked": true, "moment_seen": true, "chosen": true})
	assert_eq_deep(sut.get_unlock_state(&"c"), {"unlocked": true, "moment_seen": true, "chosen": true})
	watch_signals(sut)
	sut.mark_unlock_seen(&"b")
	# rewritten as a Dictionary
	assert_eq_deep(_unlocks_raw()["b"], {"moment_seen": true, "chosen": true})
	assert_signal_not_emitted(sut, "unlocks_changed", "the read state did not change")
	assert_eq((_save as CountingSave).requests, 1, "the repair is saved")
	sut.mark_level_chosen(&"c")
	assert_eq_deep(_unlocks_raw()["c"], {"moment_seen": true, "chosen": true})
	sut.mark_level_chosen(&"c")
	assert_eq((_save as CountingSave).requests, 2, "a proper entry is not rewritten again")


func test_non_dictionary_level_unlocks_reads_as_empty() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	_save.get_active_profile()["level_unlocks"] = "junk"
	assert_false(sut.get_unlock_state(&"b")["unlocked"])
	sut.record_run(_run(&"a"))
	assert_eq_deep(_unlocks_raw(), {"b": UNSEEN})


func test_unlocks_survive_a_reload() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	sut.record_run(_run(&"a"))
	sut.mark_unlock_seen(&"b")
	_save.save_now()
	var reloaded: PlayerDataScript = _make_unlocks()
	assert_eq_deep(reloaded.get_unlock_state(&"b"), {"unlocked": true, "moment_seen": true, "chosen": false})
	assert_false(reloaded.get_unlock_state(&"c")["unlocked"])


func test_debug_set_all_unlocked() -> void:
	var sut: PlayerDataScript = _make_unlocks(true)
	sut.record_run(_run(&"a"))
	sut.mark_unlock_seen(&"b")
	sut.mark_level_chosen(&"b")
	var requests: int = (_save as CountingSave).requests
	watch_signals(sut)
	sut.debug_set_all_unlocked(true)
	# overwrites, so the moment replays
	assert_eq_deep(_unlocks_raw(), {"b": UNSEEN, "c": UNSEEN})
	assert_signal_emit_count(sut, "unlocks_changed", 1)
	assert_signal_emitted_with_parameters(sut, "unlocks_changed", [&""])
	assert_eq((_save as CountingSave).requests, requests + 1)
	sut.debug_set_all_unlocked(false)
	assert_eq_deep(_unlocks_raw(), {})
	assert_false(sut.get_unlock_state(&"b")["unlocked"])
	assert_eq((_save as CountingSave).requests, requests + 2)


func test_reset_all_relocks() -> void:
	var sut: PlayerDataScript = _make_unlocks()
	sut.record_run(_run(&"a"))
	sut.reset_all()
	assert_false(sut.get_unlock_state(&"b")["unlocked"])
	assert_eq_deep(_unlocks_raw(), {})


func test_lazily_uses_the_shipped_registry() -> void:
	var sut: PlayerDataScript = _make()
	assert_null(sut.level_registry, "not loaded at _ready (no level scenes at boot)")
	assert_false(sut.get_unlock_state(&"horde_rush")["unlocked"])
	assert_not_null(sut.level_registry)
	assert_eq(sut.level_registry.resource_path, "res://data/levels/level_registry.tres")
	sut.record_run(_result(&"zombie_run", 50))
	assert_true(sut.get_unlock_state(&"horde_rush")["unlocked"], "the shipped chain: Zombie Run opens Horde Rush")
	assert_false(sut.get_unlock_state(&"pitchfork_panic")["unlocked"])
	sut.record_run(_result(&"horde_rush", 50))
	assert_true(sut.get_unlock_state(&"pitchfork_panic")["unlocked"], "a Horde Rush timer run opens Pitchfork Panic (FR79)")


# --- used passages (Story 8.2) ---------------------------------------------------

func test_used_passages_start_empty_and_round_trip() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_used_passages(), [] as Array[String])
	watch_signals(sut)
	sut.set_used_passages(["t3_01", "t4_02"] as Array[String])
	assert_eq(sut.get_used_passages(), ["t3_01", "t4_02"] as Array[String])
	assert_signal_emit_count(sut, "used_passages_changed", 1)
	await wait_process_frames(2)
	assert_eq_deep(_written_profile()["used_passages"], ["t3_01", "t4_02"])


func test_used_passages_dedup_and_drop_empty_ids() -> void:
	var sut: PlayerDataScript = _make()
	sut.set_used_passages(["t3_01", "", "t3_02", "t3_01"] as Array[String])
	assert_eq(sut.get_used_passages(), ["t3_01", "t3_02"] as Array[String])


func test_used_passages_equal_list_is_a_noop() -> void:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	add_child_autofree(sut)
	sut.set_used_passages(["t3_01"] as Array[String])
	assert_eq((_save as CountingSave).requests, 1, "one save request per change")
	watch_signals(sut)
	sut.set_used_passages(["t3_01", "t3_01"] as Array[String])
	assert_signal_not_emitted(sut, "used_passages_changed")
	assert_eq((_save as CountingSave).requests, 1, "an equal list requests no save")
	sut.set_used_passages(["t3_01", "t3_02"] as Array[String])
	assert_eq((_save as CountingSave).requests, 2)


func test_used_passages_reset_all_clears_them() -> void:
	var sut: PlayerDataScript = _make()
	sut.set_used_passages(["t3_01"] as Array[String])
	sut.reset_all()
	assert_eq(sut.get_used_passages(), [] as Array[String])


func test_used_passages_bad_stored_type_reads_empty() -> void:
	var sut: PlayerDataScript = _make()
	_save.get_active_profile()["used_passages"] = "t3_01"
	assert_eq(sut.get_used_passages(), [] as Array[String])
	_save.get_active_profile()["used_passages"] = ["t3_01", 5, null, "t4_01"]
	assert_eq(sut.get_used_passages(), ["t3_01", "t4_01"] as Array[String], "non-String entries are skipped")
	sut.set_used_passages(["t3_01"] as Array[String])
	assert_eq_deep(_save.get_active_profile()["used_passages"], ["t3_01"])


# --- last themes (Story 10.1) ------------------------------------------------------

func test_last_theme_starts_empty_and_round_trips() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_last_theme(&"zombie_run"), &"")
	sut.set_last_theme(&"zombie_run", &"sunny_village_green")
	sut.set_last_theme(&"horde_rush", &"farmhouse")
	assert_eq(sut.get_last_theme(&"zombie_run"), &"sunny_village_green")
	assert_eq(sut.get_last_theme(&"horde_rush"), &"farmhouse")
	assert_eq(sut.get_last_theme(&"pitchfork_panic"), &"")
	await wait_process_frames(2)
	assert_eq_deep(_written_profile()["last_themes"], {"zombie_run": "sunny_village_green", "horde_rush": "farmhouse"})


func test_last_theme_unchanged_value_requests_no_save() -> void:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	add_child_autofree(sut)
	sut.set_last_theme(&"zombie_run", &"a")
	assert_eq((_save as CountingSave).requests, 1, "one save request per change")
	sut.set_last_theme(&"zombie_run", &"a")
	assert_eq((_save as CountingSave).requests, 1, "an unchanged theme requests no save")
	sut.set_last_theme(&"", &"b")
	assert_eq((_save as CountingSave).requests, 1, "an empty level id is ignored")
	assert_false((_save.get_active_profile()["last_themes"] as Dictionary).has(""))
	sut.set_last_theme(&"zombie_run", &"b")
	assert_eq((_save as CountingSave).requests, 2)


func test_last_theme_junk_reads_empty() -> void:
	var sut: PlayerDataScript = _make()
	_save.get_active_profile()["last_themes"] = "farmhouse"
	assert_eq(sut.get_last_theme(&"horde_rush"), &"")
	sut.set_last_theme(&"horde_rush", &"farmhouse")
	assert_eq_deep(_save.get_active_profile()["last_themes"], {"horde_rush": "farmhouse"})
	_save.get_active_profile()["last_themes"] = {"horde_rush": 5, "zombie_run": null}
	assert_eq(sut.get_last_theme(&"horde_rush"), &"")
	assert_eq(sut.get_last_theme(&"zombie_run"), &"")


func test_last_theme_survives_a_reload() -> void:
	var sut: PlayerDataScript = _make()
	sut.set_last_theme(&"pitchfork_panic", &"moonlit_village")
	await wait_process_frames(2)
	var reloaded: PlayerDataScript = _make()
	assert_eq(reloaded.get_last_theme(&"pitchfork_panic"), &"moonlit_village")
	assert_eq(typeof(_written_profile()["last_themes"]["pitchfork_panic"]), TYPE_STRING)


func test_last_theme_reset_all_clears_them() -> void:
	var sut: PlayerDataScript = _make()
	sut.set_last_theme(&"zombie_run", &"sunny_village_green")
	sut.reset_all()
	assert_eq(sut.get_last_theme(&"zombie_run"), &"")


# --- lifetime totals and Progress reads (Story 10.5) ---------------------------

## A run lasting `seconds` with `keys` keys and `brains` level brains (+ `bonus`).
func _timed(keys: int, seconds: float, brains: int = 0, bonus: int = 0, stamp: int = 1000) -> RunResult:
	return RunResult.create(
		&"zombie_run", stamp, seconds, keys, 0, {}, brains, bonus, "all", GameConstants.END_REASON_TIMER)


func test_record_run_adds_to_every_lifetime_total_with_one_save() -> void:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	add_child_autofree(sut)
	sut.record_run(_timed(51, 120.9, 7, 5))
	assert_eq_deep(sut.get_lifetime(), {"runs": 1, "keys_typed": 51, "seconds": 120, "brains": 12})
	assert_eq((_save as CountingSave).requests, 1, "still exactly one save request")
	await wait_process_frames(2)
	var written: Dictionary = SaveSchema.normalize_numbers(_written_profile()["lifetime"])
	assert_eq_deep(written, {"runs": 1, "keys_typed": 51, "seconds": 120, "brains": 12})


func test_lifetime_accumulates_over_runs() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_timed(50, 60.0, 3))
	sut.record_run(_timed(70, 180.0, 4, 10))
	assert_eq_deep(sut.get_lifetime(), {"runs": 2, "keys_typed": 120, "seconds": 240, "brains": 17})


func test_lifetime_listener_on_brains_changed_sees_the_run() -> void:
	var sut: PlayerDataScript = _make()
	var seen: Array[int] = []
	sut.brains_changed.connect(func(_t: int, _d: int) -> void: seen.append(int(sut.get_lifetime()["runs"])))
	sut.record_run(_timed(50, 60.0, 3))
	assert_eq(seen, [1] as Array[int])


func test_lifetime_outlives_the_history_cap() -> void:
	var sut: PlayerDataScript = _make()
	var runs: int = GameConstants.RUN_HISTORY_CAP + 1
	for i: int in runs:
		sut.record_run(_timed(10, 60.0, 1, 0, i))
	assert_eq(_history().size(), GameConstants.RUN_HISTORY_CAP)
	assert_eq_deep(
		sut.get_lifetime(), {"runs": runs, "keys_typed": 10 * runs, "seconds": 60 * runs, "brains": runs}
	)


func test_add_brains_counts_toward_lifetime_and_spending_never_lowers_it() -> void:
	var sut: PlayerDataScript = _make_shop(0, true)
	sut.add_brains(100)
	assert_eq(int(sut.get_lifetime()["brains"]), 100, "quit-run and gift brains count")
	assert_eq((_save as CountingSave).requests, 1, "add_brains still makes one save request")
	assert_eq(sut.buy_item(_item_of(sut, &"hat_pumpkin")), PlayerDataScript.PurchaseResult.OK)
	assert_eq(sut.get_brains(), 100 - HAT_PRICE)
	assert_eq(int(sut.get_lifetime()["brains"]), 100, "spending does not lower Brains Earned")
	sut.add_brains(0)
	assert_eq(int(sut.get_lifetime()["brains"]), 100)
	assert_eq_deep(sut.get_lifetime(), {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 100})


func test_get_lifetime_reads_junk_as_zero() -> void:
	var sut: PlayerDataScript = _make()
	_save.get_active_profile()["lifetime"] = "x"
	assert_eq_deep(sut.get_lifetime(), {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 0})
	_save.get_active_profile()["lifetime"] = {"runs": -5, "keys_typed": 3.5, "seconds": "7"}
	assert_eq_deep(sut.get_lifetime(), {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 0})
	sut.add_brains(4)
	assert_eq_deep(sut.get_lifetime(), {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 4})
	_save.get_active_profile()["lifetime"] = [1]
	sut.record_run(_timed(5, 60.0))
	assert_eq_deep(sut.get_lifetime(), {"runs": 1, "keys_typed": 5, "seconds": 60, "brains": 0})
	assert_push_error_count(0)


func test_get_lifetime_returns_a_copy() -> void:
	var sut: PlayerDataScript = _make()
	sut.add_brains(3)
	var totals: Dictionary = sut.get_lifetime()
	totals["brains"] = 999
	assert_eq(int(sut.get_lifetime()["brains"]), 3)


func test_get_best_wpm_overall_is_the_highest_level_best() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_best_wpm_overall(), 0, "fresh save")
	_save.get_active_profile()["best_wpm"] = {"zombie_run": 12, "horde_rush": 17, "pitchfork_panic": 9}
	assert_eq(sut.get_best_wpm_overall(), 17)
	_save.get_active_profile()["best_wpm"] = {"zombie_run": 12, "a": -40, "b": "99", "c": 30.5, "d": 21.0}
	assert_eq(sut.get_best_wpm_overall(), 21, "junk ignored; a whole float counts")
	_save.get_active_profile()["best_wpm"] = "lots"
	assert_eq(sut.get_best_wpm_overall(), 0)


func test_get_run_history_returns_copies_and_skips_junk() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_timed(50, 60.0, 0, 0, 10))
	sut.record_run(_timed(60, 60.0, 0, 0, 20))
	_history().insert(1, "oops")
	_history().append(7)
	var records: Array[Dictionary] = sut.get_run_history()
	assert_eq(records.size(), 2)
	assert_eq(int(records[0]["timestamp"]), 10, "oldest first")
	assert_eq(int(records[1]["timestamp"]), 20)
	records[0]["wpm"] = 999
	records[0]["per_key"]["z"] = [1, 1, {}]
	records.clear()
	assert_eq(int((_history()[0] as Dictionary)["wpm"]), 10, "the save is untouched")
	assert_false((_history()[0] as Dictionary)["per_key"].has("z"))
	assert_eq(_history().size(), 4)
	_save.get_active_profile()["run_history"] = "nope"
	assert_eq(sut.get_run_history().size(), 0)


func test_lifetime_survives_a_reload() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_timed(40, 120.0, 6))
	sut.add_brains(2)
	await wait_process_frames(2)
	var reloaded: PlayerDataScript = _make()
	assert_eq_deep(reloaded.get_lifetime(), {"runs": 1, "keys_typed": 40, "seconds": 120, "brains": 8})


func test_reset_all_clears_lifetime() -> void:
	var sut: PlayerDataScript = _make()
	sut.record_run(_timed(40, 120.0, 6))
	sut.reset_all()
	assert_eq_deep(sut.get_lifetime(), {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 0})


# --- zombie name (Story 11.1, FR78) ----------------------------------------------

## A PlayerData on a CountingSave, so tests can count save requests.
func _make_counting() -> PlayerDataScript:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	add_child_autofree(sut)
	return sut


func test_zombie_name_fresh_profile_reads_empty() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_zombie_name(), "")


func test_zombie_name_fixture_without_a_name_reads_empty() -> void:
	_put_fixture(FULL_PATH)
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_zombie_name(), "", "an MVP save gets the name screen")


func test_set_zombie_name_stores_the_cleaned_name_with_one_save() -> void:
	var sut: PlayerDataScript = _make_counting()
	watch_signals(sut)
	assert_true(sut.set_zombie_name("  Sam   Z "))
	assert_eq(sut.get_zombie_name(), "Sam Z")
	assert_eq(_save.get_active_profile()["name"], "Sam Z")
	assert_eq((_save as CountingSave).requests, 1)
	assert_signal_emit_count(sut, "zombie_name_changed", 1)
	assert_signal_emitted_with_parameters(sut, "zombie_name_changed", ["Sam Z"])


func test_set_zombie_name_same_name_twice_is_one_signal_one_save() -> void:
	var sut: PlayerDataScript = _make_counting()
	watch_signals(sut)
	assert_true(sut.set_zombie_name("Sam"))
	assert_true(sut.set_zombie_name("Sam "), "cleans to the stored name")
	assert_eq((_save as CountingSave).requests, 1)
	assert_signal_emit_count(sut, "zombie_name_changed", 1)
	assert_true(sut.set_zombie_name("Bo"))
	assert_eq((_save as CountingSave).requests, 2)
	assert_eq(sut.get_zombie_name(), "Bo")


func test_set_zombie_name_leaves_the_rest_of_the_profile_untouched() -> void:
	_put_fixture(FULL_PATH)
	var sut: PlayerDataScript = _make()
	var before: Dictionary = _save.get_active_profile().duplicate(true)
	assert_true(sut.set_zombie_name("Sam"))
	var after: Dictionary = _save.get_active_profile().duplicate(true)
	assert_eq(after["name"], "Sam")
	before.erase("name")
	after.erase("name")
	assert_eq_deep(after, before)
	await wait_process_frames(2)
	var written: Dictionary = _written_profile()
	assert_eq(written["name"], "Sam")
	assert_eq(written.keys().size(), _save.get_active_profile().keys().size())


func test_set_zombie_name_invalid_changes_nothing() -> void:
	var sut: PlayerDataScript = _make_counting()
	assert_true(sut.set_zombie_name("Sam"))
	watch_signals(sut)
	for raw: String in ["", "123", "   ", "!!!"]:
		assert_false(sut.set_zombie_name(raw), "rejects '%s'" % raw)
	assert_eq(sut.get_zombie_name(), "Sam")
	assert_eq((_save as CountingSave).requests, 1, "no save for a rejected name")
	assert_signal_not_emitted(sut, "zombie_name_changed")
	assert_push_warning("set_zombie_name: invalid name")
	assert_push_warning_count(4)


func test_zombie_name_junk_stored_values_read_empty() -> void:
	var sut: PlayerDataScript = _make()
	for junk: Variant in [5, null, ["Sam"], "!!!", "W".repeat(40), " Sam", "Sam "]:
		_save.get_active_profile()["name"] = junk
		assert_eq(sut.get_zombie_name(), "", "junk %s reads as not named" % type_string(typeof(junk)))


func test_zombie_name_survives_a_reload() -> void:
	var sut: PlayerDataScript = _make()
	assert_true(sut.set_zombie_name("Mr Bones"))
	await wait_process_frames(2)
	var reloaded: PlayerDataScript = _make()
	assert_eq(reloaded.get_zombie_name(), "Mr Bones")


func test_zombie_name_reset_all_clears_it() -> void:
	var sut: PlayerDataScript = _make()
	assert_true(sut.set_zombie_name("Sam"))
	sut.reset_all()
	assert_eq(sut.get_zombie_name(), "")


## NFR12, part (a): the only line set_zombie_name pushes is fixed text. ("Zorbleflux9" from the story cleans to
## the valid "Zorbleflux", so it saves with no warning at all; a name with no letter is the invalid case.)
func test_zombie_name_warnings_never_carry_the_name() -> void:
	var sut: PlayerDataScript = _make()
	assert_true(sut.set_zombie_name("Zorbleflux9"))
	assert_eq(sut.get_zombie_name(), "Zorbleflux")
	assert_push_warning_count(0, "a valid name pushes nothing")
	assert_false(sut.set_zombie_name("#9#9#"))
	for err: Variant in gut.error_tracker.get_errors_for_test():
		assert_false(err.contains_text("Zorbleflux"), "no tracked line carries the name")
		assert_false(err.contains_text("#9#9#"), "or the rejected text")
	assert_push_warning("[WARN][save] set_zombie_name: invalid name")
	assert_push_warning_count(1)
	assert_push_error_count(0)


## NFR12, part (b): print lines can't be captured by GUT, so this reads the name code as text. Any Log.* /
## print / push_* call line in these files fails if, after its quoted strings are removed, it still names a
## variable that can hold the name (name, raw, text, cleaned, _text; Story 11.2 adds summary, raw_name, shown and the
## picker / card files). Name-related log messages must stay fixed literals.
func test_zombie_name_is_never_passed_to_a_log_call() -> void:
	var call: RegEx = RegEx.create_from_string(r"\b(Log\.\w+|print\w*|push_\w+)\s*\(")
	var quoted: RegEx = RegEx.create_from_string(r'"(\\.|[^"\\])*"')
	var name_var: RegEx = RegEx.create_from_string(
			r"\b(name|raw|text|cleaned|_text|next|value|current|out|chosen|stored|summary|raw_name|shown)\b"
			+ r"|get_zombie_name|get_text|get_shown_name|get_profile_summary\(")
	for path: String in [
		"res://scripts/autoloads/player_data.gd",
		"res://scripts/screens/name_zombie.gd",
		"res://scripts/core/zombie_name.gd",
		"res://scripts/screens/title.gd",
		# Story 11.2: the picker and the zombie card (PlayerData's profile methods are in player_data.gd above).
		"res://scripts/screens/whos_playing.gd",
		"res://scripts/ui/zombie_card.gd",
	]:
		assert_true(FileAccess.file_exists(path), path)
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var line: String = lines[i]
			if line.strip_edges().begins_with("#") or call.search(line) == null:
				continue
			var j: int = i  # join continuation lines until the call's parentheses balance
			while line.count("(") > line.count(")") and j + 1 < lines.size():
				j += 1
				line += " " + lines[j].strip_edges()
			var code: String = quoted.sub(line, "\"\"", true)
			assert_null(name_var.search(code), "%s:%d logs a name variable: %s" % [path, i + 1, line.strip_edges()])


# --- profiles (Story 11.2, FR78) -------------------------------------------------

## Adds a profile `id` to the live save: profile_defaults() plus `fields`. Returns the stored Dictionary.
func _add_profile(id: String, fields: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = SaveSchema.profile_defaults()
	profile.merge(fields, true)
	_save.get_data()["profiles"][id] = profile
	return profile


func _profile_count() -> int:
	return (_save.get_data()["profiles"] as Dictionary).size()


func test_new_zombie_id_format_matches_the_first_profile_id() -> void:
	assert_eq(GameConstants.NEW_ZOMBIE_ID_FORMAT % 1, SaveSchema.DEFAULT_PROFILE_ID, "one id pattern")


func test_profile_ids_sort_naturally() -> void:
	var sut: PlayerDataScript = _make()
	_add_profile("p10")
	_add_profile("p2")
	assert_eq(sut.get_profile_ids(), [&"p1", &"p2", &"p10"] as Array[StringName])


func test_active_profile_id_reads_the_save() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq(sut.get_active_profile_id(), &"p1")
	_add_profile("p2")
	_save.get_data()["active_profile"] = "p2"
	assert_eq(sut.get_active_profile_id(), &"p2")


func test_profile_summary_of_the_active_and_an_inactive_profile() -> void:
	var sut: PlayerDataScript = _make_shop()
	_save.get_active_profile()["name"] = "Sam"
	_save.get_active_profile()["owned_items"] = ["hat_pumpkin"]
	_save.get_active_profile()["equipped"] = {"hat": "hat_pumpkin", "pet": ""}
	_add_profile("p2", {"name": "Bo", "owned_items": ["hat_witch", "pet_cute_ghost"],
			"equipped": {"hat": "hat_witch", "pet": "pet_cute_ghost"}})
	assert_eq_deep(sut.get_profile_summary(&"p1"), {"id": &"p1", "name": "Sam", "hat": &"hat_pumpkin", "pet": &""})
	assert_eq_deep(sut.get_profile_summary(&"p2"),
			{"id": &"p2", "name": "Bo", "hat": &"hat_witch", "pet": &"pet_cute_ghost"})


func test_profile_summary_reads_only_that_profiles_items_and_a_valid_name() -> void:
	var sut: PlayerDataScript = _make_shop()
	_save.get_active_profile()["owned_items"] = ["hat_pumpkin", "pet_cute_ghost"]
	# p2 wears what only p1 owns and has a junk name; p3 wears a locked hat and a junk pet value.
	_add_profile("p2", {"name": "!!!", "owned_items": ["hat_crown"],
			"equipped": {"hat": "hat_pumpkin", "pet": "pet_cute_ghost"}})
	_add_profile("p3", {"owned_items": ["hat_crown"], "equipped": {"hat": "hat_crown", "pet": 5}})
	assert_eq_deep(sut.get_profile_summary(&"p2"), {"id": &"p2", "name": "", "hat": &"", "pet": &""})
	assert_eq_deep(sut.get_profile_summary(&"p3"), {"id": &"p3", "name": "", "hat": &"", "pet": &""})


func test_profile_summary_of_an_unknown_id_is_empty_with_an_error() -> void:
	var sut: PlayerDataScript = _make()
	assert_eq_deep(sut.get_profile_summary(&"p9"), {})
	assert_push_error("get_profile_summary: unknown profile p9")


func test_has_named_zombie() -> void:
	var sut: PlayerDataScript = _make()
	assert_false(sut.has_named_zombie(), "fresh save")
	_save.get_active_profile()["name"] = "!!!"
	assert_false(sut.has_named_zombie(), "junk name")
	_add_profile("p2", {"name": "Bo"})
	assert_true(sut.has_named_zombie(), "an inactive named zombie counts")


func test_can_add_zombie_until_the_cap() -> void:
	var sut: PlayerDataScript = _make()
	for n: int in range(2, GameConstants.MAX_ZOMBIES + 1):
		assert_true(sut.can_add_zombie(), "%d profiles" % (n - 1))
		_add_profile("p%d" % n)
	assert_false(sut.can_add_zombie(), "at MAX_ZOMBIES")


func test_switch_profile_unknown_id_changes_nothing() -> void:
	var sut: PlayerDataScript = _make_counting()
	watch_signals(sut)
	assert_false(sut.switch_profile(&"p7"))
	assert_push_error("switch_profile: unknown profile p7")
	assert_eq(sut.get_active_profile_id(), &"p1")
	assert_signal_not_emitted(sut, "profile_replaced")
	assert_eq((_save as CountingSave).requests, 0)


func test_switch_profile_to_the_active_one_is_a_noop() -> void:
	var sut: PlayerDataScript = _make_counting()
	watch_signals(sut)
	assert_true(sut.switch_profile(&"p1"))
	assert_signal_not_emitted(sut, "profile_replaced")
	assert_eq((_save as CountingSave).requests, 0)


func test_switch_profile_reads_the_other_profile_and_leaves_the_old_one_alone() -> void:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	sut.catalogue = _test_catalogue()
	add_child_autofree(sut)
	_save.get_active_profile()["brains"] = 12
	_add_profile("p2", {"name": "Bo", "brains": 40, "owned_items": ["hat_witch"],
			"equipped": {"hat": "hat_witch", "pet": ""}, "settings": {"music_on": false, "sound_on": true},
			"tier": 3, "flags": {"welcome_bonus_claimed": true, "tutorial_seen": true, "placement_done": true}})
	var old: Dictionary = _save.get_active_profile().duplicate(true)
	var requests: int = (_save as CountingSave).requests
	watch_signals(sut)
	assert_true(sut.switch_profile(&"p2"))
	assert_signal_emit_count(sut, "profile_replaced", 1)
	assert_eq((_save as CountingSave).requests, requests + 1, "one save request")
	assert_eq(sut.get_active_profile_id(), &"p2")
	assert_eq(sut.get_brains(), 40)
	assert_eq(sut.get_equipped(&"hat"), &"hat_witch")
	assert_false(sut.get_setting(&"music_on"))
	assert_eq(sut.get_tier(), 3)
	assert_eq(sut.get_zombie_name(), "Bo")
	assert_eq_deep(_save.get_data()["profiles"]["p1"], old)
	await wait_process_frames(2)
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR.path_join("save.json")))
	assert_eq(written["active_profile"], "p2", "the switch is saved")


func test_switch_profile_places_an_mvp_profile() -> void:
	_put_fixture(FULL_PATH)
	var sut: PlayerDataScript = _make()
	var mvp: Dictionary = _save.get_active_profile().duplicate(true)
	mvp["tier"] = 0
	mvp["flags"]["placement_done"] = false
	_save.get_data()["profiles"]["p2"] = mvp
	assert_true(sut.switch_profile(&"p2"))
	assert_true(sut.get_flag(&"placement_done"), "_reconcile_tier ran on the switch")
	assert_gt(sut.get_tier(), 0)


func test_create_profile_adds_a_fresh_named_active_zombie() -> void:
	var sut: PlayerDataScript = _make_counting()
	sut.add_brains(9)
	assert_true(sut.set_zombie_name("Sam"))
	var requests: int = (_save as CountingSave).requests
	watch_signals(sut)
	assert_eq(sut.create_profile("  Bo  "), &"p2")
	var expected: Dictionary = SaveSchema.profile_defaults()
	expected["name"] = "Bo"
	assert_eq_deep(_save.get_data()["profiles"]["p2"], expected)
	assert_eq(sut.get_active_profile_id(), &"p2")
	assert_eq(sut.get_brains(), 0)
	assert_eq(sut.get_zombie_name(), "Bo")
	assert_signal_emit_count(sut, "profile_replaced", 1)
	assert_signal_emitted_with_parameters(sut, "zombie_name_changed", ["Bo"])
	assert_eq((_save as CountingSave).requests, requests + 1, "one save request")
	assert_eq(int(_save.get_data()["profiles"]["p1"]["brains"]), 9, "the first zombie keeps its brains")


func test_create_profile_reuses_the_lowest_free_id() -> void:
	var sut: PlayerDataScript = _make()
	_add_profile("p3", {"name": "Al"})
	assert_eq(sut.create_profile("Bo"), &"p2")
	assert_eq(sut.get_profile_ids(), [&"p1", &"p2", &"p3"] as Array[StringName])


func test_create_profile_refusals_change_nothing() -> void:
	var sut: PlayerDataScript = _make_counting()
	assert_true(sut.set_zombie_name("Sam"))
	var before: Dictionary = _save.get_data().duplicate(true)
	var requests: int = (_save as CountingSave).requests
	watch_signals(sut)
	assert_eq(sut.create_profile("#9#9#"), &"")
	assert_push_warning("create_profile: invalid name")
	assert_eq(sut.create_profile(""), &"")
	assert_eq(sut.create_profile("sam"), &"", "same name, other case")
	assert_push_warning("create_profile: name already used")
	assert_eq(sut.create_profile(" SAM "), &"")
	assert_push_warning_count(4)
	assert_eq_deep(_save.get_data(), before)
	assert_eq((_save as CountingSave).requests, requests)
	assert_signal_not_emitted(sut, "profile_replaced")
	assert_signal_not_emitted(sut, "zombie_name_changed")


func test_create_profile_refused_at_the_cap() -> void:
	var sut: PlayerDataScript = _make()
	for n: int in range(2, GameConstants.MAX_ZOMBIES + 1):
		_add_profile("p%d" % n)
	var before: Dictionary = _save.get_data().duplicate(true)
	assert_eq(sut.create_profile("Bo"), &"")
	assert_push_warning("create_profile: no room for another zombie")
	assert_eq(_profile_count(), GameConstants.MAX_ZOMBIES)
	assert_eq_deep(_save.get_data(), before)


func test_two_profiles_survive_a_reload() -> void:
	var sut: PlayerDataScript = _make()
	assert_true(sut.set_zombie_name("Sam"))
	sut.add_brains(5)
	assert_eq(sut.create_profile("Bo"), &"p2")
	await wait_process_frames(2)
	var reloaded: PlayerDataScript = _make()
	assert_eq(reloaded.get_profile_ids(), [&"p1", &"p2"] as Array[StringName])
	assert_eq(reloaded.get_active_profile_id(), &"p2")
	assert_eq(reloaded.get_zombie_name(), "Bo")
	assert_eq(reloaded.get_profile_summary(&"p1")["name"], "Sam")
	assert_eq(int(_save.get_data()["profiles"]["p1"]["brains"]), 5)
