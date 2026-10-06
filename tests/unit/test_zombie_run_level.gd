extends GutTest
## Zombie Run level (Story 3.1): target queue, amble/idle, retargeting scoot, manual camera,
## off-screen freeing, wrong-key no-op and seed determinism. The level is disabled (nothing advances
## by itself): tests call _process(delta) and step the move tween with custom_step(delta). Keys go
## through a real TypingSession wired like RunFrame, so the "source already advanced" order is real.
## Brain blocks (Story 3.2): groups of 4, brains + signal + Brainsss roll in the same call, the hop and
## its cut, and seed determinism of letters and layout. Voice requests go to a recorder, never audio.
## Villagers (Story 3.3): every non-block slot is a villager; a villager key hugs it (0 brains), the
## zombie's hug is cut by the next key while the villager's own poof sequence still completes, and the
## hug (x) and hop (y) never cut each other.
## Conga line (Story 3.4): the logical count at resolve, the hand-off on poofed, the freeing guard, the cap
## from the config, draw order, fit and "never shrinks". The line is disabled too: tests call
## get_conga_line().step(delta).
## End dance (Story 3.5): on_run_ending() returns the config's dance time, stops the scoot and the amble
## where they are, and starts the zombie's and the line's dance, drawing nothing from any RNG.
## Story 3.6: the backdrop follows the camera (the ground layer to the pixel with %World), and the level's
## per-frame play_walk()/play_idle() never clobber the hop, hug or dance frames.

const LevelScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_level.tscn")
const LevelScript := preload("res://scripts/levels/zombie_run/zombie_run_level.gd")
const LEVEL_SCRIPT_DIR: String = "res://scripts/levels/zombie_run/"
const VIEW_WIDTH: float = 640.0

var _level: LevelScript
var _source: TargetSource
var _session: TypingSession
## The run RNG handed to the level (to check who draws from it).
var _run_rng: RandomNumberGenerator
## Voice ids the level requested, in order (the request_voice recorder).
var _voices: Array[StringName] = []
## The level's brain total at each voice request (which brain rolled it).
var _voice_brains: Array[int] = []
## Sound effect ids the level and its villagers played, in order (the play_sfx recorder, Story 5.1).
var _sfx: Array[StringName] = []


