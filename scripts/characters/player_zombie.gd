class_name PlayerZombie
extends Node2D
## The player's zombie (Story 3.1): idle and walk loops from the approved prototype sheets, drawn at
## 1x with the node origin at the feet centre (soles on sheet row 30, so Body sits at (-16, -31)).
## Zombie Run drives it; Professor Zombie, the menu (4.2) and the Crypt Closet (4.4) reuse the look.
## %HatSlot (head point, top-centre of the crown) stays empty until Story 4.3. Hop, hug and dance
## animations arrive with Stories 3.2 / 3.3 / 3.5.

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"

@onready var _body: AnimatedSprite2D = $Body


func _ready() -> void:
	# NFR16: a missing sprite never stops a run.
	if _body.sprite_frames == null:
		Log.warn(&"level", "player zombie has no sprite frames")
		_body.hide()


func play_idle() -> void:
	_play(ANIM_IDLE)


func play_walk() -> void:
	_play(ANIM_WALK)


## Restarts only when the animation changes, so calling it every frame keeps the loop smooth.
func _play(anim: StringName) -> void:
	if _body.sprite_frames == null:
		return
	if _body.animation != anim or not _body.is_playing():
		_body.play(anim)
