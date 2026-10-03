extends GutTest

var _saved_debug_enabled: bool


func before_each() -> void:
	_saved_debug_enabled = Log.debug_enabled


func after_each() -> void:
	Log.debug_enabled = _saved_debug_enabled


func test_format_line() -> void:
	assert_eq(Log.format_line("INFO", &"save", "hello"), "[INFO][save] hello")
	assert_eq(Log.format_line("ERROR", &"router", "oops"), "[ERROR][router] oops")
	assert_eq(Log.format_line("WARN", &"web", "hmm"), "[WARN][web] hmm")
	assert_eq(Log.format_line("DEBUG", &"typing", "x"), "[DEBUG][typing] x")


func test_debug_disabled_in_release() -> void:
	Log.debug_enabled = false
	assert_false(Log.is_level_enabled("DEBUG"))
	assert_true(Log.is_level_enabled("ERROR"))
	assert_true(Log.is_level_enabled("WARN"))
	assert_true(Log.is_level_enabled("INFO"))
	Log.debug(&"test", "must not print")


func test_debug_enabled_in_debug_build() -> void:
	Log.debug_enabled = true
	assert_true(Log.is_level_enabled("DEBUG"))


func test_debug_enabled_defaults_to_build_type() -> void:
	assert_eq(_saved_debug_enabled, OS.is_debug_build())


func test_error_pushes_formatted_error() -> void:
	Log.error(&"test", "boom")
	assert_push_error("[ERROR][test] boom")


func test_warn_pushes_formatted_warning() -> void:
	Log.warn(&"test", "careful")
	assert_push_warning("[WARN][test] careful")


func test_info_does_not_push_errors() -> void:
	Log.info(&"test", "milestone")
	assert_push_error_count(0)
