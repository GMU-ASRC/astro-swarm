extends "res://entities/planet/Planet.gd"

func _build(sd: int, pixels: float):
	var ground: ShaderMaterial = $Ground.material
	var craters: ShaderMaterial = $Craters.material
	ground.set_shader_parameter("pixels", pixels)
	craters.set_shader_parameter("pixels", pixels)
	$Ground.size = Vector2(pixels, pixels)
	$Craters.size = Vector2(pixels, pixels)
	var s: float = _seed_to_shader(sd)
	ground.set_shader_parameter("seed", s)
	craters.set_shader_parameter("seed", s)

func _animate(t: float):
	$Ground.material.set_shader_parameter("time", t * _multiplier($Ground.material) * 0.02)
	$Craters.material.set_shader_parameter("time", t * _multiplier($Craters.material) * 0.02)
