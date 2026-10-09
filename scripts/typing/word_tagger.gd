class_name WordTagger
extends RefCounted
## Tags words by the keyboard rows they need and their length (Story 6.1, FR66). Pure logic: no
## nodes, no autoloads, no file access, so tools/tag_words.gd does the I/O and GUT tests this
## directly. Story 7.4 added the tier pools: which words each tier may use (its rows and length band
## come from TierConfig) and whether each pool meets its minimum.

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
## FR59 / Story 6.1: before Epic 7 the game uses 3-5 letter words; the starter list needs 150 of them.
const STARTER_BAND_MIN_LEN: int = 3
const STARTER_BAND_MAX_LEN: int = 5
const STARTER_BAND_MIN_COUNT: int = 150
## The fewest words each tier pool may have, tier 1 first. Tier 1: FR66's 40 home-row words, with its band
## widened to 2-4 by Smuck at the Story 7.3 review gate (only 21 kid-safe words have 2-3 letters). Tiers
## 2-5: Story 7.4 AC, 100 each. The one source for tools/tag_words.gd and the word list tests.
const TIER_POOL_MINIMUMS: Array[int] = [40, 100, 100, 100, 100]


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
		var raw: String = lines[i]
		if i == 0:
			raw = raw.trim_prefix("\ufeff")  # UTF-8 BOM from Windows editors
		var text: String = raw.trim_suffix("\r").strip_edges()
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


## The letters of the first `row_count` rows in ROW_NAMES order (1 = home, 2 = home + top, 3 = all).
## "" for a count outside 1-3, so a bad count gives an empty pool rather than a silently clamped one.
static func letters_for_rows(row_count: int) -> String:
	if row_count < 1 or row_count > ROW_NAMES.size():
		return ""
	var rows: Array[String] = [ROW_HOME, ROW_TOP, ROW_BOTTOM]
	return "".join(rows.slice(0, row_count))


## The words (sorted) whose row tags all fall within the first `row_count` rows and whose length is in
## [min_len, max_len] (FR66). Reads the tags rather than rescanning letters. Takes tag_lines entries or
## the parsed JSON (length as float).
static func pool_words(words: Array, row_count: int, min_len: int, max_len: int) -> Array[String]:
	var allowed: Array[String] = []
	if row_count >= 1 and row_count <= ROW_NAMES.size():  # a bad count gives an empty pool, like letters_for_rows
		allowed = ROW_NAMES.slice(0, row_count)
	var out: Array[String] = []
	for entry: Dictionary in words:
		var length: int = int(entry["length"])
		if length < min_len or length > max_len:
			continue
		var fits: bool = true
		for row: String in entry["rows"]:
			if not allowed.has(row):
				fits = false
				break
		if fits:
			out.append(entry["word"])
	out.sort()
	return out


## One pool per tier of `config`, tier 1 first: { tier, rows (names), min_length, max_length, words }.
static func build_tier_pools(words: Array, config: TierConfig) -> Array[Dictionary]:
	var pools: Array[Dictionary] = []
	for tier: int in range(1, config.tier_count() + 1):
		var row_count: int = config.row_count_of(tier)
		var band: Vector2i = config.word_band_of(tier)
		pools.append({
			"tier": tier,
			"rows": ROW_NAMES.slice(0, row_count),
			"min_length": band.x,
			"max_length": band.y,
			"words": pool_words(words, row_count, band.x, band.y),
		})
	return pools


## Per pool: { tier, count, minimum, ok }. `minimums` is tier 1 first. A tier with no minimum reports
## minimum 0 and ok false, so adding a tier without choosing its minimum fails instead of passing.
static func pool_report(pools: Array, minimums: Array[int]) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for pool: Dictionary in pools:
		var tier: int = int(pool["tier"])
		var count: int = (pool["words"] as Array).size()
		var has_minimum: bool = tier >= 1 and tier <= minimums.size()
		var minimum: int = minimums[tier - 1] if has_minimum else 0
		report.append({ "tier": tier, "count": count, "minimum": minimum, "ok": has_minimum and count >= minimum })
	return report
