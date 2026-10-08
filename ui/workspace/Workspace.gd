extends Control

@onready var back_btn:       Button = $TopBar/HBox/BackButton
@onready var tab_box:        HBoxContainer = $TopBar/HBox/Tabs
@onready var palette_list:   VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteMargin/PaletteList
@onready var canvas:         Control = $Body/Right/RightVBox/Scroll/Canvas
@onready var name_edit:      LineEdit = $Body/Right/RightVBox/HeaderBar/Header/NameEdit
@onready var color_picker:   ColorPickerButton = $Body/Right/RightVBox/HeaderBar/Header/ColorPicker
@onready var delete_species_btn: Button = $Body/Right/RightVBox/HeaderBar/Header/DeleteSpeciesBtn
@onready var hint_label: Label = $Body/Right/RightVBox/HeaderBar/Header/HintLabel

const BlockFactory := preload("res://ui/workspace/BlockFactory.gd")
const ERROR_BANNER := preload("res://ui/workspace/WorkspaceErrorBanner.gd")
const WorkspaceStyle := preload("res://ui/workspace/WorkspaceStyle.gd")
const ARENA_TAB_COLOR := Color(0.788, 0.310, 0.502, 1.0)
const ARENA_HINT := "Runs once for the whole arena · Controls spawn zones"
const PALETTE_CATEGORIES := ["config", "condition", "logic", "variable", "spawn", "action"]

var _current_type_id: String = "hunter"
var _tab_buttons: Dictionary = {}
var _error_banner: PanelContainer
var _species_hint: String = ""

func _ready():
	get_tree().paused = false
	_current_type_id = SimulationManager.selected_type_id
	_species_hint = hint_label.text
	back_btn.pressed.connect(_on_back)
	canvas.canvas_mutated.connect(_save_blocks)
	color_picker.color_changed.connect(_on_color_changed)
	delete_species_btn.pressed.connect(_on_delete_species)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_commit_species_name)
	SimulationManager.species_list_changed.connect(_on_species_list_changed)
	SimulationManager.variables_changed.connect(_on_variables_changed)
	_style_color_picker()
	WorkspaceStyle.apply(self, WorkspaceStyle.SIMULATOR)
	_build_error_banner()
	_build_tabs()
	_build_palette()
	_refresh()

func _build_error_banner():
	var scroll: ScrollContainer = $Body/Right/RightVBox/Scroll
	_error_banner = ERROR_BANNER.new()
	scroll.get_parent().add_child(_error_banner)
	scroll.get_parent().move_child(_error_banner, scroll.get_index())

func _update_errors():
	if _error_banner != null:
		_error_banner.show_messages(canvas.highlight_errors())

func _on_variables_changed():
	_build_palette()
	_refresh()

func _build_tabs():
	for child in tab_box.get_children():
		child.queue_free()
	_tab_buttons.clear()
	var group := ButtonGroup.new()
	_add_tab_button("Arena", ARENA_TAB_COLOR, SimulationManager.ARENA_PROGRAM_ID, group)
	for t in SimulationManager.robot_types:
		_add_tab_button(t.name, t.color, t.id, group)
	var add_btn := Button.new()
	add_btn.text = " + "
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.tooltip_text = "Add new species"
	add_btn.pressed.connect(_on_add_species)
	tab_box.add_child(add_btn)

func _add_tab_button(label: String, color: Color, program_id: String, group: ButtonGroup):
	var btn := Button.new()
	btn.text = " %s " % label
	btn.toggle_mode = true
	btn.button_group = group
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	var sb_normal := _tab_style()
	sb_normal.bg_color = Color(color.r, color.g, color.b, 0.08)
	sb_normal.border_color = color.darkened(0.15)
	var sb_hover := _tab_style()
	sb_hover.bg_color = Color(color.r, color.g, color.b, 0.18)
	sb_hover.border_color = color
	var sb_pressed := _tab_style()
	sb_pressed.bg_color = color
	sb_pressed.border_color = color
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_normal)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover_pressed", sb_pressed)
	btn.pressed.connect(func(): _switch_type(program_id))
	if program_id == _current_type_id:
		btn.button_pressed = true
	tab_box.add_child(btn)
	_tab_buttons[program_id] = btn

