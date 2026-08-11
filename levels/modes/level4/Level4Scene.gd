extends "res://levels/modes/FARPBase.gd"

const METRICS       := preload("res://levels/components/SwarmMetrics.gd")
const METRICS_PANEL := preload("res://ui/hud/SwarmMetricsPanel.gd")

const LEVEL_ARENA := Vector2(2560.0, 1440.0) # pixels, this level runs in a smaller arena

const GROUP_SIZE         := 6     # count, agents in each swarm group
const GROUP_OFFSET       := 640.0 # pixels, how far each group starts from the planet
const GROUP_SPAWN_RADIUS := 110.0 # pixels, ring the agents of a group start on
const LEADER_OFFSET      := 460.0 # pixels, how far below the planet the leader starts

const MERGE_DISTANCE  := 240.0 # pixels (6 m), gap that still links two agents into one swarm
const GOAL_RADIUS     := 220.0 # pixels, how close the swarm center has to get to the planet
const ESCAPE_DISTANCE := 560.0 # pixels, how far the leader has to get from the swarm center
const HOLD_SECONDS    := 3.0   # seconds the escape has to hold before the run is won
const MILL_MINIMUM    := 0.5   # circliness the swarm has to keep while the leader escapes

const LEADER_SPEED     := 150.0 # pixels/second (3.75 m/s)
const LEADER_TURN_RATE := 2.8   # radians/second
const LEADER_HP        := 99.0  # hit points

const TIME_LIMIT_SECONDS := 300.0 # seconds
const RECORD_FPS         := 15.0  # frames/second written into the submitted replay

const C_GROUP_A := Color(1.0, 0.42, 0.32, 1.0)
const C_GROUP_B := Color(0.451, 0.616, 1.0, 1.0)
const C_MERGED  := Color(1.0, 0.84, 0.2, 1.0)
const C_GOAL    := Color(0.93, 0.94, 1.0, 1.0)

const MILLING_PROGRAM := [
	{"type": "when_start", "params": {}, "children": [
		{"type": "set_speed", "params": {"value": 3.0}},
		{"type": "set_fov",   "params": {"value": 60.0}},
		{"type": "set_view",  "params": {"value": 5.0}},
	]},
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_forward",    "params": {}},
		{"type": "do_turn_right", "params": {"value": 90.0}},
	]},
	{"type": "when_sees_ally", "params": {}, "children": [
		{"type": "do_turn_left", "params": {"value": 90.0}},
	]},
]

enum Objective { MERGE, DELIVER, ESCAPE, COMPLETE }

var _group_a: Array = []
var _group_b: Array = []
var _leader: Node2D = null

var _objective: int = Objective.MERGE
var _hold_elapsed: float = 0.0

var _merged: bool = false
var _center_a: Vector2 = Vector2.ZERO
var _center_b: Vector2 = Vector2.ZERO
var _center_all: Vector2 = Vector2.ZERO

var _goal_distance: float = -1.0
var _circliness: float = -1.0
var _loss: float = -1.0
var _minimum_loss: float = -1.0

var _metrics_panel: PanelContainer
var _legend_merged: bool = false

var _merge_time: float = -1.0
var _deliver_time: float = -1.0
var _escape_time: float = -1.0

var _agent_program: Array = []
var _frames: Array = []
var _record_accum: float = 0.0

func _level_id() -> String:
	return "farp4"

func _arena_size() -> Vector2:
	return LEVEL_ARENA

func _planet_center() -> Vector2:
	return LEVEL_ARENA * 0.5

func _level_title() -> String:
	return "LEVEL 4 - MERGE THE SWARMS"

func _level_subtitle() -> String:
	return "Two swarms are milling on their own. Press LAUNCH, then fly the gold leader between them, pull them into one mill, walk that mill onto the planet and slip away without breaking it."

func _uses_workspace() -> bool:
	return false

func _uses_collisions_toggle() -> bool:
	return false

func _submit_button_text() -> String:
	return "SUBMIT RUN"

func _time_limit() -> float:
	return TIME_LIMIT_SECONDS

