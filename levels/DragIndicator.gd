extends Node2D

var _active: bool = false
var _start: Vector2
var _end: Vector2
var _color: Color = Color.WHITE

func update_drag(active: bool, start: Vector2 = Vector2.ZERO, end: Vector2 = Vector2.ZERO, color: Color = Color.WHITE):
	_active = active
	_start = start
	_end = end
	_color = color
	queue_redraw()

func _draw():
	if not _active:
		return

	var length = _start.distance_to(_end)
	if length < 2.0:
		return

	var angle = _start.angle_to_point(_end)

	draw_line(_start, _end, _color, 2.0, true)

	var head_length = min(15.0, length * 0.5)
	var head_width = head_length * 0.6

	var p1 = _end
	var p2 = _end - Vector2(head_length, head_width).rotated(angle)
	var p3 = _end - Vector2(head_length, -head_width).rotated(angle)

	var pts = PackedVector2Array([p1, p2, p3])
	draw_polygon(pts, PackedColorArray([_color, _color, _color]))
