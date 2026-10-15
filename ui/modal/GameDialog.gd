extends Control

signal confirmed(text: String)

const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")

const PANEL_WIDTH := 460.0
const PADDING := 26
const BUTTON_FONT_SIZE := 13
const C_DIM := Color(0.0, 0.0, 0.0, 0.65)
const C_PANEL := Color(0.13, 0.12, 0.2, 1.0)
const C_EDGE := Color(0.451, 0.616, 1.0, 1.0)
const C_DANGER_EDGE := Color(0.9, 0.45, 0.45, 1.0)
const C_TITLE := Color(0.93, 0.94, 1.0, 1.0)
const C_BODY := Color(0.6, 0.62, 0.74, 1.0)
const C_ERROR := Color(1.0, 0.55, 0.5, 1.0)

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _input: LineEdit
var _error_label: Label
var _confirm_btn: Button

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = C_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)

	_title_label = _label(22, C_TITLE)
	column.add_child(_title_label)
	_body_label = _label(13, C_BODY)
	column.add_child(_body_label)

	_input = LineEdit.new()
	_input.text_submitted.connect(func(_text): _submit())
	column.add_child(_input)

	_error_label = _label(12, C_ERROR)
	column.add_child(_error_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)

	var cancel_btn: Button = HUD_BUTTONS.make("CANCEL", HUD_BUTTONS.Kind.NEUTRAL, BUTTON_FONT_SIZE)
	cancel_btn.pressed.connect(close)
	buttons.add_child(cancel_btn)

	_confirm_btn = HUD_BUTTONS.make("", HUD_BUTTONS.Kind.PRIMARY, BUTTON_FONT_SIZE)
	_confirm_btn.pressed.connect(_submit)
	buttons.add_child(_confirm_btn)

func open(title: String, body: String, confirm_text: String, danger: bool = false, input_text = null, input_max_length: int = 24):
	_title_label.text = title.to_upper()
	_body_label.text = body
	_body_label.visible = body != ""
	_confirm_btn.text = confirm_text.to_upper()
	_confirm_btn.add_theme_color_override("font_color", C_ERROR if danger else C_TITLE)
	_panel.add_theme_stylebox_override("panel", _panel_style(C_DANGER_EDGE if danger else C_EDGE))
	_input.visible = input_text != null
	_input.max_length = input_max_length
	_input.text = str(input_text) if input_text != null else ""
	_error_label.visible = false
	visible = true
	if _input.visible:
		_input.grab_focus()
		_input.select_all()

func show_error(message: String):
	_error_label.text = message
	_error_label.visible = true
	if _input.visible:
		_input.grab_focus()
		_input.select_all()

func close():
	visible = false

func _submit():
	if visible:
		confirmed.emit(_input.text)

func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(PADDING)
	return style
