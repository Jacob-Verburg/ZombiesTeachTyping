extends GutTest
## Story 11.3 (FR78, ADR-2): every zombie's progress is fully separate. A table of every public PlayerData mutation
## runs on the active profile, and after each row every other profile is deep-equal to its snapshot, in memory and in
## the written save.json. A guard fails on a public PlayerData method that is in neither the table nor the read-only
## allow-list, so a new setter can't skip this check; a coverage test fails on a profile field no row changes.
## Also: switching back and forth keeps each zombie's state (and survives a reload), no Array/Dictionary is shared
## between two profiles, and the F8 reset still wipes every zombie (pinned on purpose).
## Always a temp SaveService (save_dir = TEST_DIR), a code-built catalogue and level registry: the real save is never
## touched.

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_profile_isolation/"
const HAT_PRICE: int = 30
const HAT2_PRICE: int = 45
const PET_PRICE: int = 20
## Public PlayerData methods that change no profile field (reads), or that change which profile is active or the
## whole save (profile-level, covered by their own tests below and in test_player_data.gd). Every other public
## method must be a row of _mutations(). Any name starting with get_ is a read.
const READ_ONLY_OR_PROFILE_LEVEL: Array[String] = [
	"owns", "has_named_zombie", "can_add_zombie", "switch_profile", "create_profile", "reset_all",
]


## A SaveService that counts request_save() calls.
class CountingSave extends SaveServiceScript:
	var requests: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()


var _save: CountingSave = null


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


func _cosmetic(id: StringName, slot: CosmeticItem.Slot, price: int) -> CosmeticItem:
	var item: CosmeticItem = CosmeticItem.new()
	item.id = id
	item.slot = slot
	item.price = price
	item.row = 1
	item.is_available = true
	return item


## Test prices, not the shipped ones.
func _test_catalogue() -> Catalogue:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(_cosmetic(&"hat_pumpkin", CosmeticItem.Slot.HAT, HAT_PRICE))
	catalogue.items.append(_cosmetic(&"hat_witch", CosmeticItem.Slot.HAT, HAT2_PRICE))
	catalogue.items.append(_cosmetic(&"pet_cute_ghost", CosmeticItem.Slot.PET, PET_PRICE))
	return catalogue


func _level(id: StringName, unlocked_by: StringName) -> LevelEntry:
	var entry: LevelEntry = LevelEntry.new()
	entry.id = id
	entry.display_name = String(id)
	entry.available = true
	entry.unlocked_by = unlocked_by
	return entry


## The shipped chain's ids (zombie_run is the shipped tier config's placement level), built in code.
func _test_registry() -> LevelRegistry:
	var registry: LevelRegistry = LevelRegistry.new()
	registry.entries = [
		_level(&"zombie_run", &""), _level(&"horde_rush", &"zombie_run"), _level(&"pitchfork_panic", &"horde_rush"),
	]
	return registry


## A fresh temp SaveService and a PlayerData on the test catalogue and registry (and the shipped TierConfig).
func _make() -> PlayerDataScript:
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	var sut: PlayerDataScript = PlayerDataScript.new()
	sut.save_service = _save
	sut.catalogue = _test_catalogue()
	sut.level_registry = _test_registry()
	add_child_autofree(sut)
	return sut


## A zombie_run timer finish of `keys` correct keys in 60 s (WPM = keys / 5) earning `brains`.
func _run(level: StringName, keys: int, brains: int) -> RunResult:
	return RunResult.create(level, 1790000000, 60.0, keys, 2, {}, brains, 0, "all", GameConstants.END_REASON_TIMER)


