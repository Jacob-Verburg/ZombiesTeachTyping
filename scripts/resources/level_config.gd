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
