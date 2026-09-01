extends "res://levels/modes/WaveBase.gd"

func _level_id() -> String:
	return "farp3"

func _level_title() -> String:
	return "LEVEL 3 - HOLD THE WAVES"

func _level_subtitle() -> String:
	return "%d waves come in, one evader at a time, each from a fresh random bearing on the red ring. A defender that catches one destroys it and keeps hunting. Hold every wave. REROLL for a new scatter." % MAX_WAVES

func _walkthrough_lines() -> Array:
	return [
		"GOAL: keep every one of the %d waves off the planet." % MAX_WAVES,
		"1.  %d defenders are dropped at random inside the blue placement ring, exactly as in Level 2." % RING_COUNT,
		"2.  Open WORKSPACE and write the algorithm all of them run. You cannot move them by hand.",
		"3.  Press LAUNCH WAVES. One evader spawns on the red ring at a random bearing and drives straight at the planet.",
		"4.  The moment that evader is resolved the next wave launches, up to %d waves in all." % MAX_WAVES,
		"5.  A defender that touches an evader destroys it. The defender survives and takes the next wave.",
		"6.  Every evader that reaches the planet is counted. The run is clean only if none of them do.",
		"7.  The server benchmarks your algorithm over far longer runs than the %d waves you play here, and reports the share of evaders you destroyed." % MAX_WAVES,
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"Nothing is spent here, so a defender that chases hard costs you nothing and pays off every wave.",
		"Each wave picks a fresh bearing, so a layout that leaves one arc uncovered will be found eventually.",
		"WHEN SEES ENEMY with DO FACE and DO FORWARD turns a sighting into a capture. Without it you will watch evaders sail past.",
		"A defender that chased the last wave out to the ring is out of position for the next one. Give it a reason to come home.",
		"The server keeps throwing waves long past the %d you see here, so an algorithm that only survives the opening will score badly." % MAX_WAVES,
		"Speed matters more than in Level 2 - the waves do not wait for a slow defender to get back.",
		"REROLL a few scatters before you settle. The server benchmarks the layout you launched with.",
	]
