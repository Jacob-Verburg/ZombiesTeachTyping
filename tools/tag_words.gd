extends SceneTree
## Dev-only: tags a plain word list (one word per line) by keyboard rows and length (Story 6.1, FR66).
## The tagging and pool rules live in WordTagger; the tier rows and bands live in data/tier_config.tres.
##
## Default (starter) mode writes data/content/words.json and checks the 3-5 letter starter band:
##   "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/tag_words.gd [-- --in=res://... --out=res://...]
## Pools mode (Story 7.4, FR62/FR66) reads tools/word_lists/master_words.txt and writes each tier's pool to
## data/content/word_pools.json and the pool validation report to data/content/word_pool_report.json:
##   "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/tag_words.gd -- --pools [--in= --pools-out= --report-out=]
## Then --import. Exit 0 when all is well; 1 when a line was rejected, the starter band or a tier pool is
## short, an argument is bad, or a file can't be read or written. The output files are written even on
## rejections or short pools, so the report shows the shortfall.

const DEFAULT_IN: String = "res://tools/word_lists/starter_words.txt"
const DEFAULT_OUT: String = "res://data/content/words.json"
const DEFAULT_POOLS_IN: String = "res://tools/word_lists/master_words.txt"
const DEFAULT_POOLS_OUT: String = "res://data/content/word_pools.json"
const DEFAULT_REPORT_OUT: String = "res://data/content/word_pool_report.json"
const TIER_CONFIG_PATH: String = "res://data/tier_config.tres"

var _ok: bool = true


func _init() -> void:
	var pools: bool = false
	var in_path: String = ""
	var out_path: String = DEFAULT_OUT
	var starter_only_arg: String = ""
	var pools_only_arg: String = ""
	var pools_out: String = DEFAULT_POOLS_OUT
	var report_out: String = DEFAULT_REPORT_OUT
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--pools":
			pools = true
		elif arg.begins_with("--in="):
			in_path = _res_path_arg(arg, "--in=")
		elif arg.begins_with("--out="):
			out_path = _res_path_arg(arg, "--out=")
			starter_only_arg = arg
		elif arg.begins_with("--pools-out="):
			pools_out = _res_path_arg(arg, "--pools-out=")
			pools_only_arg = arg
		elif arg.begins_with("--report-out="):
			report_out = _res_path_arg(arg, "--report-out=")
			pools_only_arg = arg
		else:
			_fail("unknown argument '%s'" % arg)
	if pools and starter_only_arg != "":
		_fail("%s has no effect with --pools (use --pools-out= and --report-out=)" % starter_only_arg)
	if not pools and pools_only_arg != "":
		_fail("%s only works with --pools" % pools_only_arg)
	if in_path == "":
		in_path = DEFAULT_POOLS_IN if pools else DEFAULT_IN
	if _ok:
		if pools:
			_run_pools(in_path, pools_out, report_out)
		else:
			_run(in_path, out_path)
	quit(0 if _ok else 1)


## The value after `prefix`; fails (and returns "") unless it is a non-empty res:// path.
func _res_path_arg(arg: String, prefix: String) -> String:
	var value: String = arg.trim_prefix(prefix)
	if value == "" or not value.begins_with("res://"):
		_fail("%s needs a res:// path (got '%s')" % [prefix.trim_suffix("="), value])
		return ""
	return value


func _run(in_path: String, out_path: String) -> void:
	var tagged: Variant = _read_and_tag(in_path)
	if tagged == null:
		return
	var words: Array = tagged

	var band: int = WordTagger.count_in_band(words, WordTagger.STARTER_BAND_MIN_LEN, WordTagger.STARTER_BAND_MAX_LEN)
	print("%d-%d letter band: %d (minimum %d)" % [WordTagger.STARTER_BAND_MIN_LEN,
			WordTagger.STARTER_BAND_MAX_LEN, band, WordTagger.STARTER_BAND_MIN_COUNT])
	if band < WordTagger.STARTER_BAND_MIN_COUNT:
		_fail("only %d words in the %d-%d letter band (need %d)" % [band, WordTagger.STARTER_BAND_MIN_LEN,
				WordTagger.STARTER_BAND_MAX_LEN, WordTagger.STARTER_BAND_MIN_COUNT])

	_write_json(out_path, { "schema": 1, "source": in_path, "words": words })


## Pools mode: no starter band check (a 6.1 starter-list rule); each tier pool must meet its minimum.
func _run_pools(in_path: String, pools_out: String, report_out: String) -> void:
	var config: TierConfig = load(TIER_CONFIG_PATH) as TierConfig
	if config == null:
		_fail("can't load %s as a TierConfig" % TIER_CONFIG_PATH)
		return
	var problem: String = config.validate()
	if problem != "":
		_fail("%s: %s" % [TIER_CONFIG_PATH, problem])
		return
	var tagged: Variant = _read_and_tag(in_path)
	if tagged == null:
		return
	var words: Array = tagged

	var pools: Array[Dictionary] = WordTagger.build_tier_pools(words, config)
	var report: Array[Dictionary] = WordTagger.pool_report(pools, WordTagger.TIER_POOL_MINIMUMS)
	for i: int in pools.size():
		var pool: Dictionary = pools[i]
		var line: Dictionary = report[i]
		print("tier %d (%s, %d-%d): %d words (minimum %d) %s" % [pool["tier"], "+".join(pool["rows"]),
				pool["min_length"], pool["max_length"], line["count"], line["minimum"],
				"ok" if line["ok"] else "SHORT"])
		if not line["ok"]:
			_fail("tier %d has %d words (need %d)" % [line["tier"], line["count"], line["minimum"]])

	_write_json(pools_out, { "schema": 1, "source": in_path, "tiers": pools })
	_write_json(report_out, { "schema": 1, "source": in_path, "tiers": report })


## The tagged words of `in_path` (failing on each rejected line) after printing the summary; null when
## the file can't be read, so nothing is written.
func _read_and_tag(in_path: String) -> Variant:
	if not FileAccess.file_exists(in_path):
		_fail("can't find %s" % in_path)
		return null
	var text: String = FileAccess.get_file_as_string(in_path)
	if text == "":
		_fail("%s is empty" % in_path)
		return null
	var result: Dictionary = WordTagger.tag_lines(text.split("\n"))
	var words: Array = result["words"]
	var rejected: Array = result["rejected"]
	for entry: Dictionary in rejected:
		_fail("line %d \"%s\": %s" % [entry["line"], entry["text"], entry["reason"]])
	_print_summary(words, rejected.size())
	return words


## Writes `doc` as tab-indented JSON plus a final newline. No timestamp: re-running on the same
## inputs must not create a diff.
func _write_json(out_path: String, doc: Dictionary) -> void:
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	if dir_err != OK:
		_fail("can't create %s (%s)" % [out_path.get_base_dir(), error_string(dir_err)])
		return
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		_fail("can't write %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		return
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
