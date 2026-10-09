extends LevelBase
## Debug-only level that proves the run frame and the level contract. Letter mode (test_level): shows
## the current letter from a LetterBagSource over a..z and earns a brain every BRAIN_EVERY correct keys.
## Word mode (test_word_level, Story 6.2): shows the current word from a WordSource over the config's
## word list and band and earns a brain per completed word. Paragraph mode (test_paragraph_level, Story
## 8.2): deals the tier's text from ParagraphSource.for_level (the HUD shows it; %LetterLabel stays empty,
## a 400-character passage never fits the playfield), earns a brain per completed passage and emits
## used_passages_changed on the run's start and on every completion, so RunFrame saves the used ids.
## Reachable only from the debug overlay's jump row. Zombie Run (Story 3.1) is the real level.

## Test-level demo rule, not a GDD number.
const BRAIN_EVERY: int = 4
## A short visible pause before the report card; also exercises RunFrame's outro wait.
const OUTRO_S: float = 0.5

var _source: TargetSource
## The same source as _source in paragraph mode (for get_used_ids()); null otherwise.
var _paragraphs: ParagraphSource = null
var _brains: int = 0


## The 26 lowercase letters, a..z.
static func alphabet() -> Array[String]:
	var letters: Array[String] = []
	for code: int in range(97, 123):
		letters.append(String.chr(code))
	return letters


## The bag gets its own RNG seeded from the run RNG, so level draws never shift the targets. A word
## band with fewer than 2 words, or no paragraph text at all, returns null, so RunFrame fails safely to
## the menu (NFR16).
func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
	if _paragraph_mode():
		_paragraphs = ParagraphSource.for_level(child, config, tier, tier_config, used_passages)
		if _paragraphs == null:
			return null
		_pool_label = _paragraphs.get_pool_label()
		_source = _paragraphs
		%LetterLabel.text = ""
		return _source
	if _word_mode():
		var pool: Array[String] = WordSource.pool_from_json(
				config.word_list, config.word_min_length, config.word_max_length)
		if pool.size() < 2:
			Log.error(&"level", "%s: only %d words in the band %d-%d" % [
				name, pool.size(), config.word_min_length, config.word_max_length])
			return null
		_source = WordSource.new(child, pool)
	else:
		_source = LetterBagSource.new(child, alphabet())
	%LetterLabel.text = _source.current()
	return _source


## The first correct key: the passage on the sign is now being typed, so its id is saved.
func on_run_started() -> void:
	if _paragraphs != null:
		used_passages_changed.emit(_paragraphs.get_used_ids())


## On a target's last letter the source has already advanced, so current() is the next target.
func on_char_accepted(_expected: String, index: int) -> void:
	if not _paragraph_mode():
		%LetterLabel.text = _source.current()
	if not _word_mode() and not _paragraph_mode() and (index + 1) % BRAIN_EVERY == 0:
		_add_brain()


## Word and paragraph demo rule: one brain per completed target. A completed passage made the next one
## current (and used), so the list is handed up again.
func on_target_completed(_target: String) -> void:
	_add_brain()
	if _paragraphs != null:
		used_passages_changed.emit(_paragraphs.get_used_ids())


func on_run_ending(_reason: StringName) -> float:
	%StatusLabel.text = "Time!"
	return OUTRO_S


func get_brains_earned() -> int:
	return _brains


func _word_mode() -> bool:
	return config != null and config.target_mode == LevelConfig.TargetMode.WORD


func _paragraph_mode() -> bool:
	return config != null and config.target_mode == LevelConfig.TargetMode.PARAGRAPH


func _add_brain() -> void:
	_brains += 1
	%StatusLabel.text = "Brains: %d" % _brains
	brains_earned_changed.emit(_brains)
