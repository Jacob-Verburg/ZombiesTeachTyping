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
## Fake frame counter (Story 5.1), read through AudioManager.frame_now: SFX in the unlock frame are held.
var _frame: int = 0


## An AudioManager whose players' "busy" state and music (re)starts are scripted (Story 5.1): headless runs
## use the Dummy driver, where `playing` can't be relied on.
class ScriptedAudioManager:
	extends "res://scripts/autoloads/audio_manager.gd"
	## Every player counts as busy (playing) while this is true.
	var all_busy: bool = false
	## Players that count as busy even when all_busy is false.
	var busy: Array[AudioStreamPlayer] = []
	## Every music player start, in order.
	var starts: Array[AudioStreamPlayer] = []

	func _is_busy(player: AudioStreamPlayer) -> bool:
		return all_busy or player in busy

	func _play_player(player: AudioStreamPlayer) -> void:
		starts.append(player)
		super._play_player(player)


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
	library.music_crossfade_s = 0.5
	library.music_pause_duck_db = -10.0
	_frame = 0
	_am = AudioManagerScript.new()
	_am.library = library
	_am.frame_now = func() -> int: return _frame
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


## The music player carrying the current loop.
func _music_player() -> AudioStreamPlayer:
	return _am._music_current


## Unlocks, then moves the fake clock to the next frame so SFX play at once (the unlock frame holds them).
func _unlock() -> void:
	_am.unlock()
	_frame += 1


## Replaces _am with a ScriptedAudioManager on the same library and fake clocks.
func _use_scripted() -> ScriptedAudioManager:
	var scripted: ScriptedAudioManager = ScriptedAudioManager.new()
	scripted.library = _am.library
	scripted.frame_now = _am.frame_now
	scripted.now_msec = _am.now_msec
	_am.free()
	_am = scripted
	add_child_autofree(scripted)
	return scripted


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


func test_pool_has_8_sfx_players_and_2_music_players() -> void:
	var players: Array[AudioStreamPlayer] = _players()
	assert_eq(players.size(), 10)
	var sfx_count: int = 0
	var music_count: int = 0
	for player: AudioStreamPlayer in players:
		if player.bus == &"SFX":
			sfx_count += 1
		elif player.bus == &"Music":
			music_count += 1
	assert_eq(sfx_count, AudioManagerScript.SFX_POOL_SIZE)
	assert_eq(sfx_count, 8)
	assert_eq(music_count, 2)
	assert_eq((_am.get_node("MusicA") as AudioStreamPlayer).bus, &"Music")
	assert_eq((_am.get_node("MusicB") as AudioStreamPlayer).bus, &"Music")


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
	_unlock()
	assert_same(_music_player().stream, _music_stream)
	_am._step_music(0.5)
	assert_almost_eq(_music_player().volume_db, -9.0, 0.001, "faded in to the cue volume")


func test_sfx_after_unlock_uses_cue_stream_and_volume() -> void:
	_unlock()
	var player: AudioStreamPlayer = _am._try_play_sfx(&"sfx_test") as AudioStreamPlayer
	assert_not_null(player)
	if player == null:
		return
	assert_same(player.stream, _sfx_stream)
	assert_eq(player.volume_db, -3.0)
	assert_eq(player.bus, &"SFX")
	assert_true(player in _players())


func test_unknown_sfx_warns_and_returns_null() -> void:
	_unlock()
	assert_null(_am._try_play_sfx(&"nope"))
	assert_push_warning("unknown sound nope")
	assert_null(_am._try_play_sfx(&"sfx_empty"))
	assert_push_warning("unknown sound sfx_empty")
	_am.play_sfx(&"nope")
	assert_push_warning("unknown sound nope")


func test_unknown_music_warns_and_plays_nothing() -> void:
	_unlock()
	_am.play_music(&"nope")
	assert_push_warning("unknown sound nope")
	assert_null(_music_player().stream)
	_am.play_music(&"sfx_empty")
	assert_push_warning("unknown sound sfx_empty")
	assert_null(_music_player().stream)


