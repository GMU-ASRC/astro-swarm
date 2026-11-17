extends RefCounted

static var editing_ship: bool = false

const ALL := [
	{
		"id": "max_speed",
		"starter_limit": 3.0,
		"limit_per_level": 0.2,
		"ship_default": 3.75,
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
		"ship_default": 70.0,
		"block_type": "set_fov",
		"title": "FOV",
		"icon": "res://assets/sprites/upgrades/fov.svg",
		"max_level": 5,
		"base_cost": 40,
	},
	{
		"id": "view_distance",
		"starter_limit": 5.0,
		"limit_per_level": 1.0,
		"ship_default": 7.5,
		"block_type": "set_view",
		"title": "VIEW DISTANCE",
		"icon": "res://assets/sprites/upgrades/view_distance.svg",
		"max_level": 5,
		"base_cost": 40,
	},
	{
		"id": "turn_speed",
		"starter_limit": 120.0,
		"limit_per_level": 24.0,
		"ship_default": 183.35,
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
	_add_missing_caps(clamped)
	return clamped

static func _add_missing_caps(scripts: Array):
	var missing: Array = []
	for upgrade in ALL:
		var limit: float = current_limit(upgrade)
		if float(upgrade["ship_default"]) > limit and not _sets_config(scripts, upgrade["block_type"]):
			missing.append({"type": upgrade["block_type"], "params": {"value": limit}, "children": []})
	if missing.is_empty():
		return
	var start_block: Dictionary = _find_start_block(scripts)
	if start_block.is_empty():
		scripts.append({"x": 40.0, "y": 40.0, "blocks": [{"type": "when_start", "params": {}, "children": missing}]})
		return
	start_block["children"] = start_block.get("children", []) + missing

static func _sets_config(scripts: Array, block_type: String) -> bool:
	for stack in scripts:
		for block in stack.get("blocks", []):
			if block.get("type", "") == block_type:
				return true
			if block.get("type", "") != "when_start":
				continue
			for child in block.get("children", []):
				if child.get("type", "") == block_type:
					return true
	return false

static func _find_start_block(scripts: Array) -> Dictionary:
	for stack in scripts:
		for block in stack.get("blocks", []):
			if block.get("type", "") == "when_start":
				return block
	return {}

static func _clamp_blocks(blocks: Array):
	for block in blocks:
		var upgrade: Dictionary = find_by_block(block.get("type", ""))
		var params: Dictionary = block.get("params", {})
		if not upgrade.is_empty() and params.has("value"):
			params["value"] = minf(float(params["value"]), current_limit(upgrade))
		_clamp_blocks(block.get("children", []))
