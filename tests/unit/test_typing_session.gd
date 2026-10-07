extends GutTest
## Judgment session (Story 2.2): correct/wrong keys, first-key start, counters, per-key record.
## Verbose typing log (Story 2.10) changes nothing but the log.


## Deterministic source: hands out a fixed list, then "" when exhausted.
class StubSource extends TargetSource:
	var _items: Array[String]
	var _pos: int = 0

	func _init(items: Array[String]) -> void:
		_items = items

	func peek(n: int) -> Array[String]:
		var out: Array[String] = []
		for i: int in range(1, n + 1):
			if _pos + i < _items.size():
				out.append(_items[_pos + i])
		return out

	func current() -> String:
		return _items[_pos] if _pos < _items.size() else ""

	func advance() -> void:
		_pos += 1


var _session: TypingSession
var _log: Array[String] = []


func _stub(items: Array[String] = ["f", "j", "f", "d"]) -> TypingSession:
	var session: TypingSession = TypingSession.new(StubSource.new(items))
	session.run_started.connect(func() -> void: _log.append("run_started"))
	session.char_accepted.connect(func(e: String, i: int) -> void: _log.append("accepted:%s:%d" % [e, i]))
	session.char_rejected.connect(func(e: String, t: String) -> void: _log.append("rejected:%s:%s" % [e, t]))
	session.target_changed.connect(func(n: String) -> void: _log.append("target:%s" % n))
	return session


func before_each() -> void:
	_log = []
	_session = _stub()
	watch_signals(_session)


func after_each() -> void:
	Log.verbose_typing = false


func test_correct_key() -> void:
	assert_eq(_session.judge("f"), TypingSession.Verdict.CORRECT)
	assert_signal_emitted_with_parameters(_session, "char_accepted", ["f", 0])
	assert_signal_emitted_with_parameters(_session, "target_changed", ["j"])
	assert_signal_emit_count(_session, "run_started", 1)
	assert_eq(_session.get_keys_typed(), 1)
	assert_eq(_session.get_errors(), 0)
	assert_true(_session.has_started())
	assert_eq(_session.get_current_target(), "j")


func test_second_correct_key_has_next_index_and_no_second_start() -> void:
	_session.judge("f")
	_session.judge("j")
	assert_signal_emit_count(_session, "run_started", 1)
	assert_signal_emit_count(_session, "char_accepted", 2)
	assert_signal_emitted_with_parameters(_session, "char_accepted", ["j", 1])
	assert_signal_emitted_with_parameters(_session, "target_changed", ["f"])


func test_wrong_key() -> void:
	assert_eq(_session.judge("g"), TypingSession.Verdict.WRONG)
	assert_signal_emitted_with_parameters(_session, "char_rejected", ["f", "g"])
	assert_signal_not_emitted(_session, "char_accepted")
	assert_signal_not_emitted(_session, "target_changed")
	assert_signal_not_emitted(_session, "run_started")
	assert_eq(_session.get_current_target(), "f")
	assert_eq(_session.get_errors(), 1)
	assert_eq(_session.get_keys_typed(), 0)


func test_wrong_first_then_correct_starts_only_on_correct() -> void:
	_session.judge("g")
	assert_false(_session.has_started())
	_session.judge("f")
	assert_true(_session.has_started())
	assert_signal_emit_count(_session, "run_started", 1)
	assert_eq(_session.get_errors(), 1)
	assert_eq(_session.get_keys_typed(), 1)


func test_repeated_wrong_keys_do_not_advance() -> void:
	for i: int in 5:
		_session.judge("x")
	assert_eq(_session.get_errors(), 5)
	assert_eq(_session.get_current_target(), "f")
	assert_signal_emit_count(_session, "char_rejected", 5)


func test_emit_order() -> void:
	_session.judge("f")
	assert_eq(_log, ["run_started", "accepted:f:0", "target:j"] as Array[String])
	_log.clear()
	_session.judge("j")
	assert_eq(_log, ["accepted:j:1", "target:f"] as Array[String])


func test_signals_are_synchronous() -> void:
	var count: Array[int] = [0]
	_session.target_changed.connect(func(_n: String) -> void: count[0] += 1)
	_session.judge("f")
	assert_eq(count[0], 1, "handler ran before judge() returned")


func test_per_key_record_shape() -> void:
	# Expected "f" is judged: wrong g, wrong g, wrong d, correct f.
	var session: TypingSession = _stub(["f", "j"])
	session.judge("g")
	session.judge("g")
	session.judge("d")
	session.judge("f")
	session.judge("j")
	var per_key: Dictionary = session.get_per_key()
	assert_eq(per_key["f"], [4, 3, {"g": 2, "d": 1}])
	assert_eq(per_key["j"], [1, 0, {}])
	assert_false(per_key.has("d"), "keys never expected are absent")


