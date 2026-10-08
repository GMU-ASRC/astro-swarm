extends "res://levels/modes/FARPBase.gd"

const SIM := preload("res://autoloads/SimulationManager.gd")

const OPPONENT_LEVEL := "farp2"
const OPPONENT_LEVEL_SCRIPT := preload("res://levels/modes/level2/Level2Scene.gd")
const HOUSE_OPPONENT := "House Algorithm"

const EVADER_PLAYER_SPEED := 150.0
const EVADER_TURN_RATE    := 2.8

const TIME_LIMIT_SECONDS := 180.0
const RECORD_FPS         := 30.0

var _frames: Array = []
var _record_accum: float = 0.0

var _rng := RandomNumberGenerator.new()
var _opponent_name: String = HOUSE_OPPONENT
var _opponent_algorithm: Array = []
var _opponent_placements: Array = []
var _opponent_label: Label
var _evader_spawn: Vector2 = Vector2.ZERO
var _dragging: bool = false

func _level_id() -> String:
	return "farp6"

func _level_title() -> String:
	return "LEVEL 6 - FLY THE EVADER"

func _level_subtitle() -> String:
	return "Drag on the red ring to pick your start point, then LAUNCH and fly the evader to the planet yourself. The defenders run the best submitted Level 2 algorithm."

func _is_evader_role() -> bool:
	return true

func _uses_workspace() -> bool:
	return false

func _time_limit() -> float:
	return TIME_LIMIT_SECONDS

func _timer_text() -> String:
	return _countdown_text()

func _setup_level():
	_rng.randomize()
	_opponent_algorithm = SIM.normalize_to_scripts(HOUSE_DEFENDER_ALGORITHM)
	_launch_btn.text = "LAUNCH EVADER (S) >"
	_opponent_label = _lbl("OPPONENT: loading...", 11, C_AMBER)
	_top_bar.add_child(_opponent_label)
	_evader_spawn = _planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(_rng.randf() * TAU)
	_place_defenders()
	if not EvalUploader.best_fetched.is_connected(_on_best_fetched):
		EvalUploader.best_fetched.connect(_on_best_fetched)
	EvalUploader.fetch_best(OPPONENT_LEVEL)

func _restart_level():
	_place_defenders()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()
	_launch_btn.text = "LAUNCH EVADER (S) >"

func _place_defenders():
	var layout: Array = _opponent_placements if not _opponent_placements.is_empty() else _house_ring_placements(RING_COUNT)
	for placement in layout:
		_placements.append(placement)
		_spawn_defender(placement, _opponent_algorithm)
	_update_count()

func _on_best_fetched(success: bool, data):
	if not success or typeof(data) != TYPE_DICTIONARY or not data.has("algorithm"):
		_opponent_label.text = "OPPONENT: " + HOUSE_OPPONENT
		return
	_opponent_name = str(data.get("username", HOUSE_OPPONENT))
	_opponent_algorithm = SIM.normalize_to_scripts(data["algorithm"])
	_opponent_placements = _centered_on_planet(_placements_from_payload(data.get("placements", [])))
	_opponent_label.text = "OPPONENT: " + _opponent_name
	if _phase == Phase.SETUP:
		_clear_ships()
		_placements.clear()
		_place_defenders()
		queue_redraw()

func _centered_on_planet(placements: Array) -> Array:
	if placements.is_empty():
		return placements
	var centroid := Vector2.ZERO
	for placement in placements:
		centroid += placement.pos
	centroid /= float(placements.size())
	var opponent_center: Vector2 = OPPONENT_LEVEL_SCRIPT.LEVEL_ARENA * 0.5
	var source_center: Vector2 = opponent_center if centroid.distance_to(opponent_center) < centroid.distance_to(PLANET_CENTER) else PLANET_CENTER
	var offset: Vector2 = _planet - source_center
	var centered: Array = []
	for placement in placements:
		centered.append({"pos": placement.pos + offset, "rot": placement.rot})
	return centered

func _launch():
	_start_active()
	_spawn_player_evader()
	_frames = []
	_record_accum = 0.0
	_frames.append(_snapshot())
	_phase_label.text = "FLY TO THE PLANET"
	_hint_label.text = "Forward and back drive, left and right turn. Stay out of reach of the defenders."

func _spawn_player_evader():
	_evader = SHIP.instantiate()
	_evader.setup_raider([], EVADER_HP)
	_evader.ship_color = C_EVADER
	_evader.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	_evader.collisions_enabled = false
	_evader.is_evader = true
	_evader.arena_size = _arena
	_evader.show_health = false
	add_child(_evader)
	_evader.global_position = _evader_spawn
	_evader.rotation = (_planet - _evader_spawn).angle()
	_evader.set_physics_process(false)

