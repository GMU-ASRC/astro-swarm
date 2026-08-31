extends "res://entities/ship/Spaceship.gd"

enum Role { WILD, HERDED, PILOT, EVADER }

const ROLE_COLORS := {
	Role.WILD:   Color(0.65, 0.45, 0.95, 1.0),
	Role.HERDED: Color(0.45, 0.62, 1.0, 1.0),
	Role.EVADER: Color(1.0, 0.42, 0.32, 1.0),
}
const PILOT_COLORS := [
	Color(1.0, 0.80, 0.25, 1.0),
	Color(0.40, 0.85, 0.45, 1.0),
]
const FREEZE_PATH := "res://assets/sprites/effects/freeze.png"

const SPRITE_WIDTH := 46.0        # pixels, width the freeze effect is sized against
const HERD_MEMORY_SECONDS := 5.0  # seconds a ship keeps following its herder after losing sight

const PROGRAMS := preload("res://entities/ship/SwarmPrograms.gd")

const WILD_PROGRAM := PROGRAMS.WILD
const HERDED_PROGRAM := PROGRAMS.HERDED

signal exploded(ship)
signal herded(ship, slot)

var role: int = Role.WILD
var pilot_slot: int = -1
var herder_slot: int = -1
var target_planet: Vector2 = Vector2.ZERO # pixels
var target_radius: float = 0.0            # pixels
var pilot_thrust: float = 0.0             # throttle in -1..1
var pilot_turn: float = 0.0               # turn in -1..1, scaled by pilot_turn_rate
var pilot_speed: float = 200.0            # pixels/second (5.0 m/s)
var pilot_turn_rate: float = 3.0          # radians/second
var freeze_remaining: float = 0.0         # seconds left frozen

var _sight_timer: float = 0.0             # seconds of herd memory left before the ship goes wild again
var _freeze_sprite: Sprite2D
var _spent: bool = false

func _ready():
	super()
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("survive_ships")
	_freeze_sprite = Sprite2D.new()
	_freeze_sprite.visible = false
	_freeze_sprite.z_index = 2
	_freeze_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_freeze_sprite.texture = load(FREEZE_PATH)
	_scale_sprite(_freeze_sprite, SPRITE_WIDTH * 1.15)
	add_child(_freeze_sprite)
	_refresh_sprite()

func setup_wild():
	role = Role.WILD
	_apply_program(WILD_PROGRAM)
	_refresh_sprite()

func setup_herded(slot: int):
	var was_wild: bool = role != Role.HERDED
	role = Role.HERDED
	herder_slot = slot
	_sight_timer = HERD_MEMORY_SECONDS
	_apply_program(HERDED_PROGRAM)
	_refresh_sprite()
	if was_wild:
		herded.emit(self, slot)

func setup_pilot(slot: int, speed: float, turn: float):
	role = Role.PILOT
	pilot_slot = slot
	pilot_speed = speed
	pilot_turn_rate = turn
	_executor = null
	_refresh_sprite()

func setup_evader(planet_center: Vector2, planet_radius: float):
	role = Role.EVADER
	target_planet = planet_center
	target_radius = planet_radius
	_executor = null
	rotation = (planet_center - global_position).angle()
	_refresh_sprite()

func _apply_program(blocks: Array):
	_set_program(blocks)
	var scripts: Array = SIM.normalize_to_scripts(blocks)
	var cfg: Dictionary = SimulationManager.ship_config_from_scripts(scripts, view_distance, fov_degrees, max_speed, turn_rate, hull_radius)
	view_distance = cfg.view_distance
	fov_degrees = cfg.fov_degrees
	max_speed = cfg.speed
	turn_rate = cfg.turn_speed
	refresh_cone()

func _refresh_sprite():
	ship_color = _role_color()

func _role_color() -> Color:
	if role == Role.PILOT:
		return PILOT_COLORS[clampi(pilot_slot, 0, 1)]
	return ROLE_COLORS[role]

func _scale_sprite(node: Sprite2D, width: float):
	if node.texture == null:
		return
	var sc: float = width / maxf(1.0, float(node.texture.get_width()))
	node.scale = Vector2(sc, sc)

func _physics_process(delta: float):
	if freeze_remaining > 0.0:
		freeze_remaining = maxf(0.0, freeze_remaining - delta)
		_freeze_sprite.visible = freeze_remaining > 0.0
		_freeze_sprite.rotation += delta * 2.0
		queue_redraw()
		return
	_freeze_sprite.visible = false
	match role:
		Role.PILOT:
			_drive_pilot(delta)
		Role.EVADER:
			_drive_evader(delta)
		_:
			_update_herd_state(delta)
			super(delta)

func _drive_pilot(delta: float):
	rotation += pilot_turn * pilot_turn_rate * delta
	global_position += Vector2.RIGHT.rotated(rotation) * pilot_speed * pilot_thrust * delta
	_clamp_to_arena()
	queue_redraw()

func _drive_evader(delta: float):
	var desired: float = (target_planet - global_position).angle()
	rotation = lerp_angle(rotation, desired, clampf(2.4 * delta, 0.0, 1.0))
	global_position += Vector2.RIGHT.rotated(rotation) * max_speed * delta
	queue_redraw()

func _update_herd_state(delta: float):
	if role == Role.HERDED:
		_sight_timer -= delta
		if _sees_herd_source():
			_sight_timer = HERD_MEMORY_SECONDS
		elif _sight_timer <= 0.0:
			setup_wild()
		return
	var source = _nearest_herd_source()
	if source != null:
		if source.role == Role.PILOT:
			herder_slot = source.pilot_slot
		else:
			herder_slot = source.herder_slot
		setup_herded(herder_slot)

func _sees_herd_source() -> bool:
	return _nearest_herd_source() != null

func _nearest_herd_source():
	var best = null
	var best_dist: float = INF
	for other in _visible:
		if not is_instance_valid(other) or other == self:
			continue
		if not (other is Node2D) or not other.has_method("is_herd_source"):
			continue
		if not other.is_herd_source():
			continue
		var d: float = global_position.distance_squared_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best

func is_herd_source() -> bool:
	return role != Role.EVADER

func can_shoot() -> bool:
	return role == Role.HERDED and not _spent

func visible_evader():
	var best = null
	var best_dist: float = INF
	for other in _visible:
		if not is_instance_valid(other):
			continue
		if not other.has_method("is_herd_source") or other.role != Role.EVADER:
			continue
		var d: float = global_position.distance_squared_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best

func is_spent() -> bool:
	return _spent

func explode():
	if _spent:
		return
	_spent = true
	exploded.emit(self)
	queue_free()

func freeze_for(seconds: float):
	freeze_remaining = maxf(freeze_remaining, seconds)
	pilot_thrust = 0.0
	pilot_turn = 0.0

func _clamp_to_arena():
	global_position.x = clampf(global_position.x, 18.0, arena_size.x - 18.0)
	global_position.y = clampf(global_position.y, 18.0, arena_size.y - 18.0)

func _draw():
	if role != Role.HERDED and role != Role.PILOT:
		return
	if _cone_polygon.size() < 3:
		return
	var col: Color = ship_color
	draw_polygon(_cone_polygon, PackedColorArray([Color(col.r, col.g, col.b, 0.06)]))
