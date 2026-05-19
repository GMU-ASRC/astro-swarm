extends Control

@onready var back_btn:       Button = $TopBar/HBox/BackButton
@onready var tab_box:        HBoxContainer = $TopBar/HBox/Tabs
@onready var palette_list:   VBoxContainer = $Body/Left/LeftVBox/PaletteScroll/PaletteList
@onready var blocks_list:    VBoxContainer = $Body/Right/RightVBox/Scroll/BlocksList
@onready var name_edit:      LineEdit = $Body/Right/RightVBox/Header/NameEdit
@onready var color_picker:   ColorPickerButton = $Body/Right/RightVBox/Header/ColorPicker
@onready var delete_species_btn: Button = $Body/Right/RightVBox/Header/DeleteSpeciesBtn

const SCRATCH_BLOCK := preload("res://ui/workspace/ScratchBlock.tscn")

var _current_type_id: String = "hunter"
var _tab_buttons: Dictionary = {}
var _drag_block: PanelContainer = null
var _drag_index: int = -1

func _ready():
	get_tree().paused = false
	_current_type_id = SimulationManager.selected_type_id
	back_btn.pressed.connect(_on_back)
	color_picker.color_changed.connect(_on_color_changed)
	delete_species_btn.pressed.connect(_on_delete_species)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(func(): _on_name_submitted(name_edit.text))
	SimulationManager.species_list_changed.connect(_on_species_list_changed)
	_style_color_picker()
	_build_tabs()
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
	_save_blocks()
	SimulationManager.remove_species(_current_type_id)
	_current_type_id = SimulationManager.selected_type_id

func _on_name_submitted(new_name: String):
	name_edit.release_focus()
	if new_name.strip_edges() == "":
		name_edit.text = SimulationManager.get_type(_current_type_id).name
		return
	SimulationManager.set_species_name(_current_type_id, new_name)

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
	for category in ["config", "condition", "action"]:
		var header := Label.new()
		header.text = category.to_upper()
		header.add_theme_font_size_override("font_size", 10)
		header.add_theme_color_override("font_color", Color(0.435, 0.435, 0.498, 1.0))
		palette_list.add_child(header)
		var ids: Array = SimulationManager.PALETTE_ORDER.get(category, [])
		for block_id in ids:
			var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_id, {})
			var btn := Button.new()
			btn.text = "  + %s" % def.get("label", block_id)
			btn.focus_mode = Control.FOCUS_NONE
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 32)
			var cat_color: Color = _cat_color(category)
			btn.add_theme_color_override("font_color", cat_color)
			btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
			var sb_h := StyleBoxFlat.new()
			sb_h.bg_color = cat_color
			sb_h.set_corner_radius_all(4)
			sb_h.content_margin_left = 8
			sb_h.content_margin_right = 8
			sb_h.content_margin_top = 4
			sb_h.content_margin_bottom = 4
			btn.add_theme_stylebox_override("hover", sb_h)
			btn.add_theme_stylebox_override("pressed", sb_h)
			var bid: String = block_id
			btn.pressed.connect(func(): _add_block(bid))
			palette_list.add_child(btn)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		palette_list.add_child(spacer)

func _cat_color(category: String) -> Color:
	match category:
		"config":    return Color(0.275, 0.663, 0.322, 1.0)
		"condition": return Color(0.482, 0.302, 0.686, 1.0)
		"action":    return Color(0.255, 0.463, 0.843, 1.0)
	return Color(0.5, 0.5, 0.5, 1.0)

func _refresh():
	var type_def := SimulationManager.get_type(_current_type_id)
	name_edit.text = type_def.name
	name_edit.add_theme_color_override("font_color", type_def.color)
	name_edit.add_theme_color_override("font_uneditable_color", type_def.color)
	color_picker.color = type_def.color
	_update_picker_swatch(type_def.color)
	delete_species_btn.visible = SimulationManager.robot_types.size() > 1
	for child in blocks_list.get_children():
		child.queue_free()
	var blocks: Array = SimulationManager.get_blocks(_current_type_id)
	for b in blocks:
		_spawn_block_widget(b.get("type", ""), b.get("params", {}))

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
	_spawn_block_widget(block_id, params)
	_save_blocks()

func _spawn_block_widget(btype: String, params: Dictionary):
	var block := SCRATCH_BLOCK.instantiate()
	blocks_list.add_child(block)
	block.setup(btype, params)
	block.block_changed.connect(func(): _save_blocks())
	block.block_deleted.connect(func():
		block.queue_free()
		await get_tree().process_frame
		_save_blocks()
	)
	block.drag_started.connect(_on_block_drag_started)

func _save_blocks():
	var blocks: Array = []
	for child in blocks_list.get_children():
		if child is PanelContainer and child.has_method("get_block_data"):
			blocks.append(child.get_block_data())
	SimulationManager.set_blocks(_current_type_id, blocks)

func _on_block_drag_started(block: PanelContainer):
	_drag_block = block
	_drag_index = block.get_index()

func _input(event: InputEvent):
	if _drag_block == null:
		return
	if event is InputEventMouseMotion:
		var mouse_y := blocks_list.get_local_mouse_position().y
		var new_index := _find_insert_index(mouse_y)
		if new_index != _drag_block.get_index():
			blocks_list.move_child(_drag_block, new_index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _drag_block.get_index() != _drag_index:
			_save_blocks()
		_drag_block = null
		_drag_index = -1

func _find_insert_index(mouse_y: float) -> int:
	var count := blocks_list.get_child_count()
	for i in count:
		var child: Control = blocks_list.get_child(i) as Control
		var mid: float = child.position.y + child.size.y * 0.5
		if mouse_y < mid:
			return i
	return count - 1

func _on_back():
	_save_blocks()
	get_tree().change_scene_to_file("res://levels/Arena.tscn")
