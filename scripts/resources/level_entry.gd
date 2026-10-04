class_name LevelEntry
extends Resource
## One row of the LevelRegistry: a level id, its scene and the name kids read. Card art,
## availability and unlock rules arrive with Stories 4.2 / 6.8.

## The id the menu and the RUN payload use, e.g. &"zombie_run".
@export var id: StringName
## The level's name as kids read it, e.g. "Zombie Run". Shown as the report card heading.
@export var display_name: String = ""
## The level scene; its root extends LevelBase.
@export var scene: PackedScene
## Debug-only levels (the test level) never appear on the real menu.
@export var debug_only: bool = false