func test_unknown_music_while_locked_warns_at_once_and_starts_nothing() -> void:
	_am.play_music(&"nope")
	assert_push_warning("unknown sound nope")
	assert_eq(_am._pending_music, &"")
	_unlock()
	assert_null(_music_player().stream)


func test_unknown_music_while_locked_keeps_the_valid_pending_id() -> void:
	_am.play_music(&"mus_test")
	_am.play_music(&"nope")
	assert_push_warning("unknown sound nope")
	assert_eq(_am._pending_music, &"mus_test", "1.5 deferral: an unknown id never overwrites pending")
	_unlock()
	assert_eq(_am._current_music, &"mus_test")


func test_pool_exhaustion_steals_without_crashing() -> void:
	_unlock()
	for i: int in 20:
		var player: AudioStreamPlayer = _am._try_play_sfx(&"sfx_test") as AudioStreamPlayer
		assert_not_null(player, "call %d" % i)
		assert_true(player in _players(), "call %d" % i)
	assert_eq(_players().size(), 10)


func test_unlock_is_idempotent() -> void:
	_am.play_music(&"mus_test")
	_unlock()
	var stream: AudioStream = _music_player().stream
	_unlock()
	assert_true(_am.is_unlocked())
	assert_same(_music_player().stream, stream)
	assert_eq(_am._current_music, &"mus_test")
	assert_eq(_am._pending_music, &"")


func test_play_music_same_id_does_not_restart() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	_unlock()
	am.play_music(&"mus_test")
	assert_eq(am.starts.size(), 1)
	var player: AudioStreamPlayer = _music_player()
	am.busy = [player]
	am._step_music(0.1)
	am.play_music(&"mus_test")
	assert_eq(am.starts.size(), 1, "no restart mid-fade-in")
	assert_same(_music_player(), player)
	assert_almost_eq(am._gain_current, 0.2, 0.0001, "the fade-in carries on")
	am._step_music(0.5)
	am.play_music(&"mus_test")
	assert_eq(am.starts.size(), 1, "no restart at full volume")
	assert_eq(am._current_music, &"mus_test")


func test_same_id_whose_player_went_quiet_starts_again() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	_unlock()
	am.play_music(&"mus_test")
	am.play_music(&"mus_test")
	assert_eq(am.starts.size(), 2, "not busy: started again")
	assert_same(am.starts[1], am.starts[0], "on the same player")


func test_play_music_empty_id_is_ignored() -> void:
	_am.play_music(&"")
	assert_eq(_am._pending_music, &"")
	_unlock()
	_am.play_music(&"")
	assert_null(_music_player().stream)


func test_play_music_same_pending_id_stays_pending() -> void:
	_am.play_music(&"mus_test")
	_am.play_music(&"mus_test")
	assert_eq(_am._pending_music, &"mus_test")
	assert_null(_music_player().stream)


# --- music crossfade and duck (Story 5.1) ---------------------------------------------------------

## Adds a second music cue to the code-built library.
func _add_music_b() -> AudioStream:
	var stream: AudioStream = _stream()
	_am.library.cues.append(_cue(&"mus_b", stream, -12.0))
	return stream


## Linear fade gain of a player: its volume_db with the cue volume and the duck taken out.
func _gain(player: AudioStreamPlayer, cue_db: float) -> float:
	return db_to_linear(player.volume_db - cue_db - _am._duck_db)


func test_crossfade_volumes_at_0_025_05_s() -> void:
	var b_stream: AudioStream = _add_music_b()
	_unlock()
	_am.play_music(&"mus_test")
	_am._step_music(0.5)
	var a: AudioStreamPlayer = _music_player()
	_am.play_music(&"mus_b")
	var b: AudioStreamPlayer = _music_player()
	assert_ne(b, a, "the new loop starts on the idle player")
	assert_same(b.stream, b_stream)
	assert_almost_eq(_gain(a, -9.0), 1.0, 0.001, "0 s: old at full")
	assert_almost_eq(_gain(b, -12.0), 0.0, 0.001, "0 s: new at silence")
	_am._step_music(0.25)
	assert_almost_eq(_gain(a, -9.0), 0.5, 0.001, "0.25 s: old half way")
	assert_almost_eq(_gain(b, -12.0), 0.5, 0.001, "0.25 s: new half way")
	_am._step_music(0.25)
	assert_almost_eq(b.volume_db, -12.0, 0.001, "0.5 s: new at its cue volume")
	assert_eq(_am._old_music, &"", "0.5 s: the old loop is done")
	assert_false(a.playing, "and its player stopped")


