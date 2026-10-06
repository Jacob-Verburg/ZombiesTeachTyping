extends GutTest
## Villager (Story 3.3, FR32/FR34): a ZombieRunTarget that waves with its letter tag above its head. Typing
## its letter hugs it (WAITING -> HUGGED, 0 brains); after hug_time_s it poofs (POOFED) on its own
## node-bound tween, and when the poof ends a party-hat zombie stands in its place and poofed is emitted.

const VillagerScene: PackedScene = preload("res://scenes/levels/zombie_run/villager.tscn")
const HUG_TIME_S: float = 0.4


func _villager(letter: String = "k", slot: int = 2) -> Villager:
	var villager: Villager = VillagerScene.instantiate() as Villager
	villager.setup(letter, slot)
	villager.configure(HUG_TIME_S)
	villager.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(villager)
	return villager


func _poofs(villager: Villager) -> Array[Poof]:
	var out: Array[Poof] = []
	for child: Node in villager.get_children():
		if child is Poof:
			out.append(child as Poof)
	return out


func _body(villager: Villager) -> AnimatedSprite2D:
	return villager.get_node("%Body") as AnimatedSprite2D


func test_is_a_waving_target_with_its_letter() -> void:
	var villager: Villager = _villager("q", 5)
	assert_true(villager is ZombieRunTarget)
	assert_eq(villager.get_letter(), "q")
	assert_eq(villager.get_slot(), 5)
	assert_eq((villager.get_node("%Letter") as Label).text, "q", "tag shows the letter")
	var body: AnimatedSprite2D = _body(villager)
	assert_false(body.centered)
	assert_eq(body.position, Vector2(-16, -31), "feet on the ground line")
	assert_true(body.visible)
	var frames: SpriteFrames = body.sprite_frames
	assert_not_null(frames)
	assert_true(frames.has_animation(&"wave"))
	assert_eq(frames.get_frame_count(&"wave"), 2)
	assert_eq(frames.get_animation_speed(&"wave"), 8.0)
	assert_true(frames.get_animation_loop(&"wave"))
	assert_eq(body.animation, &"wave")
	assert_false(villager.is_party_zombie_shown())
	assert_false(villager.get_party_zombie().visible)
	assert_eq(villager.get_state(), Villager.State.WAITING)


func test_party_zombie_does_not_bob() -> void:
	var villager: Villager = _villager()
	var party: PartyZombie = villager.get_party_zombie()
	assert_not_null(party)
	assert_eq(party.get_parent(), villager, "a child of the root, not of %Visual")
	assert_eq(party.position, Vector2.ZERO, "stands on the villager's feet")


func test_active_shows_the_arrow_and_the_tag_sits_above_the_head() -> void:
	var villager: Villager = _villager()
	villager.set_active(true)
	assert_true((villager.get_node("%Arrow") as CanvasItem).visible)
	var tag: Panel = villager.get_node("%Tag") as Panel
	assert_eq(tag.size, Vector2(24, 24), "same tag as every target")
	assert_true(tag.position.y + tag.size.y <= -28.0, "tag bottom above the head (y -27)")
	assert_true(tag.size.x <= 2.0 * ZombieRunTarget.HALF_WIDTH, "nothing wider than the tag")
	villager.set_active(false)
	assert_false((villager.get_node("%Arrow") as CanvasItem).visible)


func test_resolve_hugs_and_pays_nothing() -> void:
	var villager: Villager = _villager()
	villager.set_active(true)
	assert_eq(villager.resolve(), 0, "villagers pay no brains")
	assert_eq(villager.get_state(), Villager.State.HUGGED, "hugged in the same call")
	assert_false((villager.get_node("%Tag") as CanvasItem).visible)
	assert_false((villager.get_node("%Arrow") as CanvasItem).visible)
	assert_true(_body(villager).visible, "still visible during the hug")
	var sequence: Tween = villager.get_sequence_tween()
	assert_not_null(sequence)
	assert_true(sequence.is_valid())
	assert_eq(villager.resolve(), 0, "a second resolve pays nothing")
	assert_eq(villager.get_state(), Villager.State.HUGGED)
	assert_eq(villager.get_sequence_tween(), sequence, "no second sequence")


