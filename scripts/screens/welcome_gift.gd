extends Control
## The Welcome Gift card (Story 4.5, FR44; DESIGN.md / EXPERIENCE.md "welcome-gift-card"): a wood panel
## with a pumpkin ribbon and bow, a parchment "Welcome gift!" sign, "+N" next to a brain icon (N is
## EconomyConfig.welcome_bonus, never a literal) and one pre-focused "Open the Crypt Closet" button. The
## report card sends the first completed run's exit here; the payload is consumed and ignored.
## Grant on show, once: in _ready(), if welcome_bonus_claimed is false, add_brains(bonus) then set the flag,
## in the same frame (one coalesced save, so a reload sees both or neither). Already claimed (only reachable
## through the debug jump): logs, grants nothing, shows the same card. No economy: logs an error, grants
## nothing, sets the flag anyway (else every report card exit would redirect here forever), and the button
## still works (NFR16).
## The button (Enter or a click) goes to the Crypt Closet with {"tutorial": true}, once. Esc does nothing:
## the gift exists to teach the Closet. Mash guard: for INPUT_GUARD_S seconds of live time (counted in
## _process, which doesn't run during the Router's paused fade-in) every key or mouse press is swallowed.
## Seams (tests assign them before add_child): economy (exported), navigate, player_data, play_sfx.
## Story 5.0 art: a WoodPanel wrapped in the pumpkin Ribbon 9-slice with the bow sprite, the parchment Sign and
## the 32 px brain icon sprite. The gift sound and the counter tick-up are Story 5.1.

const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")
## Look value, not a GDD number: presses are ignored this long after the card goes live.
const INPUT_GUARD_S: float = 0.5

## Brains rules (data/economy.tres, set in welcome_gift.tscn).
@export var economy: EconomyConfig

## Test seam: called as navigate.call(screen, payload). Defaults to Router.go in _ready.
var navigate: Callable
## Test seam: defaults to the PlayerData autoload in _ready.
var player_data: PlayerDataScript = null
## Test seam: called as play_sfx.call(cue_id). Defaults to AudioManager.play_sfx in _ready.
var play_sfx: Callable

## Seconds the card has been live (unpaused); drives the guard.
var _open_s: float = 0.0
## Set by the one navigation; nothing navigates after it.
var _leaving: bool = false


func _ready() -> void:
	if not navigate.is_valid():
		navigate = Router.go
	if player_data == null:
		player_data = PlayerData
	if not play_sfx.is_valid():
		play_sfx = AudioManager.play_sfx
	Router.take_payload()
	_grant()
	%AmountLabel.text = "+%d" % (economy.welcome_bonus if economy != null else 0)
	%OpenClosetButton.pressed.connect(_open_closet)
	%OpenClosetButton.grab_focus()


func _process(delta: float) -> void:
	_open_s += delta
	if _guard_passed():
		set_process(false)


func _input(event: InputEvent) -> void:
	var echo: bool = event is InputEventKey and (event as InputEventKey).echo
	if echo or (event.is_pressed() and (_leaving or not _guard_passed())):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and get_viewport().gui_get_focus_owner() == null:
		get_viewport().set_input_as_handled()
		_open_closet()


## Grants the welcome bonus and sets the flag, once per save.
func _grant() -> void:
	if economy == null:
		Log.error(&"economy", "welcome gift: no economy, nothing granted")
		player_data.set_flag(&"welcome_bonus_claimed", true)
		return
	if player_data.get_flag(&"welcome_bonus_claimed"):
		Log.info(&"economy", "welcome gift already claimed, nothing granted")
		return
	player_data.add_brains(economy.welcome_bonus)
	player_data.set_flag(&"welcome_bonus_claimed", true)


## True once the mash guard is over.
func _guard_passed() -> bool:
	return _open_s >= INPUT_GUARD_S


func _open_closet() -> void:
	if _leaving or not _guard_passed():
		return
	_leaving = true
	play_sfx.call(&"sfx_ui_click")
	navigate.call(Router.Screen.CRYPT_CLOSET, {"tutorial": true})