## `tweak` (optional) changes a duplicate of the shipped config before the level is added.
func _make(rng_seed: int = 42, tweak: Callable = Callable()) -> LevelScript:
	_level = LevelScene.instantiate() as LevelScript
	_level.process_mode = Node.PROCESS_MODE_DISABLED
	_voices = []
	_voice_brains = []
	_sfx = []
	_level.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	_level.request_voice = func(id: StringName) -> void:
		_voices.append(id)
		_voice_brains.append(_level.get_brains_earned())
	if tweak.is_valid():
		var config: ZombieRunConfig = (_level.config as ZombieRunConfig).duplicate() as ZombieRunConfig
		tweak.call(config)
		_level.config = config
	add_child_autofree(_level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	_run_rng = rng
	_source = _level.create_target_source(rng)
	_session = TypingSession.new(_source, _level.get_level_config())
	_session.char_accepted.connect(_level.on_char_accepted)
	_session.char_rejected.connect(_level.on_char_rejected)
	return _level


func _cfg() -> ZombieRunConfig:
	return _level.get_level_config() as ZombieRunConfig


func _world() -> Node2D:
	return _level.get_node("%World") as Node2D


func _key() -> void:
	assert_eq(_session.judge(_session.get_current_target()), TypingSession.Verdict.CORRECT)


func _wrong_letter() -> String:
	return "b" if _session.get_current_target() == "a" else "a"


func _step(delta: float) -> void:
	var tween: Tween = _level.get_move_tween()
	if tween != null and tween.is_valid():
		tween.custom_step(delta)


func _finish_scoot() -> void:
	_step(_cfg().scoot_time_s + 0.01)


func _letters() -> Array[String]:
	var out: Array[String] = []
	for target: ZombieRunTarget in _level.get_queue():
		out.append(target.get_letter())
	return out


func _expected_letters() -> Array[String]:
	var out: Array[String] = [_source.current()]
	out.append_array(_source.peek(_cfg().visible_upcoming))
	return out


func _active_count() -> int:
	var count: int = 0
	for target: Node in _level.get_node("%Targets").get_children():
		if (target as ZombieRunTarget).is_active():
			count += 1
	return count


func _assert_camera_locked() -> void:
	assert_almost_eq(_level.get_zombie_x() + _world().position.x, LevelScript.ZOMBIE_SCREEN_X, 0.001)
	assert_almost_eq(_level.get_camera_x(), -_world().position.x, 0.001)


func test_contract() -> void:
	_make()
	assert_true(_level is LevelBase)
	assert_true(_level.get_level_config() is ZombieRunConfig)
	assert_true(_source is LetterBagSource)
	assert_eq(_level.get_brains_earned(), 0)
	assert_eq(_level.on_run_ending(GameConstants.END_REASON_TIMER), _cfg().dance_time_s)


func test_queue_after_setup() -> void:
	_make()
	var queue: Array[ZombieRunTarget] = _level.get_queue()
	assert_eq(queue.size(), _cfg().visible_upcoming + 1, "active + next 3")
	for i: int in queue.size():
		assert_eq(queue[i].get_slot(), i)
		assert_eq(queue[i].position.x, _level.target_x(i))
		assert_eq(queue[i].position.y, LevelScript.GROUND_Y, "on the ground line")
		if i > 0:
			assert_eq(queue[i].position.x - queue[i - 1].position.x, _cfg().target_spacing_px)
		assert_eq(queue[i].is_active(), i == 0, "only slot 0 is active")
		assert_eq((queue[i].get_node("%Arrow") as CanvasItem).visible, i == 0, "arrow only on the active one")
	assert_eq(_letters(), _expected_letters())
	assert_eq(queue[0].get_letter(), _session.get_current_target(), "matches the HUD target")
	assert_eq(_level.get_active_index(), 0)
	assert_eq(_level.get_resolved_count(), 0)


func test_get_queue_is_a_copy() -> void:
	_make()
	_level.get_queue().clear()
	assert_eq(_level.get_queue().size(), _cfg().visible_upcoming + 1)


func test_correct_key_advances_in_the_same_call() -> void:
	_make()
	var old: ZombieRunTarget = _level.get_queue()[0]
	_key()
	assert_eq(_level.get_active_index(), 1)
	assert_true(old.is_resolved())
	assert_false(old.is_active())
	var queue: Array[ZombieRunTarget] = _level.get_queue()
	assert_eq(queue.size(), _cfg().visible_upcoming + 1)
	assert_eq(queue[0].get_letter(), _source.current(), "the new active letter")
	assert_true(queue[0].is_active())
	assert_eq(queue[-1].get_letter(), _source.peek(_cfg().visible_upcoming)[-1], "spawned from peek, not current()")
	assert_eq(queue[-1].get_slot(), 1 + _cfg().visible_upcoming)
	assert_eq(queue[-1].position.x, _level.target_x(1 + _cfg().visible_upcoming))
	assert_eq(_letters(), _expected_letters())
	assert_eq(_level.get_resolved_count(), 1)
	var tween: Tween = _level.get_move_tween()
	assert_not_null(tween)
	assert_true(tween.is_running(), "the scoot starts in the same call")
	_finish_scoot()
	assert_eq(_level.get_zombie_x(), _level.approach_x(1))


func test_hud_match_over_100_keys() -> void:
	_make()
	for i: int in 100:
		_key()
		var queue: Array[ZombieRunTarget] = _level.get_queue()
		assert_eq(queue[0].get_letter(), _session.get_current_target())
		assert_eq(_letters(), _expected_letters())
		assert_eq(_active_count(), 1, "exactly one active target")
		if i % 7 == 0:
			_finish_scoot()
			_level._process(0.016)


func test_zombie_starts_one_spacing_behind_the_approach_point() -> void:
	_make()
	assert_eq(_level.get_zombie_x(), _level.approach_x(0) - _cfg().target_spacing_px)
	assert_eq(_level.approach_x(0), _level.target_x(0) - _cfg().approach_gap_px)
	_assert_camera_locked()


func test_amble_and_idle() -> void:
	_make()
	var start: float = _level.get_zombie_x()
	_level._process(1.0)
	assert_almost_eq(_level.get_zombie_x(), start + _cfg().amble_speed_px_s, 0.001, "24 px in 1 s")
	_assert_camera_locked()
	assert_eq((_level.get_node("%Zombie/Body") as AnimatedSprite2D).animation, &"walk")
	_level._process(10.0)
	assert_eq(_level.get_zombie_x(), _level.approach_x(0), "stops exactly at the approach point")
	for i: int in 5:
		_level._process(1.0)
		assert_eq(_level.get_zombie_x(), _level.approach_x(0), "never overshoots")
	assert_eq((_level.get_node("%Zombie/Body") as AnimatedSprite2D).animation, &"idle")
	_assert_camera_locked()


func test_no_amble_while_a_scoot_runs() -> void:
	_make()
	_key()
	var before: float = _level.get_zombie_x()
	_level._process(1.0)
	assert_eq(_level.get_zombie_x(), before, "the scoot owns the zombie while it runs")
	# Story 3.6: a one-shot (the hug after a villager key, the hop after a block key) owns the animation
	# while it runs; walk once it is over.
	var body: AnimatedSprite2D = _level.get_node("%Zombie/Body") as AnimatedSprite2D
	var expected: StringName = &"walk"
	if _zombie().is_hopping():
		expected = PlayerZombie.ANIM_HOP
	elif _zombie().is_hugging():
		expected = PlayerZombie.ANIM_HUG
	assert_eq(body.animation, expected)
	_zombie().stop_hug()
	_zombie().stop_hop()
	_level._process(0.01)
	assert_eq(body.animation, &"walk", "scooting with no one-shot running: walk")


func test_scoot_and_retarget_mid_scoot() -> void:
	_make()
	_key()
	_finish_scoot()
	assert_eq(_level.get_zombie_x(), _level.approach_x(1))
	_assert_camera_locked()
	_key()
	var first: Tween = _level.get_move_tween()
	_step(0.05)
	var mid: float = _level.get_zombie_x()
	assert_gt(mid, _level.approach_x(1))
	assert_lt(mid, _level.approach_x(2))
	_assert_camera_locked()
	_key()
	var second: Tween = _level.get_move_tween()
	assert_ne(second, first)
	assert_false(first.is_valid(), "the old tween was killed: only one move tween")
	_step(0.001)
	assert_true(_level.get_zombie_x() >= mid, "restarted from the current position, not the start")
	assert_lt(_level.get_zombie_x(), mid + 2.0)
	_finish_scoot()
	assert_eq(_level.get_zombie_x(), _level.approach_x(3))
	_assert_camera_locked()


func test_chaining_never_caps_typing() -> void:
	_make()
	_level._process(10.0)
	for i: int in 5:
		_key()
	_step(_cfg().scoot_time_s)
	assert_eq(_level.get_zombie_x(), _level.approach_x(5), "5 keys in one frame: there in one scoot time")
	_assert_camera_locked()


func test_camera_keeps_upcoming_targets_on_screen() -> void:
	_make()
	for i: int in 200:
		_key()
		if i % 3 == 0:
			_step(0.05)
		else:
			_finish_scoot()
		_level._process(0.016)
		_assert_camera_locked()
		for target: ZombieRunTarget in _level.get_queue():
			var screen_x: float = target.position.x + _world().position.x
			assert_true(screen_x >= 0.0 and screen_x <= VIEW_WIDTH, "target %d on screen (x %.1f)" % [target.get_slot(), screen_x])


func test_resolved_targets_are_freed_off_screen() -> void:
	_make()
	var first: ZombieRunTarget = _level.get_queue()[0]
	for i: int in 50:
		_key()
		_finish_scoot()
		# Story 3.4: villagers are kept until their poof hands off, so finish the poofs first.
		_finish_poofs()
		_level._process(0.016)
		assert_true(_level.get_resolved_count() <= 6, "resolved targets do not pile up")
	assert_true(first.is_queued_for_deletion() or not is_instance_valid(first), "the first target left the screen")
	for target: ZombieRunTarget in _level.get_queue():
		assert_false(target.is_queued_for_deletion(), "unresolved targets are never freed")
	await get_tree().process_frame
	assert_false(is_instance_valid(first))
	assert_eq(
		_level.get_node("%Targets").get_child_count(),
		_level.get_queue().size() + _level.get_resolved_count(),
		"freed targets are gone from %Targets",
	)


func test_resolved_target_stays_while_on_screen() -> void:
	_make()
	var first: ZombieRunTarget = _level.get_queue()[0]
	_key()
	_finish_scoot()
	_level._process(0.016)
	assert_false(first.is_queued_for_deletion(), "still on screen behind the zombie")
	assert_eq(_level.get_resolved_count(), 1)


func test_wrong_key_changes_nothing() -> void:
	_make()
	_level._process(0.5)
	var x: float = _level.get_zombie_x()
	var letters: Array[String] = _letters()
	assert_eq(_session.judge(_wrong_letter()), TypingSession.Verdict.WRONG)
	assert_eq(_level.get_active_index(), 0)
	assert_eq(_level.get_zombie_x(), x)
	assert_eq(_letters(), letters)
	assert_null(_level.get_move_tween(), "no scoot")
	_key()
	_step(0.05)
	var tween: Tween = _level.get_move_tween()
	x = _level.get_zombie_x()
	letters = _letters()
	_session.judge(_wrong_letter())
	assert_eq(_level.get_active_index(), 1)
	assert_eq(_level.get_zombie_x(), x)
	assert_eq(_letters(), letters)
	assert_eq(_level.get_move_tween(), tween, "the running scoot is untouched")
	assert_true(tween.is_valid())


func _first_letters(rng_seed: int, count: int) -> Array[String]:
	_make(rng_seed)
	var out: Array[String] = []
	for i: int in count:
		out.append(_level.get_queue()[0].get_letter())
		_key()
	return out


func test_same_seed_same_targets() -> void:
	var first: Array[String] = _first_letters(5, 30)
	assert_eq(_first_letters(5, 30), first)
	assert_ne(_first_letters(6, 30), first)


func test_no_tuning_literals_in_level_scripts() -> void:
	var regex: RegEx = RegEx.create_from_string("\\b(120|0\\.15|26|0\\.35|48|0\\.2)\\b")
	var files: PackedStringArray = DirAccess.get_files_at(LEVEL_SCRIPT_DIR)
	var checked: int = 0
	for file: String in files:
		if not file.ends_with(".gd"):
			continue
		checked += 1
		var source: String = FileAccess.get_file_as_string(LEVEL_SCRIPT_DIR + file)
		var line_number: int = 0
		for line: String in source.split("\n"):
			line_number += 1
			var code: String = line.get_slice("#", 0)
			assert_null(regex.search(code), "%s:%d has a tuning literal: %s" % [file, line_number, line.strip_edges()])
	assert_gt(checked, 0, "level scripts found")


# --- brain blocks (Story 3.2) ----------------------------------------------

func _zombie() -> PlayerZombie:
	return _level.get_node("%Zombie") as PlayerZombie


func _body_y() -> float:
	return (_level.get_node("%Zombie/Body") as Node2D).position.y


## Types correct keys (finishing each scoot) until the active target satisfies `want`.
func _type_until(want: Callable, limit: int = 50) -> void:
	for i: int in limit:
		if want.call(_level.get_queue()[0]):
			return
		_key()
		_finish_scoot()
	fail_test("no matching target within %d keys" % limit)


func _is_block(target: ZombieRunTarget) -> bool:
	return target is BrainBlock


func _is_villager(target: ZombieRunTarget) -> bool:
	return target is Villager


## True when slot n was a brain block, for the first `keys` keys' worth of slots.
func _block_slots(rng_seed: int, keys: int) -> Array[bool]:
	_make(rng_seed)
	var out: Array[bool] = []
	for target: ZombieRunTarget in _level.get_queue():
		out.append(target is BrainBlock)
	for i: int in keys:
		_key()
		_finish_scoot()
		var newest: ZombieRunTarget = _level.get_queue().back()
		assert_eq(newest.get_slot(), out.size(), "slots spawn in order")
		out.append(newest is BrainBlock)
	return out


func test_one_brain_block_per_group_of_4() -> void:
	for rng_seed: int in [42, 7]:
		var slots: Array[bool] = _block_slots(rng_seed, 200)
		var groups: int = slots.size() / 4
		assert_gt(groups, 49)
		for k: int in groups:
			assert_eq(slots.slice(k * 4, k * 4 + 4).count(true), 1, "seed %d slots %d..%d" % [rng_seed, k * 4, k * 4 + 3])


func test_brain_block_floats_on_its_slot() -> void:
	_make()
	_type_until(_is_block)
	var block: BrainBlock = _level.get_queue()[0] as BrainBlock
	assert_eq(block.position, Vector2(_level.target_x(block.get_slot()), LevelScript.GROUND_Y))
	assert_eq((block.get_node("%Lift") as Node2D).position.y, -_cfg().brain_block_float_px)
	assert_true(block.is_active())
	assert_true((block.get_node("%Arrow") as CanvasItem).visible)


func test_brain_block_key_pays_in_the_same_call() -> void:
	_make()
	_type_until(_is_block)
	var block: BrainBlock = _level.get_queue()[0] as BrainBlock
	var before: int = _level.get_brains_earned()
	watch_signals(_level)
	_key()
	assert_eq(_level.get_brains_earned(), before + 1, "+brains_per_block")
	assert_signal_emit_count(_level, "brains_earned_changed", 1)
	assert_eq(get_signal_parameters(_level, "brains_earned_changed"), [before + 1])
	assert_true(_zombie().is_hopping(), "the hop starts in the same call")
	assert_true(block.is_used(), "the block switched to its used look")
	assert_true(_level.get_move_tween().is_running(), "the scoot still starts")
	assert_eq(_level.get_active_index(), block.get_slot() + 1, "the logic never waits on the hop")


func test_villager_key_pays_nothing() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 1.0)
	_type_until(_is_villager)
	var before: int = _level.get_brains_earned()
	watch_signals(_level)
	_key()
	assert_eq(_level.get_brains_earned(), before)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_voices.size(), before, "no voice request for a villager")
	assert_false(_zombie().is_hopping())


