extends "res://levels/modes/FARPBase.gd"

var _rng := RandomNumberGenerator.new()

func _launch_label() -> String:
	return "LAUNCH EVADER (S) >"

func _setup_level():
	_rng.randomize()
	_add_top_button("REROLL (R)", _reroll_level)
	_launch_btn.text = _launch_label()
	_place_saved_layout()

func _restart_level():
	_place_saved_layout()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()
	_launch_btn.text = _launch_label()

# Only REROLL changes the layout: restarting or coming back from the workspace
# replays the scatter the player last rolled.
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

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, SCATTER_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, SCATTER_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
