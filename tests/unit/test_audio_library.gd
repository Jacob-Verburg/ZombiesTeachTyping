extends GutTest
## AudioLibrary lookup, and the shipped library instance. Story 5.1: the final MVP list (FR49, FR50), the
## music loops (OGG, looping, 60-120 s), every SFX/voice source file (16-bit PCM mono WAV, peak <= -1 dBFS,
## no leading silence, starting and ending at zero), the mix order (music under every effect but the
## wrong-key tick, the tick the quietest effect), the crossfade and the pause duck. Story 6.6 adds the Horde
## Rush sounds and march to the same lists, so every rule covers them.

const LIBRARY_PATH: String = "res://data/audio/audio_library.tres"


func _cue(id: StringName) -> AudioCue:
	var cue: AudioCue = AudioCue.new()
	cue.id = id
	cue.stream = AudioStreamWAV.new()
	return cue


func test_get_cue_by_id() -> void:
	var library: AudioLibrary = AudioLibrary.new()
	var a: AudioCue = _cue(&"sfx_a")
	var b: AudioCue = _cue(&"mus_b")
	library.cues = [a, b]
	assert_same(library.get_cue(&"sfx_a"), a)
	assert_same(library.get_cue(&"mus_b"), b)


func test_get_cue_unknown_returns_null() -> void:
	var library: AudioLibrary = AudioLibrary.new()
	library.cues = [_cue(&"sfx_a")]
	assert_null(library.get_cue(&"nope"))
	assert_null(AudioLibrary.new().get_cue(&"sfx_a"))


func test_real_library_ids_are_unique() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library)
	if library == null:
		return
	var seen: Dictionary[StringName, bool] = {}
	for cue: AudioCue in library.cues:
		assert_not_null(cue)
		if cue == null:
			continue
		assert_false(seen.has(cue.id), "duplicate id %s" % cue.id)
		seen[cue.id] = true


func test_real_library_wrong_key_tick() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library)
	if library == null:
		return
	var tick: AudioCue = library.get_cue(&"sfx_wrong_key")
	assert_not_null(tick, "sfx_wrong_key cue (Story 2.5)")
	if tick == null:
		return
	assert_not_null(tick.stream)
	assert_eq(tick.min_interval_s, 0.15, "at most one tick per 150 ms (FR2)")
	var click: AudioCue = library.get_cue(&"sfx_ui_click")
	assert_eq(click.min_interval_s, 0.0, "other cues stay unthrottled")


func test_real_library_brainsss_voice() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library)
	if library == null:
		return
	var voice: AudioCue = library.get_cue(&"vo_brainsss")
	assert_not_null(voice, "vo_brainsss cue (Story 3.2)")
	if voice == null:
		return
	assert_not_null(voice.stream)
	assert_eq(voice.min_interval_s, 0.0, "the voice gap is library-wide, not per cue")
	assert_eq(library.voice_min_gap_s, 8.0, "voice lines at least 8 s apart (FR48)")


func test_real_library_purchase_jingle() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library)
	if library == null:
		return
	var jingle: AudioCue = library.get_cue(&"sfx_purchase")
	assert_not_null(jingle, "sfx_purchase cue (Story 4.4)")
	if jingle == null:
		return
	assert_not_null(jingle.stream)
	assert_eq(jingle.min_interval_s, 0.0, "the jingle is not throttled")


func test_voice_gap_default_is_neutral() -> void:
	assert_eq(AudioLibrary.new().voice_min_gap_s, 0.0)


func test_real_library_groans() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library)
	if library == null:
		return
	assert_eq(library.groan_ids.size(), 4, "4 groans (FR50)")
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in library.groan_ids:
		assert_false(seen.has(id), "duplicate groan id %s" % id)
		seen[id] = true
		var cue: AudioCue = library.get_cue(id)
		assert_not_null(cue, "groan cue %s (Story 3.7)" % id)
		if cue == null:
			continue
		assert_not_null(cue.stream, id)
		assert_eq(cue.min_interval_s, 0.0, "ambience spaces the groans, not a per-cue throttle: %s" % id)
	assert_eq(library.groan_min_interval_s, 3.0, "groans every 3-8 s (FR48)")
	assert_eq(library.groan_max_interval_s, 8.0, "groans every 3-8 s (FR48)")
	assert_eq(library.groan_voice_mute_s, 2.0, "no groan within 2 s of a voice line (FR48)")


