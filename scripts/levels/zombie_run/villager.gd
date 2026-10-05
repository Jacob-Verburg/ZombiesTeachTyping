class_name Villager
extends ZombieRunTarget
## A villager on the Zombie Run path (Story 3.3, FR32/FR34): it stands on the ground line waving, with
## its letter tag above its head. The three non-block slots of every group are villagers.
##
## States, forward only (one _set_state()): WAITING -> HUGGED -> POOFED.
## - resolve() (the letter typed) sets HUGGED in the same call and returns 0: villagers pay no brains.
## - hug_time_s later the villager poofs (POOFED): the sprite hides and a Poof plays.
## - When the poof ends, the party-hat zombie standing in its place is shown and poofed is emitted.
## The sequence runs on the villager's own node-bound tween and is never cut by the zombie: the next key
## may cut the zombie's hug, but every hugged villager still poofs and leaves its party-hat zombie.
## Nothing in the typing path waits on any of it. Villagers draw nothing from any RNG.
##
## poofed(party_zombie) is the seam Story 3.4 uses to add the zombie to the conga line. 3.4 must count
## conga members logically at resolve time (a villager resolved = +1), not on poofed: at high speed a
## villager can scroll off and be freed before its poof ends.
## The node origin is the feet centre on the ground line; the base bob moves %Visual (the waving body,
## tag and arrow); %PartyZombie is a child of the root, so it never bobs. Placeholder hug lean and poof
## until Story 3.6's frames.

signal poofed(party_zombie: PartyZombie)

enum State { WAITING, HUGGED, POOFED }

const POOF_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/poof.tscn")
## Look value: the poof sits about on the body's centre (the sprite spans y -27..0).
const POOF_Y: float = -14.0

var _state: State = State.WAITING
var _hug_time_s: float = 0.0
var _sequence: Tween
var _party_zombie_shown: bool = false


## Called after setup() and before add_child: when the villager poofs after its hug.
func configure(hug_time_s: float) -> void:
	_hug_time_s = hug_time_s


func get_state() -> State:
	return _state


## The hug -> poof sequence tween (null before the hug). For tests.
func get_sequence_tween() -> Tween:
	return _sequence


func get_party_zombie() -> PartyZombie:
	return %PartyZombie as PartyZombie


func is_party_zombie_shown() -> bool:
	return _party_zombie_shown


## Hugged in the same call; the poof follows on the villager's own timer. Never calls the base (no %Box).
func _on_resolved() -> int:
	_set_state(State.HUGGED)
	_sequence = create_tween()
	_sequence.tween_interval(_hug_time_s)
	_sequence.tween_callback(_start_poof)
	return 0


## The only place the state changes: strictly forward, anything else is ignored.
func _set_state(new_state: State) -> void:
	if new_state <= _state:
		assert(false, "Villager state can only move forward")
		return
	_state = new_state


func _start_poof() -> void:
	_set_state(State.POOFED)
	%Body.hide()
	var poof: Poof = POOF_SCENE.instantiate() as Poof
	poof.position = Vector2(0.0, POOF_Y)
	poof.finished.connect(_show_party_zombie)
	add_child(poof)


func _show_party_zombie() -> void:
	_party_zombie_shown = true
	var party_zombie: PartyZombie = get_party_zombie()
	party_zombie.show()
	poofed.emit(party_zombie)
