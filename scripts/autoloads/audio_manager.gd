extends Node
## Buses, SFX pool, music and the browser audio unlock (FR47).
## Buses: Master -> Music / SFX, no effects (default_bus_layout.tres). Pool: 8 SFX players + 2 music players
## (MusicA / MusicB), and only this script creates audio players. Nothing plays until unlock(), which the
## title calls from its first key/click callback; music requested before that waits as pending, SFX are
## dropped. SFX requested in the unlock frame itself are held and played on the next frame (Story 5.1): the
## browser's AudioContext is still resuming during that frame and would swallow them.
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
## Music (Story 5.1): play_music() crossfades over library.music_crossfade_s (0.5 s): the new loop fades in
## on the idle player while the old one fades out and then stops. The same loop is never restarted; asking
## for the loop that is fading out fades it back in from where it is. set_music_ducked() lowers the music by
## library.music_pause_duck_db (a paused run) and a new loop clears it. Fades run by hand in _process (this
## node is PROCESS_MODE_ALWAYS, so the Router's tree pause doesn't stop them), in linear gain, never -INF dB.
## Variants (Story 5.1): a cue with alt_streams plays one of its takes at random from variant_rng.
## Audio rules live only here.

const LIBRARY: AudioLibrary = preload("res://data/audio/audio_library.tres")
const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const SFX_POOL_SIZE: int = 8
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
## Look value: how long the pause duck takes to move in or out.
const DUCK_RAMP_S: float = 0.15
## Linear gain floor before converting to dB, so volume_db is never -INF (NaN on some web paths).
const MIN_GAIN: float = 0.0001

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
## Test seam: the RNG that picks between a cue's takes (created and randomized in _init). Never the run
## RNG (seed replays) nor the global one.
var variant_rng: RandomNumberGenerator
## Test seam: the frame counter the unlock-frame SFX hold reads. Tests assign a fake.
var frame_now: Callable = Engine.get_process_frames

var _unlocked: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
## The music player whose loop is current (fading in or playing) and the one fading out (or idle).
var _music_current: AudioStreamPlayer
var _music_old: AudioStreamPlayer
var _current_music: StringName = &""
## The loop on _music_old while it fades out, or &"" once it has stopped.
var _old_music: StringName = &""
## Linear fade gains (0..1) and cue volumes of the two music players.
var _gain_current: float = 0.0
var _gain_old: float = 0.0
var _cue_db_current: float = 0.0
var _cue_db_old: float = 0.0
var _music_ducked: bool = false
## The duck's attenuation right now (dB, <= 0) and where it is heading.
var _duck_db: float = 0.0
var _duck_target_db: float = 0.0
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
## frame_now() when unlock() ran, or -1 before it; SFX asked for in that frame wait in _held_sfx.
var _unlock_frame: int = -1
## The most SFX held in the unlock frame (a key-mash there must not stack a burst on the next frame).
const MAX_HELD_SFX: int = 4
var _held_sfx: Array[StringName] = []


func _init() -> void:
	# Router pauses the tree during every fade; sound must keep going through it.
	# The players inherit this mode.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambience_rng = RandomNumberGenerator.new()
	ambience_rng.randomize()
	variant_rng = RandomNumberGenerator.new()
	variant_rng.randomize()


func _ready() -> void:
	for i: int in SFX_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)
	_music_current = _new_music_player("MusicA")
	_music_old = _new_music_player("MusicB")
	if player_data == null:
		player_data = PlayerData
	player_data.settings_changed.connect(_on_settings_changed)
	player_data.profile_replaced.connect(_apply_saved_settings)
	_apply_saved_settings()


func _process(delta: float) -> void:
	_flush_held_sfx()
	_step_music(delta)
	_update_ambience()


