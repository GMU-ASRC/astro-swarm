extends "res://levels/modes/FARPBase.gd"

const EXPLOSION := preload("res://entities/ship/Explosion.gd")

const EVADER_COUNT := 3
const EVADER_BLAST_SIZE := 90.0
const DEFENDER_BLAST_SIZE := 110.0
const WAVE_SPREAD_DEGREES := 40.0

var _rng := RandomNumberGenerator.new()
var _evaders: Array = []
var _spawn_angles: Array = []
var _launched: int = 0
var _wave_size: int = 0
var _captured: int = 0
var _breached: int = 0
var _resolved: int = 0
var _capture_times: Array = []
var _wave_phase: int = 0
var _total_captured: int = 0
var _total_breached: int = 0

func _capture_destroys_defender() -> bool:
	return false

func _simultaneous_phase() -> bool:
	return _wave_phase == 1

func _phase_name() -> String:
	return "ALL AT ONCE" if _simultaneous_phase() else "ONE AFTER ANOTHER"

func _setup_level():
	_rng.randomize()
	_add_top_button("REROLL (R)", _reroll_level)
	_launch_btn.text = "LAUNCH WAVES (S) >"
	_place_saved_layout()

func _restart_level():
	_wave_size = 0
	_wave_phase = 0
	_place_saved_layout()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()
	_launch_btn.text = "LAUNCH WAVES (S) >"

func _place_saved_layout():
	var saved: Array = PlayerData.get_level_placements(_level_id())
	if saved.is_empty():
		_roll_layout()
		return
	for placement in _placements_from_payload(saved):
		_placements.append(placement)
		_spawn_defender(placement, PlayerData.ship_blocks)
	_update_count()

func _roll_layout():
	for placement in _random_ring_placements(RING_COUNT, _rng):
		_placements.append(placement)
		_spawn_defender(placement, PlayerData.ship_blocks)
	_update_count()
	PlayerData.set_level_placements(_level_id(), _placements_payload())

func _can_reroll() -> bool:
	return _phase == Phase.SETUP

func _shortcut_hint() -> String:
	return "Shortcuts: S start  ·  P replay  ·  R reroll"

func _reroll_level():
	if _phase != Phase.SETUP:
		return
	_clear_ships()
	_placements.clear()
	_rng.randomize()
	_roll_layout()
	queue_redraw()

func _evader_total() -> int:
	if _wave_size > 0:
		return _wave_size
	return mini(EVADER_COUNT, maxi(1, _defender_ships.size()))

func _launch():
	_start_active()
	_capture_times.clear()
	_total_captured = 0
	_total_breached = 0
	_wave_phase = 0
	_wave_size = mini(EVADER_COUNT, maxi(1, _defender_ships.size()))
	_spawn_angles.clear()
	var base_angle: float = _rng.randf() * TAU
	for index in _evader_total():
		var spread: float = deg_to_rad(WAVE_SPREAD_DEGREES) * float(index)
		_spawn_angles.append(base_angle + spread + _rng.randf_range(-0.15, 0.15))
	_start_wave_phase()

func _start_wave_phase():
	_evaders.clear()
	_captured = 0
	_breached = 0
	_resolved = 0
	_launched = 0
	if _simultaneous_phase():
		for index in _evader_total():
			_launch_next_evader()
	else:
		_launch_next_evader()
	_phase_label.text = "WAVE %d OF 2 - %s" % [_wave_phase + 1, _phase_name()]
	_hint_label.text = "%d evaders are coming in %s. Capture every one before any of them touches the planet." % [
		_evader_total(), "at once" if _simultaneous_phase() else "one after another"
	]

func _reset_arena():
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	_defender_ships.clear()
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.queue_free()
	_evaders.clear()
	_evader = null
	for placement in _placements:
		_spawn_defender(placement, PlayerData.ship_blocks)
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(true)

func _advance_wave_phase():
	_wave_phase += 1
	_reset_arena()
	_start_wave_phase()

func _launch_next_evader():
	if _launched >= _evader_total():
		return
	var angle: float = _spawn_angles[_launched]
	var evader := _make_scripted_evader(_planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(angle))
	_evaders.append(evader)
	_evader = evader
	_launched += 1

func _clear_ships():
	super()
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.queue_free()
	_evaders.clear()

func _finish(reason: String):
	for evader in _evaders:
		if is_instance_valid(evader):
			evader.set_physics_process(false)
	super(reason)

