extends CanvasLayer

signal closed

# ── Exact palette from GameTheme.tres ────────────────────────────────────────
const C_BG          := Color(0.129, 0.122, 0.196, 1.0)
const C_BG_DARK     := Color(0.09,  0.085, 0.145, 1.0)
const C_BG_CARD     := Color(0.105, 0.099, 0.168, 1.0)
const C_BORDER      := Color(0.318, 0.306, 0.463, 1.0)
const C_BORDER_LIT  := Color(0.451, 0.616, 1.0,   1.0)
const C_TEXT        := Color(0.93,  0.94,  1.0,   1.0)
const C_TEXT_MID    := Color(0.82,  0.83,  0.93,  1.0)
const C_TEXT_DIM    := Color(0.6,   0.62,  0.74,  1.0)
const C_BLUE        := Color(0.451, 0.616, 1.0,   1.0)
const C_GOLD        := Color(1.0,   0.85,  0.30,  1.0)
const C_GOLD_DIM    := Color(0.75,  0.64,  0.22,  1.0)
const C_LOCKED      := Color(0.50,  0.50,  0.62,  1.0)
const C_GREEN       := Color(0.40,  0.85,  0.45,  1.0)

const GAME_THEME    := preload("res://ui/GameTheme.tres")
const FONT_REG      := preload("res://assets/fonts/Silkscreen-Regular.ttf")

const UPGRADES := [
	{
		"id":        "speed",
		"name":      "DRONE SPEED",
		"desc":      "Attack drones fly\n10% faster per level",
		"max_level": 10,
		"base_cost": 10,
	},
	{
		"id":        "health",
		"name":      "DRONE HEALTH",
		"desc":      "All drones gain\n25% more HP per level",
		"max_level": 10,
		"base_cost": 15,
	},
	{
		"id":        "death_spawn",
		"name":      "DEATH SPAWN",
		"desc":      "Destroyed attack\ndrones release\n2 nano drones",
		"max_level": 1,
		"base_cost": 50,
	},
	{
		"id":        "kamikaze",
		"name":      "KAMIKAZE",
		"desc":      "Nano drones\nself-destruct near\nenemy drones",
		"max_level": 1,
		"base_cost": 100,
	},
]

var _token_label: Label
var _cards: Dictionary = {}

func _ready():
	layer = 20
	_build_ui()

# ── Build ─────────────────────────────────────────────────────────────────────
func _build_ui():
	# Dim overlay
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Centred root (apply theme so buttons inherit it)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GAME_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	# Outer panel
	var outer := _make_panel(C_BG, C_BORDER, 2, 8)
	outer.custom_minimum_size = Vector2(740, 0)
	center.add_child(outer)

	var margin := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	outer.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var title := _lbl("MARKET", 20, C_TEXT)
	header.add_child(title)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_spacer)

	_token_label = _lbl("", 13, C_GOLD)
	header.add_child(_token_label)

	var close_btn := _make_btn("✕", 14)
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# ── Divider ───────────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# ── Cards row ─────────────────────────────────────────────────────────────
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for upg in UPGRADES:
		row.add_child(_make_card(upg))

	# ── Footer hint ───────────────────────────────────────────────────────────
	var hint := _lbl("Tokens are earned by dominating enemy planets", 10, C_TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hint)

	refresh()

# ── Card builder ──────────────────────────────────────────────────────────────
func _make_card(upg: Dictionary) -> Control:
	var pc := _make_panel(C_BG_CARD, C_BORDER, 1, 6)
	pc.custom_minimum_size = Vector2(162, 0)

	var m := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	pc.add_child(m)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	m.add_child(vbox)

	# Image placeholder — white rect with subtle inner border
	var img_wrap := _make_panel(Color.WHITE, Color(0.75, 0.75, 0.75, 0.5), 1, 4)
	img_wrap.custom_minimum_size = Vector2(138, 90)
	vbox.add_child(img_wrap)

	# Upgrade name
	var name_lbl := _lbl(upg["name"], 12, C_TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(138, 0)
	vbox.add_child(name_lbl)

	# Level badge
	var level_lbl := _lbl("", 11, C_BLUE)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(level_lbl)

	# Description
	var desc_lbl := _lbl(upg["desc"], 10, C_TEXT_DIM)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(138, 42)
	vbox.add_child(desc_lbl)

	# Separator line
	var line := ColorRect.new()
	line.color = C_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(line)

	# Cost
	var cost_lbl := _lbl("", 11, C_GOLD)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)

	# Buy button
	var buy_btn := _make_btn("BUY", 12)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.pressed.connect(func(): _buy(upg["id"]))
	vbox.add_child(buy_btn)

	_cards[upg["id"]] = {
		"level_lbl": level_lbl,
		"cost_lbl":  cost_lbl,
		"buy_btn":   buy_btn,
		"panel":     pc,
	}
	return pc