func _tab_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _is_arena_program() -> bool:
	return _current_type_id == SimulationManager.ARENA_PROGRAM_ID

func _switch_type(type_id: String):
	_commit_species_name()
	_save_blocks()
	_current_type_id = type_id
	_build_palette()
	_refresh()

func _on_color_changed(color: Color):
	SimulationManager.set_species_color(_current_type_id, color)
	_update_picker_swatch(color)
	_build_tabs()

func _update_picker_swatch(color: Color):
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.667, 0.667, 0.694, 1.0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	color_picker.add_theme_stylebox_override("normal", sb)
	color_picker.add_theme_stylebox_override("hover", sb)
	color_picker.add_theme_stylebox_override("pressed", sb)
	color_picker.add_theme_stylebox_override("focus", sb)

func _style_color_picker():
	_update_picker_swatch(color_picker.color)
	color_picker.picker_created.connect(_on_picker_created)

func _on_picker_created():
	var picker: ColorPicker = color_picker.get_picker()
	var popup: PopupPanel = color_picker.get_popup()
	var app_theme := preload("res://ui/MainTheme.tres")
	popup.theme = app_theme
	var sb_popup := StyleBoxFlat.new()
	sb_popup.bg_color = Color(0.910, 0.910, 0.925, 1.0)
	sb_popup.set_corner_radius_all(6)
	sb_popup.set_border_width_all(1)
	sb_popup.border_color = Color(0.667, 0.667, 0.694, 1.0)
	sb_popup.content_margin_left = 12
	sb_popup.content_margin_right = 12
	sb_popup.content_margin_top = 12
	sb_popup.content_margin_bottom = 12
	sb_popup.shadow_color = Color(0, 0, 0, 0.25)
	sb_popup.shadow_size = 6
	popup.add_theme_stylebox_override("panel", sb_popup)
	picker.color_modes_visible = false
	picker.sliders_visible = true
	picker.hex_visible = true
	picker.presets_visible = false

func _on_add_species():
	_commit_species_name()
	_save_blocks()
	var n: int = SimulationManager.robot_types.size() + 1
	var hue: float = fmod(n * 0.618033988, 1.0)
	var color := Color.from_hsv(hue, 0.55, 0.70)
	var new_id := SimulationManager.add_species("Species %d" % n, color)
	_current_type_id = new_id
	SimulationManager.set_selected_type(new_id)

func _on_delete_species():
	if SimulationManager.robot_types.size() <= 1:
		return
	name_edit.release_focus()
	_save_blocks()
	SimulationManager.remove_species(_current_type_id)
	_current_type_id = SimulationManager.selected_type_id

func _on_name_submitted(_new_name: String):
	name_edit.release_focus()

func _commit_species_name():
	if _is_arena_program():
		return
	var t: String = name_edit.text.strip_edges()
	var current_name: String = SimulationManager.get_type(_current_type_id).name
	if t == "":
		name_edit.text = current_name
		return
	if t != current_name:
		SimulationManager.set_species_name(_current_type_id, t)

func _on_species_list_changed():
	var found := _is_arena_program()
	for t in SimulationManager.robot_types:
		if t.id == _current_type_id:
			found = true
			break
	if not found and SimulationManager.robot_types.size() > 0:
		_current_type_id = SimulationManager.robot_types[0].id
	_build_tabs()
	_build_palette()
	_refresh()

func _build_palette():
	for child in palette_list.get_children():
		child.queue_free()
	var palette_order: Dictionary = SimulationManager.ARENA_PALETTE_ORDER if _is_arena_program() else SimulationManager.PALETTE_ORDER
	for category in PALETTE_CATEGORIES:
		if not palette_order.has(category):
			continue
		if category == "variable":
			_build_variable_section()
		else:
			_build_palette_category(category, palette_order[category])

