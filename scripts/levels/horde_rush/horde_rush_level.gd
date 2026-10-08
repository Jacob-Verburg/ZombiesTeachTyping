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
## is frozen where it is and no copy arrives (so nothing pays after the end).
##
## Randomness (LevelBase rule: children of the run RNG): words first (the WordSource's child RNG, so a
## seed keeps its words), lanes second (HordeField's child RNG, one draw per spawn). The run RNG itself is
## unused (6.5's Brainsss has no roll; AudioManager's voice gap throttles it).
##
## Defender (Story 6.4, FR56): HordeDefender (pure, no RNG at all) paces the lanes in front of the house
## and throws projectiles that hit, flash and stop copies. It runs only from on_run_started() until
## on_run_ending(); the tree pause freezes it with everything else. Step order, every logic step:
## field.advance(dt) first (arrivals, so a copy that reaches the house in a step is safe), then
## defender.advance(dt, field) (projectiles land in throw order, then pacing and the cooldown, then at
## most one throw). _process() caps a frame at MAX_FRAME_S (a longer hitch is dropped, so it can never pay
## a burst of brains or run hundreds of steps) and splits it into equal steps of at most MAX_STEP_S, so a
## hitch never skips a throw or a contact, then updates every view once. A hit copy flashes for hit_flash_s; a
## stopped copy leaves the march at once and melts into a puddle over melt_s (a self-freeing one-shot that
## never gates input), earning nothing.
##
## Arrivals (Story 6.5, FR57): a copy HordeField returns as arrived pays its class's arrival_brains to the
## run total in the same logic step, before any visual; a paying arrival emits brains_earned_changed (the
## HUD counter, through RunFrame) and every arrival asks for "Brainsss" through request_voice (no roll:
## AudioManager's voice gap is the throttle). Then the visuals chase: the copy's sprite leaves the march,
## shuffles into the house (a self-freeing one-shot) and a "+N" brain pop rises from the house front.
## The outro: on_run_ending() freezes everything, clears the tomatoes in the air and makes every marching
## copy dance for outro_time_s, which RunFrame waits before the report card. The +25 completion bonus is
## horde_rush.tres's completion_bonus, which RunFrame adds (never on quit).
## The shuffle is a slide and an edge-on squash into the copy's own lane's doorway; the pop is the shared brain.
##
## The art (Story 6.6, docs/art-style-sheet.md): %Field holds two static layers, field.png (the sky band and
## five baked soil lanes, so a lane_count change needs new field art) and farmhouse.png at HOUSE_FRONT_X,
## whose field edge has a doorway per lane on that lane's feet line. The defender is the Farmer
## (HordeFarmer): idle before the first key and after the end, walking while he paces, a one-shot throw on
## every throw, all from logic. A tomato is the tomato_fly sheet; every hit (non-final or final) spawns a
## self-freeing HordeTomatoSplat under %Effects at the landing point; a non-final hit swaps the copy's
## walk for its flash frames (the walk recoloured, PlayerZombie.set_flashing) for hit_flash_s; a final
## hit plays the copy's melt frames over melt_s (PlayerZombie.melt) and then frees it. Stamp red is
## reserved (DESIGN.md D16): the tomato and the flash are pumpkin.
##
## Sounds (Story 6.6): the march is RunFrame's (horde_rush.tres music_id). Through the play_sfx seam:
## sfx_zombie_spawn per spawned copy (in the key's call), sfx_tomato_throw per throw, sfx_tomato_hit per
## non-final hit and sfx_melt per final hit (no hit sound on top), all in the logic step that resolves them,
## never from a tween, never after on_run_ending(), no RNG (AudioManager throttles the bursts).
##
## Still to come: tuning, economy parity and the stress check (6.7); unlocks (6.8); the Castle + Knight
## and Beach Hut + Lifeguard pairs (Epic 10).

