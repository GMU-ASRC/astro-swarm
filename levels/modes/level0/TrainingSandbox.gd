extends Node

signal passed()
signal scored(average_circliness: float)

const CIRCLINESS_TRACKER := preload("res://levels/components/CirclinessTracker.gd")
const EVADER_STREAM := preload("res://levels/components/EvaderStream.gd")
const ROLLING_AVERAGE := preload("res://levels/components/RollingAverage.gd")
const FARP_BASE := preload("res://levels/modes/FARPBase.gd")

const CIRCLINESS_GOAL := 0.5
const AVERAGE_WINDOW_SECONDS := 10.0
const SUBMIT_COOLDOWN_SECONDS := 5.0
const SANDBOX_ZOOM := 0.8
const DRAG_MIN_DISTANCE := 6.0
const PICK_RADIUS := 16.0

var level
var circliness := CIRCLINESS_TRACKER.new()
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var window_average := ROLLING_AVERAGE.new(AVERAGE_WINDOW_SECONDS)
var _passed_this_run: bool = false
var _best_average: float = -1.0
var _best_submitted: float = -1.0
var _since_submit: float = SUBMIT_COOLDOWN_SECONDS
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
	window_average.reset()
	_passed_this_run = false
	_since_submit = SUBMIT_COOLDOWN_SECONDS
	level._start_active()
	level._phase_label.text = "SWARM RUNNING"

func reset():
	flush_score()
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
	window_average.add(maxf(circliness.latest, 0.0), delta)
	_since_submit += delta
	if not window_average.is_full():
		return
	var current_average: float = window_average.average()
	if not _passed_this_run and current_average > CIRCLINESS_GOAL:
		_passed_this_run = true
		passed.emit()
	if current_average > _best_average:
		_best_average = current_average
	if _since_submit >= SUBMIT_COOLDOWN_SECONDS:
		flush_score()

func flush_score():
	if _best_average <= _best_submitted:
		return
	_best_submitted = _best_average
	_since_submit = 0.0
	scored.emit(_best_average)

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
		return "AVERAGE OVER %s CIRCLINESS FOR %dS TO PASS%s" % [
			EVADER_STREAM.circliness_text(CIRCLINESS_GOAL), int(AVERAGE_WINDOW_SECONDS), _best_text()
		]
	return "MILLS %d   CIRCLINESS %s   %dS AVERAGE %s / %s%s" % [
		circliness.latest_mills,
		EVADER_STREAM.circliness_text(circliness.latest),
		int(AVERAGE_WINDOW_SECONDS),
		_window_text(),
		EVADER_STREAM.circliness_text(CIRCLINESS_GOAL),
		_best_text(),
	]

func _window_text() -> String:
	if not window_average.is_full():
		return "IN %dS" % ceili(AVERAGE_WINDOW_SECONDS - window_average.elapsed())
	return EVADER_STREAM.circliness_text(window_average.average())

func _best_text() -> String:
	if _best_average < 0.0:
		return ""
	var text: String = "   BEST %s" % EVADER_STREAM.circliness_text(_best_average)
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
