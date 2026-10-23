extends "res://levels/modes/supply/SupplyAssault.gd"

const BOARD := preload("res://ui/hud/PlanetBoard.gd")

var _board: PanelContainer = null
var _defender_picker: OptionButton = null

func _line_options() -> Array:
	return [10, 25]

func _has_attrition() -> bool:
	return true

func _planet_collisions() -> bool:
	return _planet_index() == STATE.PLANET_A

func _planet_seed() -> int:
	return STATE.planet_seed(_planet_index())

func _star_seed() -> int:
	return STATE.planet_seed(_planet_index())

func _level_title() -> String:
	return "LEVEL %d - PLANET %s" % [LevelInfo.number(_level_id()), _planet_letter()]

func _launch_label() -> String:
	return "START DEPLOYMENT (S) >"

func _can_reroll() -> bool:
	return false

func _time_limit() -> float:
	if STATE.stage == STATE.Stage.ALLOCATE:
		return STATE.ALLOCATE_SECONDS
	return STATE.ASSAULT_SECONDS

func _timer_text() -> String:
	return _countdown_text()

func _carries_genome_switches() -> bool:
	return STATE.running

func _setup_level():
	_rng.randomize()
	_launch_btn.text = _launch_label()
	_commit_btn = HUD_BUTTONS.make("BEGIN ASSAULT", HUD_BUTTONS.Kind.PRIMARY, 9)
	_commit_btn.pressed.connect(_commit)
	_commit_btn.visible = false
	_top_bar.add_child(_commit_btn)
	if not STATE.running or STATE.level_id != _level_id():
		_reset_run()
	_build_defender_picker()
	_build_board()
	if STATE.stage == STATE.Stage.ALLOCATE:
		_spawn_garrison()
	_resume_stage()

func _reset_run():
	_close_worlds()
	if not _line_options().has(STATE.defender_total):
		STATE.defender_total = _line_options()[0]
	STATE.reset(_level_id(), _planet_count(), [])
	STATE.capture(STATE.PLANET_A, _scatter_placements())

func _planet_names() -> Array:
	var names: Array = []
	for planet in _planet_count():
		names.append("PLANET %s" % STATE.letter(planet))
	return names

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
	_board.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hud_root.add_child(_board)
	_hud_root.move_child(_board, 0)
	_board.build(_planet_names(), STATE.evaders_per_planet())

func _build_defender_picker():
	_defender_picker = OptionButton.new()
	_defender_picker.focus_mode = Control.FOCUS_NONE
	HUD_BUTTONS.apply(_defender_picker, HUD_BUTTONS.Kind.NEUTRAL, 9)
	for option in _line_options():
		_defender_picker.add_item("%d DEFENDERS" % option)
	_defender_picker.select(_line_options().find(STATE.defender_total))
	_defender_picker.item_selected.connect(_on_defender_total_selected)
	_top_bar.add_child(_defender_picker)
	_refresh_defender_picker()

func _can_pick_defenders() -> bool:
	return _phase == Phase.SETUP and not STATE.deploying and STATE.stage == STATE.Stage.ALLOCATE and _planet_index() == STATE.PLANET_A

func _refresh_defender_picker():
	if _defender_picker != null:
		_defender_picker.visible = _can_pick_defenders()

func _on_defender_total_selected(index: int):
	if not _can_pick_defenders():
		_defender_picker.select(_line_options().find(STATE.defender_total))
		return
	STATE.defender_total = _line_options()[index]
	_reset_run()
	_spawn_garrison()
	_rebuild_board()
	queue_redraw()

func _rebuild_board():
	if _board != null:
		_board.queue_free()
	_build_board()
	_refresh_board()

func _refresh_board():
	if _board == null:
		return
	for planet in _planet_count():
		var here: bool = planet == _planet_index()
		var result: Dictionary = STATE.results[planet]
		if not result.is_empty():
			var through: int = int(result.get("breached", 0))
			_board.set_planet(planet, here, int(result.get("destroyed", 0)), through, "%d THROUGH" % through)
			continue
		_board.set_planet(planet, here, 0, 0, "%d DEFENDERS" % _count_at(planet))

