class_name PitchforkPanicLevel
extends LevelBase
## Pitchfork Panic (Stories 8.3, 8.4, 8.5, 8.6): the chase. Every correct key moves the zombie one step away from the mob
## (ChaseModel.step(), the logical position, in the key's own call); the mob advances by run time in
## _process(). The text is a paragraph dealt exactly as in the Test text level (ParagraphSource); the level
## draws none of it.
##
## Logic leads, visuals chase: on_char_accepted() raises ChaseModel.zombie_steps first and only then
## retargets the sprite's walk tween. The gap, the catch and the mob's visibility read the model, never a
## sprite position, and the tween never gates input.
##
## Camera without Camera2D (same technique as Zombie Run): the level scrolls %World, and _set_zombie_x()
## moves the zombie, the world and the backdrop in one call, so the zombie is at zombie_screen_x_frac of the
## 640 px width every frame. Nothing else ever tweens the zombie's position, except the escape dive (below),
## where the camera stops and only the zombie node runs off into the bush.
##
## The mob (ChaseMob, Story 8.6) lives in world coordinates at mob_steps * step_px, so it scrolls with %World;
## its origin is the front member's feet and the other three trail behind within 58 px. It is drawn whenever
## the gap is under mob_visible_gap_steps, which the shipped config sets so the front member is still just
## off the left screen edge then: the whole mob, villagers with their pitchforks and torches, walks in
## together from the edge (Story 8.7, Smuck's playtest call; the 8.6 tips-only hint was removed). The mob
## runs from on_run_started() and freezes on its frame in on_run_ending().
##
## Time: _process() does nothing until on_run_started() and after on_run_ending(); the tree pause (PAUSED,
## COUNTDOWN) stops it, so the mob freezes for free. A frame is capped at MAX_FRAME_S (a longer hitch is
## dropped, never paid as a burst) and split into equal steps of at most MAX_STEP_S.
##
## Endings (Story 8.5, FR73): when the mob catches the zombie the level emits end_requested(&"caught") once.
## When RunFrame's clock reaches duration_s it asks get_timer_end_reason(), which is escaped here, and
## get_end_bonus(escaped) adds escape_bonus on top of the config's completion_bonus. The level processes
## before RunFrame (PROCESS_PRIORITY), so a catch in the clock's last frame ends the run as caught.
## on_run_ending() stops the chase, hides the pickups left on the path and starts the outro, returning its
## length: caught = a dust cloud over the zombie and the mob (caught_dust_s), the zombie sitting dazed
## (PlayerZombie.sit_dazed(); a tilt and drop only if its sheet is missing) with circling stars and "Got
## you!" (caught_dazed_s), then a fade to night on a CanvasLayer over the HUD (caught_fade_s);
## escaped = the zombie hops into a bush ahead and vanishes (escape_dive_s), then "Escaped!"
## (escape_label_s). The outro is visuals only: one node-bound tween chain, nothing awaits, the result was
## decided before it starts, and freeing the level mid-outro leaves nothing running. The mob stays where it
## froze.
##
## Brain pickups (Story 8.4, FR72): a PickupTrail places pickups by distance on the path (min to max steps
## apart). When a correct key raises zombie_steps to a pickup's step it is collected in that key's call,
## before any visual: brains grow by brains_per_pickup, brains_earned_changed carries the total to the HUD,
## and play_sfx plays sfx_brain_pickup once per pickup. Only then does the sprite walk, the pickup node pop
## (BrainPickup.collect) and new nodes get placed ahead. Nodes live in %Pickups under %World (behind the mob
## and the zombie) at step * step_px on GROUND_Y, placed _pickup_lookahead_steps() ahead of the logical
## zombie so each one exists before it scrolls in. The pop is added to %World itself, after the zombie, so
## it rises in front of it (Smuck's layout call). Nothing time-based collects anything.
##
## The look (Story 8.6, FR74): the Moonlit Village, driven by the ParallaxBackdrop script with the same
## four layers over a night Sky, plus a static Moon outside the layers (the script never moves it). The dust
## cloud, the dizzy stars and the bush are sprite sheets stepped by frames and whole px; no pixel art is
## scaled or rotated in the outros (the hop into the bush is a position tween).
##
## Randomness: the run RNG's first randi() seeds the paragraph source's child RNG (unchanged from 8.3, so a
## seed deals the same text), its second seeds the pickup trail's child RNG; after create_target_source the
## run RNG is never drawn again. The chase itself draws nothing.
##
## Sounds: the play_sfx seam (like ZombieRunLevel); _ready() points it at AudioManager.play_sfx unless a test
## assigned a recorder before add_child. sfx_brain_pickup per pickup; sfx_dust_cloud when the caught outro
## starts and sfx_escape when the escape dive starts, both inside on_run_ending()'s own call behind its
## repeat guard (once per run, never from a tween callback). RunFrame plays the chase loop from music_id.

