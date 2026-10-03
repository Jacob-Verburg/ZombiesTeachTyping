extends Control
## Keyboard capture test (Story 1.5): proves Space, ', /, Backspace and Tab reach the game and not
## the browser, and exercises WebPlatform's fullscreen and download.
## Temporary: the Fullscreen and Download buttons stay until Story 4.2 (real Fullscreen toggle) and
## Story 1.8 (real save download) replace them. Not the typing pipeline (that is Story 2.1).
## Temporary brain counter (Story 1.7, NFR4 reload measurement): "+1 brain" calls PlayerData.add_brains(1)
## and the label updates only through PlayerData.brains_changed (and re-reads on profile_replaced, the
## debug overlay's F8 reset, Story 1.8); "Last save" reads
## SaveService.last_write_ticks_msec. Both go away with this screen.

const ECHO_MAX_CHARS: int = 20
const REFRESH_SEC: float = 0.5
const DOWNLOAD_NAME: String = "zts-test.txt"
const DOWNLOAD_TEXT: String = "zombies-teach-typing download test\n"
## The test counter's step (NFR4 measurement), not a balance number.
const BRAIN_STEP: int = 1

var _echo: String = ""


## Pure echo rule: printable characters append, Backspace removes the last one, everything else
## (echo repeats, releases, modifiers and Ctrl/Alt/Meta combos, Tab, Esc) changes nothing.
static func apply_key(text: String, event: InputEventKey) -> String:
	if not event.pressed or event.echo:
		return text
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return text
	if event.keycode == KEY_BACKSPACE:
		return text.left(maxi(text.length() - 1, 0))
	if event.unicode < 32:
		return text
	return (text + char(event.unicode)).right(ECHO_MAX_CHARS)


func _ready() -> void:
	# Nothing travels with this screen, but a stale payload must not linger.
	Router.take_payload()
	WebPlatform.capture_keys = true
	%FullscreenButton.pressed.connect(_on_fullscreen_button_pressed)
	%DownloadButton.pressed.connect(_on_download_button_pressed)
	%BackButton.pressed.connect(_on_back_button_pressed)
	%BrainButton.pressed.connect(_on_brain_button_pressed)
	PlayerData.brains_changed.connect(_on_player_data_brains_changed)
	PlayerData.profile_replaced.connect(_on_player_data_profile_replaced)
	_show_brains(PlayerData.get_brains())
	%RefreshTimer.wait_time = REFRESH_SEC
	%RefreshTimer.timeout.connect(_refresh_status)
	_refresh_status()


func _exit_tree() -> void:
	WebPlatform.capture_keys = false
	if PlayerData.brains_changed.is_connected(_on_player_data_brains_changed):
		PlayerData.brains_changed.disconnect(_on_player_data_brains_changed)
	if PlayerData.profile_replaced.is_connected(_on_player_data_profile_replaced):
		PlayerData.profile_replaced.disconnect(_on_player_data_profile_replaced)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Router.go(Router.Screen.MAIN_MENU)
		return
	if event is InputEventMouseButton:
		_refresh_status()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	_echo = apply_key(_echo, key)
	%EchoLabel.text = _echo
	%VisibleLabel.text = _echo.replace(" ", "[_]")
	%LastKeyLabel.text = _describe(key)
	_refresh_status()


func _describe(key: InputEventKey) -> String:
	var key_name: String = "[tab]" if key.keycode == KEY_TAB else OS.get_keycode_string(key.keycode)
	var kind: String = "printable" if key.unicode >= 32 else "not printable"
	return "Last key: %s (keycode %d, unicode %d, %s)" % [key_name, key.keycode, key.unicode, kind]


func _refresh_status() -> void:
	%CaptureLabel.text = "capture_keys: %s (swallowing: %s)" % [
		WebPlatform.capture_keys, WebPlatform.is_key_capture_active()
	]
	%FullscreenLabel.text = "Fullscreen: %s" % ("on" if WebPlatform.is_fullscreen() else "off")
	var last_write: int = SaveService.last_write_ticks_msec
	if last_write < 0:
		%SaveStatusLabel.text = "Last save: never"
	else:
		%SaveStatusLabel.text = "Last save: %.1f s ago" % ((Time.get_ticks_msec() - last_write) / 1000.0)


func _show_brains(total: int) -> void:
	%BrainsLabel.text = "Brains: %d" % total


func _on_fullscreen_button_pressed() -> void:
	WebPlatform.toggle_fullscreen()
	_refresh_status()


func _on_download_button_pressed() -> void:
	WebPlatform.offer_download(DOWNLOAD_TEXT.to_utf8_buffer(), DOWNLOAD_NAME)


func _on_back_button_pressed() -> void:
	Router.go(Router.Screen.MAIN_MENU)


func _on_brain_button_pressed() -> void:
	PlayerData.add_brains(BRAIN_STEP)


func _on_player_data_brains_changed(total: int, _delta: int) -> void:
	_show_brains(total)


func _on_player_data_profile_replaced() -> void:
	_show_brains(PlayerData.get_brains())
