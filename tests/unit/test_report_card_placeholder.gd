extends GutTest
## Placeholder report card (Story 2.4): shows a RunResult's stats. Story 2.9 builds the real one.
## Disabled instance; buttons are never pressed (they would call the live Router).

const ReportScene: PackedScene = preload("res://scenes/screens/report_card.tscn")


func after_each() -> void:
	Router.take_payload()


func _card(payload: Dictionary) -> Control:
	Router._store_payload(payload)
	var card: Control = ReportScene.instantiate() as Control
	card.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(card)
	return card


func _text(card: Control) -> String:
	return (card.get_node("%PayloadLabel") as Label).text


func test_shows_result_stats() -> void:
	var result: RunResult = RunResult.create(
		&"test_level", 1790000000, 120.0, 100, 5, {}, 30, 0, "all", GameConstants.END_REASON_TIMER)
	var text: String = _text(_card({"result": result}))
	assert_string_contains(text, "Keys Typed: 100")
	assert_string_contains(text, "Errors: 5")
	assert_string_contains(text, "WPM: 10")
	assert_string_contains(text, "Accuracy: 95%")
	assert_string_contains(text, "Lesson Time: 2:00")
	assert_string_contains(text, "Brains: 30")
	assert_eq(Router.take_payload(), {}, "payload consumed")


func test_no_result_keeps_the_placeholder_text() -> void:
	assert_eq(_text(_card({})), "")
	assert_false(_text(_card({"result": null})).contains("WPM"))
