extends GutTest
## AudioManager buses, pool, unlock gate (FR47) and bus mute, on fresh instances.
## Never assert on the live AudioManager autoload: the title's _ready() talks to it during other tests.
## Headless runs use the Dummy audio driver, so the tests check which player and stream were picked,
## not audible output.

const AudioManagerScript := preload("res://scripts/autoloads/audio_manager.gd")
const GROAN_IDS: Array[StringName] = [&"sfx_groan_a", &"sfx_groan_b", &"sfx_groan_c", &"sfx_groan_d"]

var _sfx_stream: AudioStreamWAV
var _music_stream: AudioStreamWAV
var _am: AudioManagerScript
## Fake clock for the per-cue throttle (Story 2.5), read through AudioManager.now_msec.
var _now: int = 0
## The streams of the code-built library's 4 groans (Story 3.7), in GROAN_IDS order.
var _groan_streams: Array[AudioStream] = []


func before_each() -> void:
	_sfx_stream = _stream()
	_music_stream = _stream()
	var library: AudioLibrary = AudioLibrary.new()
	library.cues = [
		_cue(&"sfx_test", _sfx_stream, -3.0),
		_cue(&"mus_test", _music_stream, -9.0),
		_cue(&"sfx_empty", null, 0.0),
		_throttled_cue(&"sfx_tick", 0.15),
		_throttled_cue(&"sfx_tock", 0.15),
		_cue(&"vo_test", _stream(), -4.0),
		_cue(&"vo_other", _stream(), -6.0),
	]
	library.voice_min_gap_s = 8.0
	_groan_streams.clear()
	for id: StringName in GROAN_IDS:
		var groan: AudioStream = _stream()
		_groan_streams.append(groan)
		library.cues.append(_cue(id, groan, -8.0))
	library.groan_ids = GROAN_IDS.duplicate()
	library.groan_min_interval_s = 3.0
	library.groan_max_interval_s = 8.0
	library.groan_voice_mute_s = 2.0
	_am = AudioManagerScript.new()
	_am.library = library
	add_child_autofree(_am)


func after_each() -> void:
	# Mute is global AudioServer state: never leak it into other tests or the live game.
	for bus: StringName in [&"Music", &"SFX"]:
		var index: int = AudioServer.get_bus_index(bus)
		if index != -1:
			AudioServer.set_bus_mute(index, false)


func _stream() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	return stream


func _cue(id: StringName, stream: AudioStream, volume_db: float) -> AudioCue:
	var cue: AudioCue = AudioCue.new()
	cue.id = id
	cue.stream = stream
	cue.volume_db = volume_db
	return cue


func _players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child: Node in _am.get_children():
		if child is AudioStreamPlayer:
			players.append(child as AudioStreamPlayer)
	return players


func _music_player() -> AudioStreamPlayer:
	return _am.get_node("Music") as AudioStreamPlayer


func test_bus_layout_master_music_sfx() -> void:
	assert_eq(AudioServer.bus_count, 3)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	assert_ne(AudioServer.get_bus_index(&"Music"), -1)
	assert_ne(AudioServer.get_bus_index(&"SFX"), -1)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")), &"Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"SFX")), &"Master")
	for bus: int in AudioServer.bus_count:
		assert_eq(AudioServer.get_bus_effect_count(bus), 0, AudioServer.get_bus_name(bus))


func test_default_library_is_the_shipped_one() -> void:
	assert_eq(AudioManagerScript.LIBRARY.resource_path, "res://data/audio/audio_library.tres")


func test_pool_has_8_sfx_players_and_1_music_player() -> void:
	var players: Array[AudioStreamPlayer] = _players()
	assert_eq(players.size(), 9)
	var sfx_count: int = 0
	var music_count: int = 0
	for player: AudioStreamPlayer in players:
		if player.bus == &"SFX":
			sfx_count += 1
		elif player.bus == &"Music":
			music_count += 1
	assert_eq(sfx_count, AudioManagerScript.SFX_POOL_SIZE)
	assert_eq(sfx_count, 8)
	assert_eq(music_count, 1)
	assert_eq(_music_player().bus, &"Music")


func test_process_mode_always() -> void:
	# Router pauses the tree during every fade; music and clicks must keep going.
	assert_eq(_am.process_mode, Node.PROCESS_MODE_ALWAYS)
	for player: AudioStreamPlayer in _players():
		assert_true(player.can_process(), player.name)