func test_crossfade_length_comes_from_the_library() -> void:
	_add_music_b()
	_am.library.music_crossfade_s = 1.0
	_unlock()
	_am.play_music(&"mus_test")
	_am._step_music(1.0)
	_am.play_music(&"mus_b")
	_am._step_music(0.5)
	assert_almost_eq(_am._gain_current, 0.5, 0.0001)
	assert_almost_eq(_am._gain_old, 0.5, 0.0001)


func test_zero_crossfade_is_a_cut() -> void:
	_add_music_b()
	_am.library.music_crossfade_s = 0.0
	_unlock()
	_am.play_music(&"mus_test")
	assert_almost_eq(_music_player().volume_db, -9.0, 0.001)
	_am.play_music(&"mus_b")
	assert_almost_eq(_music_player().volume_db, -12.0, 0.001)
	assert_eq(_am._old_music, &"")


func test_return_to_the_fading_out_loop_does_not_restart_it() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	_add_music_b()
	_unlock()
	am.play_music(&"mus_test")
	am._step_music(0.5)
	var a: AudioStreamPlayer = _music_player()
	am.all_busy = true
	am.play_music(&"mus_b")
	var b: AudioStreamPlayer = _music_player()
	am._step_music(0.1)
	assert_eq(am.starts, [a, b] as Array[AudioStreamPlayer])
	am.play_music(&"mus_test")
	assert_eq(am.starts.size(), 2, "the fading-out loop is not restarted")
	assert_same(_music_player(), a, "it is current again")
	assert_almost_eq(am._gain_current, 0.8, 0.0001, "fading back in from where it was")
	assert_almost_eq(am._gain_old, 0.2, 0.0001, "the other one fades out from where it was")
	assert_eq(am._old_music, &"mus_b")
	am._step_music(0.1)
	assert_almost_eq(am._gain_current, 1.0, 0.0001)
	assert_eq(am._old_music, &"", "mus_b reached silence")


func test_a_third_loop_cuts_the_one_fading_out() -> void:
	_add_music_b()
	var c_stream: AudioStream = _stream()
	_am.library.cues.append(_cue(&"mus_c", c_stream, -10.0))
	_unlock()
	_am.play_music(&"mus_test")
	_am._step_music(0.5)
	_am.play_music(&"mus_b")
	_am._step_music(0.25)
	var b: AudioStreamPlayer = _music_player()
	_am.play_music(&"mus_c")
	assert_same(_music_player().stream, c_stream)
	assert_ne(_music_player(), b)
	assert_eq(_am._old_music, &"mus_b", "the loop that was coming in now fades out")
	assert_almost_eq(_am._gain_old, 0.5, 0.0001, "from where it was")
	assert_eq(_am._current_music, &"mus_c")


func test_unknown_music_while_unlocked_keeps_the_current_loop() -> void:
	_unlock()
	_am.play_music(&"mus_test")
	_am._step_music(0.5)
	var player: AudioStreamPlayer = _music_player()
	_am.play_music(&"nope")
	assert_push_warning("unknown sound nope")
	assert_eq(_am._current_music, &"mus_test")
	assert_same(_music_player(), player)
	assert_eq(_am._old_music, &"")
	assert_almost_eq(player.volume_db, -9.0, 0.001)


func test_process_runs_the_crossfade_under_a_paused_tree() -> void:
	_unlock()
	_am.play_music(&"mus_test")
	get_tree().paused = true
	var can_process: bool = _am.can_process()
	_am._process(0.25)
	get_tree().paused = false
	assert_true(can_process, "PROCESS_MODE_ALWAYS: the Router's pause never stops a fade")
	assert_almost_eq(_am._gain_current, 0.5, 0.0001, "_process steps the fade")


