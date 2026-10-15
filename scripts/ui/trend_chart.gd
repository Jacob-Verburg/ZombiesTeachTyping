class_name TrendChart
extends Control
## One Progress-screen bar chart (Story 10.5, DESIGN.md "Trend chart"): a Chalkboard panel, a chalk-dim
## title and chalk bars. Each bar is a palette ColorRect (no draw calls, no outline, no numbers), whole
## pixels, bottom-aligned in %Bars; heights come from TrendsCalculator.bar_heights. Nothing in it takes
## focus or the mouse.

## Look value, not a GDD number: the bar colour (palette chalk).
const CHALK: Color = Color("#F4F1E4")
## Look value, not a GDD number: the default bar width and gap (20 bars fill the 316 px bar area).
const BAR_W: int = 12
const BAR_GAP: int = 4

var _heights: Array[int] = []

@onready var _title: Label = %Title
@onready var _bars: Control = %Bars


func set_title(text: String) -> void:
	_title.text = text


## Replaces the bars with one per value, left to right, scaled against max(values, scale_floor).
func show_values(values: Array[int], scale_floor: int, bar_w: int = BAR_W, gap: int = BAR_GAP) -> void:
	for old: Node in _bars.get_children():
		_bars.remove_child(old)
		old.queue_free()
	var area_h: int = floori(_bars.size.y)
	_heights = TrendsCalculator.bar_heights(values, area_h, scale_floor)
	for i: int in _heights.size():
		var bar: ColorRect = ColorRect.new()
		bar.name = "Bar%d" % i
		bar.color = CHALK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.focus_mode = Control.FOCUS_NONE
		bar.position = Vector2(i * (bar_w + gap), area_h - _heights[i])
		bar.size = Vector2(bar_w, _heights[i])
		_bars.add_child(bar)


## The heights shown by the last show_values call (for tests).
func get_bar_heights() -> Array[int]:
	return _heights.duplicate()
