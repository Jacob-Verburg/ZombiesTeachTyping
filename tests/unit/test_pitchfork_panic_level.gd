extends GutTest
## Pitchfork Panic level (Story 8.3): the paragraph source, one correct key = one logical step in the
## key's own call, the mob advancing only between on_run_started and on_run_ending, the camera that keeps the
## zombie at 60% of the width every frame, the mob's screen rect and the left-edge glow, the interim caught
## ending (once), the used-passage hand-up, the frame cap. Story 8.4: brain pickups placed by distance from
## the second child RNG, collected in the key's own call (brains, signal, sound), their nodes on the path.
## Story 8.5: the two hooks (escaped at the clock, +25 escape bonus) and both outros by beats. Keys go
## through a real TypingSession wired like RunFrame; _process() is called with fixed deltas, never real time.
## Story 8.6: the ChaseMob (frozen until the run starts, frozen again at its end, its whole-mob rect), the dazed
## sit (with the tilt fallback), the outro sounds, the sprite
## ending nodes (frames and whole px, scale ONE throughout) and the static moon.
## Story 8.7: the whole mob walks in from the left edge (gap 25 puts the front frame's right edge at x 0).
## Story 10.4: the escape cover travels with the backdrop (ChaseBackdrop.escape_cover_sheet to %EscapeCover).
## Outro beats are driven with Tween.custom_step() on the level's outro tween (get_outro_tween()), so they are
## deterministic and fast; the tree's own frames add only a few real milliseconds on top.

const LevelScene: PackedScene = preload("res://scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn")
const STEP: float = 1.0 / 60.0
const ZOMBIE_SCREEN_X: float = 384.0

var _level: PitchforkPanicLevel
var _source: TargetSource
var _session: TypingSession
## The run RNG handed to the level (to check who draws from it).
var _run_rng: RandomNumberGenerator
## Sound effect ids the level played, in order (the play_sfx recorder).
var _sfx: Array[StringName] = []


