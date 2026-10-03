extends GutTest
## Router decisions (registry, payload, load fallback, overlay) on a fresh instance.
## Never call go() on the live Router autoload here: the scene swap would replace GUT's own runner.

const RouterScript := preload("res://scripts/autoloads/router.gd")
const MISSING_PATH: String = "res://does_not_exist.tscn"

var _router: RouterScript


func before_each() -> void:
	_router = RouterScript.new()
	add_child_autofree(_router)


func test_every_screen_has_a_loadable_scene() -> void:
	for screen: RouterScript.Screen in RouterScript.Screen.values():
		assert_true(RouterScript.SCREEN_PATHS.has(screen), "no path for %s" % RouterScript.Screen.keys()[screen])
		var path: String = RouterScript.SCREEN_PATHS.get(screen, "")
		assert_true(ResourceLoader.exists(path), "missing scene %s" % path)
		assert_true(ResourceLoader.load(path) is PackedScene, "not a PackedScene: %s" % path)


func test_screen_enum_order_is_stable() -> void:
	assert_eq(RouterScript.Screen.keys(), ["TITLE", "MAIN_MENU", "RUN", "REPORT_CARD", "WELCOME_GIFT", "CRYPT_CLOSET", "KEYBOARD_TEST"])


func test_take_payload_returns_once() -> void:
	_router._store_payload({"level_id": &"zombie_run"})
	assert_eq(_router.take_payload(), {"level_id": &"zombie_run"})
	assert_eq(_router.take_payload(), {})


func test_stored_payload_is_a_copy() -> void:
	var payload: Dictionary = {"level_id": &"zombie_run"}
	_router._store_payload(payload)
	payload["level_id"] = &"changed"
	assert_eq(_router.take_payload(), {"level_id": &"zombie_run"})


func test_take_payload_is_empty_by_default() -> void:
	assert_eq(_router.take_payload(), {})


func test_load_screen_returns_scene_for_registered_path() -> void:
	assert_not_null(_router._load_screen(RouterScript.Screen.MAIN_MENU))


func test_load_screen_returns_null_and_logs_for_missing_path() -> void:
	_router._paths[RouterScript.Screen.RUN] = MISSING_PATH
	assert_null(_router._load_screen(RouterScript.Screen.RUN))
	assert_push_error("[ERROR][router] screen RUN failed to load")


func test_resolve_falls_back_to_main_menu_and_clears_payload() -> void:
	_router._paths[RouterScript.Screen.RUN] = MISSING_PATH
	_router._store_payload({"level_id": &"zombie_run"})
	var resolved: Dictionary = _router._resolve(RouterScript.Screen.RUN)
	assert_eq(resolved.get("screen"), RouterScript.Screen.MAIN_MENU)
	assert_true(resolved.get("scene") is PackedScene)
	assert_eq(_router.take_payload(), {})
	assert_push_error_count(1)


func test_resolve_keeps_payload_on_success() -> void:
	_router._store_payload({"level_id": &"zombie_run"})
	var resolved: Dictionary = _router._resolve(RouterScript.Screen.RUN)
	assert_eq(resolved.get("screen"), RouterScript.Screen.RUN)
	assert_eq(_router.take_payload(), {"level_id": &"zombie_run"})


func test_main_menu_failure_does_not_loop() -> void:
	_router._paths[RouterScript.Screen.RUN] = MISSING_PATH
	_router._paths[RouterScript.Screen.MAIN_MENU] = MISSING_PATH
	assert_eq(_router._resolve(RouterScript.Screen.RUN), {})
	assert_push_error_count(2)


func test_fade_overlay_is_idle_after_ready() -> void:
	var layer: CanvasLayer = _router._fade_layer
	assert_not_null(layer)
	assert_gte(layer.layer, 100)
	var rect: ColorRect = _router._fade_rect
	assert_eq(rect.modulate.a, 0.0)
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(rect.color, Color("#2B1D3F"))


func test_router_runs_while_paused() -> void:
	assert_eq(_router.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_starts_on_title_and_idle() -> void:
	assert_eq(_router.current_screen, RouterScript.Screen.TITLE)
	assert_false(_router.is_transitioning())
