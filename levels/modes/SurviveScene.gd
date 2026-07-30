extends Node2D

const SHIP       := preload("res://entities/ship/SurviveShip.tscn")
const SHIP_CLASS := preload("res://entities/ship/SurviveShip.gd")
const WORLD      := preload("res://levels/modes/SurviveWorld.gd")
const TERRAN     := preload("res://entities/planet/PlanetTerran.tscn")
const EXPLOSION  := preload("res://entities/ship/Explosion.gd")
const LASER      := preload("res://entities/ship/LaserBeam.gd")
const TUTORIAL   := preload("res://ui/tutorial/BlobTutorial.gd")
const FONT_REG   := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const GAME_THEME := preload("res://ui/GameTheme.tres")

const FREEZE_ICON_PATH := "res://assets/sprites/effects/freeze.png"

const ARENA          := Vector2(2400.0, 1350.0)
const PLANET_PIXELS  := 80.0
const PLANET_DISP    := 180.0
const PLANET_RADIUS  := PLANET_DISP * 0.5
const PLANET_CENTERS := [Vector2(520.0, 675.0), Vector2(1880.0, 675.0)]
const BASE_RADIUS    := 300.0

const VIEW_ZOOM   := 0.7
const CAMERA_LERP := 7.0

const MATCH_SECONDS   := 180.0
const WILD_COUNT      := 24
const EVADER_TOTAL    := 14
const WAVE_ONE_START  := 60.0
const WAVE_ONE_END    := 90.0
const WAVE_TWO_START  := 120.0
const WAVE_TWO_END    := 150.0
const SPAWN_INTERVAL  := 5.0
const READY_COUNTDOWN := 5.0

const EVADER_SPEED        := 120.0
const EVADER_MIN_X_GAP    := 400.0
const EVADER_MIN_DISTANCE := 700.0
const SHIP_HULL           := 14.0

const PILOT_SPEED     := 215.0
const PILOT_TURN_RATE := 3.6
const PILOT_VIEW      := 200.0
const PILOT_FOV       := 90.0

const FREEZE_CHARGES := 2
const FREEZE_SECONDS := 15.0

const APM_BUCKET_SECONDS := 5.0
const STICK_DEADZONE     := 0.18
const TRIGGER_DEADZONE   := 0.12
const STICK_CURVE        := 0.45
const THRUST_RESPONSE    := 5.0
const TURN_RESPONSE      := 8.0
const SETTLE_BOOST       := 2.0
const REVERSE_FACTOR     := 0.6

const BG_COLOR   := Color(0.04, 0.04, 0.07, 1.0)
const C_TEXT     := Color(0.93, 0.94, 1.0, 1.0)
const C_DIM      := Color(0.6, 0.62, 0.74, 1.0)
const C_BORDER   := Color(0.318, 0.306, 0.463, 1.0)
const C_PANEL    := Color(0.129, 0.122, 0.196, 1.0)
const C_ACCENT   := Color(0.451, 0.616, 1.0, 1.0)
const C_RED      := Color(1.0, 0.42, 0.32, 1.0)
const C_AMBER    := Color(1.0, 0.70, 0.20, 1.0)
const C_GREENISH := Color(0.40, 0.85, 0.45, 1.0)
const PLAYER_COLORS := [Color(1.0, 0.80, 0.25, 1.0), Color(0.35, 0.90, 0.45, 1.0)]

const PILOT_KEYS := [
	{"forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D, "freeze": KEY_Q},
	{"forward": KEY_UP, "backward": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "freeze": KEY_SLASH},
]
const PILOT_KEY_HINTS  := ["WASD", "ARROW KEYS"]
const FREEZE_KEY_HINTS := ["Q", "/"]
const READY_KEY_HINTS  := ["W", "UP ARROW"]

enum Phase { TUTORIAL, READY, ACTIVE, DONE }

var _phase: int = Phase.TUTORIAL
var _elapsed: float = 0.0
var _countdown: float = -1.0
var _rng := RandomNumberGenerator.new()

var _world
var _viewports: Array = []
var _cameras: Array = []

var _wild_ships: Array = []
var _pilot_ships: Array = [null, null]
var _evader_ships: Array = []

var _ready_flags := [false, false]
var _ready_down := [false, false]
var _pad_claims := [-1, -1]
var _pad_claim_down := {}
var _pad_release_down := {}
var _freeze_down := [false, false]
var _evaders_through := [0, 0]
var _freezes_left := [FREEZE_CHARGES, FREEZE_CHARGES]
var _freezes_used := [0, 0]
var _herded_total := [0, 0]
var _input_bits := [0, 0]
var _actions := [0, 0]
var _bucket_actions := [0, 0]
var _apm_series := [[], []]
var _apm_times: Array = []
var _bucket_time: float = 0.0

var _spawn_queue: Array = []
var _spawn_index: int = 0
var _first_target: int = 0
var _match_submitted: bool = false
var _outcome: String = "tie"

var _timer_label: Label
var _wave_label: Label
var _hint_label: Label
var _player_panels: Array = [{}, {}]
var _freeze_pips: Array = [[], []]
var _freeze_keys: Array = [null, null]
var _freeze_status: Array = [null, null]
var _result_panel: Control
var _result_title: Label
var _result_headline: Label
var _result_grid: GridContainer
var _upload_label: Label

func _ready():
	get_tree().paused = false
	_rng.randomize()
	Input.joy_connection_changed.connect(_on_joy_disconnected)

	_build_world()
	_build_split()
	_build_planets()
	randomize()
	_build_hud()
	_build_spawn_queue()
	_spawn_pilots()
	_show_tutorial()

func _build_world():
	_world = WORLD.new()
	_world.arena = ARENA
	_world.background = BG_COLOR
	_world.base_radius = BASE_RADIUS
	_world.planet_centers = PLANET_CENTERS
	_world.planet_colors = PLAYER_COLORS
	_world.stars = _make_bg_stars()
	_world.edge_top = load("res://assets/space_edge_top.png")
	_world.edge_bottom = load("res://assets/space_edge_bottom.png")
	_world.edge_left = load("res://assets/space_edge_left.png")
	_world.edge_right = load("res://assets/space_edge_right.png")

func _build_split():
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(row)

	for slot in _player_count():
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(container)

		var viewport := SubViewport.new()
		viewport.handle_input_locally = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)

		if slot == 0:
			viewport.add_child(_world)
		else:
			viewport.world_2d = _viewports[0].world_2d

		var camera := Camera2D.new()
		camera.zoom = Vector2(VIEW_ZOOM, VIEW_ZOOM)
		camera.position = PLANET_CENTERS[slot]
		viewport.add_child(camera)
		camera.make_current()

		_viewports.append(viewport)
		_cameras.append(camera)

