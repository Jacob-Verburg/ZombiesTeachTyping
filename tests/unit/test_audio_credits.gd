extends GutTest
## assets/audio/CREDITS.md (Story 5.1, NFR14): every audio file under res://assets/audio/ (no .import) has
## exactly one row, every row names a file that exists, and every license is CC0-style or self-recorded.

const AUDIO_DIR: String = "res://assets/audio/"
const CREDITS_PATH: String = "res://assets/audio/CREDITS.md"
const AUDIO_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3", "flac", "opus"]
## The licenses CREDITS.md may name (keep this list and the file in step).
const ALLOWED_LICENSES: Array[String] = ["CC0", "CC0 1.0", "Self-recorded (CC0)"]


## Every audio file under AUDIO_DIR, as a path relative to it ("sfx/sfx_ui_click.wav").
func _audio_files(dir: String = "") -> Array[String]:
	var out: Array[String] = []
	var full: String = AUDIO_DIR.path_join(dir)
	for file_name: String in DirAccess.get_files_at(full):
		if file_name.get_extension() in AUDIO_EXTENSIONS:
			out.append(dir.path_join(file_name) if dir != "" else file_name)
	for sub: String in DirAccess.get_directories_at(full):
		out.append_array(_audio_files(dir.path_join(sub) if dir != "" else sub))
	return out


## The table rows of CREDITS.md as [file, source, author, license], header and divider skipped.
func _rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var text: String = FileAccess.get_file_as_string(CREDITS_PATH)
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("|") or trimmed.begins_with("|--") or trimmed.begins_with("| File"):
			continue
		var cells: PackedStringArray = PackedStringArray()
		for cell: String in trimmed.trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(cell.strip_edges())
		rows.append(cells)
	return rows


func _file_of(row: PackedStringArray) -> String:
	return row[0].trim_prefix("`").trim_suffix("`")


func test_credits_file_exists() -> void:
	assert_true(FileAccess.file_exists(CREDITS_PATH))


func test_every_row_has_four_columns() -> void:
	var rows: Array[PackedStringArray] = _rows()
	assert_gt(rows.size(), 0)
	for row: PackedStringArray in rows:
		assert_eq(row.size(), 4, " | ".join(row))


func test_every_audio_file_has_exactly_one_row() -> void:
	var listed: Array[String] = []
	for row: PackedStringArray in _rows():
		listed.append(_file_of(row))
	var files: Array[String] = _audio_files()
	assert_gt(files.size(), 0, "audio files found")
	for file: String in files:
		assert_eq(listed.count(file), 1, file)


func test_every_row_names_an_existing_file() -> void:
	for row: PackedStringArray in _rows():
		var file: String = _file_of(row)
		assert_true(FileAccess.file_exists(AUDIO_DIR.path_join(file)), "no placeholder rows: %s" % file)


func test_every_license_is_allowed() -> void:
	for row: PackedStringArray in _rows():
		if row.size() < 4:
			continue
		assert_true(row[3] in ALLOWED_LICENSES, "%s: license '%s'" % [_file_of(row), row[3]])
		assert_ne(row[1], "", "%s: source" % _file_of(row))
		assert_ne(row[2], "", "%s: author" % _file_of(row))