func _timer_text() -> String:
	return _countdown_text()

func _walkthrough_lines() -> Array:
	return [
		"GOAL: merge the two milling swarms into one, bring that swarm to the center planet, then leave it milling without you.",
		"1.  Every agent follows one rule: turn one way when it can see another ship, the other way when it sees nothing. That rule alone is what makes them mill in a circle.",
		"2.  You fly the gold leader. The agents cannot tell you apart from one of their own, so wherever you go you bend their turning.",
		"3.  Press LAUNCH, then fly the leader. Forward and back drive, left and right turn (WASD or arrow keys, remappable in Settings).",
		"4.  MERGE: the swarm counts as one when every agent is within %d meters of the group through its neighbours. Two center markers become one gold marker." % int(MERGE_DISTANCE / SimulationManager.PX_PER_METER),
		"5.  DELIVER: walk the merged mill until its gold center marker sits inside the white ring around the planet.",
		"6.  ESCAPE: fly at least %d meters clear and hold it for %d seconds while the swarm stays merged, stays on the planet and keeps milling." % [int(ESCAPE_DISTANCE / SimulationManager.PX_PER_METER), int(HOLD_SECONDS)],
		"The panel on the right tracks the loss: distance from the swarm center to the planet plus how far the mill is from a clean circle. Lower is better, and the minimum you reached is kept.",
		"You have %d minutes. The clock in the top right counts down." % int(TIME_LIMIT_SECONDS / 60.0),
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"Do not charge into a mill. Sitting just outside it turns the whole ring toward you.",
		"Lead from in front. Agents follow what they can see, so back away slowly and the mill drifts after you.",
		"Merge first, move second. Dragging one group across the arena usually strings it out and loses the other.",
		"A mill that is stretched into an oval scores badly. Give it a few seconds to round out before you leave.",
		"Circliness drops the moment agents stop moving tangentially. If it dives, you are pulling too hard.",
		"Your escape only counts if the swarm holds together while you are away. Leave along a line that does not drag the ring with you.",
		"The clock is generous. A slow, patient nudge beats a fast pass every time.",
	]

func _setup_level():
	_build_metrics_panel()
	_spawn_scenario()

func _restart_level():
	_spawn_scenario()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()

func _spawn_scenario():
	_placements.clear()
	_objective = Objective.MERGE
	_hold_elapsed = 0.0
	_merged = false
	_goal_distance = -1.0
	_circliness = -1.0
	_loss = -1.0
	_minimum_loss = -1.0
	_legend_merged = true
	_merge_time = -1.0
	_deliver_time = -1.0
	_escape_time = -1.0
	_frames = []
	_record_accum = 0.0
	_agent_program = SimulationManager.normalize_to_scripts(MILLING_PROGRAM)
	_group_a = _spawn_group(_planet - Vector2(GROUP_OFFSET, 0.0), C_GROUP_A, _agent_program)
	_group_b = _spawn_group(_planet + Vector2(GROUP_OFFSET, 0.0), C_GROUP_B, _agent_program)
	_leader = _make_ship([], LEADER_HP, C_MERGED)
	_leader.global_position = _planet + Vector2(0.0, LEADER_OFFSET)
	_leader.rotation = -PI / 2.0
	_update_metrics()
	_update_event_label()

func _spawn_group(center: Vector2, color: Color, program: Array) -> Array:
	var ships: Array = []
	for index in GROUP_SIZE:
		var angle: float = TAU * float(index) / float(GROUP_SIZE)
		var ship := _make_ship(program, DEFENDER_HP, color)
		ship.global_position = center + Vector2(GROUP_SPAWN_RADIUS, 0.0).rotated(angle)
		ship.rotation = angle + PI / 2.0
		ships.append(ship)
		_placements.append({"pos": ship.global_position, "rot": ship.rotation})
	return ships

