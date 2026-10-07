extends SceneTree
## Dev-only (Story 5.2, AC 2): renders the MVP screens at the 640×360 logical resolution and writes a colour
## PNG and a grayscale PNG of each to _bmad-output/implementation-artifacts/screenshots/5-2/, for the
## grayscale review (NFR8). Grayscale = Rec. 709 luma (0.2126 r + 0.7152 g + 0.0722 b) on the sRGB values,
## the formula tests/unit/test_art_ui.gd::_luma uses.
## Run in a REAL window (the headless Dummy renderer draws nothing):
##   "/c/Program Files/Godot/Godot.exe" --path . -s tools/capture_screens.gd
## Convert any other PNG (e.g. a browser-pane shot) with the same formula:
##   "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/capture_screens.gd -- --convert <png>
## The shots live in tools/capture_screens_runner.gd, loaded at runtime: a `-s` script is compiled before the
## autoloads exist, so it can't preload the screens itself.
## Each screen is instanced like tests/integration/test_screen_flow.gd: process disabled, recorder seams, a
## temp-dir PlayerData. The real save is never written (hash user://save.json before and after). Fixed values
## and seeds, so a rerun draws the same pictures. tools/ is export-excluded.

const RUNNER_PATH: String = "res://tools/capture_screens_runner.gd"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var convert_at: int = args.find("--convert")
	if convert_at >= 0 and convert_at + 1 < args.size():
		_convert_only(args[convert_at + 1])
		quit()
		return
	_start.call_deferred()


func _start() -> void:
	var script: GDScript = load(RUNNER_PATH) as GDScript
	if script == null or not script.can_instantiate():
		printerr("capture_screens: can't load %s" % RUNNER_PATH)
		quit(1)
		return
	var runner: Node = script.new() as Node
	root.add_child(runner)
	runner.connect(&"done", func(code: int) -> void: quit(code))
	runner.call(&"run")


func _convert_only(path: String) -> void:
	var image: Image = Image.load_from_file(path)
	if image == null:
		printerr("capture_screens: can't read %s" % path)
		return
	var out: String = path.get_basename() + "-gray.png"
	gray(image).save_png(out)
	print("capture_screens: wrote ", out)


## Rec. 709 luma on the sRGB values, alpha kept.
static func gray(source: Image) -> Image:
	var image: Image = source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			image.set_pixel(x, y, Color(l, l, l, c.a))
	return image
