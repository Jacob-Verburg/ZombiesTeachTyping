extends GutTest
## The Progress screen (Story 10.5, FR77): totals from the lifetime getters, the three charts (or the empty
## sign), the bias seam, Esc / Menu back to the main menu once, focus, re-reads on profile_replaced, nothing
## written, and the layout (16 px margin, 16 px text, labels fit, no overlaps).
## Always a temp-dir SaveService + PlayerData and recorder seams: the real save and the live Router are never
## touched. Instances are disabled, so handlers are called directly.

const TrendsScene: PackedScene = preload("res://scenes/screens/trends.tscn")
const TrendsScript := preload("res://scripts/screens/trends.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_trends/"
const SAFE_RECT: Rect2 = Rect2(16, 16, 608, 328)
const DAY: int = 86400
## 2026-09-01 00:00:00 UTC.
const DAY0: int = 1788220800
## Words the screen must never show (FR60, NFR10): the tier and difficulty words.
const NEVER: Array[String] = ["tier", "rank", "grade", "easy", "hard", "level", "goal", "streak"]


## A SaveService that counts request_save() calls.
class CountingSave extends SaveServiceScript:
	var requests: int = 0

	func request_save() -> void:
		requests += 1
		super.request_save()


var _save: CountingSave
var _player: PlayerDataScript
var _screen: TrendsScript
var _nav: Array = []
var _sfx: Array[StringName] = []
var _music: Array[StringName] = []
var _transitioning: bool = false
var _bias: int = 0


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_nav = []
	_sfx = []
	_music = []
	_transitioning = false
	_bias = 0
	_save = CountingSave.new()
	_save.save_dir = TEST_DIR
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)


func after_each() -> void:
	Router.take_payload()
	_clear()
	_reset_input_handled()
	_screen = null
	_player = null
	_save = null


## Calling _unhandled_input() by hand marks GUT's viewport input as handled, and headless no real event ever
## clears it. Pushing a no-op event resets the flag so later tests start clean.
func _reset_input_handled() -> void:
	get_viewport().push_input(InputEventAction.new())


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _make() -> TrendsScript:
	var screen: TrendsScript = TrendsScene.instantiate() as TrendsScript
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.navigate = func(target: int, payload: Dictionary) -> void: _nav.append([target, payload])
	screen.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	screen.play_music = func(id: StringName) -> void: _music.append(id)
	screen.is_transitioning = func() -> bool: return _transitioning
	screen.time_zone_bias = func() -> int: return _bias
	screen.player_data = _player
	add_child_autofree(screen)
	_screen = screen
	return screen


func _run(stamp: int, keys: int = 50, seconds: float = 120.0, brains: int = 5, errors: int = 0) -> void:
	_player.record_run(RunResult.create(
		&"zombie_run", stamp, seconds, keys, errors, {}, brains, 0, "all", GameConstants.END_REASON_TIMER))


func _label(path: String) -> String:
	return (_screen.get_node(path) as Label).text


func _chart(path: String) -> TrendChart:
	return _screen.get_node(path) as TrendChart


func _esc() -> InputEventAction:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


# --- Content -------------------------------------------------------------------------------------------

func test_empty_save_shows_the_sign_and_zero_totals() -> void:
	_make()
	assert_true((_screen.get_node("%EmptySign") as Control).visible)
	for path: String in ["%WpmChart", "%AccuracyChart", "%PracticeChart"]:
		assert_false((_screen.get_node(path) as Control).visible, "%s hidden" % path)
	assert_eq(_label("%EmptyLabel"), "Finish a game to see your charts!")
	assert_eq(_label("%KeysValue"), "0")
	assert_eq(_label("%BestWpmValue"), "0")
	assert_eq(_label("%BrainsValue"), "0")
	assert_eq(_label("%TimeValue"), "0 min")


func test_quit_brains_show_in_the_empty_state() -> void:
	_player.add_brains(100)
	_make()
	assert_true((_screen.get_node("%EmptySign") as Control).visible)
	assert_eq(_label("%BrainsValue"), "100")


func test_only_junk_history_is_the_empty_state() -> void:
	(_save.get_active_profile()["run_history"] as Array).append_array(["oops", 5, null])
	_make()
	assert_true((_screen.get_node("%EmptySign") as Control).visible)
	assert_false((_screen.get_node("%WpmChart") as Control).visible)


