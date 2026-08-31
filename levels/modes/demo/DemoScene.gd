extends Node2D

const SHIP       := preload("res://entities/ship/DemoShip.tscn")
const SHIP_CLASS := preload("res://entities/ship/DemoShip.gd")
const WORLD      := preload("res://levels/modes/demo/DemoWorld.gd")
const LASER_BOX  := preload("res://levels/modes/demo/LaserBox.gd")
const HUD        := preload("res://levels/modes/demo/DemoHud.gd")
const TERRAN     := preload("res://entities/planet/PlanetTerran.tscn")
const EXPLOSION  := preload("res://entities/ship/Explosion.gd")
const WORKSPACE  := preload("res://ui/workspace/ShipWorkspace.tscn")

const WORKSPACE_LAYER := 20

const ARENA         := Vector2(1920.0, 1080.0)
const ARENA_CENTER  := Vector2(960.0, 540.0)
const PLANET_PIXELS := 80.0
const PLANET_DISP   := 190.0
const PLANET_RADIUS := 95.0
const GUIDE_RADIUS  := 300.0
const EDGE_INSET    := 34.0

const SWARM_COUNT := 20
const PILOT_COUNT := 4
const SHIP_HULL   := 14.0

const PILOT_SPEED      := 250.0
const PILOT_TURN_RATE  := 3.4
const PILOT_PARK_DELAY := 0.3
const BOX_HALF_SIZE    := 320.0

const EVADER_SPEED := 120.0

const WAVE_FIRST_DELAY    := 8.0
const WAVE_GAP            := 14.0
const WAVE_SPAWN_INTERVAL := 1.1
const WAVE_BASE_COUNT     := 4
const WAVE_GROWTH         := 2
const WAVE_MAX_COUNT      := 18

const SWARM_SPAWN_CLEARANCE := 60.0
const PLANET_SPAWN_KEEPOUT  := 170.0

const BG_COLOR := Color(0.04, 0.04, 0.07, 1.0)

const SELECT_KEYS   := [KEY_1, KEY_2, KEY_3, KEY_4]
const FORWARD_KEYS  := [KEY_W, KEY_UP]
const BACKWARD_KEYS := [KEY_S, KEY_DOWN]
const LEFT_KEYS     := [KEY_A, KEY_LEFT]
const RIGHT_KEYS    := [KEY_D, KEY_RIGHT]

enum Phase { ACTIVE, DONE }

var _phase: int = Phase.ACTIVE
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()

var _world
var _camera: Camera2D
var _laser_box
var _hud
var _workspace_layer: CanvasLayer
var _defender_program: Array = []

var _pilot_ships: Array = []
var _evader_ships: Array = []
var _active_index: int = 0

var _wave: int = 0
var _wave_timer: float = WAVE_FIRST_DELAY
var _spawns_left: int = 0
var _spawn_timer: float = 0.0

var _box_was_armed: bool = false
var _captures: int = 0
var _planet_hits: int = 0

var _key_down := {}

func _ready():
	get_tree().paused = false
	_rng.randomize()
	randomize()
	_defender_program = PlayerData.get_ship_algorithm()
	_build_world()
	_build_camera()
	_build_planet()
	_build_laser_box()
	_build_hud()
	_spawn_pilots()
	_spawn_swarm()

func _build_world():
	_world = WORLD.new()
	_world.arena = ARENA
	_world.background = BG_COLOR
	_world.planet_center = ARENA_CENTER
	_world.orbit_radius = GUIDE_RADIUS
	_world.stars = _make_bg_stars()
	_world.edge_top = load("res://assets/space_edge_top.png")
	_world.edge_bottom = load("res://assets/space_edge_bottom.png")
	_world.edge_left = load("res://assets/space_edge_left.png")
	_world.edge_right = load("res://assets/space_edge_right.png")
	add_child(_world)

func _build_camera():
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()

