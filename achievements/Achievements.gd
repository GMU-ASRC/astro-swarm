extends RefCounted

const PERFECT_ORBIT := "perfect_orbit"
const LIFTOFF := "liftoff"
const PLANET_GUARD := "planet_guard"
const HIVEMIND := "hivemind"
const VETERAN := "veteran"
const SWARM_MASTER := "swarm_master"

const CIRCLINESS_TARGET := 0.9
const VETERAN_LEVEL := 5
const FIRST_LEVEL_ID := "farp1"

const ALL := [
	{"id": LIFTOFF,       "title": "LIFTOFF",       "description": "Finish level 1.",                                   "icon": "res://assets/badges/liftoff.svg"},
	{"id": PLANET_GUARD,  "title": "PLANET GUARD",  "description": "Finish level 1 without a single evader landing.",   "icon": "res://assets/badges/planet-guard.svg"},
	{"id": PERFECT_ORBIT, "title": "PERFECT ORBIT", "description": "Average circliness over 0.9 in level 1.",           "icon": "res://assets/badges/perfect-orbit.svg"},
	{"id": HIVEMIND,      "title": "HIVEMIND",      "description": "Save your first algorithm.",                        "icon": "res://assets/badges/hivemind.svg"},
	{"id": VETERAN,       "title": "VETERAN",       "description": "Reach the rank of Commander.",                        "icon": "res://assets/badges/veteran.svg"},
	{"id": SWARM_MASTER,  "title": "SWARM MASTER",  "description": "Finish every level.",                               "icon": "res://assets/badges/swarm-master.svg"},
]

static func find(achievement_id: String) -> Dictionary:
	for achievement in ALL:
		if achievement["id"] == achievement_id:
			return achievement
	return {}

static func check_level_completed(level_id: String):
	if level_id == FIRST_LEVEL_ID:
		PlayerData.unlock_achievement(LIFTOFF)
	for level in LevelInfo.LEVELS:
		if not PlayerData.is_level_completed(level["id"]):
			return
	PlayerData.unlock_achievement(SWARM_MASTER)

static func check_level_one_result(held: bool, average_circliness: float):
	if held:
		PlayerData.unlock_achievement(PLANET_GUARD)
	if average_circliness > CIRCLINESS_TARGET:
		PlayerData.unlock_achievement(PERFECT_ORBIT)

static func check_commander_level(level: int):
	if level >= VETERAN_LEVEL:
		PlayerData.unlock_achievement(VETERAN)
