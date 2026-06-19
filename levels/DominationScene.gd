extends Node2D

const SHIP   := preload("res://entities/ship/Spaceship.tscn")
const TERRAN := preload("res://entities/planet/PlanetTerran.tscn")

# ── Arena layout ─────────────────────────────────────────────────────────────
const ARENA          := Vector2(2560, 1440)
const HOME_CENTER    := Vector2(500.0, 720.0)
const HOME_PX        := 80.0
const HOME_DISP      := 200.0
const HOME_ORBIT_R   := 165.0
const HOME_ORBIT_SPD := 0.30
const HOME_ZONE_R    := 300.0

const ENEMY_CENTER    := Vector2(2060.0, 720.0)
const ENEMY_PX        := 80.0
const ENEMY_DISP      := 200.0
const ENEMY_ORBIT_R   := 165.0
const ENEMY_ORBIT_SPD := 0.45

# Enemy waves spawn in the neutral corridor (between defense and attack zones)
# so they are completely independent of the attack rectangle
const WAVE_SPAWN_X     := 1390.0   # neutral corridor x
const WAVE_SPAWN_X_VAR := 120.0    # slight x jitter so they don't stack

const INIT_DEF := 3
const MAX_DEF  := 5
const MAX_ATK  := 8
const DRONE_HP := 2.0

# ── Camera ───────────────────────────────────────────────────────────────────
const CAM_POS      := Vector2(1280.0, 720.0)
const CAM_ZOOM     := Vector2(0.50, 0.50)
const CAM_SLIDE_POS := Vector2(1800.0, 720.0)   # slide right on stage clear

# ── Colors ───────────────────────────────────────────────────────────────────
const BG_COLOR      := Color(0.04, 0.04, 0.07, 1.0)
const BLUE          := Color(0.451, 0.616, 1.0, 1.0)
const RED           := Color(1.0, 0.42, 0.32, 1.0)
const ZONE_DEF_FILL := Color(0.451, 0.616, 1.0, 0.06)
const ZONE_DEF_BDR  := Color(0.451, 0.616, 1.0, 0.45)
const ZONE_ATK_FILL := Color(1.0, 0.35, 0.35, 0.05)
const ZONE_ATK_BDR  := Color(1.0, 0.35, 0.35, 0.40)

# ── Programs ─────────────────────────────────────────────────────────────────
const ATTACK_PROG := [
	{"type": "when_sees_enemy", "params": {}},
	{"type": "do_face",         "params": {}},
	{"type": "do_fire",         "params": {}},
	{"type": "when_always",     "params": {}},
	{"type": "do_forward",      "params": {}},
]
const ENEMY_ATTACK_PROG := [
	{"type": "when_sees_enemy", "params": {}},
	{"type": "do_face",         "params": {}},
	{"type": "do_fire",         "params": {}},
	{"type": "when_always",     "params": {}},
	{"type": "do_forward",      "params": {}},
]

# ── HUD refs ─────────────────────────────────────────────────────────────────
@onready var timer_label:    Label   = $HUD/Root/Timer
@onready var score_label:    Label   = $HUD/Root/Score
@onready var ships_label:    Label   = $HUD/Root/Ships
@onready var hint_label:     Label   = $HUD/Root/Hint
@onready var back_btn:       Button  = $HUD/Root/BackButton
@onready var result_panel:   Control = $HUD/Root/Result
@onready var result_title:   Label   = $HUD/Root/Result/Panel/Margin/VBox/ResultTitle
@onready var result_detail:  Label   = $HUD/Root/Result/Panel/Margin/VBox/ResultDetail
@onready var return_btn:     Button  = $HUD/Root/Result/Panel/Margin/VBox/ReturnButton
@onready var drag_indicator: Node2D  = $DragIndicator
@onready var stage_label:    Label   = $HUD/Root/StageLabel
@onready var alert_panel:    Control = $HUD/Root/RedAlert
@onready var alert_msg:      Label   = $HUD/Root/RedAlert/Msg
@onready var coins_label:    Label   = $HUD/Root/CoinsLabel
@onready var market_btn:     Button  = $HUD/Root/MarketButton