func test_starts_locked() -> void:
	assert_false(_am.is_unlocked())


func test_sfx_before_unlock_plays_nothing() -> void:
	assert_null(_am._try_play_sfx(&"sfx_test"))
	_am.play_sfx(&"sfx_test")
	for player: AudioStreamPlayer in _players():
		assert_null(player.stream, player.name)
		assert_false(player.playing, player.name)


func test_unknown_sfx_before_unlock_is_silent() -> void:
	assert_null(_am._try_play_sfx(&"nope"))
	assert_push_warning_count(0)


func test_music_before_unlock_is_pending_not_playing() -> void:
	_am.play_music(&"mus_test")
	assert_null(_music_player().stream)
	assert_false(_music_player().playing)
	_am.unlock()
	assert_same(_music_player().stream, _music_stream)
	assert_eq(_music_player().volume_db, -9.0)


func test_sfx_after_unlock_uses_cue_stream_and_volume() -> void:
	_am.unlock()
	var player: AudioStreamPlayer = _am._try_play_sfx(&"sfx_test") as AudioStreamPlayer
	assert_not_null(player)
	if player == null:
		return
	assert_same(player.stream, _sfx_stream)
	assert_eq(player.volume_db, -3.0)
	assert_eq(player.bus, &"SFX")
	assert_true(player in _players())


func test_unknown_sfx_warns_and_returns_null() -> void:
	_am.unlock()
	assert_null(_am._try_play_sfx(&"nope"))
	assert_push_warning("unknown sound nope")
	assert_null(_am._try_play_sfx(&"sfx_empty"))
	assert_push_warning("unknown sound sfx_empty")
	_am.play_sfx(&"nope")
	assert_push_warning("unknown sound nope")


func test_unknown_music_warns_and_plays_nothing() -> void:
	_am.unlock()
	_am.play_music(&"nope")
	assert_push_warning("unknown sound nope")
	assert_null(_music_player().stream)
	_am.play_music(&"sfx_empty")
	assert_push_warning("unknown sound sfx_empty")
	assert_null(_music_player().stream)


func test_unknown_pending_music_warns_on_unlock() -> void:
	_am.play_music(&"nope")
	assert_push_warning_count(0)
	_am.unlock()
	assert_push_warning("unknown sound nope")
	assert_null(_music_player().stream)


func test_pool_exhaustion_steals_without_crashing() -> void:
	_am.unlock()
	for i: int in 20:
		var player: AudioStreamPlayer = _am._try_play_sfx(&"sfx_test") as AudioStreamPlayer
		assert_not_null(player, "call %d" % i)
		assert_true(player in _players(), "call %d" % i)
	assert_eq(_players().size(), 9)


func test_unlock_is_idempotent() -> void:
	_am.play_music(&"mus_test")
	_am.unlock()
	var stream: AudioStream = _music_player().stream
	_am.unlock()
	assert_true(_am.is_unlocked())
	assert_same(_music_player().stream, stream)
	assert_eq(_am._current_music, &"mus_test")
	assert_eq(_am._pending_music, &"")


func test_play_music_same_id_does_not_restart() -> void:
	_am.unlock()
	_am.play_music(&"mus_test")
	var position_before: float = _music_player().get_playback_position()
	_am.play_music(&"mus_test")
	assert_eq(_am._current_music, &"mus_test")
	assert_same(_music_player().stream, _music_stream)
	assert_eq(_music_player().get_playback_position(), position_before)


func test_play_music_empty_id_is_ignored() -> void:
	_am.play_music(&"")
	assert_eq(_am._pending_music, &"")
	_am.unlock()
	_am.play_music(&"")
	assert_null(_music_player().stream)


func test_play_music_same_pending_id_stays_pending() -> void:
	_am.play_music(&"mus_test")
	_am.play_music(&"mus_test")
	assert_eq(_am._pending_music, &"mus_test")
	assert_null(_music_player().stream)


func test_stop_music_clears_current_and_pending() -> void:
	_am.play_music(&"mus_test")
	_am.stop_music()
	assert_eq(_am._pending_music, &"")
	_am.unlock()
	assert_null(_music_player().stream, "nothing pending, so unlock starts nothing")
	_am.play_music(&"mus_test")
	_am.stop_music()
	assert_eq(_am._current_music, &"")
	assert_false(_music_player().playing)