func test_hop_finishes_after_a_villager_key() -> void:
	_make()
	_type_until(func(t: ZombieRunTarget) -> bool:
		return t is BrainBlock and not _level.get_queue()[1] is BrainBlock)
	_key()
	assert_true(_zombie().is_hopping())
	var hop: Tween = _zombie().get_hop_tween()
	hop.custom_step(_cfg().hop_time_s * 0.4)
	assert_lt(_body_y(), -31.0, "mid-hop")
	_key()
	assert_true(_zombie().is_hopping(), "a villager key does not cut the hop")
	assert_true(_zombie().is_hugging(), "the villager key starts the hug during the hop")
	assert_true(hop.is_valid())
	hop.custom_step(_cfg().hop_time_s)
	assert_false(_zombie().is_hopping())
	assert_eq(_body_y(), -31.0, "back at rest height")


func test_block_after_block_restarts_the_hop() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.brain_block_every = 1)
	for target: ZombieRunTarget in _level.get_queue():
		assert_true(target is BrainBlock, "groups of 1: every slot is a block")
	_key()
	var first: Tween = _zombie().get_hop_tween()
	first.custom_step(_cfg().hop_time_s * 0.4)
	_key()
	var second: Tween = _zombie().get_hop_tween()
	assert_ne(second, first)
	assert_false(first.is_valid(), "only one hop tween")
	assert_true(_zombie().is_hopping())
	second.custom_step(_cfg().hop_time_s * 0.5)
	assert_almost_eq(_body_y(), -31.0 - _level.hop_height(), 0.01, "a full new arc")
	assert_eq(_level.get_brains_earned(), 2)


