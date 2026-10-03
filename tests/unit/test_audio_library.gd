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
