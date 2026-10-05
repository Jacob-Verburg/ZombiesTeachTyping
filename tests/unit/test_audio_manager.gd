extends GutTest
## AudioManager buses, pool, unlock gate (FR47) and bus mute, on fresh instances.
## Never assert on the live AudioManager autoload: the title's _ready() talks to it during other tests.
## Headless runs use the Dummy audio driver, so the tests check which player and stream were picked,
## not audible output.

const AudioManagerScript := preload("res://scripts/autoloads/audio_manager.gd")

var _sfx_stream: AudioStreamWAV
var _music_stream: AudioStreamWAV
var _am: AudioManagerScript
## Fake clock for the per-cue throttle (Story 2.5), read through AudioManager.now_msec.
var _now: int = 0


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
