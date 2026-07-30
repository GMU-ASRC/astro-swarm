extends Node2D

const LIFETIME := 0.22

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
var beam_color: Color = Color(0.55, 0.85, 1.0, 1.0)

var _age: float = 0.0

func _ready():
	z_index = 7

func _process(delta: float):
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw():
	var fade: float = 1.0 - clampf(_age / LIFETIME, 0.0, 1.0)
	var glow := Color(beam_color.r, beam_color.g, beam_color.b, 0.35 * fade)
	var core := Color(1.0, 1.0, 1.0, fade)
	draw_line(from_point, to_point, glow, 7.0, true)
	draw_line(from_point, to_point, Color(beam_color.r, beam_color.g, beam_color.b, fade), 3.0, true)
	draw_line(from_point, to_point, core, 1.0, true)