func _update_level(delta: float):
	if not is_instance_valid(_evader):
		return
	_drive_with_keys(_evader, delta, EVADER_PLAYER_SPEED, EVADER_TURN_RATE)
	_record(delta)
	_update_countdown_color()

func _record(delta: float):
	_record_accum += delta
	var step: float = 1.0 / RECORD_FPS
	while _record_accum >= step:
		_record_accum -= step
		_frames.append(_snapshot())

func _snapshot() -> Array:
	var frame: Array = []
	for ship in _defender_ships:
		if is_instance_valid(ship):
			frame.append(int(ship.global_position.x))
			frame.append(int(ship.global_position.y))
			frame.append(int(rad_to_deg(ship.rotation)))
		else:
			frame.append(0)
			frame.append(0)
			frame.append(0)
	if is_instance_valid(_evader):
		frame.append(int(_evader.global_position.x))
		frame.append(int(_evader.global_position.y))
		frame.append(int(rad_to_deg(_evader.rotation)))
	else:
		frame.append(-1)
		frame.append(-1)
		frame.append(0)
	return frame

func _finish(reason: String):
	if is_instance_valid(_evader):
		_frames.append(_snapshot())
	super(reason)

func _show_outcome(reason: String):
	var title: String
	var headline: String
	match reason:
		"goal":
			if _detect_time < 0.0:
				title = "CLEAN RUN"
				headline = "You reached the planet and no defender ever saw you."
			else:
				title = "PLANET REACHED"
				headline = "You reached the planet, but a defender spotted you at %s. Fly it again to go undetected." % _time_text(_detect_time)
			_phase_label.text = title
			_phase_label.add_theme_color_override("font_color", C_GREEN)
		"capture":
			title = "EVADER CAUGHT"
			headline = "A defender caught you before you reached the planet."
			_phase_label.text = title
			_phase_label.add_theme_color_override("font_color", C_RED)
		_:
			title = "OUT OF TIME"
			headline = "The clock ran out before you reached the planet."
			_phase_label.text = title
			_phase_label.add_theme_color_override("font_color", C_RED)
	_show_result(reason == "goal", title, headline)

func _outcome() -> String:
	match _end_reason:
		"goal":    return "win"
		"capture": return "lose"
	return "timeout"

func _view_distance() -> float:
	for ship in _defender_ships:
		if is_instance_valid(ship):
			return ship.view_distance
	return 300.0

func _fov_degrees() -> float:
	for ship in _defender_ships:
		if is_instance_valid(ship):
			return ship.fov_degrees
	return 70.0

func _submit_entry():
	if _submitted:
		return
	_submitted = true
	if not EvalUploader.submit_finished.is_connected(_on_submit_finished):
		EvalUploader.submit_finished.connect(_on_submit_finished)
	var run := {
		"outcome": _outcome(),
		"detection_time": snappedf(_detect_time, 0.01),
		"capture_time": snappedf(_capture_time, 0.01),
		"goal_time": snappedf(_goal_time, 0.01),
		"fps": int(RECORD_FPS),
		"defenders": _placements.size(),
		"view": int(_view_distance()),
		"fov": int(_fov_degrees()),
		"planet": [int(_planet.x), int(_planet.y), int(PLANET_RADIUS)],
		"arena": [int(_arena.x), int(_arena.y)],
		"frames": _frames,
		"opponent": _opponent_name,
	}
	EvalUploader.submit_run(_level_id(), _opponent_algorithm, _placements_payload(), run)

func _level_input(event: InputEvent):
	if _phase != Phase.SETUP:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_spawn_from_mouse()
	elif event is InputEventMouseMotion and _dragging:
		_set_spawn_from_mouse()

func _set_spawn_from_mouse():
	var angle: float = (get_global_mouse_position() - _planet).angle()
	_evader_spawn = _planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(angle)
	queue_redraw()

func _draw_level():
	if _phase != Phase.SETUP:
		return
	_draw_dashed_circle(_planet, EVADER_SPAWN_RADIUS, Color(C_RED.r, C_RED.g, C_RED.b, 0.6), 1.5)
	draw_line(_evader_spawn, _planet, Color(1.0, 0.70, 0.20, 0.15), 1.0, true)
	draw_circle(_evader_spawn, 12.0, C_AMBER)