func test_one_run_shows_one_bar_per_chart() -> void:
	# 50 keys in 120 s -> 5 WPM, 100 % accuracy, 2 minutes.
	_run(DAY0 + 3600)
	_make()
	assert_false((_screen.get_node("%EmptySign") as Control).visible)
	for path: String in ["%WpmChart", "%AccuracyChart", "%PracticeChart"]:
		assert_true((_screen.get_node(path) as Control).visible, "%s shown" % path)
	assert_eq(_chart("%WpmChart").get_bar_heights(), [16] as Array[int], "5 WPM against the floor of 10")
	assert_eq(_chart("%AccuracyChart").get_bar_heights(), [32] as Array[int], "100 % is full height")
	assert_eq(_chart("%PracticeChart").get_bar_heights(), [6] as Array[int], "120 s against the 600 s floor")
	assert_eq(_label("%KeysValue"), "50")
	assert_eq(_label("%BestWpmValue"), "5")
	assert_eq(_label("%BrainsValue"), "5")
	assert_eq(_label("%TimeValue"), "2 min")


func test_chart_titles() -> void:
	_run(DAY0 + 3600)
	_make()
	assert_eq((_screen.get_node("%WpmChart/%Title") as Label).text, "Words per minute")
	assert_eq((_screen.get_node("%AccuracyChart/%Title") as Label).text, "Accuracy")
	assert_eq((_screen.get_node("%PracticeChart/%Title") as Label).text, "Practice time")


func test_twenty_five_runs_show_the_newest_twenty() -> void:
	for i: int in 25:
		_run(DAY0 + i * 60, 10 * (i + 1), 60.0)
	_make()
	var heights: Array[int] = _chart("%WpmChart").get_bar_heights()
	assert_eq(heights.size(), TrendsScript.RECENT_RUNS)
	# Run i has 10 * (i + 1) keys in 60 s -> 2 * (i + 1) WPM; the newest (50 WPM) is the full-height last bar.
	assert_eq(heights[-1], 32, "newest last, tallest")
	assert_lt(heights[0], heights[-1], "oldest shown first")
	assert_eq(_chart("%AccuracyChart").get_bar_heights().size(), TrendsScript.RECENT_RUNS)


func test_practice_chart_skips_empty_days_and_keeps_seven() -> void:
	var day_offsets: Array[int] = [0, 1, 3, 4, 6, 8, 10, 12, 15]
	for i: int in day_offsets.size():
		_run(DAY0 + day_offsets[i] * DAY + 7200, 50, 60.0 * (i + 1))
	_make()
	var heights: Array[int] = _chart("%PracticeChart").get_bar_heights()
	assert_eq(heights.size(), TrendsScript.PRACTICE_DAYS)
	var expected: Array[int] = []
	for minutes: int in [3, 4, 5, 6, 7, 8, 9]:
		expected.append(minutes * 60)
	assert_eq(heights, TrendsCalculator.bar_heights(expected, 32, TrendsScript.PRACTICE_SCALE_FLOOR_S))


func test_bias_moves_a_run_across_midnight() -> void:
	_run(DAY0 - 3600)  # 23:00 UTC the day before
	_run(DAY0 + 3600)  # 01:00 UTC
	_make()
	assert_eq(_chart("%PracticeChart").get_bar_heights().size(), 2, "two UTC days")
	_bias = 120  # UTC+2: both runs are on the same local day
	_screen.call("_show")
	assert_eq(_chart("%PracticeChart").get_bar_heights().size(), 1, "one local day")


func test_a_junk_bias_reads_as_utc() -> void:
	_run(DAY0 - 3600)
	_run(DAY0 + 3600)
	var screen: TrendsScript = TrendsScene.instantiate() as TrendsScript
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.navigate = func(_t: int, _p: Dictionary) -> void: pass
	screen.play_sfx = func(_id: StringName) -> void: pass
	screen.play_music = func(_id: StringName) -> void: pass
	screen.time_zone_bias = func() -> String: return "x"
	screen.player_data = _player
	add_child_autofree(screen)
	assert_eq((screen.get_node("%PracticeChart") as TrendChart).get_bar_heights().size(), 2)