## Feet line in playfield px, the same as Zombie Run so the HUD band stays clear. Layout, not a GDD number.
const GROUND_Y: float = 192.0
## Half the front mob member's 32 px frame: the mob's rect reaches this far ahead of its origin. Layout.
const MOB_HALF_WIDTH_PX: float = 16.0
## The playfield's width in px; the camera fraction is taken from it.
const SCREEN_W: float = 640.0
## Longest frame _process() will integrate; a longer hitch is dropped. Robustness, not a GDD number.
const MAX_FRAME_S: float = 0.5
## Longest single integration slice. Robustness, not a GDD number.
const MAX_STEP_S: float = 1.0 / 30.0
## Below RunFrame's default 0, so the mob moves and the catch is checked before RunFrame's timer each frame.
const PROCESS_PRIORITY: int = -1
## Pickup nodes are placed this many steps past the right screen edge. Layout, not a GDD number.
const PICKUP_LOOKAHEAD_MARGIN_STEPS: int = 2
const SFX_PICKUP: StringName = &"sfx_brain_pickup"
const SFX_DUST_CLOUD: StringName = &"sfx_dust_cloud"
const SFX_ESCAPE: StringName = &"sfx_escape"
const PICKUP_SCENE: PackedScene = preload("res://scenes/levels/pitchfork_panic/brain_pickup.tscn")
## The caught outro's label (EXPERIENCE.md string table).
const TEXT_CAUGHT: String = "Got you!"
## The escape outro's label (EXPERIENCE.md string table).
const TEXT_ESCAPED: String = "Escaped!"
## The bush stands this far ahead of the zombie when it escapes. Layout, not a GDD number.
const ESCAPE_BUSH_AHEAD_PX: float = 48.0
## Share of escape_dive_s spent running to the bush; for the rest the bush rustles with the zombie inside.
const ESCAPE_RUN_SHARE: float = 0.8
## Height of the hop into the bush in px (look value).
const ESCAPE_HOP_PX: float = 10.0
## The end label's top edge in playfield px. Layout, not a GDD number.
const END_LABEL_Y: float = 100.0
## The fallback dazed pose when the zombie has no dazed sheet: it tilts this many degrees and drops this many
## px. With the sheet it sits (sit_dazed()) and is never rotated.
const DAZED_TILT_DEG: float = -12.0
const DAZED_DROP_PX: float = 2.0
## The stars circle this many px above the zombie's feet: just above the dazed head (its crown is 22 px above
## the feet, the dazed anchor's row 9). Layout value.
const STARS_ABOVE_FEET_PX: float = 26.0
## Without the dazed sheet the zombie stays upright (head about 30 px up), so the stars sit higher.
const STARS_ABOVE_TILT_PX: float = 34.0

## Plays a sound effect by id. _ready() points it at AudioManager.play_sfx unless a test assigned a recorder
## before add_child.
var play_sfx: Callable

var _cfg: PitchforkPanicConfig
var _model: ChaseModel
var _paragraphs: ParagraphSource = null
var _running: bool = false
var _caught_emitted: bool = false
var _trail: PickupTrail = null
var _brains: int = 0
## Placed, uncollected pickup nodes by their step.
var _pickup_nodes: Dictionary[int, BrainPickup] = {}
## The sprite's single walk tween; every correct key kills and restarts it.
var _walk_tween: Tween
## The reason on_run_ending() was first called with (&"" before the run ends); a repeat call starts nothing.
var _ending_reason: StringName = &""
## The outro length on_run_ending() returned.
var _outro_length: float = 0.0
## The outro's node-bound tween chain (null before an outro starts).
var _outro_tween: Tween

