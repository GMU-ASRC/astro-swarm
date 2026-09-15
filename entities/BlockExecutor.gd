extends RefCounted

const DONE := true
const RUNNING := false
const MIN_INTERVAL := 0.05

var host
var scripts: Array = []
var single_pass: bool = false

func _init(h):
	host = h

func set_program(script_list: Array):
	scripts = []
	for s in script_list:
		_collect_scripts(s.get("blocks", []))

func _collect_scripts(blocks: Array):
	var current = null
	for b in blocks:
		var t: String = b.get("type", "")
		if t.begins_with("when_"):
			var cond: String = t.substr(5)
			current = {
				"cond": cond,
				"cond_params": b.get("params", {}),
				"body": (b.get("children", []) as Array).duplicate(),
				"frames": [],
				"state": {},
				"active": false,
				"once": cond == "start",
				"done": false,
				"interval": _interval_seconds(cond, b.get("params", {})),
				"elapsed": 0.0,
			}
			scripts.append(current)
		elif current != null:
			current.body.append(b)

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
	if not (sc.once or host.eval_condition(sc.cond, sc.cond_params)):
		if sc.active and host.has_method("on_deactivate"):
			host.on_deactivate()
		sc.active = false
		sc.frames = []
		sc.state = {}
		return
	if not sc.active:
		sc.active = true
		sc.frames = [{"blocks": sc.body, "idx": 0, "matched": false}]
		sc.state = {}
	_advance(sc, delta)

func _run_interval_script(sc: Dictionary, delta: float):
	sc.elapsed += delta
	if not sc.active:
		if sc.elapsed < sc.interval:
			return
		sc.elapsed = minf(sc.elapsed - sc.interval, sc.interval)
		sc.active = true
		sc.frames = [{"blocks": sc.body, "idx": 0, "matched": false}]
		sc.state = {}
	_advance(sc, delta)

func _advance(sc: Dictionary, delta: float):
	var guard := 0
	while guard < 64:
		guard += 1
		if sc.frames.is_empty():
			if sc.once:
				sc.done = true
				return
			if sc.interval > 0.0:
				sc.active = false
				return
			sc.frames = [{"blocks": sc.body, "idx": 0, "matched": false}]
			sc.state = {}
			if single_pass:
				return
			continue
		var frame: Dictionary = sc.frames.back()
		if frame.idx >= frame.blocks.size():
			sc.frames.pop_back()
			if not sc.frames.is_empty():
				sc.frames.back().idx += 1
			sc.state = {}
			continue
		var b: Dictionary = frame.blocks[frame.idx]
		var t: String = b.get("type", "")
		if t == "else":
			var run_else: bool = not frame.matched
			frame.matched = false
			if run_else:
				sc.frames.append({"blocks": b.get("children", []), "idx": 0, "matched": false})
				sc.state = {}
			else:
				frame.idx += 1
			continue
		if t.begins_with("when_") or t.begins_with("if_"):
			var result: bool = host.eval_condition(t.substr(t.find("_") + 1), b.get("params", {}))
			frame.matched = result
			if result:
				sc.frames.append({"blocks": b.get("children", []), "idx": 0, "matched": false})
				sc.state = {}
			else:
				frame.idx += 1
			continue
		if host.exec_action(t, b.get("params", {}), delta, sc.state):
			frame.idx += 1
			sc.state = {}
			continue
		return
