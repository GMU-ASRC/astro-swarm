extends "res://levels/modes/supply/SupplyDeployment.gd"

# The assault of a supply level: every planet is attacked at once, the planet on
# screen with live ships in the scene and every other one in the hidden worlds.
const WORLDS := preload("res://levels/modes/supply/SupplyWorlds.gd")

const WORLDS_NAME := "SupplyWorlds"

var _record_accum: float = 0.0
var _evader_slots: Array = []
var _defender_slots: Array = []
var _commit_btn: Button = null
var _travelling: bool = false

func _refresh_board():
	pass

func _flash_planet(_planet_to_flash: int):
	pass

func _on_genome_switched(stage_index: int):
	super(stage_index)
	var worlds = _worlds()
	if worlds != null:
		var program: Array = PlayerData.get_ship_algorithm()
		for ship in worlds.all_defenders():
			ship.reprogram(program)
			_apply_ship_config(ship, program)
			ship.ship_color = GenomeBank.active_color()
	STATE.genome_switch_frames.append(STATE.frames.size())

func _live_defender_count() -> int:
	var worlds = _worlds()
	return super() + (worlds.live_defender_count() if worlds != null else 0)

func _make_ship(program: Array, hp_value: float, color: Color) -> Node2D:
	var ship := super(program, hp_value, color)
	ship.world_id = _planet_index()
	return ship

func _make_scripted_evader(spawn_pos: Vector2) -> Node2D:
	var evader := super(spawn_pos)
	evader.world_id = _planet_index()
	return evader

# Looked up through the main loop rather than get_tree(), so it still answers
# while this scene is outside the tree on its way in or out.
func _scene_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root

func _worlds():
	var worlds = _scene_root().get_node_or_null(WORLDS_NAME)
	if worlds == null or worlds.is_queued_for_deletion():
		return null
	return worlds

func _open_worlds():
	var worlds := WORLDS.new()
	worlds.name = WORLDS_NAME
	worlds.visible = false
	worlds.setup(_planet_count())
	_scene_root().add_child(worlds)

func _close_worlds():
	var worlds = _worlds()
	if worlds != null:
		worlds.name = WORLDS_NAME + "Closing"
		worlds.queue_free()

# The hidden planets hold still while the player is off in the workspace, so
# nothing is fought out unwatched on a clock that is not running.
func _hold_worlds(held: bool):
	var worlds = _worlds()
	if worlds != null:
		worlds.process_mode = Node.PROCESS_MODE_DISABLED if held else Node.PROCESS_MODE_INHERIT

# Every planet's line goes live together: the planet on screen keeps its own
# ships, and every other garrison is stationed in the hidden worlds.
func _commit():
	if STATE.stage != STATE.Stage.ALLOCATE:
		return
	_settle_crossings()
	_hand_scene_over()
	STATE.begin_assault(_rng)
	_open_worlds()
	for planet in _planet_count():
		if planet == _planet_index():
			continue
		for placement in STATE.garrison(planet):
			_station_defender(planet, placement)
	_start_assault()

func _summon_source() -> int:
	var worlds = _worlds()
	if STATE.stage != STATE.Stage.ASSAULT or worlds == null:
		return super()
	var best: int = -1
	for planet in _planet_count():
		if planet == _planet_index() or worlds.defender_count(planet) == 0:
			continue
		if best < 0 or worlds.defender_count(planet) > worlds.defender_count(best):
			best = planet
	return best

func _detach_from(planet: int) -> bool:
	var worlds = _worlds()
	if STATE.stage != STATE.Stage.ASSAULT or worlds == null:
		return super(planet)
	return worlds.release_defender(planet)

func _count_at(planet: int) -> int:
	var worlds = _worlds()
	if STATE.stage != STATE.Stage.ASSAULT or worlds == null or planet == _planet_index():
		return super(planet)
	return worlds.defender_count(planet) + STATE.crossings_to(planet)

func _station_defender(planet: int, placement: Dictionary):
	var ship := _make_ship(PlayerData.ship_blocks, DEFENDER_HP, _defender_color())
	ship.global_position = placement.pos
	ship.rotation = placement.rot
	ship.world_id = planet
	ship.planet_collisions = planet == STATE.PLANET_A
	ship.set_physics_process(true)
	_worlds().adopt_defender(planet, ship)

func _station_away(planet: int, arrival: Dictionary):
	if STATE.stage == STATE.Stage.ASSAULT and _worlds() != null:
		_station_defender(planet, arrival)
		return
	super(planet, arrival)

func _defender_arrived(ship: Node2D):
	super(ship)
	if STATE.stage == STATE.Stage.ASSAULT:
		_fill_slot(_defender_slots, ship)