@onready var _zombie: PlayerZombie = %Zombie
@onready var _world: Node2D = %World
@onready var _backdrop: ParallaxBackdrop = %Backdrop


func _accepts_backdrop(node: Node) -> bool:
	return node is ParallaxBackdrop
@onready var _mob: Node2D = %Mob
## The mob as a ChaseMob (null if %Mob is a plain Node2D: it still positions, it just has no run frames).
@onready var _chase_mob: ChaseMob = _mob as ChaseMob
@onready var _pickups: Node2D = %Pickups
@onready var _dust: DustCloud = %DustCloud
@onready var _stars: DizzyStars = %DizzyStars
@onready var _bush: EscapeBush = %EscapeBush
@onready var _end_label: Label = %EndLabel
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	_cfg = config as PitchforkPanicConfig
	if _cfg == null:
		Log.error(&"level", "pitchfork panic level has no PitchforkPanicConfig")
		return
	_zombie.position.y = GROUND_Y
	_mob.position.y = GROUND_Y
	_set_zombie_x(0.0)
	_mob.visible = false


## Builds the paragraph source, the chase model and the pickup trail. A broken config or no text at all returns null, so
## RunFrame fails safely to the menu (NFR16).
func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	if _cfg == null:
		return null
	var problem: String = _cfg.validate()
	if problem != "":
		Log.error(&"level", "pitchfork panic config invalid: %s" % problem)
		return null
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
	_paragraphs = ParagraphSource.for_level(child, config, tier, tier_config, used_passages)
	if _paragraphs == null:
		return null
	_pool_label = _paragraphs.get_pool_label()
	# Second draw, after the paragraph's: see the class doc. The run RNG is not kept.
	var pickup_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pickup_rng.seed = rng.randi()
	_trail = PickupTrail.new(pickup_rng, _cfg.pickup_min_steps, _cfg.pickup_max_steps)
	_brains = 0
	_clear_pickup_nodes()
	_model = ChaseModel.new(_cfg)
	_caught_emitted = false
	_fill_pickups()
	_update_views()
	return _paragraphs


## The first correct key: the mob starts its clock, and the passage being typed is saved as used.
func on_run_started() -> void:
	_running = true
	_zombie.play_idle()
	if _chase_mob != null:
		_chase_mob.run()
	if _paragraphs != null:
		used_passages_changed.emit(_paragraphs.get_used_ids())


## One correct key = one step, logic first (the step, then any pickup it reaches: brains, signal, sound),
## then the sprite chases and new pickups are placed ahead. A key judged after the run ended (the session
## still judges one in the same frame) moves and collects nothing.
func on_char_accepted(_expected: String, _index: int) -> void:
	if _model == null or not _running:
		return
	_model.step()
	_collect_pickups()
	_walk_to(_model.zombie_steps * _cfg.step_px)
	_fill_pickups()
	_update_views()


## A completed passage made the next one current (and used), so the list is handed up again.
func on_target_completed(_target: String) -> void:
	if _paragraphs != null:
		used_passages_changed.emit(_paragraphs.get_used_ids())


## Stops the chase, hides the pickups left on the path and starts the outro for `reason` (see the class
## doc). Returns its length: caught_dust_s + caught_dazed_s + caught_fade_s for caught, escape_dive_s +
## escape_label_s for escaped, 0.0 for anything else. A second call starts nothing and returns the same.
func on_run_ending(reason: StringName) -> float:
	if _ending_reason != &"":
		return _outro_length
	_running = false
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	if _chase_mob != null:
		_chase_mob.freeze()
	if _zombie != null:
		_zombie.play_idle()
	if _pickups != null:
		_pickups.visible = false
	var known: bool = reason == GameConstants.END_REASON_CAUGHT or reason == GameConstants.END_REASON_ESCAPED
	if _cfg == null or not known:
		return 0.0
	if _zombie == null or _dust == null or _stars == null or _bush == null or _end_label == null or _fade == null:
		Log.error(&"level", "pitchfork panic level is missing an outro node; skipping the outro")
		return 0.0
	_ending_reason = reason
	match reason:
		GameConstants.END_REASON_CAUGHT:
			_play_caught()
			_outro_length = _cfg.caught_dust_s + _cfg.caught_dazed_s + _cfg.caught_fade_s
		GameConstants.END_REASON_ESCAPED:
			_play_escape()
			_outro_length = _cfg.escape_dive_s + _cfg.escape_label_s
	return _outro_length


