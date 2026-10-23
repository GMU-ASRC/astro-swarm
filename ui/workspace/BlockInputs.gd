extends RefCounted

const SHIP_UPGRADES := preload("res://progression/ShipUpgrades.gd")

const SLOT_COLOR := Color(0, 0, 0, 0.25)
const TEXT_COLOR := Color(1, 1, 1, 1)
const FONT_SIZE := 12
const FINE_STEP := 0.01
const DEFAULT_SLIDER_STEP := 1.0
const STEP_TOLERANCE := 0.0001

static func build(block, inputs_box: HBoxContainer, def: Dictionary):
	for c in inputs_box.get_children():
		c.queue_free()
	for spec in input_specs(def):
		_add_input_widget(block, inputs_box, spec)

static func build_compact(block, inputs_box: HBoxContainer, def: Dictionary):
	for c in inputs_box.get_children():
		c.queue_free()
	for spec in input_specs(def):
		if spec.get("type", "slider") == "label":
			inputs_box.add_child(_make_label(spec.get("text", "")))
		else:
			inputs_box.add_child(_make_chip(_compact_text(block, spec)))

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
			if spec.get("rebuilds_inputs", false):
				block.rebuild_inputs()
			block.block_changed.emit()
	)
	return opt

static func _make_number(block, spec: Dictionary) -> SpinBox:
	var key: String = spec.get("key", "value")
	var box := SpinBox.new()
	box.min_value = spec.get("min", 0.0)
	box.step = spec.get("step", 1.0)
	box.max_value = SHIP_UPGRADES.editor_max(block.block_type, spec.get("max", 100.0))
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
	var slider_step: float = spec.get("slider_step", DEFAULT_SLIDER_STEP)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = spec.get("min", 0.0)
	slider.max_value = _slider_max(block, spec)
	slider.step = 0.0
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slider.grab_focus()
		elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_left", true):
			var direction: float = 1.0 if event.is_action_pressed("ui_right", true) else -1.0
			slider.value = clampf(_next_slider_value(slider.value, slider_step, direction), slider.min_value, slider.max_value)
			slider.accept_event()
	)
	var value_input := LineEdit.new()
	value_input.custom_minimum_size = Vector2(56, 0)
	value_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_line_edit(value_input)
	var suffix_label := _make_label(suffix)
	suffix_label.add_theme_color_override("font_color", TEXT_COLOR)
	var stored_value: float = maxf(0.0, float(block.block_params.get(key, spec.get("default", 0.0))))
	slider.value = stored_value
	block.block_params[key] = stored_value if stored_value < slider.min_value else slider.value
	value_input.text = _format_value(float(block.block_params[key]))
	slider.value_changed.connect(func(v):
		var stepped_value: float = _step_slider_value(v, slider.min_value, slider.max_value, slider_step)
		slider.set_value_no_signal(stepped_value)
		block.block_params[key] = stepped_value
		value_input.text = _format_value(stepped_value)
		block.block_changed.emit()
	)
	var apply_typed_value := func():
		var typed_text: String = value_input.text.strip_edges()
		if typed_text.is_valid_float():
			var typed_value: float = snappedf(clampf(typed_text.to_float(), 0.0, slider.max_value), FINE_STEP)
			if typed_value != float(block.block_params[key]):
				block.block_params[key] = typed_value
				slider.set_value_no_signal(typed_value)
				block.block_changed.emit()
		value_input.text = _format_value(float(block.block_params[key]))
	value_input.text_submitted.connect(func(_text):
		apply_typed_value.call()
		value_input.release_focus()
	)
	value_input.focus_exited.connect(apply_typed_value)
	row.add_child(slider)
	row.add_child(value_input)
	if suffix != "":
		row.add_child(suffix_label)
	return row

static func _slider_max(block, spec: Dictionary) -> float:
	if spec.has("max_by_unit"):
		var unit: String = str(block.block_params.get(spec.get("unit_key", "unit"), "degrees"))
		return float(spec.max_by_unit.get(unit, spec.max_by_unit.values()[0]))
	return SHIP_UPGRADES.editor_max(block.block_type, spec.get("max", 100.0))

static func _step_slider_value(val: float, min_value: float, max_value: float, slider_step: float) -> float:
	if val <= min_value or val >= max_value:
		return val
	return clampf(snappedf(roundf(val / slider_step) * slider_step, FINE_STEP), min_value, max_value)

static func _next_slider_value(val: float, slider_step: float, direction: float) -> float:
	var steps_taken: float = val / slider_step
	if direction > 0.0:
		return snappedf((floorf(steps_taken + STEP_TOLERANCE) + 1.0) * slider_step, FINE_STEP)
	return snappedf((ceilf(steps_taken - STEP_TOLERANCE) - 1.0) * slider_step, FINE_STEP)

static func _format_value(val: float) -> String:
	return String.num(snappedf(val, FINE_STEP), 2)

static func _format_number(val: float, suffix: String) -> String:
	return _format_value(val) + suffix

static func _compact_text(block, spec: Dictionary) -> String:
	var value = block.block_params.get(spec.get("key", "value"), spec.get("default", null))
	match spec.get("type", "slider"):
		"slider", "number":
			return _format_number(float(value if value != null else 0.0), spec.get("suffix", ""))
		"species", "dropdown":
			var provider: String = "species" if spec.get("type") == "species" else spec.get("provider", "")
			var options: Array = SimulationManager.dropdown_options(provider)
			for option in options:
				if str(option.value) == str(value):
					return option.text
			return options[0].text if not options.is_empty() else "(none)"
	return str(value if value != null else "")

static func _make_chip(text: String) -> Label:
	var chip := _make_label(text)
	chip.add_theme_color_override("font_color", TEXT_COLOR)
	chip.add_theme_stylebox_override("normal", _slot_box(8, 8))
	return chip

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
