extends Node2D

const SHIP      := preload("res://entities/ship/Spaceship.tscn")
const TERRAN    := preload("res://entities/planet/PlanetTerran.tscn")
const FONT_REG  := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

# ── Arena ─────────────────────────────────────────────────────────────────────
# 3840×2160 = exactly 3× the 1280×720 viewport → zoom 1/3 fills screen perfectly
const ARENA        := Vector2(3840.0, 2160.0)
const EARTH_CENTER := Vector2(1920.0, 1080.0)
const EARTH_PX     := 80.0
const EARTH_DISP   := 200.0
const EARTH_RADIUS := 105.0     # enemy reaching this = player loses

const MAX_DEF       := 6
const PLACE_MIN     := 155.0    # can't place inside this radius (too close to planet)
const PLACE_MAX     := 700.0    # outer boundary of placement zone
const DEF_ORBIT_SPD := 0.35

const ENEMY_SPEED   := 105.0
# spawn distance is computed per-launch from arena boundary (see _start_wave)

const BG_COLOR     := Color(0.04, 0.04, 0.07, 1.0)
const C_BLUE       := Color(0.451, 0.616, 1.0, 1.0)
const C_RED        := Color(1.0,  0.42,  0.32, 1.0)
const C_TEXT       := Color(0.93, 0.94,  1.0,  1.0)
const C_DIM        := Color(0.6,  0.62,  0.74, 1.0)
const C_GOLD       := Color(1.0,  0.85,  0.30, 1.0)
const C_GREEN      := Color(0.40, 0.85,  0.45, 1.0)
const C_PANEL      := Color(0.09, 0.085, 0.145, 0.94)
const C_BORDER     := Color(0.318, 0.306, 0.463, 1.0)

# ── Phase ─────────────────────────────────────────────────────────────────────
enum Phase { PLACE, ACTIVE, WIN, LOSE }
var _phase: Phase = Phase.PLACE

# ── Game state ────────────────────────────────────────────────────────────────
var _defenders: Array = []
var _enemy_pos: Vector2  = Vector2.ZERO
var _enemy_dir: Vector2  = Vector2.ZERO
var _active_time: float  = 0.0
var _score: int          = 0
var _intercept_dist: float = 0.0

# ── Slider values ─────────────────────────────────────────────────────────────
var _vision_range: float = 300.0
var _fov_deg: float      = 70.0

# ── Scene nodes ───────────────────────────────────────────────────────────────
var _camera: Camera2D
var _bg_stars: Array = []

# ── HUD refs ──────────────────────────────────────────────────────────────────
var _phase_label:       Label
var _timer_label:       Label
var _drone_label:       Label
var _score_label:       Label
var _hint_label:        Label
var _start_btn:         Button
var _result_panel:      Control
var _result_title:      Label
var _result_detail:     Label
var _vision_value_lbl:  Label
var _fov_value_lbl:     Label

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready():
	get_tree().paused = false
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.position = EARTH_CENTER
	_camera.zoom     = Vector2(1.0 / 3.0, 1.0 / 3.0)
	_camera.make_current()

	_make_bg_stars()
	_build_earth()
	_build_hud()
	queue_redraw()

# ── Background ────────────────────────────────────────────────────────────────
func _make_bg_stars():
	var rng := RandomNumberGenerator.new()
	rng.seed = 77421
	for _i in 900:
		_bg_stars.append({
			"pos": Vector2(rng.randf_range(0.0, ARENA.x), rng.randf_range(0.0, ARENA.y)),
			"sz":  rng.randf_range(1.0, 2.4),
			"a":   rng.randf_range(0.10, 0.55),
		})

