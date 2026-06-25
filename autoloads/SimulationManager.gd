extends Node

signal settings_changed
signal selected_type_changed(type_id: String)
signal behavior_changed(type_id: String)
signal type_config_changed(type_id: String)
signal species_list_changed
signal tool_changed(tool_id: String)
signal obstacles_changed
signal variables_changed

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
var pending_upload: bool = false
var pending_upload_run: String = ""

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
var _next_obstacle_id: int = 0

var behaviors: Dictionary = {}

var type_configs: Dictionary = {}

var placements: Array = []
var obstacles: Array = []

var variables: Array = []
var var_values: Dictionary = {}

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
	"set_size":      {"category": "config",    "label": "Set size to",         "input": {"min": 2.0,  "max": 16.0, "default": 6.0,  "step": 0.5,  "suffix": " px"}},

	"when_start":           {"category": "condition", "label": "On start",             "input": null},
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

	"if_sees":           {"category": "logic", "label": "If I see anyone",  "input": null},
	"if_sees_species":   {"category": "logic", "label": "If I see a",       "input": {"type": "species", "default": "hunter"}},
	"if_within":         {"category": "logic", "label": "If target within", "input": {"min": 0.5, "max": 12.5, "default": 3.0, "step": 0.1, "suffix": " m"}},
	"if_beyond":         {"category": "logic", "label": "If target beyond", "input": {"min": 0.5, "max": 12.5, "default": 3.0, "step": 0.1, "suffix": " m"}},
	"if_see":            {"category": "logic", "label": "If I see", "inputs": [
		{"type": "dropdown", "key": "target", "provider": "targets"},
	]},
	"if_compare":        {"category": "logic", "label": "If", "inputs": [
		{"type": "dropdown", "key": "var", "provider": "variables"},
		{"type": "dropdown", "key": "op", "provider": "operators"},
		{"type": "number", "key": "value", "min": -99999.0, "max": 99999.0, "step": 1.0, "default": 0.0},
	]},
	"else":              {"category": "logic", "label": "Else", "input": null},

	"set_var":           {"category": "variable", "label": "Set", "inputs": [
		{"type": "dropdown", "key": "var", "provider": "variables"},
		{"type": "label", "text": "to"},
		{"type": "number", "key": "value", "min": -99999.0, "max": 99999.0, "step": 1.0, "default": 0.0},
	]},
	"set_var_random":    {"category": "variable", "label": "Set", "inputs": [
		{"type": "dropdown", "key": "var", "provider": "variables"},
		{"type": "label", "text": "to random"},
		{"type": "number", "key": "min", "min": -99999.0, "max": 99999.0, "step": 1.0, "default": 1.0},
		{"type": "label", "text": "to"},
		{"type": "number", "key": "max", "min": -99999.0, "max": 99999.0, "step": 1.0, "default": 5.0},
	]},

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
	"do_stop_sim":   {"category": "action", "label": "Stop simulation",  "input": null},
	"do_pause_sim":  {"category": "action", "label": "Pause simulation", "input": null},
}

const PALETTE_ORDER := {
	"config":    ["set_speed", "set_turn", "set_view", "set_fov", "set_size"],
	"condition": ["when_start", "when_always", "when_sees", "when_alone", "when_near_wall", "when_sees_wall", "when_sees_species", "when_no_sees_species"],
	"logic":     ["if_see", "if_within", "if_beyond", "if_compare", "else"],
	"variable":  ["set_var", "set_var_random"],
	"action":    ["do_forward", "do_backward", "do_stop", "do_random_walk", "do_turn_left", "do_turn_right", "do_turn_left_by", "do_turn_right_by", "do_face", "do_flee", "do_throttle", "do_stop_sim", "do_pause_sim"],
}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_defaults()
	_normalize_all_behaviors()
	for t in robot_types:
		compile(t.id)

static func normalize_blocks(blocks: Array) -> Array:
	if blocks.is_empty():
		return []
	if blocks[0] is Dictionary and blocks[0].has("children"):
		return _rebuild_nested(blocks)
	var result: Array = []
	var current = null
	for b in blocks:
		var t: String = b.get("type", "")
		var node := {"type": t, "params": (b.get("params", {}) as Dictionary).duplicate(true), "children": []}
		if t.begins_with("when_"):
			current = node
			result.append(node)
		elif t.begins_with("do_") and current != null:
			current.children.append(node)
		else:
			current = null
			result.append(node)
	return result

