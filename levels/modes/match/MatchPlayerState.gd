extends RefCounted

const MATCH_CONFIG := preload("res://levels/modes/match/MatchConfig.gd")

var slot: int = 0
var display_name: String = ""
var dust: int = MATCH_CONFIG.STARTING_DUST
var planet_hp: float = MATCH_CONFIG.PLANET_MAX_HP
var hangar_defenders: int = 0
var is_ready: bool = false
var upgrade_levels: Dictionary = {"cargo": 0, "drill": 0, "engine": 0}
var programs: Dictionary = {}
var ship_counts: Dictionary = {}
var dust_collected: int = 0
var ships_built: int = 0
var planet_damage_dealt: float = 0.0
var ships_destroyed: int = 0

func _init(player_slot: int = 0, player_name: String = ""):
	slot = player_slot
	display_name = player_name
	programs = MATCH_CONFIG.default_programs()

func color() -> Color:
	return MATCH_CONFIG.PLAYER_COLORS[slot]

func upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))

func cargo_capacity() -> float:
	return MATCH_CONFIG.cargo_capacity(upgrade_level("cargo"))

func mining_rate() -> float:
	return MATCH_CONFIG.mining_rate(upgrade_level("drill"))

func collector_speed_cap() -> float:
	return MATCH_CONFIG.collector_speed_cap(upgrade_level("engine"))

func ship_count(role: int) -> int:
	return int(ship_counts.get(role, 0))

func spend(amount: int) -> bool:
	if amount < 0 or amount > dust:
		return false
	dust -= amount
	return true

func to_dict() -> Dictionary:
	return {
		"slot": slot,
		"name": display_name,
		"dust": dust,
		"hp": planet_hp,
		"hangar": hangar_defenders,
		"ready": is_ready,
		"upgrades": upgrade_levels.duplicate(),
		"counts": ship_counts.duplicate(),
		"collected": dust_collected,
		"built": ships_built,
		"damage": planet_damage_dealt,
		"kills": ships_destroyed,
	}

func apply_dict(data: Dictionary):
	display_name = str(data.get("name", display_name))
	dust = int(data.get("dust", dust))
	planet_hp = float(data.get("hp", planet_hp))
	hangar_defenders = int(data.get("hangar", hangar_defenders))
	is_ready = bool(data.get("ready", is_ready))
	upgrade_levels = data.get("upgrades", upgrade_levels)
	ship_counts = data.get("counts", ship_counts)
	dust_collected = int(data.get("collected", dust_collected))
	ships_built = int(data.get("built", ships_built))
	planet_damage_dealt = float(data.get("damage", planet_damage_dealt))
	ships_destroyed = int(data.get("kills", ships_destroyed))
