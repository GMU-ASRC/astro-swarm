extends Node2D

signal destroyed(ship)

const TEAM_PLAYER := 0
const TEAM_PROTECTOR := 1

const HULL_BITS := {0: 16, 1: 32}

const SPEED := 150.0
const TURN_SPEED := 3.2
const VIEW_DISTANCE := 300.0
const FOV_DEGREES := 70.0
const FIRE_INTERVAL := 0.55
const PROJECTILE_SPEED := 460.0
const DAMAGE := 1.0
const HULL_RADIUS := 9.0

const PROJECTILE := preload("res://entities/ship/Projectile.tscn")

var team: int = TEAM_PLAYER
var hp: float = 3.0
var max_hp: float = 3.0
var show_health: bool = true
var arena_size: Vector2 = Vector2(1280, 720)
var speed_mult: float = 1.0
var view_distance: float = VIEW_DISTANCE
var fov_degrees: float = FOV_DEGREES
var max_speed: float = SPEED
var turn_rate: float = TURN_SPEED
var hull_radius: float = HULL_RADIUS

var star_center: Vector2 = Vector2.ZERO
var star_radius: float = 0.0
var planet_center: Vector2 = Vector2.ZERO
var planet_radius: float = 0.0
var collisions_enabled: bool = true

var forward_input: float = 0.0
var turn_input: float = 0.0
var _turn_cmd: float = 0.0
var can_fire: bool = true

const BlockExecutor := preload("res://entities/BlockExecutor.gd")
const STEP_TIME := 0.4

var _executor
var _visible: Array = []
var _fire_cooldown: float = 0.0
var _throttle_mult: float = 1.0
var _enemies_cache: Array = []

var _orbit: bool = false
var _orbit_center: Vector2 = Vector2.ZERO
var _orbit_radius: float = 0.0
var _orbit_speed: float = 0.0
var _orbit_angle: float = 0.0
var ship_color: Color = Color(1.0, 0.42, 0.32, 1.0)

var _cone_polygon: PackedVector2Array = PackedVector2Array()

@onready var _hull: Area2D = $Hull
@onready var _vision: Area2D = $Vision

func _ready():
	z_index = 5
	_setup_collision()
	_generate_cone()
	_hull.add_to_group("ship_hull")
	add_to_group("ships")
	_vision.area_entered.connect(_on_vision_entered)
	_vision.area_exited.connect(_on_vision_exited)
	queue_redraw()

func _setup_collision():
	_hull.collision_layer = HULL_BITS[team]
	_hull.collision_mask = 0
	_hull.monitorable = true
	_hull.monitoring = false
	_vision.collision_layer = 0
	_vision.collision_mask = HULL_BITS[0] | HULL_BITS[1]
	_vision.monitoring = true
	_vision.monitorable = false

func setup_player(blocks: Array, hp_value: float):
	team = TEAM_PLAYER
	max_hp = hp_value
	hp = hp_value
	_set_program(blocks)
	_orbit = false
	ship_color = Color(0.451, 0.616, 1.0, 1.0)

func set_obstacles(s_center: Vector2, s_radius: float, p_center: Vector2, p_radius: float):
	star_center = s_center
	star_radius = s_radius
	planet_center = p_center
	planet_radius = p_radius

func setup_protector(center: Vector2, radius: float, ang_speed: float, start_angle: float, hp_value: float):
	team = TEAM_PROTECTOR
	max_hp = hp_value
	hp = hp_value
	_orbit = true
	_orbit_center = center
	_orbit_radius = radius
	_orbit_speed = ang_speed
	_orbit_angle = start_angle
	ship_color = Color(1.0, 0.42, 0.32, 1.0)
	global_position = center + Vector2(radius, 0.0).rotated(start_angle)
	rotation = start_angle + PI / 2.0

func setup_raider(blocks: Array, hp_value: float):
	team = TEAM_PROTECTOR
	max_hp = hp_value
	hp = hp_value
	_set_program(blocks)
	_orbit = false
	ship_color = Color(0.85, 0.4, 0.95, 1.0)