# A slot whose ship is gone is handed to the next arrival, so the replay layout
# never runs out of room for ships that come and go through the gates.
func _fill_slot(slots: Array, ship: Node2D):
	for index in slots.size():
		if not is_instance_valid(slots[index]):
			slots[index] = ship
			return
	slots.append(ship)

# Runs when the assault opens and again whenever the player lands on another
# planet mid-assault: the planet's live ships come back out of the hidden
# worlds, and its tally picks up where it was left.
func _start_assault():
	if not is_instance_valid(_shuttle):
		_launch_shuttle()
	if _commit_btn != null:
		_commit_btn.visible = false
	_start_active()
	_hold_worlds(false)
	_elapsed = STATE.assault_elapsed
	_reset_counters()
	_take_planet()
	_load_tally()
	_defender_slots = _defender_ships.duplicate()
	_evader_slots = _evaders.duplicate()
	_record_accum = 0.0
	STATE.frames.append(_snapshot())
	_phase_label.text = "ALL PLANETS UNDER ATTACK - PLANET %s" % _planet_letter()
	_update_count()

func _take_planet():
	var worlds = _worlds()
	if worlds == null:
		return
	for ship in worlds.take_defenders(_planet_index()):
		ship.reparent(self)
		_defender_ships.append(ship)
	for evader in worlds.take_evaders(_planet_index()):
		evader.reparent(self)
		_evaders.append(evader)

func _leave_planet():
	_settle_transits()
	_store_tally()
	var worlds = _worlds()
	if worlds == null:
		return
	for ship in _defender_ships:
		if is_instance_valid(ship):
			worlds.adopt_defender(_planet_index(), ship)
	for evader in _evaders:
		if is_instance_valid(evader):
			worlds.adopt_evader(_planet_index(), evader)
	_defender_ships.clear()
	_evaders.clear()

func _load_tally():
	var tally: Dictionary = STATE.results[_planet_index()]
	_destroyed = int(tally.get("destroyed", 0))
	_breached = int(tally.get("breached", 0))
	_defenders_lost = int(tally.get("lost", 0))
	_detect_time = float(tally.get("detect", -1.0))
	_goal_time = float(tally.get("goal", -1.0))

func _store_tally():
	var tally: Dictionary = STATE.results[_planet_index()]
	tally["destroyed"] = _destroyed
	tally["breached"] = _breached
	tally["lost"] = _defenders_lost
	tally["detect"] = _detect_time
	tally["goal"] = _goal_time

func _update_assault(delta: float):
	STATE.assault_elapsed = _elapsed
	_send_attacks()
	_send_defenders_through_gate()
	_land_crossings(STATE.tick_crossings(delta))
	_update_transits(delta)
	_gate_lock = maxf(0.0, _gate_lock - delta)
	_record(delta)
	_update_countdown_color()
	_check_gate()

func _send_attacks():
	while not STATE.attack_queue.is_empty() and _elapsed >= STATE.next_attack:
		_attack(int(STATE.attack_queue.pop_front()))
		STATE.next_attack += STATE.attack_interval()

func _attack(planet: int):
	var spawn: Vector2 = _edge_point(_rng.randf() * TAU)
	if planet == _planet_index():
		_fill_slot(_evader_slots, _spawn_evader_at(spawn))
		return
	var evader := _make_scripted_evader(spawn)
	evader.world_id = planet
	_worlds().adopt_evader(planet, evader)

func _track_events():
	if _travelling or _phase != Phase.ACTIVE or STATE.stage == STATE.Stage.ALLOCATE:
		return
	_resolve_evaders()
	_store_tally()
	var worlds = _worlds()
	var away_evaders: int = 0
	if worlds != null:
		for planet in worlds.resolve(_planet, PLANET_RADIUS + GOAL_MARGIN, _has_attrition()):
			_flash_planet(planet)
		away_evaders = worlds.live_evader_count()
	_refresh_board()
	if STATE.attack_queue.is_empty() and _evaders.is_empty() and away_evaders == 0:
		_finish("cleared")

func _record(delta: float):
	_record_accum += delta
	var step: float = 1.0 / STATE.RECORD_FPS
	while _record_accum >= step:
		_record_accum -= step
		STATE.frames.append(_snapshot())

func _snapshot() -> Array:
	var frame: Array = []
	for index in STATE.defender_total:
		_append_slot(frame, _defender_slots[index] if index < _defender_slots.size() else null)
	for index in STATE.evaders_per_planet():
		_append_slot(frame, _evader_slots[index] if index < _evader_slots.size() else null)
	_append_slot(frame, _shuttle)
	return frame

func _append_slot(frame: Array, ship):
	if ship != null and is_instance_valid(ship):
		frame.append(int(ship.global_position.x))
		frame.append(int(ship.global_position.y))
		frame.append(int(rad_to_deg(ship.rotation)))
		return
	frame.append(-1)
	frame.append(-1)
	frame.append(0)
