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
var _simultaneous: bool = false
var _wave_btn: Button

func _capture_destroys_defender() -> bool:
	return false

func _wave_word() -> String:
	return "at once" if _simultaneous else "one after another"

func _setup_level():
	_rng.randomize()
	_add_top_button("REROLL (R)", _reroll_level)
	_wave_btn = _make_compact_btn(_wave_button_text())
	_wave_btn.pressed.connect(_toggle_wave_style)
	_top_bar.add_child(_wave_btn)
	_launch_btn.text = "LAUNCH WAVE (S) >"
	_place_saved_layout()

func _wave_button_text() -> String:
	return "WAVE: SIMULTANEOUS" if _simultaneous else "WAVE: SEQUENTIAL"

func _toggle_wave_style():
	if _phase != Phase.SETUP:
		return
	_simultaneous = not _simultaneous
	_wave_btn.text = _wave_button_text()
	_hint_label.text = _level_subtitle()

func _restart_level():
	_wave_size = 0
	_place_saved_layout()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()
	_launch_btn.text = "LAUNCH WAVE (S) >"
	if _wave_btn != null:
		_wave_btn.text = _wave_button_text()
		_wave_btn.disabled = false

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
	return "Shortcuts: S start  ·  P replay  ·  R reroll  ·  W wave style"

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
	_evaders.clear()
	_capture_times.clear()
	_captured = 0
	_breached = 0
	_resolved = 0
	_launched = 0
	_wave_size = mini(EVADER_COUNT, maxi(1, _defender_ships.size()))
	_spawn_angles.clear()
	var base_angle: float = _rng.randf() * TAU
	for index in _evader_total():
		var spread: float = deg_to_rad(WAVE_SPREAD_DEGREES) * float(index)
		_spawn_angles.append(base_angle + spread + _rng.randf_range(-0.15, 0.15))
	if _simultaneous:
		for index in _evader_total():
			_launch_next_evader()
	else:
		_launch_next_evader()
	if _wave_btn != null:
		_wave_btn.disabled = true
	_phase_label.text = "WAVE INBOUND"
	_hint_label.text = "%d evaders are coming in %s. Capture every one before any of them touches the planet." % [_evader_total(), _wave_word()]

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
		_finish("capture" if _breached == 0 else "goal")
		return
	if not _simultaneous and _evaders.is_empty() and _launched < _evader_total():
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
		_count_label.text = "DEFENDERS %d   EVADERS DOWN %d / %d" % [_defender_ships.size(), _captured, _evader_total()]

func _event_summary() -> String:
	return "First detection: %s\nEvaders destroyed: %d of %d\nEvaders through: %d\nFirst planet hit: %s" % [
		_time_text(_detect_time), _captured, _evader_total(), _breached, _time_text(_goal_time)
	]

func _update_event_label():
	_event_label.text = "DETECTED %s   DOWN %d/%d   BREACHED %d   REACHED PLANET %s" % [
		_time_text(_detect_time), _captured, _evader_total(), _breached, _time_text(_goal_time)
	]

func _show_outcome(reason: String):
	var title: String
	var headline: String
	match reason:
		"capture":
			title = "PLANET DEFENDED"
			headline = "Every evader was destroyed before it reached the planet."
		"goal":
			title = "PLANET BREACHED"
			headline = "%d of %d evaders reached the planet." % [_breached, _evader_total()]
		_:
			title = "OUT OF TIME"
			headline = "The clock ran out with %d of %d evaders destroyed." % [_captured, _evader_total()]
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if reason == "capture" else C_RED)
	_show_result(title, "%s\n\n%s" % [headline, _event_summary()])

func _handle_shortcut(event: InputEvent) -> bool:
	if super(event):
		return true
	if _phase != Phase.SETUP or _guide_panel == null or _guide_panel.visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W:
		_toggle_wave_style()
		return true
	return false

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, SCATTER_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, SCATTER_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
	_draw_dashed_circle(_planet, EVADER_SPAWN_RADIUS, Color(1.0, 0.42, 0.32, 0.25), 1.5)