func test_mute_music_only_mutes_music() -> void:
	var music: int = AudioServer.get_bus_index(&"Music")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	_am.set_music_muted(true)
	assert_true(AudioServer.is_bus_mute(music))
	assert_false(AudioServer.is_bus_mute(sfx))
	assert_false(AudioServer.is_bus_mute(0))
	assert_true(_am.is_music_muted())
	assert_false(_am.is_sfx_muted())
	_am.set_music_muted(false)
	assert_false(AudioServer.is_bus_mute(music))
	assert_false(_am.is_music_muted())


func test_mute_sfx_only_mutes_sfx() -> void:
	var music: int = AudioServer.get_bus_index(&"Music")
	var sfx: int = AudioServer.get_bus_index(&"SFX")
	_am.set_sfx_muted(true)
	assert_true(AudioServer.is_bus_mute(sfx))
	assert_false(AudioServer.is_bus_mute(music))
	assert_false(AudioServer.is_bus_mute(0))
	assert_true(_am.is_sfx_muted())
	assert_false(_am.is_music_muted())
	_am.set_sfx_muted(false)
	assert_false(AudioServer.is_bus_mute(sfx))
	assert_false(_am.is_sfx_muted())


# --- per-cue throttle (Story 2.5, FR2) -------------------------------------

func _throttled_cue(id: StringName, min_interval_s: float) -> AudioCue:
	var cue: AudioCue = _cue(id, _stream(), -6.0)
	cue.min_interval_s = min_interval_s
	return cue


func _use_fake_clock() -> void:
	_now = 0
	_am.now_msec = func() -> int: return _now


func test_throttle_drops_plays_inside_the_interval() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "t=0 plays")
	_now = 100
	assert_null(_am._try_play_sfx(&"sfx_tick"), "t=100 dropped")
	_now = 149
	assert_null(_am._try_play_sfx(&"sfx_tick"), "t=149 dropped")
	_now = 150
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "t=150 plays")
	_now = 300
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "t=300 plays: the gap counts from the last play")


func test_dropped_calls_do_not_restart_the_gap() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"))
	_now = 140
	assert_null(_am._try_play_sfx(&"sfx_tick"))
	_now = 160
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "the dropped call at 140 did not stamp")


func test_throttle_is_per_cue() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"))
	assert_not_null(_am._try_play_sfx(&"sfx_tock"), "another throttled id is not blocked")
	assert_not_null(_am._try_play_sfx(&"sfx_test"), "an unthrottled id is not blocked")


func test_unthrottled_cue_plays_every_call() -> void:
	_use_fake_clock()
	_am.unlock()
	for i: int in 5:
		assert_not_null(_am._try_play_sfx(&"sfx_test"), "call %d" % i)


func test_locked_call_does_not_stamp() -> void:
	_use_fake_clock()
	assert_null(_am._try_play_sfx(&"sfx_tick"), "locked: dropped")
	_now = 10
	_am.unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "first call after unlock plays")


func test_default_clock_is_ticks_msec() -> void:
	var fresh: AudioManagerScript = AudioManagerScript.new()
	assert_true(fresh.now_msec.is_valid())
	assert_true(fresh.now_msec.call() >= 0)
	fresh.free()


# --- voice lines (Story 3.2, FR48) -----------------------------------------

func test_voice_gap_8_seconds() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"), "t=0 plays")
	_now = 7999
	assert_null(_am._try_play_voice(&"vo_test"), "t=7999 dropped")
	_now = 8000
	assert_not_null(_am._try_play_voice(&"vo_test"), "t=8000 plays")


func test_dropped_voice_does_not_restart_the_gap() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_now = 5000
	assert_null(_am._try_play_voice(&"vo_test"))
	assert_eq(_am._last_voice_msec, 0, "the drop did not stamp")
	_now = 8000
	assert_not_null(_am._try_play_voice(&"vo_test"), "counted from the play at 0, not the drop at 5000")
	assert_eq(_am._last_voice_msec, 8000)


func test_voice_gap_is_shared_across_ids() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_now = 1000
	assert_null(_am._try_play_voice(&"vo_other"), "any voice line waits for the gap")