func _build_earth():
	var p := TERRAN.instantiate() as Control
	add_child(p)
	p.generate(PlayerData.planet_seed, EARTH_PX)
	p.z_index = 2
	var sc := EARTH_DISP / EARTH_PX
	p.scale    = Vector2(sc, sc)
	p.position = EARTH_CENTER - Vector2(EARTH_DISP * 0.5, EARTH_DISP * 0.5)
	_disable_mouse(p)

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud():
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GAME_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	# ── Top bar ───────────────────────────────────────────────────────────────
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("separation", 16)
	top.offset_left   = 16
	top.offset_top    = 14
	top.offset_right  = -16
	top.offset_bottom = 50
	root.add_child(top)

	var back_btn := _make_btn("← LEAVE", 13)
	back_btn.pressed.connect(_leave)
	top.add_child(back_btn)

	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp1)

	_timer_label = _lbl("0:00", 24, C_TEXT)
	top.add_child(_timer_label)

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp2)

	_score_label = _lbl("SCORE  —", 13, C_GOLD)
	top.add_child(_score_label)

	# ── Left info ─────────────────────────────────────────────────────────────
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 16
	left.offset_top  = 58
	root.add_child(left)

	_phase_label = _lbl("PLACE DEFENDERS", 13, C_BLUE)
	left.add_child(_phase_label)

	_drone_label = _lbl("DEFENDERS: 0 / 6", 11, C_DIM)
	left.add_child(_drone_label)

	# ── Right panel: sliders ──────────────────────────────────────────────────
	var rp := _panel(C_PANEL, C_BORDER, 1, 6)
	rp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rp.offset_left   = -248
	rp.offset_top    = 58
	rp.offset_right  = -12
	rp.offset_bottom = 58  # grows with content
	root.add_child(rp)

	var rm := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		rm.add_theme_constant_override("margin_" + s, 12)
	rp.add_child(rm)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rv.custom_minimum_size = Vector2(220, 0)
	rm.add_child(rv)

	rv.add_child(_lbl("DEFENDER SETTINGS", 10, C_TEXT))

	var line1 := ColorRect.new()
	line1.color = C_BORDER
	line1.custom_minimum_size = Vector2(0, 1)
	rv.add_child(line1)

	# Vision Range
	rv.add_child(_lbl("VISION RANGE", 9, C_DIM))
	var vr_row := HBoxContainer.new()
	vr_row.add_theme_constant_override("separation", 6)
	rv.add_child(vr_row)
	var vr_sl := HSlider.new()
	vr_sl.min_value = 80.0
	vr_sl.max_value = 700.0
	vr_sl.step      = 10.0
	vr_sl.value     = _vision_range
	vr_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vr_sl.value_changed.connect(_on_vision_changed)
	vr_row.add_child(vr_sl)
	_vision_value_lbl = _lbl("300", 10, C_BLUE)
	_vision_value_lbl.custom_minimum_size = Vector2(32, 0)
	vr_row.add_child(_vision_value_lbl)

	# FOV
	rv.add_child(_lbl("FIELD OF VIEW", 9, C_DIM))
	var fov_row := HBoxContainer.new()
	fov_row.add_theme_constant_override("separation", 6)
	rv.add_child(fov_row)
	var fov_sl := HSlider.new()
	fov_sl.min_value = 15.0
	fov_sl.max_value = 180.0
	fov_sl.step      = 5.0
	fov_sl.value     = _fov_deg
	fov_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_sl.value_changed.connect(_on_fov_changed)
	fov_row.add_child(fov_sl)
	_fov_value_lbl = _lbl("70°", 10, C_BLUE)
	_fov_value_lbl.custom_minimum_size = Vector2(38, 0)
	fov_row.add_child(_fov_value_lbl)

	# ── Start button ──────────────────────────────────────────────────────────
	_start_btn = _make_btn("LAUNCH ENEMY  →", 13)
	_start_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_start_btn.offset_left   = -210
	_start_btn.offset_top    = -54
	_start_btn.offset_right  = -16
	_start_btn.offset_bottom = -16
	_start_btn.pressed.connect(_start_wave)
	root.add_child(_start_btn)

	# ── Hint ──────────────────────────────────────────────────────────────────
	_hint_label = _lbl(
		"Click inside the blue ring to place defenders (max 6)  ·  Tune their vision with sliders above  ·  Then launch the enemy",
		10, C_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_left   = 16
	_hint_label.offset_top    = -28
	_hint_label.offset_right  = -16
	_hint_label.offset_bottom = -6
	root.add_child(_hint_label)

	# ── Result panel ──────────────────────────────────────────────────────────
	_result_panel = Control.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_result_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(dim)

	var rcard := _panel(Color(0.129, 0.122, 0.196, 1.0), C_BORDER, 2, 8)
	rcard.set_anchors_preset(Control.PRESET_CENTER)
	rcard.offset_left   = -240
	rcard.offset_top    = -180
	rcard.offset_right  = 240
	rcard.offset_bottom = 180
	_result_panel.add_child(rcard)

	var rmar := MarginContainer.new()
	for s in ["left","right","top","bottom"]:
		rmar.add_theme_constant_override("margin_" + s, 28)
	rcard.add_child(rmar)

	var rvb := VBoxContainer.new()
	rvb.add_theme_constant_override("separation", 14)
	rmar.add_child(rvb)

	_result_title = _lbl("", 26, C_TEXT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rvb.add_child(_result_title)

	_result_detail = _lbl("", 11, C_DIM)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_detail.custom_minimum_size = Vector2(400, 0)
	rvb.add_child(_result_detail)

	var sep2 := ColorRect.new()
	sep2.color = C_BORDER
	sep2.custom_minimum_size = Vector2(0, 1)
	rvb.add_child(sep2)

	var rbtnrow := HBoxContainer.new()
	rbtnrow.add_theme_constant_override("separation", 14)
	rbtnrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rvb.add_child(rbtnrow)

	var retry := _make_btn("TRY AGAIN", 13)
	retry.pressed.connect(_retry)
	rbtnrow.add_child(retry)

	var leave2 := _make_btn("LEVELS", 13)
	leave2.pressed.connect(_leave)
	rbtnrow.add_child(leave2)

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float):
	if _phase == Phase.ACTIVE:
		_active_time += delta
		_timer_label.text = "%.1fs" % _active_time

		# Move enemy
		_enemy_pos += _enemy_dir * ENEMY_SPEED * delta

		# Check win (any defender sees enemy)
		if _any_defender_sees_enemy():
			_trigger_win()
			return

		# Check lose (enemy reached planet)
		if _enemy_pos.distance_to(EARTH_CENTER) <= EARTH_RADIUS:
			_trigger_lose()
			return

	queue_redraw()

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent):
	if _phase != Phase.PLACE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var world_pos: Vector2 = get_global_mouse_position()
		var dist: float = world_pos.distance_to(EARTH_CENTER)
		if dist < PLACE_MIN or dist > PLACE_MAX:
			return
		if _defenders.size() >= MAX_DEF:
			return
		_place_defender(world_pos)

