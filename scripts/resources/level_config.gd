class_name LevelConfig
extends Resource
## Per-level settings read by the run (RunFrame) and the typing pipeline.
## Real values live in each level's .tres; the defaults here are neutral, not balance numbers.

## What the player types: single letters, whole words, or running text.
enum TargetMode { LETTER, WORD, PARAGRAPH }

## Run length in seconds (Zombie Run uses 120, set in its .tres).
@export var duration_s: float = 0.0
## True keeps the typed case; false folds capitals to lowercase (FR4).
@export var case_sensitive: bool = false
## True makes Space a typed character; false ignores it (FR3).
@export var space_is_input: bool = false
## Which kind of target the level shows; the HUD's start prompt keys off it.
@export var target_mode: TargetMode = TargetMode.LETTER
## Brains added to every completed run's RunResult.bonus_brains by RunFrame (Zombie Run 10); never on
## quit.
@export var completion_bonus: int = 0
## The music loop the run asks AudioManager for when it starts (Story 5.1: Zombie Run &"mus_zombie_run").
## Empty = leave the music as it is (the test level).
@export var music_id: StringName = &""
## The tagged word list (res://data/content/words.json, Story 6.1) word levels draw from; null = no words.
@export var word_list: JSON
## Shortest word the level uses, inclusive. Epic 7 replaces the fixed band with the tier band.
@export var word_min_length: int = 0
## Longest word the level uses, inclusive. Epic 7 replaces the fixed band with the tier band.
@export var word_max_length: int = 0
