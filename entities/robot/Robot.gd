extends CharacterBody2D

@export var type_id: String = "hunter"
@export var dot_radius: float = 6.0
var robot_name: String = ""
var spawn_id: int = -1

var forward_input: float = 1.0
var turn_input: float = 0.0
var is_controlled: bool = false
var controller_index: int = -1
var _color: Color
const STICK_DEADZONE := 0.18

var trail_enabled: bool = false
var pin_coords: bool = false
var _trail_points: PackedVector2Array = PackedVector2Array()
var _trail_color: Color = Color(1, 1, 1, 0.6)
const TRAIL_MIN_DIST := 4.0
const TRAIL_MAX_POINTS := 4096

static var _trail_counter: int = 0

signal clicked(robot)
signal release_requested(robot)

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 1
	collision_mask = 1
	_color = SimulationManager.get_type(type_id).color
	add_to_group("robots")
	add_to_group("type_" + type_id)
	turn_input = randf_range(-1.0, 1.0)
	_apply_type_config()
	SimulationManager.type_config_changed.connect(_on_type_config_changed)
	if has_node("ClickArea"):
		$ClickArea.process_mode = Node.PROCESS_MODE_ALWAYS
		$ClickArea.input_event.connect(_on_click_area_input_event)
	queue_redraw()

func _draw():
	if trail_enabled and _trail_points.size() >= 2:
		var local_points := PackedVector2Array()
		local_points.resize(_trail_points.size())
		for i in _trail_points.size():
			local_points[i] = to_local(_trail_points[i])
		draw_polyline(local_points, _trail_color, 1.6, true)
	if is_controlled:
		var ring_color: Color = _player_color()
		draw_arc(Vector2.ZERO, dot_radius + 4.0, 0.0, TAU, 32, ring_color, 2.0, true)
	draw_circle(Vector2.ZERO, dot_radius, _color)
	if is_controlled and controller_index >= 0:
		_draw_player_badge()
	if pin_coords:
		_draw_coord_label()

func _player_color() -> Color:
	if controller_index == 1:
		return Color(0.30, 0.78, 0.35, 1.0)
	return Color(1.0, 0.82, 0.18, 1.0)

func _draw_player_badge():
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var txt: String = "P%d" % (controller_index + 1)
	var size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pad: float = 2.0
	var bg_color: Color = _player_color()
	var bg_rect: Rect2 = Rect2(Vector2(-size.x * 0.5 - pad, dot_radius + 4.0), Vector2(size.x + pad * 2.0, size.y + pad))
	draw_rect(bg_rect, bg_color, true)
	draw_string(font, Vector2(-size.x * 0.5, dot_radius + 4.0 + size.y - 1.0), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 1))

func _draw_coord_label():
	var font := ThemeDB.fallback_font
	var font_size := 11
	var meters: Vector2 = global_position / SimulationManager.PX_PER_METER
	var txt := "(%.1fm, %.1fm)" % [meters.x, meters.y]
	var size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pad := 3.0
	var bg_rect := Rect2(Vector2(-size.x * 0.5 - pad, -dot_radius - size.y - pad * 2.0 - 4.0), Vector2(size.x + pad * 2.0, size.y + pad * 2.0))
	draw_rect(bg_rect, Color(0, 0, 0, 0.6), true)
	var text_pos := Vector2(-size.x * 0.5, -dot_radius - pad - 4.0)
	draw_string(font, text_pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 1))

func _process(_delta):
	if trail_enabled:
		if _trail_points.is_empty() or _trail_points[_trail_points.size() - 1].distance_to(global_position) >= TRAIL_MIN_DIST:
			_trail_points.append(global_position)
			if _trail_points.size() > TRAIL_MAX_POINTS:
				_trail_points.remove_at(0)
		queue_redraw()
	elif pin_coords:
		queue_redraw()

func _physics_process(delta: float):
	if SimulationManager.is_replaying:
		return
	var ts: float = SimulationManager.settings.time_scale
	var scaled_delta: float = delta * ts
	if is_controlled:
		_poll_control_input()
	elif has_node("Interpreter"):
		$Interpreter.process_behavior(scaled_delta)
	var cfg := SimulationManager.get_type_config(type_id)
	rotation += turn_input * cfg.turn_speed * scaled_delta
	velocity = Vector2.RIGHT.rotated(rotation) * cfg.speed * forward_input * ts
	move_and_slide()
	var s = Vector2(SimulationManager.settings.arena_width, SimulationManager.settings.arena_height)
	var r := dot_radius
	global_position.x = clampf(global_position.x, r, s.x - r)
	global_position.y = clampf(global_position.y, r, s.y - r)
	if not is_controlled and get_slide_collision_count() > 0:
		turn_input = randf_range(0.5, 1.5)

func _poll_control_input():
	if controller_index >= 0:
		var dev: int = controller_index
		var fwd: float = -Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		var turn: float = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		if absf(fwd) < STICK_DEADZONE: fwd = 0.0
		if absf(turn) < STICK_DEADZONE: turn = 0.0
		forward_input = clampf(fwd, -1.0, 1.0)
		turn_input = clampf(turn, -1.0, 1.0)
		return
	var fwd_kb := 0.0
	if Input.is_action_pressed("robot_forward"):
		fwd_kb += 1.0
	if Input.is_action_pressed("robot_backward"):
		fwd_kb -= 1.0
	var turn_kb := 0.0
	if Input.is_action_pressed("robot_turn_left"):
		turn_kb -= 1.0
	if Input.is_action_pressed("robot_turn_right"):
		turn_kb += 1.0
	forward_input = fwd_kb
	turn_input = turn_kb

func set_controlled(value: bool):
	is_controlled = value
	if not value:
		forward_input = 0.0
		turn_input = 0.0
		controller_index = -1
	set_process_input(value and controller_index >= 0)
	queue_redraw()

func assign_controller(idx: int):
	controller_index = idx
	set_process_input(is_controlled and idx >= 0)

func _input(event: InputEvent):
	if not is_controlled or controller_index < 0:
		return
	if event is InputEventJoypadButton and event.device == controller_index and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			release_requested.emit(self)

func toggle_trail():
	trail_enabled = not trail_enabled
	if not trail_enabled:
		_trail_points.clear()
	else:
		_trail_color = _allocate_trail_color()
		_trail_points.append(global_position)
	queue_redraw()

static func _allocate_trail_color() -> Color:
	var hue: float = fmod(_trail_counter * 0.618033988, 1.0)
	_trail_counter += 1
	return Color.from_hsv(hue, 0.78, 0.85, 0.85)

func toggle_pin_coords():
	pin_coords = not pin_coords
	queue_redraw()

func _apply_type_config():
	var cfg := SimulationManager.get_type_config(type_id)
	dot_radius = cfg.get("dot_radius", 6.0)
	queue_redraw()
	if has_node("VisionCone"):
		var sensor = $VisionCone
		sensor.view_distance = cfg.view_distance
		sensor.fov_degrees = cfg.fov_degrees
		sensor.call_deferred("generate_cone")

func _on_type_config_changed(changed_type: String):
	if changed_type == type_id:
		_apply_type_config()

func _on_click_area_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clicked.emit(self)
		viewport.set_input_as_handled()
