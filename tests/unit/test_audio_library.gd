extends GutTest
## AudioLibrary lookup, and the shipped library instance (placeholder cues until Story 5.1).

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


func test_real_library_has_placeholders() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library, "not an AudioLibrary: %s" % LIBRARY_PATH)
	if library == null:
		return
	var click: AudioCue = library.get_cue(&"sfx_ui_click")
	var music: AudioCue = library.get_cue(&"mus_menu")
	assert_not_null(click)
	assert_not_null(music)
	if click == null or music == null:
		return
	assert_not_null(click.stream)
	assert_not_null(music.stream)
	assert_lt(music.volume_db, click.volume_db, "music sits below SFX (NFR14)")


func test_real_library_menu_music_loops() -> void:
	var library: AudioLibrary = load(LIBRARY_PATH) as AudioLibrary
	assert_not_null(library)
	if library == null:
		return
	var music: AudioCue = library.get_cue(&"mus_menu")
	assert_not_null(music)
	if music == null:
		return
	var wav: AudioStreamWAV = music.stream as AudioStreamWAV
	assert_not_null(wav, "mus_menu is a WAV placeholder until 5.1")
	if wav != null:
		assert_ne(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED)


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
