extends Node2D

var _active: bool = false
var _mode: String = "arrow"
var _start: Vector2
var _end: Vector2
var _color: Color = Color.WHITE

func update_drag(active: bool, mode: String = "arrow", start: Vector2 = Vector2.ZERO, end: Vector2 = Vector2.ZERO, color: Color = Color.WHITE):
	_active = active
	_mode = mode
	_start = start
	_end = end
	_color = color
	queue_redraw()

func _draw():
	if not _active:
		return
	match _mode:
		"arrow": _draw_arrow()
		"rect": _draw_rect()
		"circle": _draw_circle()
		"measure": _draw_measure()

func _draw_arrow():
	var length: float = _start.distance_to(_end)
	if length < 2.0:
		return
	var angle: float = _start.angle_to_point(_end)
	draw_line(_start, _end, _color, 2.0, true)
	var head_length: float = min(15.0, length * 0.5)
	var head_width: float = head_length * 0.6
	var p1: Vector2 = _end
	var p2: Vector2 = _end - Vector2(head_length, head_width).rotated(angle)
	var p3: Vector2 = _end - Vector2(head_length, -head_width).rotated(angle)
	var pts: PackedVector2Array = PackedVector2Array([p1, p2, p3])
	draw_polygon(pts, PackedColorArray([_color, _color, _color]))

func _draw_rect():
	var r: Rect2 = Rect2(_start, _end - _start).abs()
	if r.size.x < 1.0 and r.size.y < 1.0:
		return
	var fill: Color = Color(_color.r, _color.g, _color.b, 0.25)
	draw_rect(r, fill, true)
	draw_rect(r, _color, false, 2.0)

func _draw_circle():
	var radius: float = _start.distance_to(_end)
	if radius < 1.0:
		return
	var fill: Color = Color(_color.r, _color.g, _color.b, 0.25)
	draw_circle(_start, radius, fill)
	draw_arc(_start, radius, 0.0, TAU, 64, _color, 2.0, true)

func _draw_measure():
	var length_px: float = _start.distance_to(_end)
	draw_line(_start, _end, _color, 2.0, true)
	_draw_tick(_start, _end)
	_draw_tick(_end, _start)
	var meters: float = length_px / SimulationManager.PX_PER_METER
	var txt: String = "%.2f m" % meters
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 12
	var size: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var mid: Vector2 = (_start + _end) * 0.5
	var pad: float = 4.0
	var bg_rect: Rect2 = Rect2(mid - Vector2(size.x * 0.5 + pad, size.y * 0.5 + pad), size + Vector2(pad * 2.0, pad * 2.0))
	draw_rect(bg_rect, Color(0.965, 0.965, 0.973, 1.0), true)
	draw_rect(bg_rect, _color, false, 1.0)
	draw_string(font, mid + Vector2(-size.x * 0.5, size.y * 0.3), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.137, 0.137, 0.196, 1.0))

func _draw_tick(at: Vector2, away_from: Vector2):
	var dir: Vector2 = (away_from - at).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_line(at - perp * 6.0, at + perp * 6.0, _color, 2.0, true)
