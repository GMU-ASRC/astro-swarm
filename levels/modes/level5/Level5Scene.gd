extends "res://levels/modes/FARPBase.gd"

const SIM := preload("res://autoloads/SimulationManager.gd")

const OPPONENT_LEVEL := "farp2"
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
	return "farp5"

func _level_title() -> String:
	return "LEVEL 5 - FLY THE EVADER"

func _level_subtitle() -> String:
	return "Drag on the red ring to pick your start point, then LAUNCH and fly the evader to the planet yourself. The defenders run the best submitted Level 2 algorithm."

func _is_evader_role() -> bool:
	return true

func _submit_button_text() -> String:
	return "SUBMIT RUN"

func _uses_workspace() -> bool:
	return false

func _time_limit() -> float:
	return TIME_LIMIT_SECONDS

func _timer_text() -> String:
	return _countdown_text()

func _walkthrough_lines() -> Array:
	return [
		"GOAL: fly the evader to the center planet. Reaching it wins - reaching it without ever being seen is a clean run.",
		"1.  The defenders run the best Level 2 algorithm submitted by another player, standing exactly where that entry placed them. Their name is shown in the top bar.",
		"2.  Drag anywhere on the red ring to choose where your evader starts.",
		"3.  Press LAUNCH EVADER, then fly it yourself. Forward and back drive, left and right turn (WASD or arrow keys, remappable in Settings).",
		"You have %d minutes to reach the planet. The clock in the top right counts down." % int(TIME_LIMIT_SECONDS / 60.0),
		"4.  DETECTION is logged the first time a defender sees you in its vision cone. Being seen does not end the run, but it costs you the clean run.",
		"5.  CAPTURE is a defender physically touching you. That ends the run and you lose.",
		"6.  The GOAL TIME is when you reach the planet. Reach it and you win, and the run pays out a large XP bonus.",
		"Every run is submitted automatically, detected or not, and rendered on the website with your times.",
		"7.  Your run is recorded and rendered on the website, with your detected, captured and goal times.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"Being seen is survivable - being touched is not. A defender that spots you will usually turn and charge.",
		"Watch the cones before you commit. Ring defenders sweep, so gaps open and close on a rhythm.",
		"Approach through a gap between two cones rather than straight down a defender's line of sight.",
		"You turn faster than you accelerate away. Cutting a tight arc around a charging defender beats outrunning it.",
		"The planet is the goal, not the exit. Once you are inside the ring, the shortest line in is usually the safest.",
		"Getting in unseen is the real challenge. A detected run still counts, but a clean run is the one worth flying for.",
		"If a defender locks on, break its line and force it to re-acquire you rather than driving straight ahead.",
	]

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
	_opponent_placements = _placements_from_payload(data.get("placements", []))
	_opponent_label.text = "OPPONENT: " + _opponent_name
	if _phase == Phase.SETUP:
		_clear_ships()
		_placements.clear()
		_place_defenders()
		queue_redraw()

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
	_show_result(title, "%s\n\n%s\n\nThe run is submitted automatically and rendered on the website with your times." % [headline, _event_summary()], not _submitted)

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
	_submit_btn.disabled = true
	_submit_btn.text = "SUBMITTING..."
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
