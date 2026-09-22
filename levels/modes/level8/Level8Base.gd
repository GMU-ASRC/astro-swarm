extends "res://levels/modes/level8/Level8Deployment.gd"

const BOARD := preload("res://ui/hud/PlanetBoard.gd")

const PLANET_A_SCENE := "res://levels/modes/level8/Level8PlanetA.tscn"
const PLANET_B_SCENE := "res://levels/modes/level8/Level8PlanetB.tscn"

const HANDOVER_DELAY := 3.0 # seconds the planet A result is held before planet B loads

var _record_accum: float = 0.0
var _evader_slots: Array = []
var _commit_btn: Button = null
var _travelling: bool = false
var _board: PanelContainer = null

func _other_scene() -> String:
	return PLANET_B_SCENE if _planet_index() == STATE.PLANET_A else PLANET_A_SCENE

func _level_id() -> String:
	return "farp8"

func _planet_collisions() -> bool:
	return _planet_index() == STATE.PLANET_A

func _planet_seed() -> int:
	return STATE.planet_seed(_planet_index())

func _star_seed() -> int:
	return STATE.planet_seed(_planet_index())

func _level_title() -> String:
	return "LEVEL 8 - PLANET %s" % _planet_letter()

func _level_subtitle() -> String:
	return "Planet A starts with every defender and planet B has none. Lead them around with the shuttle and call them across between the two planets, then both planets are attacked in turn."

func _launch_label() -> String:
	return "START DEPLOYMENT (S) >"

func _can_reroll() -> bool:
	return false

func _shortcut_hint() -> String:
	return "Shortcuts: S start  ·  P replay  ·  E call one in  ·  Q go dark"

func _time_limit() -> float:
	if STATE.stage == STATE.Stage.ALLOCATE:
		return STATE.ALLOCATE_SECONDS
	return STATE.ASSAULT_SECONDS

func _timer_text() -> String:
	return _countdown_text()

func _walkthrough_lines() -> Array:
	return [
		"GOAL: hold both planets. Planet A and planet B each face %d evaders, and you only have %d defenders for the pair." % [STATE.EVADERS_PER_PLANET, STATE.TOTAL_DEFENDERS],
		"1.  All %d defenders start parked around planet A. Planet B starts empty." % STATE.TOTAL_DEFENDERS,
		"2.  Open WORKSPACE and write the algorithm every defender runs, on both planets.",
		"3.  Press START DEPLOYMENT to open the window. You fly the gold shuttle: forward and back drive, left and right turn (WASD or arrow keys, remappable in Settings).",
		"4.  Every defender runs your workspace algorithm here as well as in the fight, so they sweep on their own during the window.",
		"5.  The shuttle reads to them as one of their own. Whatever your WHEN SEES ALLY rule does is how they react to you, and that is the only lever you have to steer them.",
		"6.  Q takes the shuttle dark. A purple shuttle is off their sensors entirely, so they carry on as if you were not there and you can leave without pulling them after you. Q again brings it back to gold.",
		"7.  Fly into the blue jump gate at the edge of the arena to cross to the other planet. The defenders stay behind.",
		"8.  Sit inside the blue placement band and press E to call a defender across from the other planet. It leaves purple, flies in through the gate and settles on the marker you dropped, facing the way you were.",
		"9.  The window lasts %d seconds, or press BEGIN ASSAULT to close it early. Anything still crossing when it closes lands where it was headed." % int(STATE.ALLOCATE_SECONDS),
		"10. Planet A is attacked first, then planet B. Both fights play out with the split you chose, and a planet with nothing on it is lost.",
		"11. The panel on the right tracks both planets at once: a pip for every evader each one faces, red when it lands and green when it is stopped, so you can read planet B's result while you are standing on planet A.",
		"12. You keep flying through both assaults. E is done with, but the shuttle still reads as an ally, so you can pull defenders onto an evader they have not seen. Q still takes you dark when you would rather not disturb them.",
		"The camera follows the shuttle. Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"An even split is the obvious answer, and it is not always the right one. Both planets face the same %d evaders, so anything you leave standing idle on A is wasted." % STATE.EVADERS_PER_PLANET,
		"Calling one across is the fast way to move a defender. Nudging it with the shuttle is the precise way to place it once it has landed.",
		"An algorithm with no WHEN SEES ALLY rule ignores the shuttle completely, and then the marker is the only placement tool you have.",
		"Go dark before you fly off, or the half of the line that can see you keeps reacting to you and drifts off the arc it was covering.",
		"Drop your markers spread around the band. Every defender that lands on the same spot is watching the same sky.",
		"The same algorithm runs on both planets, so write one that works with a thin line as well as a thick one.",
		"Close the window early once the split looks right. The leftover time buys you nothing.",
		"The shuttle cannot catch anything, in the window or in the fight. All it ever does is move the ships that can.",
		"Flying into a fight cuts both ways: you can pull a defender onto an evader it never saw, or drag it off the arc that was covering the one behind you.",
	]

