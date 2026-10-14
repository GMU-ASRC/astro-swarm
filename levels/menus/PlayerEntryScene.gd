extends Control

const GAME_THEME := preload("res://ui/GameTheme.tres")
const STYLE := preload("res://levels/menus/EntryStyle.gd")

const DETAIL_PATH := "/api/evaluations/"
const API_KEY := "world-unfair-file"

static var entry_id: String = ""
static var entry_summary: Dictionary = {}

var _title_label: Label
var _status_badge_slot: HBoxContainer
var _meta_label: Label
var _headline_value: Label
var _headline_caption: Label
var _headline_breakdown: Label
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
	add_child(STYLE.make_background())
	var margin := STYLE.make_page_margin()
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	scroll.add_child(page)

	_build_header(page)
	_build_headline(page)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 12)
	_stats_grid.add_theme_constant_override("v_separation", 12)
	page.add_child(_stats_grid)

	_detail_status = STYLE.make_label("Loading details...", 11, STYLE.C_FAINT)
	page.add_child(_detail_status)

	_build_xp_row(page)
	_build_algorithm_panel(page)

func _build_header(page: VBoxContainer):
	var back := STYLE.make_button("< BACK TO ENTRIES")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerEntriesScene.tscn"))
	page.add_child(back)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)

	_title_label = STYLE.make_label("ENTRY", 28, STYLE.C_TEXT)
	header.add_child(_title_label)

	_status_badge_slot = HBoxContainer.new()
	_status_badge_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_badge_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_status_badge_slot)

	var website_button := STYLE.make_website_button("OPEN ON WEBSITE", STYLE.entry_page_url(entry_id))
	website_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(website_button)

	_meta_label = STYLE.make_label("", 12, STYLE.C_DIM)
	page.add_child(_meta_label)

func _build_headline(page: VBoxContainer):
	var card := STYLE.make_card(20)
	page.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	_headline_value = STYLE.make_label("-", 36, STYLE.C_GREEN)
	column.add_child(_headline_value)

	_headline_caption = STYLE.make_label("", 11, STYLE.C_FAINT)
	column.add_child(_headline_caption)

	_headline_breakdown = STYLE.make_label("", 11, STYLE.C_DIM)
	column.add_child(_headline_breakdown)

func _build_xp_row(page: VBoxContainer):
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 12)
	page.add_child(xp_row)

	_claim_btn = STYLE.make_button("CLAIM XP")
	_claim_btn.visible = false
	_claim_btn.pressed.connect(_on_claim_pressed)
	xp_row.add_child(_claim_btn)

	_xp_label = STYLE.make_label("", 14, STYLE.C_GREEN)
	_xp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_row.add_child(_xp_label)

func _build_algorithm_panel(page: VBoxContainer):
	_algo_title = STYLE.make_label("ALGORITHM USED", 12, STYLE.C_BLUE)
	page.add_child(_algo_title)

	var algo_panel := STYLE.make_card(14)
	algo_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(algo_panel)

	_algo_text = STYLE.make_label("", 13, STYLE.C_TEXT)
	_algo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	algo_panel.add_child(_algo_text)

func _fill_from_summary():
	_title_label.text = str(entry_summary.get("username", "Entry"))
	_set_status(str(entry_summary.get("status", "")))
	var level_id: String = str(entry_summary.get("level_id", "farp"))
	_meta_label.text = "%s  -  %s" % [LevelInfo.display_name(level_id), STYLE.short_date(str(entry_summary.get("created_at", "")))]
	if LevelInfo.is_pilot(level_id):
		_algo_title.text = "OPPONENT ALGORITHM"
		_set_headline("-", "PILOTED RUN", "")
		_set_stat_cards([])
	else:
		_set_headline(_rate_text(entry_summary.get("success_rate", null)), "CAPTURE SUCCESS RATE", "")
		_set_stat_cards([["TRIALS", str(entry_summary.get("trials", "-"))]])

func _set_status(status: String):
	for child in _status_badge_slot.get_children():
		child.queue_free()
	if status != "":
		_status_badge_slot.add_child(STYLE.make_badge(status.to_upper(), STYLE.status_color(status)))

func _set_headline(value_text: String, caption_text: String, breakdown_text: String, won: bool = true):
	_headline_value.text = value_text
	_headline_value.add_theme_color_override("font_color", STYLE.C_GREEN if won else STYLE.C_RED)
	_headline_caption.text = caption_text
	_headline_breakdown.text = breakdown_text
	_headline_breakdown.visible = breakdown_text != ""

func _time_text(value) -> String:
	if value == null or float(value) < 0.0:
		return "never"
	return "%.2fs" % float(value)

func _first(values, fallback = null):
	if typeof(values) == TYPE_ARRAY and not values.is_empty():
		return values[0]
	return fallback

func _fetch_detail():
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	request.request_completed.connect(_on_detail_response.bind(request))
	if request.request(PlayerSettings.server_url() + DETAIL_PATH + entry_id, ["X-API-Key: " + API_KEY], HTTPClient.METHOD_GET) != OK:
		request.queue_free()
		_detail_status.text = "Could not reach the server."

