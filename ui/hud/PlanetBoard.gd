extends PanelContainer

# One row per planet: a pip for every evader that planet faces, plus a status
# line. A pip turns red the moment an evader lands on that planet and green
# when one is stopped, so both planets can be read at a glance from either
# scene.
const PIP_SIZE      := Vector2(9, 9)
const FLASH_SECONDS := 1.2
const HERE_MARKER   := "> "
const AWAY_MARKER   := "  "

var label_font: Font = null
var text_color       := Color(0.93, 0.94, 1.0, 1.0)
var dim_color        := Color(0.6, 0.62, 0.74, 1.0)
var pip_idle_color   := Color(0.28, 0.27, 0.38, 1.0)
var stopped_color    := Color(0.40, 0.85, 0.45, 1.0)
var breach_color     := Color(1.0, 0.42, 0.32, 1.0)
var border_color     := Color(0.318, 0.306, 0.463, 1.0)
var background_color := Color(0.129, 0.122, 0.196, 0.88)

var _rows: Array = []
var _flash: Array = []

func build(planet_names: Array, pips_per_planet: int):
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	add_child(box)

	box.add_child(_make_label("EVADERS THROUGH", dim_color))

	var separator := ColorRect.new()
	separator.color = border_color
	separator.custom_minimum_size = Vector2(0, 1)
	box.add_child(separator)

	for planet_name in planet_names:
		_rows.append(_add_row(box, planet_name, pips_per_planet))
		_flash.append(0.0)

func set_planet(index: int, here: bool, destroyed: int, breached: int, status: String):
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	row["name"].text = (HERE_MARKER if here else AWAY_MARKER) + str(row["title"])
	row["name"].add_theme_color_override("font_color", text_color if here else dim_color)
	row["status"].text = status
	var pips: Array = row["pips"]
	for i in pips.size():
		if i < breached:
			pips[i].color = breach_color
		elif i < breached + destroyed:
			pips[i].color = stopped_color
		else:
			pips[i].color = pip_idle_color

func flash(index: int):
	if index >= 0 and index < _flash.size():
		_flash[index] = FLASH_SECONDS

func _process(delta: float):
	for i in _flash.size():
		if _flash[i] <= 0.0:
			continue
		_flash[i] = maxf(0.0, _flash[i] - delta)
		var strength: float = _flash[i] / FLASH_SECONDS
		var label: Label = _rows[i]["status"]
		label.add_theme_color_override("font_color", dim_color.lerp(breach_color, strength))

func _add_row(box: VBoxContainer, title: String, pip_count: int) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var name_label := _make_label(AWAY_MARKER + title, dim_color)
	name_label.custom_minimum_size = Vector2(76, 0)
	row.add_child(name_label)

	var pip_box := HBoxContainer.new()
	pip_box.add_theme_constant_override("separation", 3)
	pip_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(pip_box)

	var pips: Array = []
	for _i in pip_count:
		var pip := ColorRect.new()
		pip.color = pip_idle_color
		pip.custom_minimum_size = PIP_SIZE
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip_box.add_child(pip)
		pips.append(pip)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var status := _make_label("", dim_color)
	row.add_child(status)

	return {"title": title, "name": name_label, "pips": pips, "status": status}

func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	if label_font != null:
		label.add_theme_font_override("font", label_font)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", color)
	return label
