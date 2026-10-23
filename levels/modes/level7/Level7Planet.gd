extends "res://levels/modes/supply/SupplyBase.gd"

const PLANET_SCENES := [
	"res://levels/modes/level7/Level7PlanetA.tscn",
	"res://levels/modes/level7/Level7PlanetB.tscn",
]

func _level_id() -> String:
	return "farp7"

func _planet_count() -> int:
	return 2

func _planet_scenes() -> Array:
	return PLANET_SCENES

func _gates(planet: int) -> Array:
	if planet == 0:
		return [{"edge": Edge.RIGHT, "to": 1}]
	return [{"edge": Edge.LEFT, "to": 0}]
