extends CharacterBody2D

@export var type_id: String = "hunter"
@export var dot_radius: float = 6.0
var robot_name: String = ""

var forward_input: float = 1.0
var turn_input: float = 0.0
var is_controlled: bool = false
var _color: Color

signal clicked(robot)

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
	if is_controlled:
		draw_arc(Vector2.ZERO, dot_radius + 4.0, 0.0, TAU, 32, Color(1.0, 0.82, 0.18, 1.0), 2.0, true)
	draw_circle(Vector2.ZERO, dot_radius, _color)

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
	var fwd := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		fwd += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		fwd -= 1.0
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		turn += 1.0
	forward_input = fwd
	turn_input = turn

func set_controlled(value: bool):
	is_controlled = value
	if not value:
		forward_input = 0.0
		turn_input = 0.0
	queue_redraw()

func _apply_type_config():
	var cfg := SimulationManager.get_type_config(type_id)
	if has_node("VisionCone"):
		var sensor = $VisionCone
		sensor.view_distance = cfg.view_distance
		sensor.fov_degrees = cfg.fov_degrees
		sensor.call_deferred("generate_cone")

func _on_type_config_changed(changed_type: String):
	if changed_type == type_id:
		_apply_type_config()

func _on_click_area_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
