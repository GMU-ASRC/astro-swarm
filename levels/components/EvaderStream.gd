extends RefCounted

const CIRCLINESS_TRACKER := preload("res://levels/components/CirclinessTracker.gd")

var total: int = 10
var interval: float = 3.0
var spawn_distance: float = 1000.0
var start_delay: float = 0.0
var tracks_circliness: bool = true
var wins_by_capture: bool = false

var spawned: int = 0
var detected: int = 0
var captured: int = 0
var breached: int = 0
var circliness := CIRCLINESS_TRACKER.new()

var _level
var _evaders: Array = []
var _spawn_timer: float = 0.0
var _detected_ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init(level):
	_level = level
	_rng.randomize()

func reset():
	clear()
	spawned = 0
	detected = 0
	captured = 0
	breached = 0
	_detected_ids.clear()
	circliness.reset()
	_spawn_timer = start_delay

func start():
	reset()
	if start_delay <= 0.0:
		_spawn_next()

func update(delta: float):
	_spawn_timer -= delta
	if spawned < total and _spawn_timer <= 0.0:
		_spawn_next()
	_resolve()
	if tracks_circliness:
		circliness.sample(_level._defender_ships)

func is_finished() -> bool:
	return spawned >= total and _evaders.is_empty()

func waiting_seconds() -> float:
	return maxf(0.0, _spawn_timer) if spawned == 0 else 0.0

func freeze():
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.set_physics_process(false)

func clear():
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.queue_free()
	_evaders.clear()

func _spawn_next():
	var angle: float = _rng.randf() * TAU
	var spawn_position: Vector2 = _level._planet + Vector2(spawn_distance, 0.0).rotated(angle)
	_evaders.append(_level._make_scripted_evader(spawn_position))
	spawned += 1
	_spawn_timer = interval

func _resolve():
	var remaining: Array = []
	for evader in _evaders:
		if not is_instance_valid(evader):
			continue
		if not _detected_ids.has(evader.get_instance_id()) and _level._any_defender_sees(evader):
			_detected_ids[evader.get_instance_id()] = true
			detected += 1
			if _level._detect_time < 0.0:
				_level._detect_time = _level._elapsed
			if not wins_by_capture:
				evader.queue_free()
				continue
		if wins_by_capture and _level._defender_touching(evader) != null:
			captured += 1
			if _level._capture_time < 0.0:
				_level._capture_time = _level._elapsed
			evader.queue_free()
		elif _level._evader_reached_goal(evader):
			breached += 1
			if _level._goal_time < 0.0:
				_level._goal_time = _level._elapsed
			evader.queue_free()
		else:
			remaining.append(evader)
	_evaders = remaining

func outcome(reason: String) -> Dictionary:
	var held: bool = breached == 0 and reason == "cleared"
	var title: String = "PLANET DEFENDED" if held else "PLANET BREACHED"
	var headline: String = "Your defenders %s all %d evaders before they reached the planet." % ["captured" if wins_by_capture else "spotted", total]
	if reason == "timeout":
		title = "OUT OF TIME"
		headline = "The clock ran out with %d evaders still inbound." % (_evaders.size() + total - spawned)
	elif not held:
		headline = "%d of the %d evaders reached the planet%s." % [breached, total, "" if wins_by_capture else " without being spotted"]
	return {"held": held, "title": title, "headline": headline}

func summary_text(first_detection: String, first_capture: String) -> String:
	var text: String = "Evaders detected: %d of %d" % [detected, total]
	if wins_by_capture:
		text += "\nEvaders captured: %d of %d" % [captured, total]
	text += "\nEvaders that reached the planet: %d\nFirst detection: %s" % [breached, first_detection]
	if wins_by_capture:
		text += "\nFirst capture: %s" % first_capture
	if tracks_circliness:
		text += "\nAverage circliness: %s" % circliness_text(circliness.average())
	return text

func event_label_text() -> String:
	var waiting: float = waiting_seconds()
	var text: String = "FIRST EVADER IN %ds" % ceili(waiting) if waiting > 0.0 else _progress_text()
	if tracks_circliness:
		text += "   CIRCLINESS %s" % circliness_text(circliness.latest)
		if circliness.latest_mills > 1:
			text += " (%d MILLS)" % circliness.latest_mills
	return text

func _progress_text() -> String:
	if wins_by_capture:
		return "DETECTED %d/%d   CAPTURED %d/%d   THROUGH %d" % [detected, total, captured, total, breached]
	return "DETECTED %d/%d   THROUGH %d" % [detected, total, breached]

static func circliness_text(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.3f" % value
