extends Node2D

const SHIP           := preload("res://entities/ship/Spaceship.tscn")
const TERRAN         := preload("res://entities/planet/PlanetTerran.tscn")
const DRAG_INDICATOR := preload("res://levels/components/DragIndicator.tscn")
const RADIAL_MENU    := preload("res://ui/hud/RadialMenu.tscn")
const SHIP_WORKSPACE := preload("res://ui/workspace/ShipWorkspace.gd")
const TUTORIAL       := preload("res://ui/tutorial/BlobTutorial.gd")
const TUTORIAL_LINES := preload("res://ui/tutorial/LevelTutorialLines.gd")
const FONT_REG       := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME     := preload("res://ui/GameTheme.tres")
const HUD_BUTTONS    := preload("res://ui/hud/HudButtons.gd")
const STARFIELD      := preload("res://ui/game/Starfield.gd")
const RESULT_PANEL   := preload("res://levels/components/LevelResultPanel.gd")
const PAUSE_MENU     := preload("res://levels/components/PauseMenu.gd")
const ACHIEVEMENTS   := preload("res://achievements/Achievements.gd")
const EVADER_STREAM  := preload("res://levels/components/EvaderStream.gd")
const LEVELS_MENU_SCENE := "res://levels/menus/LevelsScene.tscn"
const STREAM_SPAWN_RADIUS := 750.0

# Distances are pixels, durations are seconds and rotations are radians. The
# block editor shows meters, at 40 pixels per meter.
const ARENA         := Vector2(3840.0, 2160.0) # pixels, arena width and height
const PLANET_CENTER := Vector2(1920.0, 1080.0) # pixels
const PLANET_PIXELS := 80.0                    # pixels, source sprite size
const PLANET_DISP   := 240.0                   # pixels, drawn planet diameter
const PLANET_RADIUS := PLANET_DISP * 0.5       # pixels
const GOAL_MARGIN   := 16.0                    # pixels past PLANET_RADIUS that still counts as reaching the planet

const MAX_DEFENDERS := 6     # count
const MIN_DEFENDERS := 1     # count
const DEFENDER_HP   := 99.0  # hit points

const EVADER_HP            := 3.0    # hit points
const EVADER_SPEED         := 105.0  # pixels/second (2.625 m/s)
const EVADER_SPAWN_RADIUS  := 1000.0 # pixels, radius of the ring the evader spawns on
const EVADER_PROGRAM := [
	{"type": "when_always", "params": {}},
	{"type": "do_forward", "params": {}},
]

const RING_RADIUS  := 200.0 # pixels, radius of the defender ring around the planet
const RING_COUNT   := 5     # count, defenders in the ring layout

const PLACE_MIN := PLANET_RADIUS + 50.0 # pixels, closest a defender may be placed to the planet center
const PLACE_MAX := 465.0                # pixels, farthest a defender may be placed from the planet center
const SCATTER_MAX := 250.0              # pixels, farthest a scattered defender may spawn from the planet center
const SCATTER_SPACING := 110.0          # pixels, minimum gap between two scattered defenders
const SCATTER_ATTEMPTS := 40            # count, retries before a scattered position is accepted anyway

const MATCH_CAP_SECONDS := 240.0 # seconds before a match times out
const WARNING_SECONDS   := 30.0  # seconds left on the clock when the timer turns red

const STAR_SEED := 77421     # rng seed for the background starfield
const EDGE_THICKNESS := 16.0 # pixels, arena border texture width
const ZOOM_MIN := 0.4        # camera zoom factor
const ZOOM_MAX := 2.5        # camera zoom factor

const BG_COLOR    := Color(0.04, 0.04, 0.07, 1.0)
const LEVEL_STAR_COUNT_SCALE := 0.45
const ZONE_FILL   := Color(0.451, 0.616, 1.0, 0.05)
const ACCENT      := Color(0.451, 0.616, 1.0, 1.0)
const C_TEXT      := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM       := Color(0.6, 0.62, 0.74, 1.0)
const C_RED       := Color(1.0, 0.42, 0.32, 1.0)
const C_GREEN     := Color(0.40, 0.85, 0.45, 1.0)
const C_AMBER     := Color(1.0, 0.70, 0.20, 1.0)
const C_BORDER    := Color(0.318, 0.306, 0.463, 1.0)
const C_PANEL     := Color(0.129, 0.122, 0.196, 1.0)
const C_DEFENDER  := Color(0.451, 0.616, 1.0, 1.0)
const C_EVADER    := Color(1.0, 0.42, 0.32, 1.0)

