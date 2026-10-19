extends Node

signal passed()
signal scored(average_circliness: float)

const CIRCLINESS_TRACKER := preload("res://levels/components/CirclinessTracker.gd")
const EVADER_STREAM := preload("res://levels/components/EvaderStream.gd")
const FARP_BASE := preload("res://levels/modes/FARPBase.gd")

const CIRCLINESS_GOAL := 0.5
const PASS_HOLD_SECONDS := 2.0
const SCORE_WINDOW_SECONDS := 30.0
const SANDBOX_ZOOM := 0.8
const DRAG_MIN_DISTANCE := 6.0
const PICK_RADIUS := 16.0

var level
var circliness := CIRCLINESS_TRACKER.new()
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _time_above_goal: float = 0.0
var _passed_this_run: bool = false
var _run_seconds: float = 0.0
var _scored_this_run: bool = false
var _last_score: float = -1.0
var upload_note: String = ""

func start():
	level._camera.zoom = Vector2(SANDBOX_ZOOM, SANDBOX_ZOOM)
	level._camera.position = level._planet
	level._clamp_camera()
	level._launch_btn.text = "RUN SWARM (S) >"
	level._launch_btn.visible = true
	restore_placements()

func restore_placements():
	for placement in level._placements_from_payload(PlayerData.get_level_placements(level._level_id())):
		if can_place(placement.pos) and level._placements.size() < FARP_BASE.MAX_DEFENDERS:
			level._placements.append(placement)
			level._spawn_defender(placement, PlayerData.ship_blocks)
	level._update_count()

func save_placements():
	PlayerData.set_level_placements(level._level_id(), level._placements_payload())

func launch():
	if level._placements.size() < FARP_BASE.MIN_DEFENDERS:
		level._phase_label.text = "PLACE AT LEAST %d DEFENDER FIRST" % FARP_BASE.MIN_DEFENDERS
		return
	save_placements()
	circliness.reset()
	_time_above_goal = 0.0
	_passed_this_run = false
	_run_seconds = 0.0
	_scored_this_run = false
	_last_score = -1.0
	upload_note = ""
	level._start_active()
	level._phase_label.text = "SWARM RUNNING"

func reset():
	level._clear_ships()
	level._placements.clear()
	level._phase = FARP_BASE.Phase.SETUP
	level._elapsed = 0.0
	level._launch_btn.visible = true
	level._launch_program = []
	circliness.reset()
	level._phase_label.text = level._level_title()
	level._phase_label.add_theme_color_override("font_color", FARP_BASE.ACCENT)
	restore_placements()
	level.queue_redraw()

func clear_defenders():
	if level._phase != FARP_BASE.Phase.SETUP:
		return
	level._clear_ships()
	level._placements.clear()
	save_placements()
	level._update_count()
	level.queue_redraw()

func update(delta: float):
	if level._phase != FARP_BASE.Phase.ACTIVE:
		return
	circliness.sample(level._defender_ships)
	if circliness.latest >= CIRCLINESS_GOAL:
		_time_above_goal += delta
	else:
		_time_above_goal = 0.0
	if not _passed_this_run and _time_above_goal >= PASS_HOLD_SECONDS:
		_passed_this_run = true
		passed.emit()
	_run_seconds += delta
	if not _scored_this_run and _run_seconds >= SCORE_WINDOW_SECONDS:
		_scored_this_run = true
		_last_score = circliness.average()
		if _last_score >= 0.0:
			scored.emit(_last_score)

func handle_input(event: InputEvent):
	if level._phase != FARP_BASE.Phase.SETUP:
		return
	var mouse_position: Vector2 = level.get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_remove_defender_at(mouse_position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if can_place(mouse_position) and level._placements.size() < FARP_BASE.MAX_DEFENDERS:
				_dragging = true
				_drag_start = mouse_position
				level._drag_indicator.update_drag(true, "arrow", mouse_position, mouse_position, FARP_BASE.ACCENT)
		elif _dragging:
			_dragging = false
			level._drag_indicator.update_drag(false)
			_place_defender(_drag_start, mouse_position)
	elif event is InputEventMouseMotion and _dragging:
		level._drag_indicator.update_drag(true, "arrow", _drag_start, mouse_position, FARP_BASE.ACCENT)

func can_place(world_position: Vector2) -> bool:
	var distance: float = world_position.distance_to(level._planet)
	return distance >= FARP_BASE.PLACE_MIN and distance <= FARP_BASE.SCATTER_MAX

func count_text() -> String:
	return "DEFENDERS: %d / %d" % [level._placements.size(), FARP_BASE.MAX_DEFENDERS]

func status_text() -> String:
	if level._phase != FARP_BASE.Phase.ACTIVE:
		return "REACH %s CIRCLINESS TO PASS TRAINING" % EVADER_STREAM.circliness_text(CIRCLINESS_GOAL)
	return "MILLS %d   CIRCLINESS %s / %s   %s" % [
		circliness.latest_mills, EVADER_STREAM.circliness_text(circliness.latest), EVADER_STREAM.circliness_text(CIRCLINESS_GOAL), _score_text()
	]

func _score_text() -> String:
	if not _scored_this_run:
		return "SCORE IN %dS" % ceili(SCORE_WINDOW_SECONDS - _run_seconds)
	var text: String = "%dS SCORE %s" % [int(SCORE_WINDOW_SECONDS), EVADER_STREAM.circliness_text(_last_score)]
	if upload_note != "":
		text += "   " + upload_note
	return text

func draw():
	if level._phase != FARP_BASE.Phase.SETUP:
		return
	level.draw_circle(level._planet, FARP_BASE.SCATTER_MAX, FARP_BASE.ZONE_FILL)
	level._draw_dashed_circle(level._planet, FARP_BASE.SCATTER_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	level._draw_dashed_circle(level._planet, FARP_BASE.PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)

func _place_defender(start: Vector2, end: Vector2):
	if level._placements.size() >= FARP_BASE.MAX_DEFENDERS:
		return
	var facing: float = start.angle_to_point(end) if start.distance_to(end) > DRAG_MIN_DISTANCE else 0.0
	var placement := {"pos": start, "rot": facing}
	level._placements.append(placement)
	level._spawn_defender(placement, PlayerData.ship_blocks)
	save_placements()
	level._update_count()
	level.queue_redraw()

func _remove_defender_at(world_position: Vector2):
	for ship in level._defender_ships:
		if is_instance_valid(ship) and ship.global_position.distance_to(world_position) <= PICK_RADIUS:
			level._placements.erase(ship.get_meta("placement"))
			level._defender_ships.erase(ship)
			ship.queue_free()
			save_placements()
			level._update_count()
			level.queue_redraw()
			return
