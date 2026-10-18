extends Node
## Single in-memory source of truth for the active profile; the only code that writes save fields.
## Every mutation emits a typed signal and requests a save (SaveService.request_save(), never save_now()).
## Getters read through SaveService.get_active_profile() on every call: nothing is cached, so a
## reset (Story 1.8) or a profile switch (switch_profile / create_profile, Story 11.2) is picked up.
## reset_all() is the one mutation that replaces the whole profile: it emits profile_replaced (no
## brains_changed/settings_changed deltas), and anything showing a profile value re-reads on it.
## switch_profile and create_profile (Story 11.2) emit the same signal.
## Contract violations (negative amount, unknown setting, null run result) log an error and change
## nothing; no assert(), which would fire in GUT's debug run and in release would vanish.
## save_service and catalogue are test seams: tests assign a fresh SaveService (save_dir in a temp folder)
## and a code-built Catalogue before add_child.
## Shop (Story 4.1): buy_item checks against the catalogue's own record and returns a PurchaseResult;
## owns/get_owned_items, equip/unequip/get_equipped (one hat, one pet, either may be empty) and
## set_flag/get_flag. Ids and keys are stored as Strings (the save is JSON); the API uses StringNames.
## Listeners also re-read on profile_replaced (a reset changes owned/equipped/flags with no delta signals).
## Level unlocks (Story 6.8, FR79): a level whose registry unlocked_by is empty is always open. Any other
## level opens when a run of its unlocked_by level is recorded with end_reason timer (quits are never
## recorded, so they never unlock). The profile's level_unlocks holds {level_id: {"moment_seen", "chosen"}};
## a key present = unlocked, never removed by gameplay (only reset_all and the debug relock clear it).
## get_unlock_state reads it, mark_unlock_seen (the menu's one-time unlock moment) and mark_level_chosen
## (the "New!" badge) write it. level_registry is a test seam, loaded lazily (never preloaded: the
## registry references every level scene, which must not load at boot).
## Tier (Story 7.2, FR60-FR63): the hidden adaptive-difficulty tier. The first completed run of
## tier_config.placement_level places a new save: that run's WPM alone (times its level scale) sets the tier
## and flags.placement_done turns true. Every later recorded run moves it with TierCalculator.compute_tier
## (rolling average, hysteresis). Both are written inline in record_run, so it still makes one save request.
## _reconcile_tier() keeps placement_done true <=> tier in 1..tier count: it runs at load and in reset_all
## (and in switch_profile / create_profile), and places an MVP save that has runs but no tier from its
## rolling average. The tier is never shown (FR60): no copy, no label, no log line carries it or the average.
## get_tier() is the one read (Story 7.5). An invalid tier config changes nothing and logs an error.
## tier_config is a test seam (null = the shipped data/tier_config.tres); only the shipped one is validated
## at _ready.
## Used passages (Story 8.2, FR68): get_used_passages / set_used_passages read and write the profile's
## used_passages, the paragraph ids already shown; RunFrame forwards the level's list, so this is its only
## writer. Generated tier 1-2 text is never tracked.
## Last themes (Story 10.1, FR76): get_last_theme / set_last_theme read and write the profile's
## last_themes, {level_id: theme_id}, the look each level last started in. RunFrame reads it to pick a
## different theme and writes the pick at run start, so this is its only writer. No signal: nothing listens.
## Lifetime (Story 10.5, FR77): the profile's lifetime {"runs", "keys_typed", "seconds", "brains"} are running
## totals that outlive the RUN_HISTORY_CAP. record_run adds the run (inline, same single save request);
## add_brains adds to lifetime brains too (quit runs, the welcome gift); spending never lowers it. Reads for
## the Progress screen: get_lifetime, get_best_wpm_overall, get_run_history (copies; junk reads as 0 / skipped).
## Zombie name (Story 11.1, FR78): the active profile's "name". set_zombie_name stores ZombieName.clean(raw) and
## refuses an invalid name; get_zombie_name reads it back through ZombieName.is_valid, so a junk or hand-edited
## value reads as "" (not named yet, NFR16). The name is personal data: it is never logged (NFR12), only fixed
## text. switch_profile / create_profile emit profile_replaced, and anything showing the name re-reads it then.
## Profiles (Story 11.2, FR78): the save holds up to GameConstants.MAX_ZOMBIES profiles, keyed "p<N>"; every getter
## and setter above works on the active one only. get_profile_ids (natural order), get_active_profile_id,
## get_profile_summary (name, hat, pet of any profile, read with the active getters' rules), has_named_zombie and
## can_add_zombie feed the "Who's playing?" picker. switch_profile makes another profile active; create_profile
## adds a fresh named one (refusing an invalid or already-used name, ignoring case, and a full save) and makes it
## active. Both write active_profile through save_service.get_data(), reconcile the tier, emit profile_replaced
## and request one save. Logs carry profile ids, never names.
## Story 11.3: every field in a profile is per-zombie; tests/unit/test_profile_isolation.gd checks each mutation leaves
## the other profiles untouched (in memory and in save.json) and fails on a new public setter not in its table. Global
## by design, never per-zombie: schema_version, active_profile, SaveService's read-only flag and save.bak, AudioManager's
## voice-spacing timers, RunFrame's static debug seeds, Log statics and the window / fullscreen state. The F8 reset
## (reset_all) wipes every zombie.

