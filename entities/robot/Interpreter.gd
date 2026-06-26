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
		"within":
			var d: float = _nearest_dist()
			return d >= 0.0 and d <= float(params.get("value", 3.0)) * SimulationManager.PX_PER_METER
		"beyond":
			var d2: float = _nearest_dist()
			return d2 >= 0.0 and d2 > float(params.get("value", 3.0)) * SimulationManager.PX_PER_METER
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
			return _compare_var(params)
	return false

func _compare_var(params: Dictionary) -> bool:
	var left = SimulationManager.get_var(params.get("var", ""))
	var op: String = params.get("op", "=")
	var right = params.get("value", 0.0)
	if left is String:
		var rs := str(right)
		if op == "=":  return left == rs
		if op == "!=": return left != rs
		return false
	var a := float(left)
	var b := float(right)
	match op:
		"=":  return a == b
		"!=": return a != b
		"<":  return a < b
		">":  return a > b
		"<=": return a <= b
		">=": return a >= b
	return false

func _nearest_dist() -> float:
	var best: float = -1.0
	for t in sensor.visible_targets:
		if not is_instance_valid(t):
			continue
		var d: float = robot.global_position.distance_to(t.global_position)
		if best < 0.0 or d < best:
			best = d
	return best

func exec_action(block_type: String, params: Dictionary, delta: float, state: Dictionary) -> bool:
	match block_type:
		"set_var":
			SimulationManager.set_var(params.get("var", ""), params.get("value", 0))
			return BlockExecutor.DONE
		"set_var_random":
			var lo: int = int(params.get("min", 0))
			var hi: int = int(params.get("max", 0))
			if lo > hi:
				var tmp := lo
				lo = hi
				hi = tmp
			SimulationManager.set_var(params.get("var", ""), randi_range(lo, hi))
			return BlockExecutor.DONE
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
			robot.turn_cmd = 0.0
			return BlockExecutor.DONE
		"random_walk", "wander":
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
		"turn_left":
			robot.turn_cmd = -deg_to_rad(float(params.get("value", 90.0)))
			return BlockExecutor.DONE
		"turn_right":
			robot.turn_cmd = deg_to_rad(float(params.get("value", 90.0)))
			return BlockExecutor.DONE
		"turn_left_by":
			robot.turn_cmd = 0.0
			return _turn_by(state, delta, -1.0, float(params.get("value", 180.0)))
		"turn_right_by":
			robot.turn_cmd = 0.0
			return _turn_by(state, delta, 1.0, float(params.get("value", 180.0)))
		"face":
			robot.turn_cmd = 0.0
			_rotate_toward(0.0, delta)
			return _step(state, delta)
		"flee":
			robot.turn_cmd = 0.0
			_rotate_toward(PI, delta)
			return _step(state, delta)
		"throttle":
			_throttle_mult = float(params.get("value", 1.0))
			return BlockExecutor.DONE
		"stop_sim":
			SimulationManager.has_started = false
			get_tree().paused = true
			return BlockExecutor.DONE
		"pause_sim":
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
	var cfg := SimulationManager.get_type_config(robot.type_id)
	var step: float = cfg.turn_speed * delta
	if step >= state.rem:
		robot.rotation += dir * state.rem
		return BlockExecutor.DONE
	robot.rotation += dir * step
	state.rem -= step
	return BlockExecutor.RUNNING

func _rotate_toward(offset: float, delta: float):
	var target = null
	for t in sensor.visible_targets:
		if is_instance_valid(t):
			target = t
			break
	if target == null:
		return
	var a: float = robot.global_position.angle_to_point(target.global_position) + offset
	robot.rotation = lerp_angle(robot.rotation, a, 5.0 * delta)
