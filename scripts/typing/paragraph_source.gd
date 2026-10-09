class_name ParagraphSource
extends TargetSource
## Deals paragraph targets (Story 8.2, FR67 / FR68 / FR69): one target per passage, the passage text plus
## one join Space, so typing that Space completes the passage and the next one starts (GDD G7). Pure: no
## nodes, no file access; the level hands in its LevelConfig's JSON through for_level().
## Authored mode (tiers 3-5, paragraphs.json): no passage repeats until every passage of the list has been
## used; then the tier's ids are dropped from the used list (when the first passage of the new cycle
## becomes current) and a new cycle starts, never with the passage just shown. A passage is used when it
## becomes current (peeking never marks or resets), so get_used_ids() is what
## the save keeps (profiles.<id>.used_passages, one flat list for every tier: the "t<tier>_" id prefix
## tells them apart).
## Generated mode (tiers 1-2): each passage is GENERATED_SENTENCES SentenceGenerator sentences; nothing is
## tracked. Neither mode runs dry.
## Determinism: only the injected (child) RNG is drawn, by passage selection or by the generator, and peek
## only deals earlier, never differently. Replay contract: a seed replays the same text only at the same
## tier AND the same starting used list; a debug replay after the list has moved deals other passages.
## Bad data never asserts (NFR16), and no log line names a tier or a validator message (FR60).

## The Space that joins one passage to the next; the last character of every target.
const JOIN: String = " "
## Sentences per generated passage. A content choice, not a GDD number: 3 sentences of 4-7 words make a
## 2-5-line passage.
const GENERATED_SENTENCES: int = 3
## The authored tier an untiered run, or a tier whose text can't be built, falls back to.
const FALLBACK_TIER: int = 3
## A passage id: "t<tier>_" and two or more digits (8.1: ids are save data, never renumbered).
const ID_PATTERN: String = "^t(\\d+)_\\d{2,}\\z"

static var _id_regex: RegEx = null

var _rng: RandomNumberGenerator = null
## Authored passages, {"id", "text"}, in file order.
var _passages: Array[Dictionary] = []
var _generator: SentenceGenerator = null
## Used ids in the order marked (all tiers).
var _used: Array[String] = []
## Already dealt, not yet consumed. Index 0 is current().
var _queue: Array[Dictionary] = []
## The id of the passage that most recently became current, for the cycle-boundary rule.
var _last_current_id: String = ""
## Set by for_level(): the run record's pool label.
var _pool_label: String = GameConstants.LETTER_POOL_ALL


## Authored mode. `used` is the save's list (copied); a non-empty `all_ids` (every id in the file) first
## prunes retired ids from it, so the saved list can't grow forever. A null RNG or no passages logs once
## and leaves the source empty (current() is ""). `generator` and `generated_mode` are generated()'s seam.
func _init(rng: RandomNumberGenerator = null, passages: Array[Dictionary] = [], used: Array[String] = [],
		all_ids: Array[String] = [], generator: SentenceGenerator = null, generated_mode: bool = false) -> void:
	for id: String in used:
		if id != "" and not _used.has(id) and (all_ids.is_empty() or all_ids.has(id)):
			_used.append(id)
	if rng == null:
		Log.error(&"typing", "ParagraphSource: no RandomNumberGenerator; it will stay empty")
		return
	if generated_mode:
		if generator == null:
			Log.error(&"typing", "ParagraphSource: no sentence generator; it will stay empty")
			return
		_rng = rng
		_generator = generator
		_ensure(1)
		if _queue.is_empty():
			_generator = null
			_rng = null
			Log.error(&"typing", "ParagraphSource: the sentence generator gave no text; it will stay empty")
		return
	if passages.is_empty():
		Log.error(&"typing", "ParagraphSource: no passages; it will stay empty")
		return
	_rng = rng
	_passages = passages.duplicate(true)
	_ensure(1)
	_mark_current()


## Generated mode (tiers 1-2): GENERATED_SENTENCES of `generator`'s sentences per passage, never tracked.
## A null or empty generator leaves the source empty with one log line. `used` / `all_ids` are carried
## through untouched so get_used_ids() hands the save's authored history back (a generated run must not wipe it).
static func generated(rng: RandomNumberGenerator, generator: SentenceGenerator,
		used: Array[String] = [], all_ids: Array[String] = []) -> ParagraphSource:
	return ParagraphSource.new(rng, [] as Array[Dictionary], used, all_ids, generator, true)


