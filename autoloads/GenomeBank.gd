extends Node

const SIM := preload("res://autoloads/SimulationManager.gd")
const ACHIEVEMENTS := preload("res://achievements/Achievements.gd")
const GENOME_UPGRADES := preload("res://progression/GenomeUpgrades.gd")

const SAVE_PATH := "user://genomes.cfg"
const MAX_GENOMES := 12
const NAME_MAX_LENGTH := 24
const DEFAULT_NAME := "Genome"
const CURRENT_PROGRAM_NAME := "Current Program"

const COLORS := [
	Color(0.451, 0.616, 1.0, 1.0),
	Color(0.31, 0.82, 0.55, 1.0),
	Color(1.0, 0.70, 0.28, 1.0),
	Color(0.79, 0.48, 1.0, 1.0),
	Color(0.31, 0.85, 0.88, 1.0),
	Color(1.0, 0.48, 0.66, 1.0),
	Color(0.83, 0.88, 0.34, 1.0),
	Color(1.0, 0.54, 0.40, 1.0),
	Color(0.56, 0.64, 0.68, 1.0),
]

signal genomes_changed()

var genomes: Array = []
var active_id: String = ""
var loadout: Array = []

var _rng := RandomNumberGenerator.new()
var _activating: bool = false

func _ready():
	_rng.randomize()
	if not _load():
		_migrate_from_player_data()
	_ensure_active()
	_ensure_loadout()
	PlayerData.ship_program_changed.connect(_on_ship_program_changed)

func is_unlocked() -> bool:
	return PlayerData.is_genome_unlocked()

func genome_count() -> int:
	return genomes.size()

func is_full() -> bool:
	return genomes.size() >= MAX_GENOMES

func get_genome(genome_id: String) -> Dictionary:
	for genome in genomes:
		if genome["id"] == genome_id:
			return genome
	return {}

func active_genome() -> Dictionary:
	return get_genome(active_id)

func genome_color(genome: Dictionary) -> Color:
	return COLORS[clampi(int(genome.get("color", 0)), 0, COLORS.size() - 1)]

func active_color() -> Color:
	return genome_color(active_genome())

func set_color(genome_id: String, color_index: int):
	var genome: Dictionary = get_genome(genome_id)
	if genome.is_empty() or color_index < 0 or color_index >= COLORS.size():
		return
	genome["color"] = color_index
	_touch(genome)

func loadout_limit() -> int:
	return GENOME_UPGRADES.switches_per_level()

func in_loadout(genome_id: String) -> bool:
	return loadout.has(genome_id)

func loadout_full() -> bool:
	return loadout.size() >= loadout_limit()

func loadout_genomes() -> Array:
	var picked: Array = []
	for genome_id in loadout.slice(0, loadout_limit()):
		var genome: Dictionary = get_genome(genome_id)
		if not genome.is_empty():
			picked.append(genome)
	return picked

func toggle_loadout(genome_id: String):
	if get_genome(genome_id).is_empty():
		return
	if in_loadout(genome_id):
		if loadout.size() <= 1:
			return
		loadout.erase(genome_id)
	elif not loadout_full():
		loadout.append(genome_id)
	else:
		return
	_save()
	genomes_changed.emit()

func activate_loadout_start():
	var picked: Array = loadout_genomes()
	if picked.is_empty():
		return
	for genome in picked:
		if genome["id"] == active_id:
			return
	activate(picked[0]["id"])

func block_count(genome: Dictionary) -> int:
	var total: int = 0
	for script in genome.get("scripts", []):
		total += _count_blocks(script.get("blocks", []))
	return total

func create(genome_name: String = "", scripts: Array = []) -> String:
	if is_full():
		return ""
	var program: Array = scripts if not scripts.is_empty() else SIM.normalize_to_scripts(PlayerData.DEFAULT_SHIP_BLOCKS)
	var genome := _new_genome(unique_name(genome_name if genome_name.strip_edges() != "" else DEFAULT_NAME), program)
	genomes.append(genome)
	_save()
	PlayerData.unlock_achievement(ACHIEVEMENTS.HIVEMIND)
	ACHIEVEMENTS.check_genome_count(genomes.size(), is_full())
	genomes_changed.emit()
	return genome["id"]

func duplicate_genome(genome_id: String) -> String:
	var source: Dictionary = get_genome(genome_id)
	if source.is_empty():
		return ""
	return create(source["name"] + " Copy", source["scripts"].duplicate(true))

func rename(genome_id: String, new_name: String) -> bool:
	var genome: Dictionary = get_genome(genome_id)
	var cleaned: String = new_name.strip_edges().left(NAME_MAX_LENGTH)
	if genome.is_empty() or cleaned == "":
		return false
	if cleaned == genome["name"]:
		return true
	if _name_taken(cleaned):
		return false
	genome["name"] = cleaned
	_touch(genome)
	return true