# Attack zone rectangle matching the yellow dashed shape:
#   left ≈62% across arena (x≈1590), right near arena right (x≈2530)
#   top ≈6% (y≈90), bottom ≈95% (y≈1370)
# Enemy planet at (2060,720) sits inside. Wave spawns at x≈1390 are outside (left of rect).
const ATK_RECT   := Rect2(1590.0, 90.0, 940.0, 1280.0)
const ATK_HOLE_R := 230.0   # dashed circle around enemy planet (its guard exclusion zone)

# ── State ────────────────────────────────────────────────────────────────────
var _stage: int          = 0
var _time: float         = 0.0
var _active: bool        = false
var _game_over: bool     = false
var _transitioning: bool = false
var _alert_timer: float  = 0.0
const ALERT_DUR          := 4.5

var _enemy_total:  int = 0
var _enemy_killed: int = 0
var _placed_def:   int = 0
var _placed_atk:   int = 0
var _total_coins:  int = 0

var _camera: Camera2D
var _panning: bool       = false
var _dragging: bool      = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_zone: String   = ""

var _enemy_planet:   Control = null
var _bg_stars:       Array   = []
var _home_defenders: Array   = []
var _attack_drones:  Array   = []
var _wave_drones:    Array   = []

var _wave_triggered: bool = false
var _wave_timer: float    = 0.0

# ── Ready ────────────────────────────────────────────────────────────────────
func _ready():
	get_tree().paused = false
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.position = CAM_POS
	_camera.zoom     = CAM_ZOOM
	_camera.make_current()

	_make_bg_stars()
	_build_home_planet()
	_spawn_initial_defenders()

	back_btn.pressed.connect(_leave)
	return_btn.pressed.connect(_leave)
	market_btn.pressed.connect(func(): print("Market coming soon"))

	hint_label.text      = "Blue circle: drop defenders · Red zone: attack the enemy planet · Enemy wave arrives after your first move"
	result_panel.visible = false
	alert_panel.visible  = false
	coins_label.text     = ""

	_begin_stage()
	queue_redraw()

# ── Background ────────────────────────────────────────────────────────────────
func _make_bg_stars():
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321
	for _i in 420:
		_bg_stars.append({
			"pos": Vector2(rng.randf_range(0.0, ARENA.x), rng.randf_range(0.0, ARENA.y)),
			"sz":  rng.randf_range(1.0, 2.2),
			"a":   rng.randf_range(0.12, 0.55),
		})

# ── Planets ───────────────────────────────────────────────────────────────────
func _build_home_planet():
	var p := TERRAN.instantiate() as Control
	add_child(p)
	p.generate(PlayerData.planet_seed, HOME_PX)
	p.z_index = 1
	var sc := HOME_DISP / HOME_PX
	p.scale    = Vector2(sc, sc)
	p.position = HOME_CENTER - Vector2(HOME_DISP * 0.5, HOME_DISP * 0.5)
	_disable_mouse(p)

func _spawn_enemy_planet():
	if is_instance_valid(_enemy_planet):
		_enemy_planet.queue_free()
	var p := TERRAN.instantiate() as Control
	add_child(p)
	p.generate(_stage + 100, ENEMY_PX)
	p.z_index = 1
	var sc := ENEMY_DISP / ENEMY_PX
	p.scale    = Vector2(sc, sc)
	p.position = ENEMY_CENTER - Vector2(ENEMY_DISP * 0.5, ENEMY_DISP * 0.5)
	_disable_mouse(p)
	_enemy_planet = p

