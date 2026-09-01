extends "res://levels/modes/WaveBase.gd"

func _has_attrition() -> bool:
	return true

func _level_id() -> String:
	return "farp4"

func _level_title() -> String:
	return "LEVEL 4 - TRADE FOR THE PLANET"

func _level_subtitle() -> String:
	return "The same wave after wave, with one change: a capture destroys the defender that made it. You have %d bodies to spend, and the run ends when they are gone. REROLL for a new scatter." % RING_COUNT

func _walkthrough_lines() -> Array:
	return [
		"GOAL: stop as many evaders as you can before your line is spent.",
		"1.  %d defenders are dropped at random inside the blue placement ring, exactly as in Level 3." % RING_COUNT,
		"2.  Open WORKSPACE and write the algorithm all of them run.",
		"3.  Press LAUNCH WAVES. One evader spawns on the red ring at a random bearing and drives straight at the planet.",
		"4.  A capture destroys BOTH ships. Every evader you stop costs you a defender.",
		"5.  The next wave launches as soon as the last one is resolved, so the line has to cover more sky each time it thins.",
		"6.  The run ends when the last defender is gone or the clock runs out, whichever comes first.",
		"7.  The server benchmarks your algorithm over many runs and reports the share of evaders destroyed and the defenders lost.",
		"Scroll to zoom, middle-drag to pan.",
	]

func _hint_lines() -> Array:
	return [
		"With %d defenders you get at most %d captures, so every body you spend badly is a wave you will not be there for." % [RING_COUNT, RING_COUNT],
		"Every capture thins your line, so the defenders that are left have to cover more sky than they did a moment ago.",
		"An algorithm that sends every defender at the same evader wastes the trade. WHEN SEES ALLY with a turn keeps them apart.",
		"A defender that ignores a distant evader and holds its arc may be worth more than one that trades itself early.",
		"Spreading the scatter matters more than in Level 3, because a dead defender leaves a hole nothing fills.",
		"REROLL a few scatters before you settle. The server benchmarks the layout you launched with.",
	]
