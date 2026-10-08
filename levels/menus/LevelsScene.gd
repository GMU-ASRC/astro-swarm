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

const TILE_WIDTH    := 560.0
const ROW_SEPARATION := 10
const SCREEN_MARGIN := 40

const BAR_WIDTH       := 4.0
const BAR_WIDTH_HOVER := 7.0
const PAD_LEFT        := 16
const PAD_RIGHT       := 14
const PAD_Y           := 10

const GHOST_SIZE  := 40
const GHOST_ALPHA := 0.13
const BORDER_ALPHA := 0.5


func _ready():
	theme = GAME_THEME
	_build_ui()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_top", SCREEN_MARGIN)
	outer.add_theme_constant_override("margin_bottom", SCREEN_MARGIN)
	add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(vbox)

	var title := _lbl("LEVELS", 32, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list_scroll)

	var level_list := VBoxContainer.new()
	level_list.add_theme_constant_override("separation", ROW_SEPARATION)
	level_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(level_list)

	level_list.add_child(_make_tile(0, LevelInfo.TRAINING_LEVEL, false))
	for i in LevelInfo.LEVELS.size():
		level_list.add_child(_make_tile(i + 1, LevelInfo.LEVELS[i], _is_locked(i)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	var back := _make_btn("← BACK TO BASE")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn"))
	buttons.add_child(back)

func _is_locked(level_index: int) -> bool:
	if PlayerSettings.is_dev_mode() or level_index == 0:
		return false
	return not PlayerData.is_level_completed(LevelInfo.LEVELS[level_index - 1]["id"])

func _make_tile(number: int, level: Dictionary, locked: bool) -> Control:
	var accent: Color = C_LOCKED if locked else level["color"]

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(TILE_WIDTH, 0)
	tile.add_theme_stylebox_override("panel", _tile_style(accent, locked, false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(row)

	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(BAR_WIDTH, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	var padding := MarginContainer.new()
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", PAD_LEFT)
	padding.add_theme_constant_override("margin_right", PAD_RIGHT)
	padding.add_theme_constant_override("margin_top", PAD_Y)
	padding.add_theme_constant_override("margin_bottom", PAD_Y)
	row.add_child(padding)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_child(content)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text)

	var ghost := _lbl("%02d" % number, GHOST_SIZE, Color(accent.r, accent.g, accent.b, GHOST_ALPHA))
	ghost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ghost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(ghost)

	var tag := _lbl("LEVEL %d - LOCKED" % number if locked else "LEVEL %d" % number, 10, accent)
	text.add_child(tag)

	var name_lbl := _lbl(level["name"], 17, C_LOCKED if locked else C_TEXT)
	text.add_child(name_lbl)

	if locked:
		tile.tooltip_text = "Finish level %d to unlock this level." % (number - 1)
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
	bar.custom_minimum_size.x = BAR_WIDTH_HOVER if hovered else BAR_WIDTH
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
