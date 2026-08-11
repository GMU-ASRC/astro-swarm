extends "res://levels/modes/FARPBase.gd"

var _rng := RandomNumberGenerator.new()

func _level_id() -> String:
	return "farp2"

func _level_title() -> String:
	return "LEVEL 2 - PROGRAM THE RING"

func _level_subtitle() -> String:
	return "%d defenders are scattered at random inside the blue placement ring, facing random directions. You cannot move them - only your algorithm decides the outcome. Press REROLL for a different scatter. The layout on screen when you submit is the one the server benchmarks." % RING_COUNT

func _walkthrough_lines() -> Array:
	return [
		"GOAL: keep the red evader from reaching the center planet, using your algorithm alone.",
		"1.  %d defenders are dropped at random positions inside the blue placement ring, each facing a random direction." % RING_COUNT,
		"2.  You cannot place or move them. Open WORKSPACE and write the algorithm they all run.",
		"3.  Press REROLL for a different scatter and check your algorithm is not just lucky on one layout.",
		"4.  Press LAUNCH EVADER. A red evader spawns on the outer ring and drives straight at the planet.",
		"5.  DETECTION is logged the first time any defender sees the evader in its vision cone.",
		"6.  CAPTURE is the first time a defender physically touches the evader. Capture ends the run and you win.",
		"7.  The GOAL TIME is when the evader reaches the planet. If that happens first, the planet is breached.",
		"8.  Submit your algorithm. The server benchmarks it on the layout you submitted, over many enemy approach angles.",
		"9.  The best submitted entry becomes the opponent in Level 3 - your algorithm and your layout.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"REROLL until you get a scatter you like - the layout on screen when you submit is the one you are graded on, and the one Level 3 pilots will face if you win.",
		"An algorithm that only works from one lucky layout will fall apart on the next reroll. Check a few before submitting.",
		"Make the defenders sweep: turning while moving forward covers far more angles than driving straight.",
		"Detection alone does not win. Add WHEN SEES ENEMY then DO FACE and DO FORWARD so a defender closes in and touches the evader.",
		"WHEN SEES ALLY plus a turn keeps defenders from bunching up and watching the same slice of sky.",
		"Widening FOV costs vision range. A short wide cone catches late, a long narrow cone catches early but misses often.",
		"Test with REROLL several times before submitting - the benchmark runs many random trials.",
	]

func _setup_level():
	_rng.randomize()
	_add_top_button("REROLL (R)", _reroll_level)
	_launch_btn.text = "LAUNCH EVADER (S) >"
	_place_saved_layout()

func _restart_level():
	_place_saved_layout()
	_phase_label.text = _level_title()
	_hint_label.text = _level_subtitle()
	_launch_btn.text = "LAUNCH EVADER (S) >"

func _place_saved_layout():
	# Only REROLL changes the layout: restarting or coming back from the
	# workspace replays the scatter the player last rolled.
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

func _launch():
	_start_active()
	var angle: float = _rng.randf() * TAU
	_spawn_scripted_evader(_planet + Vector2(EVADER_SPAWN_RADIUS, 0.0).rotated(angle))
	_phase_label.text = "EVADER INBOUND"
	_hint_label.text = "Your algorithm is driving every defender. Touch the evader to capture it before it reaches the planet."

func _draw_level():
	if _phase != Phase.SETUP:
		return
	draw_circle(_planet, SCATTER_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, SCATTER_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
