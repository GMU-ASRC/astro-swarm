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
const DEFAULT_SWEEP_MAX    := 100
const DEFAULT_SWEEP_TRIALS := 1
const DEFAULT_SEED         := 987654321
const DEFAULT_SPAWN_POINTS := 20
const DEFAULT_MATCH_SECONDS := 4 * 60.0
const SWEEP_RADIUS  := 400.0
const RECORD_EVERY   := 2
const REPLAY_TAIL    := 90

enum Phase { PLACEMENT, SWEEP }

var _algorithm: Array = []
var _placements: Array = []
var _trials: int = DEFAULT_TRIALS
var _sweep_max: int = DEFAULT_SWEEP_MAX
var _sweep_trials: int = DEFAULT_SWEEP_TRIALS
var _seed: int = DEFAULT_SEED
var _spawn_count: int = DEFAULT_SPAWN_POINTS
var _match_seconds: float = DEFAULT_MATCH_SECONDS
var _trial_start: int = 0
var _trial_count: int = -1
var _n_start: int = 1
var _n_count: int = -1
var _out_path: String = "user://farp_bench.json"

var _spawn_rng := RandomNumberGenerator.new()
var _orient_rng := RandomNumberGenerator.new()
var _spawn_points: Array = []

var _world: Node2D
var _defenders: Array = []
var _enemy: Node2D = null
var _frame: int = 0
var _match_frames: int = 0

var _phase: int = Phase.PLACEMENT
var _current_trial: int = 0
var _success_count: int = 0
var _global_done: int = 0
var _global_total: int = 1

var _replay_view: float = 300.0
var _replay_fov: float = 70.0
var _outcomes: Array = []
var _detection_times: Array = []
var _capture_times: Array = []
var _runs: Array = []
var _replay_frames: Array = []

var _sweep_n: int = 1
var _sweep_success: int = 0
var _sweep_points: Array = []
var _sweep_runs: Array = []

var _detect_frame: int = -1
var _capture_frame: int = -1
var _replay_stop: int = -1
var _running: bool = false

