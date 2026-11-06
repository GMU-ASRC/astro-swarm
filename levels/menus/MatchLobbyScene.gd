extends Control

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

const MATCH_SCENE := "res://levels/modes/match/MatchScene.tscn"
const PLAYER_BASE_SCENE := "res://levels/menus/PlayerBaseScene.tscn"
const DEFAULT_NAME := "COMMANDER"
const QUICK_MATCH_SEARCH_SECONDS := 3.0

const C_BG := Color(0.035, 0.031, 0.059, 1.0)
const C_PANEL := Color(0.098, 0.094, 0.157, 1.0)
const C_BORDER := Color(0.318, 0.306, 0.463, 1.0)
const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_AMBER := Color(1.0, 0.70, 0.20, 1.0)

var _mode_option: OptionButton
var _status_label: Label
var _address_label: Label
var _host_button: Button
var _start_button: Button
var _join_button: Button
var _address_edit: LineEdit
var _host_list: VBoxContainer
var _quick_button: Button
var _guest_name: String = ""
var _quick_search_left: float = -1.0

func _ready():
	get_tree().paused = false
	theme = GAME_THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MatchNetwork.close()
	_build_ui()
	MatchNetwork.hosts_changed.connect(_on_hosts_changed)
	MatchNetwork.opponent_joined.connect(_on_opponent_joined)
	MatchNetwork.opponent_left.connect(_on_opponent_left)
	MatchNetwork.connection_failed.connect(_on_connection_failed)
	MatchNetwork.match_started.connect(_on_match_started)
	MatchNetwork.command_received.connect(_on_command_received)
	_listen_for_games()

func _listen_for_games():
	MatchNetwork.start_listening()
	if not MatchNetwork.is_listening():
		_status_label.text = "Could not listen for games on port %d. Type the host address to join." % MatchNetwork.BEACON_PORT
	_on_hosts_changed(MatchNetwork.found_hosts())

func _process(delta: float):
	if _quick_search_left < 0.0:
		return
	_quick_search_left -= delta
	if _quick_search_left <= 0.0:
		_quick_search_left = -1.0
		_status_label.text = "No games found. Hosting one instead..."
		_on_host_pressed()

func _on_quick_match_pressed():
	var hosts: Array = MatchNetwork.found_hosts()
	if not hosts.is_empty():
		_join(str(hosts[0]["address"]))
		return
	_set_buttons_enabled(false)
	_quick_search_left = QUICK_MATCH_SEARCH_SECONDS
	_status_label.text = "Searching the network for a game..."

func _set_buttons_enabled(enabled: bool):
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
	_quick_button.disabled = not enabled

func _exit_tree():
	MatchNetwork.stop_listening()
	for connection in [
		[MatchNetwork.hosts_changed, _on_hosts_changed],
		[MatchNetwork.opponent_joined, _on_opponent_joined],
		[MatchNetwork.opponent_left, _on_opponent_left],
		[MatchNetwork.connection_failed, _on_connection_failed],
		[MatchNetwork.match_started, _on_match_started],
		[MatchNetwork.command_received, _on_command_received],
	]:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])

func _local_name() -> String:
	return PlayerData.username if PlayerData.username != "" else DEFAULT_NAME

func _build_ui():
	var background := ColorRect.new()
	background.color = C_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
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

	var title := _label("LAN MATCH", 28, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label("Two devices on the same network. One hosts, the other joins.", 10, C_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(_label("PLAYING AS %s" % _local_name().to_upper(), 11, C_TEXT))
	_quick_button = HUD_BUTTONS.make("QUICK MATCH", HUD_BUTTONS.Kind.PRIMARY, 13)
	_quick_button.pressed.connect(_on_quick_match_pressed)
	column.add_child(_quick_button)
	var quick_hint := _label("Joins the first game found on the network, or hosts one if there is none.", 9, C_DIM)
	column.add_child(quick_hint)

	column.add_child(_section_title("HOST"))
	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 10)
	column.add_child(host_row)
	_mode_option = OptionButton.new()
	_mode_option.focus_mode = Control.FOCUS_NONE
	_mode_option.add_item(MATCH_CONFIG.mode_name(MATCH_CONFIG.Mode.REGULAR), MATCH_CONFIG.Mode.REGULAR)
	_mode_option.add_item(MATCH_CONFIG.mode_name(MATCH_CONFIG.Mode.FOG), MATCH_CONFIG.Mode.FOG)
	_mode_option.custom_minimum_size = Vector2(180, 0)
	host_row.add_child(_mode_option)
	_host_button = HUD_BUTTONS.make("HOST GAME", HUD_BUTTONS.Kind.NEUTRAL, 11)
	_host_button.pressed.connect(_on_host_pressed)
	host_row.add_child(_host_button)
	_start_button = HUD_BUTTONS.make("START MATCH", HUD_BUTTONS.Kind.PRIMARY, 11)
	_start_button.disabled = true
	_start_button.pressed.connect(_on_start_pressed)
	host_row.add_child(_start_button)
	_address_label = _label("", 9, C_DIM)
	column.add_child(_address_label)

	column.add_child(_section_title("JOIN"))
	_host_list = VBoxContainer.new()
	_host_list.add_theme_constant_override("separation", 6)
	column.add_child(_host_list)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	column.add_child(join_row)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "Host address, for example 192.168.1.20"
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address_edit)
	_join_button = HUD_BUTTONS.make("JOIN", HUD_BUTTONS.Kind.NEUTRAL, 11)
	_join_button.pressed.connect(func(): _join(_address_edit.text.strip_edges()))
	join_row.add_child(_join_button)

	_status_label = _label("", 11, C_AMBER)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status_label)
	var back_button := HUD_BUTTONS.make("BACK", HUD_BUTTONS.Kind.BACK, 11)
	back_button.pressed.connect(_on_back_pressed)
	column.add_child(back_button)

