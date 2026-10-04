class_name ProfessorZombie
extends Node2D
## Professor Zombie (Story 2.9): the player zombie in a cap and gown, pointing at the report card's
## chalkboard. Drawn at 1x sprite scale, soles on the node's local row 30.
## %HatSlot (at the head point, top-centre of the crown) and %PetSlot (on the floor to his right) are
## empty here: Story 4.3 puts the worn hat and pet in them and lifts the mortarboard onto the hat.


func _ready() -> void:
	var body: AnimatedSprite2D = $Body
	if body.sprite_frames == null:
		Log.warn(&"ui", "professor zombie has no sprite frames")
		body.hide()