## p2 "Bo": a non-default value in every field, so "unchanged" means something.
func _bo() -> Dictionary:
	var bo: Dictionary = SaveSchema.profile_defaults()
	bo["name"] = "Bo"
	bo["brains"] = 250
	bo["owned_items"] = ["hat_witch", "pet_cute_ghost"]
	bo["equipped"] = {"hat": "hat_witch", "pet": "pet_cute_ghost"}
	bo["flags"] = {"welcome_bonus_claimed": true, "tutorial_seen": true, "placement_done": true}
	bo["tier"] = 2
	bo["settings"] = {"music_on": false, "sound_on": true}
	bo["best_wpm"] = {"zombie_run": 9, "horde_rush": 7}
	bo["run_history"] = [_run(&"zombie_run", 45, 3).to_record()]
	bo["level_unlocks"] = {"horde_rush": {"moment_seen": true, "chosen": true}}
	bo["used_passages"] = ["t4_03"]
	bo["last_themes"] = {"horde_rush": "castle"}
	bo["lifetime"] = {"runs": 1, "keys_typed": 45, "seconds": 60, "brains": 250}
	return bo


## p1 from the defaults (active) and p2 = _bo(); returns the PlayerData.
func _two_zombies() -> PlayerDataScript:
	var sut: PlayerDataScript = _make()
	_save.get_data()["profiles"]["p2"] = _bo()
	return sut


## Every public PlayerData mutation, in an order where each row changes a profile that starts from the defaults
## (so the field coverage test can read the end state). Each row: {"name": method name, "run": Callable}.
func _mutations(sut: PlayerDataScript) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"name": "set_zombie_name", "run": func() -> void: sut.set_zombie_name("Zed")})
	rows.append({"name": "add_brains", "run": func() -> void: sut.add_brains(100)})
	# 20 WPM, a timer finish of the placement level: history, best, brains, lifetime, opens horde_rush, places.
	rows.append({"name": "record_run", "run": func() -> void: sut.record_run(_run(&"zombie_run", 100, 5))})
	rows.append({"name": "set_flag:placement_done", "run": func() -> void: sut.set_flag(&"placement_done", false)})
	# 40 WPM: re-places, so the tier moves (3 -> 5).
	rows.append({"name": "record_run:moves_tier", "run": func() -> void: sut.record_run(_run(&"zombie_run", 200, 5))})
	rows.append({"name": "set_flag:welcome_bonus_claimed",
			"run": func() -> void: sut.set_flag(&"welcome_bonus_claimed", true)})
	rows.append({"name": "set_flag:tutorial_seen", "run": func() -> void: sut.set_flag(&"tutorial_seen", true)})
	rows.append({"name": "set_setting:music_on", "run": func() -> void: sut.set_setting(&"music_on", false)})
	rows.append({"name": "set_setting:sound_on", "run": func() -> void: sut.set_setting(&"sound_on", false)})
	rows.append({"name": "buy_item", "run": func() -> void: sut.buy_item(sut.catalogue.get_item(&"hat_pumpkin"))})
	rows.append({"name": "buy_item:pet", "run": func() -> void: sut.buy_item(sut.catalogue.get_item(&"pet_cute_ghost"))})
	rows.append({"name": "equip", "run": func() -> void: sut.equip(&"hat_pumpkin")})
	rows.append({"name": "equip:pet", "run": func() -> void: sut.equip(&"pet_cute_ghost")})
	rows.append({"name": "unequip", "run": func() -> void: sut.unequip(&"pet")})
	rows.append({"name": "debug_set_all_unlocked:false", "run": func() -> void: sut.debug_set_all_unlocked(false)})
	rows.append({"name": "debug_set_all_unlocked", "run": func() -> void: sut.debug_set_all_unlocked(true)})
	rows.append({"name": "mark_unlock_seen", "run": func() -> void: sut.mark_unlock_seen(&"horde_rush")})
	rows.append({"name": "mark_level_chosen", "run": func() -> void: sut.mark_level_chosen(&"horde_rush")})
	rows.append({"name": "set_used_passages",
			"run": func() -> void: sut.set_used_passages(["t3_01", "t3_02"] as Array[String])})
	rows.append({"name": "set_last_theme", "run": func() -> void: sut.set_last_theme(&"zombie_run", &"snowy_town")})
	return rows


## The method a row exercises: its name up to any ":variant".
func _method_of(row: Dictionary) -> String:
	return String(row["name"]).get_slice(":", 0)


