extends CanvasLayer

const FONT_REG   := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

const C_TEXT     := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM      := Color(0.6, 0.62, 0.74, 1.0)
const C_BORDER   := Color(0.318, 0.306, 0.463, 1.0)
const C_PANEL    := Color(0.129, 0.122, 0.196, 1.0)
const C_ACCENT   := Color(0.451, 0.616, 1.0, 1.0)
const C_RED      := Color(1.0, 0.42, 0.32, 1.0)
const C_AMBER    := Color(1.0, 0.70, 0.20, 1.0)
const C_GREENISH := Color(0.40, 0.85, 0.45, 1.0)
const C_PURPLE   := Color(0.65, 0.45, 0.95, 1.0)
const C_LASER    := Color(0.55, 0.90, 1.0, 1.0)

const HINT_TEXT := "1-4 or TAB picks a ship  -  W A S D or ARROW KEYS flies it  -  park all four to raise the laser box  -  defenders inside the box run your WORKSPACE algorithm"

signal leave_pressed
signal restart_pressed
signal workspace_pressed

var _wave_label: Label
var _box_label: Label
var _ship_labels: Array = []
var _swarm_labels: Dictionary = {}
var _score_labels: Dictionary = {}
var _result_panel: Control
var _result_grid: GridContainer

func _ready():
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GAME_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := HBoxContainer.new()
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.offset_left = 12
	top_left.offset_top = 12
	top_left.offset_right = 280
	top_left.offset_bottom = 42
	top_left.add_theme_constant_override("separation", 8)
	root.add_child(top_left)

	var leave := _compact_btn("< LEAVE")
	leave.pressed.connect(func(): leave_pressed.emit())
	top_left.add_child(leave)

	var workspace := _compact_btn("WORKSPACE")
	workspace.pressed.connect(func(): workspace_pressed.emit())
	top_left.add_child(workspace)

	_build_header(root)
	_build_swarm_panel(root)
	_build_score_panel(root)
	_build_ship_bar(root)
	_build_hint(root)
	_build_result_panel(root)

func _build_header(root: Control):
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	column.offset_left = -240
	column.offset_right = 240
	column.offset_top = 10
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var title := _lbl("DEMO", 22, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_wave_label = _lbl("", 11, C_AMBER)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_wave_label)

	_box_label = _lbl("", 11, C_DIM)
	_box_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_box_label)

