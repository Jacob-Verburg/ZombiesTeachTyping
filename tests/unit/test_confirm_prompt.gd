extends GutTest
## ConfirmPrompt (Story 4.4): open() shows the question and focuses Yes, Yes / No / cancel() answer once and
## close, focus is trapped on the pair, it is hidden by default and never handles Esc itself.

const PromptScene: PackedScene = preload("res://scenes/ui/confirm_prompt.tscn")

var _answers: Array[bool] = []


func before_each() -> void:
	_answers = []


func _prompt() -> ConfirmPrompt:
	var prompt: ConfirmPrompt = PromptScene.instantiate() as ConfirmPrompt
	prompt.process_mode = Node.PROCESS_MODE_DISABLED
	prompt.answer_delay_ms = 0
	prompt.answered.connect(func(yes: bool) -> void: _answers.append(yes))
	add_child_autofree(prompt)
	return prompt


func _button(prompt: ConfirmPrompt, path: String) -> Button:
	return prompt.get_node(path) as Button


func _neighbor(from: Control, side: Side) -> Node:
	return from.get_node_or_null(from.get_focus_neighbor(side))


func test_hidden_until_open() -> void:
	var prompt: ConfirmPrompt = _prompt()
	assert_false(prompt.visible)
	assert_false(prompt.is_open())


func test_open_shows_the_question_and_focuses_yes() -> void:
	var prompt: ConfirmPrompt = _prompt()
	prompt.open("Buy the Pumpkin hat for 100 brains?")
	assert_true(prompt.visible)
	assert_true(prompt.is_open())
	assert_eq((prompt.get_node("%QuestionLabel") as Label).text, "Buy the Pumpkin hat for 100 brains?")
	assert_true(_button(prompt, "%YesButton").has_focus())
	assert_eq(_button(prompt, "%YesButton").text, "Yes")
	assert_eq(_button(prompt, "%NoButton").text, "No")


func test_yes_answers_true_once_and_closes() -> void:
	var prompt: ConfirmPrompt = _prompt()
	prompt.open("?")
	_button(prompt, "%YesButton").pressed.emit()
	_button(prompt, "%YesButton").pressed.emit()
	assert_eq(_answers, [true] as Array[bool])
	assert_false(prompt.visible)
	assert_false(prompt.is_open())


func test_no_and_cancel_answer_false() -> void:
	var prompt: ConfirmPrompt = _prompt()
	prompt.open("?")
	_button(prompt, "%NoButton").pressed.emit()
	prompt.open("?")
	prompt.cancel()
	prompt.cancel()
	assert_eq(_answers, [false, false] as Array[bool])
	assert_false(prompt.is_open())


func test_close_answers_nothing() -> void:
	var prompt: ConfirmPrompt = _prompt()
	prompt.open("?")
	prompt.close()
	assert_eq(_answers, [] as Array[bool])
	assert_false(prompt.visible)


func test_focus_is_trapped_on_yes_and_no() -> void:
	var prompt: ConfirmPrompt = _prompt()
	var yes: Button = _button(prompt, "%YesButton")
	var no: Button = _button(prompt, "%NoButton")
	assert_eq(_neighbor(yes, SIDE_RIGHT), no)
	assert_eq(_neighbor(no, SIDE_LEFT), yes)
	assert_eq(_neighbor(yes, SIDE_LEFT), yes)
	assert_eq(_neighbor(no, SIDE_RIGHT), no)
	for button: Button in [yes, no]:
		assert_eq(_neighbor(button, SIDE_TOP), button)
		assert_eq(_neighbor(button, SIDE_BOTTOM), button)
	assert_eq(yes.get_node(yes.focus_next), no)
	assert_eq(yes.get_node(yes.focus_previous), no)
	assert_eq(no.get_node(no.focus_next), yes)
	assert_eq(no.get_node(no.focus_previous), yes)


func test_esc_is_not_handled_here() -> void:
	var prompt: ConfirmPrompt = _prompt()
	var names: Array = prompt.get_script().get_script_method_list().map(func(method: Dictionary) -> String: return method["name"])
	assert_false(names.has("_unhandled_input"), "the owner routes Esc")
	assert_false(names.has("_input"), "the owner routes Esc")
	assert_false(names.has("_unhandled_key_input"), "the owner routes Esc")


func test_presses_right_after_open_are_ignored() -> void:
	var prompt: ConfirmPrompt = _prompt()
	prompt.answer_delay_ms = 60000
	prompt.open("?")
	_button(prompt, "%YesButton").pressed.emit()
	_button(prompt, "%NoButton").pressed.emit()
	assert_eq(_answers, [], "a double-tap cannot answer")
	assert_true(prompt.is_open())
	prompt.cancel()
	assert_eq(_answers, [false], "Esc still answers at once")


func test_decor_ignores_the_mouse_and_the_scrim_stops_it() -> void:
	var prompt: ConfirmPrompt = _prompt()
	assert_eq(prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq((prompt.get_node("%Scrim") as Control).mouse_filter, Control.MOUSE_FILTER_STOP)
	for path: String in ["%Panel", "%Sign", "%QuestionLabel"]:
		assert_eq((prompt.get_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, path)
		assert_eq((prompt.get_node(path) as Control).focus_mode, Control.FOCUS_NONE, path)