# ── Drone spawning ────────────────────────────────────────────────────────────
func _spawn_initial_defenders():
	for i in INIT_DEF:
		var angle := float(i) * TAU / float(INIT_DEF)
		_add_home_defender(angle, HOME_ORBIT_R)

func _add_home_defender(angle: float, radius: float):
	var ship := SHIP.instantiate()
	ship.setup_player_orbit(HOME_CENTER, radius, HOME_ORBIT_SPD, angle, DRONE_HP)
	ship.arena_size = ARENA
	add_child(ship)
	_home_defenders.append(ship)
	ship.destroyed.connect(_on_home_defender_killed)

func _spawn_enemy_guards():
	var count: int = 3 + _stage * 2
	_enemy_total  = count
	_enemy_killed = 0
	for i in count:
		var angle := float(i) * TAU / float(count)
		var ship  := SHIP.instantiate()
		ship.setup_protector(ENEMY_CENTER, ENEMY_ORBIT_R,
			ENEMY_ORBIT_SPD + float(_stage) * 0.05, angle, DRONE_HP)
		ship.arena_size = ARENA
		add_child(ship)
		ship.destroyed.connect(_on_enemy_killed)

func _place_attacker(pos: Vector2, rot: float):
	var ship := SHIP.instantiate()
	ship.setup_player(ATTACK_PROG, DRONE_HP)
	ship.ship_color = BLUE
	ship.set_obstacles(Vector2.ZERO, 0.0, ENEMY_CENTER, ENEMY_DISP * 0.5)
	ship.arena_size = ARENA
	add_child(ship)
	ship.global_position = pos
	ship.rotation = rot
	_attack_drones.append(ship)
	ship.destroyed.connect(_on_attack_drone_destroyed)

func _do_spawn_enemy_wave():
	# Spawns in the neutral corridor (left of attack zone, right of defense zone)
	# so wave drones are fully independent of the player's attack rectangle
	var count: int = 2 + _stage + randi_range(0, _stage + 1)
	for i in count:
		var ship := SHIP.instantiate()
		ship.setup_raider(ENEMY_ATTACK_PROG, DRONE_HP)
		ship.ship_color = RED
		ship.arena_size = ARENA
		add_child(ship)
		var t := float(i) / float(max(count - 1, 1))
		var sx := WAVE_SPAWN_X + randf_range(-WAVE_SPAWN_X_VAR, WAVE_SPAWN_X_VAR)
		ship.global_position = Vector2(sx, lerp(200.0, ARENA.y - 200.0, t))
		ship.rotation = PI   # face left — fly toward home planet
		_wave_drones.append(ship)
		ship.destroyed.connect(_on_wave_drone_destroyed)

# ── Stage flow ────────────────────────────────────────────────────────────────
func _begin_stage():
	for ship in _attack_drones.duplicate():
		if is_instance_valid(ship): ship.queue_free()
	_attack_drones.clear()
	for ship in _wave_drones.duplicate():
		if is_instance_valid(ship): ship.queue_free()
	_wave_drones.clear()

	_active         = true
	_placed_atk     = 0
	_placed_def     = 0
	_wave_triggered = false
	_wave_timer     = 0.0

	_spawn_enemy_planet()
	_spawn_enemy_guards()
	_update_hud()
	queue_redraw()

	# Slide camera back to centered split view
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_camera, "position", CAM_POS, 1.0)

func _on_home_defender_killed(ship):
	_home_defenders.erase(ship)
	queue_redraw()
	if _home_defenders.is_empty() and not _game_over:
		_trigger_game_over()

func _on_attack_drone_destroyed(ship):
	_attack_drones.erase(ship)
	_placed_atk = max(0, _placed_atk - 1)
	_update_hud()
	queue_redraw()

func _on_wave_drone_destroyed(ship):
	_wave_drones.erase(ship)

func _trigger_game_over():
	_game_over           = true
	_active              = false
	result_title.text    = "GAME OVER"
	result_detail.text   = "Your home planet fell!\n\nTotal AstroCoin earned: %d" % _total_coins
	result_panel.visible = true

