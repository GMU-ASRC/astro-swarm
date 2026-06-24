extends Node

const SHIP := preload("res://entities/ship/Spaceship.tscn")

const ARENA         := Vector2(2560.0, 1440.0)
const PLANET_CENTER := Vector2(1280.0, 720.0)
const PLANET_RADIUS := 120.0
const PLACE_RADIUS  := 360.0
const DEFENDER_HP   := 99.0
const ENEMY_HP      := 3.0
const ENEMY_SPEED   := 105.0
const ENEMY_PROGRAM := [
	{"type": "when_always", "params": {}},
	{"type": "do_forward", "params": {}},
]

const DEFAULT_N_MAX  := 40
const DEFAULT_TRIALS := 20
const MATCH_SECONDS  := 25.0
const BASE_VIEW      := 300.0
const BASE_FOV       := 70.0

var _algorithm: Array = []
var _n_max: int = DEFAULT_N_MAX
var _trials: int = DEFAULT_TRIALS
var _out_path: String = "user://farp_bench.json"
var _rng := RandomNumberGenerator.new()

var _world: Node2D
var _defenders: Array = []
var _enemy: Node2D = null
var _frame: int = 0
var _match_frames: int = 0

var _current_n: int = 1
var _current_trial: int = 0
var _success_count: int = 0
var _results: Array = []
var _running: bool = false

func _ready():
	if not _is_bench_mode():
		return
	_running = true
	_parse_args()
	_match_frames = int(MATCH_SECONDS * Engine.physics_ticks_per_second)
	_world = Node2D.new()
	add_child(_world)
	_start_match()

func _is_bench_mode() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	return "--bench" in OS.get_cmdline_user_args() or "--bench" in OS.get_cmdline_args()

func _parse_args():
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--algorithm="):
			_load_algorithm(arg.split("=", true, 1)[1])
		elif arg.begins_with("--out="):
			_out_path = arg.split("=", true, 1)[1]
		elif arg.begins_with("--nmax="):
			_n_max = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--trials="):
			_trials = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--seed="):
			_rng.seed = int(arg.split("=", true, 1)[1])
	if _algorithm.is_empty():
		_algorithm = SimulationManager.normalize_to_scripts(PlayerData.DEFAULT_SHIP_BLOCKS)

func _load_algorithm(path: String):
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return
	var data = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY and data.has("algorithm"):
		data = data["algorithm"]
	if typeof(data) == TYPE_ARRAY:
		_algorithm = SimulationManager.normalize_to_scripts(data)

func _start_match():
	_clear_world()
	_frame = 0
	_spawn_defenders(_current_n)
	_spawn_enemy()

func _spawn_defenders(count: int):
	var cfg: Dictionary = SimulationManager.ship_config_from_scripts(_algorithm, BASE_VIEW, BASE_FOV)
	for i in count:
		var angle: float = float(i) * TAU / float(count)
		var ship := SHIP.instantiate()
		ship.setup_player(_algorithm, DEFENDER_HP)
		ship.set_obstacles(Vector2.ZERO, 0.0, PLANET_CENTER, PLANET_RADIUS)
		ship.arena_size = ARENA
		ship.can_fire = false
		ship.view_distance = cfg.view_distance
		ship.fov_degrees = cfg.fov_degrees
		_world.add_child(ship)
		ship.global_position = PLANET_CENTER + Vector2(PLACE_RADIUS, 0.0).rotated(angle)
		ship.rotation = angle
		ship.refresh_cone()
		_defenders.append(ship)

func _spawn_enemy():
	var margin := 40.0
	var spawn_pos: Vector2
	match _rng.randi() % 4:
		0: spawn_pos = Vector2(_rng.randf_range(margin, ARENA.x - margin), margin)
		1: spawn_pos = Vector2(_rng.randf_range(margin, ARENA.x - margin), ARENA.y - margin)
		2: spawn_pos = Vector2(margin, _rng.randf_range(margin, ARENA.y - margin))
		_: spawn_pos = Vector2(ARENA.x - margin, _rng.randf_range(margin, ARENA.y - margin))
	_enemy = SHIP.instantiate()
	_enemy.setup_raider(ENEMY_PROGRAM, ENEMY_HP)
	_enemy.set_obstacles(Vector2.ZERO, 0.0, PLANET_CENTER, PLANET_RADIUS)
	_enemy.arena_size = ARENA
	_enemy.speed_mult = ENEMY_SPEED / 150.0
	_world.add_child(_enemy)
	_enemy.global_position = spawn_pos
	_enemy.rotation = (PLANET_CENTER - spawn_pos).angle()

func _physics_process(_delta: float):
	if not _running:
		return
	_frame += 1
	var intercepted: bool = _any_defender_sees_enemy()
	var reached: bool = is_instance_valid(_enemy) and _enemy.global_position.distance_to(PLANET_CENTER) <= PLANET_RADIUS + 16.0
	var timed_out: bool = _frame >= _match_frames
	if intercepted or reached or timed_out:
		_finish_match(intercepted)

func _finish_match(intercepted: bool):
	if intercepted:
		_success_count += 1
	_current_trial += 1
	if _current_trial >= _trials:
		var rate: float = 100.0 * float(_success_count) / float(_trials)
		_results.append({"n": _current_n, "success_rate": snappedf(rate, 0.1)})
		_success_count = 0
		_current_trial = 0
		_current_n += 1
		if _current_n > _n_max:
			_write_output()
			return
	_start_match()

func _any_defender_sees_enemy() -> bool:
	if not is_instance_valid(_enemy):
		return false
	for ship in _defenders:
		if not is_instance_valid(ship):
			continue
		var to_enemy: Vector2 = _enemy.global_position - ship.global_position
		if to_enemy.length() > ship.view_distance:
			continue
		var diff: float = absf(angle_difference(ship.rotation, to_enemy.angle()))
		if diff <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

func _clear_world():
	for ship in _defenders:
		if is_instance_valid(ship):
			ship.queue_free()
	_defenders.clear()
	if is_instance_valid(_enemy):
		_enemy.queue_free()
	_enemy = null

func _write_output():
	_running = false
	var payload := {
		"n_max": _n_max,
		"trials": _trials,
		"results": _results,
	}
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()
	print(JSON.stringify(payload))
	get_tree().quit(0)