func _new_music_player(player_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.bus = MUSIC_BUS
	player.volume_db = linear_to_db(MIN_GAIN)
	add_child(player)
	return player


## Opens the audio gate. Call it synchronously from a user input callback (browser gesture rule).
## Starts any music requested while locked. Safe to call more than once.
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	_unlock_frame = frame_now.call()
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
## Before unlock() calls are dropped silently (FR47); they are not queued. In the unlock frame they are
## held (returns null) and played once on the next frame.
func _try_play_sfx(id: StringName) -> AudioStreamPlayer:
	if not _unlocked:
		return null
	if frame_now.call() == _unlock_frame:
		if _held_sfx.size() < MAX_HELD_SFX and not _held_sfx.has(id):
			_held_sfx.append(id)
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


## Plays the SFX held in the unlock frame, once each, from the first later frame.
func _flush_held_sfx() -> void:
	if _held_sfx.is_empty() or frame_now.call() == _unlock_frame:
		return
	var held: Array[StringName] = _held_sfx
	_held_sfx = []
	for id: StringName in held:
		_try_play_sfx(id)


## Plays the cue on a pool player (SFX bus) with one of the cue's takes and its volume.
func _play_on_pool(cue: AudioCue) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _pick_sfx_player()
	player.stream = _pick_take(cue)
	player.volume_db = cue.volume_db
	player.play()
	return player


## cue.stream, or (with alt_streams) one of [stream] + alt_streams picked with variant_rng. Nulls skipped.
func _pick_take(cue: AudioCue) -> AudioStream:
	var takes: Array[AudioStream] = [cue.stream]
	for alt: AudioStream in cue.alt_streams:
		if alt != null:
			takes.append(alt)
	if takes.size() == 1:
		return cue.stream
	return takes[variant_rng.randi_range(0, takes.size() - 1)]


## Whether a player is still sounding. Test seam: headless runs use the Dummy driver, where `playing`
## can't be relied on, so tests override this on a subclass.
func _is_busy(player: AudioStreamPlayer) -> bool:
	return player.playing


## Starts a music player from the top. Test seam: tests override it to count (re)starts.
func _play_player(player: AudioStreamPlayer) -> void:
	player.play()


## A free pool player, or (all busy) the next one round-robin. The pool never grows.
func _pick_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not _is_busy(player):
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


## Crossfades to a music loop. The same id already playing (or pending) is not restarted. An unknown id
## warns and changes nothing (it never replaces a valid pending id or the current loop).
## While locked the id only becomes pending, and unlock() starts it.
func play_music(id: StringName) -> void:
	if id == &"":
		return
	if id == _pending_music or (id == _current_music and _is_busy(_music_current)):
		return
	if _get_playable_cue(id) == null:
		return
	if not _unlocked:
		_pending_music = id
		return
	_start_music(id)


## Stops both music players at once and clears the current and pending loop and the duck.
func stop_music() -> void:
	_music_current.stop()
	_music_old.stop()
	_current_music = &""
	_old_music = &""
	_pending_music = &""
	_gain_current = 0.0
	_gain_old = 0.0
	_music_ducked = false
	_duck_db = 0.0
	_duck_target_db = 0.0
	_apply_music_volumes()


## Lowers the music by library.music_pause_duck_db (on) or back to full (off) over DUCK_RAMP_S; the loop
## keeps playing. RunFrame ducks while a run is paused or counting down. A new loop clears it.
func set_music_ducked(on: bool) -> void:
	_music_ducked = on
	_duck_target_db = library.music_pause_duck_db if on and library != null else 0.0


func is_music_ducked() -> bool:
	return _music_ducked


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


## Starts (or brings back) a loop. The loop that is fading out swaps back in from its current gain; any
## other loop starts at silence on the idle player while the current one becomes the one fading out.
func _start_music(id: StringName) -> void:
	if id == _current_music:
		# Same loop but its player went quiet: start it again, keeping the fade where it is.
		var same_cue: AudioCue = _get_playable_cue(id)
		if same_cue != null:
			_music_current.stream = same_cue.stream
			_cue_db_current = same_cue.volume_db
		_play_player(_music_current)
		_apply_music_volumes()
		return
	var cue: AudioCue = _get_playable_cue(id)
	if cue == null:
		return
	var previous: AudioStreamPlayer = _music_current
	if id == _old_music:
		_music_current = _music_old
		_music_old = previous
		var gain: float = _gain_current
		_gain_current = _gain_old
		_gain_old = gain
		var cue_db: float = _cue_db_current
		_cue_db_current = _cue_db_old
		_cue_db_old = cue_db
		_old_music = _current_music
		_current_music = id
		if not _is_busy(_music_current):
			_play_player(_music_current)
	else:
		# A loop still fading out is cut: its player takes the new loop.
		_music_old.stop()
		_music_current = _music_old
		_music_old = previous
		_gain_old = _gain_current
		_cue_db_old = _cue_db_current
		_old_music = _current_music
		_music_current.stream = cue.stream
		_cue_db_current = cue.volume_db
		_gain_current = 0.0
		_current_music = id
		_play_player(_music_current)
	_music_ducked = false
	_duck_target_db = 0.0
	if _fade_s() <= 0.0:
		_step_music(0.0)
	_apply_music_volumes()


## The per-frame music step: the current loop's gain rises and the old one's falls by 1 / crossfade per
## second (a cut without a crossfade); the old player stops at silence. The duck moves toward its target.
func _step_music(delta: float) -> void:
	var fade_s: float = _fade_s()
	var step: float = 1.0 if fade_s <= 0.0 else delta / fade_s
	if _current_music != &"":
		_gain_current = minf(1.0, _gain_current + step)
	if _old_music != &"":
		_gain_old = maxf(0.0, _gain_old - step)
		if _gain_old <= 0.0:
			_music_old.stop()
			_old_music = &""
	var duck_range: float = absf(library.music_pause_duck_db) if library != null else 0.0
	_duck_db = move_toward(_duck_db, _duck_target_db, duck_range * delta / DUCK_RAMP_S)
	_apply_music_volumes()


func _fade_s() -> float:
	return library.music_crossfade_s if library != null else 0.0


func _apply_music_volumes() -> void:
	_music_current.volume_db = _cue_db_current + linear_to_db(maxf(_gain_current, MIN_GAIN)) + _duck_db
	_music_old.volume_db = _cue_db_old + linear_to_db(maxf(_gain_old, MIN_GAIN)) + _duck_db


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