const PLAYER_ZOMBIE_SCENE: PackedScene = preload("res://scenes/characters/player_zombie.tscn")
const TOMATO_SCENE: PackedScene = preload("res://scenes/levels/horde_rush/tomato.tscn")
const TOMATO_SPLAT_SCENE: PackedScene = preload("res://scenes/levels/horde_rush/tomato_splat.tscn")
## The "+N" brain pop over the house front.
const ARRIVAL_POP_SCENE: PackedScene = preload("res://scenes/levels/horde_rush/arrival_pop.tscn")
## Sound ids (data/audio/audio_library.tres). The tomato ones belong to the Farmhouse pair (Epic 10 adds
## its own per pair); the spawn and the melt are pair-independent.
const SFX_SPAWN: StringName = &"sfx_zombie_spawn"
const SFX_THROW: StringName = &"sfx_tomato_throw"
const SFX_HIT: StringName = &"sfx_tomato_hit"
const SFX_MELT: StringName = &"sfx_melt"

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
## Look, the fallback only (a copy without melt frames, NFR16): how wide its squashed puddle spreads, as
## a multiple of its class scale.
const MELT_SPREAD: float = 1.3
## Robustness, not a GDD number: the longest logic step; a longer frame is split into equal steps.
const MAX_STEP_S: float = 1.0 / 30.0
## Robustness, not a GDD number: a hitch longer than this is dropped: the field falls a little behind
## RunClock, invisible, and no burst of brains. 0.5 s is exactly 15 steps.
const MAX_FRAME_S: float = 0.5
## Look values (not GDD numbers; Story 6.6 may replace them): an arriving copy slides this far into the
## door while it squashes edge-on, over this long.
const SHUFFLE_S: float = 0.3
const SHUFFLE_PX: float = 8.0
## Layout: the highest a pop may start (its origin is the brain's bottom), so a big copy's pop in lane 0
## stays on screen after it rises (16 px brain + HordeArrivalPop.RISE_PX).
const POP_MIN_Y: float = 32.0

## Test seam: how the level asks for a voice line. _ready() points it at AudioManager.play_voice unless
## a test assigned a recorder before add_child.
var request_voice: Callable
## Test seam (Story 6.6): how the level plays sound effects (spawn, throw, hit, melt). _ready() points it at
## AudioManager.play_sfx unless a test assigned a recorder before add_child.
var play_sfx: Callable

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
## Tomatoes in the air, by HordeProjectile.id.
var _projectile_views: Dictionary[int, Node2D] = {}
## One flash tween per hit copy, by HordeMarcher.id.
var _flash_tweens: Dictionary[int, Tween] = {}
## Stopped copies still melting, with their melt tween.
var _melt_tweens: Dictionary[PlayerZombie, Tween] = {}
## Arrived copies still shuffling into the house, with their shuffle tween.
var _shuffle_tweens: Dictionary[PlayerZombie, Tween] = {}
## The logical run total of arrival brains (FR57).
var _brains: int = 0

@onready var _zombies: Node2D = %Zombies
@onready var _projectiles: Node2D = %Projectiles
@onready var _defender_view: Node2D = %Defender
@onready var _effects: Node2D = %Effects
## The defender view as the Farmer; null when %Defender is some other node (it still moves, it just does
## not animate).
@onready var _farmer: HordeFarmer = _defender_view as HordeFarmer


func _ready() -> void:
	if not request_voice.is_valid():
		request_voice = AudioManager.play_voice
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
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


## A fresh run on this node: drop every old sprite, tomato, melt, shuffle and pop, stop the defender,
## zero the brains and un-freeze.
func _reset() -> void:
	for view: PlayerZombie in _views.values():
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()
	for tween: Tween in _flash_tweens.values():
		tween.kill()
	_flash_tweens.clear()
	for view: Variant in _melt_tweens:
		_melt_tweens[view].kill()
		if is_instance_valid(view):
			(view as PlayerZombie).queue_free()
	_melt_tweens.clear()
	for view: Variant in _shuffle_tweens:
		_shuffle_tweens[view].kill()
		if is_instance_valid(view):
			(view as PlayerZombie).queue_free()
	_shuffle_tweens.clear()
	if _effects != null:
		for effect: Node in _effects.get_children():
			effect.queue_free()
	for tomato: Node2D in _projectile_views.values():
		if is_instance_valid(tomato):
			tomato.queue_free()
	_projectile_views.clear()
	_defender_running = false
	_frozen = false
	_brains = 0


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
	# The copy exists from here (logic leads), with or without its sprite.
	_play_sfx(SFX_SPAWN)
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


