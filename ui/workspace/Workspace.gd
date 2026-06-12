extends Control

@onready var back_btn:       Button = $TopBar/HBox/BackButton
@onready var tab_box:        HBoxContainer = $TopBar/HBox/Tabs
@onready var palette_list:   VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteMargin/PaletteList
@onready var canvas:         Control = $Body/Right/RightVBox/Scroll/Canvas
@onready var name_edit:      LineEdit = $Body/Right/RightVBox/HeaderBar/Header/NameEdit
@onready var color_picker:   ColorPickerButton = $Body/Right/RightVBox/HeaderBar/Header/ColorPicker
@onready var delete_species_btn: Button = $Body/Right/RightVBox/HeaderBar/Header/DeleteSpeciesBtn

const SCRATCH_BLOCK := preload("res://ui/workspace/ScratchBlock.tscn")

var _current_type_id: String = "hunter"
var _tab_buttons: Dictionary = {}

func _ready():
	get_tree().paused = false
	_current_type_id = SimulationManager.selected_type_id
	back_btn.pressed.connect(_on_back)
	canvas.canvas_mutated.connect(_save_blocks)
	color_picker.color_changed.connect(_on_color_changed)
	delete_species_btn.pressed.connect(_on_delete_species)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_commit_species_name)
	SimulationManager.species_list_changed.connect(_on_species_list_changed)
	SimulationManager.variables_changed.connect(_on_variables_changed)
	_style_color_picker()
	_build_tabs()
	_build_palette()
	_refresh()

func _on_variables_changed():
	_build_palette()
	_refresh()

func _build_tabs():
	for child in tab_box.get_children():
		child.queue_free()
	_tab_buttons.clear()
	var group := ButtonGroup.new()
	for t in SimulationManager.robot_types:
		var btn := Button.new()
		btn.text = " %s " % t.name
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_color_override("font_color", t.color)
		btn.add_theme_color_override("font_hover_color", t.color)
		btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		var sb := StyleBoxFlat.new()
		sb.bg_color = t.color
		sb.border_color = t.color
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover_pressed", sb)
		var type_id: String = t.id
		btn.pressed.connect(func(): _switch_type(type_id))
		if t.id == _current_type_id:
			btn.button_pressed = true
		tab_box.add_child(btn)
		_tab_buttons[t.id] = btn
	var add_btn := Button.new()
	add_btn.text = " + "
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.tooltip_text = "Add new species"
	add_btn.pressed.connect(_on_add_species)
	tab_box.add_child(add_btn)

func _switch_type(type_id: String):
	_commit_species_name()
	_save_blocks()
	_current_type_id = type_id
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
	var t: String = name_edit.text.strip_edges()
	var current_name: String = SimulationManager.get_type(_current_type_id).name
	if t == "":
		name_edit.text = current_name
		return
	if t != current_name:
		SimulationManager.set_species_name(_current_type_id, t)

func _on_species_list_changed():
	var found := false
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
	for category in ["config", "condition", "logic", "variable", "action"]:
		if category == "variable":
			_build_variable_section()
		else:
			_build_palette_category(category, SimulationManager.PALETTE_ORDER.get(category, []))

func _build_variable_section():
	var header := Label.new()
	header.text = "VARIABLES"
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.435, 0.435, 0.498, 1.0))
	palette_list.add_child(header)
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
		palette_list.add_child(row)
	var new_btn := Button.new()
	new_btn.text = "  + New variable"
	new_btn.focus_mode = Control.FOCUS_NONE
	new_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_btn.custom_minimum_size = Vector2(0, 28)
	new_btn.pressed.connect(_open_new_variable_dialog)
	palette_list.add_child(new_btn)
	for block_id in SimulationManager.PALETTE_ORDER.get("variable", []):
		_make_palette_item(block_id)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	palette_list.add_child(spacer)

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
	var header := Label.new()
	header.text = _category_label(category)
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.435, 0.435, 0.498, 1.0))
	palette_list.add_child(header)
	for block_id in ids:
		_make_palette_item(block_id)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	palette_list.add_child(spacer)

func _make_palette_item(block_id: String):
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var preview := SCRATCH_BLOCK.instantiate()
	wrap.add_child(preview)
	palette_list.add_child(wrap)
	preview.setup_preview(block_id)
	wrap.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_add_block(block_id)
	)
	wrap.mouse_entered.connect(func(): wrap.modulate = Color(1.12, 1.12, 1.12))
	wrap.mouse_exited.connect(func(): wrap.modulate = Color(1, 1, 1))

func _category_label(category: String) -> String:
	match category:
		"condition": return "EVENTS"
		"logic":     return "CONDITIONS"
	return category.to_upper()

func _refresh():
	var type_def := SimulationManager.get_type(_current_type_id)
	name_edit.text = type_def.name
	name_edit.add_theme_color_override("font_color", type_def.color)
	name_edit.add_theme_color_override("font_uneditable_color", type_def.color)
	color_picker.color = type_def.color
	_update_picker_swatch(type_def.color)
	delete_species_btn.visible = SimulationManager.robot_types.size() > 1
	for child in canvas.get_children():
		child.queue_free()
	for s in SimulationManager.get_scripts(_current_type_id):
		var zone: VBoxContainer = canvas.spawn_stack(Vector2(s.get("x", 40.0), s.get("y", 40.0)))
		for b in s.get("blocks", []):
			_spawn_block_widget(b, zone)
	canvas.resolve_overlaps()

func _add_block(block_id: String):
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_id, {})
	var params := {}
	var input_def = def.get("input", null)
	if input_def != null and input_def is Dictionary:
		var itype: String = input_def.get("type", "slider")
		if itype == "species":
			params["value"] = input_def.get("default", "hunter")
		else:
			params["value"] = input_def.get("default", 0.0)
	var zone: VBoxContainer = canvas.spawn_stack(_new_stack_position())
	_spawn_block_widget({"type": block_id, "params": params, "children": []}, zone)
	_save_blocks()

func _new_stack_position() -> Vector2:
	var scroll: ScrollContainer = $Body/Right/RightVBox/Scroll
	var n: int = canvas.get_child_count() % 6
	return Vector2(scroll.scroll_horizontal + 30.0 + n * 28.0, scroll.scroll_vertical + 30.0 + n * 28.0)

func _spawn_block_widget(data: Dictionary, parent_zone: VBoxContainer):
	var block := SCRATCH_BLOCK.instantiate()
	parent_zone.add_child(block)
	block.setup(data.get("type", ""), data.get("params", {}))
	block.block_changed.connect(_save_blocks)
	block.block_deleted.connect(func():
		block.queue_free()
		await get_tree().process_frame
		_save_blocks()
	)
	if block.is_container():
		var zone: VBoxContainer = block.get_children_zone()
		zone.blocks_mutated.connect(_save_blocks)
		for child_data in data.get("children", []):
			_spawn_block_widget(child_data, zone)

func _save_blocks():
	canvas.remove_empty_stacks()
	var scripts: Array = []
	for zone in canvas.get_children():
		if not zone is VBoxContainer:
			continue
		var blocks: Array = []
		for child in zone.get_children():
			if child is PanelContainer and child.has_method("get_block_data"):
				blocks.append(child.get_block_data())
		if blocks.is_empty():
			continue
		scripts.append({"x": zone.position.x, "y": zone.position.y, "blocks": blocks})
	SimulationManager.set_scripts(_current_type_id, scripts)

func _on_back():
	_commit_species_name()
	_save_blocks()
	get_tree().change_scene_to_file("res://levels/Arena.tscn")
