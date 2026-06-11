extends RefCounted

const DONE := true
const RUNNING := false

var host
var scripts: Array = []

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
			}
			scripts.append(current)
		elif current != null:
			current.body.append(b)

func process(delta: float):
	host.reset_inputs()
	for sc in scripts:
		_run_script(sc, delta)

func _run_script(sc: Dictionary, delta: float):
	if sc.done:
		return
	if not (sc.once or host.eval_condition(sc.cond, sc.cond_params)):
		sc.active = false
		sc.frames = []
		sc.state = {}
		return
	if not sc.active:
		sc.active = true
		sc.frames = [{"blocks": sc.body, "idx": 0}]
		sc.state = {}

	var guard := 0
	while guard < 64:
		guard += 1
		if sc.frames.is_empty():
			if sc.once:
				sc.done = true
				return
			sc.frames = [{"blocks": sc.body, "idx": 0}]
			sc.state = {}
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
		if t.begins_with("when_") or t.begins_with("if_"):
			if host.eval_condition(t.substr(t.find("_") + 1), b.get("params", {})):
				sc.frames.append({"blocks": b.get("children", []), "idx": 0})
				sc.state = {}
			else:
				frame.idx += 1
			continue
		if host.exec_action(t, b.get("params", {}), delta, sc.state):
			frame.idx += 1
			sc.state = {}
			continue
		return
