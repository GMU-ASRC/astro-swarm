extends RefCounted

var window_seconds: float = 10.0
var _samples: Array = []
var _total: float = 0.0
var _elapsed: float = 0.0

func _init(seconds: float = 10.0):
	window_seconds = seconds

func reset():
	_samples.clear()
	_total = 0.0
	_elapsed = 0.0

func add(value: float, delta: float):
	_elapsed += delta
	_samples.append(Vector2(_elapsed, value))
	_total += value
	while not _samples.is_empty() and _samples[0].x <= _elapsed - window_seconds:
		_total -= _samples.pop_front().y

func is_full() -> bool:
	return _elapsed >= window_seconds

func elapsed() -> float:
	return _elapsed

func average() -> float:
	if _samples.is_empty():
		return 0.0
	return _total / float(_samples.size())