static func _rebuild_nested(blocks: Array) -> Array:
	var result: Array = []
	for b in blocks:
		result.append({
			"type": b.get("type", ""),
			"params": (b.get("params", {}) as Dictionary).duplicate(true),
			"children": _rebuild_nested(b.get("children", [])),
		})
	return result

static func normalize_to_scripts(data) -> Array:
	if data is Dictionary:
		if data.has("scripts"):
			return _rebuild_scripts(data["scripts"])
		if data.has("blocks"):
			return _split_into_stacks(normalize_blocks(data["blocks"]))
		return []
	if data is Array:
		if data.is_empty():
			return []
		if data[0] is Dictionary and data[0].has("blocks"):
			return _rebuild_scripts(data)
		return _split_into_stacks(normalize_blocks(data))
	return []

static func _rebuild_scripts(scripts: Array) -> Array:
	var result: Array = []
	var y_fallback := 40.0
	for s in scripts:
		result.append({
			"x": float(s.get("x", 40.0)),
			"y": float(s.get("y", y_fallback)),
			"blocks": _rebuild_nested(s.get("blocks", [])),
		})
		y_fallback += 150.0
	return result

static func _split_into_stacks(nested: Array) -> Array:
	var configs: Array = []
	var heads: Array = []
	for node in nested:
		var nt: String = node.get("type", "")
		if nt.begins_with("set_"):
			configs.append(node)
		else:
			heads.append(node)
	var ordered: Array = []
	if not configs.is_empty():
		ordered.append({"type": "when_start", "params": {}, "children": configs})
	ordered.append_array(heads)

	var result: Array = []
	for i in ordered.size():
		var col: int = i % 2
		@warning_ignore("integer_division")
		var row: int = i / 2
		result.append({"x": 40.0 + col * 400.0, "y": 30.0 + row * 280.0, "blocks": [ordered[i]]})
	return result

func _normalize_all_behaviors():
	for id in behaviors.keys():
		behaviors[id] = {"scripts": normalize_to_scripts(behaviors[id])}

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
		"dot_radius": 6.0,
	})

func get_scripts(type_id: String) -> Array:
	return behaviors.get(type_id, {}).get("scripts", [])

func set_scripts(type_id: String, scripts: Array):
	behaviors[type_id] = {"scripts": normalize_to_scripts(scripts)}
	compile(type_id)
	behavior_changed.emit(type_id)
	type_config_changed.emit(type_id)

func compile(type_id: String):
	var cfg := {
		"speed":          settings.speed * PX_PER_METER,
		"turn_speed":     settings.turn_speed,
		"view_distance":  settings.view_distance * PX_PER_METER,
		"fov_degrees":    settings.fov_degrees,
		"dot_radius":     6.0,
	}
	for s in behaviors.get(type_id, {}).get("scripts", []):
		_collect_config(s.get("blocks", []), cfg)
	type_configs[type_id] = cfg

func _collect_config(blocks: Array, cfg: Dictionary):
	for b in blocks:
		var t: String = b.get("type", "")
		var p: Dictionary = b.get("params", {})
		match t:
			"set_speed":  cfg.speed         = float(p.get("value", settings.speed)) * PX_PER_METER
			"set_turn":   cfg.turn_speed    = deg_to_rad(float(p.get("value", 120.0)))
			"set_view":   cfg.view_distance = float(p.get("value", settings.view_distance)) * PX_PER_METER
			"set_fov":    cfg.fov_degrees   = float(p.get("value", settings.fov_degrees))
			"set_size":   cfg.dot_radius    = float(p.get("value", 6.0))
			"when_start":
				_collect_config(b.get("children", []), cfg)

func ship_config_from_scripts(scripts: Array, base_view: float, base_fov: float, base_speed: float = 150.0, base_turn: float = 3.2, base_size: float = 9.0) -> Dictionary:
	var cfg := {
		"view_distance": base_view,
		"fov_degrees": base_fov,
		"speed": base_speed,
		"turn_speed": base_turn,
		"dot_radius": base_size,
	}
	for s in scripts:
		_collect_config(s.get("blocks", []), cfg)
	return cfg

