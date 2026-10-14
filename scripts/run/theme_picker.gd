class_name ThemePicker
extends RefCounted
## Picks a level's theme for one run (Story 10.1, FR76). Pure: no nodes, no autoloads, static funcs only.
## One theme is used as is (no random draw); with two or more, the pick is uniform among those not called
## `last_id`, so a level never shows the same look twice in a row. The draw uses its own RNG built from the
## run seed (theme_rng), never the run RNG, so adding a theme can never change the targets a seed deals.


## The theme for this run, or null when `themes` holds none (null entries are skipped). One theme: that
## theme, and `rng` is not touched. More: uniform among the ids that are not `last_id` (all of them when
## `last_id` is empty, unknown, or every theme shares it).
static func pick(themes: Array[LevelTheme], last_id: StringName, rng: RandomNumberGenerator) -> LevelTheme:
	var usable: Array[LevelTheme] = []
	for theme: LevelTheme in themes:
		if theme != null:
			usable.append(theme)
	if usable.is_empty():
		return null
	if usable.size() == 1:
		return usable[0]
	var candidates: Array[LevelTheme] = []
	for theme: LevelTheme in usable:
		if theme.id != last_id:
			candidates.append(theme)
	if candidates.is_empty():
		candidates = usable
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## A fresh RNG for the theme draw, seeded from a hash of the run seed: the same seed gives the same theme
## (F2 replay), and the hash keeps the pick from mirroring the run RNG's first draw.
static func theme_rng(run_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("theme:%d" % run_seed)
	return rng
