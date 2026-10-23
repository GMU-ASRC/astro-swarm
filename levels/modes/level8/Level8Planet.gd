extends "res://levels/modes/supply/SupplyBase.gd"

const PLANET_SCENES := [
	"res://levels/modes/level8/Level8PlanetA.tscn",
	"res://levels/modes/level8/Level8PlanetB.tscn",
	"res://levels/modes/level8/Level8PlanetC.tscn",
]

func _level_id() -> String:
	return "farp8"

func _line_options() -> Array:
	return [10, 25, 50]

func _planet_count() -> int:
	return 3

func _planet_scenes() -> Array:
	return PLANET_SCENES

func _gates(planet: int) -> Array:
	match planet:
		0:
			return [{"edge": Edge.RIGHT, "to": 1}, {"edge": Edge.BOTTOM, "to": 2}]
		1:
			return [{"edge": Edge.LEFT, "to": 0}]
	return [{"edge": Edge.TOP, "to": 0}]