func test_hop_height_reaches_the_block() -> void:
	_make()
	assert_eq(_level.hop_height(), _cfg().brain_block_float_px - PlayerZombie.SIZE_PX)
	assert_eq(_level.hop_height(), 16.0)


func test_brainsss_at_chance_one_every_brain() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 1.0)
	for i: int in 40:
		_key()
	assert_eq(_level.get_brains_earned(), 10, "40 keys = 10 groups")
	assert_eq(_voices.size(), 10)
	for id: StringName in _voices:
		assert_eq(id, &"vo_brainsss")


func test_brainsss_at_chance_zero_never() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 0.0)
	for i: int in 40:
		_key()
	assert_eq(_level.get_brains_earned(), 10)
	assert_eq(_voices.size(), 0)


func _voice_brains_for(rng_seed: int, keys: int) -> Array[int]:
	_make(rng_seed)
	for i: int in keys:
		_key()
	return _voice_brains.duplicate()


func test_brainsss_rate_and_determinism() -> void:
	var first: Array[int] = _voice_brains_for(11, 2000)
	assert_eq(_level.get_brains_earned(), 500)
	assert_between(first.size(), 60, 140, "about 20%% of 500 brains (%d)" % first.size())
	assert_eq(_voice_brains_for(11, 2000), first, "same seed, same rolls")


func _letters_and_blocks(rng_seed: int, count: int) -> Array:
	_make(rng_seed)
	var out: Array = []
	for i: int in count:
		var target: ZombieRunTarget = _level.get_queue()[0]
		out.append([target.get_letter(), target is BrainBlock])
		_key()
	return out


func test_same_seed_same_letters_and_blocks() -> void:
	var first: Array = _letters_and_blocks(5, 60)
	assert_eq(_letters_and_blocks(5, 60), first)
	assert_ne(_letters_and_blocks(6, 60), first)


func test_layout_does_not_depend_on_the_voice_rolls() -> void:
	var quiet: Array = []
	_make(9, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 0.0)
	for i: int in 60:
		quiet.append(_level.get_queue()[0] is BrainBlock)
		_key()
	_make(9, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 1.0)
	for i: int in 60:
		assert_eq(_level.get_queue()[0] is BrainBlock, quiet[i], "slot %d" % i)
		_key()


func test_letters_match_the_story_3_1_letter_bag() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = rng.randi()
	var bag: LetterBagSource = LetterBagSource.new(child, _make().get_level_config().letter_pool)
	for i: int in 60:
		assert_eq(_level.get_queue()[0].get_letter(), bag.current(), "letter %d" % i)
		_key()
		bag.advance()


