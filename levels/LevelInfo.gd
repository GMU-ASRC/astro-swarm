extends RefCounted
class_name LevelInfo

const PILOT_LEVELS := [6, 7, 8]
const WAVE_LEVELS := [3, 4]
const ATTRITION_LEVELS := [4, 5]
const MULTI_EVADER_LEVELS := [5]
const SUPPLY_LEVELS := [8]

const TRAINING_LEVEL := {"id": "farp0", "name": "TRAINING", "color": Color(0.85, 0.86, 0.96, 1.0), "scene": "res://levels/modes/level0/Level0Scene.tscn"}

const LEVELS := [
	{"id": "farp1", "name": "DEFENSE",   "color": Color(0.451, 0.616, 1.0, 1.0),  "scene": "res://levels/modes/level1/Level1Scene.tscn"},
	{"id": "farp2", "name": "SCATTER",   "color": Color(0.400, 0.780, 0.95, 1.0), "scene": "res://levels/modes/level2/Level2Scene.tscn"},
	{"id": "farp3", "name": "WAVES",     "color": Color(0.400, 0.850, 0.45, 1.0), "scene": "res://levels/modes/level3/Level3Scene.tscn"},
	{"id": "farp4", "name": "ATTRITION", "color": Color(1.000, 0.700, 0.20, 1.0), "scene": "res://levels/modes/level4/Level4Scene.tscn"},
	{"id": "farp5", "name": "SIEGE",     "color": Color(1.000, 0.420, 0.32, 1.0), "scene": "res://levels/modes/level5/Level5Scene.tscn"},
	{"id": "farp6", "name": "PILOT",     "color": Color(0.780, 0.520, 1.0, 1.0),  "scene": "res://levels/modes/level6/Level6Scene.tscn"},
	{"id": "farp7", "name": "SWARM",     "color": Color(1.000, 0.840, 0.20, 1.0), "scene": "res://levels/modes/level7/Level7Scene.tscn"},
	{"id": "farp8", "name": "SUPPLY",    "color": Color(0.350, 0.880, 0.80, 1.0), "scene": "res://levels/modes/level8/Level8PlanetA.tscn"},
]

static func next_level(level_id: String) -> Dictionary:
	for i in LEVELS.size() - 1:
		if LEVELS[i]["id"] == level_id:
			return LEVELS[i + 1]
	return {}

static func number(level_id: String) -> int:
	var digits: String = ""
	for ch in level_id:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 1
	return int(digits)

static func is_pilot(level_id: String) -> bool:
	return number(level_id) in PILOT_LEVELS

static func is_wave(level_id: String) -> bool:
	return number(level_id) in WAVE_LEVELS

static func has_attrition(level_id: String) -> bool:
	return number(level_id) in ATTRITION_LEVELS

static func is_multi_evader(level_id: String) -> bool:
	return number(level_id) in MULTI_EVADER_LEVELS

static func is_supply(level_id: String) -> bool:
	return number(level_id) in SUPPLY_LEVELS

static func display_name(level_id: String) -> String:
	match number(level_id):
		2: return "LEVEL 2 - SCATTER"
		3: return "LEVEL 3 - WAVES"
		4: return "LEVEL 4 - ATTRITION"
		5: return "LEVEL 5 - SIEGE"
		6: return "LEVEL 6 - PILOT"
		7: return "LEVEL 7 - SWARM"
		8: return "LEVEL 8 - SUPPLY"
	return "LEVEL 1 - DEFENSE"

static func result_text(level_id: String, rate: float) -> String:
	if is_supply(level_id):
		return "%s%% held" % str(rate)
	if is_pilot(level_id):
		return "planet reached" if rate >= 100.0 else "no goal"
	return "%s%% capture" % str(rate)
