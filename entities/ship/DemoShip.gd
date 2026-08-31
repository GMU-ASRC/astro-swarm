extends "res://entities/ship/Spaceship.gd"

const PROGRAMS := preload("res://entities/ship/SwarmPrograms.gd")

enum Role { PILOT, DEFENDER, WILD, EVADER }

const DEFENDER_COLOR := Color(0.45, 0.62, 1.0, 1.0)
const WILD_COLOR     := Color(0.65, 0.45, 0.95, 1.0)
const EVADER_COLOR   := Color(1.0, 0.42, 0.32, 1.0)
const PILOT_COLOR    := Color(1.0, 0.80, 0.25, 1.0)
const PILOT_IDLE_COLOR := Color(0.52, 0.58, 0.80, 1.0)

const DEFENDER_VIEW  := 320.0
const DEFENDER_FOV   := 150.0
const DEFENDER_SPEED := 165.0
const DEFENDER_TURN  := 4.0

const EVADER_TURN_RATE := 2.4
const STILL_EPSILON    := 0.35
const ARENA_INSET      := 18.0
const SELECT_RING      := 26.0

signal exploded(ship)

var role: int = Role.WILD
var pilot_index: int = -1
var is_active_pilot: bool = false
var pilot_thrust: float = 0.0
var pilot_turn: float = 0.0
var pilot_speed: float = 220.0
var pilot_turn_rate: float = 3.4
var still_time: float = 0.0
var target_planet: Vector2 = Vector2.ZERO

var _spent: bool = false
var _base_hull: float = HULL_RADIUS

func _ready():
	super()
	_base_hull = hull_radius
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("demo_ships")
	_refresh_color()

func setup_pilot(index: int, speed: float, turn: float):
	role = Role.PILOT
	pilot_index = index
	pilot_speed = speed
	pilot_turn_rate = turn
	_executor = null
	_refresh_color()

func setup_defender(blocks: Array):
	role = Role.DEFENDER
	view_distance = DEFENDER_VIEW
	fov_degrees = DEFENDER_FOV
	max_speed = DEFENDER_SPEED
	turn_rate = DEFENDER_TURN
	hull_radius = _base_hull
	_apply_program(blocks)
	_refresh_color()

func setup_wild():
	role = Role.WILD
	hull_radius = _base_hull
	_apply_program(PROGRAMS.WILD)
	_refresh_color()

func setup_evader(planet_center: Vector2):
	role = Role.EVADER
	is_evader = true
	target_planet = planet_center
	_executor = null
	rotation = (planet_center - global_position).angle()
	_refresh_color()

func set_active_pilot(active: bool):
	is_active_pilot = active
	_refresh_color()
	queue_redraw()

func is_swarm() -> bool:
	return role == Role.DEFENDER or role == Role.WILD

func is_stationary(delay: float) -> bool:
	return still_time >= delay

func is_spent() -> bool:
	return _spent

func explode():
	if _spent:
		return
	_spent = true
	exploded.emit(self)
	queue_free()

func _apply_program(blocks: Array):
	_set_program(blocks)
	var scripts: Array = SIM.normalize_to_scripts(blocks)
	var cfg: Dictionary = SimulationManager.ship_config_from_scripts(scripts, view_distance, fov_degrees, max_speed, turn_rate, hull_radius)
	view_distance = cfg.view_distance
	fov_degrees = cfg.fov_degrees
	max_speed = cfg.speed
	turn_rate = cfg.turn_speed
	hull_radius = cfg.dot_radius
	refresh_cone()

func _live_enemies() -> Array:
	return _ships_in_cone(true)

func _live_allies() -> Array:
	return _ships_in_cone(false)

func _ships_in_cone(enemies: bool) -> Array:
	var out: Array = []
	var half_fov: float = deg_to_rad(fov_degrees) * 0.5
	for other in get_tree().get_nodes_in_group("demo_ships"):
		if other == self or not is_instance_valid(other) or other.is_spent() or other.hp <= 0.0:
			continue
		if (other.team != team) != enemies:
			continue
		var offset: Vector2 = other.global_position - global_position
		if offset.length() > view_distance:
			continue
		if absf(angle_difference(rotation, offset.angle())) > half_fov:
			continue
		out.append(other)
	return out

func _refresh_color():
	match role:
		Role.PILOT:
			ship_color = PILOT_COLOR if is_active_pilot else PILOT_IDLE_COLOR
		Role.DEFENDER:
			ship_color = DEFENDER_COLOR
		Role.EVADER:
			ship_color = EVADER_COLOR
		_:
			ship_color = WILD_COLOR

func _physics_process(delta: float):
	match role:
		Role.PILOT:
			_drive_pilot(delta)
		Role.EVADER:
			_drive_evader(delta)
		_:
			super(delta)

func _drive_pilot(delta: float):
	var before: Vector2 = global_position
	rotation += pilot_turn * pilot_turn_rate * delta
	global_position += Vector2.RIGHT.rotated(rotation) * pilot_speed * pilot_thrust * delta
	global_position.x = clampf(global_position.x, ARENA_INSET, arena_size.x - ARENA_INSET)
	global_position.y = clampf(global_position.y, ARENA_INSET, arena_size.y - ARENA_INSET)
	if global_position.distance_to(before) < STILL_EPSILON:
		still_time += delta
	else:
		still_time = 0.0
	queue_redraw()

func _drive_evader(delta: float):
	var desired: float = (target_planet - global_position).angle()
	rotation = lerp_angle(rotation, desired, clampf(EVADER_TURN_RATE * delta, 0.0, 1.0))
	global_position += Vector2.RIGHT.rotated(rotation) * max_speed * delta
	queue_redraw()

func _draw():
	if role == Role.DEFENDER and _cone_polygon.size() >= 3:
		var fill := Color(ship_color.r, ship_color.g, ship_color.b, 0.06)
		draw_polygon(_cone_polygon, PackedColorArray([fill]))
	if role == Role.PILOT and is_active_pilot:
		draw_arc(Vector2.ZERO, SELECT_RING, 0.0, TAU, 32, Color(1.0, 0.88, 0.45, 0.85), 2.0, true)
