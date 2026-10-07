class_name HordeSizeClass
extends Resource
## One Horde Rush size class (Story 6.3, FR55): which word lengths it covers and how its zombie copy
## marches, takes hits and pays at the house. HordeRushConfig holds the classes, shortest band first.
## Real values live in data/levels/horde_rush.tres; the defaults here are neutral.

## &"small", &"medium" or &"brute".
@export var id: StringName = &""
## Longest word in this class, inclusive. 0 = no upper bound (only the last class).
@export var max_word_length: int = 0
## Seconds a copy of this class takes from the left edge to the house.
@export var crossing_time_s: float = 0.0
## Hits the defender needs to stop a copy of this class (read by Story 6.4).
@export var hits_to_stop: int = 0
## Brains a copy of this class pays when it reaches the house (read by Story 6.5).
@export var arrival_brains: int = 0
## The copy's draw scale; the hat follows through its anchors plus this scale (D6).
@export var sprite_scale: float = 1.0
