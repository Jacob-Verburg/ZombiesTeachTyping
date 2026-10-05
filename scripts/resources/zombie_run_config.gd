class_name ZombieRunConfig
extends LevelConfig
## Zombie Run's own tuning numbers (Story 3.1), on top of the shared LevelConfig fields. A
## ZombieRunConfig is a LevelConfig, so RunFrame, TypingInput and the HUD read it unchanged.
## Real values live in data/levels/zombie_run.tres; the defaults here are neutral.

## World distance between two neighbouring targets on the path, in px.
@export var target_spacing_px: float = 0.0
## How many targets after the active one are shown.
@export var visible_upcoming: int = 0
## The zombie's walking speed toward the active target when no scoot is running, in px/s.
@export var amble_speed_px_s: float = 0.0
## The zombie idles this far before the active target, in px.
@export var approach_gap_px: float = 0.0
## How long one scoot to the next target takes after a correct key, in seconds.
@export var scoot_time_s: float = 0.0
## Every Nth target is a brain block (used from Story 3.2).
@export var brain_block_every: int = 0
## The letters the bag deals from (single lowercase characters, no duplicates).
@export var letter_pool: Array[String] = []


## Empty when the numbers can run a level; otherwise the first problem found.
func validate() -> String:
	if visible_upcoming < 1:
		return "visible_upcoming must be at least 1"
	if letter_pool.size() < 2:
		return "letter_pool needs at least 2 letters"
	if target_spacing_px <= 0.0:
		return "target_spacing_px must be above 0"
	if amble_speed_px_s <= 0.0:
		return "amble_speed_px_s must be above 0"
	if scoot_time_s <= 0.0:
		return "scoot_time_s must be above 0"
	return ""