func test_voice_and_sfx_are_independent() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_now = 100
	assert_not_null(_am._try_play_sfx(&"sfx_test"), "SFX play during the voice gap")
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "throttled SFX too")
	_now = 9000
	assert_not_null(_am._try_play_sfx(&"sfx_tick"))
	assert_null(_am._try_play_sfx(&"sfx_tick"), "the tick is throttled")
	assert_not_null(_am._try_play_voice(&"vo_test"), "a throttled SFX doesn't block voice")


func test_locked_voice_does_not_stamp() -> void:
	_use_fake_clock()
	assert_null(_am._try_play_voice(&"vo_test"), "locked: dropped")
	assert_eq(_am._last_voice_msec, -1)
	_now = 10
	_am.unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"), "first call after unlock plays")
	assert_eq(_am._last_voice_msec, 10)


func test_unknown_voice_warns_and_does_not_stamp() -> void:
	_use_fake_clock()
	_am.unlock()
	assert_null(_am._try_play_voice(&"vo_nope"))
	assert_push_warning("unknown sound vo_nope")
	assert_eq(_am._last_voice_msec, -1)
	_now = 10
	assert_not_null(_am._try_play_voice(&"vo_test"))


func test_zero_voice_gap_plays_every_call() -> void:
	_use_fake_clock()
	_am.library.voice_min_gap_s = 0.0
	_am.unlock()
	for i: int in 5:
		assert_not_null(_am._try_play_voice(&"vo_test"), "call %d" % i)


func test_voice_on_sfx_bus_with_cue_stream_and_volume() -> void:
	_am.unlock()
	var player: AudioStreamPlayer = _am._try_play_voice(&"vo_test")
	assert_not_null(player)
	if player == null:
		return
	assert_same(player.stream, _am.library.get_cue(&"vo_test").stream)
	assert_eq(player.volume_db, -4.0)
	assert_eq(player.bus, &"SFX", "the Sound toggle mutes voice too (FR46)")
	assert_true(player in _players())


func test_sfx_pool_exhaustion_never_steals_the_voice_player() -> void:
	_am.unlock()
	var voice: AudioStreamPlayer = _am._try_play_voice(&"vo_test")
	assert_not_null(voice)
	for i: int in 30:
		var player: AudioStreamPlayer = _am._try_play_sfx(&"sfx_test") as AudioStreamPlayer
		if voice.playing:
			assert_ne(player, voice, "call %d" % i)


func test_play_voice_public_entry() -> void:
	_use_fake_clock()
	_am.unlock()
	_am.play_voice(&"vo_test")
	assert_eq(_am._last_voice_msec, 0)


# --- ambience (Story 3.7, FR48) --------------------------------------------
# Synchronous bodies only: the fresh instance's own _process runs between frames and would take a due
# groan first if a test awaited.

func _seed_ambience(rng_seed: int = 7) -> void:
	_am.ambience_rng.seed = rng_seed


## The groan id of a player _update_ambience() returned, or &"" for anything else.
func _groan_id_of(player: AudioStreamPlayer) -> StringName:
	if player == null:
		return &""
	var index: int = _groan_streams.find(player.stream)
	return GROAN_IDS[index] if index != -1 else &""


## The gap from the current fake time to the next groan.
func _gap_after_due() -> int:
	return _am._next_groan_msec - _now


func test_ambience_starts_off() -> void:
	assert_false(_am.is_ambience_on())
	assert_eq(_am._next_groan_msec, -1)
	_use_fake_clock()
	_am.unlock()
	_now = 100000
	assert_null(_am._update_ambience(), "off: never a groan")


func test_start_ambience_schedules_within_3_to_8_s() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.start_ambience()
	assert_true(_am.is_ambience_on())
	assert_between(_am._next_groan_msec - 0, 3000, 8000)


func test_groan_plays_exactly_at_due_on_sfx_bus() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	var due: int = _am._next_groan_msec
	_now = due - 1
	assert_null(_am._update_ambience(), "not due yet")
	assert_eq(_am._next_groan_msec, due, "an early tick does not reschedule")
	_now = due
	var player: AudioStreamPlayer = _am._update_ambience()
	assert_not_null(player, "due: a groan")
	if player == null:
		return
	assert_eq(player.bus, &"SFX", "the Sound toggle mutes groans (FR46)")
	assert_true(player in _players())
	assert_true(_groan_streams.has(player.stream), "one of the 4 groans")
	assert_eq(player.volume_db, -8.0)


