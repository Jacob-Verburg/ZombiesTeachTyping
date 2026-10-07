extends GutTest
## Horde Rush level (Story 6.3): the word source and band, a copy per completed word in the key's own
## call (lane, x, scale, hat slot), the march derived from HordeField's logic, arrival frees the copy,
## on_run_ending() freezes the march, brains stay 0, seed replay of words and lanes (words seeded first,
## lanes second), and an invalid config fails safely. The level is disabled (nothing advances by itself):
## tests call _process(delta) with fixed steps. Keys go through a real TypingSession wired like RunFrame.

const LevelScene: PackedScene = preload("res://scenes/levels/horde_rush/horde_rush_level.tscn")
const LevelScript := preload("res://scripts/levels/horde_rush/horde_rush_level.gd")
const STEP: float = 1.0 / 60.0

var _level: LevelScript
var _source: TargetSource
var _session: TypingSession


## `tweak` (optional) changes a deep duplicate of the shipped config before the level is added.
func _make(rng_seed: int = 42, tweak: Callable = Callable()) -> LevelScript:
	_level = LevelScene.instantiate() as LevelScript
	_level.process_mode = Node.PROCESS_MODE_DISABLED
	if tweak.is_valid():
		var config: HordeRushConfig = (_level.config as HordeRushConfig).duplicate(true) as HordeRushConfig
		tweak.call(config)
		_level.config = config
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
		assert_almost_eq(view.position.x, _level.march_x(marcher.progress()), 1e-4)
		assert_eq(view.position.y, y, "stays in its lane")
	assert_almost_eq(marcher.progress(), 5.5 / 10.0, 1e-3)
	# The sprite is never read back: moving it by hand does not change the logic.
	view.position.x = 600.0
	var before: float = marcher.elapsed_s
	_level._process(STEP)
	assert_almost_eq(marcher.elapsed_s, before + STEP, 1e-6)
	assert_almost_eq(view.position.x, _level.march_x(marcher.progress()), 1e-4)


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
	await wait_process_frames(1)
	assert_false(is_instance_valid(view), "freed")


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
	assert_eq(_level.on_run_ending(&"timer"), 0.0)
	assert_true(_level.is_frozen())
	_steps(20.0)
	for i: int in marching.size():
		assert_eq(marching[i].progress(), progress[i], "progress frozen")
		assert_eq(_level.get_view(marching[i].id).position.x, xs[i], "sprite frozen")
	assert_eq(_level.get_view_count(), 2, "no arrivals after the end")
	assert_eq(_level.get_field().get_arrived_count(), 0)


func test_no_brains_yet() -> void:
	_make()
	_level.on_target_completed("cat")
	_steps(9.0)
	assert_eq(_level.get_brains_earned(), 0)
	assert_eq(_level.config.completion_bonus, 0)


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
