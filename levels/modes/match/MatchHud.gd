extends Control

signal buy_requested(item_id: String)
signal upgrade_requested(upgrade_id: String)
signal workspace_requested()
signal ready_requested()
signal menu_requested()

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const STORE_PANEL := preload("res://levels/modes/match/MatchStorePanel.gd")
const MINIMAP := preload("res://levels/modes/match/MatchMinimap.gd")
const DUST_ICON_PATH := "res://assets/sprites/match/astrodust.svg"

const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_RED := Color(1.0, 0.42, 0.32, 1.0)
const C_AMBER := Color(1.0, 0.70, 0.20, 1.0)
const C_BAR := Color(0.07, 0.065, 0.11, 0.88)
const C_BAR_EDGE := Color(0.318, 0.306, 0.463, 1.0)
const NOTICE_SECONDS := 2.5
const SCREEN_MARGIN := 14

var minimap

var _name_label: Label
var _dust_label: Label
var _hp_label: Label
var _clock_label: Label
var _phase_label: Label
var _opponent_label: Label
var _fleet_labels: Dictionary = {}
var _hint_label: Label
var _notice_label: Label
var _ready_button: Button
var _shop_panel
var _upgrade_panel
var _notice_left: float = 0.0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GAME_THEME
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, SCREEN_MARGIN)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	layout.add_child(_build_top_bar())
	layout.add_child(_build_middle())
	layout.add_child(_build_bottom())

func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _bar_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	_name_label = _label("", 13, C_TEXT)
	row.add_child(_name_label)
	var dust_row := HBoxContainer.new()
	dust_row.add_theme_constant_override("separation", 6)
	row.add_child(dust_row)
	var dust_icon := TextureRect.new()
	dust_icon.texture = load(DUST_ICON_PATH)
	dust_icon.custom_minimum_size = Vector2(20, 20)
	dust_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dust_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dust_row.add_child(dust_icon)
	_dust_label = _label("0", 13, MATCH_CONFIG.DUST_COLOR)
	dust_row.add_child(_dust_label)
	_hp_label = _label("", 13, C_TEXT)
	row.add_child(_hp_label)
	row.add_child(_expander())
	_phase_label = _label("", 12, C_AMBER)
	row.add_child(_phase_label)
	_clock_label = _label("", 16, C_TEXT)
	row.add_child(_clock_label)
	row.add_child(_expander())
	_opponent_label = _label("", 13, C_DIM)
	row.add_child(_opponent_label)
	return bar

func _build_middle() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fleet := VBoxContainer.new()
	fleet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fleet.add_theme_constant_override("separation", 4)
	row.add_child(fleet)
	for role in [MATCH_CONFIG.Role.COLLECTOR, MATCH_CONFIG.Role.DEFENDER, MATCH_CONFIG.Role.EVADER, MATCH_CONFIG.Role.SCOUT]:
		var label := _label("", 10, C_TEXT)
		fleet.add_child(label)
		_fleet_labels[role] = label
	_hint_label = _label("", 9, C_DIM)
	_hint_label.custom_minimum_size = Vector2(300, 0)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fleet.add_child(_hint_label)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(center)
	_notice_label = _label("", 13, C_AMBER)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_notice_label)
	var panels := VBoxContainer.new()
	panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(panels)
	_shop_panel = _make_panel(panels, "SHOP")
	_shop_panel.item_pressed.connect(func(item_id): buy_requested.emit(item_id))
	_upgrade_panel = _make_panel(panels, "UPGRADES")
	_upgrade_panel.item_pressed.connect(func(upgrade_id): upgrade_requested.emit(upgrade_id))
	return row

func _build_bottom() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	minimap = MINIMAP.new()
	row.add_child(minimap)
	row.add_child(_expander())
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.size_flags_vertical = Control.SIZE_SHRINK_END
	buttons.add_theme_constant_override("separation", 8)
	row.add_child(buttons)
	_add_button(buttons, "MENU (ESC)", HUD_BUTTONS.Kind.BACK, func(): menu_requested.emit())
	_add_button(buttons, "WORKSPACE (TAB)", HUD_BUTTONS.Kind.NEUTRAL, func(): workspace_requested.emit())
	_add_button(buttons, "UPGRADES (U)", HUD_BUTTONS.Kind.NEUTRAL, toggle_upgrades)
	_add_button(buttons, "SHOP (B)", HUD_BUTTONS.Kind.NEUTRAL, toggle_shop)
	_ready_button = _add_button(buttons, "READY (R)", HUD_BUTTONS.Kind.PRIMARY, func(): ready_requested.emit())
	return row

func _add_button(row: HBoxContainer, text: String, kind: int, handler: Callable) -> Button:
	var button := HUD_BUTTONS.make(text, kind, 11)
	button.pressed.connect(handler)
	row.add_child(button)
	return button

