extends Node
## Loads and writes the save file. The only script that touches files (FileAccess/DirAccess).
## Load: save.json, else save.bak, else SaveSchema defaults; then SaveSchema.prepare() (numbers,
## migrations, missing fields). Nothing is ever shown to the player; problems are only logged.
## Write order: save.tmp -> copy the current good save.json to save.bak -> rename save.tmp over
## save.json (a direct write of save.json if the rename fails). A corrupt save.json is never backed up.
## When: request_save() coalesces every request in a frame into one write at the end of the frame;
## a tab hide (WebPlatform.visibility_hidden) or a desktop window close writes immediately, but only
## when something changed (a clean write would just rotate save.bak into a copy of save.json).
## A save written by a newer build is loaded read-only: it is never written back.
## get_data()/get_active_profile() hand out the live dictionaries, and reset_to_defaults() replaces
## them: PlayerData only. Nobody else edits save fields.
## Export (Story 1.8): offer_export() hands export_json() to the download as export_file_name()
## (zts-save-YYYYMMDD.json, local date). Callable by the main menu (Ctrl+Shift+E) and the debug
## overlay (F9). On desktop it first writes the file next to the save, because the desktop download
## only opens the user:// folder. Never changes the save; never logs its contents.
## save_dir and offer_download are test seams: tests set them before add_child.

signal save_written

const SAVE_FILE: String = "save.json"
const TMP_FILE: String = "save.tmp"
const BACKUP_FILE: String = "save.bak"
const EXPORT_NAME_FORMAT: String = "zts-save-%04d%02d%02d.json"

var save_dir: String = "user://"
## Time.get_ticks_msec() of the last successful write; -1 before the first one (debug overlay).
var last_write_ticks_msec: int = -1
## Delivers the export bytes; WebPlatform.offer_download unless a test set it before add_child.
var offer_download: Callable = Callable()

var _data: Dictionary = {}
var _dirty: bool = false
var _flush_scheduled: bool = false
## True when save.json holds a good save (loaded from it, or written by us), so it may be backed up.
var _main_valid: bool = false
## True when the loaded save has a schema_version newer than this build; writes are refused.
var _read_only: bool = false


func _ready() -> void:
	_data = load_save()
	if not offer_download.is_valid():
		offer_download = WebPlatform.offer_download
	WebPlatform.visibility_hidden.connect(_on_web_platform_visibility_hidden)


func _exit_tree() -> void:
	if WebPlatform.visibility_hidden.is_connected(_on_web_platform_visibility_hidden):
		WebPlatform.visibility_hidden.disconnect(_on_web_platform_visibility_hidden)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty:
		save_now()


func load_save() -> Dictionary:
	var main: String = save_dir.path_join(SAVE_FILE)
	var bak: String = save_dir.path_join(BACKUP_FILE)
	var main_exists: bool = FileAccess.file_exists(main)
	var data: Dictionary = _read_json(main)
	_main_valid = not data.is_empty()
	if _main_valid:
		Log.info(&"save", "loaded save.json")
	else:
		data = _read_json(bak)
		if not data.is_empty():
			Log.warn(&"save", "save.json %s, using save.bak" % ("unreadable" if main_exists else "missing"))
		elif main_exists or FileAccess.file_exists(bak):
			Log.warn(&"save", "no valid save, starting fresh")
			data = SaveSchema.defaults()
		else:
			Log.info(&"save", "no valid save, starting fresh")
			data = SaveSchema.defaults()
	data = SaveSchema.prepare(data)
	_read_only = int(data["schema_version"]) > GameConstants.CURRENT_SCHEMA
	return data


## The export's file name from the local date: now, or unix_time (seconds, UTC) when given.
static func export_file_name(unix_time: float = -1.0) -> String:
	var date: Dictionary
	if unix_time < 0.0:
		date = Time.get_datetime_dict_from_system()
	else:
		var bias_min: int = int(Time.get_time_zone_from_system()["bias"])
		date = Time.get_date_dict_from_unix_time(int(unix_time) + bias_min * 60)
	return EXPORT_NAME_FORMAT % [date["year"], date["month"], date["day"]]


