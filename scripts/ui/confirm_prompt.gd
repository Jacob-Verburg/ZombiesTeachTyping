class_name ConfirmPrompt
extends Control
## A modal yes/no question (Story 4.4; DESIGN.md / EXPERIENCE.md "confirm-prompt", approved sketch
## sketches/crypt-closet-4-4.md): the night scrim at 60 % over the whole screen (the one sanctioned alpha
## in the UI; it stops every click), a wood panel, a parchment sign with the question at 24 px, and Yes /
## No pixel buttons. open() focuses Yes (EXPERIENCE: default focus on Yes), and focus stays on the pair:
## every neighbour and Tab point inside it. The owner switches its own controls to FOCUS_NONE while it is
## open, so nothing behind the scrim can be focused by code either.
## Yes / No emit answered(yes) once, then close. The prompt never handles Esc itself: the owning screen
## routes Esc to cancel() (= No), so Esc has one owner. Yes / No ignore presses for answer_delay_ms after
## open(), so a double-tap on the Buy tile cannot answer Yes by accident. Hidden until open(). Story 5.0 art: a WoodPanel and a parchment Sign over the night scrim.

signal answered(yes: bool)

## Look value, not a GDD number: how long Yes / No ignore presses after open().
@export var answer_delay_ms: int = 300

var _open: bool = false
var _opened_at_ms: int = 0


func _ready() -> void:
	visible = false
	%YesButton.pressed.connect(_press.bind(true))
	%NoButton.pressed.connect(_press.bind(false))
	_trap_focus()


## Shows `question` and focuses Yes.
func open(question: String) -> void:
	%QuestionLabel.text = question
	_open = true
	_opened_at_ms = Time.get_ticks_msec()
	visible = true
	%YesButton.grab_focus()


func close() -> void:
	_open = false
	visible = false


func get_yes_button() -> Button:
	return %YesButton


func is_open() -> bool:
	return _open


## The same as No (Esc, routed by the owner).
func cancel() -> void:
	_answer(false)


## A button press; too soon after open() it is ignored.
func _press(yes: bool) -> void:
	if Time.get_ticks_msec() - _opened_at_ms < answer_delay_ms:
		return
	_answer(yes)


func _answer(yes: bool) -> void:
	if not _open:
		return
	close()
	answered.emit(yes)


## Yes and No point only at each other, so arrows and Tab never leave the prompt.
func _trap_focus() -> void:
	var yes: Button = %YesButton
	var no: Button = %NoButton
	for pair: Array[Button] in [[yes, no] as Array[Button], [no, yes] as Array[Button]]:
		var own: NodePath = pair[0].get_path_to(pair[0])
		var other: NodePath = pair[0].get_path_to(pair[1])
		pair[0].focus_neighbor_top = own
		pair[0].focus_neighbor_bottom = own
		pair[0].focus_next = other
		pair[0].focus_previous = other
	yes.focus_neighbor_left = yes.get_path_to(yes)
	yes.focus_neighbor_right = yes.get_path_to(no)
	no.focus_neighbor_left = no.get_path_to(yes)
	no.focus_neighbor_right = no.get_path_to(no)
