extends Control
## Chalkboard report card (Story 2.9, FR19-FR21): the level name, the run's stats on a chalkboard,
## Professor Zombie pointing at it, a "New best!" stamp, and Play Again / Menu.
## Payload: {"result": RunResult, "new_best": bool}, read once in _ready(). A missing or wrong result
## logs a warning and shows zeros under the fallback heading; new_best counts only when it is a bool.
## Mash guard (FR21): for the first GameConstants.REPORT_CARD_INPUT_GUARD_S seconds the screen is live,
## every key or mouse press is swallowed in _input, before the focused button sees it. The time is
## counted in _process, which does not run while the Router keeps the tree paused for its fade-in.
## One exit: every navigation goes through _leave(), at most once per card; keep it the only place that
## navigates. Welcome Gift (Story 4.5): a card opened with a RunResult whose exit finds the
## welcome_bonus_claimed flag still false goes to the Welcome Gift instead of where it was asked, so the first
## completed run's exit (Play Again, Menu, Esc or Enter) shows the gift once. The flag is read at leave time
## and never written here (the gift owns it). That one flag is all this screen reads from PlayerData.
## Story 5.0 art: the chalkboard and keycaps are theme boxes, the chalk tray, the "New best!" stamp (pre-rotated)
## and the window's moon and bat are sprites, and Play Again / Menu are PixelButtons (the focused fill and
## ring are theirs). Sounds (chalk-scratch per row, chime, stamp thump) are Story 5.1.
## The worn hat and pet fill the Professor's slots by themselves (Story 4.3).

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
## Level replayed by Play Again when the payload has no result.
const FALLBACK_LEVEL_ID: StringName = &"zombie_run"
## Heading when there is no level to name (no result, or a result without a level id).
const FALLBACK_HEADING: String = "Report Card"
## UX assumption (EXPERIENCE.md "Report card open"): the write-on reveal shows one row per this many
## seconds, top to bottom, then the stamp.
const REVEAL_STEP_S: float = 0.1
## %Row0..%Row5 hold the six stats; this row holds the "+N bonus" line.
const BONUS_ROW: int = 6

## Level name lookup (data/levels/level_registry.tres, set in report_card.tscn).
@export var level_registry: LevelRegistry

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready; tests assign a
## recorder before add_child so the live Router never swaps GUT's scene.
var navigate: Callable
## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null

var _level_id: StringName = FALLBACK_LEVEL_ID
var _new_best: bool = false
## The payload had a RunResult: only such a card can send the first exit to the Welcome Gift.
var _has_result: bool = false
## Seconds the screen has been live (unpaused); drives the guard and the reveal.
var _open_s: float = 0.0
## Set by the one navigation; nothing navigates after it.
var _leaving: bool = false
## Rows in reveal order; the bonus row is only in it when there is a bonus.
var _rows: Array[Control] = []


func _ready() -> void:
	if not navigate.is_valid():
		navigate = Router.go
	if player_data == null:
		player_data = PlayerData
	var payload: Dictionary = Router.take_payload()
	var raw: Variant = payload.get("result")
	var result: RunResult = raw if raw is RunResult else null
	var flag: Variant = payload.get("new_best", false)
	if result == null:
		Log.warn(&"ui", "report card opened without a RunResult")
	else:
		_has_result = true
		_new_best = flag is bool and flag
		if result.level_id != &"":
			_level_id = result.level_id
	_fill(result)
	var has_bonus: bool = result != null and result.bonus_brains > 0
	for i: int in BONUS_ROW + 1:
		var row: Control = get_node("%%Row%d" % i)
		row.hide()
		if i != BONUS_ROW or has_bonus:
			_rows.append(row)
	%Stamp.hide()
	%PlayAgainButton.pressed.connect(_on_play_again_button_pressed)
	%MenuButton.pressed.connect(_on_menu_button_pressed)
	%PlayAgainButton.grab_focus()


func _process(delta: float) -> void:
	_open_s += delta
	var shown: int = 0
	for i: int in _rows.size():
		if _open_s >= i * REVEAL_STEP_S:
			_rows[i].show()
			shown += 1
	var stamp_done: bool = not _new_best or _open_s >= _rows.size() * REVEAL_STEP_S
	if _new_best and stamp_done:
		%Stamp.show()
	if shown == _rows.size() and stamp_done and _guard_passed():
		set_process(false)


func _input(event: InputEvent) -> void:
	var echo: bool = event is InputEventKey and (event as InputEventKey).echo
	if echo or (event.is_pressed() and (_leaving or not _guard_passed())):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_to_menu()
	elif event.is_action_pressed(&"ui_accept") and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()
		_play_again()


## True once the mash guard is over.
func _guard_passed() -> bool:
	return _open_s >= GameConstants.REPORT_CARD_INPUT_GUARD_S


func _fill(result: RunResult) -> void:
	%Heading.text = _heading(result.level_id if result != null else &"")
	if result == null:
		for value: Label in [%KeysValue, %ErrorsValue, %WpmValue, %BrainsValue]:
			value.text = "0"
		%AccuracyValue.text = "0%"
		%TimeValue.text = StatsCalculator.format_time(0.0)
		return
	%KeysValue.text = str(result.keys_typed)
	%ErrorsValue.text = str(result.errors)
	%WpmValue.text = str(result.wpm)
	%AccuracyValue.text = "%d%%" % result.accuracy
	%TimeValue.text = result.lesson_time()
	%BrainsValue.text = str(result.total_brains())
	%BonusLabel.text = "+%d bonus" % result.bonus_brains


## The registry's display name, else the id capitalized ("zombie_run" -> "Zombie Run"), else the
## fallback heading. Never an error: a missing name must not stop the screen (NFR16).
func _heading(level_id: StringName) -> String:
	if level_id == &"":
		return FALLBACK_HEADING
	var entry: LevelEntry = level_registry.get_entry(level_id) if level_registry != null else null
	if entry != null and not entry.display_name.is_empty():
		return entry.display_name
	return String(level_id).capitalize()


func _play_again() -> void:
	# No seed: a replay gets a fresh letter bag.
	_leave(Router.Screen.RUN, {"level_id": _level_id})


func _leave_to_menu() -> void:
	_leave(Router.Screen.MAIN_MENU, {})


## The only navigation: ignored during the guard and after the first call. The first completed run's exit
## goes to the Welcome Gift instead (Story 4.5).
func _leave(screen: Router.Screen, payload: Dictionary) -> void:
	if _leaving or not _guard_passed():
		return
	_leaving = true
	if _has_result and not player_data.get_flag(&"welcome_bonus_claimed"):
		screen = Router.Screen.WELCOME_GIFT
		payload = {}
	navigate.call(screen, payload)


func _on_play_again_button_pressed() -> void:
	_play_again()


func _on_menu_button_pressed() -> void:
	_leave_to_menu()
