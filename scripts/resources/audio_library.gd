class_name AudioLibrary
extends Resource
## Sound id -> AudioCue table that AudioManager plays from. Ids: sfx_*, mus_*, vo_*.

@export var cues: Array[AudioCue] = []
## Minimum gap between two voice lines (any vo_* id); AudioManager enforces it. FR48: 8 s.
@export_range(0.0, 30.0, 0.5) var voice_min_gap_s: float = 0.0


## Returns the cue with this id, or null if there is none. A linear scan: the library stays small,
## and a cache would go stale when cues change in the inspector.
func get_cue(id: StringName) -> AudioCue:
	for cue: AudioCue in cues:
		if cue != null and cue.id == id:
			return cue
	return null
