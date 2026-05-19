extends Node

@onready var robot: CharacterBody2D = get_parent()
@onready var sensor: Area2D = robot.get_node("VisionCone")

var _pending_turn_remaining: float = 0.0
var _pending_turn_dir: float = 0.0

var _turn_cooldown: float = 0.0
const TURN_COOLDOWN_TIME := 0.5

var _prev_condition_states: Dictionary = {}

func process_behavior(delta: float):
	if _turn_cooldown > 0.0:
		_turn_cooldown -= delta

	if _pending_turn_remaining > 0.0:
		var cfg := SimulationManager.get_type_config(robot.type_id)
		var turn_speed: float = cfg.turn_speed
		var step: float = turn_speed * delta
		if step >= _pending_turn_remaining:
			robot.rotation += _pending_turn_dir * _pending_turn_remaining
			_pending_turn_remaining = 0.0
			_turn_cooldown = TURN_COOLDOWN_TIME
		else:
			robot.rotation += _pending_turn_dir * step
			_pending_turn_remaining -= step
		robot.forward_input = 0.0
		robot.turn_input = 0.0
		return

	robot.forward_input = 0.0
	robot.turn_input = 0.0

	var current_states: Dictionary = {}
	var rules: Array = SimulationManager.get_compiled_rules(robot.type_id)

	for i in rules.size():
		var rule = rules[i]
		var cond: String = rule.get("condition", "always")
		var cond_params: Dictionary = rule.get("condition_params", {})
		var is_true: bool = _eval_condition(cond, cond_params)
		var rule_key: String = "%d_%s" % [i, cond]
		current_states[rule_key] = is_true

		if is_true:
			var was_true: bool = _prev_condition_states.get(rule_key, false)
			var is_rising_edge: bool = not was_true
			for act in rule.get("actions", []):
				var act_id: String = act.get("id", "stop")
				if act_id in ["turn_left_by", "turn_right_by"]:
					if is_rising_edge and _turn_cooldown <= 0.0:
						_exec_action(act_id, act.get("params", {}), delta)
				else:
					_exec_action(act_id, act.get("params", {}), delta)
				if _pending_turn_remaining > 0.0:
					robot.forward_input = 0.0
					robot.turn_input = 0.0
					_prev_condition_states = current_states
					return

	_prev_condition_states = current_states

func _eval_condition(cond: String, params: Dictionary) -> bool:
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
	return false

func _exec_action(action: String, params: Dictionary, delta: float):
	match action:
		"forward":
			robot.forward_input = 1.0
		"backward":
			robot.forward_input = -1.0
		"stop":
			robot.forward_input = 0.0
			robot.turn_input = 0.0
		"wander":
			robot.turn_input = randf_range(-0.4, 0.4)
		"turn_left":
			var rate: float = params.get("value", 1.0)
			robot.turn_input = -rate
		"turn_right":
			var rate: float = params.get("value", 1.0)
			robot.turn_input = rate
		"face":
			if sensor.visible_targets.size() > 0:
				var t = sensor.visible_targets[0]
				var a := robot.global_position.angle_to_point(t.global_position)
				robot.rotation = lerp_angle(robot.rotation, a, 5.0 * delta)
				robot.turn_input = 0.0
		"flee":
			if sensor.visible_targets.size() > 0:
				var t = sensor.visible_targets[0]
				var a: float = robot.global_position.angle_to_point(t.global_position) + PI
				robot.rotation = lerp_angle(robot.rotation, a, 5.0 * delta)
				robot.turn_input = 0.0
		"throttle":
			var mult: float = params.get("value", 1.0)
			robot.forward_input *= mult
		"turn_left_by":
			var deg: float = params.get("value", 180.0)
			_pending_turn_remaining = deg_to_rad(deg)
			_pending_turn_dir = -1.0
		"turn_right_by":
			var deg2: float = params.get("value", 180.0)
			_pending_turn_remaining = deg_to_rad(deg2)
			_pending_turn_dir = 1.0
