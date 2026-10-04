class_name LevelEntry
extends Resource
## One row of the LevelRegistry: a level id and its scene. Card art, availability and unlock rules
## arrive with Stories 4.2 / 6.8.

## The id the menu and the RUN payload use, e.g. &"zombie_run".
@export var id: StringName
## The level scene; its root extends LevelBase.
@export var scene: PackedScene
## Debug-only levels (the test level) never appear on the real menu.
@export var debug_only: bool = false
