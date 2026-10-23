extends "res://levels/modes/SurviveScene.gd"

# Sur2: a short Survive cut made for recording. No tutorial or ready-up, no
# research readouts, upload or power-ups. Blue ships run each player's genome
# and capture by touch, every evader is sent by the rival and flies on the
# rival's genome, and the jump gates from the supply levels are in play.
const SUR2_SECONDS     := 60.0
const START_COUNTDOWN  := 3.0
const SUR2_EVADERS     := 10
const FIRST_EVADER     := 15.0 # seconds into the round
const EVADER_GAP       := 3.5  # seconds between evaders
const EVADER_HOMING    := 1.2  # radians/second a sent evader turns toward its planet
const EVADER_TINT      := 0.35 # share of the sender's color mixed into a sent evader

const GATE_BAND        := 48.0  # pixels, width of the jump gate strip on the left and right edges
const ARRIVAL_INSET    := 90.0  # pixels in from the far edge where a crossing comes out
const GATE_COOLDOWN    := 1.0   # seconds before a pilot can take a gate again
const CROSSING_SECONDS := 2.5   # seconds a ship other than a pilot spends crossing
const PARKED           := Vector2(-9000.0, -9000.0) # pixels, where a ship waits out a crossing

const STOCK_GENOME   := "STOCK HERD"

var _genome_names: Array = [STOCK_GENOME, STOCK_GENOME]
var _genome_scripts: Array = [[], []]
var _genome_colors: Array = [SHIP_CLASS.ROLE_COLORS[SHIP_CLASS.Role.HERDED], SHIP_CLASS.ROLE_COLORS[SHIP_CLASS.Role.HERDED]]
var _gate_lock: Array = [0.0, 0.0]
var _crossings: Array = []

func _match_seconds() -> float:
	return SUR2_SECONDS

func _spawn_times() -> Array:
	var times: Array = []
	for index in SUR2_EVADERS:
		times.append(FIRST_EVADER + EVADER_GAP * index)
	return times

func _wave_text() -> String:
	if _spawn_index >= _spawn_queue.size():
		return "ALL EVADERS LAUNCHED"
	if _elapsed < FIRST_EVADER:
		return "EVADERS IN %ds" % int(ceilf(FIRST_EVADER - _elapsed))
	return "EVADERS INCOMING - %d LEFT" % (_spawn_queue.size() - _spawn_index)

func _build_world():
	_pick_genomes()
	super()
	_world.gate_left = load("res://assets/edges/gate_edge_left.svg")
	_world.gate_right = load("res://assets/edges/gate_edge_right.svg")
	_world.gate_band = GATE_BAND

# Player one takes the first genome of the loadout and player two the second,
# falling back to the whole bank when the loadout is short.
func _pick_genomes():
	var pool: Array = GenomeBank.loadout_genomes()
	if pool.size() < 2:
		pool = GenomeBank.genomes
	if pool.is_empty():
		return
	for slot in _player_count():
		var genome: Dictionary = pool[slot % pool.size()]
		_genome_names[slot] = str(genome.get("name", STOCK_GENOME)).to_upper()
		_genome_scripts[slot] = genome.get("scripts", []).duplicate(true)
		_genome_colors[slot] = GenomeBank.genome_color(genome)

func _show_tutorial():
	_phase = Phase.READY
	_ready_flags = [true, true]
	_countdown = START_COUNTDOWN

func _ready_toggled(_slot: int) -> bool:
	return false

func _build_freeze_indicator(_root: Control, _slot: int):
	pass

func _refresh_freeze(_slot: int):
	pass

func _use_freeze(_slot: int):
	pass

func _spawn_ship():
	var ship = super()
	ship.herd_programs = _genome_scripts
	ship.herd_colors = _genome_colors
	return ship

func _spawn_evader(slot: int):
	var sender: int = 1 - slot
	var ship = _spawn_ship()
	ship.team = 1
	ship.max_speed = EVADER_SPEED
	_world.add_child(ship)
	ship.global_position = _evader_spawn_point(slot)
	if _genome_scripts[sender].is_empty():
		ship.setup_evader(PLANET_CENTERS[slot], PLANET_RADIUS)
	else:
		ship.setup_program_evader(PLANET_CENTERS[slot], PLANET_RADIUS, _genome_scripts[sender], EVADER_HOMING)
	ship.ship_color = C_RED.lerp(PLAYER_COLORS[sender], EVADER_TINT)
	ship.set_meta("slot", slot)
	_evader_ships.append(ship)

func _update_extras(delta: float):
	for slot in _player_count():
		_gate_lock[slot] = maxf(0.0, _gate_lock[slot] - delta)
		_check_pilot_gate(slot)
	_send_ships_through_gates()
	_tick_crossings(delta)

