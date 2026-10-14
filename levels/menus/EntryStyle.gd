extends RefCounted

const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")

const C_BG     := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL  := Color(0.129, 0.122, 0.196, 1.0)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT   := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM    := Color(0.6, 0.62, 0.74, 1.0)
const C_FAINT  := Color(0.45, 0.45, 0.51, 1.0)
const C_BLUE   := Color(0.451, 0.616, 1.0, 1.0)
const C_GREEN  := Color(0.45, 0.85, 0.5, 1.0)
const C_RED    := Color(0.9, 0.45, 0.45, 1.0)

static func entry_page_url(entry_id: String) -> String:
	return PlayerSettings.server_url() + "/levels/" + entry_id

static func profile_page_url(player_id: String) -> String:
	return PlayerSettings.server_url() + "/leaderboard/" + player_id

static func make_background() -> ColorRect:
	var background := ColorRect.new()
	background.color = C_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	return background

static func make_page_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	return margin

static func make_card(padding: int = 16) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding - 2
	style.content_margin_bottom = padding - 2
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func make_badge(text: String, color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.12)
	style.border_color = Color(color.r, color.g, color.b, 0.45)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(make_label(text, 10, color))
	return badge

static func make_stat(value_text: String, caption_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	var value_label := make_label(value_text, 20, C_TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(value_label)
	var caption_label := make_label(caption_text, 10, C_FAINT)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(caption_label)
	return column

static func make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_REG)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT_REG)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	return button

static func make_website_button(text: String, url: String) -> Button:
	var button := make_button(text)
	button.add_theme_color_override("font_color", C_BLUE)
	button.pressed.connect(func(): OS.shell_open(url))
	return button

static func status_color(status: String) -> Color:
	if status == "done":
		return C_GREEN
	if status == "failed" or status == "error":
		return C_RED
	return C_BLUE

static func short_date(iso: String) -> String:
	if iso.length() >= 10:
		return iso.substr(0, 10)
	return iso