func _build_metrics_panel():
	_metrics_panel = METRICS_PANEL.new()
	_metrics_panel.label_font = FONT_REG
	_metrics_panel.text_color = C_TEXT
	_metrics_panel.dim_color = C_DIM
	_metrics_panel.border_color = C_BORDER
	_metrics_panel.background_color = Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.88)
	_metrics_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_metrics_panel.offset_left = -272
	_metrics_panel.offset_top = 58
	_metrics_panel.offset_right = -16
	_metrics_panel.offset_bottom = 58
	_hud_root.add_child(_metrics_panel)
	_hud_root.move_child(_metrics_panel, 0)
	_metrics_panel.build()

func _swarm_ships() -> Array:
	return _group_a + _group_b

func _live_ships(ships: Array) -> Array:
	var out: Array = []
	for ship in ships:
		if is_instance_valid(ship):
			out.append(ship)
	return out

func _positions(ships: Array) -> Array:
	var out: Array = []
	for ship in _live_ships(ships):
		out.append(ship.global_position)
	return out

func _headings(ships: Array) -> Array:
	var out: Array = []
	for ship in _live_ships(ships):
		out.append(ship.rotation)
	return out

func _start_active():
	super()
	for ship in _swarm_ships():
		if is_instance_valid(ship):
			ship.set_physics_process(true)

func _clear_ships():
	for ship in _swarm_ships():
		if is_instance_valid(ship):
			ship.queue_free()
	_group_a.clear()
	_group_b.clear()
	if is_instance_valid(_leader):
		_leader.queue_free()
	_leader = null
	super()

func _update_count():
	if _count_label != null:
		_count_label.text = "SWARM: %d AGENTS   LEADER: 1" % _live_ships(_swarm_ships()).size()

func _launch():
	_start_active()
	_objective = Objective.MERGE
	_hold_elapsed = 0.0
	_minimum_loss = -1.0
	_merge_time = -1.0
	_deliver_time = -1.0
	_escape_time = -1.0
	_frames = [_snapshot()]
	_record_accum = 0.0
	_phase_label.text = "MERGE THE TWO SWARMS"
	_hint_label.text = "Fly the gold leader between the two mills and pull them together."

func _update_level(delta: float):
	if is_instance_valid(_leader):
		_drive_with_keys(_leader, delta, LEADER_SPEED, LEADER_TURN_RATE)
	_update_metrics()
	_advance_objective(delta)
	_record(delta)
	_update_countdown_color()

func _record(delta: float):
	_record_accum += delta
	var step: float = 1.0 / RECORD_FPS
	while _record_accum >= step:
		_record_accum -= step
		_frames.append(_snapshot())

func _snapshot() -> Array:
	var frame: Array = []
	for ship in _swarm_ships():
		if is_instance_valid(ship):
			frame.append(int(ship.global_position.x))
			frame.append(int(ship.global_position.y))
			frame.append(int(rad_to_deg(ship.rotation)))
		else:
			frame.append(-1)
			frame.append(-1)
			frame.append(0)
	if is_instance_valid(_leader):
		frame.append(int(_leader.global_position.x))
		frame.append(int(_leader.global_position.y))
		frame.append(int(rad_to_deg(_leader.rotation)))
	else:
		frame.append(-1)
		frame.append(-1)
		frame.append(0)
	return frame

func _update_metrics():
	var swarm: Array = _swarm_ships()
	var positions: Array = _positions(swarm)
	_center_a = METRICS.center_of_mass(_positions(_group_a))
	_center_b = METRICS.center_of_mass(_positions(_group_b))
	_center_all = METRICS.center_of_mass(positions)
	_merged = METRICS.is_merged(positions, MERGE_DISTANCE)
	if _merged:
		_goal_distance = _center_all.distance_to(_planet) / SimulationManager.PX_PER_METER
		_circliness = METRICS.circliness(positions, _headings(swarm))
		_loss = METRICS.loss(_goal_distance, _circliness)
		if _minimum_loss < 0.0 or _loss < _minimum_loss:
			_minimum_loss = _loss
	else:
		_goal_distance = -1.0
		_circliness = -1.0
		_loss = -1.0
	if _metrics_panel != null:
		_metrics_panel.set_metrics("MERGED" if _merged else "SEPARATE", _loss, _minimum_loss, _goal_distance, _circliness)
		_refresh_legend()