func _breach_evader(evader: Node2D):
	super(evader)
	_flash_planet(_planet_index())

func _flash_planet(planet: int):
	if _board != null:
		_board.flash(planet)

func _resume_stage():
	if STATE.stage == STATE.Stage.ALLOCATE:
		if STATE.deploying:
			_begin_allocation()
		return
	if STATE.stage == STATE.Stage.ASSAULT:
		_start_assault()

func _restart_level():
	_despawn_shuttle()
	STATE.running = false
	_close_worlds()
	if _planet_index() != STATE.PLANET_A:
		_change_scene(_scene_for(STATE.PLANET_A))
		return
	_reset_run()
	_spawn_garrison()
	_rebuild_board()
	_launch_btn.text = _launch_label()
	_phase_label.text = _level_title()
	if _commit_btn != null:
		_commit_btn.visible = false
	_refresh_defender_picker()

func _exit_level(scene_path: String):
	STATE.running = false
	_close_worlds()
	super(scene_path)

# Going to the workspace reloads this scene, so the live line is written back
# before the level is torn down.
func _open_workspace():
	if STATE.stage == STATE.Stage.ALLOCATE:
		_hand_scene_over()
	elif STATE.stage == STATE.Stage.ASSAULT:
		_leave_planet()
		_hold_worlds(true)
	super()

func _scatter_placements() -> Array:
	var out: Array = []
	for _index in STATE.defender_total:
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
	_refresh_defender_picker()
	_phase_label.text = "DEPLOYMENT WINDOW - PLANET %s" % _planet_letter()
	_update_count()

func _update_level(delta: float):
	if _travelling:
		return
	_pilot_shuttle(delta)
	if STATE.stage == STATE.Stage.ALLOCATE:
		_update_allocation(delta)
		return
	_update_assault(delta)

func _finish(reason: String):
	if _travelling:
		return
	if STATE.stage == STATE.Stage.ALLOCATE:
		_commit()
		return
	_settle_transits()
	_store_tally()
	STATE.frames.append(_snapshot())
	STATE.stage = STATE.Stage.DONE
	var worlds = _worlds()
	if worlds != null:
		worlds.freeze()
	super(reason)

func _clear_ships():
	_evader_slots.clear()
	_defender_slots.clear()
	super()

func _change_scene(path: String):
	if _genome_switcher != null:
		_genome_switcher.carry()
	if STATE.stage == STATE.Stage.ALLOCATE:
		_hand_scene_over()
	elif STATE.stage == STATE.Stage.ASSAULT and STATE.running:
		_leave_planet()
	STATE.shuttle_parked = false
	_travelling = true
	if is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file(path)

func _planet_counts_text() -> String:
	var parts: Array = []
	for planet in _planet_count():
		parts.append("%s %d" % [STATE.letter(planet), _count_at(planet)])
	return "   ".join(PackedStringArray(parts))

func _update_count():
	_refresh_board()
	if _count_label == null:
		return
	if STATE.stage == STATE.Stage.ALLOCATE and _phase == Phase.ACTIVE:
		_count_label.text = "PLANET %s   %s   INBOUND %d   SHUTTLE %s" % [
			_planet_letter(), _planet_counts_text(), _transits.size() + STATE.crossings_to(_planet_index()), "DARK" if STATE.cloaked else "LIT"]
		return
	if _phase == Phase.SETUP:
		_count_label.text = "PLANET %s   DEFENDERS %d / %d" % [
			_planet_letter(), _defender_ships.size(), STATE.defender_total]
		return
	_count_label.text = "PLANET %s   %s   EVADERS %d   DOWN %d   THROUGH %d" % [
		_planet_letter(), _planet_counts_text(), _evaders.size(), _destroyed, _breached]

