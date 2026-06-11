extends Node

const BlockExecutor := preload("res://entities/BlockExecutor.gd")
const STEP_TIME := 0.4

@onready var robot: CharacterBody2D = get_parent()
@onready var sensor: Area2D = robot.get_node("VisionCone")

var _executor
var _throttle_mult: float = 1.0

func _ready():
	_executor = BlockExecutor.new(self)
	_rebuild_program()
	SimulationManager.behavior_changed.connect(_on_behavior_changed)

func _on_behavior_changed(type_id: String):
	if type_id == robot.type_id:
		_rebuild_program()

func _rebuild_program():
	_executor.set_program(SimulationManager.get_scripts(robot.type_id))

func process_behavior(delta: float):
	_executor.process(delta)

func reset_inputs():
	robot.forward_input = 0.0
	robot.turn_input = 0.0

func eval_condition(cond: String, params: Dictionary) -> bool:
	match cond:
		"always":      return true
		"sees":        return sensor.visible_targets.size() > 0
		"alone":       return sensor.visible_targets.size() == 0
		"near_wall":   return robot.get_slide_collision_count() > 0
		"sees_wall":   return sensor.near_wall
		"sees_species":
			var target_type: String = params.get("value", "")
			for t in sensor.visible_targets:
				if t is CharacterBody2D and "type_id" in t and t.type_id == target_type:
					return true
			return false
		"no_sees_species":
			var target_type2: String = params.get("value", "")
			for t in sensor.visible_targets:
				if t is CharacterBody2D and "type_id" in t and t.type_id == target_type2:
					return false
			return true
		"within":
			var d: float = _nearest_dist()
			return d >= 0.0 and d <= float(params.get("value", 3.0)) * SimulationManager.PX_PER_METER
		"beyond":
			var d2: float = _nearest_dist()
			return d2 >= 0.0 and d2 > float(params.get("value", 3.0)) * SimulationManager.PX_PER_METER
	return false

func _nearest_dist() -> float:
	var best: float = -1.0
	for t in sensor.visible_targets:
		var d: float = robot.global_position.distance_to(t.global_position)
		if best < 0.0 or d < best:
			best = d
	return best

func exec_action(block_type: String, params: Dictionary, delta: float, state: Dictionary) -> bool:
	if block_type.begins_with("set_"):
		return BlockExecutor.DONE
	match block_type.substr(3):
		"forward":
			robot.forward_input = _throttle_mult
			return _step(state, delta)
		"backward":
			robot.forward_input = -_throttle_mult
			return _step(state, delta)
		"stop":
			robot.forward_input = 0.0
			robot.turn_input = 0.0
			return BlockExecutor.DONE
		"wander":
			if not state.has("turn"):
				state.turn = randf_range(-0.6, 0.6)
			robot.turn_input = state.turn
			robot.forward_input = _throttle_mult
			return _step(state, delta)
		"random_walk":
			if not state.has("dir"):
				state.dir = [0.0, PI / 2.0, PI, -PI / 2.0][randi() % 4]
			robot.rotation = state.dir
			robot.forward_input = _throttle_mult
			return _step(state, delta)
		"turn_left":
			robot.rotation -= deg_to_rad(float(params.get("value", 90.0))) * delta
			return _step(state, delta)
		"turn_right":
			robot.rotation += deg_to_rad(float(params.get("value", 90.0))) * delta
			return _step(state, delta)
		"turn_left_by":
			return _turn_by(state, delta, -1.0, float(params.get("value", 180.0)))
		"turn_right_by":
			return _turn_by(state, delta, 1.0, float(params.get("value", 180.0)))
		"face":
			_rotate_toward(0.0, delta)
			return _step(state, delta)
		"flee":
			_rotate_toward(PI, delta)
			return _step(state, delta)
		"throttle":
			_throttle_mult = float(params.get("value", 1.0))
			return BlockExecutor.DONE
	return BlockExecutor.DONE

func _step(state: Dictionary, delta: float) -> bool:
	if not state.has("t"):
		state.t = STEP_TIME
	state.t -= delta
	return state.t <= 0.0

func _turn_by(state: Dictionary, delta: float, dir: float, deg: float) -> bool:
	if not state.has("rem"):
		state.rem = deg_to_rad(deg)
	var cfg := SimulationManager.get_type_config(robot.type_id)
	var step: float = cfg.turn_speed * delta
	if step >= state.rem:
		robot.rotation += dir * state.rem
		return BlockExecutor.DONE
	robot.rotation += dir * step
	state.rem -= step
	return BlockExecutor.RUNNING

func _rotate_toward(offset: float, delta: float):
	if sensor.visible_targets.size() == 0:
		return
	var target = sensor.visible_targets[0]
	var a: float = robot.global_position.angle_to_point(target.global_position) + offset
	robot.rotation = lerp_angle(robot.rotation, a, 5.0 * delta)
