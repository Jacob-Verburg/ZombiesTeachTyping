extends Control
## The main menu (Story 4.2, FR24-FR27, FR46): the title logo, the player's zombie (idle), the brain counter
## (the saved wallet), one LevelCard per LevelRegistry.menu_entries() in registry order, the Crypt Closet
## signpost button and the Music / Sound / Fullscreen toggles. Debug-only levels never get a card; the
## debug overlay (F3) jumps to the test level, the gift and the keyboard test instead (Boundary 7).
## Focus: on open, the first choosable (Available or New) card. Left/Right move along a row (the ends stop),
## Down from any card goes to the Closet button, Up from the bottom row goes to the first choosable card. Hover moves
## focus (LevelCard and PixelButton do it), so one control is highlighted at a time. Esc does nothing: this
## is the root screen. The payload is consumed and ignored (report card and pause quit pass {}).
## Toggles: Music/Sound only call PlayerData.set_setting(); AudioManager follows the setting (Boundary 4).
## Fullscreen calls WebPlatform.toggle_fullscreen() inside the input callback (browser gesture rule) and
## re-reads is_fullscreen() every frame (the late switch, the browser's own Esc exit; Story 5.5). Not saved.
## Kept from Stories 1.7 / 1.8: the FR27 storage notice (a non-interactive corner note shown only when
## WebPlatform.is_storage_persistent() is false) and the hidden Ctrl+Shift+E SaveService.offer_export()
## chord in every build, with no visible change.
## Story 4.3: the worn hat rides on the zombie's %HatSlot and the pet stands in %PetSlot beside it; both
## listen to PlayerData themselves, so this script calls nothing for them.
## Level unlocks (Story 6.8, FR79): each card's state comes from LevelCard.state_for(entry,
## PlayerData.get_unlock_state(id)) (Coming soon > Locked > New > Available). A Locked card's hint reads
## "Finish <its unlocked_by level's display_name> to open!". When the menu opens with an available level
## unlocked but its moment unseen, that card is built Locked, PlayerData.mark_unlock_seen() saves it at once
## and the card plays its unlock moment (several play together; focus goes to the first in registry order
## when they end). Input stays live: an arrow, Enter, Esc or a left click finishes every moment at once
## (focus to the new card) and is then handled normally. A Coming soon level's pending moment waits (not
## played, not marked). Choosing a New card calls PlayerData.mark_level_chosen() before leaving, so its badge
## is gone next time. Card states are re-read (no moment) on profile_replaced and unlocks_changed.
## Story 5.2 (Gate A): the storage notice reads "This browser might forget your brains" (plain words, NFR9).
## Seams (tests assign them before add_child): navigate, player_data, toggle_fullscreen, is_fullscreen and
## the exported level_registry.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const LEVEL_CARD_SCENE: PackedScene = preload("res://scenes/ui/level_card.tscn")
const STORAGE_NOTICE_TEXT: String = "This browser might forget your brains"
## After a Fullscreen press, how long the icon keeps the asked-for state while the window has not switched
## yet (the browser applies the mode later). Past this, the real mode shows again (a refused request).
const FULLSCREEN_SETTLE_FRAMES: int = 60

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
## The entry each card was built from (same index as _cards; a broken available entry is its Coming soon copy).
var _entries: Array[LevelEntry] = []
## Cards whose unlock moment started when the menu opened, in registry order.
var _moment_cards: Array[LevelCard] = []
## Set by the one navigation; nothing navigates after it.
var _leaving: bool = false
## The control that held focus when the menu opened; a moment's end only pulls focus if it is still there.
var _initial_focus: Control = null
## Frames left in which a Fullscreen press waits for the window to switch, and the mode it switches from.
var _fullscreen_settle: int = 0
var _fullscreen_before: bool = false


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
	get_tree().root.size_changed.connect(_on_window_resized)
	_sync_fullscreen()
	%ClosetButton.pressed.connect(_on_closet_button_pressed)
	_wire_focus()
	var first: LevelCard = _first_choosable_card()
	if first != null:
		first.grab_focus()
		_initial_focus = first
	else:
		%ClosetButton.grab_focus()
		_initial_focus = %ClosetButton
	%StorageNoticeLabel.text = STORAGE_NOTICE_TEXT
	_show_storage_notice(WebPlatform.is_storage_persistent())
	_start_unlock_moments()
	# After the moments start: their mark_unlock_seen() must not re-read the cards mid-moment.
	player_data.unlocks_changed.connect(_on_unlocks_changed)
	player_data.profile_replaced.connect(_refresh_unlocks)


