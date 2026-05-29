extends Node

signal settings_changed
signal selected_type_changed(type_id: String)
signal behavior_changed(type_id: String)
signal type_config_changed(type_id: String)
signal species_list_changed
signal tool_changed(tool_id: String)
signal obstacles_changed

var simulation_time: float = 0.0
var has_started: bool = false
var selected_type_id: String = "hunter"

var is_recording: bool = false
var recorded_frames: Array = []
var record_timer: float = 0.0
const RECORD_INTERVAL: float = 0.1
var is_replaying: bool = false
var current_replay: Array = []
var replay_time: float = 0.0
var is_exporting: bool = false

const PX_PER_METER := 40.0

const ROBOT_NAMES: Array = [
	"Liam", "Olivia", "Noah", "Emma", "Oliver", "Charlotte", "James", "Amelia", "Elijah", "Ava",
	"William", "Sophia", "Henry", "Isabella", "Lucas", "Mia", "Benjamin", "Evelyn", "Theodore", "Harper",
	"Mateo", "Luna", "Levi", "Camila", "Sebastian", "Gianna", "Daniel", "Elizabeth", "Jack", "Eleanor",
	"Michael", "Ella", "Alexander", "Abigail", "Owen", "Sofia", "Asher", "Avery", "Samuel", "Scarlett",
	"Ethan", "Emily", "Leo", "Aria", "Jackson", "Penelope", "Mason", "Chloe", "Ezra", "Layla",
	"John", "Mila", "Hudson", "Nora", "Luca", "Hazel", "Aiden", "Madison", "Joseph", "Ellie",
	"David", "Lily", "Jacob", "Maya", "Logan", "Isla", "Luke", "Grace", "Julian", "Violet",
	"Gabriel", "Aurora", "Grayson", "Riley", "Wyatt", "Zoey", "Matthew", "Willow", "Isaac", "Emilia",
	"Elias", "Stella", "Anthony", "Zoe", "Carter", "Victoria", "Lincoln", "Hannah", "Dylan", "Lucy",
	"Charles", "Everly", "Thomas", "Anna", "Josiah", "Caroline", "Caleb", "Sadie", "Christopher", "Genesis"
]

func get_random_name() -> String:
	return ROBOT_NAMES[randi() % ROBOT_NAMES.size()]

var robot_types: Array = [
	{"id": "hunter", "name": "Hunter", "color": Color(0.141, 0.255, 0.722, 1.0)},
	{"id": "scout",  "name": "Scout",  "color": Color(0.780, 0.275, 0.180, 1.0)},
	{"id": "worker", "name": "Worker", "color": Color(0.180, 0.541, 0.322, 1.0)},
]

var _next_species_id: int = 1
var _next_robot_id: int = 0

var behaviors: Dictionary = {}

var type_configs: Dictionary = {}

var compiled_rules: Dictionary = {}

var placements: Array = []
var obstacles: Array = []

const TOOL_PLACE := "place_robot"
const TOOL_MEASURE := "measure"
const TOOL_WALL := "wall"
const TOOL_OBSTACLE := "obstacle"

var active_tool: String = TOOL_PLACE

var settings: Dictionary = {
	"speed":          3.75,
	"turn_speed":     2.0,
	"view_distance":  3.75,
	"fov_degrees":    90.0,
	"time_scale":     1.0,
	"arena_width":    1280.0,
	"arena_height":   720.0,
	"controller_mode": false,
	"multiplayer":    false,
}

