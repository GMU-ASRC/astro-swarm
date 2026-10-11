extends Node2D

const FRAME_SECONDS := 0.07
const PIXELS_PER_HULL := 4.5
const NOZZLE_HULL_RADII := 1.3
const BASE_LENGTH := 2
const LENGTH_PER_THRUST := 4.0
const FLICKER_STEPS := [0, 1, 0, 2, 1]
const LAYERS := [
	{"color": Color(1.0, 0.42, 0.24, 1.0), "height": 5, "length_cut": 0},
	{"color": Color(1.0, 0.78, 0.2, 1.0), "height": 3, "length_cut": 1},
	{"color": Color(1.0, 0.97, 0.82, 1.0), "height": 1, "length_cut": 3},
]

var _age: float = 0.0
var _frame: int = 0
var _thrust: float = 0.0

func _process(delta: float):
	_age += delta
	var frame: int = int(_age / FRAME_SECONDS) % FLICKER_STEPS.size()
	var thrust: float = get_parent().thruster_level()
	if frame == _frame and is_equal_approx(thrust, _thrust):
		return
	_frame = frame
	_thrust = thrust
	queue_redraw()

func _draw():
	if _thrust <= 0.0:
		return
	var hull_radius: float = get_parent().hull_radius
	var pixel: float = hull_radius / PIXELS_PER_HULL
	var length: int = BASE_LENGTH + roundi(_thrust * LENGTH_PER_THRUST) + FLICKER_STEPS[_frame]
	for layer in LAYERS:
		_draw_layer(layer, length - int(layer["length_cut"]), -hull_radius * NOZZLE_HULL_RADII, pixel)

func _draw_layer(layer: Dictionary, columns: int, nozzle_x: float, pixel: float):
	for column in columns:
		var columns_to_tip: int = columns - column
		var height: int = mini(int(layer["height"]), columns_to_tip * 2 - 1)
		var left: float = nozzle_x - float(column + 1) * pixel
		draw_rect(Rect2(left, -height * pixel * 0.5, pixel, height * pixel), layer["color"], true)