## Ctrl+Shift+E, pressed, not a repeat, no Alt/Meta.
static func is_export_chord(event: InputEventKey) -> bool:
	if not event.pressed or event.echo:
		return false
	if event.alt_pressed or event.meta_pressed:
		return false
	return event.keycode == KEY_E and event.ctrl_pressed and event.shift_pressed


## While an unlock moment plays, an arrow, Enter, Esc or a left click press finishes it first; the event is
## not consumed, so it then does what it always does (on the new card, which now has focus).
func _input(event: InputEvent) -> void:
	if not is_playing_unlock_moment() or not finishes_unlock_moment(event):
		return
	_finish_unlock_moments()


## Pressed (not echo) ui_left / ui_right / ui_up / ui_down / ui_accept / ui_cancel, or a left mouse press.
static func finishes_unlock_moment(event: InputEvent) -> bool:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null:
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept", &"ui_cancel"]:
		if event.is_action_pressed(action):
			return true
	return false


func is_playing_unlock_moment() -> bool:
	for card: LevelCard in _moment_cards:
		if card.is_playing_moment():
			return true
	return false


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
		var unlock: Dictionary = player_data.get_unlock_state(entry.id)
		var card: LevelCard = LEVEL_CARD_SCENE.instantiate() as LevelCard
		card.setup(entry, unlock)
		if entry.unlocked_by != &"":
			card.set_hint_text(_hint_text(entry))
		if entry.available and unlock["unlocked"] and not unlock["moment_seen"] and not unlock["chosen"]:
			# The moment starts from the Locked look (EXPERIENCE "Level Unlocks").
			card.set_state(LevelCard.State.LOCKED)
			_moment_cards.append(card)
		card.chosen.connect(_on_card_chosen)
		card.unlock_moment_finished.connect(_on_unlock_moment_finished)
		%Cards.add_child(card)
		_cards.append(card)
		_entries.append(entry)


## "Finish Zombie Run to open!": the unlocked_by level's display name from the registry.
func _hint_text(entry: LevelEntry) -> String:
	var by: LevelEntry = level_registry.get_entry(entry.unlocked_by)
	var by_name: String = String(entry.unlocked_by).capitalize()
	if by != null and not by.display_name.is_empty():
		by_name = by.display_name
	return "Finish %s to open!" % by_name


## Marks each pending moment seen (saved before the animation, so a closed tab never replays it) and plays it.
func _start_unlock_moments() -> void:
	for card: LevelCard in _moment_cards:
		player_data.mark_unlock_seen(card.get_level_id())
		card.play_unlock_moment()


func _finish_unlock_moments() -> void:
	for card: LevelCard in _moment_cards:
		card.finish_unlock_moment()


## When the last moment ends, focus goes to the first new card (registry order).
func _on_unlock_moment_finished(_level_id: StringName) -> void:
	if is_playing_unlock_moment() or _moment_cards.is_empty():
		return
	_wire_focus()
	# Not when the player already moved on (Tab, mouse hover): only from where the menu opened, or nowhere.
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner == null or owner == _initial_focus or owner in _moment_cards:
		_moment_cards[0].grab_focus()


## The first card Enter can start (Available or New), or null.
func _first_choosable_card() -> LevelCard:
	for card: LevelCard in _cards:
		if card.is_choosable():
			return card
	return null


func _on_unlocks_changed(_level_id: StringName) -> void:
	_refresh_unlocks()


