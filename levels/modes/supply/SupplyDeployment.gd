extends "res://levels/modes/AssaultBase.gd"

# The deployment window of a supply level: the player-flown shuttle, the
# defenders that follow it, and the crossings that move them between planets.
const STATE := preload("res://levels/modes/supply/SupplyState.gd")

enum Edge { RIGHT, LEFT, TOP, BOTTOM }

const SHUTTLE_SPEED := 260.0 # pixels/second (6.5 m/s)
const SHUTTLE_TURN  := 3.0   # radians/second
const SHUTTLE_HP    := 99.0  # hit points

const TRANSIT_SPEED     := 340.0 # pixels/second a summoned defender crosses at
const TRANSIT_TURN      := 3.4   # radians/second
const ARRIVE_RADIUS     := 24.0  # pixels from the marker that counts as landed
const APPROACH_DISTANCE := 160.0 # pixels out from the marker where a crossing eases off

const CAMERA_LERP   := 6.0   # camera follow rate, higher is snappier

const GATE_BAND     := 48.0  # pixels, width of the jump gate strip along the gate edge
const ARRIVAL_INSET := 90.0  # pixels in from the gate edge where crossings come out
const GATE_COOLDOWN := 1.5   # seconds after a jump before the gate takes the shuttle again
const DEFENDER_CROSSING_SECONDS := 2.5

const C_SHUTTLE := Color(1.0, 0.84, 0.2, 1.0)
const C_DARK    := Color(0.85, 0.4, 0.95, 1.0)

const GATE_TEXTURES := {
	Edge.RIGHT: preload("res://assets/edges/gate_edge_right.svg"),
	Edge.LEFT: preload("res://assets/edges/gate_edge_left.svg"),
	Edge.TOP: preload("res://assets/edges/gate_edge_top.svg"),
	Edge.BOTTOM: preload("res://assets/edges/gate_edge_bottom.svg"),
}

var _shuttle: Node2D = null
var _transits: Array = []
var _gate_lock: float = 0.0

func _planet_index() -> int:
	return STATE.PLANET_A

func _planet_count() -> int:
	return 2

func _planet_scenes() -> Array:
	return []

func _gates(_planet: int) -> Array:
	return []

func _planet_letter() -> String:
	return STATE.letter(_planet_index())

func _scene_for(planet: int) -> String:
	return _planet_scenes()[planet]

func _change_scene(_path: String):
	pass

# The ships of the planet on screen are live nodes, so their positions are
# written back to the run state before this scene is torn down.
func _capture_garrison():
	var out: Array = []
	for ship in _defender_ships:
		if is_instance_valid(ship):
			out.append({"pos": ship.global_position, "rot": ship.rotation})
	STATE.capture(_planet_index(), out)
	_placements = out.duplicate(true)

func _hand_scene_over():
	_settle_transits()
	_capture_garrison()

# Flown in every stage, so this is called when the deployment window opens and
# again when an assault starts in a scene the shuttle has not reached yet.
func _launch_shuttle():
	_spawn_shuttle()
	_camera.position = _shuttle.global_position
	_clamp_camera()
	_gate_lock = GATE_COOLDOWN

func _spawn_shuttle():
	_shuttle = _make_ship([], SHUTTLE_HP, _shuttle_color())
	_shuttle.show_cone = false
	_shuttle.sensor_visible = not STATE.cloaked
	if STATE.shuttle_parked:
		_shuttle.global_position = STATE.shuttle_position
		_shuttle.rotation = STATE.shuttle_rotation
		return
	if STATE.trips == 0 and _planet_index() == STATE.PLANET_A:
		var start: Vector2 = _planet + Vector2(0.0, PLACE_MAX + 120.0)
		_shuttle.global_position = start
		_shuttle.rotation = (_planet - start).angle()
		return
	var edge: int = _gate_toward(_planet_index(), STATE.came_from)["edge"]
	_shuttle.global_position = _arrival_point(edge, STATE.gate_along)
	_shuttle.rotation = _arrival_heading(edge)