enum PurchaseResult { OK, NOT_ENOUGH_BRAINS, ALREADY_OWNED, UNAVAILABLE }

## delta < 0 only for a purchase.
signal brains_changed(total: int, delta: int)
signal settings_changed(key: StringName, value: bool)
signal profile_replaced
## A finished run was saved; new_best is true when it beat a saved best WPM for its level.
signal run_recorded(level_id: StringName, new_best: bool)
## A bought item's id was added to the owned items.
signal inventory_changed(item_id: StringName)
## A slot's item changed; item_id is &"" when the slot was emptied.
signal equipment_changed(slot: StringName, item_id: StringName)
signal flags_changed(flag: StringName, value: bool)
## record_run opened this level (emitted after run_recorded, once per newly unlocked level).
signal level_unlocked(level_id: StringName)
## A level's moment_seen or chosen changed; &"" = many levels changed at once (the debug tools).
signal unlocks_changed(level_id: StringName)
## The used passage ids changed (set_used_passages, Story 8.2).
signal used_passages_changed
## The active profile's zombie name was set (Story 11.1). The name is never logged.
signal zombie_name_changed(name: String)

const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")
const CATALOGUE: Catalogue = preload("res://data/cosmetics/catalogue.tres")
const TIER_CONFIG: TierConfig = preload("res://data/tier_config.tres")
const LEVEL_REGISTRY_PATH: String = "res://data/levels/level_registry.tres"
## What get_unlock_state returns for an open level (no lock, nothing new to show).
const OPEN_STATE: Dictionary = {"unlocked": true, "moment_seen": true, "chosen": true}
## The lifetime totals' keys (SaveSchema v5).
const LIFETIME_FIELDS: Array[String] = ["runs", "keys_typed", "seconds", "brains"]

## Test seam: tests assign a fresh SaveService before add_child.
var save_service: SaveServiceScript = null
## Test seam: tests assign a code-built Catalogue before add_child.
var catalogue: Catalogue = null
## Test seam: tests assign a code-built LevelRegistry; null = the shipped one, loaded on first use.
var level_registry: LevelRegistry = null
## Test seam: tests assign a code-built TierConfig before add_child; null = the shipped tier_config.tres.
var tier_config: TierConfig = null


func _ready() -> void:
	if save_service == null:
		save_service = SaveService
	if catalogue == null:
		catalogue = CATALOGUE
		# Only the shipped file is checked: tests inject small catalogues on purpose.
		var problem: String = catalogue.validate()
		if not problem.is_empty():
			Log.error(&"economy", "shipped catalogue invalid: %s" % problem)
	if tier_config == null:
		tier_config = TIER_CONFIG
		var tier_problem: String = tier_config.validate()
		if not tier_problem.is_empty():
			Log.error(&"tier", "shipped tier config invalid: %s" % tier_problem)
	_reconcile_tier()


func get_brains() -> int:
	return int(_profile()["brains"])


func add_brains(amount: int) -> void:
	if amount < 0:
		Log.error(&"economy", "add_brains: negative amount %d" % amount)
		return
	if amount == 0:
		return
	var total: int = get_brains() + amount
	_profile()["brains"] = total
	_add_lifetime("brains", amount)
	brains_changed.emit(total, amount)
	save_service.request_save()


