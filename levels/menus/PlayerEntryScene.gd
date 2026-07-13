extends Control

const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

const DETAIL_URL := "https://astroswarm.autonomousrobotics.club/api/evaluations/"
const API_KEY := "world-unfair-file"

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
var _algo_text: Label
var _xp_label: Label
var _claim_btn: Button
var _algo_title: Label

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

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 12)
	vbox.add_child(xp_row)

	_claim_btn = _make_btn("CLAIM XP")
	_claim_btn.visible = false
	_claim_btn.pressed.connect(_on_claim_pressed)
	xp_row.add_child(_claim_btn)

	_xp_label = _lbl("", 14, C_GREEN)
	_xp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(_xp_label)

	_algo_title = _lbl("ALGORITHM USED", 12, C_BLUE)
	vbox.add_child(_algo_title)

	var algo_scroll := ScrollContainer.new()
	algo_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	algo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(algo_scroll)

	var algo_panel := PanelContainer.new()
	algo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var algo_style := StyleBoxFlat.new()
	algo_style.bg_color = C_PANEL
	algo_style.border_color = C_BORDER
	algo_style.set_border_width_all(2)
	algo_style.content_margin_left = 14
	algo_style.content_margin_right = 14
	algo_style.content_margin_top = 12
	algo_style.content_margin_bottom = 12
	algo_panel.add_theme_stylebox_override("panel", algo_style)
	algo_scroll.add_child(algo_panel)

	_algo_text = _lbl("", 13, C_TEXT)
	_algo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	algo_panel.add_child(_algo_text)

	var back := _make_btn("← BACK TO ENTRIES")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerEntriesScene.tscn"))
	vbox.add_child(back)

func _fill_from_summary():
	_title_label.text = str(entry_summary.get("username", "Entry"))
	var status: String = str(entry_summary.get("status", ""))
	_status_label.text = status.to_upper()
	_status_label.add_theme_color_override("font_color", _status_color(status))
	var level_id: String = str(entry_summary.get("level_id", "farp"))
	_meta_label.text = "%s  ·  %s" % [_level_name(level_id), _date(str(entry_summary.get("created_at", "")))]
	if _is_pilot(level_id):
		_algo_title.text = "OPPONENT ALGORITHM"
		_set_stat_cards([["RESULT", "-"]])
	else:
		_set_stat_cards([
			["CAPTURE RATE", _rate_text(entry_summary.get("success_rate", null))],
			["TRIALS", str(entry_summary.get("trials", "-"))],
		])

func _level_number(level_id: String) -> int:
	var digits: String = ""
	for ch in level_id:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 1
	return int(digits)

func _is_pilot(level_id: String) -> bool:
	return _level_number(level_id) == 3

func _level_name(level_id: String) -> String:
	match _level_number(level_id):
		2: return "LEVEL 2 - DEFENSE"
		3: return "LEVEL 3 - PILOT"
	return "LEVEL 1 - DEFENSE"

func _time_text(value) -> String:
	if value == null or float(value) < 0.0:
		return "never"
	return "%.2fs" % float(value)

