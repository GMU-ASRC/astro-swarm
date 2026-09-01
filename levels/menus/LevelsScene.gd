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

const TILE_SIZE    := Vector2(220, 140)
const GRID_COLUMNS := 3

const LEVELS := [
	{
		"name":   "FARP  I\nDEFENSE · PLACE",
		"desc":   "Place your own defenders\nand program their detection",
		"scene":  "res://levels/modes/level1/Level1Scene.tscn",
		"locked": false,
	},
	{
		"name":   "FARP  II\nDEFENSE · RING",
		"desc":   "Defenders ring the planet\nYour algorithm is all that counts",
		"scene":  "res://levels/modes/level2/Level2Scene.tscn",
		"locked": false,
	},
	{
		"name":   "FARP  III\nDEFENSE · WAVES",
		"desc":   "Wave after wave of one evader\nA captured evader is destroyed",
		"scene":  "res://levels/modes/level3/Level3Scene.tscn",
		"locked": false,
	},
	{
		"name":   "FARP  IV\nDEFENSE · ATTRITION",
		"desc":   "The same waves, but a capture\ndestroys the defender too",
		"scene":  "res://levels/modes/level4/Level4Scene.tscn",
		"locked": false,
	},
	{
		"name":   "FARP  V\nDEFENSE · SIEGE",
		"desc":   "Five evaders at once off the edges\nEvery capture costs a defender",
		"scene":  "res://levels/modes/level5/Level5Scene.tscn",
		"locked": false,
	},
	{
		"name":   "FARP  VI\nEVASION · PILOT",
		"desc":   "Fly the evader yourself against\nthe best Level 2 algorithm",
		"scene":  "res://levels/modes/level6/Level6Scene.tscn",
		"locked": false,
	},
	{
		"name":   "FARP  VII\nSWARM · MERGE",
		"desc":   "Lead two milling swarms into one\nand walk them onto the planet",
		"scene":  "res://levels/modes/level7/Level7Scene.tscn",
		"locked": false,
	},
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

	var entries_wrap := CenterContainer.new()
	vbox.add_child(entries_wrap)
	var entries_btn := _make_btn("MY ENTRIES")
	entries_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerEntriesScene.tscn"))
	entries_wrap.add_child(entries_btn)

	var back_wrap := CenterContainer.new()
	vbox.add_child(back_wrap)
	var back := _make_btn("← BACK TO BASE")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn"))
	back_wrap.add_child(back)

func _make_tile(number: int, level: Dictionary) -> Control:
	var locked: bool = level["locked"]

	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL if not locked else Color(0.08, 0.075, 0.13, 1.0)
	style.border_color = C_BLUE  if not locked else C_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 14
	style.content_margin_bottom = 14
	tile.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	tile.add_child(vb)

	var num_lbl := Label.new()
	num_lbl.text = "LEVEL %d" % number
	num_lbl.add_theme_font_override("font", FONT_REG)
	num_lbl.add_theme_font_size_override("font_size", 11)
	num_lbl.add_theme_color_override("font_color", C_BLUE if not locked else C_LOCKED)
	vb.add_child(num_lbl)

	var name_lbl := Label.new()
	name_lbl.text = level["name"] if not locked else "LOCKED"
	name_lbl.add_theme_font_override("font", FONT_REG)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", C_TEXT if not locked else C_LOCKED)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_lbl)

	if level.has("desc") and not locked:
		var sep := ColorRect.new()
		sep.color = C_BORDER
		sep.custom_minimum_size = Vector2(0, 1)
		vb.add_child(sep)
		var desc_lbl := Label.new()
		desc_lbl.text = level["desc"]
		desc_lbl.add_theme_font_override("font", FONT_REG)
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.add_theme_color_override("font_color", C_DIM)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(desc_lbl)

	if not locked:
		var scene_path: String = level["scene"]
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				get_tree().change_scene_to_file(scene_path)
		)
		tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return tile

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	return b