func test_totals_come_from_the_lifetime_getters_and_survive_the_cap() -> void:
	for i: int in GameConstants.RUN_HISTORY_CAP + 3:
		_run(DAY0 + i, 10, 60.0, 1)
	_make()
	var runs: int = GameConstants.RUN_HISTORY_CAP + 3
	var totals: Dictionary = _player.get_lifetime()
	assert_eq(int(totals["runs"]), runs)
	assert_eq(_label("%KeysValue"), str(10 * runs))
	assert_eq(_label("%BrainsValue"), str(runs))
	assert_eq(_label("%TimeValue"), TrendsCalculator.format_practice_time(60 * runs))
	assert_eq(_label("%TimeValue"), "8 hr 23 min")


func test_best_wpm_is_the_highest_level_best() -> void:
	_run(DAY0)
	_save.get_active_profile()["best_wpm"] = {"zombie_run": 12, "horde_rush": 23, "pitchfork_panic": 7}
	_make()
	assert_eq(_label("%BestWpmValue"), "23")


func test_junk_totals_read_as_zero_without_errors() -> void:
	_save.get_active_profile()["lifetime"] = {"runs": "x", "keys_typed": -4, "seconds": 2.5}
	_save.get_active_profile()["best_wpm"] = "lots"
	_make()
	assert_eq(_label("%KeysValue"), "0")
	assert_eq(_label("%BestWpmValue"), "0")
	assert_eq(_label("%BrainsValue"), "0")
	assert_eq(_label("%TimeValue"), "0 min")
	assert_push_error_count(0)


func test_profile_replaced_rereads_to_the_empty_state() -> void:
	_run(DAY0)
	_make()
	assert_false((_screen.get_node("%EmptySign") as Control).visible)
	_player.reset_all()
	assert_true((_screen.get_node("%EmptySign") as Control).visible)
	assert_false((_screen.get_node("%WpmChart") as Control).visible)
	assert_eq(_label("%KeysValue"), "0")


func test_run_recorded_rereads() -> void:
	_make()
	_run(DAY0)
	assert_false((_screen.get_node("%EmptySign") as Control).visible)
	assert_eq(_label("%KeysValue"), "50")


func test_disconnects_from_player_data_on_exit() -> void:
	_make()
	assert_true(_player.profile_replaced.is_connected(_screen._show))
	remove_child(_screen)
	assert_false(_player.profile_replaced.is_connected(_screen._show))
	assert_false(_player.run_recorded.is_connected(_screen._on_run_recorded))
	_screen.free()


func test_nothing_is_written() -> void:
	_run(DAY0)
	await wait_process_frames(2)
	var before: int = _save.requests
	var file_before: String = FileAccess.get_file_as_string(TEST_DIR.path_join("save.json"))
	_make()
	_screen.call("_show")
	_screen._unhandled_input(_esc())
	await wait_process_frames(2)
	assert_eq(_save.requests, before, "no save request")
	assert_eq(FileAccess.get_file_as_string(TEST_DIR.path_join("save.json")), file_before, "file untouched")


func test_music_and_payload() -> void:
	Router._store_payload({"stale": true})
	_make()
	assert_eq(Router.take_payload(), {}, "payload consumed")
	assert_eq(_music, [&"mus_menu"] as Array[StringName])
	assert_eq(_nav, [], "opening navigates nowhere")


func test_no_string_shows_the_tier_or_a_rank() -> void:
	_run(DAY0)
	_make()
	for node: Node in _screen.find_children("*", "Label", true, false):
		var text: String = (node as Label).text.to_lower()
		for word: String in NEVER:
			assert_false(text.contains(word), "%s '%s' contains '%s'" % [node.name, text, word])
		assert_false(text.contains("all"), "%s shows a letter pool label" % node.name)


# --- Navigation and focus ------------------------------------------------------------------------------

func test_esc_goes_to_the_menu_once() -> void:
	_make()
	_screen._unhandled_input(_esc())
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])
	_screen._unhandled_input(_esc())
	(_screen.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav.size(), 1, "one navigation per screen")
	assert_eq(_sfx.size(), 1, "one click")


func test_menu_button_goes_to_the_menu_once() -> void:
	_make()
	(_screen.get_node("%MenuButton") as Button).pressed.emit()
	(_screen.get_node("%MenuButton") as Button).pressed.emit()
	assert_eq(_nav, [[Router.Screen.MAIN_MENU, {}]])
	assert_eq(_sfx, [&"sfx_ui_click"] as Array[StringName])


func test_nothing_happens_during_a_router_transition() -> void:
	_make()
	_transitioning = true
	_screen._unhandled_input(_esc())
	assert_eq(_nav, [])
	assert_eq(_sfx, [] as Array[StringName])


