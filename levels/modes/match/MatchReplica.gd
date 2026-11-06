extends Node

signal ship_spawned(ship)
signal ship_removed(ship)

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")
const SHIP_FACTORY := preload("res://levels/modes/match/MatchShipFactory.gd")

enum Column { ID, ROLE, OWNER, X, Y, ROTATION, VIEW, FOV, CARGO, CAPACITY, THRUST }

var players: Array = []
var homes: Array = []
var sites: Array = []
var arena: Vector2 = Vector2.ZERO
var world: Node2D
var phase: int = MATCH_CONFIG.Phase.SETUP
var setup_left: float = MATCH_CONFIG.SETUP_SECONDS
var match_left: float = MATCH_CONFIG.MATCH_SECONDS
var ships: Dictionary = {}

func setup(match_players: Array, home_bases: Array, mining_sites: Array, arena_size: Vector2, world_node: Node2D):
	players = match_players
	homes = home_bases
	sites = mining_sites
	arena = arena_size
	world = world_node
	for site in sites:
		site.regenerates = false

func apply_snapshot(data: Dictionary):
	phase = int(data.get("phase", phase))
	setup_left = float(data.get("setup_left", setup_left))
	match_left = float(data.get("match_left", match_left))
	var player_rows: Array = data.get("players", [])
	for slot in mini(player_rows.size(), players.size()):
		players[slot].apply_dict(player_rows[slot])
		homes[slot].hp = players[slot].planet_hp
	var site_dust: Array = data.get("sites", [])
	for index in mini(site_dust.size(), sites.size()):
		sites[index].dust = float(site_dust[index])
	_apply_ships(data.get("ships", []))

func _apply_ships(rows: Array):
	var seen: Dictionary = {}
	for row in rows:
		var ship_id: int = int(row[Column.ID])
		seen[ship_id] = true
		var ship = ships.get(ship_id)
		if ship == null or not is_instance_valid(ship):
			ship = _create_ship(row)
		ship.target_position = Vector2(float(row[Column.X]), float(row[Column.Y]))
		ship.target_rotation = float(row[Column.ROTATION])
		ship.cargo = float(row[Column.CARGO])
		ship.cargo_capacity = float(row[Column.CAPACITY])
		ship.remote_thrust = float(row[Column.THRUST])
		var view: float = float(row[Column.VIEW])
		var fov: float = float(row[Column.FOV])
		if not is_equal_approx(view, ship.view_distance) or not is_equal_approx(fov, ship.fov_degrees):
			ship.view_distance = view
			ship.fov_degrees = fov
			ship.refresh_cone()
	for ship_id in ships.keys():
		if not seen.has(ship_id):
			var ship = ships[ship_id]
			ships.erase(ship_id)
			if is_instance_valid(ship):
				ship_removed.emit(ship)
				ship.queue_free()

func _create_ship(row: Array) -> Node2D:
	var role: int = int(row[Column.ROLE])
	var owner_slot: int = int(row[Column.OWNER])
	var ship = SHIP_FACTORY.create(role, owner_slot, int(row[Column.ID]), arena, homes, sites)
	ship.is_remote = true
	ship.global_position = Vector2(float(row[Column.X]), float(row[Column.Y]))
	ship.rotation = float(row[Column.ROTATION])
	ship.show_cone = role != MATCH_CONFIG.Role.SCOUT
	world.add_child(ship)
	ship.set_physics_process(false)
	ships[ship.ship_id] = ship
	ship_spawned.emit(ship)
	return ship

func _process(delta: float):
	for ship in ships.values():
		if is_instance_valid(ship):
			ship.follow_remote(delta)

func scout_of(slot: int):
	for ship in ships.values():
		if is_instance_valid(ship) and ship.owner_slot == slot and ship.role == MATCH_CONFIG.Role.SCOUT:
			return ship
	return null
