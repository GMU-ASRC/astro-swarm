extends RefCounted

const SLOT_COLOR := Color(0, 0, 0, 0.25)
const TEXT_COLOR := Color(1, 1, 1, 1)
const FONT_SIZE := 12

static func build(block, inputs_box: HBoxContainer, def: Dictionary):
	for c in inputs_box.get_children():
		c.queue_free()
	for spec in input_specs(def):
		_add_input_widget(block, inputs_box, spec)

static func input_specs(def: Dictionary) -> Array:
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

static func _add_input_widget(block, inputs_box: HBoxContainer, spec: Dictionary):
	match spec.get("type", "slider"):
		"label":
			inputs_box.add_child(_make_label(spec.get("text", "")))
		"slider":
			inputs_box.add_child(_make_slider(block, spec))
		"species":
			inputs_box.add_child(_make_dropdown(block, spec, SimulationManager.dropdown_options("species")))
		"dropdown":
			inputs_box.add_child(_make_dropdown(block, spec, SimulationManager.dropdown_options(spec.get("provider", ""))))
		"number":
			inputs_box.add_child(_make_number(block, spec))
		"text":
			inputs_box.add_child(_make_text(block, spec))

static func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

static func _make_dropdown(block, spec: Dictionary, options: Array) -> OptionButton:
	var key: String = spec.get("key", "value")
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_dropdown(opt)
	if options.is_empty():
		opt.add_item("(none)")
		opt.disabled = true
		return opt
	var current = block.block_params.get(key, spec.get("default", options[0].value))
	var selected_index := 0
	for i in options.size():
		opt.add_item(options[i].text, i)
		if str(options[i].value) == str(current):
			selected_index = i
	opt.select(selected_index)
	block.block_params[key] = options[selected_index].value
	opt.item_selected.connect(func(idx):
		if idx >= 0 and idx < options.size():
			block.block_params[key] = options[idx].value
			block.block_changed.emit()
	)
	return opt

static func _make_number(block, spec: Dictionary) -> SpinBox:
	var key: String = spec.get("key", "value")
	var box := SpinBox.new()
	box.min_value = spec.get("min", 0.0)
	box.max_value = spec.get("max", 100.0)
	box.step = spec.get("step", 1.0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.custom_minimum_size = Vector2(70, 0)
	box.value = float(block.block_params.get(key, spec.get("default", 0.0)))
	block.block_params[key] = box.value
	_style_line_edit(box.get_line_edit())
	box.value_changed.connect(func(v):
		block.block_params[key] = v
		block.block_changed.emit()
	)
	return box

static func _make_text(block, spec: Dictionary) -> LineEdit:
	var key: String = spec.get("key", "value")
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(90, 0)
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.text = str(block.block_params.get(key, spec.get("default", "")))
	block.block_params[key] = edit.text
	_style_line_edit(edit)
	edit.text_changed.connect(func(t):
		block.block_params[key] = t
		block.block_changed.emit()
	)
	return edit

static func _make_slider(block, spec: Dictionary) -> HBoxContainer:
	var key: String = spec.get("key", "value")
	var suffix: String = spec.get("suffix", "")
	var step: float = spec.get("step", 1.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = spec.get("min", 0.0)
	slider.max_value = spec.get("max", 100.0)
	slider.step = step
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slider.grab_focus()
	)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.add_theme_color_override("font_color", TEXT_COLOR)
	value_label.add_theme_font_size_override("font_size", FONT_SIZE)
	slider.value = float(block.block_params.get(key, spec.get("default", 0.0)))
	block.block_params[key] = slider.value
	_update_slider_label(value_label, slider.value, suffix, step)
	slider.value_changed.connect(func(v):
		block.block_params[key] = v
		_update_slider_label(value_label, v, suffix, step)
		block.block_changed.emit()
	)
	row.add_child(slider)
	row.add_child(value_label)
	return row

static func _update_slider_label(lbl: Label, val: float, suffix: String, step: float):
	if step >= 1.0:
		lbl.text = "%d%s" % [int(val), suffix]
	else:
		lbl.text = "%.1f%s" % [val, suffix]

static func _slot_box(left: float, right: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SLOT_COLOR
	box.set_corner_radius_all(8)
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

static func _style_dropdown(opt: OptionButton):
	var box := _slot_box(10, 8)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		opt.add_theme_stylebox_override(state, box)
	opt.add_theme_color_override("font_color", TEXT_COLOR)
	opt.add_theme_color_override("font_hover_color", TEXT_COLOR)
	opt.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	opt.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	opt.add_theme_font_size_override("font_size", FONT_SIZE)

static func _style_line_edit(edit: LineEdit):
	var box := _slot_box(8, 8)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	edit.add_theme_color_override("font_color", TEXT_COLOR)
	edit.add_theme_font_size_override("font_size", FONT_SIZE)
