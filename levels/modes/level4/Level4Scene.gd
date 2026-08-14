extends "res://levels/modes/WaveBase.gd"

func _capture_destroys_defender() -> bool:
	return true

func _level_id() -> String:
	return "farp4"

func _level_title() -> String:
	return "LEVEL 4 - TRADE FOR THE PLANET"

func _level_subtitle() -> String:
	return "Two waves of %d evaders come in off the red ring: the first one after another, the second all at once. A capture destroys the evader and the defender that caught it, so you have %d bodies to spend each wave. REROLL for a new scatter." % [EVADER_COUNT, RING_COUNT]

func _walkthrough_lines() -> Array:
	return [
		"GOAL: destroy every evader in the wave before any of them touches the planet.",
		"1.  %d defenders are dropped at random inside the blue placement ring, exactly as in Level 3." % RING_COUNT,
		"2.  Open WORKSPACE and write the algorithm all of them run.",
		"3.  A run is two waves. The first sends the evaders one after another, then the arena resets, your line is restored and the second sends all %d at once." % EVADER_COUNT,
		"4.  Press LAUNCH WAVES. Every evader spawns on the red ring and drives straight at the planet.",
		"5.  A capture destroys BOTH ships. Every evader you stop costs you a defender.",
		"6.  The wave always plays out in full. One evader reaching the planet loses the run, and so does running out of defenders.",
		"7.  The run is a win only if both waves are stopped, so all %d evaders." % (EVADER_COUNT * 2),
		"8.  The server benchmarks your algorithm over many waves.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"You have %d defenders and %d evaders, so you can afford to lose a body per kill and no more." % [RING_COUNT, EVADER_COUNT],
		"Every capture thins your line, so the defenders that are left have to cover more sky than they did a moment ago.",
		"An algorithm that sends every defender at the same evader wastes the trade. WHEN SEES ALLY with a turn keeps them apart.",
		"The second wave is far harder here - three captures at once can strip most of your line in a second.",
		"Spreading the scatter matters more than in Level 3, because a dead defender leaves a hole that nothing fills until the next wave restores your line.",
		"REROLL a few scatters before you settle. The server benchmarks the layout you launched with.",
	]
