extends SceneTree
## Dev-only: tags a plain word list (one word per line) by keyboard rows and length and writes
## data/content/words.json (Story 6.1, FR66). The tagging rules live in WordTagger.
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/tag_words.gd
## Other files (Story 7.4's master list): ... -s tools/tag_words.gd -- --in=res://... --out=res://...
## then --import. Exits non-zero when a line was rejected, the starter band check failed, or the
## list can't be read or the JSON can't be written. Accepted words are written even on rejections.

const DEFAULT_IN: String = "res://tools/word_lists/starter_words.txt"
const DEFAULT_OUT: String = "res://data/content/words.json"
## FR59 / Story 6.1: before Epic 7 the game uses 3-5 letter words; the starter list needs 150 of them.
const STARTER_BAND_MIN_LEN: int = 3
const STARTER_BAND_MAX_LEN: int = 5
const STARTER_BAND_MIN_COUNT: int = 150

var _ok: bool = true


func _init() -> void:
	var in_path: String = DEFAULT_IN
	var out_path: String = DEFAULT_OUT
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--in="):
			in_path = arg.trim_prefix("--in=")
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		else:
			_fail("unknown argument '%s'" % arg)
	if _ok:
		_run(in_path, out_path)
	quit(0 if _ok else 1)


func _run(in_path: String, out_path: String) -> void:
	var text: String = FileAccess.get_file_as_string(in_path)
	if text == "":
		_fail("can't read %s (%s) or it is empty" % [in_path, error_string(FileAccess.get_open_error())])
		return
	var result: Dictionary = WordTagger.tag_lines(text.split("\n"))
	var words: Array = result["words"]
	var rejected: Array = result["rejected"]
	for entry: Dictionary in rejected:
		_fail("line %d \"%s\": %s" % [entry["line"], entry["text"], entry["reason"]])
	_print_summary(words, rejected.size())

	var band: int = WordTagger.count_in_band(words, STARTER_BAND_MIN_LEN, STARTER_BAND_MAX_LEN)
	print("%d-%d letter band: %d (minimum %d)" % [STARTER_BAND_MIN_LEN, STARTER_BAND_MAX_LEN, band,
			STARTER_BAND_MIN_COUNT])
	if band < STARTER_BAND_MIN_COUNT:
		_fail("only %d words in the %d-%d letter band (need %d)" % [band, STARTER_BAND_MIN_LEN,
				STARTER_BAND_MAX_LEN, STARTER_BAND_MIN_COUNT])

	var dir_err: Error = DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if dir_err != OK:
		_fail("can't create %s (%s)" % [out_path.get_base_dir(), error_string(dir_err)])
		return
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("can't write %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		return
	# No timestamp: re-running on the same list must not create a diff.
	var doc: Dictionary = { "schema": 1, "source": in_path, "words": words }
	file.store_string(JSON.stringify(doc, "\t") + "\n")
	var write_err: Error = file.get_error()
	file.close()
	print("%s -> %s" % [out_path, error_string(write_err)])
	if write_err != OK:
		_fail("write failed for %s" % out_path)


func _print_summary(words: Array, rejected_count: int) -> void:
	print("accepted %d, rejected %d" % [words.size(), rejected_count])
	var per_length: Dictionary = {}
	var per_rows: Dictionary = {}
	for entry: Dictionary in words:
		var length: int = entry["length"]
		per_length[length] = int(per_length.get(length, 0)) + 1
		var key: String = "+".join(entry["rows"])
		per_rows[key] = int(per_rows.get(key, 0)) + 1
	for length: int in range(WordTagger.MIN_LENGTH, WordTagger.MAX_LENGTH + 1):
		print("  length %d: %d" % [length, int(per_length.get(length, 0))])
	var row_keys: Array = per_rows.keys()
	row_keys.sort()
	for key: String in row_keys:
		print("  %s: %d" % [key, per_rows[key]])


func _fail(message: String) -> void:
	printerr("tag_words: " + message)
	_ok = false
