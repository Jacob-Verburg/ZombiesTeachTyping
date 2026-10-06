class_name MenuToggle
extends VBoxContainer
## An on/off toggle (Story 4.2; DESIGN.md / EXPERIENCE.md "toggle"): a 32 x 32 PixelButton with an icon
## and a caption under it. On: the icon in zombie-green-bright. Off: stone-light with a stamp-red diagonal
## slash. The slash, not the colour, carries the state (NFR8). Kind picks the icon (Music: a note, Sound:
## a speaker, Fullscreen: four corner brackets) and the caption.
## A user flip (Enter or a click on the button) emits flipped(new_state) once; show_state() sets the look
## without emitting. The owner decides what a flip does. The focus target is the inner %IconButton, so the
## owner wires focus neighbours to get_focus_target(). The button is not in toggle_mode: Button would draw
## its `pressed` box the whole time a toggle is on, hiding the focused fill; this script keeps the state.
## Placeholder icons drawn as rects until Story 5.0's art.

enum Kind { MUSIC, SOUND, FULLSCREEN }

signal flipped(on: bool)

const CAPTIONS: Dictionary[Kind, String] = {Kind.MUSIC: "Music", Kind.SOUND: "Sound", Kind.FULLSCREEN: "Fullscreen"}
const ON_COLOR: Color = Color("#B8F27C")  # zombie-green-bright
const OFF_COLOR: Color = Color("#BDB6C4")  # stone-light
const SLASH_COLOR: Color = Color("#B02A25")  # stamp-red
## Look value: the off slash's width in px.
const SLASH_PX: float = 2.0

@export var kind: Kind = Kind.MUSIC

var _on: bool = true


func _ready() -> void:
	%Caption.text = CAPTIONS[kind]
	%IconButton.pressed.connect(_on_icon_button_pressed)
	%Icon.draw.connect(_draw_icon)


## Shows `on` without emitting flipped.
func show_state(on: bool) -> void:
	_on = on
	%Icon.queue_redraw()


func is_on() -> bool:
	return _on


## The control that takes focus: the owner wires focus neighbours to it.
func get_focus_target() -> Button:
	return %IconButton


func _on_icon_button_pressed() -> void:
	show_state(not _on)
	flipped.emit(_on)


## Draws the placeholder icon inside the 32 x 32 button.
func _draw_icon() -> void:
	var icon: Control = %Icon
	var color: Color = ON_COLOR if _on else OFF_COLOR
	var rects: Array[Rect2] = []
	match kind:
		Kind.MUSIC:
			rects = [Rect2(17, 8, 2, 14), Rect2(11, 18, 7, 6), Rect2(19, 8, 4, 2), Rect2(21, 10, 2, 3)]
		Kind.SOUND:
			rects = [Rect2(8, 13, 4, 6), Rect2(12, 11, 2, 10), Rect2(14, 9, 2, 14),
					Rect2(19, 12, 2, 8), Rect2(23, 10, 2, 12)]
		Kind.FULLSCREEN:
			rects = [Rect2(8, 8, 6, 2), Rect2(8, 8, 2, 6), Rect2(18, 8, 6, 2), Rect2(22, 8, 2, 6),
					Rect2(8, 22, 6, 2), Rect2(8, 18, 2, 6), Rect2(18, 22, 6, 2), Rect2(22, 18, 2, 6)]
	for rect: Rect2 in rects:
		icon.draw_rect(rect, color)
	if not _on:
		icon.draw_line(Vector2(7, 25), Vector2(25, 7), SLASH_COLOR, SLASH_PX)
