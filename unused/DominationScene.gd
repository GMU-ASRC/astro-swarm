extends Node2D

const SHIP     := preload("res://entities/ship/Spaceship.tscn")
const TERRAN   := preload("res://entities/planet/PlanetTerran.tscn")
const FONT_REG := preload("res://assets/fonts/Silkscreen-Regular.ttf")

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
const ZONE_ATK_FILL := Color(0.451, 0.616, 1.0, 0.05)
const ZONE_ATK_BDR  := Color(0.451, 0.616, 1.0, 0.40)

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

# Launch zone — player's left side; attack drones placed here fly toward enemy
const ATK_RECT   := Rect2(30.0, 30.0, 980.0, 1380.0)
const ATK_HOLE_R := 320.0   # input exclusion radius around HOME_CENTER

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
var _music: AudioStreamPlayer = null
var _panning: bool       = false
var _dragging: bool      = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_zone: String   = ""

var _enemy_planet:   Control = null
var _bg_stars:       Array   = []
var _home_defenders: Array   = []
var _attack_drones:  Array   = []
var _wave_drones:    Array   = []
var _mini_drones:    Array   = []

var _wave_triggered: bool = false
var _wave_timer: float    = 0.0

const MARKET_PANEL := preload("res://levels/components/MarketPanel.gd")

# ── Role system ───────────────────────────────────────────────────────────────
enum Role { ATTACKER, DEFENDER }
var _role: Role = Role.ATTACKER
var _role_btn: OptionButton

# DEFENDER mode: player guards the right planet against left-side AI attackers
const DEF_ZONE_R      := 300.0
const DEF_WAVE_SPAWN_X := 150.0   # AI attackers spawn near left edge
const CAM_DEF_POS      := Vector2(1800.0, 720.0)

var _player_def_drones: Array = []  # player defenders around ENEMY_CENTER

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

	var stream := load("res://assets/music/domination challenge music.mp3") as AudioStreamMP3
	if stream:
		stream.loop = true
		_music = AudioStreamPlayer.new()
		_music.stream = stream
		_music.bus = "Music"
		add_child(_music)
		_music.play()

	back_btn.pressed.connect(_leave)
	return_btn.pressed.connect(_leave)
	market_btn.pressed.connect(_open_market)

	# Role dropdown — added programmatically so no .tscn edits needed
	_role_btn = OptionButton.new()
	_role_btn.add_item("ATTACKER", Role.ATTACKER)
	_role_btn.add_item("DEFENDER", Role.DEFENDER)
	_role_btn.selected = Role.ATTACKER
	_role_btn.add_theme_font_override("font", FONT_REG)
	_role_btn.add_theme_font_size_override("font_size", 12)
	_role_btn.focus_mode = Control.FOCUS_NONE
	_role_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_role_btn.offset_left   = 16
	_role_btn.offset_top    = 52
	_role_btn.offset_right  = 180
	_role_btn.offset_bottom = 80
	_role_btn.item_selected.connect(_on_role_changed)
	$HUD/Root.add_child(_role_btn)

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

# ── Role switching ────────────────────────────────────────────────────────────
func _on_role_changed(index: int):
	if _active and not _game_over:
		_role_btn.selected = _role  # revert if mid-game
		return
	_role = index as Role
	# Full reset
	_stage       = 0
	_time        = 0.0
	_total_coins = 0
	_game_over   = false
	result_panel.visible = false
	alert_panel.visible  = false
	_clear_all_drones()
	if _role == Role.DEFENDER:
		hint_label.text = "DEFENDER ROLE: drop your defenders in the blue zone around the right planet · Stop AI attackers from reaching it"
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_camera, "position", CAM_DEF_POS, 0.8)
	else:
		hint_label.text = "Blue circle: drop defenders · Red zone: attack the enemy planet · Enemy wave arrives after your first move"
		var tw := create_tween()
		tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_camera, "position", CAM_POS, 0.8)
	_begin_stage()

func _clear_all_drones():
	for arr in [_home_defenders, _attack_drones, _wave_drones, _mini_drones, _player_def_drones]:
		for ship in arr:
			if is_instance_valid(ship): ship.queue_free()
	_home_defenders.clear()
	_attack_drones.clear()
	_wave_drones.clear()
	_mini_drones.clear()
	_player_def_drones.clear()
	_placed_def = 0
	_placed_atk = 0

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
	ship.setup_player_orbit(HOME_CENTER, radius, HOME_ORBIT_SPD, angle, _drone_hp())
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

