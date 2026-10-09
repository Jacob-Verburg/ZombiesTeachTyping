class_name ParagraphLayout
extends RefCounted
## Word-wraps a paragraph target into the HUD's 2-line window (Story 8.2, FR69). Pure and static: no
## nodes, no autoloads, so the HUD and the tests share it. A line is a start index into the text; every
## character, Spaces included, belongs to exactly one line, and a line's trailing Space counts toward
## its length (the kid types it, and the underline must sit in a visible cell). A Space never starts a
## line. A word too long for an empty line breaks after its last "-" (defensive: validated text never has one), else
## hard-splits at line_chars - 1 characters, so nothing ever overflows.

## Characters per 24 px line: 12 x 24 px = 288 px, the paragraph sign's inner width (sketch hud-band-2-5
## deviation 4).
const LINE_CHARS: int = 12


## Each line's start index into `text`, greedy: a word with its following Space goes on the current line
## when it fits, else starts the next one. "" gives [0].
static func wrap(text: String, line_chars: int = LINE_CHARS) -> PackedInt32Array:
	line_chars = maxi(line_chars, 2)
	var starts: PackedInt32Array = PackedInt32Array([0])
	var line_len: int = 0
	for piece: Vector2i in _pieces(text, line_chars):
		if line_len > 0 and line_len + piece.y > line_chars:
			starts.append(piece.x)
			line_len = 0
		line_len += piece.y
	return starts


## The line holding character `index`: the last start <= index, clamped to a valid line.
static func line_of(starts: PackedInt32Array, index: int) -> int:
	if starts.is_empty():
		return 0
	return clampi(starts.bsearch(index, false) - 1, 0, starts.size() - 1)


## The text cut into (start, length) pieces that each fit an empty line: a word plus its following
## Space, or the parts of a word too long for one line.
static func _pieces(text: String, line_chars: int) -> Array[Vector2i]:
	var pieces: Array[Vector2i] = []
	var n: int = text.length()
	var i: int = 0
	while i < n:
		var end: int = i
		while end < n and text[end] != " ":
			end += 1
		if end < n:
			end += 1
		var start: int = i
		while end - start > line_chars:
			var cut: int = _cut_length(text.substr(start, line_chars), end - start)
			pieces.append(Vector2i(start, cut))
			start += cut
		pieces.append(Vector2i(start, end - start))
		i = end
	return pieces


## How much of an over-long word (`left` characters, its Space included) goes on its line: up to and
## including the last "-" in `head` (the first line_chars characters), else all but one character. A cut
## never leaves only the Space behind, so a Space never starts a line.
static func _cut_length(head: String, left: int) -> int:
	var hyphen: int = head.rfind("-")
	if hyphen >= 0 and hyphen + 1 < left - 1:
		return hyphen + 1
	return head.length() - 1