func _first(values, fallback = null):
	if typeof(values) == TYPE_ARRAY and not values.is_empty():
		return values[0]
	return fallback

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

	_algo_text.text = _algorithm_to_text(data.get("algorithm", []))
	_update_xp_ui(status, data.get("xp_awarded", null))

	var level_id: String = str(data.get("level_id", "farp"))
	var pilot: bool = _is_pilot(level_id)
	var placements: Array = data.get("placements", [])
	var trials = data.get("trials", entry_summary.get("trials", "-"))
	var when: String = _date(str(data.get("completed_at", data.get("created_at", ""))))
	if pilot:
		_algo_title.text = "OPPONENT ALGORITHM"
		_meta_label.text = "%s  ·  %d defenders  ·  %s" % [_level_name(level_id), placements.size(), when]
	else:
		_meta_label.text = "%s  ·  %d defenders  ·  %s trials  ·  %s" % [_level_name(level_id), placements.size(), str(trials), when]

	var results = data.get("results", {})
	var outcomes: Array = []
	var rate = entry_summary.get("success_rate", null)
	if typeof(results) == TYPE_DICTIONARY:
		outcomes = results.get("outcomes", [])
		rate = results.get("success_rate", rate)

	if outcomes.is_empty():
		if pilot:
			_set_stat_cards([["RESULT", "-"], ["DEFENDERS", str(placements.size())]])
			_detail_status.text = "Run is being rendered. Stats appear when it finishes." if status in ["queued", "running"] else "No run data for this entry yet."
		else:
			_set_stat_cards([
				["CAPTURE RATE", _rate_text(rate)],
				["TRIALS", str(trials)],
				["DEFENDERS", str(placements.size())],
			])
			_detail_status.text = "Benchmark still running. Stats appear when it finishes." if status in ["queued", "running"] else "No benchmark data for this entry yet."
		return

	if pilot:
		_set_stat_cards([
			["RESULT", _pilot_result_text(_first(outcomes, "timeout"))],
			["DETECTED", _time_text(_first(results.get("detection_times", [])))],
			["CAPTURED", _time_text(_first(results.get("capture_times", [])))],
			["REACHED PLANET", _time_text(_first(results.get("goal_times", [])))],
			["DEFENDERS", str(placements.size())],
		])
		_detail_status.text = "Entry ID: %s" % entry_id
		return

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

	_set_stat_cards([
		["CAPTURE RATE", _rate_text(rate)],
		["DETECTION RATE", _rate_text(results.get("detection_rate", null))],
		["CAPTURES", str(wins)],
		["PLANET HITS", str(losses)],
		["TIMEOUTS", str(timeouts)],
		["DEFENDERS", str(placements.size())],
		["TRIALS", str(trials)],
	])
	_detail_status.text = "Entry ID: %s" % entry_id

func _pilot_result_text(outcome) -> String:
	match str(outcome):
		"win":  return "PLANET REACHED"
		"lose": return "CAUGHT"
	return "OUT OF TIME"

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

func _update_xp_ui(status: String, xp_awarded):
	if status != "done":
		_claim_btn.visible = false
		_xp_label.text = "XP can be claimed once the entry finishes processing." if status in ["queued", "running"] else ""
		return
	if xp_awarded == null:
		_claim_btn.visible = true
		_claim_btn.disabled = false
		_claim_btn.text = "CLAIM XP"
		_xp_label.text = ""
	else:
		_claim_btn.visible = false
		_xp_label.text = "XP claimed: %d" % int(xp_awarded)

func _on_claim_pressed():
	_claim_btn.disabled = true
	_claim_btn.text = "CLAIMING..."
	_xp_label.text = ""
	if not EvalUploader.xp_claimed.is_connected(_on_claim_finished):
		EvalUploader.xp_claimed.connect(_on_claim_finished)
	EvalUploader.claim_xp(entry_id)

func _on_claim_finished(claimed_id: String, success: bool, xp: int, message: String):
	if claimed_id != entry_id:
		return
	if not success:
		_claim_btn.disabled = false
		_claim_btn.text = "CLAIM XP - RETRY"
		_xp_label.add_theme_color_override("font_color", C_RED)
		_xp_label.text = message
		return
	_claim_btn.visible = false
	_xp_label.add_theme_color_override("font_color", C_GREEN)
	_xp_label.text = "XP awarded: %d" % xp

func _algorithm_to_text(scripts) -> String:
	if typeof(scripts) != TYPE_ARRAY or scripts.is_empty():
		return "(no algorithm data)"
	var lines: Array = []
	for s in scripts:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		_blocks_to_lines(s.get("blocks", []), 0, lines)
		lines.append("")
	var text: String = "\n".join(lines).strip_edges()
	return text if text != "" else "(no algorithm data)"

func _blocks_to_lines(blocks, depth: int, lines: Array):
	if typeof(blocks) != TYPE_ARRAY:
		return
	for b in blocks:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		lines.append("    ".repeat(depth) + _block_label(str(b.get("type", "")), b.get("params", {})))
		_blocks_to_lines(b.get("children", []), depth + 1, lines)

func _block_label(block_type: String, params) -> String:
	var def: Dictionary = SimulationManager.BLOCK_DEFS.get(block_type, {})
	var label: String = str(def.get("label", block_type))
	if params is Dictionary:
		for key in ["value", "min", "max", "target", "var", "op"]:
			if params.has(key):
				label += " " + str(params[key])
	return label

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

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	return b
