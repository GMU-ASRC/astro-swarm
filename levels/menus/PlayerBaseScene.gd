extends Control

const TERRAN := preload("res://entities/planet/PlanetTerran.tscn")
const MOON := preload("res://entities/planet/PlanetMoon.tscn")

const PLANET_PIXELS := 80.0
const PLANET_DISP := 300.0
const MOON_PIXELS := 40.0
const MOON_DISP := 52.0
const ORBIT_MIN := 170.0
const ORBIT_MAX := 255.0

@onready var planet_layer: Control = $PlanetLayer
@onready var username_label: Label = $HUD/PlayerInfo/Username
@onready var level_label: Label = $HUD/PlayerInfo/Level
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var xp_label: Label = $HUD/XPLabel
@onready var coin_label: Label = $HUD/Navbar/CoinLabel
@onready var back_btn: Button = $BackButton
@onready var find_btn: Button = $FindMatchButton
@onready var game_mode_btn: Button = $GameModeButton
@onready var moons_btn: Button = $HUD/Navbar/MoonsButton
@onready var shop_btn: Button = $HUD/Navbar/ShopButton
@onready var modal: Control = $UsernameModal
@onready var name_edit: LineEdit = $UsernameModal/Panel/Margin/VBox/NameEdit
@onready var confirm_btn: Button = $UsernameModal/Panel/Margin/VBox/Confirm

const GAME_MODES := [
	{"id": "levels",      "label": "Levels",       "scene": "res://levels/menus/LevelsScene.tscn"},
]

const MARKET_PANEL := preload("res://levels/components/MarketPanel.gd")

const C_COIN := Color(1.0, 0.88, 0.40, 1.0)

var _planet: Control
var _moons: Array = []
var _orbit_time: float = 0.0
var _mode_index: int = 0

func _ready():
	get_tree().paused = false
	_style_xp_bar()

	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/HomeScene.tscn"))
	find_btn.pressed.connect(_on_find_match)
	moons_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://levels/menus/MoonsScene.tscn"))
	shop_btn.disabled = true
	game_mode_btn.pressed.connect(_on_game_mode_btn)
	_setup_mode_popup()
	_init_game_mode()

	confirm_btn.pressed.connect(_on_confirm_username)
	name_edit.text_changed.connect(func(t): confirm_btn.disabled = t.strip_edges() == "")
	name_edit.text_submitted.connect(func(_t): _on_confirm_username())

	PlayerData.xp_changed.connect(_on_xp_changed)
	PlayerData.level_changed.connect(_on_level_changed)
	PlayerData.coins_changed.connect(_on_coins_changed)
	PlayerData.moons_changed.connect(_on_moons_changed)

	get_viewport().size_changed.connect(_reposition)

	_build_planet()
	_build_moons()
	_refresh_hud()

	if not PlayerData.has_profile():
		modal.visible = true
		name_edit.grab_focus()

func _process(delta: float):
	_orbit_time += delta
	_update_moons()

func _style_xp_bar():
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.065, 0.122, 1)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.318, 0.306, 0.463, 1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.451, 0.616, 1, 1)
	xp_bar.add_theme_stylebox_override("background", bg)
	xp_bar.add_theme_stylebox_override("fill", fill)

func _planet_center() -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	return Vector2(vp.x * 0.5, vp.y * 0.46)

func _build_planet():
	_planet = TERRAN.instantiate() as Control
	planet_layer.add_child(_planet)
	_planet.generate(PlayerData.planet_seed, PLANET_PIXELS)
	_disable_mouse(_planet)
	_reposition()

func _build_moons():
	for m in _moons:
		m["node"].queue_free()
	_moons.clear()
	for i in PlayerData.moon_seeds.size():
		var sd: int = int(PlayerData.moon_seeds[i])
		var moon := MOON.instantiate() as Control
		planet_layer.add_child(moon)
		moon.generate(sd, MOON_PIXELS)
		_disable_mouse(moon)
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		_moons.append({
			"node": moon,
			"r": rng.randf_range(ORBIT_MIN, ORBIT_MAX),
			"incl": rng.randf_range(deg_to_rad(58.0), deg_to_rad(78.0)),
			"alpha": rng.randf_range(0.0, PI),
			"speed": rng.randf_range(0.25, 0.55) * (1.0 if rng.randf() < 0.5 else -1.0),
			"phase": rng.randf_range(0.0, TAU),
		})
	_update_moons()