## The outro (FR57): freezes the march and the defender where they are (nothing lands or arrives after the
## end), removes the tomatoes in the air (a frozen tomato looks broken) and makes every marching copy dance
## in place; running melts and shuffles may finish, they are visual one-shots. Returns outro_time_s, the
## seconds RunFrame waits before the report card; a second call changes nothing.
func on_run_ending(_reason: StringName) -> float:
	if _cfg == null:
		return 0.0
	if _frozen:
		return _cfg.outro_time_s
	_frozen = true
	_defender_running = false
	# The defender's logical projectiles stay as they are: nothing advances them any more.
	for tomato: Node2D in _projectile_views.values():
		if is_instance_valid(tomato):
			tomato.queue_free()
	_projectile_views.clear()
	for id: int in _views:
		var flash: Tween = _flash_tweens.get(id) as Tween
		if flash != null:
			flash.kill()
		var view: PlayerZombie = _views[id]
		if not is_instance_valid(view):
			continue
		view.set_flashing(false)
		view.dance(_cfg.outro_time_s)
	_flash_tweens.clear()
	if _farmer != null:
		_farmer.play_idle()
	return _cfg.outro_time_s


## The arrival brains of this run so far (FR57); stopped copies add nothing.
func get_brains_earned() -> int:
	return _brains


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


## The tomato view of projectile `id`; null once it has landed (or never existed).
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


func get_shuffling_count() -> int:
	return _shuffle_tweens.size()


## The shuffle tween of an arrived copy's sprite (for tests); null when it is not shuffling in.
func get_shuffle_tween(view: PlayerZombie) -> Tween:
	return _shuffle_tweens.get(view) as Tween


func _process(delta: float) -> void:
	if _field == null or _frozen:
		return
	if not (delta > 0.0 and is_finite(delta)):
		return
	delta = minf(delta, MAX_FRAME_S)
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
		if _farmer != null:
			_farmer.play_throw()
		_play_sfx(SFX_THROW)
	for projectile: HordeProjectile in step.landed:
		var tomato: Node2D = _projectile_views.get(projectile.id) as Node2D
		_projectile_views.erase(projectile.id)
		if tomato != null:
			tomato.queue_free()
		if projectile.hit_marcher == null:
			continue
		_spawn_splat(_tomato_position(projectile))
		if projectile.stopped_marcher:
			_play_sfx(SFX_MELT)
			_on_marcher_stopped(projectile.hit_marcher)
		else:
			_play_sfx(SFX_HIT)
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
	if _farmer != null:
		if _defender_running:
			_farmer.play_walk()
		else:
			_farmer.play_idle()


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
		# The projectile still flies and lands (logic leads); only its sprite is missing.
		Log.error(&"level", "horde rush: tomato.tscn root is not a Node2D")
		return
	tomato.position = _tomato_position(projectile)
	_projectiles.add_child(tomato)
	_projectile_views[projectile.id] = tomato


## A tomato landed on a copy at `at`: a self-freeing splat under %Effects (it never gates anything).
func _spawn_splat(at: Vector2) -> void:
	if _effects == null:
		return
	var splat: Node2D = TOMATO_SPLAT_SCENE.instantiate() as Node2D
	if splat == null:
		Log.error(&"level", "horde rush: tomato_splat.tscn root is not a Node2D")
		return
	splat.position = at
	_effects.add_child(splat)


## A non-final hit: the copy's walk shows its flash frames for hit_flash_s (no tint, no fade: pixel-art
## rule). A new hit restarts it.
func _flash(marcher: HordeMarcher) -> void:
	var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
	if view == null or _cfg.hit_flash_s <= 0.0:
		return
	var old: Tween = _flash_tweens.get(marcher.id) as Tween
	if old != null:
		old.kill()
	view.set_flashing(true)
	var tween: Tween = view.create_tween()
	tween.tween_interval(_cfg.hit_flash_s)
	tween.tween_callback(view.set_flashing.bind(false))
	_flash_tweens[marcher.id] = tween


