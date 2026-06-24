extends Node

const SHIP := preload("res://entities/ship/Spaceship.tscn")

const ARENA         := Vector2(2560.0, 1440.0)
const PLANET_CENTER := Vector2(1280.0, 720.0)
const PLANET_RADIUS := 120.0
const MAX_DEFENDERS  := 6
const DEFENDER_HP   := 99.0
const ENEMY_HP      := 3.0
const ENEMY_SPEED   := 105.0
const ENEMY_PROGRAM := [
	{"type": "when_always", "params": {}},
	{"type": "do_forward", "params": {}},
]

const DEFAULT_TRIALS := 100
const MATCH_SECONDS  := 25.0
const RECORD_EVERY   := 2
const TAIL_FRAMES    := 24

var _algorithm: Array = []
var _placements: Array = []
var _trials: int = DEFAULT_TRIALS
var _out_path: String = "user://farp_bench.json"
var _rng := RandomNumberGenerator.new()

var _world: Node2D
var _defenders: Array = []
var _enemy: Node2D = null
var _frame: int = 0
var _match_frames: int = 0

var _current_trial: int = 0
var _success_count: int = 0
var _replay_view: float = 300.0
var _replay_fov: float = 70.0
var _outcomes: Array = []
var _runs: Array = []
var _replay_frames: Array = []
var _running: bool = false
var _in_tail: bool = false
var _tail: int = 0

func _ready():
	if not _is_bench_mode():
		return
	_running = true
	_parse_args()
	_match_frames = int(MATCH_SECONDS * Engine.physics_ticks_per_second)
	print("[bench] start defenders=%d trials=%d" % [_placements.size(), _trials])
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
		elif arg.begins_with("--placements="):
			_load_placements(arg.split("=", true, 1)[1])
		elif arg.begins_with("--out="):
			_out_path = arg.split("=", true, 1)[1]
		elif arg.begins_with("--trials="):
			_trials = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--seed="):
			_rng.seed = int(arg.split("=", true, 1)[1])
	if _algorithm.is_empty():
		_algorithm = SimulationManager.normalize_to_scripts(PlayerData.DEFAULT_SHIP_BLOCKS)
	if _placements.size() > MAX_DEFENDERS:
		_placements.resize(MAX_DEFENDERS)

func _load_algorithm(path: String):
	var data = _read_json(path)
	if typeof(data) == TYPE_DICTIONARY and data.has("algorithm"):
		data = data["algorithm"]
	if typeof(data) == TYPE_ARRAY:
		_algorithm = SimulationManager.normalize_to_scripts(data)

func _load_placements(path: String):
	var data = _read_json(path)
	if typeof(data) == TYPE_DICTIONARY and data.has("placements"):
		data = data["placements"]
	if typeof(data) != TYPE_ARRAY:
		return
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_placements.append({
			"pos": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
			"rot": float(entry.get("rot", 0.0)),
		})

func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return null
	return JSON.parse_string(text)

func _start_match():
	_clear_world()
	_frame = 0
	_in_tail = false
	_tail = 0
	_replay_frames = []
	_spawn_defenders()
	_spawn_enemy()
	_replay_frames.append(_snapshot())

func _spawn_defenders():
	for placement in _placements:
		var ship := SHIP.instantiate()
		ship.setup_player(_algorithm, DEFENDER_HP)
		ship.set_obstacles(Vector2.ZERO, 0.0, PLANET_CENTER, PLANET_RADIUS)
		ship.arena_size = ARENA
		ship.can_fire = false
		_world.add_child(ship)
		var cfg: Dictionary = SimulationManager.ship_config_from_scripts(_algorithm, ship.view_distance, ship.fov_degrees, ship.max_speed, ship.turn_rate, ship.hull_radius)
		ship.view_distance = cfg.view_distance
		ship.fov_degrees = cfg.fov_degrees
		ship.max_speed = cfg.speed
		ship.turn_rate = cfg.turn_speed
		ship.hull_radius = cfg.dot_radius
		ship.global_position = placement.pos
		ship.rotation = placement.rot
		ship.refresh_cone()
		_replay_view = ship.view_distance
		_replay_fov = ship.fov_degrees
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
	if _frame % RECORD_EVERY == 0:
		_replay_frames.append(_snapshot())
	if _in_tail:
		_tail -= 1
		if _tail <= 0:
			_finish_match(true, "win")
		return
	var intercepted: bool = _any_defender_sees_enemy()
	var reached: bool = is_instance_valid(_enemy) and _enemy.global_position.distance_to(PLANET_CENTER) <= PLANET_RADIUS + 16.0
	var timed_out: bool = _frame >= _match_frames
	if intercepted:
		_in_tail = true
		_tail = TAIL_FRAMES
	elif reached:
		_finish_match(false, "lose")
	elif timed_out:
		_finish_match(false, "timeout")

func _finish_match(intercepted: bool, outcome: String):
	_replay_frames.append(_snapshot())
	_runs.append({
		"trial": _current_trial,
		"outcome": outcome,
		"frames": _replay_frames,
	})
	_outcomes.append(outcome)
	if intercepted:
		_success_count += 1
	print("PROGRESS %d/%d  trial=%d outcome=%s" % [_current_trial + 1, _trials, _current_trial + 1, outcome])
	_current_trial += 1
	if _current_trial >= _trials:
		_write_output()
		return
	_start_match()

func _snapshot() -> Array:
	var frame: Array = []
	for ship in _defenders:
		if is_instance_valid(ship):
			frame.append(int(ship.global_position.x))
			frame.append(int(ship.global_position.y))
			frame.append(int(rad_to_deg(ship.rotation)))
		else:
			frame.append(0)
			frame.append(0)
			frame.append(0)
	if is_instance_valid(_enemy):
		frame.append(int(_enemy.global_position.x))
		frame.append(int(_enemy.global_position.y))
		frame.append(int(rad_to_deg(_enemy.rotation)))
	else:
		frame.append(-1)
		frame.append(-1)
		frame.append(0)
	return frame

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
	var success_rate: float = 100.0 * float(_success_count) / float(maxi(1, _trials))
	var payload := {
		"trials": _trials,
		"results": {
			"trials": _trials,
			"success_rate": snappedf(success_rate, 0.1),
			"outcomes": _outcomes,
		},
		"replays": {
			"fps": int(Engine.physics_ticks_per_second / RECORD_EVERY),
			"defenders": _placements.size(),
			"view": int(_replay_view),
			"fov": int(_replay_fov),
			"planet": [int(PLANET_CENTER.x), int(PLANET_CENTER.y), int(PLANET_RADIUS)],
			"arena": [int(ARENA.x), int(ARENA.y)],
			"runs": _runs,
		},
	}
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()
	print(JSON.stringify(payload))
	get_tree().quit(0)