func _section_title(text: String) -> Label:
	return _label(text, 13, C_TEXT)

func _on_host_pressed():
	_quick_search_left = -1.0
	if not MatchNetwork.host_game(_local_name()):
		_status_label.text = "Could not open port %d. Another game may already be hosting on this device." % MatchNetwork.GAME_PORT
		_set_buttons_enabled(true)
		return
	MatchNetwork.stop_listening()
	_set_buttons_enabled(false)
	var addresses: Array = MatchNetwork.local_addresses()
	_address_label.text = "Your address: %s" % (", ".join(addresses) if not addresses.is_empty() else "unknown")
	_status_label.text = "Waiting for an opponent to join..."

func _on_start_pressed():
	if not MatchNetwork.is_host or not MatchNetwork.has_opponent():
		return
	var guest: String = _guest_name if _guest_name != "" else "GUEST"
	MatchNetwork.start_match({
		"seed": randi(),
		"mode": _mode_option.get_selected_id(),
		"names": [_local_name(), guest],
	})

func _join(address: String):
	if address == "":
		_status_label.text = "Enter the host address or pick a game from the list."
		return
	_quick_search_left = -1.0
	MatchNetwork.stop_listening()
	if not MatchNetwork.join_game(address):
		_status_label.text = "Could not connect to %s." % address
		_set_buttons_enabled(true)
		_listen_for_games()
		return
	_set_buttons_enabled(false)
	_status_label.text = "Connecting to %s..." % address

func _on_hosts_changed(hosts: Array):
	for child in _host_list.get_children():
		child.queue_free()
	if hosts.is_empty():
		_host_list.add_child(_label("Searching the network for games...", 9, C_DIM))
		return
	if _quick_search_left >= 0.0:
		_join(str(hosts[0]["address"]))
		return
	for host in hosts:
		var address: String = host["address"]
		var button := HUD_BUTTONS.make("JOIN %s  (%s)" % [str(host["name"]).to_upper(), address], HUD_BUTTONS.Kind.NEUTRAL, 10)
		button.pressed.connect(func(): _join(address))
		_host_list.add_child(button)

func _on_opponent_joined():
	if MatchNetwork.is_host:
		_status_label.text = "Opponent connected. Pick a mode and start the match."
		_start_button.disabled = false
	else:
		_status_label.text = "Connected. Waiting for the host to start the match."
		MatchNetwork.send_command("hello", {"name": _local_name()})

func _on_command_received(slot: int, kind: String, payload: Dictionary):
	if kind == "hello" and slot == MatchNetwork.CLIENT_SLOT:
		_guest_name = str(payload.get("name", "GUEST"))
		_status_label.text = "%s connected. Pick a mode and start the match." % _guest_name.to_upper()

func _on_opponent_left():
	_guest_name = ""
	_start_button.disabled = true
	if MatchNetwork.is_host:
		_status_label.text = "Opponent left. Waiting for another opponent..."
	else:
		_status_label.text = "The host closed the game."
		MatchNetwork.close()
		_set_buttons_enabled(true)
		_listen_for_games()

func _on_connection_failed():
	_status_label.text = "Connection failed. Check the address and that both devices are on the same network."
	_set_buttons_enabled(true)
	_listen_for_games()

func _on_match_started(_settings: Dictionary):
	get_tree().change_scene_to_file(MATCH_SCENE)

func _on_back_pressed():
	MatchNetwork.close()
	get_tree().change_scene_to_file(PLAYER_BASE_SCENE)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
