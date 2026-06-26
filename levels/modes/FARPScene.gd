extends Node2D

const SHIP           := preload("res://entities/ship/Spaceship.tscn")
const TERRAN         := preload("res://entities/planet/PlanetTerran.tscn")
const DRAG_INDICATOR := preload("res://levels/components/DragIndicator.tscn")
const RADIAL_MENU    := preload("res://ui/hud/RadialMenu.tscn")
const SHIP_WORKSPACE := preload("res://ui/workspace/ShipWorkspace.gd")
const FONT_REG       := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME     := preload("res://ui/GameTheme.tres")

const ARENA         := Vector2(3840.0, 2160.0)
const PLANET_CENTER := Vector2(1920.0, 1080.0)
const PLANET_PIXELS := 80.0
const PLANET_DISP   := 240.0
const PLANET_RADIUS := PLANET_DISP * 0.5

const PLACE_MIN     := PLANET_RADIUS + 50.0
const PLACE_MAX     := 465.0
const MAX_DEFENDERS := 6
const DEFENDER_HP   := 99.0

const ENEMY_HP    := 3.0
const ENEMY_SPEED := 105.0
const ENEMY_PROGRAM := [
	{"type": "when_always", "params": {}},
	{"type": "do_forward", "params": {}},
]

const EDGE_THICKNESS := 16.0
const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.5

const BG_COLOR    := Color(0.04, 0.04, 0.07, 1.0)
const ZONE_FILL   := Color(0.451, 0.616, 1.0, 0.05)
const ZONE_BORDER := Color(0.451, 0.616, 1.0, 0.5)
const ACCENT      := Color(0.451, 0.616, 1.0, 1.0)
const C_TEXT      := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM       := Color(0.6, 0.62, 0.74, 1.0)
const C_RED       := Color(1.0, 0.42, 0.32, 1.0)
const C_GREEN     := Color(0.40, 0.85, 0.45, 1.0)
const C_BORDER    := Color(0.318, 0.306, 0.463, 1.0)

const TUTORIAL_FLAG := "farp_tutorial_seen"

const PLACE_HINT := "Drag inside the blue ring to place a defender and aim its vision cone  ·  Right-click a defender to remove it  ·  Program how they scan in WORKSPACE  ·  Press LAUNCH DRONE to start the wave  ·  Scroll to zoom, middle-drag to pan"
const ACTIVE_HINT := "Your defenders run their workspace program. Catch the drone in a vision cone before it reaches the planet."
const TEST_HINT := "Defenders run their workspace program with no enemy spawned. Press RESTART to edit placements."

enum Phase { PLACE, ACTIVE, TEST, WIN, LOSE }
var _phase: Phase = Phase.PLACE

var _placements: Array = []
var _defender_ships: Array = []
var _enemy: Node2D = null
var _active_time: float = 0.0

var _radial: CanvasLayer
var _radial_target: Node2D = null
var _music: AudioStreamPlayer = null

static var _persisted_placements: Array = []

var _camera: Camera2D
var _panning: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _bg_stars: Array = []
var _drag_indicator: Node2D

var _edge_tex_top: Texture2D
var _edge_tex_bottom: Texture2D
var _edge_tex_left: Texture2D
var _edge_tex_right: Texture2D

var _phase_label: Label
var _timer_label: Label
var _count_label: Label
var _hint_label: Label
var _launch_btn: Button
var _clear_btn: Button
var _result_panel: Control
var _result_title: Label
var _result_detail: Label
var _tutorial_panel: Control

func _ready():
	get_tree().paused = false
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge_tex_top = load("res://assets/space_edge_top.png")
	_edge_tex_bottom = load("res://assets/space_edge_bottom.png")
	_edge_tex_left = load("res://assets/space_edge_left.png")
	_edge_tex_right = load("res://assets/space_edge_right.png")

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.position = PLANET_CENTER
	_camera.zoom = Vector2(0.5, 0.5)
	_camera.make_current()
	_clamp_camera()

	_make_bg_stars()
	_build_planet()
	_start_music()

	_drag_indicator = DRAG_INDICATOR.instantiate()
	_drag_indicator.z_index = 8
	add_child(_drag_indicator)
	_drag_indicator.update_drag(false)

	_build_hud()

	_radial = RADIAL_MENU.instantiate()
	add_child(_radial)
	_radial.PANEL_BG     = Color(0.129, 0.122, 0.196, 1.0)
	_radial.PANEL_BORDER = C_BORDER
	_radial.SLICE_BG     = Color(0.09, 0.085, 0.145, 1.0)
	_radial.SEP_COLOR    = C_BORDER
	_radial.TEXT_DARK    = C_TEXT
	_radial.TEXT_MUTED   = C_DIM
	_radial.label_font   = FONT_REG
	_radial.action_selected.connect(_on_radial_action)
	_radial.menu_closed.connect(func(): _radial_target = null)

	_restore_placements()
	queue_redraw()

	if not PlayerSettings.get_flag(TUTORIAL_FLAG):
		PlayerSettings.set_flag(TUTORIAL_FLAG, true)
		_show_tutorial()

