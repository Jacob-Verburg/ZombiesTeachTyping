extends Control
## The pause panel (FR10, GDD M3): "Paused", Resume (pre-focused), Quit to Menu, Music and Sound
## toggles, over the night scrim. Runs only while the tree is paused (PROCESS_MODE_WHEN_PAUSED); it is a
## menu, so its buttons take keyboard focus (Up/Down, Enter/Space, click). Esc on the panel = Resume
## (EXPERIENCE.md [ASSUMPTION]). It touches no autoload: RunFrame applies what it emits (call down,
## signal up). Story 5.0 look: a stone panel with a parchment "Paused" sign, PixelButtons, and Music / Sound
## MenuToggles (icon plus caption; the slash carries the off state). Focus: Up / Down move between Resume, Quit
## and the toggle row (wrapping), Left / Right between the two toggles.

## Resume was chosen (button, Enter on it, or Esc on the panel).
signal resume_chosen
## Quit to Menu was chosen.
signal quit_chosen
## The Music toggle changed; `on` is the new state.
signal music_toggled(on: bool)
## The Sound toggle changed; `on` is the new state.
signal sound_toggled(on: bool)


func _ready() -> void:
	%ResumeButton.pressed.connect(_on_resume_button_pressed)
	%QuitButton.pressed.connect(_on_quit_button_pressed)
	%MusicToggle.flipped.connect(_on_music_toggle_toggled)
	%SoundToggle.flipped.connect(_on_sound_toggle_toggled)
	_wire_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_chosen.emit()


## Shows the panel with the saved settings (no toggle signal) and focuses Resume.
func open(music_on: bool, sound_on: bool) -> void:
	(%MusicToggle as MenuToggle).show_state(music_on)
	(%SoundToggle as MenuToggle).show_state(sound_on)
	visible = true
	%ResumeButton.grab_focus()


## Hides the panel and drops keyboard focus if a panel button held it, so Space/Enter typed in the run
## can never press one.
func close() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		get_viewport().gui_release_focus()
	visible = false


## True while the panel is shown.
func is_open() -> bool:
	return visible


## Resume <-> Quit <-> the toggle row, wrapping; Left / Right between the toggles (their inner buttons).
func _wire_focus() -> void:
	var resume: Button = %ResumeButton
	var quit_button: Button = %QuitButton
	var music: Button = (%MusicToggle as MenuToggle).get_focus_target()
	var sound: Button = (%SoundToggle as MenuToggle).get_focus_target()
	_link(resume, music, quit_button, resume, resume)
	_link(quit_button, resume, music, quit_button, quit_button)
	_link(music, quit_button, resume, sound, sound)
	_link(sound, quit_button, resume, music, music)


func _link(button: Button, up: Control, down: Control, left: Control, right: Control) -> void:
	button.focus_neighbor_top = button.get_path_to(up)
	button.focus_neighbor_bottom = button.get_path_to(down)
	button.focus_neighbor_left = button.get_path_to(left)
	button.focus_neighbor_right = button.get_path_to(right)


func _on_resume_button_pressed() -> void:
	if visible:
		resume_chosen.emit()


func _on_quit_button_pressed() -> void:
	if visible:
		quit_chosen.emit()


func _on_music_toggle_toggled(on: bool) -> void:
	if visible:
		music_toggled.emit(on)


func _on_sound_toggle_toggled(on: bool) -> void:
	if visible:
		sound_toggled.emit(on)
