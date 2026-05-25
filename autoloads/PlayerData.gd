extends Node

const SAVE_PATH := "user://player.cfg"
const MAX_MOONS := 5
const MOON_LEVEL_STEP := 2

signal username_changed(new_name: String)
signal xp_changed(current: int, needed: int)
signal level_changed(new_level: int)
signal coins_changed(amount: int)
signal moons_changed()

var username: String = ""
var level: int = 1
var xp: int = 0
var coins: int = 0
var planet_seed: int = 0
var planet_type: String = "terran"
var moon_seeds: Array = []

var _rng := RandomNumberGenerator.new()

func _ready():
	_rng.randomize()
	_load()
	_ensure_planet()
	_sync_moons()

func has_profile() -> bool:
	return username.strip_edges() != ""

func xp_for_level(lvl: int) -> int:
	return 100 + (lvl - 1) * 75

func xp_needed() -> int:
	return xp_for_level(level)

func moons_for_level(lvl: int) -> int:
	return clampi(lvl / MOON_LEVEL_STEP, 0, MAX_MOONS)

func set_username(value: String):
	username = value.strip_edges()
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

func add_coins(amount: int):
	coins += amount
	_save()
	coins_changed.emit(coins)

func _ensure_planet():
	if planet_seed == 0:
		planet_seed = _new_seed()
		planet_type = "terran"
		_save()

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
	cfg.set_value("player", "level", level)
	cfg.set_value("player", "xp", xp)
	cfg.set_value("player", "coins", coins)
	cfg.set_value("planet", "seed", planet_seed)
	cfg.set_value("planet", "type", planet_type)
	cfg.set_value("moons", "seeds", moon_seeds)
	cfg.save(SAVE_PATH)

func _load():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	username = cfg.get_value("player", "username", "")
	level = cfg.get_value("player", "level", 1)
	xp = cfg.get_value("player", "xp", 0)
	coins = cfg.get_value("player", "coins", 0)
	planet_seed = cfg.get_value("planet", "seed", 0)
	planet_type = cfg.get_value("planet", "type", "terran")
	moon_seeds = cfg.get_value("moons", "seeds", [])
