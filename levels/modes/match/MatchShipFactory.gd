extends RefCounted

const SHIP_SCENE := preload("res://levels/modes/match/MatchShip.tscn")
const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

const SCOUT_VIEW := 200.0
const SCOUT_FOV := 90.0

static func create(role: int, owner_slot: int, ship_id: int, arena: Vector2, homes: Array, sites: Array) -> Node2D:
	var ship = SHIP_SCENE.instantiate()
	ship.role = role
	ship.owner_slot = owner_slot
	ship.ship_id = ship_id
	ship.setup_player([], 1.0)
	ship.team = owner_slot
	ship.ship_color = MATCH_CONFIG.PLAYER_COLORS[owner_slot]
	ship.arena_size = arena
	ship.home_center = homes[owner_slot].position
	ship.enemy_home_center = homes[1 - owner_slot].position
	ship.mining_sites = sites
	ship.collisions_enabled = false
	ship.planet_collisions = false
	ship.can_fire = false
	ship.show_health = false
	ship.set_obstacles(Vector2.ZERO, 0.0, Vector2.ZERO, 0.0)
	return ship

static func configure(ship: Node2D, program: Array, player):
	if ship.role == MATCH_CONFIG.Role.SCOUT:
		ship.max_speed = MATCH_CONFIG.SPEED_CAPS[MATCH_CONFIG.Role.SCOUT]
		ship.turn_rate = MATCH_CONFIG.SCOUT_TURN_RATE
		ship.view_distance = SCOUT_VIEW
		ship.fov_degrees = SCOUT_FOV
		ship.show_cone = false
		ship.refresh_cone()
		return
	ship.reprogram(program)
	var config: Dictionary = SimulationManager.ship_config_from_scripts(program, ship.view_distance, ship.fov_degrees, ship.max_speed, ship.turn_rate, ship.hull_radius)
	ship.view_distance = config.view_distance
	ship.fov_degrees = config.fov_degrees
	ship.max_speed = config.speed
	ship.turn_rate = config.turn_speed
	ship.speed_cap = speed_cap_for(ship.role, player)
	refresh_upgrades(ship, player)
	ship.refresh_cone()

static func refresh_upgrades(ship: Node2D, player):
	ship.speed_cap = speed_cap_for(ship.role, player)
	if ship.role == MATCH_CONFIG.Role.COLLECTOR:
		ship.cargo_capacity = player.cargo_capacity()
		ship.mining_rate = player.mining_rate()
	ship.apply_role_limits()

static func speed_cap_for(role: int, player) -> float:
	if role == MATCH_CONFIG.Role.COLLECTOR:
		return player.collector_speed_cap()
	return float(MATCH_CONFIG.SPEED_CAPS.get(role, 200.0))