## Saves a finished run (never a quit): appends its record (newest RUN_HISTORY_CAP kept), updates the
## level's best WPM, adds the run's brains, adds the run to the lifetime totals, for a timer finish unlocks the levels it opens, and places or
## moves the hidden tier, with one save request. Returns true for a new personal best; a level's first run sets the best but returns false.
func record_run(result: RunResult) -> bool:
	if result == null:
		Log.error(&"run", "record_run: null result")
		return false
	var profile: Dictionary = _profile()
	var history: Array = profile["run_history"]
	var record: Dictionary = result.to_record()
	history.append(record)
	if history.size() > GameConstants.RUN_HISTORY_CAP:
		# One slice, not remove_at(0) per run: a loaded history may be far over the cap.
		profile["run_history"] = history.slice(history.size() - GameConstants.RUN_HISTORY_CAP)
		history = profile["run_history"]
	var best: Dictionary = profile["best_wpm"]
	var key: String = String(result.level_id)
	# A hand-edited save may hold any type here; anything but a positive number counts as no best.
	var stored: Variant = best.get(key, 0)
	var previous: int = maxi(0, int(stored)) if stored is int or stored is float else 0
	var new_best: bool = previous > 0 and result.wpm > previous
	if result.wpm > previous:
		best[key] = result.wpm
	var earned: int = result.total_brains()
	# Before brains_changed, so a listener reading get_lifetime() sees this run.
	_add_lifetime("runs", 1)
	_add_lifetime("keys_typed", maxi(0, result.keys_typed))
	_add_lifetime("seconds", int(record["duration_s"]))
	_add_lifetime("brains", maxi(0, earned))
	if earned > 0:
		# Inline, not add_brains(): that would request a second save.
		var total: int = get_brains() + earned
		profile["brains"] = total
		brains_changed.emit(total, earned)
	var opened: Array[StringName] = []
	if result.end_reason == GameConstants.END_REASON_TIMER:
		var unlocks: Dictionary = _level_unlocks()
		for entry: LevelEntry in _registry().unlocks_of(result.level_id):
			if not unlocks.has(String(entry.id)):
				unlocks[String(entry.id)] = {"moment_seen": false, "chosen": false}
				opened.append(entry.id)
	_update_tier(result, profile)
	run_recorded.emit(result.level_id, new_best)
	for id: StringName in opened:
		level_unlocked.emit(id)
	save_service.request_save()
	Log.info(&"run", "recorded level=%s wpm=%d new_best=%s history=%d" % [
			result.level_id, result.wpm, new_best, history.size()])
	for id: StringName in opened:
		Log.info(&"run", "unlocked %s" % id)
	return new_best


## {"unlocked", "moment_seen", "chosen"} for `level_id`. A level with an empty unlocked_by, or one the
## registry doesn't know, is always open (all true). A hand-edited entry reads leniently: a key present
## is unlocked, and a non-Dictionary entry or a missing / non-bool field reads as true (no surprise replays).
func get_unlock_state(level_id: StringName) -> Dictionary:
	var entry: LevelEntry = _registry().get_entry(level_id)
	if entry == null or entry.unlocked_by == &"":
		return OPEN_STATE.duplicate()
	var unlocks: Dictionary = _level_unlocks()
	if not unlocks.has(String(level_id)):
		return {"unlocked": false, "moment_seen": false, "chosen": false}
	var stored: Variant = unlocks[String(level_id)]
	return {
		"unlocked": true,
		"moment_seen": _stored_flag(stored, "moment_seen"),
		"chosen": _stored_flag(stored, "chosen"),
	}


## The unlock moment for `level_id` has played (the menu calls it as the moment starts). Changes nothing
## for a locked or always-open level, or when already seen.
func mark_unlock_seen(level_id: StringName) -> void:
	_mark_unlock(level_id, "moment_seen")


## The kid picked `level_id` on the menu, so its "New!" badge is gone for good. Changes nothing for a
## locked or always-open level, or when already chosen.
func mark_level_chosen(level_id: StringName) -> void:
	_mark_unlock(level_id, "chosen")