func test_groan_gaps_are_3_to_8_s_with_no_repeat() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	var low: int = 1 << 30
	var high: int = 0
	var below_mid: int = 0
	var above_mid: int = 0
	var last_id: StringName = &""
	var seen: Dictionary[StringName, bool] = {}
	var repeats: int = 0
	var out_of_range: int = 0
	var silent: int = 0
	for i: int in 500:
		_now = _am._next_groan_msec
		var id: StringName = _groan_id_of(_am._update_ambience())
		if id == &"":
			silent += 1
		if id == last_id:
			repeats += 1
		last_id = id
		seen[id] = true
		var gap: int = _gap_after_due()
		if gap < 3000 or gap > 8000:
			out_of_range += 1
		low = mini(low, gap)
		high = maxi(high, gap)
		if gap < 5500:
			below_mid += 1
		elif gap > 5500:
			above_mid += 1
	assert_eq(silent, 0, "every due tick played a groan")
	assert_eq(out_of_range, 0, "every gap is within 3-8 s")
	assert_eq(repeats, 0, "never the same groan twice in a row")
	for id: StringName in GROAN_IDS:
		assert_true(seen.has(id), "%s played" % id)
	assert_gt(below_mid, 0, "some short gaps")
	assert_gt(above_mid, 0, "some long gaps")
	assert_lt(low, 3500, "the short end is reached")
	assert_gt(high, 7500, "the long end is reached")


func test_single_groan_id_repeats() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.library.groan_ids = [&"sfx_groan_b"]
	_am.unlock()
	_am.start_ambience()
	for i: int in 10:
		_now = _am._next_groan_msec
		assert_eq(_groan_id_of(_am._update_ambience()), &"sfx_groan_b", "groan %d" % i)


func test_groan_skipped_within_2_s_of_a_voice_line() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_now = 10000
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_am.start_ambience()
	_am._next_groan_msec = 11999
	_now = 11999
	assert_null(_am._update_ambience(), "1999 ms after the voice: skipped")
	assert_between(_am._next_groan_msec - 11999, 3000, 8000, "skipped, not delayed: the next one is 3-8 s on")
	_am._next_groan_msec = 12000
	_now = 12000
	assert_not_null(_am._update_ambience(), "2000 ms after the voice: plays")


func test_dropped_voice_does_not_mute_groans() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_now = 5000
	assert_null(_am._try_play_voice(&"vo_test"), "in the 8 s gap: dropped")
	_am.start_ambience()
	_am._next_groan_msec = 5500
	_now = 5500
	assert_not_null(_am._update_ambience(), "the dropped call did not stamp, so no mute")


func test_groan_does_not_stamp_the_voice() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	_now = _am._next_groan_msec
	assert_not_null(_am._update_ambience())
	assert_eq(_am._last_voice_msec, -1)
	_now += 1
	assert_not_null(_am._try_play_voice(&"vo_test"), "a groan never blocks a Brainsss")


func test_groans_not_tied_to_keys() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	var due: int = _am._next_groan_msec
	_now = 1000
	_am._try_play_sfx(&"sfx_tick")
	_am.play_sfx(&"sfx_test")
	_am._try_play_voice(&"vo_test")
	_am.play_voice(&"vo_other")
	assert_eq(_am._next_groan_msec, due, "SFX and voice calls never move the next groan")


func test_start_twice_does_not_reschedule() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.start_ambience()
	var due: int = _am._next_groan_msec
	_now = 2000
	_am.start_ambience()
	assert_eq(_am._next_groan_msec, due)


func test_stop_and_restart_ambience() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	var due: int = _am._next_groan_msec
	_am.stop_ambience()
	assert_false(_am.is_ambience_on())
	_now = due + 100000
	assert_null(_am._update_ambience(), "stopped: no groan, however late")
	_am.stop_ambience()
	assert_false(_am.is_ambience_on(), "stop twice is fine")
	_am.start_ambience()
	assert_true(_am.is_ambience_on())
	assert_between(_am._next_groan_msec - _now, 3000, 8000, "a fresh gap from now")