func _setup_level():
	_rng.randomize()
	_launch_btn.text = _launch_label()
	_commit_btn = _make_compact_btn("BEGIN ASSAULT")
	_commit_btn.pressed.connect(_commit)
	_commit_btn.visible = false
	_top_bar.add_child(_commit_btn)
	_build_board()
	if not STATE.running:
		STATE.reset(_scatter_placements())
	_spawn_garrison()
	_resume_stage()

func _build_board():
	_board = BOARD.new()
	_board.label_font = FONT_REG
	_board.text_color = C_TEXT
	_board.dim_color = C_DIM
	_board.stopped_color = C_GREEN
	_board.breach_color = C_RED
	_board.border_color = C_BORDER
	_board.background_color = Color(C_PANEL.r, C_PANEL.g, C_PANEL.b, 0.88)
	_board.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_board.offset_left = -268
	_board.offset_top = 58
	_board.offset_right = -16
	_board.offset_bottom = 58
	_hud_root.add_child(_board)
	_hud_root.move_child(_board, 0)
	_board.build(["PLANET A", "PLANET B"], STATE.EVADERS_PER_PLANET)

func _refresh_board():
	if _board == null:
		return
	for planet in [STATE.PLANET_A, STATE.PLANET_B]:
		var here: bool = planet == _planet_index()
		if here and _fighting():
			_board.set_planet(planet, true, _destroyed, _breached, "%d THROUGH" % _breached)
			continue
		var result: Dictionary = STATE.results[planet]
		if not result.is_empty():
			var through: int = int(result.get("breached", 0))
			_board.set_planet(planet, here, int(result.get("destroyed", 0)), through, "%d THROUGH" % through)
			continue
		_board.set_planet(planet, here, 0, 0, "%d DEFENDERS" % _count_at(planet))

func _fighting() -> bool:
	return STATE.stage != STATE.Stage.ALLOCATE and _phase != Phase.SETUP

func _breach_evader(evader: Node2D):
	super(evader)
	if _board != null:
		_board.flash(_planet_index())

func _resume_stage():
	if STATE.stage == STATE.Stage.ALLOCATE:
		if STATE.deploying:
			_begin_allocation()
		return
	if STATE.stage == STATE.Stage.ASSAULT_A and _planet_index() == STATE.PLANET_A:
		_start_assault()
		return
	if STATE.stage == STATE.Stage.ASSAULT_B and _planet_index() == STATE.PLANET_B:
		_start_assault()

func _restart_level():
	_despawn_shuttle()
	STATE.running = false
	if _planet_index() != STATE.PLANET_A:
		_change_scene(PLANET_A_SCENE)
		return
	STATE.reset(_scatter_placements())
	_spawn_garrison()
	_launch_btn.text = _launch_label()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()
	if _commit_btn != null:
		_commit_btn.visible = false