## Debug overlay only. on: every level with an unlocked_by is unlocked with its moment not seen and not
## chosen (overwriting, so the moment replays); off: level_unlocks is emptied. One save request.
func debug_set_all_unlocked(on: bool) -> void:
	var unlocks: Dictionary = _level_unlocks()
	unlocks.clear()
	if on:
		for entry: LevelEntry in _registry().entries:
			if entry != null and entry.unlocked_by != &"":
				unlocks[String(entry.id)] = {"moment_seen": false, "chosen": false}
	unlocks_changed.emit(&"")
	save_service.request_save()
	Log.info(&"run", "debug: all levels %s" % ("unlocked" if on else "relocked"))


func get_setting(key: StringName) -> bool:
	if not _is_setting(key):
		Log.error(&"save", "unknown setting %s" % key)
		return false
	return bool(_settings()[String(key)])


func set_setting(key: StringName, value: bool) -> void:
	if not _is_setting(key):
		Log.error(&"save", "unknown setting %s" % key)
		return
	var settings: Dictionary = _settings()
	if bool(settings[String(key)]) == value:
		return
	settings[String(key)] = value
	settings_changed.emit(key, value)
	save_service.request_save()


## Spends brains on `item` (one save request). The catalogue's own record decides price and
## availability, so a stray copy of an item can't buy cheaper or skip "Coming soon". Anything but OK
## changes nothing.
func buy_item(item: CosmeticItem) -> PurchaseResult:
	var record: CosmeticItem = null if item == null else catalogue.get_item(item.id)
	if record == null:
		Log.error(&"economy", "buy_item: item %s not in catalogue" % ("null" if item == null else String(item.id)))
		return PurchaseResult.UNAVAILABLE
	if record.price <= 0:
		Log.error(&"economy", "buy_item: %s has price %d" % [record.id, record.price])
		return PurchaseResult.UNAVAILABLE
	if not record.is_available:
		Log.debug(&"economy", "buy_item: %s not available" % record.id)
		return PurchaseResult.UNAVAILABLE
	if owns(record.id):
		return PurchaseResult.ALREADY_OWNED
	if get_brains() < record.price:
		return PurchaseResult.NOT_ENOUGH_BRAINS
	var profile: Dictionary = _profile()
	# Inline, not add_brains(): that rejects negatives and would request a second save.
	var total: int = get_brains() - record.price
	profile["brains"] = total
	(profile["owned_items"] as Array).append(String(record.id))
	brains_changed.emit(total, -record.price)
	inventory_changed.emit(record.id)
	save_service.request_save()
	Log.info(&"economy", "bought %s for %d, brains=%d" % [record.id, record.price, total])
	return PurchaseResult.OK


func owns(item_id: StringName) -> bool:
	return _owns_in(_profile(), item_id)


## The owned ids in purchase order, skipping junk a hand-edited save may hold.
func get_owned_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: String in _owned_in(_profile()):
		result.append(StringName(id))
	return result


## Wears an owned catalogue item in its slot, replacing what was there. False for an unknown or
## not-owned id (a caller bug: the Closet only offers Wear on owned items).
func equip(item_id: StringName) -> bool:
	var item: CosmeticItem = catalogue.get_item(item_id)
	if item == null:
		Log.error(&"economy", "equip: %s not in catalogue" % item_id)
		return false
	if not owns(item_id):
		Log.error(&"economy", "equip: %s not owned" % item_id)
		return false
	if not item.is_available:
		Log.error(&"economy", "equip: %s not available" % item_id)
		return false
	var slot: StringName = item.slot_key()
	var equipped: Dictionary = _equipped()
	if _stored_id(equipped, slot) == String(item_id):
		return true
	equipped[String(slot)] = String(item_id)
	equipment_changed.emit(slot, item_id)
	save_service.request_save()
	return true


func unequip(slot: StringName) -> void:
	if not CosmeticItem.is_slot_key(slot):
		Log.error(&"economy", "unequip: unknown slot %s" % slot)
		return
	var equipped: Dictionary = _equipped()
	var was_visible: bool = get_equipped(slot) != &""
	if _stored_id(equipped, slot).is_empty() and equipped.get(String(slot), "") is String:
		return
	equipped[String(slot)] = ""
	if was_visible:
		equipment_changed.emit(slot, &"")
	save_service.request_save()


