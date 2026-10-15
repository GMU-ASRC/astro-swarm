extends RefCounted

static var editing_ship: bool = false

const ALL := [
	{
		"id": "max_speed",
		"starter_limit": 4.0,
		"limit_per_level": 1.2,
		"block_type": "set_speed",
		"title": "MAX SPEED",
		"icon": "res://assets/sprites/upgrades/max_speed.svg",
		"max_level": 5,
		"base_cost": 40,
	},
	{
		"id": "fov",
		"starter_limit": 90.0,
		"limit_per_level": 18.0,
		"block_type": "set_fov",
		"title": "FOV",
		"icon": "res://assets/sprites/upgrades/fov.svg",
		"max_level": 5,
		"base_cost": 40,
	},
	{
		"id": "view_distance",
		"starter_limit": 7.5,
		"limit_per_level": 1.0,
		"block_type": "set_view",
		"title": "VIEW DISTANCE",
		"icon": "res://assets/sprites/upgrades/view_distance.svg",
		"max_level": 5,
		"base_cost": 40,
	},
	{
		"id": "turn_speed",
		"starter_limit": 180.0,
		"limit_per_level": 36.0,
		"block_type": "set_turn",
		"title": "TURN SPEED",
		"icon": "res://assets/sprites/upgrades/turn_speed.svg",
		"max_level": 5,
		"base_cost": 40,
	},
]

static func cost(upgrade: Dictionary, current_level: int) -> int:
	return int(upgrade["base_cost"]) * (current_level + 1)

static func is_maxed(upgrade: Dictionary) -> bool:
	return PlayerData.ship_upgrade_level(upgrade["id"]) >= int(upgrade["max_level"])

static func purchase(upgrade: Dictionary) -> bool:
	if is_maxed(upgrade):
		return false
	var price: int = cost(upgrade, PlayerData.ship_upgrade_level(upgrade["id"]))
	if not PlayerData.spend_coins(price):
		return false
	PlayerData.raise_ship_upgrade(upgrade["id"])
	return true

static func find_by_block(block_type: String) -> Dictionary:
	for upgrade in ALL:
		if upgrade["block_type"] == block_type:
			return upgrade
	return {}

static func limit_at_level(upgrade: Dictionary, level: int) -> float:
	return float(upgrade["starter_limit"]) + float(upgrade["limit_per_level"]) * level

static func current_limit(upgrade: Dictionary) -> float:
	return limit_at_level(upgrade, PlayerData.ship_upgrade_level(upgrade["id"]))

static func editor_max(block_type: String, base_max: float) -> float:
	var upgrade: Dictionary = find_by_block(block_type)
	if upgrade.is_empty() or not editing_ship:
		return base_max
	return current_limit(upgrade)

static func limit_text(upgrade: Dictionary, level: int) -> String:
	if not upgrade.has("block_type"):
		return "%d%s" % [roundi(limit_at_level(upgrade, level)), upgrade.get("suffix", "")]
	var input: Dictionary = SimulationManager.BLOCK_DEFS[upgrade["block_type"]]["input"]
	var limit: float = limit_at_level(upgrade, level)
	if float(input["step"]) >= 1.0:
		return "%d%s" % [roundi(limit), input["suffix"]]
	return "%.1f%s" % [limit, input["suffix"]]

static func clamp_scripts(scripts: Array) -> Array:
	var clamped: Array = scripts.duplicate(true)
	for stack in clamped:
		_clamp_blocks(stack.get("blocks", []))
	return clamped

static func _clamp_blocks(blocks: Array):
	for block in blocks:
		var upgrade: Dictionary = find_by_block(block.get("type", ""))
		var params: Dictionary = block.get("params", {})
		if not upgrade.is_empty() and params.has("value"):
			params["value"] = minf(float(params["value"]), current_limit(upgrade))
		_clamp_blocks(block.get("children", []))
