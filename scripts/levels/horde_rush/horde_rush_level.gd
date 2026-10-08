extends LevelBase
## Horde Rush (Story 6.3): every completed word sends a copy of the player zombie (wearing the equipped
## hat) marching down a random lane from the left edge toward the house on the right.
##
## Field: lane_count lanes of LANE_HEIGHT_PX from FIELD_TOP_Y, above the shared HUD band. Copies are
## player_zombie.tscn instances under %Zombies (y-sorted, origin at the feet, so lower lanes draw in
## front); their HatSlot follows PlayerData by itself, so the level never touches PlayerData. A copy's
## size class (HordeRushConfig.size_class_for the word's length) sets its crossing time and its draw
## scale; scaling the copy's root scales Body and the hat together (D6).
##
## Logic leads, visuals chase: HordeField (pure) owns every copy's seconds marched. on_target_completed()
## spawns the logical marcher first and then its sprite, in the key's own call. _process() advances the
## field and sets each sprite's x from progress(); a sprite's position is never read back for gameplay.
## The tree pause (PAUSED, COUNTDOWN) stops _process, so nothing marches; after on_run_ending() the march
## is frozen where it is and no copy arrives.
##
## Randomness (LevelBase rule: children of the run RNG): words first (the WordSource's child RNG, so a
## seed keeps its words), lanes second (HordeField's child RNG, one draw per spawn). The run RNG itself is
## unused for now and reserved; Story 6.5 takes it or a third child, so the lanes never shift.
##
## Defender (Story 6.4, FR56): HordeDefender (pure, no RNG at all) paces the lanes in front of the house
## and throws projectiles that hit, flash and stop copies. It runs only from on_run_started() until
## on_run_ending(); the tree pause freezes it with everything else. Step order, every logic step:
## field.advance(dt) first (arrivals, so a copy that reaches the house in a step is safe), then
## defender.advance(dt, field) (projectiles land in throw order, then pacing and the cooldown, then at
## most one throw). _process() splits a long frame into equal steps of at most MAX_STEP_S, so a hitch
## never skips a throw or a contact, then updates every view once. A hit copy flashes for hit_flash_s; a
## stopped copy leaves the march at once and squashes into the ground over melt_s (a self-freeing
## one-shot that never gates input), earning nothing.
## Placeholders, palette only: the defender is the villager sprite, a tomato is two ColorRects (ink edge,
## pumpkin fill: stamp red is reserved, DESIGN.md D16), the flash is a hard modulate tint and the melt is
## a squash at the feet.
##
## Still to come: arrival brains, the shuffle-in and "Brainsss" in place of _on_marcher_arrived, the +25
## bonus and the outro (6.5); Farmhouse art, the Farmer, the tomato, flash and melt art, the march music
## and the throw/hit/melt sounds (6.6).

const PLAYER_ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
## Placeholder tomato (Story 6.6 draws the real one).
const TOMATO_SCENE: PackedScene = preload("res://scenes/levels/horde_rush/tomato.tscn")

## Layout values (UX, mock key-run-hud frame B, not GDD tuning numbers), in playfield px.
const FIELD_TOP_Y: float = 36.0
const LANE_HEIGHT_PX: float = 44.0
## Feet sit this far above a lane's bottom edge.
const LANE_FEET_INSET_PX: float = 6.0
## The 104 px HUD band starts here; the lanes must end above it.
const FIELD_BOTTOM_Y: float = 256.0
## Half the player zombie sprite's width at scale 1 (32 px, origin at the feet centre).
const SPRITE_HALF_WIDTH_PX: float = 16.0
const HOUSE_FRONT_X: float = 548.0
## Feet x where a small (scale 1) copy enters, fully on screen in the frame it spawns (NFR2); a larger
## copy's half-width grows with its scale, see spawn_x().
const SPAWN_X: float = SPRITE_HALF_WIDTH_PX
## Feet x where a small copy touches the house front, see arrive_x().
const ARRIVE_X: float = HOUSE_FRONT_X - SPRITE_HALF_WIDTH_PX
## Layout: the defender's feet x, in front of the house wall (mock frame B draws the farmer at 512-532).
const DEFENDER_X: float = 520.0
## Layout: a tomato flies this far above its lane's feet line (chest height).
const TOMATO_RISE_PX: float = 14.0
## Look: the hit tint. A placeholder: stamp red is reserved (DESIGN.md D16, style sheet section 5) and
## Story 6.6 owns the final red-flash effect.
const HIT_FLASH_MODULATE: Color = Color(1.0, 0.45, 0.4)
## Look: how wide a melted copy's puddle spreads, as a multiple of its class scale.
const MELT_SPREAD: float = 1.3
## Robustness, not a GDD number: the longest logic step; a longer frame is split into equal steps.
const MAX_STEP_S: float = 1.0 / 30.0

