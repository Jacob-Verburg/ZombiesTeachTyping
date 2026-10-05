class_name PartyZombie
extends Node2D
## A party-hat zombie (Story 3.3, FR34): what a hugged villager turns into after its poof. The villager
## recoloured zombie-green with a party hat baked into the sheet (style sheet section 6), drawn at 1x
## with the node origin at the feet centre (soles on sheet row 30, so Body sits at (-16, -31)).
## In the villager it stands where the villager was; Story 3.4's CongaLine instances its own copies that
## follow the player zombie. Animations: idle (2f) and, from Story 3.6, walk (4f, the villager's legs in
## four poses), which the conga line plays while a follower is moving. face_left() mirrors it in place
## (Body spans x -16..16 around the origin).

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"

@onready var _body: AnimatedSprite2D = $Body


func _ready() -> void:
	# NFR16: a missing sprite never stops a run.
	if _body.sprite_frames == null:
		Log.warn(&"level", "party zombie has no sprite frames")
		_body.hide()


func play_idle() -> void:
	_play(ANIM_IDLE)


func play_walk() -> void:
	_play(ANIM_WALK)


## Restarts only when the animation changes, so calling it every frame keeps the loop smooth.
func _play(anim: StringName) -> void:
	if _body.sprite_frames == null or not _body.sprite_frames.has_animation(anim):
		return
	if _body.animation != anim or not _body.is_playing():
		_body.play(anim)


## Mirrors the sprite in place: Body is centered = false at x -16 on a 32 px sheet, so flip_h keeps the
## feet point.
func face_left(left: bool) -> void:
	if _body.sprite_frames == null:
		return
	_body.flip_h = left
