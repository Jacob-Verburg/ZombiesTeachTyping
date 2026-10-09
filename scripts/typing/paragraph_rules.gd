class_name ParagraphRules
extends RefCounted
## The content rules for Pitchfork Panic's authored passages (Story 8.1, FR67). Pure logic: no nodes,
## no file access, so tests/unit/test_paragraphs.gd runs it over data/content/paragraphs.json in CI and
## Story 8.2's ParagraphSource can keep only the valid entries. Bad data is reported, never asserted
## (NFR16). Tiers 1-2 are generated (SentenceGenerator), tiers 3-5 are authored.

## Tiers whose text comes from paragraphs.json.
const AUTHORED_TIERS: Array[int] = [3, 4, 5]
## Tiers whose text SentenceGenerator builds from the tier word pool.
const GENERATED_TIERS: Array[int] = [1, 2]
## Generated tiers whose sentences may hold a comma (GDD tier table: tier 2 adds commas).
const COMMA_TIERS: Array[int] = [2]
const MIN_CHARS: int = 150
const MAX_CHARS: int = 400
const MIN_SENTENCES: int = 2
const MAX_SENTENCES: int = 4
## The paragraph sign fits 12 characters per 24 px line (deferred-work.md, Story 2.5 note), so a longer
## word could never wrap.
const MAX_WORD_CHARS: int = 12
const MIN_PER_TIER: int = 12
const MAX_PER_TIER: int = 15
const MIN_TOTAL: int = 38
const MAX_TOTAL: int = 42
const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const UPPER: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITS: String = "0123456789"
## Tier 3: letters, Space and these.
const TIER3_PUNCTUATION: String = ".,!?"
## Tier 4 adds these to tier 3.
const TIER4_EXTRA: String = "0123456789'"
## Tier 5 adds every other non-letter key data/finger_map.tres maps. ` ~ [ ] { } \ | are not mapped
## (tools/gen_finger_map.gd) and never appear.
const TIER5_EXTRA: String = ";:-\"()/=+_@#$%^&*<>"
const END_MARKS: String = ".!?"
## One of these may close a sentence after its end marks, and open one before its capital.
const CLOSERS: String = "\")"
const OPENERS: String = "\"("


## Letters + Space + the tier's extras, cumulative. "" for a tier outside AUTHORED_TIERS.
static func allowed_chars(tier: int) -> String:
	if not tier in AUTHORED_TIERS:
		return ""
	var chars: String = LETTERS + " " + TIER3_PUNCTUATION
	if tier >= 4:
		chars += TIER4_EXTRA
	if tier >= 5:
		chars += TIER5_EXTRA
	return chars


## How many sentence ends the text has. An end is a run of one or more . ! ? , optionally followed by
## one closing " or ), followed by a Space or the end of the text ("3.50" has no end; "..." is one).
static func sentence_count(text: String) -> int:
	return _sentence_ends(text).size()


## [] when the entry is valid; otherwise one short reason per rule broken. Takes the parsed JSON
## (numbers as float). Unknown extra keys are ignored.
static func passage_problems(entry: Variant) -> Array[String]:
	var problems: Array[String] = []
	if not entry is Dictionary:
		problems.append("not a Dictionary")
		return problems
	var dict: Dictionary = entry
	var id: Variant = dict.get("id")
	if not id is String or (id as String) == "":
		problems.append("id is not a non-empty String")
	var tier: int = _tier_of(dict.get("tier"))
	if tier == 0:
		problems.append("tier is not 3, 4 or 5")
	var raw: Variant = dict.get("text")
	if not raw is String:
		problems.append("text is not a String")
		return problems
	var text: String = raw
	if text.length() < MIN_CHARS or text.length() > MAX_CHARS:
		problems.append("length %d is outside %d-%d" % [text.length(), MIN_CHARS, MAX_CHARS])
	problems.append_array(_char_problems(text, tier))
	problems.append_array(_spacing_problems(text))
	# Trimmed so an edge space is reported once, by the spacing rule.
	problems.append_array(_sentence_problems(text.strip_edges()))
	return problems


