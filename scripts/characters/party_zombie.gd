class_name PartyZombie
extends Node2D
## A party-hat zombie (Story 3.3, FR34): what a hugged villager turns into after its poof. The villager
## recoloured zombie-green with a party hat baked into the sheet (style sheet section 6), drawn at 1x
## with the node origin at the feet centre (soles on sheet row 30, so Body sits at (-16, -31)).
## Idle only for now: it stands where the villager was and scrolls off with the world. Story 3.4 makes
## it walk in the conga line; Story 3.6 adds the walk frames.

const ANIM_IDLE: StringName = &"idle"

@onready var _body: AnimatedSprite2D = $Body


func _ready() -> void:
	# NFR16: a missing sprite never stops a run.
	if _body.sprite_frames == null:
		Log.warn(&"level", "party zombie has no sprite frames")
		_body.hide()


func play_idle() -> void:
	if _body.sprite_frames == null:
		return
	if _body.animation != ANIM_IDLE or not _body.is_playing():
		_body.play(ANIM_IDLE)
