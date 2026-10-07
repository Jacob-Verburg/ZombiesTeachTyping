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
## unused for now and reserved; Stories 6.4/6.5 take it or a third child, so the lanes never shift.
##
## Still to come: the defender, projectiles and melting (6.4); arrival brains, the shuffle-in and
## "Brainsss" in place of _on_marcher_arrived, the +25 bonus and the outro (6.5); Farmhouse art, the
## Farmer and the march music (6.6).

const PLAYER_ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/player_zombie.tscn")

## Layout values (UX, mock key-run-hud frame B, not GDD tuning numbers), in playfield px.
const FIELD_TOP_Y: float = 36.0
const LANE_HEIGHT_PX: float = 44.0
## Feet sit this far above a lane's bottom edge.
const LANE_FEET_INSET_PX: float = 6.0
## The 104 px HUD band starts here; the lanes must end above it.
const FIELD_BOTTOM_Y: float = 256.0
## Feet x where a copy enters; a small copy is fully on screen in the frame it spawns (NFR2).
const SPAWN_X: float = 16.0
const HOUSE_FRONT_X: float = 548.0
## Feet x where a copy touches the house front.
const ARRIVE_X: float = HOUSE_FRONT_X - 16.0

var _cfg: HordeRushConfig
var _source: WordSource
var _field: HordeField
## Sprites of the marching copies, by HordeMarcher.id.
var _views: Dictionary[int, PlayerZombie] = {}
## Set by on_run_ending(): the march stops where it is.
var _frozen: bool = false

@onready var _zombies: Node2D = %Zombies


func _ready() -> void:
	_cfg = config as HordeRushConfig
	if _cfg == null:
		assert(false, "HordeRushLevel needs a HordeRushConfig")
		Log.error(&"level", "horde rush level has no HordeRushConfig")
		return
	if _cfg.lane_count * LANE_HEIGHT_PX > FIELD_BOTTOM_Y - FIELD_TOP_Y:
		Log.error(&"level", "horde rush: %d lanes do not fit above the HUD" % _cfg.lane_count)


## Feet y of a copy in `lane` (0 = top).
func lane_feet_y(lane: int) -> float:
	return FIELD_TOP_Y + LANE_HEIGHT_PX * (lane + 1) - LANE_FEET_INSET_PX


## Feet x of a copy at `progress` (0..1) across the field.
func march_x(progress: float) -> float:
	return lerpf(SPAWN_X, ARRIVE_X, progress)


## Words first, lanes second (see the class doc). An invalid config or a band with fewer than 2 words
## returns null, so RunFrame fails safely to the menu (NFR16).
func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	if _cfg == null:
		return null
	var problem: String = _cfg.validate()
	if problem != "":
		Log.error(&"level", "horde rush config invalid: %s" % problem)
		return null
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
	return _source


## Logic first (the marcher), then its sprite, all in the key's call: no await, no tween.
func on_target_completed(target: String) -> void:
	if _field == null or _frozen:
		return
	var marcher: HordeMarcher = _field.spawn(target)
	if marcher == null:
		return
	var view: PlayerZombie = PLAYER_ZOMBIE_SCENE.instantiate() as PlayerZombie
	view.position = Vector2(SPAWN_X, lane_feet_y(marcher.lane))
	view.scale = Vector2.ONE * marcher.size_class.sprite_scale
	_zombies.add_child(view)
	view.play_walk()
	_views[marcher.id] = view


## Freezes the march where it is; the outro is Story 6.5.
func on_run_ending(_reason: StringName) -> float:
	_frozen = true
	for view: PlayerZombie in _views.values():
		view.play_idle()
	return 0.0


## Arrival brains are Story 6.5.
func get_brains_earned() -> int:
	return 0


func get_field() -> HordeField:
	return _field


## The sprite of marcher `id`; null once it has arrived (or never existed).
func get_view(id: int) -> PlayerZombie:
	return _views.get(id) as PlayerZombie


func get_view_count() -> int:
	return _views.size()


func is_frozen() -> bool:
	return _frozen


func _process(delta: float) -> void:
	if _field == null or _frozen:
		return
	for marcher: HordeMarcher in _field.advance(delta):
		_on_marcher_arrived(marcher)
	for marcher: HordeMarcher in _field.get_marching():
		var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
		if view == null:
			continue
		view.position.x = march_x(marcher.progress())
		view.play_walk()


## A copy reached the house: Story 6.3 just frees its sprite. Story 6.5 replaces this with the shuffle-in,
## "Brainsss" and the arrival brains.
func _on_marcher_arrived(marcher: HordeMarcher) -> void:
	var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
	_views.erase(marcher.id)
	if view != null:
		view.queue_free()
