class_name SpriteAnchors
extends Resource
## Per-frame head points for one character's SpriteFrames (architecture D6). A point is in the
## AnimatedSprite2D's local pixels (centered = false, so (0, 0) is the frame's top-left): the top-centre of
## the crown, where a hat's seat goes. Measured from the art; tests/unit/test_sprite_anchors.gd re-measures
## the PNGs. The shipped sets are data/anchors/<character>_anchors.tres.

## Animation name -> one head point per frame, in frame order.
@export var head: Dictionary[StringName, PackedVector2Array] = {}


## True when `anim` has a point for `frame`.
func has_head(anim: StringName, frame: int) -> bool:
	if not head.has(anim):
		return false
	return frame >= 0 and frame < head[anim].size()


## The head point of `anim` frame `frame`, or Vector2.ZERO when missing. Callers check has_head() first
## and handle the gap, so this never logs.
func get_head(anim: StringName, frame: int) -> Vector2:
	if not has_head(anim, frame):
		return Vector2.ZERO
	return head[anim][frame]


## Empty when every animation in `frames` has exactly one point per frame and nothing extra; otherwise
## the first problem found.
func validate(frames: SpriteFrames) -> String:
	if frames == null:
		return "no sprite frames"
	for anim: StringName in frames.get_animation_names():
		if not head.has(anim):
			return "animation %s has no anchors" % anim
		var count: int = frames.get_frame_count(anim)
		if head[anim].size() != count:
			return "animation %s has %d anchors, want %d" % [anim, head[anim].size(), count]
	for anim: StringName in head:
		if not frames.has_animation(anim):
			return "anchors for %s, which has no frames" % anim
	return ""
