extends RefCounted

const PERFECT_ORBIT := "perfect_orbit"
const LIFTOFF := "liftoff"
const PLANET_GUARD := "planet_guard"
const HIVEMIND := "hivemind"
const VETERAN := "veteran"
const SWARM_MASTER := "swarm_master"
const GENE_POOL := "gene_pool"
const FULL_LIBRARY := "full_library"
const ADAPTATION := "adaptation"
const EVOLUTION := "evolution"
const NEW_HORIZONS := "new_horizons"
const SHIPWRIGHT := "shipwright"
const FULLY_LOADED := "fully_loaded"
const LONG_GAME := "long_game"

const SHIP_UPGRADES := preload("res://progression/ShipUpgrades.gd")
const GENOME_UPGRADES := preload("res://progression/GenomeUpgrades.gd")

const CIRCLINESS_TARGET := 0.9
const VETERAN_LEVEL := 5
const FIRST_LEVEL_ID := "farp1"
const GENE_POOL_SIZE := 5

const ALL := [
	{"id": LIFTOFF,       "title": "LIFTOFF",       "description": "Finish level 1.",                                   "icon": "res://assets/badges/liftoff.svg"},
	{"id": PLANET_GUARD,  "title": "PLANET GUARD",  "description": "Finish level 1 without a single evader landing.",   "icon": "res://assets/badges/planet-guard.svg"},
	{"id": PERFECT_ORBIT, "title": "PERFECT ORBIT", "description": "Average circliness over 90% in level 1.",           "icon": "res://assets/badges/perfect-orbit.svg"},
	{"id": HIVEMIND,      "title": "HIVEMIND",      "description": "Create your first genome.",                        "icon": "res://assets/badges/hivemind.svg"},
	{"id": VETERAN,       "title": "VETERAN",       "description": "Reach the rank of Commander.",                        "icon": "res://assets/badges/veteran.svg"},
	{"id": SWARM_MASTER,  "title": "SWARM MASTER",  "description": "Finish every level.",                               "icon": "res://assets/badges/swarm-master.svg"},
	{"id": GENE_POOL,     "title": "GENE POOL",     "description": "Keep 5 genomes in the Genome moon.",                "icon": "res://assets/badges/gene-pool.svg"},
	{"id": FULL_LIBRARY,  "title": "FULL LIBRARY",  "description": "Fill every genome slot.",                           "icon": "res://assets/badges/full-library.svg"},
	{"id": ADAPTATION,    "title": "ADAPTATION",    "description": "Switch genomes in the middle of a level.",          "icon": "res://assets/badges/adaptation.svg"},
	{"id": EVOLUTION,     "title": "EVOLUTION",     "description": "Win a level after switching genomes mid-run.",      "icon": "res://assets/badges/evolution.svg"},
	{"id": NEW_HORIZONS,  "title": "NEW HORIZONS",  "description": "Travel to a newly unlocked moon.",                  "icon": "res://assets/badges/new-horizons.svg"},
	{"id": SHIPWRIGHT,    "title": "SHIPWRIGHT",    "description": "Buy your first upgrade or addon.",                  "icon": "res://assets/badges/shipwright.svg"},
	{"id": FULLY_LOADED,  "title": "FULLY LOADED",  "description": "Max out every Shipyard upgrade.",                   "icon": "res://assets/badges/fully-loaded.svg"},
	{"id": LONG_GAME,     "title": "LONG GAME",     "description": "Max out Level Switches in the Genome moon.",        "icon": "res://assets/badges/long-game.svg"},
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

static func check_genome_count(count: int, is_full: bool):
	if count >= GENE_POOL_SIZE:
		PlayerData.unlock_achievement(GENE_POOL)
	if is_full:
		PlayerData.unlock_achievement(FULL_LIBRARY)

static func check_genome_switch():
	PlayerData.unlock_achievement(ADAPTATION)

static func check_run_result(held: bool, switched_genome: bool):
	if held and switched_genome:
		PlayerData.unlock_achievement(EVOLUTION)

static func check_moon_travel():
	PlayerData.unlock_achievement(NEW_HORIZONS)

static func check_purchases():
	if PlayerData.ship_upgrades.is_empty() and PlayerData.ship_addons.is_empty():
		return
	PlayerData.unlock_achievement(SHIPWRIGHT)
	if SHIP_UPGRADES.is_maxed(GENOME_UPGRADES.SWITCHES):
		PlayerData.unlock_achievement(LONG_GAME)
	for upgrade in SHIP_UPGRADES.ALL:
		if not SHIP_UPGRADES.is_maxed(upgrade):
			return
	PlayerData.unlock_achievement(FULLY_LOADED)