func test_per_key_invariants() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	var pool: Array[String] = ["a", "b", "c", "d"]
	var session: TypingSession = TypingSession.new(LetterBagSource.new(rng, pool))
	for i: int in 200:
		session.judge("z" if i % 3 == 0 else session.get_current_target())
	var total_attempts: int = 0
	var total_errors: int = 0
	var per_key: Dictionary = session.get_per_key()
	for key: String in per_key:
		var entry: Array = per_key[key]
		var typed_sum: int = 0
		for n: int in (entry[2] as Dictionary).values():
			typed_sum += n
		assert_eq(entry[1], typed_sum, "errors equal sum of typed counts for %s" % key)
		assert_true(entry[1] <= entry[0])
		total_attempts += entry[0]
		total_errors += entry[1]
	assert_eq(total_attempts, 200)
	assert_eq(total_errors, session.get_errors())
	assert_eq(total_attempts - total_errors, session.get_keys_typed())


func test_get_per_key_is_a_deep_copy() -> void:
	_session.judge("g")
	var first: Dictionary = _session.get_per_key()
	(first["f"] as Array)[0] = 99
	((first["f"] as Array)[2] as Dictionary)["g"] = 99
	assert_eq(_session.get_per_key()["f"], [1, 1, {"g": 1}])


func test_no_case_folding_and_odd_input_is_wrong() -> void:
	assert_eq(_session.judge("F"), TypingSession.Verdict.WRONG)
	assert_eq(_session.judge(""), TypingSession.Verdict.WRONG)
	assert_eq(_session.judge("ff"), TypingSession.Verdict.WRONG)
	assert_eq(_session.get_errors(), 3)
	assert_eq(_session.get_current_target(), "f")


func test_exhausted_source_returns_wrong_without_counting() -> void:
	var session: TypingSession = _stub(["f"])
	session.judge("f")
	assert_eq(session.get_current_target(), "")
	assert_eq(session.judge("x"), TypingSession.Verdict.WRONG)
	assert_eq(session.get_errors(), 0)
	assert_eq(session.get_keys_typed(), 1)


func test_get_upcoming_delegates_to_peek() -> void:
	assert_eq(_session.get_upcoming(2), ["j", "f"] as Array[String])


func test_cooperates_with_letter_bag() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var pool: Array[String] = ["a", "b", "c", "d", "e"]
	var session: TypingSession = TypingSession.new(LetterBagSource.new(rng, pool))
	var indexes: Array[int] = []
	var repeats: Array[int] = [0]
	var last: Array[String] = [""]
	session.char_accepted.connect(func(e: String, i: int) -> void:
		indexes.append(i)
		last[0] = e)
	session.target_changed.connect(func(n: String) -> void:
		if n == last[0]:
			repeats[0] += 1)
	for i: int in 100:
		assert_eq(session.judge(session.get_current_target()), TypingSession.Verdict.CORRECT)
	assert_eq(session.get_keys_typed(), 100)
	assert_eq(session.get_errors(), 0)
	var expected: Array[int] = []
	for i: int in 100:
		expected.append(i)
	assert_eq(indexes, expected)
	assert_eq(repeats[0], 0)


## Story 2.10: the per-judgment log lines (checked by hand; GUT does not capture print) change nothing.
func _judge_sequence() -> Array:
	_log = []
	var session: TypingSession = _stub()
	var verdicts: Array = []
	for c: String in ["x", "f", "j", "q", "f"]:
		verdicts.append(session.judge(c))
	return [verdicts, session.get_keys_typed(), session.get_errors(), session.get_per_key(), _log.duplicate()]


func test_verbose_typing_changes_nothing_but_the_log() -> void:
	Log.verbose_typing = false
	var quiet: Array = _judge_sequence()
	Log.verbose_typing = true
	var verbose: Array = _judge_sequence()
	assert_eq(verbose, quiet)
	assert_eq(verbose[1], 3)
	assert_eq(verbose[2], 2)


## Story 6.2: word mode. The session judges the word's next letter (the cursor) and completes the word
## on its last letter, with no Space.
func _config(mode: LevelConfig.TargetMode) -> LevelConfig:
	var config: LevelConfig = LevelConfig.new()
	config.target_mode = mode
	return config


func _word_session(mode: LevelConfig.TargetMode = LevelConfig.TargetMode.WORD,
		items: Array[String] = ["dad", "cat"]) -> TypingSession:
	var session: TypingSession = TypingSession.new(StubSource.new(items), _config(mode))
	session.run_started.connect(func() -> void: _log.append("run_started"))
	session.char_accepted.connect(func(e: String, i: int) -> void: _log.append("accepted:%s:%d" % [e, i]))
	session.char_rejected.connect(func(e: String, t: String) -> void: _log.append("rejected:%s:%s" % [e, t]))
	session.target_completed.connect(func(t: String) -> void: _log.append("completed:%s" % t))
	session.target_changed.connect(func(n: String) -> void: _log.append("target:%s" % n))
	return session


