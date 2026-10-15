class_name ZombieCard
extends Control
## One zombie on the "Who's playing?" screen (Story 11.2, FR78; DESIGN.md / EXPERIENCE.md "zombie-card", approved
## sketch sketches/whos-playing-11-2.md): a 352 × 52 parchment tile with that zombie (1×) wearing its own hat,
## its own pet beside it, and its name in 16 px ink. A profile with no valid name shows
## GameConstants.ZOMBIE_NAME_DEFAULT. No brains, WPM or tier: zombies are never compared (NFR10, FR60).
## The card shows what the screen gives it and never touches PlayerData: setup(summary, catalogue) before
## add_child takes PlayerData.get_profile_summary()'s {"id", "name", "hat", "pet"}, and Enter, Space or a left
## click emits picked(id). The hat and pet slots have follow_equipped = false (set in the scene, the Crypt Closet
## preview pattern) and show only what setup() hands them, so a card never follows the active profile.
## Every child ignores the mouse, so the card gets clicks and hover; real mouse motion moves focus here. The
## focused card shows the candy-yellow FocusRing 2 px outside its ink edge. The name is personal data: nothing
## here logs it (NFR12).

signal picked(id: StringName)

var _summary: Dictionary = {}
var _catalogue: Catalogue = null


func _ready() -> void:
	focus_entered.connect(_show_focus.bind(true))
	focus_exited.connect(_show_focus.bind(false))
	_show_focus(has_focus())
	_apply()


## Fills the card from a profile summary ({"id", "name", "hat", "pet"}) and the catalogue its hat and pet ids are
## looked up in. Call before add_child; calling again later re-shows the card.
func setup(summary: Dictionary, catalogue: Catalogue) -> void:
	_summary = summary.duplicate()
	_catalogue = catalogue
	if is_node_ready():
		_apply()


func get_profile_id() -> StringName:
	return StringName(_summary.get("id", &""))


## The text on the card: the name, or the default name when the profile has none.
func get_shown_name() -> String:
	return (%NameLabel as Label).text


func get_hat_id() -> StringName:
	return _hat_slot().get_item_id()


func get_pet_id() -> StringName:
	return (%PetSlot as PetSlot).get_item_id()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not has_focus() and focus_mode != FOCUS_NONE:
		grab_focus()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	var clicked: bool = click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if clicked or event.is_action_pressed(&"ui_accept"):
		accept_event()
		picked.emit(get_profile_id())


func _apply() -> void:
	var stored: Variant = _summary.get("name", "")
	var shown: String = stored as String if stored is String else ""
	(%NameLabel as Label).text = GameConstants.ZOMBIE_NAME_DEFAULT if shown.is_empty() else shown
	_hat_slot().show_item(_item_for(_summary.get("hat", &"")))
	(%PetSlot as PetSlot).show_item(_item_for(_summary.get("pet", &"")))


func _item_for(id: Variant) -> CosmeticItem:
	if _catalogue == null or not (id is StringName or id is String) or String(id).is_empty():
		return null
	return _catalogue.get_item(StringName(id))


## The zombie's hat slot (unique inside player_zombie.tscn, so reached through %Zombie).
func _hat_slot() -> HatSlot:
	return %Zombie.get_node(^"%HatSlot") as HatSlot


func _show_focus(focused: bool) -> void:
	# focus_exited also fires while the card is being freed, after its children are gone.
	var ring: Control = get_node_or_null(^"%FocusRing") as Control
	if ring != null:
		ring.visible = focused
