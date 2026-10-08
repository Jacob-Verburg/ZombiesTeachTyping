extends GutTest
## Horde Rush level (Story 6.3): the word source and band, a copy per completed word in the key's own
## call (lane, x, scale, hat slot), the march derived from HordeField's logic, arrival frees the copy,
## on_run_ending() freezes the march, brains stay 0, seed replay of words and lanes (words seeded first,
## lanes second), and an invalid config fails safely. The level is disabled (nothing advances by itself):
## tests call _process(delta) with fixed steps. Keys go through a real TypingSession wired like RunFrame.
## Story 6.4: the defender (idle until on_run_started), projectile views, the hit flash, the melt, the
## freeze at the end, the reset on re-create, and substepping. Node-bound tweens only move with
## custom_step here (the level is disabled).
## Story 6.5: arrival brains per class, brains_earned_changed, the "Brainsss" seam (a recorder set before
## add_child, so no test calls the live AudioManager), the shuffle-in and "+N" pop one-shots, the hitch
## cap and the outro (dance, tomatoes cleared, outro_time_s returned).

const LevelScene: PackedScene = preload("res://scenes/levels/horde_rush/horde_rush_level.tscn")
const LevelScript := preload("res://scripts/levels/horde_rush/horde_rush_level.gd")
const STEP: float = 1.0 / 60.0

var _level: LevelScript
var _source: TargetSource
var _session: TypingSession
var _voices: Array[StringName] = []


