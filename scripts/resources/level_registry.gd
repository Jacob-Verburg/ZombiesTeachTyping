class_name LevelRegistry
extends Resource
## level_id -> level scene. RunFrame looks up the RUN payload's level_id here. The shipped registry is
## data/levels/level_registry.tres; ids must be unique there (a unit test checks), and if two entries
## ever share an id the first one wins.

## Every registered level, in menu order.
@export var entries: Array[LevelEntry] = []


## The entry for `id`, or null when the id is unknown or empty.
func get_entry(id: StringName) -> LevelEntry:
	if id == &"":
		return null
	for entry: LevelEntry in entries:
		if entry != null and entry.id == id:
			return entry
	return null


## The scene for `id`, or null when the id is unknown, the entry has no scene, or the entry is
## debug_only and this is not a debug build (`debug_build` is a test seam).
func get_scene(id: StringName, debug_build: bool = OS.is_debug_build()) -> PackedScene:
	var entry: LevelEntry = get_entry(id)
	if entry == null or (entry.debug_only and not debug_build):
		return null
	return entry.scene
