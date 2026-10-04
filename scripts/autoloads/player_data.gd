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
## save_service is a test seam: tests assign a fresh SaveService (save_dir in a temp folder) before add_child.
## Later methods, by story: buy_item/equip/unequip/set_flag/get_flag (4.1),
## mark_unlock_seen/mark_level_chosen/get_unlock_state (6.8).

signal brains_changed(total: int, delta: int)
signal settings_changed(key: StringName, value: bool)
signal profile_replaced
## A finished run was saved; new_best is true when it beat a saved best WPM for its level.
signal run_recorded(level_id: StringName, new_best: bool)

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