func _make_with_bad_config(tweak: Callable) -> TargetSource:
	var level: LevelScript = LevelScene.instantiate() as LevelScript
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.request_voice = func(_id: StringName) -> void: pass
	var config: ZombieRunConfig = (level.config as ZombieRunConfig).duplicate() as ZombieRunConfig
	tweak.call(config)
	level.config = config
	add_child_autofree(level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	return level.create_target_source(rng)


func test_bad_brain_config_returns_no_source() -> void:
	assert_null(_make_with_bad_config(func(c: ZombieRunConfig) -> void: c.brain_block_every = 0))
	assert_push_error("brain_block_every")
	assert_null(_make_with_bad_config(func(c: ZombieRunConfig) -> void: c.brainsss_chance = 1.5))
	assert_push_error("brainsss_chance")


func test_request_voice_defaults_to_the_audio_manager() -> void:
	var level: LevelScript = LevelScene.instantiate() as LevelScript
	level.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(level)
	assert_true(level.request_voice.is_valid())
	assert_eq(level.request_voice.get_method(), &"play_voice")
	assert_eq(level.request_voice.get_object(), AudioManager)


# --- villagers (Story 3.3) --------------------------------------------------

func test_bad_hug_config_returns_no_source() -> void:
	assert_null(_make_with_bad_config(func(c: ZombieRunConfig) -> void: c.hug_time_s = 0.0))
	assert_push_error("hug_time_s")


func test_every_non_block_target_is_a_villager() -> void:
	_make()
	var villager_script: Script = load("res://scripts/levels/zombie_run/villager.gd")
	var seen: int = 0
	for i: int in 200:
		for target: ZombieRunTarget in _level.get_queue():
			if target is BrainBlock:
				continue
			assert_eq(target.get_script(), villager_script, "slot %d is a villager" % target.get_slot())
			seen += 1
		_key()
		_finish_scoot()
		_level._process(0.016)
	assert_gt(seen, 400, "villagers checked")
	for target: Node in _level.get_node("%Targets").get_children():
		assert_true(target is BrainBlock or target is Villager, "no plain ZombieRunTarget is spawned")


func test_villager_key_hugs_in_the_same_call() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 1.0)
	_type_until(_is_villager)
	var villager: Villager = _level.get_queue()[0] as Villager
	var before: int = _level.get_brains_earned()
	var voices: int = _voices.size()
	watch_signals(_level)
	_key()
	assert_true(_zombie().is_hugging(), "the hug starts in the same call")
	assert_eq(villager.get_state(), Villager.State.HUGGED)
	assert_eq(_level.get_brains_earned(), before)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_voices.size(), voices, "no voice request")
	assert_true(_level.get_move_tween().is_running(), "the scoot still starts")
	assert_eq(_level.get_active_index(), villager.get_slot() + 1, "the logic never waits on the hug")


func test_villager_after_villager_cuts_and_restarts_the_hug() -> void:
	_make()
	_type_until(func(t: ZombieRunTarget) -> bool:
		return t is Villager and _level.get_queue()[1] is Villager)
	var first_villager: Villager = _level.get_queue()[0] as Villager
	_key()
	var first: Tween = _zombie().get_hug_tween()
	first.custom_step(_cfg().hug_time_s * 0.25)
	_key()
	var second: Tween = _zombie().get_hug_tween()
	assert_ne(second, first)
	assert_false(first.is_valid(), "only one hug tween")
	assert_true(second.is_valid())
	assert_true(_zombie().is_hugging())
	assert_true(first_villager.get_sequence_tween().is_valid(), "the first villager's sequence keeps going")
	assert_eq(first_villager.get_state(), Villager.State.HUGGED)


func test_block_key_cuts_the_hug_and_hops() -> void:
	_make()
	_type_until(func(t: ZombieRunTarget) -> bool:
		return t is Villager and _level.get_queue()[1] is BrainBlock)
	_key()
	_zombie().get_hug_tween().custom_step(_cfg().hug_time_s * 0.25)
	_key()
	assert_false(_zombie().is_hugging(), "a block key cuts the hug")
	assert_eq((_level.get_node("%Zombie/Body") as Node2D).position.x, -16.0, "Body back at rest x")
	assert_true(_zombie().is_hopping(), "and starts the hop")


func test_effects_complete_after_a_cut() -> void:
	_make()
	_type_until(_is_villager)
	var villager: Villager = _level.get_queue()[0] as Villager
	watch_signals(villager)
	_key()
	_key()
	assert_eq(villager.get_state(), Villager.State.HUGGED, "the cut never touches the villager")
	villager.get_sequence_tween().custom_step(_cfg().hug_time_s + 0.01)
	assert_eq(villager.get_state(), Villager.State.POOFED)
	var poof: Poof = null
	for child: Node in villager.get_children():
		if child is Poof:
			poof = child as Poof
	assert_not_null(poof)
	assert_eq(poof.position, Vector2.ZERO, "the poof is at the villager's feet origin")
	poof.get_tween().custom_step(Poof.FRAMES / Poof.FPS + 0.01)
	assert_true(villager.is_party_zombie_shown(), "a party-hat zombie stands where the villager was")
	assert_signal_emit_count(villager, "poofed", 1)


func test_burst_every_villager_still_poofs() -> void:
	_make()
	var villagers: Array[Villager] = []
	for i: int in 12:
		var target: ZombieRunTarget = _level.get_queue()[0]
		if target is Villager:
			villagers.append(target as Villager)
		_key()
	assert_eq(villagers.size(), 9, "12 keys = 3 groups of 3 villagers")
	for villager: Villager in villagers:
		villager.get_sequence_tween().custom_step(_cfg().hug_time_s + 0.01)
		for child: Node in villager.get_children():
			if child is Poof:
				(child as Poof).get_tween().custom_step(1.0)
		assert_true(villager.is_party_zombie_shown(), "slot %d" % villager.get_slot())


func test_hug_time_comes_from_the_config() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.hug_time_s = 1.0)
	_type_until(_is_villager)
	var villager: Villager = _level.get_queue()[0] as Villager
	_key()
	_zombie().get_hug_tween().custom_step(0.9)
	assert_true(_zombie().is_hugging(), "the zombie hugs for the configured 1.0 s")
	villager.get_sequence_tween().custom_step(0.9)
	assert_eq(villager.get_state(), Villager.State.HUGGED, "the villager poofs after the configured 1.0 s")
	villager.get_sequence_tween().custom_step(0.2)
	assert_eq(villager.get_state(), Villager.State.POOFED)


## The run RNG gives two child seeds (letters, layout) and then one randf() per brain; villagers add none.
func test_run_rng_has_one_consumer() -> void:
	_make(42)
	for i: int in 40:
		_key()
	assert_eq(_level.get_brains_earned(), 10)
	var expected: RandomNumberGenerator = RandomNumberGenerator.new()
	expected.seed = 42
	expected.randi()
	expected.randi()
	for i: int in 10:
		expected.randf()
	assert_eq(_run_rng.state, expected.state, "two child seeds + one roll per brain, nothing else")


# --- conga line (Story 3.4) ---------------------------------------------------

