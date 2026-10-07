class_name HordeRushConfig
extends LevelConfig
## Horde Rush's own tuning numbers (Story 6.3), on top of the shared LevelConfig fields. A HordeRushConfig
## is a LevelConfig, so RunFrame, TypingInput and the HUD read it unchanged. Real values live in
## data/levels/horde_rush.tres; the defaults here are neutral.

## How many lanes the field has (top lane = 0).
@export var lane_count: int = 0
## The size classes, shortest band first; the last one has max_word_length 0 (no upper bound).
@export var size_classes: Array[HordeSizeClass] = []


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
	for i: int in size_classes.size():
		var size_class: HordeSizeClass = size_classes[i]
		if size_class == null:
			return "size class %d is missing" % i
		if not (size_class.crossing_time_s > 0.0 and is_finite(size_class.crossing_time_s)):
			return "size class %d: crossing_time_s must be above 0" % i
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
	return ""
