extends SceneTree
## Dev-only: writes the two placeholder sounds (CC0, replaced in Story 5.1).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_placeholder_audio.gd
## then --import, so the .wav.import files (and the menu loop settings) are applied.

const MIX_RATE: int = 22050
const CLICK_PATH: String = "res://assets/audio/sfx/sfx_ui_click.wav"
const MUSIC_PATH: String = "res://assets/audio/music/mus_menu.wav"

## C, Am, F, G: one 8-note arpeggio per chord (MIDI note numbers).
const ARPEGGIOS: Array[Array] = [
	[60, 64, 67, 72, 76, 72, 67, 64],
	[57, 60, 64, 69, 72, 69, 64, 60],
	[53, 57, 60, 65, 69, 65, 60, 57],
	[55, 59, 62, 67, 71, 67, 62, 59],
]
const NOTE_SECONDS: float = 0.1875 # 160 bpm eighth notes; 4 chords x 8 notes = 6 s
const MUSIC_PEAK: float = 0.25 # about -12 dBFS
const CLICK_PEAK: float = 0.5


func _init() -> void:
	var errors: Array[Error] = [
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/sfx")),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/music")),
		_save(_click_samples(), CLICK_PATH),
		_save(_music_samples(), MUSIC_PATH),
	]
	# Non-zero exit on any failure, so a bad path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


## 40 ms, 1 kHz sine with a fast exponential decay.
func _click_samples() -> PackedFloat32Array:
	var count: int = int(0.04 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var envelope: float = exp(-t * 120.0) * (1.0 - float(i) / count)
		samples[i] = sin(TAU * 1000.0 * t) * envelope * CLICK_PEAK
	return samples


## Soft triangle-wave arpeggios. Every note starts and ends at zero amplitude,
## so the loop point (start = end) has no click.
func _music_samples() -> PackedFloat32Array:
	var note_count: int = int(NOTE_SECONDS * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	for arpeggio: Array in ARPEGGIOS:
		for midi: int in arpeggio:
			var freq: float = 440.0 * pow(2.0, (midi - 69) / 12.0)
			for i: int in note_count:
				var t: float = float(i) / MIX_RATE
				var phase: float = freq * t
				var triangle: float = 4.0 * absf(phase - floorf(phase + 0.5)) - 1.0
				var attack: float = minf(1.0, t / 0.005)
				var release: float = minf(1.0, float(note_count - 1 - i) / (0.01 * MIX_RATE))
				var envelope: float = attack * release * exp(-t * 6.0)
				samples.append(triangle * envelope * MUSIC_PEAK)
	return samples


func _save(samples: PackedFloat32Array, path: String) -> Error:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	var err: Error = wav.save_to_wav(path)
	print("%s -> %s (%d samples)" % [path, error_string(err), samples.size()])
	return err
