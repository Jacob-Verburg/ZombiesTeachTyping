extends GutTest
## Debug overlay (Story 1.8): F3 toggle, cheats only while open, F8 two-step confirm, F9 export,
## never blocks the mouse, save-age text. A fresh SaveService (save_dir = TEST_DIR, download seam
## recorded) and a fresh PlayerData are injected before add_child, so the real save is never touched.
## Keys go through _handle_key() directly (no synthetic InputEvent plumbing).

const OverlayScene: PackedScene = preload("res://scenes/debug/debug_overlay.tscn")
const OverlayScript := preload("res://scripts/debug/debug_overlay.gd")
const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const TEST_DIR: String = "user://test_debug_overlay/"

var _save: SaveServiceScript = null
var _player: PlayerDataScript = null
var _downloads: Array[String] = []


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clear()
	_downloads = []


func after_each() -> void:
	_clear()
	_save = null
	_player = null


func _clear() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _record_download(_bytes: PackedByteArray, file_name: String) -> void:
	_downloads.append(file_name)


func _make() -> OverlayScript:
	_save = SaveServiceScript.new()
	_save.save_dir = TEST_DIR
	_save.offer_download = _record_download
	add_child_autofree(_save)
	_player = PlayerDataScript.new()
	_player.save_service = _save
	add_child_autofree(_player)
	var sut: OverlayScript = OverlayScene.instantiate() as OverlayScript
	sut.player_data = _player
	sut.save_service = _save
	add_child_autofree(sut)
	return sut


func _controls(node: Node, found: Array[Control]) -> Array[Control]:
	if node is Control:
		found.append(node as Control)
	for child: Node in node.get_children():
		_controls(child, found)
	return found


func test_root_is_a_hidden_canvas_layer_above_the_fade() -> void:
	var sut: OverlayScript = _make()
	assert_true(sut is CanvasLayer)
	assert_false(sut.visible)
	assert_gt(sut.layer, 100, "above the Router's fade layer")
	assert_eq(sut.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(sut.is_processing(), "closed = no per-frame work")


func test_f3_toggles_and_process_follows() -> void:
	var sut: OverlayScript = _make()
	assert_true(sut._handle_key(KEY_F3))
	assert_true(sut.visible)
	assert_true(sut.is_processing())
	assert_true(sut._handle_key(KEY_F3))
	assert_false(sut.visible)
	assert_false(sut.is_processing())


func test_cheats_do_nothing_while_closed() -> void:
	var sut: OverlayScript = _make()
	assert_false(sut._handle_key(KEY_F5))
	assert_false(sut._handle_key(KEY_F8))
	assert_false(sut._handle_key(KEY_F9))
	assert_eq(_player.get_brains(), 0)
	assert_false(sut.is_confirming())
	assert_eq(_downloads.size(), 0)


func test_f5_adds_cheat_brains_through_player_data() -> void:
	var sut: OverlayScript = _make()
	watch_signals(_player)
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F5))
	assert_true(sut._handle_key(KEY_F5))
	assert_eq(OverlayScript.CHEAT_BRAINS, 100)
	assert_eq(_player.get_brains(), 200)
	assert_signal_emit_count(_player, "brains_changed", 2)
	assert_signal_emitted_with_parameters(_player, "brains_changed", [200, 100])


func test_f8_needs_a_second_f8() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	assert_true(sut._handle_key(KEY_F8))
	assert_true(sut.is_confirming())
	assert_true((sut.get_node("%ConfirmLabel") as Label).visible)
	assert_eq(_player.get_brains(), 100, "first F8 only asks")
	assert_true(sut._handle_key(KEY_F8))
	assert_false(sut.is_confirming())
	assert_false((sut.get_node("%ConfirmLabel") as Label).visible)
	assert_eq(_player.get_brains(), 0)


func test_f8_reset_emits_profile_replaced() -> void:
	var sut: OverlayScript = _make()
	watch_signals(_player)
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F8)
	sut._handle_key(KEY_F8)
	assert_signal_emit_count(_player, "profile_replaced", 1)


func test_any_other_key_cancels_the_confirm() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	sut._handle_key(KEY_F8)
	assert_false(sut._handle_key(KEY_A), "a cancelling key is not swallowed")
	assert_false(sut.is_confirming())
	assert_false((sut.get_node("%ConfirmLabel") as Label).visible)
	sut._handle_key(KEY_F8)
	assert_true(sut.is_confirming(), "a fresh F8 asks again, it does not reset")
	assert_eq(_player.get_brains(), 100)


func test_closing_cancels_the_confirm() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	sut._handle_key(KEY_F8)
	sut._handle_key(KEY_F3)
	assert_false(sut.visible)
	assert_false(sut.is_confirming())
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F8)
	assert_true(sut.is_confirming(), "reopened: first F8 asks again")
	assert_eq(_player.get_brains(), 100)


func test_confirm_times_out() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	sut._handle_key(KEY_F5)
	sut._handle_key(KEY_F8)
	var timer: Timer = sut.get_node("%ConfirmTimer") as Timer
	assert_false(timer.is_stopped(), "the cancel timer runs while confirming")
	assert_eq(timer.wait_time, OverlayScript.CONFIRM_SEC)
	sut._on_confirm_timer_timeout()
	assert_false(sut.is_confirming())
	sut._handle_key(KEY_F8)
	assert_eq(_player.get_brains(), 100, "after the timeout F8 asks again")


func test_f9_exports_only_while_open() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F9)
	assert_eq(_downloads.size(), 0)
	sut._handle_key(KEY_F3)
	assert_true(sut._handle_key(KEY_F9))
	assert_eq(_downloads.size(), 1)
	assert_true(_downloads[0].begins_with("zts-save-"))


func test_unused_keys_are_not_consumed() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_false(sut._handle_key(KEY_A))
	assert_false(sut._handle_key(KEY_F6))
	assert_false(sut._handle_key(KEY_ESCAPE))


func test_never_blocks_the_mouse() -> void:
	var sut: OverlayScript = _make()
	var controls: Array[Control] = _controls(sut, [])
	assert_gt(controls.size(), 0)
	for control: Control in controls:
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, str(control.name))
		assert_eq(control.focus_mode, Control.FOCUS_NONE, str(control.name))


func test_labels_fill_in_when_opened() -> void:
	var sut: OverlayScript = _make()
	sut._handle_key(KEY_F3)
	assert_string_contains((sut.get_node("%StatsLabel") as Label).text, "FPS")
	var save_text: String = (sut.get_node("%SaveLabel") as Label).text
	assert_string_contains(save_text, "Last save: never")
	assert_string_contains(save_text, "Storage: persistent")
	assert_eq((sut.get_node("%HelpLabel") as Label).text, "F5 +100 brains   F8 reset   F9 export")


func test_format_save_age() -> void:
	assert_eq(OverlayScript.format_save_age(-1, 5000), "Last save: never")
	assert_eq(OverlayScript.format_save_age(1000, 3300), "Last save: 2.3 s ago")


func test_uses_live_autoloads_by_default() -> void:
	var sut: OverlayScript = OverlayScene.instantiate() as OverlayScript
	add_child_autofree(sut)
	assert_eq(sut.player_data, PlayerData)
	assert_eq(sut.save_service, SaveService)