## The id worn in `slot`, or &"" when empty. A stored id the kid doesn't own reads as empty.
func get_equipped(slot: StringName) -> StringName:
	if not CosmeticItem.is_slot_key(slot):
		Log.error(&"economy", "get_equipped: unknown slot %s" % slot)
		return &""
	return _equipped_id_in(_profile(), slot)


func get_flag(flag: StringName) -> bool:
	if not _is_flag(flag):
		Log.error(&"save", "unknown flag %s" % flag)
		return false
	return bool(_flags()[String(flag)])


func set_flag(flag: StringName, value: bool) -> void:
	if not _is_flag(flag):
		Log.error(&"save", "unknown flag %s" % flag)
		return
	var flags: Dictionary = _flags()
	if bool(flags[String(flag)]) == value:
		return
	flags[String(flag)] = value
	flags_changed.emit(flag, value)
	save_service.request_save()


## The active profile's zombie name; "" when it has none yet (a missing, non-String or invalid stored value).
func get_zombie_name() -> String:
	return _stored_name(_profile())


## Stores ZombieName.clean(raw) as the zombie name. An invalid name logs a fixed warning, changes nothing and
## returns false; the stored name again returns true with no signal and no save; otherwise it writes the name,
## emits zombie_name_changed and requests a save. Never logs the name (NFR12).
func set_zombie_name(raw: String) -> bool:
	var cleaned: String = ZombieName.clean(raw)
	if not ZombieName.is_valid(cleaned):
		Log.warn(&"save", "set_zombie_name: invalid name")
		return false
	if cleaned == get_zombie_name():
		return true
	_profile()["name"] = cleaned
	zombie_name_changed.emit(cleaned)
	save_service.request_save()
	Log.info(&"save", "zombie named")
	return true


## The hidden tier for Story 7.5: 1..tier count once placed; 0 when not placed yet (or a junk stored value).
## Never shown to the player (FR60).
func get_tier() -> int:
	var value: Variant = _profile().get("tier", 0)
	if not value is int or tier_config == null:
		return 0
	var tier: int = value
	return tier if tier >= 1 and tier <= tier_config.tier_count() else 0


## The paragraph ids already shown (Story 8.2), in the order used: a copy of the String entries. A
## non-Array in the save reads as [].
func get_used_passages() -> Array[String]:
	var ids: Array[String] = []
	var stored: Variant = _profile().get("used_passages", [])
	if not stored is Array:
		return ids
	for id: Variant in stored as Array:
		if id is String:
			ids.append(id as String)
	return ids


## Stores `ids` as the used passages: the unique non-empty Strings, in order. An unchanged list does
## nothing; otherwise it writes, emits used_passages_changed and requests a save.
func set_used_passages(ids: Array[String]) -> void:
	var clean: Array[String] = []
	for id: String in ids:
		if id != "" and not clean.has(id):
			clean.append(id)
	var stored: Variant = _profile().get("used_passages")
	if stored is Array and Array(clean) == Array((stored as Array).duplicate()):
		return
	_profile()["used_passages"] = clean.duplicate()
	used_passages_changed.emit()
	save_service.request_save()


## The theme `level_id` last started in; &"" when none is saved (a missing key, a non-Dictionary
## last_themes or a non-String value all read as none).
func get_last_theme(level_id: StringName) -> StringName:
	var stored: Variant = _profile().get("last_themes")
	if not stored is Dictionary:
		return &""
	var value: Variant = (stored as Dictionary).get(String(level_id))
	if not value is String:
		return &""
	return StringName(value as String)


## Stores `theme_id` as the theme `level_id` last started in (as Strings). An empty level id or an unchanged
## value does nothing; otherwise it writes and requests a save.
func set_last_theme(level_id: StringName, theme_id: StringName) -> void:
	if level_id == &"" or get_last_theme(level_id) == theme_id:
		return
	var profile: Dictionary = _profile()
	if not profile.get("last_themes") is Dictionary:
		profile["last_themes"] = {}
	(profile["last_themes"] as Dictionary)[String(level_id)] = String(theme_id)
	save_service.request_save()


## The lifetime totals, a fresh {"runs", "keys_typed", "seconds", "brains"} Dictionary of non-negative ints. A
## missing, negative or non-int stored value (or a non-Dictionary lifetime) reads as 0.
func get_lifetime() -> Dictionary:
	var stored: Variant = _profile().get("lifetime")
	var source: Dictionary = stored if stored is Dictionary else {}
	var totals: Dictionary = {}
	for field: String in LIFETIME_FIELDS:
		totals[field] = _whole(source.get(field))
	return totals


