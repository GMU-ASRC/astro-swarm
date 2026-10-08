extends "res://levels/modes/WaveBase.gd"

func _level_id() -> String:
	return "farp3"

func _level_title() -> String:
	return "LEVEL 3 - HOLD THE WAVES"

func _level_subtitle() -> String:
	return "%d waves come in, one evader at a time, each from a fresh random bearing on the red ring. A defender that catches one destroys it and keeps hunting. Hold every wave. REROLL for a new scatter." % MAX_WAVES

