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
## block, all in the same call.
##
## Villagers (Story 3.3, FR34): the other slots of each group. Typing a villager's letter hugs it (0
## brains, no signal, no roll) and starts the zombie's hug; the villager poofs and leaves a party-hat
## zombie on its own timer. Any correct key cuts a running hug (the zombie's tween only, never the
## villager's sequence). The hug moves Body on x and the hop on y, so they never fight: a villager key
## during a hop lets the hop finish, and a block key during a hug cuts the hug and hops.
##
## Randomness, three uses kept apart (LevelBase rule: children of the run RNG):
## - letters: the LetterBagSource's child RNG, seeded first (unchanged from 3.1, so a seed keeps its
##   letters);
## - layout: the dealer's child RNG, seeded second, so the blocks never depend on the voice rolls;
## - the run RNG itself: only the Brainsss roll, exactly one randf() per collected brain whether or not
##   audio is unlocked or muted. AudioManager alone decides the 8 s voice spacing. Villagers draw nothing
##   from any RNG, so it still has exactly one consumer.
## A seed therefore replays the same letters and the same blocks (Story 2.10).
##
## Conga line (Story 3.4, FR35): _conga_count is the logical count, +1 in the same on_char_accepted call
## that resolves a villager (before any visuals). %CongaLine is the view: when
## a villager's poof ends (Villager.poofed), the level hides that villager's party zombie and the line
## instances its own follower at the same spot, so the line's joined count catches up with the logical
## count. _free_off_screen() keeps a villager until that hand-off, so every hugged villager joins even at
## high speed. The cap is ZombieRunConfig.conga_max_drawn (beyond it a ×N badge). Neither count ever
## goes down, and the line draws nothing from any RNG.
##
## Logic leads, visuals chase: on_char_accepted() updates the index, queue and brains synchronously and
## only then starts or cuts the hug and hop and retargets the single move tween from the zombie's current
## position. Nothing awaits a tween, so walking, hopping or hugging never caps typing speed. Pause freezes it all
## for free (tree pause, node-bound tweens).
##
## End dance (Story 3.5, FR36): on_run_ending() kills the scoot where it is (the camera stays put), stops
## the amble and the walk/idle switching in _process, and starts the zombie's dance and the conga line's
## dance; RunFrame waits the returned dance_time_s before the report card. No key is judged after that, so
## on_char_accepted needs no guard. The dance draws nothing from any RNG; the completion bonus is
## RunFrame's.
##
## Backdrop (Story 3.6, FR37): %Backdrop (SunnyVillageBackdrop) sits outside %World and scrolls its
## parallax layers from the camera x; _set_zombie_x() calls its scroll_to() in the same call that moves
## the world, so the backdrop, the world and the zombie never drift apart (the ground layer moves exactly
## with the world). It draws nothing from any RNG.
##
## Sounds (Story 5.1): the play_sfx seam plays sfx_brain_bonk in the same call that resolves a brain
## block, and each villager gets the seam in _spawn() to play sfx_hug_poof when its poof starts (with the
## cloud, not the key). Neither touches the run RNG; the Zombie Run music is RunFrame's (LevelConfig.music_id).

## The non-block slots (Story 3.3). The generic zombie_run_target.tscn stays the base and test fixture.
const VILLAGER_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/villager.tscn")
const BRAIN_BLOCK_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/brain_block.tscn")

## Layout values (UX, not GDD tuning numbers). Feet line in playfield px: characters and tags stay
## above the HUD's Caps Lock hint (y 196-224) and start prompt strip (y 228-252).
const GROUND_Y: float = 192.0
## Where the zombie stays on screen; fits the full conga line (conga_max_drawn × CongaLine.SPACING_PX)
## plus its badge behind the zombie and keeps the queued targets clear of the pause button.
const ZOMBIE_SCREEN_X: float = 224.0
## World x of slot 0. The zombie starts one target spacing before slot 0's approach point.
const FIRST_TARGET_X: float = ZOMBIE_SCREEN_X