func _add_player_right_defender(angle: float, radius: float):
	var ship := SHIP.instantiate()
	ship.setup_player_orbit(ENEMY_CENTER, radius, HOME_ORBIT_SPD, angle, _drone_hp())
	ship.arena_size = ARENA
	add_child(ship)
	_player_def_drones.append(ship)
	ship.destroyed.connect(_on_player_def_destroyed)

func _on_player_def_destroyed(ship):
	_player_def_drones.erase(ship)
	queue_redraw()
	if _player_def_drones.is_empty() and not _game_over and _role == Role.DEFENDER:
		_trigger_game_over()

func _place_attacker(pos: Vector2, rot: float):
	var ship := SHIP.instantiate()
	ship.setup_player(PlayerData.get_ship_algorithm(), _drone_hp())
	ship.speed_mult = _drone_speed_mult()
	ship.ship_color = BLUE
	ship.set_obstacles(Vector2.ZERO, 0.0, ENEMY_CENTER, ENEMY_DISP * 0.5)
	ship.arena_size = ARENA
	add_child(ship)
	ship.global_position = pos
	ship.rotation = rot
	_attack_drones.append(ship)
	ship.destroyed.connect(_on_attack_drone_destroyed)

func _do_spawn_enemy_wave():
	var count: int = 2 + _stage + randi_range(0, _stage + 1)
	if _role == Role.DEFENDER:
		_enemy_total  = count
		_enemy_killed = 0
	for i in count:
		var ship := SHIP.instantiate()
		ship.setup_raider(ENEMY_ATTACK_PROG, DRONE_HP)
		ship.ship_color = RED
		ship.arena_size = ARENA
		add_child(ship)
		var t := float(i) / float(max(count - 1, 1))
		if _role == Role.DEFENDER:
			# Attackers spawn near left edge and head RIGHT toward the right planet
			ship.global_position = Vector2(DEF_WAVE_SPAWN_X + randf_range(-40.0, 40.0),
				lerp(200.0, ARENA.y - 200.0, t))
			ship.rotation = 0.0  # face right
		else:
			# Standard: spawn in neutral corridor, head left toward home planet
			var sx := WAVE_SPAWN_X + randf_range(-WAVE_SPAWN_X_VAR, WAVE_SPAWN_X_VAR)
			ship.global_position = Vector2(sx, lerp(200.0, ARENA.y - 200.0, t))
			ship.rotation = PI
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
	for ship in _mini_drones.duplicate():
		if is_instance_valid(ship): ship.queue_free()
	_mini_drones.clear()

	_active         = true
	_placed_atk     = 0
	_placed_def     = 0
	_wave_triggered = false
	_wave_timer     = 0.0

	_spawn_enemy_planet()
	if _role == Role.ATTACKER:
		_spawn_enemy_guards()
	# DEFENDER: player places their own defenders; no AI guards around right planet
	_update_hud()
	queue_redraw()

	# Slide camera to appropriate position
	var target_cam := CAM_DEF_POS if _role == Role.DEFENDER else CAM_POS
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_camera, "position", target_cam, 1.0)

func _on_home_defender_killed(ship):
	_home_defenders.erase(ship)
	queue_redraw()
	if _home_defenders.is_empty() and not _game_over:
		_trigger_game_over()

func _on_attack_drone_destroyed(ship):
	var death_pos: Vector2 = ship.global_position if is_instance_valid(ship) else Vector2.ZERO
	_attack_drones.erase(ship)
	_placed_atk = max(0, _placed_atk - 1)
	_update_hud()
	queue_redraw()
	if DominationData.death_spawn and death_pos != Vector2.ZERO:
		_spawn_nano_drones(death_pos)

func _on_wave_drone_destroyed(ship):
	_wave_drones.erase(ship)
	if _role == Role.DEFENDER and _active:
		_enemy_killed += 1
		_update_hud()
		if _enemy_killed >= _enemy_total:
			_on_enemy_killed(null)  # reuse stage-clear logic