const BLOCK_DEFS := {
	"set_speed":     {"category": "config",    "label": "Set speed to",        "input": {"min": 0.5,  "max": 10.0, "default": 3.75, "step": 0.05, "suffix": " m/s"}},
	"set_turn":      {"category": "config",    "label": "Set turn rate to",    "input": {"min": 15.0, "max": 360.0, "default": 120.0, "step": 5.0, "suffix": "°/s"}},
	"set_view":      {"category": "config",    "label": "Set vision range to", "input": {"min": 0.5,  "max": 12.5, "default": 3.75, "step": 0.1,  "suffix": " m"}},
	"set_fov":       {"category": "config",    "label": "Set FOV to",          "input": {"min": 20.0, "max": 360.0,"default": 90.0, "step": 1.0,  "suffix": "°"}},

	"when_always":          {"category": "condition", "label": "Always",               "input": null},
	"when_sees":            {"category": "condition", "label": "When I see anyone",    "input": null},
	"when_alone":           {"category": "condition", "label": "When I see nobody",    "input": null},
	"when_near_wall":       {"category": "condition", "label": "When I touch a wall",  "input": null},
	"when_sees_wall":       {"category": "condition", "label": "When I see a wall",    "input": null},
	"when_sees_species":    {"category": "condition", "label": "When I see a",         "input": {"type": "species", "default": "hunter"}},
	"when_no_sees_species": {"category": "condition", "label": "When I don't see a",   "input": {"type": "species", "default": "hunter"}},
	"when_sees_enemy":      {"category": "condition", "label": "When I see an enemy",  "input": null},
	"when_sees_ally":       {"category": "condition", "label": "When I see an ally",   "input": null},
	"when_sees_object":     {"category": "condition", "label": "When I see an object",    "input": null},
	"when_sees_rim":        {"category": "condition", "label": "When I see the outer rim", "input": null},

	"do_forward":    {"category": "action", "label": "Move forward",    "input": null},
	"do_backward":   {"category": "action", "label": "Move backward",   "input": null},
	"do_stop":       {"category": "action", "label": "Stop",            "input": null},
	"do_wander":     {"category": "action", "label": "Wander randomly", "input": null},
	"do_random_walk":{"category": "action", "label": "Random walk",     "input": null},
	"do_turn_left":  {"category": "action", "label": "Turn left at",    "input": {"min": 15.0, "max": 360.0, "default": 90.0, "step": 5.0, "suffix": "°/s"}},
	"do_turn_right": {"category": "action", "label": "Turn right at",   "input": {"min": 15.0, "max": 360.0, "default": 90.0, "step": 5.0, "suffix": "°/s"}},
	"do_turn_left_by":  {"category": "action", "label": "Turn left by",  "input": {"min": 1.0, "max": 360.0, "default": 180.0, "step": 1.0, "suffix": "°"}},
	"do_turn_right_by": {"category": "action", "label": "Turn right by", "input": {"min": 1.0, "max": 360.0, "default": 180.0, "step": 1.0, "suffix": "°"}},
	"do_face":       {"category": "action", "label": "Face the target",  "input": null},
	"do_flee":       {"category": "action", "label": "Flee the target",  "input": null},
	"do_fire":       {"category": "action", "label": "Fire",             "input": null},
	"do_throttle":   {"category": "action", "label": "Throttle to",     "input": {"min": 0.0, "max": 1.5, "default": 1.0, "step": 0.05, "suffix": "×"}},
}