var _cfg: HordeRushConfig
var _source: WordSource
var _field: HordeField
## Sprites of the marching copies, by HordeMarcher.id.
var _views: Dictionary[int, PlayerZombie] = {}
## Set by on_run_ending(): the march stops where it is.
var _frozen: bool = false
var _defender: HordeDefender
## True from on_run_started() until on_run_ending(): the defender paces and throws only then.
var _defender_running: bool = false
## Placeholder tomatoes in the air, by HordeProjectile.id.
var _projectile_views: Dictionary[int, Node2D] = {}
## One flash tween per hit copy, by HordeMarcher.id.
var _flash_tweens: Dictionary[int, Tween] = {}
## Stopped copies still melting, with their melt tween.
var _melt_tweens: Dictionary[PlayerZombie, Tween] = {}

@onready var _zombies: Node2D = %Zombies
@onready var _projectiles: Node2D = %Projectiles
@onready var _defender_view: Node2D = %Defender


func _ready() -> void:
	_cfg = config as HordeRushConfig
	if _cfg == null:
		assert(false, "HordeRushLevel needs a HordeRushConfig")
		Log.error(&"level", "horde rush level has no HordeRushConfig")
		return
	if not _lanes_fit():
		Log.error(&"level", "horde rush: %d lanes do not fit above the HUD" % _cfg.lane_count)


func _lanes_fit() -> bool:
	return _cfg.lane_count * LANE_HEIGHT_PX <= FIELD_BOTTOM_Y - FIELD_TOP_Y


## Feet y of a copy in `lane` (0 = top).
func lane_feet_y(lane: int) -> float:
	return lane_feet_y_at(float(lane))


## Feet y at a continuous lane position (the pacing defender is between lanes most of the time).
func lane_feet_y_at(lane_pos: float) -> float:
	return FIELD_TOP_Y + LANE_HEIGHT_PX * (lane_pos + 1.0) - LANE_FEET_INSET_PX


## Feet x where a copy of draw scale `sprite_scale` enters: its whole sprite is on screen.
func spawn_x(sprite_scale: float = 1.0) -> float:
	return SPRITE_HALF_WIDTH_PX * sprite_scale


## Feet x where a copy of draw scale `sprite_scale` touches the house front (never past it).
func arrive_x(sprite_scale: float = 1.0) -> float:
	return HOUSE_FRONT_X - SPRITE_HALF_WIDTH_PX * sprite_scale


## Feet x of a copy of draw scale `sprite_scale` at `progress` (0..1) across the field.
func march_x(progress: float, sprite_scale: float = 1.0) -> float:
	return lerpf(spawn_x(sprite_scale), arrive_x(sprite_scale), progress)


## Words first, lanes second (see the class doc). An invalid config or a band with fewer than 2 words
## returns null, so RunFrame fails safely to the menu (NFR16).
func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	if _cfg == null:
		return null
	var problem: String = _cfg.validate()
	if problem != "":
		Log.error(&"level", "horde rush config invalid: %s" % problem)
		return null
	if not _lanes_fit():
		Log.error(&"level", "horde rush: %d lanes do not fit above the HUD" % _cfg.lane_count)
		return null
	_reset()
	var word_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	word_rng.seed = rng.randi()
	var lane_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	lane_rng.seed = rng.randi()
	var pool: Array[String] = WordSource.pool_from_json(_cfg.word_list, _cfg.word_min_length, _cfg.word_max_length)
	if pool.size() < 2:
		Log.error(&"level", "horde rush: only %d words in the band %d-%d" % [
			pool.size(), _cfg.word_min_length, _cfg.word_max_length])
		return null
	_source = WordSource.new(word_rng, pool)
	_field = HordeField.new(_cfg, lane_rng)
	# The defender takes no RNG, so the words and lanes of a seed never shift.
	_defender = HordeDefender.new(_cfg)
	_update_defender_view()
	return _source