func _trigger_game_over():
	_game_over           = true
	_active              = false
	_role_btn.disabled   = false
	if _role == Role.DEFENDER:
		result_title.text  = "GAME OVER"
		result_detail.text = "An attacker reached your planet!\n\nTotal Market Tokens earned: %d" % _total_coins
	else:
		result_title.text  = "GAME OVER"
		result_detail.text = "Your home planet fell!\n\nTotal Market Tokens earned: %d" % _total_coins
	result_panel.visible = true

func _on_enemy_killed(_ship):
	_enemy_killed += 1
	_update_hud()
	if _enemy_killed >= _enemy_total and _active:
		_active          = false
		var coins: int   = int(10.0 * pow(2.0, float(_stage)))
		DominationData.add_tokens(coins)
		_total_coins    += coins
		coins_label.text = "+%d Market Tokens  (Total: %d)" % [coins, _total_coins]
		_transitioning      = true
		_alert_timer        = ALERT_DUR
		_role_btn.disabled  = false
		if _stage == 0:
			alert_msg.text = "PLANET DOMINATED!\n+%d Market Tokens\n\nPrepare for Stage 1!" % coins
		else:
			alert_msg.text = "PLANET DOMINATED!\n+%d Market Tokens\n\nStage %d incoming…" % [coins, _stage + 1]
		alert_panel.visible = true

		# Camera slides RIGHT — "going deeper into space" (background is extended so no gray)
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
	_check_nano_drones()

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
		if _role == Role.DEFENDER:
			# Attacker reached the right planet → game over
			if pos.distance_to(ENEMY_CENTER) <= ENEMY_DISP * 0.5 + 20.0:
				_trigger_game_over()
				return
			# Overshot right edge → respawn from left for continuous pressure (stage 1+)
			if pos.x > ARENA.x - 50.0:
				if _stage > 0:
					ship.global_position = Vector2(DEF_WAVE_SPAWN_X + randf_range(-40.0, 40.0),
						randf_range(200.0, ARENA.y - 200.0))
					ship.rotation = 0.0
				else:
					_wave_drones.erase(ship)
					ship.queue_free()
		else:
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
	stage_label.text = "Stage %d" % _stage
	if _role == Role.DEFENDER:
		score_label.text = "Attackers Down: %d / %d" % [_enemy_killed, _enemy_total]
		ships_label.text = "Defense: %d/%d" % [_player_def_drones.size(), MAX_DEF + INIT_DEF]
	else:
		score_label.text = "Enemy Drones: %d / %d" % [_enemy_killed, _enemy_total]
		ships_label.text = "Attack: %d/%d   Defense: %d/%d" % [_placed_atk, MAX_ATK, _home_defenders.size(), MAX_DEF + INIT_DEF]

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
			var p: Vector2 = get_global_mouse_position()
			var in_def: bool
			var in_atk: bool
			if _role == Role.DEFENDER:
				in_def = p.distance_to(ENEMY_CENTER) <= DEF_ZONE_R and _placed_def < MAX_DEF
				in_atk = false
			else:
				in_def = p.distance_to(HOME_CENTER) <= HOME_ZONE_R and _placed_def < MAX_DEF
				in_atk = ATK_RECT.has_point(p) \
					and p.distance_to(HOME_CENTER) > ATK_HOLE_R \
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
		if _role == Role.DEFENDER:
			var r: float = clampf(ENEMY_CENTER.distance_to(start), 80.0, DEF_ZONE_R - 20.0)
			var a: float = ENEMY_CENTER.angle_to_point(start)
			_add_player_right_defender(a, r)
		else:
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
		_role_btn.disabled = true  # lock role once game starts

	_update_hud()
	queue_redraw()