const HOUSE_DEFENDER_ALGORITHM := [
	{"type": "when_start", "params": {}, "children": [
		{"type": "set_speed", "params": {"value": 3.4}},
		{"type": "set_fov",   "params": {"value": 50.0}},
		{"type": "set_view",  "params": {"value": 4.5}},
	]},
	{"type": "when_always", "params": {}, "children": [
		{"type": "do_forward",   "params": {}},
		{"type": "do_turn_left", "params": {"value": 90.0}},
	]},
	{"type": "when_sees_ally", "params": {}, "children": [
		{"type": "do_turn_right", "params": {"value": 90.0}},
	]},
]

enum Phase { SETUP, ACTIVE, DONE }

var _arena: Vector2 = ARENA
var _planet: Vector2 = PLANET_CENTER

var _phase: int = Phase.SETUP
var _elapsed: float = 0.0
var _end_reason: String = ""

var _detect_time: float = -1.0
var _capture_time: float = -1.0
var _goal_time: float = -1.0

var _placements: Array = []
var _defender_ships: Array = []
var _evader: Node2D = null

var _collisions_on: bool = false
var _submitted: bool = false

var _camera: Camera2D
var _panning: bool = false
var _drag_indicator: Node2D
var _music: AudioStreamPlayer = null

var _edge_tex_top: Texture2D
var _edge_tex_bottom: Texture2D
var _edge_tex_left: Texture2D
var _edge_tex_right: Texture2D

var _tutorial: CanvasLayer
var _hud_root: Control
var _top_bar: HBoxContainer
var _phase_label: Label
var _timer_label: Label
var _count_label: Label
var _hint_label: Label
var _event_label: Label
var _launch_btn: Button
var _result_panel: Control
var _new_badges: Array = []
var _stream = null

func _ready():
	get_tree().paused = false
	_arena = _arena_size()
	_planet = _planet_center()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge_tex_top = load("res://assets/edges/space_edge_top.png")
	_edge_tex_bottom = load("res://assets/edges/space_edge_bottom.png")
	_edge_tex_left = load("res://assets/edges/space_edge_left.png")
	_edge_tex_right = load("res://assets/edges/space_edge_right.png")

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.position = _planet
	_camera.zoom = Vector2(0.5, 0.5)
	_camera.make_current()
	_clamp_camera()

	_build_starfield()
	_build_planet()
	_start_music()

	_drag_indicator = DRAG_INDICATOR.instantiate()
	_drag_indicator.z_index = 8
	add_child(_drag_indicator)
	_drag_indicator.update_drag(false)

	_build_hud()
	PlayerData.achievement_unlocked.connect(_on_achievement_unlocked)
	_setup_level()
	_update_count()
	queue_redraw()

	if not PlayerSettings.get_flag(_seen_flag()):
		PlayerSettings.set_flag(_seen_flag(), true)
		_show_tutorial()

func _setup_level():
	pass

func _arena_size() -> Vector2:
	return ARENA

func _planet_center() -> Vector2:
	return PLANET_CENTER

func _planet_seed() -> int:
	return PlayerData.planet_seed

func _star_seed() -> int:
	return STAR_SEED

func _level_id() -> String:
	return "farp1"

func _level_title() -> String:
	return "FARP"

func _level_subtitle() -> String:
	return ""

func _submits_algorithm() -> bool:
	return true

func _uses_workspace() -> bool:
	return true

func _planet_collisions() -> bool:
	return true

func _uses_collisions_toggle() -> bool:
	return false

func _time_limit() -> float:
	return MATCH_CAP_SECONDS

func _timer_text() -> String:
	return "%.1fs" % _elapsed

func _countdown_text() -> String:
	var remaining: float = maxf(0.0, _time_limit() - _elapsed)
	return "%d:%02d" % [floori(remaining / 60.0), int(remaining) % 60]

func _update_countdown_color():
	var remaining: float = _time_limit() - _elapsed
	_timer_label.add_theme_color_override("font_color", C_RED if remaining <= WARNING_SECONDS else C_TEXT)

