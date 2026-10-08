extends "res://levels/modes/FARPBase.gd"

const LESSONS := preload("res://levels/modes/level0/TrainingLessons.gd")
const LESSON_PANEL := preload("res://levels/components/LessonPanel.gd")
const CIRCLINESS_TRACKER := preload("res://levels/components/CirclinessTracker.gd")
const BLOCK_FACTORY := preload("res://ui/workspace/BlockFactory.gd")

const DEMO_SPAWN_RADIUS := 750.0
const DEMO_RING_RADIUS := 220.0
const SENSOR_OFFSET := 260.0
const ALLY_IN_CONE := Vector2(180.0, -40.0)
const MILL_SHIPS := 12
const MILL_BAND_MAX := 450.0
const CAMERA_ZOOM := 0.45
const CAMERA_LIFT := 260.0
const EVADER_DEMOS := ["planet", "patrol", "sensor", "sensor_types", "chase"]
const SENSOR_DEMOS := ["sensor", "sensor_types"]

var _lesson_panel
var _demo: String = ""
var _demo_evaders: Array = []
var _watched = null
var _detected_ids: Dictionary = {}
var _detected: int = 0
var _captured: int = 0
var _circliness := CIRCLINESS_TRACKER.new()
var _rng := RandomNumberGenerator.new()

func _level_id() -> String:
	return "farp0"

func _level_title() -> String:
	return "LEVEL 0 - TRAINING"

func _submits_algorithm() -> bool:
	return false

func _uses_workspace() -> bool:
	return false

func _shows_run_controls() -> bool:
	return false

func _shows_hint_text() -> bool:
	return false

func _setup_level():
	_rng.randomize()
	_timer_label.visible = false
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_camera.position = _planet + Vector2(0.0, CAMERA_LIFT)
	_clamp_camera()
	_lesson_panel = LESSON_PANEL.new()
	_lesson_panel.lessons = LESSONS.LESSONS
	_lesson_panel.voice_dir = _voice_dir()
	add_child(_lesson_panel)
	_lesson_panel.step_changed.connect(_on_step)
	_lesson_panel.show_step(0)

func _launch():
	pass

func _restart():
	_start_demo(_demo)

func _on_step(index: int):
	var lesson: Dictionary = LESSONS.LESSONS[index]
	var demo: String = lesson.get("demo", "planet")
	if demo != _demo:
		_start_demo(demo)
	if lesson.has("program"):
		_show_program(LESSONS.program(lesson["program"]))
	if lesson.get("finish", false):
		_show_finish_buttons()

func _show_program(program: Array):
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	_lesson_panel.extra_area().add_child(flow)
	for block in program:
		BLOCK_FACTORY.create_preview(block, flow)

func _show_finish_buttons():
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_lesson_panel.extra_area().add_child(row)
	var workspace := HUD_BUTTONS.make("OPEN WORKSPACE", HUD_BUTTONS.Kind.NEUTRAL, 10)
	workspace.pressed.connect(_open_workspace)
	row.add_child(workspace)
	var first_level := HUD_BUTTONS.make("START LEVEL 1 >", HUD_BUTTONS.Kind.PRIMARY, 10)
	first_level.pressed.connect(func(): _exit_level(LevelInfo.LEVELS[0]["scene"]))
	row.add_child(first_level)

func _start_demo(demo: String):
	_demo = demo
	_clear_ships()
	_placements.clear()
	_clear_demo_evaders()
	_watched = null
	_detected_ids.clear()
	_detected = 0
	_captured = 0
	_circliness.reset()
	match demo:
		"patrol":
			_spawn_ring(LESSONS.PATROL_PROGRAM)
		"sensor":
			_watched = _spawn_demo_defender(_planet + Vector2(SENSOR_OFFSET, 0.0), 0.0, LESSONS.HOLD_PROGRAM)
		"sensor_types":
			_watched = _spawn_demo_defender(_planet + Vector2(SENSOR_OFFSET, 0.0), 0.0, LESSONS.HOLD_PROGRAM)
			_spawn_demo_defender(_planet + Vector2(SENSOR_OFFSET, 0.0) + ALLY_IN_CONE, PI, LESSONS.HOLD_PROGRAM)
		"chase":
			_spawn_ring(LESSONS.CHASE_PROGRAM)
		"mill":
			_spawn_mill()
	_update_count()
	_update_event_label()
	queue_redraw()

