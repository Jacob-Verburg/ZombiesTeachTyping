extends Control
## The pause panel (FR10, GDD M3): "Paused", Resume (pre-focused), Quit to Menu, Music and Sound
## toggles, over the night scrim. Runs only while the tree is paused (PROCESS_MODE_WHEN_PAUSED); it is a
## menu, so its buttons take keyboard focus (Up/Down, Enter/Space, click). Esc on the panel = Resume
## (EXPERIENCE.md [ASSUMPTION]). It touches no autoload: RunFrame applies what it emits (call down,
## signal up). Placeholder look (stone panel, word toggles) until Stories 4.2 / 5.0.

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
	%MusicToggle.toggled.connect(_on_music_toggle_toggled)
	%SoundToggle.toggled.connect(_on_sound_toggle_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_chosen.emit()


## Shows the panel with the saved settings (no toggle signal) and focuses Resume.
func open(music_on: bool, sound_on: bool) -> void:
	%MusicToggle.set_pressed_no_signal(music_on)
	%SoundToggle.set_pressed_no_signal(sound_on)
	_update_toggle_texts()
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


func _update_toggle_texts() -> void:
	%MusicToggle.text = "Music: %s" % ("on" if %MusicToggle.button_pressed else "off")
	%SoundToggle.text = "Sound: %s" % ("on" if %SoundToggle.button_pressed else "off")


func _on_resume_button_pressed() -> void:
	if visible:
		resume_chosen.emit()


func _on_quit_button_pressed() -> void:
	if visible:
		quit_chosen.emit()


func _on_music_toggle_toggled(on: bool) -> void:
	if not visible:
		return
	_update_toggle_texts()
	music_toggled.emit(on)


func _on_sound_toggle_toggled(on: bool) -> void:
	if not visible:
		return
	_update_toggle_texts()
	sound_toggled.emit(on)
