extends Node2D

signal destroyed(ship)

const TEAM_PLAYER := 0
const TEAM_PROTECTOR := 1

const HULL_BITS := {0: 16, 1: 32}

const SPEED := 150.0
const TURN_SPEED := 3.2
const TURN_COOLDOWN := 0.5
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
var arena_size: Vector2 = Vector2(1280, 720)

var star_center: Vector2 = Vector2.ZERO
var star_radius: float = 0.0
var planet_center: Vector2 = Vector2.ZERO
var planet_radius: float = 0.0

var forward_input: float = 0.0
var turn_input: float = 0.0

var _rules: Array = []
var _visible: Array = []
var _fire_cooldown: float = 0.0
var _wander_turn: float = 0.0
var _wander_timer: float = 0.0
var _walk_timer: float = 0.0
var _walk_dir: float = 0.0
var _pending_turn: float = 0.0
var _pending_dir: float = 0.0
var _turn_cooldown: float = 0.0
var _prev_states: Dictionary = {}

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
	_rules = _compile(blocks)
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
	_rules = _compile(blocks)
	_orbit = false
	ship_color = Color(0.85, 0.4, 0.95, 1.0)

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
	if _turn_cooldown > 0.0:
		_turn_cooldown -= delta
	if _pending_turn > 0.0:
		var step: float = TURN_SPEED * delta
		if step >= _pending_turn:
			rotation += _pending_dir * _pending_turn
			_pending_turn = 0.0
			_turn_cooldown = TURN_COOLDOWN
		else:
			rotation += _pending_dir * step
			_pending_turn -= step
		forward_input = 0.0
		turn_input = 0.0
		return

	forward_input = 0.0
	turn_input = 0.0
	var enemies: Array = _live_enemies()
	var current_states: Dictionary = {}
	for i in _rules.size():
		var rule: Dictionary = _rules[i]
		var cond: String = rule.get("condition", "always")
		var is_true: bool = _eval_condition(cond, rule.get("params", {}), enemies)
		var key: String = "%d_%s" % [i, cond]
		current_states[key] = is_true
		if not is_true:
			continue
		var rising: bool = not _prev_states.get(key, false)
		for act in rule.get("actions", []):
			var aid: String = act.get("id", "stop")
			if aid == "turn_left_by" or aid == "turn_right_by":
				if rising and _turn_cooldown <= 0.0:
					_exec_action(aid, act.get("params", {}), delta, enemies)
			else:
				_exec_action(aid, act.get("params", {}), delta, enemies)
			if _pending_turn > 0.0:
				forward_input = 0.0
				turn_input = 0.0
				_prev_states = current_states
				return
	_prev_states = current_states

func _apply_movement(delta: float):
	rotation += turn_input * TURN_SPEED * delta
	var vel: Vector2 = Vector2.RIGHT.rotated(rotation) * SPEED * forward_input
	global_position += vel * delta
	global_position.x = clampf(global_position.x, 14.0, arena_size.x - 14.0)
	global_position.y = clampf(global_position.y, 14.0, arena_size.y - 14.0)
	_resolve_obstacles()

func _resolve_obstacles():
	if star_radius > 0.0 and global_position.distance_to(star_center) < star_radius + HULL_RADIUS:
		take_damage(max_hp)
		return
	if planet_radius > 0.0:
		var min_dist: float = planet_radius + HULL_RADIUS
		var offset: Vector2 = global_position - planet_center
		var dist: float = offset.length()
		if dist < min_dist:
			if dist < 0.001:
				offset = Vector2.RIGHT
				dist = 1.0
			global_position = planet_center + offset / dist * min_dist

func _eval_condition(cond: String, params: Dictionary, enemies: Array) -> bool:
	match cond:
		"always":
			return true
		"sees", "sees_species", "sees_enemy":
			return enemies.size() > 0
		"alone", "no_sees_species":
			return enemies.size() == 0
		"sees_ally":
			return _live_allies().size() > 0
		"near_wall":
			return _near_wall()
		"sees_wall":
			return false
		"sees_object":
			return _sees_object()
		"sees_rim":
			return _sees_rim()
	return false

