extends GutTest
## ParagraphRules (Story 8.1, FR67): each rule catches a bad passage and passes the fixed one, the
## sentence counter's edge cases, and the tier character sets against the real finger map.

const FINGER_MAP_PATH: String = "res://data/finger_map.tres"
## 158 characters, 3 sentences, tier 3 characters only.
const GOOD_T3: String = "Zip the zombie loved to dance on the village green every night. The cows clapped along, and the farmer woke up! Did Zip wave his hat and run all the way home?"
const GOOD_T4: String = "Zip the zombie had 7 party hats in his closet, and he could not pick one. He tried them all at 9 o'clock. It's hard to choose when every hat looks this good!"
const GOOD_T5: String = "Zip the zombie made a list: socks, hats and pumpkins. The farmer said, \"Not again!\" Zip just smiled (he always smiles) and kept on dancing in the moonlit village."
## Plain names that make each generated test passage's text unique.
const NAMES: Array[String] = ["Ada", "Ben", "Cal", "Dot", "Eve", "Fay", "Gus", "Hal", "Ivy", "Jo", "Kit", "Lu", "Max", "Ned", "Oz", "Pip"]


func _entry(text: String, tier: int = 3, id: String = "t3_01") -> Dictionary:
	return { "id": id, "tier": float(tier), "text": text }


func _problems(text: String, tier: int = 3) -> Array[String]:
	return ParagraphRules.passage_problems(_entry(text, tier))


func _assert_good(text: String, tier: int = 3) -> void:
	assert_eq(_problems(text, tier), [] as Array[String], "passes: %s" % text)


func _assert_bad(text: String, tier: int, contains: String) -> void:
	var problems: Array[String] = _problems(text, tier)
	var found: bool = false
	for p: String in problems:
		if p.contains(contains):
			found = true
	assert_true(found, "'%s' reported for: %s (got %s)" % [contains, text, problems])


## A valid document: `per_tier` passages for each authored tier, texts made unique with a name.
func _doc(per_tier: Array[int]) -> Dictionary:
	var passages: Array = []
	var bases: Array[String] = [GOOD_T3, GOOD_T4, GOOD_T5]
	for t: int in 3:
		for i: int in per_tier[t]:
			var text: String = bases[t].replace("Zip", NAMES[i])
			passages.append(_entry(text, t + 3, "t%d_%02d" % [t + 3, i + 1]))
	return { "schema": 1.0, "passages": passages }


func test_good_passages_pass() -> void:
	_assert_good(GOOD_T3, 3)
	_assert_good(GOOD_T4, 4)
	_assert_good(GOOD_T5, 5)


func test_extra_keys_are_ignored() -> void:
	var entry: Dictionary = _entry(GOOD_T3)
	entry["note"] = "kept"
	assert_eq(ParagraphRules.passage_problems(entry), [] as Array[String])


func test_entry_shape() -> void:
	assert_eq(ParagraphRules.passage_problems("text"), ["not a Dictionary"] as Array[String])
	assert_eq(ParagraphRules.passage_problems(null), ["not a Dictionary"] as Array[String])
	var no_id: Dictionary = _entry(GOOD_T3)
	no_id.erase("id")
	assert_eq(ParagraphRules.passage_problems(no_id), ["id is not a non-empty String"] as Array[String])
	assert_eq(ParagraphRules.passage_problems(_entry(GOOD_T3, 3, "")), ["id is not a non-empty String"] as Array[String])
	var number_text: Dictionary = _entry(GOOD_T3)
	number_text["text"] = 7
	assert_eq(ParagraphRules.passage_problems(number_text), ["text is not a String"] as Array[String])


func test_wrong_tier() -> void:
	for bad: Variant in [2.0, 6.0, 3.5, "3", null, 0]:
		var entry: Dictionary = _entry(GOOD_T3)
		entry["tier"] = bad
		assert_eq(ParagraphRules.passage_problems(entry), ["tier is not 3, 4 or 5"] as Array[String], "tier %s" % [bad])
	var int_tier: Dictionary = _entry(GOOD_T3)
	int_tier["tier"] = 3
	assert_eq(ParagraphRules.passage_problems(int_tier), [] as Array[String], "an int tier is fine too")


## A valid 2-sentence tier 3 passage of exactly `target` characters (at least 27).
func _padded(target: int) -> String:
	var rest: int = target - 27
	var text: String = "Zip" + "p".repeat(rest % 3) + " sang" + " la".repeat(floori(rest / 3.0)) + ". Then he ran home."
	return text


func test_length_limits() -> void:
	for target: int in [ParagraphRules.MIN_CHARS, ParagraphRules.MAX_CHARS]:
		assert_eq(_padded(target).length(), target)
		_assert_good(_padded(target))
	_assert_bad(_padded(ParagraphRules.MIN_CHARS - 1), 3, "length 149")
	_assert_bad(_padded(ParagraphRules.MAX_CHARS + 1), 3, "length 401")


