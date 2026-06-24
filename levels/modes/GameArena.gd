extends Node2D

const SHIP := preload("res://entities/ship/Spaceship.tscn")
const STAR := preload("res://entities/star/Star.tscn")
const TERRAN := preload("res://entities/planet/PlanetTerran.tscn")

const ARENA := Vector2(2560, 1440)
const STAR_CENTER := Vector2(1280, 720)
const STAR_PIXELS := 110.0
const STAR_DISP := 270.0
const STAR_SEED := 7

const PLANET_PIXELS := 80.0
const PLANET_DISP := 200.0

const STAR_RADIUS := STAR_DISP * 0.5
const PLANET_RADIUS := PLANET_DISP * 0.5

const DEPLOY_ZONE := Rect2(90, 360, 460, 720)
const CAM_START := Vector2(720, 720)

const EDGE_THICKNESS := 16.0

const PROTECTOR_COUNT := 12
const PROTECTOR_RADIUS := 180.0
const PROTECTOR_SPEED := 0.4
const PROTECTOR_HP := 1.0

const RAIDER_COUNT := 6
const RAIDER_HP := 2.0

const RAIDER_PROGRAM := [
	{"type": "when_sees_enemy", "params": {}},
	{"type": "do_face", "params": {}},
	{"type": "do_fire", "params": {}},
	{"type": "when_sees_object", "params": {}},
	{"type": "do_turn_left", "params": {"value": 120.0}},
	{"type": "when_sees_rim", "params": {}},
	{"type": "do_turn_left", "params": {"value": 120.0}},
	{"type": "when_always", "params": {}},
	{"type": "do_wander", "params": {}},
	{"type": "do_forward", "params": {}},
]
const PLAYER_HP := 4.0
const MATCH_TIME := 90.0
const MAX_SHIPS := 5

const BG_COLOR := Color(0.04, 0.04, 0.07, 1.0)
const ZONE_FILL := Color(0.451, 0.616, 1.0, 0.07)
const ZONE_BORDER := Color(0.451, 0.616, 1.0, 0.5)
const ACCENT := Color(0.451, 0.616, 1.0, 1.0)

@onready var drag_indicator: Node2D = $DragIndicator
@onready var timer_label: Label = $HUD/Root/Timer
@onready var score_label: Label = $HUD/Root/Score
@onready var ships_label: Label = $HUD/Root/Ships
@onready var hint_label: Label = $HUD/Root/Hint
@onready var back_btn: Button = $HUD/Root/BackButton
@onready var result_panel: Control = $HUD/Root/Result
@onready var result_title: Label = $HUD/Root/Result/Panel/Margin/VBox/ResultTitle
@onready var result_detail: Label = $HUD/Root/Result/Panel/Margin/VBox/ResultDetail
@onready var return_btn: Button = $HUD/Root/Result/Panel/Margin/VBox/ReturnButton

var _time_left: float = MATCH_TIME
var _match_over: bool = false
var _total: int = 0
var _destroyed: int = 0
var _deployed: int = 0
var _player_alive: int = 0
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _bg_stars: Array = []
var _camera: Camera2D
var _panning: bool = false
var _edge_tex_bottom: Texture2D = null
var _edge_tex_top: Texture2D = null
var _edge_tex_left: Texture2D = null
var _edge_tex_right: Texture2D = null

const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0

func _ready():
	get_tree().paused = false
	_time_left = MATCH_TIME
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge_tex_bottom = load("res://assets/space_edge_bottom.png")
	_edge_tex_top = load("res://assets/space_edge_top.png")
	_edge_tex_left = load("res://assets/space_edge_left.png")
	_edge_tex_right = load("res://assets/space_edge_right.png")
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.position = CAM_START
	_camera.make_current()
	_clamp_camera()
	_make_bg_stars()
	_build_star()
	_build_planet()
	_spawn_protectors()
	_spawn_raiders()
	drag_indicator.z_index = 8
	drag_indicator.update_drag(false)
	back_btn.pressed.connect(_leave)
	return_btn.pressed.connect(_leave)
	_update_hud()
	queue_redraw()

func _process(delta: float):
	if _match_over:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_update_hud()
		_end_match()
		return
	_update_hud()

