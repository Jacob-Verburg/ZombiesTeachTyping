extends Control
## The Progress screen (Story 10.5, FR77): how a kid's typing is going, for a parent, one step from the main
## menu. A chalkboard of four lifetime totals (Keys Typed, Best WPM, Brains Earned, Time Practiced) and three
## chalk bar charts: WPM and accuracy of the newest RECENT_RUNS recorded runs (all levels together, oldest
## left) and practice time per local day for the newest PRACTICE_DAYS days that have practice (days without
## practice are skipped, NFR11). With no recorded run the charts hide and one sign says how to fill them;
## the totals still show. No tier, no grade, no goal, no comparison, no timer (FR60, NFR9-NFR11).
## Read-only (Boundary 4): only PlayerData getters, nothing written. Everything is re-read on
## profile_replaced (F8 reset while open) and run_recorded. Junk save values read as 0 (NFR16).
## One exit: Esc, or Enter / a click on %MenuButton (the only focusable control, focused on open), goes to
## the main menu through _leave(), at most once, with a UI click. The payload is consumed and ignored.
## Seams (tests assign them before add_child): navigate, player_data, play_sfx, play_music, is_transitioning
## and time_zone_bias (minutes, local minus UTC; on web it may be 0, so days are UTC days there).

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
## Look value, not a GDD number: how many recent runs the WPM and accuracy charts show (20 bars fill 320 px).
const RECENT_RUNS: int = 20
## Look value, not a GDD number: how many practice days the practice chart shows.
const PRACTICE_DAYS: int = 7
## Look value, not a GDD number: a first slow run is not a full-height bar.
const WPM_SCALE_FLOOR: int = 10
## Look value, not a GDD number: 100 % accuracy is a full bar.
const ACCURACY_SCALE: int = 100
## Look value, not a GDD number: 10 minutes; a short first day is not a full-height bar.
const PRACTICE_SCALE_FLOOR_S: int = 600
## Look value, not a GDD number: practice bars are wider (7 bars, not 20).
const PRACTICE_BAR_W: int = 32
const PRACTICE_BAR_GAP: int = 8
const WPM_TITLE: String = "Words per minute"
const ACCURACY_TITLE: String = "Accuracy"
const PRACTICE_TITLE: String = "Practice time"

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready.
var navigate: Callable
## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null
## Test seam: called as play_sfx.call(cue_id). Defaults to AudioManager.play_sfx in _ready.
var play_sfx: Callable
## Test seam: called as play_music.call(music_id). Defaults to AudioManager.play_music in _ready.
var play_music: Callable
## Test seam: defaults to Router.is_transitioning in _ready.
var is_transitioning: Callable
## Test seam: returns the local time zone's offset from UTC in minutes. Defaults to the system's.
var time_zone_bias: Callable

## Set by the one navigation; nothing navigates after it.
var _leaving: bool = false


func _ready() -> void:
	if not navigate.is_valid():
		navigate = Router.go
	if player_data == null:
		player_data = PlayerData
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	if not play_music.is_valid():
		play_music = AudioManager.play_music
	if not is_transitioning.is_valid():
		is_transitioning = Router.is_transitioning
	if not time_zone_bias.is_valid():
		time_zone_bias = _system_bias
	Router.take_payload()
	play_music.call(&"mus_menu")
	(%WpmChart as TrendChart).set_title(WPM_TITLE)
	(%AccuracyChart as TrendChart).set_title(ACCURACY_TITLE)
	(%PracticeChart as TrendChart).set_title(PRACTICE_TITLE)
	player_data.profile_replaced.connect(_show)
	player_data.run_recorded.connect(_on_run_recorded)
	%MenuButton.pressed.connect(_leave)
	_show()
	%MenuButton.grab_focus()


func _exit_tree() -> void:
	if player_data == null:
		return
	if player_data.profile_replaced.is_connected(_show):
		player_data.profile_replaced.disconnect(_show)
	if player_data.run_recorded.is_connected(_on_run_recorded):
		player_data.run_recorded.disconnect(_on_run_recorded)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


## Fills the totals and the charts (or the empty sign) from PlayerData.
func _show() -> void:
	var totals: Dictionary = player_data.get_lifetime()
	%KeysValue.text = str(int(totals["keys_typed"]))
	%BestWpmValue.text = str(player_data.get_best_wpm_overall())
	%BrainsValue.text = str(int(totals["brains"]))
	%TimeValue.text = TrendsCalculator.format_practice_time(int(totals["seconds"]))
	var history: Array[Dictionary] = player_data.get_run_history()
	var empty: bool = history.is_empty()
	%EmptySign.visible = empty
	for chart: Control in [%WpmChart, %AccuracyChart, %PracticeChart]:
		chart.visible = not empty
	if empty:
		return
	var runs: Array[Dictionary] = TrendsCalculator.recent_runs(history, RECENT_RUNS)
	(%WpmChart as TrendChart).show_values(TrendsCalculator.wpm_series(runs), WPM_SCALE_FLOOR)
	(%AccuracyChart as TrendChart).show_values(TrendsCalculator.accuracy_series(runs), ACCURACY_SCALE)
	var bias: Variant = time_zone_bias.call()
	var days: Array[int] = TrendsCalculator.daily_seconds(history, PRACTICE_DAYS, bias if bias is int else 0)
	(%PracticeChart as TrendChart).show_values(days, PRACTICE_SCALE_FLOOR_S, PRACTICE_BAR_W, PRACTICE_BAR_GAP)


func _on_run_recorded(_level_id: StringName, _new_best: bool) -> void:
	_show()


## The only navigation, at most once: back to the main menu with a UI click. Released if the Router's
## transition ends without freeing this screen (the target failed to load), so the screen is not left dead.
func _leave() -> void:
	if _leaving or is_transitioning.call():
		return
	_leaving = true
	play_sfx.call(&"sfx_ui_click")
	navigate.call(Router.Screen.MAIN_MENU, {})
	if not is_transitioning.call():
		return
	while is_transitioning.call():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_leaving = false


## The system time zone's bias in minutes (0 when unknown).
static func _system_bias() -> int:
	var bias: Variant = Time.get_time_zone_from_system().get("bias", 0)
	return int(bias) if bias is int or bias is float else 0