func _show_tutorial():
	_phase = Phase.TUTORIAL
	var tutorial := TUTORIAL.new()
	tutorial.lines = _tutorial_lines()
	tutorial.finished.connect(_on_tutorial_finished)
	add_child(tutorial)

func _on_tutorial_finished():
	_phase = Phase.READY
	_refresh_hint()

func _tutorial_lines() -> Array:
	return [
		{"id": 1, "visual": "title", "text": "Hello Commanders! Dr. Blob at your service. Welcome to Astro Swarm."},
		{"id": 2, "visual": "pilots", "text": "In this mode you and a friend can play against each other. Each of you have a planet to protect for three minutes.\nPlayer one flies the gold ship on W A S D. Player two flies the green ship on the arrow keys. Controllers work as well, just press A on the one you want and it attaches to the next free player."},
		{"id": 3, "visual": "herd", "text": "Twenty four purple ships are drifting out there. The moment one sees another ship, any other ship, it turns blue. Leave it with nothing in sight for five seconds and it goes purple again. You cannot push them around, they only react to what they see."},
		{"id": 4, "visual": "cluster", "text": "You can herd Blue Ships to your planet. And nothing stops you stealing your rival's Blue Ships too."},
		{"id": 5, "visual": "waves", "text": "After the first minute the red evaders arrive in waves. Fourteen of them, seven at each planet. Every one that lands is a point against you."},
		{"id": 6, "visual": "laser", "text": "A blue ship that sees an evader kills it with a laser, then burns out. One blue for one red, so collect plenty. Your own ship has no weapons, so the blue ships are your only defence."},
		{"id": 7, "visual": "freeze", "text": "Two freeze charges each, fifteen seconds apiece. Q for player one, the forward slash key for player two, or the right shoulder button."},
		{"id": 8, "visual": "score", "text": "Fewest evaders on your planet wins, and an equal count is a draw. Both of you press your drive key to ready up. Five seconds later we launch, and pressing it again before then calls it off. Good luck, Commanders!"},
	]

func _process(delta: float):
	_poll_pad_claims()
	match _phase:
		Phase.READY:
			_poll_ready(delta)
		Phase.ACTIVE:
			_elapsed += delta
			_poll_pilots(delta)
			_run_waves()
			_resolve_lasers()
			_resolve_planet_hits()
			_sample_apm(delta)
			if _elapsed >= MATCH_SECONDS:
				_finish()
	_update_cameras(delta)
	_refresh_hud()

func _player_count() -> int:
	return 2

func _update_cameras(delta: float):
	for slot in _player_count():
		var camera: Camera2D = _cameras[slot]
		camera.position = camera.position.lerp(_camera_target(slot), clampf(delta * CAMERA_LERP, 0.0, 1.0))

func _camera_target(slot: int) -> Vector2:
	var ship = _pilot_ships[slot]
	var focus: Vector2 = PLANET_CENTERS[slot]
	if is_instance_valid(ship):
		focus = ship.global_position
	var half: Vector2 = Vector2(_viewports[slot].size) / VIEW_ZOOM * 0.5
	var out: Vector2 = focus
	if half.x * 2.0 >= ARENA.x:
		out.x = ARENA.x * 0.5
	else:
		out.x = clampf(focus.x, half.x, ARENA.x - half.x)
	if half.y * 2.0 >= ARENA.y:
		out.y = ARENA.y * 0.5
	else:
		out.y = clampf(focus.y, half.y, ARENA.y - half.y)
	return out