func _ready():
	if not _is_bench_mode():
		return
	_running = true
	_parse_args()
	if _trial_count < 0:
		_trial_count = _trials
	if _n_count < 0:
		_n_count = _sweep_max
	_build_spawn_points()
	_match_frames = int(_match_seconds * Engine.physics_ticks_per_second)
	_global_total = maxi(1, _trial_count + _n_count * _sweep_trials)
	print("[bench] start defenders=%d trials=%d trial_start=%d trial_count=%d n_start=%d n_count=%d seed=%d" % [_placements.size(), _trials, _trial_start, _trial_count, _n_start, _n_count, _seed])
	_world = Node2D.new()
	add_child(_world)
	_phase = Phase.PLACEMENT
	_current_trial = _trial_start
	if _trial_count > 0:
		_start_match()
	else:
		_begin_sweep()

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
		elif arg.begins_with("--n-max="):
			_sweep_max = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--sweep-trials="):
			_sweep_trials = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--seed="):
			_seed = int(arg.split("=", true, 1)[1])
		elif arg.begins_with("--spawn-points="):
			_spawn_count = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--match-seconds="):
			_match_seconds = maxf(1.0, float(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--trial-start="):
			_trial_start = maxi(0, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--trial-count="):
			_trial_count = maxi(0, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--n-start="):
			_n_start = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--n-count="):
			_n_count = maxi(0, int(arg.split("=", true, 1)[1]))
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

func _build_spawn_points():
	_spawn_rng.seed = _seed
	var margin := 40.0
	for _i in _spawn_count:
		var pos: Vector2
		match _spawn_rng.randi() % 4:
			0: pos = Vector2(_spawn_rng.randf_range(margin, ARENA.x - margin), margin)
			1: pos = Vector2(_spawn_rng.randf_range(margin, ARENA.x - margin), ARENA.y - margin)
			2: pos = Vector2(margin, _spawn_rng.randf_range(margin, ARENA.y - margin))
			_: pos = Vector2(ARENA.x - margin, _spawn_rng.randf_range(margin, ARENA.y - margin))
		_spawn_points.append(pos)

func _ring_placements(count: int) -> Array:
	var out: Array = []
	_orient_rng.seed = _seed + 100000 + count
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		out.append({
			"pos": PLANET_CENTER + Vector2(SWEEP_RADIUS, 0.0).rotated(angle),
			"rot": _orient_rng.randf() * TAU,
		})
	return out

func _start_match():
	_clear_world()
	_frame = 0
	_detect_frame = -1
	_capture_frame = -1
	_replay_stop = -1
	_replay_frames = []
	var placements: Array
	var spawn_index: int
	if _phase == Phase.PLACEMENT:
		placements = _placements
		spawn_index = _current_trial
		seed(_seed + _current_trial)
	else:
		placements = _ring_placements(_sweep_n)
		spawn_index = 0
		seed(_seed + 1000000 + _sweep_n)
	_spawn_defenders(placements)
	_spawn_enemy(spawn_index)
	_replay_frames.append(_snapshot())

func _spawn_defenders(placements: Array):
	for placement in placements:
		var ship := SHIP.instantiate()
		ship.setup_player(_algorithm, DEFENDER_HP)
		ship.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
		ship.collisions_enabled = false
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

func _spawn_enemy(index: int):
	var spawn_pos: Vector2 = _spawn_points[index % _spawn_points.size()]
	_enemy = SHIP.instantiate()
	_enemy.setup_raider(ENEMY_PROGRAM, ENEMY_HP)
	_enemy.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	_enemy.collisions_enabled = false
	_enemy.arena_size = ARENA
	_enemy.speed_mult = ENEMY_SPEED / 150.0
	_world.add_child(_enemy)
	_enemy.global_position = spawn_pos
	_enemy.rotation = (PLANET_CENTER - spawn_pos).angle()

func _physics_process(_delta: float):
	if not _running:
		return
	_frame += 1
	if _frame % RECORD_EVERY == 0 and (_replay_stop < 0 or _frame <= _replay_stop):
		_replay_frames.append(_snapshot())

	if _detect_frame < 0 and _any_defender_sees_enemy():
		_detect_frame = _frame
	if _capture_frame < 0 and is_instance_valid(_enemy) and _enemy.global_position.distance_to(PLANET_CENTER) <= PLANET_RADIUS + 16.0:
		_capture_frame = _frame
		if _replay_stop < 0:
			_replay_stop = _frame + REPLAY_TAIL

	var timed_out: bool = _frame >= _match_frames
	if _phase == Phase.PLACEMENT:
		var both_known: bool = _detect_frame >= 0 and _capture_frame >= 0
		if both_known or timed_out:
			_finish_placement_match()
	else:
		var captured_with_tail: bool = _capture_frame >= 0 and _frame >= _capture_frame + REPLAY_TAIL
		if captured_with_tail or timed_out:
			_finish_sweep_match()

func _frame_to_time(frame: int) -> float:
	if frame < 0:
		return -1.0
	return snappedf(float(frame) / float(Engine.physics_ticks_per_second), 0.01)

func _classify() -> String:
	if _detect_frame >= 0 and (_capture_frame < 0 or _detect_frame <= _capture_frame):
		return "win"
	if _capture_frame >= 0:
		return "lose"
	return "timeout"

func _finish_placement_match():
	var outcome: String = _classify()
	_runs.append({
		"trial": _current_trial,
		"outcome": outcome,
		"detection_time": _frame_to_time(_detect_frame),
		"capture_time": _frame_to_time(_capture_frame),
		"frames": _replay_frames,
	})
	_outcomes.append(outcome)
	_detection_times.append(_frame_to_time(_detect_frame))
	_capture_times.append(_frame_to_time(_capture_frame))
	if outcome == "win":
		_success_count += 1
	_advance(outcome)

func _finish_sweep_match():
	var outcome: String = _classify()
	_sweep_runs.append({
		"n": _sweep_n,
		"outcome": outcome,
		"detection_time": _frame_to_time(_detect_frame),
		"capture_time": _frame_to_time(_capture_frame),
		"defenders": _sweep_n,
		"frames": _replay_frames,
	})
	if outcome == "win":
		_sweep_success += 1
	_advance("sweep n=%d" % _sweep_n)

func _advance(label: String):
	_global_done += 1
	_current_trial += 1
	var phase_name: String = "placement" if _phase == Phase.PLACEMENT else "sweep"
	print("PROGRESS %d/%d  phase=%s outcome=%s" % [_global_done, _global_total, phase_name, label])

	if _phase == Phase.PLACEMENT:
		if _current_trial >= _trial_start + _trial_count:
			_begin_sweep()
			return
		_start_match()
		return

	if _current_trial >= _sweep_trials:
		var rate: float = 100.0 * float(_sweep_success) / float(maxi(1, _sweep_trials))
		_sweep_points.append({"n": _sweep_n, "success_rate": snappedf(rate, 0.1)})
		_sweep_n += 1
		if _sweep_n >= _n_start + _n_count:
			_write_output()
			return
		_sweep_success = 0
		_current_trial = 0
	_start_match()

func _begin_sweep():
	_phase = Phase.SWEEP
	_sweep_n = _n_start
	_sweep_success = 0
	_current_trial = 0
	if _n_count > 0:
		_start_match()
	else:
		_write_output()

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
			"detection_times": _detection_times,
			"capture_times": _capture_times,
			"sweep": _sweep_points,
		},
		"replays": {
			"fps": int(Engine.physics_ticks_per_second / RECORD_EVERY),
			"defenders": _placements.size(),
			"view": int(_replay_view),
			"fov": int(_replay_fov),
			"planet": [int(PLANET_CENTER.x), int(PLANET_CENTER.y), int(PLANET_RADIUS)],
			"arena": [int(ARENA.x), int(ARENA.y)],
			"runs": _runs,
			"sweep_runs": _sweep_runs,
		},
	}
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()
	print(JSON.stringify(payload))
	get_tree().quit(0)