func _make_bg_stars():
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 380:
		_bg_stars.append({
			"pos": Vector2(rng.randf_range(0.0, ARENA.x), rng.randf_range(0.0, ARENA.y)),
			"sz": rng.randf_range(1.0, 2.0),
			"a": rng.randf_range(0.15, 0.6),
		})

func _build_star():
	var star := STAR.instantiate() as Control
	add_child(star)
	star.generate(STAR_SEED, STAR_PIXELS)
	star.z_index = 1
	var sc: float = STAR_DISP / STAR_PIXELS
	star.scale = Vector2(sc, sc)
	star.position = STAR_CENTER - Vector2(STAR_DISP * 0.5, STAR_DISP * 0.5)
	_disable_mouse(star)

func _build_planet():
	var planet := TERRAN.instantiate() as Control
	add_child(planet)
	planet.generate(PlayerData.planet_seed, PLANET_PIXELS)
	planet.z_index = 1
	var sc: float = PLANET_DISP / PLANET_PIXELS
	planet.scale = Vector2(sc, sc)
	planet.position = _zone_center() - Vector2(PLANET_DISP * 0.5, PLANET_DISP * 0.5)
	_disable_mouse(planet)

func _spawn_protectors():
	_total = PROTECTOR_COUNT
	for i in PROTECTOR_COUNT:
		var angle: float = float(i) * TAU / float(PROTECTOR_COUNT)
		var ship := SHIP.instantiate()
		ship.setup_protector(STAR_CENTER, PROTECTOR_RADIUS, PROTECTOR_SPEED, angle, PROTECTOR_HP)
		ship.arena_size = ARENA
		ship.destroyed.connect(_on_protector_destroyed)
		add_child(ship)

func _spawn_raiders():
	for i in RAIDER_COUNT:
		var ship := SHIP.instantiate()
		ship.setup_raider(RAIDER_PROGRAM, RAIDER_HP)
		ship.set_obstacles(STAR_CENTER, STAR_RADIUS, _zone_center(), PLANET_RADIUS)
		ship.arena_size = ARENA
		add_child(ship)
		var t: float = float(i) / float(RAIDER_COUNT - 1)
		ship.global_position = Vector2(ARENA.x - 220.0, ARENA.y * (0.22 + 0.56 * t))
		ship.rotation = PI

func _zone_center() -> Vector2:
	return DEPLOY_ZONE.position + DEPLOY_ZONE.size * 0.5

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.1)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(0.9)
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			return
	elif event is InputEventMouseMotion and _panning:
		_camera.position -= event.relative / _camera.zoom.x
		_clamp_camera()
		return

	if _match_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = get_global_mouse_position()
			if DEPLOY_ZONE.has_point(p) and _deployed < MAX_SHIPS:
				_dragging = true
				_drag_start = p
				drag_indicator.update_drag(true, "arrow", p, p, ACCENT)
		elif _dragging:
			_dragging = false
			drag_indicator.update_drag(false)
			_deploy(_drag_start, get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		drag_indicator.update_drag(true, "arrow", _drag_start, get_global_mouse_position(), ACCENT)

func _zoom_by(factor: float):
	var z: float = clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)
	_clamp_camera()

func _clamp_camera():
	var half: Vector2 = get_viewport_rect().size * 0.5 / _camera.zoom
	var min_x: float = half.x
	var max_x: float = ARENA.x - half.x
	var min_y: float = half.y
	var max_y: float = ARENA.y - half.y
	if min_x > max_x:
		_camera.position.x = ARENA.x * 0.5
	else:
		_camera.position.x = clampf(_camera.position.x, min_x, max_x)
	if min_y > max_y:
		_camera.position.y = ARENA.y * 0.5
	else:
		_camera.position.y = clampf(_camera.position.y, min_y, max_y)

