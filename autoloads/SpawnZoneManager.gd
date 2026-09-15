extends Node

signal zones_changed
signal runtime_changed
signal spawn_requested(zone: Dictionary, type_id: String, count: int)

const MAX_ROBOTS := 600
const MIN_ZONE_SIZE := 12.0

var zones: Array = []
var _next_zone_id: int = 0
var _runtime_states: Dictionary = {}

func add_zone(rect: Rect2, type_id: String) -> Dictionary:
	var zone := {
		"id": _next_zone_id,
		"name": "Zone %d" % (_next_zone_id + 1),
		"position": rect.position + rect.size * 0.5,
		"size": rect.size,
		"type_id": type_id,
		"enabled": true,
	}
	_next_zone_id += 1
	zones.append(zone)
	zones_changed.emit()
	return zone

func remove_zone(zone_id: int):
	zones = zones.filter(func(zone): return int(zone.get("id", -1)) != zone_id)
	_runtime_states.erase(zone_id)
	zones_changed.emit()

func clear_zones():
	zones.clear()
	_runtime_states.clear()
	zones_changed.emit()

func load_zones(saved_zones: Array):
	zones = saved_zones.duplicate(true)
	_runtime_states.clear()
	var highest_id := -1
	for zone in zones:
		if zone.has("id"):
			highest_id = maxi(highest_id, int(zone["id"]))
	for zone in zones:
		if not zone.has("id"):
			highest_id += 1
			zone["id"] = highest_id
	_next_zone_id = highest_id + 1
	zones_changed.emit()

func get_zone(zone_id: int) -> Dictionary:
	for zone in zones:
		if int(zone.get("id", -1)) == zone_id:
			return zone
	return {}

func zone_rect(zone: Dictionary) -> Rect2:
	var size: Vector2 = zone.get("size", Vector2.ZERO)
	var center: Vector2 = zone.get("position", Vector2.ZERO)
	return Rect2(center - size * 0.5, size)

func zone_at(point: Vector2) -> Dictionary:
	for index in range(zones.size() - 1, -1, -1):
		if zone_rect(zones[index]).has_point(point):
			return zones[index]
	return {}

func set_zone_species(zone_id: int, type_id: String):
	var zone := get_zone(zone_id)
	if zone.is_empty():
		return
	zone["type_id"] = type_id
	zones_changed.emit()

func set_zone_starts_enabled(zone_id: int, enabled: bool):
	var zone := get_zone(zone_id)
	if zone.is_empty():
		return
	zone["enabled"] = enabled
	zones_changed.emit()

func replace_species(removed_type_id: String, fallback_type_id: String):
	for zone in zones:
		if zone.get("type_id", "") == removed_type_id:
			zone["type_id"] = fallback_type_id
	for state in _runtime_states.values():
		if state.get("type_id", "") == removed_type_id:
			state["type_id"] = fallback_type_id
	zones_changed.emit()

func begin_runtime():
	_runtime_states.clear()
	for zone in zones:
		_runtime_states[int(zone.get("id", -1))] = {
			"enabled": bool(zone.get("enabled", true)),
			"type_id": str(zone.get("type_id", "")),
		}
	runtime_changed.emit()

func end_runtime():
	_runtime_states.clear()
	runtime_changed.emit()

func is_zone_enabled(zone_id: int) -> bool:
	if _runtime_states.has(zone_id):
		return _runtime_states[zone_id].enabled
	return bool(get_zone(zone_id).get("enabled", false))

func zone_species(zone_id: int) -> String:
	if _runtime_states.has(zone_id):
		return _runtime_states[zone_id].type_id
	return str(get_zone(zone_id).get("type_id", ""))

func set_runtime_enabled(zone_id: int, enabled: bool):
	if not _runtime_states.has(zone_id):
		return
	_runtime_states[zone_id].enabled = enabled
	runtime_changed.emit()

func set_runtime_species(zone_id: int, type_id: String):
	if not _runtime_states.has(zone_id) or not SimulationManager.has_species(type_id):
		return
	_runtime_states[zone_id].type_id = type_id
	runtime_changed.emit()

func request_spawn(zone_id: int, count: int):
	var zone := get_zone(zone_id)
	if zone.is_empty() or count <= 0 or not is_zone_enabled(zone_id):
		return
	var type_id := zone_species(zone_id)
	if not SimulationManager.has_species(type_id):
		return
	spawn_requested.emit(zone, type_id, count)

func random_point_in_zone(zone: Dictionary) -> Vector2:
	var rect := zone_rect(zone)
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)

func count_robots_in_zone(zone_id: int) -> int:
	var zone := get_zone(zone_id)
	if zone.is_empty():
		return 0
	var rect := zone_rect(zone)
	var count := 0
	for robot in get_tree().get_nodes_in_group("robots"):
		if robot.is_queued_for_deletion():
			continue
		if rect.has_point(robot.global_position):
			count += 1
	return count

func dropdown_options() -> Array:
	var options: Array = []
	for zone in zones:
		options.append({"value": int(zone.get("id", -1)), "text": str(zone.get("name", "Zone"))})
	return options
