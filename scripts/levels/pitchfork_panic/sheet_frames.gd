class_name SheetFrames
extends RefCounted
## Builds a one-animation SpriteFrames from a horizontal sprite sheet in code (Story 8.6). The Pitchfork
## Panic ending nodes (DustCloud, DizzyStars, EscapeBush) are script-only nodes that tests create with new(),
## so their sprites are made in _ready() rather than in a scene. One AtlasTexture region per frame, the
## texture filter left at the project default (Nearest). A sheet that fails to load logs one warning and
## returns null, so the node stays invisible-safe and the run goes on (NFR16).


## `frame_count` frames of `frame_px` square from the sheet at `path`, as animation `anim` at `fps`
## (`loop` as given). Null (after one warning naming `owner_name`) when the sheet cannot be loaded or is too small for the frames.
static func build(path: String, frame_count: int, frame_px: int, fps: float, anim: StringName, loop: bool,
		owner_name: String) -> SpriteFrames:
	var sheet: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if sheet == null:
		Log.warn(&"level", "%s has no sprite sheet at %s" % [owner_name, path])
		return null
	if sheet.get_width() < frame_count * frame_px or sheet.get_height() < frame_px:
		Log.warn(&"level", "%s sprite sheet %s is smaller than %d frames of %d px" % [owner_name, path, frame_count, frame_px])
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	frames.rename_animation(&"default", anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i: int in frame_count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_px, 0, frame_px, frame_px)
		frames.add_frame(anim, atlas)
	return frames
