extends PanelContainer

signal block_changed
signal block_deleted
signal drag_started(block: PanelContainer)

var block_type: String = ""
var block_params: Dictionary = {}

var _category: String = ""
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

const CAT_COLORS := {
	"config":    Color(0.275, 0.663, 0.322, 1.0),
	"condition": Color(0.482, 0.302, 0.686, 1.0),
	"action":    Color(0.255, 0.463, 0.843, 1.0),
}

const CAT_DARK := {
	"config":    Color(0.208, 0.518, 0.247, 1.0),
	"condition": Color(0.361, 0.216, 0.541, 1.0),
	"action":    Color(0.180, 0.345, 0.682, 1.0),
}

@onready var label_node: Label = $HBox/LabelText
@onready var slider_node: HSlider = $HBox/SliderBox/Slider
@onready var value_label: Label = $HBox/SliderBox/ValueLabel
@onready var slider_box: HBoxContainer = $HBox/SliderBox
@onready var species_select: OptionButton = $HBox/SpeciesSelect
@onready var delete_btn: Button = $HBox/DeleteButton
@onready var drag_handle: Label = $HBox/DragHandle

var _input_def = null
var _input_type: String = "slider"
var _suffix: String = ""

func _ready():
	delete_btn.pressed.connect(func(): block_deleted.emit())
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_apply_block_def()

func setup(btype: String, params: Dictionary):
	block_type = btype
	block_params = params.duplicate()
	if is_inside_tree():
		_apply_block_def()

func _apply_block_def():
	if block_type == "":
		return
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_type, {})
	_category = def.get("category", "action")
	_input_def = def.get("input", null)
	var lbl_text: String = def.get("label", block_type)

	_input_type = "none"
	if _input_def != null and _input_def is Dictionary:
		_input_type = _input_def.get("type", "slider")

	_apply_style()
	label_node.text = lbl_text

	match _input_type:
		"slider":
			slider_box.visible = true
			species_select.visible = false
			_suffix = _input_def.get("suffix", "")
			slider_node.min_value = _input_def.get("min", 0.0)
			slider_node.max_value = _input_def.get("max", 100.0)
			slider_node.step = _input_def.get("step", 1.0)
			var val: float = block_params.get("value", _input_def.get("default", 0.0))
			slider_node.value = val
			_update_value_label(val)
			if not slider_node.value_changed.is_connected(_on_slider_changed):
				slider_node.value_changed.connect(_on_slider_changed)
		"species":
			slider_box.visible = false
			species_select.visible = true
			_populate_species_dropdown()
			if not species_select.item_selected.is_connected(_on_species_selected):
				species_select.item_selected.connect(_on_species_selected)
		_:
			slider_box.visible = false
			species_select.visible = false

func _populate_species_dropdown():
	species_select.clear()
	var current_val: String = block_params.get("value", _input_def.get("default", ""))
	var select_idx: int = 0
	for i in SimulationManager.robot_types.size():
		var t: Dictionary = SimulationManager.robot_types[i]
		species_select.add_item(t.name, i)
		if t.id == current_val:
			select_idx = i
	species_select.select(select_idx)
	var sb_opt := StyleBoxFlat.new()
	sb_opt.bg_color = Color(0, 0, 0, 0.2)
	sb_opt.set_corner_radius_all(4)
	sb_opt.content_margin_left = 8
	sb_opt.content_margin_right = 8
	sb_opt.content_margin_top = 3
	sb_opt.content_margin_bottom = 3
	species_select.add_theme_stylebox_override("normal", sb_opt)
	species_select.add_theme_stylebox_override("hover", sb_opt)
	species_select.add_theme_stylebox_override("pressed", sb_opt)
	species_select.add_theme_stylebox_override("focus", sb_opt)
	species_select.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	species_select.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	species_select.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	species_select.add_theme_font_size_override("font_size", 12)

func _apply_style():
	var cat_color: Color = CAT_COLORS.get(_category, CAT_COLORS.action)
	var dark_color: Color = CAT_DARK.get(_category, CAT_DARK.action)

	var sb := StyleBoxFlat.new()
	sb.bg_color = cat_color
	sb.set_corner_radius_all(6)
	sb.border_width_left = 4
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.border_color = dark_color
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	label_node.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label_node.add_theme_font_size_override("font_size", 13)

	delete_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	delete_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))
	var sb_del := StyleBoxFlat.new()
	sb_del.bg_color = Color(0, 0, 0, 0)
	sb_del.set_corner_radius_all(3)
	sb_del.content_margin_left = 4
	sb_del.content_margin_right = 4
	sb_del.content_margin_top = 2
	sb_del.content_margin_bottom = 2
	delete_btn.add_theme_stylebox_override("normal", sb_del)
	var sb_del_h := StyleBoxFlat.new()
	sb_del_h.bg_color = Color(0, 0, 0, 0.15)
	sb_del_h.set_corner_radius_all(3)
	sb_del_h.content_margin_left = 4
	sb_del_h.content_margin_right = 4
	sb_del_h.content_margin_top = 2
	sb_del_h.content_margin_bottom = 2
	delete_btn.add_theme_stylebox_override("hover", sb_del_h)
	delete_btn.add_theme_stylebox_override("pressed", sb_del_h)
	delete_btn.add_theme_stylebox_override("focus", sb_del)

	drag_handle.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))

	if _input_type == "slider":
		value_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		value_label.add_theme_font_size_override("font_size", 12)

func _on_slider_changed(val: float):
	block_params["value"] = val
	_update_value_label(val)
	block_changed.emit()

func _on_species_selected(idx: int):
	if idx >= 0 and idx < SimulationManager.robot_types.size():
		block_params["value"] = SimulationManager.robot_types[idx].id
		block_changed.emit()

func _update_value_label(val: float):
	var step: float = 1.0
	if _input_def != null and _input_def is Dictionary:
		step = _input_def.get("step", 1.0)
	if step >= 1.0:
		value_label.text = "%d%s" % [int(val), _suffix]
	else:
		value_label.text = "%.1f%s" % [val, _suffix]

func get_block_data() -> Dictionary:
	return {"type": block_type, "params": block_params.duplicate()}

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = event.position
			drag_started.emit(self)
		else:
			_dragging = false
