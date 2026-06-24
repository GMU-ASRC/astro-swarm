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

const LEVELS := [
	{
		"num":    "01",
		"title":  "FARP SCENARIO",
		"desc":   "Position defenders to protect\nyour planet from a lone\nenemy drone. Tune vision\nand FOV to intercept it.",
		"scene":  "res://levels/FARPScene.tscn",
		"locked": false,
	},
	{
		"num":    "02",
		"title":  "DOMINATION",
		"desc":   "Conquer enemy planets wave\nby wave. Build an attack\nforce and defend your home.\nEarn Market Tokens.",
		"scene":  "res://levels/DominationScene.tscn",
		"locked": false,
	},
	{
		"num":    "03",
		"title":  "TBD",
		"desc":   "Coming soon...",
		"scene":  "",
		"locked": true,
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

	# Title
	var title := _lbl("LEVELS", 32, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Cards
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for lvl in LEVELS:
		row.add_child(_make_card(lvl))

	# Back button
	var back_wrap := CenterContainer.new()
	vbox.add_child(back_wrap)
	var back := _make_btn("← BACK TO BASE")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/PlayerBaseScene.tscn"))
	back_wrap.add_child(back)

func _make_card(lvl: Dictionary) -> Control:
	var locked: bool = lvl["locked"]

	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL if not locked else Color(0.08, 0.075, 0.13, 1.0)
	style.border_color = C_BLUE if not locked else C_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	pc.add_theme_stylebox_override("panel", style)
	pc.custom_minimum_size = Vector2(200, 280)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 20)
	pc.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# Level number badge
	var num_lbl := _lbl("LEVEL " + lvl["num"], 10, C_BLUE if not locked else C_LOCKED)
	vb.add_child(num_lbl)

	# Separator
	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)

	# Title
	var title := _lbl(lvl["title"], 14, C_TEXT if not locked else C_LOCKED)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(160, 0)
	vb.add_child(title)

	# Description
	var desc := _lbl(lvl["desc"], 10, C_DIM if not locked else C_LOCKED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(160, 0)
	vb.add_child(desc)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	# Play button
	var btn := _make_btn("LOCKED" if locked else "PLAY →")
	btn.disabled = locked
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not locked:
		var scene_path: String = lvl["scene"]
		btn.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))
	vb.add_child(btn)

	return pc

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
