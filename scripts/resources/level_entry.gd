class_name LevelEntry
extends Resource
## One row of the LevelRegistry: a level id, its scene, the name kids read, whether the menu card
## can be chosen and the card picture. Unlock rules arrive with Story 6.8.

## The id the menu and the RUN payload use, e.g. &"zombie_run".
@export var id: StringName
## The level's name as kids read it, e.g. "Zombie Run". Shown as the report card heading.
@export var display_name: String = ""
## The level scene; its root extends LevelBase.
@export var scene: PackedScene
## Debug-only levels (the test level) never appear on the real menu.
@export var debug_only: bool = false
## False = the card shows Coming soon and cannot be chosen (FR26). Coming soon wins over Locked (FR79).
@export var available: bool = false
## Card picture; placeholder until Story 5.0's `ui_level_card_<id>.png`. Null = a flat placeholder fill.
@export var card_picture: Texture2D
