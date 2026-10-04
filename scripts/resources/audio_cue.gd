class_name AudioCue
extends Resource
## One sound in the AudioLibrary: id, stream, playback volume and an optional per-cue throttle.

@export var id: StringName
@export var stream: AudioStream
@export_range(-40.0, 6.0, 0.5) var volume_db: float = 0.0
## The minimum gap between two plays of this cue; 0 = no throttle. AudioManager enforces it, so
## callers never throttle (FR2: the wrong-key tick plays at most once per 150 ms).
@export_range(0.0, 10.0, 0.01) var min_interval_s: float = 0.0
