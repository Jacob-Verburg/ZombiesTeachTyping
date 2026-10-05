extends GutTest
## Zombie Run level (Story 3.1): target queue, amble/idle, retargeting scoot, manual camera,
## off-screen freeing, wrong-key no-op and seed determinism. The level is disabled (nothing advances
## by itself): tests call _process(delta) and step the move tween with custom_step(delta). Keys go
## through a real TypingSession wired like RunFrame, so the "source already advanced" order is real.
## Brain blocks (Story 3.2): groups of 4, brains + signal + Brainsss roll in the same call, the hop and
## its cut, and seed determinism of letters and layout. Voice requests go to a recorder, never audio.

const LevelScene: PackedScene = preload("res://scenes/levels/zombie_run/zombie_run_level.tscn")
const LevelScript := preload("res://scripts/levels/zombie_run/zombie_run_level.gd")
const LEVEL_SCRIPT_DIR: String = "res://scripts/levels/zombie_run/"
const VIEW_WIDTH: float = 640.0

var _level: LevelScript
var _source: TargetSource
var _session: TypingSession
## Voice ids the level requested, in order (the request_voice recorder).
var _voices: Array[StringName] = []
## The level's brain total at each voice request (which brain rolled it).
var _voice_brains: Array[int] = []


## `tweak` (optional) changes a duplicate of the shipped config before the level is added.
func _make(rng_seed: int = 42, tweak: Callable = Callable()) -> LevelScript:
	_level = LevelScene.instantiate() as LevelScript
	_level.process_mode = Node.PROCESS_MODE_DISABLED
	_voices = []
	_voice_brains = []
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
	assert_eq(_level.on_run_ending(GameConstants.END_REASON_TIMER), 0.0)


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
	assert_eq((_level.get_node("%Zombie/Body") as AnimatedSprite2D).animation, &"walk")


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


func _is_generic(target: ZombieRunTarget) -> bool:
	return not target is BrainBlock


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


func test_generic_key_pays_nothing() -> void:
	_make(42, func(c: ZombieRunConfig) -> void: c.brainsss_chance = 1.0)
	_type_until(_is_generic)
	var before: int = _level.get_brains_earned()
	watch_signals(_level)
	_key()
	assert_eq(_level.get_brains_earned(), before)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_voices.size(), before, "no voice request for a generic target")
	assert_false(_zombie().is_hopping())


func test_hop_finishes_after_a_generic_key() -> void:
	_make()
	_type_until(func(t: ZombieRunTarget) -> bool:
		return t is BrainBlock and not _level.get_queue()[1] is BrainBlock)
	_key()
	assert_true(_zombie().is_hopping())
	var hop: Tween = _zombie().get_hop_tween()
	hop.custom_step(_cfg().hop_time_s * 0.4)
	assert_lt(_body_y(), -31.0, "mid-hop")
	_key()
	assert_true(_zombie().is_hopping(), "a generic key does not cut the hop")
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
