extends "res://levels/modes/AssaultBase.gd"

const WAVE_GAP_SECONDS := 1.5 # seconds between one evader resolving and the next wave launching

var _wave: int = 0
var _gap_left: float = 0.0

func _launch_label() -> String:
	return "LAUNCH WAVES (S) >"

func _wave_spawn_angle() -> float:
	return _rng.randf() * TAU

func _launch():
	_start_active()
	_reset_counters()
	_wave = 0
	_gap_left = 0.0
	_launch_wave()
	_phase_label.text = "WAVES INBOUND"
	_hint_label.text = _wave_hint()

func _wave_hint() -> String:
	if _has_attrition():
		return "One evader at a time, wave after wave. Every capture costs the defender that made it, so the run ends when your line is gone or the clock runs out."
	return "One evader at a time, wave after wave. A defender that catches one survives and takes the next. Hold until the clock runs out."

func _launch_wave():
	_wave += 1
	_spawn_evader_at(_planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(_wave_spawn_angle()))
	_update_count()

func _track_events():
	if _phase != Phase.ACTIVE:
		return
	_resolve_evaders()
	if _live_defenders() < 1:
		_finish("overrun")
		return
	if not _evaders.is_empty():
		_gap_left = WAVE_GAP_SECONDS
		return
	_gap_left -= get_process_delta_time()
	if _gap_left <= 0.0:
		_launch_wave()

func _update_count():
	if _count_label == null:
		return
	if _phase == Phase.SETUP:
		_count_label.text = "DEFENDERS %d / %d" % [_defender_ships.size(), RING_COUNT]
	else:
		_count_label.text = "DEFENDERS %d   WAVE %d   DOWN %d   THROUGH %d" % [
			_live_defenders(), _wave, _destroyed, _breached
		]

func _update_event_label():
	_event_label.text = "DETECTED %s   WAVES %d   DOWN %d   THROUGH %d   LOST %d" % [
		_time_text(_detect_time), _wave, _destroyed, _breached, _defenders_lost
	]

func _event_summary() -> String:
	return "First detection: %s\nWaves launched: %d\nEvaders destroyed: %d\nEvaders that reached the planet: %d%s" % [
		_time_text(_detect_time), _wave, _destroyed, _breached, _attrition_summary()
	]

func _show_outcome(reason: String):
	var held: bool = _breached == 0
	var title: String = "PLANET HELD" if held else "PLANET BREACHED"
	var headline: String
	if reason == "overrun":
		title = "LINE WIPED OUT"
		headline = "Every defender was spent. %d evaders were destroyed and %d reached the planet." % [_destroyed, _breached]
	elif held:
		headline = "The clock ran out with every one of the %d waves stopped." % _wave
	else:
		headline = "%d of the %d evaders sent reached the planet." % [_breached, _launched]
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if held else C_RED)
	_show_result(title, "%s\n\n%s" % [headline, _event_summary()])

func _draw_level():
	super()
	if _phase == Phase.SETUP:
		_draw_dashed_circle(_planet, EVADER_SPAWN_RADIUS, Color(1.0, 0.42, 0.32, 0.25), 1.5)
