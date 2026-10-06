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
## Story 5.0: the icon is a 20 x 20 frame of the kind's 2-frame sheet (ui_icon_<kind>.png: frame 0 on, frame 1
## off with the slash), centred in the button.

enum Kind { MUSIC, SOUND, FULLSCREEN }

signal flipped(on: bool)

const CAPTIONS: Dictionary[Kind, String] = {Kind.MUSIC: "Music", Kind.SOUND: "Sound", Kind.FULLSCREEN: "Fullscreen"}
const ICON_SHEETS: Dictionary[Kind, Texture2D] = {
	Kind.MUSIC: preload("res://assets/sprites/ui/common/ui_icon_music.png"),
	Kind.SOUND: preload("res://assets/sprites/ui/common/ui_icon_sound.png"),
	Kind.FULLSCREEN: preload("res://assets/sprites/ui/common/ui_icon_fullscreen.png"),
}
const ICON_PX: int = 20

@export var kind: Kind = Kind.MUSIC

var _on: bool = true


func _ready() -> void:
	%Caption.text = CAPTIONS[kind]
	%IconButton.pressed.connect(_on_icon_button_pressed)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = ICON_SHEETS.get(kind)
	%Icon.texture = atlas
	_show_icon()


## Shows `on` without emitting flipped.
func show_state(on: bool) -> void:
	_on = on
	if is_node_ready():
		_show_icon()


func is_on() -> bool:
	return _on


## The control that takes focus: the owner wires focus neighbours to it.
func get_focus_target() -> Button:
	return %IconButton


func _on_icon_button_pressed() -> void:
	show_state(not _on)
	flipped.emit(_on)


## Frame 0 (on) or 1 (off) of the kind's icon sheet.
func _show_icon() -> void:
	var atlas: AtlasTexture = %Icon.texture as AtlasTexture
	if atlas != null:
		atlas.region = Rect2(0 if _on else ICON_PX, 0, ICON_PX, ICON_PX)