## The final hit: the copy leaves the march at once and melts into a puddle (its melt frames over melt_s);
## it earns nothing (no counter). Its sfx_melt is played by the logic step that resolved the hit.
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
	view.set_flashing(false)
	if _cfg.melt_s <= 0.0:
		view.queue_free()
		return
	# The class scale stays on the copy; the sheet does the melting.
	var tween: Tween = view.melt(_cfg.melt_s)
	if tween == null:
		# No melt frames (NFR16): squash at the feet instead; the origin is at the feet, so squashing y
		# sinks it into the ground and x spreads into a puddle.
		view.play_idle()
		var class_scale: float = marcher.size_class.sprite_scale
		tween = view.create_tween()
		tween.tween_property(view, "scale", Vector2(class_scale * MELT_SPREAD, 0.0), _cfg.melt_s)
	tween.tween_callback(_on_melt_done.bind(view))
	_melt_tweens[view] = tween


func _on_melt_done(view: PlayerZombie) -> void:
	_melt_tweens.erase(view)
	view.queue_free()


## A copy reached the house (called only from _logic_step). Logic first: its class's brains go to the run
## total and the HUD hears of it; every arrival asks for "Brainsss". Then the visuals chase: the sprite
## leaves the march and shuffles in, and a "+N" pop rises. A copy without a sprite still pays.
func _on_marcher_arrived(marcher: HordeMarcher) -> void:
	var gained: int = marcher.size_class.arrival_brains
	if gained > 0:
		_brains += gained
		brains_earned_changed.emit(_brains)
	Log.debug(&"level", "horde rush: copy %d arrived, +%d brains" % [marcher.id, gained])
	if request_voice.is_valid():
		request_voice.call(&"vo_brainsss")
	var view: PlayerZombie = _views.get(marcher.id) as PlayerZombie
	_views.erase(marcher.id)
	var flash: Tween = _flash_tweens.get(marcher.id) as Tween
	_flash_tweens.erase(marcher.id)
	if flash != null:
		flash.kill()
	_spawn_pop(marcher, gained)
	if view != null:
		# The sprite was last placed a frame ago; the copy has reached the house, so it steps in from there.
		view.position.x = arrive_x(marcher.size_class.sprite_scale)
		_shuffle_in(view)


## The copy steps through the door: it slides SHUFFLE_PX right while squashing edge-on, then is freed. No
## fade (pixel-art rule); it never gates input or logic.
func _shuffle_in(view: PlayerZombie) -> void:
	view.set_flashing(false)
	view.play_walk()
	var tween: Tween = view.create_tween().set_parallel()
	tween.tween_property(view, "position:x", view.position.x + SHUFFLE_PX, SHUFFLE_S)
	tween.tween_property(view, "scale:x", 0.0, SHUFFLE_S)
	tween.chain().tween_callback(_on_shuffle_done.bind(view))
	_shuffle_tweens[view] = tween


func _on_shuffle_done(view: PlayerZombie) -> void:
	_shuffle_tweens.erase(view)
	if is_instance_valid(view):
		view.queue_free()


## Plays sound `id` through the seam (bound in _ready, or a test's recorder).
func _play_sfx(id: StringName) -> void:
	if play_sfx.is_valid():
		play_sfx.call(id)


## The "+N" pop above the arrived copy's head at the house front; none when it paid nothing.
func _spawn_pop(marcher: HordeMarcher, gained: int) -> void:
	if gained <= 0 or _effects == null:
		return
	var pop: HordeArrivalPop = ARRIVAL_POP_SCENE.instantiate() as HordeArrivalPop
	if pop == null:
		Log.error(&"level", "horde rush: arrival_pop.tscn root is not a HordeArrivalPop")
		return
	var sprite_scale: float = marcher.size_class.sprite_scale
	pop.setup(gained)
	var head_y: float = lane_feet_y(marcher.lane) - PlayerZombie.SIZE_PX * sprite_scale
	pop.position = Vector2(arrive_x(sprite_scale), maxf(head_y, POP_MIN_Y))
	_effects.add_child(pop)
