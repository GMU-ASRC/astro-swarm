extends "res://levels/modes/ScatterBase.gd"

const EVADERS_PER_DEFENDER := 2
const BASE_DEFENDERS := 5
const BASE_SPAWN_INTERVAL := 3.0
const FIRST_EVADER_DELAY := 10.0
const SCENE_SCALE := 1.5
const LEVEL_ARENA := ARENA * SCENE_SCALE

func _level_id() -> String:
	return "farp2"

func _arena_size() -> Vector2:
	return LEVEL_ARENA

func _planet_center() -> Vector2:
	return LEVEL_ARENA * 0.5

func _level_title() -> String:
	return "LEVEL 2 - PROGRAM THE SCATTER"

func _defender_options() -> Array:
	return DEFENDER_COUNT_OPTIONS

func _setup_level():
	_use_evader_stream(_evader_total(), _spawn_interval(), FIRST_EVADER_DELAY)
	_stream.wins_by_capture = true
	_stream.wins_by_majority = true
	super()
	_scale_stream()

func _reroll_level():
	super()
	_scale_stream()

func _evader_total() -> int:
	return EVADERS_PER_DEFENDER * _defender_count

func _spawn_interval() -> float:
	return BASE_SPAWN_INTERVAL * float(BASE_DEFENDERS) / float(_defender_count)

func _scale_stream():
	_stream.total = _evader_total()
	_stream.interval = _spawn_interval()
	_update_event_label()

func _launch_label() -> String:
	return "LAUNCH EVADERS (S) >"

func _launch():
	_scale_stream()
	_start_active()
	_stream.start()
	_phase_label.text = "EVADERS INCOMING"