func test_duck_moves_to_the_library_value_and_back() -> void:
	_unlock()
	_am.play_music(&"mus_test")
	_am._step_music(0.5)
	assert_false(_am.is_music_ducked())
	_am.set_music_ducked(true)
	assert_true(_am.is_music_ducked())
	_am._step_music(0.075)
	assert_almost_eq(_music_player().volume_db, -14.0, 0.001, "half way down the 0.15 s ramp")
	_am._step_music(0.1)
	assert_almost_eq(_music_player().volume_db, -19.0, 0.001, "-9 cue - 10 duck")
	assert_eq(_am._current_music, &"mus_test", "the loop keeps playing")
	_am.set_music_ducked(false)
	assert_false(_am.is_music_ducked())
	_am._step_music(0.2)
	assert_almost_eq(_music_player().volume_db, -9.0, 0.001, "back to full")


func test_a_new_loop_clears_the_duck() -> void:
	_add_music_b()
	_unlock()
	_am.play_music(&"mus_test")
	_am.set_music_ducked(true)
	_am._step_music(0.5)
	_am.play_music(&"mus_b")
	assert_false(_am.is_music_ducked())
	_am._step_music(0.5)
	assert_eq(_am._duck_db, 0.0)
	assert_almost_eq(_music_player().volume_db, -12.0, 0.001)


func test_same_loop_keeps_the_duck() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	am.all_busy = true
	_unlock()
	am.play_music(&"mus_test")
	am.set_music_ducked(true)
	am.play_music(&"mus_test")
	assert_true(am.is_music_ducked(), "asking for the playing loop is not a new loop")


func test_stop_music_clears_the_duck_and_both_players() -> void:
	_add_music_b()
	_unlock()
	_am.play_music(&"mus_test")
	_am._step_music(0.5)
	_am.play_music(&"mus_b")
	_am.set_music_ducked(true)
	_am._step_music(0.1)
	_am.stop_music()
	assert_false(_am.is_music_ducked())
	assert_eq(_am._duck_db, 0.0)
	assert_eq(_am._current_music, &"")
	assert_eq(_am._old_music, &"")
	for player_name: String in ["MusicA", "MusicB"]:
		assert_false((_am.get_node(player_name) as AudioStreamPlayer).playing, player_name)


func test_music_volume_is_never_nan_or_inf() -> void:
	_add_music_b()
	_unlock()
	var players: Array[AudioStreamPlayer] = [_am.get_node("MusicA"), _am.get_node("MusicB")]
	var bad: Array[String] = []
	var check: Callable = func(label: String) -> void:
		for player: AudioStreamPlayer in players:
			if is_nan(player.volume_db) or is_inf(player.volume_db):
				bad.append("%s %s" % [label, player.name])
	check.call("idle")
	_am.play_music(&"mus_test")
	check.call("start")
	for i: int in 10:
		_am._step_music(0.1)
		check.call("step %d" % i)
	_am.play_music(&"mus_b")
	_am.set_music_ducked(true)
	for i: int in 10:
		_am._step_music(0.1)
		check.call("fade %d" % i)
	_am.stop_music()
	check.call("stopped")
	assert_eq(bad, [] as Array[String])


func test_set_music_ducked_without_library_is_safe() -> void:
	_am.library = null
	_am.set_music_ducked(true)
	_am._step_music(0.1)
	assert_eq(_am._duck_db, 0.0)


func test_stop_music_clears_current_and_pending() -> void:
	_am.play_music(&"mus_test")
	_am.stop_music()
	assert_eq(_am._pending_music, &"")
	_unlock()
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
	_unlock()
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
	_unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"))
	_now = 140
	assert_null(_am._try_play_sfx(&"sfx_tick"))
	_now = 160
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "the dropped call at 140 did not stamp")


func test_throttle_is_per_cue() -> void:
	_use_fake_clock()
	_unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"))
	assert_not_null(_am._try_play_sfx(&"sfx_tock"), "another throttled id is not blocked")
	assert_not_null(_am._try_play_sfx(&"sfx_test"), "an unthrottled id is not blocked")


func test_unthrottled_cue_plays_every_call() -> void:
	_use_fake_clock()
	_unlock()
	for i: int in 5:
		assert_not_null(_am._try_play_sfx(&"sfx_test"), "call %d" % i)