func _leave():
	STATE.running = false
	super()

# Going to the workspace reloads this scene, so the live line is written back
# before the level is torn down.
func _open_workspace():
	if STATE.stage == STATE.Stage.ALLOCATE:
		_hand_scene_over()
	super()

func _scatter_placements() -> Array:
	var out: Array = []
	for _index in STATE.TOTAL_DEFENDERS:
		var pos: Vector2 = _garrison_point()
		for _attempt in SCATTER_ATTEMPTS:
			if _is_clear_of(pos, out):
				break
			pos = _garrison_point()
		out.append({"pos": pos, "rot": _rng.randf() * TAU})
	return out

func _garrison_point() -> Vector2:
	var angle: float = _rng.randf() * TAU
	var radius: float = _rng.randf_range(PLACE_MIN, PLACE_MAX)
	return _planet + Vector2(radius, 0.0).rotated(angle)

func _spawn_garrison():
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	_defender_ships.clear()
	_placements.clear()
	for placement in STATE.garrison(_planet_index()):
		_placements.append(placement)
		_spawn_defender(placement, PlayerData.ship_blocks)
	_update_count()

func _launch():
	_begin_allocation()

func _begin_allocation():
	STATE.stage = STATE.Stage.ALLOCATE
	STATE.deploying = true
	_start_active()
	_elapsed = STATE.ALLOCATE_SECONDS - STATE.allocate_remaining
	_launch_shuttle()
	_commit_btn.visible = true
	_phase_label.text = "DEPLOYMENT WINDOW - PLANET %s" % _planet_letter()
	_hint_label.text = "The defenders run your algorithm and read the gold shuttle as an ally. Q goes dark, E calls one across onto a marker."
	_update_count()

func _cross_to_other_planet():
	_change_scene(_other_scene())

func _update_level(delta: float):
	if _travelling:
		return
	_pilot_shuttle(delta)
	if STATE.stage == STATE.Stage.ALLOCATE:
		_update_allocation(delta)
		return
	_record(delta)
	_update_countdown_color()

func _commit():
	if STATE.stage != STATE.Stage.ALLOCATE:
		return
	_hand_scene_over()
	STATE.stage = STATE.Stage.ASSAULT_A
	_commit_btn.visible = false
	if _planet_index() != STATE.PLANET_A:
		_change_scene(PLANET_A_SCENE)
		return
	_start_assault()

func _start_assault():
	if not is_instance_valid(_shuttle):
		_launch_shuttle()
	if _commit_btn != null:
		_commit_btn.visible = false
	_start_active()
	_reset_counters()
	_evader_slots.clear()
	_record_accum = 0.0
	_spawn_edge_wave(STATE.EVADERS_PER_PLANET)
	_evader_slots = _evaders.duplicate()
	STATE.frames.append(_snapshot())
	_phase_label.text = "PLANET %s UNDER ATTACK" % _planet_letter()
	_hint_label.text = "%d evaders inbound, %d defenders holding. You keep flying: lead them onto the threat, or go dark and stay out of it." % [STATE.EVADERS_PER_PLANET, _defender_ships.size()]
	_update_count()

func _track_events():
	if _travelling or _phase != Phase.ACTIVE or STATE.stage == STATE.Stage.ALLOCATE:
		return
	_resolve_evaders()
	if _evaders.is_empty():
		_finish("cleared")

func _record(delta: float):
	_record_accum += delta
	var step: float = 1.0 / STATE.RECORD_FPS
	while _record_accum >= step:
		_record_accum -= step
		STATE.frames.append(_snapshot())

func _snapshot() -> Array:
	var frame: Array = []
	for index in STATE.TOTAL_DEFENDERS:
		_append_slot(frame, _defender_ships[index] if index < _defender_ships.size() else null)
	for index in STATE.EVADERS_PER_PLANET:
		_append_slot(frame, _evader_slots[index] if index < _evader_slots.size() else null)
	_append_slot(frame, _shuttle)
	return frame

