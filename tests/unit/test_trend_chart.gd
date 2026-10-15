extends GutTest
## TrendChart (Story 10.5): one chalk ColorRect bar per value, bottom-aligned, replaced on each call, never
## focusable or clickable.

const SCENE: PackedScene = preload("res://scenes/ui/trend_chart.tscn")


func _chart() -> TrendChart:
	var chart: TrendChart = SCENE.instantiate() as TrendChart
	add_child_autofree(chart)
	return chart


func _bars(chart: TrendChart) -> Array[ColorRect]:
	var found: Array[ColorRect] = []
	for child: Node in chart.get_node("%Bars").get_children():
		found.append(child as ColorRect)
	return found


func test_values_make_bottom_aligned_bars() -> void:
	var chart: TrendChart = _chart()
	chart.set_title("Accuracy")
	var values: Array[int] = [100, 50, 0, 1]
	chart.show_values(values, 100)
	var area: Control = chart.get_node("%Bars")
	var expected: Array[int] = TrendsCalculator.bar_heights(values, int(area.size.y), 100)
	assert_eq(chart.get_bar_heights(), expected)
	assert_eq(expected, [32, 16, 0, 2] as Array[int])
	var bars: Array[ColorRect] = _bars(chart)
	assert_eq(bars.size(), 4)
	for i: int in bars.size():
		assert_eq(bars[i].size, Vector2(TrendChart.BAR_W, expected[i]), "bar %d size" % i)
		assert_eq(bars[i].position.x, float(i * (TrendChart.BAR_W + TrendChart.BAR_GAP)))
		assert_eq(bars[i].position.y + bars[i].size.y, area.size.y, "bar %d sits on the bottom" % i)
		assert_eq(bars[i].color, TrendChart.CHALK)
	assert_eq((chart.get_node("%Title") as Label).text, "Accuracy")


func test_a_second_call_replaces_the_bars() -> void:
	var chart: TrendChart = _chart()
	chart.show_values([1, 2, 3, 4, 5] as Array[int], 10)
	chart.show_values([7, 8] as Array[int], 10)
	assert_eq(_bars(chart).size(), 2, "old bars are gone at once")
	await wait_process_frames(1)
	assert_eq(_bars(chart).size(), 2)
	assert_eq(chart.get_bar_heights().size(), 2)


func test_empty_values_show_no_bars() -> void:
	var chart: TrendChart = _chart()
	chart.show_values([3] as Array[int], 10)
	chart.show_values([] as Array[int], 10)
	assert_eq(_bars(chart).size(), 0)
	assert_eq(chart.get_bar_heights(), [] as Array[int])


func test_twenty_bars_fit_inside_the_board() -> void:
	var chart: TrendChart = _chart()
	var values: Array[int] = []
	for i: int in 20:
		values.append(i + 1)
	chart.show_values(values, 10)
	var board: Rect2 = (chart.get_node("Board") as Control).get_global_rect()
	var area: Rect2 = (chart.get_node("%Bars") as Control).get_global_rect()
	assert_true(board.encloses(area), "the bar area is inside the board")
	for bar: ColorRect in _bars(chart):
		assert_true(area.encloses(bar.get_global_rect()), "%s inside the bar area" % bar.name)


func test_seven_wide_practice_bars_fit() -> void:
	var chart: TrendChart = _chart()
	chart.show_values([1, 2, 3, 4, 5, 6, 7] as Array[int], 10, 32, 8)
	var area: Rect2 = (chart.get_node("%Bars") as Control).get_global_rect()
	for bar: ColorRect in _bars(chart):
		assert_true(area.encloses(bar.get_global_rect()), "%s inside the bar area" % bar.name)
		assert_eq(bar.size.x, 32.0)


func test_nothing_takes_focus_or_the_mouse() -> void:
	var chart: TrendChart = _chart()
	chart.show_values([5, 6] as Array[int], 10)
	var controls: Array[Control] = [chart, chart.get_node("Board"), chart.get_node("%Bars")]
	for bar: ColorRect in _bars(chart):
		controls.append(bar)
	for control: Control in controls:
		assert_eq(control.focus_mode, Control.FOCUS_NONE, "%s takes no focus" % control.name)
		assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % control.name)
	var title: Label = chart.get_node("%Title")
	assert_eq(title.mouse_filter, Control.MOUSE_FILTER_IGNORE, "a Label ignores the mouse")
