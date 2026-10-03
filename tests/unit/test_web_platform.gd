extends GutTest
## WebPlatform decisions that are pure GDScript. Browser behaviour (JavaScript, real focus,
## fullscreen, downloads) is proven in a real browser, not here.
## Always a fresh instance; the live autoload is only read, never driven.

const WebPlatformScript := preload("res://scripts/autoloads/web_platform.gd")

var _wp: WebPlatformScript


func before_each() -> void:
	_wp = WebPlatformScript.new()
	add_child_autofree(_wp)


func test_capture_keys_defaults_to_false() -> void:
	assert_false(_wp.capture_keys)
	# Guard for the keyboard test screen lifecycle: nothing in the suite may leave it on.
	assert_false(WebPlatform.capture_keys, "live autoload left capturing keys")


func test_is_web_false_on_desktop() -> void:
	assert_false(_wp.is_web())


func test_desktop_is_noop() -> void:
	assert_null(_wp._blur_callback)
	assert_null(_wp._visibility_callback)
	assert_null(_wp._window)
	assert_null(_wp._document)
	assert_null(_wp._zts)
	_wp.capture_keys = true
	assert_true(_wp.capture_keys)
	assert_false(_wp.is_key_capture_active(), "no listener on desktop, so nothing is swallowed")
	_wp.capture_keys = false
	assert_false(_wp.capture_keys)


func test_blur_emits_focus_lost() -> void:
	watch_signals(_wp)
	_wp._on_blur([])
	assert_signal_emit_count(_wp, "focus_lost", 1)


func test_visibility_hidden_emits_only_when_hidden() -> void:
	watch_signals(_wp)
	_wp._emit_if_hidden(false)
	assert_signal_not_emitted(_wp, "visibility_hidden")
	_wp._emit_if_hidden(true)
	assert_signal_emit_count(_wp, "visibility_hidden", 1)


func test_is_storage_persistent_matches_engine() -> void:
	assert_eq(_wp.is_storage_persistent(), OS.is_userfs_persistent())


func test_is_fullscreen_rereads_engine() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	var expected: bool = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	assert_eq(_wp.is_fullscreen(), expected)

# offer_download() and toggle_fullscreen() are not called here: they would open a file explorer
# and flip the runner's window. They are verified on the desktop run and in the browser.
