extends Control

const GAME_THEME := preload("res://ui/GameTheme.tres")
const ENTRY_SCENE := preload("res://levels/menus/PlayerEntryScene.gd")
const STYLE := preload("res://levels/menus/EntryStyle.gd")

const ENTRIES_PATH := "/api/evaluations"
const API_KEY := "world-unfair-file"

var _list: VBoxContainer
var _status_label: Label
var _claim_buttons: Dictionary = {}

func _ready():
	theme = GAME_THEME
	_build_ui()
	_fetch_entries()

func _build_ui():
	add_child(STYLE.make_background())
	var margin := STYLE.make_page_margin()
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	var back := STYLE.make_button("< BACK TO BASE")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn"))
	page.add_child(back)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)

	var title := STYLE.make_label("MY ENTRIES", 28, STYLE.C_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var profile_button := STYLE.make_website_button("VIEW PROFILE ON WEBSITE", STYLE.profile_page_url(PlayerData.player_id))
	profile_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(profile_button)

	var lede := STYLE.make_label("Every benchmark you have submitted. Open one on the website for charts and replays.", 12, STYLE.C_DIM)
	lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(lede)

	_status_label = STYLE.make_label("Loading entries...", 12, STYLE.C_FAINT)
	page.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

func _fetch_entries():
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	request.request_completed.connect(_on_entries_response.bind(request))
	if request.request(PlayerSettings.server_url() + ENTRIES_PATH, ["X-API-Key: " + API_KEY], HTTPClient.METHOD_GET) != OK:
		request.queue_free()
		_status_label.text = "Could not reach the server."

func _on_entries_response(_result, code, _headers, body, request):
	request.queue_free()
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
		_list.add_child(_make_entry_card(entry))

func _make_entry_card(entry: Dictionary) -> Control:
	var level_id: String = str(entry.get("level_id", "farp"))
	var status: String = str(entry.get("status", ""))
	var entry_id: String = str(entry.get("id", ""))

	var card := STYLE.make_card(18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	body.add_child(title_row)
	title_row.add_child(STYLE.make_label(LevelInfo.display_name(level_id), 16, STYLE.C_TEXT))
	title_row.add_child(STYLE.make_badge(status.to_upper(), STYLE.status_color(status)))

	var meta_text := "%s  -  %s" % [STYLE.short_date(str(entry.get("created_at", ""))), entry_id]
	body.add_child(STYLE.make_label(meta_text, 10, STYLE.C_FAINT))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	body.add_child(buttons)

	var view_button := STYLE.make_button("VIEW")
	view_button.pressed.connect(_open_entry.bind(entry))
	buttons.add_child(view_button)

	var claim_button := STYLE.make_button("CLAIM REWARD")
	claim_button.pressed.connect(_on_claim_pressed.bind(entry, claim_button))
	buttons.add_child(claim_button)
	_style_claim_button(claim_button, entry)

	buttons.add_child(STYLE.make_website_button("OPEN ON WEBSITE", STYLE.entry_page_url(entry_id)))

	var stat := STYLE.make_stat(_result_text(entry), _result_caption(level_id))
	stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stat)

	return card

func _result_text(entry: Dictionary) -> String:
	var rate = entry.get("success_rate", null)
	if rate == null:
		return "-"
	var level_id: String = str(entry.get("level_id", "farp"))
	if LevelInfo.is_pilot(level_id) and not LevelInfo.is_supply(level_id):
		return "REACHED" if float(rate) >= 100.0 else "NO GOAL"
	return "%s%%" % str(rate)

func _result_caption(level_id: String) -> String:
	if LevelInfo.is_supply(level_id):
		return "EVADERS STOPPED"
	if LevelInfo.is_pilot(level_id):
		return "RESULT"
	return "CAPTURE RATE"

func _style_claim_button(button: Button, entry: Dictionary):
	var status: String = str(entry.get("status", ""))
	var xp_awarded = entry.get("xp_awarded", null)
	var coins_awarded = entry.get("coins_awarded", null)
	if status != "done":
		button.disabled = true
		button.text = "PENDING"
	elif xp_awarded != null:
		button.disabled = true
		button.text = STYLE.reward_text(int(xp_awarded), int(coins_awarded) if coins_awarded != null else 0)
	else:
		button.disabled = false
		button.text = "CLAIM REWARD"

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

func _on_claim_finished(claimed_id: String, success: bool, xp: int, coins: int, message: String):
	var button: Button = _claim_buttons.get(claimed_id, null)
	if button == null or not is_instance_valid(button):
		return
	_claim_buttons.erase(claimed_id)
	if success:
		button.disabled = true
		button.text = STYLE.reward_text(xp, coins)
		_status_label.text = ("Claimed %d XP and %d coins. %s" % [xp, coins, message]).strip_edges()
	else:
		button.disabled = false
		button.text = "CLAIM REWARD"
		_status_label.text = message

func _open_entry(entry: Dictionary):
	ENTRY_SCENE.entry_id = str(entry.get("id", ""))
	ENTRY_SCENE.entry_summary = entry
	get_tree().change_scene_to_file("res://levels/menus/PlayerEntryScene.tscn")
