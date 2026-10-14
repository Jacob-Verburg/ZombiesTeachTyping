class_name LevelBase
extends Node2D
## The level contract (ADR-1): RunFrame calls down into a level, the level signals up. Every level
## scene's root extends this; the defaults here are safe no-ops.
##
## Rules: a level never reads input, never touches the clock, never reads or writes PlayerData and never
## calls the Router. It reacts to the calls below and emits end_requested / brains_earned_changed /
## used_passages_changed.
## Used passages (Story 8.2, FR68): RunFrame hands the save's used paragraph ids down with
## set_used_passages(); a paragraph level emits used_passages_changed(ids) whenever its list changes and
## RunFrame forwards it to PlayerData, the only writer.
##
## Randomness: create_target_source() must give the source its OWN RandomNumberGenerator seeded from
## the run RNG (child.seed = rng.randi()). The level may keep the run rng for its own draws; the
## source then never interleaves with them, so a seed always replays the same targets.
##
## Themes (Story 10.1, FR76): RunFrame picks one LevelTheme per run and calls apply_theme(theme) before the
## level enters the tree. The base swaps the backdrop slot (_backdrop_slot(), default %Backdrop) for the
## theme's scene; a level with more themed parts (Horde Rush's defender) overrides apply_theme and swaps
## them with _swap_slot. A theme is art and music only: it never changes the config or the targets.
##
## Call order inside one run (all synchronous, in the key event's call stack):
##   RunFrame._ready: level instanced -> apply_theme(theme) -> added under %LevelHost (level _ready) -> set_tier(tier, config)
##     -> set_used_passages(ids) -> create_target_source(rng) -> TypingSession built -> TypingInput configured
##   first correct key: on_run_started() -> on_char_accepted(expected, 0)
##   each correct key: on_char_accepted(expected, index)
##   a word's (or paragraph's) last correct letter: on_char_accepted(expected, index) -> on_target_completed(target)
##   each wrong key: on_char_rejected(expected, typed) (also before the first correct key; never starts the run)
##   end: clock reaches duration_s (RunFrame asks get_timer_end_reason()) or end_requested(reason)
##     -> on_run_ending(reason) -> RunFrame reads get_brains_earned() and get_end_bonus(reason), builds and
##     records the RunResult -> outro wait -> report card

## Emitted by the level to end the run early (one of GameConstants.END_REASON_*). RunFrame honours
## it only while the run is RUNNING. Declared here, emitted only by subclasses.
@warning_ignore("unused_signal")
signal end_requested(reason: StringName)
## Emitted by the level whenever its brain total for this run changes (the HUD counter, Story 2.5).
@warning_ignore("unused_signal")
signal brains_earned_changed(total: int)
## Emitted by a paragraph level whenever its used passage ids change (Story 8.2): RunFrame saves them.
@warning_ignore("unused_signal")
signal used_passages_changed(ids: Array[String])

## The level's settings (duration, case and Space rules, target mode). Set in the level scene.
@export var config: LevelConfig

## The save's hidden tier (Story 7.5), set by RunFrame through set_tier(). 0 = untiered (not placed yet,
## or the level runs outside a RunFrame): the level plays as before tiers existed. A level never reads
## PlayerData (call down): this is the only way the tier reaches it.
var tier: int = 0
## The TierConfig that computed `tier` (its rows and word bands). null = untiered.
var tier_config: TierConfig = null
## The save's used paragraph ids (Story 8.2), set by RunFrame through set_used_passages(). [] outside a
## RunFrame. Only paragraph levels read it.
var used_passages: Array[String] = []
## The applied theme's id (Story 10.1), set by apply_theme(). &"" = the scene's built-in look.
var theme_id: StringName = &""


## Called once by RunFrame before the level enters the tree (so before _ready and its @onready lookups).
## A null theme changes nothing. Otherwise stores theme_id and swaps the backdrop slot for the theme's
## backdrop scene. Override to swap more slots, calling super(theme) first.
func apply_theme(theme: LevelTheme) -> void:
	if theme == null:
		return
	theme_id = theme.id
	_swap_slot(_backdrop_slot(), theme.backdrop, _accepts_backdrop)


## Whether a themed backdrop's root fits this level (a level that types its %Backdrop overrides this).
## A false answer keeps the built-in backdrop with one warning (NFR16).
func _accepts_backdrop(_node: Node) -> bool:
	return true


## The unique name of the node a theme's backdrop replaces.
func _backdrop_slot() -> StringName:
	return &"Backdrop"


