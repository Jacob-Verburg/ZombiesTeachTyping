class_name ChaseMob
extends Node2D
## The Pitchfork Panic mob (Story 8.6, FR70): four villagers woken up in their pyjamas, run as one mob from
## two base sprites and their clothes recolours (GDD Reuse). The node's origin is the front member's feet,
## so the level keeps placing it at the logical mob position (mob_steps * step_px) and the gap, the catch
## and the "on screen under mob_visible_gap_steps" rule are unchanged; the other three trail behind (MEMBER_OFFSETS,
## the back one 42 px behind, 58 px counting its width), the front one drawn last.
##
## Each member is an AnimatedSprite2D in the Body convention (centered = false, at (-16, -31) plus its x
## offset) with one looping 10 fps "run". They start on different frames (fixed, no RNG) so the legs never
## march in lockstep. run() plays them, freeze() stops them dead on the current frame (the comic halt when
## the run ends). No _process, no RNG, no await, no sound: the level drives it. A member without
## SpriteFrames warns once for the whole mob and the run goes on (NFR16).

const ANIM_RUN: StringName = &"run"
## Member nodes, front (right) to back. The scene lists them back to front, so the front draws last.
const MEMBER_NAMES: Array[StringName] = [&"PitchA", &"TorchB", &"PitchAlt", &"TorchAlt"]
## Each member's feet x relative to the origin, front to back. Layout values: the back member at -42 keeps
## the whole mob on screen at gap 19.9 (the level's screen-rect test).
const MEMBER_OFFSETS: Array[float] = [0.0, -14.0, -28.0, -42.0]
## Each member's first frame, front to back (fixed: no RNG).
const START_FRAMES: Array[int] = [0, 2, 1, 3]
## Body convention: the sheet's feet centre (16, 31) sits on the member's feet x.
const BODY_OFFSET: Vector2 = Vector2(-16.0, -31.0)
## Half a member's 32 px frame: the back member's frame reaches this far behind its feet.
const HALF_FRAME_PX: float = 16.0


func _ready() -> void:
	var missing: Array[String] = []
	var members: Array[AnimatedSprite2D] = get_members()
	for i: int in members.size():
		var member: AnimatedSprite2D = members[i]
		member.position = BODY_OFFSET + Vector2(MEMBER_OFFSETS[i], 0.0)
		if member.sprite_frames == null or not member.sprite_frames.has_animation(ANIM_RUN):
			missing.append(member.name)
			continue
		member.animation = ANIM_RUN
		member.frame = START_FRAMES[i]
		member.pause()
	if members.size() != MEMBER_NAMES.size():
		missing.append("%d of %d members" % [members.size(), MEMBER_NAMES.size()])
	if not missing.is_empty():
		Log.warn(&"level", "chase mob is missing run frames: %s" % ", ".join(missing))


## Plays every member's run from its current frame.
func run() -> void:
	for member: AnimatedSprite2D in get_members():
		if member.sprite_frames != null and member.sprite_frames.has_animation(ANIM_RUN):
			member.play(ANIM_RUN)


## Stops every member dead on its current frame.
func freeze() -> void:
	for member: AnimatedSprite2D in get_members():
		member.pause()


## How far the mob reaches behind its origin in px: the back member's offset plus half its frame (58).
func get_back_px() -> float:
	return -MEMBER_OFFSETS.back() + HALF_FRAME_PX


## The members front to back (the ones present). For the level and tests.
func get_members() -> Array[AnimatedSprite2D]:
	var members: Array[AnimatedSprite2D] = []
	for member_name: StringName in MEMBER_NAMES:
		var member: AnimatedSprite2D = get_node_or_null(NodePath(member_name)) as AnimatedSprite2D
		if member != null:
			members.append(member)
	return members