func _conga() -> CongaLine:
	return _level.get_conga_line()


## Finishes the hug -> poof -> party zombie sequence of every hugged villager still in %Targets.
func _finish_poofs() -> void:
	for node: Node in _level.get_node("%Targets").get_children():
		var villager: Villager = node as Villager
		if villager == null or villager.get_state() == Villager.State.WAITING:
			continue
		_finish_poof(villager)


func _finish_poof(villager: Villager) -> void:
	if villager.is_party_zombie_shown():
		return
	villager.get_sequence_tween().custom_step(_cfg().hug_time_s + 0.01)
	for child: Node in villager.get_children():
		if child is Poof:
			(child as Poof).get_tween().custom_step(Poof.FRAMES / Poof.FPS + 0.01)


func test_villager_key_counts_in_the_same_call() -> void:
	_make()
	_type_until(_is_villager)
	var before: int = _level.get_conga_count()
	_key()
	assert_eq(_level.get_conga_count(), before + 1, "counted at resolve, before any tween step")
	assert_eq(_conga().get_joined_count(), 0, "the view joins later, when the poof ends")


func test_block_and_wrong_keys_do_not_count() -> void:
	_make()
	_type_until(_is_block)
	var before: int = _level.get_conga_count()
	_key()
	assert_eq(_level.get_conga_count(), before, "a brain block is not a villager")
	_session.judge(_wrong_letter())
	assert_eq(_level.get_conga_count(), before, "a wrong key changes nothing")


func test_poof_hands_the_party_zombie_to_the_line() -> void:
	_make()
	_type_until(_is_villager)
	var villager: Villager = _level.get_queue()[0] as Villager
	_key()
	_finish_poof(villager)
	assert_eq(_conga().get_joined_count(), 1)
	var followers: Array[PartyZombie] = _conga().get_followers()
	assert_eq(followers.size(), 1)
	assert_almost_eq(followers[0].global_position.x, villager.get_party_zombie().global_position.x, 0.001, "same spot")
	assert_almost_eq(followers[0].global_position.y, villager.get_party_zombie().global_position.y, 0.001, "same feet")
	var follower_frames: SpriteFrames = (followers[0].get_node("Body") as AnimatedSprite2D).sprite_frames
	var villager_frames: SpriteFrames = (villager.get_party_zombie().get_node("Body") as AnimatedSprite2D).sprite_frames
	assert_eq(follower_frames, villager_frames, "same sprite")
	assert_false(villager.get_party_zombie().visible, "the villager's own copy hides")
	assert_true(villager.is_party_zombie_shown(), "the hand-off happened")


func test_burst_every_villager_joins() -> void:
	_make()
	var villagers: Array[Villager] = []
	for i: int in 12:
		var target: ZombieRunTarget = _level.get_queue()[0]
		if target is Villager:
			villagers.append(target as Villager)
		_key()
	assert_gt(villagers.size(), 0)
	assert_eq(_level.get_conga_count(), villagers.size(), "every villager counted immediately")
	assert_eq(_conga().get_joined_count(), 0)
	for villager: Villager in villagers:
		_finish_poof(villager)
	assert_eq(_conga().get_joined_count(), villagers.size(), "the view caught up")


func test_villager_is_not_freed_before_its_hand_off() -> void:
	_make()
	_type_until(_is_villager)
	var villager: Villager = _level.get_queue()[0] as Villager
	for i: int in 12:
		_key()
		_finish_scoot()
	_level._process(0.016)
	assert_true(villager.position.x + ZombieRunTarget.HALF_WIDTH < _level.get_camera_x(), "off screen")
	assert_false(villager.is_party_zombie_shown(), "its poof has not ended yet")
	assert_false(villager.is_queued_for_deletion(), "kept until the hand-off")
	_finish_poof(villager)
	assert_eq(_conga().get_joined_count(), 1, "it joined the line")
	_level._process(0.016)
	assert_true(villager.is_queued_for_deletion(), "the next pass frees it")


func test_cap_comes_from_the_config() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.conga_max_drawn = 3)
	for i: int in 12:
		_key()
	_finish_poofs()
	var count: int = _level.get_conga_count()
	assert_gt(count, 3)
	assert_eq(_conga().get_drawn_count(), 3)
	assert_eq(_conga().get_joined_count(), count)
	assert_true(_conga().is_badge_shown())
	assert_eq(_conga().get_badge_text(), "×%d" % count)


func test_conga_line_draws_between_targets_and_zombie() -> void:
	_make()
	var conga: Node = _level.get_node("%CongaLine")
	assert_eq(conga.get_parent(), _world())
	assert_gt(conga.get_index(), _level.get_node("%Targets").get_index(), "above the targets")
	assert_lt(conga.get_index(), _zombie().get_index(), "below the player zombie")
	assert_eq((conga as Node2D).position.y, LevelScript.GROUND_Y, "on the ground line")


func test_full_line_fits_behind_the_zombie() -> void:
	_make()
	assert_true(
		LevelScript.ZOMBIE_SCREEN_X - _cfg().conga_max_drawn * CongaLine.SPACING_PX >= 16.0,
		"room for the tail sprite and the badge's left edge"
	)


func test_followers_stay_on_screen_and_above_the_ground_at_normal_speed() -> void:
	_make()
	for i: int in 80:
		_key()
		_finish_scoot()
		_finish_poofs()
		for s: int in 10:
			_level._process(0.03)
			_conga().step(0.03)
	assert_eq(_conga().get_drawn_count(), _cfg().conga_max_drawn)
	assert_true(_conga().is_badge_shown())
	for follower: PartyZombie in _conga().get_followers():
		var screen_x: float = follower.position.x + _world().position.x
		assert_true(screen_x - 8.0 >= 0.0, "tail on screen (x %.1f)" % screen_x)
		assert_true(screen_x < LevelScript.ZOMBIE_SCREEN_X, "behind the zombie")
		assert_true(follower.global_position.y <= LevelScript.GROUND_Y, "nothing below the ground line")
	var badge: Control = _conga().get_node("%Badge") as Control
	assert_true(badge.position.x + _world().position.x >= 0.0, "badge on screen")