## A deep copy of profile `id` as it is in memory now.
func _snapshot(id: String) -> Dictionary:
	return (_save.get_data()["profiles"][id] as Dictionary).duplicate(true)


## `value` as it reads back after a JSON write and load (the written file's view of the same data).
func _as_written(value: Variant) -> Variant:
	return SaveSchema.normalize_numbers(JSON.parse_string(JSON.stringify(value)))


## The whole save.json, written now, numbers normalised like SaveService does on load.
func _written() -> Dictionary:
	assert_eq(_save.save_now(), OK, "save written")
	return SaveSchema.normalize_numbers(
			JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR.path_join("save.json")))) as Dictionary


## Snapshots of every profile except the active one.
func _inactive_snapshots() -> Dictionary:
	var snapshots: Dictionary = {}
	var active: String = str(_save.get_data()["active_profile"])
	for id: Variant in (_save.get_data()["profiles"] as Dictionary).keys():
		if str(id) != active:
			snapshots[str(id)] = _snapshot(str(id))
	return snapshots


## Runs every row; after each, every inactive profile equals its snapshot in memory and in save.json. With
## `expect_change`, the active profile must also change on every row (a no-op row would prove nothing).
func _run_table(sut: PlayerDataScript, expect_change: bool) -> void:
	for row: Dictionary in _mutations(sut):
		var before: Dictionary = _inactive_snapshots()
		var active: String = str(_save.get_data()["active_profile"])
		var active_before: Dictionary = _snapshot(active)
		(row["run"] as Callable).call()
		var written: Dictionary = _written()
		for id: String in before.keys():
			assert_eq(_snapshot(id), before[id], "%s: %s unchanged in memory" % [row["name"], id])
			assert_eq(written["profiles"][id], _as_written(before[id]), "%s: %s unchanged in save.json" % [row["name"], id])
		if expect_change:
			assert_ne(_snapshot(active), active_before, "%s changed the active profile %s" % [row["name"], active])
		assert_eq(str(_save.get_data()["active_profile"]), active, "%s keeps %s active" % [row["name"], active])


# --- AC 1, 2: every mutation changes only the active profile ------------------------------------------------

func test_every_mutation_changes_only_the_active_profile() -> void:
	var sut: PlayerDataScript = _two_zombies()
	_run_table(sut, true)


func test_every_mutation_on_the_other_zombie_leaves_the_first_alone() -> void:
	var sut: PlayerDataScript = _two_zombies()
	sut.set_zombie_name("Sam")
	sut.add_brains(40)
	assert_true(sut.switch_profile(&"p2"))
	# Bo already has some of these values, so not every row changes p2: only isolation is checked.
	_run_table(sut, false)
	assert_eq(int(_snapshot("p1")["brains"]), 40)


func test_every_mutation_leaves_a_third_zombie_alone() -> void:
	var sut: PlayerDataScript = _two_zombies()
	assert_eq(sut.create_profile("Al"), &"p3")
	assert_true(sut.switch_profile(&"p1"))
	_run_table(sut, true)


func test_every_public_player_data_method_is_in_the_isolation_table() -> void:
	var sut: PlayerDataScript = _make()
	var covered: Array[String] = []
	for row: Dictionary in _mutations(sut):
		covered.append(_method_of(row))
	var seen: Array[String] = []
	var script: GDScript = PlayerDataScript
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = String(method["name"])
		if method_name.begins_with("_") or method_name.begins_with("@") or seen.has(method_name):
			continue
		seen.append(method_name)
		if method_name.begins_with("get_") or READ_ONLY_OR_PROFILE_LEVEL.has(method_name):
			continue
		assert_true(covered.has(method_name),
				"PlayerData.%s is not in the profile isolation table (Story 11.3)" % method_name)
	assert_true(seen.has("add_brains") and seen.has("set_zombie_name"), "the method list was read")
	for name_in_table: String in covered:
		assert_true(seen.has(name_in_table), "table row %s names a real PlayerData method" % name_in_table)