func _blast(point: Vector2, size: float):
	var effect := EXPLOSION.new()
	effect.display_size = size
	add_child(effect)
	effect.global_position = point

func _track_events():
	if _phase != Phase.ACTIVE:
		return
	var live: Array = []
	for evader in _evaders:
		if not is_instance_valid(evader):
			continue
		if _detect_time < 0.0 and _any_defender_sees(evader):
			_detect_time = _elapsed
		if _evader_reached_goal(evader):
			if _goal_time < 0.0:
				_goal_time = _elapsed
			_breach_evader(evader)
			continue
		var catcher: Node2D = _defender_touching(evader)
		if catcher != null:
			_destroy_evader(evader, catcher)
			continue
		live.append(evader)
	_evaders = live
	if _resolved >= _evader_total():
		_total_captured += _captured
		_total_breached += _breached
		if _wave_phase == 0:
			_advance_wave_phase()
			return
		_finish("capture" if _total_breached == 0 else "goal")
		return
	if not _simultaneous_phase() and _evaders.is_empty() and _launched < _evader_total():
		_launch_next_evader()

func _breach_evader(evader: Node2D):
	_breached += 1
	_resolved += 1
	_blast(evader.global_position, EVADER_BLAST_SIZE)
	evader.queue_free()
	_update_count()

func _destroy_evader(evader: Node2D, catcher: Node2D):
	_captured += 1
	_resolved += 1
	_capture_times.append(_elapsed)
	if _capture_time < 0.0:
		_capture_time = _elapsed
	_blast(evader.global_position, EVADER_BLAST_SIZE)
	evader.queue_free()
	if _capture_destroys_defender() and is_instance_valid(catcher):
		_blast(catcher.global_position, DEFENDER_BLAST_SIZE)
		_defender_ships.erase(catcher)
		catcher.queue_free()
	_update_count()

func _any_defender_sees(evader: Node2D) -> bool:
	var target: Vector2 = evader.global_position
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		var to_evader: Vector2 = target - ship.global_position
		if to_evader.length() > ship.view_distance:
			continue
		if absf(angle_difference(ship.rotation, to_evader.angle())) <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

func _defender_touching(evader: Node2D) -> Node2D:
	var target: Vector2 = evader.global_position
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		if ship.global_position.distance_to(target) <= ship.hull_radius + evader.hull_radius:
			return ship
	return null

func _evader_reached_goal(evader: Node2D) -> bool:
	return evader.global_position.distance_to(_planet) <= PLANET_RADIUS + GOAL_MARGIN

func _update_count():
	if _count_label == null:
		return
	if _phase == Phase.SETUP:
		_count_label.text = "DEFENDERS %d / %d" % [_defender_ships.size(), RING_COUNT]
	else:
		_count_label.text = "DEFENDERS %d   WAVE %d/2   DOWN %d / %d" % [
			_defender_ships.size(), _wave_phase + 1, _captured, _evader_total()
		]

func _event_summary() -> String:
	return "First detection: %s\nEvaders destroyed: %d of %d across both waves\nEvaders through: %d\nFirst planet hit: %s" % [
		_time_text(_detect_time), _total_captured, _evader_total() * 2, _total_breached, _time_text(_goal_time)
	]

func _update_event_label():
	_event_label.text = "DETECTED %s   WAVE %d/2   DOWN %d/%d   BREACHED %d" % [
		_time_text(_detect_time), _wave_phase + 1, _captured, _evader_total(), _breached
	]

func _show_outcome(reason: String):
	var title: String
	var headline: String
	match reason:
		"capture":
			title = "PLANET DEFENDED"
			headline = "Both waves were stopped: every evader destroyed before it reached the planet."
		"goal":
			title = "PLANET BREACHED"
			headline = "%d evaders reached the planet across the two waves." % _total_breached
		_:
			title = "OUT OF TIME"
			headline = "The clock ran out during wave %d of 2, with %d of %d destroyed." % [
				_wave_phase + 1, _captured, _evader_total()
			]
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if reason == "capture" else C_RED)
	_show_result(title, "%s\n\n%s" % [headline, _event_summary()])

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, SCATTER_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, SCATTER_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
	_draw_dashed_circle(_planet, EVADER_SPAWN_RADIUS, Color(1.0, 0.42, 0.32, 0.25), 1.5)