func _on_detail_response(_result, code, _headers, body, request):
	request.queue_free()
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
	_set_status(status)

	_algo_text.text = _algorithm_to_text(data.get("algorithm", []))
	_update_xp_ui(status, data.get("xp_awarded", null))

	var level_id: String = str(data.get("level_id", "farp"))
	var pilot: bool = LevelInfo.is_pilot(level_id)
	var placements: Array = data.get("placements", [])
	var trials = data.get("trials", entry_summary.get("trials", "-"))
	var when: String = STYLE.short_date(str(data.get("completed_at", data.get("created_at", ""))))
	if pilot:
		_algo_title.text = "OPPONENT ALGORITHM"
		_meta_label.text = "%s  -  %d defenders  -  %s" % [LevelInfo.display_name(level_id), placements.size(), when]
	else:
		_meta_label.text = "%s  -  %d defenders  -  %s trials  -  %s" % [LevelInfo.display_name(level_id), placements.size(), str(trials), when]

	var results = data.get("results", {})
	var outcomes: Array = []
	var rate = entry_summary.get("success_rate", null)
	if typeof(results) == TYPE_DICTIONARY:
		outcomes = results.get("outcomes", [])
		rate = results.get("success_rate", rate)

	var still_running: bool = status in ["queued", "running"]
	if outcomes.is_empty():
		if pilot:
			_set_headline("-", "PILOTED RUN", "")
			_set_stat_cards([["DEFENDERS FACED", str(placements.size())]])
			_detail_status.text = "Run is being rendered. Stats appear when it finishes." if still_running else "No run data for this entry yet."
		else:
			_set_headline(_rate_text(rate), "CAPTURE SUCCESS RATE", "")
			_set_stat_cards([
				["TRIALS", str(trials)],
				["DEFENDERS PLACED", str(placements.size())],
			])
			_detail_status.text = "Benchmark still running. Stats appear when it finishes." if still_running else "No benchmark data for this entry yet."
		return

	if pilot:
		var outcome: String = str(_first(outcomes, "timeout"))
		_set_headline(_pilot_result_text(outcome), "PILOTED RUN", "", outcome == "win")
		_set_stat_cards([
			["DETECTED", _time_text(_first(results.get("detection_times", [])))],
			["CAPTURED", _time_text(_first(results.get("capture_times", [])))],
			["REACHED PLANET", _time_text(_first(results.get("goal_times", [])))],
			["DEFENDERS FACED", str(placements.size())],
		])
		_detail_status.text = "Entry ID: %s" % entry_id
		return

	var wins := 0
	var losses := 0
	var timeouts := 0
	for outcome in outcomes:
		if outcome == "win":
			wins += 1
		elif outcome == "lose":
			losses += 1
		else:
			timeouts += 1

	var breakdown := "%d HELD   %d BREACHED" % [wins, losses]
	if timeouts > 0:
		breakdown += "   %d TIMEOUTS" % timeouts
	_set_headline(_rate_text(rate), "CAPTURE SUCCESS RATE", breakdown)
	_set_stat_cards([
		["DETECTION RATE", _rate_text(results.get("detection_rate", null))],
		["EVADERS THAT REACHED THE PLANET", str(losses)],
		["TIMEOUTS", str(timeouts)],
		["DEFENDERS PLACED", str(placements.size())],
		["TRIALS", str(trials)],
	])
	_detail_status.text = "Entry ID: %s" % entry_id

func _pilot_result_text(outcome: String) -> String:
	match outcome:
		"win":  return "PLANET REACHED"
		"lose": return "CAUGHT"
	return "OUT OF TIME"

func _set_stat_cards(cards: Array):
	for child in _stats_grid.get_children():
		child.queue_free()
	for card in cards:
		_stats_grid.add_child(_make_stat_card(card[0], card[1]))

func _make_stat_card(caption_text: String, value_text: String) -> Control:
	var card := STYLE.make_card(14)
	card.custom_minimum_size = Vector2(180, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)

	column.add_child(STYLE.make_label(value_text, 20, STYLE.C_TEXT))
	var caption := STYLE.make_label(caption_text, 10, STYLE.C_FAINT)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(caption)
	return card

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
		_xp_label.add_theme_color_override("font_color", STYLE.C_RED)
		_xp_label.text = message
		return
	_claim_btn.visible = false
	_xp_label.add_theme_color_override("font_color", STYLE.C_GREEN)
	_xp_label.text = "XP awarded: %d" % xp

func _algorithm_to_text(scripts) -> String:
	if typeof(scripts) != TYPE_ARRAY or scripts.is_empty():
		return "(no algorithm data)"
	var lines: Array = []
	for script_data in scripts:
		if typeof(script_data) != TYPE_DICTIONARY:
			continue
		_blocks_to_lines(script_data.get("blocks", []), 0, lines)
		lines.append("")
	var text: String = "\n".join(lines).strip_edges()
	return text if text != "" else "(no algorithm data)"

func _blocks_to_lines(blocks, depth: int, lines: Array):
	if typeof(blocks) != TYPE_ARRAY:
		return
	for block in blocks:
		if typeof(block) != TYPE_DICTIONARY:
			continue
		lines.append("    ".repeat(depth) + _block_label(str(block.get("type", "")), block.get("params", {})))
		_blocks_to_lines(block.get("children", []), depth + 1, lines)

func _block_label(block_type: String, params) -> String:
	var definition: Dictionary = SimulationManager.BLOCK_DEFS.get(block_type, {})
	var label: String = str(definition.get("label", block_type))
	if params is Dictionary:
		for key in ["value", "min", "max", "target", "var", "op"]:
			if params.has(key):
				label += " " + str(params[key])
	return label

func _rate_text(rate) -> String:
	if rate == null:
		return "-"
	return "%s%%" % str(rate)
