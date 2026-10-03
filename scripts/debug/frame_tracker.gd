class_name FrameTracker
extends RefCounted
## Frame times over a sliding window, for the debug overlay (Story 1.8): the last frame and the worst
## frame in the last WINDOW_SEC. Time is passed in, so it is pure and deterministic in tests.
## Debug code (Boundary 7): only the debug overlay uses it.

## "Worst frame in the last 10 s" (debug overlay), not a balance number.
const WINDOW_SEC: float = 10.0

var _times: PackedFloat64Array = []
var _frames_ms: PackedFloat64Array = []
## Index of the oldest entry still in the window; the arrays are compacted once it passes half.
var _start: int = 0


func record(now_sec: float, frame_ms: float) -> void:
	_times.append(now_sec)
	_frames_ms.append(frame_ms)
	var oldest: float = now_sec - WINDOW_SEC
	while _start < _times.size() and _times[_start] < oldest:
		_start += 1
	if _start > 0 and _start * 2 >= _times.size():
		_times = _times.slice(_start)
		_frames_ms = _frames_ms.slice(_start)
		_start = 0


## 0.0 when nothing is recorded.
func worst_ms() -> float:
	var worst: float = 0.0
	for i: int in range(_start, _frames_ms.size()):
		worst = maxf(worst, _frames_ms[i])
	return worst


## 0.0 when nothing is recorded.
func last_ms() -> float:
	if size() == 0:
		return 0.0
	return _frames_ms[_frames_ms.size() - 1]


func size() -> int:
	return _times.size() - _start


func clear() -> void:
	_times.clear()
	_frames_ms.clear()
	_start = 0
