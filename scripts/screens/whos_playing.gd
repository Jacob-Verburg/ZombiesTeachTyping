extends Control
## The "Who's playing?" screen (Story 11.2, FR78, FR25; sketch whos-playing-11-2.md, approved 2026-10-15). The
## title comes here once any zombie has a name. One ZombieCard per profile (PlayerData.get_profile_ids() order,
## each built from get_profile_summary(): its own name, hat and pet) in a top-aligned list under the sign, and a
## "New zombie" PixelButton under the last card, hidden and unfocusable once the save holds
## GameConstants.MAX_ZOMBIES zombies.
## Arrow keys and Tab walk the cards, then New zombie (ends stop, no wrap); focus starts on the card of the zombie
## that played last (the active profile). Enter, Space or a click on a card switches to that zombie
## (PlayerData.switch_profile), plays the UI click and navigates once: to the main menu when it has a name, else
## to the name screen (Story 11.1's mode). New zombie plays the click and opens the name screen with
## {"new_zombie": true}; the profile is only created there, once a good name is confirmed. Esc does nothing (the
## title is not a place to go back to). The payload is consumed and ignored. The cards are rebuilt on
## profile_replaced (an F8 reset while open). One navigation per visit (_leaving, released if the Router's
## transition never starts or ends without freeing the screen). Names are personal data: nothing here logs them
## (NFR12); this screen doesn't type, so WebPlatform.capture_keys is left alone.
## Seams (tests assign them before add_child): navigate, player_data, play_sfx, play_music, is_transitioning,
## catalogue.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
const ZombieCardScene: PackedScene = preload("res://scenes/ui/zombie_card.tscn")
const CATALOGUE: Catalogue = preload("res://data/cosmetics/catalogue.tres")
## Look value, not a GDD number: the gap between two cards.
const CARD_GAP_PX: float = 4.0
## Look value, not a GDD number: the gap between the last card and New zombie.
const BUTTON_GAP_PX: float = 12.0

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
## Where the cards look up hat and pet ids; null = the shipped catalogue.
@export var catalogue: Catalogue = null

## Set by the one navigation; nothing picks or rebuilds after it.
var _leaving: bool = false


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
	if catalogue == null:
		catalogue = CATALOGUE
	Router.take_payload()
	play_music.call(&"mus_menu")
	%NewZombieButton.pressed.connect(_new_zombie)
	player_data.profile_replaced.connect(_on_profile_replaced)
	_build()


func _exit_tree() -> void:
	if player_data != null and player_data.profile_replaced.is_connected(_on_profile_replaced):
		player_data.profile_replaced.disconnect(_on_profile_replaced)
	if is_inside_tree() and get_tree().process_frame.is_connected(_release_when_settled):
		get_tree().process_frame.disconnect(_release_when_settled)


## The cards, in list order.
func get_cards() -> Array[ZombieCard]:
	var cards: Array[ZombieCard] = []
	for child: Node in %Cards.get_children():
		if child is ZombieCard:
			cards.append(child as ZombieCard)
	return cards


## Esc does nothing here; it is taken so nothing behind the screen sees it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()


## A reset replaced the save while the picker is open: show the zombies it holds now.
func _on_profile_replaced() -> void:
	if not _leaving:
		_build()


## (Re)builds one card per profile, shows New zombie only while there is room, wires focus and focuses the
## active zombie's card (the first card if none matches).
func _build() -> void:
	var holder: Control = %Cards
	for old: Node in holder.get_children():
		holder.remove_child(old)
		old.queue_free()
	var active: StringName = player_data.get_active_profile_id()
	var focus_card: ZombieCard = null
	var y: float = 0.0
	for id: StringName in player_data.get_profile_ids():
		var card: ZombieCard = ZombieCardScene.instantiate() as ZombieCard
		card.setup(player_data.get_profile_summary(id), catalogue)
		card.position = Vector2(0.0, y)
		card.picked.connect(_pick)
		holder.add_child(card)
		y += card.size.y + CARD_GAP_PX
		if focus_card == null or id == active:
			focus_card = card
	var button: Button = %NewZombieButton
	var can_add: bool = player_data.can_add_zombie()
	button.visible = can_add
	button.focus_mode = Control.FOCUS_ALL if can_add else Control.FOCUS_NONE
	button.position.y = holder.position.y + maxf(y - CARD_GAP_PX, 0.0) + BUTTON_GAP_PX
	_wire_focus()
	if focus_card != null:
		focus_card.grab_focus()
	elif can_add:
		button.grab_focus()


## One focus list: the cards then New zombie (when shown). Arrows and Tab step through it; the ends stop.
func _wire_focus() -> void:
	var order: Array[Control] = []
	for card: ZombieCard in get_cards():
		order.append(card)
	var button: Button = %NewZombieButton
	if button.visible:
		order.append(button)
	for i: int in order.size():
		var control: Control = order[i]
		var previous: NodePath = control.get_path_to(order[maxi(i - 1, 0)])
		var next: NodePath = control.get_path_to(order[mini(i + 1, order.size() - 1)])
		control.focus_neighbor_top = previous
		control.focus_neighbor_left = previous
		control.focus_previous = previous
		control.focus_neighbor_bottom = next
		control.focus_neighbor_right = next
		control.focus_next = next


## A card was picked: that zombie plays. Named → main menu; not named yet → the name screen (11.1's mode).
func _pick(id: StringName) -> void:
	if _leaving or is_transitioning.call():
		return
	_leaving = true  # before the switch: its profile_replaced must not rebuild the cards being clicked
	if not player_data.switch_profile(id):
		_leaving = false
		return
	play_sfx.call(&"sfx_ui_click")
	var named: bool = not player_data.get_zombie_name().is_empty()
	_go(Router.Screen.MAIN_MENU if named else Router.Screen.NAME_ZOMBIE)


## New zombie: the name screen in its new-zombie mode. Nothing is created here.
func _new_zombie() -> void:
	if _leaving or is_transitioning.call() or not player_data.can_add_zombie():
		return
	_leaving = true
	play_sfx.call(&"sfx_ui_click")
	_go(Router.Screen.NAME_ZOMBIE, {"new_zombie": true})


## The one navigation. If the Router never starts a transition, or it ends with this screen still here, the
## screen takes input again.
func _go(screen: Router.Screen, payload: Dictionary = {}) -> void:
	_leaving = true
	navigate.call(screen, payload)
	if not is_transitioning.call():
		_leaving = false
		return
	# A connection to a method (not an await), so nothing resumes on a freed screen.
	get_tree().process_frame.connect(_release_when_settled)


func _release_when_settled() -> void:
	if is_transitioning.call():
		return
	get_tree().process_frame.disconnect(_release_when_settled)
	_leaving = false
