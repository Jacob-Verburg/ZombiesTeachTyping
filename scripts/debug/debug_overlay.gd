extends CanvasLayer
## Debug overlay (Story 1.8). Debug builds only: the Router instances it only when OS.is_debug_build()
## (Boundary 7), so in release none of this exists and F3/F5/F8/F9 do nothing.
## F3 toggles it on top of every screen (layer above the Router's fade). It shows FPS, frame time,
## the worst frame in the last 10 s, the last save write and whether storage is persistent.
## Cheats work only while it is open: F5 +CHEAT_BRAINS through PlayerData; F9 = SaveService.offer_export()
## (the same export as the main menu's Ctrl+Shift+E); F8 resets the save through PlayerData.reset_all()
## after a two-step confirm: a second F8 within CONFIRM_SEC. Any other key, the timeout or closing cancels.
## Keys are read in _input, not _unhandled_input: the Keyboard Test screen swallows every key in
## _unhandled_input. PROCESS_MODE_ALWAYS so it works while the tree is paused (Router fade, run pause).
## Closed = no per-frame work (_process off, refresh timer stopped). Nothing is logged per frame.
## A new section (Story 2.10) is one more label plus one more _refresh_* called from _refresh().
## player_data and save_service are test seams: tests assign fresh instances before add_child.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const SaveServiceScript: GDScript = preload("res://scripts/autoloads/save_service.gd")

## Dev cheat amount, not a balance number.
const CHEAT_BRAINS: int = 100
## How long the F8 reset waits for the second F8.
const CONFIRM_SEC: float = 5.0
const REFRESH_SEC: float = 0.25
const HELP_TEXT: String = "F5 +100 brains   F8 reset   F9 export"
const CONFIRM_TEXT: String = "Reset the save? F8 again = yes, any other key = no"

## Test seams: default to the live autoloads in _ready().
var player_data: PlayerDataScript = null
var save_service: SaveServiceScript = null

var _tracker: FrameTracker = FrameTracker.new()
var _last_frame_usec: int = 0
var _confirming: bool = false


static func format_save_age(last_write_ticks_msec: int, now_msec: int) -> String:
	if last_write_ticks_msec < 0:
		return "Last save: never"
	return "Last save: %.1f s ago" % ((now_msec - last_write_ticks_msec) / 1000.0)


func _ready() -> void:
	if player_data == null:
		player_data = PlayerData
	if save_service == null:
		save_service = SaveService
	visible = false
	set_process(false)
	%HelpLabel.text = HELP_TEXT
	%ConfirmLabel.text = CONFIRM_TEXT
	%ConfirmLabel.visible = false
	%RefreshTimer.wait_time = REFRESH_SEC
	%RefreshTimer.timeout.connect(_refresh)
	%ConfirmTimer.wait_time = CONFIRM_SEC
	%ConfirmTimer.one_shot = true
	%ConfirmTimer.timeout.connect(_on_confirm_timer_timeout)


## Real elapsed time between frames, not the time-scaled delta.
func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	_tracker.record(now_usec / 1000000.0, (now_usec - _last_frame_usec) / 1000.0)
	_last_frame_usec = now_usec


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	if key.ctrl_pressed or key.shift_pressed or key.alt_pressed or key.meta_pressed:
		_cancel_confirm()
		return
	if _handle_key(key.keycode):
		get_viewport().set_input_as_handled()


func is_confirming() -> bool:
	return _confirming


## Returns true when the overlay used the key (the caller then marks it handled).
func _handle_key(keycode: Key) -> bool:
	if _confirming and keycode != KEY_F8:
		_cancel_confirm()
	if keycode == KEY_F3:
		_set_open(not visible)
		return true
	if not visible:
		return false
	match keycode:
		KEY_F5:
			player_data.add_brains(CHEAT_BRAINS)
			_refresh()
			return true
		KEY_F8:
			if _confirming:
				_cancel_confirm()
				player_data.reset_all()
				_refresh()
			else:
				_start_confirm()
			return true
		KEY_F9:
			save_service.offer_export()
			return true
	return false


func _set_open(open: bool) -> void:
	visible = open
	set_process(open)
	if open:
		_tracker.clear()
		_last_frame_usec = Time.get_ticks_usec()
		_refresh()
		%RefreshTimer.start()
	else:
		_cancel_confirm()
		%RefreshTimer.stop()


func _start_confirm() -> void:
	_confirming = true
	%ConfirmLabel.visible = true
	%ConfirmTimer.start()


func _cancel_confirm() -> void:
	_confirming = false
	%ConfirmLabel.visible = false
	%ConfirmTimer.stop()


func _refresh() -> void:
	_refresh_stats()
	_refresh_save()


func _refresh_stats() -> void:
	%StatsLabel.text = "FPS %d   Frame %.1f ms\nWorst 10 s: %.1f ms" % [
		Engine.get_frames_per_second(), _tracker.last_ms(), _tracker.worst_ms()
	]


func _refresh_save() -> void:
	var storage: String = "persistent" if WebPlatform.is_storage_persistent() else "NOT persistent"
	%SaveLabel.text = "%s\nStorage: %s" % [
		format_save_age(save_service.last_write_ticks_msec, Time.get_ticks_msec()), storage
	]


func _on_confirm_timer_timeout() -> void:
	_cancel_confirm()