## The source a paragraph level uses (the test level now, Pitchfork Panic in 8.3). `rng` is the level's
## child RNG. Tiers 1-2 generate from the tier's word pool and band; tiers 3-5 deal that tier's authored
## passages; tier 0, any other tier, or a tier whose text can't be built deals FALLBACK_TIER's passages
## labelled "all". null when even those are missing (RunFrame then fails safely to the menu, NFR16).
static func for_level(rng: RandomNumberGenerator, config: LevelConfig, tier: int, tier_config: TierConfig,
		used: Array[String]) -> ParagraphSource:
	if config == null:
		Log.error(&"typing", "ParagraphSource: no level config")
		return null
	var label: String = GameConstants.TIER_POOL_FORMAT % tier
	var all_ids: Array[String] = _all_ids(config.paragraphs)
	var failed: bool = tier != 0
	if tier in ParagraphRules.GENERATED_TIERS and tier_config != null:
		var band: Vector2i = tier_config.word_band_of(tier)
		if band != Vector2i.ZERO:
			var pool: Array[String] = WordSource.tier_pool_from_json(config.tier_word_pools, tier, band.x, band.y)
			if pool.size() >= 2:
				var source: ParagraphSource = generated(rng, SentenceGenerator.for_tier(rng, pool, tier), used, all_ids)
				if source.current() != "":
					source._pool_label = label
					return source
	elif tier in ParagraphRules.AUTHORED_TIERS:
		var passages: Array[Dictionary] = passages_from_json(config.paragraphs, tier)
		if not passages.is_empty():
			var authored: ParagraphSource = ParagraphSource.new(rng, passages, used, all_ids)
			authored._pool_label = label
			return authored
	if failed:
		Log.error(&"typing", "ParagraphSource: no text for the requested tier; using the fallback passages")
	var fallback: Array[Dictionary] = passages_from_json(config.paragraphs, FALLBACK_TIER)
	if fallback.is_empty():
		Log.error(&"typing", "ParagraphSource: no fallback passages")
		return null
	var source_all: ParagraphSource = ParagraphSource.new(rng, fallback, used, all_ids)
	source_all._pool_label = GameConstants.LETTER_POOL_ALL
	return source_all


## The valid passages of `tier` in paragraphs.json (`{"passages": [{"id", "tier", "text"}, ...]}`, Story
## 8.1) as {"id", "text"}, in file order, without duplicate ids. Valid = ParagraphRules finds no problem
## and the id is "t<tier>_NN" with the entry's own tier. A bad entry is skipped and counted, with one log
## line that names only the count (never the problems: they name tiers, FR60). Never asserts (NFR16).
static func passages_from_json(json: JSON, tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = _passage_list(json)
	var failed: int = 0
	var seen: Dictionary = {}
	for entry: Variant in list:
		if not entry is Dictionary:
			failed += 1
			continue
		var dict: Dictionary = entry
		var raw_tier: Variant = dict.get("tier")
		if not (raw_tier is float or raw_tier is int):
			failed += 1
			continue
		if raw_tier is float and raw_tier != floorf(raw_tier):
			failed += 1
			continue
		if int(raw_tier) != tier:
			continue
		var id: Variant = dict.get("id")
		if not ParagraphRules.passage_problems(dict).is_empty() or not _id_matches(id, tier) or seen.has(id):
			failed += 1
			continue
		seen[id] = true
		out.append({"id": id as String, "text": dict["text"] as String})
	if failed > 0:
		Log.error(&"typing", "ParagraphSource: %d passages failed checks; skipped" % failed)
	return out


func peek(n: int) -> Array[String]:
	var out: Array[String] = []
	if n <= 0:
		return out
	_ensure(n + 1)
	for i: int in range(1, mini(n + 1, _queue.size())):
		out.append(_target_of(_queue[i]))
	return out


func current() -> String:
	return _target_of(_queue[0]) if not _queue.is_empty() else ""


func advance() -> void:
	if _queue.is_empty():
		return
	_queue.remove_at(0)
	_ensure(1)
	_mark_current()


## The current passage's id; "" in generated mode or when empty.
func get_current_id() -> String:
	return str(_queue[0]["id"]) if not _queue.is_empty() else ""


## The used ids in the order marked (a copy): what the level hands up to the save.
func get_used_ids() -> Array[String]:
	return _used.duplicate()


## The run record's pool label: "tier_n" for a tiered source, "all" for the fallback (FR60: never shown).
func get_pool_label() -> String:
	return _pool_label


func _ensure(count: int) -> void:
	if _rng == null:
		return
	while _queue.size() < count:
		var next: Dictionary = _deal_generated() if _generator != null else _deal_authored()
		if next.is_empty():
			return
		_queue.append(next)


func _deal_generated() -> Dictionary:
	var sentences: Array[String] = []
	for i: int in GENERATED_SENTENCES:
		var sentence: String = _generator.next_sentence()
		if sentence == "":
			return {}
		sentences.append(sentence)
	return {"id": "", "text": " ".join(sentences)}


## Fixed draw order: one randi_range over the candidates in file order. A peek never changes `_used`: a
## passage that opens a new cycle carries "cycle_start", and the used list is only reset when that passage
## becomes current (_mark_current), so the passage being typed is never dropped from the save.
func _deal_authored() -> Dictionary:
	if _passages.is_empty():
		return {}
	var used: Array[String] = _effective_used()
	var candidates: Array[Dictionary] = []
	for passage: Dictionary in _passages:
		var id: String = passage["id"]
		if not used.has(id) and not _is_queued(id):
			candidates.append(passage)
	var starts_cycle: bool = candidates.is_empty()
	if starts_cycle:
		for passage: Dictionary in _passages:
			var id: String = passage["id"]
			if not _is_queued(id) and id != _last_current_id:
				candidates.append(passage)
	if candidates.is_empty():
		# Only possible with a tiny list: repeat a passage rather than run dry, but not one already queued.
		for passage: Dictionary in _passages:
			if not _is_queued(passage["id"]):
				candidates.append(passage)
	if candidates.is_empty():
		candidates = _passages.duplicate()
	var dealt: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)].duplicate()
	if starts_cycle:
		dealt["cycle_start"] = true
	return dealt


