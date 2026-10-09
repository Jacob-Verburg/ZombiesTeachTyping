class_name SentenceGenerator
extends RefCounted
## Builds Pitchfork Panic's tier 1-2 sentences from a tier word pool (Story 8.1, FR67 / FR62). Word
## salad on purpose (GDD: "generated sentences from row-filtered words"): 4-7 words, a capital first
## letter, one "." at the end and, when commas are allowed, at most one "," inside. Holds a WordSource,
## so the words come from its seed-stable bag (every word once before repeats, never twice in a row)
## and only the injected RNG is used. Pure: no nodes, no file access. Not a TargetSource: Story 8.2's
## ParagraphSource groups sentences into passages and owns the Space join.

## FR67: generated sentences have 4-7 words.
const MIN_WORDS: int = 4
const MAX_WORDS: int = 7
## The chance a comma-allowed sentence gets its one comma. A content choice, not a GDD number.
const COMMA_CHANCE: float = 0.5

var _rng: RandomNumberGenerator
var _words: WordSource = null
var _allow_comma: bool = false


## Bad input never asserts (the pool is content data, NFR16): it is logged once and the generator
## stays empty, so next_sentence() gives "".
func _init(rng: RandomNumberGenerator, pool: Array[String], allow_comma: bool) -> void:
	var reason: String = _pool_problem(rng, pool)
	if reason != "":
		Log.error(&"typing", "SentenceGenerator: %s; it will stay empty" % reason)
		return
	_rng = rng
	_allow_comma = allow_comma
	_words = WordSource.new(rng, pool)


## The generator for a tier: commas only in ParagraphRules.COMMA_TIERS, so the rule lives in one place.
## Only ParagraphRules.GENERATED_TIERS generate text: any other tier logs one error (no tier number,
## FR60) and gives null (Story 8.2).
static func for_tier(rng: RandomNumberGenerator, pool: Array[String], tier: int) -> SentenceGenerator:
	if not tier in ParagraphRules.GENERATED_TIERS:
		Log.error(&"typing", "SentenceGenerator: the requested tier has authored text, not generated")
		return null
	return SentenceGenerator.new(rng, pool, tier in ParagraphRules.COMMA_TIERS)


## The next sentence, or "" when the generator is empty. The RNG draw order is fixed (word count,
## the bag's words, then the comma roll and slot) so the same seed replays the same sentences.
func next_sentence() -> String:
	if _words == null:
		return ""
	var count: int = _rng.randi_range(MIN_WORDS, MAX_WORDS)
	var words: Array[String] = []
	for i: int in count:
		words.append(_words.current())
		_words.advance()
	if _allow_comma and _rng.randf() < COMMA_CHANCE:
		var slot: int = _rng.randi_range(1, count - 2)
		words[slot] += ","
	words[0] = words[0].substr(0, 1).to_upper() + words[0].substr(1)
	return " ".join(words) + "."


## "" when the inputs are usable; otherwise a short reason (no tier number in it, FR60).
static func _pool_problem(rng: RandomNumberGenerator, pool: Array[String]) -> String:
	if rng == null:
		return "no RandomNumberGenerator"
	if pool.size() < 2:
		return "the word pool has fewer than 2 words"
	var seen: Dictionary = {}
	for word: String in pool:
		if seen.has(word):
			return "the word pool has a duplicate"
		if WordTagger.rejection_reason(word) != "":
			return "the word pool has an invalid word"
		seen[word] = true
	return ""