func _make(rng_seed: int = 42, tweak: Callable = Callable()) -> PitchforkPanicLevel:
	_level = LevelScene.instantiate() as PitchforkPanicLevel
	_sfx = []
	_level.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	if tweak.is_valid():
		var cfg: PitchforkPanicConfig = (_level.config as PitchforkPanicConfig).duplicate(true)
		tweak.call(cfg)
		_level.config = cfg
	add_child_autofree(_level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	_run_rng = rng
	_source = _level.create_target_source(rng)
	if _source != null:
		_session = TypingSession.new(_source, _level.get_level_config())
		_session.run_started.connect(_level.on_run_started)
		_session.char_accepted.connect(_level.on_char_accepted)
		_session.char_rejected.connect(_level.on_char_rejected)
		_session.target_completed.connect(_level.on_target_completed)
	return _level


## Types the next `count` correct characters of the passage.
func _type(count: int) -> void:
	for i: int in count:
		var c: String = _session.get_current_target()[_session.get_cursor()]
		assert_eq(_session.judge(c), TypingSession.Verdict.CORRECT)


## Sets the logical gap by moving the mob (the model is public state on purpose, for tests and sims).
func _set_gap(gap: float) -> void:
	var model: ChaseModel = _level.get_model()
	model.mob_steps = float(model.zombie_steps) - gap
	_level._update_views()


func test_source_is_a_paragraph_source_and_the_level_never_draws_text() -> void:
	_make()
	assert_true(_source is ParagraphSource)
	assert_ne(_source.current(), "")
	assert_eq(_level.get_pool_label(), (_source as ParagraphSource).get_pool_label())
	assert_eq(_level.get_brains_earned(), 0)


func test_broken_config_gives_null_and_an_error() -> void:
	_make(42, func(cfg: PitchforkPanicConfig) -> void: cfg.start_gap_steps = 0.0)
	assert_null(_source)
	assert_push_error_count(1)


func test_missing_paragraphs_gives_null_and_an_error() -> void:
	_make(42, func(cfg: PitchforkPanicConfig) -> void: cfg.paragraphs = null)
	assert_null(_source)
	assert_push_error_count(1)


func test_one_correct_key_is_one_step_in_the_same_call() -> void:
	_make()
	var seen: Array[int] = []
	_session.char_accepted.connect(func(_e: String, _i: int) -> void: seen.append(_level.get_model().zombie_steps))
	var model: ChaseModel = _level.get_model()
	assert_eq(model.zombie_steps, 0)
	_type(3)
	assert_eq(model.zombie_steps, 3)
	# The level's own handler runs first (connected first), so each call already saw its step.
	assert_eq(seen, [1, 2, 3] as Array[int])
	assert_eq(model.gap(), (_level.config as PitchforkPanicConfig).start_gap_steps + 3.0)


func test_capitals_punctuation_and_spaces_all_step_and_wrong_keys_do_not() -> void:
	_make()
	var text: String = _session.get_current_target()
	var head: String = text.substr(0, 80)
	assert_ne(head, "")
	var has_capital: bool = head != head.to_lower()
	var has_space: bool = head.contains(" ")
	assert_true(has_capital and has_space, "the first 80 characters hold a capital and a space")
	_type(head.length())
	assert_eq(_level.get_model().zombie_steps, head.length())
	var before: int = _level.get_model().zombie_steps
	var expected: String = _session.get_current_target()[_session.get_cursor()]
	var wrong: String = "~" if expected != "~" else "^"
	assert_eq(_session.judge(wrong), TypingSession.Verdict.WRONG)
	assert_eq(_level.get_model().zombie_steps, before)
	# A capital typed as lowercase is wrong (case sensitive).
	var capital_at: int = -1
	for i: int in range(_session.get_cursor(), text.length()):
		if text[i] != text[i].to_lower():
			capital_at = i
			break
	assert_gt(capital_at, -1, "the passage has a capital ahead")
	_type(capital_at - _session.get_cursor())
	var steps: int = _level.get_model().zombie_steps
	assert_eq(_session.judge(text[capital_at].to_lower()), TypingSession.Verdict.WRONG)
	assert_eq(_level.get_model().zombie_steps, steps)


func test_process_does_nothing_before_the_run_starts_and_freezes_after() -> void:
	_make()
	var model: ChaseModel = _level.get_model()
	for i: int in 120:
		_level._process(STEP)
	assert_eq(model.elapsed_s, 0.0, "time before the first key never counts")
	_type(1)
	for i: int in 60:
		_level._process(STEP)
	assert_almost_eq(model.elapsed_s, 1.0, 1e-6)
	_level.on_run_ending(&"timer")
	var frozen: float = model.mob_steps
	for i: int in 60:
		_level._process(STEP)
	assert_eq(model.mob_steps, frozen)
	# A key judged after the end moves nothing.
	_level.on_char_accepted("x", 5)
	assert_eq(model.zombie_steps, 1)


func test_run_ending_returns_each_outro_length_once() -> void:
	_make()
	_type(2)
	assert_almost_eq(_level.on_run_ending(&"caught"), 1.5 + 1.0 + 0.5, 1e-6)
	var tween: Tween = _level.get_outro_tween()
	assert_almost_eq(_level.on_run_ending(&"caught"), 3.0, 1e-6, "a repeat returns the same")
	assert_almost_eq(_level.on_run_ending(&"escaped"), 3.0, 1e-6, "a repeat with another reason too")
	assert_same(_level.get_outro_tween(), tween, "a repeat call does not restart the outro")
	_make()
	_type(2)
	assert_almost_eq(_level.on_run_ending(&"escaped"), 1.5 + 1.0, 1e-6)
	_make()
	_type(2)
	assert_eq(_level.on_run_ending(&"timer"), 0.0, "an unknown reason has no outro")
	assert_null(_level.get_outro_tween())
	assert_almost_eq(_level.on_run_ending(&"caught"), 3.0, 1e-6, "an unknown reason does not block a real one")


func test_zombie_stays_at_60_percent_of_the_width_every_frame() -> void:
	_make()
	var zombie: Node2D = _level.get_node("%Zombie")
	var backdrop: ParallaxBackdrop = _level.get_node("%Backdrop")
	assert_almost_eq(zombie.global_position.x, ZOMBIE_SCREEN_X, 0.001, "first frame")
	assert_eq(_level.get_zombie_screen_x(), ZOMBIE_SCREEN_X)
	for i: int in 30:
		_type(1)
		_level._process(STEP)
		# Mid-tween: step the walk by hand (the tween is node-bound and the test does not wait for frames).
		var tween: Tween = _level._walk_tween
		assert_not_null(tween)
		if tween != null and tween.is_valid():
			tween.custom_step(0.03)
		assert_almost_eq(zombie.global_position.x, ZOMBIE_SCREEN_X, 0.001, "key %d" % i)
		var x: float = zombie.position.x
		assert_eq(backdrop.get_layer_offset(ParallaxBackdrop.LAYER_GROUND),
				fposmod(roundf(x - ZOMBIE_SCREEN_X), 640.0))
		assert_eq(zombie.global_position.y, PitchforkPanicLevel.GROUND_Y)
	# The sprite chases the logical position and arrives.
	var tween_done: Tween = _level._walk_tween
	tween_done.custom_step(1.0)
	assert_almost_eq(zombie.position.x, 30.0 * 16.0, 0.001)
	assert_almost_eq(zombie.global_position.x, ZOMBIE_SCREEN_X, 0.001)


func test_mob_is_fully_on_screen_for_gaps_under_20_and_off_it_at_30() -> void:
	_make()
	_type(1)
	# The sprite chases the logical step; finish the walk so the camera has caught up with the model.
	assert_not_null(_level._walk_tween, "the first key starts the walk")
	_level._walk_tween.custom_step(1.0)
	for gap: float in [1.0, 5.0, 10.0, 15.0, 19.0, 19.9]:
		_set_gap(gap)
		var rect: Rect2 = _level.get_mob_screen_rect()
		assert_true(rect.position.x >= 0.0 and rect.end.x <= 640.0, "gap %s rect %s" % [gap, rect])
		assert_true((_level.get_node("%Mob") as Node2D).visible, "gap %s shows the mob" % gap)
		var mob_x: float = (_level.get_node("%Mob") as Node2D).global_position.x
		assert_almost_eq(rect.position.x, mob_x - (_level.get_node("%Mob") as ChaseMob).get_back_px(), 1e-4, "gap %s: the rect starts at the back member" % gap)
	# Written-out oracles: gap 15 puts the mob's feet at screen x 144, gap 20 at 64.
	_set_gap(15.0)
	assert_eq((_level.get_node("%Mob") as Node2D).global_position.x, 144.0)
	_set_gap(30.0)
	var far: Rect2 = _level.get_mob_screen_rect()
	assert_true(far.end.x <= 0.0 or far.position.x >= 640.0, "gap 30 is off screen: %s" % far)


## Story 8.7 (Smuck's playtest call): no tips-only hint; the whole mob, villagers with their pitchforks and
## torches, walks in together from the left edge. It is first drawn while its front member is still off
## screen (gap 25 puts the front frame's right edge at x 0), so it never pops in on screen.
func test_the_whole_mob_walks_in_from_the_left_edge() -> void:
	_make()
	_type(1)
	assert_not_null(_level._walk_tween, "the first key starts the walk")
	_level._walk_tween.custom_step(1.0)
	assert_false(_level.has_node("%MobHint"), "the 8.6 hint is gone")
	var mob: Node2D = _level.get_node("%Mob")
	_set_gap(25.0)
	assert_false(mob.visible, "gap 25: not drawn yet")
	assert_almost_eq(_level.get_mob_screen_rect().end.x, 0.0, 1e-4, "gap 25: the front frame ends at the edge")
	_set_gap(30.0)
	assert_false(mob.visible, "gap 30: not drawn")
	for gap: float in [24.9, 23.0, 22.0, 21.0]:
		_set_gap(gap)
		var rect: Rect2 = _level.get_mob_screen_rect()
		assert_true(mob.visible, "gap %s: drawn" % gap)
		assert_lt(rect.position.x, 0.0, "gap %s: the back members still off the left edge" % gap)
		assert_gt(rect.end.x, 0.0, "gap %s: the front member is coming in" % gap)
	# Shown, then pushed back out: hidden again.
	_set_gap(25.0)
	assert_false(mob.visible, "gap 25 after being shown: hidden again")


func test_caught_emits_the_ending_exactly_once() -> void:
	_make()
	_type(1)
	watch_signals(_level)
	_set_gap(0.01)
	_level._process(STEP)
	_level._process(STEP)
	_level._process(STEP)
	assert_signal_emit_count(_level, "end_requested", 1)
	assert_signal_emitted_with_parameters(_level, "end_requested", [GameConstants.END_REASON_CAUGHT])


func test_used_passages_are_handed_up_at_the_start_and_on_each_completion() -> void:
	_make()
	watch_signals(_level)
	_type(1)
	assert_signal_emit_count(_level, "used_passages_changed", 1)
	var ids: Array = get_signal_parameters(_level, "used_passages_changed", 0)[0]
	assert_true(ids.has((_source as ParagraphSource).get_current_id()), "the current passage is in the list")
	_level.on_target_completed("x")
	assert_signal_emit_count(_level, "used_passages_changed", 2)


func test_a_hitch_advances_the_mob_by_at_most_the_frame_cap() -> void:
	_make()
	_type(1)
	_level._process(10.0)
	assert_almost_eq(_level.get_model().elapsed_s, PitchforkPanicLevel.MAX_FRAME_S, 1e-6)
	_level._process(NAN)
	assert_almost_eq(_level.get_model().elapsed_s, PitchforkPanicLevel.MAX_FRAME_S, 1e-6)


func test_the_level_pauses_with_the_tree() -> void:
	_make()
	assert_eq(_level.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(_level.can_process(), "runs while the tree runs")
	get_tree().paused = true
	var paused_can_process: bool = _level.can_process()
	get_tree().paused = false
	assert_false(paused_can_process, "frozen while the tree is paused (PAUSED, COUNTDOWN)")


func test_same_seed_deals_the_same_text() -> void:
	_make(7)
	var first: String = _source.current()
	_make(7)
	assert_eq(_source.current(), first)


# --- brain pickups (Story 8.4) ------------------------------------------------

func _first_pickup() -> int:
	var upcoming: Array[int] = _level.get_pickup_trail().upcoming()
	assert_gt(upcoming.size(), 0, "pickups are placed at create_target_source")
	return upcoming[0] if not upcoming.is_empty() else 0


func _pickup_nodes() -> Array[BrainPickup]:
	var nodes: Array[BrainPickup] = []
	for child: Node in _level.get_node("%Pickups").get_children():
		if child is BrainPickup and not child.is_queued_for_deletion():
			nodes.append(child as BrainPickup)
	return nodes


## BrainPops in %World (drawn in front of the zombie: Smuck's layout call).
func _pops() -> Array[BrainPop]:
	var pops: Array[BrainPop] = []
	for child: Node in _level.get_node("%World").get_children():
		if child is BrainPop:
			pops.append(child as BrainPop)
	return pops


func test_first_pickup_pays_5_on_exactly_its_key_in_the_same_call() -> void:
	_make()
	watch_signals(_level)
	var first: int = _first_pickup()
	assert_between(first, 10, 30)
	assert_lt(first, _session.get_current_target().length(), "the first pickup is inside the first passage")
	# Seen from a handler connected after the level's: the award already happened in the key's own call.
	var seen: Array[int] = []
	_session.char_accepted.connect(func(_e: String, _i: int) -> void: seen.append(_level.get_brains_earned()))
	_type(first - 1)
	assert_eq(_level.get_brains_earned(), 0, "not one key early")
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_sfx, [] as Array[StringName])
	_type(1)
	assert_eq(seen[seen.size() - 1], 5, "paid in the key's call, before any _process")
	assert_eq(_level.get_brains_earned(), 5)
	assert_signal_emit_count(_level, "brains_earned_changed", 1)
	assert_signal_emitted_with_parameters(_level, "brains_earned_changed", [5])
	assert_eq(_sfx, [&"sfx_brain_pickup"] as Array[StringName])


func test_several_pickups_emit_the_running_total_once_each() -> void:
	_make()
	watch_signals(_level)
	# Only the lookahead is placed up front, so type until the third pickup (at most 90 steps) is taken.
	var length: int = _session.get_current_target().length()
	var keys: int = 0
	while _level.get_brains_earned() < 15 and keys < mini(length, 90):
		_type(1)
		keys += 1
	assert_eq(_level.get_brains_earned(), 15)
	assert_signal_emit_count(_level, "brains_earned_changed", 3)
	for i: int in 3:
		assert_eq(get_signal_parameters(_level, "brains_earned_changed", i), [5 * (i + 1)])
	assert_eq(_sfx, [&"sfx_brain_pickup", &"sfx_brain_pickup", &"sfx_brain_pickup"] as Array[StringName])


func test_wrong_keys_collect_nothing() -> void:
	_make()
	watch_signals(_level)
	var first: int = _first_pickup()
	_type(first - 1)
	var expected: String = _session.get_current_target()[_session.get_cursor()]
	var wrong: String = "~" if expected != "~" else "^"
	for i: int in 5:
		assert_eq(_session.judge(wrong), TypingSession.Verdict.WRONG)
	assert_eq(_level.get_brains_earned(), 0)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_sfx, [] as Array[StringName])