const PALETTE_ORDER := {
	"config":    ["set_speed", "set_turn", "set_view", "set_fov"],
	"condition": ["when_always", "when_sees", "when_alone", "when_near_wall", "when_sees_wall", "when_sees_species", "when_no_sees_species"],
	"action":    ["do_forward", "do_backward", "do_stop", "do_wander", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_flee", "do_throttle"],
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_defaults()
	for t in robot_types:
		compile(t.id)

func _install_defaults():
	behaviors["hunter"] = {"blocks": [
		{"type": "set_speed", "params": {"value": 5.25}},
		{"type": "set_turn",  "params": {"value": 170.0}},
		{"type": "set_view",  "params": {"value": 5.5}},
		{"type": "set_fov",   "params": {"value": 55.0}},
		{"type": "when_sees", "params": {}},
		{"type": "do_face",   "params": {}},
		{"type": "when_always", "params": {}},
		{"type": "do_forward", "params": {}},
	]}
	behaviors["scout"] = {"blocks": [
		{"type": "set_speed", "params": {"value": 3.75}},
		{"type": "set_turn",  "params": {"value": 115.0}},
		{"type": "set_view",  "params": {"value": 4.5}},
		{"type": "set_fov",   "params": {"value": 110.0}},
		{"type": "when_always", "params": {}},
		{"type": "do_wander",   "params": {}},
		{"type": "do_forward",  "params": {}},
	]}
	behaviors["worker"] = {"blocks": [
		{"type": "set_speed", "params": {"value": 2.4}},
		{"type": "set_turn",  "params": {"value": 80.0}},
		{"type": "set_view",  "params": {"value": 3.25}},
		{"type": "set_fov",   "params": {"value": 180.0}},
		{"type": "when_sees",   "params": {}},
		{"type": "do_flee",     "params": {}},
		{"type": "when_always", "params": {}},
		{"type": "do_forward",  "params": {}},
	]}

func _process(delta: float):
	if has_started and not get_tree().paused and not is_replaying:
		simulation_time += delta * settings.time_scale

func get_type(type_id: String) -> Dictionary:
	for t in robot_types:
		if t.id == type_id:
			return t
	if robot_types.size() > 0:
		return robot_types[0]
	return {"id": "", "name": "", "color": Color.WHITE}

func get_type_config(type_id: String) -> Dictionary:
	return type_configs.get(type_id, {
		"speed": settings.speed * PX_PER_METER,
		"turn_speed": settings.turn_speed,
		"view_distance": settings.view_distance * PX_PER_METER,
		"fov_degrees": settings.fov_degrees,
	})

func get_compiled_rules(type_id: String) -> Array:
	return compiled_rules.get(type_id, [])

func get_blocks(type_id: String) -> Array:
	return behaviors.get(type_id, {}).get("blocks", [])

func set_blocks(type_id: String, blocks: Array):
	behaviors[type_id] = {"blocks": blocks.duplicate(true)}
	compile(type_id)
	behavior_changed.emit(type_id)
	type_config_changed.emit(type_id)

func compile(type_id: String):
	var blocks: Array = behaviors.get(type_id, {}).get("blocks", [])
	var cfg := {
		"speed":          settings.speed * PX_PER_METER,
		"turn_speed":     settings.turn_speed,
		"view_distance":  settings.view_distance * PX_PER_METER,
		"fov_degrees":    settings.fov_degrees,
	}
	var rules: Array = []
	var current_rule = null
	for b in blocks:
		var t: String = b.get("type", "")
		var p: Dictionary = b.get("params", {})
		match t:
			"set_speed":  cfg.speed         = float(p.get("value", settings.speed)) * PX_PER_METER
			"set_turn":   cfg.turn_speed    = deg_to_rad(float(p.get("value", 120.0)))
			"set_view":   cfg.view_distance = float(p.get("value", settings.view_distance)) * PX_PER_METER
			"set_fov":    cfg.fov_degrees   = float(p.get("value", settings.fov_degrees))
			"when_always", "when_sees", "when_alone", "when_near_wall", "when_sees_wall", "when_sees_species", "when_no_sees_species", "when_sees_enemy", "when_sees_ally", "when_sees_object", "when_sees_rim":
				current_rule = {"condition": t.substr(5), "condition_params": p.duplicate(), "actions": []}
				rules.append(current_rule)
			_:
				if t.begins_with("do_"):
					if current_rule == null:
						current_rule = {"condition": "always", "condition_params": {}, "actions": []}
						rules.append(current_rule)
					current_rule.actions.append({"id": t.substr(3), "params": p.duplicate()})
	type_configs[type_id] = cfg
	compiled_rules[type_id] = rules

func set_selected_type(type_id: String):
	selected_type_id = type_id
	selected_type_changed.emit(type_id)

func set_active_tool(tool_id: String):
	if active_tool == tool_id:
		return
	active_tool = tool_id
	tool_changed.emit(tool_id)

func add_obstacle(data: Dictionary):
	obstacles.append(data)
	obstacles_changed.emit()

func clear_obstacles():
	obstacles.clear()
	obstacles_changed.emit()

func update_setting(key: String, value):
	settings[key] = value
	for t in robot_types:
		compile(t.id)
	settings_changed.emit()

func reset_time():
	simulation_time = 0.0
	has_started = false

func next_robot_id() -> int:
	var id := _next_robot_id
	_next_robot_id += 1
	return id

func add_placement(type_id: String, pos: Vector2, rot: float):
	placements.append({"type_id": type_id, "id": next_robot_id(), "position": pos, "rotation": rot})

func clear_placements():
	placements.clear()
	reset_time()

func clear_all_arena():
	placements.clear()
	obstacles.clear()
	obstacles_changed.emit()
	reset_time()


func add_species(species_name: String, color: Color) -> String:
	var id := "species_%d" % _next_species_id
	_next_species_id += 1
	robot_types.append({"id": id, "name": species_name, "color": color})
	behaviors[id] = {"blocks": [
		{"type": "set_speed", "params": {"value": 3.75}},
		{"type": "set_view",  "params": {"value": 3.75}},
		{"type": "when_always", "params": {}},
		{"type": "do_wander",   "params": {}},
		{"type": "do_forward",  "params": {}},
	]}
	compile(id)
	species_list_changed.emit()
	return id

func remove_species(type_id: String):
	if robot_types.size() <= 1:
		return
	robot_types = robot_types.filter(func(t): return t.id != type_id)
	behaviors.erase(type_id)
	type_configs.erase(type_id)
	compiled_rules.erase(type_id)
	placements = placements.filter(func(p): return p.type_id != type_id)
	if selected_type_id == type_id:
		selected_type_id = robot_types[0].id
		selected_type_changed.emit(selected_type_id)
	species_list_changed.emit()

func set_species_color(type_id: String, color: Color):
	for t in robot_types:
		if t.id == type_id:
			t.color = color
			break
	species_list_changed.emit()

func set_species_name(type_id: String, new_name: String):
	for t in robot_types:
		if t.id == type_id:
			t.name = new_name
			break
	species_list_changed.emit()

func get_setup_data() -> Dictionary:
	return {
		"robot_types": robot_types,
		"behaviors": behaviors,
		"type_configs": type_configs,
		"compiled_rules": compiled_rules,
		"placements": placements,
		"obstacles": obstacles,
		"settings": settings,
	}

func save_setup(path: String):
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_var(get_setup_data())

func load_setup(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var data = f.get_var()
	if typeof(data) == TYPE_DICTIONARY:
		robot_types = data.get("robot_types", robot_types)
		behaviors = data.get("behaviors", behaviors)
		placements = data.get("placements", placements)
		obstacles = data.get("obstacles", [])
		settings = data.get("settings", settings)
		_resync_species_counter()
		_normalize_placement_ids()
		for t in robot_types:
			compile(t.id)

		species_list_changed.emit()
		settings_changed.emit()
		obstacles_changed.emit()
		return true
	return false

func _resync_species_counter():
	var max_id := 0
	for t in robot_types:
		var id: String = t.get("id", "")
		if id.begins_with("species_"):
			var n := int(id.substr(8))
			if n > max_id:
				max_id = n
	_next_species_id = max_id + 1

func _normalize_placement_ids():
	var max_id := -1
	for p in placements:
		if p.has("id"):
			max_id = maxi(max_id, int(p["id"]))
	for p in placements:
		if not p.has("id"):
			max_id += 1
			p["id"] = max_id
	_next_robot_id = max_id + 1

func load_run(path: String) -> bool:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var data = f.get_var()
	if typeof(data) == TYPE_DICTIONARY and data.has("setup") and data.has("frames"):
		var setup = data["setup"]
		robot_types = setup.get("robot_types", robot_types)
		behaviors = setup.get("behaviors", behaviors)
		placements = setup.get("placements", placements)
		obstacles = setup.get("obstacles", [])
		settings = setup.get("settings", settings)
		_resync_species_counter()
		_normalize_placement_ids()
		for t in robot_types:
			compile(t.id)

		species_list_changed.emit()
		settings_changed.emit()
		obstacles_changed.emit()

		current_replay = data["frames"]
		is_replaying = true
		replay_time = 0.0
		is_exporting = false
		return true
	return false

func export_run(path: String) -> bool:
	if load_run(path):
		is_exporting = true
		return true
	return false

func start_recording():
	is_recording = true
	is_replaying = false
	recorded_frames.clear()
	record_timer = 0.0

func _make_run_filename() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var base: String = "Run_%04d-%02d-%02d_%02dh%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
	var candidate: String = base + ".run"
	var n: int = 2
	while FileAccess.file_exists("user://runs/" + candidate):
		candidate = "%s_(%d).run" % [base, n]
		n += 1
	return candidate

func stop_recording_and_save():
	if not is_recording: return
	is_recording = false

	if recorded_frames.is_empty(): return

	DirAccess.make_dir_absolute("user://runs")
	var filename: String = _make_run_filename()
	var path: String = "user://runs/" + filename

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_var({
			"setup": get_setup_data(),
			"frames": recorded_frames
		})
	print("Saved run to ", path)

func _physics_process(delta: float):
	if is_exporting: return
	if not has_started or get_tree().paused: return

	if is_replaying:
		replay_time += delta * settings.get("time_scale", 1.0)
		var idx = int(replay_time / RECORD_INTERVAL)
		if idx < current_replay.size():
			_apply_replay_frame(current_replay[idx])
		else:
			get_tree().paused = true
			has_started = false

	elif is_recording:
		record_timer += delta * settings.get("time_scale", 1.0)
		if record_timer >= RECORD_INTERVAL:
			record_timer -= RECORD_INTERVAL
			var frame = []
			for r in get_tree().get_nodes_in_group("robots"):
				frame.append({
					"id": r.spawn_id,
					"pos": r.global_position,
					"rot": r.rotation
				})
			recorded_frames.append(frame)

func _apply_replay_frame(frame: Array):
	var robots := get_tree().get_nodes_in_group("robots")
	var by_id := {}
	for r in robots:
		by_id[r.spawn_id] = r
	for k in frame.size():
		var entry: Dictionary = frame[k]
		var target = null
		if entry.has("id"):
			target = by_id.get(int(entry["id"]), null)
		elif k < robots.size():
			target = robots[k]
		if target != null:
			target.global_position = entry["pos"]
			target.rotation = entry["rot"]