func test_leaving_is_released_when_the_transition_ends_without_freeing_the_screen() -> void:
	_make()
	_screen.navigate = func(target: int, payload: Dictionary) -> void:
		_nav.append([target, payload])
		_transitioning = true
	_screen._unhandled_input(_esc())
	assert_eq(_nav.size(), 1)
	_transitioning = false
	await wait_process_frames(2)
	_screen._unhandled_input(_esc())
	assert_eq(_nav.size(), 2, "a failed swap leaves the screen usable")


func test_menu_button_starts_focused_and_is_the_only_focusable_control() -> void:
	_run(DAY0)
	_make()
	var button: Button = _screen.get_node("%MenuButton") as Button
	assert_true(button.has_focus())
	for node: Node in _screen.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control != button:
			assert_eq(control.focus_mode, Control.FOCUS_NONE, "%s takes no focus" % control.name)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(button.get_node_or_null(button.get_focus_neighbor(side)), button)


# --- Layout --------------------------------------------------------------------------------------------

func _blocks() -> Array[Control]:
	var result: Array[Control] = []
	for path: String in ["%Heading", "%Totals", "%WpmChart", "%AccuracyChart", "%PracticeChart", "%MenuButton",
			"%EscHint"]:
		result.append(_screen.get_node(path) as Control)
	return result


func test_every_block_is_inside_the_margin_and_overlaps_nothing() -> void:
	_run(DAY0)
	_make()
	await wait_process_frames(2)
	var blocks: Array[Control] = _blocks()
	blocks.append(_screen.get_node("%EmptySign") as Control)
	for control: Control in blocks:
		var rect: Rect2 = control.get_global_rect()
		assert_true(SAFE_RECT.encloses(rect), "%s %s outside the 16 px margin" % [control.name, rect])
	for i: int in blocks.size():
		for j: int in range(i + 1, blocks.size()):
			var a: Control = blocks[i]
			var b: Control = blocks[j]
			var charts_and_sign: bool = b.name == "EmptySign" and a.name.ends_with("Chart")
			if charts_and_sign:
				continue  # never shown together
			assert_false(a.get_global_rect().intersects(b.get_global_rect()), "%s overlaps %s" % [a.name, b.name])


func test_empty_sign_and_charts_are_never_shown_together() -> void:
	_make()
	assert_true((_screen.get_node("%EmptySign") as Control).visible)
	for path: String in ["%WpmChart", "%AccuracyChart", "%PracticeChart"]:
		assert_false((_screen.get_node(path) as Control).visible)


func test_menu_button_is_tall_enough() -> void:
	_make()
	assert_gte((_screen.get_node("%MenuButton") as Control).size.y, 32.0)


func test_text_fits_and_is_at_least_16px_with_the_longest_values() -> void:
	_run(DAY0)
	_make()
	for path: String in ["%KeysValue", "%BestWpmValue", "%BrainsValue"]:
		(_screen.get_node(path) as Label).text = "999999"
	(_screen.get_node("%TimeValue") as Label).text = "99 hr 59 min"
	await wait_process_frames(2)
	var checked: int = 0
	for state: bool in [false, true]:
		(_screen.get_node("%EmptySign") as Control).visible = state
		await wait_process_frames(1)
		for node: Node in _screen.find_children("*", "Control", true, false):
			var control: Control = node as Control
			if not control.is_visible_in_tree():
				continue
			if control is Label:
				_assert_label_fits(control as Label)
				checked += 1
			elif control is Button:
				var button: Button = control as Button
				assert_gte(button.get_theme_font_size(&"font_size"), 16, "%s font size" % button.name)
				assert_lte(button.get_minimum_size().x, button.size.x, "%s text overflows" % button.name)
				checked += 1
	assert_gt(checked, 12, "the walk found the screen's text")


func _assert_label_fits(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	assert_gte(font_size, 16, "%s font size" % label.name)
	assert_lte(label.get_minimum_size().y, label.size.y, "%s taller than its box" % label.name)
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(width, label.size.x, "%s '%s' overflows" % [label.name, label.text])
		return
	for word: String in label.text.split(" "):
		var word_width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_lte(word_width, label.size.x, "%s word '%s' overflows" % [label.name, word])
	var lines_height: float = label.get_line_count() * label.get_line_height()
	assert_lte(lines_height, label.size.y, "%s wraps taller than its box" % label.name)
