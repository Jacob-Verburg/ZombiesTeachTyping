extends GutTest
## ZombieCard (Story 11.2): shows a profile summary's name (or the default name), hat and pet from the catalogue
## it is given, emits picked(id) once on Enter or a left click, shows the focus ring only while focused, and never
## follows PlayerData (its hat and pet slots don't connect to the autoload).

const ZombieCardScene: PackedScene = preload("res://scenes/ui/zombie_card.tscn")
const HAT: CosmeticItem = preload("res://data/cosmetics/hat_pumpkin.tres")
const PET: CosmeticItem = preload("res://data/cosmetics/pet_cute_ghost.tres")


func _catalogue() -> Catalogue:
	var catalogue: Catalogue = Catalogue.new()
	catalogue.items.append(HAT)
	catalogue.items.append(PET)
	return catalogue


func _make(summary: Dictionary) -> ZombieCard:
	var card: ZombieCard = ZombieCardScene.instantiate() as ZombieCard
	card.setup(summary, _catalogue())
	add_child_autofree(card)
	return card


func _card_summary(name: String = "Sam", hat: StringName = &"", pet: StringName = &"") -> Dictionary:
	return {"id": &"p2", "name": name, "hat": hat, "pet": pet}


func test_shows_name_hat_and_pet() -> void:
	var card: ZombieCard = _make(_card_summary("Sam", HAT.id, PET.id))
	assert_eq(card.get_shown_name(), "Sam")
	assert_eq(card.get_hat_id(), HAT.id)
	assert_eq(card.get_pet_id(), PET.id)
	assert_eq(card.get_profile_id(), &"p2")


func test_nothing_worn_shows_no_hat_and_no_pet() -> void:
	var card: ZombieCard = _make(_card_summary())
	assert_eq(card.get_hat_id(), &"")
	assert_eq(card.get_pet_id(), &"")


func test_an_unknown_item_id_shows_nothing() -> void:
	var card: ZombieCard = _make(_card_summary("Sam", &"hat_nope", &"pet_nope"))
	assert_eq(card.get_hat_id(), &"")
	assert_eq(card.get_pet_id(), &"")


func test_empty_name_shows_the_default_name() -> void:
	var card: ZombieCard = _make(_card_summary(""))
	assert_eq(card.get_shown_name(), GameConstants.ZOMBIE_NAME_DEFAULT)


func test_enter_emits_picked_once_with_the_id() -> void:
	var card: ZombieCard = _make(_card_summary())
	watch_signals(card)
	var enter: InputEventAction = InputEventAction.new()
	enter.action = &"ui_accept"
	enter.pressed = true
	card._gui_input(enter)
	assert_signal_emit_count(card, "picked", 1)
	assert_signal_emitted_with_parameters(card, "picked", [&"p2"])


func test_left_click_emits_picked_once_and_right_click_does_not() -> void:
	var card: ZombieCard = _make(_card_summary())
	watch_signals(card)
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	card._gui_input(right)
	var left: InputEventMouseButton = InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	card._gui_input(left)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	card._gui_input(release)
	assert_signal_emit_count(card, "picked", 1)


func test_hover_grabs_focus() -> void:
	var card: ZombieCard = _make(_card_summary())
	card._gui_input(InputEventMouseMotion.new())
	assert_true(card.has_focus())


func test_focus_ring_only_while_focused() -> void:
	var card: ZombieCard = _make(_card_summary())
	var ring: Control = card.get_node("%FocusRing")
	assert_false(ring.visible)
	card.grab_focus()
	assert_true(ring.visible)
	card.release_focus()
	assert_false(ring.visible)


func test_card_is_focusable_and_children_ignore_the_mouse() -> void:
	var card: ZombieCard = _make(_card_summary())
	assert_eq(card.focus_mode, Control.FOCUS_ALL)
	assert_gte(card.size.y, 32.0, "every control is at least 32 px tall")
	for node: Node in card.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % node.name)


func test_card_never_follows_player_data() -> void:
	var card: ZombieCard = _make(_card_summary("Sam", HAT.id, PET.id))
	var hat_slot: HatSlot = card.get_node("%Zombie").get_node("%HatSlot") as HatSlot
	var pet_slot: PetSlot = card.get_node("%PetSlot") as PetSlot
	assert_false(hat_slot.follow_equipped)
	assert_false(pet_slot.follow_equipped)
	assert_null(hat_slot.player_data, "the hat slot never takes the PlayerData autoload")
	assert_null(pet_slot.player_data, "the pet slot never takes the PlayerData autoload")
	assert_false(PlayerData.profile_replaced.is_connected(hat_slot._on_profile_replaced))
	assert_false(PlayerData.profile_replaced.is_connected(pet_slot._on_profile_replaced))


func test_setup_again_reshows_the_card() -> void:
	var card: ZombieCard = _make(_card_summary("Sam", HAT.id))
	card.setup(_card_summary("Bo"), _catalogue())
	assert_eq(card.get_shown_name(), "Bo")
	assert_eq(card.get_hat_id(), &"")
