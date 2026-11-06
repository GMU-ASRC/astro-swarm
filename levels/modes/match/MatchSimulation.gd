extends Node

signal ship_spawned(ship)
signal ship_removed(ship)
signal explosion(position: Vector2, size: float)
signal notice(slot: int, text: String)
signal match_over(result: Dictionary)

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const SHIP_FACTORY := preload("res://levels/modes/match/MatchShipFactory.gd")

const SPAWN_GAP := 14.0
const PLANET_HIT_MARGIN := 10.0

var players: Array = []
var homes: Array = []
var sites: Array = []
var arena: Vector2 = Vector2.ZERO
var world: Node2D
var phase: int = MATCH_CONFIG.Phase.SETUP
var setup_left: float = MATCH_CONFIG.SETUP_SECONDS
var match_left: float = MATCH_CONFIG.MATCH_SECONDS
var ships: Dictionary = {}

var _next_ship_id: int = 1
var _pilot_inputs: Array = [Vector2.ZERO, Vector2.ZERO]
var _rng := RandomNumberGenerator.new()

func setup(match_players: Array, home_bases: Array, mining_sites: Array, arena_size: Vector2, world_node: Node2D):
	players = match_players
	homes = home_bases
	sites = mining_sites
	arena = arena_size
	world = world_node
	_rng.randomize()

func handle_command(slot: int, kind: String, payload: Dictionary):
	if phase == MATCH_CONFIG.Phase.OVER:
		return
	match kind:
		"buy":
			_buy(slot, str(payload.get("item", "")))
		"upgrade":
			_upgrade(slot, str(payload.get("id", "")))
		"deploy":
			_deploy(slot, Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))), float(payload.get("rot", 0.0)))
		"program":
			_set_program(slot, int(payload.get("role", -1)), payload.get("scripts", []))
		"ready":
			if phase == MATCH_CONFIG.Phase.SETUP:
				players[slot].is_ready = not players[slot].is_ready

func set_pilot(slot: int, thrust: float, turn: float):
	_pilot_inputs[slot] = Vector2(clampf(thrust, -1.0, 1.0), clampf(turn, -1.0, 1.0))

func _buy(slot: int, item_id: String):
	var item: Dictionary = MATCH_CONFIG.shop_item(item_id)
	if item.is_empty():
		return
	var player = players[slot]
	var role: int = item["role"]
	var owned: int = player.ship_count(role) + (player.hangar_defenders if role == MATCH_CONFIG.Role.DEFENDER else 0)
	if owned >= int(MATCH_CONFIG.SHIP_LIMITS[role]):
		notice.emit(slot, "%s LIMIT REACHED" % MATCH_CONFIG.ROLE_NAMES[role].to_upper())
		return
	if not player.spend(int(item["cost"])):
		notice.emit(slot, "NOT ENOUGH ASTRODUST")
		return
	player.ships_built += 1
	if role == MATCH_CONFIG.Role.DEFENDER:
		player.hangar_defenders += 1
		notice.emit(slot, "DEFENDER READY, DRAG IN YOUR RING TO DEPLOY")
		return
	var home_center: Vector2 = homes[slot].position
	var facing: float = home_center.angle_to_point(homes[1 - slot].position)
	if role == MATCH_CONFIG.Role.COLLECTOR:
		facing = _rng.randf() * TAU
	elif role == MATCH_CONFIG.Role.EVADER:
		facing += _rng.randf_range(-0.6, 0.6)
	var spawn_point: Vector2 = home_center + Vector2(MATCH_CONFIG.PLANET_RADIUS + SPAWN_GAP, 0.0).rotated(facing)
	_spawn(slot, role, spawn_point, facing)

func _upgrade(slot: int, upgrade_id: String):
	var player = players[slot]
	var cost: int = MATCH_CONFIG.upgrade_cost(upgrade_id, player.upgrade_level(upgrade_id))
	if cost < 0:
		notice.emit(slot, "UPGRADE MAXED")
		return
	if not player.spend(cost):
		notice.emit(slot, "NOT ENOUGH ASTRODUST")
		return
	player.upgrade_levels[upgrade_id] = player.upgrade_level(upgrade_id) + 1
	for ship in _ships_of(slot, MATCH_CONFIG.Role.COLLECTOR):
		SHIP_FACTORY.configure(ship, player.programs[MATCH_CONFIG.Role.COLLECTOR], player)

func _deploy(slot: int, point: Vector2, facing: float):
	var player = players[slot]
	if player.hangar_defenders <= 0:
		notice.emit(slot, "BUY A DEFENDER IN THE SHOP FIRST")
		return
	if not homes[slot].can_deploy_at(point):
		return
	player.hangar_defenders -= 1
	_spawn(slot, MATCH_CONFIG.Role.DEFENDER, point, facing)

func _set_program(slot: int, role: int, scripts: Array):
	if not MATCH_CONFIG.PROGRAMMABLE_ROLES.has(role):
		return
	var player = players[slot]
	player.programs[role] = scripts
	for ship in _ships_of(slot, role):
		SHIP_FACTORY.configure(ship, scripts, player)

