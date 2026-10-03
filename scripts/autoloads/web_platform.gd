extends Node
## Browser integration: focus/visibility signals, key swallowing, fullscreen, downloads.
## The only script allowed to use JavaScriptBridge or OS.has_feature("web").
## Everything browser-specific is a no-op on desktop. is_fullscreen()/toggle_fullscreen() are plain
## DisplayServer calls and offer_download() opens user:// on desktop.
## capture_keys is false at start; only a screen that needs Space, ', /, Backspace and Tab
## (the keyboard test screen, later RunFrame) sets it in _ready() and resets it in _exit_tree().
## Fullscreen on web only works from a user input callback (browser gesture rule): the caller
## calls toggle_fullscreen() from its click or key handler, never from a timer.

signal focus_lost
signal visibility_hidden

## Shipped on (Story 1.5 review): the canvas looked fine in Chrome, but Firefox quick-find on ' and /
## was never measured, so the listener is a hedge. False = no JS listener is installed.
const INSTALL_KEY_LISTENER: bool = true
## Keys the listener swallows while capture_keys is true. Modifier combos are never touched.
const CAPTURED_KEYS: PackedStringArray = [" ", "'", "/", "Backspace", "Tab"]
const KEY_LISTENER_JS: String = """
(function () {
	var captured = %s;
	window.__zts = { capture: false };
	window.addEventListener('keydown', function (evt) {
		if (!window.__zts.capture) { return; }
		if (evt.ctrlKey || evt.metaKey || evt.altKey) { return; }
		if (captured.indexOf(evt.key) !== -1) { evt.preventDefault(); }
	}, true);
})();
"""

var capture_keys: bool = false:
	set(value):
		capture_keys = value
		_push_capture_state()

var _window: JavaScriptObject
var _document: JavaScriptObject
var _zts: JavaScriptObject
var _blur_callback: JavaScriptObject
var _visibility_callback: JavaScriptObject


func _ready() -> void:
	if not is_web():
		return
	_install_browser_hooks()


## The only OS.has_feature("web") call in the project; also the test seam.
func is_web() -> bool:
	return OS.has_feature("web")


func is_storage_persistent() -> bool:
	return OS.is_userfs_persistent()


## True only while keys are actually being swallowed (capture_keys on and the JS listener installed).
func is_key_capture_active() -> bool:
	return capture_keys and _zts != null


## Flips between fullscreen and windowed. The current mode is read from the engine, not cached.
func toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	DisplayServer.window_set_mode(mode)


## Re-reads the engine every call, so the browser's own Esc exit shows up the next time it is asked.
func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Web: the browser downloads the file. Desktop: the user:// folder opens. Never logs the contents.
func offer_download(bytes: PackedByteArray, file_name: String) -> void:
	Log.info(&"web", "download offered: %s (%d bytes)" % [file_name, bytes.size()])
	if not is_web():
		OS.shell_open(ProjectSettings.globalize_path("user://"))
		return
	var mime: String = "application/json" if file_name.ends_with(".json") else "application/octet-stream"
	JavaScriptBridge.download_buffer(bytes, file_name, mime)


func _install_browser_hooks() -> void:
	Log.info(&"web", "storage persistent: %s" % is_storage_persistent())
	_window = JavaScriptBridge.get_interface("window")
	_document = JavaScriptBridge.get_interface("document")
	if _window == null or _document == null:
		Log.warn(&"web", "browser window/document unavailable; focus and key hooks skipped")
		return
	# Callbacks must live in members: a callback held only in a local is freed and stops firing.
	_blur_callback = JavaScriptBridge.create_callback(_on_blur)
	_visibility_callback = JavaScriptBridge.create_callback(_on_visibility_change)
	_window.addEventListener("blur", _blur_callback)
	_document.addEventListener("visibilitychange", _visibility_callback)
	if INSTALL_KEY_LISTENER:
		_install_key_listener()


func _install_key_listener() -> void:
	var captured: PackedStringArray = []
	for key: String in CAPTURED_KEYS:
		captured.append(JSON.stringify(key))
	JavaScriptBridge.eval(KEY_LISTENER_JS % ("[" + ", ".join(captured) + "]"))
	_zts = JavaScriptBridge.get_interface("__zts")
	if _zts == null:
		Log.warn(&"web", "key listener state unavailable; capture keys inactive")
	_push_capture_state()


func _push_capture_state() -> void:
	if _zts != null:
		_zts.capture = capture_keys


func _on_blur(_args: Array) -> void:
	Log.info(&"web", "focus lost")
	focus_lost.emit()


func _on_visibility_change(_args: Array) -> void:
	var hidden: bool = false
	if _document != null:
		hidden = bool(_document.hidden)
	_emit_if_hidden(hidden)


## Becoming visible again emits nothing.
func _emit_if_hidden(hidden: bool) -> void:
	if not hidden:
		return
	Log.info(&"web", "visibility hidden")
	visibility_hidden.emit()
