extends "res://levels/modes/AssaultBase.gd"

const SIEGE_EVADERS := 5 # count, evaders that come in together

func _has_attrition() -> bool:
	return true

func _level_id() -> String:
	return "farp5"

func _level_title() -> String:
	return "LEVEL 5 - BREAK THE SIEGE"

func _level_subtitle() -> String:
	return "%d evaders come in at once off the arena edges, all driving at the planet. A capture destroys the defender that made it, so your %d bodies have to be spent well. REROLL for a new scatter." % [SIEGE_EVADERS, RING_COUNT]

func _launch_label() -> String:
	return "LAUNCH SIEGE (S) >"

func _launch():
	_start_active()
	_reset_counters()
	_spawn_edge_wave(SIEGE_EVADERS)
	_phase_label.text = "SIEGE INBOUND"
	_hint_label.text = "All %d are on their way in. Every capture costs you the defender that made it." % SIEGE_EVADERS
	_update_count()

func _track_events():
	if _phase != Phase.ACTIVE:
		return
	_resolve_evaders()
	if _evaders.is_empty():
		_finish("cleared")

func _update_count():
	if _count_label == null:
		return
	if _phase == Phase.SETUP:
		_count_label.text = "DEFENDERS %d / %d" % [_defender_ships.size(), RING_COUNT]
	else:
		_count_label.text = "DEFENDERS %d   INBOUND %d   DOWN %d   THROUGH %d" % [
			_live_defenders(), _evaders.size(), _destroyed, _breached
		]

func _update_event_label():
	_event_label.text = "DETECTED %s   DOWN %d/%d   THROUGH %d   LOST %d" % [
		_time_text(_detect_time), _destroyed, SIEGE_EVADERS, _breached, _defenders_lost
	]

func _event_summary() -> String:
	return "First detection: %s\nEvaders destroyed: %d of %d\nEvaders that reached the planet: %d%s" % [
		_time_text(_detect_time), _destroyed, SIEGE_EVADERS, _breached, _attrition_summary()
	]

func _show_outcome(reason: String):
	var held: bool = _breached == 0
	var title: String = "SIEGE BROKEN" if held else "PLANET BREACHED"
	var headline: String
	if reason == "timeout":
		title = "OUT OF TIME"
		headline = "The clock ran out with %d evaders still inbound." % _evaders.size()
	elif held:
		headline = "All %d evaders were destroyed before any of them touched the planet." % SIEGE_EVADERS
	else:
		headline = "%d of the %d evaders reached the planet." % [_breached, SIEGE_EVADERS]
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if held else C_RED)
	_show_result(held, title, headline)

func _draw_level():
	super()
	if _phase == Phase.SETUP:
		_draw_spawn_band()
