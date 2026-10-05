extends LevelBase
## Zombie Run (Story 3.1): the player zombie walks a path of letter targets. Each correct key resolves
## the active target and scoots the zombie to the next one; a wrong key changes nothing in the world.
##
## Targets: the active one plus the next visible_upcoming stand target_spacing_px apart at fixed world
## x (targets never scroll away, the camera does). A correct key spawns one new target at the far end.
## Resolved targets stay where they are until they have scrolled off the left edge, then are freed.
##
## Camera without Camera2D: RunFrame's HUD, pause panel and countdown are plain Controls on the same
## canvas layer as %LevelHost, so a Camera2D would scroll them with the world. Instead the level
## scrolls %World, and _set_zombie_x() moves the zombie and the world in one call, so the zombie sits
## at exactly ZOMBIE_SCREEN_X every frame (no one-frame camera lag). The amble and the scoot tween both
## go through it; never tween the zombie's position directly.
##
## Randomness: the LetterBagSource owns a child RNG seeded from the run RNG (LevelBase rule); the run
## RNG is kept for the level's own draws (Story 3.2's brain-block shuffle), so a seed always replays
## the same letters.
##
## Logic leads, visuals chase: on_char_accepted() updates the index and queue synchronously and only
## then retargets the single move tween from the zombie's current position. Nothing awaits a tween,
## so walking never caps typing speed. Pause freezes it all for free (tree pause, node-bound tween).
##
## Later stories: brain blocks and brains (3.2), villagers (3.3), conga line behind the zombie (3.4),
## end dance and completion bonus (3.5), real backdrop and sprites (3.6), groans (3.7).

const TARGET_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_target.tscn")

## Layout values (UX, not GDD tuning numbers). Feet line in playfield px: characters and tags stay
## above the HUD's Caps Lock hint (y 196-224) and start prompt strip (y 228-252).
const GROUND_Y: float = 192.0
## Where the zombie stays on screen; leaves room behind it for the Story 3.4 conga line and keeps the
## queued targets clear of the pause button. Story 3.4 may retune it.
const ZOMBIE_SCREEN_X: float = 224.0
## World x of slot 0. The zombie starts one target spacing before slot 0's approach point.
const FIRST_TARGET_X: float = ZOMBIE_SCREEN_X

var _cfg: ZombieRunConfig
## The run RNG, kept for Story 3.2's level draws. Nothing draws from it yet.
var _rng: RandomNumberGenerator
var _source: LetterBagSource
## Unresolved targets, active first.
var _queue: Array[ZombieRunTarget] = []
## Resolved targets still on screen.
var _resolved: Array[ZombieRunTarget] = []
var _active_index: int = 0
var _brains: int = 0
## The zombie's single move tween; every correct key kills and restarts it.
var _move_tween: Tween

@onready var _zombie: PlayerZombie = %Zombie
@onready var _world: Node2D = %World


func _ready() -> void:
	_cfg = config as ZombieRunConfig
	if _cfg == null:
		assert(false, "ZombieRunLevel needs a ZombieRunConfig")
		Log.error(&"level", "zombie run level has no ZombieRunConfig")
		return
	_zombie.position.y = GROUND_Y
	_set_zombie_x(approach_x(0) - _cfg.target_spacing_px)


## World x of a target slot.
func target_x(slot: int) -> float:
	return FIRST_TARGET_X + slot * _cfg.target_spacing_px


## Where the zombie idles before the target in `slot`.
func approach_x(slot: int) -> float:
	return target_x(slot) - _cfg.approach_gap_px


func create_target_source(rng: RandomNumberGenerator) -> TargetSource:
	if _cfg == null:
		return null
	var problem: String = _cfg.validate()
	if problem != "":
		Log.error(&"level", "zombie run config invalid: %s" % problem)
		return null
	_rng = rng
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
	_source = LetterBagSource.new(child, _cfg.letter_pool)
	_spawn(0, _source.current())
	var upcoming: Array[String] = _source.peek(_cfg.visible_upcoming)
	for i: int in upcoming.size():
		_spawn(i + 1, upcoming[i])
	_queue[0].set_active(true)
	return _source


## The source has already advanced: current() is the new active letter and the last of
## peek(visible_upcoming) belongs to the slot spawned at the far end.
func on_char_accepted(expected: String, _index: int) -> void:
	if _queue.is_empty():
		return
	var upcoming: Array[String] = _source.peek(_cfg.visible_upcoming)
	if upcoming.is_empty():
		Log.error(&"level", "zombie run has no upcoming letter")
		return
	var done: ZombieRunTarget = _queue.pop_front()
	assert(done.get_letter() == expected, "Zombie Run queue out of step with the session")
	_active_index += 1
	_brains += done.resolve()
	_resolved.append(done)
	_spawn(_active_index + _cfg.visible_upcoming, upcoming.back())
	if not _queue.is_empty():
		_queue[0].set_active(true)
	_scoot_to(approach_x(_active_index))


## No outro yet: the end dance (2.0 s) arrives with Story 3.5.
func on_run_ending(_reason: StringName) -> float:
	return 0.0


func get_brains_earned() -> int:
	return _brains


func _process(delta: float) -> void:
	if _cfg == null:
		return
	var goal: float = approach_x(_active_index)
	var scooting: bool = _move_tween != null and _move_tween.is_running()
	if not scooting and _zombie.position.x < goal:
		_set_zombie_x(minf(_zombie.position.x + _cfg.amble_speed_px_s * delta, goal))
	if scooting or _zombie.position.x < goal:
		_zombie.play_walk()
	else:
		_zombie.play_idle()
	_free_off_screen()


func get_active_index() -> int:
	return _active_index


## Unresolved targets, active first (a copy).
func get_queue() -> Array[ZombieRunTarget]:
	return _queue.duplicate()


func get_resolved_count() -> int:
	return _resolved.size()


func get_zombie_x() -> float:
	return _zombie.position.x


## World x at the left edge of the screen.
func get_camera_x() -> float:
	return -_world.position.x


## The current move tween (null before the first key; may be finished or killed).
func get_move_tween() -> Tween:
	return _move_tween


## Moves the zombie and the camera together (see the class doc). One float argument, for tween_method.
func _set_zombie_x(x: float) -> void:
	_zombie.position.x = x
	_world.position.x = ZOMBIE_SCREEN_X - x


func _scoot_to(goal: float) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_method(_set_zombie_x, _zombie.position.x, goal, _cfg.scoot_time_s)
	_zombie.play_walk()


func _spawn(slot: int, letter: String) -> void:
	var target: ZombieRunTarget = TARGET_SCENE.instantiate() as ZombieRunTarget
	target.setup(letter, slot)
	target.position = Vector2(target_x(slot), GROUND_Y)
	%Targets.add_child(target)
	_queue.append(target)


## Frees resolved targets once they are fully past the left edge. Unresolved ones are never freed.
func _free_off_screen() -> void:
	var camera_x: float = get_camera_x()
	for i: int in range(_resolved.size() - 1, -1, -1):
		var target: ZombieRunTarget = _resolved[i]
		if target.position.x + ZombieRunTarget.HALF_WIDTH < camera_x:
			target.queue_free()
			_resolved.remove_at(i)
