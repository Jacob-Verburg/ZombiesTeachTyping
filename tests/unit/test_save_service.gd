extends GutTest
## SaveService: load fallbacks, atomic write with backup, coalescing, immediate writes, export.
## Always a fresh instance whose save_dir points at TEST_DIR (set before add_child, because _ready()
## loads). The live autoload is only read, never driven, so the real user://save.json is never touched.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const TEST_DIR: String = "user://test_save_service/"
const NESTED_DIR: String = "user://test_save_service/nested/"
const FRESH_PATH: String = "res://tests/fixtures/saves/save_v1_fresh.json"
const FULL_PATH: String = "res://tests/fixtures/saves/save_v1_full.json"
const CORRUPT_PATH: String = "res://tests/fixtures/saves/save_corrupt.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()


func after_each() -> void:
	_clear()


func _clear() -> void:
	for dir: String in [NESTED_DIR, TEST_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file_name: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file_name))
	if DirAccess.dir_exists_absolute(NESTED_DIR):
		DirAccess.remove_absolute(NESTED_DIR)


func _make(dir: String = TEST_DIR) -> SaveServiceScript:
	var sut: SaveServiceScript = SaveServiceScript.new()
	sut.save_dir = dir
	add_child_autofree(sut)
	return sut


func _put(file_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read(file_name: String) -> String:
	return FileAccess.get_file_as_string(TEST_DIR.path_join(file_name))


func _exists(file_name: String) -> bool:
	return FileAccess.file_exists(TEST_DIR.path_join(file_name))


func _fixture(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _prepared(path: String) -> Dictionary:
	return SaveSchema.prepare(JSON.parse_string(_fixture(path)))


func test_fresh_start_uses_defaults_and_writes_nothing() -> void:
	var sut: SaveServiceScript = _make()
	assert_eq_deep(sut.get_data(), SaveSchema.defaults())
	assert_eq_deep(sut.get_active_profile(), SaveSchema.profile_defaults())
	assert_eq(DirAccess.get_files_at(TEST_DIR).size(), 0, "loading never writes")
	assert_eq(sut.last_write_ticks_msec, -1)


func test_write_creates_save_json_and_no_tmp() -> void:
	var sut: SaveServiceScript = _make()
	assert_eq(sut.save_now(), OK)
	assert_true(_exists("save.json"))
	assert_false(_exists("save.tmp"), "no temp file left behind")
	assert_false(_exists("save.bak"), "nothing to back up on the first write")
	assert_eq(_read("save.json"), sut.export_json())
	assert_gt(sut.last_write_ticks_msec, -1)


func test_second_write_keeps_previous_as_bak() -> void:
	var sut: SaveServiceScript = _make()
	sut.save_now()
	var first_text: String = _read("save.json")
	sut.get_active_profile()["brains"] = 7
	assert_eq(sut.save_now(), OK)
	assert_eq(_read("save.bak"), first_text)
	var written: Dictionary = JSON.parse_string(_read("save.json"))
	assert_eq(int(written["profiles"]["p1"]["brains"]), 7)
	assert_false(_exists("save.tmp"))


func test_round_trip_full_fixture() -> void:
	_put("save.json", _fixture(FULL_PATH))
	var sut: SaveServiceScript = _make()
	var expected: Dictionary = _prepared(FULL_PATH)
	assert_eq_deep(sut.get_data(), expected)
	assert_eq(sut.get_data()["x_future_root"], "keep me")
	assert_eq(sut.save_now(), OK)
	var reloaded: SaveServiceScript = _make()
	assert_eq_deep(reloaded.get_data(), expected)
	assert_eq(typeof(reloaded.get_active_profile()["brains"]), TYPE_INT)


func test_corrupt_main_falls_back_to_bak() -> void:
	_put("save.json", _fixture(CORRUPT_PATH))
	_put("save.bak", _fixture(FULL_PATH))
	var sut: SaveServiceScript = _make()
	assert_eq_deep(sut.get_data(), _prepared(FULL_PATH))
	assert_push_warning("parse failed")
	assert_push_warning("using save.bak")
	assert_push_error_count(0)


func test_both_corrupt_uses_defaults() -> void:
	_put("save.json", _fixture(CORRUPT_PATH))
	_put("save.bak", _fixture(CORRUPT_PATH))
	var sut: SaveServiceScript = _make()
	assert_eq_deep(sut.get_data(), SaveSchema.defaults())
	assert_push_warning("parse failed")
	assert_push_warning("parse failed")
	assert_push_warning("no valid save")
	assert_push_error_count(0, "a corrupt file is not an error")


func test_non_dictionary_or_empty_save_counts_as_unreadable() -> void:
	_put("save.json", "[1, 2, 3]")
	_put("save.bak", "{}")
	var sut: SaveServiceScript = _make()
	assert_eq_deep(sut.get_data(), SaveSchema.defaults())
	assert_push_warning("not a save")
	assert_push_warning("not a save")
	assert_push_warning("no valid save")


func test_corrupt_main_is_not_rotated_into_bak() -> void:
	_put("save.json", _fixture(CORRUPT_PATH))
	_put("save.bak", _fixture(FULL_PATH))
	var sut: SaveServiceScript = _make()
	assert_eq(sut.save_now(), OK)
	assert_eq(_read("save.bak"), _fixture(FULL_PATH), "the only good copy survives")
	assert_eq(_read("save.json"), sut.export_json())
	assert_push_warning("parse failed")
	assert_push_warning("using save.bak")


func test_missing_fields_filled_on_load() -> void:
	_put("save.json", '{"schema_version": 1, "profiles": {"p1": {"brains": 12}}}')
	var sut: SaveServiceScript = _make()
	var p1: Dictionary = sut.get_active_profile()
	assert_eq(p1["brains"], 12)
	assert_eq(typeof(p1["brains"]), TYPE_INT)
	assert_eq_deep(p1["settings"], {"music_on": true, "sound_on": true})
	assert_eq(sut.get_data()["active_profile"], "p1")


func test_unknown_fields_kept_on_load() -> void:
	_put("save.json", _fixture(FULL_PATH))
	var sut: SaveServiceScript = _make()
	sut.save_now()
	var written: Dictionary = JSON.parse_string(_read("save.json"))
	assert_eq(written["x_future_root"], "keep me")
	assert_eq_deep(written["profiles"]["p1"]["x_future_profile"], {"kept": true})


func test_request_save_coalesces_same_frame() -> void:
	var sut: SaveServiceScript = _make()
	watch_signals(sut)
	sut.request_save()
	sut.request_save()
	sut.request_save()
	assert_signal_emit_count(sut, "save_written", 0, "nothing written until the frame ends")
	await wait_process_frames(2)
	assert_signal_emit_count(sut, "save_written", 1)
	assert_true(_exists("save.json"))
	sut.request_save()
	await wait_process_frames(2)
	assert_signal_emit_count(sut, "save_written", 2)


func test_save_now_writes_immediately() -> void:
	var sut: SaveServiceScript = _make()
	watch_signals(sut)
	sut.save_now()
	assert_signal_emit_count(sut, "save_written", 1)


func test_save_now_creates_missing_dir() -> void:
	var sut: SaveServiceScript = _make(NESTED_DIR)
	assert_eq(sut.save_now(), OK)
	assert_true(FileAccess.file_exists(NESTED_DIR.path_join("save.json")))


func test_visibility_hidden_writes_immediately_when_dirty() -> void:
	var sut: SaveServiceScript = _make()
	sut.request_save()
	sut._on_web_platform_visibility_hidden()
	assert_true(_exists("save.json"))


func test_visibility_hidden_clean_writes_nothing() -> void:
	var sut: SaveServiceScript = _make()
	sut._on_web_platform_visibility_hidden()
	assert_false(_exists("save.json"))


func test_connected_to_visibility_hidden() -> void:
	var sut: SaveServiceScript = _make()
	assert_true(WebPlatform.visibility_hidden.is_connected(sut._on_web_platform_visibility_hidden))


func test_close_request_writes_immediately_when_dirty() -> void:
	var sut: SaveServiceScript = _make()
	sut.request_save()
	sut._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(_exists("save.json"))


func test_close_request_clean_writes_nothing() -> void:
	var sut: SaveServiceScript = _make()
	sut._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_false(_exists("save.json"))


func test_newer_schema_save_is_never_written_back() -> void:
	var future: Dictionary = SaveSchema.defaults()
	future["schema_version"] = GameConstants.CURRENT_SCHEMA + 1
	var text: String = JSON.stringify(future, "	")
	_put("save.json", text)
	var sut: SaveServiceScript = _make()
	assert_eq(sut.save_now(), ERR_LOCKED)
	sut.request_save()
	await wait_process_frames(2)
	assert_eq(_read("save.json"), text, "the newer build's save is untouched")
	assert_false(_exists("save.bak"))
	assert_false(_exists("save.tmp"))
	assert_push_warning("newer than this build")


func test_export_json_matches_file_and_touches_nothing() -> void:
	var sut: SaveServiceScript = _make()
	var exported: String = sut.export_json()
	assert_eq(DirAccess.get_files_at(TEST_DIR).size(), 0, "export never touches the file system")
	assert_eq_deep(SaveSchema.prepare(JSON.parse_string(exported)), sut.get_data())
	assert_eq(exported, _fixture(FRESH_PATH).strip_edges(false, true))
	sut.save_now()
	assert_eq(_read("save.json"), sut.export_json())


func test_disconnects_on_exit() -> void:
	var sut: SaveServiceScript = SaveServiceScript.new()
	sut.save_dir = TEST_DIR
	add_child(sut)
	var handler: Callable = sut._on_web_platform_visibility_hidden
	assert_true(WebPlatform.visibility_hidden.is_connected(handler))
	remove_child(sut)
	assert_false(WebPlatform.visibility_hidden.is_connected(handler))
	sut.free()
