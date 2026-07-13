extends "res://simulations/farp/BenchBase.gd"

func start():
	var run = _read_json(_run_path)
	if typeof(run) == TYPE_DICTIONARY and run.has("run"):
		run = run["run"]
	if typeof(run) != TYPE_DICTIONARY:
		push_error("[bench] level 3 render needs a recorded run (--run=<file>)")
		get_tree().quit(1)
		return

	var frames: Array = run.get("frames", [])
	print("[bench] render level=%s frames=%d outcome=%s" % [_level_id, frames.size(), run.get("outcome", "timeout")])
	print("PROGRESS 1/1 stage=Rendering piloted run")

	var payload := {
		"trials": 1,
		"level_id": _level_id,
		"results": {
			"trials": 1,
			"outcomes": [run.get("outcome", "timeout")],
			"detection_times": [run.get("detection_time", -1.0)],
			"capture_times": [run.get("capture_time", -1.0)],
			"goal_times": [run.get("goal_time", -1.0)],
			"sweep": [],
		},
		"replays": {
			"fps": int(run.get("fps", 30)),
			"defenders": int(run.get("defenders", 0)),
			"view": int(run.get("view", 300)),
			"fov": int(run.get("fov", 70)),
			"planet": run.get("planet", [int(PLANET_CENTER.x), int(PLANET_CENTER.y), int(PLANET_RADIUS)]),
			"arena": run.get("arena", [int(ARENA.x), int(ARENA.y)]),
			"runs": [{
				"trial": 0,
				"outcome": run.get("outcome", "timeout"),
				"detection_time": run.get("detection_time", -1.0),
				"capture_time": run.get("capture_time", -1.0),
				"goal_time": run.get("goal_time", -1.0),
				"frames": frames,
			}],
			"sweep_runs": [],
		},
	}
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()
	print(JSON.stringify(payload))
	get_tree().quit(0)
