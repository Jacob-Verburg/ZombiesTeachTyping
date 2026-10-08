class_name PlayerZombie
extends Node2D
## The player's zombie (Story 3.1): idle and walk loops from the approved prototype sheets, drawn at
## 1x with the node origin at the feet centre (soles on sheet row 30, so Body sits at (-16, -31)).
## Zombie Run drives it; Professor Zombie, the menu (4.2) and the Crypt Closet (4.4) reuse the look.
## %HatSlot follows SpriteAnchors per frame (Story 4.3): it listens to Body's frame and animation changes
## and to PlayerData by itself, so nothing here drives it.
## Hop (Story 3.2): a sine arc that lifts Body (and the hat slot with it), never the node itself; the
## level owns the node's position and the camera reads its x. One hop tween at a time: a new hop or
## stop_hop() kills the running one. Story 3.6: hop() plays the hop frames (drawn grounded; the tween
## does the lift).
## Hug (Story 3.3): Body leans forward and back on x for the hug time after a villager's letter. One hug
## tween at a time: a new hug or stop_hug() kills the running one. The hop owns Body.position.y and the
## hug owns Body.position.x, so neither ever kills or resets the other. Story 3.6: hug() plays the hug
## frames; a hug started during a hop shows the hop frames until the hop ends, then the hug frames.
## Dance (Story 3.5, FR36): one dance tween bounces Body on y for the dance time, then puts Body back at
## rest. It owns Body.position.y and cuts the hop and the hug first, so nothing fights it. With the
## Story 3.6 dance frames the sheet carries the sway; without a dance animation (a stripped SpriteFrames)
## it plays idle and flips Body (flip_h) on every beat instead.
## One animation owner at a time (Story 3.6): while a hop, hug or dance runs, play_idle() and play_walk()
## do nothing (the level calls play_walk() every frame). The one-shots are not looping and hold their
## last frame; the first play_*() after the tween ends takes over again. stop_hop() and stop_hug() never
## change the animation.
## Flash (Story 6.6, Horde Rush hits): set_flashing(true) makes the walk show the flash frames (the walk
## recoloured, the same silhouette), swapped at the same frame index and progress so the march never
## stutters; set_flashing(false) swaps back. play_idle() and the one-shots are unaffected. A no-op without
## a flash animation (a stripped SpriteFrames).
## Melt (Story 6.6, a Horde Rush copy's final hit): melt() cuts the hop, hug, dance and flash and steps the
## melt frames with a node-bound tween across the given time, holding the last (a small puddle). Once
## melting, the copy stays melted: every play_*() does nothing. Returns null without a melt animation.

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_DANCE: StringName = &"dance"
const ANIM_HOP: StringName = &"hop"
const ANIM_HUG: StringName = &"hug"
const ANIM_FLASH: StringName = &"flash"
const ANIM_MELT: StringName = &"melt"
## Character sprite size (art standard, NFR13); the level derives the hop height from it.
const SIZE_PX: float = 32.0
## Hug lean (look value, not a GDD number): how far Body leans forward at the middle of the hug.
const HUG_LEAN_PX: float = 3.0
## Dance look values, not GDD numbers: the bounce height, and bounces per second (Body flips its facing
## on every beat).
const DANCE_HOP_PX: float = 4.0
const DANCE_BEAT_HZ: float = 2.0

var _body_rest_x: float = 0.0
var _body_rest_y: float = 0.0
var _hop_height_px: float = 0.0
var _hop_tween: Tween
var _hug_tween: Tween
var _dance_tween: Tween
## True while a dance without dance frames flips Body on the beat.
var _dance_flips: bool = false
## True while a hit flash shows (the walk plays the flash frames).
var _flashing: bool = false
## Set by melt(), never cleared: a melted copy does not get up again.
var _melting: bool = false
var _melt_tween: Tween

@onready var _body: AnimatedSprite2D = $Body


func _ready() -> void:
	_body_rest_x = _body.position.x
	_body_rest_y = _body.position.y
	# NFR16: a missing sprite never stops a run.
	if _body.sprite_frames == null:
		Log.warn(&"level", "player zombie has no sprite frames")
		_body.hide()


