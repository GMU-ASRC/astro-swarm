extends PanelContainer

signal item_pressed(item_id: String)
signal close_pressed()

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")

const PANEL_WIDTH := 420.0
const C_PANEL := Color(0.129, 0.122, 0.196, 0.97)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_DUST := Color(0.78, 0.55, 1.0, 1.0)

var title_text: String = "SHOP"

var _rows_box: VBoxContainer
var _title_label: Label
var _buttons: Dictionary = {}
var _cost_labels: Dictionary = {}
var _level_labels: Dictionary = {}

func _ready():
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title_label = _label(title_text, 16, C_TEXT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	var close_button := HUD_BUTTONS.make("X", HUD_BUTTONS.Kind.BACK, 10)
	close_button.pressed.connect(func(): close_pressed.emit())
	header.add_child(close_button)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 8)
	column.add_child(_rows_box)

func build_rows(rows: Array):
	for child in _rows_box.get_children():
		child.queue_free()
	_buttons.clear()
	_cost_labels.clear()
	_level_labels.clear()
	for row in rows:
		_rows_box.add_child(_make_row(row))

func refresh(rows: Array, dust: int):
	for row in rows:
		var item_id: String = row["id"]
		if not _buttons.has(item_id):
			continue
		var cost: int = int(row["cost"])
		var button: Button = _buttons[item_id]
		button.disabled = cost < 0 or cost > dust or bool(row.get("locked", false))
		button.text = "MAX" if cost < 0 else "BUY"
		_cost_labels[item_id].text = "" if cost < 0 else "%d DUST" % cost
		_level_labels[item_id].text = str(row.get("detail", ""))

func _make_row(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text_column)
	var name_row := HBoxContainer.new()
	text_column.add_child(name_row)
	name_row.add_child(_label(str(row["title"]).to_upper(), 12, C_TEXT))
	var level_label := _label("", 9, C_DIM)
	name_row.add_child(level_label)
	var description := _label(str(row["text"]), 9, C_DIM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_column.add_child(description)
	var cost_label := _label("", 10, C_DUST)
	cost_label.custom_minimum_size = Vector2(70, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(cost_label)
	var item_id: String = row["id"]
	var button := HUD_BUTTONS.make("BUY", HUD_BUTTONS.Kind.PRIMARY, 10)
	button.custom_minimum_size = Vector2(64, 0)
	button.pressed.connect(func(): item_pressed.emit(item_id))
	line.add_child(button)
	_buttons[item_id] = button
	_cost_labels[item_id] = cost_label
	_level_labels[item_id] = level_label
	return line

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