func test_conga_never_shrinks() -> void:
	_make()
	for i: int in 12:
		_key()
	_finish_poofs()
	var count: int = _level.get_conga_count()
	var joined: int = _conga().get_joined_count()
	var followers: Array[PartyZombie] = _conga().get_followers()
	for i: int in 10:
		_session.judge(_wrong_letter())
		_level._process(0.016)
		_conga().step(0.016)
	assert_eq(_level.get_conga_count(), count)
	assert_eq(_conga().get_joined_count(), joined)
	assert_eq(_conga().get_followers(), followers)


func test_bad_conga_config_returns_no_source() -> void:
	assert_null(_make_with_bad_config(func(c: ZombieRunConfig) -> void: c.conga_max_drawn = 0))
	assert_push_error("conga_max_drawn")


## test_run_rng_has_one_consumer never finishes a poof; this one does, so a draw in the hand-off shows up.
func test_conga_line_draws_nothing_from_the_run_rng() -> void:
	_make(42)
	for i: int in 40:
		_key()
		_finish_poofs()
		_conga().step(0.016)
	assert_gt(_conga().get_joined_count(), 0, "poofs handed off")
	assert_eq(_level.get_brains_earned(), 10)
	var expected: RandomNumberGenerator = RandomNumberGenerator.new()
	expected.seed = 42
	expected.randi()
	expected.randi()
	for i: int in 10:
		expected.randf()
	assert_eq(_run_rng.state, expected.state, "the conga line adds no draws")


# --- end dance (Story 3.5) ----------------------------------------------------

func _body() -> AnimatedSprite2D:
	return _level.get_node("%Zombie/Body") as AnimatedSprite2D


func test_on_run_ending_returns_the_config_dance_time() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.dance_time_s = 3.0)
	assert_eq(_level.on_run_ending(GameConstants.END_REASON_TIMER), 3.0)


func test_end_stops_mid_scoot_and_dances() -> void:
	_make()
	assert_false(_level.is_dancing())
	_key()
	_key()
	var tween: Tween = _level.get_move_tween()
	_step(_cfg().scoot_time_s * 0.5)
	assert_true(tween.is_running(), "mid-scoot")
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	assert_false(tween.is_valid(), "the scoot tween was killed")
	assert_true(_level.is_dancing())
	assert_true(_zombie().is_dancing(), "the zombie's dance tween runs")
	assert_true(_conga().is_dancing(), "the line dances too")
	var zombie_x: float = _level.get_zombie_x()
	var camera_x: float = _level.get_camera_x()
	assert_lt(zombie_x, _approach_goal(), "stopped short of the goal")
	for i: int in 50:
		_level._process(0.1)
	assert_eq(_level.get_zombie_x(), zombie_x, "no amble while dancing")
	assert_eq(_level.get_camera_x(), camera_x, "the camera stays put")
	_assert_camera_locked()


func _approach_goal() -> float:
	return _level.approach_x(_level.get_active_index())


func test_end_while_idle_before_the_goal_stops_the_amble() -> void:
	_make()
	var zombie_x: float = _level.get_zombie_x()
	assert_lt(zombie_x, _approach_goal(), "starts short of the first approach point")
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	for i: int in 20:
		_level._process(0.1)
	assert_eq(_level.get_zombie_x(), zombie_x, "no amble while dancing")


## Without dance frames (a stripped SpriteFrames) the dance plays idle, and _process keeps it.
func test_process_while_dancing_keeps_the_dance_animation() -> void:
	_make()
	var frames: SpriteFrames = _body().sprite_frames.duplicate() as SpriteFrames
	frames.remove_animation(PlayerZombie.ANIM_DANCE)
	_body().sprite_frames = frames
	_key()
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	assert_eq(_body().animation, PlayerZombie.ANIM_IDLE, "no dance frames: idle")
	for i: int in 10:
		_level._process(0.1)
		assert_eq(_body().animation, PlayerZombie.ANIM_IDLE, "not switched to walk by _process")


## With Story 3.6's dance frames (the real scene), a play_idle() from _process would show too.
func test_process_while_dancing_keeps_the_dance_frames() -> void:
	_make()
	_key()
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	assert_eq(_body().animation, PlayerZombie.ANIM_DANCE)
	for i: int in 10:
		_level._process(0.1)
		assert_eq(_body().animation, PlayerZombie.ANIM_DANCE, "not switched to walk or idle by _process")
	_finish_scoot()
	_level._process(0.1)
	assert_eq(_body().animation, PlayerZombie.ANIM_DANCE, "nor once the cut scoot would have ended")


func test_end_cuts_hop_and_hug() -> void:
	_make()
	_type_until(_is_block)
	_key()
	assert_true(_zombie().is_hopping())
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	assert_false(_zombie().is_hopping(), "the dance cuts the hop")
	assert_false(_zombie().is_hugging())


func test_villager_hugged_before_the_end_still_joins_during_the_dance() -> void:
	_make()
	_type_until(_is_villager)
	var villager: Villager = _level.get_queue()[0] as Villager
	_key()
	var joined: int = _conga().get_joined_count()
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	_finish_poof(villager)
	assert_eq(_conga().get_joined_count(), joined + 1, "it still joins the line")
	assert_eq(_conga().get_joined_count(), _level.get_conga_count())
	for i: int in 30:
		_conga().step(1.0 / 60.0)
	assert_true(_conga().is_dancing())


func test_dance_draws_nothing_from_the_run_rng() -> void:
	_make(42)
	for i: int in 40:
		_key()
	var state: int = _run_rng.state
	_level.on_run_ending(GameConstants.END_REASON_TIMER)
	for i: int in 30:
		_level._process(1.0 / 30.0)
		_conga().step(1.0 / 30.0)
		_zombie().get_dance_tween().custom_step(1.0 / 30.0)
	assert_eq(_run_rng.state, state, "the dance adds no draws")


