extends RefCounted
class_name LevelInfo

const PILOT_LEVELS := [5, 6]
const MULTI_EVADER_LEVELS := [3, 4]

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

static func is_multi_evader(level_id: String) -> bool:
	return number(level_id) in MULTI_EVADER_LEVELS

static func display_name(level_id: String) -> String:
	match number(level_id):
		2: return "LEVEL 2 - DEFENSE"
		3: return "LEVEL 3 - WAVES"
		4: return "LEVEL 4 - TRADE"
		5: return "LEVEL 5 - PILOT"
		6: return "LEVEL 6 - SWARM"
	return "LEVEL 1 - DEFENSE"

static func result_text(level_id: String, rate: float) -> String:
	if is_pilot(level_id):
		return "planet reached" if rate >= 100.0 else "no goal"
	return "%s%% capture" % str(rate)
