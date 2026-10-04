extends GutTest
## TargetSource base (Story 2.2): safe no-op defaults.


func test_base_defaults_are_safe_no_ops() -> void:
	var source: TargetSource = TargetSource.new()
	assert_eq(source.peek(3), [] as Array[String])
	assert_eq(source.current(), "")
	source.advance()
	assert_eq(source.current(), "")


func test_letter_bag_overrides_all_three() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var pool: Array[String] = ["a", "b", "c"]
	var source: TargetSource = LetterBagSource.new(rng, pool)
	assert_ne(source.current(), "")
	assert_eq(source.peek(2).size(), 2)
	var first: String = source.current()
	source.advance()
	assert_ne(source.current(), first)