func _start_music():
	var stream := load("res://assets/music/domination challenge music.mp3") as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = "Music"
	add_child(_music)
	_music.play()

func _restore_placements():
	var source: Array = _persisted_placements if not _persisted_placements.is_empty() else _placements_from_disk()
	for placement in source:
		var p: Dictionary = {"pos": placement.pos, "rot": placement.rot}
		_placements.append(p)
		_spawn_defender(p, false)
	_update_count()

func _placements_from_disk() -> Array:
	var out: Array = []
	for p in PlayerData.get_farp_placements():
		out.append({"pos": Vector2(p.get("x", 0.0), p.get("y", 0.0)), "rot": p.get("rot", 0.0)})
	return out

func _save_placements_to_disk():
	var out: Array = []
	for placement in _placements:
		out.append({"x": placement.pos.x, "y": placement.pos.y, "rot": placement.rot})
	PlayerData.set_farp_placements(out)

func _make_bg_stars():
	var rng := RandomNumberGenerator.new()
	rng.seed = 77421
	for _i in 500:
		_bg_stars.append({
			"pos": Vector2(rng.randf_range(0.0, ARENA.x), rng.randf_range(0.0, ARENA.y)),
			"sz":  rng.randf_range(1.0, 2.2),
			"a":   rng.randf_range(0.12, 0.55),
		})

func _build_planet():
	var planet := TERRAN.instantiate() as Control
	add_child(planet)
	planet.generate(PlayerData.planet_seed, PLANET_PIXELS)
	planet.z_index = 2
	var sc: float = PLANET_DISP / PLANET_PIXELS
	planet.scale = Vector2(sc, sc)
	planet.position = PLANET_CENTER - Vector2(PLANET_DISP * 0.5, PLANET_DISP * 0.5)
	_disable_mouse(planet)

func _process(delta: float):
	if _phase == Phase.ACTIVE:
		_active_time += delta
		_timer_label.text = "%.1fs" % _active_time
		if not is_instance_valid(_enemy):
			_trigger_win()
			return
		if _any_defender_sees_enemy():
			_trigger_win()
			return
		if _enemy.global_position.distance_to(PLANET_CENTER) <= PLANET_RADIUS + 16.0:
			_trigger_lose()
			return
	queue_redraw()