func remove(genome_id: String) -> bool:
	if genomes.size() <= 1:
		return false
	var genome: Dictionary = get_genome(genome_id)
	if genome.is_empty():
		return false
	genomes.erase(genome)
	loadout.erase(genome_id)
	if active_id == genome_id:
		activate(genomes[0]["id"])
	_ensure_loadout()
	_save()
	genomes_changed.emit()
	return true

func activate(genome_id: String):
	var genome: Dictionary = get_genome(genome_id)
	if genome.is_empty():
		return
	active_id = genome_id
	_activating = true
	PlayerData.set_ship_blocks(genome["scripts"])
	_activating = false
	genome["scripts"] = PlayerData.get_ship_algorithm()
	_save()
	genomes_changed.emit()

func unique_name(base_name: String) -> String:
	var root: String = base_name.strip_edges().left(NAME_MAX_LENGTH)
	if not _name_taken(root):
		return root
	var suffix: int = 2
	while _name_taken("%s %d" % [root.left(NAME_MAX_LENGTH - 3), suffix]):
		suffix += 1
	return "%s %d" % [root.left(NAME_MAX_LENGTH - 3), suffix]

func reset():
	genomes = []
	active_id = ""
	loadout = []
	_ensure_active()
	_ensure_loadout()
	genomes_changed.emit()

func _on_ship_program_changed():
	if _activating:
		return
	var genome: Dictionary = active_genome()
	if genome.is_empty():
		return
	genome["scripts"] = PlayerData.get_ship_algorithm()
	_touch(genome)

func _ensure_active():
	if genomes.is_empty():
		var genome := _new_genome(DEFAULT_NAME, PlayerData.get_ship_algorithm())
		genomes.append(genome)
		active_id = genome["id"]
		_save()
		return
	if get_genome(active_id).is_empty():
		active_id = genomes[0]["id"]
		_save()
	var genome: Dictionary = active_genome()
	if _program_key(genome["scripts"]) != _program_key(PlayerData.get_ship_algorithm()):
		genome["scripts"] = PlayerData.get_ship_algorithm()
		_save()

func _ensure_loadout():
	var valid: Array = []
	for genome_id in loadout:
		if not get_genome(genome_id).is_empty() and not valid.has(genome_id):
			valid.append(genome_id)
	if valid.is_empty() and not get_genome(active_id).is_empty():
		valid.append(active_id)
	if valid != loadout:
		loadout = valid
		_save()

func _next_color_index() -> int:
	var used: Array = []
	for genome in genomes:
		if genome.has("color"):
			used.append(int(genome["color"]))
	for color_index in COLORS.size():
		if not used.has(color_index):
			return color_index
	return genomes.size() % COLORS.size()

func _migrate_from_player_data():
	var current: Array = PlayerData.get_ship_algorithm()
	var legacy: Dictionary = PlayerData.legacy_algorithms
	var names: Array = legacy.keys()
	names.sort()
	for legacy_name in names:
		if genomes.size() >= MAX_GENOMES:
			break
		var scripts: Array = SIM.normalize_to_scripts(legacy[legacy_name])
		var genome := _new_genome(unique_name(str(legacy_name)), scripts)
		genomes.append(genome)
		if _program_key(scripts) == _program_key(current):
			active_id = genome["id"]
	if active_id == "" and not is_full():
		var genome := _new_genome(unique_name(CURRENT_PROGRAM_NAME if not genomes.is_empty() else DEFAULT_NAME), current)
		genomes.append(genome)
		active_id = genome["id"]
	_save()

func _new_genome(genome_name: String, scripts: Array) -> Dictionary:
	return {
		"id": _new_id(),
		"name": genome_name,
		"color": _next_color_index(),
		"scripts": scripts.duplicate(true),
		"updated": int(Time.get_unix_time_from_system()),
	}

func _touch(genome: Dictionary):
	genome["updated"] = int(Time.get_unix_time_from_system())
	_save()
	genomes_changed.emit()

func _name_taken(genome_name: String) -> bool:
	for genome in genomes:
		if str(genome["name"]).to_lower() == genome_name.to_lower():
			return true
	return false

func _count_blocks(blocks: Array) -> int:
	var total: int = 0
	for block in blocks:
		total += 1 + _count_blocks(block.get("children", []))
	return total

func _program_key(scripts: Array) -> String:
	var shapes: Array = []
	for script in scripts:
		shapes.append(script.get("blocks", []))
	return JSON.stringify(shapes)

func _new_id() -> String:
	return "%08x%08x" % [_rng.randi(), _rng.randi()]

func _save():
	var cfg := ConfigFile.new()
	cfg.set_value("genomes", "list", genomes)
	cfg.set_value("genomes", "active", active_id)
	cfg.set_value("genomes", "loadout", loadout)
	cfg.save(SAVE_PATH)

func _load() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	genomes = cfg.get_value("genomes", "list", [])
	active_id = cfg.get_value("genomes", "active", "")
	loadout = cfg.get_value("genomes", "loadout", [])
	for genome in genomes:
		genome["scripts"] = SIM.normalize_to_scripts(genome.get("scripts", []))
		if not genome.has("color"):
			genome["color"] = _next_color_index()
	return true
