class_name WordSource
extends LetterBagSource
## Deals whole words (Story 6.2, FR59 / FR66). A word bag is the letter bag with words in it: every
## word once before any repeat, never the same word twice in a row (also across bags), only the
## injected RNG. Extending the bag keeps one shuffle, already tested and seed-stable, instead of two.
## Pure: no nodes, no file access. The level's LevelConfig.word_list (a JSON ext_resource) holds the
## list, so this class never names a path and tests can pass their own JSON.


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
			Log.error(&"typing", "WordSource: word list entry is not a Dictionary; stopped at %d words" % pool.size())
			return pool
		var word: Variant = (entry as Dictionary).get("word")
		if not word is String:
			continue
		var text: String = word
		if WordTagger.rejection_reason(text) != "" or pool.has(text):
			continue
		if text.length() >= min_len and text.length() <= max_len:
			pool.append(text)
	return pool
