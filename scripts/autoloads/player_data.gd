extends Node
## Single in-memory source of truth for the active profile; the only code that writes save fields.
## Every mutation emits a typed signal and requests a save (SaveService.request_save(), never save_now()).
## Getters read through SaveService.get_active_profile() on every call: nothing is cached, so a
## reset (Story 1.8) or a profile switch (Epic 11) that replaces SaveService's data is picked up.
## Contract violations (negative amount, unknown setting) log an error and change nothing; no assert(),
## which would fire in GUT's debug run and in release would vanish.
## save_service is a test seam: tests assign a fresh SaveService (save_dir in a temp folder) before add_child.
## Later methods, by story: buy_item/equip/unequip/set_flag/get_flag (4.1), record_run (2.8),
## mark_unlock_seen/mark_level_chosen/get_unlock_state (6.8).

signal brains_changed(total: int, delta: int)
signal settings_changed(key: StringName, value: bool)

const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")

## Test seam: tests assign a fresh SaveService before add_child.
var save_service: SaveServiceScript = null


func _ready() -> void:
	if save_service == null:
		save_service = SaveService


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


func _profile() -> Dictionary:
	return save_service.get_active_profile()


func _settings() -> Dictionary:
	return _profile()["settings"]


func _is_setting(key: StringName) -> bool:
	var defaults: Dictionary = SaveSchema.profile_defaults()["settings"]
	return defaults.has(String(key))