func _build_variable_section():
	var section: VBoxContainer = WorkspaceStyle.add_palette_section(palette_list, "VARIABLES", "variable", WorkspaceStyle.SIMULATOR)
	for v in SimulationManager.variables:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s : %s" % [v.get("name", ""), v.get("type", "int")]
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var del := Button.new()
		del.text = "x"
		del.focus_mode = Control.FOCUS_NONE
		var vname: String = v.get("name", "")
		del.pressed.connect(func(): SimulationManager.remove_variable(vname))
		row.add_child(del)
		section.add_child(row)
	var new_btn := Button.new()
	new_btn.text = "  + New variable"
	new_btn.focus_mode = Control.FOCUS_NONE
	new_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_btn.custom_minimum_size = Vector2(0, 28)
	new_btn.pressed.connect(_open_new_variable_dialog)
	section.add_child(new_btn)
	for block_id in SimulationManager.PALETTE_ORDER.get("variable", []):
		BlockFactory.add_palette_item(section, block_id, _add_block)

func _open_new_variable_dialog():
	var dialog := AcceptDialog.new()
	dialog.title = "New Variable"
	dialog.theme = preload("res://ui/MainTheme.tres")
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	box.add_theme_constant_override("separation", 8)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Variable name"
	box.add_child(name_edit)
	var type_select := OptionButton.new()
	type_select.add_item("int")
	type_select.add_item("string")
	box.add_child(type_select)
	dialog.add_child(box)
	dialog.confirmed.connect(func():
		var type_name: String = "string" if type_select.selected == 1 else "int"
		SimulationManager.add_variable(name_edit.text, type_name)
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	name_edit.grab_focus()

func _build_palette_category(category: String, ids: Array):
	var section: VBoxContainer = WorkspaceStyle.add_palette_section(palette_list, _category_label(category), category, WorkspaceStyle.SIMULATOR)
	for block_id in ids:
		BlockFactory.add_palette_item(section, block_id, _add_block)

func _category_label(category: String) -> String:
	match category:
		"condition": return "EVENTS"
		"logic":     return "CONDITIONS"
		"spawn":     return "SPAWN ZONES"
	return category.to_upper()

func _refresh():
	_refresh_header()
	for child in canvas.get_children():
		child.queue_free()
	for s in SimulationManager.get_scripts(_current_type_id):
		var zone: VBoxContainer = canvas.spawn_stack(Vector2(s.get("x", 40.0), s.get("y", 40.0)))
		for b in s.get("blocks", []):
			BlockFactory.create_block(b, zone, _save_blocks)
	canvas.resolve_overlaps()
	_update_errors()

func _refresh_header():
	var arena_program := _is_arena_program()
	name_edit.editable = not arena_program
	color_picker.visible = not arena_program
	hint_label.text = ARENA_HINT if arena_program else _species_hint
	if arena_program:
		name_edit.text = "Arena program"
		name_edit.add_theme_color_override("font_color", ARENA_TAB_COLOR)
		name_edit.add_theme_color_override("font_uneditable_color", ARENA_TAB_COLOR)
		delete_species_btn.visible = false
		return
	var type_def := SimulationManager.get_type(_current_type_id)
	name_edit.text = type_def.name
	name_edit.add_theme_color_override("font_color", type_def.color)
	name_edit.add_theme_color_override("font_uneditable_color", type_def.color)
	color_picker.color = type_def.color
	_update_picker_swatch(type_def.color)
	delete_species_btn.visible = SimulationManager.robot_types.size() > 1

func _add_block(block_id: String):
	var zone: VBoxContainer = canvas.spawn_stack(_new_stack_position())
	BlockFactory.create_block({"type": block_id}, zone, _save_blocks)
	_save_blocks()

func _new_stack_position() -> Vector2:
	var scroll: ScrollContainer = $Body/Right/RightVBox/Scroll
	var n: int = canvas.get_child_count() % 6
	return Vector2(scroll.scroll_horizontal + 30.0 + n * 28.0, scroll.scroll_vertical + 30.0 + n * 28.0)

func _save_blocks():
	SimulationManager.set_scripts(_current_type_id, canvas.collect_scripts())
	_update_errors()

func _on_back():
	_commit_species_name()
	_save_blocks()
	get_tree().change_scene_to_file("res://levels/modes/Arena.tscn")