func setup_player_orbit(center: Vector2, radius: float, ang_speed: float, start_angle: float, hp_value: float):
	team = TEAM_PLAYER
	max_hp = hp_value
	hp = hp_value
	_orbit = true
	_orbit_center = center
	_orbit_radius = radius
	_orbit_speed = ang_speed
	_orbit_angle = start_angle
	ship_color = Color(0.451, 0.616, 1.0, 1.0)
	global_position = center + Vector2(radius, 0.0).rotated(start_angle)
	rotation = start_angle + PI / 2.0

func _set_program(blocks: Array):
	_executor = BlockExecutor.new(self)
	_executor.set_program(SimulationManager.normalize_to_scripts(blocks))

func _physics_process(delta: float):
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _orbit:
		_process_orbit(delta)
	else:
		_process_program(delta)
		_apply_movement(delta)
		if is_queued_for_deletion():
			return
	queue_redraw()

func _process_orbit(delta: float):
	_orbit_angle += _orbit_speed * delta
	var prev: Vector2 = global_position
	global_position = _orbit_center + Vector2(_orbit_radius, 0.0).rotated(_orbit_angle)
	var tangent: Vector2 = global_position - prev
	if tangent.length() > 0.001:
		rotation = tangent.angle()

func _process_program(delta: float):
	_enemies_cache = _live_enemies()
	_executor.process(delta)

func reset_inputs():
	forward_input = 0.0
	turn_input = 0.0

func on_deactivate():
	_turn_cmd = 0.0

func _apply_movement(delta: float):
	rotation += (turn_input * turn_rate + _turn_cmd) * delta
	var vel: Vector2 = Vector2.RIGHT.rotated(rotation) * max_speed * speed_mult * forward_input
	global_position += vel * delta
	global_position.x = clampf(global_position.x, 14.0, arena_size.x - 14.0)
	global_position.y = clampf(global_position.y, 14.0, arena_size.y - 14.0)
	_resolve_obstacles()

func _resolve_obstacles():
	if not collisions_enabled:
		return
	if star_radius > 0.0 and global_position.distance_to(star_center) < star_radius + hull_radius:
		take_damage(max_hp)
		return
	if planet_radius > 0.0:
		var min_dist: float = planet_radius + hull_radius
		var offset: Vector2 = global_position - planet_center
		var dist: float = offset.length()
		if dist < min_dist:
			if dist < 0.001:
				offset = Vector2.RIGHT
				dist = 1.0
			global_position = planet_center + offset / dist * min_dist

func eval_condition(cond: String, params: Dictionary) -> bool:
	match cond:
		"always":
			return true
		"sees", "sees_species", "sees_enemy":
			return _enemies_cache.size() > 0
		"alone":
			return _enemies_cache.size() == 0 and _live_allies().size() == 0
		"no_sees_species":
			return _enemies_cache.size() == 0
		"sees_ally":
			return _live_allies().size() > 0
		"near_wall":
			return _near_wall()
		"sees_wall":
			return _sees_rim()
		"sees_object":
			return _sees_object()
		"sees_rim":
			return _sees_rim()
		"within":
			var d: float = _nearest_enemy_dist()
			return d >= 0.0 and d <= float(params.get("value", 3.0)) * SimulationManager.PX_PER_METER
		"beyond":
			var d2: float = _nearest_enemy_dist()
			return d2 >= 0.0 and d2 > float(params.get("value", 3.0)) * SimulationManager.PX_PER_METER
		"see":
			match params.get("target", "anyone"):
				"object": return _sees_object()
				"wall": return _near_wall()
				_: return _enemies_cache.size() > 0
		"compare":
			return _compare_var(params)
	return false

func _compare_var(params: Dictionary) -> bool:
	var left = SimulationManager.get_var(params.get("var", ""))
	var op: String = params.get("op", "=")
	var right = params.get("value", 0.0)
	if left is String:
		var rs := str(right)
		if op == "=":  return left == rs
		if op == "!=": return left != rs
		return false
	var a := float(left)
	var b := float(right)
	match op:
		"=":  return a == b
		"!=": return a != b
		"<":  return a < b
		">":  return a > b
		"<=": return a <= b
		">=": return a >= b
	return false

