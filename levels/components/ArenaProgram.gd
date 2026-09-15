extends Node

const BlockExecutor := preload("res://entities/BlockExecutor.gd")

var _executor
var _is_running: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_executor = BlockExecutor.new(self)
	_executor.single_pass = true
	_rebuild_program()
	SimulationManager.behavior_changed.connect(_on_behavior_changed)

func _on_behavior_changed(program_id: String):
	if program_id == SimulationManager.ARENA_PROGRAM_ID:
		_rebuild_program()

func _rebuild_program():
	_executor.set_program(SimulationManager.get_scripts(SimulationManager.ARENA_PROGRAM_ID))

func _physics_process(delta: float):
	if not SimulationManager.has_started or SimulationManager.is_replaying:
		_is_running = false
		return
	if get_tree().paused:
		return
	if not _is_running:
		_is_running = true
		SpawnZoneManager.begin_runtime()
		_rebuild_program()
	_executor.process(delta * SimulationManager.settings.get("time_scale", 1.0))

func reset_inputs():
	pass

func eval_condition(condition: String, params: Dictionary) -> bool:
	match condition:
		"always":
			return true
		"compare":
			return SimulationManager.compare_variable(params)
		"zone_count":
			var robots_in_zone := SpawnZoneManager.count_robots_in_zone(int(params.get("zone", -1)))
			return SimulationManager.compare_numbers(float(robots_in_zone), str(params.get("op", "=")), float(params.get("value", 0.0)))
	return false

func exec_action(block_type: String, params: Dictionary, _delta: float, _state: Dictionary) -> bool:
	if SimulationManager.apply_variable_block(block_type, params):
		return BlockExecutor.DONE
	var zone_id := int(params.get("zone", -1))
	match block_type:
		"do_spawn":
			SpawnZoneManager.request_spawn(zone_id, int(params.get("count", 1)))
		"do_zone_species":
			SpawnZoneManager.set_runtime_species(zone_id, str(params.get("species", "")))
		"do_zone_toggle":
			SpawnZoneManager.set_runtime_enabled(zone_id, str(params.get("state", "on")) == "on")
		"do_stop_sim":
			SimulationManager.has_started = false
			get_tree().paused = true
		"do_pause_sim":
			get_tree().paused = true
	return BlockExecutor.DONE