func _any_defender_sees_enemy() -> bool:
	if not is_instance_valid(_enemy):
		return false
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		var to_enemy: Vector2 = _enemy.global_position - ship.global_position
		if to_enemy.length() > ship.view_distance:
			continue
		var diff: float = absf(angle_difference(ship.rotation, to_enemy.angle()))
		if diff <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

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

	if _phase != Phase.PLACE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var ship := _defender_at(get_global_mouse_position())
		if ship != null:
			_radial_target = ship
			var actions: Array = [{"id": "remove", "label": "Remove", "color": Color(0.8, 0.25, 0.25, 1.0)}]
			_radial.open(get_viewport().get_mouse_position(), actions, "Defender")
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var p: Vector2 = get_global_mouse_position()
			if _can_place(p) and _placements.size() < MAX_DEFENDERS:
				_dragging = true
				_drag_start = p
				_drag_indicator.update_drag(true, "arrow", p, p, ACCENT)
		elif _dragging:
			_dragging = false
			_drag_indicator.update_drag(false)
			_place_defender(_drag_start, get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		_drag_indicator.update_drag(true, "arrow", _drag_start, get_global_mouse_position(), ACCENT)

func _can_place(p: Vector2) -> bool:
	var dist: float = p.distance_to(PLANET_CENTER)
	return dist >= PLACE_MIN and dist <= PLACE_MAX

func _place_defender(start: Vector2, end: Vector2):
	if _placements.size() >= MAX_DEFENDERS:
		return
	var rot: float = start.angle_to_point(end) if start.distance_to(end) > 6.0 else 0.0
	var placement := {"pos": start, "rot": rot}
	_placements.append(placement)
	_spawn_defender(placement, false)
	_update_count()
	queue_redraw()

func _spawn_defender(placement: Dictionary, running: bool):
	var ship := SHIP.instantiate()
	ship.setup_player(PlayerData.ship_blocks, DEFENDER_HP)
	ship.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	ship.collisions_enabled = false
	ship.arena_size = ARENA
	ship.can_fire = false
	ship.show_health = false
	add_child(ship)
	var cfg: Dictionary = SimulationManager.ship_config_from_scripts(PlayerData.ship_blocks, ship.view_distance, ship.fov_degrees, ship.max_speed, ship.turn_rate, ship.hull_radius)
	ship.view_distance = cfg.view_distance
	ship.fov_degrees = cfg.fov_degrees
	ship.max_speed = cfg.speed
	ship.turn_rate = cfg.turn_speed
	ship.hull_radius = cfg.dot_radius
	ship.refresh_cone()
	ship.global_position = placement.pos
	ship.rotation = placement.rot
	ship.set_meta("placement", placement)
	ship.set_physics_process(running)
	_defender_ships.append(ship)

func _defender_at(world_pos: Vector2) -> Node2D:
	for ship in _defender_ships:
		if is_instance_valid(ship) and ship.global_position.distance_to(world_pos) <= 16.0:
			return ship
	return null

func _on_radial_action(action_id: String):
	if action_id == "remove" and is_instance_valid(_radial_target):
		_placements.erase(_radial_target.get_meta("placement"))
		_defender_ships.erase(_radial_target)
		_radial_target.queue_free()
		_update_count()
		queue_redraw()
	_radial_target = null

func _clear_defenders():
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	_defender_ships.clear()
	_placements.clear()
	_radial_target = null
	if _radial != null:
		_radial.visible = false
	_update_count()
	queue_redraw()

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

func _launch():
	if _placements.is_empty():
		_hint_label.text = "Place at least one defender first!"
		return
	_phase = Phase.ACTIVE
	_launch_btn.visible = false
	_clear_btn.disabled = true
	_phase_label.text = "INTERCEPTING..."
	_hint_label.text = ACTIVE_HINT
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(true)
	_spawn_enemy()
	queue_redraw()

func _test_run():
	if _placements.is_empty():
		_hint_label.text = "Place at least one defender first!"
		return
	_phase = Phase.TEST
	_launch_btn.visible = false
	_clear_btn.disabled = true
	_phase_label.text = "TESTING..."
	_phase_label.add_theme_color_override("font_color", ACCENT)
	_hint_label.text = TEST_HINT
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(true)
	queue_redraw()

func _spawn_enemy():
	var margin := 40.0
	var spawn_pos: Vector2
	match randi() % 4:
		0: spawn_pos = Vector2(randf_range(margin, ARENA.x - margin), margin)
		1: spawn_pos = Vector2(randf_range(margin, ARENA.x - margin), ARENA.y - margin)
		2: spawn_pos = Vector2(margin, randf_range(margin, ARENA.y - margin))
		_: spawn_pos = Vector2(ARENA.x - margin, randf_range(margin, ARENA.y - margin))

	_enemy = SHIP.instantiate()
	_enemy.setup_raider(ENEMY_PROGRAM, ENEMY_HP)
	_enemy.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	_enemy.collisions_enabled = false
	_enemy.arena_size = ARENA
	_enemy.show_health = false
	_enemy.speed_mult = ENEMY_SPEED / 150.0
	add_child(_enemy)
	_enemy.global_position = spawn_pos
	_enemy.rotation = (PLANET_CENTER - spawn_pos).angle()

func _placements_payload() -> Array:
	var out: Array = []
	for placement in _placements:
		out.append({"x": placement.pos.x, "y": placement.pos.y, "rot": placement.rot})
	return out

func _trigger_win():
	_phase = Phase.WIN
	if is_instance_valid(_enemy):
		_enemy.queue_free()
		_enemy = null
	_stop_all_ships()
	EvalUploader.submit(PlayerData.ship_blocks, _placements_payload(), "farp")
	_phase_label.text = "INTERCEPTED!"
	_phase_label.add_theme_color_override("font_color", C_GREEN)
	var detail := "Drone destroyed %.1fs into the wave.\n\nThe planet is safe." % _active_time
	_show_result("MISSION SUCCESS", detail)

func _trigger_lose():
	_phase = Phase.LOSE
	_stop_all_ships()
	_phase_label.text = "PLANET HIT"
	_phase_label.add_theme_color_override("font_color", C_RED)
	var detail := "The drone reached your planet!\n\nReposition your defenders or edit\ntheir program in the workspace."
	_show_result("MISSION FAILED", detail)

func _stop_all_ships():
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(false)
	if is_instance_valid(_enemy):
		_enemy.set_physics_process(false)

func _show_result(title: String, detail: String):
	_result_title.text = title
	_result_detail.text = detail
	_result_panel.visible = true

func _build_hud():
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GAME_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("separation", 6)
	top.offset_left = 12
	top.offset_top = 12
	top.offset_right = -12
	top.offset_bottom = 40
	root.add_child(top)

	var leave_btn := _make_compact_btn("← LEAVE")
	leave_btn.pressed.connect(_leave)
	top.add_child(leave_btn)

	var workspace_btn := _make_compact_btn("WORKSPACE")
	workspace_btn.pressed.connect(_open_workspace)
	top.add_child(workspace_btn)

	var test_btn := _make_compact_btn("TEST")
	test_btn.pressed.connect(_test_run)
	top.add_child(test_btn)

	var restart_btn := _make_compact_btn("RESTART")
	restart_btn.pressed.connect(_restart)
	top.add_child(restart_btn)

	_clear_btn = _make_compact_btn("CLEAR")
	_clear_btn.pressed.connect(_clear_defenders)
	top.add_child(_clear_btn)

	var help_btn := _make_compact_btn("? HELP")
	help_btn.pressed.connect(_show_tutorial)
	top.add_child(help_btn)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	_timer_label = _lbl("0.0s", 22, C_TEXT)
	top.add_child(_timer_label)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 16
	left.offset_top = 58
	root.add_child(left)

	_phase_label = _lbl("PLACE DEFENDERS", 13, ACCENT)
	left.add_child(_phase_label)

	_count_label = _lbl("DEFENDERS: 0 / %d" % MAX_DEFENDERS, 11, C_DIM)
	left.add_child(_count_label)

	_launch_btn = _make_btn("LAUNCH DRONE →", 11)
	_launch_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_launch_btn.offset_left = -210
	_launch_btn.offset_top = -54
	_launch_btn.offset_right = -16
	_launch_btn.offset_bottom = -16
	_launch_btn.pressed.connect(_launch)
	root.add_child(_launch_btn)

	_hint_label = _lbl(PLACE_HINT, 10, C_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.offset_left = 16
	_hint_label.offset_top = -120
	_hint_label.offset_right = 320
	_hint_label.offset_bottom = -14
	root.add_child(_hint_label)

	_build_result_panel(root)
	_build_tutorial_panel(root)

func _build_result_panel(root: Control):
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
	rcard.offset_left = -240
	rcard.offset_top = -160
	rcard.offset_right = 240
	rcard.offset_bottom = 160
	_result_panel.add_child(rcard)

	var rmar := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
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

	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	rvb.add_child(sep)

	var rbtnrow := HBoxContainer.new()
	rbtnrow.add_theme_constant_override("separation", 14)
	rbtnrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rvb.add_child(rbtnrow)

	var retry := _make_btn("TRY AGAIN", 11)
	retry.pressed.connect(_restart)
	rbtnrow.add_child(retry)

	var leave2 := _make_btn("LEVELS", 11)
	leave2.pressed.connect(_leave)
	rbtnrow.add_child(leave2)

func _build_tutorial_panel(root: Control):
	_tutorial_panel = Control.new()
	_tutorial_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_panel.visible = false
	root.add_child(_tutorial_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_panel.add_child(dim)

	var card := _panel(Color(0.129, 0.122, 0.196, 1.0), C_BORDER, 2, 8)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -300
	card.offset_top = -210
	card.offset_right = 300
	card.offset_bottom = 210
	_tutorial_panel.add_child(card)

	var mar := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		mar.add_theme_constant_override("margin_" + s, 28)
	card.add_child(mar)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	mar.add_child(vb)

	var title := _lbl("HOW TO PLAY · FARP", 20, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var subtitle := _lbl("Spot the incoming drone before it reaches your planet.", 11, ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(subtitle)

	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)

	var steps := [
		"1.  Drag inside the blue ring to place a defender and aim its vision cone.",
		"2.  Right-click a defender to remove it. Place up to %d." % MAX_DEFENDERS,
		"3.  Open WORKSPACE to program how your defenders move and scan.",
		"4.  Press LAUNCH DRONE to start the wave. Catch the drone in any vision cone to win.",
		"5.  Use TEST to dry-run your defenders with no enemy.",
		"Scroll to zoom  ·  Middle-drag to pan.",
	]
	for step_text in steps:
		var l := _lbl(step_text, 11, C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		vb.add_child(l)

	var btnrow := HBoxContainer.new()
	btnrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btnrow)

	var got_it := _make_btn("GOT IT", 11)
	got_it.pressed.connect(_hide_tutorial)
	btnrow.add_child(got_it)

func _show_tutorial():
	if _tutorial_panel != null:
		_tutorial_panel.visible = true

func _hide_tutorial():
	if _tutorial_panel != null:
		_tutorial_panel.visible = false

func _update_count():
	_count_label.text = "DEFENDERS: %d / %d" % [_placements.size(), MAX_DEFENDERS]

func _open_workspace():
	_persisted_placements = _placements.duplicate(true)
	SHIP_WORKSPACE.return_scene = "res://levels/modes/FARPScene.tscn"
	get_tree().change_scene_to_file("res://ui/workspace/ShipWorkspace.tscn")

func _restart():
	if is_instance_valid(_enemy):
		_enemy.queue_free()
	_enemy = null
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	_defender_ships.clear()
	_phase = Phase.PLACE
	_active_time = 0.0
	_timer_label.text = "0.0s"
	_phase_label.text = "PLACE DEFENDERS"
	_phase_label.add_theme_color_override("font_color", ACCENT)
	_hint_label.text = PLACE_HINT
	_launch_btn.visible = true
	_clear_btn.disabled = false
	_result_panel.visible = false
	for placement in _placements:
		_spawn_defender(placement, false)
	_update_count()
	queue_redraw()

func _leave():
	_save_placements_to_disk()
	_persisted_placements = []
	if is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file("res://levels/menus/LevelsScene.tscn")

func _draw():
	draw_rect(Rect2(Vector2.ZERO, ARENA), BG_COLOR)
	for s in _bg_stars:
		draw_rect(Rect2(s["pos"], Vector2(s["sz"], s["sz"])), Color(1, 1, 1, s["a"]))

	if _phase == Phase.PLACE:
		draw_circle(PLANET_CENTER, PLACE_MAX, ZONE_FILL)
		_draw_dashed_circle(PLANET_CENTER, PLACE_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
		_draw_dashed_circle(PLANET_CENTER, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)

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

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float):
	var segs := 60
	for i in segs:
		if i % 3 == 0:
			continue
		var a0: float = float(i) / float(segs) * TAU
		var a1: float = float(i + 1) / float(segs) * TAU
		draw_line(center + Vector2(radius, 0.0).rotated(a0),
			center + Vector2(radius, 0.0).rotated(a1), color, width, true)

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

func _make_compact_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", 9)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _compact_btn_style(Color(0.129, 0.122, 0.196, 1.0), C_BORDER))
	b.add_theme_stylebox_override("hover", _compact_btn_style(Color(0.18, 0.17, 0.27, 1.0), ACCENT))
	b.add_theme_stylebox_override("pressed", _compact_btn_style(Color(0.1, 0.095, 0.155, 1.0), ACCENT))
	b.add_theme_stylebox_override("focus", _compact_btn_style(Color(0.129, 0.122, 0.196, 1.0), C_BORDER))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	return b

func _compact_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _panel(bg: Color, border: Color, bw: int, radius: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = bw
	style.border_width_top = bw
	style.border_width_right = bw
	style.border_width_bottom = bw
	style.set_corner_radius_all(radius)
	pc.add_theme_stylebox_override("panel", style)
	return pc