func play_idle() -> void:
	_play(ANIM_IDLE)


## The walk, or its flash frames while flashing.
func play_walk() -> void:
	_play(ANIM_FLASH if _flashing else ANIM_WALK)


## Turns the hit flash on or off. While the walk (or the flash) is showing it swaps at once, keeping the
## frame; otherwise the next play_walk() picks it up. A no-op without a flash animation.
func set_flashing(on: bool) -> void:
	if on == _flashing or not _has_animation(ANIM_FLASH):
		return
	_flashing = on
	if _body.animation == ANIM_WALK or _body.animation == ANIM_FLASH:
		play_walk()


func is_flashing() -> bool:
	return _flashing


## Melts over `duration_s`: cuts the hop, the hug, the dance and the flash, shows the melt's first frame
## and returns the node-bound tween that steps frame i at i * duration_s / frames and holds the last.
## The caller may append to the tween (the level frees the copy at its end). Null without a melt
## animation, and the copy is left as it was.
func melt(duration_s: float) -> Tween:
	if not _has_animation(ANIM_MELT):
		return null
	stop_hop()
	stop_hug()
	_kill_dance()
	_reset_dance()
	_flashing = false
	_melting = true
	if _melt_tween != null and _melt_tween.is_valid():
		_melt_tween.kill()
	_body.stop()
	_body.animation = ANIM_MELT
	_body.frame = 0
	_melt_tween = create_tween()
	_melt_tween.tween_method(_set_melt_t, 0.0, float(_body.sprite_frames.get_frame_count(ANIM_MELT)),
			maxf(duration_s, 0.0))
	return _melt_tween


func is_melting() -> bool:
	return _melting


## The current melt tween (null before melt()). For tests.
func get_melt_tween() -> Tween:
	return _melt_tween


## `t` counts frames; the last frame is held.
func _set_melt_t(t: float) -> void:
	var frame: int = mini(floori(t), _body.sprite_frames.get_frame_count(ANIM_MELT) - 1)
	if _body.animation == ANIM_MELT and _body.frame != frame:
		_body.frame = frame


## Starts a hop of `height_px` over `duration_s`, cutting any running hop. Fire-and-forget: the tween is
## node-bound, so it pauses with the tree.
func hop(duration_s: float, height_px: float) -> void:
	_kill_hop()
	_body.position.y = _body_rest_y
	_hop_height_px = height_px
	_hop_tween = create_tween()
	_hop_tween.tween_method(_set_hop_t, 0.0, 1.0, duration_s)
	_hop_tween.tween_callback(_end_hop)
	if not is_dancing():
		_play_action(ANIM_HOP)


## Cuts a running hop and puts Body back at rest; a hug still running gets its frames, as when the hop
## ends by itself. No-op when not hopping.
func stop_hop() -> void:
	if not is_hopping():
		return
	_kill_hop()
	_end_hop()


func is_hopping() -> bool:
	return _hop_tween != null and _hop_tween.is_valid() and _hop_tween.is_running()


## The current hop tween (null before the first hop; may be finished or killed). For tests.
func get_hop_tween() -> Tween:
	return _hop_tween


func _set_hop_t(t: float) -> void:
	_body.position.y = _body_rest_y - _hop_height_px * sin(PI * t)


func _reset_hop() -> void:
	_body.position.y = _body_rest_y


## The hop tween's end: back at rest, and a hug still running gets its frames.
func _end_hop() -> void:
	_reset_hop()
	if is_hugging() and not is_dancing():
		_play_action(ANIM_HUG)


func _kill_hop() -> void:
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()


## Starts a hug lasting `duration_s`, cutting any running hug. Fire-and-forget and node-bound like the hop;
## touches only Body.position.x. A restart picks up from the current lean on the rising edge, so rapid
## hugs do not snap Body back to rest.
func hug(duration_s: float) -> void:
	_kill_hug()
	var lean: float = clampf((_body.position.x - _body_rest_x) / HUG_LEAN_PX, 0.0, 1.0)
	var t0: float = asin(lean) / PI
	_hug_tween = create_tween()
	_hug_tween.tween_method(_set_hug_t, t0, 1.0, duration_s * (1.0 - t0))
	_hug_tween.tween_callback(_reset_hug)
	if not is_hopping() and not is_dancing():
		_play_action(ANIM_HUG)