# --- AC 3: every field is exercised ---------------------------------------------------------------------------

func test_the_table_changes_every_profile_field_and_the_other_zombie_keeps_its_own() -> void:
	var sut: PlayerDataScript = _two_zombies()
	var bo: Dictionary = _snapshot("p2")
	for row: Dictionary in _mutations(sut):
		(row["run"] as Callable).call()
	var defaults: Dictionary = SaveSchema.profile_defaults()
	var p1: Dictionary = _snapshot("p1")
	for key: String in defaults.keys():
		assert_true(p1.has(key), "p1 has %s" % key)
		assert_ne(p1.get(key), defaults[key], "no mutation in the isolation table changes profile field %s" % key)
	for group: String in ["flags", "settings", "lifetime"]:
		for key: String in (defaults[group] as Dictionary).keys():
			assert_ne((p1[group] as Dictionary).get(key), defaults[group][key],
					"no mutation in the isolation table changes profile field %s.%s" % [group, key])
	assert_eq(_snapshot("p2"), bo, "Bo is exactly as before")
	# Spot checks of the numbers the table should give.
	assert_eq(sut.get_brains(), 100 + 5 + 5 - HAT_PRICE - PET_PRICE)
	assert_eq(sut.get_tier(), 5)
	assert_eq(sut.get_lifetime(), {"runs": 2, "keys_typed": 300, "seconds": 120, "brains": 110})


# --- AC 6: back and forth ---------------------------------------------------------------------------------------

func test_switching_back_and_forth_keeps_each_zombie_and_survives_a_reload() -> void:
	var sut: PlayerDataScript = _two_zombies()
	# A mutates.
	sut.set_zombie_name("Sam")
	sut.add_brains(100)
	sut.record_run(_run(&"zombie_run", 100, 5))
	sut.buy_item(sut.catalogue.get_item(&"hat_pumpkin"))
	var left: Dictionary = {}
	left["p1"] = _snapshot("p1")
	left["p2"] = _snapshot("p2")
	var requests: int = _save.requests
	assert_true(sut.switch_profile(&"p2"))
	assert_eq(_save.requests - requests, 1, "one save request per switch")
	assert_eq(_snapshot("p2"), left["p2"], "B reads exactly its last state")
	assert_eq(sut.get_brains(), 250)
	assert_eq(sut.get_zombie_name(), "Bo")
	assert_eq(sut.get_equipped(&"hat"), &"hat_witch")
	assert_false(sut.get_setting(&"music_on"))
	# B mutates.
	sut.add_brains(10)
	sut.set_setting(&"sound_on", false)
	sut.set_used_passages(["t4_03", "t4_04"] as Array[String])
	left["p2"] = _snapshot("p2")
	requests = _save.requests
	assert_true(sut.switch_profile(&"p1"))
	assert_eq(_save.requests - requests, 1, "one save request per switch")
	assert_eq(_snapshot("p1"), left["p1"], "A reads exactly its last state")
	assert_eq(sut.get_brains(), 100 + 5 - HAT_PRICE, "A has only its own brains")
	assert_true(sut.get_setting(&"sound_on"), "B's Sound off stays with B")
	assert_eq(sut.get_used_passages(), [] as Array[String])
	# A mutates again.
	sut.add_brains(50)
	sut.equip(&"hat_pumpkin")
	sut.set_last_theme(&"horde_rush", &"beach_hut")
	left["p1"] = _snapshot("p1")
	requests = _save.requests
	assert_true(sut.switch_profile(&"p2"))
	assert_eq(_save.requests - requests, 1, "one save request per switch")
	assert_eq(_snapshot("p2"), left["p2"], "B reads exactly its last state again")
	assert_eq(sut.get_brains(), 260)
	assert_eq(sut.get_last_theme(&"horde_rush"), &"castle")
	assert_eq(sut.get_owned_items(), [&"hat_witch", &"pet_cute_ghost"] as Array[StringName])
	await wait_process_frames(2)
	var memory: Dictionary = _save.get_data().duplicate(true)
	var reloaded: CountingSave = CountingSave.new()
	reloaded.save_dir = TEST_DIR
	add_child_autofree(reloaded)
	assert_eq(str(reloaded.get_data()["active_profile"]), "p2")
	assert_eq(reloaded.get_data()["profiles"]["p1"], _as_written(memory["profiles"]["p1"]), "A reloads as in memory")
	assert_eq(reloaded.get_data()["profiles"]["p2"], _as_written(memory["profiles"]["p2"]), "B reloads as in memory")
	assert_eq((reloaded.get_data()["profiles"] as Dictionary).size(), 2)


