extends "res://entities/planet/Planet.gd"

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

func _animate(t: float):
	var land: ShaderMaterial = $Land.material
	var cloud: ShaderMaterial = $Cloud.material
	land.set_shader_parameter("time", t * _multiplier(land) * 0.02)
	cloud.set_shader_parameter("time", t * _multiplier(cloud) * 0.01)