func test_keys_before_the_run_starts_collect_nothing() -> void:
	_make()
	watch_signals(_level)
	for i: int in 40:
		_level.on_char_accepted("x", i)
	assert_eq(_level.get_model().zombie_steps, 0)
	assert_eq(_level.get_brains_earned(), 0)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_sfx, [] as Array[StringName])


func test_keys_after_the_run_ends_collect_nothing() -> void:
	_make()
	watch_signals(_level)
	var first: int = _first_pickup()
	_type(first - 1)
	_level.on_run_ending(&"timer")
	for i: int in 40:
		_level.on_char_accepted("x", first + i)
	assert_eq(_level.get_brains_earned(), 0)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_sfx, [] as Array[StringName])
	assert_eq(_pickup_nodes().size(), _level.get_pickup_trail().upcoming().size(), "remaining nodes stay")


func test_run_rng_gives_two_child_seeds_and_nothing_else() -> void:
	_make(42)
	var expected: RandomNumberGenerator = RandomNumberGenerator.new()
	expected.seed = 42
	expected.randi()
	expected.randi()
	assert_eq(_run_rng.state, expected.state, "paragraph child + pickup child")
	_type(1)
	for i: int in 199:
		_level.on_char_accepted("x", i + 1)
		_level._process(STEP)
	assert_gt(_level.get_brains_earned(), 0, "the 200 keys collected pickups")
	assert_eq(_run_rng.state, expected.state, "no other consumer of the run RNG")


