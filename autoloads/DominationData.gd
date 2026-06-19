extends Node

const SAVE_PATH := "user://domination.cfg"

signal tokens_changed(amount: int)

var tokens: int = 0
var speed_level: int = 0
var health_level: int = 0
var death_spawn: bool = false
var kamikaze: bool = false

func _ready():
	_load()

func add_tokens(amount: int):
	if amount <= 0:
		return
	tokens += amount
	_save()
	tokens_changed.emit(tokens)

func spend_tokens(amount: int) -> bool:
	if amount <= 0 or amount > tokens:
		return false
	tokens -= amount
	_save()
	tokens_changed.emit(tokens)
	return true

func get_upgrade(id: String):
	match id:
		"speed":       return speed_level
		"health":      return health_level
		"death_spawn": return death_spawn
		"kamikaze":    return kamikaze
	return 0

func set_upgrade(id: String, value):
	match id:
		"speed":       speed_level = int(value)
		"health":      health_level = int(value)
		"death_spawn": death_spawn = bool(value)
		"kamikaze":    kamikaze = bool(value)
	_save()

func _save():
	var cfg := ConfigFile.new()
	cfg.set_value("domination", "tokens", tokens)
	cfg.set_value("domination", "speed_level", speed_level)
	cfg.set_value("domination", "health_level", health_level)
	cfg.set_value("domination", "death_spawn", death_spawn)
	cfg.set_value("domination", "kamikaze", kamikaze)
	cfg.save(SAVE_PATH)

func _load():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	tokens       = cfg.get_value("domination", "tokens", 0)
	speed_level  = cfg.get_value("domination", "speed_level", 0)
	health_level = cfg.get_value("domination", "health_level", 0)
	death_spawn  = cfg.get_value("domination", "death_spawn", false)
	kamikaze     = cfg.get_value("domination", "kamikaze", false)