func test_locked_call_does_not_stamp() -> void:
	_use_fake_clock()
	assert_null(_am._try_play_sfx(&"sfx_tick"), "locked: dropped")
	_now = 10
	_unlock()
	assert_not_null(_am._try_play_sfx(&"sfx_tick"), "first call after unlock plays")


func test_default_clock_is_ticks_msec() -> void:
	var fresh: AudioManagerScript = AudioManagerScript.new()
	assert_true(fresh.now_msec.is_valid())
	assert_true(fresh.now_msec.call() >= 0)
	fresh.free()


# --- voice lines (Story 3.2, FR48) -----------------------------------------

func test_voice_gap_8_seconds() -> void:
	_use_fake_clock()
	_unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"), "t=0 plays")
	_now = 7999
	assert_null(_am._try_play_voice(&"vo_test"), "t=7999 dropped")
	_now = 8000
	assert_not_null(_am._try_play_voice(&"vo_test"), "t=8000 plays")


func test_dropped_voice_does_not_restart_the_gap() -> void:
	_use_fake_clock()
	_unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_now = 5000
	assert_null(_am._try_play_voice(&"vo_test"))
	assert_eq(_am._last_voice_msec, 0, "the drop did not stamp")
	_now = 8000
	assert_not_null(_am._try_play_voice(&"vo_test"), "counted from the play at 0, not the drop at 5000")
	assert_eq(_am._last_voice_msec, 8000)


func test_voice_gap_is_shared_across_ids() -> void:
	_use_fake_clock()
	_unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"))
	_now = 1000
	assert_null(_am._try_play_voice(&"vo_other"), "any voice line waits for the gap")


func test_voice_and_sfx_are_independent() -> void:
	_use_fake_clock()
	_unlock()
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
	_unlock()
	assert_not_null(_am._try_play_voice(&"vo_test"), "first call after unlock plays")
	assert_eq(_am._last_voice_msec, 10)


func test_unknown_voice_warns_and_does_not_stamp() -> void:
	_use_fake_clock()
	_unlock()
	assert_null(_am._try_play_voice(&"vo_nope"))
	assert_push_warning("unknown sound vo_nope")
	assert_eq(_am._last_voice_msec, -1)
	_now = 10
	assert_not_null(_am._try_play_voice(&"vo_test"))


func test_zero_voice_gap_plays_every_call() -> void:
	_use_fake_clock()
	_am.library.voice_min_gap_s = 0.0
	_unlock()
	for i: int in 5:
		assert_not_null(_am._try_play_voice(&"vo_test"), "call %d" % i)


func test_voice_on_sfx_bus_with_cue_stream_and_volume() -> void:
	_unlock()
	var player: AudioStreamPlayer = _am._try_play_voice(&"vo_test")
	assert_not_null(player)
	if player == null:
		return
	assert_same(player.stream, _am.library.get_cue(&"vo_test").stream)
	assert_eq(player.volume_db, -4.0)
	assert_eq(player.bus, &"SFX", "the Sound toggle mutes voice too (FR46)")
	assert_true(player in _players())


func test_sfx_pool_exhaustion_never_steals_the_voice_player() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	am.all_busy = true
	_unlock()
	var voice: AudioStreamPlayer = am._try_play_voice(&"vo_test")
	assert_not_null(voice)
	for i: int in 30:
		var player: AudioStreamPlayer = am._try_play_sfx(&"sfx_test") as AudioStreamPlayer
		assert_ne(player, voice, "call %d" % i)


func test_busy_pool_steals_round_robin() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	am.all_busy = true
	_unlock()
	var picked: Array[AudioStreamPlayer] = []
	for i: int in AudioManagerScript.SFX_POOL_SIZE * 2:
		picked.append(am._try_play_sfx(&"sfx_test") as AudioStreamPlayer)
	for i: int in AudioManagerScript.SFX_POOL_SIZE:
		assert_same(picked[i], am._sfx_players[i], "call %d" % i)
		assert_same(picked[i + AudioManagerScript.SFX_POOL_SIZE], am._sfx_players[i], "wraps at %d" % i)


