extends RefCounted

const SHIP_UPGRADES := preload("res://progression/ShipUpgrades.gd")

const SWITCHES := {
	"id": "genome_switches",
	"starter_limit": 3.0,
	"limit_per_level": 1.0,
	"suffix": " SWITCHES",
	"title": "LEVEL SWITCHES",
	"icon": "res://assets/sprites/upgrades/genome_switch.svg",
	"max_level": 5,
	"base_cost": 250,
}

const ALL := [SWITCHES]

static func switches_per_level() -> int:
	return roundi(SHIP_UPGRADES.current_limit(SWITCHES))

static func purchase(upgrade: Dictionary) -> bool:
	return SHIP_UPGRADES.purchase(upgrade)