func _nearest_enemy_dist() -> float:
	var best: float = -1.0
	for e in _enemies_cache:
		var d: float = global_position.distance_to(e.global_position)
		if best < 0.0 or d < best:
			best = d
	return best

func exec_action(block_type: String, params: Dictionary, delta: float, state: Dictionary) -> bool:
	match block_type:
		"set_var":
			SimulationManager.set_var(params.get("var", ""), params.get("value", 0))
			return BlockExecutor.DONE
		"set_var_random":
			var lo: int = int(params.get("min", 0))
			var hi: int = int(params.get("max", 0))
			if lo > hi:
				var tmp := lo
				lo = hi
				hi = tmp
			SimulationManager.set_var(params.get("var", ""), randi_range(lo, hi))
			return BlockExecutor.DONE
	if block_type.begins_with("set_"):
		return BlockExecutor.DONE
	match block_type.substr(3):
		"forward":
			forward_input = _throttle_mult
			return _step(state, delta)
		"backward":
			forward_input = -_throttle_mult
			return _step(state, delta)
		"stop":
			forward_input = 0.0
			turn_input = 0.0
			_turn_cmd = 0.0
			return BlockExecutor.DONE
		"random_walk", "wander":
			_turn_cmd = 0.0
			if not state.has("heading"):
				state.heading = randf() * TAU
				state.remaining = _levy_step_time()
			rotation = state.heading
			forward_input = _throttle_mult
			state.remaining -= delta
			if state.remaining <= 0.0:
				return BlockExecutor.DONE
			return BlockExecutor.RUNNING
		"turn_left":
			_turn_cmd = -deg_to_rad(float(params.get("value", 90.0)))
			return BlockExecutor.DONE
		"turn_right":
			_turn_cmd = deg_to_rad(float(params.get("value", 90.0)))
			return BlockExecutor.DONE
		"turn_left_by":
			_turn_cmd = 0.0
			return _turn_by(state, delta, -1.0, float(params.get("value", 180.0)))
		"turn_right_by":
			_turn_cmd = 0.0
			return _turn_by(state, delta, 1.0, float(params.get("value", 180.0)))
		"face":
			_turn_cmd = 0.0
			_rotate_toward(0.0, delta)
			return _step(state, delta)
		"flee":
			_turn_cmd = 0.0
			_rotate_toward(PI, delta)
			return _step(state, delta)
		"throttle":
			_throttle_mult = float(params.get("value", 1.0))
			return BlockExecutor.DONE
		"fire":
			_fire()
			return BlockExecutor.DONE
	return BlockExecutor.DONE

func _levy_step_time() -> float:
	var shortest := 0.2
	var longest := 3.0
	var sample := randf()
	var step := shortest / maxf(0.001, 1.0 - sample)
	return minf(step, longest)

func _step(state: Dictionary, delta: float) -> bool:
	if not state.has("t"):
		state.t = STEP_TIME
	state.t -= delta
	return state.t <= 0.0

func _turn_by(state: Dictionary, delta: float, dir: float, deg: float) -> bool:
	if not state.has("rem"):
		state.rem = deg_to_rad(deg)
	var step: float = turn_rate * delta
	if step >= state.rem:
		rotation += dir * state.rem
		return BlockExecutor.DONE
	rotation += dir * step
	state.rem -= step
	return BlockExecutor.RUNNING

func _rotate_toward(offset: float, delta: float):
	var t = _nearest(_enemies_cache)
	if t == null:
		return
	var a: float = global_position.angle_to_point(t.global_position) + offset
	rotation = lerp_angle(rotation, a, clampf(turn_rate * delta, 0.0, 1.0))

func _object_in_view(center: Vector2, radius: float) -> bool:
	var to: Vector2 = center - global_position
	if to.length() - radius > view_distance:
		return false
	return absf(angle_difference(rotation, to.angle())) <= deg_to_rad(fov_degrees) * 0.5

func _sees_object() -> bool:
	if star_radius > 0.0 and _object_in_view(star_center, star_radius):
		return true
	if planet_radius > 0.0 and _object_in_view(planet_center, planet_radius):
		return true
	# asteroids will be checked here once added
	return false