func test_free_player_is_picked_before_stealing() -> void:
	var am: ScriptedAudioManager = _use_scripted()
	_unlock()
	am.busy = am._sfx_players.duplicate()
	am.busy.erase(am._sfx_players[5])
	assert_same(am._try_play_sfx(&"sfx_test"), am._sfx_players[5])


# --- variants and the unlock frame (Story 5.1) ----------------------------------------------------

func test_cue_without_alt_streams_never_touches_variant_rng() -> void:
	_unlock()
	_am.variant_rng.seed = 11
	var state: int = _am.variant_rng.state
	_am._try_play_sfx(&"sfx_test")
	assert_eq(_am.variant_rng.state, state)


func test_variant_pick_uses_variant_rng_and_both_takes_come_up() -> void:
	var take_2: AudioStream = _stream()
	var cue: AudioCue = _am.library.get_cue(&"vo_test")
	cue.alt_streams = [null, take_2]
	_am.library.voice_min_gap_s = 0.0
	_unlock()
	_am.variant_rng.seed = 42
	var seen: Dictionary[AudioStream, int] = {}
	var order: Array[AudioStream] = []
	for i: int in 40:
		var player: AudioStreamPlayer = _am._try_play_voice(&"vo_test")
		seen[player.stream] = seen.get(player.stream, 0) + 1
		order.append(player.stream)
	assert_eq(seen.size(), 2, "both takes, never the null entry")
	assert_true(seen.has(cue.stream) and seen.has(take_2))
	# Same seed, same picks, whatever the global RNG does: the pick reads variant_rng only.
	_am.variant_rng.seed = 42
	seed(1)
	for i: int in 40:
		assert_same(_am._try_play_voice(&"vo_test").stream, order[i], "pick %d" % i)


func test_default_variant_rng_exists() -> void:
	var fresh: AudioManagerScript = AudioManagerScript.new()
	assert_not_null(fresh.variant_rng)
	assert_ne(fresh.variant_rng, fresh.ambience_rng)
	fresh.free()


## The streams currently set on SFX pool players.
func _pool_streams() -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for player: AudioStreamPlayer in _am._sfx_players:
		if player.stream != null:
			streams.append(player.stream)
	return streams


func test_sfx_in_the_unlock_frame_play_on_the_next_frame_once() -> void:
	_am.unlock()
	assert_null(_am._try_play_sfx(&"sfx_test"), "held in the unlock frame")
	_am._process(0.0)
	assert_eq(_pool_streams().size(), 0, "still the unlock frame: nothing played")
	_frame += 1
	_am._process(0.0)
	assert_eq(_pool_streams(), [_sfx_stream] as Array[AudioStream], "played once on the next frame")
	_frame += 1
	_am._process(0.0)
	assert_eq(_pool_streams().size(), 1, "never twice")


func test_sfx_after_the_unlock_frame_play_at_once() -> void:
	_am.unlock()
	_frame += 1
	assert_not_null(_am._try_play_sfx(&"sfx_test"))


func test_default_frame_clock_is_process_frames() -> void:
	var fresh: AudioManagerScript = AudioManagerScript.new()
	assert_eq(fresh.frame_now.call(), Engine.get_process_frames())
	fresh.free()


func test_play_voice_public_entry() -> void:
	_use_fake_clock()
	_unlock()
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
	_unlock()
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
	_unlock()
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
	_unlock()
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
	_unlock()
	_am.start_ambience()
	for i: int in 10:
		_now = _am._next_groan_msec
		assert_eq(_groan_id_of(_am._update_ambience()), &"sfx_groan_b", "groan %d" % i)


func test_groan_skipped_within_2_s_of_a_voice_line() -> void:
	_use_fake_clock()
	_seed_ambience()
	_unlock()
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
	_unlock()
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
	_unlock()
	_am.start_ambience()
	_now = _am._next_groan_msec
	assert_not_null(_am._update_ambience())
	assert_eq(_am._last_voice_msec, -1)
	_now += 1
	assert_not_null(_am._try_play_voice(&"vo_test"), "a groan never blocks a Brainsss")


