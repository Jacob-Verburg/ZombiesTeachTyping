class_name Log
## Static logger: every line is "[LEVEL][tag] message".
## The tag names the system (&"save", &"typing", &"audio", &"router", &"web", &"economy", &"level").
## Never log inside _process, and never log personal data.
## Per-keystroke logs are DEBUG only, and only while verbose_typing is on.

static var verbose_typing: bool = false
## DEBUG lines print only when true. Defaults to the build type; tests flip it to simulate a release build.
static var debug_enabled: bool = OS.is_debug_build()


static func error(tag: StringName, msg: String) -> void:
	push_error(format_line("ERROR", tag, msg))


static func warn(tag: StringName, msg: String) -> void:
	push_warning(format_line("WARN", tag, msg))


static func info(tag: StringName, msg: String) -> void:
	print(format_line("INFO", tag, msg))


static func debug(tag: StringName, msg: String) -> void:
	if is_level_enabled("DEBUG"):
		print(format_line("DEBUG", tag, msg))


static func format_line(level: String, tag: StringName, msg: String) -> String:
	return "[%s][%s] %s" % [level, tag, msg]


static func is_level_enabled(level: String) -> bool:
	if level == "DEBUG":
		return debug_enabled
	return true