## The highest saved per-level best WPM (best_wpm outlives the history cap); 0 when there is none. Only
## non-negative ints and whole floats count.
func get_best_wpm_overall() -> int:
	var stored: Variant = _profile().get("best_wpm")
	if not stored is Dictionary:
		return 0
	var best: int = 0
	for value: Variant in (stored as Dictionary).values():
		if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9.0e15:
			value = int(value)
		best = maxi(best, _whole(value))
	return best


## Deep copies of the run_history Dictionary records, oldest first; junk entries are skipped. Mutating the
## result never changes the save.
func get_run_history() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var stored: Variant = _profile().get("run_history")
	if not stored is Array:
		return records
	for record: Variant in stored as Array:
		if record is Dictionary:
			records.append((record as Dictionary).duplicate(true))
	return records


## Replaces the save with defaults (debug overlay F8). The old save.json becomes save.bak on the write.
func reset_all() -> void:
	save_service.reset_to_defaults()
	_reconcile_tier()
	profile_replaced.emit()


## Every profile id in the save, natural order on the String (p2 before p10): stable whatever the JSON key order.
func get_profile_ids() -> Array[StringName]:
	var keys: Array[String] = []
	for key: Variant in _profiles().keys():
		keys.append(str(key))
	keys.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var ids: Array[StringName] = []
	for key: String in keys:
		ids.append(StringName(key))
	return ids


func get_active_profile_id() -> StringName:
	return StringName(str(save_service.get_data()["active_profile"]))


## {"id", "name", "hat", "pet"} for any profile, read with the active-profile getters' rules: a junk name reads
## "", a hat or pet that profile doesn't own (or that isn't an available catalogue item) reads &"". An unknown id
## logs an error and returns {}.
func get_profile_summary(id: StringName) -> Dictionary:
	var profiles: Dictionary = _profiles()
	if not profiles.has(String(id)) or not profiles[String(id)] is Dictionary:
		Log.error(&"save", "get_profile_summary: unknown profile %s" % id)
		return {}
	var profile: Dictionary = profiles[String(id)]
	return {
		"id": id,
		"name": _stored_name(profile),
		"hat": _equipped_id_in(profile, CosmeticItem.SLOT_HAT),
		"pet": _equipped_id_in(profile, CosmeticItem.SLOT_PET),
	}


## True when any profile has a valid name (the title then opens the "Who's playing?" picker).
func has_named_zombie() -> bool:
	for profile: Variant in _profiles().values():
		if profile is Dictionary and not _stored_name(profile as Dictionary).is_empty():
			return true
	return false


## True while the save holds fewer than GameConstants.MAX_ZOMBIES profiles.
func can_add_zombie() -> bool:
	return _profiles().size() < GameConstants.MAX_ZOMBIES


## Makes `id` the active profile: reconciles its tier, emits profile_replaced (every listener re-reads) and requests
## one save. Already active: true, nothing else. Unknown id: an error, nothing changes, false. Logs the id only.
func switch_profile(id: StringName) -> bool:
	if not _profiles().has(String(id)):
		Log.error(&"save", "switch_profile: unknown profile %s" % id)
		return false
	if id == get_active_profile_id():
		return true
	save_service.get_data()["active_profile"] = String(id)
	_reconcile_tier()
	profile_replaced.emit()
	save_service.request_save()
	Log.info(&"save", "switched zombie %s" % id)
	return true


