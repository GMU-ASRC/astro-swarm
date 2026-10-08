extends Node

const SIM := preload("res://autoloads/SimulationManager.gd")
const ACHIEVEMENTS := preload("res://achievements/Achievements.gd")

const SAVE_PATH := "user://player.cfg"
const MAX_MOONS := 5
const WORKSPACE_MOON_SEED := 424242
const DEFAULT_PLANET_REFERENCE := "your planet"
const PLANET_NAME_MAX_LENGTH := 24
const MOON_LEVEL_STEP := 2

const DEFAULT_SHIP_BLOCKS := [
	{"type": "when_sees_enemy", "params": {}},
	{"type": "do_face", "params": {}},
	{"type": "when_always", "params": {}},
	{"type": "do_forward", "params": {}},
]

signal username_changed(new_name: String)
signal planet_name_changed(new_name: String)
signal achievement_unlocked(achievement_id: String)
signal xp_changed(current: int, needed: int)
signal level_changed(new_level: int)
signal coins_changed(amount: int)
signal moons_changed()
signal ship_program_changed()

var username: String = ""
var planet_name: String = ""
var player_id: String = ""
var level: int = 1
var xp: int = 0
var coins: int = 0
var planet_seed: int = 0
var planet_type: String = "terran"
var moon_seeds: Array = []
var ship_blocks: Array = []
var ship_algorithms: Dictionary = {}
var active_algorithm: String = ""
var game_mode: String = "levels"
var farp_placements: Array = []
var farp_layouts: Dictionary = {}
var completed_levels: Array = []
var achievements: Array = []

var _rng := RandomNumberGenerator.new()

func _ready():
	_rng.randomize()
	_load()
	_ensure_planet()
	_sync_moons()
	_ensure_ship_program()
	_ensure_player_id()
	call_deferred("_catch_up_achievements")

func _catch_up_achievements():
	ACHIEVEMENTS.check_commander_level(level)
	if is_level_completed(ACHIEVEMENTS.FIRST_LEVEL_ID):
		ACHIEVEMENTS.check_level_completed(ACHIEVEMENTS.FIRST_LEVEL_ID)
	if not ship_algorithms.is_empty():
		unlock_achievement(ACHIEVEMENTS.HIVEMIND)

func has_profile() -> bool:
	return username.strip_edges() != ""

func xp_for_level(lvl: int) -> int:
	return 100 + (lvl - 1) * 75

func xp_needed() -> int:
	return xp_for_level(level)

func moons_for_level(lvl: int) -> int:
	return clampi(floori(float(lvl) / float(MOON_LEVEL_STEP)), 0, MAX_MOONS)

func set_planet_name(value: String):
	planet_name = value.strip_edges()
	_save()
	planet_name_changed.emit(planet_name)

func planet_display_name() -> String:
	return planet_name if planet_name != "" else DEFAULT_PLANET_REFERENCE

func set_username(value: String):
	username = value.strip_edges()
	if player_id == "":
		player_id = _generate_uuid()
	_save()
	username_changed.emit(username)

func add_xp(amount: int):
	if amount <= 0:
		return
	xp += amount
	var leveled: bool = false
	while xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		leveled = true
	if leveled:
		_sync_moons()
	_save()
	xp_changed.emit(xp, xp_for_level(level))
	if leveled:
		level_changed.emit(level)
		moons_changed.emit()
		ACHIEVEMENTS.check_commander_level(level)

func add_coins(amount: int):
	if amount <= 0:
		return
	coins += amount
	_save()
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or amount > coins:
		return false
	coins -= amount
	_save()
	coins_changed.emit(coins)
	return true

func _ensure_planet():
	if planet_seed == 0:
		planet_seed = _new_seed()
		planet_type = "terran"
		_save()

func _ensure_ship_program():
	if ship_blocks.is_empty():
		ship_blocks = SIM.normalize_to_scripts(DEFAULT_SHIP_BLOCKS)
		_save()

func _ensure_player_id():
	if has_profile() and player_id == "":
		player_id = _generate_uuid()
		_save()

func _generate_uuid() -> String:
	var bytes: Array = []
	for i in 16:
		bytes.append(_rng.randi() % 256)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = ""
	for i in 16:
		hex += "%02x" % bytes[i]
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func get_ship_algorithm() -> Array:
	return SIM.normalize_to_scripts(ship_blocks)

func set_ship_blocks(blocks: Array):
	ship_blocks = SIM.normalize_to_scripts(blocks)
	_save()
	ship_program_changed.emit()

func save_algorithm(algo_name: String, scripts: Array):
	var key: String = algo_name.strip_edges()
	if key == "":
		return
	ship_algorithms[key] = SIM.normalize_to_scripts(scripts)
	active_algorithm = key
	_save()
	unlock_achievement(ACHIEVEMENTS.HIVEMIND)

