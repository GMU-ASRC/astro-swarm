extends Control

signal buy_requested(item_id: String)
signal upgrade_requested(upgrade_id: String)
signal workspace_requested()
signal ready_requested()
signal leave_requested()

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")
const HUD_BUTTONS := preload("res://ui/hud/HudButtons.gd")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const STORE_PANEL := preload("res://levels/modes/match/MatchStorePanel.gd")
const DUST_ICON_PATH := "res://assets/sprites/match/astrodust.svg"

const C_TEXT := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM := Color(0.6, 0.62, 0.74, 1.0)
const C_RED := Color(1.0, 0.42, 0.32, 1.0)
const C_AMBER := Color(1.0, 0.70, 0.20, 1.0)
const NOTICE_SECONDS := 2.5

var _name_label: Label
var _dust_label: Label
var _hp_label: Label
var _clock_label: Label
var _phase_label: Label
var _opponent_label: Label
var _hangar_label: Label
var _hint_label: Label
var _notice_label: Label
var _ready_button: Button
var _shop_panel
var _upgrade_panel
var _notice_left: float = 0.0
var _last_rows_dust: int = -1

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GAME_THEME
	_build_top_bar()
	_build_side_info()
	_build_buttons()
	_build_panels()

func _build_top_bar():
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16
	bar.offset_top = 12
	bar.offset_right = -16
	bar.add_theme_constant_override("separation", 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_name_label = _label("", 13, C_TEXT)
	bar.add_child(_name_label)
	var dust_row := HBoxContainer.new()
	dust_row.add_theme_constant_override("separation", 6)
	bar.add_child(dust_row)
	var dust_icon := TextureRect.new()
	dust_icon.texture = load(DUST_ICON_PATH)
	dust_icon.custom_minimum_size = Vector2(20, 20)
	dust_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dust_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dust_row.add_child(dust_icon)
	_dust_label = _label("0", 13, MATCH_CONFIG.DUST_COLOR)
	dust_row.add_child(_dust_label)
	_hp_label = _label("", 13, C_TEXT)
	bar.add_child(_hp_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_phase_label = _label("", 13, C_AMBER)
	bar.add_child(_phase_label)
	_clock_label = _label("", 18, C_TEXT)
	bar.add_child(_clock_label)
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer_right)
	_opponent_label = _label("", 13, C_DIM)
	bar.add_child(_opponent_label)

func _build_side_info():
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = 16
	column.offset_top = 48
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_hangar_label = _label("", 11, C_TEXT)
	column.add_child(_hangar_label)
	_hint_label = _label("", 9, C_DIM)
	column.add_child(_hint_label)
	_notice_label = _label("", 12, C_AMBER)
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notice_label.offset_bottom = -90
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_notice_label)

func _build_buttons():
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -16
	row.offset_bottom = -16
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_add_button(row, "LEAVE", HUD_BUTTONS.Kind.BACK, func(): leave_requested.emit())
	_add_button(row, "WORKSPACE", HUD_BUTTONS.Kind.NEUTRAL, func(): workspace_requested.emit())
	_add_button(row, "UPGRADES", HUD_BUTTONS.Kind.NEUTRAL, func(): _toggle_panel(_upgrade_panel))
	_add_button(row, "SHOP", HUD_BUTTONS.Kind.NEUTRAL, func(): _toggle_panel(_shop_panel))
	_ready_button = _add_button(row, "READY", HUD_BUTTONS.Kind.PRIMARY, func(): ready_requested.emit())

func _add_button(row: HBoxContainer, text: String, kind: int, handler: Callable) -> Button:
	var button := HUD_BUTTONS.make(text, kind, 11)
	button.pressed.connect(handler)
	row.add_child(button)
	return button

func _build_panels():
	_shop_panel = _make_panel("SHOP")
	_shop_panel.item_pressed.connect(func(item_id): buy_requested.emit(item_id))
	_upgrade_panel = _make_panel("UPGRADES")
	_upgrade_panel.item_pressed.connect(func(upgrade_id): upgrade_requested.emit(upgrade_id))

func _make_panel(title: String):
	var panel = STORE_PANEL.new()
	panel.title_text = title
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_right = -16
	panel.visible = false
	add_child(panel)
	panel.close_pressed.connect(func(): panel.visible = false)
	return panel

func _toggle_panel(panel):
	var opening: bool = not panel.visible
	_shop_panel.visible = false
	_upgrade_panel.visible = false
	panel.visible = opening

func is_over_panel(screen_point: Vector2) -> bool:
	for panel in [_shop_panel, _upgrade_panel]:
		if panel.visible and panel.get_global_rect().has_point(screen_point):
			return true
	return false

func show_notice(text: String):
	_notice_label.text = text
	_notice_left = NOTICE_SECONDS

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
	_opponent_label.text = "%s  %d HP" % [opponent.display_name.to_upper(), ceili(opponent.planet_hp)] if mode == MATCH_CONFIG.Mode.REGULAR else opponent.display_name.to_upper()
	_hangar_label.text = "DEFENDERS IN HANGAR: %d" % player.hangar_defenders
	_ready_button.visible = phase == MATCH_CONFIG.Phase.SETUP
	_ready_button.text = "UNREADY" if player.is_ready else "READY"
	if phase == MATCH_CONFIG.Phase.SETUP:
		_phase_label.text = "SETUP  %s" % ("OPPONENT READY" if opponent.is_ready else "")
		_clock_label.text = "%ds" % ceili(setup_left)
		_hint_label.text = "Buy ships, write your algorithms, deploy defenders in your ring."
	else:
		_phase_label.text = MATCH_CONFIG.mode_name(mode).to_upper()
		var seconds_left: float = maxf(match_left, 0.0)
		_clock_label.text = "%d:%02d" % [floori(seconds_left / 60.0), int(seconds_left) % 60]
		_hint_label.text = "Drag in your ring to deploy. Fly a scout with WASD. F toggles follow."
	if player.dust != _last_rows_dust or _shop_panel.visible or _upgrade_panel.visible:
		_last_rows_dust = player.dust
		_shop_panel.refresh(shop_rows(), player.dust)
		_upgrade_panel.refresh(upgrade_rows(player), player.dust)

func build_store(player):
	_shop_panel.build_rows(shop_rows())
	_upgrade_panel.build_rows(upgrade_rows(player))

func shop_rows() -> Array:
	var rows: Array = []
	for item in MATCH_CONFIG.SHOP_ITEMS:
		rows.append({"id": item["id"], "title": item["title"], "text": item["text"], "cost": item["cost"]})
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

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