func _pressed(action: String, fallback: Key) -> bool:
	if InputMap.has_action(action):
		return Input.is_action_pressed(action)
	return Input.is_key_pressed(fallback)

func _drive_with_keys(ship: Node2D, delta: float, speed: float, turn_rate: float):
	var turn: float = 0.0
	var thrust: float = 0.0
	if _pressed("robot_turn_right", KEY_D) or Input.is_action_pressed("ui_right"):
		turn += 1.0
	if _pressed("robot_turn_left", KEY_A) or Input.is_action_pressed("ui_left"):
		turn -= 1.0
	if _pressed("robot_forward", KEY_W) or Input.is_action_pressed("ui_up"):
		thrust += 1.0
	if _pressed("robot_backward", KEY_S) or Input.is_action_pressed("ui_down"):
		thrust -= 1.0
	ship.rotation += turn * turn_rate * delta
	ship.global_position += Vector2.RIGHT.rotated(ship.rotation) * speed * thrust * delta
	ship.global_position.x = clampf(ship.global_position.x, 20.0, _arena.x - 20.0)
	ship.global_position.y = clampf(ship.global_position.y, 20.0, _arena.y - 20.0)
	ship.queue_redraw()

func _update_level(_delta: float):
	pass

func _draw_level():
	pass

func _level_input(_event: InputEvent):
	pass

func _restart_level():
	pass

func _seen_flag() -> String:
	return "tutorial_seen_" + _level_id()

func _voice_dir() -> String:
	return "res://va/levels/" + _level_id()

func _tutorial_lines() -> Array:
	return TUTORIAL_LINES.for_level(_level_id())

func _show_tutorial():
	if is_instance_valid(_tutorial):
		return
	var lines: Array = _tutorial_lines()
	if lines.is_empty():
		return
	var tutorial := TUTORIAL.new()
	_tutorial = tutorial
	tutorial.lines = lines
	tutorial.voice_dir = _voice_dir()
	tutorial.show_visuals = false
	tutorial.final_hint = _tutorial_final_hint()
	tutorial.finished.connect(_after_tutorial)
	add_child(tutorial)

func _tutorial_final_hint() -> String:
	return "CLICK TO CLOSE"

func _after_tutorial():
	pass

func _shows_hint_text() -> bool:
	return true

func _shows_run_controls() -> bool:
	return true

func _process(delta: float):
	if _phase == Phase.ACTIVE:
		_elapsed += delta
		_timer_label.text = _timer_text()
		_update_level(delta)
		_update_stream(delta)
		_track_events()
		_update_event_label()
		if _phase == Phase.ACTIVE and _elapsed >= _time_limit():
			_finish("timeout")
	queue_redraw()

func _track_events():
	if not is_instance_valid(_evader):
		return
	if _detect_time < 0.0 and _defender_sees_evader():
		_detect_time = _elapsed
	if _capture_time < 0.0 and _defender_touches_evader():
		_capture_time = _elapsed
		_finish("capture")
		return
	if _goal_time < 0.0 and _evader_at_goal():
		_goal_time = _elapsed
		_finish("goal")

func _evader_position() -> Vector2:
	if is_instance_valid(_evader):
		return _evader.global_position
	return Vector2(-99999.0, -99999.0)

func _defender_sees_evader() -> bool:
	return _any_defender_sees_point(_evader_position())

func _any_defender_sees(evader: Node2D) -> bool:
	return _any_defender_sees_point(evader.global_position)

func _any_defender_sees_point(target: Vector2) -> bool:
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		var to_evader: Vector2 = target - ship.global_position
		if to_evader.length() > ship.view_distance:
			continue
		if absf(angle_difference(ship.rotation, to_evader.angle())) <= deg_to_rad(ship.fov_degrees * 0.5):
			return true
	return false

func _defender_touches_evader() -> bool:
	if not is_instance_valid(_evader):
		return false
	var target: Vector2 = _evader.global_position
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		if ship.global_position.distance_to(target) <= ship.hull_radius + _evader.hull_radius:
			return true
	return false

func _evader_at_goal() -> bool:
	return _evader_position().distance_to(_planet) <= PLANET_RADIUS + GOAL_MARGIN

