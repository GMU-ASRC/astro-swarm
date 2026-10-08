extends RefCounted

const DONE := true
const RUNNING := false
const MIN_INTERVAL := 0.05
const MAX_STEPS_PER_FRAME := 256
const NEGATION_PREFIX := "not_"

enum Kind { ACTION, CONDITION, ELSE_IF, ELSE }

var host
var scripts: Array = []
var _host_has_deactivate: bool = false

func _init(h):
	host = h
	_host_has_deactivate = host.has_method("on_deactivate")

func set_program(script_list: Array):
	scripts = []
	for s in script_list:
		_collect_scripts(s.get("blocks", []))

func _collect_scripts(blocks: Array):
	var current = null
	for b in blocks:
		var block_type: String = b.get("type", "")
		if block_type.begins_with("when_"):
			var params: Dictionary = b.get("params", {})
			var condition: Dictionary = _parse_condition(block_type.substr(5))
			current = {
				"cond": condition.name,
				"negate": condition.negate,
				"cond_params": params,
				"body": _compile(b.get("children", [])),
				"frames": [],
				"state": {},
				"active": false,
				"once": condition.name == "start",
				"done": false,
				"interval": _interval_seconds(condition.name, params),
				"elapsed": 0.0,
			}
			scripts.append(current)
		elif current != null:
			current.body.append(_compile_block(b))

func _compile(blocks: Array) -> Array:
	var compiled: Array = []
	for b in blocks:
		compiled.append(_compile_block(b))
	return compiled

func _compile_block(b: Dictionary) -> Dictionary:
	var block_type: String = b.get("type", "")
	var node := {
		"kind": Kind.ACTION,
		"type": block_type,
		"params": b.get("params", {}),
		"children": _compile(b.get("children", [])),
		"cond": "",
		"negate": false,
	}
	if block_type == "else":
		node.kind = Kind.ELSE
	elif block_type.begins_with("elif_") or block_type.begins_with("if_") or block_type.begins_with("when_"):
		node.kind = Kind.ELSE_IF if block_type.begins_with("elif_") else Kind.CONDITION
		var condition: Dictionary = _parse_condition(block_type.substr(block_type.find("_") + 1))
		node.cond = condition.name
		node.negate = condition.negate
	return node

func _parse_condition(raw: String) -> Dictionary:
	if raw.begins_with(NEGATION_PREFIX):
		return {"name": raw.substr(NEGATION_PREFIX.length()), "negate": true}
	return {"name": raw, "negate": false}

func _interval_seconds(cond: String, params: Dictionary) -> float:
	if cond != "every":
		return 0.0
	return maxf(MIN_INTERVAL, float(params.get("value", 1.0)))

func process(delta: float):
	host.reset_inputs()
	for sc in scripts:
		_run_script(sc, delta)

func _run_script(sc: Dictionary, delta: float):
	if sc.done:
		return
	if sc.body.is_empty():
		if sc.once:
			sc.done = true
		return
	if sc.interval > 0.0:
		_run_interval_script(sc, delta)
		return
	if not (sc.once or _evaluate(sc.cond, sc.negate, sc.cond_params)):
		if sc.active:
			if _host_has_deactivate:
				host.on_deactivate()
			sc.active = false
			sc.frames.clear()
			sc.state.clear()
		return
	if not sc.active:
		_start_body(sc)
	_advance(sc, delta)

func _evaluate(cond: String, negate: bool, params: Dictionary) -> bool:
	return host.eval_condition(cond, params) != negate

func _run_interval_script(sc: Dictionary, delta: float):
	sc.elapsed += delta
	if not sc.active:
		if sc.elapsed < sc.interval:
			return
		sc.elapsed = minf(sc.elapsed - sc.interval, sc.interval)
		_start_body(sc)
	_advance(sc, delta)

func _start_body(sc: Dictionary):
	sc.active = true
	sc.frames.clear()
	sc.frames.append(_frame(sc.body))
	sc.state.clear()

func _frame(blocks: Array) -> Dictionary:
	return {"blocks": blocks, "idx": 0, "matched": false}

func _enter(sc: Dictionary, blocks: Array):
	sc.frames.append(_frame(blocks))
	sc.state.clear()

func _advance(sc: Dictionary, delta: float):
	for _step in MAX_STEPS_PER_FRAME:
		if sc.frames.is_empty():
			if sc.once:
				sc.done = true
			elif sc.interval > 0.0:
				sc.active = false
			else:
				_start_body(sc)
			return
		var frame: Dictionary = sc.frames.back()
		if frame.idx >= frame.blocks.size():
			sc.frames.pop_back()
			if not sc.frames.is_empty():
				sc.frames.back().idx += 1
			sc.state.clear()
			continue
		var node: Dictionary = frame.blocks[frame.idx]
		match node.kind:
			Kind.ELSE:
				var run_else: bool = not frame.matched
				frame.matched = false
				if run_else:
					_enter(sc, node.children)
				else:
					frame.idx += 1
			Kind.ELSE_IF, Kind.CONDITION:
				if node.kind == Kind.ELSE_IF and frame.matched:
					frame.idx += 1
					continue
				var result: bool = _evaluate(node.cond, node.negate, node.params)
				frame.matched = result
				if result:
					_enter(sc, node.children)
				else:
					frame.idx += 1
			_:
				if not host.exec_action(node.type, node.params, delta, sc.state):
					return
				frame.idx += 1
				sc.state.clear()