# ── Defender placement ────────────────────────────────────────────────────────
func _place_defender(world_pos: Vector2):
	var radius: float = world_pos.distance_to(EARTH_CENTER)
	var angle: float  = (world_pos - EARTH_CENTER).angle()

	var ship := SHIP.instantiate()
	ship.setup_player_orbit(EARTH_CENTER, radius, DEF_ORBIT_SPD, angle, 99.0)
	ship.arena_size     = ARENA
	ship.view_distance  = _vision_range
	ship.fov_degrees    = _fov_deg
	add_child(ship)
	ship.refresh_cone()
	_defenders.append(ship)

	_drone_label.text = "DEFENDERS: %d / %d" % [_defenders.size(), MAX_DEF]
	queue_redraw()

# ── Slider callbacks ──────────────────────────────────────────────────────────
func _on_vision_changed(value: float):
	_vision_range = value
	_vision_value_lbl.text = str(int(value))
	_update_defender_vision()

func _on_fov_changed(value: float):
	_fov_deg = value
	_fov_value_lbl.text = "%d°" % int(value)
	_update_defender_vision()

func _update_defender_vision():
	for ship in _defenders:
		if is_instance_valid(ship):
			ship.view_distance = _vision_range
			ship.fov_degrees   = _fov_deg
			ship.refresh_cone()

# ── Wave ──────────────────────────────────────────────────────────────────────
func _start_wave():
	if _defenders.is_empty():
		_hint_label.text = "Place at least one defender first!"
		return

	_phase = Phase.ACTIVE
	_start_btn.visible = false
	_phase_label.text  = "INTERCEPTING..."
	_hint_label.text   = "Watch your defenders — if their vision cone catches the enemy, they destroy it"

	# Spawn enemy at the arena boundary in a random direction
	var angle: float = randf_range(0.0, TAU)
	var ca := absf(cos(angle))
	var sa := absf(sin(angle))
	var half_w := ARENA.x * 0.5 - 20.0   # 1900
	var half_h := ARENA.y * 0.5 - 20.0   # 1060
	var dist: float
	if ca < 0.0001:
		dist = half_h
	elif sa < 0.0001:
		dist = half_w
	else:
		dist = min(half_w / ca, half_h / sa)
	_enemy_pos = EARTH_CENTER + Vector2(dist, 0.0).rotated(angle)
	_enemy_dir = (EARTH_CENTER - _enemy_pos).normalized()

	queue_redraw()

# ── Vision check ──────────────────────────────────────────────────────────────
func _any_defender_sees_enemy() -> bool:
	for ship in _defenders:
		if not is_instance_valid(ship):
			continue
		var to_enemy: Vector2 = _enemy_pos - ship.global_position
		var dist: float = to_enemy.length()
		if dist > ship.view_distance:
			continue
		var diff: float = absf(angle_difference(ship.rotation, to_enemy.angle()))
		if diff <= deg_to_rad(ship.fov_degrees * 0.5):
			_intercept_dist = _enemy_pos.distance_to(EARTH_CENTER)
			return true
	return false

