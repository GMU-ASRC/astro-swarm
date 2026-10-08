extends RefCounted

const SIZE := Vector2(20, 20)
const CROSS_INSET := 6.0
const CROSS_WIDTH := 2.0
const CROSS_COLOR := Color(1, 1, 1, 0.9)
const HOVER_COLOR := Color(0.85, 0.25, 0.22, 1.0)
const PRESSED_COLOR := Color(0.65, 0.17, 0.15, 1.0)

static func setup(button: Button):
	button.text = ""
	button.tooltip_text = "Delete block"
	button.custom_minimum_size = SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.draw.connect(func(): _draw_cross(button))

static func style(button: Button, block_dark_color: Color):
	var resting := Color(block_dark_color.darkened(0.25), 0.85)
	button.add_theme_stylebox_override("normal", _box(resting))
	button.add_theme_stylebox_override("focus", _box(resting))
	button.add_theme_stylebox_override("hover", _box(HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _box(PRESSED_COLOR))
	button.add_theme_stylebox_override("hover_pressed", _box(PRESSED_COLOR))

static func _box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = fill.darkened(0.3)
	box.set_border_width_all(1)
	box.set_corner_radius_all(0)
	return box

static func _draw_cross(button: Button):
	var top_left := Vector2(CROSS_INSET, CROSS_INSET)
	var bottom_right: Vector2 = button.size - Vector2(CROSS_INSET, CROSS_INSET)
	button.draw_line(top_left, bottom_right, CROSS_COLOR, CROSS_WIDTH)
	button.draw_line(Vector2(bottom_right.x, top_left.y), Vector2(top_left.x, bottom_right.y), CROSS_COLOR, CROSS_WIDTH)
