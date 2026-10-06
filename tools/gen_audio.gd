extends SceneTree
## Dev-only: writes every MVP sound (Story 5.1, Gate A: all generated, CC0 by authorship).
## Takes over gen_placeholder_audio.gd (Stories 1.4, 2.5, 3.2, 3.7, 4.4).
## Run: "/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_audio.gd -- --music-dir=<dir>
## then --headless --import. SFX and voice go straight to assets/audio as 16-bit mono WAV. The two music
## loops are rendered to WAV under --music-dir (a scratch folder, never committed; default user://gen_audio)
## and encoded to OGG by tools/encode_ogg.py:
##   uv run --with soundfile tools/encode_ogg.py <dir>/mus_menu.wav assets/audio/music/mus_menu.ogg
## Every RNG has a fixed seed, so reruns are byte-identical. Every SFX/voice file is normalized to
## FILE_PEAK, starts at its first sound (no leading silence) and starts and ends at exactly zero.

const MIX_RATE: int = 44100
## About -3 dBFS: the files carry the sound, the library's volume_db does the mixing.
const FILE_PEAK: float = 0.708
## Edge fades, so no file starts or ends with a click.
const EDGE_FADE_S: float = 0.003

const SFX_DIR: String = "res://assets/audio/sfx/"
const VOICE_DIR: String = "res://assets/audio/voice/"

## Formant targets (F1, F2, F3 in Hz) for the vowels and voiced consonants the voices use.
const FORMANTS: Dictionary[StringName, Vector3] = {
	&"a": Vector3(730.0, 1090.0, 2440.0),
	&"uh": Vector3(640.0, 1190.0, 2390.0),
	&"u": Vector3(300.0, 870.0, 2240.0),
	&"o": Vector3(570.0, 840.0, 2410.0),
	&"i": Vector3(300.0, 2200.0, 2950.0),
	&"r": Vector3(420.0, 1300.0, 1600.0),
	&"m": Vector3(250.0, 1100.0, 2300.0),
	&"n": Vector3(250.0, 1700.0, 2600.0),
}


## A second-order (RBJ cookbook) filter. Coefficients can change every sample.
class Biquad:
	extends RefCounted
	var b0: float = 1.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a1: float = 0.0
	var a2: float = 0.0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0

	## Band-pass with a 0 dB peak at freq.
	func set_bandpass(freq: float, q: float, rate: int) -> void:
		var w0: float = TAU * freq / rate
		var alpha: float = sin(w0) / (2.0 * q)
		_set_coeffs(alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * cos(w0), 1.0 - alpha)

	func set_lowpass(freq: float, q: float, rate: int) -> void:
		var w0: float = TAU * freq / rate
		var alpha: float = sin(w0) / (2.0 * q)
		var c: float = cos(w0)
		_set_coeffs((1.0 - c) / 2.0, 1.0 - c, (1.0 - c) / 2.0, 1.0 + alpha, -2.0 * c, 1.0 - alpha)

	func set_highpass(freq: float, q: float, rate: int) -> void:
		var w0: float = TAU * freq / rate
		var alpha: float = sin(w0) / (2.0 * q)
		var c: float = cos(w0)
		_set_coeffs((1.0 + c) / 2.0, -(1.0 + c), (1.0 + c) / 2.0, 1.0 + alpha, -2.0 * c, 1.0 - alpha)

	func process(x: float) -> float:
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y

	func _set_coeffs(nb0: float, nb1: float, nb2: float, na0: float, na1: float, na2: float) -> void:
		b0 = nb0 / na0
		b1 = nb1 / na0
		b2 = nb2 / na0
		a1 = na1 / na0
		a2 = na2 / na0


