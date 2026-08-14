extends "res://levels/modes/WaveBase.gd"

func _level_id() -> String:
	return "farp3"

func _level_title() -> String:
	return "LEVEL 3 - HOLD THE WAVE"

func _level_subtitle() -> String:
	return "%d evaders come in %s from the red ring. A defender that touches one destroys it and keeps hunting. Capture every evader before any of them reaches the planet. Press W to switch the wave style, REROLL for a new scatter." % [EVADER_COUNT, _wave_word()]

func _walkthrough_lines() -> Array:
	return [
		"GOAL: destroy every evader in the wave before any of them touches the planet.",
		"1.  %d defenders are dropped at random inside the blue placement ring, exactly as in Level 2." % RING_COUNT,
		"2.  Open WORKSPACE and write the algorithm all of them run. You cannot move them by hand.",
		"3.  WAVE picks how the evaders arrive. SEQUENTIAL sends the next one only after the last is gone, SIMULTANEOUS sends all %d at once." % EVADER_COUNT,
		"4.  Press LAUNCH WAVE. Every evader spawns on the red ring and drives straight at the planet.",
		"5.  A defender that touches an evader destroys it. The defender survives and can take the next one.",
		"6.  The wave always plays out in full. One evader reaching the planet loses the run, however many you had already destroyed.",
		"7.  The run is a win only if all %d evaders are destroyed." % EVADER_COUNT,
		"8.  The server benchmarks your algorithm over many waves.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"One defender can clear the whole wave here, so an algorithm that chases hard pays off more than one that holds position.",
		"SEQUENTIAL gives your defenders time to reset between evaders. SIMULTANEOUS punishes a layout that leaves one arc uncovered.",
		"The evaders arrive within a narrow arc of each other, so a defender parked on the far side may never see any of them.",
		"WHEN SEES ENEMY with DO FACE and DO FORWARD turns a sighting into a capture. Without it you will watch evaders sail past.",
		"Speed matters more than in Level 2 - a slow defender that kills one evader may not reach the next in time.",
		"REROLL a few scatters before you settle. The server benchmarks the layout you launched with.",
	]
