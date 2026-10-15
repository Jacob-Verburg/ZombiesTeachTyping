extends Control
## The "Name your zombie!" screen (Story 11.1, FR78; sketch name-zombie-11-1.md, approved 2026-10-15). The title
## sends a zombie with no name here; Done saves the name and goes to the main menu. The kid's own zombie (worn
## hat, pet beside it) stands above a chalkboard name field and one pre-focused %DoneButton.
## Typing follows ZombieName: A-Z / a-z add a letter (case as typed, read by unicode so any layout types the
## letter it shows, NFR6), Space adds one space between words, Backspace removes the last character, every
## other key, echo and Ctrl/Alt/Meta combo is ignored without a sound or a mark. Space is taken in _input,
## before the GUI, so it never presses the focused button (ui_accept includes Space). Enter (or a click on
## %DoneButton) with a valid name saves it through PlayerData.set_zombie_name, plays the UI click and navigates
## to the main menu once (_leaving, released if the Router's transition ends without freeing the screen).
## With nothing valid typed, Done saves the default name (GameConstants.ZOMBIE_NAME_DEFAULT) so nobody is stuck
## here; the button wears its "off" look while the field is empty, and the field only wiggles if the save is refused. Esc does nothing: there is nowhere to go back to. The payload is consumed and
## ignored. While open, WebPlatform.capture_keys is on, so the browser never scrolls on Space or navigates on
## Backspace. The name is personal data: nothing here logs it (NFR12).
## Seams (tests assign them before add_child): navigate, player_data, play_sfx, play_music, is_transitioning.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
## Look value, not a GDD number: how long the empty-Done wiggle lasts.
const WIGGLE_S: float = 0.2
## Look value, not a GDD number: how far the field moves sideways in the wiggle.
const WIGGLE_PX: float = 4.0
## Look value: the name's left edge inside the field (8 px chalkboard frame + 4 px padding).
const TEXT_INSET_PX: float = 12.0
## The button's font colours that switch to the theme's disabled colour while the name is empty.
const OFF_FONT_COLORS: Array[StringName] = [
	&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
]
## The button's boxes that switch to the theme's disabled plank while the name is empty (the focus ring stays).
const OFF_STYLES: Array[StringName] = [&"normal_focused", &"hover", &"pressed", &"hover_pressed"]

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready.
var navigate: Callable
## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null
## Test seam: called as play_sfx.call(cue_id). Defaults to AudioManager.play_sfx in _ready.
var play_sfx: Callable
## Test seam: called as play_music.call(music_id). Defaults to AudioManager.play_music in _ready.
var play_music: Callable
## Test seam: defaults to Router.is_transitioning in _ready.
var is_transitioning: Callable

## The name as typed so far (may end in one space).
var _text: String = ""
## Set by the one navigation; nothing is typed or navigates after it.
var _leaving: bool = false
var _wiggle_tween: Tween = null
var _field_rest_x: float = 0.0


func _ready() -> void:
	if not navigate.is_valid():
		navigate = Router.go
	if player_data == null:
		player_data = PlayerData
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	if not play_music.is_valid():
		play_music = AudioManager.play_music
	if not is_transitioning.is_valid():
		is_transitioning = Router.is_transitioning
	Router.take_payload()
	play_music.call(&"mus_menu")
	WebPlatform.capture_keys = true
	_field_rest_x = %NameField.position.x
	%DoneButton.pressed.connect(_submit)
	player_data.profile_replaced.connect(_on_profile_replaced)
	_set_text(player_data.get_zombie_name())
	%DoneButton.grab_focus()


func _exit_tree() -> void:
	WebPlatform.capture_keys = false


## A reset or profile switch replaced the profile: show the new profile's name.
func _on_profile_replaced() -> void:
	_set_text(player_data.get_zombie_name())


## The name typed so far, as shown.
func get_text() -> String:
	return _text