func get_algorithm(algo_name: String) -> Array:
	return SIM.normalize_to_scripts(ship_algorithms.get(algo_name, []))

func delete_algorithm(algo_name: String):
	if ship_algorithms.erase(algo_name):
		if active_algorithm == algo_name:
			active_algorithm = ""
		_save()

func set_active_algorithm(algo_name: String):
	active_algorithm = algo_name if ship_algorithms.has(algo_name) else ""
	_save()

func algorithm_names() -> Array:
	return ship_algorithms.keys()

func set_game_mode(mode: String):
	game_mode = mode
	_save()

func set_farp_placements(placements: Array):
	farp_placements = placements
	_save()

func get_farp_placements() -> Array:
	return farp_placements

func set_level_placements(level_id: String, placements: Array):
	farp_layouts[level_id] = placements
	_save()

func get_level_placements(level_id: String) -> Array:
	return farp_layouts.get(level_id, [])

func complete_level(level_id: String):
	if completed_levels.has(level_id):
		return
	completed_levels.append(level_id)
	_save()

func is_level_completed(level_id: String) -> bool:
	return completed_levels.has(level_id)

func unlock_achievement(achievement_id: String):
	if achievements.has(achievement_id):
		return
	achievements.append(achievement_id)
	_save()
	achievement_unlocked.emit(achievement_id)

func has_achievement(achievement_id: String) -> bool:
	return achievements.has(achievement_id)

func reset_game():
	username = ""
	planet_name = ""
	player_id = ""
	level = 1
	xp = 0
	coins = 0
	planet_seed = 0
	planet_type = "terran"
	moon_seeds = []
	ship_blocks = []
	ship_algorithms = {}
	active_algorithm = ""
	game_mode = "levels"
	farp_placements = []
	farp_layouts = {}
	completed_levels = []
	achievements = []
	_ensure_planet()
	_sync_moons()
	_ensure_ship_program()
	_save()
	username_changed.emit(username)
	planet_name_changed.emit(planet_name)
	level_changed.emit(level)
	xp_changed.emit(xp, xp_for_level(level))
	coins_changed.emit(coins)
	moons_changed.emit()
	ship_program_changed.emit()

func _sync_moons():
	var target: int = moons_for_level(level)
	var changed: bool = false
	while moon_seeds.size() < target:
		moon_seeds.append(_new_seed())
		changed = true
	if changed:
		_save()

func _new_seed() -> int:
	return _rng.randi_range(1, 999999)

func _save():
	var cfg := ConfigFile.new()
	cfg.set_value("player", "username", username)
	cfg.set_value("planet", "name", planet_name)
	cfg.set_value("player", "player_id", player_id)
	cfg.set_value("player", "level", level)
	cfg.set_value("player", "xp", xp)
	cfg.set_value("player", "coins", coins)
	cfg.set_value("planet", "seed", planet_seed)
	cfg.set_value("planet", "type", planet_type)
	cfg.set_value("moons", "seeds", moon_seeds)
	cfg.set_value("ship", "blocks", ship_blocks)
	cfg.set_value("ship", "algorithms", ship_algorithms)
	cfg.set_value("ship", "active_algorithm", active_algorithm)
	cfg.set_value("match", "game_mode", game_mode)
	cfg.set_value("farp", "placements", farp_placements)
	cfg.set_value("farp", "layouts", farp_layouts)
	cfg.set_value("progress", "completed_levels", completed_levels)
	cfg.set_value("progress", "achievements", achievements)
	cfg.save(SAVE_PATH)

func _load():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	username = cfg.get_value("player", "username", "")
	planet_name = cfg.get_value("planet", "name", "")
	player_id = cfg.get_value("player", "player_id", "")
	level = cfg.get_value("player", "level", 1)
	xp = cfg.get_value("player", "xp", 0)
	coins = cfg.get_value("player", "coins", 0)
	planet_seed = cfg.get_value("planet", "seed", 0)
	planet_type = cfg.get_value("planet", "type", "terran")
	moon_seeds = cfg.get_value("moons", "seeds", [])
	ship_blocks = SIM.normalize_to_scripts(cfg.get_value("ship", "blocks", []))
	ship_algorithms = cfg.get_value("ship", "algorithms", {})
	active_algorithm = cfg.get_value("ship", "active_algorithm", "")
	game_mode = cfg.get_value("match", "game_mode", "levels")
	farp_placements = cfg.get_value("farp", "placements", [])
	farp_layouts = cfg.get_value("farp", "layouts", {})
	completed_levels = cfg.get_value("progress", "completed_levels", [])
	achievements = cfg.get_value("progress", "achievements", [])