func test_bad_dance_config_returns_no_source() -> void:
	assert_null(_make_with_bad_config(func(c: ZombieRunConfig) -> void: c.dance_time_s = 0.0))
	assert_push_error("dance_time_s")


# --- animations through the level (Story 3.6) ----------------------------------


## The 3.2 deferral: _process and _scoot_to call play_walk(); the hop frames stay for the whole hop.
func test_block_key_plays_the_hop_and_the_level_does_not_clobber_it() -> void:
	_make()
	_type_until(_is_block)
	_key()
	assert_true(_zombie().is_hopping())
	assert_eq(_body().animation, PlayerZombie.ANIM_HOP, "the hop frames, not walk")
	for i: int in 3:
		_step(0.05)
		_level._process(0.05)
		assert_eq(_body().animation, PlayerZombie.ANIM_HOP, "still hopping mid-scoot (%d)" % i)
	_zombie().get_hop_tween().custom_step(_cfg().hop_time_s + 0.01)
	_finish_scoot()
	_level._process(0.01)
	assert_eq(_body().animation, PlayerZombie.ANIM_IDLE, "at the goal once the hop ends: the level's idle takes over")


func test_villager_key_plays_the_hug() -> void:
	_make()
	_type_until(_is_villager)
	_key()
	assert_true(_zombie().is_hugging())
	assert_eq(_body().animation, PlayerZombie.ANIM_HUG)
	_level._process(0.05)
	assert_eq(_body().animation, PlayerZombie.ANIM_HUG, "the level's play_walk() does not clobber it")


# --- backdrop (Story 3.6) --------------------------------------------------------


func _backdrop() -> SunnyVillageBackdrop:
	return _level.get_node("%Backdrop") as SunnyVillageBackdrop


func _ground_offset() -> float:
	return _backdrop().get_layer_offset(SunnyVillageBackdrop.LAYER_GROUND)


func test_backdrop_is_outside_the_world_and_behind_it() -> void:
	_make()
	var backdrop: SunnyVillageBackdrop = _backdrop()
	assert_not_null(backdrop)
	assert_eq(backdrop.get_parent(), _level, "outside %World, so the HUD never scrolls with it")
	assert_lt(backdrop.get_index(), _world().get_index(), "drawn behind the world")
	assert_eq(backdrop.position, Vector2.ZERO)


func test_backdrop_follows_the_camera_from_the_start() -> void:
	_make()
	assert_lt(_level.get_camera_x(), 0.0, "a run starts at a negative camera x")
	assert_eq(_ground_offset(), fposmod(roundf(_level.get_camera_x()), 640.0))


func test_backdrop_ground_follows_a_scoot() -> void:
	_make()
	_key()
	_finish_scoot()
	assert_eq(_ground_offset(), fposmod(roundf(_level.get_camera_x()), 640.0))
	for i: int in 5:
		_key()
	for i: int in 30:
		_step(1.0 / 60.0)
		assert_eq(_ground_offset(), fposmod(roundf(_level.get_camera_x()), 640.0), "mid-scoot step %d" % i)
	_finish_scoot()
	assert_eq(_ground_offset(), fposmod(roundf(_level.get_camera_x()), 640.0))


func test_backdrop_ground_follows_the_amble() -> void:
	_make()
	var start: float = _level.get_camera_x()
	for i: int in 8:
		_level._process(0.1)
		assert_eq(_ground_offset(), fposmod(roundf(_level.get_camera_x()), 640.0), "amble step %d" % i)
	assert_gt(_level.get_camera_x(), start, "the camera moved with the amble")


## The ground layer and %World are both whole-pixel positioned by the same rounding, so a target never
## swims on the path: the layer's on-screen x is the world's rounded x, modulo the 640 px period.
func test_ground_layer_stays_in_step_with_the_world_while_scooting() -> void:
	_make()
	for i: int in 8:
		_key()
		for j: int in 7:
			_step(0.013)
			var world_px: float = roundf(-_world().position.x)
			assert_eq(_ground_offset(), fposmod(world_px, 640.0), "key %d step %d" % [i, j])
			var layer_x: float = _backdrop().get_layer(SunnyVillageBackdrop.LAYER_GROUND).position.x
			assert_eq(fposmod(layer_x - roundf(_world().position.x), 640.0), 0.0, "ground and world move together")


func test_backdrop_layers_scroll_at_different_speeds() -> void:
	_make()
	for i: int in 10:
		_key()
	_finish_scoot()
	var camera_x: float = _level.get_camera_x()
	for layer: StringName in SunnyVillageBackdrop.FACTORS:
		assert_eq(_backdrop().get_layer_offset(layer),
				fposmod(roundf(camera_x * SunnyVillageBackdrop.FACTORS[layer]), 640.0), String(layer))


# --- sounds (Story 5.1) ---------------------------------------------------------

func test_one_bonk_per_brain_block_none_for_villagers() -> void:
	_make(42)
	for i: int in 40:
		var before_brains: int = _level.get_brains_earned()
		var before_bonks: int = _sfx.count(&"sfx_brain_bonk")
		_key()
		var block: bool = _level.get_brains_earned() > before_brains
		assert_eq(_sfx.count(&"sfx_brain_bonk") - before_bonks, 1 if block else 0, "key %d" % i)
	assert_eq(_sfx.count(&"sfx_brain_bonk"), 10, "10 blocks, 10 bonks")
	assert_eq(_sfx.count(&"sfx_hug_poof"), 0, "no poof has started yet: the poof sound waits for it")


func test_villagers_play_the_hug_poof_through_the_level_seam() -> void:
	_make(42)
	for i: int in 8:
		_key()
	_finish_poofs()
	assert_eq(_sfx.count(&"sfx_hug_poof"), 6, "8 keys = 2 blocks + 6 villagers, one poof each")


func test_play_sfx_defaults_to_the_audio_manager() -> void:
	var level: LevelScript = LevelScene.instantiate() as LevelScript
	level.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(level)
	assert_eq(level.play_sfx, Callable(AudioManager.play_sfx))
