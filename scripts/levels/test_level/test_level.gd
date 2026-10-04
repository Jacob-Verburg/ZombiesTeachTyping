extends LevelBase
## Debug-only level that proves the run frame and the level contract: shows the current letter from a
## LetterBagSource over a..z and earns a brain every BRAIN_EVERY correct keys. Reachable only from
## the placeholder main menu's debug button. Zombie Run (Story 3.1) is the real level.

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


## The bag gets its own RNG seeded from the run RNG, so level draws never shift the letters.
func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
	_source = LetterBagSource.new(child, alphabet())
	%LetterLabel.text = _source.current()
	return _source


## The source has already advanced, so current() is the new target.
func on_char_accepted(_expected: String, index: int) -> void:
	%LetterLabel.text = _source.current()
	if (index + 1) % BRAIN_EVERY == 0:
		_brains += 1
		%StatusLabel.text = "Brains: %d" % _brains
		brains_earned_changed.emit(_brains)


func on_run_ending(_reason: StringName) -> float:
	%StatusLabel.text = "Time!"
	return OUTRO_S


func get_brains_earned() -> int:
	return _brains