# ── End conditions ────────────────────────────────────────────────────────────
func _trigger_win():
	_phase = Phase.WIN
	_score = _calc_score()
	_phase_label.text = "INTERCEPTED!"
	_phase_label.add_theme_color_override("font_color", C_GREEN)
	_score_label.text = "SCORE  %d" % _score

	var max_dist: float = ARENA.length() * 0.5
	var dist_pct: float = clampf(_intercept_dist / max_dist, 0.0, 1.0)
	var dist_bonus: int = int(dist_pct * 300)
	var eff_bonus: int  = (MAX_DEF - _defenders.size()) * 80
	var time_bonus: int = max(0, 300 - int(_active_time * 15))

	var detail := "Enemy intercepted  %.1fs into the wave\n\n" % _active_time
	detail += "Base score              +1000\n"
	detail += "Efficiency (%d/%d drones)    +%d\n" % [_defenders.size(), MAX_DEF, eff_bonus]
	detail += "Intercept distance         +%d\n" % dist_bonus
	detail += "Speed bonus                +%d\n\n" % time_bonus
	detail += "TOTAL SCORE:  %d" % _score

	_show_result("MISSION SUCCESS", detail)

func _trigger_lose():
	_phase = Phase.LOSE
	_score = 0
	_phase_label.text = "PLANET DESTROYED"
	_phase_label.add_theme_color_override("font_color", C_RED)
	_score_label.text = "SCORE  0"

	var detail := "The enemy drone reached your planet!\n\n"
	detail += "Try adjusting defender positions\nor increasing vision range / FOV."

	_show_result("MISSION FAILED", detail)

func _calc_score() -> int:
	var base: int       = 1000
	var eff: int        = (MAX_DEF - _defenders.size()) * 80
	var dist_pct: float = clampf(_intercept_dist / (ARENA.length() * 0.5), 0.0, 1.0)
	var dist_b: int     = int(dist_pct * 300)
	var time_b: int     = max(0, 300 - int(_active_time * 15))
	return base + eff + dist_b + time_b

func _show_result(title: String, detail: String):
	_result_title.text  = title
	_result_detail.text = detail
	_result_panel.visible = true

# ── Actions ───────────────────────────────────────────────────────────────────
func _retry():
	get_tree().reload_current_scene()

func _leave():
	get_tree().change_scene_to_file("res://levels/LevelsScene.tscn")

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw():
	# Background
	draw_rect(Rect2(-500.0, -500.0, ARENA.x + 1000.0, ARENA.y + 1000.0), BG_COLOR)

	# Stars
	for s in _bg_stars:
		draw_rect(Rect2(s["pos"], Vector2(s["sz"], s["sz"])), Color(1, 1, 1, s["a"]))

	# Danger zone — thin red ring at Earth radius
	draw_arc(EARTH_CENTER, EARTH_RADIUS + 4.0, 0.0, TAU, 48,
		Color(1.0, 0.35, 0.35, 0.55), 1.5, true)

	if _phase == Phase.PLACE:
		# Placement zone: dashed outer boundary
		_draw_dashed_circle(EARTH_CENTER, PLACE_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
		# Inner exclusion ring (can't place too close)
		_draw_dashed_circle(EARTH_CENTER, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
		# Subtle fill showing valid placement zone
		draw_circle(EARTH_CENTER, PLACE_MAX, Color(0.451, 0.616, 1.0, 0.03))

	# Enemy
	if _phase == Phase.ACTIVE or _phase == Phase.WIN or _phase == Phase.LOSE:
		if _phase == Phase.ACTIVE:
			_draw_enemy(_enemy_pos, _enemy_dir.angle())
		# Draw enemy path line (faint)
		if _phase == Phase.ACTIVE:
			draw_line(_enemy_pos, EARTH_CENTER, Color(1.0, 0.35, 0.35, 0.12), 1.0, true)

func _draw_enemy(pos: Vector2, angle: float):
	var tip   := pos + Vector2(14.0, 0.0).rotated(angle)
	var back_a := pos + Vector2(-10.0, -7.0).rotated(angle)
	var back_b := pos + Vector2(-10.0,  7.0).rotated(angle)
	draw_colored_polygon(PackedVector2Array([tip, back_a, back_b]), C_RED)
	draw_polyline(PackedVector2Array([tip, back_a, back_b, tip]),
		Color(0.05, 0.05, 0.1, 1.0), 1.5, true)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float):
	var segs := 60
	for i in segs:
		if i % 3 == 0:
			continue
		var a0 := float(i)     / float(segs) * TAU
		var a1 := float(i + 1) / float(segs) * TAU
		draw_line(center + Vector2(radius, 0.0).rotated(a0),
			center + Vector2(radius, 0.0).rotated(a1), color, width, true)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String, size: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _panel(bg: Color, border: Color, bw: int, radius: int) -> PanelContainer:
	var pc    := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color            = bg
	style.border_color        = border
	style.border_width_left   = bw
	style.border_width_top    = bw
	style.border_width_right  = bw
	style.border_width_bottom = bw
	style.set_corner_radius_all(radius)
	style.content_margin_left   = 0.0
	style.content_margin_top    = 0.0
	style.content_margin_right  = 0.0
	style.content_margin_bottom = 0.0
	pc.add_theme_stylebox_override("panel", style)
	return pc