func _defender_touching(evader: Node2D) -> Node2D:
	var target: Vector2 = evader.global_position
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		if ship.global_position.distance_to(target) <= ship.hull_radius + evader.hull_radius:
			return ship
	return null

func _evader_reached_goal(evader: Node2D) -> bool:
	return evader.global_position.distance_to(_planet) <= PLANET_RADIUS + GOAL_MARGIN

func _spawn_defender(placement: Dictionary, program: Array):
	var ship := _make_ship(program, DEFENDER_HP, C_DEFENDER)
	ship.global_position = placement.pos
	ship.rotation = placement.rot
	ship.set_meta("placement", placement)
	_defender_ships.append(ship)

func _make_ship(program: Array, hp_value: float, color: Color) -> Node2D:
	var ship := SHIP.instantiate()
	ship.setup_player(program, hp_value)
	ship.ship_color = color
	ship.set_obstacles(Vector2.ZERO, 0.0, _planet, PLANET_RADIUS)
	ship.planet_collisions = _planet_collisions()
	ship.collisions_enabled = _collisions_on
	ship.arena_size = _arena
	ship.can_fire = false
	ship.show_health = false
	add_child(ship)
	var cfg: Dictionary = SimulationManager.ship_config_from_scripts(program, ship.view_distance, ship.fov_degrees, ship.max_speed, ship.turn_rate, ship.hull_radius)
	ship.view_distance = cfg.view_distance
	ship.fov_degrees = cfg.fov_degrees
	ship.max_speed = cfg.speed
	ship.turn_rate = cfg.turn_speed
	ship.hull_radius = cfg.dot_radius
	ship.refresh_cone()
	ship.set_physics_process(false)
	return ship

func _spawn_scripted_evader(spawn_pos: Vector2):
	_evader = _make_scripted_evader(spawn_pos)

func _make_scripted_evader(spawn_pos: Vector2) -> Node2D:
	var evader := SHIP.instantiate()
	evader.setup_raider(EVADER_PROGRAM, EVADER_HP)
	evader.ship_color = C_EVADER
	evader.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	evader.collisions_enabled = false
	evader.is_evader = true
	evader.arena_size = _arena
	evader.show_health = false
	evader.speed_mult = EVADER_SPEED / 150.0
	add_child(evader)
	evader.global_position = spawn_pos
	evader.rotation = (_planet - spawn_pos).angle()
	return evader

