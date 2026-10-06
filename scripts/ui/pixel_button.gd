class_name PixelButton
extends Button
## The shared pixel button (Story 4.2; DESIGN.md "pixel button"): the PixelButton theme type variation in
## data/ui_theme.tres (Story 5.0: 9-slice wood plank art with stepped corners and a baked 2 px ink drop, a
## stepped candy-yellow focus ring outside the outline) plus the behaviours a theme can't express.
## Hovering moves keyboard focus here, so only one control is ever highlighted. Only real mouse motion
## moves focus, so a cursor resting where a screen appeared never steals it. A focused button shows the
## pumpkin-light fill whether hovered or not: Button draws its `focus` box on top of `normal`, so the fill
## comes from swapping `normal` to the theme's `normal_focused` box while focused; the swap is dropped when
## the button is disabled or hidden while focused. The squish is art: the `pressed` box is the plank drawn
## 2 px lower with no shadow, and its content margins move the label down with it. On focus the button
## bounces 1 px up and back (EXPERIENCE Game Feel), only when its parent is not a Container (a container
## would reset `position`); the bounce is applied as a relative offset, so it always ends exactly at rest
## even if an owner moves the button meanwhile, and never runs hidden or disabled. get_rest_rect() is the
## button's global rect without the bounce, for aiming a TutorialArrow.

## Look value, not a GDD number: the focus bounce height.
const BOUNCE_PX: float = 1.0
## Look value, not a GDD number: the whole bounce, up and back.
const BOUNCE_S: float = 0.1

var _bounce_tween: Tween = null
var _bounce_applied: float = 0.0


func _init() -> void:
	theme_type_variation = &"PixelButton"


func _ready() -> void:
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	visibility_changed.connect(_refresh_fill)


func _notification(what: int) -> void:
	# `disabled` has no signal; setting it redraws the button, so the redraw is the hook, both ways (deferred:
	# never change theme overrides while drawing). It settles once the override matches the state.
	if what == NOTIFICATION_DRAW and _wants_focused_fill() != has_theme_stylebox_override(&"normal"):
		_refresh_fill.call_deferred()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus() and focus_mode != FOCUS_NONE and not disabled and is_visible_in_tree():
		grab_focus()


## True while the focus bounce runs.
func is_bouncing() -> bool:
	return _bounce_tween != null and _bounce_tween.is_running()


func _on_focus_changed(focused: bool) -> void:
	_refresh_fill()
	if focused:
		_bounce()


## The focused fill shows only while focused, enabled and visible.
func _wants_focused_fill() -> bool:
	return has_focus() and not disabled and is_visible_in_tree()


func _refresh_fill() -> void:
	if _wants_focused_fill():
		add_theme_stylebox_override(&"normal", get_theme_stylebox(&"normal_focused"))
	else:
		remove_theme_stylebox_override(&"normal")


## The button's global rect without the bounce offset.
func get_rest_rect() -> Rect2:
	var rect: Rect2 = get_global_rect()
	rect.position.y -= _bounce_applied
	return rect


func _bounce() -> void:
	if get_parent() is Container or disabled or not is_visible_in_tree():
		return
	if is_bouncing():
		_bounce_tween.kill()
	_apply_bounce(0.0)
	_bounce_tween = create_tween()
	_bounce_tween.tween_method(_apply_bounce, 0.0, -BOUNCE_PX, BOUNCE_S / 2.0)
	_bounce_tween.tween_method(_apply_bounce, -BOUNCE_PX, 0.0, BOUNCE_S / 2.0)


## Moves `position.y` by the change in offset, so anything else that moves the button meanwhile is kept. The
## offset is whole pixels (pixel art, and no float drift in the running sum).
func _apply_bounce(offset: float) -> void:
	offset = roundf(offset)
	position.y += offset - _bounce_applied
	_bounce_applied = offset
