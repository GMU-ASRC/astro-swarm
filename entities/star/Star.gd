extends "res://entities/planet/Planet.gd"

const REL := 1.6

func _build(sd: int, pixels: float):
	var body: ShaderMaterial = $Body.material
	var blobs: ShaderMaterial = $Blobs.material
	var flares: ShaderMaterial = $Flares.material
	var big: float = pixels * REL
	body.set_shader_parameter("pixels", pixels)
	blobs.set_shader_parameter("pixels", big)
	flares.set_shader_parameter("pixels", big)
	$Body.size = Vector2(pixels, pixels)
	$Body.position = Vector2.ZERO
	$Blobs.size = Vector2(big, big)
	$Flares.size = Vector2(big, big)
	var off: float = -(big - pixels) * 0.5
	$Blobs.position = Vector2(off, off)
	$Flares.position = Vector2(off, off)
	var s: float = _seed_to_shader(sd)
	body.set_shader_parameter("seed", s)
	blobs.set_shader_parameter("seed", s)
	flares.set_shader_parameter("seed", s)

func _animate(t: float):
	$Body.material.set_shader_parameter("time", t * _multiplier($Body.material) * 0.005)
	$Blobs.material.set_shader_parameter("time", t * _multiplier($Blobs.material) * 0.01)
	$Flares.material.set_shader_parameter("time", t * _multiplier($Flares.material) * 0.015)