func _update_moons():
	if _moons.is_empty():
		return
	var center: Vector2 = _planet_center()
	var base_scale: float = MOON_DISP / MOON_PIXELS
	for m in _moons:
		var theta: float = float(m["phase"]) + float(m["speed"]) * _orbit_time
		var depth: float = sin(theta)
		var r: float = float(m["r"])
		var cos_i: float = cos(float(m["incl"]))
		var local := Vector2(cos(theta) * r, depth * r * cos_i)
		var offset: Vector2 = local.rotated(float(m["alpha"]))
		var sc: float = base_scale * (1.0 + depth * 0.18)
		var node: Control = m["node"]
		node.scale = Vector2(sc, sc)
		var visual: float = MOON_PIXELS * sc
		node.position = center + offset - Vector2(visual * 0.5, visual * 0.5)
		node.z_index = 1 if depth >= 0.0 else -1

func _reposition():
	if is_instance_valid(_planet):
		var center: Vector2 = _planet_center()
		_planet.scale = Vector2(PLANET_DISP / PLANET_PIXELS, PLANET_DISP / PLANET_PIXELS)
		_planet.position = center - Vector2(PLANET_DISP * 0.5, PLANET_DISP * 0.5)
	_update_moons()

func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)

func _refresh_hud():
	username_label.text = PlayerData.username if PlayerData.has_profile() else "Commander"
	level_label.text = "Level %d" % PlayerData.level
	coin_label.text = str(PlayerData.coins)
	_update_xp()

func _update_xp():
	var needed: int = PlayerData.xp_needed()
	xp_bar.max_value = needed
	xp_bar.value = PlayerData.xp
	xp_label.text = "%d / %d XP" % [PlayerData.xp, needed]

func _on_xp_changed(_current: int, _needed: int):
	_update_xp()

func _on_level_changed(lvl: int):
	level_label.text = "Level %d" % lvl

func _on_coins_changed(amount: int):
	coin_label.text = str(amount)

func _on_moons_changed():
	_build_moons()

func _on_confirm_username():
	var n: String = name_edit.text.strip_edges()
	if n == "":
		return
	PlayerData.set_username(n)
	modal.visible = false
	_refresh_hud()

func _init_game_mode():
	# Migrate old "domination"/"timed_local" saves to "levels"
	if PlayerData.game_mode == "domination" or PlayerData.game_mode == "timed_local":
		PlayerData.set_game_mode("levels")
	for i in GAME_MODES.size():
		if GAME_MODES[i].id == PlayerData.game_mode:
			_mode_index = i
			break
	game_mode_btn.text = GAME_MODES[_mode_index].label
	_refresh_mode_ui()

var _mode_popup: PopupMenu

func _setup_mode_popup():
	_mode_popup = PopupMenu.new()
	for i in GAME_MODES.size():
		_mode_popup.add_item(GAME_MODES[i].label, i)
	add_child(_mode_popup)
	_mode_popup.id_pressed.connect(_on_mode_selected)

func _on_game_mode_btn():
	var btn_width: int = int(game_mode_btn.size.x)
	var gp: Vector2 = game_mode_btn.global_position
	_mode_popup.reset_size()
	_mode_popup.min_size = Vector2i(btn_width, 0)
	var pos := Vector2i(int(gp.x), int(gp.y + game_mode_btn.size.y))
	_mode_popup.popup(Rect2i(pos, Vector2i(btn_width, 0)))

func _on_mode_selected(id: int):
	_mode_index = id
	PlayerData.set_game_mode(GAME_MODES[id].id)
	game_mode_btn.text = GAME_MODES[id].label
	_refresh_mode_ui()

func _refresh_mode_ui():
	shop_btn.text = "Shop"
	coin_label.text = str(PlayerData.coins)
	coin_label.add_theme_color_override("font_color", C_COIN)

func _on_shop():
	if PlayerData.game_mode == "levels":
		var panel := MARKET_PANEL.new()
		add_child(panel)
		panel.closed.connect(func(): shop_btn.disabled = false)
		shop_btn.disabled = true
	else:
		print("Shop coming soon")

func _on_find_match():
	get_tree().change_scene_to_file(GAME_MODES[_mode_index].scene)