func _shuttle_color() -> Color:
	return C_DARK if STATE.cloaked else C_SHUTTLE

func _despawn_shuttle():
	if is_instance_valid(_shuttle):
		_shuttle.queue_free()
	_shuttle = null

func _gate_toward(planet: int, target: int) -> Dictionary:
	var gates: Array = _gates(planet)
	for gate in gates:
		if int(gate["to"]) == target:
			return gate
	return gates[0]

func _gate_at(point: Vector2) -> Dictionary:
	for gate in _gates(_planet_index()):
		if _in_band(int(gate["edge"]), point):
			return gate
	return {}

func _in_band(edge: int, point: Vector2) -> bool:
	match edge:
		Edge.RIGHT:
			return point.x >= _arena.x - GATE_BAND
		Edge.LEFT:
			return point.x <= GATE_BAND
		Edge.TOP:
			return point.y <= GATE_BAND
	return point.y >= _arena.y - GATE_BAND

func _band_rect(edge: int) -> Rect2:
	match edge:
		Edge.RIGHT:
			return Rect2(_arena.x - GATE_BAND, 0.0, GATE_BAND, _arena.y)
		Edge.LEFT:
			return Rect2(0.0, 0.0, GATE_BAND, _arena.y)
		Edge.TOP:
			return Rect2(0.0, 0.0, _arena.x, GATE_BAND)
	return Rect2(0.0, _arena.y - GATE_BAND, _arena.x, GATE_BAND)

func _along(edge: int, point: Vector2) -> float:
	return point.y if edge == Edge.RIGHT or edge == Edge.LEFT else point.x

func _arrival_point(edge: int, along: float) -> Vector2:
	var vertical: bool = edge == Edge.RIGHT or edge == Edge.LEFT
	var span: float = _arena.y if vertical else _arena.x
	var position_along: float = span * 0.5 if along < 0.0 else clampf(along, ARRIVAL_INSET, span - ARRIVAL_INSET)
	match edge:
		Edge.RIGHT:
			return Vector2(_arena.x - ARRIVAL_INSET, position_along)
		Edge.LEFT:
			return Vector2(ARRIVAL_INSET, position_along)
		Edge.TOP:
			return Vector2(position_along, ARRIVAL_INSET)
	return Vector2(position_along, _arena.y - ARRIVAL_INSET)

func _arrival_heading(edge: int) -> float:
	match edge:
		Edge.RIGHT:
			return PI
		Edge.LEFT:
			return 0.0
		Edge.TOP:
			return PI * 0.5
	return -PI * 0.5

# The shuttle is flown for the whole run, the deployment window and every
# assault alike, so this runs in every stage.
func _pilot_shuttle(delta: float):
	if not is_instance_valid(_shuttle):
		return
	_drive_with_keys(_shuttle, delta, SHUTTLE_SPEED, SHUTTLE_TURN)
	STATE.park_shuttle(_shuttle.global_position, _shuttle.rotation)
	_follow_shuttle(delta)

func _update_allocation(delta: float):
	STATE.allocate_remaining = maxf(0.0, STATE.ALLOCATE_SECONDS - _elapsed)
	_update_transits(delta)
	_send_defenders_through_gate()
	_land_crossings(STATE.tick_crossings(delta))
	_gate_lock = maxf(0.0, _gate_lock - delta)
	_check_gate()
	_update_countdown_color()
	_update_count()

# Middle-drag still pans freely, and the camera picks the shuttle back up as
# soon as the drag ends.
func _follow_shuttle(delta: float):
	if _panning:
		return
	_camera.position = _camera.position.lerp(_shuttle.global_position, clampf(delta * CAMERA_LERP, 0.0, 1.0))
	_clamp_camera()

