extends GutTest
## Run result (Story 2.3): built at run end, derived stats, and the save's run record.

const FULL_PATH: String = "res://tests/fixtures/saves/save_v1_full.json"


func _per_key() -> Dictionary:
	return {"f": [12, 2, {"g": 2}], "j": [10, 0, {}]}


func _make(duration_s: float = 120.0, completed_words: int = 0) -> RunResult:
	return RunResult.create(
		&"zombie_run", 1790000000, duration_s, 100, 5, _per_key(), 35, 10, "all",
		GameConstants.END_REASON_TIMER, completed_words)


func _fixture_record() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FULL_PATH))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "fixture must parse to a Dictionary")
	var data: Dictionary = parsed
	var history: Array = data["profiles"]["p1"]["run_history"]
	var record: Dictionary = history[0]
	return record


func test_end_reason_constants() -> void:
	assert_eq(GameConstants.END_REASON_TIMER, &"timer")
	assert_eq(GameConstants.END_REASON_CAUGHT, &"caught")
	assert_eq(GameConstants.END_REASON_ESCAPED, &"escaped")


func test_create_fills_every_field() -> void:
	var r: RunResult = _make()
	assert_eq(r.level_id, &"zombie_run")
	assert_eq(r.timestamp, 1790000000)
	assert_eq(r.duration_s, 120.0)
	assert_eq(r.keys_typed, 100)
	assert_eq(r.errors, 5)
	assert_eq(r.completed_words, 0)
	assert_eq(r.brains, 35)
	assert_eq(r.bonus_brains, 10)
	assert_eq(r.letter_pool_or_tier, "all")
	assert_eq_deep(r.per_key, _per_key())
	assert_eq(r.end_reason, GameConstants.END_REASON_TIMER)


func test_wpm_and_accuracy_are_computed() -> void:
	var r: RunResult = _make()
	assert_eq(r.wpm, 10)
	assert_eq(r.accuracy, 95)


func test_new_result_is_valid_without_arguments() -> void:
	var r: RunResult = RunResult.new()
	assert_not_null(r)
	assert_eq(r.keys_typed, 0)


func test_completed_words_affect_wpm_only() -> void:
	# 100 keys + 20 implied spaces in 60 s = 24 WPM; without words it is 20.
	var with_words: RunResult = _make(60.0, 20)
	var without: RunResult = _make(60.0, 0)
	assert_eq(without.wpm, 20)
	assert_eq(with_words.wpm, 24)
	assert_eq(with_words.accuracy, without.accuracy)
	assert_eq(with_words.keys_typed, 100)
	assert_eq(with_words.completed_words, 20)
	assert_false(with_words.to_record().has("completed_words"))
	assert_false(with_words.to_record().has("bonus_brains"))


func test_per_key_is_copied_on_the_way_in() -> void:
	var source: Dictionary = _per_key()
	var r: RunResult = RunResult.create(
		&"zombie_run", 1, 60.0, 1, 0, source, 0, 0, "all", GameConstants.END_REASON_TIMER)
	var entry: Array = source["f"]
	entry[0] = 99
	var typed: Dictionary = entry[2]
	typed["h"] = 7
	assert_eq_deep(r.per_key, _per_key())


func test_per_key_is_copied_on_the_way_out() -> void:
	var r: RunResult = _make()
	var record: Dictionary = r.to_record()
	var typed: Dictionary = record["per_key"]["f"][2]
	typed["g"] = 50
	typed["k"] = 1
	assert_eq_deep(r.per_key, _per_key())


func test_total_brains_adds_bonus() -> void:
	var r: RunResult = _make()
	assert_eq(r.total_brains(), 45)
	assert_eq(r.to_record()["brains"], 45)


func test_lesson_time() -> void:
	assert_eq(_make(120.0).lesson_time(), "2:00")
	assert_eq(_make(119.7).lesson_time(), "1:59")


func test_record_key_set_matches_fixture() -> void:
	var keys: Array = _make().to_record().keys()
	keys.sort()
	var expected: Array = _fixture_record().keys()
	expected.sort()
	assert_eq_deep(keys, expected)


func test_record_types() -> void:
	var record: Dictionary = _make(119.7).to_record()
	var strings: Array[String] = ["level_id", "end_reason", "letter_pool_or_tier"]
	for key: String in record.keys():
		if key in strings:
			assert_eq(typeof(record[key]), TYPE_STRING, "%s is a String" % key)
		elif key == "per_key":
			assert_eq(typeof(record[key]), TYPE_DICTIONARY)
		else:
			assert_eq(typeof(record[key]), TYPE_INT, "%s is an int" % key)
	assert_eq(record["duration_s"], 119)
	assert_eq(record["level_id"], "zombie_run")
	assert_eq(record["end_reason"], "timer")
	assert_eq_deep(record["per_key"], _per_key())


func test_record_non_finite_duration_is_zero() -> void:
	for bad: float in [NAN, INF, -INF]:
		var record: Dictionary = _make(bad).to_record()
		assert_eq(record["duration_s"], 0, "non-finite duration saves as 0")
		assert_eq(typeof(record["duration_s"]), TYPE_INT)
		assert_eq(record["wpm"], 0)


func test_record_values() -> void:
	var record: Dictionary = _make().to_record()
	assert_eq(record["timestamp"], 1790000000)
	assert_eq(record["keys_typed"], 100)
	assert_eq(record["errors"], 5)
	assert_eq(record["wpm"], 10)
	assert_eq(record["accuracy"], 95)
	assert_eq(record["letter_pool_or_tier"], "all")


func test_record_survives_save_round_trip() -> void:
	var record: Dictionary = _make().to_record()
	var save: Dictionary = SaveSchema.defaults()
	var history: Array = save["profiles"]["p1"]["run_history"]
	history.append(record)
	var text: String = JSON.stringify(save, "\t")
	assert_string_contains(text, "\"duration_s\": 120")
	assert_false(text.contains("120.0"), "whole numbers are written without .0")
	var parsed: Variant = JSON.parse_string(text)
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	var loaded: Dictionary = SaveSchema.prepare(parsed)
	var loaded_history: Array = loaded["profiles"]["p1"]["run_history"]
	assert_eq(loaded_history.size(), 1)
	assert_eq_deep(loaded_history[0], record)


func test_end_reasons_round_trip_as_plain_strings() -> void:
	var reasons: Array[StringName] = [
		GameConstants.END_REASON_TIMER, GameConstants.END_REASON_CAUGHT, GameConstants.END_REASON_ESCAPED,
	]
	var expected: Array[String] = ["timer", "caught", "escaped"]
	for i: int in reasons.size():
		var r: RunResult = RunResult.create(&"zombie_run", 1, 10.0, 1, 0, {}, 0, 0, "all", reasons[i])
		var record: Dictionary = r.to_record()
		assert_eq(typeof(record["end_reason"]), TYPE_STRING)
		assert_eq(record["end_reason"], expected[i])
		var back: Variant = JSON.parse_string(JSON.stringify(record))
		var back_record: Dictionary = back
		assert_eq(back_record["end_reason"], expected[i])
