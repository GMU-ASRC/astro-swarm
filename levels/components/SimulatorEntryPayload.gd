extends RefCounted

const MAX_FRAMES := 6000
const MAX_ROBOT_SAMPLES := 250000
const MAX_TITLE_LENGTH := 80
const MAX_DESCRIPTION_LENGTH := 400

static func build(run_data: Dictionary, title: String, description: String) -> Dictionary:
	var setup: Dictionary = run_data.get("setup", {})
	var frames: Array = run_data.get("frames", [])
	if frames.is_empty():
		return {"error": "This run has no recorded frames."}
	if frames.size() > MAX_FRAMES:
		return {"error": "This run is too long to upload. The limit is %d seconds of recording." % int(MAX_FRAMES * SimulationManager.RECORD_INTERVAL)}
	var sample_count := 0
	for frame in frames:
		sample_count += (frame as Array).size()
	if sample_count > MAX_ROBOT_SAMPLES:
		return {"error": "This run has too many robots for its length to upload. Try a shorter recording."}

	var robot_types: Array = setup.get("robot_types", [])
	if robot_types.is_empty():
		return {"error": "This run has no species."}
	var fallback_type: String = str(robot_types[0].get("id", ""))
	var settings: Dictionary = setup.get("settings", {})

	return {"payload": {
		"title": title.strip_edges().left(MAX_TITLE_LENGTH),
		"description": description.strip_edges().left(MAX_DESCRIPTION_LENGTH),
		"setup": {
			"arena": [float(settings.get("arena_width", 1280.0)), float(settings.get("arena_height", 720.0))],
			"species": _species(robot_types, setup.get("type_configs", {})),
			"behaviors": _behaviors(robot_types, setup.get("behaviors", {})),
			"arena_program": json_safe(SimulationManager.normalize_to_scripts(setup.get("arena_program", []))),
			"variables": json_safe(setup.get("variables", [])),
			"obstacles": json_safe(setup.get("obstacles", [])),
			"spawn_zones": json_safe(setup.get("spawn_zones", [])),
			"placement_count": (setup.get("placements", []) as Array).size(),
		},
		"replay": _replay(frames, setup.get("placements", []), fallback_type),
	}}

static func _species(robot_types: Array, type_configs: Dictionary) -> Array:
	var species: Array = []
	for robot_type in robot_types:
		var type_id: String = str(robot_type.get("id", ""))
		var color: Color = robot_type.get("color", Color.WHITE)
		species.append({
			"id": type_id,
			"name": str(robot_type.get("name", type_id)),
			"color": "#" + color.to_html(false),
			"config": _config_in_meters(type_configs.get(type_id, {})),
		})
	return species

static func _config_in_meters(config: Dictionary) -> Dictionary:
	if config.is_empty():
		return {}
	var pixels_per_meter: float = SimulationManager.PX_PER_METER
	return {
		"speed": float(config.get("speed", 0.0)) / pixels_per_meter,
		"turn_rate": rad_to_deg(float(config.get("turn_speed", 0.0))),
		"vision": float(config.get("view_distance", 0.0)) / pixels_per_meter,
		"fov": float(config.get("fov_degrees", 0.0)),
		"size": float(config.get("dot_radius", 6.0)),
	}

static func _behaviors(robot_types: Array, behaviors: Dictionary) -> Dictionary:
	var programs := {}
	for robot_type in robot_types:
		var type_id: String = str(robot_type.get("id", ""))
		programs[type_id] = json_safe(SimulationManager.normalize_to_scripts(behaviors.get(type_id, [])))
	return programs

static func _replay(frames: Array, placements: Array, fallback_type: String) -> Dictionary:
	var placement_types := {}
	for placement in placements:
		placement_types[int(placement.get("id", -1))] = str(placement.get("type_id", fallback_type))
	var robot_species := {}
	var packed_frames: Array = []
	for frame in frames:
		var packed_frame: Array = []
		for index in (frame as Array).size():
			var sample: Dictionary = frame[index]
			var robot_id := int(sample.get("id", index))
			if not robot_species.has(robot_id):
				robot_species[robot_id] = str(sample.get("type", placement_types.get(robot_id, fallback_type)))
			var position: Vector2 = sample.get("pos", Vector2.ZERO)
			packed_frame.append(robot_id)
			packed_frame.append(snappedf(position.x, 0.1))
			packed_frame.append(snappedf(position.y, 0.1))
			packed_frame.append(snappedf(rad_to_deg(float(sample.get("rot", 0.0))), 0.1))
		packed_frames.append(packed_frame)
	var robots: Array = []
	for robot_id in robot_species.keys():
		robots.append([robot_id, robot_species[robot_id]])
	return {"interval": SimulationManager.RECORD_INTERVAL, "robots": robots, "frames": packed_frames}

static func json_safe(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var converted := {}
			for key in value.keys():
				converted[str(key)] = json_safe(value[key])
			return converted
		TYPE_ARRAY:
			var converted_list: Array = []
			for item in value:
				converted_list.append(json_safe(item))
			return converted_list
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [snappedf(value.x, 0.1), snappedf(value.y, 0.1)]
		TYPE_COLOR:
			return "#" + value.to_html(false)
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
	return str(value)
