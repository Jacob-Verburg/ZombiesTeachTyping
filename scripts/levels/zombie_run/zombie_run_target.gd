class_name ZombieRunTarget
extends Node2D
## One target on the Zombie Run path (Story 3.1): a placeholder box with its letter on a parchment
## tag. Only the active target bobs and carries the down-arrow (Story 3.6: the down_arrow.png sprite in
## %Arrow, its tip 4 px above the tag; the bob stays code). The node origin is the
## target's feet centre on the ground line; the level owns `position`, the bob moves %Visual only.
## This is the base Story 3.2's brain block and 3.3's villager extend: they override
## _on_resolved() (brains earned + their own resolved look) and keep the rest.
## setup() runs before add_child, so it only stores values; _ready() applies them.

## Bob look (UX values, not GDD numbers): a couple of pixels up and down, a bit under 2 Hz.
const BOB_PX: float = 2.0
const BOB_PERIOD_S: float = 0.6
## Half the widest part (the tag), for the level's off-screen check.
const HALF_WIDTH: float = 12.0
## Placeholder resolved look: stone-light (docs/art-style-sheet.md palette).
const RESOLVED_FILL: Color = Color("#BDB6C4")

var _letter: String = ""
var _slot: int = 0
var _active: bool = false
var _resolved: bool = false
var _bob_t: float = 0.0


## Called before add_child: the letter on the tag and the slot index along the path.
func setup(letter: String, slot: int) -> void:
	_letter = letter
	_slot = slot


func _ready() -> void:
	%Letter.text = _letter
	_apply_active()


func get_letter() -> String:
	return _letter


func get_slot() -> int:
	return _slot


func is_active() -> bool:
	return _active


func is_resolved() -> bool:
	return _resolved


## Shows the arrow and starts the bob (or hides it and settles). A resolved target stays inactive.
func set_active(active: bool) -> void:
	_active = active and not _resolved
	_bob_t = 0.0
	if is_node_ready():
		_apply_active()


## Marks the target resolved (one way), hides the tag and arrow, stops the bob and switches to the
## resolved look. Returns the brains earned; a second call is a no-op returning 0.
func resolve() -> int:
	if _resolved:
		return 0
	_resolved = true
	set_active(false)
	%Tag.hide()
	return _on_resolved()


## Override point for 3.2 / 3.3: switch to the resolved look and return the brains earned.
func _on_resolved() -> int:
	var base: StyleBoxFlat = %Box.get_theme_stylebox(&"panel") as StyleBoxFlat
	if base == null:
		return 0
	var style: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	style.bg_color = RESOLVED_FILL
	%Box.add_theme_stylebox_override(&"panel", style)
	return 0


func _process(delta: float) -> void:
	if not _active:
		return
	_bob_t = fmod(_bob_t + delta, BOB_PERIOD_S)
	%Visual.position.y = -BOB_PX * (0.5 - 0.5 * cos(TAU * _bob_t / BOB_PERIOD_S))


func _apply_active() -> void:
	%Arrow.visible = _active
	%Visual.position.y = 0.0
