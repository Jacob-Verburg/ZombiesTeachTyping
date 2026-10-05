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
## Brain blocks (Story 3.2, FR32/FR33): targets come in groups of brain_block_every, one brain block per
## group (ZombieRunGroups). Typing a block's letter adds brains_per_block to the run total, emits
## brains_earned_changed (the HUD counter), rolls the Brainsss voice line, hops the zombie and bonks the
## block, all in the same call. Other targets are generic until villagers arrive (3.3).
##
## Randomness, three uses kept apart (LevelBase rule: children of the run RNG):
## - letters: the LetterBagSource's child RNG, seeded first (unchanged from 3.1, so a seed keeps its
##   letters);
## - layout: the dealer's child RNG, seeded second, so the blocks never depend on the voice rolls;
## - the run RNG itself: only the Brainsss roll, exactly one randf() per collected brain whether or not
##   audio is unlocked or muted. AudioManager alone decides the 8 s voice spacing.
## A seed therefore replays the same letters and the same blocks (Story 2.10).
##
## Logic leads, visuals chase: on_char_accepted() updates the index, queue and brains synchronously and
## only then starts or cuts the hop and retargets the single move tween from the zombie's current
## position. Nothing awaits a tween, so walking or hopping never caps typing speed. Pause freezes it all
## for free (tree pause, node-bound tweens).
##
## Later stories: villagers (3.3), conga line behind the zombie (3.4), end dance and completion bonus
## (3.5), real backdrop and sprites (3.6), groans (3.7).

## Villager slots until Story 3.3 swaps in villager.tscn.
const TARGET_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_target.tscn")
const BRAIN_BLOCK_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/brain_block.tscn")

## Layout values (UX, not GDD tuning numbers). Feet line in playfield px: characters and tags stay
## above the HUD's Caps Lock hint (y 196-224) and start prompt strip (y 228-252).
const GROUND_Y: float = 192.0
## Where the zombie stays on screen; leaves room behind it for the Story 3.4 conga line and keeps the
## queued targets clear of the pause button. Story 3.4 may retune it.
const ZOMBIE_SCREEN_X: float = 224.0
## World x of slot 0. The zombie starts one target spacing before slot 0's approach point.
const FIRST_TARGET_X: float = ZOMBIE_SCREEN_X

## Test seam: how the level asks for a voice line. _ready() points it at AudioManager.play_voice unless
## a test assigned a recorder before add_child.
var request_voice: Callable

var _cfg: ZombieRunConfig
## The run RNG: used only for the Brainsss roll (one randf() per collected brain).
var _rng: RandomNumberGenerator
var _source: LetterBagSource
var _groups: ZombieRunGroups
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
	if not request_voice.is_valid():
		request_voice = AudioManager.play_voice
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
	# Letters first, layout second: see the class doc.
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
	_source = LetterBagSource.new(child, _cfg.letter_pool)
	var group_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	group_rng.seed = rng.randi()
	_groups = ZombieRunGroups.new(group_rng, _cfg.brain_block_every)
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
	var gained: int = done.resolve()
	if gained > 0:
		_brains += gained
		brains_earned_changed.emit(_brains)
		# Exactly one draw per collected brain, whatever the outcome or the audio state.
		if _rng.randf() < _cfg.brainsss_chance:
			request_voice.call(&"vo_brainsss")
	_resolved.append(done)
	_spawn(_active_index + _cfg.visible_upcoming, upcoming.back())
	if not _queue.is_empty():
		_queue[0].set_active(true)
	if done is BrainBlock:
		_zombie.hop(_cfg.hop_time_s, hop_height())
	_scoot_to(approach_x(_active_index))


## The hop lifts the zombie's head to the bottom of a brain block.
func hop_height() -> float:
	return maxf(0.0, _cfg.brain_block_float_px - PlayerZombie.SIZE_PX)


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
	var target: ZombieRunTarget
	if _groups.next() == ZombieRunGroups.Kind.BRAIN_BLOCK:
		var block: BrainBlock = BRAIN_BLOCK_SCENE.instantiate() as BrainBlock
		block.setup(letter, slot)
		block.configure(_cfg.brain_block_float_px, _cfg.brains_per_block)
		target = block
	else:
		target = TARGET_SCENE.instantiate() as ZombieRunTarget
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
