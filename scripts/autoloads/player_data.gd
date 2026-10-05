extends Node
## Single in-memory source of truth for the active profile; the only code that writes save fields.
## Every mutation emits a typed signal and requests a save (SaveService.request_save(), never save_now()).
## Getters read through SaveService.get_active_profile() on every call: nothing is cached, so a
## reset (Story 1.8) or a profile switch (Epic 11) that replaces SaveService's data is picked up.
## reset_all() is the one mutation that replaces the whole profile: it emits profile_replaced (no
## brains_changed/settings_changed deltas), and anything showing a profile value re-reads on it.
## Epic 11's profile switch emits the same signal.
## Contract violations (negative amount, unknown setting, null run result) log an error and change
## nothing; no assert(), which would fire in GUT's debug run and in release would vanish.
## save_service and catalogue are test seams: tests assign a fresh SaveService (save_dir in a temp folder)
## and a code-built Catalogue before add_child.
## Shop (Story 4.1): buy_item checks against the catalogue's own record and returns a PurchaseResult;
## owns/get_owned_items, equip/unequip/get_equipped (one hat, one pet, either may be empty) and
## set_flag/get_flag. Ids and keys are stored as Strings (the save is JSON); the API uses StringNames.
## Listeners also re-read on profile_replaced (a reset changes owned/equipped/flags with no delta signals).
## Later methods, by story: mark_unlock_seen/mark_level_chosen/get_unlock_state (6.8).

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

const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")
const CATALOGUE: Catalogue = preload("res://data/cosmetics/catalogue.tres")

## Test seam: tests assign a fresh SaveService before add_child.
var save_service: SaveServiceScript = null
## Test seam: tests assign a code-built Catalogue before add_child.
var catalogue: Catalogue = null


func _ready() -> void:
	if save_service == null:
		save_service = SaveService
	if catalogue == null:
		catalogue = CATALOGUE
		# Only the shipped file is checked: tests inject small catalogues on purpose.
		var problem: String = catalogue.validate()
		if not problem.is_empty():
			Log.error(&"economy", "shipped catalogue invalid: %s" % problem)


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
	brains_changed.emit(total, amount)
	save_service.request_save()


## Saves a finished run (never a quit): appends its record (newest RUN_HISTORY_CAP kept), updates the
## level's best WPM and adds the run's brains, with one save request. Returns true for a new personal
## best; a level's first run sets the best but returns false.
func record_run(result: RunResult) -> bool:
	if result == null:
		Log.error(&"run", "record_run: null result")
		return false
	var profile: Dictionary = _profile()
	var history: Array = profile["run_history"]
	history.append(result.to_record())
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
	if earned > 0:
		# Inline, not add_brains(): that would request a second save.
		var total: int = get_brains() + earned
		profile["brains"] = total
		brains_changed.emit(total, earned)
	run_recorded.emit(result.level_id, new_best)
	save_service.request_save()
	Log.info(&"run", "recorded level=%s wpm=%d new_best=%s history=%d" % [
			result.level_id, result.wpm, new_best, history.size()])
	return new_best


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
	if item_id == &"":
		return false
	return _owned().has(String(item_id))


## The owned ids in purchase order, skipping junk a hand-edited save may hold.
func get_owned_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: String in _owned():
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
	var id: String = _stored_id(_equipped(), slot)
	if id.is_empty() or not owns(StringName(id)):
		return &""
	var item: CosmeticItem = catalogue.get_item(StringName(id))
	if item == null or not item.is_available:
		return &""
	return StringName(id)


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


## Replaces the save with defaults (debug overlay F8). The old save.json becomes save.bak on the write.
func reset_all() -> void:
	save_service.reset_to_defaults()
	profile_replaced.emit()


func _profile() -> Dictionary:
	return save_service.get_active_profile()


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


## The distinct non-empty String ids in owned_items; anything else a hand-edited save holds is skipped.
func _owned() -> Array[String]:
	var result: Array[String] = []
	for value: Variant in _profile()["owned_items"]:
		if value is String and not (value as String).is_empty() and not result.has(value):
			result.append(value)
	return result


## The String stored for `slot`, or "" when missing or not a String.
func _stored_id(equipped: Dictionary, slot: StringName) -> String:
	var value: Variant = equipped.get(String(slot), "")
	return value if value is String else ""