## Adds a new zombie named ZombieName.clean(raw_name) with a fresh profile (SaveSchema.profile_defaults()) under the
## lowest unused id, makes it active, emits profile_replaced and zombie_name_changed and requests one save; returns
## the id. Refused with a fixed warning and &"" (nothing changes) for an invalid name, a name another zombie has
## (ignoring case) or a full save (MAX_ZOMBIES). Never logs the name (NFR12).
func create_profile(raw_name: String) -> StringName:
	var cleaned: String = ZombieName.clean(raw_name)
	if not ZombieName.is_valid(cleaned):
		Log.warn(&"save", "create_profile: invalid name")
		return &""
	if not can_add_zombie():
		Log.warn(&"save", "create_profile: no room for another zombie")
		return &""
	var profiles: Dictionary = _profiles()
	for profile: Variant in profiles.values():
		if profile is Dictionary and _stored_name(profile as Dictionary).nocasecmp_to(cleaned) == 0:
			Log.warn(&"save", "create_profile: name already used")
			return &""
	var n: int = 1
	while profiles.has(GameConstants.NEW_ZOMBIE_ID_FORMAT % n):
		n += 1
	var key: String = GameConstants.NEW_ZOMBIE_ID_FORMAT % n
	var fresh: Dictionary = SaveSchema.profile_defaults()
	fresh["name"] = cleaned
	profiles[key] = fresh
	save_service.get_data()["active_profile"] = key
	_reconcile_tier()
	profile_replaced.emit()
	zombie_name_changed.emit(cleaned)
	save_service.request_save()
	Log.info(&"save", "new zombie %s" % key)
	return StringName(key)


func _profile() -> Dictionary:
	return save_service.get_active_profile()


## The save's live profiles Dictionary (every zombie), keyed by String id.
func _profiles() -> Dictionary:
	return save_service.get_data()["profiles"]


## False (with an error) when tier_config is missing or invalid: tier work then changes nothing.
func _tier_config_ok() -> bool:
	if tier_config == null:
		Log.error(&"tier", "no tier config")
		return false
	var problem: String = tier_config.validate()
	if not problem.is_empty():
		Log.error(&"tier", "tier config invalid: %s" % problem)
		return false
	return true


## record_run's tier step, after the record is appended. Placed: compute_tier over the history. Not placed:
## a run of placement_level places from its own WPM; any other level changes nothing. Inline writes, no save.
func _update_tier(result: RunResult, profile: Dictionary) -> void:
	if not _tier_config_ok():
		return
	var flags: Dictionary = profile["flags"]
	if bool(flags["placement_done"]):
		var next: int = TierCalculator.compute_tier(get_tier(), profile["run_history"], tier_config)
		if next >= 1:
			profile["tier"] = next
		return
	if result.level_id != tier_config.placement_level or not TierCalculator.is_completed(String(result.end_reason)):
		return
	var placement_wpm: float = result.wpm * tier_config.scale_for(result.level_id)
	profile["tier"] = TierCalculator.tier_for_wpm(placement_wpm, tier_config)
	flags["placement_done"] = true
	flags_changed.emit(&"placement_done", true)
	Log.info(&"tier", "placed")


## Enforces placement_done true <=> tier in 1..tier count on the loaded profile. Not placed but with counted
## runs (an MVP save) -> placed from the rolling average; not placed, no runs -> tier 0; placed with a junk
## tier -> recomputed from the average, or unplaced when there is none. One save request only when it changed
## something. No signal: it runs at load and before profile_replaced, which make listeners re-read.
func _reconcile_tier() -> void:
	if not _tier_config_ok():
		return
	var profile: Dictionary = _profile()
	var flags: Dictionary = profile["flags"]
	var placed: bool = bool(flags["placement_done"])
	if placed and get_tier() >= 1:
		return
	var average: float = TierCalculator.rolling_average(profile["run_history"], tier_config)
	var has_average: bool = average >= 0.0
	if not placed:
		var stored: Variant = profile.get("tier", 0)
		if has_average:
			profile["tier"] = TierCalculator.tier_for_wpm(average, tier_config)
			flags["placement_done"] = true
		elif stored is int and stored == 0:
			return
		else:
			profile["tier"] = 0
	elif has_average:
		profile["tier"] = TierCalculator.tier_for_wpm(average, tier_config)
	else:
		profile["tier"] = 0
		flags["placement_done"] = false
	save_service.request_save()
	Log.info(&"tier", "reconciled placement")


func _registry() -> LevelRegistry:
	if level_registry == null:
		level_registry = load(LEVEL_REGISTRY_PATH) as LevelRegistry
		if level_registry == null:
			# Every level then reads as open and no run unlocks anything, but runs still record and save.
			Log.error(&"run", "level registry failed to load from %s" % LEVEL_REGISTRY_PATH)
			level_registry = LevelRegistry.new()
	return level_registry


