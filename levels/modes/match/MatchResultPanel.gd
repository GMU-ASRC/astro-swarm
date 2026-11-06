extends Control

signal leave_requested()

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

const C_PANEL := Color(0.129, 0.122, 0.196, 1.0)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_GREEN := Color(0.40, 0.85, 0.45, 1.0)
const C_RED := Color(1.0, 0.42, 0.32, 1.0)

const STAT_ROWS := [
	["Planet health", "hp"],
	["Astrodust collected", "collected"],
	["Ships built", "built"],
	["Planet damage dealt", "damage"],
	["Ships destroyed", "kills"],
]

var _title: Label
var _headline: Label
var _grid: GridContainer

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_title = _label("", 26, C_TEXT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_headline = _label("", 11, C_DIM)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_headline)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(_grid)
	var leave_button := HUD_BUTTONS.make("BACK TO LOBBY", HUD_BUTTONS.Kind.PRIMARY, 12)
	leave_button.pressed.connect(func(): leave_requested.emit())
	column.add_child(leave_button)

func show_result(result: Dictionary, local_slot: int):
	var winner: int = int(result.get("winner", -1))
	if winner < 0:
		_title.text = "DRAW"
		_title.add_theme_color_override("font_color", C_TEXT)
	elif winner == local_slot:
		_title.text = "VICTORY"
		_title.add_theme_color_override("font_color", C_GREEN)
	else:
		_title.text = "DEFEAT"
		_title.add_theme_color_override("font_color", C_RED)
	_headline.text = _headline_text(result, winner)
	_fill_grid(result.get("players", []))
	visible = true

func _headline_text(result: Dictionary, winner: int) -> String:
	match str(result.get("reason", "")):
		"planet":
			return "A planet was destroyed."
		"time":
			return "Time ran out. The planet with more health wins." if winner >= 0 else "Time ran out with both planets level."
		"left":
			return "Your opponent left the match."
	return ""

func _fill_grid(players: Array):
	for child in _grid.get_children():
		child.queue_free()
	if players.size() < 2:
		return
	_grid.add_child(_label("", 10, C_DIM))
	for slot in 2:
		_grid.add_child(_label(str(players[slot].get("name", "")).to_upper(), 11, MATCH_CONFIG.PLAYER_COLORS[slot]))
	for stat in STAT_ROWS:
		_grid.add_child(_label(stat[0], 10, C_DIM))
		for slot in 2:
			_grid.add_child(_label(str(int(round(float(players[slot].get(stat[1], 0))))), 10, C_TEXT))

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
