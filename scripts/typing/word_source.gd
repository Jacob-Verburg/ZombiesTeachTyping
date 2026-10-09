class_name WordSource
extends LetterBagSource
## Deals whole words (Story 6.2, FR59 / FR66). A word bag is the letter bag with words in it: every
## word once before any repeat, never the same word twice in a row (also across bags), only the
## injected RNG. Extending the bag keeps one shuffle, already tested and seed-stable, instead of two.
## Pure: no nodes, no file access. The level's LevelConfig.word_list (a JSON ext_resource) holds the
## list, so this class never names a path and tests can pass their own JSON.
## Tier pools (Story 7.5, FR62): tier_pool_from_json reads one tier of word_pools.json (Story 7.4), which
## reaches the level through LevelConfig.tier_word_pools the same way.


func _init(rng: RandomNumberGenerator, words: Array[String]) -> void:
	super(rng, words)


## The valid words of a tagged list (`{"words": [{"word": ...}, ...]}`, Story 6.1) whose length is in
## [min_len, max_len], in file order, without repeats. Bad content data never asserts (NFR16): it is
## logged once and whatever was valid before it comes back, often []. Callers check the pool size
## before building a WordSource (the bag needs at least 2 words).
static func pool_from_json(json: JSON, min_len: int, max_len: int) -> Array[String]:
	var pool: Array[String] = []
	if json == null:
		Log.error(&"typing", "WordSource: no word list")
		return pool
	if not json.data is Dictionary:
		Log.error(&"typing", "WordSource: word list data is not a Dictionary")
		return pool
	var data: Dictionary = json.data
	var words: Variant = data.get("words")
	if not words is Array:
		Log.error(&"typing", "WordSource: word list has no \"words\" array")
		return pool
	for entry: Variant in words as Array:
		if not entry is Dictionary:
			Log.error(&"typing", "WordSource: word list entry is not a Dictionary; skipped")
			continue
		var word: Variant = (entry as Dictionary).get("word")
		if not word is String:
			continue
		var text: String = word
		if WordTagger.rejection_reason(text) != "" or pool.has(text):
			continue
		if text.length() >= min_len and text.length() <= max_len:
			pool.append(text)
	return pool


## One tier's words from the per-tier pools (`{"tiers": [{"tier": n, "words": [...]}, ...]}`, Story 7.4)
## whose length is in [min_len, max_len], in file order, without repeats. The band is re-applied on
## purpose: the runtime rule ("the tier's pool with its band") holds even if the TierConfig changes before
## the pools tool is re-run. Rows are not re-checked (test_word_pools.gd guards the file). Bad data never
## asserts (NFR16): malformed tiers or words are skipped with one log line; no matching tier gives [].
static func tier_pool_from_json(json: JSON, tier: int, min_len: int, max_len: int) -> Array[String]:
	var pool: Array[String] = []
	if json == null:
		Log.error(&"typing", "WordSource: no tier pools")
		return pool
	if not json.data is Dictionary:
		Log.error(&"typing", "WordSource: tier pools data is not a Dictionary")
		return pool
	var tiers: Variant = (json.data as Dictionary).get("tiers")
	if not tiers is Array:
		Log.error(&"typing", "WordSource: tier pools have no \"tiers\" array")
		return pool
	var malformed: bool = false
	var found: bool = false
	var seen: Dictionary = {}
	for entry: Variant in tiers as Array:
		if not entry is Dictionary:
			malformed = true
			continue
		var number: Variant = (entry as Dictionary).get("tier")
		if not (number is float or number is int):
			malformed = true
			continue
		if int(number) != tier:
			continue
		var words: Variant = (entry as Dictionary).get("words")
		if not words is Array:
			malformed = true
			continue
		found = true
		for word: Variant in words as Array:
			if not word is String:
				malformed = true
				continue
			var text: String = word
			if seen.has(text) or WordTagger.rejection_reason(text) != "":
				continue
			if text.length() >= min_len and text.length() <= max_len:
				seen[text] = true
				pool.append(text)
	if malformed:
		Log.error(&"typing", "WordSource: tier pools have malformed entries; skipped")
	if not found:
		Log.error(&"typing", "WordSource: tier pools have no words for the requested tier")
	return pool
