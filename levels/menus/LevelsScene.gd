extends Control

const FONT_REG   := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

const C_BG            := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL         := Color(0.098, 0.094, 0.157, 1.0)
const C_PANEL_HOVER   := Color(0.165, 0.157, 0.251, 1.0)
const C_PANEL_LOCKED  := Color(0.063, 0.059, 0.102, 1.0)
const C_TEXT          := Color(0.93, 0.94, 1.0, 1.0)
const C_TEXT_HOVER    := Color(1.0, 1.0, 1.0, 1.0)
const C_LOCKED        := Color(0.35, 0.35, 0.45, 1.0)

const TILE_SIZE     := Vector2(560, 56)
const ROW_SEPARATION := 10

const BAR_WIDTH       := 4.0
const BAR_WIDTH_HOVER := 7.0
const PAD_LEFT        := 16.0
const PAD_RIGHT       := 14.0
const PAD_Y           := 8.0

const GHOST_SIZE  := 40
const GHOST_ALPHA := 0.13
const BORDER_ALPHA := 0.5

const LEVELS := [
	{"name": "DEFENSE",   "color": Color(0.451, 0.616, 1.0, 1.0),  "scene": "res://levels/modes/level1/Level1Scene.tscn",      "locked": false},
	{"name": "RING",      "color": Color(0.400, 0.780, 0.95, 1.0), "scene": "res://levels/modes/level2/Level2Scene.tscn",      "locked": false},
	{"name": "WAVES",     "color": Color(0.400, 0.850, 0.45, 1.0), "scene": "res://levels/modes/level3/Level3Scene.tscn",      "locked": false},
	{"name": "ATTRITION", "color": Color(1.000, 0.700, 0.20, 1.0), "scene": "res://levels/modes/level4/Level4Scene.tscn",      "locked": false},
	{"name": "SIEGE",     "color": Color(1.000, 0.420, 0.32, 1.0), "scene": "res://levels/modes/level5/Level5Scene.tscn",      "locked": false},
	{"name": "PILOT",     "color": Color(0.780, 0.520, 1.0, 1.0),  "scene": "res://levels/modes/level6/Level6Scene.tscn",      "locked": false},
	{"name": "SWARM",     "color": Color(1.000, 0.840, 0.20, 1.0), "scene": "res://levels/modes/level7/Level7Scene.tscn",      "locked": false},
	{"name": "SUPPLY",    "color": Color(0.350, 0.880, 0.80, 1.0), "scene": "res://levels/modes/level8/Level8PlanetA.tscn",    "locked": false},
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
	vbox.add_theme_constant_override("separation", 20)
	outer.add_child(vbox)

	var title := _lbl("LEVELS", 32, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var level_list := VBoxContainer.new()
	level_list.add_theme_constant_override("separation", ROW_SEPARATION)
	vbox.add_child(level_list)

	for i in LEVELS.size():
		level_list.add_child(_make_tile(i + 1, LEVELS[i]))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	var back := _make_btn("← BACK TO BASE")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn"))
	buttons.add_child(back)

	var entries_btn := _make_btn("MY ENTRIES")
	entries_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerEntriesScene.tscn"))
	buttons.add_child(entries_btn)

func _make_tile(number: int, level: Dictionary) -> Control:
	var locked: bool = level["locked"]
	var accent: Color = C_LOCKED if locked else level["color"]

	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.add_theme_stylebox_override("panel", _tile_style(accent, locked, false))

	var layers := Control.new()
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(layers)

	var bar := ColorRect.new()
	bar.color = accent
	bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_right = BAR_WIDTH
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(bar)

	var ghost := _lbl("%02d" % number, GHOST_SIZE, Color(accent.r, accent.g, accent.b, GHOST_ALPHA))
	ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	ghost.offset_right = -PAD_RIGHT
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(ghost)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = BAR_WIDTH + PAD_LEFT
	text.offset_top = PAD_Y
	text.offset_right = -PAD_RIGHT
	text.offset_bottom = -PAD_Y
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layers.add_child(text)

	var tag := _lbl("LEVEL %d" % number, 10, accent)
	text.add_child(tag)

	var name_lbl := _lbl(level["name"] if not locked else "LOCKED", 17, C_TEXT if not locked else C_LOCKED)
	text.add_child(name_lbl)

	if locked:
		return tile

	var scene_path: String = level["scene"]
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_tree().change_scene_to_file(scene_path)
	)
	tile.mouse_entered.connect(func(): _set_hover(tile, bar, name_lbl, accent, true))
	tile.mouse_exited.connect(func(): _set_hover(tile, bar, name_lbl, accent, false))
	return tile

func _set_hover(tile: PanelContainer, bar: ColorRect, name_lbl: Label, accent: Color, hovered: bool):
	tile.add_theme_stylebox_override("panel", _tile_style(accent, false, hovered))
	bar.offset_right = BAR_WIDTH_HOVER if hovered else BAR_WIDTH
	name_lbl.add_theme_color_override("font_color", C_TEXT_HOVER if hovered else C_TEXT)

func _tile_style(accent: Color, locked: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if locked:
		style.bg_color = C_PANEL_LOCKED
	else:
		style.bg_color = C_PANEL_HOVER if hovered else C_PANEL
	style.border_color = accent if hovered else Color(accent.r, accent.g, accent.b, BORDER_ALPHA)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	return style

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