func _exec_action(action: String, params: Dictionary, delta: float, enemies: Array):
	match action:
		"forward":
			forward_input = 1.0
		"backward":
			forward_input = -1.0
		"stop":
			forward_input = 0.0
			turn_input = 0.0
		"wander":
			_do_wander(delta)
		"random_walk":
			_do_random_walk(delta)
		"turn_left":
			rotation -= deg_to_rad(float(params.get("value", 90.0))) * delta
			turn_input = 0.0
		"turn_right":
			rotation += deg_to_rad(float(params.get("value", 90.0))) * delta
			turn_input = 0.0
		"throttle":
			forward_input *= float(params.get("value", 1.0))
		"face":
			var t = _nearest(enemies)
			if t != null:
				_turn_toward(global_position.angle_to_point(t.global_position), delta)
		"flee":
			var f = _nearest(enemies)
			if f != null:
				_turn_toward(global_position.angle_to_point(f.global_position) + PI, delta)
		"fire":
			_fire()
		"turn_left_by":
			_pending_turn = deg_to_rad(float(params.get("value", 180.0)))
			_pending_dir = -1.0
		"turn_right_by":
			_pending_turn = deg_to_rad(float(params.get("value", 180.0)))
			_pending_dir = 1.0

func _turn_toward(target_angle: float, delta: float):
	rotation = lerp_angle(rotation, target_angle, clampf(TURN_SPEED * delta, 0.0, 1.0))
	turn_input = 0.0

func _do_wander(delta: float):
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_turn = randf_range(-1.0, 1.0)
		_wander_timer = randf_range(0.4, 1.0)
	turn_input = _wander_turn

func _do_random_walk(delta: float):
	_walk_timer -= delta
	if _walk_timer <= 0.0:
		_walk_dir = [0.0, PI / 2.0, PI, -PI / 2.0][randi() % 4]
		_walk_timer = 0.5
	rotation = _walk_dir
	forward_input = 1.0

func _object_in_view(center: Vector2, radius: float) -> bool:
	var to: Vector2 = center - global_position
	if to.length() - radius > VIEW_DISTANCE:
		return false
	return absf(angle_difference(rotation, to.angle())) <= deg_to_rad(FOV_DEGREES) * 0.5

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
	return dist <= VIEW_DISTANCE

func _near_wall() -> bool:
	var m := 24.0
	return global_position.x <= m or global_position.y <= m \
		or global_position.x >= arena_size.x - m or global_position.y >= arena_size.y - m

func _fire():
	if _fire_cooldown > 0.0:
		return
	var proj := PROJECTILE.instantiate()
	proj.target_team = 1 - team
	proj.damage = DAMAGE
	proj.speed = PROJECTILE_SPEED
	proj.color = _team_color()
	proj.global_position = global_position + Vector2(HULL_RADIUS + 4.0, 0.0).rotated(rotation)
	proj.rotation = rotation
	get_parent().add_child(proj)
	_fire_cooldown = FIRE_INTERVAL

func take_damage(amount: float):
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

func _compile(blocks: Array) -> Array:
	var rules: Array = []
	var current = null
	for b in blocks:
		var t: String = b.get("type", "")
		var p: Dictionary = b.get("params", {})
		if t.begins_with("when_"):
			current = {"condition": t.substr(5), "params": p.duplicate(), "actions": []}
			rules.append(current)
		elif t.begins_with("do_"):
			if current == null:
				current = {"condition": "always", "params": {}, "actions": []}
				rules.append(current)
			current.actions.append({"id": t.substr(3), "params": p.duplicate()})
	return rules

func _generate_cone():
	var polygon := PackedVector2Array()
	polygon.append(Vector2.ZERO)
	var fov_rad: float = deg_to_rad(FOV_DEGREES)
	var num_points := 16
	var start_angle: float = -fov_rad / 2.0
	for i in range(num_points + 1):
		var angle: float = start_angle + (fov_rad * i / float(num_points))
		polygon.append(Vector2.RIGHT.rotated(angle) * VIEW_DISTANCE)
	$Vision/VisionShape.polygon = polygon
	_cone_polygon = polygon

func _team_color() -> Color:
	return ship_color

func _draw():
	var col: Color = _team_color()
	if _cone_polygon.size() >= 3:
		var fill := Color(col.r, col.g, col.b, 0.05)
		draw_polygon(_cone_polygon, PackedColorArray([fill]))
	var tip := Vector2(13.0, 0.0)
	var back_a := Vector2(-9.0, -7.0)
	var back_b := Vector2(-9.0, 7.0)
	draw_colored_polygon(PackedVector2Array([tip, back_a, back_b]), col)
	draw_polyline(PackedVector2Array([tip, back_a, back_b, tip]), Color(0.05, 0.05, 0.1, 1.0), 1.5, true)
	if hp < max_hp:
		_draw_hp_bar()

func _draw_hp_bar():
	var w := 22.0
	var h := 3.0
	var y := -18.0
	var frac: float = clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, h), Color(0.1, 0.1, 0.12, 0.8), true)
	draw_rect(Rect2(-w / 2.0, y, w * frac, h), Color(0.4, 0.85, 0.45, 1.0), true)