## A fresh run on this node: drop every old sprite, tomato and melt, stop the defender and un-freeze.
func _reset() -> void:
	for view: PlayerZombie in _views.values():
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()
	for tween: Tween in _flash_tweens.values():
		tween.kill()
	_flash_tweens.clear()
	for view: PlayerZombie in _melt_tweens:
		_melt_tweens[view].kill()
		if is_instance_valid(view):
			view.queue_free()
	_melt_tweens.clear()
	for tomato: Node2D in _projectile_views.values():
		if is_instance_valid(tomato):
			tomato.queue_free()
	_projectile_views.clear()
	_defender_running = false
	_frozen = false


## The first correct key: the defender starts pacing.
func on_run_started() -> void:
	if _defender == null or _frozen:
		return
	_defender_running = true


## Logic first (the marcher), then its sprite, all in the key's call: no await, no tween.
func on_target_completed(target: String) -> void:
	if _field == null or _frozen:
		return
	var marcher: HordeMarcher = _field.spawn(target)
	if marcher == null:
		return
	var view: PlayerZombie = PLAYER_ZOMBIE_SCENE.instantiate() as PlayerZombie
	if view == null:
		# The marcher still marches and arrives (logic leads); only its sprite is missing.
		Log.error(&"level", "horde rush: player_zombie.tscn root is not a PlayerZombie")
		return
	var sprite_scale: float = marcher.size_class.sprite_scale
	view.position = Vector2(spawn_x(sprite_scale), lane_feet_y(marcher.lane))
	view.scale = Vector2.ONE * sprite_scale
	_zombies.add_child(view)
	view.play_walk()
	_views[marcher.id] = view


## Freezes the march, the defender and every tomato in the air where they are (nothing lands after the
## end); running flashes and melts may finish, they are visual one-shots. The outro is Story 6.5.
func on_run_ending(_reason: StringName) -> float:
	_frozen = true
	_defender_running = false
	for view: PlayerZombie in _views.values():
		view.play_idle()
	return 0.0


## Arrival brains are Story 6.5.
func get_brains_earned() -> int:
	return 0


func get_field() -> HordeField:
	return _field


## The sprite of marcher `id`; null once it has arrived or been stopped (or never existed).
func get_view(id: int) -> PlayerZombie:
	return _views.get(id) as PlayerZombie


func get_view_count() -> int:
	return _views.size()


func is_frozen() -> bool:
	return _frozen


func get_defender() -> HordeDefender:
	return _defender


func get_defender_view() -> Node2D:
	return _defender_view


func is_defender_running() -> bool:
	return _defender_running


## The placeholder tomato of projectile `id`; null once it has landed (or never existed).
func get_projectile_view(id: int) -> Node2D:
	return _projectile_views.get(id) as Node2D


func get_projectile_view_count() -> int:
	return _projectile_views.size()


## The flash tween of marcher `id` (for tests); null when it was never hit.
func get_flash_tween(id: int) -> Tween:
	return _flash_tweens.get(id) as Tween


func get_melting_count() -> int:
	return _melt_tweens.size()


## The melt tween of a stopped copy's sprite (for tests); null when it is not melting.
func get_melt_tween(view: PlayerZombie) -> Tween:
	return _melt_tweens.get(view) as Tween


func _process(delta: float) -> void:
	if _field == null or _frozen:
		return
	if not (delta > 0.0 and is_finite(delta)):
		return
	# Equal steps of at most MAX_STEP_S; the slack keeps a 0.5 s frame at 15 steps, not 16.
	var steps: int = maxi(1, ceili(delta / MAX_STEP_S - 1e-6))
	var dt: float = delta / steps
	for i: int in steps:
		_logic_step(dt)
	_update_views()


