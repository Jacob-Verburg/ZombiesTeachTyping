extends SceneTree
## Dev-only: writes the placeholder sounds (CC0, replaced in Story 5.1).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_placeholder_audio.gd
## then --import, so the .wav.import files (and the menu loop settings) are applied.

const MIX_RATE: int = 22050
const CLICK_PATH: String = "res://assets/audio/sfx/sfx_ui_click.wav"
const MUSIC_PATH: String = "res://assets/audio/music/mus_menu.wav"
const WRONG_KEY_PATH: String = "res://assets/audio/sfx/sfx_wrong_key.wav"
const VOICE_PATH: String = "res://assets/audio/voice/vo_brainsss_01.wav"
## Ambience groans (Story 3.7), one per _groan_samples() variant.
const GROAN_PATHS: Array[String] = [
	"res://assets/audio/sfx/sfx_groan_01.wav",
	"res://assets/audio/sfx/sfx_groan_02.wav",
	"res://assets/audio/sfx/sfx_groan_03.wav",
	"res://assets/audio/sfx/sfx_groan_04.wav",
]

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
## Quieter than the click: the wrong-key tick is a soft "bonk" (FR2, EXPERIENCE.md Game Feel).
const WRONG_KEY_PEAK: float = 0.35
## A low, goofy "brain-sss" (Story 3.2) until the real voice lines in Story 5.1.
const VOICE_PEAK: float = 0.35
## Fixed seed for the "sss" noise, so re-running the tool rewrites every file byte-for-byte.
const VOICE_NOISE_SEED: int = 3202
## Goofy, not scary (NFR10): low and soft, a bit under the Brainsss line.
const GROAN_PEAK: float = 0.3
## Groan lengths in seconds, one per variant.
const GROAN_SECONDS: Array[float] = [0.8, 0.7, 0.65, 0.85]


func _init() -> void:
	var errors: Array[Error] = [
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/sfx")),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/music")),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio/voice")),
		_save(_click_samples(), CLICK_PATH),
		_save(_music_samples(), MUSIC_PATH),
		_save(_wrong_key_samples(), WRONG_KEY_PATH),
		_save(_voice_samples(), VOICE_PATH),
		_save(_groan_samples(0), GROAN_PATHS[0]),
		_save(_groan_samples(1), GROAN_PATHS[1]),
		_save(_groan_samples(2), GROAN_PATHS[2]),
		_save(_groan_samples(3), GROAN_PATHS[3]),
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


## 70 ms, 220 Hz triangle with a short attack and a fast decay: a low, soft bonk.
func _wrong_key_samples() -> PackedFloat32Array:
	var count: int = int(0.07 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var phase: float = 220.0 * t
		var triangle: float = 4.0 * absf(phase - floorf(phase + 0.5)) - 1.0
		var attack: float = minf(1.0, t / 0.003)
		var envelope: float = attack * exp(-t * 45.0) * (1.0 - float(i) / count)
		samples[i] = triangle * envelope * WRONG_KEY_PEAK
	return samples


## About 0.7 s: a 0.3 s triangle "brain" gliding 200 -> 130 Hz with a small wobble, then 0.4 s of
## soft decaying noise for the "sss". Starts and ends at zero amplitude.
func _voice_samples() -> PackedFloat32Array:
	var glide_count: int = int(0.3 * MIX_RATE)
	var hiss_count: int = int(0.4 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	var phase: float = 0.0
	for i: int in glide_count:
		var t: float = float(i) / MIX_RATE
		var u: float = float(i) / glide_count
		var freq: float = lerpf(200.0, 130.0, u) * (1.0 + 0.04 * sin(TAU * 7.0 * t))
		phase += freq / MIX_RATE
		var triangle: float = 4.0 * absf(phase - floorf(phase + 0.5)) - 1.0
		var attack: float = minf(1.0, t / 0.01)
		var release: float = minf(1.0, float(glide_count - 1 - i) / (0.02 * MIX_RATE))
		samples.append(triangle * attack * release * VOICE_PEAK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = VOICE_NOISE_SEED
	var smoothed: float = 0.0
	for i: int in hiss_count:
		var t: float = float(i) / MIX_RATE
		# Lightly smoothed noise: fades in from zero after the glide, then decays back to zero.
		var noise: float = rng.randf_range(-1.0, 1.0)
		smoothed = lerpf(smoothed, noise, 0.6)
		var envelope: float = exp(-t * 6.0) * (1.0 - float(i) / hiss_count)
		var fade_in: float = minf(1.0, t / 0.02)
		samples.append(smoothed * envelope * fade_in * VOICE_PEAK * 0.6)
	samples[0] = 0.0
	samples[samples.size() - 1] = 0.0
	return samples


## A low triangle groan with a slow wobble; each variant has its own pitch contour:
## 0 "uuuh" falls, 1 "hrrm" stays flat with a fast 9 Hz wobble, 2 "mmh?" rises at the end,
## 3 "braa" rises quickly then falls. No noise, so no RNG. Starts and ends at zero amplitude.
func _groan_samples(variant: int) -> PackedFloat32Array:
	var count: int = int(GROAN_SECONDS[variant] * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var u: float = float(i) / count
		var freq: float = _groan_pitch(variant, u)
		var wobble_hz: float = 9.0 if variant == 1 else 4.0
		var wobble_depth: float = 0.08 if variant == 1 else 0.03
		freq *= 1.0 + wobble_depth * sin(TAU * wobble_hz * t)
		phase += freq / MIX_RATE
		var triangle: float = 4.0 * absf(phase - floorf(phase + 0.5)) - 1.0
		var attack: float = minf(1.0, t / 0.04)
		var release: float = minf(1.0, float(count - 1 - i) / (0.12 * MIX_RATE))
		samples[i] = triangle * attack * release * GROAN_PEAK
	return samples


## The groan's pitch in Hz at u (0..1 through the sound).
func _groan_pitch(variant: int, u: float) -> float:
	match variant:
		0:
			return lerpf(150.0, 90.0, u)
		1:
			return 110.0
		2:
			return 100.0 if u < 0.6 else lerpf(100.0, 150.0, (u - 0.6) / 0.4)
		_:
			return lerpf(100.0, 145.0, u / 0.25) if u < 0.25 else lerpf(145.0, 100.0, (u - 0.25) / 0.75)


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
