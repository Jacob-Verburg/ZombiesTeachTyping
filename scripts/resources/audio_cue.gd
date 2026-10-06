class_name AudioCue
extends Resource
## One sound in the AudioLibrary: id, stream, playback volume and an optional per-cue throttle.
## Alternate takes (Story 5.1): AudioManager plays stream or one of alt_streams at random.

@export var id: StringName
@export var stream: AudioStream
## Extra takes of the same cue (vo_brainsss: 2 takes). AudioManager picks one of [stream] + alt_streams
## at random with its variant_rng; null entries are skipped.
@export var alt_streams: Array[AudioStream] = []
@export_range(-40.0, 6.0, 0.5) var volume_db: float = 0.0
## The minimum gap between two plays of this cue; 0 = no throttle. AudioManager enforces it, so
## callers never throttle (FR2: the wrong-key tick plays at most once per 150 ms).
@export_range(0.0, 10.0, 0.01) var min_interval_s: float = 0.0
