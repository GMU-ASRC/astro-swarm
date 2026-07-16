extends Node

const SHIP := preload("res://entities/ship/Spaceship.tscn")
const SIM := preload("res://autoloads/SimulationManager.gd")

const ARENA         := Vector2(3840.0, 2160.0)
const PLANET_CENTER := Vector2(1920.0, 1080.0)
const PLANET_RADIUS := 120.0
const GOAL_MARGIN   := 16.0
const MAX_DEFENDERS := 6
const DEFENDER_HP   := 99.0
const ENEMY_HP      := 3.0
const ENEMY_SPEED   := 105.0
const ENEMY_PROGRAM := [
	{"type": "when_always", "params": {}},
	{"type": "do_forward", "params": {}},
]

const DEFAULT_TRIALS := 100
const DEFAULT_SWEEP_MAX    := 100
const DEFAULT_SWEEP_TRIALS := 10
const DEFAULT_SEED         := 987654321
const DEFAULT_MATCH_SECONDS := 4 * 60.0
const DEFAULT_GOAL_TAIL_SECONDS := 3.0
const SWEEP_RADIUS  := 300.0
const PLACE_MIN     := PLANET_RADIUS + 50.0
const PLACE_MAX     := 465.0
const SCATTER_MAX   := 250.0
const SCATTER_SPACING := 110.0
const SCATTER_ATTEMPTS := 40
const RING_COUNT    := 5
const ENEMY_SPAWN_RADIUS := 1000.0
const RECORD_EVERY   := 1
const REPLAY_SWEEP_N_MAX  := 50
const REPLAY_SWEEP_TRIALS := 10
const SWEEP_SEED_OFFSET := 100000
const SWEEP_SEED_STRIDE := 1000000
const SWEEP_MATCH_OFFSET := 500000

enum Phase { PLACEMENT, SWEEP }

var _algorithm: Array = []
var _placements: Array = []
var _trials: int = DEFAULT_TRIALS
var _sweep_max: int = DEFAULT_SWEEP_MAX
var _sweep_trials: int = DEFAULT_SWEEP_TRIALS
var _seed: int = DEFAULT_SEED
var _match_seconds: float = DEFAULT_MATCH_SECONDS
var _goal_tail_seconds: float = DEFAULT_GOAL_TAIL_SECONDS
var _trial_start: int = 0
var _trial_count: int = -1
var _n_start: int = 1
var _n_count: int = -1
var _enemy_start: Vector2 = Vector2(-1.0, -1.0)
var _out_path: String = "user://farp_bench.json"
var _run_path: String = ""
var _level_id: String = "farp1"

var _spawn_rng := RandomNumberGenerator.new()
var _orient_rng := RandomNumberGenerator.new()
var _spawn_points: Array = []

var _world: Node2D
var _defenders: Array = []
var _enemy: Node2D = null
var _frame: int = 0
var _match_frames: int = 0
var _goal_tail_frames: int = 0

var _phase: int = Phase.PLACEMENT
var _current_trial: int = 0
var _success_count: int = 0
var _global_done: int = 0
var _global_total: int = 1

var _replay_view: float = 300.0
var _replay_fov: float = 70.0
var _replay_speed: float = 150.0
var _outcomes: Array = []
var _detection_times: Array = []
var _capture_times: Array = []
var _goal_times: Array = []
var _runs: Array = []
var _replay_frames: Array = []

var _sweep_n: int = 1
var _sweep_success: int = 0
var _sweep_points: Array = []
var _sweep_runs: Array = []
var _sweep_detect_count: int = 0
var _sweep_capture_count: int = 0
var _sweep_first_outcome: String = "timeout"
var _sweep_first_detect: float = -1.0
var _sweep_first_capture: float = -1.0
var _sweep_first_goal: float = -1.0
var _sweep_first_frames: Array = []
var _sweep_trial_runs: Array = []
var _sweep_seeds: Array = []
var _recording: bool = true

var _collisions: bool = false

var _detect_frame: int = -1
var _capture_frame: int = -1
var _goal_frame: int = -1
var _end_frame: int = -1
var _running: bool = false