func _fit_camera():
	var view: Vector2 = get_viewport_rect().size
	var fit: float = minf(view.x / ARENA.x, view.y / ARENA.y)
	_camera.zoom = Vector2(fit, fit)
	_camera.position = ARENA_CENTER

func _build_planet():
	var planet := TERRAN.instantiate() as Control
	_world.add_child(planet)
	planet.generate(PlayerData.planet_seed, PLANET_PIXELS)
	planet.z_index = 2
	var factor: float = PLANET_DISP / PLANET_PIXELS
	planet.scale = Vector2(factor, factor)
	planet.position = ARENA_CENTER - Vector2(PLANET_DISP * 0.5, PLANET_DISP * 0.5)
	_disable_mouse(planet)

func _build_laser_box():
	_laser_box = LASER_BOX.new()
	_world.add_child(_laser_box)

func _build_hud():
	_hud = HUD.new()
	_hud.leave_pressed.connect(_leave)
	_hud.restart_pressed.connect(_restart)
	_hud.workspace_pressed.connect(_open_workspace)
	add_child(_hud)

func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse(child)

func _make_bg_stars() -> Array:
	var stars: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 8321
	for _i in 700:
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, ARENA.x), rng.randf_range(0.0, ARENA.y)),
			"sz":  rng.randf_range(1.0, 2.4),
			"a":   rng.randf_range(0.12, 0.55),
		})
	return stars

func _new_ship():
	var ship = SHIP.instantiate()
	ship.arena_size = ARENA
	ship.hull_radius = SHIP_HULL
	ship.show_health = false
	ship.can_fire = false
	ship.collisions_enabled = false
	return ship

func _spawn_pilots():
	var corners := [
		ARENA_CENTER + Vector2(-BOX_HALF_SIZE, -BOX_HALF_SIZE),
		ARENA_CENTER + Vector2(BOX_HALF_SIZE, -BOX_HALF_SIZE),
		ARENA_CENTER + Vector2(BOX_HALF_SIZE, BOX_HALF_SIZE),
		ARENA_CENTER + Vector2(-BOX_HALF_SIZE, BOX_HALF_SIZE),
	]
	for index in PILOT_COUNT:
		var ship = _new_ship()
		ship.team = 0
		_world.add_child(ship)
		ship.global_position = corners[index]
		ship.rotation = (ARENA_CENTER - corners[index]).angle()
		ship.setup_pilot(index, PILOT_SPEED, PILOT_TURN_RATE)
		_pilot_ships.append(ship)
	_set_active(0)

func _spawn_swarm():
	for _i in SWARM_COUNT:
		var ship = _new_ship()
		ship.team = 0
		_world.add_child(ship)
		ship.set_obstacles(Vector2.ZERO, 0.0, ARENA_CENTER, PLANET_RADIUS)
		ship.global_position = _swarm_spawn_point()
		ship.rotation = _rng.randf() * TAU
		ship.setup_wild()

func _swarm_spawn_point() -> Vector2:
	for _attempt in 140:
		var point := Vector2(
			_rng.randf_range(80.0, ARENA.x - 80.0),
			_rng.randf_range(80.0, ARENA.y - 80.0))
		if point.distance_to(ARENA_CENTER) < PLANET_SPAWN_KEEPOUT:
			continue
		var clear := true
		for other in _swarm_ships():
			if other.global_position.distance_to(point) < SWARM_SPAWN_CLEARANCE:
				clear = false
				break
		if clear:
			return point
	return ARENA_CENTER + Vector2(PLANET_SPAWN_KEEPOUT, 0.0).rotated(_rng.randf() * TAU)

func _spawn_evader():
	var ship = _new_ship()
	ship.team = 1
	ship.max_speed = EVADER_SPEED
	_world.add_child(ship)
	ship.global_position = _edge_spawn_point()
	ship.setup_evader(ARENA_CENTER)
	ship.exploded.connect(_on_evader_exploded)
	_evader_ships.append(ship)

