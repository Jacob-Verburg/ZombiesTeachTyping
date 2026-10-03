extends GutTest
## SaveSchema: defaults, number normalising, default filling, migrations. Pure; only reads fixtures.

const FRESH_PATH: String = "res://tests/fixtures/saves/save_v1_fresh.json"
const FULL_PATH: String = "res://tests/fixtures/saves/save_v1_full.json"


func _fixture_text(path: String) -> String:
	return FileAccess.get_file_as_string(path).strip_edges(false, true)


func _parse(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "fixture must parse to a Dictionary")
	var data: Dictionary = parsed
	return data


func _fresh() -> Dictionary:
	return SaveSchema.normalize_numbers(_parse(_fixture_text(FRESH_PATH)))


func _full() -> Dictionary:
	return SaveSchema.normalize_numbers(_parse(_fixture_text(FULL_PATH)))


func _step_a(data: Dictionary) -> Dictionary:
	assert_eq(data["schema_version"], 1, "step a gets a v1 save")
	var trace: Array = data.get("trace", [])
	trace.append("a")
	data["trace"] = trace
	return data


func _step_b(data: Dictionary) -> Dictionary:
	assert_eq(data["schema_version"], 2, "step b gets a v2 save")
	var trace: Array = data.get("trace", [])
	trace.append("b")
	data["trace"] = trace
	return data


func test_defaults_match_v1_fixture() -> void:
	assert_eq_deep(SaveSchema.defaults(), _fresh())
	assert_eq(JSON.stringify(SaveSchema.defaults(), "\t"), _fixture_text(FRESH_PATH))
	assert_eq(SaveSchema.DEFAULT_PROFILE_ID, "p1")
	assert_eq(typeof(SaveSchema.defaults()["schema_version"]), TYPE_INT)


func test_defaults_returns_fresh_copies() -> void:
	var first: Dictionary = SaveSchema.defaults()
	first["profiles"]["p1"]["brains"] = 5
	first["profiles"]["p1"]["owned_items"].append("hat_pumpkin")
	first["profiles"]["p1"]["settings"]["music_on"] = false
	var second: Dictionary = SaveSchema.defaults()
	assert_eq(second["profiles"]["p1"]["brains"], 0)
	assert_eq(second["profiles"]["p1"]["owned_items"], [])
	assert_true(second["profiles"]["p1"]["settings"]["music_on"])
	assert_eq(SaveSchema.profile_defaults()["owned_items"], [])


func test_normalize_numbers_turns_integral_floats_into_ints() -> void:
	var data: Dictionary = {"a": 120.0, "b": 2.5, "c": "7", "d": true, "e": [1.0, {"f": 3.0, "g": [4.0]}]}
	var out: Dictionary = SaveSchema.normalize_numbers(data)
	assert_eq(typeof(out["a"]), TYPE_INT)
	assert_eq(out["a"], 120)
	assert_eq(typeof(out["b"]), TYPE_FLOAT)
	assert_eq(out["b"], 2.5)
	assert_eq(typeof(out["c"]), TYPE_STRING)
	assert_eq(typeof(out["d"]), TYPE_BOOL)
	assert_eq(typeof(out["e"][0]), TYPE_INT)
	assert_eq(typeof(out["e"][1]["f"]), TYPE_INT)
	assert_eq(typeof(out["e"][1]["g"][0]), TYPE_INT)


func test_fill_adds_missing_fields() -> void:
	var data: Dictionary = _fresh()
	var p1: Dictionary = data["profiles"]["p1"]
	p1["flags"].erase("tutorial_seen")
	p1.erase("settings")
	p1["best_wpm"].erase("zombie_run")
	data.erase("active_profile")
	SaveSchema.fill_defaults(data)
	assert_eq(data["active_profile"], "p1")
	assert_eq(data["profiles"]["p1"]["flags"]["tutorial_seen"], false)
	assert_eq_deep(data["profiles"]["p1"]["settings"], {"music_on": true, "sound_on": true})
	assert_eq(data["profiles"]["p1"]["best_wpm"]["zombie_run"], 0)
	assert_eq_deep(data, SaveSchema.defaults())


func test_fill_keeps_unknown_fields() -> void:
	var data: Dictionary = _full()
	data["profiles"]["p1"]["best_wpm"]["horde_rush"] = 9
	SaveSchema.fill_defaults(data)
	assert_eq(data["x_future_root"], "keep me")
	assert_eq_deep(data["profiles"]["p1"]["x_future_profile"], {"kept": true})
	assert_eq(data["profiles"]["p1"]["best_wpm"]["horde_rush"], 9)
	assert_eq(data["profiles"]["p1"]["best_wpm"]["zombie_run"], 14)
	assert_eq(data["profiles"]["p1"]["run_history"].size(), 2)
	assert_push_warning_count(0)


func test_fill_replaces_wrong_types_with_defaults() -> void:
	var data: Dictionary = _fresh()
	data["profiles"]["p1"]["brains"] = "lots"
	data["profiles"]["p1"]["flags"] = []
	SaveSchema.fill_defaults(data)
	assert_eq(data["profiles"]["p1"]["brains"], 0)
	assert_eq_deep(
		data["profiles"]["p1"]["flags"],
		{"welcome_bonus_claimed": false, "tutorial_seen": false, "placement_done": false}
	)
	assert_push_warning("bad type at profiles/p1/brains")
	assert_push_warning("bad type at profiles/p1/flags")


