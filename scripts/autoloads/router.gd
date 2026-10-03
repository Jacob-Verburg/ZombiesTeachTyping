extends Node
## Screen flow: one fade-covered scene swap at a time.
## go() stores a payload; the incoming screen reads it once with take_payload() in _ready().
## A screen that fails to load is logged and replaced by MAIN_MENU (never loops).
## KEYBOARD_TEST is a temporary dev screen (Story 1.5); Story 1.8 or 5.0 may remove it.

signal screen_changed(screen: Screen)

enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET, KEYBOARD_TEST }

## Paths, not preloads: a failed preload is a parse error, so the MAIN_MENU fallback could never run.
const SCREEN_PATHS: Dictionary[Screen, String] = {
	Screen.TITLE: "res://scenes/screens/title.tscn",
	Screen.MAIN_MENU: "res://scenes/screens/main_menu.tscn",
	Screen.RUN: "res://scenes/run/run_frame.tscn",
	Screen.REPORT_CARD: "res://scenes/screens/report_card.tscn",
	Screen.WELCOME_GIFT: "res://scenes/screens/welcome_gift.tscn",
	Screen.CRYPT_CLOSET: "res://scenes/screens/crypt_closet.tscn",
	Screen.KEYBOARD_TEST: "res://scenes/screens/keyboard_test.tscn",
}
const FADE_OUT_SEC: float = 0.15
const FADE_IN_SEC: float = 0.15
const FADE_COLOR: Color = Color("#2B1D3F")  # night
const FADE_LAYER: int = 100

## The title is the main scene and is never reached through go() at boot.
var current_screen: Screen = Screen.TITLE

var _paths: Dictionary[Screen, String] = SCREEN_PATHS.duplicate()
var _payload: Dictionary = {}
var _transitioning: bool = false
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "FadeLayer"
	_fade_layer.layer = FADE_LAYER
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = FADE_COLOR
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)


func go(screen: Screen, payload: Dictionary = {}) -> void:
	if not _paths.has(screen):
		Log.error(&"router", "go() called with unknown screen %d" % screen)
		return
	if _transitioning:
		Log.debug(&"router", "ignored go(%s) during a transition" % Screen.keys()[screen])
		return
	_transitioning = true
	_store_payload(payload)
	# Paused screens get no input, so the outgoing screen ignores keys and clicks during the fade.
	get_tree().paused = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, FADE_OUT_SEC)
	var swapped: bool = await _swap_to(screen)
	if not swapped:
		# Nothing loaded: fade back in on the current scene and drop the undelivered payload.
		_payload = {}
	await _fade_to(0.0, FADE_IN_SEC)
	# A new screen never starts paused, even when go() came from a paused run (Pause -> Quit to Menu).
	get_tree().paused = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	if swapped:
		screen_changed.emit(current_screen)


func take_payload() -> Dictionary:
	var payload: Dictionary = _payload
	_payload = {}
	return payload


func is_transitioning() -> bool:
	return _transitioning


func _store_payload(payload: Dictionary) -> void:
	# A copy, so the caller can reuse its dictionary during the fade.
	_payload = payload.duplicate()


## Returns null (and logs) when the screen's scene is missing or isn't a PackedScene.
func _load_screen(screen: Screen) -> PackedScene:
	var path: String = _paths.get(screen, "")
	# exists() first: loading a missing path raises an engine error on top of ours.
	var packed: PackedScene = null
	if path != "" and ResourceLoader.exists(path):
		packed = ResourceLoader.load(path) as PackedScene
	if packed == null:
		Log.error(&"router", "screen %s failed to load" % Screen.keys()[screen])
	return packed


## Picks the scene to show: the requested screen, else MAIN_MENU (payload cleared), else {}.
func _resolve(screen: Screen) -> Dictionary:
	var packed: PackedScene = _load_screen(screen)
	if packed != null:
		return {"screen": screen, "scene": packed}
	if screen == Screen.MAIN_MENU:
		return {}
	_payload = {}
	packed = _load_screen(Screen.MAIN_MENU)
	if packed == null:
		return {}
	return {"screen": Screen.MAIN_MENU, "scene": packed}


## Swaps the scene; on failure falls back to MAIN_MENU once. Returns false if nothing changed.
func _swap_to(screen: Screen) -> bool:
	var resolved: Dictionary = _resolve(screen)
	if resolved.is_empty():
		return false
	var target: Screen = resolved["screen"]
	var packed: PackedScene = resolved["scene"]
	var err: Error = get_tree().change_scene_to_packed(packed)
	if err != OK:
		Log.error(&"router", "screen %s failed to start (error %d)" % [Screen.keys()[target], err])
		if target == Screen.MAIN_MENU:
			return false
		_payload = {}
		return await _swap_to(Screen.MAIN_MENU)
	# The swap is deferred to the end of the frame; scene_changed fires after the new _ready().
	await get_tree().scene_changed
	current_screen = target
	Log.info(&"router", "-> %s" % Screen.keys()[target])
	return true


func _fade_to(alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "modulate:a", alpha, duration)
	await tween.finished