func _init() -> void:
	var music_dir: String = "user://gen_audio"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--music-dir="):
			music_dir = arg.trim_prefix("--music-dir=")
	var errors: Array[Error] = [
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SFX_DIR)),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VOICE_DIR)),
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(music_dir)),
		_save_sfx(_click(), SFX_DIR + "sfx_ui_click.wav"),
		_save_sfx(_wrong_key(), SFX_DIR + "sfx_wrong_key.wav"),
		_save_sfx(_brain_bonk(), SFX_DIR + "sfx_brain_bonk.wav"),
		_save_sfx(_hug_poof(), SFX_DIR + "sfx_hug_poof.wav"),
		_save_sfx(_purchase(), SFX_DIR + "sfx_purchase.wav"),
		_save_sfx(_chalk_scratch(), SFX_DIR + "sfx_chalk_scratch.wav"),
		_save_sfx(_report_chime(), SFX_DIR + "sfx_report_chime.wav"),
		_save_sfx(_groan(0), SFX_DIR + "sfx_groan_01.wav"),
		_save_sfx(_groan(1), SFX_DIR + "sfx_groan_02.wav"),
		_save_sfx(_groan(2), SFX_DIR + "sfx_groan_03.wav"),
		_save_sfx(_groan(3), SFX_DIR + "sfx_groan_04.wav"),
		_save_sfx(_brainsss(0), VOICE_DIR + "vo_brainsss_01.wav"),
		_save_sfx(_brainsss(1), VOICE_DIR + "vo_brainsss_02.wav"),
		_save_music(_menu_music(), music_dir.path_join("mus_menu.wav")),
		_save_music(_zombie_run_music(), music_dir.path_join("mus_zombie_run.wav")),
	]
	# Non-zero exit on any failure, so a bad path or cwd doesn't look like success.
	quit(0 if errors.all(func(err: Error) -> bool: return err == OK) else 1)


# --- Sound effects -------------------------------------------------------------------------------


