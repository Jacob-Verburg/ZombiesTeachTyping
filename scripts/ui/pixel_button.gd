class_name PixelButton
extends Button
## The shared pixel button (Story 4.2; DESIGN.md "pixel button"): the PixelButton theme type variation in
## data/ui_theme.tres (wood fill, ink outline, candy-yellow focus ring outside the outline, square corners)
## plus the two behaviours a theme can't express. Hovering moves keyboard focus here, so only one control is
## ever highlighted. Only real mouse motion moves focus, so a cursor resting where a screen appeared never
## steals it. A focused button shows the pumpkin-light fill whether hovered or not: Button draws its
## `focus` box on top of `normal`, so the fill comes from swapping `normal` to the theme's `normal_focused`
## box while focused. Placeholder chrome; Story 5.0 brings the 9-slice art and the squish, and migrates the
## report card and pause panel buttons.


func _init() -> void:
	theme_type_variation = &"PixelButton"


func _ready() -> void:
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus() and focus_mode != FOCUS_NONE and not disabled and is_visible_in_tree():
		grab_focus()


func _on_focus_changed(focused: bool) -> void:
	if focused:
		add_theme_stylebox_override(&"normal", get_theme_stylebox(&"normal_focused"))
	else:
		remove_theme_stylebox_override(&"normal")