## Re-reads every card's state with no moment (F8 reset, debug tools). A moment still heading for the same
## New look keeps playing; any other change finishes it first. Focus is re-wired: the first choosable card
## may have changed. A focused card that became Locked keeps focus (Locked cards stay focusable).
func _refresh_unlocks() -> void:
	for i: int in _cards.size():
		var card: LevelCard = _cards[i]
		var state: LevelCard.State = LevelCard.state_for(_entries[i], player_data.get_unlock_state(_entries[i].id))
		if card.is_playing_moment():
			if state == LevelCard.State.NEW:
				continue
			card.finish_unlock_moment()
		card.set_state(state)
	_wire_focus()


## Two rows: the cards, and Closet / Music / Sound / Fullscreen. The row ends stop (no wrap).
func _wire_focus() -> void:
	var bottom: Array[Control] = [
		%ClosetButton, %MusicToggle.get_focus_target(), %SoundToggle.get_focus_target(),
		%FullscreenToggle.get_focus_target(),
	]
	var cards: Array[Control] = []
	cards.assign(_cards)
	_wire_row(cards, bottom[0], true)
	_wire_row(bottom, _first_choosable_card(), false)
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


## Story 5.5 (F1): the window mode changes after toggle_fullscreen returns, and viewport stretch keeps the root
## at 640 x 360 so size_changed rarely fires; so the mode is re-read every frame while the menu is open.
func _process(_delta: float) -> void:
	if _leaving:
		return
	if _fullscreen_settle > 0:
		_fullscreen_settle -= 1
		if is_fullscreen.call() == _fullscreen_before and _fullscreen_settle > 0:
			return  # not switched yet: keep the pressed state, no flicker
		_fullscreen_settle = 0
	_sync_fullscreen()


## A resize follows the mode too, but not while a press waits for the window or after the menu is left.
func _on_window_resized() -> void:
	if _leaving or _fullscreen_settle > 0:
		return
	_sync_fullscreen()


func _sync_fullscreen() -> void:
	var on: bool = is_fullscreen.call()
	if on != %FullscreenToggle.is_on():
		%FullscreenToggle.show_state(on)


func _show_storage_notice(persistent: bool) -> void:
	%StorageNotice.visible = not persistent


## The only navigation, at most once per menu. If the Router starts a transition that ends without freeing
## this menu (the target failed to load), the guard is released so the menu is not left dead.
func _leave(screen: Router.Screen, payload: Dictionary, on_started: Callable = Callable()) -> void:
	if _leaving or is_transitioning.call():
		return
	_leaving = true
	AudioManager.play_sfx(&"sfx_ui_click")
	navigate.call(screen, payload)
	if on_started.is_valid():
		on_started.call()
	if not is_transitioning.call():
		return
	while is_transitioning.call():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_leaving = false


## A New card's badge goes for good once it is picked here (Play Again on the report card doesn't count).
func _on_card_chosen(level_id: StringName) -> void:
	if _leaving or is_transitioning.call():
		return
	var was_new: bool = false
	for card: LevelCard in _cards:
		if card.get_level_id() == level_id and card.get_state() == LevelCard.State.NEW:
			was_new = true
	# The badge goes only once the Router has taken the navigation.
	_leave(Router.Screen.RUN, {"level_id": level_id}, func() -> void:
		if was_new:
			player_data.mark_level_chosen(level_id))


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
## The toggle already shows the asked-for state; _process keeps it until the window switches (or not).
## A press while the first one is still settling is ignored: the toggle shows the asked-for state again.
func _on_fullscreen_flipped(_on: bool) -> void:
	if _fullscreen_settle > 0:
		%FullscreenToggle.show_state(not _fullscreen_before)
		return
	_fullscreen_before = is_fullscreen.call()
	toggle_fullscreen.call()
	_fullscreen_settle = FULLSCREEN_SETTLE_FRAMES
	AudioManager.play_sfx(&"sfx_ui_click")