func test_seed_42_deals_the_same_first_passage_as_before_pickups() -> void:
	_make(42)
	var oracle: RandomNumberGenerator = RandomNumberGenerator.new()
	oracle.seed = 42
	var child: RandomNumberGenerator = RandomNumberGenerator.new()
	child.seed = oracle.randi()
	var paragraphs: ParagraphSource = ParagraphSource.for_level(child, _level.config, _level.tier,
			_level.tier_config, _level.used_passages)
	assert_not_null(paragraphs)
	if paragraphs != null:
		assert_eq(_source.current(), paragraphs.current())


func test_same_seed_places_the_same_pickups() -> void:
	_make(42)
	var first: Array[int] = _level.get_pickup_trail().upcoming()
	assert_gt(first.size(), 0)
	_make(42)
	assert_eq(_level.get_pickup_trail().upcoming(), first)
	# Independent oracle: the trail's RNG is seeded with the run RNG's second draw.
	var oracle: RandomNumberGenerator = RandomNumberGenerator.new()
	oracle.seed = 42
	oracle.randi()
	var pickup_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pickup_rng.seed = oracle.randi()
	assert_eq(first[0], pickup_rng.randi_range(10, 30))


func test_every_placed_pickup_has_a_node_on_the_ground_line() -> void:
	_make()
	var upcoming: Array[int] = _level.get_pickup_trail().upcoming()
	var nodes: Array[BrainPickup] = _pickup_nodes()
	assert_gt(nodes.size(), 0)
	assert_eq(nodes.size(), upcoming.size())
	for i: int in mini(nodes.size(), upcoming.size()):
		assert_eq(nodes[i].position, Vector2(upcoming[i] * 16.0, PitchforkPanicLevel.GROUND_Y))


func test_the_furthest_pickup_is_always_past_the_right_edge() -> void:
	_make()
	var model: ChaseModel = _level.get_model()
	var cfg: PitchforkPanicConfig = _level.config as PitchforkPanicConfig
	var visible_ahead: int = ceili((PitchforkPanicLevel.SCREEN_W - _level.get_zombie_screen_x()) / cfg.step_px)
	visible_ahead += PitchforkPanicLevel.PICKUP_LOOKAHEAD_MARGIN_STEPS
	for i: int in 120:
		var upcoming: Array[int] = _level.get_pickup_trail().upcoming()
		assert_gt(upcoming.size(), 0)
		if upcoming.is_empty():
			return
		assert_gte(upcoming[upcoming.size() - 1], model.zombie_steps + visible_ahead, "key %d" % i)
		_type(1)