# --- AC 7: no shared Array or Dictionary between two profiles -----------------------------------------------

## Every Array and Dictionary in `value`'s tree, `value` itself included.
func _containers(value: Variant, out: Array) -> Array:
	if value is Dictionary:
		out.append(value)
		for child: Variant in (value as Dictionary).values():
			_containers(child, out)
	elif value is Array:
		out.append(value)
		for child: Variant in value as Array:
			_containers(child, out)
	return out


func _assert_nothing_shared(where: String) -> void:
	var profiles: Dictionary = _save.get_data()["profiles"]
	var ids: Array = profiles.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var mine: Array = _containers(profiles[ids[i]], [])
			var theirs: Array = _containers(profiles[ids[j]], [])
			for a: Variant in mine:
				for b: Variant in theirs:
					assert_false(is_same(a, b), "%s: %s and %s share a container %s" % [where, ids[i], ids[j], str(a)])


func test_no_container_is_shared_between_profiles() -> void:
	var sut: PlayerDataScript = _make()
	assert_true(sut.set_zombie_name("Sam"))
	assert_eq(sut.create_profile("Bo"), &"p2")
	assert_eq(sut.create_profile("Al"), &"p3")
	_assert_nothing_shared("after create_profile")
	await wait_process_frames(2)
	# A load through SaveService: JSON + SaveSchema.fill_defaults for every profile.
	var loaded: PlayerDataScript = _make()
	assert_eq(loaded.get_profile_ids(), [&"p1", &"p2", &"p3"] as Array[StringName])
	_assert_nothing_shared("after a load")
	assert_true(loaded.switch_profile(&"p1"))
	for row: Dictionary in _mutations(loaded):
		(row["run"] as Callable).call()
	assert_true(loaded.switch_profile(&"p2"))
	for row: Dictionary in _mutations(loaded):
		(row["run"] as Callable).call()
	_assert_nothing_shared("after the mutation table")


func test_a_save_whose_profiles_were_filled_from_defaults_shares_nothing() -> void:
	# Two profiles missing every field: fill_defaults must give each its own containers.
	var file: FileAccess = FileAccess.open(TEST_DIR.path_join("save.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": GameConstants.CURRENT_SCHEMA, "active_profile": "p1", "profiles": {"p1": {}, "p2": {}},
	}))
	file.close()
	var sut: PlayerDataScript = _make()
	_assert_nothing_shared("after filling empty profiles")
	sut.add_brains(HAT_PRICE)
	sut.buy_item(sut.catalogue.get_item(&"hat_pumpkin"))
	assert_eq(_snapshot("p2")["owned_items"], [], "p1's purchase is not in p2's list")


# --- AC 10: the F8 reset wipes every zombie (pinned) -------------------------------------------------------------

func test_f8_reset_wipes_every_zombie() -> void:
	var sut: PlayerDataScript = _two_zombies()
	assert_true(sut.set_zombie_name("Sam"))
	sut.reset_all()
	assert_eq(sut.get_profile_ids(), [&"p1"] as Array[StringName],
			"F8 wipes every zombie (dev-only, deferred 11-2); change on purpose")
	assert_eq(sut.get_zombie_name(), "", "F8 wipes every zombie (dev-only, deferred 11-2); change on purpose")
	assert_eq(sut.get_active_profile_id(), &"p1")