## Test seam: how the level asks for a voice line. _ready() points it at AudioManager.play_voice unless
## a test assigned a recorder before add_child.
var request_voice: Callable
## Test seam (Story 5.1): how the level and its villagers play sound effects (the bonk on a brain block, the
## hug-poof). _ready() points it at AudioManager.play_sfx unless a test assigned a recorder before add_child.
var play_sfx: Callable

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
## Logical conga count: villagers resolved this run (Story 3.4). Never goes down.
var _conga_count: int = 0
## The zombie's single move tween; every correct key kills and restarts it.
var _move_tween: Tween
## Set by on_run_ending(): the zombie stays put and dances.
var _dancing: bool = false

@onready var _zombie: PlayerZombie = %Zombie
@onready var _world: Node2D = %World
@onready var _conga: CongaLine = %CongaLine
@onready var _backdrop: SunnyVillageBackdrop = %Backdrop


func _ready() -> void:
	if not request_voice.is_valid():
		request_voice = AudioManager.play_voice
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	_cfg = config as ZombieRunConfig
	if _cfg == null:
		assert(false, "ZombieRunLevel needs a ZombieRunConfig")
		Log.error(&"level", "zombie run level has no ZombieRunConfig")
		return
	_zombie.position.y = GROUND_Y
	_conga.position.y = GROUND_Y
	_conga.configure(_zombie, _cfg.conga_max_drawn)
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
	if done is Villager:
		_conga_count += 1
	_resolved.append(done)
	_spawn(_active_index + _cfg.visible_upcoming, upcoming.back())
	if not _queue.is_empty():
		_queue[0].set_active(true)
	# A block key cuts a running hug; a villager key restarts it from the current lean.
	if done is BrainBlock:
		if play_sfx.is_valid():
			play_sfx.call(&"sfx_brain_bonk")
		_zombie.stop_hug()
		_zombie.hop(_cfg.hop_time_s, hop_height())
	elif done is Villager:
		_zombie.hug(_cfg.hug_time_s)
	_scoot_to(approach_x(_active_index))


## The hop lifts the zombie's head to the bottom of a brain block.
func hop_height() -> float:
	return maxf(0.0, _cfg.brain_block_float_px - PlayerZombie.SIZE_PX)


## The end dance (Story 3.5, FR36): stops the zombie where it is and starts the zombie's and the line's
## dance; RunFrame waits the returned dance time before the report card.
func on_run_ending(_reason: StringName) -> float:
	if _cfg == null:
		return 0.0
	if _dancing:
		return _cfg.dance_time_s
	_dancing = true
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_zombie.dance(_cfg.dance_time_s)
	_conga.dance()
	return _cfg.dance_time_s


## True once the end dance has started.
func is_dancing() -> bool:
	return _dancing


func get_brains_earned() -> int:
	return _brains


## Villagers resolved this run (the logical conga count).
func get_conga_count() -> int:
	return _conga_count


func get_conga_line() -> CongaLine:
	return _conga


func _process(delta: float) -> void:
	if _cfg == null:
		return
	if _dancing:
		_free_off_screen()
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
	if _backdrop != null:
		_backdrop.scroll_to(x - ZOMBIE_SCREEN_X)


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
		var villager: Villager = VILLAGER_SCENE.instantiate() as Villager
		villager.setup(letter, slot)
		villager.configure(_cfg.hug_time_s)
		# The hug-poof sound goes with the visible poof, so the villager plays it (Story 5.1).
		villager.play_sfx = play_sfx
		villager.poofed.connect(_on_villager_poofed)
		target = villager
	target.position = Vector2(target_x(slot), GROUND_Y)
	%Targets.add_child(target)
	_queue.append(target)


## Hands a poofed villager's party zombie to the conga line: the line instances its own follower at the
## same world spot and the villager's copy hides, so nothing visibly jumps.
func _on_villager_poofed(party_zombie: PartyZombie) -> void:
	var x: float = _conga.to_local(party_zombie.global_position).x
	party_zombie.hide()
	_conga.join(x)


## Frees resolved targets once they are fully past the left edge. Unresolved ones are never freed, nor
## is a villager whose poof has not handed its party zombie to the conga line yet (a later pass frees it).
func _free_off_screen() -> void:
	var camera_x: float = get_camera_x()
	for i: int in range(_resolved.size() - 1, -1, -1):
		var target: ZombieRunTarget = _resolved[i]
		if target is Villager and not (target as Villager).is_party_zombie_shown():
			continue
		if target.position.x + ZombieRunTarget.HALF_WIDTH < camera_x:
			target.queue_free()
			_resolved.remove_at(i)