func _update_event_label():
	if _event_label == null:
		return
	if STATE.stage == STATE.Stage.ALLOCATE:
		_event_label.text = "E CALLS ONE ACROSS   Q GOES %s   CROSSINGS %d" % [
			"LIT" if STATE.cloaked else "DARK", STATE.trips]
		return
	_event_label.text = "PLANET %s   DOWN %d/%d   THROUGH %d   STILL TO COME %d   E CALLS ONE ACROSS   CROSSINGS %d" % [
		_planet_letter(), _destroyed, STATE.evaders_per_planet(), _breached, STATE.attack_queue.size(), STATE.trips]

func _event_summary() -> String:
	var lines: Array = []
	for planet in _planet_count():
		lines.append("Planet %s: %s" % [STATE.letter(planet), _result_line(planet)])
	lines.append("Evaders stopped: %d of %d" % [STATE.destroyed_total(), STATE.evaders_total()])
	lines.append("Crossings flown: %d" % STATE.trips)
	return "\n".join(PackedStringArray(lines))

func _result_line(planet: int) -> String:
	var result: Dictionary = STATE.results[planet]
	if result.is_empty():
		return "not attacked"
	return "%d defenders, %d stopped, %d through, %d lost" % [
		int(result.get("defenders", 0)), int(result.get("destroyed", 0)), int(result.get("breached", 0)), int(result.get("lost", 0))]

func _show_outcome(_reason: String):
	var held: bool = STATE.all_held()
	var every: String = "BOTH" if _planet_count() == 2 else "ALL"
	var title: String = "%s PLANETS HELD" % every if held else "LINE BROKEN"
	var headline: String
	if held:
		headline = "Every evader was stopped on %s planets. The split worked." % every.to_lower()
	elif STATE.breached_total() >= STATE.evaders_total():
		headline = "Every planet was overrun. The defenders never reached the fights that needed them."
	else:
		headline = "%d of %d evaders reached a planet." % [STATE.breached_total(), STATE.evaders_total()]
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if held else C_RED)
	_show_result(held, title, headline)

func _outcome() -> String:
	if STATE.all_held():
		return "win"
	if STATE.breached_total() > 0:
		return "lose"
	return "timeout"

func _combined_placements() -> Array:
	var out: Array = []
	for planet in _planet_count():
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
	for result in STATE.results:
		var value: float = float(result.get(key, -1.0))
		if value >= 0.0 and (best < 0.0 or value < best):
			best = value
	return best

func _run_stats() -> Dictionary:
	var stats := {
		"delivered": float(STATE.delivered),
		"trips": float(STATE.trips),
		"hold_rate": snappedf(STATE.hold_rate(), 0.01),
		"defenders_total": float(STATE.defender_total),
		"evaders_per_planet": float(STATE.evaders_per_planet()),
		"planets": float(_planet_count()),
	}
	for planet in _planet_count():
		var suffix: String = STATE.letter(planet).to_lower()
		var result: Dictionary = STATE.results[planet]
		stats["defenders_" + suffix] = float(STATE.garrison(planet).size())
		stats["destroyed_" + suffix] = float(result.get("destroyed", 0))
		stats["breached_" + suffix] = float(result.get("breached", 0))
		stats["lost_" + suffix] = float(result.get("lost", 0))
	return stats

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
		"defenders": STATE.defender_total,
		"view": int(_defender_value("view_distance", 200.0)),
		"fov": int(_defender_value("fov_degrees", 60.0)),
		"planet": [int(_planet.x), int(_planet.y), int(PLANET_RADIUS)],
		"arena": [int(_arena.x), int(_arena.y)],
		"frames": STATE.frames,
		"genome_switches": STATE.genome_switch_frames,
		"stats": _run_stats(),
	}
	EvalUploader.submit_run(_level_id(), _launch_algorithm(), _combined_placements(), run, _genome_schedule())

func _launch_algorithm() -> Array:
	var schedule: Array = _genome_schedule()
	return schedule[0]["algorithm"] if not schedule.is_empty() else PlayerData.get_ship_algorithm()

func _draw_level():
	if STATE.stage != STATE.Stage.DONE:
		_draw_allocation()
