extends "res://entities/planet/Planet.gd"

const HUE_RANGE := 0.08 # fraction of the color wheel a world's palette may drift

func _build(sd: int, pixels: float):
	var land: ShaderMaterial = $Land.material
	var cloud: ShaderMaterial = $Cloud.material
	land.set_shader_parameter("pixels", pixels)
	cloud.set_shader_parameter("pixels", pixels)
	$Land.size = Vector2(pixels, pixels)
	$Cloud.size = Vector2(pixels, pixels)
	var s: float = _seed_to_shader(sd)
	land.set_shader_parameter("seed", s)
	cloud.set_shader_parameter("seed", s)
	cloud.set_shader_parameter("cloud_cover", randf_range(0.35, 0.6))
	land.set_shader_parameter("size", randf_range(3.6, 5.8))
	land.set_shader_parameter("river_cutoff", randf_range(0.3, 0.45))
	var hue_shift: float = randf_range(-HUE_RANGE, HUE_RANGE)
	land.set_shader_parameter("colors", _shift_colors(
		land.get_shader_parameter("colors"), hue_shift, randf_range(0.8, 1.2), randf_range(0.9, 1.1)))

func _animate(t: float):
	var land: ShaderMaterial = $Land.material
	var cloud: ShaderMaterial = $Cloud.material
	land.set_shader_parameter("time", t * _multiplier(land) * 0.02)
	cloud.set_shader_parameter("time", t * _multiplier(cloud) * 0.01)