func test_groans_not_tied_to_keys() -> void:
	_use_fake_clock()
	_seed_ambience()
	_unlock()
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
	_unlock()
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
	_unlock()
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
	_unlock()
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
	_unlock()
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
	_unlock()
	_am.set_sfx_muted(true)
	_am.start_ambience()
	_now = _am._next_groan_msec
	var player: AudioStreamPlayer = _am._update_ambience()
	assert_not_null(player, "muting is the bus's job")
	if player != null:
		assert_eq(player.bus, &"SFX")


func test_ambience_rng_is_not_the_global_rng() -> void:
	_use_fake_clock()
	_unlock()
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
	_unlock()
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


# --- Story 4.2: saved Music/Sound settings drive the buses -------------------------------------------

const SaveServiceScript := preload("res://scripts/autoloads/save_service.gd")
const PlayerDataScript := preload("res://scripts/autoloads/player_data.gd")
const SETTINGS_DIR: String = "user://test_audio_manager_settings/"


func _clear_settings_dir() -> void:
	if not DirAccess.dir_exists_absolute(SETTINGS_DIR):
		return
	for file_name: String in DirAccess.get_files_at(SETTINGS_DIR):
		DirAccess.remove_absolute(SETTINGS_DIR.path_join(file_name))


## A fresh PlayerData on a temp-dir SaveService (never the real save), with `settings` applied
## before the AudioManager under test sees it.
func _player_data(settings: Dictionary = {}) -> PlayerDataScript:
	DirAccess.make_dir_recursive_absolute(SETTINGS_DIR)
	_clear_settings_dir()
	var save: SaveServiceScript = SaveServiceScript.new()
	save.save_dir = SETTINGS_DIR
	add_child_autofree(save)
	var player: PlayerDataScript = PlayerDataScript.new()
	player.save_service = save
	add_child_autofree(player)
	for key: StringName in settings:
		player.set_setting(key, settings[key])
	return player


## A fresh AudioManager listening to `player`.
func _am_with(player: PlayerDataScript) -> AudioManagerScript:
	var am: AudioManagerScript = AudioManagerScript.new()
	am.library = _am.library
	am.player_data = player
	add_child_autofree(am)
	return am


func test_saved_music_off_mutes_music_bus_at_startup() -> void:
	var am: AudioManagerScript = _am_with(_player_data({&"music_on": false}))
	assert_true(am.is_music_muted(), "music_on = false is applied in _ready")
	assert_false(am.is_sfx_muted())
	_clear_settings_dir()


func test_saved_sound_off_mutes_sfx_bus_at_startup() -> void:
	var am: AudioManagerScript = _am_with(_player_data({&"sound_on": false}))
	assert_true(am.is_sfx_muted())
	assert_false(am.is_music_muted())
	_clear_settings_dir()


func test_saved_settings_on_unmute_buses_at_startup() -> void:
	_am.set_music_muted(true)
	_am.set_sfx_muted(true)
	var am: AudioManagerScript = _am_with(_player_data())
	assert_false(am.is_music_muted(), "defaults are on")
	assert_false(am.is_sfx_muted())
	_clear_settings_dir()


func test_settings_changed_follows_each_key() -> void:
	var player: PlayerDataScript = _player_data()
	var am: AudioManagerScript = _am_with(player)
	player.set_setting(&"sound_on", false)
	assert_true(am.is_sfx_muted())
	assert_false(am.is_music_muted(), "only the changed key is applied")
	player.set_setting(&"music_on", false)
	assert_true(am.is_music_muted())
	player.set_setting(&"sound_on", true)
	assert_false(am.is_sfx_muted())
	assert_true(am.is_music_muted())
	_clear_settings_dir()


func test_profile_replaced_reapplies_defaults() -> void:
	var player: PlayerDataScript = _player_data({&"music_on": false, &"sound_on": false})
	var am: AudioManagerScript = _am_with(player)
	assert_true(am.is_music_muted())
	assert_true(am.is_sfx_muted())
	player.reset_all()
	assert_false(am.is_music_muted(), "reset_all re-applies the default music_on")
	assert_false(am.is_sfx_muted(), "reset_all re-applies the default sound_on")
	_clear_settings_dir()


func test_default_player_data_is_the_autoload() -> void:
	assert_eq(_am.player_data, PlayerData)
