extends "res://levels/modes/WaveBase.gd"

const LEVEL_FOUR_DEFENDER_OPTIONS := [5, 10, 15, 20]

func _has_attrition() -> bool:
	return true

func _level_id() -> String:
	return "farp4"

func _level_title() -> String:
	return "LEVEL 4 - TRADE FOR THE PLANET"

func _defender_options() -> Array:
	return LEVEL_FOUR_DEFENDER_OPTIONS
