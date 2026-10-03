class_name AudioCue
extends Resource
## One sound in the AudioLibrary: id, stream and playback volume.

@export var id: StringName
@export var stream: AudioStream
@export_range(-40.0, 6.0, 0.5) var volume_db: float = 0.0