func _build_swarm_panel(root: Control):
	var column := _stat_column(root, true)
	_add_stat(column, "SWARM", 12, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_swarm_labels["defenders"] = _add_stat(column, "", 11, C_ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	_swarm_labels["wild"] = _add_stat(column, "", 11, C_PURPLE, HORIZONTAL_ALIGNMENT_LEFT)
	_swarm_labels["evaders"] = _add_stat(column, "", 11, C_RED, HORIZONTAL_ALIGNMENT_LEFT)

func _build_score_panel(root: Control):
	var column := _stat_column(root, false)
	_add_stat(column, "TALLY", 12, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_labels["captures"] = _add_stat(column, "", 11, C_GREENISH, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_labels["hits"] = _add_stat(column, "", 11, C_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_labels["waves"] = _add_stat(column, "", 11, C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

func _stat_column(root: Control, on_left: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if on_left:
		column.set_anchors_preset(Control.PRESET_TOP_LEFT)
		column.offset_left = 14
		column.offset_right = 274
		column.offset_top = 52
	else:
		column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		column.offset_left = -274
		column.offset_right = -14
		column.offset_top = 12
	root.add_child(column)
	return column

func _add_stat(column: VBoxContainer, text: String, size: int, color: Color, align: int) -> Label:
	var label := _lbl(text, size, color)
	label.horizontal_alignment = align
	column.add_child(label)
	return label

func _build_ship_bar(root: Control):
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -220
	row.offset_right = 220
	row.offset_top = -84
	row.offset_bottom = -58
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for index in 4:
		var label := _lbl("SHIP %d" % (index + 1), 12, C_DIM)
		row.add_child(label)
		_ship_labels.append(label)

func _build_hint(root: Control):
	var hint := _lbl(HINT_TEXT, 10, C_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -520
	hint.offset_right = 520
	hint.offset_top = -44
	hint.offset_bottom = -14
	root.add_child(hint)

func refresh(state: Dictionary):
	_wave_label.text = "WAVE %d  -  NEXT IN %ds" % [int(state["wave"]), int(state["next_wave"])]
	if int(state["incoming"]) > 0:
		_wave_label.text = "WAVE %d  -  %d ATTACKERS INBOUND" % [int(state["wave"]), int(state["incoming"])]
	if bool(state["box_active"]):
		_box_label.text = "LASER BOX ARMED"
		_box_label.add_theme_color_override("font_color", C_LASER)
	else:
		_box_label.text = "LASER BOX OFFLINE - PARK ALL FOUR SHIPS"
		_box_label.add_theme_color_override("font_color", C_DIM)
	_swarm_labels["defenders"].text = "DEFENDERS IN BOX: %d" % int(state["defenders"])
	_swarm_labels["wild"].text = "DRIFTING PURPLE: %d" % int(state["wild"])
	_swarm_labels["evaders"].text = "ATTACKERS ALIVE: %d" % int(state["evaders"])
	_score_labels["captures"].text = "CAPTURES: %d" % int(state["captures"])
	_score_labels["hits"].text = "PLANET HITS: %d" % int(state["hits"])
	_score_labels["waves"].text = "TIME: %d:%02d" % [int(state["elapsed"]) / 60, int(state["elapsed"]) % 60]
	_refresh_ship_bar(int(state["active_ship"]), state["parked"])

func _refresh_ship_bar(active_index: int, parked: Array):
	for index in _ship_labels.size():
		var label: Label = _ship_labels[index]
		if index == active_index:
			label.text = "[ SHIP %d ]" % (index + 1)
			label.add_theme_color_override("font_color", C_AMBER)
		elif index < parked.size() and bool(parked[index]):
			label.text = "SHIP %d" % (index + 1)
			label.add_theme_color_override("font_color", C_LASER)
		else:
			label.text = "SHIP %d" % (index + 1)
			label.add_theme_color_override("font_color", C_DIM)

func show_result(state: Dictionary):
	_fill_result_grid(state)
	_result_panel.visible = true

func _fill_result_grid(state: Dictionary):
	for child in _result_grid.get_children():
		_result_grid.remove_child(child)
		child.queue_free()
	_result_row("WAVES LAUNCHED", str(int(state["wave"])), C_TEXT)
	_result_row("ATTACKERS CAPTURED", str(int(state["captures"])), C_GREENISH)
	_result_row("PLANET HITS TAKEN", str(int(state["hits"])), C_RED)
	_result_row("TIME SURVIVED", "%d:%02d" % [int(state["elapsed"]) / 60, int(state["elapsed"]) % 60], C_TEXT)

func _result_row(caption: String, value: String, color: Color):
	var name_label := _lbl(caption, 11, C_DIM)
	name_label.custom_minimum_size = Vector2(260, 0)
	_result_grid.add_child(name_label)
	var value_label := _lbl(value, 12, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(120, 0)
	_result_grid.add_child(value_label)

func _build_result_panel(root: Control):
	_result_panel = Control.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	root.add_child(_result_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(dim)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -270
	card.offset_top = -180
	card.offset_right = 270
	card.offset_bottom = 180
	_result_panel.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := _lbl("SWARM WIPED OUT", 20, C_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := _lbl("every defender has been spent", 10, C_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var separator := ColorRect.new()
	separator.color = C_BORDER
	separator.custom_minimum_size = Vector2(0, 1)
	box.add_child(separator)

	_result_grid = GridContainer.new()
	_result_grid.columns = 2
	_result_grid.add_theme_constant_override("h_separation", 12)
	_result_grid.add_theme_constant_override("v_separation", 7)
	box.add_child(_result_grid)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	var again := _btn("RUN IT AGAIN", 11)
	again.pressed.connect(func(): restart_pressed.emit())
	row.add_child(again)

	var back := _btn("BACK TO BASE", 11)
	back.pressed.connect(func(): leave_pressed.emit())
	row.add_child(back)

func _lbl(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_REG)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _btn(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT_REG)
	button.add_theme_font_size_override("font_size", size)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _compact_btn(text: String) -> Button:
	var button := _btn(text, 9)
	button.add_theme_stylebox_override("normal", _compact_style(C_PANEL, C_BORDER))
	button.add_theme_stylebox_override("hover", _compact_style(Color(0.18, 0.17, 0.27, 1.0), C_ACCENT))
	button.add_theme_stylebox_override("pressed", _compact_style(Color(0.1, 0.095, 0.155, 1.0), C_ACCENT))
	button.add_theme_stylebox_override("focus", _compact_style(C_PANEL, C_BORDER))
	button.add_theme_color_override("font_color", C_TEXT)
	return button

func _compact_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style