func test_fill_fills_every_profile() -> void:
	var data: Dictionary = _fresh()
	data["profiles"]["p2"] = {"name": "Zed", "brains": 3}
	SaveSchema.fill_defaults(data)
	var p2: Dictionary = data["profiles"]["p2"]
	assert_eq(p2["name"], "Zed")
	assert_eq(p2["brains"], 3)
	assert_eq(p2["tier"], 0)
	assert_eq(p2["owned_items"], [])
	assert_eq_deep(p2["equipped"], {"hat": "", "pet": ""})
	assert_eq(p2["run_history"], [])


func test_fill_repairs_profiles_and_active_profile() -> void:
	var empty: Dictionary = {"schema_version": 1, "active_profile": "p1", "profiles": {}}
	SaveSchema.fill_defaults(empty)
	assert_eq_deep(empty, SaveSchema.defaults())

	var stray: Dictionary = _fresh()
	stray["active_profile"] = "zz"
	SaveSchema.fill_defaults(stray)
	assert_eq(stray["active_profile"], "p1")
	assert_push_warning("active profile zz missing")

	var no_p1: Dictionary = _fresh()
	no_p1["profiles"] = {"p3": SaveSchema.profile_defaults(), "p2": SaveSchema.profile_defaults()}
	SaveSchema.fill_defaults(no_p1)
	assert_eq(no_p1["active_profile"], "p2", "first key in sorted order")
	assert_push_warning("active profile p1 missing")


func test_migrate_runs_steps_in_order() -> void:
	var steps: Array[Callable] = [_step_a, _step_b]
	var data: Dictionary = SaveSchema.migrate(_fresh(), steps, 3)
	assert_eq(data["trace"], ["a", "b"])
	assert_eq(data["schema_version"], 3)


func test_migrate_noop_at_current() -> void:
	var data: Dictionary = SaveSchema.migrate(SaveSchema.defaults())
	assert_eq_deep(data, SaveSchema.defaults())
	assert_eq(SaveSchema.migration_steps().size(), GameConstants.CURRENT_SCHEMA - 1)


func test_migrate_starts_mid_chain() -> void:
	var v2: Dictionary = _fresh()
	v2["schema_version"] = 2
	var steps: Array[Callable] = [_step_a, _step_b]
	var data: Dictionary = SaveSchema.migrate(v2, steps, 3)
	assert_eq(data["trace"], ["b"])
	assert_eq(data["schema_version"], 3)


func test_migrate_treats_bad_version_as_1() -> void:
	var data: Dictionary = _fresh()
	data.erase("schema_version")
	var steps: Array[Callable] = [_step_a]
	SaveSchema.migrate(data, steps, 2)
	assert_eq(data["trace"], ["a"])
	assert_eq(data["schema_version"], 2)
	assert_push_warning("schema_version")


func test_migrate_missing_step_logs_error() -> void:
	var steps: Array[Callable] = []
	var data: Dictionary = SaveSchema.migrate(_fresh(), steps, 2)
	assert_eq(data["schema_version"], 1)
	assert_push_error("no migration step 1 -> 2")


func _step_null(_data: Dictionary) -> Variant:
	return null


func test_migrate_step_returning_null_logs_error_and_keeps_data() -> void:
	var steps: Array[Callable] = [_step_null]
	var data: Dictionary = SaveSchema.migrate(_fresh(), steps, 2)
	assert_eq(data["schema_version"], 1)
	assert_true(data.has("profiles"))
	assert_push_error("returned no save")


func test_normalize_numbers_leaves_huge_floats_alone() -> void:
	var out: Dictionary = SaveSchema.normalize_numbers({"big": 1e30, "ok": 12.0})
	assert_eq(typeof(out["big"]), TYPE_FLOAT)
	assert_eq(out["ok"], 12)


func test_migrate_future_version_left_alone() -> void:
	var future: Dictionary = _fresh()
	future["schema_version"] = 9
	var data: Dictionary = SaveSchema.migrate(future)
	assert_eq(data["schema_version"], 9)
	assert_eq_deep(data["profiles"], SaveSchema.defaults()["profiles"])
	assert_push_warning("newer than this build")


func test_prepare_round_trips_full_fixture() -> void:
	var raw: Variant = JSON.parse_string(_fixture_text(FULL_PATH))
	var first: Dictionary = SaveSchema.prepare(raw)
	assert_eq(typeof(first["profiles"]["p1"]["brains"]), TYPE_INT)
	assert_eq(typeof(first["schema_version"]), TYPE_INT)
	var text: String = JSON.stringify(first, "\t")
	assert_false(text.contains("\"brains\": 0.0"), "no whole number is written as a float")
	assert_false(text.contains("\"schema_version\": 1.0"), "no whole number is written as a float")
	assert_eq(text, _fixture_text(FULL_PATH), "full fixture is already in canonical form")
	var second: Dictionary = SaveSchema.prepare(JSON.parse_string(text))
	assert_eq_deep(second, first)
	assert_eq(typeof(second["profiles"]["p1"]["run_history"][0]["per_key"]["f"][2]["g"]), TYPE_INT)
