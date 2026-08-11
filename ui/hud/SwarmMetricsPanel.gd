extends PanelContainer

const ROW_STATUS        := "status"
const ROW_CURRENT_LOSS  := "current_loss"
const ROW_MINIMUM_LOSS  := "minimum_loss"
const ROW_GOAL_DISTANCE := "goal_distance"
const ROW_CIRCLINESS    := "circliness"

var label_font: Font = null
var text_color      := Color(0.93, 0.94, 1.0, 1.0)
var dim_color       := Color(0.6, 0.62, 0.74, 1.0)
var border_color    := Color(0.318, 0.306, 0.463, 1.0)
var background_color := Color(0.129, 0.122, 0.196, 0.88)

var _rows: Dictionary = {}
var _legend_box: VBoxContainer

func build():
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(250, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)

	_rows[ROW_STATUS] = _add_row(box, text_color)
	_rows[ROW_CURRENT_LOSS] = _add_row(box, dim_color)
	_rows[ROW_MINIMUM_LOSS] = _add_row(box, dim_color)
	_rows[ROW_GOAL_DISTANCE] = _add_row(box, dim_color)
	_rows[ROW_CIRCLINESS] = _add_row(box, dim_color)

	var separator := ColorRect.new()
	separator.color = border_color
	separator.custom_minimum_size = Vector2(0, 1)
	box.add_child(separator)

	box.add_child(_make_label("LEGEND", dim_color))

	_legend_box = VBoxContainer.new()
	_legend_box.add_theme_constant_override("separation", 4)
	box.add_child(_legend_box)

	set_metrics("SEPARATE", -1.0, -1.0, -1.0, -1.0)

func set_metrics(status: String, current_loss: float, minimum_loss: float, goal_distance: float, circliness: float):
	_rows[ROW_STATUS].text = "STATUS: " + status
	_rows[ROW_CURRENT_LOSS].text = "CURRENT LOSS: " + _number(current_loss)
	_rows[ROW_MINIMUM_LOSS].text = "MINIMUM LOSS: " + _number(minimum_loss)
	_rows[ROW_GOAL_DISTANCE].text = "GOAL DISTANCE: " + _number(goal_distance)
	_rows[ROW_CIRCLINESS].text = "CIRCLINESS: " + _number(circliness)

func set_legend(entries: Array):
	for child in _legend_box.get_children():
		child.queue_free()
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var swatch := ColorRect.new()
		swatch.color = entry["color"]
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		row.add_child(_make_label(entry["label"], dim_color))
		_legend_box.add_child(row)

func _add_row(box: VBoxContainer, color: Color) -> Label:
	var label := _make_label("", color)
	box.add_child(label)
	return label

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	if label_font != null:
		label.add_theme_font_override("font", label_font)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	return label

func _number(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.3f" % value