## One logic step in the fixed order (see the class doc). Never reads a sprite.
func _logic_step(dt: float) -> void:
	for marcher: HordeMarcher in _field.advance(dt):
		_on_marcher_arrived(marcher)
	if not _defender_running:
		return
	var step: HordeDefender.Step = _defender.advance(dt, _field)
	for projectile: HordeProjectile in step.thrown:
		_add_projectile_view(projectile)
	for projectile: HordeProjectile in step.landed:
		var tomato: Node2D = _projectile_views.get(projectile.id) as Node2D
		_projectile_views.erase(projectile.id)
		if tomato != null:
			tomato.queue_free()
		if projectile.hit_marcher == null:
			continue
		if projectile.stopped_marcher:
			_on_marcher_stopped(projectile.hit_marcher)
		else:
			_flash(projectile.hit_marcher)


## Every view from logic, once per frame.
func _update_views() -> void:
	for marcher: HordeMarcher in _field.get_marching():
		var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
		if view == null:
			continue
		view.position.x = march_x(marcher.progress(), marcher.size_class.sprite_scale)
		view.play_walk()
	if _defender == null:
		return
	for projectile: HordeProjectile in _defender.get_flying():
		var tomato: Node2D = _projectile_views.get(projectile.id) as Node2D
		if tomato != null:
			tomato.position = _tomato_position(projectile)
	_update_defender_view()


func _update_defender_view() -> void:
	if _defender_view == null:
		return
	var lane_pos: float = _defender.position() if _defender != null else 0.0
	_defender_view.position = Vector2(DEFENDER_X, lane_feet_y_at(lane_pos))


## Scale 1, so a tomato starts at the defender's hand (the house line) and lands inside the copy it hits.
func _tomato_position(projectile: HordeProjectile) -> Vector2:
	return Vector2(march_x(projectile.position), lane_feet_y(projectile.lane) - TOMATO_RISE_PX)


func _add_projectile_view(projectile: HordeProjectile) -> void:
	var tomato: Node2D = TOMATO_SCENE.instantiate() as Node2D
	if tomato == null:
		# The projectile still flies and lands (logic leads); only its placeholder is missing.
		Log.error(&"level", "horde rush: tomato.tscn root is not a Node2D")
		return
	tomato.position = _tomato_position(projectile)
	_projectiles.add_child(tomato)
	_projectile_views[projectile.id] = tomato


## A non-final hit: a hard tint for hit_flash_s, no fade (pixel-art rule). A new hit restarts it.
func _flash(marcher: HordeMarcher) -> void:
	var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
	if view == null or _cfg.hit_flash_s <= 0.0:
		return
	var old: Tween = _flash_tweens.get(marcher.id) as Tween
	if old != null:
		old.kill()
	view.modulate = HIT_FLASH_MODULATE
	var tween: Tween = view.create_tween()
	tween.tween_interval(_cfg.hit_flash_s)
	tween.tween_callback(view.set_modulate.bind(Color.WHITE))
	_flash_tweens[marcher.id] = tween


## The final hit: the copy leaves the march at once and melts into a puddle; it earns nothing (no sound,
## no counter). Story 6.6 replaces the squash with the melt art.
func _on_marcher_stopped(marcher: HordeMarcher) -> void:
	Log.debug(&"level", "horde rush: copy %d stopped" % marcher.id)
	var flash: Tween = _flash_tweens.get(marcher.id) as Tween
	_flash_tweens.erase(marcher.id)
	if flash != null:
		flash.kill()
	var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
	_views.erase(marcher.id)
	if view == null:
		return
	view.play_idle()
	view.modulate = Color.WHITE
	if _cfg.melt_s <= 0.0:
		view.queue_free()
		return
	# The origin is at the feet, so squashing y sinks it into the ground; x spreads into a puddle.
	var class_scale: float = marcher.size_class.sprite_scale
	var tween: Tween = view.create_tween()
	tween.tween_property(view, "scale", Vector2(class_scale * MELT_SPREAD, 0.0), _cfg.melt_s)
	tween.tween_callback(_on_melt_done.bind(view))
	_melt_tweens[view] = tween


func _on_melt_done(view: PlayerZombie) -> void:
	_melt_tweens.erase(view)
	view.queue_free()


## A copy reached the house: Story 6.3 just frees its sprite. Story 6.5 replaces this with the shuffle-in,
## "Brainsss" and the arrival brains.
func _on_marcher_arrived(marcher: HordeMarcher) -> void:
	var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
	_views.erase(marcher.id)
	if view != null:
		view.queue_free()
