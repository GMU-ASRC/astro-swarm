extends VBoxContainer

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const RANKS := preload("res://progression/Ranks.gd")

const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_ACCENT := Color(0.451, 0.616, 1.0, 1.0)
const C_TRACK := Color(0.07, 0.065, 0.11, 1.0)
const C_TRACK_EDGE := Color(0.318, 0.306, 0.463, 1.0)
const BAR_HEIGHT := 14

func _ready():
	add_theme_constant_override("separation", 4)
	var current_level: int = PlayerData.level
	var xp_needed: int = PlayerData.xp_needed()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(_label(RANKS.rank_name(current_level), 12, C_TEXT))

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.max_value = xp_needed
	bar.value = PlayerData.xp
	bar.add_theme_stylebox_override("background", _box(C_TRACK, C_TRACK_EDGE, 2))
	bar.add_theme_stylebox_override("fill", _box(C_ACCENT, C_ACCENT, 0))
	row.add_child(bar)

	row.add_child(_label(RANKS.next_rank_name(current_level), 12, C_DIM))

	var detail := _label("%d / %d XP TO %s" % [PlayerData.xp, xp_needed, RANKS.next_rank_name(current_level)], 9, C_DIM)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(detail)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _box(fill: Color, edge: Color, border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(0)
	return box
