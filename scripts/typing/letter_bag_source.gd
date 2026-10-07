class_name LetterBagSource
extends TargetSource
## Deals targets in "bags": every entry of the pool once per bag, never the same entry twice in a
## row (also across bag boundaries). Uses only the injected RandomNumberGenerator, so the same seed
## and pool always give the same sequence. The pool is a list of unique strings supplied by the
## caller (at least 2): single letters for Zombie Run, whole words through WordSource (Story 6.2).
## Nothing in the logic depends on the entries being one character long.

var _rng: RandomNumberGenerator
var _pool: Array[String] = []
## Already dealt, not yet consumed. Index 0 is current().
var _queue: Array[String] = []
## Letters still to deal from the current bag.
var _bag: Array[String] = []
## Last letter placed in _queue, for the bag-boundary rule.
var _last: String = ""


func _init(rng: RandomNumberGenerator, pool: Array[String]) -> void:
	assert(rng != null, "LetterBagSource needs an injected RandomNumberGenerator")
	assert(pool.size() >= 2, "LetterBagSource needs a pool of at least 2 letters")
	assert(_has_no_duplicates(pool), "LetterBagSource pool must not contain duplicates")
	if rng == null or pool.size() < 2 or not _has_no_duplicates(pool):
		Log.error(&"typing", "LetterBagSource built with an invalid rng or pool; it will stay empty")
		return
	_rng = rng
	_pool = pool.duplicate()


func peek(n: int) -> Array[String]:
	var out: Array[String] = []
	if n <= 0:
		return out
	_ensure(n + 1)
	for i: int in range(1, mini(n + 1, _queue.size())):
		out.append(_queue[i])
	return out


func current() -> String:
	_ensure(1)
	return _queue[0] if not _queue.is_empty() else ""


func advance() -> void:
	_ensure(1)
	if _queue.is_empty():
		return
	_queue.remove_at(0)
	_ensure(1)


func _ensure(count: int) -> void:
	if _pool.is_empty():
		return
	while _queue.size() < count:
		if _bag.is_empty():
			_deal_bag()
		var letter: String = _bag.pop_front()
		_queue.append(letter)
		_last = letter


## Fisher-Yates with the injected RNG (the built-in array shuffle uses the global RNG).
func _deal_bag() -> void:
	_bag = _pool.duplicate()
	for i: int in range(_bag.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: String = _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = swap
	# Bag-boundary rule: swap with a random later slot (not always the last one, which would make
	# the previous bag's last letter end this bag too). Letters are unique, so _bag[k] != _last.
	if _bag[0] == _last:
		var k: int = _rng.randi_range(1, _bag.size() - 1)
		var first: String = _bag[0]
		_bag[0] = _bag[k]
		_bag[k] = first


static func _has_no_duplicates(pool: Array[String]) -> bool:
	for i: int in pool.size():
		if pool.find(pool[i]) != i:
			return false
	return true