func _pad_for(slot: int) -> int:
	var device: int = int(_pad_claims[slot])
	if device >= 0 and Input.get_connected_joypads().has(device):
		return device
	return -1

func _slot_for_pad(device: int) -> int:
	for slot in _player_count():
		if int(_pad_claims[slot]) == device:
			return slot
	return -1

func _unclaimed_pads() -> int:
	var count: int = 0
	for device in Input.get_connected_joypads():
		if _slot_for_pad(int(device)) < 0:
			count += 1
	return count

func _poll_pad_claims():
	for device in Input.get_connected_joypads():
		var id: int = int(device)
		var claim_down: bool = Input.is_joy_button_pressed(id, JOY_BUTTON_A)
		var claim_edge: bool = claim_down and not bool(_pad_claim_down.get(id, false))
		_pad_claim_down[id] = claim_down

		var release_down: bool = Input.is_joy_button_pressed(id, JOY_BUTTON_B)
		var release_edge: bool = release_down and not bool(_pad_release_down.get(id, false))
		_pad_release_down[id] = release_down

		if release_edge:
			_release_pad(id)
		elif claim_edge and _slot_for_pad(id) < 0:
			_claim_pad(id)

func _claim_pad(device: int):
	for slot in _player_count():
		if int(_pad_claims[slot]) >= 0:
			continue
		_pad_claims[slot] = device
		_ready_down[slot] = true
		_freeze_down[slot] = Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
		return

func _release_pad(device: int):
	var slot: int = _slot_for_pad(device)
	if slot >= 0:
		_pad_claims[slot] = -1

func _on_joy_disconnected(device: int, connected: bool):
	if not connected:
		_release_pad(device)

func _poll_ready(delta: float):
	for slot in _player_count():
		if not _ready_toggled(slot):
			continue
		_ready_flags[slot] = not _ready_flags[slot]
		_countdown = READY_COUNTDOWN if _both_ready() else -1.0
	if not _both_ready():
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_start_match()

func _both_ready() -> bool:
	return _ready_flags[0] and _ready_flags[1]

func _ready_toggled(slot: int) -> bool:
	var down: bool = Input.is_physical_key_pressed(PILOT_KEYS[slot]["forward"])
	var pad: int = _pad_for(slot)
	if pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_A):
		down = true
	var was: bool = bool(_ready_down[slot])
	_ready_down[slot] = down
	return down and not was

func _start_match():
	_phase = Phase.ACTIVE
	_elapsed = 0.0
	_countdown = -1.0
	_spawn_wilds()
	for ship in _pilot_ships:
		if is_instance_valid(ship):
			ship.set_physics_process(true)
	_refresh_hint()

func _build_spawn_queue():
	_first_target = _rng.randi_range(0, 1)
	var times: Array = []
	var t: float = WAVE_ONE_START
	while t <= WAVE_ONE_END and times.size() < EVADER_TOTAL:
		times.append(t)
		t += SPAWN_INTERVAL
	t = WAVE_TWO_START
	while t <= WAVE_TWO_END and times.size() < EVADER_TOTAL:
		times.append(t)
		t += SPAWN_INTERVAL
	while times.size() < EVADER_TOTAL:
		times.append(WAVE_TWO_END)
	for i in times.size():
		_spawn_queue.append({"time": times[i], "slot": (_first_target + i) % 2})

func _run_waves():
	while _spawn_index < _spawn_queue.size() and _elapsed >= float(_spawn_queue[_spawn_index]["time"]):
		_spawn_evader(int(_spawn_queue[_spawn_index]["slot"]))
		_spawn_index += 1

func _wave_text() -> String:
	if _spawn_index >= _spawn_queue.size():
		return "ALL WAVES LAUNCHED"
	var next_time: float = float(_spawn_queue[_spawn_index]["time"])
	if _elapsed < WAVE_ONE_START:
		return "HERDING PHASE - FIRST WAVE IN %ds" % int(ceilf(next_time - _elapsed))
	if _elapsed <= WAVE_ONE_END or (_elapsed >= WAVE_TWO_START and _elapsed <= WAVE_TWO_END):
		return "WAVE INCOMING - %d EVADERS LEFT" % (_spawn_queue.size() - _spawn_index)
	return "COOL OFF - NEXT WAVE IN %ds" % int(ceilf(next_time - _elapsed))

func _spawn_ship():
	var ship := SHIP.instantiate()
	ship.arena_size = ARENA
	ship.hull_radius = SHIP_HULL
	ship.show_health = false
	ship.can_fire = false
	ship.collisions_enabled = false
	return ship

func _spawn_wilds():
	for _i in WILD_COUNT:
		var ship = _spawn_ship()
		ship.team = 0
		ship.ship_color = Color(0.65, 0.45, 0.95, 1.0)
		_world.add_child(ship)
		ship.global_position = _wild_spawn_point()
		ship.rotation = _rng.randf() * TAU
		ship.setup_wild()
		ship.exploded.connect(_on_ship_exploded)
		ship.herded.connect(_on_ship_herded)
		_wild_ships.append(ship)