func test_groan_defaults_are_neutral() -> void:
	var library: AudioLibrary = AudioLibrary.new()
	assert_eq(library.groan_ids.size(), 0)
	assert_eq(library.groan_min_interval_s, 0.0)
	assert_eq(library.groan_max_interval_s, 0.0)
	assert_eq(library.groan_voice_mute_s, 0.0)


# --- the MVP audio list (Story 5.1) -----------------------------------------------------------------------

const SFX_IDS: Array[StringName] = [&"sfx_ui_click", &"sfx_wrong_key", &"sfx_brain_bonk", &"sfx_hug_poof",
		&"sfx_purchase", &"sfx_chalk_scratch", &"sfx_report_chime",
		&"sfx_groan_01", &"sfx_groan_02", &"sfx_groan_03", &"sfx_groan_04",
		&"sfx_zombie_spawn", &"sfx_tomato_throw", &"sfx_tomato_hit", &"sfx_melt",
		&"sfx_unlock_jingle"]
const VOICE_IDS: Array[StringName] = [&"vo_brainsss"]
const MUSIC_IDS: Array[StringName] = [&"mus_menu", &"mus_zombie_run", &"mus_horde_rush"]
## -1 dBFS as a 16-bit sample value.
const PEAK_LIMIT: int = 29204
## "Silence" for the leading-silence check: about -60 dBFS.
const SILENCE: int = 33


func _library() -> AudioLibrary:
	return load(LIBRARY_PATH) as AudioLibrary


## Every stream of a cue: stream plus alt_streams.
func _takes(cue: AudioCue) -> Array[AudioStream]:
	var takes: Array[AudioStream] = [cue.stream]
	takes.append_array(cue.alt_streams)
	return takes


func test_every_mvp_id_has_a_stream() -> void:
	var library: AudioLibrary = _library()
	for id: StringName in SFX_IDS + VOICE_IDS + MUSIC_IDS:
		var cue: AudioCue = library.get_cue(id)
		assert_not_null(cue, String(id))
		if cue != null:
			assert_not_null(cue.stream, String(id))
	assert_eq(library.cues.size(), SFX_IDS.size() + VOICE_IDS.size() + MUSIC_IDS.size(), "nothing else")


func test_brainsss_has_exactly_two_takes() -> void:
	var cue: AudioCue = _library().get_cue(&"vo_brainsss")
	var takes: Array[AudioStream] = _takes(cue)
	assert_eq(takes.size(), 2)
	assert_ne(takes[0], takes[1])
	assert_eq(takes[0].resource_path, "res://assets/audio/voice/vo_brainsss_01.wav")
	assert_eq(takes[1].resource_path, "res://assets/audio/voice/vo_brainsss_02.wav")


func test_music_is_looping_ogg_of_60_to_120_s() -> void:
	for id: StringName in MUSIC_IDS:
		var ogg: AudioStreamOggVorbis = _library().get_cue(id).stream as AudioStreamOggVorbis
		assert_not_null(ogg, "%s is OGG Vorbis" % id)
		if ogg == null:
			continue
		assert_true(ogg.loop, "%s loops" % id)
		assert_eq(ogg.loop_offset, 0.0, String(id))
		assert_between(ogg.get_length(), 60.0, 120.0, "%s length" % id)


func test_effects_are_wavs_that_never_loop() -> void:
	for id: StringName in SFX_IDS + VOICE_IDS:
		for take: AudioStream in _takes(_library().get_cue(id)):
			var wav: AudioStreamWAV = take as AudioStreamWAV
			assert_not_null(wav, "%s is a WAV" % id)
			if wav != null:
				assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, take.resource_path)


## The source file of a WAV take: 16-bit PCM mono, peak <= -1 dBFS, sound within 10 ms, zero at both ends.
func test_effect_source_files_follow_the_spec() -> void:
	for id: StringName in SFX_IDS + VOICE_IDS:
		for take: AudioStream in _takes(_library().get_cue(id)):
			_check_wav_file(take.resource_path)


