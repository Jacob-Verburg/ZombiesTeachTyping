class_name TierConfig
extends Resource
## The adaptive-difficulty numbers (GDD Adaptive Difficulty, FR60-FR63) that TierCalculator reads: tier
## floors, the drop margin, the rolling window, per-level WPM weighting and the levels that never count.
## The shipped values live in data/tier_config.tres; the defaults here are neutral. Story 7.2 added the
## placement level; Story 7.4 added each tier's keyboard rows and word length band (the FR62 pool table),
## which tools/tag_words.gd reads to build the tier pools and Story 7.5 reads at runtime.

## Each tier's lowest rolling-average WPM, tier 1 first (FR62: 0, 8, 15, 22, 30). Tier n is the n-th entry;
## tier 1's floor must be 0 and the floors strictly rise.
@export var tier_floors: Array[float] = []
## A tier drops only when the average falls below its floor minus this many WPM (FR63: 2).
@export var drop_margin_wpm: float = 0.0
## How many of the newest completed runs the rolling average uses (FR60: 5).
@export var window_runs: int = 0
## level_id -> multiplier applied to that level's stored WPM before averaging (GDD designer note on
## per-level WPM). A missing level counts as 1.0.
@export var level_wpm_scale: Dictionary[StringName, float] = {}
## Levels whose runs never count toward the average (the debug-only test levels).
@export var ignored_levels: Array[StringName] = []
## The level whose first completed run places a new save (FR61): that run's WPM alone sets the tier.
@export var placement_level: StringName = &""
## How many keyboard rows each tier's words may use, tier 1 first, counted in WordTagger.ROW_NAMES order
## (1 = home, 2 = home + top, 3 = all). The GDD tiers add rows cumulatively (FR62), so a count is enough.
@export var tier_row_counts: Array[int] = []
## Each tier's shortest word, tier 1 first (FR62). With tier_word_max_length it forms the tier's band.
@export var tier_word_min_length: Array[int] = []
## Each tier's longest word, tier 1 first (FR62). Tier 1 is 2-4, not the GDD's 2-3: only 21 kid-safe
## home-row words have 2-3 letters, so Smuck widened it at the Story 7.3 review gate (2026-10-08).
@export var tier_word_max_length: Array[int] = []


## How many tiers there are.
func tier_count() -> int:
	return tier_floors.size()


## The floor WPM of `tier` (1-based); 0.0 for a tier outside 1..tier_count().
func floor_of(tier: int) -> float:
	if tier < 1 or tier > tier_count():
		return 0.0
	return tier_floors[tier - 1]


## How many keyboard rows `tier` (1-based) may use; 0 for a tier outside 1..tier_count().
func row_count_of(tier: int) -> int:
	if tier < 1 or tier > tier_count() or tier > tier_row_counts.size():
		return 0
	return tier_row_counts[tier - 1]


## The word length band of `tier` (1-based) as (min, max); Vector2i.ZERO for a tier outside 1..tier_count().
func word_band_of(tier: int) -> Vector2i:
	if tier < 1 or tier > tier_count() or tier > tier_word_min_length.size() or tier > tier_word_max_length.size():
		return Vector2i.ZERO
	return Vector2i(tier_word_min_length[tier - 1], tier_word_max_length[tier - 1])


## The WPM multiplier for `level_id`; 1.0 when the level has none.
func scale_for(level_id: StringName) -> float:
	return level_wpm_scale.get(level_id, 1.0)


## Empty when the numbers can drive the tier; otherwise the first problem found.
func validate() -> String:
	if tier_count() < 2:
		return "tier_floors needs at least 2 tiers"
	if tier_floors[0] != 0.0:
		return "tier 1's floor must be 0"
	for i: int in range(1, tier_count()):
		if not (is_finite(tier_floors[i]) and tier_floors[i] > tier_floors[i - 1]):
			return "tier_floors must rise strictly (tier %d)" % (i + 1)
	if not (is_finite(drop_margin_wpm) and drop_margin_wpm >= 0.0):
		return "drop_margin_wpm must be 0 or more"
	if window_runs < 1:
		return "window_runs must be at least 1"
	for level_id: StringName in level_wpm_scale:
		var scale: float = level_wpm_scale[level_id]
		if not (is_finite(scale) and scale > 0.0):
			return "level_wpm_scale for %s must be above 0" % level_id
	for level_id: StringName in ignored_levels:
		if level_id == &"":
			return "ignored_levels has an empty id"
	if placement_level == &"":
		return "placement_level is empty"
	if placement_level in ignored_levels:
		return "placement_level %s is an ignored level" % placement_level
	if tier_row_counts.size() != tier_count():
		return "tier_row_counts needs one entry per tier"
	if tier_word_min_length.size() != tier_count():
		return "tier_word_min_length needs one entry per tier"
	if tier_word_max_length.size() != tier_count():
		return "tier_word_max_length needs one entry per tier"
	for i: int in tier_count():
		var rows: int = tier_row_counts[i]
		if rows < 1 or rows > WordTagger.ROW_NAMES.size():
			return "tier %d's row count must be 1-%d" % [i + 1, WordTagger.ROW_NAMES.size()]
		if i > 0 and rows < tier_row_counts[i - 1]:
			return "tier %d's row count must not fall below tier %d's" % [i + 1, i]
		var min_len: int = tier_word_min_length[i]
		var max_len: int = tier_word_max_length[i]
		if min_len < WordTagger.MIN_LENGTH or max_len > WordTagger.MAX_LENGTH or min_len > max_len:
			return "tier %d's word band must be within %d-%d with min <= max" % [i + 1,
					WordTagger.MIN_LENGTH, WordTagger.MAX_LENGTH]
		if i > 0 and (min_len < tier_word_min_length[i - 1] or max_len < tier_word_max_length[i - 1]):
			return "tier %d's word band must not fall below tier %d's" % [i + 1, i]
	return ""