func test_word_cursor_moves_through_the_word() -> void:
	var session: TypingSession = _word_session()
	assert_eq(session.get_cursor(), 0)
	assert_eq(session.judge("d"), TypingSession.Verdict.CORRECT)
	assert_eq(session.get_cursor(), 1)
	assert_eq(session.judge("a"), TypingSession.Verdict.CORRECT)
	assert_eq(session.get_cursor(), 2)
	assert_eq(session.get_current_target(), "dad", "the whole word stays the target mid-word")


func test_word_letters_are_accepted_with_run_wide_indexes() -> void:
	var session: TypingSession = _word_session()
	_log = []
	for c: String in ["d", "a", "d"]:
		session.judge(c)
	assert_eq(_log.slice(0, 3), ["run_started", "accepted:d:0", "accepted:a:1"] as Array[String])
	assert_has(_log, "accepted:d:2")


func test_no_target_changed_mid_word() -> void:
	var session: TypingSession = _word_session()
	watch_signals(session)
	session.judge("d")
	session.judge("a")
	assert_signal_not_emitted(session, "target_changed")
	assert_signal_not_emitted(session, "target_completed")


func test_wrong_key_mid_word_keeps_the_cursor_and_records_the_letter() -> void:
	var session: TypingSession = _word_session()
	session.judge("d")
	assert_eq(session.judge("s"), TypingSession.Verdict.WRONG)
	assert_eq(session.get_cursor(), 1)
	assert_eq(session.get_errors(), 1)
	assert_has(_log, "rejected:a:s")
	var per_key: Dictionary = session.get_per_key()
	assert_eq(per_key["a"], [1, 1, {"s": 1}])
	assert_false(per_key.has("dad"), "stats are per letter, never per word")


func test_last_letter_completes_the_word_without_space() -> void:
	var session: TypingSession = _word_session()
	watch_signals(session)
	for c: String in ["d", "a", "d"]:
		session.judge(c)
	assert_signal_emit_count(session, "target_completed", 1)
	assert_signal_emitted_with_parameters(session, "target_completed", ["dad"])
	assert_signal_emit_count(session, "target_changed", 1)
	assert_signal_emitted_with_parameters(session, "target_changed", ["cat"])
	assert_eq(session.get_cursor(), 0)
	assert_eq(session.get_current_target(), "cat")
	assert_eq(session.get_per_key()["d"], [2, 0, {}], "the repeated letter is counted per key")


func test_word_completion_signal_order() -> void:
	var session: TypingSession = _word_session()
	session.judge("d")
	session.judge("a")
	_log = []
	session.judge("d")
	assert_eq(_log, ["accepted:d:2", "completed:dad", "target:cat"] as Array[String])


func test_implied_spaces_count_completed_words() -> void:
	var session: TypingSession = _word_session()
	var seen: Array[int] = []
	session.target_completed.connect(func(_t: String) -> void: seen.append(session.get_implied_spaces()))
	assert_eq(session.get_implied_spaces(), 0)
	for c: String in ["d", "a", "d"]:
		session.judge(c)
	assert_eq(seen, [1] as Array[int], "the new count is visible inside the handler")
	assert_eq(session.get_implied_spaces(), 1)
	for c: String in ["c", "a", "t"]:
		session.judge(c)
	assert_eq(session.get_implied_spaces(), 2)


func test_run_started_once_before_the_first_accepted_letter_in_word_mode() -> void:
	var session: TypingSession = _word_session()
	watch_signals(session)
	session.judge("x")
	for c: String in ["d", "a", "d", "c"]:
		session.judge(c)
	assert_signal_emit_count(session, "run_started", 1)
	assert_eq(_log[0], "rejected:d:x")
	assert_eq(_log[1], "run_started")
	assert_eq(_log[2], "accepted:d:0")


func test_letter_mode_config_never_completes() -> void:
	var session: TypingSession = _word_session(LevelConfig.TargetMode.LETTER, ["f", "j", "f"])
	watch_signals(session)
	session.judge("f")
	session.judge("j")
	assert_signal_not_emitted(session, "target_completed")
	assert_signal_emit_count(session, "target_changed", 2)
	assert_eq(session.get_implied_spaces(), 0)
	assert_eq(session.get_cursor(), 0)


func test_null_config_never_completes() -> void:
	watch_signals(_session)
	_session.judge("f")
	_session.judge("j")
	assert_signal_not_emitted(_session, "target_completed")
	assert_eq(_session.get_implied_spaces(), 0)
	assert_eq(_session.get_cursor(), 0)


func test_paragraph_mode_completes_but_counts_no_implied_spaces() -> void:
	var session: TypingSession = _word_session(LevelConfig.TargetMode.PARAGRAPH, ["a b", "cd"])
	watch_signals(session)
	for c: String in ["a", " ", "b"]:
		session.judge(c)
	assert_signal_emitted_with_parameters(session, "target_completed", ["a b"])
	assert_eq(session.get_implied_spaces(), 0)
	assert_eq(session.get_current_target(), "cd")
