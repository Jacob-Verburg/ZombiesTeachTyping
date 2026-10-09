extends GutTest
## Pitchfork Panic passages (Story 8.1, FR67): data/content/paragraphs.json loads, passes every
## ParagraphRules check (the CI gate), keeps to independent per-tier character sets, uses only keys the
## finger map lights, and passes a banned-word backstop. Smuck's review is the real content gate.

const PARAGRAPHS_PATH: String = "res://data/content/paragraphs.json"
const FINGER_MAP_PATH: String = "res://data/finger_map.tres"
## The GDD tier table's characters, written out again here on purpose (independent of ParagraphRules).
const LETTERS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const TIER_CHARS: Dictionary = {
	3: LETTERS + " .,!?",
	4: LETTERS + " .,!?0123456789'",
}
## Exact-token backstop only (NFR9, NFR10): Story 7.3's content rules (scary, death, violence,
## weapons, rude, toilet, adult) plus the rank and difficulty words a kid must never see.
const BANNED: Array[String] = [
	"scary", "scare", "scared", "afraid", "terror", "horror", "nightmare", "monster",
	"dead", "death", "die", "dies", "died", "dying", "kill", "kills", "killed", "grave", "graves",
	"blood", "bloody", "bone", "bones", "skull", "skulls", "corpse", "brainsss", "grrr",
	"bite", "bites", "bitten", "hurt", "hurts", "hit", "hits", "punch", "kick",
	"fight", "stab", "shoot", "gun", "guns", "knife", "sword", "bomb", "attack",
	"stupid", "dumb", "idiot", "hate", "shut", "ugly", "loser", "fat",
	"poop", "pee", "toilet", "butt", "fart", "burp", "puke", "vomit", "snot",
	"beer", "wine", "kiss", "sexy", "drunk",
	"easy", "hard", "difficult", "beginner", "expert", "rank", "grade", "level", "tier", "noob", "pro",
]

var _doc: Dictionary = {}
var _passages: Array = []
## False when before_each could not load the file; the tests then stop after its failed asserts.
var _loaded: bool = false


func before_each() -> void:
	var res: JSON = load(PARAGRAPHS_PATH) as JSON
	assert_not_null(res, "paragraphs.json loads as a JSON resource")
	_doc = res.data if res != null and res.data is Dictionary else {}
	_passages = _doc.get("passages", [])
	assert_gt(_passages.size(), 0, "paragraphs.json has passages")
	_loaded = _passages.size() > 0


func _text(entry: Variant) -> String:
	return (entry as Dictionary).get("text", "") if entry is Dictionary else ""


## The CI gate: every rule in ParagraphRules holds for the shipped file.
func test_shipped_file_passes_every_rule() -> void:
	if not _loaded:
		return
	var problems: Array[String] = ParagraphRules.doc_problems(_doc)
	for problem: String in problems:
		fail_test("paragraphs.json: %s" % problem)
	assert_eq(problems.size(), 0, "no problems in paragraphs.json")


func test_counts_per_tier() -> void:
	if not _loaded:
		return
	var counts: Dictionary = { 3: 0, 4: 0, 5: 0 }
	for entry: Variant in _passages:
		var tier: int = int((entry as Dictionary).get("tier", 0))
		counts[tier] = int(counts.get(tier, 0)) + 1
	gut.p("passages per tier: %s" % counts)
	for tier: int in [3, 4, 5]:
		assert_between(int(counts[tier]), 12, 15, "tier %d count" % tier)
	assert_eq(counts.size(), 3, "only tiers 3-5")


func test_ids_follow_the_scheme_in_file_order() -> void:
	if not _loaded:
		return
	var last_tier: int = 0
	for entry: Variant in _passages:
		var dict: Dictionary = entry
		var id: String = dict.get("id", "")
		var tier: int = int(dict.get("tier", 0))
		assert_true(id.begins_with("t%d_" % tier), "'%s' is named for tier %d" % [id, tier])
		assert_gte(tier, last_tier, "'%s' is grouped by tier" % id)
		last_tier = tier


## Tiers 3 and 4 checked against the independent character sets above.
func test_tier_3_and_4_characters() -> void:
	if not _loaded:
		return
	for entry: Variant in _passages:
		var tier: int = int((entry as Dictionary).get("tier", 0))
		if not TIER_CHARS.has(tier):
			continue
		var allowed: String = TIER_CHARS[tier]
		for c: String in _text(entry):
			assert_true(allowed.contains(c), "'%s' in %s" % [c, (entry as Dictionary).get("id")])


## Belt and braces for Story 8.2's hands: every character is a key the finger map lights.
func test_every_character_is_on_the_finger_map() -> void:
	if not _loaded:
		return
	var map: FingerMap = load(FINGER_MAP_PATH) as FingerMap
	assert_not_null(map, "finger_map.tres loads")
	if map == null:
		return
	assert_gt(map.entries.size(), 0)
	var unmapped: String = ""
	for entry: Variant in _passages:
		for c: String in _text(entry):
			if not map.entries.has(c) and not unmapped.contains(c):
				unmapped += c
	assert_eq(unmapped, "", "every passage character is mapped")


## A backstop, not the gate: exact lowercase a-z tokens only, so "scarecrow" is fine and "scare" is not.
func test_banned_word_backstop() -> void:
	if not _loaded:
		return
	var token_re: RegEx = RegEx.create_from_string("[a-z]+")
	for entry: Variant in _passages:
		for m: RegExMatch in token_re.search_all(_text(entry).to_lower()):
			var token: String = m.get_string()
			assert_false(BANNED.has(token), "'%s' in %s" % [token, (entry as Dictionary).get("id")])