func _refresh_legend():
	if _legend_merged == _merged:
		return
	_legend_merged = _merged
	if _merged:
		_metrics_panel.set_legend([
			{"color": C_MERGED, "label": "Combined center"},
			{"color": C_GOAL, "label": "End point"},
		])
	else:
		_metrics_panel.set_legend([
			{"color": C_GROUP_A, "label": "Group A center"},
			{"color": C_GROUP_B, "label": "Group B center"},
			{"color": C_GOAL, "label": "End point"},
		])

func _swarm_at_goal() -> bool:
	return _center_all.distance_to(_planet) <= GOAL_RADIUS

func _leader_is_clear() -> bool:
	if not is_instance_valid(_leader):
		return true
	return _leader.global_position.distance_to(_center_all) >= ESCAPE_DISTANCE

func _advance_objective(delta: float):
	match _objective:
		Objective.MERGE:
			if _merged:
				if _merge_time < 0.0:
					_merge_time = _elapsed
				_set_objective(Objective.DELIVER, "WALK THE SWARM TO THE PLANET",
					"The swarm is one mill. Lead it into the white ring around the planet.")
		Objective.DELIVER:
			if not _merged:
				_set_objective(Objective.MERGE, "MERGE THE TWO SWARMS",
					"The swarm broke apart. Pull the groups back into one mill.")
			elif _swarm_at_goal():
				if _deliver_time < 0.0:
					_deliver_time = _elapsed
				_set_objective(Objective.ESCAPE, "SLIP AWAY FROM THE SWARM",
					"Now leave. Get clear of the mill without dragging it off the planet.")
		Objective.ESCAPE:
			_update_escape(delta)

func _update_escape(delta: float):
	if not _merged:
		_hold_elapsed = 0.0
		_set_objective(Objective.MERGE, "MERGE THE TWO SWARMS",
			"The swarm broke apart. Pull the groups back into one mill.")
		return
	if not _swarm_at_goal():
		_hold_elapsed = 0.0
		_set_objective(Objective.DELIVER, "WALK THE SWARM TO THE PLANET",
			"The mill drifted off the planet. Bring it back into the white ring.")
		return
	if _circliness < MILL_MINIMUM or not _leader_is_clear():
		_hold_elapsed = 0.0
		return
	_hold_elapsed += delta
	if _hold_elapsed >= HOLD_SECONDS:
		_objective = Objective.COMPLETE
		_escape_time = _elapsed
		_finish("delivered")

func _set_objective(objective: int, title: String, hint: String):
	_objective = objective
	_hold_elapsed = 0.0
	_phase_label.text = title
	_hint_label.text = hint

func _objective_text() -> String:
	if _objective == Objective.COMPLETE:
		return "MERGED [done]   ON PLANET [done]   LEADER CLEAR [done]"
	var merged_mark: String = "[done]" if _merged else "[  ]"
	var goal_mark: String = "[done]" if _merged and _swarm_at_goal() else "[  ]"
	var clear_mark: String = "[  ]"
	if _objective == Objective.ESCAPE and _hold_elapsed > 0.0:
		clear_mark = "[%.1fs / %.1fs]" % [_hold_elapsed, HOLD_SECONDS]
	return "MERGED %s   ON PLANET %s   LEADER CLEAR %s" % [merged_mark, goal_mark, clear_mark]

func _update_event_label():
	if _event_label != null:
		_event_label.text = _objective_text()

func _event_summary() -> String:
	return "Minimum loss: %s\nGoal distance: %s\nCircliness: %s" % [
		_metric_text(_minimum_loss), _metric_text(_goal_distance), _metric_text(_circliness)]