## The live save. PlayerData only.
func get_data() -> Dictionary:
	return _data


## The live active profile. PlayerData only.
func get_active_profile() -> Dictionary:
	return _data["profiles"][_data["active_profile"]]


## Marks the save dirty; every request in the same frame becomes one write at the end of the frame.
func request_save() -> void:
	_dirty = true
	if not _flush_scheduled:
		_flush_scheduled = true
		_flush.call_deferred()


## Writes now, synchronously. A failed write stays dirty so the next request retries.
func save_now() -> Error:
	if _read_only:
		Log.warn(&"save", "save is from a newer build, not writing")
		return ERR_LOCKED
	var text: String = _serialize()
	var err: Error = _ensure_dir()
	if err != OK:
		Log.error(&"save", "cannot create %s: %s" % [save_dir, error_string(err)])
		_dirty = true
		return err
	var main: String = save_dir.path_join(SAVE_FILE)
	var tmp: String = save_dir.path_join(TMP_FILE)
	var bak: String = save_dir.path_join(BACKUP_FILE)
	err = _write_text(tmp, text)
	if err != OK:
		Log.error(&"save", "write failed %s: %s" % [tmp, error_string(err)])
		DirAccess.remove_absolute(tmp)
		_dirty = true
		return err
	if _main_valid and FileAccess.file_exists(main):
		var copy_err: Error = DirAccess.copy_absolute(main, bak)
		if copy_err != OK:
			Log.warn(&"save", "backup copy failed: %s" % error_string(copy_err))
	err = DirAccess.rename_absolute(tmp, main)
	if err != OK:
		Log.warn(&"save", "rename failed (%s), writing save.json directly" % error_string(err))
		err = _write_text(main, text)
		if err != OK:
			Log.error(&"save", "direct write failed: %s" % error_string(err))
			_dirty = true
			return err
		DirAccess.remove_absolute(tmp)
	_dirty = false
	_main_valid = true
	last_write_ticks_msec = Time.get_ticks_msec()
	Log.info(&"save", "written (%d bytes)" % text.to_utf8_buffer().size())
	save_written.emit()
	return OK


## The save exactly as save_now() writes it. Never touches the file system.
func export_json() -> String:
	return _serialize()


## Offers the save as a download (web) or writes it next to the save and opens the folder (desktop).
func offer_export() -> void:
	var text: String = export_json()
	var file_name: String = export_file_name()
	if not WebPlatform.is_web():
		var err: Error = _ensure_dir()
		if err == OK:
			err = _write_text(save_dir.path_join(file_name), text)
		if err != OK:
			Log.error(&"save", "export write failed %s: %s" % [file_name, error_string(err)])
			return
	offer_download.call(text.to_utf8_buffer(), file_name)


## Replaces the save with defaults and writes it. PlayerData only (PlayerData.reset_all()).
## _main_valid is kept, so the next write still copies the old save.json to save.bak.
func reset_to_defaults() -> void:
	_data = SaveSchema.defaults()
	_read_only = false
	Log.info(&"save", "reset to defaults")
	request_save()


func _serialize() -> String:
	return JSON.stringify(_data, "\t")


func _flush() -> void:
	_flush_scheduled = false
	if _dirty:
		save_now()


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error(&"save", "open failed %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		Log.warn(&"save", "parse failed %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY or (json.data as Dictionary).is_empty():
		Log.warn(&"save", "not a save %s" % path)
		return {}
	var data: Dictionary = json.data
	return data


func _write_text(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(text)
	var err: Error = file.get_error()
	file.close()
	if not stored and err == OK:
		err = ERR_FILE_CANT_WRITE
	return err


func _ensure_dir() -> Error:
	if DirAccess.dir_exists_absolute(save_dir):
		return OK
	return DirAccess.make_dir_recursive_absolute(save_dir)


func _on_web_platform_visibility_hidden() -> void:
	if _dirty:
		save_now()