func test_sentence_limits() -> void:
	var one: String = "Zip the zombie loved to dance on the village green every night, and the cows clapped along while the farmer slept, and the moon was big and round and bright!"
	assert_eq(ParagraphRules.sentence_count(one), 1)
	_assert_bad(one, 3, "1 sentences")
	var five: String = "Zip the zombie loved to dance. The cows clapped. The farmer woke up! Zip waved his hat. Then he ran home and had a nice snack."
	five = five.replace("nice snack", "nice big snack of tomato soup on the porch")
	assert_eq(ParagraphRules.sentence_count(five), 5)
	_assert_bad(five, 3, "5 sentences")


func test_tier_3_characters() -> void:
	_assert_bad(GOOD_T3.replace("every night", "at 9"), 3, "not allowed")
	_assert_bad(GOOD_T3.replace("loved", "lov'd"), 3, "not allowed")
	_assert_bad(GOOD_T3.replace("green every", "green; every"), 3, "not allowed")


func test_tier_4_characters() -> void:
	_assert_bad(GOOD_T4.replace("closet,", "closet;"), 4, "not allowed")
	var plain: String = GOOD_T4.replace("7", "seven").replace("9 o'clock", "nine").replace("It's", "It is")
	_assert_bad(plain, 4, "needs a digit or an apostrophe")
	_assert_good(plain.replace("seven", "7"), 4)
	_assert_good(plain.replace("It is", "It's"), 4)


func test_tier_5_needs_a_richer_mark() -> void:
	var only_t4: String = "Zip the zombie had 7 party hats, and he could not pick one. He tried them all at 9 o'clock. It's hard to choose when every hat looks so good! Zip wore them all."
	_assert_bad(only_t4, 5, "needs a richer punctuation mark")
	_assert_good(only_t4.replace("hats, and", "hats; and"), 5)
	for c: String in "`~[]{}\\|":
		_assert_bad(GOOD_T5.replace("socks,", "socks" + c), 5, "not allowed")


func test_non_ascii_characters() -> void:
	_assert_bad(GOOD_T5.replace("\"Not again!\"", "\u201cNot again!\u201d"), 5, "non-ASCII")
	_assert_bad(GOOD_T4.replace("o'clock", "o\u2019clock"), 4, "non-ASCII")
	_assert_bad(GOOD_T5.replace("list:", "list \u2014"), 5, "non-ASCII")
	_assert_bad(GOOD_T3.replace("along,", "along\u2026"), 3, "non-ASCII")
	_assert_bad(GOOD_T3.replace("the village", "the\u00a0village"), 3, "non-ASCII")


func test_tab_and_newline() -> void:
	_assert_bad(GOOD_T3.replace("The cows", "The\tcows"), 3, "tab or newline")
	_assert_bad(GOOD_T3.replace(" The cows", "\nThe cows"), 3, "tab or newline")


func test_spacing() -> void:
	_assert_bad(GOOD_T3.replace("the zombie", "the  zombie"), 3, "double space")
	_assert_bad(" " + GOOD_T3, 3, "leading or trailing space")
	_assert_bad(GOOD_T3 + " ", 3, "leading or trailing space")


func test_capitals_and_end_punctuation() -> void:
	_assert_bad("z" + GOOD_T3.substr(1), 3, "does not start with a capital")
	_assert_bad(GOOD_T3.replace("The cows", "the cows"), 3, "no capital after a sentence end")
	_assert_bad(GOOD_T3.trim_suffix("?"), 3, "does not end with end punctuation")
	_assert_bad(GOOD_T3.trim_suffix("?") + ",", 3, "does not end with end punctuation")
	_assert_good(GOOD_T4.replace("He tried", "9 times he tried"), 4)


func test_dialogue_tag_after_a_quoted_end_fails() -> void:
	var text: String = "\"Run!\" said the farmer. Okay."
	assert_eq(ParagraphRules.sentence_count(text), 3)
	var passage: String = GOOD_T5.replace("The farmer said, \"Not again!\"", "\"Not again!\" said the farmer.")
	_assert_bad(passage, 5, "no capital after a sentence end")
	_assert_good(GOOD_T5.replace("The farmer said, \"Not again!\"", "\"Not again,\" said the farmer."), 5)


func test_quoted_and_bracketed_starts() -> void:
	_assert_good("\"Hello!\" " + GOOD_T5, 5)
	_assert_good(GOOD_T5.replace("Zip just smiled (he always smiles)", "(He always smiles.) Zip just smiled"), 5)


func test_long_word() -> void:
	_assert_bad(GOOD_T3.replace("village", "villagevilla"), 3, "longer than")
	_assert_good(GOOD_T3.replace("village", "villagevill"), 3)
	_assert_bad(GOOD_T5.replace("(he always smiles)", "(heeeeeeeeeee)"), 5, "longer than")


func test_all_caps_word() -> void:
	_assert_bad(GOOD_T3.replace("dance", "DANCE"), 3, "ALL-CAPS")
	_assert_bad(GOOD_T3.replace("Zip the", "ZIp the"), 3, "ALL-CAPS")
	_assert_good(GOOD_T3.replace("Did Zip", "Did I"), 3)