# Seeing an evader is not enough here: a blue ship has to touch it, and the
# capture takes both ships, the same trade the FARP levels make.
func _resolve_lasers():
	for evader in _evader_ships:
		if not is_instance_valid(evader) or evader.is_spent():
			continue
		var catcher = _defender_touching(evader)
		if catcher == null:
			continue
		_explode_at(evader.global_position, 70.0)
		_explode_at(catcher.global_position, 56.0)
		evader.explode()
		catcher.explode()

func _defender_touching(evader):
	for ship in _all_ships():
		if not ship.can_shoot():
			continue
		if ship.global_position.distance_to(evader.global_position) <= ship.hull_radius + evader.hull_radius:
			return ship
	return null

func _all_ships() -> Array:
	var out: Array = []
	for ship in super():
		if not ship.has_meta("crossing"):
			out.append(ship)
	return out

func _gate_side(point: Vector2) -> int:
	if point.x <= GATE_BAND:
		return 0
	if point.x >= ARENA.x - GATE_BAND:
		return 1
	return -1

func _far_point(side: int, along: float) -> Vector2:
	var x: float = ARENA.x - ARRIVAL_INSET if side == 0 else ARRIVAL_INSET
	return Vector2(x, clampf(along, ARRIVAL_INSET, ARENA.y - ARRIVAL_INSET))

func _inward_heading(side: int) -> float:
	return PI if side == 0 else 0.0

func _check_pilot_gate(slot: int):
	var ship = _pilot_ships[slot]
	if not is_instance_valid(ship) or _gate_lock[slot] > 0.0:
		return
	var side: int = _gate_side(ship.global_position)
	if side < 0:
		return
	ship.global_position = _far_point(side, ship.global_position.y)
	ship.rotation = _inward_heading(side)
	_gate_lock[slot] = GATE_COOLDOWN
	_cameras[slot].position = _camera_target(slot)

func _send_ships_through_gates():
	for ship in _all_ships():
		if ship.role == SHIP_CLASS.Role.PILOT or ship.role == SHIP_CLASS.Role.EVADER:
			continue
		var side: int = _gate_side(ship.global_position)
		if side >= 0:
			_start_crossing(ship, _far_point(side, ship.global_position.y), _inward_heading(side))

# A crossing ship is parked out of sight and out of every sensor until it
# comes out on the far side.
func _start_crossing(ship, target: Vector2, heading: float):
	ship.set_meta("crossing", true)
	ship.set_physics_process(false)
	ship.visible = false
	ship.global_position = PARKED
	_crossings.append({"ship": ship, "target": target, "heading": heading, "remaining": CROSSING_SECONDS})

func _tick_crossings(delta: float):
	var still: Array = []
	for crossing in _crossings:
		var ship = crossing["ship"]
		if not is_instance_valid(ship):
			continue
		crossing["remaining"] = float(crossing["remaining"]) - delta
		if float(crossing["remaining"]) > 0.0:
			still.append(crossing)
			continue
		ship.global_position = crossing["target"]
		ship.rotation = float(crossing["heading"])
		ship.visible = true
		ship.remove_meta("crossing")
		ship.set_physics_process(true)
	_crossings = still

func _refresh_hud():
	super()
	if _timer_label == null:
		return
	for slot in _player_count():
		var panel: Dictionary = _player_panels[slot]
		panel["apm"].text = "GENOME: %s" % _genome_names[slot]
		panel["apm"].add_theme_color_override("font_color", _genome_colors[slot])
		panel["input"].text = ""

func _refresh_hint():
	if _hint_label != null:
		_hint_label.text = ""

func _submit_match():
	_match_submitted = true
	_upload_label.text = ""

func _fill_result_grid():
	for child in _result_grid.get_children():
		_result_grid.remove_child(child)
		child.queue_free()
	_stat_row("", _player_name(0), _player_name(1), C_DIM, PLAYER_COLORS[0], PLAYER_COLORS[1])
	_stat_row("GENOME", _genome_names[0], _genome_names[1], C_DIM, _genome_colors[0], _genome_colors[1])
	_stat_row("EVADERS THROUGH", str(_evaders_through[0]), str(_evaders_through[1]), C_DIM, C_RED, C_RED)
	_stat_row("DEFENDERS LEFT", str(_defenders_for(0)), str(_defenders_for(1)), C_DIM, C_ACCENT, C_ACCENT)
	_stat_row("SHIPS HERDED", str(_herded_total[0]), str(_herded_total[1]), C_DIM, C_TEXT, C_TEXT)