## Replaces the %`slot` node with an instance of `scene`, keeping its parent, index and position, and makes
## the new node %`slot` again. A missing slot or a null scene warns once and keeps the built-in node
## (NFR16). When the slot already is an instance of `scene` (a level's single shipped theme) nothing is
## rebuilt. Only call before the level enters the tree.
func _swap_slot(slot: StringName, scene: PackedScene, accepts: Callable = Callable()) -> void:
	var old: Node = get_node_or_null("%" + String(slot))
	if old == null or scene == null:
		Log.warn(&"level", "%s: theme %s has no %s (%s), keeping the built-in look" % [
			name, theme_id, slot, "no slot" if old == null else "no scene"])
		return
	if old.scene_file_path != "" and old.scene_file_path == scene.resource_path:
		return
	var parent: Node = old.get_parent()
	var index: int = old.get_index()
	var node: Node = scene.instantiate()
	if node == null or (accepts.is_valid() and not accepts.call(node)):
		Log.warn(&"level", "%s: theme %s has a wrong %s root, keeping the built-in look" % [name, theme_id, slot])
		if node != null:
			node.free()
		return
	if old is Node2D and node is Node2D:
		(node as Node2D).position = (old as Node2D).position
	old.unique_name_in_owner = false
	parent.remove_child(old)
	old.free()
	node.name = slot
	parent.add_child(node)
	parent.move_child(node, index)
	node.owner = self
	node.unique_name_in_owner = true


## Called by RunFrame in _ready, before the session is built. Returns `config`.
func get_level_config() -> LevelConfig:
	return config


## Called once by RunFrame in _ready, after the level is in the tree and before create_target_source.
## Tier 0 or a null config leaves the level untiered.
func set_tier(p_tier: int, p_config: TierConfig) -> void:
	tier = p_tier
	tier_config = p_config


## Called once by RunFrame in _ready, after set_tier and before create_target_source. Stores a copy.
func set_used_passages(ids: Array[String]) -> void:
	used_passages = ids.duplicate()


## Read by RunFrame when it builds the RunResult (FR51): which pool the run's targets came from.
## Levels that use a tier pool override it; saved in the run record, never shown (FR60).
func get_pool_label() -> String:
	return _pool_label


## Fixed when a level builds its pool (not read live from `tier`), so a later set_tier() cannot
## relabel a run whose targets were already dealt. Levels with a tier pool set it to
## GameConstants.TIER_POOL_FORMAT % tier; the default is the untiered label.
var _pool_label: String = GameConstants.LETTER_POOL_ALL


## True when set_tier() gave a tier the config knows (1..tier_count()).
func _tier_active() -> bool:
	return tier >= 1 and tier_config != null and tier <= tier_config.tier_count()


## Called once by RunFrame in _ready. Every level must override it and return a source that owns a
## child RNG seeded from `rng` (see the class doc). The base version is a contract violation.
func create_target_source(_rng: RandomNumberGenerator) -> TargetSource:
	assert(false, "LevelBase.create_target_source() must be overridden")
	Log.error(&"level", "%s does not override create_target_source" % name)
	return null


## Called by RunFrame on the first correct key, after the clock starts and before on_char_accepted.
func on_run_started() -> void:
	pass


## Called by RunFrame for each correct key, in the same call as the key event. On the last letter of a
## target the source has already advanced, so its current() is the next target; mid-word current() is
## still the same word. `index` is 0-based and counts every accepted key of the run.
func on_char_accepted(_expected: String, _index: int) -> void:
	pass


## Called by RunFrame for each wrong key (including before the run starts).
func on_char_rejected(_expected: String, _typed: String) -> void:
	pass


## Word and paragraph targets only: called by RunFrame on a target's last correct letter, right after
## on_char_accepted, with the completed target (the source has already advanced).
func on_target_completed(_target: String) -> void:
	pass


## Called by RunFrame once when the run ends. Returns the outro length in seconds that RunFrame waits
## before the report card (0.0 = none).
func on_run_ending(_reason: StringName) -> float:
	return 0.0


## The end reason RunFrame records when the run clock reaches duration_s (or the debug F6 end). Pitchfork
## Panic returns escaped (Story 8.5). Must be one of GameConstants.END_REASON_*.
func get_timer_end_reason() -> StringName:
	return GameConstants.END_REASON_TIMER


## Bonus brains on top of LevelConfig.completion_bonus for a recorded run that ended with `reason`.
## Pitchfork Panic's Escaped! (+25, Story 8.5). Read by RunFrame when it builds the RunResult.
func get_end_bonus(_reason: StringName) -> int:
	return 0


## Read by RunFrame when it builds the RunResult: brains earned in this run, without any bonus.
func get_brains_earned() -> int:
	return 0
