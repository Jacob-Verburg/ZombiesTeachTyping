extends Node
## Buses, SFX pool, music and the browser audio unlock (FR47).
## Buses: Master -> Music / SFX, no effects (default_bus_layout.tres). Pool: 8 SFX players + 1 music player,
## and only this script creates audio players. Nothing plays until unlock(), which the title calls from its
## first key/click callback; music requested before that waits as pending, SFX are dropped.
## Per-cue throttle (Story 2.5): a cue with min_interval_s > 0 is dropped while it played less than that
## long ago (the wrong-key tick: 150 ms, FR2); the gap counts from the last play, never from a dropped call.
## Later: 3.2 voice cooldown, 3.7 groans, play_voice() (3.2),
## start_ambience()/stop_ambience() (3.7) and the music crossfade (5.1). Audio rules live only here.

const LIBRARY: AudioLibrary = preload("res://data/audio/audio_library.tres")
const SFX_POOL_SIZE: int = 8
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

## Test seam: tests on a fresh instance assign a library built in code before add_child.
var library: AudioLibrary = LIBRARY
## Test seam: the clock the throttle reads, in milliseconds. Tests assign a fake.
var now_msec: Callable = Time.get_ticks_msec

var _unlocked: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_music: StringName = &""
var _pending_music: StringName = &""
var _next_steal: int = 0
## cue id -> now_msec() of its last actual play (throttled cues only).
var _last_played_msec: Dictionary[StringName, int] = {}


func _init() -> void:
	# Router pauses the tree during every fade; sound must keep going through it.
	# The players inherit this mode.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)


## Opens the audio gate. Call it synchronously from a user input callback (browser gesture rule).
## Starts any music requested while locked. Safe to call more than once.
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	Log.info(&"audio", "unlocked")
	if _pending_music != &"":
		var id: StringName = _pending_music
		_pending_music = &""
		_start_music(id)


func is_unlocked() -> bool:
	return _unlocked


func play_sfx(id: StringName) -> void:
	_try_play_sfx(id)


## Plays a sound effect and returns the pool player used, or null if nothing played.
## Before unlock() calls are dropped silently (FR47); they are not queued.
func _try_play_sfx(id: StringName) -> AudioStreamPlayer:
	if not _unlocked:
		return null
	var cue: AudioCue = _get_playable_cue(id)
	if cue == null:
		return null
	if cue.min_interval_s > 0.0:
		var now: int = now_msec.call()
		if _last_played_msec.has(id) and now - _last_played_msec[id] < roundi(cue.min_interval_s * 1000.0):
			return null
		_last_played_msec[id] = now
	var player: AudioStreamPlayer = _pick_sfx_player()
	player.stream = cue.stream
	player.volume_db = cue.volume_db
	player.play()
	return player


## A free pool player, or (all busy) the next one round-robin. The pool never grows.
func _pick_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	var stolen: AudioStreamPlayer = _sfx_players[_next_steal]
	_next_steal = (_next_steal + 1) % SFX_POOL_SIZE
	return stolen


## Starts a music loop. The same id already playing (or pending) is not restarted.
## While locked the id only becomes pending, and unlock() starts it.
func play_music(id: StringName) -> void:
	if id == &"":
		return
	if id == _pending_music or (id == _current_music and _music_player.playing):
		return
	if not _unlocked:
		_pending_music = id
		return
	_start_music(id)


func stop_music() -> void:
	_music_player.stop()
	_current_music = &""
	_pending_music = &""


func set_music_muted(muted: bool) -> void:
	_set_bus_mute(MUSIC_BUS, muted)


func set_sfx_muted(muted: bool) -> void:
	_set_bus_mute(SFX_BUS, muted)


func is_music_muted() -> bool:
	return _is_bus_mute(MUSIC_BUS)


func is_sfx_muted() -> bool:
	return _is_bus_mute(SFX_BUS)


func _start_music(id: StringName) -> void:
	var cue: AudioCue = _get_playable_cue(id)
	if cue == null:
		return
	_music_player.stream = cue.stream
	_music_player.volume_db = cue.volume_db
	_music_player.play()
	_current_music = id


## The cue for this id, or null (with a warning) if it is unknown or has no stream (NFR16: never crash).
func _get_playable_cue(id: StringName) -> AudioCue:
	var cue: AudioCue = library.get_cue(id) if library != null else null
	if cue == null or cue.stream == null:
		Log.warn(&"audio", "unknown sound %s" % id)
		return null
	return cue


func _set_bus_mute(bus: StringName, muted: bool) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index == -1:
		Log.error(&"audio", "missing bus %s" % bus)
		return
	AudioServer.set_bus_mute(index, muted)


func _is_bus_mute(bus: StringName) -> bool:
	var index: int = AudioServer.get_bus_index(bus)
	if index == -1:
		Log.error(&"audio", "missing bus %s" % bus)
		return false
	return AudioServer.is_bus_mute(index)