## Adds `amount` to one lifetime total, inline (no save request). A non-Dictionary lifetime is replaced by the
## defaults first, and a junk stored value counts as 0.
func _add_lifetime(field: String, amount: int) -> void:
	var profile: Dictionary = _profile()
	if not profile.get("lifetime") is Dictionary:
		profile["lifetime"] = SaveSchema.profile_defaults()["lifetime"]
	var lifetime: Dictionary = profile["lifetime"]
	lifetime[field] = _whole(lifetime.get(field)) + amount


## A non-negative int as itself; anything else reads as 0.
func _whole(value: Variant) -> int:
	if value is int and int(value) >= 0:
		return value
	return 0


## The profile's level_unlocks Dictionary; a non-Dictionary value is replaced by {} first.
func _level_unlocks() -> Dictionary:
	var profile: Dictionary = _profile()
	if typeof(profile.get("level_unlocks")) != TYPE_DICTIONARY:
		profile["level_unlocks"] = {}
	return profile["level_unlocks"]


## A stored unlock field: false only when it is a real false; junk reads as true.
func _stored_flag(stored: Variant, field: String) -> bool:
	if typeof(stored) != TYPE_DICTIONARY:
		return true
	var value: Variant = (stored as Dictionary).get(field, true)
	return value if value is bool else true


## Sets `field` on an unlocked level's entry, rewriting a junk entry as a proper Dictionary. Emits only
## when the read value changes; a repair alone just saves.
func _mark_unlock(level_id: StringName, field: String) -> void:
	var state: Dictionary = get_unlock_state(level_id)
	var entry: LevelEntry = _registry().get_entry(level_id)
	if not state["unlocked"] or entry == null or entry.unlocked_by == &"":
		return
	var updated: Dictionary = {"moment_seen": state["moment_seen"], "chosen": state["chosen"]}
	updated[field] = true
	var unlocks: Dictionary = _level_unlocks()
	var stored: Variant = unlocks[String(level_id)]
	if typeof(stored) == TYPE_DICTIONARY and stored == updated:
		return
	unlocks[String(level_id)] = updated
	if not state[field]:
		unlocks_changed.emit(level_id)
	save_service.request_save()


func _settings() -> Dictionary:
	return _profile()["settings"]


func _is_setting(key: StringName) -> bool:
	var defaults: Dictionary = SaveSchema.profile_defaults()["settings"]
	return defaults.has(String(key))


func _is_flag(flag: StringName) -> bool:
	var defaults: Dictionary = SaveSchema.profile_defaults()["flags"]
	return defaults.has(String(flag))


func _flags() -> Dictionary:
	return _profile()["flags"]


func _equipped() -> Dictionary:
	return _profile()["equipped"]


## The distinct non-empty String ids in `profile`'s owned_items; anything else a hand-edited save holds is
## skipped. A non-Array owned_items reads as none.
func _owned_in(profile: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var stored: Variant = profile.get("owned_items")
	if not stored is Array:
		return result
	for value: Variant in stored as Array:
		if value is String and not (value as String).is_empty() and not result.has(value):
			result.append(value)
	return result


func _owns_in(profile: Dictionary, item_id: StringName) -> bool:
	if item_id == &"":
		return false
	return _owned_in(profile).has(String(item_id))


## The id `profile` wears in `slot` (a valid slot key), or &"" when empty, not owned by that profile, not in the
## catalogue or not available. One rule for get_equipped and get_profile_summary.
func _equipped_id_in(profile: Dictionary, slot: StringName) -> StringName:
	var equipped: Variant = profile.get("equipped")
	if not equipped is Dictionary:
		return &""
	var id: String = _stored_id(equipped as Dictionary, slot)
	if id.is_empty() or not _owns_in(profile, StringName(id)):
		return &""
	var item: CosmeticItem = catalogue.get_item(StringName(id))
	if item == null or not item.is_available:
		return &""
	return StringName(id)


## `profile`'s name; "" when missing, not a String or invalid (ZombieName.is_valid). Never logged (NFR12).
func _stored_name(profile: Dictionary) -> String:
	var stored: Variant = profile.get("name", "")
	if not stored is String or not ZombieName.is_valid(stored as String):
		return ""
	return stored as String


## The String stored for `slot`, or "" when missing or not a String.
func _stored_id(equipped: Dictionary, slot: StringName) -> String:
	var value: Variant = equipped.get(String(slot), "")
	return value if value is String else ""