func _wild_spawn_point() -> Vector2:
	for _attempt in 120:
		var point := Vector2(
			_rng.randf_range(160.0, ARENA.x - 160.0),
			_rng.randf_range(160.0, ARENA.y - 160.0))
		if point.distance_to(PLANET_CENTERS[0]) < BASE_RADIUS:
			continue
		if point.distance_to(PLANET_CENTERS[1]) < BASE_RADIUS:
			continue
		var clear := true
		for other in _wild_ships:
			if is_instance_valid(other) and other.global_position.distance_to(point) < 70.0:
				clear = false
				break
		if clear:
			return point
	return ARENA * 0.5

func _spawn_pilots():
	for slot in _player_count():
		var ship = _spawn_ship()
		ship.team = 0
		ship.ship_color = PLAYER_COLORS[slot]
		ship.view_distance = PILOT_VIEW
		ship.fov_degrees = PILOT_FOV
		_world.add_child(ship)
		ship.refresh_cone()
		ship.global_position = PLANET_CENTERS[slot] + Vector2(0.0, -BASE_RADIUS * 0.6)
		ship.rotation = 0.0 if slot == 0 else PI
		ship.setup_pilot(slot, PILOT_SPEED, PILOT_TURN_RATE)
		ship.set_physics_process(false)
		_pilot_ships[slot] = ship

func _spawn_evader(slot: int):
	var ship = _spawn_ship()
	ship.team = 1
	ship.ship_color = C_RED
	ship.max_speed = EVADER_SPEED
	_world.add_child(ship)
	ship.global_position = _evader_spawn_point(slot)
	ship.setup_evader(PLANET_CENTERS[slot], PLANET_RADIUS)
	ship.set_meta("slot", slot)
	_evader_ships.append(ship)

func _evader_spawn_point(slot: int) -> Vector2:
	var target: Vector2 = PLANET_CENTERS[slot]
	var x_lo: float = 30.0 if slot == 0 else ARENA.x * 0.5
	var x_hi: float = ARENA.x * 0.5 if slot == 0 else ARENA.x - 30.0
	var outer_x: float = 30.0 if slot == 0 else ARENA.x - 30.0
	for _attempt in 80:
		var point: Vector2
		match _rng.randi_range(0, 2):
			0:
				point = Vector2(outer_x, _rng.randf_range(40.0, ARENA.y - 40.0))
			1:
				point = Vector2(_rng.randf_range(x_lo, x_hi), 30.0)
			_:
				point = Vector2(_rng.randf_range(x_lo, x_hi), ARENA.y - 30.0)
		if absf(point.x - target.x) < EVADER_MIN_X_GAP:
			continue
		if point.distance_to(target) < EVADER_MIN_DISTANCE:
			continue
		return point
	var fallback_y: float = 40.0 if _rng.randf() < 0.5 else ARENA.y - 40.0
	return Vector2(outer_x, fallback_y)

func _poll_pilots(delta: float):
	for slot in _player_count():
		var ship = _pilot_ships[slot]
		if not is_instance_valid(ship):
			continue
		var thrust: float = 0.0
		var turn: float = 0.0
		var keys: Dictionary = PILOT_KEYS[slot]
		if Input.is_physical_key_pressed(keys["forward"]):
			thrust += 1.0
		if Input.is_physical_key_pressed(keys["backward"]):
			thrust -= 1.0
		if Input.is_physical_key_pressed(keys["right"]):
			turn += 1.0
		if Input.is_physical_key_pressed(keys["left"]):
			turn -= 1.0
		var pad: int = _pad_for(slot)
		if pad >= 0:
			var pad_thrust: float = _pad_thrust(pad)
			var pad_turn: float = _pad_turn(pad)
			if absf(pad_thrust) > 0.0:
				thrust = pad_thrust
			if absf(pad_turn) > 0.0:
				turn = pad_turn
		thrust = clampf(thrust, -1.0, 1.0)
		turn = clampf(turn, -1.0, 1.0)
		var drive: float = thrust
		if drive < 0.0:
			drive *= REVERSE_FACTOR
		ship.pilot_thrust = _ease_input(ship.pilot_thrust, drive, THRUST_RESPONSE, delta)
		ship.pilot_turn = _ease_input(ship.pilot_turn, turn, TURN_RESPONSE, delta)
		_count_actions(slot, thrust, turn)
		if _freeze_pressed(slot):
			_use_freeze(slot)

func _ease_input(current: float, target: float, rise_rate: float, delta: float) -> float:
	var rate: float = rise_rate
	if absf(target) < absf(current) or signf(target) != signf(current):
		rate = rise_rate * SETTLE_BOOST
	return move_toward(current, target, rate * delta)

func _pad_thrust(pad: int) -> float:
	var forward: float = _trigger_value(pad, JOY_AXIS_TRIGGER_RIGHT)
	var reverse: float = _trigger_value(pad, JOY_AXIS_TRIGGER_LEFT)
	if forward > 0.0 or reverse > 0.0:
		return clampf(forward - reverse, -1.0, 1.0)
	var left: float = _stick_value(-Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	var right: float = _stick_value(-Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	return left if absf(left) >= absf(right) else right

func _pad_turn(pad: int) -> float:
	var left: float = _stick_value(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X))
	var right: float = _stick_value(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X))
	return left if absf(left) >= absf(right) else right