## The used list as it will be once every queued passage is current, cycle resets included.
func _effective_used() -> Array[String]:
	var used: Array[String] = _used.duplicate()
	for i: int in range(1, _queue.size()):
		if _queue[i].get("cycle_start", false):
			used = _pruned(used)
		var id: String = str(_queue[i]["id"])
		if id != "" and not used.has(id):
			used.append(id)
	return used


## `list` without this list's ids, and any id with the same "t<tier>_" prefix. Other tiers' ids survive.
func _pruned(list: Array[String]) -> Array[String]:
	var prefixes: Array[String] = []
	var ids: Dictionary = {}
	for passage: Dictionary in _passages:
		var id: String = passage["id"]
		ids[id] = true
		var prefix: String = _prefix_of(id)
		if prefix != "" and not prefixes.has(prefix):
			prefixes.append(prefix)
	var kept: Array[String] = []
	for id: String in list:
		if not ids.has(id) and not prefixes.has(_prefix_of(id)):
			kept.append(id)
	return kept


func _mark_current() -> void:
	if _queue.is_empty():
		return
	var id: String = str(_queue[0]["id"])
	_last_current_id = id
	if _queue[0].has("cycle_start"):
		_queue[0].erase("cycle_start")
		_used = _pruned(_used)
	if id != "" and not _used.has(id):
		_used.append(id)


func _is_queued(id: String) -> bool:
	for passage: Dictionary in _queue:
		if passage["id"] == id:
			return true
	return false


static func _target_of(passage: Dictionary) -> String:
	return str(passage["text"]) + JOIN


## "t3_" for "t3_01"; "" when the id has no "t<digits>_" prefix.
static func _prefix_of(id: String) -> String:
	var underscore: int = id.find("_")
	if underscore < 2 or not id.begins_with("t") or not id.substr(1, underscore - 1).is_valid_int():
		return ""
	return id.left(underscore + 1)


static func _id_matches(id: Variant, tier: int) -> bool:
	if not id is String:
		return false
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	var found: RegExMatch = _id_regex.search(id as String)
	return found != null and found.get_string(1).is_valid_int() and int(found.get_string(1)) == tier


## The passages array of a paragraphs JSON, or [] (with one log line) when it is missing or malformed.
static func _passage_list(json: JSON) -> Array:
	if json == null:
		Log.error(&"typing", "ParagraphSource: no paragraphs")
		return []
	if not json.data is Dictionary:
		Log.error(&"typing", "ParagraphSource: paragraphs data is not a Dictionary")
		return []
	var passages: Variant = (json.data as Dictionary).get("passages")
	if not passages is Array:
		Log.error(&"typing", "ParagraphSource: paragraphs have no \"passages\" array")
		return []
	return passages


## Every String id in the file, valid or not, for the retired-id prune. Silent: the loader logs.
static func _all_ids(json: JSON) -> Array[String]:
	var ids: Array[String] = []
	if json == null or not json.data is Dictionary:
		return ids
	var passages: Variant = (json.data as Dictionary).get("passages")
	if not passages is Array:
		return ids
	for entry: Variant in passages as Array:
		if entry is Dictionary and (entry as Dictionary).get("id") is String:
			ids.append((entry as Dictionary)["id"] as String)
	return ids