func test_poofs_after_the_hug_time() -> void:
	var villager: Villager = _villager()
	villager.resolve()
	villager.get_sequence_tween().custom_step(HUG_TIME_S - 0.05)
	assert_eq(villager.get_state(), Villager.State.HUGGED, "not yet")
	assert_eq(_poofs(villager).size(), 0)
	villager.get_sequence_tween().custom_step(0.06)
	assert_eq(villager.get_state(), Villager.State.POOFED)
	assert_false(_body(villager).visible, "the villager sprite hides")
	assert_eq(_poofs(villager).size(), 1, "a poof child")
	assert_false(villager.is_party_zombie_shown(), "not until the poof ends")


func test_party_zombie_appears_when_the_poof_ends() -> void:
	var villager: Villager = _villager()
	watch_signals(villager)
	villager.resolve()
	villager.get_sequence_tween().custom_step(HUG_TIME_S + 0.01)
	var poof: Poof = _poofs(villager)[0]
	assert_eq(poof.position, Vector2.ZERO, "the poof sheet is drawn from the feet: at the villager's origin")
	poof.get_tween().custom_step(Poof.FRAMES / Poof.FPS + 0.01)
	assert_signal_emit_count(villager, "poofed", 1)
	assert_signal_emitted_with_parameters(villager, "poofed", [villager.get_party_zombie()])
	assert_true(villager.is_party_zombie_shown())
	assert_true(villager.get_party_zombie().visible)
	assert_true(poof.is_queued_for_deletion(), "the poof frees itself")
	assert_eq(villager.get_state(), Villager.State.POOFED)


## The internal _set_state() is called directly: its debug assert logs an engine error and continues in a
## headless GUT run (it does not abort the test), so the test checks the state and consumes the errors.
func test_state_never_goes_backward() -> void:
	var villager: Villager = _villager()
	villager.resolve()
	villager.get_sequence_tween().custom_step(HUG_TIME_S + 0.01)
	assert_eq(villager.get_state(), Villager.State.POOFED)
	villager._set_state(Villager.State.WAITING)
	assert_eq(villager.get_state(), Villager.State.POOFED, "never back to WAITING")
	villager._set_state(Villager.State.HUGGED)
	assert_eq(villager.get_state(), Villager.State.POOFED, "never back to HUGGED")
	assert_engine_error_count(2, "the debug assert fires on each backward move")


func test_state_never_skips_back_from_hugged() -> void:
	var villager: Villager = _villager()
	villager.resolve()
	villager._set_state(Villager.State.WAITING)
	assert_eq(villager.get_state(), Villager.State.HUGGED)
	assert_engine_error("Villager state can only move forward")


func test_arrow_is_the_sprite_above_the_tag() -> void:
	ArrowTipAssert.assert_tip(self, _villager(), -57.0)


# --- sound (Story 5.1) ----------------------------------------------------------

func test_hug_poof_plays_once_as_the_poof_starts() -> void:
	var played: Array[StringName] = []
	var villager: Villager = VillagerScene.instantiate() as Villager
	villager.setup("k", 2)
	villager.configure(HUG_TIME_S)
	villager.play_sfx = func(id: StringName) -> void: played.append(id)
	villager.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(villager)
	villager.resolve()
	assert_eq(played, [] as Array[StringName], "not on the keypress")
	villager.get_sequence_tween().custom_step(HUG_TIME_S + 0.01)
	assert_eq(played, [&"sfx_hug_poof"] as Array[StringName], "with the visible poof")
	_poofs(villager)[0].get_tween().custom_step(Poof.FRAMES / Poof.FPS + 0.01)
	assert_eq(played.size(), 1, "once")


func test_villager_without_the_seam_is_silent() -> void:
	var villager: Villager = _villager()
	villager.resolve()
	villager.get_sequence_tween().custom_step(HUG_TIME_S + 0.01)
	assert_false(villager.play_sfx.is_valid())
	assert_eq(villager.get_state(), Villager.State.POOFED, "poofs fine without a sound")