func _stick_value(raw: float) -> float:
	var size: float = absf(raw)
	if size <= STICK_DEADZONE:
		return 0.0
	var scaled: float = (size - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
	var curved: float = lerpf(scaled, scaled * scaled * scaled, STICK_CURVE)
	return signf(raw) * clampf(curved, 0.0, 1.0)

func _trigger_value(pad: int, axis: int) -> float:
	var raw: float = absf(Input.get_joy_axis(pad, axis))
	if raw <= TRIGGER_DEADZONE:
		return 0.0
	return clampf((raw - TRIGGER_DEADZONE) / (1.0 - TRIGGER_DEADZONE), 0.0, 1.0)

func _count_actions(slot: int, thrust: float, turn: float):
	var bits: int = 0
	if thrust > 0.1:
		bits |= 1
	if thrust < -0.1:
		bits |= 2
	if turn < -0.1:
		bits |= 4
	if turn > 0.1:
		bits |= 8
	var changed: int = bits ^ int(_input_bits[slot])
	if changed != 0:
		var count: int = 0
		for bit in 4:
			if changed & (1 << bit):
				count += 1
		_actions[slot] += count
		_bucket_actions[slot] += count
	_input_bits[slot] = bits

func _freeze_pressed(slot: int) -> bool:
	var down: bool = Input.is_physical_key_pressed(PILOT_KEYS[slot]["freeze"])
	var pad: int = _pad_for(slot)
	if pad >= 0 and Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER):
		down = true
	var was: bool = bool(_freeze_down[slot])
	_freeze_down[slot] = down
	return down and not was

func _use_freeze(slot: int):
	if _freezes_left[slot] <= 0:
		return
	var target = _pilot_ships[1 - slot]
	if not is_instance_valid(target):
		return
	_freezes_left[slot] -= 1
	_freezes_used[slot] += 1
	_actions[slot] += 1
	_bucket_actions[slot] += 1
	target.freeze_for(FREEZE_SECONDS)

func _on_ship_herded(_ship, slot: int):
	if slot < 0 or slot >= _player_count():
		return
	_herded_total[slot] += 1

func _all_ships() -> Array:
	var out: Array = []
	for ship in get_tree().get_nodes_in_group("survive_ships"):
		if is_instance_valid(ship):
			out.append(ship)
	return out

func _resolve_lasers():
	for ship in _all_ships():
		if not ship.can_shoot():
			continue
		var evader = ship.visible_evader()
		if evader == null or evader.is_spent():
			continue
		_fire_laser(ship, evader)

func _fire_laser(defender, evader):
	var beam := LASER.new()
	beam.from_point = defender.global_position
	beam.to_point = evader.global_position
	beam.beam_color = Color(0.55, 0.85, 1.0, 1.0)
	_world.add_child(beam)
	_explode_at(evader.global_position, 70.0)
	_explode_at(defender.global_position, 56.0)
	evader.explode()
	defender.explode()

func _resolve_planet_hits():
	for evader in _evader_ships:
		if not is_instance_valid(evader) or evader.is_spent():
			continue
		var slot: int = int(evader.get_meta("slot", 0))
		if evader.global_position.distance_to(PLANET_CENTERS[slot]) > PLANET_RADIUS + SHIP_HULL:
			continue
		_evaders_through[slot] += 1
		_explode_at(evader.global_position, 90.0)
		evader.explode()

func _explode_at(point: Vector2, size: float):
	var blast := EXPLOSION.new()
	blast.display_size = size
	_world.add_child(blast)
	blast.global_position = point

func _on_ship_exploded(ship):
	_wild_ships.erase(ship)

func _sample_apm(delta: float):
	_bucket_time += delta
	while _bucket_time >= APM_BUCKET_SECONDS:
		_bucket_time -= APM_BUCKET_SECONDS
		_apm_times.append(int(round(_elapsed - _bucket_time)))
		for slot in _player_count():
			var per_minute: float = float(_bucket_actions[slot]) * (60.0 / APM_BUCKET_SECONDS)
			_apm_series[slot].append(int(round(per_minute)))
			_bucket_actions[slot] = 0

func _finish():
	_phase = Phase.DONE
	_flush_apm()
	for ship in _all_ships():
		ship.set_physics_process(false)
	if _evaders_through[0] < _evaders_through[1]:
		_outcome = "player1"
	elif _evaders_through[1] < _evaders_through[0]:
		_outcome = "player2"
	else:
		_outcome = "tie"
	_show_result()
	_submit_match()

func _flush_apm():
	if _bucket_time <= 0.05:
		return
	_apm_times.append(int(round(_elapsed)))
	for slot in _player_count():
		var per_minute: float = float(_bucket_actions[slot]) * (60.0 / maxf(0.5, _bucket_time))
		_apm_series[slot].append(int(round(per_minute)))
		_bucket_actions[slot] = 0
	_bucket_time = 0.0

