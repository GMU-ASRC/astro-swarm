extends Control

const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

const DETAIL_URL := "https://astroswarm.autonomousrobotics.club/api/evaluations/"
const API_KEY := "damage-option-ozone"

const C_BG     := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL  := Color(0.129, 0.122, 0.196, 1.0)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT   := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM    := Color(0.6, 0.62, 0.74, 1.0)
const C_BLUE   := Color(0.451, 0.616, 1.0, 1.0)
const C_GREEN  := Color(0.45, 0.85, 0.5, 1.0)
const C_RED    := Color(0.9, 0.45, 0.45, 1.0)

static var entry_id: String = ""
static var entry_summary: Dictionary = {}

var _title_label: Label
var _status_label: Label
var _meta_label: Label
var _stats_grid: GridContainer
var _detail_status: Label

func _ready():
	theme = GAME_THEME
	_build_ui()
	_fill_from_summary()
	if entry_id != "":
		_fetch_detail()

func _build_ui():
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)

	_title_label = _lbl("ENTRY", 28, C_TEXT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_status_label = _lbl("", 14, C_DIM)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_status_label)

	_meta_label = _lbl("", 12, C_DIM)
	vbox.add_child(_meta_label)

	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 14)
	_stats_grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(_stats_grid)

	_detail_status = _lbl("Loading details...", 12, C_DIM)
	vbox.add_child(_detail_status)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var back := _make_btn("← BACK TO ENTRIES")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerEntriesScene.tscn"))
	vbox.add_child(back)

func _fill_from_summary():
	_title_label.text = str(entry_summary.get("username", "Entry"))
	var status: String = str(entry_summary.get("status", ""))
	_status_label.text = status.to_upper()
	_status_label.add_theme_color_override("font_color", _status_color(status))
	var level_id: String = str(entry_summary.get("level_id", "farp"))
	_meta_label.text = "%s  ·  %s" % [level_id.to_upper(), _date(str(entry_summary.get("created_at", "")))]
	_set_stat_cards([
		["DETECTION RATE", _rate_text(entry_summary.get("success_rate", null))],
		["TRIALS", str(entry_summary.get("trials", "-"))],
	])

func _fetch_detail():
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(_on_detail_response.bind(req))
	if req.request(DETAIL_URL + entry_id, ["X-API-Key: " + API_KEY], HTTPClient.METHOD_GET) != OK:
		req.queue_free()
		_detail_status.text = "Could not reach the server."

func _on_detail_response(_result, code, _headers, body, req):
	req.queue_free()
	if code != 200:
		_detail_status.text = "Failed to load details (status %d)." % code
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_detail_status.text = "No details available."
		return
	_apply_detail(data)

func _apply_detail(data: Dictionary):
	var status: String = str(data.get("status", entry_summary.get("status", "")))
	_status_label.text = status.to_upper()
	_status_label.add_theme_color_override("font_color", _status_color(status))

	var level_id: String = str(data.get("level_id", "farp"))
	var placements: Array = data.get("placements", [])
	var trials = data.get("trials", entry_summary.get("trials", "-"))
	var when: String = _date(str(data.get("completed_at", data.get("created_at", ""))))
	_meta_label.text = "%s  ·  %d defenders  ·  %s trials  ·  %s" % [level_id.to_upper(), placements.size(), str(trials), when]

	var results = data.get("results", {})
	var outcomes: Array = []
	var rate = entry_summary.get("success_rate", null)
	if typeof(results) == TYPE_DICTIONARY:
		outcomes = results.get("outcomes", [])
		rate = results.get("success_rate", rate)

	var wins := 0
	var losses := 0
	var timeouts := 0
	for o in outcomes:
		if o == "win":
			wins += 1
		elif o == "lose":
			losses += 1
		else:
			timeouts += 1

	if outcomes.is_empty():
		_set_stat_cards([
			["DETECTION RATE", _rate_text(rate)],
			["TRIALS", str(trials)],
			["DEFENDERS", str(placements.size())],
		])
		if status == "queued" or status == "running":
			_detail_status.text = "Benchmark still running. Stats appear when it finishes."
		else:
			_detail_status.text = "No benchmark data for this entry yet."
		return

	_set_stat_cards([
		["DETECTION RATE", _rate_text(rate)],
		["INTERCEPTS", str(wins)],
		["PLANET HITS", str(losses)],
		["TIMEOUTS", str(timeouts)],
		["DEFENDERS", str(placements.size())],
		["TRIALS", str(trials)],
	])
	_detail_status.text = "Entry ID: %s" % entry_id

func _set_stat_cards(cards: Array):
	for child in _stats_grid.get_children():
		child.queue_free()
	for card in cards:
		_stats_grid.add_child(_make_stat_card(card[0], card[1]))

func _make_stat_card(label_text: String, value_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var l := _lbl(label_text, 10, C_DIM)
	vb.add_child(l)

	var v := _lbl(value_text, 20, C_TEXT)
	vb.add_child(v)
	return panel

func _rate_text(rate) -> String:
	if rate == null:
		return "-"
	return "%s%%" % str(rate)

func _status_color(status: String) -> Color:
	if status == "done":
		return C_GREEN
	if status == "failed" or status == "error":
		return C_RED
	return C_BLUE

func _date(iso: String) -> String:
	if iso.length() >= 10:
		return iso.substr(0, 10)
	return iso

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	return b
