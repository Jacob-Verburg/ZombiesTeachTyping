extends GutTest
## PlayerData: brains and settings mutations, their signals, coalesced save requests, live profile reads.
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
