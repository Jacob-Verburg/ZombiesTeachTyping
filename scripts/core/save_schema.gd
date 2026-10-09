class_name SaveSchema
## The save file's shape: current (v3) defaults, number clean-up, default filling and migrations. Pure:
## no files, no nodes, no autoloads. SaveService calls prepare() on every save it parses.
## Filling keeps every key it doesn't know (a newer build's fields survive an older build's write).
## Migrations: one static func per version step, named migrate_N_to_N1. Each takes the whole save
## Dictionary and returns it; migrate() bumps schema_version after each step. Add the step to
## migration_steps() at index N - 1 and raise GameConstants.CURRENT_SCHEMA. Migrations run before
## filling, so they must not assume any field's type.
## v2 (Story 6.8) adds profiles.<id>.level_unlocks: {level_id: {"moment_seen": bool, "chosen": bool}};
## a key present = that level is unlocked. Only PlayerData writes it.
## v3 (Story 8.2) adds profiles.<id>.used_passages: an Array of the paragraph ids (paragraphs.json) already
## shown, so no passage repeats until its tier's set is used up (FR68). Only PlayerData writes it.

const DEFAULT_PROFILE_ID: String = "p1"
## The v2 unlock chain (level -> the level whose finished run opens it), frozen at migration time:
## migrations describe the past, so a later registry change never rewrites what migrate_1_to_2 did.
## A test keeps it equal to the shipped registry's chain for as long as that chain is unchanged.
const V2_UNLOCKED_BY: Dictionary = {"horde_rush": "zombie_run", "pitchfork_panic": "horde_rush"}


## A new dictionary every call; callers mutate it.
static func profile_defaults() -> Dictionary:
	return {
		"name": "",
		"brains": 0,
		"owned_items": [],
		"equipped": {"hat": "", "pet": ""},
		"flags": {"welcome_bonus_claimed": false, "tutorial_seen": false, "placement_done": false},
		"tier": 0,
		"settings": {"music_on": true, "sound_on": true},
		"best_wpm": {"zombie_run": 0},
		"run_history": [],
		"level_unlocks": {},
		"used_passages": [],
	}


static func defaults() -> Dictionary:
	return {
		"schema_version": GameConstants.CURRENT_SCHEMA,
		"active_profile": DEFAULT_PROFILE_ID,
		"profiles": {DEFAULT_PROFILE_ID: profile_defaults()},
	}


## Godot's JSON parser returns every number as float; every number in the save is whole by design.
## Turns each integral float into an int, in place, through all dictionaries and arrays.
static func normalize_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			if is_finite(number) and number == floorf(number) and absf(number) < 9.0e15:
				return int(number)
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			for key: Variant in dict.keys():
				dict[key] = normalize_numbers(dict[key])
		TYPE_ARRAY:
			var array: Array = value
			for i: int in array.size():
				array[i] = normalize_numbers(array[i])
	return value


## Fills missing fields from the defaults, in place, for the root and every profile. Keeps unknown
## keys. A field whose type differs from its default is replaced by the default (with a warning).
static func fill_defaults(data: Dictionary) -> Dictionary:
	var root_defaults: Dictionary = defaults()
	var profiles_default: Dictionary = root_defaults["profiles"]
	root_defaults.erase("profiles")
	_merge(data, root_defaults, "")
	if typeof(data.get("profiles")) != TYPE_DICTIONARY:
		if data.has("profiles"):
			Log.warn(&"save", "bad type at profiles, using default")
		data["profiles"] = profiles_default
	var profiles: Dictionary = data["profiles"]
	if profiles.is_empty():
		profiles[DEFAULT_PROFILE_ID] = profile_defaults()
	for id: Variant in profiles.keys():
		var path: String = "profiles/%s" % id
		if typeof(profiles[id]) != TYPE_DICTIONARY:
			Log.warn(&"save", "bad type at %s, using default" % path)
			profiles[id] = profile_defaults()
		else:
			_merge(profiles[id], profile_defaults(), path)
	if not profiles.has(data["active_profile"]):
		var ids: Array = profiles.keys()
		ids.sort()
		var fallback: String = DEFAULT_PROFILE_ID if profiles.has(DEFAULT_PROFILE_ID) else str(ids[0])
		Log.warn(&"save", "active profile %s missing, using %s" % [data["active_profile"], fallback])
		data["active_profile"] = fallback
	return data


## Migration steps in order: index 0 upgrades v1 to v2, index 1 v2 to v3, and so on.
static func migration_steps() -> Array[Callable]:
	return [migrate_1_to_2, migrate_2_to_3]


