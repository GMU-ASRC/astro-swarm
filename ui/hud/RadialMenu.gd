extends CanvasLayer

signal action_selected(action_id: String)
signal menu_closed

@onready var center = $Center

var _actions: Array = []
var _title: String = ""
var inner_radius: float = 56.0
var outer_radius: float = 118.0
var hover_index: int = -1

const PANEL_BG     := Color(0.965, 0.965, 0.973, 1.0)
const PANEL_BORDER := Color(0.722, 0.722, 0.745, 1.0)
const SHADOW       := Color(0, 0, 0, 0.18)
const SLICE_BG     := Color(0.945, 0.945, 0.957, 1.0)
const SEP_COLOR    := Color(0.78, 0.78, 0.80, 1.0)
const TEXT_DARK    := Color(0.137, 0.137, 0.196, 1.0)
const TEXT_MUTED   := Color(0.45, 0.45, 0.51, 1.0)
const TEXT_LIGHT   := Color(1, 1, 1, 1)

func _ready():
	center.draw.connect(_on_center_draw)

func open(pos: Vector2, actions_list: Array, title: String = ""):
	_actions = actions_list
	_title = title
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var clamped := pos
	var margin := outer_radius + 8.0
	clamped.x = clampf(clamped.x, margin, screen_size.x - margin)
	clamped.y = clampf(clamped.y, margin, screen_size.y - margin)
	center.position = clamped
	hover_index = -1
	visible = true
	center.queue_redraw()

func _input(event: InputEvent):
	if not visible:
		return
	if event is InputEventMouseMotion:
		var local_pos = center.get_local_mouse_position()
		var dist = local_pos.length()
		var new_hover = -1
		if dist >= inner_radius and dist <= outer_radius and _actions.size() > 0:
			var angle = local_pos.angle() + PI / 2.0
			if angle < 0: angle += TAU
			new_hover = int((angle / TAU) * _actions.size())
		if hover_index != new_hover:
			hover_index = new_hover
			center.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		if hover_index >= 0 and hover_index < _actions.size():
			action_selected.emit(_actions[hover_index].id)
		else:
			menu_closed.emit()
		visible = false
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		menu_closed.emit()
		visible = false

func _on_center_draw():
	if _actions.is_empty():
		_draw_hub()
		return

	var step = TAU / _actions.size()
	var font = ThemeDB.fallback_font
	var font_size = 12
	var segment_points = max(20, int(96 / _actions.size()))

	_draw_ring_shadow()

	for i in range(_actions.size()):
		var start_angle = -PI / 2.0 + i * step
		var end_angle = start_angle + step
		var action = _actions[i]
		var accent: Color = action.get("color", Color(0.5, 0.5, 0.5, 1.0))
		var is_hover := i == hover_index

		var poly = PackedVector2Array()
		for j in range(segment_points + 1):
			var t = start_angle + (end_angle - start_angle) * (j / float(segment_points))
			poly.append(Vector2(cos(t), sin(t)) * outer_radius)
		for j in range(segment_points + 1):
			var t = end_angle - (end_angle - start_angle) * (j / float(segment_points))
			poly.append(Vector2(cos(t), sin(t)) * inner_radius)

		var fill: Color = accent if is_hover else SLICE_BG
		center.draw_colored_polygon(poly, fill)

	for i in range(_actions.size()):
		var sep_angle = -PI / 2.0 + i * step
		var p1 = Vector2(cos(sep_angle), sin(sep_angle)) * (inner_radius + 1.0)
		var p2 = Vector2(cos(sep_angle), sin(sep_angle)) * (outer_radius - 1.0)
		center.draw_line(p1, p2, SEP_COLOR, 1.0, true)

	_draw_circle_outline(outer_radius, PANEL_BORDER, 1.5, segment_points * _actions.size())
	_draw_circle_outline(inner_radius, PANEL_BORDER, 1.5, segment_points * _actions.size())

	for i in range(_actions.size()):
		var start_angle = -PI / 2.0 + i * step
		var end_angle = start_angle + step
		var action = _actions[i]
		var accent: Color = action.get("color", Color(0.5, 0.5, 0.5, 1.0))
		var is_hover := i == hover_index
		var mid_angle = start_angle + step / 2.0
		var mid_radius = (inner_radius + outer_radius) / 2.0
		var center_pos = Vector2(cos(mid_angle), sin(mid_angle)) * mid_radius

		var label: String = action.get("label", "")
		var text_color: Color = TEXT_LIGHT if is_hover else TEXT_DARK
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

		var dot_radius := 3.0
		var dot_pos := center_pos + Vector2(0, -text_size.y * 0.5 - 6.0)
		center.draw_circle(dot_pos, dot_radius, TEXT_LIGHT if is_hover else accent)

		var text_pos = center_pos + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
		center.draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)

	_draw_hub()

func _draw_hub():
	center.draw_circle(Vector2(2, 3), inner_radius - 2.0, SHADOW)
	center.draw_circle(Vector2.ZERO, inner_radius - 4.0, PANEL_BG)
	_draw_circle_outline(inner_radius - 4.0, PANEL_BORDER, 1.0, 64)

	if _title == "":
		return
	var font = ThemeDB.fallback_font
	var lines: PackedStringArray = _title.split("\n")
	var name_size := 14
	var sub_size := 11
	var name_h: float = font.get_height(name_size)
	var sub_h: float = font.get_height(sub_size)
	var total_h: float = name_h + (lines.size() - 1) * sub_h
	var y: float = -total_h * 0.5 + name_h * 0.75

	for i in lines.size():
		var line: String = lines[i]
		var fs: int = name_size if i == 0 else sub_size
		var color: Color = TEXT_DARK if i == 0 else TEXT_MUTED
		var line_size = font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var pos = Vector2(-line_size.x * 0.5, y)
		center.draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, color)
		y += (name_h if i == 0 else sub_h)

func _draw_ring_shadow():
	var pts := 96
	var ring := PackedVector2Array()
	var offset := Vector2(2, 4)
	for j in range(pts + 1):
		var t = j / float(pts) * TAU
		ring.append(Vector2(cos(t), sin(t)) * (outer_radius + 2.0) + offset)
	for j in range(pts + 1):
		var t = (1.0 - j / float(pts)) * TAU
		ring.append(Vector2(cos(t), sin(t)) * inner_radius + offset)
	center.draw_colored_polygon(ring, SHADOW)

func _draw_circle_outline(r: float, color: Color, width: float, segments: int):
	var pts := PackedVector2Array()
	for j in range(segments + 1):
		var t = j / float(segments) * TAU
		pts.append(Vector2(cos(t), sin(t)) * r)
	center.draw_polyline(pts, color, width, true)