func _random_ring_placements(count: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for _i in count:
		var pos: Vector2 = _scatter_point(rng)
		for _attempt in SCATTER_ATTEMPTS:
			if _is_clear_of(pos, out):
				break
			pos = _scatter_point(rng)
		out.append({"pos": pos, "rot": rng.randf() * TAU})
	return out

func _scatter_point(rng: RandomNumberGenerator) -> Vector2:
	var angle: float = rng.randf() * TAU
	var radius: float = rng.randf_range(PLACE_MIN, _scatter_max_radius())
	return _planet + Vector2(radius, 0.0).rotated(angle)

func _scatter_max_radius() -> float:
	return SCATTER_MAX

func _scatter_spacing() -> float:
	return SCATTER_SPACING

func _is_clear_of(pos: Vector2, placements: Array) -> bool:
	for placement in placements:
		if pos.distance_to(placement.pos) < _scatter_spacing():
			return false
	return true

func _placements_from_payload(entries: Array) -> Array:
	var out: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out.append({
			"pos": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
			"rot": float(entry.get("rot", 0.0)),
		})
	return out

func _house_ring_placements(count: int) -> Array:
	var out: Array = []
	for i in count:
		var angle: float = TAU * float(i) / float(count)
		out.append({
			"pos": _planet + Vector2(RING_RADIUS, 0.0).rotated(angle),
			"rot": angle - PI / 2.0,
		})
	return out

func _clear_ships():
	if _stream != null:
		_stream.clear()
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	_defender_ships.clear()
	if is_instance_valid(_evader):
		_evader.queue_free()
	_evader = null

func _start_active():
	_phase = Phase.ACTIVE
	_elapsed = 0.0
	_detect_time = -1.0
	_capture_time = -1.0
	_goal_time = -1.0
	_launch_btn.visible = false
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(true)

func _finish(reason: String):
	if _stream != null:
		_stream.freeze()
	_phase = Phase.DONE
	_end_reason = reason
	PlayerData.complete_level(_level_id())
	ACHIEVEMENTS.check_level_completed(_level_id())
	for ship in _defender_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(false)
	if is_instance_valid(_evader):
		_evader.set_physics_process(false)
	_update_event_label()
	_show_outcome(reason)
	_auto_submit()

func _auto_submit():
	if _submitted or not _submits_algorithm():
		return
	_submit_entry()

func _use_evader_stream(total: int, interval: float, start_delay: float):
	_stream = EVADER_STREAM.new(self)
	_stream.total = total
	_stream.interval = interval
	_stream.start_delay = start_delay
	_stream.spawn_distance = STREAM_SPAWN_RADIUS

func _update_stream(delta: float):
	if _stream == null or _phase != Phase.ACTIVE:
		return
	_stream.update(delta)
	if _stream.is_finished():
		_finish("cleared")

func _on_stream_result(_held: bool):
	pass

func _show_outcome(reason: String):
	if _stream != null:
		var result: Dictionary = _stream.outcome(reason)
		_phase_label.text = result.title
		_phase_label.add_theme_color_override("font_color", C_GREEN if result.held else C_RED)
		_on_stream_result(result.held)
		_show_result(result.held, result.title, result.headline)
		return
	var defender_won: bool = reason == "capture"
	var title: String
	var headline: String
	if _is_evader_role():
		title = "PLANET REACHED" if reason == "goal" else "EVADER CAUGHT"
		headline = "You reached the planet." if reason == "goal" else "A defender caught you."
		if reason == "timeout":
			title = "OUT OF TIME"
			headline = "The run timed out before you reached the planet."
	else:
		title = "PLANET DEFENDED" if defender_won else "PLANET BREACHED"
		headline = "A defender captured the evader." if defender_won else "The evader reached the planet."
		if reason == "timeout":
			title = "OUT OF TIME"
			headline = "The evader was neither captured nor reached the planet."
	_phase_label.text = title
	_phase_label.add_theme_color_override("font_color", C_GREEN if (defender_won != _is_evader_role()) else C_RED)
	_show_result(defender_won != _is_evader_role(), title, headline)

func _is_evader_role() -> bool:
	return false

func _event_summary() -> String:
	if _stream != null:
		return _stream.summary_text(_time_text(_detect_time), _time_text(_capture_time))
	return "Detected: %s\nCaptured: %s\nReached planet: %s" % [_time_text(_detect_time), _time_text(_capture_time), _time_text(_goal_time)]

func _time_text(value: float) -> String:
	if value < 0.0:
		return "never"
	return "%.2fs" % value

func _update_event_label():
	if _stream != null:
		_event_label.text = _stream.event_label_text()
		return
	_event_label.text = "DETECTED %s   CAPTURED %s   REACHED PLANET %s" % [_time_text(_detect_time), _time_text(_capture_time), _time_text(_goal_time)]

func _placements_payload() -> Array:
	var out: Array = []
	for placement in _placements:
		out.append({"x": placement.pos.x, "y": placement.pos.y, "rot": placement.rot})
	return out

func _submit_entry():
	if _submitted:
		return
	_submitted = true
	if not EvalUploader.submit_finished.is_connected(_on_submit_finished):
		EvalUploader.submit_finished.connect(_on_submit_finished)
	EvalUploader.submit(PlayerData.ship_blocks, _placements_payload(), _level_id(), _collisions_on)

func _on_submit_finished(success: bool, code: int, _response):
	if success or code == 409:
		return
	_result_panel.add_note(_submit_error(code))

func _submit_error(code: int) -> String:
	if code == 426:
		return "This build is out of date, so the server would not take the entry."
	return "The server could not be reached, so the entry was not recorded."

func _restart():
	_clear_ships()
	_placements.clear()
	_phase = Phase.SETUP
	_submitted = false
	_elapsed = 0.0
	_end_reason = ""
	_detect_time = -1.0
	_capture_time = -1.0
	_goal_time = -1.0
	_timer_label.text = _timer_text()
	_timer_label.add_theme_color_override("font_color", C_TEXT)
	_result_panel.visible = false
	if _stream != null:
		_stream.reset()
	_launch_btn.visible = true
	_phase_label.add_theme_color_override("font_color", ACCENT)
	_update_event_label()
	_restart_level()
	_update_count()
	queue_redraw()

func _leave():
	_exit_level(LEVELS_MENU_SCENE)

func _leave_paused(scene_path: String):
	get_tree().paused = false
	_exit_level(scene_path)

func _go_to_next_level():
	var next: Dictionary = LevelInfo.next_level(_level_id())
	if not next.is_empty():
		_exit_level(next["scene"])

func _exit_level(scene_path: String):
	if is_instance_valid(_music):
		_music.stop()
	get_tree().change_scene_to_file(scene_path)

func _open_workspace():
	SHIP_WORKSPACE.return_scene = scene_file_path
	get_tree().change_scene_to_file("res://ui/workspace/ShipWorkspace.tscn")

func _on_collisions_toggled(on: bool):
	_collisions_on = on
	for ship in _defender_ships:
		if is_instance_valid(ship) and not ship.is_evader:
			ship.collisions_enabled = on

func _update_count():
	if _count_label != null:
		_count_label.text = "DEFENDERS: %d" % _defender_ships.size()

func _unhandled_input(event: InputEvent):
	if _handle_shortcut(event):
		return
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
	_level_input(event)

func _handle_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode == KEY_P:
		_restart()
		return true
	# The evader is steered with these same keys, so the setup shortcuts are only
	# live while a run is not in progress.
	if _phase == Phase.ACTIVE:
		return false
	match event.keycode:
		KEY_S:
			if _phase == Phase.SETUP:
				_launch()
			return true
		KEY_R:
			if _can_reroll():
				_reroll_level()
			return true
	return false

func _can_reroll() -> bool:
	return false

func _reroll_level():
	pass

func _zoom_by(factor: float):
	var z: float = clampf(_camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)
	_clamp_camera()

func _clamp_camera():
	var half: Vector2 = get_viewport_rect().size * 0.5 / _camera.zoom
	if half.x * 2.0 >= _arena.x:
		_camera.position.x = _arena.x * 0.5
	else:
		_camera.position.x = clampf(_camera.position.x, half.x, _arena.x - half.x)
	if half.y * 2.0 >= _arena.y:
		_camera.position.y = _arena.y * 0.5
	else:
		_camera.position.y = clampf(_camera.position.y, half.y, _arena.y - half.y)

func _start_music():
	var stream := load("res://assets/music/RIDLEY_4.mp3") as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = "Music"
	add_child(_music)
	_music.play()

func _build_starfield():
	var background := CanvasLayer.new()
	background.layer = -10
	add_child(background)
	var fill := ColorRect.new()
	fill.color = BG_COLOR
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(fill)
	var starfield := Control.new()
	starfield.set_script(STARFIELD)
	starfield.STAR_SEED = _star_seed()
	starfield.animated = false
	starfield.star_count_scale = LEVEL_STAR_COUNT_SCALE
	background.add_child(starfield)

func _build_planet():
	var planet := TERRAN.instantiate() as Control
	add_child(planet)
	planet.generate(_planet_seed(), PLANET_PIXELS)
	planet.z_index = 2
	var sc: float = PLANET_DISP / PLANET_PIXELS
	planet.scale = Vector2(sc, sc)
	planet.position = _planet - Vector2(PLANET_DISP * 0.5, PLANET_DISP * 0.5)
	_disable_mouse(planet)

func _draw():
	_draw_level()
	_draw_edges()

func _draw_edges():
	if _edge_tex_top == null or _edge_tex_bottom == null or _edge_tex_left == null or _edge_tex_right == null:
		return
	var t: float = EDGE_THICKNESS
	draw_texture_rect(_edge_tex_top, Rect2(0.0, 0.0, _arena.x, t), true)
	draw_texture_rect(_edge_tex_bottom, Rect2(0.0, _arena.y - t, _arena.x, t), true)
	draw_texture_rect(_edge_tex_left, Rect2(0.0, 0.0, t, _arena.y), true)
	draw_texture_rect(_edge_tex_right, Rect2(_arena.x - t, 0.0, t, _arena.y), true)

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

func _build_hud():
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GAME_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	_hud_root = root

	_top_bar = HBoxContainer.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.add_theme_constant_override("separation", 6)
	_top_bar.offset_left = 12
	_top_bar.offset_top = 12
	_top_bar.offset_right = -12
	_top_bar.offset_bottom = 40
	root.add_child(_top_bar)

	if _uses_workspace():
		_add_top_button("WORKSPACE", _open_workspace, HUD_BUTTONS.Kind.PRIMARY)
	if _shows_run_controls():
		_add_top_button("RESTART (P)", _restart)
		_add_top_button("TUTORIAL", _show_tutorial)

	if _uses_collisions_toggle():
		var collisions_btn := CheckButton.new()
		collisions_btn.text = "COLLISIONS"
		collisions_btn.button_pressed = _collisions_on
		collisions_btn.focus_mode = Control.FOCUS_NONE
		collisions_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		HUD_BUTTONS.apply(collisions_btn, HUD_BUTTONS.Kind.NEUTRAL, 9)
		collisions_btn.toggled.connect(_on_collisions_toggled)
		_top_bar.add_child(collisions_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(spacer)

	_timer_label = _lbl("0.0s", 22, C_TEXT)
	_top_bar.add_child(_timer_label)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 16
	left.offset_top = 58
	root.add_child(left)

	_phase_label = _lbl(_level_title(), 13, ACCENT)
	left.add_child(_phase_label)

	_count_label = _lbl("DEFENDERS: 0", 11, C_DIM)
	left.add_child(_count_label)

	_event_label = _lbl("", 10, C_AMBER)
	left.add_child(_event_label)
	_update_event_label()

	_launch_btn = HUD_BUTTONS.make("LAUNCH >", HUD_BUTTONS.Kind.PRIMARY, 13)
	_launch_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_launch_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_launch_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_launch_btn.offset_left = -260
	_launch_btn.offset_top = -64
	_launch_btn.offset_right = -16
	_launch_btn.offset_bottom = -16
	_launch_btn.pressed.connect(_launch)
	_launch_btn.visible = _shows_run_controls()
	root.add_child(_launch_btn)

	_hint_label = _lbl(_level_subtitle(), 10, C_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint_label.offset_left = 16
	_hint_label.offset_top = -120
	_hint_label.offset_right = 340
	_hint_label.offset_bottom = -14
	_hint_label.visible = _shows_hint_text()
	root.add_child(_hint_label)

	_build_result_panel(root)
	var pause_menu := PAUSE_MENU.new()
	pause_menu.leave_requested.connect(_leave_paused)
	add_child(pause_menu)

func _launch():
	pass

func _add_top_button(text: String, handler: Callable, kind: int = HUD_BUTTONS.Kind.NEUTRAL):
	var b := HUD_BUTTONS.make(text, kind, 9)
	b.pressed.connect(handler)
	_top_bar.add_child(b)

func _build_result_panel(root: Control):
	_result_panel = RESULT_PANEL.new()
	root.add_child(_result_panel)
	_result_panel.retry_requested.connect(_restart)
	_result_panel.next_requested.connect(_go_to_next_level)
	_result_panel.levels_requested.connect(_leave)

func _show_result(passed: bool, title: String, headline: String):
	var status: String = "LEVEL %d %s" % [LevelInfo.number(_level_id()), "COMPLETE" if passed else "FAILED"]
	var has_next: bool = not LevelInfo.next_level(_level_id()).is_empty()
	_result_panel.show_result(passed, status, title, headline, _summary_rows(), has_next)
	for achievement_id in _new_badges:
		_result_panel.add_note("BADGE UNLOCKED: %s" % ACHIEVEMENTS.find(achievement_id).get("title", achievement_id))
	_new_badges.clear()

func _on_achievement_unlocked(achievement_id: String):
	_new_badges.append(achievement_id)

func _summary_rows() -> Array:
	var rows: Array = [["Run time", "%.1fs" % _elapsed]]
	for line in _event_summary().split("\n", false):
		var split_at: int = line.find(":")
		if split_at < 0:
			rows.append([line.strip_edges(), ""])
		else:
			rows.append([line.substr(0, split_at).strip_edges(), line.substr(split_at + 1).strip_edges()])
	return rows

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _make_btn(text: String, size: int = 12) -> Button:
	return HUD_BUTTONS.make(text, HUD_BUTTONS.Kind.NEUTRAL, size)

func _make_compact_btn(text: String) -> Button:
	return HUD_BUTTONS.make(text, HUD_BUTTONS.Kind.NEUTRAL, 9)

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