func _spawn_demo_defender(spawn_position: Vector2, facing: float, program: Array) -> Node2D:
	_spawn_defender({"pos": spawn_position, "rot": facing}, program)
	var ship: Node2D = _defender_ships.back()
	ship.set_physics_process(true)
	return ship

func _spawn_ring(program: Array):
	for index in 3:
		var angle: float = TAU * float(index) / 3.0
		_spawn_demo_defender(_planet + Vector2(DEMO_RING_RADIUS, 0.0).rotated(angle), angle + PI * 0.5, program)

func _spawn_mill():
	for index in MILL_SHIPS:
		var angle: float = _rng.randf() * TAU
		var radius: float = _rng.randf_range(PLACE_MIN, MILL_BAND_MAX)
		_spawn_demo_defender(_planet + Vector2(radius, 0.0).rotated(angle), _rng.randf() * TAU, LESSONS.MILL_PROGRAM)

func _clear_demo_evaders():
	for evader in _demo_evaders:
		if is_instance_valid(evader):
			evader.queue_free()
	_demo_evaders.clear()

func _spawn_demo_evader():
	var angle: float = 0.0 if SENSOR_DEMOS.has(_demo) else _rng.randf() * TAU
	_demo_evaders.append(_make_scripted_evader(_planet + Vector2(DEMO_SPAWN_RADIUS, 0.0).rotated(angle)))

func _process(delta: float):
	super(delta)
	_update_demo()

func _update_demo():
	var remaining: Array = []
	for evader in _demo_evaders:
		if not is_instance_valid(evader):
			continue
		var id: int = evader.get_instance_id()
		if not _detected_ids.has(id) and _any_defender_sees(evader):
			_detected_ids[id] = true
			_detected += 1
		if _evader_reached_goal(evader) or (_demo == "chase" and _defender_touching(evader) != null):
			if _demo == "chase" and not _evader_reached_goal(evader):
				_captured += 1
			evader.queue_free()
			continue
		remaining.append(evader)
	_demo_evaders = remaining
	if EVADER_DEMOS.has(_demo) and _demo_evaders.is_empty():
		_spawn_demo_evader()
	if is_instance_valid(_watched):
		_watched.ship_color = C_GREEN if _watched.eval_condition("sees_enemy", {}) else C_DEFENDER
	if _demo == "mill":
		_circliness.sample(_defender_ships)
	_update_event_label()

func _update_event_label():
	if _event_label == null:
		return
	match _demo:
		"sensor":
			_event_label.text = "SENSOR   SEES ENEMY: %s" % _yes_no("sees_enemy")
		"sensor_types":
			_event_label.text = "SENSOR   SEES ENEMY: %s   SEES ALLY: %s" % [_yes_no("sees_enemy"), _yes_no("sees_ally")]
		"chase":
			_event_label.text = "DETECTED %d   CAPTURED %d" % [_detected, _captured]
		"mill":
			_event_label.text = "MILLS %d   CIRCLINESS %s" % [_circliness.latest_mills, EVADER_STREAM.circliness_text(_circliness.latest)]
		_:
			_event_label.text = ""

func _yes_no(condition: String) -> String:
	if not is_instance_valid(_watched):
		return "NO"
	return "YES" if _watched.eval_condition(condition, {}) else "NO"

func _draw_level():
	if _demo == "mill":
		_draw_dashed_circle(_planet, MILL_BAND_MAX, Color(0.451, 0.616, 1.0, 0.2), 1.0)