func _check_wav_file(path: String) -> void:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert_gt(bytes.size(), 44, path)
	if bytes.size() <= 44:
		return
	assert_eq(bytes.slice(0, 4).get_string_from_ascii(), "RIFF", path)
	assert_eq(bytes.slice(8, 12).get_string_from_ascii(), "WAVE", path)
	var at: int = 12
	var format: int = -1
	var channels: int = -1
	var rate: int = -1
	var bits: int = -1
	var data: PackedByteArray = PackedByteArray()
	while at + 8 <= bytes.size():
		var chunk: String = bytes.slice(at, at + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(at + 4)
		if chunk == "fmt ":
			format = bytes.decode_u16(at + 8)
			channels = bytes.decode_u16(at + 10)
			rate = bytes.decode_u32(at + 12)
			bits = bytes.decode_u16(at + 22)
		elif chunk == "data":
			data = bytes.slice(at + 8, at + 8 + size)
		at += 8 + size + (size % 2)
	assert_eq(format, 1, "%s is PCM" % path)
	assert_eq(bits, 16, "%s is 16-bit" % path)
	assert_eq(channels, 1, "%s is mono" % path)
	assert_true(rate == 44100 or rate == 22050, "%s rate %d" % [path, rate])
	var count: int = data.size() >> 1
	assert_gt(count, 0, path)
	if count == 0:
		return
	var peak: int = 0
	var first_sound: int = -1
	for i: int in count:
		var sample: int = absi(data.decode_s16(i * 2))
		peak = maxi(peak, sample)
		if first_sound == -1 and sample > SILENCE:
			first_sound = i
	assert_lte(peak, PEAK_LIMIT, "%s peak <= -1 dBFS" % path)
	assert_gt(peak, SILENCE, "%s is not silent" % path)
	assert_lte(first_sound, roundi(0.01 * rate), "%s: no leading silence over 10 ms" % path)
	assert_eq(data.decode_s16(0), 0, "%s starts at zero" % path)
	assert_eq(data.decode_s16((count - 1) * 2), 0, "%s ends at zero" % path)


func test_music_sits_below_every_effect_but_the_tick() -> void:
	var library: AudioLibrary = _library()
	for music_id: StringName in MUSIC_IDS:
		var music_db: float = library.get_cue(music_id).volume_db
		for id: StringName in SFX_IDS + VOICE_IDS:
			if id == &"sfx_wrong_key":
				continue
			assert_lt(music_db, library.get_cue(id).volume_db, "%s under %s (NFR14)" % [music_id, id])


func test_wrong_key_tick_is_the_quietest_effect() -> void:
	var library: AudioLibrary = _library()
	var tick_db: float = library.get_cue(&"sfx_wrong_key").volume_db
	for id: StringName in SFX_IDS + VOICE_IDS:
		if id != &"sfx_wrong_key":
			assert_lt(tick_db, library.get_cue(id).volume_db, "the tick is quieter than %s" % id)


func test_burst_cues_are_throttled() -> void:
	var library: AudioLibrary = _library()
	for id: StringName in [&"sfx_brain_bonk", &"sfx_hug_poof", &"sfx_zombie_spawn", &"sfx_tomato_throw", &"sfx_tomato_hit",
			&"sfx_melt"]:
		var cue: AudioCue = library.get_cue(id)
		assert_gt(cue.min_interval_s, 0.0, "%s can't stack in a burst" % id)
		assert_lt(cue.min_interval_s, 0.1, "%s still plays once per report row / fast key" % id)


func test_crossfade_and_pause_duck() -> void:
	var library: AudioLibrary = _library()
	assert_eq(library.music_crossfade_s, 0.5, "screen changes crossfade over 0.5 s (EXPERIENCE)")
	assert_lt(library.music_pause_duck_db, 0.0, "a paused run lowers the music")
	assert_gte(library.music_pause_duck_db, -40.0)


func test_crossfade_and_duck_defaults_are_neutral() -> void:
	var library: AudioLibrary = AudioLibrary.new()
	assert_eq(library.music_crossfade_s, 0.0)
	assert_eq(library.music_pause_duck_db, 0.0)
	assert_eq(AudioCue.new().alt_streams.size(), 0)


func test_chalk_scratch_is_never_throttled() -> void:
	# One scratch per report row must survive a frame hitch that shows several rows at once.
	assert_eq(_library().get_cue(&"sfx_chalk_scratch").min_interval_s, 0.0)