func _deploy(start: Vector2, end: Vector2):
	if _deployed >= MAX_SHIPS:
		return
	var ship := SHIP.instantiate()
	ship.setup_player(PlayerData.ship_blocks, PLAYER_HP)
	ship.set_obstacles(STAR_CENTER, STAR_RADIUS, _zone_center(), PLANET_RADIUS)
	ship.arena_size = ARENA
	ship.destroyed.connect(_on_player_ship_destroyed)
	add_child(ship)
	var cfg: Dictionary = SimulationManager.ship_config_from_scripts(PlayerData.ship_blocks, ship.view_distance, ship.fov_degrees, ship.max_speed, ship.turn_rate, ship.hull_radius)
	ship.view_distance = cfg.view_distance
	ship.fov_degrees = cfg.fov_degrees
	ship.max_speed = cfg.speed
	ship.turn_rate = cfg.turn_speed
	ship.hull_radius = cfg.dot_radius
	ship.refresh_cone()
	ship.global_position = start
	if start.distance_to(end) > 6.0:
		ship.rotation = start.angle_to_point(end)
	else:
		ship.rotation = 0.0
	_deployed += 1
	_player_alive += 1
	_update_hud()

func _on_protector_destroyed(_ship):
	_destroyed += 1
	_update_hud()
	if _destroyed >= _total and not _match_over:
		_end_match()

func _on_player_ship_destroyed(_ship):
	_player_alive -= 1
	if not _match_over and _deployed >= MAX_SHIPS and _player_alive <= 0:
		_end_match(true)

func _end_match(defeated: bool = false):
	if _match_over:
		return
	_match_over = true
	_dragging = false
	drag_indicator.update_drag(false)
	var victory: bool = _destroyed >= _total
	var elapsed: float = MATCH_TIME - _time_left
	var coins: int = _destroyed * 5
	var xp: int = _destroyed * 10
	if victory:
		coins += 50
		xp += 100
		Leaderboard.submit_time(elapsed, PlayerData.get_ship_algorithm())
	if coins > 0:
		PlayerData.add_coins(coins)
	if xp > 0:
		PlayerData.add_xp(xp)
	if victory:
		result_title.text = "VICTORY"
	elif defeated:
		result_title.text = "DEFEAT"
	else:
		result_title.text = "TIME UP"
	var detail := "Protectors downed: %d / %d\n+%d XP   +%d AstroCoin" % [_destroyed, _total, xp, coins]
	if victory:
		detail += "\nTime: %.1fs" % elapsed
	elif defeated:
		detail += "\nFleet destroyed"
	result_detail.text = detail
	result_panel.visible = true

func _update_hud():
	var total_secs: int = int(ceil(_time_left))
	timer_label.text = "%d:%02d" % [total_secs / 60, total_secs % 60]
	score_label.text = "PROTECTORS %d / %d" % [_destroyed, _total]
	ships_label.text = "SHIPS LEFT %d / %d" % [MAX_SHIPS - _deployed, MAX_SHIPS]

func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_disable_mouse(c)

func _draw():
	draw_rect(Rect2(Vector2.ZERO, ARENA), BG_COLOR)
	for s in _bg_stars:
		draw_rect(Rect2(s["pos"], Vector2(s["sz"], s["sz"])), Color(1, 1, 1, s["a"]))
	draw_rect(DEPLOY_ZONE, ZONE_FILL, true)
	draw_rect(DEPLOY_ZONE, ZONE_BORDER, false, 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, DEPLOY_ZONE.position + Vector2(10.0, 22.0), "DEPLOY ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ZONE_BORDER)
	var hint_pos := Vector2(DEPLOY_ZONE.position.x, DEPLOY_ZONE.position.y + DEPLOY_ZONE.size.y - 16.0)
	draw_string(font, hint_pos, "Left-click + drag to launch", HORIZONTAL_ALIGNMENT_CENTER, DEPLOY_ZONE.size.x, 13, ZONE_BORDER)
	_draw_edges()

func _draw_edges():
	if _edge_tex_top == null or _edge_tex_bottom == null or _edge_tex_left == null or _edge_tex_right == null:
		return
	var t: float = EDGE_THICKNESS
	var w: float = ARENA.x
	var h: float = ARENA.y
	draw_texture_rect(_edge_tex_top, Rect2(0.0, 0.0, w, t), true)
	draw_texture_rect(_edge_tex_bottom, Rect2(0.0, h - t, w, t), true)
	draw_texture_rect(_edge_tex_left, Rect2(0.0, 0.0, t, h), true)
	draw_texture_rect(_edge_tex_right, Rect2(w - t, 0.0, t, h), true)

func _leave():
	get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn")
