extends "res://levels/modes/AssaultBase.gd"

# The deployment window of level 8: the player-flown shuttle, the defenders that
# follow it, and the crossings that move one from the other planet onto a marker.
const STATE := preload("res://levels/modes/level8/Level8State.gd")

const SHUTTLE_SPEED := 260.0 # pixels/second (6.5 m/s)
const SHUTTLE_TURN  := 3.0   # radians/second
const SHUTTLE_HP    := 99.0  # hit points

const TRANSIT_SPEED     := 340.0 # pixels/second a summoned defender crosses at
const TRANSIT_TURN      := 3.4   # radians/second
const ARRIVE_RADIUS     := 24.0  # pixels from the marker that counts as landed
const APPROACH_DISTANCE := 160.0 # pixels out from the marker where a crossing eases off

const CAMERA_LERP   := 6.0   # camera follow rate, higher is snappier

const GATE_RADIUS   := 130.0 # pixels, radius of the jump gate ring
const GATE_INSET    := 300.0 # pixels, how far the gate sits inside the arena edge
const GATE_COOLDOWN := 1.5   # seconds after a jump before the gate takes the shuttle again

const C_SHUTTLE := Color(1.0, 0.84, 0.2, 1.0)
const C_DARK    := Color(0.85, 0.4, 0.95, 1.0)
const C_GATE    := Color(0.55, 0.90, 1.0, 1.0)

var _shuttle: Node2D = null
var _transits: Array = []
var _gate_lock: float = 0.0

func _planet_index() -> int:
	return STATE.PLANET_A

func _other_index() -> int:
	return STATE.other_planet(_planet_index())

func _letter(planet: int) -> String:
	return "A" if planet == STATE.PLANET_A else "B"

func _planet_letter() -> String:
	return _letter(_planet_index())

func _cross_to_other_planet():
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

func _shuttle_start() -> Vector2:
	if STATE.trips == 0 and _planet_index() == STATE.PLANET_A:
		return _planet + Vector2(0.0, PLACE_MAX + 120.0)
	var gate: Vector2 = _gate_center()
	return gate + (_planet - gate).normalized() * (GATE_RADIUS + 60.0)

func _spawn_shuttle():
	_shuttle = _make_ship([], SHUTTLE_HP, _shuttle_color())
	_shuttle.sensor_visible = not STATE.cloaked
	if STATE.shuttle_parked:
		_shuttle.global_position = STATE.shuttle_position
		_shuttle.rotation = STATE.shuttle_rotation
		return
	var at: Vector2 = _shuttle_start()
	_shuttle.global_position = at
	_shuttle.rotation = (_planet - at).angle()

func _shuttle_color() -> Color:
	return C_DARK if STATE.cloaked else C_SHUTTLE

func _despawn_shuttle():
	if is_instance_valid(_shuttle):
		_shuttle.queue_free()
	_shuttle = null

func _gate_center() -> Vector2:
	if _planet_index() == STATE.PLANET_A:
		return Vector2(_arena.x - GATE_INSET, _arena.y * 0.5)
	return Vector2(GATE_INSET, _arena.y * 0.5)

# The shuttle is flown for the whole run, the deployment window and both
# assaults alike, so this runs in every stage.
func _pilot_shuttle(delta: float):
	if not is_instance_valid(_shuttle):
		return
	_drive_with_keys(_shuttle, delta, SHUTTLE_SPEED, SHUTTLE_TURN)
	STATE.park_shuttle(_shuttle.global_position, _shuttle.rotation)
	_follow_shuttle(delta)

func _update_allocation(delta: float):
	STATE.allocate_remaining = maxf(0.0, STATE.ALLOCATE_SECONDS - _elapsed)
	_update_transits(delta)
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
	if _shuttle.global_position.distance_to(_gate_center()) > GATE_RADIUS:
		return
	STATE.trips += 1
	_cross_to_other_planet()

func _level_input(event: InputEvent):
	if _phase != Phase.ACTIVE:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_Q:
		_toggle_dark()
	elif event.keycode == KEY_E and STATE.stage == STATE.Stage.ALLOCATE:
		_summon_defender()

func _toggle_dark():
	STATE.cloaked = not STATE.cloaked
	if is_instance_valid(_shuttle):
		_shuttle.ship_color = _shuttle_color()
		_shuttle.sensor_visible = not STATE.cloaked
	if STATE.cloaked:
		_hint_label.text = "Shuttle dark. The defenders cannot sense you at all and will carry on as if you were not here."
	else:
		_hint_label.text = "Shuttle lit. The defenders read you as an ally again, so your sees-ally rule steers them."
	queue_redraw()

func _summon_defender():
	if not is_instance_valid(_shuttle):
		return
	var distance: float = _shuttle.global_position.distance_to(_planet)
	if distance < PLACE_MIN or distance > PLACE_MAX:
		_hint_label.text = "Drop the marker inside the blue placement band around the planet."
		return
	var other: int = _other_index()
	if not STATE.detach(other):
		_hint_label.text = "Planet %s has nothing left to send." % _letter(other)
		return
	var gate: Vector2 = _gate_center()
	var ship := _make_ship(PlayerData.ship_blocks, DEFENDER_HP, C_DARK)
	ship.sensor_visible = false
	ship.global_position = gate
	ship.rotation = (_shuttle.global_position - gate).angle()
	_transits.append({
		"ship": ship,
		"target": _shuttle.global_position,
		"rot": _shuttle.rotation,
	})
	_hint_label.text = "One defender inbound from planet %s." % _letter(other)
	_update_count()
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
	ship.ship_color = C_DEFENDER
	ship.sensor_visible = true
	ship.set_physics_process(_phase == Phase.ACTIVE)
	ship.queue_redraw()
	_defender_ships.append(ship)
	if _planet_index() == STATE.PLANET_B:
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
		return _defender_ships.size() + _transits.size()
	return STATE.garrison(planet).size()

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
	var gate: Vector2 = _gate_center()
	draw_circle(gate, GATE_RADIUS, Color(C_GATE.r, C_GATE.g, C_GATE.b, 0.08))
	_draw_dashed_circle(gate, GATE_RADIUS, Color(C_GATE.r, C_GATE.g, C_GATE.b, 0.7), 2.0)
	_draw_dashed_circle(gate, GATE_RADIUS * 0.55, Color(C_GATE.r, C_GATE.g, C_GATE.b, 0.35), 1.5)
	for entry in _transits:
		_draw_marker(entry["target"], C_DARK)

func _draw_marker(center: Vector2, color: Color):
	var arm: float = 16.0
	draw_arc(center, 9.0, 0.0, TAU, 20, color, 2.0, true)
	draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), color, 1.5, true)
	draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), color, 1.5, true)
