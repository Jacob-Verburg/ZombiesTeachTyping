extends GutTest
## SaveSchema: defaults, number normalising, default filling, migrations (v1 -> v2 level_unlocks backfill,
## Story 6.8; v2 -> v3 used_passages, Story 8.2). Pure; only reads fixtures (and the shipped level registry
## in one guard test).

## The current-schema fresh save; the v1 and v2 fixtures are kept byte-identical as migration inputs.
const FRESH_PATH: String = "res://tests/fixtures/saves/save_v3_fresh.json"
const V2_FRESH_PATH: String = "res://tests/fixtures/saves/save_v2_fresh.json"
const V1_FRESH_PATH: String = "res://tests/fixtures/saves/save_v1_fresh.json"
const FULL_PATH: String = "res://tests/fixtures/saves/save_v1_full.json"
const BACKFILL_PATH: String = "res://tests/fixtures/saves/save_v1_backfill.json"
const REGISTRY_PATH: String = "res://data/levels/level_registry.tres"
const UNSEEN: Dictionary = {"moment_seen": false, "chosen": false}


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


## A v1 save, for the stub-step chain tests (their first step expects schema_version 1).
func _v1_fresh() -> Dictionary:
	return SaveSchema.normalize_numbers(_parse(_fixture_text(V1_FRESH_PATH)))


func _backfill() -> Dictionary:
	return SaveSchema.normalize_numbers(_parse(_fixture_text(BACKFILL_PATH)))


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


func test_defaults_match_v3_fixture() -> void:
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
	var empty: Dictionary = {"schema_version": GameConstants.CURRENT_SCHEMA, "active_profile": "p1", "profiles": {}}
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
	var data: Dictionary = SaveSchema.migrate(_v1_fresh(), steps, 3)
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
	var data: Dictionary = _v1_fresh()
	data.erase("schema_version")
	var steps: Array[Callable] = [_step_a]
	SaveSchema.migrate(data, steps, 2)
	assert_eq(data["trace"], ["a"])
	assert_eq(data["schema_version"], 2)
	assert_push_warning("schema_version")


func test_migrate_missing_step_logs_error() -> void:
	var steps: Array[Callable] = []
	var data: Dictionary = SaveSchema.migrate(_v1_fresh(), steps, 2)
	assert_eq(data["schema_version"], 1)
	assert_push_error("no migration step 1 -> 2")


func _step_null(_data: Dictionary) -> Variant:
	return null


func test_migrate_step_returning_null_logs_error_and_keeps_data() -> void:
	var steps: Array[Callable] = [_step_null]
	var data: Dictionary = SaveSchema.migrate(_v1_fresh(), steps, 2)
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
	assert_false(text.contains("\"schema_version\": 3.0"), "no whole number is written as a float")
	# The v1 fixture is canonical; prepare() only adds what migrate_1_to_2 adds (its two timer runs of
	# Zombie Run open Horde Rush) and what migrate_2_to_3 adds, and bumps the version.
	var expected: Dictionary = _full()
	expected["schema_version"] = 3
	expected["profiles"]["p1"]["level_unlocks"] = {"horde_rush": UNSEEN.duplicate()}
	expected["profiles"]["p1"]["used_passages"] = []
	assert_eq(text, JSON.stringify(expected, "\t"), "full fixture is canonical apart from the v2 and v3 additions")
	var second: Dictionary = SaveSchema.prepare(JSON.parse_string(text))
	assert_eq_deep(second, first)
	assert_eq(typeof(second["profiles"]["p1"]["run_history"][0]["per_key"]["f"][2]["g"]), TYPE_INT)


func test_migrate_1_to_2_backfills_from_timer_runs() -> void:
	var data: Dictionary = SaveSchema.migrate_1_to_2(_backfill())
	var p1: Dictionary = data["profiles"]["p1"]
	assert_eq_deep(p1["level_unlocks"], {"horde_rush": UNSEEN})
	assert_false(p1["level_unlocks"].has("pitchfork_panic"), "a caught Horde Rush run is not a finish")
	assert_eq(p1["run_history"].size(), 3, "history untouched, junk entry included")
	assert_eq_deep(data["profiles"]["p2"]["level_unlocks"], {})
	assert_push_warning_count(0)


func test_migrate_1_to_2_on_full_fixture() -> void:
	var data: Dictionary = SaveSchema.migrate_1_to_2(_full())
	assert_eq_deep(data["profiles"]["p1"]["level_unlocks"], {"horde_rush": UNSEEN})
	assert_eq(data["x_future_root"], "keep me", "unknown fields survive")
	assert_eq_deep(data["profiles"]["p1"]["x_future_profile"], {"kept": true})


func test_migrate_1_to_2_opens_pitchfork_after_a_timer_horde_rush() -> void:
	var data: Dictionary = _backfill()
	data["profiles"]["p1"]["run_history"][1]["end_reason"] = "timer"
	SaveSchema.migrate_1_to_2(data)
	assert_eq_deep(data["profiles"]["p1"]["level_unlocks"], {"horde_rush": UNSEEN, "pitchfork_panic": UNSEEN})


