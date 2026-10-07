extends LevelBase
## Debug-only level that proves the run frame and the level contract. Letter mode (test_level): shows
## the current letter from a LetterBagSource over a..z and earns a brain every BRAIN_EVERY correct keys.
## Word mode (test_word_level, Story 6.2): shows the current word from a WordSource over the config's
## word list and band and earns a brain per completed word. Reachable only from the debug overlay's jump
## row. Zombie Run (Story 3.1) is the real level.

## Test-level demo rule, not a GDD number.
const BRAIN_EVERY: int = 4
## A short visible pause before the report card; also exercises RunFrame's outro wait.
const OUTRO_S: float = 0.5

var _source: LetterBagSource
var _brains: int = 0


## The 26 lowercase letters, a..z.
static func alphabet() -> Array[String]:
	var letters: Array[String] = []
	for code: int in range(97, 123):
		letters.append(String.chr(code))
	return letters


## The bag gets its own RNG seeded from the run RNG, so level draws never shift the targets. A word
## band with fewer than 2 words returns null, so RunFrame fails safely to the menu (NFR16).
func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
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


## On a target's last letter the source has already advanced, so current() is the next target.
func on_char_accepted(_expected: String, index: int) -> void:
	%LetterLabel.text = _source.current()
	if not _word_mode() and (index + 1) % BRAIN_EVERY == 0:
		_add_brain()


## Word mode demo rule: one brain per completed word.
func on_target_completed(_target: String) -> void:
	_add_brain()


func on_run_ending(_reason: StringName) -> float:
	%StatusLabel.text = "Time!"
	return OUTRO_S


func get_brains_earned() -> int:
	return _brains


func _word_mode() -> bool:
	return config != null and config.target_mode == LevelConfig.TargetMode.WORD


func _add_brain() -> void:
	_brains += 1
	%StatusLabel.text = "Brains: %d" % _brains
	brains_earned_changed.emit(_brains)
