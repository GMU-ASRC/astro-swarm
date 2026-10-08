extends RefCounted

enum Kind { NEUTRAL, PRIMARY, BACK }

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")

const TEXT_LIGHT := Color(0.93, 0.94, 1.0, 1.0)
const TEXT_DARK := Color(0.05, 0.06, 0.12, 1.0)
const TEXT_DISABLED := Color(0.55, 0.56, 0.66, 1.0)

const NEUTRAL_FILL := Color(0.16, 0.149, 0.243, 1.0)
const NEUTRAL_EDGE := Color(0.42, 0.404, 0.62, 1.0)
const PRIMARY_FILL := Color(0.451, 0.616, 1.0, 1.0)
const PRIMARY_EDGE := Color(0.176, 0.298, 0.62, 1.0)
const BACK_FILL := Color(0.110, 0.102, 0.165, 1.0)
const BACK_EDGE := Color(0.620, 0.300, 0.300, 1.0)
const DISABLED_FILL := Color(0.098, 0.094, 0.137, 1.0)
const DISABLED_EDGE := Color(0.200, 0.196, 0.282, 1.0)

const BORDER := 2
const DEPTH := 4
const PAD_X := 12
const PAD_Y := 6
const HOVER_LIGHTEN := 0.12

static func make(text: String, kind: int = Kind.NEUTRAL, font_size: int = 10) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply(button, kind, font_size)
	return button

static func apply(button: Button, kind: int, font_size: int):
	var fill: Color = _fill_color(kind)
	var edge: Color = _edge_color(kind)
	var text_color: Color = TEXT_DARK if kind == Kind.PRIMARY else TEXT_LIGHT
	var padding: int = PAD_Y + int(font_size * 0.2)

	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _box(fill, edge, padding, false))
	button.add_theme_stylebox_override("focus", _box(fill, edge, padding, false))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(HOVER_LIGHTEN), edge.lightened(HOVER_LIGHTEN), padding, false))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.1), edge, padding, true))
	button.add_theme_stylebox_override("hover_pressed", _box(fill.darkened(0.1), edge, padding, true))
	button.add_theme_stylebox_override("disabled", _box(DISABLED_FILL, DISABLED_EDGE, padding, true))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, text_color)
	button.add_theme_color_override("font_disabled_color", TEXT_DISABLED)

static func _fill_color(kind: int) -> Color:
	match kind:
		Kind.PRIMARY: return PRIMARY_FILL
		Kind.BACK: return BACK_FILL
	return NEUTRAL_FILL

static func _edge_color(kind: int) -> Color:
	match kind:
		Kind.PRIMARY: return PRIMARY_EDGE
		Kind.BACK: return BACK_EDGE
	return NEUTRAL_EDGE

static func _box(fill: Color, edge: Color, padding: int, pressed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_corner_radius_all(0)
	box.border_width_left = BORDER
	box.border_width_right = BORDER
	box.border_width_top = DEPTH if pressed else BORDER
	box.border_width_bottom = BORDER if pressed else DEPTH
	box.content_margin_left = PAD_X
	box.content_margin_right = PAD_X
	box.content_margin_top = padding + box.border_width_top
	box.content_margin_bottom = padding + box.border_width_bottom
	return box
