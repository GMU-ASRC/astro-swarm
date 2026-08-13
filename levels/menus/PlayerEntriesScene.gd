extends Control

const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")
const ENTRY_SCENE := preload("res://levels/menus/PlayerEntryScene.gd")

const ENTRIES_URL := "https://astroswarm.autonomousrobotics.club/api/evaluations"
const API_KEY := "world-unfair-file"

const C_BG     := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL  := Color(0.129, 0.122, 0.196, 1.0)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT   := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM    := Color(0.6, 0.62, 0.74, 1.0)
const C_BLUE   := Color(0.451, 0.616, 1.0, 1.0)
const C_GREEN  := Color(0.45, 0.85, 0.5, 1.0)
const C_RED    := Color(0.9, 0.45, 0.45, 1.0)

var _list: VBoxContainer
var _status_label: Label
var _claim_buttons: Dictionary = {}

func _ready():
	theme = GAME_THEME
	_build_ui()
	_fetch_entries()

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
	vbox.add_theme_constant_override("separation", 20)
	root.add_child(vbox)

	var title := _lbl("MY ENTRIES", 28, C_TEXT)
	vbox.add_child(title)

	_status_label = _lbl("Loading entries...", 14, C_DIM)
	vbox.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	var back := _make_btn("← BACK TO LEVELS")
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/LevelsScene.tscn"))
	vbox.add_child(back)

func _fetch_entries():
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	req.request_completed.connect(_on_entries_response.bind(req))
	if req.request(ENTRIES_URL, ["X-API-Key: " + API_KEY], HTTPClient.METHOD_GET) != OK:
		req.queue_free()
		_status_label.text = "Could not reach the server."

func _on_entries_response(_result, code, _headers, body, req):
	req.queue_free()
	if code != 200:
		_status_label.text = "Failed to load entries (status %d)." % code
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Array):
		_status_label.text = "No entries found."
		return
	var my_entries: Array = []
	for entry in data:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("player_id", "")) == PlayerData.player_id:
			my_entries.append(entry)
	if my_entries.is_empty():
		_status_label.text = "You have no entries yet."
		return
	_status_label.text = "%d entries" % my_entries.size()
	for entry in my_entries:
		_list.add_child(_make_entry_row(entry))

func _make_entry_row(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	row.add_child(top)

	var username := _lbl(str(entry.get("username", "unknown")), 16, C_TEXT)
	username.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(username)

	var status: String = str(entry.get("status", ""))
	var status_label := _lbl(status.to_upper(), 12, _status_color(status))
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(status_label)

	var claim_btn := _make_btn("CLAIM XP")
	claim_btn.pressed.connect(_on_claim_pressed.bind(entry, claim_btn))
	top.add_child(claim_btn)
	_style_claim_button(claim_btn, entry)

	var view_btn := _make_btn("VIEW")
	view_btn.pressed.connect(_open_entry.bind(entry))
	top.add_child(view_btn)

	var level_id: String = str(entry.get("level_id", "farp"))
	var meta := _lbl("%s  -  %s  -  %s" % [_level_name(level_id), _result_text(entry), _date(str(entry.get("created_at", "")))], 11, C_DIM)
	row.add_child(meta)

	var id_label := _lbl(str(entry.get("id", "")), 10, Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.7))
	row.add_child(id_label)

	return panel


func _level_name(level_id: String) -> String:
	return LevelInfo.display_name(level_id)

func _result_text(entry: Dictionary) -> String:
	var rate = entry.get("success_rate", null)
	if rate == null:
		return "pending"
	return LevelInfo.result_text(str(entry.get("level_id", "farp")), float(rate))

func _style_claim_button(button: Button, entry: Dictionary):
	var status: String = str(entry.get("status", ""))
	var xp_awarded = entry.get("xp_awarded", null)
	if status != "done":
		button.disabled = true
		button.text = "PENDING"
	elif xp_awarded != null:
		button.disabled = true
		button.text = "XP: %d" % int(xp_awarded)
	else:
		button.disabled = false
		button.text = "CLAIM XP"

func _on_claim_pressed(entry: Dictionary, button: Button):
	var claim_id: String = str(entry.get("id", ""))
	if claim_id == "":
		return
	button.disabled = true
	button.text = "CLAIMING..."
	_claim_buttons[claim_id] = button
	if not EvalUploader.xp_claimed.is_connected(_on_claim_finished):
		EvalUploader.xp_claimed.connect(_on_claim_finished)
	EvalUploader.claim_xp(claim_id)

func _on_claim_finished(claimed_id: String, success: bool, xp: int, message: String):
	var button: Button = _claim_buttons.get(claimed_id, null)
	if button == null or not is_instance_valid(button):
		return
	_claim_buttons.erase(claimed_id)
	if success:
		button.disabled = true
		button.text = "XP: %d" % xp
		_status_label.text = "Claimed %d XP." % xp
	else:
		button.disabled = false
		button.text = "CLAIM XP"
		_status_label.text = message

func _open_entry(entry: Dictionary):
	ENTRY_SCENE.entry_id = str(entry.get("id", ""))
	ENTRY_SCENE.entry_summary = entry
	get_tree().change_scene_to_file("res://levels/menus/PlayerEntryScene.tscn")

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