## RunFrame's clock ending the run means the zombie got away (FR73).
func get_timer_end_reason() -> StringName:
	return GameConstants.END_REASON_ESCAPED


## escape_bonus for an escaped run (FR73, +25), else 0; 0 without a config.
func get_end_bonus(reason: StringName) -> int:
	if _cfg == null or reason != GameConstants.END_REASON_ESCAPED:
		return 0
	return _cfg.escape_bonus


## The outro's tween chain, for tests (custom_step); null before an outro starts.
func get_outro_tween() -> Tween:
	return _outro_tween


## The brains from pickups collected this run.
func get_brains_earned() -> int:
	return _brains


func _process(delta: float) -> void:
	if not _running or _model == null:
		return
	if not (delta > 0.0 and is_finite(delta)):
		return
	delta = minf(delta, MAX_FRAME_S)
	# Equal steps of at most MAX_STEP_S; the slack keeps a 0.5 s frame at 15 steps, not 16.
	var steps: int = maxi(1, ceili(delta / MAX_STEP_S - 1e-6))
	var dt: float = delta / steps
	for i: int in steps:
		_model.advance(dt)
	_update_views()
	if _model.caught() and not _caught_emitted:
		_caught_emitted = true
		_running = false
		end_requested.emit(GameConstants.END_REASON_CAUGHT)


## Caught: the dust cloud covers the zombie (the mob's trailing members stand beside it), then the dazed beat, then the fade to night.
func _play_caught() -> void:
	if play_sfx.is_valid():
		play_sfx.call(SFX_DUST_CLOUD)
	_dust.position = Vector2(_zombie.position.x, GROUND_Y)
	_dust.play(_cfg.caught_dust_s)
	_outro_tween = create_tween()
	_outro_tween.tween_interval(_cfg.caught_dust_s)
	_outro_tween.tween_callback(_show_dazed)
	_outro_tween.tween_interval(_cfg.caught_dazed_s)
	_outro_tween.tween_property(_fade, "modulate:a", 1.0, _cfg.caught_fade_s)


## The dazed beat: no cloud, the zombie sitting dazed (or tilted and lowered without the sheet) with stars
## just above its head, "Got you!" above it.
func _show_dazed() -> void:
	_dust.visible = false
	if not _zombie.sit_dazed():
		_zombie.play_idle()
		_zombie.rotation_degrees = DAZED_TILT_DEG
		_zombie.position.y = GROUND_Y + DAZED_DROP_PX
	var stars_up: float = STARS_ABOVE_FEET_PX if _zombie.is_dazed() else STARS_ABOVE_TILT_PX
	_stars.position = Vector2(_zombie.position.x, GROUND_Y - stars_up)
	_stars.start()
	_show_end_label(TEXT_CAUGHT, _world.position.x + _zombie.position.x)


## Escaped: the camera stops; the zombie hops forward into the bush and vanishes, then "Escaped!".
func _play_escape() -> void:
	if play_sfx.is_valid():
		play_sfx.call(SFX_ESCAPE)
	var bush_x: float = _zombie.position.x + ESCAPE_BUSH_AHEAD_PX
	_bush.position = Vector2(bush_x, GROUND_Y)
	_bush.visible = true
	var run_s: float = _cfg.escape_dive_s * ESCAPE_RUN_SHARE
	_zombie.play_walk()
	_zombie.hop(run_s, ESCAPE_HOP_PX)
	_outro_tween = create_tween()
	_outro_tween.tween_property(_zombie, "position:x", bush_x, run_s)
	_outro_tween.tween_callback(_vanish_into_bush)
	_outro_tween.tween_interval(_cfg.escape_dive_s - run_s)
	_outro_tween.tween_callback(_show_end_label.bind(TEXT_ESCAPED, SCREEN_W / 2.0))


## The zombie reaches the bush: gone, and the bush rustles for the rest of the dive.
func _vanish_into_bush() -> void:
	_zombie.stop_hop()
	_zombie.visible = false
	_bush.rustle(_cfg.escape_dive_s * (1.0 - ESCAPE_RUN_SHARE))