## `tweak` (optional) changes a deep duplicate of the shipped config before the level is added.
func _make(rng_seed: int = 42, tweak: Callable = Callable()) -> LevelScript:
	_level = LevelScene.instantiate() as LevelScript
	_level.process_mode = Node.PROCESS_MODE_DISABLED
	if tweak.is_valid():
		var config: HordeRushConfig = (_level.config as HordeRushConfig).duplicate(true) as HordeRushConfig
		tweak.call(config)
		_level.config = config
	_voices = []
	_level.request_voice = func(id: StringName) -> void: _voices.append(id)
	add_child_autofree(_level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	_source = _level.create_target_source(rng)
	if _source != null:
		_session = TypingSession.new(_source, _level.get_level_config())
		_session.char_accepted.connect(_level.on_char_accepted)
		_session.char_rejected.connect(_level.on_char_rejected)
		_session.target_completed.connect(_level.on_target_completed)
	return _level


## Types the whole current word; returns it.
func _type_word() -> String:
	var word: String = _session.get_current_target()
	for c: String in word:
		assert_eq(_session.judge(c), TypingSession.Verdict.CORRECT)
	return word


func _steps(seconds: float) -> void:
	for i: int in roundi(seconds / STEP):
		_level._process(STEP)


func test_source_is_a_word_source_in_the_band() -> void:
	_make()
	assert_true(_source is WordSource)
	for word: String in _source.peek(60):
		assert_between(word.length(), 3, 5, word)


func test_layout_values_fit_above_the_hud() -> void:
	_make()
	var lanes: int = (_level.config as HordeRushConfig).lane_count
	assert_eq(_level.lane_feet_y(0), 74.0)
	assert_eq(_level.lane_feet_y(4), 250.0)
	assert_true(LevelScript.FIELD_TOP_Y + lanes * LevelScript.LANE_HEIGHT_PX <= LevelScript.FIELD_BOTTOM_Y)
	assert_eq(_level.march_x(0.0), LevelScript.SPAWN_X)
	assert_eq(_level.march_x(1.0), LevelScript.ARRIVE_X)
	assert_true(LevelScript.ARRIVE_X < LevelScript.HOUSE_FRONT_X)


func test_every_scale_spawns_on_screen_and_arrives_at_the_house_front() -> void:
	_make()
	for sprite_scale: float in [1.0, 1.25, 1.5]:
		var half_width: float = LevelScript.SPRITE_HALF_WIDTH_PX * sprite_scale
		assert_eq(_level.march_x(0.0, sprite_scale) - half_width, 0.0, "left edge at 0 for %s" % sprite_scale)
		assert_eq(_level.march_x(1.0, sprite_scale) + half_width, LevelScript.HOUSE_FRONT_X,
			"right edge on the wall for %s" % sprite_scale)


func test_a_completed_word_spawns_one_copy_in_the_same_call() -> void:
	_make()
	var counts: Array[int] = []
	_session.target_completed.connect(func(_w: String) -> void: counts.append(_level.get_view_count()))
	assert_eq(_level.get_view_count(), 0)
	var word: String = _session.get_current_target()
	for i: int in word.length() - 1:
		_session.judge(word[i])
		assert_eq(_level.get_view_count(), 0, "mid-word: nothing yet")
	_session.judge(word[word.length() - 1])
	assert_eq(counts, [1] as Array[int], "spawned inside the key's call")
	assert_eq(_level.get_view_count(), 1)
	assert_eq(_level.get_field().get_spawned_count(), 1)


func test_wrong_keys_spawn_nothing() -> void:
	_make()
	var expected: String = _session.get_current_target()[0]
	_session.judge("q" if expected != "q" else "z")
	assert_eq(_level.get_view_count(), 0)


func test_small_copy_is_placed_at_the_left_edge_of_its_lane() -> void:
	_make()
	_level.on_target_completed("cat")
	var marcher: HordeMarcher = _level.get_field().get_marching()[0]
	var view: PlayerZombie = _level.get_view(marcher.id)
	assert_not_null(view)
	assert_eq(view.position, Vector2(LevelScript.SPAWN_X, _level.lane_feet_y(marcher.lane)))
	assert_eq(view.scale, Vector2.ONE * 1.0)
	_level.on_target_completed("tiger")
	var medium: HordeMarcher = _level.get_field().get_marching()[1]
	assert_eq(_level.get_view(medium.id).position.x, LevelScript.SPRITE_HALF_WIDTH_PX * 1.25, "whole sprite on screen")
	assert_eq(view.get_parent(), _level.get_node("%Zombies"))
	assert_not_null(view.get_node_or_null("%HatSlot"), "the copy wears the equipped hat")
	assert_eq(view.get_node("%HatSlot").get_parent(), view.get_node("Body"))


func test_size_class_scales() -> void:
	_make()
	var words: Dictionary[String, float] = {"cat": 1.0, "frog": 1.25, "tiger": 1.25, "rabbit": 1.5}
	for word: String in words:
		_level.on_target_completed(word)
	for marcher: HordeMarcher in _level.get_field().get_marching():
		assert_eq(_level.get_view(marcher.id).scale, Vector2.ONE * words[marcher.word], marcher.word)


func test_the_march_moves_the_sprite_from_logic() -> void:
	_make()
	_level.on_target_completed("frog")
	var marcher: HordeMarcher = _level.get_field().get_marching()[0]
	var view: PlayerZombie = _level.get_view(marcher.id)
	var y: float = view.position.y
	for seconds: float in [0.5, 2.0, 3.0]:
		_steps(seconds)
		assert_almost_eq(view.position.x, _level.march_x(marcher.progress(), 1.25), 1e-4)
		assert_eq(view.position.y, y, "stays in its lane")
	assert_almost_eq(marcher.progress(), 5.5 / 10.0, 1e-3)
	# The sprite is never read back: moving it by hand does not change the logic.
	view.position.x = 600.0
	var before: float = marcher.elapsed_s
	_level._process(STEP)
	assert_almost_eq(marcher.elapsed_s, before + STEP, 1e-6)
	assert_almost_eq(view.position.x, _level.march_x(marcher.progress(), 1.25), 1e-4)


func test_arrival_frees_the_copy() -> void:
	_make()
	_level.on_target_completed("cat")
	var view: PlayerZombie = _level.get_view(0)
	_steps(8.0 - STEP)
	assert_eq(_level.get_view_count(), 1, "not there one frame early")
	_level._process(STEP)
	assert_eq(_level.get_view_count(), 0)
	assert_null(_level.get_view(0))
	assert_eq(_level.get_field().get_arrived_count(), 1)
	assert_eq(_level.get_shuffling_count(), 1, "it shuffles in")
	var tween: Tween = _level.get_shuffle_tween(view)
	assert_not_null(tween)
	assert_eq(view.modulate, Color.WHITE)
	var x: float = view.position.x
	tween.custom_step(LevelScript.SHUFFLE_S / 2.0)
	assert_almost_eq(view.position.x, x + LevelScript.SHUFFLE_PX / 2.0, 0.01, "steps into the door")
	assert_almost_eq(view.scale.x, 0.5, 0.01, "edge-on")
	assert_eq(_level.get_shuffling_count(), 1)
	tween.custom_step(LevelScript.SHUFFLE_S / 2.0 + 0.01)
	assert_eq(_level.get_shuffling_count(), 0, "done after SHUFFLE_S")
	var effects: Node = _level.get_node("%Effects")
	assert_eq(effects.get_child_count(), 1, "a brain pop")
	var pop: HordeArrivalPop = effects.get_child(0) as HordeArrivalPop
	assert_not_null(pop)
	assert_eq(pop.get_amount_text(), "+1")
	pop.get_tween().custom_step(HordeArrivalPop.RISE_TIME_S + 0.01)
	await wait_process_frames(1)
	assert_false(is_instance_valid(view), "freed")
	assert_false(is_instance_valid(pop), "the pop frees itself")


func test_run_ending_freezes_the_march() -> void:
	_make()
	_level.on_target_completed("cat")
	_level.on_target_completed("tiger")
	_steps(4.0)
	var marching: Array[HordeMarcher] = _level.get_field().get_marching()
	var progress: Array[float] = []
	var xs: Array[float] = []
	for marcher: HordeMarcher in marching:
		progress.append(marcher.progress())
		xs.append(_level.get_view(marcher.id).position.x)
	assert_eq(_level.on_run_ending(&"timer"), 2.0)
	assert_true(_level.is_frozen())
	_steps(20.0)
	for i: int in marching.size():
		assert_eq(marching[i].progress(), progress[i], "progress frozen")
		assert_eq(_level.get_view(marching[i].id).position.x, xs[i], "sprite frozen")
	assert_eq(_level.get_view_count(), 2, "no arrivals after the end")
	assert_eq(_level.get_field().get_arrived_count(), 0)


func test_spawn_after_run_ending_is_ignored() -> void:
	_make()
	_level.on_run_ending(&"timer")
	_level.on_target_completed("cat")
	assert_eq(_level.get_view_count(), 0)
	assert_eq(_level.get_field().get_spawned_count(), 0)


func test_the_march_stops_while_the_tree_is_paused() -> void:
	_make()
	_level.process_mode = Node.PROCESS_MODE_INHERIT
	_level.on_target_completed("cat")
	var marcher: HordeMarcher = _level.get_field().get_marching()[0]
	get_tree().paused = true
	await wait_process_frames(5)
	var paused_at: float = marcher.elapsed_s
	get_tree().paused = false
	assert_eq(paused_at, 0.0, "paused: nothing marched")
	await wait_process_frames(5)
	assert_gt(marcher.elapsed_s, 0.0, "unpaused: it marches again")


func test_create_target_source_again_starts_a_clean_run() -> void:
	_make()
	_level.on_target_completed("cat")
	var old_view: PlayerZombie = _level.get_view(0)
	_level.on_run_ending(&"timer")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	assert_not_null(_level.create_target_source(rng))
	assert_false(_level.is_frozen())
	assert_eq(_level.get_view_count(), 0)
	await wait_process_frames(1)
	assert_false(is_instance_valid(old_view), "the old sprite is freed")
	_level.on_target_completed("cat")
	assert_eq(_level.get_view_count(), 1)
	assert_eq(_level.get_field().get_spawned_count(), 1)


func test_lanes_that_do_not_fit_fail_safely() -> void:
	_make(1, func(c: HordeRushConfig) -> void: c.lane_count = 7)
	assert_null(_source)
	assert_push_error("do not fit above the HUD")
	assert_push_error("do not fit above the HUD")


# --- arrivals (Story 6.5) -----------------------------------------------------------------------

func test_each_class_pays_its_arrival_brains() -> void:
	_make()
	watch_signals(_level)
	_level.on_target_completed("cat")
	_level.on_target_completed("frog")
	_level.on_target_completed("rabbit") # brutes never spawn from the 3-5 band, but the class exists
	_steps(8.0)
	assert_eq(_level.get_brains_earned(), 1, "small: 1")
	_steps(2.0)
	assert_eq(_level.get_brains_earned(), 3, "medium: 2")
	_steps(3.0)
	assert_eq(_level.get_brains_earned(), 6, "brute: 3")
	assert_signal_emit_count(_level, "brains_earned_changed", 3)
	var totals: Array[int] = [1, 3, 6]
	for i: int in 3:
		assert_eq(get_signal_parameters(_level, "brains_earned_changed", i), [totals[i]], "total %d" % i)
	assert_eq(_voices, [&"vo_brainsss", &"vo_brainsss", &"vo_brainsss"] as Array[StringName], "every arrival")


func test_brains_are_paid_in_the_arrival_step_before_any_visual() -> void:
	_make()
	_level.on_target_completed("cat")
	var seen: Array = []
	_level.brains_earned_changed.connect(func(total: int) -> void:
		seen.append([total, _level.get_view_count(), _level.get_shuffling_count()]))
	_steps(8.0)
	assert_eq(seen, [[1, 1, 0]], "emitted while the sprite is still in the march")


func test_a_free_arrival_emits_nothing_and_has_no_pop() -> void:
	var tweak: Callable = func(c: HordeRushConfig) -> void:
		# A fresh class and array, so the shipped resource is never touched.
		var classes: Array[HordeSizeClass] = c.size_classes.duplicate()
		classes[0] = classes[0].duplicate() as HordeSizeClass
		classes[0].arrival_brains = 0
		c.size_classes = classes
	_make(42, tweak)
	watch_signals(_level)
	_level.on_target_completed("cat")
	_steps(8.0)
	assert_eq(_level.get_brains_earned(), 0)
	assert_signal_not_emitted(_level, "brains_earned_changed")
	assert_eq(_voices, [&"vo_brainsss"] as Array[StringName], "the voice is still asked")
	assert_eq(_level.get_shuffling_count(), 1, "it still shuffles in")
	assert_eq(_level.get_node("%Effects").get_child_count(), 0, "no pop")


func test_pop_shows_the_brains_paid_above_the_house_front() -> void:
	_make()
	_copy_in_lane("frog", 2)
	_steps(10.0)
	var pop: HordeArrivalPop = _level.get_node("%Effects").get_child(0) as HordeArrivalPop
	assert_eq(pop.get_amount_text(), "+2")
	assert_eq(pop.position, Vector2(_level.arrive_x(1.25), _level.lane_feet_y(2) - PlayerZombie.SIZE_PX * 1.25))
	assert_true(pop.position.x < 600.0, "clear of the pause button")


func test_a_lane_0_pop_stays_on_screen() -> void:
	_make()
	_copy_in_lane("rabbit", 0)
	_steps(13.0)
	var pop: HordeArrivalPop = _level.get_node("%Effects").get_child(0) as HordeArrivalPop
	assert_eq(pop.position.y, LevelScript.POP_MIN_Y)
	assert_true(pop.position.y - 16.0 - HordeArrivalPop.RISE_PX >= 0.0, "the brain stays on screen after the rise")


func test_a_copy_without_a_sprite_still_pays() -> void:
	_make()
	var small: HordeMarcher = _copy_in_lane("cat", 0)
	_level.get_view(small.id).free()
	(_level.get("_views") as Dictionary).erase(small.id)
	_steps(8.0)
	assert_eq(_level.get_brains_earned(), 1)
	assert_eq(_level.get_shuffling_count(), 0)
	assert_eq(_voices.size(), 1)


func test_an_arrival_drops_a_running_flash() -> void:
	_make()
	var medium: HordeMarcher = _copy_in_lane("frog", 0)
	var view: PlayerZombie = _level.get_view(medium.id)
	medium.elapsed_s = 10.0 - 0.05
	_level.call("_flash", medium)
	var flash: Tween = _level.get_flash_tween(medium.id)
	_level._process(0.1)
	assert_eq(_level.get_brains_earned(), 2)
	assert_null(_level.get_flash_tween(medium.id), "no stale entry")
	assert_false(flash.is_valid(), "killed")
	assert_eq(view.modulate, Color.WHITE)


func test_no_arrival_pays_after_the_end() -> void:
	_make()
	_level.on_target_completed("cat")
	_steps(7.9)
	_level.on_run_ending(&"timer")
	_steps(5.0)
	assert_eq(_level.get_brains_earned(), 0)
	assert_eq(_voices.size(), 0)


func test_the_shipped_config_ends_with_a_bonus_and_an_outro() -> void:
	_make()
	assert_eq(_level.config.completion_bonus, 25)
	assert_eq((_level.config as HordeRushConfig).outro_time_s, 2.0)


## Words and lanes for `count` completed words under run seed `rng_seed`.
func _replay(rng_seed: int, count: int) -> Array:
	_make(rng_seed)
	var words: Array[String] = []
	for i: int in count:
		words.append(_type_word())
	var lanes: Array[int] = []
	for marcher: HordeMarcher in _level.get_field().get_marching():
		lanes.append(marcher.lane)
	return [words, lanes]


func test_same_seed_same_words_and_lanes() -> void:
	var first: Array = _replay(9, 25)
	var second: Array = _replay(9, 25)
	assert_eq(second, first)
	assert_ne(_replay(10, 25), first)


func test_lanes_come_from_the_second_child_rng() -> void:
	var played: Array = _replay(77, 20)
	var run_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	run_rng.seed = 77
	run_rng.randi() # words first
	var lane_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	lane_rng.seed = run_rng.randi() # lanes second
	var lanes: Array[int] = []
	for i: int in 20:
		lanes.append(lane_rng.randi_range(0, (_level.config as HordeRushConfig).lane_count - 1))
	assert_eq(played[1], lanes)


func test_invalid_config_returns_null_without_asserting() -> void:
	var tweak: Callable = func(c: HordeRushConfig) -> void:
		c.word_min_length = 9
		c.word_max_length = 9
	_make(1, tweak)
	assert_null(_source, "a band with no words fails safely")
	assert_push_error("only 0 words in the band 9-9")
	assert_null(_level.get_field())
	_level._process(STEP)
	_level.on_target_completed("cat")
	assert_eq(_level.get_view_count(), 0)


func test_invalid_numbers_return_null() -> void:
	_make(1, func(c: HordeRushConfig) -> void: c.lane_count = 0)
	assert_null(_source)
	assert_push_error("lane_count must be at least 1")


func test_never_uses_the_global_rng() -> void:
	seed(1)
	var first: Array = _replay(5, 15)
	seed(999)
	assert_eq(_replay(5, 15), first)
	randomize() # leave the global RNG unseeded for later tests


# --- defender, projectiles and melting (Story 6.4) ------------------------------------------------

## A copy of `word` forced into `lane` (the lane RNG picked another; logic reads lanes from the marcher).
func _copy_in_lane(word: String, lane: int) -> HordeMarcher:
	_level.on_target_completed(word)
	var marching: Array[HordeMarcher] = _level.get_field().get_marching()
	var marcher: HordeMarcher = marching[marching.size() - 1]
	marcher.lane = lane
	return marcher


## Steps until the defender has landed `count` projectiles in total (or `max_s` passes).
func _until_landed(count: int, max_s: float = 5.0) -> void:
	var defender: HordeDefender = _level.get_defender()
	for i: int in roundi(max_s / STEP):
		if defender.get_hit_count() + defender.get_miss_count() >= count:
			return
		_level._process(STEP)


func test_defender_view_stands_in_front_of_the_house() -> void:
	_make()
	var view: Node2D = _level.get_defender_view()
	assert_not_null(view)
	assert_eq(view, _level.get_node("%Defender"))
	assert_eq(view.get_parent(), _level.get_node("%Zombies"), "y-sorts with the copies")
	assert_eq(view.position, Vector2(LevelScript.DEFENDER_X, _level.lane_feet_y(0)))
	assert_true(LevelScript.DEFENDER_X < LevelScript.HOUSE_FRONT_X)
	assert_eq(_level.lane_feet_y_at(0.5), (_level.lane_feet_y(0) + _level.lane_feet_y(1)) / 2.0)
	var projectiles: Node = _level.get_node("%Projectiles")
	assert_gt(projectiles.get_index(), _level.get_node("%Zombies").get_index(), "drawn on top")


func test_defender_waits_for_the_run_to_start() -> void:
	_make()
	_copy_in_lane("rabbit", 0)
	_steps(3.0)
	assert_eq(_level.get_defender().position(), 0.0)
	assert_eq(_level.get_defender().get_thrown_count(), 0)
	assert_eq(_level.get_projectile_view_count(), 0)
	assert_eq(_level.get_defender_view().position.y, _level.lane_feet_y(0))
	assert_false(_level.is_defender_running())


func test_the_defender_view_paces_from_logic() -> void:
	_make()
	_level.on_run_started()
	assert_true(_level.is_defender_running())
	_steps(0.6)
	assert_almost_eq(_level.get_defender().position(), 1.0, 1e-3)
	assert_almost_eq(_level.get_defender_view().position.y, _level.lane_feet_y(1), 0.1)
	assert_eq(_level.get_defender_view().position.x, LevelScript.DEFENDER_X)


func test_a_throw_creates_a_projectile_view_and_landing_frees_it() -> void:
	_make()
	_copy_in_lane("rabbit", 0)
	_level.on_run_started()
	_level._process(STEP)
	assert_eq(_level.get_projectile_view_count(), 1, "thrown in this step")
	var tomato: Node2D = _level.get_projectile_view(0)
	assert_eq(tomato.get_parent(), _level.get_node("%Projectiles"))
	assert_eq(tomato.position, Vector2(_level.march_x(1.0), _level.lane_feet_y(0) - LevelScript.TOMATO_RISE_PX))
	_steps(0.3)
	var flying: HordeProjectile = _level.get_defender().get_flying()[0]
	assert_almost_eq(tomato.position.x, _level.march_x(flying.position), 1e-3, "x from logic")
	_until_landed(1)
	assert_eq(_level.get_defender().get_hit_count(), 1)
	assert_eq(_level.get_projectile_view_count(), 0, "landed: its view is gone")
	assert_null(_level.get_projectile_view(0))
	await wait_process_frames(1)
	assert_false(is_instance_valid(tomato), "freed")


func test_a_non_final_hit_flashes_and_the_copy_keeps_marching() -> void:
	_make()
	var medium: HordeMarcher = _copy_in_lane("frog", 0)
	var view: PlayerZombie = _level.get_view(medium.id)
	_level.on_run_started()
	_until_landed(1)
	assert_eq(medium.hits_left, 1)
	assert_eq(view.modulate, LevelScript.HIT_FLASH_MODULATE, "hard flash, no fade")
	assert_eq(_level.get_view(medium.id), view, "still marching")
	var progress: float = medium.progress()
	_steps(0.1)
	assert_gt(medium.progress(), progress)
	var tween: Tween = _level.get_flash_tween(medium.id)
	assert_not_null(tween)
	tween.custom_step(0.1)
	assert_eq(view.modulate, LevelScript.HIT_FLASH_MODULATE, "still flashing before hit_flash_s")
	tween.custom_step(0.06)
	assert_eq(view.modulate, Color.WHITE, "back to normal after 0.15 s")


func test_a_new_hit_restarts_the_flash() -> void:
	_make()
	var medium: HordeMarcher = _copy_in_lane("frog", 0)
	_level.on_run_started()
	_until_landed(1)
	var first: Tween = _level.get_flash_tween(medium.id)
	_level.call("_flash", medium)
	assert_false(first.is_valid(), "the old flash tween is killed")
	assert_ne(_level.get_flash_tween(medium.id), first)


func test_a_final_hit_melts_then_frees_the_copy() -> void:
	_make()
	var small: HordeMarcher = _copy_in_lane("cat", 0)
	var view: PlayerZombie = _level.get_view(small.id)
	_level.on_run_started()
	_until_landed(1)
	assert_true(small.is_stopped())
	assert_null(_level.get_view(small.id), "out of the march at once")
	assert_eq(_level.get_view_count(), 0)
	assert_eq(_level.get_melting_count(), 1)
	assert_eq(view.modulate, Color.WHITE, "no flash on the final hit")
	var x: float = view.position.x
	_steps(1.0)
	assert_eq(view.position.x, x, "a melting copy never moves on")
	var tween: Tween = _level.get_melt_tween(view)
	assert_not_null(tween)
	tween.custom_step(0.3)
	assert_almost_eq(view.scale.y, 0.5, 0.01, "halfway into the ground")
	assert_gt(view.scale.x, 1.0, "spreading into a puddle")
	assert_eq(_level.get_melting_count(), 1)
	tween.custom_step(0.31)
	assert_eq(_level.get_melting_count(), 0, "done after melt_s")
	assert_eq(_level.get_brains_earned(), 0, "a stopped copy earns nothing")
	await wait_process_frames(1)
	assert_false(is_instance_valid(view), "freed")


func test_an_instant_melt_frees_at_once() -> void:
	_make(42, func(c: HordeRushConfig) -> void: c.melt_s = 0.0)
	var small: HordeMarcher = _copy_in_lane("cat", 0)
	var view: PlayerZombie = _level.get_view(small.id)
	_level.on_run_started()
	_until_landed(1)
	assert_eq(_level.get_melting_count(), 0)
	await wait_process_frames(1)
	assert_false(is_instance_valid(view))


func test_no_flash_when_hit_flash_is_zero() -> void:
	_make(42, func(c: HordeRushConfig) -> void: c.hit_flash_s = 0.0)
	var medium: HordeMarcher = _copy_in_lane("frog", 0)
	_level.on_run_started()
	_until_landed(1)
	assert_eq(medium.hits_left, 1)
	assert_eq(_level.get_view(medium.id).modulate, Color.WHITE)


func test_a_stopped_copy_without_a_sprite_is_fine() -> void:
	_make()
	var small: HordeMarcher = _copy_in_lane("cat", 0)
	_level.get_view(small.id).free()
	(_level.get("_views") as Dictionary).erase(small.id)
	_level.on_run_started()
	_until_landed(1)
	assert_true(small.is_stopped())
	assert_eq(_level.get_melting_count(), 0)


func test_run_ending_freezes_the_defender_and_clears_the_tomatoes() -> void:
	_make()
	var brute: HordeMarcher = _copy_in_lane("rabbit", 0)
	_level.on_run_started()
	_steps(0.3)
	var position: float = _level.get_defender().position()
	var tomato: Node2D = _level.get_projectile_view(0)
	var defender_at: Vector2 = _level.get_defender_view().position
	var progress: float = brute.progress()
	assert_eq(_level.on_run_ending(&"timer"), 2.0, "outro_time_s")
	assert_false(_level.is_defender_running())
	assert_eq(_level.get_projectile_view_count(), 0, "no tomato left in the air")
	var view: PlayerZombie = _level.get_view(brute.id)
	assert_true(view.is_dancing(), "the copy dances in place")
	_steps(2.0)
	assert_eq(_level.get_defender().position(), position)
	assert_eq(_level.get_defender_view().position, defender_at)
	assert_eq(_level.get_defender().get_hit_count(), 0, "nothing lands after the end")
	assert_eq(brute.progress(), progress)
	assert_eq(_level.get_brains_earned(), 0)
	await wait_process_frames(1)
	assert_false(is_instance_valid(tomato), "freed")


func test_a_second_run_ending_changes_nothing() -> void:
	_make()
	var small: HordeMarcher = _copy_in_lane("cat", 0)
	_level.on_run_started()
	_steps(0.1)
	assert_eq(_level.on_run_ending(&"timer"), 2.0)
	var dance: Tween = _level.get_view(small.id).get_dance_tween()
	assert_eq(_level.on_run_ending(&"quit"), 2.0)
	assert_eq(_level.get_view(small.id).get_dance_tween(), dance, "the dance is not restarted")
	assert_true(_level.is_frozen())


func test_run_ending_clears_a_running_flash() -> void:
	_make()
	var medium: HordeMarcher = _copy_in_lane("frog", 0)
	_level.on_run_started()
	_until_landed(1)
	var flash: Tween = _level.get_flash_tween(medium.id)
	assert_not_null(flash)
	_level.on_run_ending(&"timer")
	assert_false(flash.is_valid())
	assert_null(_level.get_flash_tween(medium.id))
	assert_eq(_level.get_view(medium.id).modulate, Color.WHITE)


func test_create_target_source_again_clears_the_defender_state() -> void:
	_make()
	_copy_in_lane("cat", 0)
	_copy_in_lane("frog", 1)
	_level.on_run_started()
	_until_landed(1)
	_steps(0.1)
	assert_eq(_level.get_melting_count(), 1)
	assert_eq(_level.get_projectile_view_count(), 1, "the second throw (lane 1) is in the air")
	var tomato: Node2D = _level.get_projectile_view(1)
	_level.on_run_ending(&"timer")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	assert_not_null(_level.create_target_source(rng))
	assert_eq(_level.get_projectile_view_count(), 0)
	assert_eq(_level.get_melting_count(), 0)
	assert_eq(_level.get_brains_earned(), 0)
	assert_false(_level.is_defender_running())
	assert_eq(_level.get_defender().position(), 0.0)
	assert_eq(_level.get_defender().get_thrown_count(), 0)
	assert_eq(_level.get_defender_view().position.y, _level.lane_feet_y(0))
	_copy_in_lane("rabbit", 0)
	_steps(1.0)
	assert_eq(_level.get_defender().get_thrown_count(), 0, "idle until the new run starts")
	await wait_process_frames(1)
	assert_false(is_instance_valid(tomato), "old views are freed")


func test_a_stopped_copy_earns_nothing() -> void:
	_make()
	_copy_in_lane("cat", 0)
	_level.on_run_started()
	_steps(3.0)
	assert_eq(_level.get_field().get_stopped_count(), 1)
	assert_eq(_level.get_brains_earned(), 0)


## Logic state after `frames` calls of _process(delta) on a fixed setup.
func _logic_after(delta: float, frames: int) -> Array:
	_make()
	var copies: Array[HordeMarcher] = [_copy_in_lane("frog", 0), _copy_in_lane("cat", 1), _copy_in_lane("rabbit", 0)]
	_level.on_run_started()
	for i: int in frames:
		_level._process(delta)
	var defender: HordeDefender = _level.get_defender()
	var state: Array = [defender.position(), defender.get_thrown_count(), defender.get_hit_count()]
	for marcher: HordeMarcher in copies:
		state.append(marcher.progress())
		state.append(marcher.hits_left)
	return state


func test_a_long_frame_is_split_into_substeps() -> void:
	var one: Array = _logic_after(0.5, 1)
	var many: Array = _logic_after(1.0 / 30.0, 15)
	assert_eq(one.size(), many.size())
	for i: int in one.size():
		assert_almost_eq(float(one[i]), float(many[i]), 1e-4, "state %d" % i)
	assert_eq(one[1], 1, "a throw happened inside the long frame")


func test_a_hitch_never_skips_a_throw() -> void:
	var smooth: Array = _logic_after(STEP, 240)
	var hitchy: Array = _logic_after(0.5, 8)
	assert_eq(hitchy[1], smooth[1], "same throws")
	assert_eq(hitchy[2], smooth[2], "same hits")


func test_a_frame_longer_than_the_cap_runs_only_the_cap() -> void:
	var capped: Array = _logic_after(10.0, 1)
	var half: Array = _logic_after(LevelScript.MAX_FRAME_S, 1)
	assert_eq(capped.size(), half.size())
	for i: int in capped.size():
		assert_almost_eq(float(capped[i]), float(half[i]), 1e-6, "state %d" % i)


func test_a_hitch_pays_no_burst_of_brains() -> void:
	_make()
	for word: String in ["cat", "cat", "cat"]:
		_level.on_target_completed(word)
	_level._process(30.0)
	assert_eq(_level.get_brains_earned(), 0, "only 0.5 s of march ran")
	assert_almost_eq(_level.get_field().get_marching()[0].elapsed_s, LevelScript.MAX_FRAME_S, 1e-6)


func test_create_target_source_again_clears_the_arrivals() -> void:
	_make()
	_level.on_target_completed("cat")
	_level.on_target_completed("cat")
	_steps(8.0)
	assert_eq(_level.get_brains_earned(), 2)
	assert_eq(_level.get_shuffling_count(), 2)
	var effects: Node = _level.get_node("%Effects")
	assert_eq(effects.get_child_count(), 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	assert_not_null(_level.create_target_source(rng))
	assert_eq(_level.get_brains_earned(), 0)
	assert_eq(_level.get_shuffling_count(), 0)
	await wait_process_frames(1)
	assert_eq(effects.get_child_count(), 0, "old pops are freed")


func test_bad_deltas_do_nothing() -> void:
	_make()
	_copy_in_lane("cat", 0)
	_level.on_run_started()
	for delta: float in [0.0, -1.0, INF, NAN]:
		_level._process(delta)
	assert_eq(_level.get_defender().position(), 0.0)
	assert_eq(_level.get_defender().get_thrown_count(), 0)


func test_the_defender_stops_while_the_tree_is_paused() -> void:
	_make()
	_level.process_mode = Node.PROCESS_MODE_INHERIT
	_level.on_run_started()
	get_tree().paused = true
	await wait_process_frames(5)
	var paused_at: float = _level.get_defender().position()
	get_tree().paused = false
	assert_eq(paused_at, 0.0, "paused: the defender stands still")
	await wait_process_frames(5)
	assert_gt(_level.get_defender().position(), 0.0, "unpaused: it paces again")
