extends RefCounted

const METRICS := preload("res://levels/components/SwarmMetrics.gd")

const MILL_LINK_DISTANCE := 240.0
const MILL_MINIMUM_SIZE := 2

var latest: float = -1.0
var latest_mills: int = 0
var _total: float = 0.0
var _samples: int = 0

func reset():
	latest = -1.0
	latest_mills = 0
	_total = 0.0
	_samples = 0

func sample(ships: Array):
	var positions: Array = []
	var headings: Array = []
	for ship in ships:
		if is_instance_valid(ship):
			positions.append(ship.global_position)
			headings.append(ship.rotation)
	var result: Dictionary = METRICS.mill_circliness(positions, headings, MILL_LINK_DISTANCE, MILL_MINIMUM_SIZE)
	latest_mills = result.mills
	if result.mills == 0:
		latest = -1.0
		return
	latest = result.average
	_total += latest
	_samples += 1

func average() -> float:
	if _samples == 0:
		return -1.0
	return _total / float(_samples)
