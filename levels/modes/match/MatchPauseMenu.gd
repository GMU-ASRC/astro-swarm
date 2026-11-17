extends Control

signal resume_requested()
signal tutorial_requested()
signal forfeit_requested()
signal leave_requested()

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")

const C_PANEL := Color(0.129, 0.122, 0.196, 1.0)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const CARD_WIDTH := 340.0

var _subtitle: Label
var _forfeit_button: Button
var _confirming_forfeit: bool = false

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var title := _label("PAUSED", 24, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_subtitle = _label("", 10, C_DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	_add_button(column, "RESUME", HUD_BUTTONS.Kind.PRIMARY, func(): resume_requested.emit())
	_add_button(column, "HOW TO PLAY", HUD_BUTTONS.Kind.NEUTRAL, func(): tutorial_requested.emit())
	_forfeit_button = _add_button(column, "FORFEIT", HUD_BUTTONS.Kind.NEUTRAL, _on_forfeit_pressed)
	_add_button(column, "LEAVE MATCH", HUD_BUTTONS.Kind.BACK, func(): leave_requested.emit())

func show_paused(paused_by: String):
	_subtitle.text = "Paused by %s. Both players see this menu." % paused_by.to_upper()
	if not visible:
		_reset_forfeit()
	visible = true

func hide_menu():
	visible = false
	_reset_forfeit()

func _on_forfeit_pressed():
	if _confirming_forfeit:
		forfeit_requested.emit()
		return
	_confirming_forfeit = true
	_forfeit_button.text = "PRESS AGAIN TO FORFEIT"

func _reset_forfeit():
	_confirming_forfeit = false
	if _forfeit_button != null:
		_forfeit_button.text = "FORFEIT"

func _add_button(column: VBoxContainer, text: String, kind: int, handler: Callable) -> Button:
	var button := HUD_BUTTONS.make(text, kind, 12)
	button.pressed.connect(handler)
	column.add_child(button)
	return button

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