# ── Refresh ───────────────────────────────────────────────────────────────────
func refresh():
	_token_label.text = "%d  MARKET TOKENS" % DominationData.tokens

	for upg in UPGRADES:
		var id: String       = upg["id"]
		var max_lvl: int     = upg["max_level"]
		var card: Dictionary = _cards[id]
		var is_bool: bool    = max_lvl == 1
		var cur_level: int   = 1 if (is_bool and DominationData.get_upgrade(id)) else int(DominationData.get_upgrade(id))
		var is_maxed: bool   = (is_bool and cur_level > 0) or (not is_bool and cur_level >= max_lvl)
		var is_locked: bool  = id == "kamikaze" and not DominationData.get_upgrade("death_spawn")

		# Level label
		if is_bool:
			card["level_lbl"].text = "OWNED" if cur_level > 0 else "NOT OWNED"
			card["level_lbl"].add_theme_color_override("font_color", C_GREEN if cur_level > 0 else C_TEXT_DIM)
		else:
			card["level_lbl"].text = "LVL  %d / %d" % [cur_level, max_lvl]
			card["level_lbl"].add_theme_color_override("font_color", C_BLUE if cur_level > 0 else C_TEXT_DIM)

		if is_maxed:
			card["cost_lbl"].text = "— MAXED —"
			card["cost_lbl"].add_theme_color_override("font_color", C_GREEN)
			card["buy_btn"].text     = "MAXED"
			card["buy_btn"].disabled = true
		elif is_locked:
			card["cost_lbl"].text = "NEED DEATH SPAWN"
			card["cost_lbl"].add_theme_color_override("font_color", C_LOCKED)
			card["buy_btn"].text     = "LOCKED"
			card["buy_btn"].disabled = true
		else:
			var cost: int = _next_cost(upg, cur_level)
			var can_buy: bool = DominationData.tokens >= cost
			card["cost_lbl"].text = "%d TOKENS" % cost
			card["cost_lbl"].add_theme_color_override("font_color", C_GOLD if can_buy else C_GOLD_DIM)
			card["buy_btn"].text     = "BUY"
			card["buy_btn"].disabled = not can_buy

func _next_cost(upg: Dictionary, cur_level: int) -> int:
	return int(upg["base_cost"] * pow(2.0, float(cur_level)))

func _buy(id: String):
	var upg: Dictionary = {}
	for u in UPGRADES:
		if u["id"] == id:
			upg = u
			break
	if upg.is_empty():
		return

	var is_bool: bool  = upg["max_level"] == 1
	var cur_level: int = 1 if (is_bool and DominationData.get_upgrade(id)) else int(DominationData.get_upgrade(id))

	if is_bool and cur_level > 0:
		return
	if not is_bool and cur_level >= upg["max_level"]:
		return
	if id == "kamikaze" and not DominationData.get_upgrade("death_spawn"):
		return

	var cost: int = _next_cost(upg, cur_level)
	if not DominationData.spend_tokens(cost):
		return

	if is_bool:
		DominationData.set_upgrade(id, true)
	else:
		DominationData.set_upgrade(id, cur_level + 1)

	refresh()

func _on_close():
	closed.emit()
	queue_free()

# ── UI helpers ────────────────────────────────────────────────────────────────
func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _make_panel(bg: Color, border: Color, border_w: int, radius: int) -> PanelContainer:
	var pc    := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color              = bg
	style.border_color          = border
	style.border_width_left     = border_w
	style.border_width_top      = border_w
	style.border_width_right    = border_w
	style.border_width_bottom   = border_w
	style.corner_radius_top_left     = radius
	style.corner_radius_top_right    = radius
	style.corner_radius_bottom_left  = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left   = 0.0
	style.content_margin_top    = 0.0
	style.content_margin_right  = 0.0
	style.content_margin_bottom = 0.0
	pc.add_theme_stylebox_override("panel", style)
	return pc