func _steer(ship: Node2D, heading: float, delta: float, speed: float, turn: float):
	var difference: float = angle_difference(ship.rotation, heading)
	ship.rotation += clampf(difference, -turn * delta, turn * delta)
	ship.global_position += Vector2.RIGHT.rotated(ship.rotation) * speed * delta
	_keep_clear(ship)
	ship.queue_redraw()

func _keep_clear(ship: Node2D):
	ship.global_position.x = clampf(ship.global_position.x, 20.0, _arena.x - 20.0)
	ship.global_position.y = clampf(ship.global_position.y, 20.0, _arena.y - 20.0)
	if not _planet_collisions():
		return
	var offset: Vector2 = ship.global_position - _planet
	var minimum: float = PLANET_RADIUS + ship.hull_radius
	var distance: float = offset.length()
	if distance < 0.001:
		ship.global_position = _planet + Vector2(minimum, 0.0)
	elif distance < minimum:
		ship.global_position = _planet + offset / distance * minimum

func _check_gate():
	if _gate_lock > 0.0 or not is_instance_valid(_shuttle):
		return
	var gate: Dictionary = _gate_at(_shuttle.global_position)
	if gate.is_empty():
		return
	STATE.came_from = _planet_index()
	STATE.gate_along = _along(int(gate["edge"]), _shuttle.global_position)
	STATE.trips += 1
	_change_scene(_scene_for(int(gate["to"])))

func _send_defenders_through_gate():
	var staying: Array = []
	for ship in _defender_ships:
		if not is_instance_valid(ship):
			continue
		var gate: Dictionary = _gate_at(ship.global_position)
		if not gate.is_empty():
			var along: float = _along(int(gate["edge"]), ship.global_position)
			STATE.send_crossing(_planet_index(), int(gate["to"]), along, DEFENDER_CROSSING_SECONDS)
			ship.queue_free()
			continue
		staying.append(ship)
	if staying.size() == _defender_ships.size():
		return
	_defender_ships = staying
	_update_count()

func _land_crossings(arrived: Array):
	for crossing in arrived:
		var planet: int = int(crossing["to"])
		var edge: int = _gate_toward(planet, int(crossing["from"]))["edge"]
		var arrival := {"pos": _arrival_point(edge, float(crossing["along"])), "rot": _arrival_heading(edge)}
		if crossing.has("target") and planet == _planet_index():
			_start_transit(arrival["pos"], crossing["target"], float(crossing["rot"]))
			continue
		if crossing.has("target"):
			arrival = {"pos": crossing["target"], "rot": crossing["rot"]}
		if planet != STATE.PLANET_A:
			STATE.delivered += 1
		if planet != _planet_index():
			_station_away(planet, arrival)
			continue
		_spawn_defender(arrival, PlayerData.ship_blocks)
		_defender_arrived(_defender_ships.back())
	if not arrived.is_empty():
		_update_count()

func _station_away(planet: int, arrival: Dictionary):
	STATE.garrison(planet).append(arrival)

func _defender_arrived(ship: Node2D):
	ship.set_physics_process(_phase == Phase.ACTIVE)

func _settle_crossings():
	_land_crossings(STATE.take_crossings())

func _level_input(event: InputEvent):
	if _phase != Phase.ACTIVE:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_Q:
		_toggle_dark()
	elif event.keycode == KEY_E and STATE.stage != STATE.Stage.DONE:
		_summon_defender()

func _toggle_dark():
	STATE.cloaked = not STATE.cloaked
	if is_instance_valid(_shuttle):
		_shuttle.ship_color = _shuttle_color()
		_shuttle.sensor_visible = not STATE.cloaked
	queue_redraw()

