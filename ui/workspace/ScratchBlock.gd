extends PanelContainer

signal block_changed
signal block_deleted

var block_type: String = ""
var block_params: Dictionary = {}

var _category: String = ""
var _palette: bool = false

const CAT_COLORS := {
	"config":    Color(0.275, 0.663, 0.322, 1.0),
	"condition": Color(0.482, 0.302, 0.686, 1.0),
	"logic":     Color(0.851, 0.522, 0.200, 1.0),
	"variable":  Color(0.200, 0.620, 0.600, 1.0),
	"action":    Color(0.255, 0.463, 0.843, 1.0),
}

const CAT_DARK := {
	"config":    Color(0.208, 0.518, 0.247, 1.0),
	"condition": Color(0.361, 0.216, 0.541, 1.0),
	"logic":     Color(0.682, 0.408, 0.137, 1.0),
	"variable":  Color(0.133, 0.451, 0.435, 1.0),
	"action":    Color(0.180, 0.345, 0.682, 1.0),
}

@onready var label_node: Label = $Outer/HBox/LabelText
@onready var inputs_box: HBoxContainer = $Outer/HBox/InputsBox
@onready var delete_btn: Button = $Outer/HBox/DeleteButton
@onready var drag_handle: Label = $Outer/HBox/DragHandle
@onready var inner_wrap: MarginContainer = $Outer/InnerWrap
@onready var inner_panel: PanelContainer = $Outer/InnerWrap/InnerPanel
@onready var children_zone: VBoxContainer = $Outer/InnerWrap/InnerPanel/Children

func _ready():
	delete_btn.pressed.connect(func(): block_deleted.emit())
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_apply_block_def()

func setup(btype: String, params: Dictionary):
	block_type = btype
	block_params = params.duplicate()
	if is_inside_tree():
		_apply_block_def()

func setup_preview(btype: String):
	_palette = true
	setup(btype, {})
	delete_btn.visible = false
	_ignore_mouse_tree(self)

func _ignore_mouse_tree(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse_tree(c)

func is_container() -> bool:
	return block_type.begins_with("when_") or block_type.begins_with("if_") or block_type == "else"

func get_children_zone() -> VBoxContainer:
	return children_zone

func _apply_block_def():
	if block_type == "":
		return
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_type, {})
	_category = def.get("category", "action")
	_apply_style()
	label_node.text = def.get("label", block_type)
	inner_wrap.visible = is_container()
	_build_inputs(def)

func _build_inputs(def: Dictionary):
	for c in inputs_box.get_children():
		c.queue_free()
	for spec in _input_specs(def):
		_add_input_widget(spec)

func _input_specs(def: Dictionary) -> Array:
	if def.has("inputs"):
		return def.inputs
	var single = def.get("input", null)
	if single == null or not (single is Dictionary):
		return []
	var spec: Dictionary = single.duplicate()
	if not spec.has("key"):
		spec["key"] = "value"
	if not spec.has("type"):
		spec["type"] = "slider"
	return [spec]

func _add_input_widget(spec: Dictionary):
	match spec.get("type", "slider"):
		"label":
			var lbl := Label.new()
			lbl.text = spec.get("text", "")
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.size_flags_vertical = SIZE_SHRINK_CENTER
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inputs_box.add_child(lbl)
		"slider":
			_add_slider(spec)
		"species":
			_add_dropdown(spec, SimulationManager.dropdown_options("species"))
		"dropdown":
			_add_dropdown(spec, SimulationManager.dropdown_options(spec.get("provider", "")))
		"number":
			_add_number(spec)
		"text":
			_add_text(spec)

func _add_dropdown(spec: Dictionary, options: Array):
	var key: String = spec.get("key", "value")
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_vertical = SIZE_SHRINK_CENTER
	_style_dropdown(opt)
	if options.is_empty():
		opt.add_item("(none)")
		opt.disabled = true
		inputs_box.add_child(opt)
		return
	var current = block_params.get(key, spec.get("default", options[0].value))
	var sel := 0
	for i in options.size():
		opt.add_item(options[i].text, i)
		if str(options[i].value) == str(current):
			sel = i
	opt.select(sel)
	block_params[key] = options[sel].value
	opt.item_selected.connect(func(idx):
		if idx >= 0 and idx < options.size():
			block_params[key] = options[idx].value
			block_changed.emit()
	)
	inputs_box.add_child(opt)

