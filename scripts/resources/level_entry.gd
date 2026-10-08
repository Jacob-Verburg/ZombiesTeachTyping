class_name LevelEntry
extends Resource
## One row of the LevelRegistry: a level id, its scene, the name kids read, whether the menu card
## can be chosen, the card picture and which level's finished run opens it (Story 6.8, FR79).
## Adding a level later: set its unlocked_by here in the registry; only if old saves should get it opened
## by runs they already hold, add a new SaveSchema migration (migrations never read the registry).

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
## Card picture, `assets/sprites/ui/menu/ui_level_card_<id>.png` (184 x 72, Story 5.0). Null = the card's flat
## PictureFill (NFR16 fallback).
@export var card_picture: Texture2D
## The level whose finished run (timer reached its end) opens this one; empty = open from the start. FR79.
## Must name an existing, non-debug, different entry, without loops (LevelRegistry.validate()).
@export var unlocked_by: StringName = &""
