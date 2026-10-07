class_name WordTagger
extends RefCounted
## Tags words by the keyboard rows they need and their length (Story 6.1, FR66). Pure logic: no
## nodes, no autoloads, no file access, so tools/tag_words.gd does the I/O and GUT tests this
## directly. Epic 7 can reuse the row strings for the tier letter pools.

## GDD *Curriculum* row table (US QWERTY). Together the three rows hold a-z exactly once.
const ROW_HOME: String = "asdfghjkl"
const ROW_TOP: String = "qwertyuiop"
const ROW_BOTTOM: String = "zxcvbnm"
## Row names in their canonical order; a word's tags always follow this order.
const ROW_NAMES: Array[String] = ["home", "top", "bottom"]
## GDD *Adaptive Difficulty*: the tier length bands span 2-8 letters.
const MIN_LENGTH: int = 2
## The HUD word sign fits about 9 letters (deferred-work.md, Story 2.5 note); the tier bands stop at 8.
const MAX_LENGTH: int = 8


## The rows the word needs, in canonical order, no repeats. Letters outside a-z are ignored.
static func rows_for(word: String) -> Array[String]:
	var used: Array[bool] = [false, false, false]
	for c: String in word:
		if ROW_HOME.contains(c):
			used[0] = true
		elif ROW_TOP.contains(c):
			used[1] = true
		elif ROW_BOTTOM.contains(c):
			used[2] = true
	var rows: Array[String] = []
	for i: int in ROW_NAMES.size():
		if used[i]:
			rows.append(ROW_NAMES[i])
	return rows


## "" when the word is valid; otherwise a short reason. Checked in this order so the reason is the
## useful one: uppercase, non-letter, too short, too long. Uppercase is rejected, never lowercased,
## so a typo in the source list shows up instead of being silently changed.
static func rejection_reason(word: String) -> String:
	for c: String in word:
		if c >= "A" and c <= "Z":
			return "uppercase"
	for c: String in word:
		if not (c >= "a" and c <= "z"):
			return "non-letter"
	if word.length() < MIN_LENGTH:
		return "too short"
	if word.length() > MAX_LENGTH:
		return "too long"
	return ""


## Tags a plain word list (one word per line). Blank and "#" lines are skipped; bad lines and repeats
## (the first one wins) go to "rejected" with their 1-based line number. Words come back sorted so
## the generated JSON diffs cleanly.
## Returns { "words": Array[Dictionary] {word, rows, length}, "rejected": Array[Dictionary] {line, text, reason} }.
static func tag_lines(lines: PackedStringArray) -> Dictionary:
	var words: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	var first_line: Dictionary = {}
	for i: int in lines.size():
		var text: String = lines[i].replace("\r", "").strip_edges()
		if text == "" or text.begins_with("#"):
			continue
		var reason: String = rejection_reason(text)
		if reason == "" and first_line.has(text):
			reason = "duplicate of line %d" % first_line[text]
		if reason != "":
			rejected.append({ "line": i + 1, "text": text, "reason": reason })
			continue
		first_line[text] = i + 1
		words.append({ "word": text, "rows": rows_for(text), "length": text.length() })
	words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["word"] < b["word"])
	return { "words": words, "rejected": rejected }


## How many entries have a length in [min_len, max_len]. Takes the parsed JSON too (length as float).
static func count_in_band(words: Array, min_len: int, max_len: int) -> int:
	var count: int = 0
	for entry: Dictionary in words:
		var length: int = int(entry["length"])
		if length >= min_len and length <= max_len:
			count += 1
	return count
