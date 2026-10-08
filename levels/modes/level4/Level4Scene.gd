extends "res://levels/modes/WaveBase.gd"

func _has_attrition() -> bool:
	return true

func _level_id() -> String:
	return "farp4"

func _level_title() -> String:
	return "LEVEL 4 - TRADE FOR THE PLANET"

func _level_subtitle() -> String:
	return "The same %d waves, with one change: a capture destroys the defender that made it. You have %d bodies to spend, and the run ends early if they are gone. REROLL for a new scatter." % [MAX_WAVES, RING_COUNT]