## About 35 ms: a soft wooden "tock", a sine falling 1400 -> 900 Hz with a fast decay.
func _click() -> PackedFloat32Array:
	var count: int = _n(0.035)
	var out: PackedFloat32Array = _zeros(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = _t(i)
		phase += lerpf(900.0, 1400.0, exp(-t * 120.0)) / MIX_RATE
		out[i] = sin(TAU * phase) * exp(-t * 110.0)
	return out


## About 60 ms: the quiet wrong-key tick, a low triangle falling 300 -> 220 Hz (FR2: soft, not a buzzer).
func _wrong_key() -> PackedFloat32Array:
	var count: int = _n(0.06)
	var out: PackedFloat32Array = _zeros(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = _t(i)
		phase += lerpf(220.0, 300.0, exp(-t * 80.0)) / MIX_RATE
		out[i] = _tri(phase) * exp(-t * 55.0)
	return out


## About 220 ms: a cartoony "bonk", a sine dropping 560 -> 210 Hz with a little octave and a woody
## noise knock on top.
func _brain_bonk() -> PackedFloat32Array:
	var count: int = _n(0.22)
	var out: PackedFloat32Array = _zeros(count)
	var rng: RandomNumberGenerator = _rng(5101)
	var knock: Biquad = Biquad.new()
	knock.set_bandpass(1800.0, 2.0, MIX_RATE)
	var phase: float = 0.0
	for i: int in count:
		var t: float = _t(i)
		phase += lerpf(210.0, 560.0, exp(-t * 28.0)) / MIX_RATE
		var body: float = (sin(TAU * phase) + 0.25 * sin(TAU * 2.0 * phase)) * exp(-t * 16.0)
		var noise: float = knock.process(rng.randf_range(-1.0, 1.0)) * exp(-t * 160.0) * 1.5
		out[i] = body + noise
	return out


## About 340 ms: a "poof" puff of smoke, noise through a low-pass that closes from 3 kHz to 300 Hz,
## with a small "pop" at the start.
func _hug_poof() -> PackedFloat32Array:
	var count: int = _n(0.34)
	var out: PackedFloat32Array = _zeros(count)
	var rng: RandomNumberGenerator = _rng(5102)
	var filter: Biquad = Biquad.new()
	var phase: float = 0.0
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		filter.set_lowpass(lerpf(3000.0, 300.0, sqrt(u)), 0.9, MIX_RATE)
		var puff: float = filter.process(rng.randf_range(-1.0, 1.0)) * minf(1.0, t / 0.012) * pow(1.0 - u, 2.0)
		phase += lerpf(260.0, 700.0, exp(-t * 60.0)) / MIX_RATE
		var pop: float = sin(TAU * phase) * exp(-t * 50.0) * 0.6
		out[i] = puff * 2.2 + pop
	return out


## About 0.85 s: a happy "ta-da", bell-ish notes C5 E5 G5 rising, then C6 ringing over a soft C-major chord.
func _purchase() -> PackedFloat32Array:
	var out: PackedFloat32Array = _zeros(_n(0.85))
	var steps: Array[int] = [72, 76, 79]
	for k: int in steps.size():
		_mix(out, _n(0.075 * k), _bell(_midi(steps[k]), 0.3, 14.0))
	var start: int = _n(0.225)
	_mix(out, start, _bell(_midi(84), 0.62, 5.0))
	for midi: int in [60, 64, 67]:
		_mix(out, start, _scaled(_bell(_midi(midi), 0.62, 6.0), 0.35))
	return out


## About 80 ms (report rows appear 0.1 s apart): a chalk "skritch", high band-passed noise chopped by a
## stick-slip flutter.
func _chalk_scratch() -> PackedFloat32Array:
	var count: int = _n(0.08)
	var out: PackedFloat32Array = _zeros(count)
	var rng: RandomNumberGenerator = _rng(5103)
	var band: Biquad = Biquad.new()
	band.set_bandpass(4200.0, 1.6, MIX_RATE)
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		var flutter: float = 0.55 + 0.45 * sin(TAU * 85.0 * t)
		var envelope: float = minf(1.0, t / 0.006) * (1.0 - u)
		out[i] = band.process(rng.randf_range(-1.0, 1.0)) * flutter * envelope
	return out


## About 0.9 s: a two-note "ding-ding" (G5 then C6), bell partials, after the last report row.
func _report_chime() -> PackedFloat32Array:
	var out: PackedFloat32Array = _zeros(_n(0.9))
	_mix(out, 0, _scaled(_bell(_midi(79), 0.75, 5.5), 0.8))
	_mix(out, _n(0.13), _bell(_midi(84), 0.77, 4.5))
	return out


## A bell-ish tone: fundamental plus quickly fading inharmonic partials, a 2 ms attack.
func _bell(freq: float, seconds: float, decay: float) -> PackedFloat32Array:
	var count: int = _n(seconds)
	var out: PackedFloat32Array = _zeros(count)
	for i: int in count:
		var t: float = _t(i)
		var tone: float = sin(TAU * freq * t) * exp(-t * decay)
		tone += 0.35 * sin(TAU * freq * 2.0 * t) * exp(-t * decay * 2.0)
		tone += 0.15 * sin(TAU * freq * 3.01 * t) * exp(-t * decay * 4.0)
		out[i] = tone * minf(1.0, t / 0.002)
	return out


# --- Voices (formant synthesis) ------------------------------------------------------------------


## Goofy groans (Story 3.7 contours, NFR10: silly, not scary), 0.6–1.0 s each:
## 0 "uuuh" falls, 1 "hrrm" rolls its r with a fast wobble, 2 "mmh?" rises like a question,
## 3 "braa" jumps up then falls.
func _groan(variant: int) -> PackedFloat32Array:
	match variant:
		0:
			return _voice(0.85, 5201, [0.0, 150.0, 0.6, 115.0, 1.0, 90.0], 4.0, 0.04,
					[[0.0, &"u", 1.0], [0.35, &"uh", 1.0], [1.0, &"uh", 1.0]], 0.0)
		1:
			return _voice(0.75, 5202, [0.0, 112.0, 1.0, 106.0], 9.0, 0.08,
					[[0.0, &"uh", 1.0], [0.25, &"r", 1.0], [0.6, &"r", 0.9], [0.75, &"m", 0.7], [1.0, &"m", 0.7]],
					26.0)
		2:
			return _voice(0.7, 5203, [0.0, 100.0, 0.55, 100.0, 1.0, 155.0], 4.0, 0.03,
					[[0.0, &"m", 0.7], [0.3, &"m", 0.7], [0.45, &"uh", 1.0], [1.0, &"uh", 1.0]], 0.0)
		_:
			return _voice(0.9, 5204, [0.0, 100.0, 0.22, 148.0, 1.0, 98.0], 4.5, 0.04,
					[[0.0, &"m", 0.5], [0.06, &"r", 0.9], [0.2, &"a", 1.0], [1.0, &"a", 1.0]], 0.0)


## "Braaainsss": take 0 is drawn out and low, take 1 quick, higher and happy.
func _brainsss(take: int) -> PackedFloat32Array:
	if take == 0:
		var voiced: PackedFloat32Array = _voice(0.95, 5301, [0.0, 165.0, 0.5, 150.0, 1.0, 125.0], 5.0, 0.05,
				[[0.0, &"m", 0.5], [0.05, &"r", 0.9], [0.14, &"a", 1.0], [0.62, &"a", 1.0], [0.76, &"i", 0.9],
				[0.86, &"n", 0.6], [1.0, &"n", 0.5]], 0.0)
		return _append_hiss(voiced, 0.45, 5311)
	var quick: PackedFloat32Array = _voice(0.5, 5302, [0.0, 210.0, 0.6, 255.0, 1.0, 240.0], 6.0, 0.04,
			[[0.0, &"m", 0.5], [0.07, &"r", 0.9], [0.18, &"a", 1.0], [0.6, &"a", 1.0], [0.75, &"i", 0.9],
			[0.88, &"n", 0.6], [1.0, &"n", 0.5]], 0.0)
	return _append_hiss(quick, 0.28, 5312)


## A voiced sound: a band-limited saw at the pitch contour (pairs of u, Hz) with vibrato, plus a little
## breath, through three formant band-passes that glide between keyframes [u, vowel, gain].
## roll_hz > 0 adds a rolled-r tremolo while the vowel is "r".
func _voice(seconds: float, seed_value: int, pitch: Array, vibrato_hz: float, vibrato_depth: float,
		keys: Array, roll_hz: float) -> PackedFloat32Array:
	var count: int = _n(seconds)
	var out: PackedFloat32Array = _zeros(count)
	var rng: RandomNumberGenerator = _rng(seed_value)
	var filters: Array[Biquad] = [Biquad.new(), Biquad.new(), Biquad.new()]
	var gains: Array[float] = [1.0, 0.55, 0.3]
	var phase: float = 0.0
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		var freq: float = _contour(pitch, u) * (1.0 + vibrato_depth * sin(TAU * vibrato_hz * t))
		var dt: float = freq / MIX_RATE
		phase = fposmod(phase + dt, 1.0)
		var source: float = 2.0 * phase - 1.0 - _poly_blep(phase, dt) + rng.randf_range(-0.15, 0.15)
		var key: Array = _key_at(keys, u)
		var formant: Vector3 = key[0]
		var gain: float = key[1]
		var sample: float = 0.0
		for f: int in 3:
			filters[f].set_bandpass(formant[f], 6.0, MIX_RATE)
			sample += filters[f].process(source) * gains[f]
		if roll_hz > 0.0 and key[2]:
			sample *= 0.6 + 0.4 * sin(TAU * roll_hz * t)
		var envelope: float = minf(1.0, t / 0.03) * minf(1.0, float(count - 1 - i) / (0.1 * MIX_RATE))
		out[i] = sample * gain * envelope
	return out


## The "sss": high band-passed noise that fades in over the voice's end and then dies away.
func _append_hiss(voiced: PackedFloat32Array, seconds: float, seed_value: int) -> PackedFloat32Array:
	var voiced_peak: float = _peak(voiced)
	var overlap: int = _n(0.06)
	var count: int = _n(seconds)
	var out: PackedFloat32Array = voiced.duplicate()
	out.resize(voiced.size() - overlap + count)
	var rng: RandomNumberGenerator = _rng(seed_value)
	var high: Biquad = Biquad.new()
	high.set_highpass(4000.0, 0.7, MIX_RATE)
	var band: Biquad = Biquad.new()
	band.set_bandpass(6500.0, 1.2, MIX_RATE)
	var start: int = voiced.size() - overlap
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		var hiss: float = band.process(high.process(rng.randf_range(-1.0, 1.0)))
		var envelope: float = minf(1.0, t / 0.05) * pow(1.0 - u, 1.5)
		out[start + i] += hiss * envelope * voiced_peak * 1.6
	return out


## The pitch at u from a flat list [u0, hz0, u1, hz1, ...], linear between points.
func _contour(points: Array, u: float) -> float:
	for k: int in range(2, points.size(), 2):
		if u <= points[k]:
			var u0: float = points[k - 2]
			var span: float = maxf(points[k] - u0, 0.0001)
			return lerpf(points[k - 1], points[k + 1], (u - u0) / span)
	return points[points.size() - 1]


## [formants, gain, is_r] at u from keyframes [u, vowel, gain], gliding linearly between them.
func _key_at(keys: Array, u: float) -> Array:
	for k: int in range(1, keys.size()):
		var next: Array = keys[k]
		if u <= next[0]:
			var prev: Array = keys[k - 1]
			var w: float = (u - prev[0]) / maxf(next[0] - prev[0], 0.0001)
			var formant: Vector3 = FORMANTS[prev[1]].lerp(FORMANTS[next[1]], w)
			return [formant, lerpf(prev[2], next[2], w), prev[1] == &"r" or next[1] == &"r"]
	var last: Array = keys[keys.size() - 1]
	return [FORMANTS[last[1]], last[2], last[1] == &"r"]


## PolyBLEP correction for a saw step at the wrap point (keeps the voice source from aliasing).
func _poly_blep(phase: float, dt: float) -> float:
	if phase < dt:
		var x: float = phase / dt
		return x + x - x * x - 1.0
	if phase > 1.0 - dt:
		var x: float = (phase - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


# --- Music ---------------------------------------------------------------------------------------


## The menu loop (title, menu, Closet, gift, report card): light and bouncy, C major, 120 bpm,
## 48 bars = 96 s. Oom-pah bass and ukulele plucks, a marimba tune, soft kick and hats.
func _menu_music() -> PackedFloat32Array:
	var section_a: Array[String] = ["C", "G", "Am", "F", "C", "G", "F", "G"]
	var section_b: Array[String] = ["F", "G", "Em", "Am", "F", "G", "C", "C"]
	var tune_a: Array = _make_tune(5401, section_a, [72, 74, 76, 79, 81, 84], false)
	var tune_b: Array = _make_tune(5402, section_b, [72, 74, 76, 79, 81, 84], false)
	var form: Array[int] = [0, 0, 1, 0, 1, 0]
	return _render_song(120.0, form, [section_a, section_b], [tune_a, tune_b], false)


## The Zombie Run loop: calm (GDD), A minor, 100 bpm, 40 bars = 96 s. A tiptoeing pizzicato bass,
## one soft chord per bar, a sparse marimba tune, hats only.
func _zombie_run_music() -> PackedFloat32Array:
	var section_a: Array[String] = ["Am", "F", "C", "G", "Am", "F", "Dm", "E"]
	var section_b: Array[String] = ["F", "G", "C", "Am", "F", "G", "E", "E"]
	var tune_a: Array = _make_tune(5501, section_a, [69, 72, 74, 76, 79, 81], true)
	var tune_b: Array = _make_tune(5502, section_b, [69, 72, 74, 76, 79, 81], true)
	var form: Array[int] = [0, 0, 1, 0, 1]
	return _render_song(100.0, form, [section_a, section_b], [tune_a, tune_b], true)


## MIDI notes of a chord name (root position, around middle C).
func _chord(chord_name: String) -> Array[int]:
	match chord_name:
		"C":
			return [60, 64, 67]
		"Dm":
			return [62, 65, 69]
		"Em":
			return [64, 67, 71]
		"E":
			return [64, 68, 71]
		"F":
			return [65, 69, 72]
		"G":
			return [67, 71, 74]
		_:
			return [69, 72, 76] # Am


## An 8-bar tune: per bar a list of [eighth, midi, length in eighths]. Strong eighths (0 and 4) snap to a
## chord tone; the rest step through the scale. The last bar holds the chord root.
func _make_tune(seed_value: int, chords: Array[String], scale: Array, calm: bool) -> Array:
	var rng: RandomNumberGenerator = _rng(seed_value)
	var rhythms: Array = [[0, 4], [0, 3, 6], [0, 2, 4], [0, 4, 6]] if calm else \
			[[0, 2, 4, 6], [0, 3, 4, 6, 7], [0, 2, 3, 4], [0, 4, 6], [0, 1, 2, 4, 6]]
	var tune: Array = []
	var index: int = 2
	for bar: int in chords.size():
		var notes: Array = []
		var tones: Array[int] = _chord(chords[bar])
		if bar == chords.size() - 1:
			notes.append([0, tones[0] + 12, 6])
			tune.append(notes)
			continue
		var rhythm: Array = rhythms[rng.randi_range(0, rhythms.size() - 1)]
		for k: int in rhythm.size():
			var eighth: int = rhythm[k]
			var next_eighth: int = rhythm[k + 1] if k + 1 < rhythm.size() else 8
			index = clampi(index + rng.randi_range(-1, 1) * (1 + rng.randi_range(0, 1)), 0, scale.size() - 1)
			var midi: int = scale[index]
			if eighth % 4 == 0:
				midi = _nearest_chord_tone(midi, tones)
				index = _nearest_index(scale, midi)
			notes.append([eighth, midi, mini(next_eighth - eighth, 3)])
		tune.append(notes)
	return tune


func _nearest_chord_tone(midi: int, tones: Array[int]) -> int:
	var best: int = midi
	var best_distance: int = 99
	for tone: int in tones:
		for octave: int in [0, 12, 24]:
			var distance: int = absi(tone + octave - midi)
			if distance < best_distance:
				best_distance = distance
				best = tone + octave
	return best


func _nearest_index(scale: Array, midi: int) -> int:
	var best: int = 0
	for k: int in scale.size():
		if absi(scale[k] - midi) < absi(scale[best] - midi):
			best = k
	return best


## Renders the form into one buffer. Notes that ring past the end wrap to the start, so the loop point
## is seamless. calm switches to the Zombie Run arrangement.
func _render_song(bpm: float, form: Array[int], sections: Array, tunes: Array, calm: bool) -> PackedFloat32Array:
	var eighth_s: float = 30.0 / bpm
	var bar_s: float = eighth_s * 8.0
	var bars: int = form.size() * 8
	var total: int = _n(bar_s * bars)
	var out: PackedFloat32Array = _zeros(total)
	var rng: RandomNumberGenerator = _rng(5601 if calm else 5600)
	var bar_index: int = 0
	for section: int in form:
		var chords: Array[String] = sections[section]
		var tune: Array = tunes[section]
		for bar: int in 8:
			var bar_start: float = bar_index * bar_s
			var tones: Array[int] = _chord(chords[bar])
			var root: int = tones[0] - 24
			# Bass: oom-pah (menu) or a tiptoeing walk (run).
			if calm:
				var walk: Array[int] = [root, root + 7, root + 12, root + 7]
				for beat: int in 4:
					_mix_wrapped(out, _n(bar_start + beat * 2 * eighth_s), _scaled(_pizz(_midi(walk[beat]), 0.22), 0.55))
			else:
				_mix_wrapped(out, _n(bar_start), _scaled(_bass(_midi(root), 0.35), 0.8))
				_mix_wrapped(out, _n(bar_start + 4 * eighth_s), _scaled(_bass(_midi(root + 7), 0.35), 0.7))
			# Chords: ukulele plucks on beats 2 and 4 (menu) or one soft strum per bar (run).
			var strums: Array[int] = [0]
			if not calm:
				strums = [2, 6]
			for eighth: int in strums:
				for k: int in tones.size():
					var start: int = _n(bar_start + eighth * eighth_s + k * 0.012)
					_mix_wrapped(out, start, _scaled(_pluck(_midi(tones[k]), 1.2 if calm else 0.5, rng), 0.16 if calm else 0.22))
			# Drums.
			for eighth: int in 8:
				var at: int = _n(bar_start + eighth * eighth_s)
				if eighth == 0 or (eighth == 4 and not calm):
					_mix_wrapped(out, at, _scaled(_kick(), 0.45 if calm else 0.6))
				if eighth % 2 == 1:
					_mix_wrapped(out, at, _scaled(_hat(rng), 0.06 if calm else 0.08))
				if not calm and (eighth == 2 or eighth == 6):
					_mix_wrapped(out, at, _scaled(_shaker(rng), 0.1))
			# Tune.
			for note: Array in tune[bar]:
				var length_s: float = note[2] * eighth_s
				_mix_wrapped(out, _n(bar_start + note[0] * eighth_s),
						_scaled(_marimba(_midi(note[1]), length_s + 0.25), 0.42 if calm else 0.5))
			bar_index += 1
	return out


## A marimba-ish note: fundamental plus a quickly fading 4th partial.
func _marimba(freq: float, seconds: float) -> PackedFloat32Array:
	var count: int = _n(seconds)
	var out: PackedFloat32Array = _zeros(count)
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		var tone: float = sin(TAU * freq * t) * exp(-t * 5.0) + 0.25 * sin(TAU * freq * 3.9 * t) * exp(-t * 30.0)
		out[i] = tone * minf(1.0, t / 0.003) * minf(1.0, (1.0 - u) * 8.0)
	return out


## A Karplus-Strong plucked string (ukulele-ish).
func _pluck(freq: float, seconds: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count: int = _n(seconds)
	var out: PackedFloat32Array = _zeros(count)
	var period: int = maxi(2, roundi(MIX_RATE / freq))
	var line: PackedFloat32Array = _zeros(period)
	var smooth: float = 0.0
	for k: int in period:
		smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.5)
		line[k] = smooth
	var pos: int = 0
	for i: int in count:
		var u: float = float(i) / count
		var current: float = line[pos]
		var next: float = line[(pos + 1) % period]
		line[pos] = (current + next) * 0.5 * 0.996
		pos = (pos + 1) % period
		out[i] = current * minf(1.0, (1.0 - u) * 10.0)
	return out


## A round triangle bass note with a short release.
func _bass(freq: float, seconds: float) -> PackedFloat32Array:
	var count: int = _n(seconds)
	var out: PackedFloat32Array = _zeros(count)
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		out[i] = _tri(freq * t) * minf(1.0, t / 0.005) * minf(1.0, (1.0 - u) * 6.0)
	return out


## A short pizzicato bass note: sine plus a little 2nd harmonic, fast decay.
func _pizz(freq: float, seconds: float) -> PackedFloat32Array:
	var count: int = _n(seconds)
	var out: PackedFloat32Array = _zeros(count)
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		var tone: float = sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)
		out[i] = tone * exp(-t * 9.0) * minf(1.0, t / 0.004) * minf(1.0, (1.0 - u) * 8.0)
	return out


## A soft kick: sine sweeping 110 -> 45 Hz.
func _kick() -> PackedFloat32Array:
	var count: int = _n(0.16)
	var out: PackedFloat32Array = _zeros(count)
	var phase: float = 0.0
	for i: int in count:
		var t: float = _t(i)
		var u: float = float(i) / count
		phase += lerpf(45.0, 110.0, exp(-t * 30.0)) / MIX_RATE
		out[i] = sin(TAU * phase) * exp(-t * 18.0) * minf(1.0, t / 0.002) * (1.0 - u)
	return out


## A closed hi-hat tick: high-passed noise, 35 ms.
func _hat(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count: int = _n(0.035)
	var out: PackedFloat32Array = _zeros(count)
	var high: Biquad = Biquad.new()
	high.set_highpass(7000.0, 0.7, MIX_RATE)
	for i: int in count:
		var t: float = _t(i)
		out[i] = high.process(rng.randf_range(-1.0, 1.0)) * exp(-t * 90.0) * (1.0 - float(i) / count)
	return out


## A soft shaker on the backbeat: band-passed noise, 90 ms.
func _shaker(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count: int = _n(0.09)
	var out: PackedFloat32Array = _zeros(count)
	var band: Biquad = Biquad.new()
	band.set_bandpass(3500.0, 1.0, MIX_RATE)
	for i: int in count:
		var t: float = _t(i)
		out[i] = band.process(rng.randf_range(-1.0, 1.0)) * minf(1.0, t / 0.01) * exp(-t * 35.0) * (1.0 - float(i) / count)
	return out


# --- Helpers -------------------------------------------------------------------------------------


func _n(seconds: float) -> int:
	return roundi(seconds * MIX_RATE)


func _t(i: int) -> float:
	return float(i) / MIX_RATE


func _zeros(count: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	out.fill(0.0)
	return out


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


## A triangle wave in -1..1 for a phase in cycles.
func _tri(phase: float) -> float:
	return 4.0 * absf(phase - floorf(phase + 0.5)) - 1.0


func _peak(samples: PackedFloat32Array) -> float:
	var peak: float = 0.0
	for s: float in samples:
		peak = maxf(peak, absf(s))
	return peak


func _scaled(samples: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = samples.duplicate()
	for i: int in out.size():
		out[i] *= gain
	return out


## Adds src into dst from start; anything past dst's end is dropped (one-shots are sized to fit).
func _mix(dst: PackedFloat32Array, start: int, src: PackedFloat32Array) -> void:
	for i: int in src.size():
		var at: int = start + i
		if at >= dst.size():
			return
		dst[at] += src[i]


## Adds src into dst from start, wrapping past the end to the start (seamless music loops).
func _mix_wrapped(dst: PackedFloat32Array, start: int, src: PackedFloat32Array) -> void:
	var size: int = dst.size()
	for i: int in src.size():
		dst[(start + i) % size] += src[i]


## Normalizes to FILE_PEAK, fades the edges and pins the first and last samples to zero.
func _finish(samples: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = _scaled(samples, FILE_PEAK / maxf(_peak(samples), 0.000001))
	var fade: int = _n(EDGE_FADE_S)
	for i: int in mini(fade, out.size()):
		var w: float = float(i) / fade
		out[i] *= w
		out[out.size() - 1 - i] *= w
	return out


func _save_sfx(samples: PackedFloat32Array, path: String) -> Error:
	return _save(_finish(samples), path)


## Music loops are normalized but not edge-faded: the wrapped render already makes end -> start continuous.
func _save_music(samples: PackedFloat32Array, path: String) -> Error:
	return _save(_scaled(samples, FILE_PEAK / maxf(_peak(samples), 0.000001)), path)


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
	print("%s -> %s (%.2f s)" % [path, error_string(err), float(samples.size()) / MIX_RATE])
	return err
