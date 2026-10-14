class_name LevelTheme
extends Resource
## One look for a level (Story 10.1, FR76): a backdrop, for Horde Rush a defender, and an optional music
## track. A theme is art and music only; the rules live in the level's LevelConfig and never vary per
## theme, so this resource must never gain a timing, speed, count, brains or word field (a test pins the
## property list). RunFrame picks one per run (ThemePicker) and hands it to LevelBase.apply_theme.
## Ids are permanent once shipped: they are saved as each level's last theme.

## The theme id, saved as the level's last theme, e.g. &"sunny_village_green". Unique within its entry.
@export var id: StringName
## The scene that replaces the level's backdrop slot (%Backdrop, or %Field for Horde Rush). Its root
## must work where the built-in one did (Zombie Run and Pitchfork Panic: a SunnyVillageBackdrop).
@export var backdrop: PackedScene
## Horde Rush only: the scene that replaces %Defender. Null elsewhere.
@export var defender: PackedScene
## The music track for runs in this theme; empty = the level config's music_id.
@export var music_id: StringName = &""