## [] when the whole document is valid; otherwise one reason per problem, entry problems prefixed
## with the entry's id (or "#index" when it has none).
static func doc_problems(doc: Variant) -> Array[String]:
	var problems: Array[String] = []
	if not doc is Dictionary:
		problems.append("document is not a Dictionary")
		return problems
	var schema: Variant = (doc as Dictionary).get("schema")
	if not (schema is float or schema is int) or schema != 1:
		problems.append("schema is not 1")
	var passages: Variant = (doc as Dictionary).get("passages")
	if not passages is Array:
		problems.append("passages is not an Array")
		return problems
	var ids: Dictionary = {}
	var texts: Dictionary = {}
	var per_tier: Dictionary = {}
	for tier: int in AUTHORED_TIERS:
		per_tier[tier] = 0
	var list: Array = passages
	for i: int in list.size():
		var entry: Variant = list[i]
		var label: String = "#%d" % i
		if entry is Dictionary:
			var dict: Dictionary = entry
			var id: Variant = dict.get("id")
			if id is String and (id as String) != "":
				label = id
				if ids.has(id):
					problems.append("%s: duplicate id" % label)
				ids[id] = true
			var text: Variant = dict.get("text")
			if text is String:
				if texts.has(text):
					problems.append("%s: duplicate text" % label)
				texts[text] = true
			var tier: int = _tier_of(dict.get("tier"))
			if tier != 0:
				per_tier[tier] += 1
		for problem: String in passage_problems(entry):
			problems.append("%s: %s" % [label, problem])
	for tier: int in AUTHORED_TIERS:
		var count: int = per_tier[tier]
		if count < MIN_PER_TIER or count > MAX_PER_TIER:
			problems.append("tier %d has %d passages, outside %d-%d" % [tier, count, MIN_PER_TIER, MAX_PER_TIER])
	if list.size() < MIN_TOTAL or list.size() > MAX_TOTAL:
		problems.append("%d passages, outside %d-%d" % [list.size(), MIN_TOTAL, MAX_TOTAL])
	return problems


## The tier as an int when it is a JSON number equal to an authored tier; otherwise 0 (3.5 is rejected).
static func _tier_of(value: Variant) -> int:
	if not (value is float or value is int):
		return 0
	var tier: int = int(value)
	if float(tier) != float(value) or not tier in AUTHORED_TIERS:
		return 0
	return tier


static func _char_problems(text: String, tier: int) -> Array[String]:
	var problems: Array[String] = []
	var has_layout: bool = false
	var has_other: bool = false
	var bad: String = ""
	var allowed: String = allowed_chars(tier) if tier != 0 else ""
	for c: String in text:
		var code: int = c.unicode_at(0)
		if c == "\t" or c == "\n" or c == "\r":
			has_layout = true
		elif code < 32 or code > 126:
			has_other = true
		elif tier != 0 and not allowed.contains(c) and not bad.contains(c):
			bad += c
	if has_layout:
		problems.append("has a tab or newline")
	if has_other:
		problems.append("has a non-ASCII character")
	if bad != "":
		problems.append("characters not allowed here: %s" % bad)
	if tier == 4 and not _has_any(text, TIER4_EXTRA):
		problems.append("needs a digit or an apostrophe")
	if tier == 5 and not _has_any(text, TIER5_EXTRA):
		problems.append("needs a richer punctuation mark")
	return problems


static func _spacing_problems(text: String) -> Array[String]:
	var problems: Array[String] = []
	if text.begins_with(" ") or text.ends_with(" "):
		problems.append("leading or trailing space")
	if text.contains("  "):
		problems.append("double space")
	for word: String in text.split(" ", false):
		if word.length() > MAX_WORD_CHARS:
			problems.append("word '%s' is longer than %d" % [word, MAX_WORD_CHARS])
	for i: int in range(1, text.length()):
		if UPPER.contains(text[i - 1]) and UPPER.contains(text[i]):
			problems.append("ALL-CAPS word")
			break
	return problems


static func _sentence_problems(text: String) -> Array[String]:
	var problems: Array[String] = []
	var ends: Array[int] = _sentence_ends(text)
	if ends.size() < MIN_SENTENCES or ends.size() > MAX_SENTENCES:
		problems.append("%d sentences, outside %d-%d" % [ends.size(), MIN_SENTENCES, MAX_SENTENCES])
	if not _starts_sentence(text, 0):
		problems.append("does not start with a capital")
	for end: int in ends:
		if end < text.length() and not _starts_sentence(text, end + 1, true):
			problems.append("no capital after a sentence end")
			break
	if ends.is_empty() or ends[-1] != text.length():
		problems.append("does not end with end punctuation")
	return problems


## The index just after each sentence end (the Space after it, or text.length()).
static func _sentence_ends(text: String) -> Array[int]:
	var ends: Array[int] = []
	var n: int = text.length()
	var i: int = 0
	while i < n:
		if not END_MARKS.contains(text[i]):
			i += 1
			continue
		var j: int = i
		while j < n and END_MARKS.contains(text[j]):
			j += 1
		var k: int = j
		while k < n and CLOSERS.contains(text[k]):
			k += 1
		if k == n or text[k] == " ":
			ends.append(k)
		i = j
	return ends


## True when a sentence may start at `at`: a capital, an opener then a capital, or (after an end) a digit.
static func _starts_sentence(text: String, at: int, digit_ok: bool = false) -> bool:
	if at >= text.length():
		return false
	var c: String = text[at]
	if UPPER.contains(c) or (digit_ok and DIGITS.contains(c)):
		return true
	return OPENERS.contains(c) and at + 1 < text.length() and UPPER.contains(text[at + 1])


static func _has_any(text: String, chars: String) -> bool:
	for c: String in chars:
		if text.contains(c):
			return true
	return false
