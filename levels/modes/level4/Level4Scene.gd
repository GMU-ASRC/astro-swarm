extends "res://levels/modes/WaveBase.gd"

func _capture_destroys_defender() -> bool:
	return true

func _level_id() -> String:
	return "farp4"

func _level_title() -> String:
	return "LEVEL 4 - TRADE FOR THE PLANET"

func _level_subtitle() -> String:
	return "%d evaders come in %s from the red ring. A capture destroys the evader and the defender that caught it, so you have %d bodies to spend. Press W to switch the wave style, REROLL for a new scatter." % [EVADER_COUNT, _wave_word(), RING_COUNT]

func _walkthrough_lines() -> Array:
	return [
		"GOAL: destroy every evader in the wave before any of them touches the planet.",
		"1.  %d defenders are dropped at random inside the blue placement ring, exactly as in Level 3." % RING_COUNT,
		"2.  Open WORKSPACE and write the algorithm all of them run.",
		"3.  WAVE picks how the evaders arrive. SEQUENTIAL sends the next one only after the last is gone, SIMULTANEOUS sends all %d at once." % EVADER_COUNT,
		"4.  Press LAUNCH WAVE. Every evader spawns on the red ring and drives straight at the planet.",
		"5.  A capture destroys BOTH ships. Every evader you stop costs you a defender.",
		"6.  The wave always plays out in full. One evader reaching the planet loses the run, and so does running out of defenders.",
		"7.  The run is a win only if all %d evaders are destroyed." % EVADER_COUNT,
		"8.  The server benchmarks your algorithm over many waves.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"You have %d defenders and %d evaders, so you can afford to lose a body per kill and no more." % [RING_COUNT, EVADER_COUNT],
		"Every capture thins your line, so the defenders that are left have to cover more sky than they did a moment ago.",
		"An algorithm that sends every defender at the same evader wastes the trade. WHEN SEES ALLY with a turn keeps them apart.",
		"SIMULTANEOUS is far harder here - three captures at once can strip most of your line in a second.",
		"Spreading the scatter matters more than in Level 3, because a dead defender leaves a hole that nothing fills.",
		"REROLL a few scatters before you settle. The server benchmarks the layout you launched with.",
	]