## Cuts a running hug and puts Body back at its rest x. No-op when not hugging.
func stop_hug() -> void:
	if not is_hugging():
		return
	_kill_hug()
	_reset_hug()


func is_hugging() -> bool:
	return _hug_tween != null and _hug_tween.is_valid() and _hug_tween.is_running()


## The current hug tween (null before the first hug; may be finished or killed). For tests.
func get_hug_tween() -> Tween:
	return _hug_tween


func _set_hug_t(t: float) -> void:
	_body.position.x = _body_rest_x + HUG_LEAN_PX * sin(PI * t)


func _reset_hug() -> void:
	_body.position.x = _body_rest_x


func _kill_hug() -> void:
	if _hug_tween != null and _hug_tween.is_valid():
		_hug_tween.kill()


## Dances in place for `duration_s`, cutting the hop, the hug and any running dance. Fire-and-forget and
## node-bound like the hop.
func dance(duration_s: float) -> void:
	stop_hop()
	stop_hug()
	_kill_dance()
	_reset_dance()
	_dance_flips = not _has_animation(ANIM_DANCE)
	if _dance_flips:
		_play(ANIM_IDLE)
	else:
		_play_action(ANIM_DANCE)
	_dance_tween = create_tween()
	_dance_tween.tween_method(_set_dance_s, 0.0, duration_s, duration_s)
	_dance_tween.tween_callback(_end_dance)


func is_dancing() -> bool:
	return _dance_tween != null and _dance_tween.is_valid() and _dance_tween.is_running()


## The current dance tween (null before the first dance; may be finished or killed). For tests.
func get_dance_tween() -> Tween:
	return _dance_tween


## `s` is the elapsed dance time in seconds, so the beat stays in Hz whatever the dance length.
func _set_dance_s(s: float) -> void:
	_body.position.y = _body_rest_y - roundf(DANCE_HOP_PX * absf(sin(PI * DANCE_BEAT_HZ * s)))
	if _dance_flips:
		_body.flip_h = int(floorf(DANCE_BEAT_HZ * s)) % 2 == 1


func _reset_dance() -> void:
	_body.position.y = _body_rest_y
	_body.flip_h = false


## The dance tween's end: back at rest, and the dance loop gives way to idle (the guard in `_play` would
## still see the finishing tween as running here, so it plays directly).
func _end_dance() -> void:
	_reset_dance()
	if _has_animation(ANIM_IDLE) and _body.animation == ANIM_DANCE:
		_body.play(ANIM_IDLE)


func _kill_dance() -> void:
	if _dance_tween != null and _dance_tween.is_valid():
		_dance_tween.kill()


## Restarts only when the animation changes, so calling it every frame keeps the loop smooth. Does
## nothing while a hop, hug or dance owns the animation, or once melting. Walk <-> flash keeps the frame
## and its progress, so the legs never jump.
func _play(anim: StringName) -> void:
	if _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	if _melting or is_hopping() or is_hugging() or is_dancing():
		return
	if _body.animation != anim or not _body.is_playing():
		var swap: bool = _is_walk_pair(_body.animation) and _is_walk_pair(anim)
		var frame: int = _body.frame
		var progress: float = _body.frame_progress
		_body.play(anim)
		if swap:
			_body.set_frame_and_progress(frame, progress)


func _is_walk_pair(anim: StringName) -> bool:
	return anim == ANIM_WALK or anim == ANIM_FLASH


## Starts a one-shot (or the dance) from its first frame, if the SpriteFrames has it.
func _play_action(anim: StringName) -> void:
	if _melting or not _has_animation(anim):
		return
	_body.stop()
	_body.play(anim)


func _has_animation(anim: StringName) -> bool:
	return _body.sprite_frames != null and _body.sprite_frames.has_animation(anim)
