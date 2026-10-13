class_name PitchforkPanicLevel
extends LevelBase
## Pitchfork Panic (Story 8.3): the chase. Every correct key moves the zombie one step away from the mob
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
## 640 px width every frame. Nothing else ever tweens the zombie's position.
##
## The mob lives in world coordinates at mob_steps * step_px, so it scrolls with %World. It is on screen
## whenever the gap is under mob_visible_gap_steps; otherwise %MobGlow, a strip on the left edge, warns that
## it is coming (a left-to-right orange gradient whose alpha rises as the gap falls).
##
## Time: _process() does nothing until on_run_started() and after on_run_ending(); the tree pause (PAUSED,
## COUNTDOWN) stops it, so the mob freezes for free. A frame is capped at MAX_FRAME_S (a longer hitch is
## dropped, never paid as a burst) and split into equal steps of at most MAX_STEP_S.
##
## Interim endings (replaced by Story 8.5): when the mob catches the zombie the level emits
## end_requested(&"caught") once and on_run_ending() returns 0.0 (no outro). A run that reaches duration_s
## still ends through RunFrame's timer. The level processes before RunFrame (PROCESS_PRIORITY), so a catch
## in the timer's last frame ends the run as caught, not timer. No brains yet (Story 8.4):
## get_brains_earned() is 0.
##
## Placeholder art (replaced by Story 8.6): Sunny Village Green as the backdrop, the mob is one dark
## villager frame with an orange torch. No new art files.
##
## Randomness: the paragraph source gets its own child RNG; the chase itself draws nothing, so a seed
## replays the same text.

## Feet line in playfield px, the same as Zombie Run so the HUD band stays clear. Layout, not a GDD number.
const GROUND_Y: float = 192.0
## Half the placeholder mob's width (one villager-size figure). Layout, not a GDD number.
const MOB_HALF_WIDTH_PX: float = 16.0
## The playfield's width in px; the camera fraction is taken from it.
const SCREEN_W: float = 640.0
## Longest frame _process() will integrate; a longer hitch is dropped. Robustness, not a GDD number.
const MAX_FRAME_S: float = 0.5
## Longest single integration slice. Robustness, not a GDD number.
const MAX_STEP_S: float = 1.0 / 30.0
## The glow starts this many steps out and reaches full strength at mob_visible_gap_steps (look values).
const GLOW_START_GAP_STEPS: float = 32.0
## The glow's strongest alpha (look value).
const GLOW_MAX_ALPHA: float = 0.6
## Below RunFrame's default 0, so the mob moves and the catch is checked before RunFrame's timer each frame.
const PROCESS_PRIORITY: int = -1

var _cfg: PitchforkPanicConfig
var _model: ChaseModel
var _paragraphs: ParagraphSource = null
var _running: bool = false
var _caught_emitted: bool = false
## The sprite's single walk tween; every correct key kills and restarts it.
var _walk_tween: Tween

@onready var _zombie: PlayerZombie = %Zombie
@onready var _world: Node2D = %World
@onready var _backdrop: SunnyVillageBackdrop = %Backdrop
@onready var _mob: Node2D = %Mob
@onready var _glow: TextureRect = %MobGlow


func _ready() -> void:
	process_priority = PROCESS_PRIORITY
	_cfg = config as PitchforkPanicConfig
	if _cfg == null:
		Log.error(&"level", "pitchfork panic level has no PitchforkPanicConfig")
		return
	_zombie.position.y = GROUND_Y
	_mob.position.y = GROUND_Y
	_set_zombie_x(0.0)
	_mob.visible = false


## Builds the paragraph source and the chase model. A broken config or no text at all returns null, so
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
	_model = ChaseModel.new(_cfg)
	_caught_emitted = false
	_update_views()
	return _paragraphs


## The first correct key: the mob starts its clock, and the passage being typed is saved as used.
func on_run_started() -> void:
	_running = true
	_zombie.play_idle()
	if _paragraphs != null:
		used_passages_changed.emit(_paragraphs.get_used_ids())


## One correct key = one step, logic first, then the sprite chases. A key judged after the run ended
## (the session still judges one in the same frame) moves nothing.
func on_char_accepted(_expected: String, _index: int) -> void:
	if _model == null or not _running:
		return
	_model.step()
	_walk_to(_model.zombie_steps * _cfg.step_px)
	_update_views()


## A completed passage made the next one current (and used), so the list is handed up again.
func on_target_completed(_target: String) -> void:
	if _paragraphs != null:
		used_passages_changed.emit(_paragraphs.get_used_ids())


## Interim ending (Story 8.5 replaces it): the camera stays put, the zombie idles, no outro.
func on_run_ending(_reason: StringName) -> float:
	_running = false
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	if _zombie != null:
		_zombie.play_idle()
	return 0.0


## No brains until Story 8.4.
func get_brains_earned() -> int:
	return 0


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


## The chase model (for tests and the headless sim); null before create_target_source succeeds.
func get_model() -> ChaseModel:
	return _model


## Where the camera keeps the zombie on screen, in px (0.0 without a config).
func get_zombie_screen_x() -> float:
	if _cfg == null:
		return 0.0
	return _cfg.zombie_screen_x_frac * SCREEN_W


## The mob's rect in screen px (the placeholder figure's width, its feet on GROUND_Y).
func get_mob_screen_rect() -> Rect2:
	var x: float = _mob.global_position.x
	return Rect2(x - MOB_HALF_WIDTH_PX, GROUND_Y - 32.0, MOB_HALF_WIDTH_PX * 2.0, 32.0)


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


## Places the mob and the glow from the logical gap, once per frame and per key.
func _update_views() -> void:
	if _model == null or _cfg == null:
		return
	_mob.position.x = _model.mob_steps * _cfg.step_px
	var gap: float = _model.gap()
	var mob_visible: bool = gap < _cfg.mob_visible_gap_steps
	_mob.visible = mob_visible
	_glow.visible = not mob_visible
	if not mob_visible:
		var span: float = maxf(GLOW_START_GAP_STEPS - _cfg.mob_visible_gap_steps, 0.001)
		var strength: float = clampf((GLOW_START_GAP_STEPS - gap) / span, 0.0, 1.0)
		_glow.modulate.a = strength * GLOW_MAX_ALPHA
