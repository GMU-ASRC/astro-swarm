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

func on_deactivate():
	robot.turn_cmd = 0.0

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
				if is_instance_valid(t) and t is CharacterBody2D and "type_id" in t and t.type_id == target_type:
					return true
			return false
		"no_sees_species":
			var target_type2: String = params.get("value", "")
			for t in sensor.visible_targets:
				if is_instance_valid(t) and t is CharacterBody2D and "type_id" in t and t.type_id == target_type2:
					return false
			return true
		"see":
			var target: String = params.get("target", "anyone")
			match target:
				"anyone": return sensor.visible_targets.size() > 0
				"enemy":  return sensor.visible_targets.size() > 0
				"ally":   return false
				"object": return sensor.visible_objects.size() > 0
				"wall":   return sensor.near_wall
				_:
					for t in sensor.visible_targets:
						if is_instance_valid(t) and t is CharacterBody2D and "type_id" in t and t.type_id == target:
							return true
					return false
		"compare":
			return SimulationManager.compare_variable(params)
	return false

func exec_action(block_type: String, params: Dictionary, delta: float, state: Dictionary) -> bool:
	if block_type.begins_with("set_"):
		if not SimulationManager.apply_variable_block(block_type, params):
			robot.apply_config(SimulationManager.config_entry(block_type, params))
		return BlockExecutor.DONE
	match block_type:
		"do_forward":
			robot.forward_input = _throttle_mult
			return _step(state, delta)
		"do_backward":
			robot.forward_input = -_throttle_mult
			return _step(state, delta)
		"do_stop":
			robot.forward_input = 0.0
			robot.turn_input = 0.0
			robot.turn_cmd = 0.0
			return BlockExecutor.DONE
		"do_random_walk", "do_wander":
			robot.turn_cmd = 0.0
			if not state.has("heading"):
				state.heading = randf() * TAU
				state.remaining = _levy_step_time()
			robot.rotation = state.heading
			robot.forward_input = _throttle_mult
			state.remaining -= delta
			if state.remaining <= 0.0:
				return BlockExecutor.DONE
			return BlockExecutor.RUNNING
		"do_turn_left":
			robot.turn_cmd = -deg_to_rad(float(params.get("value", 90.0)))
			return BlockExecutor.DONE
		"do_turn_right":
			robot.turn_cmd = deg_to_rad(float(params.get("value", 90.0)))
			return BlockExecutor.DONE
		"do_turn_left_by":
			robot.turn_cmd = 0.0
			return _turn_by(state, delta, -1.0, float(params.get("value", 180.0)))
		"do_turn_right_by":
			robot.turn_cmd = 0.0
			return _turn_by(state, delta, 1.0, float(params.get("value", 180.0)))
		"do_face":
			robot.turn_cmd = 0.0
			_face_target(delta)
			return _step(state, delta)
		"do_throttle":
			_throttle_mult = float(params.get("value", 1.0))
			return BlockExecutor.DONE
		"do_stop_sim":
			SimulationManager.has_started = false
			get_tree().paused = true
			return BlockExecutor.DONE
		"do_pause_sim":
			get_tree().paused = true
			return BlockExecutor.DONE
	return BlockExecutor.DONE

func _levy_step_time() -> float:
	var shortest := 0.2
	var longest := 3.0
	var sample := randf()
	var step := shortest / maxf(0.001, 1.0 - sample)
	return minf(step, longest)

func _step(state: Dictionary, delta: float) -> bool:
	if not state.has("t"):
		state.t = STEP_TIME
	state.t -= delta
	return state.t <= 0.0

func _turn_by(state: Dictionary, delta: float, dir: float, deg: float) -> bool:
	if not state.has("rem"):
		state.rem = deg_to_rad(deg)
	var step: float = robot.config.turn_speed * delta
	if step >= state.rem:
		robot.rotation += dir * state.rem
		return BlockExecutor.DONE
	robot.rotation += dir * step
	state.rem -= step
	return BlockExecutor.RUNNING

func _face_target(delta: float):
	var target = null
	for t in sensor.visible_targets:
		if is_instance_valid(t):
			target = t
			break
	if target == null:
		return
	var target_angle: float = robot.global_position.angle_to_point(target.global_position)
	robot.rotation = lerp_angle(robot.rotation, target_angle, 5.0 * delta)