func _on_enemy_killed(_ship):
	_enemy_killed += 1
	_update_hud()
	if _enemy_killed >= _enemy_total and _active:
		_active          = false
		var coins: int   = int(10.0 * pow(2.0, float(_stage)))
		PlayerData.add_coins(coins)
		_total_coins    += coins
		coins_label.text = "+%d AstroCoin  (Total: %d)" % [coins, _total_coins]
		_transitioning      = true
		_alert_timer        = ALERT_DUR
		if _stage == 0:
			alert_msg.text = "PLANET DOMINATED!\n+%d AstroCoin\n\nPrepare for Stage 1!" % coins
		else:
			alert_msg.text = "PLANET DOMINATED!\n+%d AstroCoin\n\nStage %d incoming…" % [coins, _stage + 1]
		alert_panel.visible = true

		# Camera slides RIGHT — "going deeper into space" (background is extended so no grey)
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_camera, "position", CAM_SLIDE_POS, 1.5)

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float):
	if _transitioning:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			_transitioning      = false
			alert_panel.visible = false
			_stage += 1
			_begin_stage()
		return

	if not _active or _game_over:
		return

	_time += delta
	_update_hud()

	if _wave_triggered and _wave_timer > 0.0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_do_spawn_enemy_wave()

	_check_attack_drones()
	_check_wave_drones()

func _check_attack_drones():
	for ship in _attack_drones.duplicate():
		if not is_instance_valid(ship):
			_attack_drones.erase(ship)
			continue
		var pos: Vector2 = ship.global_position
		if pos.x > ARENA.x - 30.0 or pos.x < 30.0 or pos.y < 30.0 or pos.y > ARENA.y - 30.0:
			_attack_drones.erase(ship)
			_placed_atk = max(0, _placed_atk - 1)
			ship.queue_free()
			_update_hud()
			queue_redraw()

func _check_wave_drones():
	for ship in _wave_drones.duplicate():
		if not is_instance_valid(ship):
			_wave_drones.erase(ship)
			continue
		var pos: Vector2 = ship.global_position
		if pos.x < HOME_CENTER.x:
			if _stage > 0:
				# Stage 1+: respawn from neutral corridor (continuous pressure)
				var sx := WAVE_SPAWN_X + randf_range(-WAVE_SPAWN_X_VAR, WAVE_SPAWN_X_VAR)
				ship.global_position = Vector2(sx, randf_range(200.0, ARENA.y - 200.0))
				ship.rotation = PI
			else:
				# Stage 0: single-pass — remove when they pass the home planet
				_wave_drones.erase(ship)
				ship.queue_free()

func _update_hud():
	var s := int(_time)
	timer_label.text = "%d:%02d" % [s / 60, s % 60]
	score_label.text = "Enemy Drones: %d / %d" % [_enemy_killed, _enemy_total]
	ships_label.text = "Attack: %d/%d   Defense: %d/%d" % [_placed_atk, MAX_ATK, _home_defenders.size(), MAX_DEF + INIT_DEF]
	stage_label.text = "Stage %d" % _stage

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera.zoom = (_camera.zoom * 0.9).clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			return
	elif event is InputEventMouseMotion and _panning:
		_camera.position -= event.relative / _camera.zoom.x
		return

	if not _active or _game_over:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2   = get_global_mouse_position()
			var in_def: bool = p.distance_to(HOME_CENTER) <= HOME_ZONE_R and _placed_def < MAX_DEF
			var in_atk: bool = ATK_RECT.has_point(p) \
				and p.distance_to(ENEMY_CENTER) > ATK_HOLE_R \
				and _placed_atk < MAX_ATK
			if in_def:
				_dragging   = true
				_drag_start = p
				_drag_zone  = "defense"
				drag_indicator.update_drag(true, "arrow", p, p, BLUE)
			elif in_atk:
				_dragging   = true
				_drag_start = p
				_drag_zone  = "attack"
				drag_indicator.update_drag(true, "arrow", p, p, RED)
		elif _dragging:
			_dragging = false
			drag_indicator.update_drag(false)
			_on_drag_release(_drag_start, get_global_mouse_position(), _drag_zone)
			_drag_zone = ""
	elif event is InputEventMouseMotion and _dragging:
		var col: Color = BLUE if _drag_zone == "defense" else RED
		drag_indicator.update_drag(true, "arrow", _drag_start, get_global_mouse_position(), col)

