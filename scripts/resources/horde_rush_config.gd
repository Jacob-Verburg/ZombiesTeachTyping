class_name HordeRushConfig
extends LevelConfig
## Horde Rush's own tuning numbers (Story 6.3), on top of the shared LevelConfig fields. A HordeRushConfig
## is a LevelConfig, so RunFrame, TypingInput and the HUD read it unchanged. Real values live in
## data/levels/horde_rush.tres; the defaults here are neutral. Story 6.4 adds the defender numbers;
## Story 6.5 adds the run-end outro length.

## The shortest crossing time validate() accepts, well above HordeMarcher.ARRIVE_EPSILON_S.
const MIN_CROSSING_TIME_S: float = 0.01

## How many lanes the field has (top lane = 0).
@export var lane_count: int = 0
## The size classes, shortest band first; the last one has max_word_length 0 (no upper bound).
@export var size_classes: Array[HordeSizeClass] = []
## FR56: seconds the defender takes to pace from one lane to the next.
@export var defender_lane_time_s: float = 0.0
## FR56: seconds between two throws.
@export var defender_throw_cooldown_s: float = 0.0
## FR56: seconds a projectile takes to fly the whole field (house line to left edge).
@export var projectile_cross_time_s: float = 0.0
## FR56: seconds a hit copy flashes (0 = no flash).
@export var hit_flash_s: float = 0.0
## FR56: seconds a stopped copy takes to melt into the ground (0 = gone at once).
@export var melt_s: float = 0.0
## FR57: seconds the run-end dance lasts before the report card.
@export var outro_time_s: float = 0.0


## The first class whose band holds `word_length`; null only when there are no classes.
func size_class_for(word_length: int) -> HordeSizeClass:
	for size_class: HordeSizeClass in size_classes:
		if size_class == null:
			continue
		if size_class.max_word_length == 0 or word_length <= size_class.max_word_length:
			return size_class
	return null


## Empty when the numbers can run a level; otherwise the first problem found.
func validate() -> String:
	if not (duration_s > 0.0 and is_finite(duration_s)):
		return "duration_s must be above 0"
	if target_mode != TargetMode.WORD:
		return "target_mode must be WORD"
	if word_list == null:
		return "word_list is missing"
	if word_min_length < 1 or word_min_length > word_max_length:
		return "word band must be 1 <= word_min_length <= word_max_length"
	if lane_count < 1:
		return "lane_count must be at least 1"
	if size_classes.is_empty():
		return "size_classes needs at least 1 class"
	var last_max: int = 0
	var seen_ids: Array[StringName] = []
	for i: int in size_classes.size():
		var size_class: HordeSizeClass = size_classes[i]
		if size_class == null:
			return "size class %d is missing" % i
		if seen_ids.has(size_class.id):
			return "size class %d: id '%s' is used twice" % [i, size_class.id]
		seen_ids.append(size_class.id)
		if not (size_class.crossing_time_s >= MIN_CROSSING_TIME_S and is_finite(size_class.crossing_time_s)):
			return "size class %d: crossing_time_s must be at least %s" % [i, MIN_CROSSING_TIME_S]
		if size_class.hits_to_stop < 1:
			return "size class %d: hits_to_stop must be at least 1" % i
		if size_class.arrival_brains < 0:
			return "size class %d: arrival_brains must not be negative" % i
		if not (size_class.sprite_scale > 0.0 and is_finite(size_class.sprite_scale)):
			return "size class %d: sprite_scale must be above 0" % i
		var is_last: bool = i == size_classes.size() - 1
		if size_class.max_word_length == 0:
			if not is_last:
				return "size class %d: only the last class may have max_word_length 0" % i
		elif is_last:
			return "the last size class needs max_word_length 0, so every word length has a class"
		elif size_class.max_word_length <= last_max:
			return "size class %d: max_word_length must be ascending" % i
		else:
			last_max = size_class.max_word_length
	if not (defender_lane_time_s >= MIN_CROSSING_TIME_S and is_finite(defender_lane_time_s)):
		return "defender_lane_time_s must be at least %s" % MIN_CROSSING_TIME_S
	if not (defender_throw_cooldown_s >= MIN_CROSSING_TIME_S and is_finite(defender_throw_cooldown_s)):
		return "defender_throw_cooldown_s must be at least %s" % MIN_CROSSING_TIME_S
	if not (projectile_cross_time_s >= MIN_CROSSING_TIME_S and is_finite(projectile_cross_time_s)):
		return "projectile_cross_time_s must be at least %s" % MIN_CROSSING_TIME_S
	if not (hit_flash_s >= 0.0 and is_finite(hit_flash_s)):
		return "hit_flash_s must not be negative"
	if not (melt_s >= 0.0 and is_finite(melt_s)):
		return "melt_s must not be negative"
	# Zero is rejected (like ZombieRunConfig.dance_time_s), so the end never jumps straight to the card.
	if not (outro_time_s > 0.0 and is_finite(outro_time_s)):
		return "outro_time_s must be above 0"
	return ""