func _edge_spawn_point() -> Vector2:
	var side: int = _rng.randi_range(0, 3)
	if side == 0:
		return Vector2(_rng.randf_range(0.0, ARENA.x), EDGE_INSET)
	if side == 1:
		return Vector2(_rng.randf_range(0.0, ARENA.x), ARENA.y - EDGE_INSET)
	if side == 2:
		return Vector2(EDGE_INSET, _rng.randf_range(0.0, ARENA.y))
	return Vector2(ARENA.x - EDGE_INSET, _rng.randf_range(0.0, ARENA.y))

func _physics_process(delta: float):
	if _phase != Phase.ACTIVE:
		return
	_elapsed += delta
	_poll_input(delta)
	_update_box()
	_update_roles()
	_run_waves(delta)
	_resolve_captures()
	_resolve_planet_hits()
	if _swarm_ships().is_empty():
		_finish()

func _process(_delta: float):
	_hud.refresh(_hud_state())

func _poll_input(_delta: float):
	_poll_selection()
	for ship in _pilot_ships:
		if is_instance_valid(ship):
			ship.pilot_thrust = 0.0
			ship.pilot_turn = 0.0
	var active = _active_ship()
	if active == null:
		return
	var thrust: float = 0.0
	var turn: float = 0.0
	if _any_key_down(FORWARD_KEYS):
		thrust += 1.0
	if _any_key_down(BACKWARD_KEYS):
		thrust -= 1.0
	if _any_key_down(RIGHT_KEYS):
		turn += 1.0
	if _any_key_down(LEFT_KEYS):
		turn -= 1.0
	active.pilot_thrust = clampf(thrust, -1.0, 1.0)
	active.pilot_turn = clampf(turn, -1.0, 1.0)

func _poll_selection():
	for index in SELECT_KEYS.size():
		if _key_edge(SELECT_KEYS[index]):
			_set_active(index)
	if _key_edge(KEY_TAB):
		_set_active((_active_index + 1) % PILOT_COUNT)

