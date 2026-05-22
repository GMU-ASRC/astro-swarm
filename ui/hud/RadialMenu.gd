extends CanvasLayer

signal action_selected(action_id: String)
signal menu_closed

@onready var center = $Center

var _actions: Array = []
var _title: String = ""
var inner_radius: float = 35.0
var outer_radius: float = 90.0
var hover_index: int = -1

func _ready():
	center.draw.connect(_on_center_draw)

func open(pos: Vector2, actions_list: Array, title: String = ""):
	_actions = actions_list
	_title = title
	center.position = pos
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
		if dist >= inner_radius and dist <= outer_radius:
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

func _on_center_draw():
	if _actions.is_empty():
		return

	var step = TAU / _actions.size()
	var font = ThemeDB.fallback_font
	var font_size = 14

	for i in range(_actions.size()):
		var start_angle = -PI / 2.0 + i * step
		var end_angle = start_angle + step
		var action = _actions[i]

		var color: Color = action.get("color", Color(0.3, 0.3, 0.3))
		if i == hover_index:
			color = color.lightened(0.15)
		var edge_color = color.darkened(0.3)

		var poly = PackedVector2Array()
		var segment_points = max(12, int(64 / _actions.size()))

		for j in range(segment_points + 1):
			var t = start_angle + (end_angle - start_angle) * (j / float(segment_points))
			poly.append(Vector2(cos(t), sin(t)) * outer_radius)

		for j in range(segment_points + 1):
			var t = end_angle - (end_angle - start_angle) * (j / float(segment_points))
			poly.append(Vector2(cos(t), sin(t)) * inner_radius)

		center.draw_colored_polygon(poly, color)

		var line_poly = poly.duplicate()
		line_poly.append(poly[0])
		center.draw_polyline(line_poly, edge_color, 2.0, true)

		var mid_angle = start_angle + step / 2.0
		var mid_radius = (inner_radius + outer_radius) / 2.0
		var text_pos = Vector2(cos(mid_angle), sin(mid_angle)) * mid_radius

		var label: String = action.get("label", "")
		var string_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		text_pos.y += string_size.y * 0.35
		text_pos.x -= string_size.x / 2.0

		center.draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	if _title != "":
		var lines: PackedStringArray = _title.split("\n")
		var line_h: float = font.get_height(font_size)
		var total_h: float = line_h * lines.size()
		var y_start: float = -total_h * 0.5 + line_h * 0.75
		for i in lines.size():
			var line: String = lines[i]
			var line_size = font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var line_pos = Vector2(-line_size.x / 2.0, y_start + i * line_h)
			center.draw_string(font, line_pos, line, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.9, 0.9, 0.9, 1.0))