## Space never reaches the focused button: every Space event (press, echo, release) is taken here.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or (event as InputEventKey).keycode != KEY_SPACE:
		return
	get_viewport().set_input_as_handled()
	var key: InputEventKey = event as InputEventKey
	if _is_typing_press(key):
		_set_text(ZombieName.append(_text, " "))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not _is_typing_press(key):
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_submit()
	elif key.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_set_text(ZombieName.backspace(_text))
	elif key.unicode > 0 and key.unicode <= 0x10FFFF and not (key.unicode >= 0xD800 and key.unicode <= 0xDFFF):
		var next: String = ZombieName.append(_text, char(key.unicode))
		if next != _text:
			get_viewport().set_input_as_handled()
			_set_text(next)


## A fresh key press with no Ctrl/Alt/Meta held, while the screen is still taking input.
func _is_typing_press(key: InputEventKey) -> bool:
	return key.pressed and not key.echo and not (key.ctrl_pressed or key.alt_pressed or key.meta_pressed) \
			and not _leaving


func _set_text(value: String) -> void:
	_text = value
	var label: Label = %NameLabel
	label.text = _text
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if not _text.is_empty() else 0.0
	var caret: Control = %Caret
	caret.position.x = TEXT_INSET_PX + width
	caret.visible = _text.length() < GameConstants.ZOMBIE_NAME_MAX_LENGTH
	_set_done_ready(ZombieName.is_valid(ZombieName.clean(_text)))


## Enter or a click on Done: a valid name finishes; with nothing valid typed the default name is saved, so
## nobody is stuck here (Story 11.1 review).
func _submit() -> void:
	if _leaving or is_transitioning.call():
		return
	var cleaned: String = ZombieName.clean(_text)
	_finish(cleaned if ZombieName.is_valid(cleaned) else GameConstants.ZOMBIE_NAME_DEFAULT)


## What Done does with a valid name, in one place (Story 11.2's "New zombie" will branch here).
func _finish(chosen: String) -> void:
	if not player_data.set_zombie_name(chosen):
		_wiggle()
		return
	_leaving = true
	play_sfx.call(&"sfx_ui_click")
	navigate.call(Router.Screen.MAIN_MENU, {})
	if not is_transitioning.call():
		_leaving = false  # the Router never started: don't leave the screen dead
		return
	while is_transitioning.call():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_leaving = false


func _wiggle() -> void:
	if _wiggle_tween != null:
		_wiggle_tween.kill()
	var field: Control = %NameField
	field.position.x = _field_rest_x
	_wiggle_tween = create_tween()
	var step: float = WIGGLE_S / 4.0
	for dx: float in [WIGGLE_PX, -WIGGLE_PX, WIGGLE_PX / 2.0, 0.0]:
		_wiggle_tween.tween_property(field, "position:x", _field_rest_x + dx, step)


## True while the field is wiggling.
func is_wiggling() -> bool:
	return _wiggle_tween != null and _wiggle_tween.is_valid() and _wiggle_tween.is_running()


## The "off" look (theme's disabled plank and text colour) while the name can't be saved; focus is kept.
func _set_done_ready(can_save: bool) -> void:
	var button: Button = %DoneButton
	for style: StringName in OFF_STYLES:
		button.remove_theme_stylebox_override(style)
	for color: StringName in OFF_FONT_COLORS:
		button.remove_theme_color_override(color)
	if not can_save:
		var off_box: StyleBox = button.get_theme_stylebox(&"disabled")
		var off_color: Color = button.get_theme_color(&"font_disabled_color")
		for style: StringName in OFF_STYLES:
			button.add_theme_stylebox_override(style, off_box)
		for color: StringName in OFF_FONT_COLORS:
			button.add_theme_color_override(color, off_color)
	# PixelButton keeps "normal" overridden with normal_focused while focused: refresh it to the new box.
	if button.has_theme_stylebox_override(&"normal"):
		button.add_theme_stylebox_override(&"normal", button.get_theme_stylebox(&"normal_focused"))


## True while Done wears its "off" look.
func is_done_off() -> bool:
	return (%DoneButton as Button).has_theme_color_override(&"font_color")
