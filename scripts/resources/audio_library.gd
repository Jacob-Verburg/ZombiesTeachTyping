class_name AudioLibrary
extends Resource
## Sound id -> AudioCue table that AudioManager plays from. Ids: sfx_*, mus_*, vo_*.

@export var cues: Array[AudioCue] = []
## Minimum gap between two voice lines (any vo_* id); AudioManager enforces it. FR48: 8 s.
@export_range(0.0, 30.0, 0.5) var voice_min_gap_s: float = 0.0
## Groan cues AudioManager's ambience (Story 3.7) picks from at random, never one twice in a row. FR50: 4.
@export var groan_ids: Array[StringName] = []
## Shortest gap between two groans while ambience is on. FR48: 3 s.
@export_range(0.0, 30.0, 0.5) var groan_min_interval_s: float = 0.0
## Longest gap between two groans while ambience is on. FR48: 8 s.
@export_range(0.0, 30.0, 0.5) var groan_max_interval_s: float = 0.0
## A groan that comes due this soon after a voice line is skipped (not delayed). FR48: 2 s.
@export_range(0.0, 10.0, 0.5) var groan_voice_mute_s: float = 0.0


## Returns the cue with this id, or null if there is none. A linear scan: the library stays small,
## and a cache would go stale when cues change in the inspector.
func get_cue(id: StringName) -> AudioCue:
	for cue: AudioCue in cues:
		if cue != null and cue.id == id:
			return cue
	return null