func _sees_rim() -> bool:
	var dir: Vector2 = Vector2.RIGHT.rotated(rotation)
	var dist: float = INF
	if dir.x > 0.0001:
		dist = min(dist, (arena_size.x - global_position.x) / dir.x)
	elif dir.x < -0.0001:
		dist = min(dist, -global_position.x / dir.x)
	if dir.y > 0.0001:
		dist = min(dist, (arena_size.y - global_position.y) / dir.y)
	elif dir.y < -0.0001:
		dist = min(dist, -global_position.y / dir.y)
	return dist <= view_distance

func _near_wall() -> bool:
	var m := 24.0
	return global_position.x <= m or global_position.y <= m \
		or global_position.x >= arena_size.x - m or global_position.y >= arena_size.y - m

func _fire():
	if not can_fire:
		return
	if _fire_cooldown > 0.0:
		return
	var proj := PROJECTILE.instantiate()
	proj.target_team = 1 - team
	proj.damage = DAMAGE
	proj.speed = PROJECTILE_SPEED
	proj.color = _team_color()
	proj.global_position = global_position + Vector2(hull_radius + 4.0, 0.0).rotated(rotation)
	proj.rotation = rotation
	get_parent().add_child(proj)
	_fire_cooldown = FIRE_INTERVAL

func take_damage(amount: float):
	if hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		destroyed.emit(self)
		queue_free()
	else:
		queue_redraw()

func _live_enemies() -> Array:
	var out: Array = []
	for s in _visible:
		if is_instance_valid(s) and s.hp > 0.0 and s.team != team:
			out.append(s)
	return out

func _live_allies() -> Array:
	var out: Array = []
	for s in _visible:
		if is_instance_valid(s) and s.hp > 0.0 and s.team == team:
			out.append(s)
	return out

func _nearest(enemies: Array):
	var best = null
	var best_dist: float = INF
	for e in enemies:
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func _on_vision_entered(area: Area2D):
	var ship = area.get_parent()
	if ship != null and ship != self and ship.is_in_group("ships") and not _visible.has(ship):
		_visible.append(ship)

func _on_vision_exited(area: Area2D):
	var ship = area.get_parent()
	if _visible.has(ship):
		_visible.erase(ship)

func refresh_cone():
	_generate_cone()
	queue_redraw()

func _generate_cone():
	var polygon := PackedVector2Array()
	polygon.append(Vector2.ZERO)
	var fov_rad: float = deg_to_rad(fov_degrees)
	var num_points := 16
	var start_angle: float = -fov_rad / 2.0
	for i in range(num_points + 1):
		var angle: float = start_angle + (fov_rad * i / float(num_points))
		polygon.append(Vector2.RIGHT.rotated(angle) * view_distance)
	$Vision/VisionShape.polygon = polygon
	_cone_polygon = polygon

func _team_color() -> Color:
	return ship_color

func _draw():
	var col: Color = _team_color()
	if _cone_polygon.size() >= 3:
		var fill := Color(col.r, col.g, col.b, 0.05)
		draw_polygon(_cone_polygon, PackedColorArray([fill]))
	var ss: float = hull_radius / HULL_RADIUS
	var tip := Vector2(13.0, 0.0) * ss
	var back_a := Vector2(-9.0, -7.0) * ss
	var back_b := Vector2(-9.0, 7.0) * ss
	draw_colored_polygon(PackedVector2Array([tip, back_a, back_b]), col)
	draw_polyline(PackedVector2Array([tip, back_a, back_b, tip]), Color(0.05, 0.05, 0.1, 1.0), 1.5, true)
	if show_health and hp < max_hp:
		_draw_hp_bar()

func _draw_hp_bar():
	var w := 22.0
	var h := 3.0
	var y := -18.0
	var frac: float = clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, h), Color(0.1, 0.1, 0.12, 0.8), true)
	draw_rect(Rect2(-w / 2.0, y, w * frac, h), Color(0.4, 0.85, 0.45, 1.0), true)