func test_locked_ambience_reschedules_and_plays_nothing() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.start_ambience()
	var due: int = _am._next_groan_msec
	_now = due
	assert_null(_am._update_ambience(), "locked: no groan (FR47)")
	assert_between(_am._next_groan_msec - due, 3000, 8000, "the due time moved on")
	for player: AudioStreamPlayer in _players():
		assert_false(_groan_streams.has(player.stream), player.name)


func test_ambience_bad_config_warns_and_stays_off() -> void:
	_use_fake_clock()
	_am.unlock()
	_am.library.groan_ids = []
	_am.start_ambience()
	assert_push_warning("ambience off: no groan ids")
	assert_false(_am.is_ambience_on())
	_am.library.groan_ids = GROAN_IDS.duplicate()
	_am.library.groan_min_interval_s = 0.0
	_am.start_ambience()
	assert_push_warning("ambience off: bad groan interval")
	assert_false(_am.is_ambience_on())
	_am.library.groan_min_interval_s = 5.0
	_am.library.groan_max_interval_s = 4.0
	_am.start_ambience()
	assert_push_warning("ambience off: bad groan interval")
	assert_false(_am.is_ambience_on())
	_am.library = null
	_am.start_ambience()
	assert_push_warning("ambience off: no library")
	assert_false(_am.is_ambience_on())
	for i: int in 50:
		_now = i * 100
		assert_null(_am._update_ambience(), "tick %d" % i)
	assert_push_warning_count(4, "one warning per start, none per frame")


func test_unknown_groan_id_warns_once_at_start_and_stays_off() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.library.groan_ids = [&"sfx_groan_nope"]
	_am.unlock()
	_am.start_ambience()
	assert_push_warning("ambience off: groan sfx_groan_nope has no playable cue")
	assert_false(_am.is_ambience_on())
	for i: int in 50:
		_now = i * 1000
		assert_null(_am._update_ambience(), "tick %d" % i)
	assert_push_warning_count(1, "no warning per frame")


func test_sub_millisecond_interval_is_a_bad_config() -> void:
	_use_fake_clock()
	_am.library.groan_min_interval_s = 0.0001
	_am.library.groan_max_interval_s = 0.0002
	_am.start_ambience()
	assert_push_warning("ambience off: bad groan interval")
	assert_false(_am.is_ambience_on())


func test_library_emptied_while_on_stops_ambience() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	_am.library.groan_ids = []
	_now = _am._next_groan_msec
	assert_null(_am._update_ambience())
	assert_false(_am.is_ambience_on())
	_am.library = null
	_am.start_ambience()
	assert_push_warning("ambience off: no library")


func test_groan_plays_on_muted_sfx_bus() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.set_sfx_muted(true)
	_am.start_ambience()
	_now = _am._next_groan_msec
	var player: AudioStreamPlayer = _am._update_ambience()
	assert_not_null(player, "muting is the bus's job")
	if player != null:
		assert_eq(player.bus, &"SFX")


func test_ambience_rng_is_not_the_global_rng() -> void:
	_use_fake_clock()
	_am.unlock()
	var runs: Array[Array] = []
	for global_seed: int in [1, 999]:
		seed(global_seed)
		_am.stop_ambience()
		_seed_ambience(42)
		_am._last_groan_id = &""
		_now = 0
		_am.start_ambience()
		var draws: Array = [_am._next_groan_msec]
		for i: int in 19:
			_now = _am._next_groan_msec
			draws.append(_groan_id_of(_am._update_ambience()))
			draws.append(_gap_after_due())
		runs.append(draws)
	assert_eq(runs[0], runs[1], "the same ambience_rng seed gives the same groans and gaps whatever the global seed")


func test_process_runs_the_ambience() -> void:
	_use_fake_clock()
	_seed_ambience()
	_am.unlock()
	_am.start_ambience()
	_now = _am._next_groan_msec
	_am._process(0.0)
	var groaned: bool = false
	for player: AudioStreamPlayer in _players():
		if _groan_streams.has(player.stream):
			groaned = true
	assert_true(groaned, "_process played the due groan")
	assert_gt(_am._next_groan_msec, _now)


func test_default_ambience_rng_exists() -> void:
	var fresh: AudioManagerScript = AudioManagerScript.new()
	assert_not_null(fresh.ambience_rng)
	fresh.free()