func _defenders_for(slot: int) -> int:
	var count: int = 0
	for ship in _all_ships():
		if ship.role != SHIP_CLASS.Role.HERDED:
			continue
		var own: float = ship.global_position.distance_to(PLANET_CENTERS[slot])
		var rival: float = ship.global_position.distance_to(PLANET_CENTERS[1 - slot])
		if own <= rival:
			count += 1
	return count

func _wild_remaining() -> int:
	var count: int = 0
	for ship in _all_ships():
		if ship.role == SHIP_CLASS.Role.WILD:
			count += 1
	return count

func _player_name(slot: int) -> String:
	if slot == 0 and PlayerData.has_profile():
		return PlayerData.username
	return "PLAYER %d" % (slot + 1)

func _average_apm(slot: int) -> float:
	if _apm_series[slot].is_empty():
		return 0.0
	var total: float = 0.0
	for value in _apm_series[slot]:
		total += float(value)
	return total / float(_apm_series[slot].size())

func _peak_apm(slot: int) -> int:
	var peak: int = 0
	for value in _apm_series[slot]:
		peak = maxi(peak, int(value))
	return peak

func _submit_match():
	if _match_submitted:
		return
	_match_submitted = true
	if not SurviveUploader.submit_finished.is_connected(_on_submit_finished):
		SurviveUploader.submit_finished.connect(_on_submit_finished)
	_upload_label.text = "UPLOADING MATCH DATA..."
	SurviveUploader.submit(_match_payload())

func _match_payload() -> Dictionary:
	var players: Array = []
	for slot in _player_count():
		players.append({
			"slot": slot + 1,
			"name": _player_name(slot),
			"evaders_through": _evaders_through[slot],
			"defenders_at_end": _defenders_for(slot),
			"herded_total": _herded_total[slot],
			"freezes_used": _freezes_used[slot],
			"actions": _actions[slot],
			"apm_average": snappedf(_average_apm(slot), 0.1),
			"apm_peak": _peak_apm(slot),
		})
	return {
		"outcome": _outcome,
		"duration": int(round(minf(_elapsed, MATCH_SECONDS))),
		"players": players,
		"apm_bucket_seconds": int(APM_BUCKET_SECONDS),
		"apm_times": _apm_times,
		"apm_player1": _apm_series[0],
		"apm_player2": _apm_series[1],
		"evaders_spawned": _spawn_index,
		"wild_remaining": _wild_remaining(),
		"first_target": _first_target + 1,
	}

func _on_submit_finished(success: bool, code: int, _response):
	if success:
		_upload_label.text = "MATCH DATA SUBMITTED"
		_upload_label.add_theme_color_override("font_color", C_GREENISH)
	else:
		_upload_label.text = "UPLOAD FAILED (%d)" % code
		_upload_label.add_theme_color_override("font_color", C_RED)

func _show_result():
	match _outcome:
		"player1":
			_result_title.text = "%s WINS" % _player_name(0)
			_result_title.add_theme_color_override("font_color", PLAYER_COLORS[0])
		"player2":
			_result_title.text = "%s WINS" % _player_name(1)
			_result_title.add_theme_color_override("font_color", PLAYER_COLORS[1])
		_:
			_result_title.text = "TIE MATCH"
			_result_title.add_theme_color_override("font_color", C_AMBER)
	_result_headline.text = "EVADERS THROUGH   %d  -  %d" % [_evaders_through[0], _evaders_through[1]]
	_fill_result_grid()
	_result_panel.visible = true

func _fill_result_grid():
	for child in _result_grid.get_children():
		_result_grid.remove_child(child)
		child.queue_free()
	_stat_row("", _player_name(0), _player_name(1), C_DIM, PLAYER_COLORS[0], PLAYER_COLORS[1])
	_stat_row("EVADERS THROUGH", str(_evaders_through[0]), str(_evaders_through[1]), C_DIM, C_RED, C_RED)
	_stat_row("DEFENDERS LEFT", str(_defenders_for(0)), str(_defenders_for(1)), C_DIM, C_ACCENT, C_ACCENT)
	_stat_row("SHIPS HERDED", str(_herded_total[0]), str(_herded_total[1]), C_DIM, C_TEXT, C_TEXT)
	_stat_row("FREEZES USED", str(_freezes_used[0]), str(_freezes_used[1]), C_DIM, C_TEXT, C_TEXT)
	_stat_row("ACTIONS", str(_actions[0]), str(_actions[1]), C_DIM, C_TEXT, C_TEXT)
	_stat_row("AVERAGE APM", "%.0f" % _average_apm(0), "%.0f" % _average_apm(1), C_DIM, C_GREENISH, C_GREENISH)
	_stat_row("PEAK APM", str(_peak_apm(0)), str(_peak_apm(1)), C_DIM, C_GREENISH, C_GREENISH)
	_stat_row("EVADERS LAUNCHED", str(_spawn_index), "", C_DIM, C_TEXT, C_TEXT)
	_stat_row("PURPLE STILL WILD", str(_wild_remaining()), "", C_DIM, C_TEXT, C_TEXT)

