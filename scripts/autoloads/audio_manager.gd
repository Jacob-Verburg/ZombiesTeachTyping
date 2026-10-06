extends Node
## Buses, SFX pool, music and the browser audio unlock (FR47).
## Buses: Master -> Music / SFX, no effects (default_bus_layout.tres). Pool: 8 SFX players + 1 music player,
## and only this script creates audio players. Nothing plays until unlock(), which the title calls from its
## first key/click callback; music requested before that waits as pending, SFX are dropped.
## Per-cue throttle (Story 2.5): a cue with min_interval_s > 0 is dropped while it played less than that
## long ago (the wrong-key tick: 150 ms, FR2); the gap counts from the last play, never from a dropped call.
## Voice lines (Story 3.2): play_voice() plays a vo_* cue on the SFX bus (the Sound toggle mutes it), at
## least library.voice_min_gap_s apart across every voice id (FR48: 8 s). Like the throttle, the gap counts
## from the last voice that actually played; locked, unknown and dropped calls never stamp it. Callers decide
## the chance (Zombie Run's 20% Brainsss roll), only this script decides the spacing.
## Ambience (Story 3.7): between start_ambience() and stop_ambience() one groan, picked from
## library.groan_ids with ambience_rng (never the run RNG or the global one, never the same id twice in a
## row), plays every library.groan_min..max_interval_s. A groan that comes due within groan_voice_mute_s of
## the last voice line that played is skipped, not delayed; a groan never stamps the voice time. RunFrame
## owns on/off (on exactly while RUNNING): this node is PROCESS_MODE_ALWAYS, so a tree pause does not stop
## the groan clock, and RunFrame stops ambience on pause instead.
## Settings (Story 4.2): the Music/Sound buses follow PlayerData's music_on/sound_on, applied at startup and
## on every settings_changed / profile_replaced. Screens only call PlayerData.set_setting().
## Later: the music crossfade (5.1). Audio rules live only here.

const LIBRARY: AudioLibrary = preload("res://data/audio/audio_library.tres")
const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const SFX_POOL_SIZE: int = 8
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"

## Test seam: tests on a fresh instance assign a library built in code before add_child.
var library: AudioLibrary = LIBRARY
## Test seam: the clock the throttle reads, in milliseconds. Tests assign a fake.
var now_msec: Callable = Time.get_ticks_msec
## Test seam: the RNG for groan gaps and picks (created and randomized in _init). Tests reseed it before
## start_ambience(). Never the run RNG (seed replays) nor the global one.
var ambience_rng: RandomNumberGenerator
## Test seam: the PlayerData whose settings drive the bus mutes. Defaults to the PlayerData autoload in
## _ready() (autoload #3, ready before this one). Tests assign a fresh one on a temp save before add_child.
var player_data: PlayerDataScript = null

var _unlocked: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_music: StringName = &""
var _pending_music: StringName = &""
var _next_steal: int = 0
## cue id -> now_msec() of its last actual play (throttled cues only).
var _last_played_msec: Dictionary[StringName, int] = {}
## now_msec() of the last voice line that actually played, or -1 before the first one.
var _last_voice_msec: int = -1
## The pool player carrying the latest voice line; SFX stealing skips it while it plays.
var _voice_player: AudioStreamPlayer = null
var _ambience_on: bool = false
## now_msec() when the next groan is due, or -1 while ambience is off.
var _next_groan_msec: int = -1
## The groan that played last; the next pick excludes it.
var _last_groan_id: StringName = &""


func _init() -> void:
	# Router pauses the tree during every fade; sound must keep going through it.
	# The players inherit this mode.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambience_rng = RandomNumberGenerator.new()
	ambience_rng.randomize()


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
	if player_data == null:
		player_data = PlayerData
	player_data.settings_changed.connect(_on_settings_changed)
	player_data.profile_replaced.connect(_apply_saved_settings)
	_apply_saved_settings()


func _process(_delta: float) -> void:
	_update_ambience()


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
	return _play_on_pool(cue)


## Plays a voice line (vo_*) unless another one played less than voice_min_gap_s ago.
func play_voice(id: StringName) -> void:
	_try_play_voice(id)


