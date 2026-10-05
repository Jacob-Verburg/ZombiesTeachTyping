class_name ZombieRunGroups
extends RefCounted
## Deals Zombie Run's target kinds (Story 3.2, FR32): targets come in groups of N (brain_block_every),
## and each group holds exactly 1 brain block and N - 1 villager slots in a shuffled order. Slots are
## dealt strictly in order, so the n-th next() is the kind for slot n and group k covers slots
## kN .. kN + N - 1.
##
## Randomness: the dealer owns its own RNG, a child the level seeds from the run RNG after the letter
## bag's child. The layout then never depends on the letters or on how many Brainsss rolls the run RNG
## made, so a seed replays the same blocks (Story 2.10). The shuffle is a Fisher-Yates on that RNG;
## Array.shuffle() and pick_random() use the global RNG and would break replay.
##
## VILLAGER slots are the generic ZombieRunTarget until Story 3.3 brings villagers.

enum Kind { VILLAGER, BRAIN_BLOCK }

var _rng: RandomNumberGenerator
var _group_size: int
var _buffer: Array[Kind] = []


func _init(rng: RandomNumberGenerator, group_size: int) -> void:
	_rng = rng
	_group_size = group_size


## The kind for the next slot. Refills with one shuffled group when the current one is used up.
func next() -> Kind:
	if _buffer.is_empty():
		_buffer = shuffled_group(_rng, _group_size)
		if _buffer.is_empty():
			return Kind.VILLAGER
	return _buffer.pop_front()


## One group: size - 1 villagers and 1 brain block, Fisher-Yates shuffled with `rng`.
static func shuffled_group(rng: RandomNumberGenerator, size: int) -> Array[Kind]:
	var group: Array[Kind] = []
	if size < 1:
		assert(false, "a brain block group needs at least 1 slot")
		return group
	for i: int in size - 1:
		group.append(Kind.VILLAGER)
	group.append(Kind.BRAIN_BLOCK)
	for i: int in range(size - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Kind = group[i]
		group[i] = group[j]
		group[j] = swap
	return group
