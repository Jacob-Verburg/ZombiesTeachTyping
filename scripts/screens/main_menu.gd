extends Control
## The main menu (Story 4.2, FR24-FR27, FR46): the title logo, the player's zombie (idle), the brain counter
## (the saved wallet), one LevelCard per LevelRegistry.menu_entries() in registry order, the Crypt Closet
## signpost button and the Music / Sound / Fullscreen toggles. Debug-only levels never get a card; the
## debug overlay (F3) jumps to the test level, the gift and the keyboard test instead (Boundary 7).
## Focus: on open, the first Available card. Left/Right move along a row (the ends stop), Down from any
## card goes to the Closet button, Up from the bottom row goes to the first Available card. Hover moves
## focus (LevelCard and PixelButton do it), so one control is highlighted at a time. Esc does nothing: this
## is the root screen. The payload is consumed and ignored (report card and pause quit pass {}).
## Toggles: Music/Sound only call PlayerData.set_setting(); AudioManager follows the setting (Boundary 4).
## Fullscreen calls WebPlatform.toggle_fullscreen() inside the input callback (browser gesture rule) and
## re-reads is_fullscreen() whenever the window size changes (the browser's own Esc exit). Not saved.
## Kept from Stories 1.7 / 1.8: the FR27 storage notice (a non-interactive corner note shown only when
## WebPlatform.is_storage_persistent() is false) and the hidden Ctrl+Shift+E SaveService.offer_export()
## chord in every build, with no visible change.
## Story 4.3: the worn hat rides on the zombie's %HatSlot and the pet stands in %PetSlot beside it; both
## listen to PlayerData themselves, so this script calls nothing for them.
## Later: Locked/New card states and the hint sign (6.8), final art and button feel (5.0), menu music
## crossfades (5.1).
## Seams (tests assign them before add_child): navigate, player_data, toggle_fullscreen, is_fullscreen and
## the exported level_registry.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const LEVEL_CARD_SCENE: PackedScene = preload("res://scenes/ui/level_card.tscn")
const STORAGE_NOTICE_TEXT: String = "Progress may not be saved in this browser mode"

## The levels shown as cards (data/levels/level_registry.tres, set in main_menu.tscn).
@export var level_registry: LevelRegistry

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready.
var navigate: Callable
## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null
## Test seams: default to WebPlatform.toggle_fullscreen / WebPlatform.is_fullscreen in _ready.
var toggle_fullscreen: Callable
var is_fullscreen: Callable
## Test seam: defaults to Router.is_transitioning in _ready.
var is_transitioning: Callable

var _cards: Array[LevelCard] = []
## Set by the one navigation; nothing navigates after it.
var _leaving: bool = false


func _ready() -> void:
	if not navigate.is_valid():
		navigate = Router.go
	if not is_transitioning.is_valid():
		is_transitioning = Router.is_transitioning
	if player_data == null:
		player_data = PlayerData
	if not toggle_fullscreen.is_valid():
		toggle_fullscreen = WebPlatform.toggle_fullscreen
	if not is_fullscreen.is_valid():
		is_fullscreen = WebPlatform.is_fullscreen
	Router.take_payload()
	AudioManager.play_music(&"mus_menu")
	_build_cards()
	player_data.brains_changed.connect(_on_brains_changed)
	player_data.profile_replaced.connect(_show_profile)
	_show_profile()
	%MusicToggle.flipped.connect(_on_music_flipped)
	%SoundToggle.flipped.connect(_on_sound_flipped)
	%FullscreenToggle.flipped.connect(_on_fullscreen_flipped)
	get_tree().root.size_changed.connect(_sync_fullscreen)
	_sync_fullscreen()
	%ClosetButton.pressed.connect(_on_closet_button_pressed)
	_wire_focus()
	var first: LevelCard = _first_available_card()
	if first != null:
		first.grab_focus()
	else:
		%ClosetButton.grab_focus()
	%StorageNoticeLabel.text = STORAGE_NOTICE_TEXT
	_show_storage_notice(WebPlatform.is_storage_persistent())