func _make_panel(holder: Control, title: String):
	var panel = STORE_PANEL.new()
	panel.title_text = title
	panel.visible = false
	holder.add_child(panel)
	panel.close_pressed.connect(func(): panel.visible = false)
	return panel

func toggle_shop():
	_toggle_panel(_shop_panel)

func toggle_upgrades():
	_toggle_panel(_upgrade_panel)

func close_panels():
	_shop_panel.visible = false
	_upgrade_panel.visible = false

func _toggle_panel(panel):
	var opening: bool = not panel.visible
	close_panels()
	panel.visible = opening

func show_notice(text: String):
	_notice_label.text = text
	_notice_left = NOTICE_SECONDS
	_notice_label.modulate.a = 1.0

func _process(delta: float):
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice_label.modulate.a = clampf(_notice_left, 0.0, 1.0)
		if _notice_left <= 0.0:
			_notice_label.text = ""

func refresh(player, opponent, phase: int, setup_left: float, match_left: float, mode: int):
	_name_label.text = player.display_name.to_upper()
	_name_label.add_theme_color_override("font_color", player.color())
	_dust_label.text = str(player.dust)
	_hp_label.text = "PLANET %d / %d" % [ceili(player.planet_hp), int(MATCH_CONFIG.PLANET_MAX_HP)]
	_hp_label.add_theme_color_override("font_color", C_RED if player.planet_hp < MATCH_CONFIG.PLANET_MAX_HP * 0.35 else C_TEXT)
	_opponent_label.text = _opponent_text(opponent, mode)
	_opponent_label.add_theme_color_override("font_color", opponent.color())
	_refresh_fleet(player)
	_ready_button.visible = phase == MATCH_CONFIG.Phase.SETUP
	_ready_button.text = "UNREADY (R)" if player.is_ready else "READY (R)"
	if phase == MATCH_CONFIG.Phase.SETUP:
		_phase_label.text = "SETUP - OPPONENT READY" if opponent.is_ready else "SETUP"
		_clock_label.text = "%ds" % ceili(maxf(setup_left, 0.0))
		_hint_label.text = "Buy ships, write your algorithms in the workspace and deploy defenders by dragging inside your ring. Ships launch when the match goes live."
	else:
		var seconds_left: float = maxf(match_left, 0.0)
		_phase_label.text = MATCH_CONFIG.mode_name(mode).to_upper()
		_clock_label.text = "%d:%02d" % [floori(seconds_left / 60.0), int(seconds_left) % 60]
		_hint_label.text = "Drag in your ring to deploy defenders. Fly a scout with WASD. F follows the scout, H jumps home."
	_shop_panel.refresh(shop_rows(player), player.dust)
	_upgrade_panel.refresh(upgrade_rows(player), player.dust)

func _opponent_text(opponent, mode: int) -> String:
	if mode == MATCH_CONFIG.Mode.FOG:
		return opponent.display_name.to_upper()
	return "%s  PLANET %d" % [opponent.display_name.to_upper(), ceili(opponent.planet_hp)]

func _refresh_fleet(player):
	for role in _fleet_labels:
		var label: Label = _fleet_labels[role]
		var text: String = "%s  %d / %d" % [MATCH_CONFIG.ROLE_NAMES[role].to_upper(), player.ship_count(role), int(MATCH_CONFIG.SHIP_LIMITS[role])]
		if role == MATCH_CONFIG.Role.DEFENDER and player.hangar_defenders > 0:
			text += "   +%d IN HANGAR" % player.hangar_defenders
			label.add_theme_color_override("font_color", C_AMBER)
		else:
			label.add_theme_color_override("font_color", C_TEXT)
		label.text = text

func build_store(player):
	_shop_panel.build_rows(shop_rows(player))
	_upgrade_panel.build_rows(upgrade_rows(player))

func shop_rows(player) -> Array:
	var rows: Array = []
	for item in MATCH_CONFIG.SHOP_ITEMS:
		var role: int = item["role"]
		var owned: int = player.ship_count(role) + (player.hangar_defenders if role == MATCH_CONFIG.Role.DEFENDER else 0)
		rows.append({
			"id": item["id"],
			"title": item["title"],
			"text": item["text"],
			"cost": item["cost"],
			"locked": owned >= int(MATCH_CONFIG.SHIP_LIMITS[role]),
			"detail": "  %d / %d" % [owned, int(MATCH_CONFIG.SHIP_LIMITS[role])],
		})
	return rows

func upgrade_rows(player) -> Array:
	var rows: Array = []
	for entry in MATCH_CONFIG.UPGRADES:
		var level: int = player.upgrade_level(entry["id"])
		rows.append({
			"id": entry["id"],
			"title": entry["title"],
			"text": entry["text"],
			"cost": MATCH_CONFIG.upgrade_cost(entry["id"], level),
			"detail": "  LV %d / %d" % [level, int(entry["max_level"])],
		})
	return rows

func _bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_BAR
	style.border_color = C_BAR_EDGE
	style.set_border_width_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _expander() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
