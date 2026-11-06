extends RefCounted

const SIM := preload("res://autoloads/SimulationManager.gd")

enum Role { COLLECTOR, DEFENDER, EVADER, SCOUT }
enum Mode { REGULAR, FOG }
enum Phase { SETUP, LIVE, OVER }

const ROLE_NAMES := {
	Role.COLLECTOR: "Collector",
	Role.DEFENDER: "Defender",
	Role.EVADER: "Evader",
	Role.SCOUT: "Scout",
}
const PROGRAMMABLE_ROLES := [Role.COLLECTOR, Role.DEFENDER, Role.EVADER]

const SETUP_SECONDS := 30.0
const MATCH_SECONDS := 600.0
const SNAPSHOT_INTERVAL := 0.05

const STARTING_DUST := 250
const PLANET_MAX_HP := 150.0
const EVADER_PLANET_DAMAGE := 15.0

const PLANET_PIXELS := 80.0
const PLANET_DISPLAY := 200.0
const PLANET_RADIUS := PLANET_DISPLAY * 0.5
const RING_INNER := PLANET_RADIUS + 50.0
const RING_OUTER := 330.0
const HOME_LEASH := 420.0
const PAN_LIMIT := 900.0
const HOME_VISION := 520.0
const SCOUT_VISION := 460.0
const MIN_SHIP_VISION := 140.0

const SHIP_LIMITS := {
	Role.COLLECTOR: 8,
	Role.DEFENDER: 16,
	Role.EVADER: 12,
	Role.SCOUT: 1,
}

const SHOP_ITEMS := [
	{"id": "defender", "role": Role.DEFENDER, "title": "Defender", "cost": 30, "text": "Deploy in your ring. Trades lives with an evader it touches."},
	{"id": "collector", "role": Role.COLLECTOR, "title": "Collector", "cost": 50, "text": "Searches for astrodust and brings it home."},
	{"id": "evader", "role": Role.EVADER, "title": "Evader", "cost": 40, "text": "Explodes on the enemy planet or on any enemy ship it hits."},
	{"id": "scout", "role": Role.SCOUT, "title": "Scout", "cost": 60, "text": "Fly it yourself with WASD or a gamepad to explore."},
]

const UPGRADES := [
	{"id": "cargo", "title": "Cargo Hold", "text": "Collectors carry more astrodust per trip.", "base_cost": 60, "max_level": 4},
	{"id": "drill", "title": "Mining Drill", "text": "Collectors mine astrodust faster.", "base_cost": 50, "max_level": 4},
	{"id": "engine", "title": "Collector Engine", "text": "Raises the top speed of collectors.", "base_cost": 50, "max_level": 4},
]

const CARGO_BASE := 30.0
const CARGO_PER_LEVEL := 15.0
const DRILL_BASE := 6.0
const DRILL_PER_LEVEL := 3.0
const COLLECTOR_SPEED_BASE := 110.0
const COLLECTOR_SPEED_PER_LEVEL := 20.0

const SPEED_CAPS := {
	Role.DEFENDER: 170.0,
	Role.EVADER: 160.0,
	Role.SCOUT: 230.0,
}
const VIEW_CAP := 300.0
const SCOUT_TURN_RATE := 3.6

const SITE_MAX_DUST := 300.0
const SITE_REGEN := 2.0

const PLAYER_COLORS := [Color(0.451, 0.616, 1.0, 1.0), Color(1.0, 0.42, 0.32, 1.0)]
const DUST_COLOR := Color(0.78, 0.55, 1.0, 1.0)

const DEFAULT_PROGRAMS := {
	Role.COLLECTOR: [
		{"type": "when_start", "params": {}, "children": [
			{"type": "set_speed", "params": {"value": 3.0}},
			{"type": "set_view", "params": {"value": 5.0}},
			{"type": "set_fov", "params": {"value": 100.0}},
		]},
		{"type": "when_always", "params": {}, "children": [
			{"type": "if_sees_dust", "params": {}, "children": [
				{"type": "do_face_dust", "params": {}},
				{"type": "do_forward", "params": {}},
			]},
			{"type": "elif_near_wall", "params": {}, "children": [
				{"type": "do_face_home", "params": {}},
				{"type": "do_forward", "params": {}},
			]},
			{"type": "else", "params": {}, "children": [
				{"type": "do_random_walk", "params": {}},
			]},
		]},
	],
	Role.DEFENDER: [
		{"type": "when_start", "params": {}, "children": [
			{"type": "set_speed", "params": {"value": 3.4}},
			{"type": "set_view", "params": {"value": 4.5}},
			{"type": "set_fov", "params": {"value": 70.0}},
		]},
		{"type": "when_always", "params": {}, "children": [
			{"type": "if_see", "params": {"target": "enemy"}, "children": [
				{"type": "do_face", "params": {}},
				{"type": "do_forward", "params": {}},
			]},
			{"type": "elif_far_from_home", "params": {}, "children": [
				{"type": "do_face_home", "params": {}},
				{"type": "do_forward", "params": {}},
			]},
			{"type": "else", "params": {}, "children": [
				{"type": "do_forward", "params": {}},
				{"type": "do_turn_left", "params": {"value": 45.0}},
			]},
		]},
	],
	Role.EVADER: [
		{"type": "when_start", "params": {}, "children": [
			{"type": "set_speed", "params": {"value": 4.0}},
			{"type": "set_view", "params": {"value": 4.0}},
			{"type": "set_fov", "params": {"value": 60.0}},
		]},
		{"type": "when_always", "params": {}, "children": [
			{"type": "do_face_enemy_planet", "params": {}},
			{"type": "do_forward", "params": {}},
		]},
	],
}

static func default_programs() -> Dictionary:
	var programs: Dictionary = {}
	for role in PROGRAMMABLE_ROLES:
		programs[role] = SIM.normalize_to_scripts(DEFAULT_PROGRAMS[role].duplicate(true))
	return programs

static func shop_item(item_id: String) -> Dictionary:
	for item in SHOP_ITEMS:
		if item["id"] == item_id:
			return item
	return {}

static func upgrade(upgrade_id: String) -> Dictionary:
	for entry in UPGRADES:
		if entry["id"] == upgrade_id:
			return entry
	return {}

static func upgrade_cost(upgrade_id: String, current_level: int) -> int:
	var entry: Dictionary = upgrade(upgrade_id)
	if entry.is_empty() or current_level >= int(entry["max_level"]):
		return -1
	return int(entry["base_cost"]) * (current_level + 1)

static func cargo_capacity(level: int) -> float:
	return CARGO_BASE + CARGO_PER_LEVEL * level

static func mining_rate(level: int) -> float:
	return DRILL_BASE + DRILL_PER_LEVEL * level

static func collector_speed_cap(level: int) -> float:
	return COLLECTOR_SPEED_BASE + COLLECTOR_SPEED_PER_LEVEL * level

static func role_from_name(role_name: String) -> int:
	for role in ROLE_NAMES:
		if ROLE_NAMES[role].to_lower() == role_name.to_lower():
			return role
	return -1

static func mode_name(mode: int) -> String:
	return "Fog of War" if mode == Mode.FOG else "Regular"
