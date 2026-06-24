extends Control

const FONT_REG  := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

const C_BG      := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL   := Color(0.129, 0.122, 0.196, 1.0)
const C_BORDER  := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT    := Color(0.93,  0.94,  1.0,   1.0)
const C_DIM     := Color(0.6,   0.62,  0.74,  1.0)
const C_BLUE    := Color(0.451, 0.616, 1.0,   1.0)
const C_LOCKED  := Color(0.35,  0.35,  0.45,  1.0)

const TILE_SIZE := Vector2(120, 64)
const GRID_COLUMNS := 3

const LEVELS := [
	{"scene": "res://levels/modes/FARPScene.tscn",       "locked": false},
	{"scene": "res://levels/modes/DominationScene.tscn", "locked": false},
	{"scene": "",                                  "locked": true},
	{"scene": "",                                  "locked": true},
	{"scene": "",                                  "locked": true},
	{"scene": "",                                  "locked": true},
]

func _ready():
	theme = GAME_THEME
	_build_ui()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := CenterContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 32)
	outer.add_child(vbox)

	var title := _lbl("LEVELS", 32, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	vbox.add_child(grid)

	for i in LEVELS.size():
		grid.add_child(_make_tile(i + 1, LEVELS[i]))

	var back_wrap := CenterContainer.new()
	vbox.add_child(back_wrap)
	var back := _make_btn("← BACK TO BASE")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn"))
	back_wrap.add_child(back)

func _make_tile(number: int, level: Dictionary) -> Control:
	var locked: bool = level["locked"]

	var tile := Button.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.focus_mode = Control.FOCUS_NONE
	tile.disabled = locked
	tile.text = "LEVEL %d" % number
	tile.add_theme_font_override("font", FONT_REG)
	tile.add_theme_font_size_override("font_size", 16)

	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL if not locked else Color(0.08, 0.075, 0.13, 1.0)
	style.border_color = C_BLUE if not locked else C_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	tile.add_theme_stylebox_override("normal", style)
	tile.add_theme_stylebox_override("hover", style)
	tile.add_theme_stylebox_override("pressed", style)
	tile.add_theme_stylebox_override("disabled", style)
	tile.add_theme_color_override("font_color", C_TEXT if not locked else C_LOCKED)
	tile.add_theme_color_override("font_color_hover", C_BLUE)
	tile.add_theme_color_override("font_color_disabled", C_LOCKED)

	if not locked:
		var scene_path: String = level["scene"]
		tile.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))

	return tile

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	return b