func _spawn(slot: int, role: int, point: Vector2, facing: float):
	var player = players[slot]
	var ship = SHIP_FACTORY.create(role, slot, _next_ship_id, arena, homes, sites)
	_next_ship_id += 1
	ship.global_position = point
	ship.rotation = facing
	world.add_child(ship)
	SHIP_FACTORY.configure(ship, player.programs.get(role, []), player)
	ship.set_physics_process(phase == MATCH_CONFIG.Phase.LIVE)
	if role == MATCH_CONFIG.Role.COLLECTOR:
		ship.cargo_delivered.connect(_on_cargo_delivered)
	ships[ship.ship_id] = ship
	player.ship_counts[role] = player.ship_count(role) + 1
	ship_spawned.emit(ship)

func _remove(ship):
	if not ships.has(ship.ship_id):
		return
	ships.erase(ship.ship_id)
	var player = players[ship.owner_slot]
	player.ship_counts[ship.role] = maxi(0, player.ship_count(ship.role) - 1)
	explosion.emit(ship.global_position, 48.0)
	ship_removed.emit(ship)
	ship.queue_free()

func _on_cargo_delivered(ship, amount: float):
	var player = players[ship.owner_slot]
	var whole: int = int(round(amount))
	player.dust += whole
	player.dust_collected += whole

func _ships_of(slot: int, role: int) -> Array:
	var out: Array = []
	for ship in ships.values():
		if is_instance_valid(ship) and ship.owner_slot == slot and ship.role == role:
			out.append(ship)
	return out

func scout_of(slot: int):
	var scouts: Array = _ships_of(slot, MATCH_CONFIG.Role.SCOUT)
	return scouts[0] if not scouts.is_empty() else null

func _physics_process(delta: float):
	match phase:
		MATCH_CONFIG.Phase.SETUP:
			setup_left -= delta
			if setup_left <= 0.0 or (players[0].is_ready and players[1].is_ready):
				_go_live()
		MATCH_CONFIG.Phase.LIVE:
			match_left -= delta
			_apply_pilots()
			_resolve_contacts()
			_check_finish()

func _go_live():
	phase = MATCH_CONFIG.Phase.LIVE
	setup_left = 0.0
	for ship in ships.values():
		if is_instance_valid(ship):
			ship.set_physics_process(true)

func _apply_pilots():
	for slot in 2:
		var scout = scout_of(slot)
		if scout != null:
			scout.pilot_thrust = _pilot_inputs[slot].x
			scout.pilot_turn = _pilot_inputs[slot].y

func _resolve_contacts():
	var doomed: Dictionary = {}
	var evaders: Array = []
	for ship in ships.values():
		if is_instance_valid(ship) and ship.role == MATCH_CONFIG.Role.EVADER:
			evaders.append(ship)
	for evader in evaders:
		if doomed.has(evader.ship_id):
			continue
		var enemy_home = homes[1 - evader.owner_slot]
		if evader.global_position.distance_to(enemy_home.position) <= enemy_home.radius + PLANET_HIT_MARGIN:
			_damage_planet(1 - evader.owner_slot, evader.owner_slot)
			doomed[evader.ship_id] = evader
			continue
		for other in ships.values():
			if not is_instance_valid(other) or other.owner_slot == evader.owner_slot or doomed.has(other.ship_id):
				continue
			if evader.global_position.distance_to(other.global_position) <= evader.hull_radius + other.hull_radius:
				doomed[evader.ship_id] = evader
				doomed[other.ship_id] = other
				players[evader.owner_slot].ships_destroyed += 1
				players[other.owner_slot].ships_destroyed += 1
				break
	for ship in doomed.values():
		_remove(ship)

func _damage_planet(target_slot: int, attacker_slot: int):
	var target = players[target_slot]
	target.planet_hp = maxf(0.0, target.planet_hp - MATCH_CONFIG.EVADER_PLANET_DAMAGE)
	players[attacker_slot].planet_damage_dealt += MATCH_CONFIG.EVADER_PLANET_DAMAGE
	homes[target_slot].hp = target.planet_hp
	explosion.emit(homes[target_slot].position, 120.0)

func _check_finish():
	var first_down: bool = players[0].planet_hp <= 0.0
	var second_down: bool = players[1].planet_hp <= 0.0
	if not first_down and not second_down and match_left > 0.0:
		return
	var winner: int = -1
	if first_down != second_down:
		winner = 1 if first_down else 0
	elif not first_down and not second_down:
		if players[0].planet_hp > players[1].planet_hp:
			winner = 0
		elif players[1].planet_hp > players[0].planet_hp:
			winner = 1
	finish(winner, "planet" if first_down or second_down else "time")

func finish(winner: int, reason: String):
	if phase == MATCH_CONFIG.Phase.OVER:
		return
	phase = MATCH_CONFIG.Phase.OVER
	for ship in ships.values():
		if is_instance_valid(ship):
			ship.set_physics_process(false)
	var stats: Array = []
	for player in players:
		stats.append(player.to_dict())
	match_over.emit({"winner": winner, "reason": reason, "players": stats})

func snapshot() -> Dictionary:
	var ship_rows: Array = []
	for ship in ships.values():
		if not is_instance_valid(ship):
			continue
		ship_rows.append([ship.ship_id, ship.role, ship.owner_slot, ship.global_position.x, ship.global_position.y, ship.rotation, ship.view_distance, ship.fov_degrees, ship.cargo, ship.cargo_capacity, ship.thruster_level()])
	var site_dust: Array = []
	for site in sites:
		site_dust.append(site.dust)
	return {
		"phase": phase,
		"setup_left": setup_left,
		"match_left": match_left,
		"players": [players[0].to_dict(), players[1].to_dict()],
		"ships": ship_rows,
		"sites": site_dust,
	}