# ── Drawing ───────────────────────────────────────────────────────────────────
func _draw():
	# Extended background — fills well beyond arena so camera slide never shows gray
	draw_rect(Rect2(-2000.0, -2000.0, ARENA.x + 4000.0, ARENA.y + 4000.0), BG_COLOR)

	for s in _bg_stars:
		draw_rect(Rect2(s["pos"], Vector2(s["sz"], s["sz"])), Color(1, 1, 1, s["a"]))

	var font: Font = ThemeDB.fallback_font

	# Vertical divider for stage 1+ (shows home side vs enemy side)
	if _stage > 0:
		var mid_x: float = (HOME_CENTER.x + ENEMY_CENTER.x) * 0.5
		draw_line(Vector2(mid_x, 0.0), Vector2(mid_x, ARENA.y),
			Color(0.8, 0.8, 0.9, 0.10), 2.0, true)

	if _role == Role.DEFENDER:
		# DEFENDER: blue zone around right planet (player defends it)
		draw_circle(ENEMY_CENTER, DEF_ZONE_R, ZONE_DEF_FILL)
		draw_arc(ENEMY_CENTER, DEF_ZONE_R, 0.0, TAU, 64, ZONE_DEF_BDR, 2.0, true)
		draw_string(font, ENEMY_CENTER + Vector2(-52.0, DEF_ZONE_R - 18.0),
			"DEFENSE %d/%d" % [_player_def_drones.size(), MAX_DEF + INIT_DEF],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ZONE_DEF_BDR)
	else:
		# ATTACKER: blue zone around home planet + launch zone on left
		draw_circle(HOME_CENTER, HOME_ZONE_R, ZONE_DEF_FILL)
		draw_arc(HOME_CENTER, HOME_ZONE_R, 0.0, TAU, 64, ZONE_DEF_BDR, 2.0, true)
		draw_string(font, HOME_CENTER + Vector2(-52.0, HOME_ZONE_R - 18.0),
			"DEFENSE %d/%d" % [_home_defenders.size(), MAX_DEF + INIT_DEF],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ZONE_DEF_BDR)
		draw_rect(ATK_RECT, ZONE_ATK_FILL)
		draw_rect(ATK_RECT, ZONE_ATK_BDR, false, 1.5)
		draw_string(font, ATK_RECT.position + Vector2(8.0, 18.0),
			"LAUNCH ZONE  %d/%d" % [_placed_atk, MAX_ATK],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ZONE_ATK_BDR)

# ── Upgrade helpers ───────────────────────────────────────────────────────────
func _drone_speed_mult() -> float:
	return 1.0 + DominationData.speed_level * 0.10

func _drone_hp() -> float:
	return DRONE_HP * (1.0 + DominationData.health_level * 0.25)

# ── Nano drone (Death Spawn) ──────────────────────────────────────────────────
func _spawn_nano_drones(pos: Vector2):
	for i in 2:
		var nano := SHIP.instantiate()
		nano.setup_player(ATTACK_PROG, 0.75)
		nano.speed_mult = 1.5
		nano.ship_color = Color(0.55, 0.90, 1.0, 1.0)
		nano.set_obstacles(Vector2.ZERO, 0.0, ENEMY_CENTER, ENEMY_DISP * 0.5)
		nano.arena_size = ARENA
		add_child(nano)
		nano.scale = Vector2(0.6, 0.6)
		nano.global_position = pos + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		nano.rotation = randf_range(0.0, TAU)
		_mini_drones.append(nano)
		nano.destroyed.connect(_on_nano_destroyed)

func _on_nano_destroyed(nano):
	_mini_drones.erase(nano)

func _check_nano_drones():
	if _mini_drones.is_empty() or not DominationData.kamikaze:
		return
	for nano in _mini_drones.duplicate():
		if not is_instance_valid(nano):
			_mini_drones.erase(nano)
			continue
		for ship in get_tree().get_nodes_in_group("ships"):
			if not is_instance_valid(ship) or ship.team == nano.team:
				continue
			if nano.global_position.distance_to(ship.global_position) < 65.0:
				_explode_nano(nano)
				break

func _explode_nano(nano):
	if not is_instance_valid(nano):
		return
	var pos: Vector2 = nano.global_position
	_mini_drones.erase(nano)
	nano.queue_free()
	for ship in get_tree().get_nodes_in_group("ships"):
		if not is_instance_valid(ship) or ship.team == 0:
			continue
		if ship.global_position.distance_to(pos) < 90.0:
			ship.take_damage(1.5)

# ── Market ────────────────────────────────────────────────────────────────────
func _open_market():
	var panel := MARKET_PANEL.new()
	add_child(panel)
	panel.closed.connect(func(): market_btn.disabled = false)
	market_btn.disabled = true

# ── Helpers ───────────────────────────────────────────────────────────────────
func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)

func _leave():
	if is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file("res://levels/menus/LevelsScene.tscn")