func _stat_row(label: String, left: String, right: String, label_color: Color, left_color: Color, right_color: Color):
	var name_label := _lbl(label, 10, label_color)
	name_label.custom_minimum_size = Vector2(220, 0)
	_result_grid.add_child(name_label)

	var left_label := _lbl(left, 11, left_color)
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left_label.custom_minimum_size = Vector2(170, 0)
	_result_grid.add_child(left_label)

	var right_label := _lbl(right, 11, right_color)
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_label.custom_minimum_size = Vector2(170, 0)
	_result_grid.add_child(right_label)

func _restart():
	get_tree().reload_current_scene()

func _leave():
	get_tree().change_scene_to_file("res://levels/menus/PlayerBaseScene.tscn")

func _make_bg_stars() -> Array:
	var stars: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for _i in 900:
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, ARENA.x), rng.randf_range(0.0, ARENA.y)),
			"sz":  rng.randf_range(1.0, 2.4),
			"a":   rng.randf_range(0.12, 0.55),
		})
	return stars

func _build_planets():
	var seeds := [PlayerData.planet_seed, PlayerData.planet_seed + 7717]
	for slot in _player_count():
		var planet := TERRAN.instantiate() as Control
		_world.add_child(planet)
		planet.generate(int(seeds[slot]), PLANET_PIXELS)
		planet.z_index = 2
		var sc: float = PLANET_DISP / PLANET_PIXELS
		planet.scale = Vector2(sc, sc)
		planet.position = PLANET_CENTERS[slot] - Vector2(PLANET_DISP * 0.5, PLANET_DISP * 0.5)
		_disable_mouse(planet)