func _any_key_down(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false

func _key_edge(key: int) -> bool:
	var down: bool = Input.is_physical_key_pressed(key)
	var was: bool = bool(_key_down.get(key, false))
	_key_down[key] = down
	return down and not was

func _set_active(index: int):
	_active_index = clampi(index, 0, PILOT_COUNT - 1)
	for slot in _pilot_ships.size():
		var ship = _pilot_ships[slot]
		if is_instance_valid(ship):
			ship.set_active_pilot(slot == _active_index)

func _active_ship():
	if _active_index < 0 or _active_index >= _pilot_ships.size():
		return null
	var ship = _pilot_ships[_active_index]
	return ship if is_instance_valid(ship) else null

func _update_box():
	var points: Array = []
	var all_parked: bool = true
	for ship in _pilot_ships:
		if not is_instance_valid(ship):
			continue
		points.append(ship.global_position)
		if not ship.is_stationary(PILOT_PARK_DELAY):
			all_parked = false
	_laser_box.update_box(points, all_parked and points.size() == PILOT_COUNT)

func _update_roles():
	var box_armed: bool = _laser_box.active
	var just_armed: bool = box_armed and not _box_was_armed
	_box_was_armed = box_armed
	for ship in _swarm_ships():
		if ship.role == SHIP_CLASS.Role.DEFENDER:
			if box_armed:
				_laser_box.confine(ship)
			else:
				ship.setup_wild()
			continue
		if not box_armed:
			continue
		if just_armed and _laser_box.contains(ship.global_position):
			ship.setup_defender(_defender_program)
		else:
			_laser_box.repel(ship)

func _run_waves(delta: float):
	if _spawns_left > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_evader()
			_spawns_left -= 1
			_spawn_timer = WAVE_SPAWN_INTERVAL
		return
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	_wave += 1
	_spawns_left = mini(WAVE_MAX_COUNT, WAVE_BASE_COUNT + (_wave - 1) * WAVE_GROWTH)
	_spawn_timer = 0.0
	_wave_timer = WAVE_GAP

func _resolve_captures():
	var defenders: Array = []
	for ship in _swarm_ships():
		if ship.role == SHIP_CLASS.Role.DEFENDER:
			defenders.append(ship)
	if defenders.is_empty():
		return
	for evader in _live_evaders():
		for defender in defenders:
			if defender.is_spent():
				continue
			if evader.global_position.distance_to(defender.global_position) > defender.hull_radius + evader.hull_radius:
				continue
			_explode_at(evader.global_position, 78.0)
			_explode_at(defender.global_position, 60.0)
			evader.explode()
			defender.explode()
			_captures += 1
			break

func _resolve_planet_hits():
	for evader in _live_evaders():
		if evader.global_position.distance_to(ARENA_CENTER) > PLANET_RADIUS + SHIP_HULL:
			continue
		_explode_at(evader.global_position, 96.0)
		evader.explode()
		_planet_hits += 1

func _explode_at(point: Vector2, size: float):
	var blast := EXPLOSION.new()
	blast.display_size = size
	_world.add_child(blast)
	blast.global_position = point

func _on_evader_exploded(ship):
	_evader_ships.erase(ship)

func _swarm_ships() -> Array:
	var out: Array = []
	for ship in get_tree().get_nodes_in_group("demo_ships"):
		if is_instance_valid(ship) and not ship.is_spent() and ship.is_swarm():
			out.append(ship)
	return out

func _live_evaders() -> Array:
	var out: Array = []
	for ship in _evader_ships:
		if is_instance_valid(ship) and not ship.is_spent():
			out.append(ship)
	return out

func _hud_state() -> Dictionary:
	var parked: Array = []
	for ship in _pilot_ships:
		parked.append(is_instance_valid(ship) and ship.is_stationary(PILOT_PARK_DELAY))
	var defenders: int = 0
	var wild: int = 0
	for ship in _swarm_ships():
		if ship.role == SHIP_CLASS.Role.DEFENDER:
			defenders += 1
		else:
			wild += 1
	return {
		"wave": _wave,
		"next_wave": int(ceilf(maxf(0.0, _wave_timer))),
		"incoming": _spawns_left,
		"box_active": _laser_box.active,
		"defenders": defenders,
		"wild": wild,
		"evaders": _live_evaders().size(),
		"captures": _captures,
		"hits": _planet_hits,
		"elapsed": int(_elapsed),
		"active_ship": _active_index,
		"parked": parked,
	}

func _finish():
	_phase = Phase.DONE
	for ship in get_tree().get_nodes_in_group("demo_ships"):
		if is_instance_valid(ship):
			ship.set_physics_process(false)
	_laser_box.update_box([], false)
	_hud.show_result(_hud_state())

func _open_workspace():
	if _workspace_layer != null or _phase != Phase.ACTIVE:
		return
	_workspace_layer = CanvasLayer.new()
	_workspace_layer.layer = WORKSPACE_LAYER
	_workspace_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_workspace_layer)
	var editor := WORKSPACE.instantiate()
	editor.embedded = true
	editor.closed.connect(_close_workspace)
	_workspace_layer.add_child(editor)
	get_tree().paused = true

func _close_workspace():
	if _workspace_layer != null:
		_workspace_layer.queue_free()
		_workspace_layer = null
	get_tree().paused = false
	_reload_defender_program()

func _reload_defender_program():
	_defender_program = PlayerData.get_ship_algorithm()
	for ship in _swarm_ships():
		if ship.role == SHIP_CLASS.Role.DEFENDER:
			ship.setup_defender(_defender_program)

func _restart():
	get_tree().reload_current_scene()

func _leave():
	get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn")