func set_selected_type(type_id: String):
	selected_type_id = type_id
	selected_type_changed.emit(type_id)

func set_active_tool(tool_id: String):
	if active_tool == tool_id:
		return
	active_tool = tool_id
	tool_changed.emit(tool_id)

func add_obstacle(data: Dictionary):
	data["id"] = _next_obstacle_id
	_next_obstacle_id += 1
	obstacles.append(data)
	obstacles_changed.emit()

func remove_obstacle(id: int):
	obstacles = obstacles.filter(func(ob): return ob.get("id", -1) != id)
	obstacles_changed.emit()

func clear_obstacles():
	obstacles.clear()
	obstacles_changed.emit()

func add_variable(var_name: String, var_type: String) -> bool:
	var clean := var_name.strip_edges()
	if clean == "":
		return false
	for v in variables:
		if v.get("name", "") == clean:
			return false
	variables.append({"name": clean, "type": var_type})
	variables_changed.emit()
	return true

func remove_variable(var_name: String):
	variables = variables.filter(func(v): return v.get("name", "") != var_name)
	var_values.erase(var_name)
	variables_changed.emit()

func variable_names() -> Array:
	var names: Array = []
	for v in variables:
		names.append(v.get("name", ""))
	return names

func variable_type(var_name: String) -> String:
	for v in variables:
		if v.get("name", "") == var_name:
			return v.get("type", "int")
	return "int"

func reset_variables():
	var_values.clear()
	for v in variables:
		var_values[v.get("name", "")] = ("" if v.get("type", "int") == "string" else 0)

func dropdown_options(provider: String) -> Array:
	var options: Array = []
	match provider:
		"targets":
			options.append({"value": "anyone", "text": "anyone"})
			options.append({"value": "object", "text": "an object"})
			options.append({"value": "wall", "text": "a wall"})
			for t in robot_types:
				options.append({"value": t.id, "text": "a " + t.name})
		"species":
			for t in robot_types:
				options.append({"value": t.id, "text": t.name})
		"variables":
			for v in variables:
				options.append({"value": v.name, "text": v.name})
		"operators":
			options.append({"value": "=", "text": "="})
			options.append({"value": "!=", "text": "≠"})
			options.append({"value": "<", "text": "<"})
			options.append({"value": ">", "text": ">"})
			options.append({"value": "<=", "text": "≤"})
			options.append({"value": ">=", "text": "≥"})
	return options

func get_var(var_name: String):
	if not var_values.has(var_name):
		return ("" if variable_type(var_name) == "string" else 0)
	return var_values[var_name]

func set_var(var_name: String, value):
	var_values[var_name] = value

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
	behaviors[id] = {"scripts": normalize_to_scripts([
		{"type": "set_speed", "params": {"value": 3.75}},
		{"type": "set_view",  "params": {"value": 3.75}},
		{"type": "when_always", "params": {}},
		{"type": "do_wander",   "params": {}},
		{"type": "do_forward",  "params": {}},
	])}
	compile(id)
	species_list_changed.emit()
	return id

func remove_species(type_id: String):
	if robot_types.size() <= 1:
		return
	robot_types = robot_types.filter(func(t): return t.id != type_id)
	behaviors.erase(type_id)
	type_configs.erase(type_id)
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
		"placements": placements,
		"obstacles": obstacles,
		"settings": settings,
		"variables": variables,
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
		variables = data.get("variables", [])
		_normalize_all_behaviors()
		_resync_species_counter()
		_normalize_placement_ids()
		_normalize_obstacle_ids()
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

func _normalize_obstacle_ids():
	var max_id := -1
	for ob in obstacles:
		if ob.has("id"):
			max_id = maxi(max_id, int(ob["id"]))
	for ob in obstacles:
		if not ob.has("id"):
			max_id += 1
			ob["id"] = max_id
	_next_obstacle_id = max_id + 1

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
		variables = setup.get("variables", [])
		_normalize_all_behaviors()
		_resync_species_counter()
		_normalize_placement_ids()
		_normalize_obstacle_ids()
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