## Ctrl+Shift+E, pressed, not a repeat, no Alt/Meta.
static func is_export_chord(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.alt_pressed or event.meta_pressed:
		return false
	return event.keycode == KEY_E and event.ctrl_pressed and event.shift_pressed


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		# The root screen: Esc goes nowhere.
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not is_export_chord(key):
		return
	get_viewport().set_input_as_handled()
	SaveService.offer_export()


func get_cards() -> Array[LevelCard]:
	return _cards


func _build_cards() -> void:
	if level_registry == null:
		Log.error(&"ui", "main menu: no level registry")
		return
	var entries: Array[LevelEntry] = level_registry.menu_entries()
	if entries.is_empty():
		Log.error(&"ui", "main menu: no menu levels")
		return
	for source: LevelEntry in entries:
		var entry: LevelEntry = source
		if entry.available and (entry.scene == null or entry.id.is_empty()):
			Log.error(&"ui", "main menu: level '%s' is available but has no scene or id, showing Coming soon" % entry.id)
			entry = entry.duplicate() as LevelEntry
			entry.available = false
		var card: LevelCard = LEVEL_CARD_SCENE.instantiate() as LevelCard
		card.setup(entry)
		card.chosen.connect(_on_card_chosen)
		%Cards.add_child(card)
		_cards.append(card)


func _first_available_card() -> LevelCard:
	for card: LevelCard in _cards:
		if card.get_state() == LevelCard.State.AVAILABLE:
			return card
	return null


## Two rows: the cards, and Closet / Music / Sound / Fullscreen. The row ends stop (no wrap).
func _wire_focus() -> void:
	var bottom: Array[Control] = [
		%ClosetButton, %MusicToggle.get_focus_target(), %SoundToggle.get_focus_target(),
		%FullscreenToggle.get_focus_target(),
	]
	var cards: Array[Control] = []
	cards.assign(_cards)
	_wire_row(cards, bottom[0], true)
	_wire_row(bottom, _first_available_card(), false)
	# Tab walks the cards, then the bottom row, and wraps.
	var order: Array[Control] = cards + bottom
	for i: int in order.size():
		var control: Control = order[i]
		control.focus_next = control.get_path_to(order[(i + 1) % order.size()])
		control.focus_previous = control.get_path_to(order[i - 1])


## Left/right along `row`; an end points at itself, so focus stays. `cross` is the other row's target:
## below the cards (`is_top_row`) or above the bottom row. A null cross keeps focus where it is.
func _wire_row(row: Array[Control], cross: Control, is_top_row: bool) -> void:
	for i: int in row.size():
		var control: Control = row[i]
		var own: NodePath = control.get_path_to(control)
		var cross_path: NodePath = control.get_path_to(cross) if cross != null else own
		control.focus_neighbor_left = control.get_path_to(row[maxi(i - 1, 0)])
		control.focus_neighbor_right = control.get_path_to(row[mini(i + 1, row.size() - 1)])
		control.focus_neighbor_bottom = cross_path if is_top_row else own
		control.focus_neighbor_top = own if is_top_row else cross_path


## Re-reads the wallet and the saved toggles (on open and on profile_replaced: F8 reset, Epic 11 switch).
func _show_profile() -> void:
	%BrainCounter.set_count(player_data.get_brains())
	%MusicToggle.show_state(player_data.get_setting(&"music_on"))
	%SoundToggle.show_state(player_data.get_setting(&"sound_on"))


func _sync_fullscreen() -> void:
	%FullscreenToggle.show_state(is_fullscreen.call())


func _show_storage_notice(persistent: bool) -> void:
	%StorageNotice.visible = not persistent


## The only navigation, at most once per menu. If the Router starts a transition that ends without freeing
## this menu (the target failed to load), the guard is released so the menu is not left dead.
func _leave(screen: Router.Screen, payload: Dictionary) -> void:
	if _leaving or is_transitioning.call():
		return
	_leaving = true
	AudioManager.play_sfx(&"sfx_ui_click")
	navigate.call(screen, payload)
	if not is_transitioning.call():
		return
	while is_transitioning.call():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_leaving = false


func _on_card_chosen(level_id: StringName) -> void:
	_leave(Router.Screen.RUN, {"level_id": level_id})


func _on_closet_button_pressed() -> void:
	_leave(Router.Screen.CRYPT_CLOSET, {})


func _on_brains_changed(total: int, _delta: int) -> void:
	%BrainCounter.set_count(total)


## The click plays after the setting, so turning Sound on clicks audibly.
func _on_music_flipped(on: bool) -> void:
	player_data.set_setting(&"music_on", on)
	AudioManager.play_sfx(&"sfx_ui_click")


func _on_sound_flipped(on: bool) -> void:
	player_data.set_setting(&"sound_on", on)
	AudioManager.play_sfx(&"sfx_ui_click")


## Runs inside the input callback: the browser only allows fullscreen from a user gesture.
func _on_fullscreen_flipped(_on: bool) -> void:
	toggle_fullscreen.call()
	_sync_fullscreen()
	AudioManager.play_sfx(&"sfx_ui_click")