func _metric_text(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.3f" % value

func _finish(reason: String):
	for ship in _swarm_ships():
		if is_instance_valid(ship):
			ship.set_physics_process(false)
	if is_instance_valid(_leader):
		_leader.set_physics_process(false)
	if not _frames.is_empty():
		_frames.append(_snapshot())
	super(reason)
	_submit_entry()

func _outcome() -> String:
	return "win" if _end_reason == "delivered" else "timeout"

func _agent_value(property: String, fallback: float) -> float:
	for ship in _swarm_ships():
		if is_instance_valid(ship):
			return ship.get(property)
	return fallback

func _run_stats() -> Dictionary:
	return {
		"merge_time": snappedf(_merge_time, 0.01),
		"deliver_time": snappedf(_deliver_time, 0.01),
		"escape_time": snappedf(_escape_time, 0.01),
		"minimum_loss": snappedf(_minimum_loss, 0.001),
		"final_loss": snappedf(_loss, 0.001),
		"circliness": snappedf(_circliness, 0.001),
		"goal_distance": snappedf(_goal_distance, 0.001),
		"agents": _placements.size(),
		"groups": 2,
		"merge_distance": MERGE_DISTANCE,
		"goal_radius": GOAL_RADIUS,
		"escape_distance": ESCAPE_DISTANCE,
	}

func _submit_entry():
	if _submitted or _frames.is_empty():
		return
	_submitted = true
	_submit_btn.disabled = true
	_submit_btn.text = "SUBMITTING..."
	if not EvalUploader.submit_finished.is_connected(_on_submit_finished):
		EvalUploader.submit_finished.connect(_on_submit_finished)
	var run := {
		"outcome": _outcome(),
		"detection_time": snappedf(_merge_time, 0.01),
		"capture_time": -1.0,
		"goal_time": snappedf(_deliver_time, 0.01),
		"fps": int(RECORD_FPS),
		"defenders": _placements.size(),
		"view": int(_agent_value("view_distance", 200.0)),
		"fov": int(_agent_value("fov_degrees", 60.0)),
		"planet": [int(_planet.x), int(_planet.y), int(PLANET_RADIUS)],
		"arena": [int(_arena.x), int(_arena.y)],
		"frames": _frames,
		"stats": _run_stats(),
	}
	EvalUploader.submit_run(_level_id(), _agent_program, _placements_payload(), run)

func _show_outcome(reason: String):
	var title: String
	var headline: String
	if reason == "delivered":
		title = "SWARM DELIVERED"
		headline = "Both groups merged, the mill reached the planet and it held together after you left."
		_phase_label.add_theme_color_override("font_color", C_GREEN)
	else:
		title = "OUT OF TIME"
		headline = _timeout_headline()
		_phase_label.add_theme_color_override("font_color", C_RED)
	_phase_label.text = title
	_show_result(title, "%s\n\n%s\n\nThe run is submitted automatically and rendered on the website." % [headline, _event_summary()], not _submitted)

func _timeout_headline() -> String:
	match _objective:
		Objective.MERGE:
			return "The clock ran out with the two swarms still apart."
		Objective.DELIVER:
			return "The swarms merged, but the mill never reached the planet."
		_:
			return "The mill reached the planet, but you never got clear of it in time."

func _draw_level():
	_draw_dashed_circle(_planet, GOAL_RADIUS, Color(C_GOAL.r, C_GOAL.g, C_GOAL.b, 0.35), 1.5)
	_draw_marker(_planet, C_GOAL, 16.0)
	if _objective == Objective.ESCAPE:
		_draw_dashed_circle(_center_all, ESCAPE_DISTANCE, Color(C_MERGED.r, C_MERGED.g, C_MERGED.b, 0.28), 1.5)
	if _live_ships(_swarm_ships()).is_empty():
		return
	if _merged:
		_draw_marker(_center_all, C_MERGED, 13.0)
	else:
		_draw_marker(_center_a, C_GROUP_A, 13.0)
		_draw_marker(_center_b, C_GROUP_B, 13.0)

func _draw_marker(center: Vector2, color: Color, radius: float):
	var arm: float = radius + 7.0
	var shadow := Color(0.0, 0.0, 0.0, 0.55)
	draw_arc(center, radius + 2.0, 0.0, TAU, 28, shadow, 4.0, true)
	draw_arc(center, radius, 0.0, TAU, 28, color, 2.0, true)
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), color, 2.0, true)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), color, 2.0, true)
