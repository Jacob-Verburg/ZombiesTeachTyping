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
## Shortest word of the fixed band, inclusive: the band used before placement or when the tier pool
## is missing (FR59); a placed save uses its tier's band from tier_word_pools.
@export var word_min_length: int = 0
## Longest word of the fixed band, inclusive (see word_min_length).
@export var word_max_length: int = 0
## The per-tier word pools (res://data/content/word_pools.json, Story 7.4) a tiered word level draws
## from (Story 7.5); null = the level ignores the tier and uses word_list with the fixed band.
@export var tier_word_pools: JSON
## The authored passages (res://data/content/paragraphs.json, Story 8.1) a paragraph level draws from;
## null = none. Tiers 1-2 generate text from tier_word_pools instead (Story 8.2).
@export var paragraphs: JSON