## Plays a voice line and returns the pool player used, or null if nothing played.
## Dropped before unlock() (FR47), for an unknown id (with a warning) and inside the voice gap.
func _try_play_voice(id: StringName) -> AudioStreamPlayer:
	if not _unlocked:
		return null
	var cue: AudioCue = _get_playable_cue(id)
	if cue == null:
		return null
	var now: int = now_msec.call()
	var gap_msec: int = roundi(library.voice_min_gap_s * 1000.0) if library != null else 0
	if _last_voice_msec != -1 and now - _last_voice_msec < gap_msec:
		return null
	var player: AudioStreamPlayer = _play_on_pool(cue)
	_last_voice_msec = now
	_voice_player = player
	return player


## Plays the cue on a pool player (SFX bus) with the cue's stream and volume.
func _play_on_pool(cue: AudioCue) -> AudioStreamPlayer:
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
	if stolen == _voice_player:
		stolen = _sfx_players[_next_steal]
		_next_steal = (_next_steal + 1) % SFX_POOL_SIZE
	return stolen


## Starts the groans (RunFrame: on entering RUNNING). Already on: nothing changes (no reschedule).
## A broken library setup warns once here and leaves ambience off, so it never groans every frame.
## Works while locked: the schedule runs and due groans are dropped until unlock().
func start_ambience() -> void:
	if _ambience_on:
		return
	var problem: String = _ambience_problem()
	if problem != "":
		Log.warn(&"audio", "ambience off: %s" % problem)
		return
	_ambience_on = true
	_next_groan_msec = now_msec.call() + _random_groan_gap_msec()


## Stops the groans (RunFrame: on leaving RUNNING). A groan already playing finishes (it is short).
func stop_ambience() -> void:
	_ambience_on = false
	_next_groan_msec = -1


func is_ambience_on() -> bool:
	return _ambience_on


## Why the library can't drive ambience, or "" when it can.
func _ambience_problem() -> String:
	if library == null:
		return "no library"
	if library.groan_ids.is_empty():
		return "no groan ids"
	if roundi(library.groan_min_interval_s * 1000.0) < 1 or library.groan_max_interval_s < library.groan_min_interval_s:
		return "bad groan interval"
	for id: StringName in library.groan_ids:
		var cue: AudioCue = library.get_cue(id)
		if cue == null or cue.stream == null:
			return "groan %s has no playable cue" % id
	return ""


## The per-frame ambience step. Returns the player of the groan that played, or null.
## Every due tick reschedules first, played or not, so a skipped groan never retries every frame.
func _update_ambience() -> AudioStreamPlayer:
	if not _ambience_on:
		return null
	if library == null or library.groan_ids.is_empty():
		stop_ambience()
		return null
	var now: int = now_msec.call()
	if now < _next_groan_msec:
		return null
	_next_groan_msec = now + _random_groan_gap_msec()
	if not _unlocked:
		return null
	if _last_voice_msec != -1 and now - _last_voice_msec < roundi(library.groan_voice_mute_s * 1000.0):
		return null
	var id: StringName = _pick_groan_id()
	var cue: AudioCue = _get_playable_cue(id)
	if cue == null:
		return null
	var player: AudioStreamPlayer = _play_on_pool(cue)
	_last_groan_id = id
	return player


## A random groan id, never the one that played last (with 2+ ids).
func _pick_groan_id() -> StringName:
	var ids: Array[StringName] = library.groan_ids
	if ids.size() == 1:
		return ids[0]
	var candidates: Array[StringName] = ids.filter(func(id: StringName) -> bool: return id != _last_groan_id)
	if candidates.is_empty():
		return ids[0]
	return candidates[ambience_rng.randi_range(0, candidates.size() - 1)]


## A fresh gap in [groan_min_interval_s, groan_max_interval_s], in milliseconds.
func _random_groan_gap_msec() -> int:
	return ambience_rng.randi_range(
			roundi(library.groan_min_interval_s * 1000.0), roundi(library.groan_max_interval_s * 1000.0))


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


## Mutes each bus whose saved setting is off, unmutes it otherwise.
func _apply_saved_settings() -> void:
	set_music_muted(not player_data.get_setting(&"music_on"))
	set_sfx_muted(not player_data.get_setting(&"sound_on"))


func _on_settings_changed(key: StringName, value: bool) -> void:
	match key:
		&"music_on":
			set_music_muted(not value)
		&"sound_on":
			set_sfx_muted(not value)


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