func test_a_collected_node_pops_and_is_freed() -> void:
	_make()
	var first: int = _first_pickup()
	var node: BrainPickup = _pickup_nodes()[0]
	assert_eq(node.position.x, first * 16.0)
	_type(first)
	assert_true(node.is_queued_for_deletion())
	var pops: Array[BrainPop] = _pops()
	assert_eq(pops.size(), 1)
	if pops.size() == 1:
		assert_gt(pops[0].get_index(), _level.get_node("%Zombie").get_index(), "the pop rises in front")
		assert_eq(pops[0].position.x, first * 16.0)
	assert_false(_level.get_pickup_trail().upcoming().has(first))


func test_pickups_draw_behind_the_mob_and_the_zombie() -> void:
	_make()
	var pickups: Node = _level.get_node("%Pickups")
	assert_eq(pickups.get_parent(), _level.get_node("%World"))
	assert_lt(pickups.get_index(), _level.get_node("%Mob").get_index())
	assert_lt(pickups.get_index(), _level.get_node("%Zombie").get_index())


# --- Story 8.5: endings ---


func test_the_clock_ends_the_run_as_escaped_with_a_25_bonus() -> void:
	_make()
	assert_eq(_level.get_timer_end_reason(), GameConstants.END_REASON_ESCAPED)
	assert_eq(_level.get_end_bonus(&"escaped"), 25)
	assert_eq(_level.get_end_bonus(&"caught"), 0)
	assert_eq(_level.get_end_bonus(&"timer"), 0)


func test_hooks_and_ending_are_safe_without_a_config() -> void:
	_level = LevelScene.instantiate() as PitchforkPanicLevel
	_level.config = null
	_level.play_sfx = func(_id: StringName) -> void: pass
	add_child_autofree(_level)
	assert_push_error_count(1)
	assert_eq(_level.get_timer_end_reason(), GameConstants.END_REASON_ESCAPED)
	assert_eq(_level.get_end_bonus(&"escaped"), 0)
	assert_eq(_level.on_run_ending(&"caught"), 0.0)


func _visible(unique: String) -> bool:
	return (_level.get_node(unique) as CanvasItem).visible


func test_caught_outro_by_beats() -> void:
	_make()
	_type(3)
	var label: Label = _level.get_node("%EndLabel")
	var fade: ColorRect = _level.get_node("%Fade")
	var zombie: Node2D = _level.get_node("%Zombie")
	assert_false(_visible("%DustCloud"))
	_level.on_run_ending(&"caught")
	var tween: Tween = _level.get_outro_tween()
	tween.custom_step(0.1)
	assert_true(_visible("%DustCloud"), "t=0.1: the cloud covers the scuffle")
	assert_eq((_level.get_node("%DustCloud") as Node2D).position.x, zombie.position.x, "on the zombie")
	assert_false(label.visible)
	assert_false(_visible("%DizzyStars"))
	tween.custom_step(1.5)
	assert_false(_visible("%DustCloud"), "t=1.6: the cloud is gone")
	assert_true(_visible("%DizzyStars"))
	assert_true(label.visible)
	assert_eq(label.text, "Got you!")
	assert_eq(fade.modulate.a, 0.0)
	assert_true((zombie as PlayerZombie).is_dazed(), "sitting dazed")
	assert_eq(zombie.rotation_degrees, 0.0, "never a rotation of pixel art")
	assert_eq(zombie.position.y, PitchforkPanicLevel.GROUND_Y)
	var stars: Node2D = _level.get_node("%DizzyStars")
	assert_eq(stars.position.x, zombie.position.x)
	assert_lt(stars.position.y, PitchforkPanicLevel.GROUND_Y - 22.0, "above the dazed crown")
	tween.custom_step(1.3)
	assert_gt(fade.modulate.a, 0.5, "t=2.9: fading to night")
	assert_true(zombie.is_inside_tree())
	assert_true(zombie.visible)
	tween.custom_step(0.2)
	assert_almost_eq(fade.modulate.a, 1.0, 1e-6)


