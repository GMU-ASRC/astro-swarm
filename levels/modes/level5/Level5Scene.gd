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

func _walkthrough_lines() -> Array:
	return [
		"GOAL: stop all %d evaders before they reach the planet." % SIEGE_EVADERS,
		"1.  %d defenders are dropped at random inside the blue placement ring, exactly as in Level 2." % RING_COUNT,
		"2.  Open WORKSPACE and write the algorithm all of them run.",
		"3.  Press LAUNCH SIEGE. There are no waves here: every evader spawns at once, spread around the arena edges.",
		"4.  Each one drives straight at the planet from wherever it spawned, so they arrive at different times.",
		"5.  A capture destroys BOTH ships, and there are as many evaders as defenders, so a perfect run trades one for one.",
		"6.  The run plays out until every evader is destroyed or has reached the planet.",
		"7.  The server benchmarks your algorithm over many sieges and reports the share of evaders destroyed and the defenders lost.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"The evaders spawn on the arena border, not a ring, so the ones on the long sides arrive noticeably later than the ones above and below.",
		"Every defender that trades itself leaves a hole, and here there is no next wave to fill it. Spend them on the closest threat.",
		"Several defenders converging on one evader is the fastest way to lose. WHEN SEES ALLY with a turn keeps them apart.",
		"Holding an arc near the planet beats chasing far out: an evader you miss on the way out will be behind your line.",
		"A wide FOV finds more of the %d at once, but the short range that comes with it may not reach them in time." % SIEGE_EVADERS,
		"REROLL a few scatters before you settle. The server benchmarks the layout you launched with.",
	]

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
	_show_result(title, "%s\n\n%s" % [headline, _event_summary()])

func _draw_level():
	super()
	if _phase == Phase.SETUP:
		_draw_spawn_band()