func test_migrate_1_to_2_survives_junk() -> void:
	var no_profiles: Dictionary = {"schema_version": 1, "profiles": "nope"}
	assert_eq_deep(SaveSchema.migrate_1_to_2(no_profiles), {"schema_version": 1, "profiles": "nope"})
	assert_push_warning("profiles is not a dictionary")
	var missing: Dictionary = {"schema_version": 1}
	assert_eq_deep(SaveSchema.migrate_1_to_2(missing), {"schema_version": 1})
	var data: Dictionary = {"profiles": {
		"bad": 5,
		"no_history": {"run_history": "lots"},
		"junk_records": {"run_history": [null, 3, "x", [], {"level_id": "zombie_run"}, {"end_reason": "timer"}]},
		"bad_unlocks": {"level_unlocks": [], "run_history": [{"level_id": "zombie_run", "end_reason": "timer"}]},
	}}
	SaveSchema.migrate_1_to_2(data)
	assert_eq(data["profiles"]["bad"], 5, "a junk profile is left for fill_defaults")
	assert_push_warning("profiles/bad is not a dictionary")
	assert_eq_deep(data["profiles"]["no_history"]["level_unlocks"], {})
	assert_eq_deep(data["profiles"]["junk_records"]["level_unlocks"], {})
	assert_eq_deep(data["profiles"]["bad_unlocks"]["level_unlocks"], {"horde_rush": UNSEEN})


func test_migrate_1_to_2_keeps_existing_entries() -> void:
	var data: Dictionary = _full()
	var seen: Dictionary = {"moment_seen": true, "chosen": true}
	data["profiles"]["p1"]["level_unlocks"] = {"horde_rush": seen, "x_level": {"kept": 1}}
	SaveSchema.migrate_1_to_2(data)
	assert_eq_deep(data["profiles"]["p1"]["level_unlocks"], {"horde_rush": seen, "x_level": {"kept": 1}})


func test_prepare_v1_reaches_v3() -> void:
	var data: Dictionary = SaveSchema.prepare(JSON.parse_string(_fixture_text(V1_FRESH_PATH)))
	assert_eq(data["schema_version"], 3)
	assert_eq_deep(data, SaveSchema.defaults())
	var backfilled: Dictionary = SaveSchema.prepare(JSON.parse_string(_fixture_text(BACKFILL_PATH)))
	assert_eq(backfilled["schema_version"], 3)
	assert_eq_deep(backfilled["profiles"]["p1"]["level_unlocks"], {"horde_rush": UNSEEN})
	assert_eq_deep(backfilled["profiles"]["p2"]["level_unlocks"], {})
	assert_eq_deep(backfilled["profiles"]["p1"]["used_passages"], [])
	assert_eq_deep(backfilled["profiles"]["p2"]["used_passages"], [])
	assert_eq(SaveSchema.migration_steps().size(), 2)
	assert_eq(SaveSchema.migration_steps()[0], Callable(SaveSchema.migrate_1_to_2), "registered at index 0")
	assert_eq(SaveSchema.migration_steps()[1], Callable(SaveSchema.migrate_2_to_3), "registered at index 1")


func test_migrate_2_to_3_adds_used_passages() -> void:
	var v2: Dictionary = SaveSchema.normalize_numbers(_parse(_fixture_text(V2_FRESH_PATH)))
	assert_eq(v2["schema_version"], 2, "the v2 fixture is a v2 save")
	assert_false(v2["profiles"]["p1"].has("used_passages"))
	var data: Dictionary = SaveSchema.migrate(v2)
	assert_eq(data["schema_version"], 3)
	assert_eq_deep(data["profiles"]["p1"]["used_passages"], [])
	assert_eq_deep(SaveSchema.prepare(_parse(_fixture_text(V2_FRESH_PATH))), SaveSchema.defaults())
	assert_push_warning_count(0)


func test_migrate_2_to_3_keeps_existing_list() -> void:
	var v2: Dictionary = SaveSchema.normalize_numbers(_parse(_fixture_text(V2_FRESH_PATH)))
	v2["profiles"]["p1"]["used_passages"] = ["t3_01", "t5_13"]
	SaveSchema.migrate_2_to_3(v2)
	assert_eq_deep(v2["profiles"]["p1"]["used_passages"], ["t3_01", "t5_13"])


func test_migrate_2_to_3_survives_junk() -> void:
	var no_profiles: Dictionary = {"schema_version": 2, "profiles": "nope"}
	assert_eq_deep(SaveSchema.migrate_2_to_3(no_profiles), {"schema_version": 2, "profiles": "nope"})
	assert_push_warning("migrate_2_to_3: profiles is not a dictionary")
	var missing: Dictionary = {"schema_version": 2}
	assert_eq_deep(SaveSchema.migrate_2_to_3(missing), {"schema_version": 2})
	var data: Dictionary = {"profiles": {"bad": 5, "text": {"used_passages": "t3_01"}, "ok": {}}}
	SaveSchema.migrate_2_to_3(data)
	assert_eq(data["profiles"]["bad"], 5, "a junk profile is left for fill_defaults")
	assert_push_warning("migrate_2_to_3: profiles/bad is not a dictionary")
	assert_eq_deep(data["profiles"]["text"]["used_passages"], [])
	assert_eq_deep(data["profiles"]["ok"]["used_passages"], [])


## The frozen migration chain matches the shipped registry. If a later story changes the chain on purpose,
## this test is updated to say so; the migration itself stays as it was (it describes v1 saves).
func test_v2_chain_matches_registry() -> void:
	var registry: LevelRegistry = load(REGISTRY_PATH) as LevelRegistry
	var chain: Dictionary = {}
	for entry: LevelEntry in registry.entries:
		if entry != null and entry.unlocked_by != &"":
			chain[String(entry.id)] = String(entry.unlocked_by)
	assert_eq_deep(chain, SaveSchema.V2_UNLOCKED_BY)