func _summon_defender():
	if not is_instance_valid(_shuttle):
		return
	var distance: float = _shuttle.global_position.distance_to(_planet)
	if distance < PLACE_MIN or distance > PLACE_MAX:
		return
	var source: int = _summon_source()
	if source < 0 or not _detach_from(source):
		return
	var edge: int = _gate_toward(_planet_index(), source)["edge"]
	var marker := {"target": _shuttle.global_position, "rot": _shuttle.rotation}
	STATE.send_crossing(source, _planet_index(), _along(edge, _shuttle.global_position), DEFENDER_CROSSING_SECONDS, marker)
	_update_count()
	queue_redraw()

func _summon_source() -> int:
	return STATE.fullest_planet_except(_planet_index())

func _detach_from(planet: int) -> bool:
	return STATE.detach(planet)

func _start_transit(entry_point: Vector2, target: Vector2, heading: float):
	var ship := _make_ship(PlayerData.ship_blocks, DEFENDER_HP, C_DARK)
	ship.sensor_visible = false
	ship.global_position = entry_point
	ship.rotation = (target - entry_point).angle()
	_transits.append({"ship": ship, "target": target, "rot": heading})
	queue_redraw()

func _update_transits(delta: float):
	var still: Array = []
	for entry in _transits:
		var ship = entry["ship"]
		if not is_instance_valid(ship):
			continue
		var target: Vector2 = entry["target"]
		var distance: float = ship.global_position.distance_to(target)
		if distance <= ARRIVE_RADIUS:
			_land_transit(ship, target, float(entry["rot"]))
			continue
		var speed: float = TRANSIT_SPEED * clampf(distance / APPROACH_DISTANCE, 0.25, 1.0)
		_steer(ship, (target - ship.global_position).angle(), delta, speed, TRANSIT_TURN)
		still.append(entry)
	_transits = still

# A crossing only rejoins the line once it is down on its marker: it drops the
# dark purple, comes back onto everyone's sensors and starts running the
# workspace algorithm with the rest of them.
func _land_transit(ship: Node2D, target: Vector2, heading: float):
	ship.global_position = target
	ship.rotation = heading
	ship.ship_color = _defender_color()
	ship.sensor_visible = true
	ship.queue_redraw()
	_defender_ships.append(ship)
	_defender_arrived(ship)
	if _planet_index() != STATE.PLANET_A:
		STATE.delivered += 1
	_update_count()

func _settle_transits():
	for entry in _transits:
		var ship = entry["ship"]
		if is_instance_valid(ship):
			_land_transit(ship, entry["target"], float(entry["rot"]))
	_transits.clear()

func _count_at(planet: int) -> int:
	if planet == _planet_index():
		return _defender_ships.size() + _transits.size() + STATE.crossings_to(planet)
	return STATE.garrison(planet).size() + STATE.crossings_to(planet)

func _clear_ships():
	_despawn_shuttle()
	for entry in _transits:
		var ship = entry["ship"]
		if is_instance_valid(ship):
			ship.queue_free()
	_transits.clear()
	super()

func _draw_allocation():
	draw_circle(_planet, PLACE_MAX, ZONE_FILL)
	_draw_dashed_circle(_planet, PLACE_MAX, Color(0.451, 0.616, 1.0, 0.35), 1.5)
	_draw_dashed_circle(_planet, PLACE_MIN, Color(0.6, 0.62, 0.74, 0.25), 1.0)
	for entry in _transits:
		_draw_marker(entry["target"], C_DARK)
	for crossing in STATE.crossings:
		if crossing.has("target") and int(crossing["to"]) == _planet_index():
			_draw_marker(crossing["target"], C_DARK)

func _draw_edges():
	super()
	if STATE.stage == STATE.Stage.DONE:
		return
	for gate in _gates(_planet_index()):
		var edge: int = int(gate["edge"])
		draw_texture_rect(GATE_TEXTURES[edge], _band_rect(edge), true)

func _draw_marker(center: Vector2, color: Color):
	var arm: float = 16.0
	draw_arc(center, 9.0, 0.0, TAU, 20, color, 2.0, true)
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), color, 1.5, true)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), color, 1.5, true)