## Shows `text` centred on screen x `centre_x`, kept inside the playfield.
func _show_end_label(text: String, centre_x: float) -> void:
	_end_label.text = text
	var width: float = _end_label.size.x
	_end_label.position = Vector2(clampf(centre_x - width / 2.0, 0.0, SCREEN_W - width), END_LABEL_Y)
	_end_label.visible = true


## The chase model (for tests and the headless sim); null before create_target_source succeeds.
func get_model() -> ChaseModel:
	return _model


## The pickup trail (for tests and the 8.7 sim); null before create_target_source succeeds.
func get_pickup_trail() -> PickupTrail:
	return _trail


## Where the camera keeps the zombie on screen, in px (0.0 without a config).
func get_zombie_screen_x() -> float:
	if _cfg == null:
		return 0.0
	return _cfg.zombie_screen_x_frac * SCREEN_W


## The whole mob's rect in screen px: from the back member's frame (get_back_px() behind the origin) to the
## front member's frame, 32 px tall with its feet on GROUND_Y.
func get_mob_screen_rect() -> Rect2:
	var x: float = _mob.global_position.x
	var back: float = _chase_mob.get_back_px() if _chase_mob != null else MOB_HALF_WIDTH_PX
	return Rect2(x - back, GROUND_Y - 32.0, back + MOB_HALF_WIDTH_PX, 32.0)


## Moves the zombie and the camera together (see the class doc). One float argument, for tween_method.
func _set_zombie_x(x: float) -> void:
	var screen_x: float = _cfg.zombie_screen_x_frac * SCREEN_W
	_zombie.position.x = x
	_world.position.x = screen_x - x
	if _backdrop != null:
		_backdrop.scroll_to(x - screen_x)


func _walk_to(goal: float) -> void:
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	if _cfg.step_time_s <= 0.0:
		_set_zombie_x(goal)
		_zombie.play_idle()
		return
	_walk_tween = create_tween()
	_walk_tween.tween_method(_set_zombie_x, _zombie.position.x, goal, _cfg.step_time_s)
	_walk_tween.finished.connect(_zombie.play_idle)
	_zombie.play_walk()


## Logic: takes the pickups the logical zombie has reached and pays for them in this call; then pops
## their nodes.
func _collect_pickups() -> void:
	var count: int = _trail.collect(_model.zombie_steps)
	if count <= 0:
		return
	for i: int in count:
		_brains += _cfg.brains_per_pickup
		brains_earned_changed.emit(_brains)
		if play_sfx.is_valid():
			play_sfx.call(SFX_PICKUP)
	for step: int in _pickup_nodes.keys():
		if step <= _model.zombie_steps:
			var node: BrainPickup = _pickup_nodes[step]
			_pickup_nodes.erase(step)
			if is_instance_valid(node):
				node.collect(_world)


## Places a node for every pickup up to the lookahead ahead of the logical zombie.
func _fill_pickups() -> void:
	if _trail == null or _model == null:
		return
	for step: int in _trail.fill_to(_model.zombie_steps + _pickup_lookahead_steps()):
		var node: BrainPickup = PICKUP_SCENE.instantiate() as BrainPickup
		node.position = Vector2(step * _cfg.step_px, GROUND_Y)
		_pickups.add_child(node)
		_pickup_nodes[step] = node


## Steps from the zombie to the right screen edge, plus a margin (18 with the shipped config).
func _pickup_lookahead_steps() -> int:
	return ceili((SCREEN_W - get_zombie_screen_x()) / _cfg.step_px) + PICKUP_LOOKAHEAD_MARGIN_STEPS


func _clear_pickup_nodes() -> void:
	for node: BrainPickup in _pickup_nodes.values():
		if is_instance_valid(node):
			_pickups.remove_child(node)
			node.queue_free()
	_pickup_nodes.clear()
	for pop: Node in _world.get_children():
		if pop is BrainPop:
			_world.remove_child(pop)
			pop.queue_free()


## Places the mob from the logical gap, once per frame and per key.
func _update_views() -> void:
	if _model == null or _cfg == null:
		return
	_mob.position.x = _model.mob_steps * _cfg.step_px
	_mob.visible = _model.gap() < _cfg.mob_visible_gap_steps