## v1 -> v2 (Story 6.8): gives every profile a level_unlocks Dictionary and backfills it, so a kid who
## already finished a level finds the next one open (with its unlock moment still to see). A level is
## backfilled when its V2_UNLOCKED_BY level has a run_history record with end_reason "timer". Existing
## entries are kept. Junk (non-dict profiles, non-array history, non-dict records) is skipped.
static func migrate_1_to_2(data: Dictionary) -> Dictionary:
	var profiles: Variant = data.get("profiles")
	if typeof(profiles) != TYPE_DICTIONARY:
		Log.warn(&"save", "migrate_1_to_2: profiles is not a dictionary, skipping")
		return data
	for id: Variant in (profiles as Dictionary).keys():
		var profile: Variant = profiles[id]
		if typeof(profile) != TYPE_DICTIONARY:
			Log.warn(&"save", "migrate_1_to_2: profiles/%s is not a dictionary, skipping" % id)
			continue
		if typeof(profile.get("level_unlocks")) != TYPE_DICTIONARY:
			profile["level_unlocks"] = {}
		var unlocks: Dictionary = profile["level_unlocks"]
		var finished: Array[String] = _finished_levels(profile.get("run_history"))
		for level: String in V2_UNLOCKED_BY:
			if finished.has(str(V2_UNLOCKED_BY[level])) and not unlocks.has(level):
				unlocks[level] = {"moment_seen": false, "chosen": false}
	return data


## v2 -> v3 (Story 8.2): gives every profile an empty used_passages Array; a profile that already has an
## Array there keeps it. Junk (non-dict profiles, profiles not a dict) is skipped with a warning, and a
## non-Array used_passages is replaced by [].
static func migrate_2_to_3(data: Dictionary) -> Dictionary:
	var profiles: Variant = data.get("profiles")
	if typeof(profiles) != TYPE_DICTIONARY:
		Log.warn(&"save", "migrate_2_to_3: profiles is not a dictionary, skipping")
		return data
	for id: Variant in (profiles as Dictionary).keys():
		var profile: Variant = profiles[id]
		if typeof(profile) != TYPE_DICTIONARY:
			Log.warn(&"save", "migrate_2_to_3: profiles/%s is not a dictionary, skipping" % id)
			continue
		if typeof(profile.get("used_passages")) != TYPE_ARRAY:
			profile["used_passages"] = []
	return data


## The level ids with at least one "timer" record in `history`; empty when history isn't an Array.
static func _finished_levels(history: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(history) != TYPE_ARRAY:
		return result
	for record: Variant in history:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		if str(record.get("end_reason", "")) != "timer":
			continue
		var level: String = str(record.get("level_id", ""))
		if not result.has(level):
			result.append(level)
	return result


## Runs the steps from the save's schema_version up to target. steps/target are a test seam.
## Never crashes: a missing or broken step logs an error and stops; a save newer than target is left alone.
static func migrate(
	data: Dictionary, steps: Array[Callable] = migration_steps(), target: int = GameConstants.CURRENT_SCHEMA
) -> Dictionary:
	var raw: Variant = data.get("schema_version")
	var version: int = 1
	if (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT) and int(raw) >= 1:
		version = int(raw)
	else:
		Log.warn(&"save", "bad schema_version %s, treating as 1" % str(raw))
	data["schema_version"] = version
	if version > target:
		Log.warn(&"save", "save schema %d is newer than this build (%d), leaving it alone" % [version, target])
		return data
	while version < target:
		if version - 1 >= steps.size():
			Log.error(&"save", "no migration step %d -> %d" % [version, version + 1])
			return data
		var migrated: Variant = steps[version - 1].call(data)
		if typeof(migrated) != TYPE_DICTIONARY:
			Log.error(&"save", "migration step %d -> %d returned no save, stopping" % [version, version + 1])
			return data
		data = migrated
		version += 1
		data["schema_version"] = version
		Log.info(&"save", "migrated to schema %d" % version)
	return data


## The pipeline for a freshly parsed save. Filling runs after migrating, so it fills the current shape.
static func prepare(data: Dictionary) -> Dictionary:
	normalize_numbers(data)
	data = migrate(data)
	return fill_defaults(data)


static func _merge(data: Dictionary, default_data: Dictionary, path: String) -> void:
	for key: String in default_data.keys():
		var key_path: String = key if path.is_empty() else "%s/%s" % [path, key]
		var default_value: Variant = default_data[key]
		if not data.has(key):
			data[key] = _copy(default_value)
		elif typeof(data[key]) != typeof(default_value):
			Log.warn(&"save", "bad type at %s, using default" % key_path)
			data[key] = _copy(default_value)
		elif typeof(default_value) == TYPE_DICTIONARY:
			_merge(data[key], default_value, key_path)


static func _copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value
