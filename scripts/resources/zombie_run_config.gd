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
## Each group of this many targets holds exactly 1 brain block (Story 3.2).
@export var brain_block_every: int = 0
## How high the bottom of a brain block floats above the ground line, in px.
@export var brain_block_float_px: float = 0.0
## How long the zombie's hop under a brain block takes, in seconds.
@export var hop_time_s: float = 0.0
## Brains one brain block pays when bonked.
@export var brains_per_block: int = 0
## Chance (0..1) that a collected brain asks for a "Brainsss" voice line.
@export var brainsss_chance: float = 0.0
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
	if brain_block_every < 1:
		return "brain_block_every must be at least 1"
	if hop_time_s <= 0.0:
		return "hop_time_s must be above 0"
	if brains_per_block < 1:
		return "brains_per_block must be at least 1"
	if brain_block_float_px <= PlayerZombie.SIZE_PX:
		return "brain_block_float_px must be above the zombie's height"
	if not (brainsss_chance >= 0.0 and brainsss_chance <= 1.0):
		return "brainsss_chance must be within 0..1"
	return ""