func _disable_mouse(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_mouse(child)


func _build_hud():
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = GAME_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	var divider := ColorRect.new()
	divider.color = C_BORDER
	divider.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	divider.anchor_left = 0.5
	divider.anchor_right = 0.5
	divider.anchor_top = 0.0
	divider.anchor_bottom = 1.0
	divider.offset_left = -1
	divider.offset_right = 2
	divider.offset_top = 0
	divider.offset_bottom = 0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(divider)

	var leave := _make_compact_btn("< LEAVE")
	leave.pressed.connect(_leave)
	leave.set_anchors_preset(Control.PRESET_TOP_LEFT)
	leave.offset_left = 12
	leave.offset_top = 12
	root.add_child(leave)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.offset_left = -200
	center.offset_right = 200
	center.offset_top = 10
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_timer_label = _lbl("3:00", 26, C_TEXT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_timer_label)

	_wave_label = _lbl("", 10, C_AMBER)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_wave_label)

	for slot in _player_count():
		_player_panels[slot] = _build_player_panel(root, slot)
		_build_freeze_indicator(root, slot)

	_hint_label = _lbl("", 12, C_TEXT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.offset_left = -460
	_hint_label.offset_right = 460
	_hint_label.offset_top = -46
	_hint_label.offset_bottom = -16
	root.add_child(_hint_label)

	_build_result_panel(root)
	_refresh_hud()
	_refresh_hint()

func _build_player_panel(root: Control, slot: int) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot == 0:
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.offset_left = 12
		box.offset_top = 46
		box.offset_right = 300
	else:
		box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		box.offset_left = -300
		box.offset_top = 12
		box.offset_right = -12
	root.add_child(box)

	var align: int = HORIZONTAL_ALIGNMENT_LEFT if slot == 0 else HORIZONTAL_ALIGNMENT_RIGHT

	var name_label := _lbl("P%d  %s" % [slot + 1, _player_name(slot)], 13, PLAYER_COLORS[slot])
	name_label.horizontal_alignment = align
	box.add_child(name_label)

	var through := _lbl("", 11, C_RED)
	through.horizontal_alignment = align
	box.add_child(through)

	var defenders := _lbl("", 11, C_ACCENT)
	defenders.horizontal_alignment = align
	box.add_child(defenders)

	var apm := _lbl("", 11, C_DIM)
	apm.horizontal_alignment = align
	box.add_child(apm)

	var input := _lbl("", 10, C_DIM)
	input.horizontal_alignment = align
	box.add_child(input)

	return {"through": through, "defenders": defenders, "apm": apm, "input": input}

func _build_freeze_indicator(root: Control, slot: int):
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot == 0:
		column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		column.offset_left = 14
		column.offset_right = 86
	else:
		column.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		column.offset_left = -86
		column.offset_right = -14
	column.offset_top = -110
	column.offset_bottom = 110
	root.add_child(column)

	var title := _lbl("FREEZE", 9, C_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var key := _lbl(FREEZE_KEY_HINTS[slot], 13, PLAYER_COLORS[slot])
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(key)
	_freeze_keys[slot] = key

	var pips: Array = []
	var texture: Texture2D = load(FREEZE_ICON_PATH)
	for _i in FREEZE_CHARGES:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icon)
		pips.append(icon)
	_freeze_pips[slot] = pips

	var status := _lbl("", 10, C_ACCENT)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	_freeze_status[slot] = status

func _refresh_hud():
	if _timer_label == null:
		return
	if _phase == Phase.READY and _both_ready():
		_timer_label.text = "%d" % int(ceilf(maxf(0.0, _countdown)))
		_timer_label.add_theme_color_override("font_color", C_GREENISH)
	else:
		var remaining: float = maxf(0.0, MATCH_SECONDS - _elapsed)
		_timer_label.text = "%d:%02d" % [floori(remaining / 60.0), int(remaining) % 60]
		_timer_label.add_theme_color_override("font_color", C_RED if (_phase == Phase.ACTIVE and remaining <= 30.0) else C_TEXT)
	_wave_label.text = _wave_text() if _phase == Phase.ACTIVE else ""
	for slot in _player_count():
		var panel: Dictionary = _player_panels[slot]
		panel["through"].text = "EVADERS THROUGH: %d" % _evaders_through[slot]
		panel["defenders"].text = "DEFENDERS: %d" % _defenders_for(slot)
		panel["apm"].text = "APM: %.0f" % _average_apm(slot)
		_refresh_input_label(panel["input"], slot)
		_refresh_freeze(slot)
	if _phase != Phase.ACTIVE:
		_refresh_hint()

func _refresh_input_label(label: Label, slot: int):
	var pad: int = _pad_for(slot)
	if pad >= 0:
		label.text = "[ GAMEPAD ]  %s  -  stick or triggers to fly  (B to detach)" % Input.get_joy_name(pad).to_upper().substr(0, 16)
		label.add_theme_color_override("font_color", C_GREENISH)
		return
	label.add_theme_color_override("font_color", C_DIM)
	if _unclaimed_pads() > 0:
		label.text = "[ KEYBOARD ]  %s  -  press A on a controller to attach it" % PILOT_KEY_HINTS[slot]
	else:
		label.text = "[ KEYBOARD ]  %s" % PILOT_KEY_HINTS[slot]

func _refresh_freeze(slot: int):
	var key: Label = _freeze_keys[slot]
	key.text = "RB" if _pad_for(slot) >= 0 else FREEZE_KEY_HINTS[slot]
	var pips: Array = _freeze_pips[slot]
	for i in pips.size():
		pips[i].modulate = Color(1, 1, 1, 1.0) if i < _freezes_left[slot] else Color(1, 1, 1, 0.14)
	var status: Label = _freeze_status[slot]
	var ship = _pilot_ships[slot]
	if is_instance_valid(ship) and ship.freeze_remaining > 0.0:
		status.text = "FROZEN %ds" % int(ceilf(ship.freeze_remaining))
		status.add_theme_color_override("font_color", C_ACCENT)
	else:
		status.text = ""

func _refresh_hint():
	if _hint_label == null:
		return
	match _phase:
		Phase.READY:
			if _both_ready():
				_hint_label.text = "STARTING IN %d  -  press %s or %s to cancel" % [
					int(ceilf(maxf(0.0, _countdown))), READY_KEY_HINTS[0], READY_KEY_HINTS[1]]
			else:
				var parts: Array = []
				for slot in _player_count():
					var state: String = "READY" if _ready_flags[slot] else "PRESS %s" % _ready_key_hint(slot)
					parts.append("P%d %s" % [slot + 1, state])
				_hint_label.text = "  -  ".join(parts)
		Phase.ACTIVE:
			_hint_label.text = "herd the purple ships home before the waves arrive"
		_:
			_hint_label.text = ""

func _ready_key_hint(slot: int) -> String:
	if _pad_for(slot) >= 0:
		return "A"
	return READY_KEY_HINTS[slot]

func _build_result_panel(root: Control):
	_result_panel = Control.new()
	_result_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.visible = false
	_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_result_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_panel.add_child(dim)

	var card := _panel(C_PANEL, C_BORDER, 2, 8)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -330
	card.offset_top = -260
	card.offset_right = 330
	card.offset_bottom = 260
	_result_panel.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_result_title = _lbl("", 22, C_TEXT)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)

	_result_headline = _lbl("", 12, C_DIM)
	_result_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_headline)

	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	box.add_child(sep)

	_result_grid = GridContainer.new()
	_result_grid.columns = 3
	_result_grid.add_theme_constant_override("h_separation", 12)
	_result_grid.add_theme_constant_override("v_separation", 7)
	box.add_child(_result_grid)

	_upload_label = _lbl("", 10, C_DIM)
	_upload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_upload_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	var again := _make_btn("PLAY AGAIN", 11)
	again.pressed.connect(_restart)
	row.add_child(again)

	var back := _make_btn("BACK TO BASE", 11)
	back.pressed.connect(_leave)
	row.add_child(back)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_REG)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_btn(text: String, size: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT_REG)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _make_compact_btn(text: String) -> Button:
	var b := _make_btn(text, 9)
	b.add_theme_stylebox_override("normal", _compact_btn_style(C_PANEL, C_BORDER))
	b.add_theme_stylebox_override("hover", _compact_btn_style(Color(0.18, 0.17, 0.27, 1.0), C_ACCENT))
	b.add_theme_stylebox_override("pressed", _compact_btn_style(Color(0.1, 0.095, 0.155, 1.0), C_ACCENT))
	b.add_theme_stylebox_override("focus", _compact_btn_style(C_PANEL, C_BORDER))
	b.add_theme_color_override("font_color", C_TEXT)
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
	style.set_border_width_all(bw)
	style.set_corner_radius_all(radius)
	pc.add_theme_stylebox_override("panel", style)
	return pc