func _append_slot(frame: Array, ship):
	if ship != null and is_instance_valid(ship):
		frame.append(int(ship.global_position.x))
		frame.append(int(ship.global_position.y))
		frame.append(int(rad_to_deg(ship.rotation)))
		return
	frame.append(-1)
	frame.append(-1)
	frame.append(0)

func _finish(reason: String):
	if _travelling:
		return
	if STATE.stage == STATE.Stage.ALLOCATE:
		_commit()
		return
	STATE.frames.append(_snapshot())
	STATE.record_result(_planet_index(), {
		"defenders": _defender_ships.size(),
		"destroyed": _destroyed,
		"breached": _breached,
		"detect": _detect_time,
		"goal": _goal_time,
		"reason": reason,
	})
	if _planet_index() == STATE.PLANET_A:
		STATE.stage = STATE.Stage.ASSAULT_B
		_hand_over(reason)
		return
	STATE.stage = STATE.Stage.DONE
	super(reason)

func _hand_over(reason: String):
	_phase = Phase.DONE
	_stop_ships()
	var held: bool = _breached == 0
	_phase_label.text = "PLANET A HELD" if held else "PLANET A BREACHED"
	_phase_label.add_theme_color_override("font_color", C_GREEN if held else C_RED)
	_hint_label.text = "%s Moving to planet B." % _planet_summary(reason)
	_update_event_label()
	await get_tree().create_timer(HANDOVER_DELAY).timeout
	if is_inside_tree():
		_change_scene(PLANET_B_SCENE)

func _planet_summary(reason: String) -> String:
	if reason == "timeout":
		return "The clock ran out with %d evaders still inbound." % _evaders.size()
	if _breached == 0:
		return "All %d evaders were stopped." % STATE.EVADERS_PER_PLANET
	return "%d of %d evaders got through." % [_breached, STATE.EVADERS_PER_PLANET]

func _stop_ships():
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(false)
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.set_physics_process(false)

func _clear_ships():
	_evader_slots.clear()
	super()

func _change_scene(path: String):
	if STATE.stage == STATE.Stage.ALLOCATE:
		_hand_scene_over()
	STATE.shuttle_parked = false
	_travelling = true
	if is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file(path)

func _update_count():
	_refresh_board()
	if _count_label == null:
		return
	if STATE.stage == STATE.Stage.ALLOCATE and _phase == Phase.ACTIVE:
		_count_label.text = "PLANET %s   A %d   B %d   INBOUND %d   SHUTTLE %s" % [
			_planet_letter(), _count_at(STATE.PLANET_A), _count_at(STATE.PLANET_B),
			_transits.size(), "DARK" if STATE.cloaked else "LIT"]
		return
	if _phase == Phase.SETUP:
		_count_label.text = "PLANET %s   DEFENDERS %d / %d" % [
			_planet_letter(), _defender_ships.size(), STATE.TOTAL_DEFENDERS]
		return
	_count_label.text = "DEFENDERS %d   INBOUND %d   DOWN %d   THROUGH %d" % [
		_live_defenders(), _evaders.size(), _destroyed, _breached]

func _update_event_label():
	if _event_label == null:
		return
	if STATE.stage == STATE.Stage.ALLOCATE:
		_event_label.text = "E CALLS ONE ACROSS   Q GOES %s   CROSSINGS %d" % [
			"LIT" if STATE.cloaked else "DARK", STATE.trips]
		return
	_event_label.text = "PLANET %s   DOWN %d/%d   THROUGH %d   CROSSINGS %d" % [
		_planet_letter(), _destroyed, STATE.EVADERS_PER_PLANET, _breached, STATE.trips]

func _event_summary() -> String:
	return "Planet A: %s\nPlanet B: %s\nEvaders stopped: %d of %d\nCrossings flown: %d" % [
		_result_line(STATE.PLANET_A), _result_line(STATE.PLANET_B),
		STATE.destroyed_total(), STATE.evaders_total(), STATE.trips]

