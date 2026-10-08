class_name LevelRegistry
extends Resource
## level_id -> level scene. RunFrame looks up the RUN payload's level_id here. The shipped registry is
## data/levels/level_registry.tres; ids must be unique there (a unit test checks), and if two entries
## ever share an id the first one wins. Each entry's unlocked_by names the level whose finished run opens
## it (Story 6.8); validate() checks the chain.

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


## The entries that get a main-menu card, in registry order: non-null and not debug_only. Debug-only
## levels never get a card, even in a debug build (the debug overlay jumps to them, Story 4.2).
func menu_entries() -> Array[LevelEntry]:
	var result: Array[LevelEntry] = []
	for entry: LevelEntry in entries:
		if entry != null and not entry.debug_only:
			result.append(entry)
	return result


## The entries opened by a finished run of `level_id` (their unlocked_by == level_id), in registry order.
## Empty for an empty id.
func unlocks_of(level_id: StringName) -> Array[LevelEntry]:
	var result: Array[LevelEntry] = []
	if level_id == &"":
		return result
	for entry: LevelEntry in entries:
		if entry != null and entry.unlocked_by == level_id:
			result.append(entry)
	return result


## "" when every unlocked_by names an existing, non-debug, different entry and following unlocked_by
## from any entry never comes back to an id; otherwise a message naming the first problem.
func validate() -> String:
	for entry: LevelEntry in entries:
		if entry == null or entry.unlocked_by == &"":
			continue
		if entry.unlocked_by == entry.id:
			return "%s is unlocked by itself" % entry.id
		var by: LevelEntry = get_entry(entry.unlocked_by)
		if by == null:
			return "%s is unlocked by unknown level %s" % [entry.id, entry.unlocked_by]
		if by.debug_only:
			return "%s is unlocked by debug-only level %s" % [entry.id, entry.unlocked_by]
	for entry: LevelEntry in entries:
		if entry == null:
			continue
		var seen: Array[StringName] = [entry.id]
		var current: LevelEntry = entry
		while current != null and current.unlocked_by != &"":
			if current.unlocked_by in seen:
				return "unlock chain loops at %s" % current.unlocked_by
			seen.append(current.unlocked_by)
			current = get_entry(current.unlocked_by)
	return ""