func test_sentence_count_edge_cases() -> void:
	assert_eq(ParagraphRules.sentence_count("Hi there. Bye now."), 2)
	assert_eq(ParagraphRules.sentence_count("Wait... what?! Yes."), 3)
	assert_eq(ParagraphRules.sentence_count("It cost 3.50 brains. Wow!"), 2)
	assert_eq(ParagraphRules.sentence_count("He said, \"Go.\" Then he went."), 2)
	assert_eq(ParagraphRules.sentence_count("(See the hat.) Nice."), 2)
	assert_eq(ParagraphRules.sentence_count("(He said \"Go.\") Then he left."), 2)
	assert_eq(ParagraphRules.sentence_count("Hi. (He said \"Go.\")"), 2)
	assert_eq(ParagraphRules.sentence_count("No end here"), 0)
	assert_eq(ParagraphRules.sentence_count(""), 0)


func test_good_document() -> void:
	assert_eq(ParagraphRules.doc_problems(_doc([13, 13, 13])), [] as Array[String])
	assert_eq(ParagraphRules.doc_problems(_doc([12, 12, 14])), [] as Array[String], "38 total")
	assert_eq(ParagraphRules.doc_problems(_doc([14, 14, 14])), [] as Array[String], "42 total")


func test_document_shape() -> void:
	assert_eq(ParagraphRules.doc_problems([]), ["document is not a Dictionary"] as Array[String])
	assert_eq(ParagraphRules.doc_problems({ "schema": 1 }), ["passages is not an Array"] as Array[String])
	var doc: Dictionary = _doc([13, 13, 13])
	doc["schema"] = 2
	assert_eq(ParagraphRules.doc_problems(doc), ["schema is not 1"] as Array[String])
	doc.erase("schema")
	assert_eq(ParagraphRules.doc_problems(doc), ["schema is not 1"] as Array[String])


func test_duplicate_id_and_text() -> void:
	var doc: Dictionary = _doc([13, 13, 13])
	var passages: Array = doc["passages"]
	(passages[1] as Dictionary)["id"] = "t3_01"
	assert_eq(ParagraphRules.doc_problems(doc), ["t3_01: duplicate id"] as Array[String])
	doc = _doc([13, 13, 13])
	passages = doc["passages"]
	(passages[1] as Dictionary)["text"] = (passages[0] as Dictionary)["text"]
	assert_eq(ParagraphRules.doc_problems(doc), ["t3_02: duplicate text"] as Array[String])


func test_entry_problems_are_prefixed() -> void:
	var doc: Dictionary = _doc([13, 13, 13])
	var passages: Array = doc["passages"]
	(passages[0] as Dictionary)["text"] = GOOD_T3 + " "
	assert_eq(ParagraphRules.doc_problems(doc), ["t3_01: leading or trailing space"] as Array[String])
	(passages[0] as Dictionary).erase("id")
	assert_eq(ParagraphRules.doc_problems(doc), ["#0: id is not a non-empty String", "#0: leading or trailing space"] as Array[String])


func test_tier_counts_outside_the_limits() -> void:
	var low: Array[String] = ParagraphRules.doc_problems(_doc([11, 14, 14]))
	assert_true(low.has("tier 3 has 11 passages, outside 12-15"), str(low))
	var high: Array[String] = ParagraphRules.doc_problems(_doc([16, 12, 12]))
	assert_true(high.has("tier 3 has 16 passages, outside 12-15"), str(high))
	var few: Array[String] = ParagraphRules.doc_problems(_doc([12, 12, 12]))
	assert_eq(few, ["36 passages, outside 38-42"] as Array[String])
	var many: Array[String] = ParagraphRules.doc_problems(_doc([15, 15, 13]))
	assert_eq(many, ["43 passages, outside 38-42"] as Array[String])


func test_allowed_chars() -> void:
	assert_eq(ParagraphRules.allowed_chars(1), "")
	assert_eq(ParagraphRules.allowed_chars(6), "")
	assert_eq(ParagraphRules.allowed_chars(3).length(), 26 * 2 + 1 + 4)
	assert_eq(ParagraphRules.allowed_chars(4).length(), 26 * 2 + 1 + 4 + 11)
	assert_eq(ParagraphRules.allowed_chars(5).length(), 87, "every finger map key, once")
	for low: int in [3, 4]:
		for c: String in ParagraphRules.allowed_chars(low):
			assert_true(ParagraphRules.allowed_chars(low + 1).contains(c), "'%s' of tier %d is in tier %d" % [c, low, low + 1])


func test_tier_5_chars_are_all_on_the_finger_map() -> void:
	var map: FingerMap = load(FINGER_MAP_PATH) as FingerMap
	assert_not_null(map, "finger_map.tres loads")
	if map == null:
		return
	assert_gt(map.entries.size(), 0)
	for c: String in ParagraphRules.allowed_chars(5):
		assert_true(map.entries.has(c), "'%s' is mapped, so the hands can light it" % c)
	for key: Variant in map.entries.keys():
		assert_true(ParagraphRules.allowed_chars(5).contains(key as String), "mapped '%s' is allowed in tier 5" % key)
