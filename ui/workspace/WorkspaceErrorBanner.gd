extends PanelContainer

const BACKGROUND_COLOR := Color(0.60, 0.12, 0.11, 1.0)
const BORDER_COLOR := Color(1.0, 0.36, 0.30, 1.0)
const TEXT_COLOR := Color(1, 1, 1, 1)

var _message_label: Label

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _panel_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var badge := Label.new()
	badge.text = " ! "
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", BACKGROUND_COLOR)
	badge.add_theme_stylebox_override("normal", _badge_style())
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 13)
	_message_label.add_theme_color_override("font_color", TEXT_COLOR)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_message_label)
	visible = false

func show_messages(messages: Array):
	visible = not messages.is_empty()
	if _message_label == null or messages.is_empty():
		return
	var lines: PackedStringArray = []
	for message in messages:
		lines.append(str(message))
	lines.append("Problem blocks are outlined in red.")
	_message_label.text = "\n".join(lines)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = TEXT_COLOR
	style.set_corner_radius_all(10)
	style.content_margin_left = 4
	style.content_margin_right = 4
	return style
