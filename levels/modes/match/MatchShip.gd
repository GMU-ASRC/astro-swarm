extends "res://entities/ship/Spaceship.gd"

signal cargo_delivered(ship, amount: float)

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

enum CollectorState { SEARCHING, MINING, RETURNING }

const ROLE_SPRITES := [
	"res://assets/sprites/match/collector.svg",
	"res://assets/sprites/spaceship/spaceship.svg",
	"res://assets/sprites/match/evader.svg",
	"res://assets/sprites/match/scout.svg",
]
const DELIVERY_MARGIN := 6.0
const CARGO_BAR_WIDTH := 20.0

var ship_id: int = 0
var role: int = MATCH_CONFIG.Role.DEFENDER
var owner_slot: int = 0
var home_center: Vector2 = Vector2.ZERO
var home_radius: float = MATCH_CONFIG.PLANET_RADIUS
var enemy_home_center: Vector2 = Vector2.ZERO
var mining_sites: Array = []
var speed_cap: float = INF
var view_cap: float = MATCH_CONFIG.VIEW_CAP
var cargo: float = 0.0
var cargo_capacity: float = MATCH_CONFIG.CARGO_BASE
var mining_rate: float = MATCH_CONFIG.DRILL_BASE
var collector_state: int = CollectorState.SEARCHING
var pilot_thrust: float = 0.0
var pilot_turn: float = 0.0
var is_remote: bool = false
var remote_thrust: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0

var _mining_site = null

func thruster_level() -> float:
	if is_remote:
		return remote_thrust
	return super()

func follow_remote(delta: float):
	global_position = global_position.lerp(target_position, clampf(delta * 15.0, 0.0, 1.0))
	rotation = lerp_angle(rotation, target_rotation, clampf(delta * 15.0, 0.0, 1.0))
	queue_redraw()

func _sprite_path() -> String:
	if role >= 0 and role < ROLE_SPRITES.size():
		return ROLE_SPRITES[role]
	return SHIP_SPRITE_PATH

func _physics_process(delta: float):
	match role:
		MATCH_CONFIG.Role.SCOUT:
			_fly_by_pilot(delta)
		MATCH_CONFIG.Role.COLLECTOR:
			_process_collector(delta)
		_:
			super(delta)

func _fly_by_pilot(delta: float):
	rotation += pilot_turn * turn_rate * delta
	global_position += Vector2.RIGHT.rotated(rotation) * max_speed * pilot_thrust * delta
	_clamp_to_arena()
	forward_input = pilot_thrust
	_throttle_engaged = true
	queue_redraw()

func _process_collector(delta: float):
	match collector_state:
		CollectorState.SEARCHING:
			super._physics_process(delta)
			if is_queued_for_deletion():
				return
			var site = _touching_site()
			if site != null:
				_mining_site = site
				collector_state = CollectorState.MINING
		CollectorState.MINING:
			_mine(delta)
		CollectorState.RETURNING:
			_return_home(delta)
	queue_redraw()

func _touching_site():
	for site in mining_sites:
		if is_instance_valid(site) and site.has_dust() and global_position.distance_to(site.global_position) <= site.radius + hull_radius:
			return site
	return null

func _mine(delta: float):
	forward_input = 0.0
	if not is_instance_valid(_mining_site):
		_finish_mining()
		return
	cargo += _mining_site.take(minf(mining_rate * delta, cargo_capacity - cargo))
	if cargo >= cargo_capacity - 0.01 or not _mining_site.has_dust():
		_finish_mining()

func _finish_mining():
	_mining_site = null
	collector_state = CollectorState.RETURNING if cargo > 0.0 else CollectorState.SEARCHING

func _return_home(delta: float):
	var to_home: Vector2 = home_center - global_position
	rotation = rotate_toward(rotation, to_home.angle(), turn_rate * delta)
	global_position += Vector2.RIGHT.rotated(rotation) * max_speed * delta
	_clamp_to_arena()
	forward_input = 1.0
	if to_home.length() <= home_radius + hull_radius + DELIVERY_MARGIN:
		cargo_delivered.emit(self, cargo)
		cargo = 0.0
		collector_state = CollectorState.SEARCHING
		rotation = (global_position - home_center).angle()

func _clamp_to_arena():
	global_position.x = clampf(global_position.x, 14.0, arena_size.x - 14.0)
	global_position.y = clampf(global_position.y, 14.0, arena_size.y - 14.0)

func eval_condition(cond: String, params: Dictionary) -> bool:
	match cond:
		"sees_dust":
			return _visible_site() != null
		"sees_enemy_planet":
			return _object_in_view(enemy_home_center, home_radius)
		"far_from_home":
			return global_position.distance_to(home_center) > MATCH_CONFIG.HOME_LEASH
	return super(cond, params)

func exec_action(block_type: String, params: Dictionary, delta: float, state: Dictionary) -> bool:
	match block_type:
		"do_face_dust":
			_turn_cmd = 0.0
			var site = _visible_site()
			if site != null:
				_turn_toward(site.global_position, delta)
			return _step(state, delta)
		"do_face_enemy_planet":
			_turn_cmd = 0.0
			_turn_toward(enemy_home_center, delta)
			return _step(state, delta)
		"do_face_home":
			_turn_cmd = 0.0
			_turn_toward(home_center, delta)
			return _step(state, delta)
	return super(block_type, params, delta, state)

func _turn_toward(point: Vector2, delta: float):
	var target_angle: float = global_position.angle_to_point(point)
	rotation = lerp_angle(rotation, target_angle, clampf(turn_rate * delta, 0.0, 1.0))

func _visible_site():
	var best = null
	var best_distance: float = INF
	for site in mining_sites:
		if not is_instance_valid(site) or not site.has_dust():
			continue
		if not _object_in_view(site.global_position, site.radius):
			continue
		var distance: float = global_position.distance_squared_to(site.global_position)
		if distance < best_distance:
			best_distance = distance
			best = site
	return best

func _sees_object() -> bool:
	if _visible_site() != null:
		return true
	return _object_in_view(enemy_home_center, home_radius) or _object_in_view(home_center, home_radius)

func _apply_config(entry: Dictionary):
	super(entry)
	apply_role_limits()

func apply_role_limits():
	max_speed = minf(max_speed, speed_cap)
	if view_distance > view_cap:
		view_distance = view_cap
		refresh_cone()

func vision_radius() -> float:
	if role == MATCH_CONFIG.Role.SCOUT:
		return MATCH_CONFIG.SCOUT_VISION
	return maxf(view_distance, MATCH_CONFIG.MIN_SHIP_VISION)

func _draw():
	super()
	if role == MATCH_CONFIG.Role.COLLECTOR and cargo > 0.0:
		var fraction: float = clampf(cargo / maxf(1.0, cargo_capacity), 0.0, 1.0)
		var bar_y: float = 16.0
		draw_rect(Rect2(-CARGO_BAR_WIDTH * 0.5, bar_y, CARGO_BAR_WIDTH, 3.0), Color(0.1, 0.1, 0.12, 0.8), true)
		draw_rect(Rect2(-CARGO_BAR_WIDTH * 0.5, bar_y, CARGO_BAR_WIDTH * fraction, 3.0), MATCH_CONFIG.DUST_COLOR, true)
