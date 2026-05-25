extends Control

var _t: float = 0.0

func _process(delta: float):
	_t += delta
	_animate(_t)

func generate(sd: int, pixels: float = 100.0):
	seed(sd)
	_build(sd, pixels)

func _build(_sd: int, _pixels: float):
	pass

func _animate(_time: float):
	pass

func _seed_to_shader(sd: int) -> float:
	return float(sd % 1000) / 100.0

func _multiplier(mat: ShaderMaterial) -> float:
	return (round(mat.get_shader_parameter("size")) * 2.0) / mat.get_shader_parameter("time_speed")

func _palette(n: int, hue_diff: float, saturation: float) -> Array:
	var a := Vector3(0.5, 0.5, 0.5)
	var b := Vector3(0.5, 0.5, 0.5) * saturation
	var c := Vector3(randf_range(0.5, 1.5), randf_range(0.5, 1.5), randf_range(0.5, 1.5)) * hue_diff
	var d := Vector3(randf_range(0.0, 1.0), randf_range(0.0, 1.0), randf_range(0.0, 1.0)) * randf_range(1.0, 3.0)
	var cols: Array = []
	var nf: float = max(1.0, float(n - 1))
	for i in n:
		var t: float = float(i) / nf
		cols.append(Color(
			a.x + b.x * cos(6.28318 * (c.x * t + d.x)),
			a.y + b.y * cos(6.28318 * (c.y * t + d.y)),
			a.z + b.z * cos(6.28318 * (c.z * t + d.z))
		))
	return cols