func start():
	_running = true
	if _trial_count < 0:
		_trial_count = _trials
	if _n_count < 0:
		_n_count = _sweep_max
	_build_spawn_points()
	_build_sweep_seeds()
	if _enemy_start.x < 0.0 or _enemy_start.y < 0.0:
		_enemy_start = _spawn_points[0]
	_match_frames = int(_match_seconds * Engine.physics_ticks_per_second)
	_goal_tail_frames = int(_goal_tail_seconds * Engine.physics_ticks_per_second)
	_global_total = maxi(1, _trial_count + _n_count * _sweep_trials)
	print("[bench] start level=%s defenders=%d trials=%d trial_start=%d trial_count=%d n_start=%d n_count=%d seed=%d" % [_level_id, _placements.size(), _trials, _trial_start, _trial_count, _n_start, _n_count, _seed])
	_world = Node2D.new()
	add_child(_world)
	_phase = Phase.PLACEMENT
	_current_trial = _trial_start
	if _trial_count > 0:
		_start_match()
	else:
		_begin_sweep()

func parse_args():
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--algorithm="):
			_load_algorithm(arg.split("=", true, 1)[1])
		elif arg.begins_with("--placements="):
			_load_placements(arg.split("=", true, 1)[1])
		elif arg.begins_with("--run="):
			_run_path = arg.split("=", true, 1)[1]
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
		elif arg.begins_with("--match-seconds="):
			_match_seconds = maxf(1.0, float(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--goal-tail-seconds="):
			_goal_tail_seconds = maxf(0.0, float(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--trial-start="):
			_trial_start = maxi(0, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--trial-count="):
			_trial_count = maxi(0, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--n-start="):
			_n_start = maxi(1, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--n-count="):
			_n_count = maxi(0, int(arg.split("=", true, 1)[1]))
		elif arg.begins_with("--enemy-x="):
			_enemy_start.x = float(arg.split("=", true, 1)[1])
		elif arg.begins_with("--enemy-y="):
			_enemy_start.y = float(arg.split("=", true, 1)[1])
		elif arg.begins_with("--level-id="):
			_level_id = arg.split("=", true, 1)[1]
		elif arg.begins_with("--collisions="):
			_collisions = int(arg.split("=", true, 1)[1]) != 0
	if _algorithm.is_empty():
		_algorithm = SIM.normalize_to_scripts(PlayerData.DEFAULT_SHIP_BLOCKS)
	if _placements.size() > MAX_DEFENDERS:
		_placements.resize(MAX_DEFENDERS)

func _load_algorithm(path: String):
	var data = _read_json(path)
	if typeof(data) == TYPE_DICTIONARY and data.has("algorithm"):
		data = data["algorithm"]
	if typeof(data) == TYPE_ARRAY:
		_algorithm = SIM.normalize_to_scripts(data)

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
	var count: int = maxi(1, _trials)
	for i in count:
		var angle: float = (float(i) + 0.2 + _spawn_rng.randf() * 0.6) / float(count) * TAU
		_spawn_points.append(PLANET_CENTER + Vector2(ENEMY_SPAWN_RADIUS, 0.0).rotated(angle))

func _build_sweep_seeds():
	_sweep_seeds.clear()
	for trial in _sweep_trials:
		_sweep_seeds.append(_seed + SWEEP_SEED_OFFSET + trial * SWEEP_SEED_STRIDE)

func _sweep_trial_seed(trial: int) -> int:
	if _sweep_seeds.is_empty():
		return _seed + SWEEP_SEED_OFFSET
	return _sweep_seeds[trial % _sweep_seeds.size()]

func _ring_placements(count: int) -> Array:
	var out: Array = []
	_orient_rng.seed = _sweep_trial_seed(_current_trial) + count
	var ring_offset: float = _orient_rng.randf() * TAU
	for i in count:
		var angle: float = ring_offset + TAU * float(i) / float(count)
		out.append({
			"pos": PLANET_CENTER + Vector2(SWEEP_RADIUS, 0.0).rotated(angle),
			"rot": _orient_rng.randf() * TAU,
		})
	return out

func _placements_for_trial(_trial: int) -> Array:
	return _placements

func _defender_count() -> int:
	return _placements.size()

func _start_match():
	_clear_world()
	_frame = 0
	_detect_frame = -1
	_capture_frame = -1
	_goal_frame = -1
	_end_frame = -1
	_replay_frames = []
	var placements: Array
	var spawn_pos: Vector2
	if _phase == Phase.PLACEMENT:
		_recording = true
		placements = _placements_for_trial(_current_trial)
		spawn_pos = _spawn_points[_current_trial % _spawn_points.size()]
		seed(_seed + _current_trial)
	else:
		_recording = _current_trial == 0 or _is_replay_trial()
		placements = _ring_placements(_sweep_n)
		spawn_pos = _enemy_start
		seed(_sweep_trial_seed(_current_trial) + SWEEP_MATCH_OFFSET + _sweep_n)
	_spawn_defenders(placements)
	_spawn_enemy(spawn_pos)
	if _recording:
		_replay_frames.append(_snapshot())

func _spawn_defenders(placements: Array):
	var planet_center: Vector2 = PLANET_CENTER if _collisions else Vector2.ZERO
	var planet_r: float = PLANET_RADIUS if _collisions else 0.0
	for placement in placements:
		var ship := SHIP.instantiate()
		ship.setup_player(_algorithm, DEFENDER_HP)
		ship.set_obstacles(Vector2.ZERO, 0.0, planet_center, planet_r)
		ship.collisions_enabled = _collisions
		ship.arena_size = ARENA
		ship.can_fire = false
		ship.visible = false
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
		_replay_speed = ship.max_speed
		_defenders.append(ship)

func _spawn_enemy(spawn_pos: Vector2):
	_enemy = SHIP.instantiate()
	_enemy.setup_raider(ENEMY_PROGRAM, ENEMY_HP)
	_enemy.speed_mult = ENEMY_SPEED / 150.0
	_enemy.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	_enemy.collisions_enabled = false
	_enemy.is_evader = true
	_enemy.arena_size = ARENA
	_enemy.visible = false
	_world.add_child(_enemy)
	_enemy.global_position = spawn_pos
	_enemy.rotation = (PLANET_CENTER - spawn_pos).angle()

func _physics_process(_delta: float):
	if not _running:
		return
	_frame += 1
	if _recording and _frame % RECORD_EVERY == 0 and (_end_frame < 0 or _frame <= _end_frame):
		_replay_frames.append(_snapshot())

	if _detect_frame < 0 and _any_defender_sees_enemy():
		_detect_frame = _frame
	if _capture_frame < 0 and _any_defender_touches_enemy():
		_capture_frame = _frame
	if _goal_frame < 0 and _enemy_at_goal():
		_goal_frame = _frame
		_end_frame = _frame + _goal_tail_frames

	var finished: bool = (_end_frame >= 0 and _frame >= _end_frame) \
		or _enemy_reached_far_edge() \
		or _frame >= _match_frames
	if finished:
		if _phase == Phase.PLACEMENT:
			_finish_placement_match()
		else:
			_finish_sweep_match()

func _frame_to_time(frame: int) -> float:
	if frame < 0:
		return -1.0
	return snappedf(float(frame) / float(Engine.physics_ticks_per_second), 0.01)

func _enemy_at_goal() -> bool:
	if not is_instance_valid(_enemy):
		return false
	return _enemy.global_position.distance_to(PLANET_CENTER) <= PLANET_RADIUS + GOAL_MARGIN

func _enemy_reached_far_edge() -> bool:
	if not is_instance_valid(_enemy):
		return true
	if _frame < 30:
		return false
	var p: Vector2 = _enemy.global_position
	return p.x <= 16.0 or p.y <= 16.0 or p.x >= ARENA.x - 16.0 or p.y >= ARENA.y - 16.0

func _classify() -> String:
	var captured_before_goal: bool = _capture_frame >= 0 and (_goal_frame < 0 or _capture_frame <= _goal_frame)
	if captured_before_goal:
		return "win"
	if _goal_frame >= 0:
		return "lose"
	return "timeout"

func _finish_placement_match():
	var outcome: String = _classify()
	_runs.append({
		"trial": _current_trial,
		"outcome": outcome,
		"detection_time": _frame_to_time(_detect_frame),
		"capture_time": _frame_to_time(_capture_frame),
		"goal_time": _frame_to_time(_goal_frame),
		"frames": _replay_frames,
	})
	_outcomes.append(outcome)
	_detection_times.append(_frame_to_time(_detect_frame))
	_capture_times.append(_frame_to_time(_capture_frame))
	_goal_times.append(_frame_to_time(_goal_frame))
	if outcome == "win":
		_success_count += 1
	_advance(outcome)

func _finish_sweep_match():
	var outcome: String = _classify()
	if _detect_frame >= 0:
		_sweep_detect_count += 1
	if _capture_frame >= 0:
		_sweep_capture_count += 1
	if _current_trial == 0:
		_sweep_first_outcome = outcome
		_sweep_first_detect = _frame_to_time(_detect_frame)
		_sweep_first_capture = _frame_to_time(_capture_frame)
		_sweep_first_goal = _frame_to_time(_goal_frame)
		_sweep_first_frames = _replay_frames
	if _is_replay_trial():
		_sweep_trial_runs.append({
			"trial": _current_trial,
			"outcome": outcome,
			"detection_time": _frame_to_time(_detect_frame),
			"capture_time": _frame_to_time(_capture_frame),
			"goal_time": _frame_to_time(_goal_frame),
			"frames_packed": _pack_frames(_replay_frames),
		})
	if outcome == "win":
		_sweep_success += 1
	_advance("sweep n=%d" % _sweep_n)

func _is_replay_trial() -> bool:
	return _sweep_n < REPLAY_SWEEP_N_MAX and _current_trial < REPLAY_SWEEP_TRIALS

func _pack_frames(frames: Array) -> String:
	if frames.is_empty():
		return ""
	var deltas: Array = [frames[0]]
	for i in range(1, frames.size()):
		var previous: Array = frames[i - 1]
		var current: Array = frames[i]
		var delta: Array = []
		for j in current.size():
			delta.append(current[j] - previous[j])
		deltas.append(delta)
	var raw: PackedByteArray = JSON.stringify(deltas).to_utf8_buffer()
	return Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))

func _advance(label: String):
	_global_done += 1
	_current_trial += 1
	var stage: String
	if _phase == Phase.PLACEMENT:
		var done_here: int = _current_trial - _trial_start
		stage = "Placement: trial %d/%d (last %s)" % [done_here, _trial_count, label]
	else:
		var n_index: int = _sweep_n - _n_start + 1
		stage = "Ring sweep: %d defenders (n %d/%d), trial %d/%d [detect %d, capture %d]" % [_sweep_n, n_index, _n_count, _current_trial, _sweep_trials, _sweep_detect_count, _sweep_capture_count]
	print("PROGRESS %d/%d stage=%s" % [_global_done, _global_total, stage])

	if _phase == Phase.PLACEMENT:
		if _current_trial >= _trial_start + _trial_count:
			_begin_sweep()
			return
		_start_match()
		return

	if _current_trial >= _sweep_trials:
		var rate: float = 100.0 * float(_sweep_success) / float(maxi(1, _sweep_trials))
		_sweep_points.append({"n": _sweep_n, "success_rate": snappedf(rate, 0.1)})
		var detect_rate: float = 100.0 * float(_sweep_detect_count) / float(maxi(1, _sweep_trials))
		var capture_rate: float = 100.0 * float(_sweep_capture_count) / float(maxi(1, _sweep_trials))
		_sweep_runs.append({
			"n": _sweep_n,
			"outcome": _sweep_first_outcome,
			"detection_time": _sweep_first_detect,
			"capture_time": _sweep_first_capture,
			"goal_time": _sweep_first_goal,
			"detection_rate": snappedf(detect_rate, 0.1),
			"capture_rate": snappedf(capture_rate, 0.1),
			"defenders": _sweep_n,
			"frames": _sweep_first_frames,
			"trial_runs": _sweep_trial_runs,
		})
		_sweep_n += 1
		if _sweep_n >= _n_start + _n_count:
			_write_output()
			return
		_sweep_success = 0
		_sweep_detect_count = 0
		_sweep_capture_count = 0
		_sweep_first_frames = []
		_sweep_trial_runs = []
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
		if absf(angle_difference(ship.rotation, to_enemy.angle())) <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

func _any_defender_touches_enemy() -> bool:
	if not is_instance_valid(_enemy):
		return false
	for ship in _defenders:
		if not is_instance_valid(ship):
			continue
		if ship.global_position.distance_to(_enemy.global_position) <= ship.hull_radius + _enemy.hull_radius:
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
		"level_id": _level_id,
		"results": {
			"trials": _trials,
			"success_rate": snappedf(success_rate, 0.1),
			"outcomes": _outcomes,
			"detection_times": _detection_times,
			"capture_times": _capture_times,
			"goal_times": _goal_times,
			"sweep": _sweep_points,
		},
		"replays": {
			"fps": floori(float(Engine.physics_ticks_per_second) / float(RECORD_EVERY)),
			"defenders": _defender_count(),
			"view": int(_replay_view),
			"fov": int(_replay_fov),
			"speed": int(_replay_speed),
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