func test_the_fade_covers_the_hud_band_in_night() -> void:
	_make()
	var layer: CanvasLayer = _level.get_node("FadeLayer")
	assert_eq(layer.layer, 10, "over the HUD, under Router's 100")
	var fade: ColorRect = _level.get_node("%Fade")
	assert_eq(fade.color, Color("#2B1D3F"))
	assert_eq(fade.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(fade.size, Vector2(640.0, 360.0))


func test_end_label_is_candy_yellow_with_an_ink_outline_and_readable() -> void:
	_make()
	var label: Label = _level.get_node("%EndLabel")
	assert_eq(label.get_theme_color(&"font_color"), Color("#FFD23F"))
	assert_eq(label.get_theme_color(&"font_outline_color"), Color("#1E1428"))
	assert_gte(label.get_theme_font_size(&"font_size"), 16)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_got_you_stays_inside_the_playfield() -> void:
	_make()
	_type(3)
	_level.on_run_ending(&"caught")
	_level.get_outro_tween().custom_step(1.6)
	var label: Label = _level.get_node("%EndLabel")
	assert_gte(label.position.x, 0.0)
	assert_lte(label.position.x + label.size.x, PitchforkPanicLevel.SCREEN_W)
	var centre: float = label.position.x + label.size.x / 2.0
	var zombie_screen_x: float = (_level.get_node("%Zombie") as Node2D).global_position.x
	assert_almost_eq(centre, zombie_screen_x, 1.0, "centred over the zombie")


func test_escape_outro_by_beats_with_the_camera_stopped() -> void:
	_make()
	_type(3)
	var world: Node2D = _level.get_node("%World")
	var zombie: Node2D = _level.get_node("%Zombie")
	var label: Label = _level.get_node("%EndLabel")
	var world_x: float = world.position.x
	var start_x: float = zombie.position.x
	_level.on_run_ending(&"escaped")
	var tween: Tween = _level.get_outro_tween()
	tween.custom_step(0.1)
	assert_true(_visible("%EscapeCover"), "t=0.1: the cover is there")
	assert_true(zombie.visible)
	assert_gt(zombie.position.x, start_x, "running at the cover")
	var cover: Node2D = _level.get_node("%EscapeCover")
	assert_almost_eq(cover.position.x, start_x + PitchforkPanicLevel.ESCAPE_COVER_AHEAD_PX, 1e-3)
	assert_false(label.visible)
	tween.custom_step(1.5)
	assert_false(zombie.visible, "t=1.6: into the cover")
	assert_true(label.visible)
	assert_eq(label.text, "Escaped!")
	assert_almost_eq(label.position.x + label.size.x / 2.0, 320.0, 1.0)
	assert_eq(world.position.x, world_x, "the camera stopped for the dive")
	assert_eq((_level.get_node("%Fade") as ColorRect).modulate.a, 0.0, "no fade: the Router fades next")


func test_endings_hide_the_pickups_and_keep_the_brains() -> void:
	for reason: StringName in [&"caught", &"escaped"]:
		_make()
		var first: int = _first_pickup()
		_type(first)
		assert_eq(_level.get_brains_earned(), 5)
		_level.on_run_ending(reason)
		assert_false(_visible("%Pickups"), "%s: pickups left on the path disappear" % reason)
		assert_eq(_level.get_brains_earned(), 5)
		_level.on_char_accepted("x", 999)
		assert_eq(_level.get_model().zombie_steps, first, "%s: keys after the end move nothing" % reason)


func test_endings_draw_in_front_of_the_mob_and_the_zombie() -> void:
	_make()
	var zombie_index: int = _level.get_node("%Zombie").get_index()
	for unique: String in ["%EscapeCover", "%DustCloud", "%DizzyStars"]:
		var node: Node = _level.get_node(unique)
		assert_eq(node.get_parent(), _level.get_node("%World"), unique)
		assert_gt(node.get_index(), zombie_index, unique)
		assert_false((node as CanvasItem).visible, "%s starts hidden" % unique)


func test_freeing_the_level_mid_outro_stops_everything() -> void:
	_make()
	_type(3)
	_level.on_run_ending(&"caught")
	var tween: Tween = _level.get_outro_tween()
	tween.custom_step(0.5)
	var dust: Tween = (_level.get_node("%DustCloud") as DustCloud).get_tween()
	remove_child(_level)
	_level.free()
	# A tween whose bound node is gone is killed on its next tree step.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(tween.is_valid(), "the outro died with the level")
	assert_false(dust.is_valid())


func test_dust_cloud_steps_frames_by_whole_px_and_hides_after_play() -> void:
	var cloud: DustCloud = DustCloud.new()
	add_child_autofree(cloud)
	cloud.position.x = 40.0
	cloud.play(0.5)
	assert_true(cloud.visible)
	var frames_seen: Dictionary[int, bool] = {}
	for i: int in 5:
		cloud.get_tween().custom_step(0.09)
		frames_seen[cloud.get_frame()] = true
		assert_eq(cloud.scale, Vector2.ONE, "never scaled")
		assert_eq(cloud.rotation, 0.0)
		assert_eq(cloud.position.x, roundf(cloud.position.x), "whole px")
		assert_between(cloud.position.x, 40.0 - DustCloud.JITTER_PX, 40.0 + DustCloud.JITTER_PX)
	assert_gt(frames_seen.size(), 1, "the frames step")
	cloud.get_tween().custom_step(0.6)
	assert_false(cloud.visible)
	assert_eq(cloud.scale, Vector2.ONE)
	assert_eq(cloud.position.x, 40.0, "ends at its base x")


func test_dust_cloud_sprite_is_the_sheet_standing_on_the_origin() -> void:
	var cloud: DustCloud = DustCloud.new()
	add_child_autofree(cloud)
	var sprite: AnimatedSprite2D = cloud.get_node("Sprite")
	assert_not_null(sprite.sprite_frames)
	assert_eq(sprite.sprite_frames.get_frame_count(DustCloud.ANIM), 4)
	assert_eq(sprite.position, Vector2(-24.0, -47.0))
	assert_false(sprite.centered)


func test_dizzy_stars_orbit_while_shown_and_stop_hides() -> void:
	var stars: DizzyStars = DizzyStars.new()
	stars.visible = false
	add_child_autofree(stars)
	stars.start()
	assert_true(stars.visible)
	assert_eq(stars.get_stars().size(), 3)
	stars._process(0.25)
	assert_almost_eq(stars.get_angle(), TAU * 0.25, 1e-4)
	for star: AnimatedSprite2D in stars.get_stars():
		assert_eq(star.position, star.position.round(), "whole px")
		assert_eq(star.scale, Vector2.ONE)
	stars.stop()
	assert_false(stars.visible)
	assert_false(stars.is_processing())


func test_escape_cover_rustles_by_frames_and_ends_on_the_still_frame() -> void:
	var cover: EscapeCover = EscapeCover.new()
	add_child_autofree(cover)
	cover.position.x = 12.0
	assert_eq(cover.get_frame(), 0, "still before the dive")
	cover.rustle(0.3)
	cover.get_tween().custom_step(0.1)
	assert_true(cover.get_frame() in [1, 2], "rustling")
	assert_eq(cover.scale, Vector2.ONE, "never squashed")
	cover.get_tween().custom_step(0.3)
	assert_eq(cover.get_frame(), 0, "ends on the still frame")
	assert_eq(cover.scale, Vector2.ONE)
	assert_eq(cover.position.x, 12.0, "at its base x")



# --- Story 8.6 ---

func test_the_mob_is_a_chase_mob_frozen_until_the_run_and_after_it() -> void:
	_make()
	var mob: ChaseMob = _level.get_node("%Mob") as ChaseMob
	assert_not_null(mob, "%Mob is a ChaseMob")
	assert_eq(mob.get_parent(), _level.get_node("%World"))
	assert_gt(_level.get_node("%Zombie").get_index(), mob.get_index(), "the zombie draws over the mob")
	assert_gt(mob.get_index(), _level.get_node("%Pickups").get_index(), "the mob draws over the pickups")
	for member: AnimatedSprite2D in mob.get_members():
		assert_false(member.is_playing(), "frozen before on_run_started")
	_type(1)
	for member: AnimatedSprite2D in mob.get_members():
		assert_true(member.is_playing(), "running after on_run_started")
	_level.on_run_ending(&"caught")
	for member: AnimatedSprite2D in mob.get_members():
		assert_false(member.is_playing(), "frozen after on_run_ending")


func test_dazed_without_the_sheet_falls_back_to_the_tilt() -> void:
	_make()
	_type(3)
	var zombie: PlayerZombie = _level.get_node("%Zombie")
	var body: AnimatedSprite2D = zombie.get_node("Body")
	var frames: SpriteFrames = body.sprite_frames.duplicate() as SpriteFrames
	frames.remove_animation(PlayerZombie.ANIM_DAZED)
	body.sprite_frames = frames
	_level.on_run_ending(&"caught")
	_level.get_outro_tween().custom_step(1.6)
	assert_false(zombie.is_dazed())
	assert_eq(zombie.rotation_degrees, PitchforkPanicLevel.DAZED_TILT_DEG)
	assert_eq(zombie.position.y, PitchforkPanicLevel.GROUND_Y + PitchforkPanicLevel.DAZED_DROP_PX)


## The stars sit just above the dazed head: the dazed anchor's crown (feet row 31 minus its row) plus a little.
func test_stars_sit_just_above_the_dazed_crown() -> void:
	var anchors: SpriteAnchors = load("res://data/anchors/zombie_anchors.tres") as SpriteAnchors
	var crown_above_feet: float = 31.0 - anchors.get_head(PlayerZombie.ANIM_DAZED, 0).y
	assert_gt(PitchforkPanicLevel.STARS_ABOVE_FEET_PX, crown_above_feet)
	assert_lte(PitchforkPanicLevel.STARS_ABOVE_FEET_PX, crown_above_feet + 8.0)


func test_caught_plays_the_dust_cloud_sound_once() -> void:
	_make()
	_type(3)
	_sfx.clear()
	_level.on_run_ending(&"caught")
	_level.on_run_ending(&"caught")
	_level.get_outro_tween().custom_step(5.0)
	assert_eq(_sfx, [PitchforkPanicLevel.SFX_DUST_CLOUD] as Array[StringName])
	assert_eq(PitchforkPanicLevel.SFX_DUST_CLOUD, &"sfx_dust_cloud")


func test_escaped_plays_the_escape_sound_once() -> void:
	_make()
	_type(3)
	_sfx.clear()
	_level.on_run_ending(&"escaped")
	_level.on_run_ending(&"caught")
	_level.get_outro_tween().custom_step(5.0)
	assert_eq(_sfx, [PitchforkPanicLevel.SFX_ESCAPE] as Array[StringName])
	assert_eq(PitchforkPanicLevel.SFX_ESCAPE, &"sfx_escape")


func test_an_unknown_ending_plays_no_sound() -> void:
	_make()
	_type(3)
	_sfx.clear()
	_level.on_run_ending(&"quit")
	assert_eq(_sfx.size(), 0)


func test_the_pickup_sound_id_is_unchanged() -> void:
	assert_eq(PitchforkPanicLevel.SFX_PICKUP, &"sfx_brain_pickup")


func test_the_moonlit_backdrop_and_a_static_moon() -> void:
	_make()
	var backdrop: ParallaxBackdrop = _level.get_node("%Backdrop")
	assert_eq((backdrop.get_node("Sky") as ColorRect).color, Color("#2B1D3F"), "a night sky")
	var ground: Sprite2D = backdrop.get_node("Ground/A")
	assert_eq(ground.texture.resource_path, "res://assets/sprites/backdrops/moonlit_village/ground_strip.png")
	var moon: Sprite2D = backdrop.get_node("Moon")
	var moon_at: Vector2 = moon.global_position
	assert_false(moon.centered)
	assert_lt(moon_at.x + 48.0, 600.0, "clear of the pause button corner")
	_type(10)
	assert_not_null(_level._walk_tween, "the first key starts the walk")
	_level._walk_tween.custom_step(1.0)
	assert_ne(backdrop.get_layer_offset(ParallaxBackdrop.LAYER_GROUND), 0.0, "the street scrolled")
	assert_eq(moon.global_position, moon_at, "the moon stays put")


# --- Story 10.4: the escape cover travels with the backdrop ---

const BUSH_PATH: String = "res://assets/sprites/props/escape_bush.png"
const TestChaseBackdrop: PackedScene = preload("res://tests/fixtures/levels/test_chase_backdrop.tscn")
const DUST_SHEET_PATH: String = "res://assets/sprites/props/dust_cloud.png"


## The level with `backdrop` swapped into the %Backdrop slot before it enters the tree (as RunFrame does).
func _make_with_backdrop(backdrop: PackedScene, before_add: Callable = Callable()) -> PitchforkPanicLevel:
	_level = LevelScene.instantiate() as PitchforkPanicLevel
	_sfx = []
	_level.play_sfx = func(id: StringName) -> void: _sfx.append(id)
	var theme: LevelTheme = LevelTheme.new()
	theme.id = &"test"
	theme.backdrop = backdrop
	_level.apply_theme(theme)
	if before_add.is_valid():
		before_add.call(_level.get_node("%Backdrop"))
	add_child_autofree(_level)
	return _level


func test_the_moonlit_village_dives_into_the_bush() -> void:
	_make()
	var cover: EscapeCover = _level.get_node("%EscapeCover")
	assert_true(_level.get_node("%Backdrop") is ChaseBackdrop, "the Moonlit Village is a ChaseBackdrop")
	assert_not_null(cover.get_sheet())
	assert_eq(cover.get_sheet().resource_path, BUSH_PATH)
	assert_push_warning_count(0)


func test_a_chase_backdrop_brings_its_own_cover() -> void:
	_make_with_backdrop(TestChaseBackdrop)
	var cover: EscapeCover = _level.get_node("%EscapeCover")
	assert_eq(cover.get_sheet().resource_path, DUST_SHEET_PATH, "the setting's sheet")
	var sprite: AnimatedSprite2D = cover.get_node("Sprite")
	assert_eq(sprite.sprite_frames.get_frame_count(EscapeCover.ANIM), 3)
	assert_eq((sprite.sprite_frames.get_frame_texture(EscapeCover.ANIM, 0) as AtlasTexture).atlas.resource_path,
			DUST_SHEET_PATH)
	assert_eq(sprite.position, Vector2(-24.0, -47.0), "same contract")
	# The escape outro shows that sheet.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	assert_not_null(_level.create_target_source(rng))
	_level.on_run_ending(&"escaped")
	_level.get_outro_tween().custom_step(1.7)
	assert_true(cover.visible)
	assert_eq(cover.get_sheet().resource_path, DUST_SHEET_PATH)
	var shown: AtlasTexture = sprite.sprite_frames.get_frame_texture(EscapeCover.ANIM, sprite.frame) as AtlasTexture
	assert_eq(shown.atlas.resource_path, DUST_SHEET_PATH, "the outro shows the setting's sheet")
	assert_eq(sprite.sprite_frames.get_frame_count(EscapeCover.ANIM), 3)
	assert_push_warning_count(0)


func test_a_chase_backdrop_without_a_sheet_warns_and_keeps_the_bush() -> void:
	_make_with_backdrop(TestChaseBackdrop, func(node: Node) -> void: (node as ChaseBackdrop).escape_cover_sheet = null)
	var cover: EscapeCover = _level.get_node("%EscapeCover")
	assert_eq(cover.get_sheet().resource_path, BUSH_PATH)
	assert_push_warning("no escape cover sheet")
	assert_push_warning_count(1)


func test_a_chase_backdrop_with_a_too_small_sheet_warns_once_and_keeps_the_bush() -> void:
	var small: Texture2D = load("res://assets/sprites/props/dizzy_star.png") as Texture2D
	_make_with_backdrop(TestChaseBackdrop, func(node: Node) -> void: (node as ChaseBackdrop).escape_cover_sheet = small)
	var cover: EscapeCover = _level.get_node("%EscapeCover")
	assert_eq(cover.get_sheet().resource_path, BUSH_PATH)
	assert_push_warning("smaller than 3 frames of 48 px")
	assert_push_warning_count(1)


func test_a_plain_backdrop_keeps_the_bush_silently() -> void:
	_make_with_backdrop(preload("res://tests/fixtures/levels/test_backdrop.tscn"))
	assert_eq((_level.get_node("%EscapeCover") as EscapeCover).get_sheet().resource_path, BUSH_PATH)
	assert_push_warning_count(0)


func test_a_too_small_cover_sheet_warns_and_keeps_the_frames() -> void:
	var cover: EscapeCover = EscapeCover.new()
	add_child_autofree(cover)
	assert_false(cover.use_sheet(load("res://assets/sprites/props/dizzy_star.png") as Texture2D))
	assert_push_warning("smaller than 3 frames of 48 px")
	assert_push_warning_count(1)
	var sprite: AnimatedSprite2D = cover.get_node("Sprite")
	assert_eq(sprite.sprite_frames.get_frame_count(EscapeCover.ANIM), 3)
	assert_eq(cover.get_sheet().resource_path, BUSH_PATH)
	assert_false(cover.use_sheet(null), "null changes nothing")
	assert_eq(cover.get_sheet().resource_path, BUSH_PATH)


func test_use_sheet_stops_a_rustle_and_shows_the_still_frame() -> void:
	var cover: EscapeCover = EscapeCover.new()
	add_child_autofree(cover)
	cover.rustle(0.3)
	cover.get_tween().custom_step(0.1)
	assert_true(cover.get_frame() in [1, 2])
	assert_true(cover.use_sheet(load(DUST_SHEET_PATH) as Texture2D))
	assert_false(cover.get_tween().is_valid(), "the rustle stopped")
	assert_eq(cover.get_frame(), 0)
	assert_push_warning_count(0)