func _add_number(spec: Dictionary):
	var key: String = spec.get("key", "value")
	var box := SpinBox.new()
	box.min_value = spec.get("min", 0.0)
	box.max_value = spec.get("max", 100.0)
	box.step = spec.get("step", 1.0)
	box.size_flags_vertical = SIZE_SHRINK_CENTER
	box.custom_minimum_size = Vector2(70, 0)
	box.value = float(block_params.get(key, spec.get("default", 0.0)))
	block_params[key] = box.value
	_style_spinbox(box)
	box.value_changed.connect(func(v):
		block_params[key] = v
		block_changed.emit()
	)
	inputs_box.add_child(box)

func _add_text(spec: Dictionary):
	var key: String = spec.get("key", "value")
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(90, 0)
	edit.size_flags_vertical = SIZE_SHRINK_CENTER
	edit.text = str(block_params.get(key, spec.get("default", "")))
	block_params[key] = edit.text
	edit.text_changed.connect(func(t):
		block_params[key] = t
		block_changed.emit()
	)
	inputs_box.add_child(edit)

func _add_slider(spec: Dictionary):
	var key: String = spec.get("key", "value")
	var suffix: String = spec.get("suffix", "")
	var step: float = spec.get("step", 1.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	slider.min_value = spec.get("min", 0.0)
	slider.max_value = spec.get("max", 100.0)
	slider.step = step
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slider.grab_focus()
	)
	var vlabel := Label.new()
	vlabel.custom_minimum_size = Vector2(64, 0)
	vlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vlabel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vlabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vlabel.add_theme_font_size_override("font_size", 12)
	var val: float = float(block_params.get(key, spec.get("default", 0.0)))
	slider.value = val
	block_params[key] = slider.value
	_update_slider_label(vlabel, slider.value, suffix, step)
	slider.value_changed.connect(func(v):
		block_params[key] = v
		_update_slider_label(vlabel, v, suffix, step)
		block_changed.emit()
	)
	row.add_child(slider)
	row.add_child(vlabel)
	inputs_box.add_child(row)

func _update_slider_label(lbl: Label, val: float, suffix: String, step: float):
	if step >= 1.0:
		lbl.text = "%d%s" % [int(val), suffix]
	else:
		lbl.text = "%.1f%s" % [val, suffix]

func _style_dropdown(opt: OptionButton):
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	opt.add_theme_stylebox_override("normal", sb)
	opt.add_theme_stylebox_override("hover", sb)
	opt.add_theme_stylebox_override("pressed", sb)
	opt.add_theme_stylebox_override("focus", sb)
	opt.add_theme_stylebox_override("disabled", sb)
	opt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	opt.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	opt.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	opt.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	opt.add_theme_font_size_override("font_size", 12)

func _style_spinbox(box: SpinBox):
	var line := box.get_line_edit()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	line.add_theme_stylebox_override("normal", sb)
	line.add_theme_stylebox_override("focus", sb)
	line.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	line.add_theme_font_size_override("font_size", 12)

func _apply_style():
	var cat_color: Color = CAT_COLORS.get(_category, CAT_COLORS.action)
	var dark_color: Color = CAT_DARK.get(_category, CAT_DARK.action)

	var sb := StyleBoxFlat.new()
	sb.bg_color = cat_color
	sb.set_corner_radius_all(6)
	sb.border_width_left = 4
	sb.border_color = dark_color
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var sb_inner := StyleBoxFlat.new()
	sb_inner.bg_color = Color(0, 0, 0, 0.18)
	sb_inner.set_corner_radius_all(4)
	sb_inner.content_margin_left = 6
	sb_inner.content_margin_right = 6
	sb_inner.content_margin_top = 6
	sb_inner.content_margin_bottom = 6
	inner_panel.add_theme_stylebox_override("panel", sb_inner)

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

func get_block_data() -> Dictionary:
	var child_blocks: Array = []
	if is_container():
		for c in children_zone.get_children():
			if c is PanelContainer and c.has_method("get_block_data"):
				child_blocks.append(c.get_block_data())
	return {"type": block_type, "params": block_params.duplicate(), "children": child_blocks}

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _palette:
		return null
	var preview := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CAT_COLORS.get(_category, CAT_COLORS.action)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	preview.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = label_node.text
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	preview.add_child(lbl)
	preview.modulate.a = 0.75
	set_drag_preview(preview)
	return {"blocks": [self]}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var zone = _target_zone()
	return zone != null and zone.can_accept(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var zone = _target_zone()
	if zone != null:
		zone.do_drop(data)

func _target_zone():
	if is_container():
		return children_zone
	var p := get_parent()
	if p != null and p.has_method("do_drop"):
		return p
	return null