func _on_drag_release(start: Vector2, end: Vector2, zone: String):
	if zone == "defense":
		var r: float = clampf(HOME_CENTER.distance_to(start), 80.0, HOME_ZONE_R - 20.0)
		var a: float = HOME_CENTER.angle_to_point(start)
		_add_home_defender(a, r)
		_placed_def += 1
	else:
		var rot: float = start.angle_to_point(end) if start.distance_to(end) > 6.0 else 0.0
		_place_attacker(start, rot)
		_placed_atk += 1

	if not _wave_triggered and (_placed_def + _placed_atk) == 1:
		_wave_triggered = true
		_wave_timer     = randf_range(2.0, 3.0)

	_update_hud()
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw():
	# Extended background — fills well beyond arena so camera slide never shows grey
	draw_rect(Rect2(-2000.0, -2000.0, ARENA.x + 4000.0, ARENA.y + 4000.0), BG_COLOR)

	for s in _bg_stars:
		draw_rect(Rect2(s["pos"], Vector2(s["sz"], s["sz"])), Color(1, 1, 1, s["a"]))

	var font: Font = ThemeDB.fallback_font

	# Vertical divider for stage 1+ (shows home side vs enemy side)
	if _stage > 0:
		var mid_x: float = (HOME_CENTER.x + ENEMY_CENTER.x) * 0.5
		draw_line(Vector2(mid_x, 0.0), Vector2(mid_x, ARENA.y),
			Color(0.8, 0.8, 0.9, 0.10), 2.0, true)

	# Defense zone — blue circle around home planet
	draw_circle(HOME_CENTER, HOME_ZONE_R, ZONE_DEF_FILL)
	draw_arc(HOME_CENTER, HOME_ZONE_R, 0.0, TAU, 64, ZONE_DEF_BDR, 2.0, true)
	draw_string(font, HOME_CENTER + Vector2(-52.0, HOME_ZONE_R - 18.0),
		"DEFENSE %d/%d" % [_home_defenders.size(), MAX_DEF + INIT_DEF],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ZONE_DEF_BDR)

	# Attack zone — rectangle matching yellow dashed shape
	draw_rect(ATK_RECT, ZONE_ATK_FILL)
	draw_rect(ATK_RECT, ZONE_ATK_BDR, false, 2.0)
	# Dashed circle (the "hole") — enemy guard exclusion zone inside the rectangle
	var hole_segs := 48
	for i in hole_segs:
		var a0 := float(i)       / float(hole_segs) * TAU
		var a1 := float(i + 1)   / float(hole_segs) * TAU
		if i % 3 != 0:   # every third segment skipped → dashed look
			draw_line(ENEMY_CENTER + Vector2(ATK_HOLE_R, 0.0).rotated(a0),
				ENEMY_CENTER + Vector2(ATK_HOLE_R, 0.0).rotated(a1),
				ZONE_ATK_BDR, 1.5, true)
	draw_string(font, ATK_RECT.position + Vector2(8.0, 18.0),
		"ATTACK ZONE  %d/%d" % [_placed_atk, MAX_ATK],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ZONE_ATK_BDR)

# ── Helpers ───────────────────────────────────────────────────────────────────
func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)

func _leave():
	get_tree().change_scene_to_file("res://levels/PlayerBaseScene.tscn")
