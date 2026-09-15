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
	var spin: float = randf_range(0.0, TAU)
	ground.set_shader_parameter("rotation", spin)
	craters.set_shader_parameter("rotation", spin)
	ground.set_shader_parameter("size", randf_range(6.0, 11.0))
	craters.set_shader_parameter("size", randf_range(4.0, 7.0))
	var hue_shift: float = randf()
	var saturation: float = randf_range(0.7, 1.25)
	var brightness: float = randf_range(0.85, 1.15)
	ground.set_shader_parameter("colors", _shift_colors(ground.get_shader_parameter("colors"), hue_shift, saturation, brightness))
	craters.set_shader_parameter("colors", _shift_colors(craters.get_shader_parameter("colors"), hue_shift, saturation, brightness))

func _animate(t: float):
	$Ground.material.set_shader_parameter("time", t * _multiplier($Ground.material) * 0.02)
	$Craters.material.set_shader_parameter("time", t * _multiplier($Craters.material) * 0.02)