func _result_line(planet: int) -> String:
	var result: Dictionary = STATE.results[planet]
	if result.is_empty():
		return "not fought"
	return "%d defenders, %d stopped, %d through" % [
		int(result.get("defenders", 0)), int(result.get("destroyed", 0)), int(result.get("breached", 0))]

func _show_outcome(_reason: String):
	var held: bool = STATE.both_held()
	var title: String = "BOTH PLANETS HELD" if held else "LINE BROKEN"
	var headline: String
	if held:
		headline = "Every evader was stopped on both planets. The split worked."
	elif STATE.breached_total() >= STATE.evaders_total():
		headline = "Both planets were overrun. The defenders never reached the fights that needed them."
	else:
		headline = "%d of %d evaders reached a planet." % [STATE.breached_total(), STATE.evaders_total()]
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if held else C_RED)
	_show_result(title, "%s\n\n%s" % [headline, _event_summary()])

func _outcome() -> String:
	if STATE.both_held():
		return "win"
	if STATE.breached_total() > 0:
		return "lose"
	return "timeout"

func _combined_placements() -> Array:
	var out: Array = []
	for planet in [STATE.PLANET_A, STATE.PLANET_B]:
		for placement in STATE.garrison(planet):
			out.append({"x": placement.pos.x, "y": placement.pos.y, "rot": placement.rot})
	return out

func _defender_value(property: String, fallback: float) -> float:
	for ship in _defender_ships:
		if is_instance_valid(ship):
			return ship.get(property)
	return fallback

func _first_time(key: String) -> float:
	var best: float = -1.0
	for planet in [STATE.PLANET_A, STATE.PLANET_B]:
		var value: float = float(STATE.results[planet].get(key, -1.0))
		if value >= 0.0 and (best < 0.0 or value < best):
			best = value
	return best

func _run_stats() -> Dictionary:
	return {
		"defenders_a": float(STATE.garrison(STATE.PLANET_A).size()),
		"defenders_b": float(STATE.garrison(STATE.PLANET_B).size()),
		"destroyed_a": float(STATE.results[STATE.PLANET_A].get("destroyed", 0)),
		"destroyed_b": float(STATE.results[STATE.PLANET_B].get("destroyed", 0)),
		"breached_a": float(STATE.results[STATE.PLANET_A].get("breached", 0)),
		"breached_b": float(STATE.results[STATE.PLANET_B].get("breached", 0)),
		"delivered": float(STATE.delivered),
		"trips": float(STATE.trips),
		"hold_rate": snappedf(STATE.hold_rate(), 0.01),
	}

func _submit_entry():
	if _submitted or STATE.frames.is_empty():
		return
	_submitted = true
	if not EvalUploader.submit_finished.is_connected(_on_submit_finished):
		EvalUploader.submit_finished.connect(_on_submit_finished)
	var run := {
		"outcome": _outcome(),
		"detection_time": snappedf(_first_time("detect"), 0.01),
		"capture_time": -1.0,
		"goal_time": snappedf(_first_time("goal"), 0.01),
		"fps": int(STATE.RECORD_FPS),
		"defenders": STATE.TOTAL_DEFENDERS,
		"view": int(_defender_value("view_distance", 200.0)),
		"fov": int(_defender_value("fov_degrees", 60.0)),
		"planet": [int(_planet.x), int(_planet.y), int(PLANET_RADIUS)],
		"arena": [int(_arena.x), int(_arena.y)],
		"frames": STATE.frames,
		"stats": _run_stats(),
	}
	EvalUploader.submit_run(_level_id(), PlayerData.get_ship_algorithm(), _combined_placements(), run)

func _draw_level():
	if STATE.stage == STATE.Stage.ALLOCATE:
		_draw_allocation()
		return
	if _phase == Phase.ACTIVE:
		_draw_spawn_band()
